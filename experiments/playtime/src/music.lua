-- music.lua
-- Background music, arranged the way dreamengine's lofi.c is (dreamengine
-- docs/design/radio-arranger-lessons.md): it plans first and then plays the plan.
--   the SONG is planned when it starts: key, form (intro, A, B, outro), an A and a B progression,
--     the comping taste, the tune's motif. Each part has a role per section: the first A has no
--     tune, B moves more, the outro rings home.
--   every BAR is planned knowing the next one: the push (the next chord comped early, on the
--     and-of-4), a fill into a new section, the bass walking into the next root.
--   the TUNE is seeded by its place in the form, so every A sings the same melody and B its own:
--     a hook that comes back. A motif of note groups is stated over two bars, bar 3 breathes,
--     bar 4 answers. Strong beats land on chord tones, passing tones fill the thirds, long notes
--     stay off the held chord's semitones, and the tune sits above the chord.
-- Styles are data (lib.styles): bossa (straight, Rhodes, clave), guaraldi (swung, a felt piano,
-- open fifths in the left hand, brushes), island (Animal Crossing's hourly music: short loops, a
-- plinky marimba riff, a bouncy bass, a kalimba tune), dusk (island in the evening: slower, a worn felt
-- piano holding, a sparse kalimba riff, a flute tune), dumont (Domenique Dumont's dubby synth-pop:
-- funky minor vamps, a busy syncopated bass, a marimba riff, a steel-pan tune, claps with an echo),
-- supermarket (Mr. Lucky's ii7 - V11 vamp, staccato and bouncy, a marimba tune), herbs (MF DOOM's
-- Special Herbs: a dusty swung boom-bap loop, chopped Rhodes, a sub bass on the kick), lofi (lofi
-- city's jazzhop: our planner, its sound), puppetmaker (Puppetmaker 2's band: a chance-driven CR-78
-- hand-percussion loop and its rolled Rhodes chord), strum (that chord humanized, through a key),
-- citypop (Japanese pop-funk: the Royal Road, a popping bass, guitar cutting, strings, horns),
-- buymode (the Sims 1 buy-mode piano trio: Mall Rat's moves, a key change up a half step),
-- sesame (a 70s TV small band: clav, a walking upright, vibes, horn shouts), satie (a
-- Gymnopédie-like 3/4 waltz on a felt piano), ambient (pentatonic loops of unequal lengths drifting
-- over a drone, Music for Airports), jingle (Mac DeMarco at dusk: a chorused guitar fingerpicking his
-- borrowed bVII and bIII chords, a soft bass walking down, rim and hats, a sine tune in the chorus) and
-- ballad. lib.onNote lets other code hear every note
-- (the Mipos react to the puppetmaker band).
-- style = 'set' plays lib.set as a live set: each song ends on home, takes a breath, and the next
-- one starts in a related key.
--
-- The arrangement follows the play: calm, the keys play alone and the left hand takes the bass;
-- busy (impacts call music.bump), the drums join where the form lets them (the upright too when
-- lib.upright is on). rhythmSection forces that on or off. lib.chordNotes lets sound effects play
-- in the current chord. Notes are booked ahead on the synth's audio clock, a bar at a time.
-- Driven by src/sound.lua every frame (paused or not); rooms change it with lib.cue and lib.layers
-- (src/room-music.lua).

local state = require('src.state')
local D = require('src.music-styles')
local theory = require('src.music-theory')
local stream = theory.stream
local chordPcs = theory.chordPcs
local barChords = theory.barChords
local stepTime = theory.stepTime
local plan = require('src.music-plan')
local VERSION = plan.VERSION
local nextKey = plan.nextKey
local planSong = plan.planSong
local parts = require('src.music-parts')
local bandPlays = parts.bandPlays
local bookLoopBar = parts.bookLoopBar
local lofiGroove = parts.lofiGroove
local bookTone = parts.bookTone
local remember = parts.remember
local applyLift = parts.applyLift
local keysHits = parts.keysHits
local bookKeys = parts.bookKeys
local bookVinyl = parts.bookVinyl
local bookBass = parts.bookBass
local bookRiff = parts.bookRiff
local bookDrums = parts.bookDrums
local bookHorns = parts.bookHorns
local bookGuitar = parts.bookGuitar
local bookStrings = parts.bookStrings
local bookTune = parts.bookTune
local LOOP_BARS = parts.LOOP_BARS

local lib = {}

-- The switches (the settings panel writes them) live on state, behind lib's metatable. A hot reload
-- (lume.hotswap) copies this chunk's functions onto the OLD module table, the one the panel writes
-- to, while those functions still read THIS chunk's table: a plain field set in the panel was never
-- seen (picking a style did nothing until the song ended) and a reload reset it. On state, every
-- copy of the module reads the same switch, and it survives a reload.
--   enabled
--   style          'set' (lib.set in turn), or one style: 'bossa', 'guaraldi', 'island', 'dusk', 'dumont',
--                  'supermarket', 'herbs', 'lofi', 'puppetmaker', 'strum', 'sesame', 'citypop', 'buymode',
--                  'satie', 'ambient', 'jingle', 'ballad'
--   rhythmSection  'auto' (joins when play gets busy), 'on' or 'off'
--   upright        the upright in the rhythm section; off: the left hand keeps the bass
--   melody         the tune on top
--   melodyPatch    force the tune's voice (rhodesLead, pianoLead, kalimba, ...); nil: the style's
state.musicSettings = state.musicSettings
    or { enabled = true, style = 'set', rhythmSection = 'auto', upright = false, melody = true }
local SETTINGS = { enabled = true, style = true, rhythmSection = true, upright = true, melody = true,
                   melodyPatch = true }
-- music.trace = fn(part, t, midi, vol, durMs) sees every note (claudetools, specs): on state.music too,
-- where src/music-parts.lua's play reads it
local HOOKS = { trace = true }
setmetatable(lib, {
    __index = function(_, k)
        if SETTINGS[k] then return state.musicSettings[k] end
        if HOOKS[k] then return state.music and state.music[k] end
    end,
    __newindex = function(t, k, v)
        if SETTINGS[k] then state.musicSettings[k] = v
        elseif HOOKS[k] then state.music[k] = v
        else rawset(t, k, v) end
    end,
})

-- the data (src/music-styles.lua) under its old names: music.styles, music.set, music.qualities, ...
for name, value in pairs(D) do rawset(lib, name, value) end

-- On `state` so a hot reload keeps the song going where it was.
state.music = state.music or { activity = 0, withBand = false }
local M = state.music
if M.version ~= VERSION then M.version, M.song, M.barAt = VERSION, nil, nil end
M.booked = M.booked or {} -- the last few booked chords: { at = audio time, pcs = { pitch classes } }
M.listeners = M.listeners or {} -- onNote listeners by name (on state, so they survive a hot reload)
M.heard = M.heard or {} -- [part][patch] = { { from, to }, ... }: lib.playing's memory

-- Hear every note the music books: fn(part, patch, midi, vol, durMs, t, step). part is 'keys', 'bass',
-- 'lead', 'riff', 'drums', 'vinyl', or for puppetmaker 'perc' / 'chord' / 'sample' (a sample to play: patch
-- is its name, ba / bi / biep2 / biep3, midi 60 its own pitch; the synth plays nothing); t is the audio time
-- it's booked for (lookahead ahead of synth.audioTime()); step 0..15 in its bar (puppetmaker only, for
-- now). fn = nil removes it. Call this, don't set a field: see the settings note above.
function lib.onNote(name, fn)
    M.listeners[name] = fn
