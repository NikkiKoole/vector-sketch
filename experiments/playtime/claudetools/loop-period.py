# loop-period: how long a part's loop is: the lags where its CQT matches itself best (a sampler loop scores
# ~0.8, a live player repeating ~0.6).
# usage: python3 -I claudetools/loop-period.py stem.wav start_s dur_s   (librosa)
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
import sys, numpy as np, librosa
path, a, d = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
y, sr = librosa.load(path, sr=11025, offset=a, duration=d)
hop=64
C = np.abs(librosa.cqt(y, sr=sr, hop_length=hop, fmin=librosa.note_to_hz('E1'), n_bins=36, bins_per_octave=12))
C = librosa.amplitude_to_db(C, ref=np.max); C = np.maximum(C, -40)+40
fps = sr/hop
X = C - C.mean(axis=1, keepdims=True)
best=[]
for lag_s in np.arange(1.0, 12.0, 0.01):
    L = int(lag_s*fps)
    v = np.sum(X[:, :-L]*X[:, L:]) / (np.linalg.norm(X[:, :-L])*np.linalg.norm(X[:, L:]))
    best.append((v, lag_s))
best.sort(reverse=True)
seen=[]
for v,l in best:
    if all(abs(l-s)>0.3 for s in seen):
        seen.append(l); print(f"lag {l:5.2f}s  corr {v:.3f}")
    if len(seen)>=8: break
