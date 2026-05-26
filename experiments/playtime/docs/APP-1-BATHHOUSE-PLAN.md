# App #1 — Mipo's Bathhouse

**Concept:** Mipo runs a bathhouse. Mud-caked blobs arrive at the bath. The kid scrubs the mud away to reveal a uniquely-generated Mipo hiding inside.

**Tagline test (a 4-year-old can recognise this in one sentence):** *"Wash the mud blobs to discover what's hiding inside."* ✓

**Verb:** WASH (single)
**Resolution beat:** REVEAL (Sago's allowed: 1 verb + 1 resolution beat)

---

## Current status

**Current step:** Sequence #2 — Tech spike complete. Day 1 ✓ (cluster + sponge scrub). Day 2 thorn-pull tried and dropped (see Explicit skips). Next: decide spike verdict (Day 3) — does pure sponge scrub feel satisfying enough to ship? If yes → build phase step 1.
**Last touched:** 2026-05-26
**Face gap status:** ✓ Gaze (distance-based blend) + blink (random interval, squish) both working. Mouth animation not wired but not needed for Bathhouse MVP.
**Polish phase status:** ✓ closed 2026-05-26, 5 days ahead of the 2026-05-31 deadline. Teeth done; head bodyhair outline unified with hair color; gum tried-and-dropped (see below). Remaining polish items (eyelashes, hand/foot images, DNA boundaries, patches, Mipo breeds) deferred to app #2 per the pre-approved exit.

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

- **Setting:** one screen, one bathhouse interior. No camera movement, no scene changes.
- **Mipo:** stays as the bathhouse attendant. Reacts to reveals via the face animation system (this is what `FACE-SYSTEM-PLAN.md` is *for*).
- **Mud blobs:** arrive, get scrubbed, reveal what's inside, leave clean. New blob arrives.
- **What's inside:** procedural via the Mipo DNA system. Each blob hides a uniquely-generated Mipo (face, color, size variation — DNA already supports this). No hand-authored library of reveals.
- **Reward loop:** blob arrives → kid scrubs → reveal → both Mipos react → next blob.
- **No fail state. No levels. No menus.**

---

## Sequence

1. Close the face gap (~2–3 dev days / ~1–2 calendar weeks part-time, see `FACE-SYSTEM-PLAN.md` — verified 2026-05-14)
2. **Tech spike: physics-cluster mud + thorn-pull reveal** (2–3 days, see below)
3. If spike succeeds → build the app (~3–4 weeks)
4. **Fallback 1 (if cluster fails on performance or feel):** swap to canvas-alpha erosion. Well-trodden mechanic, ships safe, no spike needed.
5. **Fallback 2 (if neither cleaning mechanic feels right):** abandon Bathhouse, swap to **Drop-the-Mipo** — pure rigid-body physics Pachinko-for-toddlers, similar verb purity, similar scope.

Total budget: 4–6 dev weeks per manifesto → **~3–4 calendar months at ~12–18 hrs/week part-time.** If app #1 isn't shipping in that window, the scope is wrong, not the deadline.

---

## Build phase — ordered steps (only if spike succeeds)

*Effort estimates are dev-days at full focus. At ~12–18 hrs/week part-time, multiply ~3× for calendar time.*

1. **Smoke-test scene.** One bathhouse Mipo (attendant), faces animating, in an empty scene. Integration check that face system + scene context work together. *0.5d*
2. **Spike mechanic in the real scene.** Place a static placeholder blob; verify scrubbing erases dirt in scene context, not just the sandbox. *0.5d*
3. **DNA-procedural Mipo inside the cluster.** Central body of the mud cluster is a randomly-generated Mipo via the DNA system. Scrubbing breaks joints, mud balls fall away, inner Mipo gradually exposed. **When this lands, you have a playable game.** *1–2d*
4. **Thorn-pull reveal + face reaction.** At ~70% joints broken, the handle/thorn becomes grab-able. Player grabs via MouseJoint, drags free, remaining joints snap, Mipo pops out, both Mipos express via the face system. *This is the magic moment — the iconic Spirited Away beat.* *1d*
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

## Tech spike: physics-cluster mud + thorn-pull reveal

**Why this over canvas-alpha erosion:** the cleaning verb *is* physics, not a visual overlay. Scrubbing breaks the nearest joint(s) → mud balls fall away → the reveal is a physical extraction, not an alpha mask. Plays to playtime's actual strength (Box2D + character DNA). The mud aesthetic emerges automatically from overlapping circles, no authored "mud canvas" needed.

**Approach:**
- Mud blob = cluster of ~15–25 Box2D circle bodies connected to a central "treasure" body via DistanceJoints (stiffness + damping for springy hold).
- Inside the cluster: a randomly-generated Mipo (via DNA system), with a "handle" / "thorn" that becomes grab-able only once cleaning passes ~70%.
- Player drag = nearest-joint break (spatial query within scrub-radius).
- Broken-off mud balls fall away with gravity, exit screen, get cleaned up.
- At ~70% joints broken: the **thorn-pull** beat — player grabs the central treasure via MouseJoint, drags it free against the remaining joints, those joints snap, the Mipo pops out, particle burst + sound. *This is the iconic Spirited Away moment.*

**Day-by-day spike scope (all on macOS — no iOS needed yet):**
- **Day 1:** Minimal cluster (15–25 circles, distance joints), scrub = break nearest joint within radius. Validate the mechanic exists end-to-end on macOS.
- **Day 2:** Scrub-tool mapping, falling-chunks feel, integrate the thorn-pull (MouseJoint grab + drag-to-extract) as the climax.
- **Day 3:** Decide — feels satisfying on macOS? If yes → ships as the Bathhouse mechanic. If no → Fallback 1.

**iPad performance check is deferred to build phase step 9** (when there's a playable app to bundle anyway). 15–25 bodies + 30–60 joints per blob is *low* by Box2D standards — modern iPads handle hundreds. The doc previously called for iPad-on-Day-1, which was overcautious for this body-count. If it later turns out to be too slow on older (2018-era) iPads, the recoverable fallback is setting a minimum iPad requirement in the App Store listing — standard practice for kids' app developers.

**Risks to verify in the spike (macOS-only):**
- **Feel** — does scrubbing feel satisfying? Does the thorn-pull moment land?
- **Spatial-query for "nearest body within radius"** — not built-in to Box2D, but standard fare via the spatial partition (`world:queryBoundingBox` + filter).
- **Joint topology** — distance joints alone might not feel right. Possible refinement: outer-layer distance joints (visible, scrub targets) + inner-layer weld joints (structural skeleton). Don't pre-design; let the spike inform.

**Spike deliverable:** a single LÖVE scene with one cluster-blob; scrubbing breaks joints; chunks fall away; at threshold, the thorn-pull triggers and reveals the inner Mipo. No app structure yet, just proof of the full reveal arc end-to-end.

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
- **Thorn-pull / MouseJoint extract mechanic** — tried on Day 2 of the spike (2026-05-26). Didn't feel right. The sponge scrub is already satisfying as the sole verb; a grab-and-yank finale didn't add to it. The reveal beat will come from the DNA Mipo being exposed as mud clears, not from a physical extraction gesture.

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
