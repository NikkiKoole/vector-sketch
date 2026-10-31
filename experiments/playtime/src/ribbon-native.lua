-- ribbon-native.lua
-- A limb ribbon's vertices in one C call (native/desound/ribbon.c, in the synth's library):
-- the same as shapeRibbon + texturedCurve in Lua, written straight into a ByteData for
-- Mesh:setVertices. lib.available() is false without the library (the web build, a desktop
-- without native/desound/build.sh): the Lua path draws then.
local lib = {}

local nativeLib = require('src.native-lib')
local ffi = nativeLib.ffi

local CDEF = [[
int ribbon_strip(const float *nodes, int nNodes, float grow, int bendiness, int segments,
                 float halfWidth, float shift, int miterClamp, float *out);
]]

-- The vertex layout ribbon_strip writes: 4 floats a vertex
lib.FORMAT = nativeLib.FORMAT
lib.BYTES_PER_VERTEX = nativeLib.BYTES_PER_VERTEX

local C
local function load()
    if C == nil then C = nativeLib.load(CDEF, 'ribbon_strip') end
    return C
end

function lib.available() return load() ~= false end

local nodeBuf = ffi and ffi.new('float[128]')

-- nodes: flat { x1, y1, x2, y2, ... } anchors. Writes into `data` (a ByteData of at least
-- segments * 2 * BYTES_PER_VERTEX bytes); returns the number of vertices (0: no curve).
-- pinch: the stricter clamp for ribbons that curl at their ends (lips, ribbon.c), over miterClamp.
function lib.strip(nodes, grow, bendiness, segments, halfWidth, shift, miterClamp, data, pinch)
    local c = load()
    if not c then return 0 end
    local n = #nodes
    if n > 128 then return 0 end
    for i = 1, n do nodeBuf[i - 1] = nodes[i] end
    return c.ribbon_strip(nodeBuf, n / 2, grow, bendiness, segments, halfWidth, shift or 0,
        pinch and 2 or (miterClamp and 1 or 0), ffi.cast('float *', data:getFFIPointer()))
end

return lib
