# -*- coding: utf-8 -*-
"""Make a sprite span its box by INSERTING WHOLE PERIODS, never by resampling.

    python tools/expand_box.py <sprite.png> <box_w> <box_h> [out.png]

WHY THIS EXISTS. `scale_to_box.py` resamples, and resampling at a rational factor
duplicates or drops a scattered handful of rows and columns. On an irregular mass
that is invisible; on a part whose IDENTITY is a regularity it is ruinous. Seven
modules were rejected on sight for exactly that: a gun barrel gained a notch, a
valve ring went lopsided, a comb of fins lost its spacing. The factor was never
the thing -- gantry survived x1.14 and coolant did not survive x1.11.

So this does the opposite. It never invents a sample. It only ever COPIES whole
columns and rows that already exist, and it chooses WHERE by asking what the
sprite is made of:

  A PERIODIC PART GROWS BY A WHOLE PERIOD. If the columns repeat with period p --
  a comb of fins, a rivet run, a bank of dials -- then inserting exactly p columns
  copied from one clean period leaves every remaining feature on its original
  spacing. The comb gets one more fin. It does not get a wider gap.

  A PART WITH A FLAT RUN GROWS THERE. A gun is a breech, a body and a barrel, and
  the barrel is a long run of near-identical columns. Copying inside that run
  lengthens the barrel and is invisible, which is the one place a gun can grow.

  A PART WITH NEITHER DOES NOT GROW. That is a result, not a failure. Under-filling
  is not a defect -- two sprites were called failures for underfilling and the art
  director kept both -- and a part that cannot grow cleanly is better left alone
  than broken to fill a cell.

IT IS ALLOWED TO UNDERSHOOT. If the box wants seven more columns and the period is
four, it adds four and stops. Six of seven cleanly beats seven with the pattern
broken, and the leftover is transparent margin that costs nothing.

IT WORKS ON THE SHIPPED SPRITE, not on a raw generation. Nothing here needs the
generator's output, so nothing here can pick the wrong take -- the failure that
turned `organ` gold. Every colour in the output was in the input by construction,
so there is no snap and the palette cannot drift.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt  # noqa: E402


def _col(rows, h, x):
    return [rows[y][x * 4:x * 4 + 4] for y in range(h)]


def _diff(a, b):
    """Distance between two columns (or rows) of RGBA. Transparent-vs-opaque is
    expensive, so a silhouette edge never reads as a place to repeat."""
    n = 0
    for pa, pb in zip(a, b):
        oa, ob = pa[3] > 8, pb[3] > 8
        if oa != ob:
            n += 400
        elif oa:
            n += abs(pa[0] - pb[0]) + abs(pa[1] - pb[1]) + abs(pa[2] - pb[2])
    return n


def _period(cols, lo=2):
    """The smallest p whose self-similarity is far better than chance.

    Scored as mean distance between column x and column x+p over the overlap,
    against the mean distance between neighbours. A comb of fins scores near
    zero at its own period and high everywhere else; a smooth body scores flat,
    and flat means NOT PERIODIC -- which is the answer that stops this from
    inventing a period in a part that has none.
    """
    n = len(cols)
    if n < lo * 3:
        return None
    base = sum(_diff(cols[i], cols[i + 1]) for i in range(n - 1)) / float(n - 1)
    if base <= 0:
        return None
    best = None
    for p in range(lo, n // 3 + 1):
        s = sum(_diff(cols[i], cols[i + p]) for i in range(n - p)) / float(n - p)
        if best is None or s < best[1]:
            best = (p, s)
    if best is None:
        return None
    p, s = best
    # Repeating at p must be at least four times more similar than a neighbour
    # step. Below that the "period" is just a smooth gradient.
    return p if s * 4 < base else None


def _extent(c):
    """First and last opaque index in a column. The column's FOOTPRINT."""
    on = [i for i, p in enumerate(c) if p[3] > 8]
    return (on[0], on[-1]) if on else None


def _runs(cols, tol):
    """Maximal runs of near-identical neighbours THAT KEEP THE SAME FOOTPRINT.

    The colour test alone is not enough, and `bracing` is why. It is an X, and
    where its two struts cross they both momentarily run near-horizontal: four
    columns whose colours barely differ, which read as a flat run and are nothing
    of the kind. Copying one turned a constant slope into a plateau, and a
    constant slope is the entire subject.

    What separates that from a gun barrel is not how long the run is -- the first
    attempt at this used a length threshold and it deleted the barrel too. It is
    that a DIAGONAL MOVES. Across a barrel the column's first and last opaque row
    do not change; across a strut they climb a row at a time. So a run is only
    growable while the footprint holds still, which lets a barrel, a pipe and a
    box wall grow, and refuses every diagonal in the set.
    """
    out, i, n = [], 0, len(cols)
    while i < n - 1:
        j, e = i, _extent(cols[i])
        while (j < n - 1 and _diff(cols[j], cols[j + 1]) <= tol
               and e is not None and _extent(cols[j + 1]) == e):
            j += 1
        if j > i:
            out.append((i, j - i + 1))
        i = max(j, i + 1)
    return out


