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

-- A fixed slide standing on the floor at (x, floorY): ladder on the left,
-- platform on top, a curved chute down to the right.
function lib.makeSlide(x, floorY, scale)
    local s = scale or 1
    local height, chuteLength, thickness = 700 * s, 1400 * s, 30 * s
    local made = {}

    local ladder = objectManager.addThing('rectangle', {
        x = x, y = floorY - height / 2, width = 40 * s, height = height,
        bodyType = 'static', label = 'slide-ladder' })
    made[#made + 1] = ladder

    local platform = objectManager.addThing('rectangle', {
        x = x + 90 * s, y = floorY - height, width = 220 * s, height = thickness,
        bodyType = 'static', label = 'slide' })
    made[#made + 1] = platform

    -- chute: an eased curve from the platform edge down to the floor
    local points, steps = {}, 12
    for i = 0, steps do
        local t = i / steps
        local eased = t * t * (3 - 2 * t) -- smoothstep: flat at both ends
        points[#points + 1] = { chuteLength * t, height * eased }
    end
    -- a ribbon centres its shape on the vertex centroid, so the body goes there
    local verts = ribbonAlong(points, thickness)
    local cx, cy = mathutils.computeCentroid(verts)
    local chute = objectManager.addThing('ribbon', {
        x = x + 200 * s + cx, y = floorY - height + cy, vertices = verts,
        bodyType = 'static', label = 'slide' })
    made[#made + 1] = chute

    for _, thing in ipairs(made) do
        if thing then setMaterial(thing.body, 0.15, 0, nil) end -- slippery
    end
    return made
end

return lib
