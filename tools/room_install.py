"""Install Jon's shop rooms into the game, lit the way the room bench lights them.

    python tools/room_install.py            # install (needs numpy and Pillow)
    python tools/room_install.py --check    # is the game's copy what the stage holds?

THE SOURCE IS HIS EXPORT. `tools/room_stage/room-layouts.json` is what the room
bench saved when Jon called the fifteen rooms final (2026-09-27, "OK final
layout. Install these into the game."), and nothing here decides anything about
a room: where a thing stands, which band it is drawn in, how bright a lamp
burns, all of it is read out of that file. What this adds is only what the game
cannot work out for itself fast enough.

WHAT IT WRITES, all of it under `tkg/art/sprites/station/rooms/`, which this
tool owns outright -- it empties the folder before it writes, so a room that
leaves the export leaves the game:

  rooms.json        every room: its plate, what is drawn behind the rack and the
                    counter and what in front of them, where those two stand,
                    its lamps, and how its light is made
  *.png             the art those rooms use, at the size it is drawn. A prop set
                    to 125% is baked at 125% here, by the bench's own nearest-
                    neighbour rule, so the game draws every sprite 1:1 and can
                    never resample one differently
  light_<room>.lmap the room's light, worked out here once (see LIGHT)

LIGHT. The bench lights a room per pixel: every lamp casts rays against what is
standing on the deck, each opening glows the colour of the place behind it,
lit panels throw their own colour, the light bounces, and the result scales the
art. That is ten to thirty light sources over eighty thousand light-map cells --
about 20 ms in the browser's JIT and seconds in GDScript. None of it depends on
anything the game decides at run time except two things, so it is computed
here and stored in pieces that the game recombines per pixel on the GPU:

  S  (rgb)  every source that never changes: steady lamps, the running lights
            on opening frames, lit panels and strings of bulbs
  O         the openings' glow at unit colour. The colour is the BACKDROP's --
            `backdropTone` -- and the game draws the backdrop at random from
            the station's level, so it multiplies O by that tone itself
  F         a failing lamp's light at full power (three rooms have one). The
            game scales it by the fault's brightness and colour each frame
  U         how completely that lamp's shadow covers a pixel, per unit power
  B         the steady lamps' shadow coverage
  X         how far a pixel is exempt from the room's light: the view through
            an opening is somewhere else, and its own light is its own

Everything after the bounce is linear in those pieces, which is what lets them
be split: the bounce is a blur added back, and a blur of a sum is the sum of
the blurs. `tools/room_bench.tmpl.html` is the reference; the constants below
are read out of it rather than restated, so the two cannot drift.

A light file (`.lmap`) is a PNG: four GW x GH bands stacked top to bottom,
the high then low bytes of (S.r, S.g, S.b, O) and of (F, U, B, X) as 16-bit
fixed point over the ranges in `SCALES`, which rooms.json repeats.
"""

import hashlib
import io
import json
import math
import os
import re
import shutil
import sys

# NOT NEEDED TO CHECK. `--check` runs in the merge gate, which has neither.
try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover
    np = None
    Image = None

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
TKG = os.path.join(REPO, "tkg")
STATION = os.path.join(TKG, "art", "sprites", "station")
STAGE = os.path.join(HERE, "room_stage")
EXPORT = os.path.join(STAGE, "room-layouts.json")
BENCH = os.path.join(HERE, "room_bench.tmpl.html")
OUT = os.path.join(STATION, "rooms")
ROOMS_JSON = os.path.join(OUT, "rooms.json")

W, H, FLOOR = 740, 431, 353
# The bezel a window's nine-slice hangs outside its glass, as `T` in the bench.
T = 12
# The rack and its stock are drawn at 1x and pixel-doubled, as the bench's
# `shelf_scale` has it: parts at the hold's own 40px cell.
SHELF_K = 2
LEVELS_ORDER = ["unclaimed", "outpost", "settlement", "city", "capital"]
FRAMES = {"chamfer": ("frame_window.png", 18), "round": ("frame_window_round.png", 24),
          "octa": ("frame_window_octa.png", 24)}
STANDARD_BOARDS = [59, 122]


# ------------------------------------------------------------------ the bench

def _bench_src():
    return io.open(BENCH, encoding="utf-8").read()


def _num(src, name):
    m = re.search(r"var %s = (-?[0-9.]+)" % name, src) or \
        re.search(r"[ ,]%s = (-?[0-9.]+)" % name, src)
    if not m:
        raise SystemExit("room_install: %s is gone from the bench" % name)
    return float(m.group(1))


