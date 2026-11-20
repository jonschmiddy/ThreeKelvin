class_name MiniPix
extends RefCounted

## A science mini game's screen: one low-res Image drawn a rectangle at a time, as the approved
## prototypes draw theirs (`TK.pixel`, `TK.text`, `TK.dither`, `TK.icon` in tk-scratch's minigames).
## The shell sets it on the desk's glass, an art pixel to a glass pixel.
## Why: docs/why/MiniGame.md#the-canvas

## The prototypes' `TK.PAL`: the game's own colours (UITheme), plus the two rare tiers.
const VOID := Color("#0a0e15")
const PANEL := Color("#111823")
const LINE := Color("#22303f")
const BEVEL_HI := Color("#3d4d61")
const BEVEL_LO := Color("#080b11")
const COLD := Color("#6b7d94")
const CHILL := Color("#8fa3ba")
const ICE := Color("#c3d2e2")
const EMBER := Color("#d97b29")
const FLARE := Color("#ff9d3d")
const HOT := Color("#ffd28a")
const GOOD := Color("#7fb89a")
const WARN := Color("#b8923f")
const BAD := Color("#c8503c")
const MARK := Color("#b8f5d8")
const TRACTOR := Color("#4fe0cc")
const BRACE := Color("#9fb0c4")
const THEM := Color("#c98d7a")
const TIERS: Array[Color] = [Color("#98a0a8"), Color("#4fbf82"), Color("#6a9ad4"), Color("#8b4fd4"),
	Color("#d99b29"), Color("#e05fa8"), Color("#e0402e")]
## The 2x2 ordered dither the prototypes share.
const BAYER: Array[int] = [0, 2, 3, 1]
## The 4x4 one most of the round 2 games shade with (`bay`).
const BAY16: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## The control icons' widths, as the prototypes' start cards lay them out (`ICW`).
const ICW := {"click": 13, "hold": 21, "drag": 22, "drag-h": 22, "drag-v": 22, "dial": 13}
## `TK.text`'s 3x5 font, 4 px advance (rows of three, top to bottom).
const FONT := {
	"A": ".#.#.#####.##.#", "B": "##.#.###.#.###.", "C": ".###..#..#...##", "D": "##.#.##.##.###.",
	"E": "####..##.#..###", "F": "####..##.#..#..", "G": ".###..#.##.#.##", "H": "#.##.#####.##.#",
	"I": "###.#..#..#.###", "J": "..#..#..##.#.#.", "K": "#.##.###.#.##.#", "L": "#..#..#..#..###",
	"M": "#.########.##.#", "N": "##.#.##.##.##.#", "O": ".#.#.##.##.#.#.", "P": "##.#.###.#..#..",
	"Q": ".#.#.##.###..##", "R": "##.#.###.#.##.#", "S": ".###...#...###.", "T": "###.#..#..#..#.",
	"U": "#.##.##.##.####", "V": "#.##.##.##.#.#.", "W": "#.##.########.#", "X": "#.##.#.#.#.##.#",
	"Y": "#.##.#.#..#..#.", "Z": "###..#.#.#..###", "0": "####.##.##.####", "1": ".#.##..#..#.###",
	"2": "##...#.#.#..###", "3": "##...#.#...###.", "4": "#.##.####..#..#", "5": "####..##...###.",
	"6": ".###..####.####", "7": "###..#.#..#..#.", "8": "####.#####.####", "9": "####.####..###.",
	" ": "...............", ".": ".............#.", ",": "..........#.#..", ":": "....#.....#....",
	"-": "......###......", "+": "....#.###.#....", "/": "..#..#.#.#..#..", "%": "#.#..#.#.#..#.#",
	"!": ".#..#..#.....#.", "?": "##...#.#.....#.", ">": "#...#...#.#.#..", "<": "..#.#.#...#...#",
	"=": "...###...###...", "#": "#.#####.#####.#", "(": ".#.#..#..#...#.", ")": ".#...#..#..#.#.",
	"*": "#.#.#.###.#.#.#", "'": ".#..#..........",
	# not in the prototypes' font: the haul line's NAME [TIER] (Jon, Nov 19)
	"[": "##.#..#..#..##.", "]": ".##..#..#..#.##",
}
const MOUSE: Array[String] = ["...#####...", "..#..#..#..", ".#...#...#.", ".#...#...#.", ".#########.",
	".#.......#.", ".#.......#.", ".#.......#.", ".#.......#.", "..#.....#..", "...#####..."]
const DIAL: Array[String] = ["..#####..", ".#.....#.", "#...#...#", "#...#...#", "#...#...#", "#.......#",
	"#.......#", ".#.....#.", "..#####.."]

var w := 0
var h := 0
var img: Image


## A new canvas, or one drawing onto `into` (its size).
func _init(width: int, height: int, into: Image = null) -> void:
	w = width
	h = height
	img = into if into != null else Image.create(w, h, false, Image.FORMAT_RGBA8)


