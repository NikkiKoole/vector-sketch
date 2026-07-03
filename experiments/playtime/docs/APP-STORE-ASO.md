# App Store ASO: Mipo Puppetmaker — keyword & metadata notes

Parked reference (2026-07-03). A keyword/metadata analysis done while Mipo Puppetmaker was
live on the App Store. **Not active work** — the app isn't being developed right now (and
likely can't be compiled on the current machine). Captured so the findings aren't lost.

Analysis was run with a small tool that lives in the *dreamengine* repo:
`~/Projects/dreamengine/tools/aso-research.js` (design: `docs/design/store-agents.md §ASO`).
Re-run any time — it needs no account, only the public iTunes Search API:

```
node tools/aso-research.js --country us --app "Mipo" "puppet maker" "marionette"
node tools/aso-research.js --country nl --app "Mipo" "poppen maken" "marionet"
```

---

## The one fact that makes ASO matter for this app

In App Store Connect → **Analytics → Acquisition → Sources**, ~**80% of product-page views
come from App Store Search** (vs Browse / referrals). People *find* Mipo by searching — so
title/subtitle/keywords are the single highest-leverage growth lever it has.

(Snapshot when checked: 123 first-time downloads, 14.2K impressions, 2.18% conversion.)

---

## How the three fields actually work (so you don't stuff the title)

- You rank on the **union** of Title + Subtitle + the hidden 100-char Keyword field. Each
  word only needs to appear **once** — repeating it anywhere is wasted space.
- The **Keyword field is invisible to users** — it's where all the "SEO" belongs. That's why
  the cheap keyword-salad titles are *unnecessary*: put keywords in the hidden field and keep
  the visible surface a real sentence.
- In the keyword field: **no spaces after commas, drop stopwords** (`a the for and your own`
  are ignored by Apple), and **don't write multi-word phrases** — Apple auto-combines your
  single words into phrases (`create` + `character` already yields "create character").
- **Taste test for the visible fields:** read it aloud. Sounds like a person describing the
  app → good. Sounds like a search query → it's stuffing.

---

## Current metadata (as of 2026-07-03)

- **Title:** `Mipo Puppetmaker` (16/30)
- **Subtitle:** `Imagine, Create and Play` (24/30)
- **Keywords:** `ragdoll,sandbox,avatar,dolls,playtime,puppet,create your own character,preschool,toca boca,for kids`

## Findings & recommendations

- **Title — good, clean.** One nuance: `Puppetmaker` as a compound may index as a single
  token (`puppetmaker`), so you might not rank for `puppet`/`maker` alone from the title. Two
  options: keep it compound and keep `puppet` in the keyword field (current), OR space it to
  `Mipo Puppet Maker` and delete `puppet` from keywords to reclaim ~7 chars.
- **Subtitle — the biggest missed win.** `Imagine, Create and Play` reads nicely but spends
  the whole (second-highest-weighted) field on mood words nobody searches. Fix keeps the
  voice *and* earns keywords:
  - `Imagine and make puppets` (24) — keeps "Imagine," adds `make` + `puppets` *(recommended)*
  - `Make and play with puppets` (26)
  - `A sandbox to make puppets` (25) — leans into the sandbox strategy
- **Keywords — right strategy (chasing the dress-up / sandbox / Toca-Boca audience, which is
  where the search traffic is), ~20 chars of waste.** Fixes:
  - `for kids` → `kids` (drop the stopword)
  - `create your own character` (25 chars!) → `create,character` (Apple forms the phrase)
  - spend the freed chars on **`marionette`** — proven EASY *and* relevant *and* Mipo is
    unranked for it (US and NL).
  - **`toca boca` is a competitor trademark** — common tactic, but technically against
    Apple's rules and *can* trigger a metadata rejection. Judgment call.

  Revised (same strategy, tighter, + marionette) — **97/100 chars:**
  ```
  ragdoll,sandbox,avatar,dolls,playtime,puppet,marionette,create,character,preschool,toca boca,kids
  ```

---

## Keyword landscape (from `aso-research.js`, 2026-07-03)

Difficulty is a **relative** proxy (crowding × incumbent strength) — *not* absolute search
volume. Zero competition ≠ opportunity unless people also search it (see the missing piece
below).

**US storefront:**
| Term | Difficulty | Note |
|---|---|---|
| `puppet maker` | MEDIUM 52 | Mipo ranks **#1** |
| `puppet pals` | EASY 25 | Mipo at #10, Education-dominated (its genre) — winnable |
| `marionette` | EASY 23 | Mipo **unranked** — clean, relevant add |
| `kids puppet` | MEDIUM 48 | Mipo at #9 |
| `stop motion` | ~HARD 65 | Stop Motion Studio (76k ratings) owns it — skip, low relevance |

**NL storefront:** `poppen maken` is EASY but **wrong intent** — it's dominated by dress-up
doll games (aankleden/meisjes/chibi), not puppet-making. The differentiated, near-empty
puppet-theatre words are the bet: `poppenkast`, `handpop`, `marionet` (all 0–3 difficulty).

---

## The missing piece (blocked, not our fault)

The one number this tool can't give — **relative search popularity** — comes from Apple's
new **Search Term Rank report** (App Store Connect → Analytics → **Insights**, launched Oct
2025). As of 2026-07-03 it is **not yet on this account** — a phased beta (the account's
Analytics sidebar has no "Insights" entry despite the app being live). Re-check periodically;
when it appears it turns every "0 competition" guess above into a real popularity number
(is `poppenkast` empty-and-searched, or empty-because-nobody-searches-it?).
