"""Install Jon's Yard into the game, lit and laid out the way the Yard Drones page ran it.

    python tools/yard_install.py            # install (needs numpy and Pillow)
    python tools/yard_install.py --check    # is the game's copy what the stage holds?

THE SOURCE IS THE STAGE. `tools/room_stage/yard/` holds the five painted halls
Jon picked, one per development level, and everything else the Yard Drones page
(the artifact he judged the Yard on, v46) drew: the ship stands, the scissor
lifts, the floor's life, the crew's walk strips, the drones' screens and the five
deal TVs. `yard.json` there is everything the page knew about them -- where each
lamp hangs and the cone it throws, which pixels burn on their own and on what
beat, the stands' seats, the TVs' glass and lamps, the crew's lanes. Nothing
here decides anything about the Yard; it works out ahead of time what the game
would be too slow to work out itself. Every CLOCK -- when a bulb pops, how a
tube stutters, when a drone flies in -- is code, and lives in `YardScene.gd`.

THE PAGE IS THE REFERENCE, and each function below names the one it ports:

  cone_at()   a lamp's cone down the wall (`coneAt`), `grow` widening its soft
              edge as it falls; `up_at` is the same cone rising (`upAt`)
  pool_v()    a floor lamp's pool, bright under it and easing to nothing at
              its reach, seen in the hall's perspective (`poolV`)
  glow_at()   a small round glow (`glowAt`)
  polished()  the floor's polish giving back what is lit above it (`polished`)
  setup()     one level's lights (`setupLighting`): the ceiling lamps with a
              pool at the wall's foot, the wall lamps, the glows, the bounce up
              the lower wall, the mechanic's work light, and which pixels burn
  lamp_off()  what a ceiling lamp's painted cone is, cell by cell, so a lamp
              that flickers out can take it with it (`lampOff`)

THE FLOOR LAMPS ARE NOT BAKED. Their pools carry the ships' shadows, and the
ships are whatever the station has on the blocks and whatever you flew in in,
so the game works them out when it stands the ships (`yard_bay.gdshader`, the
page's `bakeShips`). Only the light they put on a hull is here: `lship`, the
pools along the ships' row with nothing in the way.

WHAT IT WRITES, all of it under `tkg/art/sprites/station/yard/`, which this tool
owns (anything it did not write is removed, apart from Godot's own `.import`
files beside the pictures):

  hall_<level>.png         the hall as painted, with the capital's plinth lamps
                           drawn in
  hall_<level>_light.lmap  every lamp that holds still, summed: R, G, B and how
                           much light, each 16-bit fixed point over 0..`scale`,
                           the high bytes in the top half and the low below
  hall_<level>_vary.lmap   each lamp that can go out or stutter, alone: two to a
                           band, (A.hi, A.lo, B.hi, B.lo) over 0..`vscale`, the
                           bands in a grid two across
  hall_<level>_own.lmap    per pixel: R the light it burns with (0 none, else
                           its index + 1; 255 a lens that always burns)
  hall_<level>_off.lmap    per pixel: which ceiling lamp's painted cone it is
                           and how much of it is that lamp's, as (lamp + 1,
                           k x 255), twice over where two lamps claim it
  stand_/lift_/life_/crew_/screen_/tv_*.png   the pictures, as staged, and the TV
                           glass split into its layers (`tv_<level>_*.png`)
  yard.json                each level's lights, lamps and settings, and every
                           picture's measurements, as `YardScene` reads them

An `.lmap` is a PNG that Godot does not import -- its colours are data -- read
off disk the way the labs' are.
"""

import hashlib
import json
import math
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, "tools", "room_stage", "yard")
SOURCE = os.path.join(STAGE, "yard.json")
OUT = os.path.join(ROOT, "tkg", "art", "sprites", "station", "yard")
OUT_JSON = os.path.join(OUT, "yard.json")
STATION = os.path.join(ROOT, "tkg", "art", "sprites", "station")
LEVELS = ["unclaimed", "outpost", "settlement", "city", "capital"]

LW, LH = 766, 482
# How the baked fields are held: 16-bit fixed point over 0..SCALE. A pixel's
# summed light tops out a little under 3 (unclaimed's door tubes); one lamp's
# own field at 1.35, a cone's brightest.
SCALE = 4.0
VSCALE = 2.0
# The page's floor-lamp constants: a pool's reach, and how high the lamps hang.
BAYR = 115.0
LAMPH = 330.0
# The one light index that means "a lens: always burns" in the own map.
BURN = 255


def _sha(path):
	with open(path, "rb") as f:
		return hashlib.sha256(f.read()).hexdigest()


def jround(v):
	"""JavaScript's Math.round: halves go up, never to even."""
	return int(math.floor(v + 0.5))


class Cam:
	"""The hall's camera (`CAM`): where the floor is at each row, and how wide a
	metre is there. The ships, the crew and the floor lamps all stand in it."""

	def __init__(self, doc):
		c = doc["cam"]
		self.vx, self.hy, self.f, self.ch = float(c["vx"]), float(c["hy"]), float(c["f"]), float(c["ch"])
		self.wall = int(doc["wallrow"])

	def z_of(self, y):
		import numpy as np
		return self.ch * self.f / np.maximum(0.5, np.asarray(y, dtype=np.float64) - self.hy)

	def y_of_z(self, z):
		return self.hy + self.ch * self.f / z

	def u_of(self, x, y):
		import numpy as np
		return (np.asarray(x, dtype=np.float64) - self.vx) * self.z_of(y) / self.f

	def x_of_u(self, u, z):
		return self.vx + u * self.f / z

	def u_wall(self, x):
		return (x - self.vx) * float(self.z_of(self.wall)) / self.f


# ------------------------------------------------------------------ the shapes

def cone_at(x0, x1, y0, reach, spread, edge, grow=0.0):
	"""A lamp's cone down the wall (the page's `coneAt`)."""
	import numpy as np

	def fn(x, y):
		x = np.asarray(x, dtype=np.float64)
		y = np.asarray(y, dtype=np.float64)
		dy = y - y0
		v = np.zeros(np.broadcast(x, y).shape)
		above = (dy < 0) & (dy > -8) & (x >= x0) & (x <= x1)
		v = np.where(above, 0.3 * (1 + dy / 8.0), v)
		e = dy * spread
		dx = np.where(x < x0 - e, x0 - e - x, np.where(x > x1 + e, x - x1 - e, 0.0))
		E = edge + grow * dy
		with np.errstate(divide="ignore", invalid="ignore"):
			inside = (dy >= 0) & (dy < reach) & (dx < E)
			val = 1.35 * np.power(np.clip(1 - dy / reach, 0.0, None), 1.4) * (1 - dx / np.where(E == 0, 1, E))
		return np.where(inside, val, v)
	return fn


