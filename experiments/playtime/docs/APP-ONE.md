# App one — from spikes to a first small Mipo app in the store

status: active

Written 2026-11-16, when Nikki asked "imagine I want a business like Sago Mini, what are the next steps?"

## Why this plan

Since Puppetmaker, Playtime has grown about 80 spikes and a dozen active plans, and none of it is in a kid's
hands yet. The engine is far past what a small app needs. A Sago-style business is many small, finished,
polished apps around the same characters. So the next steps are deciding and shipping, not building.

The exploring phase (since 2026-11-01: breeds, the story, playing with the kids) goes on, but it now has an
end date: **app one is picked by 2026-12-15.**

The business model is in `../MANIFESTO.md` (the Sago Rule) and the parked `APP-1-BATHHOUSE-PLAN.md`: each app
its own paid listing at €2-3, an App Store bundle once there are three, Puppetmaker free as the way in.

## The dates

| | by |
|---|---|
| The candidates played with the kids, app one picked | 2026-12-15 |
| App one in TestFlight | 2027-01-31 (six weeks, with the holidays in them) |
| App one in the store | 2027-02-15 |
| Three months of sales looked at: is €2-3 paid the model? | 2027-05-15 |

A date that slips moves the scope, not the date (the Sago Rule).

## The steps

- [ ] **AO1. The candidates on one page.** The spikes that are nearly a one-verb toy already, each with its
  verb, what a kid gets at the end, what the Mipo does, and how it runs on the SE 2: dig (burrow), wash
  (dirt, the bathhouse), pour (sand), sail and float (drawn-sea, boat2), carry and throw (dollhouse), and any
  others Nikki names. The test for each: a 3-year-old gets it in 5 seconds without words, it ends in a
  surprise, the Mipo answers what the kid does, and it runs at 60 fps on the phone.
  2026-11-16: Nikki leans to dig: three digging apps (mole, treasure hunters, ant farm), the mole first,
  thought through in `DIGGING-SERIES.md`.
- [ ] **AO2. Played by the kids.** The two or three best on the iPad/iPhone (`./playtime.sh device`), each
  played by Nikki's kids without explaining. Write down how long each one held them, and what they tried to
  do that the game didn't do.
- [ ] **AO3. App one picked** (by 2026-12-15): its verb, its name, and a written "not in this app" list. The
  Sago Rule from here on: no "and also"; a second idea goes to app two.
- [ ] **AO4. Its own scene and ship list.** The app as one scene (or a few) with only what it needs
  (`claudetools/ship-list.py`), its own start screen, no editor. No new spikes in the engine until it ships;
  fixes only where the app needs them.
- [ ] **AO5. Store things the Kids category asks for:** a parental gate in front of every link (and the
  "more apps" button), no third-party analytics or ads, a privacy policy page, iPad and iPhone layouts, the
  age band. Paid up front needs no in-app purchases, so `APPELFLAP-ISSUES.md` doesn't block this app.
- [ ] **AO6. The store page:** icon, name and keywords (what `APP-STORE-ASO.md` learned from Puppetmaker),
  screenshots, a 15-30 s preview video.
- [ ] **AO7. TestFlight** (by 2027-01-31): on the family's devices for a week, crashes and the slowest frames
  checked (`./playtime.sh bench device`).
- [ ] **AO8. In the store** (by 2027-02-15).
- [ ] **AO9. Puppetmaker as the way in:** a "more Mipo apps" button behind a parental gate that opens app
  one's store page. First check that Puppetmaker still builds on this machine (`APP-STORE-ASO.md` says it
  may not).
- [ ] **AO10. The launch on mipo_club:** the making of app one as a YouTube video (the layered-reveal format).
- [ ] **AO11. Three months of numbers** (by 2027-05-15): downloads, sales, where buyers came from. Then
  decide: another paid app every 6-8 weeks, or another price model (free with one unlock, as Sago and Toca
  Boca moved to; that would put `APPELFLAP-ISSUES.md` back on the path).

## After app one

If the numbers say go: one small app every 6-8 weeks, each reusing the Mipos and one engine piece, each one
also a video and a line in Puppetmaker. The App Store bundle from the third app on.
