# Shoes — feet in shoes, any foot

status: idea

Nikki (2026-11-11): "feet in shoes, we probably need a multiplier approach".

Mipo feet are five drawings (`textures/mipo/foot/foot-01..05`, outline + mask), each Mipo its own size and
colours. One drawn shoe fits none of them well, so the shoe takes its shape from the foot.

## The idea

- **The shoe is the foot's own mask** (the way underpants cut their seat from the torso's mask,
  WEARABLES): the **upper** fills the mask in the shoe's colour or material, the **sole** is a band along
  the bottom of the mask, and the **details** (laces, a toe cap, stitching, a heel) are Nikki's drawings
  multiplied onto it, so the foot's outline stays. One set of shoe drawings then fits all five feet at
  any size.
- **The material map** (THINGS-TO-DRAW A16, MATERIALS MT3, "the sneaker idea"): next to outline + mask, a
  `name-material.png`, red leather, green rubber, blue cloth: the sole rubber, the upper leather or
  cloth. With LEATHER.md's stitching on the upper, it reads as a shoe.
- **The multiplier**: a shoe is bigger than a bare foot: the foot a little bigger in a shoe (×1.1-1.2) and
  the sole thicker, a fit setting on top of the above.

## Questions

- In the DNA (how a Mipo is dressed) or a loose toy like the hats? Shoes on loose bodies would be fiddly;
  dressed seems right.
- Nikki's drawings: sole and lace pictures per foot shape, or one set stretched to each?
- Both feet: the back foot is drawn behind the leg (`foot-back` / `foot-front` in the draw order), so both
  get the shoe.
- Live or baked: on today's bake (OMP) a shoe is one more baked layer; drawn live (OMP-LIVE.md) it's a
  layer chosen at draw time, swapped without a re-bake.

## Steps

- [ ] **SO1. A greybox shoe** from the foot's mask: upper colour, a sole band, a toe cap, in a scene with
  the five feet side by side. Nikki: does the "multiplier" read as a shoe?
- [ ] **SO2. Nikki draws** laces, a toe cap and stitching (and the A16 material map for one foot).
- [ ] **SO3. Leather and rubber** on it (LEATHER.md, the material palette), then a few shoes: sneaker,
  boot, slipper, sandal.
- [ ] **SO4. In the DNA**, if kept.
