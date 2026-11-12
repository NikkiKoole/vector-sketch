# Clouds — painted by a shader, the real kinds at their own heights

status: active — growing clouds with real physics (CG1-CG6); the shader clouds spike kept as it is (tried 2026-11-03, "pretty good")

**Nikki's favourites** (2026-11-04): the sea, the burrow and the clouds inspired her most of all the spikes. Hand-drawn assets come first from now on; these are where a shader earns its place.

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

- **Cotton** (2026-11-04, slider, default 1): cotton wool balls after mood picture 11: a lumpy
  edge with short tangled fibres, round all over (no flat bottom), white with a warm grey
  underneath instead of a blue belly. 0 is the real clouds.
- **The ground a little 2.5D** (2026-11-04): physics-testbed downhill's top band and side face in
  Nikki's grass patterns (`textures/world/grasspattern2/4.png`, from the testbed), a row of blades
  behind the Mipos and one in front of their feet; with scrolling-world's ground-plane perspective:
  the back edge further away (pulled in to the middle of the view), the front nearer, the line the
  Mipos stand on in between. Sliders: back, front, behind, infront, blades.

Not done / open:
- [ ] On the phone: not measured. Each cloud runs fbm a few times per pixel (heaped ones three
      times, for the lighting); big near clouds cover a lot of screen.
- [ ] Clouds as a look in the engine (SHADER-LOOKS SH2, the sky), with `../sky-atmosphere/`'s day
      and night colours. Sky and clouds as a scene setting: into the engine (Nikki 2026-11-10, LANDING-2026-11.md).
- [ ] Flying a Mipo up through them hasn't been tried by hand yet.

## Growing clouds (plan, 2026-11-12)

Nikki: "make it more physical and realistic so one can 'grow' a cloud and behaves more like a
real one". Grow by **painting moisture** or **pulling a cloud up with a finger**; the timescale
**toy-like for now, with options to slow it down** (towards real: a cumulus lives 15-30 minutes).

What was looked at (2026-11-12):
- Harris 2003, *Simulation of Cloud Dynamics on Graphics Hardware*: a fluid grid with velocity,
  pressure, temperature, vapour and cloud water; condensing releases heat (the cloud lifts itself),
  cloud water weighs it down. Our side view would be a 2D vertical slice: swirls and wisps for free,
  but a pressure solve every frame. Kept as the later option (CG7).
- Goswami & Neyret 2017 (landscape convective clouds) and the 2019 cloud-map paper: **thermals**,
  big rising parcels each with its temperature and moisture, against the air's profile. Condense at
  the condensation level (flat bases, all at one height), rise to where they're no warmer than the
  air (the top; an anvil under a stable lid), mixed away by dry air around them. Cheap: plain Lua.
  **The choice.**
- Dobashi 2000's cellular automaton: cheap, but clouds keep appearing and vanishing (the paper says
  so). Not used.
- Lighting: Beer's law through the cloud, "powder" darkening that brings out the bumps,
  forward scattering for the silver lining (Horizon Zero Dawn's clouds). In 2D: march towards the
  sun through the cloud's water.

The physics in short: a parcel lifted cools ~10 °C/km while dry, ~6 °C/km once it's cloud (the
heat its water gives off); the air around it has its own profile. Warmer than the air: it rises
(buoyancy), cloud water drags it down. Its vapour above saturation condenses (saturation falls
steeply with cold), below evaporates. Pulled up past the point where it's warmer than the air
(level of free convection) it **goes on by itself**: the toy's best moment.

- [ ] **CG1. The air's profile.** A panel: ground temperature, humidity, how fast the air cools
      with height, a stable lid (height, strength), and a **time** slider (toy .. real). Faint
      lines for the condensation level (where bases sit) and the lid.
