# Playtime docs — how they're kept

status: reference

Where the work stands is not written down here. It comes from the docs themselves:

```bash
./playtime.sh todo          # active plans with their next steps, parked plans, drift warnings
./playtime.sh todo --all    # also the done and reference docs, with titles
```

(`claudetools/plans.lua`. A Claude session sees it at start, through a hook in `.claude/settings.json`.)

## The rules

- **One status line** under each doc's title, the only thing kept by hand:
  `status: active`, `status: idea`, `status: parked — why`, `status: done` or `status: reference`.
  `idea` is a notebook added to now and then (KING-ROLLO, MUSIC-IDEAS): listed, no next steps, no warnings.
  No free-text "Status: ... built, ... next" lines: those are what went out of date.
- **Steps are checkboxes**: `- [ ] **W2. Persistence.** ...`, ticked `- [x]` when done (with the
  date in the text). `- [~]` is a step parked inside an active plan. A short id at the start
  (W2, P8, G3) lets the drift check find commits that name it.
- **A new plan** is a new doc with a status line and checkboxes. It shows up on the board.
- **When a step is done:** tick it in the same commit as the code, and name the id in the
  commit message.
- **The drift warnings** say what to fix: an active doc untouched for 3 weeks (still active?),
  an active doc with every box ticked (done?), a commit naming an unticked step, a doc
  without a status line. Fix them when they show up, a minute each.

## Folders

- `done/` — old finished docs, kept for history.
- `knut/` — the Knut mini-game (commission fizzled 2026-04-22); the rigging pipeline is still useful.
- `notes/` — loose research notes and drafts.
