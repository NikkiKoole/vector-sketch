-- wasserbahn: a water play track — gutters down from a tower, locks, a water wheel, boats, a hand pump.
-- Vintage toys idea (2026-11-16, Nikki: "a few more toys ideas, catapult, wasserbahn").
--
-- The real toy: blue plastic gutters zigzag down from a water tower to a pool; you close a lock and the water
-- backs up behind it, open it and it rushes on; the water falling from one gutter to the next turns a wheel; boats
-- ride the current; at the pool you pump the water back up into the tower. Here the water is drops (points,
-- not Box2D) that slide along a gutter (gravity along its slope, a little drag), fall off its low end and land on
-- the next gutter or in the pool. A closed lock holds them back, stacked: the lock fills. The wheel is turned by
-- the drops falling through its paddles. Boats ride their gutter carried by the water there (a dry gutter and
-- they stall), fall at the end like the drops. The pump moves pool water to the tower a stroke at a time.
--
-- play mode (tab): tap a lock to open/close it; drag the pump handle up and down; tap a boat in the pool to put
-- it back at the top. keys: 1 2 the locks   p pump a stroke   r start again
-- From the bridge: s.status(); s.pump(); s.gate(i, open)

local s = {}

local GROUND_W = 5000
local GROUND_Y = 0
local GRAVITY = 1400
local TOY_VERSION = 3
local DROP_R = 16

