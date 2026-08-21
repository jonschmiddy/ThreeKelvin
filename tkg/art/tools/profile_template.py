"""Build a hull SILHOUETTE to hand the generator as an init image.

Words do not carry proportion. "Twice as long as it is tall" came back at four
to one, twice running, and the two hulls it produced were slender tubes beside a
medium that is a chunky teardrop at 1.9:1. An init image carries a shape exactly.

Its one cost is that `no_background` is silently ignored whenever an init is
supplied — measured twelve times out of twelve — so the result comes back
opaque. `pixeltools.strip_bg` removes an opaque background by flood-filling
inward from the border, which is precisely this problem, and was written for it.

THE PROFILE IS DERIVED, NOT DRAWN. It is the medium's own top-and-bottom
profile, measured column by column and rescaled. That is what makes a light and
a heavy read as the same yard's work: they are literally the same curve at a
different size, rather than three independent guesses at "Korvan-ish".

    python art/tools/profile_template.py light  152 72 out.png
    python art/tools/profile_template.py heavy  220 100 out.png
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt

SRC = 'art/sprites/hull_medium_cold.png'
# Sampled off the medium: the lit top band, the flank, and the shadowed belly.
# Three stops rather than a gradient, because the template only has to say
# WHERE THE LIGHT COMES FROM. The generator supplies the detail.
TOP = (0x92, 0xaa, 0xc4)
MID = (0x6c, 0x80, 0x98)
LOW = (0x34, 0x42, 0x54)
EDGE = (0x0b, 0x0f, 0x16)


def profile(path):
    """Top and bottom of the hull for every column it occupies, normalised to
    0..1 across its length so it can be replayed at any size."""
    w, h, rows = pt.decode(path)
    cols = []
    for x in range(w):
        ys = [y for y in range(h) if rows[y][x * 4 + 3] > 0]
        if ys:
            cols.append((x, min(ys), max(ys)))
    if not cols:
        raise SystemExit('%s has no opaque pixels' % path)
    x0, x1 = cols[0][0], cols[-1][0]
    y0 = min(c[1] for c in cols)
    y1 = max(c[2] for c in cols)
    span = float(max(1, x1 - x0))
    tall = float(max(1, y1 - y0))
    return [((x - x0) / span, (t - y0) / tall, (b - y0) / tall)
            for x, t, b in cols]


def seams(path):
    """Where the plating is divided, normalised across the hull's extent.

    A flat template produces a flat result at EVERY strength tested — 175, 100
    and 60 all came back as smooth blobs, because the generator elaborates what
    it is given and a blob elaborates into a blob. Seams give it something to
    work from: a panel edge is where rivets, wear and hatches belong, so drawing
    the divisions is most of the way to drawing the plating.
    """
    w, h, rows = pt.decode(path)
    dark = {(0x1a, 0x1e, 0x26), (0x13, 0x1a, 0x23), (0x10, 0x16, 0x1f)}

    def is_dark(x, y):
        o = x * 4
        return rows[y][o + 3] > 0 and (rows[y][o], rows[y][o + 1], rows[y][o + 2]) in dark

    cols = [x for x in range(w)
            if [y for y in range(h) if rows[y][x * 4 + 3]]]
    x0, x1 = cols[0], cols[-1]
    out = []
    for x in range(x0, x1 + 1):
        tall = sum(1 for y in range(h) if rows[y][x * 4 + 3])
        if tall < 12:
            continue
        d = sum(1 for y in range(h) if is_dark(x, y))
        if d >= tall * 0.55:
            out.append((x - x0) / float(max(1, x1 - x0)))
    # collapse neighbours: a two-pixel seam is one seam
    keep = []
    for f in out:
        if not keep or f - keep[-1] > 0.03:
            keep.append(f)
    return keep


def build(norm, w, h, out_path, inset=2, cuts=None):
    """Replay a normalised profile at a new size and fill it."""
    rows = [bytearray(w * 4) for _ in range(h)]
    usable_w = w - inset * 2
    usable_h = h - inset * 2
    for px in range(usable_w):
        f = px / float(max(1, usable_w - 1))
        # nearest sample; the profile is dense enough that interpolation buys
        # nothing at these sizes and risks smoothing a deliberate corner
        i = min(len(norm) - 1, int(round(f * (len(norm) - 1))))
        _, tn, bn = norm[i]
        x = inset + px
        top = inset + int(round(tn * (usable_h - 1)))
        bot = inset + int(round(bn * (usable_h - 1)))
        if bot < top:
            top, bot = bot, top
        depth = max(1, bot - top)
        for y in range(top, bot + 1):
            f2 = (y - top) / float(depth)
            c = TOP if f2 < 0.22 else (MID if f2 < 0.68 else LOW)
            rows[y][x * 4:x * 4 + 4] = bytes((c[0], c[1], c[2], 255))
    # Panel divisions, replayed at this size. Drawn AFTER the fill and before
    # the outline, so a seam reads as a division of the plate rather than as a
    # scratch on top of it.
    if cuts:
        for f in cuts:
            x = inset + int(round(f * (usable_w - 1)))
            for y in range(h):
                if rows[y][x * 4 + 3] > 0:
                    rows[y][x * 4:x * 4 + 3] = bytes((0x1a, 0x1e, 0x26))

    # 1px outline, the same one every sprite in this game wears
    def live(x, y):
        return 0 <= x < w and 0 <= y < h and rows[y][x * 4 + 3] > 0
    edge = [(x, y) for y in range(h) for x in range(w) if live(x, y)
            and not all(live(x + dx, y + dy)
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:
        rows[y][x * 4:x * 4 + 3] = bytes(EDGE)
    pt.encode(out_path, w, h, rows)
    opq = sum(1 for y in range(h) for x in range(w) if live(x, y))
    bb = pt.bbox(w, h, rows)
    print('%-8s %dx%d  content %dx%d  ratio %.1f:1  %d px'
          % (os.path.basename(out_path), w, h,
             bb[2] - bb[0] + 1, bb[3] - bb[1] + 1,
             (bb[2] - bb[0] + 1) / float(bb[3] - bb[1] + 1), opq))


if __name__ == '__main__':
    norm = profile(SRC)
    if len(sys.argv) > 4:
        build(norm, int(sys.argv[2]), int(sys.argv[3]), sys.argv[4])
    else:
        cuts = seams(SRC)
        print('%d panel seams measured off the medium' % len(cuts))
        for name, w, h in (('light', 152, 72), ('medium', 188, 88), ('heavy', 220, 100)):
            build(norm, w, h, 'art/sprites/profile_%s.png' % name, cuts=cuts)
