-- music-rhodes.lua
-- The Rhodes player: how a good keyboardist plays the keys part on an electric piano (an EPIANO patch:
-- rhodes, lofiKeys, clav), on top of what the comp already decided (which hits, the voicing, the push,
-- the side-step: src/music-parts.lua's keysHits/bookKeys). It adds touch, hands, a pedal and endings
-- with no extra notes, apart from a rare ghost chuck:
--   touch    a 4-bar phrase that swells, downbeats leaning, offbeats lighter; the top voice sings over
--            softer inner voices. The engine's Rhodes is brighter the harder it's struck (gain lowers
--            the strike), so the dynamics are tone too. Bark (the morph macro, read live) only where
--            it's earned: a push, a side-step, a phrase's first downbeat, digging in and settling as the
--            tine rings; soft hits a touch rounder.
--   tines    each key a few cents off, fixed per song: an old, worn Rhodes.
--   hands    the left hand (the voicing's bottom) lands first, the right a few ms after, rolled at a
--            speed and direction of its own per hit (short stabs nearly together, a long chord now and
--            then rolled down); per style the hands sit behind the beat (lofi) or on top of it (citypop).
--   pedal    held and ringing chords (and a ballad) pedal: lifted at each chord change and pressed again
--            just after (legato pedalling, LANE_DAMPER on the slot); stabs stay dry.
--   endings  a stab's key comes up with a short release of its own (the felt damper), slower low down.
--   ghosts   now and then a stab is cut short and chucked again on the next 16th, soft and damped: mostly
--            the hammer's click (neo-soul / funk comping), at most one a bar.
-- And a little vocabulary, rare:
--   grace    now and then a stab's top gets a grace note crushed into it from half a step under.
--   bell     one high note (the top an octave up) a beat after the outro's last chord, sometimes after
--            the intro's last stab.
--   tremolo  under the pedal, a held chord's top two notes rocked soft for about a second.
--   fills    at a phrase's end where the tune breathes, the right hand stops comping for its last two
--            beats and plays a few notes down the chord's pentatonic to a chord tone (or the 4th
--            sighing to the 3rd); the answer and the picks leave that bar alone.
-- The music panel's 'humanize' row (state.musicSettings.humanize) plays the keys plainly instead, as
-- before. Built 2026-11-05 (MUSIC-IDEAS.md, "A Rhodes player"); other machines (wah, Wurli) and a
-- volume-pedal swell are left for later.
local state = require('src.state')
local theory = require('src.music-theory')
local stream, stepTime, humanize = theory.stream, theory.stepTime, theory.humanize
local qualityOf = theory.qualityOf

local lib = {}

-- ms the hands sit behind (+) or ahead (-) of the grid, per style
local FEEL = { lofi = 16, herbs = 12, ballad = 8, island = 4, bossa = 2, supermarket = 0, citypop = -3, sesame = -2 }
-- styles whose whole comp is under the pedal (elsewhere only held and ringing chords)
local PEDAL = { ballad = true }
-- the odds (percent) a comp bar gets a ghost chuck, per style; a style not here gets none
-- (supermarket's and sesame's stabs are 16ths: no room for one)
local GHOSTS = { bossa = 20, citypop = 30, herbs = 15, lofi = 15, island = 10 }
-- The vocabulary is the music panel's ideas (music-styles' commonIdeas: grace, bell, tremolo; never by
-- default), its odds song.ideaOdds: grace a bar, bell where a song closes (the intro's at 0.6 of it),
-- tremolo a held chord. Each rolls on a stream of its own, so switching one doesn't move the others.
local function ideaRnd(p, k) return stream(p.song.seed, k + p.bar.b) end
-- the phrase's swell over 4 bars (a gain on the strike)
local ARC = { 0.9, 0.96, 1.0, 0.93 }

-- the bark: dig in on the strike, settle as the tine rings (morph, scaled per note). Ids out of
-- parlour's way (21-28)
local SH = { bark = 31 }
local function defineShapes(synth)
    if state.music.rhodesShapes == synth.audioTime then return end -- defined in this run already
    if synth.defineShape(SH.bark, { 0, 120, 600 }, { 1, 0.45, 0 }, 'ease') then
        state.music.rhodesShapes = synth.audioTime
    end
end

local function playsRhodes(synth, patch)
    local settings = state.musicSettings
    local voice = settings.voices and settings.voices.keys
    local p = synth.patches and synth.patches[voice or patch]
    return p and p.wave == 'EPIANO'
end

-- the pedal on the keys' slot: up at t (it's left down only where a bar pressed it)
local function lift(synth, t)
    if state.music.rhodesPedal and synth.laneAt then
        synth.laneAt(state.music.rhodesPedal, t, 'damper', 0, 30)
    end
    state.music.rhodesPedal = nil
