# -*- coding: utf-8 -*-
"""Cut a plume down to the cavity it comes out of.

    python tools/crop_flame.py <src.png> <frames> <out.png> <mouth_x> <top> <bot> [apex_x] [hull.png ax ay]
    python tools/crop_flame.py --hull <hull.png> <ax> <ay> <from_x> <src.png> <frames> <out.png>

The second form is the one to use. It reads the mask off the HULL instead of
taking a typed wedge, because a typed wedge cannot know where the recess
actually ends: the first heavy_s mask left a black rim of un-covered cavity
between the fire and the plating, since the triangle I measured by eye was
smaller than the hole. Here the flame is allowed wherever the hull is DARK and
stops where it turns light, so it runs right up against the plating by
construction. `ax`/`ay` are the rigged offset -- the mask has to know where the
strip sits to line its columns up with the hull's.

GIVING A HULL SPARES THE PLATING. The wedge is geometry and does not know what
it is lying on, so nudging it deeper into the recess eventually pushes it out
over the light grey either side of the opening -- fire painted across solid hull.
With `hull.png ax ay` a flame pixel is dropped wherever the hull is solid, and
kept wherever the hull is OPEN.

Only columns that HAVE an opening get a say; a solid column is left to the wedge,
because the stern curves back past the mouth and judging those columns shears the
plume off in a straight line. Open is measured per column as the span from the
first dark row to the last, not as "this pixel is dark". Brightness alone cannot tell the plating outside the
hole from the detail inside it -- heavy_s has a light structural spar and amber
glints within its recess, and clipping on brightness left all of them poking back
through the flame as pale lines. The span says where the opening IS; what is
drawn inside it is the opening's business.

`from_x` is where the mask STARTS, in hull coordinates -- the cavity mouth.
Everything left of it is open space and is left alone. Without it the mask reads
"this column contains hull, so restrict it", which is false out in front of a
stern that curves: heavy_s's underside reaches back past the mouth, so the first
attempt sheared the outboard half of the plume off in a straight vertical line.

THE RECESS IS FILLED, not just masked. Masking alone removes flame pixels but
cannot add any, so wherever the plume's core is sparse the cavity's own interior
-- pale structural lines, amber glints -- shows straight through it and the whole
thing reads as a lit window rather than as fire. So inside the recess every
allowed pixel the flame does not already cover is filled by carrying the nearest
flame pixel in that row rightward. The gradient continues instead of stopping,
it still changes frame to frame because it is sampled per frame, and the recess
ends up solidly alight up to the plating.

A recess is often not one region. heavy_s has a light structural spar straight
across its axis, splitting the cavity into an upper and a lower triangle. Fire
is allowed across the WHOLE SPAN from the first dark row to the last, spar
included, rather than in the dark runs alone: an opening that is alight is alight
all the way across, and masking to the dark left the spar and the amber glints
poking through the flame as little dark ticks. Runs of one or two pixels do not
open the span -- that is the hull's own outline, and letting fire leak along it
draws a burning edge around the whole ship.

A generated plume is a rectangle of fire. A hull's exhaust is a WEDGE cut into
the stern -- mouth at the back, apex pointing forward -- and dropping the first
into the second gives you a wall of flame wider than the ship, spilling over the
hull's own outline and stopping in a hard vertical edge somewhere inside it.

The mask is a LENS, and every number in it is measured off the hull:

    left of the mouth   NOTHING. This is open space -- there is no hull out
                        there to spill over -- and the plume art already tapers
                        the way fire does. Two shaped profiles were tried here
                        and both were worse than none: a linear taper left a thin
                        dart, and a square root still shaved the flare and the
                        wisps that sell it as thrust.
    mouth to apex       it narrows, following the recess inward, so the fire
                        PLUGS INTO the wedge instead of stopping against it.

Giving `apex_x` is what makes it a mask rather than a crop. Without it the tool
stops at the mouth, which cuts away the part inside the recess and reads as a
flame parked against the stern rather than coming out of it. The mask only ever
clears pixels, so a rigged offset stays correct after it runs.

`mouth_x`, `top`, `bot` and `apex_x` are in the FLAME's own coordinates --
subtract the rigged offset from the hull-space numbers first.
"""
import io
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt


