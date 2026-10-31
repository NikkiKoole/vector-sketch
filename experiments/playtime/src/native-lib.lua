-- native-lib.lua
-- Playtime's own C, in the synth's library (native/desound: ribbon.c, grid.c): load(cdef, name)
-- declares the functions and gives the library when `name` is in it, else false. On iOS the
-- library is linked into the app (ffi.C, native/ios/device.sh), on a desktop it's the dylib
-- native/desound/build.sh makes; on the web and in pure specs there is none, and the callers
-- draw in Lua. (src/synth.lua loads the same library itself, for its render thread.)
local lib = {}

local OS = love and love.system and love.system.getOS() -- nil in pure specs (busted)
local ffi = OS and OS ~= 'Web' and require('ffi') or nil
lib.ffi = ffi

-- The vertex layout the C writes for Mesh:setVertices(ByteData): x, y, u, v as floats
lib.FORMAT = { { 'VertexPosition', 'float', 2 }, { 'VertexTexCoord', 'float', 2 } }
lib.BYTES_PER_VERTEX = 16

local dylib -- the desktop's loaded library, false when there is none
local function library()
    if OS == 'iOS' then return ffi.C end
    if dylib == nil then
        local ok, loaded = pcall(ffi.load, love.filesystem.getSource() .. '/native/desound/libdesound.dylib')
        dylib = ok and loaded or false
    end
    return dylib
end

function lib.load(cdef, name)
    if not ffi then return false end
    pcall(ffi.cdef, cdef) -- declaring again (a hot reload) is fine
    local C = library()
    if not C or not pcall(function() return C[name] end) then return false end
    return C
end

return lib
