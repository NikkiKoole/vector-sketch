-- woodpecker: the woodpecker pole — a wooden bird on a spring pecks its way down a pole.
-- Vintage toys idea (2026-11-16, Nikki: "woodpecker pole !").
--
-- The real toy: a loose ring round a pole, a spring from the ring to a wooden woodpecker. The bird's weight
-- hangs off to one side, so the ring tips and jams on the pole by friction. Flick the bird and it bobs on its
-- spring: each bob frees the ring for a moment, it slips a little, the beak hits the pole (tock), it jams again.
-- All honest Box2D here: the ring is two pads either side of the pole with a few px to spare (tipped, their
-- opposite corners pinch the pole), the spring is a soft weld (frequency, damping), the beak a fixture that hits
-- the pole. Two Mipos watch the bird.
--
-- play mode (tab): tap the bird to flick it; t (or the button) puts it back at the top.
-- From the bridge: s.status(); s.flick(); s.top()

local s = {}

local GROUND_W = 5000
local TABLE_Y = 0
local POLE_X = 0
local POLE_W = 40
local POLE_TOP = -1500
local BASE_H = 70
local GROUP = -31          -- ring and bird don't collide with each other
local TOY_VERSION = 4

local tune = {
    gap = 6,          -- px of play between each pad and the pole
    beakGap = 8,      -- px from the beak's tip to the pole, level
    lean = -0.08,     -- the spring's rest: the bird leans this much head-down (radians)
    padH = 70,        -- the ring's height
    friction = 0.9,
    springHz = 3.2,   -- the spring between ring and bird
    springDamp = 0.04,
    flick = 5,        -- a tap's kick: the bird's spin, rad/s
}

local function wp()
    local p = state.woodpecker
    if not p then
        p = { mipos = {}, pops = {}, pecks = 0 }
        state.woodpecker = p
    end
    return p
end

local function alive(b) return b and not b:isDestroyed() end

---------------------------------------------------------------- sound

local tocks
local function makeTocks()
    if tocks then return end
    tocks = {}
    local rate = 22050
    for i, f in ipairs({ 1250, 1400, 1550 }) do
        local len = 0.08
        local data = love.sound.newSoundData(math.floor(rate * len), rate, 16, 1)
        for n = 0, data:getSampleCount() - 1 do
            local t = n / rate
            local v = (math.sin(2 * math.pi * f * t) * 0.7 + math.sin(2 * math.pi * f * 2.6 * t) * 0.25
                + (love.math.random() * 2 - 1) * 0.4 * math.exp(-t * 500)) * math.exp(-t * 80) * 0.55
            data:setSample(n, math.max(-1, math.min(1, v)))
        end
        tocks[i] = love.audio.newSource(data, 'static')
    end
end