## JS `Math.round`: halves go up, negatives included (GDScript's `round` goes away from zero).
static func jr(v: float) -> int:
	return int(floorf(v + 0.5))


func clear(c: Color = VOID) -> void:
	img.fill(c)


## `fillRect` on whole pixels, clipped to the canvas.
func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	if rw <= 0 or rh <= 0:
		return
	img.fill_rect(Rect2i(x, y, rw, rh), c)


func dot(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		img.set_pixel(x, y, c)


## Another layer drawn over this one where it is opaque (`drawImage` of a canvas drawn once).
func blit(src: Image, x: int, y: int) -> void:
	img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x, y))


## Whether the dither pattern lights (x, y) at density t (the prototypes' `chk`).
static func lit(x: int, y: int, t: float) -> bool:
	return (BAYER[(y & 1) * 2 + (x & 1)] + 0.5) / 4.0 < t


## `TK.text`: upper case, 3x5, `align` "" (left), "center" or "right". Returns the width.
func text(s: String, x: int, y: int, c: Color, align := "") -> int:
	s = s.to_upper()
	var wpx := s.length() * 4 - 1
	if align == "center":
		x -= int(floorf(wpx / 2.0))
	elif align == "right":
		x -= wpx
	for ch in s:
		var gl: String = FONT.get(ch, "")
		if gl != "":
			for r in 5:
				for cc in 3:
					if gl[r * 3 + cc] == "#":
						dot(x + cc, y + r, c)
		x += 4
	return wpx


## `TK.dither`: an ordered 2x2 blend of a and b, t of b.
func dither(x: int, y: int, dw: int, dh: int, a: Color, b: Color, t: float) -> void:
	for j in dh:
		for i in dw:
			dot(x + i, y + j, b if lit(x + i, y + j, t) else a)


## `TK.icon`: the control icon of `kind` ("click", "hold", "drag", "drag-h", "drag-v", "dial",
## "key", "keys"), 13 px tall, animated by `t` seconds. Returns the width drawn.
func icon(kind: String, x: int, y: int, t: float = 0.0, label := "") -> int:
	var on := int(floorf(t * 2.0)) % 2 == 0
	match kind:
		"click":
			_mouse(x, y, on)
			if on:
				dot(x, y, HOT)
				dot(x + 1, y + 1, HOT)
				dot(x + 12, y, HOT)
			return 13
		"hold":
			_mouse(x, y, true)
			for i in 4:
				rect(x + 13 + i * 2, y + 10, 1, 2, EMBER if i < 1 + int(floorf(fmod(t * 3.0, 4.0))) else LINE)
			return 21
		"drag", "drag-h", "drag-v":
			_mouse(x, y, true)
			_drag_arrows(kind, x + 14, y + 6)
			return 22
		"dial":
			return _dial(x, y, on)
		"keys":
			return _keys(x, y, t, label if label != "" else "WASD")
		"key":
			return _key(x, y, on, label if label != "" else "SPACE")
	return 0


func _mouse(x: int, y: int, btn: bool) -> void:
	for r in MOUSE.size():
		for c in 11:
			if MOUSE[r][c] == "#":
				dot(x + c, y + r + 1, ICE)
	for r in range(1, 4):
		for c in range(2, 5):
			if MOUSE[r][c] == ".":
				dot(x + c, y + r + 1, EMBER if btn else LINE)
	for r in range(5, 10):
		for c in range(2, 9):
			if MOUSE[r][c] == ".":
				dot(x + c, y + r + 1, PANEL)


func _drag_arrows(kind: String, ax: int, ay: int) -> void:
	if kind != "drag-v":
		rect(ax, ay, 7, 1, HOT)
		for p: Vector2i in [Vector2i(5, -1), Vector2i(5, 1), Vector2i(1, -1), Vector2i(1, 1)]:
			dot(ax + p.x, ay + p.y, HOT)
	if kind == "drag-v":
		rect(ax + 3, ay - 4, 1, 9, HOT)
		for p: Vector2i in [Vector2i(2, -3), Vector2i(4, -3), Vector2i(2, 3), Vector2i(4, 3)]:
			dot(ax + p.x, ay + p.y, HOT)
	if kind == "drag":
		rect(ax + 3, ay - 4, 1, 9, HOT)


func _dial(x: int, y: int, on: bool) -> int:
	for r in 9:
		for c in 9:
			if DIAL[r][c] == "#":
				dot(x + c, y + r + 2, EMBER if r >= 1 and r <= 4 and c == 4 else ICE)
	var a: Array[Vector2i] = [Vector2i(10, 2), Vector2i(11, 3), Vector2i(11, 4), Vector2i(10, 5)]
	if not on:
		a.assign([Vector2i(10, 6), Vector2i(11, 7), Vector2i(11, 8), Vector2i(10, 9)])
	for p in a:
		dot(x + p.x, y + p.y, HOT)
	dot(x + 9, y + (2 if on else 9), HOT)
	return 13


