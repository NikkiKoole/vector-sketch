#!/usr/bin/env python3
# Clean Mipo parts: perfect circles, squares and eggs drawn by code, in the format of the hand-drawn
# scans (textures/mipo/<part>/<part>-<nn>.png: a white line on transparent; -mask.png: white fill on
# black, out to the middle of the line). To try a flat, geometric look next to Nikki's crooked one.
#   python3 -I claudetools/clean-parts.py            # writes the pictures, prints the shape8-dict lines
#   python3 -I claudetools/clean-parts.py --sheet <out.png>   # also a contact sheet on green
# The numbers start at CLEAN_FROM per part (well after the hand-drawn ones), so the scans can grow.
import math, os, sys
from PIL import Image, ImageDraw

SS = 4                      # supersampling
CLEAN_FROM = 50             # body-50, ear-50, ...
LINE = 13                   # line width in px, about the scans' (body-01: ~12-14 at 310 wide)


def ellipse(cx, cy, rx, ry, n=180):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


def superellipse(cx, cy, rx, ry, p=4, n=240):  # a rounded square (p=2 is an ellipse)
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        c, s = math.cos(t), math.sin(t)
        out.append((cx + rx * math.copysign(abs(c) ** (2 / p), c), cy + ry * math.copysign(abs(s) ** (2 / p), s)))
    return out


def egg(cx, cy, rx, ry, k=0.22, n=200):  # narrower at the top
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = math.cos(t), math.sin(t)
        out.append((cx + rx * x * (1 + k * y), cy + ry * y))
    return out


def rounded_poly(corners, r, n=24):  # a polygon with round corners of radius r
    out = []
    m = len(corners)
    for i in range(m):
        p0, p1, p2 = corners[i - 1], corners[i], corners[(i + 1) % m]
        a = math.atan2(p0[1] - p1[1], p0[0] - p1[0])
        b = math.atan2(p2[1] - p1[1], p2[0] - p1[0])
        half = ((b - a) % (2 * math.pi)) / 2
        if half > math.pi / 2: half = math.pi - half
        d = r / math.tan(half) if half > 1e-6 else 0
        u0 = (math.cos(a), math.sin(a)); u2 = (math.cos(b), math.sin(b))
        bis = (u0[0] + u2[0], u0[1] + u2[1]); bl = math.hypot(*bis)
        c = (p1[0] + bis[0] / bl * r / math.sin(half), p1[1] + bis[1] / bl * r / math.sin(half))
        s = (p1[0] + u0[0] * d, p1[1] + u0[1] * d); e = (p1[0] + u2[0] * d, p1[1] + u2[1] * d)
        a0 = math.atan2(s[1] - c[1], s[0] - c[0]); a1 = math.atan2(e[1] - c[1], e[0] - c[0])
        da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
        for j in range(n + 1):
            t = a0 + da * j / n
            out.append((c[0] + r * math.cos(t), c[1] + r * math.sin(t)))
    return out


def capsule(cx, cy, w, h, n=60):  # a stadium, upright
    r = w / 2
    top = [(cx + r * math.cos(math.pi + math.pi * i / n), cy - h / 2 + r + r * math.sin(math.pi + math.pi * i / n)) for i in range(n + 1)]
    bot = [(cx + r * math.cos(math.pi * i / n), cy + h / 2 - r + r * math.sin(math.pi * i / n)) for i in range(n + 1)]
    return top + bot


def leaf(cx, cy, rx, ry, n=200):  # pointed at the top and bottom
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = math.cos(t), math.sin(t)
        out.append((cx + rx * x * (1 - y * y) ** 0.35 * 1.0, cy + ry * y))
    return out


