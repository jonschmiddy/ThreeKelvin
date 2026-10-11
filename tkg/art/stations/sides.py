"""THE STATION SIDES JON KEPT, lit and split for the game (Jon's 1A for lights and depth: "all of it").

    uv run --with numpy --with pillow --with scipy python sides.py [--check <preview dir>]

Reads the kept plates in `src/` (470 x 530, the ships' pixel, every one carrying the Drum's entrance at the same
rows) and the kept interiors in `src/interiors/`, and writes what `StationFace` draws:

  <side>/near.png     the hull less the bay's recess, the entrance and every part at the nearest depth: the star's
                      rim (upper left), shaded undersides, cast shadows and the far step baked in; lamps dark in
                      their housings (drawn over it, lit, at their own power)
  <side>/far2.png, far3.png   (the piles only) boxes further back, drawn first, each at its own parallax
  <side>/solid.png    the whole hull less the recess in one dark tone: drawn under the layers, so a gap opened by
                      parallax is a crevice, and your ship behind the hull is never seen through one
  <side>/lamps.png    the lamp pixels alone, lit
  <side>/bay_dark.png, bay_lit.png   the bay (plate x 76..211, rows 206..283) with the inner door shut, and lit
                      from it (one level per panel by its distance from the door, the door's planks even, its frame
                      glowing): the game draws the lit one over the dark at the door's power
  <side>/side.json    the side's extra lamps (rect, kind, colour, glow radius, group: seam, windows, strings), the
                      lights drawn in code (strobes, beacons), its layers' parallax, and the hull window the camera
                      tiles past the plate's right end
  interiors/<id>/dark.png, lit.png   each kept interior (the recess only), dark and lit

The selections are checked by eye: `--check` writes each side's lamp pixels magenta, what the sky clean-up took
off the hull, and the lit composite, at 2x.

Faults fixed from the entrances stream's lightkit (scratchpad entrances/work/lightkit.py):
  - stray bright fragments along Drum 3's lower seam: the sky clean-up took dark grooves joined to space at the
    plate's bottom edge off the hull, so the rim light ran down the groove's edge; only dark blobs that touch the
    open sky above or left of the hull are sky now, and the rim needs real space (a big region of it) beside it
  - the Shanty's "windows": the warm rule caught the gold curtains, the brass plates and the ring's highlights (the
    whole-lamp fault again); windows are the capsule's portholes only, by box, and its string lights by box
  - the lower lip's guide row came out as one lamp: the game draws the entrance's lamps by StationFace's own
    rects, so the json carries only what is not the entrance
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mouth  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
BAYER = np.array([[0.0, 0.5], [0.75, 0.25]])
HEAT = [(0x5c, 0x28, 0x0c), (0x96, 0x42, 0x14), (0xcc, 0x64, 0x1c), (0xff, 0xa6, 0x3c), (0xff, 0xdc, 0xa0), (0xff, 0xf6, 0xe2)]
STAR = np.array([255, 240, 214], float)
CREVICE = (8, 10, 14)
# THE PLATES ARE MADE TALLER FIRST (`mouth.py`: one mouth for every ship, 48 rows taller through the hallway), and
# every number below is on the taller plate: the entrance, the recess, the inner door 48 rows taller than they were
# (the rows above the cut where they were, those below it 48 lower)
EBOX = (78, 200, 238, 338)          # the kept entrance, plate px x0, y0, x1, y1 (its lamp strip to x 236)
RECESS = (84, 206, 212, 332)        # the bay's dark interior (the panels the door lights)
# what is behind your ship: StationFace.RECESS, every row of the bay from the plate's left edge to the recess's end
# (the mouth's few columns left of x 84 included, so the ship's nose is never behind them going in); the bay
# pictures are this box, x 76..211
BAYBOX = (76, 206, 212, 332)
DOOR = (124, 213, 179, 327)         # the inner door's outer frame
HULL_K = 0.82
# the recovered plates (all but the Terraces) were seen to plate x 398; past it, to x 629, their right ends were
# painted by PixelLab (src/painted/: one pixflux take each, joined at x 399, the seen pixels untouched; the plates
# as recovered are in src/recovered/)
SEEN_W = 399

# side: (kind, source)
# the hull the camera tiles past the plate, where a side keeps its own: Drum take 1's two panels seam to seam
# (StationFace.HULL_SRC / HULL_X0), as its dock was approved
HULLS = {"drum1": (318, 109, 427)}
# side: (kind, source, its sky clean-up: "none", "dark" (near-black blobs joined to the open sky), "brown" (and the
# brown of the LOCAL frame the plate was recovered from), and boxes where a dark gap is the pile's own crevice)
SIDES = {
    # Drum take 1 (Jon's 2B: lit like the other six; src/drum1.png is art/stations/drum_plate.png, as approved)
    "drum1": ("drum", "drum1.png", "none", []),
    "drum3": ("drum", "drum3.png", "none", []),
    "pile1": ("pile", "pile1.png", "dark", []),
    "pile3": ("pile", "pile3.png", "dark", [(280, 348, 345, 393)]),
    "pile4": ("pile", "pile4.png", "dark", [(280, 348, 345, 393)]),
    "shanty3": ("shanty", "shanty3.png", "brown", []),
    "terraces": ("wall", "terraces.png", "dark", []),
}
# (all thirteen are made; the irises' rings cannot be made taller cleanly, and `StationSides` leaves them out of the
# pool until they are painted at the new height)
INTERIORS = ["iris_90_0", "iris_90_1", "iris_220_1", "hallway_90_1", "hallway_130_0", "hallway_130_1", "hallway_170_0",
             "hallway_170_1", "hallway_220_0", "cargo_90_0", "cargo_130_0", "cargo_130_1", "cargo_170_0"]


def lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def bayer(h, w):
    return np.tile(BAYER, (h // 2 + 1, w // 2 + 1))[:h, :w]


def clean_mask(al, rgb, rule="dark", keep=()):
    """the hull's pixels. A take's own dark sky left behind is space, not hull: near-black blobs thicker than 3 px
    joined to the open sky. Only sky that reaches the plate's top or left edge counts (a groove running off the
    bottom edge is hull: taking it put Drum 3's rim light down its edge)."""
    H, W = al.shape
    dark = lum(rgb) < 16
    if rule == "none":
        dark[:] = False
    if rule == "brown":
        r, b = rgb[..., 0], rgb[..., 2]
        dark = dark | ((lum(rgb) < 34) & (r > b + 4))
    for (kx0, ky0, kx1, ky1) in keep:
        dark[ky0:ky1, kx0:kx1] = False
    sky_lab, _ = ndimage.label(~al)
    edge_ids = np.unique(np.concatenate([sky_lab[0], sky_lab[:, 0]]))
    sky = np.isin(sky_lab, edge_ids[edge_ids > 0])
    lab, n = ndimage.label(dark | sky)
    touching = np.unique(lab[sky])
    blob = np.isin(lab, touching[touching > 0]) & dark & al
    blob = ndimage.binary_opening(blob, structure=np.ones((3, 3)))
    removed = al & blob
    al = al & ~blob
    lab, n = ndimage.label(al)
    if n:
        sz = ndimage.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1))
        al = al & np.isin(lab, 1 + np.nonzero(sz >= 6)[0])
    sl, sn = ndimage.label(~al)
    if sn:
        ss = ndimage.sum(np.ones_like(sl), sl, index=np.arange(1, sn + 1))
        al = al | np.isin(sl, 1 + np.nonzero(ss < 80)[0])
    return al, removed


