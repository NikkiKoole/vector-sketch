#!/usr/bin/env python3
r"""How songs in a style family use chords and build their form, from Chordonomicon, next to our styles.

    python3 -I claudetools/chordonomicon-report.py ~/music-reference/chordonomicon/chordonomicon_v2.csv \
        [--compare <style-report out dir>] [--progressions] [--families bossa,lounge] [--json out.json]

The data: Chordonomicon (huggingface.co/datasets/ailsntua/Chordonomicon, CC BY-NC 4.0): 680k songs'
chords in order, marked by section (<verse_1> F C E7 Amin ...), with Spotify genre tags; no tune, no
chord lengths, no key (found here from the chords). The chords come from guitar-tab sites, so they are
often simpler than played (bossa reads 40% plain triads; HookTheory's 'rich' is the better colour number).
Learning material, outside the repo (docs/MUSIC-ANALYSIS.md). A family is the songs carrying one of its
genre tags (FAMILIES below); 'pop' is every song whose main genre is pop, the baseline.
Columns:
  chords   different chords per song     rich   chords of 4+ notes     out  roots outside the key's scale
  inv      slash chords (not root position)    fifth/step/third/tri   how the root moves to the next chord
  secs     sections per song   bridge  songs with a bridge   len  chords per verse/chorus (repeats counted)
  modul    songs where a section sits in another key than the song's
--progressions adds each family's most used 4-chord progressions, in Roman numerals (lower case = minor,
7 = 4+ notes) and their share of the family's 4-chord runs. --json writes the numbers and progressions.
Plain Python, nothing to install. Reading the whole file takes about a minute.
"""
import argparse, csv, glob, json, os, re, statistics
from collections import Counter, defaultdict

FAMILIES = {
    'bossa': {'bossa nova', 'mpb', 'brazilian jazz', 'samba'},
    'citypop': {'yacht rock', 'city pop', 'shibuya-kei'},   # real city pop is 11 songs: yacht rock is its cousin
    'lofi': {'lo-fi beats', 'chillhop'},
    'jazz': {'cool jazz', 'bebop', 'jazz piano', 'vocal jazz', 'jazz'},
    'lounge': {'lounge', 'exotica', 'space age pop', 'easy listening', 'library music'},
    'soul': {'classic soul', 'motown', 'neo soul', 'quiet storm'},
    'game': {'video game music', 'japanese vgm'},
    'pop': None,
}
ap = argparse.ArgumentParser()
ap.add_argument('data'); ap.add_argument('--compare', default='')
ap.add_argument('--families', default=','.join(FAMILIES)); ap.add_argument('--progressions', action='store_true')
ap.add_argument('--json', default='')
a = ap.parse_args()
wanted = a.families.split(',')

NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
TOKEN = re.compile(r'([A-G])(s(?!us)|b)?([^/]*)(?:/([A-G])(s|b)?)?$')
def chord_pcs(q):
    """the chord's notes from the root, from its spelling (min7, maj9, 7sus4, add13 (= 6), no3d ...)"""
    if q.startswith('no3d'): base = {0, 7}
    elif q.startswith('dim'): base = {0, 3, 6}
    elif q.startswith('aug'): base = {0, 4, 8}
    elif q.startswith('min'): base = {0, 3, 7}
    else: base = {0, 4, 7}
    if 'sus2' in q: base = base - {3, 4} | {2}
    if 'sus4' in q: base = base - {3, 4} | {5}
    ext = q.replace('sus2', '').replace('sus4', '')
    if 'maj' in ext and re.search(r'maj\D*(7|9|11|13)', ext): base.add(11)
    elif q.startswith('dim7'): base.add(9)
    elif re.search(r'(?<!add)(?<!\d)(7|9|11|13)', ext.replace('maj', 'M')): base.add(10)
    if '9' in ext: base.add(2 if 'b9' not in ext else 1)
    if '11' in ext: base.add(6 if '11s' in ext else 5)
    if '13' in ext: base.add(9)
    if 'b5' in ext: base = base - {7} | {6}
    return base
