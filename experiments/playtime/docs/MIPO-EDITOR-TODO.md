# Mipo Editor TODO — Features from puppet-maker2

Comparison of puppet-maker2 (app store app) vs playtime's mipo editor.
Checked items = already supported in playtime.

Reference: `/Users/nikkikoole/Projects/love/vector-sketch/experiments/puppet-maker2`

Key source files in puppet-maker2:
- `lib/dna.lua` — DNA structure, defaults, randomizeGuy(), patchDNA()
- `lib/updatePart.lua` — part rendering, canvas creation, OMP coloring
- `lib/texturedBox2d.lua` — face rendering, positioner math, hair curves, mouth stencil
- `lib/editguy-ui.lua` — UI controls, category navigation, sliders
- `lib/editGuy.lua` — scene management, camera, physics setup

---

## 1. Face Parts (NOT in playtime yet)

Face parts are **NOT physics bodies** — they're 2D images rendered on top of the head
body using world-space coordinates derived from the head's 8-point bounding polygon.

Assets already in playtime's `textures/`: eye1-7, pupil1-11, brow1-8, nose1-15,
upperlip1-4, lowerlip1-4, teeth1-7 (all with `-mask.png` where applicable).

### Eyes
- [x] Eye shapes: `eye1.png` through `eye7.png` (+ masks)
- [x] Eye rendering: OMP compositing with black outline, white fill
- [x] Eye w/h multipliers (0.125–4.0)
- [x] Eye positioners: `eye.x` (spacing, 0–0.5), `eye.y` (vertical, 0–1)
- [ ] Eye positioner: `eye.r` (rotation, -2 to 2)
- [ ] Left eye rendered with negative width (horizontal flip)

**How eyes are positioned** (texturedBox2d.lua ~line 1064):
```lua
-- f[] = 8 points of head polygon: f[1]=top, f[3]=right, f[5]=bottom, f[7]=left
local leftEyeX = lerp(f[7][1], f[3][1], 0.5 - positioners.eye.x)
local rightEyeX = lerp(f[7][1], f[3][1], 0.5 + positioners.eye.x)
local eyeY = lerp(f[1][2], f[5][2], positioners.eye.y)
-- Then: facePart:getWorldPoint(x * sx / shrink, y * sy / shrink)
```

### Pupils
- [x] Pupil shapes: `pupil1.png` through `pupil11.png` (some with masks)
- [x] Pupil w/h multipliers (0.125–2.0, default 0.5)
- [ ] Pupils follow look-at target (constrained to max offset within eye bounds)
- [ ] Max pupil offset = `eyeW/3`, `eyeH/3`

**Look-at system** (tweenVars):
```lua
guy.tweenVars.lookAtPosX, lookAtPosY  -- target screen position
guy.tweenVars.lookAtCounter            -- counts down, eyes track when > 0
-- angle = getAngleAndDistance(eyeCenter, target)
-- pupilOffset = min(distance, maxOffset)
```

### Eyebrows
- [ ] Brow shapes: `brow1.png` through `brow8.png` (no masks — single-layer)
- [ ] Brow w/h multipliers (0.25–2.0)
- [ ] Brow positioners: `brow.y` (vertical, 0–1), `brow.bend` (1–10)
- [ ] Rendered as bezier curve mesh, NOT flat image

**10 bend patterns** (texturedBox2d.lua ~line 1160):
```lua
local bends = {
  { 0, 0, 0 },      -- 1: straight
  { 1, 0, -1 },     -- 2: angry
  { -1, 0, 1 },     -- 3: sad
  { 1, 0, 1 },      -- 4: raised both
  { -1, 0, -1 },    -- 5: lowered both
  { 1, 0, 0 },      -- 6: raise left
  { -1, 0, 0 },     -- 7: lower left
  { 0, -1, 1 },     -- 8: center down left up
  { 0, 1, 1 },      -- 9: center up
  { -1, 1, 1 },     -- 10: asymmetric
}
-- Each entry = {leftY, centerY, rightY} offsets * bendMultiplier
-- Rendered with renderCurvedObjectFromSimplePoints → bezier mesh
```

### Nose (face overlay, NOT nose segments)
- [ ] Nose shapes: `nose1.png` through `nose15.png` (most with masks)
- [ ] Nose w/h multipliers (0.5–3.0)
- [ ] Nose positioner: `nose.y` (vertical, 0–1)
- [ ] Simple positioned image, no animation

