# Code complexity — splitting the hardest functions, and what turned up

status: done — 2026-11-05: no function over cyclomatic complexity 40 left (worst was 146); the bugs found on the way and the follow-up list fixed. What's left is at the bottom

Functions with a cyclomatic complexity over 40 are the hardest to change safely. Each was split into
named steps doing the same thing in the same order, and each split was checked before it went in:
a snapshot of everything it produces (`claudetools/snapshot.sh`), the music trace
(`claudetools/music-trace.lua`, 133 scenarios, must say `all identical`), or the old function loaded
from git next to the new one and both fed every input or thousands of random ones. A slip planted on
purpose proved each check catches it. Reuse between the new pieces only where the copies were
identical (body-panel's `rebuild()`, textinput's `collapseSelection`).

Check: `luacheck src/ main.lua --std "lua51+love" --max-cyclomatic-complexity 40 --formatter plain`
reports nothing (`claudetools/lint.sh --all` lists the most complex). Over 20: 89 functions, together
632 above 20 (was 1144); the top now is 38.

## The splits

| function | complexity | checked by |
|---|---|---|
| music-jam `bookBar` | 146 | music-trace (a planted volume change showed in 9) |
| meshusert-panel `draw` | 130 | snapshot `meshpanel` (new), `overlay`; old panel vs new |
| music-plan `buildPhrase` | 75 | music-trace |
| box2d-draw `drawWorld` | 72 -> 20 | snapshot `outlines` (new) |
| editor-render `renderActiveEditorThings` | 69 -> 13 | snapshot `overlay` (new, 278 states; caught an and/or slip) |
| skinning `meshusertVertices` | 68 -> 11 | snapshot `skinning` (new, 126036 lines) |
| music-parts `bookJingle` | 64 -> 13 | music-trace |
| body-panel creation accordion | 62 | snapshot `editor` |
| music-guide `buildPhrase` | 60 -> 8 | music-trace |
| Rhodes player's bar | 59 | music-trace |
| music `bookBar` | 58 -> 13 | music-trace |
| mipo-build `reconstructInstance` | 55 -> ~8 | snapshots `scenes`, `mipos`, `editor` |
| inspector `drawRow` | 50 | old vs new, every row kind |
| music-parts `lofiGroove` | 50 | music-trace |
| mipo-appearance `updateFaceOfPart` | 49 -> ~5 | old vs new over 735 value sets; `editor`, `mipos` |
| music-theory `voiceChord` | 49 | old vs new on 147600 calls |
| music-parts `play` | 48 | music-trace |
| box2d-draw-textured `createDrawables` | 45 -> 12 | `scenes`, `mipos`; old vs new on 22 made-up sfixtures |
| music-parts `bookAnswer` | 45 | music-trace |
| synth `definePatch`, `scheduleAt` | 44, 43 | music-trace `--c` (new: every call into the C library) |
| music-jam `planDrums` | 43 | music-trace |
| textinput `handleKeyPressForTextInput` | 42 | old vs new on 3000 random key sequences |
| mipo-randomize `mutateSizes` | 41 | `mipos`, `editor` |

New safety nets that stay: snapshot kinds `outlines`, `overlay`, `skinning`, `meshpanel` (MEASURING
M2), `music-trace --c`, and the editor snapshot ending a frame per click.

## Bugs found on the way, and the follow-up list

Each with a spec that failed first:

- A Mipo with a spine crashed the game in Box2D (polygon points in a line, past any pcall). Every
  polygon now goes through `shapes.newPolygon` (`polygon.dropCollinear` first); the other Box2D shapes
  were probed and give catchable errors (MEASURING M6).
- The Mipo editor's sx / sy sliders could reach scale 0 and leave a half-rebuilt Mipo; a rebuild now
  survives a part with no fixtures (MEASURING M6).
- Redrawn textures put a Mipo's texture sensors outside its never-collide group.
- The inspector's group row read a sensor's group, not the collision fixture's.
- A scene whose skinned mesh named a deleted joint or anchor didn't load; a vertex with no bone left
  came loose; a partial clone stayed bent by the original's rig (DEEPER-ISSUES 1, 6).
- Two slow leaks: ear-bend kept every rebuilt Mipo's old ear bodies, the colour cache every colour
  (DEEPER-ISSUES 8, MEASURING M4).
- Checked and already fixed before: the z-sort flicker, cloned OMP textures (DEEPER-ISSUES 1, 3).

## What's left

- [x] Nothing over 40.
- The 19 functions between 31 and 38: diminishing returns; split one when it's in the way.
- MEASURING M6's iMac run (`claudetools/snapshot.sh take a editor`, `love . --specs spec/mipo-spine_spec.lua`).
- Little-used features need using to find their bugs: `docs/LITTLE-USED.md`.
- A clone silently leaves out joints whose other body wasn't selected (DEEPER-ISSUES 6): telling the
  user, not a bug.
