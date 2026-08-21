"""Measure each hull's dorsal and ventral lines, for mounting things on.

Not a list of anchor POINTS. A hull carries between one and five mounts of a
kind depending on its weight, its class and who built it, and a fixed list of
five points used two-at-a-time clusters both of them at one end of the ship.
The LINE is the durable fact; how many mounts sit on it is the ship's business,
and spreading N along a polyline is three lines of runtime code.

The usable span excludes the nose and the engine block. Both taper, so a mount
placed there hangs in space beside the hull rather than on it — the test is the
hull's own thickness at that column, which is what `DEEP` is measuring.
"""

import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt

SPRITES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites")

# A column counts as hull rather than nose-taper or nozzle when it is at least
# this fraction of the deepest column. 0.45 keeps the flat middle and drops the
# wedge; measured by eye against all twelve and it is not a close call on any.
DEEP = 0.45

# How many points to sample each line at. Enough that a curve reads as a curve
# when four mounts are spread along it, few enough to be legible in the data.
SAMPLES = 9


def profile(w, h, rows):
    """Topmost and bottommost opaque y for every column that has any."""
    top, bot = {}, {}
    for x in range(w):
        ys = [y for y in range(h) if rows[y][x * 4 + 3]]
        if ys:
            top[x], bot[x] = ys[0], ys[-1]
    return top, bot


# A row counts as part of the hull BODY when this fraction of the span's columns
# are opaque at it. Tail fins and wings are tall and narrow — they occupy a few
# columns each — so they fall below this and the band ignores them.
BODY = 0.55


def body_band(w, h, rows, x0, x1):
    """The y range the hull itself occupies, excluding fins and wings.

    Measured because the naive answer is wrong in a way that looks right in the
    numbers: the topmost opaque pixel of a winged hull is the TAIL FIN, so a
    mount placed on the top profile hangs off a wingtip a third of the way up
    the frame with clear space between it and the ship.
    """
    cols = float(max(1, x1 - x0 + 1))
    rowsy = []
    for y in range(h):
        n = sum(1 for x in range(x0, x1 + 1) if rows[y][x * 4 + 3])
        if n / cols >= BODY:
            rowsy.append(y)
    if not rowsy:
        return 0, h - 1
    return rowsy[0], rowsy[-1]


def lines(path):
    w, h, rows = pt.decode(path)
    top, bot = profile(w, h, rows)
    if not top:
        return None
    depth = {x: bot[x] - top[x] + 1 for x in top}
    deepest = max(depth.values())
    solid = sorted(x for x in depth if depth[x] >= deepest * DEEP)
    if len(solid) < 2:
        return None
    x0, x1 = solid[0], solid[-1]
    by0, by1 = body_band(w, h, rows, x0, x1)
    dorsal, ventral, flank = [], [], []
    for i in range(SAMPLES):
        x = int(round(x0 + (x1 - x0) * i / float(SAMPLES - 1)))
        # Clamp onto a column that actually has hull, in case the span has a
        # gap in it (a slot cut clean through, which some hulls do have).
        while x not in top and x < x1:
            x += 1
        # Clamped INTO the body band, so a column whose silhouette is mostly
        # fin still reports the spine.
        dorsal.append((x, max(top[x], by0)))
        ventral.append((x, min(bot[x], by1)))
        flank.append((x, (max(top[x], by0) + min(bot[x], by1)) // 2))
    return {"canvas": (w, h), "span": (x0, x1), "deepest": deepest,
            "body": (by0, by1),
            "dorsal": dorsal, "ventral": ventral, "flank": flank}


def main():
    out = {}
    names = []
    for weight in ("light", "medium", "heavy"):
        for cls in ("c", "b", "a", "s"):
            names.append("hull_%s_%s" % (weight, cls))
    for n in names:
        p = os.path.join(SPRITES, n + ".png")
        r = lines(p)
        if r is None:
            print("  %-18s NO HULL FOUND" % n)
            continue
        out[n] = r
        print("  %-18s canvas %3dx%-3d  span x%3d..%-3d  body y%3d..%-3d  deepest %3dpx"
              % (n, r["canvas"][0], r["canvas"][1], r["span"][0], r["span"][1],
                 r["body"][0], r["body"][1], r["deepest"]))
    here = os.path.dirname(os.path.abspath(__file__))
    io.open(os.path.join(here, "anchors.json"), "w", encoding="utf-8").write(
        json.dumps(out, indent=1))
    print("\nwrote anchors.json (%d hulls)" % len(out))


if __name__ == "__main__":
    main()
