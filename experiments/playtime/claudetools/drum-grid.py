# drum-grid: a drum stem as kick (30-120 Hz) / snare (180-1200) / hat (6-11 kHz) hits on the 16th grid, folded
# over bars: per hit the share of bars, timing against the drummer's own pulse (or a sampler's straight grid,
# --fixed anchor_s), level. The bands leak: --min -12 keeps hits within 12 dB of each drum's loud level; a hit in
# both kick and snare bands is a kick. Check the bar's phase (snare on 2 and 4) before trusting beat 1.
# usage: python3 -I claudetools/drum-grid.py drums.wav start end bpm [--fixed anchor_s] [--bars N] [--min dB]
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
import sys
import numpy as np
import librosa
from collections import defaultdict

args = sys.argv[1:]
path, t0, t1, bpm = args[0], float(args[1]), float(args[2]), float(args[3])
fixed = float(args[args.index('--fixed') + 1]) if '--fixed' in args else None
plen = int(args[args.index('--bars') + 1]) if '--bars' in args else 1
minlvl = float(args[args.index('--min') + 1]) if '--min' in args else -99
sr, hop = 22050, 64
fps = sr / hop
y, _ = librosa.load(path, sr=sr, offset=t0, duration=t1 - t0)
S = np.abs(librosa.stft(y, n_fft=1024, hop_length=hop))
freqs = librosa.fft_frequencies(sr=sr, n_fft=1024)
BANDS = {'kick': (30, 120), 'snare': (180, 1200), 'hat': (6000, 11000)}
env = {}
for k, (lo, hi) in BANDS.items():
    e = librosa.amplitude_to_db(S[(freqs >= lo) & (freqs < hi)].sum(axis=0), ref=1.0)
    env[k] = e
def onsets(k):
    e = env[k]
    flux = np.maximum(0, np.diff(e, prepend=e[0]))
    flux = np.convolve(flux, np.ones(3) / 3, mode='same')
    pk = librosa.util.peak_pick(flux.astype(np.float64), pre_max=8, post_max=8, pre_avg=40, post_avg=10, delta=float(np.percentile(flux, 97) * 0.5), wait=int(0.06 * fps))
    out = []
    for p in pk:
        lvl = e[p:p + int(0.03 * fps)].max()
        out.append((p / fps + t0, lvl))
    return out
hits = {k: onsets(k) for k in BANDS}

# the grid: a sampler loop is straight (fixed); a live drummer gets a local pulse from the beat tracker
beat = 60 / bpm
if fixed is not None:
    nb = int((t1 - fixed) / beat) + 1
    beats = fixed + np.arange(nb) * beat
else:
    oe = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
    _, bf = librosa.beat.beat_track(onset_envelope=oe, sr=sr, hop_length=hop, bpm=bpm, tightness=300)
    beats = librosa.frames_to_time(bf, sr=sr, hop_length=hop) + t0
    # smooth the pulse a little (a tracker's beats jitter; the drummer's tempo moves slowly)
    k = np.arange(len(beats))
    sm = np.array([np.polyval(np.polyfit(k[max(0, i - 4):i + 5], beats[max(0, i - 4):i + 5], 1), i) for i in k])
    beats = sm
    # beat 1: the beat (mod 4) where the kick is strongest
    kick_on = np.zeros(4)
    for t, l in hits['kick']:
        i = np.argmin(np.abs(beats - t))
        if abs(beats[i] - t) < 0.08: kick_on[i % 4] += 10 ** (l / 20)
    first = int(np.argmax(kick_on))
    beats = beats[first:]
print(f"{path.split('/')[-2]}: {len(beats)} beats, tempo {60 / np.median(np.diff(beats)):.1f} bpm (from {np.min(60 / np.diff(beats)):.1f} to {np.max(60 / np.diff(beats)):.1f})")

nbars_pat = plen
rows = defaultdict(list)
peaks = {k: np.percentile([l for _, l in hits[k]], 95) for k in hits}
for k in hits:
    for t, l in hits[k]:
        if l - peaks[k] < minlvl: continue
        i = np.searchsorted(beats, t) - 1
        if i < 0 or i + 1 >= len(beats): continue
        bl = beats[i + 1] - beats[i]
        frac = (t - beats[i]) / bl
        s16 = int(round(frac * 4))
        off = (frac - s16 / 4) * bl * 1000
        b = i + s16 // 4; s16 %= 4
        bar = b // 4
        slot = (bar % nbars_pat) * 16 + (b % 4) * 4 + s16
        rows[(k, slot)].append((bar, off, l - peaks[k]))
nbars = (len(beats) - 1) // 4
print(f"{nbars} bars, pattern of {nbars_pat} bar(s)\n")
for k in BANDS:
    line = ''
    for slot in range(16 * nbars_pat):
        r = rows.get((k, slot), [])
        share = len(set(x[0] for x in r)) / max(1, nbars / nbars_pat)
        line += '#' if share > 0.7 else '+' if share > 0.4 else '.' if share > 0.15 else ' '
        if slot % 16 == 15 and slot < 16 * nbars_pat - 1: line += '|'
    print(f"  {k:5s} |{line}|   (# >70% of bars, + >40%, . >15%)")
print("        |1   2   3   4   |")
print("\nhit         share | timing ms (vs own pulse) | level dB (vs loud) ")
allres = defaultdict(list)
for (k, slot), r in sorted(rows.items(), key=lambda x: (list(BANDS).index(x[0][0]), x[0][1])):
    share = len(set(x[0] for x in r)) / max(1, nbars / nbars_pat)
    if share < 0.25: continue
    offs = np.array([x[1] for x in r]); lv = np.array([x[2] for x in r])
    bar, beat_in = slot // 16, slot % 16
    pos = f"{bar + 1}.{beat_in // 4 + 1}" + ['', 'e', '&', 'a'][beat_in % 4]
    allres[k].append(offs - offs.mean())
    print(f"  {k:5s} {pos:6s} {share * 100:3.0f}% | {offs.mean():+5.0f} ± {offs.std():3.0f} | {lv.mean():+5.1f} ± {lv.std():.1f}")
for k, v in allres.items():
    v = np.concatenate(v)
    print(f"  {k}: random timing sd {v.std():.0f} ms (90% within {np.percentile(np.abs(v), 90):.0f})")
