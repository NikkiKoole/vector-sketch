-- boat2: the boat spike again, the boat built from planks with drawn outlines (as in the planks spike) instead of the vector line art
-- v2 of `boat` (after experiments/walter-boat): the same sea, sky, smoke, fish and buoy (Nikki's
-- drawings), but the boat is planks: a clinker hull (rows of planks overlapping, riveted), a deck,
-- a cabin of upright planks with a window, a roof, a tin chimney, a railing in front of the Mipos.
-- Each plank is a fixture of one kinematic body, drawn with its own crayon outline and grain
-- (src/drawn-stroke.lua), nails where planks overlap. The chimney is its own body on a
-- springy weld. Layers (back / mid / front) per plank: drawn in that order, and back / front are the
-- engine's depth layers per fixture (src/depth-layers.lua setFixtureLayer): Mipos pass in front of the
-- cabin's back wall and can stand on its tops, never touch the railing. docs/DEPTH-LAYERS.md.
--
-- play mode (tab): drag the Mipos about (throw one overboard).
-- keys: left / right slower / faster   m a Mipo   b boil   r build again (the wonk slider)   h the panel

local s = {}

local SHAPES = love.filesystem.load('scripts/spikes/boat-shapes.lua')()
local SCROLL = 140           -- world units a second per step of speed
local WATER_Y = -60          -- the waves' middle line
local BOAT_Y = 80            -- where the boat's origin sits: its keel

local function boat()
    state.boat2 = state.boat2 or {
        mipos = {}, showPanel = true, speed = 1, target = 1, pos = 0, time = 0, accel = 0,
        smoke = {}, smokeTimer = 0, fish = {}, clouds = {}, buoyX = 1800,
        settings = { bob = 1, tip = 1, sway = 1, float = 1, width = 9, wobble = 1.2, boil = false },
    }
    state.boat2.settings.wonk = state.boat2.settings.wonk or 1 -- added later: live states lack it
    state.boat2.settings.splash = state.boat2.settings.splash or 1
    return state.boat2
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
    if DRAW.clouds then return DRAW end
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

