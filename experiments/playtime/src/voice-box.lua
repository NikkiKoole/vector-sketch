-- voice-box.lua — a Mipo voice made from scratch, not recorded (docs/VOICEBOX.md, the voicebox spike):
-- dreamengine's formant voice (INSTR_VOICE: a glottal pulse through four vowel formants, navkit's VoicForm),
-- every knob it has, and the Mipo's mouth following what it says.
--   vowels  a point on the vowel chart (F1 = how open, F2 = how front), anywhere between the vowels:
--           the engine's AH formants scaled to that F1/F2 (its open/front levers, note_aux 8/9)
--   sound   size (the throat: giant -> tiny), effort (soft breathy -> bright pressed), nasal, buzz,
--           jitter / shimmer / creak (roughness), vibrato
--   speech  a consonant opens a syllable (voice_consonant, 22 of them: b d g m n l s sh ng r w y dh f v
--           z zh th p t k ch); a coda closes it (voice_coda: "mip", "pom", VB4); babble: a phrase of
--           Mipomi sentence on one held note (VB4: the language's own words, ~/Projects/love/mipomi-lang)
--   feeling a Mipo's feeling (src/mipo-emotion.lua) picks what it says ("mi i mola", I am happy), tints the
--           voice (pitch, pace, effort) and the mood consonant the sentence closes on (Mipomi's paragrammar:
--           m warm, p tense, h a sigh, f cross, b aww)
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
-- the engine's consonant lengths (dreamengine runtime/sound.h vox_cons_dur) and which are unvoiced
local CONSONANT_DUR = { b = 0.055, d = 0.055, g = 0.055, m = 0.09, n = 0.09, l = 0.07, s = 0.11, sh = 0.11,
    ng = 0.09, r = 0.07, w = 0.07, y = 0.07, dh = 0.09, f = 0.11, v = 0.10, z = 0.11, zh = 0.11, th = 0.11,
    p = 0.055, t = 0.055, k = 0.055, ch = 0.09 }
local UNVOICED = { s = true, sh = true, f = true, th = true, p = true, t = true, k = true, ch = true }
-- codas (VB4): the engine keeps the voice on through a coda, so an unvoiced one (p t k, s f) goes quiet once
-- it's closed: "mi-p" stops, "po-m" hums on a little
lib.CODAS = { 'm', 'n', 'ng', 'l', 'p', 't', 'k', 's', 'f', 'b', 'd', 'h' }
lib.CODA_HUM = 0.1    -- seconds a voiced coda (m n ng l) hums on, closed, before the release
lib.CODA_STOP = 0.03  -- seconds an unvoiced one holds, closed and quiet
lib.SYLLABLE = 0.2    -- seconds of vowel before a said syllable's coda (no coda: rung out 0.32)
lib.VOLUME = 6
lib.LOOP_GAP = 0.12 -- seconds between a looped take's repeats
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

local function vowelNamed(name)
    for _, v in ipairs(lib.VOWELS) do if v.name == name then return v end end
end

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
    aux(C_, handle, VP.size, clamp01(s.size + (s.cute and lib.CUTE.size or 0)))
    -- effort as dreamengine's voxpad has it: breath, glottal open quotient and tilt together
    local feel = lib.FEEL[s.feeling or 'neutral'] or lib.FEEL.neutral
    local effort = clamp01(s.effort + (feel.effort or 0))
    aux(C_, handle, VP.breath, 0.55 * (1 - effort))
    aux(C_, handle, VP.openq, 0.95 - 0.9 * effort)
    aux(C_, handle, VP.tilt, 0.8 * (1 - effort))
    aux(C_, handle, VP.nasal, s.nasal)
    aux(C_, handle, VP.buzz, s.buzz)
    aux(C_, handle, VP.jitter, s.jitter)
    aux(C_, handle, VP.shimmer, s.shimmer)
    aux(C_, handle, VP.creak, s.creak)
    local vib = s.babble and s.babble.vib -- a speaker's own vibrato (lib.speak) while it talks
    aux(C_, handle, VP.vibDepth, vib and vib.depth or s.vibDepth)
    aux(C_, handle, VP.vibRate, vib and vib.rate or s.vibRate)
end

-- the held note (one at a time): start, change, stop
local function start(pitch, consonant)
    local C_ = C()
    if not C_ then return nil end
    ensurePatch()
    local s = S()
    if s.handle then synth.noteOff(s.handle) end
    s.quietAt, s.codaAt = nil, nil -- a new note: the last one's coda is done with
    s.handle = synth.noteOn(PATCH, math.floor(pitch + 0.5), lib.VOLUME)
    if not s.handle then return nil end
    synth.noteSet(s.handle, pitch)
    pushSound(C_, s.handle)
    pushVowel(C_, s.handle, s.f1, s.f2)
    lib.articulate(C_, s, consonant, love.timer.getTime())
    s.sounding = true
    return s.handle
end

-- a consonant opens the syllable on the held note. 'h' isn't one of the engine's: a breath puff instead, the
-- voice breathy for a moment (lib.H_PUFF s), then back. 'j' is Mipomi's (the Dutch j): the engine's y.
lib.H_PUFF = 0.07
-- soft (s.soft): a voiceless consonant said as its voiced twin, as small children do ("bapa" for papa). The
-- engine cuts the voice off at once for a voiceless one, which clicks mid-sentence (f and s worst, VB4)
lib.SOFT = { p = 'b', t = 'd', k = 'g', f = 'v', s = 'z', sh = 'zh', th = 'dh', ch = 'zh' }
local function softened(s, consonant) return s.soft and lib.SOFT[consonant] or consonant end

function lib.articulate(C_, s, consonant, now)
    if consonant == 'j' then consonant = 'y' end
    consonant = softened(s, consonant)
    if consonant == 'h' then
        aux(C_, s.handle, VP.breath, 1)
        aux(C_, s.handle, VP.openq, 1)
        aux(C_, s.handle, VP.tilt, 1)
        s.breathUntil = now + lib.H_PUFF
    elseif consonant and CONSONANT_ID[consonant] then
        C_.voice_consonant(s.handle, CONSONANT_ID[consonant])
        s.consonantMouth, s.consonantUntil = CONSONANT_MOUTH[consonant] or 'C_D_E_G_K_N_R_S', now + CONSONANT_FOR
    end
end

function lib.hold(consonant) return start(S().pitch, consonant) end

local takeOff -- the person's voice, below
function lib.release()
    local s = S()
    if s.handle then synth.noteOff(s.handle) end
    takeOff(s)
    s.handle, s.sounding, s.babble, s.codaAt = nil, false, nil, nil
end

-- close the held note on a consonant now; returns how long until it's closed and done.
-- 'h' closes on a sigh: the voice goes breathy and fades (lib.SIGH s)
lib.SIGH = 0.3
local function fireCoda(s, coda, now)
    local C_ = s.handle and C()
    coda = softened(s, coda)
    if C_ and coda == 'h' then
        aux(C_, s.handle, VP.breath, 1)
        aux(C_, s.handle, VP.openq, 1)
        aux(C_, s.handle, VP.tilt, 1)
        s.quietAt = now + lib.SIGH * 0.4
        return lib.SIGH
    end
    if not (C_ and CONSONANT_ID[coda]) then return 0 end
    C_.voice_coda(s.handle, CONSONANT_ID[coda])
    local closed = CONSONANT_DUR[coda] or 0.08
    local done = closed + (UNVOICED[coda] and lib.CODA_STOP or lib.CODA_HUM)
    if UNVOICED[coda] then s.quietAt = now + closed end
    -- the mouth goes to the consonant as it closes, and stays there till the end
    s.consonantMouth, s.consonantUntil = CONSONANT_MOUTH[coda] or 'C_D_E_G_K_N_R_S', now + done
    return done
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

-- one syllable: the consonant, then the current vowel, rung out or closed on a coda ("mip")
function lib.say(consonant, coda)
    local s = S()
    s.babble = nil
    start(s.pitch, consonant)
    local now = love.timer.getTime()
    if coda and CONSONANT_ID[coda] then
        s.codaAt, s.pendingCoda, s.releaseAt = now + lib.SYLLABLE, coda, nil
    else
        s.codaAt, s.releaseAt = nil, now + 0.32
    end
end

-- a whole word: onset, vowel (a chart vowel's name), coda; 'mip' = say('m', 'i', 'p')
function lib.word(consonant, vowelName, coda)
    local v = vowelNamed(vowelName)
    if v then lib.setVowel(v.f1, v.f2) end
    lib.say(consonant, coda)
end

-- ── babble in Mipomi (VB4) ──────────────────────────────────────────────────────────────────────
-- Mipomi (~/Projects/love/mipomi-lang grammar.txt): CV syllables only, 13 consonants (m b p f k l t j n d s h
-- w), three vowels (a i o). A sentence: subject, an aspect vowel (i is, a becomes / goes, o does), what.
-- "mi i mola" I am happy. A whispered consonant after it carries the mood (its paragrammar).
-- The words: the language's core (~/Projects/love/mipomi-lang words.tsv, column core; exported to
-- src/mipomi-words.lua by its export.lua). A sentence takes its parts from the core's groups.
local mipomiWords = require('src.mipomi-words')
local function coreOf(group) return mipomiWords.core[group] or {} end
local function join(...)
    local list = {}
    for _, group in ipairs({ ... }) do
        for _, w in ipairs(type(group) == 'table' and group or coreOf(group)) do list[#list + 1] = w end
    end
    return list
end
lib.MIPOMI = {
    subjects = join({ 'mi', 'jo', 'bi', 'mibi' }, { 'wobo', 'koka', 'bofo', 'bowa' }), -- the pronouns, some things
    i = join('feeling', 'quality', 'where'),  -- is: how it feels, what it's like, where it is
    a = join('where', 'feeling'),             -- becomes / goes: somewhere, a feeling
    o = join('play', 'voice'),                -- does
    objects = coreOf('thing'),                -- after a doing that takes one, now and then
    takes = { po = true, pi = true, di = true, paki = true, faha = true, pifo = true, haka = true, lapi = true },
    alone = { { 'mipo' }, { 'la' }, { 'na' }, { 'pomo' }, { 'mipa' }, { 'mipo', 'mibi' } }, -- said on its own
}
lib.words = mipomiWords

-- per feeling: what it says, how it sounds, the mood consonant it ends on (Mipomi's paragrammar: m comfort,
-- p tension, h sigh / awe, f frustration, b affectionate aww; nil: no ending). pitch in semitones, pace x
lib.FEEL = {
    neutral   = { pitch = 0, pace = 1, effort = 0 },
    happy     = { pitch = 2, pace = 1.1, effort = 0.1, ending = 'm',
                  says = { { 'mi', 'i', 'mola' }, { 'mi', 'i', 'lala' }, { 'mi', 'o', 'mowa' }, { 'momo' } } },
    sad       = { pitch = -3, pace = 0.8, effort = -0.15, ending = 'h',
                  says = { { 'mi', 'i', 'mino' }, { 'mi', 'o', 'miso' }, { 'mino', 'mino' } } },
    angry     = { pitch = -1, pace = 1.15, effort = 0.3, ending = 'f',
                  says = { { 'mi', 'i', 'faho' }, { 'mi', 'o', 'jaho' }, { 'na', 'na' }, { 'lana' } } },
    scared    = { pitch = 4, pace = 1.3, effort = 0, ending = 'p',
                  says = { { 'mi', 'i', 'fowa' }, { 'mi', 'a', 'fowa' }, { 'nako' } } },
    surprised = { pitch = 3, pace = 1, effort = 0.15, ending = 'h',
                  says = { { 'moja' }, { 'mi', 'i', 'moja' }, { 'jo', 'i', 'moja' } } },
    sleepy    = { pitch = -4, pace = 0.7, effort = -0.25, ending = 'm',
                  says = { { 'mi', 'i', 'nini' }, { 'mi', 'a', 'nisa' }, { 'nini' } } },
    shy       = { pitch = 1, pace = 0.9, effort = -0.2, volume = 0.7, ending = 'b',
                  says = { { 'mi', 'i', 'misofo' }, { 'mi', 'i', 'lili' } } },
}
local MIPOMI_VOWEL = { a = 'a', i = 'i', o = 'o', u = 'oo', e = 'e' }

local function pick(list) return list[love.math.random(#list)] end

-- a sentence as words: the feeling's own, else subject + aspect + what (+ an object after a doing)
function lib.sentence(feeling)
    local feel = lib.FEEL[feeling or 'neutral']
    if feel and feel.says and love.math.random() < 0.75 then
        local words = {}
        for i, w in ipairs(pick(feel.says)) do words[i] = w end
        return words
    end
    local M = lib.MIPOMI
    if love.math.random() < 0.15 then
        local words = {}
        for i, w in ipairs(pick(M.alone)) do words[i] = w end
        return words
    end
    local aspect = pick({ 'i', 'a', 'o' })
    local words = { pick(M.subjects), aspect, pick(M[aspect]) }
    if aspect == 'o' and M.takes[words[3]] and love.math.random() < 0.6 then words[#words + 1] = pick(M.objects) end
    return words
end

-- a word's syllables: { consonant (nil: a bare vowel), vowel name }
function lib.syllables(word)
    local list = {}
    for c, v in word:lower():gmatch('([^aeiou]*)([aeiou])') do
        list[#list + 1] = { c = c ~= '' and c or nil, v = MIPOMI_VOWEL[v] }
    end
    return list
end

-- ── grunts (VB7): the talking heads' fx and Puppetmaker's sounds, made on the voice, not played ──────────
-- Each is a few steps on the held note: { v vowel, c consonant (nil: none), dur, bend = { from, to } semitones
-- over the step (from the speaker's pitch), nasal / breath / effort / size (0..1, over the settings while it
-- sounds), vol, cut (seconds, then quiet: a click), coda, mouth = 'closed' (a hum) } and { pause = s }.
-- Shapes measured from mipomi-lang samples-fx (2026-11-11): hum down 0.27 s voiced, falling 4-5 semitones;
-- hum up 0.13 s rising 2-4; huh 0.35 s mostly breath, a short voiced end; blah 0.3-0.45 s falling ~7, a
-- breathy end; tsk 30-60 ms, a click. In a line: (humup), (tsk); the talking heads' (humup1) and
-- ([a3]humup1) work too (digits dropped, the note is its pitch).
lib.GRUNTS = {
    humup   = { { c = 'm', v = 'uh', dur = 0.14, bend = { -2, 2 }, nasal = 0.9, mouth = 'closed' } },
    humdown = { { c = 'm', v = 'uh', dur = 0.28, bend = { 1, -4 }, nasal = 0.9, mouth = 'closed' } },
    hmm     = { { c = 'm', v = 'uh', dur = 0.55, bend = { 0, -1.5 }, nasal = 0.95, mouth = 'closed' } },
    mmhm    = { { c = 'm', v = 'uh', dur = 0.16, bend = { 0, 0 }, nasal = 0.9, mouth = 'closed' },
                { c = 'h', v = 'uh', dur = 0.22, bend = { 3, 4 }, nasal = 0.9, mouth = 'closed' } },
    uhuh    = { { v = 'uh', dur = 0.15, bend = { 2, 2 } }, { pause = 0.06 },
                { v = 'uh', dur = 0.22, bend = { -1, -2.5 } } },
    huh     = { { c = 'h', v = 'uh', dur = 0.16, bend = { 0, 0 }, breath = 1, vol = 0.6 },
                { v = 'uh', dur = 0.16, bend = { 0, 4 } } },
    eh      = { { v = 'e', dur = 0.22, bend = { 0, 5 } } },
    blah    = { { c = 'b', v = 'a', dur = 0.07, bend = { 2, 2 } },
                { c = 'l', v = 'a', dur = 0.32, bend = { 1, -7 }, breath = 0.45 } },
    tsk     = { { c = 't', v = 'i', dur = 0.06, cut = 0.025, breath = 1 } },
    tsktsk  = { { c = 't', v = 'i', dur = 0.06, cut = 0.025, breath = 1 }, { pause = 0.11 },
                { c = 't', v = 'i', dur = 0.06, cut = 0.025, breath = 1 } },
    hmpf    = { { c = 'm', v = 'uh', dur = 0.16, bend = { 0, -1 }, nasal = 0.9, mouth = 'closed' },
                { c = 'p', v = 'uh', dur = 0.14, breath = 1, vol = 0.6, cut = 0.1 } },
    oof     = { { v = 'oo', dur = 0.24, bend = { 2, -5 }, effort = 0.9, coda = 'f' } },
    squeak  = { { c = 'y', v = 'i', dur = 0.13, bend = { 8, 12 }, size = 1 } },
    ah      = { { v = 'a', dur = 0.28, bend = { 3, 7 }, effort = 0.8 } },
    ooh     = { { v = 'o', dur = 0.2, bend = { 0, 4 } }, { v = 'oo', dur = 0.32, bend = { 4, -1 }, breath = 0.3 } },
    uhoh    = { { v = 'uh', dur = 0.18, bend = { 4, 4 } }, { pause = 0.04 },
                { v = 'o', dur = 0.32, bend = { 0, -1 } } },
    yay     = { { c = 'y', v = 'a', dur = 0.15, bend = { 2, 5 } }, { v = 'i', dur = 0.26, bend = { 7, 9 } } },
    giggle  = { { c = 'h', v = 'i', dur = 0.08, bend = { 7, 7 }, breath = 0.6 },
                { c = 'h', v = 'i', dur = 0.08, bend = { 6, 6 }, breath = 0.6 },
                { c = 'h', v = 'i', dur = 0.08, bend = { 5, 5 }, breath = 0.6 },
                { c = 'h', v = 'i', dur = 0.12, bend = { 5, 3 }, breath = 0.6 } },
    sigh    = { { c = 'h', v = 'a', dur = 0.55, bend = { 2, -4 }, breath = 0.85, vol = 0.7 } },
    yawn    = { { v = 'a', dur = 0.55, bend = { 0, 5 }, effort = 0.2 }, { v = 'a', dur = 0.45, bend = { 5, -3 } },
                { v = 'uh', dur = 0.2, bend = { -3, -4 }, coda = 'm' } },
}
-- the feelings' grunts (a babble starts or ends with one now and then, lib.GRUNT_CHANCE): before the words, or
-- after them in place of the mood consonant
lib.FEEL_GRUNTS = {
    neutral = { before = { 'hmm', 'eh', 'huh' }, after = { 'mmhm' } },
    happy = { before = { 'yay' }, after = { 'giggle', 'humup' } },
    sad = { after = { 'sigh', 'humdown' } },
    angry = { before = { 'hmpf' }, after = { 'tsktsk', 'hmpf' } },
    scared = { before = { 'uhoh', 'ah' } },
    surprised = { before = { 'ah', 'ooh', 'huh' } },
    sleepy = { before = { 'yawn' }, after = { 'hmm', 'yawn' } },
    shy = { after = { 'giggle', 'humup' } },
}
lib.GRUNT_CHANCE = 0.4
lib.GRUNT_NAMES = { 'humup', 'humdown', 'hmm', 'mmhm', 'uhuh', 'huh', 'eh', 'blah', 'tsk', 'tsktsk', 'hmpf',
    'oof', 'squeak', 'ah', 'ooh', 'uhoh', 'yay', 'giggle', 'sigh', 'yawn' }

-- ── a person's voice (2026-11-11, Nikki: "so we have real voices as source sound for all this"): the
-- recorded syllables (assets/voices/<theo|nikki|herman>, all 39 Mipomi roots each) said instead of the made
-- voice, through dreamengine's INSTR_SING (one grain per vocal pulse: any note exactly, a size lever that
-- keeps who it is). One speaker's takes loaded end to end into one sample slot (one analysis), a syllable
-- plays its chop of it once through, sped to fit; the melody, cute, questions, feelings stay. The recorded grunts (assets/voices/fx) the same way, from their own slot.
lib.TAKE_VOICES = { 'theo', 'nikki', 'herman' }
lib.TAKE_INFLECTION = 0.15 -- how much of a take's own melody rides on our note (0 flat, 0.5 as recorded)
lib.TAKE_GAP = 0.04        -- seconds of quiet between takes in a bank
-- a slot each (the engine's pulse analysis of a bank takes ~0.8 s: once per speaker, then switching is free)
local BANK_SLOTS = { theo = { sample = 12, instr = 120 }, nikki = { sample = 13, instr = 121 },
    herman = { sample = 14, instr = 122 }, fx = { sample = 15, instr = 123 } }
local TAKE_VOWEL = { a = 'a', i = 'i', o = 'o', oo = 'o', e = 'i', uh = 'a' } -- a vowel no take has: the nearest
-- the recorded grunts; a grunt not here is made on the voice box voice
local FX_OF = { humup = { 'humup1', 'humup2', 'humup3', 'humup4' },
    humdown = { 'humdown1', 'humdown2', 'humdown3', 'humdown4' }, blah = { 'blah1', 'blah2', 'blah3' },
    huh = { 'huh', 'huh2' }, tsk = { 'tsk', 'tsk2' }, tsktsk = { 'tsk', 'tsk2', twice = true } }

-- a set's takes as one bank in the engine: { set, regions = { name = { start, end (0..1), seconds } } }.
-- Kept on state: the engine keeps the slots over a hot swap; loaded again when the synth restarted.
-- The first use of a speaker freezes the game ~1 s (the analysis, on the game thread).
local function bankOf(set)
    local C_ = C()
    if not C_ or not set then return nil end
    local slots = BANK_SLOTS[set]
    if not slots then return nil end
    state.voiceBoxBanks = state.voiceBoxBanks or {}
    local bank = state.voiceBoxBanks[set]
    if bank and bank.C == C_ then return bank end
    local lab = require('src.voice-lab')
    local dir = 'assets/voices/' .. set
    local parts, total = {}, 0
    local gap = math.floor(lib.TAKE_GAP * 44100)
    -- the game runs with the JIT off (main.lua); this sample loop is 1.4 s without it, 0.03 s with
    local jitOn = jit and pcall(jit.on) -- luacheck: ignore 113 (jit is a LuaJIT global)
    for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local key = file:match('^(.+)%.ogg$')
        if key then
            local data, n, seconds = lab.pcm(dir .. '/' .. file)
            parts[#parts + 1] = { key = key, data = data, n = n, seconds = seconds, at = total + gap }
            total = total + gap + n
        end
    end
    if jitOn then jit.off() jit.flush() end -- luacheck: ignore 113
    if #parts == 0 then return nil end
    total = total + gap
    local ffi_ = require('ffi')
    local all = ffi_.new('float[?]', total)
    local regions = {}
    for _, part in ipairs(parts) do
        ffi_.copy(all + part.at, part.data, part.n * 4)
        regions[part.key] = { part.at / (total - 1), (part.at + part.n - 1) / (total - 1), part.seconds }
    end
    C_.sample_load(slots.sample, all, total)
    C_.instrument(slots.instr, synth.INSTR.SING, 4, 10, 7, 90) -- first: it clears the sample binding
    C_.instrument_sample(slots.instr, slots.sample, 60)
    C_.instrument_mode(slots.instr, 0, 1) -- one-shot: the take once through, never rocked (see takeSyllable)
    C_.instrument_level(slots.instr, 4)   -- the voice lab's level (its measured match with the bare take)
    C_.instrument_morph(slots.instr, 0.5)
    pcall(C_.instrument_reverb, slots.instr, 0.15)
    -- a silent note asks the engine for the analysis now, not on the first syllable said
    local warm = C_.note_on(60, slots.instr, 0)
    if warm then C_.note_off(warm) end
    bank = { set = set, regions = regions, C = C_, instr = slots.instr }
    state.voiceBoxBanks[set] = bank
    return bank
end

-- every speaker's bank and the grunts, at the scene's start (the ~3 s of analysis there, not mid-play)
function lib.preloadVoices()
    for _, set in ipairs(lib.TAKE_VOICES) do bankOf(set) end
    bankOf('fx')
end

-- speak with a person's syllables (theo, nikki, herman) or the made voice (nil)
function lib.useVoice(set)
    local s = S()
    s.takeVoice = set
    if set then bankOf(set) bankOf('fx') end
end

local function takeSize(s)
    return clamp01(0.5 + (s.size - 0.33) * 0.35 + (s.cute and 0.05 or 0))
end

-- a recorded grunt's steps, when one is speaking with a person's voice and the grunt was recorded
local function recordedGrunt(name, base)
    local files = FX_OF[name]
    if not (S().takeVoice and files) then return nil end
    local bank = bankOf('fx')
    if not bank then return nil end
    local function step()
        local file = files[love.math.random(#files)]
        local r = bank.regions[file]
        return r and { fx = file, v = 'uh', dur = r[3], pitch = base, curve = 'neutral', explicit = true,
            grunt = name, bend = { 0, 0 } }
    end
    local first = step()
    if not first then return nil end
    if files.twice then return { first, { pause = 0.11 }, step() } end
    return { first }
end

-- say a syllable (or a recorded grunt) with the person's voice; false when there's no take for it
local function takeSyllable(s, syl, volume, now)
    if not s.takeVoice then return false end
    local bank = syl.fx and bankOf('fx') or bankOf(s.takeVoice)
    local name = syl.fx or ((syl.c or '') .. (TAKE_VOWEL[syl.v] or 'a'))
    local r = bank and bank.regions[name]
    if not r then return false end
    local C_ = C()
    if s.takeHandle then -- the last one fades out under this one (one-shot: note_off alone lets it finish)
        C_.note_vol(s.takeHandle, 0)
        C_.note_off(s.takeHandle)
    end
    if s.handle then synth.noteSet(s.handle, nil, 0) end
    C_.instrument_sample_region(bank.instr, r[1], r[2])
    -- once through (held, the engine rocks the last 60 ms of its vowel: a piece said over and over), at the
    -- speed that fits the take to the syllable: 0.4x .. 2x (the pitch and the voice stay)
    C_.instrument_mode(bank.instr, 0, 1)
    local speed = syl.fx and 1 or math.max(0.4, math.min(2, r[3] / (syl.dur * 1.1)))
    C_.instrument_morph(bank.instr, speed / 2)
    local h = C_.note_on(math.floor(syl.pitch + 0.5), bank.instr, math.max(0, math.min(7, math.floor(volume + 0.5))))
    if not h then return false end
    C_.note_pitch(h, syl.pitch)
    C_.note_timbre(h, takeSize(s))
    C_.note_harmonics(h, syl.fx and 0.5 or lib.TAKE_INFLECTION)
    s.takeHandle = h
    local c = syl.c == 'j' and 'y' or syl.c
    if c and CONSONANT_MOUTH[c] then s.consonantMouth, s.consonantUntil = CONSONANT_MOUTH[c], now + CONSONANT_FOR end
    if syl.fx and name:find('^hum') then s.consonantMouth, s.consonantUntil = 'M_B_P', now + syl.dur end
    return true
end
takeOff = function(s)
    if s.takeHandle then synth.noteOff(s.takeHandle) end
    s.takeHandle = nil
end

-- a grunt's steps as syllables at `base` (midi)
local function gruntSteps(name, base)
    local recorded = recordedGrunt(name, base)
    if recorded then return recorded end
    local steps = lib.GRUNTS[name]
    if not steps then return nil end
    local list = {}
    for i, step in ipairs(steps) do
        local syl = {}
        for k, v in pairs(step) do syl[k] = v end
        if not syl.pause then
            syl.pitch, syl.curve, syl.explicit, syl.grunt = base, 'neutral', true, name
            syl.bend = syl.bend or { 0, 0 }
        end
        list[i] = syl
    end
    return list
end

-- say a grunt now (as the current feeling's pitch and pace)
function lib.grunt(name) lib.speak('(' .. name .. ')') end

-- a step's own sound over the settings: nasal, breath (to a whisper), effort, size
local function applyStep(C_, s, syl)
    if not (syl.nasal or syl.breath or syl.effort or syl.size) then return end
    if syl.size then aux(C_, s.handle, VP.size, syl.size) end
    if syl.nasal then aux(C_, s.handle, VP.nasal, syl.nasal) end
    local effort = syl.effort or s.effort
    local b = syl.breath or 0
    aux(C_, s.handle, VP.breath, 0.55 * (1 - effort) + (1 - 0.55 * (1 - effort)) * b)
    aux(C_, s.handle, VP.openq, (0.95 - 0.9 * effort) + (1 - (0.95 - 0.9 * effort)) * b)
    aux(C_, s.handle, VP.tilt, 0.8 * (1 - effort) + (1 - 0.8 * (1 - effort)) * b)
end

-- ── speaking a line (VB4): the talking heads' notation (mipomi-lang main.lua parseInput) on the made voice ──
--   {root=c4 swing=.3:1.7 stress=1:3 rndp=0.5 vibrato=1:5:0.5 intonation=1 personality=sleepy} the speaker
--   mi-la a word's syllables (a word written whole is split: mola = mo-la), space between words, ',' a pause
--   ?word / word? rises (a question), _word / word_ falls, CAPITALS stressed, ~ba glides from the one before,
--   [c4]mi on that note, <0.5>mi that loud, a lone consonant after a word closes on it (mola... m), (fx) skipped
-- The voice follows each syllable's pitch curve every frame (the talking heads' curves, as ratios over a
-- syllable), so a rise is heard inside the syllable, not only between them.
lib.CURVES = {
    neutral = { 0.0, 1.0, 0.3, 0.98, 0.6, 1.02, 1.0, 1.0 },
    emphasis = { 0.0, 1.1, 0.3, 1.3, 0.6, 1.0, 1.0, 1.0 },
    rise = { 0.0, 1.0, 0.5, 1.05, 0.8, 1.1, 1.0, 1.25 },
    ['rise-emphasis'] = { 0.0, 1.1, 0.3, 1.25, 0.6, 1.1, 1.0, 1.4 },
    fall = { 0.0, 1.0, 0.4, 1.0, 0.7, 0.95, 1.0, 0.85 },
    ['fall-emphasis'] = { 0.0, 1.1, 0.3, 1.2, 0.6, 1.0, 1.0, 0.8 },
}
-- the talking heads' speakers (vibrato: freq Hz, depth; pause: seconds between syllables, words, at a comma)
lib.PERSONALITIES = {
    robotic = { vibrato = { freq = 0, depth = 0 }, rndp = 0, swing = { 1, 1 },
                pause = { syllable = 0.05, word = 0.2, comma = 0.1 } },
    slowlearner = { vibrato = { freq = 2, depth = 0.4 }, rndp = 0.2, swing = { 1.3, 1.3 }, stress = { 1, 2 },
                pause = { syllable = 0.3, word = 0.8, comma = 0.4 } },
    poopy = { vibrato = { freq = 6, depth = 0.8 }, rndp = 1.5, swing = { 1.2, 1.3 }, stress = { 2, 2 },
                pause = { syllable = 0.15, word = 0.45, comma = 0.25 } },
    sleepy = { vibrato = { freq = 1.5, depth = 0.2 }, rndp = 0.1, swing = { 0.9, 1.1 }, stress = { 1, 4 },
                pause = { syllable = 0.4, word = 1.2, comma = 0.6 } },
    party = { vibrato = { freq = 8, depth = 0.6 }, rndp = 2.0, swing = { 0.6, 1.4 }, stress = { 1, 2 },
                pause = { syllable = 0.1, word = 0.35, comma = 0.2 } },
    simple = { swing = { 0.3, 1.7 }, stress = { 1, 3 } },
    deadpan = { vibrato = { freq = 0.5, depth = 0 }, rndp = 0, swing = { 1, 1 }, stress = { 2, 99 },
                pause = { syllable = 0.2, word = 0.5, comma = 0.4 } },
}
lib.PERSONALITY_NAMES = { 'robotic', 'slowlearner', 'poopy', 'sleepy', 'party', 'simple', 'deadpan' }
lib.SYLLABLE_TIME = 0.17 -- seconds a syllable takes at the default pause (0.1), at pace 1
lib.DECLINE = 2          -- semitones a statement falls over its length (a question doesn't)

local NOTE = { c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11 }
local function noteMidi(name)
    local letter, accidental, octave = (name or ''):lower():match('^([a-g])([#b]?)(%-?%d)$')
    if not letter then return nil end
    return 12 * (tonumber(octave) + 1) + NOTE[letter] + (accidental == '#' and 1 or accidental == 'b' and -1 or 0)
end
lib.noteMidi = noteMidi

local curves = {}
local function curveAt(name, t)
    local c = curves[name]
    if not c then
        c = love.math.newBezierCurve(lib.CURVES[name] or lib.CURVES.neutral)
        curves[name] = c
    end
    local _, ratio = c:evaluate(math.max(0, math.min(1, t)))
    return 12 * log2(math.max(0.01, ratio))
end

local function pair(v)
    local a, b = v:match('^([%d.]+):([%d.]+)$')
    return a and { tonumber(a), tonumber(b) } or nil
end

local function speakerOf(block)
    local cfg = { pause = { syllable = 0.1, word = 0.5, comma = 0.2 }, swing = { 1, 1 }, stress = { 0, 0 },
        rndp = 0, intonation = 1 }
    for k, v in (block or ''):gmatch('([%w_]+)%s*=%s*([^%s},]+)') do
        if k == 'personality' and lib.PERSONALITIES[v] then
            for pk, pv in pairs(lib.PERSONALITIES[v]) do cfg[pk] = pv end
            cfg.personality = v
        elseif k == 'root' then cfg.root = noteMidi(v)
        elseif k == 'swing' or k == 'stress' then cfg[k] = pair(v) or cfg[k]
        elseif k == 'rndp' or k == 'intonation' then cfg[k] = tonumber(v) or cfg[k]
        elseif k == 'vibrato' then
            local _, freq, depth = v:match('^([%d.]+):([%d.]+):([%d.]+)')
            if freq then cfg.vibrato = { freq = tonumber(freq), depth = tonumber(depth) } end
        end
    end
    return cfg
end

-- a line of notation as the syllables the voice says: { c, v, pitch (midi), curve, dur, from, vol, coda } and
-- { pause = s } between words; `base` the pitch (midi) when the line names no root
function lib.parse(text, base)
    local block = text:match('^%s*(%b{})')
    local cfg = speakerOf(block)
    if block then text = text:gsub('^%s*%b{}', '') end
    base = cfg.root or base or 60
    local syllableTime = lib.SYLLABLE_TIME * (0.6 + 2 * cfg.pause.syllable) / 0.8
    local list, sung, n, question = {}, {}, 0, false
    local function lastSyllable() return sung[#sung] end
    text = text:gsub(',', ' , '):gsub('%.%.%.', ' '):gsub('…', ' ')
    for token in text:gmatch('%S+') do
        local fx = token:match('^%b()$') -- (fx): the recorded heads' extras, not this voice's
        if token == ',' then
            list[#list + 1] = { pause = cfg.pause.comma }
        elseif fx then -- a grunt (lib.GRUNTS), else a short quiet
            local inner = token:sub(2, -2)
            local name = inner:gsub('%b[]', ''):gsub('%d+$', ''):lower()
            local steps = gruntSteps(name, noteMidi(inner:match('%[([^%]]+)%]')) or base)
            if #list > 0 and not list[#list].pause then list[#list + 1] = { pause = cfg.pause.word * 0.2 } end
            for _, step in ipairs(steps or { { pause = 0.1 } }) do list[#list + 1] = step end
        elseif not token:lower():find('[aeiou]') then -- a lone consonant: the last syllable closes on it
            local c = token:lower():gsub('[^a-z]', '')
            if lastSyllable() and (CONSONANT_ID[c] or c == 'h') then lastSyllable().coda = c end
        else
            local wordRise, wordFall = token:sub(1, 1) == '?', token:sub(1, 1) == '_'
            if wordRise or wordFall then token = token:sub(2) end
            if #sung > 0 and not list[#list].pause then list[#list + 1] = { pause = cfg.pause.word * 0.2 } end
            local parts = {}
            for raw in token:gmatch('[^%-·]+') do parts[#parts + 1] = raw end
            local inWord = 0
            for pi, raw in ipairs(parts) do
                local glide = raw:sub(1, 1) == '~'
                if glide then raw = raw:sub(2) end
                local rise, fall = raw:sub(-1) == '?', raw:sub(-1) == '_'
                local note = raw:match('%[([^%]]+)%]')
                local vol = tonumber(raw:match('<([%d.]+)>') or '')
                local letters = raw:gsub('%b[]', ''):gsub('%b<>', ''):gsub('[^%a]', '')
                local emphasized = letters:find('%u') and letters == letters:upper()
                local syllables = lib.syllables(letters)
                for si, syl in ipairs(syllables) do
                    n, inWord = n + 1, inWord + 1
                    local lastOfWord = pi == #parts and si == #syllables
                    local stressed = (si == 1 and emphasized)
                        or (cfg.stress[2] > 0 and n % cfg.stress[2] == cfg.stress[1] % cfg.stress[2])
                    local up = (rise and si == #syllables) or (wordRise and lastOfWord)
                    local down = (fall and si == #syllables) or (wordFall and lastOfWord)
                    syl.curve = (up and 'rise' or down and 'fall' or (stressed and 'emphasis' or 'neutral'))
                    if stressed and (up or down) then syl.curve = syl.curve .. '-emphasis' end
                    local drift = (wordRise and 1 or wordFall and -1 or 0) * cfg.intonation * (inWord - 1)
                    syl.pitch = (si == 1 and noteMidi(note) or base) + drift + (love.math.random() * 2 - 1) * cfg.rndp
                    syl.explicit = si == 1 and note ~= nil
                    syl.dur = syllableTime * (stressed and 1.2 or 1) * cfg.swing[(n % 2 == 1) and 1 or 2]
                    syl.from = (glide and si == 1) and true or nil
                    syl.vol = vol
                    if up and lastOfWord then question = true end
                    list[#list + 1] = syl
                    sung[#sung + 1] = syl
                end
            end
        end
    end
    -- a statement falls over its length; a question (its end rising) doesn't
    local last = sung[#sung]
    question = question and last and (last.curve == 'rise' or last.curve == 'rise-emphasis')
    if not question then
        for i, syl in ipairs(sung) do
            if not syl.explicit then syl.pitch = syl.pitch - lib.DECLINE * (i - 1) / math.max(1, #sung - 1) end
        end
    end
    return list, cfg
end

-- cute (2026-11-11, Nikki: "nintendo-esque, cutesy whimsical"): what the critter voices do (Animal Crossing,
-- Springbound, Celeste) and what makes a voice read cute (higher F0 and F1, a smile's shorter throat):
-- syllables hop between the notes of a pentatonic scale instead of speaking's small drift, a word scoops up
-- into its note, quicker, a little higher, smiling formants, a smaller throat
lib.CUTE = {
    scale = { 0, 2, 4, 7, 9 }, -- the notes a syllable lands on, above the speaker's pitch
    low = -3, high = 9,        -- how far a hop goes (semitones)
    lift = 2,                  -- the whole line higher
    pace = 1.3,                -- quicker
    scoop = 1.5, scoopTime = 0.06, -- each syllable slides up into its note
    smileF1 = 1.08, smileF2 = 1.06, size = 0.1,
}
local function snapToScale(semis)
    local octave = math.floor(semis / 12)
    local within, best = semis - 12 * octave, 0
    for _, d in ipairs(lib.CUTE.scale) do
        if math.abs(d - within) < math.abs(best - within) then best = d end
    end
    if math.abs(12 - within) < math.abs(best - within) then best = 12 end
    return 12 * octave + best
end
-- the syllables of a parsed line sung cute: a hop to a scale note each, stressed ones higher, a statement
-- coming home to the speaker's note, a question ending high; set notes ([c4]) and grunts stay as they are
local function cuteMelody(list, base)
    local K = lib.CUTE
    local sung = {}
    for _, syl in ipairs(list) do
        if not syl.pause and not syl.bend and not syl.explicit then sung[#sung + 1] = syl end
    end
    local at = snapToScale(love.math.random(2, 5))
    for i, syl in ipairs(sung) do
        local hop = love.math.random(-4, 4)
        if syl.curve and syl.curve:find('emphasis') then hop = hop + 3 end
        at = math.max(K.low, math.min(K.high, snapToScale(at + hop)))
        if i == #sung then
            local asks = syl.curve == 'rise' or syl.curve == 'rise-emphasis'
            at = asks and snapToScale(love.math.random(5, 9)) or (love.math.random() < 0.7 and 0 or -3)
        end
        syl.pitch = base + K.lift + at
    end
end

-- say a line of notation, as the current feeling (its pitch, pace, voice) when the line doesn't set its own
function lib.speak(text)
    local s = S()
    local feel = lib.FEEL[s.feeling or 'neutral'] or lib.FEEL.neutral
    local list, cfg = lib.parse(text, s.pitch + (feel.pitch or 0))
    if s.cute then cuteMelody(list, cfg.root or (s.pitch + (feel.pitch or 0))) end
    local pace = (feel.pace or 1) * (s.cute and lib.CUTE.pace or 1)
    for _, syl in ipairs(list) do
        if syl.pause then syl.pause = syl.pause / pace else syl.dur = syl.dur / pace end
    end
    local last
    for i = #list, 1, -1 do if not list[i].pause then last = list[i] break end end
    if not last then return end
    if last.coda then last.dur = last.dur + 0.08 end
    last.dur = last.dur + 0.1 -- the last one rings
    local vib = cfg.vibrato and
        { depth = math.min(1, cfg.vibrato.depth * 0.5), rate = math.min(1, cfg.vibrato.freq / 10) }
    s.babble = { list = list, i = 0, nextAt = love.timer.getTime(), volume = lib.VOLUME * (feel.volume or 1),
        vib = vib }
    s.saying, s.text = text, text
end

-- babble: a Mipomi sentence (lib.sentence) written as a line and said: words split into syllables, a word's
-- first syllable stressed, the feeling's mood consonant after it; `ask` makes it a question, one of three ways
-- like people do: a tag ", jo?" (you?), a tag ", la?" (good? yes?), or only the last word rising
function lib.babble(words, ask)
    local s = S()
    local feel = lib.FEEL[s.feeling or 'neutral'] or lib.FEEL.neutral
    words = words or lib.sentence(s.feeling)
    if ask == nil then ask = s.ask end
    local out = {}
    for i, w in ipairs(words) do
        local parts = {}
        for si, syl in ipairs(lib.syllables(w)) do
            local text = (syl.c or '') .. ({ a = 'a', i = 'i', o = 'o', oo = 'u', e = 'e' })[syl.v]
            parts[si] = (si == 1 and #lib.syllables(w) > 1) and text:upper() or text
        end
        out[i] = table.concat(parts, '-')
    end
    local tag = ask and ({ 'jo', 'la', false })[love.math.random(3)]
    if ask and (not tag or words[#words] == tag) then out[#out] = out[#out] .. '?' end -- the end rises
    local line = table.concat(out, ' ')
    if tag and words[#words] ~= tag then line = line .. ', ' .. tag .. '?' end
    local grunts = lib.FEEL_GRUNTS[s.feeling or 'neutral']
    local withGrunt = grunts and love.math.random() < lib.GRUNT_CHANCE
    local before = withGrunt and grunts.before and (not grunts.after or love.math.random() < 0.5)
    if withGrunt and before then
        line = '(' .. pick(grunts.before) .. ') ' .. line
    elseif withGrunt and grunts.after then
        line = line .. ' (' .. pick(grunts.after) .. ')'
    end
    if feel.ending and not (withGrunt and not before) then line = line .. '... ' .. feel.ending end
    if s.personality then line = '{personality=' .. s.personality .. '} ' .. line end -- the speaker row
    lib.speak(line)
end


local function babbleStep(s, now)
    local b = s.babble
    if b.codaAt and now >= b.codaAt then -- this syllable closes on its coda, late in it
        b.codaAt = nil
        local done = fireCoda(s, b.list[b.i].coda, now)
        b.nextAt = math.max(b.nextAt, now + done)
    end
    -- the syllable's pitch curve, every frame (a glide comes from the one before over its first 40%)
    local cur = b.cur
    if cur and s.handle then
        local t = (now - b.startAt) / cur.dur
        local pitch = cur.bend and (cur.pitch + cur.bend[1] + (cur.bend[2] - cur.bend[1]) * math.min(1, t))
            or (cur.pitch + curveAt(cur.curve, t))
        if cur.from and b.fromPitch and t < 0.4 then pitch = b.fromPitch + (pitch - b.fromPitch) * (t / 0.4) end
        local into = now - b.startAt
        if s.cute and not cur.bend and not cur.from and into < lib.CUTE.scoopTime then
            pitch = pitch - lib.CUTE.scoop * (1 - into / lib.CUTE.scoopTime)
        end
        synth.noteSet(b.took and s.takeHandle or s.handle, pitch)
        b.lastPitch = pitch
    end
    if now < b.nextAt then return end
    b.i = b.i + 1
    local syl = b.list[b.i]
    if not syl then lib.release() return end
    if syl.pause then -- between words: quiet
        if s.handle then synth.noteSet(s.handle, nil, 0) end
        takeOff(s)
        s.sounding, b.cur = false, nil
        b.nextAt = now + syl.pause
        return
    end
    local v = vowelNamed(syl.v)
    s.f1, s.f2 = v.f1, v.f2
    if s.cute then s.f1, s.f2 = v.f1 * lib.CUTE.smileF1, v.f2 * lib.CUTE.smileF2 end
    local C_ = C()
    if not C_ then s.babble = nil return end
    local volume = b.volume * (syl.vol or 1)
    b.fromPitch = b.lastPitch
    b.took = takeSyllable(s, syl, volume, now)
    if b.took then -- a person said it: no made voice, no coda (the take is the syllable)
        s.sounding, s.quietAt, b.codaAt = true, nil, nil
        b.cur, b.startAt = syl, now
        b.nextAt = now + syl.dur
        return
    end
    takeOff(s)
    if b.i == 1 or not s.handle then
        start(syl.pitch, syl.c)
        if s.handle then synth.noteSet(s.handle, nil, volume) end
    else
        synth.noteSet(s.handle, syl.pitch, volume) -- back up after a word gap or an unvoiced coda
        s.quietAt = nil
        pushSound(C_, s.handle)
        pushVowel(C_, s.handle, s.f1, s.f2)
        C_.voice_coda(s.handle, -1) -- open again from the last coda
        lib.articulate(C_, s, syl.c, now)
    end
    applyStep(C_, s, syl)
    if syl.mouth == 'closed' then s.consonantMouth, s.consonantUntil = 'M_B_P', now + syl.dur end
    if syl.cut then s.quietAt = now + syl.cut end
    s.sounding = true
    b.cur, b.startAt = syl, now
    b.nextAt = now + syl.dur
    -- a coda closes in the syllable's back part: its closing ends with the syllable
    b.codaAt = syl.coda and (b.nextAt - (CONSONANT_DUR[syl.coda] or 0.08) - 0.04) or nil
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
    -- with the vowel filter on, the chart's point is the vowel (the mouth shows what the filter makes)
    if v and (s.takeFilter or 0) <= 0 then s.f1, s.f2 = v.f1, v.f2 end
    s.sounding, s.takeUntil = true, love.timer.getTime() + seconds
end

-- The vowel filter on a bare take: LÖVE's equalizer on an effect send, its two mid bands boosted at the
-- chart point's F1 and F2, the rest and the dry path turned down by s.takeFilter (0..1): a 2-band
-- talkbox, as the choir's (there along a u-o-a-e-i line; here anywhere on the chart). The EQ's upper band
-- can't go under 1000 Hz, so the back vowels' F2 (840-870) sits a little high.
lib.FILTER_WIDTH = 0.4
local effectsOk
local function effects()
    if effectsOk == nil then
        effectsOk = false
        if love.audio then
            local ok, yes = pcall(love.audio.isEffectsSupported)
            effectsOk = ok and yes or false
        end
    end
    return effectsOk
end
local function updateFilter(s)
    local amount = s.takeFilter or 0
    if amount <= 0 or not effects() then return end
    local boost, cut = 1 + amount * 6.9, 1 - amount * 0.87 -- up to +-18 dB
    local width = 0.05 + lib.FILTER_WIDTH * 0.95
    love.audio.setEffect('voiceBoxVowel', {
        type = 'equalizer',
        lowgain = cut, lowcut = 200,
        lowmidgain = boost, lowmidfrequency = math.max(200, math.min(3000, s.f1)), lowmidbandwidth = width,
        highmidgain = boost, highmidfrequency = math.max(1000, math.min(8000, s.f2)), highmidbandwidth = width,
        highgain = cut, highcut = 4000,
    })
end
local function sendThroughFilter(s, source)
    local amount = s.takeFilter or 0
    if not source or amount <= 0 or not effects() then return end
    updateFilter(s)
    source:setFilter({ type = 'lowpass', volume = 1 - amount, highgain = 1 })
    pcall(source.setEffect, source, 'voiceBoxVowel')
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
    s.lastHow = how -- the loop plays it again
    local measured, dur = lib.takeMidi()
    local delta = (s.takeAtPitch ~= false and measured) and (s.pitch - measured) or nil
    local speed, shift = L.speed, L.shift
    if how == 'bare' then
        if delta then L.speed = delta end
        sendThroughFilter(s, voiceLab.playNow())
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
    if s.codaAt and now >= s.codaAt then -- a said syllable closes ("mi-p")
        s.codaAt = nil
        s.releaseAt = now + fireCoda(s, s.pendingCoda, now)
    end
    if s.breathUntil and now >= s.breathUntil then -- an h's puff is over: the voice as set
        s.breathUntil = nil
        local C_ = s.handle and C()
        if C_ then
            pushSound(C_, s.handle)
            if s.babble and s.babble.cur then applyStep(C_, s, s.babble.cur) end -- a grunt step's own breath
        end
    end
    if s.quietAt and now >= s.quietAt then -- an unvoiced coda: closed, so quiet
        s.quietAt = nil
        if s.handle then synth.noteSet(s.handle, nil, 0) end
    end
    if s.takeUntil and now >= s.takeUntil then
        s.takeUntil, s.sounding = nil, false
        if s.takeLoop and s.lastHow and s.lastHow ~= 'made' then s.loopAt = now + lib.LOOP_GAP end
    end
    if s.loopAt and now >= s.loopAt then
        s.loopAt = nil
        if s.takeLoop then lib.playTake(s.lastHow) end
    end
    if s.takeUntil then updateFilter(s) end -- the chart steers a take's vowel while it plays
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
    local consonant = s.consonantUntil and now < s.consonantUntil and pointsOf(s.consonantMouth)
    if consonant then shape = consonant end
    -- how far from its own mouth: the open vowels all the way, the close ones (i, oo) about half (F1);
    -- a consonant's shape all the way (an m or p shut)
    local _, openness = lib.chartXY(s.f1, s.f2)
    local amount = s.mouthOpen * (consonant and 1 or (lib.MOUTH_CLOSE + (1 - lib.MOUTH_CLOSE) * clamp01(openness)))
    local vec = {}
    for i = 1, 16 do vec[i] = rest[i] + (shape[i] - rest[i]) * amount end
    thing.pulledFaceUntil, thing.mouthTweenStart, thing.mouthLetGo = nil, nil, nil
    thing.mouthShapeVec, s.ownsMouth = vec, true
end

return lib
