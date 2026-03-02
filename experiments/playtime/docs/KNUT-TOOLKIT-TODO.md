# Knut Character Toolkit — Implementation Plan

## Context

Knut is a children's book character (yellow crocodile-person) currently hand-built in two scene files (`knut.playtime.json`, `knutjump.playtime.json`). The goal is a lightweight toolkit to assemble Knut (and other book characters) programmatically — much simpler than the mipo/humanoid editor.

### What exists today
- 16 custom textures in `textures/knut/` (hoofd, torso, arm, been, voet, boom, gras, kaaklinks/rechts)
- Hand-built scene: 34 bodies, 28 revolute joints, 6 connected-textures
- The connected-texture deformation pipeline already works perfectly for Knut's limbs/tail
- Arms and tail are **separate chains with static roots** (not jointed to torso)
- Only head-to-torso joint has angle limits (-40 to +18 deg)

### Why not extend the humanoid system directly
- `getParentAndChildrenFromPartName()` is hardcoded for humanoid topology
- Part creation order is hardcoded in `createCharacterFromExistingDNA()`
- Knut's topology is different: detached arm chains, a tail, jaw pieces, no humanoid limb symmetry
- Generalizing the humanoid system would be a large refactor with risk to existing functionality
- Children's book characters need custom art, not procedural OMP generation

---

## Phase 1: Knut Blueprint & Assembly (~200 lines)

**New file: `src/knut-manager.lua`**

### Task 1.1 — Define the Knut blueprint as a data table

A simple Lua table describing Knut's skeleton. Not DNA format — just direct part definitions:

```lua
local blueprint = {
    torso  = { w = 224, h = 235, texture = 'knut/torso.png', bodyType = 'dynamic' },
    head   = { w = 93, h = 87, texture = 'knut/hoofd.png', bodyType = 'dynamic',
               parent = 'torso', offsetY = -0.48,
               joint = { limits = { -0.70, 0.31 } } },
    -- Legs: short 2-body chains with connected-texture
    ruleg  = { w = 40, h = 135, bodyType = 'dynamic',
               parent = 'torso', offsetX = 0.13, offsetY = 0.71,
               connectedTexture = { url = 'knut/been4f.png', chainLength = 2 } },
    luleg  = { ... same with been4.png ... },
    -- Arms: 6-segment rope chains, initially detached
    rarm   = { segmentSize = 40, segments = 6, bodyType = 'dynamic',
               connectedTexture = { url = 'knut/arm.png' },
               attachTo = 'torso', attachOffsetX = 0.85, attachOffsetY = -0.48 },
    larm   = { ... mirror ... },
    -- Tail: 11-segment rope chain
    tail   = { segmentSize = 40, segments = 11, bodyType = 'dynamic',
               connectedTexture = { url = 'knut/been4f.png' },
               attachTo = 'torso', attachOffsetX = -1.0, attachOffsetY = -0.18 },
}
```

### Task 1.2 — `createKnut(x, y, scale)` assembly function

Builds a Knut character from the blueprint:

1. Create torso body at (x, y) using `objectManager.addThing('rectangle', settings)`
2. Create head, join to torso with revolute joint (with limits)
3. Create leg chains (2 bodies each), add connected-texture sfixtures
4. Create arm chains (6 segments each), add connected-texture sfixtures with node lists
5. Create tail chain (11 segments), add connected-texture sfixtures
6. Add texfixtures for torso.png and hoofd.png on their bodies
7. Set groupIndex on all bodies for self-collision avoidance
8. Return an instance table: `{ parts = {}, joints = {}, blueprint = blueprint }`

Key helper to write: **`createChain(startX, startY, segments, segmentSize, scale, jointLimits)`** — creates a chain of N bodies connected by revolute joints, returns body list + joint list.

Key helper to write: **`addConnectedTextureToChain(rootBody, joints, anchorBody, textureURL)`** — attaches a connected-texture sfixture that references all the joints in the chain.

