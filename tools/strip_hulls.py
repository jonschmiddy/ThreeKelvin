# -*- coding: utf-8 -*-
"""Strip the background off every downloaded hull candidate, once.

Two steps: flood the background away, then drop anything left that is not
connected to the ship (see pixeltools.despeckle).

Run straight after fetch_hulls.sh. Idempotent by measurement rather than by
flag: a sprite that is already mostly transparent is left alone, so this can be
called repeatedly while the rest of a batch is still generating.

WHY creep, and why 45. The white borders on the first batch were not PixelLab's
doing -- the originals carry no rim at all. Read across the boundary of
heavy_03_deck the background runs 233,234,234 -> 230,229,232 -> 225,223,226 and
then jumps straight to the ship's dark outline at 43,36,34. That is a near-white
gradient in small steps, and a flood keeping only what sits within 14 of the
SEED cannot reach the last band: 225,223,226 is 27 away from the corner. It
survives, one pixel thick, all the way round, and reads as a white halo.

`creep` lets the flood walk that gradient by comparing each pixel to the
neighbour it was reached from. It is safe to set high here because these hulls
carry a dark outline the whole way round -- the pale bone deck plating never
touches the background directly, so the flood always meets a jump of ~560
before it can reach anything belonging to the ship.

MEASURED over the 30 stripped hulls, total light pixels left against the
transparency:

    creep   18      45     110
    rim   4517     396     500     <- 45 clears 91% of what 18 leaves
    hull     -    -568   -8584     <- 110 breaks through and eats heavy_06

45 sits in the flat part of that curve. 110 is past the point where a thin
outline somewhere gives way and the flood pours into the hull.
"""
import glob
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt

DIR = os.environ.get("HULL_DIR") or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "out", "hull_candidates")
CREEP = 45


def rim(w, h, rows):
    """Light pixels sitting against transparency -- the halo, if there is one."""
    n = 0
    for y in range(h):
        for x in range(w):
            o = x * 4
            if not rows[y][o + 3]:
                continue
            if rows[y][o] < 196 or rows[y][o + 1] < 196 or rows[y][o + 2] < 196:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and rows[ny][nx * 4 + 3] == 0:
                    n += 1
                    break
    return n


def main():
    done = skip = 0
    worst = []
    speckled = []
    broken = []
    eased = []
    for p in sorted(glob.glob(os.path.join(DIR, "*.png"))):
        w, h, rows = pt.decode(p)
        # "Already stripped" means MOSTLY transparent. On a full generation
        # canvas a finished hull runs 73-88% transparent and an unstripped one
        # runs near 0, so 20 sat well inside the range of images that still need
        # work. 60 is comfortably between the two populations.
        #
        # This does NOT rescue every background. h3_02 came back as a ship drawn
        # on a solid grey RECTANGLE with transparency outside it: the flood
        # clears the outside, stops dead at the rectangle's hard edge, and the
        # sprite sits at 28% either way. A drawn frame is a failed generation,
        # not a strip this tool can fix -- cut it at the bench.
        if pt.alpha_pct(w, h, rows) > 60.0:
            skip += 1
            continue
        # 45 is right for a sprite that arrived with a transparent background.
        # When one does not -- hv_02 came back fully opaque -- a creep that high
        # floods straight through the ship and shatters it. Step down until the
        # result is one ship again rather than a hundred fragments.
        for creep in (CREEP, 30, 18, 12, 6, 0):
            w, h, rows = pt.decode(p)
            pt.strip_bg(w, h, rows, creep=creep)
            ps = pt.pieces(w, h, rows)
            tot = float(sum(len(q) for q in ps)) or 1.0
            if len(ps[0]) / tot >= 0.80:
                break
        if creep != CREEP:
            eased.append((creep, os.path.basename(p)))
        # Whatever the flood could not reach, plus any lettering the model
        # invented off to one side, is not the ship. Left in place it survives
        # every later measurement: light_02 came out 398 deep against a real
        # ship of 174, because a caption sat above it.
        loose, suspect = pt.despeckle(w, h, rows)
        if loose:
            speckled.append((loose, os.path.basename(p)))
        if suspect:
            broken.append(os.path.basename(p))
        pt.encode(p, w, h, rows)
        done += 1
        worst.append((rim(w, h, rows), os.path.basename(p)))
    worst.sort(reverse=True)
    for n, name in worst[:3]:
        print("  %-26s %d light pixels on the edge" % (name, n))
    speckled.sort(reverse=True)
    for n, name in speckled[:3]:
        print("  %-26s %d loose pixels dropped" % (name, n))
    for creep, name in eased:
        print("  %-26s stripped at creep %d, not %d" % (name, creep, CREEP))
    for name in broken:
        print("  %-26s BROKEN -- the strip tore the ship apart, left untouched"
              % name)
    print("  stripped %d, already transparent %d, despeckled %d, broken %d"
          % (done, skip, len(speckled), len(broken)))


if __name__ == "__main__":
    main()