# ------------------------------------------------------------------------------------------------ the lamps

def comps(m, rgb, kind, radius, group, min_px=1):
    out = []
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    keep = np.zeros_like(m)
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None:
            continue
        c = lab[sl] == i
        if c.sum() < min_px:
            continue
        col = rgb[sl][c].mean(0)
        out.append(dict(kind=kind, rect=[int(sl[1].start), int(sl[0].start), int(sl[1].stop - sl[1].start),
                                         int(sl[0].stop - sl[0].start)],
                        color="#%02x%02x%02x" % tuple(int(v) for v in col), glow_radius=radius, group=group))
        keep[sl] |= c
    return out, keep


def box(shape, x0, y0, x1, y1):
    m = np.zeros(shape, bool)
    m[y0:y1, x0:x1] = True
    return m


def find_lamps(rgb, al, kind):
    """(every lamp pixel, the extra lamps for the json). The entrance's lamps by lamps.py's rules inside its own
    rows; per kind, the drum's seam lamps, the shanty's portholes and its string lights, each inside a box."""
    H, W = al.shape
    L = lum(rgb)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mask = np.zeros_like(al)
    # the entrance: guide rows and the strip beside the door (StationFace draws these by its own rects)
    warm = (r - b > 40) & (r > 80) & al
    mask |= warm & (box(al.shape, 84, 203, 222, 206) | box(al.shape, 84, 332, 222, 335))
    mask |= (r - b > 40) & (r > 120) & al & box(al.shape, 224, 200, 238, 338)
    lamps = []
    ent = box(al.shape, EBOX[0], EBOX[1] - 4, EBOX[2] + 4, EBOX[3] + 4)
    if kind == "drum":
        seam = (r > 170) & (r - b > 60) & (L > 140) & al & ~ent
        ls, m = comps(seam, rgb, "seam", 4, "seam", min_px=3)
        lamps += ls; mask |= m
        # Drum take 1's red beacon box above the hallway and its lit window below (lamps.py's own rules and
        # boxes); always on, the beacon slowly pulsing
        red = (((r > 150) & (g < 120) & (b < 110)) | ((r > 200) & (L > 150))) & al & box(al.shape, 200, 99, 212, 113)
        ls, m = comps(red & ~mask, rgb, "beacon_lamp", 6, "always", min_px=3)
        lamps += ls; mask |= m
        win = (r - b > 25) & (r > 70) & al & box(al.shape, 200, 440, 213, 458)
        ls, m = comps(win & ~mask, rgb, "window", 5, "always", min_px=3)
        lamps += ls; mask |= m
    if kind == "shanty":
        mx, mn = rgb.max(-1), rgb.min(-1)
        sat = (mx - mn) / np.maximum(mx, 1)
        # the capsule's lit portholes (its row of five, and the round ones toward its end)
        port = (L > 150) & (r - b > 60) & al & box(al.shape, 240, 70, W, 125)
        ls, m = comps(port, rgb, "window", 4, "windows", min_px=3)
        lamps += ls; mask |= m
        # the string lights: small saturated bulbs strung over the top (above the body and the capsule)
        # (each bulb a little block of about 4 x 4 in its own colour with one lit pixel)
        bulbs = (mx > 130) & (sat > 0.45) & al & box(al.shape, 0, 0, W, 125) & ~box(al.shape, 240, 70, W, 125)
        lab, n = ndimage.label(bulbs, structure=np.ones((3, 3)))
        if n:
            sz = ndimage.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1))
            bulbs = np.isin(lab, 1 + np.nonzero((sz >= 3) & (sz <= 22))[0])
        ls, m = comps(bulbs, rgb, "string", 3, "strings")
        lamps += ls; mask |= m
    return mask, lamps


