#!/usr/bin/env python3
# lettering-forge: a font's letters "drawn by hand" three times each, into one atlas for src/lettering.lua
# (docs/HANDDRAWN-FONT.md, the software route: Nikki 2026-11-12 "take a font, say comicsans, you try to follow
# (aka draw) each glyph (three times)").
#
#   python3 -I claudetools/lettering-forge.py                 # Comic Sans MS -> textures/lettering/comic.*
#   python3 -I claudetools/lettering-forge.py --font <ttf> --name <name> [--em 160] [--wobble 1] [--seed 1]
#   python3 -I claudetools/lettering-forge.py --preview "Hola Mipo" [--out preview.png]
#
# Each drawing follows the glyph's outline (flattened from the font's curves) with the line pushed in and out
# along its length by a smooth wobble (a slow one: the hand drifting; a quick one: the pen's tremble), the
# letter a little turned, stretched and shifted, so the three differ like three tries of one hand. Filled white
# on clear (tinted when drawn), 4x supersampled. Out: <name>.png (the atlas) and <name>.lua (metrics: per
# character the advance and its drawings' quads and offsets from the pen on the baseline, in atlas pixels;
# `clean`: the letter as the font has it, no wobble, for straight text).
# Needs: fontTools, Pillow, numpy.
import argparse
import math
import os
import random
import sys

import numpy as np
from fontTools.pens.basePen import BasePen
from fontTools.ttLib import TTFont
from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_FONT = '/System/Library/Fonts/Supplemental/Comic Sans MS.ttf'
CHARS = ''.join(chr(c) for c in range(33, 127)) + 'äëïöüéèàçñ'
VERSIONS = 3
SS = 4          # supersampling
PAD = 6         # around each drawing in the atlas, px


class FlattenPen(BasePen):
    """The glyph's contours as polylines (font units), curves cut into short lines."""

    def __init__(self, glyphSet, step):
        super().__init__(glyphSet)
        self.contours, self.cur, self.step = [], None, step

    def _moveTo(self, p):
        self.cur = [p]
        self.contours.append(self.cur)

    def _lineTo(self, p):
        self.cur.append(p)

    def _bezier(self, pts):
        p0 = self.cur[-1]
        ctrl = [p0] + list(pts)
        length = sum(math.dist(ctrl[i], ctrl[i + 1]) for i in range(len(ctrl) - 1))
        n = max(2, int(length / self.step))
        for i in range(1, n + 1):
            t = i / n
            q = ctrl
            while len(q) > 1:
                q = [((1 - t) * a[0] + t * b[0], (1 - t) * a[1] + t * b[1]) for a, b in zip(q, q[1:])]
            self.cur.append(q[0])

    def _curveToOne(self, p1, p2, p3):
        self._bezier([p1, p2, p3])

    def _qCurveToOne(self, p1, p2):
        self._bezier([p1, p2])

    def _closePath(self):
        if len(self.cur) > 1 and self.cur[0] == self.cur[-1]:
            self.cur.pop()
        self.cur = None

    _endPath = _closePath


def resample(pts, spacing):
    """A closed polyline as evenly spaced points (so the wobble runs along the length, not per font point)."""
    pts = np.asarray(pts, dtype=float)
    loop = np.vstack([pts, pts[:1]])
    seg = np.linalg.norm(np.diff(loop, axis=0), axis=1)
    total = seg.sum()
    if total < 1e-6:
        return pts, 0.0
    cum = np.concatenate([[0], np.cumsum(seg)])
    n = max(8, int(total / spacing))
    s = np.linspace(0, total, n, endpoint=False)
    x = np.interp(s, cum, loop[:, 0])
    y = np.interp(s, cum, loop[:, 1])
    return np.stack([x, y], axis=1), total


