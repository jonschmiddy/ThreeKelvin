"""Install Jon's five laboratories into the game, lit the way Five Labs, Lit lit them.

    python tools/lab_install.py            # install (needs numpy and Pillow)
    python tools/lab_install.py --check    # is the game's copy what the stage holds?

THE SOURCE IS THE STAGE. `tools/room_stage/lab/final/<level>.png` are the five
pictures as Jon passed them -- one painted lab per development level, each a
PixelLab take doubled to the room and edited by hand -- and
`tools/room_stage/lab/labs.json` is everything the prototype knew about them:
where each light hangs and what shape it throws, which pixels glow on their
own, where the recipe rows sit, what the big screen does. Nothing here decides
anything about a lab; it only works out ahead of time what the game would be
too slow to work out itself. Each lab's CLOCK -- when a lamp strikes, how it
breathes, when a fault stutters -- is code, and lives in `LabScene.gd`.

THE PROTOTYPE IS THE REFERENCE. Five Labs, Lit (the artifact Jon judged these
on) lights a picture like this, and every function below names the one it
ports:

  field()   a lamp's pool over the light-map cells: a soft core and a squared
            falloff, the shop's `addLight` shape. `pt` is a point, `line` a
            horizontal run, and `down` makes it fall mostly downward
  cone()    a lamp that throws a cone: a span that widens as the light falls
            and fades over its reach, with a thin glow above the fixture
  test()    which pixels glow on their own (an emitter), by colour. CYAN MEANS
            CYAN: green and blue level and red well under both -- the pale
            periwinkle the pictures edge their furniture with passed the old
            test and lit every table leg

WHAT IT WRITES, all of it under `tkg/art/sprites/station/lab/`, which this tool
owns (anything it did not write is removed, apart from Godot's own `.import`
files beside the pictures):

  lab_<level>.png        the picture, as it is on the stage
  lab_<level>_light.lmap every light's field, a GW x GH band per two lights,
                         the high then low bytes of each as 16-bit fixed point
                         over 0..SCALE: (A.hi, A.lo, B.hi, B.lo)
  lab_<level>_own.lmap   per room pixel: R the emitter it belongs to (0 none,
                         else its index + 1), G what the lab's life may draw
                         over it (MASK below)
  labs.json              each lab's lights, emitters, windows, and what its
                         screen does, as LabScene reads them

An `.lmap` is a PNG that Godot does not import -- its colours are data, and the
importer would treat them as a picture -- read off disk like the shop's light.
"""

import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, "tools", "room_stage", "lab")
SOURCE = os.path.join(STAGE, "labs.json")
OUT = os.path.join(ROOT, "tkg", "art", "sprites", "station", "lab")
OUT_JSON = os.path.join(OUT, "labs.json")
LEVELS = ["unclaimed", "outpost", "settlement", "city", "capital"]

# The room, and the light map: one cell per picture pixel (2x2 room pixels).
W, H, GK = 740, 431, 2
GW, GH = 370, 216
# A field's range. The brightest cell a light can make is 1.4 (`field`'s core).
SCALE = 2.0

# What the lab's life may draw over, bit by bit in `_own`'s G channel.
MASK = {
	"tank": 1,     # the tanks' liquid: bubbles rise through it
	"flask": 2,    # a flask's liquid: it fizzes
	"monitor": 4,  # the small monitor's screen: its animation types on it
	"glass": 8,    # the big screen's glass: the rim light runs round it
}


def _sha(path):
	with open(path, "rb") as f:
		return hashlib.sha256(f.read()).hexdigest()


def _sources(doc):
	"""Every file the install is made from, with its hash -- this tool included,
	so a change to how a lab is baked is a change the gate notices."""
	files = {"labs.json": SOURCE, "lab_install.py": os.path.abspath(__file__)}
	for lv in LEVELS:
		files[doc[lv]["picture"]] = os.path.join(STAGE, doc[lv]["picture"])
	return {k: _sha(v) for k, v in sorted(files.items())}


# ------------------------------------------------------------------ the light

def field(kind, a, b, c, rad, down):
	"""A lamp's pool (Five Labs `field`)."""
	import numpy as np
	gy, gx = np.mgrid[0:GH, 0:GW]
	cy = (gy * GK + 1).astype(np.float64)
	cx = (gx * GK + 1).astype(np.float64)
	if kind == "line":
		dx = np.where(cx < a, a - cx, np.where(cx > b, cx - b, 0.0))
		dy = cy - c
	else:
		dx = cx - a
		dy = cy - b
	if down:
		dy = np.where(dy < 0, dy * 2.6, dy)
	d = np.sqrt(dx * dx + dy * dy)
	core = max(4.0, rad * 0.5)
	w = (1.0 - d / rad) ** 2
	k = d / core
	return np.where(d >= rad, 0.0, 1.4 * w / (1.0 + k * k))