def dome(cx, cy, w, h):  # flat bottom, round top
    r = 40
    rx, ry, by = w / 2, h - r, cy + h / 2  # by: the bottom
    top = [(cx + rx * math.cos(t), by - r + ry * math.sin(t)) for t in [math.pi + math.pi * i / 120 for i in range(121)]]
    right = [(cx + rx - r + r * math.cos(t), by - r + r * math.sin(t)) for t in [math.pi / 2 * i / 20 for i in range(1, 21)]]
    left = [(cx - rx + r + r * math.cos(t), by - r + r * math.sin(t)) for t in [math.pi / 2 + math.pi / 2 * i / 20 for i in range(20)]]
    return top + right + left


def band(w, h):  # a lip: a rectangle with round corners, filling its picture
    return rounded_poly([(PAD, PAD), (w - PAD, PAD), (w - PAD, h - PAD), (PAD, h - PAD)], 16)


# kind -> list of (size, shape function of (w, h) -> outline points, extra marks drawn as lines)
PAD = LINE
def fit(f):  # a shape that fills its picture, inset by the line
    return lambda w, h: f(w / 2, h / 2, w / 2 - PAD, h / 2 - PAD)

PARTS = {
    'body': [
        ((440, 440), fit(ellipse)),                                          # circle
        ((400, 400), lambda w, h: superellipse(w / 2, h / 2, w / 2 - PAD, h / 2 - PAD, 5)),  # rounded square
        ((320, 480), fit(egg)),                                              # egg
        ((256, 512), lambda w, h: capsule(w / 2, h / 2, w - 2 * PAD, h - 2 * PAD)),  # tall capsule
        ((420, 420), lambda w, h: rounded_poly([(w / 2, PAD), (w - PAD, h - PAD), (PAD, h - PAD)], 36)),  # triangle
        ((480, 320), fit(ellipse)),                                          # wide oval
        ((440, 360), lambda w, h: dome(w / 2, h / 2, w - 2 * PAD, h - 2 * PAD)),  # dome
        ((300, 500), lambda w, h: superellipse(w / 2, h / 2, w / 2 - PAD, h / 2 - PAD, 2.6)),  # soft rectangle
    ],
    'ear': [
        ((200, 200), fit(ellipse)),                                          # round
        ((192, 256), lambda w, h: rounded_poly([(w / 2, PAD), (w - PAD, h - PAD), (PAD, h - PAD)], 24)),  # triangle
        ((120, 320), lambda w, h: capsule(w / 2, h / 2, w - 2 * PAD, h - 2 * PAD)),  # long
        ((180, 300), fit(leaf)),                                             # leaf
    ],
    'foot': [
        ((140, 256), fit(ellipse)),                                          # oval
        ((140, 256), lambda w, h: superellipse(w / 2, h / 2, w / 2 - PAD, h / 2 - PAD, 4)),  # rounded block
        ((150, 256), fit(egg)),                                              # egg (heel up)
    ],
    # limbs: a ribbon picture, stretched along the arm or leg (top at the shoulder or hip)
    'leg': [
        ((96, 512), lambda w, h: rounded_poly([(PAD, PAD), (w - PAD, PAD), (w - PAD, h - PAD), (PAD, h - PAD)], 10)),
        ((160, 512), lambda w, h: rounded_poly([(PAD, PAD), (w - PAD, PAD), (w / 2 + 38, h - PAD), (w / 2 - 38, h - PAD)], 10)),
        ((96, 512), lambda w, h: rounded_poly([(PAD, PAD), (w - PAD, PAD), (w - PAD, h - PAD), (PAD, h - PAD)], 10)),
        ((64, 512), lambda w, h: rounded_poly([(PAD, PAD), (w - PAD, PAD), (w - PAD, h - PAD), (PAD, h - PAD)], 10)),
    ],
    # brows: a solid stroke (no line, no mask), bent along the brow curve by the game
    'brow': [
        ((40, 145), lambda w, h: capsule(w / 2, h / 2, w - 4, h - 4)),
        ((30, 145), lambda w, h: capsule(w / 2, h / 2, w - 4, h - 4)),
    ],
    # lips: upright pictures laid along the mouth (black line, mask in the lip colour). As simple as can be: a
    # plain band with the line around it; -50 the fuller one, -51 thinner.
    'upperlip': [((100, 256), lambda w, h: band(w, h)), ((76, 256), lambda w, h: band(w, h))],
    'lowerlip': [((100, 256), lambda w, h: band(w, h)), ((76, 256), lambda w, h: band(w, h))],
    # teeth: a row of them in one picture
    'teeth': [
        ((256, 118), lambda w, h: [rounded_poly([(x0, PAD), (x0 + 30, PAD), (x0 + 30, h - PAD), (x0, h - PAD)], 10)
                                   for x0 in (PAD + 6 + i * 46 for i in range(5))]),
        ((256, 118), lambda w, h: [rounded_poly([(x0, PAD), (x0 + 70, PAD), (x0 + 70, h - PAD), (x0, h - PAD)], 14)
                                   for x0 in (w / 2 - 82, w / 2 + 12)]),
    ],
    'eye': [
        ((146, 133), fit(ellipse)),
        ((146, 146), fit(ellipse)),
    ],
    'pupil': [
        ((71, 71), fit(ellipse)),
        ((60, 80), fit(ellipse)),
    ],
    'nose': [
        ((120, 120), fit(ellipse)),                                          # a ball
        ((140, 120), lambda w, h: rounded_poly([(PAD, PAD), (w - PAD, PAD), (w / 2, h - PAD)], 22)),  # triangle, point down
        ((90, 180), lambda w, h: capsule(w / 2, h / 2, w - 2 * PAD, h - 2 * PAD)),  # a long one
    ],
}


