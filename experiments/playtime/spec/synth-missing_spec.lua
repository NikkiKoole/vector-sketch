-- spec/synth-missing_spec.lua
-- The synth fails gracefully when its library is out of date: src/synth.lua lists the functions a
-- library lacks before using it (a missing one used to stop the game on the first sound).
-- Without the library at all, synth.start() returns false and the Mipos use their samples.
-- Run with: love . --specs spec/synth-missing_spec.lua

if not love then return end

local synth = require('src.synth')

-- A stand-in for an ffi library: indexing a function it lacks errors, like dlsym does.
local function fakeLibrary(lacking)
    return setmetatable({}, {
        __index = function(_, name)
            if lacking[name] then error('dlsym: symbol not found: ' .. name) end
            return function() end
        end,
    })
end

describe('synth library check', function()
    it('finds nothing missing in a complete library', function()
        assert.are.same({}, synth.missingFunctions(fakeLibrary({})))
    end)

    it('names each function an old library lacks', function()
        local missing = synth.missingFunctions(fakeLibrary({ instrument_lfo = true, note_timbre = true }))
        table.sort(missing)
        assert.are.same({ 'instrument_lfo', 'note_timbre' }, missing)
    end)

    it('the real library, when built, has everything synth.lua declares', function()
        if not love.filesystem.getInfo(synth.libPath) then
            pending('no ' .. synth.libPath .. ' here (native/desound/build.sh)')
            return
        end
        local C = require('ffi').load(love.filesystem.getSource() .. '/' .. synth.libPath)
        assert.are.same({}, synth.missingFunctions(C))
    end)
end)