def up_at(x0, x1, y0, reach, spread, edge, grow=0.0):
	"""The same cone, rising from its lamp (the page's `upAt`)."""
	f = cone_at(x0, x1, y0, reach, spread, edge, grow)
	return lambda x, y: f(x, 2 * y0 - y)


def pool_v(cam, u0, z0, x, y):
	"""A floor lamp's pool (the page's `poolV`)."""
	import numpy as np
	y = np.asarray(y, dtype=np.float64)
	du = cam.u_of(x, y) - u0
	dz = cam.z_of(y) - z0
	d = np.sqrt(du * du + dz * dz) / BAYR
	e = 1 - d
	v = e * e * (3 - 2 * e)
	return np.where((y < cam.wall) | (d >= 1), 0.0, v)


def glow_at(cx, cy, rx, ry):
	"""A small round glow (the page's `glowAt`)."""
	import numpy as np

	def fn(x, y):
		dd = ((np.asarray(x, dtype=np.float64) - cx) / rx) ** 2 + ((np.asarray(y, dtype=np.float64) - cy) / ry) ** 2
		return np.where(dd < 1, np.power(np.clip(1 - dd, 0.0, None), 1.6), 0.0)
	return fn


def polished(cam, fn, gloss, rows):
	"""What is lit above the wall's foot, given back by the floor's polish (the
	page's `polished`)."""
	import numpy as np
	W = cam.wall

	def g(x, y):
		y = np.asarray(y, dtype=np.float64)
		near = (y > W) & (y - W < rows)
		return fn(x, y) + np.where(near, gloss * (1 - (y - W) / rows) * fn(x, 2 * W - y), 0.0)
	return g


def bake(x0, y0, x1, y1, fn, k=1.0):
	"""A field over its box, whole pixels, as float32 (the page's `bake`)."""
	import numpy as np
	x0 = max(0, int(math.floor(x0)))
	y0 = max(0, int(math.floor(y0)))
	x1 = min(LW - 1, int(math.ceil(x1)))
	y1 = min(LH - 1, int(math.ceil(y1)))
	ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
	d = (k * fn(xs.astype(np.float64), ys.astype(np.float64))).astype(np.float32)
	return {"x0": x0, "y0": y0, "w": x1 - x0 + 1, "h": y1 - y0 + 1, "d": d}


def pool_box(cam, u0, z0):
	"""Where a floor lamp's pool can reach, on the picture (the page's `poolBox`)."""
	ya = max(cam.wall, int(math.floor(cam.y_of_z(z0 + BAYR))))
	yb = min(LH - 1, int(math.ceil(cam.y_of_z(max(1.0, z0 - BAYR)))))
	xs = []
	for y in (ya, yb):
		z = float(cam.z_of(y))
		xs += [cam.x_of_u(u0 - BAYR, z), cam.x_of_u(u0 + BAYR, z)]
	return [min(xs), ya, max(xs), yb]


def union(*bs):
	return [min(b[0] for b in bs), min(b[1] for b in bs), max(b[2] for b in bs), max(b[3] for b in bs)]


# Which pixels burn on their own, by colour (the page's `TESTS`).
def lum(r, g, b):
	return 0.299 * r + 0.587 * g + 0.114 * b


def tests(name, r, g, b):
	import numpy as np
	L = lum(r, g, b)
	if name == "core":
		return L >= 200
	if name == "teal":
		return (L >= 200) | ((b > 150) & (g > 150) & (r < 175) & (np.abs(g - b) < 40) & (np.minimum(g, b) - r > 50))
	if name == "warm":
		return (r > 170) & (g > 120) & (r - b > 50)
	if name == "magenta":
		return (r > 150) & (b > 120) & (r - g > 60)
	if name == "gold":
		return (r > 140) & (g > 100) & (r - b > 70)
	if name == "white":
		return (r > 190) & (g > 190) & (b > 190)
	raise ValueError("no test %r" % name)


# The plinth lamps drawn into the capital (the page's `FIX.uplight`): '#' outline,
# 'm' brass, 'd' dark brass, 'L' the lens, which burns.
UPLIGHT = {"rows": [".LLLLLLL.", "#mmmmmmm#", "#mdddddm#", ".#ddddd#.", "..#ddd#..", "...###..."],
           "cols": {"#": [40, 30, 16], "m": [221, 198, 108], "d": [152, 128, 57]}, "on": [248, 251, 255]}


def variable(L, kind, i, g=None):
	"""Can this light's pool change? A ceiling lamp that flickers out (E4, a
	painted one, never the capital's) or is the level's tired one; a glow whose
	pool follows a beat that is not a constant."""
	if kind == "ceil":
		c = L["ceil"][i]
		flick = (not L.get("noFlicker")) and bool(c.get("core")) and not c.get("noflick")
		return flick or i == L.get("tired", -1)
	if kind == "glow":
		p = g.get("pool")
		return bool(p) and p[0] != "dead"
	return False


