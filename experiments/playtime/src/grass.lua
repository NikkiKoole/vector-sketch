-- grass.lua — the GRASS sfixture: blades along the up-facing edges of its body
-- (docs/WORLD-BUILDING.md G1). Height, sprite and lean come from noise on the
-- blade's place along the body (body-local), so a scene looks the same every
-- load and the blades ride along if the body moves. Two layers: the back one at
-- the sfixture's own z (behind the Mipos), the front one at FRONT_Z (in front of
-- every Mipo z-group). Each layer is one SpriteBatch, built when the body or a
-- setting changes; the sway only moves the sprites already in it.
local lib = {}

-- physics-testbed's blade atlas (the same 8 drawings as puppet-maker2's spriet1-8)
lib.ATLAS = 'textures/world/sprieten.png'
-- { x, y, w, h, pivotX, pivotY }: quads and base pivots measured in physics-testbed (downhill.lua:523-532)
lib.QUADS = {
    { 0, 0, 49, 192, 22, 185 },
    { 51, 164, 40, 197, 12, 187 },
    { 51, 0, 41, 162, 19, 144 },
    { 94, 0, 46, 186, 25, 176 },
    { 0, 194, 47, 231, 27, 224 },
    { 94, 188, 45, 236, 16, 210 },
    { 142, 197, 47, 208, 22, 190 },
    { 142, 0, 52, 195, 30, 173 },
}
lib.FRONT_Z = 1000000 -- above every Mipo z-group (zGroupOffset * 1000, groups count up from 1)

-- What a new grass sfixture starts with (also the fallback for missing keys).
lib.defaults = {
    density = 8,         -- blades per 100 units of edge
    height = 90,         -- world units, a blade at noise 1
    heightVariation = 0.5, -- 0 = all the same height, 1 = from nothing to `height`
    width = 1,           -- blade width relative to its height-scaled sprite
    frontShare = 0.25,   -- part of the blades drawn in front of the Mipos
    maxSlope = 50,       -- degrees: steeper edges get no grass
    sway = 1,            -- 0 = still
    colorBack = '2a5b3eff',
    colorFront = '86a542ff',
    seed = 0,
}

local function noise(...)
    if love and love.math then return love.math.noise(...) end
    return 0.5
end

-- A deterministic 0..1 per spot: unlike noise it's evenly spread, so 'a quarter in front' is a quarter.
local function hash(x, y, salt)
    local v = math.sin(x * 12.9898 + y * 78.233 + salt * 37.719) * 43758.5453
    return v - math.floor(v)
end

local function setting(extra, key)
    local v = extra[key]
    if v == nil then return lib.defaults[key] end
    return v
end

