#!/usr/bin/env python3
r"""A public domain score (MIDI, e.g. from mutopiaproject.org) as music data for src/music-scores/.

    python3 -I claudetools/score-from-midi.py in.mid out.lua --name bethena --key 7 --meter 3 \
        --bars 1-28,29-67,211-219 [--rh 1 --lh 2]

Per bar, notes { step (16ths from the bar's start), midi, len (16ths), part, velocity, grace? }:
part 'lead' = the right hand's top voice (no higher right-hand note sounding at its onset), 'keys' =
the rest of the right hand and the left hand's upper notes, 'bass' = a left-hand note with no lower
left-hand note sounding at its onset. Velocity is the score's dynamics. Mutopia's MIDIs often leave them
out (the markings sit on a Dynamics line, which no staff performs); rebuild the MIDI from its .ly
with a midi-only score that puts the dynamics line into both staves and moves the performer:
    \new Staff << \rightHand \dynamics >>  \new Staff << \leftHand \dynamics >>
    \midi { \context { \Voice \remove "Dynamic_performer" } \context { \Staff \consists "Dynamic_performer" } }
(convert-ly -e first for old files; a .ly can run Scheme, so read it before compiling). Grace notes
(short, off the grid) get grace = true: played just before their 16th. Only the listed bars are
written (source bar numbers kept). Other onsets off the 16th grid are rounded and counted.
--pickup: beats of an opening upbeat, which becomes the end of bar 1. --bass-below: left-hand notes
from this midi up are keys. --lh-lead: bars where the tune is in the left hand (Gershwin's Prelude II,
bars 31-40): there the left hand's top voice is the lead and the right hand keys. --low-lead: bars
where the right hand holds a note above its tune (the Prelude's bars 15-16): its lowest voice leads.
A hand transcription (claudetools/scores/*.txt) becomes a MIDI with claudetools/score-from-text.py.
Only the notes are taken (the composition); nothing of a recording.
"""
import argparse, bisect, mido

def timed(track):
    t = 0
    for x in track:
        t += x.time
        yield t, x

ap = argparse.ArgumentParser()
ap.add_argument('midi'); ap.add_argument('out')
ap.add_argument('--name', required=True); ap.add_argument('--key', type=int, required=True)
ap.add_argument('--meter', type=int, default=4); ap.add_argument('--bars', required=True)
ap.add_argument('--rh', type=int, default=1); ap.add_argument('--lh', type=int, default=2)
ap.add_argument('--source', default='')
ap.add_argument('--pickup', type=float, default=0, help='beats in the opening pickup (upbeat): it becomes the end of bar 1')
ap.add_argument('--bass-below', type=int, default=128, help='left-hand notes at or above this midi are keys, not bass')
ap.add_argument('--lh-lead', default='', help='bars (1-10,20-22) where the tune is in the left hand: its top voice is the lead, the right hand keys')
ap.add_argument('--low-lead', default='', help="bars where the tune is the right hand's lowest voice (it holds a note above it)")
a = ap.parse_args()

m = mido.MidiFile(a.midi)
tpb = m.ticks_per_beat
step_ticks = tpb / 4
bar_ticks = tpb * a.meter

UNMARKED = 90 # LilyPond's velocity for a note with no dynamic marking
marks = [] # (onset, velocity) from the staves that carry dynamics: one curve for all the notes
def notes_of(track):
    vels = [(t, x.velocity) for t, x in timed(track) if x.type == 'note_on' and x.velocity > 0]
    # a voice without markings sits at LilyPond's default (90): only the others make the curve
    if len(set(v for _, v in vels)) > 1: marks.extend((t, v) for t, v in vels if v != UNMARKED)
    t, on, out = 0, {}, []
    for x in track:
        t += x.time
        if x.type == 'note_on' and x.velocity > 0:
            on.setdefault(x.note, []).append(t)
        elif x.type in ('note_off', 'note_on') and x.note in on and on[x.note]:
            start = on[x.note].pop(0)
            out.append((start, t, x.note))
    keep = {} # two voices on one note at one time (a unison): strike it once, the longer
    for (s, e, n) in out:
        if (s, n) not in keep or e > keep[(s, n)][1]: keep[(s, n)] = (s, e, n)
    return sorted(keep.values())

