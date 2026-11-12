# Reach — hands in 3D, arms honest in Box2D

status: active

Nikki (2026-11-12): "imagine we have a notion of a more 3d space where hands are and thus lower and upper arms
rotate to, is that feasible while in box2d, can we spike this?" — and picked the honest version (option 2):
the physics hand is where the drawn hand is, not only a drawing.

Scene `reach` (`scripts/spikes/reach.playtime.lua`), the arm in `scripts/spikes/reach-arm.lua`.
Before it: the tracks spike was parked for fake depth (drawn shrunk while Box2D stayed flat, `TRACKS.md`);
this is the other way round.

## How it works

- **The hand has a place in 3D**: x, y on screen, z toward the camera. A two-bone solve in 3D (shoulder at
  z 0, the elbow bending toward a hint: down, a little out and back) gives the elbow.
- **Box2D does the foreshortening**: the arm in the world is an elbow body (a sensor) and a hand body (a circle,
  in the Mipo's collision group) on distance joints from the shoulder. Every step each joint's length is the
  segment as seen from the front, `sqrt(L^2 - dz^2)`, with the depths following the solve. So the 3D
  lengths always hold and the hand is where it's drawn: it pushes and gets pushed there.
- **Muscles**: the hand and elbow are pulled toward the solve (critically damped, gravity held up as strong as
  the muscles are), and the same force pushes the torso back at the shoulder. Without that the Mipo flew off
  by waving (first try). Let go ('hang'): a little tone pulls the hand down beside the body, so it settles
  instead of swinging round like a pendulum.
- **The look is the Mipo's own**: its arm bodies become ghosts (sensors, no gravity, 1/2000 of the torso's
  mass) posed every step so the elbow and wrist anchors sit on the physics arm; the arm ribbon, its hair and
  the hand picture follow. Not `setActive(false)`: the engine asks every Mipo part for its bounding box,
  which an inactive body hasn't got (a Box2D assertion; `SCRIPT-API.md` SA4).
- **Depth in the drawing**: the hand is bigger near the camera, smaller away (perspective, 'camera far');
  an arm more than 15% of its reach behind the body is drawn before the torso, one in front after everything
  (`state.drawableWrap`).
- Guides: the physics arm and the target in the world, a view from above and one from the side, top left.

Keys: m the hand follows the mouse (1 / 2 which hand, up / down its depth), o circle toward you, w wave,
f reach for the camera, g hold the belly, b behind the back, x hang, t 3D / flat (the Mipo's own arm), r new
Mipo, h panel.

## Steps

- [x] **RE1. Nikki plays with it.** 2026-11-12: "i like this spike"; kept.
- [ ] **RE2. The arm's width by depth.** Only the hand scales now; the ribbon keeps its width.
- [ ] **RE3. A hand seen end-on.** Reaching straight at you shows the side picture of the hand, made bigger;
  a front-on hand picture (palm or fist) for when it points at the camera?
- [ ] **RE4. What a hand behind the body touches.** Today it touches everything a hand touches; with depth
  layers (`DEPTH-LAYERS.md`) a hand behind the body could pass behind things in front.
- [ ] **RE5. Uses**: hold something in front of the chest, hug another Mipo, wave at the player, hide
  something behind the back, reach into a box. Then, if kept: an arm mode in the engine (`SCRIPT-API.md` SA4).
