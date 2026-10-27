# World metrics: design the world around Mipo feet

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
