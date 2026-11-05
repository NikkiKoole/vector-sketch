# slot-chroma: per riff slot, a chord part's pitch classes pooled over passes (fine CQT folded to 12,
# tuning-corrected, 30..150 ms after the slot), and its lowest strong note: what a keys / guitar part plays
# over each bass note. Passes from loop-fit's -fit.json; pass indexes to pool, e.g. 1,2.
# --slots file.json: [[beat, bass note name], ...] (default: Mystic Brew's intro riff)
# usage: python3 -I claudetools/slot-chroma.py stem.wav fit.json 1,2 [--slots file.json]
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
import sys, json, numpy as np, librosa
stem, fitp = sys.argv[1], sys.argv[2]; use = [int(x) for x in sys.argv[3].split(',')]
NAMES=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
SLOTS=[0,0.5,2,3,4,4.5,6,6.5,7,8,8.5,10.5,11]
BASS=['G#','C','G','F','C','A#','D#','G','G#','D#','F#','C','C#']
if '--slots' in sys.argv:
    _sl = json.load(open(sys.argv[sys.argv.index('--slots') + 1])); SLOTS = [x[0] for x in _sl]; BASS = [x[1] for x in _sl]
sr,hop=22050,128; y,_=librosa.load(stem,sr=sr); fps=sr/hop
tun=librosa.estimate_tuning(y=y[int(5*sr):int(21*sr)],sr=sr)
C=np.abs(librosa.cqt(y,sr=sr,hop_length=hop,fmin=librosa.note_to_hz('C2'),n_bins=36*6,bins_per_octave=36,filter_scale=2))
passes=json.load(open(fitp))['passes']
print(f"tuning {tun*100:+.0f} c, passes {use}")
print("slot  pos     bass | pitch classes by strength (dB below the slot's strongest)        | lowest strong")
for si,(pos,bn) in enumerate(zip(SLOTS,BASS)):
    acc=np.zeros(36*6)
    for p in use:
        s,b=passes[p]; t=s+pos*b; a=int((t+0.03)*fps); e=int((t+0.15)*fps)
        acc+=C[:,a:e].mean(axis=1)
    pcs=np.zeros(12); per_semi={}
    for k in range(36*6):
        semis=k/3-tun; m=int(round(semis))
        if abs(semis-m)<0.34: per_semi[m]=max(per_semi.get(m,0),acc[k])
    for m,v in per_semi.items(): pcs[m%12]+=v
    db=20*np.log10(pcs/pcs.max()+1e-9); order=np.argsort(-db)
    top=[f"{NAMES[i]}{db[i]:+.0f}" for i in order if db[i]>-9]
    sm=max(per_semi.values()); low=min(m for m,v in per_semi.items() if v>sm*0.35)
    print(f"{si:2d}  {int(pos//4)+1}.{pos%4+1:<4.2f}  {bn:3s} | {' '.join(top):60s} | {NAMES[low%12]}{low//12+1}")
