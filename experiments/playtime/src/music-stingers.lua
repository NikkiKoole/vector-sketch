-- music-stingers.lua: a short phrase over the music when something happens (docs/STINGERS.md, S1).
--
-- The composed styles answer the world's events (src/music-events.lua) with a stinger on the next beat:
-- a few notes from the chord sounding then, so it's always in key (wave's key moves too). Like iMUSE's ~20
-- written variations per stinger, it doesn't repeat itself: the chord changes it, and a shape and a
-- rhythm come from a shuffled bag (no shape again until the others have played). At most one a bar, and
-- softer when they come thick.
--
-- The settings (Settings -> music, state.musicSettings.world, saved with setups):
--   stingerSize     'off' (default) / 'small' (3-4 notes in a beat or two) / 'big' (5 notes, a bar)
--   stingerVoice    'band' (the song's tune instrument, else its keys: MW7's way) / 'vibes' / 'kalimba'
--   stingerRest     'yes' (default): the part whose instrument the stinger borrows rests meanwhile.
--                   Its booked notes are taken back (synth.unschedule, dreamengine's unschedule) and
--                   notes booked later skip the window (music-parts' play, M.rest)
--   stingerMoments  'button' (only the panel's try button) / 'rare' / 'all'
-- The try button sends music.event('stinger'): it plays even with the size off (as small).
local state = require('src.state')
local events = require('src.music-events')
local D = require('src.music-styles')

local lib = {}

lib.MOMENTS = {
    rare = { snap = true, door = true, room = true, daze = true, signal = true },
    all = { snap = true, door = true, room = true, daze = true, signal = true, throw = true, jump = true,
            wake = true, grab = true, drop = true },
}
lib.SIZES = { 'off', 'small', 'big' }
lib.VOICES = { 'band', 'vibes', 'kalimba' }
lib.RESTS = { 'yes', 'no' }
lib.MOMENT_PICKS = { 'button', 'rare', 'all' }
lib.range = { 67, 86 }  -- where a stinger sits: over the comp, around the tune
lib.center = 76

-- shapes: steps up the chord's notes from a start near the centre; rhythms: 16ths from the beat. A
-- stinger is one of each, so a bag of 6 x 3 gives 18 before the chord even changes it
lib.SHAPES = {
    small = { { 0, 1, 2 }, { 0, 2, 1 }, { 1, 0, 2 }, { 0, 1, 3 }, { 2, 1, 3 }, { 0, 2, 3 } },
    big = { { 0, 1, 2, 3, 4 }, { 0, 2, 1, 3, 5 }, { 3, 2, 1, 2, 4 }, { 0, 1, 3, 2, 4 }, { 0, 2, 4, 3, 5 },
            { 2, 0, 1, 3, 4 } },
}
lib.RHYTHMS = {
    small = { { 0, 1, 2 }, { 0, 2, 4 }, { 0, 1, 4 } },
    big = { { 0, 2, 4, 6, 8 }, { 0, 1, 2, 4, 8 }, { 0, 2, 3, 4, 12 } },
}

local function setting(key, default) return events.setting(key, default) end

local function S()
    local m = state.music
    m.stingers = m.stingers or { bags = {}, recent = {} }
    return m.stingers
end

-- a shuffled bag of 1..n: each comes once before any comes again
local function fromBag(name, n)
    local s = S()
    local bag = s.bags[name]
    if not bag or #bag == 0 or bag.n ~= n then
        bag = { n = n }
        for i = 1, n do bag[i] = i end
        for i = n, 2, -1 do
            local j = love.math.random(i)
            bag[i], bag[j] = bag[j], bag[i]
        end
        s.bags[name] = bag
    end
    return table.remove(bag)
end

-- the chord booked for time t (music-parts' remember: the last few bars' chords)
local function chordAt(t)
    local found
    for _, booked in ipairs(state.music.booked or {}) do
        if booked.at <= t + 1e-6 then found = booked end
    end
    return found or (state.music.booked or {})[1]
end

-- the instrument and the part it belongs to: the band's tune, else its keys; or a fixed voice
local function voiceOf()
    local voice = setting('stingerVoice', 'band')
    if voice ~= 'band' then return voice, nil end
    for _, part in ipairs({ 'lead', 'keys' }) do
        local list = events.bandInstruments(part, 4)
        if list[1] then return list[1], part end
    end
    return 'vibes', nil
end

function lib.wants(name)
    if name == 'stinger' then return true end
    if setting('stingerSize', 'off') == 'off' then return false end
    local moments = lib.MOMENTS[setting('stingerMoments', 'button')]
    return moments and moments[name] or false
end

-- Plan a stinger at `at` (seconds on the audio clock): its notes { t, midi, vol, ms }, its end.
-- Pure apart from the bag's shuffle: the spec checks it.
function lib.plan(size, pcs, at, beat, recentCount)
    local inChord = {}
    for _, pc in ipairs(pcs) do inChord[pc % 12] = true end
    local ladder = {}
    for midi = lib.range[1], lib.range[2] do
        if inChord[midi % 12] then ladder[#ladder + 1] = midi end
    end
    if #ladder == 0 then return nil end
    local shapes, rhythms = lib.SHAPES[size], lib.RHYTHMS[size]
    local shape = shapes[fromBag(size .. 'shape', #shapes)]
    local rhythm = rhythms[fromBag(size .. 'rhythm', #rhythms)]
    local start = 1
    for i, midi in ipairs(ladder) do
        if math.abs(midi - lib.center) < math.abs(ladder[start] - lib.center) then start = i end
    end
    start = math.max(1, start - love.math.random(0, 1))
    local step = beat / 4
    local base = (size == 'big' and 5 or 4) - math.min(2, recentCount or 0)
    local lastLen = size == 'big' and math.max(4, 16 - rhythm[#rhythm]) or 4
    local notes = {}
    for k, s in ipairs(rhythm) do
        local i = math.max(1, math.min(#ladder, start + (shape[k] or shape[#shape])))
        local len = rhythm[k + 1] and rhythm[k + 1] - s or lastLen
        notes[k] = { t = at + s * step, midi = ladder[i], ms = len * step * 1000 * 0.95,
                     vol = base + (k == #rhythm and 1 or 0) - (k == 1 and 0 or 1) }
    end
    return notes, at + (rhythm[#rhythm] + lastLen) * step
end

local function answer(name, _, ctx)
    if not lib.wants(name) then return end
    local s, m, beat = S(), state.music, ctx.beat
    local at = ctx.beatAt
    if s.lastAt and at < s.lastAt + 4 * beat - 1e-6 then return end -- at most one a bar
    local chord = chordAt(at)
    if not chord then return end
    local size = setting('stingerSize', 'off')
    if size == 'off' then size = 'small' end -- the try button
    local recent = 0
    for _, t in ipairs(s.recent) do if t > ctx.now - 6 then recent = recent + 1 end end
    local notes, stop = lib.plan(size, chord.pcs, at, beat, recent)
    if not notes then return end
    local patch, part = voiceOf()
    if part and setting('stingerRest', 'yes') == 'yes' then
        -- the part rests: its booked notes in the window taken back first (FIFO: the stinger's own
        -- notes, booked after, stay), and bars booked later skip it (music-parts' play)
        local from, to = at - 0.02, stop + 0.05
        require('src.synth').unschedule(patch, from, to)
        m.rest = m.rest or {}
        m.rest[part] = { from = from, to = to }
    end
    for _, n in ipairs(notes) do
        ctx.play(ctx.synth, 'stinger', patch, n.t, n.midi, math.max(1, n.vol), n.ms)
    end
    s.lastAt = at
    s.recent[#s.recent + 1] = ctx.now
    while #s.recent > 8 do table.remove(s.recent, 1) end
end

-- every style but the jam (it answers the same moments in drums, with these switches: src/music-jam.lua)
function lib.register()
    for styleName, style in pairs(D.styles) do
        if style.loop ~= 'jam' then events.answer(styleName, answer) end
    end
end
lib.register()

return lib
