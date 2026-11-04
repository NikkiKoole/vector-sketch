-- choir: three Mipos sing public-domain songs (rounds, unison, solo), in mipomi syllables, from Theo's, Herman's and Nikki's recordings
-- Each syllable's own pitch is measured (claudetools/voice-pitch.py -> src/voice-pitch-data.lua), so a
-- note plays its sample at 2^((note - measured) / 12): tuned per syllable, not per speaker. A sample
-- starts early by its consonant, so the vowel lands on the beat. Loudness is evened out per file.
-- Frère Jacques after the Dutch 'Vader Jacob': fa-do ja-ko / sa ji no / la-lo ko-ki lo-di / bi ba bo.
-- Also Twinkle Twinkle (solo), Ode to Joy (all together) and Row Your Boat (a round). Public domain only.
--
-- keys: space sing / stop   n next tune   m round / mixed (every note another voice) / solo (one voice)
--       v the solo voice (theo / herman / nikki)   t tuning (syllable / speaker / raw)
--       r swap rough takes for another speaker's (not in a solo)   u feel: off / jitter / singer   h the panels
--       1-5 the singer's layers: time, force, pitch, breath, tire   w voice: speed change / WORLD baked
--
-- WORLD baked (docs/CHOIR.md; make them with claudetools/voice-bake.py): each syllable re-tuned in advance
-- to a pitch every 3 semitones by the WORLD vocoder (throat and length kept); a note plays the nearest and
-- the rest by playback rate. Without the bake the switch stays on speed change.
--
-- Feel 'jitter': each voice its own lag and slow pitch drift, each note a little timing jitter, detune,
-- loudness, sometimes a scoop, vibrato on the long ones. Feel 'singer' (the strumhand way: a model of the
-- singer, state that carries from note to note, not dice per note): a lungful of BREATH that empties as
-- they sing (loud high notes cost more) and refills at rests and phrase ends (no rest: they snatch one and
-- come in late; the Mipo heaves); low on breath they go quieter, flat, the vibrato thin and fast. The
-- PHRASE: they push towards its highest note (louder, a little sharp, ahead) and slow into its last. A
-- LEAP up gets a bigger scoop and lands late. TIRING builds over the song: later rounds sag flat, drag and
-- scoop lazier; rests give a little back. Each Mipo has a personality (push, steady, lean, lung).
-- Scoop and vibrato ride the source's pitch every frame. Vowel: LÖVE's equalizer on an effect send, its two mid
-- bands at the vowel's first two formants (u o a e i), the dry path turned down by `amount`: a 2-band
-- talkbox on the recordings. `wobble` sweeps the vowel (a wah).

local s = {}

local DATA = love.filesystem.load('src/voice-pitch-data.lua')()
local SPEAKERS = { 'theo', 'herman', 'nikki' }
local OCTAVE = { theo = 0, herman = -12, nikki = -12 } -- each sings near their own middle
local FLOOR_Y = 260

