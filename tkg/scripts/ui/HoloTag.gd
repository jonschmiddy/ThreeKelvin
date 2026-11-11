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
## 2 B rare slip, 3 C drifting line, 4 D wears thin after a while. `-- tagcalm=N`.
static var calm := 0
## D: steady until this many seconds open, then tears that come closer, never faster than D_MIN.
const D_AFTER := 3.0
const D_FIRST := 2.5
const D_SHRINK := 0.82
const D_MIN := 1.1
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
	var r := Rect2(rect.position.round(), rect.size.round())
	var t := 1.0 if age == INF else clampf(age / OPEN, 0.0, 1.0)
	var idle := 0.0 if age == INF else maxf(0.0, age - OPEN)
	if calm == 0:
		a *= alpha_at(age) if age != INF else 1.0
	elif calm == 4 and age != INF:
		a *= _d_dim(idle)
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
			4:
				var ev := _d_event(idle)
				if ev >= 0:
					_tear(ci, r, a, 1.0, ev * 0.37)
	var f := UITheme.pixel_font()
	var y := r.position.y + PAD_V + f.get_ascent(UITheme.FS_SMALL) - 1.0
	for l in ls:
		var pair: Array = l
		var c: Color = pair[1]
		ci.draw_string(f, Vector2(r.position.x + PAD_H, y), String(pair[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, Color(c, c.a * a))
		y += LINE_H


## D: the index of the tear showing `idle` seconds open, or -1. None before D_AFTER; then each
## gap D_SHRINK of the last, from D_FIRST down to D_MIN.
static func _d_event(idle: float) -> int:
	if idle < D_AFTER:
		return -1
	var at := D_AFTER
	var gap := D_FIRST
	var k := 0
	while at <= idle:
		var dur := 0.05 if k < 4 else 0.08
		if idle < at + dur:
			return k
		at += gap
		gap = maxf(D_MIN, gap * D_SHRINK)
		k += 1
	return -1


## D: past the fifth tear, a tear also dims the whole tag a step, as if the light thins.
static func _d_dim(idle: float) -> float:
	var k := _d_event(idle)
	return 0.75 if k >= 5 and k % 2 == 1 else 1.0


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