def cone(x0, x1, y, reach, spread):
	"""A lamp that throws a cone (Five Labs `cone`)."""
	import numpy as np
	gy, gx = np.mgrid[0:GH, 0:GW]
	cy = (gy * GK + 1).astype(np.float64)
	cx = (gx * GK + 1).astype(np.float64)
	dy = cy - y
	v = np.zeros((GH, GW))
	above = (dy < 0) & (dy > -8) & (cx >= x0) & (cx <= x1)
	v = np.where(above, 0.3 * (1.0 + dy / 8.0), v)
	e = dy * spread
	dx = np.where(cx < x0 - e, x0 - e - cx, np.where(cx > x1 + e, cx - x1 - e, 0.0))
	vert = np.clip(1.0 - dy / reach, 0.0, None)
	below = (dy >= 0) & (dy < reach) & (dx < 26)
	return np.where(below, 1.35 * vert ** 1.4 * (1.0 - dx / 26.0), v)


def build(spec):
	"""Five Labs `build`: a spec is ["cone", x0, x1, y, reach, spread] or
	[kind, a, b, c, rad, down]."""
	if spec[0] == "cone":
		return cone(*spec[1:6])
	return field(*spec[0:6])


def test(kind, rgb, mn=None, cols=None):
	"""Which pixels glow on their own (Five Labs `test`), over an HxWx3 array."""
	import numpy as np
	r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
	mx = np.maximum(np.maximum(r, g), b)
	lo = np.minimum(np.minimum(r, g), b)
	lum = 0.299 * r + 0.587 * g + 0.114 * b
	if kind == "list":
		hit = np.zeros(r.shape, bool)
		for c in cols:
			hit |= (np.abs(r - c[0]) + np.abs(g - c[1]) + np.abs(b - c[2])) < 6
		return hit
	if kind == "cyan":
		return (b > 150) & (g > 150) & (r < 175) & (mx - lo > 45) & (np.abs(g - b) < 40) & (np.minimum(g, b) - r > 50)
	if kind == "green":
		return (g > 150) & (g > r + 15) & (g > b + 50)
	if kind == "red":
		return (r > 160) & (r > g + 60) & (r > b + 60)
	if kind == "warm":
		return (lum > (mn or 180)) & (r >= b)
	return lum > (mn or 180)


def near(rgb, cols, tol):
	"""Pixels within `tol` (a summed channel difference, strictly under) of any colour."""
	import numpy as np
	r, g, b = (rgb[..., i].astype(np.int32) for i in range(3))
	hit = np.zeros(r.shape, bool)
	for c in cols:
		hit |= (np.abs(r - c[0]) + np.abs(g - c[1]) + np.abs(b - c[2])) < tol
	return hit


def art_box(x0, x1, top, bottom):
	"""A picture-pixel box, inclusive, as room-pixel slices (y, x)."""
	return slice(2 * top - 16, 2 * bottom - 16 + 2), slice(max(0, 2 * x0 - 30), 2 * x1 - 30 + 2)


