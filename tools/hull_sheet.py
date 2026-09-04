# -*- coding: utf-8 -*-
"""Tile named hulls into one contact sheet, so a batch can be read in one look.

    python tools/hull_sheet.py <out.png> <name> [<name> ...]

Sprites are composited onto the game's own void rather than left transparent:
a PNG with an alpha channel is shown against whatever the viewer happens to
paint behind it, and against white a dark hull's silhouette reads inverted.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt

DIR = os.environ.get("HULL_DIR") or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "out", "hull_candidates")
VOID = (7, 10, 16)
PAD = 6


def sheet(names, out, cols=3):
    tiles = []
    for n in names:
        w, h, rows = pt.decode(os.path.join(DIR, n + ".png"))
        tiles.append((w, h, rows))
    cw = max(t[0] for t in tiles) + PAD * 2
    ch = max(t[1] for t in tiles) + PAD * 2
    rowsn = (len(tiles) + cols - 1) // cols
    W, H = cw * cols, ch * rowsn
    canvas = [bytearray(bytes(VOID + (255,)) * W) for _ in range(H)]
    for i, (w, h, rows) in enumerate(tiles):
        ox = (i % cols) * cw + (cw - w) // 2
        oy = (i // cols) * ch + (ch - h) // 2
        for y in range(h):
            dst = canvas[oy + y]
            src = rows[y]
            for x in range(w):
                if src[x * 4 + 3]:
                    o = (ox + x) * 4
                    dst[o:o + 3] = src[x * 4:x * 4 + 3]
    pt.encode(out, W, H, canvas)
    return W, H


if __name__ == "__main__":
    out = sys.argv[1]
    names = sys.argv[2:]
    w, h = sheet(names, out)
    print("  %s  %dx%d  (%d sprites)" % (out, w, h, len(names)))
