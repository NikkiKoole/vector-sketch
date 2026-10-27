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
- Wire tool (drag trigger → receiver): nice, but third in line; revisit after slice 4.

## Status

- **Slice 1 built (2026-10-27)**: `src/ui/inspector.lua` (`drawParams`), `params` on
  KEEP_ANGLE, SIGNAL_BUTTON/PLATE/SOCKET/GATE and SQUISHY in `src/behaviors.lua`,
  `spec/behaviors_spec.lua` checks the rows. The behavior panel has an `old`/`new` button
  (top right) to compare with the hand-made panels, which are still there.
  Side effects: KEEP_ANGLE's old `speed` slider is gone (nothing read it), it now shows
  `enabled`, plus `strength` (kp) and `max spin` behind '+ more'; the old KEEP_ANGLE
  'remove' wiped *all* behaviors of the body, the new one removes just that one.

## Next step

Play with it for one session and decide: keep (then delete the old SIGNAL_* /
KEEP_ANGLE branches in `src/playtime-ui.lua`) or revert. If kept: slice 2, joint settings.
