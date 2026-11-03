# Shader looks — shaders as part of the engine, not stuck in a scene script

status: active

The burrow earth and the sea (2026-11-03) both came down to "a shader paints this area", and both
live in a scene script (`scripts/spikes/burrow.playtime.lua`, `scripts/spikes/sea.playtime.lua`).
Nikki: "if we generalise this, using some shaders here and there for some greatness, can we make
something in the playtime editor for that, so it becomes sort of a part of the engine". Shaders are
already used on the Mipos themselves (`src/render/shaders.lua`, the clay light: CLAYMATION-SHADER-PLAN),
which is a third place and stays as it is.

## Two places a shader goes

**1. Looks on shapes: a `shader fill` sfixture.** Draw any shape, add the sfixture, pick a look
from a list (earth, sky, water, stone, stars, lava...). It works like grass and liquid
(`src/grass.lua`, `src/liquid.lua`): one subtype, saved in `extra`.
- The look is painted from world position, not from the shape, so it stays put while the shape
  moves through it, and two shapes next to each other join with no seam (why the burrow's chunks
  and wall line up).
- Each look declares its settings (`params`), and `src/ui/inspector.lua` builds the sliders from
  them, as it does for behaviors.

**2. Scene effects: a stack in world settings.** Effects that need the whole picture: the
scene draws into a canvas, then the effects run over it. Water bending what's behind it, a colour
grade (golden hour, night), a vignette, paper grain, a soft glow. Each is switched on and tuned per
scene, saved with the scene.

The sea is a bit of both: its water look is (1), its bending is (2), and the waves and floating stay
code (later maybe a "sea" behavior).

## One file per look

`looks/<name>.lua` returns the GLSL, its `params` (with defaults and ranges), and a `PHONE` version
when the full one is too heavy (the sea's way: `#define PHONE` on iOS/Android). The engine finds the
files in the folder, so adding a found or written look is adding one file. Effects the same way,
`looks/effects/<name>.lua`.

## Where to borrow from (licences matter: the apps are sold)

- **Shadertoy**: the biggest pile, but its default licence is CC BY-NC-SA 3.0 (no commercial use)
  unless the author says otherwise in the shader. Learn from it, don't copy from it without a
  licence in the header. **The sea's caustic is "after joltz0r" from Shadertoy**: replace it with our
  own, or check its licence, before the sea ships.
- **moonshine** (github.com/vrld/moonshine, MIT): LÖVE post-processing, made for our setup; blur,
  vignette, film grain, glow, CRT, colour grading. The start for (2).
- **webgl-noise** (stegu / Ashima, MIT) and **Dave Hoskins's "hash without sine"** (MIT): the
  building blocks of most looks.
- **LYGIA** (lygia.xyz): big and good, but non-commercial unless you're a sponsor or buy a licence.
- **Inigo Quilez's articles** (iquilezles.org): the best place to learn how (noise, palettes, distance
  shapes); check each shader's header for its licence.
- **dreamengine**'s `runtime/shadermath.h`: Nikki's own distance shapes and cosine palette.

The habit: ideas from anywhere, code we write or take from MIT sources; say where it's from in a
comment at the top of the look.

## Steps

- [ ] **SH1. The `shader fill` sfixture, with earth as the first look.** A subtype in
      `src/subtypes.lua`, drawn in the textured world at its z, the look picked from `looks/`,
      sliders from its `params`. The earth shader moves out of the burrow script into
      `looks/earth.lua`; the burrow then uses it (wall and chunks are the same look, `wall` a
      setting). Check: draw a shape in the editor, pick earth, it looks like the burrow.
- [ ] **SH2. Sky as a second look.** From `../sky-atmosphere/` (WORLD-BUILDING G5): altitude from
      world position, the colour stops as settings. Needs the G5 questions answered (colours, how
      high space is, time of day per scene) or a simple first version.
- [ ] **SH3. The scene effects stack.** The canvas from the sea (`drawBelow` to `draw`) moved into
      main.lua's draw, only when a scene has effects on; a list in world settings, saved with the
      scene. First effects: colour grade, vignette, paper grain (moonshine as the reference).
      Fix the seam on the way: `omp-bake` calling `setCanvas()` drops the scene canvas for a frame
      (SEA.md).
- [ ] **SH4. Water as a look + the bending effect.** The sea's water shader split into a look (the
      colour with depth, caustics, rays) and an effect (refraction, which needs the canvas). Our own
      caustic instead of the Shadertoy one.
- [ ] **SH5. More looks, as they're wanted.** Stone, wood, stars, lava, wallpaper... one file each.
- [ ] **SH6. On the phone.** Each look and effect measured on the iPhone SE 2 (`./playtime.sh bench
      device`); a scene with a full-screen look plus two effects stays at 60 fps.

## Open questions

- Does a look stay on the world grid when its body moves (the burrow's way), or ride along with the
  body (a stone that falls)? Probably a setting: `world` or `body`.
- Effects per scene only, or per room as well (WORLDS-AND-DOORS)? Per scene first.
