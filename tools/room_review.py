"""Build the review sheet: a batch of room plates and backdrops, to keep or cut.

    python tools/room_review.py --stage DIR [--out tools/out/room-review.html]

THE BENCH IS FOR ARRANGING, THIS IS FOR JUDGING. Stepping through forty
candidates in the bench's dropdown is a click each way and no way to record a
verdict; this is a grid, a full-size view and two buttons, and it writes out
`room-picks.json` so the install knows what survived.

A BACKDROP IS JUDGED THROUGH THE HOLES. It is never seen whole in the game --
the wall covers all but the openings -- so the lightbox composites it behind the
real wall at the real opening rects, placed the way `StationRoom` places it:
centred, standing on the floor line.

Reads `plate_<name>.png` (already 740x431) and `bd_<name>.png` (already doubled)
out of a stage directory, the same names `room_bench.py --stage` takes.
"""

import base64
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TKG = os.path.abspath(os.path.join(HERE, "..", "tkg"))
STATION = os.path.join(TKG, "art", "sprites", "station")
TEMPLATE = os.path.join(HERE, "room_review.tmpl.html")

PANEL = (740, 431)
# The development levels, in order. A take named `plate_<level>_<x>` or
# `bd_<level>_<x>` is filed under its level; anything else under "other".
LEVELS = ["unclaimed", "outpost", "settlement", "city", "capital"]


def level_of(name):
    head = name.split("_")[0]
    return head if head in LEVELS else "other"
FLOOR_Y = 353
# The openings of the shop's first layout, as `room_bench.seed_layouts` builds
# them: the big window, the band over the rack, and the door.
OPENINGS = [[411, 108, 307, 183], [26, 108, 228, 110], [290, 203, 56, 150]]


# ART BESIDE THE PAGE, NOT INSIDE IT -- the same trade the bench made. Fifty
# doubled backdrops come to 2.3 MB of PNG, which is 3 MB of base64 in the
# markup and a page the viewer sits on before it draws. Published as files they
# arrive as the grid scrolls. `--inline` puts them back for a copy off disk.
ASSETS = {}
INLINE = "--inline" in sys.argv


def b64(path, name=None):
    if INLINE:
        with open(path, "rb") as f:
            return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")
    name = name or os.path.basename(path)
    ASSETS["art/" + name] = os.path.abspath(path)
    return "art/" + name


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def main():
    if "--stage" not in sys.argv:
        print(__doc__)
        return 2
    stage = sys.argv[sys.argv.index("--stage") + 1]
    out_path = os.path.join(HERE, "out", "room-review.html")
    if "--out" in sys.argv:
        out_path = sys.argv[sys.argv.index("--out") + 1]

    rooms, backdrops = [], []
    for f in sorted(os.listdir(stage)):
        path = os.path.join(stage, f)
        if f.startswith("plate_") and f.endswith(".png"):
            w, h = png_size(path)
            rooms.append({"kind": "room", "key": "plate_" + f[6:-4], "name": f[6:-4],
                          "level": level_of(f[6:-4]), "src": b64(path), "w": w, "h": h})
        elif f.startswith("bd_") and f.endswith(".png"):
            w, h = png_size(path)
            backdrops.append({"kind": "bd", "key": "bd_" + f[3:-4], "name": f[3:-4],
                              "level": level_of(f[3:-4]), "src": b64(path), "w": w, "h": h})
    # `--mates DIR`: rooms ALREADY KEPT, not up for a vote. A new backdrop is
    # shown in the wall behind one of these, the room it will really be seen
    # through, rather than behind a take that may itself be cut.
    mates = []
    if "--mates" in sys.argv:
        md = sys.argv[sys.argv.index("--mates") + 1]
        for f in sorted(os.listdir(md)):
            if f.startswith("plate_") and f.endswith(".png"):
                mates.append({"key": "mate_" + f[6:-4], "level": level_of(f[6:-4]),
                              "src": b64(os.path.join(md, f), "mate_" + f)})
    rnd = sys.argv[sys.argv.index("--round") + 1] if "--round" in sys.argv else "1"
    order = LEVELS + ["other"]
    rooms.sort(key=lambda r: (order.index(r["level"]), r["name"]))
    backdrops.sort(key=lambda r: (order.index(r["level"]), r["name"]))
    data = {"rooms": rooms, "backdrops": backdrops, "panel": PANEL, "floor_y": FLOOR_Y,
            "levels": order, "mates": mates, "round": rnd,
            "openings": OPENINGS, "wall": b64(os.path.join(STATION, "room_wall.png"))}
    html = io.open(TEMPLATE, encoding="utf-8").read()
    html = html.replace("__DATA__", json.dumps(data))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    io.open(out_path, "w", encoding="utf-8", newline="\n").write(html)
    print("room review  %s  %d KB  %d rooms, %d backdrops"
          % (out_path, os.path.getsize(out_path) // 1024, len(rooms), len(backdrops)))
    if ASSETS:
        man = os.path.join(os.path.dirname(out_path), "review-assets.json")
        io.open(man, "w", encoding="utf-8").write(
            json.dumps(ASSETS, indent=1, sort_keys=True))
        print("  %d files beside it, listed in %s" % (len(ASSETS), man))
    return 0


if __name__ == "__main__":
    sys.exit(main())
