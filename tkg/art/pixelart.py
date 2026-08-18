"""
Three Kelvin — pixel art authoring.

Not procedural noise: every pixel is placed deliberately, the way you'd place it
in Aseprite. A disciplined palette, hand-specified shading ramps, ordered
dithering for gradients, panel seams with catch-light, and warm rim light from
the ship's own reactor.

Top-down, nose right, bilaterally symmetric — modules mount in mirrored pairs.
"""
from PIL import Image
import os

OUT = "/home/claude/art"
os.makedirs(OUT, exist_ok=True)

# ----------------------------------------------------------------- palette
# Disciplined ramps. Each surface gets 4 tones: shadow, base, light, highlight.
P = {
    # cold hull steel
    "steel_d": (19, 26, 35),
    "steel_s": (35, 45, 58),
    "steel_b": (52, 66, 84),
    "steel_l": (74, 92, 114),
    "steel_h": (108, 128, 152),
    "steel_rim": (146, 170, 196),
    "steel_m": (43, 55, 71),
    "steel_m2": (63, 79, 99),
    "steel_m3": (90, 110, 133),
    "grime_a": (48, 42, 33),
    "grime_b": (62, 50, 36),
    "rust_a": (92, 54, 30),
    "rust_b": (120, 72, 38),
    "deck_dark": (30, 39, 50),
    "st_hi": (128, 136, 158),
    # deep shadow / outline
    "ink": (11, 15, 22),
    "ink2": (16, 22, 31),
    # korvan brass-olive (weapon housings)
    "brass_d": (44, 34, 18),
    "brass_s": (74, 58, 32),
    "brass_b": (108, 84, 46),
    "brass_l": (146, 116, 64),
    "brass_h": (188, 154, 92),
    # cygnet cold blue (drone pods)
    "cyg_d": (24, 38, 54),
    "cyg_s": (40, 62, 86),
    "cyg_b": (58, 88, 118),
    "cyg_l": (92, 130, 164),
    "cyg_h": (140, 182, 212),
    # gun metal barrels
    "gun_d": (26, 30, 38),
    "gun_b": (58, 64, 76),
    "gun_l": (92, 100, 116),
    # heat / combustion
    "heat_d": (92, 40, 12),
    "heat_s": (150, 66, 20),
    "heat_b": (204, 100, 28),
    "heat_l": (255, 166, 60),
    "heat_h": (255, 220, 160),
    "heat_w": (255, 246, 226),
    # station warm interior
    "win_d": (138, 92, 32),
    "win_b": (255, 198, 108),
    "win_h": (255, 232, 184),
    # station grey-mauve hull
    "st_d": (30, 32, 42),
    "st_s": (46, 49, 62),
    "st_b": (66, 71, 88),
    "st_l": (92, 99, 118),
    "st_h": (128, 136, 158),
    # accents
    "hazard": (168, 135, 63),
    "glass_d": (22, 46, 64),
    "glass_b": (58, 107, 140),
    "glass_l": (142, 200, 230),
    "glass_h": (207, 232, 245),
    "warn_red": (214, 74, 58),
    "sig_teal": (79, 191, 168),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c if len(c) == 4 else (c[0], c[1], c[2], 255)

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.set(x + i, y + j, c)

    def hline(self, x, y, w, c):
        self.rect(x, y, w, 1, c)

    def vline(self, x, y, h, c):
        self.rect(x, y, 1, h, c)

    def dither(self, x, y, w, h, c, density):
        """Ordered 2x2 dither — pixel-art gradients without banding."""
        thr = [0.0, 0.5, 0.75, 0.25]
        for j in range(h):
            for i in range(w):
                if thr[(i % 2) + (j % 2) * 2] < density:
                    self.set(x + i, y + j, c)

    def rivets(self, x, y, n, step, c):
        for i in range(n):
            self.set(x + i * step, y, c)

    def mirror_y(self, axis):
        """Reflect the top half onto the bottom — bilateral symmetry for free."""
        for y in range(axis):
            for x in range(self.w):
                self.set(x, axis * 2 - y - 1, self.px[x, y])

    def save(self, name, scale=1):
        img = self.img
        if scale > 1:
            img = img.resize((self.w * scale, self.h * scale), Image.NEAREST)
        img.save(os.path.join(OUT, name))
        return img



def profile(weight, hw):
    """Half-height at each x along the hull — this is what makes a silhouette
    read as a ship instead of a brick. Aft is broad, waist narrows, nose tapers."""
    pts = {
        "light":  [(0.00, 0.62), (0.14, 0.86), (0.34, 1.00), (0.58, 0.94),
                   (0.78, 0.74), (0.92, 0.50), (1.00, 0.34)],
        "medium": [(0.00, 0.70), (0.10, 0.92), (0.30, 1.00), (0.55, 0.98),
                   (0.74, 0.84), (0.90, 0.60), (1.00, 0.42)],
        "heavy":  [(0.00, 0.78), (0.08, 0.96), (0.26, 1.00), (0.60, 1.00),
                   (0.80, 0.90), (0.93, 0.70), (1.00, 0.54)],
    }[weight]
    out = []
    for x in range(hw):
        f = x / max(1, hw - 1)
        for i in range(len(pts) - 1):
            if pts[i][0] <= f <= pts[i + 1][0]:
                t = (f - pts[i][0]) / max(1e-6, pts[i + 1][0] - pts[i][0])
                out.append(pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t)
                break
        else:
            out.append(pts[-1][1])
    return out


def tapered_hull(c, hx, axis, hw, hh, weight, seams):
    """Top-lit tapered hull, drawn column by column so the edge is a real curve."""
    prof = profile(weight, hw)
    half = hh // 2
    for i, f in enumerate(prof):
        x = hx + i
        top = axis - max(3, int(round(half * f)))
        h = (axis - top)
        # base body
        c.rect(x, top, 1, h, P["steel_b"])
        # top-lit bands
        c.set(x, top, P["steel_h"])
        c.rect(x, top + 1, 1, 3, P["steel_l"])
        if h > 10:
            c.rect(x, top + 4, 1, 3, P["steel_l"] if (i % 2 == 0) else P["steel_b"])
        # inner shadow toward the spine
        c.rect(x, axis - 4, 1, 4, P["steel_s"])
    # outline the silhouette edge
    for i, f in enumerate(prof):
        x = hx + i
        top = axis - max(3, int(round(half * f)))
        if i == 0:
            continue
        prev = axis - max(3, int(round(half * prof[i - 1])))
        if top != prev:
            lo, hi_ = sorted((top, prev))
            c.rect(x, lo, 1, max(1, hi_ - lo), P["ink"])
        c.set(x, top - 1, P["ink"])
    # panel seams follow the taper
    for k in range(1, seams):
        i = round(hw * k / seams)
        if i >= hw:
            continue
        top = axis - max(3, int(round(half * prof[i])))
        c.vline(hx + i, top + 1, axis - top, P["ink"])
        c.vline(hx + i + 1, top + 2, axis - top - 2, P["steel_l"])
    # rivets along the upper edge, following the curve
    for i in range(6, hw - 6, 9):
        top = axis - max(3, int(round(half * prof[i])))
        c.set(hx + i, top + 2, P["steel_d"])
    # aft transom
    c.rect(hx - 1, axis - int(half * prof[0]), 2, int(half * prof[0]), P["steel_rim"])
    # spine channel
    c.rect(hx + 4, axis - 5, hw - 10, 5, P["steel_s"])
    c.hline(hx + 4, axis - 5, hw - 10, P["ink2"])
    # weathering
    c.rect(hx + 14, axis - 12, 26, 2, (48, 42, 32))
    c.rect(hx + hw - 46, axis - 20, 16, 2, (54, 48, 36))

# --------------------------------------------------------------- hull plating
def plated_slab(c, x, y, w, h, ramp, seams=3, rim_light=True):
    """A lit metal slab: top-lit, dithered mid transition, seams with catch-light."""
    d, s, b, l, hi = (P[ramp + k] for k in ("_d", "_s", "_b", "_l", "_h"))
    c.rect(x, y, w, h, b)
    # top light band
    c.rect(x, y, w, 3, l)
    c.hline(x, y, w, hi)
    c.dither(x, y + 3, w, 4, l, 0.5)
    # bottom shadow band
    c.rect(x, y + h - 3, w, 3, s)
    c.hline(x, y + h - 1, w, d)
    c.dither(x, y + h - 6, w, 3, s, 0.45)
    # panel seams: dark line + light catch edge is what makes plating read
    for i in range(1, seams):
        sx = x + round(w * i / seams)
        c.vline(sx, y, h, P["ink"])
        c.vline(sx + 1, y, h, l)
    # rivet rows
    c.rivets(x + 4, y + 2, max(1, (w - 6) // 7), 7, d)
    c.rivets(x + 4, y + h - 3, max(1, (w - 6) // 7), 7, d)
    if rim_light:
        c.vline(x, y, h, P["steel_rim"])


def vent_strip(c, x, y, h, heat=0.0):
    """The heat instrument. Recessed housing, glowing core, bloom at high heat."""
    c.rect(x - 1, y - 1, 9, h + 2, P["ink"])
    c.rect(x, y, 7, h, P["ink2"])
    if heat <= 0.02:
        c.rect(x + 1, y + 1, 5, h - 2, (26, 33, 44))
        c.rect(x + 2, y + 3, 3, h - 6, (20, 26, 35))
        return
    glow = P["heat_s"] if heat < 0.45 else (P["heat_b"] if heat < 0.85 else P["heat_l"])
    core = P["heat_b"] if heat < 0.45 else (P["heat_l"] if heat < 0.85 else P["heat_h"])
    c.rect(x + 1, y + 1, 5, h - 2, glow)
    c.rect(x + 2, y + 3, 3, h - 6, core)
    if heat > 0.6:
        c.dither(x - 2, y - 2, 11, h + 4, glow, (heat - 0.6) * 0.55)
        c.dither(x - 1, y, 9, h, core, (heat - 0.6) * 0.35)
    if heat > 0.95:
        c.rect(x + 3, y + 5, 1, h - 10, P["heat_w"])


# ------------------------------------------------------------------ modules
def korvan_ordnance(c, x, y):
    """Mass driver: heavy housing, long barrel overhanging the nose."""
    c.rect(x, y, 34, 20, P["brass_b"])
    c.rect(x, y, 34, 4, P["brass_l"])
    c.hline(x, y, 34, P["brass_h"])
    c.rect(x, y + 16, 34, 4, P["brass_s"])
    c.hline(x, y + 19, 34, P["brass_d"])
    c.vline(x, y, 20, P["brass_h"])
    for i in range(3):
        c.rect(x + 6 + i * 10, y + 6, 4, 8, P["hazard"])
        c.rect(x + 6 + i * 10, y + 6, 4, 2, P["brass_h"])
    # barrel — deliberately too large for the mount
    c.rect(x + 34, y + 6, 62, 9, P["gun_b"])
    c.rect(x + 34, y + 6, 62, 2, P["gun_l"])
    c.hline(x + 34, y + 14, 62, P["gun_d"])
    c.rect(x + 62, y + 4, 8, 13, P["gun_b"])
    c.rect(x + 62, y + 4, 8, 2, P["gun_l"])
    c.rect(x + 92, y + 3, 8, 15, P["gun_b"])
    c.rect(x + 92, y + 3, 8, 2, P["gun_l"])
    c.rect(x + 98, y + 7, 4, 7, P["ink"])
    # sensor mast
    c.rect(x + 12, y - 14, 10, 15, P["steel_b"])
    c.rect(x + 12, y - 14, 10, 2, P["steel_h"])
    c.rect(x + 14, y - 20, 6, 7, P["steel_s"])
    c.set(x + 16, y - 21, P["glass_l"])


def korvan_autocannon(c, x, y):
    """Twin rapid-fire barrels — the cold, cheap workhorse."""
    c.rect(x, y, 22, 16, P["brass_b"])
    c.rect(x, y, 22, 3, P["brass_l"])
    c.hline(x, y, 22, P["brass_h"])
    c.rect(x, y + 13, 22, 3, P["brass_s"])
    c.rect(x + 4, y + 5, 6, 6, P["brass_d"])
    for k in (2, 10):
        c.rect(x + 22, y + k, 40, 4, P["gun_b"])
        c.hline(x + 22, y + k, 40, P["gun_l"])
        c.rect(x + 58, y + k - 1, 5, 6, P["gun_d"])


def cygnet_pod(c, x, y):
    """Drone cradle: thin frame, exposed conduit, antenna."""
    c.rect(x, y, 26, 18, P["cyg_b"])
    c.rect(x, y, 26, 3, P["cyg_l"])
    c.hline(x, y, 26, P["cyg_h"])
    c.rect(x, y + 15, 26, 3, P["cyg_s"])
    c.rect(x + 4, y + 6, 18, 7, P["cyg_d"])
    for i in range(4):
        c.rect(x + 5 + i * 4, y + 7, 2, 5, P["cyg_l"])
    # docked drone
    c.rect(x + 8, y - 10, 12, 10, P["cyg_s"])
    c.rect(x + 8, y - 10, 12, 2, P["cyg_h"])
    c.rect(x + 10, y - 7, 5, 4, P["glass_l"])
    c.rect(x + 5, y - 7, 3, 3, P["cyg_d"])
    c.rect(x + 20, y - 7, 3, 3, P["cyg_d"])
    c.vline(x + 24, y - 18, 8, P["steel_l"])
    c.set(x + 24, y - 19, P["sig_teal"])


# --------------------------------------------------------------------- hulls
def build_hull(weight, heat=0.35, modules=("ordnance", "autocannon", "cygnet")):
    """Top-down hull. Draw the top half, mirror it — guarantees symmetry."""
    spec = {
        "light": dict(w=230, h=120, hw=86, hh=44, vents=2, seams=2),
        "medium": dict(w=286, h=150, hw=122, hh=62, vents=3, seams=3),
        "heavy": dict(w=330, h=178, hw=150, hh=82, vents=4, seams=4),
    }[weight]
    c = Canvas(spec["w"], spec["h"])
    axis = spec["h"] // 2
    hx, hy = 44, axis - spec["hh"] // 2
    hw, hh = spec["hw"], spec["hh"]

    # --- engine block and thruster wash (aft, left)
    c.rect(hx - 16, axis - 20, 18, 40, P["steel_s"])
    c.rect(hx - 16, axis - 20, 18, 3, P["steel_l"])
    for off in (-16, 6):
        c.rect(hx - 26, axis + off, 12, 14, P["steel_d"])
        c.rect(hx - 26, axis + off, 12, 2, P["steel_b"])
        c.rect(hx - 33, axis + off + 3, 8, 8, P["heat_s"])
        c.rect(hx - 33, axis + off + 4, 8, 6, P["heat_b"])
        c.rect(hx - 39, axis + off + 5, 7, 4, P["heat_l"])
        c.rect(hx - 44, axis + off + 6, 5, 2, P["heat_h"])
        c.dither(hx - 52, axis + off + 5, 9, 4, P["heat_b"], 0.5)
        c.dither(hx - 60, axis + off + 6, 8, 2, P["heat_s"], 0.35)

    # --- main hull (tapered silhouette)
    tapered_hull(c, hx, axis, hw, hh, weight, spec["seams"])

    # --- bridge and nose
    bx = hx + hw
    c.rect(bx, hy + 6, 26, hh - 12, P["steel_b"])
    c.rect(bx, hy + 6, 26, 3, P["steel_l"])
    c.hline(bx, hy + 6, 26, P["steel_h"])
    c.rect(bx, hy + hh - 9, 26, 3, P["steel_s"])
    c.rect(bx + 7, axis - 9, 14, 18, P["ink"])
    c.rect(bx + 8, axis - 8, 12, 16, P["glass_b"])
    c.rect(bx + 8, axis - 8, 12, 4, P["glass_l"])
    c.rect(bx + 10, axis - 6, 4, 3, P["glass_h"])
    c.rect(bx + 26, axis - 12, 14, 24, P["steel_s"])
    c.rect(bx + 26, axis - 12, 14, 2, P["steel_l"])
    c.rect(bx + 40, axis - 6, 8, 12, P["steel_d"])
    c.rect(bx + 48, axis - 3, 5, 6, P["ink2"])

    # --- vents along the spine, height following the taper
    prof = profile(weight, hw)
    for i in range(spec["vents"]):
        vx = hx + 16 + round(i * (hw - 48) / max(1, spec["vents"] - 0.2))
        f = prof[min(hw - 1, vx - hx)]
        vh = max(8, int((spec["hh"] // 2) * f) - 8)
        vent_strip(c, vx, axis - vh, vh - 1, heat)

    # --- modules on the upper flank (mirrored automatically)
    mounts = [(hx + 24, hy - 22), (hx + 62, hy - 20), (hx + hw - 46, hy - 20)]
    for name, (mx, my) in zip(modules, mounts):
        if name == "ordnance":
            korvan_ordnance(c, mx, my)
        elif name == "autocannon":
            korvan_autocannon(c, mx, my + 4)
        elif name == "cygnet":
            cygnet_pod(c, mx, my + 2)

    c.mirror_y(axis)

    # --- asymmetric details AFTER mirroring (a fully symmetric ship reads dead)
    c.rect(hx + hw - 30, axis - 3, 12, 6, P["hazard"])
    c.rect(hx + 6, axis - 2, 8, 4, P["warn_red"])
    c.rect(hx + 40, axis - 1, 20, 2, (60, 52, 38))
    return c


def build_station(heat_windows=True):
    c = Canvas(200, 240)
    # main drum
    c.rect(54, 40, 92, 160, P["st_b"])
    c.rect(54, 40, 92, 5, P["st_l"])
    c.hline(54, 40, 92, P["st_h"])
    c.rect(54, 195, 92, 5, P["st_s"])
    c.vline(54, 40, 160, P["st_h"])
    c.dither(54, 45, 92, 6, P["st_l"], 0.45)
    c.dither(54, 188, 92, 6, P["st_s"], 0.4)
    for sx in (84, 116):
        c.vline(sx, 40, 160, P["st_d"])
        c.vline(sx + 1, 40, 160, P["st_l"])
    # ring bands
    for by in (78, 120, 162):
        c.hline(54, by, 92, P["st_d"])
        c.hline(54, by + 1, 92, P["st_l"])
    # lit windows with bloom — this is what makes it feel inhabited
    win = [(62, 54), (78, 54), (110, 54), (62, 90), (94, 90), (126, 90),
           (78, 132), (110, 132), (62, 174), (94, 174), (126, 174)]
    if heat_windows:
        for wx, wy in win:
            c.dither(wx - 3, wy - 2, 14, 12, P["win_h"], 0.18)
            c.rect(wx, wy, 9, 8, P["win_b"])
            c.rect(wx, wy, 9, 2, P["win_h"])
            c.rect(wx + 2, wy + 3, 3, 5, P["win_d"])  # silhouette inside
    # docking arms
    c.rect(14, 96, 40, 16, P["st_s"])
    c.rect(14, 96, 40, 3, P["st_l"])
    c.rect(2, 88, 14, 32, P["st_b"])
    c.rect(2, 88, 14, 3, P["st_h"])
    c.rect(146, 140, 38, 16, P["st_s"])
    c.rect(146, 140, 38, 3, P["st_l"])
    c.rect(184, 132, 14, 32, P["st_b"])
    c.rect(184, 132, 14, 3, P["st_h"])
    # spires
    c.rect(92, 20, 16, 20, P["st_s"])
    c.rect(92, 20, 16, 3, P["st_l"])
    c.rect(80, 8, 40, 12, P["st_b"])
    c.rect(80, 8, 40, 3, P["st_h"])
    c.rect(92, 200, 16, 18, P["st_s"])
    c.rect(80, 218, 40, 12, P["st_b"])
    c.rect(80, 227, 40, 3, P["st_d"])
    # beacons
    c.rect(116, 2, 5, 5, P["warn_red"])
    c.rect(78, 232, 5, 5, P["sig_teal"])
    c.rect(6, 84, 5, 4, P["heat_l"])
    return c


def build_sheet(images, pad=16, bg=(10, 14, 22, 255)):
    w = sum(im.width for im in images) + pad * (len(images) + 1)
    h = max(im.height for im in images) + pad * 2
    sheet = Image.new("RGBA", (w, h), bg)
    x = pad
    for im in images:
        sheet.alpha_composite(im, (x, (h - im.height) // 2))
        x += im.width + pad
    return sheet






# ============================================================ DETAIL TOOLKIT
# The things that separate "readable sprite" from "lush sprite": contact
# shadows, greebles, stencils, grilles, and grime with more than one tone.

DIGITS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
    "K": ["101", "101", "110", "101", "101"], "V": ["101", "101", "101", "101", "010"],
    "-": ["000", "000", "111", "000", "000"],
}


def stencil(c, x, y, text, col):
    """Tiny 3x5 block type — stencilled hull numbers read as 'real vehicle'."""
    cx = x
    for ch in text:
        rows = DIGITS.get(ch)
        if rows:
            for j, row in enumerate(rows):
                for i, bit in enumerate(row):
                    if bit == "1":
                        c.set(cx + i, y + j, col)
        cx += 4


def contact_shadow(c, x, y, w, spread=2):
    """Soft occlusion where a raised object meets the deck. Cheapest depth win
    available in 3/4 view — do this under every greeble, mount and mast."""
    for k in range(spread):
        d = 0.75 - k * 0.3
        c.dither(x - k, y + k, w + k * 2, 1, P["deck_dark"], d)


def grille(c, x, y, w, h, col_dark, col_light):
    """Slatted cover. Horizontal slats read as intake, vertical as exhaust."""
    c.rect(x, y, w, h, col_dark)
    for j in range(0, h, 2):
        c.hline(x, y + j, w, col_light)


def porthole(c, x, y, lit=False):
    c.rect(x, y, 5, 4, P["ink"])
    c.rect(x + 1, y + 1, 3, 2, P["glass_b"] if not lit else P["win_b"])
    c.set(x + 1, y + 1, P["glass_l"] if not lit else P["win_h"])


def hatch(c, x, y, w=8, h=6):
    c.rect(x, y, w, h, P["steel_m"])
    c.hline(x, y, w, P["steel_m3"])
    c.rect(x + 1, y + 1, w - 2, h - 2, P["steel_s"])
    c.set(x + w - 2, y + h - 2, P["steel_m3"])


def pipe_run(c, x, y, length, col=None):
    col = col or P["steel_m2"]
    c.rect(x, y, length, 3, col)
    c.hline(x, y, length, P["steel_m3"])
    for i in range(0, length, 7):
        c.rect(x + i, y - 1, 2, 5, P["steel_s"])


def railing(c, x, y, length):
    c.hline(x, y, length, P["steel_m3"])
    for i in range(0, length, 4):
        c.vline(x + i, y, 3, P["steel_m2"])


def crate(c, x, y, w=9, h=7, ramp="brass"):
    c.rect(x, y, w, h, P[ramp + "_b"])
    c.hline(x, y, w, P[ramp + "_l"])
    c.rect(x, y + h - 2, w, 2, P[ramp + "_s"])
    c.rect(x + 2, y + 2, w - 4, h - 4, P[ramp + "_s"])
    c.hline(x + 2, y + 2, w - 4, P[ramp + "_d"])


def grime_streak(c, x, y, length, warm=False):
    """Two-tone vertical streak running down a wall."""
    a = P["rust_a"] if warm else P["grime_a"]
    b = P["rust_b"] if warm else P["grime_b"]
    c.rect(x, y, 2, length, a)
    c.dither(x, y, 2, length, b, 0.5)
    c.dither(x - 1, y + length // 2, 4, length // 2, a, 0.3)


def scorch(c, x, y, w, h):
    c.dither(x, y, w, h, (26, 22, 20), 0.6)
    c.dither(x + 1, y + 1, w - 2, max(1, h - 2), (16, 14, 13), 0.5)


def greeble_field(c, x, y, w, h, seed=7):
    """Deterministic scatter of small engineered clutter across a deck region."""
    st = seed
    def nxt(n):
        nonlocal st
        st = (st * 1103515245 + 12345) & 0x7FFFFFFF
        return st % n
    for _ in range(max(2, (w * h) // 190)):
        gx = x + nxt(max(1, w - 10))
        gy = y + nxt(max(1, h - 8))
        kind = nxt(5)
        if kind == 0:
            hatch(c, gx, gy, 7, 5)
            contact_shadow(c, gx, gy + 5, 7, 1)
        elif kind == 1:
            pipe_run(c, gx, gy, 10 + nxt(8))
        elif kind == 2:
            c.rect(gx, gy, 4, 3, P["steel_m2"])
            c.hline(gx, gy, 4, P["steel_m3"])
        elif kind == 3:
            crate(c, gx, gy, 8, 6)
            contact_shadow(c, gx, gy + 6, 8, 1)
        else:
            c.rect(gx, gy, 3, 3, P["steel_s"])
            c.set(gx, gy, P["steel_m3"])




# ======================================================= DETAIL TOOLKIT II
# Cast shadows, surface texture, patched plating, conduits and running lights.
# This is the pass that takes a sprite from "clean" to "lived in".

def cast_shadow(c, x, y, w, length, skew=1):
    """Directional shadow thrown from a tall object across the deck toward the
    viewer. Light is top-of-frame, so shadows fall down and slightly right."""
    for j in range(length):
        d = 0.45 - (j / max(1, length)) * 0.34
        c.dither(x + j * skew, y + j, w, 1, P["deck_dark"], max(0.06, d))


def deck_tread(c, x, y, w, h):
    """Diamond-plate tread. Deliberately near-threshold: it must read as a
    surface quality at 1x, never as pattern. If you can see it clearly, it is
    too strong."""
    for j in range(0, h, 4):
        for i in range(0, w, 4):
            if ((i // 4) + (j // 4)) % 2 == 0:
                c.set(x + i, y + j, P["steel_m2"])


def patch_panel(c, x, y, w, h, warm=False):
    """A replaced hull plate: slightly off-tone, with weld beads around it.
    Nothing says 'this ship has a history' faster."""
    base = P["grime_b"] if warm else P["steel_m"]
    c.rect(x, y, w, h, base)
    c.hline(x, y, w, P["steel_m3"] if not warm else P["rust_b"])
    c.rect(x, y + h - 1, w, 1, P["ink2"])
    for i in range(x, x + w, 2):
        c.set(i, y - 1, P["steel_m3"])
        c.set(i + 1, y + h, P["steel_s"])


def conduit(c, x1, y1, x2, y2, col=None):
    """Cable run linking a module to the hull. Bends at right angles like real
    conduit, with clamps."""
    col = col or P["steel_m2"]
    if x2 != x1:
        step = 1 if x2 > x1 else -1
        for x in range(x1, x2, step):
            c.set(x, y1, col)
            c.set(x, y1 + 1, P["steel_s"])
        for x in range(x1, x2, 6 * step):
            c.set(x, y1 - 1, P["steel_m3"])
    if y2 != y1:
        step = 1 if y2 > y1 else -1
        for y in range(y1, y2, step):
            c.set(x2, y, col)
            c.set(x2 + 1, y, P["steel_s"])


def status_light(c, x, y, colour):
    c.set(x, y, colour)
    c.dither(x - 1, y - 1, 3, 3, colour, 0.3)


def radiator(c, x, y, w, h):
    """Finned heat exchanger on the wall — thematically perfect for this game."""
    c.rect(x, y, w, h, P["steel_s"])
    c.hline(x, y, w, P["steel_m3"])
    for i in range(x + 1, x + w - 1, 2):
        c.vline(i, y + 1, h - 2, P["steel_m2"])
        c.vline(i + 1, y + 1, h - 2, P["ink2"])


def floodlight(c, x, y, on=True):
    c.rect(x, y, 5, 4, P["steel_m2"])
    c.hline(x, y, 5, P["steel_m3"])
    if on:
        c.rect(x + 1, y + 4, 3, 2, P["win_b"])
        c.dither(x, y + 6, 5, 2, P["win_h"], 0.22)


def dish(c, x, y, r=5):
    c.rect(x, y - r, 2, r * 2, P["steel_s"])
    for j in range(r):
        w = r - j
        c.rect(x - w, y - r + j, w * 2 + 2, 1, P["steel_m2"] if j % 2 else P["steel_m3"])
    c.set(x, y, P["glass_l"])


def antenna(c, x, y, h):
    c.vline(x, y - h, h, P["steel_m2"])
    c.set(x, y - h, P["steel_m3"])
    for k in (h // 3, 2 * h // 3):
        c.rect(x - 2, y - k, 5, 1, P["steel_s"])


def chevrons(c, x, y, w, h, col=None):
    """Diagonal hazard striping."""
    col = col or P["hazard"]
    for j in range(h):
        for i in range(w):
            if ((i + j) // 2) % 3 == 0:
                c.set(x + i, y + j, col)


# ============================================================ 3/4 VIEW HULLS
# Camera tilted ~45 degrees: we see the top deck plus the near-side wall.
# Two-plane lighting (bright deck, darker wall) is what makes it read as solid
# rather than as a schematic. Symmetry across the horizontal axis is gone, so
# hardpoints live on the visible deck and each module is authored once.

SQUASH = 0.62          # vertical foreshortening of the deck
WALL = {"light": 13, "medium": 17, "heavy": 22}


def shade(c, ramp, k):
    return P[ramp + k]


def deck_profile(weight, hw):
    """Deck outline, foreshortened. Same silhouette language as top-down."""
    return [f * SQUASH for f in profile(weight, hw)]


def draw_34_hull(c, hx, deck_y, hw, weight, heat=0.35, modules=()):
    """deck_y is the vertical centre of the deck ellipse."""
    prof = deck_profile(weight, hw)
    wall = WALL[weight]
    half = {"light": 30, "medium": 42, "heavy": 54}[weight]

    # ---------------- near-side wall (drawn first, sits behind deck edge)
    for i, f in enumerate(prof):
        x = hx + i
        bot = deck_y + max(2, int(round(half * f)))
        # wall gets shorter toward the tapered nose
        wh = int(wall * (0.55 + 0.45 * f / max(0.01, max(prof))))
        c.rect(x, bot, 1, wh, shade(c, "steel", "_s"))
        c.rect(x, bot + wh - 3, 1, 3, shade(c, "steel", "_d"))
        c.set(x, bot + wh - 1, P["ink"])
    # wall: mid tone band so the plane has more than one step
    for i, f in enumerate(prof):
        x = hx + i
        bot = deck_y + max(2, int(round(half * f)))
        wh = int(wall * (0.55 + 0.45 * f / max(0.01, max(prof))))
        c.rect(x, bot + 1, 1, max(1, wh // 3), P["steel_m"])
    # wall panel lines and rivets
    seams = {"light": 2, "medium": 3, "heavy": 4}[weight]
    for k in range(1, seams):
        i = round(hw * k / seams)
        bot = deck_y + max(2, int(round(half * prof[i])))
        wh = int(wall * (0.55 + 0.45 * prof[i] / max(0.01, max(prof))))
        c.vline(hx + i, bot, wh - 1, P["ink2"])
        c.vline(hx + i + 1, bot + 1, max(1, wh - 3), P["steel_m2"])
    for i in range(8, hw - 8, 9):
        bot = deck_y + max(2, int(round(half * prof[i])))
        c.set(hx + i, bot + 3, shade(c, "steel", "_d"))
        if i % 18 == 8:
            c.set(hx + i, bot + 4, P["steel_m3"])
    # portholes, access hatches and docking collar along the wall
    for i in range(int(hw * 0.22), int(hw * 0.78), 16):
        bot = deck_y + max(2, int(round(half * prof[i])))
        if wall >= 15:
            porthole(c, hx + i, bot + 5, lit=(i // 16) % 3 == 0)
    ib = int(hw * 0.36)
    bot_h = deck_y + max(2, int(round(half * prof[ib])))
    hatch(c, hx + ib, bot_h + 4, 10, min(8, wall - 6))
    # two-tone grime streaks running down the wall
    for i, warm in ((int(hw * 0.28), False), (int(hw * 0.52), True),
                    (int(hw * 0.71), False)):
        bot = deck_y + max(2, int(round(half * prof[i])))
        grime_streak(c, hx + i, bot + 2, max(4, wall - 5), warm=warm)
    # radiator fins and a welded patch on the wall
    ir = int(hw * 0.60)
    bot_r = deck_y + max(2, int(round(half * prof[ir])))
    radiator(c, hx + ir, bot_r + 3, 18, max(5, wall - 7))
    ip = int(hw * 0.46)
    bot_p = deck_y + max(2, int(round(half * prof[ip])))
    patch_panel(c, hx + ip, bot_p + 4, 12, max(4, wall - 9), warm=True)
    # running lights along the wall lip
    for frac, col in ((0.18, P["warn_red"]), (0.50, P["steel_rim"]),
                      (0.84, P["sig_teal"])):
        ii = int(hw * frac)
        bot_l = deck_y + max(2, int(round(half * prof[ii])))
        status_light(c, hx + ii, bot_l + 1, col)
    # scorch near the engines
    scorch(c, hx + 4, deck_y + int(half * 0.7), 12, max(3, wall - 8))

    # ---------------- top deck (five tonal steps across the plane)
    for i, f in enumerate(prof):
        x = hx + i
        top = deck_y - max(2, int(round(half * f)))
        bot = deck_y + max(2, int(round(half * f)))
        h = bot - top
        c.rect(x, top, 1, h, P["steel_m"])
        c.rect(x, top + 1, 1, max(2, h // 4), P["steel_l"])
        c.rect(x, top + 1 + h // 4, 1, max(1, h // 5), P["steel_m3"])
        c.dither(x, top + 1 + h // 4 + h // 5, 1, 3, P["steel_m2"], 0.55)
        c.rect(x, bot - max(2, h // 5), 1, max(2, h // 5), P["steel_b"])
        c.set(x, top, shade(c, "steel", "_h"))
        # bright lip where deck meets wall — the key silhouette read
        c.set(x, bot - 1, shade(c, "steel", "_rim"))
        c.set(x, bot - 2, P["steel_m3"])
    # deck outline plus a 1px inner occlusion rim
    for i, f in enumerate(prof):
        x = hx + i
        top = deck_y - max(2, int(round(half * f)))
        c.set(x, top - 1, P["ink"])
        c.set(x, top, P["steel_m3"])

    # deck seams follow the ellipse
    for k in range(1, seams):
        i = round(hw * k / seams)
        top = deck_y - max(2, int(round(half * prof[i])))
        bot = deck_y + max(2, int(round(half * prof[i])))
        c.vline(hx + i, top + 1, bot - top - 2, P["ink"])
        c.vline(hx + i + 1, top + 2, bot - top - 4, shade(c, "steel", "_l"))

    # ---------------- deck detail pass
    mid = deck_y + 2
    # tread only along the working band amidships — the fore deck stays clean
    deck_tread(c, hx + 12, deck_y - int(half * 0.18), int(hw * 0.34), int(half * 0.50))
    patch_panel(c, hx + int(hw * 0.44), deck_y - int(half * 0.60), 16, 9)
    # central walkway with tread marks and railings
    c.rect(hx + 8, mid - 3, hw - 30, 7, P["steel_m2"])
    c.hline(hx + 8, mid - 3, hw - 30, P["steel_m3"])
    c.hline(hx + 8, mid + 3, hw - 30, P["steel_s"])
    for i in range(hx + 10, hx + hw - 24, 5):
        c.vline(i, mid - 2, 5, P["steel_m"])
    railing(c, hx + 14, deck_y - int(half * 0.55), min(46, hw // 3))
    # greeble clutter on the fore and aft deck
    greeble_field(c, hx + 8, deck_y - int(half * 0.50), hw // 6, int(half * 0.36), seed=11)
    # one solid sensor block instead of thin scattered hardware
    sx, sy = hx + int(hw * 0.64), deck_y - int(half * 0.42)
    two_plane_box(c, sx, sy, 16, 7, 7, "steel", rivet=False)
    grille(c, sx + 2, sy + 2, 11, 4, P["ink2"], P["steel_m3"])
    antenna(c, sx + 14, sy, 13)
    # cargo pair on the clean fore deck — one focal cluster, not scatter
    cx0 = hx + int(hw * 0.78)
    cy0 = deck_y - int(half * 0.10)
    cast_shadow(c, cx0 + 2, cy0 + 10, 13, 5)
    crate(c, cx0, cy0, 13, 10, "brass")
    crate(c, cx0 + 14, cy0 + 3, 10, 7, "steel")
    # three status lights total — restraint keeps them readable as signals
    status_light(c, hx + int(hw * 0.58), deck_y + int(half * 0.34), P["sig_teal"])
    status_light(c, hx + int(hw * 0.30), deck_y + int(half * 0.46), P["warn_red"])
    # stencilled hull number on the clear fore deck, hazard block aft
    stencil(c, hx + int(hw * 0.70), deck_y - int(half * 0.34), "KV-7", P["steel_m3"])
    stencil(c, hx + 6, deck_y + int(half * 0.34), "01", P["hazard"])

    # ---------------- engines on the aft wall
    for off in (-9, 5):
        ey = deck_y + off
        c.rect(hx - 13, ey, 14, 11, shade(c, "steel", "_s"))
        c.rect(hx - 13, ey, 14, 2, shade(c, "steel", "_l"))
        c.rect(hx - 13, ey + 9, 14, 2, P["ink2"])
        for k in range(hx - 12, hx - 1, 3):
            c.vline(k, ey + 3, 5, P["steel_m"])
        c.rect(hx - 6, ey + 2, 5, 7, P["steel_m2"])
        c.rect(hx - 20, ey + 2, 8, 7, P["heat_s"])
        c.rect(hx - 20, ey + 3, 8, 5, P["heat_b"])
        c.rect(hx - 26, ey + 3, 7, 4, P["heat_l"])
        c.rect(hx - 31, ey + 4, 5, 2, P["heat_h"])
        c.dither(hx - 40, ey + 3, 10, 4, P["heat_b"], 0.5)
        c.dither(hx - 50, ey + 4, 10, 2, P["heat_s"], 0.3)

    # ---------------- bridge: a raised block, so it needs its own two planes
    bx = hx + hw - 34
    bw, btop, bwall = 34, 13, 14
    by = deck_y - 8
    c.rect(bx, by, bw, btop, shade(c, "steel", "_b"))
    c.rect(bx, by, bw, 5, shade(c, "steel", "_l"))
    c.hline(bx, by, bw, shade(c, "steel", "_h"))
    c.rect(bx, by + btop, bw, bwall, shade(c, "steel", "_s"))
    c.hline(bx, by + btop, bw, shade(c, "steel", "_rim"))
    c.rect(bx, by + btop + bwall - 2, bw, 2, shade(c, "steel", "_d"))
    # canopy on the bridge's front wall
    c.rect(bx + 9, by + btop + 3, 18, 8, P["ink"])
    c.rect(bx + 10, by + btop + 4, 16, 6, P["glass_b"])
    c.rect(bx + 10, by + btop + 4, 16, 2, P["glass_l"])
    c.rect(bx + 12, by + btop + 5, 5, 2, P["glass_h"])
    c.rivets(bx + 4, by + 3, 5, 6, shade(c, "steel", "_d"))
    # bridge greebles + docking probe on the nose
    c.rect(bx + 2, by + 2, 5, 4, P["steel_m2"])
    c.set(bx + 3, by + 3, P["glass_l"])
    status_light(c, bx + bw - 4, by + 2, P["sig_teal"])
    cast_shadow(c, bx + 3, by + btop + bwall, bw - 4, 6)

    # ---------------- vents: slits on the deck, foreshortened wide
    nv = {"light": 2, "medium": 3, "heavy": 4}[weight]
    for i in range(nv):
        vx = hx + 18 + round(i * (hw - 62) / max(1, nv - 0.2))
        f = prof[min(hw - 1, vx - hx)]
        vh = max(6, int(half * f * 0.55))
        deck_vent(c, vx, deck_y - vh // 2 + 4, vh, heat)

    # ---------------- deck modules (each a small two-plane box)
    # Painter's order: far side (higher on screen) first, so near mounts occlude.
    for name, (mx, my) in sorted(modules, key=lambda m: m[1][1]):
        # short conduit stub from the mount into the deck — sells modularity
        conduit(c, hx + mx + 3, deck_y + my + 22, hx + mx + 3, deck_y + my + 30)
        if name == "ordnance":
            deck_ordnance(c, hx + mx, deck_y + my)
        elif name == "autocannon":
            deck_autocannon(c, hx + mx, deck_y + my)
        elif name == "cygnet":
            deck_pod(c, hx + mx, deck_y + my)

    # asymmetric details last — a perfectly regular ship reads dead
    c.rect(hx + 16, deck_y + 2, 10, 3, P["warn_red"])
    c.rect(hx + hw // 2, deck_y - 4, 14, 3, P["hazard"])
    c.rect(hx + hw // 2 + 22, deck_y + 5, 8, 2, (58, 50, 38))


def deck_vent(c, x, y, h, heat):
    w = 14
    # raised housing with its own lip, then the recess
    c.rect(x - 2, y - 2, w + 4, h + 5, P["steel_m2"])
    c.hline(x - 2, y - 2, w + 4, P["steel_m3"])
    c.rect(x - 2, y + h + 1, w + 4, 2, P["steel_s"])
    contact_shadow(c, x - 3, y + h + 3, w + 6, 2)
    c.rect(x - 1, y - 1, w + 2, h + 2, P["ink"])
    c.rect(x, y, w, h, P["ink2"])
    if heat <= 0.02:
        c.rect(x + 1, y + 1, w - 2, h - 2, (28, 35, 46))
        for i in range(x + 1, x + w - 1, 3):
            c.vline(i, y + 1, h - 2, (18, 24, 32))
        return
    glow = P["heat_s"] if heat < 0.45 else (P["heat_b"] if heat < 0.85 else P["heat_l"])
    core = P["heat_b"] if heat < 0.45 else (P["heat_l"] if heat < 0.85 else P["heat_h"])
    c.rect(x + 1, y + 1, w - 2, h - 2, glow)
    c.rect(x + 2, y + 2, w - 4, max(1, h - 4), core)
    # slats across the glow read as a real grille
    for i in range(x + 1, x + w - 1, 3):
        c.vline(i, y + 1, h - 2, P["heat_d"])
    if heat > 0.6:
        c.dither(x - 3, y - 2, w + 6, h + 4, core, (heat - 0.6) * 0.6)
    if heat > 0.95:
        c.rect(x + 3, y + 3, w - 6, max(1, h - 6), P["heat_w"])


def two_plane_box(c, x, y, w, top_h, wall_h, ramp, rivet=True):
    """A raised object on the deck: lit top face, darker front wall, contact
    shadow beneath, and a directional shadow thrown onto the deck."""
    cast_shadow(c, x + 2, y + top_h + wall_h, w, min(7, wall_h))
    contact_shadow(c, x - 1, y + top_h + wall_h - 1, w + 2, 3)
    c.rect(x, y, w, top_h, shade(c, ramp, "_b"))
    c.rect(x, y, w, max(2, top_h // 2), shade(c, ramp, "_l"))
    c.hline(x, y, w, shade(c, ramp, "_h"))
    c.dither(x, y + top_h // 2, w, 2, shade(c, ramp, "_l"), 0.5)
    c.rect(x, y + top_h, w, wall_h, shade(c, ramp, "_s"))
    c.rect(x, y + top_h + 1, w, max(1, wall_h // 3), shade(c, ramp, "_b"))
    c.rect(x, y + top_h + wall_h - 2, w, 2, shade(c, ramp, "_d"))
    c.hline(x, y + top_h, w, shade(c, ramp, "_h"))
    c.set(x, y + top_h + wall_h - 1, P["ink"])
    c.vline(x, y, top_h + wall_h - 1, shade(c, ramp, "_l"))
    if rivet:
        c.rivets(x + 3, y + 2, max(1, (w - 5) // 5), 5, shade(c, ramp, "_d"))


def deck_ordnance(c, x, y):
    two_plane_box(c, x, y, 32, 10, 12, "brass")
    for i in range(3):
        c.rect(x + 5 + i * 9, y + 12, 4, 7, P["hazard"])
        c.set(x + 5 + i * 9, y + 12, P["brass_h"])
    grille(c, x + 22, y + 2, 8, 6, P["brass_d"], P["brass_l"])
    stencil(c, x + 4, y + 3, "88", P["brass_h"])
    pipe_run(c, x + 2, y + 20, 16, P["brass_s"])
    # barrel runs along the deck toward the nose, slightly lower = further away
    c.rect(x + 32, y + 4, 54, 7, P["gun_b"])
    c.rect(x + 32, y + 4, 54, 2, P["gun_l"])
    c.hline(x + 32, y + 10, 54, P["gun_d"])
    c.rect(x + 58, y + 2, 7, 11, P["gun_b"])
    c.rect(x + 58, y + 2, 7, 2, P["gun_l"])
    c.rect(x + 84, y + 2, 7, 11, P["gun_b"])
    c.rect(x + 88, y + 5, 4, 5, P["ink"])
    # mast
    contact_shadow(c, x + 9, y, 10, 2)
    c.rect(x + 10, y - 12, 8, 13, P["steel_s"])
    c.rect(x + 10, y - 12, 8, 2, P["steel_l"])
    c.rect(x + 12, y - 17, 4, 6, P["steel_b"])
    c.set(x + 13, y - 18, P["glass_l"])


def deck_autocannon(c, x, y):
    two_plane_box(c, x, y, 20, 8, 9, "brass")
    grille(c, x + 3, y + 2, 6, 4, P["brass_d"], P["brass_l"])
    c.rect(x + 12, y + 10, 6, 5, P["brass_d"])
    for k in (1, 6):
        c.rect(x + 20, y + k, 34, 3, P["gun_b"])
        c.hline(x + 20, y + k, 34, P["gun_l"])
        c.rect(x + 50, y + k - 1, 5, 5, P["gun_d"])


def deck_pod(c, x, y):
    two_plane_box(c, x, y, 24, 9, 10, "cyg")
    for i in range(4):
        c.rect(x + 3 + i * 5, y + 10, 3, 6, P["cyg_l"])
        c.set(x + 3 + i * 5, y + 10, P["cyg_h"])
    grille(c, x + 4, y + 2, 16, 5, P["cyg_d"], P["cyg_l"])
    # docked drone sitting on top
    c.rect(x + 6, y - 9, 12, 6, P["cyg_s"])
    c.rect(x + 6, y - 9, 12, 2, P["cyg_h"])
    c.rect(x + 9, y - 6, 5, 3, P["glass_l"])
    c.rect(x + 21, y - 15, 2, 8, P["steel_l"])
    c.set(x + 21, y - 16, P["sig_teal"])


def build_hull_34(weight, heat=0.35):
    spec = {
        "light": dict(w=222, h=128, hw=100),
        "medium": dict(w=262, h=156, hw=132),
        "heavy": dict(w=300, h=188, hw=164),
    }[weight]
    c = Canvas(spec["w"], spec["h"])
    hx = 56
    deck_y = spec["h"] // 2 - 6
    mods = {
        "light": [("autocannon", (18, -28)), ("cygnet", (48, -8))],
        "medium": [("ordnance", (14, -36)), ("cygnet", (58, -32)),
                   ("autocannon", (20, -10))],
        "heavy": [("ordnance", (12, -46)), ("autocannon", (62, -44)),
                  ("ordnance", (18, -16)), ("cygnet", (70, -12))],
    }[weight]
    draw_34_hull(c, hx, deck_y, spec["hw"], weight, heat, mods)
    return c


if __name__ == "__main__":
    for label, heat in (("cold", 0.0), ("warm", 0.5), ("overheat", 1.0)):
        c = build_hull_34("medium", heat=heat)
        c.save(f"hull_medium_{label}.png")
        c.save(f"hull_medium_{label}@3x.png", scale=3)

    for weight in ("light", "medium", "heavy"):
        c = build_hull_34(weight, heat=0.4)
        c.save(f"hull_{weight}.png")
        c.save(f"hull_{weight}@3x.png", scale=3)

    st = build_station()
    st.save("station.png")
    st.save("station@3x.png", scale=3)

    # Preview sheets
    hulls = [Image.open(f"{OUT}/hull_{w}.png") for w in ("light", "medium", "heavy")]
    build_sheet([h.resize((h.width * 2, h.height * 2), Image.NEAREST) for h in hulls]) \
        .save(f"{OUT}/sheet_hulls@2x.png")

    heats = [Image.open(f"{OUT}/hull_medium_{s}.png") for s in ("cold", "warm", "overheat")]
    build_sheet([h.resize((h.width * 2, h.height * 2), Image.NEAREST) for h in heats]) \
        .save(f"{OUT}/sheet_heat@2x.png")

    scene = Image.open(f"{OUT}/hull_medium_warm.png")
    stat = Image.open(f"{OUT}/station.png")
    build_sheet([scene.resize((scene.width * 2, scene.height * 2), Image.NEAREST),
                 stat.resize((stat.width * 2, stat.height * 2), Image.NEAREST)]) \
        .save(f"{OUT}/sheet_encounter@2x.png")

    print("wrote:", sorted(os.listdir(OUT)))
