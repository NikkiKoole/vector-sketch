# Claymation Shader Plan

Roadmap for pushing the plasticine / hair shader look further, with a shared
lighting system at the center. Scope is the shader/material layer only —
motion stutter, film grain, post-processing, and contact shadows are separate.

## What we have today

`src/physics/box2d-draw-textured.lua`, wired on TEXFIXTURE,
CONNECTED_TEXTURE, TRACE_VERTICES. Plasticine + Hairs are mutually exclusive
per-fixture; Hairs wins.

**plasticine**
- fBm value noise → micro-normal (thumb-dent depth via `bumpAmp`).
- Alpha gradient from 4-tap ±formRadius samples → macro-normal (rounds the
  form) + rim darkening via the `avgAlpha` falloff.
- Half-lambert from a 2D `lightDir`, squared for soft matte shading.
- Per-fixture sliders: strength, scale, edge, bump, form strength/radius;
  Form / rim-style toggles.

**hairs**
- Stretched vnoise for strand shading (low-freq along uv.x, high-freq uv.y).
- Noise-modulated alpha near uv.y edges (fray).
- Bushy growth: at transparent mesh pixels, sample neighbors to find hair,
  then 2-octave noise decides whether to paint — RGB comes from alpha-weighted
  neighbor samples (not vertex color, which is (1,1,1) for OMP).
- Per-fixture sliders: strength, density, fuzz, bush (0..3).

## Centerpiece — lights as a new sfixture subtype

### Problem
`lightDir` is currently a UV-space vec2 set per-fixture. Body rotates → UV
rotates with it → the "lit side" follows the body, not the world. A Mipo
flipped upside down has its highlight still on the same texture side.

### Target
Lights become first-class scene objects: a new **LIGHT** sfixture subtype
that you place on any body. Light direction comes from the light-body's
rotation (or position, for point lights); multiple lights can coexist; they
save with the scene and can be parented to characters (held lantern, etc.).

### Sfixture schema
New subtype `LIGHT` alongside ANCHOR / SNAP / MESHUSERT / TEXFIXTURE / etc.
The fixture's shape is just an anchor on a body — no collision, purely a
marker. Extras (v1, directional-only):
```
extra = {
    color     = {1.0, 0.95, 0.85},  -- warm off-white default; tints the lit side
    intensity = 1.0,                 -- scalar on its contribution
}
```
**Direction convention:** the light aims along the host body's local `+X`
axis in world space: `dir = (cos(body:getAngle()), sin(body:getAngle()))`.
Rotating the body rotates the light.

### Shader consumption
Plasticine shader grows a small uniform-array for N lights (cap at e.g. 4):
```glsl
#define MAX_LIGHTS 4
uniform int   lightCount;
uniform vec2  lightDir[MAX_LIGHTS];       // body-local (pre-rotated on CPU)
uniform vec3  lightColor[MAX_LIGHTS];
uniform float lightIntensity[MAX_LIGHTS];
```
Per-draw, CPU iterates registered LIGHT sfixtures, converts each light's
world direction into the current body's local space (same rotation trick as
the global-light plan had), and sends the resulting array. Inside the
shader: loop, accumulate `lambert * color * intensity` contributions per
light, output the sum.

Falls back to a single default "ambient key" direction when `lightCount == 0`
so scenes without explicit lights still shade.

### Point lights — landed (2026-04-23)
LIGHT subtype supports `lightType = 'directional' | 'point'` with a `range`
field in world units for point falloff. Point contributions use a
smoothstep falloff over `range`. Directional lights ignore position.

### Natural ceiling on light count
`MAX_LIGHTS = 4` is a soft cap, not a hardware limit — picked to match a
cinematic setup (key + fill + rim + one accent/kicker). For stylized
children's-book scenes that covers nearly every composition, and the
per-pixel shader loop stays fast. Raising to 8 is free if a scene calls
for it; beyond that, switch to distance-culling point lights on the CPU
before uploading the array rather than bumping the cap further.

### Ribbons — out of scope for first pass
CONNECTED_TEXTURE / TRACE_VERTICES UVs are along-length / across-width, not
body-local. Mapping world light into ribbon-tangent space per-segment means
the shader needs the ribbon's local tangent at each sample, which varies
along the curve. Skip for v1 — ribbons stay lit in their own UV frame.

### Authoring flow
No dedicated "add light" shortcut. Users:
1. Place a normal body in the scene (typically set to **static** so it stays
   put — but dynamic lights carried by characters work too).
2. Select it, attach a LIGHT sfixture via the existing add-sfixture UI.
3. Rotate/move the host body to aim the light.
4. Inspector panel in `sfixture-editor.lua` exposes `color` (palette/hex) and
   `intensity` slider.