def bake(lv, e):
	"""One lab: its picture, light file and emitter file, as arrays, and its entry."""
	import numpy as np
	from PIL import Image
	pic = np.array(Image.open(os.path.join(STAGE, e["picture"])).convert("RGB"))
	assert pic.shape == (H, W, 3), "%s is %s, not %dx%d" % (e["picture"], pic.shape, W, H)

	# THE LIGHTS: a band of two fields each, 16-bit.
	lights = e["lights"]
	nb = (len(lights) + 1) // 2
	band = np.zeros((GH * nb, GW, 4), np.uint8)
	for i, l in enumerate(lights):
		q = np.round(np.clip(build(l["s"]), 0.0, SCALE) / SCALE * 65535.0).astype(np.uint32)
		k, ch = i // 2, (i % 2) * 2
		band[k * GH:(k + 1) * GH, :, ch] = (q >> 8).astype(np.uint8)
		band[k * GH:(k + 1) * GH, :, ch + 1] = (q & 255).astype(np.uint8)

	# THE EMITTERS, first claim wins, in the prototype's order.
	owners = []
	for em in e["emit"]:
		if em["o"] not in owners:
			owners.append(em["o"])
	own = np.zeros((H, W), np.uint8)
	for em in e["emit"]:
		x0, y0, x1, y1 = em["box"]
		ys = slice(max(0, y0), min(H - 1, y1) + 1)
		xs = slice(max(0, x0), min(W - 1, x1) + 1)
		hit = test(em["k"], pic[ys, xs], em.get("min"), em.get("cols"))
		free = own[ys, xs] == 0
		own[ys, xs] = np.where(hit & free, owners.index(em["o"]) + 1, own[ys, xs])

	# WHAT THE LIFE MAY DRAW OVER.
	mask = np.zeros((H, W), np.uint8)
	bub = e.get("bubbles")
	if bub:
		mask |= np.where(near(pic, bub["liquid"], 8), MASK["tank"], 0).astype(np.uint8)
	for fz in e.get("fizz", []):
		ys, xs = art_box(*fz["box"])
		mask[ys, xs] |= np.where(near(pic[ys, xs], fz["liquid"], 8), MASK["flask"], 0).astype(np.uint8)
	an = e.get("screenAnim")
	if an:
		ax, ay, aw, ah = an["scr"]
		ys, xs = art_box(ax, ax + aw - 1, ay, ay + ah - 1)
		mask[ys, xs] |= np.where(near(pic[ys, xs], [an["screen"]], 7), MASK["monitor"], 0).astype(np.uint8)
	scr = e.get("screen", {})
	if scr.get("glassCols"):
		g = scr["glass"]
		ys, xs = slice(g[1], g[3] + 1), slice(g[0], g[2] + 1)
		mask[ys, xs] |= np.where(near(pic[ys, xs], scr["glassCols"], 8), MASK["glass"], 0).astype(np.uint8)

	ownf = np.zeros((H, W, 4), np.uint8)
	ownf[..., 0] = own
	ownf[..., 1] = mask
	ownf[..., 3] = 255

	entry = {
		"picture": "lab_%s.png" % lv,
		"light": "lab_%s_light.lmap" % lv,
		"own": "lab_%s_own.lmap" % lv,
		"bands": nb,
		"scale": SCALE,
		"amb": e["amb"],
		"ambc": e["ambc"],
		"lights": [{"id": l["id"], "c": l["c"], "p": l["p"]} for l in lights],
		"owners": owners,
		"win": e["win"],
		"boot": e["boot"],
		"screen": scr,
	}
	for k_src, k_out in (("screenAnim", "anim"), ("bubbles", "bubbles"), ("fizz", "fizz")):
		if k_src in e:
			entry[k_out] = e[k_src]
	counts = {o: int((own == i + 1).sum()) for i, o in enumerate(owners)}
	return pic, band, ownf, entry, counts


def install():
	import numpy as np
	from PIL import Image
	with open(SOURCE, encoding="utf-8") as f:
		doc = json.load(f)
	os.makedirs(OUT, exist_ok=True)
	written = {"labs.json"}
	out = {"_about": "Written by tools/lab_install.py from tools/room_stage/lab -- do not edit; edit the stage and re-install.",
	       "sources": _sources(doc), "mask": MASK, "labs": {}}
	for lv in LEVELS:
		pic, band, ownf, entry, counts = bake(lv, doc[lv])
		Image.fromarray(pic, "RGB").save(os.path.join(OUT, entry["picture"]))
		Image.fromarray(band, "RGBA").save(os.path.join(OUT, entry["light"]), format="PNG")
		Image.fromarray(ownf, "RGBA").save(os.path.join(OUT, entry["own"]), format="PNG")
		written.update([entry["picture"], entry["light"], entry["own"]])
		out["labs"][lv] = entry
		marks = {k: int(((ownf[..., 1] & v) > 0).sum()) for k, v in MASK.items()}
		print("  %-10s %d lights in %d band(s) | glowing %s | marks %s" % (
			lv, len(entry["lights"]), entry["bands"], counts, {k: n for k, n in marks.items() if n}))
	with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as f:
		f.write(json.dumps(out, indent=1) + "\n")
	for name in os.listdir(OUT):
		keep = name in written or (name.endswith(".png.import") and name[:-len(".import")] in written)
		if not keep:
			os.remove(os.path.join(OUT, name))
			print("  removed %s" % name)
	print("installed %d labs into %s" % (len(LEVELS), os.path.relpath(OUT, ROOT)))
	print("run `godot --headless --path tkg --import` so the new pictures load")


def check():
	"""No numpy: the recorded sources against the stage, and every file there."""
	if not os.path.exists(OUT_JSON):
		print("lab_install: nothing installed (%s missing)" % os.path.relpath(OUT_JSON, ROOT))
		return 1
	with open(OUT_JSON, encoding="utf-8") as f:
		got = json.load(f)
	with open(SOURCE, encoding="utf-8") as f:
		doc = json.load(f)
	bad = 0
	want = _sources(doc)
	for k, v in want.items():
		if got.get("sources", {}).get(k) != v:
			print("lab_install: %s has moved on since the install -- run tools/lab_install.py" % k)
			bad += 1
	for lv in LEVELS:
		e = got.get("labs", {}).get(lv)
		if e is None:
			print("lab_install: no %s lab installed" % lv)
			bad += 1
			continue
		for k in ("picture", "light", "own"):
			if not os.path.exists(os.path.join(OUT, e[k])):
				print("lab_install: %s is missing" % e[k])
				bad += 1
	if bad == 0:
		print("lab_install: the five labs match the stage")
	return 1 if bad else 0


if __name__ == "__main__":
	if "--check" in sys.argv:
		sys.exit(check())
	install()