LUMA = 70.0     # above this the hull is plating, not recess
MINRUN = 3      # a shorter dark run is the silhouette's outline, not a hole


def from_hull(hull, ax, ay, from_x, src, frames, out):
    hw, hh, hr = pt.decode(hull)
    w, h, rows = pt.decode(src)
    fw = w // frames

    def dark(x, y):
        o = x * 4
        if not hr[y][o + 3]:
            return False
        return 0.299 * hr[y][o] + 0.587 * hr[y][o + 1] + 0.114 * hr[y][o + 2] < LUMA

    # Per hull column: the rows fire may occupy. Open space is unrestricted.
    allow = {}
    for x in range(hw):
        if x < from_x or not any(hr[y][x * 4 + 3] for y in range(hh)):
            allow[x] = None
            continue
        lo, hi, run = None, None, []
        for y in range(hh + 1):
            if y < hh and dark(x, y):
                run.append(y)
            else:
                if len(run) >= MINRUN:
                    lo = run[0] if lo is None else min(lo, run[0])
                    hi = run[-1] if hi is None else max(hi, run[-1])
                run = []
        allow[x] = set() if lo is None else set(range(lo, hi + 1))

    dst = [bytearray(w * 4) for _ in range(h)]
    kept = cut = filled = 0
    for f in range(frames):
        for y in range(h):
            carry = None
            for x in range(fw):
                o = (f * fw + x) * 4
                d = o
                a = allow.get(ax + x, None)
                lit = rows[y][o + 3] != 0
                if lit:
                    if a is not None and (ay + y) not in a:
                        cut += 1
                        continue
                    dst[y][d:d + 4] = rows[y][o:o + 4]
                    carry = bytes(rows[y][o:o + 4])
                    kept += 1
                elif a is not None and carry is not None and (ay + y) in a:
                    # Inside the recess, downstream of fire: carry it on rather
                    # than let the cavity show through a hole in the plume.
                    dst[y][d:d + 4] = carry
                    filled += 1
    pt.encode(out, w, h, dst)
    print("  %s masked by %s at (%d, %d)"
          % (os.path.basename(src), os.path.basename(hull), ax, ay))
    print("  frames %d of %dx%d   (%d kept, %d cut, %d filled into the recess)"
          % (frames, fw, h, kept, cut, filled))


