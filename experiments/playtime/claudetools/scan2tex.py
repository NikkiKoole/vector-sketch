# Test of AB1 (docs/ASSETS-AND-BUILDS.md): a scanned sheet of drawings -> Playtime textures.
#   outline: white RGB, alpha = how dark the ink is (keeps the crayon grain), hidden pixels white
#   mask:    opaque grey, white inside the shape (the outline filled), black outside
# The engine of tools/scan2tex (the LÖVE window); runs on its own too.
# usage: python3 -I claudetools/scan2tex.py <scan.png | photo.heic> <outdir> [name]
# env: SCALE, INSET, INTO, OPEN_BELOW, FILL, SIMILAR (below); CACHE = a folder for what doesn't change
#   between runs (a HEIC's conversion, the game textures' silhouettes), so a re-run is quick
import sys, os, hashlib, pickle
import numpy as np
from scipy import ndimage
from PIL import Image, ImageFilter, ImageOps, ImageChops, ImageDraw

src, outdir = sys.argv[1], sys.argv[2]
name = sys.argv[3] if len(sys.argv) > 3 else os.path.splitext(os.path.basename(src))[0].replace(' ', '')
SCALE = float(os.environ.get('SCALE', 0.5))  # 300 dpi scans -> game size (the game's parts are ~250-500 px)
MERGE = 4             # px (at game size): strokes this close are one part
MIN_AREA = 400        # px of ink: smaller is a speck
CLOSE = 9             # px: gaps in a line up to this are closed before the mask is filled
INSET = 2             # px: how far inside the line's outer edge the mask stops (0 = right at it)
INSET = int(os.environ.get('INSET', INSET))
INTO = float(os.environ.get('INTO', 0.6))  # how far into the line the mask stops, as a share of half its width
# FILL per part, your call where a drawing almost closes (Nikki: "it depends"): FILL='photo5534-05:close,
# scan12-16:open'; auto (the default) / close (filled as if its opening were drawn shut: the line's hull) /
# open (no mask) / mask (a mask even when it's thin)
FILL = dict(kv.split(':') for kv in os.environ.get('FILL', '').split(',') if ':' in kv)
CACHE = os.environ.get('CACHE') or os.path.join(os.path.expanduser('~'), '.cache', 'scan2tex')
os.makedirs(CACHE, exist_ok=True)
SMOOTH = 2.5          # the mask's edge smoothing (a blur radius, then cut)
OPEN_BELOW = float(os.environ.get('OPEN_BELOW', 0.07))  # under this share enclosed (not line): open, no mask
SPECK = 60            # px: ink islands smaller than this are dust
PAD = 8               # px of transparent margin around a part

# square max / min filters (grow / shrink by k//2 px), scipy's: their cost doesn't grow with k the way
# PIL's MaxFilter / MinFilter did (k squared: size 1 with a wide inset took 20 s); edges replicated as PIL's
# (copied: an image made on a numpy array shares its memory, and ImageDraw.floodfill didn't fill it)
def grow(img, k): return Image.fromarray(ndimage.maximum_filter(np.asarray(img), size=k, mode='nearest')).copy()
def shrink(img, k): return Image.fromarray(ndimage.minimum_filter(np.asarray(img), size=k, mode='nearest')).copy()

# A phone photo works too (Nikki, 2026-11-03: "a bad relationship with my scanner"): HEIC goes through
# macOS's sips first; uneven light (a hand's shadow, dark corners) is divided out below.
if src.lower().endswith(('.heic', '.heif')):
    import subprocess
    key = hashlib.sha1(('%s %s' % (os.path.abspath(src), os.path.getmtime(src))).encode()).hexdigest()[:16]
    png = os.path.join(CACHE, key + '.png')  # converted once per photo
    if not os.path.exists(png):
        subprocess.run(['sips', '-s', 'format', 'png', src, '--out', png], check=True, capture_output=True)
    src = png
