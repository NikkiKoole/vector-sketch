-- watergarden: a little plastic castle in a garden — pour water and the flowers grow where it gets wet.
-- Vintage toys idea (2026-11-16, Nikki: "a sort of toy i dont know the name, with it involved water and a little
-- plastic castle, flowers grew etc"; picked "pour water, things grow").
--
-- A jug: hold it to tip it and pour (drag it around while pouring), dip it in the pond to fill it again. The water
-- is drops (not Box2D: points with gravity) that land on what they meet: the castle's roofs shed them to the sides,
-- the funnel on the middle tower takes them in and they come out of the two spouts a moment later, and the soil
-- soaks them up: a cell of soil gets wetter (darker) and dries slowly. Seeds in the beds grow while their soil is
-- wet: a stem, leaves, a bud, and then the flower opens (a chime). The two Mipos watch the jug and cheer a bloom;
-- a drop on a Mipo makes a wet spot on it (src/dirt-look.lua's water spots: darker and glinting, it dries).
--
-- play mode (tab): hold the jug to pour, drag it; dip it in the pond. keys: r seeds again   g grow everything
-- From the bridge: s.status(); s.jugTo(x, y); s.pour(on)

local s = {}

local GROUND_W = 5000
local GROUND_Y = 0
local CELL = 40
local CELLS_X0 = -1500
local NCELLS = 75                      -- -1500 .. 1500
local POND_X0, POND_X1 = 1020, 1380    -- the pond, a dip at the right
local GRAVITY = 1400
local TOY_VERSION = 1

-- the castle: rectangles (x0, x1, top), from y = GROUND_Y up; the funnel on the middle tower
local CASTLE = {
    { -230, 230, -380 },  -- the hall
    { -290, -170, -540 }, -- left tower
    { 170, 290, -540 },   -- right tower
    { -75, 75, -720 },    -- middle tower
}
local FUNNEL = { -110, 110, -760 }    -- x0, x1, its rim
local SPOUTS = { { -230, -250, -1 }, { 230, -250, 1 } } -- x, y, which way

local tune = {
    pourRate = 70,    -- drops a second
    jugHolds = 600,   -- drops in a full jug
    soak = 0.05,      -- wetness a drop gives its soil cell
    dry = 0.025,      -- wetness lost a second
    grow = 0.11,      -- growth a second in soaked soil
    delay = 0.6,      -- seconds through the castle
    spotR = 45,       -- a drop on a Mipo wets this much round it
    spotWet = 0.35,   -- and this wet
}

local function wg()
    local p = state.watergarden
    if not p then
        p = { mipos = {}, pops = {}, drops = {}, inside = {}, blooms = 0 }
        state.watergarden = p
    end
    return p
end

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
    sounds.plink = make(0.12, function(t) -- a drop: a little falling sine
        local f = 1800 - t * 6000
        return math.sin(2 * math.pi * f * t) * math.exp(-t * 40) * 0.25
    end)
    sounds.chime = make(0.9, function(t) -- a bloom: two soft bells
        return (math.sin(2 * math.pi * 1046 * t) * 0.5 + math.sin(2 * math.pi * 1568 * t) * 0.3
            + math.sin(2 * math.pi * 2093 * t) * 0.12 * math.exp(-t * 6))
            * math.exp(-t * 4) * math.min(1, t / 0.005) * 0.4
    end)
    local pour = make(1.0, function() -- a trickle, looped
        return (love.math.random() * 2 - 1) * 0.12
    end)
    pour:setLooping(true)
    sounds.pour = pour
end

local function play(name, pitch, vol)
    if not (sounds and sounds[name]) then return end
    local src = sounds[name]:clone()
    src:setPitch(pitch or 1)
    src:setVolume(vol or 1)
    src:play()
end

---------------------------------------------------------------- the garden

local KINDS = {
    { name = 'tulip', petal = { 0.92, 0.25, 0.30 }, h = 210 },
    { name = 'daisy', petal = { 0.98, 0.97, 0.92 }, h = 170, heart = { 0.98, 0.78, 0.20 } },
    { name = 'sunflower', petal = { 0.98, 0.80, 0.15 }, h = 330, heart = { 0.45, 0.28, 0.12 } },
    { name = 'bell', petal = { 0.55, 0.50, 0.92 }, h = 190 },
    { name = 'rose', petal = { 0.96, 0.52, 0.68 }, h = 230, heart = { 0.85, 0.30, 0.48 } },
}

local function inBed(x)
    if x > -330 and x < 330 then return false end -- the castle
    if x > POND_X0 - 40 and x < POND_X1 + 40 then return false end
    return x > -1420 and x < 1450
end

local function sow(p)
    p.flowers = {}
    local x = -1380
    local k = 0
    while x < 1420 do
        if inBed(x) then
            k = k + 1
            local kind = KINDS[(k * 7) % #KINDS + 1]
            p.flowers[#p.flowers + 1] = { x = x, kind = kind, g = 0, phase = love.math.random() * 6,
                h = kind.h * (0.85 + love.math.random() * 0.3), bloomed = false }
        end
        x = x + 85 + love.math.random(-15, 15)
    end
    p.wet = {}
    for i = 1, NCELLS do p.wet[i] = 0 end
    p.blooms = 0
end

local function cellOf(x)
    local i = math.floor((x - CELLS_X0) / CELL) + 1
    if i < 1 or i > NCELLS then return nil end
    return i
end

local function makeGround(p)
    if p.ground and not p.ground:isDestroyed() then return end
    p.ground = love.physics.newBody(world, 0, 0, 'static')
    local top = love.physics.newFixture(p.ground,
        love.physics.newEdgeShape(-GROUND_W / 2, GROUND_Y, GROUND_W / 2, GROUND_Y))
    top:setFriction(0.9)
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(-GROUND_W / 2, GROUND_Y, -GROUND_W / 2, -3000))
    love.physics.newFixture(p.ground, love.physics.newEdgeShape(GROUND_W / 2, GROUND_Y, GROUND_W / 2, -3000))
    for _, r in ipairs(CASTLE) do
        local shape = love.physics.newRectangleShape((r[1] + r[2]) / 2, r[3] / 2, r[2] - r[1], -r[3])
        love.physics.newFixture(p.ground, shape)
    end
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[p.ground] = true
end

local function jugTarget()
    local p = state.watergarden
    if p and p.jug then return p.jug.x, p.jug.y end
    return 0, -600
end

local function addMipos(p)
    p.mipos = mipoKit.alive(p.mipos)
    if #p.mipos > 0 then return end
    for _, x in ipairs({ -900, 720 }) do
        local inst = mipoKit.spawn(p.mipos, x, GROUND_Y - 500)
        if inst then mipoActions.lookAt(inst, jugTarget) end
    end
end

function s.onStart()
    worldState.paused = false
    local p = wg()
    makeSounds()
    makeGround(p)
    if p.version ~= TOY_VERSION or not p.flowers then
        sow(p)
        p.jug = { x = -520, y = -980, tilt = 0, water = tune.jugHolds, vx = 0, vy = 0 }
        p.drops, p.inside = {}, {}
        p.version = TOY_VERSION
    end
    addMipos(p)
    camera.setBounds(-GROUND_W / 2, -2600, GROUND_W / 2, 400)
end

function s.onUnload()
    local p = state.watergarden
    if sounds and sounds.pour then sounds.pour:stop() end
    if not p then return end
    if p.ground and not p.ground:isDestroyed() then p.ground:destroy() end
    p.ground = nil
end

---------------------------------------------------------------- input

local function overPanel()
    local r = s._panelRect
    if not r then return false end
    local mx, my = love.mouse.getPosition()
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

local function holdJug(p)
    local jug = p.jug
    local down = state.playMode and love.mouse.isDown(1) and not overPanel()
    local mx, my = mouseWorldPos()
    if down and not p.wasDown then
        if math.sqrt((mx - jug.x) ^ 2 + (my - jug.y) ^ 2) < 220 then p.grab = { jug.x - mx, jug.y - my } end
    end
    if not down then p.grab = nil end
    p.wasDown = down
    local px, py = jug.x, jug.y
    if p.grab then
        p.jugGoal = nil
        jug.x, jug.y = mx + p.grab[1], math.min(GROUND_Y - 120, my + p.grab[2])
    elseif p.jugGoal then
        jug.x = jug.x + (p.jugGoal[1] - jug.x) * 0.15
        jug.y = jug.y + (p.jugGoal[2] - jug.y) * 0.15
    end
    jug.vx, jug.vy = (jug.x - px), (jug.y - py)
    local pouring = p.grab ~= nil or p.forcePour or (state.playMode and love.keyboard.isDown('space'))
    return pouring
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local p = wg()
    if key == 'r' then sow(p)
    elseif key == 'g' then
        for _, f in ipairs(p.flowers) do f.g = math.max(f.g, 0.99) end
    end
end

---------------------------------------------------------------- water

local function spoutOf(jug)
    -- the spout at the jug's upper left, turning with its tilt (counterclockwise: tilt > 0 tips it left)
    local lx, ly = -78, -70
    local c, sn = math.cos(-jug.tilt), math.sin(-jug.tilt)
    return jug.x + lx * c - ly * sn, jug.y + lx * sn + ly * c, -c, -sn
end

local function emit(p, dt)
    local jug = p.jug
    if jug.tilt < 0.9 or jug.water <= 0 then return end
    p.emitAcc = (p.emitAcc or 0) + dt * tune.pourRate * math.min(1, (jug.tilt - 0.9) / 0.6)
    while p.emitAcc >= 1 and jug.water > 0 do
        p.emitAcc = p.emitAcc - 1
        jug.water = jug.water - 1
        local sx, sy, dx, dy = spoutOf(jug)
        local sp = 120 + love.math.random() * 60
        p.drops[#p.drops + 1] = { x = sx + (love.math.random() - 0.5) * 8, y = sy,
            vx = dx * sp + jug.vx * 30 + (love.math.random() - 0.5) * 30, vy = dy * sp + 40 + jug.vy * 30, r = 9 }
    end
end

local function soak(p, x, amount)
    local i = cellOf(x)
    if not i then return end
    p.wet[i] = math.min(1, p.wet[i] + amount)
    if i > 1 then p.wet[i - 1] = math.min(1, p.wet[i - 1] + amount * 0.4) end
    if i < NCELLS then p.wet[i + 1] = math.min(1, p.wet[i + 1] + amount * 0.4) end
end

local function splash(p, x, y)
    if #p.pops < 40 then p.pops[#p.pops + 1] = { x = x, y = y, t = 0, kind = 'splash' } end
    p.plinkAt = p.plinkAt or 0
    local now = love.timer.getTime()
    if now - p.plinkAt > 0.07 then
        p.plinkAt = now
        play('plink', 0.8 + love.math.random() * 0.5, 0.5)
    end
end

-- a drop meeting the castle: the funnel takes it in; a roof sheds it to the nearer side
local function castleHit(p, d)
    if d.x > FUNNEL[1] and d.x < FUNNEL[2] and d.y >= FUNNEL[3] and d.y < FUNNEL[3] + 40 and d.vy > 0 then
        p.inside[#p.inside + 1] = { t = tune.delay + love.math.random() * 0.3 }
        return true
    end
    for _, r in ipairs(CASTLE) do
        if d.x > r[1] and d.x < r[2] and d.y >= r[3] and d.y < r[3] + 30 and d.vy > 0 then
            d.y = r[3]
            d.vy = -d.vy * 0.15
            local mid = (r[1] + r[2]) / 2
            d.vx = (d.x < mid and -1 or 1) * (120 + love.math.random() * 60)
            return false
        end
    end
    return false
end

-- a drop on a Mipo: a wet spot on what it hit (src/dirt-look.lua's water spots: darker, glinting, drying),
-- and the Mipo notices
local function mipoAt(x, y)
    local hit
    world:queryBoundingBox(x - 2, y - 2, x + 2, y + 2, function(fixture)
        if not fixture:isSensor() and fixture:testPoint(x, y) then
            local inst = mipoRegistry.getFromBody(fixture:getBody())
            if inst then
                hit = inst
                return false
            end
        end
        return true
    end)
    return hit
end

local function wetMipo(p, inst, x, y)
    state.dirtSpots = state.dirtSpots or {}
    if #state.dirtSpots < 8 then
        state.dirtSpots[#state.dirtSpots + 1] = { x = x, y = y, r = tune.spotR, amount = tune.spotWet }
    end
    splash(p, x, y)
    local now = love.timer.getTime()
    if now - (inst._wgNoticed or 0) > 2.5 then
        inst._wgNoticed = now
        mipoEmotion.set(inst, 'surprised', 1, 1.2)
        mipoVoice.squeak(inst, 'poke', 1.2)
    end
end

local function moveDrops(p, dt)
    for i = #p.drops, 1, -1 do
        local d = p.drops[i]
        d.vy = d.vy + GRAVITY * dt
        d.x = d.x + d.vx * dt
        d.y = d.y + d.vy * dt
        local gone = castleHit(p, d)
        if not gone then
            local inst = mipoAt(d.x, d.y)
            if inst then
                wetMipo(p, inst, d.x, d.y)
                gone = true
            end
        end
        if not gone and d.y >= GROUND_Y then
            if d.x > POND_X0 and d.x < POND_X1 then
                splash(p, d.x, GROUND_Y)
            else
                soak(p, d.x, tune.soak)
                splash(p, d.x, GROUND_Y)
            end
            gone = true
        end
        if gone or d.y > 2000 then table.remove(p.drops, i) end
    end
    -- water through the castle: out of the spouts, left and right in turn
    for i = #p.inside, 1, -1 do
        local w = p.inside[i]
        w.t = w.t - dt
        if w.t <= 0 then
            table.remove(p.inside, i)
            p.spoutTurn = ((p.spoutTurn or 0) % 2) + 1
            local sp = SPOUTS[p.spoutTurn]
            p.drops[#p.drops + 1] = { x = sp[1] + sp[3] * 50, y = sp[2],
                vx = sp[3] * (200 + love.math.random() * 260), vy = -40 + love.math.random() * 40, r = 9 }
        end
    end
end

---------------------------------------------------------------- growing

local function grow(p, dt)
    for i = 1, NCELLS do p.wet[i] = math.max(0, p.wet[i] - tune.dry * dt) end
    for _, f in ipairs(p.flowers) do
        local i = cellOf(f.x)
        local wet = i and p.wet[i] or 0
        if wet > 0.08 and f.g < 1 then
            f.g = math.min(1, f.g + tune.grow * dt * math.min(1, wet * 2))
        end
        if f.g >= 1 and not f.bloomed then
            f.bloomed = true
            f.bloomT = 0
            p.blooms = p.blooms + 1
            play('chime', 0.8 + ((p.blooms * 5) % 9) * 0.06, 0.8)
            p.pops[#p.pops + 1] = { x = f.x, y = GROUND_Y - f.h, t = 0, kind = 'bloom', color = f.kind.petal }
            if love.timer.getTime() - (p.cheeredAt or 0) > 1.5 then
                p.cheeredAt = love.timer.getTime()
                for _, inst in ipairs(mipoKit.alive(p.mipos)) do
                    mipoVoice.squeak(inst, 'happy')
                    mipoEmotion.set(inst, 'happy', 1, 2)
                end
            end
        end
        if f.bloomT then f.bloomT = math.min(1, f.bloomT + dt * 2) end
    end
end

function s.update(dt)
    local p = wg()
    if p.version ~= TOY_VERSION or not p.jug or dt <= 0 then return end
    local jug = p.jug
    local pouring = holdJug(p)
    local goal = pouring and 1.7 or 0
    jug.tilt = jug.tilt + (goal - jug.tilt) * math.min(1, dt * 6)
    -- dipped in the pond: it fills
    if jug.x > POND_X0 and jug.x < POND_X1 and jug.y > GROUND_Y - 200 then
        jug.water = math.min(tune.jugHolds, jug.water + dt * tune.jugHolds * 0.8)
    end
    emit(p, dt)
    moveDrops(p, dt)
    grow(p, dt)
    if sounds and sounds.pour then
        local on = jug.tilt > 0.9 and jug.water > 0
        if on and not sounds.pour:isPlaying() then sounds.pour:play() end
        if not on and sounds.pour:isPlaying() then sounds.pour:stop() end
    end
    for i = #p.pops, 1, -1 do
        local q = p.pops[i]
        q.t = q.t + dt
        if q.t > (q.kind == 'bloom' and 0.7 or 0.25) then table.remove(p.pops, i) end
    end
end

---------------------------------------------------------------- drawing

local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end
local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end

local SKY = { 0.78, 0.90, 0.97 }
local INK = { 0.20, 0.14, 0.14 }
local SOIL = { 0.66, 0.48, 0.32 }
local SOIL_WET = { 0.34, 0.22, 0.14 }
local GRASS = { 0.45, 0.72, 0.38 }
local STEM = { 0.30, 0.60, 0.28 }
local LEAF = { 0.40, 0.72, 0.34 }
local WATER = { 0.35, 0.65, 0.95 }
local WATER_LIGHT = { 0.75, 0.90, 1.0 }
local PINK = { 0.98, 0.76, 0.82 }
local PINK_DARK = { 0.90, 0.58, 0.68 }
local LILAC = { 0.74, 0.66, 0.92 }
local MINT = { 0.66, 0.90, 0.80 }
local YELLOW = { 0.98, 0.84, 0.30 }
local WHITE = { 1, 1, 1 }
local JUG = { 0.40, 0.70, 0.95 }
local JUG_DARK = { 0.26, 0.52, 0.80 }

function s.drawBelow()
    setc(SKY)
    love.graphics.rectangle('fill', -GROUND_W / 2, -3000, GROUND_W, 3000 + GROUND_Y)
    setc(WHITE, 0.8)
    for _, c in ipairs({ { -1100, -1500 }, { 300, -1700 }, { 1300, -1400 } }) do
        love.graphics.ellipse('fill', c[1], c[2], 160, 50)
        love.graphics.ellipse('fill', c[1] + 80, c[2] - 30, 100, 50)
    end
    local p = state.watergarden
    -- the soil, cell by cell, darker where wet
    for i = 1, NCELLS do
        local x = CELLS_X0 + (i - 1) * CELL
        local w = p and p.wet and p.wet[i] or 0
        setc(mix(SOIL, SOIL_WET, math.min(1, w * 1.4)))
        love.graphics.rectangle('fill', x, GROUND_Y, CELL + 1, 80)
    end
    setc(SOIL)
    love.graphics.rectangle('fill', -GROUND_W / 2, GROUND_Y, CELLS_X0 + GROUND_W / 2, 80)
    love.graphics.rectangle('fill', CELLS_X0 + NCELLS * CELL, GROUND_Y, GROUND_W, 80)
    setc(GRASS)
    love.graphics.rectangle('fill', -GROUND_W / 2, GROUND_Y + 80, GROUND_W, 700)
    -- the pond
    setc(INK)
    love.graphics.ellipse('fill', (POND_X0 + POND_X1) / 2, GROUND_Y + 10, (POND_X1 - POND_X0) / 2 + 8, 48)
    setc(WATER)
    love.graphics.ellipse('fill', (POND_X0 + POND_X1) / 2, GROUND_Y + 10, (POND_X1 - POND_X0) / 2, 40)
    setc(WATER_LIGHT, 0.7)
    love.graphics.ellipse('fill', (POND_X0 + POND_X1) / 2 - 60, GROUND_Y + 2, 60, 8)
    -- the castle: pastel plastic, crenellations, a door, the funnel on top, two spouts
    for k, r in ipairs(CASTLE) do
        local col = (k == 1) and PINK or ((k == 4) and LILAC or MINT)
        setc(INK)
        love.graphics.rectangle('fill', r[1] - 6, r[3] - 6, r[2] - r[1] + 12, -r[3] + 6, 10, 10)
        setc(col)
        love.graphics.rectangle('fill', r[1], r[3], r[2] - r[1], -r[3], 8, 8)
        -- crenellations
        local w = (r[2] - r[1])
        local n = math.max(2, math.floor(w / 50))
        for c = 0, n - 1 do
            if c % 2 == 0 then
                local cx = r[1] + c * w / n
                setc(INK)
                love.graphics.rectangle('fill', cx - 4, r[3] - 40, w / n + 8, 44, 6, 6)
                setc(col)
                love.graphics.rectangle('fill', cx, r[3] - 36, w / n, 40, 4, 4)
            end
        end
        -- a window
        if k > 1 then
            setc(INK)
            love.graphics.rectangle('fill', (r[1] + r[2]) / 2 - 18, r[3] + 60, 36, 60, 18, 18)
        end
    end
    setc(INK)
    love.graphics.rectangle('fill', -60, -170, 120, 170, 60, 60)
    setc(PINK_DARK)
    love.graphics.rectangle('fill', -50, -160, 100, 160, 50, 50)
    -- the funnel
    setc(INK)
    love.graphics.polygon('fill', FUNNEL[1] - 10, FUNNEL[3] - 6, FUNNEL[2] + 10, FUNNEL[3] - 6, 50, -712, -50, -712)
    setc(YELLOW)
    love.graphics.polygon('fill', FUNNEL[1], FUNNEL[3], FUNNEL[2], FUNNEL[3], 42, -718, -42, -718)
    -- the spouts: little fish heads
    for _, sp in ipairs(SPOUTS) do
        setc(INK)
        love.graphics.ellipse('fill', sp[1] + sp[3] * 30, sp[2], 40, 24)
        setc(YELLOW)
        love.graphics.ellipse('fill', sp[1] + sp[3] * 30, sp[2], 34, 18)
        setc(INK)
        love.graphics.circle('fill', sp[1] + sp[3] * 22, sp[2] - 6, 4)
        love.graphics.circle('fill', sp[1] + sp[3] * 62, sp[2], 7)
    end
end

local function drawFlower(f, now)
    local g = f.g
    if g <= 0.001 then
        setc(INK, 0.6)
        love.graphics.ellipse('fill', f.x, GROUND_Y + 6, 10, 5)
        return
    end
    local h = f.h * math.min(1, g / 0.75)
    local sway = math.sin(now * 1.3 + f.phase) * 0.04 * math.min(1, g * 2)
    local tx, ty = f.x + math.sin(sway) * h, GROUND_Y - math.cos(sway) * h
    love.graphics.setLineWidth(10)
    setc(INK)
    love.graphics.line(f.x, GROUND_Y, (f.x + tx) / 2 + sway * 60, (GROUND_Y + ty) / 2, tx, ty)
    love.graphics.setLineWidth(6)
    setc(STEM)
    love.graphics.line(f.x, GROUND_Y, (f.x + tx) / 2 + sway * 60, (GROUND_Y + ty) / 2, tx, ty)
    love.graphics.setLineWidth(1)
    -- leaves from 0.25
    if g > 0.25 then
        local l = math.min(1, (g - 0.25) / 0.25)
        local ly = GROUND_Y - h * 0.35
        for _, side in ipairs({ -1, 1 }) do
            setc(INK)
            love.graphics.ellipse('fill', f.x + side * 26 * l, ly - side * 8, 30 * l + 3, 12 * l + 3, side * 0.5)
            setc(LEAF)
            love.graphics.ellipse('fill', f.x + side * 26 * l, ly - side * 8, 28 * l, 10 * l, side * 0.5)
        end
    end
    -- a bud from 0.6, the flower open at 1
    if g > 0.6 then
        local open = f.bloomed and (f.bloomT or 1) or 0
        local bud = math.min(1, (g - 0.6) / 0.3)
        local k = f.kind
        local r = (14 + 10 * bud) * (1 + 0.5 * open)
        if k.name == 'tulip' or (k.name == 'bell' and open == 0) or open == 0 then
            setc(INK)
            love.graphics.ellipse('fill', tx, ty - r * 0.6, r * 0.75 + 4, r + 4)
            setc(open > 0 and k.petal or mix(LEAF, k.petal, bud * 0.6))
            love.graphics.ellipse('fill', tx, ty - r * 0.6, r * 0.75, r)
            if k.name == 'tulip' and open > 0 then
                setc(INK)
                love.graphics.polygon('fill', tx - r * 0.75, ty - r * 1.2, tx - r * 0.25, ty - r * 0.6,
                    tx, ty - r * 1.5, tx + r * 0.25, ty - r * 0.6, tx + r * 0.75, ty - r * 1.2,
                    tx + r * 0.75, ty - r * 0.5, tx - r * 0.75, ty - r * 0.5)
                setc(k.petal)
                love.graphics.polygon('fill', tx - r * 0.68, ty - r * 1.1, tx - r * 0.25, ty - r * 0.5,
                    tx, ty - r * 1.38, tx + r * 0.25, ty - r * 0.5, tx + r * 0.68, ty - r * 1.1,
                    tx + r * 0.68, ty - r * 0.5, tx - r * 0.68, ty - r * 0.5)
            end
        elseif k.name == 'bell' then
            setc(INK)
            love.graphics.arc('fill', tx, ty + 4, r + 4, math.pi * 0.05, math.pi * 0.95)
            setc(k.petal)
            love.graphics.arc('fill', tx, ty + 4, r, math.pi * 0.08, math.pi * 0.92)
        else
            -- petals round a heart, opening out
            local n = (k.name == 'sunflower') and 12 or ((k.name == 'rose') and 6 or 9)
            local pr = r * (k.name == 'sunflower' and 1.3 or 1)
            for i = 1, n do
                local a = i / n * 2 * math.pi + f.phase
                local px, py = tx + math.cos(a) * pr * 0.9 * open, ty + math.sin(a) * pr * 0.9 * open
                setc(INK)
                love.graphics.ellipse('fill', px, py, pr * 0.55 + 3, pr * 0.32 + 3, a)
                setc(k.petal)
                love.graphics.ellipse('fill', px, py, pr * 0.55, pr * 0.32, a)
            end
            setc(INK)
            love.graphics.circle('fill', tx, ty, pr * 0.45 + 3)
            setc(k.heart or YELLOW)
            love.graphics.circle('fill', tx, ty, pr * 0.45)
        end
    end
end

local function drawJug(p)
    local jug = p.jug
    love.graphics.push()
    love.graphics.translate(jug.x, jug.y)
    love.graphics.rotate(-jug.tilt)
    -- the handle at the right, the spout at the upper left
    love.graphics.setLineWidth(22)
    setc(INK)
    love.graphics.arc('line', 'open', 60, -10, 50, -math.pi / 2, math.pi / 2)
    love.graphics.setLineWidth(12)
    setc(JUG_DARK)
    love.graphics.arc('line', 'open', 60, -10, 50, -math.pi / 2, math.pi / 2)
    love.graphics.setLineWidth(1)
    setc(INK)
    love.graphics.polygon('fill', -60, -64, -96, -84, -88, -56, -60, -30)
    setc(JUG)
    love.graphics.polygon('fill', -58, -58, -88, -77, -82, -56, -58, -36)
    setc(INK)
    love.graphics.rectangle('fill', -68, -76, 136, 156, 30, 30)
    setc(JUG)
    love.graphics.rectangle('fill', -62, -70, 124, 144, 26, 26)
    -- how full: a window on the side
    local full = jug.water / tune.jugHolds
    setc(WATER_LIGHT, 0.9)
    love.graphics.rectangle('fill', -40, -40, 26, 100, 10, 10)
    setc(WATER)
    love.graphics.rectangle('fill', -40, -40 + 100 * (1 - full), 26, 100 * full, 10, 10)
    setc(WHITE, 0.6)
    love.graphics.ellipse('fill', 22, -40, 14, 26)
    love.graphics.pop()
end

function s.draw()
    local p = state.watergarden
    if not (p and p.version == TOY_VERSION and p.jug) then return end
    local now = love.timer.getTime()
    for _, f in ipairs(p.flowers) do drawFlower(f, now) end
    for _, d in ipairs(p.drops) do
        setc(WATER)
        love.graphics.circle('fill', d.x, d.y, d.r)
        setc(WATER_LIGHT)
        love.graphics.circle('fill', d.x - 3, d.y - 3, d.r * 0.4)
    end
    for _, q in ipairs(p.pops) do
        if q.kind == 'splash' then
            local k = q.t / 0.25
            setc(WATER, 1 - k)
            for a = -1, 1 do
                love.graphics.circle('fill', q.x + a * 18 * k, q.y - 20 * k + 30 * k * k, 5 * (1 - k) + 1)
            end
        else
            local k = q.t / 0.7
            local c = q.color or YELLOW
            love.graphics.setLineWidth(5)
            setc(c, 1 - k)
            love.graphics.circle('line', q.x, q.y, 30 + 120 * k)
            setc(WHITE, 1 - k)
            for a = 0, 5 do
                local ang = a / 6 * 2 * math.pi
                local rr = 40 + 90 * k
                love.graphics.circle('fill', q.x + math.cos(ang) * rr, q.y + math.sin(ang) * rr, 6)
            end
            love.graphics.setLineWidth(1)
        end
    end
    drawJug(p)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local p = state.watergarden
    if not (p and state.playMode and p.flowers) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 320
    local rows = 5
    local ph = BH * rows + pad * (rows + 1) + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - ph - 20
    s._panelRect = { x0, y0, w, ph }
    ui.panel(x0, y0, w, ph, '•• water garden ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'seeds again (r)') then sow(p) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('wggrow', x, y, 150, 0.02, 0.6, tune.grow, nil, 0.01)
        if v then tune.grow = v end
        ui.label(x + 250, y, 'growing')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('wgdry', x, y, 150, 0, 0.2, tune.dry, nil, 0.005)
        if v then tune.dry = v end
        ui.label(x + 250, y, 'drying')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('wgpour', x, y, 150, 10, 200, tune.pourRate, nil, 1)
        if v then tune.pourRate = v end
        ui.label(x + 250, y, 'pouring')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local grown = 0
        for _, f in ipairs(p.flowers) do if f.bloomed then grown = grown + 1 end end
        ui.label(x, y, string.format('hold the jug to pour   %d / %d', grown, #p.flowers))
    end)
end

-- From the bridge
function s.status()
    local p = wg()
    if not p.jug then return 'none' end
    local grown, sum = 0, 0
    for _, f in ipairs(p.flowers) do
        if f.bloomed then grown = grown + 1 end
        sum = sum + f.g
    end
    local wetCells = 0
    for i = 1, NCELLS do if p.wet[i] > 0.1 then wetCells = wetCells + 1 end end
    return { bloomed = grown, flowers = #p.flowers, growth = math.floor(sum * 10) / 10, drops = #p.drops,
        inside = #p.inside, jugWater = math.floor(p.jug.water), wetCells = wetCells,
        jug = { math.floor(p.jug.x), math.floor(p.jug.y) } }
end

function s.jugTo(x, y) wg().jugGoal = { x, y } end
function s.pour(on) wg().forcePour = on or nil end

return s
