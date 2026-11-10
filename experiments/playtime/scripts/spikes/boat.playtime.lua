-- boat: a spike after experiments/walter-boat (2022): two Mipos on Nikki's little boat, sailing over drawn waves
-- The boat, clouds, smoke puffs, fish and the buoy are Nikki's drawings from walter-boat
-- (flattened into boat-shapes.lua); the two Mipos stand in for Walter and Olivia. The boat stays
-- in the middle; its speed is the world going by: the waves, clouds, fish and the buoy scroll past,
-- the smoke puffs blow back. Speeding up or slowing down tips the boat and sways the Mipos (a push
-- against the change); the waves bob it. A Mipo that falls in floats, and drifts behind.
--
-- play mode (tab): drag the Mipos about (throw one overboard).
-- keys: left / right slower / faster   m a Mipo   h the panel

local s = {}

local SHAPES = love.filesystem.load('scripts/spikes/boat-shapes.lua')()
local S = 2.2                -- boat units to world units
local SCROLL = 140           -- world units a second per step of speed
local WATER_Y = -60          -- the waves' middle line
local BOAT_Y = 40            -- where the boat's drawn origin sits (its keel at about y = 16 * S)

local function boat()
    state.boat = state.boat or {
        mipos = {}, showPanel = true, speed = 1, target = 1, pos = 0, time = 0, accel = 0,
        smoke = {}, smokeTimer = 0, fish = {}, clouds = {}, buoyX = 1800,
        settings = { bob = 1, tip = 1, sway = 1, float = 1 },
    }
    return state.boat
end

local function rnd(a, b) return a + love.math.random() * (b - a) end

---------------------------------------------------------------- the drawings as meshes

