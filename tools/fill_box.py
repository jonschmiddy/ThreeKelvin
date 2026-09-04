# -*- coding: utf-8 -*-
"""Widen a module sprite until it spans its box, without resampling it.

    python tools/fill_box.py <sprite.png> <box_w> [out.png]

A generated sprite sits in the middle of its canvas with a margin either side.
`ModuleIcon` CENTRES a sprite in its box and never stretches it -- "the box is a
guide, not a frame" -- so that margin is drawn as empty space and the part reads
as floating in its cell. km4, which is hand-authored, spans its box 0 to 59.

SCALING IS NOT AN OPTION. Pixel art scaled by a non-integer factor is mush, and
the whole reduction path exists to avoid exactly that.

So this DUPLICATES COLUMNS instead. It repeatedly finds the column that differs
least from its right-hand neighbour -- a run of barrel, a flat stretch of
housing -- and inserts a copy of it. Repeating a column that already equals its
neighbour is invisible: the shape grows, every pixel stays where the generator
put it, and nothing is interpolated.

Only the WIDTH is filled. km4 is 11 rows tall in a 20-row box, so height is the
subject's business; a gun stretched to fill its height vertically would just be
a fatter gun.
"""
import io
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt


def content(w, h, rows):
    xs = [x for x in range(w) if any(rows[y][x * 4 + 3] for y in range(h))]
    ys = [y for y in range(h) if any(rows[y][x * 4 + 3] for x in range(w))]
    return (xs[0], xs[-1], ys[0], ys[-1]) if xs else (0, -1, 0, -1)


def col(rows, h, x):
    return b"".join(bytes(rows[y][x * 4:x * 4 + 4]) for y in range(h))


def cost(rows, h, a, b):
    """How different two columns are. Transparent-vs-opaque is expensive, so a
    silhouette edge is never chosen as the place to repeat."""
    ca, cb = col(rows, h, a), col(rows, h, b)
    n = 0
    for i in range(0, len(ca), 4):
        aa, ab = ca[i + 3], cb[i + 3]
        if (aa > 8) != (ab > 8):
            n += 400
            continue
        if aa <= 8:
            continue
        n += sum(abs(ca[i + k] - cb[i + k]) for k in range(3))
    return n


def widen(w, h, rows, want):
    x0, x1, _, _ = content(w, h, rows)
    have = x1 - x0 + 1
    need = want - have
    if need <= 0:
        return w, h, rows, 0
    body = [[bytearray(rows[y][x * 4:x * 4 + 4]) for y in range(h)]
            for x in range(x0, x1 + 1)]
    for _ in range(need):
        n = len(body)
        best, at = None, 1
        for i in range(n - 1):
            c = 0
            for y in range(h):
                a, b = body[i][y], body[i + 1][y]
                if (a[3] > 8) != (b[3] > 8):
                    c += 400
                elif a[3] > 8:
                    c += abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])
            if best is None or c < best:
                best, at = c, i
        body.insert(at, [bytearray(px) for px in body[at]])
    out = [bytearray(want * 4) for _ in range(h)]
    for i, c in enumerate(body):
        for y in range(h):
            out[y][i * 4:i * 4 + 4] = c[y]
    return want, h, out, need


def main():
    src = sys.argv[1]
    want = int(sys.argv[2])
    dst = sys.argv[3] if len(sys.argv) > 3 else src
    w, h, rows = pt.decode(src)
    x0, x1, y0, y1 = content(w, h, rows)
    nw, nh, out, added = widen(w, h, rows, want)
    pt.encode(dst, nw, nh, out)
    print("  %s: content %dx%d in %dx%d -> %d columns duplicated -> spans %d of %d"
          % (os.path.basename(src), x1 - x0 + 1, y1 - y0 + 1, w, h, added, nw, want))


if __name__ == "__main__":
    main()
