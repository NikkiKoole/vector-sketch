-- music-parlour.lua
-- The parlour style: a slow, warm song that shows off dreamengine's humanizing engine (2026-11-04,
-- dreamengine-a2's brief; dreamengine docs/guides/humanizing-sounds.md and humanized-playing.md §8).
-- The instruments come in one at a time so each is heard on its own first:
--   intro  the felt piano with a real sustain pedal: a LANE_DAMPER curve on its slot (lifted at each
--          chord change, pressed again just after), every note only as long as its key, with its own
--          release (pianohand.c, L mode)
--   A      + the cello: one bow per bar, the two notes in it slurred on the same voice (glide: a finger
--          landing, or a quick shift on a leap), a connected bow change at each bar line (note_event_at
--          NEV_REARTIC on the NEW note: a slur takes over the booking), swells, a late vibrato of its own
--          (cellohand.c, B mode)
--   A      + the flute: booked notes carrying their own breath-sharp cents, a scoop into each note, a swell
--          or the phrase-end fade, the tongue's puff of air, a vibrato that blooms late (breathflute.c)
--   B      + the pad: analog voice cards (instrument_analog) and a hand on the filter, LANE_CUTOFF ramps
--          sweeping slowly through each 4-bar phrase (synthhand.c, L + E)
--   A      + brushes: the kick buried (damp) on 1 and bounced on 3, ghost notes damped short, the hi-hat
--          foot: an open hat eased down (LANE_LEVEL) into the chick that closes it (drumhand.c, L mode)
--   outro  the flute's last note fading, the piano ringing under the pedal
-- The music panel's 'humanize' row (state.musicSettings.humanize) plays the same notes plainly instead:
-- fixed gates and levels, the engine's own vibrato, no lanes, no shapes, no damping. Read per bar.
-- Registered as loop = 'parlour' in music-plan's LOOP_PLANS and music-parts' LOOP_BARS, which pass in what
-- this file needs from them (addSections, play, remember), as music-jam.lua does.
local state = require('src.state')
local theory = require('src.music-theory')
local stream, stepTime, lengthMs, inRange, voiceChord, humanize =
    theory.stream, theory.stepTime, theory.lengthMs, theory.inRange, theory.voiceChord, theory.humanize

local lib = {}

lib.QUALITIES = { maj7 = { 4, 7, 11 }, m7 = { 3, 7, 10 }, ['7'] = { 4, 7, 10 }, sus = { 5, 7, 10 },
                  m6 = { 3, 7, 9 } }
lib.PROGRESSIONS = {
    intro = { { 0, 'maj7' }, { 5, 'maj7' }, { 0, 'maj7' }, { 7, 'sus' } },
    A = { { 0, 'maj7' }, { 9, 'm7' }, { 5, 'maj7' }, { 7, 'sus' },
          { 0, 'maj7' }, { 4, 'm7' }, { 2, 'm7' }, { 7, '7' } },
    B = { { 5, 'maj7' }, { 4, 'm7' }, { 2, 'm7' }, { 7, '7' },
          { 5, 'maj7' }, { 5, 'm6' }, { 2, 'm7' }, { 7, 'sus' } },
    outro = { { 5, 'maj7' }, { 5, 'm6' }, { 0, 'maj7' }, { 0, 'maj7' } },
}
-- who plays where: one more instrument each section
lib.FORM = {
    { 'intro', 4, { piano = true } },
    { 'A', 8, { piano = true, cello = true } },
    { 'A', 8, { piano = true, cello = true, flute = true } },
    { 'B', 8, { piano = true, cello = true, flute = true, pad = true } },
    { 'A', 8, { piano = true, cello = true, flute = true, pad = true, drums = true } },
    { 'outro', 4, { piano = true, cello = true, flute = true, pad = true } },
}

