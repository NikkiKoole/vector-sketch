-- cellophane: crumpled plastic wrap as water, a row of it made as a real crumpled sheet (CELLOPHANE-WATER.md)
-- After Nikki's mood pictures 12 and 14 (docs/inspiration/ai-materials). The row is a strip of
-- triangles: the corners jittered, the columns spaced unevenly and wider than the rows are tall,
-- slanted, and every corner pushed out of the sheet by a random height: that's the crumple. The
-- top corners poke up into peaks. Each triangle has its own corners, so it's lit as one flat facet
-- by the way it faces: the facets and the folds come out of the geometry, no pattern.
-- CW1: one row, standing still. A Mipo stands behind it, to see through the wrap.
--
-- keys: r a new crumple   p palette (light like picture 12, deep like 14)   s shards / one sheet   d the defaults
--       m a Mipo   h the panel

local s = {}

local ROW = { w = 5000, top = 0, h = 900 }
local FLOOR_Y = 260                       -- the Mipos stand on it, half in the wrap
local LIGHT = { -0.35, -0.75, 0.56 }      -- towards the light (y down, z out of the screen)

local PALETTES = {
    { name = 'light (12)', wallTop = { 0.12, 0.2, 0.5 }, wallBottom = { 0.2, 0.33, 0.64 },
        pale = { 0.86, 0.92, 0.96 }, cyan = { 0.38, 0.72, 0.84 }, blue = { 0.22, 0.46, 0.76 }, navy = { 0.12, 0.22, 0.52 } },
    { name = 'deep (14)', wallTop = { 0.97, 0.74, 0.25 }, wallBottom = { 0.95, 0.68, 0.22 },
        pale = { 0.75, 0.93, 1.0 }, cyan = { 0.25, 0.72, 0.95 }, blue = { 0.07, 0.36, 0.78 }, navy = { 0.03, 0.12, 0.42 } },
}

local DEFAULTS = { facet = 120, stretch = 1.6, slant = 0.5, crumple = 0.8, peaks = 1, alpha = 0.5, shine = 20 }
local function defaults()
    local out = {}
    for k, v in pairs(DEFAULTS) do out[k] = v end
    return out
end

local function cello()
    state.cellophane = state.cellophane or {
        seed = 7, palette = 1, showPanel = true, mipos = {}, statics = {}, settings = defaults(),
    }
    return state.cellophane
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end
local function lerp3(a, c, t)
    return { a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t, a[3] + (c[3] - a[3]) * t }
end

---------------------------------------------------------------- the crumpled row

local mesh
local builtFor