g = ImageOps.grayscale(ImageOps.exif_transpose(Image.open(src)))
g = g.resize((int(g.width * SCALE), int(g.height * SCALE)), Image.LANCZOS)
# FLATTEN THE LIGHT: the paper's brightness everywhere (the ink taken out with a max filter, then a big
# blur), divided out, so all the paper is equally white whatever the light did. A scan is already even:
# this changes it very little.
small = g.resize((max(1, g.width // 8), max(1, g.height // 8)), Image.BILINEAR)
paper_light = grow(small, 9).filter(ImageFilter.GaussianBlur(12)).resize(g.size, Image.BILINEAR)
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

# parts: ink grown by MERGE px, then connected regions (4-connected)
grown = grow(alpha.point(lambda a: 255 if a > 40 else 0), MERGE * 2 + 1)
w, h = grown.size
labels, count = ndimage.label(np.asarray(grown) > 0)
parts = []
for i, sl in enumerate(ndimage.find_objects(labels)):
    if sl is None: continue
    ys, xs = sl
    parts.append((xs.start, ys.start, xs.stop - 1, ys.stop - 1, i + 1))

def nonzero(img): return int(np.count_nonzero(np.asarray(img)))

def regions(img):  # connected regions of the white pixels (4-connected): a label array and their sizes
    lab, n = ndimage.label(np.asarray(img) > 0)
    return lab, np.bincount(lab.ravel())[1:] if n else np.array([], int)

def keep_where(lab, keep):  # the regions whose index (1-based) is in keep, as an image
    return Image.fromarray(np.where(np.isin(lab, keep), 255, 0).astype(np.uint8))

def pieces(img):  # every region at least 3% of the biggest (and over a speck): crumbs go
    lab, sizes = regions(img)
    if not len(sizes): return img
    return keep_where(lab, np.nonzero(sizes >= max(SPECK * 3, sizes.max() * 0.03))[0] + 1)

def keep_big(img, minimum):
    lab, sizes = regions(img)
    return keep_where(lab, np.nonzero(sizes >= minimum)[0] + 1)

def half_width(line):  # about half the stroke's thickness: how many 1-px shrinks until most of it is gone
    # (n shrinks keep the pixels whose chessboard distance to the outside is over n: one pass, not n)
    b = np.asarray(line) > 0
    total = int(b.sum())
    if not total: return 0
    dist = ndimage.distance_transform_cdt(np.pad(b, 1, mode='edge'), metric='chessboard')[1:-1, 1:-1][b]
    for n in range(1, 41):
        if int((dist > n).sum()) < total * 0.2: return n
    return 40

def hull(line):  # the convex hull of the line's pixels, filled
    w, h = line.size; px = line.load()
    pts = sorted({(x, y) for y in range(0, h, 2) for x in range(0, w, 2) if px[x, y]})
    if len(pts) < 3: return line
    def cross(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
        upper.append(p)
    out = Image.new('L', line.size, 0)
    ImageDraw.Draw(out).polygon(lower[:-1] + upper[:-1], fill=255)
    return out

os.makedirs(outdir, exist_ok=True)
# for tools/scan2tex: the sheet as the parts see it (light flattened), and a list of the parts (parts.json)
g.save(os.path.join(outdir, '_sheet.png'))
listing = []
k = 0
for (x0, y0, x1, y1, own) in sorted(parts, key=lambda p: (p[1] // 60, p[0])):
    if x0 <= 2 or y0 <= 2 or x1 >= w - 3 or y1 >= h - 3: continue  # the scanner's paper edge, not a drawing
    box = (max(0, x0 - PAD), max(0, y0 - PAD), min(w, x1 + PAD + 1), min(h, y1 + PAD + 1))
    # only this part's own ink: a neighbour reaching into the box stays out (the d and the B, side by side)
    mine = Image.fromarray(np.where(labels[box[1]:box[3], box[0]:box[2]] == own, 255, 0).astype(np.uint8))
    a = ImageChops.multiply(alpha.crop(box), mine)
    if int(np.count_nonzero(np.asarray(a) > 128)) < MIN_AREA: continue
    k += 1
    # specks first: islands of anything visible (grown 1 px, so the crayon grain next to the line counts as
    # the line) smaller than SPECK px go, faint dust included
    a = ImageChops.multiply(a, keep_big(grow(a.point(lambda v: 255 if v > 0 else 0), 3), SPECK))
    outline = Image.merge('RGBA', (Image.new('L', a.size, 255),) * 3 + (a,))  # white under it all: no halo
    # mask: flood the outside from the border; whatever the flood can't reach is the shape
    # the mask: the whole shape, line included, its edge smoothed and pulled in by INSET px, so it
    # reaches under the line but never past it (Nikki: "under the black lines, just not over")
    line = a.point(lambda v: 255 if v > 60 else 0)
    closed = grow(line, CLOSE)            # gaps in the line closed
    ImageDraw.floodfill(closed, (0, 0), 128)                      # what the outside reaches -> 128
    shape = closed.point(lambda v: 0 if v == 128 else 255)         # not outside: the shape, grown CLOSE/2
    shape = shrink(shape, CLOSE)             # back to the line's outer edge
    fill = FILL.get('%s-%02d' % (name, k), 'auto')
    if fill == 'close':  # the opening drawn shut: the line's outer hull is the shape
        shape = hull(line)
    # the line's soft fringe (a photo's blur, faint grain) counts as line too, so the mask stays inside it
    shape = ImageChops.subtract(shape, ImageChops.subtract(a.point(lambda v: 255 if v > 15 else 0), line))
    shape = shape.filter(ImageFilter.GaussianBlur(SMOOTH)).point(lambda v: 255 if v >= 128 else 0)
    # in by about half the line's thickness (measured per part: a fat crayon line and a thin marker one
    # differ), INSET px at least (Nikki: the photo's upper lip had colour at its line's edge)
    inset = max(INSET, int(round(half_width(line) * INTO)))
    mask = shrink(shape, inset * 2 + 1) if inset > 0 else shape
    mask = pieces(mask)                                            # every real piece; crumbs go
    mask = mask.filter(ImageFilter.GaussianBlur(0.8))              # a soft, even edge
    # an OPEN part (a line, a stroke, a filled dot like a pupil) has no inside to fill: no mask file, as
    # the game's brows, hair, pupils and lines have none (the bake draws them outline only)
    inside = ImageChops.subtract(shape, grow(line, 3))
    inside_px, shape_px = nonzero(inside), nonzero(shape)
    has_inside = (fill in ('close', 'mask')) or (fill != 'open' and shape_px > 0 and inside_px / shape_px >= OPEN_BELOW)
    outline.save(os.path.join(outdir, '%s-%02d.png' % (name, k)))
    if has_inside:
        mask.convert('RGB').save(os.path.join(outdir, '%s-%02d-mask.png' % (name, k)))
    listing.append({ 'id': '%s-%02d' % (name, k), 'box': box, 'w': a.width, 'h': a.height, 'mask': has_inside,
                     'inside': inside_px / max(1, shape_px), 'fill': fill })
    print('%s-%02d %dx%d  %s (inside %d%%)%s' % (name, k, a.width, a.height,
          'mask' if has_inside else 'no mask: open', 100 * inside_px // max(1, shape_px),
          '' if fill == 'auto' else '  [FILL ' + fill + ']'))
# LOOKS LIKE (Nikki: "a check that it won't add similar or identical things, or asks"): each part's
# silhouette against every texture already in the game and the sheet's other parts. A silhouette: the
# mask (or the line, for an open part), cropped, fit into SIG x SIG, compared by overlap (IoU), turned
# and mirrored (the game's 'r' parts are mirrored). A re-import of the same drawing scores ~0.95+; two
# ovals can score high too, so the tool asks, it doesn't refuse.
import glob
SIG = 40
SIMILAR = float(os.environ.get('SIMILAR', 0.85))
def signature(img):
    b = np.asarray(img.convert('L'), np.uint8) > 100
    ys, xs = np.nonzero(b)
    if len(xs) == 0: return None
    b = b[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = b.shape; k = SIG / max(w, h)
    small = Image.fromarray((b * 255).astype(np.uint8)).resize((max(1, round(w * k)), max(1, round(h * k))), Image.BILINEAR)
    out = np.zeros((SIG, SIG), bool); sw, sh = small.size
    out[(SIG - sh) // 2:(SIG - sh) // 2 + sh, (SIG - sw) // 2:(SIG - sw) // 2 + sw] = np.asarray(small) > 127
    return out
def variants(sig):
    out = []
    for flip in (sig, sig[:, ::-1]):
        for r in range(4): out.append(np.rot90(flip, r))
    return out
def iou(a, b):
    inter = np.logical_and(a, b).sum(); union = np.logical_or(a, b).sum()
    return inter / union if union else 0
def silhouette_of(line_img, mask_img):  # the shape: the mask, else the line (grown a little, so thin lines count)
    if mask_img is not None: return signature(mask_img)
    return signature(grow(line_img, 5))
textures = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'textures')
# the game's textures' silhouettes, kept in CACHE by file and its change time (and the mask's)
index_path = os.path.join(CACHE, 'textures-%d.pickle' % SIG)
try:
    with open(index_path, 'rb') as fh: index = pickle.load(fh)
except Exception:
    index = {}
known, fresh = [], {}
for f in glob.glob(os.path.join(textures, '**', '*.png'), recursive=True):  # mipo/<part>/, world/, ...
    if f.endswith('-mask.png') or '/scantest/' in f: continue
    rel = os.path.relpath(f, textures)[:-4]
    m = f[:-4] + '-mask.png'
    stamp = (os.path.getmtime(f), os.path.getmtime(m) if os.path.exists(m) else 0)
    if rel in index and index[rel][0] == stamp:
        sig = index[rel][1]
    else:
        try:
            im = Image.open(f).convert('RGBA') if Image.open(f).mode == 'P' else Image.open(f)
            line_img = im.getchannel('A') if im.mode in ('RGBA', 'LA') else im.convert('L')
            sig = silhouette_of(line_img, Image.open(m).convert('L') if os.path.exists(m) else None)
        except Exception:
            sig = None
    fresh[rel] = (stamp, sig)
    if sig is not None: known.append((rel, sig))
with open(index_path, 'wb') as fh: pickle.dump(fresh, fh)
mine = []
for entry in listing:
    m = os.path.join(outdir, entry['id'] + '-mask.png')
    line_img = Image.open(os.path.join(outdir, entry['id'] + '.png')).getchannel('A')
    mine.append(silhouette_of(line_img, Image.open(m).convert('L') if os.path.exists(m) else None))
for i, entry in enumerate(listing):
    sig = mine[i]; found = []
    if sig is not None:
        vs = variants(sig)
        for rel, other in known + [('(this sheet) ' + listing[j]['id'], mine[j]) for j in range(len(listing)) if j != i and mine[j] is not None]:
            score = max(iou(v, other) for v in vs)
            if score >= SIMILAR: found.append({ 'name': rel, 'score': round(float(score), 3) })
    found.sort(key=lambda f: -f['score'])
    entry['similar'] = found[:4]
import json
with open(os.path.join(outdir, '_parts.json'), 'w') as f:
    json.dump({ 'name': name, 'sheet': [g.width, g.height], 'scale': SCALE, 'paper': paper, 'ink': ink,
                'parts': listing, 'known': len(known) }, f)
for entry in listing:
    if entry['similar']:
        print('  %s looks like %s' % (entry['id'], ', '.join('%s %d%%' % (f['name'], f['score'] * 100) for f in entry['similar'])))
print('paper %d, ink %d; %d parts' % (paper, ink, k))
