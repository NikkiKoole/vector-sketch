-- synth-web.lua
-- The synth's C library as src/synth.lua sees it (S.C), for the browser build, where there is no
-- FFI. Each call is written down; once a frame (at de_lua_tick) the frame's calls go out as one
-- printed line. The page (webtest/index.template.html) catches lines starting with '@desound' and
-- hands them to the same engine built to wasm (native/desound/build-web.sh), running in an
-- AudioWorklet (webtest/desound-processor.js). docs/WEB-EXPORT-LOVEJS.md WEB2.
--
-- The two calls that answer: audio_time returns Lua's own clock, and the worklet maps the times
-- in schedule_at onto the engine's clock. note_on returns a number given out here, which the
-- worklet maps to the engine's handle.

local lib = {}

local calls = {}
local nextHandle = 0

local function record(name, ...)
    local parts = { name, ... }
    for i = 2, #parts do parts[i] = tostring(parts[i]) end
    calls[#calls + 1] = table.concat(parts, ' ')
end

-- Sends what this frame asked for. The time lets the worklet line up the two clocks.
local function flush()
    if #calls == 0 then return end
    print('@desound\t' .. tostring(love.timer.getTime()) .. '\t' .. table.concat(calls, '\t'))
    calls = {}
end

-- Lua's clock stands in for the engine's (the worklet keeps them lined up).
function lib.audio_time()
    return love.timer.getTime()
end

function lib.note_on(midi, instr, vol)
    nextHandle = nextHandle + 1
    record('note_on', nextHandle, midi, instr, vol)
    return nextHandle
end

function lib.de_lua_init()
    return 1
end

function lib.de_lua_tick(dt)
    record('de_lua_tick', dt)
    flush()
end

-- sample_load hands over a float array: only the voice lab uses it, not on the web.
function lib.sample_load() end

-- Everything else: a C function with number arguments and nothing back.
return setmetatable(lib, {
    __index = function(_, name)
        return function(...) record(name, ...) end
    end,
})
