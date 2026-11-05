# find-sample: where in a source record does a sampled piece come from? Slides the piece's chroma (and onset curve)
# across the source at several speeds; a speed change shifts pitch too (a sampler/turntable), so the
# chroma is rolled by the semitones that speed implies, plus an extra roll for repitching.
# Finds WHERE and the PITCH well (rolls), the speed only roughly: measure it from loop lengths. Quiet stretches
# (fades, gaps) are skipped: normalized correlation loves near-silence. Scores: ~0.85 a sure match, ~0.5 noise.
# usage: python3 -I claudetools/find-sample.py piece.wav p_start p_dur source.wav   (librosa, scipy)
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
import sys
import numpy as np
import librosa

piece, ps, pd, source = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
sr, hop = 22050, 512
yp, _ = librosa.load(piece, sr=sr, offset=ps, duration=pd)
ys, _ = librosa.load(source, sr=sr)
fps = sr / hop
Cs = librosa.feature.chroma_cqt(y=ys, sr=sr, hop_length=hop)
Os = librosa.onset.onset_strength(y=ys, sr=sr, hop_length=hop)
rmsS = librosa.feature.rms(y=ys, frame_length=2048, hop_length=hop)[0]
loud = 20 * np.log10(rmsS + 1e-9)
winq = None
res = []
for speed in np.arange(0.80, 1.21, 0.01):
    # the piece played back at 1/speed of its time gives the source's time scale
    yq = librosa.effects.time_stretch(yp, rate=1 / speed)
    Cp = librosa.feature.chroma_cqt(y=yq, sr=sr, hop_length=hop)
    Op = librosa.onset.onset_strength(y=yq, sr=sr, hop_length=hop)
    n = Cp.shape[1]
    if n >= Cs.shape[1]: continue
    semis_from_speed = 12 * np.log2(speed)   # source faster -> piece lower; undo it
    from scipy.signal import fftconvolve
    win = np.ones(n)
    lm = fftconvolve(loud, win, mode='valid') / n
    quiet = lm < np.percentile(loud, 90) - 20
    Sz = (Cs - Cs.mean(axis=0, keepdims=True))
    Opz = (Op - Op.mean()) / (Op.std() + 1e-9)
    om = fftconvolve(Os, win, mode='valid') / n
    osq = fftconvolve(Os ** 2, win, mode='valid') / n
    ocorr = fftconvolve(Os, Opz[::-1], mode='valid') / n / np.sqrt(np.maximum(osq - om ** 2, 1e-12))
    for extra in (-1, 0, 1):
        roll = int(round(semis_from_speed)) + extra
        C = np.roll(Cp, roll, axis=0)
        C = C - C.mean(axis=0, keepdims=True)
        num = sum(fftconvolve(Sz[k], C[k][::-1], mode='valid') for k in range(12))
        e1 = np.sqrt(fftconvolve((Sz ** 2).sum(axis=0), win, mode='valid'))
        v = num / (e1 * np.sqrt((C ** 2).sum()) + 1e-9)
        sc = v + 0.5 * ocorr[:len(v)]
        sc[quiet[:len(sc)]] = -9  # never match a fade or a gap: normalized correlation loves near-silence
        f = int(np.argmax(sc))
        res.append((sc[f], speed, roll, f / fps))
res.sort(reverse=True)
for sc, speed, roll, t in res[:10]:
    print(f"score {sc:.3f}  at {t:6.2f}s in the source  speed x{speed:.2f} ({12*np.log2(speed):+.2f} st from speed)  chroma roll {roll:+d}")
