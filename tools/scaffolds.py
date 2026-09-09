# -*- coding: utf-8 -*-
"""Flat scaffold shapes to hand PixelLab as an init image.

    python tools/scaffolds.py --list
    python tools/scaffolds.py --write <name> <w> <h> [out.png]
    python tools/scaffolds.py --b64 <name> <w> <h>
    python tools/scaffolds.py --sheet            # every shape, one contact strip

WHY THIS EXISTS. Nine probes were run against one subject to find what forces a
flat side elevation instead of an isometric box, and the split was clean:
everything that CHANGED THE GEOMETRY worked, everything that DESCRIBED the
geometry did not. A four-colour forced palette drew an isometric box in four
colours. A prompt asking at length for one single flat tone drew a faceted
diamond. The exact wording recorded in commit 81059ea as working first try --
"the flat side face of a plate, drawn as a flat two-dimensional profile, no
visible top or end faces" -- came back a box on a different subject.

The reason is in the diagnosis: THE PROJECTION RIDES IN ON THE SUBJECT NOUN.
A bin, a crate, a cabinet resolve to roguelike furniture, and furniture is drawn
from thirty-five degrees above because that is how the training corpus draws it.
A few modifier tokens cannot outvote the most heavily weighted concept in the
prompt, and negations are the weakest form of all -- naming perspective can
summon it.

So the projection stops being something argued for in every prompt and becomes a
property of the pipeline. `docs/art/PIXELLAB_WORKFLOW.md:48` already said so and
it had never been applied to modules: "init_image is the only reliable control
... Never generate a hull from text alone."

WHAT A SCAFFOLD IS AND IS NOT. It donates FLATNESS, not identity. Every shape
here is a bald primitive drawn from axis-aligned rectangles and circles: no top
face, no receding plane, no diagonal that could read as a corner in depth. It is
deliberately NOT an upscaled accepted sprite -- that would donate the sprite's
identity too, and eleven modules would come back as eleven optics.

TRANSPARENT, ALWAYS. bb66d02 measured that `no_background` is broken by an
OPAQUE init image and only by an opaque one; a transparent init comes back
transparent. Every shape here leaves its margin at alpha zero.

FEATURE PITCH IS A CONSTRAINT, NOT A TASTE. A module is generated at 2x its box
and halved by `pixeltools.reduce`, which takes the dominant pixel of each 2x2
block. A feature thinner than two pixels at generation size is a coin flip in
the mode filter, so combs and grids here are drawn at a pitch that leaves the
feature at least 1.5px after the halve. A tighter comb does not come back
sharper, it comes back missing.
"""
import base64
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt  # noqa: E402

## The body and the line. Two values only -- a scaffold with three would be
## proposing a lit plane, which is the thing being designed out.
BODY = (85, 105, 115)
LINE = (13, 11, 22)


def _blank(w, h):
    return [bytearray(w * 4) for _ in range(h)]


