"""The tier pictures from the star chart's own galaxy: TierMiniBake's stills, pixelated.

Each tier's stills (one whole turn) are cropped round the galaxy, shrunk to 2x2-pixel cells
(the picture is 56 cells, drawn at 112 px), cut out of the chart's sky with hard edges (no
part-transparent cell), put on one palette per tier with no dither (so nothing crawls as it
turns), kept inside the lamp ring, and written as one strip of square frames:
tier_<n>.png, 56 px tall, frames side by side, played by TierGalaxy at its ART_FPS.

usage: uv run --with pillow --with numpy python tools/dev/tier_minis.py RAW_DIR OUT_DIR [tiers]
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
    strip = Image.new("RGBA", (CELLS * len(small), CELLS), (0, 0, 0, 0))
    for i, (s, keep) in enumerate(zip(small, keep_all)):
        q = Image.fromarray(s.astype(np.uint8), "RGB").quantize(palette=pal_im, dither=Image.Dither.NONE).convert("RGB")
        a = np.asarray(q).copy()
        rgba = np.zeros((CELLS, CELLS, 4), np.uint8)
        rgba[..., :3] = a
        rgba[..., 3] = np.where(keep, 255, 0)
        strip.paste(Image.fromarray(rgba, "RGBA"), (i * CELLS, 0))
    os.makedirs(out, exist_ok=True)
    strip.save(os.path.join(out, "tier_%d.png" % t), optimize=True)
    return len(small)


def main():
    raw, out = sys.argv[1], sys.argv[2]
    tiers = [int(a) for a in sys.argv[3:]] or list(range(11))
    for t in tiers:
        n = bake(raw, out, t)
        print("tier %d: %s" % (t, "%d frames" % n if n else "no stills"))


if __name__ == "__main__":
    main()
