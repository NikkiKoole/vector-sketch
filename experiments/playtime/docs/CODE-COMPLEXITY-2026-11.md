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

## The damaged-scene sweep

`claudetools/scene-damage_spec.lua`: every scene with one thing taken out (a body, a joint, an
sfixture, a Mipo's entry), loaded, drawn, stepped, saved, loaded again; 1257 damaged loads. First run:
nothing failed to load and no load lost bodies; two kinds of crash while drawing, both fixed with a
spec failing first:

- Mipo bodies without their Mipo entry (`characters`) in the file died in spine-skin's draw:
  `mipoRegistry.getFromBody` gave a part name with no instance; it answers 'no Mipo' now
  (spec/mipo-entry-missing_spec.lua).
- ear-bend's sweep of destroyed bodies (the leak fix above) asked bodies LÖVE had already released
  (with many worlds made one after another: specs, tools; the game keeps one world): it treats those
  as gone now. The scenes snapshot had been failing on 3 scenes since the leak fix; identical again.

Second run: clean, only `Failed to find bodies for joint` logged (a joint whose body was taken out:
skipped, as it should be). Run it again after changing load, save, or anything that follows ids.

## The editor-actions sweep

`claudetools/editor-actions_spec.lua`: every scene with one editor action done through the
inspector's own rows (body, joint and sfixture panels) or an sfixture attached from the tool rail,
then checked for the sfixtures-first order (DEEPER-ISSUES 2) and a registry holding destroyed
bodies or joints (DEEPER-ISSUES 7), drawn, stepped, saved and loaded again; 5381 actions. Neither
the order nor the registry broke anywhere. Three kinds of crash, fixed with a spec failing first:

- Older scenes saved bodies without their outline (`"vertices": false`, or none on a circle:
  catapult, planets, the snap tests, 8 scenes): resizing or flipping one died in
  `recreateThingFromBody`, and a trace-vertices strip or a snap's 'place' on one too. A body gets
  its outline on load now, made as a new body's is (spec/old-scene-no-vertices_spec.lua).
- A tile repeat dropped from the tool rail has no texture until one is picked: its first draw died
  (spec/tile-repeat-new_spec.lua).
- A texture switched to OMP before a pattern was picked: composing it died on the missing `pURL`
  (spec/omp-no-pattern_spec.lua).

Not a bug: a Mipo's limb ribbons are made again from its DNA on load, so one whose joint was
destroyed in the editor comes back without that limb's ribbon. The sweep doesn't count a Mipo's
own sfixtures when comparing the reload. Run it again after changing the panels, the rebuilds
(`recreateThingFromBody`, `recreateJoint`, flip) or the draw of an sfixture kind.

## The tool-modes sweep

`claudetools/tool-modes_spec.lua`: the editor's tool modes and drags, driven by the mouse through
`src/input-manager.lua` in every scene, whole and cut off halfway by something else (the tool's
thing destroyed or rebuilt from its panel, another tool, the tool switched off, play mode, the room
loaded again), then a next click; every frame the game's (world, overlay, panels). 3388 runs. With
a spec failing first:

- A tool stayed on after its thing was gone: adding ribbon / mesh nodes, placing an sfixture, the
  mesh triangles, Steiner points (their sfixture or body destroyed from its panel, or a door to
  another room), and the next click in the world died. Joint making kept a body destroyed or rebuilt
  after it was picked. `modes.dropWhatsGone` (src/modes.lua), before every press and move: a tool
  whose thing is gone ends, a gone pick is unpicked, corners of something gone stop being edited;
  a room load ends every tool (`modes.endAll`). DEEPER-ISSUES 4, in small: what each tool needs is
  written down in one place now (spec/tool-target-gone_spec.lua).
- A Steiner point grabbed and the tool switched off before letting go left the drag behind; the next
  Steiner tool died on a mouse move. It's let go of all the same.
- `fixtures.replaceShape` destroyed the old sfixture before making the new shape: one Box2D refused
  lost it and left the registry holding a destroyed one. Found clicking a body knutjump saved 4
  million pixels below the world. The old one stays (spec/replace-shape-fails_spec.lua).
- A body rebuilt while dragged with the world running took the drag's mouse joint for one of its
  own, logging four errors; it's left out quietly (spec/rebuild-while-dragged_spec.lua).

Only logged, as it should be: a draw tool given one point ('Not enough vertices'). Run it again
after changing input-manager, modes, a panel's tool buttons or what they rebuild. The first full
run took 4 GB: thousands of frames drawn and never ended (no `present`); it ends each frame now.

## What's left

- [x] Nothing over 40.
- The 19 functions between 31 and 38: diminishing returns; split one when it's in the way.
- knutjump has a body saved 4 million pixels below the world (fell out, then saved): worth a look.
- MEASURING M6's iMac run (`claudetools/snapshot.sh take a editor`, `love . --specs spec/mipo-spine_spec.lua`).
- Little-used features need using to find their bugs: `docs/LITTLE-USED.md`.
- A clone silently leaves out joints whose other body wasn't selected (DEEPER-ISSUES 6): telling the
  user, not a bug.
