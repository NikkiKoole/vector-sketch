-- music-upright.lua
-- The upright style: a slow jazz blues where the upright bass is the voice, played by two hands the way
-- dreamengine's basshand.c plays it (2026-11-04, Nikki: "make one using upright bass"). Every pluck is a
-- booked note with its own force (gain), where the finger plucks (a harmonics offset: nearer the bridge is
-- brighter) and how bright a hard pluck is (timbre); the left hand decides how long it rings (lifted early or
-- held into the next, an open string rings on); some notes slide in from a semitone or two under (a pluck,
-- then a booked note gliding the same mono voice up: a string bends up cleanly); ghosts (a dead note, damp 1,
-- on the same slot: it stops the ringing one) and rakes between the beats; and under every pluck a THUMP,
-- the finger and the body knocked, varying with the hand. Brushes (the parlour style's) and a felt piano
-- comping sparse rootless shells.
-- The form: an intro (the turnaround), a chorus in two (half notes), two walking, one for the bass (more
-- slides and ghosts, the piano laying out), a last walking chorus, a ii V I ending on a ringing root.
-- The music panel's 'humanize' row plays the same notes plainly: on the beat, one force, one length, no
-- slides, ghosts or rakes, the same thump every time. Read per bar.
-- Registered as loop = 'upright' in music-plan's LOOP_PLANS and music-parts' LOOP_BARS (as music-jam.lua).
local state = require('src.state')
local theory = require('src.music-theory')
local parlour = require('src.music-parlour')
local stream, stepTime, lengthMs, voiceChord, humanize =
    theory.stream, theory.stepTime, theory.lengthMs, theory.voiceChord, theory.humanize

local lib = {}

-- the 12-bar blues (degree, quality); the last four bars' turnaround is the intro
lib.BLUES = {
    { 0, '7' }, { 5, '7' }, { 0, '7' }, { 0, '7' },
    { 5, '7' }, { 5, '7' }, { 0, '7' }, { 9, '7' },
    { 2, 'm7' }, { 7, '7' }, { 0, '7' }, { 7, '7' },
}
lib.INTRO = { { 2, 'm7' }, { 7, '7' }, { 0, '7' }, { 7, '7' } }
lib.OUTRO = { { 2, 'm7' }, { 7, '7' }, { 0, '7' }, { 0, '7' } }
-- the chord-scales the line walks in (semitones over the root) and the piano's rootless shells
lib.SCALES = { ['7'] = { 0, 2, 4, 5, 7, 9, 10 }, m7 = { 0, 2, 3, 5, 7, 9, 10 } }
lib.TONES = { ['7'] = { 0, 4, 7, 10 }, m7 = { 0, 3, 7, 10 } }
lib.SHELLS = { ['7'] = { 4, 10, 14 }, m7 = { 3, 10, 14 } }
local LO, HI = 28, 50                  -- E1 .. D3
local OPEN = { [28] = true, [33] = true, [38] = true, [43] = true } -- E A D G: nothing stops them

-- feel: two (half notes) or walk (quarters); feature = the bass's chorus: more slides and ghosts,
-- the piano out of the way; drums from the first chorus on
lib.FORM = {
    { 'intro', lib.INTRO, { feel = 'two', piano = true } },
    { 'A', lib.BLUES, { feel = 'two', piano = true, drums = true } },
    { 'A', lib.BLUES, { feel = 'walk', piano = true, drums = true } },
    { 'B', lib.BLUES, { feel = 'walk', feature = true, drums = true } },
    { 'A', lib.BLUES, { feel = 'walk', piano = true, drums = true } },
    { 'outro', lib.OUTRO, { feel = 'two', piano = true, drums = true, last = true } },
}

local function human() return state.musicSettings.humanize ~= false end
local function r1() return love.math.random() * 2 - 1 end
-- a slow wander, the same for the same time (the cart's noise drift)
local function drift(t, k) return math.sin(t * k * 6.1 + 1.3) * 0.6 + math.sin(t * k * 2.3 + 4.1) * 0.4 end

-- the octave of pitch class pc nearest to midi, inside the bass's range
local function nearest(pc, midi)
    local best
    for m = LO, HI do
        if m % 12 == pc and (not best or math.abs(m - midi) < math.abs(best - midi)) then best = m end
    end
    return best
end

---------------------------------------------------------------- the line, planned per song

-- four quarter notes over each bar: the root (or its octave nearest the last note) on 1, two steps of
-- the chord-scale toward the next root, an approach on 4 (a half step under or over it, or its fifth);
-- in two: the root on 1 and the approach on 3
local function planLine(song, rnd)
    local line, prev = {}, 36
    for b = 1, song.bars do
        local chord, nextChord = song.chords[b], song.chords[b + 1]
        local root = (song.key + chord[1]) % 12
        local one = nearest(root, prev)
        if rnd(100) < 25 and one + 12 <= HI - 4 and one < 34 then one = one + 12 end -- up an octave now and then
        local target = nextChord and nearest((song.key + nextChord[1]) % 12, one) or one
        local roll, four = rnd(100), one -- the last bar: no next root, stay
        if nextChord then
            if roll < 55 then four = target + (rnd(2) == 0 and -1 or 1)
            elseif roll < 75 then four = target + 7 <= HI and target + 7 or target - 5
            else four = target + (target > one and -2 or 2) end
        end
        four = math.max(LO, math.min(HI, four))
        local scale = {}
        for _, s in ipairs(lib.SCALES[chord[2]]) do scale[#scale + 1] = (root + s) % 12 end
        local function inScale(m) for _, pc in ipairs(scale) do if pc == m % 12 then return true end end end
        -- a half step (or a b9, a maj7) from a note of the piano's shell over this chord bites: walk around it
        local function rubsShell(m)
            for _, s in ipairs(lib.SHELLS[chord[2]]) do
                local d = (m - root - s) % 12
                if d == 1 or d == 11 then return true end
            end
        end
        local function walkTo(from, aim, strong)
            local best, bestCost
            for m = math.max(LO, from - 5), math.min(HI, from + 5) do
                if m ~= from and inScale(m) then
                    local isTone = false
                    for _, tone in ipairs(lib.TONES[chord[2]]) do
                        if (root + tone) % 12 == m % 12 then isTone = true end
                    end
                    local cost = math.abs(m - aim) + (strong and not isTone and 1.5 or 0) + rnd() * 0.8
                        + (rubsShell(m) and 3 or 0)
                    if not bestCost or cost < bestCost then best, bestCost = m, cost end
                end
            end
            return best or from
        end
        local gap = four - one
        local two, three
        if math.abs(gap) <= 2 then -- the next root is close: up to the chord, back down
            two = walkTo(one, one + 4, true)
            three = walkTo(two, (two + four) / 2, false)
        else
            two = walkTo(one, one + gap / 3, true)
            three = walkTo(two, one + gap * 2 / 3, false)
        end
        line[b] = { one, two, three, four }
        prev = four
    end
    return line
end

function lib.plan(song, _style, addSections)
    local list = {}
    for _, entry in ipairs(lib.FORM) do
        local prog = entry[2]
        list[#list + 1] = { entry[1], #prog, function(j) return prog[j + 1] end, entry[3] }
    end
    addSections(song, list)
    song.upright = { line = planLine(song, stream(song.seed, 100)) }
end

---------------------------------------------------------------- the bass

-- one pluck at t (a quarter's or a half's worth: beats), in basshand's hands
local function pluck(play, synth, song, t, midi, beatIndex, beats, h, feature, nextMidi)
    local beatS = song.beat
    local open = OPEN[midi]
    if not h then
        play(synth, 'bass', 'hUpright', t, midi, 7, beatS * beats * 0.92 * 1000, beatIndex * 4, nil, nil,
             { gain = 0.8 })
        play(synth, 'bass', 'hThump', t, 38, 7, 90, beatIndex * 4, nil, nil, { gain = 0.68 })
        return
    end
    -- time: a hair ahead of the beat, drifting
    local tt = t + (-0.006 + drift(t, 0.2) * 0.007 + r1() * 0.003)
    -- force: one leans in, two and four a touch more than three
    local force = (beatIndex == 0 and 0.92 or beatIndex == 2 and 0.74 or 0.82) + r1() * 0.06 + drift(t, 0.15) * 0.05
    -- touch: where the finger plucks wanders, harder is brighter, the left hand decides the length
    local spot = drift(t, 0.4) * 0.08
    local bright = (force - 0.8) * 0.4 + (open and 0.05 or 0)
    local gateFrac = open and 1.4 or 0.55 + 0.5 * love.math.random()
    local gate = beatS * beats * gateFrac * 1000
    local opts = { gain = force, harmonics = spot, timbre = bright }
    -- a slide in from under (never on an open string: there's no finger to slide)
    local slideOdds = feature and 0.45 or 0.3
    if not open and midi > 30 and love.math.random() < slideOdds then
        local from = love.math.random() < 0.4 and 2 or 1
        play(synth, 'bass', 'hUpright', tt, midi - from, 7, 40, beatIndex * 4, nil, nil, opts)
        play(synth, 'bass', 'hUpright', tt + 0.012, midi, 7, gate, beatIndex * 4, nil, nil,
             { gain = force, harmonics = spot, timbre = bright, glide = math.floor(60 + 60 * love.math.random()) })
    else
        play(synth, 'bass', 'hUpright', tt, midi, 7, gate, beatIndex * 4, nil, nil, opts)
    end
    -- the thump follows the hand: force squared, sometimes a light finger hardly knocks, its own spot and length
    local tg = force * force * 1.05 * (0.75 + 0.25 * love.math.random())
    if love.math.random() < 0.15 then tg = tg * 0.35 end
    local tm = 38 + math.floor((midi - 36) / 6) -- the body sits lower under low notes, and now and then off by one
    if love.math.random() < 0.3 then tm = tm + (love.math.random() < 0.5 and -1 or 1) end
    play(synth, 'bass', 'hThump', tt, tm, 7, 60 + love.math.random(70), beatIndex * 4, nil, nil,
         { gain = tg, timbre = spot + r1() * 0.15, morph = r1() * 0.15, harmonics = r1() * 0.1 })
    -- between the beats, on the swung and: a ghost (a dead note: it stops the one ringing) or a rake
    local ghostOdds = feature and 0.35 or 0.22
    if nextMidi and love.math.random() < ghostOdds then
        -- the swung and of this pluck's last beat
        local ta = t + (beats - 1) * beatS + stepTime(song, 0, 2) + r1() * 0.004
        if love.math.random() < 0.6 then
            play(synth, 'bass', 'hUpright', ta, nextMidi, 7, 40, beatIndex * 4 + 2, nil, nil,
                 { gain = 0.35 + 0.15 * love.math.random(), damp = 1 })
        else
            local rake = nextMidi + (love.math.random() < 0.5 and 1 or -1)
            play(synth, 'bass', 'hUpright', ta, rake, 7, 90, beatIndex * 4 + 2, nil, nil,
                 { gain = 0.45, timbre = -0.1 })
        end
    end
end

local function bookBass(play, synth, t0, song, b, roles, h)
    local line = song.upright.line[b]
    local nextLine = song.upright.line[b + 1]
    if roles.last and song.barIndex[b] >= 2 then -- the ending: the root rings two bars
        if song.barIndex[b] == 2 then
            local root = nearest((song.key + song.chords[b][1]) % 12, 31)
            if h then
                play(synth, 'bass', 'hUpright', t0 - 0.006, root, 7, song.barLength * 2000, 0, nil, nil,
                     { gain = 0.95, timbre = 0.05 })
                play(synth, 'bass', 'hThump', t0 - 0.006, 37, 7, 120, 0, nil, nil, { gain = 0.9 })
            else
                play(synth, 'bass', 'hUpright', t0, root, 7, song.barLength * 2000, 0, nil, nil, { gain = 0.8 })
                play(synth, 'bass', 'hThump', t0, 38, 7, 90, 0, nil, nil, { gain = 0.68 })
            end
        end
        return
    end
    if roles.feel == 'two' then
        pluck(play, synth, song, t0, line[1], 0, 2, h, roles.feature, line[4])
        pluck(play, synth, song, stepTime(song, t0, 8), line[4], 2, 2, h, roles.feature, nextLine and nextLine[1])
    else
        for q = 1, 4 do
            local nextMidi = line[q + 1] or (nextLine and nextLine[1])
            pluck(play, synth, song, stepTime(song, t0, (q - 1) * 4), line[q], q - 1, 1, h, roles.feature, nextMidi)
        end
    end
end

---------------------------------------------------------------- the piano

-- rootless shells, a few hits a bar: the Charleston (1 and the and-of-2), 2 and 4, or one held on 1.
-- In the bass's chorus it only touches beat 1 every other bar. Humanized: spread, uneven, short keys.
local COMPS = { { 0, 6 }, { 4, 12 }, { 0 }, { 6, 14 } }
local function bookPiano(play, synth, t0, song, b, roles, h)
    local chord = song.chords[b]
    local root = (song.key + chord[1]) % 12
    -- (a 3rd next to a 9th low down is a cluster voiceChord refuses: voiced from 55; else the plain shape)
    local shell = lib.SHELLS[chord[2]]
    song.upright.voicing = voiceChord(root, shell, 55, 72, song.upright.voicing)
        or { 55 + (root + shell[1] - 55) % 12, 55 + (root + shell[1] - 55) % 12 + (shell[2] - shell[1]),
             55 + (root + shell[1] - 55) % 12 + (shell[3] - shell[1]) }
    local hits
    if roles.feature then hits = (b % 2 == 1) and { 0 } or {}
    else hits = COMPS[stream(song.seed, 500 + b)(#COMPS) + 1] end
    synth.laneAt('hPiano', t0, 'damper', 0, 0) -- no pedal here (the slot may have had parlour's)
    -- the bass notes ringing under the bar, as {from, to, midi} in steps: a quarter (a half in two) and a
    -- little more; the walk's last note is its approach into the next chord, a half step from it on purpose
    local line, under = song.upright.line[b], {}
    if roles.feel == 'two' then
        under = { { 0, 8.5, line[1] }, { 8, 16.5, line[4] } }
    else
        for q = 1, 4 do under[#under + 1] = { (q - 1) * 4, (q - 1) * 4 + 4.5, line[q] } end
    end
    for _, s in ipairs(hits) do
        local keySteps = s == 0 and #hits == 1 and 8 or 2
        local keyMs = lengthMs(song, s, keySteps) * 0.8
        -- the release rings about two steps more: a key a half step from a bass note under it lets go
        -- (the shell plays on with two)
        local voicing = {}
        for _, midi in ipairs(song.upright.voicing) do
            local bites = false
            for _, u in ipairs(under) do
                local d = (midi - u[3]) % 12
                if u[1] < s + keySteps + 2 and u[2] > s and (d == 1 or d == 11) then bites = true end
            end
            if not bites then voicing[#voicing + 1] = midi end
        end
        for k, midi in ipairs(voicing) do
            if h then
                local t = stepTime(song, t0, s) + (k - 1) * (0.008 + 0.006 * love.math.random()) + humanize(0.006)
                play(synth, 'keys', 'hPiano', t, midi, 6, keyMs, s, nil, nil,
                     { gain = 0.42 + (k == #voicing and 0.06 or 0) + r1() * 0.05, release = 320 })
            else
                play(synth, 'keys', 'hPiano', stepTime(song, t0, s), midi, 4, keyMs, s)
            end
        end
    end
end

function lib.bookBar(play, remember, synth, t0, song, b)
    local section = song.barSection[b]
    local chord = song.chords[b]
    local root = (song.key + chord[1]) % 12
    local pcs = {}
    for _, tone in ipairs(lib.TONES[chord[2]]) do pcs[#pcs + 1] = (root + tone) % 12 end
    remember(t0, pcs)
    local h = human()
    local roles = section.roles
    bookBass(play, synth, t0, song, b, roles, h)
    if roles.piano or roles.feature then bookPiano(play, synth, t0, song, b, roles, h) end
    if roles.drums and not (roles.last and song.barIndex[b] >= 3) then
        parlour.bookDrums(play, synth, t0, song, b, h)
    end
end

return lib
