-- fluid: water as points that push each other apart (Position-Based Fluids), after dreamengine's
-- waterjar cart (docs/WATERJAR.md). A tank you tip throws a wave that climbs the far wall and
-- folds over; Box2D bodies in it are pushed out and pushed back (they float, get carried).
--
--   local f = fluid.new({ h = 36, tank = body, tankHalfWidth = 700, tankDepth = 600 })
--   fluid.fill(f, x0, y0, x1, y1)   -- a block of water, settled before it's shown
--   fluid.update(f, dt)             -- steps of 1/60
--   fluid.draw(f)                   -- the points merged into one body of water
--
-- The step runs in C when the native library has it (native/desound/fluid.c); else (the web, pure
-- specs) the same in Lua here, with fewer points. Arrays are 0-based (FFI arrays or tables).
--
-- The cart's numbers were tuned at h = 7; here everything that's a length is that times h / 7.

local state = require('src.state')
local nativeLib = require('src.native-lib')
local ffi = nativeLib.ffi

local lib = {}

local FRAME = 1 / 60
local MAX_FRAMES = 2
local SHAPE_STRIDE = 24
local MAX_SHAPES = 160
local MAX_NBR = 48
local NHEAD = 8192
local FLAG_DYNAMIC, FLAG_TANK = 1, 2

local CDEF = [[
typedef struct {
    int n, maxn, maxnbr, nhead;
    float *x, *y, *px, *py;
    float *lam, *dpx, *dpy, *vlx, *vly;
    int *nbr, *nbrN, *cnext, *head;
    uint8_t *inTank;
    float h, pr, rho0, eps;
    float gx, gy, damp, visc, vmax, maxdp, cmin, cohLo, cohHi;
    int iters;
    int hasTank;
    float tx, ty, tcos, tsin, thw, tdepth, trest, tfric;
    float mass;
    int hasFloor;
    float floorY;
} FluidSim;
int fluid_step(FluidSim *f, const float *shapes, int nshapes, float *impulses);
float fluid_rest_density(FluidSim *f, int mode);
int fluid_cull(FluidSim *f, float minx, float miny, float maxx, float maxy);
]]

local C
local function native()
    if C == nil then C = nativeLib.load(CDEF, 'fluid_step') end
    return C
end

lib.useNative = true
function lib.nativeAvailable() return native() ~= false end

