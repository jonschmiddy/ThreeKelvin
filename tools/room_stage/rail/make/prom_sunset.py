"""The Promenade at sunset (Jon: "maybe do the promenade at sunset").

A colour grade on the concourse: its shadows go violet and its lights go
orange, with a sky-side gradient top to bottom. The shop windows keep their
own light, and the sign keeps the Starter fault. Three ideas:
  gold  -- a golden wash, warm all over
  dusk  -- pink above, violet in the shadows, the windows the warmest thing
  rake  -- low sun raking in from the right in slanted beams, dithered edges
"""
import sys
from PIL import Image
from lamp import flicker_at, fnoise

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
LOOKS = {
	#        shadow tint         light tint          top tint            bottom tint         gain
	"gold": ((0.80, 0.62, 0.70), (1.35, 1.00, 0.62), (1.10, 0.90, 0.75), (1.15, 0.95, 0.70), 1.00),
	"dusk": ((0.62, 0.45, 0.95), (1.30, 0.80, 0.75), (1.20, 0.70, 0.95), (0.95, 0.70, 0.95), 0.90),
	"rake": ((0.55, 0.45, 0.85), (1.10, 0.85, 0.80), (1.00, 0.80, 0.95), (0.95, 0.75, 0.95), 0.92),
}


def lum(p):
	return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def lerp(a, b, t):
	return tuple(x + (y - x) * t for x, y in zip(a, b))


def render(src, look, out_path, n):
	im = Image.open(src).convert("RGB"); w, h = im.size
	px = im.load()
	sh, li, top, bot, gain = LOOKS[look]
	base = Image.new("RGB", (w, h)); bp = base.load()
	win = set(); sign = set(); rake = {}
	for y in range(h):
		for x in range(w):
			p = px[x, y]; l = lum(p)
			if l > 130 and p[0] > p[2] + 40:
				win.add((x, y)); bp[x, y] = p; continue
			# the sign only, by where it hangs: the potted plants are the same
			# green and flickered with it (Jon: "you are lighting up this tree")
			# its pale face is tube too: lit when the sign is, dead when it is not
			if 118 <= x <= 143 and 50 <= y <= 63 and ((p[1] > 150 and p[1] > p[0] + 40) or (l > 150 and 122 <= x <= 141 and 55 <= y <= 62)):
				sign.add((x, y)); bp[x, y] = p; continue
			t = min(1.0, l / 160)
			c = lerp(sh, li, t)
			v = lerp(top, bot, y / h)
			k = gain
			shade = tuple(int(max(0, min(255, ch * c[i] * v[i] * k))) for i, ch in enumerate(p))
			bp[x, y] = shade
			if look == "rake":
				# beams from the low sun, slanting down to the left; which pixels
				# they fall on is settled per frame, so their shadows can flutter
				cl = (c[0] * 1.9, c[1] * 1.35, c[2] * 0.7)
				lit = tuple(int(max(0, min(255, ch * cl[i] * v[i] * gain * 1.5))) for i, ch in enumerate(p))
				rake[(x, y)] = (shade, lit, x * 1.0 + y * 0.9)
	# THE SIGN'S GLOW on the wall round it: how near each pixel is to the tube,
	# dithered into bands so it reads as pixel light, not a haze.
	import math
	glow = {}
	for y in range(h):
		for x in range(w):
			if (x, y) in sign:
				continue
			d = min((math.hypot(x - sx, y - sy) for sx, sy in sign), default=99)
			if d < 9:
				g = math.exp(-d / 3.2)
				g = math.floor(g * 4 + BAYER[y % 4][x % 4] / 16) / 4
				if g > 0:
					glow[(x, y)] = g
	frames = []; ones = []
	for i in range(n):
		cr, cg, cb, fv = flicker_at(1, i * 1000 / 30, 40, 20)
		f = base.copy(); q = f.load()
		# THE SHADOWS FLUTTER (Jon: "a slight flutter in the shadow"): something
		# between the sun and the windows -- every beam's edges shiver a pixel or
		# so, each on its own noise, and the light dips a touch now and then.
		tt = i / 30
		# (Jon: "too much flutter" -- a third of the shiver, slower, no fast part)
		dip = 0.97 + 0.03 * fnoise(tt * 0.5 + 4.1)
		shift = [0.9 * (fnoise(tt * 1.1 + j * 3.7) - 0.5) for j in range(8)]
		for (x, y), (shade, lit, uu) in rake.items():
			j = int(uu // 52) % 8
			u = (uu + shift[j]) % 52
			b = 10 < u < 30
			if not b and (7 < u <= 10 or 30 <= u < 33):
				b = BAYER[y % 4][x % 4] < 8
			if b:
				q[x, y] = tuple(int(sv + (lv - sv) * dip) for sv, lv in zip(shade, lit))
		for (x, y) in sign:
			p = px[x, y]
			# off: dead glass, grey-green; on: the tube, with the Starter's
			# blue-white cast while it strikes
			off = (p[0] * 0.20 + 18, p[1] * 0.22 + 22, p[2] * 0.22 + 20)
			on = (p[0] * cr * 1.1, p[1] * cg * 1.1, p[2] * cb * 1.1)
			q[x, y] = tuple(int(max(0, min(255, a + (b - a) * fv))) for a, b in zip(off, on))
		for (x, y), g in glow.items():
			r0, g0, b0 = q[x, y]; k = g * fv * 0.55
			q[x, y] = (int(min(255, r0 + 40 * k * cr)), int(min(255, g0 + 190 * k * cg)), int(min(255, b0 + 120 * k * cb)))
		ones.append(f)
		frames.append(f.resize((w * 2, h * 2), Image.NEAREST))
	if out_path:
		frames[0].save(out_path, save_all=True, append_images=frames[1:], duration=33, loop=0, lossless=True)
		frames[0].save(out_path.replace(".webp", "_still.png"))
	return ones


if __name__ == "__main__":
	render(sys.argv[1], sys.argv[2], sys.argv[3], 30 * 8)
	print(sys.argv[3])
