# Per stem (from demucs): when it plays, note shape, range, pitch classes, stereo, wobble.
# usage: python3 -I claudetools/stem-report.py <demucs stem folder>   (see docs/MUSIC-ANALYSIS.md)
import sys, os, numpy as np, librosa
d = sys.argv[1]; SR = 22050; hop = 512
N = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
yy, _ = librosa.load(os.path.join(d, 'drums.wav'), sr=SR, mono=True)
tempo, beats = librosa.beat.beat_track(y=yy, sr=SR, hop_length=hop)
full = None
for stem in ['guitar', 'piano', 'bass', 'drums', 'vocals', 'other']:
    p = os.path.join(d, stem + '.wav')
    st, _ = librosa.load(p, sr=SR, mono=False)
    y = st.mean(axis=0)
    tun = librosa.estimate_tuning(y=y, sr=SR)
    rms = librosa.feature.rms(y=y, hop_length=hop)[0]
    t = librosa.times_like(rms, sr=SR, hop_length=hop)
    peak = rms.max()
    print(f"\n===== {stem}  (loudest {20*np.log10(peak+1e-9):.0f} dBFS)")
    # activity map: 5 s cells, '#' loud, '+' audible, '.' faint, ' ' silent (relative to stem peak)
    cells = ''
    for a in range(0, int(t[-1]), 5):
        m = rms[(t >= a) & (t < a + 5)].mean() / peak
        cells += '#' if m > .35 else '+' if m > .12 else '.' if m > .03 else ' '
    print('  plays  |' + cells + '|  (one char = 5 s)')
    # stereo width: side/mid energy
    if st.ndim == 2:
        mid = (st[0] + st[1]) / 2; side = (st[0] - st[1]) / 2
        print(f"  stereo width (side/mid) {np.sqrt((side**2).mean() / ((mid**2).mean() + 1e-12)):.2f}  pan L-R {20*np.log10((np.abs(st[0]).mean()+1e-9)/(np.abs(st[1]).mean()+1e-9)):+.1f} dB")
    env = librosa.onset.onset_strength(y=y, sr=SR, hop_length=hop)
    on = librosa.onset.onset_detect(onset_envelope=env, sr=SR, hop_length=hop)
    loud = rms > 0.12 * peak
    act = loud.mean() * t[-1]
    print(f"  audible {act:.0f} s, onsets {len(on)} ({len(on)/max(act,1):.1f}/s)")
    # note shape: median attack (onset → peak) and half-decay per onset
    att, dec = [], []
    for i, f in enumerate(on):
        g = on[i+1] if i + 1 < len(on) else len(rms) - 1
        r = rms[f:g]
        if len(r) < 3 or r.max() < .12 * peak: continue
        k = int(np.argmax(r)); att.append(k * hop / SR)
        below = np.where(r[k:] < .5 * r[k])[0]
        dec.append((below[0] if len(below) else len(r) - k) * hop / SR)
    if att: print(f"  note shape: attack ~{1000*np.median(att):.0f} ms, half-decay ~{1000*np.median(dec):.0f} ms (or cut by next note)")
    # brightness
    cent = librosa.feature.spectral_centroid(y=y, sr=SR, hop_length=hop)[0]
    print(f"  brightness: centroid median {np.median(cent[loud]) if loud.any() else 0:.0f} Hz")
    # pitch range and most used notes (harmonic part)
    if stem != 'drums':
        C = np.abs(librosa.cqt(y, sr=SR, hop_length=hop, fmin=librosa.note_to_hz('C1'), n_bins=84, tuning=tun))
        Cl = C[:, loud] if loud.any() else C
        prof = Cl.mean(axis=1); used = np.where(prof > .25 * prof.max())[0]
        if len(used): print(f"  pitch range ~{librosa.midi_to_note(24+used.min())} .. {librosa.midi_to_note(24+used.max())}")
        ch = np.zeros(12)
        for i in range(84): ch[i % 12] += prof[i]
        order = np.argsort(ch)[::-1][:7]
        print('  pitch classes: ' + ' '.join(f"{N[k]}{int(100*ch[k]/ch.max())}" for k in order))
    # tremolo / wobble hint: amplitude modulation 2-12 Hz in loud stretches
    if loud.sum() > 200:
        x = rms[loud] - rms[loud].mean()
        F = np.abs(np.fft.rfft(x * np.hanning(len(x)))); fr = np.fft.rfftfreq(len(x), hop / SR)
        band = (fr > 2) & (fr < 12)
        k = np.argmax(F[band]); print(f"  strongest amp wobble {fr[band][k]:.1f} Hz (rhythm or tremolo; compare with beat {float(np.atleast_1d(tempo)[0])/60:.2f} Hz)")
print(f"\ntempo {float(np.atleast_1d(tempo)[0]):.1f} bpm, tuning offset of the mix: see per stem")
