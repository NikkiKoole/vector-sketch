-- mipo-band.lua — the Mipos and Puppetmaker's band (style 'puppetmaker' in src/music.lua;
-- docs/PUPPETMAKER-SOUND.md P3/P4). The music books its notes ahead and tells its
-- listeners (music.onNote); this one plays what only it can play, when the synth's
-- audio clock gets there:
--   'sample' notes: pi / po3 are sung by a Mipo on stage, in its own voice with the
--     mouth flap (a random free one, and only with two or more around: in Puppetmaker
--     the crowd sang along, the one you're making didn't); ba / bi / biep2 / biep3 are
--     the band's own little voices (assets/sounds/babirhodes).
--   Puppetmaker's body reactions: a triangle makes a Mipo breathe (a small hop), the
--     rolled Rhodes chord makes one doink (a squash down onto its legs).
local lib = {}

local state = require('src.state')
local music = require('src.music')
local mipoVoice = require('src.mipo-voice')
local mipoChatter = require('src.mipo-chatter')
local mipoActions = require('src.mipo-actions')
local units = require('src.physics-units')

lib.enabled = true
lib.volume = 0.6         -- the band's samples, before mipoVoice.masterVolume
lib.doink = 1500         -- the chord's push down on a torso (breathe is 1000 up; at 100 px/m, src/physics-units.lua)
lib.singers = { pi = true, po3 = true } -- sample names a Mipo sings (assets/voices/puppetmaker)

-- On state, so a hot reload keeps what's booked.
state.mipoBand = state.mipoBand or { queue = {} } -- also .played: counts by name / kind
local B = state.mipoBand

local sources = {} -- [name] = Source, the band's samples

local function sampleSource(name)
    if sources[name] == nil then
        local path = 'assets/sounds/babirhodes/' .. name .. '.ogg'
        sources[name] = love.filesystem.getInfo(path) and love.audio.newSource(path, 'static') or false
    end
    return sources[name] or nil
end

-- Required lazily: src/synth.lua needs LuaJIT's ffi.
local function audioTime()
    local ok, synth = pcall(require, 'src.synth')
    return ok and synth.audioTime() or nil
end

local function onNote(part, patch, midi, vol, _, t)
    if not lib.enabled then return end
    local queue = B.queue
    if part == 'sample' then
        queue[#queue + 1] = { t = t, kind = 'sample', name = patch, midi = midi, vol = vol }
        return
    end
    -- the body reactions are Puppetmaker's: other styles (strum rolls a chord every bar,
    -- re-strums too) would keep the Mipos bobbing
    local playing = music.nowPlaying()
    if not (playing and playing.style == 'puppetmaker') then return end
    if part == 'perc' and (patch == 'triangle' or patch == 'triangleRing') then
        queue[#queue + 1] = { t = t, kind = 'breathe' }
    elseif part == 'chord' and not (B.lastChordAt and math.abs(t - B.lastChordAt) < 0.5) then
        -- one doink per strum (its six notes come within 0.2 s)
        B.lastChordAt = t
        queue[#queue + 1] = { t = t, kind = 'doink' }
    end
end

-- A free Mipo on stage (in view, not held, dazed or talking), and how many there are.
local function anyFree()
    local free = mipoChatter.free()
    if #free == 0 then return nil, 0 end
    return free[love.math.random(#free)], #free
end

local function playNote(note)
    B.played = B.played or {}
    local key = note.kind == 'sample' and note.name or note.kind
    B.played[key] = (B.played[key] or 0) + 1
    if note.kind == 'sample' then
        local pitch = 2 ^ ((note.midi - 60) / 12)
        if lib.singers[note.name] then
            local singer, count = anyFree()
            if singer and count >= 2 then mipoVoice.say(singer, 'puppetmaker', note.name, pitch) end
            return
        end
        local source = sampleSource(note.name)
        if source then
            local clone = source:clone()
            clone:setPitch(pitch)
            clone:setVolume(lib.volume * mipoVoice.masterVolume)
            clone:play()
        end
    elseif note.kind == 'breathe' then
        local mipo = anyFree()
        if mipo then mipoActions.breathe(mipo) end
    elseif note.kind == 'doink' then
        local mipo = anyFree()
        local torso = mipo and mipo.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then
            torso.body:applyLinearImpulse(0, units.impulse(lib.doink))
        end
    end
end

function lib.update()
    local queue = B.queue
    if #queue == 0 then return end
    local now = audioTime()
    if not now then
        B.queue = {}
        return
    end
    local i = 1
    while i <= #queue do
        local note = queue[i]
        if note.t <= now then
            table.remove(queue, i)
            if now - note.t < 0.5 then playNote(note) end -- late (a hitch, a pause): skip it
        else
            i = i + 1
        end
    end
end

-- Registered by calling it, never as a field: see src/music.lua's settings note.
music.onNote('mipo-band', onNote)

return lib