lib.defaults = {
    h = 36,             -- px: how far a point feels its neighbours; the points sit ~0.62 h apart
    maxPoints = 1600,   -- C; the Lua step gets maxPointsLua
    maxPointsLua = 350,
    gravity = 1,        -- times the world's
    damping = 0.966,    -- speed kept a frame (the cart's 'damp' slider at 0.8)
    viscosity = 0.10,   -- XSPH: 0 sprays, 0.6 is honey
    cohesion = 0.85,    -- how sticky fast water is (a crest folds instead of spraying)
    iterations = 6,     -- density passes a frame
    push = 1,           -- how hard the water pushes bodies (0: they don't feel it)
    density = 1,        -- the water's weight, as a Box2D density (kg/m^2)
    -- drawing
    color = { 0.38, 0.62, 0.86 }, deep = { 0.22, 0.42, 0.72 }, foam = { 0.93, 0.97, 1 },
    ink = { 0.12, 0.18, 0.32 }, opacity = 0.82,
    threshold = 1.3,    -- the surface: summed blobs above this are water (the cart's FTHRESH)
    rim = 0.45,         -- how much of the field above it is the ink line
    blob = 1.3,         -- a point's blob radius, times h
}

---------------------------------------------------------------- building

local function array(f, ctype, n)
    if f.native then return ffi.new(ctype .. '[?]', n) end
    local t = {}
    for i = 0, n - 1 do t[i] = 0 end
    return t
end

function lib.new(opts)
    local f = {}
    for k, v in pairs(lib.defaults) do f[k] = v end
    for k, v in pairs(opts or {}) do f[k] = v end
    f.native = lib.useNative and native() ~= false
    local maxn = f.native and f.maxPoints or f.maxPointsLua
    f.maxn = maxn
    f.n = 0
    for _, key in ipairs({ 'x', 'y', 'px', 'py', 'lam', 'dpx', 'dpy', 'vlx', 'vly' }) do
        f[key] = array(f, 'float', maxn)
    end
    f.nbr = array(f, 'int', maxn * MAX_NBR)
    f.nbrN, f.cnext = array(f, 'int', maxn), array(f, 'int', maxn)
    f.head = array(f, 'int', NHEAD)
    f.inTank = array(f, 'uint8_t', maxn)
    f.shapes = array(f, 'float', MAX_SHAPES * SHAPE_STRIDE)
    f.impulses = array(f, 'float', MAX_SHAPES * 3)
    f.bodies = {}
    f.data = {}
    for _, name in ipairs(f.dataNames or {}) do f.data[name] = {} end
    f.rho0 = 1
    f.acc = 0
    if f.native then
        local fs = ffi.new('FluidSim')
        fs.maxn, fs.maxnbr, fs.nhead = maxn, MAX_NBR, NHEAD
        for _, key in ipairs({ 'x', 'y', 'px', 'py', 'lam', 'dpx', 'dpy', 'vlx', 'vly', 'nbr', 'nbrN', 'cnext',
            'head', 'inTank' }) do
            fs[key] = f[key]
        end
        f.fs = fs
    end
    return f
end

---------------------------------------------------------------- the step in Lua (no native library)

-- the same as fluid.c, line for line where it can be
local KP, KS, H2

local function kernels(h)
    local h5 = h ^ 5
    KP = 4 / (math.pi * h5 * h * h * h)
    KS = 30 / (math.pi * h5)
    H2 = h * h
end

local function poly6(r2)
    if r2 >= H2 then return 0 end
    local d = H2 - r2
    return KP * d * d * d
end

local function spikyG(r, h)
    if r >= h or r < 0.0001 then return 0 end
    local d = h - r
    return -KS * d * d / r
end

local function bucket(gx, gy)
    return (gx * 7919 + gy * 104729) % NHEAD
end

local function neighboursLua(p)
    local X, Y, head, cnext, nbr, nbrN = p.x, p.y, p.head, p.cnext, p.nbr, p.nbrN
    local h, n = p.h, p.n
    local floor = math.floor
    for c = 0, NHEAD - 1 do head[c] = -1 end
    for i = 0, n - 1 do
        local b = bucket(floor(X[i] / h), floor(Y[i] / h))
        cnext[i] = head[b]
        head[b] = i
    end
    for i = 0, n - 1 do
        local gx, gy = floor(X[i] / h), floor(Y[i] / h)
        local xi, yi = X[i], Y[i]
        local seen, cnt = {}, 0
        for oy = -1, 1 do
            for ox = -1, 1 do
                local b = bucket(gx + ox, gy + oy)
                if not seen[b] then
                    seen[b] = true
                    local j = head[b]
                    while j >= 0 and cnt < MAX_NBR do
                        if j ~= i then
                            local dx, dy = xi - X[j], yi - Y[j]
                            if dx * dx + dy * dy < H2 then
                                nbr[i * MAX_NBR + cnt] = j
                                cnt = cnt + 1
                            end
                        end
                        j = cnext[j]
                    end
                end
            end
        end
        nbrN[i] = cnt
    end
end

local function densityAt(p, i)
    local X, Y, nbr = p.x, p.y, p.nbr
    local rho = poly6(0)
    local xi, yi = X[i], Y[i]
    for k = 0, p.nbrN[i] - 1 do
        local j = nbr[i * MAX_NBR + k]
        local dx, dy = xi - X[j], yi - Y[j]
        rho = rho + poly6(dx * dx + dy * dy)
    end
    return rho
end

local function clampSpeed(p, i)
    local vx, vy = p.x[i] - p.px[i], p.y[i] - p.py[i]
    local sp = math.sqrt(vx * vx + vy * vy)
    if sp > p.vmax then
        local s = p.vmax / sp
        p.px[i] = p.x[i] - vx * s
        p.py[i] = p.y[i] - vy * s
    end
end

local function tankLocal(p, x, y)
    local dx, dy = x - p.tx, y - p.ty
    return dx * p.tcos + dy * p.tsin, -dx * p.tsin + dy * p.tcos
end

local function tankWorld(p, lx, ly)
    return p.tx + lx * p.tcos - ly * p.tsin, p.ty + lx * p.tsin + ly * p.tcos
end

local function keepInTank(p, i)
    if p.inTank[i] == 0 then return end
    local x, y = tankLocal(p, p.x[i], p.y[i])
    local px, py = tankLocal(p, p.px[i], p.py[i])
    local r, hit = p.pr, false
    local v
    local x0, x1, y1 = -p.thw + r, p.thw - r, -r
    if x < x0 then v = x - px; x = x0; px = x + v * p.trest; hit = true end
    if x > x1 then v = x - px; x = x1; px = x + v * p.trest; hit = true end
    if y > y1 then
        v = y - py; y = y1; py = y + v * p.trest
        local vx = x - px
        px = x - vx * p.tfric
        hit = true
    end
    if not hit then return end
    p.x[i], p.y[i] = tankWorld(p, x, y)
    p.px[i], p.py[i] = tankWorld(p, px, py)
end

local function keepAboveFloor(p, i)
    if p.hasFloor == 0 then return end
    local y1 = p.floorY - p.pr
    if p.y[i] > y1 then
        local v = p.y[i] - p.py[i]
        p.y[i] = y1
        p.py[i] = y1 + v * p.trest
        local vx = p.x[i] - p.px[i]
        p.px[i] = p.x[i] - vx * p.tfric
    end
end

local function collideShapes(p, i, S, ns, J)
    local r = p.pr
    for s = 0, ns - 1 do
        local o = s * SHAPE_STRIDE
        local flags = S[o + 6]
        if not (flags >= FLAG_TANK and p.inTank[i] == 1) then
            local x, y = p.x[i], p.y[i]
            local ox, oy
            if S[o] < 0.5 then
                local dx, dy, rr = x - S[o + 7], y - S[o + 8], S[o + 9] + r
                local d2 = dx * dx + dy * dy
                if d2 < rr * rr and d2 > 1e-6 then
                    local d = math.sqrt(d2)
                    local depth = rr - d
                    ox, oy = dx / d * depth, dy / d * depth
                end
            else
                local nv = S[o + 7]
                local best, bnx, bny, inside = math.huge, 0, 0, true
                for k = 0, nv - 1 do
                    local k2 = (k + 1) % nv
                    local ax, ay = S[o + 8 + k * 2], S[o + 9 + k * 2]
                    local ex, ey = S[o + 8 + k2 * 2] - ax, S[o + 9 + k2 * 2] - ay
                    local el = math.sqrt(ex * ex + ey * ey)
                    if el > 0 then
                        local nx, ny = ey / el, -ex / el
                        local depth = r - ((x - ax) * nx + (y - ay) * ny)
                        if depth <= 0 then inside = false; break end
                        if depth < best then best, bnx, bny = depth, nx, ny end
                    end
                end
                if inside and best < math.huge then ox, oy = bnx * best, bny * best end
            end
            if ox then
                local len = math.sqrt(ox * ox + oy * oy)
                if len > 1e-6 then
                    local nx, ny = ox / len, oy / len
                    local bvx, bvy = S[o + 1] - S[o + 3] * (y - S[o + 5]), S[o + 2] + S[o + 3] * (x - S[o + 4])
                    local vx, vy = x - p.px[i], y - p.py[i]
                    local rx, ry = vx - bvx, vy - bvy
                    local vn = rx * nx + ry * ny
                    if vn < 0 then rx, ry = rx - vn * nx, ry - vn * ny end
                    rx, ry = rx * 0.92, ry * 0.92
                    local qx, qy = x + ox, y + oy
                    p.x[i], p.y[i] = qx, qy
                    p.px[i], p.py[i] = qx - (bvx + rx), qy - (bvy + ry)
                    if flags % 2 == FLAG_DYNAMIC then
                        local jx, jy = -((bvx + rx) - vx) * p.mass, -((bvy + ry) - vy) * p.mass
                        J[s * 3] = J[s * 3] + jx
                        J[s * 3 + 1] = J[s * 3 + 1] + jy
                        J[s * 3 + 2] = J[s * 3 + 2] + (qx - S[o + 4]) * jy - (qy - S[o + 5]) * jx
                    end
                end
            end
        end
    end
end

local function stepLua(p, S, ns, J)
    local n = p.n
    if n == 0 then return end
    kernels(p.h)
    for s = 0, ns * 3 - 1 do J[s] = 0 end
    local X, Y, PX, PY = p.x, p.y, p.px, p.py
    for i = 0, n - 1 do
        p.inTank[i] = 0
        if p.hasTank == 1 then
            local lx, ly = tankLocal(p, PX[i], PY[i])
            if math.abs(lx) < p.thw and ly > -p.tdepth then p.inTank[i] = 1 end
        end
    end
    for i = 0, n - 1 do
        local vx, vy = (X[i] - PX[i]) * p.damp, (Y[i] - PY[i]) * p.damp
        PX[i], PY[i] = X[i], Y[i]
        X[i], Y[i] = X[i] + vx + p.gx, Y[i] + vy + p.gy
        clampSpeed(p, i)
    end
    neighboursLua(p)
    local rho0, h, nbr, nbrN, lam, dpx, dpy = p.rho0, p.h, p.nbr, p.nbrN, p.lam, p.dpx, p.dpy
    for _ = 1, p.iters do
        for i = 0, n - 1 do
            local Cv = densityAt(p, i) / rho0 - 1
            local vx, vy = X[i] - PX[i], Y[i] - PY[i]
            local t = (math.sqrt(vx * vx + vy * vy) - p.cohLo) / (p.cohHi - p.cohLo)
            t = math.max(0, math.min(1, t))
            local coh = p.cmin * t
            if Cv < coh then Cv = coh end
            local gxi, gyi, sumk = 0, 0, 0
            local xi, yi = X[i], Y[i]
            for k = 0, nbrN[i] - 1 do
                local j = nbr[i * MAX_NBR + k]
                local dx, dy = xi - X[j], yi - Y[j]
                local gc = spikyG(math.sqrt(dx * dx + dy * dy), h)
                local gjx, gjy = gc * dx / rho0, gc * dy / rho0
                gxi, gyi = gxi + gjx, gyi + gjy
                sumk = sumk + gjx * gjx + gjy * gjy
            end
            lam[i] = -Cv / (gxi * gxi + gyi * gyi + sumk + p.eps)
        end
        for i = 0, n - 1 do
            local cx, cy = 0, 0
            local xi, yi, li = X[i], Y[i], lam[i]
            for k = 0, nbrN[i] - 1 do
                local j = nbr[i * MAX_NBR + k]
                local dx, dy = xi - X[j], yi - Y[j]
                local coef = (li + lam[j]) / rho0 * spikyG(math.sqrt(dx * dx + dy * dy), h)
                cx, cy = cx + coef * dx, cy + coef * dy
            end
            local m = math.sqrt(cx * cx + cy * cy)
            if m > p.maxdp then
                local s = p.maxdp / m
                cx, cy = cx * s, cy * s
            end
            dpx[i], dpy[i] = cx, cy
        end
        for i = 0, n - 1 do
            X[i], Y[i] = X[i] + dpx[i], Y[i] + dpy[i]
            collideShapes(p, i, S, ns, J)
            keepInTank(p, i)
            keepAboveFloor(p, i)
        end
    end
    local vlx, vly = p.vlx, p.vly
    for i = 0, n - 1 do vlx[i], vly[i] = X[i] - PX[i], Y[i] - PY[i] end
    for i = 0, n - 1 do
        local ax, ay = 0, 0
        local xi, yi = X[i], Y[i]
        for k = 0, nbrN[i] - 1 do
            local j = nbr[i * MAX_NBR + k]
            local dx, dy = xi - X[j], yi - Y[j]
            local w = poly6(dx * dx + dy * dy) / rho0
            ax, ay = ax + (vlx[j] - vlx[i]) * w, ay + (vly[j] - vly[i]) * w
        end
        PX[i], PY[i] = PX[i] - p.visc * ax, PY[i] - p.visc * ay
    end
    for i = 0, n - 1 do clampSpeed(p, i) end
end

local function restDensityLua(p, mode)
    if p.n == 0 then return 1 end
    kernels(p.h)
    neighboursLua(p)
    local d = {}
    for i = 0, p.n - 1 do d[#d + 1] = densityAt(p, i) end
    table.sort(d)
    if mode == 0 then return d[#d] end
    return d[math.floor(p.n / 2) + 1]
end

---------------------------------------------------------------- settings into the step

-- the parameters the step reads (into the C struct, or a table for the Lua step)
local function params(f)
    local p = f.native and f.fs or f.lp
    if not p then
        p = { x = f.x, y = f.y, px = f.px, py = f.py, lam = f.lam, dpx = f.dpx, dpy = f.dpy, vlx = f.vlx,
            vly = f.vly, nbr = f.nbr, nbrN = f.nbrN, cnext = f.cnext, head = f.head, inTank = f.inTank }
        f.lp = p
    end
    local s = f.h / 7
    local meter = love.physics.getMeter()
    p.n = f.n
    p.h, p.pr = f.h, 2.5 * s
    p.rho0 = f.rho0
    p.eps = 0.0008 / (s * s)
    p.gx, p.gy = 0, 9.8 * meter * f.gravity * FRAME * FRAME
    p.damp, p.visc = f.damping, f.viscosity
    p.vmax, p.maxdp = 4.5 * s, 1.2 * s
    p.cmin, p.cohLo, p.cohHi = -f.cohesion, 2 * s, 4 * s
    p.iters = math.floor(f.iterations + 0.5)
    local spacing = 0.62 * f.h
    p.mass = f.density * spacing * spacing / (meter * meter)
    local tank = f.tank
    if tank and not tank:isDestroyed() then
        p.hasTank = 1
        p.tx, p.ty = tank:getPosition()
        local a = tank:getAngle()
        p.tcos, p.tsin = math.cos(a), math.sin(a)
        p.thw, p.tdepth = f.tankHalfWidth, f.tankDepth
    else
        p.hasTank = 0
    end
    p.trest, p.tfric = 0.2, 0.92
    p.hasFloor = f.floorY and 1 or 0
    p.floorY = f.floorY or 0
    return p
end

---------------------------------------------------------------- the shapes it touches

local function bounds(f)
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    local X, Y = f.x, f.y
    for i = 0, f.n - 1 do
        local x, y = X[i], Y[i]
        if x < minx then minx = x end
        if x > maxx then maxx = x end
        if y < miny then miny = y end
        if y > maxy then maxy = y end
    end
    return minx, miny, maxx, maxy
end

local function gatherShapes(f)
    local world = state.physicsWorld
    if not world or f.n == 0 or f.noShapes then return 0 end
    local minx, miny, maxx, maxy = bounds(f)
    local pad = f.h
    local S, bodies, count = f.shapes, f.bodies, 0
    world:queryBoundingBox(minx - pad, miny - pad, maxx + pad, maxy + pad, function(fixture)
        if fixture:isSensor() then return true end
        local shape = fixture:getShape()
        local stype = shape:getType()
        if stype ~= 'circle' and stype ~= 'polygon' then return true end
        local body = fixture:getBody()
        local o = count * SHAPE_STRIDE
        local vx, vy = body:getLinearVelocity()
        local cx, cy = body:getWorldCenter()
        S[o + 1], S[o + 2], S[o + 3] = vx * FRAME, vy * FRAME, body:getAngularVelocity() * FRAME
        S[o + 4], S[o + 5] = cx, cy
        S[o + 6] = (body:getType() == 'dynamic' and FLAG_DYNAMIC or 0) + (body == f.tank and FLAG_TANK or 0)
        if stype == 'circle' then
            S[o] = 0
            S[o + 7], S[o + 8] = body:getWorldPoint(shape:getPoint())
            S[o + 9] = shape:getRadius()
        else
            S[o] = 1
            local pts = { body:getWorldPoints(shape:getPoints()) }
            S[o + 7] = #pts / 2
            for k = 1, #pts do S[o + 7 + k] = pts[k] end
        end
        count = count + 1
        bodies[count] = body
        return count < MAX_SHAPES
    end)
    return count
end

-- what the water did to the bodies, as impulses
local function pushBodies(f, count)
    if f.push <= 0 then return end
    local J, S = f.impulses, f.shapes
    local k = f.push / FRAME
    for s = 1, count do
        local body = f.bodies[s]
        local o = (s - 1) * 3
        local jx, jy, t = J[o], J[o + 1], J[o + 2]
        if (jx ~= 0 or jy ~= 0) and body:getType() == 'dynamic' then
            local so = (s - 1) * SHAPE_STRIDE
            body:applyLinearImpulse(jx * k, jy * k, S[so + 4], S[so + 5])
            body:applyAngularImpulse(t * k)
        end
    end
end

---------------------------------------------------------------- using it

-- a point at (x, y) moving (vx, vy) px/s; returns its index, or nil when full. Per-point data of
-- the caller's goes in f.data[name][i] (opts.data = { 'from', 'age' }): lib.remove keeps it in step.
function lib.add(f, x, y, vx, vy)
    if f.n >= f.maxn then return nil end
    local i = f.n
    f.x[i], f.y[i] = x, y
    f.px[i], f.py[i] = x - (vx or 0) * FRAME, y - (vy or 0) * FRAME
    f.n = i + 1
    for _, t in pairs(f.data) do t[i] = nil end
    return i
end

-- take point i out (the last one takes its place)
function lib.remove(f, i)
    local last = f.n - 1
    if i < 0 or i > last then return end
    f.x[i], f.y[i], f.px[i], f.py[i] = f.x[last], f.y[last], f.px[last], f.py[last]
    for _, t in pairs(f.data) do t[i], t[last] = t[last], nil end
    f.n = last
end

local function step(f)
    local count = gatherShapes(f)
    local p = params(f)
    if f.native then
        native().fluid_step(p, f.shapes, count, f.impulses)
    else
        stepLua(p, f.shapes, count, f.impulses)
    end
    return count
end

local function restDensity(f, mode)
    local p = params(f)
    if f.native then return native().fluid_rest_density(p, mode) end
    return restDensityLua(p, mode)
end

-- A block of water from (x0, y0) to (x1, y1), packed, then settled before it's shown: the rest
-- density is taken from how it actually rests (the cart's calibration), so still water is calm.
function lib.fill(f, x0, y0, x1, y1, maxCount)
    f.n = 0
    local sp = 0.62 * f.h
    local cap = math.min(maxCount or f.maxn, f.maxn)
    local y = y1 - sp * 0.5
    while y > y0 and f.n < cap do
        local x = x0 + sp * 0.5
        while x < x1 and f.n < cap do
            lib.add(f, x, y)
            x = x + sp
        end
        y = y - sp
    end
    f.rho0 = restDensity(f, 0)
    for _ = 1, 3 do
        for _ = 1, 55 do step(f) end
        f.rho0 = restDensity(f, 1)
    end
    for i = 0, f.n - 1 do f.px[i], f.py[i] = f.x[i], f.y[i] end
end

-- For water that starts as nothing (poured): the rest density of a block of this size of point
-- settled on a floor, with no bodies around. Kept per h and step.
local restCache = {}
function lib.calibrate(f)
    local key = f.h .. (f.native and 'C' or 'Lua')
    if not restCache[key] then
        local was = lib.useNative
        lib.useNative = f.native
        local t = lib.new({ h = f.h, floorY = 0, noShapes = true, maxPoints = 300, maxPointsLua = 300 })
        lib.useNative = was
        local w = f.h * 0.62 * 14
        lib.fill(t, -w / 2, -w, w / 2, 0)
        restCache[key] = t.rho0
    end
    f.rho0 = restCache[key]
end

-- drop the points that fell off the world
function lib.cull(f, minx, miny, maxx, maxy)
    if f.native and not next(f.data) then
        f.fs.n = f.n
        f.n = native().fluid_cull(f.fs, minx, miny, maxx, maxy)
        return
    end
    for i = f.n - 1, 0, -1 do
        if f.x[i] < minx or f.x[i] > maxx or f.y[i] < miny or f.y[i] > maxy then
            lib.remove(f, i)
        end
    end
end

-- push the points near (x, y) along (dx, dy) px: a hand stirring
function lib.stir(f, x, y, dx, dy, radius)
    local r2 = radius * radius
    for i = 0, f.n - 1 do
        local ex, ey = f.x[i] - x, f.y[i] - y
        local d2 = ex * ex + ey * ey
        if d2 < r2 then
            local k = (1 - math.sqrt(d2) / radius) * 0.6
            f.px[i], f.py[i] = f.px[i] - dx * k, f.py[i] - dy * k
        end
    end
end

function lib.update(f, dt)
    if dt <= 0 then return end
    f.acc = math.min(f.acc + dt, FRAME * MAX_FRAMES)
    while f.acc >= FRAME do
        local t0 = love.timer.getTime()
        local count = step(f)
        pushBodies(f, count)
        f.stepMs = (love.timer.getTime() - t0) * 1000
        f.acc = f.acc - FRAME
    end
end

---------------------------------------------------------------- drawing

-- Each point is a soft blob added into a canvas (red: how much water, green: how much of it is
-- fast); a shader turns the sum into one body of water: an ink line where it crosses the
-- threshold, lighter near the surface, deeper inside, foam where it's fast. The cart's metaball
-- render, on the GPU.
local blobImage, canvas, shader, batch
local SCALE = 1 / 8 -- the sum is kept small, so an 8-bit canvas holds it when floats aren't there

local SHADER = [[
uniform float threshold;
uniform float rim;
uniform float scale;
uniform vec3 water;
uniform vec3 deep;
uniform vec3 foam;
uniform vec3 ink;
uniform float opacity;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 f = Texel(tex, tc);
    float d = f.r / scale;
    float a = smoothstep(threshold - 0.08, threshold + 0.08, d);
    if (a <= 0.0) return vec4(0.0);
    float fast = clamp(f.g / max(f.r, 0.0001), 0.0, 1.0);
    vec3 c = mix(water, deep, smoothstep(threshold + rim, threshold + rim + 2.5, d));
    c = mix(c, foam, 0.8 * smoothstep(0.8, 1.0, fast));
    float line = 1.0 - smoothstep(threshold + rim - 0.08, threshold + rim + 0.08, d);
    c = mix(c, ink, line);
    float alpha = mix(opacity, 1.0, line);
    return vec4(c, alpha * a);
}
]]

local function ensureDrawing(w, h)
    if not blobImage then
        local size = 64
        local data = love.image.newImageData(size, size)
        data:mapPixel(function(x, y)
            local dx, dy = (x + 0.5) / size * 2 - 1, (y + 0.5) / size * 2 - 1
            local r2 = dx * dx + dy * dy
            local v = r2 < 1 and (1 - r2) ^ 2 or 0
            return 1, 1, 1, v
        end)
        blobImage = love.graphics.newImage(data)
        batch = love.graphics.newSpriteBatch(blobImage, 2048, 'stream')
        shader = love.graphics.newShader(SHADER)
    end
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        local formats = love.graphics.getCanvasFormats()
        local format = formats.rgba16f and 'rgba16f' or 'normal'
        canvas = love.graphics.newCanvas(w, h, { format = format })
    end
end

-- the points as dots, coloured by speed (the cart's V)
function lib.drawPoints(f)
    local s = f.h / 7
    local vmax = 4.5 * s
    for i = 0, f.n - 1 do
        local vx, vy = f.x[i] - f.px[i], f.y[i] - f.py[i]
        local t = math.min(1, math.sqrt(vx * vx + vy * vy) / (vmax * 0.6))
        love.graphics.setColor(0.2 + 0.75 * t, 0.4 + 0.55 * t, 0.85 + 0.15 * t)
        love.graphics.circle('fill', f.x[i], f.y[i], 2.5 * s)
    end
end

-- Draw in the world's transform (the camera's): the blobs go into a screen-sized canvas with that
-- transform, the canvas is laid over the screen through the shader.
function lib.draw(f)
    if f.n == 0 then return end
    local w, h = love.graphics.getDimensions()
    ensureDrawing(w, h)
    local s = f.h / 7
    local vmax = 4.5 * s
    local size = f.blob * f.h * 2 / blobImage:getWidth()
    local half = blobImage:getWidth() / 2
    batch:clear()
    for i = 0, f.n - 1 do
        local vx, vy = f.x[i] - f.px[i], f.y[i] - f.py[i]
        local fast = math.min(1, math.sqrt(vx * vx + vy * vy) / vmax)
        batch:setColor(1, fast, 0, SCALE)
        batch:add(f.x[i], f.y[i], 0, size, size, half, half)
    end
    local before = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
    love.graphics.setBlendMode('alpha')
    love.graphics.setCanvas(before)

    love.graphics.push()
    love.graphics.origin()
    shader:send('threshold', f.threshold)
    shader:send('rim', f.rim)
    shader:send('scale', SCALE)
    shader:send('water', f.color)
    shader:send('deep', f.deep)
    shader:send('foam', f.foam)
    shader:send('ink', f.ink)
    shader:send('opacity', f.opacity)
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas)
    love.graphics.setShader()
    love.graphics.pop()
end

return lib
