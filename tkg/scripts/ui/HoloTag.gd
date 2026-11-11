class_name HoloTag
extends Control

## THE ONE TOOLTIP (stripped-down UI T1, Jon, Nov 9): a small hologram right above the thing you
## point at: one sentence on a dark fill with scanlines, a 1 px mint edge with a glow, an arrow at
## the thing. It flickers on over `OPEN` seconds, the scanlines crawl, now and then a band tears
## for a frame; the words never move. Drawn by hand (`draw_tag`) for the chart's and the map's
## tips, and as this Control for every tooltip `TagLayer` shows. Why: docs/why/HoloTag.md#one-tag

const PAD_H := 6
const PAD_V := 5
const LINE_H := 11
## Between the tag and the thing it names; the arrow fills it.
const GAP := 3
const FILL := Color("#061010", 0.92)
const SCAN := Color("#0a1a16", 0.92)
const EDGE := Color("#b8f5d8")
## The flicker-on, `FLICKER` alpha steps of `STEP` seconds; the scanlines crawl a row every
## `CRAWL`; a `TEAR_FRAME` tear at the end of every `TEAR_EVERY`.
const OPEN := 0.2
const STEP := 0.04
const FLICKER: Array[float] = [1.0, 0.45, 1.0, 0.6, 1.0]
const CRAWL := 0.4
const TEAR_EVERY := 3.5
const TEAR_FRAME := 0.04
## SCRATCH (scratch/tag-calm, never main): which calm variant draws. 0 today, 1 A tear-in only,
## 2 B rare slip, 3 C drifting line, 4 D wears thin after a while (Jon's pick, Nov 11).
## `-- tagcalm=N`; under D, `-- tagglitch=1..5` is how hard it glitches once it starts.
static var calm := 4
static var glitch := 3
static var _dialled := false
## D: steady until this many seconds open, then the glitch of level `glitch`.
const D_AFTER := 3.0
## D's five levels, G1 (barely there) to G5 (failing), on a 30 Hz glitch clock. A burst every
## PERIOD frames (+- a third), BURST frames long; within a burst, each frame rolls its effects.
const G_HZ := 30.0
const G_PERIOD: Array[int] = [78, 50, 32, 18, 9]
const G_BURST: Array[int] = [1, 2, 4, 6, 8]
## Bands torn sideways a burst frame (up to), how far (px), how tall (px).
const G_TEARS: Array[int] = [1, 1, 2, 3, 4]
const G_TEAR_DX: Array[int] = [2, 3, 5, 9, 16]
const G_TEAR_H: Array[int] = [2, 3, 4, 5, 7]
## Red/cyan split of the words in a burst, and between bursts (px).
const G_CHROMA: Array[int] = [0, 1, 1, 2, 3]
const G_CHROMA_IDLE: Array[int] = [0, 0, 0, 1, 1]
## A letter's chance a burst frame to turn to junk, or to go blank.
const G_SCRAMBLE: Array[float] = [0.0, 0.0, 0.05, 0.12, 0.3]
const G_DROP: Array[float] = [0.0, 0.0, 0.0, 0.06, 0.18]
## Static dots a burst frame; bright rows across the box.
const G_NOISE: Array[int] = [0, 0, 3, 14, 40]
const G_ROWS: Array[int] = [0, 1, 1, 2, 4]
## A burst frame's chance to dim the whole tag (to G_DIM), to blink it out, to nudge it (G_JIT px).
const G_DIM_P: Array[float] = [0.0, 0.0, 0.25, 0.35, 0.4]
const G_DIM: Array[float] = [1.0, 1.0, 0.75, 0.55, 0.35]
const G_BLINK_P: Array[float] = [0.0, 0.0, 0.0, 0.05, 0.16]
const G_JIT: Array[int] = [0, 0, 0, 1, 2]
const JUNK := "#%&@$*+=?/<>[]01"
## B: one slip every B_EVERY (+- B_JITTER) seconds, B_FRAME long.
const B_EVERY := 5.0
const B_FRAME := 0.08
## C: the faint line's trip down the box, seconds.
const C_TRIP := 3.2

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


## Redrawn each frame: the open, then the crawl and the tear.
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


## The whole tag's alpha `age` seconds in: the flicker-on, then 1.
static func alpha_at(age: float) -> float:
	if age >= OPEN:
		return 1.0
	return FLICKER[mini(FLICKER.size() - 1, int(age / STEP))]


## Which row the scanlines start on, `idle` seconds after the open: 0 at rest and at INF.
static func crawl_phase(idle: float) -> int:
	return int(idle / CRAWL) % 3


## Whether the tear shows, `idle` seconds after the open.
static func tearing(idle: float) -> bool:
	return fmod(idle, TEAR_EVERY) >= TEAR_EVERY - TEAR_FRAME


