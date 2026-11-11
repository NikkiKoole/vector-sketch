# Voice box — a Mipo voice made from scratch: vowels, consonants, who's talking

status: active — VB0 and VB3's first part built 2026-11-11, Nikki to listen (VB1)

Nikki (2026-11-11): "i kinda feel like another voice spike ... i also want to figure out more with: all sorts
of vowels crossing visually and audible, the other settings how we can adjust these sounds to make them more
mipo and less just recorded people, and some consonants".

Where the voices stand: the Mipos speak and sing with recorded takes (Theo, Herman, Nikki, the Puppetmaker
takes: `src/mipo-voice.lua`, the choir spike `docs/CHOIR.md`, tuned per syllable; WORLD re-tuning and morphs
offline, liked), and the voice lab (`src/voice-lab.lua`) tries a take's speed, shift and size on the synth.
A take is always a person. This spike tries the other end: a voice with no recording in it.

## VB0. The spike (built 2026-11-11)

Scene `voicebox` (`./playtime.sh play voicebox`), engine `src/voice-box.lua` (`voiceBox` in scene scripts).
dreamengine's formant voice, `INSTR_VOICE` (24; navkit's VoicForm: a glottal pulse through four vowel
formants, measured Peterson-Barney tables), already in our libdesound with all its levers, but never used
in Playtime. A shared pool slot (patch `voiceBox`, added to `synth.patches` at run time).

- **The vowel chart**: F1 (how open) down, F2 (how front) across, log scale, the vowels at their measured
  places (i e ae a uh er o oo). Press and drag: a held note, the vowel moving under the finger, any point
  between the vowels (the engine's AH formants scaled to the point's F1/F2: its open/front levers,
  note_aux 8/9). The Mipo's mouth follows: each vowel has a mouth shape (`lib.VOWELS`), a point blends them
  by nearness (smooth, never a pick), and close vowels open the mouth less (`lib.MOUTH_CLOSE` 0.4).
- **Who's talking**: pitch, size (throat: giant .. tiny), effort (soft breathy .. bright pressed: breath,
  glottal open quotient and tilt together, as dreamengine's voxpad), nasal, buzz (smooth .. buzzy),
  jitter / shimmer / creak (roughness), vibrato and its speed. Presets mipo, tiny, big, hum, plain.
- **Consonants**: 22 buttons (b d g m n l s sh ng r w y dh f v z zh th p t k ch), each says itself with the
  current vowel (`voice_consonant`, a timed onset into the vowel); the mouth shows its shape for 80 ms (m b p
  closed, f v, th l, rounded w sh). "chart: consonant first" makes the chart's notes start with the last one.
- **Babble** (b): 3-6 mipomi syllables (m p b l n d + i o a oo e) on one held note, re-articulated, a falling
  tune with a lift and a held last syllable.

Checked in a test window: notes start and stop, babble steps through, consonants ring out; contact sheet of
the eight vowel mouths. **Not heard by me**: how it sounds is VB1.

## Steps

- [ ] **VB1. Nikki listens** (2026-11-11: "sounds ok lets continue"): does a made voice sound like a Mipo, or like a robot? Which preset, which
  levers matter (the "more Mipo, less recorded people" question from this side).
- [ ] **VB2. The mouths**: do the vowel mouths read, does the crossing look right; the shapes per vowel in
  `lib.VOWELS`.
- [ ] **VB3. Recorded takes made more Mipo**: the same question from the other side. The takes through what
  this spike has: their size (INSTR_SING, `sample_formant`), a vowel filter (the choir's EFX talkbox), a
  blend of a take and the made voice. A/B in the same panel.
  **First part built 2026-11-11** (Nikki: "can we still get the bare samples with some settings?"): the left
  panel, 'recorded take': the voice lab's sets and takes (theo, herman, nikki, pm) and its sliders (speed,
  shift, size, inflection: the same `state.voiceLab`), played four ways on one note: **bare** (the take through
  LÖVE, its rate taking it to the voice box pitch: pitch and length together, as the choir), **synth** (shifted
  to the pitch in whole semitones, length kept, size baked in), **sing** (INSTR_SING at the pitch, size as its
  throat), **made** (the same syllable on the made voice: 'ba' -> b + a). At the pitch only when the take is
  measured (`src/voice-pitch-data.lua`: theo, herman, nikki; not the Puppetmaker takes, which use the lab's
  speed/shift as set). The Mipo's mouth says the take's vowel for its length.
  **Vowel filter on takes, 2026-11-11** (after Nikki's "sounds ok lets continue"): on a bare take, LÖVE's
  equalizer boosts the chart point's F1 and F2 and turns the rest and the dry path down (the choir's 2-band
  talkbox, here at any chart point; 'vowel filter' 0..1). 'loop it' repeats the take, and then the chart
  only steers the filter (no made note): drag across and the take's vowel moves, the mouth with it.
  Checked in a test window: effects supported, the EQ follows the chart, the loop repeats. Bare only (the
  synth's own formant filter, `instrument_formant`, would take an FX bus for good: there are 7 and the music
  shares 5). Not yet: a blend of take and made voice.