def _emit(w, h, cells):
    """Cells -> rows, outlining anything on the boundary of the set."""
    rows = _blank(w, h)
    for (x, y) in cells:
        if not (0 <= x < w and 0 <= y < h):
            continue
        edge = any((x + dx, y + dy) not in cells
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        o = x * 4
        rows[y][o:o + 4] = bytes((LINE if edge else BODY) + (255,))
    return rows


def _rect(cells, x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            cells.add((x, y))


def _disc(cells, cx, cy, r, inner=0):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if inner * inner <= d <= r * r:
                cells.add((x, y))


# --------------------------------------------------------------- the shapes
#
# Every one is a SIDE ELEVATION. Read each as though the object were pressed
# against glass: the outline is the whole of it.

def comb(w, h):
    """Fins on a spine. Heat sinks, radiators, vaned anything."""
    c = set()
    pitch = max(4, w // 6)
    fin = max(2, pitch // 2)
    for fx in range(pitch // 2, w - fin, pitch):
        _rect(c, fx, int(h * 0.18), fx + fin - 1, int(h * 0.66))
    _rect(c, 2, int(h * 0.66), w - 3, int(h * 0.82))
    return _emit(w, h, c)


def ring(w, h):
    """An annulus. Coils, rolls, spools, gaskets."""
    c = set()
    r = min(w, h) * 0.42
    _disc(c, (w - 1) / 2.0, (h - 1) / 2.0, r, r * 0.42)
    return _emit(w, h, c)


def barrel(w, h):
    """A capsule lying down. Tanks, tubes, drums, bores."""
    c = set()
    r = h * 0.30
    _rect(c, int(w * 0.14), int((h - 1) / 2.0 - r), int(w * 0.86),
          int((h - 1) / 2.0 + r))
    _disc(c, w * 0.14, (h - 1) / 2.0, r)
    _disc(c, w * 0.86, (h - 1) / 2.0, r)
    return _emit(w, h, c)


def upright(w, h):
    """A capsule stood up. Bottles, cells, cylinders on end."""
    c = set()
    r = w * 0.26
    _rect(c, int((w - 1) / 2.0 - r), int(h * 0.20), int((w - 1) / 2.0 + r),
          int(h * 0.84))
    _disc(c, (w - 1) / 2.0, h * 0.20, r)
    _rect(c, int(w * 0.22), int(h * 0.84), int(w * 0.78), int(h * 0.90))
    return _emit(w, h, c)


def slab(w, h):
    """A plate with a stepped end. Armour, panels, plating.

    The step is the whole point. A bare rectangle is the other double-cut
    failure `module_batch` records -- at 40x20 the rectangle IS the silhouette
    and nothing distinguishes two of them.
    """
    c = set()
    _rect(c, 2, int(h * 0.34), w - 3, int(h * 0.66))
    _rect(c, 2, int(h * 0.24), int(w * 0.30), int(h * 0.76))
    return _emit(w, h, c)


def cross(w, h):
    """An X of struts. Bracing, frames, lattices."""
    c = set()
    t = max(2, min(w, h) // 8)
    for i in range(min(w, h) - 4):
        x = 2 + i * (w - 5) // max(1, min(w, h) - 5)
        y = 2 + i * (h - 5) // max(1, min(w, h) - 5)
        _rect(c, x, y, x + t, y + t)
        _rect(c, w - 1 - x - t, y, w - 1 - x, y + t)
    return _emit(w, h, c)


def frame(w, h):
    """An open box. Cages, racks, brace frames."""
    c = set()
    t = max(2, min(w, h) // 7)
    _rect(c, 2, 2, w - 3, 2 + t)
    _rect(c, 2, h - 3 - t, w - 3, h - 3)
    _rect(c, 2, 2, 2 + t, h - 3)
    _rect(c, w - 3 - t, 2, w - 3, h - 3)
    return _emit(w, h, c)


def bracket(w, h):
    """A U. Clamps, mounts, cradles, yokes."""
    c = set()
    t = max(2, min(w, h) // 6)
    _rect(c, 2, int(h * 0.20), 2 + t, h - 3)
    _rect(c, w - 3 - t, int(h * 0.20), w - 3, h - 3)
    _rect(c, 2, h - 3 - t, w - 3, h - 3)
    return _emit(w, h, c)


def ell(w, h):
    """An L. Torches, welders, nozzles, anything with a head on a body."""
    c = set()
    _rect(c, 2, int(h * 0.30), int(w * 0.58), int(h * 0.70))
    _rect(c, int(w * 0.58), int(h * 0.14), w - 3, int(h * 0.52))
    return _emit(w, h, c)


def gear(w, h):
    """A toothed disc. Gears, wheels, rosettes, dials."""
    c = set()
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    r = min(w, h) * 0.34
    _disc(c, cx, cy, r)
    t = max(2, int(min(w, h) * 0.10))
    for i in range(8):
        ang = i * 3.14159265 / 4.0
        import math
        ex = cx + math.cos(ang) * (r + t * 0.6)
        ey = cy + math.sin(ang) * (r + t * 0.6)
        _rect(c, int(ex - t / 2), int(ey - t / 2), int(ex + t / 2), int(ey + t / 2))
    return _emit(w, h, c)


def rail(w, h):
    """A solid beam lying level. Rails, tracks, girders, spines.

    ONE MASS, NOT AN I-BEAM PROFILE. The first version drew a true I -- two
    flanges with a web between them -- and at forty pixels the web is two pixels
    of a forty-pixel span, so the eye reads the flanges as TWO SEPARATE BARS and
    the generator drew two separate rails. Both of `ejector`'s first takes came
    back as a pair of tracks stacked one above the other, and the same shape was
    assigned to `gantry` and `keel`.

    A scaffold's whole job is to donate one flat silhouette. A silhouette with a
    gap across its middle donates two.
    """
    c = set()
    _rect(c, 1, int(h * 0.36), w - 2, int(h * 0.64))
    # End plates, which is what makes it a track rather than a bar -- and they
    # are attached to the beam rather than floating beside it.
    _rect(c, 1, int(h * 0.24), int(w * 0.10), int(h * 0.76))
    _rect(c, w - 2 - int(w * 0.10), int(h * 0.24), w - 2, int(h * 0.76))
    return _emit(w, h, c)


SHAPES = {
    "comb": comb, "ring": ring, "barrel": barrel, "upright": upright,
    "slab": slab, "cross": cross, "frame": frame, "bracket": bracket,
    "ell": ell, "gear": gear, "rail": rail,
}

## Which scaffold each module that still has no art is generated against, and
## the box it ships at. The pairing is by SILHOUETTE, not by subject: a brass
## catcher and a coolant tank are both a barrel, because what the scaffold
## donates is a shape with no top face, not an identity.
ASSIGN = {
    # 1x1 -> 20x20 box, scaffold at 40x40
    "brass": ("barrel", 20, 20), "coldsights": ("comb", 20, 20),
    "ejector": ("rail", 20, 20), "gunnery": ("gear", 20, 20),
    "weldkit": ("upright", 20, 20),
    # 2x1 -> 40x20 box, scaffold at 80x40
    "blowout": ("slab", 40, 20), "board": ("frame", 40, 20),
    "director": ("gear", 40, 20), "gantry": ("rail", 40, 20),
    "hoist": ("barrel", 40, 20), "plate": ("ell", 40, 20),
    "plating": ("slab", 40, 20), "standfast": ("bracket", 40, 20),
    # 2x2 -> 40x40 box, scaffold at 80x80
    "keel": ("rail", 40, 40), "mainbus": ("frame", 40, 40),
    "sepulchre": ("upright", 40, 40), "singing": ("cross", 40, 40),
}


def build(name, w, h):
    return SHAPES[name](w, h)


def b64(name, w, h):
    p = os.path.join("tools", "out", "_scaffold_tmp.png")
    pt.encode(p, w, h, build(name, w, h))
    raw = open(p, "rb").read()
    os.remove(p)
    return base64.b64encode(raw).decode("ascii")


def main(argv):
    if not argv or argv[0] == "--list":
        print("shapes: %s" % " ".join(sorted(SHAPES)))
        print("\n%-11s %-9s %-9s %s" % ("module", "box", "generate", "scaffold"))
        for mid in sorted(ASSIGN):
            s, bw, bh = ASSIGN[mid]
            print("  %-9s %-9s %-9s %s"
                  % (mid, "%dx%d" % (bw, bh), "%dx%d" % (bw * 2, bh * 2), s))
        return 0
    if argv[0] == "--write" and len(argv) >= 4:
        name, w, h = argv[1], int(argv[2]), int(argv[3])
        out = argv[4] if len(argv) > 4 else "tools/out/_scaf_%s_%dx%d.png" % (name, w, h)
        pt.encode(out, w, h, build(name, w, h))
        print(out)
        return 0
    if argv[0] == "--b64" and len(argv) >= 4:
        sys.stdout.write(b64(argv[1], int(argv[2]), int(argv[3])))
        return 0
    if argv[0] == "--sheet":
        frames = []
        for n in sorted(SHAPES):
            frames.append((40, 40, build(n, 40, 40)))
        w, h, rows = pt.hstrip(frames)
        pt.encode("tools/out/_scaffolds.png", w, h, rows)
        print("tools/out/_scaffolds.png   %s" % " ".join(sorted(SHAPES)))
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