local function meshesOf(group)
    local out = {}
    for _, poly in ipairs(group) do
        local ok, tris = pcall(love.math.triangulate, poly.p)
        if ok and tris and #tris > 0 then
            local verts = {}
            for _, t in ipairs(tris) do
                for i = 1, 6, 2 do verts[#verts + 1] = { t[i], t[i + 1] } end
            end
            local mesh = love.graphics.newMesh({ { 'VertexPosition', 'float', 2 } }, verts, 'triangles', 'static')
            out[#out + 1] = { mesh = mesh, color = poly.c }
        end
    end
    return out
end

local DRAW = {}
local function drawings()
    if DRAW.boat then return DRAW end
    DRAW.boat = meshesOf(SHAPES.boat[1])
    DRAW.buoy = meshesOf(SHAPES.buoy[1])
    DRAW.clouds, DRAW.smoke, DRAW.fish = {}, {}, {}
    for i, g in ipairs(SHAPES.clouds) do DRAW.clouds[i] = meshesOf(g) end
    for i, g in ipairs(SHAPES.smoke) do DRAW.smoke[i] = meshesOf(g) end
    for i, g in ipairs(SHAPES.fish) do DRAW.fish[i] = meshesOf(g) end
    return DRAW
end

local function drawShape(meshes, alpha, tint)
    for _, m in ipairs(meshes) do
        local c = m.color
        local r, g, b = c[1], c[2], c[3]
        if tint then r, g, b = r * tint[1], g * tint[2], b * tint[3] end
        love.graphics.setColor(r, g, b, (c[4] or 1) * (alpha or 1))
        love.graphics.draw(m.mesh)
    end
end

---------------------------------------------------------------- the water

-- the height of a wave layer at x: a few slow sines that scroll with the boat's travel
local function waveY(layer, x, b)
    local p = b.pos * layer.parallax
    local t = b.time
    local y = math.sin((x + p) * 0.004 + t * 0.9 + layer.phase) * 22
        + math.sin((x + p) * 0.0105 - t * 1.3 + layer.phase * 2) * 10
        + math.sin((x + p) * 0.021 + t * 2.1) * 4
    return WATER_Y + layer.y + y * layer.amp
end

local LAYERS = {
    { y = -90, amp = 0.6, parallax = 0.5, phase = 1.1, color = { 0.62, 0.78, 0.88 }, front = false },
    { y = -45, amp = 0.8, parallax = 0.75, phase = 2.3, color = { 0.42, 0.64, 0.82 }, front = false },
    { y = 0, amp = 1, parallax = 1, phase = 0, color = { 0.28, 0.5, 0.75 }, front = false },
    { y = 55, amp = 1.1, parallax = 1.25, phase = 3.7, color = { 0.2, 0.4, 0.66 }, front = true, alpha = 0.85 },
    { y = 120, amp = 1.2, parallax = 1.5, phase = 5.1, color = { 0.14, 0.3, 0.55 }, front = true, alpha = 0.6 },
}
local SURFACE = LAYERS[3] -- the boat rides on this one, and things float on it

-- a fixed hand-made wobble per point, like walter-boat's wave_offsets
local JITTER = {}
for i = 1, 400 do JITTER[i] = love.math.random() * 6 - 3 end

local function drawWave(layer, b, x0, x1, bottom)
    local step = 40
    local first = math.floor(x0 / step) - 1
    local pts = {}
    for i = first, math.ceil(x1 / step) + 1 do
        local x = i * step
        local j = JITTER[(i % #JITTER) + 1]
        pts[#pts + 1] = x
        pts[#pts + 1] = waveY(layer, x, b) + j
    end
    local c = layer.color
    love.graphics.setColor(c[1], c[2], c[3], layer.alpha or 1)
    -- a strip of quads down to the bottom of the screen
    local verts = {}
    for i = 1, #pts - 2, 2 do
        local ax, ay, cx, cy = pts[i], pts[i + 1], pts[i + 2], pts[i + 3]
        verts[#verts + 1] = { ax, ay }; verts[#verts + 1] = { cx, cy }; verts[#verts + 1] = { ax, bottom }
        verts[#verts + 1] = { cx, cy }; verts[#verts + 1] = { cx, bottom }; verts[#verts + 1] = { ax, bottom }
    end
    if #verts >= 3 then
        local mesh = love.graphics.newMesh({ { 'VertexPosition', 'float', 2 } }, verts, 'triangles', 'stream')
        love.graphics.draw(mesh)
        mesh:release()
    end
    -- a pale crest line
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.setLineWidth(4)
    love.graphics.line(pts)
end

---------------------------------------------------------------- the boat's body

-- in boat units (the drawing's own): the deck, the cabin roof, the cabin's front wall, the bow
local DECK = { -152, -262, 236, -262, 236, -226, -152, -226 }
local ROOF = { -272, -400, -148, -400, -148, -386, -272, -386 }
local CABIN = { -168, -386, -150, -386, -150, -226, -168, -226 }
local BOW = { 236, -330, 262, -330, 262, -226, 236, -226 }

local function scaled(poly)
    local out = {}
    for i = 1, #poly, 2 do out[#out + 1] = poly[i] * S; out[#out + 1] = poly[i + 1] * S end
    return out
end

local function makeBoat(b)
    if b.body and not b.body:isDestroyed() then return end
    local deck = scaled(DECK)
    local cx, cy = mathutils.computeCentroid(deck)
    -- the body's origin is the drawing's origin: the shapes are given relative to it
    local thing = objectManager.addThing('rectangle', { x = 0, y = BOAT_Y, width = 10, height = 10,
        bodyType = 'kinematic', label = 'boat' })
    if not thing then return end
    local body = thing.body
    for _, fixture in ipairs(body:getFixtures()) do fixture:destroy() end
    for _, poly in ipairs({ DECK, ROOF, CABIN, BOW }) do
        local fixture = love.physics.newFixture(body, love.physics.newPolygonShape(scaled(poly)), 1)
        fixture:setFriction(0.9)
    end
    b.body = body
    b.deckX, b.deckY = cx, cy
end

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

local function spawnMipo(b, x, y) mipoKit.spawn(b.mipos, x, y) end -- src/mipo-kit.lua

local function partBodies(inst)
    local out = {}
    for _, part in pairs(inst.parts or {}) do
        if part.body and not part.body:isDestroyed() then out[#out + 1] = part.body end
    end
    return out
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = boat()
    makeBoat(b)
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -40 * S, -600)
        spawnMipo(b, 140 * S, -600)
    end
    if #b.fish == 0 then
        for i = 1, 7 do
            local dir = love.math.random() < 0.5 and -1 or 1
            b.fish[i] = { kind = love.math.random(#SHAPES.fish), x = rnd(-1500, 1500), y = rnd(260, 520),
                dir = dir, speed = rnd(60, 140), size = rnd(1.4, 2.2), wiggle = rnd(0, 6) }
        end
    end
    if #b.clouds == 0 then
        for i = 1, 6 do
            b.clouds[i] = { kind = love.math.random(#SHAPES.clouds), x = rnd(-1800, 1800), y = rnd(-1500, -900),
                size = rnd(2.5, 4), drift = rnd(0.15, 0.35) }
        end
    end
end

function s.onUnload()
    local b = state.boat
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = boat()
    if key == 'right' then b.target = math.min(6, b.target + 1)
    elseif key == 'left' then b.target = math.max(-2, b.target - 1)
    elseif key == 'm' then local mx, my = mouseWorldPos(); spawnMipo(b, mx, my)
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

-- the chimney's top, in boat units
local CHIMNEY = { -231, -421 }

function s.update(dt)
    local b = state.boat
    if not b or dt <= 0 or worldState.paused then return end
    local set = b.settings
    b.time = b.time + dt
    -- the speed eases to the target (walter-boat: flux over 3 s)
    local before = b.speed
    b.speed = b.speed + (b.target - b.speed) * math.min(1, dt * 0.9)
    local accel = (b.speed - before) / dt
    b.accel = b.accel + (accel - b.accel) * math.min(1, dt * 4)
    b.pos = b.pos + b.speed * SCROLL * dt

    -- the boat rides the surface: up and down with it, tipped along its slope, and tipped back
    -- when it speeds up (nose up), forward when it slows down
    if b.body and not b.body:isDestroyed() then
        local front, back = 180 * S, -200 * S
        local yf, yb = waveY(SURFACE, front, b), waveY(SURFACE, back, b)
        local ty = BOAT_Y + ((yf + yb) / 2 - WATER_Y) * 0.8 * set.bob
        local ta = math.atan2(yf - yb, front - back) * 0.6 * set.bob - b.accel * 0.05 * set.tip
        local x, y = b.body:getPosition()
        local a = b.body:getAngle()
        b.body:setLinearVelocity((0 - x) / dt * 0.5, (ty - y) / dt * 0.5)
        b.body:setAngularVelocity((ta - a) / dt * 0.5)
    end

    local gx, gy = state.physicsWorld:getGravity()
    local g = math.sqrt(gx * gx + gy * gy)
    b.mipos = aliveMipos(b)
    for _, inst in ipairs(b.mipos) do
        for _, body in ipairs(partBodies(inst)) do
            local m = body:getMass()
            local px, py = body:getPosition()
            -- on board: a push against the change of speed, so they sway
            body:applyForce(-b.accel * m * g * 0.12 * set.sway, 0)
            -- in the water: float, slowed down, carried back by the boat's travel
            local depth = py - waveY(SURFACE, px, b)
            if depth > 0 then
                local vx, vy = body:getLinearVelocity()
                local up = m * g * math.min(depth / 80, 1.6) * set.float
                local flow = -b.speed * SCROLL
                body:applyForce((flow - vx) * m * 2, -up - vy * m * 2.5)
            end
        end
    end

    -- smoke: puffs from the chimney, more often when going faster, blown back by the travel
    b.smokeTimer = b.smokeTimer - dt
    if b.smokeTimer <= 0 and b.body and not b.body:isDestroyed() then
        b.smokeTimer = 1.6 / (1 + math.abs(b.speed))
        local x, y = b.body:getWorldPoint(CHIMNEY[1] * S, CHIMNEY[2] * S)
        b.smoke[#b.smoke + 1] = { kind = love.math.random(#SHAPES.smoke), x = x, y = y, age = 0,
            life = rnd(2.5, 3.5), spin = rnd(-0.6, 0.6), angle = rnd(0, 6) }
    end
    local kept = {}
    for _, p in ipairs(b.smoke) do
        p.age = p.age + dt
        p.x = p.x - (b.speed * SCROLL * 0.9 + 10) * dt
        p.y = p.y - 70 * dt
        p.angle = p.angle + p.spin * dt
        if p.age < p.life then kept[#kept + 1] = p end
    end
    b.smoke = kept

    -- fish swim both ways; the travel carries them back; past the edge they come round again
    for _, f in ipairs(b.fish) do
        f.x = f.x + (f.dir * f.speed - b.speed * SCROLL) * dt
        if f.x < -2200 or f.x > 2200 then
            f.dir = f.x < 0 and 1 or -1
            f.x = f.x < 0 and -2100 or 2100
            f.y = rnd(260, 520)
        end
    end
    for _, c in ipairs(b.clouds) do
        c.x = c.x - (b.speed * SCROLL * c.drift + 8) * dt
        if c.x < -2600 then c.x = 2600 elseif c.x > 2600 then c.x = -2600 end
    end
    b.buoyX = b.buoyX - b.speed * SCROLL * dt
    if b.buoyX < -2400 then b.buoyX = rnd(2400, 4000) elseif b.buoyX > 4200 then b.buoyX = -2300 end
end

---------------------------------------------------------------- drawing

local function view()
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getDimensions())
    return x0, y0, x1, y1
end

local function drawBoat(b)
    local d = drawings()
    if not (b.body and not b.body:isDestroyed()) then return end
    local x, y = b.body:getPosition()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(b.body:getAngle())
    love.graphics.scale(S)
    drawShape(d.boat)
    love.graphics.pop()
end

local function drawFish(b, d)
    for _, f in ipairs(b.fish) do
        love.graphics.push()
        love.graphics.translate(f.x, f.y + math.sin(b.time * 2 + f.wiggle) * 8)
        love.graphics.rotate(math.sin(b.time * 3 + f.wiggle) * 0.08)
        love.graphics.scale(-f.dir * f.size, f.size) -- the drawings swim left
        drawShape(d.fish[f.kind], 0.9)
        love.graphics.pop()
    end
end

function s.drawBelow()
    local b = state.boat
    if not b then return end
    local d = drawings()
    local x0, y0, x1, y1 = view()
    -- the sky
    love.graphics.push()
    love.graphics.origin()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.67, 0.83, 0.92)
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.pop()
    -- clouds, see-through like walter-boat's
    for _, c in ipairs(b.clouds) do
        love.graphics.push()
        love.graphics.translate(c.x + b.pos * 0, c.y)
        love.graphics.scale(c.size)
        drawShape(d.clouds[c.kind], 0.6)
        love.graphics.pop()
    end
    -- the far waves
    for _, layer in ipairs(LAYERS) do
        if not layer.front then drawWave(layer, b, x0, x1, y1 + 50) end
    end
    -- the buoy, bobbing on the surface
    love.graphics.push()
    local by = waveY(SURFACE, b.buoyX, b)
    love.graphics.translate(b.buoyX, by + 20)
    love.graphics.rotate(math.sin(b.time * 1.7) * 0.15)
    love.graphics.scale(2.2)
    drawShape(d.buoy)
    love.graphics.pop()
    drawBoat(b)
    -- smoke puffs: grow and fade
    for _, p in ipairs(b.smoke) do
        local t = p.age / p.life
        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(p.angle)
        love.graphics.scale(0.8 + t * 2.2)
        drawShape(d.smoke[p.kind], (1 - t) * 0.8)
        love.graphics.pop()
    end
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.boat
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    local d = drawings()
    local x0, _, x1, y1 = view()
    -- the near waves in front of the hull and the Mipos' feet, the fish between them
    drawWave(LAYERS[4], b, x0, x1, y1 + 50)
    drawFish(b, d)
    drawWave(LAYERS[5], b, x0, x1, y1 + 50)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.boat
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'bob', 0, 2 }, { 'tip', 0, 3 }, { 'sway', 0, 3 }, { 'float', 0, 2 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• boat ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('boat' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('speed %d  (left / right)', b.target))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'm a Mipo   h panel')
    end)
end

return s
