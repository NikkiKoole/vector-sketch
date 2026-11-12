#!/usr/bin/env python3
"""earth-pianoroll: the earth style's loop (src/music-earth.lua) to and from dreamengine's pianoroll cart
(~/Projects/dreamengine/tools/carts/pianoroll.c), so every note is on a grid to see and edit (Nikki 2026-11-12).

  python3 -I claudetools/earth-pianoroll.py export   earth's tables -> the cart's save (both save folders:
                                                      play.js's saves/pianoroll and the editor's saves/piano-roll;
                                                      a save already there is kept as cart.blob.before-earth)
  python3 -I claudetools/earth-pianoroll.py import   the cart's save -> earth's tables, printed as Lua
                                                      (BASS / KEYS / a 16-beat KIT) to paste into music-earth.lua

Run the cart: cd ~/Projects/dreamengine && node tools/play.js pianoroll run (F1 hides the debug overlay).
It saves only on its SAVE button. Tracks: BASS = earth's bass, LEAD = the keys (vibes), PNO = the drums as
pitches (36 kick, 37 rim, 38 brush, 42 shaker, 44 woodblock); the cart's own sounds, not earth's.
The cart's save layout (SaveBlob in pianoroll.c, checked with clang): 32 bytes of header, then 512 notes of 16.
Run from experiments/playtime (export needs luajit for the tables).
"""
import json, os, struct, subprocess, sys

SAVES = [os.path.expanduser('~/Projects/dreamengine/build/saves/' + d) for d in ('pianoroll', 'piano-roll')]
MAGIC, HEAD, NOTE = 0x50524C4C, '<IiiiiiB3xf', '<b3xffBB2x'
TRACK = {'bass': 0, 'keys': 1, 'drums': 3}
DRUMS = {'bapKick': 36, 'rim': 37, 'brush': 38, 'shaker': 42, 'wood': 44}
DUMP = r"""
package.path = './?.lua;' .. package.path
package.loaded['src.state'] = { musicSettings = {} }
love = { math = { random = math.random } }
local e = require('src.music-earth')
local out = {}
for _, n in ipairs(e.BASS) do out[#out + 1] = string.format('{"t":"bass","p":%d,"s":%.4f,"l":%.4f}', n[2], n[1], n[3]) end
for _, k in ipairs(e.KEYS) do
    for i = 4, #k do out[#out + 1] = string.format('{"t":"keys","p":%d,"s":%.4f,"l":%.4f}', k[i], k[1], k[2]) end
end
for _, k in ipairs(e.KIT) do
    out[#out + 1] = string.format('{"t":"kit","name":"%s","s":%.4f,"v":%d,"ms":%d,"midi":%d}', k[2], k[1], k[4], k[5], k[3])
end
print('[' .. table.concat(out, ',') .. ']')
"""


def export():
    rows = json.loads(subprocess.run(['luajit', '-e', DUMP], capture_output=True, text=True, check=True).stdout)
    notes = []
    for r in rows:
        if r['t'] == 'kit':
            for bar in range(4):
                if r['name'] in DRUMS:
                    notes.append(('drums', DRUMS[r['name']], bar * 4 + r['s'], 0.25, min(7, r['v'])))
        else:
            notes.append((r['t'], r['p'], r['s'], r['l'], 5 if r['t'] == 'bass' else 6))
    for bar in range(4):  # the shaker's 8ths (music-earth bookKit plays them outside the KIT table)
        for s in range(0, 16, 2):
            notes.append(('drums', DRUMS['shaker'], bar * 4 + s / 4, 0.25, 4 if s % 4 == 0 else 3))
    blob = bytearray(8224)
    struct.pack_into(HEAD, blob, 0, MAGIC, 2, len(notes), 91, 0, 1, 0, 0.25)  # 91 BPM, root C, MIN
    for i, (t, p, s, l, v) in enumerate(notes):
        struct.pack_into(NOTE, blob, 32 + i * 16, p, s, l, v, TRACK[t])
    for d in SAVES:
        os.makedirs(d, exist_ok=True)
        f = os.path.join(d, 'cart.blob')
        if os.path.exists(f) and not os.path.exists(f + '.before-earth'):
            os.rename(f, f + '.before-earth')
        open(f, 'wb').write(blob)
        print('wrote', f, len(notes), 'notes')


def read(path):
    b = open(path, 'rb').read()
    magic, ver, n, tempo, root, sidx, lock, snap = struct.unpack_from(HEAD, b, 0)
    assert magic == MAGIC and ver == 2, 'not a pianoroll save'
    notes = [struct.unpack_from(NOTE, b, 32 + i * 16) for i in range(n)]
    return tempo, notes


def imp():
    newest = max((os.path.join(d, 'cart.blob') for d in SAVES if os.path.exists(os.path.join(d, 'cart.blob'))),
                 key=os.path.getmtime)
    tempo, notes = read(newest)
    print(f'-- from {newest} ({len(notes)} notes, {tempo} BPM)')
    name = {v: k for k, v in DRUMS.items()}
    bass = sorted((round(s, 4), p, round(l, 4)) for p, s, l, v, t in notes if t == 0)
    keys = {}
    for p, s, l, v, t in notes:
        if t == 1:
            keys.setdefault((round(s, 4), round(l, 4)), []).append(p)
    print('lib.BASS = {')
    for s, p, l in bass:
        print(f'    {{ {s:g}, {p}, {l:g}, {"true" if l <= 0.3 else "false"} }},')
    print('}\nlib.KEYS = {')
    for (s, l), ps in sorted(keys.items()):
        print(f'    {{ {s:g}, {l:g}, 1, {", ".join(str(p) for p in sorted(ps))} }},')
    print('}\nlib.KIT16 = { -- the drums over the whole 16-beat loop: { beat, patch, midi, vol }')
    for p, s, l, v, t in sorted(notes, key=lambda n: n[1]):
        if t == 3:
            print(f"    {{ {s:g}, '{name.get(p, 'rim')}', 60, {v} }},")
    print('}')


if __name__ == '__main__':
    {'export': export, 'import': imp}.get(sys.argv[1] if len(sys.argv) > 1 else '', lambda: print(__doc__))()