-- the gestures booked notes carry (synth.defineShape), defined once per run; ids out of others' way
local SH = { scoop = 21, swell = 22, fade = 23, puff = 24, celloSwell = 25, celloFade = 26, grow = 27, dig = 28 }
local function defineShapes(synth)
    local done = state.music.parlourShapes
    if done == synth.audioTime then return end -- defined in this run already (the synth's table is per run)
    local ok = synth.defineShape(SH.scoop, { 0, 90 }, { -100, 0 }, 'fast')                -- cents, x the scoop
        and synth.defineShape(SH.swell, { 0, 450, 1000 }, { -1.5, 0.4, -1.0 }, 'ease')     -- dB over 1 s, stretched
        and synth.defineShape(SH.fade, { 0, 600, 1000 }, { 0, -0.5, -4.5 }, 'ease')        -- dB: before a breath
        and synth.defineShape(SH.puff, { 0, 45 }, { 0.4, 0 }, 'linear')                    -- timbre: the tongue's air
        and synth.defineShape(SH.celloSwell, { 0, 450, 1000 }, { -2.5, 1.2, -1.0 }, 'ease')
        and synth.defineShape(SH.celloFade, { 0, 550, 1000 }, { 0, -1.0, -7.0 }, 'ease')
        and synth.defineShape(SH.grow, { 0, 300 }, { -1.3, 0 }, 'ease')                    -- an up-bow grows in
        and synth.defineShape(SH.dig, { 0, 70, 250 }, { 0.16, 0.05, 0 }, 'ease')           -- a down-bow digs in
    if ok then state.music.parlourShapes = synth.audioTime end
end

local function human() return state.musicSettings.humanize ~= false end
local function r1() return love.math.random() * 2 - 1 end
local function smooth01(x) x = math.max(0, math.min(1, x)); return x * x * (3 - 2 * x) end

local function chordTones(song, chord)
    local root = (song.key + chord[1]) % 12
    local pcs = { root }
    for _, i in ipairs(lib.QUALITIES[chord[2]]) do pcs[#pcs + 1] = (root + i) % 12 end
    return root, pcs
end

local SCALE = { 0, 2, 4, 5, 7, 9, 11 }

---------------------------------------------------------------- the plan

-- A flute phrase's notes per bar: { at (8ths), len (8ths) }; the fourth bar of a phrase ends it (a breath)
local RHYTHMS = {
    { { 0, 4 }, { 4, 2 }, { 6, 2 } }, { { 0, 2 }, { 2, 2 }, { 4, 4 } }, { { 0, 3 }, { 3, 1 }, { 4, 4 } },
    { { 0, 4 }, { 4, 4 } }, { { 2, 2 }, { 4, 2 }, { 6, 2 } },
}
local PHRASE_ENDS = { { { 0, 6 } }, { { 0, 2 }, { 2, 4 } } }

-- a tune for one section: 8 bars, two phrases; the second starts as the first and ends its own way
local function planTune(song, kind, rnd)
    local prog, lo, hi = lib.PROGRESSIONS[kind], 72, 86
    local bars, prev = {}, nil
    local function phrase(first, count, home)
        for j = first, first + count - 1 do
            local chord = prog[j + 1]
            local _, pcs = chordTones(song, chord)
            local rhythm = j % 4 == 3 and PHRASE_ENDS[rnd(#PHRASE_ENDS) + 1] or RHYTHMS[rnd(#RHYTHMS) + 1]
            local notes = {}
            for k, cell in ipairs(rhythm) do
                local strong = cell[1] % 4 == 0
                local pos = ((j % 4) + cell[1] / 8) / 4 -- through the phrase, 0..1
                local target = 75 + 8 * math.sin(math.pi * pos)
                local best, bestScore
                for midi = lo, hi do
                    local pc = midi % 12
                    local inChord, inScale = false, false
                    for _, c in ipairs(pcs) do if c == pc then inChord = true end end
                    for _, d in ipairs(SCALE) do if (song.key + d) % 12 == pc then inScale = true end end
                    local last = home and j == first + count - 1 and k == #rhythm
                    local fits = (last and pc == song.key % 12) or (not last and (inChord or (not strong and inScale)))
                    if fits then
                        local score = math.abs(midi - target) * 0.6 + rnd() * 1.2
                        if prev then
                            local leap = math.abs(midi - prev)
                            if leap > 4 then score = score + (leap - 4) * 1.5 end
                            if leap == 0 then score = score + 2 end
                        end
                        if not bestScore or score < bestScore then best, bestScore = midi, score end
                    end
                end
                notes[k] = { at = cell[1], len = cell[2], midi = best, phraseEnd = j % 4 == 3 and k == #rhythm }
                prev = best
            end
            bars[j] = notes
        end
    end
    phrase(0, 4, false)
    bars[4], bars[5] = bars[0], bars[1]
    prev = bars[5][#bars[5]].midi
    phrase(6, 2, kind == 'A')
    return bars
end

function lib.plan(song, _style, addSections)
    local list = {}
    for _, entry in ipairs(lib.FORM) do
        local prog = lib.PROGRESSIONS[entry[1]]
        list[#list + 1] = { entry[1], entry[2], function(j) return prog[j % #prog + 1] end, entry[3] }
    end
    addSections(song, list)
    song.hasLead = true
    song.parlour = { bowDir = 1, tunes = { A = planTune(song, 'A', stream(song.seed, 100)),
                                           B = planTune(song, 'B', stream(song.seed, 200)) } }
end

---------------------------------------------------------------- the parts

-- the piano: the left hand's root on 1 and its fifth on 3, the right hand rocking through the chord in 8ths.
-- Humanized: each key held only as long as a hand holds it, with its own release; the pedal lane does
-- the ringing, lifted at the chord change and pressed again just after (a legato pedal). Plain: every
-- note gated to the bar's end, no pedal.
local RH = { [2] = 1, [4] = 2, [6] = 3, [10] = 2, [12] = 3, [14] = 2 }
local function bookPiano(play, synth, t0, song, _b, chord, h)
    local root, _ = chordTones(song, chord)
    local intervals = lib.QUALITIES[chord[2]] -- rootless (the bass has it): a maj7's root and 7th would rub
    song.parlour.voicing = voiceChord(root, intervals, 55, 71, song.parlour.voicing)
    local v = song.parlour.voicing
    local barMs = lengthMs(song, 0, 16)
    local patch = 'hPiano'
    local function note(s, midi, keyBeats, gain)
        local t = stepTime(song, t0, s) + humanize(h and 0.007 or 0.002)
        if h then
            local rel = midi >= 89 and 1100 or math.floor(260 + math.max(0, 84 - midi) * 7)
            play(synth, 'keys', patch, t, midi, 6, lengthMs(song, s, keyBeats * 4) * 0.9, s, nil, nil,
                 { gain = math.max(0.08, gain + r1() * 0.04), release = rel })
        else
            play(synth, 'keys', patch, t, midi, 4, barMs - lengthMs(song, 0, s) - 20, s)
        end
    end
    local bass = inRange(root, 40)
    note(0, bass, 1.5, 0.85)
    note(8, bass + 7, 1, 0.62)
    for s, k in pairs(RH) do
        local midi = v[math.min(k, #v)]
        note(s, midi, 0.5, (k == #v and 0.7 or 0.55) + (s == 2 and 0.06 or 0))
    end
    if h then -- the foot: up as the new chord sounds, down again just after
        synth.laneAt(patch, t0, 'damper', 0, 25)
        synth.laneAt(patch, t0 + 0.13 + humanize(0.015), 'damper', 1, 70)
    else
        synth.laneAt(patch, t0, 'damper', 0, 0)
    end
end

-- the cello: two half notes a bar, the root then a chord tone leaning toward the next root. One bow a bar,
-- the bar line a connected bow change, a fresh stroke every 4 bars (the phrase), the phrase's last note
-- fading. Humanized as cellohand's B mode; plain: every note a fresh attack, the engine's vibrato.
local function bookCello(play, synth, t0, song, b, chord, h, j, sectionBars)
    local pl = song.parlour
    local root, pcs = chordTones(song, chord)
    local nextChord = song.chords[b + 1]
    local nextRoot = nextChord and inRange((song.key + nextChord[1]) % 12, 36) or inRange(root, 36)
    local first = inRange(root, 36)
    local second, bestCost = first + 7, nil
    for _, pc in ipairs(pcs) do
        if pc ~= root then
            for _, midi in ipairs({ inRange(pc, 36), inRange(pc, 36) + 12 }) do
                if midi <= 57 then
                    local cost = math.abs(midi - nextRoot) + math.abs(midi - first) * 0.3
                    if not bestCost or cost < bestCost then second, bestCost = midi, cost end
                end
            end
        end
    end
    local halfMs = lengthMs(song, 0, 8)
    local phraseStart = j % 4 == 0
    local phraseEnd = j % 4 == 3 or j == sectionBars - 1
    if not h then
        play(synth, 'bass', 'hCelloPlain', t0, first, 5, halfMs * 0.95, 0)
        play(synth, 'bass', 'hCelloPlain', stepTime(song, t0, 8), second, 5, halfMs * 0.95, 8)
        pl.celloId = nil
        return
    end
    local dur = halfMs / 1000
    local function glideFor(from, to)
        local leap = math.abs(to - from)
        if leap <= 2 then return 1 end -- a finger landing: no slide
        return math.min(90, math.floor((40 + 5 * leap) * (0.8 + 0.4 * love.math.random())))
    end
    local function vib()
        return { cents = 12 + 6 * love.math.random(), rate = 5.0 + 0.6 * love.math.random(),
                 delay = math.floor(250 + 200 * love.math.random()), fade = 500, wander = 0.4 }
    end
    local swell = (b % 2 == 0) and 0.62 or 0.7
    -- note 1: a new stroke at the phrase start, else the bow turns as it arrives (connected)
    if phraseStart or not pl.celloId then pl.bowDir = -1 else pl.bowDir = -pl.bowDir end
    local shapes = { { id = SH.celloSwell, target = 'gain', scale = 1, stretch = dur } }
    if pl.bowDir > 0 then shapes[2] = { id = SH.dig, target = 'timbre', scale = 1, stretch = 1 }
    else shapes[2] = { id = SH.grow, target = 'gain', scale = 1, stretch = 1 } end
    local fresh = phraseStart or not pl.celloId
    local t1 = t0 + humanize(0.006)
    local id1 = play(synth, 'bass', 'hCello', t1, first, 6, (dur + 0.12) * 1000, 0, nil, nil,
        { gain = swell, glide = fresh and 0 or glideFor(pl.celloLast or first, first), vib = vib(), shapes = shapes })
    if id1 and not fresh then synth.noteEvent(id1, t1, 'reartic', 0.25 + 0.2 * love.math.random()) end
    -- note 2: slurred in the same bow
    local t2 = stepTime(song, t0, 8) + humanize(0.006)
    local endShape = phraseEnd and { id = SH.celloFade, target = 'gain', scale = 1, stretch = dur }
        or { id = SH.celloSwell, target = 'gain', scale = 0.6, stretch = dur }
    local held = phraseEnd and dur * 0.97 or dur + 0.12
    local id2 = play(synth, 'bass', 'hCello', t2, second, 6, held * 1000, 8, nil, nil,
        { gain = swell - 0.05, glide = glideFor(first, second), vib = vib(), shapes = { endShape } })
    pl.celloId = (not phraseEnd) and (id2 or id1) or nil
    pl.celloLast = second
end

-- the flute: the section's tune. Humanized as breathflute's booked mode; plain: fresh attacks at one level.
local function bookFlute(play, synth, t0, song, b, section, j, h)
    if state.musicSettings.melody == false then return end
    local notes
    if section.kind == 'outro' then
        if j ~= 0 then return end
        local chord = song.chords[b]
        local root = (song.key + chord[1]) % 12
        notes = { { at = 0, len = 16, midi = inRange((root + 4) % 12, 74), phraseEnd = true, long = true } }
    else
        local tune = song.parlour.tunes[section.kind]
        notes = tune and tune[j] or {}
    end
    local peak = 0
    for _, n in ipairs(notes) do peak = math.max(peak, n.midi or 0) end
    for k, n in ipairs(notes) do
        if n.midi then
            local s = n.at * 2
            local t = stepTime(song, t0, s) + humanize(h and 0.01 or 0.002)
            local lenMs = lengthMs(song, s, n.len * 2)
            if not h then
                play(synth, 'lead', 'hFlutePlain', t, n.midi, 5, lenMs * 0.9, s)
            else
                local nextNote = notes[k + 1]
                local slurNext = nextNote and nextNote.at == n.at + n.len and not n.phraseEnd
                local tongued = k == 1 or notes[k - 1].at + notes[k - 1].len < n.at
                local len = lenMs / 1000
                local held = n.phraseEnd and len or slurNext and len + 0.03 or len - 0.05
                local height = 1 - math.min(1, (peak - n.midi) / 10)
                local vol = 4.2 + 1.9 * height + r1() * 0.15
                if n.phraseEnd then vol = vol - 0.3 end
                local scoop = tongued and (14 + 10 * love.math.random()) or 6
                local shapes = { { id = SH.scoop, target = 'pitch', scale = scoop / 100 } }
                if n.phraseEnd then shapes[2] = { id = SH.fade, target = 'gain', scale = 1, stretch = held }
                elseif len > 0.5 then shapes[2] = { id = SH.swell, target = 'gain', scale = 1, stretch = len } end
                if tongued and #shapes < 3 then shapes[#shapes + 1] = { id = SH.puff, target = 'timbre', scale = 1 } end
                local opts = { gain = math.max(0.05, math.min(1, vol / 7)), cents = (vol - 5) * 4 + r1() * 2,
                               glide = tongued and 0 or 40, shapes = shapes }
                if len > 0.32 then
                    opts.vib = { cents = (13 + 8 * love.math.random() + (n.midi == peak and 5 or 0)),
                                 rate = 4.9 + 0.8 * love.math.random(),
                                 delay = math.floor((160 + 200 * love.math.random()) * (len > 1 and 1.3 or 1)),
                                 fade = 400, wander = 0.5 }
                end
                play(synth, 'lead', 'hFlute', t, n.midi, 7, held * 1000, s, nil, nil, opts)
            end
        end
    end
end

-- the pad: the chord held through the bar, overlapping into the next. Humanized: the notes spread a
-- little and the hand on the filter sweeps through each 4-bar phrase (LANE_CUTOFF, a ramp a beat);
-- the analog cards are the patch's (hPad). Plain: struck together, the filter left alone.
local function bookPad(play, synth, t0, song, b, chord, h, j)
    local root, _ = chordTones(song, chord)
    local intervals = lib.QUALITIES[chord[2]] -- rootless (the bass has it): a maj7's root and 7th would rub
    song.parlour.padVoicing = voiceChord(root, intervals, 52, 67, song.parlour.padVoicing)
    local barMs = lengthMs(song, 0, 16)
    local patch = h and 'hPad' or 'hPadPlain'
    for k, midi in ipairs(song.parlour.padVoicing) do
        if h then
            play(synth, 'strings', patch, t0 + (k - 1) * 0.011 + humanize(0.006), midi, 6, barMs + 250, 0, nil, nil,
                 { gain = 0.62 + r1() * 0.06 })
        else
            play(synth, 'strings', patch, t0, midi, 4, barMs - 20, 0)
        end
    end
    if h then
        local beatS = song.beat
        for q = 0, 3 do
            local phase = ((j % 4) * 4 + q + 1) / 16
            local cut = 500 + 1900 * smooth01(math.sin(math.pi * phase))
                + 250 * math.sin(b * 1.7 + q * 0.9 + song.seed % 97) * math.sin(b * 0.61 + q * 0.37) -- its wobble
            synth.laneAt(patch, t0 + q * beatS, 'cutoff', math.log(math.max(20, cut) / 900) / math.log(2),
                         math.floor(beatS * 1000))
        end
    end
end

-- brushes: a sweep per half bar, the tap on 2 and 4 a hair late, ghosts, the kick on 1 (and softly on 3),
-- the hi-hat foot. Humanized: damp per stroke (the buried kick, short ghosts, the closed chick), the open
-- hat on the and-of-4 eased down by the foot (LANE_LEVEL) into the chick on the next 1. Plain: the same
-- strokes undamped at fixed levels, no foot.
local function bookDrums(play, synth, t0, song, b, h)
    local rnd = stream(song.seed, 7000 + b)
    local function hit(patch, s, midi, gain, ms, damp, late)
        local t = stepTime(song, t0, s) + (late or 0) + humanize(h and 0.006 or 0.001)
        if h then
            play(synth, 'drums', patch, t, midi, 7, ms, s, nil, nil,
                 { gain = math.max(0.05, gain + r1() * 0.04), damp = damp })
        else
            play(synth, 'drums', patch, t, midi, 4, ms, s)
        end
    end
    local half = lengthMs(song, 0, 8)
    hit('brush', 0, 70, 0.55, half * 0.95, 0)
    hit('brush', 8, 70, 0.4, half * 0.95, 0)
    hit('kick', 0, 36, 0.78, 300, 0.82)
    if rnd(100) < 60 then hit('kick', 8, 36, 0.3, 300, 0) end
    hit('snare', 4, 60, 0.62, 160, 0, 0.008)
    hit('snare', 12, 60, 0.68, 160, 0, 0.008)
    for _, s in ipairs({ 7, 10, 15 }) do
        if rnd(100) < 45 then hit('snare', s, 60, 0.18, 160, 0.85) end
    end
    -- the hat: the foot's chick on 2 and 4, an open stroke on the and-of-4 the foot closes on the next 1
    hit('hHat', 4, 81, 0.4, 260, 0.9)
    hit('hHat', 12, 81, 0.4, 260, 0.9)
    hit('hHat', 14, 84, 0.38, 900, 0.25)
    local chickAt = t0 + song.barLength
    if h then
        synth.laneAt('hHat', chickAt - 0.15, 'level', -6.9, 150)
        synth.laneAt('hHat', chickAt, 'level', 0, 0)
        play(synth, 'drums', 'hHat', chickAt + humanize(0.004), 78, 7, 60, 0, nil, nil, { gain = 0.35, damp = 0.95 })
    end
end

function lib.bookBar(play, remember, synth, t0, song, b)
    defineShapes(synth)
    local section, j = song.barSection[b], song.barIndex[b]
    local chord = song.chords[b]
    local _, pcs = chordTones(song, chord)
    remember(t0, pcs)
    local h = human()
    local who = section.roles
    if who.piano then bookPiano(play, synth, t0, song, b, chord, h) end
    if who.cello then bookCello(play, synth, t0, song, b, chord, h, j, section.bars) end
    if who.flute then bookFlute(play, synth, t0, song, b, section, j, h) end
    if who.pad then bookPad(play, synth, t0, song, b, chord, h, j) end
    if who.drums then bookDrums(play, synth, t0, song, b, h) end
end

return lib
