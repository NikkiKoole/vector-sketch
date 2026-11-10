-- hair-native.lua
-- A hair lock's strip in one C call (native/desound/hair.c, in the synth's library): the same as
-- src/hair-locks.lua's lockPath + stripMesh in Lua, written straight into a ByteData for
-- Mesh:setVertices. lib.available() is false without the library (the web build, a desktop
-- without native/desound/build.sh, or one built before hair.c): the Lua path draws then.
local lib = {}

local nativeLib = require('src.native-lib')
local ffi = nativeLib.ffi

local CDEF = [[
int hair_strip(const float *points, int n, float segment, float radius, float pitch, float wave,
               float wavePitch, float phase, float tilt, float halfWidth, float *out);
int hair_strip_v2(void);
int hair_step(double *p, double *q, int n, double segment, double restAngle, const double *bends,
              double rootLX, double rootLY, int drape, double bx, double by, double angle,
              double gx, double gy, double dt, double damping, double stand, double stiffness,
              double springy, int hasOval, double ovalX, double ovalY, int hasGround, double groundY,
              int steps);
]]

lib.MAX_SAMPLES = 400 -- HAIR_MAX_SAMPLES in hair.c
lib.BYTES_PER_VERTEX = 32 -- x, y, u, v, r, g, b, a as floats

local C
local function load()
    -- hair_strip_v2 marks a library built since the curly wave: an older hair_strip takes fewer
    -- arguments and would read garbage for them
    if C == nil then C = nativeLib.load(CDEF, 'hair_strip_v2') and nativeLib.load(CDEF, 'hair_strip') end
    return C
end

function lib.available() return load() ~= false end

local pointBuf = ffi and ffi.new('float[128]')

-- Writes the lock's strip into `data` from vertex `at` (0-based; the ByteData needs room for
-- MAX_SAMPLES * 2 vertices of BYTES_PER_VERTEX from there); returns the number of vertices (0: none).
function lib.strip(points, n, segment, radius, pitch, wave, wavePitch, phase, tilt, halfWidth, data, at)
    local c = load()
    if not c or n > 64 then return 0 end
    for i = 1, 2 * n do pointBuf[i - 1] = points[i] end
    return c.hair_strip(pointBuf, n, segment, radius, pitch, wave, wavePitch, phase, tilt, halfWidth,
        ffi.cast('float *', data:getFFIPointer()) + (at or 0) * 8)
end

-- A lock's simulation steps in one C call (hair.c hair_step, the same maths as hair-locks.lua's
-- stepLock): its points copied in, `steps` fixed steps, copied back. False without the library
-- (the web, a stale dylib): hair-locks steps it in Lua then. (Declared in CDEF above: device.sh keeps
-- only the functions a `local CDEF = [[` block names, the linker strips the rest.)
local S
local function loadStep()
    if S == nil then S = nativeLib.load(CDEF, 'hair_step') end
    return S
end
function lib.stepAvailable() return loadStep() ~= false end

local MAX_STEP_POINTS = 64
local pBuf = ffi and ffi.new('double[?]', 2 * MAX_STEP_POINTS)
local qBuf = ffi and ffi.new('double[?]', 2 * MAX_STEP_POINTS)
local bendBuf = ffi and ffi.new('double[?]', MAX_STEP_POINTS + 1)

-- Returns false when it couldn't (no library, a lock too long): the caller steps it in Lua.
function lib.step(lock, o, bx, by, angle, gx, gy, dt, ovalX, ovalY, groundY, steps)
    local c = loadStep()
    local n = lock.n
    if not c or n > MAX_STEP_POINTS then return false end
    local p, q, bends = lock.points, lock.prev, lock.bends
    for i = 1, 2 * n do pBuf[i - 1], qBuf[i - 1] = p[i], q[i] end
    if bends then for i = 3, n do bendBuf[i] = bends[i] end end
    c.hair_step(pBuf, qBuf, n, lock.segment, lock.restAngle, bendBuf, lock.bx or lock.rx, lock.by or lock.ry,
        lock.drape and 1 or 0, bx, by, angle, gx, gy, dt, o.damping, o.stand, o.stiffness, o.springy,
        ovalX and 1 or 0, ovalX or 0, ovalY or 1, groundY and 1 or 0, groundY or 0, steps)
    for i = 1, 2 * n do p[i], q[i] = pBuf[i - 1], qBuf[i - 1] end
    return true
end

-- Vertex `from` copied over vertex `to` (0-based), in `data`: the joins between strips.
function lib.copyVertex(data, from, to)
    local base = ffi.cast('float *', data:getFFIPointer())
    ffi.copy(base + to * 8, base + from * 8, lib.BYTES_PER_VERTEX)
end

return lib
