# -*- coding: utf-8 -*-
"""Push a hull's steel toward blue without touching its amber.

    python tools/recolour.py <in.png> <out.png> [amount]

The generator's greys are close to neutral. Cooling them is a palette job, not
a generation job: the ship is already the one that was chosen, and regenerating
to change a hue throws away the shape along with it.

Each pixel is blended toward a blue-tinted grey OF ITS OWN BRIGHTNESS, so the
shading survives -- a flat hue rotation would crush the light and dark plates
together. The amber band is held out by the same warm test the bench uses,
because the band is the manufacturer's one point of colour and the entire
reason the palette reads at all.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt

# Where a cooled grey lands, per channel, as a multiple of its own brightness.
# Blue up, red down, green nearly still -- the same direction as the blue-grey
# the prompt asks for rather than a wash of saturated colour.
COOL = (0.88, 0.97, 1.18)


def warm(r, g, b):
    """The amber band, and anything else deliberately warm. Left alone."""
    return r > 130 and b < 130 and r - b > 55 and g > 70


def cool(path, out, amount=0.5):
    w, h, rows = pt.decode(path)
    touched = held = 0
    for y in range(h):
        row = rows[y]
        for x in range(w):
            o = x * 4
            if not row[o + 3]:
                continue
            r, g, b = row[o], row[o + 1], row[o + 2]
            if warm(r, g, b):
                held += 1
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            for i, k in enumerate(COOL):
                want = lum * k
                v = row[o + i] + (want - row[o + i]) * amount
                row[o + i] = 0 if v < 0 else (255 if v > 255 else int(v + 0.5))
            touched += 1
    pt.encode(out, w, h, rows)
    return touched, held


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    amt = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    t, k = cool(src, dst, amt)
    print("  %s  amount %.2f  cooled %d px, held %d amber px" % (dst, amt, t, k))
