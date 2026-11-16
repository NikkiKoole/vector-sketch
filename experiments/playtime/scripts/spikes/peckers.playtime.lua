-- peckers: the pecking chickens paddle — swing it round and the hens peck, one after the other.
-- Vintage toys idea (2026-11-16, Nikki: "you can pick up a new toys if you want?").
--
-- The real toy: a round wooden paddle with hens on it, each head on a hinge, a string from each head down
-- through a hole in the paddle to one wooden ball hanging underneath. Move the paddle in circles, the ball
-- swings round, and the string on the far side from the ball goes taut and pulls that hen's head down: tock.
-- Here, side on: a board with four hens, the paddle follows the finger (a kinematic body), the ball is a real
-- body hanging only on the four strings. A string is its length now (head -> hole -> ball) against its length
-- at rest: longer, it pulls head and ball toward the hole (a stiff spring, damped). Each neck is a hinge with a
-- weak muscle holding the head up; the ball's share of weight at rest doesn't beat it, a swing does.
-- Two Mipos on the table watch the ball.
--
-- play mode (tab): drag anywhere to move the paddle. keys: a it swings by itself   r start again
-- From the bridge: s.status(); s.auto(on)

local s = {}

local GROUND_W = 5000
local TABLE_Y = 0
local HOME_X, HOME_Y = 0, -1000       -- where the paddle rests
local BOARD_W, BOARD_H = 760, 44
local BALL_R = 58
local BALL_DROP = 330                 -- the ball hangs this far under the board
local HENS = { -270, -90, 90, 270 }   -- along the board
local TOY_VERSION = 2                 -- a script reload with an older toy builds it again
local GROUP = -23                     -- the toy's parts don't collide with each other

local tune = {
    give = 12,     -- px of string pulled through before a head moves
    pullPx = 40,   -- px of string pulled through per radian of head
    neckGain = 30, -- how quick a head follows its string
    follow = 14,   -- how quick the paddle goes to the finger
    tilt = 0.00035, -- the paddle tips with its sideways speed
    autoR = 130,   -- the swing by itself: a circle this big
    autoHz = 1.25,
}

local function pk()
    local p = state.peckers
    if not p then
        p = { mipos = {}, pops = {}, auto = false, t = 0, pecks = 0 }
        state.peckers = p
    end
    return p
end

local function alive(b) return b and not b:isDestroyed() end

---------------------------------------------------------------- sound: a wooden tock, a few pitches