# lines drawn inside a picture, on top of its outline: (kind, index) -> segments
MARKS = {('leg', 2): [((PAD, y), (96 - PAD, y)) for y in range(64, 512 - 32, 64)]}


def draw(size, pts, marks=(), solid=False):
    w, h = size
    W, H = w * SS, h * SS
    polys = pts if isinstance(pts[0], list) else [pts]  # one outline, or several (a row of teeth)
    lw = LINE * SS
    line = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(line)
    mask = Image.new('L', (W, H), 0)
    for poly in polys:
        big = [(x * SS, y * SS) for x, y in poly]
        if solid:
            d.polygon(big, fill=255)
        else:
            d.line(big + big[:2], fill=255, width=lw, joint='curve')
            for x, y in big[::4]:
                d.ellipse((x - lw / 2, y - lw / 2, x + lw / 2, y + lw / 2), fill=255)
        ImageDraw.Draw(mask).polygon(big, fill=255)
    for (x0, y0), (x1, y1) in marks:
        d.line([(x0 * SS, y0 * SS), (x1 * SS, y1 * SS)], fill=255, width=lw)
    line = line.resize((w, h), Image.LANCZOS)
    mask = mask.resize((w, h), Image.LANCZOS)
    white = Image.new('L', (w, h), 255)
    outline = Image.merge('LA', (white, line))
    maskLA = Image.merge('LA', (mask, Image.new('L', (w, h), 255)))
    return outline, maskLA


def closed_eye(size):  # the eye shut: the bottom half of its circle as an arc
    w, h = size
    W, H = w * SS, h * SS
    lw = LINE * SS
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    r = (w / 2 - PAD) * SS
    pts = [(W / 2 + r * math.cos(t), H / 2 + r * 0.55 * math.sin(t))
           for t in [math.pi * 0.1 + math.pi * 0.8 * i / 60 for i in range(61)]]
    d.line(pts, fill=255, width=lw, joint='curve')
    for x, y in (pts[0], pts[-1]):
        d.ellipse((x - lw / 2, y - lw / 2, x + lw / 2, y + lw / 2), fill=255)
    im = im.resize((w, h), Image.LANCZOS)
    return Image.merge('LA', (Image.new('L', (w, h), 255), im))


