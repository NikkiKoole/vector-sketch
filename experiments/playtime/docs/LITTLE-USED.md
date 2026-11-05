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
- [ ] Grass round
- [ ] Liquid round
- [ ] Tile repeat round
- [ ] Light round
- [ ] Recorder round
