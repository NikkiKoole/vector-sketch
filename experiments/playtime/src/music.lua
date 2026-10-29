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
-- plinky marimba riff, a bouncy bass, a kalimba tune), dumont (Domenique Dumont's dubby synth-pop:
-- funky minor vamps, a busy syncopated bass, a marimba riff, a steel-pan tune, claps with an echo),
-- supermarket (Mr. Lucky's ii7 - V11 vamp, staccato and bouncy, a marimba tune), herbs (MF DOOM's
-- Special Herbs: a dusty swung boom-bap loop, chopped Rhodes, a sub bass on the kick) and ballad.
-- style = 'set' plays lib.set as a live set: each song ends on home, takes a breath, and the next
-- one starts in a related key.
--
-- The arrangement follows the play: calm, the keys play alone and the left hand takes the bass;
-- busy (impacts call music.bump), the drums join where the form lets them (the upright too when
-- lib.upright is on). rhythmSection forces that on or off. lib.chordNotes lets sound effects play
-- in the current chord. Notes are booked ahead on the synth's audio clock, a bar at a time.
-- Driven by mipo-voice.update while synth impacts are on.

local state = require('src.state')

local lib = {}

-- The switches (the settings panel writes them) live on state, behind lib's metatable. A hot reload
-- (lume.hotswap) copies this chunk's functions onto the OLD module table, the one the panel writes
-- to, while those functions still read THIS chunk's table: a plain field set in the panel was never
-- seen (picking a style did nothing until the song ended) and a reload reset it. On state, every
-- copy of the module reads the same switch, and it survives a reload.
--   enabled
--   style          'set' (lib.set in turn), or one style: 'bossa', 'guaraldi', 'island', 'dumont',
--                  'supermarket', 'herbs', 'lofi', 'ballad'
--   rhythmSection  'auto' (joins when play gets busy), 'on' or 'off'
--   upright        the upright in the rhythm section; off: the left hand keeps the bass
--   melody         the tune on top
--   melodyPatch    force the tune's voice (rhodesLead, pianoLead, kalimba, ...); nil: the style's
state.musicSettings = state.musicSettings
    or { enabled = true, style = 'set', rhythmSection = 'auto', upright = false, melody = true }
local SETTINGS = { enabled = true, style = true, rhythmSection = true, upright = true, melody = true,
                   melodyPatch = true }
setmetatable(lib, {
    __index = function(_, k) if SETTINGS[k] then return state.musicSettings[k] end end,
    __newindex = function(t, k, v)
        if SETTINGS[k] then state.musicSettings[k] = v else rawset(t, k, v) end
    end,
})

lib.set = { 'bossa', 'guaraldi', 'island', 'dumont', 'supermarket', 'herbs', 'lofi', 'puppetmaker' }
lib.lookahead = 0.3          -- seconds of music booked ahead
lib.activityHalfLife = 8     -- seconds for the play level to halve
lib.bandJoins = 4            -- play level at which the rhythm section comes in...
lib.bandLeaves = 1.5         -- ...and below which it leaves again

lib.keys = { 5, 10, 3, 8 }   -- F, Bb, Eb, Ab: warm keys, a fourth apart, so the set walks between them
-- Chord qualities, as intervals over the root. Each style keeps to its own vocabulary, so the songs
-- don't all sound like the same jazz: the jazz (bossa, guaraldi) is rootless (the bass owns the root),
-- plain sevenths for supermarket and herbs, triads and their pop colours for island, quartal minor
-- for dumont. stack = true: voice it as written (a stacked shape), only moved by octaves.
lib.qualities = { maj9 = { 4, 7, 11, 14 }, m9 = { 3, 7, 10, 14 }, dom9 = { 4, 10, 14, 21 },
                  lydian = { 4, 11, 14, 18 },  -- maj9#11: third, seventh, ninth, raised fourth
                  maj69 = { 4, 7, 9, 14 },     -- the sixth and ninth: Guaraldi's sunny tonic
                  sus = { 5, 7, 10, 14 },      -- 9sus4 (V11): a dominant that floats instead of pulls
                  maj7 = { 4, 7, 11, 12 }, m7 = { 3, 7, 10, 12 }, dom7 = { 0, 4, 7, 10 },
                  maj = { 0, 4, 7 }, min = { 0, 3, 7 }, maj6 = { 0, 4, 7, 9 },
                  add9 = { 0, 7, 14, 16, stack = true }, sus2 = { 0, 2, 7 },
                  m11 = { 5, 10, 15, 19, stack = true }, -- So What: 11 b7 b3 5, fourths and a third
                  -- lofi's jazz on top of the rest: the dominant colours and the minor key's ii
                  n9 = { 4, 10, 14 }, b9 = { 4, 7, 10, 13 }, s9 = { 4, 7, 10, 15 },
                  m7b5 = { 3, 6, 10, 14 }, m6 = { 3, 7, 9, 14 } }

-- the forms, { section, bars }; songs grow no longer than this (a minute or so: a set keeps moving)
lib.forms = {
    { { 'intro', 2 }, { 'A', 8 }, { 'A', 8 }, { 'B', 8 }, { 'A', 8 }, { 'outro', 4 } }, -- AABA, the standard
    { { 'intro', 4 }, { 'A', 8 }, { 'B', 8 }, { 'A', 8 }, { 'B', 8 }, { 'outro', 4 } },
}

-- lofi city's forms (and a break: the keys holding, the drums out or on the rim): longer songs
lib.lofiForms = {
    { { 'intro', 4 }, { 'A', 8 }, { 'A', 8 }, { 'B', 8 }, { 'break', 4 }, { 'A', 8 }, { 'B', 8 }, { 'outro', 4 } },
    { { 'intro', 2 }, { 'A', 8 }, { 'B', 8 }, { 'A', 8 }, { 'break', 8 }, { 'B', 8 }, { 'A', 8 }, { 'outro', 4 } },
    { { 'intro', 4 }, { 'A', 16 }, { 'break', 4 }, { 'B', 8 }, { 'A', 16 }, { 'outro', 4 } },
}

