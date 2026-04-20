# spine-humanoid-sandbox

Minimal LÖVE2D sandbox for the spine-mesh math described in
`experiments/playtime/docs/SPINE-MESH-PLAN.md`. Zero playtime
dependencies — pure geometry, no bodies, no sfixtures, no editor UI.

## Run

```
cd experiments/spine-humanoid-sandbox
love .
```

## Controls

- **Drag any orange dot** — moves a joint.
- **`r`** — rebind the current pose as the new rest pose.
- **`space`** — reset to the default T-pose.
- **`esc`** — quit.

## Current phase

**Phase B — one limb bound.** `leftArm` (shoulder → elbow → wrist)
has a ribbon polygon generated around its rest chain. Dragging those
three joints reshapes the deformed polygon live. Other skeleton
points are draggable for layout but don't affect any mesh yet.

Upcoming:
- Phase C — bind the other three limbs + a static torso polygon.
- Phase D — texturing via a backdrop image.

See the plan doc for details.