local function tock(loud)
    if not tocks then return end
    local src = tocks[love.math.random(#tocks)]:clone()
    src:setVolume(0.3 + 0.7 * loud)
    src:play()
end

---------------------------------------------------------------- building

local function destroyToy(p)
    if p.toy then
        for _, b in ipairs({ p.toy.ring, p.toy.bird }) do if alive(b) then b:destroy() end end
    end
    p.toy = nil
end

local function build(p, y)
    destroyToy(p)
    y = y or (POLE_TOP + 120)
    local ring = love.physics.newBody(world, POLE_X, y, 'dynamic')
    local inner = POLE_W / 2 + tune.gap
    for _, side in ipairs({ -1, 1 }) do
        local pad = love.physics.newFixture(ring, love.physics.newRectangleShape(side * (inner + 8), 0, 16, tune.padH))
        pad:setFriction(tune.friction)
        pad:setGroupIndex(GROUP)
        pad:setDensity(1)
    end
    -- the spring's stub, out to the right
    local stub = love.physics.newFixture(ring, love.physics.newRectangleShape(inner + 34, 0, 36, 18))
    stub:setGroupIndex(GROUP)
    stub:setDensity(1)
    ring:resetMassData()
    -- the bird: body out to the right, head and beak back toward the pole, a tail down and out
    local sx = POLE_X + inner + 52             -- the spring's end
    local bird = love.physics.newBody(world, sx + 70, y + 10, 'dynamic')
    local bodyF = love.physics.newFixture(bird, love.physics.newPolygonShape(
        -60, -30, 30, -40, 70, -10, 60, 30, -40, 40))
    bodyF:setGroupIndex(GROUP)
    bodyF:setDensity(2)
    local tail = love.physics.newFixture(bird, love.physics.newPolygonShape(50, 10, 150, 70, 130, 90, 40, 35))
    tail:setGroupIndex(GROUP)
    tail:setDensity(2)
    local head = love.physics.newFixture(bird, love.physics.newCircleShape(-60, -55, 32))
    head:setGroupIndex(GROUP)
    head:setDensity(2)
    -- the beak reaches to just short of the pole: it hits it when the bird tips forward
    local tipX = (POLE_X + POLE_W / 2 + tune.beakGap) - bird:getX()
    local beak = love.physics.newFixture(bird, love.physics.newPolygonShape(-80, -66, tipX, -52, -80, -44))
    beak:setGroupIndex(GROUP)
    beak:setDensity(1)
    beak:setFriction(0.2)
    bird:resetMassData()
    -- the spring: a hinge, and a spring torque of our own between ring and bird (springTorque). A soft weld
    -- was tried first: its turning stiffness goes by the lighter body, the little ring, and the bird hung 60°.
    local spring = love.physics.newRevoluteJoint(ring, bird, sx, y, false)
    spring:setLimits(-0.9, 0.9)
    spring:setLimitsEnabled(true)
    local cx, cy = bird:getWorldCenter()
    p.toy = { ring = ring, bird = bird, spring = spring, version = TOY_VERSION, tipX = tipX, beak = beak,
        lever = cx - sx, pivotR2 = (cx - sx) ^ 2 + (cy - y) ^ 2 }
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[ring] = true
    state.hiddenBodies[bird] = true
end

local function makeGround(p)
    if alive(p.ground) then return end
    p.ground = love.physics.newBody(world, 0, 0, 'static')
    local top = love.physics.newFixture(p.ground,
        love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, GROUND_W / 2, TABLE_Y))
    top:setFriction(0.9)
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, -GROUND_W / 2, -3000))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(GROUND_W / 2, TABLE_Y, GROUND_W / 2, -3000))
    -- the pole and its base
    local pole = love.physics.newFixture(p.ground,
        love.physics.newRectangleShape(POLE_X, (POLE_TOP + TABLE_Y) / 2, POLE_W, TABLE_Y - POLE_TOP))
    pole:setFriction(tune.friction)
    p.poleFixture = pole
    love.physics.newFixture(p.ground, love.physics.newRectangleShape(POLE_X, TABLE_Y - BASE_H / 2, 360, BASE_H))
    -- a knob on top so it can't come off
    love.physics.newFixture(p.ground, love.physics.newCircleShape(POLE_X, POLE_TOP - 10, 40))
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[p.ground] = true
end

-- the spring's torque: stiffness from its frequency (the bird's inertia about the hinge), its rest angle set so the
-- bird sits level under its own weight; on the bird one way, on the ring the other (that tips the ring)
local function springTorque(p)
    local toy = p.toy
    local bird, ring = toy.bird, toy.ring
    local I = bird:getInertia() + bird:getMass() * toy.pivotR2
    local w = 2 * math.pi * tune.springHz
    local k = I * w * w
    local _, g = world:getGravity()
    local rest = tune.lean - bird:getMass() * g * toy.lever / k
    local angle = toy.spring:getJointAngle()
    local speed = toy.spring:getJointSpeed()
    local torque = -k * (angle - rest) - 2 * tune.springDamp * I * w * speed
    bird:applyTorque(torque)
    ring:applyTorque(-torque)