### Editor overlay
Lights are runtime-invisible. In the editor, draw a small sun glyph at the
host body's world position + a direction arrow for the `+X` axis, tinted by
`extra.color`. Reuse the existing sfixture overlay pass so lights are
selectable/highlightable like anchors.

### Defaults & fallback
- `color = {1.0, 0.95, 0.85}`, `intensity = 1.0` on create.
- When the scene has zero LIGHT sfixtures, the shader falls back to a baked-in
  neutral direction `(-0.7, -0.7)` with color `(1, 1, 1)` so new / unconverted
  scenes still shade.

### Open questions
- Does the light sfixture persist in scene JSON via the standard
  `extra`-serializer path, or do we need special handling? Likely standard —
  `color` + `intensity` are plain tables/scalars.
- Per-light body-mask ("this light only lights these bodies") — probably no
  for v1; keeps the shader loop trivial.

## Shader additions — ranked by claymation payoff

LIGHT system is in place (directional + point), so items below can now
reference real light directions/colors instead of the baked default.

1. **Warm/cool chromatic shading** — biggest tell separating stop-motion
   still from CG. Lit side shifts warm (amber/ivory), shadow side shifts
   cool (steel/blue). `shade = mix(coolColor, warmColor, lambert) * shade`.
   Uniforms: `warmColor`, `coolColor`. Pairs naturally with world light.

2. **Specular sheen** — tight `pow(max(nDotL, 0), specPow) * specStrength`
   lobe on top of diffuse, summed per light. Catches the waxy plasticine
   highlight. Uniforms: `specPow`, `specStrength`. With real lights, the
   sheen moves across bodies consistently as they rotate — strong
   claymation read. Cheapest-to-best-looking ratio; do this first.

3. **Terminator tightening** — one-line tweak to the half-lambert falloff
   curve, e.g. `pow(nDotL * 0.5 + 0.5, 1.4)` instead of squaring. Gives
   the tight, sculptural Disney/Pixar light-to-shadow transition that
   reads as hand-posed rather than softly CG-lit. No new uniforms; just
   a shape parameter on the existing lambert term.

4. **Opposing-light rim tinting** — the existing rim darkening goes
   black; replace with a tint driven by the light(s) whose direction
   most *opposes* the macro-normal. Warm key on the front → cool rim
   from a fill on the back is the classic stylized setup, essentially
   free once lights are plumbed. Subsumes / refines item 5 below.

5. **Voronoi thumbprint dimples** — layer discrete craters over the fBm.
   Current noise is too uniform; real plasticine has *hand-pressed* dents.
   Cellular / Voronoi noise at a larger scale, combined multiplicatively
   with the existing grain.

6. **Subsurface edge glow** — brighten the silhouette band where the
   form-normal tilts toward the light. Fake translucency. Cheap with the
   data we already have (alpha gradient + lambert).

7. **Low-freq pigment mottling** — coarse RGB jitter across the shape.
   Breaks the "flat paint fill" read; makes pigment feel hand-mixed. Cheap.

8. **Anisotropic tool marks** — stretched noise octave with a per-fixture
   direction. Carving/smoothing strokes. Per-fixture `toolMarkAngle`.

9. **Concavity AO** — sample alpha at a larger radius and compare to the
   current `avgAlpha`. Where the larger radius is less full, we're in a
   fold — darken. Makes joints/seams pop.

## Proposed order of work

1. ~~**LIGHT sfixture subtype (directional, TEXFIXTURE consumption).**~~
   ✅ Landed 2026-04-23. Directional + point with range, up to 4 lights
   via uniform array, baked default when `lightCount == 0`.
2. ~~**Specular sheen**~~ ✅ Landed 2026-04-24. Blinn-Phong per light,
   summed into output. Uniforms: `specPow`, `specStrength`.
3. ~~**Terminator tightening**~~ ✅ Landed 2026-04-24. `pow(nDotL * 0.5 + 0.5, terminatorPow)`.
4. **Opposing-light rim tinting** — swap the black rim for a color
   pulled from the most-opposing light. Reuses existing alpha-gradient
   rim pipeline.
5. ~~**Warm/cool chromatic shading**~~ ✅ Landed 2026-04-24. `mix(coolColor, rawTint * warmColor, attenBlend)`.
   Also added SSS approximation (back-face scatter * thinEdge) and pigment mottling.
   Full pipeline ported to hairs shader + CT ribbons. All params in UI.
6. **Voronoi dimples** — orthogonal; layers on the grain path.
7. Remaining items as time allows; each is independent.

## Non-goals (for this document)

- Stop-motion frame stutter (12fps render sample-and-hold). Huge claymation
  win but is render-pipeline, not shader.
- Film grain / color grade as a fullscreen post-pass.
- Contact shadows under characters.

These would go in a separate "claymation post-processing" plan if/when we get
back to them.
