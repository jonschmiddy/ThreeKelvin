"""Sprite post-processing for the PixelLab pipeline. Pure standard library.

No Pillow, no ImageMagick. Neither is installed on the dev machine, and on
Windows `convert` is the filesystem tool, not ImageMagick — running it does
nothing useful and reports success. So this module carries its own PNG codec.

Everything here exists because a PixelLab result is not a finished game asset.
See docs/art/PIXELLAB_WORKFLOW.md for the process these functions implement.

    python pixeltools.py info      sprite.png
    python pixeltools.py strip     in.png out.png        # opaque bg -> alpha
    python pixeltools.py crop      in.png out.png X Y W H
    python pixeltools.py snap      in.png palette.png out.png
    python pixeltools.py trim      in.png out.png        # crop to the ink
    python pixeltools.py reduce    in.png out.png N       # /N, dominant pixel
    python pixeltools.py strip-anim out.png f0.png f1.png ...
"""

import struct
import sys
import zlib
from collections import Counter, deque


# --------------------------------------------------------------------- codec

def decode(path):
    """-> (width, height, [bytearray rows of RGBA8]). Non-interlaced only."""
    d = open(path, "rb").read()
    w, h = struct.unpack(">II", d[16:24])
    if d[24] != 8 or d[25] != 6:
        raise ValueError("%s: need 8-bit RGBA (type 6), got depth %d type %d"
                         % (path, d[24], d[25]))
    idat, i = b"", 8
    while i < len(d):
        ln = struct.unpack(">I", d[i:i + 4])[0]
        if d[i + 4:i + 8] == b"IDAT":
            idat += d[i + 8:i + 8 + ln]
        i += 12 + ln
    raw = zlib.decompress(idat)
    bpp, stride = 4, w * 4
    rows, prev, pos = [], bytearray(stride), 0
    for _y in range(h):
        f = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos + stride]); pos += stride
        # PNG filters are per scanline and must be undone in order.
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(line); prev = line
    return w, h, rows


def encode(path, w, h, rows):
    """Write RGBA8, filter 0 on every scanline. Small sprites; size is moot."""
    raw = b"".join(b"\x00" + bytes(r) for r in rows)

    def chunk(t, data):
        return (struct.pack(">I", len(data)) + t + data
                + struct.pack(">I", zlib.crc32(t + data) & 0xffffffff))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


# ------------------------------------------------------------------ measuring

def alpha_pct(w, h, rows):
    z = sum(1 for r in rows for x in range(w) if r[x * 4 + 3] == 0)
    return 100.0 * z / (w * h)


def bbox(w, h, rows):
    """Opaque bounding box, or None. Use it before deciding a crop."""
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if rows[y][x * 4 + 3]:
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
    return None if x1 < 0 else (x0, y0, x1, y1)


def palette(w, h, rows):
    """Every distinct opaque colour, most common first."""
    c = Counter()
    for y in range(h):
        for x in range(w):
            o = x * 4
            if rows[y][o + 3]:
                c[(rows[y][o], rows[y][o + 1], rows[y][o + 2])] += 1
    return c


# ------------------------------------------------------------------ operations

def strip_bg(w, h, rows, tol=14):
    """Opaque background -> alpha, flood-filled INWARD FROM THE BORDER.

    Never a global colour key. PixelLab returns a background sampled from the
    forced palette, so the same value occurs inside the hull too, and keying it
    globally punches holes through the ship. Flooding from the edge can only
    reach pixels that are actually outside it.
    """
    def px(x, y):
        o = x * 4
        return rows[y][o], rows[y][o + 1], rows[y][o + 2]

    edge = Counter()
    for x in range(w):
        edge[px(x, 0)] += 1; edge[px(x, h - 1)] += 1
    for y in range(h):
        edge[px(0, y)] += 1; edge[px(w - 1, y)] += 1
    if not edge:
        return 0
    bg = edge.most_common(1)[0][0]

    def near(c):
        return abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) <= tol

    seen, q = bytearray(w * h), deque()
    for x in range(w):
        for y in (0, h - 1):
            if near(px(x, y)) and not seen[y * w + x]:
                seen[y * w + x] = 1; q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near(px(x, y)) and not seen[y * w + x]:
                seen[y * w + x] = 1; q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and near(px(nx, ny)):
                seen[ny * w + nx] = 1; q.append((nx, ny))
    n = 0
    for y in range(h):
        for x in range(w):
            if seen[y * w + x] and rows[y][x * 4 + 3]:
                rows[y][x * 4 + 3] = 0; n += 1
    return n


def crop(w, h, rows, x0, y0, cw, ch):
    out = []
    for y in range(y0, y0 + ch):
        line = bytearray()
        for x in range(x0, x0 + cw):
            line += bytes(rows[y][x * 4:x * 4 + 4])
        out.append(line)
    return cw, ch, out