### Mouth (most complex face part)
- [x] Upper lip shapes: `upperlip1.png` through `upperlip4.png` (+ masks, OMP with black outline)
- [x] Lower lip shapes: `lowerlip1.png` through `lowerlip4.png` (+ masks, OMP with black outline)
- [ ] Teeth shapes: `teeth1.png` through `teeth7.png` (+ masks)
- [x] Mouth w/h multipliers (0.3–2.0)
- [ ] Teeth hMultiplier (0.5–3.0)
- [x] Mouth positioner: `mouth.y` (vertical, 0.5–0.95)
- [x] **Stencil-masked rendering**: mouth interior polygon with backdrop color
- [x] Lip thickness control (lipScale 0.05–0.5)
- [x] Lip color + mouth interior color controls
- [x] 15 mouth shape presets (from mipomi-lang phoneme system)

**Mouth animation** (tweenVars):
```lua
guy.tweenVars.mouthOpen = 0   -- 0=closed, 1.25+=very open (vertical)
guy.tweenVars.mouthWide = 1   -- horizontal scaling
-- Upper lip: bezier(-w/2, 0) → (0, -mouthOpen) → (w/2, 0)
-- Lower lip: bezier(-w/2, 0) → (0, +mouthOpen) → (w/2, 0)
-- Mouth hole = polygon sampled from both curves → stencil
-- Teeth drawn inside stencil, lips drawn on top
```

### Skin Patches
- [ ] 3 patch types: snout, eye1, eye2 (using `patch1-4.png` + masks)
- [ ] Each has OMP coloring (bgPal, fgPal, linePal) + alpha per layer
- [ ] Transform values (PV): `sx`, `sy`, `r` (rotation), `tx`, `ty` (translate)
- [ ] Rendered on head canvas with transform applied

---

## 2. Per-Part Multipliers & Dimensions

- [x] **Torso** — sx/sy (our SHAPE8 scaling)
- [x] **Head** — sx/sy
- [x] **Arms/Legs** — h (length), w (width) for CAPSULE parts
- [x] **Hands/Feet** — sx/sy
- [x] **Ears** — sx/sy
- [x] **Neck** — h (all segments at once), individual h/w per segment
- [ ] **Face magnitude** — `mMultiplier` scales ALL face features (0.25–2.0)
- [ ] **Leg stance width** — `positioners.leg.x` (0–1, default 0.5)
- [ ] **Ear vertical position** — `positioners.ear.y` (0–1, default 0.5)
- [ ] **Ear stance angle** — `creation.lear.stanceAngle` (0 to π), `rear` (-π to 0)
- [x] **Head/torso flip** — our sx can go negative, same effect as flipx/flipy

---

## 3. Color & Texture System

puppet-maker2 uses palette indices (1–114 colors) instead of hex strings.
We use hex strings directly — equivalent, just different representation.

- [x] **Skin colors** — outline (bg), fill (fg), pattern (p) per patch
- [x] **Bodyhair colors** — outline + fill
- [x] **Connected-skin colors** — outline + fill + pattern
- [x] **Connected-hair color** — outline
- [x] **Haircut color** — tint via bgHex
- [ ] **Procedural texture controls** per part:
  - `bgTex`, `fgTex` — index into `texture-type0.png` through `texture-type7.png`
  - `texScale` (1–9) — pattern tile scale
  - `texRot` (0–15) — pattern rotation in steps
  - `fgAlpha` (0–5) — foreground pattern opacity
- [ ] **Per-patch alpha** — bgAlpha, fgAlpha, lineAlpha for skin patches

> We already have `textures/pat/type0-8.png` which match puppet-maker2's
> `bodytextures/texture-type0-7.png`. Our `pURL` field could reference these.

---

## 4. Creation Options

- [x] **Potato head** — isPotatoHead toggle
- [x] **Neck segments** — 0–5
- [x] **Torso segments** — 1–5
- [x] **Nose segments** — 0–5
- [ ] **Has neck toggle** — separate from segment count (puppet-maker2 has this as boolean)
- [ ] **Physics hair** — 5 hair segments as physics bodies attached to head
- [ ] **Leg facing** — 'left', 'right', 'front' (affects foot stance angles)

---

## 5. Haircut / Head Hair

- [x] **Hair texture selection** — thumbnail grid
- [x] **Hair width** — width slider
- [x] **Start/end index** — which vertices hair follows
- [x] **Hair color** — bgHex tint
- [x] **None option** — remove hair
- [ ] **Hair tension** — `extra.tension` (default 0.02), controls curviness
- [ ] **Hair spacing** — `extra.spacing` (default 5), point density along curve

---

## 6. Body Hair

- [x] **Bodyhair texture selection** — per-part (torso, head)
- [x] **Bodyhair colors** — outline + fill
- [x] **None option** — remove bodyhair
- [ ] **Chest hair magnitude** — growfactor multiplier (0.5–1.25)

---

## 7. Limb Hair (Connected Hair)

- [x] **Texture selection** — thumbnail grid
- [x] **Width multiplier** — wmul slider
- [x] **Color** — outline
- [ ] **Per-limb independent control** — currently shared via upper limb owner

---

## 8. DNA Structure Comparison

