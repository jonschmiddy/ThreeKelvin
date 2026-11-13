"""The tier pictures' ramp, laid on R2's own pixels (Jon, Nov 12: "the lower tiers dimmer and
calmer, the higher tiers more bright and energetic, without it being too chaotic and messy").

Nothing is drawn again or blurred: each tier takes one still of R2's art (tier 1's spiral for
every spiral tier, tier 4's disc for every disc tier, each ball its own, 7 and 8 swapped) and
changes only colours, cell by cell:
  - a tone curve by the tier's place in its form (ACT): dim and cool at a form's first tier,
    brighter with a hotter core at its last; a ring of cells one step brighter round the core
    on the top tiers (medium and strong)
  - the core and the brightest band breathing in whole steps, deeper and quicker up the form
  - a few stars at the edge lit for half a second at a time, more up the form
A form's first tier is still. Tier 10 is R2's strip as it is. One loop is LOOP_S seconds.

usage: uv run --with pillow --with numpy python tools/dev/tier_ramp.py R2_DIR TIER10_STRIP OUT_DIR G|M|S [TURN_DIR]
  TURN_DIR: turning strips (TierMiniBake freeze=1 typeramp=1, cut by tier_minis.py) to lay the
  ramp on frame by frame instead of one still; the core's cells are held to their median over
  the turn and a cell keeps its colour until it changes by more than HOLD.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

FPS = 12
LOOP_S = 6.0
N = int(FPS * LOOP_S)
FORM = [0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3]
ACT = [0.0, 1 / 3, 2 / 3, 1.0, 0.0, 0.5, 1.0, 0.0, 0.5, 1.0, 1.0]
## Which R2 still each tier is built on: Jon's two references and the balls' own (7 and 8 swapped).
BASE = [1, 1, 1, 1, 4, 4, 4, 8, 7, 9, 10]
BASE_FRAME = 0
PANEL = np.array([17.0, 24.0, 35.0])
WHITE = np.array([255.0, 250.0, 240.0])
HOT = np.array([255.0, 228.0, 180.0])

## gentle, medium, strong: (light at a form's first tier, at its last, cool at the first,
## core heat at the last, core rings at the last, breath steps at the last, breaths a loop at
## the last, stars at the last)
RAMPS = {
    "G": (0.82, 1.10, 0.08, 0.25, 0, 1, 2, 3),
    "M": (0.68, 1.22, 0.14, 0.40, 1, 2, 2, 6),
    "S": (0.55, 1.35, 0.20, 0.55, 2, 2, 3, 10),
    # Jon on M + turn (Nov 12): "ramp up the intensity scale a bit more": two steps past M
    "P": (0.62, 1.28, 0.17, 0.48, 1, 2, 3, 8),
    "Q": (0.56, 1.34, 0.20, 0.55, 2, 3, 4, 10),
}
## Clumps of brighter stars riding a ball's turn, so it reads as turning (Jon: "the ball
## galaxies don't turn much at all"): how many, how far out (of the ball's reach), how bright.
CLUMPS = 5
CLUMP_R = (0.42, 0.78)
CLUMP_STEP = 4
STEP = 0.13          # one breath or glow step: this share of the way to white


def frame(path, k):
    s = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    h = s.shape[0]
    return s[:, k * h:(k + 1) * h]


def grow(m, r):
    for _ in range(r):
        g = m.copy()
        g[1:, :] |= m[:-1, :]
        g[:-1, :] |= m[1:, :]
        g[:, 1:] |= m[:, :-1]
        g[:, :-1] |= m[:, 1:]
        m = g
    return m


HOLD = 80


def turning(frames):
    """A turning strip made calm: the core held to its median, colours with a memory."""
    base = frames[0]
    keep = base[..., 3] > 0
    lum = base[..., :3].max(-1)
    core = keep & (lum >= np.percentile(lum[keep], 97))
    ys, xs = np.nonzero(core)
    yy, xx = np.mgrid[0:base.shape[0], 0:base.shape[1]]
    held = np.hypot(xx - xs.mean(), (yy - ys.mean()) * 2.0) <= 3.0
    med = np.median(np.stack(frames), axis=0)
    out = []
    cur = None
    for lap in (0, 1):
        for i, f in enumerate(frames):
            f = f.copy()
            f[held] = med[held]
            if cur is not None:
                both = (f[..., 3] > 0) & (cur[..., 3] > 0)
                hold = both & (np.abs(f[..., :3] - cur[..., :3]).sum(-1) <= HOLD)
                f = np.where(hold[..., None], cur, f)
            cur = f
            if lap:
                out.append(f)
    return out


def tier(base, t, ramp, frames=None):
    """`frames`: a turning strip, the ramp laid on each; else `base`, one still."""
    lo, hi, cool, heat, rings, depth, breaths, stars = RAMPS[ramp]
    act = ACT[t]
    n_out = len(frames) if frames else N
    rgb, keep = base[..., :3].copy(), base[..., 3] > 0
    lum = rgb.max(-1)
    lit = lum[keep]
    core = keep & (lum >= np.percentile(lit, 97))
    band = keep & (lum >= np.percentile(lit, 85))
    ring = grow(core, rings) & ~core & keep if (act >= 0.99 and rings) else np.zeros_like(keep)

    def tone(px):
        # the tone curve: dim and cool low, bright and hot high
        px = PANEL + (px - PANEL) * (lo + (hi - lo) * act)
        c = (1 - act) * cool
        px = px * (1 - c) + px * np.array([0.82, 0.95, 1.18]) * c
        px[core] = px[core] + (HOT - px[core]) * (heat * act)
        px[ring] = px[ring] + (WHITE - px[ring]) * STEP
        return np.clip(px, 0, 255)
    rgb = tone(rgb)
    # the breath and the stars
    d = int(round(depth * act))
    m = max(1, int(round(1 + (breaths - 1) * act)))
    ys, xs = np.nonzero(keep)
    cy, cx = np.nonzero(core)[0].mean(), np.nonzero(core)[1].mean()
    far = np.hypot(xs - cx, (ys - cy) * 2.0)
    edge = far >= np.percentile(far, 60)
    rnd = np.random.RandomState(40 + t)
    pick = rnd.choice(np.nonzero(edge)[0], size=min(int(round(stars * act)), int(edge.sum())), replace=False)
    twinkles = [(ys[i], xs[i], rnd.randint(0, n_out), rnd.randint(1, 3)) for i in pick]
    clumps = []
    if frames and FORM[t] == 2:
        # the ball's reach and flattening on the screen, from its lit cells
        rx = np.percentile(np.abs(xs - cx), 95)
        ry = np.percentile(np.abs(ys - cy), 95)
        crnd = np.random.RandomState(90 + t)
        for j in range(CLUMPS):
            clumps.append((crnd.uniform(*CLUMP_R), 2 * math.pi * j / CLUMPS + crnd.uniform(-0.4, 0.4), crnd.randint(3, 6)))
    out = []
    for k in range(n_out):
        u = k / n_out
        if frames:
            a = tone(frames[k][..., :3].copy())
            keep = frames[k][..., 3] > 0
        else:
            a = rgb.copy()
        for (r, a0, size) in clumps:
            # whole cells on the ball's own ellipse, one turn a loop, the way the bake turns
            ang = a0 - 2 * math.pi * u
            x = int(round(cx + r * rx * math.cos(ang)))
            y = int(round(cy + r * ry * math.sin(ang)))
            for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (-1, 1)][:size]:
                if 0 <= y + dy < keep.shape[0] and 0 <= x + dx < keep.shape[1] and keep[y + dy, x + dx]:
                    a[y + dy, x + dx] = a[y + dy, x + dx] + (HOT - a[y + dy, x + dx]) * (STEP * CLUMP_STEP)
        lv = int(round(d * (0.5 - 0.5 * math.cos(2 * math.pi * m * u))))
        if lv:
            a[band] = a[band] + (WHITE - a[band]) * (STEP * lv)
        for (y, x, st, cyc) in twinkles:
            # lit for half a second, with a half step either side, cyc times a loop
            age = (k * cyc - st) % n_out
            if age < 8:
                w = 0.5 if age in (0, 7) else 1.0
                a[y, x] = a[y, x] + (WHITE - a[y, x]) * w
        img = np.zeros(base.shape, np.uint8)
        img[..., :3] = np.clip(np.round(a), 0, 255)
        img[..., 3] = np.where(keep, 255, 0)
        out.append(img)
    return out


def main():
    r2, t10, out, ramp = sys.argv[1:5]
    turn = sys.argv[5] if len(sys.argv) > 5 else None
    os.makedirs(out, exist_ok=True)
    for t in range(10):
        if turn:
            path = os.path.join(turn, "tier_%d.png" % t)
            w = Image.open(path).width // Image.open(path).height
            frames = turning([frame(path, k) for k in range(w)])
            frs = tier(frames[0], t, ramp, frames)
        else:
            base = frame(os.path.join(r2, "tier_%d.png" % BASE[t]), BASE_FRAME)
            frs = tier(base, t, ramp)
        Image.fromarray(np.concatenate(frs, axis=1), "RGBA").save(os.path.join(out, "tier_%d.png" % t), optimize=True)
    Image.open(t10).save(os.path.join(out, "tier_10.png"))
    print("ramp %s: %s" % (ramp, out))


if __name__ == "__main__":
    main()
