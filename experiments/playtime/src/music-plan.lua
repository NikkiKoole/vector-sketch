-- music-plan.lua
-- Planning a song before it plays (src/music.lua): which style and key, the chords, the form and
-- each part's role per section, the comps, pushes and fills per bar, the tune's motif and ladder,
-- the loop styles' own plans (satie, ambient, strum), and the tune's 4-bar phrases.

local state = require('src.state')
local D = require('src.music-styles')
state.music = state.music or { activity = 0, withBand = false }
local M = state.music -- on state: it survives a hot reload of any of the music modules
local theory = require('src.music-theory')
local stream = theory.stream
local progAdd = theory.progAdd
local progTurnaround = theory.progTurnaround
local chordAtStep = theory.chordAtStep
local isAvoid = theory.isAvoid
local rubs = theory.rubs
local snapChord = theory.snapChord
local inKey = theory.inKey

local lib = {}

-- songs carry this; a different one on state.music (an old save after a change) starts afresh
local VERSION = 4

local function nextStyleName()
    local style = state.musicSettings.style
    if style ~= 'set' then return D.styles[style] and style or 'bossa' end
    M.setIndex = (M.setIndex or 0) % #D.set + 1
    return D.set[M.setIndex]
end

-- a related key: up a fourth or a fifth when one of D.keys is there, else any other
local function nextKey(previous)
    if not previous then return D.keys[love.math.random(#D.keys)] end
    local related, others = {}, {}
    for _, key in ipairs(D.keys) do
        local d = (key - previous) % 12
        if d == 5 or d == 7 then related[#related + 1] = key elseif d ~= 0 then others[#others + 1] = key end
    end
    local pool = #related > 0 and related or others
    return #pool > 0 and pool[love.math.random(#pool)] or previous
end

-- the song's sections, in order: { kind, bars, chordAt(j) or nil, roles }
local function addSections(song, list)
    song.sections, song.barSection, song.barIndex, song.chords = {}, {}, {}, {}
    for _, entry in ipairs(list) do
        local section = { kind = entry[1], bars = entry[2], roles = entry[4] or {} }
        song.sections[#song.sections + 1] = section
        for j = 0, section.bars - 1 do
            local b = #song.barSection + 1
            song.barSection[b], song.barIndex[b] = section, j
            song.chords[b] = entry[3] and entry[3](j)
        end
    end
    song.bars, song.bar = #song.barSection, 0
end

-- The satie tune may use the key's notes that sit no semitone from any of the chord's
-- (root included); returns that set and the chord's pitch classes.
local function satieAllowed(song, chord)
    local root = (song.key + chord[1]) % 12
    local pcs, ok = { root }, {}
    for _, interval in ipairs(D.satie.qualities[chord[2]]) do pcs[#pcs + 1] = (root + interval) % 12 end
    for _, degree in ipairs({ 0, 2, 4, 5, 7, 9, 11 }) do
        local pc, fine = (song.key + degree) % 12, true
        for _, c in ipairs(pcs) do
            local d = (pc - c) % 12
            if d == 1 or d == 11 then fine = false end
        end
        if fine then ok[pc] = true end
    end
    return ok, pcs
end

-- `count` bars of the satie tune from bar `first`, going on from `pitch`: mostly by step, falling more
-- than rising, the long notes on chord tones; the last bar is an ending, landing on home's 1, 3 or 5
-- when `home`. Returns the last pitch.
local function satieBars(song, rnd, first, count, pitch, home)
    local st = D.satie
    for k = 0, count - 1 do
        local b = first + k
        local ok, pcs = satieAllowed(song, song.chords[b])
        local ladder, tones = {}, {}
        for midi = st.lo, st.hi do
            if ok[midi % 12] then
                ladder[#ladder + 1] = midi
                for _, pc in ipairs(pcs) do if pc == midi % 12 then tones[midi] = true end end
            end
        end
        local last = k == count - 1
        local rhythm = last and st.endings[rnd(#st.endings) + 1] or st.rhythms[rnd(#st.rhythms) + 1]
        local notes, beat = {}, 0
        for n, len in ipairs(rhythm) do
            if len > 0 then
                local target = pitch or 72 + rnd(6)
                local at = 1
                for i, midi in ipairs(ladder) do
                    if math.abs(midi - target) < math.abs(ladder[at] - target) then at = i end
                end
                if pitch then
                    local dir = pitch > 77 and -1 or pitch < 68 and 1 or (rnd(100) < 62 and -1 or 1)
                    at = math.max(1, math.min(#ladder, at + dir * (rnd(100) < 75 and 1 or 2)))
                end
                local midi = ladder[at]
                local final = last and n == #rhythm or last and rhythm[n + 1] and rhythm[n + 1] < 0
                if len >= 2 or final then -- the long notes and the arrival on chord tones (home's, at the end)
                    local best
                    for _, candidate in ipairs(ladder) do
                        local pc = (candidate - song.key) % 12
                        local wanted = tones[candidate] and (not (home and final) or pc == 0 or pc == 4 or pc == 7)
                        if wanted and (not best or math.abs(candidate - midi) < math.abs(best - midi)) then
                            best = candidate
                        end
                    end
                    midi = best or midi
                end
                notes[#notes + 1] = { beat = beat, len = len, midi = midi }
                pitch = midi
            end
            beat = beat + math.abs(len)
        end
        song.tune[b] = notes
    end
    return pitch
end

local function planSatie(song)
    local st, rnd = D.satie, stream(song.seed, 1)
    local a, b = st.A[rnd(#st.A) + 1], st.B[rnd(#st.B) + 1]
    local function loopOf(prog) return function(j) return prog[j % #prog + 1] end end
    addSections(song, {
        { 'intro', 2, loopOf(a) }, { 'A', 8, loopOf(a) }, { 'A', 8, loopOf(a) }, { 'B', 8, loopOf(b) },
        { 'A', 8, loopOf(a) }, { 'outro', 3, loopOf(st.outro) },
    })
    -- the tune, seeded by its place: every A sings the same, B its own. Two phrases of four bars;
    -- the second starts like the first and ends its own way (home, in A).
    song.tune, song.hasLead = {}, true
    local first = 1
    for _, section in ipairs(song.sections) do
        if section.kind == 'A' or section.kind == 'B' then
            local tuneRnd = stream(song.seed, section.kind == 'A' and 100 or 200)
            satieBars(song, tuneRnd, first, 4, nil, false)
            song.tune[first + 4], song.tune[first + 5] = song.tune[first], song.tune[first + 1]
            local from = song.tune[first + 1][#song.tune[first + 1]] -- every rhythm has a note
            satieBars(song, tuneRnd, first + 6, 2, from.midi, section.kind == 'A')
        end
        first = first + section.bars
    end
end

local function planAmbient(song)
    local am, rnd = D.ambient, stream(song.seed, 1)
    song.drone = am.drones[rnd(#am.drones) + 1]
    addSections(song, { { 'intro', 4 }, { 'A', 24 }, { 'outro', 4 } })
    -- each loop's figure: a few notes of the pentatonic in its register, a few 16ths apart
    song.figures = {}
    for k, loop in ipairs(am.loops) do
        local figureRnd, ladder = stream(song.seed, 300 + k), {}
        for midi = loop.lo, loop.lo + 12 do
            for _, d in ipairs(am.penta) do if (midi - song.key - d) % 12 == 0 then ladder[#ladder + 1] = midi end end
        end
        local figure, step, at = {}, figureRnd(4), figureRnd(#ladder) + 1
        for n = 1, loop.notes do
            figure[n] = { step = step, midi = ladder[at] }
            step = step + 3 + figureRnd(6)
            at = math.max(1, math.min(#ladder, at + (figureRnd(2) * 2 - 1) * (1 + figureRnd(2))))
        end
        song.figures[k] = figure
    end
end

-- Data lookups for the planner: a style names its form set, its riffs and its horn figures
local FORMS = { lofi = D.lofiForms, buymode = D.buymodeForms, jingle = D.jingleForms }
local RIFFS = { dumont = D.dumontRiffs, dusk = D.duskRiffs }
local HORN_HITS = { citypop = D.cityHornHits }

-- a loop style: one section, no chords and no tune
local function planLoop(song, style)
    local section = { kind = 'loop', bars = style.bars, roles = {} }
    song.sections, song.barSection, song.barIndex = { section }, {}, {}
    for j = 0, style.bars - 1 do song.barSection[j + 1], song.barIndex[j + 1] = section, j end
    song.bars, song.bar = style.bars, 0
end
local LOOP_PLANS = { satie = planSatie, ambient = planAmbient }

-- the key (lofi: the relative minor half the time), the A progression and the B: another loop from
-- the bank (lofi), A with a ii-V turnaround, or a move of its own
local function planChords(song, style, rnd)
    song.lydian = rnd() < (style.lydianChance or 0)
    song.minor = style.minorChance and rnd(100) < style.minorChance
    if song.minor then song.key = (song.setKey + 9) % 12 end
    song.home = song.minor and style.homeMinor or style.home
    local bank = song.minor and style.Aminor or style.A
    local chordBars = style.chordBars[rnd(#style.chordBars) + 1]
    local aIndex = rnd(#bank) + 1
    song.A = {}
    for _, chord in ipairs(bank[aIndex]) do progAdd(song.A, chord[1], chord[2], (chord[3] or 4) * chordBars) end
    song.B = {}
    if style.B == 'A' and rnd(100) < 60 then
        local bIndex = (aIndex + rnd(#bank - 1)) % #bank + 1
        for _, chord in ipairs(bank[bIndex]) do progAdd(song.B, chord[1], chord[2], (chord[3] or 4) * chordBars) end
    elseif style.B == 'A' or rnd(100) < (style.turnaroundOdds or 35) then
        for _, chord in ipairs(song.A) do progAdd(song.B, chord.degree, chord.quality, chord.steps / 4) end
        progTurnaround(song.B, song.minor, style.B == 'A')
    else
        for _, chord in ipairs(style.B[rnd(#style.B) + 1]) do progAdd(song.B, chord[1], chord[2], chord[3]) end
    end
end

-- each part's role per section (bass: 'play', 'last' bar only, 'hold' or 'none')
local function sectionRoles(style, kind, aCount, rnd)
    if kind == 'intro' then
        local roles = { keys = 'hold', drums = 'none', lead = false, bass = 'play' }
        if style.introHats then -- lofi: the hats come in for the intro's last two bars, the bass maybe
            roles.drums = rnd(100) < 45 and 'hats' or 'none'
            roles.bass = rnd(100) < 50 and 'last' or 'none'
        end
        return roles
    elseif kind == 'break' then
        return { keys = 'hold', drums = rnd(100) < 35 and 'rim' or 'none', lead = rnd(100) < 30,
                 bass = rnd(100) < 50 and 'hold' or 'none' }
    elseif kind == 'outro' then
        return { keys = 'outro', drums = 'outro', lead = false, bass = 'play' }
    end
    -- the first A has no tune: the band plays the changes once first
    return { keys = 'comp', drums = 'full', lead = kind ~= 'A' or aCount >= 2, bass = 'play' }
end

-- the form: sections with their roles, a lift (a key change) or chords of their own
local function planForm(song, style, rnd)
    song.sections, song.barSection, song.barIndex = {}, {}, {}
    local aCount = 0
    local forms = FORMS[style.forms] or D.forms
    song.hasLead = not style.leadChance or rnd(100) < style.leadChance
    for _, entry in ipairs(forms[rnd(#forms) + 1]) do
        local kind, bars = entry[1], entry[2]
        if kind == 'A' then aCount = aCount + 1 end
        local roles = sectionRoles(style, kind, aCount, rnd)
        if entry.lead == false then roles.lead = false end
        local section = { kind = kind, bars = bars, roles = roles, lift = entry.lift,
                          dipLast = (kind == 'A' or kind == 'B') and rnd(100) < 25 }
        if entry.prog then
            section.prog = {}
            for _, chord in ipairs(style.progs[entry.prog]) do progAdd(section.prog, chord[1], chord[2], chord[3]) end
        end
        song.sections[#song.sections + 1] = section
        for j = 0, bars - 1 do
            song.barSection[#song.barSection + 1] = section
            song.barIndex[#song.barIndex + 1] = j
        end
    end
    song.bars = #song.barSection
end

-- A steady style decides once per song what the others roll per bar, and keeps to it: songs of the
-- style differ, a song holds its groove. One comp cell for the A sections and one for B (or one for
-- both: sameCell), the push a habit or not (always into the same bar: every pushEvery bars, the 4th
-- by default), the side-step too, which of the cell's stabs are light, and the comping: shells (3rd,
-- 7th, a colour) or the full 9ths. A mood (pickMood) narrows the cells and sets the habit. Its own
-- stream: the planner's others keep their draws, so the other styles don't change.
local function planSteady(song, style, weights, total, mood)
    local rnd = stream(song.seed, 14)
    local allowed = mood and mood.cells
    local function pickCell()
        local sum = 0
        for i, w in ipairs(weights) do
            if not allowed or allowed[i] then sum = sum + w end
        end
        local u = rnd() * (allowed and sum or total)
        for i, w in ipairs(weights) do
            if not allowed or allowed[i] then
                if u < w then return i end
                u = u - w
            end
        end
        return #weights
    end
    local cells = { A = pickCell(), B = pickCell() }
    if style.sameCell then cells.B = cells.A end
    local habit = mood and mood.pushHabit or style.pushHabit or (style.pushOdds or 0) * 3
    song.pushes = rnd(100) < habit
    song.sidesteps = rnd(100) < (style.sidestepOdds or 0) * 2
    song.lightMask = {}
    for i, cell in ipairs(D.compsOf(style)) do
        song.lightMask[i] = {}
        for h = 1, #cell do song.lightMask[i][h] = rnd(100) < (style.lightOdds or 30) end
    end
    song.comping = rnd(100) < (style.shellOdds or 50) and 'shell' or 'full'
    song.kicks = not (mood and mood.kicks == false)
    local every = style.pushEvery or 4
    for b = 1, song.bars do
        song.comp[b] = cells[song.barSection[b].kind] or cells.A
        song.push[b] = song.pushes and song.barIndex[b] % every == every - 1
    end
end

-- per bar, knowing the next: the comp cell (per two bars), the push and a fill
local function planBars(song, style, between, mood)
    song.comp, song.push, song.fill = {}, {}, {}
    local rnd = stream(song.seed, 2)
    local weights, total = {}, 0
    for i = 1, #D.compsOf(style) do
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
    if style.steady then planSteady(song, style, weights, total, mood) end
end

-- the tune: the motif rhythm and its cell's anchor pitches, the scale, and a ladder of the key's
-- pentatonic above the chord (median ~76, lofi's 67..86) with where each section's tune starts
local function planTune(song, style, rnd)
    local motif = D.motifs[rnd(#D.motifs) + 1]
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
    -- major, dorian (minor with the major sixth) or minor, and its pentatonic
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
    song.homeKey, song.homeLadder, song.lift = song.key, song.ladder, 0 -- a lifted section moves both
    song.hookStart = { A = 4 + rnd(3), B = 3 + rnd(4) } -- ladder index where each section's tune starts
end

-- the song's own figures, each from its own stream: the riff, the horn shout, citypop's bass figure,
-- guitar cutting and kit groove
local function planParts(song, style)
    local riffs = RIFFS[style.riffs] or D.riffs
    song.riff = riffs[stream(song.seed, 3)(#riffs) + 1]
    if style.horns then
        local hits = HORN_HITS[style.horns] or D.hornHits
        song.horns = hits[stream(song.seed, 10)(#hits) + 1]
    end
    if style.flavors then -- jingle: how this song voices its borrowed chords
        local pick = stream(song.seed, 12)
        song.flavor = {}
        local names = {}
        for name in pairs(style.flavors) do names[#names + 1] = name end
        table.sort(names) -- a fixed order: the picks draw from one stream
        for _, name in ipairs(names) do
            local choices = style.flavors[name]
            song.flavor[name] = choices[pick(#choices) + 1]
        end
    end
    if style.picking == 'jingle' then -- the fingerpicking order, a strummed chorus or not, the tune's cell
        local pick = stream(song.seed, 13)
        song.pickOrder = D.jinglePicks[pick(#D.jinglePicks) + 1]
        song.strumChorus = pick(100) < 50
        song.cell = {}
        for s = 0, 30, 2 do
            if #song.cell < 5 and pick(100) < (s % 8 == 0 and 25 or 35) then song.cell[#song.cell + 1] = s end
        end
        if #song.cell < 3 then song.cell = { 2, 12, 20 } end
    end
    if style.drums == 'session' then
        local pick = stream(song.seed, 11)
        song.bassFigure = D.cityBass[pick(#D.cityBass) + 1]
        song.chuck = D.cityChucks[pick(#D.cityChucks) + 1]
        song.groove = D.cityGrooves[pick(#D.cityGrooves) + 1]
    end
end

-- lofi: the groove (one of the kit's grids, weighted by tempo), the bass held long or short, the
-- Rhodes' own lowpass and the tape's tone (the lowpass the sections ride)
local function planTone(song, style, rnd, between)
    if style.groove == 'lofi' then
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
end

-- A style's moods are the kinds of tune it plays (guaraldi: a bounce or a ballad), one per song:
-- its tempo, swing, comp cells and push habit. Its own stream.
local function pickMood(style, seed)
    if not style.moods then return nil end
    local rnd, total = stream(seed, 15), 0
    for _, mood in ipairs(style.moods) do total = total + mood.weight end
    local u = rnd() * total
    for _, mood in ipairs(style.moods) do
        if u < mood.weight then return mood end
        u = u - mood.weight
    end
    return style.moods[#style.moods]
end

-- setKey: the set's key for the song (a cue's choice); nil: a related key, a fourth from the last
local function planSong(setKey)
    local styleName = nextStyleName()
    local style = D.styles[styleName]
    local seed = love.math.random(1, 2147483646)
    local function between(range) -- a style value that is a number, or a { lo, hi } to roll per song
        if type(range) ~= 'table' then return range end
        return range[1] + love.math.random() * (range[2] - range[1])
    end
    setKey = setKey or nextKey(M.song and M.song.setKey)
    local mood = pickMood(style, seed)
    local song = {
        version = VERSION, style = styleName, seed = seed, setKey = setKey, key = setKey,
        mood = mood and mood.name,
        beat = 60 / math.floor(between(mood and mood.bpm or style.bpm) + 0.5),
        swing = between(mood and mood.swing or style.swing) or 0.5,
        swing16 = style.swing16, snareLag = between(style.snareLagMs or 8) / 1000,
    }
    song.barLength = (style.meter or 4) * song.beat
    if style.loop then
        (LOOP_PLANS[style.loop] or planLoop)(song, style)
        return song
    end
    local rnd = stream(seed, 1)
    planChords(song, style, rnd)
    planForm(song, style, rnd)
    planBars(song, style, between, mood)
    rnd = stream(seed, 9)
    planTune(song, style, rnd)
    planParts(song, style)
    planTone(song, style, rnd, between)
    song.bar = 0
    return song
end

-- One phrase over four bars from bar b (the first of them): the motif stated over bars 1-2, bar 3
-- breathes, bar 4 answers. Seeded by its place (section kind + which four bars), so it comes back
-- the same every time that place does. Notes are { step 0..63, midi, vol, len in steps, grace }.
local function buildPhrase(song, b)
    local section, j = song.barSection[b], song.barIndex[b]
    local slot = math.floor(j / 4)
    local rnd = stream(song.seed, 5000 + (section.kind == 'B' and 100 or 0) + slot)
    local style = D.styles[song.style]
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
    local answer = D.answers[rnd(#D.answers) + 1]
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

lib.VERSION = VERSION
lib.nextStyleName = nextStyleName
lib.nextKey = nextKey
lib.addSections = addSections
lib.satieAllowed = satieAllowed
lib.satieBars = satieBars
lib.planSatie = planSatie
lib.planAmbient = planAmbient
lib.FORMS = FORMS
lib.RIFFS = RIFFS
lib.HORN_HITS = HORN_HITS
lib.planLoop = planLoop
lib.LOOP_PLANS = LOOP_PLANS
lib.planChords = planChords
lib.sectionRoles = sectionRoles
lib.planForm = planForm
lib.pickMood = pickMood
lib.planBars = planBars
lib.planTune = planTune
lib.planParts = planParts
lib.planTone = planTone
lib.planSong = planSong
lib.buildPhrase = buildPhrase

return lib
