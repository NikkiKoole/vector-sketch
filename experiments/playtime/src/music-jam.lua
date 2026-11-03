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
-- around the fourths...). Calm play slows the walk; the drop lands back home; changes are decided a bar early.
-- Registered as loop = 'jam' in music-plan's LOOP_PLANS and music-parts' LOOP_BARS, which pass in what
-- this file needs from them (addSections, play, remember), so it requires neither.
local state = require('src.state')
local D = require('src.music-styles')
local theory = require('src.music-theory')
local PATTERNS = require('src.music-jam-patterns')
local riffs = require('src.music-riffs')
local stream, stepTime, inRange = theory.stream, theory.stepTime, theory.inRange
local M = state.music

local lib = {}

-- The layers, in the order they come in: the pattern roles each plays (the bass plays its loop instead).
lib.LAYERS = {
    { name = 'kick', roles = { 'BD' } },
    { name = 'bass' },
    { name = 'keys' }, -- the chord part (J9d): plays the progression, not a pattern
    { name = 'hats', roles = { 'CH', 'OH', 'SW' } },
    { name = 'snare', roles = { 'SD', 'CPS' } },
    { name = 'perc', roles = { 'RS', 'CB', 'TB', 'LT', 'MT', 'HT', 'CY' } },
}

-- role -> { patch, midi, vol, length ms }: Playtime's own drum patches, played the way its other kits play
-- them (music-parts' drumKits: the hat at 60, the ride at 81, the rim at 79), so the music panel's drum
-- rows read as the drums they are (the closed and the open hat are both 'hat', the open one longer). The
-- first cut used stand-ins (a shaker for the hats, a djembe for rim and toms) and the rows didn't match
-- what played. A drum machine's own voices are still J4.
lib.VOICES = {
    BD = { 'bapKick', 36, 5, 160 }, SD = { 'snare', 60, 4, 120 }, CPS = { 'clap', 60, 4, 100 },
    CH = { 'hat', 60, 3, 28 }, OH = { 'hat', 60, 3, 140 }, CY = { 'ride', 81, 4, 600 },
    RS = { 'rim', 79, 4, 40 }, CB = { 'wood', 76, 3, 120 }, TB = { 'tamb', 84, 2, 60 },
    LT = { 'tom', 45, 4, 220 }, MT = { 'tom', 50, 4, 200 }, HT = { 'tom', 55, 4, 180 },
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
-- APPROACH: a half step under the NEXT bar's root (so a change is walked into, not jumped), N the next
-- bar's root itself, early (the PUSH: the change arrives on the and-of-4, the funk way); '-' holds
-- the note before, '.' rests. Mostly no major third: on a progression's minor chord (the 6 in 1 5 6 4)
-- it would clash. A loop needn't be a bar long: one of 18 steps runs on across the bar line and lands
-- somewhere else each bar (it counts from the song's first bar).
-- Two per genre (A and B, moving with the drum family's variants). The voice: lib.BASS, the upright
-- (synth.lua's musicBass: dreamengine's bowed-string model plucked, a double bass body; Nikki's pick).
lib.BASS = 'musicBass'
-- Few notes on purpose (Nikki: the ROOT MOVING is the point, a busy riff buries it): A = root-octave-b7,
-- the classic funk cell and Nikki's favourite (2026-11-02), in every genre; B = a figure that suits it:
-- the push (N, the next root early) for the funky ones, the octave pop for Disco, the approach for Brushes.
-- The figures by name, for the music panel's 'jam bass' row (a pick plays instead of the genre's two).
lib.FIGURES = {
    { name = 'root-octave-b7', loop = 'R..8..7.........' },
    { name = 'the push', loop = 'R.............N.' },
    { name = 'the one', loop = 'R...............' },
    { name = 'octave pop', loop = 'R.....8.R.....8.' },
    { name = 'approach', loop = 'R-----........A.' },
}
-- and the riffs (J8, src/music-riffs.lua: a phrase, its variations, a form lined up with the root's step)
for _, riff in ipairs(riffs.RIFFS) do lib.FIGURES[#lib.FIGURES + 1] = { name = 'riff: ' .. riff.name, riff = riff } end
lib.BASS_LOOPS = {
    Electro = { 'R..8..7.........', 'R.............N.' },
    ['Hip Hop'] = { 'R..8..7.........', 'R.............N.' },
    Breaks = { 'R..8..7.........', 'R.............N.' },
    Disco = { 'R..8..7.........', 'R.....8.R.....8.' },
    Funk = { 'R..8..7.........', 'R.............N.' },
    Brushes = { 'R..8..7.........', 'R-----........A.' },
}
local DEGREE = riffs.DEGREE -- b = the b5, for blues riffs (src/music-riffs.lua)
-- The plain figures don't follow the chord, except their 7 over a maj9 (the wave): the major 7th, the
-- chord's own, not a b7 a half step under it (Nikki 2026-11-03). Over major chords the b7 stays: the
-- figure's funk, and the pad's major chord has no 7th to rub on.
local FIGURE_DEGREES = { J = setmetatable({ ['7'] = 11 }, { __index = DEGREE }) }

-- The chord part (J9d): the progression played as chords, voiced close to the last one
-- (theory.voiceChord). The chords per kind keep out of the bass's way: the major one has the 9th, not the
-- major 7th (the figures play a b7 over every chord), the minor and the dominant their b7.
lib.KEYS_CHORDS = { M = { 0, 4, 7, 14 }, m = { 0, 3, 7, 10 }, ['7'] = { 0, 4, 7, 10 },
                    J = { 0, 4, 11, 14 }, s = { 0, 5, 10, 14 } } -- maj9 and 9sus: the wave's chords
-- How the chords are played: 16 steps, 'x' a hit, '-' holding it, '.' silence; each figure on its own
-- instrument (the panel's keys row can swap it), voiced in lo..hi, rolled by `roll` seconds a note.
-- Picked in the panel's 'jam chords' row; 'auto' = the genre's (CHORDS_BY_GENRE).
lib.CHORD_FIGURES = {
    { name = 'pad', steps = 'x---------------', patch = 'rhodes', vol = 2, lo = 52, hi = 74, roll = 0.012 },
    { name = 'disco stabs', steps = '..x-..x-..x-..x-', patch = 'stab', vol = 2, lo = 55, hi = 76, roll = 0 },
    { name = 'funk stabs', steps = '....x..x.x....x.', patch = 'clav', vol = 3, lo = 55, hi = 76, roll = 0.004 },
    { name = 'skank', steps = '....x-......x-..', patch = 'jabGuitar', vol = 1, lo = 60, hi = 79, roll = 0.008 },
    { name = 'strum', steps = 'x--x--x-x--x--x-', patch = 'guitar', vol = 1, lo = 52, hi = 76, roll = 0.022 },
}
lib.CHORDS_BY_GENRE = { Disco = 'disco stabs', Funk = 'funk stabs', Breaks = 'funk stabs', Electro = 'pad',
                        ['Hip Hop'] = 'pad', Brushes = 'pad' }

-- The walks the root takes (semitones over the song's key), and how often it moves, both rolled per
-- song: 1 4 5 1 (home, away, the pull, home), 1 5 6 4 (the pop loop that never settles), 1 6 4 5
-- (doo-wop), 2 5 1 (the jazz arrival), 1 4 1 5, 1 bVII 1 4, around the fourths. A walk moves every
-- rootEvery bars, unless it carries its own lengths (bars = { bars per step }).
-- A walk is a chord PROGRESSION (J9): `kinds` gives each step's chord, M major, m minor, 7 dominant,
-- J maj9, s 9sus
-- (src/music-riffs.lua's CHORD_SCALES: a riff that follows the chord plays its pentatonic there).
-- Named for the music panel's 'jam walk' row. Paces: 2 or 4 bars (8 was too slow to hear the walk).
lib.WALKS = {
    { name = '1 4 5 1', kinds = 'MM7M', 0, 5, 7, 0 }, { name = '1 5 6 4', kinds = 'MMmM', 0, 7, 9, 5 },
    { name = '1 6 4 5 doo-wop', kinds = 'MmM7', 0, 9, 5, 7 }, { name = '2 5 1', kinds = 'm7MM', 2, 7, 0, 0 },
    { name = '1 4 1 5', kinds = 'MMM7', 0, 5, 0, 7 }, { name = '1 b7 1 4', kinds = 'MMMM', 0, 10, 0, 5 },
    { name = 'round the fourths', kinds = '77777777', 0, 5, 10, 3, 8, 1, 6, 0 },
    -- the wave (playtime-9c's composed style, Peter Martin's maj9 / 9sus cycle): roots up a fourth each
    -- step, maj9 and 9sus taking turns, so the maj9 drops a whole step every two; all twelve, then home.
    -- The plain figures' b7 rubs on the maj9 (its 7th is major); the riffs follow it.
    { name = 'the wave', kinds = 'JsJsJsJsJsJs', 0, 5, 10, 3, 8, 1, 6, 11, 4, 9, 2, 7 },
    { name = 'the wave B', kinds = 'sJsJsJsJsJsJ', 0, 5, 10, 3, 8, 1, 6, 11, 4, 9, 2, 7 }, -- 9sus first
}
-- the chord on the walk's current step
function lib.kind(walk, step) return walk.kinds and walk.kinds:sub(step, step) or 'm' end
lib.ROOT_EVERY = { 2, 4 }

-- The music panel's picks (state.musicSettings.jam = { walk, figure, pace }, src/music-params.lua; saved
-- in setups): a name, or nil / 'auto' = what the song rolled. Read every bar, so a pick is live.
local function picks() return state.musicSettings and state.musicSettings.jam or {} end
local function picked(list, name)
    if not name or name == 'auto' then return nil end
    for _, item in ipairs(list) do if item.name == name then return item end end
end
local function names(list)
    local out = { 'auto' }
    for _, item in ipairs(list) do out[#out + 1] = item.name end
    return out
end
function lib.walkNames() return names(lib.WALKS) end
function lib.figureNames() return names(lib.FIGURES) end
function lib.chordNames() return names(lib.CHORD_FIGURES) end
lib.PACES = { 'auto', '2', '4' }
-- 'all': every layer plays from the next bar, whatever the play level (for listening; Nikki 2026-11-03).
-- The breakdown and the drop still come round.
lib.LAYER_PICKS = { 'auto', 'all' }
-- the drums' moves (J10), each 'auto' / 'always' / 'never' in the panel: 'lean' = the drums lean into a
-- chord change, 'gap' = a beat of silence before the drop
lib.MOVE_PICKS = { 'auto', 'always', 'never' }
-- SPOTLIGHTS (J10c): the second half of a groove phrase (its last 4 bars) given to one part: the drum
-- break (the drums alone, the breakdown's opposite), the bass feature (the bass alone with the drums,
-- playing a riff's variations; the chords out) or trading (2 bars of bass alone, then 2 of drums alone).
-- On auto: a busy groove phrase between two breakdowns, half the time. A spotlight named in the panel
-- plays in every groove phrase (for listening).
lib.SPOTS = { 'drum break', 'bass feature', 'trading' }
lib.SPOT_PICKS = { 'auto', 'never', 'drum break', 'bass feature', 'trading' }
-- VARIATIONS (J10d), with the play level: the hats double to 16ths, ghost snares come in, and a phrase's
-- second-to-last bar plays the other variant (a turnaround into the fill). 'jam variations' auto / always / never.
lib.GHOSTS = { '......x....x....', '.......x..x.....', '...x......x....x' } -- one per song

local function move(name)
    local v = picks()[name]
    if v == 'always' or v == 'never' then return v end
    return 'auto'
end
local function allLayers() return picks().layers == 'all' end

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
    local every = lib.ROOT_EVERY[rnd(#lib.ROOT_EVERY) + 1]
    walk = picked(lib.WALKS, picks().walk) or walk -- rolled first either way, so a pick moves no other roll
    every = tonumber(picks().pace) or every
    song.jam = { group = group, family = family.name, patterns = family.loops, fill = family.fill, at = 1,
                 seed = song.seed, ghosts = lib.GHOSTS[rnd(#lib.GHOSTS) + 1],
                 layers = style.minLayers, phrase = 0, mode = 'groove', on = {},
                 walk = walk, rootEvery = every,
                 step = 1, root = walk[1] } -- a walk may start away from home (2 5 1)
    song.jam.left = walk.bars and walk.bars[1] or song.jam.rootEvery -- bars left on this step
    local sections = {}
    for k = 1, style.phrases do sections[k] = { 'A', style.phraseBars } end
    addSections(song, sections)
end

-- How many layers the play level asks for now (all of them when the panel says so).
local function target(style)
    if allLayers() then return #lib.LAYERS end
    local n = style.minLayers + math.floor((M.activity or 0) / style.perLayer)
    return math.max(style.minLayers, math.min(#lib.LAYERS, n))
end

-- Everything that changes on a bar line is DECIDED ONE BAR EARLY (the last bar of a phrase, the last bar
-- on a root) and applied when the bar comes: the bass's ending (A, N, a riff's last letter) then leans into
-- the root that really arrives. Deciding twice (once to aim the bass, again on the bar line) went wrong
-- when the play level moved in between, and a drop's jump home came unannounced. (dreamengine's
-- rootwalk.c cart does the same.)

-- The next phrase: one step of the live arrangement.
local function planPhrase(jam, style)
    local p = { phrase = jam.phrase + 1, layers = jam.layers }
    local want = target(style)
    if jam.mode == 'break' and want >= 3 then
        p.mode = 'drop' -- after a breakdown, everything the play level asks for comes back at once
        p.layers = math.max(jam.layers, want)
    elseif jam.mode == 'break' then
        p.mode, p.layers = 'groove', want -- calmed down during the breakdown: back without a drop
    elseif jam.layers >= 3 and want >= 3 and p.phrase % style.breakEvery == 0 then
        p.mode = 'break'
    else
        p.mode = 'groove' -- one layer at a time toward what the play level asks for
        if want > jam.layers then p.layers = jam.layers + 1
        elseif want < jam.layers then p.layers = jam.layers - 1 end
    end
    local spotPick = picks().spot
    if p.mode == 'groove' and spotPick and spotPick ~= 'auto' and spotPick ~= 'never' then
        p.spot = spotPick
    elseif p.mode == 'groove' and spotPick ~= 'never' and p.layers >= 4
        and p.phrase % style.breakEvery == math.floor(style.breakEvery / 2) then
        local rnd = stream(jam.seed + p.phrase * 104729, 11)
        if rnd(2) == 0 then p.spot = lib.SPOTS[rnd(#lib.SPOTS) + 1] end
    end
    return p
end
local function applyPhrase(jam, style, p)
    jam.phrase, jam.mode, jam.layers, jam.spot = p.phrase, p.mode, p.layers, p.spot
    if jam.phrase % style.variantEvery == 0 then jam.at = jam.at % #jam.patterns + 1 end
    for k, layer in ipairs(lib.LAYERS) do jam.on[layer.name] = k <= jam.layers end
    if jam.mode == 'break' then -- the breakdown: the floor drops out (no kick), the rest keeps going
        for _, layer in ipairs(lib.LAYERS) do jam.on[layer.name] = layer.name ~= 'kick' end
    end
end

local function stepBars(jam) return jam.walk.bars and jam.walk.bars[jam.step] or jam.rootEvery end
-- A walk picked in the panel waits for the next change, then starts from its first step.
local function nextWalk(jam)
    local want = picked(lib.WALKS, picks().walk)
    return want and want ~= jam.walk and want or nil
end
-- Calm play SLOWS the walk (a step lasts twice as long) but never stops it: the root moving is the point,
-- and holding it froze the jam in the editor (where nothing bumps the play level), a picked walk waiting
-- for a change that never came. Anything picked in the panel is never slowed.
function lib.lingers(jam, style)
    if jam.lingered then return false end -- slowed once already: this step moves on
    local p = picks()
    local chosen = (p.walk and p.walk ~= 'auto') or (p.pace and p.pace ~= 'auto') or nextWalk(jam)
    return not chosen and (M.activity or 0) < style.perLayer
end
-- The next root, decided on the last bar of a step (or the bar before a drop, which lands back home on
-- the walk's first step, a picked walk's if one waits): { walk, step } or { linger = true }.
local function planRoot(jam, style, drop)
    if drop then return { walk = nextWalk(jam) or jam.walk, step = 1 } end
    if lib.lingers(jam, style) then return { linger = true } end
    local switch = nextWalk(jam)
    if switch then return { walk = switch, step = 1 } end
    return { walk = jam.walk, step = jam.step % #jam.walk + 1 }
end
local function applyRoot(jam, nxt)
    if nxt.linger then jam.left, jam.lingered = stepBars(jam), true return end
    jam.lingered = false
    jam.walk, jam.step = nxt.walk, nxt.step
    jam.root = jam.walk[jam.step]
    jam.left = stepBars(jam)
end
-- The bar line: apply what was decided last bar, then decide what the next bar line brings.
local function advance(jam, style, b)
    jam.rootEvery = tonumber(picks().pace) or jam.rootEvery
    if b == 1 then
        applyPhrase(jam, style, planPhrase(jam, style))
    else
        if jam.nextPhrase then applyPhrase(jam, style, jam.nextPhrase) end
        if jam.nextRoot then applyRoot(jam, jam.nextRoot) else jam.left = jam.left - 1 end
    end
    jam.nextPhrase, jam.nextRoot = nil, nil
    if allLayers() and jam.mode ~= 'break' then -- at once, not a layer a phrase
        jam.layers = #lib.LAYERS
        for _, layer in ipairs(lib.LAYERS) do jam.on[layer.name] = true end
    end
    if (b - 1) % style.phraseBars == style.phraseBars - 1 then jam.nextPhrase = planPhrase(jam, style) end
    local drop = jam.nextPhrase and jam.nextPhrase.mode == 'drop'
    if drop or jam.left <= 1 then jam.nextRoot = planRoot(jam, style, drop) end
end
-- Where the next bar's root goes (the approach note leans into it), and the bars left on this root as a
-- riff's form counts them (1 = the bar before the change; a step slowed by calm play goes on longer).
function lib.ahead(jam)
    local nxt = jam.nextRoot
    if not nxt then return jam.root, jam.left end
    if nxt.linger then return jam.root, jam.left + stepBars(jam) end
    return nxt.walk[nxt.step], 1
end

local function bookKeys(play, synth, song, t0, jam, kind, cut)
    cut = cut or 16
    local figure = picked(lib.CHORD_FIGURES, picks().chords)
        or picked(lib.CHORD_FIGURES, lib.CHORDS_BY_GENRE[jam.group]) or lib.CHORD_FIGURES[1]
    local root = (song.key + jam.root) % 12
    jam.voicing = theory.voiceChord(root, lib.KEYS_CHORDS[kind], figure.lo, figure.hi, jam.voicing)
    if not jam.voicing then return end
    local steps = figure.steps
    for s = 0, cut - 1 do
        if steps:sub(s + 1, s + 1) == 'x' then
            local len = 1
            while s + len < cut and steps:sub(s + len + 1, s + len + 1) == '-' do len = len + 1 end
            local ms = theory.lengthMs(song, s, len) * 0.95
            for k, midi in ipairs(jam.voicing) do
                play(synth, 'keys', figure.patch, stepTime(song, t0, s) + (k - 1) * figure.roll, midi,
                     figure.vol, ms, s)
            end
        end
    end
end

local function hit(play, synth, t, role, s, accent, quieter, genre)
    local own = lib.GENRE_VOICES[genre]
    local v = own and own[role] or lib.VOICES[role]
    if not v then return end
    play(synth, 'drums', v[1], t, v[2], math.max(1, v[3] - (quieter or 0)), v[4], s, false, accent)
end

-- One bar of the bass loop over the current root: a note lasts through the '-' after it (across the bar
-- line too: the next bar's booking skips the held steps). nextRoot = where the walk goes next bar (the
-- approach note leans into it). b = the bar, so a loop that isn't a bar long keeps its place. oneBar: the
-- loop is this bar only (a riff's bar), so a hold stops at the bar line instead of wrapping.
-- degree: letter -> semitones (a riff's, following the chord), else the jam's DEGREE.
-- cut: nothing from that step on (the gap before a drop), a held note let go there.
local function bookBass(play, synth, song, t0, loop, root, nextRoot, b, oneBar, degree, cut)
    degree, cut = degree or DEGREE, cut or 16
    local home = inRange((song.key + root) % 12, 33) -- A1..G#2
    local approach = inRange((song.key + nextRoot) % 12, 33) - 1 -- a half step under the next root, right
                                                                   -- under the note it leads into
    local n = #loop
    local function at(g) local k = g % n + 1 return loop:sub(k, k) end
    for s = 0, cut - 1 do
        local g = (b - 1) * 16 + s -- the step since the song's start: where the loop is
        local c = at(g)
        local d = c == 'A' and approach - home or c == 'N' and approach + 1 - home or degree[c]
        if d then
            local len = 1
            while len < n and (not oneBar or s + len < 16) and s + len < cut and at(g + len) == '-' do
                len = len + 1
            end
            local ms = theory.lengthMs(song, s, len) * 0.9
            play(synth, 'bass', lib.BASS, stepTime(song, t0, s), home + d, s == 0 and 7 or 6, ms, s)
        end
    end
end

-- The panel lists a part's sounds as they PLAY (music-parts' play keeps M.styleSounds), so a calm jam (kick
-- and bass only) showed one drum row. Tell it every sound this song's patterns can use, from the start,
-- so each can be swapped or switched off before its layer comes in. Once per song (the family is fixed).
local function announceSounds(song, jam)
    if jam.announced then return end
    jam.announced = true
    local own = lib.GENRE_VOICES[jam.group] or {}
    local sounds = {}
    local function add(grid) for role in pairs(grid) do
        local v = own[role] or lib.VOICES[role]
        if v then sounds[v[1]] = true end
    end end
    for _, p in ipairs(jam.patterns) do add(p.grid) end
    if jam.fill then add(jam.fill.grid) end
    add({ CY = true, SD = true, OH = true, BD = true }) -- the drop's crash, the run-up, the lean-ins: every family
    if lib.hasToms(jam) then add({ HT = true, MT = true, LT = true }) end -- the tom roll
    M.styleSounds = M.styleSounds or {}
    local bySound = M.styleSounds[song.style] or {}
    M.styleSounds[song.style] = bySound
    bySound.drums = bySound.drums or {}
    for patch in pairs(sounds) do bySound.drums[patch] = true end
end

lib.LEANS = { { name = 'hat', layer = 'hats' }, { name = 'kick', layer = 'kick' },
              { name = 'snare', layer = 'snare' } }
lib.TOM_ROLL = { 'HT', 'HT', 'MT', 'LT' } -- the last beat, high to low
lib.TOM_GROUPS = { Funk = true, Breaks = true } -- the genres a tom roll suits (few patterns have toms)
function lib.hasToms(jam) return lib.TOM_GROUPS[jam.group] or false end

-- One bar. play and remember are music-parts' (every note goes through play: mutes, the panel, listeners).
function lib.bookBar(play, remember, synth, t0, song, b)
    local style, jam = D.styles[song.style], song.jam
    announceSounds(song, jam)
    local inPhrase = (b - 1) % style.phraseBars
    advance(jam, style, b)
    local kind = lib.kind(jam.walk, jam.step)
    local pcs = {}
    for _, d in ipairs(riffs.CHORD_SCALES[kind]) do pcs[#pcs + 1] = (song.key + jam.root + d) % 12 end
    remember(t0, pcs) -- impacts play along in the chord's pentatonic on the root
    local lastBar = inPhrase == style.phraseBars - 1
    local roll = stream(song.seed + b * 7919, 10)
    -- THE GAP (J10): before a drop the whole band stops on beat 4, a beat of silence, then the crash
    local gapMove = move('gap')
    local gap = lastBar and gapMove ~= 'never'
        and (gapMove == 'always' or (jam.nextPhrase and jam.nextPhrase.mode == 'drop'))
    local cut = gap and 12 or 16
    -- the spotlight's bars (the phrase's last 4): who plays
    local spot = jam.spot and inPhrase >= style.phraseBars - 4 and jam.spot or nil
    local tradeBass = spot == 'trading' and inPhrase < style.phraseBars - 2 -- the bass's 2, then the drums'
    local bassOut = spot == 'drum break' or (spot == 'trading' and not tradeBass)
    local drumsOut = tradeBass
    if jam.on.bass and not bassOut then
        local loops = lib.BASS_LOOPS[jam.group]
        local figure = picked(lib.FIGURES, picks().figure)
        local riff = figure and figure.riff
        local nextRoot, barsLeft = lib.ahead(jam)
        if spot == 'bass feature' and not riff then -- a riff for the feature, rolled per phrase
            riff = riffs.RIFFS[stream(song.seed + jam.phrase * 7, 12)(#riffs.RIFFS) + 1]
        end
        local loop
        if spot == 'bass feature' then -- its variations in turn: A, B, A, C (or A, B, A, B)
            local letters = {}
            for letter in pairs(riff.vars or {}) do letters[#letters + 1] = letter end
            table.sort(letters)
            local seq = { 'A', letters[1] or 'A', 'A', letters[2] or letters[1] or 'A' }
            loop = riffs.barWith(riff, seq[inPhrase - (style.phraseBars - 4) + 1])
        else
            loop = riff and riffs.bar(riff, barsLeft) or figure and figure.loop or loops[(jam.at - 1) % #loops + 1]
        end
        bookBass(play, synth, song, t0, loop, jam.root, nextRoot, b, riff and true,
                 riff and riffs.degrees(riff, kind) or FIGURE_DEGREES[kind], cut)
    end
    -- the chords come in as a layer with the play level; picked in the panel they play from the next bar
    -- (Nikki: "it took super long before I heard the funk stabs": a calm room never asked for layer 3)
    local chordsPicked = picks().chords and picks().chords ~= 'auto'
    if (jam.on.keys or chordsPicked) and not spot then bookKeys(play, synth, song, t0, jam, kind, cut) end
    local fill = lastBar and (jam.on.snare or jam.mode == 'break')
    -- the family's own fill plays the whole bar, two phrase ends in three; the other third (and the build
    -- before a drop) is the jam's own run-up or tom roll (every Funk family has a written fill: before,
    -- Funk never rolled its toms; dreamengine-4d's spec caught it)
    local build = gap and jam.mode == 'break'
    local written = fill and not build and roll(3) ~= 0 and jam.fill or nil
    local varMove = move('variations')
    local busy = (M.activity or 0) >= 2 * style.perLayer
    local turnaround = varMove ~= 'never' and (varMove == 'always' or busy) and #jam.patterns > 1
        and inPhrase == style.phraseBars - 2
    local pattern = written or jam.patterns[turnaround and jam.at % #jam.patterns + 1 or jam.at]
    local ghosts = varMove ~= 'never' and (varMove == 'always' or busy) and jam.ghosts
    local hats16 = varMove ~= 'never' and jam.group ~= 'Brushes'
        and (varMove == 'always' or (M.activity or 0) >= 3 * style.perLayer)
    local accents = pattern.grid.AC
    -- FILLS (J10): the run-up grows with the play level (a beat, half a bar, the whole bar); the bar before
    -- a drop is the BUILD (snare 16ths over the whole bar, getting louder); families with toms roll down
    -- them on the last beat now and then
    local activity = M.activity or 0
    local runFrom = build and 0
        or activity >= 3 * style.perLayer and 8 or 12
    local toms = fill and not written and not gap and lib.hasToms(jam) and roll(3) == 0
    -- LEANING IN (J10): on the bar before a chord change (not a phrase's last bar, the fill has that) the
    -- drums go with the bass: an open hat on the and-of-4, a kick pickup on its last 16th, or a one-beat
    -- snare fill, rolled per change
    local leanMove, lean = move('lean'), nil
    local nxt = jam.nextRoot
    local changing = nxt and not nxt.linger and nxt.walk[nxt.step] ~= jam.root
    if not lastBar and changing and leanMove ~= 'never' and (leanMove == 'always' or roll(10) < 6) then
        local can = {} -- only a drum that's playing can lean in
        for _, l in ipairs(lib.LEANS) do if jam.on[l.layer] then can[#can + 1] = l.name end end
        lean = #can > 0 and can[roll(#can) + 1] or nil
    end
    for s = 0, cut - 1 do
        local t = stepTime(song, t0, s)
        local accent = accents and accents:sub(s + 1, s + 1) == 'x' and 1 or 0
        if jam.mode == 'drop' and inPhrase == 0 and s == 0 then hit(play, synth, t, 'CY', s, 1, 0, jam.group) end
        for _, layer in ipairs(lib.LAYERS) do
            -- the hats let go before the one (under a run-up, or for the lean-in's open hat)
            local quietFill = (fill and not written or lean == 'hat') and layer.name == 'hats' and s >= 14
            if layer.roles and jam.on[layer.name] and not quietFill and not drumsOut then
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
        if not drumsOut then
            local ch, sd = pattern.grid.CH, pattern.grid.SD
            local run = fill and not written and s >= runFrom
            if run then
                if toms and s >= 12 then
                    hit(play, synth, t, lib.TOM_ROLL[s - 11], s, 0, 0, jam.group)
                else -- a snare run-up, louder toward the one
                    hit(play, synth, t, 'SD', s, 0, math.floor((15 - s) * 3 / (16 - runFrom) + 0.5), jam.group)
                end
            end
            -- the hats doubled to 16ths: a soft one after each 8th the pattern plays
            local hatsFree = s < 14 or not (fill and not written or lean == 'hat')
            if hats16 and jam.on.hats and hatsFree and s % 2 == 1 and ch and ch:sub(s, s) == 'x'
                and ch:sub(s + 1, s + 1) ~= 'x' then
                hit(play, synth, t, 'CH', s, 0, 1, jam.group)
            end
            if ghosts and jam.on.snare and not run and ghosts:sub(s + 1, s + 1) == 'x'
                and not (sd and sd:sub(s + 1, s + 1) == 'x') then
                hit(play, synth, t, 'SD', s, 0, 3, jam.group) -- a ghost: barely there
            end
            if lean == 'hat' and s == 14 and jam.on.hats then hit(play, synth, t, 'OH', s, 1, 0, jam.group) end
            if lean == 'kick' and s == 15 and jam.on.kick then hit(play, synth, t, 'BD', s, 0, 1, jam.group) end
            if lean == 'snare' and s >= 12 and jam.on.snare then
                hit(play, synth, t, 'SD', s, 0, 15 - s >= 2 and 2 or 1, jam.group)
            end
        end
    end
end

return lib
