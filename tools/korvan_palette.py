# -*- coding: utf-8 -*-
"""Force generated hulls onto the Korvan palette.

    python tools/korvan_palette.py [--write]

WHY. Round 2's hulls had a warm bone-grey that reads as one manufacturer's
paint. The hulls generated since are cold blue-white, and that is NOT a
vocabulary problem -- both prompts say the same words, "weathered grey-white
armour". It comes from the init image: the silhouette seed is a cold Pro-model
hull, and at init_image_strength 90 pixflux inherits its palette along with its
shape.

Arguing with that in the prompt would be paying generations for something an
exact operation does for free. `pixeltools.snap` forces every pixel onto a fixed
palette, and its own docstring says the point: snapping to an APPROVED sprite's
palette keeps an approved look approved.

So the tone is decided once, here, off a hull that was actually liked -- and
every hull in every future batch lands on it. Colour consistency across the
fleet stops being something to hope the generator repeats and becomes something
the pipeline guarantees.

MEASURED: snapping moves 10k-19k pixels of a 320x140 hull, and costs nothing in
shape or detail -- only hue.
"""
import glob
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt

DIR = os.environ.get("HULL_DIR") or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "out", "hull_candidates")
# The palette now comes from the EIGHT hulls that were actually chosen -- the
# ranked light and medium S/A/B/C -- rather than one hull from round 2. One
# sprite cannot carry the whole family's tone, and these eight are the family.
_HERE = os.path.dirname(os.path.abspath(__file__))
SOURCES = [os.path.join(_HERE, "out", "pool", "light", "s192_%s.png" % n)
           for n in ("09", "22", "03", "25")] +           [os.path.join(_HERE, "out", "pool", "medium", "m260_%s.png" % n)
           for n in ("15", "09", "05", "10")]
if os.environ.get("KORVAN_PALETTE_SOURCE"):
    SOURCES = os.environ["KORVAN_PALETTE_SOURCE"].split(os.pathsep)
SOURCE = SOURCES[0]
SIZE = 32


def accent(t):
    """Is this one of the amber pixels? Warm, and clearly not a grey.

    SATURATION, NOT BRIGHTNESS. The first version of this asked `r > 140`, which
    is a question about how lit a pixel is rather than what colour it is. The
    band's shadowed side sits at (120, 75, 56) -- unmistakably amber, and 308 of
    the 1,286 amber pixels on heavy_12_belt -- so it failed the gate, got snapped
    to the nearest grey, and the stripe vanished from every shaded plate. 75% of
    the band was going that way.

    A hue test survives shading. Amber here means the channels fall r > g > b and
    the colour is far enough from grey to be paint rather than warm steel: the
    hull's bone plating sits at (193, 186, 167), only 13% saturated, and stays
    out. 0.45 sits in the gap between that and the darkest real amber.
    """
    r, g, b = t
    mx, mn = max(t), min(t)
    if mx < 40:                      # near black; no hue worth trusting
        return False
    return r > g > b and (mx - mn) / float(mx) >= 0.45


def palette(paths=None, size=SIZE):
    """The Korvan paint, read off an approved hull rather than invented.

    THE ACCENT IS ADDED EXPLICITLY, and that is not fussiness. Taking simply the
    `size` most common colours destroys the amber: the stripe is only ~147
    pixels on a hull of 45,000, so on the round-two source it ranks TWENTY-SIXTH
    of 34 -- just outside a top-24 cut. Snapping to that palette moves every
    amber pixel to the nearest grey and the ship loses the one mark that makes
    it Korvan.

    Frequency is the wrong test for an accent. Rarity is the whole point of one.
    So the greys come from the ranking and the amber is unioned in whatever its
    rank.
    """
    if paths is None:
        paths = SOURCES
    if isinstance(paths, str):
        paths = [paths]
    c = Counter()
    for path in paths:
        w, h, rows = pt.decode(path)
        for y in range(h):
            for x in range(w):
                o = x * 4
                if rows[y][o + 3]:
                    c[(rows[y][o], rows[y][o + 1], rows[y][o + 2])] += 1
    base = [k for k, _ in c.most_common(size)]
    ambers = [k for k, _ in c.most_common() if accent(k)]
    for a in ambers:
        if a not in base:
            base.append(a)
    return base


def main():
    write = "--write" in sys.argv
    pal = palette()
    n_acc = sum(1 for c in pal if accent(c))
    print("  palette of %d off %s, %d of them accent"
          % (len(pal), os.path.basename(SOURCE), n_acc))
    if not n_acc:
        print("  WARNING: no accent colour found -- the amber will be lost")
    tot = n = 0
    for p in sorted(glob.glob(os.path.join(DIR, "*.png"))):
        w, h, rows = pt.decode(p)
        moved = pt.snap(w, h, rows, pal)
        tot += moved
        n += 1
        if write:
            pt.encode(p, w, h, rows)
    print("  %d hulls, %d pixels recoloured (%d each)"
          % (n, tot, tot // max(n, 1)))
    if not write:
        print("  (dry run -- pass --write to keep it)")


if __name__ == "__main__":
    main()
