"""Fit a generated hold frame round the three hold sizes.

    python tools/cage_fit.py <frame.png> <out stem> [--opening x0,y0,x1,y1]

THE HOLD IS A GRID WITH A FRAME ROUND IT. A hull's hold is 4x3, 5x4 or 6x5
cells of 40px, which in the 1x art the room doubles is 80x60, 100x80 or
120x100 pixels of opening. PixelLab draws a frame with an opening of its own
choosing, so this finds that opening and grows or shrinks the frame round it
until the opening is exactly the grid's, writing `<stem>_s.png`, `_m.png` and
`_l.png` (small, medium and heavy holds) and printing where each opening is.

WHOLE COLUMNS AND ROWS, AND THE QUIET ONES. A frame is resized the way the
level racks were seated (`furniture_seat.py`): by duplicating or dropping
entire columns of the top and bottom beams and entire rows of the posts,
never by scaling. Which ones is chosen by how little each differs from its
neighbour across the frame, so a plank's grain or a post's bolt is not cut
in half. Columns go in and out in mirror pairs about the opening's middle,
which keeps a plate on the top beam centred over the grid.

THE OPENING IS FOUND, AND CAN BE GIVEN. By default it is the dark region the
frame's middle is drawn as -- the largest connected run of dark pixels
through the centre -- which is what the grid will cover. A frame that draws
something across its middle can be measured by eye and passed with
`--opening`.
"""

import os
import sys

import numpy as np
from PIL import Image

SIZES = {"s": (80, 60), "m": (100, 80), "l": (120, 100)}


