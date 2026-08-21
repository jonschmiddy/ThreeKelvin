"""Set a sprite's livery ratio to a target, by repainting whole panels.

The generator will not take an instruction about HOW MUCH of a colour to use.
Measured across ten rolls of one prompt: told "completely bare" it returned 0.9%
amber, told "well fitted" it returned 40.9%, told "every section occupied" it
returned 7.4%. The forced-palette parameter constrains which colours are legal
and discards proportion entirely - a reference that was half amber produced 0.1%.

So the amount is set here instead, where it is exact.

WHOLE PANELS, NEVER LOOSE PIXELS. A livery panel is a connected region of amber;
recolouring a fraction of one leaves a torn edge that reads as damage rather than
as paint. Regions are converted entire, largest first, until the ratio lands.

The swap is LUMINANCE-MATCHED. Every amber shade maps to the steel shade of
closest brightness, so a panel that was lit at the top and shadowed at the
bottom stays lit at the top and shadowed at the bottom. Mapping by hue alone
flattens the two-plane lighting the whole art direction rests on.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt

REF = 'art/sprites/hull_medium_cold.png'


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def is_amber(c):
    return c[0] - c[2] > 40 and c[0] > 100


def ramps(path):
    """The reference sprite's amber and steel shades, brightest last."""
    w, h, rows = pt.decode(path)
    pal = pt.palette(w, h, rows)
    amber = sorted([c for c in pal if is_amber(c)], key=luma)
    steel = sorted([c for c in pal if c[2] >= c[0] and c not in amber], key=luma)
    return amber, steel


def nearest(ramp, target):
    return min(ramp, key=lambda c: abs(luma(c) - target))


def regions(w, h, rows, pred):
    """Connected runs of pixels matching `pred`, largest first."""
    def rgb(x, y):
        o = x * 4
        return (rows[y][o], rows[y][o + 1], rows[y][o + 2])

    def ok(x, y):
        return (0 <= x < w and 0 <= y < h and rows[y][x * 4 + 3] > 0
                and pred(rgb(x, y)))

    seen = set()
    out = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or not ok(x, y):
                continue
            stack = [(x, y)]
            cells = []
            while stack:
                q = stack.pop()
                if q in seen or not ok(*q):
                    continue
                seen.add(q)
                cells.append(q)
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    stack.append((q[0] + d[0], q[1] + d[1]))
            if cells:
                out.append(cells)
    out.sort(key=len, reverse=True)
    return out


def retint(path, out_path, target=0.159, ref=REF):
    amber_ramp, steel_ramp = ramps(ref)
    w, h, rows = pt.decode(path)
    out = [bytearray(r) for r in rows]

    def rgb(x, y):
        o = x * 4
        return (out[y][o], out[y][o + 1], out[y][o + 2])

    opaque = sum(1 for y in range(h) for x in range(w) if rows[y][x * 4 + 3])
    want = int(round(target * opaque))
    have = sum(1 for y in range(h) for x in range(w)
               if rows[y][x * 4 + 3] and is_amber(rgb(x, y)))
    moved = 0

    if have > want:
        # Too much livery. Strip whole panels, SMALLEST FIRST - the big panels
        # are the ship's identity and the little amber flecks are the ones a
        # generator scatters as trim, so removing those first is both closer to
        # the target and closer to what a person would have drawn.
        # CONTINUE, not break. Stopping at the first region that would
        # overshoot abandons every smaller one behind it, which left #08 sitting
        # at 33.3% having repainted nothing at all.
        for cells in sorted(regions(w, h, rows, is_amber), key=len):
            if have - len(cells) < want:
                continue
            for x, y in cells:
                out[y][x * 4:x * 4 + 3] = bytes(nearest(steel_ramp, luma(rgb(x, y))))
            have -= len(cells)
            moved += len(cells)
    elif have < want:
        # Too little. Paint steel panels amber, LARGEST FIRST, because a livery
        # panel is a big flat area and a hull's biggest flat areas are where one
        # would go.
        # Take the biggest region that still FITS IN THE GAP, repeatedly. The
        # first cut compared each region against the target rather than against
        # what was still missing, so on a nearly-bare hull every candidate was
        # larger than the whole allowance and all of them were skipped - which
        # is why #01 came back at 0.9% having done nothing.
        flat = [c for c in regions(w, h, rows, lambda c: c[2] >= c[0])
                if len(c) >= 30]
        used = set()
        while have < want:
            gap = want - have
            best = None
            for i, cells in enumerate(flat):
                if i in used or len(cells) > gap * 1.4:
                    continue
                if best is None or len(cells) > len(flat[best]):
                    best = i
            if best is None:
                break
            for x, y in flat[best]:
                out[y][x * 4:x * 4 + 3] = bytes(nearest(amber_ramp, luma(rgb(x, y))))
            have += len(flat[best])
            moved += len(flat[best])
            used.add(best)

    pt.encode(out_path, w, h, out)
    return 100.0 * have / opaque, moved


if __name__ == '__main__':
    src = sys.argv[1]
    dst = sys.argv[2]
    tgt = float(sys.argv[3]) if len(sys.argv) > 3 else 0.159
    got, moved = retint(src, dst, tgt)
    print('%s -> %.1f%% amber (%d px repainted)' % (os.path.basename(src), got, moved))
