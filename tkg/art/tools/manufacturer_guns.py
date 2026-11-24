"""The unbranded guns drawn in a hull manufacturer's colours (Jon, Nov 23: pick B).

    uv run --with pillow --with numpy python tkg/art/tools/manufacturer_guns.py

Reads the installed plain guns (art/sprites/guns/<id>_<side>.png, through guns.json) and
writes, per manufacturer with a recipe here:
    art/sprites/guns/<manufacturer>/<id>_<side>.png   the same canvas and anchor as the plain gun
    art/sprites/guns/<manufacturer>/guns.json         {id: {side: {file, anchor}}}, read by ShipGun.gd
`ship_guns.py` runs this after every install, so a reinstalled plain gun takes its manufacturer
copies with it. The gun stays unbranded in play; only its picture on that manufacturer's hull changes.
Why: docs/why/ShipGun.md#manufacturer-drawn-yard-guns

The recipe, 0 generations: every pixel to the manufacturer's ramp at its own brightness, the
outline to the manufacturer's ink (a lit emitter to the furnace ramp on Solari), then the manufacturer's
detail at whole pixels, placed per gun (GEO) and re-shaded lit from above on both sides.
Korvan: a steel collar, a rivet line, a hazard stencil in the hull band's colour.
Solari: brass bands, a furnace vent with a dithered glow, soot at the muzzle, a warm lens.
"""
import io
import json
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GUNS = os.path.join(HERE, "..", "sprites", "guns")

luma = lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
hexc = lambda s: tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)

# Sampled from the finished hulls and each manufacturer's own guns, dark to light.
RAMP = {
    "korvan": [hexc(h) for h in ("#08080f", "#161523", "#262735", "#2e333a", "#3e404e", "#4e5360",
                                 "#656c78", "#7b828d", "#9ea5ae", "#c3cad2", "#e4e8ee")],
    "solari": [hexc(h) for h in ("#0a0402", "#1a0e08", "#2d1e17", "#3d2a1e", "#4c3626", "#614128",
                                 "#7a5530", "#8b673e", "#b99062", "#d9b67a", "#f2dca8")],
}
INK = {"korvan": hexc("#08080f"), "solari": hexc("#0a0402")}
# Solari's guns sit darker: soot, with brass only on the lit edge.
GAMMA = {"korvan": 1.0, "solari": 1.25}
FURNACE = [hexc(h) for h in ("#5c1e06", "#993a0d", "#ef9f27", "#ffd080", "#fff0c8")]
HAZARD = hexc("#daa559")   # the band on Korvan's own hull
STEEL = [hexc(h) for h in ("#e4e8ee", "#c3cad2", "#9ea5ae", "#6c727c", "#4e5360")]  # lit top to shadow
BRASS = [hexc(h) for h in ("#f2dca8", "#d9b67a", "#b99062", "#8b673e", "#583c26")]

# Where each detail goes, in the top sprite's pixels; the belly copy's rows are mirrored.
# barrel (x0, x1, y0, y1), collar x, bands [x], rivets (x0, x1, y), hazard (x, y, w, h),
# vent ([x], y0, y1), muzzle x or None, soot (x0, x1).
GEO = {
    "beam": dict(barrel=(31, 92, 6, 16), collar=31, bands=[41, 62, 83], rivets=(6, 28, 15),
                 hazard=(4, 10, 6, 3), vent=([19, 21, 23], 10, 13), muzzle=92, soot=(84, 91)),
    "slug": dict(barrel=(56, 91, 5, 14), collar=55, bands=[66, 76], rivets=(4, 52, 16),
                 hazard=(40, 13, 7, 3), vent=([36, 38, 40, 42], 6, 9), muzzle=None, soot=(84, 90)),
    "torch": dict(barrel=(46, 61, 4, 13), collar=45, bands=[50], rivets=(4, 43, 14),
                  hazard=(6, 9, 6, 3), vent=([28, 30, 32], 8, 11), muzzle=None, soot=(51, 54)),
}
MANUFACTURERS = ("korvan", "solari")


def ramp_at(ramp, l):
    """Colour at luma l along a ramp sorted dark to light, interpolated between stops."""
    ls = [luma(c) for c in ramp]
    if l <= ls[0]:
        return ramp[0]
    for i in range(1, len(ramp)):
        if l <= ls[i]:
            t = (l - ls[i - 1]) / max(ls[i] - ls[i - 1], 1e-6)
            return tuple(round(ramp[i - 1][k] + (ramp[i][k] - ramp[i - 1][k]) * t) for k in range(3)) + (255,)
    return ramp[-1]


def is_emitter(c):
    return luma(c) > 150 and c[0] - c[2] > 25


def solid(c):
    return c[3] and luma(c) >= 30


def remap(im, manufacturer):
    """Every pixel to the manufacturer's ramp at its own value; outline to the manufacturer's ink; a lit
    emitter (the torch's flame tip) to the furnace ramp on Solari, untouched on Korvan."""
    out = im.copy()
    p = out.load()
    for y in range(im.height):
        for x in range(im.width):
            c = p[x, y]
            if not c[3]:
                continue
            l = luma(c)
            if is_emitter(c):
                if manufacturer == "solari":
                    p[x, y] = ramp_at(FURNACE, l)
                continue
            if l < 22:
                p[x, y] = INK[manufacturer]
                continue
            p[x, y] = ramp_at(RAMP[manufacturer], 255 * (l / 255) ** GAMMA[manufacturer])
    return out


def extents(p, h, x, y0, y1):
    ys = [y for y in range(max(0, y0), min(h, y1 + 1)) if p[x, y][3]]
    return (min(ys), max(ys)) if ys else None