local tocks
local function makeTocks()
    if tocks or not love.audio then return end -- (no audio: the scenes tab's thumbnails)
    tocks = {}
    local rate = 22050
    for i, f in ipairs({ 1500, 1680, 1880, 2100 }) do
        local len = 0.09
        local data = love.sound.newSoundData(math.floor(rate * len), rate, 16, 1)
        for n = 0, data:getSampleCount() - 1 do
            local t = n / rate
            local v = (math.sin(2 * math.pi * f * t) * 0.8 + math.sin(2 * math.pi * f * 2.3 * t) * 0.3
                + (love.math.random() * 2 - 1) * 0.35 * math.exp(-t * 400)) * math.exp(-t * 70) * 0.5
            data:setSample(n, math.max(-1, math.min(1, v)))
        end
        tocks[i] = love.audio.newSource(data, 'static')
    end
end

local function tock(i, loud)
    if not tocks then return end
    local src = tocks[i]:clone()
    src:setVolume(0.35 + 0.65 * loud)
    src:setPitch(0.95 + love.math.random() * 0.1)
    src:play()
end

---------------------------------------------------------------- building

local function destroyToy(p)
    if p.toy then
        for _, b in ipairs({ p.toy.paddle, p.toy.ball }) do if alive(b) then b:destroy() end end
        for _, hen in ipairs(p.toy.hens) do if alive(hen.head) then hen.head:destroy() end end
    end
    p.toy = nil
end

local function build(p)
    destroyToy(p)
    p.pecks = 0
    local paddle = love.physics.newBody(world, HOME_X, HOME_Y, 'kinematic')
    local board = love.physics.newFixture(paddle, love.physics.newRectangleShape(0, 0, BOARD_W, BOARD_H))
    board:setGroupIndex(GROUP)
    -- the handle, out to the right
    local handle = love.physics.newFixture(paddle, love.physics.newRectangleShape(BOARD_W / 2 + 130, 0, 260, 36))
    handle:setGroupIndex(GROUP)
    local hens = {}
    for i, hx in ipairs(HENS) do
        local dir = hx < 0 and -1 or 1 -- facing out, tails to the middle
        -- the body is part of the paddle; the head a body on a hinge at the neck
        local bodyY = -BOARD_H / 2 - 52
        local hb = love.physics.newFixture(paddle, love.physics.newCircleShape(hx - dir * 10, bodyY, 50))
        hb:setGroupIndex(GROUP)
        local nx, ny = HOME_X + hx + dir * 34, HOME_Y + bodyY - 30 -- the neck hinge, world
        local head = love.physics.newBody(world, nx + dir * 26, ny - 34, 'dynamic')
        local hf = love.physics.newFixture(head, love.physics.newCircleShape(30))
        hf:setGroupIndex(GROUP)
        hf:setDensity(0.6)
        local beak = love.physics.newFixture(head, love.physics.newPolygonShape(
            dir * 24, -10, dir * 58, 2, dir * 24, 12))
        beak:setGroupIndex(GROUP)
        head:resetMassData()
        local joint = love.physics.newRevoluteJoint(paddle, head, nx, ny, false)
        -- pecking: the head turns forward (dir 1 faces right: clockwise, + in y-down)
        if dir == 1 then joint:setLimits(-0.12, 1.25) else joint:setLimits(-1.25, 0.12) end
        joint:setLimitsEnabled(true)
        joint:setMotorEnabled(true)
        -- the string: from under the head to a hole in the board under the beak
        hens[i] = {
            head = head, joint = joint, dir = dir, x = hx,
            attach = { dir * 14, 22 },                     -- on the head, its own frame
            hole = { hx + dir * 95, 0 },                   -- on the paddle, its own frame
        }
    end
    local ball = love.physics.newBody(world, HOME_X, HOME_Y + BALL_DROP, 'dynamic')
    local bf = love.physics.newFixture(ball, love.physics.newCircleShape(BALL_R))
    bf:setGroupIndex(GROUP)
    bf:setDensity(2.5)
    ball:resetMassData()
    ball:setLinearDamping(0.05)
    -- the ball on its rope from the middle of the board; each string's ball side at rest
    love.physics.newRopeJoint(paddle, ball, HOME_X, HOME_Y + BOARD_H / 2, HOME_X, HOME_Y + BALL_DROP,
        BALL_DROP - BOARD_H / 2, false)
    for _, hen in ipairs(hens) do
        local hx, hy = paddle:getWorldPoint(hen.hole[1], hen.hole[2])
        local bx, by = ball:getPosition()
        hen.restBall = math.sqrt((bx - hx) ^ 2 + (by - hy) ^ 2)
        hen.peckMax = 1.2
    end
    p.toy = { paddle = paddle, ball = ball, hens = hens, version = TOY_VERSION }
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[paddle] = true
    state.hiddenBodies[ball] = true
    for _, hen in ipairs(hens) do state.hiddenBodies[hen.head] = true end
end

local function makeGround(p)
    if alive(p.ground) then return end
    p.ground = love.physics.newBody(world, 0, 0, 'static')
    local top = love.physics.newFixture(p.ground,
        love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, GROUND_W / 2, TABLE_Y))
    top:setFriction(0.9)
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, -GROUND_W / 2, -3000))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(GROUND_W / 2, TABLE_Y, GROUND_W / 2, -3000))
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[p.ground] = true
end

local function ballTarget()
    local p = state.peckers
    local ball = p and p.toy and p.toy.ball
    if alive(ball) then return ball:getPosition() end
    return 0, HOME_Y
end

local function addMipos(p)
    p.mipos = mipoKit.alive(p.mipos)
    if #p.mipos > 0 then return end
    for _, x in ipairs({ -620, 560 }) do
        local inst = mipoKit.spawn(p.mipos, x, TABLE_Y - 500)
        if inst then mipoActions.lookAt(inst, ballTarget) end
    end
end

function s.onStart()
    worldState.paused = false
    local p = pk()
    makeTocks()
    makeGround(p)
    if not (p.toy and alive(p.toy.paddle) and p.toy.version == TOY_VERSION) then build(p) end
    addMipos(p)
    camera.setBounds(-GROUND_W / 2, -2600, GROUND_W / 2, 400)
end

function s.onUnload()
    local p = state.peckers
    if not p then return end
    destroyToy(p)
    if alive(p.ground) then p.ground:destroy() end
    p.ground = nil
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local p = pk()
    if key == 'a' then p.auto = not p.auto
    elseif key == 'r' then build(p) end
