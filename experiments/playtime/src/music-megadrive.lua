-- music-megadrive.lua
-- megadrive: a club groove in Mega Drive clothes (an original, after dreamengine's mdstudies cart, its study
-- 1 'CLUB'), groove first and no lead tune: the bass, the drums, the chord stabs and a pad carry it. 124 BPM,
-- straight, a minor key on the set's key (F minor in F), a chord every two bars:
--   i m9 | bVI maj9 | bVII sus | v m9   (as the cart voices them: Fm9 Dbmaj9 Ebsus Cm9 in F)
-- The parts, on src/synth.lua's Mega Drive patches (each picked by blind listening tests in the carts):
--   bass     mdBassGrit (the patch matcher's YM2612 bass) bouncing root / octave / fifth on a syncopated
--            16th line; in B the FM bass (mdBassFM) plays a legato line instead, sliding between its notes
--   keys     mdEpiano offbeat chord stabs (the and-of-1, the and-of-2, the 'e' of 3, the and-of-4)
--   strings  mdPad swelling in from the fifth bar, a held chord at each change
--   drums    DAC drums (src/dac-drums.lua): kick four on the floor, clap on 2 and 4, open hat on the off-beats,
--            closed hats on the 16ths between (only the last of each beat until the band is in), a clap roll
--            closing each section
-- Form: intro 4 (drums, bass), A 16 (two times round), B 8 (the legato FM bass, the pad all through), A 8,
-- outro 4 (thinning out, home rung on the last bar). Registered as loop = 'megadrive' (music-plan, music-parts).
local theory = require('src.music-theory')

local lib = {}

-- the chords, as offsets from the tonic (the cart's voicings in F minor: tonic F3 = 53): the bass's root
-- (an octave under), the five-note voicing (the stabs play it an octave up, the pad its lower four).
-- [1], [2]: degree and quality (src/music-styles.lua's names), as the other styles' song.chords
lib.CHORDS = {
    i = { 0, 'm9', bass = 0, voicing = { 0, 3, 7, 10, 14 } },       -- Fm9: F Ab C Eb G
    bVI = { 8, 'maj9', bass = -4, voicing = { -4, 0, 3, 7, 10 } },  -- Dbmaj9: Db F Ab C Eb
    bVII = { 10, 'sus', bass = -2, voicing = { -2, 3, 5, 10, 12 } }, -- Ebsus: Eb Ab Bb Eb F
    v = { 7, 'm9', bass = -5, voicing = { -5, -2, 2, 5, 9 } },      -- Cm9: C Eb G Bb D
}
local C = lib.CHORDS
lib.PROGS = { A = { C.i, C.bVI, C.bVII, C.v }, B = { C.bVI, C.bVII, C.i, C.v } }

-- the grit bass's bar, per 16th: 1 root, 2 octave, 3 fifth (the cart's CLUB line)
lib.BOUNCE = { 1, 0, 0, 2, 0, 0, 1, 0, 1, 0, 2, 0, 3, 0, 1, 0 }
-- B's legato line over a chord's two bars: { 16th, semitones over the root, length in 16ths, slides in }
lib.LEGATO = {
    { 0, 0, 6 }, { 6, 12, 4, true }, { 10, 7, 2, true }, { 12, 0, 4 },
    { 16, 0, 3 }, { 19, 12, 3, true }, { 22, 7, 4, true }, { 26, 0, 4 },
}
lib.STABS = { 2, 6, 11, 14 } -- the and-of-1, and-of-2, the 'e' of 3, the and-of-4

lib.FORM = {
    { 'intro', 4, { drums = true, bass = true } },
    { 'A', 16, { drums = true, bass = true, keys = true, pad = 4 } }, -- pad = the bar it comes in from
    { 'B', 8, { drums = true, legato = true, keys = true, pad = 0 } },
    { 'A', 8, { drums = true, bass = true, keys = true, pad = 0 } },
    { 'outro', 4, { drums = true, bass = true, pad = 0, ending = true } },
}

-- the tonic in F3's neighbourhood (E3..Eb4 the cart's register): F 53, Bb 58, Eb 51, Ab 56
local function tonicOf(song) return 53 + (song.key - 5 + 6) % 12 - 6 end

function lib.plan(song, _style, addSections)
    local list = {}
    for _, entry in ipairs(lib.FORM) do
        local prog = lib.PROGS[entry[1]] or lib.PROGS.A
        local chordOf = entry[1] == 'outro' and function() return C.i end
            or function(j) return prog[math.floor(j / 2) % 4 + 1] end
        list[#list + 1] = { entry[1], entry[2], chordOf, entry[3] }
    end
    addSections(song, list)
end

local function bookDrums(play, synth, song, t0, section, j, band)
    local last = j == section.bars - 1 -- a section's last bar: a clap roll into the next
    local ending = section.roles.ending
    for s = 0, 15 do
        local t = theory.stepTime(song, t0, s)
        if s % 4 == 0 and not (ending and last and s > 0) then play(synth, 'drums', 'mdKick', t, 60, 7, 400, s) end
        if not (ending and last) then
            if (s == 4 or s == 12) and section.kind ~= 'intro' then play(synth, 'drums', 'mdClap', t, 60, 6, 300, s) end
            if s % 4 == 2 and not (last and s == 14) then play(synth, 'drums', 'mdHatOpen', t, 60, 5, 400, s) end
            if s % 2 == 1 and (band or s % 4 == 3) then play(synth, 'drums', 'mdHatClosed', t, 60, 4, 80, s) end
            if last and not ending and s >= 13 then play(synth, 'drums', 'mdClap', t, 60, s - 9, 300, s) end
        end
    end
end

-- the grit bass's bouncing bar (the outro: only the roots, the last bar one long note)
local function bookBounce(play, synth, song, t0, section, j, root)
    local ending = section.roles.ending
    for s = 0, 15 do
        local kind = lib.BOUNCE[s + 1]
        if ending then kind = (s == 0 or (s == 6 and j < section.bars - 1)) and 1 or 0 end
        if kind > 0 then
            local midi = root + (kind == 2 and 12 or kind == 3 and 7 or 0)
            local dur = (ending and j == section.bars - 1) and 1200 or theory.lengthMs(song, s, 2) - 20
            play(synth, 'bass', 'mdBassGrit', theory.stepTime(song, t0, s), midi, 6, dur, s)
        end
    end
end

-- B's legato FM bass: the notes of the chord's two bars that start in this one, each held into the next
-- when that one slides in (the engine glides only while the key is still down)
local function bookLegato(play, synth, song, t0, j, root)
    local half = (j % 2) * 16
    for k, n in ipairs(lib.LEGATO) do
        local s = n[1] - half
        if s >= 0 and s < 16 then
            local nextNote = lib.LEGATO[k + 1]
            local dur = theory.lengthMs(song, s, n[3]) + (nextNote and nextNote[4] and 30 or -20)
            play(synth, 'bass', 'mdBassFM', theory.stepTime(song, t0, s), root + n[2], 6, dur, s, n[4] == true)
        end
    end
end

function lib.bookBar(play, remember, synth, t0, song, b)
    local section, j, chord = song.barSection[b], song.barIndex[b], song.chords[b]
    local roles = section.roles
    local tonic = tonicOf(song)
    local pcs = { (tonic + chord.bass) % 12 }
    for _, d in ipairs(chord.voicing) do pcs[#pcs + 1] = (tonic + d) % 12 end
    remember(t0, pcs) -- impacts play along in the chord
    local band = require('src.music-parts').bandPlays()
    local root = tonic - 12 + chord.bass
    if roles.drums then bookDrums(play, synth, song, t0, section, j, band) end
    if roles.bass then bookBounce(play, synth, song, t0, section, j, root) end
    if roles.legato then bookLegato(play, synth, song, t0, j, root) end
    if roles.keys then
        for _, s in ipairs(lib.STABS) do
            for _, d in ipairs(chord.voicing) do
                play(synth, 'keys', 'mdEpiano', theory.stepTime(song, t0, s), tonic + d + 12, 5,
                     theory.lengthMs(song, s, 2), s)
            end
        end
    end
    -- the pad: at each chord change from its bar on, held to the next (the outro: once, to the end)
    local padFrom = roles.pad
    if padFrom and j >= padFrom and j % 2 == 0 and not (roles.ending and j > 0) then
        local bars = roles.ending and section.bars or 2
        for k = 1, 4 do
            play(synth, 'strings', 'mdPad', t0, tonic + chord.voicing[k], 4, bars * song.barLength * 1000 - 60, 0)
        end
    end
    if roles.ending and j == section.bars - 1 then -- home, rung once
        for _, d in ipairs(chord.voicing) do play(synth, 'keys', 'mdEpiano', t0, tonic + d + 12, 5, 1500, 0) end
    end
end

return lib