end

-- The player for one bar of keys, or nil when the keys play plainly (humanize off, not an electric piano,
-- no per-note engine). Books the bar's pedal. Call before the bar's stabs.
function lib.bar(bar, hits)
    local synth, song, style, t0 = bar.synth, bar.song, bar.style, bar.t0
    local patch = style.keys
    if state.musicSettings.humanize == false or not synth.laneAt or not playsRhodes(synth, patch) then
        lift(synth, t0) -- humanize switched off with the pedal down
        return nil
    end
    defineShapes(synth)
    local rnd = stream(song.seed, 9900 + bar.b)
    local p = { synth = synth, song = song, style = style, bar = bar, patch = patch, rnd = rnd,
                feel = (FEEL[song.style] or 0) / 1000, arc = ARC[(bar.j or 0) % 4 + 1] }
    -- the pedal: a ballad, held chords, the outro's ring
    local role = bar.roles.keys
    p.pedal = PEDAL[song.style] or role == 'hold' or role == 'outro'
    if p.pedal then
        if state.music.rhodesPedal and state.music.rhodesPedal ~= patch then lift(synth, t0) end
        for _, chord in ipairs(bar.chords) do
            local t = stepTime(song, t0, chord.s) + p.feel
            synth.laneAt(patch, t - 0.01, 'damper', 0, 25)                           -- up as the chord lands
            synth.laneAt(patch, t + 0.09 + humanize(0.012), 'damper', 1, 60)         -- down again just after
        end
        state.music.rhodesPedal = patch
        local M = state.music
        if M.clipAt then synth.laneAt(patch, M.clipAt, 'damper', 0, 30) end           -- a handoff: let go
    else
        lift(synth, t0)
    end
    -- a ghost chuck: a stab with room after it is cut short and struck again (on the a-of-the-beat
    -- after a long one, the next 8th after a short one), soft and damped
    local odds = GHOSTS[song.style] or 0
    if role == 'comp' and odds > 0 and rnd(100) < odds then
        local options = {}
        for i, h in ipairs(hits) do
            local s, nxt = h.s + (h.len >= 4 and 3 or 2), hits[i + 1]
            if h.len >= 3 and not h.sidestep and s < 16 and s < h.chord.s + h.chord.len
                and not (nxt and nxt.s <= s) then
                options[#options + 1] = { h = h, s = s }
            end
        end
        if #options > 0 then
            local pick = options[rnd(#options) + 1]
            p.ghost, p.ghostAt = pick.h, pick.s
        end
    end
    local ideas = song.ideaOdds or {}
    -- a fill (first: it takes the stabs it plays over away, before the others pick theirs)
    local fillRnd = ideaRnd(p, 160000)
    if (ideas.fills or 0) > 0 and fillRnd(100) < ideas.fills then p.fill = lib.planFill(p, hits, fillRnd) end
    -- a grace note: half a step under a stab's top, crushed into it
    local graceRnd = ideaRnd(p, 120000)
    if (ideas.grace or 0) > 0 and role ~= 'outro' and graceRnd(100) < ideas.grace then
        local options = {}
        for _, h in ipairs(hits) do
            if h.len >= 2 and not h.sidestep then options[#options + 1] = h end
        end
        if #options > 0 then p.grace = options[graceRnd(#options) + 1] end
    end
    -- a bell note: one high note over the last chord, closing the intro or the song
    local last, section = hits[#hits], bar.section
    local closes = role == 'outro' and last and last.ring and 1
        or section and section.kind == 'intro' and bar.j == section.bars - 1 and 0.6
    if last and closes and ideaRnd(p, 130000)(100) < (ideas.bell or 0) * closes then p.bell = last end
    -- a tremolo: a held chord's top two notes shaken, under the pedal (a ballad, held chords)
    local tremoloRnd = ideaRnd(p, 140000)
    if p.pedal and (ideas.tremolo or 0) > 0 and tremoloRnd(100) < ideas.tremolo then
        local options = {}
        for _, h in ipairs(hits) do
            if h.len >= 8 and not h.sidestep and h ~= p.grace then options[#options + 1] = h end
        end
        if #options > 0 then p.tremolo = options[tremoloRnd(#options) + 1] end
    end
    return p
end

-- The fills' rhythms, 16ths in the bar: the first is where the comp stops. sigh: the 4th to the 3rd
local FILLS = { { 10, 11, 12, 14 }, { 12, 13, 14 }, { 8, 10, 12, 14 } }
local SIGH = { 12, 14 }

-- is the tune quiet in this bar from step `from` on (its phrase is built on the phrase's first bar)
local function tuneRests(bar, from)
    local song, j = bar.song, bar.j
    if not bar.tuneOn then return true end
    if song.phraseBar ~= bar.b - j % 4 or not song.phrase then return false end
    local lo, hi = (j % 4) * 16 + from, (j % 4) * 16 + 16
    for _, note in ipairs(song.phrase) do
        if note.s < hi and note.s + (note.len or 1) > lo then return false end
    end
    return true
end

-- the next pitch at or under (dir -1) / over (dir 1) midi whose pitch class is in the set
local function stepTo(set, midi, dir)
    for d = 0, 12 do
        local m = midi + d * dir
        if set[m % 12] then return m end
    end
end

-- A fill for this bar or nil: on a phrase's last bar of an A or B, comping, the tune quiet over its last
-- two beats, one chord under them (no push, no side-step there), no riff in the style. Takes the stabs in
-- its window away.
function lib.planFill(p, hits, rnd)
    local bar, song = p.bar, p.song
    local section, j = bar.section, bar.j or 0
    if bar.roles.keys ~= 'comp' or not section or (section.kind ~= 'A' and section.kind ~= 'B') then return end
    if bar.style.riff then return end -- a riff plays all song long up there (island's marimba): no room
    if not (j % 4 == 3 or j == section.bars - 1) then return end
    local chord = bar.chords[#bar.chords]
    local root = (song.key + chord.degree) % 12
    local intervals = qualityOf(song, chord.quality)
    if not intervals then return end
    local has, tones = {}, {}
    for _, i in ipairs(intervals) do has[i % 12], tones[(root + i) % 12] = true, true end
    if has[6] and not has[7] then return end -- half-diminished: the pentatonic's 5th rubs
    local sigh = has[4] and rnd(100) < 25
    local cell = sigh and SIGH or FILLS[rnd(#FILLS) + 1]
    local from = cell[1]
    if chord.s > from - 2 or not tuneRests(bar, from - 1) then return end
    for _, h in ipairs(hits) do
        if h.s >= from - 1 and (h.pushed or h.sidestep) then return end
    end
    -- the notes: down the chord's pentatonic (no note a half step from a chord tone), from a little over
    -- the comp's top, the last one on a chord tone; or the 4th falling to the major 3rd
    local top = 72
    if state.music.voicing then top = state.music.voicing[#state.music.voicing] end
    local notes = {}
    if sigh then
        local fourth = stepTo({ [(root + 5) % 12] = true }, top + 1, 1)
        notes = { fourth, fourth - 1 }
    else
        local pent, scale = has[3] and not has[4] and { 0, 3, 5, 7, 10 } or { 0, 2, 4, 7, 9 }, {}
        for _, i in ipairs(pent) do
            local pc = (root + i) % 12
            if tones[pc] or not (tones[(pc + 1) % 12] or tones[(pc + 11) % 12]) then scale[pc] = true end
        end
        local m = stepTo(scale, top + 3 + rnd(5), 1)
        for k = 1, #cell do
            if k == #cell then m = stepTo(tones, m, -1) end
            notes[k] = m
            m = stepTo(scale, m - 1, -1)
        end
    end
    if notes[1] > 86 then return end
    for i = #hits, 1, -1 do
        if hits[i].s >= from then table.remove(hits, i) end -- the right hand fills instead
    end
    bar.filled = true
    return { cell = cell, notes = notes }
end

-- the fill's notes: a little lean on the first, softer down to the last, which rings to the bar line
function lib.fill(p, play)
    local f, song, t0 = p.fill, p.song, p.bar.t0
    for k, s in ipairs(f.cell) do
        local stop = f.cell[k + 1] or 16
        local midi = f.notes[k]
        local gain = (k == 1 and 0.72 or 0.62 - 0.03 * k) * (0.95 + 0.08 * p.rnd())
        play(p.synth, 'keys', p.patch, stepTime(song, t0, s) + p.feel + humanize(0.004), midi, 5,
             (stepTime(song, t0, stop) - stepTime(song, t0, s)) * 1000 * (k == #f.cell and 1 or 0.85), s, nil, nil,
             { gain = gain, release = 120, cents = stream(song.seed, 7700 + midi)(9) - 4,
               shapes = k == 1 and { { id = SH.bark, target = 'morph', scale = 0.08 } } or nil })
    end
end

-- a stab's length under the player (a ghosted stab lets go for its chuck)
function lib.length(p, h, len)
    if p and p.ghost == h then return math.min(len, p.ghostAt - h.s) end
    return len
end

-- how hard a hit is struck where it falls in the bar
local function beatWeight(h)
    if h.s == 14 and h.pushed then return 1 end
    if h.s == 0 then return 1 end
    if h.s % 8 == 0 then return 0.94 end
    if h.s % 4 == 0 then return 0.9 end
    if h.s % 2 == 0 then return 0.85 end
    return 0.8
end

-- the times a voicing's notes land at (a stab at t on the grid): the left hand first, the right a few ms
-- later, rolled at this hit's own speed (strum = the style's roll, seconds)
function lib.times(p, h, n, first, t, strum)
    local rnd, out = p.rnd, {}
    t = t + p.feel
    local short = h.len <= 2
    local roll = strum * (0.6 + 0.8 * rnd()) * (short and 0.35 or 1)
    local down = h.len >= 8 and rnd(100) < 20
    local rightAt = t + (first == 1 and n > 2 and (0.003 + 0.009 * rnd()) or 0)
    for k = first, n do
        if k == 1 and n > 2 then
            out[k] = t + humanize(0.002)
        else
            local i = down and (n - k) or (k - math.max(first, n > 2 and 2 or 1))
            out[k] = rightAt + math.max(0, i) * roll + humanize(0.002)
        end
    end
    return out
end

-- one note's touch: the booked-note opts for voicing[k] of n, its midi as played
function lib.touch(p, h, k, n, midi)
    local rnd = p.rnd
    local voice = (k == n) and 1 or (k == 1) and 0.92 or 0.8
    local gain = p.arc * beatWeight(h) * voice * (0.95 + 0.07 * rnd())
    local accent = h.pushed or h.sidestep or (h.s == 0 and (p.bar.j or 0) % 4 == 0)
    local opts = { gain = math.min(1, gain), cents = stream(p.song.seed, 7700 + midi)(9) - 4 }
    if accent then
        opts.accent = 0.3
        opts.shapes = { { id = SH.bark, target = 'morph', scale = 0.22 } }
    elseif gain < 0.8 or h.light then
        opts.timbre, opts.morph = -0.06, -0.08 -- a soft hit: rounder, cleaner
    else
        opts.shapes = { { id = SH.bark, target = 'morph', scale = 0.07 } }
    end
    if not (p.pedal or h.ring) then opts.release = midi < 55 and 260 or 150 end -- the felt damper
    return opts
end

local function cents(p, midi) return stream(p.song.seed, 7700 + midi)(9) - 4 end

-- the grace note crushed into a stab's top: half a step under it, soft and short, just before it; the
-- top lands a touch late for it. Skipped where the note under the top is in the voicing already
function lib.grace(p, h, voicing, times, play)
    local n = #voicing
    local top, grace = voicing[n], voicing[n] - 1
    for k = 1, n - 1 do if voicing[k] == grace then return end end
    times[n] = times[n] + 0.02
    local t = times[n] - (0.035 + 0.02 * p.rnd())
    play(p.synth, 'keys', p.patch, t, grace, math.max(1, h.vol - 1), 45, h.s, nil, nil,
         { gain = 0.45, release = 30, cents = cents(p, grace) })
    return top
end

-- the bell note: the voicing's top an octave up, soft, a beat after the stab (or just after a short one),
-- ringing out
function lib.bell(p, h, voicing, times, play)
    local midi = voicing[#voicing] + 12
    if midi > 90 then return end
    local t = h.len >= 6 and stepTime(p.song, p.bar.t0, h.s + 4) + p.feel or times[#voicing] + 0.14
    play(p.synth, 'keys', p.patch, t, midi, h.vol, math.max(1200, h.len * p.song.beat / 4 * 1000), h.s, nil, nil,
         { gain = 0.5, cents = cents(p, midi), timbre = -0.04 })
end

-- the tremolo: from a beat into a held chord, its top two notes alternating fast and soft (at most ten,
-- about a second), swelling and dying away again, ringing under the pedal. A pianist's tremolo, not a
-- trill (two neighbours): the wrist rocks between thumb and 4th or 5th finger, at most an octave apart
function lib.tremolo(p, h, voicing, play)
    local n = #voicing
    if n < 3 then return end
    local song, rnd = p.song, ideaRnd(p, 150000)
    local lo, hi = voicing[n - 1], voicing[n]
    if hi - lo > 12 then return end -- wider than one hand rocks
    local from = stepTime(song, p.bar.t0, h.s + 4) + p.feel
    local to = stepTime(song, p.bar.t0, h.s + math.min(h.len, 16) - 2) + p.feel
    local gap = 0.1 + 0.025 * rnd()
    local count = math.min(10, math.floor((to - from) / gap)) -- a shake, about a second, not a texture
    if count < 6 then return end
    for i = 0, count - 1 do
        local x = i / (count - 1)
        local swell = 0.22 + 0.28 * math.sin(x * math.pi) -- in, up and away
        local midi = i % 2 == 0 and lo or hi
        play(p.synth, 'keys', p.patch, from + i * gap + humanize(0.006), midi, math.max(1, h.vol - 1), 140,
             h.s + 4, nil, nil, { gain = swell * (0.93 + 0.1 * rnd()), release = 70, cents = cents(p, midi),
                                  timbre = -0.05 })
    end
end

-- the ghost chuck after a stab: its voicing (no bass note) on the next 16th, soft, damped to a click
function lib.ghost(p, h, voicing, play)
    local song, t0 = p.song, p.bar.t0
    local s = p.ghostAt
    local t = stepTime(song, t0, s) + p.feel
    for k = 2, #voicing do
        play(p.synth, 'keys', p.patch, t + (k - 2) * 0.002 + humanize(0.002), voicing[k], math.max(1, h.vol - 1), 70,
             s, nil, nil, { gain = 0.32, damp = 0.9, release = 40,
                                  cents = cents(p, voicing[k]), timbre = -0.05 })
    end
end

return lib