# Patterns: white marks on transparent, 512 square, every period divides 512 so they repeat (the game draws
# them mirrored-repeat). textures/pat/clean-<name>.png
def patterns():
    N = 512 * SS
    out = {}

    def new():
        im = Image.new('L', (N, N), 0)
        return im, ImageDraw.Draw(im)

    im, d = new()  # dots, every other row shifted half
    step, r = 64 * SS, 13 * SS
    for j in range(N // step + 1):
        for i in range(N // step + 1):
            x, y = i * step + (step / 2 if j % 2 else 0), j * step
            for dx in (-N, 0, N):
                d.ellipse((x + dx - r, y - r, x + dx + r, y + r), fill=255)
    out['dots'] = im

    im, d = new()  # stripes across
    for y in range(0, N, 64 * SS):
        d.rectangle((0, y, N, y + 22 * SS), fill=255)
    out['stripes'] = im

    im, d = new()  # checks
    c = 64 * SS
    for j in range(N // c):
        for i in range(N // c):
            if (i + j) % 2 == 0: d.rectangle((i * c, j * c, (i + 1) * c - 1, (j + 1) * c - 1), fill=255)
    out['checks'] = im

    im, d = new()  # diagonal stripes, 45 degrees, period 64 along x
    p, wdt = 64 * SS, 20 * SS
    for k in range(-N, 2 * N, p):
        d.polygon([(k, 0), (k + wdt, 0), (k + wdt - N, N), (k - N, N)], fill=255)
    out['diagonal'] = im

    im, d = new()  # rings
    step, r, lw = 128 * SS, 34 * SS, 10 * SS
    for j in range(-1, N // step + 1):
        for i in range(-1, N // step + 1):
            x, y = i * step + step / 2, j * step + step / 2
            d.ellipse((x - r, y - r, x + r, y + r), outline=255, width=lw)
    out['rings'] = im

    im, d = new()  # zigzag rows
    step, amp, lw = 64 * SS, 16 * SS, 10 * SS
    for y0 in range(step // 2, N + step, step):
        pts = [(x, y0 + (amp if (x // (32 * SS)) % 2 else -amp)) for x in range(-32 * SS, N + 64 * SS, 32 * SS)]
        d.line(pts, fill=255, width=lw, joint='curve')
    out['zigzag'] = im

    res = {}
    for name, im in out.items():
        a = im.resize((512, 512), Image.LANCZOS)
        res[name] = Image.merge('LA', (Image.new('L', (512, 512), 255), a))
    return res




def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    made = []
    for kind, shapes in PARTS.items():
        for i, (size, f) in enumerate(shapes):
            name = 'mipo/%s/%s-%02d' % (kind, kind, CLEAN_FROM + i)
            solid = kind in ('brow', 'pupil')  # its own fill, no mask, like the drawn brows and pupil-01
            outline, mask = draw(size, f(*size), MARKS.get((kind, i), ()), solid=solid)
            outline.save('textures/%s.png' % name)
            if not solid:
                mask.save('textures/%s-mask.png' % name)
            if kind == 'eye':
                closed_eye(size).save('textures/%s-closed.png' % name)
            made.append((kind, name, outline, mask))
    for name, im in patterns().items():
        im.save('textures/pat/clean-%s.png' % name)
        made.append(('pat', 'pat/clean-' + name, im.resize((128, 128), Image.LANCZOS), Image.new('LA', (128, 128))))
    if '--sheet' in sys.argv:
        out = sys.argv[sys.argv.index('--sheet') + 1]
        W = sum(o.width for _, _, o, _ in made) + 12 * len(made)
        H = max(o.height for _, _, o, _ in made) * 2 + 12
        sheet = Image.new('RGBA', (W, H), (60, 90, 60, 255))
        x = 0
        for _, _, o, m in made:
            sheet.alpha_composite(o.convert('RGBA'), (x, 0))
            sheet.paste(m.convert('RGB'), (x, H // 2 + 6))
            x += o.width + 12
        sheet.save(out)
    for kind, name, _, _ in made:
        print(name)


if __name__ == '__main__':
    main()
