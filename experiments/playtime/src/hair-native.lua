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

-- Vertex `from` copied over vertex `to` (0-based), in `data`: the joins between strips.
function lib.copyVertex(data, from, to)
    local base = ffi.cast('float *', data:getFFIPointer())
    ffi.copy(base + to * 8, base + from * 8, lib.BYTES_PER_VERTEX)
end

return lib
