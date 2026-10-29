-- voice-lab-params.lua
-- What the inspector (src/ui/inspector.lua) shows in the settings panel's voice
-- lab section (src/ui/world-settings.lua). The target is state.voiceLab; the
-- bench itself is src/voice-lab.lua.
local lib = {}

local function lab() return require('src.voice-lab') end

lib.rows = {
    { key = 'take', kind = 'note', label = function() return lab().status() end },
    { key = 'set', kind = 'choice', options = lab().sets,
        set = function(t, v) t.set, t.index = v, 1 end },
    { key = 'next', label = 'take', kind = 'buttons', options = { '<', '>' },
        run = function(_, _, option) lab().step(option == '<' and -1 or 1) end },
    -- the engine's limits: sample_shift -24..24, sample_formant -12..12 (best within 7)
    { key = 'speed', kind = 'number', min = -24, max = 24, step = 1 },
    { key = 'shift', kind = 'number', min = -24, max = 24, step = 1 },
    -- + = a bigger throat (measured: the spectral centroid drops, 1258 -> 1042 Hz at +6 on po3).
    -- A big Mipo is size + with the pitch down (speed or shift -); at the same pitch it's a big
    -- throat talking high.
    { key = 'size', kind = 'number', min = -12, max = 12, step = 1 },
    { key = 'inflection', kind = 'number', min = 0, max = 1 },
    { key = 'play', kind = 'buttons', options = { 'now', 'synth', 'sing' },
        run = function(_, _, option)
            if option == 'now' then lab().playNow()
            elseif option == 'synth' then lab().playSynth()
            else lab().playSing() end
        end },
}

function lib.target() return require('src.state').voiceLab end

return lib
