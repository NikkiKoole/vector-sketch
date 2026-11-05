# loop-fold: a looping bass part's notes (pyin + onsets) folded onto one cycle, per-slot spread. Writes, in the
# current folder, <stem's folder>-notes.json (every note: what loop-fit and stab-voicings read) and -fold.csv.
# usage: python3 -I claudetools/loop-fold.py bass.wav start end cycle_s beats_per_cycle anchor_s [--fixed]
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
#   anchor_s: a time where the cycle starts (its first note). --fixed: rigid loop (a sampler), one
#   straight grid; otherwise each pass is found by cross-correlation and gets its own local tempo.
import sys
import numpy as np
import librosa

path = sys.argv[1]
t_start, t_end, cyc, nbeats, anchor = map(float, sys.argv[2:7])
fixed = '--fixed' in sys.argv
sr, hop = 22050, 64
fps = sr / hop
y, _ = librosa.load(path, sr=sr, mono=True, offset=t_start, duration=t_end - t_start)
times = librosa.frames_to_time(np.arange(1 + len(y) // hop), sr=sr, hop_length=hop) + t_start

# --- pass starts
C = np.abs(librosa.cqt(y, sr=sr, hop_length=hop, fmin=librosa.note_to_hz('E1'), n_bins=36))
C = np.maximum(librosa.amplitude_to_db(C, ref=np.max), -40) + 40
def fr(t): return int(round((t - t_start) * fps))
L = int(cyc * fps)
tpl = C[:, fr(anchor):fr(anchor) + L]
starts = [anchor]
# walk forward and back
for direction in (1, -1):
    t = anchor
    while True:
        guess = t + direction * cyc
        if guess < t_start or guess + cyc > t_end:
            break
        if fixed:
            best = guess
        else:
            best, bv = guess, -1
            for d in np.arange(-0.6, 0.6, 1 / fps * 2):
                f = fr(guess + d)
                if f < 0 or f + L > C.shape[1]:
                    continue
                seg = C[:, f:f + L]
                v = np.sum((seg - seg.mean()) * (tpl - tpl.mean())) / (np.linalg.norm(seg - seg.mean()) * np.linalg.norm(tpl - tpl.mean()) + 1e-9)
                if v > bv:
                    bv, best = v, guess + d
            if bv < 0.35:
                print(f"  (pass at {guess:.2f} doesn't match: corr {bv:.2f}, stop)")
                break
        starts.append(best)
        t = best
starts = sorted(set(round(s, 4) for s in starts))
print(f"{len(starts)} passes, lengths (s):", ' '.join(f"{b - a:.2f}" for a, b in zip(starts[:-1], starts[1:])))

# --- notes
f0, voiced, prob = librosa.pyin(y, fmin=librosa.note_to_hz('A0'), fmax=librosa.note_to_hz('E4'), sr=sr, hop_length=hop, frame_length=4096)
midi = librosa.hz_to_midi(f0); good = voiced & (prob > 0.25)
tuning = float(np.median(midi[good] - np.round(midi[good])))
rms = librosa.feature.rms(y=y, frame_length=1024, hop_length=hop)[0]
rdb = 20 * np.log10(rms + 1e-9)
cent = librosa.feature.spectral_centroid(y=y, sr=sr, n_fft=2048, hop_length=hop)[0]
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
on = librosa.onset.onset_detect(onset_envelope=env, sr=sr, hop_length=hop, backtrack=True, delta=0.08, wait=int(0.07 * fps))
peak_all = np.percentile(rms, 99.5)
notes = []
bounds = list(on) + [len(rms) - 1]
for a, b in zip(bounds[:-1], bounds[1:]):
    if b - a < 4: continue
    pk_i = a + int(np.argmax(rms[a:min(b, a + int(0.12 * fps))]))
    g_db = 20 * np.log10(rms[pk_i] / peak_all + 1e-9)
    after = np.where(rdb[pk_i:b] < rdb[pk_i] - 20)[0]
    end = pk_i + after[0] if len(after) else b
    m = midi[a:end]; g = good[a:end]
    if g.sum() < 4: continue
    mg = m[g]
    sm = np.median(mg[len(mg) // 5: max(len(mg) // 5 + 1, 4 * len(mg) // 5)])
    n = int(np.round(sm - tuning))
    c = (m - tuning - n) * 100
    k = int(0.03 * fps)
    first = c[:k][g[:k]]
    scoop = float(np.median(first) - (sm - tuning - n) * 100) if len(first) else 0.0
    dseg = np.arange(pk_i, min(end, pk_i + int(0.4 * fps)))
    decay = np.polyfit(dseg / fps, rdb[dseg], 1)[0] if len(dseg) > 5 else np.nan
    ca = np.median(cent[a:a + int(0.04 * fps)])
    i2 = a + int(0.2 * fps)
    cl = np.median(cent[i2:i2 + int(0.05 * fps)]) if end > i2 + 3 else np.nan
    notes.append(dict(t=times[a], end=times[end], midi=n, gain=g_db, att=(pk_i - a) / fps * 1000, decay=decay,
                      scoop=scoop, cents=(sm - tuning - n) * 100, bright=ca, close=np.log2(cl / ca) if cl == cl else np.nan,
                      nxt=times[b]))

# --- dump notes
import json
json.dump([{k: (float(v) if isinstance(v, (float, np.floating)) else int(v)) for k, v in n.items()} for n in notes],
          open(path.rsplit('/', 2)[-2].replace(' ', '_') + '-notes.json', 'w'))
# --- fold
rows = []
for i, s in enumerate(starts):
    e = starts[i + 1] if i + 1 < len(starts) else s + cyc
    bl = (e - s) / nbeats
    for n in notes:
        if s - bl * 0.3 <= n['t'] < e - bl * 0.3:
            pos = (n['t'] - s) / bl
            g16 = round(pos * 4) / 4
            rows.append(dict(pass_=i, pos=pos, g16=g16, off_ms=(pos - g16) * bl * 1000, bl=bl,
                             len_b=(n['end'] - n['t']) / bl, gap_b=(n['nxt'] - n['end']) / bl, **n))

# slot = (16th, pitch); keep slots present in >= 40% of passes
from collections import defaultdict
slots = defaultdict(list)
for r in rows:
    slots[(r['g16'], r['midi'])].append(r)
npass = len(starts)
print(f"\ntuning {tuning * 100:+.0f} c   beat {np.mean([r['bl'] for r in rows]) * 1000:.0f} ms   passes {npass}")
print("slot: bar.beat  note  in%  | timing ms mean±sd | gain dB mean±sd | len beats mean±sd  gap | decay dB/s | scoop c | cents | bright Hz, closes oct")
for (g16, m), rs in sorted(slots.items()):
    share = len(set(r['pass_'] for r in rs)) / npass
    if share < 0.25: continue
    bar = int(g16 // 4) + 1; beat = g16 - (bar - 1) * 4 + 1
    A = lambda k: np.array([r[k] for r in rs], dtype=float)
    def ms(k, f="{:+.0f}±{:.0f}"):
        v = A(k); v = v[~np.isnan(v)]
        return f.format(np.mean(v), np.std(v)) if len(v) else '-'
    print(f"  {bar}.{beat:<5.2f} {librosa.midi_to_note(m, unicode=False):4s} {share * 100:3.0f}%  | {ms('off_ms'):>8s} | {ms('gain', '{:.1f}±{:.1f}'):>9s} | "
          f"{ms('len_b', '{:.2f}±{:.2f}'):>10s} {np.nanmean(A('gap_b')):.2f} | {ms('decay', '{:.0f}±{:.0f}'):>8s} | {ms('scoop'):>6s} | {ms('cents'):>6s} | "
          f"{np.nanmean(A('bright')):4.0f}, {np.nanmean(A('close')):+.2f}")
# pass-level: tempo drift, overall timing
bls = np.array([r['bl'] for r in rows])
print(f"\nbeat length per pass: {np.mean(bls) * 1000:.0f} ms, passes vary sd {np.std([ (b - a) / nbeats * 1000 for a, b in zip(starts[:-1], starts[1:])]) if len(starts) > 2 else 0:.1f} ms/beat")
import csv
with open(path.rsplit('/', 2)[-2].replace(' ', '_') + '-fold.csv', 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
