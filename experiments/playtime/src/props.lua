-- props.lua
-- Toy recipes for doll play (docs/DOLL-PLAY.md): balls, a skateboard, a slide.
-- Greybox shapes built with objectManager / joints, so they save with the scene
-- like anything made in the editor. Sizes are in world units and fit a Mipo at
-- scale 0.3 (about 600 tall); pass `scale` to make them bigger or smaller.
-- Each returns the thing(s) it made; every body gets a label scenes can find.
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local uuid = require('src.uuid')
local JT = require('src.joint-types')
local mathutils = require('src.math-utils')

local lib = {}

local function setMaterial(body, friction, restitution, density)
    for _, fixture in ipairs(body:getFixtures()) do
        if not fixture:isSensor() then
            if friction then fixture:setFriction(friction) end
            if restitution then fixture:setRestitution(restitution) end
            if density then fixture:setDensity(density) end
        end
    end
    body:resetMassData()
end

-- A bouncy ball. opts: { squishy = true } for the soft winegum-kiss sound.
function lib.makeBall(x, y, radius, opts)
    opts = opts or {}
    local thing = objectManager.addThing('circle', { x = x, y = y, radius = radius or 80, label = 'ball' })
    if not thing then return nil end
    setMaterial(thing.body, 0.6, 0.6, 0.5)
    if opts.squishy then
        thing.behaviors = thing.behaviors or {}
        table.insert(thing.behaviors, { name = 'SQUISHY' })
    end
    return thing
end