def parse(tok):
    mo = TOKEN.match(tok)
    if not mo: return None
    root = (NOTE[mo[1]] + (1 if mo[2] == 's' else -1 if mo[2] == 'b' else 0)) % 12
    q = mo[3]
    bass = None if not mo[4] else (NOTE[mo[4]] + (1 if mo[5] == 's' else -1 if mo[5] == 'b' else 0)) % 12
    pcs = chord_pcs(q)
    return {'root': root, 'pcs': frozenset((root + p) % 12 for p in pcs), 'rich': len(pcs) >= 4,
            'minor': 3 in pcs and 4 not in pcs, 'inv': bass is not None and bass != root, 'name': tok}

# keys: Krumhansl-Kessler over the chords' notes (each chord once: no lengths)
MAJ = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
MIN = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
SCALE = {'major': {0, 2, 4, 5, 7, 9, 11}, 'minor': {0, 2, 3, 5, 7, 8, 10}}
def corr(x, y):
    mx, my = sum(x) / 12, sum(y) / 12
    num = sum((p - mx) * (q - my) for p, q in zip(x, y))
    den = (sum((p - mx) ** 2 for p in x) * sum((q - my) ** 2 for q in y)) ** 0.5
    return num / den if den else 0
def key_of(chords):
    w = [0.0] * 12
    for c in chords:
        for p in c['pcs']: w[p] += 1.5 if p == c['root'] else 1
    return max((corr(w, prof[-t:] + prof[:-t]), t, mode) for t in range(12)
               for mode, prof in (('major', MAJ), ('minor', MIN)))[1:]
ROMAN = ['I', 'bII', 'II', 'bIII', 'III', 'IV', '#IV', 'V', 'bVI', 'VI', 'bVII', 'VII']
def roman(c, tonic):
    r = ROMAN[(c['root'] - tonic) % 12]
    return (r.lower() if c['minor'] else r) + ('7' if c['rich'] else '')
def motion(d):
    d %= 12
    return 'fifth' if d in (5, 7) else 'step' if d in (1, 2, 10, 11) else 'third' if d in (3, 4, 8, 9) else 'tritone'

def song_numbers(text):
    sections, cur = [], None
    for tok in text.split():
        if tok.startswith('<'): cur = [re.sub(r'_\d+>$', '', tok[1:]), []]; sections.append(cur); continue
        c = parse(tok)
        if c:
            if cur is None: cur = ['start', []]; sections.append(cur)
            cur[1].append(c)
    chords = [c for _, cs in sections for c in cs]
    if len(chords) < 4: return None
    tonic, mode = key_of(chords)
    changes = [(p, q) for p, q in zip(chords, chords[1:]) if p['name'] != q['name']]
    moves = Counter(motion(q['root'] - p['root']) for p, q in changes)
    romans = []
    for c in chords:
        r = roman(c, tonic)
        if not romans or romans[-1] != r: romans.append(r)
    lens = [len(cs) for name, cs in sections if name in ('verse', 'chorus') and cs]
    modulates = any(len(cs) >= 8 and key_of(cs) != (tonic, mode) and corr_gap(cs, tonic, mode) for _, cs in sections)
    out = {'chords': len({c['name'] for c in chords}), 'rich': sum(c['rich'] for c in chords) / len(chords),
           'out': sum((c['root'] - tonic) % 12 not in SCALE[mode] for c in chords) / len(chords),
           'inv': sum(c['inv'] for c in chords) / len(chords), 'secs': len(sections),
           'bridge': any(name == 'bridge' for name, _ in sections), 'len': statistics.mean(lens) if lens else None,
           'modul': modulates, 'romans': romans}
    for k in ('fifth', 'step', 'third', 'tritone'): out[k] = moves[k] / len(changes) if changes else None
    return out
def corr_gap(cs, tonic, mode):
    """a section really in another key: its own key fits clearly better than the song's (not a wobble)"""
    w = [0.0] * 12
    for c in cs:
        for p in c['pcs']: w[p] += 1
    own_t, own_m = key_of(cs)
    prof = lambda t, m: (MAJ if m == 'major' else MIN)[-t:] + (MAJ if m == 'major' else MIN)[:-t]
    return corr(w, prof(own_t, own_m)) - corr(w, prof(tonic, mode)) > 0.25

COLS = ['chords', 'rich', 'out', 'inv', 'fifth', 'step', 'third', 'tritone', 'secs', 'bridge', 'len', 'modul']
PCT = {'rich', 'out', 'inv', 'fifth', 'step', 'third', 'tritone', 'bridge', 'modul'}
def average(rows):
    avg = {}
    for c in COLS:
        v = [float(r[c]) for r in rows if r.get(c) is not None]
        avg[c] = statistics.mean(v) if v else None
    return avg
