"""Level furniture from PixelLab takes: racks seated on the stock's boards, and
counters brought to the room's pixel size.

    python tools/furniture_seat.py tools/room_stage/raw <out dir>

<raw dir> holds rack_<u|o|s|c|k>.png (120x156, pixflux, no background), the
head-on retakes named in HEADON, and till_<u|o|s|c|k>.png (180x128). The rack
takes live in tools/room_stage/raw. Writes rack2_<level>.png and till_<level>.png,
which go into tools/room_stage.

RACKS. The bench stands parts on two boards at rows 59 and 122 of a 116-wide
rack (ShelfDisplay's geometry, drawn at 1x and doubled). A generated rack puts
its shelves wherever it likes and is narrower, so each one is re-cut:

  * extra shelves are DELETED as whole rows (a shelf spans post to post, so
    taking its rows out leaves the posts and the back continuous);
  * each gap between the anchors is lengthened or shortened by repeating or
    dropping the most redundant rows inside a range known to be plain -- never
    inside a crown, a label or a shelf edge;
  * width is added the same way, one plain column at a time, spread out so no
    single column is stretched into a smear.

Nothing is scaled. Every pixel in the result is a pixel the generator drew.
The anchors in SPEC were read off each take at 5x with a row ruler; a new
take needs its own.

COUNTERS ARE DOUBLED ART. The shop's till is drawn at half size and doubled,
like every prop, so one art pixel is 2x2 on the wall. A take generated at the
full 180x128 has pixels half that size and looks sharper than everything round
it. Each 2x2 block is folded to its commonest colour (the darkest on a
four-way tie, which is usually the outline) and doubled back. A pixflux redraw
seeded with the halved take was tried on the city counter and was no better:
it lost the magenta and the lucky cat.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

RAW = OUT = ""
BOARDS = (59, 122)
RACK_W = 116


def row_cost(a, r):
    """How much would be lost dropping row r (its neighbours' disagreement)."""
    lo = max(0, r - 1)
    hi = min(a.shape[0] - 1, r + 1)
    return int(np.abs(a[lo].astype(int) - a[hi].astype(int)).sum())


def dup_cost(a, r):
    """How visible a copy of row r would be (it against the row below)."""
    nxt = min(a.shape[0] - 1, r + 1)
    return int(np.abs(a[r].astype(int) - a[nxt].astype(int)).sum())


def resize_rows(a, lo, hi, delta):
    """Add (delta > 0) or drop (delta < 0) rows inside [lo, hi)."""
    touched = []
    while delta != 0:
        best, br = None, None
        for r in range(lo, hi):
            c = dup_cost(a, r) if delta > 0 else row_cost(a, r)
            # SPREAD THEM: a row next to one already touched costs more, so a
            # long gap grows evenly instead of one row repeated forty times.
            c += sum(40000 for t in touched if abs(t - r) <= 2)
            if best is None or c < best:
                best, br = c, r
        if delta > 0:
            a = np.concatenate([a[:br + 1], a[br:br + 1], a[br + 1:]], axis=0)
            touched = [t + 1 if t > br else t for t in touched] + [br + 1]
            hi += 1
            delta -= 1
        else:
            a = np.concatenate([a[:br], a[br + 1:]], axis=0)
            touched = [t - 1 if t > br else t for t in touched] + [br]
            hi -= 1
            delta += 1
    return a


def widen(a, lo, hi, target):
    touched = []
    while a.shape[1] < target:
        best, bc = None, None
        for c in range(lo, hi):
            cost = int(np.abs(a[:, c].astype(int) - a[:, c + 1].astype(int)).sum())
            cost += sum(40000 for t in touched if abs(t - c) <= 2)
            if best is None or cost < best:
                best, bc = cost, c
        a = np.concatenate([a[:, :bc + 1], a[:, bc:bc + 1], a[:, bc + 1:]], axis=1)
        touched = [t + 1 if t > bc else t for t in touched] + [bc + 1]
        hi += 1
    return a


# Anchors are in the RAW generation's rows. Ops run bottom-up, so an op never
# moves the rows of an op still to come.
SPEC = {
    # breeze blocks and two planks: the top plank IS the top, so the wall
    # above it has to grow -- out of the tarp-and-block rows between planks.
    "u": {"p1": 27, "p2": 76, "base_to": 45, "base_carve": (88, 118),
          "seg1_carve": (40, 74), "seg0_band": (38, 68), "seg0_carve": (22, 60),
          "cols": (40, 80)},
    "o": {"p1": 35, "p2": 98, "delete": [(64, 74)], "base_to": 38, "base_carve": (106, 124),
          "seg1_carve": (44, 62), "seg0_carve": (20, 33), "cols": (46, 94),
          "label": (22, 20, 36, 44)},
    "s": {"p1": 51, "p2": 127, "delete": [(85, 100)], "base_to": 38, "base_carve": None,
          "seg1_carve": (62, 82), "seg0_carve": (31, 46), "cols": (48, 97)},
    "c": {"p1": 60, "p2": 99, "base_to": 35, "base_carve": (102, 114),
          "seg1_carve": (64, 96), "seg0_carve": (26, 56), "cols": (40, 86)},
    "k": {"p1": 56, "p2": 108, "delete": [(76, 85)], "base_to": 40, "base_carve": None,
          "seg1_carve": (62, 100), "seg0_carve": (38, 52), "cols": (42, 80)},
}


def seat(level):
    sp = SPEC[level]
    im = Image.open(os.path.join(RAW, "rack_%s.png" % level)).convert("RGBA")
    a = np.array(im)
    a[a[:, :, 3] <= 24] = 0
    if "label" in sp:
        # A LABEL THAT READS AS LETTERS goes: flat yellow, two dark rules.
        x0, y0, x1, y1 = sp["label"]
        box = a[y0:y1, x0:x1]
        yel = box[(box[:, :, 0] > 150) & (box[:, :, 1] > 150) & (box[:, :, 2] < 90)]
        if len(yel):
            col = np.median(yel, axis=0).astype(np.uint8)
            m = box[:, :, 3] > 0
            box[m] = col
            box[4:5, 2:-2][box[4:5, 2:-2, 3] > 0] = (40, 36, 20, 255)
            box[-6:-5, 2:-2][box[-6:-5, 2:-2, 3] > 0] = (40, 36, 20, 255)
    ys = np.where(a[:, :, 3] > 0)[0]
    top, bottom = int(ys.min()), int(ys.max()) + 1
    p1, p2 = sp["p1"], sp["p2"]
    # base: p2 .. bottom -> base_to rows
    base_now = bottom - p2
    if sp.get("base_carve") and base_now != sp["base_to"]:
        lo, hi = sp["base_carve"]
        a = resize_rows(a, lo, hi, sp["base_to"] - base_now)
    # deletions between the anchors (bottom-up)
    for d0, d1 in sorted(sp.get("delete", []), reverse=True):
        a = np.concatenate([a[:d0], a[d1:]], axis=0)
        if d0 < p2:
            p2 -= (d1 - d0)
    # seg1: p1 .. p2 -> 63
    lo, hi = sp["seg1_carve"]
    a = resize_rows(a, lo, min(hi, p2 - 2), (BOARDS[1] - BOARDS[0]) - (p2 - p1))
    # seg0: top .. p1 -> 59
    need = BOARDS[0] - (p1 - top)
    if "seg0_band" in sp and need > 0:
        b0, b1 = sp["seg0_band"]
        band = a[b0:b1].copy()
        a = np.concatenate([a[:p1], band, a[p1:]], axis=0)
        # the band went in ABOVE the plank, so the plank moved down by its height
        need -= (b1 - b0)
        p1 += (b1 - b0)
    lo, hi = sp["seg0_carve"]
    a = resize_rows(a, lo, min(hi, p1 - 1), need)
    # crop to the ink, keeping the top where it was measured from
    ys, xs = np.where(a[:, :, 3] > 0)
    a = a[top:int(ys.max()) + 1, int(xs.min()):int(xs.max()) + 1]
    x0 = int(xs.min())
    lo, hi = sp["cols"]
    a = widen(a, lo - x0, hi - x0, RACK_W)
    if a.shape[1] > RACK_W:
        cut = a.shape[1] - RACK_W
        a = a[:, cut // 2: a.shape[1] - (cut - cut // 2)]
    out = Image.fromarray(a)
    out.save(os.path.join(OUT, "rack2_%s.png" % LEVEL_NAME[level]))
    return out


LEVEL_NAME = {"u": "unclaimed", "o": "outpost", "s": "settlement", "c": "city", "k": "capital"}

def majority_half(a):
    """Half size by the commonest colour of each 2x2 block."""
    from collections import Counter
    H2, W2 = a.shape[0] // 2, a.shape[1] // 2
    out = np.zeros((H2, W2, 4), np.uint8)
    for y in range(H2):
        for x in range(W2):
            blk = a[2 * y:2 * y + 2, 2 * x:2 * x + 2].reshape(4, 4)
            op = [tuple(int(v) for v in p) for p in blk if p[3] > 24]
            if len(op) < 2:
                continue
            c = Counter(op).most_common()
            out[y, x] = min(op, key=lambda p: p[0] + p[1] + p[2]) if c[0][1] == 1 else c[0][0]
    return out


def counter(raw, level, out_dir, erase=None):
    a = np.array(Image.open(os.path.join(raw, "till_%s.png" % level)).convert("RGBA"))
    if erase:
        x0, y0, x1, y1 = erase
        a[y0:y1, x0:x1] = 0
    big = Image.fromarray(majority_half(a)).resize((a.shape[1], a.shape[0]), Image.NEAREST)
    b = np.array(big)
    ys, xs = np.where(b[:, :, 3] > 24)
    # even offsets, so every 2x2 block stays whole; standing on its own foot
    x0 = int(xs.min()) & ~1
    x1 = (int(xs.max()) + 2) & ~1
    y0 = int(ys.min()) & ~1
    y1 = (int(ys.max()) + 2) & ~1
    Image.fromarray(b[y0:y1, x0:x1]).save(os.path.join(out_dir, "till_%s.png" % LEVEL_NAME[level]))


# The outpost take floated a sign over the counter with letter-like marks on it.
TILL_ERASE = {"o": (134, 8, 170, 38)}

# HEAD-ON TAKES (2026-09-26). Jon: "Change the rack to be more head-on" -- the
# first outpost and settlement racks were drawn three-quarter, a side panel
# showing. These replaced them, prompted "seen perfectly head-on as a flat
# front elevation, orthographic like a technical drawing, perfectly
# symmetrical ... no side panel visible, no depth". Seated by explicit row
# operations, in the order given, on the raw take:
#   ("clear_cols", x0, x1)  ("delete", r0, r1)  ("repeat", at, row, n)
# Repeat ONE plain row, never a band: a band carries the grey strip under a
# shelf with it and reads as three extra shelves.
HEADON = {
    "o": ("rack_o1", [("clear_cols", 106, 120), ("delete", 114, 124), ("delete", 80, 89),
                      ("delete", 35, 47), ("repeat", 60, 60, 26), ("repeat", 26, 26, 21)], (20, 96)),
    # THE SETTLEMENT RACK REDRAWN (2026-09-26). The hutch was "too frilly and
    # formal for a space ship": its prompt named a dresser, a carved crown,
    # roses and lace, and got them. Four retakes named only parts; Jon picked
    # the quilted back ("quilted back is FIRE") -- terracotta steel uprights,
    # warm planks, mustard padded panels. It came with three compartments:
    # the middle plank and the shadow strip under it go, so two cushions stack
    # into the top compartment; the lower compartment grows 16 rows and the
    # top one 6 ("mix": the inner columns copy a plain row, the posts copy a
    # run of their own varied rows, so they do not smear); the bottom plank
    # grows 3 so its tags hang on it. Boards at 59 and 119.
    "s": ("rack_s_padded", [("repeat", 133, 132, 3), ("mix", 97, 95, 101, 16, 20, 101),
                            ("delete", 43, 62), ("mix", 18, 17, 24, 6, 20, 101)], (22, 98)),
}


def seat_ops(level):
    name, ops, cols = HEADON[level]
    a = np.array(Image.open(os.path.join(RAW, name + ".png")).convert("RGBA"))
    a[a[:, :, 3] <= 24] = 0
    for op in ops:
        if op[0] == "clear_cols":
            a[:, op[1]:op[2]] = 0
        elif op[0] == "delete":
            a = np.concatenate([a[:op[1]], a[op[2]:]], axis=0)
        elif op[0] == "repeat":
            at, row, n = op[1:]
            a = np.concatenate([a[:at]] + [a[row:row + 1]] * n + [a[at:]], axis=0)
        elif op[0] == "mix":
            at, inner, posts, n, x0, x1 = op[1:]
            rows = []
            for i in range(n):
                r = a[posts + i].copy()
                r[x0:x1] = a[inner, x0:x1]
                rows.append(r[None])
            a = np.concatenate([a[:at]] + rows + [a[at:]], axis=0)
    ys, xs = np.where(a[:, :, 3] > 0)
    a = a[int(ys.min()):int(ys.max()) + 1, int(xs.min()):int(xs.max()) + 1]
    a = widen(a, cols[0] - int(xs.min()), cols[1] - int(xs.min()), RACK_W)
    out = Image.fromarray(a)
    out.save(os.path.join(OUT, "rack2_%s.png" % LEVEL_NAME[level]))
    return out

# ROOM FOR THE TAGS (2026-09-26). Seated on rows 59 and 122, the settlement
# hutch, the capital vitrine and the city case put a drawer, a wood rail or a
# lit base straight under the lower board -- and the bench hangs each part's
# rarity pips and price tag in the 14 rows under its board, so the tags sat on
# the rose drawer (Jon: "kinda a problem?"). Each gets a plain strip under the
# lower board, paid for out of the plain rows between the boards, which had 8
# to spare over the 54 the tags and a two-cell part need:
#   hutch: 8 of its dark back under the board, the rose drawer below them;
#   vitrine: 6 of the plain rail under the glass, the drawer below them;
#   case: 8 of the glass under the teal board, the lit base below them.
# The lower board moves up to 117, so these racks carry their own board rows
# (RACK_BOARDS, written to rack_boards.json beside them) and the bench stands
# the stock on those.
#
# (The hutch squared under its crown, 2026-09-26, lasted an hour: Jon had it
# redrawn instead -- see THE SETTLEMENT RACK REDRAWN in HEADON.)
RESEAT = {
    "k": [("repeat", 126, 125, 6), ("delete", 85, 90)],
    "c": [("repeat", 128, 127, 8), ("delete", 104, 109)],
}
RACK_BOARDS = {"settlement": [59, 119], "capital": [59, 117], "city": [59, 117]}


def reseat(level, im):
    """The tag strip, cut into a seated rack (see ROOM FOR THE TAGS)."""
    a = np.array(im.convert("RGBA"))
    for op in RESEAT[level]:
        if op[0] == "delete":
            a = np.concatenate([a[:op[1]], a[op[2]:]], axis=0)
        elif op[0] == "repeat":
            at, row, n = op[1:]
            a = np.concatenate([a[:at]] + [a[row:row + 1]] * n + [a[at:]], axis=0)
    out = Image.fromarray(a)
    out.save(os.path.join(OUT, "rack2_%s.png" % LEVEL_NAME[level]))
    return out


# COUNTERS REDRAWN (2026-09-26). Folded to the room's pixel size, the first
# counters were only 142-154 wide against the standard 180 -- the generator had
# left margin round each, and halving took half of what was left. Jon: "why are
# some of the tills so much smaller than the standard ones". Each was redrawn at
# 92x64 (the standard counter's half size), seeded with its folded self scaled
# up to fill the frame, strength 220 -- same design, 174-176 wide when doubled.
# counter() and majority_half() stay as the record of the first pass.
#
# THE SETTLEMENT STALL AND THE OUTPOST LOCKERS were redrawn bigger (Jon: "the
# counter is too small", "lockers are too small"), generated at the half size
# they are wanted at and simply cropped and doubled -- stall 112x84 seeded with
# the first stall scaled up, lockers 64x92 fresh. No seating needed.


if __name__ == "__main__":
    RAW, OUT = sys.argv[1], sys.argv[2]
    os.makedirs(OUT, exist_ok=True)
    for lv in SPEC:
        use_ops = lv in HEADON and os.path.exists(os.path.join(RAW, HEADON[lv][0] + ".png"))
        o = seat_ops(lv) if use_ops else seat(lv)
        if lv in RESEAT:
            o = reseat(lv, o)
        # NO COUNTERS: every level counter is a redraw now (see COUNTERS
        # REDRAWN), so folding the old takes would only overwrite them.
        print("rack2_%-10s %dx%d" % (LEVEL_NAME[lv], o.width, o.height))
    with open(os.path.join(OUT, "rack_boards.json"), "w") as f:
        json.dump(RACK_BOARDS, f, indent=1)
