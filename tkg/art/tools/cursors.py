# -*- coding: utf-8 -*-
"""Three candidate mouse cursors, drawn rather than generated.

    python art/tools/cursors.py

Writes 16x16 sources and 32x32 doubles into `art/cursors/`. Sixteen because the
game is authored at 960x540 and presented at 1920x1080 with integer scaling, so
a cursor that is to look like it belongs to the art has to be drawn in art
pixels and doubled -- the same rule every sprite in the project follows.

EVERY STROKE CARRIES ITS OWN SHADOW. A cursor crosses a white hull, a black
sky, an amber card and a grey panel in one sweep, and a shape that reads on any
of them alone disappears on one of the others. One pixel of VOID behind each
lit pixel costs nothing and makes the shape independent of what is under it.

No PixelLab. These are rectangles and lines, which is what a cursor is.
"""
import os
import struct
import zlib

W = H = 16
OUT = os.path.join(os.path.dirname(__file__), "..", "cursors")

ICE = (0xc3, 0xd2, 0xe2, 255)
EMBER = (0xd9, 0x7b, 0x29, 255)
TRACTOR = (0x8e, 0xc8, 0xe6, 255)
VOID = (0x0a, 0x0e, 0x15, 255)
CLEAR = (0, 0, 0, 0)


class Grid(object):
	def __init__(self):
		self.px = [[CLEAR for _ in range(W)] for _ in range(H)]

	def put(self, x, y, c):
		if 0 <= x < W and 0 <= y < H:
			self.px[y][x] = c

	def hline(self, x0, x1, y, c):
		for x in range(x0, x1 + 1):
			self.put(x, y, c)

	def vline(self, x, y0, y1, c):
		for y in range(y0, y1 + 1):
			self.put(x, y, c)

	def box(self, x0, y0, x1, y1, c):
		self.hline(x0, x1, y0, c)
		self.hline(x0, x1, y1, c)
		self.vline(x0, y0, y1, c)
		self.vline(x1, y0, y1, c)

	def shadow(self):
		"""VOID under and right of every lit pixel that has nothing there."""
		lit = [(x, y) for y in range(H) for x in range(W)
			if self.px[y][x][3] > 0]
		for x, y in lit:
			for dx, dy in ((1, 0), (0, 1), (1, 1), (-1, 0), (0, -1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < W and 0 <= ny < H and self.px[ny][nx][3] == 0:
					self.px[ny][nx] = VOID


def reticle():
	"""A targeting mark. The same vocabulary the mounts and the enemy
	brackets already speak, with a hole in the middle so it never covers the
	thing it is pointing at."""
	g = Grid()
	g.vline(8, 1, 5, ICE)
	g.vline(8, 11, 15, ICE)
	g.hline(1, 5, 8, ICE)
	g.hline(11, 15, 8, ICE)
	# Corner ticks: the reticle closing, without a full frame.
	for cx, cy, sx, sy in ((3, 3, 1, 1), (13, 3, -1, 1),
			(3, 13, 1, -1), (13, 13, -1, -1)):
		g.put(cx, cy, TRACTOR)
		g.put(cx + sx, cy, TRACTOR)
		g.put(cx, cy + sy, TRACTOR)
	g.put(8, 8, EMBER)
	g.shadow()
	return g, (8, 8)


def caliper():
	"""An instrument rather than a weapon: a measuring arm with one jaw, so
	it points the way an arrow does without being one."""
	g = Grid()
	for i in range(11):
		g.put(1 + i, 1 + i, ICE)
	# The jaw, square to the shaft at its far end.
	g.hline(6, 11, 12, ICE)
	g.vline(12, 6, 11, ICE)
	g.put(12, 12, EMBER)
	# And the head, which is what you actually aim.
	g.put(2, 1, ICE)
	g.put(1, 2, ICE)
	g.put(1, 1, EMBER)
	g.shadow()
	return g, (1, 1)


def cell():
	"""One hold cell. The grid is what this whole game is about, so the
	pointer is a piece of it, with the corner you are actually aiming lit."""
	g = Grid()
	g.box(1, 1, 11, 11, ICE)
	g.hline(1, 4, 1, EMBER)
	g.vline(1, 1, 4, EMBER)
	g.put(6, 6, TRACTOR)
	g.shadow()
	return g, (1, 1)


def write(path, rows, scale):
	w, h = len(rows[0]) * scale, len(rows) * scale
	raw = b""
	for row in rows:
		line = b""
		for px in row:
			line += bytes(bytearray(px)) * scale
		raw += (b"\x00" + line) * scale

	def chunk(tag, data):
		return (struct.pack(">I", len(data)) + tag + data
			+ struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

	head = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
	blob = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head)
		+ chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
	f = open(path, "wb")
	f.write(blob)
	f.close()


def main():
	if not os.path.isdir(OUT):
		os.makedirs(OUT)
	for name, make in (("reticle", reticle), ("caliper", caliper),
			("cell", cell)):
		g, hot = make()
		write(os.path.join(OUT, "%s.png" % name), g.px, 1)
		write(os.path.join(OUT, "%s_2x.png" % name), g.px, 2)
		print("  %-8s hotspot %s" % (name, hot))


main()