end

---------------------------------------------------------------- the toy moving

local function overPanel()
    local r = s._panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

-- where the paddle wants to be: the finger (grabbed where it was pressed), a circle, or where it is
local function paddleGoal(p, dt)
    local paddle = p.toy.paddle
    local px, py = paddle:getPosition()
    local down = state.playMode and love.mouse.isDown(1) and not overPanel()
    local mx, my = mouseWorldPos()
    if down and not p.wasDown then p.grab = { px - mx, py - my } end
    if not down then p.grab = nil end
    p.wasDown = down
    if p.grab then return mx + p.grab[1], my + p.grab[2] end
    if p.auto then
        p.t = p.t + dt
        local a = p.t * tune.autoHz * 2 * math.pi
        return HOME_X + math.cos(a) * tune.autoR, HOME_Y + math.sin(a) * tune.autoR * 0.6
    end
    return px, py
end

local function movePaddle(p, dt)
    local paddle = p.toy.paddle
    local gx, gy = paddleGoal(p, dt)
    local px, py = paddle:getPosition()
    local vx, vy = (gx - px) * tune.follow, (gy - py) * tune.follow
    local cap = 3000
    local sp = math.sqrt(vx * vx + vy * vy)
    if sp > cap then vx, vy = vx / sp * cap, vy / sp * cap end
    paddle:setLinearVelocity(vx, vy)
    local goalAngle = math.max(-0.15, math.min(0.15, vx * tune.tilt))
    paddle:setAngularVelocity((goalAngle - paddle:getAngle()) * 10)
end

