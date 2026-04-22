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

### Point lights — deferred
Out of scope for v1. Would need per-pixel world-space position (extra
transform uniforms) or a body-center approximation (no falloff). Revisit
once directional is in.

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

All assume the world light is in place (1 and 2 especially).

1. **Warm/cool chromatic shading** — biggest tell separating stop-motion
   still from CG. Lit side shifts warm (amber/ivory), shadow side shifts
   cool (steel/blue). `shade = mix(coolColor, warmColor, lambert) * shade`.
   Uniforms: `warmColor`, `coolColor`. Pairs naturally with world light.

2. **Specular sheen** — tight `pow(lambert, specPow) * specStrength` lobe
   on top of diffuse. Catches the waxy plasticine highlight. Uniforms:
   `specPow`, `specStrength`. With world light, the sheen moves across
   bodies consistently as they rotate — strong claymation read.

3. **Voronoi thumbprint dimples** — layer discrete craters over the fBm.
   Current noise is too uniform; real plasticine has *hand-pressed* dents.
   Cellular / Voronoi noise at a larger scale, combined multiplicatively
   with the existing grain.

4. **Subsurface edge glow** — brighten the silhouette band where the
   form-normal tilts toward the light. Fake translucency. Cheap with the
   data we already have (alpha gradient + lambert).

5. **Low-freq pigment mottling** — coarse RGB jitter across the shape.
   Breaks the "flat paint fill" read; makes pigment feel hand-mixed. Cheap.

6. **Anisotropic tool marks** — stretched noise octave with a per-fixture
   direction. Carving/smoothing strokes. Per-fixture `toolMarkAngle`.

7. **Concavity AO** — sample alpha at a larger radius and compare to the
   current `avgAlpha`. Where the larger radius is less full, we're in a
   fold — darken. Makes joints/seams pop.

## Proposed order of work

1. **LIGHT sfixture subtype (directional only, TEXFIXTURE-only consumption).**
   Register the subtype, serialize/load, build the add-light affordance and
   inspector, draw the editor overlay glyph. Shader gets uniform-array light
   support with a sensible default when `lightCount == 0`. This is the
   infrastructure milestone — after this, additions 2–4 slot in naturally.
2. **Warm/cool chromatic shading** — uses light color per-light, defaulting
   to warm key + optional cool fill conventions.
3. **Specular sheen** — reuses the same lambert per light.
4. **Voronoi dimples** — orthogonal; layers on the grain path.
5. 5–7 as time allows; each is independent.

## Non-goals (for this document)

- Stop-motion frame stutter (12fps render sample-and-hold). Huge claymation
  win but is render-pipeline, not shader.
- Film grain / color grade as a fullscreen post-pass.
- Contact shadows under characters.

These would go in a separate "claymation post-processing" plan if/when we get
back to them.