rh, lh = notes_of(m.tracks[a.rh]), notes_of(m.tracks[a.lh])
offgrid = 0
def grid(ticks):
    global offgrid
    s = ticks / step_ticks
    if abs(s - round(s)) > 0.01: offgrid += 1
    return int(round(s))

def bar_list(text):
    out = []
    for r in filter(None, text.split(',')):
        lo, hi = (int(x) for x in r.split('-'))
        out += range(lo, hi + 1)
    return out
pad = round((a.meter - a.pickup) * tpb) if a.pickup else 0
lh_lead, low_lead = set(bar_list(a.lh_lead)), set(bar_list(a.low_lead))
def tune_in_lh(s): return (s + pad) // bar_ticks + 1 in lh_lead
def tune_low(s): return (s + pad) // bar_ticks + 1 in low_lead

parts = []
for (s, e, n) in rh:
    if tune_low(s): # the tune under a held note: the lowest voice leads
        lower = any(s2 <= s < e2 and n2 < n for (s2, e2, n2) in rh)
        parts.append((s, e, n, 'keys' if lower else 'lead')); continue
    higher = any(s2 <= s < e2 and n2 > n for (s2, e2, n2) in rh)
    parts.append((s, e, n, 'keys' if higher or tune_in_lh(s) else 'lead'))
for (s, e, n) in lh: # bass: no lower left-hand note sounding at its onset (a held bass keeps the tenor keys)
    if tune_in_lh(s): # the tune is down here: the top voice leads
        higher = any(s2 <= s < e2 and n2 > n for (s2, e2, n2) in lh)
        parts.append((s, e, n, 'keys' if higher else 'lead')); continue
    lower = any(s2 <= s < e2 and n2 < n for (s2, e2, n2) in lh)
    parts.append((s, e, n, 'keys' if lower or n >= a.bass_below else 'bass'))
if pad:
    parts = [(s + pad, e + pad, n, part) for (s, e, n, part) in parts]

wanted = bar_list(a.bars)
bars = {b: [] for b in wanted}
marks.sort()
mark_times = [m[0] for m in marks]
def dynamic(s): # the latest marking at or before s; before the first, the first; none: 90 (LilyPond's own)
    if not marks: return UNMARKED
    k = bisect.bisect_right(mark_times, s) - 1
    return marks[max(k, 0)][1]
bar_steps = round(bar_ticks / step_ticks)
graces = 0
for (s, e, n, part) in sorted(parts):
    # a grace note: shorter than half a 16th and off the grid; it lands on the 16th after it and is
    # played a moment early (flag g)
    grace = (e - s) < step_ticks / 2 and abs(s / step_ticks - round(s / step_ticks)) > 0.01
    if grace:
        graces += 1
        st_abs = int(-(-s // step_ticks))
    else:
        st_abs = grid(s)
    b, st = st_abs // bar_steps + 1, st_abs % bar_steps
    if b in bars:
        bars[b].append((st, n, 1 if grace else max(1, grid(e - s)), part, dynamic(s - pad), grace))

with open(a.out, 'w') as f:
    f.write("-- luacheck: no max line length\n")
    f.write(f"-- {a.name}: generated by claudetools/score-from-midi.py from {a.source or a.midi}\n")
    f.write("-- The composition only (public domain notes), played by our own synth. Per bar (source bar\n")
    f.write("-- numbers): { step in 16ths, midi, len in 16ths, part, velocity, grace? }; part l = lead, k = keys,\n")
    f.write("-- b = bass; velocity 1-127 from the score's dynamics, `velocity` the piece's usual one (the median).\n")
    vels = sorted(v for b in wanted for (_, _, _, _, v, _) in bars[b])
    f.write(f"return {{ key = {a.key}, meter = {a.meter}, velocity = {vels[len(vels) // 2] if vels else 90}, bars = {{\n")
    code = {'lead': 'l', 'keys': 'k', 'bass': 'b'}
    for b in wanted:
        cells = ', '.join(f"{{{st},{n},{ln},'{code[p]}',{v}{',true' if g else ''}}}" for (st, n, ln, p, v, g) in bars[b])
        f.write(f"    [{b}] = {{ {cells} }},\n")
    f.write("} }\n")
print('bars', len(wanted), 'notes', sum(len(v) for v in bars.values()), 'graces', graces, 'rounded onto the 16th grid', offgrid)
