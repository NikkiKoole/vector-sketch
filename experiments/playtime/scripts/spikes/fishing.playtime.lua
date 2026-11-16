-- fishing: the magnetic fishing game — a turning pond of fish opening and shutting their mouths, a rod with a magnet.
-- Vintage toys idea (2026-11-16, Nikki: "magnetic fsihing !").
--
-- The real toy: a round pond that turns, fish standing in it with their mouths up, opening and shutting as they go
-- round (a cam underneath); dangle the magnet on its line into an open mouth, it clicks on, lift the fish out.
-- Here: the pond is a drum seen a little from above, the fish on a ring around it (an ellipse, the back ones
-- behind), kinematic bodies put on the ring each frame. The rod's tip follows the finger; the magnet is a real
-- body on a rope joint, so it swings and lags. Near an open mouth it sticks: the fish turns dynamic, welded to the
-- magnet, and dangles. Lower it into the bucket and it drops in; the two Mipos watching cheer.
--
-- play mode (tab): drag anywhere to move the rod. keys: x let go of the fish   r all the fish back in the pond
-- From the bridge: s.status(); s.rodTo(x, y) moves the rod tip (until the finger moves it)

local s = {}

local GROUND_W = 5000
local TABLE_Y = 0
local POND_X, POND_Y = -180, -330     -- the middle of the pond's top (the water)
local POND_RX, POND_RY = 380, 110     -- the ring of fish, seen from a little above
local DRUM_RX, DRUM_RY = 450, 140     -- the drum's rim
local NFISH = 8
local FISH_H = 110
local BUCKET_X, BUCKET_W, BUCKET_H = 620, 260, 230
local LINE_LEN = 420
local GROUP = -29                     -- rod, magnet and fish on the ring don't collide with each other
local TOY_VERSION = 1

local tune = {
    spin = 0.35,     -- the pond's turn, radians a second
    catchR = 46,     -- the magnet sticks this close to an open mouth
    openAt = 0.5,    -- a mouth this open takes the magnet
    follow = 12,     -- how quick the rod's tip goes to the finger
}

local COLORS = {
    { 0.90, 0.25, 0.20 }, { 0.98, 0.70, 0.15 }, { 0.30, 0.62, 0.35 }, { 0.25, 0.50, 0.82 },
    { 0.62, 0.36, 0.72 }, { 0.96, 0.52, 0.62 }, { 0.20, 0.70, 0.72 }, { 0.95, 0.45, 0.15 },
}

local function fs()
    local p = state.fishing
    if not p then
        p = { mipos = {}, pops = {}, caught = 0, angle = 0 }
        state.fishing = p
    end
    return p
end

local function alive(b) return b and not b:isDestroyed() end

---------------------------------------------------------------- sounds

local sounds
local function makeSounds()
    if sounds then return end
    sounds = {}
    local rate = 22050
    local function make(len, fn)
        local data = love.sound.newSoundData(math.floor(rate * len), rate, 16, 1)
        for n = 0, data:getSampleCount() - 1 do
            data:setSample(n, math.max(-1, math.min(1, fn(n / rate))))
        end
        return love.audio.newSource(data, 'static')
    end
    sounds.click = make(0.06, function(t) -- the magnet clicking on: metal tick
        return (math.sin(2 * math.pi * 3300 * t) * 0.6 + (love.math.random() * 2 - 1) * 0.5) * math.exp(-t * 120) * 0.5
    end)
    sounds.plop = make(0.18, function(t) -- into the bucket: a hollow knock, falling
        local f = 420 - t * 900
        return math.sin(2 * math.pi * f * t) * math.exp(-t * 22) * 0.6
    end)
end

local function play(name, pitch)
    if not (sounds and sounds[name]) then return end
    local src = sounds[name]:clone()
    src:setPitch(pitch or 1)
    src:play()
end

---------------------------------------------------------------- the pond's ring

-- where fish i stands now: its foot on the ring, how near the front it is (-1 back .. 1 front), its size
local function ringSpot(p, i)
    local a = p.angle + (i - 1) * 2 * math.pi / NFISH
    local depth = math.sin(a)
    local x, y = POND_X + math.cos(a) * POND_RX, POND_Y + depth * POND_RY
    return x, y, depth, 0.85 + 0.15 * (depth + 1) / 2, a
