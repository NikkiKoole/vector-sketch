#!/usr/bin/env python3
r"""A score transcribed by hand as text (claudetools/scores/<name>.txt) as MusicXML + MIDI.

    ~/.venvs/scores/bin/python -I claudetools/score-from-text.py claudetools/scores/gershwin-prelude2.txt out
        -> out.musicxml (open it in MuseScore to check by eye and ear) and out.mid (for score-from-midi.py:
           track 1 the right hand, track 2 the left)

Needs music21 (in the ~/.venvs/scores venv). The text, one line per hand per bar:
    <bar> R: <voice> ; <voice>      R = right hand (treble), L = left hand (bass)
    <bar> = <other bar>             both hands as in another bar; <bar> R = <other> for one hand
A voice is events in time order: pitches/duration, duration in quarters (1/0.5/0.6667 for a triplet),
r/<duration> a rest, chords joined with +, ~ after one ties it into the next, g:<pitches> a grace note.
Every voice must fill the bar (the script stops and says which don't). ?? starts a remark (unsure,
check by ear); lines starting with # are comments. Settings:
    @title / @composer <text>    @meter 4    @tempo 88    @key <bar> <sharps, minus for flats>
    @dyn <bar> <mark> <velocity>   (from that bar on; score-from-midi.py turns velocities into volume steps)
Pitches are written as they sound (an 8va passage an octave up).
"""
import sys, re
from fractions import Fraction
import music21 as m

src, out = sys.argv[1], sys.argv[2]
bars = {}      # bar -> {'R': [voice...], 'L': [voice...]}, voice = [(pitches|None, dur, tie, grace)]
copies = []    # (bar, hand or None, from bar)
info = {'title': '', 'composer': '', 'meter': 4, 'tempo': None}
keys, dyns = {}, []   # bar -> sharps; [(bar, mark, velocity)]

def parse_voice(text):
    ev = []
    for tok in text.split():
        grace = tok.startswith('g:')
        if grace:
            ev.append((tok[2:].split('+'), 0, False, True)); continue
        tie = tok.endswith('~'); tok = tok.rstrip('~')
        p, d = tok.split('/')
        ev.append((None if p == 'r' else p.split('+'), Fraction(d).limit_denominator(12), tie, False))
    return ev

for line in open(src):
    if line.lstrip().startswith('#'): continue
    line = line.split('??')[0].strip()
    if not line: continue
    if line.startswith('@'):
        word, _, rest = line[1:].partition(' ')
        if word in ('title', 'composer'): info[word] = rest.strip()
        elif word in ('meter', 'tempo'): info[word] = int(rest)
        elif word == 'key': b, n = rest.split(); keys[int(b)] = int(n)
        elif word == 'dyn': b, mark, v = rest.split(); dyns.append((int(b), mark, int(v)))
        else: sys.exit('unknown setting: ' + line)
        continue
    mo = re.match(r'(\d+)\s*(R|L)?\s*=\s*(\d+)$', line)
    if mo:
        copies.append((int(mo[1]), mo[2], int(mo[3]))); continue
    mo = re.match(r'(\d+)\s+(R|L):\s*(.*)$', line)
    if not mo: sys.exit('bad line: ' + line)
    bars.setdefault(int(mo[1]), {})[mo[2]] = [parse_voice(v) for v in mo[3].split(';')]
for bar, hand, frm in copies:
    for h in ([hand] if hand else ['R', 'L']):
        bars.setdefault(bar, {})[h] = bars[frm][h]

n, meter = max(bars), info['meter']
bad = []
for b in range(1, n + 1):
    for h in 'RL':
        if h not in bars.get(b, {}): bad.append(f'bar {b} {h}: missing'); continue
        for vi, v in enumerate(bars[b][h]):
            total = sum(e[1] for e in v)
            if total != meter: bad.append(f'bar {b} {h} voice {vi + 1}: {float(total):g} beats')
if bad: sys.exit('\n'.join(bad))
dyns.sort()
def velocity(b):
    before = [v for start, _, v in dyns if start <= b]
    return before[-1] if before else 80

graces = []    # (track, onset in quarters, midi notes, velocity): music21 leaves grace notes out of MIDI
score = m.stream.Score()
score.insert(0, m.metadata.Metadata(title=info['title'], composer=info['composer']))
for track, (h, clef, name) in enumerate((('R', m.clef.TrebleClef(), 'Right hand'),
                                         ('L', m.clef.BassClef(), 'Left hand')), 1):
    part = m.stream.Part(); part.partName = name
    for b in range(1, n + 1):
        meas = m.stream.Measure(number=b)
        if b == 1:
            meas.insert(0, clef); meas.insert(0, m.meter.TimeSignature(f'{meter}/4'))
            if h == 'R' and info['tempo']: meas.insert(0, m.tempo.MetronomeMark(number=info['tempo']))
        if b in keys: meas.insert(0, m.key.KeySignature(keys[b]))
        for start, mark, _ in dyns:
            if start == b and h == 'R': meas.insert(0, m.dynamics.Dynamic(mark))
        voices = bars[b][h]
        for vi, v in enumerate(voices):
            target = m.stream.Voice(id=str(vi + 1)) if len(voices) > 1 else meas
            at = (b - 1) * meter
            for pitches, dur, tie, grace in v:
                if pitches is None:
                    el = m.note.Rest(quarterLength=dur)
                else:
                    el = m.chord.Chord(pitches) if len(pitches) > 1 else m.note.Note(pitches[0])
                    if grace:
                        el = el.getGrace()
                        graces.append((track, at, [p.midi for p in el.pitches], velocity(b)))
                    else: el.quarterLength = dur
                    if tie: el.tie = m.tie.Tie('start')
                    el.volume.velocity = velocity(b)
                target.append(el)
                at += dur
            if target is not meas: meas.insert(0, target)
        part.append(meas)
    score.insert(0, part)

score.write('musicxml', out + '.musicxml')
# the MIDI: music21 would scale the velocities by the dynamic marks, so they go (the velocities carry
# them already). Its grace notes go too: it writes them with no length, the note-off before the
# note-on, so the note never ends (and every note under it reads as an inner voice). Each grace note
# goes back in as a 1/24-beat note just before its beat, off the grid, which is how
# score-from-midi.py knows a grace note.
for d in list(score.recurse().getElementsByClass('Dynamic')): d.activeSite.remove(d)
for g in [n for n in score.recurse().notes if n.duration.isGrace]: g.activeSite.remove(g)
score.write('midi', out + '.mid')
import mido
mid = mido.MidiFile(out + '.mid')
tpb = mid.ticks_per_beat
for track in (1, 2):
    events, t = [], 0
    for x in mid.tracks[track]:
        t += x.time; events.append((t, 1, x))
    for tr, at, notes, vel in graces:
        if tr != track: continue
        on, off = round(at * tpb) - tpb // 24, round(at * tpb) - 1
        for note in notes:
            events.append((on, 0, mido.Message('note_on', note=note, velocity=vel)))
            events.append((off, 0, mido.Message('note_off', note=note, velocity=0)))
    end = [e for e in events if e[2].type == 'end_of_track']
    events = sorted((e for e in events if e[2].type != 'end_of_track'), key=lambda e: (e[0], e[1])) + end
    mid.tracks[track] = mido.MidiTrack()
    last = 0
    for t, _, x in events:
        mid.tracks[track].append(x.copy(time=max(0, t - last))); last = max(last, t)
mid.save(out + '.mid')
print('bars', n, 'grace notes', len(graces), '->', out + '.musicxml', out + '.mid')
