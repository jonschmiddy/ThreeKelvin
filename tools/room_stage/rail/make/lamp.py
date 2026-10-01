"""A picture's lamp failing the way the game's lamps fail (ShopLight.flicker_at,
ported line for line), on the room's 30 Hz clock. The lamp's light is the
picture's warm pixels; at brightness v they sit between the picture and the
picture with that light gone."""
import math
import sys
from PIL import Image

FR = 0.033
BURST = 0.62


def hash1(v):
	x = math.sin(v * 127.1) * 43758.5453
	return x - math.floor(x)


def vnoise(x):
	i0 = math.floor(x); f = x - i0
	f = f * f * (3 - 2 * f)
	a = hash1(i0 * 1.37 + 0.11); b = hash1((i0 + 1) * 1.37 + 0.11)
	return a + (b - a) * f


def fnoise(x):
	return 0.58 * vnoise(x) + 0.29 * vnoise(x * 2.13 + 11.7) + 0.13 * vnoise(x * 4.71 + 3.19)


def last_event(ts, every, seed, p):
	k = math.floor(ts / every)
	for _ in range(40):
		if hash1(k * 1.618 + seed * 2.7) <= p:
			at = (k + 0.05 + 0.9 * hash1(k * 3.77 + seed)) * every
			if at <= ts:
				return ts - at
		k -= 1
	return 1e9


def shape_strike(u, per, seed):
	e = u * per
	if e < BURST:
		fr = math.floor(e / FR)
		h = hash1(fr * 1.37 + seed * 3.1)
		return 1.0 if h < 0.42 else (0.55 if h < 0.52 else 0.04)
	return 1.0 if hash1(math.floor(seed * 11) * 0.77 + math.floor(e / per + 0.5)) < 0.45 else 0.05


def flicker_at(mode, t_ms, x, y):
	seed = hash1(math.floor(x + 0.5) * 0.7131 + math.floor(y + 0.5) * 2.9173) * 37
	rate = 1 + 0.5 * (hash1(seed * 1.77 + 7.3) - 0.5)
	ts = t_ms / 1000 + seed * 3.9
	if mode == 1:
		per = 5.5 / rate; u = ts / per; uu = u - math.floor(u)
		v = shape_strike(uu, per, seed)
		return (0.78, 0.93, 1.30, v) if (v > 0.3 and uu * per < BURST) else (1, 1, 1, v)
	if mode == 2:
		slow = fnoise(ts * 2.6 * rate); fast = fnoise(ts * 6.1 * rate + 11.3)
		v = 0.76 - 0.34 * slow + 0.20 * (fast - 0.5)
		v *= 0.94 + 0.06 * hash1(math.floor(ts / FR) * 1.7 + seed)
		v = min(1, max(0.2, v)); d = min(1, (1 - v) * 1.35)
		return (1 + 0.42 * d, 1 - 0.34 * d, 1 + 0.16 * d, v)
	if mode == 3:
		e = last_event(ts, 3.2 / rate, seed, 0.5); fr = math.floor(e / FR + 0.5); v = 1.0
		if fr == 0:
			v = 0.02
		elif fr <= 2 and hash1(seed * 5.1 + 0.7) > 0.55:
			v = 0.9 if fr == 1 else 0.03
		return (1, 1, 1, v)
	e = last_event(ts, 6 / rate, seed, 0.6)
	if e > 4.4:
		v = 1.0
	elif e < 0.9:
		v = 1 - 0.86 * (e / 0.9) ** 0.75
	else:
		v = 0.14 + 0.86 * min(1, (e - 0.9) / 3.5) ** 1.7
	v = min(1, max(0.12, v)); d = min(1, (1 - v) * 1.1)
	return (1 + 0.2 * d, 1 - 0.42 * d, 1 - 0.78 * d, v)


def lum(p):
	return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def frames(path, mode, n, lamp_xy):
	im = Image.open(path).convert("RGB")
	px = im.load()
	# the lamp's light: warm pixels, weighted by how far above the room's dark they are
	light = {}
	for y in range(im.height):
		for x in range(im.width):
			r, g, b = px[x, y]
			if r > b + 25 and lum((r, g, b)) > 60:
				light[(x, y)] = min(1.0, (lum((r, g, b)) - 60) / 120)
	out = []
	for i in range(n):
		cr, cg, cb, v = flicker_at(mode, i * 1000 / 30, *lamp_xy)
		f = im.copy(); q = f.load()
		for (x, y), w in light.items():
			r, g, b = px[x, y]
			dark = (r * 0.28, g * 0.30, b * 0.42)
			k = v
			nr = dark[0] + (r * cr - dark[0]) * k
			ng = dark[1] + (g * cg - dark[1]) * k
			nb = dark[2] + (b * cb - dark[2]) * k
			q[x, y] = (int(min(255, r + (nr - r) * w)), int(min(255, g + (ng - g) * w)), int(min(255, b + (nb - b) * w)))
		out.append(f)
	return out


if __name__ == "__main__":
	src, dst, mode = sys.argv[1], sys.argv[2], int(sys.argv[3])
	xy = (int(sys.argv[4]), int(sys.argv[5])) if len(sys.argv) > 5 else (40, 20)
	fs = frames(src, mode, 30 * 8, xy)
	big = [f.resize((288, 256), Image.NEAREST) for f in fs]
	big[0].save(dst, save_all=True, append_images=big[1:], duration=33, loop=0, lossless=True)
	print(dst)