def setup(doc, lv, hall):
	"""One level's lights, on its own hall (the page's `setupLighting`)."""
	import numpy as np
	cam = Cam(doc)
	L = doc["levels"][lv]["light"]
	W = cam.wall
	main = L["main"]
	lights = []

	def light(kind, i, col, p, f, base=1.0):
		lights.append({"kind": kind, "i": i, "col": col, "p": p, "f": f, "base": base})
		return len(lights) - 1

	zw = float(cam.z_of(W))
	ceil = []
	for i, c in enumerate(L["ceil"]):
		x0, x1, y0, reach, spread, edge = c["cone"][:6]
		g = c["cone"][6] if len(c["cone"]) > 6 else 0.0
		shape = (up_at if c.get("up") else cone_at)(*c["cone"])
		u = cam.u_wall(c["x"])
		if c.get("cut"):
			base_shape = shape
			shape = lambda x, y, s=base_shape: np.where(np.asarray(y) < W, s(x, y), 0.0)
		cone = polished(cam, shape, 0.35, 90)
		box = union([x0 - reach * (spread + g) - edge, max(0, (y0 - reach) if c.get("up") else (y0 - 8)),
		             x1 + reach * (spread + g) + edge, W + 90], pool_box(cam, u, zw))
		ceil.append(light("ceil", i, main, c.get("p", 1.0),
		                  bake(*box, lambda x, y, cone=cone, u=u: cone(x, y) + pool_v(cam, u, zw, x, y))))
	wall = []
	for j, c in enumerate(L["wall"]):
		x0, x1, y0, reach, spread, edge = c["cone"][:6]
		wall.append(light("wall", j, main, c.get("p", 0.85),
		                  bake(x0 - reach * spread - edge, y0 - 8, x1 + reach * spread + edge, W + 90,
		                       polished(cam, cone_at(*c["cone"]), 0.5, 90))))
	glow = []
	for k, g in enumerate(L["glows"]):
		cx, cy, rx, ry = g["at"]
		fn = glow_at(cx, cy, rx, ry)
		base = 0.07 if (g.get("pool") and g["pool"][0] == "dead") else 1.0
		if L.get("glowRefl", True) is not False and cy + ry > W - 45:
			f = bake(cx - rx, cy - ry, cx + rx, min(2 * W - (cy - ry), W + 70), polished(cam, fn, g.get("gloss", 0.55), 70), g.get("k", 0.9))
		else:
			f = bake(cx - rx, cy - ry, cx + rx, cy + ry, fn, g.get("k", 0.9))
		glow.append(light("glow", k, g["col"], g.get("p", 0.6), f, base))
	bay = light("bay", 0, main, 1.0, None)
	bounce = -1
	if L.get("bounce"):
		b0 = L["bounce"]["y0"]

		def bfn(x, y, b0=b0):
			u = (np.asarray(y, dtype=np.float64) - b0) / (W - b0)
			return u * u * (3 - 2 * u) + 0 * np.asarray(x)
		bounce = light("bounce", 0, main, L["bounce"]["k"], bake(0, b0, LW - 1, W - 1, bfn))
	T = doc["task"]
	tx, ty, R = float(T["x"]), float(T["y"]), float(T["r"])
	tu, tz = float(cam.u_of(tx, ty)), float(cam.z_of(ty))

	def pv(x, y):
		y = np.asarray(y, dtype=np.float64)
		du = cam.u_of(x, y) - tu
		dz = cam.z_of(y) - tz
		d = np.sqrt(du * du + dz * dz) / R
		e = np.minimum(1.0, (1 - d) / 0.45)
		return np.where((y < W) | (d >= 1), 0.0, e * e * (3 - 2 * e))
	ya = max(W, int(math.floor(cam.y_of_z(tz + R))))
	yb = min(LH - 1, int(math.ceil(cam.y_of_z(max(1.0, tz - R)))))
	hw = R * cam.f / max(1.0, tz - R)
	task = light("task", 0, T["col"], T["k"], bake(tx - hw, ya, tx + hw, yb, pv))

	# WHAT BURNS ON ITS OWN, first claim wins: the lamps' cores, then the glows.
	r = hall[..., 0].astype(np.float64)
	gg = hall[..., 1].astype(np.float64)
	b = hall[..., 2].astype(np.float64)
	own = np.zeros((LH, LW), np.uint8)

	def claim(idx, x0, y0, x1, y1, test):
		ys = slice(max(0, int(math.floor(y0))), min(LH - 1, int(math.ceil(y1))) + 1)
		xs = slice(max(0, int(math.floor(x0))), min(LW - 1, int(math.ceil(x1))) + 1)
		hit = tests(test, r[ys, xs], gg[ys, xs], b[ys, xs]) & (own[ys, xs] == 0)
		own[ys, xs] = np.where(hit, idx + 1, own[ys, xs])
	for i, c in enumerate(L["ceil"]):
		if c.get("core"):
			claim(ceil[i], *c["core"], "core")
	for j, c in enumerate(L["wall"]):
		claim(wall[j], *c["core"], "core")
	for k, g in enumerate(L["glows"]):
		for c in (g.get("cores") or [g["core"]]):
			claim(glow[k], *c, g.get("test", "core"))
	return {"lights": lights, "ceil": ceil, "wall": wall, "glow": glow, "bay": bay, "bounce": bounce, "task": task, "own": own}


def lamp_off(doc, lv, hall):
	"""Each painted ceiling lamp's cone, cell by cell, and how much of the cell's
	brightness is that lamp's (the page's `lampOff`)."""
	L = doc["levels"][lv]["light"]
	W = int(doc["wallrow"])
	s0, s1 = L["side"]
	depth = L["depth"]
	h = hall.astype("float64")
	HL = 0.3 * h[..., 0] + 0.59 * h[..., 1] + 0.11 * h[..., 2]
	HS = h.max(axis=2) - h.min(axis=2)
	out = []
	for c in L["ceil"]:
		lx, ly = jround(c["x"]), jround(c["y"])
		cells = []
		if not c.get("core"):
			out.append(cells)
			continue
		reach = s0 + 4
		for y in range(max(0, ly - 3), ly + 4):
			for x in range(lx - 7, lx + 8):
				if 0 <= x < LW and HL[y, x] >= 150:
					cells.append([x, y, 0.3])
		for y in range(ly + 2, min(W - 1, ly + depth) + 1):
			side = []
			for d in range(s0, s1 + 1):
				for sg in (-1, 1):
					x = lx + sg * d
					if 0 <= x < LW:
						side.append(HL[y, x])
			side.sort()
			ref = side[len(side) >> 1]

			def sm(x):
				return (HL[y, max(0, x - 1)] + HL[y, x] + HL[y, min(LW - 1, x + 1)]) / 3
			if sm(lx) <= ref * 1.08:
				continue
			a0 = b0 = lx
			while a0 - 2 >= 0 and a0 - 1 > lx - reach and (sm(a0 - 1) > ref * 1.08 or sm(a0 - 2) > ref * 1.08):
				a0 -= 1
			while b0 + 2 <= LW - 1 and b0 + 1 < lx + reach and (sm(b0 + 1) > ref * 1.08 or sm(b0 + 2) > ref * 1.08):
				b0 += 1
			cols = [x for x in range(a0, b0 + 1) if HS[y, x] < 45]
			rim = [x for x in (a0 - 2, a0 - 1, b0 + 1, b0 + 2) if 0 <= x < LW and HS[y, x] < 45]
			if not cols:
				continue
			mean = sum(HL[y, x] for x in cols) / len(cols)
			k = 1.0 if mean <= 0 else max(0.35, min(1.0, ref / mean))
			cells += [[x, y, k] for x in cols] + [[x, y, (1 + k) / 2] for x in rim]
		out.append(cells)
	return out


def lship(doc, lv):
	"""The floor lamps' light along the ships' row, with nothing in the way: what
	a hull takes (the page's `LSHIP`)."""
	import numpy as np
	cam = Cam(doc)
	L = doc["levels"][lv]["light"]
	row = min(LH - 1, int(doc["dial"]["ships"]) + 10)
	xs = np.arange(LW, dtype=np.float64)
	acc = np.zeros(LW, np.float32)
	for x in L.get("floorX") or [c["x"] for c in L["ceil"]]:
		ul = cam.u_wall(x)
		for zl, k in L["floor"]:
			acc = (acc + (k * pool_v(cam, ul, zl, xs, np.full(LW, float(row))))).astype(np.float32)
	return acc


