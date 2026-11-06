-- cloth: curtains, flags, sheets — a grid of points moved by a small verlet step of its own (not
-- Box2D), held together by distance constraints, drawn as one textured mesh (docs/CLOTH.md).
--
--   local c = cloth.new({ x = 0, y = -600, cols = 18, rows = 22, spacing = 14, pin = 'rail' })
--   cloth.update(c, dt)   -- frames of 1/60 in `substeps` small steps; collides with Box2D bodies
--   cloth.draw(c)
--
-- Pins: 'top' (every point of the top row), 'corners' (top two: a sheet on a line), 'left' (the
-- left column: a flag on a pole), 'rail' (the top row slides on a rail: a curtain you push open),
-- 'ring' (every `ringEvery` top point fixed). A pin can follow a body (`pinBody`): it's kept in the
-- body's frame, so a flag goes where its pole goes.
--
-- The step and the mesh run in C when the native library has them (native/desound/cloth.c, ~20x
-- the Lua); else (the web, pure specs) the same in Lua here. Both read one layout: 1-based arrays
-- of numbers (FFI arrays or tables), flags as 0/1.
--
-- Points are px; tuned numbers (wind) are at 100 px/m, through physics-units.

local units = require('src.physics-units')
local state = require('src.state')
local nativeLib = require('src.native-lib')
local ffi = nativeLib.ffi

local lib = {}

local FRAME = 1 / 60
local MAX_FRAMES = 3
local SHAPE_STRIDE = 24 -- floats a shape, as cloth.c reads them
local MAX_SHAPES = 64
local MAX_OUTLINE = 8192
local COLLIDE_MAX_PUSH = 3 -- px a substep a point is moved out of a shape (cloth.c)
local COLLIDE_FRICTION = 0.3 -- of the speed along a surface, lost a 1/60 (spread over the substeps)

local CDEF = [[
typedef struct {
    int n, cols, rows, nc;
    float *x, *y, *z, *px, *py, *pz, *inv, *pinx, *piny, *railY;
    float *sx, *sy;
    uint8_t *rail;
    int *ca, *cb;
    float *cr, *ck;
    uint8_t *alive, *structural;
    uint8_t *quad;
    uint8_t *scratch;
    float railMin, railMax;
    int grabbed;
    float grabX, grabY;
    float gravity, wind, gust, damping, thickness, time, tear;
    int iterations;
    float flutter, drag, lift, perspective, cx, cy;
} ClothSim;
int cloth_frame(ClothSim *c, float frame, int substeps, const float *shapes, int nshapes, float *impulses);
int cloth_map(ClothSim *c, const int *hEdge, const int *vEdge, uint32_t *map);
void cloth_vertices(ClothSim *c, void *out, const float *uv, float tr, float tg, float tb,
                    float shade, float spacing);
int cloth_outline(ClothSim *c, float *out, int maxFloats);
]]

local C
local function native()
    if C == nil then C = nativeLib.load(CDEF, 'cloth_frame') end
    return C
end

-- false: always the Lua path (to compare)
lib.useNative = true
function lib.nativeAvailable() return native() ~= false end

