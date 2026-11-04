# Syllable morphing (docs/CHOIR.md): two Mipo voice takes analysed with the WORLD vocoder (pitch, spectral
# envelope = the throat, aperiodicity), frames lined up with DTW, blended; a morph over time and fixed blends.
# Needs pyworld: python3 -m venv --system-site-packages /tmp/venv && /tmp/venv/bin/pip install pyworld
# usage: /tmp/venv/bin/python -I claudetools/voice-morph.py assets/voices <out dir> name:theo/mi:herman/mi [...]
import sys, os, numpy as np, librosa, pyworld as pw, soundfile as sf

VOICES, OUT = sys.argv[1], sys.argv[2]
FS = 44100
FP = 5.0  # ms per frame
ORDER = ['A', 'B', 'A through WORLD (no change)', 'crossfade A->B', 'WORLD morph A->B over time',
         'WORLD blends 0 / 25 / 50 / 75 / 100 %']

def load(name):
    y, _ = librosa.load(f"{VOICES}/{name}.ogg", sr=FS, mono=True)
    y = y.astype(np.float64)
    return y / (np.abs(y).max() + 1e-9) * 0.5

def analyse(y):
    f0, t = pw.harvest(y, FS, f0_floor=70, f0_ceil=900, frame_period=FP)
    sp = pw.cheaptrick(y, f0, t, FS)
    ap = pw.d4c(y, f0, t, FS)
    return f0, sp, ap

def synth(f0, sp, ap):
    y = pw.synthesize(np.ascontiguousarray(f0), np.ascontiguousarray(sp), np.ascontiguousarray(ap), FS, FP)
    return y / (np.abs(y).max() + 1e-9) * 0.5

def align(a, b):
    # DTW on a coded (mel-cepstrum-like) envelope: frames that sound alike get paired
    ca = pw.code_spectral_envelope(a[1], FS, 24).T
    cb = pw.code_spectral_envelope(b[1], FS, 24).T
    _, wp = librosa.sequence.dtw(ca, cb, metric='euclidean')
    return wp[::-1]  # pairs (i in A, j in B), start to end

def blend(a, b, path, weights, frames):
    # pick `frames` points evenly along the path; weights[k] = how much B at output frame k
    idx = np.linspace(0, len(path) - 1, frames).round().astype(int)
    f0s, sps, aps = [], [], []
    for k, p in enumerate(idx):
        i, j = path[p]; w = weights[k]
        fa, fb = a[0][i], b[0][j]
        voiced = (1 - w) * (fa > 0) + w * (fb > 0)
        if voiced < 0.5: f0 = 0.0
        elif fa > 0 and fb > 0: f0 = np.exp((1 - w) * np.log(fa) + w * np.log(fb))
        else: f0 = fa if fa > 0 else fb
        sp = np.exp((1 - w) * np.log(a[1][i] + 1e-12) + w * np.log(b[1][j] + 1e-12))
        ap = (1 - w) * a[2][i] + w * b[2][j]
        f0s.append(f0); sps.append(sp); aps.append(ap)
    return synth(np.array(f0s), np.array(sps), np.array(aps))

def crossfade(ya, yb):
    n = max(len(ya), len(yb))
    ya = np.pad(ya, (0, n - len(ya))); yb = np.pad(yb, (0, n - len(yb)))
    t = np.linspace(0, 1, n)
    return np.cos(t * np.pi / 2) * ya + np.sin(t * np.pi / 2) * yb

def render(pair_name, na, nb):
    ya, yb = load(na), load(nb)
    a, b = analyse(ya), analyse(yb)
    path = align(a, b)
    n, m = len(a[0]), len(b[0])
    gap = np.zeros(int(FS * 0.45)); small = np.zeros(int(FS * 0.2))
    T = (n + m) // 2
    s = 1 / (1 + np.exp(-10 * (np.linspace(0, 1, T) - 0.5)))  # an S-curve: mostly A, the turn, mostly B
    parts = [ya, gap, yb, gap, synth(*a), gap, crossfade(ya, yb), gap, blend(a, b, path, s, T), gap]
    for w in (0, 0.25, 0.5, 0.75, 1):
        frames = int(round((1 - w) * n + w * m))
        parts += [blend(a, b, path, np.full(frames, w), frames), small]
    # each part also on its own, named for what it is
    d = f"{OUT}/{pair_name}"; os.makedirs(d, exist_ok=True)
    named = [('1-original-' + na.replace('/', '-'), ya), ('2-original-' + nb.replace('/', '-'), yb),
             ('3-A-through-world-unchanged', synth(*a)), ('4-crossfade-A-to-B', crossfade(ya, yb)),
             ('5-world-morph-A-to-B', blend(a, b, path, s, T))]
    for k, w in enumerate((0, 0.25, 0.5, 0.75, 1)):
        frames = int(round((1 - w) * n + w * m))
        named.append((f"{6 + k}-world-blend-{int(w * 100)}pct-B", blend(a, b, path, np.full(frames, w), frames)))
    for fname, y in named: sf.write(f"{d}/{fname}.wav", y, FS)
    out = f"{OUT}/{pair_name}.wav"
    sf.write(out, np.concatenate(parts), FS)
    v = lambda f: f"{np.median(f[f > 0]):.0f} Hz" if (f > 0).any() else "unvoiced"
    print(f"{pair_name}: A {v(a[0])}, B {v(b[0])}, {n} vs {m} frames -> {out}")

for spec in sys.argv[3:]:
    name, a, b = spec.split(':')
    render(name, a, b)
print("order in each file:", ' | '.join(ORDER))
