#!/usr/bin/env python3
r"""How songs in a style family move their chords and tunes, from HookTheory's TheoryTabs, next to our styles.

    python3 -I claudetools/hooktheory-report.py ~/music-reference/hooktheory/Hooktheory.json.gz \
        [--compare <style-report out dir>] [--progressions] [--families bossa,game]

The data: the Sheet Sage release of HookTheory (github.com/chrisdonahue/sheetsage-data, CC BY-NC-SA 3.0):
song sections with a tune and chords, in beats, no voicings or bass. Learning material only: keep it
outside the repo, take numbers and general patterns from it, never a song's notes (docs/MUSIC-ANALYSIS.md).
A family is the artists matching its pattern (FAMILIES below); 'all' is every section, the pop baseline.
--compare reads the <style>-seed<n>.json files claudetools/style-report.py leaves in its out dir and puts
our styles' same numbers under the families (our chords are one per bar, so chg/8 tops out at 8).
Columns:
  chg/8      chord changes per 8 bars        rich   chords of 4+ notes (7ths, 6ths, 9ths)
  out        chords whose root is outside the key's scale   inv  chords not in root position
  fifth/step/third/tri   how the root moves to the next chord (by a fifth, a step, a third, a tritone)
  /beat      tune notes per beat     step   tune steps of 1-2 semitones    off  tune notes off the beat
  ct         tune notes that are in the chord under them      range  the tune's range in semitones
--progressions adds the family's most used 4-chord progressions, in Roman numerals.
Plain Python, nothing to install.
"""
import argparse, glob, gzip, json, os, re, statistics
from collections import Counter, defaultdict

FAMILIES = {
    'bossa': r'gilberto|jobim|sergio-mendes|jorge-ben|marcos-valle|caetano|bebel|joao-',
    'citypop': r'tatsuro|takeuchi|casiopea|anri$|junko-ohashi|kadomatsu|miki-matsubara|taeko-onuki|t-square|omega-tribe',
    'jazz': r'ellington|guaraldi|brubeck|coltrane|miles-davis|weather-report|mancini|bacharach|bill-evans|monk',
    'lofi': r'nujabes|jinsang|idealism|tomppabeats|j-dilla',
    'game': r'nintendo|koji-kondo|kazumi-totaka|grant-kirkhope|david-wise|toby-fox|c418|mitsuda|shimomura|uematsu|'
            r'hisaishi|pokemon|zelda|mario|kirby|katamari',
    'kids': r'sesame-street|muppets|peanuts',
    'all': r'.',
}
ap = argparse.ArgumentParser()
ap.add_argument('data'); ap.add_argument('--compare', default='')
ap.add_argument('--families', default=','.join(FAMILIES)); ap.add_argument('--progressions', action='store_true')
a = ap.parse_args()
data = json.load(gzip.open(os.path.expanduser(a.data)))

ROMAN = ['I', 'bII', 'II', 'bIII', 'III', 'IV', '#IV', 'V', 'bVI', 'VI', 'bVII', 'VII']
def motion(d):
    d %= 12
    return 'fifth' if d in (5, 7) else 'step' if d in (1, 2, 10, 11) else 'third' if d in (3, 4, 8, 9) else 'tritone'

