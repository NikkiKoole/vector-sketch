# Materials — felt, moss, cardboard, cellophane: the craft-table look at runtime

status: active

**Where it stands (2026-11-06, end of the day).** Materials are now *how Nikki's drawn pictures take
the light*: the picture's mask, its roundness baked from the mask, one shader with a mode or a row of
numbers per material, her outline on top. The workbench is the scene `material-check`
(scripts/tests; its keys in the script's top comment and on its status line): 36 materials on one
shape (n: hearts, ears, a snout, a foot, legs…), leaves, smoke, a striped shape sliding behind for the
see-through ones, the light at the mouse (b behind), k creases from the inner lines, u/i/y a second
material in the pattern, x measures what each costs. A panel on the right (2026-11-06, Nikki: "easier to tweak") has all of it as
buttons that step through choices, checkboxes and sliders (light height, crease depth, pattern size,
paint steps, wet, wind: continuous there, the keys step them); – folds it. To open it next to the shared game: a second
LÖVE with `PLAYTIME_BRIDGE_PORT=8002`, then load material-check there. Nothing is in the engine yet (MT6); it all lives in that
scene. What we found:
- **Drawn beats generated.** The first spike (noise only) read as "computer"; on her pictures the
  same tricks read as made: metal, glaze, candy, velvet, wood, leather. The weakest are the cell
  grains (stone and wet stone look like a turtle shell) and the pale ones in full sun (paper, plaster).
- **The roundness only knows the outline**: every shape is a dome or a cushion. A brushy mask
  (body-04's streaks) shows in shiny materials as ridges, like hammered tin. Her inner lines now dent
  it (MT10, k: best on the snout's nostrils; on ears with thick close lines the drawn line hides it);
  more inner shape needs a painted height picture (MT11).
- **Two materials on one part come cheap from its pattern** (MT3a): the pattern a Mipo part already
  wears says where the second material goes (velvet with brass stripes on a leg). A drawn material
  map (MT3, A16) only for splits that don't follow the pattern (a sole on a foot).
- **See-through works** (glass, ice, bubble, clear candy, amber): what's behind, bent by the roundness.
  It needs what's behind drawn into a canvas first, so in a real scene it rides on SH3's effects stack.
- **The phone can afford most of it** (iPhone SE 2, MT18 below): lights, metal, gloss, see-through,
  velvet anywhere; noise grains and fur on things, not on walls and ground; the cell grains (stucco,
  stone, leather, tin, mud, ice) baked into a picture once, or only on small things.
- **Next**: Nikki judges which read as hers (MT2), the creases (MT10) and the pattern pairs (MT3a)
  too; she draws hatching sheets, height pictures, a material map and smoke puffs (THINGS-TO-DRAW
  A14-A17); then the liked ones become a texfixture setting (MT6), with the pattern pair as its
  second material.

Nikki's AI pictures, made for mood and **not to be used in the game** (not drawn by us, not shipped):
`docs/inspiration/ai-materials/` (16, 2026-11-04). They show Mipo's world as a handmade
diorama on a table. Below is what each material is made of, and how we could get it at runtime
without the pictures. Most of these are a *look* for the shader fill in SHADER-LOOKS (SH1, SH5),
an edge for a shape, or a scene effect (SH3).

What all 16 pictures share, and what makes them read as "made by hand":
- **Everything sits on a slab** (wood disc, cardboard sheet, moss mat) with a visible cut edge,
  in front of a **coloured paper wall** with a faint grain (yellow, lilac, mint, salmon).
- **Soft light from the top left**, soft contact shadows under each thing, no hard black.
- **The background is out of focus**, the front sharp: the miniature look.
- **Edges carry the material**: felt fuzz, torn paper, corrugated cardboard, moss clumps. The
  inside of a shape is mostly flat colour with a fine grain. So the cheap way is to spend on the
  edge and keep the fill simple, which fits our outlined look.
- **Bits scattered along surfaces**: pebbles, tiny flowers, tufts, shells.

## The materials

| material | where (picture) | what it is | how, at runtime |
|---|---|---|---|
| **Felt / wool** | 02, 04, 05, 09; the Mipos' bodies | matte, fine fibre grain, a halo of loose fibres at the edge, a bit puffy, darker where needle-poked | fill: a fibre noise (stretched in random directions) multiplied in, low contrast. Puffy: fake height from the distance to the edge, lit from the top left (the plasticine shader already has the lights). Edge: a fuzz ribbon along the outline, short strands sticking out |
| **Felt appliqué** (dots, patches, shapes) | 02, 04, 08, 09 | flat cut pieces on top, a thin shadow on one side | decals/shapes drawn twice: a dark copy offset down-right, then the piece. Already possible with decals |
| **Moss / flock** | 03, 08, 09, 15 | clumps of several greens, bumpy top edge, yellow specks | along the ground's top edge: stamp clump blobs (a few drawn clump pictures, or circles), each tinted from a palette of 4 greens, lit on top. Inside: noise speckle. An edge for the `grass` sfixture |
| **Cellophane water** | 07, 12, 14 | crumpled plastic: flat facets in blues/teals, white glints along the creases, see-through | Voronoi cells, each with its own random tilt → flat-shaded facets; bright at cell borders facing the light; cells drift slowly so it crinkles. Alpha so things behind show. **Our own code, so it can replace the sea's borrowed caustic (SH4)** |
| **Cardboard** | 10, 11, 12, 14, 16 | beige-brown, paper fibres, corrugated stripes at cut edges, torn spots showing the layer under | fill: paper grain. Edge band: stripes along the outline (a ribbon with a stripe texture, like CONNECTED_TEXTURE). Torn: the outline wobbled by noise, with a lighter, slightly bigger copy underneath |
| **Collage / torn paper** | 03, 10, 11, 12 (sails, roof, walls, bunting) | pastel patches, rough white fringe | patches clipped to the shape (stencil), slight random turn; the torn edge from above with a white under-layer |
| **Hard candy / gummy** | 01, 15 (jars) | see-through, glowing inside, cracks inside, one sharp highlight, coloured shadow | shader on a circle/ellipse: brighter and more saturated where thicker (distance to edge), Voronoi crack lines inside, a highlight spot top left, the shadow tinted with its own colour |
| **Jellybeans / speckled** | 06 | matte, speckled, a few striped | flat colour + speckle noise + top-left shading. Cheap; many can share one baked picture tinted |
| **Crayon / wax pencil** | 01, 06, 11, 13 (sun, scribbles, fish, creature) | strokes that skip on the paper's tooth | stroke alpha = the pressure against a paper-tooth noise (fixed in world space, so it doesn't swim). Fits Nikki's own hand-drawn lines; could be an option on outlines |
| **Paper wall** | all | coloured paper, faint fibres, the wall curving into the floor (02) | one fullscreen shader or a texture made once at load: colour + very low-contrast fbm + fibres, a soft gradient where it bends. The clouds' sky shader is the place for it |
| **Twigs, rope, pipe cleaner** | 03, 08, 09, 14 (ladders, fences, vines, palm trunks) | bark lines along the length; twisted rope; fuzzy chenille | ribbons along a path with a repeating texture; wrapped twine = stripes across; chenille = fuzz on both sides + a bump every so often |
| **Brass / tin** | 02, 05, 07 (bells, tin can) | shiny, warm, a bright stripe | a **matcap**: a tiny picture of a lit sphere of that metal, looked up by the fake normal. Also good for glass and candy |
| **Cotton wool clouds** | 11 | white, fibrous soft edge | the clouds spike with a fibre edge instead of the smooth one (CLOUDS.md) |
| **Earth strata** | 15 | layers of earth, each with a torn top edge and a paper/clay grain | the burrow earth as stacked torn-paper layers instead of a realistic soil (BURROW.md) |

## Ways that cover many at once

1. **Fake height from the shape.** Distance to the edge (exact for circles/capsules; for any
   polygon or picture, a blurred mask baked once) gives a height. A height gives a normal, a normal
   gives light, a matcap, the candy's thickness, the felt's puffiness. One trick, most materials.
2. **Edges as their own thing.** A ribbon along the outline with a material: fuzz, corrugation,
   moss clumps, torn white paper, crease glints. Ribbons we have (`src/render/ribbon.lua`).
3. **Noise written by us** (Voronoi, fbm, fibres), no Shadertoy (SHADER-LOOKS licences).
4. **Bake what doesn't move.** Ground, walls, houses and props are drawn into a canvas once with
   their material, then just drawn. Only water, Mipos and things in motion pay per frame. The
   iPhone SE 2 is the floor.
5. **Scene effects (SH3):** the paper wall, a blur on the far parallax layers (made once, they're
   still), soft contact shadows, a warm grade.
6. **Scatter dressing:** pebbles, tiny flowers, tufts placed along a ground edge from a seed.

## First tries, if we pick this up

- Cellophane water: the sea with Voronoi facets (also gets rid of the borrowed caustic).
- The paper wall + far-layer blur in the clouds scene: the cheapest big change in feel.
- Felt on a Mipo part: fuzz edge + fibre grain + puffiness, next to the plasticine shader, so we
  can compare.
- Moss edge on the ground, with a scatter of pebbles and flowers.

## The spike (tried 2026-11-04): "not looking too great", a good outcome too

`scripts/spikes/materials.playtime.lua` (scene `materials`): every material from one shader, no
pictures, on a little diorama (paper wall, crayon sun, cardboard slab with moss, felt ball and
block, collage box, bells, candies, jellybeans, cellophane water). Parked as a spike. What we learnt:
- Noise alone reads as "computer": the crayon sun, corrugated face and moss were the closest; the
  felt grain made a triangle grid until its fibre directions wandered.
- Candies as perfect circles look like plastic balls; jellybean speckles too regular.
- The cellophane (Voronoi cells, each tilted) looked like broken glass / stained glass: round
  cells all one size, a smooth top edge, one flat layer. Take two: `CELLOPHANE-WATER.md`.
- Real photos or scans of real felt, moss and torn paper would beat the noise (not the AI pictures).

## Take two: materials on the drawings (2026-11-06)

What changed since the spike: the light on Nikki's own pictures (LIGHT-AND-SHADOW LS5, the plaster
wall) was liked, the noise-made materials were not. So now a material is only *how a drawn picture
takes the light*: the picture's mask, its roundness baked from the mask (`src/render/form-bake.lua`,
now in the script sandbox as `formBake`), one shader with a mode per material. Her outline stays on
top. Workbench: scene `material-check` (scripts/tests), each row the same picture, so the material is
the only difference; the light is the mouse, in front or behind (b). Keys in the script's top comment.