def split_lamps(plate, mask):
    unlit = plate.astype(float).copy()
    lamps = np.zeros_like(plate)
    lamps[mask] = plate[mask]
    c = unlit[mask][:, :3]
    grey = c.mean(-1, keepdims=True)
    unlit[mask, :3] = np.clip((c * 0.55 + grey * 0.45) * 0.34, 0, 255)
    return unlit, lamps


# ------------------------------------------------------------------------------------------------ the bay

def light_bay(rgb):
    """(dark, lit) colours for the recess: panels by the art's own ink seams, one level each by its distance from
    the door, stepped in quarters, no dither; the door's planks lit evenly; its frame's outline glowing"""
    x0, y0, x1, y1 = RECESS
    sub = rgb[y0:y1, x0:x1].astype(float)
    Ls = lum(sub)
    ink = Ls < 10
    dark = sub * 0.45
    colink = ink.mean(0)
    seams = [x for x in range(sub.shape[1]) if colink[x] > 0.5]
    edges = [0] + seams + [sub.shape[1]]
    fac = np.zeros(sub.shape[1])
    dx0, dy0, dx1, dy1 = DOOR[0] - x0, DOOR[1] - y0, DOOR[2] - x0, DOOR[3] - y0
    for a, b in zip(edges[:-1], edges[1:]):
        if b - a < 1:
            continue
        cx = (a + b - 1) / 2
        d = max(0, dx0 - cx, cx - dx1)
        w = max(0.0, 1 - d / 75.0) ** 1.2
        w = np.round(w * 4) / 4
        fac[a:b] = 0.42 + 0.78 * w
    lit = sub * fac[None, :, None] + np.array(HEAT[2], float)[None, None] * (0.07 * np.clip(fac - 0.42, 0, None))[None, :, None]
    floor_rows = slice(max(0, dy1 - 18), sub.shape[0])
    lit[floor_rows] = sub[floor_rows] * np.minimum(fac[None, :, None] + 0.25, 1.45)
    dsub = sub[dy0:dy1, dx0:dx1]
    dl = Ls[dy0:dy1, dx0:dx1]
    plank = dl >= 10
    dlit = dsub * 1.25
    dlit[plank] = dlit[plank] + np.array(HEAT[3], float) * 0.10 * (dl[plank, None] / 40.0)
    lit[dy0:dy1, dx0:dx1] = dlit
    ring = np.zeros_like(ink)
    ring[dy0:dy1, dx0:dx1] = True
    inner = np.zeros_like(ink)
    inner[dy0 + 1:dy1 - 1, dx0 + 1:dx1 - 1] = True
    lit[ring & ~inner & ink] = np.array(HEAT[3], float)
    out1 = ndimage.binary_dilation(ring, iterations=1) & ~ring
    chk = (np.add.outer(np.arange(sub.shape[0]), np.arange(sub.shape[1])) % 2 == 0)
    sp = out1 & ~ink & chk
    lit[sp] = lit[sp] * 0.6 + np.array(HEAT[2], float) * 0.4
    return np.clip(dark, 0, 255), np.clip(lit, 0, 255)


