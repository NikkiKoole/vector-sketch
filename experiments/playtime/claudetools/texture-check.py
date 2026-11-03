#!/usr/bin/env python3
# Texture names vs texture files (docs/ASSETS-AND-BUILDS.md AB6):
#   - every .png a scene, prefab or the code names that isn't there (after the move list in
#     src/texture-names.lua, as the game would look it up: textures/, textures/pat/, the project root)
#   - every file in textures/ nothing names
# Scenes: scripts/ (and its folders), the save folder's scenes and library/ (--no-save leaves those out).
#   python3 -I claudetools/texture-check.py [--no-save] [-v]
import os, re, sys, glob, json
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
verbose = '-v' in sys.argv
SAVE = os.path.expanduser('~/Library/Application Support/LOVE/playtime')

moves = dict(re.findall(r"\['([^']+)'\] = '([^']+)'", open('src/texture-names.lua').read()))
def resolve(url):
    m = re.match(r'^(textures/)?(.*?)(-mask\.png|\.png)$', url)
    if m and m.group(2) in moves: return (m.group(1) or '') + moves[m.group(2)] + m.group(3)
    return url
def exists(url):
    url = resolve(url)
    return any(os.path.isfile(p) for p in (os.path.join('textures', url), os.path.join('textures/pat', url), url))

def strings(data):
    if isinstance(data, str): yield data
    elif isinstance(data, dict):
        for v in data.values(): yield from strings(v)
    elif isinstance(data, list):
        for v in data: yield from strings(v)

scenes = glob.glob('scripts/**/*.playtime.json', recursive=True)
if '--no-save' not in sys.argv:
    scenes += glob.glob(os.path.join(SAVE, '*.playtime.json')) + glob.glob(os.path.join(SAVE, 'library', '*.json'))
named, missing = set(), {}
for path in sorted(scenes):
    try: data = json.load(open(path, encoding='utf-8'))
    except Exception as e:
        print('  unreadable', path, e); continue
    for s in strings(data):
        if s.endswith('.png') and not s.startswith(('-', '.')):
            named.add(resolve(s))
            if not exists(s): missing.setdefault(s, []).append(os.path.relpath(path, SAVE) if path.startswith(SAVE) else path)

code = ''
for f in glob.glob('src/**/*.lua', recursive=True) + glob.glob('scripts/**/*.lua', recursive=True) + ['main.lua']:
    code += open(f, encoding='utf-8', errors='ignore').read()
for s in re.findall(r"""['"]([^'"\s%<?]+\.png)['"]""", code):
    s = s[len('textures/'):] if s.startswith('textures/') else s
    named.add(s)
    if not exists(s) and not s.startswith(('-', '.')) and s != 'x.png': missing.setdefault(s, []).append('(code)')
for s in re.findall(r"""['"]((?:mipo|world)/[a-z]+/[a-z]+-\d\d)['"]""", code):
    named.update({s + '.png', s + '-mask.png'})
# the parts the code builds from a number (textureNames.part): every file of those kinds counts as named
built = set(re.findall(r"textureNames\.part\('([a-z]+)'", code))

# a mask named by a picture that has none (a bodyhair's fgURL is always set): the game skips it
unmasked = {s for s in missing if s.endswith('-mask.png') and exists(s[:-9] + '.png')}
print('masks named for a picture that has none (skipped when drawn): %d' % len(unmasked))
if verbose:
    for s in sorted(unmasked): print('  ' + s)
missing = {s: w for s, w in missing.items() if s not in unmasked}
print('names that point at nothing: %d' % len(missing))
for s, where in sorted(missing.items()):
    print('  %-40s %d file(s)%s' % (s, len(where), (': ' + ', '.join(sorted(set(where))[:4])) if verbose else ''))
unnamed = []
for f in sorted(glob.glob('textures/**/*.png', recursive=True)):
    rel = os.path.relpath(f, 'textures')
    kind = re.match(r'^mipo/([a-z]+)/', rel)
    if rel in named or (kind and kind.group(1) in built) or rel.startswith(('pat/', 'scantest/')):
        continue
    if rel.endswith('-mask.png') and rel[:-9] + '.png' in named: continue
    unnamed.append(rel)
print('files nothing names: %d' % len(unnamed))
for rel in unnamed: print('  ' + rel)
