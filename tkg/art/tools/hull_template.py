"""HULL TEMPLATES: one per manufacturer per weight, for the three-sprite hulls.

Since Oct 14 a weight has ONE sprite and its four grades are baked onto it in
code (HullGrade). A manufacturer's three sprites are drawn complete, once, so a
template has to carry everything all four grades will ask of that one picture.
This writes, for each manufacturer and weight:

  template_<maker>_<weight>.png   a block-in at the game's own canvas for that
                                  weight: the brief's silhouette in banded light
                                  (bright top edge, mid flank, shadowed belly),
                                  the manufacturer's band, glass, nozzles and the
                                  thin fittings kit strips. An init image for the
                                  generator (the canvas IS the output size, which
                                  `init_image` requires), or a sketch to draw over.
  guide_<maker>_<weight>.png      the block-in at 3x with what the code needs from
                                  the sprite drawn over it, labelled.

    python art/tools/hull_template.py <out_dir> [maker ...]

EVERYTHING ON THE GUIDE IS MEASURED OFF KORVAN'S BASE FOR THAT WEIGHT (L1, the
medium A, H3), which already passes -- mounts, MouthSize and YardSeatTest:

  envelope   the base's ink box. Inside it the station's mouth and the screens
             that hold a hull fit, because they were sized from it.
  engines    the rows the base's exhaust strips sit on (HULL_EXHAUST): the flame
             is rigged to nozzles at the stern, nose right.
  mounts     the dorsal and ventral lines (HULL_LINES) with S's weapon count:
             A adds a weapon and S a system to the one sprite, so it needs room
             for the S count along clean top and bottom edges.
  band       the manufacturer's colour as one run of at least 40 px (BAND_MIN),
             which HullGrade puts on the manufacturer's ramp and wears at C.
  registry   a plain flank panel 21x7 (look A paints the number a fifth lighter
             than the panel, so the panel must be one even grey).
  glass      dark panes (luma 0.2 or under) for the live lights to fill.
  kit        thin fittings, three pixels wide or less, off the top edge: what
             kit strips toward C. Anything wider stays at every grade.
  belly      a flat run under the hull's middle for the yard's two stands.
"""
import json, os, re, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))

BASES = {'light': 'hull_light_c', 'medium': 'hull_medium_a', 'heavy': 'hull_heavy_a'}
# weapon / system / utility at C; A adds a weapon, S a system (DB.TIER_DELTA)
SLOTS = {'light': (2, 2, 2), 'medium': (3, 2, 2), 'heavy': (4, 2, 1)}

STEEL = [(0x13, 0x1a, 0x23), (0x23, 0x2d, 0x3a), (0x34, 0x42, 0x54), (0x4a, 0x5c, 0x72), (0x6c, 0x80, 0x98), (0x92, 0xaa, 0xc4)]
INK = (0x0b, 0x0f, 0x16)
GUN = [(0x1a, 0x1e, 0x26), (0x3a, 0x40, 0x4c), (0x5c, 0x64, 0x74)]
GLASS = [(0x16, 0x2e, 0x40), (0x3a, 0x6b, 0x8c)]
HEAT = [(0x96, 0x42, 0x14), (0xff, 0xa6, 0x3c)]

# the mark and the field (Database._seed_manufacturers)
YARDS = {
    'solari': ('#ef9f27', '#3a2408'), 'probate': ('#b3924e', '#6e5a2e'),
    'redline': ('#e24b4a', '#1c2127'), 'cygnet': ('#58c8d8', '#16202e'),
    'verity': ('#8a7340', '#e8e0cc'), 'calyx': ('#3f8f6b', '#e2ece6'),
}


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(maker):
    """Five stops from the field to the mark, darkest first (ART_CONTRACT §3)."""
    mark, field = (hexrgb(c) for c in YARDS[maker])
    stops = [tuple(round(field[k] + (mark[k] - field[k]) * t / 4) for k in range(3)) for t in range(5)]
    return sorted(stops, key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])


