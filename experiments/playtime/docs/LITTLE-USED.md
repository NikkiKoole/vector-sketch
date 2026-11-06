# Little-used features: use them more, find the bugs

status: idea

Features that exist, have specs, but that few scenes (or none) use lately. Bugs hide there: on
2026-11-05 the skinned mesh alone gave three (a scene that didn't load after a bone was deleted,
a vertex with no bone left coming loose, a clone bent by the original's rig), all only found by
poking at it. The idea for another time: a session per feature that *uses* it (build something
with it in the editor, save, reload, clone, delete a part, play), and turns what breaks into specs.

Counted 2026-11-05 (scene files under `scripts/` with the sfixture saved in them; last change to
the code):

| feature | where it's used | code last touched |
|---|---|---|
| Skinned mesh (MESHUSERT + RESOURCE, bone weights, painted bones, spine bind) | 2 scenes: `hoop`, `workmoreclean` (Knut era) | skinning 2026-11-05 (fixes), meshusert-bind 10-30 |
| UV mesh (UVUSERT) and tracing UVs on a backdrop | 2 scenes: `resources`, `uvs` | resource-link 10-28 |
| Soft bodies (SOFTBODY, `src/blob.lua`) | no saved scene; made from scripts / the toys shelf (`drawn-sea`, `depth`, `planks`, `sm-demo`) | 11-03 |
| Grass edge (GRASS) | spikes' scripts only (`burrow`, `clouds`, `depth`, `plants`, `wild`), none saved | 10-30 |
| Level water (LIQUID) | `burrow`, `kitchen` | 10-31 |
| Tile repeat (TILE_REPEAT) | 1 scene: `knutjump` | |
| Light sfixture (LIGHT) | none saved | |
| Recorder (animation recording / playback) | `spec/recorder_spec.lua` | 10-30 |

Per feature, the round to try: make one in the editor from nothing; save and reload; clone it
(whole, and part of it); delete what it hangs on (a joint, an anchor, a body); flip / resize its
body; play with it for a minute; at 200 and 400 px per metre. What breaks becomes a spec, failing
first.

- [ ] Skinned mesh round (the clone / load / vertex fixes of 2026-11-05 are in; the rest untried)
- [ ] UV mesh + backdrop round
- [x] Soft body round (2026-11-06, `claudetools/feature-rounds_spec.lua`, 16 seeds x 2 meters: nothing broke. It
  does save and come back, rim and look, and a save loaded and saved again matches. Pictures through
  build / flip / size / drag / drop / reload looked right. What it found was in the sweeps: they stepped
  with a bare `world:update`, so blob rims and water never ran in them; `sweep.step` steps as the game does)
- [x] Grass round (2026-11-06: grassy ground and a grassy dynamic turf; 202 cases x 2 meters, a new
  'turned upside down' case for every feature; nothing broke, every grass sfixture keeps blades on
  its upper edge at any angle, flipped and reloaded too (the check caught a planted fault). To look
  at, not a bug: the blade cache's key holds the body's angle, so a tumbling grassy body builds both
  its SpriteBatches again every frame, ~118 a second in the scene `light-grass-check`)
- [x] Liquid round (2026-11-06: a dynamic cup and a static bath from the toys; 178 cases x 2 meters,
  nothing broke: the fill stays in 0..1, no container holds more than it can at its angle, the level
  always holds the water's amount, after a reload too (the check caught spilling switched off).
  Pictures: level when tilted, empty when tipped past its mouth or flipped upside down)
- [x] Tile repeat round (2026-11-06: a tiled ground and a tiled dynamic block; 182 cases x 2 meters, the
  tile mesh must cover its body as it is now (it's cached). Found: one dropped from the tool rail, its
  panel then picking a texture, died on every draw (no tile size set, the panel only shows the default
  1): drawn at the defaults now, spec/tile-repeat-new_spec.lua)
- [x] Light round (2026-11-06: a lamp with a LIGHT sfixture lighting a plasticine and a hairs box; 502 cases, 4
  seeds x 2 meters, nothing broke, every lit body gets every light, also after a reload. Found on the way:
  the sweeps never touched a texfixture's settings, its panel builds them from texfixture-params'
  accordions, not sfixture-params' bySubtype; `claudetools/actions.lua` adds them now. To look at, not a
  bug: a *directional* light also fades with the distance from its lamp (`range`, 500), so one 300 px
  away only gives about a third, and turning the lamp round changed a box's halves by ~1%; see it in
  the scene `light-grass-check`)
- [ ] Recorder round