## The box, then the words, in `rect` on `ci`, at `a` alpha. `point` is where the thing is (see
## `point`); `age` is seconds since the tag opened, INF for the still frame.
static func draw_tag(ci: CanvasItem, rect: Rect2, ls: Array, a: float = 1.0, point: int = 0,
		age: float = INF) -> void:
	read_dial()
	var r := Rect2(rect.position.round(), rect.size.round())
	var t := 1.0 if age == INF else clampf(age / OPEN, 0.0, 1.0)
	var idle := 0.0 if age == INF else maxf(0.0, age - OPEN)
	var g: Dictionary = _glitch(idle) if calm == 4 and age != INF else {}
	if calm == 0:
		a *= alpha_at(age) if age != INF else 1.0
	elif not g.is_empty():
		if g.blink:
			return
		a *= float(g.dim)
		r.position += g.jit
	_fill(ci, r, a)
	_scan(ci, r, a, crawl_phase(idle) if calm == 0 else 0, t)
	if calm == 3 and age != INF:
		_drift(ci, r, a, age)
	_halo(ci, r, 0.25 * a)
	_ring(ci, r.grow(-1), Color(EDGE, a))
	if calm == 0:
		if t >= 1.0 or (t >= 0.5 and t < 0.75):
			draw_arrow(ci, r, point, Color(EDGE, a))
	else:
		draw_arrow(ci, r, point, Color(EDGE, a))
	if age != INF:
		match calm:
			0:
				if (t >= 0.4 and t < 0.6) or (idle > 0.0 and tearing(idle)):
					_tear(ci, r, a, t)
			1:
				# A: the tear-in, a band that walks down the box as it opens (0.2 s), then nothing.
				if t < 1.0:
					_tear(ci, r, a, t, 10.0 + minf(0.99, floorf(t * 4.0) / 4.0))
			2:
				var k := int(idle / B_EVERY)
				var at := k * B_EVERY + 3.5 + fmod(k * 1.7, 2.0) - 1.0
				if idle >= at and idle < at + B_FRAME:
					_slip(ci, r, a, k)
	var f := UITheme.pixel_font()
	var asc := f.get_ascent(UITheme.FS_SMALL)
	var y := r.position.y + PAD_V + asc - 1.0
	var tears: Array = g.get("tears", [])
	for tr in tears:
		_band(ci, r, a, tr[0], tr[1], tr[2])
	var ch: int = g.get("chroma", 0)
	for i in ls.size():
		var pair: Array = ls[i]
		var c: Color = pair[1]
		var s := String(pair[0])
		var pos := Vector2(r.position.x + PAD_H, y)
		if not g.is_empty():
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
	if not g.is_empty():
		_static(ci, r, a, g)


## The dials from the command line, once: `tagcalm=N`, `tagglitch=N`.
static func read_dial() -> void:
	if _dialled:
		return
	_dialled = true
	for a in OS.get_cmdline_user_args():
		var kv := (a as String).split("=")
		if kv.size() == 2 and kv[0] == "tagcalm":
			calm = int(kv[1])
		elif kv.size() == 2 and kv[0] == "tagglitch":
			glitch = clampi(int(kv[1]), 1, 5)


