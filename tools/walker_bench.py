"""Put walk cycles on a treadmill so they can be judged, not read about.

    python tools/walker_bench.py [name ...]

Defaults to every strip in `walker_strips.json`. Writes `tools/out/walkers.html`,
which is what gets published.

THE PAGE IS THE POINT. Every number this repo has about a walk cycle -- stride,
foot wander, head hold, frame rate -- is measured on a sprite strip lying flat.
None of them is a measurement of a small figure crossing a lit deck, which is
the only place these walkers are ever seen. The 12-frame cycle scored better
than the 8 on faulty frames and looked worse; the count that decided it was
frames per SECOND, which no per-frame score can see.

So this inlines each strip beside the backdrop it will actually walk on, at 1x,
at its own measured stride, and says the numbers underneath rather than on top.
"""

import base64
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from walker_install import WALK_PACE  # noqa: E402  the one place the pace lives

STATION = os.path.abspath(os.path.join(HERE, "..", "tkg", "art", "sprites",
                                       "station"))
INDEX = os.path.join(STATION, "walker_strips.json")
WALK = os.path.join(STATION, "backdrop_walk.json")
TMPL = os.path.join(HERE, "walker_bench.tmpl.html")
OUT = os.path.join(HERE, "out", "walkers.html")

# The deck every walker is shown on. Chosen because its walk lines already
# carry one line at each rung, so a 60 and an 80 can be compared standing on
# the ground they were sized for rather than on a line invented here.
DECK = "vending"


def _band(m):
    lo, hi = m.get("within_3pct", [m["advance"], m["advance"]])
    return round(100.0 * (hi - lo) / float(m["advance"]), 1) if m["advance"] else 0.0


def uri(path):
    d = io.open(path, "rb").read()
    return "data:image/png;base64," + base64.b64encode(d).decode("ascii")


def main(argv):
    idx = json.load(io.open(INDEX, encoding="utf-8"))
    names = argv or sorted(idx)
    missing = [n for n in names if n not in idx]
    if missing:
        raise SystemExit("walker_bench: not in walker_strips.json: %s"
                         % ", ".join(missing))

    lines = json.load(io.open(WALK, encoding="utf-8"))[DECK]

    walkers = []
    for pos, n in enumerate(names):
        m = idx[n]
        strip = os.path.join(STATION, "walker_%s.png" % n)
        if not os.path.exists(strip):
            raise SystemExit("walker_bench: %s is in the index with no PNG "
                             "beside it" % n)
        # Stand each walker on the line closest to its own height, and say
        # which line that was -- a walker drawn on a rung it was not sized for
        # is the comparison quietly answering a different question.
        best = min(lines, key=lambda L: abs(L["tall"] - m["frame_h"]))
        walkers.append({
            "id": "w_" + n,
            "name": n,
            # A letter per row, so the answer can be one character rather than
            # a sentence about which strip was meant.
            "pick": "ABCDEFGH"[pos],
            "src": uri(strip),
            "n": m["frames"],
            "w": m["frame_w"],
            "h": m["frame_h"],
            "adv": m["advance"],
            "cycle": m["cycle"],
            "foot": "%d/%d" % (m.get("foot_wander", 0), m["frames"]),
            "fps": round(WALK_PACE / float(m["advance"]), 2),
            "rung": best["tall"],
            "y": best["y"],
            "over": round(100.0 * (m["frame_h"] - best["tall"]) / best["tall"]),
            # How wide the band of strides that fit this cycle nearly equally
            # well is. Wide means nobody could pin the advance down, and an
            # unpinnable stride is a boot that skates. Calibrated against the
            # walkers Jon has ruled on: 0-6% clean, 19% "the foot slips",
            # 33% "glitching out".
            "band": _band(m),
            "skate": round(100 * m.get("skate", 0)),
        })

    page = io.open(TMPL, encoding="utf-8").read()
    page = page.replace('"/*BD*/"', json.dumps(uri(os.path.join(
        STATION, "backdrop_%s.png" % DECK))))
    page = page.replace('"/*WALKERS*/"', json.dumps(walkers))
    page = page.replace("/*DECK*/", DECK)
    page = page.replace("/*PACE*/", str(WALK_PACE))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(page)

    print("walkers: %s" % ", ".join(names))
    for k in walkers:
        print("  %-9s %2df  %2dx%-3d  %5.2fpx/frame  %.1f fps  foot %-5s "
              "on the %dpx line (%+d%%)"
              % (k["name"], k["n"], k["w"], k["h"], k["adv"], k["fps"],
                 k["foot"], k["rung"], k["over"]))
    print("  -> %s (%.0f KB)" % (OUT, os.path.getsize(OUT) / 1024.0))


if __name__ == "__main__":
    main(sys.argv[1:])
