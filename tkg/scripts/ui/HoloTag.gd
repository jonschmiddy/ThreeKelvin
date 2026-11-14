class_name HoloTag
extends Control

## THE ONE TOOLTIP (stripped-down UI T1, Jon, Nov 9): a small hologram right above the thing you
## point at: one sentence on a dark fill with scanlines, a 1 px mint edge with a glow, an arrow at
## the thing. It opens steady and, after it has been open a while, wears thin: it glitches, harder
## as the hull fails (C-D, Jon, Nov 11). Drawn by hand (`draw_tag`) for the chart's and the map's
## tips, and as this Control for every tooltip `TagLayer` shows. Why: docs/why/HoloTag.md#one-tag

const PAD_H := 6
const PAD_V := 5
const LINE_H := 11
## Between the tag and the thing it names; the arrow fills it.
const GAP := 3
const FILL := Color("#061010", 0.92)
const SCAN := Color("#0a1a16", 0.92)
const EDGE := Color("#b8f5d8")
## The open: the scanlines wipe down over `OPEN` seconds.
const OPEN := 0.2

## WEARS THIN (C-D): steady for D_AFTER s once open, then bursts of glitch at a level: G2 with
## the hull over LowHull.WORN_AT, G3 at or under it, G4 with the red edge, G5b under DIRE_UNDER.
## Why: docs/why/HoloTag.md#wears-thin
const D_AFTER := 3.0
const G_BASE := 2
const G3 := 3
const G4 := 4
const G5B := 6
## A harness's hold on the level (`-- tagglitch=1..5` or `5b`); 0 follows the hull.
static var glitch := 0
static var _dialled := false
## On a 30 Hz clock: every level rests CALM_F to CALM_F + CALM_JIT_F frames (3-4 s) of clean
## words between bursts (Jon, Nov 11: "only the bursts' intensity should increase"); a burst
## is BURST (+ up to BURST_JIT) frames, per level G1..G5, G5b, and keeps the level it began on.
const G_HZ := 30.0
const CALM_F := 90
const CALM_JIT_F := 30
const G_BURST: Array[int] = [1, 2, 5, 7, 9, 9]
const G_BURST_JIT: Array[int] = [0, 0, 1, 2, 3, 6]
## Bands torn sideways a burst frame (up to), how far (px), how tall (px). G3 and up are a quarter
## stronger than first filmed (Jon, Nov 11, H2); G2 as he passed it.
const G_TEARS: Array[int] = [1, 1, 2, 4, 4, 5]
const G_TEAR_DX: Array[int] = [2, 3, 6, 11, 16, 20]
const G_TEAR_H: Array[int] = [2, 3, 5, 6, 7, 9]
## Red/cyan split of the words in a burst (px).
const G_CHROMA: Array[int] = [0, 1, 1, 2, 3, 4]
## A letter's chance a burst frame to turn to junk, or to go blank.
const G_SCRAMBLE: Array[float] = [0.0, 0.0, 0.0625, 0.15, 0.3, 0.375]
const G_DROP: Array[float] = [0.0, 0.0, 0.0, 0.075, 0.18, 0.225]
## Static dots a burst frame; bright rows across the box.
const G_NOISE: Array[int] = [0, 0, 4, 18, 40, 50]
const G_ROWS: Array[int] = [0, 1, 1, 3, 4, 5]
## A burst frame's chance to dim the whole tag (to G_DIM), to blink it out, to nudge it (G_JIT px).
const G_DIM_P: Array[float] = [0.0, 0.0, 0.31, 0.44, 0.4, 0.5]
const G_DIM: Array[float] = [1.0, 1.0, 0.69, 0.44, 0.35, 0.19]
const G_BLINK_P: Array[float] = [0.0, 0.0, 0.0, 0.0625, 0.16, 0.2]
const G_JIT: Array[int] = [0, 0, 0, 1, 2, 2]
const JUNK := "#%&@$*+=?/<>[]01"


## One frame's glitch, in a burst.
class Glitch:
	var on := false
	var lvl := 2
	var fr := 0
	var blink := false
	var dim := 1.0
	var jit := Vector2.ZERO
	## [[yf, h, dx], ...]
	var tears: Array = []
	var chroma := 0
	var scr := 0.0
	var drop := 0.0
	var noise := 0
	var rows := 0


## One open tag's bursts: the frame last asked, the burst's index, start, length and level, and
## when the next starts.
class Sched:
	var fr := 0
	var k := 0
	var start := 0
	var length := 0
	var lvl := 2
	var next := 0
	var t := 0.0


## Each open tag's schedule, by its canvas item.
static var _sched := {}

## [[text, Color], ...], one entry a line.
var lines: Array = []
var alpha := 1.0
## 1 when the tag sits above its thing, -1 below it, 0 unknown: the arrow points that way.
var point := 0
## When the words were set, on the game's clock: the open runs from here.
var _born := -INF

