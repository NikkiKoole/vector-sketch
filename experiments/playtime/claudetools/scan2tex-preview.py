# usage: python3 -I claudetools/scan2tex-preview.py <out.png> "<dir>/name-*.png"
# The parts drawn as the game does (roughly): the mask filled with a body colour, the outline tinted on top.
import sys, glob, os
from PIL import Image
out, files = sys.argv[1], sorted(f for f in glob.glob(sys.argv[2]) if not f.endswith('-mask.png'))
BODY, LINE, BG = (232, 150, 110), (60, 30, 40), (200, 220, 200)
tiles = []
for f in files:
    o = Image.open(f).convert('RGBA'); m = f.replace('.png', '-mask.png')
    tile = Image.new('RGB', (o.width + 16, o.height + 16), BG)
    if os.path.exists(m):
        mk = Image.open(m).convert('L')
        tile.paste(Image.new('RGB', mk.size, BODY), (8, 8), mk)
    tile.paste(Image.new('RGB', o.size, LINE), (8, 8), o.getchannel('A'))
    tiles.append(tile)
W = 1100; x = y = rowh = 0; placed = []
for t in tiles:
    if x + t.width > W: x, y, rowh = 0, y + rowh + 6, 0
    placed.append((t, x, y)); x += t.width + 6; rowh = max(rowh, t.height)
sheet = Image.new('RGB', (W, y + rowh), (255, 255, 255))
for t, x, y in placed: sheet.paste(t, (x, y))
sheet.save(out)