end

local function birdTarget()
    local p = state.woodpecker
    local b = p and p.toy and p.toy.bird
    if alive(b) then return b:getPosition() end
    return POLE_X, -600
end

local function addMipos(p)
    p.mipos = mipoKit.alive(p.mipos)
    if #p.mipos > 0 then return end
    for _, x in ipairs({ -650, 700 }) do
        local inst = mipoKit.spawn(p.mipos, x, TABLE_Y - 500)
        if inst then mipoActions.lookAt(inst, birdTarget) end
    end
end

function s.onStart()
    worldState.paused = false
    local p = wp()
    makeTocks()
    makeGround(p)
    if not (p.toy and alive(p.toy.ring) and p.toy.version == TOY_VERSION) then build(p) end
    addMipos(p)
    camera.setBounds(-GROUND_W / 2, -2600, GROUND_W / 2, 400)
end

function s.onUnload()
    local p = state.woodpecker
    if not p then return end
    destroyToy(p)
    if alive(p.ground) then p.ground:destroy() end
    p.ground = nil
end

---------------------------------------------------------------- playing

function s.flick()
    local p = wp()
    if not (p.toy and alive(p.toy.bird)) then return end
    local bird = p.toy.bird
    -- push the tail down: the bird tips back on its spring, and off it goes (tune.flick rad/s of spin)
    local I = bird:getInertia() + bird:getMass() * p.toy.pivotR2
    bird:applyAngularImpulse(-tune.flick * I)
    p.toy.ring:setAwake(true)
end

function s.top()
    local p = wp()
    p.pecks = 0
    build(p)
end

function s.onKeyPress(key)
    if not state.playMode then return end
    if key == 't' then s.top()
    elseif key == 'space' then s.flick() end
end

local function overPanel()
    local r = s._panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

local function taps(p)
    local down = state.playMode and love.mouse.isDown(1) and not overPanel()
    if down and not p.wasDown then
        local mx, my = mouseWorldPos()
        local bx, by = p.toy.bird:getPosition()
        if math.sqrt((mx - bx) ^ 2 + (my - by) ^ 2) < 220 then s.flick() end
    end
    p.wasDown = down
end

