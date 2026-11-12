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
- [ ] **CG3. Its life.** Young clouds crisp, older ones ragged, evaporating at the edges into dry
      air. A big one hits the lid and spreads into an anvil; the base goes heavy and dark, it rains
      (the existing drops), a cold downdraft under it, then it dies.
- [ ] **CG4. Real light.** Self-shadowing towards the sun in the shader: bright tops, bellies grey
      by depth, a silver lining with the sun behind, the sky's hour colours (SKY).
- [ ] **CG5. Wind with height.** Faster wind higher up leans towers and stretches tops; the
      existing fling and shake become pushes on the thermals.
- [ ] **CG6. On the iPhone SE 2** (`./playtime.sh bench device`), then: into the engine with the
      sky as a scene setting (ENGINE-MERGE EM7)?
- [ ] **CG7. Later, only if wanted:** the Harris grid as its own spike, if thermals look too
      blobby and real swirls and wisps are wanted.
