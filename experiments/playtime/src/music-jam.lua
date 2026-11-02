-- The drum jam (docs/DRUM-JAM.md): a drum-machine groove that never ends, arranged LIVE by the play level
-- instead of planned as a song. The plan only picks a pattern family and lays out phrases; every phrase,
-- bookBar looks at the play level (M.activity, the number music.bump() raises) and moves the jam one step:
-- a layer in or out, a breakdown (the kick leaves, the rest plays on), then the drop (all back at once,
-- a crash).
-- Each phrase's last bar has a fill: the family's own written one where the source has it (the book
-- groups' Break), else a snare run-up. Patterns: src/music-jam-patterns.lua (generated from dreamengine's
-- drum-patterns.json): genre -> families, a family = the variants of one groove (+ its fill).
-- The BASS is the organ's auto-accompaniment idea (J7): a short loop written in degrees (root, fifth,
-- octave...) over a ROOT that walks on its own clock, every rootEvery bars, along a small walk (I IV V I,
-- around the fourths...). Calm play holds the root; the drop lands back home.
-- Registered as loop = 'jam' in music-plan's LOOP_PLANS and music-parts' LOOP_BARS, which pass in what
-- this file needs from them (addSections, play, remember), so it requires neither.
local state = require('src.state')
local D = require('src.music-styles')
local theory = require('src.music-theory')
local PATTERNS = require('src.music-jam-patterns')
local stream, stepTime, inRange = theory.stream, theory.stepTime, theory.inRange
local M = state.music

local lib = {}

-- The layers, in the order they come in: the pattern roles each plays (the bass plays its loop instead).
lib.LAYERS = {
    { name = 'kick', roles = { 'BD' } },
    { name = 'bass' },
    { name = 'hats', roles = { 'CH', 'OH', 'SW' } },
    { name = 'snare', roles = { 'SD', 'CPS' } },
    { name = 'perc', roles = { 'RS', 'CB', 'TB', 'LT', 'MT', 'HT', 'CY' } },
}

-- role -> { patch, midi, vol, length ms }: the general patches until the jam has a kit of its own (J4)
lib.VOICES = {
    BD = { 'bapKick', 36, 5, 160 }, SD = { 'snare', 60, 4, 120 }, CPS = { 'clap', 60, 4, 100 },
    CH = { 'shaker', 82, 3, 35 }, OH = { 'tamb', 80, 3, 160 }, CY = { 'tamb', 76, 3, 600 },
    RS = { 'djembe', 79, 3, 60 }, CB = { 'tongueDrum', 81, 3, 120 }, TB = { 'tamb', 84, 2, 60 },
    LT = { 'djembe', 50, 4, 200 }, MT = { 'djembe', 55, 4, 180 }, HT = { 'djembe', 60, 4, 160 },
}
-- a genre's own voices over those: the brushes are the soft kick, a sweep, a tap and the hi-hat foot
lib.GENRE_VOICES = {
    Brushes = { BD = { 'kick', 36, 5, 150 }, SD = { 'snare', 60, 3, 70 }, SW = { 'brush', 70, 4, 900 },
                CH = { 'hat', 80, 4, 30 } },
}
-- genres the drum library hasn't got, written here: the same shape as src/music-jam-patterns.lua.
-- SW = a brush sweep (long, slow attack), SD = the brush's tap
lib.EXTRA = {
    Brushes = {
        { name = 'BRUSHES', loops = {
            { name = 'BRUSHES - A', grid = { BD = 'x.......x.......', SD = '....x.......x...',
                                            SW = 'x.......x.......', CH = '....x.......x...' } },
            { name = 'BRUSHES - B', grid = { BD = 'x.......x.....x.', SD = '....x.......x.x.',
                                            SW = 'x...............', CH = '....x.......x...' } },
        } },
    },
}
lib.SWING = { Brushes = 0.62 } -- a genre's own swing (the jam style's otherwise)

