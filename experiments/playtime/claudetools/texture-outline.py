#!/usr/bin/env python3
# An 8-point outline for src/shape8-dict.lua measured from a texture (its line and mask), for a picture
# not yet traced on scripts/meta.playtime.json: the top and bottom of the middle column, and the left and
# right edge at 25% above, 10% and 42% below the middle, in shape8-dict's order (clockwise from the top).
#   python3 -I claudetools/texture-outline.py mipo/body/body-18
import sys
import numpy as np
from PIL import Image
name = sys.argv[1]
m = np.asarray(Image.open('textures/%s-mask.png' % name).convert('L')) > 127
m = m | (np.asarray(Image.open('textures/%s.png' % name).convert('RGBA'))[:, :, 3] > 127)
h, w = m.shape; cx, cy = w // 2, h // 2
col = np.nonzero(m[:, cx])[0]
def row(f):
    y = int(cy + f * h); xs = np.nonzero(m[y])[0]
    return int(xs.min() - cx), int(xs.max() - cx), y - cy
a, b, c = row(-0.25), row(0.1), row(0.42)
v = [0, int(col.min() - cy), a[1], a[2], b[1], b[2], c[1], c[2], 0, int(col.max() - cy), c[0], c[2], b[0], b[2], a[0], a[2]]
print("    ['%s.png'] = { dimensions = { %d, %d },\n        vertices = { %s } }," % (name, w, h, ', '.join(map(str, v))))
