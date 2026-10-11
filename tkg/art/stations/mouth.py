"""ONE MOUTH FOR EVERY SHIP (Jon: "We need to have the ship door opening always be the same size, no matter what
ship you are in. We need to have it as tall as the large ships."): every kept side made TALL rows taller, through
its entrance and the hull either side of it, so its hallway passes the tallest fitted hull at its own size.

THE HEIGHT: `sheet=MouthSize` measures every manufacturer's hull at every weight and grade, every mount filled, as
its nose reaches the lips on the dock's approved curve. The tallest (the C-grade heavies, Korvan's Bastion Monitor
and Verity's Magnum Opus with their turrets) stands rows 200.0..305.2 of the old plate there. The medium Jon
approved stands 216.6..283.9 in the old recess (rows 206..283): 10.6 px under its top, its keel on the lower lip.
With the same room the mouth must reach from row 189 to row 306: 17 px higher and 22 px lower than it was. The
inner door's planks repeat every 12 rows, so the height added is a whole number of planks: 48 rows (4 planks). The
plate sits with your ship's middle on row 266 (`StationFace.ROW`, 250 before), so the mouth stands 60 px above it and
66 below: the tallest goes in 10 px from each lip, its top as far from the upper lip as the medium's was.

THE CUT: TALL rows are put in across the whole plate near row CUT (inside the hallway, between the planks of its
door), so the lips, the frame, the lamp strip, the decks, boxes and drums all move apart together and nothing is
covered or uncovered. Each column is cut where its own pixels genuinely repeat: a block of p rows (p dividing TALL)
followed by the same p rows again, copied TALL / p times -- never one row stretched. The row each column is cut at
may wander a little from its neighbours' (within WANDER rows), where a column is plain: the cut row is chosen along
the plate by dynamic programming, the cost a column's own mismatch plus a little for every row it steps from the
last column's.

    from mouth import taller, TALL, CUT
"""
import numpy as np

TALL = 48
CUT = 241
WANDER = 16
PERIODS = [p for p in range(1, TALL + 1) if TALL % p == 0 and p <= 24]
STEP = 2.0
# THE HALLWAY IS CUT AT ONE ROW: its door's planks are horizontal rows of pattern, which break if neighbouring
# columns are cut at different rows. Every column from the mouth's left edge to the recess's end is cut at CUT itself,
# between two planks of the door (rows 229..240 then 241..252 are the same 12 rows). The frame's right side and the
# lamp strip beside it are vertical bands, each column cut where it repeats.
ENTRANCE = (76, 212)
LONGER = 0.01


def _cost(col, c, p):
    a = col[c - p:c].astype(float)
    b = col[c:c + p].astype(float)
    # alpha counts like colour: a column running out of the hull must keep its edge where it is
    return float(np.abs(a - b).mean())


def plan(img, cut=CUT, wander=WANDER):
    """each column's (cut row, period), and its mismatch"""
    H, W = img.shape[:2]
    rows = list(range(cut - wander, cut + wander + 1))
    n = len(rows)
    cost = np.zeros((W, n))
    per = np.zeros((W, n), int)
    for x in range(W):
        col = img[:, x]
        for i, c in enumerate(rows):
            if ENTRANCE[0] <= x < ENTRANCE[1] and c != cut:
                cost[x, i] = 1e6
                per[x, i] = 1
                continue
            best = None
            for p in PERIODS:
                if c - p < 0 or c + p > H:
                    continue
                e = _cost(col, c, p)
                # (of blocks that repeat as well, the longest: one flat row repeated inside a plank of the door makes
                # one plank four times taller, where twelve rows repeated make four more planks)
                sc = e - LONGER * p
                if best is None or sc < best[0]:
                    best = (sc, p, e)
            cost[x, i] = best[2]
            per[x, i] = best[1]
    acc = cost[0].copy()
    back = np.zeros((W, n), int)
    idx = np.arange(n)
    for x in range(1, W):
        tr = acc[None, :] + STEP * np.abs(idx[:, None] - idx[None, :])
        back[x] = tr.argmin(1)
        acc = cost[x] + tr.min(1)
    sel = np.zeros(W, int)
    sel[-1] = int(acc.argmin())
    for x in range(W - 1, 0, -1):
        sel[x - 1] = back[x, sel[x]]
    cuts = np.array([rows[i] for i in sel])
    pers = np.array([per[x, sel[x]] for x in range(W)])
    errs = np.array([cost[x, sel[x]] for x in range(W)])
    return cuts, pers, errs


