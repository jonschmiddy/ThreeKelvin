"""Build the backdrop-heights page: each backdrop behind a room of its level.

    python tools/height_bench.py [--out tools/out/heights]

WHY ITS OWN PAGE. Jon asked for it (2026-09-25). A backdrop's height is a
fact about the picture -- where its floor is drawn -- and any room of its level
may show it, so it is set once per backdrop, not per layout. The room bench
kept it in browser storage, where neither the game nor Claude could read it.
This page keeps it in the artifact's `db` store instead, collection `heights`,
one document per backdrop: {"drop": N}, pixels moved DOWN from the default of
the picture's bottom edge on the room's floor line (negative is up).

Writes `<out>/index.html` and copies the art beside it under `art/`.
"""

import io
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STATION = os.path.abspath(os.path.join(HERE, "..", "tkg", "art", "sprites", "station"))
STAGE = os.path.join(HERE, "room_stage")
sys.argv += [] if "--stage" in sys.argv else ["--stage", STAGE]
sys.path.insert(0, HERE)
from room_bench import VIEWS, DEV  # noqa: E402


def size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return [int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")]


def main():
    out = os.path.join(HERE, "out", "heights")
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    art = os.path.join(out, "art")
    os.makedirs(art, exist_ok=True)
    decks = json.load(io.open(os.path.join(STATION, "backdrop_decks.json"), encoding="utf-8"))
    plates = json.load(io.open(os.path.join(STAGE, "plates.json"), encoding="utf-8"))
    backdrops = []
    for v in VIEWS:
        f = "backdrop_%s.png" % v
        shutil.copy(os.path.join(STATION, f), os.path.join(art, f))
        backdrops.append({"id": v, "level": v.split("_")[0], "src": "art/" + f,
                          "size": size(os.path.join(STATION, f)), "deck": decks.get(v, 0)})
    rooms = dict((lv, []) for lv in DEV)
    for pid in sorted(plates):
        f = "plate_%s.png" % pid
        shutil.copy(os.path.join(STAGE, f), os.path.join(art, f))
        rooms[plates[pid]["level"]].append({"id": pid, "src": "art/" + f})
    data = {"backdrops": backdrops, "rooms": rooms}
    html = io.open(os.path.join(HERE, "height_bench.tmpl.html"), encoding="utf-8").read()
    html = html.replace("__DATA__", json.dumps(data))
    io.open(os.path.join(out, "index.html"), "w", encoding="utf-8", newline="\n").write(html)
    files = sorted("art/" + f for f in os.listdir(art))
    print("heights  %s  %d backdrops, %d rooms, %d files"
          % (out, len(backdrops), sum(len(r) for r in rooms.values()), len(files)))


if __name__ == "__main__":
    main()