-- The strings. The ball hangs from the paddle on a rope (the strings together carry it); each hen's string
-- runs from its head through its hole to the ball. When the ball swings away from a hole, more string is
-- pulled through on the ball's side, and that hen's head goes down by as much (past a little give): its neck
-- motor is driven to that angle. (Tried first: each string a stiff spring between a light head and the heavy
-- ball, by applyForce. It blew up: the heads are too light for a spring that holds a ball.)
local function pullStrings(p)
    local toy = p.toy
    local bx, by = toy.ball:getPosition()
    for i, hen in ipairs(toy.hens) do
        local hx, hy = toy.paddle:getWorldPoint(hen.hole[1], hen.hole[2])
        local d2 = math.sqrt((bx - hx) ^ 2 + (by - hy) ^ 2)
        local pulled = math.max(0, d2 - hen.restBall - tune.give)
        hen.tension = pulled
        local goal = math.min(hen.peckMax, pulled / tune.pullPx)
        local joint = hen.joint
        local angle = joint:getJointAngle() * hen.dir
        joint:setMotorSpeed((goal - angle) * tune.neckGain * hen.dir)
        joint:setMaxMotorTorque(hen.head:getMass() * 1e6)
        -- a peck: the head reaching the bottom of its swing, going down
        local speed = joint:getJointSpeed() * hen.dir
        if angle > 0.9 and not hen.down then
            hen.down = true
            p.pecks = p.pecks + 1
            tock(i, math.min(1, math.abs(speed) / 8))
            local hx2, hy2 = hen.head:getWorldPoint(hen.dir * 58, 2)
            p.pops[#p.pops + 1] = { x = hx2, y = hy2, t = 0 }
        elseif angle < 0.45 then
            hen.down = false
        end
    end
end

-- the Mipos: a happy squeak now and then at a good run of pecks
local function cheer(p)
    local now = love.timer.getTime()
    p.recent = p.recent or {}
    if p.pecks ~= p.lastPecks then
        p.recent[#p.recent + 1] = now
        p.lastPecks = p.pecks
    end
    while p.recent[1] and now - p.recent[1] > 2 do table.remove(p.recent, 1) end
    if #p.recent >= 6 and now - (p.cheeredAt or 0) > 4 then
        p.cheeredAt = now
        for _, inst in ipairs(mipoKit.alive(p.mipos)) do
            mipoVoice.squeak(inst, 'happy')
            mipoEmotion.set(inst, 'happy', 1, 2)
        end
    end
end

function s.update(dt)
    local p = pk()
    if not (p.toy and alive(p.toy.paddle) and alive(p.toy.ball) and p.toy.version == TOY_VERSION) then return end
    if dt <= 0 then return end
    movePaddle(p, dt)
    pullStrings(p)
    cheer(p)
    for i = #p.pops, 1, -1 do
        local q = p.pops[i]
        q.t = q.t + dt
        if q.t > 0.3 then table.remove(p.pops, i) end
    end
end

---------------------------------------------------------------- drawing

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local WALL = { 0.84, 0.90, 0.86 }
local WALL_STRIPE = { 0.78, 0.86, 0.81 }
local TABLE = { 0.70, 0.50, 0.32 }
local TABLE_EDGE = { 0.52, 0.35, 0.21 }
local WOOD = { 0.86, 0.68, 0.44 }
local WOOD_DARK = { 0.66, 0.48, 0.28 }
local INK = { 0.26, 0.16, 0.10 }
local HEN = { 0.97, 0.94, 0.86 }
local HEN_BROWN = { 0.78, 0.45, 0.22 }
local RED = { 0.86, 0.20, 0.16 }
local YELLOW = { 0.97, 0.75, 0.18 }
local GREEN = { 0.36, 0.62, 0.34 }
local STRING = { 0.32, 0.24, 0.18 }

function s.drawBelow()
    setc(WALL)
    love.graphics.rectangle('fill', -GROUND_W / 2, -3000, GROUND_W, 3000 + TABLE_Y)
    setc(WALL_STRIPE)
    for x = -GROUND_W / 2, GROUND_W / 2, 140 do love.graphics.rectangle('fill', x, -3000, 50, 3000 + TABLE_Y) end
    setc(TABLE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y, GROUND_W, 110)
    setc(TABLE_EDGE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y + 110, GROUND_W, 600)
end

local function drawHen(p, hen, i)
    local paddle = p.toy.paddle
    local dir = hen.dir
    -- the body, in the paddle's frame
    love.graphics.push()
    local px, py = paddle:getPosition()
    love.graphics.translate(px, py)
    love.graphics.rotate(paddle:getAngle())
    local bx, by = hen.x - dir * 10, -BOARD_H / 2 - 52
    setc(INK)
    love.graphics.ellipse('fill', bx, by, 66, 56)
    setc(i % 2 == 0 and HEN_BROWN or HEN)
    love.graphics.ellipse('fill', bx, by, 60, 50)
    -- the tail, up at the back
    setc(INK)
    love.graphics.polygon('fill', bx - dir * 40, by - 20, bx - dir * 92, by - 66, bx - dir * 72, by + 6)
    setc(i % 2 == 0 and HEN_BROWN or HEN)
    love.graphics.polygon('fill', bx - dir * 44, by - 18, bx - dir * 84, by - 56, bx - dir * 68, by + 2)
    -- a painted wing
    setc(i % 2 == 0 and HEN or HEN_BROWN, 0.8)
    love.graphics.ellipse('fill', bx - dir * 8, by + 4, 30, 18)
    -- legs as two dowels into the board
    setc(INK)
    love.graphics.rectangle('fill', bx - 18, by + 40, 8, 26)
    love.graphics.rectangle('fill', bx + 10, by + 40, 8, 26)
    love.graphics.pop()
    -- the head, in its own frame
    local head = hen.head
    local hx, hy = head:getPosition()
    love.graphics.push()
    love.graphics.translate(hx, hy)
    love.graphics.rotate(head:getAngle())
    setc(INK)
    love.graphics.polygon('fill', dir * 20, -14, dir * 62, 2, dir * 20, 16)
    setc(YELLOW)
    love.graphics.polygon('fill', dir * 24, -9, dir * 55, 2, dir * 24, 11)
    -- the comb and wattle
    setc(RED)
    love.graphics.circle('fill', -dir * 4, -32, 12)
    love.graphics.circle('fill', dir * 10, -34, 12)
    love.graphics.circle('fill', dir * 22, 20, 9)
    setc(INK)
    love.graphics.circle('fill', 0, 0, 34)
    setc(i % 2 == 0 and HEN_BROWN or HEN)
    love.graphics.circle('fill', 0, 0, 29)
    setc(INK)
    love.graphics.circle('fill', dir * 10, -6, 5.5)
    love.graphics.pop()
end

function s.draw()
    local p = state.peckers
    if not (p and p.toy and alive(p.toy.paddle) and alive(p.toy.ball)) then return end
    local toy = p.toy
    local paddle, ball = toy.paddle, toy.ball
    local bx, by = ball:getPosition()
    -- the strings, behind everything: head -> hole -> ball
    love.graphics.setLineWidth(3)
    for _, hen in ipairs(toy.hens) do
        local ax, ay = hen.head:getWorldPoint(hen.attach[1], hen.attach[2])
        local hx, hy = paddle:getWorldPoint(hen.hole[1], hen.hole[2])
        setc(STRING, (hen.tension or 0) > 0 and 1 or 0.6)
        love.graphics.line(ax, ay, hx, hy, bx, by)
    end
    -- the ball, painted wood with a stripe
    setc(INK)
    love.graphics.circle('fill', bx, by, BALL_R + 6)
    setc(RED)
    love.graphics.circle('fill', bx, by, BALL_R)
    setc(YELLOW)
    love.graphics.push()
    love.graphics.translate(bx, by)
    love.graphics.rotate(ball:getAngle())
    love.graphics.rectangle('fill', -BALL_R, -9, BALL_R * 2, 18)
    love.graphics.pop()
    setc(HEN, 0.5)
    love.graphics.circle('fill', bx - 20, by - 22, 12)
    -- the paddle: board with painted grain and a green rim, the handle
    love.graphics.push()
    local px, py = paddle:getPosition()
    love.graphics.translate(px, py)
    love.graphics.rotate(paddle:getAngle())
    setc(INK)
    love.graphics.rectangle('fill', BOARD_W / 2 - 10, -24, 290, 48, 22, 22)
    setc(WOOD_DARK)
    love.graphics.rectangle('fill', BOARD_W / 2 - 4, -18, 280, 36, 18, 18)
    setc(INK)
    love.graphics.rectangle('fill', -BOARD_W / 2 - 6, -BOARD_H / 2 - 6, BOARD_W + 12, BOARD_H + 12, 16, 16)
    setc(GREEN)
    love.graphics.rectangle('fill', -BOARD_W / 2, -BOARD_H / 2, BOARD_W, BOARD_H, 12, 12)
    setc(WOOD)
    love.graphics.rectangle('fill', -BOARD_W / 2 + 10, -BOARD_H / 2, BOARD_W - 20, BOARD_H - 14, 8, 8)
    setc(YELLOW)
    for gx = -BOARD_W / 2 + 40, BOARD_W / 2 - 40, 46 do
        love.graphics.ellipse('fill', gx + (gx % 3) * 4, -BOARD_H / 2 + 8, 7, 4)
    end
    love.graphics.pop()
    for i, hen in ipairs(toy.hens) do drawHen(p, hen, i) end
    for _, q in ipairs(p.pops) do
        local k = q.t / 0.3
        love.graphics.setColor(1, 0.9, 0.5, 1 - k)
        for a = 0, 4 do
            local ang = -math.pi / 2 + (a - 2) * 0.5
            love.graphics.line(q.x + math.cos(ang) * (16 + 30 * k), q.y + math.sin(ang) * (16 + 30 * k),
                q.x + math.cos(ang) * (30 + 50 * k), q.y + math.sin(ang) * (30 + 50 * k))
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local p = state.peckers
    if not (p and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 320
    local rows = 5
    local ph = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - ph - 20
    s._panelRect = { x0, y0, w, ph }
    ui.panel(x0, y0, w, ph, '•• pecking hens ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, p.auto and 'stop swinging (a)' or 'swing by itself (a)') then p.auto = not p.auto end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('pkpull', x, y, 150, 10, 120, tune.pullPx, nil, 1)
        if v then tune.pullPx = v end
        ui.label(x + 250, y, 'string give')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('pkhz', x, y, 150, 0.3, 3, tune.autoHz, nil, 0.01)
        if v then tune.autoHz = v end
        ui.label(x + 250, y, 'swing Hz')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('pkr', x, y, 150, 20, 400, tune.autoR, nil, 1)
        if v then tune.autoR = v end
        ui.label(x + 250, y, 'swing size')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('drag to swing it   pecks: %d', p.pecks))
    end)
end

-- From the bridge
function s.status()
    local p = pk()
    if not (p.toy and alive(p.toy.ball)) then return 'none' end
    local heads = {}
    for i, hen in ipairs(p.toy.hens) do
        heads[i] = string.format('%.2f/%.0f', hen.joint:getJointAngle() * hen.dir, hen.tension or 0)
    end
    local bx, by = p.toy.ball:getPosition()
    local px, py = p.toy.paddle:getPosition()
    return { pecks = p.pecks, heads = table.concat(heads, ' '), ballDX = math.floor(bx - px),
        ballDY = math.floor(by - py), auto = p.auto }
end

function s.auto(on) pk().auto = on end

return s
