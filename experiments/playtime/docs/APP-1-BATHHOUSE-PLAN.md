# App #1 — Mipo's Bathhouse

**Concept:** Mipo runs a bathhouse. Mud-caked blobs arrive at the bath. The kid scrubs the mud away to reveal a uniquely-generated Mipo hiding inside.

**Tagline test (a 4-year-old can recognise this in one sentence):** *"Wash the mud blobs to discover what's hiding inside."* ✓

**Verb:** WASH (single)
**Resolution beat:** REVEAL (Sago's allowed: 1 verb + 1 resolution beat)

---

## Current status

**Current step:** Build phase step 3 — spawn a new mud-coated procedural Mipo into the scene. (`'n'` key in `mudready.playtime.lua` calls `spawnNewMudMipo()` — clears mud, destroys old Mipo, creates + randomizes a new one and re-coats it. `characterManager` now exposed in scriptEnv.)
**Last touched:** 2026-05-28
**Face gap status:** ✓ Gaze (distance-based blend) + blink (random interval, squish) both working. Mouth animation not wired but not needed for Bathhouse MVP.
**Polish phase status:** ✓ closed 2026-05-26, 5 days ahead of the 2026-05-31 deadline. Teeth done; head bodyhair outline unified with hair color; gum tried-and-dropped (see below). Remaining polish items (eyelashes, hand/foot images, DNA boundaries, patches, Mipo breeds) deferred to app #2 per the pre-approved exit.
**Attendant Mipo:** dropped — the player *is* the attendant. No separate attendant character needed.

*Update these lines after each working session. They're the canonical "where am I?" so resume doesn't require re-derivation.*

---

## Mipo pre-spike polish (deadline: 2026-05-31)

The Mipo is the reveal payload. If it doesn't read at small size mid-bubble-burst, the iconic beat lands flat — so a focused round of polish before the spike is *not* drift, it's prep. The risk is "almost there" being unbounded, hence the time-box.

**Time-box: 2026-05-24 → 2026-05-31 (1 week).** When this list is empty, spike starts.

- [x] ~~**Teeth**~~ — done 2026-05-24. Outline visibility (black `bgHex`), width slider (`teethWMul`, max 3), z-order split (new `mouth-backdrop` drawable at z=250), stickOut clipping (shift lower-arc curve points down by `h*0.8` *before* polygon build — preserves natural upper-arc dip, gives front teeth room in weird shapes), animated tracking (corner midpoint + 0.3 pull toward p3).
  - ~~**(5) Upper gum.**~~ — *tried and dropped 2026-05-25.* Asset drawn (`textures/gum1.png` retained for future), DNA + decal + render + UI fully wired (`mouth-gum` drawable at z=250.5, tint via `setColor`, anchored at p3 of animated curve, clipped to mouth polygon). Issue: gum moves independently of teeth as the mouth shape changes — the two anchors don't share a rig, so they slide apart visually. Fixing properly would require attaching gum to teeth's frame of reference, which is more rig work than this polish window allows. Reverted via `git restore` on the 5 modified src files; `gum1.png` kept for revisit. Not app-#1 blocker.
- [ ] **Eyelashes (wimpers)** — add to eyes for cuter read
- [ ] **Missing hand/foot images** — fill gaps in the texture set
- [ ] **Stronger DNA boundaries** — tighten constrained ranges so randomization stays on-brand
- [ ] **Hair de-duplication** — face *and* body currently both spawn hairy parts; only one should
- [ ] **Patches** — enable + tune until they look good
- [ ] **Mipo breeds** — define a handful of archetypes (potato / chunk / long / hairy etc.). Draft already exists in `MIPO-CODE-IDEA.md` lines 19–44 (BLOB, SPUD, TALL, TWIG, CHUNK, WIDE) — pick which ones ship in app #1 and lock the constraint ranges

### If 2026-05-31 hits and the list isn't empty

Pre-approved exit, no shame debate:

- Anything still open becomes **app #2 polish**, not an app-#1 blocker
- Spike starts on 2026-06-01 regardless — the cluster mechanic doesn't care about teeth outlines or patches
- Re-evaluate only if a remaining item *materially blocks the reveal beat* (e.g. Mipos still unrecognisable at thumb size)

### Friction heads-up

A few items need new image assets (drawing tablet, export pipeline). That's a "hassle" tax — schedule those for an **anchor block** (focused session), not a low-energy fill-in. Don't let asset prep become its own sub-project that eats the week.

---

## Why this concept beat vanilla "Mipo's Bath"

- Upgrades the loop from *maintenance* (clean a thing) to *discovery* (reveal a thing). Same engine work, much stronger commercial framing.
- Surprise/unboxing is the dominant kids'-content mechanic (Surprise Eggs, Ryan's World) — algorithm-friendly without trying.
- Reframes Mipo from "the one in the tub" to "the bathhouse attendant" — keeps Mipo as the consistent IP and the face-reaction-shot character, while the washed creatures vary every play.
- Reference: Spirited Away river-spirit scene. Cleaning as revelation. Borrow the emotional shape, not the literal art.