# ---------------------------------------------------------------- the briefs
# Each block-in, in fractions of the envelope (x 0 stern .. 1 nose, y 0 top ..
# 1 bottom). `body` is the hull's profile, (x, top, bottom) points joined
# straight; the rest are parts on it. Kit lines are the thin fittings.
#   ('ell', cx, cy, rx, ry, tone)   ('rect', x0, y0, x1, y1, tone)
#   ('poly', [(x, y) ...], tone)    ('kit', [(x, y) ...])     tone: 's' steel, 'a' accent
#   ('glass', x0, y0, x1, y1)       ('band', x0, x1)          ('noz', y, h)
BRIEFS = {
 'solari': {
  'light': {'body': [(0, .5, .74), (.08, .44, .78), (.35, .40, .80), (.62, .44, .74), (.86, .54, .64), (1, .58, .60)],
            'parts': [('ell', .2, .58, .14, .26, 'a'), ('ell', .38, .48, .07, .16, 'a'), ('glass', .17, .52, .23, .62),
                      ('kit', [(.08, .40), (.14, .12)]), ('kit', [(.14, .38), (.20, .08)]), ('kit', [(.20, .36), (.26, .10)]),
                      ('kit', [(.26, .37), (.32, .16)]), ('kit', [(.62, .52), (.98, .58)]),
                      ('band', .48, .55), ('noz', .5, .12), ('noz', .68, .12)]},
  'medium': {'body': [(0, .42, .74), (.1, .36, .80), (.5, .36, .80), (.8, .40, .74), (.95, .46, .68), (1, .5, .64)],
             'parts': [('ell', .42, .56, .11, .40, 'a'), ('ell', .22, .54, .07, .26, 'a'), ('rect', .82, .36, .97, .66, 's'),
                       ('glass', .39, .5, .45, .62), ('kit', [(.12, .34), (.15, .14)]), ('kit', [(.2, .32), (.23, .1)]),
                       ('kit', [(.28, .32), (.31, .12)]), ('kit', [(.52, .32), (.55, .1)]), ('kit', [(.6, .33), (.63, .14)]),
                       ('band', .66, .72), ('noz', .5, .12), ('noz', .64, .12)]},
  'heavy': {'body': [(0, .40, .82), (.08, .34, .90), (.6, .34, .92), (.86, .40, .82), (1, .56, .66)],
            'parts': [('ell', .45, .58, .13, .36, 'a'), ('rect', .3, .2, .36, .36, 's'), ('glass', .42, .5, .48, .62),
                      ('kit', [(.22, .32), (.24, .02)]), ('kit', [(.27, .32), (.29, .0)]), ('kit', [(.4, .2), (.42, .0)]),
                      ('kit', [(.5, .2), (.52, .04)]), ('kit', [(.58, .3), (.6, .08)]), ('kit', [(.64, .32), (.66, .12)]),
                      ('band', .74, .8), ('noz', .5, .14), ('noz', .7, .14)]},
 },
 'probate': {
  'light': {'body': [(0, .46, .82), (.6, .46, .82), (.66, .36, .82), (.86, .36, .82), (1, .46, .78)],
            'parts': [('rect', .66, .22, .86, .40, 's'), ('glass', .74, .27, .80, .34), ('rect', .08, .32, .36, .48, 'a'),
                      ('rect', .4, .38, .54, .48, 's'), ('kit', [(.86, .82), (.98, .94)]), ('kit', [(.1, .32), (.1, .2)]),
                      ('kit', [(.2, .32), (.2, .2)]), ('kit', [(.3, .32), (.3, .2)]), ('band', .56, .62),
                      ('noz', .58, .14), ('noz', .74, .08)]},
  'medium': {'body': [(0, .4, .84), (.9, .4, .84), (1, .48, .78)],
             'parts': [('rect', .3, .28, .66, .42, 'a'), ('rect', .06, .2, .2, .42, 's'), ('glass', .1, .25, .16, .32),
                       ('rect', .7, .14, .76, .42, 's'), ('kit', [(.3, .26), (.64, .06)]), ('kit', [(.64, .06), (.68, .2)]),
                       ('kit', [(.36, .28), (.4, .18)]), ('band', .82, .88), ('noz', .5, .14), ('noz', .7, .12)]},
  'heavy': {'body': [(0, .42, .86), (.92, .42, .86), (1, .44, .86)],
            'parts': [('rect', .2, .3, .7, .44, 'a'), ('rect', .42, .1, .52, .44, 's'), ('glass', .44, .16, .5, .22),
                      ('poly', [(0, .36), (.18, .36), (.18, .42), (0, .42)], 's'), ('kit', [(.24, .3), (.24, .2)]),
                      ('kit', [(.34, .3), (.34, .22)]), ('kit', [(.6, .3), (.6, .18)]), ('kit', [(.47, .1), (.47, .0)]),
                      ('band', .8, .86), ('noz', .5, .1), ('noz', .64, .1), ('noz', .76, .1)]},
 },
 'redline': {
  'light': {'body': [(0, .4, .74), (.5, .42, .74), (.8, .5, .72), (1, .64, .70)],
            'parts': [('poly', [(.04, .4), (.16, .4), (.08, .12)], 's'), ('poly', [(.14, .41), (.24, .41), (.18, .18)], 's'),
                      ('rect', .56, .38, .7, .5, 's'), ('glass', .6, .41, .68, .47), ('kit', [(.08, .12), (.06, .04)]),
                      ('kit', [(.18, .18), (.17, .1)]), ('band', .38, .44), ('noz', .5, .14), ('noz', .64, .1)]},
  'medium': {'body': [(0, .22, .86), (.3, .30, .86), (.7, .46, .80), (1, .62, .70)],
             'parts': [('rect', .34, .78, .6, .9, 's'), ('glass', .7, .5, .78, .56), ('poly', [(0, .22), (.12, .22), (.04, .06)], 's'),
                       ('kit', [(.04, .06), (.02, .0)]), ('kit', [(.5, .38), (.52, .2)]), ('band', .26, .32),
                       ('noz', .34, .1), ('noz', .5, .1), ('noz', .64, .1), ('noz', .78, .08)]},
  'heavy': {'body': [(0, .28, .80), (.2, .34, .82), (.8, .42, .76), (1, .6, .66)],
            'parts': [('rect', .3, .48, .62, .58, 's'), ('glass', .82, .46, .88, .52), ('ell', .46, .4, .05, .08, 's'),
                      ('kit', [(.12, .3), (.08, .02)]), ('kit', [(.2, .33), (.16, .04)]), ('kit', [(.66, .4), (.7, .2)]),
                      ('band', .7, .76), ('noz', .44, .12), ('noz', .64, .12)]},
 },
 'cygnet': {
  'light': {'body': [(0, .46, .62), (.2, .44, .64), (.7, .44, .62), (.86, .48, .58), (1, .52, .54)],
            'parts': [('rect', .24, .36, .5, .5, 's'), ('glass', .4, .4, .46, .45), ('rect', .3, .7, .62, .76, 's'),
                      ('rect', .4, .76, .5, .86, 'a'), ('kit', [(.86, .52), (1, .5)]), ('kit', [(.6, .44), (.62, .2)]),
                      ('kit', [(.3, .64), (.3, .7)]), ('kit', [(.6, .64), (.6, .7)]), ('band', .62, .68), ('noz', .54, .12)]},
  'medium': {'body': [(0, .44, .6), (1, .5, .54)],
             'parts': [('rect', .2, .28, .7, .4, 's'), ('rect', .2, .64, .7, .76, 's'), ('rect', .26, .2, .34, .28, 'a'),
                       ('rect', .42, .2, .5, .28, 'a'), ('rect', .3, .76, .38, .86, 'a'), ('rect', .5, .76, .58, .86, 'a'),
                       ('glass', .8, .46, .88, .52), ('kit', [(.6, .2), (.66, .02)]), ('kit', [(.66, .02), (.72, .12)]),
                       ('kit', [(.76, .44), (.78, .1)]), ('kit', [(.24, .4), (.24, .44)]), ('kit', [(.66, .4), (.66, .44)]),
                       ('band', .74, .8), ('noz', .52, .1)]},
  'heavy': {'body': [(0, .3, .84), (.84, .3, .84), (1, .46, .7)],
            'parts': [('glass', .2, .52, .26, .58), ('glass', .32, .52, .38, .58), ('glass', .44, .52, .5, .58), ('glass', .56, .52, .62, .58),
                      ('rect', .84, .4, .96, .6, 's'), ('glass', .88, .44, .94, .5), ('kit', [(.1, .3), (.12, .0)]),
                      ('kit', [(.2, .3), (.21, .06)]), ('kit', [(.3, .3), (.31, .1)]), ('kit', [(.4, .3), (.41, .04)]),
                      ('kit', [(.5, .3), (.51, .12)]), ('band', .7, .76), ('noz', .44, .14), ('noz', .66, .14)]},
 },
 'verity': {
  'light': {'body': [(0, .5, .66), (.1, .46, .70), (.5, .44, .70), (.85, .48, .64), (1, .54, .58)],
            'parts': [('ell', .4, .44, .1, .04, 's'), ('glass', .7, .5, .76, .54), ('rect', .2, .56, .3, .62, 'a'),
                      ('kit', [(.46, .44), (.48, .02)]), ('kit', [(.18, .46), (.19, .18)]), ('band', .56, .6), ('noz', .58, .08)]},
  'medium': {'body': [(0, .48, .7), (.1, .44, .76), (.5, .42, .78), (.86, .46, .70), (1, .52, .62)],
             'parts': [('ell', .3, .42, .12, .04, 's'), ('ell', .62, .42, .1, .04, 's'), ('glass', .82, .5, .9, .55),
                       ('rect', .7, .56, .8, .62, 'a'), ('kit', [(.36, .42), (.38, .02)]), ('kit', [(.62, .42), (.64, .04)]),
                       ('band', .5, .55), ('noz', .56, .1)]},
  'heavy': {'body': [(0, .46, .74), (.1, .42, .82), (.5, .40, .86), (.86, .44, .76), (1, .52, .64)],
            'parts': [('ell', .28, .4, .1, .04, 's'), ('ell', .54, .4, .1, .04, 's'), ('glass', .04, .5, .1, .56),
                      ('glass', .04, .6, .1, .66), ('rect', .66, .56, .8, .62, 'a'), ('kit', [(.24, .4), (.26, .06)]),
                      ('kit', [(.46, .4), (.48, .0)]), ('kit', [(.66, .42), (.67, .12)]), ('band', .58, .63), ('noz', .56, .12)]},
 },
 'calyx': {
  'light': {'body': [(0, .5, .66), (.1, .40, .78), (.4, .32, .86), (.7, .32, .86), (.92, .40, .76), (1, .52, .62)],
            'parts': [('ell', .55, .86, .08, .08, 'a'), ('glass', .62, .52, .7, .56), ('glass', .44, .52, .52, .56),
                      ('kit', [(.55, .32), (.57, .12)]), ('kit', [(.02, .5), (0, .3)]), ('kit', [(.02, .62), (0, .82)]),
                      ('band', .3, .36)]},
  'medium': {'body': [(0, .5, .6), (.1, .40, .74), (.5, .34, .78), (.9, .40, .72), (1, .5, .6)],
             'parts': [('rect', .18, .36, .82, .42, 'a'), ('ell', .5, .8, .08, .06, 'a'), ('glass', .3, .52, .36, .56),
                       ('kit', [(.4, .34), (.42, .12)]), ('kit', [(.62, .74), (.64, .94)]), ('kit', [(.02, .52), (0, .36)]),
                       ('kit', [(.98, .52), (1, .36)]), ('band', .66, .71)]},
  'heavy': {'body': [(0, .48, .7), (.1, .38, .8), (.5, .32, .84), (.9, .38, .78), (1, .5, .64)],
            'parts': [('rect', .04, .78, .96, .86, 'a'), ('ell', .38, .88, .08, .08, 's'), ('ell', .62, .88, .08, .08, 's'),
                      ('glass', .2, .5, .24, .54), ('glass', .3, .5, .34, .54), ('glass', .4, .5, .44, .54),
                      ('kit', [(.3, .32), (.32, .1)]), ('kit', [(.5, .32), (.52, .06)]), ('kit', [(.7, .34), (.72, .12)]),
                      ('band', .78, .83)]},
 },
}


