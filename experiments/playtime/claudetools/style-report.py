#!/usr/bin/env python3
r"""Every music style next to the real pieces, in the numbers of claudetools/score-analysis.py.

    python3 -I claudetools/style-report.py [--seeds 5] [--styles bossa,satie] [--out dir]

Per style: a song per seed recorded without sound (render-music.lua, NOTES_ONLY), each analysed, the
numbers averaged. The score pieces (src/music-scores/) are analysed as they are, as the yardstick.
What the columns mean:
  chords      different chords in the song          chg/8   chord changes per 8 bars
  step%       how often each part moves by 1-2 semitones to its next note (tune, keys, bass)
  hold%       how often the keys repeat the notes they just played (a held, re-struck chord)
  lines/8     lines moving by step (4+ notes one way) per 8 bars; chrom = how many by half steps
  back        the share of bars that bring back an earlier bar (same, moved, tune or re-voiced)
  /beat       notes per beat (tune, keys, bass)       span    lowest bass to highest tune, in octaves
  loud        how far the loudness moves (the spread of the bars' loudness, in velocity)
"""
import argparse, glob, json, os, re, statistics, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ap = argparse.ArgumentParser()
ap.add_argument('--seeds', type=int, default=5); ap.add_argument('--styles', default='')
ap.add_argument('--out', default=''); ap.add_argument('--seconds', type=int, default=400)
a = ap.parse_args()
out = a.out or tempfile.mkdtemp(prefix='style-report-')
os.makedirs(out, exist_ok=True)

params = open(os.path.join(ROOT, 'src', 'music-params.lua')).read()
listed = re.search(r"field\('style', 'style', 'choice',\s*\{(.*?)\}", params, re.S).group(1)
styles = [s for s in re.findall(r"'(\w+)'", listed) if s != 'set']
if a.styles: styles = a.styles.split(',')

def analyse(score, js):
    r = subprocess.run([sys.executable, '-I', os.path.join(HERE, 'score-analysis.py'), score, '--json', js],
                       capture_output=True, text=True, timeout=120)
    if r.returncode: print('  analysis failed:', score, r.stderr.strip().splitlines()[-1:]); return None
    return json.load(open(js))

def numbers(d):
    secs = [s for s in d['sections'].values()]
    def per_beat(part):
        v = [s[part]['per_beat'] for s in secs if part in s]
        return sum(v) / len(v) if v else None
    lows = [s['bass']['low_midi'] for s in secs if 'bass' in s] or [s['keys']['low_midi'] for s in secs if 'keys' in s]
    highs = [s['tune']['high_midi'] for s in secs if 'tune' in s] or [s['keys']['high_midi'] for s in secs if 'keys' in s]
    return {'chords': d['distinct_chords'], 'chg/8': d['chord_changes_per_8_bars'],
            'step tune': d['step_motion'].get('tune'), 'step keys': d['step_motion'].get('keys'),
            'step bass': d['step_motion'].get('bass'), 'hold keys': d['hold'].get('keys'),
            'lines/8': d['lines_per_8_bars'], 'chrom': d['chromatic_lines'], 'back': d['bars_brought_back'],
            '/beat tune': per_beat('tune'), '/beat keys': per_beat('keys'), '/beat bass': per_beat('bass'),
            'span': (max(highs) - min(lows)) / 12 if lows and highs else None, 'loud': d['loudness_spread']}

rows = []
for f in sorted(glob.glob(os.path.join(ROOT, 'src', 'music-scores', '*.lua'))):
    d = analyse(f, os.path.join(out, os.path.basename(f)[:-4] + '.json'))
    if d: rows.append(('piece: ' + d['name'], 1, numbers(d)))
for style in styles:
    got = []
    for seed in range(1, a.seeds + 1):
        notes = os.path.join(out, f'{style}-seed{seed}.lua')
        env = dict(os.environ, NOTES=notes, NOTES_ONLY='1')
        r = subprocess.run(['luajit', os.path.join(HERE, 'render-music.lua'), '/dev/null', str(a.seconds), style, 'auto',
                            '20', str(seed)], cwd=ROOT, env=env, capture_output=True, text=True, timeout=300)
        if r.returncode or not os.path.exists(notes):
            print(f'  {style} seed {seed}: no song', (r.stderr or r.stdout).strip().splitlines()[-1:]); continue
        d = analyse(notes, notes[:-4] + '.json')
        if d: got.append(numbers(d))
    if not got: continue
    avg = {}
    for k in got[0]:
        v = [g[k] for g in got if g[k] is not None]
        avg[k] = statistics.mean(v) if v else None
    rows.append((style, len(got), avg))

cols = ['chords', 'chg/8', 'step tune', 'step keys', 'step bass', 'hold keys', 'lines/8', 'chrom', 'back',
        '/beat tune', '/beat keys', '/beat bass', 'span', 'loud']
pct = {'step tune', 'step keys', 'step bass', 'hold keys', 'back'}
print(f"{'':<20}{'n':>3} " + ''.join(f'{c.split()[-1] if " " in c else c:>8}' for c in cols))
print(f"{'':<24}" + ''.join(f'{(c.split()[0] if " " in c else ""):>8}' for c in cols))
for name, n, v in rows:
    cells = []
    for c in cols:
        x = v[c]
        cells.append('-' if x is None else f'{100 * x:.0f}%' if c in pct else f'{x:.1f}' if isinstance(x, float) else str(x))
    print(f'{name:<20}{n:>3} ' + ''.join(f'{x:>8}' for x in cells))
print('\nsongs and their analyses:', out)