---

## Approach

- **Setting:** one screen, full-bleed tub. No room, no door — the ceiling is the outside. No camera movement, no scene changes.
- **Mipo:** no separate attendant — the player *is* the attendant. The revealed Mipo reacts on clean via the face animation system.
- **Mud blobs:** arrive from above, get scrubbed, reveal what's inside, float away. New blob arrives.
- **What's inside:** procedural via the Mipo DNA system. Each blob hides a uniquely-generated Mipo (face, color, size variation — DNA already supports this). No hand-authored library of reveals.
- **Three affordances, one verb:** sponge (direct scrub) + soapbar (spread-and-wait lather) + showerhead (kid drags Mipo under it). All three are WASH — different rhythm, same agent. Not an "and also."
  - **Sponge:** active, direct. Scrub-scrub-scrub. Good for detail and finishing.
  - **Soapbar:** spread lather across mud balls, then watch the foam eat away at them. Clings visibly to the mud and slowly drains health without the kid needing to stay on it. Different pace — satisfying to smear everywhere and step back.
  - **Showerhead:** bulk removal from above, draggable. Good for rinsing loose mud and the foam left by the soapbar.
- **No fail state. No levels. No menus.**

### Full interaction loop

1. **Doorbell rings.** A mud blob drops from the top of the screen, splashes into the tub.
2. **Wash.** Player scrubs with sponge and/or shower. Water gradually browns as mud dissolves (tint water fill proportional to mud cleared). The dirty water is visible progress.
3. **Rinse (optional player action).** Player can drag the water level down (dirty water drains) and back up (clean water refills). Natural signal that they're ready for the next customer — but not forced.
4. **Reveal + tadaa moment.** Last mud ball pops → a balloon magically appears and ties itself to the Mipo → rainbow burst + floating balloons fill the screen for a moment. The Mipo's face reacts (face animation system). This is the payoff beat and the shareable clip moment.
5. **Departure.** The balloon slowly lifts the Mipo upward. Player can let it drift on its own, or play with it in the tub a bit longer — the balloon provides gentle upward buoyancy but doesn't force an exit. Eventually the Mipo floats up and off the top of the screen.
6. **Loop.** Tub is empty and clean. Doorbell rings. Repeat.

**Three beats, one verb:** WASH → REVEAL → RELEASE. The balloon is the resolution beat, not a second mechanic — the player's only choice is when to stop playing with the cleaned Mipo.

**Why balloon over a jump:** a jump is automatic and over in a frame. A balloon gives the player a moment of "aww" and the choice of when to let go. A Mipo floating away with a balloon is the image that ends up on a book cover — and a natural 10-second clip.

---

## Sequence

1. Close the face gap (~2–3 dev days / ~1–2 calendar weeks part-time, see `FACE-SYSTEM-PLAN.md` — verified 2026-05-14)
2. **Tech spike: physics-cluster mud + sponge scrub reveal** ✓ DONE 2026-05-26 (see below)
3. **Build the app** (~3–4 weeks)
4. **Fallback 1 (if cluster fails on performance or feel):** swap to canvas-alpha erosion. Well-trodden mechanic, ships safe, no spike needed.
5. **Fallback 2 (if neither cleaning mechanic feels right):** abandon Bathhouse, swap to **Drop-the-Mipo** — pure rigid-body physics Pachinko-for-toddlers, similar verb purity, similar scope.

Total budget: 4–6 dev weeks per manifesto → **~3–4 calendar months at ~12–18 hrs/week part-time.** If app #1 isn't shipping in that window, the scope is wrong, not the deadline.

---

## Build phase — ordered steps (only if spike succeeds)

*Effort estimates are dev-days at full focus. At ~12–18 hrs/week part-time, multiply ~3× for calendar time.*

