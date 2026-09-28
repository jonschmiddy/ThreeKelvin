"""Stage the Exchange's generated art for the bench: the hangar doors, the
machines and the cargo props, from the PixelLab takes Jon picked.

    python tools/exchange_art.py      # reads room_stage/exchange/picks.json

EVERY TAKE IS KEPT in `room_stage/exchange/takes/`, so a different pick is a
line in `picks.json` and this run, not a generation.

THE DOORS ARE RAISED ABOUT A THIRD (Jon, 2026-09-27: the original Exchange's
"hanger door situation", with space seen under it). PixelLab draws a roll-up
door with its slats most of the way down whatever the prompt says, so the
raise is done here, by rows, never by painting: the slats are kept as drawn
from the header down, the leaf's bottom edge -- its rail, its hazard band --
is lifted to sit under them, and every row below it down to the floor is cut
out between the posts. The posts stay whole, row for row.

Each door is measured by hand off a 5x zoom with a pixel grid, because what is
leaf and what is post differs per take: the row the slats start (`top`), the
leaf's columns (`leaf`), the rows of its bottom edge (`bar`, and `bar_x` if it
is wider than the leaf), the first row of the gap PixelLab drew (`gap_top`)
and its columns (`gap`), and the floor row (`floor`).

THE DOOR IS THE MAIN THING (Jon, 2026-09-27: "the hanger doors should be MUCH
bigger. like the main thing"). A roll-up door is one slat over and over, so it
is grown the way `cage_fit.py` grows a hold frame -- by repeating bands of its
own columns and rows, never by scaling -- and the bulb, the beacon, the lantern
and the crest stay the size they were drawn, as they would on a bigger door.
`grow` names the bands, measured off the same zoom to miss every detail, each
a whole number of the slats' or stripes' repeats so no seam shows: `cols`, two
bands of columns repeated `times` more, and `rows`, one band repeated
`rtimes` more. Everything else in the spec is in the take's own pixels, and is
moved along with the bands before the raise.

A MACHINE MAY BE EDITED THE SAME WAY, in its own colours: `mouth` makes the
city's small grille one wide intake mouth (Jon: "it should have a bigger
opening"). A prop may drop the light pixels under a row (`clear_light_below`,
the hand truck's pale slab: "remove the white under the box").

WHAT IT WRITES, into `tools/room_stage/`, cropped to the ink:

  open_hangar_<level>.png   the door, doubled like the hold frames beside it,
                            its gap transparent
  hole_hangar_<level>.png   the gap alone, opaque: the bench reads it as the
                            hole's runs (`room_bench.hole_runs`)
  till_exchange_<level>.png the machine you sell at, at 1x -- waist-high beside
                            the doors, the scale the shop's tills are drawn at
  prop_wall_<name>.png      a cargo prop, doubled like the others
  exchange/hook.png         the crane hook the hold hangs from, doubled, with
                            the rows of rope at its top recorded in
                            `exchange/hook.json` for the rope to be tiled from

THE HOLD HANGS FROM A WIRE (Jon, 2026-09-27: "i kinda want the storage to be a
box that is suspended by a wire (like the original generated design)"). The
old dock's cage hung from a crane hook on a cable to the ceiling; this one does
too. The hook is a picture; the cable above it is the picture's own top rows
of rope, repeated up to the ceiling.
"""

import io
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
STAGE = os.path.join(HERE, "room_stage")
EX = os.path.join(STAGE, "exchange")
PICKS = os.path.join(EX, "picks.json")
RAISE = 1.0 / 3.0


def load(take):
    return np.array(Image.open(os.path.join(EX, take)).convert("RGBA"))