end

-- the cam under the pond: a mouth opens and shuts twice a turn, each fish at its own moment
local function mouthOpen(a, i)
    local v = math.sin(a * 2 + i * 1.7)
    return math.max(0, math.min(1, (v - 0.1) * 1.6))
end

---------------------------------------------------------------- building

local function destroyToy(p)
    if p.toy then
        for _, b in ipairs({ p.toy.rod, p.toy.magnet }) do if alive(b) then b:destroy() end end
        for _, fish in ipairs(p.toy.fish) do if alive(fish.body) then fish.body:destroy() end end
    end
    p.toy = nil
end

local function makeFish(i)
    local body = love.physics.newBody(world, POND_X, POND_Y, 'kinematic')
    local f = love.physics.newFixture(body, love.physics.newRectangleShape(0, 0, 54, FISH_H))
    f:setGroupIndex(GROUP)
    f:setSensor(true)
    f:setDensity(1.2)
    f:setFriction(0.8)
    return { body = body, fixture = f, i = i, color = COLORS[(i - 1) % #COLORS + 1], open = 0, scale = 1, depth = 0 }
end

local function build(p)
    destroyToy(p)
    p.caught = 0
    local rod = love.physics.newBody(world, POND_X + 150, POND_Y - 650, 'kinematic')
    local magnet = love.physics.newBody(world, POND_X + 150, POND_Y - 650 + LINE_LEN, 'dynamic')
    local mf = love.physics.newFixture(magnet, love.physics.newCircleShape(20))
    mf:setGroupIndex(GROUP)
    mf:setDensity(3)
    magnet:resetMassData()
    magnet:setLinearDamping(0.3)
    magnet:setAngularDamping(2)
    love.physics.newRopeJoint(rod, magnet, rod:getX(), rod:getY(), magnet:getX(), magnet:getY(), LINE_LEN, false)
    local fish = {}
    for i = 1, NFISH do fish[i] = makeFish(i) end
    p.toy = { rod = rod, magnet = magnet, fish = fish, version = TOY_VERSION }
    p.rodGoal = { rod:getX(), rod:getY() }
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[rod] = true
    state.hiddenBodies[magnet] = true
    for _, f in ipairs(fish) do state.hiddenBodies[f.body] = true end
end

local function makeGround(p)
    if alive(p.ground) then return end
    p.ground = love.physics.newBody(world, 0, 0, 'static')
    local top = love.physics.newFixture(p.ground,
        love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, GROUND_W / 2, TABLE_Y))
    top:setFriction(0.9)
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(-GROUND_W / 2, TABLE_Y, -GROUND_W / 2, -3000))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(GROUND_W / 2, TABLE_Y, GROUND_W / 2, -3000))
    -- the bucket: two walls (a fish dropped in stays)
    local bx0, bx1 = BUCKET_X - BUCKET_W / 2, BUCKET_X + BUCKET_W / 2
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(bx0, TABLE_Y, bx0 - 20, TABLE_Y - BUCKET_H))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(bx1, TABLE_Y, bx1 + 20, TABLE_Y - BUCKET_H))
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[p.ground] = true
end

local function magnetTarget()
    local p = state.fishing
    local m = p and p.toy and p.toy.magnet
    if alive(m) then return m:getPosition() end
    return POND_X, POND_Y
end

local function addMipos(p)
    p.mipos = mipoKit.alive(p.mipos)
    if #p.mipos > 0 then return end
    for _, x in ipairs({ -800, 1150 }) do
        local inst = mipoKit.spawn(p.mipos, x, TABLE_Y - 500)
        if inst then mipoActions.lookAt(inst, magnetTarget) end
    end
end

function s.onStart()
    worldState.paused = false
    local p = fs()
    makeSounds()
    makeGround(p)
    if not (p.toy and alive(p.toy.rod) and p.toy.version == TOY_VERSION) then build(p) end
    addMipos(p)
    camera.setBounds(-GROUND_W / 2, -2600, GROUND_W / 2, 400)
