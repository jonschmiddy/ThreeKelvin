# -*- coding: utf-8 -*-
"""Hand edits to individual hulls, written down so they survive a rebuild.

    python tools/hull_edits.py [src] [dst]
        src defaults to tools/out/heavy_raw -- pristine, never written
        dst defaults to tools/out/heavy_final -- rebuilt from src every run

A generated hull is nearly right and then has one wrong pixel cluster on it.
Fixing that in an image editor loses the fix the moment the sprite is
regenerated or repainted, and leaves no record of what was changed or why. Each
edit here is a named region and an operation, so re-running the whole pipeline
reproduces them exactly.

Edits are applied to a PRISTINE SOURCE and written elsewhere, never in place.
That is what makes repeated runs safe, and it is not fussiness: the amber boost
multiplies brightness, so run against its own output it climbs further every
time. Two earlier versions of this file drifted the art -- one by re-trimming
after an erase, which moved the origin so the next run cut into the hull, and
one by re-boosting an already-boosted readout. Neither is possible now.
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import korvan_palette as kp
import pixeltools as pt

LIGHT = 45.0          # above this luma a pixel is a mark, below it is the recess


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def erase(w, h, rows, x0, y0, x1, y1):
    """Clear a box. Used to remove a protrusion that reads as an accident."""
    n = 0
    for y in range(max(0, y0), min(h, y1 + 1)):
        for x in range(max(0, x0), min(w, x1 + 1)):
            o = x * 4
            if rows[y][o + 3]:
                rows[y][o + 3] = 0
                n += 1
    return n


def amberise(w, h, rows, x0, y0, x1, y1, ambers, boost=1.0):
    """Make the lit marks in a recess amber, and optionally brighter.

    A pixel qualifies if it is already amber OR is light enough to be a mark
    rather than the recess it sits in. Both are needed: the first pass here only
    converted the greys and left the readout's own dark amber alone, which is
    why it still read as half-lit.

    Each qualifying pixel is matched to the amber whose brightness is closest to
    its own times `boost`, so the glyphs keep their relative shading instead of
    flattening to one colour. The ramp runs luma 44 to 209, and matching clamps
    at the top rather than overflowing.
    """
    n = 0
    for y in range(max(0, y0), min(h, y1 + 1)):
        for x in range(max(0, x0), min(w, x1 + 1)):
            o = x * 4
            if not rows[y][o + 3]:
                continue
            c = (rows[y][o], rows[y][o + 1], rows[y][o + 2])
            if luma(c) < LIGHT and not kp.accent(c):
                continue
            want = luma(c) * boost
            best = min(ambers, key=lambda a: abs(luma(a) - want))
            if best != c:
                n += 1
            rows[y][o], rows[y][o + 1], rows[y][o + 2] = best
    return n


# name -> list of (op, x0, y0, x1, y1, [boost,] why)
EDITS = {
    "heavy_18": [
        # y81 was where the spike stopped being a separate blob, but its base
        # carried on to y85 as a wedge sitting on top of the outermost engine
        # bell. The hull's own edge here is x12, so x0-11 is all spike.
        ("erase", 0, 73, 11, 85,
         "a thin 45-degree spike off the top of the engine, attached to nothing"),
    ],
    # heavy_12_belt's readout is NOT edited here any more. Jon repainted it by
    # hand -- filling the whole recess with two mid ambers rather than lighting
    # the glyphs and leaving the recess dark, which is what my `amber` op did.
    # His version is baked into tools/out/heavy_raw/heavy_12_belt.png, so an
    # edit here would run straight over it. Left as a comment rather than
    # deleted so nobody re-adds it wondering why the hull has no entry.
}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "out", "heavy_raw")
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "out", "heavy_final")
    ambers = [c for c in kp.palette() if kp.accent(c)]
    if not os.path.isdir(dst):
        os.makedirs(dst)
    # Everything is rebuilt from the pristine art every run. Editing in place
    # cannot work for an operation that is not its own fixed point: the amber
    # boost multiplies brightness, so applied to its own output it climbs a
    # little further each time and the art drifts. Reading from a source that is
    # never written makes every edit reproducible whatever it does.
    for n in sorted(os.listdir(src)):
        if n.lower().endswith(".png"):
            shutil.copyfile(os.path.join(src, n), os.path.join(dst, n))
    for name, edits in sorted(EDITS.items()):
        p = os.path.join(dst, name + ".png")
        if not os.path.isfile(p):
            print("  %-18s not here, skipped" % name)
            continue
        w, h, rows = pt.decode(p)
        for e in edits:
            op, x0, y0, x1, y1 = e[:5]
            why = e[-1]
            if op == "erase":
                n = erase(w, h, rows, x0, y0, x1, y1)
                what = "erased %d px" % n
            else:
                n = amberise(w, h, rows, x0, y0, x1, y1, ambers, e[5])
                what = "recoloured %d px" % n
            print("  %-18s %-18s  %s" % (name, what, why))
        # DO NOT re-trim here. An erase at the edge shrinks the bounding box, and
        # cropping to it moves the origin -- after which every coordinate in
        # EDITS points one pixel into the hull and a second run eats real art.
        # That is exactly what happened: the first run trimmed 295 to 294 wide
        # and the second erased two pixels of engine. The canvas keeps its size
        # and the transparent margin; whatever consumes these trims anyway.
        pt.encode(p, w, h, rows)


if __name__ == "__main__":
    main()
