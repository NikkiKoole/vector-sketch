# Rig zones — places that take over a Mipo's skeleton, and ways to drag one

status: parked — kept as a spike (Nikki 2026-11-15: "all are keepers, parked for now"); RZ2 (pose on the bench topples it) and RZ9 open for when it comes back

Nikki (2026-11-14): "what if (a bit like the connectors on vehicles) we have some places on the map or objects
that make the mipos skeleton behave? for example a slide where the legs go different to improve sliding down?
or a way that changes how you can drag a mipo, so basically more control about rig".

## The spike (2026-11-14, scene `rigzones`)

`scripts/spikes/rig-zones.lua` is the system (its sliders in `lib.tuning`); `scripts/spikes/rigzones.playtime.lua`
the scene: a slide, a bench, a bar on two posts, a cushion, three Mipos.

- **A zone is on a body** (`rig.addZone{ kind, body, inside(x, y), ... }`): what a Mipo whose torso is in it
  does with its limbs. Like a vehicle's seat poses its rider (`src/vehicle-rides.lua`), but for any place.
  Poses are KEEP_ANGLE targets in world angles (0 = hanging straight down; a KEEP_ANGLE holds *degrees*);
  everything a zone changes (muscle targets, joint limits, collision masks, the arm hang) is kept and put back
  when the Mipo leaves. Walking is held off meanwhile (`mipoWalk.hold`).
  - **slide**: sits, legs straight out *along the chute's slope where it is* (props.makeSlide's curve), feet up,
    leaning back, arms up. Faces the way the chute goes. The chute is slippery (friction 0.06).
  - **bench**: let go over it, it sits down at once: posed, the thighs put on the seat, the torso welded to
    it till it's picked up. All of it passes through the seat (collision category 15, `rig.SEAT`): the thighs
    held out on slow muscles (the vehicles' rider's, kp 8, 2 rad/s), the shins and feet slack, hanging down.
    Nikki 2026-11-14: "bench isn't working nicely, mipo moves erratically". What it was, in turn: the thighs'
    muscles bending into the seat flung it off; an arm or shin held off its target (by a shoulder limit, by
    the seat) read as a split to `mipoJointGuard`, which hopped it every 1.2 s; on a springy wheel joint (the
    vehicles' seat) the torso bounced and spun against the thighs.
  - **bar**: arms up (the arm joints' limits off meanwhile: they stopped the arms level, and the elbow's
    jammed them halfway); a hand near the bar, or crossing it between frames, grips it (a joint). Lets go
    when pulled over 'grip' times its weight for 0.15 s (dropping into the hang jerks harder than that for a
    frame), or when the finger holding it goes 'pull away' px off.
  - **cushion**: flops (a ragdoll) till picked up.

  Playground 2 (2026-11-14, Nikki picked five of the ideas; left / right arrow between the two):
  - **crawl** (a table, 360 of room; an awning, 520): under something low it gets down by how much room
    there is for *its* height (Mipos differ: 600-1000 tall): less than 'belly below' on its belly (legs
    trailing, arms reaching in turn), less than 'crawl below' on hands and knees, else ducked. Let go in front
    of it or under it, it goes through by itself (a push on the torso while it's down), the way in it faced;
    let go too near to get down, it backs up a little first. A Mipo too big for the room noses in and stops
    (honest). Found on the way: a held part's muscle is off (dragged by the torso it couldn't bend over);
    turning round when dragged back flipped it to and fro; the head's KEEP_ANGLE is set by `mipoActions`'
    gaze every frame after a scene's update, so kept upright its neck limit held the torso at ~45 degrees:
    the head's muscle is off while crawling and a motor in the neck holds it.
  - **ladder**: the bar's grip on every rung (crossing a rung between frames counts), 'pull away' 260; the
    feet too (Nikki 2026-11-14), on a rung below the torso and not a hand's. Held by four grips it didn't
    budge when pulled up, so climbing: dragged with the finger well above, it lets go of its lowest grip every
    0.2 s and that limb catches a higher rung; well below, its highest. A foot also lets go when its leg is
    stretched. The frame of the swing touches nothing (Nikki: "can the frame not collide with the swing").
  - **beam**: arms out, swaying ('beam: sway'); within 140 of an end the arms windmill, leaning away.
  - **wind**: a force on every loose body in the box (gusting), streaks drawn; a Mipo leans into it, arms
    streaming downwind. A fan at the end.
  - **swing**: a seat on a revolute joint at the beam (rigid ropes), its zone moving with it. Let go over the
    seat it sits (welded, like the bench); arms along the ropes (their joints free); pumps: legs out going
    forward, tucked going back, plus a push along the swing ('swing: push', 0 for the legs alone). Stays on
    while dragged unless the finger goes 'pull away' off.
  Playground 3, the slide park (2026-11-15, Nikki: "can we add a few more slides, can also be in the sky"):
  any chute is a curve (`chute(points)` in the scene: a ribbon, its slide zone knowing the slope where the Mipo
  is, a bump uphill a negative one). A sky tower (a cloud, three chutes zig-zagging down with a wall at each
  turn: it shoots off one, bounces, lands on the next and turns to face down it), a bumpy one with humps, and
  a steep drop from a high cloud that launches it onto the bumpy one. What it took: the tower's chutes
  steepen to their ends (flat there, it stopped), a big drop and the walls well out between them (wedged
  between two chutes, or its legs against a wall), arms ahead not up (they caught the chute above), the
  Mipo slippery while it slides (friction 0.02, put back after: its own grip stopped it on a gentle top),
  and sat still 0.7 s on a slide it scoots forward. `mipoJointGuard` leaves a posed Mipo alone
  (`inst._noStandUp`, a new flag there): a limb held off its target by a chute read as a split and it
  hopped about.
- A zone that turns a Mipo (slide, bench, crawl) sets the head's and body's turn from the facing and draws the
  face again (`mipoFacing.applyFace`): `mipoFacing.angle` returns the turn under way, so copying it kept the
  old one, and without the redraw the face looked the way it last turned (Nikki 2026-11-15: "mipos are still
  not looking with their face in the direction they are sliding in").
- Everything's posed on soft, slow muscles (kp 8, 3 rad/s) where a pose meets the floor or a seat: at full
  strength the slide's legs flung a Mipo off the deck and out of the world.
- **Drag styles** (keys 1-4, the panel): **normal**; **scruff**: whatever you press, it's taken by the head;
  **hand**: by the nearest hand (`pointerJoints.grab` moves the press); **pose**: a doll. Every joint gets
  friction (a motor at speed 0, torque the Mipo's weight times 'pose: stiffness' of a quarter of its
  height), so it stays as you leave it; the limb you hold is free, so dragging a hand moves the arm and the
  rest stays put; held by the torso, it moves whole.
- The arm hang (`mipoActions`' `inst._armSwing`) couldn't be used: the walk clears it again after a scene's
  update. A zone holds the arms on KEEP_ANGLEs and sets `inst._isRagdoll` alone (the arm hang skips a
  ragdoll; the legs keep their muscles).

## Next

- [x] RZ1. Nikki plays with it (2026-11-15: keeper, parked): which zones and drag styles to keep
- [ ] RZ2. Switching to pose while a Mipo sits on the bench lets go of its seat, and it topples
- [ ] RZ3. Zones as a thing to place in the editor (an sfixture kind, saved), not built by a scene script
- [x] RZ4. More places: crawl under things, ladder, beam, wind, swing (2026-11-14)
- [ ] RZ5. Nikki plays with playground 2; the swing only keeps a small swing going (±10 degrees) by itself
- [x] RZ7. A slide park: sky tower, bumpy, steep drop (2026-11-15)
- [ ] RZ6. A bed (lie down), a chair facing front, a seesaw, a trampoline
