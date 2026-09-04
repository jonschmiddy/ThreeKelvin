# -*- coding: utf-8 -*-
"""Cut the needle off a hull's bow and cap it flat.

    python tools/blunt_bow.py [--keep 0.5] [--write]

WHY THIS IS OFFLINE. The generator will not draw a blunt prow. Measured, on
heavy hulls at 320x140: four separate promptings failed --

    "a flat squared-off prow: a blunt vertical armoured face, chisel-like"
    "cut off square ... as if the tip had been sawn off"
    "a thick square-fronted ram block ... like the head of a hammer"
    "squared off flat like the Pillar of Autumn"

-- and so did img2img over an accepted hull at strength 220 and 150. Every one
came back with a point. The prior is too strong to argue with, and each attempt
costs generations and drifts the rest of the sprite off what was already
approved.

Truncation is exact, free, and reversible. The taper the generator draws is
wanted right up until the last stretch, so the fix is to stop it early: find the
bow, walk in until the hull is thick enough to read as a prow, drop everything
beyond, and close the cut with the ship's own outline colour. Every pixel in the
result was drawn by the generator; nothing is invented.
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


def columns(w, h, rows):
    """Opaque pixels per column -- the hull's thickness along its length."""
    return [sum(1 for y in range(h) if rows[y][x * 4 + 3]) for x in range(w)]


def outline_colour(w, h, rows):
    """The darkest colour the ship already uses on its own silhouette edge.

    Sampled rather than chosen, so the cap belongs to the sprite. Ties go to
    whichever is most common, which is the outline the generator drew.
    """
    edge = Counter()
    for y in range(h):
        for x in range(w):
            o = x * 4
            if not rows[y][o + 3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or rows[ny][nx * 4 + 3] == 0:
                    edge[(rows[y][o], rows[y][o + 1], rows[y][o + 2])] += 1
                    break
    if not edge:
        return (26, 18, 18)
    dark = sorted(edge.items(), key=lambda kv: (sum(kv[0]), -kv[1]))
    return dark[0][0]


def bevel(w, h, rows, cut, d, depth):
    """Chamfer the prow's corners so the hull runs INTO the face at an angle.

    A straight vertical slice reads as damage -- the ship looks sawn through,
    which is exactly the complaint. On a real armoured prow the top and bottom
    surfaces fall away through short angled facets and meet a face that is
    smaller than the hull is deep. That is a 45-degree bevel on the two front
    corners, and it is the whole difference between a chisel and a cut.
    """
    gone = 0
    for i in range(depth):
        x = cut - i * d
        if not (0 <= x < w):
            break
        take = depth - 1 - i
        if take <= 0:
            continue
        ys = [y for y in range(h) if rows[y][x * 4 + 3]]
        if not ys:
            continue
        for y in ys[:take] + ys[-take:]:
            if rows[y][x * 4 + 3]:
                rows[y][x * 4 + 3] = 0
                gone += 1
    return gone


def blunt(w, h, rows, keep=0.5, chamfer=6):
    """Truncate the bow at `keep` of the hull's thickest column. Returns (cut, side).

    The bow is the thin end: whichever half carries less of the ship. That is
    read off the sprite rather than assumed, because orientation is the
    generator's to decide and it does not always agree with `direction`.
    """
    col = columns(w, h, rows)
    body = [c for c in col if c]
    if not body:
        return 0, ""
    peak = max(col)
    left = sum(col[:w // 2])
    right = sum(col[w // 2:])
    bow_right = right < left

    want = peak * keep
    if bow_right:
        rng = range(w - 1, -1, -1)
    else:
        rng = range(w)
    cut = None
    for x in rng:
        if col[x] >= want:
            cut = x
            break
    if cut is None:
        return 0, ""

    gone = 0
    dead = range(cut + 1, w) if bow_right else range(0, cut)
    for x in dead:
        for y in range(h):
            if rows[y][x * 4 + 3]:
                rows[y][x * 4 + 3] = 0
                gone += 1
    if not gone:
        return 0, "right" if bow_right else "left"

    d = 1 if bow_right else -1
    if chamfer:
        gone += bevel(w, h, rows, cut, d, chamfer)

    # Close the cut: the exposed column becomes the prow's front face.
    r, g, b = outline_colour(w, h, rows)
    for y in range(h):
        o = cut * 4
        if rows[y][o + 3]:
            rows[y][o] = r
            rows[y][o + 1] = g
            rows[y][o + 2] = b
    return gone, "right" if bow_right else "left"


def main():
    keep = 0.5
    chamfer = 6
    write = "--write" in sys.argv
    if "--keep" in sys.argv:
        keep = float(sys.argv[sys.argv.index("--keep") + 1])
    if "--chamfer" in sys.argv:
        chamfer = int(sys.argv[sys.argv.index("--chamfer") + 1])
    sides = Counter()
    tot = 0
    n = 0
    for p in sorted(glob.glob(os.path.join(DIR, "*.png"))):
        w, h, rows = pt.decode(p)
        gone, side = blunt(w, h, rows, keep, chamfer)
        sides[side] += 1
        tot += gone
        n += 1
        if write and gone:
            pt.encode(p, w, h, rows)
    print("  keep %.2f chamfer %d -> %d hulls, %d pixels off the bows, bow side %s"
          % (keep, chamfer, n, tot, dict(sides)))
    if not write:
        print("  (dry run -- pass --write to keep it)")


if __name__ == "__main__":
    main()