Kinds of material, by what the shader does differently:
- **matte grain**: clay, plaster (LS11), felt, rubber, stucco
- **gloss**: leather, glazed pottery, plastic, wet
- **metal**: the room reflected (bright above, a dark band at the horizon, the warm floor) plus a
  highlight in the metal's colour; no matcap picture needed
- **sheen**: velvet, cotton, satin: the middle soaks up the light, the edges shine
- **see-through**: leaves, ears, wax, candy: from behind the light comes through, most at the thin edges
- **smoke**: not a surface; drawn puffs as particles that rise, grow and wear away at the edges, lit by
  the same light

- [x] **MT1. The first four** (2026-11-06, to judge): brass / tin / copper, velvet plum / moss, leaves
  lit from the front (waxy) or behind (glowing), smoke as steam / smoke / soot from the body pictures
  as puffs. p paints the light in four steps (poster paint) instead of smooth. Found: a brushy mask
  (body-04's streaks) shows as ridges in metal, like hammered tin: kept, it's the drawing.
- [x] **MT1b. The palette** (2026-11-06, to judge): in `material-check`, 28 materials (36 now) on one shape
  (n another): clay, plaster, stucco, stone, paper, felt, cotton; velvet ×2, satin, suede, leather,
  rubber, wax; toy plastic, glazed pot, candy, jade, pearl, wet stone, mud; wood, varnished, brass,
  gold, copper, tin, iron. Most are one 'surface' model with settings (PALETTE in the script: wrap,
  shine, clear coat, sheen, edges darkened, light through, grain: sand / fibre / pebble / wood /
  crackle, rainbow), so a new material is a row of numbers.
- [ ] **MT2. Judge and tune** with Nikki: which read as made by hand, which as "computer". Claude's
  read from screenshots: strongest metal, glaze, plastic, candy, wood, leather, felt, plush fur,
  the backlit leaves; weakest stone / wet stone (cell pattern), shaggy fur (more hair than fur),
  smoke (pale clumps more than smoke), paper and plaster washed out in full sun.
  Next, before MT6 (ENGINE-MERGE.md, 2026-11-06): Nikki goes through them in material-check (keep /
  change / drop each); only the kept ones go into the engine. Postponed by Nikki 2026-11-06: another time.
- [~] **MT3a. Two materials by the pattern** (2026-11-06, Nikki: "a ropey leg with that strip pattern:
  dark velvet, light metal"): in material-check, u picks a second material (brass, gold, tin, velvet,
  glass, felt), i the pattern (bee stripes, spots, the Mipo patterns), y its size. Each cell's own
  material fills the pattern's dark parts, the second its light parts: the picture drawn twice, the
  second time cut by the pattern (its alpha times its brightness). Legs added to n (leg-02, leg-05 with
  its rungs, leg-03). On a real Mipo the pattern already sits on the part (OMP), so this is the
  cheapest way to two materials there; costs the two materials added up.
- [ ] **MT3. A material map per picture** (the sneaker idea; drawing it: THINGS-TO-DRAW A16): one more picture next to outline + mask
  saying which part is which material (leather / rubber / cloth), so one Mipo part can be two materials.
- [x] **MT4. The next ones**: leather, rubber, stucco, glazed pottery (MT1b), wet (MT12).
- [ ] **MT5. Leaves for real**: translucency on the plants and garden spikes' leaves, with their sway.
- [~] **MT6a. A material per Mipo part, and wet** (2026-11-06, Nikki: "one Mipo with metal legs and a
  velvet body, part of his face wet"): `extra.material = 'brass'` on a part (texfixture, limb ribbon,
  torso skin) is drawn by the plasticine shader (src/render/shaders.lua) instead of clay, the part's
  own colours and pattern kept; presets in `src/render/materials.lua` (metal, brass, gold, copper, tin,
  velvet, satin, felt, leather, rubber, wax, plastic, glaze, candy: the ones without a grain). Wet:
  `src/wet.lua`, spots that stick to the body they land on and dry from the edge in (25 s), a
  waterline that soaks what's under it; porous things darken most, all get a sharp shine. No material
  and nothing wet: drawn as before (full suite 1521 pass). Scene `mipo-materials` (scripts/tests,
  light-grass-check's lights and Mipos at a fixed day): a panel with a material per part (all Mipos
  or one), the water's height, rain, dry; w a wet spot at the mouse. Not yet: saved in a Mipo's DNA
  (breeds), the editor's part panel, the face (its decals and the mouth don't take the light).
