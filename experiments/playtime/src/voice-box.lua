-- voice-box.lua — a Mipo voice made from scratch, not recorded (docs/VOICEBOX.md, the voicebox spike):
-- dreamengine's formant voice (INSTR_VOICE: a glottal pulse through four vowel formants, navkit's VoicForm),
-- every knob it has, and the Mipo's mouth following what it says.
--   vowels  a point on the vowel chart (F1 = how open, F2 = how front), anywhere between the vowels:
--           the engine's AH formants scaled to that F1/F2 (its open/front levers, note_aux 8/9)
--   sound   size (the throat: giant -> tiny), effort (soft breathy -> bright pressed), nasal, buzz,
--           jitter / shimmer / creak (roughness), vibrato
--   speech  a consonant opens a syllable (voice_consonant, 22 of them: b d g m n l s sh ng r w y dh f v
--           z zh th p t k ch); babble: a phrase of mipomi syllables on one held note
-- The mouth: each vowel on the chart has a mouth shape, a point between them blends those by nearness;
-- a consonant shows its own shape for its moment; quiet, the Mipo's own mouth.
-- Synth: the 'voiceBox' patch in a shared pool slot (src/synth.lua lib.poolSlots), held notes.
-- Recorded takes beside it (VOICEBOX VB3): the voice lab's take (src/voice-lab.lua, state.voiceLab) played
-- bare, synth or sing, at this pitch when the take's pitch is measured (src/voice-pitch-data.lua), or the
-- same syllable made: A/B on one note.
local lib = {}

local state = require('src.state')
local synth = require('src.synth')
local mouthShapes = require('src.mouth-shapes')

local okFfi, ffi = pcall(require, 'ffi')
if okFfi then
    pcall(ffi.cdef, [[
void note_aux(int handle, int idx, float value);
void voice_consonant(int handle, int id);
void voice_coda(int handle, int id);
]])
end

synth.INSTR.VOICE = synth.INSTR.VOICE or 24
local PATCH = 'voiceBox'
local function ensurePatch()
    synth.INSTR.VOICE = synth.INSTR.VOICE or 24
    synth.patches[PATCH] = synth.patches[PATCH] or { pool = true, wave = 'VOICE', adsr = { 30, 60, 7, 160 },
        harmonics = 0.5, timbre = 0.33, morph = 0.5, reverb = 0.12, level = 0.9 }
end

-- the engine's raw params (note_aux idx), dreamengine runtime/sound.h sound_voice_sample
local VP = { vowel = 0, size = 1, breath = 2, openq = 3, tilt = 4, vibDepth = 5, vibRate = 6, nasal = 7,
    openF1 = 8, frontF2 = 9, buzz = 10, jitter = 11, shimmer = 12, creak = 13, nasalAF = 14, reduce = 15,
    measBW = 16, vow2 = 17, glide = 18 }
local BASE = { f1 = 520, f2 = 1190, row = 6 } -- AH "uh": the formants the chart point scales

