-- ribbon-native.lua
-- A limb ribbon's vertices in one C call (native/desound/ribbon.c, in the synth's library):
-- the same as shapeRibbon + texturedCurve in Lua, written straight into a ByteData for
-- Mesh:setVertices. lib.available() is false without the library (the web build, a desktop
-- without native/desound/build.sh): the Lua path draws then.
local lib = {}

local OS = love and love.system and love.system.getOS() -- nil in pure specs (busted)
local IS_IOS = OS == 'iOS'
local ffi = OS and OS ~= 'Web' and require('ffi') or nil

local CDEF = [[
int ribbon_strip(const float *nodes, int nNodes, float grow, int bendiness, int segments,
                 float halfWidth, float shift, int miterClamp, float *out);
]]

-- The vertex layout ribbon_strip writes: 4 floats a vertex
lib.FORMAT = { { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 } }
lib.BYTES_PER_VERTEX = 16

local C
local function load()
    if C ~= nil then return C end
    C = false
    if not ffi then return C end
    pcall(ffi.cdef, CDEF)
    local ok, found
    if IS_IOS then
        ok, found = pcall(function() return ffi.C.ribbon_strip and ffi.C end)
    else
        local path = love.filesystem.getSource() .. '/native/desound/libdesound.dylib'
        ok, found = pcall(ffi.load, path)
        if ok then ok = pcall(function() return found.ribbon_strip end) end
    end
    if ok and found then C = found end
    return C
end

function lib.available() return load() ~= false end

local nodeBuf = ffi and ffi.new('float[128]')

-- nodes: flat { x1, y1, x2, y2, ... } anchors. Writes into `data` (a ByteData of at least
-- segments * 2 * BYTES_PER_VERTEX bytes); returns the number of vertices (0: no curve).
function lib.strip(nodes, grow, bendiness, segments, halfWidth, shift, miterClamp, data)
    local c = load()
    if not c then return 0 end
    local n = #nodes
    if n > 128 then return 0 end
    for i = 1, n do nodeBuf[i - 1] = nodes[i] end
    return c.ribbon_strip(nodeBuf, n / 2, grow, bendiness, segments, halfWidth, shift or 0,
        miterClamp and 1 or 0, ffi.cast('float *', data:getFFIPointer()))
end

return lib
