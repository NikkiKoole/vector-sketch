# Emotions — Mipos showing how they feel with their faces

status: active

Nikki (2026-11-11): "we have faces and face parts, mouth, and even cheeks ... also i can imagine some
recoloring to become possible too, could we experiment a system where mipos show emotion with their faces".
Scene `emotions` (`scripts/spikes/emotions.playtime.lua`), the system in `src/mipo-emotion.lua` (in scene
scripts as `mipoEmotion`).

Before it: the face could already blink, look, move its brows and tween its mouth (FACE-SYSTEM-PLAN, done;
`src/mipo-face.lua`), and a click near a face pulled a random one for 2 s. An archived video note
(`docs/notes/archive/emotional-beings.md`) sketched mood and tension, then valence / arousal / dominance;
dreamengine's peteyes keeps an eye's shape (who it is) apart from the emotion levers (HARVEST-NAVKIT-DREAMENGINE).

## What's built (2026-11-11)

- **Levers** on the face, which the renderer reads off the face owner's thing: brows (how high; their bend,
  outer end / middle / inner end), the mouth (a mix of `src/mouth-shapes.lua` shapes over the Mipo's own; a
  share over 1 exaggerates, the frown alone is mild), how open the eyes are (`eyeScale`, the pupil clipped
  to the narrower eye), the pupils' size (`pupilScale`), a blush (`blush`: soft discs below and outside the
  eyes, drawn before the nose).
- **Seven feelings** as lever sets: happy, sad, angry, scared, surprised, sleepy, shy (`lib.EMOTIONS`, data
  to tune). A Mipo holds a few with weights that glide in (0.25 s) and out (0.7 s); the levers are the mix
  over neutral, so two feelings blend, never snap. `mipoEmotion.set(inst, name, amount, hold, mix)`.
- **The scene**: four Mipos at 0.6 scale, a panel: a button per feeling, how strongly, every Mipo or the one
  last touched, mix in or instead. e: random feelings, n: neutral, h: the panel.

Seen on the contact sheets: happy, scared, surprised, sleepy, shy read at once; sad and angry after the
mouth was let go past the frown. The brows move as meant but are thin and often hidden (hair, a big nose).

## Next

- [ ] **EMO1. Nikki plays with it**: which feelings read, which need more (the numbers are `lib.EMOTIONS`).
- [ ] **EMO2. Feelings from play**: picked up (surprised, then happy while held), thrown hard (scared),
  a hard landing (sad, dizzy), left alone a long while (sleepy), another Mipo near (shy or happy). The voice
  already has `mipo:squeak(emotion)` (PUPPETMAKER-SOUND V3): the same feeling for both.
- [ ] **EMO3. Recolouring**: the face flushing red (angry, shy) or going pale (scared), a tint on the head's
  skin rather than the cheeks alone.
- [ ] **EMO4. Brows that read**: thicker or darker while feeling something, or above the hair.
- [ ] **EMO5. Into the engine**: `mipoEmotion.update` as a system (`src/systems.lua`) so every scene's Mipos
  feel, and the pulled face on a click (mipo-face) as a short surprised instead of random.
