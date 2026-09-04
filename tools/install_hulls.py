# -*- coding: utf-8 -*-
"""Put the chosen hulls into the game, at native size.

    python tools/install_hulls.py [--write]

Without --write it stages into tools/out/install and touches nothing the game
loads. That is the default because this replaces twelve shipped sprites and
changes the size of every hull box.

THREE FILES PER HULL, and the shapes are not arbitrary -- they are read off what
already ships:

    bare/  the ship and a couple of pixels of margin, ship pushed to the RIGHT
    full   bare with exactly 76 px added on the LEFT, for the exhaust plume
    half/  full reduced by two, for the convoy column (ConvoySlot.use_half)

The 76 is measured, not chosen: light 80-4, medium 83-7, heavy 77-1 all give 76.

NOTHING IS RESAMPLED. The art goes in at the size it was generated, and the box
grows to fit it, because the art is already authored at 2x its box and scaling
pixel art by a non-integer factor is how crisp plating turns to mush. The half
sheet is an exact halving, which is the one reduction that stays clean.
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, "..", "tkg", "art", "sprites", "hulls", "korvan")
STAGE = os.path.join(HERE, "out", "install")

PAD = 76          # exhaust room, left of the ship, in the full sheet
RIGHT = 2         # margin between the nose and the right edge of `bare`
TIERS = ("s", "a", "b", "c")

# Ranked most advanced first; the bench's order maps straight onto S A B C.
RANK = {
    "light":  ["s192_09", "s192_22", "s192_03", "s192_25"],
    "medium": ["m260_15", "m260_09", "m260_05", "m260_10"],
    "heavy":  ["heavy_12_belt", "heavy_08_patched", "n_33", "heavy_18"],
}
SRC = {
    "light":  os.path.join(HERE, "out", "pool", "light"),
    "medium": os.path.join(HERE, "out", "pool", "medium"),
    "heavy":  os.path.join(HERE, "out", "heavy_final"),
}
# Marked flip in the bench. n_33 is NOT here: it was mirrored on the way into
# heavy_final, so the file on disk already points right.
FLIP = {"m260_05", "m260_10"}


def round4(n):
    return (n + 3) // 4 * 4


def blank(w, h):
    return [bytearray(w * 4) for _ in range(h)]


def mirror(w, h, rows):
    out = blank(w, h)
    for y in range(h):
        s = rows[y]
        for x in range(w):
            o = (w - 1 - x) * 4
            out[y][x * 4:x * 4 + 4] = s[o:o + 4]
    return out


def blit(dst, dw, dh, src, sw, sh, ox, oy):
    for y in range(sh):
        if not 0 <= oy + y < dh:
            continue
        row = dst[oy + y]
        s = src[y]
        for x in range(sw):
            if not 0 <= ox + x < dw or not s[x * 4 + 3]:
                continue
            row[(ox + x) * 4:(ox + x) * 4 + 4] = s[x * 4:x * 4 + 4]


def ship(path, flip):
    w, h, rows = pt.decode(path)
    if flip:
        rows = mirror(w, h, rows)
    xs = [x for x in range(w) if any(rows[y][x * 4 + 3] for y in range(h))]
    ys = [y for y in range(h) if any(rows[y][x * 4 + 3] for x in range(w))]
    return pt.crop(w, h, rows, xs[0], ys[0], xs[-1] - xs[0] + 1, ys[-1] - ys[0] + 1)


def box(weight):
    """One bare canvas per weight, big enough for the largest of its four."""
    W = H = 0
    for name in RANK[weight]:
        sw, sh, _ = ship(os.path.join(SRC[weight], name + ".png"), name in FLIP)
        W = max(W, sw)
        H = max(H, sh)
    return round4(W + RIGHT * 2), round4(H + 6)


def main():
    write = "--write" in sys.argv
    root = GAME if write else STAGE
    for sub in ("", "bare", "half"):
        d = os.path.join(root, sub)
        if not os.path.isdir(d):
            os.makedirs(d)
    print("  %-8s %-11s %-11s %-11s %s"
          % ("", "bare", "full", "half", "ship"))
    for weight in ("light", "medium", "heavy"):
        bw, bh = box(weight)
        fw, fh = bw + PAD, bh
        for tier, name in zip(TIERS, RANK[weight]):
            sw, sh, sr = ship(os.path.join(SRC[weight], name + ".png"), name in FLIP)
            ox, oy = bw - sw - RIGHT, (bh - sh) // 2

            bare = blank(bw, bh)
            blit(bare, bw, bh, sr, sw, sh, ox, oy)
            full = blank(fw, fh)
            blit(full, fw, fh, sr, sw, sh, PAD + ox, oy)
            hw, hh, half = pt.reduce(fw, fh, [bytearray(r) for r in full], 2)

            stem = "hull_%s_%s.png" % (weight, tier)
            pt.encode(os.path.join(root, stem), fw, fh, full)
            pt.encode(os.path.join(root, "bare", stem), bw, bh, bare)
            pt.encode(os.path.join(root, "half", stem), hw, hh, half)
            print("  %-8s %-11s %-11s %-11s %3dx%-3d  %s%s"
                  % ("%s_%s" % (weight, tier), "%dx%d" % (bw, bh),
                     "%dx%d" % (fw, fh), "%dx%d" % (hw, hh), sw, sh, name,
                     "  mirrored" if name in FLIP else ""))
    print()
    print("  wrote to %s" % ("the game" if write else STAGE))
    if not write:
        print("  nothing the game loads has changed; re-run with --write to install")


if __name__ == "__main__":
    main()
