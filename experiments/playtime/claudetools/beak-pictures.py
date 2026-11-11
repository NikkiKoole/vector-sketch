#!/usr/bin/env python3
"""beak-pictures.py — placeholder beak pictures for the beaks spike (docs/BEAKS.md).

Each beak is three silhouettes on 512x512 canvases, the beak pointing right, the hinge (the corner of
the mouth) at the left edge, the mouth line (where the two halves meet, shut) at row 256; 512 px = the
beak's length:
  textures/beak/<name>-upper.png  the upper half from the side (above the mouth line, or past it: a hook)
  textures/beak/<name>-lower.png  the lower half from the side
  textures/beak/<name>-top.png    the whole beak from above, centred on row 256: how wide it is
The game (scripts/spikes/beak.lua) builds the 3D beak from them: the side pictures give each half's
height and colours, the top one its width. Fill only, no outline: the outline is drawn.
Hand-drawn ones replace these the same way (same canvas, same hinge and mouth line).

    python3 claudetools/beak-pictures.py          # all beaks
"""
import math
import os

import numpy as np
from PIL import Image

N = 512
MID = 256
OUT = os.path.join(os.path.dirname(__file__), '..', 'textures', 'beak')


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def tip(s, p):
    """1 at the base, rounding off to 0 at the tip (higher p = blunter)."""
    return max(0.0, 1 - min(1.0, s) ** p) ** 0.5


def taper(s, p=1.0):
    return max(0.0, 1 - s) ** p


# Each beak: functions of s (0 hinge .. 1 tip of the upper half), in beak lengths, y down from the mouth line.
#   upper(s) -> (top, bottom) or None past its end; lower(s) the same; half(s) half the width;
#   colour(part, s, y) -> hex; lower parts may end before s = 1.
BEAKS = {}


def duck():
    def upper(s):
        return -(0.12 - 0.05 * s) * tip(s, 5) - 0.004, 0.006 * tip(s, 5)

    def lower(s):
        if s > 0.94:
            return None
        return -0.004, (0.075 - 0.035 * s) * tip(s / 0.94, 4) + 0.004

    def half(s):
        return 0.24 * (0.8 + 0.35 * s) * tip(s, 7) + 0.004

    def colour(part, s, y):
        if part == 'upper' and s > 0.86:
            return 'b8650c'  # the nail
        return 'f2a516' if part == 'upper' else 'e8930f'
    return upper, lower, half, colour


def stork():
    def upper(s):
        return -0.055 * taper(s, 0.95) - 0.003, 0.003

    def lower(s):
        return -0.003, 0.048 * taper(s, 0.95) + 0.003

    def half(s):
        return 0.05 * taper(s, 0.8) + 0.003

    def colour(part, s, y):
        if s > 0.82:
            return 'a8231c'
        return 'd8352a' if part == 'upper' else 'cc2f25'
    return upper, lower, half, colour


def finch():
    def upper(s):
        return -0.30 * taper(s, 1.25) - 0.004, 0.006

    def lower(s):
        if s > 0.92:
            return None
        return -0.004, 0.22 * taper(s / 0.92, 1.2) + 0.004

    def half(s):
        return 0.30 * taper(s, 1.0) + 0.004

    def colour(part, s, y):
        return 'ef5a2a' if part == 'upper' else 'e04d22'
    return upper, lower, half, colour


def parrot():
    def upper(s):
        top = -0.42 * (1 - s ** 1.6) + 0.30 * s ** 2.2
        bottom = 0.42 * max(0.0, (s - 0.5) / 0.5) ** 1.7 + 0.006
        return top - 0.004, max(bottom, top + 0.02)

    def lower(s):
        if s > 0.52:
            return None
        u = s / 0.52
        return -0.004 + 0.06 * u ** 2, 0.30 * tip(u, 2.2) + 0.004

    def half(s):
        return 0.30 * taper(s, 0.7) + 0.004

    def colour(part, s, y):
        if part == 'upper':
            return '3b3a40' if s > 0.55 else '4b4a52'
        return '2f2e33'
    return upper, lower, half, colour


def toucan():
    def droop(s):
        return 0.07 * s ** 2

    def upper(s):
        return -0.19 * tip(s, 2.4) - 0.004 + droop(s), 0.006 + droop(s)

    def lower(s):
        if s > 0.97:
            return None
        return -0.004 + droop(s), 0.15 * tip(s / 0.97, 2.2) + 0.004 + droop(s)

    def half(s):
        return 0.11 * taper(s, 0.7) + 0.004

    def colour(part, s, y):
        if s < 0.07:
            return '2e8b3a'  # the green band at the base
        if s > 0.84:
            return '1d1b1a'  # the black tip
        if part == 'upper':
            return 'f7b81e' if y < -0.05 + droop(s) * 0 else 'f08a1c'
        return 'f39a1d' if s < 0.6 else 'd8402a'
    return upper, lower, half, colour


BEAKS = {'duck': duck, 'stork': stork, 'finch': finch, 'parrot': parrot, 'toucan': toucan}


def side(fn, part, colour):
    img = np.zeros((N, N, 4), dtype=np.uint8)
    for x in range(N):
        s = (x + 0.5) / N
        span = fn(s)
        if span is None:
            continue
        top, bottom = span
        r0, r1 = MID + top * N, MID + bottom * N
        if r1 - r0 < 1:
            continue
        for row in range(max(0, math.floor(r0)), min(N, math.ceil(r1))):
            y = (row + 0.5 - MID) / N
            img[row, x, :3] = hexrgb(colour(part, s, y))
            img[row, x, 3] = 255
    return Image.fromarray(img, 'RGBA')


def top(half, colour):
    img = np.zeros((N, N, 4), dtype=np.uint8)
    for x in range(N):
        s = (x + 0.5) / N
        h = half(s) * N
        if h < 0.5:
            continue
        for row in range(max(0, math.floor(MID - h)), min(N, math.ceil(MID + h))):
            img[row, x, :3] = hexrgb(colour('upper', s, -0.1))
            img[row, x, 3] = 255
    return Image.fromarray(img, 'RGBA')


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in BEAKS.items():
        upper, lower, half, colour = make()
        side(upper, 'upper', colour).save(os.path.join(OUT, name + '-upper.png'))
        side(lower, 'lower', colour).save(os.path.join(OUT, name + '-lower.png'))
        top(half, colour).save(os.path.join(OUT, name + '-top.png'))
        print('textures/beak/' + name + '-{upper,lower,top}.png')


if __name__ == '__main__':
    main()
