"""Measure how far a walk strip actually strides, so nothing has to guess.

    python tools/walk_stride.py <strip.png> <frame_width>

WHY THIS EXISTS. A walk cycle looks right only when the body advances exactly
as far as the sprite's own legs say it should. Move it further and the planted
foot skates forward; move it less and the character moonwalks. I picked 11px a
frame out of the air against a sprite that strides 6.2, and Jon's first words
on seeing it were that they were sliding on the floor.

The number is a property OF THE ART and cannot be inferred from the frame
count, the character's height or the template's name -- two six-frame walks
from the same generator stride different distances. So it is measured from the
pixels and carried beside the sprite.

HOW. While a boot is planted it does not move on the deck, so at the right
advance the pixels touching the ground land on the same ground twice running.
The advance is found by asking the WHOLE CYCLE at once -- of every candidate,
which single one best explains all the frames -- rather than pair by pair.

Pairwise is the trap. Following the planted boot frame to frame gave 7.00px;
cross-correlating the soles gave 8.67; the samples inside each method scattered
from 1.5 to 13. The boots swap roles mid-cycle and the sole reshapes as it
rolls heel to toe, so any one pair reads two ways. Asked of the whole cycle
there is a clear peak, and the changeover frames fit badly at every advance
instead of poisoning an average.

It is never exact: the sole changes shape through the step, so the best fit
sits near 40% and the peak is about a pixel wide. A pixel is the size of the
error a viewer can see, so this is the starting number and the eye settles it.
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools  # noqa: E402

ALPHA = 40


def stride(path, fw):
    """The advance per frame that keeps the soles most nearly still.

    NOT measured pair by pair. Following the planted boot from one frame to the
    next gave 7.00 px, cross-correlating the soles gave 8.67, and the samples
    within each method scattered wildly ([6.0, 6.5, 9.0, 3.5]) -- because the
    boots swap roles mid-cycle and the sole reshapes as it rolls heel to toe,
    so any single pair can be read two ways.

    So the question is asked of the whole cycle at once: of all the advances,
    which ONE best explains every frame? That has a clear peak where the
    pairwise methods have noise. The frames where the weight changes feet fit
    badly at every advance, so they no longer poison an average the way they
    did when each pair voted.
    """
    w, h, r = pixeltools.decode(path)
    if w % fw:
        raise SystemExit("walk_stride: %dpx strip does not divide into %dpx "
                         "frames" % (w, fw))
    n = w // fw
    # ONLY THE SOLE -- two rows. The swinging foot is off the ground and simply
    # is not here, so there is nothing to confuse the planted one with.
    soles = []
    for i in range(n):
        s = set()
        for y in range(h - 2, h):
            for x in range(fw):
                if r[y][(i * fw + x) * 4 + 3] >= ALPHA:
                    s.add((x, y))
        soles.append(s)
    if not any(soles):
        raise SystemExit("walk_stride: nothing touches the ground in %s -- is "
                         "the frame width right?" % os.path.basename(path))

    def fit(d):
        """How well the soles stay put on the deck at this advance."""
        tot = 0.0
        for i in range(n - 1):
            a = set((x + int(round(i * d)), y) for x, y in soles[i])
            b = set((x + int(round((i + 1) * d)), y) for x, y in soles[i + 1])
            u = len(a | b)
            tot += (len(a & b) / float(u)) if u else 0.0
        return tot / (n - 1)

    best, bd, curve = -1.0, 0.0, []
    d = 1.0
    while d <= 24.0:
        f = fit(d)
        curve.append((d, f))
        if f > best:
            best, bd = f, d
        d += 0.25
    # How wide the peak is, which is how much this can be trusted. The sole
    # changes shape through the step, so it never reaches 1.0 and the optimum
    # is broad -- about a pixel wide, which is the size of the error that shows.
    near = [c[0] for c in curve if c[1] > best * 0.97]
    return {"frames": n, "frame_w": fw, "frame_h": h,
            "advance_px": round(bd, 2), "cycle_px": round(bd * n, 1),
            "fit": round(best, 3),
            "within_3pct": [near[0], near[-1]] if near else [bd, bd]}


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__.strip().splitlines()[2].strip())
    path, fw = sys.argv[1], int(sys.argv[2])
    s = stride(path, fw)
    print("%s" % os.path.basename(path))
    print("  %d frames of %dx%d" % (s["frames"], s["frame_w"], s["frame_h"]))
    print("  advance %.2f px per frame, %.1f px per cycle"
          % (s["advance_px"], s["cycle_px"]))
    print("  sole stays put %.0f%% of the time; anything from %.2f to %.2f "
          "fits nearly as well" % (s["fit"] * 100, s["within_3pct"][0],
                                   s["within_3pct"][1]))
    # A person's stride is roughly three quarters of their height. Far off that
    # and the gait will read as mincing or as bounding, however smooth it is.
    ratio = s["cycle_px"] / float(s["frame_h"])
    print("  stride is %.2f x the figure's height (a person's is about 0.75)"
          % ratio)
    if ratio < 0.5:
        print("  -- short: this will read as quick little steps")
    elif ratio > 1.1:
        print("  -- long: this will read as bounding")
    print(json.dumps(s))


if __name__ == "__main__":
    main()
