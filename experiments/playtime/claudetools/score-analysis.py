#!/usr/bin/env python3
r"""An analysis sheet for a score in src/music-scores/ (or a song recorded from a style, same format).

    python3 -I claudetools/score-analysis.py src/music-scores/gershwin2.lua [--form A:1-30,B:31-44,A:45-61]
        [--bars] [--json out.json]

What's in the piece, from its notes: the key regions, the chord of each bar (and its Roman numeral in
the key there), the form (which bars bring back earlier ones: the same, moved, or re-voiced), the
dynamics, per section how busy each part is and where it sits, the lines that move by step (an inner
voice creeping by half steps under a held chord, a line cliché), and the tune's cells that come back.
--bars adds the bar-by-bar table; --json writes the summary numbers, for comparing pieces and styles.
Notes come as midi numbers, so a name is spelled with sharps (E# shows as F).
Plain Python, nothing to install.
"""
import argparse, json, os, re, statistics, subprocess, sys, tempfile
from collections import Counter, defaultdict

ap = argparse.ArgumentParser()
ap.add_argument('score'); ap.add_argument('--form', default='')
ap.add_argument('--bars', action='store_true'); ap.add_argument('--json', default='')
a = ap.parse_args()

# --- reading the score: { step, midi, len, part, velocity, grace? } per bar --------------------------
# luajit runs the file (some scores build their bars in code) and prints one note per line
DUMP = r"""
local score = dofile(arg[1])
print('head', score.key or 0, score.meter or 4)
for b, notes in pairs(score.bars) do
    for _, n in ipairs(notes) do
        print(b, n[1], n[2], n[3], n[4], n[5] or 90, n[6] and 1 or 0)
    end
end
"""
with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False) as dump: dump.write(DUMP)
out = subprocess.run(['luajit', dump.name, a.score], capture_output=True, text=True, timeout=30)
os.unlink(dump.name)
if out.returncode: sys.exit(out.stderr)
text = open(a.score).read()
name = re.search(r'^-- (?!luacheck)(\S+?):', text, re.M)
name = name.group(1) if name else a.score
bars = defaultdict(list)
for line in out.stdout.splitlines():
    f = line.split('\t')
    if f[0] == 'head': tonic, meter = int(f[1]), int(f[2]); continue
    bars[int(f[0])].append({'step': int(f[1]), 'midi': int(f[2]), 'len': int(f[3]), 'part': f[4],
                            'vel': int(f[5]), 'grace': f[6] == '1'})
# an ensemble score names its parts (fl, vc, ...): their roles are in the style that plays it
styles = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'music-styles.lua')).read()
ROLE = {}
m = re.search(r"score = '" + re.escape(os.path.basename(a.score)[:-4]) + r"'(.*?)\n    \w+ = \{", styles, re.S)
if m: ROLE = dict(re.findall(r"(\w+) = \{ role = '(\w)'", m.group(1)))
order = sorted(bars)
steps_per_bar = meter * 4
PART = {'l': 'tune', 'k': 'keys', 'b': 'bass'}
def role(p): return PART.get(ROLE.get(p, p), p)

