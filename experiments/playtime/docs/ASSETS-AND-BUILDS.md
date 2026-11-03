# Assets and builds — where things live, how drawings get in, what ships

status: active

Nikki 2026-11-03: "our assets are all over the place, source files too; keep in mind we will be
growing levels, textures and more." This plan tidies it in small steps that each leave the game
working, and makes a new drawing cheap to get in. Measured on 2026-11-03 (the numbers below).

## How it is now

**Work that isn't in git.** Saving a scene ('s') writes to the LÖVE save folder
(`~/Library/Application Support/LOVE/playtime/`, 439 MB: 204 scenes, 1039 PNGs, videos, flight
recordings), not to `scripts/`. Only scenes copied over by hand reach the repo and the builds, and
some exist in both places with no telling which is newer (`crowd.playtime.json`). The library's
8 prefabs and the music setups live only there.

**The builds ship everything.** `native/ios/device.sh` and `webtest/build-web.sh` copy all of
`assets/` and `textures/`. About 83 of 330 textures (3.3 MB) aren't named by any scene or code (old
feet, necks, torsos, patterns), the Knut textures (`textures/knut/`, 1.4 MB) ride along, and so do
unused sounds (`cr78`, `bd-perc`, two rubber-stretch), two old music loops, two start images
(1.4 MB), a font.

**Textures are one flat folder**: 297 files in `textures/` (ears, feet, noses, brows, outlines next to
masks), `pat/`, `knut/` and `world/` (one file). The names carry the structure (`earx12r-mask.png`).

**Scenes**: `scripts/` holds the rooms (overworld, bakery, treehouse), the spikes and the checks
together, data and code side by side (SCENES.md says which to keep).

**Source art is in five places or nowhere**: `oldtextures/`, `knut-is-dead/` (15 MB, still used by 3
scenes), `backdrops/` (Knut), `krita/`, `archive/scenes`. The scans aren't kept at all.

**Build outputs in git**: `webtest/output-*` (19 MB, 26 MB in history). `native/ios/` (489 MB) and
`.snapshots/` are rightly ignored. `profilingReport6.txt` is committed.

## How a drawing gets in (Nikki)