end

function s.onUnload()
    local p = state.fishing
    if not p then return end
    destroyToy(p)
    if alive(p.ground) then p.ground:destroy() end
    p.ground = nil
end

---------------------------------------------------------------- playing

local function letGo(p)
    local toy = p.toy
    if toy.weld and not toy.weld:isDestroyed() then toy.weld:destroy() end
    toy.weld = nil
    if toy.hooked then toy.hooked.letGoAt = love.timer.getTime() end
    toy.hooked = nil
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local p = fs()
    if key == 'x' and p.toy then letGo(p)
    elseif key == 'r' then build(p) end
end

local function overPanel()
    local r = s._panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

local function moveRod(p)
    local rod = p.toy.rod
    local down = state.playMode and love.mouse.isDown(1) and not overPanel()
    local mx, my = mouseWorldPos()
    if down and not p.wasDown then p.grab = { rod:getX() - mx, rod:getY() - my } end
    if not down then p.grab = nil end
    p.wasDown = down
    if p.grab then p.rodGoal = { mx + p.grab[1], my + p.grab[2] } end
    local gx, gy = p.rodGoal[1], p.rodGoal[2]
    rod:setLinearVelocity((gx - rod:getX()) * tune.follow, (gy - rod:getY()) * tune.follow)
end

-- the fish on the ring follow the turning pond; mouths open and shut
local function turnPond(p, dt)
    p.angle = (p.angle + tune.spin * dt) % (2 * math.pi)
    for _, fish in ipairs(p.toy.fish) do
        if fish.onRing ~= false then
            local x, y, depth, scale, a = ringSpot(p, fish.i)
            fish.depth, fish.scale = depth, scale
            fish.open = mouthOpen(a, fish.i)
            fish.body:setPosition(x, y - FISH_H * scale / 2)
            fish.body:setAngle(0)
        end
    end
end

local function mouthOf(fish)
    return fish.body:getWorldPoint(0, -FISH_H * fish.scale / 2)
end

