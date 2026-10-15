"""HULL TEMPLATES: one per manufacturer per weight, as starting images for the
generator (Jon, Oct 15: "make the python templates for the manufacturer
ships... then we use those as the base for pixellab").

Since Oct 14 a weight has ONE sprite and its four grades are baked onto it in
code (HullGrade), so a manufacturer's three sprites are drawn once, complete.
This writes, for each manufacturer and weight:

  template_<maker>_<weight>.png   the ship on the game's own canvas for that
                                  weight -- which is the output size, as an
                                  `init_image` must be -- for the generator to
                                  elaborate.
  guide_<maker>_<weight>.png      the template at 3x with what the code needs
                                  from the one sprite every grade shares.

    python art/tools/hull_template.py <out_dir> [maker ...]

WHY THESE ARE DETAILED. The first templates were flat shapes in four bands of
one steel, and Jon called them boring; they were. `profile_template.py` had
already measured why that matters for the generator too: "A flat template
produces a flat result at EVERY strength tested... Seams give it something to
work from: a panel edge is where rivets, wear and hatches belong." So every part
here is lit on its own (ART_CONTRACT §2: every raised object needs a
light-to-dark break), the plating is divided in the manufacturer's own rhythm,
rivets ride the seams, there are ports, hatches, fittings and materials, and
the light bands meet through ordered dithering rather than a hard edge.

THE GUIDE is measured off Korvan's base for the weight (L1, the medium A, H3),
which passes -- mounts, MouthSize and YardSeatTest:
  envelope  the base's ink box: inside it the station's mouth and the screens fit
  mounts    the hull's own top and bottom edges, with room for S's count
  engines   the template's nozzles, at the stern, nose right
  band      one run of the manufacturer's colour, 40 px or more (BAND_MIN)
  registry  a plain flank panel 21x7 in one grey (look A paints on it)
  glass     dark panes, luma 0.2 or under, for the live lights
  kit       fittings 3 px wide or less, which kit strips toward C
  belly     flat under the middle, for the yard's two stands
"""
import os, re, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
BASES = {'light': 'hull_light_c', 'medium': 'hull_medium_a', 'heavy': 'hull_heavy_a'}
# weapon / system / utility at C; A adds a weapon, S a system (DB.TIER_DELTA)
SLOTS = {'light': (2, 2, 2), 'medium': (3, 2, 2), 'heavy': (4, 2, 1)}


