-- spine-skin.lua
-- A Mipo spine (creation.torsoSpine, docs/MIPO-SPINE.md S2): torso1 draws the whole torso
-- picture; these bend it over the bands. Points are given in torso1's local space as they
-- are at rest (all bands straight); each follows the band it lies on, blended between two
-- bands around their cut so there's no crease (linear blend skinning: fine for the small
-- angles a spine bends), and comes back in torso1's local space, so the usual
-- love.graphics.draw(mesh, body x, y, angle) still places it.
local mipoRegistry = require('src.mipo-registry')
local mathutils = require('src.math-utils')
local shape8Dict = require('src.shape8-dict')
local topology = require('src.character-topology')

local lib = {}

lib.blend = 0.6   -- part of the distance between two band middles that blends them
lib.columns = 3   -- grid cells across the picture
lib.rows = 12     -- grid cells down the picture

local function smoothstep(t)
    if t <= 0 then return 0 elseif t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

-- The bones of a spine torso when `body` is its torso1: { bodies = { torso1.. }, middles = {
-- each band's middle y in torso1's local space at rest }, originY = where the whole torso
-- shape's centre is in torso1's local space, outline = the whole torso outline around that
-- centre (as a whole torso's thing.vertices) }; nil for anything else.
function lib.bonesOf(body)
    local instance, partName = mipoRegistry.getFromBody(body)
    if partName ~= 'torso1' then return nil end
    local creation = instance.dna and instance.dna.creation
    local count = creation and creation.torsoSpine and creation.torsoSegments or 1
    if count < 2 then return nil end
    local partData = instance.dna.parts.torso1
    local raw = partData.shape8URL and shape8Dict[partData.shape8URL]
    if not raw then return nil end
    local sy = (partData.dims.sy or 1) * (instance.scale or 1)
    local flipY = (partData.dims.sy or 1) < 0
    local bodies, middles = {}, {}
    local _, first = topology.spineBand(raw.vertices, 1, count, flipY)
    local sx = (partData.dims.sx or 1) * (instance.scale or 1)
    local outline = {}
    for k = 1, #raw.vertices, 2 do outline[k], outline[k + 1] = raw.vertices[k] * sx, raw.vertices[k + 1] * sy end
    for i = 1, count do
        local part = instance.parts['torso' .. i]
        if not (part and part.body and not part.body:isDestroyed()) then return nil end
        local _, middle = topology.spineBand(raw.vertices, i, count, flipY)
        bodies[i] = part.body
        middles[i] = (middle - first) * sy
    end
    return { bodies = bodies, middles = middles, originY = -first * sy, outline = outline }
end

-- Bend a flat list of torso1-local rest points (x1, y1, x2, y2, ...) over the bones;
-- writes into `out` (or a new table) and returns it.
function lib.deform(points, bones, out)
    out = out or {}
    local bodies, middles = bones.bodies, bones.middles
    local n = #bodies
    local root = bodies[1]
    for k = 1, #points - 1, 2 do
        local x, y = points[k], points[k + 1]
        -- the two bands around y and how much of the second
        local a, w = 1, 0
        for i = 1, n - 1 do
            local s = (y - middles[i]) / (middles[i + 1] - middles[i])
            if s >= 0 or i == 1 then
                a = i
                w = smoothstep((s - 0.5) / lib.blend + 0.5)
            end
        end
        if n == 1 then w = 0 end
        local b = math.min(a + 1, n)
        local ax, ay = bodies[a]:getWorldPoint(x, y - middles[a])
        local bx, by = bodies[b]:getWorldPoint(x, y - middles[b])
        out[k], out[k + 1] = root:getLocalPoint(ax + (bx - ax) * w, ay + (by - ay) * w)
    end
    return out
end

-- A transform (world space) that carries something drawn on torso1 around its rest point
-- (x, y) (torso1-local) to where the bent torso has that point, turned with the bend there:
-- a face part keeps its shape and rides the spine. nil when `body` is no spine torso1.
local transform, toBody, fromBody = nil, nil, nil
function lib.transformAt(body, x, y)
    local bones = lib.bonesOf(body)
    if not bones then return nil end
    transform = transform or love.math.newTransform()
    toBody = toBody or love.math.newTransform()
    fromBody = fromBody or love.math.newTransform()
    local p = lib.deform({ x, y, x + 10, y }, bones)
    local turn = math.atan2(p[4] - p[2], p[3] - p[1])
    local bx, by, angle = body:getX(), body:getY(), body:getAngle()
    toBody:setTransformation(bx, by, angle)
    fromBody:setTransformation(bx, by, angle)
    fromBody = fromBody:inverse()
    transform:reset()
    transform:apply(toBody)
    transform:translate(p[1], p[2])
    transform:rotate(turn)
    transform:translate(-x, -y)
    transform:apply(fromBody)
    return transform
end

-- The squish fan (box2d-draw-textured drawSquishableHairOver) for an 8-point ring: a
-- centre at uv (0.5, 0.5), ring points at these uvs. Bodyhair is drawn that way.
local ringUV = { 0, 0, 0.5, 0, 1, 0, 1, 0.5, 1, 1, 0.5, 1, 0, 1, 0, 0.5 }

-- Where the fan puts uv (u, v), given the ring (16 numbers) and its centre.
function lib.fanPoint(ring, cx, cy, u, v)
    for i = 1, 8 do
        local j = i % 8 + 1
        local ax, ay = ringUV[i * 2 - 1], ringUV[i * 2]
        local bx, by = ringUV[j * 2 - 1], ringUV[j * 2]
        -- barycentric of (u, v) in the uv triangle (0.5, 0.5), a, b
        local d = (ay - by) * (0.5 - bx) + (bx - ax) * (0.5 - by)
        local wc = ((ay - by) * (u - bx) + (bx - ax) * (v - by)) / d
        local wa = ((by - 0.5) * (u - bx) + (0.5 - bx) * (v - by)) / d
        local wb = 1 - wc - wa
        if wc >= -1e-6 and wa >= -1e-6 and wb >= -1e-6 then
            return wc * cx + wa * ring[i * 2 - 1] + wb * ring[j * 2 - 1],
                wc * cy + wa * ring[i * 2] + wb * ring[j * 2]
        end
    end
    return cx, cy
end

-- Bodyhair on a spine torso: the fan of 8 ring points (a few big triangles across several
-- bands) made the hair slide over the bending picture. Here the same fan picture is laid
-- as a fine grid at rest (the fan's own mapping, so it looks the same straight) and every
-- grid point follows its band like the torso picture does.
-- [extra] = { [img] = { key, mesh, img, rest, bent, verts } } (bodyhair draws two layers)
local fans = setmetatable({}, { __mode = 'k' })

function lib.drawFan(img, ring, bones, body, extra)
    local n = lib.rows
    local key = table.concat(ring, ',')
    local byImg = fans[extra]
    if not byImg then
        byImg = setmetatable({}, { __mode = 'k' })
        fans[extra] = byImg
    end
    local cache = byImg[img]
    if not cache or cache.key ~= key then
        local verts, map, rest = {}, {}, {}
        local cx, cy = mathutils.getCenterOfPoints(ring)
        for r = 0, n do
            for c = 0, n do
                local i = r * (n + 1) + c + 1
                local u, v = c / n, r / n
                rest[i * 2 - 1], rest[i * 2] = lib.fanPoint(ring, cx, cy, u, v)
                verts[i] = { 0, 0, u, v }
            end
        end
        for r = 0, n - 1 do
            for c = 0, n - 1 do
                local v = r * (n + 1) + c + 1
                for _, idx in ipairs({ v, v + 1, v + n + 1, v + 1, v + n + 2, v + n + 1 }) do map[#map + 1] = idx end
            end
        end
        local mesh = cache and cache.mesh or love.graphics.newMesh(verts, 'triangles', 'stream')
        mesh:setVertexMap(map)
        mesh:setTexture(img)
        cache = { key = key, mesh = mesh, img = img, rest = rest, bent = {}, verts = verts }
        byImg[img] = cache
    end
    local bent = lib.deform(cache.rest, bones, cache.bent)
    for i, d in ipairs(cache.verts) do d[1], d[2] = bent[i * 2 - 1], bent[i * 2] end
    cache.mesh:setVertices(cache.verts)
    love.graphics.draw(cache.mesh, body:getX(), body:getY(), body:getAngle())
end

-- Draw `img` over the rectangle `corners` (4 points, torso1-local, top left first, as the
-- texfixture's shape gives them) as a bent grid. The mesh lives here, never on `extra`
-- (that is saved to the scene file). bones.deform, when there, bends instead of
-- lib.deform (a Mipo ear: src/ear-bend.lua).
local meshes = setmetatable({}, { __mode = 'k' }) -- [extra] = { mesh, img, rest, verts }

-- The grid laid and bent in C when the native library is there (native/desound/grid.c,
-- lib.useNative): spine torsos and ears. In Lua each point cost three calls into Box2D
-- (getWorldPoint twice, getLocalPoint): ~30 us a picture on an iPhone SE 2, the bent pictures
-- were 55% of the textured draw with 20 Mipos (2026-10-31). C gets each bone's transform once.
lib.useNative = true
local nativeLib = require('src.native-lib')
local ffi = nativeLib.ffi
local CDEF = [[
int grid_spine(const float *corners, int cols, int rows, const float *bones, const float *middles,
               int nBones, float blend, float *out);
int grid_ear(const float *corners, int cols, int rows, const float *ear, const float *parent,
             float restAngle, float anchorX, float anchorY, float rootX, float rootY,
             float axisX, float axisY, float length, float bendLength, float *out);
]]
local C -- the library, false without one (nil: not asked yet)
local cornerBuf = ffi and ffi.new('float[8]')
local boneBuf = ffi and ffi.new('float[96]') -- 32 bones x { x, y, angle } (grid.c's most)
local middleBuf = ffi and ffi.new('float[32]')
local earBuf, parentBuf = ffi and ffi.new('float[3]'), ffi and ffi.new('float[3]')
local gridData, gridOut -- one ByteData the C writes into; setVertices copies it

local function xformInto(buf, offset, body)
    buf[offset], buf[offset + 1], buf[offset + 2] = body:getX(), body:getY(), body:getAngle()
end

-- The bent grid written by C into gridData; returns the vertex count, or nil for the Lua path.
local function bendInC(corners, bones, cols, rows)
    for k = 1, 8 do cornerBuf[k - 1] = corners[k] end
    if bones.ear then
        xformInto(earBuf, 0, bones.ear)
        xformInto(parentBuf, 0, bones.parent)
        local bendLength = require('src.ear-bend').bendLength -- here, not on top: no require loop
        return C.grid_ear(cornerBuf, cols, rows, earBuf, parentBuf, bones.restAngle, bones.anchorX,
            bones.anchorY, bones.rootX, bones.rootY, bones.axisX, bones.axisY, bones.length, bendLength,
            gridOut)
    end
    local bodies, middles = bones.bodies, bones.middles
    if #bodies > 32 then return nil end
    for i, b in ipairs(bodies) do
        xformInto(boneBuf, (i - 1) * 3, b)
        middleBuf[i - 1] = middles[i]
    end
    return C.grid_spine(cornerBuf, cols, rows, boneBuf, middleBuf, #bodies, lib.blend, gridOut)
end

local function ensureGridData(count)
    if not gridData or gridData:getSize() < count * nativeLib.BYTES_PER_VERTEX then
        gridData = love.data.newByteData(count * nativeLib.BYTES_PER_VERTEX)
        gridOut = ffi.cast('float *', gridData:getFFIPointer())
    end
end

-- For specs (spec/grid-native_spec.lua): the bent grid as C lays it, flat { x, y, ... } row by
-- row; nil without the library.
function lib.bentGridC(corners, bones)
    if C == nil then C = nativeLib.load(CDEF, 'grid_spine') end
    if not C then return nil end
    local cols, rows = lib.columns, lib.rows
    ensureGridData((cols + 1) * (rows + 1))
    local n = bendInC(corners, bones, cols, rows)
    if not n then return nil end
    local out = {}
    for i = 0, n - 1 do out[i * 2 + 1], out[i * 2 + 2] = gridOut[i * 4], gridOut[i * 4 + 1] end
    return out
end

function lib.drawGrid(img, corners, bones, body, extra)
    local cols, rows = lib.columns, lib.rows
    if C == nil then C = nativeLib.load(CDEF, 'grid_spine') end
    -- an ear's bones or a spine's (no deform of their own); anything else bends in Lua
    local useNative = lib.useNative and C and (bones.ear ~= nil or not bones.deform) and #corners == 8
    local count = (cols + 1) * (rows + 1)
    local cache = meshes[extra]
    if not cache or cache.img ~= img or cache.native ~= useNative or cache.count ~= count then
        local verts, map = {}, {}
        for i = 1, count do verts[i] = { 0, 0, 0, 0 } end
        for r = 0, rows - 1 do
            for c = 0, cols - 1 do
                local v = r * (cols + 1) + c + 1
                local list = { v, v + 1, v + cols + 1, v + 1, v + cols + 2, v + cols + 1 }
                for _, idx in ipairs(list) do map[#map + 1] = idx end
            end
        end
        local mesh = useNative and love.graphics.newMesh(nativeLib.FORMAT, count, 'triangles', 'stream')
            or love.graphics.newMesh(verts, 'triangles', 'stream')
        mesh:setVertexMap(map)
        mesh:setTexture(img)
        if cache then cache.mesh:release() end
        cache = { mesh = mesh, img = img, rest = {}, bent = {}, verts = verts, native = useNative, count = count }
        meshes[extra] = cache
    end
    if useNative then
        ensureGridData(count)
        local n = bendInC(corners, bones, cols, rows)
        if n and n > 0 then
            cache.mesh:setVertices(gridData, 1, n)
            love.graphics.draw(cache.mesh, body:getX(), body:getY(), body:getAngle())
            return
        end
    end
    -- rest grid over the rectangle (bilinear between its corners)
    local x1, y1, x2, y2, x3, y3, x4, y4 = unpack(corners)
    local rest = cache.rest
    for r = 0, rows do
        local v = r / rows
        for c = 0, cols do
            local u = c / cols
            local k = (r * (cols + 1) + c) * 2 + 1
            local tx, ty = x1 + (x2 - x1) * u, y1 + (y2 - y1) * u
            local bx, by = x4 + (x3 - x4) * u, y4 + (y3 - y4) * u
            rest[k], rest[k + 1] = tx + (bx - tx) * v, ty + (by - ty) * v
        end
    end
    local bent = (bones.deform or lib.deform)(rest, bones, cache.bent)
    local verts = cache.verts
    for r = 0, rows do
        for c = 0, cols do
            local i = r * (cols + 1) + c + 1
            local d = verts[i]
            d[1], d[2], d[3], d[4] = bent[i * 2 - 1], bent[i * 2], c / cols, r / rows
        end
    end
    cache.mesh:setVertices(verts)
    love.graphics.draw(cache.mesh, body:getX(), body:getY(), body:getAngle())
end

return lib