# ------------------------------------------------------------------------------------------------ the hull

def static_terms(rgb, al, kind, lampmask, seed=7):
    """the shade multiplier S (stepped), the rim (alpha), the top edges caught by the star, the depth map"""
    H, W = al.shape
    by = bayer(H, W)
    L = lum(rgb)
    S = np.full((H, W), HULL_K)
    S[lampmask] = 1.0
    ent = box(al.shape, *EBOX)
    rec = box(al.shape, *RECESS)
    depth = np.ones((H, W), int)
    depth[~al] = 9
    if kind == "pile":
        outline = (L < 30) & al & ~ent
        lab, n = ndimage.label(al & ~outline & ~ent)
        sizes = ndimage.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1)) if n else []
        rng = np.random.default_rng(seed)
        for i in range(1, n + 1):
            # (ONE DEPTH PER WHOLE BOX: only a box its dark lines leave whole, 1500 px or more, may go back; a
            # box its own texture cuts into scraps stays near, or its scraps would part at different depths)
            r_ = int(rng.choice([1, 1, 2, 3]))
            if sizes[i - 1] >= 1500:
                # (and only a box-shaped piece: one that fills most of its bounding box; a piece running through
                # several boxes is ragged and stays near)
                sl_ = ndimage.find_objects((lab == i).astype(int))[0]
                area = (sl_[0].stop - sl_[0].start) * (sl_[1].stop - sl_[1].start)
                if sizes[i - 1] >= 0.8 * area:
                    depth[lab == i] = r_
        # (what frames the entrance stays with it: anything within 24 px of the kept entrance is near, or the
        # frame round the hallway would slide off its lamps)
        near_ent = box(al.shape, EBOX[0] - 24, EBOX[1] - 24, EBOX[2] + 24, EBOX[3] + 24)
        for i in np.unique(lab[near_ent & (lab > 0)]):
            depth[lab == i] = 1
        # (a whole box's scraps -- the pieces its own texture cut off -- go where the box goes: a small piece
        # ringed mostly by one far box takes its depth)
        objs = ndimage.find_objects(lab)
        # (every piece round it votes, the scraps of near boxes too)
        bigd = np.where(lab > 0, depth, 0)
        for i, sl in enumerate(objs, 1):
            if sl is None or sizes[i - 1] >= 1500:
                continue
            y0_, y1_ = max(0, sl[0].start - 4), min(H, sl[0].stop + 4)
            x0_, x1_ = max(0, sl[1].start - 4), min(W, sl[1].stop + 4)
            m = lab[y0_:y1_, x0_:x1_] == i
            ring = ndimage.binary_dilation(m, iterations=3) & ~m
            v = bigd[y0_:y1_, x0_:x1_][ring]
            v = v[v > 0]
            if len(v) < 6:
                continue
            vals, cnt = np.unique(v, return_counts=True)
            k = int(cnt.argmax())
            if vals[k] > 1 and cnt[k] >= 0.6 * len(v):
                depth[y0_:y1_, x0_:x1_][m] = int(vals[k])
        d2 = depth.copy()
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            d2 = np.minimum(d2, np.roll(np.roll(depth, dy, 0), dx, 1))
        depth = np.where(outline, np.minimum(d2, 3), depth)
        # NO COMBS: a box's dark texture (a grid, ribs) splits it into pieces that can land at different depths,
        # and the parallax then slides thin strips of it over the crevice (pile 3's teal box). A far layer is
        # only its thick parts (a 5 x 5 opening) in pieces of at least 150 px; the rest comes back to the near
        for dd in (2, 3):
            m = depth == dd
            thick = ndimage.binary_opening(m, structure=np.ones((5, 5)))
            lab2, n2 = ndimage.label(thick)
            if n2:
                sz2 = ndimage.sum(np.ones_like(lab2), lab2, index=np.arange(1, n2 + 1))
                thick = np.isin(lab2, 1 + np.nonzero(sz2 >= 150)[0])
            # (a piece's own outline stays with it: the thick part grown by 2 px, within what was at this depth)
            keep = ndimage.binary_dilation(thick, iterations=2) & m
            depth[m & ~keep] = 1
            # (and what is left must look like boxes: a far region that fills under 85% of its bounding box is
            # ragged -- a box's scraps strewn through its neighbours' -- and comes back near whole)
            lab3, n3 = ndimage.label(depth == dd)
            for j, sl in enumerate(ndimage.find_objects(lab3), 1):
                if sl is None:
                    continue
                mm = lab3[sl] == j
                if mm.sum() < 0.85 * mm.size or mm.shape[0] < 16 or mm.shape[1] < 16:
                    depth[sl][mm] = 1
    depth[ent] = 0
    for dd, f in ((2, 0.9), (3, 0.8)):
        S[(depth == dd) & ~lampmask] *= f
    sh = np.zeros((H, W))
    for k, s in ((1, 0.9), (2, 0.65), (3, 0.4)):
        nearer = np.roll(np.roll(depth, k, 0), k, 1)
        sh = np.maximum(sh, np.where((nearer < depth) & al & (depth < 9), s, 0))
    S[(sh > by * 0.95) & ~lampmask & ~rec] *= 0.55
    run = np.full(W, 99)
    below = np.zeros((H, W), int)
    for y in range(H - 1, -1, -1):
        run = np.where(al[y], np.minimum(run + 1, 99), 0)
        below[y] = run
    for dist, s in ((1, 0.95), (3, 0.8), (6, 0.6), (10, 0.35), (14, 0.15)):
        S[(below <= dist) & (below > 0) & al & (s > by) & ~lampmask] *= 0.86
    if kind == "drum":
        for x in range(W):
            ys = np.nonzero(al[:, x])[0]
            if len(ys) < 3:
                continue
            ya, yb = ys[0], ys[-1]
            u = (np.arange(ya, yb + 1) - ya) / max(yb - ya, 1) * 2 - 1
            lt = np.clip(-0.55 * u + 0.83 * np.sqrt(np.clip(1 - u * u, 0, 1)), 0, 1)
            f = np.round((0.66 + 0.4 * lt) * 6) / 6
            keep = lampmask[ya:yb + 1, x]
            S[ya:yb + 1, x][~keep] *= f[~keep]
    # THE STAR'S RIM (upper left): hull pixels with open space up or left of them. Space is the sky only -- a big
    # region of it (a slit or a hole in the hull is not where the star is seen from)
    sl, sn = ndimage.label(~al)
    big = np.zeros_like(al)
    if sn:
        ss = ndimage.sum(np.ones_like(sl), sl, index=np.arange(1, sn + 1))
        big = np.isin(sl, 1 + np.nonzero(ss >= 400)[0])
    up = np.roll(big, 1, 0); up[0] = True
    left = np.roll(big, 1, 1); left[:, 0] = True
    up2 = np.roll(big, 2, 0); up2[:2] = True
    rim = np.zeros((H, W))
    # (only on parts at least 5 px thick: cables, masts and the strings of lights get no rim)
    thick = ndimage.binary_opening(al, structure=np.ones((5, 5)))
    rim1 = al & thick & (up | left) & ~ent
    rim2 = al & thick & ~rim1 & up2 & ~ent & (by < 0.5)
    # the plate's own cut edges (its top row, its left column) are not an edge the star sees
    rim1[0] = False; rim2[:2] = False; rim1[:, 0] = False
    rim[rim1] = 0.55
    rim[rim2] = 0.25
    seam_above = np.roll(L, 1, 0) < L - 35
    from scipy.ndimage import uniform_filter1d
    te = al & seam_above & ~rec & ~lampmask & ~rim1
    te = te & (uniform_filter1d(te.astype(float), 9, axis=1) > 0.99)
    return S, rim, te, depth