-- the vowels on the chart, measured F1/F2 (the engine's own table), with the mouth each one gets
lib.VOWELS = {
    { name = 'i', f1 = 270, f2 = 2290, mouth = 'C_D_E_G_K_N_R_S' }, -- see
    { name = 'e', f1 = 530, f2 = 1840, mouth = 'A_I' },             -- bed
    { name = 'ae', f1 = 660, f2 = 1720, mouth = 'open_tween_happy' }, -- cat
    { name = 'a', f1 = 730, f2 = 1090, mouth = 'O_U_agh' },         -- father
    { name = 'uh', f1 = 520, f2 = 1190, mouth = 'open_tween' },     -- cup
    { name = 'er', f1 = 490, f2 = 1350, mouth = 'ugh' },            -- bird
    { name = 'o', f1 = 570, f2 = 840, mouth = 'L_OU' },             -- go
    { name = 'oo', f1 = 300, f2 = 870, mouth = 'O_U_W_Q' },         -- boot
}
lib.CHART = { f1min = 230, f1max = 800, f2min = 750, f2max = 2450 } -- the chart's edges

lib.CONSONANTS = { 'b', 'd', 'g', 'm', 'n', 'l', 's', 'sh', 'ng', 'r', 'w', 'y', 'dh', 'f', 'v', 'z', 'zh',
    'th', 'p', 't', 'k', 'ch' }
local CONSONANT_ID = {}
for i, name in ipairs(lib.CONSONANTS) do CONSONANT_ID[name] = i - 1 end
local CONSONANT_MOUTH = { m = 'M_B_P', b = 'M_B_P', p = 'M_B_P', f = 'F_V', v = 'F_V', th = 'TH_L', dh = 'TH_L',
    l = 'TH_L', w = 'O_U_W_Q', r = 'L_OU', sh = 'O_U_W_Q', zh = 'O_U_W_Q', ch = 'O_U_W_Q' }
local CONSONANT_FOR = 0.08 -- seconds its mouth shows
lib.MOUTH_CLOSE = 0.4 -- how far a close vowel (i, oo) opens the mouth, of the open ones' way

-- the presets: how a Mipo might sound (pitch in midi)
lib.PRESETS = {
    mipo  = { pitch = 64, size = 0.72, effort = 0.45, nasal = 0.15, buzz = 0.8, jitter = 0.15, shimmer = 0.1,
              creak = 0, vibDepth = 0.15, vibRate = 0.55 },
    tiny  = { pitch = 74, size = 0.95, effort = 0.4, nasal = 0.25, buzz = 0.6, jitter = 0.1, shimmer = 0.1,
              creak = 0, vibDepth = 0.25, vibRate = 0.8 },
    big   = { pitch = 45, size = 0.15, effort = 0.55, nasal = 0.1, buzz = 1, jitter = 0.2, shimmer = 0.15,
              creak = 0.2, vibDepth = 0.1, vibRate = 0.3 },
    hum   = { pitch = 55, size = 0.45, effort = 0.2, nasal = 0.85, buzz = 0.7, jitter = 0.05, shimmer = 0,
              creak = 0, vibDepth = 0.1, vibRate = 0.4 },
    plain = { pitch = 57, size = 0.33, effort = 0.5, nasal = 0, buzz = 1, jitter = 0, shimmer = 0,
              creak = 0, vibDepth = 0, vibRate = 0.5 },
}

local function S()
    if not state.voiceBox then
        state.voiceBox = { f1 = 730, f2 = 1090, onset = 'm', mouthOpen = 0 }
        for k, v in pairs(lib.PRESETS.mipo) do state.voiceBox[k] = v end
    end
    return state.voiceBox
end
lib.settings = S

local function C()
    if not okFfi then return nil end
    if not synth.start() then return nil end
    return state.synth and state.synth.C
end

local function clamp01(x) return math.max(0, math.min(1, x)) end
local function log2(x) return math.log(x) / math.log(2) end

-- the chart point as the engine's open/front levers (x2^((s - 0.5) * 3.4) on F1 / F2)
local function aux(C_, handle, idx, value) C_.note_aux(handle, idx, value) end
local function pushVowel(C_, handle, f1, f2)
    aux(C_, handle, VP.openF1, clamp01(0.5 + log2(f1 / BASE.f1) / 3.4))
    aux(C_, handle, VP.frontF2, clamp01(0.5 + log2(f2 / BASE.f2) / 3.4))
end

local function pushSound(C_, handle)
    local s = S()
    aux(C_, handle, VP.vow2, BASE.row / 9)
    aux(C_, handle, VP.glide, 1)
    aux(C_, handle, VP.size, s.size)
    -- effort as dreamengine's voxpad has it: breath, glottal open quotient and tilt together
    aux(C_, handle, VP.breath, 0.55 * (1 - s.effort))
    aux(C_, handle, VP.openq, 0.95 - 0.9 * s.effort)
    aux(C_, handle, VP.tilt, 0.8 * (1 - s.effort))
    aux(C_, handle, VP.nasal, s.nasal)
    aux(C_, handle, VP.buzz, s.buzz)
    aux(C_, handle, VP.jitter, s.jitter)
    aux(C_, handle, VP.shimmer, s.shimmer)
    aux(C_, handle, VP.creak, s.creak)
    aux(C_, handle, VP.vibDepth, s.vibDepth)
    aux(C_, handle, VP.vibRate, s.vibRate)
end

-- the held note (one at a time): start, change, stop
local function start(pitch, consonant)
    local C_ = C()
    if not C_ then return nil end
    ensurePatch()
    local s = S()
    if s.handle then synth.noteOff(s.handle) end
    s.handle = synth.noteOn(PATCH, math.floor(pitch + 0.5), 6)
    if not s.handle then return nil end
    synth.noteSet(s.handle, pitch)
    pushSound(C_, s.handle)
    pushVowel(C_, s.handle, s.f1, s.f2)
    if consonant and CONSONANT_ID[consonant] then
        C_.voice_consonant(s.handle, CONSONANT_ID[consonant])
        s.consonantMouth, s.consonantUntil = CONSONANT_MOUTH[consonant] or 'C_D_E_G_K_N_R_S',
            love.timer.getTime() + CONSONANT_FOR
    end
    s.sounding = true
    return s.handle
end

function lib.hold(consonant) return start(S().pitch, consonant) end

function lib.release()
    local s = S()
    if s.handle then synth.noteOff(s.handle) end
    s.handle, s.sounding, s.babble = nil, false, nil
end

-- the chart point moves (while held: heard at once, the engine slews it)
function lib.setVowel(f1, f2)
    local s = S()
    s.f1, s.f2 = f1, f2
    local C_ = s.handle and C()
    if C_ then pushVowel(C_, s.handle, f1, f2) end
end

-- a setting changed: heard on the held note too
function lib.refresh()
    local s = S()
    local C_ = s.handle and C()
    if C_ then
        pushSound(C_, s.handle)
        synth.noteSet(s.handle, s.pitch)
    end
end

function lib.preset(name)
    local s = S()
    for k, v in pairs(lib.PRESETS[name] or {}) do s[k] = v end
    s.presetName = name
    lib.refresh()
end

-- one syllable: the consonant, then the current vowel, rung out
function lib.say(consonant)
    local s = S()
    s.babble = nil
    start(s.pitch, consonant)
    s.releaseAt = love.timer.getTime() + 0.32
end

-- babble: mipomi syllables on one held note, re-articulated (connected), a falling tune with a lift
local BABBLE_C = { 'm', 'p', 'b', 'l', 'n', 'd', 'm', 'p' }
local BABBLE_V = { 'i', 'o', 'a', 'oo', 'e', 'o', 'i', 'a' }
local function vowelNamed(name)
    for _, v in ipairs(lib.VOWELS) do if v.name == name then return v end end
end
function lib.babble(count)
    local s = S()
    count = count or love.math.random(3, 6)
    local list = {}
    local pitch = s.pitch + love.math.random(0, 3)
    for i = 1, count do
        local last = i == count
        list[i] = { c = BABBLE_C[love.math.random(#BABBLE_C)], v = BABBLE_V[love.math.random(#BABBLE_V)],
            pitch = pitch + (last and love.math.random(-4, 4) or 0),
            dur = last and 0.34 or (0.15 + love.math.random() * 0.08) }
        pitch = pitch - love.math.random(0, 2) + (love.math.random() < 0.2 and 3 or 0)
    end
    s.babble = { list = list, i = 0, nextAt = love.timer.getTime() }
end

local function babbleStep(s, now)
    local b = s.babble
    if now < b.nextAt then return end
    b.i = b.i + 1
    local syl = b.list[b.i]
    if not syl then lib.release() return end
    local v = vowelNamed(syl.v)
    s.f1, s.f2 = v.f1, v.f2
    local C_ = C()
    if not C_ then s.babble = nil return end
    if b.i == 1 or not s.handle then
        start(syl.pitch, syl.c)
    else
        synth.noteSet(s.handle, syl.pitch)
        pushVowel(C_, s.handle, s.f1, s.f2)
        C_.voice_consonant(s.handle, CONSONANT_ID[syl.c])
        s.consonantMouth, s.consonantUntil = CONSONANT_MOUTH[syl.c] or 'C_D_E_G_K_N_R_S', now + CONSONANT_FOR
    end
    b.nextAt = now + syl.dur
end

-- ── recorded takes (VB3) ─────────────────────────────────────────────────────────────────────────
local voiceLab = require('src.voice-lab')
lib.lab = voiceLab -- for the scene's take panel (scene scripts can't require)
local pitchData
local VOWEL_OF = { a = 'a', e = 'e', i = 'i', o = 'o', u = 'oo' }
local CONSONANT_OF = { j = 'y', c = 'k', h = nil } -- the take's letters the voice says otherwise

-- a take's name as a syllable: its consonant (nil: none the voice has) and vowel ('po3' -> 'p', 'o')
function lib.syllableOf(name)
    local letters = (name or ''):lower():gsub('[^a-z]', '')
    local consonant, vowelLetter = letters:match('^([^aeiou]*)([aeiou])')
    if not vowelLetter then return nil, 'uh' end
    if CONSONANT_OF[consonant] ~= nil then consonant = CONSONANT_OF[consonant] end
    if not CONSONANT_ID[consonant] then consonant = nil end
    return consonant, VOWEL_OF[vowelLetter]
end

-- the take's measured pitch (midi), nil when it hasn't been measured (the puppetmaker and fx sets)
function lib.takeMidi()
    pitchData = pitchData or require('src.voice-pitch-data')
    local L = state.voiceLab
    local set = pitchData[L.set]
    local entry = set and set[voiceLab.takeName()]
    return entry and entry.midi, entry and entry.dur
end

local function sayingFor(seconds, vowelName)
    local s = S()
    local v = vowelNamed(vowelName)
    if v then s.f1, s.f2 = v.f1, v.f2 end
    s.sounding, s.takeUntil = true, love.timer.getTime() + seconds
end

-- how: 'bare' (the take through LÖVE, its rate taking it to the pitch: pitch and length together, as
-- the choir), 'synth' (shifted to the pitch, length kept, size as set), 'sing' (INSTR_SING at the pitch),
-- 'made' (the same syllable on the voice box). Off pitch (s.takeAtPitch false, or not measured): the
-- voice lab's own speed / shift.
function lib.playTake(how)
    local s = S()
    local L = state.voiceLab
    lib.release()
    local name = voiceLab.takeName()
    if not name then return end
    local consonant, vowelName = lib.syllableOf(name)
    if how == 'made' then
        local v = vowelNamed(vowelName)
        if v then s.f1, s.f2 = v.f1, v.f2 end
        lib.say(consonant)
        return
    end
    local measured, dur = lib.takeMidi()
    local delta = (s.takeAtPitch ~= false and measured) and (s.pitch - measured) or nil
    local speed, shift = L.speed, L.shift
    if how == 'bare' then
        if delta then L.speed = delta end
        voiceLab.playNow()
        sayingFor((dur or 0.4) / 2 ^ (L.speed / 12), vowelName)
    elseif how == 'synth' then
        if delta then L.speed, L.shift = 0, math.floor(delta + 0.5) end -- whole semitones: baked per value
        voiceLab.playSynth()
        sayingFor(dur or L.seconds or 0.4, vowelName)
    elseif how == 'sing' then
        voiceLab.playSing(delta and s.pitch or nil)
        sayingFor(dur or L.seconds or 0.4, vowelName)
    end
    L.speed, L.shift = speed, shift
    -- the lab sets up pool slots 45/46 itself: the pool's record of them is stale now
    local pool = state.synth and state.synth.pool
    if pool and how ~= 'bare' then pool[45], pool[46] = nil, nil end
end

-- the mouth shape points by name (normalized, 16 numbers)
local shapePoints
local function pointsOf(name)
    if not shapePoints then
        shapePoints = {}
        for _, sh in ipairs(mouthShapes.normalized) do shapePoints[sh.name] = sh.points end
    end
    return shapePoints[name]
end

-- where a point sits on the chart, 0..1 both ways (front left, open down)
function lib.chartXY(f1, f2)
    local c = lib.CHART
    return (log2(c.f2max) - log2(f2)) / (log2(c.f2max) - log2(c.f2min)),
        (log2(f1) - log2(c.f1min)) / (log2(c.f1max) - log2(c.f1min))
end
function lib.chartFormants(x, y)
    local c = lib.CHART
    x, y = clamp01(x), clamp01(y)
    return 2 ^ (log2(c.f1min) + y * (log2(c.f1max) - log2(c.f1min))),
        2 ^ (log2(c.f2max) - x * (log2(c.f2max) - log2(c.f2min)))
end

-- the vowel mouth for a chart point: each vowel's shape weighted by nearness (smooth, never a pick)
local function vowelMouth(f1, f2)
    local x, y = lib.chartXY(f1, f2)
    local vec, total = {}, 0
    for i = 1, 16 do vec[i] = 0 end
    for _, v in ipairs(lib.VOWELS) do
        local vx, vy = lib.chartXY(v.f1, v.f2)
        local w = 1 / ((x - vx) ^ 2 + (y - vy) ^ 2 + 0.002) ^ 1.5
        local pts = pointsOf(v.mouth)
        if pts then
            total = total + w
            for i = 1, 16 do vec[i] = vec[i] + w * pts[i] end
        end
    end
    for i = 1, 16 do vec[i] = vec[i] / total end
    return vec
end
lib._vowelMouth = vowelMouth -- for specs

local function faceThing(instance)
    local owner = instance.dna and instance.dna.creation and instance.dna.creation.isPotatoHead and 'torso1' or 'head'
    local part = instance.parts and instance.parts[owner]
    if not (part and part.body and not part.body:isDestroyed()) then return nil end
    return part.body:getUserData().thing, instance.dna.parts[owner]
end

-- each frame: the babble, a said syllable's end, and the Mipo's mouth (nil: no Mipo)
function lib.update(dt, instance)
    local s = S()
    local now = love.timer.getTime()
    if s.babble then babbleStep(s, now) end
    if s.takeUntil and now >= s.takeUntil then s.takeUntil, s.sounding = nil, false end
    if s.releaseAt and now >= s.releaseAt and not s.babble then
        s.releaseAt = nil
        lib.release()
    end
    -- the mouth opens with the sound (fast) and closes after it (a little slower)
    local goal = s.sounding and 1 or 0
    local rate = goal > s.mouthOpen and 30 or 10
    s.mouthOpen = s.mouthOpen + (goal - s.mouthOpen) * math.min(1, dt * rate)
    if not instance then return end
    local thing, part = faceThing(instance)
    if not thing then return end
    if s.mouthOpen < 0.01 and not s.sounding then
        if s.ownsMouth then thing.mouthShapeVec, s.ownsMouth = nil, false end
        return
    end
    local face = part and part.appearance and part.appearance.face
    local own = face and face.mouth and mouthShapes.normalized[face.mouth.shape]
    local rest = own and own.points or pointsOf('closed')
    local shape = vowelMouth(s.f1, s.f2)
    if s.consonantUntil and now < s.consonantUntil and pointsOf(s.consonantMouth) then
        shape = pointsOf(s.consonantMouth)
    end
    -- how far from its own mouth: the open vowels all the way, the close ones (i, oo) about half (F1)
    local _, openness = lib.chartXY(s.f1, s.f2)
    local amount = s.mouthOpen * (lib.MOUTH_CLOSE + (1 - lib.MOUTH_CLOSE) * clamp01(openness))
    local vec = {}
    for i = 1, 16 do vec[i] = rest[i] + (shape[i] - rest[i]) * amount end
    thing.pulledFaceUntil, thing.mouthTweenStart, thing.mouthLetGo = nil, nil, nil
    thing.mouthShapeVec, s.ownsMouth = vec, true
end

return lib
