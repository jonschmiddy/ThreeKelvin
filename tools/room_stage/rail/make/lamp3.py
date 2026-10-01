"""The Hiring Board's shaded lamp: the same dim room and the same fault as
lamp2, with the light thrown round the shade and down, and a pool on the floor
under it."""
import math
import sys
from PIL import Image
import lamp2
from lamp2 import BAYER, AMBIENT


def shade_map(w, h, lamp, reach, pool):
	L = [[0.0] * w for _ in range(h)]
	for y in range(h):
		for x in range(w):
			dx = x - lamp[0]; dy = y - lamp[1]
			# a shade throws its light down: above it, the light falls off twice as fast
			r = math.hypot(dx, dy * (2.0 if dy < 0 else 1.0))
			k = max(0.0, 1 - max(0.0, r - 10) / reach)
			px, py, rx, ry = pool
			e = math.hypot((x - px) / rx, (y - py) / ry)
			k = max(k, max(0.0, 1 - e) * 1.4)
			k = min(1.0, k)
			if k < 0.5:
				# the edge, dithered: lit or not, never a haze
				k = 0.5 if k * 32 > BAYER[y % 4][x % 4] else 0.0
			L[y][x] = max(k, AMBIENT + 0.30 * math.exp(-r / 16))
	return L


if __name__ == "__main__":
	src, dst, mode = sys.argv[1], sys.argv[2], int(sys.argv[3])
	xy = (int(sys.argv[4]), int(sys.argv[5]))
	lamp2.HOT_ALL = True
	lamp2.MOTES = int(sys.argv[6]) if len(sys.argv) > 6 else 0
	lamp2.light_map = lambda w, h, cone, lamp, reach: shade_map(w, h, lamp, reach, (45, 117, 42, 9))
	fs = lamp2.frames(src, mode, 30 * 8, xy, None, (47, 62), 62, (35, 51, 60, 69))
	big = [f.resize((288, 256), Image.NEAREST) for f in fs]
	big[0].save(dst, save_all=True, append_images=big[1:], duration=33, loop=0, lossless=True)
	big[0].save(dst.replace(".webp", "_still.png"))
	print(dst)
