# Stingers: the music answering a moment

status: idea

A stinger is a short musical phrase played over the music when something happens: a Mipo found, a door opened, a toy snapped in place. This is MW4 in WORLD-AND-MUSIC.md. Research first (Nikki 2026-11-03: "sounds interesting, also something we need to research a bit beforehand"), nothing built yet.

## How others do it

- **Wwise** (the usual game-audio middleware). A stinger is a short segment laid over the playing music. Each one has a sync rule: immediately, the next grid step, beat, bar or a marker in the music. Its **pickup** is lined up so that its downbeat, not its first note, lands on the boundary. Repeats are a known problem: one voice per stinger, a new one cuts the old. Timing has to stay on the music's own clock; a callback round trip through game code drifts. ([Audiokinetic Q&A](https://blog.audiokinetic.com/qa/3570/trying-wwise-metronome-synchronize-gameplay-mechanics-unity), [stingers dropped at fast grids](https://audiokinetic.com/qa/11580/stinger-could-scheduled-segment-dropped-triggering-notes), [stop/retrigger](https://audiokinetic.com/qa/5339/trigger-sounds-on-sync-with-the-music), [quantized triggers in Unreal](https://bugnet.io/blog/how-to-fix-unreal-metasound-quantized-trigger-not-on-beat))
- **iMUSE** (Monkey Island 2, Land and McConnell). The music changes at **decision points** in the score, never with a hard cut. Its short stingers came in about **20 variations each**, so a repeated moment didn't sound the same. ([iMUSE](https://en.wikipedia.org/wiki/IMUSE), [Jesse Harlin interview](https://www.audiogang.org/interview-with-lucasarts-jesse-harlin/))
- **Mario Galaxy / Odyssey**:
  - Galaxy synced some sound effects to the music's MIDI clock; the Sling Star launch plays harp in the music.
  - The series takes an effect's notes from the music's key, so it never clashes.
  - In Odyssey, riding a power line changes its tune when the music changes.
  - Kawamura kept the musical effects to **Mario's own actions**.
  ([Iwata Asks: Galaxy sound](https://iwataasks.nintendo.com/interviews/wii/super_mario_galaxy/2/0), [Musical SFX in Mario](https://medium.com/game-audio-lookout/musical-sound-effects-in-the-super-mario-series-b14872fb2d94), [Odyssey's harmonizing effects](https://creators.vice.com/en/article/xwvyan/the-tiny-touches-of-super-mario-odyssey-extend-to-even-the-sound-effects-harmonize-music-easter-egg))
- **Tetris Effect / Rez**: every move is a musical sound, quantized to the music, with each stage giving its own cue per action. Reviews also note the link can get lost when it isn't obvious. ([Tetris Effect team](https://www.meta.com/blog/a-chat-with-the-team-behind-vr-puzzler-tetris-effect/), [review](https://www.fandom.com/articles/tetris-effect-review))
- **Preschool sound** ([Game Developer](https://gamedeveloper.com/audio/re-imagining-the-sound-of-pre-school-games); Sago Mini Sound Box's instant feedback):
  - While a child plays, the sounds of their own actions are the lead; the music steps back.
  - No wall-to-wall music.
  - Repeated triggers are the main fatigue: a sound tapped ten times.
  - Mix for a tiny mono speaker.

## What it means here

The rules that come out of it:
- **When:** the next beat (or 8th), on the music's own clock, never a hard cut.
- **What notes:** from the chord sounding then. In wave that's the local chord, since it changes key every two bars.
- **How often:** variations plus a limit (at most one a bar, quieter when repeated).
- **Restraint:** a stinger for a moment that matters. A touch stays an immediate sound effect.

What Playtime already has for it:
- `events.answer(style, fn(name, opts, ctx))`: `ctx.beatAt` is the next beat, at least 60 ms ahead, so it can still be booked. `ctx.play` books a note on the music's clock (no drift).
- `music.chordNotes(lo, hi)`: the chord booked at that moment. It follows wave's key moves and the jam's walks.
- `music.bandInstruments(part)` (MW7): the patches the song's parts are playing, so a stinger can sound like the band.
- `music.event(name, opts)`: the game sends one. Only 'impact' exists so far; 'found', 'door' and 'snap' still have to be sent from the game.
- `music.on('bar'|'chord', ...)`: the world can be told when the stinger lands, so a Mipo can react on it.

## Questions for Nikki (decide before building)

1. **Which moments?** Found, door, snap, others (a Mipo waking, a toy finished)? Two or three, not ten.
2. **Whose voice?** Either the song's own instrument for the tune (it blends; MW7's way) or one fixed **Mipo voice**, a glockenspiel or bells, the same in every style. A fixed voice makes the moment recognisable everywhere, like Mario's coin.
3. **A motif or a figure?** A short leitmotif per moment (found = a rising 3-note call), re-harmonized into each chord, or a free chord-tone figure (an arpeggio up, a sparkle).
4. **How long?** 3-5 notes over one beat, or a whole bar. Short keeps it out of the way (feedback_background_music).
5. **Does the music make room?** The tune rests that bar, or plays on underneath.

## Nikki so far (2026-11-03)

Keep the options open and get the feel by playing, alone and with the kids. Liked: the ball borrowing the song's bass (MW7), so the band's own instruments are the favourite for now. A guess: when a stinger plays on a part's instrument, that part of the song rests for a moment.

**Making a part rest.** Each bar's notes are booked on the synth up to a bar ahead (`schedule_at`, 0.3 s before the bar), and booked notes can't be taken back. The stinger itself still lands on the next beat; only the rest is the problem. The ways round it:
- **Duck** the part's slot (`instrument_level`, instant, from update at the stinger's beat) and play the stinger on a twin of the patch, on its own slot. Works today. The ducked notes still sound quietly and use voices.
- **Unschedule** in the engine: `unschedule(slot, t1, t2)` drops a slot's booked notes in a window. dreamengine-4d: easy, about 30 lines (the `delayed[]` array in runtime/sound.h, a new SR_ event kind, the four-place API add, a schedule-check assertion), then bound in desound.c. Notes already sounding keep ringing, so pair it with a choke. Exact to the sample, and it frees the voices. **Nikki chose this one (2026-11-03).** Built 2026-11-03: dreamengine 837f0d54 has `unschedule(slot, t1, t2)` (gate: its schedule-check unschedcheck). libdesound is rebuilt (`bash native/desound/build.sh`, no desound.c change), and `synth.unschedule(patch, t1, t2)` is in src/synth.lua (optional; false without it). Notes already ringing: `instrument_choke(stingerSlot, partSlot)`, declared once, makes the stinger's first note cut them (a 3 ms fade). Caveats:
  - A shared pool slot handed to another patch inside the window loses that patch's notes too.
  - The web build exports only synth.lua's CDEF and has no FFI path for it, so there's no unschedule on the web, the same as schedule_note_at today.
- Booking a beat at a time instead of a bar would also work, but it changes how every part books. Not worth it.

## The world's events (sent since 2026-11-03)

`music.event(name, opts)` from the game. Nothing answers them yet except the jam's impacts. The panel's music section shows a tally (`events: grab 12 snap 3 ...`, `state.music.eventLog`), to see how often each happens while playing:

| event | where | opts |
|---|---|---|
| impact | mipo-voice (MW1) | strength |
| grab | play-level: the pointer takes something | |
| throw / drop | play-level: letting go, hard or soft (`throwEvent` 0.35 of throwSpeed) | strength |
| snap | snap-sound: a snap joint formed | |
| door | doors: tapped, or a Mipo dropped on it | how = tap / mipo, to |
| room | doors: arrived through a door | from, to |
| signal | signals.emit: a button, plate or socket | signal |
| daze / wake | mipo-actions: a hard hit knocks a Mipo limp, it gets up | strength (daze) |
| jump | mipo-actions.jump | |

## Steps (when it's decided)

- [ ] **S1. One stinger, one event.** 'found' or 'snap' sent from the game. A composed-style answerer (`events.answer` for every non-loop style), a 3-note figure from `chordNotes` on `ctx.beatAt`, at most one a bar. A panel row: off / small / big.
- [ ] **S2. Hear it offline.** render-music/music-when with events at given seconds (e.g. `EVENTS=20:found,31:found`), to check the timing and the notes in wave and bossa.
- [ ] **S3. Variations and fatigue.** Several shapes per moment, picked without repeats; quieter on a repeat within a few seconds.
- [ ] **S4. The other moments**, and the jam answering them the same way (playtime-71's answerer).