- [ ] **VB4. More consonants**: endings (`voice_coda`: "mip", "pom"), two in a row, consonants in the babble
  chosen by the mipomi language (`~/Projects/love/mipomi-lang`).
  **Codas, 2026-11-11** (Nikki: "lets do the codas, mip and pom"): `voiceBox.say(onset, coda)` and
  `voiceBox.word('m', 'i', 'p')`: 0.2 s of vowel, then `voice_coda` closes it over the consonant's own length
  (the engine's table). The engine keeps the voice on through a coda, so an unvoiced one (p t k s) turns the
  note's volume down once closed ("mi-p" stops), a voiced one (m n ng l) hums on 0.1 s ("po-m"). The mouth
  goes to the consonant's shape fully (an m or p shut) until the end. Panel: an 'ends on' row (- m n ng l p
  t k s; the consonant buttons use it) and mip / pom / min / pong. Babble: the last syllable closes 60% of
  the time, the others 15% (m p n ng); the next syllable opens again (`voice_coda(-1)`, volume back).
  Checked in a test window: timing and mouth state right, no errors; not heard. Still open here: two
  consonants in a row, consonants chosen by mipomi-lang.
  **Mipomi, h, feelings, 2026-11-11** (Nikki: "yes do 1 to 3"): babble now says Mipomi sentences
  (`lib.MIPOMI`, `lib.sentence`): CV syllables, vowels a i o only, subject + aspect vowel (i is, a becomes,
  o does) + a word; first syllable of a word stressed, falling to the end, a short quiet between words. 'h'
  (not one of the engine's 22) is a breath puff (`lib.H_PUFF`); 'j' is the engine's y (the Dutch j). The
  scene's feeling row (neutral … shy) sets the Mipo's face (src/mipo-emotion.lua), what it says ("mi i
  mola"), a voice tint (`lib.FEEL`: pitch, pace, effort, volume) and the mood consonant it ends on, from
  Mipomi's paragrammar: happy m, sad h (a sigh: breathy fade), angry f, scared p, surprised h, sleepy m,
  shy b. Endings row gains f b d h. Notes and the dictionary's open questions written to mipomi-lang
  `VOICE-NOTES.md`. Checked in a test window: sentences, word gaps, the h puff and sigh, no errors; not heard.
  **From the core, 2026-11-11** (Nikki: "y"): the words come from mipomi-lang's word list now
  (`words.tsv`, its core of 57 in 7 groups), exported to `src/mipomi-words.lua` by mipomi-lang's
  `lua export.lua <path>` (refuses a list `check.lua` finds errors in). A sentence: a pronoun or thing + i
  (feeling, quality, where) / a (where, feeling) / o (play, voice, + a thing after give, take, eat, catch,
  push, pull, build, look); 15% a word on its own (mipo, la, na, pomo, mipa).
  **Questions and the talking heads' notation, 2026-11-11** (Nikki: "i also feel we want ways of a
  question? where pitch is going up or the other things we have in talking head demo?"; the vowel filter
  on the made voice: not needed, it already makes its vowels): `voiceBox.speak(line)` says a line in
  mipomi-lang's notation (`lib.parse`): `{root= swing= stress= rndp= vibrato= intonation= personality=}`,
  `-` syllables, `,` pause, `?word`/`word?` rise, `_` fall, CAPITALS stressed, `~` glide, `[c4]` note,
  `<0.5>` volume, a lone consonant closes the word before it. Each syllable follows the talking heads'
  pitch curve (neutral, emphasis, rise, fall and the emphasis mixes) every frame; a statement falls 2
  semitones over its length, a question doesn't. The 7 personalities (robotic … deadpan) as speakers.
  Babble writes its sentence as such a line and says it (a word's first syllable in capitals, the mood
  consonant after it; with 'ask?' on, one of three at random: ', jo?', ', la?' or just the last word rising:
  Nikki: "sometimes jo? sometimes la, sometimes nothing just ?"). Panel: the line in a text field (edit it, return or 'say'),
  the speaker row, 'ask?'. Checked in a test window: parsing, a babble with party + ask, no errors; not heard.
  **Soft, 2026-11-11** (Nikki: "some of the glyphs click a flip and do weird, F for example"): the engine
  gates the voice off at once for a voiceless consonant (sound.h: `gl_gain` 0 until 55% of it), so p t k
  click and f s click with a gap, worst mid-sentence. 'soft' says each as its voiced twin (`lib.SOFT`: p b,
  t d, k g, f v, s z, sh zh, th dh, ch zh), as small children do; codas too. Not yet: the engine fix (fade
  the gate ~5 ms, glide the formants at a re-articulation) in dreamengine, if f and s should stay sharp.
- [ ] **VB7. Grunts, tsks and the rest on the made voice** (Nikki 2026-11-11: "we need ways to make all the
  grunts and tssk and stuff IN the voicebox voice too"): the talking heads' fx (mipomi-lang samples-fx: hum
  up/down, huh, tsk, blah) and Puppetmaker's hmpfs/squeaks made, not played: `(humup)` etc. in a line.
- [ ] **VB5. Singing**: the choir's tunes on the made voice: any note exactly, no takes, no tuning tables;
  the singer model (breath, scoop, vibrato) as its levers.
- [ ] **VB6. A voice per Mipo**, if kept: size from the body, a pitch and a preset in the DNA (PUPPETMAKER-SOUND
  P6 / V5), and its mouth flaps from the voice instead of random shapes.