-- The surface answers a Mipo (Nikki 2026-11-12: "a fast response to a mipo being pulled in", only
-- the layer it's in): a ring of springy columns along the surface, in the water's own x
-- (x + travel, so a ripple drifts back with the boat's travel), pushed by Mipo parts crossing it;
-- the front layer just in front of the Mipos (layer 4) shows it too, a bit less (layer.ripple).
local RIP_DX, RIP_N = 20, 256
local RIP_K, RIP_C, RIP_DAMP = 60, 350, 3 -- spring back (fast), spreading speed px/s, fading per s
local RIP_PUSH = 0.12 -- a crossing part's speed (px/s) into the surface's, per frame
local function ripples(b)
    b.rip = b.rip or { h = {}, v = {} }
    if not b.rip.h[1] then for i = 1, RIP_N do b.rip.h[i], b.rip.v[i] = 0, 0 end end
    return b.rip
end
local function ripIndex(u) return math.floor(u / RIP_DX) % RIP_N + 1 end
local function rippleAt(b, x)
    local rip = b.rip
    if not (rip and rip.h[1]) then return 0 end
    local u = (x + b.pos) / RIP_DX
    local i = math.floor(u)
    local a, c = rip.h[i % RIP_N + 1], rip.h[(i + 1) % RIP_N + 1]
    return a + (c - a) * (u - i)
end

-- the height of a wave layer at x: a few slow sines that scroll with the boat's travel
local function waveY(layer, x, b)
    local p = b.pos * layer.parallax
    local t = b.time
    local y = math.sin((x + p) * 0.004 + t * 0.9 + layer.phase) * 22
        + math.sin((x + p) * 0.0105 - t * 1.3 + layer.phase * 2) * 10
        + math.sin((x + p) * 0.021 + t * 2.1) * 4
    local wy = WATER_Y + layer.y + y * layer.amp
    if layer.ripple then wy = wy + rippleAt(b, x) * layer.ripple end
    return wy
end

local LAYERS = {
    { y = -90, amp = 0.6, parallax = 0.5, phase = 1.1, color = { 0.62, 0.78, 0.88 }, front = false },
    { y = -45, amp = 0.8, parallax = 0.75, phase = 2.3, color = { 0.42, 0.64, 0.82 }, front = false },
    { y = 0, amp = 1, parallax = 1, phase = 0, color = { 0.28, 0.5, 0.75 }, front = false, ripple = 1 },
    { y = 55, amp = 1.1, parallax = 1.25, phase = 3.7, color = { 0.2, 0.4, 0.66 }, front = true, alpha = 0.85,
      ripple = 0.7 }, -- the splash shows in front of the Mipo too
    { y = 120, amp = 1.2, parallax = 1.5, phase = 5.1, color = { 0.14, 0.3, 0.55 }, front = true, alpha = 0.6 },
}
local SURFACE = LAYERS[3] -- the boat rides on this one, and things float on it

-- a fixed hand-made wobble per point, like walter-boat's wave_offsets
local JITTER = {}
for i = 1, 400 do JITTER[i] = love.math.random() * 6 - 3 end

local function drawWave(layer, b, x0, x1, bottom)
    local step = layer.ripple and RIP_DX or 40 -- the rippling layers finer
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

---------------------------------------------------------------- the boat: planks (scripts/spikes/plank-boat.lua)

local plankBoat = love.filesystem.load('scripts/spikes/plank-boat.lua')()
local STROKE, CHIMNEY = plankBoat.STROKE, plankBoat.CHIMNEY
local function buildPlanks(b) plankBoat.buildPlanks(b) end
local placeNails, drawBoat = plankBoat.placeNails, plankBoat.drawBoat

local function makeBoat(b)
    if b.body and not b.body:isDestroyed() then return end
    buildPlanks(b)
    placeNails(b)
    local thing = objectManager.addThing('rectangle', { x = 0, y = BOAT_Y, width = 10, height = 10,
        bodyType = 'kinematic', label = 'boat2' })
    if not thing then return end
    local body = thing.body
    for _, fixture in ipairs(body:getFixtures()) do fixture:destroy() end
    for _, p in ipairs(b.planks) do
        local ok, shape = pcall(love.physics.newPolygonShape, p.pts)
        if ok and not p.chimney then
            local fixture = love.physics.newFixture(body, shape, 1)
            fixture:setFriction(0.9)
            -- the cabin's back wall and the railing: the engine's depth layers, per fixture (one body): Mipos
            -- pass in front of the back wall and can stand on its tops, never touch the railing
            if p.layer == 'back' or p.layer == 'front' then
                depthLayers.setFixtureLayer(fixture, p.layer)
            elseif not p.solid then
                fixture:setSensor(true)
            end
        end
    end
    b.body = body
    -- the chimney: its own body, light, on a springy weld at the roof, so it wobbles when the
    -- boat rocks and a Mipo can bump it or tug it
    local chim = objectManager.addThing('rectangle', { x = 0, y = BOAT_Y, width = 10, height = 10,
        bodyType = 'dynamic', label = 'boat2-chimney' })
    if chim then
        local cb = chim.body
        for _, fixture in ipairs(cb:getFixtures()) do fixture:destroy() end
        for _, p in ipairs(b.planks) do
            if p.chimney then
                local ok, shape = pcall(love.physics.newPolygonShape, p.pts)
                if ok then
                    local fixture = love.physics.newFixture(cb, shape, 0.3)
                    fixture:setFriction(0.6)
                end
            end
        end
        local base = b.chimney and { b.chimney[1], -1010 } or { -455, -1010 }
        local wx, wy = body:getWorldPoint(base[1], base[2])
        local joint = love.physics.newWeldJoint(body, cb, wx, wy, false)
        joint:setFrequency(4)
        joint:setDampingRatio(0.35)
        local id = 'boat2-chimney-weld-' .. tostring(love.math.random(1e6))
        joint:setUserData({ id = id, label = 'chimney' })
        registry.registerJoint(id, joint)
        b.chimneyBody = cb
    end
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
        spawnMipo(b, -60, -900)
        spawnMipo(b, 320, -900)
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
    local b = state.boat2
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
    elseif key == 'b' then b.settings.boil = not b.settings.boil
    elseif key == 'r' then -- build the boat again (another wonk)
        if b.chimneyBody and not b.chimneyBody:isDestroyed() then objectManager.destroyBody(b.chimneyBody) end
        if b.body and not b.body:isDestroyed() then objectManager.destroyBody(b.body) end
        b.body, b.chimneyBody = nil, nil
        makeBoat(b)
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end


-- A fish alive (Nikki 2026-11-12: "make the fish seem alive", for fun): it cruises at a speed it
-- changes now and then, sometimes darts or turns round (its facing eases through flat, a flip),
-- drifts to a new depth, and bolts away from a Mipo part in the water near it. Its tail beats
-- faster and wider the faster it swims (drawFish bends the drawing).
local FISH_TOP, FISH_BOTTOM = 200, 560 -- the depths they keep to
local FISH_FLEE = 380                 -- a Mipo part in the water nearer than this scares them
local function swimFish(f, wet, dt)
    f.face, f.sp, f.phase = f.face or f.dir, f.sp or f.speed, f.phase or 0
    f.cruise, f.ty, f.vy = f.cruise or f.speed, f.ty or f.y, f.vy or 0
    f.think, f.dart = (f.think or rnd(0.5, 3)) - dt, math.max(0, (f.dart or 0) - dt)
    if f.think <= 0 then
        f.think = rnd(1.5, 4)
        local r = love.math.random()
        if r < 0.15 then f.dir = -f.dir elseif r < 0.35 then f.dart = rnd(0.3, 0.6) end
        f.cruise = rnd(30, 140)
        f.ty = math.max(FISH_TOP, math.min(FISH_BOTTOM, f.y + rnd(-120, 120)))
    end
    for i = 1, #wet, 2 do
        local dx, dy = f.x - wet[i], f.y - wet[i + 1]
        if dx * dx + dy * dy < FISH_FLEE * FISH_FLEE then
            f.dir = dx < 0 and -1 or 1
            f.dart = math.max(f.dart, 0.7)
            f.ty = math.max(FISH_TOP, math.min(FISH_BOTTOM, f.y + (dy < 0 and -150 or 150)))
            break
        end
    end
    local target = f.cruise * (f.dart > 0 and 4 or 1)
    f.sp = f.sp + (target - f.sp) * math.min(1, dt * (f.dart > 0 and 6 or 1.5))
    f.face = f.face + (f.dir - f.face) * math.min(1, dt * 6)
    f.vy = f.vy + ((f.ty - f.y) * 1.5 - f.vy) * math.min(1, dt * 2)
    f.y = f.y + f.vy * dt
    f.phase = f.phase + dt * (5 + f.sp * 0.06)
    f.amp = math.min(12, 3 + f.sp * 0.03)
end

function s.update(dt)
    local b = state.boat2
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
        local front, back = 400, -440
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
    local rip = ripples(b)
    local rh, rv = rip.h, rip.v
    local wet = {} -- Mipo parts under the surface (x, y pairs), for the fish to flee
    for _, inst in ipairs(b.mipos) do
        for _, body in ipairs(partBodies(inst)) do
            local m = body:getMass()
            local px, py = body:getPosition()
            -- on board: a push against the change of speed, so they sway
            body:applyForce(-b.accel * m * g * 0.12 * set.sway, 0)
            -- in the water: float, slowed down, carried back by the boat's travel
            local depth = py - waveY(SURFACE, px, b)
            -- crossing the surface: its speed up or down pushes the surface there (down: a dip)
            if math.abs(depth) < 40 then
                local _, pvy = body:getLinearVelocity()
                local push = math.max(-500, math.min(500, pvy)) * RIP_PUSH * (set.splash or 1)
                local i = ripIndex(px + b.pos)
                rv[i] = rv[i] + push
                rv[(i - 2) % RIP_N + 1] = rv[(i - 2) % RIP_N + 1] + push * 0.5
                rv[i % RIP_N + 1] = rv[i % RIP_N + 1] + push * 0.5
            end
            if depth > 0 then
                wet[#wet + 1] = px
                wet[#wet + 1] = py
                local vx, vy = body:getLinearVelocity()
                local up = m * g * math.min(depth / 80, 1.6) * set.float
                local flow = -b.speed * SCROLL
                body:applyForce((flow - vx) * m * 2, -up - vy * m * 2.5)
            end
        end
    end

    -- the surface's columns: a stiff spring each (back fast), tied to their neighbours (spreading)
    local c2 = RIP_C * RIP_C / (RIP_DX * RIP_DX)
    local step = math.min(dt, 1 / 60)
    for i = 1, RIP_N do
        local l, r = rh[(i - 2) % RIP_N + 1], rh[i % RIP_N + 1]
        rv[i] = (rv[i] + (-RIP_K * rh[i] + c2 * (l + r - 2 * rh[i])) * step) * (1 - RIP_DAMP * step)
    end
    for i = 1, RIP_N do rh[i] = math.max(-80, math.min(80, rh[i] + rv[i] * step)) end

    -- smoke: puffs from the chimney, more often when going faster, blown back by the travel
    b.smokeTimer = b.smokeTimer - dt
    if b.smokeTimer <= 0 and b.body and not b.body:isDestroyed() then
        b.smokeTimer = 1.6 / (1 + math.abs(b.speed))
        local top = b.chimney or CHIMNEY
        local from = (b.chimneyBody and not b.chimneyBody:isDestroyed()) and b.chimneyBody or b.body
        local x, y = from:getWorldPoint(top[1], top[2])
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
        swimFish(f, wet, dt)
        f.x = f.x + (f.face * f.sp - b.speed * SCROLL) * dt
        if f.x < -2200 or f.x > 2200 then
            f.dir = f.x < 0 and 1 or -1
            f.face = f.dir
            f.x = f.x < 0 and -2100 or 2100
            f.y = rnd(260, 520)
            f.ty = f.y
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

-- the fish drawing bent by its swimming: a wave running from the head (left, x < 0 in the drawings)
-- to the tail, the head stiff and the tail swinging most (swimFish's phase and amp)
local fishShader
local function getFishShader()
    if fishShader == nil then
        local ok, sh = pcall(love.graphics.newShader, [[
            uniform float phase;
            uniform float amp;
            vec4 position(mat4 transform_projection, vec4 vertex_position) {
                float w = clamp((vertex_position.x + 30.0) / 70.0, 0.0, 1.0);
                vertex_position.y += sin(vertex_position.x * 0.08 - phase) * amp * w * w;
                return transform_projection * vertex_position;
            }
        ]])
        fishShader = ok and sh or false
    end
    return fishShader
end

local function drawFish(b, d)
    local shader = getFishShader()
    local before = love.graphics.getShader()
    for _, f in ipairs(b.fish) do
        local face = f.face or f.dir
        local pitch = math.max(-0.5, math.min(0.5, math.atan2(f.vy or 0, math.max(40, f.sp or f.speed))))
        love.graphics.push()
        love.graphics.translate(f.x, f.y)
        love.graphics.rotate(pitch * (face < 0 and -1 or 1)) -- nose toward where it's heading
        love.graphics.scale(-face * f.size, f.size) -- the drawings swim left
        if shader then
            shader:send('phase', f.phase or 0)
            shader:send('amp', f.amp or 4)
            love.graphics.setShader(shader)
        end
        drawShape(d.fish[f.kind], 0.9)
        love.graphics.setShader(before)
        love.graphics.pop()
    end
end

function s.drawBelow()
    local b = state.boat2
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
    local b = state.boat2
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    local d = drawings()
    local x0, _, x1, y1 = view()
    -- the near waves in front of the hull and the Mipos' feet, the fish between them
    drawBoat(b, true)
    drawWave(LAYERS[4], b, x0, x1, y1 + 50)
    drawFish(b, d)
    drawWave(LAYERS[5], b, x0, x1, y1 + 50)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.boat2 and boat()
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'bob', 0, 2 }, { 'tip', 0, 3 }, { 'sway', 0, 3 }, { 'float', 0, 2 }, { 'width', 2, 30 },
        { 'wobble', 0, 4 }, { 'wonk', 0, 3 }, { 'splash', 0, 3 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• boat2 ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('boat2' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key == 'wonk' and 'wonk (r: build)' or key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, string.format('speed %d  (left / right)', b.target))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'm a Mipo   b boil   r build again   h panel')
    end)
end

return s