-- Ribbon vertices along a path: top edge left -> right, then the bottom edge
-- (offset by thickness) right -> left, relative to (x, y).
local function ribbonAlong(points, thickness)
    local verts = {}
    for _, p in ipairs(points) do
        verts[#verts + 1] = p[1]
        verts[#verts + 1] = p[2]
    end
    for i = #points, 1, -1 do
        verts[#verts + 1] = points[i][1]
        verts[#verts + 1] = points[i][2] + thickness
    end
    return verts
end

-- A skateboard: a long deck whose ends curl up (kicktails, so a sliding foot
-- is stopped) on two wheel joints with a little suspension. 800 long fits the
-- widest Mipo stance measured (~640); a 420 flat board let feet slide off.
function lib.makeSkateboard(x, y, scale)
    local s = scale or 1
    local half, tail, tailHeight, thickness, wheelR = 400 * s, 70 * s, 70 * s, 34 * s, 40 * s
    local points = {}
    for i = 0, 20 do
        local px = -half + 2 * half * i / 20
        local over = math.max(0, math.abs(px) - (half - tail)) / tail
        points[#points + 1] = { px, -tailHeight * over * over }
    end
    local verts = ribbonAlong(points, thickness)
    local cx, cy = mathutils.computeCentroid(verts)
    local deck = objectManager.addThing('ribbon',
        { x = x + cx, y = y + cy, vertices = verts, label = 'skateboard' })
    if not deck then return nil end
    setMaterial(deck.body, 0.9, 0.05, 1)
    local wheels = {}
    for _, side in ipairs({ -1, 1 }) do
        local wx, wy = side * half * 0.65, thickness + wheelR * 0.9
        local wheel = objectManager.addThing('circle',
            { x = x + wx, y = y + wy, radius = wheelR, label = 'skateboard-wheel' })
        if wheel then
            setMaterial(wheel.body, 1.0, 0.1, 1)
            joints.createJoint({
                body1 = deck.body,
                body2 = wheel.body,
                jointType = JT.WHEEL,
                id = uuid.generateID(),
                offsetA = { x = wx - cx, y = wy - cy },
                offsetB = { x = 0, y = 0 },
                axisX = 0,
                axisY = 1,
                springFrequency = 10,
                springDampingRatio = 0.8,
                collideConnected = false,
            })
            wheels[#wheels + 1] = wheel
        end
    end
    return deck, wheels
end

-- Nearest static surface straight below (x, fromY), ignoring `ignoreBody`.
-- Box2D reports ray hits in any order, so keep the closest one.
function lib.floorBelow(x, fromY, ignoreBody)
    local state = require('src.state')
    local best, bestY = math.huge, nil
    state.physicsWorld:rayCast(x, fromY, x, fromY + 20000, function(fixture, _, hy, _, _, fraction)
        local body = fixture:getBody()
        if body:getType() == 'static' and body ~= ignoreBody and not fixture:isSensor() and fraction < best then
            best, bestY = fraction, hy
        end
        return 1
    end)
    return bestY
end

-- A fixed slide standing on the floor at (x, floorY): a ladder on the left, a
-- starting deck long enough for the skateboard (docs/WORLD-METRICS.md) sloping
-- gently toward the chute, then a smooth chute down. Deck and chute are one
-- ribbon so there's no bump. Returns { ladder, deck, deckEnd = { x, y } }.
function lib.makeSlide(x, floorY, scale)
    local s = scale or 1
    local height, deckLength, deckDrop = 700 * s, 1000 * s, 1000 * s * math.tan(math.rad(3))
    local chuteLength, thickness = 1400 * s, 30 * s
    local ladder = objectManager.addThing('rectangle', {
        x = x, y = floorY - (height + 70 * s) / 2, width = 40 * s, height = height + 70 * s,
        bodyType = 'static', label = 'slide-ladder' }) -- sticks up 70 above the deck: a lip

    local points = {}
    for i = 0, 10 do
        local t = i / 10
        points[#points + 1] = { deckLength * t, deckDrop * t }
    end
    local chuteHeight = height - deckDrop
    for i = 1, 14 do
        local t = i / 14
        local eased = t * t * (3 - 2 * t) -- smoothstep: flat at both ends
        points[#points + 1] = { deckLength + chuteLength * t, deckDrop + chuteHeight * eased }
    end
    local verts = ribbonAlong(points, thickness)
    local cx, cy = mathutils.computeCentroid(verts)
    local left = x + 20 * s
    local deck = objectManager.addThing('ribbon', {
        x = left + cx, y = floorY - height + cy, vertices = verts, bodyType = 'static', label = 'slide' })
    if ladder then setMaterial(ladder.body, 0.9, 0, nil) end
    if deck then setMaterial(deck.body, 0.15, 0, nil) end -- slippery: things slide and roll
    return { ladder = ladder, deck = deck, deckEnd = { left + deckLength, floorY - height + deckDrop } }
end

-- A gate on a prismatic joint to `baseBody`, standing up from (x, surfaceY).
-- Closed: up, blocking. Open: pulled down into the base (joined bodies don't
-- collide). Listens to `signal` (src/signals.lua).
function lib.makeGate(baseBody, x, surfaceY, signal, scale)
    local s = scale or 1
    local gateH, gateW = 200 * s, 30 * s
    local gate = objectManager.addThing('rectangle', {
        x = x, y = surfaceY - gateH / 2, width = gateW, height = gateH, label = 'gate' })
    if not gate then return nil end
    setMaterial(gate.body, 0.5, 0, 2)
    gate.body:setFixedRotation(true)
    gate.behaviors = { { name = 'SIGNAL_GATE', signal = signal or 'gate1', open = false } }
    local bx, by = baseBody:getPosition()
    local joint = joints.createJoint({
        body1 = baseBody,
        body2 = gate.body,
        jointType = JT.PRISMATIC,
        id = uuid.generateID(),
        offsetA = { x = x - bx, y = surfaceY - by },
        offsetB = { x = 0, y = 0 },
        axisX = 0,
        axisY = -1, -- positive translation = up
        collideConnected = false,
    })
    if joint then
        -- translation is measured from where the gate stands now (closed)
        joint:setLimits(-gateH - 10 * s, 0)
        joint:setLimitsEnabled(true)
    end
    require('src.signals').setGate(gate.body, false)
    return gate
end

-- A button on a post standing on the floor at (x, floorY), `height` up.
-- Tapping it sends `signal`.
function lib.makeButton(x, floorY, height, signal, scale)
    local s = scale or 1
    local post = objectManager.addThing('rectangle', {
        x = x, y = floorY - height / 2, width = 24 * s, height = height,
        bodyType = 'static', label = 'button-post' })
    local button = objectManager.addThing('rectangle', {
        x = x, y = floorY - height - 30 * s, width = 110 * s, height = 60 * s,
        bodyType = 'static', label = 'button' })
    if button then
        button.behaviors = { { name = 'SIGNAL_BUTTON', signal = signal or 'gate1' } }
    end
    return button, post
end

return lib
