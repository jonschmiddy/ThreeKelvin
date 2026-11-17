"""Install the on-ship gun pictures from the artist's folder.

    uv run --with pillow --with numpy python tkg/art/tools/ship_guns.py SRC_DIR

SRC_DIR holds gun_<id>.png and guns.json (per gun: side_drawn, anchor, and an
optional "stencil" list of [x, y, w, h] boxes). Re-run it after the artist drops
in new PNGs or new anchors; that is the whole update.

Writes tkg/art/sprites/guns/:
    <id>_<side>.png  the side the gun was drawn for, as drawn, and the other
                     side flipped and relit by relight.py (lit from above)
    guns.json        {id: {side: {file, anchor}}}, read by ShipGun.gd

Every gun is shrunk to SCALE of its drawn size first (Jon, Nov 17: "too big"),
the way the hold icons are: an area shrink on premultiplied colour, hard alpha at
0.45, the gun's own palette (24 colours), then its 1 px dark outline closed again
on every edge. Its anchor scales with it, and the belly copy is made from the
shrunk gun.

The anchor is the gun's contact point (hardpoints.md): the row just past a top
gun's foot, or a belly gun's top row. A flip moves it to (x, h - y).
A stencil is lettering: the flip would mirror it, so it is painted out of the
relit copy and stamped back upright in the same place.
"""
import io
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from relight import relight, luma

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "sprites", "guns")

# Lettering on the pilot guns, in the drawn sprite's own pixels, used when the
# artist's guns.json gives no "stencil" for a gun.
STENCILS = {
    "kh20": [[26, 14, 10, 5]],
    "kh40": [[30, 27, 10, 7]],
    "km4": [[44, 22, 8, 5]],
}
# The on-ship size against the drawn one (Jon, Nov 17), and the shrink's alpha cut.
SCALE = 0.6
ALPHA_CUT = 0.45
COLOURS = 24
# An edge pixel lighter than this is a gap in the outline (the edge audit's measure).
EDGE_LUMA = 60
# A light (a charge slit, a muzzle lamp): this bright and this warm in the drawn gun. The
# shrink averages a thin one into the dark metal round it, so it is stamped back after.
LIGHT_LUMA = 200
LIGHT_WARM = 25
# Brighter than this inside a stencil box is a letter, not the panel under it.
INK = 140
# Flip the spinals (drawn for the belly) onto a top mount too. The relight is not
# trusted on them (notes.md), so a top-mounted spinal keeps its hold picture.
FLIP_BELLY_GUNS = False


def shrink(im, s):
    """Area shrink on premultiplied colour, hard alpha, the gun's own palette."""
    w, h = max(1, round(im.width * s)), max(1, round(im.height * s))
    a = np.asarray(im).astype(float)
    al = a[..., 3:] / 255.0
    pm = np.concatenate([a[..., :3] * al, a[..., 3:]], -1)
    sm = np.asarray(Image.fromarray(pm.astype(np.uint8)).resize((w, h), Image.BOX)).astype(float)
    A = sm[..., 3:] / 255.0
    rgb = np.where(A > 0, sm[..., :3] / np.maximum(A, 1e-6), 0)
    out = np.concatenate([np.clip(rgb, 0, 255), np.where(A > ALPHA_CUT, 255, 0)], -1).astype(np.uint8)
    o = Image.fromarray(out)
    q = o.convert("RGB").quantize(COLOURS).convert("RGBA")
    q.putalpha(o.getchannel("A"))
    return q


def close_outline(im):
    """Every opaque pixel with a clear neighbour is outline-dark; returns the light ones it fixed."""
    w, h = im.size
    p = im.load()
    darks = [p[x, y] for x in range(w) for y in range(h) if p[x, y][3] and luma(p[x, y]) <= EDGE_LUMA]
    ink = min(darks, key=luma) if darks else (20, 22, 28, 255)
    fixed = 0
    for y in range(h):
        for x in range(w):
            if not p[x, y][3] or luma(p[x, y]) <= EDGE_LUMA:
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if nx < 0 or ny < 0 or nx >= w or ny >= h or not p[nx, ny][3]:
                    p[x, y] = ink
                    fixed += 1
                    break
    return fixed