def ink(a):
    ys, xs = np.nonzero(a[..., 3] > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def double(a):
    return np.repeat(np.repeat(a, 2, axis=0), 2, axis=1)


def save(a, name):
    Image.fromarray(a, "RGBA").save(os.path.join(STAGE, name))


def repeat_band(a, axis, b0, b1, times):
    """`a` with lines [b0, b1) along `axis` repeated `times` more."""
    if times <= 0:
        return a
    lines = np.moveaxis(a, axis, 0)
    parts = [lines[:b1]] + [lines[b0:b1]] * times + [lines[b1:]]
    return np.moveaxis(np.concatenate(parts), 0, axis)


def grow_door(a, d):
    """The take grown by its bands, and the spec moved to match."""
    g = d.get("grow")
    if not g:
        return a, d
    d = json.loads(json.dumps(d))
    # A LEAF WITH A SHEEN IS FLATTENED FIRST (`flat`): the settlement's planks
    # carry a diagonal of light across them, and repeating columns cut it into
    # teeth. Each row of the leaf is rebuilt from a band on its unlit side.
    if "flat" in d:
        f0, f1 = d["flat"]
        lx0, lx1 = d["leaf"]
        a = a.copy()
        for y in range(d["top"], d["bar"][1]):
            band = a[y, f0:f1].copy()
            for x in range(lx0, lx1):
                a[y, x] = band[(x - lx0) % (f1 - f0)]
    # A LEAF WITH A DIAGONAL SHEEN IS STRETCHED, NOT REPEATED (`stretch`:
    # [x0, x1, new width]). The settlement's planks carry a diagonal of light
    # corner to corner, and any repeated band cut it into teeth; sampling the
    # span's columns out to the new width makes the diagonal shallower and the
    # grain longer, which a plank can take. Everything outside the span -- the
    # sign, the bolts, the posts -- stays as drawn.
    if "stretch" in g:
        s0, s1, nw = g["stretch"]
        src = [s0 + (j * (s1 - s0)) // nw for j in range(nw)]
        a = np.concatenate([a[:, :s0], a[:, src], a[:, s1:]], axis=1)
        grow_w = nw - (s1 - s0)

        def fx(x):
            if x <= s0:
                return x
            if x >= s1:
                return x + grow_w
            return s0 + ((x - s0) * nw) // (s1 - s0)

        for key in ("leaf", "bar_x", "gap"):
            if key in d:
                d[key] = [fx(v) for v in d[key]]
        return a, d
    k = g.get("times", 0)
    (l0, l1), (r0, r1) = g["cols"]
    wl, wr = (l1 - l0) * k, (r1 - r0) * k
    # the right band first, so the left one's columns are still where measured
    a = repeat_band(a, 1, r0, r1, k)
    a = repeat_band(a, 1, l0, l1, k)

    def fx(x):
        return x + (wl if x >= l1 else 0) + (wr if x >= r1 else 0)

    m = g.get("rtimes", 0)
    y0, y1 = g.get("rows", (0, 0))
    a = repeat_band(a, 0, y0, y1, m)
    h = (y1 - y0) * m

    def fy(y):
        return y + (h if y >= y1 else 0)

    for key in ("leaf", "bar_x", "gap"):
        if key in d:
            d[key] = [fx(v) for v in d[key]]
    for key in ("top", "gap_top", "floor"):
        d[key] = fy(d[key])
    d["bar"] = [fy(v) for v in d["bar"]]
    return a, d


def paint_mouth(a, spec):
    """A wide intake mouth over `box` [x0, y0, x1, y1), in the colours of the
    grille it replaces, sampled at `sample` (the grille's top-left): its frame,
    a darker inner line, a lit left edge, a dark throat, and a lit bottom lip."""
    out = a.copy()
    x0, y0, x1, y1 = spec["box"]
    sx, sy = spec["sample"]
    frame = a[sy, sx + 10].copy()          # the grille's outer frame
    inner = a[sy + 2, sx + 10].copy()      # its darker inner line
    edge = a[sy + 4, sx].copy()            # its lit left edge
    lip = a[sy + 9, sx + 10].copy()        # its lit bottom lip
    throat = (inner.astype(int) * 2 // 3).astype(np.uint8)
    throat[3] = 255
    out[y0:y0 + 2, x0:x1] = frame
    out[y0 + 2, x0:x1] = inner
    out[y0 + 3:y1 - 2, x0:x1] = throat
    out[y0 + 3:y1 - 2, x0] = edge
    out[y0 + 3:y1 - 2, x1 - 1] = inner
    out[y1 - 2, x0:x1] = frame
    out[y1 - 1, x0:x1] = lip
    return out


# WHAT THE HOOK CATCHES (Jon, 2026-09-27: "IDK what is it hooking into?", and
# of the shackle that answered it, "kinda muddy and undefined"). A shackle and
# lug at this size were grey on the hook's dark grey and read as a knot. So it
# is one bold shape: a bright steel lifting ring on a welded base plate, its top
# caught in the hook's curve -- the hook in front of it on the left and below,
# the ring in front of the hook's tip on the right. Drawn here from geometry, in
# steel lit from the upper left like everything else in the rooms.
RING_INK = {"out": (8, 8, 11), "dark": (60, 64, 70), "mid": (120, 128, 136),
            "light": (178, 190, 198), "hi": (222, 232, 238)}


def rig(a, spec):
    """The hook take with its lifting ring and base plate drawn under it."""
    import math
    cx, cy = spec["centre"]
    r_in, r_out = spec["radii"]
    plate_y = spec["plate_y"]
    # THE HOOK HANGS `drop` ROWS DEEPER into the ring than the take drew it
    # (Jon: "can the hook go a bit lower"), so more of its curve crosses the
    # ring; the ring and its plate stay where they stand on the frame.
    drop = spec.get("drop", 0)
    h = max(a.shape[0] + drop, plate_y + 3)
    out = np.zeros((h, a.shape[1], 4), np.uint8)
    out[drop:drop + a.shape[0]] = a
    hook = out[..., 3] > 40
    w = a.shape[1]
    ring = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            ring[y, x] = r_in <= math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r_out
    fx0, fy0, fx1, fy1 = spec["ring_in_front"]
    fy0, fy1 = fy0 + drop, fy1 + drop
    for y in range(h):
        for x in range(w):
            if not ring[y, x]:
                continue
            if hook[y, x] and not (fx0 <= x < fx1 and fy0 <= y < fy1):
                continue
            edge = any(not ring[yy, xx] for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1))
                       if 0 <= yy < h and 0 <= xx < w)
            lit = -math.cos(math.atan2(y + 0.5 - cy, x + 0.5 - cx) + math.pi * 0.75)
            if edge:
                c = RING_INK["out"] if lit < 0.3 else RING_INK["dark"]
            else:
                c = RING_INK["hi"] if lit > 0.6 else (RING_INK["light"] if lit > -0.1 else RING_INK["mid"])
            out[y, x, :3] = c
            out[y, x, 3] = 255
    # the plate it is welded on: three rows, widening, lit on top
    x_mid = int(cx)
    for i, (half, ink) in enumerate(((4, "light"), (5, "mid"), (6, "dark"))):
        y = plate_y + i
        for x in range(x_mid - half + 1, x_mid + half + 1):
            edge = x in (x_mid - half + 1, x_mid + half)
            out[y, x, :3] = RING_INK["out"] if edge else RING_INK[ink]
            out[y, x, 3] = 255
    return out


def raise_door(a, d):
    """`a` with its leaf raised to cover the upper two thirds of the opening;
    returns (door, hole) at 1x."""
    out = a.copy()
    hole = np.zeros(a.shape[:2], bool)
    top, floor = d["top"], d["floor"]
    b0, b1 = d["bar"]
    bh = b1 - b0
    keep = d.get("keep")
    if keep is None:
        keep = int(round((floor - top) * (1.0 - RAISE))) - bh
    edge = top + keep                   # where the lifted bottom edge goes
    bx0, bx1 = d.get("bar_x", d["leaf"])
    lx0, lx1 = d["leaf"]
    gx0, gx1 = d["gap"]
    out[edge:edge + bh, bx0:bx1] = a[b0:b1, bx0:bx1]
    for y in range(edge + bh, floor):
        x0, x1 = (gx0, gx1) if y >= d["gap_top"] else (lx0, lx1)
        out[y, x0:x1] = 0
        hole[y, x0:x1] = True
    return out, hole


def main():
    picks = json.load(io.open(PICKS, encoding="utf-8"))
    for level, d in sorted(picks["doors"].items()):
        grown, d = grow_door(load(d["take"]), d)
        door, hole = raise_door(grown, d)
        x0, y0, x1, y1 = ink(door)
        m = np.zeros(door.shape, np.uint8)
        m[hole] = (255, 255, 255, 255)
        save(double(door[y0:y1, x0:x1]), "open_hangar_%s.png" % level)
        save(double(m[y0:y1, x0:x1]), "hole_hangar_%s.png" % level)
        print("  door     %-10s %-24s %dx%d" % (level, d["take"], (x1 - x0) * 2, (y1 - y0) * 2))
    for level, m in sorted(picks["machines"].items()):
        m = m if isinstance(m, dict) else {"take": m}
        a = load(m["take"])
        if "mouth" in m:
            a = paint_mouth(a, m["mouth"])
        x0, y0, x1, y1 = ink(a)
        save(a[y0:y1, x0:x1], "till_exchange_%s.png" % level)
        print("  machine  %-10s %-24s %dx%d" % (level, m["take"], x1 - x0, y1 - y0))
    if "hook" in picks:
        h = picks["hook"]
        a = load(h["take"])
        if h.get("rig"):
            a = rig(a, h["rig"])
        # most of the rope the take hangs from comes off (`crop_top`): what is
        # left at the top is the tile the cable is repeated from
        a = a[h.get("crop_top", 0):]
        x0, y0, x1, y1 = ink(a)
        Image.fromarray(double(a[y0:y1, x0:x1]), "RGBA").save(os.path.join(EX, "hook.png"))
        with io.open(os.path.join(EX, "hook.json"), "w", encoding="utf-8", newline="\n") as f:
            f.write(json.dumps({"rope": h["rope"] * 2, "into": h.get("into", 3) * 2}) + "\n")
        print("  hook     %-24s %dx%d, rope %d rows" % (h["take"], (x1 - x0) * 2, (y1 - y0) * 2, h["rope"] * 2))
    for name, p in sorted(picks["props"].items()):
        p = p if isinstance(p, dict) else {"take": p}
        a = load(p["take"])
        if "clear_light_below" in p:
            y = p["clear_light_below"]
            lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
            light = (lum > 150) & (a[..., 3] > 0)
            light[:y] = False
            a[light] = 0
        x0, y0, x1, y1 = ink(a)
        save(double(a[y0:y1, x0:x1]), "prop_wall_%s.png" % name)
        print("  prop     %-24s %-24s %dx%d" % (name, p["take"], (x1 - x0) * 2, (y1 - y0) * 2))


if __name__ == "__main__":
    main()
