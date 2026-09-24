"""The cast, standing on the deck at the size the room draws them.

    python tools/crowd_sheet.py <pull dir> [name ...]

Reads what `pixellab_pull.py` unpacked and writes `tools/out/crowd.html`.

WHY A STANDING SHEET AND NOT A WALKING ONE. A walk costs four generations and
a body costs one. Judging the bodies first means a face that is not wanted is
cut for one generation instead of five -- and more to the point, it is cut
before it has taken up a slot in a batch of seventy. The figures are trimmed to
their own ink and stood on a real walk line, because a character sheet floating
on white flatters everything equally.
"""

import base64
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "tkg", "art", "tools"))

import pixeltools  # noqa: E402

STATION = os.path.abspath(os.path.join(HERE, "..", "tkg", "art", "sprites",
                                       "station"))
TMPL = os.path.join(HERE, "crowd_sheet.tmpl.html")
OUT = os.path.join(HERE, "out", "crowd.html")
DECK = "vending"
RUNG = 80


def uri(path):
    return ("data:image/png;base64,"
            + base64.b64encode(io.open(path, "rb").read()).decode("ascii"))


def trimmed(path, scratch):
    """The figure cut to its own ink, and how tall that ink is."""
    w, h, rows = pixeltools.decode(path)
    bb = pixeltools.bbox(w, h, rows)
    cw, ch = bb[2] - bb[0] + 1, bb[3] - bb[1] + 1
    # crop() hands back (w, h, rows), not bare rows.
    cw, ch, cropped = pixeltools.crop(w, h, rows, bb[0], bb[1], cw, ch)
    pixeltools.encode(scratch, cw, ch, cropped)
    return cw, ch


def main(argv):
    pull = argv[0]
    names = argv[1:] or sorted(
        d for d in os.listdir(pull) if os.path.isdir(os.path.join(pull, d)))

    scratch = os.path.join(HERE, "out", "_crop")
    os.makedirs(scratch, exist_ok=True)

    cast = []
    for n in names:
        rot = os.path.join(pull, n, "Idle", "rotations", "east.png")
        if not os.path.exists(rot):
            print("  %-12s no east rotation, skipped" % n)
            continue
        cut = os.path.join(scratch, n + ".png")
        w, h = trimmed(rot, cut)
        cast.append({"name": n, "src": uri(cut), "w": w, "h": h,
                     "over": round(100.0 * (h - RUNG) / RUNG)})
        print("  %-12s %2d x %-3d  %+d%% of the %dpx line" % (n, w, h,
                                                             cast[-1]["over"],
                                                             RUNG))

    import json
    page = io.open(TMPL, encoding="utf-8").read()
    page = page.replace('"/*BD*/"', json.dumps(uri(os.path.join(
        STATION, "backdrop_%s.png" % DECK))))
    page = page.replace('"/*CAST*/"', json.dumps(cast))
    page = page.replace("/*RUNG*/", str(RUNG))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(page)
    print("\n%d in the sheet -> %s (%.0f KB)"
          % (len(cast), OUT, os.path.getsize(OUT) / 1024.0))


if __name__ == "__main__":
    main(sys.argv[1:])
