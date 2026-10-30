-- burrow: a spike for an underground Mipo home you dig yourself.
-- The earth is a grid of densities (0 air .. 1 earth), drawn and collided with interpolated
-- marching squares where the density crosses 0.5 (the same idea as ../liquid and
-- ~/Projects/love/underground). The grid is cut into chunks; each chunk is one static body
-- with chain shapes along its outline, rebuilt only when a stroke touches it.
-- No water yet.
--
-- play mode (tab): drag on earth to dig (or put earth back: the panel, or hold shift).
-- The panel (bottom left) has the brush size, the cell size and a new landscape.
-- keys: [ ] brush size   m: a new Mipo at the mouse   r: new landscape

local s = {}

local WORLD_W, WORLD_H = 9600, 4800
local X0 = -WORLD_W / 2
local Y0 = -1200         -- top of the grid; the surface is around y = 0
local CHUNK = 16         -- cells per chunk side
local CELL_MIN, CELL_MAX = 15, 120

-- The grid follows the cell size (useCell); the world stays the same size.
local CELL, COLS, ROWS, SW, CHUNKS_X, CHUNKS_Y
local function useCell(cell)
    CELL = cell                -- world units between samples
    COLS = math.floor(WORLD_W / cell)
    ROWS = math.floor(WORLD_H / cell)
    SW = COLS + 1              -- samples per row
    CHUNKS_X = math.ceil(COLS / CHUNK)
    CHUNKS_Y = math.ceil(ROWS / CHUNK)
end
useCell(40)

local earthColor = { 0.62, 0.45, 0.30, 1 }
local wallColor = { 0.36, 0.25, 0.17, 1 } -- the dug-out back wall
local rimColor = { 0.25, 0.17, 0.11, 1 }

local function idx(i, j) return j * SW + i + 1 end

local function clamp01(v)
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

-- Kept on state so a hot reload of this script keeps what was dug (and the Mipos).
local function burrow()
    local b = state.burrow or {}
    state.burrow = b
    b.brush, b.cell, b.seed = b.brush or 300, b.cell or 40, b.seed or 0
    return b
end

local function surfaceAt(b, x)
    local u = (x - X0) / WORLD_W
    return 120 * (love.math.noise(u * 3, 7.3 + b.seed) - 0.5) + 60 * (love.math.noise(u * 9, 1.1 + b.seed) - 0.5)
end

local function surfaces(b)
    b.surface = {}
    for i = 0, COLS do b.surface[i] = surfaceAt(b, X0 + i * CELL) end
end

-- How far (in cells, signed) a point lies inside a rounded rectangle; negative outside.
local function roomDepth(x, y, cx, cy, w, h, r)
    local dx = math.max(math.abs(x - cx) - (w / 2 - r), 0)
    local dy = math.max(math.abs(y - cy) - (h / 2 - r), 0)
    return (r - math.sqrt(dx * dx + dy * dy)) / CELL
end

local function newLandscape(b)
    b.dens = {}
    surfaces(b)
    for j = 0, ROWS do
        for i = 0, COLS do
            local x, y = X0 + i * CELL, Y0 + j * CELL
            local v = clamp01(0.5 + (y - b.surface[i]) / CELL)
            -- a cave with a flat floor to start in (floors must be flat: docs/WORLD-METRICS.md)
            local cave = roomDepth(x, y, 1500, 1700, 2200, 1100, 350)
            v = math.min(v, clamp01(0.5 - cave))
            if i == 0 or i == COLS or j == ROWS then v = 1 end
            b.dens[idx(i, j)] = v
        end
    end
end

-- Another cell size: what was dug is sampled over onto the new grid.
local function resample(b, cell)
    local old, oldCell, oldCols, oldRows, oldSW = b.dens, CELL, COLS, ROWS, SW
    local function at(x, y)
        local fi = math.max(0, math.min(oldCols - 0.001, (x - X0) / oldCell))
        local fj = math.max(0, math.min(oldRows - 0.001, (y - Y0) / oldCell))
        local i, j = math.floor(fi), math.floor(fj)
        local u, v = fi - i, fj - j
        local k = j * oldSW + i + 1
        local top = old[k] * (1 - u) + old[k + 1] * u
        local bottom = old[k + oldSW] * (1 - u) + old[k + oldSW + 1] * u
        return top * (1 - v) + bottom * v
    end
    useCell(cell)
    b.cell = cell
    b.dens = {}
    surfaces(b)
    for j = 0, ROWS do
        for i = 0, COLS do
            local v = at(X0 + i * CELL, Y0 + j * CELL)
            if i == 0 or i == COLS or j == ROWS then v = 1 end
            b.dens[idx(i, j)] = v
        end
    end
