# Editor: inspector + library (plan, 2026-10-27)

Goal: a tighter editor, Flash-style. One **inspector** that is shallow by default and
deep on demand, and a **library** you drag things from. The editor keeps doing
everything it does now. Code stays in files (scene scripts, props, behaviors); the
editor only shows what the code exposes.

Today: ~7,800 lines of UI across `src/playtime-ui.lua` and `src/ui/` (sfixture-editor
2,349, mipo-editor 1,931). Most of it is hand-placed (`ui.textinput(..., 340, 145, ...)`).

## Risk rules

- **No rewrite.** New things live *next to* the old panels; old panels keep working
  until a new one has replaced them and felt better. Any slice can be the last one.
- **Each slice: max 1 week of work, ends usable**, with a "keep / drop" moment.
- **The next app wins.** If an app needs something, editor work pauses. Editor work
  is fine when it makes the next contraption or Mipo cheaper, not as a project of its own.
- **Kill criteria (pre-approved, no debate):** if a slice doesn't feel better than the old
  panel after one play session, revert it and stop. Slices 1 and 4 are the checks.

## Slices

1. **Schema for behaviors (inspector v0).** Each behavior in `src/behaviors.lua`
   declares its params: `{ key, kind = 'text'|'number'|'bool'|'choice', min, max,
   default, advanced = true? }`. One generic `drawParams(thing, behavior)` draws them
   with the layout helpers. Convert only the SIGNAL_* behaviors (the hand-placed ones
   from today). Check: is it nicer than the old panel? Keep or revert.
2. **Basic / advanced fold.** Basic params show; an arrow shows the advanced ones.
   Apply the schema to one more area (joint settings, ~380 lines) next to the old one.
3. **Library v0, no new UI.** "Save selection as prefab" → `library/<name>.playtime.json`
   (reuses clone + save in `src/io.lua`). Prefabs show up as buttons in the existing
   toys list; click places a copy at the camera centre. Props stay code; prefabs are data.
4. **Use it for real.** Build the next contraption with the library + inspector only.
   Check: did it go faster than today's slide/gate/button? If not: stop here.
5. **Later, only if 4 was a yes:** library thumbnails + drag to the stage; the inspector
   replaces the old panel per area (sfixtures and the Mipo editor last, they're big).

## Not doing (considered, said no)

- Timeline, onion skinning (said no 2026-10-27).
- Code editing inside the editor: code stays in files.
- Rewriting all panels in one go, or a new UI framework/library.
- Nested prefabs / linked instances (edit one, all update): too deep for now.
- Comic Shanns (compact, 16px) as the editor font: tried live, said no 2026-10-27; Arial Narrow stays.
- Wire tool (drag trigger → receiver): nice, but third in line; revisit after slice 4.

## Status

- **Slice 1 built (2026-10-27)**: `src/ui/inspector.lua` (`drawParams`), `params` on
  KEEP_ANGLE, SIGNAL_BUTTON/PLATE/SOCKET/GATE and SQUISHY in `src/behaviors.lua`,
  `spec/behaviors_spec.lua` checks the rows. The behavior panel has an `old`/`new` button
  (top right) to compare with the hand-made panels, which are still there.
  Side effects: KEEP_ANGLE's old `speed` slider is gone (nothing read it), it now shows
  `enabled`, plus `strength` (kp) and `max spin` behind '+ more'; the old KEEP_ANGLE
  'remove' wiped *all* behaviors of the body, the new one removes just that one.

- **Slice 2 built (2026-10-27)**: joints. `src/joint-params.lua` lists every joint type's
  settings as get/set rows (a set that rebuilds the joint returns the new one; `visible`
  hides limit/motor sliders while off). `src/ui/joint-update.lua` uses it, with the same
  old/new button. Collide, max force/torque and axis sit behind '+ more'.
- **Body panel (2026-10-27)**: `src/body-params.lua`: type, label, size (per shape; rebuilds
  the body), density/bounce/friction, flip x/y; '+ more': fixed angle, angle, x, y, sensor,
  group, damping, sleep ok, bullet, spin. Behaviors/joints/sfixtures lists and the polygon
  tools stay custom in `src/ui/body-editor.lua`. Density now resets the mass at once (the old
  slider only took effect after a rebuild). New inspector kind `numberText` (field only).
- **UI regression specs**: `spec/inspector_spec.lua` — per joint type, every setting is set
  and read back on a real joint (caught a planted degrees/radians bug), and every panel
  (new with all rows open, and old) draws without errors; every behavior panel too.
  Not yet: clicking. The UI reads `love.mouse` directly, so neither specs nor the bridge's
  `/input/click` can press a button; a fake-pointer hook in `ui.startFrame` would fix both.

- **Kept (2026-10-27)**: Nikki liked the behavior, joint and body panels; the old
  hand-made code and the old/new buttons are deleted (`src/ui/joint-update.lua` 380 -> 28
  lines, `src/ui/body-editor.lua` 658 -> ~290, the SIGNAL_*/KEEP_ANGLE/SQUISHY branches in
  `src/playtime-ui.lua`).

- **Sfixtures, step 1 (2026-10-27)**: `src/sfixture-params.lua`: label + destroy for every
  kind; snap, anchor, uvusert, tile-repeat and light fully from data (position: ∆ move,
  centre, radius, N/E/S/W/C placement). New inspector kinds: color, file, buttons, note.
  N/E/S/W/C now re-registers the new fixture (the old code didn't). Still hand-made:
  texfixture, meshusert, resource, connected-texture, trace-vertices (mostly tools).
  Known: resizing/moving an sfixture recreates it *after* the collision fixtures, which
  breaks the sfixtures-first ordering invariant (old behaviour, not fixed here).
- **Scrolling panels**: `ui.scrollPanel` (body, joint, sfixture panels) +
  `spec/ui-overflow_spec.lua`, which draws every panel fully open and checks it fits or scrolls.

## Next step

Convert the rest the same way: the remaining sfixture kinds (texfixture's layer settings
first; the tools stay custom) and world settings. Then slice 3 (library v0); add the fake-pointer hook when it needs clicks.