def main():
    if sys.argv[1] == "--hull":
        from_hull(sys.argv[2], int(sys.argv[3]), int(sys.argv[4]),
                  int(sys.argv[5]), sys.argv[6], int(sys.argv[7]), sys.argv[8])
        return
    src, frames, out, mouth, top, bot = (
        sys.argv[1], int(sys.argv[2]), sys.argv[3],
        int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]))
    apex = int(sys.argv[7]) if len(sys.argv) > 7 else 0
    solid = None
    if len(sys.argv) > 10:
        hw, hh, hrows = pt.decode(sys.argv[8])
        hx, hy = int(sys.argv[9]), int(sys.argv[10])

        def dark_at(px, py):
            o = px * 4
            if not hrows[py][o + 3]:
                return False
            return (0.299 * hrows[py][o] + 0.587 * hrows[py][o + 1]
                    + 0.114 * hrows[py][o + 2]) < LUMA

        open_rows = {}
        for px in range(hw):
            if not any(hrows[py][px * 4 + 3] for py in range(hh)):
                open_rows[px] = None          # no hull here: all of it is open
                continue
            lo = hi = None
            run = []
            for py in range(hh + 1):
                if py < hh and dark_at(px, py):
                    run.append(py)
                else:
                    if len(run) >= MINRUN:
                        lo = run[0] if lo is None else min(lo, run[0])
                        hi = run[-1] if hi is None else max(hi, run[-1])
                    run = []
            # A column with no opening in it gets NO OPINION, not "cut it all".
            # The stern curves, so its underside reaches back past the mouth and
            # those columns are solid -- judging them sheared the outboard half
            # of the plume off in a straight vertical line, twice.
            open_rows[px] = None if lo is None else (lo, hi)
        # SMOOTHED BY WIDENING, over a few columns either side. Taken raw the band
        # jitters -- the hull's dark runs vary a row or two -- and a column that
        # measures narrower than its neighbours cuts a notch out of the flame that
        # reads as a stray dark sliver. Two narrower smoothings were tried first
        # and both left the hole dark, which is the fault this whole mask exists
        # to fix: clamping to the running tightest collapsed the channel to the
        # narrowest column, and interpolating mouth-to-apex only ever narrowed, so
        # neither covered the recess where it is actually widest. Taking the
        # WIDEST band in a small window fills the dips instead of chasing them,
        # and it cannot spill onto plating by more than the window, because the
        # neighbours it borrows from are openings too.
        WIN = 3
        cols = sorted(k for k in open_rows if open_rows[k] is not None)
        raw = {px: open_rows[px] for px in cols}
        for px in cols:
            near = [raw[q] for q in range(px - WIN, px + WIN + 1) if q in raw]
            open_rows[px] = (min(b[0] for b in near), max(b[1] for b in near))
        solid = (open_rows, hx, hy)
    w, h, rows = pt.decode(src)
    fw = w // frames
    # Clamped to the strip: the apex is a fact about the HULL, and a plume rigged
    # further forward can run out of frame before it reaches it. That is fine --
    # the opening is still widening there -- but the output cannot be wider than
    # the source or every frame would read the next one's pixels.
    nw = min(apex + 1, fw) if apex else mouth
    cy = (top + bot) / 2.0
    half = (bot - top) / 2.0
    dst = [bytearray(nw * frames * 4) for _ in range(h)]
    kept = cut = 0
    for f in range(frames):
        for y in range(h):
            for x in range(nw):
                o = (f * fw + x) * 4
                if not rows[y][o + 3]:
                    continue
                # Untouched outboard; narrowing into the recess from the mouth
                # in. Past the apex there is no opening left, so nothing is drawn.
                if x < mouth:
                    lim = float(h)
                elif apex:
                    lim = half * float(apex - x) / float(apex - mouth)
                else:
                    lim = 0.0
                if abs(y - cy) > lim:
                    cut += 1
                    continue
                if solid is not None:
                    open_rows, hx, hy = solid
                    band = open_rows.get(hx + x, None)
                    if band is not None and not (band[0] <= hy + y <= band[1]):
                        cut += 1
                        continue
                d = (f * nw + x) * 4
                dst[y][d:d + 4] = rows[y][o:o + 4]
                kept += 1
    # EVERY isolated pixel goes, not only the ones the mask stranded. The first
    # version kept the plume's own sparks on the grounds that they are art rather
    # than damage, and that was wrong in context: against a masked plume seated in
    # a recess a lone lit pixel floating off the flame reads as a stray, not as a
    # spark. Jon called it an artifact twice. It costs about two pixels a frame.
    def orphans(rows, w):
        out = set()
        for f in range(frames):
            for y in range(h):
                for x in range(w):
                    if not rows[y][(f * w + x) * 4 + 3]:
                        continue
                    n = 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < w and 0 <= yy < h and rows[yy][(f * w + xx) * 4 + 3]:
                            n += 1
                    if n == 0:
                        out.add((f, x, y))
        return out
    stranded = orphans(dst, nw)
    for f, x, y in stranded:
        dst[y][(f * nw + x) * 4 + 3] = 0
    pt.encode(out, nw * frames, h, dst)
    if stranded:
        print("  %d isolated pixel(s) removed" % len(stranded))
    print("  %s -> %s" % (os.path.basename(src), os.path.basename(out)))
    print("  frames %d of %dx%d  ->  %dx%d   (%d px kept, %d cut)"
          % (frames, fw, h, nw, h, kept, cut))


if __name__ == "__main__":
    main()