def _table(src, name):
    m = re.search(r"var %s = \{(.*?)\};" % name, src, re.S)
    if not m:
        raise SystemExit("room_install: %s is gone from the bench" % name)
    body = re.sub(r"//[^\n]*", "", m.group(1))
    return dict((k, float(v)) for k, v in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([0-9.]+)", body))


def bench_constants():
    """The lighting constants, read out of the bench so they cannot drift."""
    src = _bench_src()
    amb = re.search(r"var AMB_COL = \[([^\]]*)\]", src)
    bayer = re.search(r"var BAYER = \[([^\]]*)\]", src)
    return {
        "GK": int(_num(src, "GK")),
        "LEVELS": int(_num(src, "LEVELS")),
        "SOFT": _num(src, "SOFT"),
        "AMB_COL": [float(v) for v in amb.group(1).split(",")],
        "BAYER": [int(v) for v in bayer.group(1).split(",")],
        "BOUNCE": _num(src, "BOUNCE"),
        "BLUR": int(_num(src, "BLUR")),
        "RAYS": int(_num(src, "RAYS")),
        "OPEN_GLOW": _num(src, "OPEN_GLOW"),
        "OPEN_REACH": _num(src, "OPEN_REACH"),
        "PROP_GLOW": _table(src, "PROP_GLOW"),
        "STRING_GLOW": _table(src, "STRING_GLOW"),
        "REFLECT_ALPHA": _num(src, "REFLECT_ALPHA"),
    }


C = bench_constants()
GK = C["GK"]
GW, GH = int(math.ceil(W / GK)), int(math.ceil(H / GK))


# ------------------------------------------------------------------- pictures

def load(path):
    return np.array(Image.open(path).convert("RGBA"))


def save(path, a):
    Image.fromarray(np.ascontiguousarray(a), "RGBA").save(path, optimize=True)


def _src_index(n_dst, sw, dw):
    """Which source column each destination column samples, the bench's way.

    NEAREST, FROM THE PIXEL CENTRE, and a centre that lands exactly on a source
    boundary takes the pixel BEFORE it. Measured against Chrome drawing the
    bench's own tills and props: that is what it does in all but the cases its
    float rounding tips the other way, which differ by one duplicated row or
    column and are not visible at 2x.
    """
    i = np.arange(n_dst, dtype=np.float64)
    u = np.ceil((i + 0.5) * sw / dw) - 1
    return np.clip(u, 0, sw - 1).astype(np.int64)


def _span(d):
    """How many whole pixels a box d long covers, from a whole-pixel origin.

    A PIXEL IS IN THE BOX WHEN ITS CENTRE IS, and a centre exactly on the far
    edge counts while one on the near edge does not -- measured in Chrome, which
    draws a counter 127.5 tall as 128 full rows and never a half-lit one.
    """
    return int(math.floor(d - 0.5)) + 1


def scale_to(a, dw, dh):
    """`a` drawn into a dw x dh box at nearest neighbour, as drawImage does it."""
    sh, sw = a.shape[:2]
    if dw == sw and dh == sh:
        return a.copy()
    return a[_src_index(_span(dh), sh, dh)][:, _src_index(_span(dw), sw, dw)].copy()


def lum(a):
    return 0.299 * a[..., 0].astype(np.float64) + 0.587 * a[..., 1] + 0.114 * a[..., 2]


def _components(on, conn):
    """Connected regions of a boolean mask: a list of (ys, xs) index arrays.

    `conn` is 4 for edge neighbours, or an int radius r for every pixel within
    r both ways (the bench's pilot finder joins across a 5x5 window).
    """
    h, w = on.shape
    seen = np.zeros_like(on, dtype=bool)
    out = []
    if conn == 4:
        steps = [(0, -1), (0, 1), (-1, 0), (1, 0)]
    else:
        steps = [(dy, dx) for dy in range(-conn, conn + 1) for dx in range(-conn, conn + 1)
                 if dy or dx]
    for y0, x0 in zip(*np.nonzero(on)):
        if seen[y0, x0]:
            continue
        seen[y0, x0] = True
        stack, ys, xs = [(y0, x0)], [], []
        while stack:
            y, x = stack.pop()
            ys.append(y)
            xs.append(x)
            for dy, dx in steps:
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and on[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        out.append((np.array(ys), np.array(xs)))
    return out


# ---------------------------------------------------------- what lights up

def emitters(a):
    """Where a lamp sprite's light comes out: `emitters()` in the bench."""
    h, w = a.shape[:2]
    L = lum(a)
    opaque = a[..., 3] >= 40
    best = []
    for x in range(w):
        col = np.where(opaque[:, x], L[:, x], -1.0)
        if col.max() <= 0:
            best.append((0.0, 0))
            continue
        # strictly brighter wins, so the topmost of equals
        y = int(np.argmax(col))
        best.append((float(col[y]), y))
    peak = max(b[0] for b in best)
    lit = [b[0] >= max(90, peak * 0.80) for b in best]
    runs, run = [], None
    for x in range(w):
        if lit[x]:
            if run is None:
                run = [x, x]
            else:
                run[1] = x
        elif run is not None and x - run[1] > 2:
            runs.append(run)
            run = None
    if run is not None:
        runs.append(run)
    runs = [r for r in runs if r[1] - r[0] >= 2]
    out = []
    for ra, rb in runs:
        mid = (ra + rb) / 2.0
        low = max(best[x][1] for x in range(ra, rb + 1))
        out.append({"cx": mid + 0.5, "half": max(3.0, (rb - ra + 1) / 2.0), "y": low + 1})
    if not out:
        out = [{"cx": w / 2.0, "half": max(3.0, w * 0.40), "y": float(h)}]
    return out


def lamp_glass(a, col, gl):
    """The lit glass of a lamp sprite, tinted: `lampStates()` in the bench."""
    L = lum(a)
    ok = a[..., 3] >= 40
    peak = float(L[ok].max()) if ok.any() else 0.0
    hi, lo = peak * 0.72, peak * 0.40
    seed = ok & (L >= hi)
    grow = ok & (L >= lo)
    mask = np.zeros_like(seed)
    for ys, xs in _components(grow, 1):
        if seed[ys, xs].any():
            mask[ys, xs] = True
    span = max(1.0, peak - lo)
    t = np.clip((L - lo) / span, 0.0, 1.0)
    tint = np.array([int(col[1:3], 16), int(col[3:5], 16), int(col[5:7], 16)], np.float64)
    out = np.zeros_like(a)
    sel = mask & ok & (t > 0)
    rgb = a[..., :3].astype(np.float64) * tint / 255.0 * gl
    # a canvas clamps and rounds half to even as it stores
    out[..., :3] = np.where(sel[..., None], np.clip(np.round(rgb), 0, 255), 0).astype(np.uint8)
    out[..., 3] = np.where(sel, np.round(a[..., 3] * t), 0).astype(np.uint8)
    return out


def _is_lit(a):
    R, G, B = (a[..., i].astype(np.int64) for i in range(3))
    lu = 0.299 * R + 0.587 * G + 0.114 * B
    sat = np.max(a[..., :3], axis=-1).astype(np.int64) - np.min(a[..., :3], axis=-1)
    return (a[..., 3] >= 40) & ((lu >= 150) | ((lu >= 110) & (sat >= 45)))


def lit_keep(a):
    """The pixels of a prop that are lit from inside: `litKeep()`."""
    keep = np.zeros(a.shape[:2], bool)
    for ys, xs in _components(_is_lit(a), 4):
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        if len(ys) < 40 or bw < 6 or bh < 6 or len(ys) / float(bw * bh) < 0.25:
            continue
        keep[ys, xs] = True
    return keep


def lit_face(a):
    kp = lit_keep(a)
    n = int(kp.sum())
    if n < 12:
        return None
    ys, xs = np.nonzero(kp)
    s = a[kp][:, :3].astype(np.float64).sum(axis=0) / n
    mx = s.max() or 1.0
    return {"cx": (xs.min() + xs.max() + 1) / 2.0, "cy": (ys.min() + ys.max() + 1) / 2.0,
            "halfW": (xs.max() - xs.min() + 1) / 2.0, "halfH": (ys.max() - ys.min() + 1) / 2.0,
            "rgb": list(s / mx)}


def lit_spots(a):
    out = []
    for ys, xs in _components(_is_lit(a), 4):
        n = len(ys)
        if n < 4:
            continue
        s = a[ys, xs][:, :3].astype(np.float64).sum(axis=0) / n
        mx = s.max() or 1.0
        out.append({"cx": xs.mean() + 0.5, "cy": ys.mean() + 0.5, "rgb": list(s / mx)})
    return out


def lit_pixels(a):
    kp = lit_keep(a)
    if kp.sum() < 12:
        return None
    out = a.copy()
    out[~kp, 3] = 0
    out[~kp, :3] = 0
    return out


def pilots(a):
    """Running lights painted on an opening's frame: `pilots()`."""
    mx = a[..., :3].max(axis=-1).astype(np.int64)
    mn = a[..., :3].min(axis=-1).astype(np.int64)
    on = (a[..., 3] >= 40) & (mx - mn >= 60) & (lum(a) >= 80)
    out = []
    for ys, xs in _components(on, 2):
        n = len(ys)
        if n < 10 or n > 620:
            continue
        s = a[ys, xs][:, :3].astype(np.float64).sum(axis=0) / n
        m = s.max() or 1.0
        out.append({"cx": xs.mean(), "cy": ys.mean(),
                    "half": max(2.0, (xs.max() - xs.min() + 1) / 2.0), "n": n, "rgb": list(s / m)})
    out.sort(key=lambda p: -p["n"])
    return out[:4]


def backdrop_tone(a):
    """The colour a backdrop throws through an opening: `backdropTone()`.

    The bench shrinks the picture to 32x18 with smoothing on and averages
    that. Chrome's shrink is its own; four halvings and a bilinear tap per
    cell comes within 0.012 of it on every backdrop the game draws (measured
    against the bench's own numbers), where the plain mean was 0.025 off.
    """
    img = a[..., :3].astype(np.float64)
    for _ in range(4):
        h2, w2 = img.shape[0] // 2 * 2, img.shape[1] // 2 * 2
        img = (img[0:h2:2, 0:w2:2] + img[1:h2:2, 0:w2:2] +
               img[0:h2:2, 1:w2:2] + img[1:h2:2, 1:w2:2]) / 4
    sh, sw = img.shape[:2]
    j = (np.arange(18) + 0.5) * sh / 18 - 0.5
    i = (np.arange(32) + 0.5) * sw / 32 - 0.5
    y0, x0 = np.floor(j).astype(int), np.floor(i).astype(int)
    fy, fx = (j - y0)[:, None, None], (i - x0)[None, :, None]
    Y0, Y1 = np.clip(y0, 0, sh - 1), np.clip(y0 + 1, 0, sh - 1)
    X0, X1 = np.clip(x0, 0, sw - 1), np.clip(x0 + 1, 0, sw - 1)
    c = (img[Y0][:, X0] * (1 - fx) * (1 - fy) + img[Y0][:, X1] * fx * (1 - fy) +
         img[Y1][:, X0] * (1 - fx) * fy + img[Y1][:, X1] * fx * fy)
    s = np.floor(c + 0.5).reshape(-1, 3).mean(axis=0)
    mx = s.max() or 1.0
    out = s / mx
    av = out.mean()
    out = av + (out - av) * 1.9
    return [float(v) for v in np.clip(out, 0.0, 1.0)]


# -------------------------------------------------------------- the stage

class Stage:
    """Every picture the bench can put in a room, found the way it finds them."""

    def __init__(self):
        self.props, self.lampskins, self.doors, self.tills, self.racks = {}, {}, {}, {}, {}
        self.plates = {}
        for f in sorted(os.listdir(STAGE)):
            p = os.path.join(STAGE, f)
            if not f.endswith(".png"):
                continue
            if f.startswith("prop_"):
                layer, name = f[5:-4].split("_", 1)
                self.props[name] = (p, layer)
            elif f.startswith("lampskin_"):
                self.lampskins[f[9:-4]] = p
            elif f.startswith("door_"):
                self.doors[f[5:-4]] = p
            elif f.startswith("till_"):
                self.tills[f[5:-4]] = p
            elif f.startswith("rack2_"):
                self.racks[f[6:-4]] = p
            elif f.startswith("plate_"):
                self.plates[f[6:-4]] = p
        bj = os.path.join(STAGE, "rack_boards.json")
        self.boards = json.load(io.open(bj, encoding="utf-8")) if os.path.exists(bj) else {}
        self.holes = json.load(io.open(os.path.join(STATION, "opening_holes.json"), encoding="utf-8"))
        self._img = {}

    def img(self, path):
        if path not in self._img:
            self._img[path] = load(path)
        return self._img[path]

    def opening(self, skin):
        p = os.path.join(STAGE, "open_%s.png" % skin)
        if not os.path.exists(p):
            p = os.path.join(STATION, "opening_%s.png" % skin)
        return p

    def lamp(self, o, light):
        sk = o["skin"] if "skin" in o else light.get("skin", "")
        if sk and sk in self.lampskins:
            return self.lampskins[sk], sk
        return os.path.join(STATION, "lamp_hood.png"), ""


# ---------------------------------------------------------------- geometry

def band(o, stage):
    if o["type"] not in ("prop", "shelf", "till"):
        return None
    if o.get("layer") in ("wall", "floor", "near"):
        return o["layer"]
    if o["type"] == "prop" and o["id"] in stage.props:
        return stage.props[o["id"]][1]
    return "floor"


def item_art(o, stage, light):
    """(path, native w, h) of the picture that stands for an item, or None."""
    t = o["type"]
    if t == "prop":
        return stage.props[o["id"]][0]
    if t == "shelf":
        return stage.racks[o["skin"]] if o.get("skin") in stage.racks \
            else os.path.join(STATION, "shop_shelf2.png")
    if t == "till":
        return stage.tills[o["skin"]] if o.get("skin") in stage.tills \
            else os.path.join(STATION, "shop_counter.png")
    if t == "lamp":
        return stage.lamp(o, light)[0]
    if t == "door" and o.get("skin") in stage.doors:
        return stage.doors[o["skin"]]
    if t == "open":
        return stage.opening(o["skin"])
    return None


def rect_of(o, stage, light):
    """`rectOf()` in the bench: where an item stands, in room pixels."""
    t = o["type"]
    if t == "shelf":
        if o.get("boards") == 3:
            raise SystemExit("room_install: a three-board rack has no level art")
        a = stage.img(item_art(o, stage, light))
        w, h = a.shape[1] * SHELF_K, a.shape[0] * SHELF_K
    elif t == "till":
        a = stage.img(item_art(o, stage, light))
        k = o.get("scale") or 1
        w, h = a.shape[1] * k, a.shape[0] * k
    elif t == "lamp":
        a = stage.img(item_art(o, stage, light))
        w, h = a.shape[1], a.shape[0]
    elif t == "prop":
        a = stage.img(item_art(o, stage, light))
        k = o.get("scale") or 1
        w, h = int(round(a.shape[1] * k)), int(round(a.shape[0] * k))
    elif t == "door" and o.get("skin") in stage.doors:
        a = stage.img(stage.doors[o["skin"]])
        k = o.get("scale") or 1
        w, h = (a.shape[1] - 24) * k, (a.shape[0] - 12) * k
    elif t == "open":
        e = stage.holes[o["skin"]]
        k = o.get("scale") or 1
        w, h = int(round(e["w"] * k)), int(round(e["h"] * k))
    else:
        w, h = o["w"], o["h"]
    y = o.get("y")
    if y is None and t in ("shelf", "till", "prop"):
        y = H - h
    return {"x": o["x"], "y": y, "w": w, "h": h}


def is_opening(o):
    return o["type"] in ("window", "door", "ports", "open")


# ---------------------------------------------------------------- occluders

def occluder_alpha(room, stage, light, bands, lamps):
    """What stands in the room, as alpha at light-map size: `occluderAlpha()`.

    The bench draws the items into a canvas at half size. Each light-map cell
    whose centre falls in an item's box takes the sprite pixel under that
    centre -- (2x+1, 2y+1) in the room.
    """
    acc = np.ones((GH, GW), np.float64)    # what is still clear: 1 - alpha so far

    def put(a, r, fx, fy):
        sw, sh = a.shape[1], a.shape[0]
        x0, y0, w, h = r["x"] / GK, r["y"] / GK, r["w"] / GK, r["h"] / GK
        # every cell whose centre is in the box, far edge included (see _span)
        gx0, gx1 = max(0, int(math.floor(x0 - 0.5)) + 1), min(GW, int(math.floor(x0 + w - 0.5)) + 1)
        gy0, gy1 = max(0, int(math.floor(y0 - 0.5)) + 1), min(GH, int(math.floor(y0 + h - 0.5)) + 1)
        if gx1 <= gx0 or gy1 <= gy0:
            return
        gx = np.arange(gx0, gx1, dtype=np.float64)
        gy = np.arange(gy0, gy1, dtype=np.float64)
        # the centre of each cell, in the sprite's own pixels
        ux = ((gx + 0.5) * GK - r["x"]) * sw / r["w"]
        vy = ((gy + 0.5) * GK - r["y"]) * sh / r["h"]
        if fx:
            ux = sw - ux
        if fy:
            vy = sh - vy
        ui = np.clip(np.ceil(ux) - 1, 0, sw - 1).astype(np.int64)
        vi = np.clip(np.ceil(vy) - 1, 0, sh - 1).astype(np.int64)
        al = a[vi][:, ui, 3].astype(np.float64) / 255.0
        acc[gy0:gy1, gx0:gx1] *= (1.0 - al)

    for b in bands:
        for o in room["items"]:
            if band(o, stage) != b:
                continue
            r = rect_of(o, stage, light)
            a = stage.img(item_art(o, stage, light))
            put(a, r, o.get("fx"), o.get("fy"))
    if lamps:
        for o in room["items"]:
            if o["type"] == "lamp":
                r = rect_of(o, stage, light)
                a = stage.img(item_art(o, stage, light))
                put(a, r, o.get("fx"), o.get("fy"))
    return np.round((1.0 - acc) * 255.0)


# -------------------------------------------------------------------- light

def ray_cast(cx, cy, rad, grid):
    """How far a lamp sees along each of RAYS directions: `rayCast()`."""
    R = C["RAYS"]
    a = np.arange(R, dtype=np.float64) * 6.283185307 / R
    ux, uy = np.cos(a), np.sin(a)
    far = np.full(R, rad, np.float64)
    live = np.ones(R, bool)
    lim = int(math.ceil(rad))
    for s in range(2, lim):
        if not live.any():
            break
        x = np.trunc(cx + ux * s).astype(np.int64)
        y = np.trunc(cy + uy * s).astype(np.int64)
        out = (x < 0) | (y < 0) | (x >= GW) | (y >= GH)
        hit = np.zeros(R, bool)
        inb = live & ~out
        hit[inb] = grid[y[inb], x[inb]]
        stop = live & (out | hit)
        far[stop] = s
        live &= ~stop
    return far


class LightMap:
    def __init__(self):
        self.rgb = np.zeros((3, GH, GW), np.float32)
        self.blocked = np.zeros((GH, GW), np.float32)

    def add(self, cx, cy, half, rad, f, col, omni, shadow, shade_share, mono=False,
            per_unit=False):
        """`addLight()`.

        `mono` puts the light into one channel as a bare amount and leaves the
        colour to whoever reads it. `per_unit` is for a lamp the game will dim
        itself: it is added at f = 1 with no floor on how faint a pixel may be,
        and its shadow coverage is kept uncapped, so that scaling both by the
        fault's brightness gives what the bench computes at that brightness.
        """
        if rad < 1 or f <= 0:
            return
        soft = max(3.0, rad * 0.38)
        core = max(4.0, rad * 0.50)
        y0, y1 = max(0, math.floor(cy - rad)), min(GH - 1, math.ceil(cy + rad))
        x0, x1 = max(0, math.floor(cx - rad - half)), min(GW - 1, math.ceil(cx + rad + half))
        if y1 < y0 or x1 < x0:
            return
        ys = np.arange(y0, y1 + 1, dtype=np.float64)[:, None]
        xs = np.arange(x0, x1 + 1, dtype=np.float64)[None, :]
        dy = ys - cy
        g = np.clip((dy + soft) / (2 * soft), 0.0, 1.0)
        up = np.ones_like(g) if omni else 0.34 + 0.66 * (g * g * (3 - 2 * g))
        dxr = np.maximum(np.abs(xs - cx) - half, 0.0)
        d = np.sqrt(dxr * dxr + dy * dy)
        inside = d < rad
        shade = np.ones_like(d)
        blocked = np.zeros_like(inside)
        if shadow is not None:
            ang = np.arctan2(ys - cy, xs - cx)
            ang = np.where(ang < 0, ang + 6.283185307, ang)
            ri = np.trunc(ang * C["RAYS"] / 6.283185307).astype(np.int64)
            ri = np.where(ri < C["RAYS"], ri, 0)
            real = np.sqrt((xs - cx) ** 2 + dy * dy)
            blocked = inside & (real > shadow[ri] + 1)
            shade = np.where(blocked, shade_share, 1.0)
        w = (1 - d / rad) ** 2
        k = d / core
        a = 1.4 * w * up * f * shade / (1 + k * k)
        sl = (slice(y0, y1 + 1), slice(x0, x1 + 1))
        if blocked.any():
            full = 1.4 * w * up * f / (1 + k * k)
            cov = full / 0.05 if per_unit else np.minimum(1.0, full / 0.05)
            cur = self.blocked[sl]
            upd = blocked & (cov > cur)
            self.blocked[sl] = np.where(upd, cov.astype(np.float32), cur)
        a = np.where(inside & (a > (0.0 if per_unit else 0.0005)), a, 0.0)
        if mono:
            self.rgb[0][sl] = (self.rgb[0][sl] + a).astype(np.float32)
            return
        for c in range(3):
            self.rgb[c][sl] = (self.rgb[c][sl] + a * col[c]).astype(np.float32)

    def bounce(self):
        """`bouncePass()`: a box blur of the light, added back."""
        r, n = C["BLUR"], 2 * C["BLUR"] + 1
        for c in range(3):
            S = self.rgb[c].astype(np.float64)
            p = np.pad(S, ((0, 0), (r, r + 1)), mode="edge")
            cs = np.concatenate([np.zeros((GH, 1)), np.cumsum(p, axis=1)], axis=1)
            D = ((cs[:, n:n + GW] - cs[:, 0:GW]) / n).astype(np.float32).astype(np.float64)
            p2 = np.pad(D, ((r, r + 1), (0, 0)), mode="edge")
            cs2 = np.concatenate([np.zeros((1, GW)), np.cumsum(p2, axis=0)], axis=0)
            V = (cs2[n:n + GH, :] - cs2[0:GH, :]) / n
            self.rgb[c] = (S + V * C["BOUNCE"]).astype(np.float32)


def feather(mask):
    """`featherMask()`: the opening exemption softened over a 7x7 box."""
    r, n = 3, 7
    m = mask.astype(np.float64)
    p = np.pad(m, ((0, 0), (r, r + 1)), mode="edge")
    cs = np.concatenate([np.zeros((GH, 1)), np.cumsum(p, axis=1)], axis=1)
    t = ((cs[:, n:n + GW] - cs[:, 0:GW]) / n).astype(np.float32).astype(np.float64)
    p2 = np.pad(t, ((r, r + 1), (0, 0)), mode="edge")
    cs2 = np.concatenate([np.zeros((1, GW)), np.cumsum(p2, axis=0)], axis=0)
    return ((cs2[n:n + GH, :] - cs2[0:GH, :]) / n).astype(np.float32)


def hole_spots(o, r, stage):
    """Where an opening's glow comes out: `holeSpots()`."""
    if o["type"] == "open":
        runs = stage.holes[o["skin"]]["runs"]
        k = o.get("scale") or 1
        if not runs:
            return []
        ry = [q[0] for q in runs]
        y0, y1 = min(ry), max(ry)
        out = []
        for j in range(4):
            want = y0 + (y1 - y0) * (j + 0.5) / 4
            best, bd = None, 1e9
            for q in runs:
                dd = abs(q[0] - want)
                if dd < bd:
                    bd, best = dd, q
            out.append({"x": r["x"] + (best[1] + best[2] / 2.0) * k,
                        "y": r["y"] + best[0] * k, "half": max(2.0, best[2] * k / 2.0)})
        return out
    rows = max(1, min(4, int(math.floor(r["h"] / 40.0 + 0.5))))
    return [{"x": r["x"] + r["w"] / 2.0, "y": r["y"] + r["h"] * (q + 0.5) / rows,
             "half": max(2.0, r["w"] / 2.0)} for q in range(rows)]


def light_mask(room, stage, light):
    """`buildLightMask()`: the openings, less whatever stands in front of them."""
    m = np.zeros((GH, GW), bool)

    def mark(x0, y0, x1, y1):
        ax0, ax1 = max(0, int(x0 / GK)), min(GW, int(math.ceil(x1 / GK)))
        ay0, ay1 = max(0, int(y0 / GK)), min(GH, int(math.ceil(y1 / GK)))
        if ax1 > ax0 and ay1 > ay0:
            m[ay0:ay1, ax0:ax1] = True

    for o in room["items"]:
        if not is_opening(o):
            continue
        r = rect_of(o, stage, light)
        if o["type"] == "open":
            k = o.get("scale") or 1
            for q in stage.holes[o["skin"]]["runs"]:
                mark(r["x"] + q[1] * k, r["y"] + q[0] * k,
                     r["x"] + (q[1] + q[2]) * k, r["y"] + q[0] * k + k)
        else:
            mark(r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])
    occ = occluder_alpha(room, stage, light, ["wall", "floor", "near"], True)
    m &= ~(occ > 24)
    return feather(m)


def build_light(room, stage, tones):
    """Every piece of the room's light, as the module docstring lists them."""
    light = room["light"]
    shadowk = light.get("shadowk", 0.55)
    share = max(0.06, 1 - shadowk)
    rad = light.get("rad", 280)
    grid = None
    if shadowk > 0:
        grid = occluder_alpha(room, stage, light, ["floor", "near"], False) > 90
    S, O = LightMap(), LightMap()
    flick = []
    lamps = [o for o in room["items"] if o["type"] == "lamp"]
    for i, o in enumerate(lamps):
        mode = o.get("flick") or 0
        pw = o.get("pow", 1.4)
        col = o.get("col") or "#ffb457"
        c = np.array([int(col[1:3], 16), int(col[3:5], 16), int(col[5:7], 16)], np.float64) / 255.0
        cn = c / (c.max() or 1.0)
        r = rect_of(o, stage, light)
        path = item_art(o, stage, light)
        a = stage.img(path)
        sx = r["w"] / max(1, a.shape[1])
        reach = o.get("reach", 280) / GK
        target = S if not mode else LightMap()
        for e in emitters(a):
            ex, ey = (r["x"] + e["cx"] * sx) / GK, (r["y"] + e["y"] * sx) / GK
            rays = ray_cast(ex, ey, reach, grid) if grid is not None else None
            target.add(ex, ey, e["half"] * sx / GK, reach, 1.0 if mode else pw,
                       cn, False, rays, share, mono=bool(mode), per_unit=bool(mode))
        if mode:
            flick.append({"lamp": i, "map": target})
    bd = room["backdrop"]["id"]
    for o in room["items"]:
        if not is_opening(o) or o.get("glow") is False:
            continue
        r = rect_of(o, stage, light)
        spots = hole_spots(o, r, stage)
        if not spots:
            continue
        g = C["OPEN_GLOW"] * o.get("gain", 1) / math.sqrt(len(spots))
        reach = (rad * C["OPEN_REACH"]) / GK
        for sp in spots:
            O.add(sp["x"] / GK, sp["y"] / GK, sp["half"] / GK, reach, g, None, True, None,
                  share, mono=True)
    for o in room["items"]:
        if o["type"] != "open" or o.get("glow") is False:
            continue
        r = rect_of(o, stage, light)
        k = o.get("scale") or 1
        for e in pilots(stage.img(stage.opening(o["skin"]))):
            S.add((r["x"] + e["cx"] * k) / GK, (r["y"] + e["cy"] * k) / GK, e["half"] * k / GK,
                  (rad * 0.32) / GK, 0.38, e["rgb"], True, None, share)
    for o in room["items"]:
        if o["type"] != "prop" or o.get("glow") is False:
            continue
        g = C["PROP_GLOW"].get(o["id"])
        if not g:
            continue
        a = stage.img(item_art(o, stage, light))
        r = rect_of(o, stage, light)
        if o["id"] in C["STRING_GLOW"]:
            ks = r["w"] / max(1, a.shape[1])
            reach = (rad * C["STRING_GLOW"][o["id"]]) / GK
            for sp in lit_spots(a):
                sx = a.shape[1] - sp["cx"] if o.get("fx") else sp["cx"]
                S.add((r["x"] + sx * ks) / GK, (r["y"] + sp["cy"] * ks) / GK, 0, reach, g,
                      sp["rgb"], True, None, share)
            continue
        lf = lit_face(a)
        if not lf:
            continue
        k = r["w"] / max(1, a.shape[1])
        half = max(2.0, lf["halfW"] * k)
        reach = (rad * 0.34) / GK
        rows = max(1, min(4, int(math.floor(lf["halfH"] * k / 22.0 + 0.5))))
        gp = g / math.sqrt(rows)
        for q in range(rows):
            fy = lf["cy"] + (lf["halfH"] * (2 * (q + 0.5) / rows - 1)) * 0.8
            S.add((r["x"] + lf["cx"] * k) / GK, (r["y"] + fy * k) / GK, half / GK, reach, gp,
                  lf["rgb"], True, None, share)
    S.bounce()
    O.bounce()
    for fl in flick:
        fl["map"].bounce()
    if len(flick) > 1:
        raise SystemExit("room_install: %s has %d failing lamps; the game carries one"
                         % (room["name"], len(flick)))
    X = light_mask(room, stage, light)
    F = flick[0]["map"].rgb[0] if flick else np.zeros((GH, GW), np.float32)
    # A failing lamp's shadow coverage at unit power: `full / 0.05`, uncapped,
    # so the game can scale it by the fault and cap it there.
    U = (flick[0]["map"].blocked if flick else np.zeros((GH, GW), np.float32))
    return {"S": S.rgb, "O": O.rgb[0], "F": F, "U": U, "B": S.blocked, "X": X,
            "flick_lamp": flick[0]["lamp"] if flick else -1}


# ------------------------------------------------------------------ install

def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace(" · ", "_")).strip("_")


