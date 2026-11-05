# bass-notes: a bass stem note by note in NoteOpts terms (timing, gain, length, decay, scoop, cents, vibrato,
# brightness closing). A beat tracker easily locks to double time: pin it with --bpm; --grid takes the beat from
# another stem (a drum stem's).
# usage: python3 -I claudetools/bass-notes.py bass.wav [start_s] [dur_s] [--bpm N] [--grid drums.wav] [--csv out.csv]
# (MUSIC-ANALYSIS.md Song 3 shows them used: Electric Relaxation, Mystic Brew, Outside Love; 2026-11-06)
# Per note: grid position, timing offset (ms, + = late), gain (dB below loudest), attack ms,
# length in beats + gap to next (legato/detached), decay dB/s (damp), pitch: settled cents,
# scoop (cents at attack vs settled), fall (cents at end), vibrato (cents sd, Hz), slide flag,
# brightness: centroid at attack and how many octaves it closes over 250 ms.
import sys
import numpy as np
import librosa

args = [a for a in sys.argv[1:]]
bpm_fix = None
csv_out = None
if '--bpm' in args:
    i = args.index('--bpm'); bpm_fix = float(args[i + 1]); del args[i:i + 2]
grid_src = None
if '--grid' in args:
    i = args.index('--grid'); grid_src = args[i + 1]; del args[i:i + 2]
if '--csv' in args:
    i = args.index('--csv'); csv_out = args[i + 1]; del args[i:i + 2]
path = args[0]
start = float(args[1]) if len(args) > 1 else 0.0
dur = float(args[2]) if len(args) > 2 else None
y, sr = librosa.load(path, sr=22050, mono=True, offset=start, duration=dur)
hop = 64
fps = sr / hop

f0, voiced, prob = librosa.pyin(y, fmin=librosa.note_to_hz('A0'), fmax=librosa.note_to_hz('E4'),
                                sr=sr, hop_length=hop, frame_length=4096)
midi = librosa.hz_to_midi(f0)
good = voiced & (prob > 0.25)
tuning = float(np.median((midi[good] - np.round(midi[good])))) if good.sum() > 20 else 0.0

rms = librosa.feature.rms(y=y, frame_length=1024, hop_length=hop)[0]
rdb = 20 * np.log10(rms + 1e-9)
cent = librosa.feature.spectral_centroid(y=y, sr=sr, n_fft=2048, hop_length=hop)[0]
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
onsets = librosa.onset.onset_detect(onset_envelope=env, sr=sr, hop_length=hop, backtrack=True, units='frames',
                                    delta=0.08, wait=int(0.07 * fps))

if bpm_fix:
    tempo = bpm_fix
    _, beats = librosa.beat.beat_track(onset_envelope=env, sr=sr, hop_length=hop, bpm=bpm_fix, tightness=400)
else:
    tempo, beats = librosa.beat.beat_track(onset_envelope=env, sr=sr, hop_length=hop, tightness=200)
    tempo = float(np.atleast_1d(tempo)[0])
if grid_src:
    yg, _ = librosa.load(grid_src, sr=sr, mono=True, offset=start, duration=dur)
    envg = librosa.onset.onset_strength(y=yg, sr=sr, hop_length=hop)
    _, beats = librosa.beat.beat_track(onset_envelope=envg, sr=sr, hop_length=hop, bpm=bpm_fix or 120, tightness=400)
beat_t = librosa.frames_to_time(beats, sr=sr, hop_length=hop)
beat_len = 60.0 / tempo
# a straight grid fitted to the beats (least squares): the player's drift shows up as offsets
k = np.arange(len(beat_t))
slope, icpt = np.polyfit(k, beat_t, 1) if len(beat_t) > 3 else (beat_len, 0.0)
beat_len = slope
print(f"file {path.split('/')[-1]}  from {start:.1f}s  tempo {60/beat_len:.2f} bpm  tuning {tuning*100:+.0f} cents")

