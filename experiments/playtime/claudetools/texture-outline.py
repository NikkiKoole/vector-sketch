#!/usr/bin/env python3
# An 8-point outline for src/shape8-dict.lua measured from a texture (its line and mask), for a picture
# not yet traced on scripts/meta.playtime.json, in shape8-dict's order (clockwise from the top): the top
# and bottom of the middle column, the left and right edge a little below the middle (10%, where the
# traced ones put them), and the four corners as far out as the drawing reaches towards the picture's
# corners (from the middle). Box2D takes it as a convex shape, so a dent (body-18's) is bridged.
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
def corner(sx, sy):  # the farthest drawn pixel on the line from the middle to a picture corner
    best = (0, 0)
    for i in range(1, 1001):
        x, y = cx + sx * (w / 2 - 1) * i / 1000, cy + sy * (h / 2 - 1) * i / 1000
        if m[int(y), int(x)]: best = (int(round(x - cx)), int(round(y - cy)))
    return best
b = row(0.1)
ur, lr, ll, ul = corner(1, -1), corner(1, 1), corner(-1, 1), corner(-1, -1)
v = [0, int(col.min() - cy), ur[0], ur[1], b[1], b[2], lr[0], lr[1], 0, int(col.max() - cy), ll[0], ll[1], b[0], b[2],
     ul[0], ul[1]]
print("    ['%s.png'] = { dimensions = { %d, %d },\n        vertices = { %s } }," % (name, w, h, ', '.join(map(str, v))))