lib.defaults = {
    cols = 18, rows = 22, spacing = 14,
    pin = 'top', ringEvery = 3,
    -- The points move in 3D and the cloth is drawn flat (cloth.c's top comment): after Müller's
    -- Ten Minute Physics #14 — many small steps, sides that don't stretch, soft bending, almost no
    -- damping, real gravity; the air does the calming.
    substeps = 15,         -- small steps a frame (1/60): more is stiffer and stops fast things
                           -- passing through (the "small steps" result: substeps beat iterations)
    iterations = 1,        -- constraint passes per substep
    damping = 0.999,       -- velocity kept a 1/60 (the air below does the real calming)
    gravity = 1,           -- times the world's
    drag = 0.8,            -- 1/s: the air against the cloth's motion along itself
    lift = 3,              -- 1/s: the air against its face (a sheet falls slowly flat, fast edge-on)
    wind = 0,              -- px/s at 100 px/m, + is to the right
    gust = 0.6,            -- 0..1: how much the wind comes and goes, and how uneven it is over the cloth
    flutter = 0.6,         -- how fast the gusts move over it (1: brisk, lower: lazy)
    shear = 0.5,           -- the diagonals' stiffness: 0 lets the cells shear (a net), 1 keeps them square
    stretch = 1,           -- the sides' stiffness: 1 doesn't stretch (cloth), lower is rubbery
    slack = 1,             -- rest lengths this much longer than the grid (it folds in depth anyway)
    bend = 0.03,           -- the skip-one constraints: how much it resists folding (silk ~0, felt ~0.3)
    tear = 0,              -- 0: never; else an edge stretched this many times its length tears (2.5 ≈ easy)
    collide = true, thickness = 5,
    bodyDepth = 45,        -- px: a moving body's half thickness in z (the ground is endless)
    push = 0.02,           -- how much the cloth holds back bodies moving through it (0: a ghost)
    perspective = 0.0005,  -- drawn size per px toward you: folds that come forward grow a little
    fabric = 'stripes', tint = { 1, 1, 1 }, outline = { 0.2, 0.13, 0.1 }, outlineWidth = 3,
    fabricScale = 1,       -- the pattern's size on the cloth
    shade = 0.6,           -- 0..1: how much the folds are lit (light from the top left, in front)
}

---------------------------------------------------------------- fabrics

local fabricCache = {}

local function canvasFabric(size, paint)
    local cv = love.graphics.newCanvas(size, size)
    love.graphics.push('all')
    love.graphics.setCanvas(cv)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.origin()
    paint(size)
    love.graphics.pop()
    cv:setWrap('repeat', 'repeat')
    cv:setFilter('linear', 'linear')
    return cv
end

-- name -> image, repeats (repeats: the pattern tiles over the cloth; else it's stretched once)
local FABRICS = {
    stripes = function()
        return canvasFabric(64, function(s)
            love.graphics.setColor(0.86, 0.36, 0.32)
            love.graphics.rectangle('fill', 0, 0, s * 0.5, s)
            love.graphics.setColor(0.95, 0.9, 0.8)
            love.graphics.rectangle('fill', s * 0.5, 0, s * 0.5, s)
        end), true
    end,
    gingham = function()
        return canvasFabric(64, function(s)
            love.graphics.setColor(0.97, 0.95, 0.9)
            love.graphics.rectangle('fill', 0, 0, s, s)
            love.graphics.setColor(0.35, 0.5, 0.75, 0.55)
            love.graphics.rectangle('fill', 0, 0, s * 0.5, s)
            love.graphics.rectangle('fill', 0, 0, s, s * 0.5)
        end), true
    end,
    dots = function()
        return canvasFabric(64, function(s)
            love.graphics.setColor(0.32, 0.45, 0.62)
            love.graphics.rectangle('fill', 0, 0, s, s)
            love.graphics.setColor(0.96, 0.92, 0.78)
            love.graphics.circle('fill', s * 0.25, s * 0.25, s * 0.11)
            love.graphics.circle('fill', s * 0.75, s * 0.75, s * 0.11)
        end), true
    end,
    velvet = function()
        return canvasFabric(16, function(s)
            love.graphics.setColor(0.55, 0.12, 0.18)
            love.graphics.rectangle('fill', 0, 0, s, s)
        end), true
    end,
    banner = function() -- three bands, a disc in the middle: stretched once over the cloth
        return canvasFabric(256, function(s)
            local bands = { { 0.9, 0.75, 0.3 }, { 0.36, 0.6, 0.45 }, { 0.9, 0.75, 0.3 } }
            for i, c in ipairs(bands) do
                love.graphics.setColor(c)
                love.graphics.rectangle('fill', 0, (i - 1) * s / 3, s, s / 3 + 1)
            end
            love.graphics.setColor(0.86, 0.36, 0.32)
            love.graphics.circle('fill', s * 0.38, s * 0.5, s * 0.15)
        end), false
    end,
}

lib.fabricNames = { 'stripes', 'gingham', 'dots', 'velvet', 'banner', 'pattern', 'type1', 'bee-stripes' }

-- a fabric by name: one of FABRICS, a picture in textures/pat (tiled), or a path to a picture
-- (stretched once over the cloth)
function lib.fabric(name)
    local hit = fabricCache[name]
    if hit then return hit.image, hit.repeats end
    local image, repeats
    if FABRICS[name] then
        image, repeats = FABRICS[name]()
    else
        local path = name:find('/') and name or ('textures/pat/' .. name .. '.png')
        local ok, img = pcall(love.graphics.newImage, path, { mipmaps = true })
        if not ok then return lib.fabric('velvet') end
        repeats = not name:find('/')
        if repeats then img:setWrap('repeat', 'repeat') end
        img:setFilter('linear', 'linear')
        image = img
    end
    fabricCache[name] = { image = image, repeats = repeats }
    return image, repeats
end

---------------------------------------------------------------- building

-- a 1-based array of n numbers, zeroed: an FFI array for the C path, else a table
local function array(c, ctype, n)
    if c.native then return ffi.new(ctype .. '[?]', n + 1) end
    local t = {}
    for i = 1, n do t[i] = 0 end
    return t
end

local function pinPoint(c, i)
    c.inv[i] = 0
    c.pinx[i], c.piny[i] = c.x[i], c.y[i]
    if c.pinBody and not c.pinBody:isDestroyed() then
        c.pinlx[i], c.pinly[i] = c.pinBody:getLocalPoint(c.x[i], c.y[i])
    end
end

function lib.new(opts)
    local c = {}
    for k, v in pairs(lib.defaults) do c[k] = v end
    for k, v in pairs(opts or {}) do c[k] = v end
    c.native = lib.useNative and native() ~= false
    local cols, rows, sp = c.cols, c.rows, c.spacing
    local n = cols * rows
    c.n = n
    c.x0, c.y0 = (opts and opts.x) or 0, (opts and opts.y) or 0 -- the top left corner
    local x0, y0 = c.x0, c.y0
    local function id(col, r) return r * cols + col + 1 end

    -- the constraints, gathered first (their count sizes the arrays)
    local ca, cb, ck, hEdge, vEdge = {}, {}, {}, {}, {}
    local function add(a, b, k)
        ca[#ca + 1], cb[#cb + 1], ck[#ck + 1] = a, b, k
        return #ca
    end
    for r = 0, rows - 1 do
        for col = 0, cols - 1 do
            local i = id(col, r)
            if col < cols - 1 then hEdge[i] = add(i, id(col + 1, r), c.stretch) end
            if r < rows - 1 then vEdge[i] = add(i, id(col, r + 1), c.stretch) end
            if col < cols - 1 and r < rows - 1 and c.shear > 0 then
                add(i, id(col + 1, r + 1), c.shear)
                add(id(col + 1, r), id(col, r + 1), c.shear)
            end
            if c.bend > 0 then
                if col < cols - 2 then add(i, id(col + 2, r), c.bend) end
                if r < rows - 2 then add(i, id(col, r + 2), c.bend) end
            end
        end
    end
    local nc = #ca
    c.nc = nc

    for _, key in ipairs({ 'x', 'y', 'z', 'px', 'py', 'pz', 'inv', 'pinx', 'piny', 'railY', 'sx', 'sy' }) do
        c[key] = array(c, 'float', n)
    end
    c.rail, c.quad = array(c, 'uint8_t', n), array(c, 'uint8_t', n)
    c.ca, c.cb = array(c, 'int', nc), array(c, 'int', nc)
    c.cr, c.ck = array(c, 'float', nc), array(c, 'float', nc)
    c.alive, c.structural = array(c, 'uint8_t', nc), array(c, 'uint8_t', nc)
    c.hEdge, c.vEdge = array(c, 'int', n), array(c, 'int', n) -- point -> its side to the right / below
    c.pinlx, c.pinly = {}, {}

    for r = 0, rows - 1 do
        for col = 0, cols - 1 do
            local i = id(col, r)
            c.x[i], c.y[i] = x0 + col * sp, y0 + r * sp
            c.z[i] = (love.math.random() - 0.5) * 0.6 -- a breath off flat, so it can fold either way
            c.px[i], c.py[i], c.pz[i] = c.x[i], c.y[i], c.z[i]
            c.inv[i] = 1
        end
    end
    for e = 1, nc do
        local a, b = ca[e], cb[e]
        c.ca[e], c.cb[e], c.ck[e] = a, b, ck[e]
        c.cr[e] = math.sqrt((c.x[a] - c.x[b]) ^ 2 + (c.y[a] - c.y[b]) ^ 2 + (c.z[a] - c.z[b]) ^ 2) * c.slack
        c.alive[e] = 1
    end
    for i, e in pairs(hEdge) do c.hEdge[i] = e; c.structural[e] = 1 end
    for i, e in pairs(vEdge) do c.vEdge[i] = e; c.structural[e] = 1 end

    -- pins
    if c.pin == 'top' then
        for col = 0, cols - 1 do pinPoint(c, id(col, 0)) end
    elseif c.pin == 'corners' then
        pinPoint(c, id(0, 0)); pinPoint(c, id(cols - 1, 0))
    elseif c.pin == 'left' then
        for r = 0, rows - 1 do pinPoint(c, id(0, r)) end
    elseif c.pin == 'ring' then
        for col = 0, cols - 1, c.ringEvery do pinPoint(c, id(col, 0)) end
        pinPoint(c, id(cols - 1, 0))
    elseif c.pin == 'rail' then
        -- rings on a rail: the top row keeps its height and slides sideways between the rail's ends
        c.railMin = c.railMin or x0
        c.railMax = c.railMax or (x0 + (cols - 1) * sp)
        for col = 0, cols - 1, c.ringEvery do c.rail[id(col, 0)] = 1; c.railY[id(col, 0)] = y0 end
        c.rail[id(cols - 1, 0)] = 1
        c.railY[id(cols - 1, 0)] = y0
    end
    c.railMin, c.railMax = c.railMin or 0, c.railMax or 0
    c.cx, c.cy = x0 + (cols - 1) * sp / 2, y0 + (rows - 1) * sp / 2 -- the perspective's centre

    if c.native then
        c.scratch = ffi.new('uint8_t[?]', 2 * n + 2)
        c.shapes = ffi.new('float[?]', MAX_SHAPES * SHAPE_STRIDE)
        c.impulses = ffi.new('float[?]', MAX_SHAPES * 2)
        local cs = ffi.new('ClothSim')
        cs.n, cs.cols, cs.rows, cs.nc = n, cols, rows, nc
        for _, key in ipairs({ 'x', 'y', 'z', 'px', 'py', 'pz', 'inv', 'pinx', 'piny', 'railY', 'sx', 'sy',
            'rail', 'ca', 'cb', 'cr', 'ck', 'alive', 'structural', 'quad', 'scratch' }) do
            cs[key] = c[key] -- the arrays stay referenced from c, so they outlive the struct's pointers
        end
        c.cs = cs
    else
        c.shapes, c.impulses = {}, {}
    end
    c.bodies = {}
    c.mapDirty = true
    c.time = love.math.random() * 100
    c.acc = 0
    return c
end

---------------------------------------------------------------- the shapes it touches

-- The Box2D shapes over the cloth, into c.shapes in the world (cloth.c's layout) with their bodies
-- in c.bodies; returns how many. Once a frame: the shapes move little in 1/60.
local function gatherShapes(c)
    local world = state.physicsWorld
    if not world then return 0 end
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    local X, Y = c.x, c.y
    for i = 1, c.n do
        local x, y = X[i], Y[i]
        if x < minx then minx = x end
        if x > maxx then maxx = x end
        if y < miny then miny = y end
        if y > maxy then maxy = y end
    end
    local pad = c.thickness
    local S, bodies, count = c.shapes, c.bodies, 0
    world:queryBoundingBox(minx - pad, miny - pad, maxx + pad, maxy + pad, function(f)
        if f:isSensor() then return true end
        local shape = f:getShape()
        local stype = shape:getType()
        if stype ~= 'circle' and stype ~= 'polygon' then return true end
        local body = f:getBody()
        local o = count * SHAPE_STRIDE
        S[o + 23] = body:getType() == 'dynamic' and c.bodyDepth or 0 -- a slab; the ground's endless
        local vx, vy = body:getLinearVelocity()
        local cx, cy = body:getWorldCenter()
        S[o + 1], S[o + 2], S[o + 3], S[o + 4], S[o + 5] = vx, vy, body:getAngularVelocity(), cx, cy
        if stype == 'circle' then
            S[o] = 0
            S[o + 6], S[o + 7] = body:getWorldPoint(shape:getPoint())
            S[o + 8] = shape:getRadius()
        else
            S[o] = 1
            local pts = { body:getWorldPoints(shape:getPoints()) }
            S[o + 6] = #pts / 2
            for k = 1, #pts do S[o + 6 + k] = pts[k] end
        end
        count = count + 1
        bodies[count] = body
        return count < MAX_SHAPES
    end)
    return count
end

-- The cloth holds back a body moving through it: drag, more the more cloth it's in (how far the
-- points had to be moved out of it). Only against its motion, never a push of its own: a push
-- (the cloth's weight on a Mipo) fought the Mipo's balance and the two kept each other jumping.
local function dragBodies(c, count)
    if c.push <= 0 then return end
    local J = c.impulses
    local per = 1 / math.max(1, math.floor(c.substeps + 0.5)) -- the sum over the substeps, as one
    for s = 1, count do
        local body = c.bodies[s]
        local jx, jy = J[(s - 1) * 2], J[(s - 1) * 2 + 1]
        if body:getType() == 'dynamic' and (jx ~= 0 or jy ~= 0) then
            local amount = math.sqrt(jx * jx + jy * jy) * per -- px of cloth moved out a frame
            local share = math.min(0.3, amount * c.push * 0.1) -- of its speed taken this frame
            local vx, vy = body:getLinearVelocity()
            local m = body:getMass()
            local bx, by = body:getWorldCenter()
            body:applyLinearImpulse(-vx * m * share, -vy * m * share, bx, by)
        end
    end
end

---------------------------------------------------------------- the Lua step (no native library)

-- the same as cloth.c, line for line where it can be

local function normalAt(c, i)
    local cols, X, Y, Z = c.cols, c.x, c.y, c.z
    local col, r = (i - 1) % cols, math.floor((i - 1) / cols)
    local l, rt = col > 0 and i - 1 or i, col < cols - 1 and i + 1 or i
    local u, d = r > 0 and i - cols or i, r < c.rows - 1 and i + cols or i
    local ax, ay, az = X[rt] - X[l], Y[rt] - Y[l], Z[rt] - Z[l]
    local bx, by, bz = X[d] - X[u], Y[d] - Y[u], Z[d] - Z[u]
    local x, y, z = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
    local len = math.sqrt(x * x + y * y + z * z)
    if len < 1e-6 then return 0, 0, 1 end
    return x / len, y / len, z / len
end

local function collideLua(c, H, count)
    local X, Y, Z, PX, PY, PZ, inv, S, J = c.x, c.y, c.z, c.px, c.py, c.pz, c.inv, c.shapes, c.impulses
    local th = c.thickness
    local keep = (1 - COLLIDE_FRICTION) ^ (H * 60)
    local acc = {}
    for s = 0, count - 1 do
        local o = s * SHAPE_STRIDE
        local poly = S[o] > 0.5
        local half = S[o + 23]
        local nv = poly and S[o + 6] or 0
        local minx, miny, maxx, maxy
        if poly then
            minx, maxx, miny, maxy = S[o + 7], S[o + 7], S[o + 8], S[o + 8]
            for k = 1, nv - 1 do
                local vx, vy = S[o + 7 + k * 2], S[o + 8 + k * 2]
                if vx < minx then minx = vx end
                if vx > maxx then maxx = vx end
                if vy < miny then miny = vy end
                if vy > maxy then maxy = vy end
            end
        else
            minx, maxx = S[o + 6] - S[o + 8], S[o + 6] + S[o + 8]
            miny, maxy = S[o + 7] - S[o + 8], S[o + 7] + S[o + 8]
        end
        minx, miny, maxx, maxy = minx - th, miny - th, maxx + th, maxy + th
        local jx, jy = 0, 0
        for i = 1, c.n do
            local x, y, z = X[i], Y[i], Z[i]
            local zdepth = math.huge
            if half > 0 then zdepth = half + th - math.abs(z) end
            if inv[i] > 0 and zdepth > 0 and x > minx and x < maxx and y > miny and y < maxy then
                local ox, oy, dxy
                if not poly then
                    local r = S[o + 8] + th
                    local dx, dy = x - S[o + 6], y - S[o + 7]
                    local d2 = dx * dx + dy * dy
                    if d2 < r * r and d2 > 1e-6 then
                        local d = math.sqrt(d2)
                        dxy = r - d
                        ox, oy = dx / d * dxy, dy / d * dxy
                    end
                else
                    local best, bnx, bny = math.huge, 0, 0
                    local inside = true
                    for k = 0, nv - 1 do
                        local k2 = (k + 1) % nv
                        local ax, ay = S[o + 7 + k * 2], S[o + 8 + k * 2]
                        local ex, ey = S[o + 7 + k2 * 2] - ax, S[o + 8 + k2 * 2] - ay
                        local el = math.sqrt(ex * ex + ey * ey)
                        if el > 0 then
                            local nx, ny = ey / el, -ex / el
                            local depth = th - ((x - ax) * nx + (y - ay) * ny)
                            if depth <= 0 then inside = false; break end
                            if depth < best then best, bnx, bny = depth, nx, ny end
                        end
                    end
                    if inside then dxy, ox, oy = best, bnx * best, bny * best end
                end
                if ox then
                    local oz = 0
                    if zdepth < dxy then
                        ox, oy, oz = 0, 0, (z >= 0 and 1 or -1) * zdepth -- out the front or back
                    else
                        jx, jy = jx - ox, jy - oy
                    end
                    local a = acc[i]
                    if not a then a = { 0, 0, 0, 0, 0, 0 }; acc[i] = a end
                    a[1], a[2], a[3] = a[1] + ox, a[2] + oy, a[3] + oz
                    a[4] = a[4] + (S[o + 1] - S[o + 3] * (y - S[o + 5])) * H
                    a[5] = a[5] + (S[o + 2] + S[o + 3] * (x - S[o + 4])) * H
                    a[6] = a[6] + 1
                end
            end
        end
        J[s * 2] = (J[s * 2] or 0) + jx
        J[s * 2 + 1] = (J[s * 2 + 1] or 0) + jy
    end
    for i, a in pairs(acc) do
        local k = a[6]
        local ox, oy, oz, bvx, bvy = a[1] / k, a[2] / k, a[3] / k, a[4] / k, a[5] / k
        local depth = math.sqrt(ox * ox + oy * oy + oz * oz)
        if depth > 1e-6 then
            local nx, ny, nz = ox / depth, oy / depth, oz / depth
            if depth > COLLIDE_MAX_PUSH then
                ox, oy, oz = nx * COLLIDE_MAX_PUSH, ny * COLLIDE_MAX_PUSH, nz * COLLIDE_MAX_PUSH
            end
            local x, y, z = X[i], Y[i], Z[i]
            local rx, ry, rz = (x - PX[i]) - bvx, (y - PY[i]) - bvy, z - PZ[i]
            local vn = rx * nx + ry * ny + rz * nz
            if vn < 0 then rx, ry, rz = rx - vn * nx, ry - vn * ny, rz - vn * nz end
            rx, ry, rz = rx * keep, ry * keep, rz * keep
            local qx, qy, qz = x + ox, y + oy, z + oz
            X[i], Y[i], Z[i] = qx, qy, qz
            PX[i], PY[i], PZ[i] = qx - (bvx + rx), qy - (bvy + ry), qz - rz
        end
    end
end

local function stepLua(c, H, count)
    local X, Y, Z, PX, PY, PZ, inv = c.x, c.y, c.z, c.px, c.py, c.pz, c.inv
    c.time = c.time + H
    local ft = c.time * c.flutter -- the wind's own clock
    local g = 9.8 * love.physics.getMeter() * c.gravity
    local wind = units.speed(c.wind)
    local gust = c.gust
    local swell = 1 - gust * 0.5 + gust * 0.5 * math.sin(ft * 0.9) * math.sin(ft * 0.37 + 1.3)
    local damp = c.damping ^ (H / FRAME) -- the damping is per 1/60
    local hh = H * H
    local drag, lift = c.drag, c.lift
    local noise = love.math.noise
    for i = 1, c.n do
        if inv[i] > 0 then
            local x, y, z = X[i], Y[i], Z[i]
            local vx, vy, vz = (x - PX[i]) * damp, (y - PY[i]) * damp, (z - PZ[i]) * damp
            local wx, wy, wz = 0, 0, 0
            if wind ~= 0 then
                local w = noise(x * 0.006 - ft * 1.7, y * 0.006, ft * 0.25)
                wx = wind * swell * (1 - gust + gust * 2 * w)
                wy = math.abs(wind) * gust * 0.3 * (noise(x * 0.01, y * 0.01 - ft * 2.1) - 0.5)
                wz = math.abs(wind) * (0.15 + gust * 0.4) * (noise(x * 0.008 - ft * 1.3, y * 0.008, 3.1) - 0.5)
            end
            local rx, ry, rz = wx - vx / H, wy - vy / H, wz - vz / H
            local nx, ny, nz = normalAt(c, i)
            local face = rx * nx + ry * ny + rz * nz
            local ax = drag * rx + lift * face * nx
            local ay = g + drag * ry + lift * face * ny
            local az = drag * rz + lift * face * nz
            PX[i], PY[i], PZ[i] = x, y, z
            X[i], Y[i], Z[i] = x + vx + ax * hh, y + vy + ay * hh, z + vz + az * hh
        end
    end
    for i = 1, c.n do
        if inv[i] == 0 and i ~= c.grabbed then X[i], Y[i], Z[i] = c.pinx[i], c.piny[i], 0 end
    end
    local ca, cb, cr, ck, alive, structural = c.ca, c.cb, c.cr, c.ck, c.alive, c.structural
    local tear = c.tear
    for _ = 1, c.iterations do
        for e = 1, c.nc do
            if alive[e] == 1 then
                local a, b = ca[e], cb[e]
                local wa, wb = inv[a], inv[b]
                local w = wa + wb
                if w > 0 then
                    local dx, dy, dz = X[b] - X[a], Y[b] - Y[a], Z[b] - Z[a]
                    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                    if d > 1e-6 then
                        local rest = cr[e]
                        if tear > 0 and d > rest * tear and structural[e] == 1 then
                            alive[e] = 0
                            c.mapDirty = true
                        else
                            local f = (d - rest) / d * ck[e] / w
                            X[a], Y[a], Z[a] = X[a] + dx * f * wa, Y[a] + dy * f * wa, Z[a] + dz * f * wa
                            X[b], Y[b], Z[b] = X[b] - dx * f * wb, Y[b] - dy * f * wb, Z[b] - dz * f * wb
                        end
                    end
                end
            end
        end
        for i = 1, c.n do
            if c.rail[i] == 1 then
                Y[i], Z[i] = c.railY[i], 0
                if X[i] < c.railMin then X[i] = c.railMin elseif X[i] > c.railMax then X[i] = c.railMax end
            end
        end
        if c.grabbed then X[c.grabbed], Y[c.grabbed], Z[c.grabbed] = c.grabX, c.grabY, 0 end
    end
    if count > 0 then collideLua(c, H, count) end
end

---------------------------------------------------------------- update

-- pins that ride on a body go where it is now
local function movePins(c)
    local pb = c.pinBody
    if not pb then return end
    if pb:isDestroyed() then c.pinBody = nil; return end
    for i, lx in pairs(c.pinlx) do
        c.pinx[i], c.piny[i] = pb:getWorldPoint(lx, c.pinly[i])
    end
end

local function frameNative(c, count)
    local cs = c.cs
    cs.railMin, cs.railMax = c.railMin, c.railMax
    cs.grabbed = c.grabbed or 0
    cs.grabX, cs.grabY = c.grabX or 0, c.grabY or 0
    cs.gravity = 9.8 * love.physics.getMeter() * c.gravity
    cs.wind, cs.gust, cs.damping = units.speed(c.wind), c.gust, c.damping
    cs.thickness, cs.tear, cs.iterations = c.thickness, c.tear, c.iterations
    cs.flutter, cs.drag, cs.lift = c.flutter, c.drag, c.lift
    cs.perspective, cs.cx, cs.cy = c.perspective, c.cx, c.cy
    cs.time = c.time % 10000
    local tears = native().cloth_frame(cs, FRAME, math.floor(c.substeps + 0.5), c.shapes, count, c.impulses)
    c.time = cs.time
    if tears > 0 then c.mapDirty = true end
end

function lib.update(c, dt)
    if dt <= 0 then return end
    c.acc = math.min(c.acc + dt, FRAME * MAX_FRAMES)
    while c.acc >= FRAME do
        movePins(c)
        local count = c.collide and gatherShapes(c) or 0
        if c.native then
            frameNative(c, count)
        else
            for s = 0, count * 2 - 1 do c.impulses[s] = 0 end
            local n = math.max(1, math.floor(c.substeps + 0.5))
            for _ = 1, n do stepLua(c, FRAME / n, count) end
        end
        dragBodies(c, count)
        c.acc = c.acc - FRAME
    end
end

---------------------------------------------------------------- the hand

-- the point nearest (x, y) within `reach`, or nil
function lib.nearest(c, x, y, reach)
    local best, bi = reach * reach, nil
    for i = 1, c.n do
        local d = (c.x[i] - x) ^ 2 + (c.y[i] - y) ^ 2
        if d < best then best, bi = d, i end
    end
    return bi
end

function lib.grab(c, i, x, y)
    c.grabbed, c.grabX, c.grabY = i, x, y
end

function lib.drag(c, x, y)
    if c.grabbed then c.grabX, c.grabY = x, y end
end

function lib.release(c)
    c.grabbed = nil
end

---------------------------------------------------------------- drawing

local FORMAT = { { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 }, { 'VertexColor', 'byte', 4 } }
local BYTES_PER_VERTEX = 20

local function rebuildMap(c)
    local cols, rows = c.cols, c.rows
    local count
    if c.native then
        c.mapData = c.mapData or love.data.newByteData((cols - 1) * (rows - 1) * 6 * 4)
        count = native().cloth_map(c.cs, c.hEdge, c.vEdge, ffi.cast('uint32_t *', c.mapData:getFFIPointer()))
        if count > 0 then c.mesh:setVertexMap(c.mapData, 'uint32') end
        c.mesh:setDrawRange(1, math.max(1, count))
    else
        local map, alive, quad = {}, c.alive, c.quad
        local hE, vE = c.hEdge, c.vEdge
        for r = 0, rows - 2 do
            for col = 0, cols - 2 do
                local i = r * cols + col + 1
                -- a cell stays while its four sides do
                local ok = alive[hE[i]] == 1 and alive[vE[i]] == 1
                    and alive[hE[i + cols]] == 1 and alive[vE[i + 1]] == 1
                quad[i] = ok and 1 or 0
                if ok then
                    local a, b, d, e = i, i + 1, i + cols, i + cols + 1
                    map[#map + 1] = a; map[#map + 1] = b; map[#map + 1] = e
                    map[#map + 1] = a; map[#map + 1] = e; map[#map + 1] = d
                end
            end
        end
        count = #map
        if count > 0 then c.mesh:setVertexMap(map) end
    end
    c.mapCount = count
    c.mapDirty = false
end

local function ensureMesh(c)
    local image, repeats = lib.fabric(c.fabric)
    if c.mesh and c.meshFabric == c.fabric and c.meshScale == c.fabricScale then return end
    local cols, sp = c.cols, c.spacing
    local iw, ih = image:getDimensions()
    c.uv = c.native and ffi.new('float[?]', (c.n + 1) * 2) or {}
    for i = 1, c.n do
        local col, r = (i - 1) % cols, math.floor((i - 1) / cols)
        local u, v
        if repeats then
            local s = c.fabricScale
            u, v = col * sp / (iw * s), r * sp / (ih * s)
        else
            u, v = col / (cols - 1), r / (c.rows - 1)
        end
        c.uv[i * 2], c.uv[i * 2 + 1] = u, v
    end
    c.mesh = love.graphics.newMesh(FORMAT, c.n, 'triangles', 'stream')
    c.mesh:setTexture(image)
    if c.native then
        c.vertexData = love.data.newByteData(c.n * BYTES_PER_VERTEX)
        c.outlineBuf = ffi.new('float[?]', MAX_OUTLINE)
    else
        c.verts = {}
        for i = 1, c.n do c.verts[i] = { 0, 0, c.uv[i * 2], c.uv[i * 2 + 1], 1, 1, 1, 1 } end
    end
    c.meshFabric, c.meshScale = c.fabric, c.fabricScale
    c.mapDirty = true
end

-- where each point is drawn and its light (as cloth_vertices in cloth.c)
local function writeVerticesLua(c)
    local X, Y, Z, SX, SY = c.x, c.y, c.z, c.sx, c.sy
    local tr, tg, tb = c.tint[1], c.tint[2], c.tint[3]
    local shade = c.shade
    local lx, ly, lz = -0.35, -0.55, 0.76
    for i = 1, c.n do
        local sc = math.max(0.2, 1 + Z[i] * c.perspective)
        SX[i], SY[i] = c.cx + (X[i] - c.cx) * sc, c.cy + (Y[i] - c.cy) * sc
    end
    for i = 1, c.n do
        local v = c.verts[i]
        v[1], v[2] = SX[i], SY[i]
        local l = 1
        if shade > 0 then
            local nx, ny, nz = normalAt(c, i)
            if nz < 0 then nx, ny, nz = -nx, -ny, -nz end
            local lam = math.max(0, nx * lx + ny * ly + nz * lz)
            l = math.min(1.2, 1 - shade + shade * (0.45 + 0.55 * lam / lz))
        end
        v[5], v[6], v[7] = math.min(1, tr * l), math.min(1, tg * l), math.min(1, tb * l)
    end
    c.mesh:setVertices(c.verts)
end

local line = {}

-- an edge of the cloth (outside, or along a tear) has a whole cell on one side only
local function drawOutlineNative(c)
    local buf = c.outlineBuf
    local total = native().cloth_outline(c.cs, buf, MAX_OUTLINE)
    local k = 0
    while k < total do
        local count = buf[k]
        k = k + 1
        if count >= 2 then
            for j = 1, count * 2 do line[j] = buf[k + j - 1] end
            for j = count * 2 + 1, #line do line[j] = nil end
            love.graphics.line(line)
        end
        k = k + count * 2
    end
end

local function drawOutlineLua(c)
    local cols, rows = c.cols, c.rows
    local q = c.quad
    local X, Y = c.sx, c.sy
    for r = 0, rows - 1 do
        for col = 0, cols - 1 do
            local i = r * cols + col + 1
            if col < cols - 1 then
                local above = r > 0 and q[i - cols] == 1
                local below = r < rows - 1 and q[i] == 1
                if above ~= below then love.graphics.line(X[i], Y[i], X[i + 1], Y[i + 1]) end
            end
            if r < rows - 1 then
                local left = col > 0 and q[i - 1] == 1
                local right = col < cols - 1 and q[i] == 1
                if left ~= right then love.graphics.line(X[i], Y[i], X[i + cols], Y[i + cols]) end
            end
        end
    end
end

function lib.draw(c, opts)
    ensureMesh(c)
    if c.mapDirty then rebuildMap(c) end
    if c.mapCount == 0 then return end
    if c.native then
        local tint = c.tint
        local out = c.vertexData:getFFIPointer()
        native().cloth_vertices(c.cs, out, c.uv, tint[1], tint[2], tint[3], c.shade, c.spacing)
        c.mesh:setVertices(c.vertexData)
    else
        writeVerticesLua(c)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(c.mesh)
    if c.outlineWidth > 0 then
        love.graphics.setColor(c.outline)
        love.graphics.setLineWidth(c.outlineWidth)
        love.graphics.setLineJoin('bevel')
        if c.native then drawOutlineNative(c) else drawOutlineLua(c) end
    end
    if opts and opts.debug then
        local X, Y = c.x, c.y
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.setLineWidth(1)
        for e = 1, c.nc do
            if c.alive[e] == 1 and c.structural[e] == 1 then
                local a, b = c.ca[e], c.cb[e]
                love.graphics.line(X[a], Y[a], X[b], Y[b])
            end
        end
        love.graphics.setColor(0.9, 0.2, 0.2)
        for i = 1, c.n do
            if c.inv[i] == 0 or c.rail[i] == 1 then love.graphics.circle('fill', X[i], Y[i], 4) end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return lib
