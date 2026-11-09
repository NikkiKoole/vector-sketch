-- hair-native.lua
-- A hair lock's strip in one C call (native/desound/hair.c, in the synth's library): the same as
-- src/hair-locks.lua's lockPath + stripMesh in Lua, written straight into a ByteData for
-- Mesh:setVertices. lib.available() is false without the library (the web build, a desktop
-- without native/desound/build.sh, or one built before hair.c): the Lua path draws then.
local lib = {}

local nativeLib = require('src.native-lib')
local ffi = nativeLib.ffi

local CDEF = [[
int hair_strip(const float *points, int n, float segment, float radius, float pitch, float phase,
               float tilt, float halfWidth, float *out);
]]

lib.MAX_SAMPLES = 400 -- HAIR_MAX_SAMPLES in hair.c
lib.BYTES_PER_VERTEX = 32 -- x, y, u, v, r, g, b, a as floats

local C
local function load()
    if C == nil then C = nativeLib.load(CDEF, 'hair_strip') end
    return C
end

function lib.available() return load() ~= false end

local pointBuf = ffi and ffi.new('float[128]')

-- Writes the lock's strip into `data` (a ByteData of MAX_SAMPLES * 2 * BYTES_PER_VERTEX bytes);
-- returns the number of vertices (0: none).
function lib.strip(points, n, segment, radius, pitch, phase, tilt, halfWidth, data)
    local c = load()
    if not c or n > 64 then return 0 end
    for i = 1, 2 * n do pointBuf[i - 1] = points[i] end
    return c.hair_strip(pointBuf, n, segment, radius, pitch, phase, tilt, halfWidth,
        ffi.cast('float *', data:getFFIPointer()))
end

return lib