end

-- Where the 0.5 crossing sits on the edge between samples a and b, kept off the corners
-- so two crossings never land on the same point (Box2D refuses chains with near-equal vertices).
local function crossing(va, vb)
    local t = (0.5 - va) / (vb - va)
    if t < 0.05 then return 0.05 elseif t > 0.95 then return 0.95 end
    return t
end

-- One chunk: the filled triangles (for its mesh) and the outline as chains.
local function marchChunk(b, cx, cy)
    local dens = b.dens
    local tris = {}
    local pos, adj = {}, {}
    local function link(ka, kb)
        adj[ka] = adj[ka] or {}
        adj[kb] = adj[kb] or {}
        adj[ka][#adj[ka] + 1] = kb
        adj[kb][#adj[kb] + 1] = ka
    end

    local i1, j1 = math.min((cx + 1) * CHUNK, COLS) - 1, math.min((cy + 1) * CHUNK, ROWS) - 1
    for j = cy * CHUNK, j1 do
        for i = cx * CHUNK, i1 do
            local tl, tr = dens[idx(i, j)], dens[idx(i + 1, j)]
            local br, bl = dens[idx(i + 1, j + 1)], dens[idx(i, j + 1)]
            local x, y = X0 + i * CELL, Y0 + j * CELL
            -- walk tl tr br bl; a solid corner is a vertex, a change between corners a crossing.
            -- Crossings are keyed by their edge so neighbouring cells (and chunks) share them.
            local poly = {}
            local function corner(v, px, py)
                if v > 0.5 then poly[#poly + 1] = { px, py } end
            end
            local function edge(va, vb, key, ax, ay, dx, dy)
                if (va > 0.5) ~= (vb > 0.5) then
                    local t = crossing(va, vb)
                    local p = { ax + dx * t, ay + dy * t, key }
                    pos[key] = p
                    poly[#poly + 1] = p
                end
            end
            corner(tl, x, y)
            edge(tl, tr, idx(i, j) * 2, x, y, CELL, 0)
            corner(tr, x + CELL, y)
            edge(tr, br, idx(i + 1, j) * 2 + 1, x + CELL, y, 0, CELL)
            corner(br, x + CELL, y + CELL)
            -- bottom and left edges are measured from their left / top sample, like the cell
            -- that shares them, so both cells get the exact same point
            if (bl > 0.5) ~= (br > 0.5) then
                local key = idx(i, j + 1) * 2
                local t = crossing(bl, br)
                local p = { x + CELL * t, y + CELL, key }
                pos[key] = p
                poly[#poly + 1] = p
            end
            corner(bl, x, y + CELL)
            if (tl > 0.5) ~= (bl > 0.5) then
                local key = idx(i, j) * 2 + 1
                local t = crossing(tl, bl)
                local p = { x, y + CELL * t, key }
                pos[key] = p
                poly[#poly + 1] = p
            end

            local n = #poly
            if n >= 3 then
                for k = 2, n - 1 do
                    tris[#tris + 1] = { poly[1][1], poly[1][2] }
                    tris[#tris + 1] = { poly[k][1], poly[k][2] }
                    tris[#tris + 1] = { poly[k + 1][1], poly[k + 1][2] }
                end
                -- two crossings next to each other in the walk are a piece of outline
                for k = 1, n do
                    local p, q = poly[k], poly[k % n + 1]
                    if p[3] and q[3] then link(p[3], q[3]) end
                end
            end
        end
    end

    -- string the outline pieces together: open chains end on the chunk border, loops don't
    local visited, chains = {}, {}
    local function walk(start)
        local keys = { start }
        visited[start] = true
        local cur = start
        while true do
            local nxt
            for _, k in ipairs(adj[cur]) do
                if not visited[k] then nxt = k break end
            end
            if not nxt then break end
            visited[nxt] = true
            keys[#keys + 1] = nxt
            cur = nxt
        end
        return keys
    end
    for key, list in pairs(adj) do
        if #list == 1 and not visited[key] then chains[#chains + 1] = { keys = walk(key), loop = false } end
    end
    for key in pairs(adj) do
        if not visited[key] then chains[#chains + 1] = { keys = walk(key), loop = true } end
    end

    local outlines = {}
    for _, chain in ipairs(chains) do
        local flat = {}
        for _, key in ipairs(chain.keys) do
            local p = pos[key]
            local n = #flat
            local dx, dy = n > 0 and p[1] - flat[n - 1] or 1e9, n > 0 and p[2] - flat[n] or 1e9
            if dx * dx + dy * dy > 4 then
                flat[n + 1], flat[n + 2] = p[1], p[2]
            end
        end
        local loop = chain.loop
        if loop and #flat >= 4 then
            local dx, dy = flat[1] - flat[#flat - 1], flat[2] - flat[#flat]
            if dx * dx + dy * dy <= 4 then flat[#flat], flat[#flat - 1] = nil, nil end
        end
        if loop and #flat < 6 then loop = false end
        if #flat >= 4 then outlines[#outlines + 1] = { flat = flat, loop = loop } end
    end
    return tris, outlines
end

local function destroyChunk(chunk)
    if chunk.body and not chunk.body:isDestroyed() then chunk.body:destroy() end
    chunk.body = nil
end

local function rebuildChunk(b, cx, cy)
    local key = cy * CHUNKS_X + cx + 1
    local chunk = b.chunks[key] or {}
    b.chunks[key] = chunk
    destroyChunk(chunk)

    local tris, outlines = marchChunk(b, cx, cy)
    chunk.mesh = #tris >= 3 and love.graphics.newMesh(tris, 'triangles', 'static') or nil
    chunk.outlines = outlines

    if #outlines > 0 then
        local body = love.physics.newBody(world, 0, 0, 'static')
        body:setUserData({ burrowChunk = key })
        for _, o in ipairs(outlines) do
            local fixture = love.physics.newFixture(body, love.physics.newChainShape(o.loop, unpack(o.flat)))
            fixture:setFriction(0.9)
        end
        chunk.body = body
    end

    -- whatever was asleep on the old outline has to notice the new one
    local x1, y1 = X0 + cx * CHUNK * CELL, Y0 + cy * CHUNK * CELL
    world:queryBoundingBox(x1 - CELL, y1 - CELL, x1 + (CHUNK + 1) * CELL, y1 + (CHUNK + 1) * CELL,
        function(fixture)
            fixture:getBody():setAwake(true)
            return true
        end)
end

local function rebuildAll(b)
    for _, chunk in pairs(b.chunks or {}) do destroyChunk(chunk) end
    b.chunks = {}
    for cy = 0, CHUNKS_Y - 1 do
        for cx = 0, CHUNKS_X - 1 do rebuildChunk(b, cx, cy) end
    end
    b.dirty = {}
end

-- The back wall shows where earth was: everything under the first surface.
local function buildWall(b)
    local verts = {}
    local bottom = Y0 + ROWS * CELL
    for i = 0, COLS - 1 do
        local xa, xb = X0 + i * CELL, X0 + (i + 1) * CELL
        local ya, yb = b.surface[i] + 10, b.surface[i + 1] + 10
        verts[#verts + 1] = { xa, ya }
        verts[#verts + 1] = { xb, yb }
        verts[#verts + 1] = { xb, bottom }
        verts[#verts + 1] = { xa, ya }
        verts[#verts + 1] = { xb, bottom }
        verts[#verts + 1] = { xa, bottom }
    end
    b.wall = love.graphics.newMesh(verts, 'triangles', 'static')
end

-- Is this sample under a Mipo part (putting earth back there would bury it)?
local function underBody(x, y)
    local hit = false
    world:queryBoundingBox(x - 1, y - 1, x + 1, y + 1, function(fixture)
        if fixture:getBody():getType() == 'dynamic' and fixture:testPoint(x, y) then
            hit = true
            return false
        end
        return true
    end)
    return hit
end

-- One round brush stamp: dig lowers samples towards 0 inside the radius, fill raises them.
local function stamp(b, wx, wy, r, fill)
    local i0 = math.max(1, math.floor((wx - r - X0) / CELL) - 1)
    local i1 = math.min(COLS - 1, math.ceil((wx + r - X0) / CELL) + 1)
    local j0 = math.max(0, math.floor((wy - r - Y0) / CELL) - 1)
    local j1 = math.min(ROWS - 1, math.ceil((wy + r - Y0) / CELL) + 1)
    if i0 > i1 or j0 > j1 then return end
    local dens = b.dens
    for j = j0, j1 do
        for i = i0, i1 do
            local x, y = X0 + i * CELL, Y0 + j * CELL
            local d = math.sqrt((x - wx) ^ 2 + (y - wy) ^ 2)
            local outside = clamp01(0.5 + (d - r) / CELL)
            local k = idx(i, j)
            if fill then
                local v = math.max(dens[k], 1 - outside)
                if v ~= dens[k] and not (v > 0.5 and underBody(x, y)) then dens[k] = v end
            else
                dens[k] = math.min(dens[k], outside)
            end
        end
    end
    -- a sample is a corner of the cells on both sides, so the chunks around it change too
    for cy = math.max(0, math.floor((j0 - 1) / CHUNK)), math.min(CHUNKS_Y - 1, math.floor(j1 / CHUNK)) do
        for cx = math.max(0, math.floor((i0 - 1) / CHUNK)), math.min(CHUNKS_X - 1, math.floor(i1 / CHUNK)) do
            b.dirty[cy * CHUNKS_X + cx] = true
        end
    end
end

local function spawnMipo(b, x, y, dna)
    local inst
    if dna then
        inst = characterManager.createCharacterFromJustDNA(dna, x, y, 0.3)
    else
        inst = characterManager.createCharacter('humanoid', x, y, 0.3)
        if inst then characterManager.randomizeMipoConstrained(inst) end
    end
    if not inst then return end
    inst.burrowStart = { x, y }
    b.mipos[#b.mipos + 1] = inst
end

local function aliveMipos(b)
    local alive = {}
    for _, inst in ipairs(b.mipos or {}) do
        local torso = inst.parts and inst.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then alive[#alive + 1] = inst end
    end
    return alive
end

local function rebuildEverything(b)
    buildWall(b)
    rebuildAll(b)
end

-- Reset: the landscape as it started and every Mipo (same looks) back where it came in.
local function reset(b)
    newLandscape(b)
    rebuildEverything(b)
    local mipos = aliveMipos(b)
    b.mipos = {}
    for _, inst in ipairs(mipos) do
        for _, part in pairs(inst.parts) do
            if part.body and not part.body:isDestroyed() then objectManager.destroyBody(part.body) end
        end
        local start = inst.burrowStart or { -1500, -900 }
        spawnMipo(b, start[1], start[2], inst.dna)
    end
end

local function setCell(b, cell)
    cell = math.max(CELL_MIN, math.min(CELL_MAX, cell))
    if cell == CELL then return end
    resample(b, cell)
    rebuildEverything(b)
end

function s.onStart()
    worldState.paused = false
    local b = burrow()
    useCell(b.cell)
    if not b.dens then newLandscape(b) end
    rebuildEverything(b)
    b.mipos = aliveMipos(b)
    if #b.mipos == 0 then
        spawnMipo(b, -1500, -900) -- one on the grass
        spawnMipo(b, 1500, 1500)  -- one in the cave
    end
    camera.setBounds(X0, Y0 - 2000, X0 + WORLD_W, Y0 + WORLD_H)
end

function s.onUnload()
    local b = state.burrow
    if not b then return end
    for _, chunk in pairs(b.chunks or {}) do destroyChunk(chunk) end
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local b = burrow()
    if key == '[' then
        b.brush = math.max(100, b.brush - 40)
    elseif key == ']' then
        b.brush = math.min(800, b.brush + 40)
    elseif key == 'm' then
        local mx, my = mouseWorldPos()
        spawnMipo(b, mx, my)
    elseif key == 'r' then
        reset(b)
    end
end

-- the panel's rectangle on screen, so a press on it doesn't dig
local panelRect = { 20, 0, 380, 0 }
local function overPanel()
    local mx, my = love.mouse.getPosition()
    local r = panelRect
    return mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4]
end

function s.update(dt)
    local b = burrow()
    if not b.dens then return end
    if b.pendingCell and not love.mouse.isDown(1) then -- the cell slider applies when let go
        setCell(b, b.pendingCell)
        b.pendingCell = nil
    end
    -- dig with a press that didn't grab anything (a grab makes a pointer joint first)
    local down = state.playMode and love.mouse.isDown(1)
    if down and not b.stroke and #getInteractedWithPointer() == 0 and not overPanel() then
        b.stroke = true
        b.lastX, b.lastY = mouseWorldPos()
    elseif not down then
        b.stroke = nil
    end
    if b.stroke then
        local mx, my = mouseWorldPos()
        local fill = (b.fill == true) ~= love.keyboard.isDown('lshift', 'rshift') -- shift does the other one
        local dx, dy = mx - b.lastX, my - b.lastY
        local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / (b.brush * 0.25)))
        for k = 1, steps do
            stamp(b, b.lastX + dx * k / steps, b.lastY + dy * k / steps, b.brush, fill)
        end
        b.lastX, b.lastY = mx, my
    end
    for key in pairs(b.dirty) do
        rebuildChunk(b, key % CHUNKS_X, math.floor(key / CHUNKS_X))
    end
    b.dirty = {}
end

function s.drawUI()
    local b = state.burrow
    if not (b and state.playMode) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 40, 10, 380
    local h = BH * 6 + pad * 7 + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    panelRect[2], panelRect[4] = y0, h
    ui.panel(x0, y0, w, h, '•• burrow ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local used, fill = ui.toggleButton(x, y, w - 20, BH, 'putting earth back', 'digging', b.fill)
        if used then b.fill = fill end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('burrowbrush', x, y, 160, 100, 800, b.brush, nil, 1)
        if v then b.brush = v end
        ui.label(x + 260, y, 'brush')
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        v = ui.sliderWithInput('burrowcell', x, y, 160, CELL_MIN, CELL_MAX, b.pendingCell or CELL, nil, 1)
        if v then b.pendingCell = v end
        ui.label(x + 260, y, 'cell ' .. COLS .. 'x' .. ROWS)
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'reset (earth + Mipos)') then reset(b) end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, w - 20, 'new landscape') then
            b.seed = b.seed + 1
            newLandscape(b)
            rebuildEverything(b)
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'shift: the other one  m: Mipo')
    end)
end

-- A stroke from the bridge: s.dig(x1, y1, x2, y2[, fill])
function s.dig(x1, y1, x2, y2, fill)
    local b = burrow()
    local dx, dy = x2 - x1, y2 - y1
    local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / (b.brush * 0.25)))
    for k = 0, steps do
        stamp(b, x1 + dx * k / steps, y1 + dy * k / steps, b.brush, fill)
    end
end

function s.drawBelow()
    local b = state.burrow
    if not (b and b.chunks) then return end
    love.graphics.setColor(wallColor)
    if b.wall then love.graphics.draw(b.wall) end
    love.graphics.setColor(earthColor)
    for _, chunk in pairs(b.chunks) do
        if chunk.mesh then love.graphics.draw(chunk.mesh) end
    end
    love.graphics.setColor(rimColor)
    love.graphics.setLineWidth(8)
    love.graphics.setLineJoin('bevel')
    for _, chunk in pairs(b.chunks) do
        for _, o in ipairs(chunk.outlines) do
            if o.loop then love.graphics.polygon('line', o.flat) else love.graphics.line(o.flat) end
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.draw()
    local b = state.burrow
    if not (b and state.playMode) then return end
    local mx, my = mouseWorldPos()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(4)
    love.graphics.circle('line', mx, my, b.brush)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return s
