# Clouds — painted by a shader, the real kinds at their own heights

status: parked — kept as a spike: "pretty good" (tried 2026-11-03: shader clouds after Puppetmaker 2's, then the real kinds in layers)

The spike is `scripts/spikes/clouds.playtime.lua` (scene `clouds`). It started from Puppetmaker 2's
brushy clouds (`../puppet-maker2/assets/world/clouds1.png`, `worldparts/clouds3.png`): could a
shader make them, many of them, moving? Then: real clouds in the layers of the atmosphere.

How it's made:
- **No pictures.** Each cloud is one quad; the shader paints it from a seed. Lobes breathe and
  drift, so a cloud slowly changes shape. Heaped clouds are one shape (the union of their lobes),
  lit as a whole: light on the sun's side and on top, grey towards the flat bottom, a lit edge
  near the sun.
- **The real kinds** (WMO cloud atlas levels, temperate: low under 2 km, middle 2-7, high 5-13;
  here 1 km = 1000 world units, so a Mipo dragged up reaches the low ones):
  cumulus (flat bottoms all at one height, the cauliflower on top), stratocumulus (a row of grey
  lumps), cumulonimbus (a tower with a dark base and a flat anvil; it rains), altocumulus (small
  cells in slanted rows, the mackerel sky), altostratus (a grey veil the sun shines through),
  cirrus (thin hooked strands, on a faster wind).
- **Weathers** (`w`): fair, mackerel sky, grey, storm: how many of each kind per layer.
- **Six layers at different distances**, parallax. Each has its own camera: it follows the real
  one by its distance and zooms by a power of it, so far clouds hardly grow when the camera
  zooms in on a Mipo. Far clouds are paler and crowd towards the horizon, which is at eye level
  (far hills in between, drawn at fixed places in the landscape so panning doesn't make them jump).
  The front layer goes in front of the Mipos. Near clouds cast shadows on the grass.
- **Play:** drag a cloud and fling it; shake it and it goes grey and rains; tap it and it parts in two.
- Panel: wind, morph, strokes, grain, light. Nikki's settings are the defaults: no brush strokes,
  no grain, strong light.

What Nikki said along the way: the first look had pixel-sized grain and hair strands ("i also
dont like the loose pixels": gone, no specks); near clouds at the top looked weird (they zoomed
with the camera); "the clouds feel very close and there arent many when you drag up" (layers
pushed back; the real kinds at their heights instead of a band); the middle hill band jumped on
a pan (fixed).

The noise and the shapes are written here, nothing copied from Shadertoy (SHADER-LOOKS.md).

Not done / open:
- [ ] On the phone: not measured. Each cloud runs fbm a few times per pixel (heaped ones three
      times, for the lighting); big near clouds cover a lot of screen.
- [ ] Clouds as a look in the engine (SHADER-LOOKS SH2, the sky), with `../sky-atmosphere/`'s day
      and night colours.
- [ ] Flying a Mipo up through them hasn't been tried by hand yet.
