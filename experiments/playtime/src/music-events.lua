-- music-events.lua: the world and the music telling each other things (docs/WORLD-AND-MUSIC.md).
--
-- World -> music (MW1): music.event(name, opts) says something happened ('impact' with opts.strength
-- 0..1, ...). The event waits for the next frame's update, then the style playing answers it (an
-- answerer a style registers with lib.answer, e.g. the drum jam's crash), at its own decision point:
-- ctx.beatAt is the next beat on the music's clock, far enough ahead to be booked.
--
-- Music -> world (MW2): music.on(name, what, fn, ahead) hears the music's MOMENTS: 'bar', 'beat',
-- 'chord' (data.pcs, the jam adds root and kind), 'phrase', 'drop', 'kick'. fn(data, at, now) is called
-- when the audio clock reaches `at`, or `ahead` seconds before it. Moments are known when their bar
-- is booked (music.lookahead, 0.3 s, before it starts) except the jam's chord changes and drops,
-- which it knows a bar early (DRUM-JAM J9a): ahead can be up to a bar for those. fn = nil removes it.
-- Keyed by name (state survives a hot reload; call again to replace).
local state = require('src.state')

local lib = {}

local function M()
    state.music = state.music or { activity = 0 }
    local m = state.music
    m.events = m.events or {}
    m.moments = m.moments or {}
    m.momentListeners = m.momentListeners or {}
    return m
end

-- The panel's settings: state.musicSettings.world = { impact = ... } (src/music-params.lua).
function lib.setting(key, default)
    local w = state.musicSettings and state.musicSettings.world
    return w and w[key] or default
end
lib.IMPACT_PICKS = { 'crash and fill', 'crash', 'off' }

-- The first beat at or after t + margin, on a grid of `beat` seconds through barStart.
function lib.nextBeat(barStart, beat, t, margin)
    local k = math.ceil((t + (margin or 0) - barStart) / beat - 1e-9)
    return barStart + k * beat
end

-- World -> music --------------------------------------------------------------------------------------
local answerers = {} -- by a style's loop ('jam') or its name: fn(name, opts, ctx)
function lib.answer(key, fn) answerers[key] = fn end

function lib.event(name, opts)
    local m = M()
    -- the tally: how often each moment happens while playing (docs/STINGERS.md), on state so a reload keeps it
    m.eventLog = m.eventLog or {}
    local log = m.eventLog[name] or { count = 0 }
    log.count, log.last = log.count + 1, love and love.timer and love.timer.getTime() or 0
    m.eventLog[name] = log
    if #m.events < 16 then m.events[#m.events + 1] = { name = name, opts = opts or {} } end
end

-- Music -> world --------------------------------------------------------------------------------------
function lib.on(name, what, fn, ahead)
    M().momentListeners[name] = fn and { what = what, fn = fn, ahead = ahead or 0 } or nil
end