1. **Smoke-test scene.** One bathhouse Mipo (attendant), faces animating, in an empty scene. Integration check that face system + scene context work together. *0.5d*
2. **Spike mechanic in the real scene.** Place a static placeholder blob; verify scrubbing erases dirt in scene context, not just the sandbox. *0.5d*
3. **DNA-procedural Mipo inside the cluster.** Central body of the mud cluster is a randomly-generated Mipo via the DNA system. Scrubbing breaks joints, mud balls fall away, inner Mipo gradually exposed. **When this lands, you have a playable game.** *1–2d*
4. **Face reaction on full reveal.** When all mud balls are cleared, attendant Mipo and the newly-revealed Mipo both express via the face system. *The emotional beat — no grab mechanic needed.* *0.5d*
5. **Blob lifecycle.** Cleaned blob exits, new blob arrives. The infinite loop. *1d*
6. **Particle polish.** Soap bubbles, splashes, water droplets. Reuse playtime's particle system where possible. *1–2d*
7. **Hand-drawn art pass.** Bathhouse background, blob silhouette/dirt texture, scrub brush/sponge. **Up until now you've been working with placeholder rectangles.** *3–5d*
8. **Sound (tiny).** Splash sounds, reveal chime. Optional, keep small. *0.5d*
9. **iOS bundle + App Store prep.** Fuse the .love, build with appelflap, test on device. **This is where iOS dev setup matters** — refresh Xcode certs/provisioning, plug in iPad, validate performance, fix any cluster-on-older-iPad perf issues (e.g. set minimum device requirement in App Store listing if needed). App Store Connect setup (icon, screenshots, metadata, age rating). Submit for review. *3–5d + review wait*
10. **Marketing pass** *(parallel to step 9)*. Cut YouTube sequel from real footage, cut Reels/TikTok highlight, ASO update on Mipo Puppetmaker with "More Mipo apps" link. *2–3d*

### Ordering principle (this matters)

- **Function before art.** Steps 1–6 produce a playable greybox app with placeholder rectangles. Hand-drawn art (step 7) comes *after* you know the mechanic feels good and the procedural reveal works. Pivots and scope shifts cost zero art time when art is done last. The greybox-playable moment at step 6 also gives you the dopamine win of "it works!" months before final art — that carries you through polish phase.
- **Always run after each step.** End each step with the app launchable and the new thing visible. Don't accumulate uncommitted/un-tested integration work between steps. Worst-case ADHD scenario is "I changed five things last week and now nothing runs."
- **Hand-drawing as step 1 is the trap.** It's intrinsically interesting, has clear sub-tasks, and produces zero playable progress. If you find yourself opening the drawing tablet before step 7, the manifesto is being violated quietly.

---

## Tech spike: physics-cluster mud + sponge scrub reveal ✓ DONE 2026-05-26

**Why this over canvas-alpha erosion:** the cleaning verb *is* physics, not a visual overlay. Scrubbing breaks the nearest joint(s) → mud balls fall away → the reveal emerges naturally as the cluster clears. Plays to playtime's actual strength (Box2D + character DNA). The mud aesthetic emerges automatically from overlapping circles, no authored "mud canvas" needed.

**What was built (script: `scripts/mudready.playtime.lua`):**
- Mud clusters on every Mipo body part (16 anchors: torso, head, ears, arms, hands, legs, feet). Each cluster is **auto-sized** from the body part's collision fixture bounding box — big parts get more/bigger balls, small parts fewer/smaller ones.
- Ball count per anchor: 4–16, computed as `floor(r * 0.18)`, capped to stay reasonable.
- Distance joints (frequency 4, damping 0.6) + angular restoring spring (`ANGLE_SPRING = 700`) keeps balls spread even when Mipo moves — prevents collapse into a pile.
- Sponge scrub (mouse drag + speed threshold) damages nearest balls; balls pop with splatter + jiggle neighbours.
- **Showerhead** (static, above tub) rains droplets that also damage mud balls on contact — secondary cleaning verb.
- **Water fill** with animated wave surface; buoyancy + linear/angular damping applied to Mipo bodies when submerged (`FLUID_DENSITY`, `FLUID_DRAG`, `FLUID_ANGDAMP`).
- Water-crossing splash particles: entry fires a crown upward, exit fires a sheet outward.
- Sponge moving in water generates disturbance droplets (no click needed).
- Root anchor circles shrink and disappear when their last ball is popped.
- Tuning UI panel: density, drag, ang.damp, water level, shower position.

**Verdict: go.** Sponge scrub is satisfying as the sole verb. Water + buoyancy adds life. Thorn-pull tried and dropped (see Explicit skips).

