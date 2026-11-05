# claudetools

Dev tools for Playtime: textures, music, voices, measuring and upkeep. None of them ship with the game.
Run them **from `experiments/playtime/`** (the paths below assume that), unless a tool says otherwise.
Each file's top comment is the full usage; this page is the map, and what each one needs installed.

## Setting up a machine

| Need | For | Install |
|---|---|---|
| `luajit` | every `.lua` tool run outside the game | `brew install luajit` |
| `libdesound.dylib` | anything that makes sound offline (render-music, drum-audition, the music checks) | dreamengine in `~/Projects/dreamengine`, then `native/desound/build.sh` (docs/SOUND-SYNTH.md). Rebuild after pulling dreamengine |
| LÖVE 11.5 | scan2tex, drawcall-bench, make-door-rooms, snapshot.sh | `/Applications/love115.app` |
| Pillow, numpy, scipy | scan2tex, texture-outline | `python3 -I -m pip install --break-system-packages pillow numpy scipy` |
| mido, music21 | score-from-midi / -text / -xml | same command, `mido music21` (or the `~/.venvs/scores` venv, docs/MUSIC-ANALYSIS.md) |
| librosa, soundfile | chords-from-audio, stem-*, voice-pitch, the voice tools | `pip install librosa soundfile` (see below) |
| pyworld | voice-bake, voice-morph, choir-world-render | a venv: `python3 -m venv --system-site-packages /tmp/venv && /tmp/venv/bin/pip install pyworld` |
| demucs | splitting a song into stems before stem-report | `pip install demucs` (big: pulls in torch) |
| `ffmpeg` | mp3 input for the audio tools | `brew install ffmpeg` |
| `sips` | HEIC phone photos in scan2tex | built into macOS |

**Why `python3 -I -m pip`, not `pip install --user`:** the tools run Python with `-I` (isolated mode),
which ignores the per-user site-packages. A `--user` install is invisible to them (scan2tex then says
"is python3 the one with Pillow and numpy?"). Install into the Python itself, with pip run under `-I` too.

**librosa on an Intel Mac** (2026-11-05): it fails to build on Python 3.13 and 3.14, because
newer llvmlite (librosa → numba → llvmlite) has no Intel-Mac wheel and won't build from source. Still to
try: an older llvmlite/numba with wheels (`--only-binary llvmlite,numba`), or Python 3.11.

Check what's missing: every tool's imports against the Python the tools use:

```sh
python3 -I - <<'EOF'
import ast, glob, importlib.util, sys
for f in sorted(glob.glob('claudetools/*.py')):
    mods = set()
    for n in ast.walk(ast.parse(open(f).read())):
        if isinstance(n, ast.Import): mods |= {a.name.split('.')[0] for a in n.names}
        elif isinstance(n, ast.ImportFrom) and n.module and n.level == 0: mods.add(n.module.split('.')[0])
    miss = [m for m in sorted(mods) if m not in sys.stdlib_module_names and not importlib.util.find_spec(m)]
    if miss: print(f, miss)
EOF
```

## Textures and drawings

| Tool | What | Run |
|---|---|---|
| `scan2tex.py` | A scan or phone photo of a sheet of drawings → Playtime textures (outline + mask per part). The engine behind `tools/scan2tex`, the LÖVE window you normally use (`love tools/scan2tex`, docs/ASSETS-AND-BUILDS.md AB1) | `python3 -I claudetools/scan2tex.py <scan.png\|photo.heic> <outdir> [name]` |
| `scan2tex-preview.py` | The parts drawn as the game would (mask filled, outline on top), one sheet | `python3 -I claudetools/scan2tex-preview.py out.png "dir/name-*.png"` |
| `texture-check.py` | Texture names pointing at nothing, and files in `textures/` nothing names | `python3 -I claudetools/texture-check.py [--no-save] [-v]` |
| `texture-outline.py` | An 8-point outline for `src/shape8-dict.lua`, measured from a texture | `python3 -I claudetools/texture-outline.py mipo/body/body-18` |
| `shape8-from-meta.lua` | The meta scene's traced outlines vs `src/shape8-dict.lua` and the catalogs | `lua claudetools/shape8-from-meta.lua` |

## Music