-- the corners: rows of points, top first
local function corners(b)
    local set = b.settings
    local rng = love.math.newRandomGenerator(b.seed)
    local colW = set.facet * set.stretch
    local xs, x = {}, -ROW.w / 2
    while x < ROW.w / 2 do
        xs[#xs + 1] = x
        x = x + colW * (0.35 + rng:random() * 1.3)   -- facets of many sizes
    end
    xs[#xs + 1] = ROW.w / 2
    local rows = math.max(2, math.floor(ROW.h / set.facet + 0.5))
    local dy = ROW.h / rows
    local grid = {}
    for j = 0, rows do
        local t = j / rows
        local line = {}
        for i, cx in ipairs(xs) do
            local px = cx + (rng:random() - 0.5) * colW * 0.5 + j * set.slant * colW * 0.35
            local py = ROW.top + j * dy + (rng:random() - 0.5) * dy * 0.6
            if j == 0 then
                -- the top edge: a slow swell of crests, and sharp points where the wrap folds up
                local swell = love.math.noise(cx * 0.0012, b.seed * 0.37) * 0.6 + 0.4
                py = py - set.peaks * dy * (0.4 * swell + 1.6 * rng:random() ^ 3 * swell)
            end
            local pz = (rng:random() - 0.5) * set.crumple * set.facet
            line[i] = { px, py, pz, t }
        end
        grid[j] = line
    end
    return grid, rng
end

-- one flat facet: its colour from the way it faces
local function facet(b, verts, p1, p2, p3, rng)
    local set, pal = b.settings, PALETTES[b.palette]
    local ux, uy, uz = p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]
    local vx, vy, vz = p3[1] - p1[1], p3[2] - p1[2], p3[3] - p1[3]
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local len = math.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    nx, ny, nz = nx / len, ny / len, nz / len
    if nz < 0 then nx, ny, nz = -nx, -ny, -nz end
    local lx, ly, lz = LIGHT[1], LIGHT[2], LIGHT[3]
    local ll = math.sqrt(lx * lx + ly * ly + lz * lz)
    lx, ly, lz = lx / ll, ly / ll, lz / ll
    local nl = nx * lx + ny * ly + nz * lz
    local diff = math.max(nl, 0)
    local rz = 2 * nl * nz - lz                     -- the reflection, towards the eye (z)
    local spec = math.max(rz, 0) ^ set.shine
    local depth = (p1[4] + p2[4] + p3[4]) / 3
    local u = rng:random()
    local c = lerp3(pal.cyan, pal.navy, clamp(depth * 0.75 + u * 0.5 - 0.15, 0, 1))
    c = lerp3(c, pal.blue, clamp(1 - math.abs(u - 0.5) * 3, 0, 1) * 0.5)
    c = lerp3(c, pal.pale, diff * 0.45)
    local a = set.alpha + 0.25 * depth
    if u > 0.88 then                                -- a clear, greyish facet: the wrap with nothing behind
        c = lerp3(c, pal.pale, 0.6); a = a * 0.55
    end
    c = lerp3(c, { 1, 1, 1 }, clamp(spec * 1.2, 0, 1))
    a = clamp(a + spec * 0.5, 0, 1)
    for _, p in ipairs({ p1, p2, p3 }) do
        verts[#verts + 1] = { p[1], p[2], 0, 0, c[1], c[2], c[3], a }
    end
end

local function build(b)
    local grid, rng = corners(b)
    local verts = {}
    for j = 0, #grid - 1 do
        local top, bot = grid[j], grid[j + 1]
        for i = 1, math.min(#top, #bot) - 1 do
            local a, bb, c, d = top[i], top[i + 1], bot[i + 1], bot[i]
            if rng:random() < 0.5 then
                facet(b, verts, a, bb, c, rng); facet(b, verts, a, c, d, rng)
            else
                facet(b, verts, a, bb, d, rng); facet(b, verts, bb, c, d, rng)
            end
        end
    end
    mesh = love.graphics.newMesh(verts, 'triangles', 'static')
end

---------------------------------------------------------------- shards: overlapping pieces of wrap

-- Picture 12 is not one sheet: it's many small see-through pieces overlapping. Where they overlap
-- the colour deepens, every piece's edge is a thin lighter line, many are clear and greyish, and
-- the crests stand up in sharp points. Rows of crests, back to front.
local CRESTS = 4
local shardCanvas, shardBox

local function crestTop(b, k, x)
    local set = b.settings
    local gap = ROW.h * 0.22
    local base = ROW.top + k * gap
    local period = set.facet * 2.6
    local u = x / period + k * 0.37 + b.seed * 0.01
    local f = u - math.floor(u)
    local peak = 1 - math.abs(f * 2 - 1)                       -- 0 between, 1 at a point
    local tall = 0.35 + 0.65 * love.math.noise(math.floor(u) * 0.73, k * 3.1, b.seed * 0.1)
    return base - peak ^ 1.6 * tall * set.peaks * set.facet * 1.1
end

local function shardColour(b, rng, depth, low)
    local set, pal = b.settings, PALETTES[b.palette]
    -- lower in a crest: more of the deep colours
    local u = clamp(rng:random() + low * 0.45, 0, 1)
    local c, a
    if u < 0.22 then c, a = pal.pale, 0.25                        -- clear, greyish
    elseif u < 0.55 then c, a = pal.cyan, 0.4
    elseif u < 0.82 then c, a = pal.blue, 0.48
    else c, a = pal.navy, 0.55 end
    -- a random tilt: some catch the light
    local nx, ny = (rng:random() - 0.5) * 1.4, (rng:random() - 0.5) * 1.4
    local nz = 1
    local l = math.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / l, ny / l, nz / l
    local lx, ly, lz = LIGHT[1], LIGHT[2], LIGHT[3]
    local ll = math.sqrt(lx * lx + ly * ly + lz * lz)
    local nl = (nx * lx + ny * ly + nz * lz) / ll
    local spec = math.max(2 * nl * nz - lz / ll, 0) ^ set.shine
    c = lerp3(c, pal.pale, math.max(nl, 0) * 0.25)
    c = lerp3(c, { 1, 1, 1 }, clamp(spec * 1.3, 0, 1))
    -- the back rows: paler, into the wall's colour
    c = lerp3(c, lerp3(pal.wallBottom, pal.pale, 0.5), (1 - depth) * 0.35)
    a = clamp(a * (set.alpha / 0.5) + spec * 0.4, 0, 1)
    return c, a
end

local function buildShards(b)
    local set = b.settings
    local rng = love.math.newRandomGenerator(b.seed)
    local scale = cam:getScale() * love.graphics.getDPIScale()
    local x0, x1 = -ROW.w / 2, ROW.w / 2
    local y0 = ROW.top - set.peaks * set.facet * 1.3 - set.facet
    local y1 = ROW.top + ROW.h + set.facet
    shardBox = { x0, y0, x1, y1, scale }
    local cw, ch = math.ceil((x1 - x0) * scale), math.ceil((y1 - y0) * scale)
    if not shardCanvas or shardCanvas:getWidth() ~= cw or shardCanvas:getHeight() ~= ch then
        shardCanvas = love.graphics.newCanvas(cw, ch)
    end
    love.graphics.push('all')
    love.graphics.setCanvas(shardCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.scale(scale)
    love.graphics.translate(-x0, -y0)
    love.graphics.setLineJoin('miter')
    love.graphics.setLineWidth(1.2 / scale)
    local size = set.facet
    for k = 0, CRESTS - 1 do
        local depth = (k + 1) / CRESTS
        local band = ROW.h - k * ROW.h * 0.22 + size
        local n = math.floor(set.crumple * 1.6 * (ROW.w / size) * (band / size))
        local shards = {}
        for _ = 1, n do
            local x = x0 + rng:random() * (x1 - x0)
            local top = crestTop(b, k, x)
            local y = top + rng:random() ^ 1.4 * band
            local len = size * (0.5 + rng:random()) * set.stretch * (0.7 + 0.3 * depth)
            local wid = size * (0.45 + 0.6 * rng:random()) * (0.7 + 0.3 * depth)
            local ang = rng:random() * math.pi * 2
            if y - top < len * 0.6 then
                -- at the crest: a point standing up, its tip on the crest line
                ang = -math.pi / 2 + (rng:random() - 0.5) * 0.9 + set.slant * 0.4
                y = top + len * 0.5
            end
            local dx, dy = math.cos(ang), math.sin(ang)
            local px, py = -dy, dx
            -- an irregular piece: a tip, then three or four corners round the back
            local pts = { x + dx * len / 2, y + dy * len / 2 }
            local sides = 3 + math.floor(rng:random() * 2)
            for i = 1, sides do
                local t = i / (sides + 1)                          -- round the back, side to side
                local along = -0.5 + 0.55 * math.sin(t * math.pi) * (0.6 + 0.4 * rng:random())
                local side = math.cos(t * math.pi) * (0.6 + 0.5 * rng:random())
                pts[#pts + 1] = x + dx * len * along + px * wid * side
                pts[#pts + 1] = y + dy * len * along + py * wid * side
            end
            local c, a = shardColour(b, rng, depth, clamp((y - top) / band, 0, 1))
            shards[#shards + 1] = { y = y, pts = pts, c = c, a = a }
        end
        table.sort(shards, function(p, q) return p.y < q.y end)
        for _, sh in ipairs(shards) do
            love.graphics.setColor(sh.c[1], sh.c[2], sh.c[3], sh.a)
            love.graphics.polygon('fill', sh.pts)
            -- the thin edge of the wrap catches the light
            love.graphics.setColor(0.92, 0.97, 1, 0.1 + sh.a * 0.3)
            love.graphics.polygon('line', sh.pts)
        end
    end
    love.graphics.pop()
end

local function key(b)
    local set = b.settings
    return table.concat({ b.seed, b.palette, b.mode or 'shards', set.facet, set.stretch, set.slant, set.crumple,
        set.peaks, set.alpha, set.shine, cam:getScale() }, ',')
end

---------------------------------------------------------------- the stage

local function aliveMipos(b) return mipoKit.alive(b.mipos) end -- src/mipo-kit.lua

local function spawnMipo(b, x, y) mipoKit.spawn(b.mipos, x, y) end -- src/mipo-kit.lua

local function buildFloor(b)
    for _, st in ipairs(b.statics) do
        if st.body and not st.body:isDestroyed() then return end
    end
    b.statics = {}
    local thing = objectManager.addThing('rectangle', { x = 0, y = FLOOR_Y + 20, width = ROW.w, height = 40,
        bodyType = 'static', label = 'cello-floor' })
    if thing then b.statics[1] = { body = thing.body } end
    for _, x in ipairs({ -ROW.w / 2 - 20, ROW.w / 2 + 20 }) do
        local wall = objectManager.addThing('rectangle', { x = x, y = -800, width = 40, height = 2200,
            bodyType = 'static', label = 'cello-wall' })
        if wall then b.statics[#b.statics + 1] = { body = wall.body } end
    end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local b = cello()
    buildFloor(b)
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -500, -400)
        spawnMipo(b, 700, -400)
    end
    builtFor = nil
end

function s.onUnload()
    local b = state.cellophane
    if b and b.savedDrawBodies ~= nil then state.world.debugDrawBodies = b.savedDrawBodies end
end

function s.onKeyPress(k)
    if not state.playMode then return end
    local b = cello()
    if k == 'r' then b.seed = love.math.random(1, 9999)
    elseif k == 'p' then b.palette = b.palette % #PALETTES + 1
    elseif k == 'm' then
        local mx, my = mouseWorldPos()
        spawnMipo(b, mx, my)
    elseif k == 'h' then b.showPanel = not b.showPanel
    elseif k == 'd' then b.settings = defaults()
    elseif k == 's' then b.mode = (b.mode or 'shards') == 'shards' and 'sheet' or 'shards'
    end
end

local wallMesh = love.graphics.newMesh(4, 'fan', 'stream')

function s.drawBelow()
    local b = state.cellophane
    if not b then return end
    local w, h = love.graphics.getDimensions()
    local pal = PALETTES[b.palette]
    local t, bo = pal.wallTop, pal.wallBottom
    wallMesh:setVertices({
        { 0, 0, 0, 0, t[1], t[2], t[3], 1 }, { w, 0, 0, 0, t[1], t[2], t[3], 1 },
        { w, h, 0, 0, bo[1], bo[2], bo[3], 1 }, { 0, h, 0, 0, bo[1], bo[2], bo[3], 1 },
    })
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(wallMesh)
    love.graphics.pop()
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
    b.drawing = true
end

function s.draw()
    local b = state.cellophane
    if not (b and b.drawing) then return end
    b.drawing = nil
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    local k = key(b)
    local shards = (b.mode or 'shards') == 'shards'
    if k ~= builtFor or not (mesh or shardCanvas) then
        if shards then buildShards(b) else build(b) end
        builtFor = k
    end
    love.graphics.setColor(1, 1, 1, 1)
    if shards and shardCanvas then
        love.graphics.setBlendMode('alpha', 'premultiplied')
        love.graphics.draw(shardCanvas, shardBox[1], shardBox[2], 0, 1 / shardBox[5])
        love.graphics.setBlendMode('alpha')
    elseif mesh then
        love.graphics.draw(mesh)
    end
end

function s.drawUI()
    local b = state.cellophane
    if not (b and state.playMode and b.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 36, 8, 400
    local rows = {
        { 'facet', 40, 250, 1 }, { 'stretch', 0.5, 3 }, { 'slant', -1, 1 }, { 'crumple', 0, 2 },
        { 'peaks', 0, 3 }, { 'alpha', 0, 1 }, { 'shine', 2, 60 },
    }
    local h = (BH + pad) * (#rows + 1) + pad + 24
    local x0, y0 = 20, 20
    ui.panel(x0, y0, w, h, '•• cellophane ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        for _, row in ipairs(rows) do
            local name = row[1]
            local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('cello' .. name, x, y, 180, row[2], row[3], b.settings[name], nil, row[4])
            if v then b.settings[name] = v + 0 end
            ui.label(x + 280, y, name)
        end
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, PALETTES[b.palette].name .. ', ' .. (b.mode or 'shards') .. '   r p s d m h')
    end)
end

return s
