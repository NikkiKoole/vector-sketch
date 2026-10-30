-- music-parts.lua
-- Playing a planned bar, part by part (src/music.lua calls these from bookBar): every note goes
-- through play (the layers' mutes, a handoff's clip, onNote listeners, music.trace), the bass lines,
-- drum kits and lofi grooves, the loop styles' bars, and the keys, bass, riff, drums, horns,
-- guitar, strings and tune of a song bar.

local state = require('src.state')
local D = require('src.music-styles')
state.music = state.music or { activity = 0, withBand = false }
local M = state.music -- on state: it survives a hot reload of any of the music modules
local theory = require('src.music-theory')
local stream = theory.stream
local voiceChord = theory.voiceChord
local inRange = theory.inRange
local humanize = theory.humanize
local qualityOf = theory.qualityOf
local chordAtStep = theory.chordAtStep
local rubs = theory.rubs
local stepTime = theory.stepTime
local lengthMs = theory.lengthMs
local plan = require('src.music-plan')
local buildPhrase = plan.buildPhrase

local lib = {}

local function bandPlays()
    if state.musicSettings.rhythmSection == 'on' then return true end
    if state.musicSettings.rhythmSection == 'off' then return false end
    if M.withBand and M.activity < D.bandLeaves then M.withBand = false end
    if not M.withBand and M.activity > D.bandJoins then M.withBand = true end
    return M.withBand
end

---------------------------------------------------------------------------------------------------
-- The song plan

