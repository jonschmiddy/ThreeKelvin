# -*- coding: utf-8 -*-
"""Resample a raw generation so the part SPANS its box, keeping its proportions.

    python tools/scale_to_box.py [--cold] <raw.png> <box_w> <box_h> [out.png]

WHY THIS AND NOT `fill_box.py --tall`. That tool grows a sprite by duplicating
rows, which is right for a hull panel and wrong for a machine: duplicating row i
creates a new seam between the copy and the original whose cost is exactly zero,
nothing can ever beat zero, and so every remaining insertion lands in the same
band. Eleven copies of one drum row turned a winch into an orange column. Six
independent attempts at a smarter seam choice all agreed the fault was not WHICH
seam but that one seam can take the whole of the growth.

The simpler answer is not to grow the part at all. It is to notice the part was
DRAWN SMALL: the generator put 27 pixels of predictor in the middle of a canvas
that could hold 40, and the pipeline faithfully carried that margin all the way
to the sprite. Scaling the drawing up until it spans the box keeps every
proportion the generator chose and fills the cell as a side effect.

FROM THE RAW GENERATION, NOT THE SHIPPING SPRITE. The 80x40 the generator
returns carries twice the detail of the 40x20 it reduces to, so a part that ends
up 40 wide should be resampled once, from 80x40 straight to its final size,
rather than halved to 20-odd pixels and then blown back up. One resample from
the densest source available is the whole reason this reads at all.

RATIONAL, BUT STILL NOT INTERPOLATED. `pixeltools.reduce` shrinks by an exact
integer, taking the DOMINANT pixel of each block rather than the average,
because averaging four colours invents a fifth and a snapped sprite comes back
off its own palette. This is the same rule generalised to a rational factor: a
target pixel samples the source rectangle it covers and takes the most common
opaque colour in it. Every colour emitted was already in the source, so the
palette cannot drift, and nothing is blended. Ties go to the lowest RGB, and
coverage below half stays transparent -- both copied from `reduce` so a rebuild
gives the same bytes and a silhouette does not fatten by a pixel all round.

WHAT THIS IS FOR AND WHAT IT IS NOT FOR, learned by running it over all 27 modules
that had a raw to rescale from and having 7 of them rejected on sight.

  IT BREAKS REGULAR REPEATING PATTERNS. A rational factor duplicates or drops a
  scattered handful of rows and columns. On an irregular mass -- a winch drum, a
  crystal, a starburst, a brace frame -- that is invisible. On anything whose
  IDENTITY is the regularity it is ruinous: a straight gun barrel gains a notch,
  a valve ring goes lopsided, a comb of fins loses its spacing, evenly spaced
  rivets stop being evenly spaced. gantry survived x1.14 and coolant did not
  survive x1.11, and the difference was never the factor.

  IT EATS A ONE-PIXEL ACCENT. Every accepted small module is a dark body with one
  hot point, and a single warm pixel is dropped whenever it is not the majority of
  the rectangle a target pixel covers. MEASURED, not assumed: `scope` lost its
  only gold pixel outright; `weldkit` and `coolline` kept a warm pixel but fell
  from amber to brown. Count the warm pixels before and after and compare the
  brightest -- a reviewer's eye claimed the same of `gunnery` and `board` and the
  count showed both keep theirs.

  A RAW THAT DOES NOT REPRODUCE THE SPRITE MAY STILL BE ITS RAW -- THE SNAP RULE
  MOVED. `organ` came back a saturated gold swirl, and the first diagnosis was that
  a pink take had been mistaken for the one that shipped. That was wrong, and the
  way it was wrong is worth keeping. The raw IS organ's source: its silhouette
  matches the shipped sprite exactly. What changed is the snap. organ was posted
  when the rule was `module_palette(cold_only=True)`, which drops the warm entries
  and lands pink on cold greys; `snap_split` replaced that later, and it sends a
  warm pixel to a warm entry -- of which the only ones in the palette are `optics`
  amber lens. Cold-only reproduces the shipped sprite to a distance of 706. Split
  scores 38532.

  So before concluding a raw is the wrong take, RE-POST IT UNDER THE OLDER RULE.
  `--cold` exists for exactly this: a sprite whose art was decided under cold-only
  has to be rescaled under cold-only, or it changes colour on the way through.

WIDTH LEADS, HEIGHT FOLLOWS. The scale is chosen so the ink spans the box
width, and the height lands where the proportions put it. A 2:1 box and a 3.5:1
drum cannot both be filled by one factor, and stretching the odd one out to
close that gap is the thing this file exists to avoid. If the proportional
height would overflow the box, the height leads instead.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import module_batch as mb  # noqa: E402


def resample(w, h, rows, tw, th):
    """Box-resample to exactly tw x th by the dominant-pixel rule.

    Bounds are computed in integer arithmetic -- pixel X covers source columns
    [X*w/tw, (X+1)*w/tw) -- so the same input always produces the same output
    and no source pixel is counted twice or skipped.
    """
    out = []
    for Y in range(th):
        y0, y1 = (Y * h) // th, ((Y + 1) * h + th - 1) // th
        y1 = max(y1, y0 + 1)
        line = bytearray(tw * 4)
        for X in range(tw):
            x0, x1 = (X * w) // tw, ((X + 1) * w + tw - 1) // tw
            x1 = max(x1, x0 + 1)
            tally, solid, seen = {}, 0, 0
            for y in range(y0, min(y1, h)):
                r = rows[y]
                for x in range(x0, min(x1, w)):
                    o = x * 4
                    seen += 1
                    if not r[o + 3]:
                        continue
                    solid += 1
                    c = (r[o], r[o + 1], r[o + 2])
                    tally[c] = tally.get(c, 0) + 1
            if not seen or solid * 2 < seen:
                continue                      # left transparent
            c = min(tally.items(), key=lambda kv: (-kv[1], kv[0]))[0]
            o = X * 4
            line[o], line[o + 1], line[o + 2], line[o + 3] = c[0], c[1], c[2], 255
        out.append(line)
    return tw, th, out


def target(w, h, bw, bh):
    """The largest size with this aspect that fits the box, width leading."""
    tw, th = bw, max(1, int(round(h * bw / float(w))))
    if th > bh:
        th, tw = bh, max(1, int(round(w * bh / float(h))))
    return tw, th


def main():
    argv = sys.argv[1:]
    cold_only = "--cold" in argv
    if cold_only:
        argv.remove("--cold")
    src, bw, bh = argv[0], int(argv[1]), int(argv[2])
    dst = argv[3] if len(argv) > 3 else src
    w, h, rows = pt.decode(src)
    pt.strip_bg(w, h, rows)
    pt.despeckle(w, h, rows)
    w, h, rows = pt.trim(w, h, rows)
    tw, th = target(w, h, bw, bh)
    nw, nh, out = resample(w, h, rows, tw, th)
    nw, nh, out = pt.trim(nw, nh, out)
    # Same snap the rest of the batch gets, and for the same reason: the
    # generator invents its own greys and the set has to land on one tone.
    # `resample` cannot drift the palette but it never promised the SOURCE was
    # on it.
    if cold_only:
        pt.snap(nw, nh, out, mb.module_palette(cold_only=True))
    else:
        pal = mb.module_palette()
        cold = [c for c in pal if not mb.is_warm(c)]
        warm = [c for c in pal if mb.is_warm(c)]
        mb.snap_split(nw, nh, out, cold, warm)
    print("  %s: ink %dx%d -> %dx%d in %dx%d (x%.2f)"
          % (os.path.basename(src), w, h, nw, nh, bw, bh, tw / float(w)))
    return dst, bw, bh, nw, nh, out


if __name__ == "__main__":
    dst, bw, bh, nw, nh, out = main()
    nw, nh, out, over = pt.fit(nw, nh, out, bw, bh)
    if any(over):
        print("  OVERFLOW %d x %d" % over)
    pt.encode(dst, nw, nh, out)