## A stable 0..1 from three ints.
static func _h(x: int, y: int, z: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


## D: what glitches this frame, `idle` seconds open: {} while steady (before D_AFTER, and between
## bursts below G4). Keys: blink, dim, jit, tears [[yf, h, dx]], chroma, scr, drop, noise, rows, fr.
static func _glitch(idle: float) -> Dictionary:
	if idle < D_AFTER:
		return {}
	var L := clampi(glitch, 1, 5) - 1
	var fr := int((idle - D_AFTER) * G_HZ)
	var per: int = G_PERIOD[L]
	var k := fr / per
	var start := 0 if k == 0 else k * per + int(_h(k, 7, L) * per / 3.0)
	if fr < start or fr >= start + G_BURST[L]:
		if G_CHROMA_IDLE[L] == 0:
			return {}
		return {"blink": false, "dim": 1.0, "jit": Vector2.ZERO, "tears": [], "chroma": G_CHROMA_IDLE[L],
			"scr": 0.0, "drop": 0.0, "noise": 0, "rows": 0, "fr": fr}
	var tears := []
	var n := mini(G_TEARS[L], 1 + int(_h(fr, 1, L) * G_TEARS[L]))
	for j in n:
		var dx := int(ceilf(G_TEAR_DX[L] * (0.5 + 0.5 * _h(fr, 2, j))))
		if _h(fr, 3, j) < 0.35:
			dx = -dx
		tears.append([_h(fr, 4, j), G_TEAR_H[L], dx])
	var jit := Vector2.ZERO
	if G_JIT[L] > 0 and _h(fr, 5, L) < 0.4:
		jit = Vector2(roundf((_h(fr, 6, L) * 2.0 - 1.0) * G_JIT[L]), 0)
	return {
		"blink": _h(fr, 8, L) < G_BLINK_P[L],
		"dim": G_DIM[L] if _h(fr, 9, L) < G_DIM_P[L] else 1.0,
		"jit": jit, "tears": tears, "chroma": G_CHROMA[L],
		"scr": G_SCRAMBLE[L], "drop": G_DROP[L], "noise": G_NOISE[L], "rows": G_ROWS[L], "fr": fr,
	}


## D: a tear band's top row inside the box, `yf` of the way down.
static func _band_y(r: Rect2, yf: float, hgt: int) -> int:
	return 2 + int(yf * maxf(1.0, r.size.y - 4.0 - hgt))


## D: a band `hgt` px tall at `yf` of the way down the box, its fill slid `dx` px with its edge.
static func _band(ci: CanvasItem, r: Rect2, a: float, yf: float, hgt: int, dx: int) -> void:
	var band := Rect2(r.position + Vector2(dx, _band_y(r, yf, hgt)), Vector2(r.size.x, hgt))
	ci.draw_rect(band, Color(FILL, FILL.a * a), true)
	ci.draw_rect(Rect2(band.position, Vector2(1, hgt)), Color(EDGE, a), true)
	ci.draw_rect(Rect2(band.end.x - 1.0, band.position.y, 1, hgt), Color(EDGE, a), true)


## D: the line's letters this frame, some turned to junk or gone.
static func _junk(s: String, g: Dictionary, line: int) -> String:
	var scr: float = g.scr
	var drop: float = g.drop
	if scr <= 0.0 and drop <= 0.0:
		return s
	var fr: int = g.fr
	var out := ""
	for j in s.length():
		var c := s[j]
		var p := _h(fr, line * 97 + j, 11)
		if c != " " and p < drop:
			c = " "
		elif c != " " and p < drop + scr:
			c = JUNK[int(_h(fr, line * 97 + j, 12) * JUNK.length()) % JUNK.length()]
		out += c
	return out


## D: static dots and bright rows over the box.
static func _static(ci: CanvasItem, r: Rect2, a: float, g: Dictionary) -> void:
	var fr: int = g.fr
	for j in int(g.rows):
		var y := 2 + int(_h(fr, 20, j) * (r.size.y - 4.0))
		var x0 := int(_h(fr, 21, j) * r.size.x * 0.5)
		ci.draw_rect(Rect2(r.position + Vector2(x0, y), Vector2(r.size.x - x0 - 1.0, 1)), Color(EDGE, 0.35 * a), true)
	for j in int(g.noise):
		var p := Vector2(int(_h(fr, 22, j) * r.size.x), int(_h(fr, 23, j) * r.size.y))
		ci.draw_rect(Rect2(r.position + p, Vector2(1, 1)), Color(EDGE, (0.4 + 0.6 * _h(fr, 24, j)) * a), true)


## B: a 2 px band of the box slid 3 px sideways for a few frames, its edge with it.
static func _slip(ci: CanvasItem, r: Rect2, a: float, k: int) -> void:
	var h := int(r.size.y)
	var y := 4 + (k * 7) % maxi(1, h - 8)
	var band := Rect2(r.position + Vector2(3, y), Vector2(r.size.x, 2))
	ci.draw_rect(band, Color(FILL, FILL.a * a), true)
	ci.draw_rect(Rect2(band.end.x - 2.0, band.position.y, 1, 2), Color(EDGE, a), true)


## C: one faint mint row drifting down the fill, under the words, a trip every C_TRIP.
static func _drift(ci: CanvasItem, r: Rect2, a: float, age: float) -> void:
	var h := int(r.size.y) - 4
	var y := int(fmod(age, C_TRIP) / C_TRIP * (h + 6)) - 3
	for d in [-1, 0, 1]:
		var yy: int = y + d
		if yy < 0 or yy >= h:
			continue
		var al := 0.24 if d == 0 else 0.09
		ci.draw_rect(Rect2(r.position + Vector2(2, 2 + yy), Vector2(r.size.x - 4.0, 1)), Color(EDGE, al * a), true)


static func _fill(ci: CanvasItem, r: Rect2, a: float) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(FILL, FILL.a * a), true)


## One dark row in three from row `ph`, wiped down to `t` of the height as it opens.
static func _scan(ci: CanvasItem, r: Rect2, a: float, ph: int, t: float) -> void:
	var line := Color(SCAN, SCAN.a * a)
	var h := int(r.size.y)
	var rows := h - 4 if t >= 1.0 else int(t * (h - 4))
	for i in rows:
		if (i + ph) % 3 == 1:
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


## The tear: a 3 px band of the box drawn again 4 px to the side, for a frame; its row from
## the open's clock, so it is not always the same row.
static func _tear(ci: CanvasItem, r: Rect2, a: float, t: float, row: float = -1.0) -> void:
	var h := int(r.size.y)
	var y := 3 + int(fmod((t if row < 0.0 else row) * 97.0, maxf(1.0, h - 8.0)))
	if row >= 10.0:
		# an explicit fraction of the way down (row - 10)
		y = 3 + int((row - 10.0) * maxf(1.0, h - 8.0))
	var band := Rect2(r.position + Vector2(4, y), Vector2(r.size.x, 3))
	ci.draw_rect(band, Color(FILL, FILL.a * a), true)
	ci.draw_rect(Rect2(band.position, Vector2(1, 3)), Color(EDGE, a), true)
	ci.draw_rect(Rect2(band.position + Vector2(band.size.x - 1.0, 0), Vector2(1, 3)), Color(EDGE, a), true)


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