end

-- Gameplay calls this (impacts); enough of it brings the rhythm section in.
function lib.bump(amount)
    M.activity = M.activity + (amount or 1)
end

-- The play level now, and whether the band is in (the settings panel's meter)
function lib.playLevel()
    return M.activity, M.withBand
end

-- One bar of a song, part by part, in this order (the parts share the bar's random stream and the
-- performance jitter, so the order is part of the sound).
local function bookBar(synth, t0, song, b)
    local style = lib.styles[song.style]
    M.barStart = t0
    if style.loop then return (LOOP_BARS[style.loop] or bookLoopBar)(synth, t0, song, b) end
    local section, j = song.barSection[b], song.barIndex[b]
    applyLift(song, section)
    local bar = { synth = synth, t0 = t0, song = song, b = b, style = style, section = section, j = j,
                  roles = section.roles, band = bandPlays(), rnd = stream(song.seed, 1000 + b),
                  chords = barChords(song, b), nextChords = b < song.bars and barChords(song, b + 1) or nil }
    for _, chord in ipairs(bar.chords) do
        chord.root = (song.key + chord.degree) % 12
        chord.lydian = song.lydian and chord.quality == 'maj9'
        remember(stepTime(song, t0, chord.s), chordPcs(song, chord)) -- impacts play along in the chord
    end
    if style.picking == 'travis' then return parts.bookTravis(bar) end -- strum: the guitar alone
    if style.picking == 'jabs' then return parts.bookJabs(bar) end     -- rollo: bass and guitar stabs
    if style.picking == 'jingle' then return parts.bookJingle(bar) end -- jingle: its own four parts
    local hits, sidestepAt, pushes = keysHits(bar)
    bookKeys(bar, hits)
    local groove = style.groove == 'lofi'
        and lofiGroove(song, section.kind, j, section.bars, bar.band and bar.roles.drums or 'none',
                       stream(song.seed, 3000 + b))
    if song.tone then bookTone(synth, song, section, j, bar.rnd) end
    if style.vinyl then bookVinyl(bar) end
    bookBass(bar, groove, pushes, sidestepAt)
    if style.riff and not (section.kind == 'outro' and j >= 2) then bookRiff(bar) end
    bookDrums(bar, groove)
    local inSong = section.kind == 'A' or section.kind == 'B'
    if song.horns and bar.band and inSong and j % 4 == 2 then bookHorns(bar) end
    if style.guitar and bar.band and inSong then bookGuitar(bar, pushes) end
    if style.strings and section.kind == 'B' then bookStrings(bar) end
    if lib.melody and bar.roles.lead and song.hasLead ~= false then bookTune(bar) end
end

-- The style was just picked: skip the intro into the first A with the tune and the band in, so the
-- new style is heard at once. The band lifts the play level, so it leaves again as play calms down.
-- bandIn = false (a cue): the tune at once, the band as the play level says.
local function audition(song, bandIn)
    local skip = 0
    for _, section in ipairs(song.sections) do
        if section.kind == 'A' then
            section.roles.lead = true
            song.bar = skip
            break
        end
        skip = skip + section.bars
    end
    song.hasLead = true
    if bandIn ~= false then M.activity = math.max(M.activity, 2 * lib.bandJoins) end
end

-- A cue comes in where the energy is: at its B (the chorus) when the old song was in its B, else at
-- its first A; never the intro. The tune is in from the start, the band as the play level says.
local function enter(song, kind)
    local skip, at = 0, nil
    for _, section in ipairs(song.sections) do
        if section.kind == kind or (not at and section.kind == 'A') then
            at = { section = section, bar = skip }
            if section.kind == kind then break end
        end
        skip = skip + section.bars
    end
    if at then
        at.section.roles.lead = true
        song.bar = at.bar
    end
    song.hasLead = true
end

-- The layers (iMUSE's instruments on and off, Woodtick's one tune in many arrangements): which parts
-- play. A preset is a name from lib.layerPresets or a table { drums = false, ... }; M.layers holds
-- { name, off = { part = true } } and M.nextLayers the one waiting for the next bar line.
lib.layerPresets = { 'full', 'quiet', 'cellar', 'rhythm' }
local LAYERS = {
    full = {},
    quiet = { drums = true, bass = true, perc = true, riff = true, guitar = true, horns = true, vinyl = true },
    cellar = { lead = true, drums = true, perc = true, riff = true, guitar = true, horns = true, strings = true,
               sample = true },
    rhythm = { lead = true, keys = true, chord = true, strings = true },
}
local function layerOf(preset)
    if type(preset) == 'string' then
        if not LAYERS[preset] then return nil end
        local off = {}
        for part in pairs(LAYERS[preset]) do off[part] = true end
        return { name = preset, off = off }
    elseif type(preset) == 'table' then
        local off = {}
        for part, on in pairs(preset) do if on == false then off[part] = true end end
        return { name = 'custom', off = off }
    end
end
local function sameLayers(a, b)
    a, b = a and a.off or {}, b and b.off or {}
    for part in pairs(a) do if not b[part] then return false end end
    for part in pairs(b) do if not a[part] then return false end end
    return true
end

-- The handoff, part by part: the old song's last bar keeps its light parts and is cut at the bar
-- line (the releases fade it); the new song comes in light and the heavy parts join bar by bar.
local TAIL_OFF = { drums = true, bass = true, perc = true, riff = true, guitar = true, horns = true, vinyl = true,
                   sample = true }
local ENTRY_OFF = {
    { drums = true, perc = true, riff = true, guitar = true, horns = true, vinyl = true },
    { drums = true, perc = true, horns = true },
}
local function muteFor(extra)
    local mute = {}
    for part in pairs(M.layers and M.layers.off or {}) do mute[part] = true end
    for part in pairs(extra or {}) do mute[part] = true end
    return next(mute) and mute or nil
end

-- Whether bar b closes a 4-bar phrase (or a section, or the song): a cue's moment
local function phraseEnds(song, b)
    if b < 1 or b >= song.bars then return true end
    local j, section = song.barIndex[b], song.barSection[b]
    return (j + 1) % 4 == 0 or j == section.bars - 1
end

local function cueKey(cue, song)
    if cue.key == 'keep' and song then return song.setKey end
    return nextKey(song and song.setKey)
end

-- Books the next bar at audio time t0; returns its length in seconds. Past the song's last bar:
-- one bar's breath (in a set), then the next song.
local function bookNext(synth, t0)
    local song = M.song
    local wrongStyle = song and ((lib.style ~= 'set' and song.style ~= lib.style)
        or (lib.style == 'set' and not (function()
            for _, name in ipairs(lib.set) do if name == song.style then return true end end
            return false
        end)()))
    if M.nextLayers then M.layers, M.nextLayers = M.nextLayers, nil end -- layers change on the bar line
    M.mute, M.clipAt = muteFor(), nil
    local cue = M.cue
    if cue and wrongStyle then M.cue, cue = nil, nil end -- a pick in the panel wins over a cue
    if cue and song and not cue.tailed then
        if cue.at == 'phrase' and not phraseEnds(song, song.bar + 1) then
            cue = nil -- the old song plays on: its tail is the phrase's last bar
        elseif song.bar < song.bars then -- the old song's last bar: its light parts, cut at the bar line
            cue.tailed = true
            song.bar = song.bar + 1
            M.mute, M.clipAt = muteFor(TAIL_OFF), t0 + song.barLength
            bookBar(synth, t0, song, song.bar)
            return song.barLength
        end
    end
    if cue then -- the cue lands: its style on the next downbeat, in its key, coming in light
        M.cue = nil
        lib.style = cue.style
        if cue.layers then M.layers = cue.layers end
        local was = song and song.barSection[math.max(1, math.min(song.bars, song.bar))]
        M.song = planSong(cueKey(cue, song))
        song = M.song
        enter(song, was and was.kind == 'B' and 'B' or 'A')
        M.entry = 0
    elseif not song or wrongStyle then
        M.song = planSong()
        song = M.song
        if wrongStyle then audition(song) end
    elseif song.bar >= song.bars then
        if lib.style == 'set' and not song.breathed then
            song.breathed = true
            return song.barLength
        end
        M.song = planSong()
        song = M.song
    end
    if M.entry then -- the new song's first bars: the heavy parts join one bar at a time
        M.entry = M.entry + 1
        M.mute = muteFor(ENTRY_OFF[M.entry])
        if M.entry >= #ENTRY_OFF then M.entry = nil end
    end
    song.bar = song.bar + 1
    bookBar(synth, t0, song, song.bar)
    return song.barLength
end

-- Switch which parts play (lib.layerPresets, or a table { drums = false, lead = false, ... }) on the
-- next bar line, same song. Returns whether it changes anything.
function lib.layers(preset)
    local layer = layerOf(preset)
    if not layer then return false end
    if sameLayers(layer, M.layers) then
        M.nextLayers = nil
        return false
    end
    if sameLayers(layer, M.nextLayers) then return false end
    if lib.enabled and M.song then M.nextLayers = layer else M.layers = layer end
    return true
end

-- Change to `style` (a style name, or 'set') the way a game score does, for the rooms
-- (src/room-music.lua). opts.at: 'bar' (at the next bar line) or 'phrase' (the default: when the
-- 4-bar phrase ends). Then a handoff, part by part: the old song plays one more bar with only its
-- light parts, cut at the bar line, and the new one starts on the next downbeat at its A (its B
-- when the old one was in B), light first, drums and horns joining two bars in. opts.key: 'related'
-- (the default: a fourth away) or 'keep'. opts.layers: a preset the new song comes in with (see
-- lib.layers); for the style already set, a cue with layers is lib.layers. The style lands in
-- lib.style (the settings panel shows it). Cueing what's already set does nothing (and drops a
-- pending cue); a second cue replaces the first. With the music off or not started it just sets
-- the style. Returns whether it will change anything.
function lib.cue(style, opts)
    opts = opts or {}
    if style ~= 'set' and not lib.styles[style] then return false end
    local layer = opts.layers and layerOf(opts.layers)
    if style == lib.style then
        M.cue = nil
        return layer and lib.layers(opts.layers) or false
    end
    if not (lib.enabled and M.song) then
        lib.style, M.cue = style, nil
        if layer then M.layers = layer end
        return true
    end
    M.cue = { style = style, at = opts.at == 'bar' and 'bar' or 'phrase',
              key = opts.key == 'keep' and 'keep' or 'related', layers = layer }
    return true
