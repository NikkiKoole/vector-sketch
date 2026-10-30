-- music-styles.lua
-- The music's data (src/music.lua re-exports every name as music.<name>): the set and its keys,
-- chord qualities, forms, comp cells, the styles, and each style's own tables (puppetmaker, strum,
-- satie, ambient, city pop's figures), the tune's motifs and riffs, the horn shouts. No state.

local D = {}

D.set = { 'bossa', 'guaraldi', 'island', 'dusk', 'dumont', 'supermarket', 'herbs', 'lofi', 'puppetmaker', 'strum',
            'satie', 'ambient', 'sesame', 'citypop', 'buymode', 'rollo', 'jingle' }
D.lookahead = 0.3          -- seconds of music booked ahead
D.activityHalfLife = 8     -- seconds for the play level to halve
D.bandJoins = 4            -- play level at which the rhythm section comes in...
D.bandLeaves = 1.5         -- ...and below which it leaves again

D.keys = { 5, 10, 3, 8 }   -- F, Bb, Eb, Ab: warm keys, a fourth apart, so the set walks between them
-- Chord qualities, as intervals over the root. Each style keeps to its own vocabulary, so the songs
-- don't all sound like the same jazz: the jazz (bossa, guaraldi) is rootless (the bass owns the root),
-- plain sevenths for supermarket and herbs, triads and their pop colours for island, quartal minor
-- for dumont. stack = true: voice it as written (a stacked shape), only moved by octaves.
D.qualities = { maj9 = { 4, 7, 11, 14 }, m9 = { 3, 7, 10, 14 }, dom9 = { 4, 10, 14, 21 },
                  lydian = { 4, 11, 14, 18 },  -- maj9#11: third, seventh, ninth, raised fourth
                  maj69 = { 4, 7, 9, 14 },     -- the sixth and ninth: Guaraldi's sunny tonic
                  sus = { 5, 7, 10, 14 },      -- 9sus4 (V11): a dominant that floats instead of pulls
                  maj7 = { 4, 7, 11, 12 }, m7 = { 3, 7, 10, 12 }, dom7 = { 0, 4, 7, 10 },
                  maj = { 0, 4, 7 }, min = { 0, 3, 7 }, maj6 = { 0, 4, 7, 9 },
                  add9 = { 0, 7, 14, 16, stack = true }, sus2 = { 0, 2, 7 }, sus4 = { 0, 5, 7 },
                  m11 = { 5, 10, 15, 19, stack = true }, -- So What: 11 b7 b3 5, fourths and a third
                  -- lofi's jazz on top of the rest: the dominant colours and the minor key's ii
                  n9 = { 4, 10, 14 }, b9 = { 4, 7, 10, 13 }, s9 = { 4, 7, 10, 15 },
                  m7b5 = { 3, 6, 10, 14 }, m6 = { 3, 7, 9, 14 },
                  alt = { 4, 10, 15, 20 }, -- citypop's 7alt: 3 b7 #9 b13, the Just the Two of Us crunch
                  dim7 = { 0, 3, 6, 9 },   -- buymode's passing diminished
                  -- strum's guitar chords (their grips are D.grips)
                  gmaj = { 0, 4, 7 }, gadd9 = { 0, 4, 7, 14 }, gmaj7 = { 0, 4, 7, 11 }, gmaj9 = { 0, 4, 7, 11, 14 },
                  gm7 = { 0, 3, 7, 10 }, gm9 = { 0, 3, 7, 10, 14 }, g9sus4 = { 0, 5, 7, 10, 14 },
                  gsus4add9 = { 0, 5, 7, 14 },
                  -- jingle's rootless three-voice guitar shapes, every one with a 9 on top; jbVII and
                  -- jbIII are the borrowed chords, voiced per song (song.flavor)
                  jmaj = { 4, 7, 14 }, jmaj7 = { 4, 11, 14 }, j7 = { 4, 10, 14 },
                  jm = { 3, 7, 14 }, jm7 = { 3, 10, 14 }, jm6 = { 3, 9, 14 } }

-- strum's guitar: standard tuning low to high, and E-shape barre grips from dreamengine's
-- pedalboard.c (fret offsets above the barre per string, -1 = damped). The barre sits on the
-- chord's root on the low E string.
D.guitarOpen = { 40, 45, 50, 55, 59, 64 }
D.grips = {
    gmaj = { 0, 2, 2, 1, 0, 0 }, gadd9 = { 0, 2, 2, 1, 0, 2 }, gmaj7 = { 0, 2, 1, 1, 0, 0 },
    gmaj9 = { 0, 2, 1, 1, 0, 2 }, gm7 = { 0, 2, 0, 0, 0, 0 }, gm9 = { 0, 2, 0, 0, 0, 2 },
    g9sus4 = { 0, 2, 0, 2, 0, 2 }, gsus4add9 = { 0, 2, 2, 2, 0, 2 },
}