def taller(img, cuts=None, pers=None):
    """the plate TALL rows taller: rows above each column's cut where they were, its repeating block copied in,
    the rest TALL rows lower. Returns (taller image, cuts, periods, mismatch)."""
    errs = None
    if cuts is None:
        cuts, pers, errs = plan(img)
    H, W = img.shape[:2]
    out = np.zeros((H + TALL,) + img.shape[1:], img.dtype)
    for x in range(W):
        c, p = int(cuts[x]), int(pers[x])
        col = img[:, x]
        out[:c, x] = col[:c]
        out[c:c + TALL, x] = np.concatenate([col[c - p:c]] * (TALL // p), 0)
        out[c + TALL:, x] = col[c:]
    return out, cuts, pers, errs


def extend_picture(img, lo=None, hi=None):
    """an interior made TALL rows taller at its own cleanest cut (one row across, a repeating block): (picture,
    (cut, period, mismatch))"""
    H = img.shape[0]
    best = None
    for p in PERIODS:
        for c in range(max(p + 4, lo or 0), min(H - p - 4, hi or H)):
            e = float(np.abs(img[c - p:c].astype(float) - img[c:c + p].astype(float)).mean())
            if best is None or e < best[2]:
                best = (c, p, e)
    c, p, e = best
    out = np.concatenate([img[:c]] + [img[c - p:c]] * (TALL // p) + [img[c:]], 0)
    return out, best


def cut_columns(img, cuts, period, tall=TALL):
    """`img` made `tall` rows taller, each column at its own cut row, its `period`-row block above the cut copied in"""
    H, W = img.shape[:2]
    out = np.zeros((H + tall,) + img.shape[1:], img.dtype)
    for x in range(W):
        c = int(cuts[x])
        col = img[:, x]
        out[:c, x] = col[:c]
        out[c:c + tall, x] = np.concatenate([col[c - period:c]] * (tall // period), 0)
        out[c + tall:, x] = col[c:]
    return out


def extend_around_objects(img, period, tall=TALL, lo=None, hi=None, step=1.0):
    """an interior made `tall` rows taller through its BACK WALL only: each column cut at a row of its own where the
    wall (the dark, unsaturated ribs or bricks) runs `period` rows above and below with nothing in front of it, the
    wall's own `period`-row block copied in -- so clamps keep their arms, crates their height, and the wall grows
    between the clamp jaws and the floor. Neighbouring columns may cut at different rows: the wall repeats every
    `period` rows and `tall` is a multiple of it, so the bricks carry on across. Returns (picture, cuts)."""
    a = img.astype(float)
    H, W = a.shape[:2]
    # (the wall runs across in rows -- ribs or courses of brick -- so a thing in front of it is a pixel far from its
    # own row's commonest colour; the bricks' mortar is matched by the row's own spread)
    med = np.median(a, 1, keepdims=True)
    dev = np.abs(a - med).sum(-1)
    spread = np.median(dev, 1, keepdims=True)
    obj = dev > (spread * 2.5 + 24)
    # (grow the things a little, so a cut never grazes an outline)
    o2 = obj.copy()
    for dy in (-2, -1, 1, 2):
        o2 |= np.roll(obj, dy, 0)
    for dx in (-1, 1):
        o2 |= np.roll(obj, dx, 1)
    lo = lo if lo is not None else period + 6
    hi = hi if hi is not None else H - period - 6
    rows = list(range(lo, hi))
    n = len(rows)
    cost = np.zeros((W, n))
    for x in range(W):
        free = []
        for i, c in enumerate(rows):
            e = float(np.abs(a[c - period:c, x] - a[c:c + period, x]).mean())
            blocked = bool(o2[c - period:c + period, x].any())
            cost[x, i] = e + (1000.0 if blocked else 0.0)
            free.append(not blocked)
        if not any(free):
            # (a column that is all frame or all object: cut where it repeats best)
            cost[x] = np.where(cost[x] >= 1000.0, cost[x] - 1000.0, cost[x])
    acc = cost[0].copy()
    back = np.zeros((W, n), int)
    idx = np.arange(n)
    for x in range(1, W):
        tr = acc[None, :] + step * np.abs(idx[:, None] - idx[None, :])
        back[x] = tr.argmin(1)
        acc = cost[x] + tr.min(1)
    sel = np.zeros(W, int)
    sel[-1] = int(acc.argmin())
    for x in range(W - 1, 0, -1):
        sel[x - 1] = back[x, sel[x]]
    cuts = np.array([rows[i] for i in sel])
    out = cut_columns(img, cuts, period, tall)
    blocked = int(sum(cost[x, sel[x]] >= 1000.0 for x in range(W)))
    return out, cuts, blocked