static var _plate: StyleBoxTexture = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_lines(ls: Array) -> void:
	lines = ls
	size = measure(ls)
	custom_minimum_size = size
	_born = GameClock.now()
	set_process(true)
	queue_redraw()


## Seconds since the words were set; INF before they were.
func age() -> float:
	return INF if _born == -INF else GameClock.now() - _born


## Redrawn each frame: the open, then the wear.
func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_tag(self, Rect2(Vector2.ZERO, size), lines, alpha, point, age())


## The tag's box for these lines: the widest line plus the padding, a line's height each.
static func measure(ls: Array) -> Vector2:
	var f := UITheme.pixel_font()
	var w := 0.0
	for l in ls:
		w = maxf(w, f.get_string_size(String((l as Array)[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x)
	return Vector2(ceilf(w) + PAD_H * 2.0, float(ls.size() * LINE_H + PAD_V * 2 - 2))


## One sentence, wrapped to `width` characters, as the tag's lines in `col`.
static func sentence(text: String, col: Color = UITheme.ICE, width: int = UITheme.TOOLTIP_WRAP) -> Array[Array]:
	var out: Array[Array] = []
	for para in text.split("\n"):
		var line := ""
		for word in (para as String).split(" "):
			if word == "":
				continue
			if line == "":
				line = word
			elif line.length() + 1 + (word as String).length() <= width:
				line += " " + word
			else:
				out.append([line, col])
				line = word
		if line != "":
			out.append([line, col])
	return out


## The box, then the words, in `rect` on `ci`, at `a` alpha. `point` is where the thing is (see
## `point`); `age` is seconds since the tag opened, INF for the still frame.
static func draw_tag(ci: CanvasItem, rect: Rect2, ls: Array, a: float = 1.0, point: int = 0,
		age: float = INF) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	var t := 1.0 if age == INF else clampf(age / OPEN, 0.0, 1.0)
	var g: Glitch = null if age == INF else glitch_at(maxf(0.0, age - OPEN), ci.get_instance_id())
	if g != null and g.on:
		if g.blink:
			return
		a *= g.dim
		r.position += g.jit
	_fill(ci, r, a)
	_scan(ci, r, a, t)
	_halo(ci, r, 0.25 * a)
	_ring(ci, r.grow(-1), Color(EDGE, a))
	draw_arrow(ci, r, point, Color(EDGE, a))
	var tears: Array = g.tears if g != null else []
	for tr in tears:
		_band(ci, r, a, tr[0], tr[1], tr[2])
	var ch := g.chroma if g != null else 0
	var f := UITheme.pixel_font()
	var asc := f.get_ascent(UITheme.FS_SMALL)
	var y := r.position.y + PAD_V + asc - 1.0
	for i in ls.size():
		var pair: Array = ls[i]
		var c: Color = pair[1]
		var s := String(pair[0])
		var pos := Vector2(r.position.x + PAD_H, y)
		if g != null and g.on:
			s = _junk(s, g, i)
			# a line under a tear is torn with it
			var top := y - asc - r.position.y
			for tr in tears:
				var ty := _band_y(r, tr[0], tr[1])
				if top + LINE_H > ty and top < ty + int(tr[1]):
					pos.x += int(tr[2])
					break
		if ch > 0:
			ci.draw_string(f, pos - Vector2(ch, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color(1.0, 0.18, 0.3, 0.6 * a))
			ci.draw_string(f, pos + Vector2(ch, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color(0.2, 0.95, 1.0, 0.6 * a))
		ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color(c, c.a * a))
		y += LINE_H
	if g != null and g.on:
		_static(ci, r, a, g)


## A harness's `-- tagglitch=N` (1..5, or 5b), read once.
static func read_dial() -> void:
	if _dialled:
		return
	_dialled = true
	for a in OS.get_cmdline_user_args():
		var kv := (a as String).split("=")
		if kv.size() == 2 and kv[0] == "tagglitch":
			glitch = G5B if kv[1] == "5b" else clampi(int(kv[1]), 0, G5B)


## The level a tag glitches at now: a harness's hold, or the hull's.
static func level_now() -> int:
	read_dial()
	return glitch if glitch > 0 else hull_level(LowHull.worn, LowHull.on, LowHull.dire)


## The level for LowHull's eased `worn`, `on` and `dire` (0..1 on the game's clock at EASE_S):
## each step taken once it is half in, so the tags follow the warning's pace, both ways.
static func hull_level(worn: float, on: float, dire: float = 0.0) -> int:
	if dire >= 0.5:
		return G5B
	if on >= 0.5:
		return G4
	return G3 if worn >= 0.5 else G_BASE


## A stable 0..1 from three ints.
static func _h(x: int, y: int, z: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


## Burst `k`'s frames from its start to the next's: its own length, then 3-4 s of calm.
static func _gap(length: int, k: int) -> int:
	return length + CALM_F + int(_h(k, 7, 0) * (CALM_JIT_F + 0.999))


## Burst `k`'s length in frames at level `lvl`.
static func _burst_len(lvl: int, k: int) -> int:
	var L := lvl - 1
	return G_BURST[L] + int(_h(k, 13, L) * (G_BURST_JIT[L] + 0.999))


## The schedule of the tag `key` walked to frame `fr`: a new one when the tag (re)opened; each
## burst takes the level in force as it begins.
static func _walk(key: int, fr: int) -> Sched:
	var s: Sched = _sched.get(key)
	if s == null or fr < s.fr:
		s = Sched.new()
		s.lvl = level_now()
		s.length = _burst_len(s.lvl, 0)
		s.next = _gap(s.length, 0)
		_sched[key] = s
	while fr >= s.next:
		s.k += 1
		s.start = s.next
		s.lvl = level_now()
		s.length = _burst_len(s.lvl, s.k)
		s.next = s.start + _gap(s.length, s.k)
	s.fr = fr
	s.t = GameClock.now()
	if _sched.size() > 32:
		for k2 in _sched.keys():
			if GameClock.now() - (_sched[k2] as Sched).t > 5.0:
				_sched.erase(k2)
	return s


## What glitches `idle` seconds after the open, for the tag `key`: null while steady (before
## D_AFTER, between bursts, and always under reduced motion, as LowHull stills).
static func glitch_at(idle: float, key: int = 0) -> Glitch:
	if idle < D_AFTER or not LowHull.moving():
		return null
	var fr := int((idle - D_AFTER) * G_HZ)
	var s := _walk(key, fr)
	var L := s.lvl - 1
	var g := Glitch.new()
	g.lvl = s.lvl
	g.fr = fr
	if fr >= s.start + s.length:
		return null
	g.on = true
	var n := mini(G_TEARS[L], 1 + int(_h(fr, 1, L) * G_TEARS[L]))
	for j in n:
		var dx := int(ceilf(G_TEAR_DX[L] * (0.5 + 0.5 * _h(fr, 2, j))))
		if _h(fr, 3, j) < 0.35:
			dx = -dx
		g.tears.append([_h(fr, 4, j), G_TEAR_H[L], dx])
	if G_JIT[L] > 0 and _h(fr, 5, L) < 0.4:
		g.jit = Vector2(roundf((_h(fr, 6, L) * 2.0 - 1.0) * G_JIT[L]), 0)
	g.blink = _h(fr, 8, L) < G_BLINK_P[L]
	g.dim = G_DIM[L] if _h(fr, 9, L) < G_DIM_P[L] else 1.0
	g.chroma = G_CHROMA[L]
	g.scr = G_SCRAMBLE[L]
	g.drop = G_DROP[L]
	g.noise = G_NOISE[L]
	g.rows = G_ROWS[L]
	return g


## A tear band's top row inside the box, `yf` of the way down.
static func _band_y(r: Rect2, yf: float, hgt: int) -> int:
	return 2 + int(yf * maxf(1.0, r.size.y - 4.0 - hgt))


## A band `hgt` px tall at `yf` of the way down the box, its fill slid `dx` px with its edge.
static func _band(ci: CanvasItem, r: Rect2, a: float, yf: float, hgt: int, dx: int) -> void:
	var band := Rect2(r.position + Vector2(dx, _band_y(r, yf, hgt)), Vector2(r.size.x, hgt))
	ci.draw_rect(band, Color(FILL, FILL.a * a), true)
	ci.draw_rect(Rect2(band.position, Vector2(1, hgt)), Color(EDGE, a), true)
	ci.draw_rect(Rect2(band.end.x - 1.0, band.position.y, 1, hgt), Color(EDGE, a), true)


## The line's letters this frame, some turned to junk or gone.
static func _junk(s: String, g: Glitch, line: int) -> String:
	if g.scr <= 0.0 and g.drop <= 0.0:
		return s
	var out := ""
	for j in s.length():
		var c := s[j]
		var p := _h(g.fr, line * 97 + j, 11)
		if c != " " and p < g.drop:
			c = " "
		elif c != " " and p < g.drop + g.scr:
			c = JUNK[int(_h(g.fr, line * 97 + j, 12) * JUNK.length()) % JUNK.length()]
		out += c
	return out


## Static dots and bright rows over the box.
static func _static(ci: CanvasItem, r: Rect2, a: float, g: Glitch) -> void:
	for j in g.rows:
		var y := 2 + int(_h(g.fr, 20, j) * (r.size.y - 4.0))
		var x0 := int(_h(g.fr, 21, j) * r.size.x * 0.5)
		ci.draw_rect(Rect2(r.position + Vector2(x0, y), Vector2(r.size.x - x0 - 1.0, 1)), Color(EDGE, 0.35 * a), true)
	for j in g.noise:
		var p := Vector2(int(_h(g.fr, 22, j) * r.size.x), int(_h(g.fr, 23, j) * r.size.y))
		ci.draw_rect(Rect2(r.position + p, Vector2(1, 1)), Color(EDGE, (0.4 + 0.6 * _h(g.fr, 24, j)) * a), true)


static func _fill(ci: CanvasItem, r: Rect2, a: float) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(FILL, FILL.a * a), true)


## One dark row in three, wiped down to `t` of the height as it opens.
static func _scan(ci: CanvasItem, r: Rect2, a: float, t: float) -> void:
	var line := Color(SCAN, SCAN.a * a)
	var h := int(r.size.y)
	var rows := h - 4 if t >= 1.0 else int(t * (h - 4))
	for i in rows:
		if i % 3 == 1:
			ci.draw_rect(Rect2(r.position + Vector2(2, 2 + i), Vector2(r.size.x - 4.0, 1)), line, true)


## A 1 px ring just inside `rr`.
static func _ring(ci: CanvasItem, rr: Rect2, col: Color) -> void:
	var o := rr.position
	var w := rr.size.x
	var h := rr.size.y
	ci.draw_rect(Rect2(o, Vector2(w, 1)), col, true)
	ci.draw_rect(Rect2(o + Vector2(0, h - 1), Vector2(w, 1)), col, true)
	ci.draw_rect(Rect2(o + Vector2(0, 1), Vector2(1, h - 2)), col, true)
	ci.draw_rect(Rect2(o + Vector2(w - 1, 1), Vector2(1, h - 2)), col, true)


## The glow outside the ring: the box's own outer pixel, its corners left clear so it reads as
## light, not a frame.
static func _halo(ci: CanvasItem, r: Rect2, al: float) -> void:
	var o := r.position
	var w := r.size.x
	var h := r.size.y
	var c := Color(EDGE, al)
	ci.draw_rect(Rect2(o + Vector2(1, 0), Vector2(w - 2, 1)), c, true)
	ci.draw_rect(Rect2(o + Vector2(1, h - 1), Vector2(w - 2, 1)), c, true)
	ci.draw_rect(Rect2(o + Vector2(0, 1), Vector2(1, h - 2)), c, true)
	ci.draw_rect(Rect2(o + Vector2(w - 1, 1), Vector2(1, h - 2)), c, true)


## The arrow at the thing: a 3 px pixel triangle off the box's edge, filling `GAP`.
static func draw_arrow(ci: CanvasItem, r: Rect2, point: int, col: Color) -> void:
	if point == 0:
		return
	var cx := floorf(r.position.x + r.size.x * 0.5)
	for i in 3:
		var wd := 5 - i * 2
		var y := r.end.y + i if point > 0 else r.position.y - 1 - i
		ci.draw_rect(Rect2(Vector2(cx - (wd - 1) / 2, y), Vector2(wd, 1)), col, true)


## The same box as a StyleBox, for the plate round a rich body (a part's readout, the badge):
## an 8 px slice, tiled, so its scanlines run on at any size. Built once.
static func plate() -> StyleBoxTexture:
	if _plate != null:
		return _plate
	var n := 8
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := mini(x, n - 1 - x)
			var dy := mini(y, n - 1 - y)
			var c := FILL
			if dx == 0 and dy == 0:
				c = Color(0, 0, 0, 0)
			elif dx == 0 or dy == 0:
				c = Color(EDGE, 0.25)
			elif dx == 1 or dy == 1:
				c = EDGE
			elif y % 2 == 1:
				c = SCAN
			img.set_pixel(x, y, c)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(3)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.set_content_margin(SIDE_LEFT, PAD_H)
	sb.set_content_margin(SIDE_RIGHT, PAD_H)
	sb.set_content_margin(SIDE_TOP, PAD_V)
	sb.set_content_margin(SIDE_BOTTOM, PAD_V)
	_plate = sb
	return sb


## Where a tag of `sz` goes for a thing in `about` (the same coordinates): centred above it,
## `GAP` clear; below it when there is no room above; slid inside `bound`; never over `about`
## while both fit. Whole pixels.
static func place(sz: Vector2, about: Rect2, bound: Rect2) -> Vector2:
	var x := about.get_center().x - sz.x * 0.5
	var y := about.position.y - GAP - sz.y
	if y < bound.position.y:
		y = about.end.y + GAP
	if y + sz.y > bound.end.y:
		y = maxf(bound.position.y, about.position.y - GAP - sz.y)
	x = clampf(x, bound.position.x, maxf(bound.position.x, bound.end.x - sz.x))
	return Vector2(x, y).round()
