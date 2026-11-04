# Wild — one slider from tidy to wild (order and chaos, culture and nature)

status: parked — kept as a spike: "yeah nice" (tried 2026-11-04, scene `wild`)

Nikki's question (2026-11-04): a slider for the balance between nature and culture, chaos and
order, that makes things dirty, grimy, overgrown. `scripts/spikes/wild.playtime.lua`: a plank
shed (a door, a window, trim, a roof), a fence in front, a lawn, two Mipos.

## How it's made

- **One master slider, `wild`** (0 tidy .. 1 wild; keys 1 / 2 / 3), and three under it saying how
  much of each it brings (0..1.5 times the master):
  - **chaos:** planks turn and lose true (gaps open); about one in five comes loose and hangs
    from its higher end, the free end swinging down, its nail there gone.
  - **grime:** fresh paint (a red shed, cream trim, a blue door, a white fence) fades to grey
    weathered wood and darker; stains come in one by one, rust runs down from the nails, the grain
    shows more, the sky and ground go a bit duller.
  - **growth:** moss clumps along the shed's foot, the roof's edges, the sill and the fence feet;
    four vines climb and leaf out as they reach; the mown lawn grows into tall weeds (the blade
    atlas), flowers at the wild end.
- Everything random about a plank is drawn once with its own seed, so the same plank always moves
  the same way. Chaos goes in 12 steps, each step's outlines made once and kept (stop-motion);
  grime and growth slide smoothly.
- Drawn, no shader: Nikki's crayon strokes (`scripts/spikes/drawn-stroke.lua`), the grass atlas.
  Nails, rust, stains, knots, moss and leaves are drawn in code until they're drawn by hand
  (`THINGS-TO-DRAW.md` A11).
- `r` builds another shed (another seed). The roof is solid, the walls behind the Mipos.

## Left, if picked up

- The drawn markings (A11) instead of circles and ellipses.
- The same slider on other things: a Mipo (muddy, leaves in its hair), the boat (barnacles, weed
  on the hull), the treehouse; a world-wide `wild` a room could set.
- Vines only grow up; they could run along the roof and the fence too.