- [~] **MT6b. The mouth** (2026-11-06, Nikki: "the mouth, teeth, lips and inner mouth various
  settings"): the lips' and the teeth's own `extra.material`, the inside's `extra.innerMaterial` (on
  the lower lip's extra) and its colour (`backdropHex`), drawn by `src/render/mouth.lua` through the
  same shader (no material: no shader, as before). In mipo-materials: lips, teeth, inside, its colour
  (as is, black, dark red, pink, deep blue). Gold teeth, candy lips, a glazed inside read well.
  Wet spots reach the mouth only where it has a material (it's drawn without the shader otherwise).
  Found on the way: the script sandbox has no setmetatable (a scene script that uses it fails to load).
- [~] **MT6c. Eyes, pupils, nose** (2026-11-06, Nikki: "eyes too"): a face decal with `extra.material`
  is drawn as a quad in the head's own frame (src/physics/box2d-draw-textured.lua drawDecalLit), so
  the lights reach it as they reach the head; without a material, the plain image draw as before.
  mipo-materials: eyes, pupils, brows, nose rows (glazed eyes, plastic pupils, a gold nose). The
  brows are a bent strip in the head's frame: lit directly, the mirrored one telling the lights it's
  flipped (main.fx), so both are lit from the same side.
- [ ] **MT6. Into the engine**: a material as a texfixture setting, next to plasticine (SHADER-LOOKS'
  "looks on shapes"), if any of it earns a place.
  Already drawn by the engine since MT6a-c (`extra.material` on a texfixture, limb, torso, decal);
  what's left is setting it in the editor, for the materials MT2 keeps. After MT2 (ENGINE-MERGE.md).

## Fur (Nikki's follow-up talk, 2026-11-06)

Already here: the hairs shader (strand noise, frayed edges: `src/render/shaders.lua`), the back light
(LS9: its rim shows best on the Mipos' fur strokes), hair tufts as real bodies (HAIR-LOCKS.md).
From the talk: light streaking along the way the fur grows (in clumps, not single hairs); never a
crisp outline (tufts along the edge, fade or dither); a strong soft rim; darker at the root, lighter
at the tips; denser and darker in creases; flutter at the tips from the plants' wind; wet fur clumps,
darkens and gets sharper highlights. For close-ups, shell layers: a few copies, each thinned by
noise and pushed a little outward.
- [x] **MT7. Fur on the palette** (2026-11-06, to judge): plush and shaggy, strands down the picture in
  clumps, dark toward the skin and lighter where tips gather, the shine a streak across the strands,
  a soft strong rim (stronger from behind), a frayed edge, the outline faint. Not yet: tufts past the
  outline, shell layers, the direction following the body.

## Drawing styles

Pencil, charcoal, watercolour, gouache, oil: how the whole picture is drawn, more than what a thing
is made of. Nikki (2026-11-06): don't worry much about generated strokes vs drawn ones; what we want
is **hatching sheets** of her own, so the shading can be her lines.
- **CMYK offsets** (idea, Nikki 2026-11-06: "not here yet"): the cyan, magenta and yellow plates
  each printed a little off, the drawn outline (the black plate) in place: coloured fringes, old
  offset print, Childcraft. Tried in material-check the same day (each plate's mask sampled off by
  ~1-3% of the picture; at 1% the outline hides most of it) and taken out again: a drawing style,
  for later, maybe as a picture pass. Burrow's drawn outline has the simpler misregistration (2026-10-30).
- [ ] **MT8. Hatching sheets** (drawing them: THINGS-TO-DRAW A14): Nikki draws hatching at four or five densities (light .. cross-hatched),
  a few versions of each; through scan2tex; in material-check a mode where the darkness after lighting
  picks her hatching (tonal art maps), swapping versions ~12 times a second.
- A style over a whole scene (watercolour, gouache) waits for SH3's effects stack (SHADER-LOOKS.md);
  the picture pass below is a small start.

## Normal and depth maps: where ours come from

Ours now: `src/render/form-bake.lua` makes a height and normal from any picture's mask (how far in
from the edge), no tools and no extra drawing. Its limits: it only knows the outline, so every shape
is a dome or a cushion (no nose bump, no fold in an ear), and a brushy mask shows as ridges
(body-04 in metal).
Other ways, in our pipeline:
- **The outline's inner lines as creases**: the strokes inside a shape (a fold, a cheek) dent the
  height. Automatic, from what's already drawn. Cheapest to try.
- **A painted height picture**: a grey `-height.png` next to outline and mask (lighter is nearer),
  added to the bake. Fully in Nikki's hand; scan2tex could cut it from the same sheet.
- **Photographed clay**: a clay model lit from four sides, combined into real normals (photometric
  stereo). Fits the claymation look.
- **Tools** (Laigter, SpriteIlluminator) work but are another app; tools we build in LÖVE come first
  (`feedback_deform_editor`).
- **Depth** for parallax comes from the layer order (DEPTH-LAYERS.md); AI depth estimation (Depth
  Anything) only for a painted backdrop, if ever.
- [x] **MT10. Creases from the outline** (2026-11-06, to judge): in the shader, not the bake. The drawn
  outline picture, blurred for free by its mipmaps, is a valley wherever a stroke lies well inside the
  shape (the blurred mask near full, so the outer outline doesn't count): its slope tilts the normal,
  and a crease is a little darker inside. k: off / on / deep (on to start). Shapes that have inner
  lines added to n: ear-06, the snout nose-07, foot-01, ear-10, ear-05 (found by how much of a
  picture's line lies deep inside its mask). The snout's nostrils show it best (g, normals); on
  ears whose inner lines are thick and close the drawn line hides most of it. Cheap: +0.02 ms/MP
  on the Mac (~10%).
- [ ] **MT11. A painted height picture** as an option on a part (outline + mask + height; drawing
  them: THINGS-TO-DRAW A15).

## More from the lists (2026-11-06, in material-check)

- [x] **MT12. Wet** (r: a shower, wet in 2 s, dry over 20): porous things darken most (metal and glaze
  hardly), a sharp wet shine, drops (dark, a bright spot toward the light).
  Changed 2026-11-06 (Nikki: "the little white pixels feel ugly"): no drops, and a soft sheen instead of
  the sharp shine (exponent 160 -> 40), here and in the engine's wet (src/render/shaders.lua). "Better".
- [x] **MT19. Lumpy, bevel, ink shadow** (2026-11-06, Nikki: "good options"): in material-check's panel.
  Lumpy: a few soft bumps per thing, as if pressed by hand (0-2; ~0.5 on metals, 1 on felt/clay).
  Bevel: a fourth rise, a straight slope then flat (a coin; `formBake.bakeData(data, rise, 'bevel')`).
  Ink shadow: a soft dark band just inside the outline, so the shape sits in the line.
- [x] **MT13. What the shader sees** (g): the height, the normals, the light alone on white. For when a
  material looks off.
- [x] **MT14. The picture pass** (e): a soft glow from the bright parts, a grade by the light (warm sun,
  warmer candle, cool moon), a vignette, film grain at 12 fps. **t**: the whole picture at 12 frames a
  second (stop-motion), the leaves' sway too.
- [x] **MT15. Leaves sway**: a slow sway and a quick flutter from the stem, more with wind (w).
- Still in the lists, not built: a material map per picture (MT3), varied gloss and per-plant colour
  and size, ambient occlusion at a plant's base and in clumps, front leaves blurred and back layers
  darker (DEPTH-LAYERS), pollen and falling leaves, plants that react when brushed through.

## One screen, see-through, and what each costs (2026-11-06)

- [x] **MT16. One screen**: palette (36, with 'as drawn' first), leaves under it, smoke on the right.
- [x] **MT17. See-through** (Nikki: "I like to see transparency too"): a big striped shape slides behind
  everything (j stops it, hold h to carry it); glass, ice (frosted), soap bubble, clear candy and amber
  show it bent toward where they're thicker, less clear at the edges, tinted by their colour. Everything
  is drawn through a canvas of what's behind, which the shader reads.
- [x] **MT18. What each costs** (x): `src/render/shader-cost.lua` (`shaderCost` in the script sandbox)
  draws each over a 512 canvas 80 times a round, waits for the GPU with a one-pixel read, keeps the
  fastest of 7 rounds: ms per million pixels (a phone screen is ~1 MP). Repeats to a few hundredths.
  On the Mac (2026-11-06): as drawn ~0.19, metals and glossy ~0.2-0.3 (x1-1.5), clay, rubber, jade,
  wood ~0.45 (x2), fibres and fur ~0.5 (x2.5), the cell grains (stucco, stone, leather, tin, mud, wet
  stone, ice) ~0.9-1.0 (x4-5: nine cell points looked up three times for the relief). All of it is cheap
  here; the phone is what counts (LS12): measure there before choosing, and if the cell grains are too
  dear, bake the grain once into a picture.

**On the iPhone SE 2** (2026-11-06, `./playtime.sh device material-check`, x over the bridge; its screen
is 1334x750 = 1.0 MP, so ms/MP = ms for a full-screen layer; a frame has 16.7 ms). The scene itself
runs at ~53-60 fps with all 36 on screen. About 6-12 times the Mac:
- **~1.2-1.8**: as drawn 1.15, leaf 1.40, smoke 1.78
- **~2-3** (x2-2.7): metals 2.0, velvet 2.2, wax, glaze, satin, plastic, candy, glass, clear candy,
  amber, pearl, bubble 2.6-3.1
- **~3.4-6.4** (x3-5.5): clay 3.4, plaster 3.8, iron 4.4, rubber, jade, wood, varnished, fur ~5, paper,
  felt, cotton, suede ~6
- **~8.5-11.4** (x7-10): the cell grains: stucco 8.5, tin 9.5, stone, mud 9.9, leather 10.1, wet stone
  10.9, ice 11.4
What it means: a thing covers a small part of the screen (a Mipo ~5%), so even ice on a Mipo is
~0.6 ms; a wall or the ground in a cell grain (a third of the screen) would be ~3-4 ms, too much next to
everything else. So: lights, metal, gloss, see-through and velvet are affordable anywhere; the
noise grains on things, not on big areas; the cell grains (pebble, crackle) baked into a picture
once, or only on small things.

## What the Mipo shaders cost (2026-11-06, after MT6)

Timed with shader-cost on the part shader itself (src/render/shaders.lua, the plasticine shader all
lit Mipo parts go through), under mipo-materials' 7 lights (4 off), in ms per million pixels:

| | Mac before | Mac after | iPhone SE 2 after |
|---|---|---|---|
| no shader | 0.05 | 0.06 | 0.62 |
| clay (the lit Mipos) | 1.9 | 1.3 | 9.3-9.5 |
| a material | 1.8-2.2 | 0.71-0.78 | 5.1-5.9 |
| clay + 12 wet spots | 2.0 | 1.46 | 12.3 |

'After': lights that are off are skipped (they were looped per pixel), and a material skips clay's
thumb-dent noise; the picture is the same (spec/light-off_spec.lua). A Mipo is ~5% of the phone's
1 MP screen: a clay-lit Mipo ~0.47 ms a frame, one in materials ~0.28 ms; 20 lit Mipos (the room
limit) ~9.5 ms clay or ~5.6 ms in materials, of the 16.7 ms a frame. mipo-materials itself (3 Mipos)
runs at 60 fps on the phone.
Wet spots were looped per pixel for every part (12 spots: +2.7 ms/MP on the phone); since 2026-11-06 a
part is sent only the spots that reach it (wet.shaderSpots(body); limb ribbons, drawn without a body,
still get all), so a dry part pays nothing: after a dip, 23 of a scene's 48 Mipo bodies got spots,
25 none (spec/wet_spec.lua). Still to win if needed: fewer lights per part (the far ones).

**Lighting 20 Mipos on the phone, the whole frame** (b5's measurements, iPhone SE 2, editor, paused,
2026-11-06): the per-part Lua was the real cost, not the pixels. As drawn 7.6 ms draw; lit was 19.6
(the lights searched for in all sfixtures per part, then gathered per light per part), 16 after the
light list (LS23), 12.4 after the lights worked out once a frame (shaders.newFrame), 9.3 after sending
a shader only what changed: lighting 20 Mipos ~1.8 ms, from ~9.8 that morning. 60 fps. Rule since then:
nothing sends to the plasticine or hairs shader except through setSurfaceShader (it remembers what each
shader last got).