-- every note goes through here; M.trace(part, t, midi, vol, durMs), when set, sees them all
-- (claudetools/render-music.lua counts rubs with it)
local function notify(part, patch, midi, vol, durMs, t, step)
    -- what each part plays, for music.playing: per patch the runs of notes sounding back to back. Bars
    -- are booked ahead, so the next bar's run starts while the last one still sounds: keep a few.
    M.heard[part] = M.heard[part] or {}
    local runs = M.heard[part][patch] or {}
    M.heard[part][patch] = runs
    local last, ends = runs[#runs], t + math.max(durMs / 1000, 0.15) -- short hits still show
    if last and t >= last.from and t <= last.to then last.to = math.max(last.to, ends)
    else runs[#runs + 1] = { from = t, to = ends } end
    while #runs > 1 and runs[1].to < (M.audioTime or 0) - 10 do table.remove(runs, 1) end
    for name, fn in pairs(M.listeners) do
        local ok, err = pcall(fn, part, patch, midi, vol, durMs, t, step)
        if not ok then M.listeners[name] = nil; print('[music] onNote ' .. name .. ': ' .. tostring(err)) end
    end
end

-- M.mute: the parts that sit this bar out (the layers, a handoff); M.clipAt: no note rings past it
local function play(synth, part, patch, t, midi, vol, durMs, step)
    if M.mute and M.mute[part] then return end
    if M.clipAt and t + durMs / 1000 > M.clipAt then durMs = math.max(20, (M.clipAt - t) * 1000) end
    synth.scheduleAt(patch, t, midi, vol, durMs)
    if M.trace then M.trace(part, t, midi, vol, durMs) end
    notify(part, patch, midi, vol, durMs, t, step)
end

-- One bar of Puppetmaker's loop: every hit rolls its chance, rnd ones land on a random semitone.
-- Busy play gets the crowd's dense page, calm the editor's sparse one.
local function bookLoopBar(synth, t0, song, b)
    local pm, rnd = D.puppetmaker, stream(song.seed, 6000 + b)
    for _, voice in ipairs(bandPlays() and pm.dense or pm.sparse) do
        local patch, midi, durMs, hits = voice[1], voice[2], voice[3], voice[4]
        for _, h in ipairs(hits) do
            if rnd(100) < h[2] then
                local s, shift = h[1] - 1, h[3] and rnd(12) - 6 or 0
                local t = stepTime(song, t0, s) + humanize(0.003)
                if patch == 'chord' then -- the rolled Rhodes chord, an up-strum
                    local root, pcs = pm.chordRoot + shift, {}
                    for k, interval in ipairs(pm.chord) do
                        play(synth, 'chord', 'rhodes', t + pm.strum[k] / 1000, root + interval, 4,
                             pm.chordMs - pm.strum[k], s)
                        pcs[#pcs + 1] = (root + interval) % 12
                    end
                    table.insert(M.booked, { at = t, pcs = pcs }) -- impacts play along in its notes
                    if #M.booked > 4 then table.remove(M.booked, 1) end
                elseif patch:sub(1, 7) == 'sample:' then -- a sample: only the listeners play it
                    if not (M.mute and M.mute.sample) then
                        notify('sample', patch:sub(8), midi + shift, 5, durMs, t, s)
                    end
                else
                    play(synth, 'perc', patch, t, midi + shift, patch == 'tamb' and 4 or 5, durMs, s)
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
    -- walk: calm, a two-feel (the root on 1, the fifth on 3); with the band, quarter notes: the root,
    -- up through the chord, the last beat a half-step into the next root (a whole step when the
    -- half-step would rub the chord)
    walk = function(hit, chord, lo, lastBar, nextRoot, fits, band)
        local root, e = inRange(chord.root, lo), chord.s + chord.len
        local third = root + 4
        for _, interval in ipairs(D.qualities[chord.quality] or {}) do
            if interval % 12 == 3 then third = root + 3 end
        end
        local fifth = fits(root + 7, chord) and root + 7 or root
        if not band then
            if chord.s == 0 or chord.s == 8 then hit(chord.s, root, 5, math.min(8, chord.len)) end
            if chord.s == 0 and e > 8 then hit(8, fifth, 4, e - 8) end
            return
        end
        local beats = {}
        for s = chord.s, e - 1 do if s % 4 == 0 then beats[#beats + 1] = s end end
        local line = { root, third, fifth, root + 9 }
        if #beats >= 2 then
            local last = line[#beats - 1]
            if lastBar and nextRoot then
                local target = inRange(nextRoot, lo)
                if math.abs(target + 12 - last) < math.abs(target - last) then target = target + 12 end
                local from = last > target and 1 or -1
                local approach = target + from
                if not fits(approach, chord) then approach = target + 2 * from end
                line[#beats] = fits(approach, chord) and approach or fifth
            elseif #beats == 4 then
                line[4] = fits(root + 9, chord) and root + 9 or fifth
            end
        end
        for i, s in ipairs(beats) do hit(s, line[i], i == 1 and 5 or 4, 4) end
    end,
    -- disco (citypop): the song's figure, root, octave pops and dead-note ghosts, each note held to
    -- the next; with the band, two 16ths running chromatically into the next root. Calm: the root
    -- held, one pop.
    disco = function(hit, chord, lo, lastBar, nextRoot, fits, band, song)
        local root, e = inRange(chord.root, lo), chord.s + chord.len
        local pop = fits(root + 12, chord) and root + 12 or root
        if not band then
            hit(chord.s, root, 5, math.min(6, chord.len))
            if chord.s <= 6 and e > 6 then hit(6, pop, 3, 1) end
            return
        end
        local run = lastBar and nextRoot and nextRoot ~= chord.root
        local stop = run and 14 or e
        local figure = song.bassFigure
        local function at(s) return s == chord.s and 'x' or figure:sub(s + 1, s + 1) end
        for s = chord.s, stop - 1 do
            local c = at(s)
            if c ~= '.' then
                local len = 1
                while s + len < stop and at(s + len) == '.' do len = len + 1 end
                if c == 'x' then hit(s, root, s == 0 and 5 or 4, len) -- whole steps: the grid has no halves
                elseif c == 'o' then hit(s, pop, 4, 1)
                else hit(s, root, 2, 1) end
            end
        end
        if run then
            local target = inRange(nextRoot, lo)
            local dir = target > root and 1 or -1
            hit(14, target - 2 * dir, 3, 1)
            hit(15, target - dir, 3, 1)
        end
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
    -- dusk: island's kit, lazier: a kick on 1 (the and-of-3 now and then), a brush sweep every other
    -- bar, one rim on 4, the shaker only on the off-beats; a conga in B
    dusk = function(hit, rnd, kind, j, fill)
        hit(0, 'kick', 36, 3, 150)
        if rnd(100) < 50 then hit(10, 'kick', 36, 2, 120) end
        if j % 2 == 0 then hit(0, 'brush', 70, 2, 900) end
        hit(12, 'rim', 79, 3, 40)
        for s = 2, 14, 4 do hit(s, 'shaker', 84, 1, 40) end
        if kind == 'B' then hit(14, 'conga', 59, 2, 200) end
        if fill then hit(13, 'conga', 64, 2, 200); hit(14, 'conga', 61, 3, 200); hit(15, 'conga', 59, 3, 200) end
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
    -- citypop's session kit: the song's groove (disco four, funk ghosts, the push, the skip),
    -- session-tight, 16th hats leaning on the 8ths, a shaker in the chorus, a conga now and then;
    -- fills roll on the snare or go round the toms
    session = function(hit, rnd, kind, _, fill, song)
        local groove = song.groove
        for s = 0, 15 do
            if groove.k:sub(s + 1, s + 1) == 'x' then hit(s, 'kick', 36, 5, 150) end
            local sn = groove.s:sub(s + 1, s + 1)
            if sn == 'x' and not (fill and s >= 12) then hit(s, 'snare', 60, 5, 140)
            elseif sn == 'g' then hit(s, 'snare', 60, 1, 50) end
            hit(s, 'hat', 60, s % 4 == 0 and 3 or s % 2 == 0 and 2 or 1, 25)
        end
        if kind == 'B' then for s = 2, 14, 4 do hit(s, 'shaker', 84, 2, 40) end end
        if rnd(100) < 30 then hit(14, 'conga', 64, 3, 200) end
        if fill then
            if rnd(100) < 50 then
                for s = 12, 15 do hit(s, 'snare', 60, s - 10, 60) end
            else
                for s, midi in ipairs({ 50, 47, 43, 40 }) do hit(11 + s, 'tom', midi, s < 3 and 4 or 5, 200) end
            end
        end
    end,
    -- a 70s TV band on sticks: the ride's ding ding-ga ding leaning on 2 and 4, the hat's foot on 2
    -- and 4, a feathered kick, the snare dropping in now and then; a rim backbeat in B; snare fills
    sticks = function(hit, rnd, kind, _, fill)
        for s = 0, 12, 4 do hit(s, 'ride', 81, s % 8 == 0 and 3 or 4, 220) end
        hit(6, 'ride', 81, 2, 120)
        hit(14, 'ride', 81, 2, 120)
        hit(4, 'hat', 60, 3, 40)
        hit(12, 'hat', 60, 3, 40)
        for s = 0, 12, 4 do hit(s, 'kick', 33, 2, 60) end
        if rnd(100) < 25 then hit(14, 'snare', 60, 2, 60) end
        if rnd(100) < 20 then hit(10, 'snare', 60, 1, 50) end
        if kind == 'B' then hit(4, 'rim', 79, 3, 40); hit(12, 'rim', 79, 3, 40) end
        if fill then
            for _, s in ipairs({ 8, 10, 12, 14 }) do hit(s, 'snare', 60, s < 12 and 3 or 4, 60) end
            hit(14, 'kick', 36, 4, 120)
        end
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
    -- lanes in a fixed order: the velocities draw from rnd hit by hit, and pairs() order is the hash's
    -- (it moved when this file changed, and differs between LuaJIT builds and the web's Lua)
    for _, lane in ipairs({ 'S', 'H', 'K', 'R' }) do
        local pattern = grid[lane] or ''
        for i = 1, #pattern do
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

local function remember(t0, pcs) -- impacts play along in the chord
    table.insert(M.booked, { at = t0, pcs = pcs })
    if #M.booked > 4 then table.remove(M.booked, 1) end
end

-- One bar of the satie waltz: the root on 1 held through the bar, the chord on 2 held through 3, the
-- planned tune on the felt piano. Busy play: a sine under the root and vibes doubling the tune.
-- The outro's last chord rings two bars, struck on 1.
local function bookSatieBar(synth, t0, song, b)
    local chord = song.chords[b]
    local root, intervals = (song.key + chord[1]) % 12, D.satie.qualities[chord[2]]
    local pcs = { root }
    for _, interval in ipairs(intervals) do pcs[#pcs + 1] = (root + interval) % 12 end
    remember(t0, pcs)
    local band, barMs = bandPlays(), lengthMs(song, 0, 12)
    local ringMs = chord.ring and 2 * barMs or barMs - 30
    local bass = inRange(root, 38)
    play(synth, 'bass', 'piano', t0 + humanize(0.004), bass, 5, ringMs, 0)
    if band then play(synth, 'bass', 'roundBass', t0, bass, 1, ringMs, 0) end
    song.voicing = voiceChord(root, intervals, 53, 67, song.voicing)
    local s = chord.ring and 0 or 4
    local t = stepTime(song, t0, s) + humanize(0.006)
    for k, midi in ipairs(song.voicing) do
        play(synth, 'keys', 'piano', t + (k - 1) * 0.012, midi, 4, ringMs - lengthMs(song, 0, s), s)
    end
    if not state.musicSettings.melody then return end
    for _, note in ipairs(song.tune[b] or {}) do
        local ns = note.beat * 4
        local nt = stepTime(song, t0, ns) + humanize(0.008)
        local dur = lengthMs(song, ns, note.len * 4) - 20
        play(synth, 'lead', state.musicSettings.melodyPatch or 'pianoLead', nt, note.midi, 6, dur, ns)
        if band then play(synth, 'lead', 'vibes', nt, note.midi, 2, dur, ns) end
    end
end

-- One bar of the ambient style: the drone every 8 bars, and each loop's figure wherever its own
-- length puts it (counted from the bar it joined).
local function bookAmbientBar(synth, t0, song, b)
    local am, pcs = D.ambient, {}
    for _, d in ipairs(am.penta) do pcs[#pcs + 1] = (song.key + d) % 12 end
    remember(t0, pcs)
    if (b - 1) % 8 == 0 then -- the drone, root and fifth, ringing until the next one
        local degree = song.drone[math.floor((b - 1) / 8) % #song.drone + 1]
        local root = inRange((song.key + degree) % 12, 36)
        local ms = lengthMs(song, 0, 16 * math.min(8, song.bars - b + 1)) - 30
        play(synth, 'bass', 'roundBass', t0, root, 2, ms, 0)
        play(synth, 'bass', 'roundBass', t0, root + 7, 1, ms, 0)
    end
    local band = bandPlays()
    for k, loop in ipairs(am.loops) do
        if b >= loop.joins and b <= song.bars - (k - 1) and (band or not loop.band) then
            for s = 0, 15 do
                local at = ((b - loop.joins) * 16 + s) % loop.steps
                for _, note in ipairs(song.figures[k]) do
                    if note.step == at then
                        play(synth, 'keys', loop.patch, stepTime(song, t0, s) + humanize(0.01), note.midi,
                             loop.vol, loop.ring, s)
                    end
                end
            end
        end
    end
end

-- buymode's key change: a lifted section moves the key and the tune's ladder
local function applyLift(song, section)
    local lift = section.lift or 0
    if song.homeKey and lift ~= song.lift then
        song.lift, song.key = lift, (song.homeKey + lift) % 12
        song.ladder = {}
        for i, midi in ipairs(song.homeLadder) do song.ladder[i] = midi + lift end
        song.phraseBar = nil
    end
end

-- The keys' hits in a bar: the comp cell clipped to the chords, held chords in the intro and outro,
-- the push (the next chord on the and-of-4) or the side-step. Returns the hits, where the
-- side-step starts and whether the bar pushes.
local function keysHits(bar)
    local song, style, b, j, section, roles = bar.song, bar.style, bar.b, bar.j, bar.section, bar.roles
    local chords, nextChords, rnd = bar.chords, bar.nextChords, bar.rnd
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
        local cell = D.compsOf(style)[song.comp[b - j % 2] or 1]
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
    return hits, sidestepAt, pushes
end

-- the keys play their hits, rolled by the style's strum; the dub echo repeats a stab while its chord lasts
local function bookKeys(bar, hits)
    local synth, song, style, t0 = bar.synth, bar.song, bar.style, bar.t0
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
            play(synth, 'keys', style.keys, t + (k - 1) * strum, note, math.min(7, vol), dur)
            if style.echo and style.echo.keys and not h.sidestep then
                for e = 1, 2 do
                    local s, chordEnd = h.s + 3 * e, h.chord.s + h.chord.len
                    if s >= chordEnd or vol - 2 * e < 1 then break end
                    local echoDur = math.min(dur, lengthMs(song, s, chordEnd - s) * 0.9) -- not into the next chord
                    play(synth, 'keys', style.keys, stepTime(song, t0, s) + (k - 1) * strum, note, vol - 2 * e, echoDur)
                end
            end
        end
    end
end

-- herbs and lofi: the vinyl, a hiss bed a section long and crackle ticks
local function bookVinyl(bar)
    local synth, song, t0, section, rnd = bar.synth, bar.song, bar.t0, bar.section, bar.rnd
    if bar.j == 0 then -- the hiss bed, one long note a section, crossfading into the next
        play(synth, 'vinyl', 'hiss', t0, 60, 4, lengthMs(song, 0, 16 * section.bars) + 300)
    end
    local ticks = (section.kind == 'intro' or section.kind == 'outro') and 5 or 3
    for _ = 1, ticks do play(synth, 'vinyl', 'crackle', stepTime(song, t0, rnd(16)), 90 + rnd(12), 1, 8) end
end

-- the bass: the left hand, or the upright when the band plays with it; the outro's last bar rests. It
-- lets go when the next chord comes in early. lofi's plays on its groove's kicks.
local function bookBass(bar, groove, pushes, sidestepAt)
    local synth, song, style, t0, b, j = bar.synth, bar.song, bar.style, bar.t0, bar.b, bar.j
    local section, chords, nextChords, band = bar.section, bar.chords, bar.nextChords, bar.band
    local upright = band and state.musicSettings.upright and bar.roles.drums ~= 'none'
    local bassPatch = upright and 'musicBass' or style.bassPatch or style.keys
    local lo = upright and 34 or style.bassLo or 40
    local bassRole = bar.roles.bass or 'play'
    local nextRoot = nextChords and (song.key + nextChords[1].degree) % 12
    if bassRole == 'none' or (bassRole == 'last' and j < section.bars - 1) then
        return -- the bass sits this one out
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
        lofiBass(hit, chords, nextRoot, steps, stop, stream(song.seed, 4000 + b), song.legato and 0.92 or 0.55)
    elseif not (section.kind == 'outro' and j > 2) then
        local stop = pushes and 14 or sidestepAt or 16
        local function hit(s, midi, vol, len)
            len = math.min(len, stop - s)
            if len <= 0 then return end
            local t = stepTime(song, t0, s) + humanize(0.004)
            play(synth, 'bass', bassPatch, t, midi, vol, lengthMs(song, s, len) * 0.95)
        end
        local function fits(midi, chord) return not rubs(song, midi, chord) end
        local bassLine = bassLines[style.bass] or bassLines.hold
        for _, chord in ipairs(chords) do
            bassLine(hit, chord, lo, chord.s + chord.len == 16, nextRoot, fits, band, song)
        end
    end
end

-- the riff: the song's own pattern over the chord's voicing, in eighths; it starts the intro
-- alone and rings out in the outro
local function bookRiff(bar)
    local synth, song, style, t0, b = bar.synth, bar.song, bar.style, bar.t0, bar.b
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

-- the drums, where the form and the play let them: lofi's groove (the snare and the rim laid back by
-- the song's lag), or the style's kit
local LOFI_LANES = { K = { 'lofiKick', 32 }, S = { 'snare', 60 }, H = { 'hat', 60 }, R = { 'rim', 79 } }
local function bookDrums(bar, groove)
    local synth, song, style, t0, j, roles = bar.synth, bar.song, bar.style, bar.t0, bar.j, bar.roles
    if groove then
        for _, h in ipairs(groove.hits) do
            local patch = LOFI_LANES[h.lane]
            local lag = (h.lane == 'S' or h.lane == 'R') and song.snareLag or 0
            local t = stepTime(song, t0, h.s) + lag + humanize(h.lane == 'H' and 0.006 or 0.004)
            local vol = math.max(1, math.min(7, math.floor(h.vel * (h.lane == 'H' and 4.5 or 7) + 0.5)))
            local dur = h.lane == 'K' and 200 or h.lane == 'S' and 140 or h.open and 160 or 30
            play(synth, 'drums', patch[1], t, patch[2], vol, dur)
            if h.lane == 'S' and not h.ghost then play(synth, 'drums', 'lofiKick', t, 48, math.max(1, vol - 2), 90) end
        end
        return
    end
    local kit = style.drums and drumKits[style.drums]
    local drums = roles.drums == 'full' or (roles.drums == 'outro' and j < 2)
    if kit and bar.band and drums then
        local function hit(s, patch, midi, vol, dur, dt)
            local drag = (style.swing > 0.5 and s % 8 == 4) and 0.008 or 0 -- the backbeat lays back a hair
            local t = stepTime(song, t0, s) + drag + (dt or 0) + humanize(0.003)
            play(synth, 'drums', patch, t, midi, vol, dur)
        end
        kit(hit, bar.rnd, bar.section.kind, j, song.fill[bar.b], song)
    end
end

-- the band plays the keys' own voicing of a chord (its notes never rub each other; the same
-- chord voiced again elsewhere can put a 9th a b9 over the minor third, or a #9 over the third)
local function keysVoicing(song, chord)
    return voiceChord((song.key + chord.degree) % 12, qualityOf(song, chord.quality), 48, 76, M.voicing)
end

-- the horns: the song's shout in the bar the tune breathes (bar 3 of 4), the top of the chord
local function bookHorns(bar)
    local synth, song, t0 = bar.synth, bar.song, bar.t0
    for _, h in ipairs(song.horns) do
        local voicing = keysVoicing(song, chordAtStep(song, bar.b, h[1]))
        local t = stepTime(song, t0, h[1]) + humanize(0.004)
        for k = math.max(1, #voicing - 2), #voicing do
            play(synth, 'horns', 'horn', t + (k - 1) * 0.004, voicing[k], h[3], lengthMs(song, h[1], h[2]) * 0.85)
        end
    end
end

-- citypop's guitar: the song's 16th cutting on the chord's top notes
local function bookGuitar(bar, pushes)
    local synth, song, t0 = bar.synth, bar.song, bar.t0
    for s = 0, (pushes and 14 or 16) - 1 do
        local c = song.chuck[s + 1]
        if c > 0 then
            local voicing = keysVoicing(song, chordAtStep(song, bar.b, s))
            local t = stepTime(song, t0, s) + humanize(0.002)
            local from = c == 1 and #voicing - 1 or #voicing - 2
            for k = math.max(1, from), #voicing do
                play(synth, 'guitar', 'cityGuitar', t + (k - from) * 0.006, voicing[k], c == 1 and 3 or 4,
                     c == 1 and 50 or 150)
            end
        end
    end
end

-- citypop's strings: the chord's top three held under the chorus, slow in
local function bookStrings(bar)
    local synth, song, t0 = bar.synth, bar.song, bar.t0
    for _, chord in ipairs(bar.chords) do
        local voicing = keysVoicing(song, chord)
        for k = math.max(1, #voicing - 2), #voicing do
            play(synth, 'strings', 'strings', stepTime(song, t0, chord.s), voicing[k], 4,
                 lengthMs(song, chord.s, chord.len) - 40)
        end
    end
end

-- the tune: its 4-bar phrase, built when the phrase starts (seeded by its place in the form)
local function bookTune(bar)
    local synth, song, style, t0, b, j = bar.synth, bar.song, bar.style, bar.t0, bar.b, bar.j
    local phraseBar = b - j % 4
    if song.phraseBar ~= phraseBar then song.phrase, song.phraseBar = buildPhrase(song, phraseBar), phraseBar end
    local patch = state.musicSettings.melodyPatch or style.lead
    local barInPhrase = j % 4
    for _, note in ipairs(song.phrase) do
        if math.floor(note.s / 16) == barInPhrase then
            local t = stepTime(song, t0, note.s % 16) + humanize(0.003)
            if note.grace then play(synth, 'lead', patch, t - 0.05, note.grace, math.max(1, note.vol - 2), 45) end
            play(synth, 'lead', patch, t, note.midi, note.vol, lengthMs(song, note.s % 16, note.len) * 0.9)
        end
    end
end

local LOOP_BARS = { satie = bookSatieBar, ambient = bookAmbientBar }

-- strum's guitar: the strings of a chord's barre grip, low to high (nil = damped)
local function guitarStrings(song, chord)
    local fret = ((song.key + chord.degree) % 12 - 4) % 12 -- the barre, on the root on the low E
    local grip = D.grips[chord.quality] or D.grips.gmaj
    local strings = {}
    for s = 1, 6 do
        if grip[s] >= 0 then strings[s] = D.guitarOpen[s] + fret + grip[s] end
    end
    return strings
end

-- a pedal change, turned when the music gets there (notes are booked ahead; music.update turns it)
local function pedal(t, patch, settings)
    M.pedals = M.pedals or {}
    M.pedals[#M.pedals + 1] = { at = t, patch = patch, tape = settings.tape, flanger = settings.flanger }
end

-- One bar of Travis picking: per beat the thumb (root on 1 and 3, fifth on 2 and 4, palm-damped),
-- a treble string with it on 1 and 3 (the pinch; not in the intro), another on the off-beat. The
-- section's pedal settings turn at its first bar; the outro's third bar is one strum left to ring.
local TRAVIS_PINCH = { [0] = 6, [2] = 4 }
local TRAVIS_OFF = { [0] = 5, 6, 5, 4 }
local function bookTravis(bar)
    local synth, song, style, t0, section, j = bar.synth, bar.song, bar.style, bar.t0, bar.section, bar.j
    local patch = style.pickPatch
    if j == 0 and style.pedals and style.pedals[section.kind] then pedal(t0, patch, style.pedals[section.kind]) end
    if section.kind == 'outro' and j >= 2 then
        if j == 2 then
            local strings = guitarStrings(song, bar.chords[1])
            for s = 1, 6 do
                if strings[s] then play(synth, 'keys', patch, t0 + (s - 1) * 0.028, strings[s], 4, 3200, 0) end
            end
        end
        return
    end
    for beat = 0, 3 do
        local s = beat * 4
        local chord = chordAtStep(song, bar.b, s)
        local strings = guitarStrings(song, chord)
        local ends = chord.s + chord.len -- a string rings up to the next chord, never into it
        local t = stepTime(song, t0, s) + humanize(0.008) -- laid back
        local thumb = strings[beat % 2 == 0 and 1 or 2]
        if thumb then play(synth, 'keys', patch, t, thumb, 4, 600, s) end
        local pinch = section.kind ~= 'intro' and TRAVIS_PINCH[beat] and strings[TRAVIS_PINCH[beat]]
        if pinch then
            play(synth, 'keys', patch, t + 0.012, pinch, 3, math.min(1500, lengthMs(song, s, ends - s)), s)
        end
        local off = strings[TRAVIS_OFF[beat]]
        if off then
            play(synth, 'keys', patch, stepTime(song, t0, s + 2) + humanize(0.008), off, 4,
                 math.min(1500, lengthMs(song, s + 2, ends - s - 2)), s + 2)
        end
    end
end

-- One bar of rollo, after King Rollo's "The Tree" (docs/MUSIC-ANALYSIS.md): the bass holds the root
-- on 1 and 3, the guitar only stabs a high triad on the and of 2 and the and of 4, choked. A phrase's
-- last bar has a three-strum fill instead of the second stab; a section's last bar is one low note
-- left to ring. The intro is the bass and the second stab.
local function jabTriad(song, chord) -- the grip's top three strings, up the neck
    local strings = guitarStrings(song, chord)
    local up = strings[6] and strings[6] < 72 and 12 or 0
    local triad = {}
    for s = 4, 6 do
        if strings[s] then triad[#triad + 1] = strings[s] + up end
    end
    return triad
end
local function jab(synth, patch, t, triad, durMs, step)
    for k, midi in ipairs(triad) do play(synth, 'keys', patch, t + (k - 1) * 0.006, midi, 3, durMs, step) end
end
-- the flute's run: the chord's notes running down from its highest at or under A5, quick, the last
-- one held up to the second stab (the record's flute, docs/MUSIC-ANALYSIS.md)
local function bookFluteRun(bar, s, chord)
    local song, t = bar.song, stepTime(bar.song, bar.t0, s)
    local notes = {}
    for _, midi in ipairs(jabTriad(song, chord)) do
        for _, n in ipairs({ midi, midi + 12, midi - 12 }) do
            if n <= 81 and n >= 64 then notes[#notes + 1] = n end
        end
    end
    table.sort(notes, function(a, b) return a > b end)
    local last = math.min(#notes, 4)
    for k = 1, last do
        local dur = k == last and lengthMs(song, s, 5) - (k - 1) * 70 or 90
        play(bar.synth, 'lead', bar.style.flute, t + (k - 1) * 0.07, notes[k], k == 1 and 4 or 3, dur, s)
    end
end
local function bookJabs(bar)
    local synth, song, style, t0, section, j = bar.synth, bar.song, bar.style, bar.t0, bar.section, bar.j
    local patch = style.pickPatch
    if j == 0 and style.pedals and style.pedals[section.kind] then
        pedal(t0, patch, style.pedals[section.kind])
        pedal(t0, style.flute, style.pedals[section.kind])
    end
    -- the flute now and then, in a phrase's second bar after the bass's beat 3 (the melody switch is its)
    local runOdds = section.kind == 'B' and 70 or section.kind == 'A' and 40 or 0
    if state.musicSettings.melody ~= false and j % 4 == 1 and bar.rnd(100) < runOdds then
        bookFluteRun(bar, 9, chordAtStep(song, bar.b, 9))
    end
    for _, s in ipairs({ 0, 8 }) do
        local chord = chordAtStep(song, bar.b, s)
        local root = 36 + (song.key + chord.degree) % 12
        play(synth, 'bass', style.bassPatch, stepTime(song, t0, s) + humanize(0.004), root, 4,
             lengthMs(song, s, 7), s)
    end
    if j == section.bars - 1 and section.kind ~= 'intro' then
        local low = guitarStrings(song, bar.chords[1])[1]
        if low then play(synth, 'keys', patch, t0 + 0.01, low, 4, 3200, 0) end
        return
    end
    local fill = j % 4 == 3 and section.kind ~= 'intro'
    for _, s in ipairs(section.kind == 'intro' and { 14 } or fill and { 6, 10, 12, 14 } or { 6, 14 }) do
        jab(synth, patch, stepTime(song, t0, s) + humanize(0.004), jabTriad(song, chordAtStep(song, bar.b, s)),
            s > 6 and fill and 140 or 110, s)
    end
end

lib.bandPlays = bandPlays
lib.notify = notify
lib.play = play
lib.bookLoopBar = bookLoopBar
lib.bassLines = bassLines
lib.drumKits = drumKits
lib.lofiGrids = lofiGrids
lib.LANE_VEL = LANE_VEL
lib.HAT_ACCENT = HAT_ACCENT
lib.lofiGroove = lofiGroove
lib.lofiBass = lofiBass
lib.bookTone = bookTone
lib.remember = remember
lib.bookSatieBar = bookSatieBar
lib.bookAmbientBar = bookAmbientBar
lib.applyLift = applyLift
lib.keysHits = keysHits
lib.bookKeys = bookKeys
lib.bookVinyl = bookVinyl
lib.bookBass = bookBass
lib.bookRiff = bookRiff
lib.LOFI_LANES = LOFI_LANES
lib.bookDrums = bookDrums
lib.keysVoicing = keysVoicing
lib.bookHorns = bookHorns
lib.bookGuitar = bookGuitar
lib.bookStrings = bookStrings
lib.bookTune = bookTune
lib.LOOP_BARS = LOOP_BARS
lib.bookTravis = bookTravis
lib.bookJabs = bookJabs

return lib