def grow(cols, want):
    """Return a new column list of length <= want, having only copied columns."""
    have = len(cols)
    need = want - have
    if need <= 0:
        return cols, 0, "already spans"

    p = _period(cols)
    if p and p <= need:
        # Copy whole periods from the most self-similar location.
        best, at = None, 0
        for i in range(have - p):
            s = _diff(cols[i], cols[i + p])
            if best is None or s < best:
                best, at = s, i
        k = need // p
        block = [list(c) for c in cols[at:at + p]] * k
        return cols[:at] + block + cols[at:], k * p, "period %d x%d" % (p, k)

    # No usable period: grow inside the flat runs. Two rules, both learned from
    # a sprite this got wrong.
    #
    # A RUN ONLY COUNTS WHILE THE FOOTPRINT HOLDS STILL -- see `_runs`, which is
    # where that rule and the sprite that taught it are written down.
    #
    # AND GROWTH IS SPLIT IN PROPORTION, not poured into the longest run until it
    # is full. `coolant` is pipe-valve-pipe, and greedy filling put every new
    # column in the left pipe, walking the valve toward the middle of a sprite it
    # had never sat in the middle of. Proportional shares leave the composition
    # where the generator put it.
    base = sum(_diff(cols[i], cols[i + 1]) for i in range(have - 1)) / float(max(1, have - 1))
    runs = _runs(cols, max(1, int(base * 0.35)))
    if not runs:
        return cols, 0, "no period, no run worth growing"
    total = float(sum(r[1] for r in runs))
    add, left = {}, need
    for start, length in sorted(runs, key=lambda r: -r[1]):
        take = min(left, min(length, int(round(need * length / total))))
        if take > 0:
            add[start] = take
            left -= take
    # Whatever rounding left over goes to the longest run that can still take it.
    for start, length in sorted(runs, key=lambda r: -r[1]):
        if left <= 0:
            break
        room = length - add.get(start, 0)
        take = min(left, room)
        if take > 0:
            add[start] = add.get(start, 0) + take
            left -= take
    out, done = [], 0
    for i, c in enumerate(cols):
        out.append(c)
        if i in add:
            out.extend([list(c) for _ in range(add[i])])
            done += add[i]
    return out, done, "runs %d" % len(add)


def _as_cols(w, h, rows):
    return [[bytearray(rows[y][x * 4:x * 4 + 4]) for y in range(h)] for x in range(w)]


def _from_cols(cols, h):
    w = len(cols)
    out = [bytearray(w * 4) for _ in range(h)]
    for x, c in enumerate(cols):
        for y in range(h):
            out[y][x * 4:x * 4 + 4] = c[y]
    return w, h, out


def main():
    src, bw, bh = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    dst = sys.argv[4] if len(sys.argv) > 4 else src
    w, h, rows = pt.decode(src)
    w, h, rows = pt.trim(w, h, rows)
    ow, oh = w, h

    cols = _as_cols(w, h, rows)
    cols, dw, whyw = grow(cols, bw)
    w, h, rows = _from_cols(cols, h)

    # The same operation on rows, by transposing the problem rather than writing
    # it twice: a row of the image is a "column" of the transpose.
    rws = [[bytearray(rows[y][x * 4:x * 4 + 4]) for x in range(w)] for y in range(h)]
    rws, dh, whyh = grow(rws, bh)
    h = len(rws)
    rows = [bytearray(w * 4) for _ in range(h)]
    for y, r in enumerate(rws):
        for x in range(w):
            rows[y][x * 4:x * 4 + 4] = r[x]

    w, h, rows = pt.trim(w, h, rows)
    w, h, rows, over = pt.fit(w, h, rows, bw, bh)
    print("  %-13s %dx%d -> %dx%d in %dx%d   w: %-18s h: %s%s"
          % (os.path.basename(src)[:-4], ow, oh, ow + dw, oh + dh, bw, bh,
             whyw, whyh, "  OVERFLOW" if any(over) else ""))
    pt.encode(dst, w, h, rows)


if __name__ == "__main__":
    main()