def hx(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def R(*hs):
    return [hx(h) for h in hs]


# Five stops dark to light, then a rim. Cold steel, ink, gun metal, glass and
# heat are the contract's own (ART_CONTRACT §3); the rest are each yard's
# materials, kept to the same value spacing.
MAT = {
    'steel': R('#131a23', '#232d3a', '#344254', '#4a5c72', '#6c8098', '#92aac4'),
    'dark': R('#0f141c', '#1a212c', '#262f3d', '#343f50', '#4a5668', '#66748a'),
    'rust': R('#24160f', '#43281a', '#643d24', '#86552f', '#a6713f', '#c08c58'),
    'olive': R('#191d14', '#2e3424', '#464e38', '#606a4e', '#7c8866', '#98a482'),
    'brick': R('#28120e', '#461f16', '#672c1e', '#874028', '#a2573a', '#b8704e'),
    'enamel': R('#3e3a32', '#6a6456', '#968e7a', '#c2b9a0', '#e2d9c2', '#f6efdd'),
    'chitin': R('#26302b', '#45524a', '#6c7a70', '#96a498', '#bfcbbd', '#dde6da'),
    'cold': R('#182636', '#283e56', '#3a5876', '#5c82a4', '#8cb6d4', '#b8dcee'),
    'gun': R('#14171d', '#1a1e26', '#2a2f39', '#3a404c', '#5c6474', '#7a8494'),
}
INK = hx('#0b0f16')
GLASS = R('#162e40', '#3a6b8c')
LIT = R('#8a5c20', '#ffc66c', '#ffe8b8')
HEAT = R('#5c280c', '#964214', '#cc641c', '#ffa63c', '#ffdca0')

# the mark and the field (Database._seed_manufacturers)
YARDS = {
    'solari': ('#ef9f27', '#3a2408'), 'probate': ('#b3924e', '#6e5a2e'),
    'redline': ('#e24b4a', '#1c2127'), 'cygnet': ('#58c8d8', '#16202e'),
    'verity': ('#8a7340', '#e8e0cc'), 'calyx': ('#3f8f6b', '#e2ece6'),
}


def accent(maker):
    """Five stops from the field to the mark, darkest first, and a rim: the
    contract's interpolated ramp. A pale field (Verity, Calyx) runs the other
    way, so the stops are sorted by lightness."""
    mark, field = (hx(c) for c in YARDS[maker])
    st = [tuple(round(field[k] + (mark[k] - field[k]) * t / 4) for k in range(3)) for t in range(5)]
    st.sort(key=lambda c: .299 * c[0] + .587 * c[1] + .114 * c[2])
    rim = tuple(min(255, v + 40) for v in st[-1])
    return st + [rim]


def lum(c):
    return (.299 * c[0] + .587 * c[1] + .114 * c[2]) / 255.0


# ---------------------------------------------------------------- the specs
#
# Fractions of the envelope: x 0 the stern .. 1 the nose, y 0 the top .. 1 the
# bottom. Parts draw in order, later on top, each lit on its own.
#   shape  ('prof', [(x, top, bottom), ...])  ('ell', cx, cy, rx, ry)
#          ('rect', x0, y0, x1, y1)  ('poly', [(x, y), ...])
#   mat    a MAT key, or 'acc' for the manufacturer's ramp
#   seams  plate width in px (vertical seams); 'slant' leans them (Redline)
#   rivets rivets along the seams and the belt
#   belt   a horizontal seam at that fraction of the part's own height
#   ports  [(y, x0, x1, n, w, h, lit)]: n panes across the part at height y,
#          `lit` of them warm (lit windows are the contract's one warm light
#          besides heat)
#   ribs   n rib arches (Calyx)          lattice  X bracing (Cygnet, Probate)
#   hatch  [(x0, y0, x1, y1)]: outlined hatches, in the part's fractions
#   greeb  n small fittings along the part's top edge
#   stripe (y, px): a horizontal run of the accent (Redline's redline)
#   band   (x0, x1): the manufacturer's band across this part
#   lens   r: a heat-lit lens at the part's centre (Solari)
#   rule   a gilt hairline under the top edge (Verity)
#   growth n rows of green growth inside (Calyx's translucent panel)
# 'kit' lines are the thin fittings kit strips: [(x, y), ...] with a bead.
# 'noz' (y, h): a bell nozzle at the stern, glowing inside.

def P(shape, mat='steel', **kw):
    d = {'shape': shape, 'mat': mat}
    d.update(kw)
    return d


def rings(x0, x1, top, bot, n):
    """Solari's reactor rings: n brass hoops clamped round the hull between x0
    and x1, standing proud of it, a hot seam glowing down each (Jon, Oct 15:
    "I just don't like the middle circles", then look A of three)."""
    out = []
    for i in range(n):
        cx = x0 + (x1 - x0) * (i + .5) / n
        out.append(P(('rect', cx - .014, top - .07, cx + .014, bot + .05), 'acc', rivets=True, belt=.5))
        out.append(P(('rect', cx - .005, top + .1, cx + .005, bot - .1), 'acc', ports=[(.1, 0, 1, 1, 2, 30, 1)]))
    return out


def crest(x0, x1, top, n):
    """Solari's radiator crest: a brass ridge along the spine over the reactor
    rings, glowing louvres in its side. It stands where the aerials stood (Jon,
    Oct 15: "the straight fins look bad", then look B)."""
    return [P(('prof', [(x0 - .02, top + .01, top + .04), (x0 + .04, top - .09, top + .04),
                        (x1 - .01, top - .09, top + .04), (x1 + .04, top + .01, top + .04)]), 'acc',
              rivets=True, ports=[(.25, .08, .92, n, 1, 4, n)])]


SPECS = {
 'solari': {
  'light': {'parts': [
     P(('prof', [(.44, .47, .65), (.8, .51, .61), (1, .55, .57)]), seams=20, rivets=True, band=(.62, .70)),
     P(('prof', [(.04, .38, .80), (.28, .34, .84), (.48, .38, .80), (.60, .45, .68)]), seams=14, rivets=True, belt=.55,
       ports=[(.32, .45, .9, 3, 3, 2, 1)], hatch=[(.6, .6, .85, .85)]),
     P(('rect', .06, .74, .48, .86), 'brick', seams=7)] + crest(.12, .44, .34, 6) + rings(.12, .44, .34, .84, 3),
   'kit': [],
   'noz': [(.50, .12), (.68, .12)]},
  'medium': {'parts': [
     P(('prof', [(0, .40, .70), (.1, .34, .78), (.5, .34, .82), (.75, .38, .78), (.9, .44, .70), (1, .50, .64)]), seams=18,
       rivets=True, belt=.48, ports=[(.3, .62, .8, 4, 3, 2, 2)], band=(.68, .74)),
     P(('poly', [(.16, .80), (.62, .80), (.55, .87), (.24, .87)]), 'brick', seams=8)] + crest(.12, .56, .34, 9) + rings(.12, .56, .34, .82, 3),
   'kit': [],
   'noz': [(.48, .12), (.64, .12)]},
  'heavy': {'parts': [
     P(('prof', [(0, .40, .74), (.08, .34, .84), (.5, .34, .92), (.78, .38, .86), (.9, .44, .76), (1, .56, .66)]), seams=20, rivets=True,
       belt=.5, ports=[(.28, .66, .84, 4, 3, 2, 2)], band=(.76, .82), hatch=[(.06, .6, .14, .8)]),
     P(('poly', [(.18, .90), (.70, .90), (.62, .96), (.28, .96)]), 'brick', seams=8),
     P(('poly', [(.92, .44), (1, .56), (1, .66), (.92, .70)]), 'gun')] + crest(.26, .62, .34, 9) + rings(.26, .62, .34, .92, 4),
   'kit': [],
   'noz': [(.50, .14), (.72, .14)]},
 },
 'probate': {
  'light': {'parts': [
     P(('rect', .02, .42, .38, .84), 'olive', seams=11, rivets=True, belt=.5),
     P(('rect', .36, .46, .66, .84), 'steel', seams=16, rivets=True, belt=.4, band=(.48, .62)),
     P(('rect', .64, .22, .88, .84), 'rust', seams=12, rivets=True, ports=[(.2, .2, .8, 2, 4, 3, 1)], hatch=[(.2, .5, .7, .9)]),
     P(('poly', [(.86, .34), (1, .48), (1, .80), (.86, .84)]), 'steel', seams=5),
     P(('rect', .06, .30, .32, .44), 'olive', lattice=True),
     P(('rect', .42, .38, .56, .48), 'gun', greeb=3)],
   'kit': [[(.86, .84), (.95, .93), (.99, .88)], [(.70, .22), (.70, .08)], [(.80, .22), (.82, .12)],
           [(.1, .30), (.1, .18)], [(.2, .30), (.2, .2)], [(.3, .30), (.3, .18)]],
   'noz': [(.56, .14), (.74, .08)]},
  'medium': {'parts': [
     P(('rect', 0, .42, .90, .86), 'steel', seams=22, rivets=True, belt=.45, ports=[(.7, .3, .7, 5, 3, 2, 1)], band=(.78, .86)),
     P(('rect', 0, .36, .24, .86), 'olive', seams=9, rivets=True),
     P(('poly', [(.86, .38), (1, .50), (1, .78), (.86, .86)]), 'rust', seams=6, rivets=True),
     P(('poly', [(.30, .42), (.33, .30), (.42, .26), (.52, .30), (.60, .27), (.66, .34), (.68, .42)]), 'rust', greeb=9),
     P(('rect', .26, .20, .72, .24), 'steel', lattice=True),
     P(('rect', .04, .18, .20, .40), 'steel', seams=8, ports=[(.35, .15, .85, 2, 4, 3, 1)]),
     P(('rect', .72, .10, .78, .42), 'rust', seams=4, lens=2)],
   'kit': [[(.30, .26), (.64, .06)], [(.64, .06), (.68, .20)], [(.27, .24), (.27, .42)], [(.71, .24), (.71, .42)],
           [(.12, .18), (.12, .06)]],
   'noz': [(.50, .14), (.72, .12)]},
  'heavy': {'parts': [
     P(('rect', .18, .42, .94, .88), 'steel', seams=24, rivets=True, belt=.5, ports=[(.28, .26, .9, 7, 3, 2, 2)], band=(.80, .86)),
     P(('rect', .92, .40, 1, .90), 'olive', seams=3, rivets=True),
     P(('poly', [(0, .34), (.20, .34), (.22, .88), (0, .88)]), 'rust', seams=8, rivets=True, belt=.5),
     P(('rect', .24, .32, .36, .42), 'olive', seams=5, greeb=2), P(('rect', .36, .30, .44, .42), 'rust', greeb=2),
     P(('rect', .56, .32, .70, .42), 'olive', seams=6, greeb=3),
     P(('rect', .44, .12, .54, .42), 'steel', seams=5, rivets=True, ports=[(.25, .2, .8, 2, 3, 3, 2)], lens=2),
     P(('rect', .30, .86, .70, .92), 'gun', seams=10)],
   'kit': [[(.24, .32), (.24, .2)], [(.34, .32), (.34, .22)], [(.62, .32), (.62, .18)], [(.47, .12), (.47, .0)],
           [(.51, .12), (.52, .04)]],
   'noz': [(.48, .1), (.60, .08), (.70, .1), (.80, .08)]},
 },
 'redline': {
  'light': {'parts': [
     P(('prof', [(0, .36, .74), (.3, .40, .76), (.7, .48, .74), (1, .63, .69)]), 'steel', seams=16, slant=.5, stripe=(.6, 2),
       band=(.32, .40), hatch=[(.12, .5, .28, .8)]),
     P(('poly', [(0, .36), (.14, .36), (.05, .06)]), 'dark', seams=6, slant=.6),
     P(('poly', [(.12, .38), (.24, .38), (.16, .16)]), 'rust'),
     P(('rect', .40, .74, .58, .82), 'dark', seams=6),
     P(('poly', [(.55, .44), (.70, .40), (.80, .48), (.60, .50)]), 'dark', ports=[(.4, .1, .9, 1, 12, 3, 0)])],
   'kit': [[(.05, .06), (.03, .0)], [(.16, .16), (.15, .08)], [(.80, .58), (.98, .62)]],
   'noz': [(.50, .14), (.64, .1)]},
  'medium': {'parts': [
     P(('prof', [(0, .18, .86), (.3, .26, .88), (.7, .44, .82), (1, .62, .70)]), 'steel', seams=20, slant=.5, stripe=(.72, 3),
       ports=[(.3, .55, .85, 3, 3, 2, 1)], band=(.22, .30), hatch=[(.08, .3, .2, .6)]),
     P(('rect', .30, .80, .62, .92), 'rust', seams=8, rivets=True),
     P(('rect', .42, .40, .54, .62), 'olive', seams=6),
     P(('poly', [(0, .18), (.13, .18), (.04, .02)]), 'dark', seams=5, slant=.6),
     P(('poly', [(.78, .46), (.92, .52), (.96, .58), (.80, .56)]), 'dark', ports=[(.4, .1, .8, 1, 14, 3, 0)])],
   'kit': [[(.04, .02), (.02, .0)], [(.50, .36), (.53, .16)], [(.94, .60), (1.0, .64)]],
   'noz': [(.30, .1), (.46, .1), (.62, .1), (.76, .08)]},
  'heavy': {'parts': [
     P(('prof', [(0, .26, .80), (.15, .32, .82), (.8, .42, .74), (1, .60, .64)]), 'steel', seams=24, slant=.5, stripe=(.58, 3),
       ports=[(.25, .2, .7, 6, 3, 2, 0)], band=(.70, .76), hatch=[(.25, .55, .4, .85), (.45, .55, .6, .85)]),
     P(('ell', .46, .40, .05, .07), 'dark', lens=0),
     P(('poly', [(0, .26), (.12, .26), (.04, .06)]), 'dark', seams=5, slant=.6),
     P(('poly', [(.82, .44), (.94, .52), (.84, .54)]), 'dark', ports=[(.4, .1, .8, 1, 10, 3, 0)]),
     P(('rect', .5, .74, .66, .80), 'rust', seams=5)],
   'kit': [[(.10, .30), (.07, .0)], [(.18, .32), (.15, .04)], [(.66, .40), (.70, .2)], [(.95, .6), (1.0, .62)]],
   'noz': [(.42, .12), (.62, .12)]},
 },
 'cygnet': {
  'light': {'parts': [
     P(('rect', 0, .47, .86, .56), 'cold', seams=9, rivets=True, band=(.66, .76)),
     P(('ell', .36, .47, .17, .11), 'cold', seams=8, belt=.5, ports=[(.35, .2, .8, 3, 2, 2, 1)]),
     P(('poly', [(.84, .46), (1, .515), (.84, .57)]), 'steel'),
     P(('rect', .26, .66, .66, .70), 'steel', lattice=True),
     P(('ell', .46, .76, .06, .055), 'acc', lens=1), P(('ell', .58, .76, .045, .045), 'acc'),
     P(('ell', .52, .38, .05, .05), 'steel', ports=[(.4, .3, .7, 1, 2, 2, 1)])],
   'kit': [[(.30, .56), (.30, .66)], [(.42, .56), (.42, .66)], [(.54, .56), (.54, .66)], [(.62, .56), (.62, .66)],
           [(.62, .47), (.64, .10)], [(.58, .22), (.70, .22)], [(.86, .50), (1.0, .49)]],
   'noz': [(.51, .12)]},
  'medium': {'parts': [
     P(('rect', 0, .46, .9, .55), 'cold', seams=10, rivets=True),
     P(('rect', .16, .31, .70, .36), 'steel', lattice=True), P(('rect', .16, .64, .70, .69), 'steel', lattice=True),
     P(('ell', .24, .25, .045, .05), 'acc'), P(('ell', .36, .25, .045, .05), 'acc'), P(('ell', .48, .25, .045, .05), 'acc'),
     P(('ell', .60, .25, .045, .05), 'acc'),
     P(('ell', .28, .75, .045, .05), 'acc'), P(('ell', .44, .75, .045, .05), 'acc'), P(('ell', .58, .75, .045, .05), 'acc'),
     P(('ell', .88, .50, .10, .14), 'cold', seams=8, belt=.5, ports=[(.3, .4, .9, 2, 3, 2, 1)], band=(.84, .92)),
     P(('poly', [(.70, .26), (.76, .10), (.82, .26), (.76, .30)]), 'steel')],
   'kit': [[(.2, .36), (.2, .46)], [(.4, .36), (.4, .46)], [(.6, .36), (.6, .46)], [(.2, .55), (.2, .64)],
           [(.4, .55), (.4, .64)], [(.6, .55), (.6, .64)], [(.76, .30), (.76, .46)], [(.66, .46), (.68, .04)],
           [(.62, .14), (.72, .14)]],
   'noz': [(.50, .1)]},
  'heavy': {'parts': [
     P(('rect', 0, .32, .86, .84), 'cold', seams=22, rivets=True, belt=.5,
       ports=[(.25, .06, .80, 7, 6, 4, 0), (.65, .06, .80, 7, 8, 6, 3)], band=(.74, .80)),
     P(('rect', .84, .40, 1, .70), 'steel', seams=6, ports=[(.3, .2, .8, 2, 4, 3, 2)]),
     P(('rect', .10, .26, .70, .32), 'steel', greeb=10),
     P(('ell', .22, .89, .03, .04), 'acc'), P(('ell', .40, .89, .03, .04), 'acc'), P(('ell', .58, .89, .03, .04), 'acc')],
   'kit': [[(.12, .26), (.13, .0)], [(.18, .26), (.19, .08)], [(.26, .26), (.27, .02)], [(.34, .26), (.35, .1)],
           [(.42, .26), (.43, .04)], [(.50, .26), (.51, .12)], [(.58, .26), (.59, .06)], [(.66, .26), (.67, .14)],
           [(.22, .84), (.22, .86)], [(.40, .84), (.40, .86)], [(.58, .84), (.58, .86)]],
   'noz': [(.44, .14), (.66, .14)]},
 },
 'verity': {
  'light': {'parts': [
     P(('prof', [(0, .52, .66), (.08, .46, .72), (.5, .42, .72), (.86, .46, .66), (1, .54, .58)]), 'enamel', rule=True, belt=.6,
       ports=[(.42, .08, .26, 3, 2, 2, 3), (.42, .62, .80, 2, 3, 2, 0)], band=(.54, .60)),
     P(('ell', .40, .42, .10, .045), 'enamel'),
     P(('rect', .24, .56, .32, .62), 'acc', rivets=True)],
   'kit': [[(.46, .42), (.47, .02)], [(.40, .14), (.53, .14)], [(.18, .46), (.185, .16)], [(.15, .26), (.22, .26)]],
   'noz': [(.58, .08)]},
  'medium': {'parts': [
     P(('prof', [(0, .48, .70), (.1, .44, .76), (.5, .42, .78), (.86, .46, .70), (1, .52, .62)]), 'enamel', rule=True, belt=.62,
       ports=[(.45, .04, .18, 4, 2, 2, 4), (.45, .70, .84, 3, 3, 2, 0)], band=(.48, .53),
       hatch=[(.22, .55, .34, .7)]),
     P(('ell', .30, .42, .12, .04), 'enamel', ports=[(.5, .2, .8, 3, 3, 1, 0)]),
     P(('ell', .64, .42, .10, .04), 'enamel', ports=[(.5, .2, .8, 2, 3, 1, 0)]),
     P(('rect', .72, .58, .82, .64), 'acc', rivets=True)],
   'kit': [[(.36, .42), (.38, .02)], [(.30, .12), (.46, .12)], [(.62, .42), (.64, .04)], [(.57, .16), (.71, .16)]],
   'noz': [(.56, .1)]},
  'heavy': {'parts': [
     P(('prof', [(0, .46, .74), (.1, .42, .82), (.5, .40, .86), (.86, .44, .76), (1, .52, .64)]), 'enamel', rule=True, belt=.6,
       ports=[(.36, .02, .12, 3, 3, 2, 3), (.56, .02, .12, 3, 3, 2, 3), (.4, .74, .86, 3, 3, 2, 0)], band=(.58, .63),
       hatch=[(.2, .55, .3, .72), (.36, .55, .46, .72)]),
     P(('ell', .28, .40, .10, .04), 'enamel', ports=[(.5, .2, .8, 3, 3, 1, 0)]),
     P(('ell', .52, .40, .10, .04), 'enamel', ports=[(.5, .2, .8, 3, 3, 1, 0)]),
     P(('rect', .66, .58, .80, .64), 'acc', rivets=True)],
   'kit': [[(.24, .40), (.26, .06)], [(.19, .14), (.33, .14)], [(.46, .40), (.48, .0)], [(.40, .10), (.56, .10)],
           [(.66, .42), (.67, .12)], [(.62, .20), (.72, .20)]],
   'noz': [(.56, .12)]},
 },
 'calyx': {
  'light': {'parts': [
     P(('ell', .52, .58, .46, .28), 'chitin', ribs=7, ports=[(.5, .45, .7, 2, 4, 1, 0)], band=(.26, .33)),
     P(('ell', .55, .88, .08, .07), 'acc', lens=2),
     P(('ell', .05, .40, .04, .06), 'acc'), P(('ell', .02, .52, .03, .05), 'acc'), P(('ell', .02, .64, .03, .05), 'acc'),
     P(('ell', .05, .76, .04, .06), 'acc')],
   'kit': [[(.56, .30), (.58, .08)], [(.40, .32), (.41, .2)], [(.70, .32), (.71, .2)]],
   'noz': [(.58, .1)]},
  'medium': {'parts': [
     P(('prof', [(0, .50, .60), (.1, .40, .74), (.5, .34, .78), (.9, .40, .72), (1, .50, .60)]), 'chitin', ribs=10,
       ports=[(.55, .3, .7, 3, 4, 1, 0)], band=(.66, .71)),
     P(('rect', .18, .36, .82, .44), 'acc', growth=2),
     P(('ell', .50, .80, .08, .06), 'acc', lens=2),
     P(('ell', .03, .44, .03, .05), 'acc'), P(('ell', .03, .66, .03, .05), 'acc'),
     P(('ell', .97, .44, .03, .05), 'acc'), P(('ell', .97, .66, .03, .05), 'acc')],
   'kit': [[(.40, .34), (.42, .12)], [(.62, .74), (.64, .94)], [(.24, .35), (.25, .2)], [(.76, .36), (.77, .22)]],
   'noz': [(.55, .08)]},
  'heavy': {'parts': [
     P(('prof', [(0, .48, .70), (.1, .38, .80), (.5, .32, .84), (.9, .38, .78), (1, .50, .64)]), 'chitin', ribs=14,
       ports=[(.5, .16, .5, 4, 3, 1, 0)], band=(.78, .83)),
     P(('rect', .04, .76, .96, .84), 'acc', ribs=20, growth=1),
     P(('ell', .38, .88, .08, .08), 'chitin', ribs=3, lens=2), P(('ell', .62, .88, .08, .08), 'chitin', ribs=3, lens=2),
     P(('ell', .04, .58, .03, .14), 'acc', ribs=3)],
   'kit': [[(.30, .32), (.32, .1)], [(.50, .32), (.52, .04)], [(.70, .34), (.72, .12)], [(.40, .33), (.41, .2)],
           [(.60, .33), (.61, .2)]],
   'noz': [(.56, .1)]},
 },
}


def lines_of(base):
    """HULL_EXHAUST for a base, read out of Database.gd (for reference)."""
    src = open(os.path.join(ROOT, 'scripts', 'autoload', 'Database.gd')).read()
    i = src.index('const HULL_EXHAUST := {')
    j = src.index('\t"%s":' % base, i)
    end = src.index('\n\t]', j)
    return [tuple(map(int, p)) for p in re.findall(r'Vector2i\((\d+), (\d+)\)', src[j:end])]


# ---------------------------------------------------------------- the renderer

def _shade(r, f, x, y):
    """A ramp stop for a point `f` down a part (0 top, 1 bottom), dithered where
    two bands meet (ordered, a checkerboard: ART_CONTRACT §2)."""
    edges = [.10, .30, .56, .80]
    idx = 4 if f < edges[0] else (3 if f < edges[1] else (2 if f < edges[2] else (1 if f < edges[3] else 0)))
    for k, e in enumerate(edges):
        if abs(f - e) < .035 and (x + y) % 2:
            idx = 4 - k if f >= e else 3 - k
            break
    return r[max(0, min(4, idx))]


def render(maker, weight):
    base = Image.open(os.path.join(ROOT, 'art', 'sprites', 'hulls', 'korvan', BASES[weight] + '.png')).convert('RGBA')
    W, H = base.size
    x0, y0, x1, y1 = base.getbbox()
    ew, eh = x1 - x0 - 1, y1 - y0 - 1
    X = lambda f: x0 + round(f * ew)
    Y = lambda f: y0 + round(f * eh)
    spec = SPECS[maker][weight]
    acc = accent(maker)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    solid = Image.new('L', (W, H), 0)
    tone = Image.new('L', (W, H), 0)          # 0 plain hull plate (registry may go here)
    px, sp, tp = img.load(), solid.load(), tone.load()
    marks = {'glass': [], 'kit': [], 'noz': [], 'band': None}

    def mask_of(shape):
        m = Image.new('L', (W, H), 0)
        d = ImageDraw.Draw(m)
        k = shape[0]
        if k == 'prof':
            pts = shape[1]
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]
                for cx in range(X(a[0]), X(b[0]) + 1):
                    t = 0 if X(b[0]) == X(a[0]) else (cx - X(a[0])) / (X(b[0]) - X(a[0]))
                    d.line([(cx, Y(a[1] + (b[1] - a[1]) * t)), (cx, Y(a[2] + (b[2] - a[2]) * t))], fill=255)
        elif k == 'ell':
            d.ellipse([X(shape[1] - shape[3]), Y(shape[2] - shape[4]), X(shape[1] + shape[3]), Y(shape[2] + shape[4])], fill=255)
        elif k == 'rect':
            d.rectangle([X(shape[1]), Y(shape[2]), X(shape[3]), Y(shape[4])], fill=255)
        elif k == 'poly':
            d.polygon([(X(a), Y(b)) for a, b in shape[1]], fill=255)
        return m

    for part in spec['parts']:
        m = mask_of(part['shape'])
        mp = m.load()
        bb = m.getbbox()
        if not bb:
            continue
        bx0, by0, bx1, by1 = bb
        r = acc if part['mat'] == 'acc' else MAT[part['mat']]
        hull_plate = part['mat'] in ('steel', 'dark', 'olive', 'rust', 'enamel', 'chitin', 'cold')
        # fill, lit column by column on the part's own extent
        cols = {}
        for cx in range(bx0, bx1):
            ys = [cy for cy in range(by0, by1) if mp[cx, cy]]
            if ys:
                cols[cx] = (ys[0], ys[-1])
        for cx, (t, b) in cols.items():
            for cy in range(t, b + 1):
                f = (cy - t) / max(1, b - t)
                c = r[5] if cy == t else _shade(r, f, cx, cy)
                px[cx, cy] = c + (255,)
                sp[cx, cy] = 255
                tp[cx, cy] = 0 if hull_plate else 3
        # the band, across this part
        if part.get('band'):
            ba, bb_ = X(part['band'][0]), X(part['band'][1])
            marks['band'] = (ba, bb_)
            for cx in range(max(ba, bx0), min(bb_, bx1 - 1) + 1):
                if cx not in cols:
                    continue
                t, b = cols[cx]
                for cy in range(t, b + 1):
                    f = (cy - t) / max(1, b - t)
                    px[cx, cy] = (acc[5] if cy == t else _shade(acc, f, cx, cy)) + (255,)
                    tp[cx, cy] = 1
        # seams: a dark line with a lit edge beside it, rivets along them
        seam = part.get('seams')
        if seam:
            sl = part.get('slant', 0)
            for sx in range(bx0 + seam, bx1 - 2, seam):
                for cy in range(by0, by1):
                    cx = sx + round((cy - by0) * sl * 0.4)
                    if cx in cols and cols[cx][0] < cy < cols[cx][1] and mp[cx, cy]:
                        c = px[cx, cy][:3]
                        px[cx, cy] = _darker(r, c) + (255,)
                        if cx + 1 in cols and mp[cx + 1, cy]:
                            px[cx + 1, cy] = _lighter(r, px[cx + 1, cy][:3]) + (255,)
                        tp[cx, cy] = 3
                        if part.get('rivets') and (cy - by0) % 4 == 2 and cx - 2 in cols and mp[cx - 2, cy]:
                            px[cx - 2, cy] = r[5] + (255,)
                            tp[cx - 2, cy] = 3
        # a belt line across the part
        if part.get('belt'):
            for cx, (t, b) in cols.items():
                cy = t + round((b - t) * part['belt'])
                if t < cy < b:
                    px[cx, cy] = _darker(r, px[cx, cy][:3]) + (255,)
                    if cy + 1 <= b:
                        px[cx, cy + 1] = _lighter(r, px[cx, cy + 1][:3]) + (255,)
                    tp[cx, cy] = tp[cx, cy + 1] = 3
                    if part.get('rivets') and cx % 5 == 0 and cy - 2 > t:
                        px[cx, cy - 2] = r[5] + (255,)
        # a gilt hairline under the top edge (Verity)
        if part.get('rule'):
            for cx, (t, b) in cols.items():
                if t + 2 < b:
                    px[cx, t + 2] = acc[4] + (255,)
                    tp[cx, t + 2] = 3
        # a horizontal run of the accent (Redline)
        if part.get('stripe'):
            sy, sh = part['stripe']
            for cx, (t, b) in cols.items():
                cy0 = t + round((b - t) * sy)
                for cy in range(cy0, cy0 + sh):
                    if t < cy < b:
                        px[cx, cy] = (acc[4] if cy == cy0 else acc[2]) + (255,)
                        tp[cx, cy] = 1
        # rib arches (Calyx): dark curves up the part, lit behind
        if part.get('ribs'):
            n = part['ribs']
            for i in range(1, n + 1):
                rx = bx0 + round((bx1 - bx0) * i / (n + 1))
                for cy in range(by0, by1):
                    if rx not in cols:
                        continue
                    t, b = cols[rx]
                    if not (t < cy < b):
                        continue
                    f = (cy - t) / max(1, b - t)
                    cx = rx + round((f - .5) ** 2 * 6) - 1
                    if cx in cols and mp[cx, cy]:
                        px[cx, cy] = _darker(r, px[cx, cy][:3]) + (255,)
                        if cx - 1 in cols and mp[cx - 1, cy]:
                            px[cx - 1, cy] = _lighter(r, px[cx - 1, cy][:3]) + (255,)
                        tp[cx, cy] = 3
        # X bracing (Cygnet, Probate's bins, Solari's cages)
        if part.get('lattice'):
            for cx, (t, b) in cols.items():
                for cy in range(t + 1, b):
                    if (cx - cy) % 6 == 0 or (cx + cy) % 6 == 0:
                        px[cx, cy] = _darker(r, px[cx, cy][:3]) + (255,)
                        tp[cx, cy] = 3
        # green growth in rows (Calyx's translucent panel)
        if part.get('growth'):
            for cx, (t, b) in cols.items():
                for k in range(part['growth']):
                    cy = t + 1 + round((b - t - 2) * (k + 1) / (part['growth'] + 1))
                    if (cx // 2) % 2 == 0 and t < cy < b:
                        px[cx, cy] = hx('#9ad48a') + (255,)
        # hatches
        for hb in part.get('hatch', []):
            ha, hb_ = bx0 + round((bx1 - bx0) * hb[0]), bx0 + round((bx1 - bx0) * hb[2])
            hc, hd = by0 + round((by1 - by0) * hb[1]), by0 + round((by1 - by0) * hb[3])
            for cx in range(ha, hb_ + 1):
                for cy in (hc, hd):
                    if mp[cx, cy]:
                        px[cx, cy] = _darker(r, px[cx, cy][:3]) + (255,)
                        tp[cx, cy] = 3
            for cy in range(hc, hd + 1):
                for cx in (ha, hb_):
                    if mp[cx, cy]:
                        px[cx, cy] = _darker(r, px[cx, cy][:3]) + (255,)
                        tp[cx, cy] = 3
        # ports: dark glass, some lit warm
        for (py, pa, pb, n, w, h, lit) in part.get('ports', []):
            cy = by0 + round((by1 - by0) * py)
            for i in range(n):
                cx = bx0 + round((bx1 - bx0) * (pa + (pb - pa) * (i + .5) / n)) - w // 2
                on = i < lit
                for yy in range(cy, cy + h):
                    for xx in range(cx, cx + w):
                        if mp[xx, yy]:
                            if on:
                                px[xx, yy] = (LIT[2] if yy == cy else LIT[1]) + (255,)
                            else:
                                px[xx, yy] = (GLASS[1] if yy == cy else GLASS[0]) + (255,)
                            tp[xx, yy] = 2
                if not on:
                    marks['glass'].append((cx, cy, cx + w - 1, cy + h - 1))
        # small fittings along the part's top edge
        g = part.get('greeb', 0)
        for i in range(g):
            cx = bx0 + round((bx1 - bx0) * (i + .5) / g)
            if cx not in cols:
                continue
            t = cols[cx][0]
            gw, gh = 2 + (i * 7) % 3, 2 + (i * 5) % 3
            for yy in range(t - gh, t):
                for xx in range(cx, cx + gw):
                    if 0 <= yy < H:
                        px[xx, yy] = (MAT['gun'][4] if yy == t - gh else MAT['gun'][2]) + (255,)
                        sp[xx, yy] = 255
                        tp[xx, yy] = 3
        # a heat-lit lens (Solari): the contract's warm light, from inside
        if part.get('lens'):
            lr = part['lens']
            cx, cy = (bx0 + bx1) // 2, (by0 + by1) // 2
            for yy in range(cy - lr, cy + lr + 1):
                for xx in range(cx - lr, cx + lr + 1):
                    dd = ((xx - cx) ** 2 + (yy - cy) ** 2) ** .5
                    if dd <= lr + .3:
                        px[xx, yy] = (HEAT[4] if dd < lr * .35 else (HEAT[3] if dd < lr * .7 else HEAT[2])) + (255,)
                        tp[xx, yy] = 3
            if lr >= 2:
                for a in range(-lr - 1, lr + 2):
                    for (xx, yy) in ((cx + a, cy - lr - 1), (cx + a, cy + lr + 1), (cx - lr - 1, cy + a), (cx + lr + 1, cy + a)):
                        if mp[xx, yy] and abs(a) <= lr:
                            px[xx, yy] = _darker(r, px[xx, yy][:3]) + (255,)
        # the part's own edge, a recess where it meets what is behind it
        for cx, (t, b) in cols.items():
            for cy in range(t, b + 1):
                edge = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1)):
                    if not mp[cx + dx, cy + dy] if 0 <= cx + dx < W and 0 <= cy + dy < H else True:
                        edge = True
                if edge and cy != t and sp[cx, cy]:
                    px[cx, cy] = r[0] + (255,)

    # nozzles: bells at the stern, warm inside
    for (ny, nh) in spec.get('noz', []):
        cy, hh = Y(ny), max(4, round(nh * eh))
        bw = max(5, ew // 22)
        for i in range(bw):
            half = hh // 2 + (bw - i) // 3
            for yy in range(cy - half, cy + half + 1):
                xx = x0 - 2 + i
                f = (yy - (cy - half)) / max(1, 2 * half)
                c = MAT['gun'][5] if yy == cy - half else _shade(MAT['gun'], f, xx, yy)
                if i == 0 and abs(yy - cy) < half - 1:
                    c = HEAT[3] if abs(yy - cy) < half // 2 else HEAT[1]
                px[xx, yy] = c + (255,)
                sp[xx, yy] = 255
                tp[xx, yy] = 3
        marks['noz'].append(cy)

    # the thin fittings: two pixels, lit on top, a bead at the tip
    d = ImageDraw.Draw(img)
    for line in spec.get('kit', []):
        pts = [(X(a), Y(b)) for a, b in line]
        d.line(pts, fill=MAT['steel'][3] + (255,), width=2)
        d.line([(p[0], p[1]) for p in pts], fill=MAT['steel'][5] + (255,), width=1)
        tx, ty = pts[-1]
        d.rectangle([tx - 1, ty - 1, tx, ty], fill=MAT['steel'][5] + (255,))
        marks['kit'].append(pts[-1])
    sp2 = img.split()[3].load()
    for yy in range(H):
        for xx in range(W):
            if sp2[xx, yy]:
                sp[xx, yy] = 255 if sp[xx, yy] else sp[xx, yy]

    # the silhouette's outline, in ink
    out = img.copy()
    a = img.split()[3].load()
    o = out.load()
    for yy in range(H):
        for xx in range(W):
            if a[xx, yy]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                qx, qy = xx + dx, yy + dy
                if 0 <= qx < W and 0 <= qy < H and a[qx, qy]:
                    o[xx, yy] = INK + (255,)
                    break
    return out, base, (x0, y0, x1, y1), marks, solid, tone


def _darker(r, c):
    i = min(range(len(r)), key=lambda k: sum((r[k][j] - c[j]) ** 2 for j in range(3)))
    return r[max(0, i - 2)]


def _lighter(r, c):
    i = min(range(len(r)), key=lambda k: sum((r[k][j] - c[j]) ** 2 for j in range(3)))
    return r[min(5, i + 1)]


# ---------------------------------------------------------------- the guide

def _edges(solid, env, frac=(.18, .82)):
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
    """A 21x7 run of plain hull plate in the lower flank, nearest the middle."""
    x0, y0, x1, y1 = env
    S, T = solid.load(), tone.load()
    best = None
    mid = (x0 + x1) / 2
    for py in range(y0 + (y1 - y0) // 3, y1 - 8):
        for px in range(x0 + 4, x1 - 26):
            ok = True
            for yy in range(py, py + 7):
                for xx in range(px, px + 21):
                    if not S[xx, yy] or T[xx, yy] != 0:
                        ok = False
                        break
                if not ok:
                    break
            if ok:
                dd = abs(px + 10 - mid) + abs(py - (y0 + (y1 - y0) * .62)) * 2
                if best is None or dd < best[0]:
                    best = (dd, px, py)
    return None if best is None else (best[1], best[2])


def guide(maker, weight, tmpl, base, env, marks, solid, tone, k=3):
    W, H = tmpl.size
    L, R_, T_, B = 70, 30, 40, 110
    g = Image.new('RGBA', (W * k + L + R_, H * k + T_ + B), (14, 17, 24, 255))
    ghost = base.resize((W * k, H * k), Image.NEAREST)
    gp = ghost.load()
    for y in range(H * k):
        for x in range(W * k):
            if gp[x, y][3]:
                gp[x, y] = (60, 80, 100, 50)
    g.alpha_composite(ghost, (L, T_))
    g.alpha_composite(tmpl.resize((W * k, H * k), Image.NEAREST), (L, T_))
    d = ImageDraw.Draw(g)
    Pt = lambda x, y: (L + x * k, T_ + y * k)
    x0, y0, x1, y1 = env
    WHITE, ORANGE, MAG, GOLD, GREEN, CYAN, BLUE = (230, 230, 230), (255, 160, 60), (230, 90, 230), (255, 200, 80), (120, 230, 140), (110, 220, 255), (160, 160, 255)
    a0, a1 = Pt(x0, y0), Pt(x1, y1)
    for i in range(a0[0], a1[0], 8):
        d.line([(i, a0[1]), (i + 4, a0[1])], fill=WHITE)
        d.line([(i, a1[1]), (i + 4, a1[1])], fill=WHITE)
    for i in range(a0[1], a1[1], 8):
        d.line([(a0[0], i), (a0[0], i + 4)], fill=WHITE)
        d.line([(a1[0], i), (a1[0], i + 4)], fill=WHITE)
    w_, s_, u_ = SLOTS[weight]
    top, bot = _edges(solid, env)
    for pts in (top, bot):
        if len(pts) > 1:
            d.line([Pt(x, y) for x, y in pts], fill=ORANGE, width=1)
    n_top = (w_ + 2) // 2
    n_bot = w_ + 1 - n_top
    for pts, n in ((top, n_top), (bot, n_bot)):
        for i in range(n):
            if pts:
                x, y = pts[round((i + .5) / n * (len(pts) - 1))]
                c = Pt(x, y)
                d.ellipse([c[0] - 5, c[1] - 5, c[0] + 5, c[1] + 5], outline=ORANGE, width=2)
    if marks['noz']:
        c0, c1 = Pt(x0 - 4, min(marks['noz']) - 6), Pt(x0 + 6, max(marks['noz']) + 6)
        d.rectangle([c0, c1], outline=MAG, width=2)
    if marks['band']:
        d.rectangle([Pt(marks['band'][0], y0 + 2), Pt(marks['band'][1] + 1, y1 - 2)], outline=GOLD, width=2)
    rg = _registry(solid, tone, env, marks['band'])
    if rg:
        d.rectangle([Pt(rg[0], rg[1]), Pt(rg[0] + 21, rg[1] + 7)], outline=GREEN, width=2)
    for (ga, gb, gc, gd) in marks['glass']:
        e0, e1 = Pt(ga, gb), Pt(gc + 1, gd + 1)
        d.rectangle([e0[0] - 2, e0[1] - 2, e1[0] + 2, e1[1] + 2], outline=CYAN, width=1)
    for (tx, ty) in marks['kit']:
        q = Pt(tx, ty)
        d.ellipse([q[0] - 4, q[1] - 4, q[0] + 4, q[1] + 4], outline=WHITE)
    mid = (x0 + x1) // 2
    span = (x1 - x0) // 5
    under = [y for x, y in bot if mid - span <= x <= mid + span]
    by = max(under) if under else y1
    d.line([Pt(mid - span, by + 3), Pt(mid + span, by + 3)], fill=BLUE, width=3)
    ly = T_ + H * k + 14
    rows = [
        (WHITE, 'envelope %dx%d on a %dx%d canvas: Korvan\'s %s, so the mouth and the screens fit' % (x1 - x0, y1 - y0, W, H, BASES[weight])),
        (ORANGE, 'mounts on the top and bottom edges: room for S, %d weapons, %d systems, %d utility (C has %d/%d/%d)' % (w_ + 1, s_ + 1, u_, w_, s_, u_)),
        (MAG, 'engines at the stern, nose right: the flame is rigged to these nozzles'),
        (GOLD, 'band: one run of the manufacturer\'s colour, 40 px or more, worn at C'),
        (GREEN, 'registry: a plain panel 21x7 in one even grey (look A paints the number a fifth lighter)' + ('' if rg else ' -- NONE FOUND: leave one')),
        (CYAN, 'glass: dark panes, luma 0.2 or under, which the live lights fill'),
        (WHITE, 'kit (circled tips): fittings 3 px wide or less, stripped toward C; anything wider stays'),
        (BLUE, 'belly: flat under the middle, for the yard\'s two stands'),
    ]
    for i, (c, t) in enumerate(rows):
        d.rectangle([L, ly + i * 12 + 2, L + 8, ly + i * 12 + 10], fill=c)
        d.text((L + 14, ly + i * 12), t, fill=c)
    d.text((L, 10), '%s  %s  (template_%s_%s.png)' % (maker.upper(), weight.upper(), maker, weight), fill=WHITE)
    return g


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'hull_templates'
    makers = sys.argv[2:] or list(SPECS)
    os.makedirs(out, exist_ok=True)
    for m in makers:
        for w in ('light', 'medium', 'heavy'):
            tmpl, base, env, marks, solid, tone = render(m, w)
            tmpl.save(os.path.join(out, 'template_%s_%s.png' % (m, w)))
            guide(m, w, tmpl, base, env, marks, solid, tone).save(os.path.join(out, 'guide_%s_%s.png' % (m, w)))
            print('%s %s: canvas %dx%d, %d colours' % (m, w, tmpl.width, tmpl.height, len(set(tmpl.getdata()))))


if __name__ == '__main__':
    main()