-- the forms, { section, bars }; songs grow no longer than this (a minute or so: a set keeps moving)
D.forms = {
    { { 'intro', 2 }, { 'A', 8 }, { 'A', 8 }, { 'B', 8 }, { 'A', 8 }, { 'outro', 4 } }, -- AABA, the standard
    { { 'intro', 4 }, { 'A', 8 }, { 'B', 8 }, { 'A', 8 }, { 'B', 8 }, { 'outro', 4 } },
}

-- buymode's form, after Mall Rat: lift = the section a half step up (the jingle's key change), prog =
-- the section's own chords (style.progs), lead = false: the tune rests
D.buymodeForms = {
    { { 'intro', 4, prog = 'sway' }, { 'A', 8 }, { 'A', 8 }, { 'B', 8 }, { 'A', 8, lift = 1 },
      { 'turn', 4, prog = 'turn', lead = false }, { 'A', 8 }, { 'outro', 4, prog = 'float' } },
}

-- jingle's form: verse (A), chorus (B), each a 4-chord progression played twice
D.jingleForms = {
    { { 'intro', 4 }, { 'A', 8 }, { 'B', 8 }, { 'A', 8 }, { 'B', 8 }, { 'outro', 4 } },
    { { 'intro', 4 }, { 'A', 8 }, { 'A', 8 }, { 'B', 8 }, { 'B', 8 }, { 'outro', 4 } },
}

-- lofi city's forms (and a break: the keys holding, the drums out or on the rim): longer songs
D.lofiForms = {
    { { 'intro', 4 }, { 'A', 8 }, { 'A', 8 }, { 'B', 8 }, { 'break', 4 }, { 'A', 8 }, { 'B', 8 }, { 'outro', 4 } },
    { { 'intro', 2 }, { 'A', 8 }, { 'B', 8 }, { 'A', 8 }, { 'break', 8 }, { 'B', 8 }, { 'A', 8 }, { 'outro', 4 } },
    { { 'intro', 4 }, { 'A', 16 }, { 'break', 4 }, { 'B', 8 }, { 'A', 16 }, { 'outro', 4 } },
}

