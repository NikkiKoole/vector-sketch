-- music-setups.lua
-- Little music setups found by playing around in settings → music: the style, each part's instrument
-- (voices), the parts switched off, the drum sounds off or swapped, the band and the effects amount,
-- saved under a name ('island 2') in the save directory's music-setups.json, and put back with one
-- click. Rooms could name one later. reset goes back to the style's own setup; undo undoes the last
-- reset or setup put back (and undo again redoes it).
local json = require('vendor.dkjson')
local state = require('src.state')

local lib = {}

lib.FILE = 'music-setups.json'

local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

-- the settings a setup changes (state.musicSettings), all { key = value } tables
local CHOICES = { 'voices', 'partsOff', 'soundsOff', 'soundVoices', 'ideas', 'jam', 'world' } -- jam: the drum
-- jam's picks; world: how the music answers the world (src/music-events.lua)

-- what plays now, as a setup without a name
function lib.snapshot()
    local s = state.musicSettings
    local now = require('src.music').nowPlaying()
    local snap = { style = s.style, playing = now and now.style, band = s.rhythmSection,
                   effects = require('src.synth').effectAmount(), melodyPatch = s.melodyPatch, spice = s.spice }
    for _, key in ipairs(CHOICES) do snap[key] = copy(s[key]) end
    return snap
end

local function restore(snap)
    local s = state.musicSettings
    if snap.style then s.style = snap.style end
    for _, key in ipairs(CHOICES) do s[key] = copy(snap[key]) end
    s.melodyPatch = snap.melodyPatch
    s.spice = snap.spice
    if snap.band then s.rhythmSection = snap.band end
    if snap.effects then require('src.synth').setEffectAmount(snap.effects) end
end

-- back to the style's own setup: every instrument and sound its own, every part on (style, band and
-- effects stay); undo brings back what was there
function lib.reset()
    state.musicUndo = lib.snapshot()
    local s = state.musicSettings
    for _, key in ipairs(CHOICES) do s[key] = {} end
    s.melodyPatch, s.spice = nil, nil
end

function lib.undo()
    if not state.musicUndo then return false end
    local now = lib.snapshot()
    restore(state.musicUndo)
    state.musicUndo = now
    return true
end

-- the saved setups, in the order they were saved (read once, kept on state across hot reloads)
function lib.list()
    if not state.musicSetups then
        local text = love.filesystem.getInfo(lib.FILE) and love.filesystem.read(lib.FILE)
        local data = text and json.decode(text)
        state.musicSetups = type(data) == 'table' and data or {}
    end
    return state.musicSetups
end

local function write()
    local ok, err = love.filesystem.write(lib.FILE, json.encode(lib.list(), { indent = true }))
    if not ok then print('[music-setups] could not save: ' .. tostring(err)) end
end

-- the setup sounding now, named after its style and a number
function lib.save()
    local setup = lib.snapshot()
    local style = setup.playing or setup.style
    local n, taken = 1, {}
    for _, saved in ipairs(lib.list()) do taken[saved.name] = true end
    while taken[style .. ' ' .. n] do n = n + 1 end
    setup.name, setup.style, setup.playing = style .. ' ' .. n, style, nil
    table.insert(lib.list(), setup)
    write()
    return setup
end

-- put a setup back: its style (at the next bar, as a pick in the panel), its instruments and parts;
-- undo goes back to what played before
function lib.apply(setup)
    state.musicUndo = lib.snapshot()
    restore(setup)
end

function lib.remove(name)
    local list = lib.list()
    for i = #list, 1, -1 do if list[i].name == name then table.remove(list, i) end end
    write()
end

return lib