def wobble(pts, total, rng, em, amount):
    """Push each point in or out along the line's normal: a few sines with a whole number of waves around the
    loop (so the start meets the end). Small contours (a dot, a comma) get less, or they'd lose their shape."""
    n = len(pts)
    if n < 3 or amount <= 0:
        return pts
    size = max(np.ptp(pts[:, 0]), np.ptp(pts[:, 1]))
    s = np.arange(n) / n
    d = np.zeros(n)
    # (wavelength as part of the em, amplitude as part of the em)
    for wl, amp in ((0.6, 0.012), (0.25, 0.0065), (0.09, 0.0009)):
        k = max(1, round(total / (wl * em)))
        d += amp * em * rng.uniform(0.6, 1.2) * np.sin(2 * math.pi * (k * s + rng.random()))
    d *= amount * min(1.0, size / (0.25 * em))
    nxt, prv = np.roll(pts, -1, axis=0), np.roll(pts, 1, axis=0)
    t = nxt - prv
    t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-9)
    normal = np.stack([t[:, 1], -t[:, 0]], axis=1)
    return pts + normal * d[:, None]


def draw_version(contours, rng, em, amount):
    """One try at the letter: the contours (px, y down, baseline 0) wobbled and the whole a little off."""
    rot = math.radians(rng.uniform(-2.2, 2.2) * amount)
    sx = 1 + rng.uniform(-0.035, 0.035) * amount
    sy = 1 + rng.uniform(-0.035, 0.035) * amount
    shear = rng.uniform(-0.04, 0.04) * amount
    dx, dy = rng.uniform(-0.012, 0.012) * em * amount, rng.uniform(-0.015, 0.015) * em * amount
    allp = np.vstack(contours)
    cx, cy = allp[:, 0].mean(), allp[:, 1].mean()
    c, s = math.cos(rot), math.sin(rot)
    out = []
    for pts in contours:
        r, total = resample(pts, 0.006 * em)
        r = wobble(r, total, rng, em, amount)
        x, y = r[:, 0] - cx, r[:, 1] - cy
        x = x + shear * y
        x, y = x * sx, y * sy
        x, y = x * c - y * s, x * s + y * c
        out.append(np.stack([x + cx + dx, y + cy + dy], axis=1))
    return out


def rasterize(contours):
    """Even-odd fill (a counter cuts the hole) at SS x, then down. -> (alpha image, left, top) in px."""
    allp = np.vstack(contours)
    left, top = math.floor(allp[:, 0].min()) - 2, math.floor(allp[:, 1].min()) - 2
    right, bottom = math.ceil(allp[:, 0].max()) + 2, math.ceil(allp[:, 1].max()) + 2
    w, h = right - left, bottom - top
    mask = Image.new('L', (w * SS, h * SS), 0)
    for pts in contours:
        one = Image.new('L', mask.size, 0)
        ImageDraw.Draw(one).polygon([((x - left) * SS, (y - top) * SS) for x, y in pts], fill=255)
        mask = ImageChops.logical_xor(mask.convert('1'), one.convert('1')).convert('L')
    return mask.resize((w, h), Image.Resampling.BOX), left, top


def forge(font_path, em, amount, seed):
    font = TTFont(font_path)
    upm = font['head'].unitsPerEm
    scale = em / upm
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    hhea = font['hhea']
    rng = random.Random(seed)
    letters = {}
    for ch in ' ' + CHARS:
        name = cmap.get(ord(ch))
        if not name:
            continue
        g = glyphs[name]
        pen = FlattenPen(glyphs, step=upm / 400)
        g.draw(pen)
        contours = [np.array([(x * scale, -y * scale) for x, y in c]) for c in pen.contours if len(c) > 2]
        entry = {'advance': g.width * scale, 'versions': []}
        if contours:
            for _ in range(VERSIONS):
                img, left, top = rasterize(draw_version(contours, np.random.default_rng(rng.getrandbits(32)),
                                                        em, amount))
                entry['versions'].append({'img': img, 'ox': left, 'oy': top})
            # and the font itself, no wobble (lettering.draw's straight = true); its own rng, so the three
            # drawings stay what they were before this one was added
            img, left, top = rasterize(draw_version(contours, np.random.default_rng(0), em, 0))
            entry['clean'] = {'img': img, 'ox': left, 'oy': top}
        letters[ch] = entry
    metrics = {'em': em, 'ascent': hhea.ascent * scale, 'descent': -hhea.descent * scale,
               'lineHeight': (hhea.ascent - hhea.descent + hhea.lineGap) * scale}
    return letters, metrics