def opening_of(a):
    """The dark middle of a frame, as (x0, y0, x1, y1) inclusive."""
    h, w = a.shape[:2]
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    dark = (a[..., 3] > 40) & (lum < 60)
    cy, cx = h // 2, w // 2
    if not dark[cy, cx]:
        ys, xs = np.nonzero(dark)
        if not len(ys):
            raise SystemExit("cage_fit: no dark middle to fit a grid into")
        i = int(np.argmin((ys - cy) ** 2 + (xs - cx) ** 2))
        cy, cx = int(ys[i]), int(xs[i])
    seen = np.zeros_like(dark)
    stack, pts = [(cy, cx)], []
    seen[cy, cx] = True
    while stack:
        y, x = stack.pop()
        pts.append((y, x))
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and dark[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    ys = [p[0] for p in pts]
    xs = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def _cost_cols(a, x0, x1, y0, y1):
    """How visible a seam after each column would be, over the beams only."""
    rows = [y for y in range(a.shape[0]) if y < y0 or y > y1]
    band = a[rows].astype(np.int64)
    diff = np.abs(band[:, 1:] - band[:, :-1]).sum(axis=(0, 2))
    return diff  # diff[c] is between column c and c+1


def _cost_rows(a, x0, x1, y0, y1):
    cols = [x for x in range(a.shape[1]) if x < x0 or x > x1]
    band = a[:, cols].astype(np.int64)
    return np.abs(band[1:] - band[:-1]).sum(axis=(1, 2))


def _pick(cost, lo, hi, n, avoid=()):
    """`n` quiet positions in [lo, hi], two apart, none in `avoid`."""
    order = [i for i in np.argsort(cost, kind="stable") if lo <= i <= hi and i not in avoid]
    out = []
    for i in order:
        if all(abs(int(i) - j) >= 2 for j in out):
            out.append(int(i))
        if len(out) >= n:
            break
    return sorted(out)


def _resize_axis(a, axis, delta, positions):
    """Duplicate (delta > 0) or drop (delta < 0) the lines at `positions`,
    spreading the change across them as evenly as whole lines allow."""
    if delta == 0 or not positions:
        return a
    counts = [abs(delta) // len(positions)] * len(positions)
    for i in range(abs(delta) % len(positions)):
        counts[i] += 1
    lines = np.moveaxis(a, axis, 0)
    out, skip = [], {}
    for p, c in zip(positions, counts):
        skip[p] = c
    i = 0
    n = lines.shape[0]
    while i < n:
        c = skip.get(i, 0)
        if delta > 0:
            out.append(lines[i])
            for _ in range(c):
                out.append(lines[i])
            i += 1
        else:
            # drop c lines starting here
            if c:
                i += c
                continue
            out.append(lines[i])
            i += 1
    return np.moveaxis(np.stack(out), 0, axis)


def _period(profile):
    """The repeat of a striped post or beam, or None when it has none.

    The mean difference between the profile and itself shifted by p, for each
    p, against how much the profile varies at all: a hazard stripe comes back
    to itself every ten or so pixels and a plain post never needs this.
    """
    n = len(profile)
    spread = float(np.abs(profile - profile.mean()).mean())
    if n < 12 or spread < 6.0:
        return None
    best, best_d = None, 1e9
    for p in range(4, min(32, n // 2)):
        d = float(np.abs(profile[p:] - profile[:-p]).mean())
        if d < best_d:
            best, best_d = p, d
    return best if best_d < 0.35 * spread else None


def _insert_blocks(a, axis, at, p, count):
    """`count` copies of the `p` lines from `at`, placed right after them."""
    lines = np.moveaxis(a, axis, 0)
    block = lines[at:at + p]
    parts = [lines[:at + p]] + [block] * count + [lines[at + p:]]
    return np.moveaxis(np.concatenate(parts), 0, axis)


def _drop_blocks(a, axis, at, p, count):
    lines = np.moveaxis(a, axis, 0)
    return np.moveaxis(np.concatenate([lines[:at], lines[at + p * count:]]), 0, axis)


def fit(a, opening, size):
    """`a` with its opening grown or shrunk to `size`; returns (image, opening)."""
    x0, y0, x1, y1 = opening
    ow, oh = x1 - x0 + 1, y1 - y0 + 1
    tw, th = size
    # --- width: mirror pairs of quiet beam columns about the opening's middle.
    dw = tw - ow
    if dw:
        cost = _cost_cols(a, x0, x1, y0, y1)
        mid = (x0 + x1) / 2.0
        # clear of the posts and clear of a plate in the middle third
        lo, hi = x0 + 2, int(mid - ow / 6.0)
        pairs = max(1, min(6, abs(dw) // 2 or 1))
        left = _pick(cost, lo, hi, pairs)
        # the mirror of column c about the opening's middle; duplicating or
        # dropping it matches whatever happens to c
        right = [x0 + x1 - c for c in left]
        half = abs(dw) // 2
        a = _resize_axis(a, 1, (1 if dw > 0 else -1) * (abs(dw) - half), sorted(right))
        a = _resize_axis(a, 1, (1 if dw > 0 else -1) * half, left)
    # --- height: rows of the posts. A STRIPED POST GROWS BY WHOLE STRIPES:
    # copying one row of a diagonal hazard stripe six times drew a yellow
    # block down the post, so a post with a repeat takes whole repeats of it
    # and only what is left over goes in as single quiet rows.
    dh = th - oh
    if dh:
        x1n = x0 + tw - 1
        post = a[y0:y1 + 1, max(0, x0 - 6):x0].astype(np.float64)
        prof = (0.299 * post[..., 0] + 0.587 * post[..., 1] + 0.114 * post[..., 2]).mean(axis=1)
        p = _period(prof)
        if p and abs(dh) >= p:
            n = abs(dh) // p
            at = y0 + (oh - p) // 2
            if dh > 0:
                a = _insert_blocks(a, 0, at, p, n)
            else:
                a = _drop_blocks(a, 0, at, p, n)
            dh -= (n * p) if dh > 0 else -(n * p)
            y1 = y0 + oh - 1 + (n * p if th > oh else -n * p)
        if dh:
            cost = _cost_rows(a, x0, x1n, y0, y1)
            rows = _pick(cost, y0 + 2, y1 - 3, max(1, min(6, abs(dh))))
            a = _resize_axis(a, 0, dh, rows)
    return a, (x0, y0, x0 + tw - 1, y0 + th - 1)


def main(argv):
    src, stem = argv[0], argv[1]
    a = np.array(Image.open(src).convert("RGBA"))
    opening = None
    for arg in argv[2:]:
        if arg.startswith("--opening="):
            opening = tuple(int(v) for v in arg.split("=", 1)[1].split(","))
    if opening is None:
        opening = opening_of(a)
    print("%s: opening x %d..%d y %d..%d (%dx%d)" % (os.path.basename(src), opening[0], opening[2],
          opening[1], opening[3], opening[2] - opening[0] + 1, opening[3] - opening[1] + 1))
    for key, size in SIZES.items():
        out, op = fit(a.copy(), opening, size)
        path = "%s_%s.png" % (stem, key)
        Image.fromarray(out, "RGBA").save(path)
        print("  %s  %dx%d  opening at %d,%d  -> %s" % (key, out.shape[1], out.shape[0], op[0], op[1],
                                                       os.path.basename(path)))


if __name__ == "__main__":
    main(sys.argv[1:])