-- Tunes in C: notes are { midi, beats, syllable } (syllable false = a rest). `canon` = beats between
-- the voices' entries (8: Frère Jacques' round; 0: all together, an octave apart).
local C4, D4, E4, F4, G4, A4, C5, G3 = 60, 62, 64, 65, 67, 69, 72, 55
local T3 = 1 / 3 -- an eighth in 6/8, where a beat is a dotted quarter
local function tune(t)
    t.notes = {}
    for _, ph in ipairs(t) do
        local lo, hi = 999, 0
        for _, n in ipairs(ph) do if n[3] then lo, hi = math.min(lo, n[1]), math.max(hi, n[1]) end end
        for _ = 1, ph.times or 1 do
            for i, n in ipairs(ph) do
                t.notes[#t.notes + 1] = { n[1], n[2], n[3], first = i == 1, last = i == #ph, lo = lo, hi = hi }
            end
        end
    end
    return t
end
local TUNES = {
    tune({ name = 'frere jacques', canon = 8, tempo = 96, mode = 'round',
        { times = 2, { C4, 1, 'fa' }, { D4, 1, 'do' }, { E4, 1, 'ja' }, { C4, 1, 'ko' } },
        { times = 2, { E4, 1, 'sa' }, { F4, 1, 'ji' }, { G4, 2, 'no' } },
        { times = 2, { G4, .5, 'la' }, { A4, .5, 'lo' }, { G4, .5, 'ko' }, { F4, .5, 'ki' }, { E4, 1, 'lo' }, { C4, 1, 'di' } },
        { times = 2, { C4, 1, 'bi' }, { G3, 1, 'ba' }, { C4, 2, 'bo' } },
    }),
    tune({ name = 'twinkle twinkle', canon = 0, tempo = 100, mode = 'solo',
        { { C4, 1, 'ti' }, { C4, 1, 'ki' }, { G4, 1, 'ti' }, { G4, 1, 'ki' }, { A4, 1, 'li' }, { A4, 1, 'ta' }, { G4, 2, 'so' } },
        { { F4, 1, 'ha' }, { F4, 1, 'wi' }, { E4, 1, 'wo' }, { E4, 1, 'da' }, { D4, 1, 'wa' }, { D4, 1, 'ji' }, { C4, 2, 'na' } },
        { times = 2, { G4, 1, 'la' }, { G4, 1, 'bo' }, { F4, 1, 'do' }, { F4, 1, 'wa' }, { E4, 1, 'lo' }, { E4, 1, 'so' },
            { D4, 2, 'hi' } },
        { { C4, 1, 'ti' }, { C4, 1, 'ki' }, { G4, 1, 'ti' }, { G4, 1, 'ki' }, { A4, 1, 'li' }, { A4, 1, 'ta' }, { G4, 2, 'so' } },
        { { F4, 1, 'ha' }, { F4, 1, 'wi' }, { E4, 1, 'wo' }, { E4, 1, 'da' }, { D4, 1, 'wa' }, { D4, 1, 'ji' }, { C4, 2, 'na' } },
    }),
    -- all three together, an octave apart (canon 0 in 'round' mode)
    tune({ name = 'ode to joy', canon = 0, tempo = 110, mode = 'round',
        { times = 2, { E4, 1, 'fo' }, { E4, 1, 'da' }, { F4, 1, 'so' }, { G4, 1, 'no' }, { G4, 1, 'ko' }, { F4, 1, 'ta' },
            { E4, 1, 'fo' }, { D4, 1, 'ki' }, { C4, 1, 'to' }, { C4, 1, 'ta' }, { D4, 1, 'wa' }, { E4, 1, 'li' },
            { E4, 1.5, 'si' }, { D4, .5, 'wo' }, { D4, 2, 'mo' } },
    }),
    -- 6/8, so a beat here is a dotted quarter and the eighths are thirds; a round, each voice two bars later
    tune({ name = 'row your boat', canon = 4, tempo = 66, mode = 'round',
        { { C4, 1, 'po' }, { C4, 1, 'po' }, { C4, 2 * T3, 'po' }, { D4, T3, 'ji' }, { E4, 1, 'bo' },
            { E4, 2 * T3, 'ji' }, { D4, T3, 'li' }, { E4, 2 * T3, 'da' }, { F4, T3, 'da' }, { G4, 2, 'so' },
            { C5, T3, 'mi' }, { C5, T3, 'li' }, { C5, T3, 'li' }, { G4, T3, 'mi' }, { G4, T3, 'li' }, { G4, T3, 'li' },
            { E4, T3, 'mi' }, { E4, T3, 'li' }, { E4, T3, 'li' }, { C4, T3, 'mi' }, { C4, T3, 'li' }, { C4, T3, 'li' },
            { G4, 2 * T3, 'la' }, { F4, T3, 'wi' }, { E4, 2 * T3, 'ba' }, { D4, T3, 'wa' }, { C4, 2, 'di' } },
    }),
}

local function median(list)
    table.sort(list)
    return list[math.floor((#list + 1) / 2)] or 60
end
local SPEAKER_MIDI = {}
for _, sp in ipairs(SPEAKERS) do
    local ms = {}
    for _, r in pairs(DATA[sp]) do if r.midi and not r.rough then ms[#ms + 1] = r.midi end end
    SPEAKER_MIDI[sp] = median(ms)
end

-- humanize: timing ms, detune cents, scoop cents, vibrato cents, dynamics dB
local HUMAN = { timing = 18, detune = 12, scoop = 40, vibrato = 22, dynamics = 3 }
-- the singers (guesses, to tune by ear): push 0..1 (how hard they go for the high notes), steady 0..1
-- (how little their timing and pitch wander), lean ms (+ behind the beat), lung beats (of singing per breath)
local PERSONALITY = {
    theo = { push = 0.8, steady = 0.3, lean = -12, lung = 7 },   -- the kid: pushes, rushes, short of breath
    herman = { push = 0.4, steady = 0.8, lean = 10, lung = 10 }, -- steady, sits back
    nikki = { push = 0.6, steady = 0.5, lean = 3, lung = 8 },
}
local LAYERS = { 'time', 'force', 'pitch', 'breath', 'tire' }
-- vowel filter: amount 0..1 (0 off), vowel 0..4 along u o a e i, wobble Hz, width 0..1 (band width)
local VOWEL = { amount = 0, vowel = 2, wobble = 0, width = 0.4 }
-- F1, F2 per vowel (Hz; the EQ's upper band can't go under 1000)
local VOWELS = { { 'u', 320, 1000 }, { 'o', 480, 1000 }, { 'a', 750, 1200 }, { 'e', 500, 1850 }, { 'i', 290, 2250 } }

local function filled(t, defaults)
    for k, v in pairs(defaults) do if t[k] == nil then t[k] = v end end
    return t
end

local function choir()
    state.choir = state.choir or {
        tune = 1, tempo = 96, transpose = 0, rounds = 2, tuning = 'syllable', mode = 'round', solo = 1,
        swapRough = true,
        showPanel = true, mipos = {}, statics = {}, playing = false,
    }
    local c = state.choir
    c.human = filled(c.human or {}, HUMAN) -- fields added later default here (a hot swap keeps the old table)
    c.vowelFx = filled(c.vowelFx or {}, VOWEL)
    if c.feel == nil then c.feel = 'singer' end
    c.humanity = c.humanity or 1
    c.layers = c.layers or { time = true, force = true, pitch = true, breath = true, tire = true }
    c.voiceState = c.voiceState or {}
    c.active = c.active or {}
    return c
end

---------------------------------------------------------------- sounds

-- WORLD re-tuned takes (claudetools/voice-bake.py; generated, not in git): nil when not baked yet
local okBaked, BAKED = pcall(function() return love.filesystem.load('assets/voices-baked/index.lua')() end)
if not okBaked then BAKED = nil end

local sources, gains = {}, {}
-- a take by its path, loaded once; peak = its loudest sample (to even out loudness)
local function source(path, peak)
    if sources[path] == nil then
        if not love.filesystem.getInfo(path) then sources[path] = false return false end
        gains[path] = math.min(0.35 / math.max(peak or 0.35, 0.001), 3)
        sources[path] = love.audio.newSource(path, 'static')
    end
    return sources[path]
end

-- which recording sings this note, at what playback rate, how early to start it
local function take(c, sp, syl, midi)
    local r = DATA[sp] and DATA[sp][syl]
    local octave = OCTAVE[sp] -- a swapped take still sings in this voice's octave
    -- a solo keeps the soloist's own takes (one voice), rough or not; only a missing one is swapped
    if (c.swapRough and c.mode ~= 'solo' and r and r.rough) or not (r and r.midi) then
        local best -- the clean take that needs the smallest shift (less chipmunk, less slow-mo)
        for _, other in ipairs(SPEAKERS) do
            local o = DATA[other][syl]
            if o and o.midi and not o.rough then
                local shift = math.abs(midi + octave - o.midi)
                if not best or shift < best then best, sp, r = shift, other, o end
            end
        end
    end
    if not r then return nil end
    local target = midi + octave + c.transpose
    local baked = c.baked and BAKED and BAKED[sp] and BAKED[sp][syl]
    if baked then
        -- the nearest WORLD-tuned take; the rest (<= 1.5 st) by playback rate, too little to chipmunk
        local best
        for g in pairs(baked.pitches) do
            if not best or math.abs(g - target) < math.abs(best - target) then best = g end
        end
        local path = 'assets/voices-baked/' .. sp .. '/' .. syl .. '/' .. best .. '.ogg'
        if source(path, baked.pitches[best]) then
            local rate = 2 ^ ((target - best) / 12)
            return { sp = sp, syl = syl, rate = rate, lead = (baked.start or 0) / rate, key = path }
        end
    end
    local path = 'assets/voices/' .. sp .. '/' .. syl .. '.ogg'
    if not source(path, r.peak) then return nil end
    local from = (c.tuning == 'syllable' and r.midi) or (c.tuning == 'speaker' and SPEAKER_MIDI[sp]) or target
    local rate = 2 ^ ((target - from) / 12)
    return { sp = sp, syl = syl, rate = rate, lead = (r.start or 0) / rate, key = path }
end

---------------------------------------------------------------- the score

local rnd = love.math.random
local function jitter() return rnd() + rnd() + rnd() - 1.5 end -- about normal, sd 0.5

-- feel 'jitter': dice per note (and a lag and drift per voice)
local function jitterFeel(c, tk, t, v)
    local h = c.human
    v.lag = v.lag or (rnd() * 2 - 1) * h.timing / 2000
    v.drift = math.max(-h.detune, math.min(h.detune, (v.drift or 0) + jitter() * h.detune / 3))
    tk.at = tk.at + v.lag + jitter() * h.timing / 1000
    tk.cents = v.drift + jitter() * h.detune
    tk.scoop = rnd() < 0.5 and h.scoop * (0.5 + rnd() * 0.5) or 0
    tk.vibrato = tk.dur > 0.35 and h.vibrato * (0.7 + rnd() * 0.6) or 0
    tk.vibRate = 5 + rnd() * 1.5
    local accent = (t % 4 == 0) and h.dynamics / 2 or 0
    tk.gain = 10 ^ ((jitter() * h.dynamics + accent - h.dynamics / 2) / 20)
end

-- feel 'singer': the singer's state (v) carries from note to note
local function singerFeel(c, tk, n, t, v, P)
    local H, L = c.humanity, c.layers
    local breath = L.breath and v.breath or 1
    local tired = L.tire and v.tired or 0
    local short = (1 - breath) ^ 2
    local contour = n.hi > n.lo and (n[1] - n.lo) / (n.hi - n.lo) or 0.5
    local leap = v.prevMidi and (n[1] - v.prevMidi) or 0
    v.feelMs = v.feelMs * 0.85 + jitter() * 8 * (1 - P.steady) -- the timing feel wanders, and comes back
    v.drift = v.drift * 0.9 + jitter() * 5 * (1 - P.steady)
    if L.time then
        local ms = P.lean + v.feelMs - P.push * 15 * contour + (n.last and 35 or 0)
            + (v.late or 0) + math.max(0, leap - 4) * 3 + tired * 30
        tk.at = tk.at + ms * H / 1000
    end
    local db = 0
    if L.force then db = db + P.push * 4 * contour + ((t % 4 == 0) and 1.5 or 0) - (n.last and 1.5 or 0) end
    db = db - 8 * short - 3 * tired
    tk.gain = 10 ^ (db * H / 20)
    local cents = -25 * short - 18 * tired
    if L.pitch then cents = cents + v.drift + P.push * 8 * contour end
    tk.cents = cents * H
    if L.pitch then
        tk.scoop = ((leap > 0 and math.min(120, leap * 10) * (0.6 + 0.4 * P.push) or 8) + tired * 30) * H
        tk.vibrato = tk.dur > 0.35 and 25 * (0.4 + 0.6 * breath) * (n.last and 1.3 or 1) * H or 0
        tk.vibRate = 5.6 - tired * 1.2 + short * 2
    else
        tk.scoop, tk.vibrato, tk.vibRate = 0, 0, 5
    end
    tk.breath, tk.tired = v.breath, v.tired
    -- singing costs breath (loud high notes more) and tires the voice
    v.breath = math.max(0.05, v.breath - n[2] / P.lung * (1 + 0.5 * contour * P.push))
    v.tired = math.min(1, v.tired + n[2] / (P.lung * 12))
    v.prevMidi, v.late = n[1], 0
end

local function buildEvents(c)
    local beat = 60 / c.tempo
    local events = {}
    local voices = c.mode == 'round' and 3 or 1
    local song = TUNES[c.tune]
    for vi = 1, voices do
        local t = (vi - 1) * song.canon -- a round: each voice comes in later
        local sp0 = (c.mode == 'round' and SPEAKERS[vi]) or (c.mode == 'solo' and SPEAKERS[c.solo]) or nil
        local P = PERSONALITY[sp0 or 'nikki']
        local v = { breath = 1, tired = 0, feelMs = 0, drift = 0 }
        local voiceIx = c.mode == 'round' and vi or (sp0 and c.solo)
        for _ = 1, c.rounds do
            for _, n in ipairs(song.notes) do
                if not n[3] then
                    -- a rest: a full breath (when there's time for one), and a little rest for the voice
                    if n[2] >= 0.5 and v.breath < 0.95 then
                        v.breath = 1
                        events[#events + 1] = { kind = 'breath', at = t * beat, voice = voiceIx }
                    end
                    v.tired = math.max(0, v.tired - 0.02 * n[2])
                else
                    if n.first and v.breath < 0.8 and c.feel == 'singer' and c.layers.breath then
                        -- a new phrase and no rest before it: they snatch a breath and come in a touch late
                        v.breath, v.late = 1, 35
                        events[#events + 1] = { kind = 'breath', at = t * beat - 0.15, voice = voiceIx }
                    end
                    local sp = sp0 or SPEAKERS[rnd(#SPEAKERS)]
                    local tk = take(c, sp, n[3], n[1])
                    if tk then
                        tk.at = t * beat - tk.lead
                        tk.dur = n[2] * beat
                        tk.voice = voiceIx or ({ theo = 1, herman = 2, nikki = 3 })[tk.sp]
                        if c.feel == 'jitter' then jitterFeel(c, tk, t, v)
                        elseif c.feel == 'singer' then singerFeel(c, tk, n, t, v, P) end
                        events[#events + 1] = tk
                    end
                end
                t = t + n[2]
            end
        end
    end
    table.sort(events, function(a, b) return a.at < b.at end)
    return events
end

local function start(c)
    c.events = buildEvents(c)
    c.next = 1
    local first = c.events[1] and c.events[1].at or 0
    c.t0 = love.timer.getTime() - math.min(first, 0) + 0.1
    c.playing = true
end

---------------------------------------------------------------- the vowel filter

local effectsOk = nil
local function effects()
    if effectsOk == nil then
        local ok, yes = pcall(love.audio.isEffectsSupported)
        effectsOk = ok and yes or false
    end
    return effectsOk
end

local function vowelFormants(pos)
    pos = math.max(0, math.min(#VOWELS - 1, pos))
    local i = math.min(math.floor(pos), #VOWELS - 2)
    local f, a, b = pos - i, VOWELS[i + 1], VOWELS[i + 2]
    return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

local function vowelName(pos)
    return VOWELS[math.floor(math.max(0, math.min(#VOWELS - 1, pos)) + 0.5) + 1][1]
end

-- the EQ follows the vowel (and its wobble) every frame; sources only join it at their start
local function updateVowel(c, now)
    local fx = c.vowelFx
    if fx.amount <= 0 or not effects() then return end
    local pos = fx.vowel + (fx.wobble > 0 and math.sin(now * fx.wobble * 2 * math.pi) * 1.5 or 0)
    local f1, f2 = vowelFormants(pos)
    local boost = 1 + fx.amount * 6.9  -- up to +18 dB on the formants
    local cut = 1 - fx.amount * 0.87   -- down to -18 dB around them
    local width = 0.05 + fx.width * 0.95
    love.audio.setEffect('choirVowel', {
        type = 'equalizer',
        lowgain = cut, lowcut = 200,
        lowmidgain = boost, lowmidfrequency = math.max(200, math.min(3000, f1)), lowmidbandwidth = width,
        highmidgain = boost, highmidfrequency = math.max(1000, math.min(8000, f2)), highmidbandwidth = width,
        highgain = cut, highcut = 4000,
    })
end

local function sendThroughVowel(c, src)
    local fx = c.vowelFx
    if fx.amount <= 0 or not effects() then return end
    src:setFilter({ type = 'lowpass', volume = 1 - fx.amount, highgain = 1 }) -- the dry path, turned down
    pcall(src.setEffect, src, 'choirVowel')
end

---------------------------------------------------------------- the stage

local function aliveMipos(c)
    local out = {}
    for i, inst in pairs(c.mipos) do
        local torso = inst.parts and inst.parts.torso1
        if torso and torso.body and not torso.body:isDestroyed() then out[i] = inst end
    end
    return out
end

local function buildStage(c)
    for _, st in ipairs(c.statics) do
        if st.body and not st.body:isDestroyed() then return end
    end
    c.statics = {}
    local floor = objectManager.addThing('rectangle', { x = 0, y = FLOOR_Y + 20, width = 3000, height = 40,
        bodyType = 'static', label = 'choir-floor' })
    if floor then c.statics[1] = { body = floor.body } end
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local c = choir()
    if c.baked == nil then c.baked = BAKED ~= nil end -- the WORLD voices when they're baked
    buildStage(c)
    c.mipos = aliveMipos(c)
    for i = 1, 3 do
        if not c.mipos[i] then
            local inst = characterManager.createCharacter('humanoid', (i - 2) * 450, FLOOR_Y - 300, 0.3)
            if inst then characterManager.randomizeMipoConstrained(inst) c.mipos[i] = inst end
        end
    end
    c.playing = false
end

-- scoop up into the note over its first 80 ms (from the vowel on), vibrato fading in after 120 ms
local function bend(a, t)
    local el = t - a.vowelAt
    local cents = a.cents
    if el < 0.08 then cents = cents - a.scoop * (1 - math.max(0, el) / 0.08) end
    if el > 0.12 and a.vibrato > 0 then
        cents = cents + a.vibrato * math.sin((el - 0.12) * a.vibRate * 2 * math.pi) * math.min(1, (el - 0.12) / 0.15)
    end
    return a.rate * 2 ^ (cents / 1200)
end

function s.update()
    local c = state.choir
    if not c then return end
    choir()
    local clock = love.timer.getTime()
    updateVowel(c, clock)
    for i = #c.active, 1, -1 do
        local a = c.active[i]
        if a.src:isPlaying() then a.src:setPitch(bend(a, clock)) else table.remove(c.active, i) end
    end
    if not c.playing then return end
    local now = clock - c.t0
    while c.next <= #c.events and c.events[c.next].at <= now do
        local e = c.events[c.next]
        c.next = c.next + 1
        local inst = e.voice and c.mipos[e.voice]
        if e.kind == 'breath' then
            if inst then mipoActions.breathe(inst) end -- the Mipo heaves: a breath in
            if e.voice then c.voiceState[e.voice] = { breath = 1, tired = (c.voiceState[e.voice] or {}).tired or 0 } end
        else
            if e.voice and e.breath then c.voiceState[e.voice] = { breath = e.breath, tired = e.tired } end
            local src = sources[e.key]:clone()
            local a = { src = src, rate = e.rate, cents = e.cents or 0, scoop = e.scoop or 0, vibrato = e.vibrato or 0,
                vibRate = e.vibRate or 5, vowelAt = clock + e.lead }
            src:setPitch(bend(a, clock))
            src:setVolume(gains[e.key] * 0.8 * (e.gain or 1))
            sendThroughVowel(c, src)
            src:play()
            c.active[#c.active + 1] = a
            if inst then mipoVoice.flapMouth(inst, math.min(e.dur, src:getDuration() / e.rate)) end
        end
    end
    if c.next > #c.events then c.playing = false end
end

-- for the bridge (works in the editor too): script.call('sing') / script.call('hush')
function s.sing() start(choir()) end
function s.hush() choir().playing = false end

function s.onKeyPress(k)
    if not state.playMode then return end
    local c = choir()
    if k == 'space' then if c.playing then c.playing = false else start(c) end
    elseif k == 't' then c.tuning = ({ syllable = 'speaker', speaker = 'raw', raw = 'syllable' })[c.tuning]
    elseif k == 'm' then c.mode = ({ round = 'mixed', mixed = 'solo', solo = 'round' })[c.mode]
    elseif k == 'v' then c.solo = c.solo % #SPEAKERS + 1
    elseif k == 'r' then c.swapRough = not c.swapRough
    elseif k == 'h' then c.showPanel = not c.showPanel
    elseif k == 'w' then c.baked = not c.baked
    elseif k == 'u' then c.feel = ({ off = 'jitter', jitter = 'singer', singer = 'off' })[c.feel]
    elseif tonumber(k) and LAYERS[tonumber(k)] then
        local name = LAYERS[tonumber(k)]
        c.layers[name] = not c.layers[name]
    elseif k == 'n' then
        c.tune = c.tune % #TUNES + 1
        c.tempo = TUNES[c.tune].tempo
        c.mode = TUNES[c.tune].mode
        c.playing = false
    end
end

function s.drawUI()
    local c = state.choir
    if not (c and state.playMode and c.showPanel) then return end
    ui.startFrame()
    local BH, pad, w = 36, 8, 420
    local h = (BH + pad) * 8 + pad + 24
    local x0, y0 = 20, 20
    ui.panel(x0, y0, w, h, '•• choir ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 190, c.playing and 'stop' or 'sing') then
            if c.playing then c.playing = false else start(c) end
        end
        if ui.button(x + 200, y, 190, TUNES[c.tune].name) then s.onKeyPress('n') end
        for _, row in ipairs({ { 'tempo', 50, 200, 1 }, { 'transpose', -7, 7, 1 }, { 'rounds', 1, 4, 1 } }) do
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local v = ui.sliderWithInput('choir' .. row[1], x, y, 180, row[2], row[3], c[row[1]], nil, row[4])
            if v then c[row[1]] = math.floor(v + 0.5) end
            ui.label(x + 280, y, row[1])
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 190, 'tuning: ' .. c.tuning) then s.onKeyPress('t') end
        if ui.button(x + 200, y, 190, c.mode == 'solo' and ('solo: ' .. SPEAKERS[c.solo]) or c.mode) then
            s.onKeyPress(c.mode == 'solo' and 'v' or 'm')
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 190, c.swapRough and 'rough: swapped' or 'rough: kept') then s.onKeyPress('r') end
        if ui.button(x + 200, y, 190, 'mode: ' .. c.mode) then s.onKeyPress('m') end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 390, not BAKED and 'voice: speed (not baked: voice-bake.py)'
            or (c.baked and 'voice: WORLD baked' or 'voice: speed change')) then s.onKeyPress('w') end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'space n t m v r w u 1-5 h')
    end)

    -- the second panel: the feel (jitter's dice or the singer model) and the vowel filter
    local rows = {}
    if c.feel == 'jitter' then
        rows = { { c.human, 'timing', 0, 60, 1 }, { c.human, 'detune', 0, 50, 1 }, { c.human, 'scoop', 0, 150, 1 },
            { c.human, 'vibrato', 0, 80, 1 }, { c.human, 'dynamics', 0, 10, 0.5 } }
    elseif c.feel == 'singer' then
        rows = { { c, 'humanity', 0, 2, 0.05 } }
    end
    for _, row in ipairs({ { c.vowelFx, 'amount', 0, 1, 0.05 }, { c.vowelFx, 'vowel', 0, 4, 0.05 },
        { c.vowelFx, 'wobble', 0, 8, 0.1 }, { c.vowelFx, 'width', 0, 1, 0.05 } }) do rows[#rows + 1] = row end
    local extra = c.feel == 'singer' and 5 or 0 -- layer buttons (2 lines) + a line per singer
    local x1, h2 = x0 + w + 10, (BH + pad) * (#rows + 2 + extra) + pad + 24
    ui.panel(x1, y0, w, h2, '•• feel & vowel ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x1 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        if ui.button(x, y, 190, 'feel: ' .. c.feel) then s.onKeyPress('u') end
        if c.feel == 'singer' then
            for i, name in ipairs(LAYERS) do
                if i == 1 or i == 4 then x, y = ui.nextLayoutPosition(layout, w - 20, BH) end
                local col = (i <= 3) and (i - 1) or (i - 4)
                if ui.button(x + col * 130, y, 124, (c.layers[name] and '' or 'no ') .. name) then
                    s.onKeyPress(tostring(i))
                end
            end
            for vi, sp in ipairs(SPEAKERS) do
                x, y = ui.nextLayoutPosition(layout, w - 20, BH)
                local st = c.voiceState[vi]
                ui.label(x, y, st and string.format('%s  breath %3d%%  tired %3d%%', sp, st.breath * 100, st.tired * 100)
                    or (sp .. '  -'))
            end
        end
        for _, row in ipairs(rows) do
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            local t, key = row[1], row[2]
            local v = ui.sliderWithInput('choir' .. key, x, y, 180, row[3], row[4], t[key], nil, row[5])
            if v then t[key] = v + 0 end
            ui.label(x + 280, y, key .. (key == 'vowel' and (' ' .. vowelName(t.vowel)) or ''))
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, effects() and 'feel: from the next song' or 'no audio effects here')
    end)
end

return s
