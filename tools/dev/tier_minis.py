"""The tier pictures from the star chart's own galaxy: TierMiniBake's stills, pixelated.

Each tier's stills (one whole turn) are cropped round the galaxy, shrunk to 2x2-pixel cells
(the picture is 56 cells, drawn at 112 px), cut out of the chart's sky with hard edges (no
part-transparent cell), put on one palette per tier with no dither (so nothing crawls as it
turns), kept inside the lamp ring, and written as one strip of square frames:
tier_<n>.png, 56 px tall, frames side by side, played by TierGalaxy at its ART_FPS.

usage: uv run --with pillow --with numpy python tools/dev/tier_minis.py RAW_DIR OUT_DIR [tiers] [--fx K1|K2|K3]
  --fx: the tier's intensity drawn over the turn, rising 0 to 10 (Jon, Nov 11), in whole cells:
  K1 heat (warmer palette, a bigger brighter core, more sparks lit), K2 storm (the body boils
  in moving patches, its edge frays), K3 pressure (a pulsing halo round it, debris thrown off).
"""
import math
import os
import sys

import numpy as np
from PIL import Image

CELLS = 56          # the picture's cells across; drawn 2x into the 112 px galaxy
RING_R = 47.5       # the drawing's limit in screen px; the lamp ring is at 52
FILL = 50           # the galaxy's widest reach, dim edge and all, in cells (its drawn part is narrower)
COLOURS = 24        # the palette a tier gets
CUT = 22            # how far above the chart's sky a block must be to count as galaxy (summed rgb)
KEEP = 48           # how far above it a cell must be, once lifted, to be drawn


def frames_of(raw, t):
    out = []
    k = 0
    while os.path.exists(os.path.join(raw, "frame_%d_%d.png" % (t, k))):
        out.append(np.asarray(Image.open(os.path.join(raw, "frame_%d_%d.png" % (t, k))).convert("RGB")).astype(int))
        k += 1
    return out


def sky_of(fr):
    """The chart's empty sky colour: the median of the frame's border."""
    edge = np.concatenate([fr[0], fr[-1], fr[:, 0], fr[:, -1]])
    return np.median(edge, axis=0)


def inside_cells():
    yy, xx = np.mgrid[0:CELLS, 0:CELLS]
    cx = (xx + 0.5) * 2
    cy = (yy + 0.5) * 2
    return np.hypot(cx - 56, cy - 56) + 1.42 <= RING_R


def body(mask, bright):
    """Only the cells joined to the galaxy's bright parts: drops the chart's far galaxies,
    lone background stars and its corner labels."""
    return mask & flood(mask, gap=False, seeds=mask & bright)


def flood(mask, gap=True, seeds=None):
    """The part of a mask joined to its middle (a one-cell gap allowed with `gap`)."""
    hh, ww = mask.shape
    grown = mask.copy()
    if not gap:
        mask = np.zeros_like(mask)
    grown[1:, :] |= mask[:-1, :]
    grown[:-1, :] |= mask[1:, :]
    grown[:, 1:] |= mask[:, :-1]
    grown[:, :-1] |= mask[:, 1:]
    seen = np.zeros_like(mask)
    cy, cx = hh // 2, ww // 2
    if seeds is not None:
        stack = list(zip(*np.nonzero(seeds)))
    else:
        stack = [(y, x) for y in range(cy - 2, cy + 2) for x in range(cx - 2, cx + 2) if grown[y, x]]
    for p in stack:
        seen[p] = True
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (y + dy, x + dx)
            if 0 <= q[0] < hh and 0 <= q[1] < ww and grown[q] and not seen[q]:
                seen[q] = True
                stack.append(q)
    return seen