end

-- The notes from lo to hi (MIDI) that belong to the chord sounding right now, low to high, so
-- sound effects can play along. nil when the music is off or hasn't started.
function lib.chordNotes(lo, hi)
    if not (lib.enabled and M.audioTime) then return nil end
    local sounding
    for _, chord in ipairs(M.booked) do
        if chord.at <= M.audioTime then sounding = chord end
    end
    sounding = sounding or M.booked[1]
    if not sounding then return nil end
    local inChord = {}
    for _, pc in ipairs(sounding.pcs) do inChord[pc] = true end
    local notes = {}
    for midi = lo, hi do
        if inChord[midi % 12] then notes[#notes + 1] = midi end
    end
    return #notes > 0 and notes or nil
end

-- Which instruments are playing, per part, for the settings panel (and the bridge): a list of
-- { part, patches = { { name, now } } } in a fixed part order, holding each patch heard in the last
-- `window` seconds (default 4); now = sounding at this moment.
lib.parts = { 'lead', 'keys', 'chord', 'guitar', 'horns', 'strings', 'riff', 'bass', 'drums', 'perc', 'sample',
              'vinyl' }
function lib.playing(window)
    local now = M.audioTime
    if not (lib.enabled and now) then return {} end
    window = window or 4
    local out = {}
    for _, part in ipairs(lib.parts) do
        local patches = {}
        for name, runs in pairs(M.heard[part] or {}) do
            local heard, sounding = false, false
            for _, run in ipairs(runs) do
                if run.from <= now and run.to > now - window then
                    heard, sounding = true, sounding or run.to >= now
                end
            end
            if heard then patches[#patches + 1] = { name = name, now = sounding } end
        end
        table.sort(patches, function(a, b) return a.name < b.name end)
        if #patches > 0 then out[#out + 1] = { part = part, patches = patches } end
    end
    return out
end

-- what is playing, for a console or a HUD: style, key, section
function lib.nowPlaying()
    local song = M.song
    if not song then return nil end
    local section = song.barSection[math.max(1, math.min(song.bars, song.bar))]
    return { style = song.style, key = song.key, section = section and section.kind, bar = song.bar, bars = song.bars,
             layers = M.layers and M.layers.name or 'full',
             stepTime = M.barStart, stepLen = song.beat / 4 } -- the latest booked bar's step 0, in audio time
end

function lib.update(synth, now)
    if M.lastNow then M.activity = M.activity * 0.5 ^ ((now - M.lastNow) / lib.activityHalfLife) end
    M.lastNow = now
    if not lib.enabled then return end
    local t = synth.audioTime()
    if not t then return end
    M.audioTime = t
    -- pedal changes (strum's guitar) turn when the music reaches them, not when they were booked
    while M.pedals and M.pedals[1] and M.pedals[1].at <= t do
        local change = table.remove(M.pedals, 1)
        local tape, flanger = change.tape, change.flanger
        if tape and synth.slotTape then synth.slotTape(change.patch, tape[1], tape[2], tape[3], tape[4]) end
        if flanger and synth.slotFlanger then
            synth.slotFlanger(change.patch, flanger[1], flanger[2], flanger[3], flanger[4])
        end
    end
    -- first call, or back from a pause: start fresh a moment from now
    if not M.barAt or M.barAt < t then M.barAt = t + 0.2 end
    while M.barAt < t + lib.lookahead do
        M.barAt = M.barAt + bookNext(synth, M.barAt)
    end
end

return lib
