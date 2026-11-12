-- background-app.lua — a spec run or a thumbs run doesn't take the keyboard (macOS).
-- Launched from a terminal, LÖVE's window made it the active app and took the keys from whatever
-- you were typing in (Nikki 2026-11-12), off-screen window or not. Tried 2026-11-12: SDL's
-- SDL_MAC_BACKGROUND_APP hint (in LÖVE 11.5's SDL, didn't stop it); [NSApp hide:] once the window
-- was up (focus went to Chrome, not back to the terminal, and LÖVE took it again later).
-- What's done: from conf.lua, before the window exists, the app's activation policy set to
-- 'prohibited': it never becomes the active app. Its window is off-screen anyway (conf.lua);
-- drawing to canvases works the same. Not the game: that one you want to see and play.
-- Plain C through LuaJIT's FFI (conf.lua runs before love.system exists, so the OS from jit.os).
local lib = {}

local PROHIBITED = 2 -- NSApplicationActivationPolicyProhibited

function lib.neverActivate()
    local jit = rawget(_G, 'jit') -- LuaJIT's (luacheck's lua51 doesn't know it)
    if not (jit and jit.os == 'OSX') then return false end
    local okFfi, ffi = pcall(require, 'ffi')
    if not okFfi then return false end
    return (pcall(function()
        pcall(ffi.cdef, [[
            void *objc_getClass(const char *name);
            void *sel_registerName(const char *name);
            void objc_msgSend(void);
        ]])
        local C = ffi.C
        -- objc_msgSend called through its real types (as variadic it breaks on arm64)
        local send = ffi.cast('void *(*)(void *, void *)', C.objc_msgSend)
        local sendLong = ffi.cast('bool (*)(void *, void *, long)', C.objc_msgSend)
        local app = send(C.objc_getClass('NSApplication'), C.sel_registerName('sharedApplication'))
        if app ~= nil then sendLong(app, C.sel_registerName('setActivationPolicy:'), PROHIBITED) end
    end))
end

return lib