times = librosa.frames_to_time(np.arange(len(rms)), sr=sr, hop_length=hop)
peak_all = rms.max()
bounds = list(onsets) + [len(rms) - 1]
rows = []
for idx, (a, b) in enumerate(zip(bounds[:-1], bounds[1:])):
    if b - a < 4:
        continue
    seg = np.arange(a, b)
    pk_i = a + int(np.argmax(rms[a:min(b, a + int(0.12 * fps))]))
    pk = rms[pk_i]
    gain_db = 20 * np.log10(pk / peak_all + 1e-9)
    if gain_db < -30:
        continue
    attack_ms = (pk_i - a) / fps * 1000
    # end: first frame after the peak below peak-20dB, else next onset
    after = np.where(rdb[pk_i:b] < rdb[pk_i] - 20)[0]
    end = pk_i + after[0] if len(after) else b
    length_beats = (end - a) / fps / beat_len
    gap_beats = (b - end) / fps / beat_len
    # decay: slope of dB from peak over up to 400 ms (while above -25)
    dseg = np.arange(pk_i, min(end, pk_i + int(0.4 * fps)))
    decay = np.polyfit(dseg / fps, rdb[dseg], 1)[0] if len(dseg) > 5 else np.nan
    # pitch
    m = midi[a:end]; g = good[a:end]
    if g.sum() < 4:
        continue
    settled_m = np.median(m[g][len(m[g]) // 5: max(len(m[g]) // 5 + 1, 4 * len(m[g]) // 5)])
    note = int(np.round(settled_m - tuning))
    settled_c = (settled_m - tuning - note) * 100
    c = (m - tuning - note) * 100
    first = c[:int(0.03 * fps)][g[:int(0.03 * fps)]]
    scoop = (np.median(first) - settled_c) if len(first) else 0.0
    lastn = int(0.05 * fps)
    tail = c[-lastn:][g[-lastn:]]
    fall = (np.median(tail) - settled_c) if len(tail) > 2 else 0.0
    sus = c[int(0.08 * fps):-lastn][g[int(0.08 * fps):-lastn]] if len(c) > int(0.08 * fps) + lastn + 6 else np.array([])
    vib_sd, vib_hz = 0.0, 0.0
    if len(sus) > 12:
        d = sus - np.convolve(sus, np.ones(9) / 9, mode='same')
        vib_sd = float(np.std(np.polyfit(np.arange(len(sus)), sus, 1)[0] * 0 + sus - np.median(sus)))
        zc = np.sum(np.diff(np.sign(d)) != 0)
        vib_hz = zc / 2 / (len(sus) / fps)
    # a slide: a settled pitch change >80 cents inside the note
    slide = ''
    if g.sum() > 10:
        mm = np.round(m[g] - tuning)
        vals = [v for v in np.unique(mm) if np.sum(mm == v) > 0.15 * len(mm)]
        if len(vals) > 1:
            slide = '->' + '/'.join(librosa.midi_to_note(int(v), unicode=False) for v in vals if int(v) != note)
    # brightness
    ca = np.median(cent[a:a + int(0.04 * fps)])
    cl = np.median(cent[min(end - 1, a + int(0.22 * fps)):min(end, a + int(0.28 * fps)) + 1]) if end - a > int(0.25 * fps) else np.nan
    close_oct = np.log2(cl / ca) if cl == cl else np.nan
    # grid
    t = times[a] + start
    bpos = (times[a] - icpt) / beat_len
    grid16 = np.round(bpos * 4) / 4
    off_ms = (bpos - grid16) * beat_len * 1000
    bar = int(np.floor(grid16 / 4)); beat_in_bar = grid16 - bar * 4
    rows.append(dict(t=t, bar=bar + 1, beat=beat_in_bar + 1, off=off_ms, note=librosa.midi_to_note(note, unicode=False),
                     midi=note, gain=gain_db, att=attack_ms, len=length_beats, gap=gap_beats, decay=decay,
                     cents=settled_c, scoop=scoop, fall=fall, vibsd=vib_sd, vibhz=vib_hz, slide=slide,
                     bright=ca, close=close_oct))

hdr = "   time bar  beat  off_ms note  gain_dB att_ms len_b gap_b dB/s  cents scoop fall vib_sd vibHz  bright close slide"
print(hdr)
for r in rows:
    print(f"{r['t']:7.2f} {r['bar']:3d} {r['beat']:5.2f} {r['off']:+6.0f}  {r['note']:4s} {r['gain']:6.1f} {r['att']:6.0f} "
          f"{r['len']:5.2f} {r['gap']:5.2f} {r['decay']:5.0f} {r['cents']:+5.0f} {r['scoop']:+5.0f} {r['fall']:+5.0f} "
          f"{r['vibsd']:6.1f} {r['vibhz']:5.1f} {r['bright']:6.0f} {r['close']:+5.2f} {r['slide']}")
if csv_out:
    import csv
    with open(csv_out, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
