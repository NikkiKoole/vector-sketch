# Test of AB1 (docs/ASSETS-AND-BUILDS.md): a scanned sheet of drawings -> Playtime textures.
#   outline: white RGB, alpha = how dark the ink is (keeps the crayon grain), hidden pixels white
#   mask:    opaque grey, white inside the shape (the outline filled), black outside
# A prototype (2026-11-03); the plan is a LÖVE tool like experiments/alpha-padder.
# usage: python3 -I claudetools/scan2tex.py <scan.png> <outdir> [name]
import sys, os
from PIL import Image, ImageFilter, ImageOps, ImageChops, ImageDraw

src, outdir = sys.argv[1], sys.argv[2]
name = sys.argv[3] if len(sys.argv) > 3 else os.path.splitext(os.path.basename(src))[0].replace(' ', '')
SCALE = 0.5           # 300 dpi scans -> game size (the game's parts are ~250-500 px)
MERGE = 4             # px (at game size): strokes this close are one part
MIN_AREA = 400        # px of ink: smaller is a speck
CLOSE = 9             # px: gaps in a line up to this are closed before the mask is filled
PAD = 8               # px of transparent margin around a part

g = ImageOps.grayscale(Image.open(src))
g = g.resize((int(g.width * SCALE), int(g.height * SCALE)), Image.LANCZOS)
# levels: paper = a high percentile, ink = a low one
hist = g.histogram(); total = sum(hist)
def pct(p):
    acc = 0
    for v, n in enumerate(hist):
        acc += n
        if acc >= total * p: return v
    return 255
paper, ink = pct(0.60), pct(0.005)
lo, hi = ink + (paper - ink) * 0.10, paper - (paper - ink) * 0.15
alpha = g.point(lambda v: 255 if v <= lo else 0 if v >= hi else int(255 * (hi - v) / (hi - lo)))

# parts: ink grown by MERGE px, then connected regions
grown = alpha.point(lambda a: 255 if a > 40 else 0).filter(ImageFilter.MaxFilter(MERGE * 2 + 1))
w, h = grown.size; px = grown.load(); seen = bytearray(w * h); parts = []
for y in range(h):
    for x in range(w):
        if px[x, y] and not seen[y * w + x]:
            stack, x0, y0, x1, y1, n = [(x, y)], x, y, x, y, 0
            seen[y * w + x] = 1
            while stack:
                cx, cy = stack.pop(); n += 1
                x0, y0, x1, y1 = min(x0, cx), min(y0, cy), max(x1, cx), max(y1, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1; stack.append((nx, ny))
            parts.append((x0, y0, x1, y1, n))

os.makedirs(outdir, exist_ok=True)
k = 0
for (x0, y0, x1, y1, n) in sorted(parts, key=lambda p: (p[1] // 60, p[0])):
    if x0 <= 2 or y0 <= 2 or x1 >= w - 3 or y1 >= h - 3: continue  # the scanner's paper edge, not a drawing
    box = (max(0, x0 - PAD), max(0, y0 - PAD), min(w, x1 + PAD + 1), min(h, y1 + PAD + 1))
    a = alpha.crop(box)
    if sum(1 for v in a.get_flattened_data() if v > 128) < MIN_AREA: continue
    k += 1
    outline = Image.merge('RGBA', (Image.new('L', a.size, 255),) * 3 + (a,))  # white under it all: no halo
    # mask: flood the outside from the border; whatever the flood can't reach is the shape
    # close the line's gaps (grow it, fill, shrink back), so a gap doesn't let the outside in
    solid = a.point(lambda v: 255 if v > 60 else 0).filter(ImageFilter.MaxFilter(CLOSE))
    ImageDraw.floodfill(solid, (0, 0), 128)  # outside -> 128
    mask = solid.point(lambda v: 0 if v == 128 else 255).filter(ImageFilter.MinFilter(CLOSE - 2))
    # specks: ink islands far from the part's own line go
    a = ImageChops.multiply(a, a.point(lambda v: 255 if v > 40 else 0).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3)).point(lambda v: 255 if v else 0))
    open_shape = sum(1 for v in mask.get_flattened_data() if v) < sum(1 for v in a.get_flattened_data() if v > 60) * 1.6
    outline.save(os.path.join(outdir, '%s-%02d.png' % (name, k)))
    mask.convert('RGB').save(os.path.join(outdir, '%s-%02d-mask.png' % (name, k)))
    print('%s-%02d %dx%d%s' % (name, k, a.width, a.height, '  (open: no inside to fill)' if open_shape else ''))
print('paper %d, ink %d; %d parts' % (paper, ink, k))
