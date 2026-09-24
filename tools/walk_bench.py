"""Build the walk-line bench: every backdrop, one at a time, lines drawn on it.

    python tools/walk_bench.py [--out tools/out/walk-lines.html]

WHY A SECOND BENCH. Walking lines are a fact about a PICTURE, not about a room
-- any room may draw any backdrop, so the lines have to be set per backdrop.
Doing that inside the room bench means switching the backdrop behind a room
twenty-five times and judging each one through whatever windows that layout
happens to have. Jon asked for it to be its own thing, and it is the right
shape: one picture at a time, whole, at the size the room draws it.

It writes `walk-lines.json`, keyed by backdrop id:

    {"format": "three-kelvin/walk-lines/1",
     "lines": {"bazaar": [{"y": 261, "tall": 84}, ...]}}

THE PEOPLE ARE NOT COPIED, THEY ARE LIFTED. `figure()` and `hash1()` come out
of `room_bench.tmpl.html` at build time and are injected here, so the walkers
you judge on this page are drawn by the same code that draws them in the room.
Copying them would have made a third renderer of the same thing, and this
repository has already paid twice for having two.
"""

import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TKG = os.path.abspath(os.path.join(HERE, "..", "tkg"))
STATION = os.path.join(TKG, "art", "sprites", "station")
BENCH = os.path.join(HERE, "room_bench.tmpl.html")   # people are lifted from here
TMPL = os.path.join(HERE, "walk_bench.tmpl.html")    # this page

# The same verdict the room bench keeps. A backdrop Jon cut is not a picture
# anyone should be spending an afternoon drawing lines on.
sys.path.insert(0, HERE)
from room_bench import CUT_BACKDROPS  # noqa: E402

ASSETS = {}


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return [int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")]


def _fn(src, name):
    """One JS function, whole, by matching its braces."""
    i = src.index("function %s(" % name)
    depth, j = 0, src.index("{", i)
    for k in range(j, len(src)):
        if src[k] == "{":
            depth += 1
        elif src[k] == "}":
            depth -= 1
            if depth == 0:
                return src[i:k + 1]
    raise SystemExit("walk_bench: %s() is unterminated in the room bench" % name)


def lifted():
    """`figure()` and `hash1()` out of the room bench, adapted to take a ctx.

    The room bench draws to one canvas held in a module-level `ctx`; this page
    draws the same people into a transformed context of its own. The ONLY
    change made here is that parameter -- anything else and the two would be
    different drawings again, which is the thing this exists to prevent.
    """
    src = io.open(BENCH, encoding="utf-8").read()
    fig = _fn(src, "figure")
    h1 = _fn(src, "hash1")
    fig = fig.replace("function figure(cx, feet, tall, h0, run, haze){",
                      "function figure(ctx, cx, feet, tall, h0, run, haze){", 1)
    if "function figure(ctx," not in fig:
        raise SystemExit("walk_bench: figure()'s signature changed -- "
                         "the lift needs updating")
    return ("// LIFTED FROM room_bench.tmpl.html AT BUILD TIME. Do not edit here.\n"
            + h1 + "\n" + fig + "\n"
            + "FIG.hash1 = hash1; FIG.figure = figure;")


def decks():
    p = os.path.join(STATION, "backdrop_decks.json")
    return json.load(io.open(p, encoding="utf-8")) if os.path.exists(p) else {}


def main():
    out_path = os.path.join(HERE, "out", "walk-lines.html")
    if "--out" in sys.argv:
        out_path = sys.argv[sys.argv.index("--out") + 1]
    dk = decks()
    wp = os.path.join(STATION, "backdrop_walk.json")
    drawn = json.load(io.open(wp, encoding="utf-8")) if os.path.exists(wp) else {}
    backdrops, seed = [], {}
    for f in sorted(os.listdir(STATION)):
        if not (f.startswith("backdrop_") and f.endswith(".png")):
            continue
        bid = f[9:-4]
        if bid in CUT_BACKDROPS:
            continue
        path = os.path.join(STATION, f)
        ASSETS["art/" + f] = os.path.abspath(path)
        size = png_size(path)
        backdrops.append({"id": bid, "src": "art/" + f, "size": size,
                          "deck": dk.get(bid, 0)})
        # THE LINES ALREADY DRAWN WIN OVER THE GUESS. `backdrop_walk.json` is
        # the work, kept in the repo; the deck is only what to open on for a
        # picture nobody has touched. Seeding from the guess when the real
        # answer exists would quietly hand back the starting point.
        if bid in drawn:
            seed[bid] = [{"y": l["y"], "tall": l["tall"]} for l in drawn[bid]]
        elif dk.get(bid):
            seed[bid] = [{"y": size[1] - dk[bid],
                          "tall": max(10, round(size[1] * 0.2))}]

    if not backdrops:
        raise SystemExit("walk_bench: no backdrops found in %s" % STATION)

    html = io.open(TMPL, encoding="utf-8").read()
    html = html.replace("/*DATA*/", json.dumps({"backdrops": backdrops,
                                                "seed": seed}, sort_keys=True))
    html = html.replace("/*FIGURE*/", lifted())
    if "/*DATA*/" in html or "/*FIGURE*/" in html:
        raise SystemExit("walk_bench: a placeholder was left unfilled")

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    io.open(out_path, "w", encoding="utf-8", newline="\n").write(html)
    man = os.path.join(os.path.dirname(out_path), "walk-assets.json")
    io.open(man, "w", encoding="utf-8").write(
        json.dumps(ASSETS, indent=1, sort_keys=True))
    nlines = sum(len(v) for v in seed.values())
    print("walk bench  %s  %.0f KB  %d backdrops, %d lines seeded (%d from "
          "work already drawn)"
          % (out_path, os.path.getsize(out_path) / 1024.0, len(backdrops),
             nlines, sum(len(v) for k, v in seed.items() if k in drawn)))
    print("  %d files beside it, listed in %s" % (len(ASSETS), man))

    # THE LIFT IS THE ONE THING THAT CAN ROT SILENTLY. If `figure()` moves or
    # is renamed in the room bench, this page keeps building with whatever it
    # last managed to grab -- so say out loud what came across.
    print("  people lifted from room_bench.tmpl.html: hash1(), figure()")


if __name__ == "__main__":
    main()