function lib.moment(what, at, data)
    local m = M()
    if not next(m.momentListeners) then return end -- nobody listening: keep nothing
    m.moments[#m.moments + 1] = { what = what, at = at, data = data or {}, fired = {} }
end

-- A bar was booked (src/music.lua's bookBar): its bar and beats as moments, and for styles that don't
-- tell their own chords (all but the jam), a 'chord' moment where the booked chord changes.
function lib.barBooked(t0, song, style)
    local m = M()
    lib.moment('bar', t0, { bar = song.bar })
    for k = 0, 3 do lib.moment('beat', t0 + k * song.beat, { beat = k + 1, bar = song.bar }) end
    if style and style.loop == 'jam' then return end
    for _, booked in ipairs(m.booked or {}) do
        if booked.at >= t0 - 1e-6 and booked.at > (m.chordAt or -1) then
            m.chordAt = booked.at
            local same = m.chordPcs and #m.chordPcs == #booked.pcs
            if same then for i, pc in ipairs(booked.pcs) do same = same and m.chordPcs[i] == pc end end
            if not same then
                m.chordPcs = booked.pcs
                lib.moment('chord', booked.at, { pcs = booked.pcs })
            end
        end
    end
end

-- The band's instruments for the world (MW7), the latest first, in this order:
--   1. the instrument picked for the part in the music panel (state.musicSettings.voices), even with the
--      part switched off (Nikki: "I picked another bass sound but disabled the bass: I still want it for
--      the ball");
--   2. what the part has played in the last `within` seconds (state.music.heard);
--   3. the song's own instrument for it (state.music.styleParts / styleSounds, kept while a part is off).
-- {} when there's none of those. Impacts borrow them (src/mipo-voice.lua: the ball plays the song's bass,
-- boxes its percussion). For drums: every sound, with the panel's sound swaps (soundVoices).
function lib.bandInstruments(part, within)
    local m = M()
    local settings = state.musicSettings or {}
    local pick = settings.voices and settings.voices[part]
    if pick then return { pick } end
    local now, out = m.audioTime or 0, {}
    for patch, runs in pairs(m.heard and m.heard[part] or {}) do
        local last = runs[#runs]
        if last and last.to >= now - (within or 4) and last.from <= now + 1 then
            out[#out + 1] = { patch = patch, to = last.to }
        end
    end
    table.sort(out, function(a, b) if a.to ~= b.to then return a.to > b.to end return a.patch < b.patch end)
    for i, o in ipairs(out) do out[i] = o.patch end
    if #out > 0 then return out end
    local style = m.song and m.song.style
    if not style then return out end
    local own = m.styleParts and m.styleParts[style] and m.styleParts[style][part]
    if own then return { own } end
    local sounds = m.styleSounds and m.styleSounds[style] and m.styleSounds[style][part]
    for patch in pairs(sounds or {}) do
        out[#out + 1] = settings.soundVoices and settings.soundVoices[patch] or patch
    end
    table.sort(out)
    return out
end
-- which impacts borrow the band: state.musicSettings.world.band = { ball = 'band' | 'own', ... }
lib.BAND_DEFAULTS = { ball = 'band', box = 'band', plonk = 'own' }
function lib.borrows(kind)
    local w = state.musicSettings and state.musicSettings.world
    local v = w and w.band and w.band[kind] or lib.BAND_DEFAULTS[kind]
    return v == 'band'
end

-- Every note the music books (an onNote listener): a kick drum is a moment.
local function heard(part, patch, _, _, _, t)
    if part == 'drums' and type(patch) == 'string' and patch:lower():find('kick') then lib.moment('kick', t) end
end

-- Each frame, from music.update: answer the events, fire the moments the clock has reached.
-- play = music-parts' play (every note through it: mutes, the panel).
function lib.update(synth, t, song, style, play)
    local m = M()
    m.listeners = m.listeners or {}
    m.listeners['music-events'] = heard
    local events = m.events
    m.events = {}
    if song and song.beat and m.barStart then
        local answer = answerers[style and style.loop or ''] or answerers[song.style]
        for _, e in ipairs(events) do
            if answer then
                local ctx = { synth = synth, play = play, song = song, style = style, now = t,
                              beat = song.beat, beatAt = lib.nextBeat(m.barStart, song.beat, t, 0.06) }
                local ok, err = pcall(answer, e.name, e.opts, ctx)
                if not ok then print('[music-events] ' .. e.name .. ': ' .. tostring(err)) end
            end
        end
    end
    lib.fire(t)
end

function lib.fire(t)
    local m = M()
    local keep = {}
    for _, mo in ipairs(m.moments) do
        for name, l in pairs(m.momentListeners) do
            if l.what == mo.what and not mo.fired[name] and t >= mo.at - l.ahead then
                mo.fired[name] = true
                local ok, err = pcall(l.fn, mo.data, mo.at, t)
                if not ok then
                    m.momentListeners[name] = nil
                    print('[music-events] on ' .. name .. ': ' .. tostring(err))
                end
            end
        end
        if mo.at > t - 0.25 then keep[#keep + 1] = mo end
    end
    m.moments = keep
end

return lib
