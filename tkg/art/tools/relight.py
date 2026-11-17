"""Flip a top-drawn gun for a belly mount and relight it so the light still comes from the top-left.

  uv run --with pillow python relight.py <gun.png> <out.png> [--mode faces|segments|plain]

Modes, all 0 generations, all using only colours the gun already has:
  plain     the bare vertical flip (the light now comes from below-left).
  segments  per column, each run between outline pixels gets its colours back in their original top-to-bottom
            order. Rivets and seams move inside the run, so faces come out mottled.
  facets    (default) as `faces`, and each face's MEAN luma is also mirrored about the gun's median, because a
            facet that faced up (lit, light) faces down after the flip and should now be in shadow, and vice versa.
  faces     flip, then split the sprite into FACES: 4-connected regions of non-outline pixels
            (outline = luma < OUTLINE_LUMA). In each face, fit the luma's vertical trend (least squares,
            luma = a + b*y) and mirror it: new luma = luma - 2*b*(y - mean y). The flip turned every face's
            light-to-dark ramp upside down; this turns the ramp back and leaves the detail (rivets, seams,
            stencils) where the flip put them. Each pixel then snaps to the gun's own colour of nearest luma
            within its kind (grey stays grey, warm stays warm). Left-right is untouched: a vertical flip keeps the
            light's left side on the left.
"""
import sys
from PIL import Image, ImageOps
OUTLINE_LUMA = 40
luma = lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
warm = lambda c: c[0] - c[2] > 30

def relight(src, mode='facets'):
    f = ImageOps.flip(src.convert('RGBA'))
    if mode == 'plain':
        return f
    W, H = f.size; fp = f.load(); out = f.copy(); op = out.load()
    if mode == 'segments':
        for x in range(W):
            y = 0
            while y < H:
                if fp[x, y][3] == 0 or luma(fp[x, y]) < OUTLINE_LUMA:
                    y += 1; continue
                y0 = y
                while y < H and fp[x, y][3] and luma(fp[x, y]) >= OUTLINE_LUMA:
                    y += 1
                seg = [fp[x, yy] for yy in range(y0, y)]
                for i, c in enumerate(reversed(seg)):
                    op[x, y0 + i] = c
        return out
    pal = sorted({fp[x, y][:3] for x in range(W) for y in range(H) if fp[x, y][3]}, key=luma)
    greys = [c for c in pal if not warm(c)]; warms = [c for c in pal if warm(c)]
    def snap(l, c):
        pool = (warms if warm(c) else greys) or pal
        return min(pool, key=lambda p: abs(luma(p) - l))
    allL = sorted(luma(fp[x, y]) for x in range(W) for y in range(H) if fp[x, y][3] and luma(fp[x, y]) >= OUTLINE_LUMA)
    MED = allL[len(allL) // 2]
    face = lambda x, y: 0 <= x < W and 0 <= y < H and fp[x, y][3] and luma(fp[x, y]) >= OUTLINE_LUMA
    seen = set(); faces = []
    for x0 in range(W):
        for y0 in range(H):
            if (x0, y0) in seen or not face(x0, y0):
                continue
            st = [(x0, y0)]; seen.add((x0, y0)); reg = []
            while st:
                x, y = st.pop(); reg.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if (nx, ny) not in seen and face(nx, ny):
                        seen.add((nx, ny)); st.append((nx, ny))
            ys = [y for _, y in reg]; my = sum(ys) / len(ys)
            vy = sum((y - my) ** 2 for y in ys)
            if len(reg) < 3 or vy == 0:
                continue
            ls = [luma(fp[x, y]) for x, y in reg]; ml = sum(ls) / len(ls)
            b = sum((y - my) * (l - ml) for (x, y), l in zip(reg, ls)) / vy
            shift = 2 * (MED - ml) if mode == 'facets' else 0     # facets: an up-facing (lit) face now faces down
            faces.append((reg, ls, b, my, shift))
    # keep the gun's overall brightness: mirroring face means about the median would otherwise darken it
    n = sum(len(r) for r, *_ in faces) or 1
    bias = sum(sh * len(r) for r, _, _, _, sh in faces) / n
    for reg, ls, b, my, shift in faces:
        for (x, y), l in zip(reg, ls):
            op[x, y] = snap(l - 2 * b * (y - my) + shift - bias, fp[x, y]) + (255,)
    return out

if __name__ == '__main__':
    mode = sys.argv[sys.argv.index('--mode') + 1] if '--mode' in sys.argv else 'facets'
    relight(Image.open(sys.argv[1]), mode).save(sys.argv[2])
