# Scene Graph + Box2D via a Physics-Root Node

## Context

Vector-sketch (the parent project) and playtime are converging. Both deal with flat-shaded figures, triangulated outlines, Steiner points, mesh regen, hierarchical transforms. The only real difference is that playtime also has a Box2D simulation on top.

This doc captures the model we've settled on for combining the two: **not a per-node `box2d=true` flag**, but a dedicated *physics-root* node that defines the coordinate frame and lifetime of a Box2D world.

## Why not "just a flag per node"

Tempting, but breaks down fast:

- **Scale doesn't round-trip through Box2D.** Fixtures are fixed at creation; `sx=2` on an ancestor folder does nothing to the physics shape. Either forbid scale on physics-enabled subtrees, or rebuild fixtures on every scale change.
- **Transform ownership flips mid-tree.** For a dynamic body, Box2D owns world position/angle each step — the node's `l` transform becomes a *derived* value. With physics bodies scattered anywhere in the tree, any ancestor rotation means constantly re-decomposing world → local. The scene graph stops being the source of truth halfway down.
- **Joints cross the hierarchy.** A joint between `leftFoot` and `rightFoot` doesn't fit parent-child. Needs identity-based linking, not tree-based.

## The model: physics-root node

One node in the scene graph is marked as a physics-root. It owns:

- the `love.physics.World` instance
- world-level state: gravity, `pixelsPerMeter`, contact listeners, timeScale, paused flag
- the lifetime boundary — when this node is destroyed, the world is destroyed

**Rules:**

1. **Above the physics-root** — pure authoring space. Any transform (translate/rotate/scale/skew) you want. The physics-root's accumulated world transform is applied as a *render-time* multiply only; the sim itself runs at 1x in physics-root-local space forever. Fixtures never rebuild when you scale.

2. **Inside the physics-root subtree** — nodes marked `body=true` become Box2D bodies. Their position/angle lives in physics-root-local coordinates. Each step, Box2D writes back to the node's transform.

3. **Visual-only children under a body** — normal scene graph nodes parented to a body node just inherit its transform via the usual `_g` math. This is the "bodies as bones" idea: a body is a bone, decorative children (hats, face features, accessories) ride along for free.

4. **Joints** — reference bodies by id within the same physics-root. They're siblings in the same world; the tree structure underneath doesn't matter to them. Connector/link nodes (playtime already has these) can live anywhere in the subtree.

5. **No nested physics-roots.** Or if we ever need it, define it as "inner is a completely separate sim" — no cross-world joints.

## What this buys us

- **Clear ownership boundary.** No more "who owns this transform." Above the root → authoring owns it. Below the root, for body nodes → Box2D owns it. Everything else → normal scene graph math.
- **Scale animation works.** You can scale/rotate/skew the whole physics sim from above as a visual effect. The sim doesn't care.
- **Mesh/triangulation/Steiner work is shared.** That layer is identical whether a body ends up in Box2D or not. Vector-sketch and playtime can share a single mesh module underneath.
- **Multiple sims possible.** A scene could have two physics-root nodes for two independent worlds (split-screen, picture-in-picture, stage/backstage).
- **Save/load is cleaner.** World state is localized to one subtree; serializing a physics-root serializes its entire sim.

## Prior art

This is roughly how Godot models it (`PhysicsBody` nodes live under a scene, `World2D` is per-viewport) and how Unity does it (Rigidbodies are components, but physics queries are per-Scene). We're landing on a pattern that's been validated elsewhere — not inventing something weird.

## Open questions

- Where does `pixelsPerMeter` live — on the physics-root, or global? Probably per-root so sims at different scales can coexist.
- How do we reparent a body node across physics-root boundaries (cut/paste between sims)? Destroy + recreate the Box2D body in the new world, preserve user-facing state.
- Do non-body children of a body inherit collision? No — they're purely visual. If they should collide, make them their own body with a weld joint.

## Status

Design-phase. Not implemented. Playtime's current model is flatter (bodies at root, no scene graph on top yet). This is the target for unifying vector-sketch authoring with playtime simulation.
