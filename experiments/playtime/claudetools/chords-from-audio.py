# Chords from a recording: tempo, key, swing and a chord per half bar (beat-synced chroma + a bass
# chroma, matched to chord shapes). For learning a style's harmony and feel, not its tune.
# usage: python3 -I claudetools/chords-from-audio.py song.mp3   (needs librosa; ffmpeg for mp3)
import sys, numpy as np, librosa
path = sys.argv[1]
y, sr = librosa.load(path, sr=22050, mono=True)
yh, yp = librosa.effects.hpss(y)
tempo, beats = librosa.beat.beat_track(y=yp, sr=sr, trim=False)
tempo = float(np.atleast_1d(tempo)[0])
bt = librosa.frames_to_time(beats, sr=sr)
print(f"duration {len(y)/sr:.1f}s  tempo {tempo:.1f} bpm  beats {len(beats)}")
hop = 512
chroma = librosa.feature.chroma_cqt(y=yh, sr=sr, hop_length=hop, fmin=librosa.note_to_hz('C3'), n_octaves=4)
C = np.abs(librosa.cqt(yh, sr=sr, hop_length=hop, fmin=librosa.note_to_hz('C1'), n_bins=36, bins_per_octave=12))
bass = np.zeros((12, C.shape[1]))
for i in range(36): bass[i % 12] += C[i]
cs = librosa.util.sync(chroma, beats, aggregate=np.median)
bs = librosa.util.sync(bass, beats, aggregate=np.median)
NAMES = ['C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B']
Q = {'':[0,4,7],'m':[0,3,7],'7':[0,4,7,10],'maj7':[0,4,7,11],'m7':[0,3,7,10],'6':[0,4,7,9],'m7b5':[0,3,6,10],'dim7':[0,3,6,9],'sus':[0,5,7]}
temps = []
for r in range(12):
    for q, iv in Q.items():
        v = np.zeros(12); v[[(r+i)%12 for i in iv]] = 1
        temps.append((r, q, v / np.linalg.norm(v)))
def label(c, b):
    c = c / (np.linalg.norm(c) + 1e-9); bn = b / (b.max() + 1e-9)
    best = max(temps, key=lambda t: float(c @ t[2]) + 0.25 * bn[t[0]] - (0.02 if len(Q[t[1]]) == 4 else 0))
    return best[0], best[1], int(np.argmax(b))
labels = [label(cs[:, i], bs[:, i]) for i in range(cs.shape[1])]
# key (Krumhansl)
maj = np.array([6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]); mnr = np.array([6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17])
tot = chroma.sum(axis=1)
scores = [(np.corrcoef(tot, np.roll(maj, k))[0,1], NAMES[k]+' major') for k in range(12)] + [(np.corrcoef(tot, np.roll(mnr, k))[0,1], NAMES[k]+' minor') for k in range(12)]
print("key:", sorted(scores, reverse=True)[:3])
# swing: where the off-beat onset falls between two beats
on = librosa.onset.onset_strength(y=yp, sr=sr, hop_length=hop)
ratios = []
for a, b in zip(beats[:-1], beats[1:]):
    seg = on[a + (b - a) // 4: b - (b - a) // 8]
    if len(seg) > 2 and seg.max() > np.median(on) * 1.5:
        ratios.append(((a + (b - a) // 4 + np.argmax(seg)) - a) / (b - a))
if ratios: print(f"off-beat position (0.5 straight, 0.67 triplet swing): median {np.median(ratios):.2f}  n={len(ratios)}")
# downbeat: the phase where chord changes most often land
changes = [i for i in range(1, len(labels)) if labels[i][:2] != labels[i-1][:2]]
phase = max(range(4), key=lambda p: sum(1 for i in changes if i % 4 == p))
print("downbeat phase", phase)
bars = []
for start in range(phase, len(labels) - 3, 4):
    ch = labels[start:start+4]
    t = bt[start]
    first = f"{NAMES[ch[0][0]]}{ch[0][1]}"; third = f"{NAMES[ch[2][0]]}{ch[2][1]}"
    bassn = '/'.join(NAMES[x[2]] for x in ch)
    bars.append((t, first, third, bassn))
for i, (t, a, c, bn) in enumerate(bars):
    print(f"{i+1:3d} {int(t//60)}:{t%60:05.2f}  {a:7s} {c if c != a else '':7s}  bass {bn}")