def snap(w, h, rows, pal):
    """Force every pixel onto `pal` (list of RGB tuples). Returns drift count.

    animate_image and create_image_pro both invent colours. Snapping to the
    SOURCE sprite's own palette keeps an approved look approved, where snapping
    to the project ramp would silently recolour it.
    """
    cache, n = {}, 0
    for y in range(h):
        for x in range(w):
            o = x * 4
            if not rows[y][o + 3]:
                continue
            c = (rows[y][o], rows[y][o + 1], rows[y][o + 2])
            if c in pal:
                continue
            n += 1
            if c not in cache:
                cache[c] = min(pal, key=lambda p: (c[0] - p[0]) ** 2
                               + (c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2)
            s = cache[c]
            rows[y][o], rows[y][o + 1], rows[y][o + 2] = s
    return n


def trim(w, h, rows):
    """Crop to the ink and nothing else. THE PREFERRED WAY DOWN TO SIZE.

    Every pixel that ships is exactly the pixel the generator drew, because
    nothing is resampled -- only empty margin is removed. That is the whole
    difference between this and reduce(), and on a 46x15 gun the difference is
    not subtle: reduce() halves a 92x30 image whose detail was drawn at 92x30,
    so half of it goes in the bin and the rest reads as speckle.

    The catch is that the generator decides how tall its subject is, so the
    result is whatever it is rather than a size you chose. That is why the
    fitted-part box is a guide and not a frame -- see ModuleIcon.draw_sprite.
    Ask for a canvas the width you want and let this take the rest away.
    """
    b = bbox(w, h, rows)
    if not b:
        return w, h, rows
    return crop(w, h, rows, b[0], b[1], b[2] - b[0] + 1, b[3] - b[1] + 1)


def reduce(w, h, rows, n):
    """Shrink by an exact integer factor, one n*n block to one pixel.

    PREFER trim(). This resamples, and resampling a generated sprite throws
    away detail that was drawn at full density. It survives for the one case
    trim cannot serve: a part whose box is too small for the generator's floor
    in BOTH axes, where there is no canvas that is both legal and small enough.

    THE DOMINANT PIXEL, NOT THE AVERAGE. Averaging four colours invents a fifth,
    which is how a snapped sprite comes back off its own palette and why this
    does not need a snap() afterwards: every colour it emits was already in the
    source, so the palette cannot drift by construction.

    Why this exists at all. A module is drawn on the hull at HALF the hold's
    cell -- a long gun is 46x15 art pixels -- and every module footprint is
    under PixelLab's floor of 16 per side and 1024 of area. Nothing in the set
    can be generated at the size it is drawn, so it is generated at 2x or 3x and
    brought down here, offline, once. The runtime still draws 1:1.

    A block is opaque when at least HALF its pixels are, which keeps an edge
    where the edge was. The alternative -- opaque if any pixel is -- fattens
    every silhouette by a pixel on all four sides, and at 15 pixels tall that is
    a seventh of the part.

    Ties go to the lowest RGB rather than to whichever the counter happened to
    see first, so a rebuild produces the same bytes. Determinism is worth more
    than the shade it occasionally costs.
    """
    if n < 1 or w % n or h % n:
        raise ValueError("%dx%d does not divide by %d" % (w, h, n))
    nw, nh = w // n, h // n
    out = []
    for by in range(nh):
        line = bytearray(nw * 4)
        for bx in range(nw):
            tally, solid = {}, 0
            for dy in range(n):
                r = rows[by * n + dy]
                for dx in range(n):
                    o = (bx * n + dx) * 4
                    if not r[o + 3]:
                        continue
                    solid += 1
                    c = (r[o], r[o + 1], r[o + 2])
                    tally[c] = tally.get(c, 0) + 1
            if solid * 2 < n * n:
                continue                      # left transparent
            c = min(tally.items(), key=lambda kv: (-kv[1], kv[0]))[0]
            o = bx * 4
            line[o], line[o + 1], line[o + 2], line[o + 3] = c[0], c[1], c[2], 255
        out.append(line)
    return nw, nh, out


def fit(w, h, rows, bw, bh):
    """Centre the ink in an EXACTLY bw x bh canvas. Never resamples.

    THE LAST STEP OF EVERY MODULE SPRITE. A part is authored at the size of its
    box -- 20x20, 40x20, 60x20, 80x20, 40x40 -- and this is what guarantees it,
    whatever the generator happened to draw. Trimming alone gives whatever the
    ink measured (16x15, 38x13), which then has to be centred at draw time by
    code that could get it wrong, and leaves `-- artcheck` unable to say
    anything stricter than "close enough".

    Transparent margin costs nothing: it is the same pixels the draw would have
    left blank, decided here where it can be looked at instead of at runtime.

    Ink larger than the box is CLIPPED, deliberately and loudly -- it returns
    the overflow so the caller can refuse the asset. Silently shrinking it would
    be a resample by another name.
    """
    b = bbox(w, h, rows)
    if not b:
        return bw, bh, [bytearray(bw * 4) for _ in range(bh)], (0, 0)
    iw, ih = b[2] - b[0] + 1, b[3] - b[1] + 1
    over = (max(0, iw - bw), max(0, ih - bh))
    out = [bytearray(bw * 4) for _ in range(bh)]
    ox, oy = (bw - iw) // 2, (bh - ih) // 2
    for y in range(min(ih, bh)):
        for x in range(min(iw, bw)):
            s = (b[0] + x) * 4
            dx, dy = ox + x, oy + y
            if 0 <= dx < bw and 0 <= dy < bh:
                out[dy][dx * 4:dx * 4 + 4] = rows[b[1] + y][s:s + 4]
    return bw, bh, out, over


def reduce_avg(w, h, rows, n):
    """Like reduce(), but each block picks the pixel NEAREST ITS OWN AVERAGE.

    Same guarantee -- only colours that were already in the block are emitted,
    so the palette cannot drift -- and a different answer where a block is split
    between a highlight and a shadow. reduce() takes whichever is more numerous
    and can drop a one-pixel specular entirely; this takes whichever is closest
    to what the block MEANS, which keeps a lit edge reading as a lit edge.

    Which is better is a question about the art, not about the code. Try both.
    """
    if n < 1 or w % n or h % n:
        raise ValueError("%dx%d does not divide by %d" % (w, h, n))
    nw, nh = w // n, h // n
    out = []
    for by in range(nh):
        line = bytearray(nw * 4)
        for bx in range(nw):
            seen, tot = [], [0, 0, 0]
            for dy in range(n):
                r = rows[by * n + dy]
                for dx in range(n):
                    o = (bx * n + dx) * 4
                    if not r[o + 3]:
                        continue
                    c = (r[o], r[o + 1], r[o + 2])
                    seen.append(c)
                    tot[0] += c[0]; tot[1] += c[1]; tot[2] += c[2]
            if len(seen) * 2 < n * n:
                continue
            k = len(seen)
            av = (tot[0] / k, tot[1] / k, tot[2] / k)
            c = min(seen, key=lambda p: (p[0] - av[0]) ** 2 + (p[1] - av[1]) ** 2
                    + (p[2] - av[2]) ** 2)
            o = bx * 4
            line[o], line[o + 1], line[o + 2], line[o + 3] = c[0], c[1], c[2], 255
        out.append(line)
    return nw, nh, out


def hstrip(frames):
    """[(w,h,rows), ...] of equal size -> one horizontal strip."""
    fw, fh = frames[0][0], frames[0][1]
    out = [bytearray(fw * len(frames) * 4) for _ in range(fh)]
    for i, (w, h, rows) in enumerate(frames):
        if (w, h) != (fw, fh):
            raise ValueError("frame %d is %dx%d, expected %dx%d" % (i, w, h, fw, fh))
        for y in range(fh):
            out[y][i * fw * 4:(i + 1) * fw * 4] = rows[y]
    return fw * len(frames), fh, out


# ------------------------------------------------------------------------ cli

def _main(argv):
    if len(argv) < 2:
        print(__doc__); return 1
    cmd = argv[1]
    if cmd == "info":
        w, h, rows = decode(argv[2])
        print("%s  %dx%d  %.1f%% transparent" % (argv[2], w, h, alpha_pct(w, h, rows)))
        b = bbox(w, h, rows)
        if b:
            print("  content x %d..%d  y %d..%d  (margins L%d R%d T%d B%d)"
                  % (b[0], b[2], b[1], b[3], b[0], w - 1 - b[2], b[1], h - 1 - b[3]))
        for c, n in palette(w, h, rows).most_common(16):
            print("  #%02x%02x%02x  x%d" % (c[0], c[1], c[2], n))
    elif cmd == "strip":
        w, h, rows = decode(argv[2])
        n = strip_bg(w, h, rows)
        encode(argv[3], w, h, rows)
        print("cleared %d background px -> %.1f%% transparent" % (n, alpha_pct(w, h, rows)))
    elif cmd == "crop":
        w, h, rows = decode(argv[2])
        x, y, cw, ch = (int(v) for v in argv[4:8])
        encode(argv[3], *crop(w, h, rows, x, y, cw, ch))
        print("cropped to %dx%d at (%d,%d)" % (cw, ch, x, y))
    elif cmd == "snap":
        w, h, rows = decode(argv[2])
        pw, ph, prows = decode(argv[3])
        pal = list(palette(pw, ph, prows).keys())
        n = snap(w, h, rows, pal)
        encode(argv[4], w, h, rows)
        print("snapped %d px onto %d source colours" % (n, len(pal)))
    elif cmd == "trim":
        w, h, rows = decode(argv[2])
        encode(argv[3], *trim(w, h, rows))
        nw, nh, _ = trim(w, h, rows)
        print("%dx%d -> %dx%d" % (w, h, nw, nh))
    elif cmd == "reduce":
        w, h, rows = decode(argv[2])
        n = int(argv[4])
        encode(argv[3], *reduce(w, h, rows, n))
        print("%dx%d /%d -> %dx%d" % (w, h, n, w // n, h // n))
    elif cmd == "strip-anim":
        frames = [decode(f) for f in argv[3:]]
        w, h, rows = hstrip(frames)
        encode(argv[2], w, h, rows)
        print("%d frames -> %dx%d strip" % (len(frames), w, h))
    else:
        print(__doc__); return 1
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
