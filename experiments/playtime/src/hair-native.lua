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
int hair_cut_step(double *P, double *Q, const double *defs, const double *bends, int locks,
                  double bx, double by, double angle, double gx, double gy, double dt, double damping,
                  double stand, double stiffness, double springy, int hasOval, double ovalX, double ovalY,
                  int hasGround, double groundY, int steps);
int hair_cut_settled(const double *P, double *snap, int total, double limit2, int valid);
int hair_cut_strip(const double *P, const double *defs, int locks, int wantFront, double tilt, double picW,
                   float *out, int maxVerts);
int hair_cut_v1(void);
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

-- A whole haircut with its points kept in C (hair.c hair_cut_*, HAIR-LOCKS H8): with the JIT off every
-- FFI element access from Lua is slow, and copying each lock's points in and out (lib.step, lib.strip)
-- cost most of what the C saved. A cut is made from the locks once (newCut), stepped, checked and laid
-- out in one call each a frame; readBack puts the points into the Lua tables again (back to the Lua path).
local CUT
local function loadCut()
    if CUT == nil then CUT = nativeLib.load(CDEF, 'hair_cut_v1') end
    return CUT
end
function lib.cutAvailable() return loadCut() ~= false end

local DEF = 16 -- HAIR_DEF in hair.c, and its fields (0-based)
local D_N, D_OFF, D_SEG, D_REST, D_RX, D_RY, D_DRAPE, D_FRONT, D_RING, D_PITCH, D_WAVE, D_WAVEP, D_PHASE,
    D_WIDTH, D_BENDS = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14

-- locks: hair-locks' lock tables (points, prev, bends, n, segment, ...); o: the haircut's opts;
-- waveSegments: segments a curly wave (wavePitch = segment * it).
function lib.newCut(locks, o, waveSegments)
    if not loadCut() then return nil end
    local total, bendCount = 0, 0
    for _, lock in ipairs(locks) do
        total = total + 2 * lock.n
        bendCount = bendCount + lock.n + 1
    end
    local cut = {
        locks = #locks, total = total,
        P = ffi.new('double[?]', math.max(1, total)), Q = ffi.new('double[?]', math.max(1, total)),
        snap = ffi.new('double[?]', math.max(1, total)), snapValid = false,
        defs = ffi.new('double[?]', math.max(1, #locks * DEF)), bends = ffi.new('double[?]', math.max(1, bendCount)),
    }
    local off, boff = 0, 0
    for k, lock in ipairs(locks) do
        local d = (k - 1) * DEF
        local defs = cut.defs
        defs[d + D_N], defs[d + D_OFF], defs[d + D_SEG], defs[d + D_REST] = lock.n, off, lock.segment, lock.restAngle
        defs[d + D_RX], defs[d + D_RY] = lock.bx or lock.rx, lock.by or lock.ry
        defs[d + D_DRAPE], defs[d + D_FRONT] = lock.drape and 1 or 0, lock.front and 1 or 0
        defs[d + D_RING], defs[d + D_PITCH] = lock.ring or o.ringlets, lock.ringPitch or o.ringletPitch
        defs[d + D_WAVE], defs[d + D_WAVEP] = lock.wave or 0, lock.segment * waveSegments
        defs[d + D_PHASE], defs[d + D_WIDTH], defs[d + D_BENDS] = lock.phase or 0, lock.width, boff
        for i = 3, lock.n do cut.bends[boff + i] = lock.bends[i] end
        for i = 1, 2 * lock.n do cut.P[off + i - 1], cut.Q[off + i - 1] = lock.points[i], lock.prev[i] end
        off, boff = off + 2 * lock.n, boff + lock.n + 1
    end
    return cut
end

-- The points back into the lock tables (to step and draw in Lua again).
function lib.readBack(cut, locks)
    local off = 0
    for _, lock in ipairs(locks) do
        for i = 1, 2 * lock.n do lock.points[i], lock.prev[i] = cut.P[off + i - 1], cut.Q[off + i - 1] end
        off = off + 2 * lock.n
    end
end

-- Lock k's root (its head's frame) moved: a torso drawn bent (hair-locks bendRoots).
function lib.cutRoot(cut, k, x, y)
    local d = (k - 1) * DEF
    cut.defs[d + D_RX], cut.defs[d + D_RY] = x, y
end

function lib.cutStep(cut, o, bx, by, angle, gx, gy, dt, ovalX, ovalY, groundY, steps)
    CUT.hair_cut_step(cut.P, cut.Q, cut.defs, cut.bends, cut.locks, bx, by, angle, gx, gy, dt, o.damping, o.stand,
        o.stiffness, o.springy, ovalX and 1 or 0, ovalX or 0, ovalY or 1, groundY and 1 or 0, groundY or 0, steps)
end

-- Whether no point moved more than `limit` since the last call; takes the new snapshot.
function lib.cutSettled(cut, limit)
    local still = CUT.hair_cut_settled(cut.P, cut.snap, cut.total, limit * limit, cut.snapValid and 1 or 0) == 1
    cut.snapValid = true
    return still
end

-- One layer as one joined strip into `data` (ByteData, 8 floats a vertex); returns the vertex count.
function lib.cutStrip(cut, wantFront, tilt, picW, data, maxVerts)
    return CUT.hair_cut_strip(cut.P, cut.defs, cut.locks, wantFront and 1 or 0, tilt, picW,
        ffi.cast('float *', data:getFFIPointer()), maxVerts)
end

-- Vertex `from` copied over vertex `to` (0-based), in `data`: the joins between strips.
function lib.copyVertex(data, from, to)
    local base = ffi.cast('float *', data:getFFIPointer())
    ffi.copy(base + to * 8, base + from * 8, lib.BYTES_PER_VERTEX)
end

return lib
