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

## 1. Face Parts

Face parts are **NOT physics bodies** — they're 2D images rendered on top of the head
body using world-space coordinates derived from the head's 8-point bounding polygon.

Assets already in playtime's `textures/`: eye1-7, pupil1-11, brow1-8, nose1-15,
upperlip1-4, lowerlip1-4, teeth1-7 (all with `-mask.png` where applicable).

### Eyes
- [x] Eye shapes: `eye1.png` through `eye7.png` (+ masks)
- [x] Eye rendering: OMP compositing with black outline, white fill
- [x] Eye w/h multipliers (0.125–4.0)
- [x] Eye positioners: `eye.x` (spacing, 0–0.5), `eye.y` (vertical, 0–1)
- [x] Eye positioner: `eye.r` (rotation, -2 to 2)
- [x] Left eye rendered with negative width (horizontal flip)

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
- [~] Pupils follow mouse (checkbox toggle, elliptical clamp to eyeW/3, eyeH/3 — works but needs polish; stencil masking to eye shape attempted and rolled back)
- [x] Max pupil offset = `eyeW/3`, `eyeH/3`

**Look-at system** (tweenVars):
```lua
guy.tweenVars.lookAtPosX, lookAtPosY  -- target screen position
guy.tweenVars.lookAtCounter            -- counts down, eyes track when > 0
-- angle = getAngleAndDistance(eyeCenter, target)
-- pupilOffset = min(distance, maxOffset)
```

### Eyebrows
- [x] Brow shapes: `brow1.png` through `brow8.png` (no masks — single-layer)
- [x] Brow w/h multipliers (0.25–2.0)
- [x] Brow positioners: `brow.y` (vertical, 0–1), `brow.bend` (1–10)
- [x] Brow color (bgHex) control
- [x] Rendered as bezier curve mesh (10 bend patterns, texturedCurve). Note: playtime averages adjacent control points `{p1, avg(p1,p2), avg(p2,p3), p3}` while puppet-maker2 doubled the center `{p1, p2, p2, p3}` for a stronger bend.
- [x] Brow texture mirroring — right brow mirrors via `sx=-1` at draw time (matching puppet-maker2 approach)

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
- [x] Nose shapes: `nose1.png` through `nose15.png` (most with masks)
- [x] Nose w/h multipliers (0.5–3.0)
- [x] Nose positioner: `nose.y` (vertical, 0–1)
- [x] Simple positioned image, no animation
- [x] Mutually exclusive with physics nose segments

### Mouth (most complex face part)
- [x] Upper lip shapes: `upperlip1.png` through `upperlip4.png` (+ masks, OMP with black outline)
- [x] Lower lip shapes: `lowerlip1.png` through `lowerlip4.png` (+ masks, OMP with black outline)
- [x] Teeth shapes: `teeth1.png` through `teeth7.png` (+ masks)
- [x] Mouth w/h multipliers (0.3–2.0)
- [x] Teeth hMultiplier (0.5–3.0)
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

### Face Skin Patches
- [ ] 3 patch types: snout, eye1, eye2 (using `patch1-4.png` + masks)
- [ ] Each has OMP coloring (bgPal, fgPal, linePal) + alpha per layer
- [ ] Transform values (PV): `sx`, `sy`, `r` (rotation), `tx`, `ty` (translate)
- [ ] Rendered on head canvas with transform applied

> Note: these are face-specific patches (snout markings, eye markings) rendered on
> the head. Different from the body skin patches which are already implemented per
> body part.

---

## 2. Per-Part Multipliers & Dimensions

- [x] **Torso** — sx/sy (our SHAPE8 scaling)
- [x] **Head** — sx/sy
- [x] **Arms/Legs** — h (length), w (width) for CAPSULE parts
- [x] **Hands/Feet** — sx/sy
- [x] **Ears** — sx/sy
- [x] **Neck** — h (all segments at once), individual h/w per segment
- [x] **Face magnitude** — `faceMagnitude` scales ALL face features (0.25–2.0)
- [x] **Leg stance width** — `positioners.leg.x` (0–1, default 0.5)
- [x] **Ear vertical position** — `positioners.ear.y` (0–1, default 0.5)
- [x] **Ear stance angle** — per-ear stanceAngle sliders (lear + rear independent)
- [x] **Ears over/under head** — zOffset toggle (190=behind, 210=in front). Fixed: `addTexturesFromInstance2` now re-applies `zGroupOffset` to recreated fixtures.
- [x] **Head/torso flip** — our sx can go negative, same effect as flipx/flipy
- [x] **Symmetric editing** — checkbox mirrors changes to left/right counterpart