-- The bass. A loop is steps (16ths) of degrees over the current root: R root, 2 a second, m minor third,
-- 3 major third, 4 fourth, 5 fifth, 6 major sixth, 7 flat seventh, 8 octave, L the fifth below, A the
-- APPROACH: a half step under the NEXT bar's root (so a change is walked into, not jumped); '-' holds
-- the note before, '.' rests. Mostly no major third: on a progression's minor chord (the 6 in 1 5 6 4)
-- it would clash. A loop needn't be a bar long: one of 18 steps runs on across the bar line and lands
-- somewhere else each bar (it counts from the song's first bar).
-- Two per genre (A and B, moving with the drum family's variants). The voice: lib.BASS, the upright
-- (synth.lua's musicBass: dreamengine's bowed-string model plucked, a double bass body; Nikki's pick).
lib.BASS = 'musicBass'
lib.BASS_LOOPS = {
    Electro = { 'R--.R--.R-.R-.5.', 'R--.R--.8.R.5.A.' },
    ['Hip Hop'] = { 'R-----.R--..5-A-', 'R-----.R--..L-A-' },
    Breaks = { 'R---..R.5---..A.', 'R---..R.8.7.5.A.' },
    Disco = { 'R.8.R.8.R.8.5.A.', 'R.8.R.8.5.8.6.A.' },
    Funk = { 'R..R..5.7.8..RA.', 'R..R.L..R..5.6A.' },
    Brushes = { 'R-..5-..6-..A-..', 'R-..8-..5-..2.A.' },
}
local DEGREE = { R = 0, ['2'] = 2, m = 3, ['3'] = 4, ['4'] = 5, ['5'] = 7, ['6'] = 9, ['7'] = 10, ['8'] = 12,
                 L = -5 }

-- The walks the root takes (semitones over the song's key), and how often it moves, both rolled per
-- song: 1 4 5 1 (home, away, the pull, home), 1 5 6 4 (the pop loop that never settles), 1 6 4 5
-- (doo-wop), 2 5 1 (the jazz arrival), 1 4 1 5, 1 bVII 1 4, around the fourths. A walk moves every
-- rootEvery bars, unless it carries its own lengths (bars = bars per step): Nikki's C F D F E held
-- 4 1 2 1 1 (in C: 1 4 2 4 3), a step that lingers and then hurries.
lib.WALKS = { { 0, 5, 7, 0 }, { 0, 7, 9, 5 }, { 0, 9, 5, 7 }, { 2, 7, 0, 0 }, { 0, 5, 0, 7 }, { 0, 10, 0, 5 },
              { 0, 5, 10, 3, 8, 1, 6, 0 }, { 0, 5, 2, 5, 4, bars = { 4, 1, 2, 1, 1 } } }
lib.ROOT_EVERY = { 2, 4, 4, 8 }

-- The plan: a genre (style.groups, one per song) at its own tempo, one of its families, a bass walk, and
-- a long run of phrases. What happens in them is decided as they come (bookBar), from the play level.
function lib.plan(song, style, addSections)
    local rnd = stream(song.seed, 1)
    local group = style.groups[rnd(#style.groups) + 1]
    local families = PATTERNS[group] or lib.EXTRA[group]
    local family = families[rnd(#families) + 1]
    local bpm = style.bpms[group]
    song.beat = 60 / math.floor(bpm[1] + rnd() * (bpm[2] - bpm[1]) + 0.5)
    song.barLength = 4 * song.beat
    if lib.SWING[group] then song.swing = lib.SWING[group] end
    local walk = lib.WALKS[rnd(#lib.WALKS) + 1]
    song.jam = { group = group, family = family.name, patterns = family.loops, fill = family.fill, at = 1,
                 layers = style.minLayers, phrase = 0, mode = 'groove', on = {},
                 walk = walk, rootEvery = lib.ROOT_EVERY[rnd(#lib.ROOT_EVERY) + 1],
                 step = 1, root = walk[1] } -- a walk may start away from home (2 5 1)
    song.jam.left = walk.bars and walk.bars[1] or song.jam.rootEvery -- bars left on this step
    local sections = {}
    for k = 1, style.phrases do sections[k] = { 'A', style.phraseBars } end
    addSections(song, sections)
end

-- How many layers the play level asks for now.
local function target(style)
    local n = style.minLayers + math.floor((M.activity or 0) / style.perLayer)
    return math.max(style.minLayers, math.min(#lib.LAYERS, n))
end

-- A phrase starts: one step of the live arrangement.
local function newPhrase(jam, style)
    jam.phrase = jam.phrase + 1
    local want = target(style)
    if jam.mode == 'break' and want >= 3 then
        jam.mode = 'drop' -- after a breakdown, everything the play level asks for comes back at once
        jam.layers = math.max(jam.layers, want)
        jam.step, jam.root = 1, jam.walk[1] -- and the drop lands back home, for a whole step
        jam.left = (jam.walk.bars and jam.walk.bars[1] or jam.rootEvery) + 1
    elseif jam.mode == 'break' then
        jam.mode, jam.layers = 'groove', want -- calmed down during the breakdown: back without a drop
    elseif jam.layers >= 3 and want >= 3 and jam.phrase % style.breakEvery == 0 then
        jam.mode = 'break'
    else
        jam.mode = 'groove' -- one layer at a time toward what the play level asks for
        if want > jam.layers then jam.layers = jam.layers + 1
        elseif want < jam.layers then jam.layers = jam.layers - 1 end
    end
    if jam.phrase % style.variantEvery == 0 then jam.at = jam.at % #jam.patterns + 1 end
    for k, layer in ipairs(lib.LAYERS) do jam.on[layer.name] = k <= jam.layers end
    if jam.mode == 'break' then -- the breakdown: the floor drops out (no kick), the rest keeps going
        for _, layer in ipairs(lib.LAYERS) do jam.on[layer.name] = layer.name ~= 'kick' end
    end
end

-- The root walker: when a step's bars are up (its own length, else rootEvery), the root takes the walk's
-- next step, unless play is calm (then it holds a bar at a time, so a quiet room sits on one chord).
local function stepBars(jam) return jam.walk.bars and jam.walk.bars[jam.step] or jam.rootEvery end
local function walkRoot(jam, style, b)
    if b == 1 then return end
    jam.left = jam.left - 1
    if jam.left > 0 then return end
    if (M.activity or 0) < style.perLayer then jam.left = 1 return end
    jam.step = jam.step % #jam.walk + 1
    jam.root = jam.walk[jam.step]
    jam.left = stepBars(jam)
end

local function hit(play, synth, t, role, s, accent, quieter, genre)
    local own = lib.GENRE_VOICES[genre]
    local v = own and own[role] or lib.VOICES[role]
    if not v then return end
    play(synth, 'drums', v[1], t, v[2], math.max(1, v[3] - (quieter or 0)), v[4], s, false, accent)
end

-- One bar of the bass loop over the current root: a note lasts through the '-' after it (across the bar
-- line too: the next bar's booking skips the held steps). nextRoot = where the walk goes next bar (the
-- approach note leans into it). b = the bar, so a loop that isn't a bar long keeps its place.
local function bookBass(play, synth, song, t0, loop, root, nextRoot, b)
    local home = inRange((song.key + root) % 12, 33) -- A1..G#2
    local approach = inRange((song.key + nextRoot) % 12, 33) - 1 -- a half step under the next root, right
                                                                   -- under the note it leads into
    local n = #loop
    local function at(g) local k = g % n + 1 return loop:sub(k, k) end
    for s = 0, 15 do
        local g = (b - 1) * 16 + s -- the step since the song's start: where the loop is
        local c = at(g)
        local degree = c == 'A' and approach - home or DEGREE[c]
        if degree then
            local len = 1
            while len < n and at(g + len) == '-' do len = len + 1 end
            local ms = theory.lengthMs(song, s, len) * 0.9
            play(synth, 'bass', lib.BASS, stepTime(song, t0, s), home + degree, s == 0 and 7 or 6, ms, s)
        end
    end
end

-- One bar. play and remember are music-parts' (every note goes through play: mutes, the panel, listeners).
function lib.bookBar(play, remember, synth, t0, song, b)
    local style, jam = D.styles[song.style], song.jam
    local inPhrase = (b - 1) % style.phraseBars
    if inPhrase == 0 then newPhrase(jam, style) end
    walkRoot(jam, style, b)
    local pcs = {}
    for _, d in ipairs({ 0, 3, 5, 7, 10 }) do pcs[#pcs + 1] = (song.key + jam.root + d) % 12 end
    remember(t0, pcs) -- impacts play along in a minor pentatonic on the root
    if jam.on.bass then
        local loops = lib.BASS_LOOPS[jam.group]
        local moves = jam.left == 1 and (M.activity or 0) >= style.perLayer -- the root changes next bar
        local nextRoot = moves and jam.walk[jam.step % #jam.walk + 1] or jam.root
        bookBass(play, synth, song, t0, loops[(jam.at - 1) % #loops + 1], jam.root, nextRoot, b)
    end
    local lastBar = inPhrase == style.phraseBars - 1
    local fill = lastBar and (jam.on.snare or jam.mode == 'break')
    local written = fill and jam.fill -- the family's own fill plays the whole bar
    local pattern = written or jam.patterns[jam.at]
    local accents = pattern.grid.AC
    for s = 0, 15 do
        local t = stepTime(song, t0, s)
        local accent = accents and accents:sub(s + 1, s + 1) == 'x' and 1 or 0
        if jam.mode == 'drop' and inPhrase == 0 and s == 0 then hit(play, synth, t, 'CY', s, 1, 0, jam.group) end
        for _, layer in ipairs(lib.LAYERS) do
            local quietFill = fill and not written and layer.name == 'hats' and s >= 14 -- let go before the one
            if layer.roles and jam.on[layer.name] and not quietFill then
                for _, role in ipairs(layer.roles) do
                    local c = pattern.grid[role] and pattern.grid[role]:sub(s + 1, s + 1)
                    if c == 'x' or c == 'f' then
                        local quieter = jam.mode == 'break' and layer.name ~= 'hats' and 1 or 0
                        hit(play, synth, t, role, s, accent, quieter, jam.group)
                        if c == 'f' then hit(play, synth, t + 0.015, role, s, 0, 1, jam.group) end -- a flam
                    end
                end
            end
        end
        if fill and not written and s >= 12 then hit(play, synth, t, 'SD', s, 0, 15 - s, jam.group) end -- a run-up
    end
end

return lib
