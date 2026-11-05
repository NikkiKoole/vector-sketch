# loop-fit: each pass of a riff fitted to its slots (own start and beat length per pass, least squares), then
# per slot: hit rate, timing against the player's own pulse, accent, length, octaves, decay, scoop, cents, tone;
# feel (per-slot mean) apart from jitter. Reads loop-fold's -notes.json; writes -fit.json (passes, rows).
# --slots file.json: [[beat, pitch class, core 0/1], ...] in the cycle (default: Mystic Brew's intro riff, F)
# --scan: every note on slot 0's pitch class tried as a pass start (a riff that comes and goes)
# usage: python3 -I claudetools/loop-fit.py notes.json first_start beat_s transpose [--fixed] [--scan]
#        [--from T] [--to T] [--slots file.json]
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
import sys, json
import numpy as np
from collections import Counter

NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
def nm(m): return f"{NAMES[m % 12]}{m // 12 - 1}"
# the riff in Mystic Brew's key: (beat position in the 12-beat cycle, pitch class, core?)
SLOTS = [(0.0, 8, 1), (0.5, 0, 1), (1.25, 0, 0), (2.0, 7, 1), (3.0, 5, 1),
         (4.0, 0, 0), (4.5, 10, 1), (6.0, 3, 1), (6.5, 7, 1), (7.0, 8, 1),
         (8.0, 3, 1), (8.25, 3, 0), (8.5, 6, 1), (9.25, 6, 0), (10.5, 0, 1), (11.0, 1, 1)]

args = sys.argv[1:]
if '--slots' in args:
    SLOTS = [tuple(x) for x in json.load(open(args[args.index('--slots') + 1]))]
fixed = '--fixed' in args
def opt(k, d):
    return float(args[args.index(k) + 1]) if k in args else d
t_from, t_to = opt('--from', 0), opt('--to', 1e9)
notes = [n for n in json.load(open(args[0])) if t_from <= n['t'] < t_to]
start0, bl0, tr = float(args[1]), float(args[2]), int(args[3])
T = np.array([n['t'] for n in notes])

def fit_pass(start, bl):
    for _ in range(4):
        match = {}
        for si, (pos, pc, core) in enumerate(SLOTS):
            want = start + pos * bl
            cand = [i for i in np.where(np.abs(T - want) < 0.3 * bl)[0] if (notes[i]['midi'] + tr) % 12 == pc]
            if cand:
                match[si] = min(cand, key=lambda i: abs(T[i] - want))
        core = [(SLOTS[si][0], T[i]) for si, i in match.items() if SLOTS[si][2]]
        if len(core) < 6:
            return None
        if fixed:
            break
        P = np.array(core)
        bl, start = np.polyfit(P[:, 0], P[:, 1], 1)
    return start, bl, match

passes = []
if '--scan' in args:
    # every note on slot 0's pitch class is a candidate pass start; keep the good ones, no overlaps
    cands = []
    for i, n in enumerate(notes):
        if (n['midi'] + tr) % 12 != SLOTS[0][1]: continue
        for bl in (bl0 * 0.94, bl0, bl0 * 1.06):
            r = fit_pass(n['t'] + 0.02, bl)
            if r:
                s, b, match = r
                ncore = sum(1 for si in match if SLOTS[si][2])
                if ncore >= 9 and 0.85 * bl0 < b < 1.15 * bl0:
                    cands.append((ncore, s, b, match)); break
    cands.sort(key=lambda c: -c[0])
    for c in cands:
        if all(abs(c[1] - p[0]) > 10 * c[2] for p in passes):
            passes.append((c[1], c[2], c[3]))
for direction in (() if '--scan' in args else (1, -1)):
    start, bl = start0, bl0
    if direction == -1:
        start -= 12 * bl
    while t_from - 1 < start < t_to:
        r = fit_pass(start, bl)
        if r is None:
            break
        s, b, match = r
        passes.append((s, b, match))
        start = s + direction * 12 * b
passes.sort(key=lambda p: p[0])
print(f"{len(passes)} passes from {passes[0][0]:.1f}s to {passes[-1][0] + 12 * passes[-1][1]:.1f}s")
print("tempo per pass:", ' '.join(f"{60 / b:.1f}" for _, b, _ in passes))