### Task 1.3 — Register with existing systems

- Register all bodies in `registry` so they render with the textured pipeline
- Use existing `fixtures.addSFixture()` for connected-texture and texfixture creation
- Optionally register with `mipoRegistry` for selection/editing (or skip if not needed)

---

## Phase 2: Environment Pieces (~50 lines)

### Task 2.1 — Environment blueprint

Knut scenes have background elements. Define simple spawners:

```lua
lib.addTree(x, y)      -- boom.png or boom2.png on a static body
lib.addGrass(x, y, w)  -- gras2.png tiled across width
lib.addSky(x, y, w, h) -- blauw.png backdrop
lib.addJaw(x, y, side) -- kaaklinks.png or kaakrechts.png
```

These are just static bodies with texfixtures — very simple.

### Task 2.2 — Scene presets

```lua
lib.createScene('tropical')  -- ground + tree + grass + sky + knut
```

---

## Phase 3: Simple Editor Panel (~150 lines)

**New file: `src/ui/knut-editor.lua`**

NOT a full mipo-style accordion editor. Just a compact panel for quick tweaks.

### Task 3.1 — Basic controls

- **Scale slider** (0.1 - 1.0) — uniform character scale
- **Spawn button** — click to place a new Knut at mouse position
- **Randomize pose** — set random joint angles within limits
- **Reset pose** — return to default stance

### Task 3.2 — Per-part tweaks (optional, collapsible)

- Arm chain length slider (3-8 segments)
- Tail chain length slider (5-15 segments)
- Leg length slider
- Head-torso joint limit slider

### Task 3.3 — Color tinting

Since Knut uses custom art (not OMP), tinting options are simpler:
- Overall tint color picker (applies `love.graphics.setColor` tint to all textures)
- Or per-part tint if variety is wanted

---

## Phase 4: Multi-Character Support (~100 lines)

### Task 4.1 — Blueprint registry

Generalize so other children's book characters can use the same system:

```lua
local blueprints = {}
blueprints['knut'] = { ... }
blueprints['other-animal'] = { ... }

lib.createCharacter(blueprintName, x, y, scale)
```

Each blueprint is just a data table — no code changes needed per character. New characters only need:
1. Textures in `textures/<name>/`
2. A blueprint table defining parts, chains, textures, joints

### Task 4.2 — Blueprint-from-scene extractor (tool)

A dev tool to reverse-engineer existing hand-built scenes into blueprint format:
```lua
-- Usage from bridge:
-- POST /eval { code = "require('src.knut-manager').extractBlueprint()" }
```

Reads the current scene's bodies/joints/sfixtures and generates a blueprint Lua table. This way you can hand-build a new character in the editor, then extract it as a reusable blueprint.

---

## File Plan

```
src/knut-manager.lua        -- Phase 1-2: blueprint, assembly, environment
src/ui/knut-editor.lua      -- Phase 3: simple editor panel
textures/knut/              -- Already exists (16 files)
```

## Dependencies

All existing infrastructure is reused:
- `objectManager.addThing()` — body creation
- `fixtures.addSFixture()` — sfixture creation
- `registry` — body/joint/fixture tracking
- `box2d-draw-textured.lua` — connected-texture rendering (no changes needed)
- `src/joints.lua` — joint creation

No changes to existing modules needed in Phase 1-2.

## Open Questions

1. **Should arm/tail chains attach to torso via joints?** The current knut scene has them as separate static-root chains. For ragdoll physics, jointing them to the torso would be better. But static roots give more control for posed/scripted animation.

2. **Jaw pieces (kaaklinks/kaakrechts)** — these are large overlapping textures. Are they part of the character (attached to head) or environment decoration? This affects whether they go in the character blueprint or environment.

3. **How many other book characters are there?** Knowing the full cast helps design the blueprint format. Are there quadrupeds, birds, fish?

4. **Animation/scripting** — does Knut need scripted behaviors (walking, jumping) or is static posing enough for now?
