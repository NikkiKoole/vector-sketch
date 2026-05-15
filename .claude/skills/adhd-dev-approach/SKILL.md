---
description: ADHD/executive-function-aware collaboration pattern for long-running personal software projects. Externalize state to docs and memory, time-box decisions, document fallbacks before starting risky work, and treat the working pattern as load-bearing infrastructure rather than incidental.
---

# ADHD-Centric Developer Approach

A working pattern for collaborating with a developer who has ADHD and broader executive-function considerations (planning, timing, emotional regulation, self-control). The pattern treats those considerations as *design constraints on the workflow itself*, not obstacles to overcome with willpower.

## When to use this skill

Apply this skill whenever the context matches one or more of:

- The user mentions ADHD, executive function, low energy, burnout, getting stuck, or "sunk-cost grinding"
- The user is starting (or resuming after a break) a multi-month personal software project
- The user is at a planning/sequencing/scoping decision point in a long-running project
- The user is working part-time on the project (alongside a job, family responsibilities, other commitments)
- The user is solo or near-solo on the work — there's no team to absorb the friction

Skip if the context is collaborative/team-based, a quick one-off task, or where the user is acting in a professional/client-facing capacity where these patterns might not match.

## Core principles

### 1. Externalize state — docs and memory carry the project, not the user's head
- Every decision and plan lives in a file. Future-the-user, reading the doc on a low-energy day, should be able to resume without re-derivation.
- Each plan doc names the *next concrete step* and its *prerequisites* explicitly. No "now what?" questions on session resume.
- Memory (`MEMORY.md` + per-topic files) captures durable context: rules, preferences, project state, locked-in decisions. Reference operational docs from memory so future-Claude meets the user where they left off.
- Always end an active session by writing the next step into the relevant doc — leaving an in-context note ("step 3 of FACE-SYSTEM-PLAN is next") removes the most expensive cognitive cost: figuring out what to resume with.

### 2. Time-box and document fallbacks BEFORE starting risky work
- Every spike/experiment gets a hard time budget (e.g. 2–3 days) with a documented exit if it fails.
- Two-tier fallback ladders are common shape: primary mechanic → known-safe alternative → "abandon this concept, ship something else." This removes the *decision* from the moment of fatigue.
- "Pre-approved exits" — the plan explicitly says "if X fails, switch to Y." When fatigue hits, no shame or sunk-cost debate, just execute the pre-approved branch.
- Documented skip lists ("considered X and said no, here's why") prevent rediscovery temptation later.

### 3. Ship-shaped slices, not comprehensive plans
- One core verb per shipped product. Resist "and also" expansions — they belong to the *next* product.
- 4–6 dev weeks per ship max. Multiply ~3× for calendar time at typical part-time rates (~12–18 hrs/week).
- "If feature X wants to grow, it's product #2." Trust the first mechanic.
- Each shipped slice is its own win — don't make product #1 a stepping stone toward product #5.

### 4. Function before art — validate cheap things first
- Get a working/playable greybox in the simplest possible form before polishing.
- The temptation to draw/decorate/refine before the mechanic works is the classic ADHD trap: it's interesting, sub-divisible, produces sub-tasks the brain rewards, but generates zero validated progress.
- Always end a working session with the project runnable and the new thing visible. Avoid accumulating "I changed five things last week and now nothing runs."

### 5. Calendar weeks beat hour budgets
- "Worked X hours this week" is depressing math. "By Sunday this milestone ships" is concrete and either-or.
- Plan for 4+ lost weeks/year (vacation, illness, work crunch, low-energy weeks). Bake this into honest timelines rather than treating it as failure.
- 1-hour-minimum rule: below that, cognitive setup cost exceeds output. Above that, momentum often carries to 2–3 hours.
- Anchor block per week: one consistent calendar slot that's the floor. Other time is bonus.

### 6. Sunk-cost grinding is uniquely damaging for ADHD brains
- Neurotypical brains often recover energy from "pushing through" via finishing-reward dopamine. ADHD recovery is muted — grinding past the stuck point costs more than it returns.
- Recovery typically requires interest-shift, not just rest. Swap to something engaging at the natural stop point rather than "finish then rest."
- Time-boxes and pre-approved exits matter because they remove the in-the-moment decision to grind.
- After a stall, "the plan keeps" — picking up cold from documented state is fine; no shame catch-up.

### 7. End mid-thing — set up resumability
- Always end a session in the middle of an easy step, not at a decision point. Next session opens to "finish the loop" rather than "now what?"
- Track *shipped milestones*, not hours.

## Executive-function dimensions beyond attention/dopamine

The patterns above also address the broader EF profile commonly co-occurring with ADHD:

- **Planning/timing:** External documented plans + calendar-week deadlines bypass the internal "estimate from feel" failure mode. The doc tells you the next step; the calendar tells you when.
- **Emotional regulation:** Pre-approved fallbacks and time-boxes mean pivoting carries no shame — the decision was already made when fresh. Reduces the post-failure spiral that ADHD's emotional dysregulation tends to amplify.
- **Self-control / scope discipline:** External rules (the project's manifesto, "out of scope" lists in plans) act as commitment devices. They override the in-the-moment temptation to "and also…" or to polish the toolchain instead of the product.

The pattern is: **the workflow should never depend on having full energy or full self-control to make a good decision.** Decisions get made in advance, in the docs and the fallback ladders, when the user is fresh. Lower-energy days execute pre-made decisions, they don't make new ones.

## How to apply when collaborating

- When the user proposes adding scope mid-project, push back with an "and also?" check. Cut scope, not corners.
- When the user is stuck on a path, surface the pre-documented fallback rather than pushing them to muscle through.
- Validate the user's instincts when they're right — confirming a correct read ("yes, that overkill detection was correct") is high-value and prevents second-guessing.
- Don't surface friction tasks (cert renewals, tooling setup, infra setup) earlier than they're needed. Schedule them at the moment they're due, not preemptively.
- Memory is essential for cross-session continuity. Write durable rules + project state to memory; reference docs from memory.
- Keep manifesto/principles docs **pristine** — adding rules to them dilutes their function as commitment devices. Discoveries get captured in *operational* docs, not in the principles file.
- The user knows their own experience best. Frame approaches as "this is the model I work from" not "this is how ADHD works." Defer when their lived experience contradicts the model.

## How to apply when reviewing existing work

- Look for principle violations as a friction-audit lens: scope creep, toolchain polishing, missing fallbacks, undocumented decisions, plans that don't name the next step.
- Look for *missing* skip lists — "what did we consider and reject?" is as important as "what are we doing?"
- Honest deadlines bake in lost weeks. A plan that assumes 52 productive weeks/year is wrong even before it starts.

## Honest caveat

I am not a clinician. Individuals with ADHD and executive-function profiles vary enormously. Use these patterns as defaults that respect a known shape, but always defer to the user's lived experience over the model. If a pattern doesn't fit the specific person, drop it.