**iPad performance check is deferred to build phase step 9.** ~4–16 balls × 16 anchors = well under 300 bodies max — low by Box2D standards.

---

## Fallback 1 — Canvas-alpha erosion (if cluster spike fails)

Well-trodden mechanic, no spike needed — known to work. Approach:
- Render a "dirt layer" into a `love.graphics.newCanvas`
- Player drag = brush stroke punches alpha out of the dirt layer
- Inner Mipo (DNA-generated) drawn underneath; shows through as dirt erodes
- Stencil clips the dirt to the mud-blob silhouette
- The thorn-pull beat still applies: at ~70% cleared, handle becomes grab-able, MouseJoint drag extracts the Mipo

Less physics-native than the cluster approach, but ships safer.

---

## Fallback 2 — Drop-the-Mipo (if neither cleaning mechanic works)

Pure rigid-body Pachinko-for-toddlers: kid drops Mipos from the top, they bounce through pegs to a happy goal. Verb: DROP. No new tech needed, just Box2D the engine already does well. Same verb purity, same scope, same face-system benefit. Documented exit if the bath concept itself doesn't pan out.

---

## Explicit skips (considered, decided against)

- **LiquidFun / Box2D particle extension** — not natively in LÖVE 11.x; wrappers are unmaintained; particle liquids are GPU-heavy on mobile. Hard no.
- **Metaball shaders** — not needed; overlapping cluster circles produce the metaball aesthetic automatically.
- **Realistic mud soft-body simulation** — the cluster *is* a soft body, but we're not chasing photorealism. The cleaning verb defines the simulation, not the other way around.
- **Thorn-pull / MouseJoint extract mechanic** — tried on Day 2 of the spike (2026-05-26). Didn't feel right. The sponge scrub is already satisfying as the sole verb; a grab-and-yank finale didn't add to it. The reveal beat comes from the DNA Mipo being exposed as mud clears, not from a physical extraction gesture.

If you find yourself reaching for any of these mid-build, the manifesto is being violated. Write the idea on a separate list and walk away.

---

## Scenario / interaction loop (brainstormed 2026-05-26)

Each play interaction has a clear start and end:

**Beginning:** mud blob slides/drops into the tub with a splash.
**Middle:** player scrubs mud off with the sponge.
**End:** last mud ball pops → clean Mipo floats up to the surface, reacts (face animation) → exits. Attendant Mipo reacts too. Next blob arrives.

Preferred flow: **slide in / float out** — blob arrives down one side of the tub, clean Mipo floats up from buoyancy when fully clean, climbs/slides out the other side. No button needed; the water surface is the "done" signal.

Water surface crossing already fires **splash particles** (blue droplets, arc upward on entry/exit). This is the transition visual for both arrival and departure.

---

## Open visual questions

- **Root node circle** — the filled brown circle drawn at each anchor point (center of each mud cluster) doesn't feel right. It's currently a plain filled circle that shrinks away when the last ball pops. Unclear what would be better: maybe no center circle at all (balls alone cover the body), maybe a rough blob outline, maybe it's only visible when balls are present and fades fast. Needs a try-it session before build phase step 7 (art pass).

---

## Asset list (full app, not the spike)

- 1 bathhouse interior background
- 1 bathtub (could be part of the background)
- 1 sponge / scrub brush (player's tool)
- 1 mud-ball texture (single small circle with noise/colour variation per instance — the cluster of ~15–25 instances per blob automatically produces the mud aesthetic). Fallback 1 (canvas erosion) would need a blob silhouette + dirt texture instead.
- Soap + bubble particles (reuse existing playtime particle tech where possible)
- Bathhouse Mipo (the attendant — uses the DNA + face system already working after step 1)

~5–6 hand-drawn assets total. Within Sago Rule scope.

---

## Out of scope — these are app #2, app #3, or never

The manifesto enforcement section. If you find yourself drifting toward any of these mid-build, write the idea on a separate list and walk away:

- Different bathhouse rooms / progression
- Customising the bathhouse Mipo's outfit
- Multi-player mud-blob bathing
- A "gallery" of revealed Mipos to collect
- Day/night cycles, story arcs, narrative
- A second tool (loofah, soap with different effects)
- Different mud types

The verb is **wash**. The resolution is **reveal**. Anything else is a different app.

---

## Cross-references

- Principles: `MANIFESTO.md` (Sago Rule)
- Prerequisite tech work: `docs/FACE-SYSTEM-PLAN.md`
- IAP layer status: paid app, no in-app IAP needed → `APPELFLAP-ISSUES.md` is non-blocking for this app
