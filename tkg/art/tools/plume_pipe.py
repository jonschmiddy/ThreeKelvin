"""Turn a PixelLab animate_image result into a game-ready thruster strip.

    python art/tools/plume_pipe.py NAME RAMP frame0.png frame1.png ...

PixelLab draws far better fire than anything worth hand-rolling -- billowing,
turbulent, genuinely alight. What it will not do is leave the flame alone: every
roll welds a rocket body, a nozzle bell or a whole aircraft onto the hot end,
which is the same "nothing comes back bare" behaviour ASSET_PIPELINE.md records
for hulls. So the flame is generated and the hardware is removed here.

THE FILTER IS BY TEMPERATURE, not by position. The welded-on parts are cool
grey-blue metal; the plume is warm or white-hot. One comparison separates them
and it does not care where on the canvas the intruder landed. For the cold ramps
(plasma, violet, viridian) the test inverts, because there the FLAME is the cool
thing and any warm pixel is a stray.

Output is one horizontal strip of equal frames -- the layout
`ShipView._flame_frames()` already slices -- with the nozzle end flush right.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt

# Which end of the spectrum the flame lives on, per ramp.
WARM = {"heat", "whitehot"}
COOL = {"plasma", "violet", "viridian"}


def is_flame(r, g, b, ramp):
	"""True if this pixel is fire rather than welded-on hardware.

	The WARM ramps test by hue, which works because their hardware is cool grey
	and their flame is not.

	THE COOL RAMPS CANNOT TEST BY HUE and used to try. Two ways it failed, both
	measured: a violet plume is magenta, so `b > r` is FALSE for its brightest
	pixels and the flame was stripped instead of the nozzle; and a blue-grey
	steel bell satisfies `b > r + 18` outright, so the nozzle came through as
	flame. Hue does not separate them because on a cool ramp the flame and the
	metal are the same hue.

	VIVIDNESS does. A plasma flame is either near-white at its core or violently
	saturated at its edge; a nozzle is a muted mid-tone, whatever colour it is.
	Thresholds read off the art rather than guessed: across the plasma, violet
	and viridian rolls the flame stops sit at value 111-255 with saturation
	0.19-0.94, and every one of them clears one of the two tests below, while
	the nozzle stops (value 8-124, saturation 0.38-0.54) clear neither.
	"""
	mn, mx = min(r, g, b), max(r, g, b)
	if mx - mn < 26 and mx < 210:
		return False          # desaturated and not white-hot: metal
	if ramp in WARM:
		return r > b + 18 or mn > 200
	sat = 0.0 if mx == 0 else float(mx - mn) / float(mx)
	return mx >= 200 or (sat >= 0.6 and mx >= 110)


def clean(w, h, rows, ramp):
	out = [bytearray(w * 4) for _ in range(h)]
	kept = dropped = 0
	for y in range(h):
		for x in range(w):
			o = x * 4
			if not rows[y][o + 3]:
				continue
			r, g, b = rows[y][o], rows[y][o + 1], rows[y][o + 2]
			if is_flame(r, g, b, ramp):
				out[y][o:o + 4] = bytes((r, g, b, 255))
				kept += 1
			else:
				dropped += 1
	return out, kept, dropped


def despeckle(w, h, rows):
	"""Drop lit pixels with fewer than two lit neighbours.

	Stripping the hardware leaves a scatter of single pixels where the metal met
	the flame. One orphan pixel floating off a plume reads as a rendering fault,
	not as a spark.
	"""
	out = [bytearray(r) for r in rows]
	for y in range(h):
		for x in range(w):
			if not rows[y][x * 4 + 3]:
				continue
			n = 0
			for dy in (-1, 0, 1):
				for dx in (-1, 0, 1):
					if dx == 0 and dy == 0:
						continue
					yy, xx = y + dy, x + dx
					if 0 <= yy < h and 0 <= xx < w and rows[yy][xx * 4 + 3]:
						n += 1
			if n < 2:
				out[y][x * 4:x * 4 + 4] = b"\x00\x00\x00\x00"
	return out


def build(name, ramp, paths, dest):
	frames = []
	W = H = 0
	for p in paths:
		w, h, rows = pt.decode(p)
		W, H = w, h
		rows, kept, dropped = clean(w, h, rows, ramp)
		rows = despeckle(w, h, rows)
		frames.append(rows)
		print("  %-14s kept %5d  stripped %4d" % (os.path.basename(p), kept, dropped))

	# Common ink box across every frame, so the plume does not jitter when the
	# strip is sliced. Per-frame cropping would make the anchor wander.
	x0, y0, x1, y1 = W, H, -1, -1
	for rows in frames:
		b = pt.bbox(W, H, rows)
		if b is None:
			continue
		x0, y0 = min(x0, b[0]), min(y0, b[1])
		x1, y1 = max(x1, b[2]), max(y1, b[3])
	fw, fh = x1 - x0 + 1, y1 - y0 + 1

	n = len(frames)
	out = [bytearray(fw * n * 4) for _ in range(fh)]
	for i, rows in enumerate(frames):
		for y in range(fh):
			src = rows[y0 + y]
			out[y][i * fw * 4:(i + 1) * fw * 4] = src[x0 * 4:(x1 + 1) * 4]

	if not os.path.isdir(dest):
		os.makedirs(dest)
	p = os.path.join(dest, name + ".png")
	pt.encode(p, fw * n, fh, out)
	print("  -> %s  frame %dx%d  strip %dx%d  %d frames  %d colours"
	      % (os.path.basename(p), fw, fh, fw * n, fh, n,
	         len(pt.palette(fw * n, fh, out))))
	return p


def main(argv):
	if len(argv) < 3:
		print(__doc__)
		return 1
	name, ramp, paths = argv[0], argv[1], argv[2:]
	here = os.path.dirname(os.path.abspath(__file__))
	dest = os.path.abspath(os.path.join(here, "..", "sprites", "thrusters"))
	print("%s  (%s ramp, %d frames)" % (name, ramp, len(paths)))
	build(name, ramp, paths, dest)
	return 0



# --------------------------------------------------------------------------
# Everything below was learned building the 24-strip library and belongs beside
# the filter above rather than in a scratch file that gets wiped.
# See docs/art/EXHAUST_PIPELINE.md for the order these run in and why.
# --------------------------------------------------------------------------


def keep_body(w, h, rows):
	"""Keep only the largest 8-connected component.

	despeckle() removes ORPHANS; this removes ISLANDS. A nozzle's specular
	highlight is a 6px run of near-white that passes the flame test and floats
	free of the plume, reading as a rendering fault rather than as a spark.

	Iterative, not recursive: a 112x48 plume is ~5000 lit pixels and a recursive
	fill blows the stack well before that.
	"""
	seen = [bytearray(w) for _ in range(h)]
	best, best_n = None, 0
	for sy in range(h):
		for sx in range(w):
			if seen[sy][sx] or not rows[sy][sx * 4 + 3]:
				continue
			comp, stack = [], [(sx, sy)]
			seen[sy][sx] = 1
			while stack:
				x, y = stack.pop()
				comp.append((x, y))
				for dy in (-1, 0, 1):
					for dx in (-1, 0, 1):
						xx, yy = x + dx, y + dy
						if (0 <= xx < w and 0 <= yy < h and not seen[yy][xx]
								and rows[yy][xx * 4 + 3]):
							seen[yy][xx] = 1
							stack.append((xx, yy))
			if len(comp) > best_n:
				best, best_n = comp, len(comp)
	out = [bytearray(w * 4) for _ in range(h)]
	for x, y in best or []:
		out[y][x * 4:x * 4 + 4] = rows[y][x * 4:x * 4 + 4]
	return out, best_n


def column_counts(w, h, rows):
	return [sum(1 for y in range(h) if rows[y][x * 4 + 3]) for x in range(w)]


def trim_hardware(w, h, rows, frac=0.35, floor=3):
	"""Cut back to the last column that is really plume.

	The temperature filter cannot save a nozzle drawn in the same VALUE as the
	flame -- one bell came back as white bars against a white core, and no
	colour rule separates those. Geometry does: a plume is thickest where it
	leaves the bell, so the last column carrying a real share of its peak
	thickness is the attachment point, and everything right of it is scenery.
	"""
	col = column_counts(w, h, rows)
	peak = max(col) if col else 0
	if not peak:
		return rows, 0
	need = max(floor, int(peak * frac))
	solid = [x for x, c in enumerate(col) if c >= need]
	if not solid:
		return rows, 0
	edge, n = max(solid), 0
	for y in range(h):
		for x in range(edge + 1, w):
			o = x * 4
			if rows[y][o + 3]:
				rows[y][o + 3] = 0
				n += 1
	return rows, n


def common_edge(counts, frac=0.35, floor=4):
	"""Rightmost column carrying real flame in EVERY frame of a sequence.

	Judging each frame against its own thickest column over-trims: one frame
	with a thin nozzle mouth pulls the threshold up and takes fourteen columns
	off all nine. What matters is not how thick a column is in its best frame
	but how thick it is in its WORST, so the test runs on the per-column
	minimum across the sequence.
	"""
	if not counts:
		return None
	mins = [min(c[x] for c in counts) for x in range(len(counts[0]))]
	peak = max(mins) if mins else 0
	if not peak:
		return None
	need = max(floor, int(peak * frac))
	solid = [x for x, m in enumerate(mins) if m >= need]
	return max(solid) if solid else None


def fill_holes(w, h, rows):
	"""Re-light transparent pixels ringed on all four sides by lit ones.

	clean() drops pixels by colour, so a cool-tinted pixel INSIDE the flame
	fails the test and leaves a hole punched through the sprite. Against the
	void behind a ship, that shows.
	"""
	n = 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			o = x * 4
			if rows[y][o + 3]:
				continue
			if (rows[y - 1][o + 3] and rows[y + 1][o + 3]
					and rows[y][o - 4 + 3] and rows[y][o + 4 + 3]):
				rows[y][o:o + 4] = rows[y][o - 4:o]
				n += 1
	return n


_BIG = 1 << 20


def edge_distance(w, h, rows):
	"""Chamfer 3-4 distance from each lit pixel to the nearest empty one."""
	d = [[0 if not rows[y][x * 4 + 3] else _BIG for x in range(w)]
	     for y in range(h)]
	for y in range(h):
		for x in range(w):
			if not d[y][x]:
				continue
			best = 4 if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else _BIG
			for dx, dy, c in ((-1, 0, 3), (1, 0, 3), (0, -1, 3), (0, 1, 3),
			                  (-1, -1, 4), (1, -1, 4)):
				xx, yy = x + dx, y + dy
				if (0 <= xx < w and 0 <= yy < h
						and (yy < y or (yy == y and xx < x))):
					best = min(best, d[yy][xx] + c)
			d[y][x] = min(d[y][x], best)
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			if not d[y][x]:
				continue
			best = d[y][x]
			for dx, dy, c in ((1, 0, 3), (-1, 0, 3), (0, 1, 3), (0, -1, 3),
			                  (1, 1, 4), (-1, 1, 4)):
				xx, yy = x + dx, y + dy
				if (0 <= xx < w and 0 <= yy < h
						and (yy > y or (yy == y and xx > x))):
					best = min(best, d[yy][xx] + c)
			d[y][x] = best
	return d


def _noise(cx, cy):
	"""Deterministic 0..1 per noise cell.

	A hash rather than random, for two reasons. It is reproducible, so a rebuild
	does not reshuffle the sprite. And it is COHERENT at a small scale --
	neighbours share a value -- so a tail breaks into flecks and wisps instead
	of dissolving into per-pixel dust, which reads as noise rather than as fire.
	"""
	n = (cx * 374761393 + cy * 668265263) & 0xFFFFFFFF
	n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
	return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def erode(w, h, rows, start=0.45, bite=0.95, depth=4, cell=2, passes=3, phase=0):
	"""Dissipate a tail by eating it from the OUTSIDE IN.

	The first version removed pixels wherever the noise said so, which punched
	black holes through the middle of a dense plume -- that reads as damage, not
	as fire thinning out. Real dissipation eats the boundary: the outer skin
	goes first and the core survives longest.

	`depth` is how many pixels in from the edge stay erodible, and it HAS TO
	SCALE WITH THE PLUME -- four is a rim on a 40px heavy and most of the radius
	on a 20px light, where it opens holes. `phase` varies the noise per frame so
	shed embers move between frames instead of freezing in place.
	"""
	out = [bytearray(r) for r in rows]
	b = pt.bbox(w, h, out)
	if b is None:
		return out, 0
	x0, _, x1, _ = b
	span = float(max(1, x1 - x0))
	cut = 0
	for p in range(passes):
		d = edge_distance(w, h, out)
		doomed = []
		for y in range(h):
			for x in range(x0, x1 + 1):
				if not out[y][x * 4 + 3]:
					continue
				t = (x1 - x) / span
				if t <= start:
					continue
				g = ((t - start) / (1.0 - start)) ** 1.5
				skin = max(0.0, 1.0 - (d[y][x] / 3.0 - 1.0) / depth)
				if skin <= 0.0:
					continue
				if _noise(x // cell + (p + phase * 7) * 977,
				          y // cell + (p + phase * 7) * 641) < g * bite * skin:
					doomed.append((x, y))
		for x, y in doomed:
			out[y][x * 4 + 3] = 0
		cut += len(doomed)
	return out, cut


def sequence(paths, ramp="heat", source=None, rim=True):
	"""Frames -> one strip, cropped, eroded, and anchored on the nozzle.

	`source` is the palette of the approved STILL. animate_image invents colours
	-- one plume came back with 67 on a still that carried 21 -- and pt.snap's
	docstring names the fix: snap to the source sprite's OWN palette, never to
	the project ramp, so an approved look stays approved.

	Returns (frame_w, frame_h, rows, report).
	"""
	frames, W, H, edges = [], 0, 0, []
	holes = empty = 0
	for p in paths:
		w, h, rows = pt.decode(p)
		W, H = w, h
		rows, _kept, _dropped = clean(w, h, rows, ramp)
		rows = despeckle(w, h, rows)
		rows, _ = keep_body(w, h, rows)
		holes += fill_holes(w, h, rows)
		edges.append(column_counts(w, h, rows))
		if source:
			pt.snap(w, h, rows, source)
		frames.append(rows)

	# ONE edge for the whole sequence: the last column solid in every frame.
	# Everything right of it goes, so the attachment point can neither blink
	# nor wander -- the two faults that make a plume look detached from a ship.
	edge = common_edge(edges)
	if edge is None:
		per = [max([x for x, c in enumerate(cnt) if c] or [0]) for cnt in edges]
		edge = sorted(per)[len(per) // 2]
	for rows in frames:
		for y in range(H):
			for x in range(edge + 1, W):
				rows[y][x * 4 + 3] = 0

	for i, rows in enumerate(frames):
		if rim:
			rows, _ = erode(W, H, rows, start=0.0, bite=0.22, depth=1,
			                cell=1, passes=1, phase=i)
		ink = pt.bbox(W, H, rows)
		if ink is None:
			empty += 1
			frames[i] = rows
			continue
		frames[i], _ = erode(W, H, rows,
		                     depth=max(2, (ink[3] - ink[1] + 1) // 10), phase=i)

	boxes = [pt.bbox(W, H, r) for r in frames]
	live = [b for b in boxes if b is not None]
	if not live:
		raise ValueError("every frame cleaned to nothing")
	y0, y1 = min(b[1] for b in live), max(b[3] for b in live)
	fw = max(b[2] - b[0] + 1 for b in live) + 1
	fh = y1 - y0 + 1
	n = len(frames)
	out = [bytearray(fw * n * 4) for _ in range(fh)]
	for i, rows in enumerate(frames):
		shift = (i + 1) * fw - 1 - edge
		for y in range(fh):
			src = rows[y0 + y]
			for x in range(W):
				o = x * 4
				if not src[o + 3]:
					continue
				tx = x + shift
				if i * fw <= tx < (i + 1) * fw:
					out[y][tx * 4:tx * 4 + 4] = src[o:o + 4]
	return fw, fh, out, dict(holes=holes, empty=empty, edge=edge, frames=n)

if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
