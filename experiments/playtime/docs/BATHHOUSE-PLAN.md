# Bathhouse — next steps (pick-up plan)

Lean roadmap for taking the mudready spike toward a shippable Bathhouse loop.
Strategy backdrop is `docs/STUDIO-STRATEGY.md`; this doc is the *execution* spine.

Captured 28 May 2026. Live tuning state (density 2.0, drag 1.5, ang.damp 1.5)
lives in `scripts/mudready.playtime.lua`.

## Where we are

The spike nails the **feel** — the hard part:
- `spawnCluster` cakes procedural mud balls around the scene's rigged Mipo (any
  body tagged with an `ANCHOR_LABELS` label) — see `mudready.playtime.lua:135`.
- `breakBall` knocks balls off when scrubbed enough — *this is the behavior
  you're happy with*, the satisfying break.
- Body parts under the mud are buoyant in water (`FLUID_DENSITY > 1` floats them
  up) and there's a draggable showerhead.
- Per-anchor counts (`anchorBodies[i].ballCount` / `totalBalls`) are already
  tracked, so "all mud gone" is one comparison away.

What's missing: **everything after the mud comes off.** No reveal payoff, no
named character, no collection, no flow. Scrubbing leads to *nothing* yet.

## The spine — one verb: **wash**

> muddy ball drifts in → you scrub it clean → the Mipo underneath is **revealed
> and named** → it bobs happily in the bath (reward) → joins your **shelf** →
> next muddy ball.

Everything below serves that loop. Nothing adds a second verb. "Take a bath" is
*reward juice*, not a mechanic. (See the manifesto: ambient physics props are
not a second verb.)

## Next steps, in order

### 1. Close the loop — the reveal moment  *(the single next thing)*

You already count balls per anchor. Detect "fully clean" → trigger a payoff:
- The clean Mipo bobs up out of the suds.
- Its name appears (one word, big, briefly).
- A small happy sound + a settle animation.

This is what turns a satisfying toy into "I discovered someone." It is also
*exactly* the clip-worthy beat the strategy doc calls the "content engine" —
each reveal is a 10–20s shareable moment generated as a byproduct of play.

**Acceptance:** scrubbing every ball off any rigged Mipo in any scene triggers a
reveal beat that ends with the loop ready for the next muddy ball.

### 2. A roster of Mipos

Author a small set of **named** characters (start with 3–5). Each muddy ball is
a random un-revealed one. The reveal pulls the name + a one-line personality
beat from the roster. Author-driven, per the studio framing.

**Open fork to settle before starting this step:**
- **Fixed hand-made roster** (curated, each with a name + visual + personality) —
  strongest emotional payoff, matches the author-driven framing, finite.
- **Procedurally assembled** from puppet-maker parts — endless, but personality
  is thinner and "discovery" feels less specific.
- *Lean:* fixed roster. The whole strategy is named characters with personalities.

### 3. The shelf (collection)

Revealed Mipos persist into a gallery you can revisit. This is:
- The "gotta-find-them-all" hook that gives sessions a shape.
- The natural place for the **paywall** (free until 2–3 Mipos revealed, then a
  one-time ~€2.99 unlock — per strategy doc).
- Your footage source — the gallery is where re-watch-the-reveal lives.

### 4. Wordless feel + onboarding

Scrub gesture obvious to a 3-year-old with **zero text**. Sound design. The
"ball enters" intro. Keep water/foam/shower as *juice*, not a second game.

## Later / parallel (from STUDIO-STRATEGY.md)

- Capture reveal footage as you build (Vimeo/IG drip, App Store screenshots).
- Pricing decision: lean is free + ~€2.99 unlock after a couple of reveals.
- Trailer (30–45s, mood piece, no narration).
- Site reframe to hold Puppet Maker + Bathhouse as equals; press page.

## Discipline (worth re-reading mid-spike)

- The verb is **wash**. If a feature isn't *make washing more satisfying* or
  *make the reveal land harder*, it waits.
- Solo + ADHD: one phase at a time. Step 1 first; don't start Step 2 before
  the reveal moment is real.
- Sago Rule: one verb, 4–6 weeks, no "and also."
- If something can be captured as a clip, treat it as a launch asset.

## Open questions (parked)

- **Fixed roster vs. procedural Mipos** — see Step 2. Lean = fixed.
- **Reveal staging** — does the Mipo *rise* out of the water, or does the camera
  pull back? Probably try the simpler bob-up first.
- **Session shape** — endless stream of muddy balls, or N per session then a
  pause? Skipping for now; ship one full loop first.
- **What is "the bath"?** Currently the tub + water are present but the bath
  itself is implicit. Stays as ambient reward, *not* a separate verb.

## What I'd start with on the other machine

Step 1, narrowly: in `mudready.playtime.lua`, add a check in `s.update` (or
adjacent to `breakBall`) for `anchorBodies[i].ballCount == 0`, fire it once per
anchor, and put a placeholder reveal beat behind it (text + a sound stub).
Don't try to do Step 2 in the same pass.
