"""A dim room lit by its one lamp, the lamp failing as the game's lamps fail.

The picture goes dark everywhere (the room with the light off), then a light
map puts it back: the lamp's cone, smooth inside with a dithered 4-px edge,
and a faint spill round the lamp so what stands near it can still be made out.
The fault (lamp.flicker_at, the game's own timing) scales that light map.
"""
import math
import sys
from PIL import Image
from lamp import flicker_at, hash1

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
DARK = (0.24, 0.26, 0.36)   # the room with the light off: dim, a little blue
AMBIENT = 0.10              # what the rest of the room gets from the lamp
WARM = 0.0                  # how orange the beam turns what it falls on
HOT_ALL = False             # the Hiring Board, as approved, lights its whole shade box
MOTE_FLOOR = None           # dust only where the light is at least this
MOTES = 0                   # dust motes in the light
POOL = None                 # (x, y, rx, ry) of the beam's pool on the floor
GLOW = 0.0                  # warm light the lamp adds to the wall round it
SPILL = (0.30, 16)          # the glow round the lamp: how bright, how far


def edge_dist(px, py, poly):
	"""Signed distance to the polygon's edge: positive inside."""
	inside = False
	best = 1e9
	n = len(poly)
	for i in range(n):
		ax, ay = poly[i]; bx, by = poly[(i + 1) % n]
		if (ay > py) != (by > py) and px < (bx - ax) * (py - ay) / (by - ay) + ax:
			inside = not inside
		dx, dy = bx - ax, by - ay
		t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
		best = min(best, math.hypot(px - ax - t * dx, py - ay - t * dy))
	return best if inside else -best


def light_map(w, h, cone, lamp, reach):
	L = [[0.0] * w for _ in range(h)]
	for y in range(h):
		for x in range(w):
			d = edge_dist(x + 0.5, y + 0.5, cone)
			r = math.hypot(x - lamp[0], y - lamp[1])
			inner = max(0.55, 1 - 0.45 * r / reach)
			if d >= 4:
				c = inner
			elif d > 0:
				c = inner if d / 4 * 16 > BAYER[y % 4][x % 4] else 0.0
			else:
				c = 0.0
			amb = AMBIENT + SPILL[0] * math.exp(-r / SPILL[1])
			if POOL:
				# where the beam lands: a pool on the floor, dithered at its rim
				e = math.hypot((x - POOL[0]) / POOL[2], (y - POOL[1]) / POOL[3])
				pv = min(1.0, max(0.0, 1.3 * (1 - e)))
				if 0 < pv < 0.6:
					pv = 0.6 if pv / 0.6 * 16 > BAYER[y % 4][x % 4] else 0.0
				c = max(c, pv)
			# kept apart: the beam warms what it falls on, the glow does not
			# the lamp's warm light laid on the wall round it, in dithered bands
			gl = math.exp(-r / SPILL[1])
			gl = math.floor(gl * 5 + BAYER[y % 4][x % 4] / 16) / 5
			L[y][x] = (c, amb, gl)
	return L


