# Rides — little vehicles a Mipo gets into, and you drive

status: parked — Nikki 2026-11-09: "i think vehicles is done" (tried 2026-11-09: kart, car, skateboard, banana car; pick up, push, Darda wind-up, tap to drive). RD1 is her verdict on which way to play stays

Karts, tiny cars, mopeds, electric skateboards: a Mipo gets in or on, and the child drives
(Nikki 2026-11-09). Unlike the bike and the soapbox (docs/BIKE.md, docs/SOAPBOX.md: they roll
by themselves, a knikkerbaan to watch), these are driven. Spike: `scripts/spikes/rides`
(`r` another Mipo, `c` camera follows on/off, `p` pause).

Asked 2026-11-09: drive by **touching the vehicle** (no buttons), first a **kart, an electric
skateboard and a tiny car** (then a banana car), get on by **dropping a Mipo on the seat**. Then (same day): no car
roof, and **just pick a vehicle up, the Mipo in it**, helped upright a little while carried
("just enough to feel nice"), after physics-testbed's downhill (it only dragged the frame, and
kicked the bike back over when it landed upside down).

## What's there (2026-11-09)

- **A street**, 48000 long (Nikki: "a longer terrain"): flat in the middle where the vehicles
  and Mipos start (four Mipos in pairs between the vehicles), a hump; out each way a kicker
  (left of the start rising left, right of it rising right), rolling bumps, a dip, a long rise to
  the end wall. Heights in Mipo heights (S), places fixed.
- **The kart is whizzy** (Nikki: "an even wizzier gokart"): 6.5 S a second, 0.7 g (was 3.2,
  0.35); its driver is only thrown off at 2.6 S a second's change in a frame (the others 1.6), so
  landings keep it in. Over the bridge it ran the whole left half, kicker, bumps, dip, to the
  hill at the end, driver in.
- **Picking up**: a press picks a vehicle up by its frame (a wheel pressed: the frame at that
  spot, `pointerGrab`), the rider still in. Carried, a soft spring turns it toward upright
  (torque per S^2 of the whole weight: kp 2, kd 1.8, at most 3): held by one end it hangs ~30
  degrees, a fast swing sideways settles in under a second. Tried 2026-11-09 with kd 1.1: a
  flick spun it past upside down and the rider fell out. Carried, the rider never falls out;
  set down, a bump isn't a crash for 0.6 s. Let go, it's put down, not thrown (Nikki: "it just
  shoots away"): vehicle and rider stop and drop from there; the drag critically damped (1, not
  0.5) so it follows the finger without springing past it. The real cause of the shooting
  away: the follow camera kept moving while carrying (leading by the speed), and the drag's
  target moves with the camera under a still finger: a runaway loop. The camera now holds still
  while anything is held.
- **Pushed or wound** (Nikki 2026-11-09: "pick up and position the cart, or push it along, give
  it some momentum, see it roll; or the Darda way"). Let go, it keeps the finger's speed over its
  last 0.1 s (capped at 7 S a second; held still, it's just put down). Dragged backwards with its
  wheels on the ground it winds up (the back wheel's backward roll; forward doesn't unwind),
  up to 3 S; let go wound, it starts from rest and its spring drives it forward at 3.5 S a second
  per S wound (accel 1.1 g), for 5 times the pull-back, slowing over the last 1.5 S. A key on
  its back turns as it winds and unwinds. A tap catches a running spring. Only with a Mipo in, as
  driving (`WIND_NEEDS_RIDER`). Over the bridge: pulled back ~1.5 S, it shot to ~1700 a second
  and ran ~3100, driver in. Not yet felt by hand: the push.
- **Driving**: a tap (short, hardly moved), only with a Mipo in it (Nikki 2026-11-09: an empty
  one just sits; the driver out, it rolls to a stop). Stopped: it goes toward the side tapped (its back:
  it turns round first). Going: a tap on its front stops it, on its back turns it round. Motors
  in the wheel axles, torque from the whole weight (rider included) times an acceleration in g,
  up to a top speed in Mipo heights a second. Tried first (2026-11-09): hold to drive, drag to
  pick up, told apart by 0.15 s held still; picking up felt like it should be the press itself.
- **Getting on**: drop a Mipo (let go of it) over a free vehicle: it gets in. Turned upright with
  the vehicle, facing the way it drives (`switchFacing`, src/mipo-facing.lua), legs posed.
  Kart and car: hips on a spring (a wheel joint, as the soapbox), leg muscles at fixed world
  angles (the soapbox's lesson). Skateboard: stands, feet welded to the deck, standing muscles.
- **Getting off**: drag the rider out of the vehicle; a hard knock (a change of speed of 1.6
  Mipo heights a second in a frame) throws it off at the speed it had; upside down for 0.6 s it
  falls out; a dazed skater falls off. An empty vehicle on its back rights itself after 2 s.
- **Banana car** (Nikki 2026-11-09, after Richard Scarry's Busytown): a long banana on two
  little wheels, ends curving up, a brown tip at the back and the stem at the front, the rider in
  a hollow scooped out of its middle (its far side drawn peeled pale behind the rider). The car
  underneath (floor, low walls, 2 riders' weight); 3 S a second.
- **Kart**: low red tray, legs out front, steering wheel, a number. **Car**: open, blue, the
  rider sits upright, its body over the side (a drawn roof over the rider: tried 2026-11-09,
  Nikki: no roof). **Skateboard**: a yellow deck with
  kicktails, battery and a light that glows while driven; gentler acceleration (a standing
  rider tips past ~0.4 g).
- Tried over the bridge: the car drives and shoves the skater along; the kart takes the kicker at
  ~1600 a second and lands; a standing Mipo in a vehicle's way stalls it (the kart stalled on the
  kicker pushing one up it), so the free Mipos stand between the vehicles.
- Drawn as flat shapes with an ink line: placeholders for Nikki's drawings.

## Next

- [ ] **RD1. Nikki plays with it**: picking up, pushing, winding up, tap to drive; which stays; on the phone.
- [ ] **RD2. A moped**: two wheels, sits astride, feet on a footboard (not pedals: the bike's
  pedal legs were the fragile part).
- [ ] **RD3. The look**: drawn vehicles, wheel pictures as the soapbox's.
  Started 2026-11-12 in the engine's vehicles (src/vehicles.lua, KINDS KD4): every wheel wears Nikki's crayon
  tyre from the mipoworld experiment (textures/world/vehicles/wheel-01 + -mask: tread lines in ink, the tyre
  in rubber). The frames are still plain shapes.
- [ ] **RD4. Sound**: a motor hum pitched by speed (synth), a squeak getting in.
