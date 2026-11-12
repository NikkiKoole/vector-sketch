# Boat — two Mipos on a little boat, after walter-boat

status: parked — kept as two spikes: `boat` ("keep this scene") and `boat2`, the boat of planks ("very nice") (tried 2026-11-04)

After `experiments/walter-boat` (2022): Walter the walrus and Olivia on a little boat, the speed on
the arrow keys, the boat leaning with it, smoke, fish, clouds, a buoy and fishing rods. Here two
Mipos stand in for Walter and Olivia; the rods and the dragging of fish and buoy are left out.

## boat (`scripts/spikes/boat.playtime.lua`)

- **Nikki's drawings:** the boat, clouds, smoke puffs, fish and buoy from walter-boat's vector-sketch
  polygon files, flattened into `scripts/spikes/boat-shapes.lua` (a colour and points per shape;
  the transforms applied), triangulated into meshes at load.
- **The boat** is a kinematic body (deck, cabin roof, the cabin's front wall, a bow wall), steered
  by velocity onto the surface wave: it bobs, tips along the slope, lifts its nose when speeding
  up and dips it slowing down (*bob*, *tip*). It stays in the middle; the speed is the world going
  by (waves, clouds, fish, buoy scroll; smoke puffs blow back, more of them when faster).
- **The Mipos** stand on the deck for real; a push against each change of speed sways them
  (*sway*). In the water a part floats, slowed, and drifts behind with the travel (*float*).
- **Waves:** five layers of sines with walter-boat's fixed per-point wobble; the two front ones over
  the hull, see-through so the fish show.
- Walter-boat's cartoon skew (leaning with speed) became the tip and sway: Mipos can't be skewed.

## boat2 (`scripts/spikes/boat2.playtime.lua`)

The same sea, sky, smoke, fish and buoy; the boat built from planks with the drawn outline (as in
`PLANKS.md`, from `src/drawn-stroke.lua`):
- A clinker hull (six rows overlapping, cream top, navy, red bottom; rivets along every seam),
  stem and stern posts, a deck, a cabin of upright planks with a window and frame, a solid front
  post, a red two-plank roof, a railing in front of the Mipos.
- Every plank is a fixture of one kinematic body (nothing wobbles loose); nails drawn where planks
  overlap, one every 130 units along the overlap.
- **Wonky** (*wonk*, `r` builds again): each plank turned a little about its middle (less for long
  ones, so the hull rows still meet), each corner pushed off true, the whole cabin leaning like a
  settled shed.
- **The chimney** is its own light body on a springy weld (frequency 4) at the roof: it wobbles when
  the boat rocks, the smoke comes from its top.
- It needs a **back layer**: the far side of the boat behind the Mipos (`DEPTH-LAYERS.md`).
- **The sea splashes** (2026-11-12, Nikki: "pretty nice actually"): a Mipo dragged into or out of the
  water dips or lifts the surface there, which springs back fast and spreads as ripples (springy
  columns every 20 units, in the water's own x so they drift back with the travel). Only the Mipos'
  layer (3) and the front layer just in front of them (4, at 0.7); the *splash* slider, 0 off.
- **The fish are alive** (2026-11-12, for fun): a swimming wave down the drawing to the tail (a
  vertex shader; faster and wider the faster it swims), a cruise speed and depth they change now and
  then, darts, turns round through flat, the nose tilted where it's heading, and they bolt from a
  Mipo part in the water within 380 units.

## Left, if picked up

- Throwing a Mipo overboard isn't checked yet (floating, drifting back).
- The sea, clouds, smoke and fish in boat2 are still the vector drawings; planks and strokes for
  them too, if wanted.
- Rebuilding boat2 (`r`) over the bridge hits the eval limit; restart instead.