-- gutters, each from its high end to its low end
local GUTTERS = {
    { -880, -990, 300, -860 },
    { 470, -660, -620, -520 },
    { -900, -410, 790, -250 }, -- (starts well left of gutter 2's end: the water shoots on as it falls)
}
local GATES = { { g = 1, at = 760 }, { g = 3, at = 1000 } } -- a lock: which gutter, how far along
local TOWER = { x = -1010, y = -1060, w = 230, h = 190 }   -- the basin; its outlet onto gutter 1
local POOL = { x0 = 820, x1 = 1270, depth = 170 }
local PUMP = { x = 1360, y = -260 }                          -- the handle's pivot
local WHEEL = { x = 330, y = -760, r = 82 }

local tune = {
    drag = 0.35,       -- a drop's drag along a gutter (with the slopes: ~400 px/s)
    maxSpeed = 700,
    outlet = 40,       -- drops a second out of the tower
    stroke = 14,       -- drops a pump stroke lifts
    total = 260,       -- drops in the toy
    dropArea = 300,    -- px^2 of water a drop is, in a lock's pond
    gateH = 120,       -- a lock board's height: deeper water spills over
    wheelPush = 0.00003,
    wheelMax = 9,      -- rad/s at most
    wheelDrag = 0.8,
}

local function wb()
    local p = state.wasserbahn
    if not p then
        p = { mipos = {}, pops = {} }
        state.wasserbahn = p
    end
    return p
end

---------------------------------------------------------------- geometry

local G = {}
for i, g in ipairs(GUTTERS) do
    local dx, dy = g[3] - g[1], g[4] - g[2]
    local len = math.sqrt(dx * dx + dy * dy)
    local ux, uy = dx / len, dy / len
    local nx, ny = uy, -ux
    if ny > 0 then nx, ny = -nx, -ny end -- the normal pointing up
    G[i] = { x1 = g[1], y1 = g[2], x2 = g[3], y2 = g[4], len = len, ux = ux, uy = uy, nx = nx, ny = ny,
        sin = dy / len }
end

local function onGutter(i, sAlong)
    local g = G[i]
    return g.x1 + g.ux * sAlong + g.nx * DROP_R, g.y1 + g.uy * sAlong + g.ny * DROP_R
end

-- a falling thing crossing gutter i between y0 and y1 at x: where along it lands, or nil
local function landsOn(i, x, y0, y1)
    local g = G[i]
    local lo, hi = math.min(g.x1, g.x2), math.max(g.x1, g.x2)
    if x < lo or x > hi then return nil end
    local ly = g.y1 + (x - g.x1) * (g.y2 - g.y1) / (g.x2 - g.x1)
    if y0 < ly and y1 >= ly then return (x - g.x1) / g.ux end
    return nil
end

local function poolTop(p)
    local frac = math.min(1, p.pool / tune.total)
    return GROUND_Y - 20 - frac * (POOL.depth - 30)
end

---------------------------------------------------------------- sounds

local sounds
local function makeSounds()
    if sounds or not love.audio then return end -- (no audio: the scenes tab's thumbnails)
    sounds = {}
    local rate = 22050
    local function make(len, fn)
        local data = love.sound.newSoundData(math.floor(rate * len), rate, 16, 1)
        for n = 0, data:getSampleCount() - 1 do
            data:setSample(n, math.max(-1, math.min(1, fn(n / rate))))
        end
        return love.audio.newSource(data, 'static')
    end
    sounds.splash = make(0.2, function(t)
        return (love.math.random() * 2 - 1) * math.exp(-t * 25) * 0.35
    end)
    sounds.clunk = make(0.15, function(t) -- a lock board
        return (math.sin(2 * math.pi * 180 * t) * 0.8 + (love.math.random() * 2 - 1) * 0.3) * math.exp(-t * 35) * 0.6
    end)
    sounds.tick = make(0.04, function(t) -- a wheel paddle
        return (love.math.random() * 2 - 1) * math.exp(-t * 200) * 0.25
    end)
    sounds.pump = make(0.35, function(t) -- a stroke: a gulp
        local f = 160 + 200 * t
        return math.sin(2 * math.pi * f * t) * math.sin(math.pi * t / 0.35) * 0.4
    end)
    local flow = make(1.0, function() return (love.math.random() * 2 - 1) * 0.1 end)
    flow:setLooping(true)
    sounds.flow = flow
end

local function play(name, pitch, vol)
    if not (sounds and sounds[name]) then return end
    local src = sounds[name]:clone()
    src:setPitch(pitch or 1)
    src:setVolume(vol or 1)
    src:play()
end

---------------------------------------------------------------- state

local function reset(p)
    p.drops = {}
    p.tower = math.floor(tune.total * 0.55)
    p.pool = tune.total - p.tower
    p.gates = {}
    for i in ipairs(GATES) do p.gates[i] = { open = true, lift = 1 } end
    p.wheel = { a = 0, w = 0, lastPaddle = 0 }
    p.pumpA = 0
    p.boats = {}
    local colors = { { 0.92, 0.30, 0.22 }, { 0.98, 0.80, 0.20 }, { 0.40, 0.75, 0.40 } }
    for i = 1, 3 do
        p.boats[i] = { mode = 'gutter', g = 1, s = 40 + (i - 1) * 140, v = 0, color = colors[i], bob = i }
    end
    p.version = TOY_VERSION
end

local function makeGround(p)
    if p.ground and not p.ground:isDestroyed() then return end
    p.ground = love.physics.newBody(world, 0, 0, 'static')
    local top = love.physics.newFixture(p.ground,
        love.physics.newEdgeShape(-GROUND_W / 2, GROUND_Y, GROUND_W / 2, GROUND_Y))
    top:setFriction(0.9)
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(-GROUND_W / 2, GROUND_Y, -GROUND_W / 2, -3000))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(GROUND_W / 2, GROUND_Y, GROUND_W / 2, -3000))
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[p.ground] = true
end

local function boatTarget()
    local p = state.wasserbahn
    local b = p and p.boats and p.boats[1]
    if b and b.x then return b.x, b.y end
    return 0, -600
end

local function addMipos(p)
    p.mipos = mipoKit.alive(p.mipos)
    if #p.mipos > 0 then return end
    for _, x in ipairs({ -1420, 1700 }) do -- either side of the track, not in front of it
        local inst = mipoKit.spawn(p.mipos, x, GROUND_Y - 500)
        if inst then mipoActions.lookAt(inst, boatTarget) end
    end
end

function s.onStart()
    worldState.paused = false
    local p = wb()
    makeSounds()
    makeGround(p)
    if p.version ~= TOY_VERSION then reset(p) end
    addMipos(p)
    camera.setBounds(-GROUND_W / 2, -2600, GROUND_W / 2, 400)
end

function s.onUnload()
    if sounds and sounds.flow then sounds.flow:stop() end
    local p = state.wasserbahn
    if not p then return end
    if p.ground and not p.ground:isDestroyed() then p.ground:destroy() end
    p.ground = nil
end

---------------------------------------------------------------- the toy

