"""Cut the bolted-on bays OFF a hull, leaving the bare frame underneath.

Different job from strip_bays.py, and the one that was actually wanted. That
one emptied the bays in place and kept the outline. This removes them from the
SILHOUETTE, because they are not inset panels — they are boxes bolted to the
hull that stick out past it.

Measured on the medium, the top and bottom profile says so plainly:

    x  38..44   stern, curving       top 32 -> 29   bottom 56 -> 59
    x  45..133  FLAT                 top 4          bottom 80
    x 134..182  nose, tapering       top 9 -> 42    bottom 76 -> 48

A hand-drawn hull does not have eighty-nine columns of identical height in the
middle and curves at both ends. The flat run is the bays, seen edge-on. The bare
frame is the curve that the stern and the nose are both already part of.

So: keep the profile where it is genuinely the hull, interpolate across the part
the bays flattened, and cut anything outside it.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt

BARE_STERN = 44      # last column before the bays begin
BARE_NOSE = 134      # first column after they end
OUTLINE = (0x0b, 0x0f, 0x16)


def profile(rows, w, h):
    top, bot = {}, {}
    for x in range(w):
        ys = [y for y in range(h) if rows[y][x * 4 + 3] > 0]
        if ys:
            top[x], bot[x] = min(ys), max(ys)
    return top, bot


def smooth(a, b, t):
    """Smoothstep. A linear tween between the stern and the nose gives a hull
    with two visible corners where the interpolation starts and stops; easing
    both ends means the reconstructed curve leaves the real geometry tangentially
    and nobody can see the join."""
    t = t * t * (3.0 - 2.0 * t)
    return a + (b - a) * t


def shave(src, dst, belly=0.0):
    w, h, rows = pt.decode(src)
    top, bot = profile(rows, w, h)
    if BARE_STERN not in top or BARE_NOSE not in top:
        raise SystemExit('hull does not reach the sample columns')

    t0, t1 = top[BARE_STERN], top[BARE_NOSE]
    b0, b1 = bot[BARE_STERN], bot[BARE_NOSE]
    want_t, want_b = dict(top), dict(bot)
    span = BARE_NOSE - BARE_STERN
    for x in range(BARE_STERN + 1, BARE_NOSE):
        t = (x - BARE_STERN) / float(span)
        # `belly` bows the middle outward. A pure tween between two ends gives a
        # wedge; a ship wants to be widest somewhere in the middle of its length.
        bow = belly * (1.0 - (2.0 * t - 1.0) ** 2)
        want_t[x] = int(round(smooth(t0, t1, t) - bow))
        want_b[x] = int(round(smooth(b0, b1, t) + bow))

    out = [bytearray(r) for r in rows]
    cut = 0
    for x in range(w):
        if x not in want_t:
            continue
        for y in range(h):
            if rows[y][x * 4 + 3] == 0:
                continue
            if y < want_t[x] or y > want_b[x]:
                out[y][x * 4 + 3] = 0
                cut += 1

    # Re-edge it. Shaving exposes interior pixels that were never meant to be a
    # boundary, and a pixel-art hull without its 1px dark outline reads as a
    # cutout rather than an object.
    def live(x, y):
        return 0 <= x < w and 0 <= y < h and out[y][x * 4 + 3] > 0
    edge = []
    for y in range(h):
        for x in range(w):
            if not live(x, y):
                continue
            if not all(live(x + dx, y + dy)
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.append((x, y))
    for x, y in edge:
        out[y][x * 4:x * 4 + 3] = bytes(OUTLINE)

    pt.encode(dst, w, h, out)
    kept = sum(1 for y in range(h) for x in range(w) if out[y][x * 4 + 3] > 0)
    print('cut %d px, %d remain, %d re-outlined' % (cut, kept, len(edge)))
    print('profile now: stern top %d bot %d -> nose top %d bot %d'
          % (t0, b0, t1, b1))
    return w, h, out


if __name__ == '__main__':
    a = sys.argv[1] if len(sys.argv) > 1 else 'art/sprites/hull_medium_cold.png'
    b = sys.argv[2] if len(sys.argv) > 2 else 'art/sprites/hull_medium_bare.png'
    belly = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    shave(a, b, belly)