-- Blades for a polygon (flat {x1, y1, x2, y2, ...}, body-local) on a body at `angle`.
-- Returns { { x, y, quad, scale, lean, phase, front }, ... } in body-local units.
function lib.placeBlades(vertices, angle, extra)
    local blades = {}
    local n = #vertices / 2
    if n < 3 then return blades end

    -- winding decides which side of an edge is outside (y points down)
    local area = 0
    for i = 1, n do
        local j = i % n + 1
        area = area + vertices[i * 2 - 1] * vertices[j * 2] - vertices[j * 2 - 1] * vertices[i * 2]
    end
    local outward = area > 0 and 1 or -1

    local cosA, sinA = math.cos(angle), math.sin(angle)
    local minUp = math.cos(math.rad(setting(extra, 'maxSlope')))
    local spacing = 100 / math.max(0.1, setting(extra, 'density'))
    local variation = setting(extra, 'heightVariation')
    local frontShare = setting(extra, 'frontShare')
    local seed = setting(extra, 'seed')

    for i = 1, n do
        local j = i % n + 1
        local x1, y1 = vertices[i * 2 - 1], vertices[i * 2]
        local x2, y2 = vertices[j * 2 - 1], vertices[j * 2]
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            -- outward normal in body space, then turned into the world
            local nx, ny = dy / len * outward, -dx / len * outward
            local worldNy = nx * sinA + ny * cosA
            if -worldNy >= minUp then
                local count = math.floor(len / spacing)
                for k = 0, count - 1 do
                    local t = (k + 0.5) / count
                    local x, y = x1 + dx * t, y1 + dy * t
                    -- height rolls smoothly along the edge (clumps), the rest differs per blade
                    local h = noise(x / 300, y / 300, seed + 0.5)
                    blades[#blades + 1] = {
                        x = x, y = y,
                        quad = math.min(#lib.QUADS, math.floor(hash(x, y, seed + 1) * #lib.QUADS) + 1),
                        scale = (1 - variation) + variation * h,
                        lean = (hash(x, y, seed + 2) - 0.5) * 0.5,
                        phase = hash(x, y, seed + 3) * math.pi * 2,
                        front = hash(x, y, seed + 4) < frontShare,
                    }
                end
            end
        end
    end
    return blades
end

-- Cache per sfixture (keyed by its extra table, weak): batches + blades. Only a cache,
-- so a hot reload emptying it just rebuilds. Kept out of `extra` so it isn't saved.
local cache = setmetatable({}, { __mode = 'k' })
local atlas, quads

local function loadAtlas()
    if atlas then return atlas end
    if not love.filesystem.getInfo(lib.ATLAS) then return nil end
    atlas = love.graphics.newImage(lib.ATLAS)
    quads = {}
    for i, q in ipairs(lib.QUADS) do
        quads[i] = love.graphics.newQuad(q[1], q[2], q[3], q[4], atlas:getDimensions())
    end
    return atlas
end

local SIGNATURE_KEYS = { 'density', 'height', 'heightVariation', 'width', 'frontShare', 'maxSlope',
    'colorBack', 'colorFront', 'seed' }

local function signature(extra, vertices, angle)
    local parts = { tostring(vertices), #vertices, string.format('%.3f', angle) }
    for _, key in ipairs(SIGNATURE_KEYS) do parts[#parts + 1] = tostring(setting(extra, key)) end
    return table.concat(parts, '|')
end

local function hexColor(hex)
    local function byte(i) return (tonumber(hex:sub(i, i + 1), 16) or 255) / 255 end
    return byte(1), byte(3), byte(5), #hex >= 8 and byte(7) or 1
end

local function setBlade(batch, id, blade, extra, angle, time)
    local q = lib.QUADS[blade.quad]
    local s = setting(extra, 'height') * blade.scale / q[4]
    local sway = setting(extra, 'sway') * (math.sin(time * 1.7 + blade.phase) * 0.06
        + math.sin(time * 0.6 + blade.phase * 0.3) * 0.04)
    -- grass grows up in the world, whatever the body's angle
    batch:set(id, quads[blade.quad], blade.x, blade.y, blade.lean + sway - angle,
        s * setting(extra, 'width'), s, q[5], q[6])
end

-- thing.vertices aren't always body-local: a ribbon keeps them around its centroid, and the body
-- sits on that centroid (the tile-repeat draw does the same subtraction).
local function bodyLocal(vertices)
    local cx, cy = require('src.math-utils').computeCentroid(vertices)
    local out = {}
    for i = 1, #vertices, 2 do
        out[i], out[i + 1] = vertices[i] - cx, vertices[i + 1] - cy
    end
    return out
end

local function build(extra, thing, angle)
    local blades = lib.placeBlades(bodyLocal(thing.vertices), angle, extra)
    local entry = { blades = blades, signature = signature(extra, thing.vertices, angle) }
    for _, layer in ipairs({ 'back', 'front' }) do
        local batch = love.graphics.newSpriteBatch(atlas, math.max(1, #blades), 'dynamic')
        local r, g, b, a = hexColor(setting(extra, layer == 'front' and 'colorFront' or 'colorBack'))
        batch:setColor(r, g, b, a)
        local ids = {}
        for i, blade in ipairs(blades) do
            if blade.front == (layer == 'front') then
                ids[i] = batch:add(quads[blade.quad], blade.x, blade.y)
            end
        end
        entry[layer] = { batch = batch, ids = ids }
    end
    cache[extra] = entry
    return entry
end

-- Draw one layer ('back' or 'front') of a grass sfixture on `body` (thing = its thing).
function lib.draw(extra, thing, body, layer)
    if not thing or not thing.vertices or not body or body:isDestroyed() then return end
    if not loadAtlas() then return end
    local angle = body:getAngle()
    local entry = cache[extra]
    if not entry or entry.signature ~= signature(extra, thing.vertices, angle) then
        entry = build(extra, thing, angle)
    end
    local part = entry[layer]
    local time = love.timer.getTime()
    for i, id in pairs(part.ids) do
        setBlade(part.batch, id, entry.blades[i], extra, angle, time)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(part.batch, body:getX(), body:getY(), angle)
end

return lib
