# Materials — felt, moss, cardboard, cellophane: the craft-table look at runtime

status: active

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
- [x] **MT1b. The palette** (2026-11-06, to judge): page 1 of `material-check` (v), 28 materials on one shape
  (n another): clay, plaster, stucco, stone, paper, felt, cotton; velvet ×2, satin, suede, leather,
  rubber, wax; toy plastic, glazed pot, candy, jade, pearl, wet stone, mud; wood, varnished, brass,
  gold, copper, tin, iron. Most are one 'surface' model with settings (PALETTE in the script: wrap,
  shine, clear coat, sheen, edges darkened, light through, grain: sand / fibre / pebble / wood /
  crackle, rainbow), so a new material is a row of numbers.
- [ ] **MT2. Judge and tune** with Nikki: which read as made by hand, which as "computer".
- [ ] **MT3. A material map per picture** (the sneaker idea): one more picture next to outline + mask
  saying which part is which material (leather / rubber / cloth), so one Mipo part can be two materials.
- [ ] **MT4. The next ones**: leather, rubber, stucco, glazed pottery, wet (a wetness that comes and goes).
- [ ] **MT5. Leaves for real**: translucency on the plants and garden spikes' leaves, with their sway.
- [ ] **MT6. Into the engine**: a material as a texfixture setting, next to plasticine (SHADER-LOOKS'
  "looks on shapes"), if any of it earns a place.

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
- [ ] **MT8. Hatching sheets**: Nikki draws hatching at four or five densities (light .. cross-hatched),
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
- [ ] **MT10. Creases from the outline** into the bake, compared in material-check.
- [ ] **MT11. A painted height picture** as an option on a part (outline + mask + height).

## More from the lists (2026-11-06, in material-check)

- [x] **MT12. Wet** (r: a shower, wet in 2 s, dry over 20): porous things darken most (metal and glaze
  hardly), a sharp wet shine, drops (dark, a bright spot toward the light).
- [x] **MT13. What the shader sees** (g): the height, the normals, the light alone on white. For when a
  material looks off.
- [x] **MT14. The picture pass** (e): a soft glow from the bright parts, a grade by the light (warm sun,
  warmer candle, cool moon), a vignette, film grain at 12 fps. **t**: the whole picture at 12 frames a
  second (stop-motion), the leaves' sway too.
- [x] **MT15. Leaves sway** (page 2): a slow sway and a quick flutter from the stem, more with wind (w).
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
