# -*- coding: utf-8 -*-
"""Repaint hulls onto the Korvan palette without letting steel become paint.

    python tools/match_palette.py <in_dir> <out_dir> [target_luma]

Two steps, both exact:

1. SCALE the greys to the family's brightness. The heavies came out of the
   generator around luma 95-103 against 74 for the ranked lights and mediums --
   a third brighter, and neutral where the family is cool. Scaling every channel
   by one factor preserves the saturation ratio exactly, so this changes value
   and nothing else.

2. SNAP to the palette read off the approved hulls, SPLIT IN TWO. Greys may only
   land on greys and amber may only land on amber.

WHY THE SPLIT. A single palette lets the nearest-colour search cross the line in
both directions, and both directions are wrong. Snapping amber to grey deletes
the band -- that is what a brightness-based accent test used to do to the whole
shadowed side of the stripe. Snapping grey to amber is subtler and worse: it
tints the steel. On n_15 an unsplit snap turned 638 grey pixels amber, a sixfold
increase in the band, without looking obviously wrong at 1x.

Keeping the two sets apart makes both impossible rather than unlikely.
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import korvan_palette as kp
import pixeltools as pt

TARGET_LUMA = 74.0          # measured off the ranked light and medium S/A/B/C


def luma(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b


def grey_profile(w, h, rows):
    """Mean luma and blue-minus-red of the NON-amber pixels."""
    n = lum = bd = 0
    for y in range(h):
        for x in range(w):
            o = x * 4
            if not rows[y][o + 3]:
                continue
            c = (rows[y][o], rows[y][o + 1], rows[y][o + 2])
            if kp.accent(c):
                continue
            lum += luma(*c)
            bd += c[2] - c[0]
            n += 1
    return (lum / n, bd / float(n), n) if n else (0.0, 0.0, 0)


def match(path, out, pal_grey, pal_amber, target=TARGET_LUMA):
    w, h, rows = pt.decode(path)
    L, _, n = grey_profile(w, h, rows)
    if not n:
        return 0, 0
    k = target / L
    moved = amber = 0
    cache = {}
    for y in range(h):
        for x in range(w):
            o = x * 4
            if not rows[y][o + 3]:
                continue
            c = (rows[y][o], rows[y][o + 1], rows[y][o + 2])
            hot = kp.accent(c)
            if not hot:
                c = tuple(min(255, max(0, int(v * k + 0.5))) for v in c)
            pool = pal_amber if hot else pal_grey
            if c not in cache:
                cache[c] = min(pool, key=lambda p: (c[0] - p[0]) ** 2
                               + (c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2)
            new = cache[c]
            if new != (rows[y][o], rows[y][o + 1], rows[y][o + 2]):
                moved += 1
            rows[y][o], rows[y][o + 1], rows[y][o + 2] = new
            if hot:
                amber += 1
    pt.encode(out, w, h, rows)
    return moved, amber


def main():
    src = sys.argv[1]
    dst = sys.argv[2]
    target = float(sys.argv[3]) if len(sys.argv) > 3 else TARGET_LUMA
    pal = kp.palette()
    pal_amber = [c for c in pal if kp.accent(c)]
    pal_grey = [c for c in pal if not kp.accent(c)]
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    os.makedirs(dst)
    print("  palette: %d grey, %d amber" % (len(pal_grey), len(pal_amber)))
    for n in sorted(os.listdir(src)):
        if not n.lower().endswith(".png"):
            continue
        p = os.path.join(src, n)
        w, h, rows = pt.decode(p)
        L0, B0, _ = grey_profile(w, h, rows)
        a0 = sum(1 for y in range(h) for x in range(w)
                 if rows[y][x * 4 + 3]
                 and kp.accent((rows[y][x * 4], rows[y][x * 4 + 1], rows[y][x * 4 + 2])))
        moved, a1 = match(p, os.path.join(dst, n), pal_grey, pal_amber, target)
        w, h, rows = pt.decode(os.path.join(dst, n))
        L1, B1, _ = grey_profile(w, h, rows)
        print("  %-20s luma %5.1f->%5.1f  b-r %+5.1f->%+5.1f  amber %4d->%4d  %5d moved"
              % (n[:-4], L0, L1, B0, B1, a0, a1, moved))


if __name__ == "__main__":
    main()