-- Comps shared between styles by name (a style's comps = 'name'): how the chords are played,
-- kept apart from which chords, so another song can reuse the feel.
lib.comps = {
    -- the supermarket bounce (70s library music): short staccato stabs, the chick on 2 and 4 with
    -- a skip into it (the a-of-2, the and-of-1), a stab pushed a 16th early now and then
    bounce = {
        { { 4, 1, 4 }, { 7, 1, 3 }, { 12, 1, 4 }, { 20, 1, 4 }, { 23, 1, 3 }, { 28, 1, 4 } },
        { { 2, 1, 3 }, { 4, 1, 4 }, { 10, 1, 3 }, { 12, 1, 4 }, { 18, 1, 3 }, { 20, 1, 4 }, { 26, 2, 4 } },
        { { 0, 2, 4 }, { 6, 1, 3 }, { 12, 1, 4 }, { 15, 1, 3 }, { 20, 1, 4 }, { 24, 2, 4 }, { 30, 1, 3 } },
    },
    -- lofi: the chord held a whole bar, the Charleston (1 and the and-of-2, held), the pulse (1 and 3)
    jazzhop = {
        { { 0, 16, 4 }, { 16, 16, 4 } },
        { { 0, 3, 4 }, { 6, 10, 4 }, { 16, 3, 4 }, { 22, 10, 4 } },
        { { 0, 6, 4 }, { 8, 8, 4 }, { 16, 6, 4 }, { 24, 8, 4 } },
    },
}

-- Progressions are { degree from the key, quality } (A: each chord lasts the song's chordBars) or
-- { degree, quality, beats } (B). Comps are two-bar cells { step, length, vol } in 16ths (0..31).
lib.styles = {
    bossa = {
        bpm = 116, swing = 0.5, chordBars = { 2 }, lydianChance = 0.6, pushOdds = 15, sidestepOdds = 25,
        strumMs = 8, keys = 'rhodes', lead = 'rhodesLead', bass = 'bossa', drums = 'bossa', home = 'maj9',
        A = {
            { { 0, 'maj9' }, { 2, 'dom9' }, { 2, 'm9' }, { 7, 'dom9' } },   -- Imaj7 II7 iim7 V7 (Ipanema)
            { { 0, 'maj9' }, { 9, 'm9' }, { 2, 'm9' }, { 7, 'dom9' } },     -- I vi ii V
            { { 0, 'maj9' }, { 5, 'm9' }, { 0, 'maj9' }, { 10, 'dom9' } },  -- I ivm I bVII7, the dreamy one
            { { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' }, { 9, 'dom9' } },   -- ii V I VI7
        },
        B = {
            { { 5, 'maj9', 8 }, { 5, 'm9', 8 }, { 0, 'maj9', 8 }, { 9, 'm9', 8 } },     -- IV iv I vi, the sigh
            { { 2, 'm9', 8 }, { 7, 'dom9', 8 }, { 4, 'm9', 8 }, { 9, 'dom9', 8 } },     -- ii V iii VI7
            { { 8, 'maj9', 8 }, { 7, 'dom9', 8 }, { 0, 'maj9', 16 } },                  -- bVI V I
            { { 0, 'maj9', 8 }, { 1, 'maj9', 8 } },                                     -- the half-step float
        },
        -- the comp on the bossa clave and its cousins, short stabs
        comps = {
            { { 0, 3, 4 }, { 6, 3, 4 }, { 12, 3, 4 }, { 20, 3, 4 }, { 26, 3, 4 } },
            { { 0, 3, 4 }, { 6, 3, 4 }, { 14, 3, 4 }, { 20, 3, 4 }, { 24, 3, 4 } },
            { { 4, 3, 4 }, { 10, 3, 4 }, { 16, 3, 4 }, { 20, 3, 4 }, { 26, 3, 4 } },
        },
    },
    guaraldi = {
        bpm = 132, swing = 0.62, chordBars = { 1, 2 }, lydianChance = 0, pushOdds = 35, motifRepeat = 30,
        strumMs = 12, keys = 'piano', lead = 'pianoLead', bass = 'guaraldi', drums = 'brushes', home = 'maj69',
        A = {
            { { 0, 'maj69' }, { 5, 'dom9' } },                                -- I6/9 IV9, the rocking vamp
            { { 0, 'maj7' }, { 2, 'm7' }, { 4, 'm7' }, { 5, 'maj7' } },       -- I ii iii IV, stepping up
            { { 0, 'maj69' }, { 9, 'm9' }, { 2, 'm9' }, { 7, 'sus' } },       -- I vi ii V9sus
            { { 0, 'maj7' }, { 5, 'dom9' }, { 0, 'maj7' }, { 7, 'dom9' } },   -- I IV7 I V7, the bluesy one
        },
        B = {
            { { 5, 'maj7', 8 }, { 5, 'm9', 8 }, { 0, 'maj69', 8 }, { 9, 'm9', 4 }, { 7, 'dom9', 4 } }, -- IV iv I vi V
            { { 2, 'm9', 4 }, { 7, 'dom9', 4 }, { 4, 'm7', 4 }, { 9, 'dom9', 4 },
              { 2, 'm9', 4 }, { 7, 'sus', 4 }, { 0, 'maj69', 8 } },                         -- ii V iii VI ii V I
            { { 5, 'dom9', 8 }, { 0, 'maj69', 8 }, { 5, 'dom9', 8 }, { 7, 'dom9', 8 } },               -- the blues turn
        },
        -- Charleston, the anticipations (the and-of-2 and the and-of-4), a held chord with a lift
        comps = {
            { { 0, 3, 4 }, { 6, 4, 3 }, { 16, 3, 4 }, { 22, 4, 3 } },
            { { 6, 2, 3 }, { 14, 4, 4 }, { 22, 2, 3 }, { 30, 2, 4 } },
            { { 0, 8, 4 }, { 14, 2, 3 }, { 16, 8, 4 }, { 26, 4, 3 } },
        },
    },
    -- Animal Crossing's hourly music: one-bar chords in short loops, the Rhodes only holding, a
    -- marimba riff (the song's own, lib.riffs) carrying the groove, a bouncy root and fifth, a
    -- kalimba tune, a soft kick, a rim on 2 and 4 and a shaker. Cozy, with one odd chord per loop.
    island = {
        bpm = 104, swing = 0.56, chordBars = { 1 }, lydianChance = 0, pushOdds = 0, motifRepeat = 30,
        strumMs = 10, keys = 'rhodes', lead = 'kalimba', bass = 'bounce', drums = 'island', home = 'maj6',
        riff = 'marimba',
        -- plain triads, sixths, sus2 and add9: a toy's chords, no jazz
        A = {
            { { 0, 'maj6' }, { 4, 'min' }, { 5, 'maj' }, { 5, 'min' } },   -- I6 iii IV iv, the wistful one
            { { 0, 'add9' }, { 10, 'maj' }, { 5, 'add9' }, { 0, 'maj' } },  -- I bVII IV I
            { { 0, 'maj6' }, { 2, 'maj' }, { 5, 'maj6' }, { 0, 'sus2' } },  -- I II IV I, a bit bright
            { { 0, 'maj' }, { 9, 'min' }, { 5, 'add9' }, { 7, 'maj' } },    -- I vi IV V
        },
        B = {
            { { 5, 'maj6', 4 }, { 4, 'min', 4 }, { 2, 'min', 4 }, { 7, 'maj', 4 } },  -- IV iii ii V
            { { 9, 'min', 4 }, { 8, 'maj', 4 }, { 5, 'maj', 4 }, { 7, 'sus2', 4 } },  -- vi bVI IV V, the odd one
        },
        comps = { { { 0, 14, 3 }, { 16, 14, 3 } } }, -- the Rhodes holds, quietly: the riff is the comp
    },
    -- Domenique Dumont (Comme Ca, 2015): funky, pastel synth-pop on a homemade drum machine, not
    -- slow. Two-chord dorian vamps (the IV is major), a busy syncopated bass with ghost notes and
    -- octave pops, a marimba riff, the tune on a steel pan in short notes, 16th-note synth stabs
    -- with a dotted-8th echo kept inside the chord, a flammed clap, 16th hats, congas.
    dumont = {
        bpm = 116, swing = 0.56, chordBars = { 1, 2 }, lydianChance = 0, pushOdds = 0, motifRepeat = 15,
        mode = 'dorian', strumMs = 4, keys = 'stab', lead = 'steelpan', bass = 'funk', bassPatch = 'dubBass',
        bassLo = 36, drums = 'machine', home = 'm11', riff = 'marimba', riffs = 'dumont', echo = { keys = true },
        staccato = 3,
        -- quartal minor (the So What shape) against open add9 and sus chords: pastel, not jazz
        A = {
            { { 0, 'm11' }, { 5, 'add9' }, { 0, 'm11' }, { 5, 'add9' } },  -- i11 IV, the dorian vamp
            { { 0, 'm11' }, { 10, 'sus2' }, { 8, 'add9' }, { 10, 'sus2' } }, -- i bVII bVI bVII, Mediterranean
            { { 0, 'm11' }, { 5, 'add9' }, { 10, 'sus' }, { 5, 'add9' } },  -- i IV bVIIsus IV
            { { 0, 'm11' }, { 8, 'add9' }, { 0, 'm11' }, { 10, 'sus' } },   -- i bVI i bVII9sus
        },
        B = {
            { { 8, 'add9', 8 }, { 10, 'sus2', 8 }, { 0, 'm11', 16 } },                    -- bVI bVII i, the lift
            { { 5, 'add9', 8 }, { 10, 'sus2', 8 }, { 8, 'add9', 8 }, { 10, 'sus', 8 } },  -- IV bVII bVI bVII
        },
        -- funk stabs on the 16ths around the beat; the echo fills the holes
        comps = {
            { { 3, 1, 3 }, { 6, 1, 4 }, { 14, 1, 4 }, { 19, 1, 3 }, { 22, 1, 4 }, { 27, 1, 3 }, { 30, 1, 4 } },
            { { 2, 1, 4 }, { 7, 1, 3 }, { 10, 1, 4 }, { 18, 1, 4 }, { 23, 1, 3 }, { 26, 2, 4 } },
            { { 0, 1, 4 }, { 6, 1, 4 }, { 11, 1, 3 }, { 14, 1, 4 }, { 22, 1, 4 }, { 27, 1, 3 }, { 30, 1, 3 } },
        },
    },
    -- supermarket music after Karl Jenkins' Mr. Lucky (Sounds for the Supermarket): the ii7 - V11
    -- vamp (V11 = the sus quality) with a secondary dominant now and then, straight and bouncy,
    -- staccato Rhodes stabs (lib.comps.bounce), the left hand bouncing root and fifth, a marimba
    -- tune (vibes-ish) that runs by step over a wide range in short syncopated notes. Its own tune:
    -- the chords and the feel are borrowed, the melody is not.
    supermarket = {
        bpm = 89, swing = 0.5, chordBars = { 1 }, lydianChance = 0, pushOdds = 20, sidestepOdds = 15,
        motifRepeat = 10, strumMs = 4, keys = 'rhodes', lead = 'marimba', bass = 'bounce',
        drums = 'lounge', home = 'maj7', comps = 'bounce',
        range = { 62, 88 }, staccato = 2,
        -- plain sevenths, the root in the stab, and the V11: no ninths
        A = {
            { { 2, 'm7' }, { 7, 'sus' }, { 2, 'm7' }, { 7, 'sus' } },     -- ii7 V11, the vamp
            { { 2, 'm7' }, { 7, 'sus' }, { 4, 'm7' }, { 9, 'dom7' } },    -- ii V11 iii VI7, back into ii
            { { 2, 'm7' }, { 7, 'sus' }, { 2, 'm7' }, { 2, 'dom7' } },    -- ii V11 ii II7, a cheeky lift
        },
        B = {
            { { 5, 'maj7', 4 }, { 4, 'm7', 4 }, { 2, 'm7', 4 }, { 7, 'sus', 4 } },   -- IV iii ii V11
            { { 0, 'maj7', 4 }, { 9, 'dom7', 4 }, { 2, 'm7', 4 }, { 7, 'sus', 4 } }, -- I VI7 ii V11
        },
    },
    -- MF DOOM's Special Herbs: a dusty soul-jazz loop on an MPC. Minor loops of one or two bars a
    -- chord that just keep going (B is the switch-up), the Rhodes chopped like a sample (held
    -- chunks retriggered on the 16ths), a sub bass on the kick, a hard kick and a snare on 2 and 4
    -- laid back, swung hats, a sparse piano phrase that loops, vinyl crackle.
    herbs = {
        bpm = 88, swing = 0.6, chordBars = { 1, 2 }, lydianChance = 0, pushOdds = 0, motifRepeat = 40,
        mode = 'dorian', strumMs = 3, keys = 'rhodes', lead = 'pianoLead', bass = 'boom', bassPatch = 'dubBass',
        bassLo = 33, drums = 'boombap', home = 'm7',
        -- plain minor sevenths, like the sample: dark and simple, no ninths
        A = {
            { { 0, 'm7' }, { 5, 'm7' } },                                    -- i7 iv7, the dark soul loop
            { { 0, 'm7' }, { 10, 'maj' }, { 8, 'maj7' }, { 7, 'm7' } },      -- i bVII bVI v, walking down
            { { 0, 'm7' }, { 3, 'maj7' } },                                  -- i bIII
            { { 0, 'm7' }, { 8, 'maj7' }, { 0, 'm7' }, { 10, 'maj' } },      -- i bVI i bVII
        },
        B = {
            { { 8, 'maj7', 8 }, { 7, 'm7', 8 }, { 0, 'm7', 16 } },   -- bVI v i, the switch-up
            { { 5, 'm7', 16 }, { 0, 'm7', 16 } },                    -- iv i, slower
        },
        -- the chop: held chunks of the chord, retriggered a 16th or a dotted 8th later
        comps = {
            { { 0, 6, 4 }, { 7, 3, 3 }, { 10, 4, 4 }, { 16, 6, 4 }, { 23, 3, 3 }, { 26, 6, 3 } },
            { { 0, 3, 4 }, { 3, 3, 3 }, { 8, 6, 4 }, { 16, 3, 4 }, { 19, 3, 3 }, { 24, 6, 4 } },
            { { 0, 10, 4 }, { 10, 2, 3 }, { 14, 2, 3 }, { 16, 10, 4 }, { 26, 6, 3 } },
        },
    },
    -- lofi city (dreamengine's loficity.c, its jazzhop): our planner, its sound. A major or a minor
    -- key, 68-88 bpm with the 16ths swung, the standard lofi moves (ii-V-I, the backdoor iv, the
    -- minor ii-V), the Rhodes holding, Charleston-ing or pulsing, pushing the next chord half the
    -- time, a boom-bap groove from its grids with a lazy snare, a round bass on the kicks with an
    -- approach note, a vibes tune in some songs, a break, the tone opening in the intro, vinyl.
    lofi = {
        bpm = { 68, 88 }, swing = { 0.54, 0.62 }, swing16 = true, snareLagMs = { 8, 18 },
        chordBars = { 1, 2 }, lydianChance = 0, pushOdds = 50, minorChance = 55,
        strumMs = 18, keys = 'lofiKeys', lead = 'vibes', leadChance = 60, bass = 'lofi',
        bassPatch = 'roundBass', bassLo = 33, drums = 'jazzhop', home = 'maj9', homeMinor = 'm9',
        comps = 'jazzhop', compWeights = { { 0.3, 1.0 }, { 0.1, 0.8 }, { 0.1, 0.6 } }, lightOdds = 0,
        holdChanges = true, forms = 'lofi', B = 'A', range = { 67, 84 }, tone = { 5500, 9000 },
        epLp = { 2400, 4500 }, vinyl = true,
        A = {
            { { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' }, { 0, 'maj9' } },  -- ii V13 I
            { { 0, 'maj9' }, { 9, 'm9' }, { 2, 'm9' }, { 7, 'dom9' } },    -- I vi ii V13
            { { 5, 'maj9' }, { 4, 'm9' }, { 2, 'm9' }, { 0, 'maj9' } },    -- IV iii ii I, walking down
            { { 5, 'maj9' }, { 5, 'm9' }, { 4, 'm9' }, { 9, 'm9' } },      -- IV iv iii vi
            { { 5, 'maj9' }, { 4, 'b9' }, { 9, 'm9' }, { 7, 'm9', 2 }, { 0, 'dom9', 2 } }, -- IV III7b9 vi, v I13
            { { 0, 'maj9' }, { 0, 'maj9' }, { 5, 'maj9' }, { 5, 'maj9' } },  -- I IV, the two-chord loop
            { { 0, 'maj9' }, { 4, 'm9' }, { 5, 'maj9' }, { 5, 'm6' } },    -- I iii IV iv6
        },
        Aminor = {
            { { 0, 'm9' }, { 5, 'm9' }, { 10, 'dom9' }, { 3, 'maj9' } },   -- i iv bVII13 bIII
            { { 0, 'm9' }, { 0, 'm9' }, { 5, 'n9' }, { 5, 'n9' } },        -- i IV9, dorian
            { { 8, 'maj9' }, { 10, 'maj69' }, { 0, 'm9' }, { 0, 'm9' } },  -- bVI bVII i
            { { 2, 'm7b5' }, { 7, 'b9' }, { 0, 'm9' }, { 0, 'm9' } },      -- the minor ii-V-i
            { { 0, 'm9' }, { 3, 'maj9' }, { 8, 'maj9' }, { 7, 's9' } },    -- i bIII bVI V7#9
            { { 0, 'm9' }, { 8, 'maj9' }, { 5, 'm9' }, { 7, 'sus', 2 }, { 7, 'b9', 2 } }, -- i bVI iv Vsus V7b9
        },
    },
    -- Puppetmaker 2's band (docs/PUPPETMAKER-SOUND.md 1a): no form, no chords, a dry swung CR-78
    -- hand-percussion loop at 60 bpm in 16ths where every hit has its chance, and one rolled Rhodes
    -- chord floating in at a chromatic pitch now and then. Dense when play is busy (PM2's crowd
    -- outside), sparse when calm (its editor, one Mipo). Pattern: lib.puppetmaker.
    puppetmaker = { loop = true, bpm = 60, swing = 0.52, swing16 = true, bars = 16 },
    ballad = {
        bpm = 76, swing = 0.5, chordBars = { 1, 2 }, lydianChance = 0.6, pushOdds = 0,
        strumMs = 70, keys = 'rhodes', lead = 'rhodesLead', bass = 'hold', drums = nil, home = 'maj9',
        A = {
            { { 0, 'maj9' }, { 9, 'm9' } },                                 -- Imaj9 vi9
            { { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' }, { 0, 'maj9' } },   -- ii V I
            { { 0, 'maj9' }, { 5, 'm7' }, { 8, 'dom9' }, { 0, 'maj9' } },   -- the jazzy loop
        },
        B = {
            { { 5, 'maj9', 4 }, { 5, 'm9', 4 }, { 0, 'maj9', 4 }, { 9, 'm9', 4 } },     -- IV iv I vi, the sigh
            { { 9, 'm9', 4 }, { 2, 'm9', 4 }, { 7, 'dom9', 4 }, { 0, 'maj9', 4 } },     -- vi ii V I
        },
        comps = { { { 0, 16, 4 }, { 16, 16, 4 } } },
    },
}

-- Puppetmaker's pattern, from its song file (mipo4.melodypaint.txt): per voice the patch, the pitch, the
-- length and its hits { step 1..16, chance %, rnd = a random semitone }. dense = PM2's page 1 (outside,
-- the crowd), sparse = page 2 (the editor). The chord is the rhodes2 sample: one up-strummed voicing
-- (root + 0 7 16 19 21, 60 ms apart, ringing ~2.8 s), only its root moves.
lib.puppetmaker = {
    chord = { 0, 7, 16, 19, 21 }, chordRoot = 51, strumMs = 60, chordMs = 2800,
    dense = {
        { 'conga', 52, 420, { { 1, 50 }, { 5, 50 }, { 9, 60 }, { 13, 60 } } },                  -- conga low
        { 'conga', 62, 140, { { 2, 80 }, { 7, 80 }, { 10, 80 }, { 3, 60 }, { 6, 60 }, { 11, 60 },
                              { 14, 90 }, { 15, 90 } } },                                         -- bongo low
        { 'conga', 69, 130, { { 1, 80 }, { 5, 80 }, { 10, 80 }, { 14, 80 }, { 3, 50 }, { 7, 50 },
                              { 9, 40 }, { 12, 70 } } },                                          -- bongo high
        { 'tamb', 60, 290, { { 1, 100 }, { 10, 100 }, { 13, 100 }, { 3, 80 }, { 4, 80 }, { 15, 80 },
                             { 16, 80 }, { 12, 70 }, { 8, 30 } } },
        { 'guiro', 60, 440, { { 8, 50 } } },
        { 'triangle', 100, 90, { { 5, 60 }, { 13, 80 } } },                                      -- 101, choked
        { 'triangleRing', 100, 1800, { { 6, 60 }, { 14, 40 } } },                                -- 103, ringing
        { 'chord', 0, 0, { { 9, 50, true } } },
        { 'rhodes', 64, 400, { { 8, 5, true } } },                                               -- ba
        { 'rhodes', 66, 200, { { 12, 5, true } } },                                              -- bi
        { 'rhodes', 66, 150, { { 16, 5, true }, { 3, 5, true } } },                              -- biep
    },
    sparse = {
        { 'conga', 69, 130, { { 11, 20 }, { 13, 20 } } },
        { 'tamb', 60, 290, { { 3, 10 }, { 15, 10 }, { 7, 20 }, { 12, 30 } } },
        { 'guiro', 60, 440, { { 7, 20, true } } },
        { 'triangle', 100, 90, { { 3, 10 }, { 15, 20, true } } },
        { 'triangleRing', 100, 1800, { { 14, 20, true } } },
        { 'chord', 0, 0, { { 8, 10, true } } },
        { 'quijada', 60, 800, { { 10, 20 } } },
    },
}

-- the tune's rhythm: GROUPS of two to four notes a 16th or an 8th apart, then a breath (lofi.c's
-- MOTIFS). { steps over two bars, group per note }
lib.motifs = {
    { { 0, 2, 4, 10, 12 }, { 0, 0, 0, 1, 1 } },          -- three up, two answer
    { { 0, 3, 6, 8, 16 }, { 0, 0, 0, 0, 1 } },           -- a four-note run, one long note
    { { 2, 4, 6, 12, 14, 20 }, { 0, 0, 0, 1, 1, 2 } },   -- off the beat, three groups
    { { 0, 2, 3, 6, 14, 16 }, { 0, 0, 0, 0, 1, 1 } },    -- a turn, then a pair
    { { 1, 4, 6, 8, 18 }, { 0, 0, 0, 0, 1 } },           -- a pickup into the run
    { { 0, 4, 6, 8, 10, 22 }, { 0, 1, 1, 1, 1, 2 } },    -- a stab, a run, a tail
    { { 4, 6, 8, 14, 16 }, { 0, 0, 0, 1, 1 } },          -- late: the space first
}
-- the island riff: per eighth, which voice of the chord's voicing (1 = lowest, 0 = rest)
lib.riffs = {
    { 1, 3, 2, 4, 1, 3, 2, 4 },   -- the rolling one
    { 1, 2, 3, 4, 3, 2, 1, 0 },   -- up and down
    { 4, 0, 3, 1, 4, 0, 3, 2 },   -- hopping from the top
    { 1, 0, 3, 0, 2, 4, 0, 3 },   -- with holes
    { 2, 4, 0, 4, 1, 4, 0, 3 },   -- the top note keeps coming back
}
-- dumont's pan riffs: sparser, around the off-beats, the way a steel pan part sits in dub-pop
lib.dumontRiffs = {
    { 0, 3, 0, 4, 0, 3, 2, 0 },
    { 4, 0, 3, 0, 0, 4, 3, 2 },
    { 0, 2, 4, 0, 3, 0, 4, 0 },
    { 3, 0, 0, 4, 0, 2, 0, 3 },
}
-- the answer's rhythms in bar 4, grouped the same way
lib.answers = { { 0, 2, 4, 10 }, { 2, 4, 6, 12 }, { 0, 2, 6, 8, 14 }, { 4, 6, 8, 12 }, { 0, 3, 6, 8 } }

-- a style's comp cells: its own, or a shared set from lib.comps by name
function lib.compsOf(style)
    return type(style.comps) == 'string' and lib.comps[style.comps] or style.comps
end

local VERSION = 2
-- On `state` so a hot reload keeps the song going where it was.
state.music = state.music or { activity = 0, withBand = false }
local M = state.music
if M.version ~= VERSION then M.version, M.song, M.barAt = VERSION, nil, nil end
M.booked = M.booked or {} -- the last few booked chords: { at = audio time, pcs = { pitch classes } }
M.listeners = M.listeners or {} -- onNote listeners by name (on state, so they survive a hot reload)

-- Hear every note the music books: fn(part, patch, midi, vol, durMs, t, step). part is 'keys', 'bass',
-- 'lead', 'riff', 'drums', 'vinyl', or for puppetmaker 'perc' / 'chord' / 'keys'; t is the audio time
-- it's booked for (lookahead ahead of synth.audioTime()); step 0..15 in its bar (puppetmaker only, for
-- now). fn = nil removes it. Call this, don't set a field: see the settings note above.
function lib.onNote(name, fn)
    M.listeners[name] = fn
end

-- Gameplay calls this (impacts); enough of it brings the rhythm section in.
function lib.bump(amount)
    M.activity = M.activity + (amount or 1)
end

-- A seeded stream: rnd(n) is 0..n-1, rnd() is 0..1. Every planning concern draws from its own
-- stream (song seed + a number), so a decision added to one never reshuffles another, and a phrase
-- seeded by its place in the form comes out the same each time that place comes round.
local function stream(seed, k)
    local s = (seed * 69069 + k * 2654435 + 1) % 2147483647
    if s == 0 then s = 1 end
    local function rnd(n)
        s = (s * 16807) % 2147483647
        if n then return s % n end
        return s / 2147483647
    end
    rnd(); rnd()
    return rnd
end

-- lofi.c's lead_to4: every rotation and drop-2 of the chord in every octave, bottom note in
-- lo..lo+12, top at most hi, no semitone or minor ninth between any two notes, no low clusters; the
-- one that moves least from the previous voicing (top-voice leaps over 4 cost extra), pulled toward 62.
local function voiceChord(rootPc, intervals, lo, hi, previous)
    if intervals.stack then -- a fixed shape: the octave nearest the previous voicing's middle
        local best, bestCost = nil, math.huge
        for octave = 2, 7 do
            local v = {}
            for j, interval in ipairs(intervals) do v[j] = rootPc + interval + 12 * octave end
            if v[1] >= lo and v[1] <= lo + 12 and v[#v] <= hi then
                local mean = 0
                for j = 1, #v do mean = mean + v[j] / #v end
                local target = previous and (previous[1] + previous[#previous]) / 2 or 62
                local cost = math.abs(mean - target)
                if cost < bestCost then bestCost, best = cost, v end
            end
        end
        return best or previous
    end
    local pcs = {}
    for _, interval in ipairs(intervals) do
        local pc = (rootPc + interval) % 12
        local dup = false
        for _, existing in ipairs(pcs) do if existing == pc then dup = true end end
        if not dup then pcs[#pcs + 1] = pc end
    end
    table.sort(pcs)
    local n, best, bestCost = #pcs, nil, math.huge
    for rotation = 0, n - 1 do
        for drop2 = 0, (n >= 3 and 1 or 0) do
            local shape = {}
            for j = 0, n - 1 do
                local note = pcs[(rotation + j) % n + 1]
                while j > 0 and note <= shape[j] do note = note + 12 end
                shape[j + 1] = note
            end
            if drop2 == 1 then
                shape[n - 1] = shape[n - 1] - 12
                table.sort(shape)
            end
            for octave = 2, 7 do
                local v = {}
                for j = 1, n do v[j] = shape[j] + 12 * octave end
                if v[1] >= lo and v[1] <= lo + 12 and v[n] <= hi then
                    local bad = false
                    for a = 1, n do
                        for b = a + 1, n do
                            local d = v[b] - v[a]
                            if d == 1 or d == 13 or d == 25 then bad = true end
                        end
                        if a > 1 and v[a] - v[a - 1] < 3 and v[a - 1] < 52 then bad = true end
                    end
                    if not bad then
                        local mean = 0
                        for j = 1, n do mean = mean + v[j] end
                        local cost = 0.5 * math.abs(mean / n - 62)
                        if previous then
                            for j = 1, n do cost = cost + math.abs(v[j] - previous[math.min(j, #previous)]) end
                            local topLeap = math.abs(v[n] - previous[#previous])
                            if topLeap > 4 then cost = cost + 2 * (topLeap - 4) end
                        end
                        if cost < bestCost then bestCost, best = cost, v end
                    end
                end
            end
        end
    end
    return best or previous
end

-- MIDI note of pitch class pc in lo..lo+11
local function inRange(pc, lo)
    return lo + (pc - lo) % 12
end

-- performance, not composition: a few ms of human timing (a sum of uniforms, roughly Gaussian)
local function humanize(sigma)
    local r = love.math.random
    return (r() + r() + r() - 1.5) * 2 * sigma
end

local function bandPlays()
    if lib.rhythmSection == 'on' then return true end
    if lib.rhythmSection == 'off' then return false end
    if M.withBand and M.activity < lib.bandLeaves then M.withBand = false end
    if not M.withBand and M.activity > lib.bandJoins then M.withBand = true end
    return M.withBand
end

---------------------------------------------------------------------------------------------------
-- The song plan

local function progAdd(prog, degree, quality, beats)
    prog[#prog + 1] = { degree = degree % 12, quality = quality, steps = beats * 4 }
    prog.steps = (prog.steps or 0) + beats * 4
end

-- the last bar of B becomes a ii-V back to the top
local function progTurnaround(prog, minor, fromKey)
    local cut = 16
    while cut > 0 and #prog > 0 do
        local last = prog[#prog]
        if last.steps > cut then
            last.steps, cut = last.steps - cut, 0
        else
            cut = cut - last.steps
            prog[#prog] = nil
        end
    end
    prog.steps = prog.steps - 16
    local home = fromKey and 0 or prog[1].degree -- lofi turns around to the key, the others to A's first chord
    progAdd(prog, home + 2, minor and 'm7b5' or 'm9', 2)
    progAdd(prog, home + 7, minor and 'b9' or 'dom9', 2)
end

local function nextStyleName()
    if lib.style ~= 'set' then return lib.styles[lib.style] and lib.style or 'bossa' end
    M.setIndex = (M.setIndex or 0) % #lib.set + 1
    return lib.set[M.setIndex]
end

-- a related key: up a fourth or a fifth when one of lib.keys is there, else any other
local function nextKey(previous)
    if not previous then return lib.keys[love.math.random(#lib.keys)] end
    local related, others = {}, {}
    for _, key in ipairs(lib.keys) do
        local d = (key - previous) % 12
        if d == 5 or d == 7 then related[#related + 1] = key elseif d ~= 0 then others[#others + 1] = key end
    end
    local pool = #related > 0 and related or others
    return #pool > 0 and pool[love.math.random(#pool)] or previous
end

local function planSong()
    local styleName = nextStyleName()
    local style = lib.styles[styleName]
    local seed = love.math.random(1, 2147483646)
    local function between(range) -- a style value that is a number, or a { lo, hi } to roll per song
        if type(range) ~= 'table' then return range end
        return range[1] + love.math.random() * (range[2] - range[1])
    end
    local setKey = nextKey(M.song and M.song.setKey)
    local song = {
        version = VERSION, style = styleName, seed = seed, setKey = setKey, key = setKey,
        beat = 60 / math.floor(between(style.bpm) + 0.5), swing = between(style.swing) or 0.5,
        swing16 = style.swing16, snareLag = between(style.snareLagMs or 8) / 1000,
    }
    song.barLength = 4 * song.beat

    if style.loop then -- a loop, not a song: one section, no chords, no tune
        local section = { kind = 'loop', bars = style.bars, roles = {} }
        song.sections, song.barSection, song.barIndex = { section }, {}, {}
        for j = 0, style.bars - 1 do song.barSection[j + 1], song.barIndex[j + 1] = section, j end
        song.bars, song.bar = style.bars, 0
        return song
    end

    local rnd = stream(seed, 1)
    song.lydian = rnd() < (style.lydianChance or 0)
    -- lofi: a minor key half the time, the relative minor of the set's key
    song.minor = style.minorChance and rnd(100) < style.minorChance
    if song.minor then song.key = (setKey + 9) % 12 end
    song.home = song.minor and style.homeMinor or style.home
    local bank = song.minor and style.Aminor or style.A
    local chordBars = style.chordBars[rnd(#style.chordBars) + 1]
    local aIndex = rnd(#bank) + 1
    song.A = {}
    for _, chord in ipairs(bank[aIndex]) do progAdd(song.A, chord[1], chord[2], (chord[3] or 4) * chordBars) end
    song.B = {}
    if style.B == 'A' and rnd(100) < 60 then -- lofi: B is another loop from the same bank...
        local bIndex = (aIndex + rnd(#bank - 1)) % #bank + 1
        for _, chord in ipairs(bank[bIndex]) do progAdd(song.B, chord[1], chord[2], (chord[3] or 4) * chordBars) end
    elseif style.B == 'A' or rnd(100) < 35 then -- ...or A with a ii-V turnaround...
        for _, chord in ipairs(song.A) do progAdd(song.B, chord.degree, chord.quality, chord.steps / 4) end
        progTurnaround(song.B, song.minor, style.B == 'A')
    else                  -- ...or a move of its own
        for _, chord in ipairs(style.B[rnd(#style.B) + 1]) do progAdd(song.B, chord[1], chord[2], chord[3]) end
    end

    -- the form, and each part's role per section (bass: 'play', 'last' bar only, 'hold' or 'none')
    song.sections, song.barSection, song.barIndex = {}, {}, {}
    local aCount = 0
    local forms = style.forms == 'lofi' and lib.lofiForms or lib.forms
    song.hasLead = not style.leadChance or rnd(100) < style.leadChance
    for _, entry in ipairs(forms[rnd(#forms) + 1]) do
        local kind, bars = entry[1], entry[2]
        local roles = { keys = 'comp', drums = 'full', lead = true, bass = 'play' }
        if kind == 'intro' then
            roles = { keys = 'hold', drums = 'none', lead = false, bass = 'play' }
            if style.forms == 'lofi' then -- the hats come in for the intro's last two bars, the bass maybe
                roles.drums = rnd(100) < 45 and 'hats' or 'none'
                roles.bass = rnd(100) < 50 and 'last' or 'none'
            end
        elseif kind == 'A' then aCount = aCount + 1; roles.lead = aCount >= 2 -- the band plays the changes once first
        elseif kind == 'break' then
            roles = { keys = 'hold', drums = rnd(100) < 35 and 'rim' or 'none', lead = rnd(100) < 30,
                      bass = rnd(100) < 50 and 'hold' or 'none' }
        elseif kind == 'outro' then roles = { keys = 'outro', drums = 'outro', lead = false, bass = 'play' } end
        local section = { kind = kind, bars = bars, roles = roles,
                          dipLast = (kind == 'A' or kind == 'B') and rnd(100) < 25 }
        song.sections[#song.sections + 1] = section
        for j = 0, bars - 1 do
            song.barSection[#song.barSection + 1] = section
            song.barIndex[#song.barIndex + 1] = j
        end
    end
    song.bars = #song.barSection

    -- the comp cell per two bars, and per bar (knowing the next): the push and a fill
    song.comp, song.push, song.fill = {}, {}, {}
    rnd = stream(seed, 2)
    local weights, total = {}, 0
    for i = 1, #lib.compsOf(style) do
        local w = style.compWeights and between(style.compWeights[i]) or 1
        weights[i], total = w, total + w
    end
    for b = 1, song.bars do
        local u, pick = rnd() * total, #weights
        for i, w in ipairs(weights) do
            if u < w then pick = i; break end
            u = u - w
        end
        song.comp[b] = pick
        song.push[b] = rnd(100) < (style.pushOdds or 0)
        local section = song.barSection[b]
        song.fill[b] = b < song.bars and section.roles.drums == 'full'
            and song.barIndex[b] == section.bars - 1 and rnd(100) < 60
    end

    -- the tune: the song's motif rhythm and its cell's anchor pitches; a ladder of the key's
    -- pentatonic above the chord (median ~76, lofi's 67..86)
    rnd = stream(seed, 9)
    local motif = lib.motifs[rnd(#lib.motifs) + 1]
    song.motif = { steps = motif[1], groups = motif[2], dir = {} }
    local repeatOdds = style.motifRepeat or 18
    local run, d = 0, rnd(100) < 55 and 1 or -1
    for i = 2, #motif[1] do
        if motif[2][i] ~= motif[2][i - 1] then
            run, d = 0, rnd(100) < 55 and 1 or -1 -- a new group, a new direction
            song.motif.dir[i] = 0
        else
            run = run + 1
            local u = rnd(100) -- a run turns back at its end, and sometimes repeats a note
            song.motif.dir[i] = (run >= 3 or u < 18) and -d or (u < 18 + repeatOdds) and 0 or d
        end
    end
    song.cellDegrees = { 0, rnd(6) - 2, rnd(6) - 1 }
    local riffs = style.riffs == 'dumont' and lib.dumontRiffs or lib.riffs
    song.riff = riffs[stream(seed, 3)(#riffs) + 1]
    -- the scale and the tune's pentatonic: major, dorian (minor, with the major sixth) or minor
    local minor = style.mode == 'dorian' or song.minor
    song.scale = style.mode == 'dorian'
        and { [0] = true, [2] = true, [3] = true, [5] = true, [7] = true, [9] = true, [10] = true }
        or song.minor and { [0] = true, [2] = true, [3] = true, [5] = true, [7] = true, [8] = true, [10] = true }
        or { [0] = true, [2] = true, [4] = true, [5] = true, [7] = true, [9] = true, [11] = true }
    local penta = minor and { [0] = true, [3] = true, [5] = true, [7] = true, [10] = true }
        or { [0] = true, [2] = true, [4] = true, [7] = true, [9] = true }
    song.ladder = {}
    local range = style.range or { 67, 86 }
    for midi = range[1], range[2] do
        if penta[(midi - song.key) % 12] then song.ladder[#song.ladder + 1] = midi end
    end
    song.hookStart = { A = 4 + rnd(3), B = 3 + rnd(4) } -- ladder index where each section's tune starts

    -- lofi: the groove (one of the kit's grids, weighted by tempo), the bass held long or short, the
    -- Rhodes' own lowpass and the tape's tone (the lowpass the sections ride)
    if style.drums == 'jazzhop' then
        local slow = 60 / song.beat < 74
        local w = slow and { 1.0, 1.0, 1.0, 2.6, 0.5, 0.7 } or { 1.3, 1.2, 1.0, 0.6, 0.5, 1.0 }
        local sum = 0
        for _, x in ipairs(w) do sum = sum + x end
        local u = rnd() * sum
        song.grid = #w
        for i, x in ipairs(w) do
            if u < x then song.grid = i; break end
            u = u - x
        end
    end
    song.legato = rnd(100) < 50
    song.epLp = between(style.epLp)
    song.tone = between(style.tone)

    song.bar = 0
    return song
end

local function qualityOf(song, name)
    if song.lydian and name == 'maj9' then name = 'lydian' end
    return lib.qualities[name]
end

local function chordPcs(song, chord)
    local root = (song.key + chord.degree) % 12
    local pcs = { root }
    for _, interval in ipairs(qualityOf(song, chord.quality)) do pcs[#pcs + 1] = (root + interval) % 12 end
    return pcs
end

-- the chords inside bar b: { degree, quality, s = start step, len = steps }
local function barChords(song, b)
    if b < 1 or b > song.bars then b = math.max(1, math.min(song.bars, b)) end
    local section, j = song.barSection[b], song.barIndex[b]
    if section.kind == 'outro' and j >= 2 then -- the outro rings on home
        return { { degree = 0, quality = song.home or lib.styles[song.style].home, s = 0, len = 16 } }
    end
    local prog = section.kind == 'B' and song.B or song.A
    local b0, at, out = (j * 16) % prog.steps, 0, {}
    for _, chord in ipairs(prog) do
        local cs, ce = at, at + chord.steps
        at = ce
        local s, e = math.max(cs, b0), math.min(ce, b0 + 16)
        if e > s then out[#out + 1] = { degree = chord.degree, quality = chord.quality, s = s - b0, len = e - s } end
    end
    return out
end

local function chordAtStep(song, b, s)
    local chords = barChords(song, b + math.floor(s / 16))
    s = s % 16
    for i = #chords, 1, -1 do
        if s >= chords[i].s then return chords[i] end
    end
    return chords[1]
end

---------------------------------------------------------------------------------------------------
-- The tune

local function isChordTone(song, midi, chord)
    local pc = midi % 12
    for _, chordPc in ipairs(chordPcs(song, chord)) do
        if chordPc == pc or (chordPc + 7) % 12 == pc and chordPc == (song.key + chord.degree) % 12 then return true end
    end
    return false
end

-- an avoid note: a semitone above a chord tone
local function isAvoid(song, midi, chord)
    return not isChordTone(song, midi, chord) and isChordTone(song, midi - 1, chord)
end

-- a semitone from a note the chord holds: fine for a passing 16th, not for a long note
local function rubs(song, midi, chord)
    local root = (song.key + chord.degree) % 12
    for _, interval in ipairs(qualityOf(song, chord.quality)) do
        local d = (midi - root - interval) % 12
        if d == 1 or d == 11 then return true end
    end
    return false
end

local function snapChord(song, li, chord)
    local ladder = song.ladder
    for d = 0, 3 do
        if ladder[li - d] and isChordTone(song, ladder[li - d], chord) then return li - d end
        if ladder[li + d] and isChordTone(song, ladder[li + d], chord) then return li + d end
    end
    return li
end

local function inKey(song, midi)
    return song.scale[(midi - song.key) % 12] == true
end

-- One phrase over four bars from bar b (the first of them): the motif stated over bars 1-2, bar 3
-- breathes, bar 4 answers. Seeded by its place (section kind + which four bars), so it comes back
-- the same every time that place does. Notes are { step 0..63, midi, vol, len in steps, grace }.
local function buildPhrase(song, b)
    local section, j = song.barSection[b], song.barIndex[b]
    local slot = math.floor(j / 4)
    local rnd = stream(song.seed, 5000 + (section.kind == 'B' and 100 or 0) + slot)
    local style = lib.styles[song.style]
    local notes = {}
    if slot % 2 == 1 and rnd(100) < 30 then return notes end -- a phrase of space
    local ladder = song.ladder
    local function clampIndex(i) return math.max(1, math.min(#ladder, i)) end
    local start = section.lastLadder
    if slot == 0 or not start then start = song.hookStart[section.kind == 'B' and 'B' or 'A'] end
    local invert, shift = section.kind == 'B', section.kind == 'B' and 2 or 0
    local motif, x = song.motif, start
    for i, step in ipairs(motif.steps) do
        local s = step + shift
        if s < 30 then
            local group = motif.groups[i]
            local first = i == 1 or motif.groups[i - 1] ~= group
            if first then -- the cell's pitch anchors the group
                local d = song.cellDegrees[group % #song.cellDegrees + 1]
                x = start + (invert and -d or d)
            else          -- inside a group: a scale step
                x = x + (invert and -motif.dir[i] or motif.dir[i])
            end
            x = clampIndex(x)
            local chord = chordAtStep(song, b, s)
            if s % 8 == 0 or isAvoid(song, ladder[x], chord) then x = snapChord(song, x, chord) end
            notes[#notes + 1] = { s = s, li = x, vol = first and 5 or 4 }
        end
    end
    local at = #notes > 0 and notes[#notes].li or start
    if slot % 3 == 2 and at > 1 then -- now and then a pickup into the answer's bar
        local x2 = at - 1
        local chord = chordAtStep(song, b, 31)
        if isAvoid(song, ladder[x2], chord) then x2 = snapChord(song, x2, chord) end
        notes[#notes + 1] = { s = 31, li = x2, vol = 3 }
    end
    local answer = lib.answers[rnd(#lib.answers) + 1]
    for k, step in ipairs(answer) do
        local s = 48 + step -- bar 4: bar 3 is the breath
        local leap = rnd(100) < 75 and 1 or 2 -- answers mostly fall, mostly by step
        at = clampIndex(at + (rnd(100) < 60 and -leap or leap))
        local chord = chordAtStep(song, b, s)
        if s % 8 == 0 or k == #answer or isAvoid(song, ladder[at], chord) then at = snapChord(song, at, chord) end
        notes[#notes + 1] = { s = s, li = at, vol = k == #answer and 4 or 3 }
    end
    for _, note in ipairs(notes) do note.midi = ladder[note.li] end

    -- passing tones: a third with room gives its second half to the key's scale step between
    local out = {}
    for k, note in ipairs(notes) do
        out[#out + 1] = note
        local nextNote = notes[k + 1]
        if nextNote then
            local iv, gap = nextNote.midi - note.midi, nextNote.s - note.s
            if math.abs(iv) >= 3 and math.abs(iv) <= 4 and gap >= 2 and gap <= 8 and rnd(100) < 60 then
                local dir = iv > 0 and 1 or -1
                local p = note.midi + dir
                if not inKey(song, p) then p = p + dir end
                local s = note.s + math.floor(gap / 2)
                local fits = p ~= nextNote.midi and inKey(song, p) and s % 8 ~= 0
                if fits and not isAvoid(song, p, chordAtStep(song, b, s)) then
                    out[#out + 1] = { s = s, li = note.li, midi = p, vol = math.max(2, note.vol - 1) }
                end
            end
        end
    end
    notes = out

    -- each note lasts to the next (the last rings); long notes keep off the chord's semitones;
    -- a long note may get a quick scale neighbour flicked in just before it
    for k, note in ipairs(notes) do
        local nextS = notes[k + 1] and notes[k + 1].s or 64
        note.len = math.min(nextS - note.s, notes[k + 1] and (style.staccato or 6) or 10)
        local chord = chordAtStep(song, b, note.s)
        if note.len >= 2 and rubs(song, note.midi, chord) then
            for d = 1, 2 do
                local down, up = ladder[note.li - d], ladder[note.li + d]
                if down and not rubs(song, down, chord) then note.midi = down break end
                if up and not rubs(song, up, chord) then note.midi = up break end
            end
        end
        if note.len * song.beat / 4 >= 0.3 and rnd(100) < 40 then
            local dir = rnd(100) < 62 and 1 or -1
            local grace = note.midi + dir
            if not inKey(song, grace) then grace = grace + dir end
            local previous = notes[k - 1]
            if not previous or previous.s + previous.len <= note.s - 1 then note.grace = grace end
        end
    end
    section.lastLadder = #notes > 0 and notes[#notes].li or section.lastLadder
    return notes
end

---------------------------------------------------------------------------------------------------
-- Booking a bar

-- the audio time of 16th step s in a bar starting at t0, swung on the off-beat 8ths
local function stepTime(song, t0, s)
    local beat, sw = song.beat, song.swing
    if song.swing16 then -- lofi's swing: straight 8ths, the off-beat 16ths late
        local sd = beat / 4
        return t0 + s * sd + (s % 2 == 1 and (sw - 0.5) * 2 * sd or 0)
    end
    local r = s % 4
    local off = r == 0 and 0 or r == 1 and sw * beat / 2 or r == 2 and sw * beat or sw * beat + (1 - sw) * beat / 2
    return t0 + math.floor(s / 4) * beat + off
end

-- how long steps s..s+len last, in ms: on the swung grid, not in straight 16ths (a swung off-beat
-- 8th is short, so a straight length rings into the next downbeat)
local function lengthMs(song, s, len)
    return (stepTime(song, 0, s + len) - stepTime(song, 0, s)) * 1000
end

-- every note goes through here; lib.trace(part, t, midi, vol, durMs), when set, sees them all
-- (claudetools/render-music.lua counts rubs with it)
local function play(synth, part, patch, t, midi, vol, durMs, step)
    synth.scheduleAt(patch, t, midi, vol, durMs)
    if lib.trace then lib.trace(part, t, midi, vol, durMs) end
    for name, fn in pairs(M.listeners) do
        local ok, err = pcall(fn, part, patch, midi, vol, durMs, t, step)
        if not ok then M.listeners[name] = nil; print('[music] onNote ' .. name .. ': ' .. tostring(err)) end
    end
end

-- One bar of Puppetmaker's loop: every hit rolls its chance, rnd ones land on a random semitone.
-- Busy play gets the crowd's dense page, calm the editor's sparse one.
local function bookLoopBar(synth, t0, song, b)
    local pm, rnd = lib.puppetmaker, stream(song.seed, 6000 + b)
    for _, voice in ipairs(bandPlays() and pm.dense or pm.sparse) do
        local patch, midi, durMs, hits = voice[1], voice[2], voice[3], voice[4]
        for _, h in ipairs(hits) do
            if rnd(100) < h[2] then
                local s, shift = h[1] - 1, h[3] and rnd(12) - 6 or 0
                local t = stepTime(song, t0, s) + humanize(0.003)
                if patch == 'chord' then -- the rolled Rhodes chord, an up-strum
                    local root, pcs = pm.chordRoot + shift, {}
                    for k, interval in ipairs(pm.chord) do
                        play(synth, 'chord', 'rhodes', t + (k - 1) * pm.strumMs / 1000, root + interval, 4,
                             pm.chordMs - (k - 1) * pm.strumMs, s)
                        pcs[#pcs + 1] = (root + interval) % 12
                    end
                    table.insert(M.booked, { at = t, pcs = pcs }) -- impacts play along in its notes
                    if #M.booked > 4 then table.remove(M.booked, 1) end
                else
                    play(synth, patch == 'rhodes' and 'keys' or 'perc', patch, t, midi + shift,
                         patch == 'tamb' and 4 or 5, durMs, s)
                end
            end
        end
    end
end

-- the left hand (or the upright, with lane = 'musicBass') under one chord inside the bar
local bassLines = {
    -- root on 1 held a dotted quarter, the fifth on the and-of-2 held over 3
    bossa = function(hit, chord, lo)
        local root = inRange(chord.root, lo)
        local fifth = chord.lydian and root or root + 7 -- the fifth would rub the raised fourth, the octave the seventh
        if chord.s == 0 then hit(0, root, 4, 5) end
        if chord.s <= 6 and chord.s + chord.len > 6 then hit(6, fifth, 3, 10) end
        if chord.s == 8 then hit(8, root, 4, 8) end
    end,
    -- open fifths, bouncing: the fifth on 1 and 3, the fifth again on the and-of-2 and a half-step
    -- walk into the next root on the and-of-4
    guaraldi = function(hit, chord, lo, lastBar, nextRoot)
        local root = inRange(chord.root, lo)
        local function fifth(s, vol, len) hit(s, root, vol, len); hit(s, root + 7, vol - 1, len) end
        local e = chord.s + chord.len
        if chord.s == 0 then fifth(0, 5, 5) end
        if chord.s <= 6 and e > 6 then hit(6, root + 7, 3, 2) end
        if chord.s <= 8 and e > 8 then fifth(8, 4, 5) end
        if e == 16 then
            if lastBar and nextRoot and nextRoot ~= chord.root then
                local target = inRange(nextRoot, lo)
                hit(14, target + (target > root and -1 or 1), 3, 2)
            else
                hit(14, root + 7, 3, 2)
            end
        end
    end,
    -- root on 1, fifth on 3, a pickup on the and-of-4 now and then (the step before the next root)
    bounce = function(hit, chord, lo, lastBar, nextRoot, fits)
        local root = inRange(chord.root, lo)
        if chord.s == 0 then hit(0, root, 5, 5) end
        if chord.s <= 8 and chord.s + chord.len > 8 then hit(8, root + 7, 4, 5) end
        if chord.s + chord.len == 16 and lastBar and nextRoot and nextRoot ~= chord.root then
            local target = inRange(nextRoot, lo)
            local pickup = target + (target > root and -2 or 2)
            hit(14, fits(pickup, chord) and pickup or root + 7, 3, 2)
        end
    end,
    -- funk: the root short on 1, a ghost on the a-of-1, the octave popping on the and-of-2 and
    -- the a-of-4, the root again just after the pop, the fifth on the and-of-3, a step into the next
    -- root; any note that would rub the chord gives way to the root or the fifth
    funk = function(hit, chord, lo, lastBar, nextRoot, fits)
        local root = inRange(chord.root, lo)
        local fifth = fits(root + 7, chord) and root + 7 or root
        local pop = fits(root + 12, chord) and root + 12 or fifth -- the octave would rub a maj7 in the keys
        local e = chord.s + chord.len
        local function at(s, midi, vol, len) if s >= chord.s and s < e then hit(s, midi, vol, len) end end
        at(0, root, 5, 2); at(3, root, 2, 1); at(6, pop, 4, 1); at(7, root, 3, 1)
        if chord.s == 8 then at(8, root, 5, 2) end
        at(10, fifth, 4, 2); at(12, root, 3, 1); at(13, pop, 3, 1)
        if e == 16 and lastBar and nextRoot and nextRoot ~= chord.root then
            local target = inRange(nextRoot, lo)
            local pickup = target + (target > root and -2 or 2)
            at(14, fits(pickup, chord) and pickup or fifth, 4, 2)
        else
            at(14, fifth, 3, 2)
        end
    end,
    -- boom: a sub under the kick, the root long on 1 and again on the and-of-3, now and then a
    -- step into the next root
    boom = function(hit, chord, lo, lastBar, nextRoot, fits)
        local root = inRange(chord.root, lo)
        local e = chord.s + chord.len
        if chord.s == 0 then hit(0, root, 5, 6) end
        if chord.s <= 10 and e > 10 then hit(10, root, 4, 4) end
        if e == 16 and lastBar and nextRoot and nextRoot ~= chord.root then
            local target = inRange(nextRoot, lo)
            local pickup = target + (target > root and -2 or 2)
            if fits(pickup, chord) then hit(14, pickup, 3, 2) end
        end
    end,
    hold = function(hit, chord, lo)
        hit(chord.s, inRange(chord.root, lo), 5, chord.len)
    end,
}

-- the drums for one bar: hit(step, patch, midi, vol, durMs); section = 'A' / 'B' / 'outro'
local drumKits = {
    bossa = function(hit, _, kind, j, fill)
        hit(0, 'kick', 36, 4, 150)
        hit(6, 'kick', 36, 3, 150)
        for s = 0, 14, 2 do hit(s, 'shaker', 84, s % 4 == 2 and 3 or 2, 40) end -- the off-beats lean
        if kind == 'B' then -- the cross-stick on the clave joins in B
            local clave = j % 2 == 0 and { 0, 6, 12 } or { 4, 10 }
            for _, s in ipairs(clave) do hit(s, 'rim', 79, 4, 40) end
        end
        if fill then
            hit(12, 'rim', 79, 3, 40); hit(14, 'rim', 79, 4, 40); hit(15, 'rim', 79, 3, 40)
            hit(14, 'kick', 36, 3, 150)
        end
    end,
    island = function(hit, rnd, kind, _, fill)
        hit(0, 'kick', 36, 4, 150)
        hit(8, 'kick', 36, 3, 150)
        hit(4, 'rim', 79, 4, 40)
        hit(12, 'rim', 79, 4, 40)
        for s = 0, 14, 2 do hit(s, 'shaker', 84, s % 4 == 2 and 2 or 1, 40) end
        if kind == 'B' and rnd(100) < 40 then hit(14, 'kick', 36, 2, 120) end
        if fill then hit(10, 'rim', 79, 2, 40); hit(14, 'rim', 79, 3, 40); hit(15, 'rim', 79, 3, 40) end
    end,
    -- a homemade drum machine, funky: kick on 1, the and-of-2 and the and-of-3, a flammed clap
    -- on 2 and 4 with a quiet echo, 16th hats leaning on the off-beats, a conga answering
    machine = function(hit, rnd, kind, _, fill)
        hit(0, 'kick', 36, 5, 140)
        hit(6, 'kick', 36, 3, 120)
        hit(10, 'kick', 36, 4, 140)
        for _, s in ipairs({ 4, 12 }) do
            hit(s, 'clap', 72, 4, 60); hit(s, 'clap', 72, 3, 60, 0.011); hit(s, 'clap', 72, 3, 80, 0.022)
        end
        hit(15, 'clap', 72, 2, 80, 0.011) -- the echo of 4
        for s = 0, 15 do hit(s, 'hat', 60, s % 4 == 2 and 3 or s % 2 == 0 and 2 or 1, 25) end
        hit(14, 'conga', 59, 3, 200)
        if kind == 'B' then hit(7, 'conga', 64, 3, 200); if rnd(100) < 50 then hit(11, 'conga', 64, 2, 200) end end
        if fill then hit(13, 'conga', 64, 3, 200); hit(14, 'conga', 61, 4, 200); hit(15, 'conga', 59, 4, 200) end
    end,
    -- boom-bap: a hard kick on 1 and the and-of-3 (and the a-of-2 now and then), a snare on 2 and
    -- 4 (noise over a tuned-up kick for its body) dragged by the swing, a ghost snare, swung 8th
    -- hats, an open hat on the and-of-4 now and then, vinyl crackle
    boombap = function(hit, rnd, kind, _, fill)
        hit(0, 'bapKick', 36, 6, 220)
        hit(10, 'bapKick', 36, 5, 220)
        if rnd(100) < 40 then hit(7, 'bapKick', 36, 4, 180) end
        for _, s in ipairs({ 4, 12 }) do hit(s, 'snare', 60, 5, 140); hit(s, 'bapKick', 50, 3, 90) end
        if rnd(100) < 35 then hit(15, 'snare', 60, 2, 60) end
        for s = 0, 14, 2 do hit(s, 'hat', 60, s % 4 == 0 and 3 or 2, 30) end
        if kind == 'B' and rnd(100) < 50 then hit(14, 'hat', 60, 2, 160) end
        for _ = 1, 5 do hit(rnd(16), 'crackle', 90 + rnd(12), 1, 8) end
        if fill then hit(13, 'snare', 60, 3, 60); hit(14, 'snare', 60, 4, 60); hit(15, 'bapKick', 36, 4, 160) end
    end,
    -- a light 70s kit: kick on 1 and 3, the rim on 2 and 4, closed hats in 8ths with a lift on the
    -- off-beats, a skip on the a-of-4 into B
    lounge = function(hit, rnd, kind, _, fill)
        hit(0, 'kick', 36, 4, 150)
        hit(8, 'kick', 36, 3, 150)
        if rnd(100) < 30 then hit(14, 'kick', 36, 2, 120) end
        hit(4, 'rim', 79, 4, 40)
        hit(12, 'rim', 79, 4, 40)
        for s = 0, 14, 2 do hit(s, 'hat', 60, s % 4 == 2 and 2 or 1, 30) end
        if kind == 'B' then for s = 1, 15, 4 do hit(s + 2, 'shaker', 84, 1, 30) end end
        if fill then hit(13, 'rim', 79, 3, 40); hit(14, 'rim', 79, 3, 40); hit(15, 'rim', 79, 4, 40) end
    end,
    -- cocktail.c's brushes: the hat snaps 2 and 4, the sweep every other bar, a feathered kick;
    -- in B the ride carries the time, ding ding-ga ding
    brushes = function(hit, rnd, kind, j, fill)
        hit(4, 'hat', 60, 3, 40)
        hit(12, 'hat', 60, 3, 40)
        if j % 2 == 0 then hit(0, 'brush', 70, 2, 900) end
        for s = 0, 12, 4 do
            if rnd(100) < 30 then hit(s, 'kick', 33, 3, 60) end
        end
        if kind == 'B' or fill then
            for s = 0, 12, 4 do hit(s, 'ride', 81, s % 8 == 0 and 3 or 2, 220) end
            hit(6, 'ride', 81, 2, 120)
            hit(14, 'ride', 81, 2, 120)
        end
        if fill then hit(10, 'ride', 81, 3, 120); hit(14, 'kick', 33, 3, 60) end
    end,
}

-- lofi's boom-bap grids, per lane over a bar of 16ths (x hit, g ghost, o open hat, r rim): boom,
-- bounce, lazy, half-time, the rim (the break), shuffle
local lofiGrids = {
    { K = 'x.........x.....', S = '....x.......x...', H = 'x.x.x.x.x.x.x.x.' },
    { K = 'x......x..x.....', S = '....x.......x...', H = 'x.x.x.x.x.x.x.xx' },
    { K = 'x.....x.........', S = '....x..g....x...', H = 'x.x.x.x.x.x.x.o.' },
    { K = 'x.....x...x.....', S = '........x.......', H = 'x.x.x.x.x.x.x.x.', R = '............r...' },
    { K = 'x.........x.....', H = 'x...x...x...x...', R = '....r.......r...' },
    { K = 'x..x......x.....', S = '....x..g....x.g.', H = 'xxxxxxxxxxxxxxxx' },
}
local LANE_VEL = { K = 0.92, S = 0.88, H = 0.8, R = 0.8 }
local HAT_ACCENT = { [0] = 1, 0.45, 0.7, 0.45 }

-- One bar of the lofi groove: { hits = { { s, lane, vel, ghost, open } }, kicks = { steps }, stop }.
-- mode: 'full' (the song's grid), 'hats' (the intro's last two bars), 'rim' (the break), 'outro'.
-- Planned before the bass, which plays on the kicks. Fills come on the 4th and 8th bars.
local function lofiGroove(song, kind, j, bars, mode, rnd)
    local out = { hits = {}, kicks = {} }
    if mode == 'none' or (mode == 'hats' and j < bars - 2) or (mode == 'outro' and j >= 2) then return out end
    local grid = lofiGrids[mode == 'rim' and 5 or song.grid]
    local hits = out.hits
    for lane, pattern in pairs(grid) do
        for i = 1, 16 do
            local c = pattern:sub(i, i)
            if c ~= '.' then hits[#hits + 1] = { s = i - 1, lane = lane, ghost = c == 'g', open = c == 'o' } end
        end
    end
    local function keep(pred)
        local kept = {}
        for _, h in ipairs(hits) do if pred(h) then kept[#kept + 1] = h end end
        hits = kept
    end
    local function has(lane, s)
        for _, h in ipairs(hits) do if h.lane == lane and h.s == s then return h end end
    end
    if mode == 'hats' then keep(function(h) return h.lane == 'H' end) end
    if mode == 'outro' then keep(function(h) return h.lane ~= 'K' end) end
    local groove = mode == 'full' or mode == 'rim'
    if groove and j > 0 and rnd(100) < 8 then keep(function(h) return h.lane ~= 'K' end) end -- a bar without the kick
    if mode == 'full' and kind == 'B' then -- B: an open hat on the and-of-4 every other bar, ghost snares
        if j % 2 == 1 then
            local h = has('H', 14)
            if h then h.open = true else hits[#hits + 1] = { s = 14, lane = 'H', open = true } end
            keep(function(x) return not (x.lane == 'H' and x.s == 15) end)
        end
        for _, gs in ipairs({ 7, 15 }) do
            if rnd(100) < 30 and not has('S', gs) then hits[#hits + 1] = { s = gs, lane = 'S', ghost = true } end
        end
    end
    local pos = j + 1
    local fillOdds = pos % 8 == 0 and 50 or pos % 4 == 0 and 20 or 0
    if groove and fillOdds > 0 and rnd(100) < fillOdds then
        local fill = rnd(4) + 1
        if fill == 1 then -- a snare roll into the next bar
            keep(function(h) return not (h.lane == 'S' and h.s >= 12) end)
            for i, v in ipairs({ 0.9, 0.3, 0.45, 0.65 }) do hits[#hits + 1] = { s = 11 + i, lane = 'S', vel = v } end
        elseif fill == 2 then -- everything stops on beat 4
            keep(function(h) return h.s < 12 end)
            out.stop = 12
        elseif fill == 3 then -- two kicks pushing into the next bar
            for _, ks in ipairs({ 13, 15 }) do
                if not has('K', ks) then hits[#hits + 1] = { s = ks, lane = 'K', vel = 0.7 } end
            end
        else -- an open hat on the and-of-4
            keep(function(h) return not (h.lane == 'H' and h.s >= 14) end)
            hits[#hits + 1] = { s = 14, lane = 'H', open = true }
        end
    end
    local scale = mode == 'rim' and 0.6 or 1
    for _, h in ipairs(hits) do
        local v = h.vel or LANE_VEL[h.lane]
        if h.lane == 'H' then v = v * (h.open and 0.95 or HAT_ACCENT[h.s % 4]) end
        if h.lane == 'K' and h.s ~= 0 and not h.vel then v = v * 0.9 end
        if h.ghost then v = 0.25 + 0.1 * rnd() end
        h.vel = v * scale * (1 + (rnd() * 2 - 1) * 0.08)
        if h.lane == 'K' then out.kicks[#out.kicks + 1] = h.s end
    end
    table.sort(hits, function(a, c) return a.s < c.s end)
    table.sort(out.kicks)
    out.hits = hits
    return out
end

-- lofi's bass for one bar: the root on the kicks and on each change (nearest the last bass note),
-- now and then the fifth or the octave off the beat, a half-step approach on the and-of-4 into a new
-- root; held a little under the gap to the next note (most of it when the song is legato)
local function lofiBass(hit, chords, nextRoot, steps, stop, rnd, hold)
    local approach = false
    local changes = {}
    for _, chord in ipairs(chords) do changes[chord.s] = true end
    local function nearest(pc, prev)
        local best, bestD = nil, math.huge
        for m = 33 + (pc - 33) % 12, 47, 12 do
            local d = math.abs(m - prev)
            if d < bestD then best, bestD = m, d end
        end
        return best
    end
    local last = chords[#chords]
    if steps.useKicks and nextRoot and nextRoot ~= last.root and rnd(100) < 50 then
        local kept = {}
        for _, s in ipairs(steps) do if s < 14 then kept[#kept + 1] = s end end
        kept[#kept + 1] = 14
        steps, approach = kept, true
    end
    local kept = {}
    for _, s in ipairs(steps) do if s < stop then kept[#kept + 1] = s end end
    steps = kept
    for k, s in ipairs(steps) do
        local chord = chords[#chords]
        for _, c in ipairs(chords) do if s >= c.s and s < c.s + c.len then chord = c; break end end
        local root = nearest(chord.root, M.prevBass or 40)
        local m = root
        if approach and s == 14 then
            local target = nearest(nextRoot, root)
            m = rnd(100) < 60 and target - 1 or target + 1
        elseif not changes[s] and s % 8 ~= 0 and rnd(100) < 25 then
            if rnd(100) < 60 then m = root + 7 <= 50 and root + 7 or root - 5
            else m = root + 12 <= 52 and root + 12 or root end
        end
        local nextS = steps[k + 1] or stop
        hit(s, m, s == 0 and 6 or 5, math.max(1, nextS - s) * hold)
        M.prevBass = root
    end
end

-- lofi's tape tone: a lowpass the sections ride on the keys, the vibes and the bass. The intro opens
-- from 900 Hz, A and B drift around the song's tone every four bars, the break dips to 1800, a
-- section's last bar dips to 500 now and then, the outro closes to 700.
local function bookTone(synth, song, section, j, rnd)
    local kind, tone = section.kind, nil
    local function drift() return song.tone * (1 + (rnd() * 2 - 1) * 0.12) end
    if kind == 'intro' then tone = 900 * (song.tone / 900) ^ ((j + 1) / section.bars)
    elseif kind == 'outro' then if j == section.bars - 2 then tone = 700 end
    elseif j == 0 then tone = kind == 'break' and 1800 or drift()
    elseif j % 4 == 0 and (kind == 'A' or kind == 'B') then tone = drift() end
    if section.dipLast and j == section.bars - 1 then tone = 500 end
    if not (tone and synth.slotFilter) then return end
    synth.slotFilter('lofiKeys', math.min(song.epLp, tone))
    synth.slotFilter('vibes', math.min(3200, tone))
    synth.slotFilter('roundBass', math.min(600, tone))
end

local function bookBar(synth, t0, song, b)
    local style = lib.styles[song.style]
    M.barStart = t0
    if style.loop then return bookLoopBar(synth, t0, song, b) end
    local section, j = song.barSection[b], song.barIndex[b]
    local roles = section.roles
    local band = bandPlays()
    local rnd = stream(song.seed, 1000 + b)
    local chords = barChords(song, b)
    local nextChords = b < song.bars and barChords(song, b + 1) or nil
    for _, chord in ipairs(chords) do
        chord.root = (song.key + chord.degree) % 12
        chord.lydian = song.lydian and chord.quality == 'maj9'
    end
    local keysPatch = style.keys

    for _, chord in ipairs(chords) do
        table.insert(M.booked, { at = stepTime(song, t0, chord.s), pcs = chordPcs(song, chord) })
        if #M.booked > 4 then table.remove(M.booked, 1) end
    end

    -- the keys: the comp cell clipped to the chords, held chords in the intro and outro, the push
    local hits, sidestepAt = {}, nil
    local pushedInto = b > 1 and song.pushed and song.pushed[b - 1]
    local pushes = roles.keys == 'comp' and song.push[b] and nextChords
        and song.barSection[b + 1].roles.keys == 'comp'
        and (nextChords[1].degree ~= chords[#chords].degree or nextChords[1].quality ~= chords[#chords].quality)
    if roles.keys == 'hold' or (roles.keys == 'outro' and j < 2) then
        for _, chord in ipairs(chords) do hits[#hits + 1] = { s = chord.s, len = chord.len, vol = 4, chord = chord } end
    elseif roles.keys == 'outro' then
        if j == 2 then hits[1] = { s = 0, len = (section.bars - 2) * 16, vol = 4, chord = chords[1], ring = true } end
    else
        local cell = lib.compsOf(style)[song.comp[b - j % 2] or 1]
        local half = (j % 2) * 16
        for _, chord in ipairs(chords) do
            local c0, c1, own = chord.s, chord.s + chord.len, 0
            for _, h in ipairs(cell) do
                local s = h[1] - half
                if s >= c0 and s < c1 and not (pushedInto and s == 0) and not (pushes and s >= 14) then
                    own = own + 1
                    hits[#hits + 1] = { s = s, len = math.min(h[2], c1 - s), vol = h[3], chord = chord,
                                        light = rnd(100) < (style.lightOdds or 30) }
                end
            end
            if own == 0 and not (pushedInto and c0 == 0) then -- a change always sounds
                hits[#hits + 1] = { s = c0, len = style.holdChanges and c1 - c0 or math.min(4, c1 - c0), vol = 4,
                                    chord = chord }
            end
        end
        if pushes then -- anticipate: the next chord on the and-of-4, the next bar skips its downbeat
            for _, h in ipairs(hits) do h.len = math.min(h.len, 14 - h.s) end -- let go for it
            local nextChord = nextChords[1]
            nextChord.root = (song.key + nextChord.degree) % 12
            hits[#hits + 1] = { s = 14, len = 2 + math.min(nextChord.len, 6), vol = 4, chord = nextChord }
            song.pushed = song.pushed or {}
            song.pushed[b] = true
        elseif nextChords and style.sidestepOdds and rnd(100) < style.sidestepOdds
            and nextChords[1].degree ~= chords[#chords].degree then
            -- the side-step: the bar's last stab is the next chord a half-step high, sliding into it
            local last = hits[#hits]
            if last and last.s >= 8 then last.sidestep, sidestepAt = nextChords[1], last.s end
        end
    end
    table.sort(hits, function(a, c) return a.s < c.s end)
    for _, h in ipairs(hits) do
        local chord = h.sidestep or h.chord
        local root = (song.key + chord.degree) % 12
        local voicing = voiceChord(root, qualityOf(song, chord.quality), 48, 76, M.voicing)
        if not h.sidestep then M.voicing = voicing end
        local t = stepTime(song, t0, h.s) + humanize(0.005)
        local strum = (style.strumMs or 8) / 1000
        for k = h.light and 2 or 1, #voicing do
            local note = voicing[k] + (h.sidestep and 1 or 0)
            local vol = (k == #voicing) and h.vol + 1 or h.vol
            local dur = lengthMs(song, h.s, h.len) * (h.ring and 1 or 0.9)
            play(synth, 'keys', keysPatch, t + (k - 1) * strum, note, math.min(7, vol), dur)
            -- the dub echo: the stab again a dotted 8th later, quieter, only while its chord lasts
            if style.echo and style.echo.keys and not h.sidestep then
                for e = 1, 2 do
                    local s, chordEnd = h.s + 3 * e, h.chord.s + h.chord.len
                    if s >= chordEnd or vol - 2 * e < 1 then break end
                    local echoDur = math.min(dur, lengthMs(song, s, chordEnd - s) * 0.9) -- not into the next chord
                    play(synth, 'keys', keysPatch, stepTime(song, t0, s) + (k - 1) * strum, note, vol - 2 * e, echoDur)
                end
            end
        end
    end

    -- lofi: the groove first (the bass plays on its kicks), the tape's tone, the vinyl
    local groove = style.drums == 'jazzhop'
        and lofiGroove(song, section.kind, j, section.bars, band and roles.drums or 'none', stream(song.seed, 3000 + b))
    if song.tone then bookTone(synth, song, section, j, rnd) end
    if style.vinyl then
        if j == 0 then -- the hiss bed, one long note a section, crossfading into the next
            play(synth, 'vinyl', 'hiss', t0, 60, 4, lengthMs(song, 0, 16 * section.bars) + 300)
        end
        local ticks = (section.kind == 'intro' or section.kind == 'outro') and 5 or 3
        for _ = 1, ticks do play(synth, 'vinyl', 'crackle', stepTime(song, t0, rnd(16)), 90 + rnd(12), 1, 8) end
    end

    -- the bass: the left hand, or the upright when the band plays with it; the outro's last bar rests
    local upright = band and lib.upright and roles.drums ~= 'none'
    local bassPatch = upright and 'musicBass' or style.bassPatch or keysPatch
    local lo = upright and 34 or style.bassLo or (style.bass == 'guaraldi' and 38 or 40)
    local bassLine = bassLines[style.bass] or bassLines.hold
    local bassRole = roles.bass or 'play'
    if bassRole == 'none' or (bassRole == 'last' and j < section.bars - 1) then -- luacheck: ignore 542
        -- the bass sits this one out
    elseif section.kind == 'outro' and j == 2 then
        play(synth, 'bass', bassPatch, t0, inRange(chords[1].root, lo), 5, lengthMs(song, 0, 32))
    elseif style.bass == 'lofi' then
        local stop = groove and groove.stop or 16
        local function hit(s, midi, vol, len)
            len = math.min(len, stop - s)
            if len <= 0 then return end
            play(synth, 'bass', bassPatch, stepTime(song, t0, s) + 0.003 + humanize(0.004), midi, vol,
                 lengthMs(song, s, len))
        end
        local steps, seen = { useKicks = bassRole == 'play' and section.kind ~= 'outro' }, {}
        if steps.useKicks and groove then
            for _, k in ipairs(groove.kicks) do if not seen[k] then seen[k] = true; steps[#steps + 1] = k end end
        end
        for _, chord in ipairs(chords) do
            if not seen[chord.s] then seen[chord.s] = true; steps[#steps + 1] = chord.s end
        end
        table.sort(steps)
        local nextRoot = nextChords and (song.key + nextChords[1].degree) % 12
        lofiBass(hit, chords, nextRoot, steps, stop, stream(song.seed, 4000 + b), song.legato and 0.92 or 0.55)
    elseif not (section.kind == 'outro' and j > 2) then
        local stop = pushes and 14 or sidestepAt or 16 -- the bass lets go when the next chord comes in early
        local function hit(s, midi, vol, len)
            len = math.min(len, stop - s)
            if len <= 0 then return end
            local t = stepTime(song, t0, s) + humanize(0.004)
            play(synth, 'bass', bassPatch, t, midi, vol, lengthMs(song, s, len) * 0.95)
        end
        local nextRoot = nextChords and (song.key + nextChords[1].degree) % 12
        local function fits(midi, chord) return not rubs(song, midi, chord) end
        for _, chord in ipairs(chords) do
            bassLine(hit, chord, lo, chord.s + chord.len == 16, nextRoot, fits)
        end
    end

    -- the riff: the song's own pattern over the chord's voicing, in eighths; it starts the intro
    -- alone and rings out in the outro
    if style.riff and not (section.kind == 'outro' and j >= 2) then
        for i, voice in ipairs(song.riff) do
            local s = (i - 1) * 2
            if voice > 0 then
                local chord = chordAtStep(song, b, s)
                local root = (song.key + chord.degree) % 12
                local voicing = voiceChord(root, qualityOf(song, chord.quality), 48, 76, M.voicing)
                local note = voicing[math.min(voice, #voicing)]
                local vol = (s % 4 == 0) and 4 or 3
                local t = stepTime(song, t0, s) + humanize(0.004)
                local len = math.min(3, chord.s + chord.len - s) -- rings a little, never into the next chord
                play(synth, 'riff', style.riff, t, note, vol, lengthMs(song, s, len) * 0.95)
            end
        end
    end

    -- the drums, where the form and the play let them
    if groove then -- lofi's groove: the snare and the rim laid back by the song's lag
        local patches = { K = { 'lofiKick', 32 }, S = { 'snare', 60 }, H = { 'hat', 60 }, R = { 'rim', 79 } }
        for _, h in ipairs(groove.hits) do
            local patch = patches[h.lane]
            local lag = (h.lane == 'S' or h.lane == 'R') and song.snareLag or 0
            local t = stepTime(song, t0, h.s) + lag + humanize(h.lane == 'H' and 0.006 or 0.004)
            local vol = math.max(1, math.min(7, math.floor(h.vel * (h.lane == 'H' and 4.5 or 7) + 0.5)))
            local dur = h.lane == 'K' and 200 or h.lane == 'S' and 140 or h.open and 160 or 30
            play(synth, 'drums', patch[1], t, patch[2], vol, dur)
            if h.lane == 'S' and not h.ghost then play(synth, 'drums', 'lofiKick', t, 48, math.max(1, vol - 2), 90) end
        end
    end
    local kit = not groove and style.drums and drumKits[style.drums]
    local drums = roles.drums == 'full' or (roles.drums == 'outro' and j < 2)
    if kit and band and drums then
        local function hit(s, patch, midi, vol, dur, dt)
            local drag = (style.swing > 0.5 and s % 8 == 4) and 0.008 or 0 -- the backbeat lays back a hair
            local t = stepTime(song, t0, s) + drag + (dt or 0) + humanize(0.003)
            play(synth, 'drums', patch, t, midi, vol, dur)
        end
        kit(hit, rnd, section.kind, j, song.fill[b])
    end

    -- the tune
    if lib.melody and roles.lead and song.hasLead ~= false then
        local phraseBar = b - j % 4
        if song.phraseBar ~= phraseBar then song.phrase, song.phraseBar = buildPhrase(song, phraseBar), phraseBar end
        local patch = lib.melodyPatch or style.lead
        local barInPhrase = j % 4
        for _, note in ipairs(song.phrase) do
            if math.floor(note.s / 16) == barInPhrase then
                local t = stepTime(song, t0, note.s % 16) + humanize(0.003)
                if note.grace then play(synth, 'lead', patch, t - 0.05, note.grace, math.max(1, note.vol - 2), 45) end
                play(synth, 'lead', patch, t, note.midi, note.vol, lengthMs(song, note.s % 16, note.len) * 0.9)
            end
        end
    end
end

-- The style was just picked: skip the intro into the first A with the tune and the band in, so the
-- new style is heard at once. The band lifts the play level, so it leaves again as play calms down.
local function audition(song)
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
    M.activity = math.max(M.activity, 2 * lib.bandJoins)
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
    if not song or wrongStyle then
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
    song.bar = song.bar + 1
    bookBar(synth, t0, song, song.bar)
    return song.barLength
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

-- The audio time of 16th step s (0..15, fractions fine) of the latest booked bar, on the song's swing.
function lib.stepAt(s)
    local song = M.song
    if not (song and M.barStart) then return nil end
    return stepTime(song, M.barStart, s)
end

-- what is playing, for a console or a HUD: style, key, section
function lib.nowPlaying()
    local song = M.song
    if not song then return nil end
    local section = song.barSection[math.max(1, math.min(song.bars, song.bar))]
    return { style = song.style, key = song.key, section = section and section.kind, bar = song.bar, bars = song.bars,
             stepTime = M.barStart, stepLen = song.beat / 4 } -- the latest booked bar's step 0, in audio time
end

function lib.update(synth, now)
    if M.lastNow then M.activity = M.activity * 0.5 ^ ((now - M.lastNow) / lib.activityHalfLife) end
    M.lastNow = now
    if not lib.enabled then return end
    local t = synth.audioTime()
    if not t then return end
    M.audioTime = t
    -- first call, or back from a pause: start fresh a moment from now
    if not M.barAt or M.barAt < t then M.barAt = t + 0.2 end
    while M.barAt < t + lib.lookahead do
        M.barAt = M.barAt + bookNext(synth, M.barAt)
    end
end

return lib
