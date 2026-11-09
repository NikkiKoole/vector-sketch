-- native-lib.lua
-- Playtime's own C, in the synth's library (native/desound: ribbon.c, grid.c, cloth.c): load(cdef, name)
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

-- A library that's there but lacks a function is stale: built before that C was pulled. The
-- callers then quietly draw in Lua (the office iMac's "ghost Mipos", docs/GHOST-MIPOS.md), so say it,
-- once per function per run.
local warned = {}
local function warnStale(name)
    if warned[name] then return end
    warned[name] = true
    print('[native-lib] native/desound/libdesound.dylib lacks ' .. name
        .. ': it is older than the C in native/desound, rerun native/desound/build.sh (game stopped)')
end

function lib.load(cdef, name)
    if not ffi then return false end
    pcall(ffi.cdef, cdef) -- declaring again (a hot reload) is fine
    local C = library()
    if not C then return false end
    if not pcall(function() return C[name] end) then
        warnStale(name)
        return false
    end
    return C
end

return lib
