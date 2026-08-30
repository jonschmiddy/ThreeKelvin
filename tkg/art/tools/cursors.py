# -*- coding: utf-8 -*-
"""The pointer, in two states.

    python art/tools/cursors.py

Writes 16x16 sources and 32x32 doubles into `art/cursors/`. Sixteen because the
game is authored at 960x540 and presented at 1920x1080 with integer scaling, so
a cursor that is to look like it belongs to the art has to be drawn in art
pixels and doubled -- the same rule every sprite in the project follows.

FOUR CORNERS AND A DOT, and no crosshair. The bars were the half that had to
cross whatever you were pointing at to reach the middle, which is the one thing
a pointer must not do; the corners say the same thing from outside the target
and leave it visible. What is left is a reticle closing on something rather
than a set of sights laid over it.

AND IT CLOSES. `reticle` is the resting state and `reticle_hot` is the same
four corners pulled in toward the dot -- the shape reacting to a thing worth
pressing, rather than a second shape replacing the first.

EVERY STROKE CARRIES ITS OWN SHADOW. A cursor crosses a white hull, a black
sky, an amber card and a grey panel in one sweep, and a shape that reads on any
of them alone disappears on one of the others. One pixel of VOID behind each
lit pixel costs nothing and makes the shape independent of what is under it.

No PixelLab. These are rectangles, which is what a cursor is.
"""
import os
import struct
import zlib

W = H = 16
OUT = os.path.join(os.path.dirname(__file__), "..", "cursors")

ICE = (0xc3, 0xd2, 0xe2, 255)
EMBER = (0xd9, 0x7b, 0x29, 255)
VOID = (0x0a, 0x0e, 0x15, 255)
CLEAR = (0, 0, 0, 0)


class Grid(object):
	def __init__(self):
		self.px = [[CLEAR for _ in range(W)] for _ in range(H)]

	def put(self, x, y, c):
		if 0 <= x < W and 0 <= y < H:
			self.px[y][x] = c

	def shadow(self):
		"""VOID in every empty pixel touching a lit one."""
		lit = [(x, y) for y in range(H) for x in range(W)
			if self.px[y][x][3] > 0]
		for x, y in lit:
			for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1),
					(1, 1), (-1, -1), (1, -1), (-1, 1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < W and 0 <= ny < H and self.px[ny][nx][3] == 0:
					self.px[ny][nx] = VOID


def reticle(gap, arm):
	"""`gap` is how far each corner sits from the centre pixel, `arm` how long
	its two legs are. Closing the gap is the whole animation."""
	g = Grid()
	c = 8
	for sx in (-1, 1):
		for sy in (-1, 1):
			x, y = c + gap * sx, c + gap * sy
			g.put(x, y, ICE)
			for i in range(1, arm + 1):
				g.put(x - i * sx, y, ICE)
				g.put(x, y - i * sy, ICE)
	# THE PIXEL YOU ARE ACTUALLY POINTING WITH. Four corners describe a box and
	# a box has no point; this is where the click lands.
	g.put(c, c, EMBER)
	g.shadow()
	return g


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
	# SIX OUT TO THREE IN, AS FOUR FRAMES.
	#
	# A custom mouse cursor in Godot is one static texture per shape; there is
	# no animated form of it. So the animation is the frames, and `Main` swaps
	# them -- which is worth the trouble over drawing the pointer ourselves,
	# because a cursor we paint is a cursor one frame behind the mouse and a
	# hardware one never is.
	#
	# The arm stays at two the whole way and only the corners travel. Shrinking
	# both at once read as a different shape arriving rather than as this one
	# closing, which is the entire point of doing it in steps.
	for i, gap in enumerate((6, 5, 4, 3)):
		g = reticle(gap, 2)
		write(os.path.join(OUT, "reticle_%d.png" % i), g.px, 1)
		write(os.path.join(OUT, "reticle_%d_2x.png" % i), g.px, 2)
		print("  reticle_%d    gap %d" % (i, gap))


main()