### What puppet-maker2 has that we need in `instance.dna`:

```lua
-- puppet-maker2 DNA:
dna = {
  creation = { ... },        -- ✅ We have this
  multipliers = { ... },     -- ❌ We use dims.sx/sy/h/w instead (partial)
  values = { ... },          -- ❌ We use appearance table (partial)
  positioners = { ... },     -- ❌ Missing entirely
}

-- Proposed additions to instance.dna:
instance.dna.positioners = {
  eye = { x = 0.2, y = 0.5, r = 0 },
  brow = { y = 0.8, bend = 1 },
  nose = { y = 0.5 },
  mouth = { y = 0.25 },
  ear = { y = 0.5 },
  leg = { x = 0.5 },
}

instance.dna.face = {
  magnitude = 1,            -- global face feature scaler
  eye =      { shape = 1, bgHex = '...', fgHex = '...', wMul = 1, hMul = 1 },
  pupil =    { shape = 1, bgHex = '...', wMul = 0.5, hMul = 0.5 },
  brow =     { shape = 1, bgHex = '...', wMul = 1, hMul = 1 },
  nose =     { shape = 1, bgHex = '...', fgHex = '...', wMul = 1, hMul = 1 },
  upperlip = { shape = 1, bgHex = '...', fgHex = '...', wMul = 1, hMul = 1 },
  lowerlip = { shape = 1, bgHex = '...', fgHex = '...', wMul = 1, hMul = 1 },
  teeth =    { shape = 1, bgHex = '...', fgHex = '...', hMul = 1 },
  patches = {
    snout = { shape = 1, sx = 2, sy = 1, r = 0, tx = 0, ty = 5, alpha = 5 },
    eye1 =  { shape = 1, sx = 1, sy = 1, r = 0, tx = -2, ty = 0, alpha = 5 },
    eye2 =  { shape = 1, sx = 1, sy = 1, r = 0, tx = 2, ty = 0, alpha = 5 },
  },
}
```

### Tween/animation state (runtime only, not saved):
```lua
instance.tweenVars = {
  eyesOpen = 1,          -- 0=closed, 1=open (blink animation)
  mouthOpen = 0,         -- vertical mouth opening
  mouthWide = 1,         -- horizontal mouth stretch
  lookAtPosX = 0,        -- pupil tracking target
  lookAtPosY = 0,
  lookAtCounter = 0,     -- countdown timer
}
```

---

## 9. UI Improvements

- [x] **Drag-to-place** mipo characters
- [x] **Accordion-based panels** per feature
- [x] **Thumbnail grids** for shape/texture selection
- [ ] **Category navigation** — left sidebar with body part categories
- [ ] **Camera focus** — zoom/pan to selected part when switching categories
- [ ] **Part tabs** — hierarchical (e.g. mouth → upper lip / lower lip / teeth)

---

## 10. Randomization

- [x] **Basic randomize** — shapes, colors, bodyhair
- [ ] **Smarter randomize** — `randValue(min, max, step, preferMiddle)` avoids extremes
- [ ] **Linked colors** — hair, chesthair, armhair, leghair, brows share hair color
- [ ] **Randomize face** — all face part shapes, positions, sizes
- [ ] **Randomize patches** — skin patch alpha/transform randomization

---

## 11. Save/Export

- [ ] **DNA save/load slots** — save multiple character presets
- [ ] **Screenshot export** — capture character at various resolutions

---

## Priority Order (suggested)

### Phase 1: Face rendering infrastructure ✅
1. ✅ Add `dna.face` and `dna.positioners` to DNA template in character-manager
2. ✅ Face rendering function: decal sfixtures with OMP compositing on head body
3. ✅ Head bounding polygon (shape8Dict vertices for eye/mouth positioning)
4. ✅ Decal rendering: positioned images at body-local coordinates

### Phase 2: Individual face parts (in progress)
5. ✅ Eyes + pupils (shape thumbnails, position, scale, color)
6. Eyebrows (shape, bend patterns, bezier curve rendering) — **next up**
7. Nose (shape, position, scale — face overlay, separate from nose segments)
8. ✅ Mouth (upper lip + lower lip as bezier curves, stencil-masked interior, 15 presets)
9. Skin patches with transforms

### Phase 3: Animation
10. Eye blink tween (eyesOpen 0→1)
11. Pupil look-at tracking (follow mouse or target)
12. Mouth open/close tween

### Phase 4: Positioners & polish
13. Ear position + stance angle controls
14. Leg stance width
15. Hair tension/spacing sliders
16. Chest hair magnitude
17. Face magnitude global scaler

### Phase 5: Advanced
18. Physics hair (5 hair bodies attached to head)
19. Procedural texture controls (texScale, texRot, alpha)
20. DNA save/load presets
21. Smarter randomization with linked colors
