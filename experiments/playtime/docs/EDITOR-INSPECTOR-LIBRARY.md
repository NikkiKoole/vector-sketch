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

## Layout direction (2026-10-27)

Claude Desktop sketched directions A-E (`~/Downloads/playtime-editor-handoff/`, HANDOFF.md +
mockups). Nikki's pick, not E's bottom strip:

- **Left: tool rail.** Tools instead of the "add shape" / "add joint" panels (pick a joint type,
  drag body A -> B; pick an sfixture kind, click a body). Tool options sit next to the rail/top bar.
- **Right: one column, three tabs, one at a time:** **properties** (the inspector panels we
  have) | **on stage** (one row per object, duplicates grouped, wires shown `button -> gate1`,
  click selects) | **library** (saved contraptions + toys; slice 3).
- Stage gets the middle. Toolbars on the right where it helps.

Order: (a) right column with the three tabs, properties first (move today's panels in); (b) the
on-stage list; (c) library v0 (slice 3); (d) left rail replacing add shape/add joint.
Each is its own keep/revert moment.

## Not doing (considered, said no)

- Timeline, onion skinning (said no 2026-10-27).
- Code editing inside the editor: code stays in files.
- Rewriting all panels in one go, or a new UI framework/library.
- Nested prefabs / linked instances (edit one, all update): too deep for now.
- Bottom-strip inspector (HANDOFF direction E): said no 2026-10-27, a busy body runs out of width.
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

- **World settings + backdrop (2026-10-27)**: `src/world-params.lua`. Basic: gravity, speed,
  grid, textures, dark; '+ more': debug draw switches (now checkboxes that show their state,
  were blind toggle buttons), alpha, drag force/damp, profile, stats. The panel sizes itself
  to its content and scrolls. The selected backdrop's scale/foreground/border use the
  inspector too (the backdrop list stays custom). Scrollbars are 10 px now, inside the
  panel margin, so they no longer cover number fields.

- **Texfixture (2026-10-27)**: `src/texfixture-params.lua`, one list per accordion: position
  (∆ move, centre, size from body/image, edit verts, corners; '+ more' width/height/z),
  texture (mode, hairs, plasticine, images + colours; OMP pattern transform behind '+ more'),
  hairs and plasticine (only while switched on; the fine shader knobs behind '+ more'),
  patch1-3. sfixture-editor 2281 -> ~1940 lines. The 'dims' checkbox is gone ('+ more' does that).
- **Hot reload fix**: `src/ui/all.lua` keeps one ui table across reloads (a reload used to
  split it, so panels missed `overPanel` and closed on any click).

## Next step (pick up here)

**Where we are (2026-10-28):** step (a) is done. `src/ui/right-column.lua` draws the tabs
`properties | on stage | library` at y 70 (under the toolbar row, so the tab bar doesn't
collide with the toolbar buttons), and the tab is saved in `state.rightColumn.tab`. The properties tab calls
`playtime-ui.drawSelectionProperties(x, y, w, h)`. The body, multi-selection, sfixture, joint and
Mipo panels all take an optional rect now (defaults to the old right-edge rect, so old specs
keep working). With nothing selected, and on the two empty tabs, a short note panel shows
instead of a full-height panel, so the stage stays visible. The draw-click and autoropify mode
panels still draw their own right-edge panel, so the column is hidden in those modes.
Specs: `spec/right-column_spec.lua` (tab clicks, rect) plus "in column" checks in the overflow spec.

**Step (b) done too (2026-10-28):** the on-stage tab (`src/ui/on-stage.lua`) lists Mipos (one row
each, lit up for any of its parts), wires (`button -> gate1 -> gate`, from `signals.wires()`, which
the wire overlay now uses too) and the other bodies grouped by label (`hold  x28`). Clicking a
row selects it and pans the camera if it's off screen. Clicking a group again steps to the next
one. You stay on the list; the properties are one tab over. Spec: `spec/on-stage_spec.lua`.

**Step (c) / slice 3, library v0 (2026-10-28):** the library tab (`src/ui/library-tab.lua`):
type a name, "save selection" writes the selected bodies + the joints between them to
`library/<name>.playtime.json` in the save directory (`src/library.lua`; Mipo parts are left
out). Each prefab is a button: press spawns a copy at the mouse, drag, release (like the toys).
Placing gives every body/sfixture/joint id a new uuid wherever it appears in the data, then
builds with `sceneIO.buildWorld(data, world, cam, { additive = true })` (new: no clearing, camera
or backdrops; post-passes only touch the new sfixtures; returns the built things). Spec:
`spec/library_spec.lua`. A `.playtime.json` dropped on the open library tab is imported as a
prefab (non-Mipo bodies + their joints, centred; `library.import`, uses `sceneIO.prepareLoaded`);
dropped anywhere else it still loads as the scene. 'open folder' opens `library/` in Finder for
renaming/deleting. Mipos (2026-10-28): saved as DNA in a `mipos` list (dna, scale, torso position); any
selected part saves the whole Mipo; placing grows it fresh with `createCharacterFromJustDNA` +
T-pose (own id, collision group, z-range). Its pose isn't kept. Not yet: thumbnails;
world positions inside sfixture `extra` aren't shifted.
**Copies and names (2026-10-28):** ids are renewed on every copy (clone: `idMapping` in
`io.cloneSelection`; place: `library.renewIds`). Names that link things were not: a placed
button + gate stayed on `gate1` and worked the original gate too. Now `signals.renameForCopy`
gives a copy its own name (`gate1 -> gate2`) for each signal it holds *both* ends of; a copy
with one end (a second button) keeps the name and joins that circuit. Used by place and clone.
Clone also no longer shares the original's `behaviors` table, and copies joints from its
argument (not `state.selection`). MESHUSERT/UVUSERT -> RESOURCE used to pair by equal sfixture
label (a copy could draw with the original's mesh). Now `src/resource-link.lua`: `extra.resourceId`
links them (an sfixture id, so clone and place renew it); label match is only the fallback for
old scenes and fills in the link. A mesh copied with its RESOURCE uses the copy, alone it keeps
the original's. Socket `accepts` and script label lookups are meant to be shared kinds, left as is. And a
RESOURCE now owns its picture (`extra.imageURL`), so a placed or cloned skinned body draws
textured in any scene, no backdrop needed (`docs/UV-BACKDROP-FRAGILITY.md`, update at the top).

**Kept (2026-10-28):** Nikki likes the library.
**Compact switch (2026-10-28, keep/revert open):** `src/ui/density.lua`, settings → 'compact'
(saved in `editor-density.txt`, applied between frames by re-running the UI modules). First try
also shrank the font (25 -> 17); Nikki: keep the 25 px font, it's the *padding* that feels big.
So compact = same font, rows and outlines; less padding: gaps 10 -> 6, inspector rows 45 -> 31
(fields 40 -> 29), panel title band 40 -> 32, hand-placed content starts 36 below the panel top
(was 80), column top 70 -> 52, toolbar buttons 70% wide. 'roomy' is exactly the old numbers.
Next look, if compact stays: flatter buttons (ghost/outline), muted labels, handoff palette.

**Next: slice 4, the real test:** build the next contraption with the library + inspector only.

**Keep/revert check still open:** use it for a session. Does switching tabs feel better than
panels popping up?

**After that:** slice 4 (use it for real), (d) left tool rail.
Still hand-made and fine for now: meshusert, resource, connected-texture, trace-vertices panels
(mostly tools). Add the fake-pointer hook when a spec needs real clicks.
