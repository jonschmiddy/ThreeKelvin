# -*- coding: utf-8 -*-
"""Take a batch of generated module art from raw PNG to shipping sprite.

    python tools/module_batch.py --post <indir> <outdir>
    python tools/module_batch.py --sheet <dir> [<dir> ...] > out.js

WHY THIS EXISTS. The pilot did every one of these steps by hand and the hand
slipped: a sprite that skipped the snap came out warmer than its neighbours,
and one that skipped `fit` was centred by luck. The steps are not interesting
enough to think about twice, and they have to be identical across 108 assets or
the set drifts. So they live here, in the order pixeltools' own docstrings give:

    strip_bg -> despeckle -> reduce(2) -> trim -> snap -> fit(box)

REDUCE COMES BEFORE SNAP, not after. `reduce` picks the dominant pixel of each
2x2 block rather than averaging, so every colour it emits was already in the
source -- its docstring says it needs no snap of its own. Snapping the smaller
image is the same operation on a quarter of the pixels.

SNAP AT ALL, though, because generation invents its own greys. The palette is
the union of the six modules that were ACCEPTED, which is the same argument
`tools/korvan_palette.py` makes for hulls: the tone is decided once, off art
that was actually liked, and every future batch lands on it. Colour consistency
stops being something to hope the generator repeats.

WHAT THE PROMPTS HAVE TO SAY, learned the expensive way over three rounds and
worth writing down because none of it is guessable:

  ONE OBJECT, NAMEABLE IN SILHOUETTE. The accepted set is an X, a tube with a
  wheel, a capsule, a comb of fins, a mesh. Each survives being filled in solid
  black. "A rail with a chain hanging from it" is two objects and was cut twice.

  FLAT SIDE-ON, NO PERSPECTIVE. A casket drawn in three-quarter view was cut for
  exactly that and nothing else -- it read as a different projection from every
  part beside it on the hull. `view="side"` alone does not get there; the prompt
  has to say "strictly side-on with no perspective and no angle".

  FLAT RECTANGULAR PANELS DO NOT WORK AT 40x20. Four of them were cut twice, in
  two different framings. At that size the rectangle IS the silhouette and the
  only thing telling two panels apart is detail on the face, which is the first
  thing to go at 2x. This looks like a property of the subject rather than of
  any prompt, and the plate that DOES work in the game was drawn by hand.

EVERY MODULE IS GENERATED AT 2x ITS BOX. Not a style choice -- PixelLab's floor
is 1024px of area and every module box is under it (40x20 is 800). The 2x2s
clear the floor at 40x40, but they are generated at 2x anyway so that one rule
covers the set and a 2x2 does not quietly become the one shape drawn at a
different density from the rest.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt  # noqa: E402

SPRITES = os.path.join("tkg", "art", "sprites", "modules")

## The modules whose art was accepted. THE TONE COMES FROM THESE and nothing
## else -- three were generated and three were drawn by hand, and the hand-drawn
## ones are in deliberately: they are the ones nobody argued with.
ACCEPTED = ["kh20", "optics", "bulkhead", "km4", "widow", "reactive"]

## id -> box, in art pixels. Derived from the footprint the same way
## MountPoints does it: cells * (HoldGrid.CELL / 2), gap zero.
BOX = {
    # structure
    "plating": (40, 20), "board": (40, 20), "bracing": (40, 20),
    "coolant": (40, 20), "sinkplate": (40, 20), "blowout": (40, 20),
    "hoist": (40, 20), "gantry": (40, 20), "buscoupling": (40, 20),
    "plate": (40, 20),
    "cryobat": (40, 40), "keel": (40, 40), "lattice": (40, 40),
    "sepulchre": (40, 40), "braceframe": (40, 40), "mainbus": (40, 40),
    # utility. A 1x1 is TWENTY pixels square -- the smallest box in the game and
    # the one with the least room to be wrong in.
    "brass": (20, 20), "coldsights": (20, 20), "coolline": (20, 20),
    "ejector": (20, 20), "gunnery": (20, 20), "oracle": (20, 20),
    "patchkit": (20, 20), "scope": (20, 20), "scuttle": (20, 20),
    "servo": (20, 20), "weldkit": (20, 20),
    "director": (40, 20), "standfast": (40, 20), "organ": (40, 40),
    # weapons. FOUR VARIANTS EACH, judged as a set -- one-shotting a gun has
    # never worked and the variant round is how kh20 landed. Variants are named
    # "<id>_a" .. "<id>_d" and share the base id's box.
    "beam": (60, 20), "slug": (60, 20), "torch": (40, 20),
    "kh40": (40, 20), "kh88": (40, 20), "kh500": (80, 20),
    "singing": (40, 40),
}


def box_for(mid):
    """A variant `slug_b` is the same box as `slug`."""
    if mid in BOX:
        return BOX[mid]
    return BOX.get(mid.rsplit("_", 1)[0])


def module_palette(cold_only=True):
    """The colours the accepted modules use, as a flat list.

    COLD ONLY, BY DEFAULT, and that is a bug fix rather than a taste. The first
    version took the union of every colour in the accepted set, which quietly
    made `optics` -- a twenty-pixel sight with an AMBER LENS -- contribute ten
    oranges to the palette every other module then snapped against. A brass bin
    came back with 21 amber pixels it was never generated with, because the
    nearest palette entry to a warm-ish grey had become #d6b043.

    An accent belongs to the sprite that earned it. Snapping is for forcing the
    STRUCTURAL greys onto one tone, so the ramp is what it takes, and a warm
    pixel lands on the nearest cold neighbour instead of on somebody else lens.

    MEASURED: 15 of the 53 colours were warm, all of them from four sprites, and
    ten from `optics` alone.
    """
    seen = []
    for name in ACCEPTED:
        p = os.path.join(SPRITES, name + ".png")
        if not os.path.exists(p):
            continue
        w, h, rows = pt.decode(p)
        for c in pt.palette(w, h, rows):
            if cold_only and c[0] > c[2] + 12:
                continue
            if c not in seen:
                seen.append(c)
    return seen


def post_one(src, box, pal):
    """Raw generation -> shipping sprite. Returns (w, h, rows, report)."""
    w, h, rows = pt.decode(src)
    # The generator answers no_background with alpha already, but not always
    # cleanly -- a matte survives at the corners often enough to be worth the
    # pass, and strip_bg on an already-transparent border is a no-op.
    pt.strip_bg(w, h, rows)
    pt.despeckle(w, h, rows)
    w, h, rows = pt.reduce(w, h, rows, 2)
    w, h, rows = pt.trim(w, h, rows)
    drift = pt.snap(w, h, rows, pal)
    ink = (w, h)
    # `fit` hands back the OVERFLOW rather than shrinking to hide it. A
    # generation that measures wider than its box after trimming is a failed
    # asset, not one to resample -- so it is reported, loudly, per column.
    w, h, rows, over = pt.fit(w, h, rows, box[0], box[1])
    return w, h, rows, (ink, drift, over)


def main(argv):
    if len(argv) >= 3 and argv[0] == "--post":
        indir, outdir = argv[1], argv[2]
        if not os.path.isdir(outdir):
            os.makedirs(outdir)
        pal = module_palette()
        print("palette: %d colours from %d accepted modules"
              % (len(pal), len(ACCEPTED)))
        for f in sorted(os.listdir(indir)):
            if not f.endswith(".png"):
                continue
            mid = os.path.splitext(f)[0]
            box = box_for(mid)
            if box is None:
                print("  %-12s SKIP  no box in the table" % mid)
                continue
            w, h, rows, (ink, drift, over) = post_one(
                os.path.join(indir, f), box, pal)
            pt.encode(os.path.join(outdir, f), w, h, rows)
            flag = "  CLIPPED %dx%d" % over if any(over) else ""
            print("  %-12s box %-7s ink %-7s  %4d px snapped%s"
                  % (mid, "%dx%d" % box, "%dx%d" % ink, drift, flag))
        return 0

    if len(argv) >= 2 and argv[0] == "--sheet":
        import base64
        out = {}
        for d in argv[1:]:
            tag = os.path.basename(d.rstrip("/\\"))
            for f in sorted(os.listdir(d)):
                if f.endswith(".png"):
                    raw = open(os.path.join(d, f), "rb").read()
                    key = "%s:%s" % (tag, os.path.splitext(f)[0])
                    out[key] = base64.b64encode(raw).decode("ascii")
        sys.stdout.write("var IMG = {\n")
        for k in sorted(out):
            sys.stdout.write('  "%s": "%s",\n' % (k, out[k]))
        sys.stdout.write("};\n")
        return 0

    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
