"""Install the on-ship gun pictures from the artist's folder.

    uv run --with pillow python tkg/art/tools/ship_guns.py SRC_DIR

SRC_DIR holds gun_<id>.png and guns.json (per gun: side_drawn, anchor, and an
optional "stencil" list of [x, y, w, h] boxes). Re-run it after the artist drops
in new PNGs or new anchors; that is the whole update.

Writes tkg/art/sprites/guns/:
    <id>_<side>.png  the side the gun was drawn for, as drawn, and the other
                     side flipped and relit by relight.py (lit from above)
    guns.json        {id: {side: {file, anchor}}}, read by ShipGun.gd

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
# Brighter than this inside a stencil box is a letter, not the panel under it.
INK = 140
# Flip the spinals (drawn for the belly) onto a top mount too. The relight is not
# trusted on them (notes.md), so a top-mounted spinal keeps its hold picture.
FLIP_BELLY_GUNS = False


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
        src = Image.open(path).convert("RGBA")
        w, h = src.size
        side = g.get("side_drawn", "top")
        ax, ay = int(g["anchor"][0]), int(g["anchor"][1])
        entry = {}
        name = "%s_%s.png" % (gid, side)
        src.save(os.path.join(OUT, name))
        entry[side] = {"file": name, "anchor": [ax, ay]}
        if side == "top" or FLIP_BELLY_GUNS:
            flip = relight(src)
            flip = restamp(src, flip, g.get("stencil", STENCILS.get(gid, [])))
            fname = "%s_%s.png" % (gid, other(side))
            flip.save(os.path.join(OUT, fname))
            entry[other(side)] = {"file": fname, "anchor": [ax, h - ay]}
        table[gid] = entry
        print("  %-6s %3dx%-3d drawn %-5s anchor %s  sides %s"
              % (gid, w, h, side, (ax, ay), "/".join(sorted(entry))))
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