def light_edges(im):
    w, h = im.size
    p = im.load()
    n = 0
    for y in range(h):
        for x in range(w):
            if p[x, y][3] and luma(p[x, y]) > EDGE_LUMA and any(
                    nx < 0 or ny < 0 or nx >= w or ny >= h or not p[nx, ny][3]
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                n += 1
    return n


def lights(im):
    """The drawn gun's lights, each a 4-connected run: [(x0, y0, x1, y1, brightest colour)]."""
    w, h = im.size
    p = im.load()
    on = {(x, y) for x in range(w) for y in range(h)
          if p[x, y][3] and luma(p[x, y]) >= LIGHT_LUMA and p[x, y][0] - p[x, y][2] >= LIGHT_WARM}
    out = []
    while on:
        st = [on.pop()]
        run = []
        while st:
            q = st.pop()
            run.append(q)
            for n in ((q[0] + 1, q[1]), (q[0] - 1, q[1]), (q[0], q[1] + 1), (q[0], q[1] - 1)):
                if n in on:
                    on.discard(n)
                    st.append(n)
        xs = [x for x, _ in run]
        ys = [y for _, y in run]
        out.append((min(xs), min(ys), max(xs), max(ys), max((p[q] for q in run), key=luma)))
    return out


def stamp_lights(im, found, s, ink):
    """Each light back at full brightness on the shrunk cells that cover it, dark above and below."""
    w, h = im.size
    p = im.load()
    for x0, y0, x1, y1, c in found:
        sx0, sx1 = int(x0 * s), max(int(x0 * s), int(np.ceil((x1 + 1) * s)) - 1)
        sy0, sy1 = int(y0 * s), max(int(y0 * s), int(np.ceil((y1 + 1) * s)) - 1)
        for x in range(sx0, min(sx1 + 1, w)):
            for y in range(sy0, min(sy1 + 1, h)):
                p[x, y] = c
            for y in (sy0 - 1, sy1 + 1):
                if 0 <= y < h and p[x, y][3]:
                    p[x, y] = ink
    return len(found)


def other(side):
    return "belly" if side == "top" else "top"


def restamp(src, out, boxes):
    """Paint the flipped lettering out of `out` and stamp the source's upright."""
    w, h = src.size
    sp = src.load()
    op = out.load()
    for bx, by, bw, bh in boxes:
        ink = [(x, y) for x in range(bx, bx + bw) for y in range(by, by + bh)
               if 0 <= x < w and 0 <= y < h and sp[x, y][3] and luma(sp[x, y]) >= INK]
        if not ink:
            continue
        fy0 = h - by - bh
        # the panel under the letters, read off the relit copy's box
        ground = sorted((op[x, y] for x in range(bx, bx + bw) for y in range(fy0, fy0 + bh)
                         if 0 <= x < w and 0 <= y < h and op[x, y][3]
                         and 40 <= luma(op[x, y]) < INK), key=luma)
        fill = ground[len(ground) // 2] if ground else None
        for x, y in ink:
            fx, fyy = x, h - 1 - y
            if fill is not None:
                op[fx, fyy] = fill
        for x, y in ink:
            op[x, fy0 + (y - by)] = sp[x, y]
    return out


def install(src_dir):
    spec = json.load(io.open(os.path.join(src_dir, "guns.json"), encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    table = {}
    for gid in sorted(spec):
        if gid.startswith("_"):
            continue
        g = spec[gid]
        path = os.path.join(src_dir, "gun_%s.png" % gid)
        if not os.path.exists(path):
            print("  %-6s no gun_%s.png, skipped" % (gid, gid))
            continue
        drawn = Image.open(path).convert("RGBA")
        src = shrink(drawn, SCALE)
        fixed = close_outline(src)
        lit = lights(drawn)
        stamp_lights(src, lit, SCALE, min((c for c in src.get_flattened_data() if c[3]), key=luma))
        w, h = src.size
        side = g.get("side_drawn", "top")
        dax, day = int(g["anchor"][0]), int(g["anchor"][1])
        # (a top gun's contact row is the row past its foot: it stays the row past the shrunk foot)
        ax = round(dax * SCALE)
        ay = h if day >= drawn.height else round(day * SCALE)
        boxes = [[int(bx * SCALE), int(by * SCALE), int(np.ceil(bw * SCALE)) + 1, int(np.ceil(bh * SCALE)) + 1]
                 for bx, by, bw, bh in g.get("stencil", STENCILS.get(gid, []))]
        entry = {}
        name = "%s_%s.png" % (gid, side)
        src.save(os.path.join(OUT, name))
        entry[side] = {"file": name, "anchor": [ax, ay]}
        if side == "top" or FLIP_BELLY_GUNS:
            flip = relight(src)
            flip = restamp(src, flip, boxes)
            close_outline(flip)
            # (the lights, flipped with the gun, at full brightness again after the relight)
            dh = drawn.height
            stamp_lights(flip, [(x0, dh - 1 - y1, x1, dh - 1 - y0, c) for x0, y0, x1, y1, c in lit], SCALE,
                         min((c for c in flip.get_flattened_data() if c[3]), key=luma))
            fname = "%s_%s.png" % (gid, other(side))
            flip.save(os.path.join(OUT, fname))
            entry[other(side)] = {"file": fname, "anchor": [ax, h - ay]}
        table[gid] = entry
        print("  %-6s %3dx%-3d (drawn %dx%d) %-5s anchor %s  sides %s  lights %d  outline closed %d px, light edge px left %d"
              % (gid, w, h, drawn.width, drawn.height, side, (ax, ay), "/".join(sorted(entry)), len(lit), fixed,
                 light_edges(src) + (light_edges(Image.open(os.path.join(OUT, entry[other(side)]["file"])))
                                     if other(side) in entry else 0)))
    # a picture no longer made goes, with its import; the rest keep theirs
    made = {e["file"] for sides in table.values() for e in sides.values()}
    for f in os.listdir(OUT):
        png = f[:-len(".import")] if f.endswith(".import") else f
        if png.endswith(".png") and png not in made:
            os.remove(os.path.join(OUT, f))
    io.open(os.path.join(OUT, "guns.json"), "w", encoding="utf-8", newline="\n").write(
        json.dumps(table, indent=1, sort_keys=True) + "\n")
    print("wrote %d guns to %s" % (len(table), os.path.normpath(OUT)))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    install(sys.argv[1])