def _pct(k):
    return "" if (k or 1) == 1 else "_s%d" % int(round((k or 1) * 100))


class Baker:
    """Writes each picture the rooms draw, once, at the size it is drawn."""

    def __init__(self, stage):
        self.stage = stage
        self.written = {}

    def put(self, name, a):
        if name in self.written:
            if not np.array_equal(self.written[name], a):
                raise SystemExit("room_install: two different pictures want %s" % name)
            return name
        save(os.path.join(OUT, name), a)
        self.written[name] = a
        return name

    def sprite(self, stem, a, w, h, fx=False, fy=False):
        """A picture at w x h, mirrored as asked. Mirroring the SCALED picture
        is exactly what the bench's mirror-about-the-centre draws, because the
        scale samples from pixel centres both ways."""
        k = w / float(a.shape[1])
        out = scale_to(a, w, h)
        if fx:
            out = out[:, ::-1]
        if fy:
            out = out[::-1]
        name = "%s%s%s%s.png" % (stem, _pct(round(k, 4)), "_fx" if fx else "", "_fy" if fy else "")
        return self.put(name, out)


def _hex(col):
    return col.lower().lstrip("#")


# THE RANGE EACH PIECE IS STORED OVER, as 16-bit fixed point. Light past 8 is
# past full brightness and the most overbright the bench ever adds, so nothing
# above it can change a pixel; the failing lamp's shadow per unit of power
# reaches about 19. Resolution is range / 65535 -- 0.00012 of light, a hundred
# times finer than the smallest step anyone could see.
SCALES = [[8.0, 8.0, 8.0, 8.0], [8.0, 32.0, 1.0, 1.0]]


