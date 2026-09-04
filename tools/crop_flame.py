# -*- coding: utf-8 -*-
"""Cut a plume down to the cavity it comes out of.

    python tools/crop_flame.py <src.png> <frames> <out.png> <mouth_x> <top> <bot> [apex_x]

A generated plume is a rectangle of fire. A hull's exhaust is a WEDGE cut into
the stern -- mouth at the back, apex pointing forward -- and dropping the first
into the second gives you a wall of flame wider than the ship, spilling over the
hull's own outline and stopping in a hard vertical edge somewhere inside it.

The mask is a LENS, and every number in it is measured off the hull:

    left of the mouth   NOTHING. This is open space -- there is no hull out
                        there to spill over -- and the plume art already tapers
                        the way fire does. Two shaped profiles were tried here
                        and both were worse than none: a linear taper left a thin
                        dart, and a square root still shaved the flare and the
                        wisps that sell it as thrust.
    mouth to apex       it narrows, following the recess inward, so the fire
                        PLUGS INTO the wedge instead of stopping against it.

Giving `apex_x` is what makes it a mask rather than a crop. Without it the tool
stops at the mouth, which cuts away the part inside the recess and reads as a
flame parked against the stern rather than coming out of it. The mask only ever
clears pixels, so a rigged offset stays correct after it runs.

`mouth_x`, `top`, `bot` and `apex_x` are in the FLAME's own coordinates --
subtract the rigged offset from the hull-space numbers first.
"""
import io
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt


def main():
    src, frames, out, mouth, top, bot = (
        sys.argv[1], int(sys.argv[2]), sys.argv[3],
        int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]))
    apex = int(sys.argv[7]) if len(sys.argv) > 7 else 0
    w, h, rows = pt.decode(src)
    fw = w // frames
    # Clamped to the strip: the apex is a fact about the HULL, and a plume rigged
    # further forward can run out of frame before it reaches it. That is fine --
    # the opening is still widening there -- but the output cannot be wider than
    # the source or every frame would read the next one's pixels.
    nw = min(apex + 1, fw) if apex else mouth
    cy = (top + bot) / 2.0
    half = (bot - top) / 2.0
    dst = [bytearray(nw * frames * 4) for _ in range(h)]
    kept = cut = 0
    for f in range(frames):
        for y in range(h):
            for x in range(nw):
                o = (f * fw + x) * 4
                if not rows[y][o + 3]:
                    continue
                # Untouched outboard; narrowing into the recess from the mouth
                # in. Past the apex there is no opening left, so nothing is drawn.
                if x < mouth:
                    lim = float(h)
                elif apex:
                    lim = half * float(apex - x) / float(apex - mouth)
                else:
                    lim = 0.0
                if abs(y - cy) > lim:
                    cut += 1
                    continue
                d = (f * nw + x) * 4
                dst[y][d:d + 4] = rows[y][o:o + 4]
                kept += 1
    pt.encode(out, nw * frames, h, dst)
    print("  %s -> %s" % (os.path.basename(src), os.path.basename(out)))
    print("  frames %d of %dx%d  ->  %dx%d   (%d px kept, %d cut)"
          % (frames, fw, h, nw, h, kept, cut))


if __name__ == "__main__":
    main()