def hull_window(rgb, al, lo=96, hi=200, a0=240, end=(0, SEEN_W)):
    """the window of the plate's own columns [a, a + w) the camera tiles past the plate: the one whose next
    column (a + w) is most like its first (a), on the rows the hull is seen in, so the tiles join where the plate's
    own pixels would have gone on; silhouettes must match. `end`: where the window may end (a + w), within the
    columns that are the plate's own (seen, or painted)"""
    rows = slice(110, 448)
    A = al[rows].astype(float)
    C = np.concatenate([rgb[rows], A[..., None] * 255], -1)
    best = None
    for w in range(lo, hi + 1):
        for a in range(a0, end[1] - w):
            if a + w >= end[1] or a + w < end[0]:
                continue
            e = np.abs(C[:, a] - C[:, a + w]).mean() + 4.0 * np.abs(A[:, a] - A[:, a + w]).mean() * 255
            # prefer wide windows a little (fewer repeats seen)
            e -= 0.02 * w
            if best is None or e < best[0]:
                best = (e, a, w)
    return best


def build(plate, kind, rule="dark", keep=(), hull=None):
    rgb = plate[..., :3].astype(float)
    al, removed = clean_mask(plate[..., 3] > 0, rgb, rule, keep)
    H, W = al.shape
    lampmask, lamps = find_lamps(rgb, al, kind)
    unlit, lamplayer = split_lamps(plate, lampmask)
    S, rim, te, depth = static_terms(rgb, al, kind, lampmask)
    base = unlit[..., :3] * S[..., None]
    base[te] = np.minimum(base[te] * 1.22 + 6, 255)
    r = rim[..., None]
    base = base * (1 - r) + STAR * r
    rec = box(al.shape, 0, BAYBOX[1], BAYBOX[2], BAYBOX[3])
    bay_dark, bay_lit = light_bay(rgb)
    front = al & ~rec

    def rgba(c, m):
        a = np.zeros((H, W, 4), np.uint8)
        a[..., :3] = np.clip(np.round(c), 0, 255).astype(np.uint8)
        a[..., 3] = np.where(m, 255, 0)
        return a

    out = {}
    bx0, by0, bx1, by1 = BAYBOX
    x0, y0, x1, y1 = RECESS
    for key, bay in (("bay_dark", bay_dark), ("bay_lit", bay_lit)):
        a = np.zeros((by1 - by0, bx1 - bx0, 4), np.uint8)
        a[..., :3] = np.clip(np.round(base[by0:by1, bx0:bx1]), 0, 255).astype(np.uint8)
        a[..., 3] = np.where(al[by0:by1, bx0:bx1], 255, 0)
        a[:, x0 - bx0:, :3] = np.round(bay).astype(np.uint8)
        a[:, x0 - bx0:, 3] = 255
        out[key] = a
    near = front & (depth <= 1)
    out["near"] = rgba(base, near)
    layers = [dict(file="near.png", parallax=1.0)]
    for d, p in ((2, 0.9), (3, 0.8)):
        m = front & (depth == d)
        if m.any():
            out["far%d" % d] = rgba(base, m)
            layers.insert(0, dict(file="far%d.png" % d, parallax=p))
    sol = np.zeros((H, W, 3)); sol[:] = CREVICE
    out["solid"] = rgba(sol, front)
    lam = lamplayer.copy()
    lam[rec] = 0
    out["lamps"] = lam
    # the lights drawn in code: a strobe on the top corner, a red beacon above the bay and a green one below
    code = []
    if kind == "drum":
        code += [dict(kind="strobe", at=[90, 43], radius=8, color="#b8e2f4", period=1.6, offset=0.0),
                 dict(kind="strobe", at=[90, 505], radius=8, color="#b8e2f4", period=2.1, offset=0.9)]
    else:
        top = int(np.nonzero(al.any(1))[0].min())
        topx = int(np.nonzero(al[top])[0].min())
        if top > 0:
            code.append(dict(kind="strobe", at=[topx + 3, top + 2], radius=8, color="#b8e2f4", period=1.6, offset=0.0))
    for (yy, col, off) in ((EBOX[1] - 30, "#ff4a36", 0.0), (EBOX[3] + 30, "#5ae678", 1.2)):
        xs = np.nonzero(al[yy, :240])[0]
        if len(xs):
            code.append(dict(kind="beacon", at=[int(xs.min()) + 3, yy], radius=5, color=col, period=2.4, offset=off))
    if hull is not None:
        hw = (0.0, hull[0], hull[1])
    elif W > 470:
        # A PLATE MADE WHOLE (Jon's 1B): its right end painted by PixelLab to x 629, past everything the camera
        # sees before the dock's dip to black; the tiles start at its painted end
        hw = hull_window(rgb, al, a0=SEEN_W + 20, end=(W - 40, W - 1))
    else:
        hw = hull_window(rgb, al)
    data = dict(kind=kind, size=[W, H], bay=list(BAYBOX), layers=layers, lamps=lamps, code_lights=code,
                hull=dict(src=[int(hw[1]), 0, int(hw[2]), H], x0=int(hull[2] if hull is not None else hw[1] + hw[2]),
                          err=round(float(hw[0]), 2)))
    return out, data, dict(al=al, removed=removed, lampmask=lampmask, rim=rim, te=te, depth=depth, base=base)


