# The choir re-tuned with the WORLD vocoder (docs/CHOIR.md): the scene's real score (claudetools/choir-score-dump.lua)
# rendered by resampling (the game's way: pitch and length together) or by WORLD (pitch moved, throat and length kept,
# the singer model's scoop and vibrato drawn into the pitch curve from the vowel on). Needs pyworld (see voice-morph.py).
# usage: luajit claudetools/choir-score-dump.lua 1 round 1 singer 1 > fj.events
#        /tmp/venv/bin/python -I claudetools/choir-world-render.py assets/voices fj.events fj.wav world|resample
import sys, numpy as np, librosa, pyworld as pw, soundfile as sf
VOICES, EVF, OUT, HOW = sys.argv[1:5]
FS, FP = 44100, 5.0
ev = [l.split() for l in open(EVF)]
cache = {}
def take(key):
    if key not in cache:
        y, _ = librosa.load(f"{VOICES}/{key}.ogg", sr=FS, mono=True)
        y = y.astype(np.float64)
        an = None
        if HOW == 'world':
            f0, t = pw.harvest(y, FS, f0_floor=70, f0_ceil=900, frame_period=FP)
            an = (f0, pw.cheaptrick(y, f0, t, FS), pw.d4c(y, f0, t, FS))
        cache[key] = (y, np.abs(y).max() + 1e-9, an)
    return cache[key]

end = max(float(e[0]) for e in ev) + 3
mix = np.zeros(int(end * FS) + FS)
for at, sp, syl, rate, lead, voice, cents, scoop, vib, vibRate, gain in ev:
    at, rate, lead = float(at), float(rate), float(lead)
    cents, scoop, vib, vibRate, gain = map(float, (cents, scoop, vib, vibRate, gain))
    y, peak, an = take(f"{sp}/{syl}")
    vowelAt = at + lead                # where the vowel lands (the beat), as in the game
    start = lead * rate                # the consonant's length in the take itself
    if HOW == 'resample':
        r = rate * 2 ** (cents / 1200)
        out = np.interp(np.arange(0, len(y) - 1, r), np.arange(len(y)), y)
        begin = vowelAt - start / r
    else:
        f0, spec, ap = an
        el = np.arange(len(f0)) * FP / 1000 - start      # seconds since the vowel began
        curve = np.full(len(f0), cents)
        curve -= np.where(el < 0.08, scoop * (1 - np.clip(el, 0, None) / 0.08), 0)
        on = el > 0.12
        curve += np.where(on, vib * np.sin((el - 0.12) * vibRate * 2 * np.pi) * np.clip((el - 0.12) / 0.15, 0, 1), 0)
        out = pw.synthesize(f0 * rate * 2 ** (curve / 1200), spec, ap, FS, FP)
        begin = vowelAt - start
    out = out / (np.abs(out).max() + 1e-9) * 0.35 * 0.8 * gain
    i = int((begin + 0.3) * FS)
    mix[i:i + len(out)] += out[:len(mix) - i]
sf.write(OUT, mix / np.abs(mix).max() * 0.9, FS)
print(f"{OUT.split('/')[-1]}: {len(ev)} notes, {len(mix)/FS:.1f}s")