def lines_of(base):
    """HULL_LINES and HULL_EXHAUST for a base, read out of Database.gd."""
    src = open(os.path.join(ROOT, 'scripts', 'autoload', 'Database.gd')).read()
    def block(const):
        i = src.index('const %s := {' % const)
        j = src.index('\t"%s":' % base, i)
        k = src.index('\n\t', j + 1)
        end = src.index('\n\t}', j) if const == 'HULL_LINES' else src.index('\n\t]', j)
        return src[j:end]
    out = {}
    lb = block('HULL_LINES')
    for name in ('dorsal', 'ventral'):
        m = re.search(name + r' = \[(.*?)\]', lb)
        out[name] = [tuple(map(float, p)) for p in re.findall(r'Vector2\(([\d.]+), ([\d.]+)\)', m.group(1))]
    eb = block('HULL_EXHAUST')
    out['exhaust'] = [tuple(map(int, p)) for p in re.findall(r'Vector2i\((\d+), (\d+)\)', eb)]
    return out


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def block_in(maker, weight):
    base = Image.open(os.path.join(ROOT, 'art', 'sprites', 'hulls', 'korvan', BASES[weight] + '.png')).convert('RGBA')
    W, H = base.size
    x0, y0, x1, y1 = base.getbbox()
    ew, eh = x1 - x0 - 1, y1 - y0 - 1
    X = lambda f: x0 + round(f * ew)
    Y = lambda f: y0 + round(f * eh)
    brief = BRIEFS[maker][weight]
    acc = ramp(maker)
    solid = Image.new('L', (W, H), 0)      # the hull's own mask
    tone = Image.new('L', (W, H), 0)       # 0 steel, 1 accent, 2 glass, 3 gun
    d = ImageDraw.Draw(solid)
    t = ImageDraw.Draw(tone)
    body = brief['body']
    for i in range(len(body) - 1):
        a, b = body[i], body[i + 1]
        for px in range(X(a[0]), X(b[0]) + 1):
            f = 0 if X(b[0]) == X(a[0]) else (px - X(a[0])) / (X(b[0]) - X(a[0]))
            top = Y(a[1] + (b[1] - a[1]) * f)
            bot = Y(a[2] + (b[2] - a[2]) * f)
            d.line([(px, top), (px, bot)], fill=255)
    kits = []
    band = None
    for p in brief['parts']:
        k = p[0]
        if k == 'ell':
            box = [X(p[1] - p[3]), Y(p[2] - p[4]), X(p[1] + p[3]), Y(p[2] + p[4])]
            d.ellipse(box, fill=255)
            t.ellipse(box, fill=1 if p[5] == 'a' else 0)
        elif k == 'rect':
            box = [X(p[1]), Y(p[2]), X(p[3]), Y(p[4])]
            d.rectangle(box, fill=255)
            t.rectangle(box, fill=1 if p[5] == 'a' else 0)
        elif k == 'poly':
            pts = [(X(a), Y(b)) for a, b in p[1]]
            d.polygon(pts, fill=255)
            t.polygon(pts, fill=1 if p[2] == 'a' else 0)
        elif k == 'kit':
            kits.append([(X(a), Y(b)) for a, b in p[1]])
        elif k == 'band':
            band = (X(p[1]), X(p[2]))
        elif k == 'noz':
            yc, hh = Y(p[1]), max(3, round(p[2] * eh))
            box = [x0 - 2, yc - hh // 2, x0 + max(6, ew // 18), yc + hh // 2]
            d.rectangle(box, fill=255)
            t.rectangle(box, fill=3)
    if band:
        for py in range(H):
            for px in range(band[0], band[1] + 1):
                if solid.getpixel((px, py)) and tone.getpixel((px, py)) == 0:
                    tone.putpixel((px, py), 1)
    for p in brief['parts']:
        if p[0] == 'glass':
            t.rectangle([X(p[1]), Y(p[2]), X(p[3]), Y(p[4])], fill=2)
    # banded light, column by column: rim, lit top, flank, shadowed belly
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    S, T = solid.load(), tone.load()
    for px in range(W):
        ys = [py for py in range(H) if S[px, py]]
        if not ys:
            continue
        top, bot = ys[0], ys[-1]
        for py in ys:
            f = (py - top) / max(1, bot - top)
            kind = T[px, py]
            if kind == 2:
                c = GLASS[1] if py == top or not S[px, py - 1] or T[px, py - 1] != 2 else GLASS[0]
            elif kind == 3:
                c = GUN[2] if f < .3 else (GUN[1] if f < .7 else GUN[0])
            else:
                r = acc if kind == 1 else STEEL[1:]
                idx = 4 if f < .08 else (3 if f < .42 else (2 if f < .7 else (1 if f < .9 else 0)))
                c = r[min(idx, len(r) - 1)]
                if kind == 0 and py == top:
                    c = STEEL[5]
            img.putpixel((px, py), c + (255,))
    # the thin fittings: one or two pixels, lit on top
    kd = ImageDraw.Draw(img)
    for pts in kits:
        kd.line(pts, fill=STEEL[4] + (255,), width=2)
    # outline
    a = img.split()[3].load()
    out = img.copy()
    for py in range(H):
        for px in range(W):
            if a[px, py]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                qx, qy = px + dx, py + dy
                if 0 <= qx < W and 0 <= qy < H and a[qx, qy]:
                    out.putpixel((px, py), INK + (255,))
                    break
    # a warm emitter in each nozzle (the only warm light: ART_CONTRACT)
    for p in brief['parts']:
        if p[0] == 'noz':
            yc = Y(p[1])
            out.putpixel((x0, yc), HEAT[1] + (255,))
            out.putpixel((x0, yc - 1), HEAT[0] + (255,))
    return out, base, (x0, y0, x1, y1), band, brief, solid, tone


def _edges(solid, env, frac=(.18, .82)):
    """The hull's own top and bottom edge, column by column, over the middle of
    its length: where the dorsal and ventral mounts have to sit."""
    x0, y0, x1, y1 = env
    S = solid.load()
    top, bot = [], []
    for px in range(x0 + round((x1 - x0) * frac[0]), x0 + round((x1 - x0) * frac[1])):
        ys = [py for py in range(solid.height) if S[px, py]]
        if ys:
            top.append((px, ys[0]))
            bot.append((px, ys[-1]))
    return top, bot


def _registry(solid, tone, env, band):
    """A 21x7 run of plain steel in the lower flank, nearest the middle: the
    panel the number is painted on."""
    x0, y0, x1, y1 = env
    S, T = solid.load(), tone.load()
    best = None
    mid = (x0 + x1) / 2
    for py in range(y0 + (y1 - y0) // 2, y1 - 8):
        for px in range(x0 + 4, x1 - 26):
            ok = True
            for yy in range(py - 1, py + 8):
                for xx in range(px - 1, px + 22):
                    if not S[xx, yy] or T[xx, yy] != 0 or (band and band[0] - 1 <= xx <= band[1] + 1):
                        ok = False
                        break
                if not ok:
                    break
            if ok:
                d = abs(px + 10 - mid) + abs(py - (y0 + (y1 - y0) * .62)) * 2
                if best is None or d < best[0]:
                    best = (d, px, py)
    return None if best is None else (best[1], best[2])


def guide(maker, weight, tmpl, base, env, band, brief, solid, tone, k=3):
    W, H = tmpl.size
    L, R, T_, B = 70, 30, 40, 110
    g = Image.new('RGBA', (W * k + L + R, H * k + T_ + B), (14, 17, 24, 255))
    ghost = base.resize((W * k, H * k), Image.NEAREST)
    gp = ghost.load()
    for y in range(H * k):
        for x in range(W * k):
            if gp[x, y][3]:
                gp[x, y] = (60, 80, 100, 60)
    g.alpha_composite(ghost, (L, T_))
    g.alpha_composite(tmpl.resize((W * k, H * k), Image.NEAREST), (L, T_))
    d = ImageDraw.Draw(g)
    P = lambda x, y: (L + x * k, T_ + y * k)
    x0, y0, x1, y1 = env
    WHITE, ORANGE, MAG, GOLD, GREEN, CYAN, BLUE = (230, 230, 230), (255, 160, 60), (230, 90, 230), (255, 200, 80), (120, 230, 140), (110, 220, 255), (160, 160, 255)
    # envelope
    a0, a1 = P(x0, y0), P(x1, y1)
    for i in range(a0[0], a1[0], 8):
        d.line([(i, a0[1]), (i + 4, a0[1])], fill=WHITE)
        d.line([(i, a1[1]), (i + 4, a1[1])], fill=WHITE)
    for i in range(a0[1], a1[1], 8):
        d.line([(a0[0], i), (a0[0], i + 4)], fill=WHITE)
        d.line([(a1[0], i), (a1[0], i + 4)], fill=WHITE)
    # mounts, on the hull's own edges, S's count spread along each
    w_, s_, u_ = SLOTS[weight]
    top, bot = _edges(solid, env)
    for pts in (top, bot):
        d.line([P(x, y) for x, y in pts], fill=ORANGE, width=2)
    n_top = (w_ + 1 + 1) // 2
    n_bot = w_ + 1 - n_top
    for pts, n in ((top, n_top), (bot, n_bot)):
        for i in range(n):
            x, y = pts[round((i + .5) / n * (len(pts) - 1))]
            c = P(x, y)
            d.ellipse([c[0] - 5, c[1] - 5, c[0] + 5, c[1] + 5], outline=ORANGE, width=2)
    # engines: the template's own nozzles
    noz = [p for p in brief['parts'] if p[0] == 'noz']
    if noz:
        ys = [y0 + round(p[1] * (y1 - y0 - 1)) for p in noz]
        c0, c1 = P(x0 - 3, min(ys) - 6), P(x0 + 8, max(ys) + 6)
        d.rectangle([c0, c1], outline=MAG, width=2)
    # band
    if band:
        d.rectangle([P(band[0], y0 + 2), P(band[1] + 1, y1 - 2)], outline=GOLD, width=2)
    # registry
    rg = _registry(solid, tone, env, band)
    if rg:
        d.rectangle([P(rg[0], rg[1]), P(rg[0] + 21, rg[1] + 7)], outline=GREEN, width=2)
    # glass
    for p in brief['parts']:
        if p[0] == 'glass':
            e0 = P(x0 + round(p[1] * (x1 - x0 - 1)), y0 + round(p[2] * (y1 - y0 - 1)))
            e1 = P(x0 + round(p[3] * (x1 - x0 - 1)) + 1, y0 + round(p[4] * (y1 - y0 - 1)) + 1)
            d.rectangle([e0[0] - 2, e0[1] - 2, e1[0] + 2, e1[1] + 2], outline=CYAN, width=2)
    # kit
    for p in brief['parts']:
        if p[0] == 'kit':
            pts = [P(x0 + round(a * (x1 - x0 - 1)), y0 + round(b * (y1 - y0 - 1))) for a, b in p[1]]
            for q in pts:
                d.ellipse([q[0] - 3, q[1] - 3, q[0] + 3, q[1] + 3], outline=WHITE)
    # belly: the flat run the two stands take, under the middle
    mid = (x0 + x1) // 2
    span = (x1 - x0) // 5
    by = max(y for x, y in bot if mid - span <= x <= mid + span) if bot else y1
    d.line([P(mid - span, by + 3), P(mid + span, by + 3)], fill=BLUE, width=3)
    # legend
    ly = T_ + H * k + 14
    rows = [
        (WHITE, 'envelope %dx%d on a %dx%d canvas: Korvan\'s %s, so the mouth and the screens fit' % (x1 - x0, y1 - y0, W, H, BASES[weight])),
        (ORANGE, 'mounts on the top and bottom edges: room for S, %d weapons, %d systems, %d utility (C has %d/%d/%d)' % (w_ + 1, s_ + 1, u_, w_, s_, u_)),
        (MAG, 'engines at the stern, nose right: the flame is rigged to these nozzles'),
        (GOLD, 'band: one run of the manufacturer\'s colour, 40 px or more, worn at C'),
        (GREEN, 'registry: a plain panel 21x7 in one even grey (look A paints the number a fifth lighter)'),
        (CYAN, 'glass: dark panes, luma 0.2 or under, which the live lights fill'),
        (WHITE, 'kit (circled tips): fittings 3 px wide or less, stripped toward C; anything wider stays'),
        (BLUE, 'belly: flat under the middle, for the yard\'s two stands'),
    ]
    for i, (c, t) in enumerate(rows):
        d.rectangle([L, ly + i * 12 + 2, L + 8, ly + i * 12 + 10], fill=c)
        d.text((L + 14, ly + i * 12), t, fill=c)
    d.text((L, 10), '%s  %s  (%s)' % (maker.upper(), weight.upper(), 'template_%s_%s.png' % (maker, weight)), fill=WHITE)
    return g


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'hull_templates'
    makers = sys.argv[2:] or list(BRIEFS)
    os.makedirs(out, exist_ok=True)
    for m in makers:
        for w in ('light', 'medium', 'heavy'):
            tmpl, base, env, band, brief, solid, tone = block_in(m, w)
            tmpl.save(os.path.join(out, 'template_%s_%s.png' % (m, w)))
            guide(m, w, tmpl, base, env, band, brief, solid, tone).save(os.path.join(out, 'guide_%s_%s.png' % (m, w)))
            print('%s %s: canvas %dx%d, envelope %dx%d' % (m, w, tmpl.width, tmpl.height, env[2] - env[0], env[3] - env[1]))


if __name__ == '__main__':
    main()
