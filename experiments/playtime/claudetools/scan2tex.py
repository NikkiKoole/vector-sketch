# Test of AB1 (docs/ASSETS-AND-BUILDS.md): a scanned sheet of drawings -> Playtime textures.
#   outline: white RGB, alpha = how dark the ink is (keeps the crayon grain), hidden pixels white
#   mask:    opaque grey, white inside the shape (the outline filled), black outside
# A prototype (2026-11-03); the plan is a LÖVE tool like experiments/alpha-padder.
# usage: python3 -I claudetools/scan2tex.py <scan.png> <outdir> [name]
import sys, os
# INSET=n in the environment overrides the mask's inset (px)
from PIL import Image, ImageFilter, ImageOps, ImageChops, ImageDraw

src, outdir = sys.argv[1], sys.argv[2]
name = sys.argv[3] if len(sys.argv) > 3 else os.path.splitext(os.path.basename(src))[0].replace(' ', '')
SCALE = 0.5           # 300 dpi scans -> game size (the game's parts are ~250-500 px)
MERGE = 4             # px (at game size): strokes this close are one part
MIN_AREA = 400        # px of ink: smaller is a speck
CLOSE = 9             # px: gaps in a line up to this are closed before the mask is filled
INSET = 2             # px: how far inside the line's outer edge the mask stops (0 = right at it)
INSET = int(os.environ.get('INSET', INSET))
SMOOTH = 2.5          # the mask's edge smoothing (a blur radius, then cut)
OPEN_BELOW = 0.07     # under this share of the shape enclosed (not line), a part is open: no mask
SPECK = 60            # px: ink islands smaller than this are dust
PAD = 8               # px of transparent margin around a part

# A phone photo works too (Nikki, 2026-11-03: "a bad relationship with my scanner"): HEIC goes through
# macOS's sips first; uneven light (a hand's shadow, dark corners) is divided out below.
if src.lower().endswith(('.heic', '.heif')):
    import subprocess, tempfile
    png = os.path.join(tempfile.mkdtemp(), 'photo.png')
    subprocess.run(['sips', '-s', 'format', 'png', src, '--out', png], check=True, capture_output=True)
    src = png
g = ImageOps.grayscale(ImageOps.exif_transpose(Image.open(src)))
g = g.resize((int(g.width * SCALE), int(g.height * SCALE)), Image.LANCZOS)
# FLATTEN THE LIGHT: the paper's brightness everywhere (the ink taken out with a max filter, then a big
# blur), divided out, so all the paper is equally white whatever the light did. A scan is already even:
# this changes it very little.
small = g.resize((max(1, g.width // 8), max(1, g.height // 8)), Image.BILINEAR)
paper_light = small.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(12)).resize(g.size, Image.BILINEAR)
import numpy as np
g = Image.fromarray(np.clip(np.asarray(g, np.float32) / np.maximum(np.asarray(paper_light, np.float32), 1) * 255,
                            0, 255).astype(np.uint8))  # pixel / the paper there (paper -> 255)
g = g.filter(ImageFilter.MedianFilter(3))  # the photo's grain
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

def regions(img):  # connected regions of the white pixels: lists of indices
    w, h = img.size; px = img.load(); seen = bytearray(w * h); out = []
    for y in range(h):
        for x in range(w):
            if px[x, y] and not seen[y * w + x]:
                stack, reg = [(x, y)], []
                seen[y * w + x] = 1
                while stack:
                    cx, cy = stack.pop(); reg.append(cy * w + cx)
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not seen[ny * w + nx]:
                            seen[ny * w + nx] = 1; stack.append((nx, ny))
                out.append(reg)
    return out

def only(img, keep):
    out = Image.new('L', img.size, 0); data = bytearray(img.size[0] * img.size[1])
    for reg in keep:
        for i in reg: data[i] = 255
    out.frombytes(bytes(data)); return out

def largest(img):
    regs = regions(img)
    return only(img, [max(regs, key=len)]) if regs else img

def pieces(img):  # every region at least 3% of the biggest (and over a speck): crumbs go
    regs = regions(img)
    if not regs: return img
    big = max(len(r) for r in regs)
    return only(img, [r for r in regs if len(r) >= max(SPECK * 3, big * 0.03)])

def keep_big(img, minimum):
    return only(img, [r for r in regions(img) if len(r) >= minimum])

os.makedirs(outdir, exist_ok=True)
k = 0
for (x0, y0, x1, y1, n) in sorted(parts, key=lambda p: (p[1] // 60, p[0])):
    if x0 <= 2 or y0 <= 2 or x1 >= w - 3 or y1 >= h - 3: continue  # the scanner's paper edge, not a drawing
    box = (max(0, x0 - PAD), max(0, y0 - PAD), min(w, x1 + PAD + 1), min(h, y1 + PAD + 1))
    a = alpha.crop(box)
    if sum(1 for v in a.get_flattened_data() if v > 128) < MIN_AREA: continue
    k += 1
    # specks first: islands of anything visible (grown 1 px, so the crayon grain next to the line counts as
    # the line) smaller than SPECK px go, faint dust included
    a = ImageChops.multiply(a, keep_big(a.point(lambda v: 255 if v > 0 else 0).filter(ImageFilter.MaxFilter(3)),
                                        SPECK))
    outline = Image.merge('RGBA', (Image.new('L', a.size, 255),) * 3 + (a,))  # white under it all: no halo
    # mask: flood the outside from the border; whatever the flood can't reach is the shape
    # the mask: the whole shape, line included, its edge smoothed and pulled in by INSET px, so it
    # reaches under the line but never past it (Nikki: "under the black lines, just not over")
    line = a.point(lambda v: 255 if v > 60 else 0)
    closed = line.filter(ImageFilter.MaxFilter(CLOSE))            # gaps in the line closed
    ImageDraw.floodfill(closed, (0, 0), 128)                      # what the outside reaches -> 128
    shape = closed.point(lambda v: 0 if v == 128 else 255)         # not outside: the shape, grown CLOSE/2
    shape = shape.filter(ImageFilter.MinFilter(CLOSE))             # back to the line's outer edge
    shape = shape.filter(ImageFilter.GaussianBlur(SMOOTH)).point(lambda v: 255 if v >= 128 else 0)
    mask = shape.filter(ImageFilter.MinFilter(INSET * 2 + 1)) if INSET > 0 else shape
    mask = pieces(mask)                                            # every real piece; crumbs go
    mask = mask.filter(ImageFilter.GaussianBlur(0.8))              # a soft, even edge
    # an OPEN part (a line, a stroke, a filled dot like a pupil) has no inside to fill: no mask file, as
    # the game's brows, hair, pupils and lines have none (the bake draws them outline only)
    inside = ImageChops.subtract(shape, line.filter(ImageFilter.MaxFilter(3)))
    inside_px = sum(1 for v in inside.get_flattened_data() if v)
    shape_px = sum(1 for v in shape.get_flattened_data() if v)
    has_inside = shape_px > 0 and inside_px / shape_px >= OPEN_BELOW
    outline.save(os.path.join(outdir, '%s-%02d.png' % (name, k)))
    if has_inside:
        mask.convert('RGB').save(os.path.join(outdir, '%s-%02d-mask.png' % (name, k)))
    print('%s-%02d %dx%d  %s (inside %d%%)' % (name, k, a.width, a.height,
          'mask' if has_inside else 'no mask: open', 100 * inside_px // max(1, shape_px)))
print('paper %d, ink %d; %d parts' % (paper, ink, k))