def show(name, n, v):
    cells = ['-' if v.get(c) is None else f'{100 * v[c]:.0f}%' if c in PCT else f'{v[c]:.1f}' for c in COLS]
    print(f'{name:<16}{n:>7} ' + ''.join(f'{x:>8}' for x in cells))

csv.field_size_limit(10 ** 8)
rows = defaultdict(list)
for song in csv.DictReader(open(os.path.expanduser(a.data))):
    tags = set(re.findall(r"'([^']+)'", song['genres'] or ''))
    fams = [f for f in wanted if (FAMILIES[f] is None and song['main_genre'] == 'pop') or (FAMILIES[f] and tags & FAMILIES[f])]
    if not fams: continue
    r = song_numbers(song['chords'])
    if r:
        for f in fams: rows[f].append(r)

print(f"{'':<16}{'songs':>7} " + ''.join(f'{c:>8}' for c in COLS))
summary = {}
for f in wanted:
    if not rows[f]: print(f'{f:<16}{0:>7}'); continue
    avg = average(rows[f]); show(f, len(rows[f]), avg)
    grams = Counter(tuple(r['romans'][i:i + 4]) for r in rows[f] for i in range(len(r['romans']) - 3))
    total = sum(grams.values()) or 1
    summary[f] = {'songs': len(rows[f]), **avg,
                  'progressions': [[' '.join(g), round(c / total, 4)] for g, c in grams.most_common(30)]}

if a.compare:
    ours = defaultdict(list)
    for fn in glob.glob(os.path.join(a.compare, '*-seed*.json')):
        d = json.load(open(fn))
        if 'shared' not in d: continue
        sh = d['shared']
        ours[os.path.basename(fn).split('-seed')[0]].append({
            'chords': d['distinct_chords'], 'rich': sh['rich_chords'], 'out': sh['out_of_key'], 'inv': sh['inversions'],
            **{k: sh['root_motion'].get(k, 0) for k in ('fifth', 'step', 'third', 'tritone')},
            'romans': sh.get('romans', [])})
    print('\nour styles (a chord per bar, from the recorded notes; form is set by the style, so left out)')
    for style in sorted(ours):
        show(style, len(ours[style]), average(ours[style]))
        grams = Counter(tuple(r['romans'][i:i + 4]) for r in ours[style] for i in range(len(r['romans']) - 3))
        summary['ours: ' + style] = {'progressions': [[' '.join(g), c] for g, c in grams.most_common(30)]}

# the progressions typical of a family: in a larger share of its songs than of pop's (I-IV-I-IV is
# everywhere). Counted per song, so one song looping an odd turn eight times doesn't make it typical
def songs_with(rs):
    df = Counter()
    for r in rs:
        df.update({tuple(r['romans'][i:i + 4]) for i in range(len(r['romans']) - 3)})
    return df
pop_df = songs_with(rows['pop']) if rows.get('pop') else None
for f in wanted:
    if f == 'pop' or not rows[f] or not pop_df: continue
    n, n_pop = len(rows[f]), len(rows['pop'])
    lift = [((c / n) / ((pop_df[g] + 1) / n_pop), ' '.join(g), c / n)
            for g, c in songs_with(rows[f]).items() if c >= max(5, n // 100)]
    summary[f]['typical'] = [[p, round(x, 1), round(share, 3)] for x, p, share in sorted(lift, reverse=True)[:30]]

if a.progressions:
    print('\nthe most used 4-chord progressions (share of the family\'s 4-chord runs)')
    for f, s in summary.items():
        if not f.startswith('ours: ') or a.compare:
            print(f'  {f:<18} ' + '   '.join(f'{p} ({100 * c:.1f}%)' if c < 1 else f'{p} (x{c})'
                                           for p, c in s['progressions'][:5]))
    print('\nthe progressions typical of each family (in how many more of its songs than of pop\'s; % of its songs)')
    for f, s in summary.items():
        if s.get('typical'):
            print(f'  {f:<9} ' + '   '.join(f'{p} (x{x:g}, {100 * sh:.0f}%)' for p, x, sh in s['typical'][:5]))
if a.json:
    json.dump(summary, open(a.json, 'w'), indent=1)
    print('\nnumbers and progressions ->', a.json)
