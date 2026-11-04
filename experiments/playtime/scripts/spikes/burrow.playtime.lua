-- burrow: a spike for an underground Mipo home you dig yourself.
-- The earth is a grid of densities (0 air .. 1 earth), drawn and collided with interpolated
-- marching squares where the density crosses 0.5 (the same idea as ../liquid and
-- ~/Projects/love/underground). The grid is cut into chunks; each chunk is one static body
-- with chain shapes along its outline, rebuilt only when a stroke touches it.
-- No water yet.
--
-- play mode (tab): drag on earth to dig (or put earth back: the panel, or hold shift).
-- The panel (bottom left) has the brush size, the cell size and a new landscape.
-- keys: [ ] brush size   m: a new Mipo at the mouse   r: new landscape   t: plain / textured earth

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

-- The earth's look, worked out per pixel from where it is in the world (like the sand in
-- scripts/spikes/sea.playtime.lua): topsoil, clay, deeper ground, grain, fine roots near
-- the top. `wall` draws the dug-out back wall with the same earth, darker and flatter. 't' toggles.
local earthShader = love.graphics.newShader([[
varying vec2 wpos;
extern float wall;
#ifdef VERTEX
vec4 position(mat4 tp, vec4 vp) { wpos = vp.xy; return tp * vp; }
#endif
#ifdef PIXEL
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float depth = wpos.y;
    // the wall is the earth a metre further back: the same layers at the same depths,
    // its own grain and roots (the noise read from far away)
    vec2 wpos = wpos + vec2(5371.0, 2113.0) * step(0.25, wall);
    // the layers, their edges wobbling
    float y = depth + (vnoise(vec2(wpos.x * 0.002, 3.0)) - 0.5) * 260.0;
    vec3 topsoil = vec3(0.36, 0.25, 0.16);
    vec3 clay = vec3(0.62, 0.44, 0.28);
    vec3 deep = vec3(0.52, 0.40, 0.33);
    vec3 col = mix(topsoil, clay, smoothstep(150.0, 450.0, y));
    col = mix(col, deep, smoothstep(1500.0, 2300.0, y));
    // thin bands of sediment, and grain at three sizes
    col *= 0.94 + 0.10 * smoothstep(0.45, 0.6, vnoise(vec2(wpos.x * 0.0015, wpos.y * 0.015)));
    col *= 0.86 + hash(floor(wpos / 7.0)) * 0.12 + vnoise(wpos * 0.012) * 0.12 + vnoise(wpos * 0.003) * 0.08;
    // fine roots in the topsoil: where a stretched noise crosses one value
    float rn = vnoise(vec2(wpos.x * 0.008, wpos.y * 0.004)) + vnoise(wpos * 0.03) * 0.15;
    float root = (1.0 - smoothstep(0.0, 0.025, abs(rn - 0.5))) * (1.0 - smoothstep(200.0, 700.0, depth));
    col = mix(col, vec3(0.22, 0.15, 0.10), root * 0.7);
    // the back wall (1) darker and flatter; the sides of a tunnel (0.5) between it and the front
    col = mix(col, vec3(dot(col, vec3(0.33))), 0.3 * wall) * (1.0 - 0.5 * wall);
    return vec4(col, 1.0) * color;
}
#endif
]])

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