---

## 3. Color & Texture System

puppet-maker2 uses palette indices (1–114 colors) instead of hex strings.
We use hex strings directly — equivalent, just different representation.

- [x] **Skin colors** — outline (bg), fill (fg), pattern (p) per patch
- [x] **Bodyhair colors** — outline + fill
- [x] **Connected-skin colors** — outline + fill + pattern
- [x] **Connected-hair color** — outline (+ fill/pattern for masked textures)
- [x] **Haircut color** — tint via bgHex (+ fill/pattern for masked textures)
- [ ] **Procedural texture controls** per part:
  - `bgTex`, `fgTex` — index into `texture-type0.png` through `texture-type7.png`
  - `texScale` (1–9) — pattern tile scale
  - `texRot` (0–15) — pattern rotation in steps
  - `fgAlpha` (0–5) — foreground pattern opacity
- [ ] **Per-patch alpha** — bgAlpha, fgAlpha, lineAlpha for face skin patches

> We already have `textures/pat/type0-8.png` which match puppet-maker2's
> `bodytextures/texture-type0-7.png`. Our `pURL` field could reference these.

---

## 4. Creation Options

- [x] **Potato head** — isPotatoHead toggle
- [x] **Neck segments** — 0–5
- [x] **Torso segments** — 1–5
- [x] **Nose segments** — 0–5
- [~] **Has neck toggle** — neckSegments=0 achieves same result
- [~] **Physics hair** — skipped (won't implement)
- [ ] **Leg facing** — 'left', 'right', 'front' (affects foot stance angles)

---

## 5. Haircut / Head Hair

- [x] **Hair texture selection** — thumbnail grid
- [x] **Hair width** — width slider
- [x] **Start/end index** — which vertices hair follows
- [x] **Hair color** — bgHex tint (+ fill/pattern for masked textures)
- [x] **None option** — remove hair
- [ ] **Hair tension** — `extra.tension` (default 0.02), controls curviness
- [ ] **Hair spacing** — `extra.spacing` (default 5), point density along curve

---

## 6. Body Hair

- [x] **Bodyhair texture selection** — per-part (torso, head)
- [x] **Bodyhair colors** — outline + fill
- [x] **None option** — remove bodyhair
- [x] **Bodyhair growfactor** — slider (0.5–2.5), propagates to all torso segments

---

## 7. Limb Hair (Connected Hair)

- [x] **Texture selection** — thumbnail grid
- [x] **Width multiplier** — wmul slider
- [x] **Color** — outline (+ fill/pattern for masked textures)
- [ ] **Per-limb independent control** — currently shared via upper limb owner

---

## 8. DNA Structure Comparison

### What puppet-maker2 has that we need in `instance.dna`:

```lua
-- puppet-maker2 DNA:
dna = {
  creation = { ... },        -- ✅ We have this
  multipliers = { ... },     -- ✅ We use dims.sx/sy/h/w (equivalent)
  values = { ... },          -- ✅ We use appearance table (equivalent)
  positioners = { ... },     -- ✅ Implemented: eye, brow, nose, mouth, ear, leg
}

-- Our DNA structure (implemented):
instance.dna.positioners = {
  eye = { x = 0.2, y = 0.5, r = 0 },
  brow = { y = 0.8, bend = 1 },
  nose = { y = 0.5 },
  mouth = { y = 0.25 },
  ear = { y = 0.5 },
  leg = { x = 0.5 },
}

instance.dna.faceMagnitude = 1  -- global face feature scaler

-- Face data stored in appearance['face'] on head/torso1 part:
face = {
  eye =      { shape = 1, bgHex = '...', fgHex = '...', wMul = 1, hMul = 1 },
  pupil =    { shape = 1, bgHex = '...', wMul = 0.5, hMul = 0.5 },
  brow =     { shape = 1, bgHex = '...', wMul = 1, hMul = 1, bend = 1 },
  nose =     { shape = 0, bgHex = '...', fgHex = '...', wMul = 1, hMul = 1 },
  mouth =    { shape = 2, wMul = 1, hMul = 1, lipScale = 0.25,
               lipHex = '...', backdropHex = '...',
               upperLipShape = 1, lowerLipShape = 1 },
  positioners = { eye = {...}, brow = {...}, nose = {...}, mouth = {...} },
}
```

### Still missing from DNA:
```lua
-- Teeth (✅ implemented):
face.teeth = { shape = 0, bgHex = '...', fgHex = '...', hMul = 1, stickOut = false }

-- Face skin patches (not implemented):
face.patches = {
  snout = { shape = 1, sx = 2, sy = 1, r = 0, tx = 0, ty = 5, alpha = 5 },
  eye1 =  { shape = 1, sx = 1, sy = 1, r = 0, tx = -2, ty = 0, alpha = 5 },
  eye2 =  { shape = 1, sx = 1, sy = 1, r = 0, tx = 2, ty = 0, alpha = 5 },
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
- [x] **Symmetric editing toggle** — mirrors changes to left/right counterpart
- [ ] **Category navigation** — left sidebar with body part categories
- [ ] **Camera focus** — zoom/pan to selected part when switching categories
- [ ] **Part tabs** — hierarchical (e.g. mouth → upper lip / lower lip / teeth)

---

## 10. Randomization

- [x] **Basic randomize** — shapes, colors, bodyhair
- [x] **Symmetric color randomization** — torso segments share colors, head matches torso, feet/hands share colors, limb connected-skin/hair share texture + colors
- [x] **Randomize face** — eyes, pupils, mouth, brows (shapes, positions, sizes, colors)
- [ ] **Smarter randomize** — `randValue(min, max, step, preferMiddle)` avoids extremes
- [ ] **Linked colors** — hair, chesthair, armhair, leghair, brows share hair color
- [ ] **Randomize patches** — skin patch alpha/transform randomization

---

## 11. Save/Export

- [ ] **DNA save/load slots** — save multiple character presets
- [ ] **Screenshot export** — capture character at various resolutions

---

## Remaining Work Summary

### Editor features (no new rendering needed)
- [ ] **Hair tension/spacing sliders** — trace-vertices already support `extra.tension` and `extra.spacing`, just needs UI
- [ ] **Leg facing** — 'left'/'right'/'front' creation option

### Rendering + editor features
- [x] **Teeth** — shapes (teeth1-7.png), hMul, color, stencil-clipped or stick-out mode.
- [x] **Face skin patches** — patch1/2/3 overlays with transforms, OMP coloring. Accordion UI added.
- [x] **Bezier brow rendering** — 10 bend patterns, uses texturedCurve (slightly different control point interpolation than puppet-maker2)

### Animation (runtime, not editor)
- [ ] **Eye blink** — eyesOpen tween (0→1)
- [~] **Pupil look-at** — basic mouse follow with checkbox toggle implemented, needs polish (movement feel, eye-shape masking)
- [ ] **Mouth open/close** — mouthOpen/mouthWide tweens

### Nice-to-have
- [ ] **Linked color randomization** — share hair color across hair/bodyhair/armhair/leghair/brows
- [ ] **Smarter randomize** — prefer middle values, avoid extremes
- [ ] **DNA save/load presets**
- [ ] **Screenshot export**
- [ ] **Procedural texture controls** — texScale, texRot, fgAlpha per part
- [x] **Left eye horizontal flip** — render left eye with negative width

---

## Priority Order (suggested)

### Phase 1: Face rendering infrastructure ✅
1. ✅ Add `dna.face` and `dna.positioners` to DNA template in character-manager
2. ✅ Face rendering function: decal sfixtures with OMP compositing on head body
3. ✅ Head bounding polygon (shape8Dict vertices for eye/mouth positioning)
4. ✅ Decal rendering: positioned images at body-local coordinates

### Phase 2: Individual face parts ✅
5. ✅ Eyes + pupils (shape thumbnails, position, scale, color, rotation)
6. ✅ Eyebrows (shape, bend patterns, position, color — rendered as flat decal)
7. ✅ Nose (shape, position, scale — face overlay, mutually exclusive with nose segments)
8. ✅ Mouth (upper lip + lower lip as bezier curves, stencil-masked interior, 15 presets)
9. ✅ Teeth (shape, hMul, color, stick-out — rendered inside mouth stencil or over lower lip)
10. ✅ Face skin patches with transforms (patch1/2/3 overlays with OMP coloring)

### Phase 3: Animation
11. Eye blink tween (eyesOpen 0→1)
12. Pupil look-at tracking (follow mouse or target)
13. Mouth open/close tween

### Phase 4: Positioners & polish ✅
14. ✅ Ear position + stance angle controls
15. ✅ Leg stance width
16. Hair tension/spacing sliders
17. ✅ Bodyhair growfactor
18. ✅ Face magnitude global scaler
19. ✅ Ears over/under head toggle
20. ✅ Symmetric editing toggle

### Phase 5: Advanced
21. ~~Physics hair~~ — skipped
22. Procedural texture controls (texScale, texRot, alpha)
23. DNA save/load presets
24. Smarter randomization with linked colors