def section_numbers(s):
    an = s['annotations']
    harmony, melody = an.get('harmony') or [], an.get('melody') or []
    if not harmony or not an['keys']: return None
    key = an['keys'][0]
    scale, at = {0}, 0
    for i in key['scale_degree_intervals']: at += i; scale.add(at % 12)
    tonic = key['tonic_pitch_class']
    per_bar = an['meters'][0]['beats_per_bar'] or 4
    bars = an['num_beats'] / per_bar
    def pcs(h):
        out, at = {0}, 0
        for i in h['root_position_intervals']: at += i; out.add(at % 12)
        return {(h['root_pitch_class'] + p) % 12 for p in out}
    chords = [h for h in harmony if h['root_position_intervals']]
    changes = [(p, q) for p, q in zip(chords, chords[1:]) if (p['root_pitch_class'], p['root_position_intervals'])
               != (q['root_pitch_class'], q['root_position_intervals'])]
    weight = lambda h: h['offset'] - h['onset']
    total = sum(weight(h) for h in chords) or 1
    out = {'chg/8': 8 * len(changes) / bars if bars else None,
           'rich': sum(weight(h) for h in chords if len(h['root_position_intervals']) >= 3) / total,
           'out': sum(weight(h) for h in chords if (h['root_pitch_class'] - tonic) % 12 not in scale) / total,
           'inv': sum(weight(h) for h in chords if h['inversion']) / total}
    moves = Counter(motion(q['root_pitch_class'] - p['root_pitch_class']) for p, q in changes)
    for k in ('fifth', 'step', 'third', 'tritone'):
        out[k] = moves[k] / len(changes) if changes else None
    romans = []
    for h in chords:
        iv = h['root_position_intervals']
        r = ROMAN[(h['root_pitch_class'] - tonic) % 12]
        r = (r.lower() if iv[0] == 3 else r) + ('7' if len(iv) >= 3 else '')
        if not romans or romans[-1] != r: romans.append(r)   # a chord held on (or re-voiced) counts once
    out['romans'] = romans
    notes = [n for n in melody if n.get('pitch_class') is not None]
    if notes:
        midi = [n['octave'] * 12 + n['pitch_class'] for n in notes]
        steps = [abs(y - x) for x, y in zip(midi, midi[1:])]
        def under(n):
            for h in chords:
                if h['onset'] <= n['onset'] < h['offset']: return pcs(h)
            return None
        cts = [n['pitch_class'] in u for n in notes for u in [under(n)] if u is not None]
        out.update({'/beat': len(notes) / an['num_beats'],
                    'tune step': sum(1 <= d <= 2 for d in steps) / len(steps) if steps else None,
                    'off': sum(n['onset'] % 1 > 0.01 for n in notes) / len(notes),
                    'ct': sum(cts) / len(cts) if cts else None, 'range': max(midi) - min(midi)})
    return out

COLS = ['chg/8', 'rich', 'out', 'inv', 'fifth', 'step', 'third', 'tritone', '/beat', 'tune step', 'off', 'ct', 'range']
PCT = {'rich', 'out', 'inv', 'fifth', 'step', 'third', 'tritone', 'tune step', 'off', 'ct'}
def average(rows):
    avg = {}
    for c in COLS:
        v = [r[c] for r in rows if r.get(c) is not None]
        avg[c] = statistics.mean(v) if v else None
    return avg
def show(name, n, v):
    cells = ['-' if v[c] is None else f'{100 * v[c]:.0f}%' if c in PCT else f'{v[c]:.1f}' for c in COLS]
    print(f'{name:<22}{n:>6} ' + ''.join(f'{x:>7}' for x in cells))

print(f"{'':<22}{'n':>6} " + ''.join(f'{c.split()[-1]:>7}' for c in COLS))
print(f"{'':<29}" + ''.join(f'{"tune" if c in ("/beat", "tune step", "off", "ct", "range") else "":>7}' for c in COLS))
progressions = {}
for fam in a.families.split(','):
    pat = re.compile(FAMILIES[fam])
    rows, songs = [], set()
    for s in data.values():
        if not pat.search(s['hooktheory']['artist']): continue
        r = section_numbers(s)
        if not r: continue
        rows.append(r); songs.add((s['hooktheory']['artist'], s['hooktheory']['song']))
    if not rows: print(f'{fam:<22}     0'); continue
    show(f'{fam} ({len(songs)} songs)', len(rows), average(rows))
    grams = Counter(tuple(r['romans'][i:i + 4]) for r in rows for i in range(len(r['romans']) - 3))
    progressions[fam] = grams.most_common(6)

if a.compare:
    by_style = defaultdict(list)
    for f in glob.glob(os.path.join(a.compare, '*-seed*.json')):
        d = json.load(open(f))
        if 'shared' not in d: continue
        sh = d['shared']
        tune = [s['tune'] for s in d['sections'].values() if 'tune' in s]
        by_style[os.path.basename(f).split('-seed')[0]].append({
            'chg/8': d['chord_changes_per_8_bars'], 'rich': sh['rich_chords'], 'out': sh['out_of_key'],
            'inv': sh['inversions'], **{k: sh['root_motion'].get(k, 0) for k in ('fifth', 'step', 'third', 'tritone')},
            '/beat': statistics.mean(t['per_beat'] for t in tune) if tune else None,
            'tune step': d['step_motion'].get('tune'), 'off': sh['tune_offbeat'], 'ct': sh['tune_chord_tones'],
            'range': sh['tune_range']})
    print('\nour styles (chords one per bar, from the recorded notes)')
    for style in sorted(by_style):
        show(style, len(by_style[style]), average(by_style[style]))

if a.progressions:
    print('\nthe most used 4-chord progressions (Roman numerals in the key; lower case = minor, 7 = 4+ notes)')
    for fam, grams in progressions.items():
        print(f'  {fam:<8} ' + '   '.join(f"{' '.join(g)} ({c})" for g, c in grams))
