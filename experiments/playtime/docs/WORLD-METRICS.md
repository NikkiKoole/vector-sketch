# World metrics: design the world around Mipo feet

status: reference

Measured 2026-10-27 on 20 random Mipos (scale 0.3, `randomizeMipoConstrained`, arm-reach
rule on), standing on a flat floor with friction 0.9. World units.

| | min | median | max |
|---|---|---|---|
| Stance (outside of one foot to outside of the other) | 249 | 442 | 556 |
| Foot width / height | 113 / 66 | 204 / 112 | 277 / 246 |
| Height (feet to top of head) | 363 | 658 | 951 |
| Width with arms | 312 | 468 | 661 |
| Mass | 6 | 12 | 19 |

## Rules for anything a Mipo stands on

- **Surface width ≥ 650** (widest stance 556 plus a foot of margin). The skateboard is 800.
- **Lips stop feet**: a raised edge of **≥ 70** at the ends (lowest foot is 66). See the
  skateboard kicktails in `src/props.lua`.
- **Flat, ≤ 5° slope.** At 5° Mipos drift only 40-85 units in 5s. From 10° they walk
  downhill (lower legs flail: KEEP_ANGLE holds legs world-vertical while the feet sit on the
  slope, and knees bend one way). Bug to fix before slopes are usable; see DOLL-PLAY.md.
- **Grip: friction ~0.9** on floors and standing surfaces (feet are 1.0). The default 0.2
  feels like ice.
- **Something to slide down**: slippery (0.15) and smooth (no kinks); the chute is a
  smoothstep curve.

## Other sizes

- **Hands never reach the floor**: arm ≤ torso + leg, enforced by the randomizers
  (`characterManager.limitArmReach`).
- **Heights to sit or climb**: a Mipo is 360-950 tall, so a slide top at 700 is about
  one Mipo high.
- **Toys to hold or throw**: balls 55-130 radius feel right next to a 200-wide foot.

## How many Mipos a room can hold

Measured 2026-10-31 on the floor device, an iPhone SE 2 (Retina, sound on, play mode), with
the Mipos dropped into one pile (the worst case). Details and how: [MEASURING.md](MEASURING.md) M10.

- **Up to ~20 Mipos in a room is comfortable**: ~10.5 of the 16.7 ms a frame. What's left
  covers a warm phone (~25% slower), props and the scene's script.
- **25 is the ceiling** (1 frame in 10 late, worse when they pile up). Past 30 the game plays
  in slow motion (smooth, not jerky: the loop's time budget), so don't design for it.
- **Count in Mipos**: one is ~16 bodies, 15 joints, ~30 sfixtures, ~0.3 ms of drawing and
  ~0.2-0.3 ms of physics on the phone. A plain prop is a fraction of that; a toy of many
  joints counts like part of a Mipo.
- **The limit is per room**: off-screen Mipos aren't drawn, but every Mipo in the room takes
  part in the physics. More Mipos in all: spread them over rooms behind doors.
- **Piles cost most** (contacts grow faster than the Mipos): a pit full of Mipos reaches the
  limit sooner than a room where they stand apart.
