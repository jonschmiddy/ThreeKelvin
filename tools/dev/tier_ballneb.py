"""The balls' nebula, borrowed from the discs (Jon, Nov 12: "can't they just have nebula in
them like the other galaxies have?"). An elliptical has almost no gas, so the chart draws
none in it, and forcing gas or young gas on gave only specks. So each ball strip takes the
gas of a disc strip (tier 4 for 7, 5 for 8, 6 for 9): every ball cell looks up the disc cell
at the same place on its own ellipse, in the frame at the same point of the turn, and where
the disc has gas (bluer than red, off its core) the ball takes that colour by W. The disc's
gas turns once a loop, as the ball does, so it turns with it. Pixel for pixel, no blur.

usage: uv run --with pillow --with numpy python tools/dev/tier_ballneb.py TURN_DIR OUT_DIR W
  TURN_DIR: the turning strips (tiers 4 to 9, cut by tier_minis.py); OUT_DIR gets 7 to 9.
"""
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


def mix(ball, disc, w):
    bcx, bcy, brx, bry = shape(ball[0])
    dcx, dcy, drx, dry = shape(disc[0])
    hh, ww = ball[0].shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    xd = np.clip(np.round(dcx + (xx - bcx) / brx * drx).astype(int), 0, ww - 1)
    # the disc's gas lies round and below its core (its glow stands above it): sample the lower side
    yd = np.clip(np.round(dcy + np.abs(yy - bcy) / bry * dry).astype(int), 0, hh - 1)
    out = []
    nb, nd = len(ball), len(disc)
    for k, b in enumerate(ball):
        d = disc[int(round(k / nb * nd)) % nd][yd, xd]
        dcore = np.hypot(xd - dcx, (yd - dcy) * 2.0) <= 4.0
        gas = (b[..., 3] > 0) & (d[..., 3] > 0) & (d[..., 2] > d[..., 0] + 8) & ~dcore
        f = b.copy()
        # the gas keeps the ball's light: its colour, at least as bright as the ball's dimmest
        f[gas, :3] = b[gas, :3] * (1 - w) + d[gas, :3] * w * 1.15
        out.append(f)
    return out


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