rows, extras = [], []
for pi, (s, b, match) in enumerate(passes):
    used = set(match.values())
    gains = [notes[i]['gain'] for i in match.values()]
    gmean = np.mean(gains)
    for si, i in match.items():
        n = notes[i]
        rows.append(dict(p=pi, si=si, off=(n['t'] - (s + SLOTS[si][0] * b)) * 1000, gain=n['gain'], grel=n['gain'] - gmean,
                         len=(n['end'] - n['t']) / b, gap=(n['nxt'] - n['end']) / b, midi=n['midi'] + tr, decay=n['decay'],
                         scoop=n['scoop'], cents=n['cents'], bright=n['bright'], close=n['close'], att=n['att']))
    for i in np.where((T >= s - 0.2 * b) & (T < s + 11.8 * b))[0]:
        if i not in used:
            n = notes[i]
            pos = (n['t'] - s) / b
            extras.append(dict(p=pi, pos=pos, midi=n['midi'] + tr, grel=n['gain'] - gmean, len=(n['end'] - n['t']) / b))

def st(v, f="{:+.0f}±{:.0f}"):
    v = np.array([x for x in v if x == x])
    return f.format(v.mean(), v.std()) if len(v) else '-'
N = len(passes)
print(f"\nslot  bar.beat  note | hit% | timing ms | accent dB | len beats | octaves | decay dB/s | scoop c | cents | bright Hz | closes oct/200ms")
for si, (pos, pc, core) in enumerate(SLOTS):
    rs = [r for r in rows if r['si'] == si]
    if not rs: continue
    bar, beat = int(pos // 4) + 1, pos % 4 + 1
    octs = Counter(nm(r['midi']) for r in rs)
    G = lambda k: [r[k] for r in rs]
    print(f"{'*' if core else ' '}{si:2d}  {bar}.{beat:<5.2f}  {NAMES[pc]:2s}  | {len(rs) / N * 100:3.0f}% | {st(G('off')):>8s} | {st(G('grel'), '{:+.1f}±{:.1f}'):>9s} | "
          f"{st(G('len'), '{:.2f}±{:.2f}'):>10s} | {' '.join(f'{k}:{v}' for k, v in octs.most_common(2)):12s} | {st(G('decay'), '{:.0f}±{:.0f}'):>7s} | "
          f"{st(G('scoop')):>6s} | {st(G('cents')):>6s} | {np.nanmean(G('bright')):4.0f} | {np.nanmean(G('close')):+.2f}")

# timing: systematic (slot mean) vs random (within slot)
offs = {si: np.array([r['off'] for r in rows if r['si'] == si]) for si in range(len(SLOTS))}
means = np.array([v.mean() for v in offs.values() if len(v) > 2])
resid = np.concatenate([v - v.mean() for v in offs.values() if len(v) > 2])
print(f"\ntiming: per-slot feel spread {means.std():.0f} ms (range {means.min():+.0f}..{means.max():+.0f}); random jitter sd {resid.std():.0f} ms "
      f"(|jitter| median {np.median(np.abs(resid)):.0f} ms, 90% {np.percentile(np.abs(resid), 90):.0f} ms)")
gr = np.concatenate([np.array([r['grel'] for r in rows if r['si'] == si]) - np.mean([r['grel'] for r in rows if r['si'] == si])
                     for si in range(len(SLOTS)) if sum(1 for r in rows if r['si'] == si) > 2])
print(f"loudness: per-note random sd {gr.std():.1f} dB; per-pass loudness range "
      f"{min(np.mean([r['gain'] for r in rows if r['p'] == p]) for p in range(N)):.1f}..{max(np.mean([r['gain'] for r in rows if r['p'] == p]) for p in range(N)):.1f} dB")
# the pickups (8th before a long note) vs the long notes: swing of the pairs
print(f"\nextras (notes off the riff): {len(extras)} over {N} passes ({len(extras) / N:.1f} a pass)")
ex = Counter((round(e['pos'] * 4) / 4, NAMES[e['midi'] % 12]) for e in extras)
for (pos, n), c in ex.most_common(14):
    es = [e for e in extras if round(e['pos'] * 4) / 4 == pos and NAMES[e['midi'] % 12] == n]
    print(f"   {int(pos // 4) + 1}.{pos % 4 + 1:<5.2f} {n:2s} x{c:2d}  accent {np.mean([e['grel'] for e in es]):+.1f} dB  len {np.mean([e['len'] for e in es]):.2f}")
json.dump(dict(rows=rows, extras=extras, passes=[(s, b) for s, b, _ in passes]), open(args[0].replace('-notes.json', '-fit.json'), 'w'), default=float)
