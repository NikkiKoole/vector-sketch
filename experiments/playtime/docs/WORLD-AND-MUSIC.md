# The world and the music

status: active

The characters and the world play the music, and the music moves the characters and the world, both
ways through one small set of hooks, each with a setting. iMUSE's idea (MUSIC-IDEAS.md): the game fires
events, the music answers at its own **decision points** (the next beat, bar or phrase), never with a
hard cut. Started 2026-11-03 (Nikki: "lots of ways we want our characters and the world to drive the
music or vice versa; we need hooks and functions and settings for it all, and we have some of it").

## What's there already

**World → music**
- `music.bump(amount)`, the PLAY LEVEL (`M.activity`, halves every `activityHalfLife` s): impacts
  (`mipo-voice.lua`), squeaks, snaps (`snap-sound.lua`), holding / dragging / throwing (`play-level.lua`).
  The band joins at `bandJoins`; the drum jam's layers follow it (DRUM-JAM.md).
- `music.cue(style, { at, layers })` and `music.layers(preset)`: rooms (`room-music.lua`) and music
  zones (`music-zones.lua`) change the style or the arrangement, on a bar or phrase.

**Music → world**
- `music.onNote(name, fn)`: listeners told each note as it's booked. `mipo-band.lua` uses it: Mipos
  sing the 'sample' notes, a triangle makes one breathe, the rolled chord makes one doink.
- `music.chordNotes(lo, hi)`: the chord sounding now, so sound effects play in it (impact plonks,
  snap clicks). The jam's `remember` gives its chord's pentatonic.
- `music.nowPlaying()`: style, section, bar, `stepTime` / `stepLen` (the beat clock).

What's missing: the play level is one number, so the music can't tell a big hit from a lot of small
play; there's no way to ask for something AT the next beat or bar; and listeners hear every note, but
not "a bar starts", "the chord changes", "the drop".

## The shape

Two functions and a settings panel, in `src/music-events.lua` (new), registered once in `music.lua`:

- **`music.event(name, opts)`**, the world telling the music something happened: `'impact'` (with
  `strength`), `'land'`, `'found'`, `'snap'`, `'door'`, ... Each style answers in its own way at its
  own decision point: the jam with a crash or a quick fill on the next beat, a composed style with a
  stinger in its key (MUSIC-IDEAS' stingers), or nothing. The play level still gets its bump.
- **`music.on(what, fn)`**, the music telling the world: `'beat'`, `'bar'`, `'chord'` (the root and
  its kind), `'phrase'`, `'drop'`, `'kick'`. The jam already knows its changes a bar early (J9a), so
  it can tell them a bar ahead too, for a Mipo to get ready (a crouch before the drop).
- **Settings → world & music**: a row per event (how strongly the music answers: off / small / big)
  and per reaction (Mipos dance to the kick: off / on). Saved with music setups.

## Steps

- [ ] **MW1. `music.event` and the impact.** (DRUM-JAM J10e.) The event function, quantized to the
  next beat (from `nowPlaying().stepTime`), and the first answer: a hard Mipo impact (`mipo-voice.lua`,
  above a strength) gives a crash on the next beat in the jam, at most one a bar; a very hard one a
  one-beat fill. A setting row. A spec: an event at any time lands on a beat.
- [ ] **MW2. `music.on`: beat, bar, chord, drop.** The music's moments as listeners, told on the audio
  clock (as mipo-band does with notes), the jam's chord changes and drops a bar ahead.
- [ ] **MW3. Mipos move to the music.** On the kick a nod or a small bounce (mipo-actions' breathe),
  on the drop a jump, idle Mipos only. The setting row: off / on. (DRUM-JAM J5's dance.)
- [ ] **MW4. Stingers for moments.** A Mipo found, a door opened, a toy snapped in place: a short phrase
  in the key on the next beat, in the composed styles too.
- [ ] **MW5. Each Mipo a part.** A Mipo held or played with leads a layer (the one you hold plays the
  bass louder, or the tune); far from the camera, quieter. Ties into the Mipo band.
- [ ] **MW6. The world's state as music.** Not events but how things are: how many Mipos are awake,
  day or night, under water (a low-pass), up high. A room or zone names which.

Ideas to keep, not steps yet: the world's own instruments (a toy you hit plays a note of the chord,
already half there with `chordNotes`); a Mipo that hums the tune when idle; the music slowing when a
Mipo falls asleep.
