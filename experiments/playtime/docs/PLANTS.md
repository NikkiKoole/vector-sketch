# Plants — drawn leaves and stems, grown into real plants

status: idea

Nikki, 2026-11-03, right after the scan tool worked: "start adding some vegetation: leaves and stems,
and grow real plants that are random, physicsy and great."

## What's there to start from

- **Drawing them in**: `tools/scan2tex` (ASSETS-AND-BUILDS.md AB1): a sheet of leaves and stems on
  paper, a phone photo, named parts into `textures/` (outline + mask, so they take colours and
  patterns like a Mipo part). The old Scan 14 already has three sprouts and a fern on it.
- **Physics plants, tried before**: `../vehicles-vegetation/main.lua:794` `makeGrassThing`, each plant a
  dynamic body on a revolute joint to a static anchor, springing back to a random rest angle
  (`:2272`), drawn by `../../lib/texturedBox2d.lua:184` `drawPlantOver`; and 13 unused leaf
  sprites in its `assets/leaves/` (WORLD-BUILDING.md 1d).
- **Bending ribbons**: CONNECTED_TEXTURE (a textured ribbon through joints, the Mipo's hair and arm
  hair) could be a stem; the grass edge (`src/grass.lua`) for the small stuff.
- **Growing over time**: dreamengine's `plants.c` (growth stages) and `lsystem.c` (L-system plants),
  HARVEST-NAVKIT-DREAMENGINE.md 1i.

## The tension to decide early

WORLD-BUILDING's lesson: scenery doesn't need to be physics (cheaper to draw and step; the iPhone SE
2 floor, ~20 Mipos a room). So probably both: a few plants you can grab, bend and pull out (real
bodies: a stem as a chain, leaves on it), and many decor plants that only sway (a fake bend, no
bodies), made from the same drawn parts and the same random recipe.

## A first spike, when it's picked up

One random plant from drawn parts: a stem of 3-6 segments (bodies on springy joints, the ears' weld
feel), a leaf or two per joint, a flower or bud on top, random but seeded; tap it and it wobbles, a Mipo
bumps it and it bends back. Then: does it look drawn, is it fun to knock about, what does it cost on
the phone.