def pack(letters, width=2048):
    """Shelf packing, tallest first. Sets x, y on each version; returns the atlas."""
    items = [v for e in letters.values() for v in e['versions'] + ([e['clean']] if 'clean' in e else [])]
    items.sort(key=lambda v: -v['img'].height)
    x = y = shelf = 0
    for v in items:
        w, h = v['img'].size
        if x + w + PAD > width:
            x, y, shelf = 0, y + shelf, 0
        v['x'], v['y'] = x + PAD, y + PAD
        x += w + PAD
        shelf = max(shelf, h + PAD)
    atlas = Image.new('RGBA', (width, y + shelf + PAD), (255, 255, 255, 0))
    white = Image.new('L', (1, 1), 255)
    for v in items:
        tile = Image.merge('RGBA', [white.resize(v['img'].size)] * 3 + [v['img']])
        atlas.paste(tile, (v['x'], v['y']))
    return atlas


def lua_string(ch):
    return '"' + ch.replace('\\', '\\\\').replace('"', '\\"') + '"'


def write_lua(path, letters, metrics, image_name, atlas):
    lines = ['-- made by claudetools/lettering-forge.py; don\'t edit, run it again',
             'return {',
             f'    image = "{image_name}", width = {atlas.width}, height = {atlas.height},']
    for k in ('em', 'ascent', 'descent', 'lineHeight'):
        lines.append(f'    {k} = {metrics[k]:.2f},')
    lines.append('    letters = {')
    for ch, e in letters.items():
        vs = ', '.join(f'{{ {v["x"]}, {v["y"]}, {v["img"].width}, {v["img"].height}, {v["ox"]}, {v["oy"]} }}'
                       for v in e['versions'])
        if 'clean' in e:
            c = e['clean']
            vs += f', clean = {{ {c["x"]}, {c["y"]}, {c["img"].width}, {c["img"].height}, {c["ox"]}, {c["oy"]} }}'
        lines.append(f'        [{lua_string(ch)}] = {{ advance = {e["advance"]:.2f}, {vs} }},')
    lines.append('    },')
    lines.append('}')
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def preview(letters, metrics, atlas, text, out):
    """The text set the way src/lettering.lua sets it (each letter its own try), three lines: three picks."""
    em = metrics['em']
    lh = int(metrics['lineHeight'])
    width = int(sum(letters.get(c, letters[' '])['advance'] for c in text)) + 40
    img = Image.new('RGBA', (width, lh * 3 + 40), (246, 240, 226, 255))
    for row in range(3):
        pen, base = 20, 20 + int(metrics['ascent']) + row * lh
        prev, prevv = None, None
        for i, ch in enumerate(text):
            e = letters.get(ch)
            if not e:
                continue
            if e['versions']:
                vi = (i * 7 + row * 5 + ord(ch)) % VERSIONS
                if ch == prev and vi == prevv:
                    vi = (vi + 1) % VERSIONS
                v = e['versions'][vi]
                ink = Image.new('RGBA', v['img'].size, (40, 34, 30, 255))
                img.paste(ink, (int(pen + v['ox']), base + v['oy']), v['img'])
                prev, prevv = ch, vi
            pen += e['advance']
    img.save(out)
    print('preview ->', out, f'(em {em})')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--font', default=DEFAULT_FONT)
    ap.add_argument('--name', default='comic')
    ap.add_argument('--em', type=int, default=160)
    ap.add_argument('--wobble', type=float, default=1.0)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--preview')
    ap.add_argument('--out', default='lettering-preview.png')
    a = ap.parse_args()
    letters, metrics = forge(a.font, a.em, a.wobble, a.seed)
    atlas = pack(letters)
    if a.preview:
        preview(letters, metrics, atlas, a.preview, a.out)
        return
    outdir = os.path.join(ROOT, 'textures', 'lettering')
    os.makedirs(outdir, exist_ok=True)
    png = os.path.join(outdir, a.name + '.png')
    atlas.save(png, optimize=True)
    write_lua(os.path.join(outdir, a.name + '.lua'), letters, metrics, 'textures/lettering/' + a.name + '.png',
              atlas)
    n = sum(len(e['versions']) for e in letters.values())
    print(f'{n} drawings of {len(letters)} characters -> {png} ({atlas.width}x{atlas.height})')


if __name__ == '__main__':
    sys.exit(main())
