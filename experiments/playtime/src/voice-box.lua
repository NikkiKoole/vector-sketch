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
    aux(C_, handle, VP.size, s.size)
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
function lib.articulate(C_, s, consonant, now)
    if consonant == 'j' then consonant = 'y' end
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

function lib.release()
    local s = S()
    if s.handle then synth.noteOff(s.handle) end
    s.handle, s.sounding, s.babble, s.codaAt = nil, false, nil, nil
end

-- close the held note on a consonant now; returns how long until it's closed and done.
-- 'h' closes on a sigh: the voice goes breathy and fades (lib.SIGH s)
lib.SIGH = 0.3
local function fireCoda(s, coda, now)
    local C_ = s.handle and C()
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
lib.MIPOMI = {
    subjects = { 'mi', 'jo', 'bo', 'bi', 'ba', 'koka', 'wobo' }, -- I, you, creature, friend, child, box, ball
    i = { 'lala', 'mola', 'lili', 'doka', 'koti', 'koto', 'wala', 'kola', 'lali', 'momo', 'koko', 'foko' },
    a = { 'koto', 'koti', 'foko', 'fiko', 'kofo', 'koko', 'mola' },
    o = { 'hafa', 'hihi', 'soso', 'fowo', 'paki', 'faha', 'pifo', 'jaja', 'jojo', 'mowa', 'pahi', 'di' },
    objects = { 'wobo', 'koka', 'wawa', 'jiki' }, -- after an o-verb now and then (ball, box, water, book)
}
-- per feeling: what it says, how it sounds, the mood consonant it ends on (Mipomi's paragrammar: m comfort,
-- p tension, h sigh / awe, f frustration, b affectionate aww; nil: no ending). pitch in semitones, pace x
lib.FEEL = {
    neutral   = { pitch = 0, pace = 1, effort = 0 },
    happy     = { pitch = 2, pace = 1.1, effort = 0.1, ending = 'm',
                  says = { { 'mi', 'i', 'mola' }, { 'mi', 'i', 'lala' }, { 'mi', 'o', 'mowa' }, { 'momo' } } },
    sad       = { pitch = -3, pace = 0.8, effort = -0.15, ending = 'h',
                  says = { { 'mi', 'i', 'mino' }, { 'mi', 'o', 'miso' }, { 'mino', 'mino' } } },
    angry     = { pitch = -1, pace = 1.15, effort = 0.3, ending = 'f',
                  says = { { 'mi', 'i', 'faho' }, { 'mi', 'o', 'jaho' }, { 'no', 'no' }, { 'lana' } } },
    scared    = { pitch = 4, pace = 1.3, effort = 0, ending = 'p',
                  says = { { 'mi', 'i', 'fowa' }, { 'mi', 'a', 'fowa' }, { 'nako' } } },
    surprised = { pitch = 3, pace = 1, effort = 0.15, ending = 'h',
                  says = { { 'moja' }, { 'mi', 'i', 'moja' }, { 'jo', 'i', 'moja' } } },
    sleepy    = { pitch = -4, pace = 0.7, effort = -0.25, ending = 'm',
                  says = { { 'mi', 'i', 'nini' }, { 'mi', 'a', 'nisa' }, { 'nini' } } },
    shy       = { pitch = 1, pace = 0.9, effort = -0.2, volume = 0.7, ending = 'b',
                  says = { { 'mi', 'i', 'misofo' }, { 'mi', 'i', 'lili' } } },
}
lib.STRESS = 1.5        -- semitones up on a word's first syllable (and a little longer)
lib.WORD_GAP = 0.07     -- seconds of quiet between words
lib.SYLLABLE_TIME = 0.17 -- seconds a syllable takes (at pace 1)
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
    local aspect = pick({ 'i', 'a', 'o' })
    local words = { pick(M.subjects), aspect, pick(M[aspect]) }
    if aspect == 'o' and love.math.random() < 0.4 then words[#words + 1] = pick(M.objects) end
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

-- babble: a Mipomi sentence on one held note, its syllables re-articulated (connected), a short quiet between
-- words, the first syllable of each word stressed, falling to the end, closing on the feeling's consonant
function lib.babble(words)
    local s = S()
    local feel = lib.FEEL[s.feeling or 'neutral'] or lib.FEEL.neutral
    words = words or lib.sentence(s.feeling)
    local pace = feel.pace or 1
    local list = {}
    local pitch = s.pitch + (feel.pitch or 0)
    local total = 0
    for _, w in ipairs(words) do total = total + #lib.syllables(w) end
    local n = 0
    for wi, w in ipairs(words) do
        if wi > 1 then list[#list + 1] = { pause = lib.WORD_GAP / pace } end
        for si, syl in ipairs(lib.syllables(w)) do
            n = n + 1
            local stressed = si == 1 and #lib.syllables(w) > 1
            syl.pitch = pitch - 2.5 * (n - 1) / math.max(1, total - 1) + (stressed and lib.STRESS or 0)
                + (love.math.random() - 0.5) * 0.6
            syl.dur = lib.SYLLABLE_TIME * (stressed and 1.2 or 1) * (0.9 + love.math.random() * 0.2) / pace
            list[#list + 1] = syl
        end
    end
    local last = list[#list]
    if last and feel.ending then
        last.coda = feel.ending
        last.dur = last.dur + 0.08
    end
    if last then last.dur = last.dur + 0.1 end -- the last one rings
    s.babble = { list = list, i = 0, nextAt = love.timer.getTime(), words = words,
        volume = lib.VOLUME * (feel.volume or 1) }
    s.saying = table.concat(words, ' ') .. (feel.ending and ('... ' .. feel.ending) or '')
end

local function babbleStep(s, now)
    local b = s.babble
    if b.codaAt and now >= b.codaAt then -- this syllable closes on its coda, late in it
        b.codaAt = nil
        local done = fireCoda(s, b.list[b.i].coda, now)
        b.nextAt = math.max(b.nextAt, now + done)
    end
    if now < b.nextAt then return end
    b.i = b.i + 1
    local syl = b.list[b.i]
    if not syl then lib.release() return end
    if syl.pause then -- between words: quiet
        if s.handle then synth.noteSet(s.handle, nil, 0) end
        s.sounding = false
        b.nextAt = now + syl.pause
        return
    end
    local v = vowelNamed(syl.v)
    s.f1, s.f2 = v.f1, v.f2
    local C_ = C()
    if not C_ then s.babble = nil return end
    if b.i == 1 or not s.handle then
        start(syl.pitch, syl.c)
        if s.handle then synth.noteSet(s.handle, nil, b.volume) end
    else
        synth.noteSet(s.handle, syl.pitch, b.volume) -- back up after a word gap or an unvoiced coda
        s.quietAt = nil
        pushSound(C_, s.handle)
        pushVowel(C_, s.handle, s.f1, s.f2)
        C_.voice_coda(s.handle, -1) -- open again from the last coda
        lib.articulate(C_, s, syl.c, now)
    end
    s.sounding = true
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
        if C_ then pushSound(C_, s.handle) end
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