def interiors():
    """each kept interior made TALL rows taller (the new recess) at its own cleanest cut: a block of rows that
    genuinely repeats (`mouth.extend_picture`, found on the lit picture, the same cut made in the flat one)"""
    report = {}
    for k in INTERIORS:
        flat0 = np.asarray(Image.open(os.path.join(SRC, "interiors", k + "_flat.png")).convert("RGB"))
        lit0 = np.asarray(Image.open(os.path.join(SRC, "interiors", k + "_lit.png")).convert("RGB"))
        lit, (c, pp, e) = mouth.extend_picture(lit0)
        flat = np.concatenate([flat0[:c]] + [flat0[c - pp:c]] * (mouth.TALL // pp) + [flat0[c:]], 0).astype(float)
        report[k] = dict(cut=int(c), period=int(pp), mismatch=round(float(e), 2))
        d = os.path.join(HERE, "interiors", k)
        os.makedirs(d, exist_ok=True)
        a = np.full(flat.shape[:2] + (1,), 255, np.uint8)
        Image.fromarray(np.concatenate([np.round(flat * 0.45).astype(np.uint8), a], -1)).save(os.path.join(d, "dark.png"), optimize=True)
        Image.fromarray(np.concatenate([lit, a], -1)).save(os.path.join(d, "lit.png"), optimize=True)
    json.dump(report, open(os.path.join(HERE, "interiors", "cuts.json"), "w"), indent=1)


def check(name, plate, out, data, dbg, prev):
    """2x previews: lamps magenta, what the clean-up took (cyan), rim (yellow); and the lit composite"""
    os.makedirs(prev, exist_ok=True)
    v = plate[..., :3].copy()
    v[dbg["removed"]] = (0, 255, 255)
    v[dbg["lampmask"]] = (255, 0, 255)
    v[dbg["rim"] > 0.5] = (255, 255, 0)
    bg = np.zeros_like(v); bg[:] = (9, 12, 19)
    a = plate[..., 3:4] > 0
    v = np.where(a | dbg["removed"][..., None], v, bg)
    Image.fromarray(v).resize((v.shape[1] * 2, v.shape[0] * 2), Image.NEAREST).save(os.path.join(prev, name + "_select.png"))
    c = np.zeros_like(v, dtype=float); c[:] = (9, 12, 19)
    for key in ["solid"] + [l["file"][:-4] for l in data["layers"]] + ["lamps"]:
        L_ = out[key]; m = L_[..., 3] > 0
        c[m] = L_[m, :3]
    x0, y0, x1, y1 = BAYBOX
    m = out["bay_lit"][..., 3] > 0
    c[y0:y1, x0:x1][m] = out["bay_lit"][..., :3][m]
    Image.fromarray(c.astype(np.uint8)).resize((v.shape[1] * 2, v.shape[0] * 2), Image.NEAREST).save(os.path.join(prev, name + "_lit.png"))


def main():
    prev = sys.argv[sys.argv.index("--check") + 1] if "--check" in sys.argv else None
    for name, (kind, src, rule, keep) in SIDES.items():
        plate0 = np.asarray(Image.open(os.path.join(SRC, src)).convert("RGBA"))
        plate, cuts, pers, errs = mouth.taller(plate0)
        out, data, dbg = build(plate, kind, rule, keep, HULLS.get(name))
        data["mouth"] = dict(tall=mouth.TALL, cut_rows=[int(cuts.min()), int(cuts.max())],
                             periods=sorted(set(int(v) for v in pers)), worst=round(float(errs.max()), 2))
        d = os.path.join(HERE, name)
        os.makedirs(d, exist_ok=True)
        for k, v in out.items():
            Image.fromarray(v, "RGBA").save(os.path.join(d, k + ".png"), optimize=True)
        json.dump(data, open(os.path.join(d, "side.json"), "w"), indent=1)
        print("%-9s lamps %3d (%s)  layers %s  hull window x %d..%d (err %.1f)  clean-up took %d px" % (
            name, len(data["lamps"]), ",".join(sorted({l["kind"] for l in data["lamps"]})), [l["file"] for l in data["layers"]],
            data["hull"]["src"][0], data["hull"]["src"][0] + data["hull"]["src"][2], data["hull"]["err"], int(dbg["removed"].sum())))
        if prev:
            check(name, plate, out, data, dbg, prev)
    interiors()
    print("interiors", len(INTERIORS))


if __name__ == "__main__":
    main()
