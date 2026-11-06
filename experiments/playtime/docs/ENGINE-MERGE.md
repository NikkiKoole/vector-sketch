# Merging the spikes into the engine

status: idea

Where it stood on 2026-11-06: about 35 spike scenes, most of them one big scene script (600-2,900 lines)
with their own drawing, shaders and physics. A few have code in `src/` already (cloth, liquid, fluid,
wet, materials, raspberry, facing, hair locks/tufts, fabuland). About 20 are parked as "kept as a
spike" with Nikki's verdict. None are on the toys shelf (`src/props.lua`, 15 recipes).

## What "merged" means

A spike is merged when it works **without its scene script**, as one of:
- **a thing on the shelf**: a prop recipe with 🎲 and its own few settings (EDITOR-ARRANGE.md):
  a critter, a plank, a glass bead, a stone with a material, a curtain, a plant;
- **a scene setting**: light, sky and clouds, water level, depth layers, music style, as sliders
  in the scene panel.
What's neither (the soapbox ride, the burrow) stays a scene, a shorter one, built from the merged parts.

## The themes

| Theme | Spikes | In the engine as |
|---|---|---|
| Water | sea, drawn-sea, seaside, waterjar, water, cellophane, boat, boat2, the mirrors pond | one kind of water (seaside already brings them together) |
| The scene's look | light and shadow, materials, clouds, depth, mirrors | scene settings; a material as a setting on a picture |
| Built from drawn parts | planks, boat2, wild's shed, fabuland, soapbox and bike tracks | prop recipes with drawn outlines |
| Creatures and plants | garden (the biggest), plants | things to place |
| The Mipo | breeds, facing, raspberry, choir, tufts, soft torso | DNA and actions (mostly on the way in) |
| Places | burrow, soapbox, bike, planets, platforms | stay scenes |

## Order

- [ ] **EM1. Light and materials.** Decisions first, then the move:
  MATERIALS MT2 (Nikki judges the 36 in material-check: keep / change / drop; postponed 2026-11-06,
  another time), then LIGHT-AND-SHADOW LS23 + LS15 (a full room's defaults), then LS13 (light as a
  scene setting) and MT6 (setting a material in the editor, for the kept ones). LS20, LS21 and LS24
  after, in a real room. Started 2026-11-06 with LS13's first slice (the light button: off / lit,
  `src/scene-light.lua`), the order above turned round by Nikki's wish to have the button.
- [ ] **EM2. Two or three easy shelf things**: cloth (`src/cloth.lua`), planks with drawn outlines,
  glass beads; tries spike thing -> prop recipe -> shelf. Read each spike's script first.
- [ ] **EM3. Water**, as one piece of work, from seaside.
- [ ] **EM4. Garden critters**, once the shelf and 🎲 exist (EDITOR-ARRANGE EA2-EA4).

Mipo breeds stays the focus; this runs beside it.
