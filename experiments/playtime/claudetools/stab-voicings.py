# stab-voicings: a chord part's onsets, each one's notes from a fine CQT (3 bins a semitone, tuning-corrected,
# octaves/12ths of a louder note dropped), placed on a riff grid, with the bass note under it. One stab is noisy
# (drawbar partials, bleed): slot-chroma pools passes. The grid: loop-fit's -fit.json, or any
# {"passes": [[start_s, beat_s], ...]}; the bass: loop-fold's -notes.json.
# usage: python3 -I claudetools/stab-voicings.py stem.wav fit.json notes.json [t_from t_to] [--min-db -14]
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
import sys, json
import numpy as np
import librosa

args = sys.argv[1:]
mindb = float(args[args.index('--min-db') + 1]) if '--min-db' in args else -14
stem, fitp, bassp = args[0], args[1], args[2]
t_from = float(args[3]) if len(args) > 3 and not args[3].startswith('--') else 0
t_to = float(args[4]) if len(args) > 4 and not args[4].startswith('--') else 1e9
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
def nm(m): return f"{NAMES[m % 12]}{m // 12 - 1}"

sr, hop = 22050, 128
y, _ = librosa.load(stem, sr=sr, offset=t_from, duration=None if t_to > 1e8 else t_to - t_from)
fps = sr / hop
fmin = librosa.note_to_hz('C2')
C = np.abs(librosa.cqt(y, sr=sr, hop_length=hop, fmin=fmin, n_bins=36 * 6, bins_per_octave=36, filter_scale=2))
Cdb = librosa.amplitude_to_db(C, ref=np.max)
tun = librosa.estimate_tuning(y=y, sr=sr)
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
on = librosa.onset.onset_detect(onset_envelope=env, sr=sr, hop_length=hop, backtrack=False, delta=0.1, wait=int(0.08 * fps))
fit = json.load(open(fitp)); passes = fit['passes']
bass = json.load(open(bassp))

def gridpos(t):
    for s, b in passes:
        if s - 0.3 * b <= t < s + 11.7 * b:
            pos = (t - s) / b; g = round(pos * 4) / 4
            return f"{int(g // 4) + 1}.{g % 4 + 1:<4.2f}", (pos - g) * b * 1000
    return None, None

print(f"tuning {tun * 100:+.0f} c; stabs with notes within {-mindb:.0f} dB of the stab's loudest")
print("   time   riff pos  off ms | lvl dB | ring ms | notes (low to high)                | bass under")
for f in on:
    a = f + int(0.025 * fps); b = f + int(0.09 * fps)
    if b >= C.shape[1]: continue
    spec = Cdb[:, a:b].mean(axis=1)
    lvl = spec.max()
    if lvl < -35: continue
    # one value per semitone: the bin nearest its tuned centre, a local peak in the fine spectrum
    notes = []
    for k in range(1, 36 * 6 - 1):
        if spec[k] >= spec[k - 1] and spec[k] >= spec[k + 1] and spec[k] > lvl + mindb:
            semis = k / 3 - tun
            if abs(semis - round(semis)) < 0.34:
                notes.append((int(round(semis)) + 36, spec[k]))
    # drop overtones: a note an octave or a 12th (19) above a much louder one
    keep = []
    for m, v in notes:
        if any(m - m2 in (12, 19, 24) and v2 - v > 6 for m2, v2 in notes): continue
        keep.append((m, v))
    if not keep: continue
    # ring: frames until the stab's top bins fall 20 dB
    rows = [int((m - 36 + tun) * 3) for m, _ in keep]
    e = Cdb[rows, f:f + int(1.0 * fps)].max(axis=0)
    below = np.where(e < e[:int(0.05 * fps)].max() - 20)[0]
    ring = (below[0] / fps * 1000) if len(below) else 1000
    t = f / fps + t_from
    pos, off = gridpos(t)
    under = [n for n in bass if n['t'] <= t + 0.03 and n['end'] > t]
    bn = nm(under[-1]['midi']) if under else '-'
    print(f"{t:7.2f}  {pos or '':9s} {off if off is not None else 0:+5.0f} | {lvl:6.1f} | {ring:6.0f}  | {' '.join(nm(m) for m, _ in keep):34s} | {bn}")
