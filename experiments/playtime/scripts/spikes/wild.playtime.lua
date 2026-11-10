-- wild: a spike for one slider between order and chaos, culture and nature: a plank shed that goes from fresh and tidy to grimy, crooked and overgrown
-- One master slider, `wild` (0 tidy .. 1 wild), and three under it that say how much of each it
-- brings (0..1.5 times the master):
-- - chaos: planks turn and lose true, some come loose and hang from one nail;
-- - grime: fresh paint fades to grey weathered wood, darker; stains, rust running down from nails;
-- - growth: moss creeping along the bottoms and the roof's edge, vines climbing the walls and
--   leafing out, the lawn growing into tall weeds with flowers.
-- Everything drawn, no shader: the planks with Nikki's crayon strokes (src/drawn-stroke.lua), the
-- weeds from the grass blade atlas (textures/world/sprieten.png). Chaos goes in twelve steps (the
-- outlines are made again at each, and kept), so it moves like stop-motion.
--
-- play mode (tab): drag the Mipos about.
-- keys: 1 tidy  2 half  3 wild   m a Mipo   r new shed (other planks)   h the panel

local s = {}

local STROKE = drawnStroke()
local OUTLINE = { 0.2, 0.13, 0.1 }
local GROUND_Y = 0
local LEVELS = 12 -- chaos steps

local function wild()
    state.wild = state.wild or {
        planks = {}, mipos = {}, showPanel = true, time = 0,
        settings = { wild = 0.5, chaos = 1, grime = 1, growth = 1, width = 9, wobble = 1.2 },
    }
    return state.wild
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end
local function smooth(x) x = clamp(x, 0, 1); return x * x * (3 - 2 * x) end
local function lerp(a, b, t) return a + (b - a) * t end
local function lerpColor(a, b, t) return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) } end

local function amounts(b)
    local set = b.settings
    return clamp(set.wild * set.chaos, 0, 1), clamp(set.wild * set.grime, 0, 1), clamp(set.wild * set.growth, 0, 1)
end

---------------------------------------------------------------- the planks

local PAINT = { -- fresh: a red shed with cream trim, a white fence
    wall = { 0.78, 0.26, 0.22 }, trim = { 0.95, 0.92, 0.82 }, roof = { 0.3, 0.32, 0.36 },
    door = { 0.25, 0.42, 0.55 }, fence = { 0.96, 0.95, 0.9 },
}
local WEATHERED = { { 0.55, 0.5, 0.45 }, { 0.5, 0.46, 0.42 }, { 0.6, 0.55, 0.48 }, { 0.47, 0.43, 0.4 } }