function s.gate(i, open)
    local p = wb()
    local gate = p.gates and p.gates[i]
    if not gate then return end
    if open == nil then open = not gate.open end
    if gate.open ~= open then play('clunk', open and 1.1 or 0.9) end
    gate.open = open
end

function s.pump()
    local p = wb()
    local n = math.min(tune.stroke, p.pool)
    p.pool = p.pool - n
    p.tower = p.tower + n
    play('pump', 0.9 + love.math.random() * 0.2, 0.8)
    p.pops[#p.pops + 1] = { x = TOWER.x, y = TOWER.y - 40, t = 0 }
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local p = wb()
    if key == '1' then s.gate(1)
    elseif key == '2' then s.gate(2)
    elseif key == 'p' then s.pump()
    elseif key == 'r' then reset(p) end
end

local function gateWorld(i)
    local gd = GATES[i]
    local x, y = onGutter(gd.g, gd.at)
    return x, y - DROP_R
end

local function overPanel()
    local r = s._panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

local function handleEnd(a)
    -- the pump handle: from its pivot, out to the left, a = 0 up .. 1 down
    local ang = -0.6 + a * 1.2
    return PUMP.x - math.cos(ang) * 200, PUMP.y + math.sin(ang) * 200
end

local function input(p)
    local down = state.playMode and love.mouse.isDown(1) and not overPanel()
    local mx, my = mouseWorldPos()
    if down and not p.wasDown then
        p.dragPump = false
        local hx, hy = handleEnd(p.pumpA)
        if math.sqrt((mx - hx) ^ 2 + (my - hy) ^ 2) < 120 then
            p.dragPump = true
        else
            for i in ipairs(GATES) do
                local gx, gy = gateWorld(i)
                if math.abs(mx - gx) < 70 and my > gy - 140 and my < gy + 50 then s.gate(i) end
            end
            for _, b in ipairs(p.boats) do
                if b.mode == 'pool' and math.abs(mx - b.x) < 90 and math.abs(my - b.y) < 90 then
                    b.mode, b.g, b.s, b.v = 'gutter', 1, 30, 0
                    play('clunk', 1.4, 0.5)
                end
            end
        end
    end
    if not down then p.dragPump = false end
    p.wasDown = down
    if p.dragPump then
        local goal = math.max(0, math.min(1, (my - (PUMP.y - 120)) / 240))
        if goal > 0.9 and p.pumpA <= 0.9 then s.pump() end -- a stroke: the handle all the way down
        p.pumpA = goal
    else
        p.pumpA = p.pumpA * 0.9
    end
end

-- drops on each gutter, in order along it (for the locks and the boats)
local function byGutter(p)
    local lists = {}
    for i in ipairs(G) do lists[i] = {} end
    for _, d in ipairs(p.drops) do
        if d.g then table.insert(lists[d.g], d) end
    end
    for i in ipairs(G) do table.sort(lists[i], function(a, b) return a.s > b.s end) end
    return lists
end

local function gateOn(p, gi)
    for i, gd in ipairs(GATES) do
        if gd.g == gi and not p.gates[i].open then return gd.at end
    end
end

local function moveDrops(p, dt, lists)
    -- the tower lets water onto gutter 1
    p.outAcc = (p.outAcc or 0) + dt * tune.outlet
    while p.outAcc >= 1 and p.tower > 0 do
        p.outAcc = p.outAcc - 1
        p.tower = p.tower - 1
        p.drops[#p.drops + 1] = { g = 1, s = 5 + love.math.random() * 10, v = 80 }
    end
    if p.tower <= 0 then p.outAcc = 0 end
    -- along the gutters. Behind a closed lock the water is a pond: level on top, its length from how much is
    -- held (the wedge between the sloping gutter and a flat surface: n drops of dropArea = L^2 sin / 2), and
    -- deeper than the board it spills over. (First: drops stacked in a line, which ran all the way back up.)
    p.locks = {}
    for gi, list in ipairs(lists) do
        local g = G[gi]
        local gate = gateOn(p, gi)
        local pondL = 0
        if gate then
            local A = tune.dropArea
            local n = 0
            for _, d in ipairs(list) do -- (furthest along first)
                if d.s <= gate + 0.01 then
                    local L = math.sqrt(2 * (n + 1) * A / g.sin)
                    if d.s >= gate - L - DROP_R then n = n + 1 else break end
                end
            end
            local maxL = tune.gateH / g.sin
            local spill = math.max(0, n - math.floor(maxL * maxL * g.sin / (2 * A)))
            pondL = math.min(maxL, math.sqrt(2 * n * A / g.sin))
            p.locks[gi] = { gate = gate, L = pondL }
            local k = 0
            for _, d in ipairs(list) do
                if d.s <= gate + 0.01 then
                    k = k + 1
                    if k > n then break end
                    if k <= spill then
                        d.s, d.v, d.held = gate + 2, 80, nil -- over the top
                    else
                        d.s, d.v, d.held = math.min(d.s, gate), 0, true
                    end
                end
            end
        end
        for _, d in ipairs(list) do
            if d.held and not gate then d.held = nil end -- the lock opened: off it goes
            if not d.held then
                d.v = d.v + GRAVITY * g.sin * dt - d.v * tune.drag * dt
                d.v = math.min(tune.maxSpeed, d.v)
                local ns = d.s + d.v * dt
                if gate and d.s <= gate and ns > gate - pondL then ns, d.v = gate - pondL, 0 end -- into the pond
                d.s = ns
                if d.s > g.len then
                    -- off the low end: falling
                    d.x, d.y = onGutter(gi, g.len)
                    d.vx, d.vy = g.ux * d.v, g.uy * d.v
                    d.g, d.s = nil, nil
                end
            end
        end
    end
    -- falling: through the wheel, onto a gutter, into the pool
    local top = poolTop(p)
    for i = #p.drops, 1, -1 do
        local d = p.drops[i]
        if not d.g then
            local y0 = d.y
            d.vy = d.vy + GRAVITY * dt
            d.x = d.x + d.vx * dt
            d.y = d.y + d.vy * dt
            local dx, dy = d.x - WHEEL.x, d.y - WHEEL.y
            if dx * dx + dy * dy < WHEEL.r * WHEEL.r then
                -- a paddle takes some of its fall: the wheel turns, the drop slows
                local side = dx >= 0 and 1 or -1
                p.wheel.w = math.max(-tune.wheelMax, math.min(tune.wheelMax, p.wheel.w + side * d.vy * tune.wheelPush))
                d.vy = d.vy * 0.96
            end
            local landed = false
            for gi in ipairs(G) do
                local at = landsOn(gi, d.x, y0, d.y)
                if at then
                    d.g, d.s = gi, math.max(0, math.min(G[gi].len, at))
                    d.v = math.max(0, d.vx * G[gi].ux + d.vy * G[gi].uy) * 0.5
                    landed = true
                    break
                end
            end
            if not landed and d.y >= top then
                table.remove(p.drops, i)
                p.pool = p.pool + 1 -- (in the pool, or anywhere on the ground: back to the pool)
                if d.x > POOL.x0 and d.x < POOL.x1 and love.math.random() < 0.08 then
                    play('splash', 0.8 + love.math.random() * 0.5, 0.4)
                end
            end
        end
    end
end

local function moveWheel(p, dt)
    local wl = p.wheel
    wl.w = wl.w - wl.w * tune.wheelDrag * dt
    wl.a = wl.a + wl.w * dt
    local paddle = math.floor(wl.a / (math.pi / 4))
    if paddle ~= wl.lastPaddle then
        wl.lastPaddle = paddle
        if math.abs(wl.w) > 0.5 then play('tick', 0.9 + math.min(1, math.abs(wl.w) / 8), 0.6) end
    end
end

local function moveBoats(p, dt, lists)
    local top = poolTop(p)
    for _, b in ipairs(p.boats) do
        if b.mode == 'gutter' then
            local g = G[b.g]
            -- the water near it, and how fast it goes
            local n, sum = 0, 0
            for _, d in ipairs(lists[b.g]) do
                if d.g == b.g and math.abs(d.s - b.s) < 80 then -- (d.g: not fallen off since the list was made)
                    n = n + 1
                    sum = sum + d.v
                end
            end
            if n >= 2 then
                local w = sum / n
                b.v = b.v + (w - b.v) * 3 * dt + GRAVITY * g.sin * 0.15 * dt
            else
                b.v = b.v + GRAVITY * g.sin * 0.15 * dt - b.v * 3 * dt -- dry: it drags and stalls
                if b.v < 0 then b.v = 0 end
            end
            local gate = gateOn(p, b.g)
            local ns = b.s + b.v * dt
            if gate and b.s <= gate - 50 and ns > gate - 50 then ns, b.v = gate - 50, 0 end
            b.s = ns
            b.x, b.y = onGutter(b.g, b.s)
            b.angle = math.atan2(g.uy, g.ux)
            local lock = p.locks and p.locks[b.g]
            if lock and b.s >= lock.gate - lock.L and b.s <= lock.gate then
                b.y = math.min(b.y, g.y1 + g.uy * (lock.gate - lock.L) - 10 + DROP_R) -- afloat on the pond
                b.angle = 0
            end
            if b.s > g.len then
                b.mode = 'fall'
                b.vx, b.vy = g.ux * b.v, g.uy * b.v
            end
        elseif b.mode == 'fall' then
            local y0 = b.y
            b.vy = b.vy + GRAVITY * dt
            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
            b.angle = (b.angle or 0) + (b.vx > 0 and 1 or -1) * dt * 2
            for gi in ipairs(G) do
                local at = landsOn(gi, b.x, y0, b.y)
                if at then
                    b.mode, b.g, b.s = 'gutter', gi, math.max(0, math.min(G[gi].len, at))
                    b.v = math.max(0, b.vx * G[gi].ux + b.vy * G[gi].uy) * 0.4
                    play('splash', 1.2, 0.5)
                    break
                end
            end
            if b.mode == 'fall' and b.y >= top then
                b.mode = 'pool'
                b.x = math.max(POOL.x0 + 60, math.min(POOL.x1 - 60, b.x))
                play('splash', 0.7, 0.9)
                p.pops[#p.pops + 1] = { x = b.x, y = top, t = 0 }
                if love.timer.getTime() - (p.cheeredAt or 0) > 1.5 then
                    p.cheeredAt = love.timer.getTime()
                    for _, inst in ipairs(mipoKit.alive(p.mipos)) do
                        mipoVoice.squeak(inst, 'happy')
                        mipoEmotion.set(inst, 'happy', 1, 2)
                    end
                end
            end
        else -- in the pool: bobbing, drifting a little
            b.y = top + math.sin(love.timer.getTime() * 2 + b.bob) * 6
            b.angle = math.sin(love.timer.getTime() * 1.5 + b.bob) * 0.08
        end
    end
end

function s.update(dt)
    local p = wb()
    if p.version ~= TOY_VERSION or dt <= 0 then return end
    input(p)
    for _, gate in ipairs(p.gates) do
        gate.lift = gate.lift + ((gate.open and 1 or 0) - gate.lift) * math.min(1, dt * 8)
    end
    local lists = byGutter(p)
    moveDrops(p, dt, lists)
    moveWheel(p, dt)
    moveBoats(p, dt, lists)
    if sounds and sounds.flow then
        local onTrack = 0
        for _, d in ipairs(p.drops) do if d.g and d.v > 30 then onTrack = onTrack + 1 end end
        sounds.flow:setVolume(math.min(1, onTrack / 60))
        if onTrack > 0 and not sounds.flow:isPlaying() then sounds.flow:play() end
        if onTrack == 0 and sounds.flow:isPlaying() then sounds.flow:stop() end
    end
    for i = #p.pops, 1, -1 do
        local q = p.pops[i]
        q.t = q.t + dt
        if q.t > 0.4 then table.remove(p.pops, i) end
    end
end

---------------------------------------------------------------- drawing

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local SKY = { 0.82, 0.92, 0.96 }
local GRASS = { 0.50, 0.76, 0.40 }
local GRASS_DARK = { 0.40, 0.64, 0.32 }
local INK = { 0.16, 0.16, 0.22 }
local BLUE = { 0.20, 0.55, 0.88 }
local BLUE_DARK = { 0.12, 0.38, 0.70 }
local WATER = { 0.40, 0.75, 0.98 }
local WATER_LIGHT = { 0.80, 0.94, 1.0 }
local YELLOW = { 0.98, 0.80, 0.18 }
local RED = { 0.90, 0.25, 0.20 }
local GREEN = { 0.30, 0.65, 0.40 }
local WHITE = { 1, 1, 1 }

function s.drawBelow()
    setc(SKY)
    love.graphics.rectangle('fill', -GROUND_W / 2, -3000, GROUND_W, 3000 + GROUND_Y)
    setc(GRASS)
    love.graphics.rectangle('fill', -GROUND_W / 2, GROUND_Y, GROUND_W, 800)
    setc(GRASS_DARK)
    love.graphics.rectangle('fill', -GROUND_W / 2, GROUND_Y, GROUND_W, 18)
    -- posts under the gutters
    for _, g in ipairs(G) do
        for _, t in ipairs({ 0.08, 0.5, 0.92 }) do
            local x, y = g.x1 + (g.x2 - g.x1) * t, g.y1 + (g.y2 - g.y1) * t
            setc(INK)
            love.graphics.rectangle('fill', x - 13, y, 26, GROUND_Y - y)
            setc(YELLOW)
            love.graphics.rectangle('fill', x - 8, y, 16, GROUND_Y - y)
        end
    end
    -- the pipe from the pool back up to the tower, under the ground and up
    love.graphics.setLineWidth(30)
    setc(INK)
    love.graphics.line(PUMP.x, PUMP.y, PUMP.x, GROUND_Y + 40, TOWER.x - TOWER.w / 2 - 40, GROUND_Y + 40,
        TOWER.x - TOWER.w / 2 - 40, TOWER.y - TOWER.h / 2 - 30, TOWER.x - 40, TOWER.y - TOWER.h / 2 - 30)
    love.graphics.setLineWidth(18)
    setc(GREEN)
    love.graphics.line(PUMP.x, PUMP.y, PUMP.x, GROUND_Y + 40, TOWER.x - TOWER.w / 2 - 40, GROUND_Y + 40,
        TOWER.x - TOWER.w / 2 - 40, TOWER.y - TOWER.h / 2 - 30, TOWER.x - 40, TOWER.y - TOWER.h / 2 - 30)
    love.graphics.setLineWidth(1)
    -- the tower: legs and a basin
    setc(INK)
    love.graphics.rectangle('fill', TOWER.x - 70, TOWER.y, 30, GROUND_Y - TOWER.y)
    love.graphics.rectangle('fill', TOWER.x + 40, TOWER.y, 30, GROUND_Y - TOWER.y)
    setc(RED)
    love.graphics.rectangle('fill', TOWER.x - 64, TOWER.y, 18, GROUND_Y - TOWER.y)
    love.graphics.rectangle('fill', TOWER.x + 46, TOWER.y, 18, GROUND_Y - TOWER.y)
    -- the pool
    setc(INK)
    love.graphics.rectangle('fill', POOL.x0 - 14, GROUND_Y - POOL.depth - 10, POOL.x1 - POOL.x0 + 28, POOL.depth + 24,
        20, 20)
    setc(BLUE)
    love.graphics.rectangle('fill', POOL.x0 - 6, GROUND_Y - POOL.depth - 2, POOL.x1 - POOL.x0 + 12, POOL.depth + 10,
        14, 14)
    setc(BLUE_DARK)
    love.graphics.rectangle('fill', POOL.x0 + 6, GROUND_Y - POOL.depth + 10, POOL.x1 - POOL.x0 - 12, POOL.depth - 14,
        10, 10)
end

local function drawGutter(g)
    love.graphics.setLineWidth(46)
    setc(INK)
    love.graphics.line(g.x1, g.y1, g.x2, g.y2)
    love.graphics.circle('fill', g.x1, g.y1, 23)
    love.graphics.circle('fill', g.x2, g.y2, 23)
    love.graphics.setLineWidth(36)
    setc(BLUE)
    love.graphics.line(g.x1, g.y1, g.x2, g.y2)
    love.graphics.circle('fill', g.x1, g.y1, 18)
    love.graphics.circle('fill', g.x2, g.y2, 18)
    love.graphics.setLineWidth(12)
    setc(BLUE_DARK)
    love.graphics.line(g.x1 - g.nx * 6, g.y1 - g.ny * 6, g.x2 - g.nx * 6, g.y2 - g.ny * 6)
    love.graphics.setLineWidth(1)
end

local function drawBoat(b)
    love.graphics.push()
    love.graphics.translate(b.x, b.y - 8)
    love.graphics.rotate(b.angle or 0)
    setc(INK)
    love.graphics.polygon('fill', -58, -14, 58, -14, 40, 22, -40, 22)
    setc(b.color)
    love.graphics.polygon('fill', -50, -9, 50, -9, 36, 16, -36, 16)
    setc(INK)
    love.graphics.rectangle('fill', -4, -90, 8, 80)
    setc(WHITE)
    love.graphics.polygon('fill', 6, -86, 6, -22, 46, -26)
    love.graphics.pop()
end

function s.draw()
    local p = state.wasserbahn
    if not (p and p.version == TOY_VERSION) then return end
    -- the tower's basin and its water
    local bx, by, bw, bh = TOWER.x - TOWER.w / 2, TOWER.y - TOWER.h / 2, TOWER.w, TOWER.h
    setc(INK)
    love.graphics.rectangle('fill', bx - 8, by - 8, bw + 16, bh + 16, 18, 18)
    setc(RED)
    love.graphics.rectangle('fill', bx, by, bw, bh, 12, 12)
    local frac = math.min(1, p.tower / tune.total)
    setc(WATER)
    love.graphics.rectangle('fill', bx + 14, by + bh - 14 - (bh - 28) * frac, bw - 28, (bh - 28) * frac, 8, 8)
    setc(YELLOW)
    love.graphics.rectangle('fill', bx, by + 20, bw, 18)
    for _, g in ipairs(G) do drawGutter(g) end
    -- water on the gutters and falling
    for _, d in ipairs(p.drops) do
        if not d.held then
            local x, y
            if d.g then x, y = onGutter(d.g, d.s) else x, y = d.x, d.y end
            setc(WATER)
            love.graphics.circle('fill', x, y, DROP_R)
        end
    end
    -- a lock's pond: from where it starts, level, to the board
    for gi, lock in pairs(p.locks or {}) do
        if lock.L > 1 then
            local g = G[gi]
            local s0 = lock.gate - lock.L
            local ax, ay = g.x1 + g.ux * s0, g.y1 + g.uy * s0 - 10
            local bx2, by2 = g.x1 + g.ux * lock.gate, g.y1 + g.uy * lock.gate - 10
            setc(WATER)
            love.graphics.polygon('fill', ax, ay, bx2, by2 + 8, bx2, ay)
            setc(WATER_LIGHT, 0.8)
            love.graphics.rectangle('fill', ax + 10, ay - 2, bx2 - ax - 14, 5, 2, 2)
        end
    end
    setc(WATER_LIGHT, 0.8)
    for _, d in ipairs(p.drops) do
        if d.g and d.v > 120 then
            local x, y = onGutter(d.g, d.s)
            love.graphics.circle('fill', x - 3, y - 5, DROP_R * 0.35)
        end
    end
    -- the pool's water
    local top = poolTop(p)
    setc(WATER, 0.85)
    love.graphics.rectangle('fill', POOL.x0 + 6, top, POOL.x1 - POOL.x0 - 12, GROUND_Y - 4 - top, 10, 10)
    setc(WATER_LIGHT, 0.7)
    love.graphics.rectangle('fill', POOL.x0 + 20, top, POOL.x1 - POOL.x0 - 40, 6, 3, 3)
    -- the locks: a red board in a yellow frame, lifted when open
    for i, gate in ipairs(p.gates) do
        local gx, gy = gateWorld(i)
        setc(INK)
        love.graphics.rectangle('fill', gx - 34, gy - 150, 12, 170)
        love.graphics.rectangle('fill', gx + 22, gy - 150, 12, 170)
        love.graphics.rectangle('fill', gx - 34, gy - 156, 68, 16, 6, 6)
        setc(YELLOW)
        love.graphics.rectangle('fill', gx - 30, gy - 146, 6, 162)
        love.graphics.rectangle('fill', gx + 24, gy - 146, 6, 162)
        local lift = gate.lift * 100
        setc(INK)
        love.graphics.rectangle('fill', gx - 24, gy - 40 - lift, 48, 62, 6, 6)
        setc(RED)
        love.graphics.rectangle('fill', gx - 19, gy - 35 - lift, 38, 52, 4, 4)
        setc(WHITE)
        love.graphics.print(tostring(i), gx - 5, gy - 22 - lift)
    end
    -- the wheel
    local wl = p.wheel
    setc(INK)
    love.graphics.circle('fill', WHEEL.x, WHEEL.y, 22)
    love.graphics.setLineWidth(14)
    for k = 0, 7 do
        local a = wl.a + k * math.pi / 4
        local ex, ey = WHEEL.x + math.cos(a) * WHEEL.r, WHEEL.y + math.sin(a) * WHEEL.r
        setc(INK)
        love.graphics.line(WHEEL.x, WHEEL.y, ex, ey)
    end
    love.graphics.setLineWidth(8)
    for k = 0, 7 do
        local a = wl.a + k * math.pi / 4
        local ex, ey = WHEEL.x + math.cos(a) * WHEEL.r, WHEEL.y + math.sin(a) * WHEEL.r
        setc(k % 2 == 0 and YELLOW or RED)
        love.graphics.line(WHEEL.x + math.cos(a) * 20, WHEEL.y + math.sin(a) * 20, ex, ey)
    end
    love.graphics.setLineWidth(1)
    setc(YELLOW)
    love.graphics.circle('fill', WHEEL.x, WHEEL.y, 16)
    -- the boats
    for _, b in ipairs(p.boats) do if b.x then drawBoat(b) end end
    -- the pump: a post and a handle
    setc(INK)
    love.graphics.rectangle('fill', PUMP.x - 26, PUMP.y - 30, 52, GROUND_Y - PUMP.y + 30, 10, 10)
    setc(GREEN)
    love.graphics.rectangle('fill', PUMP.x - 19, PUMP.y - 23, 38, GROUND_Y - PUMP.y + 20, 8, 8)
    local hx, hy = handleEnd(p.pumpA)
    love.graphics.setLineWidth(22)
    setc(INK)
    love.graphics.line(PUMP.x, PUMP.y, hx, hy)
    love.graphics.setLineWidth(12)
    setc(RED)
    love.graphics.line(PUMP.x, PUMP.y, hx, hy)
    love.graphics.setLineWidth(1)
    setc(INK)
    love.graphics.circle('fill', hx, hy, 26)
    setc(YELLOW)
    love.graphics.circle('fill', hx, hy, 19)
    -- splashes
    love.graphics.setLineWidth(5)
    for _, q in ipairs(p.pops) do
        local k = q.t / 0.4
        setc(WATER_LIGHT, 1 - k)
        love.graphics.circle('line', q.x, q.y, 20 + 80 * k)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local p = state.wasserbahn
    if not (p and state.playMode and p.version == TOY_VERSION) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 320
    local rows = 5
    local ph = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - ph - 20
    s._panelRect = { x0, y0, w, ph }
    ui.panel(x0, y0, w, ph, '•• wasserbahn ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, (w - 26) / 2, p.gates[1].open and 'close lock 1' or 'open lock 1') then s.gate(1) end
        if ui.button(x + (w - 26) / 2 + 6, y, (w - 26) / 2, p.gates[2].open and 'close lock 2' or 'open lock 2') then
            s.gate(2)
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'pump (p, or the handle)') then s.pump() end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'start again (r)') then reset(p) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('wbout', x, y, 150, 5, 120, tune.outlet, nil, 1)
        if v then tune.outlet = v end
        ui.label(x + 250, y, 'tower tap')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('tower %d   pool %d   flowing %d', p.tower, p.pool, #p.drops))
    end)
end

-- From the bridge
function s.status()
    local p = wb()
    if p.version ~= TOY_VERSION then return 'none' end
    local boats = {}
    for i, b in ipairs(p.boats) do
        boats[i] = b.mode .. (b.g and ('@' .. b.g .. ':' .. math.floor(b.s or 0)) or '')
    end
    local held = {}
    local lists = byGutter(p)
    for i, l in ipairs(lists) do held[i] = #l end
    return { tower = p.tower, pool = p.pool, drops = #p.drops, onGutters = table.concat(held, ','),
        wheel = math.floor(p.wheel.w * 10) / 10, boats = table.concat(boats, ' '),
        gates = (p.gates[1].open and 'o' or 'x') .. (p.gates[2].open and 'o' or 'x') }
end

return s
