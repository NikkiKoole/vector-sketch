# find-drum-sample: a drum loop's source, by mel-spectrogram cross-correlation across speeds (a sampler: faster
# is higher, so the piece is resampled). Speed x<1: the source is slower than the piece. Compare a control record
# (Electric Relaxation's drums: Outside Love 0.80, Mystic Brew 0.52).
# usage: python3 -I claudetools/find-drum-sample.py piece.wav p_start p_dur source.wav speed_lo speed_hi
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
import sys, numpy as np, librosa
from scipy.signal import fftconvolve
piece, ps, pd, source = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
sr, hop = 22050, 256
yp, _ = librosa.load(piece, sr=sr, offset=ps, duration=pd)
ys, _ = librosa.load(source, sr=sr)
fps = sr / hop
def mel(y): 
    M = librosa.power_to_db(librosa.feature.melspectrogram(y=y, sr=sr, hop_length=hop, n_mels=48, fmax=10000))
    M = np.maximum(M, M.max() - 50)
    return M - M.mean(axis=1, keepdims=True)
Ms = mel(ys)
res = []
for speed in np.arange(float(sys.argv[5]), float(sys.argv[6]), 0.005):
    yq = librosa.resample(yp, orig_sr=sr, target_sr=int(sr / speed))  # played faster: shorter AND higher
    Mp = mel(yq); n = Mp.shape[1]
    num = sum(fftconvolve(Ms[k], Mp[k][::-1], mode='valid') for k in range(48))
    e1 = np.sqrt(fftconvolve((Ms ** 2).sum(axis=0), np.ones(n), mode='valid'))
    v = num / (e1 * np.sqrt((Mp ** 2).sum()) + 1e-9)
    f = int(np.argmax(v)); res.append((v[f], speed, f / fps))
res.sort(reverse=True)
for sc, sp, t in res[:6]: print(f"score {sc:.3f}  at {t:6.2f}s  source played x{sp:.2f}  ({12*np.log2(sp):+.2f} st)")
