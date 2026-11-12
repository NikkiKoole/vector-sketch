# Emotions — Mipos showing how they feel with their faces

status: active — in the engine since 2026-11-12 (EMO5); EMO2 open: other Mipos near, the voice; the feelings button in the selection bar next

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

- Feelings on a pad (2026-11-12, BESPOKE-UI.md BU2): a mood map at the top of the panel, drag to blend.
- [x] **EMO1. Nikki plays with it**: which feelings read, which need more (the numbers are `lib.EMOTIONS`).
  Kept 2026-11-12 (Nikki: "yeah they work as is").
- [ ] **EMO2. Feelings from play**: picked up (surprised, then happy while held), thrown hard (scared),
  a hard landing (sad, dizzy), left alone a long while (sleepy), another Mipo near (shy or happy). The voice
  already has `mipo:squeak(emotion)` (PUPPETMAKER-SOUND V3): the same feeling for both.
  **Built 2026-11-11, Nikki to try** (`mipoEmotion.update(dt, true)`; the scene's 'feel what happens'): watched
  each frame, nothing hooked in elsewhere: held (box2d-pointerjoints) -> surprised 0.5 s, then happy 0.8;
  let go faster than 900 (at 100 px/m) -> scared 1.4 s, else happy 0.6 for 1.5 s; dazed (mipo-actions'
  hard-hit daze) -> sad, and a moment after; still (torso speed averaged over ~1 s under 60: a standing Mipo
  breathes at 2-60) for 12 s with nothing to feel -> sleepy, woken by a move with a little surprise. All in
  `lib.REACT`. Checked from the bridge in a test window: each fires. Not yet: another Mipo near, the voice.
- [x] **EMO3. Recolouring**: the face flushing red (angry, shy) or going pale (scared), a tint on the head's
  skin rather than the cheeks alone.
  **Built 2026-11-11, Nikki to try**: each feeling's `flush` = { r, g, b, how strongly }: angry red 0.45,
  shy pink 0.3, scared pale 0.4, sad a little blue 0.18, happy warm 0.12; mixed by weight like the rest. A
  wide soft wash centred a little under the eyes, clipped to the head's skin (`box2d-draw-textured`
  `drawInsideSkin`, the face patches' `clipToSkin`), drawn just before the left eye with the blush, so it
  lies under the eyes, brows, nose, mouth and the head's hair strokes (first under the nose: it tinted the
  eyes). A head without a masked skin gets none.
- [x] **EMO4. Brows that read**: thicker or darker while feeling something, or above the hair.
  Built 2026-11-11, Nikki to try (Nikki: "lets make the eye brows more prominent"). Why they were lost:
  their colour is random per Mipo and often the head's own (magenta brows in magenta head strokes,
  lavender on lavender skin), and they were thin. Now, at draw time for every Mipo (`box2d-draw-textured`
  `lib.browThick` 1.8, `lib.browWide` 1.15, `lib.browDark` 0.6 = that far towards black), and a feeling
  makes them thicker still: `brow` in each feeling's row (angry 1.45, sad/scared/surprised 1.2, sleepy
  0.85), in twentieths so the strip is rebuilt only a few times a glide.
- [x] **EMO5. Into the engine**: `mipoEmotion.update` as a system (`src/systems.lua`) so every scene's Mipos
  feel, and the pulled face on a click (mipo-face) as a short surprised instead of random.
  Done 2026-11-12: the 'feelings' system; feeling what happens is on in every scene, off per scene in the
  settings panel's 'mipos' section ('feel what happens', saved as `feelings` in the scene file). A click
  near a face: surprised 0.6 s when it's on, the old random face when off. While the voice flaps the mouth
  (`mipoVoice.isFlapping`), a feeling leaves the mouth alone. The emotions and voicebox scenes no longer
  call `update` themselves (voicebox turns the reactions off). Scenes smoke: 88 pass.
