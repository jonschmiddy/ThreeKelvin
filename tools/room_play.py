"""The room, moving, as a page.

    python tools/room_play.py <frame dir> [--crop x,y,w,h] [--label "..."]

`stationshot ... frames=N` writes `station_<berth>_fNN.png` a twelfth of a
second apart. This inlines them and plays them back, with a 2x view and a crop
box, so the walkers can be watched in the actual room rather than inferred from
a still.

A STILL CANNOT SHOW THAT A WALKER WALKS. That is the whole reason the frame
mode exists in `StationShot`, and every check on the crowd so far has been a
single frame of a thing whose entire job is to move.
"""

import base64
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TMPL = os.path.join(HERE, "room_play.tmpl.html")
OUT = os.path.join(HERE, "out", "room-play.html")


def main(argv):
    src = argv[0]
    crop = None
    label = "the shop deck"
    for a in argv[1:]:
        if a.startswith("--crop"):
            crop = [int(v) for v in a.split("=", 1)[1].split(",")]
        elif a.startswith("--label"):
            label = a.split("=", 1)[1]

    names = sorted(f for f in os.listdir(src)
                   if re.match(r"station_.*_f\d\d\.png$", f))
    if not names:
        raise SystemExit("room_play: no station_*_fNN.png in %s" % src)

    # CROPPED HERE, NOT IN THE PAGE. Passing the whole 1920x1080 shot and
    # cropping in canvas meant inlining 33MB for a 16MB ceiling, most of it
    # chrome nobody is looking at.
    frames = []
    scratch = os.path.join(HERE, "out", "_play_frame.png")
    for n in names:
        path = os.path.join(src, n)
        if crop:
            w, h, rows = pixeltools.decode(path)
            cw, ch, cut = pixeltools.crop(w, h, rows, crop[0], crop[1],
                                          min(crop[2], w - crop[0]),
                                          min(crop[3], h - crop[1]))
            pixeltools.encode(scratch, cw, ch, cut)
            path = scratch
        d = io.open(path, "rb").read()
        frames.append("data:image/png;base64,"
                      + base64.b64encode(d).decode("ascii"))
    if os.path.exists(scratch):
        os.remove(scratch)
    crop = None  # already applied; the page shows what it is given

    page = io.open(TMPL, encoding="utf-8").read()
    page = page.replace('"/*FRAMES*/"', json.dumps(frames))
    page = page.replace('"/*CROP*/"', json.dumps(crop))
    page = page.replace("/*LABEL*/", label)
    page = page.replace("/*N*/", str(len(frames)))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(page)
    print("%d frames -> %s (%.1f MB)"
          % (len(frames), OUT, os.path.getsize(OUT) / 1048576.0))


if __name__ == "__main__":
    main(sys.argv[1:])