NAMES = 'C C# D D# E F F# G G# A A# B'.split()
def nm(midi): return NAMES[midi % 12] + str(midi // 12 - 1)

# --- keys: Krumhansl-Kessler profiles over a few bars around each one -------------------------------
MAJ = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MIN = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
def pc_weights(bs):
    w = [0.0] * 12
    for b in bs:
        for n in bars[b]:
            if not n['grace']: w[n['midi'] % 12] += n['len'] * (0.6 if role(n['part']) == 'tune' else 1)
    return w
def corr(x, y):
    mx, my = sum(x) / 12, sum(y) / 12
    num = sum((p - mx) * (q - my) for p, q in zip(x, y))
    den = (sum((p - mx) ** 2 for p in x) * sum((q - my) ** 2 for q in y)) ** 0.5
    return num / den if den else 0
def best_key(w):
    return max(((corr(w, prof[-t:] + prof[:-t]), t, mode) for t in range(12)
                for mode, prof in (('major', MAJ), ('minor', MIN))))[1:]
def third_of(w, t):
    """the key's third: 'minor', 'major', or 'blue' when both sound a lot (the blues' third)"""
    lo, hi = w[(t + 3) % 12], w[(t + 4) % 12]
    if lo and hi and min(lo, hi) / max(lo, hi) > 0.35: return 'blue'
    return 'minor' if lo > hi else 'major'
bar_key = {}
for i, b in enumerate(order):
    bar_key[b] = best_key(pc_weights(order[max(0, i - 4):i + 5]))
regions = []   # [first, last, (tonic, mode)], short runs folded into their neighbour
for b in order:
    if regions and regions[-1][2] == bar_key[b]: regions[-1][1] = b
    else: regions.append([b, b, bar_key[b]])
changed = True
while changed and len(regions) > 1:
    changed = False
    for i, r in enumerate(regions):
        if r[1] - r[0] + 1 < 4:
            j = i - 1 if i > 0 else i + 1
            if i + 1 < len(regions) and i > 0 and regions[i + 1][1] - regions[i + 1][0] > regions[i - 1][1] - regions[i - 1][0]:
                j = i + 1
            lo, hi = min(r[0], regions[j][0]), max(r[1], regions[j][1])
            regions[j][0], regions[j][1] = lo, hi
            del regions[i]; changed = True; break
    for i in range(len(regions) - 1, 0, -1):
        if regions[i][2] == regions[i - 1][2]:
            regions[i - 1][1] = regions[i][1]; del regions[i]
def key_of(lo, hi):
    w = pc_weights([b for b in order if lo <= b <= hi])
    t, mode = best_key(w)
    third = third_of(w, t)
    return (t, mode if third != 'blue' else 'blue')
def key_name(k): return NAMES[k[0]] + {'major': ' major', 'minor': ' minor', 'blue': ' (blue third: minor and major)'}[k[1]]
if a.form:   # the sections give the key regions: each section's key over the whole of it
    regions = []
    for part in a.form.split(','):
        lo, hi = (int(x) for x in part.split(':')[1].split('-'))
        regions.append([lo, hi, key_of(lo, hi)])
else:
    regions = [[r[0], r[1], key_of(r[0], r[1])] for r in regions]
for r in regions:
    for b in range(r[0], r[1] + 1): bar_key[b] = r[2]

# --- chords: the best-fitting template over the bar's notes, the bass note favoured as the root -----
CHORDS = [('', (0, 4, 7)), ('m', (0, 3, 7)), ('7', (0, 4, 7, 10)), ('maj7', (0, 4, 7, 11)), ('m7', (0, 3, 7, 10)),
          ('6', (0, 4, 7, 9)), ('m6', (0, 3, 7, 9)), ('dim', (0, 3, 6)), ('m7b5', (0, 3, 6, 10)), ('dim7', (0, 3, 6, 9)),
          ('aug', (0, 4, 8)), ('sus4', (0, 5, 7)), ('9', (0, 4, 7, 10, 2)), ('m9', (0, 3, 7, 10, 2)), ('5', (0, 7)),
          ('(m/M)', (0, 3, 4, 7)), ('7(m/M)', (0, 3, 4, 7, 10))]   # both thirds: the blue third
ROMAN = ['I', 'bII', 'II', 'bIII', 'III', 'IV', '#IV', 'V', 'bVI', 'VI', 'bVII', 'VII']
def chord_of(notes):
    notes = [n for n in notes if not n['grace']]
    if not notes: return None
    w = [0.0] * 12
    for n in notes: w[n['midi'] % 12] += n['len'] * (0.5 if role(n['part']) == 'tune' else 1)
    bass = min(notes, key=lambda n: (n['midi'], n['step']))['midi'] % 12
    total = sum(w) or 1
    best = None
    for root in range(12):
        for q, iv in CHORDS:
            pcs = {(root + i) % 12 for i in iv}
            fit = sum(w[p] for p in pcs) - 0.7 * sum(w[p] for p in range(12) if p not in pcs)
            fit = fit / total + (0.12 if root == bass else 0) - 0.03 * len(iv)
            if best is None or fit > best[0]: best = (fit, root, q, bass)
    _, root, q, bass = best
    return {'root': root, 'quality': q, 'bass': bass,
            'name': NAMES[root] + q + ('/' + NAMES[bass] if bass != root else '')}
def roman(ch, key):
    numeral = ROMAN[(ch['root'] - key[0]) % 12]
    if ch['quality'].startswith('m') and not ch['quality'].startswith('maj') or ch['quality'].startswith('dim'):
        numeral = numeral.lower()
    q = ch['quality'];
    q = q[1:] if q.startswith('m') and not q.startswith('maj') else q
    return numeral + q
chord = {b: chord_of(bars[b]) for b in order}

# --- form: does a bar bring back an earlier one? the same, moved (transposed), tune only, re-voiced -
def sig(notes, keep=lambda n: True, pc=False):
    return tuple(sorted((n['step'], n['midi'] % 12 if pc else n['midi'], n['len']) for n in notes if keep(n)))
def moved(s1, s2):
    if len(s1) != len(s2) or not s1: return None
    d = {y[1] - x[1] for x, y in zip(s1, s2)}
    return d.pop() if len(d) == 1 and all(x[0] == y[0] and x[2] == y[2] for x, y in zip(s1, s2)) else None
same_as = {}
family, letters = {}, iter('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz')
for b in order:
    hit = None
    full, tune = sig(bars[b]), sig(bars[b], lambda n: role(n['part']) == 'tune')
    pcs_rhythm = {(n['step'], n['midi'] % 12) for n in bars[b]}
    for e in order:
        if e >= b: break
        if not full: break
        if sig(bars[e]) == full: hit = ('same as', e); break
        t = moved(sig(bars[e]), full)
        if t is not None and t % 12: hit = (f'moved {t:+d} from', e); break
        if t is not None: hit = ('an octave away from', e); break
    if not hit and tune:
        for e in order:
            if e >= b: break
            te = sig(bars[e], lambda n: role(n['part']) == 'tune')
            if te == tune: hit = ('tune as', e); break
            t = moved(te, tune)
            if t is not None: hit = (f'tune {t:+d} from' if t % 12 else 'tune octave of', e); break
    if not hit and full:
        for e in order:
            if e >= b: break
            pe = {(n['step'], n['midi'] % 12) for n in bars[e]}
            if pe and len(pe & pcs_rhythm) / len(pe | pcs_rhythm) > 0.75: hit = ('re-voiced from', e); break
    same_as[b] = hit
    family[b] = family[hit[1]] if hit else (next(letters) if full else '-')

# --- lines that move by step: chains through each part's onsets --------------------------------------
events = defaultdict(lambda: defaultdict(list))   # part -> absolute step -> [midi]
for b in order:
    for n in bars[b]:
        if not n['grace']: events[role(n['part'])][(b - order[0]) * steps_per_bar + n['step']].append(n['midi'])
def where(t): return order[0] + t // steps_per_bar
lines, motion = [], {}
for part, ev in events.items():
    times = sorted(ev)
    # a line: notes 1-2 semitones apart, one direction, each within half a bar of the last; it lives
    # on through the part's other notes (an inner voice under a moving tune), a repeated note holds it
    active, done = [], []   # chains [(t, midi)]
    for t in times:
        gap = steps_per_bar // 2
        active, stale = [c for c in active if t - c[-1][0] <= gap], [c for c in active if t - c[-1][0] > gap]
        done += stale
        used = set()
        for midi in sorted(ev[t]):
            fits = [c for c in active if id(c) not in used and 0 <= abs(midi - c[-1][1]) <= 2
                    and (len(c) < 2 or midi == c[-1][1] or (midi - c[-1][1]) * (c[-1][1] - c[-2][1]) > 0)]
            if fits:
                c = min(fits, key=lambda c: (abs(midi - c[-1][1]) == 0, abs(midi - c[-1][1]), t - c[-1][0]))
                if midi != c[-1][1]: c.append((t, midi))
                else: c[-1] = (t, midi)
                used.add(id(c))
            else:
                c = [(t, midi)]
                # a turn: the old chain ends, a new one starts from its last note
                turned = [d for d in active if id(d) not in used and 0 < abs(midi - d[-1][1]) <= 2]
                if turned: c = [max(turned, key=lambda d: d[-1][0])[-1], (t, midi)]   # from the latest
                active.append(c); used.add(id(c))
    done += active
    seen = set()
    for c in done:
        ms = [m for _, m in c]
        if len(ms) >= 4 and tuple(c) not in seen:
            seen.add(tuple(c))
            chromatic = all(abs(y - x) == 1 for x, y in zip(ms, ms[1:]))
            lines.append({'part': part, 'from': where(c[0][0]), 'to': where(c[-1][0]),
                          'notes': [nm(m) for m in ms], 'chromatic': chromatic})
    # voice leading: each note against the nearest note of the part's previous onset
    moves, prev = Counter(), None
    for t in times:
        if prev:
            for midi in ev[t]:
                d = min(abs(midi - p) for p in prev)
                moves['hold' if d == 0 else 'step' if d <= 2 else 'leap'] += 1
        prev = ev[t]
    motion[part] = moves
# a line that is part of a longer one at the same time is shown once, as the longer one
lines = [l for l in lines if not any(o is not l and o['part'] == l['part'] and len(o['notes']) > len(l['notes'])
                                     and o['from'] <= l['to'] and l['from'] <= o['to']
                                     and ' '.join(l['notes']) in ' '.join(o['notes']) for o in lines)]
lines.sort(key=lambda l: (l['from'], l['part']))

# --- the tune's cells: three notes (two intervals + their rhythm) that come back ---------------------
tune = sorted((t, max(ms)) for t, ms in events.get('tune', {}).items())
cells = defaultdict(list)
for i in range(len(tune) - 2):
    (t0, m0), (t1, m1), (t2, m2) = tune[i:i + 3]
    if t2 - t0 > steps_per_bar: continue
    cells[(m1 - m0, m2 - m1, t1 - t0, t2 - t1)].append(where(t0))
top_cells = sorted(((k, v) for k, v in cells.items() if len(set(v)) > 2), key=lambda kv: -len(set(kv[1])))[:6]

# --- sections: --form, or the key regions ----------------------------------------------------------
if a.form:
    sections = []
    for part in a.form.split(','):
        label, rng = part.split(':'); lo, hi = (int(x) for x in rng.split('-'))
        sections.append((label, lo, hi))
else:
    sections = [(key_name(r[2]), r[0], r[1]) for r in regions]
def section_stats(lo, hi):
    bs = [b for b in order if lo <= b <= hi]
    out = {}
    for part in ('tune', 'keys', 'bass'):
        ns = [n for b in bs for n in bars[b] if role(n['part']) == part and not n['grace']]
        if not ns: continue
        onsets = {(b, n['step']) for b in bs for n in bars[b] if role(n['part']) == part}
        out[part] = {'per_beat': round(len(onsets) / (len(bs) * meter), 2),
                     'low': nm(min(n['midi'] for n in ns)), 'high': nm(max(n['midi'] for n in ns)),
                     'low_midi': min(n['midi'] for n in ns), 'high_midi': max(n['midi'] for n in ns),
                     'middle': nm(round(statistics.median(n['midi'] for n in ns)))}
    vel = [n['vel'] for b in bs for n in bars[b]]
    out['loudness'] = round(statistics.median(vel)) if vel else 0
    out['chords'] = len({chord[b]['name'] for b in bs if chord[b]})
    return out

# --- the sheet -------------------------------------------------------------------------------------
def spark(values, lo=None, hi=None):
    ticks = '▁▂▃▄▅▆▇█'
    lo = min(values) if lo is None else lo; hi = max(values) if hi is None else hi
    return ''.join(ticks[min(7, int((v - lo) / ((hi - lo) or 1) * 7.99))] for v in values)
def strip(fn):
    rows = []
    for i in range(0, len(order), 10):
        chunk = order[i:i + 10]
        rows.append(f'  {chunk[0]:>3}  ' + ' '.join(fn(b) for b in chunk))
    return '\n'.join(rows)

print(f'== {name}: {len(order)} bars of {meter}/4')
print('keys:   ' + ' · '.join(f'{r[0]}-{r[1]} {key_name(r[2])}' for r in regions))
print('\nform: a letter per bar, the same letter where a bar brings back earlier material')
print(strip(lambda b: family[b]))
vel = [statistics.median([n['vel'] for n in bars[b]] or [0]) for b in order]
print('\nloudness (the score\'s dynamics), a mark per bar')
print(strip(lambda b: spark(vel)[order.index(b)]))
print('\nchords (each bar\'s best fit; Roman numerals in the key there)')
print(strip(lambda b: f"{(roman(chord[b], bar_key[b]) if chord[b] else '-'):<7}"))

print('\nsections')
for label, lo, hi in sections:
    st = section_stats(lo, hi)
    parts = '  '.join(f"{p} {s['per_beat']}/beat {s['low']}-{s['high']}" for p, s in st.items() if isinstance(s, dict))
    print(f'  {label:<10} {lo:>3}-{hi:<3} loudness {st["loudness"]:>3}  {st["chords"]:>2} chords   {parts}')

print('\nhow each part moves (onset to onset, its top note): by step (1-2 semitones), leap, or holds')
for part, mv in sorted(motion.items()):
    total = sum(mv.values()) or 1
    print(f"  {part:<5} step {100 * mv['step'] // total:>3}%  leap {100 * mv['leap'] // total:>3}%  hold {100 * mv['hold'] // total:>3}%")

print('\nlines moving by step (4+ notes one way; * = by half steps, a chromatic line)')
for l in lines:
    print(f"  {l['part']:<5} bars {l['from']}-{l['to']}: {' '.join(l['notes'])}{'  *' if l['chromatic'] else ''}")

print('\nthe tune\'s cells that come back (intervals in semitones, rhythm in 16ths): bars')
for (i1, i2, r1, r2), bs in top_cells:
    print(f'  {i1:+d} {i2:+d}  rhythm {r1},{r2}  x{len(bs):<3} ' + ' '.join(str(b) for b in sorted(set(bs))))

repeats = Counter(h[0].split()[0] for h in same_as.values() if h)
print('\nbars that bring back earlier ones: ' +
      ', '.join(f'{v} {k}' for k, v in repeats.most_common()) + f' (of {len(order)})')
# runs: a stretch of bars bringing back a stretch of earlier ones, in order (skipping a bar or two)
runs, i = [], 0
while i < len(order):
    b, h = order[i], same_as[order[i]]
    if h and h[1] != b - 1:
        j, hows = i, Counter()
        last = h[1]   # the run goes on while each bar brings back one a little after the last one's
        while j < len(order) and same_as[order[j]] and (j == i or 0 < same_as[order[j]][1] - last <= 3):
            last = same_as[order[j]][1]; hows[same_as[order[j]][0].split()[0]] += 1; j += 1
        if j - i >= 3:
            runs.append((b, order[j - 1], h[1], last, hows.most_common(1)[0][0])); i = j; continue
    i += 1
for lo, hi, flo, fhi, how in runs:
    print(f'  {lo}-{hi} bring back {flo}-{fhi} (mostly: {how})')

if a.bars:
    print('\nbar  chord        key            back from                     tune  keys  bass  loud')
    for b in order:
        c = Counter(role(n['part']) for n in bars[b])
        h = same_as[b]
        print(f"{b:>3}  {(chord[b]['name'] if chord[b] else '-'):<12} {key_name(bar_key[b]):<14} "
              f"{(h[0] + ' ' + str(h[1]) if h else ''):<29} {c['tune']:>4}  {c['keys']:>4}  {c['bass']:>4}  {vel[order.index(b)]:>4}")

if a.json:
    total = {p: sum(m.values()) or 1 for p, m in motion.items()}
    summary = {'name': name, 'bars': len(order), 'meter': meter,
               'keys': [[r[0], r[1], key_name(r[2])] for r in regions],
               'chord_changes_per_8_bars': round(8 * sum(1 for p, q in zip(order, order[1:]) if chord[p] and chord[q]
                                                         and chord[p]['name'] != chord[q]['name']) / len(order), 2),
               'distinct_chords': len({chord[b]['name'] for b in order if chord[b]}),
               'step_motion': {p: round(motion[p]['step'] / total[p], 2) for p in motion},
               'hold': {p: round(motion[p]['hold'] / total[p], 2) for p in motion},
               'loudness_spread': round(statistics.pstdev(vel), 1),
               'lines_per_8_bars': round(8 * len(lines) / len(order), 2),
               'chromatic_lines': sum(l['chromatic'] for l in lines),
               'bars_brought_back': round(sum(1 for h in same_as.values() if h) / len(order), 2),
               'sections': {f'{lab} {lo}-{hi}': section_stats(lo, hi) for lab, lo, hi in sections}}
    json.dump(summary, open(a.json, 'w'), indent=1)
    print('\nsummary ->', a.json)
