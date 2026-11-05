# Module functions (lib.x / M.x / ui.x in src/) that nothing names: no .x, :x or 'x' anywhere in the
# code, specs, scenes, tools or the web build. A name defined in two modules counts as used if either is.
# Rough (a name built at runtime, or typed into the bridge by hand, looks unused): a list to look at.
#   python3 -I claudetools/unused-functions.py      (run from experiments/playtime)
import re, glob, collections
defs = []
DEF = [re.compile(r'\s*function\s+(?:lib|M|ui)\.([A-Za-z_]\w*)\s*\('), re.compile(r'(?:lib|M|ui)\.([A-Za-z_]\w*)\s*=\s*function')]
for f in sorted(glob.glob('src/**/*.lua', recursive=True)):
    for i, l in enumerate(open(f, encoding='utf-8', errors='replace'), 1):
        for d in DEF:
            m = d.match(l)
            if m: defs.append((f, i, m.group(1))); break
uses = collections.Counter()
TOK = re.compile(r'[.:]\s*([A-Za-z_]\w*)|[\'"]([A-Za-z_]\w*)[\'"]')
for pat in ['src/**/*.lua','*.lua','spec/**/*.lua','scripts/**/*.lua','tools/**/*.lua','claudetools/**/*.lua','webtest/**/*.lua','webtest/*.js','native/**/*.lua','*.sh','claudetools/*.py']:
    for f in glob.glob(pat, recursive=True):
        for m in TOK.finditer(open(f, encoding='utf-8', errors='replace').read()):
            uses[m.group(1) or m.group(2)] += 1
defcount = collections.Counter(n for _, _, n in defs)
LOVE_CB = set('update draw keypressed keyreleased mousepressed mousereleased mousemoved wheelmoved textinput touchpressed touchreleased touchmoved resize load quit filedropped focus beginContact endContact preSolve postSolve'.split())
out = collections.defaultdict(list)
for f, i, n in defs:
    if n in LOVE_CB: continue
    if uses[n] <= defcount[n]: out[f].append((i, n))
print('unused-looking:', sum(map(len, out.values())), 'of', len(defs), 'module functions, in', len(out), 'files')
for f in sorted(out, key=lambda k: -len(out[k])):
    print(f'{len(out[f]):3} {f}: ' + ', '.join(n for i, n in out[f]))
