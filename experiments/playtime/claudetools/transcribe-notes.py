# transcribe-notes: a clip's notes (polyphonic, chords too) with Spotify's basic-pitch, as JSON [[start s, end s,
# midi, velocity], ...] and a .mid next to it. Runs basic-pitch's ONNX model (its TF saved model won't load
# under TF 2.16 / Keras 3) and aliases scipy.signal.gaussian (moved in scipy 1.13).
# Install: python3 -I -m pip install basic-pitch (2026-11-06: it downgraded numpy 2.4 -> 1.26; librosa,
# demucs, opencv, rembg still import). Fold the notes onto a loop's cycle to keep what repeats (MUSIC-ANALYSIS Song 4).
# usage: python3 -I claudetools/transcribe-notes.py clip.wav out.json [onset_threshold 0.5]
import sys, json, numpy as np
import scipy.signal, scipy.signal.windows
if not hasattr(scipy.signal, 'gaussian'): scipy.signal.gaussian = scipy.signal.windows.gaussian  # moved in scipy 1.13
from basic_pitch.inference import predict
import basic_pitch, os
MODEL = os.path.join(os.path.dirname(basic_pitch.__file__), 'saved_models', 'icassp_2022', 'nmp.onnx')
path, out = sys.argv[1], sys.argv[2]
_, midi, notes = predict(path, MODEL, onset_threshold=float(sys.argv[3]) if len(sys.argv) > 3 else 0.5,
                         frame_threshold=0.3, minimum_note_length=40)
notes = sorted(notes, key=lambda n: (n[0], n[2]))
json.dump([[float(a), float(b), int(p), float(v)] for a, b, p, v, *_ in notes], open(out, 'w'))
midi.write(out.replace('.json', '.mid'))
print(len(notes), "notes")
