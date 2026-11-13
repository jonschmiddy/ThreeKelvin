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

usage: uv run --with pillow --with numpy python tools/dev/tier_ramp.py R2_DIR TIER10_STRIP OUT_DIR G|M|S
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
}
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


def tier(base, t, ramp):
    lo, hi, cool, heat, rings, depth, breaths, stars = RAMPS[ramp]
    act = ACT[t]
    rgb, keep = base[..., :3].copy(), base[..., 3] > 0
    lum = rgb.max(-1)
    lit = lum[keep]
    core = keep & (lum >= np.percentile(lit, 97))
    band = keep & (lum >= np.percentile(lit, 85))
    # the tone curve: dim and cool low, bright and hot high
    f = lo + (hi - lo) * act
    rgb = PANEL + (rgb - PANEL) * f
    c = (1 - act) * cool
    rgb = rgb * (1 - c) + rgb * np.array([0.82, 0.95, 1.18]) * c
    rgb[core] = rgb[core] + (HOT - rgb[core]) * (heat * act)
    if act >= 0.99 and rings:
        ring = grow(core, rings) & ~core & keep
        rgb[ring] = rgb[ring] + (WHITE - rgb[ring]) * STEP
    rgb = np.clip(rgb, 0, 255)
    # the breath and the stars
    d = int(round(depth * act))
    m = max(1, int(round(1 + (breaths - 1) * act)))
    ys, xs = np.nonzero(keep)
    cy, cx = np.nonzero(core)[0].mean(), np.nonzero(core)[1].mean()
    far = np.hypot(xs - cx, (ys - cy) * 2.0)
    edge = far >= np.percentile(far, 60)
    rnd = np.random.RandomState(40 + t)
    pick = rnd.choice(np.nonzero(edge)[0], size=min(int(round(stars * act)), int(edge.sum())), replace=False)
    twinkles = [(ys[i], xs[i], rnd.randint(0, N), rnd.randint(1, 3)) for i in pick]
    out = []
    for k in range(N):
        u = k / N
        a = rgb.copy()
        lv = int(round(d * (0.5 - 0.5 * math.cos(2 * math.pi * m * u))))
        if lv:
            a[band] = a[band] + (WHITE - a[band]) * (STEP * lv)
        for (y, x, st, cyc) in twinkles:
            # lit for half a second, with a half step either side, cyc times a loop
            age = (k * cyc - st) % N
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
    os.makedirs(out, exist_ok=True)
    for t in range(10):
        base = frame(os.path.join(r2, "tier_%d.png" % BASE[t]), BASE_FRAME)
        frs = tier(base, t, ramp)
        Image.fromarray(np.concatenate(frs, axis=1), "RGBA").save(os.path.join(out, "tier_%d.png" % t), optimize=True)
    Image.open(t10).save(os.path.join(out, "tier_10.png"))
    print("ramp %s: %s" % (ramp, out))


if __name__ == "__main__":
    main()