def light_image(pieces):
    """The light as one RGBA8 picture, four GW x GH bands stacked: the high
    and low bytes of (S.r, S.g, S.b, O), then of (F, U, B, X).

    A PNG BECAUSE GODOT DECODES ONE NATIVELY. The same numbers as half floats
    under zlib were 6.3 MB and needed a GDScript loop to unpack; as PNG planes
    they are 2.4 MB and arrive as a texture the shader reads directly."""
    p1 = np.stack([pieces["S"][0], pieces["S"][1], pieces["S"][2], pieces["O"]], axis=-1)
    p2 = np.stack([pieces["F"], pieces["U"], pieces["B"], pieces["X"]], axis=-1)
    bands = []
    for p, sc in ((p1, SCALES[0]), (p2, SCALES[1])):
        p = p.astype(np.float64)
        if not np.isfinite(p).all():
            raise SystemExit("room_install: a light map came out non-finite")
        over = [i for i in range(4) if p[..., i].max() > sc[i] and sc[i] > 1]
        if over:
            raise SystemExit("room_install: light piece %s runs past its range %s -- raise SCALES"
                             % (over, sc))
        q = np.clip(np.floor(p / np.array(sc) * 65535.0 + 0.5), 0, 65535).astype(np.uint16)
        bands.append((q >> 8).astype(np.uint8))
        bands.append((q & 255).astype(np.uint8))
    return np.concatenate([bands[0], bands[1], bands[2], bands[3]], axis=0)


