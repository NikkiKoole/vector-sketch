# Mipo flip / stand-on-hands button

**Status:** experiment reverted 2026-05-22. Next attempt needs a different mechanic — see below.

**Goal:** per-Mipo button in the sidebar (next to "breathe") that inverts the body so it's standing on its hands. Toggle: click again to right-itself.

## Where things live

- Sidebar buttons: `src/ui/mipo-editor.lua` — see the "RANDOMIZE BUTTONS" / "breathe" section near the end of `lib.drawMipoEditor`. The breathe button (commit `24269202`) is the precedent — full-width, applies `torso.body:applyLinearImpulse(0, -1000)`.
- KEEP_ANGLE behaviour: defined in DNA defaults at `src/character-manager.lua` lines ~1027–1052 — only the 4 leg parts (`luleg`, `ruleg`, `llleg`, `rlleg`) have `{ name = 'KEEP_ANGLE', angle = 0, kp = 40 }`. Arms have none.
- KEEP_ANGLE controller: `src/keep-angle.lua`. Note `angle` is in **degrees** (PD controller calls `math.rad(targetAngle)`). Default `kp = 20`, `maxOmega = 15`.

## What was tried (and reverted)

1. Toggle leg KEEP_ANGLE between 0° and 180° → not enough; just flips the legs' target without moving the torso.
2. Add an `enabled` flag to KEEP_ANGLE, disable legs / enable arms on flip → arms snap to point-down but body doesn't invert.

## Why those didn't work

`keep-angle.lua` calls `body:setAngularVelocity(omega_cmd)` directly — it **bypasses Box2D's force pipeline**. So flipping a leg's KEEP_ANGLE target doesn't transmit torque through the hip joint to the torso. The legs just rotate themselves; the torso stays upright.

To invert the body, we have to act on **the torso itself**. Options to try next time:

- **`setAngle(currentAngle + π)` on torso1** (teleport-rotate). Simplest. Joints will resolve limb positions. Multi-segment torsos (torso2, torso3 if `instance.dna.creation.torsoSegments > 1`) and the head probably need flipping too, or they'll be left dangling at the old orientation.
- **`applyAngularImpulse(large_value)` on torso1** — physics-driven flip. Smoother visually but unpredictable; may not complete a full half-turn before damping kills the rotation.

Once the torso is inverted, **then** the limb KEEP_ANGLE flag-toggle becomes useful:
- Legs free (or KEEP_ANGLE 180 = pointing up away from now-inverted hips, so they stick up like real handstand legs)
- Arms KEEP_ANGLE 0 = pointing down in world coords, bracing the body on the floor

## Puppet-maker2 reference

The user remembered a "stand on hands" feature in `experiments/puppet-maker2`. **There isn't one that actually works** — search confirms `upsideDown` flag is set by the UI button (`scenes/outside.lua:523`) but never read by any physics/render code. The visual didn't exist; the button just flipped a UI icon.

So: we're inventing this, not porting it. The puppet-maker2 patterns to actually borrow are `breathBody` (impulse) and `eyeBlink` (countdown tween) — both already in playtime as the breathe button + the existing blink system.

## Recommended next attempt

1. Add the `enabled` flag back to `keep-angle.lua` (one-liner: `if vb.name == 'KEEP_ANGLE' and vb.enabled ~= false and not same then`).
2. Flip button does, in order:
   - `torso1.body:setAngle(currentAngle + (flipping and math.pi or -math.pi))`
   - Same for `head`, `torso2`, `torso3`, `neck-segments` if present.
   - Disable leg KEEP_ANGLE, enable arm KEEP_ANGLE (add behaviour entries if missing, like the reverted version did).
3. Toggle state can be derived by checking `instance.parts.luleg`'s KEEP_ANGLE `enabled` flag — no separate `instance.isFlipped` state needed.

If `setAngle` looks ugly (instant snap), fall back to applyAngularImpulse with a large value (~5000) and let physics handle the rotation, then enable the flags after a short delay.
