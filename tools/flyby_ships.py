"""The ships that pass the Exchange's windows, made small from Jon's kept pool.

    python tools/flyby_ships.py      # writes tkg/art/sprites/station/flyby/

WHAT GOES BY. Jon asked for the Exchange's view to be space "with maybe ships
in the back flying past occasionally" (2026-09-27). The ships are his: the
kept half of the pool in `tools/art_pool/ships`, in the orientation he judged
them in (`picks.json`), which faces them left -- so every pass runs right to
left, one lane of traffic, and nothing he judged is mirrored. Only what makes
sense going past a trading station is taken: traders, freighters, tankers,
shuttles, liners, market ships, tugs and a patrol boat. The organic, the
crystal, the rings and the swarm stay in the pool (see `TRAFFIC`).

SMALL, BECAUSE THEY ARE FAR. The pool's ships are about 200px long, as wide as
a window. Each is made at a third (`near`, about 70px) and a quarter (`far`,
about 50px) by averaging whole blocks of pixels -- light weighted by how opaque
it is -- then cutting the edge at half cover and snapping every colour back to
the ship's own palette, so the result is pixel art at its size rather than a
blur of the big one. The game dims and cools the far ones (`ExchangeScene`).
"""

import io
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
POOL = os.path.join(HERE, "art_pool")
OUT = os.path.join(HERE, "..", "tkg", "art", "sprites", "station", "flyby")

TRAFFIC = [
    "armedtrader", "asteroidtow", "barnook", "bigdish", "bored", "catamaran", "cl_drums",
    "cl_stack", "cl_tree", "courier2", "dropship", "fm_domes", "forked", "gunboat", "hp_pods",
    "hp_wards", "lattice", "lightfreighter", "liner", "lrshuttle", "mk_arcade", "mk_awning",
    "mkt_dome", "mkt_slung", "modulepush", "orbitarms", "pr_drum", "rf_pipes", "ringdrive",
    "ringspine", "rl_double", "rly_dishes", "science", "scoop",
]
DEPTHS = {"near": 3, "far": 4}
PALETTE = 24


def trim(a):
    ys, xs = np.nonzero(a[..., 3] > 0)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def palette(a, n):
    """The ship's own colours, its `n` commonest opaque ones."""
    px = a[a[..., 3] > 127][:, :3]
    cols, counts = np.unique(px, axis=0, return_counts=True)
    return cols[np.argsort(-counts)[:n]].astype(np.float64)


def reduce(a, k, pal):
    """`a` at 1/k: block-averaged, edge cut at half cover, snapped to `pal`."""
    h, w = a.shape[:2]
    H, W = (h + k - 1) // k, (w + k - 1) // k
    pad = np.zeros((H * k, W * k, 4), np.float64)
    pad[:h, :w] = a
    al = pad[..., 3:] / 255.0
    blocks = lambda v: v.reshape(H, k, W, k, -1).sum(axis=(1, 3))
    cover = blocks(al)[..., 0] / (k * k)
    rgb = blocks(pad[..., :3] * al) / np.maximum(blocks(al), 1e-9)
    out = np.zeros((H, W, 4), np.uint8)
    on = cover >= 0.5
    d = ((rgb[on][:, None, :] - pal[None, :, :]) ** 2).sum(-1)
    out[on, :3] = pal[np.argmin(d, axis=1)].astype(np.uint8)
    out[on, 3] = 255
    return trim(out)


def main():
    picks = json.load(io.open(os.path.join(POOL, "picks.json"), encoding="utf-8"))["ships"]
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png") or f == "flyby.json":
            os.remove(os.path.join(OUT, f))
    ships = []
    for name in TRAFFIC:
        v = picks.get(name, {})
        if v.get("verdict") != "keep":
            raise SystemExit("flyby_ships: %s is not a kept ship" % name)
        im = Image.open(os.path.join(POOL, "ships", name + ".png")).convert("RGBA")
        if v.get("flip"):
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        a = trim(np.array(im))
        pal = palette(a, PALETTE)
        e = {"name": name, "facing": -1}
        for depth, k in DEPTHS.items():
            small = reduce(a, k, pal)
            fn = "%s_%s.png" % (name, depth)
            Image.fromarray(small, "RGBA").save(os.path.join(OUT, fn))
            e[depth] = fn
            e[depth + "_size"] = [int(small.shape[1]), int(small.shape[0])]
        ships.append(e)
        print("  %-15s near %-8s far %s" % (name, "%dx%d" % tuple(e["near_size"]),
                                              "%dx%d" % tuple(e["far_size"])))
    with io.open(os.path.join(OUT, "flyby.json"), "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps({"source": "tools/flyby_ships.py", "ships": ships}, indent=1) + "\n")
    print("flyby_ships: %d ships in %s" % (len(ships), os.path.relpath(OUT, os.path.join(HERE, ".."))))


if __name__ == "__main__":
    main()