def frames(src, mode, n, xy, cone, lamp, reach, hot):
	im = Image.open(src).convert("RGB"); px = im.load()
	w, h = im.size
	L = light_map(w, h, cone, lamp, reach)
	out = []
	for i in range(n):
		cr, cg, cb, v = flicker_at(mode, i * 1000 / 30, *xy)
		f = Image.new("RGB", (w, h)); q = f.load()
		for y in range(h):
			for x in range(w):
				r, g, b = px[x, y]
				dr, dg, db = r * DARK[0], g * DARK[1], b * DARK[2]
				k = L[y][x]
				c, amb, gl = k if isinstance(k, tuple) else (k if k > AMBIENT + 0.31 else 0.0, k, 0.0)
				# the lamp's own lens is lit by itself, not by the room
				# (its bright pixels only: the box round it also holds dark wall,
				# and lighting that drew a square round the lamp -- Jon: "a weird
				# square around the lamp")
				if hot[0] <= x <= hot[2] and hot[1] <= y <= hot[3] and (HOT_ALL or 0.299 * r + 0.587 * g + 0.114 * b > 90):
					k = 1.0
					c = amb = 1.0
				# the fault takes the beam and the glow; the room's own light stays
				cb_ = min(1.0, c * v)
				k = max(cb_, AMBIENT + max(0.0, amb - AMBIENT) * v)
				wr, wg, wb = (1 + WARM * cb_, 1 + WARM * 0.25 * cb_, 1 - WARM * cb_)
				add = GLOW * gl * v * (0.35 + (0.299 * r + 0.587 * g + 0.114 * b) / 255)
				q[x, y] = (int(min(255, dr + (r * cr * wr - dr) * k + add * 255)),
				           int(min(255, dg + (g * cg * wg - dg) * k + add * 140)),
				           int(min(255, db + (b * cb * wb - db) * k + add * 60)))
		# DUST IN THE LIGHT, as the shop rooms draw it (ShopScene._draw_glow):
		# each mote drifts on the same clock, shows only where there is light,
		# a pixel of the light's own colour, fainter or stronger by its seed.
		t = i / 30
		for m in range(MOTES):
			sx = hash1(m * 1.37 + 0.11); sy = hash1(m * 2.71 + 5.3)
			sp = 0.15 + 0.5 * hash1(m * 3.91 + 1.7)
			mx = (sx * w + t * sp * 3.5 + 6.5 * math.sin(t * 0.21 + sx * 31)) % w
			my = (sy * h - t * sp * 2.0 + 4.5 * math.sin(t * 0.17 + sy * 27)) % h
			ix, iy = int(mx), int(my)
			lk = L[iy][ix]
			if isinstance(lk, tuple):
				# in the beam only (Jon: "only in the beam of the light")
				l = lk[0] * v
			else:
				# only in the light's bright heart, if a floor is set: the Hiring
				# Board's dust drifted over its notices and read as the board's own
				# pixels crawling (Jon: "the hiring board kinda jiggles")
				if MOTE_FLOOR is not None and lk < MOTE_FLOOR:
					continue
				l = max(0.0, lk - AMBIENT) / (1 - AMBIENT) * v
			if l < 0.06:
				continue
			a = min(0.9, l * (0.65 + 0.5 * hash1(m * 7.7)))
			r0, g0, b0 = q[ix, iy]
			q[ix, iy] = (int(r0 + (255 - r0) * a), int(g0 + (214 - g0) * a), int(b0 + (160 - b0) * a))
		out.append(f)
	return out


if __name__ == "__main__":
	src, dst, mode = sys.argv[1], sys.argv[2], int(sys.argv[3])
	xy = (int(sys.argv[4]), int(sys.argv[5]))
	# the Exchange: hood mouth at (54, 36), cone to the floor at row 116.
	# Jon: "the light beam quite a bit wider. and maybe some ambient light
	# elsewhere" -- the foot of the cone near doubled, the room at 0.24.
	AMBIENT = float(sys.argv[6]) if len(sys.argv) > 6 else AMBIENT
	spread = float(sys.argv[7]) if len(sys.argv) > 7 else 26
	WARM = 0.35
	SPILL = (float(sys.argv[8]), float(sys.argv[9])) if len(sys.argv) > 9 else SPILL
	GLOW = float(sys.argv[10]) if len(sys.argv) > 10 else 0.0
	POOL = (54, 117, 58, 6)
	MOTES = int(sys.argv[11]) if len(sys.argv) > 11 else 0
	cone = [(45, 35), (63, 35), (54 + spread * 1.6, 116), (54 - spread * 1.6, 116)]
	fs = frames(src, mode, 30 * 8, xy, cone, (54, 36), 90, (46, 26, 62, 36))
	big = [f.resize((288, 256), Image.NEAREST) for f in fs]
	big[0].save(dst, save_all=True, append_images=big[1:], duration=33, loop=0, lossless=True)
	big[0].save(dst.replace(".webp", "_still.png"))
	print(dst)