# ------------------------------------------------------------------ the bake

def enc16(v, scale):
	"""16-bit fixed point over 0..scale, as (high byte, low byte)."""
	import numpy as np
	q = np.round(np.clip(v, 0.0, scale) / scale * 65535.0).astype(np.uint32)
	return (q >> 8).astype(np.uint8), (q & 255).astype(np.uint8)


def draw_uplights(L, hall, own):
	"""The capital's plinth lamps, drawn into the hall where the page drew them
	each frame (`drawFixtures`); their lenses always burn."""
	for F in L.get("fixtures", []):
		rows = UPLIGHT["rows"]
		x0 = jround(F["x"]) - (len(rows[0]) >> 1)
		for j, row in enumerate(rows):
			for k, ch in enumerate(row):
				if ch == ".":
					continue
				x, y = x0 + k, int(F["y"]) + j
				if not (0 <= x < LW and 0 <= y < LH):
					continue
				hall[y, x] = UPLIGHT["on"] if ch in "LH" else UPLIGHT["cols"][ch]
				if ch in "LH":
					own[y, x] = BURN


def bake_level(doc, lv):
	"""One level: its hall, the light that holds still, the lamps that do not,
	what burns, and its entry in the installed yard.json."""
	import numpy as np
	from PIL import Image
	e = doc["levels"][lv]
	L = e["light"]
	hall = np.array(Image.open(os.path.join(STAGE, e["hall"])).convert("RGB"))
	assert hall.shape == (LH, LW, 3), "%s is %s, not %dx%d" % (e["hall"], hall.shape, LW, LH)
	S = setup(doc, lv, hall)
	lights = S["lights"]
	# THE LIGHT THAT HOLDS STILL: every lamp and glow at rest -- a lamp that can go
	# out at full, a dead bulb at its 0.07 -- and the capital's plinth lamps' glow.
	sa = np.zeros((LH, LW, 4), np.float64)
	var = []
	meta = []
	for n, l in enumerate(lights):
		kind, i = l["kind"], l["i"]
		g = L["glows"][i] if kind == "glow" else None
		m = {"kind": kind, "i": i, "p": l["p"], "col": l["col"], "band": -1}
		if kind == "glow":
			m["beat"] = g.get("beat")
			if g.get("pool"):
				m["pool"] = g["pool"]
			if g.get("sfx"):
				m["sfx"] = True
			if g.get("pop"):
				m["pop"] = True
			m["at"] = g["at"]
		meta.append(m)
		if kind == "bay":
			continue
		f = l["f"]
		d = f["d"].astype(np.float64)
		k = l["base"] * l["p"]
		sl = (slice(f["y0"], f["y0"] + f["h"]), slice(f["x0"], f["x0"] + f["w"]))
		for ch in range(3):
			sa[sl + (ch,)] += k * l["col"][ch] * d
		sa[sl + (3,)] += k * d
		if variable(L, kind, i, g):
			m["band"] = len(var)
			m["box"] = [f["x0"], f["y0"], f["w"], f["h"]]
			full = np.zeros((LH, LW), np.float64)
			full[sl] = d
			var.append(full)
	for F in L.get("fixtures", []):
		rx, ry, dy, k, col = F["glow"]
		cx, cy = float(F["x"]), float(F["y"]) + dy
		y0, y1 = max(0, int(math.floor(cy - ry))), min(LH - 1, int(math.ceil(cy + ry)))
		x0, x1 = max(0, int(math.floor(cx - rx))), min(LW - 1, int(math.ceil(cx + rx)))
		ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
		dd = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2
		v = np.where(dd < 1, k * np.power(np.clip(1 - dd, 0, None), 1.6), 0.0)
		for ch in range(3):
			sa[y0:y1 + 1, x0:x1 + 1, ch] += v * col[ch]
		sa[y0:y1 + 1, x0:x1 + 1, 3] += v
	assert sa.max() <= SCALE, "%s: a pixel's light is %.2f, over the %.1f the file holds" % (lv, sa.max(), SCALE)
	hi, lo = enc16(sa, SCALE)
	light = np.concatenate([hi, lo], axis=0)

	# THE LAMPS THAT CAN GO OUT: each alone, two to a band, the bands two across.
	assert len(var) <= 12, "%s: %d lamps can go out, the shader holds 12" % (lv, len(var))
	nb = max(1, (len(var) + 1) // 2)
	vary = np.zeros((LH * ((nb + 1) // 2), LW * (2 if nb > 1 else 1), 4), np.uint8)
	for n, full in enumerate(var):
		assert full.max() <= VSCALE, "%s: a lamp's own light is %.2f, over %.1f" % (lv, full.max(), VSCALE)
		b = n // 2
		ox, oy = (b % 2) * LW, (b // 2) * LH
		h8, l8 = enc16(full, VSCALE)
		ch = (n % 2) * 2
		vary[oy:oy + LH, ox:ox + LW, ch] = h8
		vary[oy:oy + LH, ox:ox + LW, ch + 1] = l8

	# WHAT BURNS, AND WHAT EACH CEILING LAMP'S PAINTED CONE IS.
	own = S["own"].copy()
	pic = hall.copy()
	draw_uplights(L, pic, own)
	ownf = np.zeros((LH, LW, 4), np.uint8)
	ownf[..., 0] = own
	ownf[..., 3] = 255
	# Two claims at most on a pixel: a lamp's own cone rows can meet the rows round
	# its core, and unclaimed's two door tubes meet mid-door. Each is (lamp + 1, k).
	offf = np.zeros((LH, LW, 4), np.uint8)
	off = lamp_off(doc, lv, hall)
	for li, cells in enumerate(off):
		for x, y, k in cells:
			q = max(1, min(255, jround(k * 255)))
			if offf[y, x, 0] == 0:
				offf[y, x, 0] = li + 1
				offf[y, x, 1] = q
			else:
				assert offf[y, x, 2] == 0, "%s: three claims on (%d, %d)" % (lv, x, y)
				offf[y, x, 2] = li + 1
				offf[y, x, 3] = q

	ceil_idx = S["ceil"]
	lamps = []
	for i, c in enumerate(L["ceil"]):
		lamps.append({"x": jround(c["x"]), "y": jround(c["y"]), "painted": bool(c.get("core")), "noflick": bool(c.get("noflick")), "light": ceil_idx[i]})
	entry = {
		"picture": "hall_%s.png" % lv, "light": "hall_%s_light.lmap" % lv, "vary": "hall_%s_vary.lmap" % lv, "own": "hall_%s_own.lmap" % lv,
		"off": "hall_%s_off.lmap" % lv,
		"scale": SCALE, "vscale": VSCALE, "bands": nb, "nvary": len(var),
		"lights": meta, "ceil": ceil_idx, "wall": S["wall"], "glow": S["glow"], "bay": S["bay"], "bounce": S["bounce"], "task": S["task"],
		"lamps": lamps, "tired": L.get("tired", -1), "noFlicker": bool(L.get("noFlicker")),
		"main": L["main"], "amb": L["amb"], "ambK": L.get("ambK", 1), "dust": L["dust"], "dustN": L.get("dustN", 56),
		"moths": bool(L.get("moths")), "people": bool(L.get("people")), "stars": L.get("stars"), "glowRefl": L.get("glowRefl", True) is not False,
		"reflK": L.get("reflK", 0.4), "floorX": L.get("floorX") or [c["x"] for c in L["ceil"]], "floor": L["floor"],
		"lship": [round(float(v), 6) for v in lship(doc, lv)],
		"pop": next((S["glow"][k] for k, g in enumerate(L["glows"]) if g.get("pop")), -1),
		"moth_lamps": [{"x": c["x"], "y": c["y"]} for c in L["ceil"]] if L.get("moths") else [],
	}
	counts = {"lights": len(lights), "vary": len(var), "burning px": int(((own > 0) & (own < BURN)).sum()), "lamp-off px": int((offf[..., 0] > 0).sum()), "two claims": int((offf[..., 2] > 0).sum())}
	return pic, light, vary, ownf, offf, entry, counts


# ------------------------------------------------------------------ the pictures

def rgba(path):
	import numpy as np
	from PIL import Image
	return np.array(Image.open(path).convert("RGBA"))


def ink(a):
	"""A sprite's opaque box (the page's `ink`): x0, x1, top, foot, and the
	middle of its width."""
	import numpy as np
	m = a[..., 3] >= 128
	ys, xs = np.nonzero(m)
	if len(xs) == 0:
		return {"w": int(a.shape[1]), "h": int(a.shape[0]), "x0": int(a.shape[1]), "x1": -1, "top": int(a.shape[0]), "foot": -1, "cx": 0.0}
	x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
	return {"w": int(a.shape[1]), "h": int(a.shape[0]), "x0": x0, "x1": x1, "top": y0, "foot": y1, "cx": (x0 + x1) / 2}


def strip(a, n):
	"""A strip cut into n frames, measured; every frame anchored on the first
	frame's middle, so a moving hand never shifts the body (the page's `cut`)."""
	fw = a.shape[1] // n
	assert fw * n == a.shape[1], "a strip %d wide does not cut into %d frames" % (a.shape[1], n)
	frames = [ink(a[:, i * fw:(i + 1) * fw]) for i in range(n)]
	for f in frames:
		f["cx"] = frames[0]["cx"]
	return fw, frames


def lumx(r, g, b):
	return 0.3 * r + 0.59 * g + 0.11 * b


def welder_tip(a):
	"""The brightest pixel in a frame's top half: the torch (the page's `tipOf`)."""
	best = None
	h, w = a.shape[:2]
	for y in range(0, (h + 1) // 2 if h % 2 else h // 2):
		for x in range(w):
			if a[y, x, 3] < 128:
				continue
			l = lumx(float(a[y, x, 0]), float(a[y, x, 1]), float(a[y, x, 2]))
			if best is None or l > best[2]:
				best = (x, y, l)
	return [best[0], best[1]] if best else [0, 0]


def feet_span(a):
	"""How far apart the feet are on the bottom three rows."""
	h, w = a.shape[:2]
	lo, hi = 10 ** 9, -1
	for y in range(h - 3, h):
		for x in range(w):
			if a[y, x, 3] >= 128:
				lo, hi = min(lo, x), max(hi, x)
	return lo, hi


def install_art(doc, written):
	"""Copy the stage's pictures into the game and measure what the Yard needs
	of each."""
	import numpy as np
	from PIL import Image
	art = {"life": {}, "crew": {}, "screens": {}, "stands": {}, "lifts": {}, "flyers": {}}

	def put(src, name):
		shutil.copyfile(os.path.join(STAGE, src), os.path.join(OUT, name))
		written.add(name)
		return name

	for lv in LEVELS:
		e = doc["levels"][lv]
		st = dict(e["stand"])
		st["picture"] = put(st["picture"], "stand_%s.png" % lv)
		a = rgba(os.path.join(OUT, st["picture"]))
		st["w"], st["h"] = int(a.shape[1]), int(a.shape[0])
		art["stands"][lv] = st
		li = dict(e["lift"])
		li["picture"] = put(li["picture"], "lift_%s.png" % lv)
		li.update(ink(rgba(os.path.join(OUT, li["picture"]))))
		art["lifts"][lv] = li

	# THE FLOOR'S LIFE: each picture or strip, measured.
	STRIPS = {"welder_strip": 9, "tech_strip": 9, "grind_strip": 9, "cat_walk": 8, "cat_sit": 8, "cat_lick": 12,
	          "mech_gen_1": 2, "mech_gen_2": 2, "mech_legs_1": 2, "mech_legs_2": 2, "mech_kneel_2": 1}
	for f in sorted(os.listdir(os.path.join(STAGE, "life"))):
		if not f.endswith(".png"):
			continue
		key = f[:-4]
		name = put("life/" + f, "life_%s.png" % key)
		a = rgba(os.path.join(OUT, name))
		if key in STRIPS:
			fw, frames = strip(a, STRIPS[key])
			entry = {"picture": name, "n": STRIPS[key], "fw": fw, "fh": int(a.shape[0]), "frames": frames}
			if key == "welder_strip":
				for i, fr in enumerate(frames):
					fr["tip"] = welder_tip(a[:, i * fw:(i + 1) * fw])
		else:
			entry = dict(ink(a), picture=name)
		art["life"][key] = entry
	# each forklift: where its blade starts, how high a crate rides on it, where its beacon sits
	forks = []
	for n in ["", "_2", "_3"]:
		B = rgba(os.path.join(STAGE, "life", "fork_body%s.png" % n))
		BL = rgba(os.path.join(STAGE, "life", "fork_blade%s.png" % n))
		bi, bli = ink(B), ink(BL)
		right = bli["x1"]
		top = BL.shape[0]
		for y in range(BL.shape[0]):
			for x in range(right - 2, right + 1):
				if BL[y, x, 3] >= 128 and y < top:
					top = y
		btop, xs = B.shape[0], []
		for x in range(bi["x0"], bi["x0"] + jround((bi["x1"] - bi["x0"]) * 0.62) + 1):
			for y in range(B.shape[0]):
				if B[y, x, 3] >= 128:
					if y < btop:
						btop, xs = y, [x]
					elif y == btop:
						xs.append(x)
					break
		beacon = [jround((xs[0] + xs[-1]) / 2) if xs else jround(bi["cx"]), btop]
		forks.append({"body": "life_fork_body%s.png" % n, "blade": "life_fork_blade%s.png" % n, "slot": bli["x0"], "bladeTop": top,
		              "rest": bi["foot"] - top + 1, "beacon": beacon})
	art["forks"] = forks
	con = rgba(os.path.join(STAGE, "life", "console.png"))
	m = (con[..., 3] > 128) & (con[..., 2] > 140) & (con[..., 1] > 130) & (con[..., 0] < 150)
	art["life"]["console"]["screen"] = [[int(x), int(y)] for y, x in zip(*np.nonzero(m))]
	bot = rgba(os.path.join(STAGE, "life", "bot.png")).astype(np.int32)
	m = (bot[..., 3] > 128) & (bot[..., 1] > 150) & (bot[..., 1] > bot[..., 0] + 15) & (bot[..., 1] > bot[..., 2] + 50)
	art["life"]["bot"]["em"] = [[int(x), int(y)] for y, x in zip(*np.nonzero(m))]

	# THE CREW: each walk strip, with the pose each stops in and the one it steps
	# out in, and how wide its feet are for the shadow under them.
	for n, s in doc["crew"]["strips"].items():
		name = put(s["picture"], "crew_%s.png" % n)
		a = rgba(os.path.join(OUT, name))
		fw, fh, nf = s["frame_w"], s["frame_h"], s["frames"]
		spans, fs = [], []
		for i in range(nf):
			lo, hi = feet_span(a[:, i * fw:(i + 1) * fw])
			spans.append(hi - lo if hi >= 0 else None)
			fs.append((hi - lo + 1) / 2 if hi >= 0 else 4)
		stand = min((i for i in range(nf) if spans[i] is not None), key=lambda i: (spans[i], i), default=0)
		stride = max(range(nf), key=lambda i: ((spans[i] if spans[i] is not None else -2), -i))
		art["crew"][n] = dict(s, picture=name, stand=stand, stride=stride, fs=fs)

	# THE DRONES' SCREENS: each with its glass, its top row, and where its cables hook on.
	for k, lst in doc["screens"].items():
		out = []
		for sc in lst:
			base = os.path.basename(sc["picture"])
			name = put(sc["picture"], "screen_%s" % base)
			a = rgba(os.path.join(OUT, name))
			W = a.shape[1]
			top = 0
			while top < a.shape[0] and not (a[top, :, 3] >= 128).any():
				top += 1
			runs, s0 = [], -1
			for x in range(W + 1):
				on = x < W and a[top + 1, x, 3] >= 128
				if on and s0 < 0:
					s0 = x
				if not on and s0 >= 0:
					runs.append((s0 + x - 1) / 2)
					s0 = -1
			hooks = [runs[0], runs[-1]] if len(runs) >= 2 and runs[-1] - runs[0] < W - 10 else [14, W - 15]
			hook = min(runs, key=lambda r: abs(r - W / 2)) if runs else W / 2
			if runs:
				# the first run nearest the middle, as the page's reduce keeps the earlier on a tie
				best = runs[0]
				for r in runs[1:]:
					if abs(r - W / 2) < abs(best - W / 2):
						best = r
				hook = best
			out.append({"picture": name, "glass": sc["glass"], "w": int(W), "h": int(a.shape[0]), "top": top, "hooks": hooks, "hook": hook})
		art["screens"][k] = out

	# THE STATION'S FLYERS, the game's own: twelve frames each, and where each
	# frame's underside is, for the cables of the four that carry screens.
	FL = {"d8": [62, 41], "d5": [50, 33], "d9": [62, 33], "d12": [60, 35], "d1": [60, 35], "d2": [62, 36], "d3": [60, 35], "d4": [62, 37],
	      "d6": [62, 34], "d7": [62, 36], "d10": [59, 46], "d11": [60, 34], "d13": [62, 36], "d14": [60, 31]}
	for k, (fw, fh) in FL.items():
		a = rgba(os.path.join(STATION, "walker_flyer_%s.png" % k))
		bot = []
		for f in range(12):
			b = 0
			for y in range(fh):
				for x in range(f * fw + (fw >> 1) - 8, f * fw + (fw >> 1) + 9):
					if a[y, x, 3] >= 128:
						b = y
			bot.append(b)
		art["flyers"][k] = {"picture": "walker_flyer_%s.png" % k, "fw": fw, "fh": fh, "bot": bot, "low": max(bot)}
	return art


# ------------------------------------------------------------------ the TVs

def install_tvs(doc, written):
	"""Each level's deal TV, its glass split the way the page split it: the glass
	as painted with the bulb's light taken off it, that light as a layer of its
	own, the backlit glass, the dark round its foot, the settlement lamp's cone,
	and every pixel of every lamp on it."""
	import numpy as np
	from PIL import Image
	tvs = {}
	for lv in LEVELS:
		e = doc["levels"][lv]
		D0 = e["tvdef"]
		src = e["tv"]
		shutil.copyfile(os.path.join(STAGE, "tvs", src + ".png"), os.path.join(OUT, "tv_%s.png" % lv))
		shutil.copyfile(os.path.join(STAGE, "tvs", src + "_lid.png"), os.path.join(OUT, "tv_%s_lid.png" % lv))
		written.update(["tv_%s.png" % lv, "tv_%s_lid.png" % lv])
		d = rgba(os.path.join(STAGE, "tvs", src + ".png")).astype(np.int32)
		H0, IW = d.shape[0], d.shape[1]
		gx0, gy0, gx1, gy1 = D0["glass"]
		GW, GH = gx1 - gx0 + 1, gy1 - gy0 + 1
		tx0, ty0, tx1, ty1 = D0.get("text") or D0["glass"]
		TW, TH, TOX, TOY = tx1 - tx0 + 1, ty1 - ty0 + 1, tx0 - gx0, ty0 - gy0

		def L8(y, x):
			return 0.299 * d[y, x, 0] + 0.587 * d[y, x, 1] + 0.114 * d[y, x, 2]

		# its base darkens where it meets the floor
		ao = np.zeros((H0, IW, 4), np.uint8)
		N = 14
		for y in range(H0 - N, H0):
			for x in range(IW):
				if d[y, x, 3] >= 128:
					ao[y, x, 3] = jround(255 * 0.42 * math.pow((y - (H0 - N) + 1) / N, 1.6))
		Image.fromarray(ao, "RGBA").save(os.path.join(OUT, "tv_%s_ao.png" % lv))
		written.add("tv_%s_ao.png" % lv)

		dg = d.copy()
		bulb = []
		bset = set()
		ent = {"size": [IW, H0], "glass": D0["glass"], "GW": GW, "GH": GH, "tint": D0["tint"], "screen": D0["screen"], "reveal": D0["reveal"],
		       "fx": D0["fx"], "text": [TOX, TOY, TW, TH]}
		if D0.get("gold"):
			ent["gold"] = D0["gold"]
		BG = D0.get("bulbGlass")
		if BG:
			cx, cy = BG["cx"], BG["cy"]
			sx, sy = BG["seed"]
			stack = [(sx, sy)]
			while stack:
				x, y = stack.pop()
				k = y * IW + x
				if k in bset or abs(x - sx) > 12 or abs(y - sy) > 10 or L8(y, x) < 60:
					continue
				bset.add(k)
				bulb.append(k)
				stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
			bins = {}
			for y in range(GH):
				for x in range(GW):
					Y, X = gy0 + y, gx0 + x
					if d[Y, X, 3] < 200 or (Y * IW + X) in bset:
						continue
					k = int(math.floor(math.hypot(X - cx, Y - cy) / 3))
					bins.setdefault(k, []).append(L8(Y, X))
			nbins = max(bins) + 1 if bins else 0
			prof = [None] * nbins
			for k, v in bins.items():
				v = sorted(v)
				prof[k] = v[len(v) >> 1]
			far = sorted(v for v in prof[16:24] if v is not None)
			base = max(4, far[len(far) >> 1]) if far else 8

			def pAt(dd):
				f = dd / 3 - 0.5
				k0 = max(0, int(math.floor(f)))
				u = min(1, max(0, f - k0))
				a = prof[k0] if k0 < nbins and prof[k0] is not None else base
				b = prof[k0 + 1] if k0 + 1 < nbins and prof[k0 + 1] is not None else a
				return a + (b - a) * u
			glow = np.zeros((GH, GW, 4), np.uint8)
			for y in range(GH):
				for x in range(GW):
					Y, X = gy0 + y, gx0 + x
					if d[Y, X, 3] < 200:
						continue
					isb = (Y * IW + X) in bset
					f = base / max(base, L8(Y, X)) if isb else min(1, base / max(base, pAt(math.hypot(X - cx, Y - cy))))
					for c in range(3):
						dg[Y, X, c] = jround(d[Y, X, c] * f)
						glow[y, x, c] = 0 if isb else d[Y, X, c] - dg[Y, X, c]
					glow[y, x, 3] = 0 if isb else 255
			Image.fromarray(glow, "RGBA").save(os.path.join(OUT, "tv_%s_glow.png" % lv))
			written.add("tv_%s_glow.png" % lv)
			ent["glowL"] = "tv_%s_glow.png" % lv
		artg = dg[gy0:gy1 + 1, gx0:gx1 + 1].astype(np.uint8)
		Image.fromarray(artg, "RGBA").save(os.path.join(OUT, "tv_%s_art.png" % lv))
		written.add("tv_%s_art.png" % lv)
		ent["art"] = "tv_%s_art.png" % lv
		# the glass's own pixels, backlit: what the power-on brings up
		dim = np.zeros((GH, GW, 4), np.uint8)
		tint = D0["tint"]
		for y in range(GH):
			for x in range(GW):
				r, g, b, a = (int(v) for v in dg[gy0 + y, gx0 + x])
				lm = 0.3 * r + 0.59 * g + 0.11 * b
				sat = max(r, g, b) - min(r, g, b)
				if a < 200 or lm >= 130 or sat >= 90:
					continue
				sl = 0.86 if y % 2 == 1 else 1.0
				dim[y, x] = [jround((r * 0.4 + 18 * 0.6 + tint[0] * 0.06) * sl), jround((g * 0.4 + 24 * 0.6 + tint[1] * 0.06) * sl),
				             jround((b * 0.4 + 34 * 0.6 + tint[2] * 0.06) * sl), 255]
		Image.fromarray(dim, "RGBA").save(os.path.join(OUT, "tv_%s_dim.png" % lv))
		written.add("tv_%s_dim.png" % lv)
		ent["dim"] = "tv_%s_dim.png" % lv

		RULE = {
			"warm": lambda r, g, b: r > 170 and g > 120 and b < 170 and r >= g,
			"amber": lambda r, g, b: r > 140 and r > b + 50,
			"cyan": lambda r, g, b: b > 150 and g > 150 and r < 140,
			"magenta": lambda r, g, b: r > 150 and b > 140 and g < 120,
			"gold": lambda r, g, b: r > 180 and g > 130 and b < 120,
			"teal": lambda r, g, b: g > 140 and b > 110 and r < 130,
			"bulb": lambda r, g, b: 0.3 * r + 0.59 * g + 0.11 * b >= 200,
		}
		lights = []
		for Ld in D0["lights"]:
			bx0, by0, bx1, by1 = Ld["box"]
			px, on = [], set()
			for y in range(max(0, by0), min(H0, by1)):
				for x in range(max(0, bx0), min(IW, bx1)):
					r, g, b, a = (int(v) for v in d[y, x])
					if a > 200 and RULE[Ld["rule"]](r, g, b):
						px.append([x, y, r, g, b, 1])
						on.add(y * IW + x)
			if Ld.get("off") == "glass" and bset:
				px, on = [], set()
				cells = [(k % IW, k // IW) for k in bulb]
				body = sorted([c for c in cells if c[1] >= BG["seed"][1] - 3], key=lambda c: c[0] + c[1])
				glint = set(c[1] * IW + c[0] for c in body[:2])
				for x, y in cells:
					r, g, b = (int(v) for v in d[y, x, :3])
					v = L8(y, x)
					off = [220, 226, 220] if (y * IW + x) in glint else [98, 88, 74] if v >= 245 else [132, 138, 132] if y < BG["seed"][1] - 4 else [150, 157, 151] if v >= 190 else [118, 124, 120]
					px.append([x, y, r, g, b, 1, off])
					on.add(y * IW + x)
				for x, y in cells:
					for dy in (-1, 0, 1):
						for dx in (-1, 0, 1):
							k = (y + dy) * IW + x + dx
							if k in on or d[y + dy, x + dx, 3] < 200 or L8(y + dy, x + dx) >= 20:
								continue
							on.add(k)
							r, g, b = (int(v) for v in d[y + dy, x + dx, :3])
							px.append([x + dx, y + dy, r, g, b, 0])
				Z = BG["bezel"]
				for y in range(Z["y0"], Z["y1"] + 1):
					for x in range(Z["x0"], Z["x1"] + 1):
						k = y * IW + x
						if k in on or d[y, x, 3] < 200:
							continue
						r, g, b = (int(v) for v in d[y, x, :3])
						if r > 195 and b < r - 15:
							on.add(k)
							px.append([x, y, r, g, b, 2, Z["off"]])
			out = {k: v for k, v in Ld.items() if k not in ("box", "rule")}
			out["px"] = px
			if Ld.get("cone"):
				lit = [q for q in px if q[5]]
				C = Ld["cone"]
				ccx = C["x"] if "x" in C else sum(q[0] for q in lit) / len(lit)
				cy0 = C["y"] if "y" in C else max(q[1] for q in lit) + 1
				cw = int(math.ceil(C["hw"] + C["reach"] * C["spread"])) * 2 + 2
				ch = C["reach"]
				cone = np.zeros((ch, cw, 4), np.uint8)
				for dy in range(ch):
					for x in range(cw):
						half = C["hw"] + dy * C["spread"]
						dx = abs(x + 0.5 - cw / 2)
						if dx > half:
							continue
						f0 = math.pow(1 - dy / ch, 1.3) * min(1, (half - dx) / 3)
						f = math.floor(f0 * 4 + ((x + dy) & 1) * 0.5) / 4
						if f <= 0:
							continue
						cone[dy, x] = C["col"] + [jround(255 * C["a"] * f)]
				Image.fromarray(cone, "RGBA").save(os.path.join(OUT, "tv_%s_cone.png" % lv))
				written.add("tv_%s_cone.png" % lv)
				out["coneImg"] = "tv_%s_cone.png" % lv
				out["coneAt"] = [jround(ccx - cw / 2), cy0]
				del out["cone"]
			lights.append(out)
		ent["lights"] = lights
		oy = TOY + int(math.floor((TH - 56) / 2)) - 6
		ent["rows_y"] = oy
		ent["take"] = [TOX + TW - 6 - 44, oy + 45, 44, 17]
		ent["spill"] = e["spill"]
		tvs[lv] = ent
	return tvs


# ------------------------------------------------------------------ install

def _sources(doc):
	"""Every file the install is made from, with its hash -- this tool included,
	so a change to how the Yard is baked is a change the gate notices."""
	files = {"yard.json": SOURCE, "yard_install.py": os.path.abspath(__file__)}
	for dp, _, fs in os.walk(STAGE):
		for f in fs:
			if f.endswith(".png"):
				p = os.path.join(dp, f)
				files[os.path.relpath(p, STAGE).replace(os.sep, "/")] = p
	return {k: _sha(v) for k, v in sorted(files.items())}


def install():
	import numpy as np
	from PIL import Image
	with open(SOURCE, encoding="utf-8") as f:
		doc = json.load(f)
	os.makedirs(OUT, exist_ok=True)
	written = {"yard.json"}
	out = {"_about": "Written by tools/yard_install.py from tools/room_stage/yard -- do not edit; edit the stage and re-install.",
	       "sources": _sources(doc), "size": doc["size"], "wallrow": doc["wallrow"], "polish": doc["polish"], "cam": doc["cam"],
	       "bay": doc["bay"], "dial": doc["dial"], "berths": doc["berths"], "task": doc["task"], "life_windows": doc["life"],
	       "lanes": doc["crew"]["lanes"], "levels": {}, "burn": BURN}
	for lv in LEVELS:
		pic, light, vary, ownf, offf, entry, counts = bake_level(doc, lv)
		Image.fromarray(pic.astype(np.uint8), "RGB").save(os.path.join(OUT, entry["picture"]))
		Image.fromarray(light, "RGBA").save(os.path.join(OUT, entry["light"]), format="PNG")
		Image.fromarray(vary, "RGBA").save(os.path.join(OUT, entry["vary"]), format="PNG")
		Image.fromarray(ownf, "RGBA").save(os.path.join(OUT, entry["own"]), format="PNG")
		Image.fromarray(offf, "RGBA").save(os.path.join(OUT, entry["off"]), format="PNG")
		written.update([entry["picture"], entry["light"], entry["vary"], entry["own"], entry["off"]])
		e = doc["levels"][lv]
		entry["set"] = e["set"]
		out["levels"][lv] = entry
		print("  %-10s %s" % (lv, counts))
	out["art"] = install_art(doc, written)
	out["tvs"] = install_tvs(doc, written)
	with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as f:
		f.write(json.dumps(out, separators=(",", ":")) + "\n")
	for name in os.listdir(OUT):
		keep = name in written or (name.endswith(".png.import") and name[:-len(".import")] in written)
		if not keep:
			os.remove(os.path.join(OUT, name))
			print("  removed %s" % name)
	print("installed the yard's five halls and %d pictures into %s" % (len(written) - 1, os.path.relpath(OUT, ROOT)))
	print("run `godot --headless --path tkg --import` so the new pictures load")


def check():
	"""No numpy: the recorded sources against the stage, and every file there."""
	if not os.path.exists(OUT_JSON):
		print("yard_install: nothing installed (%s missing)" % os.path.relpath(OUT_JSON, ROOT))
		return 1
	with open(OUT_JSON, encoding="utf-8") as f:
		got = json.load(f)
	with open(SOURCE, encoding="utf-8") as f:
		doc = json.load(f)
	bad = 0
	want = _sources(doc)
	have = got.get("sources", {})
	for k, v in want.items():
		if have.get(k) != v:
			print("yard_install: %s has moved on since the install -- run tools/yard_install.py" % k)
			bad += 1
	for k in have:
		if k not in want:
			print("yard_install: %s was installed but is no longer on the stage -- run tools/yard_install.py" % k)
			bad += 1
	names = []
	for lv in LEVELS:
		e = got.get("levels", {}).get(lv)
		if e is None:
			print("yard_install: no %s hall installed" % lv)
			bad += 1
			continue
		names += [e[k] for k in ("picture", "light", "vary", "own", "off")]
	for name in names:
		if not os.path.exists(os.path.join(OUT, name)):
			print("yard_install: %s is missing" % name)
			bad += 1
	if bad == 0:
		print("yard_install: the yard's five halls match the stage")
	return 1 if bad else 0


if __name__ == "__main__":
	if "--check" in sys.argv:
		sys.exit(check())
	install()
