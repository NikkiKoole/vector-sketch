# Cut one stem into note events, group them (jab/ring, note/dyad/chord, low/mid/high), write an example wav per group.
# usage: python3 -I claudetools/stem-pieces.py <stem.wav> <out dir>   (see docs/MUSIC-ANALYSIS.md)
import sys, os, numpy as np, librosa, soundfile as sf
p, outdir = sys.argv[1], sys.argv[2]; SR = 44100; hop = 512
os.makedirs(outdir, exist_ok=True)
y, _ = librosa.load(p, sr=SR, mono=True)
tun = librosa.estimate_tuning(y=y, sr=SR)
rms = librosa.feature.rms(y=y, hop_length=hop)[0]; peak = rms.max()
env = librosa.onset.onset_strength(y=y, sr=SR, hop_length=hop)
on = librosa.onset.onset_detect(onset_envelope=env, sr=SR, hop_length=hop, backtrack=True)
C = np.abs(librosa.cqt(y, sr=SR, hop_length=hop, fmin=librosa.note_to_hz('C2'), n_bins=60, tuning=tun))
cent = librosa.feature.spectral_centroid(y=y, sr=SR, hop_length=hop)[0]
N = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
ev = []
for i, f in enumerate(on):
    g = on[i+1] if i + 1 < len(on) else len(rms) - 1
    r = rms[f:g]
    if len(r) < 2 or r.max() < .15 * peak: continue
    k = int(np.argmax(r)); below = np.where(r[k:] < .3 * r[k])[0]
    ring = (below[0] if len(below) else len(r) - k) * hop / SR
    gap = (g - f) * hop / SR
    seg = C[:, f+k:f+k+4].mean(axis=1)
    notes = [j for j in np.argsort(seg)[::-1][:4] if seg[j] > .45 * seg.max()]
    ev.append(dict(t=f*hop/SR, ring=ring, gap=gap, lvl=r.max()/peak, cent=float(np.median(cent[f+k:f+k+4])),
                   notes=sorted(notes), n=len(notes)))
def kind(e):
    short = e['ring'] < .15
    size = 'chord' if e['n'] >= 3 else 'dyad' if e['n'] == 2 else 'note'
    reg = 'high' if np.mean(e['notes']) > 30 else 'mid' if np.mean(e['notes']) > 15 else 'low'
    return f"{'jab' if short else 'ring'}-{size}-{reg}"
from collections import defaultdict
groups = defaultdict(list)
for e in ev: groups[kind(e)].append(e)
name = os.path.basename(p)[:-4]
print(f"{name}: {len(ev)} events")
for k, es in sorted(groups.items(), key=lambda kv: -len(kv[1])):
    rg = np.median([e['ring'] for e in es]); ce = np.median([e['cent'] for e in es])
    when = [e['t'] for e in es]
    # most common pitch sets
    from collections import Counter
    sets = Counter(' '.join(N[j % 12] + str(j // 12 + 2) for j in e['notes']) for e in es).most_common(3)
    print(f"  {k:18s} x{len(es):3d}  ring {1000*rg:4.0f} ms  centroid {ce:5.0f} Hz  span {min(when)/60:.0f}:{min(when)%60:02.0f}-{int(max(when)//60)}:{max(when)%60:02.0f}   e.g. {sets}")
    # example: the loudest, cleanest (longest gap) event
    best = max(es, key=lambda e: e['lvl'] * min(e['gap'], 1.0))
    a = int(best['t'] * SR); b = a + int(min(max(best['gap'], .4), 2.5) * SR)
    sf.write(os.path.join(outdir, f"{name}-{k}-{int(best['t']//60)}m{best['t']%60:04.1f}.wav"), y[a:b], SR)