Drawn on paper, scanned, then in GIMP the white turned transparent (and the colours flipped). The
`-mask` is a shape drawn on paper too and treated the same way. The papers are kept, the scans are
not. Then, sometimes, `experiments/alpha-padder` (2023, LÖVE: drop files; pads transparent pixels
with their neighbour's colour 1 px wide, an alpha multiplier, alpha to grey). Also on disk:
`~/Projects/alpha-bleeding-master` (urraka's C tool, the full bleed; not built).

Measured: of the 111 textures with a hard edge, 109 hide black under the transparency (fine under a
black outline); the masks have hard edges and a dark grey fill, so no halo shows today. Soft edges
drawn small would.

## Where it should go

```
playtime/
  textures/                    what the game draws, by use
    mipo/<part>/               ears, feet, noses ... (outline + -mask side by side)
    world/                     grass, ground, props
    pat/                       patterns
  scripts/
    rooms/                     the game's rooms (what ships)
    spikes/                    experiments and checks (SCENES.md)
  library/                     prefabs, in the repo (the game reads these, saves new ones here)
  assets/                      sounds, voices, fonts, icons: what's used
  tools/art/                   the scan-to-texture tool
~/Projects/mipo-art/           outside the repo, backed up
  scans/<same layout>/         every scan, as scanned
  sources/                     .kra, GIMP files
  archive/                     Knut, old textures, backdrops
```

## Steps

Each step leaves every scene loading the same (`spec/scenes-smoke_spec.lua`, and a before/after
snapshot for the moves, MEASURING.md) and both builds working.

- [ ] **AB1. The scan-to-texture tool, tried on one scan.** A LÖVE tool like the alpha padder (drop a
  scan, see it, a slider or two): levels and a threshold, the paper to transparent and the ink to a
  clean line, the bleed a few pixels wide, saved under the scan's name. Try it on one fresh scan of
  an existing part, side by side with the GIMP version in the game. Only then the rest of the tool
  (masks, batches, naming).
  Prototype (2026-11-03, no scanner at hand, so on the old scans in `vector-sketch/scans/`, 300 dpi
  grayscale sheets of many parts): `claudetools/scan2tex.py` cuts a sheet into its parts, ink -> a white
  line with the crayon grain in its alpha, white under the transparency (no halo), the MASK filled from
  the outline (gaps closed first), opaque grey as the bake shader reads it (`.r`); the scanner's paper
  edge dropped. `scan2tex-preview.py` draws them as the game does. Scan 12 (ovals, eyes, lines, lips):
  31 parts, all apart, masks right; Scan 14 (feet, sprouts): good, but its dust leaves specks. Still
  to do: the specks, naming the parts, the size per part, open shapes (a line: no mask), then a real
  look in the game and the LÖVE version.
  The MASK, after Nikki's look: the whole shape, line included, its edge smoothed (no rough pixels)
  and pulled in INSET px (2) from the line's outer edge: under the line, never past it. First tries
  went past it (filled to the grown line) and then fell short (only to the line's middle). "Hit and
  miss", so INSET is a setting. The scene `scan-test` bakes the parts as the game does, above the
  game's own GIMP parts (which have colour past the line too); `textures/scantest/` is made from the
  scans (in git, `vector-sketch/scans/`), not committed.
  OPEN parts (lines, single strokes, filled dots) get no mask file, as the game's brows, hair, pupils
  and lines have none (the bake draws them outline only): a part is open when under 7% of its shape
  is enclosed space, not line (Nikki; lines 0-6% open, the fern 12% and the lips and sprouts 17-33% get
  a mask, ovals and feet 30-78%).
  SPECKS: islands of anything visible (grown 1 px, so grain next to the line counts as the line) under
  60 px go, before the outline is written (the first cut cleaned them after: they stayed). Dust around
  the parts gone; the crayon grain kept.
  PHONE PHOTOS (Nikki: "a bad relationship with my scanner"): HEIC through `sips`, the photo turned
  upright (EXIF), the paper's brightness estimated (ink taken out, a big blur) and divided out, so a
  shadow or dark corners go; a median for the grain. Tried on Scan 14 made into a fake phone photo
  (a shadow over a corner, warm light, noise, JPEG): the same 10 parts, clean, masks right; the line
  a little smoother (the median). A REAL photo (IMG_5534.HEIC, 2026-11-03, a sheet shot sideways with
  the table edge in view): 13 parts, clean, masks on the closed shapes, the table edge dropped. It
  showed one fault, now fixed: a part cut as a box took a neighbour's ink with it (the d and the B side
  by side); each part keeps only its own ink now. Phone photos are good enough to skip the scanner.
  The mask's inset follows each part's LINE: about 60% of half its thickness (measured), INSET px at
  least, the soft fringe counted as line (the photo's upper lip had colour at its line's edge). Shapes
  that ALMOST close are Nikki's call per part ("it depends"): FILL='name-05:close,name-01:open', auto /
  close (the line's hull: the opening drawn shut) / open (no mask) / mask; in the LÖVE tool a click.
  THE TOOL (2026-11-03): `love tools/scan2tex` (from a terminal: it runs claudetools/scan2tex.py with
  the python3 that has Pillow and numpy). Drop a photo or scan; the sheet shows with its parts boxed,
  the selected one baked large. Enter names it, f fill, r turns 90°, x skips; the sheet's settings
  (size, mask inset, into the line, open below) with - / +; ctrl-s writes the named parts into
  textures/ (turned by copying pixels: a canvas lost the white under the transparency). Per sheet it
  remembers the names and picks (its save folder's sheets.json). LOOKS LIKE (Nikki: "a check that it
  won't add similar or identical things, or asks"): every part's silhouette against the game's 213
  textures and the sheet's other parts, overlap (IoU) turned and mirrored, 85%+ listed with a picture;
  saving one of those, or over an existing name, asks (ctrl-s again). `--test <file>` /
  `--test-save <file>` run it without clicking (a screenshot in its save folder). Not yet: a size per
  part, writing into a subfolder, the catalogs (shape-catalogs.lua) learning the new names.
- [ ] **AB2. Keep the scans.** `~/Projects/mipo-art/scans/`, laid out like `textures/`, backed up
  (a cloud folder or a disk). New drawings from now on; old papers rescanned when a part is touched.
- [ ] **AB3. Prefabs, setups and saved scenes into the repo.** The game reads `library/` and music
  setups from the repo first (the save folder as the fallback), and on the desktop the editor saves a
  scene straight into `scripts/` (io.open works there; the web build keeps the save folder). Sort
  out the 204 saved scenes once: which are newer than the repo's copy, which are worth keeping.
- [ ] **AB4. Build outputs out of git.** `webtest/output-*` into `.gitignore` and `git rm --cached`;
  `profilingReport*.txt` ignored.
- [ ] **AB5. Ship what's used.** First an exclude list in both build scripts (Knut, the unnamed
  textures, the unused sounds), the .love size before and after; later a list per room of what its
  scenes use, if rooms grow apart.
- [ ] **AB6. Textures in folders by use.** A move list (old path -> new), the loader looks a missing
  old name up in it so old scenes and the save folder's copies still load; then the scenes rewritten
  on their next save. `claudetools/` gets a check that lists every texture a scene or the code names
  and every file nothing names.

  **The names** (Nikki 2026-11-03: English everywhere; `x` "was just some variant, no real meaning"):
  - `mipo/<part>/<part>-<nn>.png` + `<part>-<nn>-mask.png`, numbered 01, 02… per part; world art in
    `world/`, patterns in `pat/`. A second take on the same part is just the next number.
  - Parts: `foot` (feet), `ear` (earx), `nose`, `body` (shapes, shapeA, shapeX: the torso/head
    shapes, `torsoHeadShapes`), `torso` (romp), `chesthair` (borsthaar), `neck`, `leg`, `hand`, `hair`,
    `brow`, `eye`, `pupil`, `teeth`, `upperlip`, `lowerlip`, `patch`.
  - The `r` (turned upright) goes: the upright one is the part. The unturned originals and the `x`
    variants nothing names go to the art archive (AB8), as do the leftovers (`hair5_`, `romp3__`,
    `type3_`, `null`, …) once the check says nothing names them.
  - The move list is the only place old names live; `tools/scan2tex` saves under the new names (pick
    a part, it offers the next free number).
- [ ] **AB7. Rooms and spikes apart.** `scripts/rooms/` and `scripts/spikes/` (scene-catalog already
  walks folders); the builds take rooms from `rooms/`.
- [ ] **AB8. The source art out of the game folder.** `oldtextures/`, `backdrops/`, `krita/`, Knut's
  pictures not used by a scene into `~/Projects/mipo-art/`; the 3 scenes using `knut-is-dead/` keep
  theirs (or go to `spikes/` with them).

Later, not steps yet: the tool making the mask from the outline when they're the same shape; a
texture atlas per Mipo part set (MIPO-DRAWING.md says it saves nothing on the phone today); Playtime
in its own repo (it's `vector-sketch/experiments/playtime`, a 639 MB `.git` shared with the old app).
