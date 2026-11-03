#!/usr/bin/env python3
# What a build of Playtime packs (docs/ASSETS-AND-BUILDS.md AB5): the code, the start scene and every
# room its doors lead to, and of textures/ and assets/ only what the code or those rooms name.
# Both builds copy from it (webtest/build-web.sh, native/ios/device.sh).
#   python3 -I claudetools/ship-list.py <scene>            the files, one per line (relative paths)
#   python3 -I claudetools/ship-list.py <scene> --report   what's left out and the sizes, to stderr too
# Exits 1 when the code or a room names a picture or sound that isn't there (the build would be
# missing it): the names go to stderr. spec/ship-list_spec.lua checks the list against what the game
# really opens while those rooms run.
#
# A data file ships when a string in the code or a room names it: its path ('assets/Arial
# Narrow.ttf', 'textures/world/sprieten.png'), its name under textures/ with or without .png
# ('mipo/foot/foot-04.png', the catalogs' 'mipo/foot/foot-04'), a pattern's file name ('type1.png'),
# a sound's name under assets/sounds/ without .ogg ('korg-minipops/tom1'). A mask ships with its
# picture. FOLDERS ship whole: the code builds their file names at runtime.
import os, re, sys, json, glob

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
os.chdir(ROOT)

# whole folders: the names inside are made while the game runs
FOLDERS = {
    'assets/voices/': "src/mipo-voice.lua loadSet: every .ogg of a voice set's folder",
    'assets/sounds/babirhodes/': "src/mipo-band.lua sampleSource: the music's sample notes by name",
}
# always: the code and what the game reads besides pictures and sounds
CODE = ['main.lua', 'conf.lua', 'music-setups.json']
CODE_DIRS = ['src', 'vendor', 'library']
SKIP = ('.DS_Store', 'README.md')


def rooms(start):
    seen, todo = [], [start]
    while todo:
        room = todo.pop()
        path = 'scripts/%s.playtime.json' % room
        if room in seen or not os.path.exists(path):
            continue
        seen.append(room)
        for body in json.load(open(path)).get('bodies', []):
            for behavior in body.get('behaviors') or []:
                if behavior.get('name') == 'DOOR' and behavior.get('to'):
                    todo.append(behavior['to'])
    return seen


def files_under(d):
    out = []
    for dirpath, dirs, names in os.walk(d):
        dirs[:] = [x for x in dirs if not x.startswith('.')]
        for n in names:
            if n not in SKIP and not n.startswith('.'):
                out.append(os.path.relpath(os.path.join(dirpath, n), '.'))
    return sorted(out)


def lua_strings(text):
    """the string literals of Lua code, comments skipped"""
    out, i, n = set(), 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith('--', i):
            m = re.match(r'--\[(=*)\[', text[i:])
            if m:
                end = text.find(']' + m.group(1) + ']', i)
                i = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = text.find('\n', i)
                i = n if end < 0 else end + 1
        elif c in '\'"':
            j, s = i + 1, []
            while j < n and text[j] != c and text[j] != '\n':
                if text[j] == '\\' and j + 1 < n:
                    s.append(text[j:j + 2]); j += 2
                else:
                    s.append(text[j]); j += 1
            out.add(''.join(s)); i = j + 1
        elif c == '[' and re.match(r'\[(=*)\[', text[i:]):
            m = re.match(r'\[(=*)\[', text[i:])
            end = text.find(']' + m.group(1) + ']', i)
            stop = n if end < 0 else end
            out.add(text[i + len(m.group(0)):stop]); i = stop + len(m.group(1)) + 2
        else:
            i += 1
    return out


def json_strings(data, out):
    if isinstance(data, str): out.add(data)
    elif isinstance(data, dict):
        for v in data.values(): json_strings(v, out)
    elif isinstance(data, list):
        for v in data: json_strings(v, out)


def names_of(path):
    """the strings that would name this file"""
    names = {path}
    if path.startswith('textures/'):
        t = path[len('textures/'):]
        stem = t[:-4] if t.endswith('.png') else t
        names |= {t, stem}
        if t.startswith('pat/'): names |= {t[4:], stem}
    if path.startswith('assets/'):
        a = path[len('assets/'):]
        names.add(a)
        if a.startswith('sounds/') and a.endswith('.ogg'): names.add(a[len('sounds/'):-4])
    return names


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    report = '--report' in sys.argv
    scene = args[0] if args else 'dollhouse'
    if not os.path.exists('scripts/%s.playtime.json' % scene):
        sys.exit('no scene scripts/%s.playtime.json' % scene)
    shipped_rooms = rooms(scene)
    code = [p for p in CODE if os.path.exists(p)]
    for d in CODE_DIRS:
        code += files_under(d) if os.path.isdir(d) else []
    room_files = []
    for r in shipped_rooms:
        room_files += sorted(glob.glob('scripts/%s.playtime.*' % r))

    strings = set()
    for p in code:
        if p.endswith('.lua'): strings |= lua_strings(open(p, encoding='utf-8', errors='ignore').read())
        elif p.endswith('.json'):
            try: json_strings(json.load(open(p, encoding='utf-8')), strings)
            except ValueError: pass
    for p in room_files:
        if p.endswith('.json'): json_strings(json.load(open(p, encoding='utf-8')), strings)
        else: strings |= lua_strings(open(p, encoding='utf-8', errors='ignore').read())

    data = files_under('textures') + files_under('assets')
    ships, left = [], []
    for p in data:
        if p.endswith('-mask.png'):
            continue  # with its picture, below
        if any(p.startswith(f) for f in FOLDERS) or names_of(p) & strings:
            ships.append(p)
            mask = p[:-4] + '-mask.png'
            if os.path.exists(mask): ships.append(mask)
        else:
            left.append(p)
    left += [p for p in data if p.endswith('-mask.png') and p not in ships]

    # names that point at nothing: a .png/.ogg/.ttf string that is no file we have (old saves'
    # masks for pictures without one are skipped: the game skips them too)
    have = set()
    for p in data: have |= names_of(p)
    missing = []
    for s in sorted(strings):
        if not re.search(r'\.(png|ogg|ttf|wav)$', s) or s.startswith(('-', '.')) or re.search(r'[%<?*]', s):
            continue
        if s in have or os.path.exists(s):
            continue
        if s.endswith('-mask.png') and (s[:-9] + '.png') in have:
            continue
        missing.append(s)

    out = code + room_files + ships
    print('\n'.join(out))
    size = lambda ps: sum(os.path.getsize(p) for p in ps) / 1e6
    if report:
        sys.stderr.write('rooms: %s\nships %d files, %.1f MB (pictures and sounds %.1f MB); left out %d, %.1f MB:\n'
                         % (' '.join(shipped_rooms), len(out), size(out), size(ships), len(left), size(left)))
        for p in left: sys.stderr.write('  %s\n' % p)
    if missing:
        sys.stderr.write('named but not there (the build would miss them):\n')
        for s in missing: sys.stderr.write('  %s\n' % s)
        sys.exit(1)


main()