-- Comps shared between styles by name (a style's comps = 'name'): how the chords are played,
-- kept apart from which chords, so another song can reuse the feel.
D.comps = {
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
D.styles = {
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
        strumMs = 12, keys = 'piano', lead = 'pianoLead', bass = 'guaraldi', bassLo = 38, drums = 'brushes',
        home = 'maj69',
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
    -- marimba riff (the song's own, D.riffs) carrying the groove, a bouncy root and fifth, a
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
    -- dusk: island's second flavor, the island in the evening. The same band and the same jobs (the
    -- keys only holding, a riff off the chord's voicing, a bouncy root and fifth, a tune that comes
    -- back, the drums only when play is busy), slower and lazier, with more space: a worn felt piano
    -- holding (and bouncing the bass), a sparser kalimba riff with holes in it, a tongue drum plonking
    -- the tune, a kit of a kick, a brush sweep and one rim on 4. Its own
    -- chords: open maj7s, add9 and sus4, the bVII and the bIII instead of island's iv and bVI.
    dusk = {
        bpm = { 86, 94 }, swing = 0.6, chordBars = { 1, 2 }, lydianChance = 0, pushOdds = 0, motifRepeat = 30,
        strumMs = 25, keys = 'feltKeys', lead = 'tongueDrum', bass = 'bounce', drums = 'dusk', home = 'add9',
        riff = 'kalimba', riffs = 'dusk', range = { 64, 81 },
        A = {
            { { 0, 'maj7' }, { 5, 'add9' }, { 0, 'maj7' }, { 5, 'add9' } },  -- I IV, rocking
            { { 0, 'add9' }, { 10, 'maj' }, { 5, 'maj7' }, { 7, 'sus4' } },  -- I bVII IV Vsus
            { { 5, 'maj7' }, { 4, 'min' }, { 2, 'min' }, { 0, 'add9' } },    -- IV iii ii I, walking down
            { { 0, 'maj7' }, { 9, 'min' }, { 5, 'add9' }, { 7, 'sus4' } },   -- I vi IV Vsus
        },
        B = {
            { { 9, 'min', 4 }, { 5, 'maj7', 4 }, { 0, 'add9', 4 }, { 7, 'sus4', 4 } },  -- vi IV I Vsus
            { { 3, 'add9', 4 }, { 10, 'maj', 4 }, { 5, 'maj7', 4 }, { 7, 'sus4', 4 } }, -- bIII bVII IV V, the odd one
        },
        comps = { { { 0, 14, 3 }, { 16, 14, 3 } } }, -- the piano holds, quietly: the riff is the comp
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
    -- staccato Rhodes stabs (D.comps.bounce), the left hand bouncing root and fifth, a marimba
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
        bassPatch = 'roundBass', bassLo = 33, groove = 'lofi', introHats = true, home = 'maj9', homeMinor = 'm9',
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
    -- outside), sparse when calm (its editor, one Mipo). Pattern: D.puppetmaker.
    puppetmaker = { loop = true, bpm = 60, swing = 0.52, swing16 = true, bars = 16 },
    -- strum: one clean electric guitar, Travis-picked (after dreamengine's pedalboard.c), and nothing
    -- else: background music. The thumb alternates root and fifth on the beat, a treble string on every
    -- off-beat and one with the thumb on 1 and 3, on real barre grips (D.grips). Puppetmaker's open
    -- chord moves, B's last chord planned outside the key. The guitar's pedals turn with the sections
    -- (pedals per section kind: tape { wow, flutter, saturation, warble }, flanger { rate, depth,
    -- feedback, mix }): a hint of flanger in the intro, moving in A, B a slow full jet sweep, the outro
    -- through-zero and the tape at its most worn. The outro ends on one strum.
    strum = {
        bpm = { 72, 82 }, swing = 0.58, chordBars = { 1, 2 }, pushOdds = 0, turnaroundOdds = 0, leadChance = 0,
        picking = 'travis', pickPatch = 'guitar', home = 'gadd9',
        A = {
            { { 0, 'gadd9' }, { 5, 'gmaj9' }, { 9, 'gm7' }, { 7, 'g9sus4' } },     -- I IV vi V
            { { 0, 'gadd9' }, { 9, 'gm9' }, { 5, 'gmaj7' }, { 0, 'gadd9' } },      -- I vi IV I
            { { 5, 'gmaj9' }, { 0, 'gadd9' }, { 2, 'gm7' }, { 7, 'gsus4add9' } },  -- IV I ii V
            { { 0, 'gmaj9' }, { 4, 'gm7' }, { 5, 'gadd9' }, { 2, 'gm9' } },        -- I iii IV ii
        },
        B = { -- the last chord floats: the same kind of chord on a root outside the key
            { { 5, 'gmaj9', 8 }, { 0, 'gadd9', 8 }, { 2, 'gm9', 8 }, { 10, 'gadd9', 8 } },   -- IV I ii bVII
            { { 9, 'gm7', 8 }, { 5, 'gmaj9', 8 }, { 0, 'gadd9', 8 }, { 8, 'gmaj7', 8 } },    -- vi IV I bVI
            { { 0, 'gadd9', 8 }, { 4, 'gm7', 8 }, { 5, 'gadd9', 8 }, { 3, 'gadd9', 8 } },    -- I iii IV bIII
        },
        comps = { { { 0, 16, 4 }, { 16, 16, 4 } } }, -- the planner wants one; the picking hand plays instead
        pedals = {
            intro = { tape = { 0.2, 0.06, 0.2, 0.05 }, flanger = { 0.3, 0.3, 0.3, 0.2 } },
            A = { tape = { 0.25, 0.08, 0.25, 0.1 }, flanger = { 0.25, 0.5, 0.5, 0.35 } },
            -- the jet at 0.85: 0.95 resonates (peaks 4x the guitar's, +3.6 dB rms)
            B = { tape = { 0.4, 0.12, 0.3, 0.2 }, flanger = { 0.1, 1.0, 0.85, 0.8 } },
            outro = { tape = { 0.55, 0.15, 0.3, 0.35 }, flanger = { 0.05, 1.0, -0.85, 0.85 } },
        },
    },
    -- rollo: after the electric guitar in King Rollo's "The Tree" (docs/MUSIC-ANALYSIS.md). A picked
    -- electric bass holds the root on 1 and 3, a choked guitar stabs a high triad on the and of 2 and
    -- the and of 4, and nothing else: straight eighths, mostly I and V, on a worn cassette (the tape).
    rollo = {
        bpm = { 110, 118 }, swing = 0.5, chordBars = { 1, 1 }, pushOdds = 0, turnaroundOdds = 0, leadChance = 0,
        picking = 'jabs', pickPatch = 'jabGuitar', bassPatch = 'pickBass', flute = 'flute', home = 'gmaj',
        A = {
            { { 0, 'gmaj', 8 }, { 7, 'gmaj', 8 }, { 0, 'gmaj', 8 }, { 7, 'gmaj', 8 } },   -- I V I V
            { { 0, 'gmaj', 8 }, { 7, 'gmaj', 8 }, { 5, 'gmaj', 8 }, { 7, 'gmaj', 8 } },   -- I V IV V
            { { 0, 'gmaj', 8 }, { 5, 'gmaj', 8 }, { 7, 'gmaj', 8 }, { 0, 'gmaj', 8 } },   -- I IV V I
        },
        B = {
            { { 9, 'gm7', 8 }, { 4, 'gm7', 8 }, { 5, 'gmaj', 8 }, { 7, 'gmaj', 8 } },     -- vi iii IV V
            { { 5, 'gmaj', 8 }, { 0, 'gmaj', 8 }, { 2, 'gm7', 8 }, { 7, 'gmaj', 8 } },    -- IV I ii V
        },
        comps = { { { 0, 16, 4 }, { 16, 16, 4 } } }, -- the planner wants one; the jabs play instead
        pedals = { -- tape { wow, flutter, saturation, warble }; the flanger off (mix 0)
            intro = { tape = { 0.3, 0.12, 0.35, 0.15 }, flanger = { 0.25, 0.5, 0.5, 0 } },
            A = { tape = { 0.3, 0.12, 0.35, 0.15 }, flanger = { 0.25, 0.5, 0.5, 0 } },
            B = { tape = { 0.4, 0.15, 0.4, 0.25 }, flanger = { 0.25, 0.5, 0.5, 0 } },
            outro = { tape = { 0.55, 0.18, 0.4, 0.35 }, flanger = { 0.25, 0.5, 0.5, 0 } },
        },
    },
    -- jingle: Mac DeMarco at dusk, after dreamengine's jingle.c (Reverb Machine's "Mac DeMarco Chord
    -- Theory"). A chorused electric guitar fingerpicking the chord's three voices in 8ths, a soft round
    -- bass voice-led so the chromatic templates walk down by semitone, a rim and hat on 2 and 4 (the
    -- kick joins in the chorus), Juno chords held under it all (juno.c's saw pad and chorus), a sine
    -- tune with a vibrato in the chorus. Verse (A) and chorus (B)
    -- progressions are lifted from the songs; the bVII (maj, 7 or 9) and the bIII (maj7 or m6) are
    -- borrowed and voiced per song. Over a borrowed chord the tune keeps to that chord's own tones.
    -- Parts: the guitar is 'keys', the Juno 'strings', so the layers keep the guitar (cellar: guitar and
    -- bass; quiet: guitar, Juno and tune).
    jingle = {
        bpm = { 72, 92 }, swing = 0.52, chordBars = { 1 }, pushOdds = 0, turnaroundOdds = 0,
        picking = 'jingle', pickPatch = 'jingleGuitar', bassPatch = 'jingleBass', lead = 'jingleLead',
        padPatch = 'junoPad',
        home = 'jmaj7', forms = 'jingle',
        A = {
            { { 0, 'jmaj' }, { 2, 'jm7' }, { 9, 'jm7' }, { 10, 'jbVII' } },     -- Blue Boy: I ii vi bVII
            { { 0, 'jmaj' }, { 7, 'jmaj' }, { 10, 'jbVII' }, { 5, 'jmaj' } },   -- Dreaming: I V bVII IV
            { { 0, 'jmaj7' }, { 9, 'jm7' }, { 2, 'jm7' }, { 7, 'j7' } },        -- Moonlight, verse: I vi ii V9
            { { 5, 'jmaj' }, { 4, 'jm' }, { 3, 'jbIII' }, { 4, 'jm' } },        -- Another One: IV iii bIII iii
        },
        B = {
            { { 0, 'jmaj7', 4 }, { 3, 'jbIII', 4 }, { 2, 'jm7', 4 }, { 7, 'j7', 4 } },   -- Stars Keep Calling
            { { 3, 'jbIII', 4 }, { 9, 'jm7', 4 }, { 2, 'jm7', 4 }, { 7, 'j7', 4 } },     -- Moonlight, chorus
            { { 5, 'jmaj', 4 }, { 4, 'jm', 4 }, { 3, 'jbIII', 4 }, { 4, 'jm', 4 } },     -- Another One
            { { 9, 'jm7', 4 }, { 8, 'jmaj7', 4 }, { 7, 'jm', 4 }, { 0, 'j7', 4 } },      -- A Heart Like Hers
        },
        flavors = { jbVII = { 'jmaj', 'j7', 'j7' }, jbIII = { 'jmaj7', 'jmaj7', 'jm6' } },
        comps = { { { 0, 16, 4 }, { 16, 16, 4 } } }, -- the planner wants one; the picking hand plays instead
    },
    -- sesame: a 70s TV small band (old Sesame Street's jazz), quick and swung. A clavinet chopping
    -- the off-beats, the upright in two while it's calm and walking when the band joins, a vibes tune,
    -- sticks on the ride, and short horn shouts in the bar where the tune breathes (D.hornHits).
    sesame = {
        bpm = { 148, 164 }, swing = 0.6, chordBars = { 1, 2 }, pushOdds = 30, motifRepeat = 25,
        strumMs = 3, keys = 'clav', lead = 'vibes', bass = 'walk', bassPatch = 'musicBass', bassLo = 34,
        drums = 'sticks', home = 'maj6', horns = true,
        A = {
            { { 0, 'maj6' }, { 9, 'dom7' }, { 2, 'm7' }, { 7, 'dom7' } },               -- I VI7 ii V
            { { 0, 'maj6' }, { 5, 'dom7' }, { 0, 'maj6' }, { 7, 'dom7' } },             -- I IV7 I V7, the kids' blues
            { { 0, 'maj6' }, { 4, 'm7' }, { 9, 'dom7' }, { 2, 'm7', 2 }, { 7, 'dom7', 2 } }, -- I iii VI7 ii V
            { { 0, 'maj6' }, { 0, 'dom7' }, { 5, 'maj6' }, { 5, 'm6' } },               -- I I7 IV iv, sunny to wistful
        },
        B = {
            { { 4, 'dom7', 8 }, { 9, 'dom7', 8 }, { 2, 'dom7', 8 }, { 7, 'dom7', 8 } },  -- III7 VI7 II7 V7
            { { 5, 'maj7', 8 }, { 5, 'm6', 8 }, { 0, 'maj6', 8 }, { 7, 'dom7', 8 } },   -- IV iv I V
            { { 2, 'm7', 4 }, { 7, 'dom7', 4 }, { 0, 'maj6', 8 }, { 2, 'm7', 4 }, { 7, 'dom7', 4 },
              { 4, 'm7', 4 }, { 9, 'dom7', 4 } },                                       -- ii V I, ii V iii VI
        },
        -- the clav: the off-beat chang, Charleston chops, 2 and 4 with a skip
        comps = {
            { { 2, 1, 4 }, { 6, 1, 3 }, { 10, 1, 4 }, { 14, 1, 3 },
              { 18, 1, 4 }, { 22, 2, 4 }, { 26, 1, 4 }, { 30, 1, 3 } },
            { { 0, 2, 4 }, { 6, 1, 3 }, { 8, 2, 4 }, { 14, 1, 4 },
              { 16, 2, 4 }, { 22, 1, 3 }, { 24, 2, 4 }, { 30, 1, 4 } },
            { { 4, 1, 4 }, { 6, 1, 3 }, { 12, 1, 4 }, { 14, 1, 3 },
              { 20, 1, 4 }, { 22, 1, 3 }, { 28, 1, 4 }, { 30, 2, 4 } },
        },
    },
    -- citypop: Tatsuro Yamashita, Mariya Takeuchi, Anri; after dreamengine's citypop2.c. Glossy and
    -- session-tight (straight 16ths, no lag): the Rhodes comping, a fingered bass popping octaves and
    -- running chromatically into each change (D.cityBass), a clean guitar cutting 16ths, a string
    -- pad under the chorus (B), trumpets in the bar the tune breathes, a glossy synth on the tune, a
    -- disco or funk kit. A is the verse, B the chorus on the Royal Road or Just the Two of Us.
    citypop = {
        bpm = { 104, 118 }, swing = 0.5, chordBars = { 1 }, pushOdds = 35, turnaroundOdds = 0,
        strumMs = 4, keys = 'rhodes', lead = 'citySynth', bass = 'disco', bassPatch = 'dubBass', bassLo = 33,
        drums = 'session', home = 'maj9', horns = 'citypop', guitar = true, strings = true,
        A = {
            { { 2, 'm9' }, { 7, 'dom9' }, { 0, 'maj9' }, { 9, 'm9' } },                   -- ii V I vi, smooth
            { { 0, 'maj9' }, { 0, 'n9' }, { 5, 'maj7' }, { 5, 'm6' } },                   -- the descent: I I7 IV iv
            { { 5, 'maj7' }, { 4, 'alt' }, { 9, 'm9' }, { 7, 'm7', 2 }, { 0, 'n9', 2 } }, -- Just the Two of Us
            { { 2, 'm7' }, { 4, 'alt' }, { 9, 'm9' }, { 9, 'm9' } },                      -- ii III7 vi, the minor one
        },
        B = {
            { { 5, 'maj9', 4 }, { 7, 'dom9', 4 }, { 4, 'm7', 4 }, { 9, 'm9', 4 },
              { 5, 'maj9', 4 }, { 7, 'dom9', 4 }, { 4, 'm7', 4 }, { 9, 'm9', 4 } },      -- the Royal Road
            { { 5, 'maj9', 4 }, { 7, 'dom9', 4 }, { 4, 'm7', 4 }, { 9, 'm7', 2 }, { 7, 'sus', 2 },
              { 5, 'maj9', 4 }, { 7, 'dom9', 4 }, { 4, 'm7', 4 }, { 9, 'm7', 2 }, { 7, 'sus', 2 } }, -- turned back
            { { 5, 'maj7', 4 }, { 4, 'alt', 4 }, { 9, 'm9', 4 }, { 7, 'm7', 2 }, { 0, 'n9', 2 },
              { 5, 'maj7', 4 }, { 4, 'alt', 4 }, { 9, 'm9', 4 }, { 7, 'm7', 2 }, { 0, 'n9', 2 } },  -- JTTOU
        },
        -- Charleston into anticipations, the funk stabs, anticipations into halves
        comps = {
            { { 0, 3, 4 }, { 6, 10, 3 }, { 16, 6, 4 }, { 22, 2, 3 }, { 26, 6, 3 } },
            { { 0, 2, 4 }, { 3, 2, 2 }, { 6, 2, 3 }, { 10, 2, 2 }, { 12, 4, 3 },
              { 16, 2, 4 }, { 19, 2, 2 }, { 22, 2, 3 }, { 26, 2, 2 }, { 28, 4, 3 } },
            { { 0, 6, 4 }, { 6, 2, 3 }, { 10, 6, 3 }, { 16, 8, 4 }, { 24, 8, 3 } },
        },
    },
    -- buymode: the Sims 1 buy-mode piano trio, after Jerry Martin's Mall Rat (its chords and moves, read
    -- off the recording; never its tune). Straight and peppy, about 112 bpm: a felt piano comping and
    -- singing the tune, the upright in two (walking when the band joins), a light kit. The intro sways
    -- I to bVII, A and B are I-ii-V with sixths and passing diminished chords, then the jingle's key
    -- change: an A a half step up, a turn round the fifths back home (III7 VI7 II7 V7), the last A at
    -- home, and an ending that floats between I6 and bII6.
    buymode = {
        bpm = { 108, 116 }, swing = 0.5, chordBars = { 1 }, pushOdds = 25, turnaroundOdds = 0, motifRepeat = 25,
        strumMs = 10, keys = 'piano', lead = 'pianoLead', bass = 'walk', bassPatch = 'musicBass', bassLo = 34,
        drums = 'lounge', home = 'maj69', forms = 'buymode',
        A = {
            { { 0, 'maj69' }, { 2, 'm7', 2 }, { 7, 'dom7', 2 }, { 0, 'maj69' }, { 9, 'm7', 2 }, { 7, 'dom7', 2 } },
            { { 0, 'maj69' }, { 4, 'm7' }, { 2, 'm7', 2 }, { 7, 'dom7', 2 }, { 0, 'maj69', 2 }, { 1, 'dim7', 2 } },
            { { 0, 'maj7' }, { 5, 'maj69' }, { 11, 'm7b5', 2 }, { 4, 'dom7', 2 }, { 9, 'm7', 2 }, { 7, 'dom7', 2 } },
            { { 0, 'maj69' }, { 10, 'maj7' }, { 0, 'maj69' }, { 2, 'm7', 2 }, { 7, 'dom7', 2 } },
        },
        B = {
            { { 5, 'maj69', 8 }, { 7, 'dom7', 8 }, { 4, 'm7', 4 }, { 9, 'dom7', 4 }, { 2, 'm7', 4 }, { 7, 'dom7', 4 } },
            { { 2, 'm7', 4 }, { 7, 'dom7', 4 }, { 0, 'maj7', 8 }, { 2, 'm7', 4 }, { 7, 'dom7', 4 },
              { 4, 'm7', 4 }, { 3, 'dim7', 4 } },
        },
        -- the sections with chords of their own (D.buymodeForms)
        progs = {
            sway = { { 0, 'maj7', 4 }, { 10, 'maj7', 4 } },                                   -- I bVII
            turn = { { 4, 'dom7', 4 }, { 9, 'dom7', 4 }, { 2, 'dom7', 4 }, { 7, 'dom7', 4 } },  -- round the fifths
            float = { { 0, 'maj6', 4 }, { 1, 'maj6', 4 } },                                   -- I6 bII6
        },
        -- the piano: 1, the and-of-2, 3, the and-of-4; the off-beat chank; long and short
        comps = {
            { { 0, 2, 3 }, { 6, 2, 2 }, { 8, 2, 3 }, { 14, 2, 2 },
              { 16, 2, 3 }, { 22, 2, 2 }, { 24, 2, 3 }, { 30, 2, 2 } },
            { { 4, 2, 3 }, { 10, 2, 2 }, { 12, 2, 3 }, { 20, 2, 3 }, { 26, 2, 2 }, { 28, 2, 3 } },
            { { 0, 4, 3 }, { 6, 2, 2 }, { 12, 4, 2 }, { 16, 4, 3 }, { 22, 2, 2 }, { 28, 4, 2 } },
        },
    },
    -- satie: a Gymnopédie-like waltz in 3/4, slow, no drums. Root on 1, chord on 2, a felt-piano tune
    -- falling by step over rocking sevenths (D.satie). A planned song: intro, A A B A, a ringing outro.
    satie = { loop = 'satie', meter = 3, bpm = { 66, 74 }, swing = 0.5 },
    -- ambient: Yoshimura / Music for Airports. Pentatonic figures looping at unequal lengths over a
    -- drone, drifting against each other (D.ambient). No drums, no chords, no tune.
    ambient = { loop = 'ambient', bpm = { 60, 66 }, swing = 0.5 },
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
-- the crowd), sparse = page 2 (the editor). The chord is the rhodes2 sample: one up-strummed voicing,
-- only its root moves. Measured on the recording (2026-10-29): Eb3 Bb3 G4 Bb4 C5 Eb5 (root + 0 7 16 19
-- 21 24), a hand's strum (quick through the first four, then a lag before the top two), blooming for
-- half a second and ringing past 3 s.
D.puppetmaker = {
    chord = { 0, 7, 16, 19, 21, 24 }, strum = { 0, 29, 52, 75, 151, 191 }, chordRoot = 51, chordMs = 3000,
    dense = {
        { 'conga', 52, 420, { { 1, 50 }, { 5, 50 }, { 9, 60 }, { 13, 60 } } },                  -- conga low
        { 'conga', 62, 140, { { 2, 80 }, { 7, 80 }, { 10, 80 }, { 3, 60 }, { 6, 60 }, { 11, 60 },
                              { 14, 90 }, { 15, 90 } } },                                         -- bongo low
        { 'conga', 69, 130, { { 1, 80 }, { 5, 80 }, { 10, 80 }, { 14, 80 }, { 3, 50 }, { 7, 50 },
                              { 9, 40 }, { 12, 70 } } },                                          -- bongo high
        { 'tamb', 60, 290, { { 1, 100 }, { 10, 100 }, { 13, 100 }, { 3, 80 }, { 4, 80 }, { 15, 80 },
                             { 16, 80 }, { 12, 70 }, { 8, 30 } } },
        { 'guiro', 60, 245, { { 8, 50 } } },
        { 'triangle', 100, 90, { { 5, 60 }, { 13, 80 } } },                                      -- 101, choked
        { 'triangleRing', 100, 1800, { { 6, 60 }, { 14, 40 } } },                                -- 103, ringing
        { 'chord', 0, 0, { { 9, 50, true } } },
        { 'sample:ba', 60, 400, { { 8, 5, true } } },        -- babirhodes' voices: samples, played by the
        { 'sample:bi', 60, 200, { { 12, 5, true } } },       -- onNote listener (like the Mipos' mi/po),
        { 'sample:biep2', 60, 300, { { 16, 5, true } } },    -- midi 60 = the sample's own pitch
        { 'sample:biep3', 60, 300, { { 3, 5, true } } },
        { 'sample:pi', 60, 284, { { 4, 50 }, { 12, 50 }, { 14, 90, true } } },           -- the Mipos sing (only
        { 'sample:po3', 60, 693, { { 2, 20, true }, { 10, 20, true }, { 16, 30, true } } }, -- here: the crowd)
    },
    sparse = {
        { 'conga', 69, 130, { { 11, 20 }, { 13, 20 } } },
        { 'tamb', 60, 290, { { 3, 10 }, { 15, 10 }, { 7, 20 }, { 12, 30 } } },
        { 'guiro', 60, 245, { { 7, 20, true } } },
        { 'triangle', 100, 90, { { 3, 10 }, { 15, 20, true } } },
        { 'triangleRing', 100, 1800, { { 14, 20, true } } },
        { 'chord', 0, 0, { { 8, 10, true } } },
        { 'quijada', 60, 600, { { 10, 20 } } },
    },
}

-- The satie style: a Gymnopédie-like waltz. A low root on 1, the chord on 2 held through 3 (no root:
-- the bass has it), sevenths rocking a bar each in A, a four-chord walk in B. The tune keeps off
-- every pitch a semitone from the bar's chord, so it never rubs. Its bars are rhythms in beats
-- (negative: a rest); a phrase's last bar is one of the endings.
D.satie = {
    qualities = { maj7 = { 4, 7, 11 }, m7 = { 3, 7, 10 } },
    A = {
        { { 5, 'maj7' }, { 0, 'maj7' } },   -- IV I, the rocking pair
        { { 0, 'maj7' }, { 2, 'm7' } },     -- I ii
        { { 9, 'm7' }, { 5, 'maj7' } },     -- vi IV
        { { 0, 'maj7' }, { 5, 'maj7' } },   -- I IV
    },
    B = {
        { { 2, 'm7' }, { 4, 'm7' }, { 5, 'maj7' }, { 5, 'maj7' } },   -- ii iii IV
        { { 9, 'm7' }, { 2, 'm7' }, { 4, 'm7' }, { 5, 'maj7' } },     -- vi ii iii IV
        { { 5, 'maj7' }, { 4, 'm7' }, { 2, 'm7' }, { 0, 'maj7' } },   -- IV iii ii I, walking down
    },
    outro = { { 5, 'maj7' }, { 0, 'maj7' }, { 0, 'maj7', ring = true } },
    rhythms = { { 3 }, { 1, 2 }, { 2, 1 }, { 1, 1, 1 }, { -1, 1, 1 }, { -1, 2 } },
    endings = { { 3 }, { -1, 2 }, { 2, -1 } },
    lo = 65, hi = 81,                         -- the tune's range
}

-- The ambient style: Hiroshi Yoshimura, Music for Airports. A few short figures, each looping at its
-- own length (none divides another), so they drift against each other and never line up the same
-- way twice; all on the key's major pentatonic, so any two notes that meet sound fine. Under it a
-- low drone that moves every 8 bars. Calm play: the drone and the first two loops; busy: all four.
-- A loop: its patch, its length in 16ths, how many notes, their register (lo..lo+12), how long each
-- rings, the bar it joins. The loops leave one by one at the end, the last first.
D.ambient = {
    penta = { 0, 2, 4, 7, 9 },
    drones = { { 0, 9, 0, 7 }, { 0, 2, 9, 0 }, { 0, 7, 9, 0 } },   -- a degree per 8 bars
    loops = {
        { patch = 'piano', steps = 46, notes = 3, lo = 57, ring = 3500, vol = 5, joins = 1 },
        { patch = 'vibes', steps = 59, notes = 2, lo = 64, ring = 2400, vol = 4, joins = 3 },
        { patch = 'kalimba', steps = 37, notes = 2, lo = 76, ring = 800, vol = 4, joins = 5, band = true },
        { patch = 'pianoLead', steps = 67, notes = 3, lo = 69, ring = 3000, vol = 4, joins = 9, band = true },
    },
}

-- the tune's rhythm: GROUPS of two to four notes a 16th or an 8th apart, then a breath (lofi.c's
-- MOTIFS). { steps over two bars, group per note }
D.motifs = {
    { { 0, 2, 4, 10, 12 }, { 0, 0, 0, 1, 1 } },          -- three up, two answer
    { { 0, 3, 6, 8, 16 }, { 0, 0, 0, 0, 1 } },           -- a four-note run, one long note
    { { 2, 4, 6, 12, 14, 20 }, { 0, 0, 0, 1, 1, 2 } },   -- off the beat, three groups
    { { 0, 2, 3, 6, 14, 16 }, { 0, 0, 0, 0, 1, 1 } },    -- a turn, then a pair
    { { 1, 4, 6, 8, 18 }, { 0, 0, 0, 0, 1 } },           -- a pickup into the run
    { { 0, 4, 6, 8, 10, 22 }, { 0, 1, 1, 1, 1, 2 } },    -- a stab, a run, a tail
    { { 4, 6, 8, 14, 16 }, { 0, 0, 0, 1, 1 } },          -- late: the space first
}
-- the island riff: per eighth, which voice of the chord's voicing (1 = lowest, 0 = rest)
D.riffs = {
    { 1, 3, 2, 4, 1, 3, 2, 4 },   -- the rolling one
    { 1, 2, 3, 4, 3, 2, 1, 0 },   -- up and down
    { 4, 0, 3, 1, 4, 0, 3, 2 },   -- hopping from the top
    { 1, 0, 3, 0, 2, 4, 0, 3 },   -- with holes
    { 2, 4, 0, 4, 1, 4, 0, 3 },   -- the top note keeps coming back
}
-- dusk's kalimba riffs: island's idea with more holes, the off-beats left to breathe
D.duskRiffs = {
    { 1, 0, 3, 0, 4, 0, 3, 0 },   -- on the beats only
    { 0, 3, 4, 0, 0, 3, 2, 0 },   -- late, a pair and a pair
    { 4, 3, 0, 0, 2, 0, 3, 0 },   -- falling, then a hole
    { 1, 4, 0, 3, 0, 0, 4, 0 },   -- a leap, an answer, the top again
}
-- dumont's pan riffs: sparser, around the off-beats, the way a steel pan part sits in dub-pop
D.dumontRiffs = {
    { 0, 3, 0, 4, 0, 3, 2, 0 },
    { 4, 0, 3, 0, 0, 4, 3, 2 },
    { 0, 2, 4, 0, 3, 0, 4, 0 },
    { 3, 0, 0, 4, 0, 2, 0, 3 },
}
-- jingle's fingerpicking: per eighth, which of the chord's three voices (1 = lowest)
D.jinglePicks = {
    { 1, 3, 2, 3, 1, 3, 2, 3 },
    { 1, 2, 3, 2, 1, 3, 2, 1 },
}
-- the answer's rhythms in bar 4, grouped the same way
-- the sesame horns: one shout per song, in the bar the tune breathes { step, length, vol } (all before
-- the and-of-4, where the keys may push the next chord)
D.hornHits = {
    { { 6, 2, 4 }, { 8, 3, 5 } },                  -- da-DAH
    { { 0, 2, 5 }, { 6, 1, 4 }, { 8, 3, 5 } },     -- DAH, da-DAH
    { { 4, 1, 4 }, { 6, 1, 4 }, { 10, 3, 5 } },    -- ba-da ... DAH
    { { 2, 1, 4 }, { 8, 4, 5 } },                  -- da ... DAAH
}

-- citypop's horn figures (citypop2.c), its bass figures (x root, o octave pop, g a dead-note ghost;
-- the chord's first step is always the root) and the guitar's cutting (1 a muted chuck, 2 an open
-- stab; nothing on 13-15, where the horns and the bass run own the turn). One of each per song.
D.cityHornHits = {
    { { 2, 1, 4 }, { 6, 1, 4 }, { 10, 2, 5 } },
    { { 3, 1, 4 }, { 6, 1, 4 }, { 8, 2, 5 } },
    { { 0, 1, 4 }, { 3, 1, 4 }, { 6, 2, 5 } },
}
D.cityBass = { 'x.....o.x.o...o.', 'x..x..o.x..x..o.', 'x.g...o.x.g...o.' }
D.cityChucks = {
    { 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0 },
    { 0, 0, 1, 1, 0, 0, 2, 0, 0, 0, 1, 0, 1, 0, 0, 0 },
    { 0, 0, 2, 0, 0, 1, 1, 0, 0, 0, 2, 0, 0, 0, 0, 0 },
}
-- the session kit's grooves (k kick, s snare, g ghost): disco four, funk with ghosts, the push, the skip
D.cityGrooves = {
    { k = 'x...x...x...x...', s = '....x.......x...' },
    { k = 'x.....x...x.....', s = '....x..g.g..x..g' },
    { k = 'x.......x.x.....', s = '....x.......x...' },
    { k = 'x..x....x.x..x..', s = '....x.......x...' },
}

D.answers = { { 0, 2, 4, 10 }, { 2, 4, 6, 12 }, { 0, 2, 6, 8, 14 }, { 4, 6, 8, 12 }, { 0, 3, 6, 8 } }

-- a style's comp cells: its own, or a shared set from D.comps by name
function D.compsOf(style)
    return type(style.comps) == 'string' and D.comps[style.comps] or style.comps
end


return D