func _keys(x: int, y: int, t: float, label: String) -> int:
	var ks := label.to_upper()
	var lit_k := int(floorf(t * 2.0)) % ks.length()
	for i in ks.length():
		var ch := ks[i]
		var col := 0 if ch == "A" else (1 if ch == "S" else (2 if ch == "D" else 1))
		_cap(ch, x + col * 10, y + (-9 if ch == "W" else 1), i == lit_k)
	return 30


func _cap(ch: String, cx: int, cy: int, on: bool) -> void:
	rect(cx, cy, 9, 1, ICE)
	rect(cx, cy + 9, 9, 1, ICE)
	rect(cx, cy, 1, 10, ICE)
	rect(cx + 8, cy, 1, 10, ICE)
	rect(cx + 1, cy + 1, 7, 8, LINE if on else PANEL)
	text(ch, cx + 3, cy + (2 if on else 3), HOT if on else ICE)


func _key(x: int, y: int, on: bool, label: String) -> int:
	var lab := label.to_upper()
	var kw := lab.length() * 4 + 5
	rect(x, y + 1, kw, 1, ICE)
	rect(x, y + 11, kw, 1, ICE)
	rect(x, y + 1, 1, 11, ICE)
	rect(x + kw - 1, y + 1, 1, 11, ICE)
	rect(x + 1, y + 2, kw - 2, 9, LINE if on else PANEL)
	rect(x + 1, y + 10, kw - 2, 1, BEVEL_LO)
	text(lab, x + 3, y + (4 if on else 5), HOT if on else ICE)
	return kw


# ---------------------------------------------------------------- shared by the round 2 games

static var _tones: Dictionary = {}


## The 4x4 Bayer threshold at (x, y), in 0..1.
static func bay(x: int, y: int) -> float:
	return (BAY16[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


## A colour's 8-bit channels.
static func c8(c: Color) -> Vector3i:
	return Vector3i(roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0))


static func _byte(v: float) -> int:
	return clampi(jr(v), 0, 255)


## The prototypes' `shade`: a lighter step toward white (f > 0) or a darker one (f < 0), in bytes.
static func shade(c: Color, f: float) -> Color:
	var k := Vector4(c.r, c.g, c.b, f)
	if _tones.has(k):
		return _tones[k]
	var v := c8(c)
	var o := Color8(_byte(v.x + (255 - v.x) * f), _byte(v.y + (255 - v.y) * f), _byte(v.z + (255 - v.z) * f)) if f >= 0.0 		else Color8(_byte(v.x * (1.0 + f)), _byte(v.y * (1.0 + f)), _byte(v.z * (1.0 + f)))
	_tones[k] = o
	return o


## The prototypes' `mix`: a of b by t, rounded to bytes.
static func mix(a: Color, b: Color, t: float) -> Color:
	var x := c8(a)
	var y := c8(b)
	return Color8(_byte(x.x + (y.x - x.x) * t), _byte(x.y + (y.y - x.y) * t), _byte(x.z + (y.z - x.z) * t))


## A pixel at a fractional point, rounded as `fillRect(Math.round(x), ...)`.
func dotf(x: float, y: float, c: Color) -> void:
	dot(jr(x), jr(y), c)


## Bresenham between rounded ends.
func line(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var ax := jr(x0)
	var ay := jr(y0)
	var bx := jr(x1)
	var by := jr(y1)
	var dx := absi(bx - ax)
	var dy := -absi(by - ay)
	var sx := 1 if ax < bx else -1
	var sy := 1 if ay < by else -1
	var e := dx + dy
	while true:
		dot(ax, ay, c)
		if ax == bx and ay == by:
			break
		var e2 := 2 * e
		if e2 >= dy:
			e += dy
			ax += sx
		if e2 <= dx:
			e += dx
			ay += sy


## Text at twice the size (the prototypes draw it small, then blow it up). Returns the width.
func text2(s: String, x: int, y: int, c: Color) -> int:
	var small := MiniPix.new(maxi(1, s.length() * 4), 5)
	small.clear(Color(0, 0, 0, 0))
	var w := small.text(s, 0, 0, c)
	for j in 5:
		for i in w:
			var p := small.img.get_pixel(i, j)
			if p.a > 0.0:
				rect(x + i * 2, y + j * 2, 2, 2, p)
	return w * 2


## The start frame's card: the goal in words, the inputs as icons under it (`startCard`).
func start_card(hint: String, ctl: Array, cx: float, y: int, t: float, bg: Color, edge: Color) -> void:
	var tw := hint.length() * 4 - 1
	var iw := -4
	for k: String in ctl:
		iw += int(ICW[k]) + 4
	var w := maxi(tw, iw) + 10
	var x := jr(cx - w / 2.0)
	rect(x - 1, y - 1, w + 2, 28, edge)
	rect(x, y, w, 26, bg)
	text(hint, int(cx), y + 3, HOT, "center")
	var ix := jr(cx - iw / 2.0)
	for k: String in ctl:
		icon(k, ix, y + 11, t)
		ix += int(ICW[k]) + 4
