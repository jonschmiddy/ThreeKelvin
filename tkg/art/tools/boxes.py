"""Placeholder hulls at the agreed sizes, for working on screens rather than art.

    python art/tools/boxes.py            # write the twelve placeholders
    python art/tools/boxes.py --restore  # put the real hulls back

WHY A BOX. The ship creator and the hold are being built, and real art is a
distraction there in both directions: it hides layout problems behind something
nice to look at, and it makes a size change look like an art change. A box is
exactly its dimensions and nothing else, so anything that looks wrong IS wrong.

THE ART IS THE SPEC NOW, and these numbers follow it rather than lead it. They
were 75x30, 100x40 and 125x50 — an agreed 2.5:1 settled by putting boxes on
screen — and the Korvan hulls were then drawn to their own proportions and
installed at native size by `tools/install_hulls.py`. What is below is measured
back off those hulls: half of each weight's bare canvas, which is the space a
hull actually occupies in a layout.

BROKEN IN TWO OTHER WAYS, both older than that and neither fixed here, because
writing twelve placeholder PNGs somewhere wrong is worse than writing none.
SPRITES still points at the flat `art/sprites` the hulls left when they moved
into `hulls/korvan/`, and `--restore` names that same dead path; and the boxes
are emitted at 1x, from before the doubling moved into the art, so a screen
calling `magnify(1)` would draw them half the size of the hulls they stand in
for. Re-point and re-scale both before trusting this tool again.

Each box carries its class as pips, because a placeholder that looks identical
at C and at S cannot show you that the tier picker works.
"""

import io
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(HERE, "..", "sprites")

# The agreed hull box per weight class, in art pixels. See the module docstring.
SPEC = {"light": (96, 46), "medium": (124, 56), "heavy": (158, 70)}
TIERS = ("c", "b", "a", "s")

# 38px of clearance to the left of the engines for the exhaust plume — half of
# the 76 the real sheets carry, since these are box units. Nose and vertical
# padding are zero because SPEC above is the whole bare canvas, margins included,
# rather than the ship inside it.
LEFT, RIGHT, VPAD = 38, 0, 0

ICE = (0xC3, 0xD2, 0xE2)
DIM = (0x1A, 0x24, 0x30)
EMBER = (0xD9, 0x7B, 0x29)


def box(bw, bh, tier_index):
    w, h = LEFT + bw + RIGHT, bh + VPAD
    ox, oy = LEFT, (h - bh) // 2
    rows = [bytearray(w * 4) for _ in range(h)]

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            o = x * 4
            rows[y][o], rows[y][o + 1], rows[y][o + 2], rows[y][o + 3] = (
                c[0], c[1], c[2], 255)

    for y in range(bh):
        for x in range(bw):
            put(ox + x, oy + y, DIM)
    for x in range(bw):
        put(ox + x, oy, ICE)
        put(ox + x, oy + bh - 1, ICE)
    for y in range(bh):
        put(ox, oy + y, ICE)
        put(ox + bw - 1, oy + y, ICE)

    # A nose wedge, so orientation reads without a caption. Player hulls face
    # right; an unlabelled rectangle does not, and a placeholder that hides
    # which way the ship points hides a whole class of mistake.
    for i in range(min(10, bh // 2)):
        for x in range(2):
            put(ox + bw - 1 - i - x, oy + bh // 2 - i, EMBER)
            put(ox + bw - 1 - i - x, oy + bh // 2 + i, EMBER)

    # Class, as pips along the bottom edge: C is one, S is four.
    for p in range(tier_index + 1):
        for dx in range(3):
            for dy in range(3):
                put(ox + 4 + p * 5 + dx, oy + bh - 5 + dy, EMBER)
    return w, h, rows


def write():
    for weight, (bw, bh) in SPEC.items():
        for i, tier in enumerate(TIERS):
            w, h, rows = box(bw, bh, i)
            pt.encode(os.path.join(SPRITES, "hull_%s_%s.png" % (weight, tier)),
                      w, h, rows)
        print("  %-7s %3dx%-3d ship on a %3dx%-3d canvas -> %3dx%-3d at 2x"
              % (weight, bw, bh, LEFT + bw + RIGHT, bh + VPAD, bw * 2, bh * 2))


def restore():
    """Put the committed hulls back. The boxes are never the thing to keep."""
    names = ["tkg/art/sprites/hull_%s_%s.png" % (w, t)
             for w in SPEC for t in TIERS]
    root = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
    subprocess.check_call(["git", "checkout", "--"] + names, cwd=root)
    print("  restored %d hulls from git" % len(names))


if __name__ == "__main__":
    if "--restore" in sys.argv:
        restore()
    else:
        write()
    print("\nre-run art/tools/anchors.py afterwards: the mount lines are")
    print("measured per sprite, and `-- mounts` fails if they are not.")
