# Planks — a treehouse nailed together, every plank with a drawn outline

status: parked — kept as a spike: "this experiment is good now" (tried 2026-11-04, scene `planks`)

The planked-together dwelling look (tree houses, sheds): `scripts/spikes/planks.playtime.lua`.
A tree (trunk, branches, leaf blobs) with a house on a platform: floor planks, a beam, braces to
the trunk, a back wall of upright planks with a window, corner posts, a roof, a porch railing in
front, a ladder. Every plank is its own body, a little crooked, its ends cut a bit skew.

## How it's made

- **The outline** is Nikki's crayon strokes (`textures/strokes`), the burrow rim's stroke: broken
  at corners over 55° (each piece overshoots and tapers), wobble and width from noise, a seed per
  plank so each line is its own.
- **Seamless (`s` toggles):** each side gets one stroke picture, repeated mirror-wise, so every copy
  runs into the next as its own reflection. Before, every repeat picked another picture: thick,
  thin, a step sideways ("morse code"). Each picture is cut at load to its steady part along
  (`STEADY`: line1 19–83%, it has steps drawn near its ends; line2 8–92%) and tight to the crayon
  across (the track lines filled only a fifth to a third of their pictures' height), so all draw
  equally thick. Width default 9.
- **Grain:** thin pale strokes along the plank, a knot now and then.
- **Nails:** a weld where two planks overlap (sampled every 20 units along the thinner one), a
  nail head drawn there. All planks in one negative group, so they don't push each other; they're
  held by their nails. Nails pop only on a plank being dragged and pulled hard (the drag's own
  force against the plank's weight), one at a time, most loaded first: a nail at rest can carry
  the whole house (measured up to 300× its plank's weight), so its own force says nothing.
  A plank with no nails left falls free and collides again.
- **Layers by hand:** back wall and ladder are sensors drawn behind the Mipos; floor, posts, roof
  solid; railing and a few leaves drawn in front. The real thing: `DEPTH-LAYERS.md`.
- The follow camera is off for the scene (it kept zooming in on a Mipo).

## Left, if picked up

- The left brace may still not be nailed at its top.
- The stroke copies are short (cut, about 4–5× as long as wide): long planks can look a bit
  regular. A few long crayon lines from Nikki (1500–2000 px) would fix it.
- The stroke code is in three places (burrow, planks, `scripts/spikes/drawn-stroke.lua`, which
  `boat2` loads); one module if it's kept.
- Rebuilding (`r`) over the bridge hits the eval limit; restart instead.