def band(p, h, x, win, ramp, ink, grow=1):
    """A raised band round the bore at column x: one px proud above and below, ink on its
    ends, the ramp down its face (lit top, shadow under)."""
    e = extents(p, h, x, *win)
    if not e:
        return
    y0, y1 = e[0] - grow, e[1] + grow
    for y in range(max(0, y0), min(h, y1 + 1)):
        if y in (y0, y1):
            p[x, y] = ink
        else:
            t = (y - y0 - 1) / max(y1 - y0 - 2, 1)
            p[x, y] = ramp[min(len(ramp) - 1, round(t * (len(ramp) - 1)))]


def korvan_detail(p, h, g, fy, win):
    """A steel clamp collar where the bores leave the housing, a rivet line, a hazard stencil."""
    for x in (g["collar"], g["collar"] + 1):
        band(p, h, x, win, STEEL, INK["korvan"])
    rx0, rx1, ry = g["rivets"]
    ry = fy(ry)
    for x in range(rx0, rx1 + 1, 3):
        if solid(p[x, ry]) and ry + 1 < h and solid(p[x, ry + 1]):
            p[x, ry] = hexc("#b7bcc4")
            p[x, ry + 1] = hexc("#1f1f2e")
    # the stripes run / on both sides
    hx, hy, hw, hh = g["hazard"]
    for j, y in enumerate(sorted(fy(y) for y in range(hy, hy + hh))):
        for x in range(hx, hx + hw):
            if solid(p[x, y]):
                p[x, y] = HAZARD if ((x - j) // 2) % 2 == 0 else hexc("#2e333a")


def solari_vent(p, h, g, fy):
    """Slits glowing core-hot, dark lips, the glow falling off dithered either side."""
    xs, ya, yb = g["vent"]
    ya, yb = sorted((fy(ya), fy(yb)))
    glow = []
    for x in xs:
        for y in range(ya, yb + 1):
            p[x, y] = FURNACE[3] if ya < y < yb else FURNACE[2]
        for y in (ya - 1, yb + 1):
            if 0 <= y < h and p[x, y][3]:
                p[x, y] = hexc("#1a0802")
        for nx in (x - 1, x + 1):
            if nx not in xs:
                glow += [(nx, y) for y in range(ya, yb + 1)]
    for x, y in glow:
        c = p[x, y]
        if solid(c):
            k = 0.55 if ya < y < yb else 0.3
            p[x, y] = tuple(round(c[i] + (FURNACE[1][i] - c[i]) * k) for i in range(3)) + (255,)


def solari_detail(p, h, g, fy, win):
    """Brass bands down the bore, soot at the business end, the vent, the laser's lens."""
    for x in g["bands"]:
        band(p, h, x, win, BRASS, INK["solari"])
    # the soot is a checker thinning backwards
    sx0, sx1 = g["soot"]
    for x in range(sx0, sx1 + 1):
        for y in range(h):
            c = p[x, y]
            if not solid(c) or is_emitter(c):
                continue
            strong = x >= (sx0 + sx1) // 2
            if (x + y) % 2 == 0 if strong else (x + y) % 4 == 0:
                p[x, y] = tuple(max(0, int(v * 0.55)) for v in c[:3]) + (255,)
    solari_vent(p, h, g, fy)
    if g["muzzle"] is not None:
        x = g["muzzle"]
        e = extents(p, h, x, *win)
        if e:
            for y in range(e[0] + 1, e[1]):
                p[x, y] = FURNACE[3] if e[0] + 1 < y < e[1] - 1 else FURNACE[2]


def manufacturer_gun(im, gid, side, manufacturer):
    """The plain gun `im` (on its `side`) in `manufacturer`'s colours with its detail drawn on."""
    out = remap(im, manufacturer)
    p = out.load()
    h = out.height
    g = GEO[gid]
    fy = (lambda y: y) if side == "top" else (lambda y: h - 1 - y)
    _bx0, _bx1, by0, by1 = g["barrel"]
    win = tuple(sorted((fy(by0), fy(by1))))
    (korvan_detail if manufacturer == "korvan" else solari_detail)(p, h, g, fy, win)
    return out


def install(plain=None):
    """Every manufacturer's copy of every unbranded gun in GEO that is installed plain."""
    if plain is None:
        plain = json.load(io.open(os.path.join(GUNS, "guns.json"), encoding="utf-8"))
    for manufacturer in MANUFACTURERS:
        od = os.path.join(GUNS, manufacturer)
        os.makedirs(od, exist_ok=True)
        table = {}
        for gid in sorted(GEO):
            for side, e in sorted(plain.get(gid, {}).items()):
                im = Image.open(os.path.join(GUNS, e["file"])).convert("RGBA")
                manufacturer_gun(im, gid, side, manufacturer).save(os.path.join(od, e["file"]))
                table.setdefault(gid, {})[side] = {"file": e["file"], "anchor": e["anchor"]}
        # a picture no longer made goes, with its import; the rest keep theirs
        made = {e["file"] for sides in table.values() for e in sides.values()}
        for f in os.listdir(od):
            png = f[:-len(".import")] if f.endswith(".import") else f
            if png.endswith(".png") and png not in made:
                os.remove(os.path.join(od, f))
        io.open(os.path.join(od, "guns.json"), "w", encoding="utf-8", newline="\n").write(
            json.dumps(table, indent=1, sort_keys=True) + "\n")
        print("wrote %s's %s to %s" % (manufacturer, "/".join(sorted(table)), os.path.normpath(od)))


if __name__ == "__main__":
    install()