---------------------------------------------------------------- rocks
-- Hand-drawn rocks buried in the earth: shape8 bodies (the collision is the drawing's outline)
-- with an OMP skin (outline + mask + pattern, like a Mipo part). Kinematic while there's earth
-- under them (no dragging them out); dig it away and one shakes, turns dynamic and falls.
-- Until rocks are drawn (THINGS-TO-DRAW A8) they borrow the Mipo body outlines, in stone colours.
local ROCK_PICTURES = {}
for n = 1, 18 do
    local url = string.format('mipo/body/body-%02d.png', n)
    if shape8Dict[url] and shape8Dict[url].dimensions then ROCK_PICTURES[#ROCK_PICTURES + 1] = url end
end
local ROCK_STONES = { 'A39C8EFF', '8E8579FF', 'B4A893FF', '7D776EFF', '9A8F80FF' }
local ROCK_PATTERNS = { 'pattern3.png', 'pattern5.png', 'type4.png' }
local ROCK_COUNT = 70
local SHAKE_TIME = 0.7

local function earthAt(b, x, y)
    local i = math.floor((x - X0) / CELL + 0.5)
    local j = math.floor((y - Y0) / CELL + 0.5)
    if i < 0 or i > COLS or j < 0 or j > ROWS then return 0 end
    return b.dens[idx(i, j)] or 0
end

-- how much earth is still holding the rock up (0..1): the bottom half of a ring just outside
-- it, in the world (a rock with the earth gone from under it drops, whatever is above)
local function buriedness(b, rock)
    local x, y = rock.body:getPosition()
    local r = rock.r * 1.15
    local n, earth = 9, 0
    for k = 0, n - 1 do
        local t = k / (n - 1) * math.pi -- 0..pi: right, down, left (y is down)
        if earthAt(b, x + math.cos(t) * r, y + math.sin(t) * r) > 0.5 then earth = earth + 1 end
    end
    return earth / n
end

-- kinematic while the earth holds it (it can't be dragged and doesn't move, Mipos bump into it),
-- dynamic once it's loose
local function hold(body, held)
    if held then
        body:setType('kinematic')
        body:setLinearVelocity(0, 0)
        body:setAngularVelocity(0)
    else
        body:setType('dynamic')
        body:setAwake(true)
    end
end

local function makeRockBody(rock)
    local entry = shape8Dict[rock.url]
    local verts = {}
    for k = 1, #entry.vertices, 2 do
        verts[k], verts[k + 1] = entry.vertices[k] * rock.scale, entry.vertices[k + 1] * rock.scale
    end
    local thing = objectManager.addThing('shape8', { x = rock.x, y = rock.y, vertices = verts,
        label = 'burrow-rock', bodyType = 'dynamic' })
    if not thing then return end
    local body = thing.body
    body:setAngle(rock.angle)
    for _, fixture in ipairs(body:getFixtures()) do
        fixture:setDensity(2)
        fixture:setFriction(0.8)
        fixture:setRestitution(0.05)
    end
    body:resetMassData()
    -- the skin: the picture's document size, a little bigger, as Mipo parts do (mipo-textures)
    local grow = 1.1
    local fixture = fixtures.createSFixture(body, 0, 0, 'texfixture', {
        width = entry.dimensions[1] * rock.scale * grow, height = entry.dimensions[2] * rock.scale * grow })
    local ud = fixture:getUserData()
    ud.extra.OMP = true
    ud.extra.dirty = true
    ud.extra.zOffset = 0
    ud.extra.main = {
        bgURL = rock.url, bgHex = '2B2119FF',             -- the outline, dark earth-brown ink
        fgURL = rock.url:gsub('%.png', '-mask.png'), fgHex = rock.stone,
        pURL = rock.pattern, pHex = rock.patternHex,
    }
    hold(body, not rock.loose)
    rock.body = body
end

local function destroyRocks(b)
    for _, rock in ipairs(b.rocks or {}) do
        if rock.body and not rock.body:isDestroyed() then objectManager.destroyBody(rock.body) end
        rock.body = nil
    end
end

local function placeRocks(b)
    destroyRocks(b)
    b.rocks = {}
    if #ROCK_PICTURES == 0 then return end
    local rng = love.math.newRandomGenerator(1000 + b.seed)
    local tries = 0
    while #b.rocks < ROCK_COUNT and tries < ROCK_COUNT * 20 do
        tries = tries + 1
        local r = 45 + rng:random() ^ 2 * 190
        local x = X0 + 300 + rng:random() * (WORLD_W - 600)
        local y = surfaceAt(b, x) + 150 + r + rng:random() * (WORLD_H - 900)
        local free = y + r < Y0 + WORLD_H - 200 and earthAt(b, x, y) > 0.5
        for _, other in ipairs(b.rocks) do
            if free and (other.x - x) ^ 2 + (other.y - y) ^ 2 < (other.r + r + 40) ^ 2 then free = false end
        end
        if free then
            local url = ROCK_PICTURES[rng:random(1, #ROCK_PICTURES)]
            local dims = shape8Dict[url].dimensions
            local stone = ROCK_STONES[rng:random(1, #ROCK_STONES)]
            local rock = {
                x = x, y = y, angle = rng:random() * math.pi * 2, url = url, r = r,
                scale = 2 * r / math.max(dims[1], dims[2]),
                stone = stone, pattern = ROCK_PATTERNS[rng:random(1, #ROCK_PATTERNS)],
                patternHex = ROCK_STONES[rng:random(1, #ROCK_STONES)],
            }
            makeRockBody(rock)
            b.rocks[#b.rocks + 1] = rock
        end
    end
end

local function rocksUpdate(b, dt)
    for _, rock in ipairs(b.rocks or {}) do
        local body = rock.body
        if body and not body:isDestroyed() then
            rock.x, rock.y = body:getPosition()
            rock.angle = body:getAngle()
            if not rock.loose then
                local left = buriedness(b, rock)
                if rock.shaking then
                    if left > 0.6 then
                        rock.shaking = nil -- buried again
                    else
                        rock.shaking = rock.shaking + dt
                        -- a wobble while it works loose
                        body:setAngle(rock.angle + (love.math.random() - 0.5) * 0.03)
                        if rock.shaking >= SHAKE_TIME then
                            rock.loose, rock.shaking = true, nil
                            hold(body, false)
                        end
                    end
                elseif left < 0.45 then
                    rock.shaking = 0
                end
            end
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
    placeRocks(b)
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
    if not b.rocks or (b.rocks[1] and not b.rocks[1].url) then placeRocks(b) end
    for _, rock in ipairs(b.rocks) do
        if not rock.body or rock.body:isDestroyed() then makeRockBody(rock) end
    end
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
    destroyRocks(b)
    if b.savedDrawBodies ~= nil then state.world.debugDrawBodies = b.savedDrawBodies end
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
    elseif key == 't' then
        b.plain = not b.plain
    end
end

-- the panel's rectangle on screen, so a press on it doesn't dig
local panelRect = { 20, 0, 380, 0 }
local function overPanel()
    if ui.isPanelFolded('•• burrow ••') then return false end
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
    rocksUpdate(b, dt)
end

-- The grass on top a little 2.5D, like the clouds spike's ground (after physics-testbed's downhill and
-- scrolling-world's ground plane): the top of the ground seen from a little above, a band from a
-- back edge (further away: pulled in towards the middle of the view) to a front edge (nearer:
-- pushed out), the line the Mipos stand on in between; Nikki's grass pattern on it, a row of
-- blades at the back (behind the Mipos) and at the front (in front of their feet). The earth's
-- cut face is the side face. Only where the top is still about where the landscape had it: dig
-- into it and the grass is gone, put the earth back and it grows again.
local PLANE_DEFAULTS = { back = 0.84, front = 1.12, behind = 40, infront = 110, blades = 1, tunnel = 0.9 }
local LIGHT_GRASS = { 0x86 / 255, 0xa5 / 255, 0x42 / 255 }
local DARK_GRASS = { 0x2a / 255, 0x5b / 255, 0x3e / 255 }
local topPattern = love.graphics.newImage('textures/world/grasspattern2.png')
topPattern:setWrap('repeat', 'repeat')
local blades = love.graphics.newImage('textures/world/sprieten.png')
-- the blade atlas's quads and base pivots (src/grass.lua, measured in physics-testbed)
local BLADES = {
    { 0, 0, 49, 192, 22, 185 }, { 51, 164, 40, 197, 12, 187 }, { 51, 0, 41, 162, 19, 144 },
    { 94, 0, 46, 186, 25, 176 }, { 0, 194, 47, 231, 27, 224 }, { 94, 188, 45, 236, 16, 210 },
    { 142, 197, 47, 208, 22, 190 }, { 142, 0, 52, 195, 30, 173 },
}
local bladeQuads = {}
for i, q in ipairs(BLADES) do bladeQuads[i] = love.graphics.newQuad(q[1], q[2], q[3], q[4], blades:getDimensions()) end
local backBlades = love.graphics.newSpriteBatch(blades, 2000, 'stream')
local frontBlades = love.graphics.newSpriteBatch(blades, 2000, 'stream')
local TOP_MAX = 6 * (math.floor(WORLD_W / CELL_MIN) + 2)
local topMesh = love.graphics.newMesh(TOP_MAX, 'triangles', 'stream')
local BAND_DEPTH = 700

local function plane(b)
    b.plane = b.plane or {}
    for k, v in pairs(PLANE_DEFAULTS) do
        if b.plane[k] == nil then b.plane[k] = v end
    end
    return b.plane
end

local function viewCentre()
    local w, h = love.graphics.getDimensions()
    local cx, cy = cam:getWorldCoordinates(w / 2, h / 2)
    return cx, cy, w, cam:getScale()
end

-- a point at depth k (1 = the line the Mipos stand on), as it shows through the real camera
local function project(x, y, k, cx, cy)
    return cx + (x - cx) * k, cy + (y - cy) * k
end

-- the visible columns' tops: the first earth from above, if it's still the grassy surface
local function grassTops(b, k)
    local cx, _, w, scale = viewCentre()
    local half = w / 2 / scale / k + CELL * 2
    local i0 = math.max(0, math.floor((cx - half - X0) / CELL))
    local i1 = math.min(COLS, math.ceil((cx + half - X0) / CELL))
    local dens, tops = b.dens, {}
    for i = i0, i1 do
        local j = 0
        while j <= ROWS and dens[idx(i, j)] < 0.5 do j = j + 1 end
        if j > 0 and j <= ROWS then
            local y = Y0 + (j - 1 + crossing(dens[idx(i, j - 1)], dens[idx(i, j)])) * CELL
            if math.abs(y - b.surface[i]) < CELL * 1.5 then tops[i] = y end
        end
    end
    return tops, i0, i1
end

-- the band's edges at one column, kept at least `behind` / `infront` from the line (with the eye
-- under the ground the perspective would turn the band over)
local function edges(pl, x, y, cx, cy)
    local bx, by = project(x, y - pl.behind, pl.back, cx, cy)
    local fx, fy = project(x, y + pl.infront, pl.front, cx, cy)
    return bx, math.min(by, y - pl.behind), fx, math.max(fy, y + pl.infront)
end

local function drawGrassTop(b)
    local pl = plane(b)
    local cx, cy = viewCentre()
    local tops, i0, i1 = grassTops(b, pl.back)
    b.tops = tops
    local tw, th = topPattern:getWidth() * 1.6, topPattern:getHeight() * 1.6
    local verts = {}
    for i = i0, i1 - 1 do
        local ya, yb = tops[i], tops[i + 1]
        if ya and yb and #verts + 6 <= TOP_MAX then
            local xa, xb = X0 + i * CELL, X0 + (i + 1) * CELL
            local bax, bay, fax, fay = edges(pl, xa, ya, cx, cy)
            local bbx, bby, fbx, fby = edges(pl, xb, yb, cx, cy)
            local A = { bax, bay, xa / tw, 0, 1, 1, 1, 1 }
            local B = { bbx, bby, xb / tw, 0, 1, 1, 1, 1 }
            local C = { fbx, fby, xb / tw, BAND_DEPTH / th, 1, 1, 1, 1 }
            local D = { fax, fay, xa / tw, BAND_DEPTH / th, 1, 1, 1, 1 }
            verts[#verts + 1] = A; verts[#verts + 1] = B; verts[#verts + 1] = C
            verts[#verts + 1] = A; verts[#verts + 1] = C; verts[#verts + 1] = D
        end
    end
    if #verts == 0 then return end
    topMesh:setVertices(verts)
    topMesh:setDrawRange(1, #verts)
    topMesh:setTexture()
    love.graphics.setColor(LIGHT_GRASS[1], LIGHT_GRASS[2], LIGHT_GRASS[3], 1)
    love.graphics.draw(topMesh)
    topMesh:setTexture(topPattern)
    love.graphics.setColor(DARK_GRASS[1], DARK_GRASS[2], DARK_GRASS[3], 0.8)
    love.graphics.draw(topMesh)
end

-- The inside of what's dug, in depth: the back wall is further away (pulled in towards the middle
-- of the view by `tunnel`), and every edge of the earth is joined to it by a face, like a box cut
-- out of the ground. Floors face up (lit), ceilings down (darker), walls to the side; a face turned
-- away from the eye lands inside the earth and the earth's front face covers it.
local LIGHT_DIR = { -0.4, -0.92 }
local sideMesh, sideMax = nil, 0
local function drawTunnelSides(b)
    local k = plane(b).tunnel
    local cx, cy = viewCentre()
    local verts = {}
    for _, chunk in pairs(b.chunks) do
        for _, o in ipairs(chunk.outlines) do
            local f, n = o.flat, #o.flat
            local last = o.loop and n or n - 2
            for a = 1, last, 2 do
                local b2 = a + 2
                if b2 > n then b2 = 1 end
                local ax, ay, bx, by = f[a], f[a + 1], f[b2], f[b2 + 1]
                local dx, dy = bx - ax, by - ay
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 1e-3 then
                    -- the face's normal, pointing into the air
                    local nx, ny = dy / len, -dx / len
                    local mx, my = (ax + bx) / 2, (ay + by) / 2
                    if earthAt(b, mx + nx * CELL * 0.5, my + ny * CELL * 0.5) > 0.5 then nx, ny = -nx, -ny end
                    local lit = 0.62 + 0.38 * math.max(0, nx * LIGHT_DIR[1] + ny * LIGHT_DIR[2])
                    if ny > 0.3 then lit = lit * 0.75 end                    -- a ceiling
                    local pax, pay = project(ax, ay, k, cx, cy)
                    local pbx, pby = project(bx, by, k, cx, cy)
                    local A = { ax, ay, 0, 0, lit, lit, lit, 1 }
                    local B = { bx, by, 0, 0, lit, lit, lit, 1 }
                    local Bp = { pbx, pby, 0, 0, lit, lit, lit, 1 }
                    local Ap = { pax, pay, 0, 0, lit, lit, lit, 1 }
                    verts[#verts + 1] = A; verts[#verts + 1] = B; verts[#verts + 1] = Bp
                    verts[#verts + 1] = A; verts[#verts + 1] = Bp; verts[#verts + 1] = Ap
                end
            end
        end
    end
    if #verts == 0 then return end
    if #verts > sideMax then
        sideMax = math.max(#verts * 2, 6000)
        sideMesh = love.graphics.newMesh(sideMax, 'triangles', 'stream')
    end
    sideMesh:setVertices(verts)
    sideMesh:setDrawRange(1, #verts)
    love.graphics.draw(sideMesh)
end

-- the back wall at the tunnels' depth
local function drawBackWall(b)
    local k = plane(b).tunnel
    local cx, cy = viewCentre()
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(k)
    love.graphics.translate(-cx, -cy)
    love.graphics.draw(b.wall)
    love.graphics.pop()
end

-- a row of blades on the grassy top, at the back (front = false) or the front edge
local function bladeRow(b, batch, front, seedP, size)
    local pl, tops = plane(b), b.tops
    if not tops or pl.blades <= 0 then return end
    local cx, cy, w, scale = viewCentre()
    local k = front and pl.front or pl.back + 0.02
    local half = w / 2 / scale / k + 400
    local step = math.max(55, 6 / scale)
    local t = love.timer.getTime()
    batch:clear()
    for x = math.floor((cx - half) / step) * step, cx + half, step do
        local fi = (x - X0) / CELL
        local i = math.floor(fi)
        local ya, yb = tops[i], tops[i + 1]
        if ya and yb then
            local y = ya + (yb - ya) * (fi - i)
            local bx, by, fx, fy = edges(pl, x, y, cx, cy)
            local px, py = bx, by
            if front then px, py = fx, fy end
            local hh = 0.3 + love.math.noise(x / 1000, seedP) * 0.9
            local n = math.min(#BLADES, 1 + math.floor(love.math.noise(x * 0.37, seedP * 3.1) * #BLADES))
            local q = BLADES[n]
            local ang = math.sin(hh * 9) * 0.1 + math.sin(t * 1.3 + x * 0.003) * 0.06
            local sz = size * k * pl.blades
            batch:add(bladeQuads[n], px, py, ang, sz, sz * hh, q[5], q[6])
        end
    end
    love.graphics.draw(batch)
end

function s.drawUI()
    local b = state.burrow
    if not (b and state.playMode) then return end
    ui.startFrame() -- play mode draws no editor UI, so nothing else starts the frame
    local BH, pad, w = 40, 10, 380
    local h = BH * 12 + pad * 13 + 20
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
            placeRocks(b)
            rebuildEverything(b)
        end
        -- the grass top's plane: depth of its back and front edges, how far they're off the line,
        -- the blades' size
        local pl = plane(b)
        for _, row in ipairs({ { 'back', 0.5, 1 }, { 'front', 1, 1.6 }, { 'behind', 0, 400, 1 },
            { 'infront', 0, 400, 1 }, { 'blades', 0, 3 }, { 'tunnel', 0.6, 1 } }) do
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            v = ui.sliderWithInput('burrowplane' .. row[1], x, y, 160, row[2], row[3], pl[row[1]], nil, row[4])
            if v then pl[row[1]] = v + 0 end
            ui.label(x + 260, y, row[1])
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'shift: the other one  m: Mipo  t: plain')
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
    if not b.plain then love.graphics.setShader(earthShader) end
    earthShader:send('wall', 1)
    love.graphics.setColor(b.plain and wallColor or { 1, 1, 1, 1 })
    if b.wall then
        if b.plain then love.graphics.draw(b.wall) else drawBackWall(b) end
    end
    if not b.plain then
        earthShader:send('wall', 0.5)
        drawTunnelSides(b)
    end
    earthShader:send('wall', 0)
    love.graphics.setColor(b.plain and earthColor or { 1, 1, 1, 1 })
    for _, chunk in pairs(b.chunks) do
        if chunk.mesh then love.graphics.draw(chunk.mesh) end
    end
    love.graphics.setShader()
    love.graphics.setColor(rimColor)
    love.graphics.setLineWidth(8)
    love.graphics.setLineJoin('bevel')
    for _, chunk in pairs(b.chunks) do
        for _, o in ipairs(chunk.outlines) do
            if o.loop then love.graphics.polygon('line', o.flat) else love.graphics.line(o.flat) end
        end
    end
    love.graphics.setLineWidth(1)
    if not b.plain then
        drawGrassTop(b)
        love.graphics.setColor(DARK_GRASS[1], DARK_GRASS[2], DARK_GRASS[3], 1)
        bladeRow(b, backBlades, false, 1, 1.5)
    end
    love.graphics.setColor(1, 1, 1, 1)
    -- the plain debug lines of the earth's chains would show over the grass (the Mipos and rocks
    -- draw themselves); back on in draw
    if state.playMode then
        b.savedDrawBodies = state.world.debugDrawBodies
        state.world.debugDrawBodies = false
    end
end

function s.draw()
    local b = state.burrow
    if not b then return end
    if b.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = b.savedDrawBodies
        b.savedDrawBodies = nil
    end
    if not b.plain and b.chunks then
        love.graphics.setColor(LIGHT_GRASS[1] * 1.15, LIGHT_GRASS[2] * 1.12, LIGHT_GRASS[3] * 0.95, 1)
        bladeRow(b, frontBlades, true, 2, 2.0)
        love.graphics.setColor(1, 1, 1, 1)
    end
    if not state.playMode then return end
    local mx, my = mouseWorldPos()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(4)
    love.graphics.circle('line', mx, my, b.brush)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return s