docs/SOUND-SYNTH.md, docs/MUSIC-ANALYSIS.md. The `.lua` ones run the real `src/music.lua` offline with luajit;
most take the same env switches as render-music (`IDEAS=`, `VOICES=`, ...: see its top comment).

| Tool | What | Run |
|---|---|---|
| `render-music.lua` | A style rendered to a WAV, no app needed | `luajit claudetools/render-music.lua out.wav 30 bossa auto [busyFrom] [seed]` |
| `music-when.lua` | What plays between two seconds of a render ("a weird note at 50 s") | `luajit claudetools/music-when.lua bossa 1 48 52` |
| `music-rubs.lua` | Half-step rubs between parts in a recorded song | `luajit claudetools/music-rubs.lua song.lua [bars]` |
| `music-harmony.lua` | Chord changes per 8 bars, roots outside the key | `luajit claudetools/music-harmony.lua <style> [ideas] [songs]` |
| `music-answer-check.lua` | The answer's notes outside both key and chord | `luajit claudetools/music-answer-check.lua <style> [songs]` |
| `music-trace.lua` | Every call the music makes to the synth (plus its moments and chords) over 133 fixed scenarios (every style, the ideas, the jam's picks), as text: take before a refactor, take after, diff. `--c` also logs every call synth.lua makes into the C library (NoteOpts field by field), for changes inside synth.lua | `luajit claudetools/music-trace.lua take /tmp/before [--c]`, `... diff /tmp/before /tmp/after` |
| `drum-audition.lua` | One WAV per drum role: old jam voice / 808 / 909 | `luajit claudetools/drum-audition.lua <outdir>` |
| `jam-patterns.py` | Regenerates `src/music-jam-patterns.lua` from dreamengine's drum patterns | `python3 -I claudetools/jam-patterns.py` |
| `score-analysis.py` | Analysis sheet for a score: keys, chords, form, busy-ness, lines | `python3 -I claudetools/score-analysis.py src/music-scores/x.lua` |
| `style-report.py` | Every style next to the real pieces, in score-analysis's numbers | `python3 -I claudetools/style-report.py [--styles bossa] [--reference DIR]` |
| `score-from-midi.py` | A public-domain MIDI → a score in `src/music-scores/` | top comment (mido) |
| `score-from-xml.py` | MusicXML (MuseScore download) → a score | top comment (music21) |
| `score-from-text.py` | A hand-transcribed text score (`scores/*.txt`) → MusicXML + MIDI | top comment (music21) |
| `chords-from-audio.py` | Tempo, key, swing and chords from a recording | `python3 -I claudetools/chords-from-audio.py song.mp3` (librosa) |
| `stem-report.py` | Per demucs stem: when it plays, range, pitch classes, stereo | `python3 -I claudetools/stem-report.py <stem folder>` (librosa) |
| `stem-pieces.py` | One stem cut into note events, an example WAV per kind | `python3 -I claudetools/stem-pieces.py stem.wav <outdir>` (librosa) |
| `loop-period.py` | How long a part's loop is (a sampler's ~0.8, a live player's ~0.6) | `python3 -I claudetools/loop-period.py stem.wav start dur` (librosa) |
| `bass-notes.py` | A bass stem note by note in NoteOpts terms (timing, gain, length, decay, scoop, tone) | `python3 -I claudetools/bass-notes.py bass.wav [start dur] [--bpm N] [--grid drums.wav]` (librosa) |
| `loop-fold.py` | A looping bass part folded onto one cycle; writes `-notes.json` for the next two | `python3 -I claudetools/loop-fold.py bass.wav start end cycle_s beats anchor_s [--fixed]` (librosa) |
| `loop-fit.py` | Each pass of a riff fitted to its slots: per-note feel vs jitter, accents, octaves (the humanizing numbers) | `python3 -I claudetools/loop-fit.py notes.json start beat_s transpose [--scan] [--slots f.json]` |
| `slot-chroma.py` | What a keys / guitar part plays over each riff slot, pooled over passes | `python3 -I claudetools/slot-chroma.py stem.wav fit.json 1,2 [--slots f.json]` (librosa) |
| `stab-voicings.py` | A chord part's onsets with their notes, on a riff grid, the bass under each | `python3 -I claudetools/stab-voicings.py stem.wav fit.json notes.json [from to]` (librosa) |
| `drum-grid.py` | A drum stem as kick / snare / hat on the 16th grid: share of bars, timing, level | `python3 -I claudetools/drum-grid.py drums.wav start end bpm [--fixed anchor] [--min -12]` (librosa) |
| `find-sample.py` | Where in a source record a sampled piece comes from, and at what pitch | `python3 -I claudetools/find-sample.py piece.wav start dur source.wav` (librosa, scipy) |
| `find-drum-sample.py` | The same for a drum loop (sampler speed = pitch) | `python3 -I claudetools/find-drum-sample.py piece.wav start dur source.wav lo hi` (librosa, scipy) |
| `hooktheory-report.py`, `chordonomicon-report.py` | Style families' chords/tunes from reference datasets in `~/music-reference/` (learning only, never in the repo) | top comment |

## Mipo voices

docs/CHOIR.md, docs/PUPPETMAKER-SOUND.md.

| Tool | What | Run |
|---|---|---|
| `voice-pitch.py` | The pitch of every voice syllable → `src/voice-pitch-data.lua` | `python3 -I claudetools/voice-pitch.py [--no-write]` (librosa) |
| `voice-bake.py` | Syllables re-tuned with the WORLD vocoder → `assets/voices-baked/` (generated, not in git) | `/tmp/venv/bin/python -I claudetools/voice-bake.py` (pyworld) |
| `voice-morph.py` | Two voice takes morphed into each other | top comment (pyworld) |
| `choir-score-dump.lua` + `choir-world-render.py` | The choir scene's score offline, rendered by resampling or WORLD | top comment of choir-world-render.py |

## Measuring and performance

docs/MEASURING.md.

| Tool | What | Run |
|---|---|---|
| `sample-profile.lua` | Sampling profiler inside the running game (a few % overhead) | via the bridge, see its top comment |
| `frame-profile.lua` | Where a frame goes, step by step, plus garbage and GPU stats | via the bridge, see its top comment |
| `drawcall-bench/` | What draw calls cost on this machine (or the phone) | `love claudetools/drawcall-bench` |
| `snapshot.sh` + `snapshots/` | Before/after snapshots of scenes (textured), Mipos, the Mipo editor outlines (box2d-draw's drawWorld in 9 settings variants, plus a built-in world with what no scene has) the editor overlay (editor-render's renderActiveEditorThings in 278 selection / mode / edit states over 5 scenes) skinning (meshusertVertices on the hoop mesh in 15 setups — no bind, weights, painted bones, spine, groups, stale binds — times 3 poses; runs every line) and meshpanel (the MESHUSERT panel in 11 states, every button and slider clicked on a fresh load; runs every line of its draw) for refactors | `claudetools/snapshot.sh take before`, `... diff before after` |
| `flight-analyze.py`, `flight-window.py` | Summaries of a flight-recorder dump (`src/flight-recorder.lua`): grab force, joint stretch | `python3 claudetools/flight-analyze.py dump.json` |

## Checking the code

`claudetools/lint.sh` runs the checks in one go: luacheck (should say 0 warnings), module functions nothing
calls, shellcheck, ruff. `--all` adds luacheck's list of the most complex functions and lua-language-server
(~25 s). Only luacheck has to be clean; the rest are lists to read.

lua-language-server (2026-11-05, config `claudetools/luals.json`) is mostly noise here: it doesn't know
LÖVE's or Box2D's objects (undefined-field), scene scripts' globals (undefined-global, archive/) or tables
filled in later (need-check-nil, inject-field). Its known false alarms: `function lib.x(...) return y(...) end`
wrappers and `love.draw(lag / dt)` (redundant-parameter), `bassLine(...)` in music-parts (the bass lines take
different arguments), `dt or 1 / 60` (ambiguity-1). Installs: `brew install lua-language-server shellcheck`,
`python3 -I -m pip install --break-system-packages ruff` (Homebrew's ruff builds Rust from source on this Mac).

| Tool | What | Run |
|---|---|---|
| `lint.sh` | All the static checks | `claudetools/lint.sh [--all]` |
| `unused-functions.py` | `lib.x` / `M.x` / `ui.x` in src/ that nothing names | `python3 -I claudetools/unused-functions.py` |
| `luals.json` | lua-language-server's settings for lint.sh | |
| `scene-damage_spec.lua` | Every scene with one thing taken out (a body, joint, sfixture, Mipo entry; up to 25 of each), loaded, drawn, stepped, saved and loaded again; errors grouped by message with a traceback, lost bodies, and what was only logged. ~1250 loads, 5-15 minutes. Finds what a deleted part or a damaged file breaks | `DAMAGE_OUT=/tmp/d.txt love . --specs claudetools/scene-damage_spec.lua` (`DAMAGE_ONLY=<scene>`, `DAMAGE_PER_KIND=n`) |
| `editor-actions_spec.lua` | Every scene with one editor action done through the inspector's own rows (resize, flip, clone, destroy, a joint's limits / motor / collide, an sfixture moved or destroyed) or an sfixture attached from the tool rail; then checked (sfixtures first on every body, the registry holding no destroyed object), drawn, stepped, saved and loaded again (as many bodies, joints, sfixtures). One case per row and kind of target per scene. ~5400 actions, ~15 minutes | `ACTIONS_OUT=/tmp/a.txt love . --specs claudetools/editor-actions_spec.lua` (`ACTIONS_ONLY=<scene>`, `ACTIONS_PER_KIND=n`) |
| `tool-modes_spec.lua` | The editor's tool modes and drags, driven by the mouse through input-manager (joint anchors, sfixture placing, ribbon / mesh nodes, mesh triangles, Steiner points, polygon and texture corners, making joints, the draw tools, dragging), each whole and cut off halfway (its thing destroyed or rebuilt from its panel, another tool, tool off, play and back, the room again), then a next click; full editor frames (world, overlay, panels). Reports throws, tools left on with their thing gone, the world checks, save and reload. ~3400 runs, ~15 minutes, ~200-400 MB (`TOOLS_MEM=1`: a memory line per run) | `TOOLS_OUT=/tmp/t.txt love . --specs claudetools/tool-modes_spec.lua` (`TOOLS_ONLY=<scene>`) |
| `feature-rounds_spec.lua` | The little-used features (`docs/LITTLE-USED.md`), each built from nothing in a closed room, then every inspector row and tool-rail attach on it, a clone of the whole and of the feature alone, a save loaded and saved again (must match), a minute of play dragged about, turned upside down; at 200 and 400 px per metre. The sweep checks plus the feature's own (a blob keeps its rim and its handle inside it; every lit body gets every light; grass has blades at any angle; water within what its container holds, its level holding its amount; a tile mesh covering its body; nothing NaN or out of the room), on the world and its reload. Recipes pick looks at random: try a few seeds. Soft body: 116 cases, ~3 s; light 502, ~4 s; grass 202, ~1 s; liquid 178, ~2 s; tile repeat 182, ~1 s | `FEATURES_OUT=/tmp/f.txt love . --specs claudetools/feature-rounds_spec.lua` (`FEATURES_ONLY=softbody`, `FEATURES_SEED=n`, `FEATURES_CASE=<part of a label>`) |
| `actions.lua` | One editor action on a loaded world (the inspector's rows, a texfixture's accordion rows too, tool-rail attaches, or a function), then checked, drawn, stepped, saved and reloaded | required by editor-actions and feature-rounds |
| `sweep.lua` | What the sweeps share: scene list, fresh world, a frame, steps as the game takes them (blob rims, water, signals, snaps; a bare `world:update` skipped blobs and water), catching logger.error, the world checks, save and reload, the grouped report | required by them |

## Project upkeep

| Tool | What | Run |
|---|---|---|
| `plans.lua` | The work board, built from the docs' `status:` lines and checkboxes | `./playtime.sh todo` |
| `ship-list.py` | What a build packs; both the web and iOS builds read it | `python3 -I claudetools/ship-list.py <scene> [--report]` |
| `find-forward-refs.lua` | Local functions used before they're defined (breaks hot reload). Too many false alarms; use luacheck | `lua claudetools/find-forward-refs.lua [dir]` |
| `make-door-rooms.lua` | Rebuilds the door test rooms in `scripts/` (overwrites them) | `love . --specs claudetools/make-door-rooms.lua` |
| `old/concat2.lua` | Dumps the code into one `output.md` (needs luafilesystem). Unused since 2026-05 | `lua claudetools/old/concat2.lua <dirs or files>` |