def bake(raw, out, t):
    frs = frames_of(raw, t)
    if not frs:
        return None
    sky = sky_of(frs[0])
    h, w = frs[0].shape[:2]
    # the galaxy's reach over the whole turn, from the chart's centre
    # in 6 px blocks, the lit blocks joined to the middle: the galaxy, not the sky round it
    B = 6
    hb, wb = h // B, w // B
    lit = np.zeros((hb, wb), bool)
    for fr in frs[:: max(1, len(frs) // 12)]:
        d = np.abs(fr[:hb * B, :wb * B] - sky).sum(-1).reshape(hb, B, wb, B).mean(axis=(1, 3))
        lit |= flood(d > CUT)
    ys, xs = np.nonzero(lit)
    # centred on the galaxy's own box (tier 10's giant sits off the dwarf's middle)
    cx = ((xs.min() + xs.max() + 1) / 2.0) * B
    cy = ((ys.min() + ys.max() + 1) / 2.0) * B
    reach = max(np.abs((xs + 0.5) * B - cx).max(), np.abs((ys + 0.5) * B - cy).max()) + B
    side = int(math.ceil(reach * 2 * CELLS / FILL))
    x0, y0 = int(round(cx - side / 2)), int(round(cy - side / 2))
    pad = np.zeros((side, side, 3), int) + sky.astype(int)
    sx0, sy0 = max(0, x0), max(0, y0)
    sx1, sy1 = min(w, x0 + side), min(h, y0 + side)
    small = []
    for fr in frs:
        sq = pad.copy()
        sq[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = fr[sy0:sy1, sx0:sx1]
        im = Image.fromarray(sq.astype(np.uint8), "RGB").resize((CELLS, CELLS), Image.BOX)
        small.append(np.asarray(im).astype(int))
    # lifted so its brightest cells reach near white: shrinking averages the chart's light down
    peak = np.percentile(np.concatenate([np.abs(s - sky).max(-1).ravel() for s in small[:: max(1, len(small) // 8)]]), 99.5)
    gain = min(2.2, 235.0 / max(peak, 1.0))
    small = [np.clip(sky + (s - sky) * gain, 0, 255) for s in small]
    # one palette for the whole turn, from every frame's kept cells
    keep_all = []
    for s_ in small:
        d = np.abs(s_ - sky).sum(-1)
        keep_all.append(body((d > KEEP) & inside_cells(), d > np.percentile(d, 97)))
    pool = np.concatenate([s[k] for s, k in zip(small, keep_all)])
    pal_im = Image.fromarray(pool.reshape(1, -1, 3).astype(np.uint8), "RGB").quantize(COLOURS, method=Image.Quantize.FASTOCTREE)
    cells = [np.asarray(Image.fromarray(s.astype(np.uint8), "RGB").quantize(palette=pal_im, dither=Image.Dither.NONE)
                        .convert("RGB")).astype(int) for s in small]
    if FX:
        cells, keep_all = FX(cells, keep_all, t)
    strip = Image.new("RGBA", (CELLS * len(small), CELLS), (0, 0, 0, 0))
    for i, (a, keep) in enumerate(zip(cells, keep_all)):
        rgba = np.zeros((CELLS, CELLS, 4), np.uint8)
        rgba[..., :3] = np.clip(a, 0, 255)
        rgba[..., 3] = np.where(keep & inside_cells(), 255, 0)
        strip.paste(Image.fromarray(rgba, "RGBA"), (i * CELLS, 0))
    os.makedirs(out, exist_ok=True)
    strip.save(os.path.join(out, "tier_%d.png" % t), optimize=True)
    return len(small)


# ---------------------------------------------------------------- the intensity, over the turn

TIER_COL = [None, (150, 215, 205), (150, 215, 205), (150, 215, 205), (240, 160, 67), (240, 160, 67),
            (240, 160, 67), (238, 96, 58), (238, 96, 58), (238, 96, 58), (255, 70, 90)]
WHITE = np.array([255, 250, 240])
PANEL_C = np.array([17, 24, 35])
FX = None


def grow(m, r):
    """A mask grown by r cells (4-neighbour steps)."""
    for _ in range(r):
        g = m.copy()
        g[1:, :] |= m[:-1, :]
        g[:-1, :] |= m[1:, :]
        g[:, 1:] |= m[:, :-1]
        g[:, :-1] |= m[:, 1:]
        m = g
    return m


def lum(a):
    return a.max(-1)


def middle(keep, a):
    """The galaxy's middle in cells: its brightest cells' centre."""
    if not keep.any():
        return CELLS / 2.0, CELLS / 2.0
    b = np.where(keep, lum(a), 0)
    ys, xs = np.nonzero(b >= np.percentile(b[keep], 98))
    return xs.mean(), ys.mean()


def k1(cells, keeps, t):
    """HEAT: the palette warms, the core grows and brightens, and more sparks light, each on
    for a fifth of its own slow cycle."""
    h = t / 10.0
    n = len(cells)
    rnd = np.random.RandomState(100 + t)
    sparks = [(rnd.rand(), rnd.randint(1, 3), rnd.rand()) for _ in range(int(round(40 * h)))]
    out = []
    for k, (a, keep) in enumerate(zip(cells, keeps)):
        u = k / n
        a = a.astype(float)
        warm = np.stack([a[..., 0] * 1.18 + 18, a[..., 1] * 1.0 + 4, a[..., 2] * 0.72], -1)
        a = a + (warm - a) * (0.55 * h)
        if keep.any():
            # the core: a disc of cells round the middle, wider and whiter up the tiers, swelling slowly
            cx, cy = middle(keep, cells[k])
            yy, xx = np.mgrid[0:CELLS, 0:CELLS]
            sw = 0.5 + 0.5 * math.sin(2 * math.pi * u * (1 + round(2 * h)))
            rad = 1.2 + 2.6 * h + 0.8 * h * sw
            core = keep & (np.hypot(xx - cx, (yy - cy) * 1.8) <= rad)
            a[core] = a[core] + (WHITE - a[core]) * (0.25 + 0.45 * h)
        ys, xs = np.nonzero(keep)
        for (p, cyc, sel) in sparks:
            if len(ys) and ((u * cyc + p) % 1.0) < 0.2:
                i = int(sel * len(ys)) % len(ys)
                a[ys[i], xs[i]] = WHITE
        out.append(a)
    return out, keeps


def k2(cells, keeps, t):
    """STORM: the body boils in moving patches (a step brighter or darker where a slow wave
    field crosses it), faster and wider up the tiers, and its edge frays."""
    h = t / 10.0
    n = len(cells)
    yy, xx = np.mgrid[0:CELLS, 0:CELLS]
    m = 1 + int(round(3 * h))
    out, kout = [], []
    for k, (a, keep) in enumerate(zip(cells, keeps)):
        u = k / n
        f = (np.sin(xx * 0.55 + yy * 0.9 - 2 * math.pi * m * u) * np.sin(xx * 0.31 - yy * 0.47 + 2 * math.pi * (m + 1) * u + 1.3)
             + 0.6 * np.sin(xx * 1.3 - 2 * math.pi * 2 * m * u + yy * 0.2))
        a = a.astype(float)
        share = 0.04 + 0.5 * h
        up = keep & (f > 1.2 - 1.3 * share)
        down = keep & (f < -1.2 + 1.3 * share)
        a[up] = a[up] * 1.35 + 14
        a[down] = a[down] * 0.68
        fray = np.zeros_like(keep)
        if h > 0:
            fray = grow(keep, 1) & ~keep & (f > 1.4 - 1.2 * h)
            a[fray] = np.array(TIER_COL[t]) * 0.55
        out.append(a)
        kout.append(keep | fray)
    return out, kout


def k3(cells, keeps, t):
    """PRESSURE: a halo round the galaxy that swells and settles slowly, and debris thrown off
    its edge, more of it and faster up the tiers."""
    h = t / 10.0
    n = len(cells)
    col = np.array(TIER_COL[t] if t > 0 else (120, 150, 200))
    rnd = np.random.RandomState(300 + t)
    debris = [(rnd.rand() * 2 * math.pi, rnd.rand(), 1 + rnd.randint(0, 1 + int(2 * h))) for _ in range(int(round(36 * h)))]
    ins = inside_cells()
    out, kout = [], []
    for k, (a, keep0) in enumerate(zip(cells, keeps)):
        u = k / n
        a = a.astype(float)
        keep = keep0.copy()
        pulse = 0.5 - 0.5 * math.cos(2 * math.pi * u * (1 + int(round(2 * h))))
        w = int(round(1.8 * h * pulse))
        halo = grow(keep0, w) & ~keep0 & ins
        a[halo] = PANEL_C + (col - PANEL_C) * (0.16 + 0.14 * h)
        keep |= halo
        cx, cy = middle(keep0, cells[k])
        for (ang, p, cyc) in debris:
            age = (u * cyc + p) % 1.0
            dx, dy = math.cos(ang), math.sin(ang) * 0.45
            r = 2.0
            while r < 40:
                yi, xi = int(cy + dy * r), int(cx + dx * r)
                if not (0 <= yi < CELLS and 0 <= xi < CELLS and keep0[yi, xi]):
                    break
                r += 1.0
            r += 1 + age * (6 + 14 * h)
            x, y = int(cx + dx * r), int(cy + dy * r)
            if 0 <= x < CELLS and 0 <= y < CELLS and ins[y, x]:
                a[y, x] = col + (WHITE - col) * (0.5 * (1 - age))
                keep[y, x] = True
        out.append(a)
        kout.append(keep)
    return out, kout


def main():
    global FX
    args = sys.argv[1:]
    if "--fx" in args:
        i = args.index("--fx")
        FX = {"K1": k1, "K2": k2, "K3": k3}[args[i + 1]]
        args = args[:i] + args[i + 2:]
    raw, out = args[0], args[1]
    tiers = [int(a) for a in args[2:]] or list(range(11))
    for t in tiers:
        n = bake(raw, out, t)
        print("tier %d: %s" % (t, "%d frames" % n if n else "no stills"))


if __name__ == "__main__":
    main()
