"""The Drum's lamps, split out of the painting (and its front layer, the plate
less the bay's recess, cut here too) so the game can switch them on:
for the plate and its front layer, an UNLIT copy (each lamp pixel darkened to
its housing) and a LAMPS layer (the lamp pixels alone, lit, transparent
elsewhere). Lamps are selected by colour inside tight boxes, one group at a
time, and a magenta preview is written to check the selection by eye.

  uv run --with numpy --with pillow python lamps.py <plate.png> <front.png> <out dir> <preview dir>
"""
import sys, os
import numpy as np
from PIL import Image

plate_p, front_p, out, prev = sys.argv[1:5]
P = np.asarray(Image.open(plate_p).convert("RGBA")).astype(int)
F = np.asarray(Image.open(front_p).convert("RGBA")).astype(int)


def sel(a, box, rule):
    x0, y0, x1, y1 = box
    m = np.zeros(a.shape[:2], bool)
    sub = a[y0:y1, x0:x1]
    r, g, b, al = sub[..., 0], sub[..., 1], sub[..., 2], sub[..., 3]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    m[y0:y1, x0:x1] = rule(r, g, b, lum) & (al > 0)
    return m


warm = lambda r, g, b, lum: (r - b > 40) & (r > 80)
bright_warm = lambda r, g, b, lum: (r > 170) & (r - b > 60) & (lum > 140)
door = lambda r, g, b, lum: (r - b > 40) & (r > 120)
red = lambda r, g, b, lum: ((r > 150) & (g < 120) & (b < 110)) | ((r > 200) & (lum > 150))
window = lambda r, g, b, lum: (r - b > 25) & (r > 70)

groups = {
    # the guide lights along the lips (the lamp row on each lip's edge)
    "guide_top": (P, (88, 203, 219, 206), warm),
    "guide_low": (P, (88, 284, 219, 286), warm),
    # the amber seam's lamp cores: down the groove and along both bands
    "seam": (P, (262, 44, 470, 440), bright_warm),
    # the inner door's lit edge
    "door": (P, (225, 202, 234, 285), door),
    "beacon": (P, (200, 99, 212, 113), red),
    "window": (P, (200, 392, 213, 410), window),
}
masks = {k: sel(a, box, rule) for k, (a, box, rule) in groups.items()}
# the lower lip's row 285 is in the front layer too
mf = sel(F, (88, 284, 219, 286), warm)
for k, m in masks.items():
    print(k, int(m.sum()), "px")
print("front guide_low", int(mf.sum()), "px")


def split(a, m):
    unlit = a.copy()
    lamps = np.zeros_like(a)
    lamps[m] = a[m]
    # a lamp switched off: its own colour, dark (the housing), a little toward grey
    c = a[m][:, :3].astype(float)
    grey = c.mean(-1, keepdims=True)
    d = (c * 0.55 + grey * 0.45) * 0.34
    unlit[m, :3] = np.clip(d, 0, 255).astype(int)
    return unlit, lamps


allp = np.zeros(P.shape[:2], bool)
for m in masks.values():
    allp |= m
pu, pl = split(P, allp)

# THE FRONT LAYER IS THE PLATE LESS THE BAY'S RECESS: everything that is hull --
# the lips, the frame round the opening, the lit strip beside it, the plating
# beyond -- is in front of your ship, so it is seen only inside the recess and
# goes behind the hull as it flies on past the bay's end. The recess, from the
# art: its rows are where the bay's dark interior runs (206..283); its right
# edge the first column past the back wall's door panel where the interior's dark
# tone stops, on the bay's middle rows (the frame's outline)
lum = (P[..., 0] * 299 + P[..., 1] * 587 + P[..., 2] * 114) // 1000
edges = []
for y in range(220, 271):
    x = 195
    while x < P.shape[1] and lum[y, x] in (19, 20, 7) and x < 260:
        x += 1
    edges.append(x)
RIGHT = int(np.median(edges))
TOP, BOT = 206, 284
recess = np.zeros(P.shape[:2], bool)
recess[TOP:BOT, :RIGHT] = True
print("recess: x < %d, rows %d..%d" % (RIGHT, TOP, BOT - 1))
F = P.copy()
F[recess] = 0
fu = pu.copy()
fu[recess] = 0
fl = pl.copy()
fl[recess] = 0
Image.fromarray(F.astype(np.uint8), "RGBA").save(os.path.join(out, "drum_front.png"))
os.makedirs(out, exist_ok=True)
Image.fromarray(pu.astype(np.uint8), "RGBA").save(os.path.join(out, "drum_plate_unlit.png"))
Image.fromarray(pl.astype(np.uint8), "RGBA").save(os.path.join(out, "drum_plate_lamps.png"))
Image.fromarray(fu.astype(np.uint8), "RGBA").save(os.path.join(out, "drum_front_unlit.png"))
Image.fromarray(fl.astype(np.uint8), "RGBA").save(os.path.join(out, "drum_front_lamps.png"))

# the check: every selected pixel magenta on the plate, 3x
os.makedirs(prev, exist_ok=True)
v = P.copy()
v[allp, :3] = (255, 0, 255)
bg = Image.new("RGBA", (P.shape[1], P.shape[0]), (9, 12, 19, 255))
bg.alpha_composite(Image.fromarray(v.astype(np.uint8), "RGBA"))
bg.crop((80, 40, 470, 460)).resize((390 * 2, 420 * 2), Image.NEAREST).save(os.path.join(prev, "lamps_magenta.png"))
u = Image.new("RGBA", (P.shape[1], P.shape[0]), (9, 12, 19, 255))
u.alpha_composite(Image.fromarray(pu.astype(np.uint8), "RGBA"))
u.crop((80, 40, 470, 460)).resize((390 * 2, 420 * 2), Image.NEAREST).save(os.path.join(prev, "lamps_unlit.png"))
# lamp extents for the game (per group, per lamp)
from scipy import ndimage
for k, m in masks.items():
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    boxes = [(o[1].start, o[0].start, o[1].stop - o[1].start, o[0].stop - o[0].start) for o in ndimage.find_objects(lab)]
    print(k, n, "lamps", boxes[:40])