-- a peck: the beak's fixture starting to touch the pole (Box2D's own contacts)
local function pecks(p)
    local toy = p.toy
    local touching = false
    for _, contact in ipairs(toy.bird:getContacts()) do
        if contact:isTouching() then
            local fa, fb = contact:getFixtures()
            if (fa == toy.beak and fb == p.poleFixture) or (fb == toy.beak and fa == p.poleFixture) then
                touching = true
            end
        end
    end
    if touching and not p.touching then
        local tx, ty = toy.bird:getWorldPoint(toy.tipX, -52)
        local vx, vy = toy.bird:getLinearVelocityFromWorldPoint(tx, ty)
        local speed = math.sqrt(vx * vx + vy * vy)
        p.pecks = p.pecks + 1
        tock(math.min(1, 0.3 + speed / 300))
        p.pops[#p.pops + 1] = { x = POLE_X + POLE_W / 2, y = ty, t = 0 }
    end
    p.touching = touching
end

function s.update(dt)
    local p = wp()
    if not (p.toy and alive(p.toy.ring) and p.toy.version == TOY_VERSION) then return end
    if dt <= 0 then return end
    springTorque(p)
    taps(p)
    pecks(p)
    for i = #p.pops, 1, -1 do
        local q = p.pops[i]
        q.t = q.t + dt
        if q.t > 0.25 then table.remove(p.pops, i) end
    end
end

---------------------------------------------------------------- drawing

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local SKY = { 0.80, 0.90, 0.95 }
local HILL = { 0.62, 0.78, 0.50 }
local TABLE = { 0.62, 0.45, 0.30 }
local TABLE_EDGE = { 0.46, 0.32, 0.20 }
local INK = { 0.20, 0.13, 0.10 }
local POLE = { 0.88, 0.74, 0.50 }
local POLE_DARK = { 0.72, 0.56, 0.34 }
local RED = { 0.86, 0.18, 0.15 }
local BLACK = { 0.18, 0.16, 0.18 }
local WHITE = { 0.97, 0.95, 0.90 }
local YELLOW = { 0.97, 0.78, 0.20 }
local GREEN = { 0.30, 0.58, 0.38 }
local STEEL = { 0.70, 0.72, 0.75 }

function s.drawBelow()
    setc(SKY)
    love.graphics.rectangle('fill', -GROUND_W / 2, -3000, GROUND_W, 3000 + TABLE_Y)
    setc(HILL)
    love.graphics.ellipse('fill', -900, TABLE_Y, 1400, 380)
    love.graphics.ellipse('fill', 1100, TABLE_Y, 1300, 300)
    setc(TABLE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y, GROUND_W, 110)
    setc(TABLE_EDGE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y + 110, GROUND_W, 600)
    -- the base, a green painted block
    setc(INK)
    love.graphics.rectangle('fill', POLE_X - 186, TABLE_Y - BASE_H - 6, 372, BASE_H + 6, 14, 14)
    setc(GREEN)
    love.graphics.rectangle('fill', POLE_X - 180, TABLE_Y - BASE_H, 360, BASE_H - 6, 10, 10)
    -- the pole, with a stripe to show the slipping, and its knob
    setc(INK)
    love.graphics.rectangle('fill', POLE_X - POLE_W / 2 - 6, POLE_TOP, POLE_W + 12, TABLE_Y - BASE_H - POLE_TOP)
    setc(POLE)
    love.graphics.rectangle('fill', POLE_X - POLE_W / 2, POLE_TOP, POLE_W, TABLE_Y - BASE_H - POLE_TOP)
    setc(POLE_DARK)
    love.graphics.rectangle('fill', POLE_X + 4, POLE_TOP, POLE_W / 2 - 4, TABLE_Y - BASE_H - POLE_TOP)
    for y = POLE_TOP + 100, TABLE_Y - BASE_H - 40, 140 do
        setc(RED, 0.8)
        love.graphics.rectangle('fill', POLE_X - POLE_W / 2, y, POLE_W, 14)
    end
    setc(INK)
    love.graphics.circle('fill', POLE_X, POLE_TOP - 10, 46)
    setc(RED)
    love.graphics.circle('fill', POLE_X, POLE_TOP - 10, 40)
    setc(WHITE, 0.6)
    love.graphics.circle('fill', POLE_X - 14, POLE_TOP - 24, 10)
end

local function poly(body, verts, col)
    local pts = {}
    for i = 1, #verts, 2 do
        local x, y = body:getWorldPoint(verts[i], verts[i + 1])
        pts[#pts + 1], pts[#pts + 2] = x, y
    end
    setc(col)
    love.graphics.polygon('fill', pts)
end

function s.draw()
    local p = state.woodpecker
    if not (p and p.toy and alive(p.toy.ring) and p.toy.version == TOY_VERSION) then return end
    local ring, bird = p.toy.ring, p.toy.bird
    local inner = POLE_W / 2 + tune.gap
    -- the ring: a red sleeve round the pole, and the spring as a coil to the bird
    poly(ring, { -inner - 20, -tune.padH / 2 - 4, inner + 20, -tune.padH / 2 - 4, inner + 20, tune.padH / 2 + 4,
        -inner - 20, tune.padH / 2 + 4 }, INK)
    poly(ring, { -inner - 14, -tune.padH / 2 + 2, inner + 14, -tune.padH / 2 + 2, inner + 14, tune.padH / 2 - 2,
        -inner - 14, tune.padH / 2 - 2 }, RED)
    local ax, ay = ring:getWorldPoint(inner + 16, 0)
    local bx, by = bird:getWorldPoint(-30, -6)
    love.graphics.setLineWidth(5)
    setc(STEEL)
    local pts = {}
    local dx, dy = bx - ax, by - ay
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local nx, ny = -dy / len, dx / len
    for k = 0, 24 do
        local t = k / 24
        local w = (k == 0 or k == 24) and 0 or ((k % 2 == 0) and 12 or -12)
        pts[#pts + 1] = ax + dx * t + nx * w
        pts[#pts + 1] = ay + dy * t + ny * w
    end
    love.graphics.line(pts)
    -- the bird: black tail, white-and-black body, red cap, yellow beak
    poly(bird, { 46, 4, 158, 70, 134, 98, 34, 40 }, INK)
    poly(bird, { 50, 12, 146, 70, 130, 88, 42, 36 }, BLACK)
    poly(bird, { -66, -38, 32, -48, 78, -12, 66, 38, -46, 48 }, INK)
    poly(bird, { -58, -30, 30, -40, 70, -10, 60, 30, -40, 40 }, BLACK)
    poly(bird, { -46, -18, 20, -26, 36, 10, -30, 30 }, WHITE)
    local tipX = p.toy.tipX
    poly(bird, { -84, -70, tipX - 2, -52, -84, -40 }, INK)
    poly(bird, { -82, -65, tipX - 6, -52, -82, -45 }, YELLOW)
    local hx, hy = bird:getWorldPoint(-60, -55)
    setc(INK)
    love.graphics.circle('fill', hx, hy, 38)
    setc(WHITE)
    love.graphics.circle('fill', hx, hy, 32)
    local cx, cy = bird:getWorldPoint(-50, -82)
    setc(RED)
    love.graphics.circle('fill', cx, cy, 22)
    local ex, ey = bird:getWorldPoint(-68, -58)
    setc(INK)
    love.graphics.circle('fill', ex, ey, 8)
    setc(WHITE)
    love.graphics.circle('fill', ex - 2, ey - 3, 3)
    -- the tocks
    love.graphics.setLineWidth(5)
    for _, q in ipairs(p.pops) do
        local k = q.t / 0.25
        love.graphics.setColor(1, 0.85, 0.4, 1 - k)
        for a = -1, 1 do
            local ang = math.pi + a * 0.5
            love.graphics.line(q.x + math.cos(ang) * (20 + 20 * k), q.y + math.sin(ang) * (20 + 20 * k),
                q.x + math.cos(ang) * (40 + 40 * k), q.y + math.sin(ang) * (40 + 40 * k))
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local p = state.woodpecker
    if not (p and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 320
    local rows = 5
    local ph = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - ph - 20
    s._panelRect = { x0, y0, w, ph }
    ui.panel(x0, y0, w, ph, '•• woodpecker ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'back to the top (t)') then s.top() end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'flick it (tap the bird)') then s.flick() end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('wpgap', x, y, 150, 1, 14, tune.gap, nil, 0.5)
        if v then tune.gap = v end
        ui.label(x + 250, y, 'ring play')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('wphz', x, y, 150, 1, 8, tune.springHz, nil, 0.1)
        if v then
            tune.springHz = v
        end
        ui.label(x + 250, y, 'spring Hz')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('pecks: %d   (ring play: on t)', p.pecks))
    end)
end

-- From the bridge
function s.status()
    local p = wp()
    if not (p.toy and alive(p.toy.ring)) then return 'none' end
    local rx, ry = p.toy.ring:getPosition()
    local _, vy = p.toy.ring:getLinearVelocity()
    return { ringY = math.floor(ry), ringX = math.floor(rx), ringDeg = math.floor(math.deg(p.toy.ring:getAngle())),
        ringVy = math.floor(vy), birdDeg = math.floor(math.deg(p.toy.bird:getAngle())), pecks = p.pecks }
end

return s
