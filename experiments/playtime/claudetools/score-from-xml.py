#!/usr/bin/env python3
r"""A MusicXML score (.mxl, .musicxml, .xml: MuseScore's "Download > MusicXML") as a score for the analysis.

    ~/.venvs/scores/bin/python -I claudetools/score-from-xml.py in.mxl out.lua [--rh 1 --lh 2] [--name x]
        [--parts]   only list the parts and staves, numbered, to pick --rh/--lh

For reference material (~/music-reference/, docs/MUSIC-ANALYSIS.md: learning only, never in the repo) as
much as for public domain pieces. The two staves (or parts) given as --rh/--lh become the two hands of
claudetools/score-from-midi.py, which writes the score; by default the first two staves, which for a
piano arrangement are its right and left hand. Other parts are left out (listed, so you can pick).
Chord symbols are taken out (MIDI would play them) and counted; grace notes go too (music21 writes
them with no end). Repeats are played as written once, not expanded.
Needs music21 and mido (the ~/.venvs/scores venv).
"""
import argparse, os, subprocess, sys, tempfile
import music21 as m

HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('score'); ap.add_argument('out', nargs='?')
ap.add_argument('--rh', type=int, default=1); ap.add_argument('--lh', type=int, default=2)
ap.add_argument('--name', default=''); ap.add_argument('--parts', action='store_true')
a = ap.parse_args()

score = m.converter.parse(a.score)
staves = list(score.parts)
for i, p in enumerate(staves, 1):
    notes = len(p.recurse().notes)
    print(f'  {i}: {p.partName or p.id}  {notes} notes, {len(p.getElementsByClass("Measure"))} bars')
if a.parts or not a.out: sys.exit(0)

ts = score.recurse().getElementsByClass('TimeSignature')
meter = ts[0].numerator * 4 // ts[0].denominator if ts else 4
ks = score.recurse().getElementsByClass('KeySignature')
key = ks[0].asKey().tonic.pitchClass if ks else 0
symbols = list(score.recurse().getElementsByClass('ChordSymbol'))
for el in symbols + [n for n in score.recurse().notes if n.duration.isGrace]:
    el.activeSite.remove(el)
for d in list(score.recurse().getElementsByClass('Dynamic')): d.activeSite.remove(d)   # velocities stay

keep = m.stream.Score()
for i in (a.rh, a.lh): keep.insert(0, staves[i - 1])
with tempfile.TemporaryDirectory() as tmp:
    mid = os.path.join(tmp, 'score.mid')
    keep.write('midi', mid)
    name = a.name or os.path.splitext(os.path.basename(a.score))[0]
    r = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'score-from-midi.py'), mid, a.out, '--name', name,
                        '--key', str(key), '--meter', str(meter), '--rh', '1', '--lh', '2',
                        '--source', os.path.basename(a.score)])
print(f'meter {meter}/4, key signature tonic {key}, {len(symbols)} chord symbols left out')
sys.exit(r.returncode)