- [ ] **CG2. Paint moisture, pull clouds up.** A finger in the sky paints moist air (seen as a
      faint shimmer). Moist air is a set of thermals; drag one (or a cloud) up and it cools, turns
      to cloud at the base line, and past the free-convection level carries on alone, turrets
      climbing; drag it down and it warms and fades. The thermals are the lobes of the existing
      shader, so the look stays.
  Built 2026-11-12, for Nikki to try (scene `clouds`, play mode; `e` or the panel's checkbox
  switches between growing and the old sky): the physics in `src/cloud-air.lua` (pure, spec
  `spec/cloud-air_spec.lua`: bases ~125 m per degree of dew point spread, taking off past free
  convection, stopping under the lid); the thermals live in layer 5 (1 unit = 1 m). Press on clear
  sky and drag to paint moist air (97% humid, a little warm: near the ground it rises by itself);
  press on a cloud or shimmer to pull the whole cloud it's part of, let go with a flick and it keeps
  the speed. Lines: cloud base, goes on by itself, lid. Time x25 by default (x80 was gone in 6 s).
  Seen in screenshots: a pulled cloud climbs to the lid in ~5 s, spreads under it and tatters away;
  painted air low down becomes a flat-based cloud that stays under the take-off line.
  Painting changed 2026-11-12 (Nikki: "i just want to paint clouds and have them be friendly, do
  not care about the rain just yet"): a dab is cloud straight away (`cloudAir.newCloud`), as heavy
  as the air, and it **floats** where it's put, fading over minutes; painted ones don't push each
  other apart. Pulled and let go gently it floats again where it's left; flung, or lifted past
  the take-off line, the air takes over (rises to the lid, or sinks and clears).
- **Smoke** (2026-11-12, Nikki: "imagine a fire we get smoke right? not clouds, its kinda different
  but sort of the same"): tools 1 cloud / 2 smoke / 3 boom (panel buttons). Smoke lights a fire
  where pressed (8 s, dragging lights more); a boom throws out 18 hot puffs (they glow orange while
  hot, `cloudAir.glow`) and some dust, with a flash. The puffs are `cloudAir.newSmoke`: much warmer
  than the air, they shoot up, take in air (growing, thinning, cooling), slow and spread; burning
  gives off water, so a plume reaching the cloud base grows a white cap (pyrocumulus). Drawn by
  the cloud shader's smoke mode (billowy, soft edges, see-through where thin, dark in the middle),
  before the clouds. Puffs lying mostly over each other merge (260 overlapping puffs made bands
  and blocks in the tiles, Nikki's screenshot): ~10 for two fires.
- [ ] **CG3. Its life.** Tried 2026-11-12 and taken out again (Nikki liked the clouds better
      before it; rain not wanted yet): rain from 0.8 g/kg of cloud water weighing the cloud down,
      its evaporation cooling it until it sank (a shower ending its own updraft; under a higher lid
      more rain, a longer life), drops reaching the ground or drying up halfway, a dark belly,
      lobes flattening into an anvil at the lid, dying clouds going ragged. In git: commit ad1f56a1,
      reverted; back to it when rain is wanted.
- [x] **CG4. Real light.** Kept 2026-11-12 (Nikki: "ok fine"). Self-shadowing towards the sun in the shader: bright tops, bellies grey
      by depth, a silver lining with the sun behind, the sky's hour colours (SKY).
  Built 2026-11-12, for Nikki to judge: the cloud shader looks for cloud between each pixel and
  the sun (4 samples, 180 m apart) and above it (2), each counting as at most solid cloud (where
  many lobes overlap the field passes 1); the sunlight that gets through, exp(-that), shades the
  first light (which keeps the bumps and lit edges) from white towards the sky's blue-grey (warm
  grey with cotton); a bump's middle a little brighter than its thin edge (powder); the thin
  edge near the sun lit (silver lining). Slider 'light through cloud' (0 = the first light).
  First try was black inside a big heap (the overlapping field summed to ~25). 60 fps on the Mac
  with ~16 lobes; the hour's colours not yet (the spike has its own sky).
- **Billows** (2026-11-12, Nikki: "i would like to see what you got for better cloud shapes"): painted
  clouds came out as smooth potatoes (lobes melting into one blob). Domes packed in cells (a
  jittered grid, each its own size) at two sizes, 230 m and 95 m: bumps on bumps push the outline
  out and in, each dome lit on its own (bright towards the sun and on top, dark in the creases),
  churning slowly upwards. Slider 'billows' (0 = smooth). Nikki: "i dont like how the billows
  are sort of screenbound": the domes and noise were fixed in the sky while clouds drifted through
  them. Now each lobe carries how far it has moved since it was made (lobeShift, wraps and smoke
  merges kept steady) and the pattern is read back by the lobes' weighted move, so it travels with
  its cloud (and smoke). Nikki's settings then: light through cloud 0, billows 0.34, cotton 0.22.
- [ ] **CG5. Wind with height.** Faster wind higher up leans towers and stretches tops; the
      existing fling and shake become pushes on the thermals.
- [ ] **CG6. On the iPhone SE 2** (`./playtime.sh bench device`), then: into the engine with the
      sky as a scene setting (ENGINE-MERGE EM7)?
- [ ] **CG7. Later, only if wanted:** the Harris grid as its own spike, if thermals look too
      blobby and real swirls and wisps are wanted.