local function tryCatch(p)
    local toy = p.toy
    if toy.hooked then return end
    local mx, my = toy.magnet:getPosition()
    local best, bestD
    for _, fish in ipairs(toy.fish) do
        if fish.onRing ~= false and fish.open >= tune.openAt then
            local fx, fy = mouthOf(fish)
            local d = math.sqrt((fx - mx) ^ 2 + (fy - my) ^ 2)
            if d < tune.catchR and (not bestD or d < bestD) then best, bestD = fish, d end
        end
    end
    if not best then return end
    -- it clicks on: off the ring, a real fish now, welded to the magnet by its mouth
    local fish = best
    fish.onRing = false
    fish.body:setType('dynamic')
    fish.fixture:setSensor(false)
    fish.body:resetMassData()
    fish.body:setAngularDamping(1.5)
    local fx, fy = mouthOf(fish)
    toy.magnet:setPosition(fx, fy)
    toy.weld = love.physics.newWeldJoint(toy.magnet, fish.body, fx, fy, false)
    toy.hooked = fish
    fish.open = 1
    play('click', 0.95 + love.math.random() * 0.1)
    p.pops[#p.pops + 1] = { x = fx, y = fy, t = 0 }
    for _, inst in ipairs(mipoKit.alive(p.mipos)) do mipoEmotion.set(inst, 'surprised', 1, 0.8) end
end

-- a hooked fish over the bucket's mouth drops in; a fish in the bucket counts once
local function bucket(p)
    local toy = p.toy
    local fish = toy.hooked
    if fish then
        local x, y = fish.body:getPosition()
        if math.abs(x - BUCKET_X) < BUCKET_W / 2 - 30 and y > TABLE_Y - BUCKET_H - 60 then letGo(p) end
    end
    for _, f in ipairs(toy.fish) do
        if f.onRing == false and not f.inBucket and f ~= toy.hooked then
            local x, y = f.body:getPosition()
            if math.abs(x - BUCKET_X) < BUCKET_W / 2 + 10 and y > TABLE_Y - BUCKET_H and y < TABLE_Y then
                f.inBucket = true
                p.caught = p.caught + 1
                play('plop', 0.9 + love.math.random() * 0.2)
                p.pops[#p.pops + 1] = { x = x, y = TABLE_Y - BUCKET_H, t = 0 }
                for _, inst in ipairs(mipoKit.alive(p.mipos)) do
                    mipoVoice.squeak(inst, 'happy')
                    mipoEmotion.set(inst, 'happy', 1, 2)
                end
            end
        end
    end
end

function s.update(dt)
    local p = fs()
    if not (p.toy and alive(p.toy.rod) and p.toy.version == TOY_VERSION) then return end
    if dt <= 0 then return end
    moveRod(p)
    turnPond(p, dt)
    tryCatch(p)
    bucket(p)
    for i = #p.pops, 1, -1 do
        local q = p.pops[i]
        q.t = q.t + dt
        if q.t > 0.35 then table.remove(p.pops, i) end
    end
end

---------------------------------------------------------------- drawing

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local WALL = { 0.97, 0.90, 0.78 }
local WALL_CHECK = { 0.94, 0.84, 0.70 }
local TABLE = { 0.55, 0.70, 0.86 }
local TABLE_EDGE = { 0.40, 0.55, 0.72 }
local INK = { 0.20, 0.14, 0.12 }
local DRUM = { 0.95, 0.80, 0.20 }
local DRUM_DARK = { 0.82, 0.62, 0.10 }
local WATER = { 0.25, 0.58, 0.85 }
local WATER_LIGHT = { 0.55, 0.80, 0.95 }
local WHITE = { 0.98, 0.96, 0.92 }
local RED = { 0.86, 0.20, 0.16 }
local SILVER = { 0.78, 0.80, 0.82 }
local BAMBOO = { 0.82, 0.70, 0.42 }
local BAMBOO_DARK = { 0.60, 0.48, 0.24 }
local BUCKET = { 0.30, 0.60, 0.40 }
local BUCKET_DARK = { 0.20, 0.45, 0.30 }

function s.drawBelow()
    setc(WALL)
    love.graphics.rectangle('fill', -GROUND_W / 2, -3000, GROUND_W, 3000 + TABLE_Y)
    setc(WALL_CHECK)
    for y = -3000, TABLE_Y - 100, 200 do
        for x = -GROUND_W / 2, GROUND_W / 2, 200 do
            if ((x + y) / 200) % 2 == 0 then love.graphics.rectangle('fill', x, y, 100, 100) end
        end
    end
    setc(TABLE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y, GROUND_W, 110)
    setc(TABLE_EDGE)
    love.graphics.rectangle('fill', -GROUND_W / 2, TABLE_Y + 110, GROUND_W, 600)
    -- the drum: its side down to the table, its rim, the water
    setc(INK)
    love.graphics.rectangle('fill', POND_X - DRUM_RX - 6, POND_Y, DRUM_RX * 2 + 12, TABLE_Y - POND_Y)
    love.graphics.ellipse('fill', POND_X, TABLE_Y - 10, DRUM_RX + 6, 30)
    setc(DRUM)
    love.graphics.rectangle('fill', POND_X - DRUM_RX, POND_Y, DRUM_RX * 2, TABLE_Y - POND_Y - 10)
    love.graphics.ellipse('fill', POND_X, TABLE_Y - 10, DRUM_RX, 24)
    setc(DRUM_DARK)
    love.graphics.rectangle('fill', POND_X + DRUM_RX - 90, POND_Y, 70, TABLE_Y - POND_Y - 10)
    -- painted waves round the side
    setc(WHITE)
    love.graphics.setLineWidth(10)
    for k = 0, 7 do
        local x = POND_X - DRUM_RX + 50 + k * 105
        love.graphics.arc('line', 'open', x, POND_Y + 170, 34, math.pi, 2 * math.pi)
    end
    love.graphics.setLineWidth(1)
    setc(INK)
    love.graphics.ellipse('fill', POND_X, POND_Y, DRUM_RX + 8, DRUM_RY + 8)
    setc(RED)
    love.graphics.ellipse('fill', POND_X, POND_Y, DRUM_RX, DRUM_RY)
    setc(WATER)
    love.graphics.ellipse('fill', POND_X, POND_Y, DRUM_RX - 34, DRUM_RY - 20)
    setc(WATER_LIGHT, 0.7)
    local p = state.fishing
    local a = p and p.angle or 0
    for k = 0, 2 do
        local ang = a + k * 2.1
        love.graphics.ellipse('fill', POND_X + math.cos(ang) * 180, POND_Y + math.sin(ang) * 45, 46, 9)
    end
    -- the bucket, behind its fish
    local bx0 = BUCKET_X - BUCKET_W / 2
    setc(INK)
    love.graphics.polygon('fill', bx0 - 28, TABLE_Y - BUCKET_H - 6, bx0 + BUCKET_W + 28, TABLE_Y - BUCKET_H - 6,
        bx0 + BUCKET_W + 6, TABLE_Y, bx0 - 6, TABLE_Y)
    setc(BUCKET_DARK)
    love.graphics.polygon('fill', bx0 - 20, TABLE_Y - BUCKET_H, bx0 + BUCKET_W + 20, TABLE_Y - BUCKET_H,
        bx0 + BUCKET_W, TABLE_Y - 6, bx0, TABLE_Y - 6)
end

local function drawFish(fish)
    local x, y = fish.body:getPosition()
    local sc = fish.scale
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(fish.body:getAngle())
    love.graphics.scale(sc, sc)
    local h = FISH_H
    local c = fish.color
    local open = fish.open
    -- the tail, down at the foot
    setc(INK)
    love.graphics.polygon('fill', 0, h / 2 - 30, -34, h / 2 + 4, 34, h / 2 + 4)
    setc(c)
    love.graphics.polygon('fill', 0, h / 2 - 26, -27, h / 2 - 1, 27, h / 2 - 1)
    -- the body
    setc(INK)
    love.graphics.ellipse('fill', 0, 4, 33, h / 2 - 8)
    setc(c)
    love.graphics.ellipse('fill', 0, 4, 28, h / 2 - 13)
    -- a white belly stripe and its number
    setc(WHITE)
    love.graphics.ellipse('fill', 0, 14, 16, 18)
    setc(INK)
    love.graphics.print(tostring(fish.i), -5, 3)
    -- the mouth at the top: two lips, apart when open, with a steel ring inside
    local lip = 6 + open * 16
    setc(INK)
    love.graphics.ellipse('fill', -lip, -h / 2 + 10, 12, 16)
    love.graphics.ellipse('fill', lip, -h / 2 + 10, 12, 16)
    setc(SILVER)
    love.graphics.circle('fill', 0, -h / 2 + 14, 7 + open * 3)
    setc(c)
    love.graphics.ellipse('fill', -lip, -h / 2 + 10, 8, 12)
    love.graphics.ellipse('fill', lip, -h / 2 + 10, 8, 12)
    -- the eyes
    setc(WHITE)
    love.graphics.circle('fill', -14, -h / 2 + 34, 8)
    love.graphics.circle('fill', 14, -h / 2 + 34, 8)
    setc(INK)
    love.graphics.circle('fill', -13, -h / 2 + 35, 4)
    love.graphics.circle('fill', 13, -h / 2 + 35, 4)
    love.graphics.pop()
end

function s.draw()
    local p = state.fishing
    if not (p and p.toy and alive(p.toy.rod) and p.toy.version == TOY_VERSION) then return end
    local toy = p.toy
    -- fish on the ring, back first; caught ones after
    local order = {}
    for _, fish in ipairs(toy.fish) do if fish.onRing ~= false then order[#order + 1] = fish end end
    table.sort(order, function(a, b) return a.depth < b.depth end)
    for _, fish in ipairs(order) do drawFish(fish) end
    for _, fish in ipairs(toy.fish) do if fish.onRing == false then drawFish(fish) end end
    -- the bucket's front rim, over the fish inside
    local bx0 = BUCKET_X - BUCKET_W / 2
    setc(INK)
    love.graphics.rectangle('fill', bx0 - 30, TABLE_Y - BUCKET_H - 10, BUCKET_W + 60, 26, 10, 10)
    setc(BUCKET)
    love.graphics.rectangle('fill', bx0 - 24, TABLE_Y - BUCKET_H - 4, BUCKET_W + 48, 14, 7, 7)
    setc(INK)
    love.graphics.print(string.format('%d', p.caught), BUCKET_X - 6, TABLE_Y - 60, 0, 3, 3)
    -- the rod: a bamboo pole from off to the upper right down to its tip
    local rx, ry = toy.rod:getPosition()
    local hx, hy = rx + 700, ry - 260
    love.graphics.setLineWidth(22)
    setc(INK)
    love.graphics.line(hx, hy, rx, ry)
    love.graphics.setLineWidth(14)
    setc(BAMBOO)
    love.graphics.line(hx, hy, rx, ry)
    setc(BAMBOO_DARK)
    for k = 1, 4 do
        local t = k / 5
        love.graphics.circle('fill', rx + (hx - rx) * t, ry + (hy - ry) * t, 9)
    end
    -- the line: straight when taut, sagging when slack
    local mx, my = toy.magnet:getPosition()
    local d = math.sqrt((mx - rx) ^ 2 + (my - ry) ^ 2)
    local sag = math.max(0, LINE_LEN - d) * 0.6
    love.graphics.setLineWidth(3)
    setc(INK)
    local pts = {}
    for k = 0, 12 do
        local t = k / 12
        pts[#pts + 1] = rx + (mx - rx) * t
        pts[#pts + 1] = ry + (my - ry) * t + math.sin(t * math.pi) * sag
    end
    love.graphics.line(pts)
    -- the magnet: a red horseshoe with silver tips
    love.graphics.push()
    love.graphics.translate(mx, my)
    love.graphics.rotate(toy.magnet:getAngle())
    love.graphics.setLineWidth(14)
    setc(INK)
    love.graphics.arc('line', 'open', 0, -6, 20, math.pi, 2 * math.pi)
    love.graphics.setLineWidth(9)
    setc(RED)
    love.graphics.arc('line', 'open', 0, -6, 20, math.pi, 2 * math.pi)
    setc(INK)
    love.graphics.rectangle('fill', -27, -8, 14, 22)
    love.graphics.rectangle('fill', 13, -8, 14, 22)
    setc(SILVER)
    love.graphics.rectangle('fill', -24, 0, 8, 11)
    love.graphics.rectangle('fill', 16, 0, 8, 11)
    love.graphics.pop()
    -- clicks and plops
    love.graphics.setLineWidth(5)
    for _, q in ipairs(p.pops) do
        local k = q.t / 0.35
        love.graphics.setColor(1, 0.95, 0.6, 1 - k)
        love.graphics.circle('line', q.x, q.y, 20 + 70 * k)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local p = state.fishing
    if not (p and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 320
    local rows = 4
    local ph = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - ph - 20
    s._panelRect = { x0, y0, w, ph }
    ui.panel(x0, y0, w, ph, '•• magnetic fishing ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'all fish back (r)') then build(p) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('fspin', x, y, 150, 0, 1.5, tune.spin, nil, 0.01)
        if v then tune.spin = v end
        ui.label(x + 250, y, 'pond turns')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('fcatch', x, y, 150, 15, 120, tune.catchR, nil, 1)
        if v then tune.catchR = v end
        ui.label(x + 250, y, 'magnet pull')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('drag the rod; x lets go   caught: %d', p.caught))
    end)
end

-- From the bridge
function s.status()
    local p = fs()
    if not (p.toy and alive(p.toy.magnet)) then return 'none' end
    local mx, my = p.toy.magnet:getPosition()
    local open = {}
    for _, fish in ipairs(p.toy.fish) do
        if fish.onRing ~= false then
            local fx, fy = mouthOf(fish)
            open[#open + 1] = string.format('%d:%.1f@%d,%d', fish.i, fish.open, math.floor(fx), math.floor(fy))
        end
    end
    return { magnet = { math.floor(mx), math.floor(my) }, hooked = p.toy.hooked and p.toy.hooked.i or false,
        caught = p.caught, fish = table.concat(open, ' ') }
end

function s.rodTo(x, y) fs().rodGoal = { x, y } end

return s