-- a plank from (x1, y1) to (x2, y2), thick wide. Everything that's random about it is drawn now and
-- kept (with its own seed), so each step of chaos moves the same plank the same way.
local function plank(b, x1, y1, x2, y2, thick, paint, layer, rng)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    local ux, uy = dx / len, dy / len
    local nx, ny = -uy * thick / 2, ux * thick / 2
    local p = {
        base = { x1 - nx, y1 - ny, x2 - nx, y2 - ny, x2 + nx, y2 + ny, x1 + nx, y1 + ny },
        len = len, thick = thick, layer = layer or 'back',
        paint = paint, wood = WEATHERED[rng:random(#WEATHERED)],
        seed = rng:random() * 1000, turn = rng:random() * 2 - 1, delta = {},
        loose = rng:random() < 0.22 and (0.45 + rng:random() * 0.45) or nil, -- comes loose at this chaos
        hang = rng:random() < 0.5 and 1 or 2, swing = (0.25 + rng:random() * 0.35) * (rng:random() < 0.5 and -1 or 1),
        stains = {}, cache = {},
    }
    for k = 1, 8 do p.delta[k] = rng:random() * 2 - 1 end
    for k = 1, 1 + rng:random(2) do
        p.stains[k] = { u = rng:random() * 0.8 + 0.1, v = 0.55 + rng:random() * 0.3,
            rx = 0.06 + rng:random() * 0.12, ry = 0.15 + rng:random() * 0.2, th = rng:random() * 0.6 }
    end
    b.planks[#b.planks + 1] = p
    return p
end

local function rotateAbout(pts, cx, cy, a)
    local c, sn = math.cos(a), math.sin(a)
    for i = 1, #pts, 2 do
        local x, y = pts[i] - cx, pts[i + 1] - cy
        pts[i], pts[i + 1] = cx + x * c - y * sn, cy + x * sn + y * c
    end
end

-- the plank at a chaos level: turned, its corners pushed off true; a loose one hangs from one end
local function shapeAt(p, c)
    local q = {}
    for i = 1, 8 do q[i] = p.base[i] end
    local cx, cy = (q[1] + q[3] + q[5] + q[7]) / 4, (q[2] + q[4] + q[6] + q[8]) / 4
    rotateAbout(q, cx, cy, p.turn * c * math.min(0.07, 40 / p.len))
    local push = 10 * c
    for i = 1, 8 do q[i] = q[i] + p.delta[i] * push end
    if p.loose and c > p.loose then
        -- it hangs from its higher end (a long rail from either), and the free end swings down
        local t = smooth((c - p.loose) / (1 - p.loose))
        local ax, ay = (q[1] + q[7]) / 2, (q[2] + q[8]) / 2
        local bx, by = (q[3] + q[5]) / 2, (q[4] + q[6]) / 2
        local upright = math.abs(by - ay) > math.abs(bx - ax)
        local fromA = upright and ay < by or (not upright and p.hang == 1)
        local px, py, fx, fy = ax, ay, bx, by
        if not fromA then px, py, fx, fy = bx, by, ax, ay end
        local amount = math.abs(p.swing) * math.min(1, 300 / p.len) * t
        -- the way round that takes the free end down
        local dx, dy = fx - px, fy - py
        local down = (dx * math.sin(amount) + dy * math.cos(amount)) > (-dx * math.sin(amount) + dy * math.cos(amount))
        rotateAbout(q, px, py, down and amount or -amount)
    end
    return q
end

-- the look at a level: the outline and the grain as stroke meshes, and where the nails go
local function lookAt(b, p, level)
    local set = b.settings
    local key = level .. ',' .. set.width .. ',' .. set.wobble
    local hit = p.cache[key]
    if hit then return hit end
    local q = shapeAt(p, level / LEVELS)
    local rng = love.math.newRandomGenerator(math.floor(p.seed * 1000))
    local ox, oy = p.seed * 997 % 20000, p.seed * 613 % 20000
    local outline = {}
    for i = 1, 8, 2 do outline[#outline + 1] = { q[i] + ox, q[i + 1] + oy } end
    local function at(u, v)
        local x1, y1 = q[1] + (q[3] - q[1]) * u, q[2] + (q[4] - q[2]) * u
        local x2, y2 = q[7] + (q[5] - q[7]) * u, q[8] + (q[6] - q[8]) * u
        return x1 + (x2 - x1) * v, y1 + (y2 - y1) * v
    end
    local grain = {}
    for i = 1, math.max(1, math.floor(p.thick / 30)) do
        local v = 0.2 + rng:random() * 0.6
        local u0, u1 = 0.05 + rng:random() * 0.35, 0.6 + rng:random() * 0.35
        local line = {}
        for k = 0, 6 do
            local u = u0 + (u1 - u0) * k / 6
            local x, y = at(u, v + math.sin(u * 7 + i) * 0.04)
            line[#line + 1] = { x + ox, y + oy }
        end
        grain[#grain + 1] = { pts = line, loop = false, width = 5, wobble = 0.6 }
    end
    local nails = {}
    for _, u in ipairs({ 0.07, 0.93 }) do
        local lost = false
        if p.loose and level / LEVELS > p.loose then
            local ay, by = (q[2] + q[8]) / 2, (q[4] + q[6]) / 2
            local ax, bx = (q[1] + q[7]) / 2, (q[3] + q[5]) / 2
            local upright = math.abs(by - ay) > math.abs(bx - ax)
            local fromA = upright and ay < by or (not upright and p.hang == 1)
            lost = (fromA and u > 0.5) or (not fromA and u < 0.5)
        end
        if not lost then
            local x, y = at(u, 0.5)
            nails[#nails + 1] = { x, y }
        end
    end
    hit = {
        pts = q, at = at, nails = nails, ox = ox, oy = oy,
        outline = STROKE.meshes({ { pts = outline, loop = true, width = set.width } }, set.wobble, 0, true),
        grain = STROKE.meshes(grain, set.wobble, 0, true),
    }
    p.cache[key] = hit
    return hit
end

---------------------------------------------------------------- the shed, the fence

local function buildShed(b, seed)
    local rng = love.math.newRandomGenerator(seed)
    b.planks = {}
    b.seed = seed
    local top = -720
    -- the walls: upright planks, a door, a window
    local x = -520
    local i = 0
    while x < 520 do
        local w = 88 + rng:random() * 18
        local mid = x + w / 2
        i = i + 1
        local paint = PAINT.wall
        if i == 3 or i == 4 then -- the door
            plank(b, mid, GROUND_Y - 10, mid, -560, w, PAINT.door, 'back', rng)
            plank(b, mid, -580, mid, top, w, paint, 'back', rng)
        elseif i == 7 or i == 8 then -- the window
            plank(b, mid, GROUND_Y - 10, mid, -330, w, paint, 'back', rng)
            plank(b, mid, -560, mid, top, w, paint, 'back', rng)
        else
            plank(b, mid, GROUND_Y - 10, mid, top, w, paint, 'back', rng)
        end
        x = x + w + 4
    end
    -- trim: the door's frame, the window's frame and its cross, the corners, a sill
    local function at(k) return -520 + (k - 1) * 101 end
    plank(b, at(3) - 10, -585, at(5) + 10, -585, 30, PAINT.trim, 'back', rng)
    plank(b, at(3) - 6, GROUND_Y - 10, at(3) - 6, -590, 26, PAINT.trim, 'back', rng)
    plank(b, at(5) + 6, GROUND_Y - 10, at(5) + 6, -590, 26, PAINT.trim, 'back', rng)
    plank(b, at(7) - 15, -330, at(9) + 15, -330, 30, PAINT.trim, 'back', rng)
    plank(b, at(7) - 15, -560, at(9) + 15, -560, 30, PAINT.trim, 'back', rng)
    plank(b, at(7) - 4, -320, at(7) - 4, -570, 24, PAINT.trim, 'back', rng)
    plank(b, at(9) + 4, -320, at(9) + 4, -570, 24, PAINT.trim, 'back', rng)
    plank(b, (at(7) + at(9)) / 2, -320, (at(7) + at(9)) / 2, -570, 18, PAINT.trim, 'back', rng)
    plank(b, at(7), -445, at(9), -445, 16, PAINT.trim, 'back', rng)
    plank(b, -540, GROUND_Y - 5, -540, top - 10, 40, PAINT.trim, 'back', rng)
    plank(b, 540, GROUND_Y - 5, 540, top - 10, 40, PAINT.trim, 'back', rng)
    -- the roof: two slopes of planks, a ridge board
    for side = -1, 1, 2 do
        plank(b, side * 660, top + 30, side * 330, top - 165, 60, PAINT.roof, 'roof', rng)
        plank(b, side * 360, top - 150, side * -10, top - 375, 60, PAINT.roof, 'roof', rng)
        plank(b, side * 640, top + 5, side * 320, top - 190, 26, PAINT.trim, 'roof', rng)
    end
    plank(b, -70, top - 385, 70, top - 386, 34, PAINT.trim, 'roof', rng)
    -- the fence, in front of the Mipos
    for k = 0, 6 do
        local px = 760 + k * 130
        plank(b, px, GROUND_Y + 15, px, -300 - rng:random() * 30, 36, PAINT.fence, 'front', rng)
    end
    plank(b, 720, -250, 1580, -252, 30, PAINT.fence, 'front', rng)
    plank(b, 720, -110, 1580, -108, 30, PAINT.fence, 'front', rng)

    -- what grows: moss spots (along the shed's foot, the roof's lower edge, the fence's feet),
    -- vines (paths up the walls), weeds and flowers along the ground; each with the growth it
    -- shows at
    b.moss, b.vines, b.weeds = {}, {}, {}
    local function moss(mx, my, r) b.moss[#b.moss + 1] = { x = mx, y = my, r = r, th = rng:random() * 0.8,
        shade = rng:random(), bits = 2 + rng:random(3), seed = rng:random() * 100 } end
    for mx = -560, 560, 34 do moss(mx + rng:random() * 20, GROUND_Y - 8 - rng:random() * 20, 22 + rng:random() * 22) end
    for side = -1, 1, 2 do
        for k = 0, 9 do
            local t = k / 9
            moss(side * lerp(650, 20, t), lerp(top + 10, top - 395, t), 14 + rng:random() * 14)
        end
    end
    for k = 0, 6 do moss(760 + k * 130 + rng:random() * 20 - 10, GROUND_Y - 10, 20 + rng:random() * 12) end
    for mx = -380, 300, 150 do moss(mx, -330 + 5, 12 + rng:random() * 10) end -- the window sill
    local function vine(x0, climb, lean, wander)
        local pts, len = {}, 0
        local px, py = x0, GROUND_Y
        for k = 0, 40 do
            local t = k / 40
            local x = x0 + lean * t * climb * 0.3 + math.sin(t * 7 + wander) * 55 * (0.3 + t)
                + math.sin(t * 19 + wander * 2) * 12
            local y = GROUND_Y - t * climb
            if k > 0 then len = len + math.sqrt((x - px) ^ 2 + (y - py) ^ 2) end
            pts[#pts + 1] = { x, y, len }
            px, py = x, y
        end
        local leaves = {}
        for d = 40, len, 42 + rng:random() * 22 do
            leaves[#leaves + 1] = { d = d, side = (#leaves % 2 == 0) and 1 or -1, size = 0.8 + rng:random() * 0.6,
                tilt = rng:random() * 0.6 - 0.3 }
        end
        b.vines[#b.vines + 1] = { pts = pts, len = len, leaves = leaves, th = 0.15 + rng:random() * 0.2 }
    end
    vine(-480, 820, 0.4, 0.5)
    vine(-130, 600, -0.3, 2.1)
    vine(470, 760, -0.5, 4.2)
    vine(830, 330, 0.3, 1.3)
    for wx = -1800, 2400, 26 do
        local near = math.abs(wx) < 650 and 1.4 or 1
        b.weeds[#b.weeds + 1] = { x = wx + rng:random() * 20, th = rng:random() * 0.9, height = (0.6 + rng:random() * 0.8) * near,
            kind = rng:random(8), flower = rng:random() < 0.12 and (0.55 + rng:random() * 0.4) or nil,
            petals = ({ { 1, 1, 0.95 }, { 1, 0.85, 0.3 }, { 0.95, 0.55, 0.7 }, { 0.65, 0.6, 0.95 } })[rng:random(4)],
            front = rng:random() < 0.35 }
    end
end

local function makeBodies(b)
    if b.ground and not b.ground:isDestroyed() then return end
    local ground = objectManager.addThing('rectangle', { x = 300, y = GROUND_Y + 150, width = 6000, height = 300,
        bodyType = 'static', label = 'wild-ground' })
    if ground then
        for _, f in ipairs(ground.body:getFixtures()) do f:setFriction(0.9) end
        b.ground = ground.body
    end
    -- the roof can be stood on
    local roof = objectManager.addThing('rectangle', { x = 0, y = 0, width = 10, height = 10, bodyType = 'static',
        label = 'wild-roof' })
    if roof then
        local body = roof.body
        for _, f in ipairs(body:getFixtures()) do f:destroy() end
        for _, p in ipairs(b.planks) do
            if p.layer == 'roof' then
                local ok, shape = pcall(love.physics.newPolygonShape, p.base)
                if ok then love.physics.newFixture(body, shape, 1):setFriction(0.8) end
            end
        end
        b.roof = body
    end
end

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

local function spawnMipo(b, x, y) mipoKit.spawn(b.mipos, x, y) end -- src/mipo-kit.lua

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = wild()
    if #b.planks == 0 then buildShed(b, 7) end
    makeBodies(b)
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -250, -500)
        spawnMipo(b, 300, -500)
    end
end

function s.onUnload()
    local b = state.wild
    if b and b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = wild()
    if key == '1' then b.settings.wild = 0
    elseif key == '2' then b.settings.wild = 0.5
    elseif key == '3' then b.settings.wild = 1
    elseif key == 'm' then local mx, my = mouseWorldPos(); spawnMipo(b, mx, my)
    elseif key == 'r' then
        buildShed(b, (b.seed or 7) + 1)
        if b.roof and not b.roof:isDestroyed() then objectManager.destroyBody(b.roof) end
        if b.ground and not b.ground:isDestroyed() then objectManager.destroyBody(b.ground) end
        b.roof, b.ground = nil, nil
        makeBodies(b)
    elseif key == 'h' then b.showPanel = not b.showPanel
    end
end

function s.update(dt)
    local b = state.wild
    if b then b.time = b.time + dt end
end

---------------------------------------------------------------- drawing

local blades = love.graphics.newImage('textures/world/sprieten.png')
local BLADES = { -- the atlas's quads and base pivots (src/grass.lua)
    { 0, 0, 49, 192, 22, 185 }, { 51, 164, 40, 197, 12, 187 }, { 51, 0, 41, 162, 19, 144 },
    { 94, 0, 46, 186, 25, 176 }, { 0, 194, 47, 231, 27, 224 }, { 94, 188, 45, 236, 16, 210 },
    { 142, 197, 47, 208, 22, 190 }, { 142, 0, 52, 195, 30, 173 },
}
local bladeQuads = {}
for i, q in ipairs(BLADES) do bladeQuads[i] = love.graphics.newQuad(q[1], q[2], q[3], q[4], blades:getDimensions()) end
local weedBatch = love.graphics.newSpriteBatch(blades, 400, 'stream')

local function drawPlank(b, p, level, grime)
    local look = lookAt(b, p, level)
    -- the colour: fresh paint fading to grey weathered wood, and darker
    local c = lerpColor(p.paint, p.wood, smooth(grime * 1.2))
    local dark = 1 - 0.22 * grime
    if p.layer == 'back' then dark = dark * 0.95 end
    love.graphics.setColor(c[1] * dark, c[2] * dark, c[3] * dark)
    love.graphics.polygon('fill', look.pts)
    -- stains: dark blotches in the lower part, each coming in at its own grime
    for _, st in ipairs(p.stains) do
        local k = smooth((grime - st.th) / 0.4)
        if k > 0 then
            local x, y = look.at(st.u, st.v)
            local ang = math.atan2(look.pts[4] - look.pts[2], look.pts[3] - look.pts[1])
            love.graphics.setColor(0.18, 0.15, 0.1, 0.28 * k)
            love.graphics.push()
            love.graphics.translate(x, y)
            love.graphics.rotate(ang)
            love.graphics.ellipse('fill', 0, 0, st.rx * p.len * 0.5, st.ry * p.thick * 0.5)
            love.graphics.pop()
        end
    end
    if #STROKE.strokes > 0 then
        love.graphics.push()
        love.graphics.translate(-look.ox, -look.oy)
        love.graphics.setColor(c[1] * dark * 0.6, c[2] * dark * 0.55, c[3] * dark * 0.5, 0.25 + 0.4 * grime)
        for _, mesh in ipairs(look.grain) do love.graphics.draw(mesh) end
        love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
        for _, mesh in ipairs(look.outline) do love.graphics.draw(mesh) end
        love.graphics.pop()
    end
    -- nails, and rust running down from them
    for _, n in ipairs(look.nails) do
        if grime > 0.2 then
            local run = (grime - 0.2) / 0.8
            love.graphics.setColor(0.45, 0.25, 0.12, 0.45 * run)
            love.graphics.setLineWidth(5)
            love.graphics.line(n[1], n[2], n[1] + 2, n[2] + 15 + 55 * run)
        end
        love.graphics.setColor(lerp(0.3, 0.42, grime), lerp(0.3, 0.26, grime), lerp(0.32, 0.18, grime))
        love.graphics.circle('fill', n[1], n[2], 7)
        love.graphics.setColor(0.65, 0.65, 0.66, 1 - grime * 0.7)
        love.graphics.circle('fill', n[1] - 2, n[2] - 2, 3)
    end
end

local function drawLayer(b, layer, level, grime)
    for _, p in ipairs(b.planks) do
        if p.layer == layer then drawPlank(b, p, level, grime) end
    end
end

-- moss: soft clumps, each growing in at its own growth
local MOSS = { { 0.3, 0.45, 0.18 }, { 0.38, 0.55, 0.2 }, { 0.46, 0.6, 0.22 } }
local function drawMoss(b, growth)
    for _, m in ipairs(b.moss) do
        local k = smooth((growth - m.th) / 0.35)
        if k > 0 then
            local r = m.r * k
            for j = 1, m.bits do
                local a = m.seed + j * 2.1
                local bx, by = m.x + math.cos(a) * r * 0.7, m.y + math.sin(a) * r * 0.35
                local col = MOSS[(j + math.floor(m.shade * 3)) % 3 + 1]
                love.graphics.setColor(col[1] * 0.75, col[2] * 0.75, col[3] * 0.75)
                love.graphics.circle('fill', bx, by + r * 0.15, r * 0.75)
                love.graphics.setColor(col)
                love.graphics.circle('fill', bx, by, r * 0.7)
            end
        end
    end
end

local LEAF = { 0.33, 0.55, 0.22 }
local function drawVines(b, growth)
    love.graphics.setLineStyle('smooth')
    for _, v in ipairs(b.vines) do
        local reach = smooth((growth - v.th) / (1 - v.th)) * v.len
        if reach > 5 then
            local pts = {}
            for _, p in ipairs(v.pts) do
                if p[3] <= reach then pts[#pts + 1] = p[1]; pts[#pts + 1] = p[2] end
            end
            if #pts >= 4 then
                love.graphics.setColor(OUTLINE)
                love.graphics.setLineWidth(13)
                love.graphics.line(pts)
                love.graphics.setColor(0.36, 0.48, 0.2)
                love.graphics.setLineWidth(8)
                love.graphics.line(pts)
            end
            -- leaves where it's reached, grown by how far past them it is
            for _, leaf in ipairs(v.leaves) do
                local k = clamp((reach - leaf.d) / 120, 0, 1)
                if k > 0 then
                    local x, y
                    for i = 2, #v.pts do
                        if v.pts[i][3] >= leaf.d then
                            local a, c = v.pts[i - 1], v.pts[i]
                            local t = (leaf.d - a[3]) / math.max(1, c[3] - a[3])
                            x, y = lerp(a[1], c[1], t), lerp(a[2], c[2], t)
                            break
                        end
                    end
                    if x then
                        local sz = 46 * leaf.size * k
                        love.graphics.push()
                        love.graphics.translate(x, y)
                        love.graphics.rotate(leaf.side * 0.9 + leaf.tilt + math.sin(b.time * 1.2 + leaf.d) * 0.06)
                        local shape = { 0, 0, sz * 0.5, -sz * 0.35, sz * 1.1, 0, sz * 0.5, sz * 0.35 }
                        love.graphics.setColor(LEAF[1] * (0.9 + leaf.tilt * 0.3), LEAF[2], LEAF[3])
                        love.graphics.polygon('fill', shape)
                        love.graphics.setColor(OUTLINE)
                        love.graphics.setLineWidth(3)
                        love.graphics.polygon('line', shape)
                        love.graphics.line(0, 0, sz * 0.9, 0)
                        love.graphics.pop()
                    end
                end
            end
        end
    end
    love.graphics.setLineWidth(1)
end

-- the lawn: short and even when tidy, weeds of every height when wild, flowers on some
local function drawWeeds(b, growth, front)
    weedBatch:clear()
    local flowers = {}
    for _, w in ipairs(b.weeds) do
        if w.front == front then
            local tall = 0.25 + growth * w.height * 1.3
            local show = growth > w.th * 0.9 or w.th < 0.35 -- a tidy lawn still has some
            if show then
                local q = BLADES[w.kind]
                local ang = math.sin(w.x * 0.37) * (0.05 + 0.2 * growth) + math.sin(b.time * 1.3 + w.x * 0.003) * 0.05
                local sz = 0.9
                weedBatch:add(bladeQuads[w.kind], w.x, GROUND_Y + (front and 20 or 4), ang, sz, sz * tall, q[5], q[6])
                if w.flower and growth > w.flower then
                    local top = q[6] * sz * tall
                    flowers[#flowers + 1] = { w.x + math.sin(ang) * top, GROUND_Y + (front and 20 or 4) - top * math.cos(ang),
                        w.petals, smooth((growth - w.flower) / 0.2) }
                end
            end
        end
    end
    local g = lerp(0.85, 0.65, growth)
    love.graphics.setColor(0.55 * g, 0.75 * g, 0.35 * g)
    love.graphics.draw(weedBatch)
    for _, f in ipairs(flowers) do
        local r = 13 * f[4]
        love.graphics.setColor(f[3])
        for k = 0, 4 do
            local a = k / 5 * math.pi * 2
            love.graphics.circle('fill', f[1] + math.cos(a) * r * 0.7, f[2] + math.sin(a) * r * 0.7, r * 0.55)
        end
        love.graphics.setColor(0.98, 0.78, 0.2)
        love.graphics.circle('fill', f[1], f[2], r * 0.4)
    end
end

function s.drawBelow()
    local b = state.wild
    if not b or #b.planks == 0 then return end
    local chaos, grime, growth = amounts(b)
    local level = math.floor(chaos * LEVELS + 0.5)
    love.graphics.push()
    love.graphics.origin()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(lerp(0.72, 0.68, grime), lerp(0.85, 0.78, grime), lerp(0.93, 0.82, grime))
    love.graphics.rectangle('fill', 0, 0, w, h)
    love.graphics.pop()
    -- the ground: a mown green going rougher and darker
    local x0 = cam:getWorldCoordinates(0, 0)
    local x1 = cam:getWorldCoordinates(w, h)
    local gc = lerpColor({ 0.5, 0.72, 0.32 }, { 0.38, 0.52, 0.24 }, growth)
    gc = lerpColor(gc, { 0.42, 0.38, 0.26 }, grime * 0.35)
    love.graphics.setColor(gc)
    love.graphics.rectangle('fill', x0 - 100, GROUND_Y, x1 - x0 + 200, 3000)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(6)
    love.graphics.line(x0 - 100, GROUND_Y, x1 + 100, GROUND_Y)
    love.graphics.setLineWidth(1)
    drawLayer(b, 'back', level, grime)
    drawLayer(b, 'roof', level, grime)
    drawMoss(b, growth)
    drawVines(b, growth)
    drawWeeds(b, growth, false)
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.wild
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    local chaos, grime, growth = amounts(b)
    local level = math.floor(chaos * LEVELS + 0.5)
    drawLayer(b, 'front', level, grime)
    drawWeeds(b, growth, true)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local b = state.wild
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 34, 6, 400
    local rows = { { 'wild', 0, 1 }, { 'chaos', 0, 1.5 }, { 'grime', 0, 1.5 }, { 'growth', 0, 1.5 },
        { 'width', 2, 30 }, { 'wobble', 0, 4 } }
    local h = (BH + pad) * (#rows + 2) + pad + 24
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• tidy ... wild ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local key = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('wild' .. key, x, y, 180, row[2], row[3], b.settings[key], nil, 0.01)
            if v then b.settings[key] = v + 0 end
            ui.label(x + 280, y, key)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local c, g, gr = amounts(b)
        ui.label(x, y, string.format('chaos %.2f  grime %.2f  growth %.2f', c, g, gr))
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, '1 tidy 2 half 3 wild  m Mipo  r new shed')
    end)
end

return s
