"""The number of frames a walk cycle ACTUALLY takes, which is rarely the number
of frames the generator returned.

    python tools/walk_period.py <dir of 0.png .. N-1.png>

WHY THIS EXISTS. Asked for 16 frames, PixelLab returns 16 images -- but the
walk inside them may close in 12, or 8. The extra frames are not padding; they
are a partial second lap, so playing all 16 puts a hitch at the seam every
cycle. The first 16-frame walker shipped with exactly that fault and it took
Jon noticing "the walking animation also weirdly loops wrong" to find it.

The frames are compared as raw silhouettes on their own canvas, because a v3
walk is an IN-PLACE cycle -- the generator does not translate the figure, so
canvas coordinates are already aligned and nothing needs registering first.
Period P is the smallest P where frame i and frame i+P agree across every i
that has a partner. Frame 0 alone is not enough evidence: a walk passes through
a near-mirror of its start at the half cycle, so matching 0 against 8 votes for
8 when the truth is 16.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tkg", "art", "tools"))
import pixeltools  # noqa: E402

ALPHA = 40


def load(path):
    """-> (w, h, silhouette rows, rgb rows). decode() hands back flat RGBA
    bytearrays, one per scanline."""
    w, h, rows = pixeltools.decode(path)
    sil, rgb = [], []
    for row in rows:
        sil.append(bytes(1 if row[x * 4 + 3] >= ALPHA else 0 for x in range(w)))
        rgb.append(row)
    return w, h, sil, rgb


def agree(a, b, w, h):
    """-> (silhouette IoU, colour agreement over the shared pixels).

    THE TWO NUMBERS ANSWER DIFFERENT QUESTIONS, and only together do they
    find a walk's real lap. Seen side on, a walker at the half cycle is very
    nearly its own mirror -- same outline, legs swapped -- so the silhouette
    peaks at HALF the period and would have us ship a cycle whose near and far
    legs trade shading every step. Colour does not: the near leg is lit and the
    far one is not, so a half cycle disagrees on exactly those pixels.
    """
    sa, ra = a
    sb, rb = b
    inter = union = same = 0
    for y in range(h):
        pa, pb, ca, cb = sa[y], sb[y], ra[y], rb[y]
        for x in range(w):
            if pa[x] or pb[x]:
                union += 1
                if pa[x] and pb[x]:
                    inter += 1
                    o = x * 4
                    if (abs(ca[o] - cb[o]) < 24 and abs(ca[o + 1] - cb[o + 1]) < 24
                            and abs(ca[o + 2] - cb[o + 2]) < 24):
                        same += 1
    return (inter / union if union else 1.0,
            same / inter if inter else 1.0)


def period(frames, w, h):
    n = len(frames)
    # P=1 is not a candidate period -- it is the BASELINE. Frame i and frame
    # i+1 are different poses of the same character, so their agreement is what
    # "as alike as two drawings of this man ever get" means for this sprite.
    # A real repeat must beat it: frame i and frame i+P are the SAME pose.
    #
    # Without this the finder had no idea when to say "no period here". Run
    # against eighteen template animations -- each an authored cycle exactly
    # one lap long, with no repeat in it to find -- it confidently answered 2
    # or 3 for every one of them, and the whole survey installed itself before
    # the numbers were looked at.
    for p in range(1, n + 1):
        pairs = [(i, i + p) for i in range(n - p)]
        if not pairs:
            # p == n: the whole file is one lap, which is the fallback answer.
            yield p, 0.0, 0.0, 0
            continue
        s = c = 0.0
        for i, j in pairs:
            si, ci = agree(frames[i], frames[j], w, h)
            s += si
            c += ci
        yield p, s / len(pairs), c / len(pairs), len(pairs)


# How far past the neighbour baseline a repeat has to score before it is
# believed. Measured: on the two v3 cycles that really did contain a short lap
# the winner beat its baseline by 0.16 and 0.32; on eighteen template cycles
# with no lap to find, nothing beat it at all.
MARGIN = 0.05


def decide(rows, n):
    """-> (period, its score, the neighbour baseline).

    Returns n when no period is believable, which means "the whole file is one
    lap" -- the right answer for any authored cycle.
    """
    base = next((r[2] for r in rows if r[0] == 1), 0.0)
    tested = [r for r in rows if 2 <= r[0] < n and r[3] >= 2
              and r[2] >= base + MARGIN]
    if not tested:
        return n, base, base
    top = max(r[2] for r in tested)
    # The shortest period that agrees as well as the best does. A longer period
    # always scores at least as high because it compares fewer, more distant
    # pairs, so "highest" alone would always answer n-1.
    return min(r[0] for r in tested if r[2] >= top - 0.02), top, base


def main(argv):
    d = argv[0]
    paths = []
    i = 0
    while os.path.exists(os.path.join(d, "%d.png" % i)):
        paths.append(os.path.join(d, "%d.png" % i))
        i += 1
    if not paths:
        raise SystemExit("walk_period: no 0.png in %s" % d)

    w = h = None
    frames = []
    for p in paths:
        fw, fh, sil, rgb = load(p)
        if w is None:
            w, h = fw, fh
        elif (fw, fh) != (w, h):
            raise SystemExit("walk_period: %s is %dx%d, not %dx%d"
                             % (p, fw, fh, w, h))
        frames.append((sil, rgb))

    n = len(frames)
    print("%d frames, %dx%d" % (n, w, h))
    print("")
    print("  P   pairs   silhouette   colour")
    rows = []
    for p, sil, col, pairs in period(frames, w, h):
        rows.append((p, sil, col, pairs))
        print("  %-3d %-7d %-12.3f %.3f%s"
              % (p, pairs, sil, col, "" if pairs else "   (no evidence)"))

    # A lap is only believable if it was tested against something. Among the
    # periods with evidence, take the SHORTEST that agrees as well as the best
    # one does -- a longer period always scores at least as high (it compares
    # fewer, more distant pairs), so "highest score" alone would always answer
    # n-1 and never find the real lap.
    pick, top, base = decide(rows, n)
    print("")
    print("neighbour agreement (P=1) is %.3f -- a real repeat must beat it"
          % base)
    if pick >= n:
        print("nothing beats it by %.2f: all %d frames are one lap"
              % (MARGIN, n))
        return
    print("best colour agreement %.3f; shortest period within 0.02 of it: %d"
          % (top, pick))

    # Say so out loud when the silhouette wanted half of that, because the
    # half cycle is the answer that looks right and ships swapped legs.
    half = [r for r in tested if r[0] * 2 == pick]
    if half and half[0][1] >= max(r[1] for r in tested) - 0.02:
        print("(the silhouette alone peaks at %d -- that is the HALF cycle, "
              "legs swapped; colour rules it out)" % half[0][0])

    if pick < n:
        print("=> trim to frames 0..%d; the last %d are a partial second lap"
              % (pick - 1, n - pick))
    else:
        print("=> all %d frames are one lap" % n)


if __name__ == "__main__":
    main(sys.argv[1:])
