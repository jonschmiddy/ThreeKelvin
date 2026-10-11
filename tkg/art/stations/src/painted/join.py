"""join.py <plate name> <take tag> [--out <png>]: the plate made whole to x 629 -- its own pixels to the seam,
the take past it. The seam is a path down the band x 380..418, one column per row, moving at most a pixel a row,
cut where the take and the plate agree (dynamic programming on the colour difference). Writes the joined plate
(630 wide, 530 tall: rows outside the take's 50..449 carry on from the old grown plate) and a check sheet."""
import os, sys, json
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "C:/Users/Jon/Documents/GitHub/tk-wt/stations/tkg/art/stations/src"
sys.path.insert(0, os.path.dirname(SRC))
import sides  # noqa: E402

CX, CY, CW, CH = 230, 50, 400, 400
SEEN = 399
# (the seam is the cut itself: the plate's own seen pixels, x 0..398, are never replaced)
BAND = (399, 400)
W = CX + CW


def lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def join(name, tag, srcname=None):
    p = np.asarray(Image.open(os.path.join(SRC, (srcname or name) + ".png")).convert("RGBA")).copy()
    kind, _, rule, keep = sides.SIDES[name]
    al, _ = sides.clean_mask(p[..., 3] > 0, p[..., :3].astype(float), rule, keep)
    H = p.shape[0]
    t = np.asarray(Image.open(os.path.join(HERE, "raw", tag + ".png")).convert("RGBA")).astype(int)
    full = np.zeros((H, W, 4), np.uint8)
    full[:, :p.shape[1]] = p
    # rows outside the take: the old grown columns, then their last column on (never seen at the dock's end)
    for x in range(p.shape[1], W):
        full[:, x] = full[:, p.shape[1] - 48 + (x - p.shape[1]) % 48]
    # the take's sky: what pixflux paints space with is given back as transparent, or as its flat sky colour
    # (the silhouette is the init's: pixflux given an init paints space as a speckled pale sky)
    init = np.asarray(Image.open(os.path.join(HERE, "inits", name + ".png")).convert("RGBA"))
    ta = (t[..., 3] > 0) & (init[..., 3] > 0)
    # the seam, per row of the take
    x0, x1 = BAND
    real = p[CY:CY + CH, x0:x1, :3].astype(float)
    tk = t[:, x0 - CX:x1 - CX, :3].astype(float)
    cost = np.abs(lum(real) - lum(tk)) + 0.3 * np.abs(real - tk).sum(-1)
    # (both must be hull or both space for a cut to be free)
    ra = al[CY:CY + CH, x0:x1]
    cost += 400.0 * (ra != ta[:, x0 - CX:x1 - CX])
    # vertical: cumulative, moving at most one column a row
    n = x1 - x0
    acc = cost.copy()
    back = np.zeros_like(cost, int)
    for y in range(1, CH):
        prev = acc[y - 1]
        cand = np.stack([np.roll(prev, 1), prev, np.roll(prev, -1)])
        cand[0, 0] = np.inf
        cand[2, -1] = np.inf
        k = cand.argmin(0)
        acc[y] += cand[k, np.arange(n)]
        back[y] = np.arange(n) + (k - 1)
    seam = np.zeros(CH, int)
    seam[-1] = int(acc[-1].argmin())
    for y in range(CH - 1, 0, -1):
        seam[y - 1] = back[y, seam[y]]
    seam = np.minimum(seam + x0, SEEN)          # never past the seen pixels' end
    for y in range(CH):
        sx = seam[y]
        row = t[y, sx - CX:]
        full[CY + y, sx:] = np.clip(row, 0, 255).astype(np.uint8)
        full[CY + y, sx:, 3] = np.where(ta[y, sx - CX:], 255, 0)
    # THE JOIN IN THE ART'S OWN HAND (the piles): where a box of the plate is cut by the seam, its end is drawn
    # in the first painted column, in that box's own darkest tone along the row, so it reads as a box ending
    # against the next one (the plate's own pixels are never touched)
    if name.startswith("pile"):
        L = lum(p[..., :3].astype(float))
        for y in range(CY, CY + CH):
            if not al[y, SEEN - 1] or L[y, SEEN - 1] < 45:
                continue
            row = p[y, SEEN - 20:SEEN, :3].astype(int)
            k = int(np.argmin(lum(row.astype(float))))
            dark = row[k]
            if lum(dark[None].astype(float))[0] < 45:
                full[y, SEEN, :3] = dark
                full[y, SEEN, 3] = 255
    err = float(np.mean([cost[y, seam[y] - x0] for y in range(CH)]))
    return full, seam, err


def sheet(name, full, seam, out):
    bg = np.zeros(full.shape[:3][:2] + (3,), np.uint8); bg[:] = (9, 12, 19)
    a = full[..., 3:4] / 255.0
    rgb = (full[..., :3] * a + bg * (1 - a)).astype(np.uint8)
    crop = rgb[100:420, 250:630]
    mark = crop.copy()
    for y in range(CH):
        yy = CY + y - 100
        if 0 <= yy < mark.shape[0]:
            mark[yy, seam[y] - 250] = (255, 0, 255)
    s = np.concatenate([crop, np.full((crop.shape[0], 6, 3), 0, np.uint8), mark], 1)
    Image.fromarray(s.repeat(2, 0).repeat(2, 1)).save(out)


if __name__ == "__main__":
    name, tag = sys.argv[1:3]
    full, seam, err = join(name, tag)
    os.makedirs(os.path.join(HERE, "joined"), exist_ok=True)
    Image.fromarray(full).save(os.path.join(HERE, "joined", name + ".png"))
    sheet(name, full, seam, os.path.join(HERE, "joined", name + "_check.png"))
    print(name, tag, "seam x %d..%d, mean cost %.1f" % (seam.min(), seam.max(), err))
