"""Put back the lights a hold icon's shrink averaged into the dark.

    uv run --with pillow --with numpy python tkg/art/tools/hold_lights.py SPEC.json [--dry]

SPEC.json: {id: {"drawing": the big drawing the icon was shrunk from,
                 "ink": [x0, y0, x1, y1] the box the shrink cropped to, when it was not the
                        drawing's own alpha box (strays dropped first), end exclusive,
                 "copies": [[x0, y0, x1, y1, sx, sy], ...] boxes a hand clean copied in the
                        icon (end inclusive) from the box at (sx, sy)}}.
The icon is tkg/art/sprites/modules/hold/<id>.png; only stamped pixels change.

A light is ship_guns.lights(): a warm run of luma >= 200. The hold icons were shrunk as
iconlib.shrink does (crop to ink, fit the cell less 1 px, box filter, centred), so a light's
cells are known. One is put back, as ship_guns.stamp_lights does (its brightest colour on the
cells that cover it, the icon's darkest colour on the row above and below), when the icon has
no pixel there at LOST of its luma, and it is a slit in the dark: at least MIN_RUN drawn pixels
each way, the drawn rows above and below it no lighter than ship_guns.EDGE_LUMA. A 1 px glint,
or a highlight on lit brass, is not a lamp; stamping it would add a speck or a dark line.

The spec for the 67 icons on the hold-icons branch, and the sheets that judged it, are
tk-scratch/hold_icons/lights (mkspec.py, sheet.py). The Korvan 1:1 re-shrinks (mainbus,
cryobat, plate) have no lights, so the line map clean/reshrink.py used is not modelled here.
"""
import io
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ship_guns import EDGE_LUMA, lights, stamp_column
from relight import luma

HOLD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites", "modules", "hold")
LOST = 0.85
MIN_RUN = 2


def ink_box(drawing):
    return drawing.split()[3].point(lambda v: 255 if v >= 128 else 0).getbbox()


def fit_maps(drawing, cw, ch, box=None, margin=1):
    """Per drawn column and row, the icon cells (lo, hi) the shrink put it on, or None."""
    bx0, by0, bx1, by1 = box or ink_box(drawing)
    W, H = bx1 - bx0, by1 - by0
    s = min((cw - 2 * margin) / W, (ch - 2 * margin) / H)
    w, h = max(1, round(W * s)), max(1, round(H * s))

    def axis(n, b0, b1, size, cells, off):
        k = cells / size
        return [(int(np.floor((i - b0) * k)) + off, int(np.ceil((i - b0 + 1) * k)) - 1 + off)
                if b0 <= i < b1 else None for i in range(n)]
    return (axis(drawing.width, bx0, bx1, W, w, (cw - w) // 2),
            axis(drawing.height, by0, by1, H, h, (ch - h) // 2))


def cells_of(light, xmap, ymap, copies=()):
    """The icon cells a light landed on, after any hand-clean copies."""
    x0, y0, x1, y1 = light[:4]
    xs = [xmap[i] for i in range(x0, x1 + 1) if xmap[i]]
    ys = [ymap[i] for i in range(y0, y1 + 1) if ymap[i]]
    if not xs or not ys:
        return set()
    cells = {(x, y) for x in range(min(a for a, _ in xs), max(b for _, b in xs) + 1)
             for y in range(min(a for a, _ in ys), max(b for _, b in ys) + 1)}
    for cx0, cy0, cx1, cy1, sx, sy in copies:
        dest = {(x, y) for x in range(cx0, cx1 + 1) for y in range(cy0, cy1 + 1)}
        moved = {(x, y) for x, y in dest if (x - cx0 + sx, y - cy0 + sy) in cells}
        cells = (cells - dest) | moved
    # (what a copy left of a light under MIN_RUN cells across is the edge of the part it painted over)
    if copies and cells and min(len({x for x, _ in cells}), len({y for _, y in cells})) < MIN_RUN:
        return set()
    return cells


def in_slot(drawing, light):
    """At least MIN_RUN drawn px each way, with the drawn rows above and below it dark."""
    x0, y0, x1, y1 = light[:4]
    if x1 - x0 + 1 < MIN_RUN or y1 - y0 + 1 < MIN_RUN:
        return False
    p = drawing.load()

    def row(y):
        px = [p[x, y] for x in range(x0, x1 + 1) if 0 <= y < drawing.height and p[x, y][3] >= 128]
        return sum(map(luma, px)) / len(px) if px else 0
    return row(y0 - 1) <= EDGE_LUMA and row(y1 + 1) <= EDGE_LUMA


def kept(icon, cells, c):
    p = icon.load()
    return any(p[x, y][3] and luma(p[x, y]) >= LOST * luma(c) for x, y in cells
               if 0 <= x < icon.width and 0 <= y < icon.height)


def restore(drawing, icon, xmap, ymap, copies=()):
    """Stamp the lost slits into `icon` in place; returns [(light, cells, 'kept'|'stamped'|'glint'|'painted over')]."""
    ink = min((c for c in icon.get_flattened_data() if c[3]), key=luma)
    p = icon.load()
    out = []
    for lt in sorted(lights(drawing), key=lambda t: (t[0], t[1])):
        cells = cells_of(lt, xmap, ymap, copies)
        if not cells:
            out.append((lt, cells, "painted over"))
            continue
        if kept(icon, cells, lt[4]):
            out.append((lt, cells, "kept"))
            continue
        if not in_slot(drawing, lt):
            out.append((lt, cells, "glint"))
            continue
        for x in sorted({x for x, _ in cells}):
            ys = [y for cx, y in cells if cx == x]
            stamp_column(p, icon.height, x, min(ys), max(ys), lt[4], ink)
        out.append((lt, cells, "stamped"))
    return out


def run(spec_path, dry=False):
    spec = json.load(io.open(spec_path, encoding="utf-8"))
    for mid in sorted(spec):
        e = spec[mid]
        drawing = Image.open(e["drawing"]).convert("RGBA")
        path = os.path.join(HOLD, mid + ".png")
        icon = Image.open(path).convert("RGBA")
        xmap, ymap = fit_maps(drawing, icon.width, icon.height, e.get("ink"))
        res = restore(drawing, icon, xmap, ymap, e.get("copies", ()))
        n = {k: sum(1 for r in res if r[2] == k) for k in ("kept", "stamped", "glint", "painted over")}
        if res:
            print("  %-13s lights %2d  kept %2d  stamped %2d  glint or highlight %2d  painted over %d"
                  % (mid, len(res), n["kept"], n["stamped"], n["glint"], n["painted over"]))
        if n["stamped"] and not dry:
            icon.save(path)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    run(sys.argv[1], "--dry" in sys.argv)
