"""The balls' nebula, borrowed from the discs (Jon, Nov 12: "can't they just have nebula in
them like the other galaxies have?"). An elliptical has almost no gas, so the chart draws
none in it, and forcing gas or young gas on gave only specks. So each ball strip takes the
gas of a disc strip (tier 4 for 7, 5 for 8, 6 for 9): every ball cell looks up the disc cell
at the same place on its own ellipse in the disc's first frame, and where the disc has gas
(bluer than red, off its core) the ball takes that colour by W. That one map then turns
rigidly with the ball, counter-clockwise, once a loop, so every patch stays put on the ball
(Jon: sampled frame by frame, "the nebula aren't persistent"). Whole cells, no blur.

usage: uv run --with pillow --with numpy python tools/dev/tier_ballneb.py RAMPED_DIR OUT_DIR W
  RAMPED_DIR: tier_ramp.py's finished strips (tiers 4 to 9). The gas goes on last, after the
  ramp's colour memory, which otherwise held the gas back in steps that read as turning the
  wrong way; OUT_DIR gets 7 to 9.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

DISC_OF = {7: 4, 8: 5, 9: 6}


def strip(path):
    s = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    h = s.shape[0]
    return [s[:, k * h:(k + 1) * h] for k in range(s.shape[1] // h)]


def shape(fr):
    """Middle and reach (95th percentile) of a picture's lit cells."""
    keep = fr[..., 3] > 0
    lum = fr[..., :3].max(-1)
    core = keep & (lum >= np.percentile(lum[keep], 97))
    ys, xs = np.nonzero(core)
    cy, cx = ys.mean(), xs.mean()
    ys, xs = np.nonzero(keep)
    rx = np.percentile(np.abs(xs - cx), 95)
    ry = np.percentile(np.abs(ys - cy), 95)
    return cx, cy, max(rx, 1.0), max(ry, 1.0)


def gas_map(ball0, disc0):
    """The ball's one gas map, built once from the disc's first frame: each ball cell's disc
    colour, and whether it is gas (bluer than red, off both cores)."""
    bcx, bcy, brx, bry = shape(ball0)
    dcx, dcy, drx, dry = shape(disc0)
    hh, ww = ball0.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    # the disc's gas lies round and below its core (its glow stands above it): the ball's upper
    # half samples the lower side turned half round (x and y both flipped)
    flip = np.where(yy < bcy, -1.0, 1.0)
    xd = np.clip(np.round(dcx + flip * (xx - bcx) / brx * drx).astype(int), 0, ww - 1)
    yd = np.clip(np.round(dcy + flip * (yy - bcy) / bry * dry).astype(int), 0, hh - 1)
    d = disc0[yd, xd]
    dcore = np.hypot(xd - dcx, (yd - dcy) * 2.0) <= 4.0
    gas = (d[..., 3] > 0) & (d[..., 2] > d[..., 0] + 8) & ~dcore
    return d[..., :3], gas, (bcx, bcy, brx, bry)


def turned(colour, gas, shp, ang):
    """The map turned by ang counter-clockwise on the ball's own ellipse, whole cells."""
    bcx, bcy, brx, bry = shp
    hh, ww = gas.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    ex, ey = (xx + 0.5 - bcx) / brx, -(yy + 0.5 - bcy) / bry      # y up
    c, s_ = math.cos(-ang), math.sin(-ang)
    sx = ex * c - ey * s_
    sy = ex * s_ + ey * c
    xi = np.round(bcx + sx * brx - 0.5).astype(int)
    yi = np.round(bcy - sy * bry - 0.5).astype(int)
    inside = (xi >= 0) & (xi < ww) & (yi >= 0) & (yi < hh)
    xi, yi = np.clip(xi, 0, ww - 1), np.clip(yi, 0, hh - 1)
    return colour[yi, xi], gas[yi, xi] & inside


def mix(ball, disc, w):
    """The one map, turned rigidly with the ball, once a loop: frame n would be frame 0."""
    colour, gas0, shp = gas_map(ball[0], disc[0])
    bcx, bcy = shp[0], shp[1]
    hh, ww = gas0.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    # the ball's own core is left alone, so it holds still
    bcore = np.hypot(xx - bcx, (yy - bcy) * 2.0) <= 4.0
    # the gas's own colour, set once against the ball's first frame, so a patch keeps its
    # colour as it goes round (mixed against each frame, the ball's churn showed through)
    lit = ball[0][..., :3] * (1 - w) + colour * w * 1.15
    if WARM:
        lit = warm(lit, ball[0], colour)
    out = []
    n = len(ball)
    for k, b in enumerate(ball):
        col, gas = turned(lit, gas0 & (ball[0][..., 3] > 0), shp, 2 * math.pi * k / n)
        gas = gas & (b[..., 3] > 0) & ~bcore
        f = b.copy()
        f[gas, :3] = col[gas]
        out.append(f)
    return out


WARM = os.environ.get("BALL_GAS_WARM") == "1"


def warm(lit, b0, gas_colour=None):
    """The gas in the ball's own warm palette: the borrowed gas's light and dark kept as warm
    patches (a deep red-brown where it is dim, a bright amber where it is bright) over the
    ball, so the nebula still reads without cooling it (a test; Jon likes the balls hot)."""
    src = lit if gas_colour is None else gas_colour
    g = src.max(-1)
    lo, hi = np.percentile(g, 10), np.percentile(g, 95)
    u = np.clip((g - lo) / max(hi - lo, 1.0), 0, 1)[..., None]
    dark = b0[..., :3] * np.array([0.62, 0.42, 0.30])
    bright = b0[..., :3] * np.array([1.45, 1.3, 1.05])
    return np.clip(dark + (bright - dark) * u, 0, 255)


def main():
    turn, out, w = sys.argv[1], sys.argv[2], float(sys.argv[3])
    os.makedirs(out, exist_ok=True)
    for t, dt in DISC_OF.items():
        frs = mix(strip(os.path.join(turn, "tier_%d.png" % t)), strip(os.path.join(turn, "tier_%d.png" % dt)), w)
        Image.fromarray(np.clip(np.concatenate(frs, axis=1), 0, 255).astype(np.uint8), "RGBA").save(
            os.path.join(out, "tier_%d.png" % t), optimize=True)
    print("balls with the discs' gas at %.2f: %s" % (w, out))


if __name__ == "__main__":
    main()