def write_light(path, pieces):
    Image.fromarray(light_image(pieces), "RGBA").save(path, "PNG", optimize=True)


def room_entry(room, stage, baker):
    light = room["light"]
    level = room["levels"][0] if room.get("levels") else room["name"].split(" · ")[0]
    sl = slug(room["name"])
    wall_id = room["room"]["wall"]
    if wall_id not in stage.plates:
        raise SystemExit("room_install: %s stands on plate %s, which the stage lacks"
                         % (room["name"], wall_id))
    plate = baker.put("plate_%s.png" % wall_id, stage.img(stage.plates[wall_id]))
    e = {"name": room["name"], "slug": sl, "level": level, "plate": plate,
         "backdrop": room["backdrop"]["id"],
         "air": {"people": room.get("air", {}).get("people", 1),
                 "motes": int(room.get("air", {}).get("motes", 90))},
         "openings": [], "lamps": [], "glass": []}
    for o in room["items"]:
        if not is_opening(o):
            continue
        r = rect_of(o, stage, light)
        if o["type"] == "open":
            if (o.get("scale") or 1) != 1:
                raise SystemExit("room_install: %s scales an opening" % room["name"])
            e["openings"].append({"type": "open", "skin": o["skin"], "x": r["x"], "y": r["y"],
                                  "w": r["w"], "h": r["h"], "fx": bool(o.get("fx")),
                                  "fy": bool(o.get("fy"))})
        elif o["type"] == "door":
            if not o.get("skin") or o["skin"] not in stage.doors:
                raise SystemExit("room_install: %s has a door with no style" % room["name"])
            k = o.get("scale") or 1
            a = stage.img(stage.doors[o["skin"]])
            art = baker.sprite("door_%s" % o["skin"], a, a.shape[1] * k, a.shape[0] * k,
                               o.get("fx"), o.get("fy"))
            e["openings"].append({"type": "door", "x": r["x"], "y": r["y"], "w": r["w"],
                                  "h": r["h"], "art": art, "ax": r["x"] - 12 * k,
                                  "ay": r["y"] - 12 * k})
        elif o["type"] == "window":
            style = o.get("style") if o.get("style") in FRAMES else "chamfer"
            e["openings"].append({"type": "window", "x": r["x"], "y": r["y"], "w": r["w"],
                                  "h": r["h"], "frame": FRAMES[style][0],
                                  "margin": FRAMES[style][1]})
        else:
            raise SystemExit("room_install: %s has a %s, which the game does not draw"
                             % (room["name"], o["type"]))
    # THE BENCH'S DRAW ORDER: the wall band in item order, the haze, the floor
    # band, the near band. The rack and the counter are live nodes in the game,
    # so the rest is split around them: whatever the bench draws AFTER a piece
    # of furniture and on top of it -- or on top of something already in front
    # -- goes in the layer over the furniture; everything else stays on the
    # room's own canvas. Jon's racks and counters stand in the WALL band (so
    # they neither cast a shadow nor sit in one), which puts the haze, and the
    # little on the floor band, in front of them.
    seq = [o for o in room["items"] if band(o, stage) == "wall"] + ["haze"]
    for b in ("floor", "near"):
        seq += [o for o in room["items"] if band(o, stage) == b]
    haze = {"x": 0, "y": FLOOR - 90, "w": W, "h": H - (FLOOR - 90)}

    def hits(a, b):
        return (a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and
                a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"])

    furniture, ahead = {}, []
    e["back"], e["front"], e["furniture"] = [], [], []
    for o in seq:
        if o == "haze":
            front = any(hits(haze, q) for q in ahead)
            (e["front"] if front else e["back"]).append({"haze": True})
            if front:
                ahead.append(haze)
            continue
        r = rect_of(o, stage, light)
        if o["type"] in ("shelf", "till"):
            if o["type"] in furniture:
                raise SystemExit("room_install: %s has two of %s" % (room["name"], o["type"]))
            a = stage.img(item_art(o, stage, light))
            if o["type"] == "shelf":
                sk = o.get("skin") or "standard"
                art = baker.put("rack_%s.png" % sk, a)
                furniture["shelf"] = {"art": art, "x": r["x"], "y": r["y"], "w": r["w"],
                                      "h": r["h"], "k": SHELF_K,
                                      "boards": stage.boards.get(o.get("skin"), STANDARD_BOARDS)}
            else:
                art = baker.sprite("till_%s" % (o.get("skin") or "standard"), a, r["w"], r["h"])
                furniture["till"] = {"art": art, "x": r["x"], "y": r["y"], "w": r["w"],
                                     "h": r["h"]}
            e["furniture"].append("rack" if o["type"] == "shelf" else "till")
            ahead.append(r)
            continue
        a = stage.img(item_art(o, stage, light))
        art = baker.sprite("prop_%s" % o["id"], a, r["w"], r["h"], o.get("fx"), o.get("fy"))
        entry = {"art": art, "x": r["x"], "y": r["y"], "w": r["w"], "h": r["h"]}
        front = any(hits(r, q) for q in ahead)
        (e["front"] if front else e["back"]).append(entry)
        if front:
            ahead.append(r)
        g = C["PROP_GLOW"].get(o["id"])
        if g and o.get("glow") is not False:
            lp = lit_pixels(a)
            if lp is not None:
                gl = baker.sprite("propglass_%s" % o["id"], lp, r["w"], r["h"],
                                  o.get("fx"), o.get("fy"))
                e["glass"].append({"art": gl, "x": r["x"], "y": r["y"]})
    if set(furniture) != {"shelf", "till"}:
        raise SystemExit("room_install: %s needs one rack and one counter" % room["name"])
    e["rack"], e["till"] = furniture["shelf"], furniture["till"]
    # THE RACK AND THE COUNTER ARE TWO NODES SIDE BY SIDE, drawn in whatever
    # order the screen adds them, so they must not overlap.
    if hits(e["rack"], e["till"]):
        raise SystemExit("room_install: %s stands its rack and counter on each other"
                         % room["name"])
    pieces = build_light(room, stage, None)
    lamps = [o for o in room["items"] if o["type"] == "lamp"]
    for i, o in enumerate(lamps):
        r = rect_of(o, stage, light)
        path, sk = stage.lamp(o, light)
        a = stage.img(path)
        body = baker.sprite("lamp_%s" % (sk or "hood"), a, a.shape[1], a.shape[0],
                            o.get("fx"), o.get("fy"))
        col = o.get("col") or "#ffb457"
        gl = o.get("glass", 0.62)
        glass = baker.sprite("lampglass_%s_%s_%d" % (sk or "hood", _hex(col),
                                                     int(round(gl * 100))),
                             lamp_glass(a, col, gl), a.shape[1], a.shape[0],
                             o.get("fx"), o.get("fy"))
        e["lamps"].append({"art": body, "glass": glass, "x": int(round(r["x"])),
                           "y": int(round(r["y"])), "flick": int(o.get("flick") or 0),
                           "rate": o.get("rate") or 0, "px": o["x"], "py": o.get("y", 0),
                           "pow": o.get("pow", 1.4), "col": col})
    f_lamp = pieces["flick_lamp"]
    # NOT .png: the editor would import it, and an import may touch the
    # colour of a transparent pixel -- which here is data, not colour.
    lf = "light_%s.lmap" % sl
    write_light(os.path.join(OUT, lf), pieces)
    e["light"] = {"amb": light.get("amb", 0.30), "shadowk": light.get("shadowk", 0.55),
                  "dither": bool(light.get("dither", True)), "file": lf,
                  "flick_lamp": f_lamp}
    return e, pieces


def main_install():
    if np is None or Image is None:
        raise SystemExit("room_install: installing needs numpy and Pillow")
    stage = Stage()
    src = io.open(EXPORT, encoding="utf-8").read()
    export = json.loads(src)
    rooms = export["layouts"]
    if export.get("panel") != [W, H] or export.get("floor_y") != FLOOR:
        raise SystemExit("room_install: the export is for a %s room with its floor on %s"
                         % (export.get("panel"), export.get("floor_y")))
    if export.get("shelf_scale", 2) != SHELF_K:
        raise SystemExit("room_install: the export draws racks at %sx" % export.get("shelf_scale"))
    if os.path.isdir(OUT):
        for f in os.listdir(OUT):
            p = os.path.join(OUT, f)
            if os.path.isfile(p) and not f.endswith(".import"):
                os.remove(p)
    os.makedirs(OUT, exist_ok=True)
    baker = Baker(stage)
    entries, levels = [], dict((lv, []) for lv in LEVELS_ORDER)
    for room in rooms:
        e, _ = room_entry(room, stage, baker)
        if e["level"] not in levels:
            raise SystemExit("room_install: %s is for no level the game has" % room["name"])
        levels[e["level"]].append(e["slug"])
        entries.append(e)
        print("  %-24s %2d openings, %2d behind the furniture, %d in front, "
              "%d lamps%s, %d lit panels"
              % (room["name"].replace(" · ", " / "), len(e["openings"]),
                 len([q for q in e["back"] if "art" in q]),
                 len([q for q in e["front"] if "art" in q]),
                 len(e["lamps"]), " (one failing)" if e["light"]["flick_lamp"] >= 0 else "",
                 len(e["glass"])))
    short = [lv for lv, v in levels.items() if not v]
    if short:
        raise SystemExit("room_install: no room for %s" % ", ".join(short))
    # THE OPENING GLOW'S COLOUR, for every backdrop the game can draw. The
    # pools are read out of StationRoom.gd, which is what picks one.
    gd = io.open(os.path.join(TKG, "scripts", "ui", "StationRoom.gd"), encoding="utf-8").read()
    blk = gd[gd.index("const BACKDROPS := {"):]
    blk = blk[:blk.index("\n}\n")]
    tones = {}
    for bid in sorted(set(re.findall(r'&"(\w+)"', blk))):
        tones[bid] = [round(v, 6) for v in
                      backdrop_tone(load(os.path.join(STATION, "backdrop_%s.png" % bid)))]
    doc = {
        "format": "three-kelvin/shop-rooms/1",
        "source": "tools/room_stage/room-layouts.json",
        "source_sha1": hashlib.sha1(src.encode("utf-8")).hexdigest(),
        "panel": [W, H], "floor_y": FLOOR, "gk": GK, "light_size": [GW, GH],
        "light_scales": SCALES,
        "bezel": T,
        "constants": {"levels": C["LEVELS"], "soft": C["SOFT"], "amb_col": C["AMB_COL"],
                      "bayer": C["BAYER"], "reflect_alpha": C["REFLECT_ALPHA"]},
        "levels": levels,
        "tones": tones,
        "rooms": entries,
    }
    with io.open(ROOMS_JSON, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    # AN IMPORT WITH NO PICTURE is Godot's record of a file this install no
    # longer writes; the ones whose picture is still here keep their ids.
    for f in os.listdir(OUT):
        if f.endswith(".import") and not os.path.exists(os.path.join(OUT, f[:-7])):
            os.remove(os.path.join(OUT, f))
    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print("room_install: %d rooms, %d pictures, %.1f MB in %s"
          % (len(entries), len(baker.written), size / 1e6, os.path.relpath(OUT, REPO)))


def main_check():
    """The game's rooms are the export's: same source, every file present."""
    if not os.path.exists(ROOMS_JSON):
        raise SystemExit("room_install --check: nothing installed")
    doc = json.load(io.open(ROOMS_JSON, encoding="utf-8"))
    src = io.open(EXPORT, encoding="utf-8").read()
    if doc.get("source_sha1") != hashlib.sha1(src.encode("utf-8")).hexdigest():
        raise SystemExit("room_install --check: room-layouts.json changed since the install; "
                         "run tools/room_install.py")
    missing = []
    for e in doc["rooms"]:
        names = [e["plate"], e["light"]["file"], e["rack"]["art"], e["till"]["art"]]
        names += [p["art"] for p in e["back"] + e["front"] if "art" in p]
        names += [o["art"] for o in e["openings"] if "art" in o]
        names += [l["art"] for l in e["lamps"]] + [l["glass"] for l in e["lamps"]]
        names += [g["art"] for g in e["glass"]]
        missing += [n for n in names if not os.path.exists(os.path.join(OUT, n))]
    if missing:
        raise SystemExit("room_install --check: %d file(s) missing: %s"
                         % (len(missing), ", ".join(sorted(set(missing))[:8])))
    print("room_install --check: %d rooms, installed from the current export" % len(doc["rooms"]))


if __name__ == "__main__":
    if "--check" in sys.argv:
        main_check()
    else:
        main_install()
