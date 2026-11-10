class_name HoloFrames
extends RefCounted

## THE HOLO FAMILY, looks 11..20 (Jon, Nov 9: HOLO the best of ten, "10 versions similar to
## it"): a mint edge with a glow, scanlines, a flicker-on and an arrow at the thing, each one
## idea apart. Everything is drawn by hand in whole pixels, so a corner, a dash or a ghost edge
## can be its own thing. `TipFrames` holds the dial and hands these looks here.
## Why: docs/why/TornTag.md#holo-family

const FIRST := 11
const LAST := 20
const NAMES: Array[String] = ["CYAN", "BEAM", "INTERLACE", "GLITCH", "CORNERS", "GHOST", "DASHED",
	"HEADER", "VSCAN", "CHEAP"]
const OPEN: Array[float] = [0.2, 0.24, 0.2, 0.2, 0.24, 0.2, 0.2, 0.2, 0.24, 0.24]
const CYAN := Color("#7fe8e0")
const SCAN := Color("#0a1a16")
const FILL := Color("#061010", 0.92)
## The loops: 14's tear every `TEAR_EVERY` for one frame, 17's dashes a step every `MARCH`,
## 18's cursor on and off every `CURSOR`, 19's faint sweep every `RESCAN`, 20's breath and noise.
const TEAR_EVERY := 3.5
const MARCH := 0.25
const CURSOR := 0.5
const RESCAN := 3.0
const BREATHE := 0.6
const NOISE := 0.2


static func name_of(look: int) -> String:
	return NAMES[look - FIRST]


static func open_of(look: int) -> float:
	return OPEN[look - FIRST]


static func pad(look: int) -> Rect2i:
	return Rect2i(6, 8, 6, 5) if look == 18 else Rect2i(6, 5, 6, 5)


static func idles(look: int) -> bool:
	return look != 15 and look != 12


static func edge(look: int) -> Color:
	match look:
		11: return CYAN
		20: return Color(UITheme.MARK, 0.75)
	return UITheme.MARK


## The loop's step `idle` seconds after the open; 0 the resting step.
static func idle_phase(look: int, idle: float) -> int:
	match look:
		13: return int(idle / 0.5) % 2
		14: return 1 if fmod(idle, TEAR_EVERY) >= TEAR_EVERY - 0.04 else 0
		17: return int(idle / MARCH) % 5
		18: return int(idle / CURSOR) % 2
		19:
			var c := fmod(idle, RESCAN)
			return 1 + int((c - (RESCAN - 0.25)) / 0.25 * 1000.0) if c >= RESCAN - 0.25 else 0
		20: return (int(idle / BREATHE) % 2) + 2 * (int(idle / NOISE) % 4)
		12, 15: return 0
	return int(idle / TipFrames.CRAWL) % 3


## The tag's alpha while it opens: HOLO's flicker, or 20's uneven one; 12, 15 and 19 come on
## whole.
static func alpha_at(look: int, age: float) -> float:
	if age >= open_of(look) or look in [12, 15, 19]:
		return 1.0
	if look == 20:
		var cheap: Array[float] = [0.3, 1.0, 0.2, 0.7, 0.4, 1.0]
		return cheap[mini(5, int(age / 0.04))]
	var steps: Array[float] = [1.0, 0.45, 1.0, 0.6, 1.0]
	return steps[mini(4, int(age / 0.04))]


## The letters shown: 12 and 15 hold the words back until the box is there (its last third).
static func letters_at(look: int, age: float, total: int) -> int:
	if look in [12, 15] and age < open_of(look) * 0.66:
		return 0
	return total


static func draw(ci: CanvasItem, r: Rect2, look: int, a: float, point: int, age: float) -> void:
	var t := 1.0 if age == INF else clampf(age / open_of(look), 0.0, 1.0)
	var idle := 0.0 if age == INF else maxf(0.0, age - open_of(look))
	var ph := idle_phase(look, idle)
	match look:
		11:
			_fill(ci, r, a)
			_scan(ci, r, a, ph, t)
			_halo(ci, r, 0.35 * a, 0, CYAN)
			_halo(ci, r, 0.18 * a, -1, CYAN)
			_ring(ci, r.grow(-1), Color(CYAN, a))
			_arrow(ci, r, point, t, Color(CYAN, a))
		12: _beam(ci, r, a, point, t, ph)
		13: _interlace(ci, r, a, point, t, ph)
		14:
			_plain(ci, r, a, point, t, 1.0, ph)
			if (t >= 0.4 and t < 0.6) or ph == 1:
				_tear(ci, r, a, t)
		15: _corners(ci, r, a, point, t, ph)
		16:
			_plain(ci, r, a, point, t, 1.0, ph)
			var off := 2 + (4 - int(t * 4.0)) if t < 1.0 else 2
			_ring(ci, r.grow(float(off)), Color(UITheme.MARK, 0.3 * a))
		17: _dashed(ci, r, a, point, t, ph)
		18: _header(ci, r, a, point, t, ph)
		19: _vscan(ci, r, a, point, t, ph)
		20: _cheap(ci, r, a, point, t, ph)


## HOLO as it is (look 2), the parts shared by the family: fill, scanlines wiping down, the
## halo, the mint ring, the arrow blinking in. `wipe` 1 draws every row.
static func _plain(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, wipe: float, ph: int) -> void:
	_fill(ci, r, a)
	_scan(ci, r, a, ph, t if wipe > 0.0 else 1.0)
	_halo(ci, r, 0.25 * a, 0, UITheme.MARK)
	_ring(ci, r.grow(-1), Color(UITheme.MARK, a))
	_arrow(ci, r, point, t, Color(UITheme.MARK, a))


static func _fill(ci: CanvasItem, r: Rect2, a: float, col: Color = FILL) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(col, col.a * a), true)


## The scanlines: one dark row in three, from row `ph`, wiped down to `t` of the height.
static func _scan(ci: CanvasItem, r: Rect2, a: float, ph: int, t: float, period: int = 3) -> void:
	var line := Color(SCAN, 0.92 * a)
	var h := int(r.size.y)
	var rows := h - 4 if t >= 1.0 else int(t * (h - 4))
	for i in rows:
		if (i + ph) % period == 1:
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


## The glow outside the ring: a 1 px ring `inset` from the box (0 the box's own edge, -1 a
## pixel out), its corner pixels left clear so it reads as light, not a frame.
static func _halo(ci: CanvasItem, r: Rect2, al: float, inset: int, col: Color) -> void:
	var rr := r.grow(-float(inset))
	var o := rr.position
	var w := rr.size.x
	var h := rr.size.y
	var c := Color(col, al)
	ci.draw_rect(Rect2(o + Vector2(1, 0), Vector2(w - 2, 1)), c, true)
	ci.draw_rect(Rect2(o + Vector2(1, h - 1), Vector2(w - 2, 1)), c, true)
	ci.draw_rect(Rect2(o + Vector2(0, 1), Vector2(1, h - 2)), c, true)
	ci.draw_rect(Rect2(o + Vector2(w - 1, 1), Vector2(1, h - 2)), c, true)


## The arrow at the thing: there once open, and a blink at the open's middle.
static func _arrow(ci: CanvasItem, r: Rect2, point: int, t: float, col: Color) -> void:
	if t >= 1.0 or (t >= 0.5 and t < 0.75):
		TipFrames._notch(ci, r, point, col)


## Look 12: the arrow first, a beam cone fanning from it to the box's near corners, then the
## box rising from that edge, then the words.
static func _beam(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, ph: int) -> void:
	var mint := Color(UITheme.MARK, a)
	if t >= 0.66:
		_plain(ci, r, a, point, 1.0, 1.0, ph)
		return
	if point != 0:
		TipFrames._notch(ci, r, point, mint)
	var tip := Vector2(floorf(r.position.x + r.size.x * 0.5), r.end.y + 2 if point >= 0 else r.position.y - 3)
	var far := r.end.y if point >= 0 else r.position.y - 1.0
	var near_l := Vector2(r.position.x, far)
	var near_r := Vector2(r.end.x - 1.0, far)
	var k := minf(1.0, t / 0.33)
	# the cone: two pixel lines from the tip, drawn out to `k` of their length
	for e: Vector2 in [near_l, near_r]:
		var n := int(absf(e.x - tip.x) * k)
		for i in n:
			var x := tip.x + signf(e.x - tip.x) * i
			var y := tip.y + (e.y - tip.y) * (float(i) / maxf(1.0, absf(e.x - tip.x)))
			ci.draw_rect(Rect2(Vector2(x, floorf(y)), Vector2.ONE), Color(UITheme.MARK, 0.5 * a), true)
	if t >= 0.33:
		# the box rises from the near edge: its rows from that edge, `k2` of the height
		var k2 := (t - 0.33) / 0.33
		var rows := int(r.size.y * k2)
		var part := Rect2(r.position + Vector2(0, r.size.y - rows) if point >= 0 else r.position, Vector2(r.size.x, rows))
		if rows >= 3:
			_fill(ci, part, a)
			_halo(ci, part, 0.25 * a, 0, UITheme.MARK)
			_ring(ci, part.grow(-1), mint)


## Look 13: scanlines every other row, each odd one a pixel over; the box starts as stripes
## with no fill and fills in over the open; the stripes swap rows every 0.5 s.
static func _interlace(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, ph: int) -> void:
	var o := r.position
	var w := r.size.x
	var h := int(r.size.y)
	var solid := FILL
	var f := Color(solid, solid.a * a * (0.25 + 0.75 * t))
	ci.draw_rect(Rect2(o + Vector2(1, 1), r.size - Vector2(2, 2)), f, true)
	var line := Color(SCAN, 0.92 * a)
	for i in h - 4:
		if (i + ph) % 2 == 1:
			var x := 2 + ((i / 2) % 2)
			ci.draw_rect(Rect2(o + Vector2(x, 2 + i), Vector2(w - 4.0 - (x - 2), 1)), line, true)
	_halo(ci, r, 0.25 * a, 0, UITheme.MARK)
	_ring(ci, r.grow(-1), Color(UITheme.MARK, a))
	_arrow(ci, r, point, t, Color(UITheme.MARK, a))


## Look 14's tear: a 3 px band of the box drawn again 4 px to the side, for a frame.
static func _tear(ci: CanvasItem, r: Rect2, a: float, t: float) -> void:
	var h := int(r.size.y)
	var y := 3 + int(fmod(t * 97.0, maxf(1.0, h - 8.0)))
	var band := Rect2(r.position + Vector2(4, y), Vector2(r.size.x, 3))
	ci.draw_rect(band, Color(FILL, 0.92 * a), true)
	ci.draw_rect(Rect2(band.position, Vector2(1, 3)), Color(UITheme.MARK, a), true)
	ci.draw_rect(Rect2(band.position + Vector2(band.size.x - 1.0, 0), Vector2(1, 3)), Color(UITheme.MARK, a), true)


## Look 15: four glowing corner ticks, then the edges grow from them to meet, then the fill
## and the words.
static func _corners(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, ph: int) -> void:
	if t >= 0.66:
		_plain(ci, r, a, point, 1.0, 1.0, ph)
		return
	var rr := r.grow(-1)
	var o := rr.position
	var w := rr.size.x
	var h := rr.size.y
	var mint := Color(UITheme.MARK, a)
	var k := 0.0 if t < 0.33 else (t - 0.33) / 0.33
	var lx := floorf(maxf(3.0, (w - 2.0) * 0.5 * k + 3.0))
	var ly := floorf(maxf(3.0, (h - 2.0) * 0.5 * k + 3.0))
	for q: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var cx := o.x if q.x == 0.0 else o.x + w - 1.0
		var cy := o.y if q.y == 0.0 else o.y + h - 1.0
		var hx := cx if q.x == 0.0 else cx - lx + 1.0
		var vy := cy if q.y == 0.0 else cy - ly + 1.0
		ci.draw_rect(Rect2(Vector2(hx, cy), Vector2(lx, 1)), mint, true)
		ci.draw_rect(Rect2(Vector2(cx, vy), Vector2(1, ly)), mint, true)
	if t >= 0.33:
		_arrow(ci, r, point, 1.0, mint)


## Look 17: the edge is dashes, 3 on and 2 off, that march a pixel every `MARCH`.
static func _dashed(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, ph: int) -> void:
	_fill(ci, r, a)
	_scan(ci, r, a, 0, t)
	_halo(ci, r, 0.25 * a, 0, UITheme.MARK)
	var rr := r.grow(-1)
	var o := rr.position
	var w := int(rr.size.x)
	var h := int(rr.size.y)
	var mint := Color(UITheme.MARK, a)
	# the dashes run clockwise round the ring, so the march goes round too
	var n := 2 * (w + h) - 4
	for i in n:
		if (i + ph) % 5 >= 3:
			continue
		var p: Vector2
		if i < w:
			p = Vector2(i, 0)
		elif i < w + h - 1:
			p = Vector2(w - 1, i - w + 1)
		elif i < 2 * w + h - 2:
			p = Vector2(w - 1 - (i - (w + h - 1)) - 1, h - 1)
		else:
			p = Vector2(0, h - 1 - (i - (2 * w + h - 2)) - 1)
		ci.draw_rect(Rect2(o + p, Vector2.ONE), mint, true)
	_arrow(ci, r, point, t, mint)


## Look 18: a glowing bar along the top, drawn out left to right as it opens, with a cursor
## block at its end that blinks every `CURSOR`; scanlines below it.
static func _header(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, ph: int) -> void:
	_fill(ci, r, a)
	var line := Color(SCAN, 0.92 * a)
	var h := int(r.size.y)
	var rows := h - 7 if t >= 1.0 else int(t * (h - 7))
	for i in rows:
		if i % 3 == 1:
			ci.draw_rect(Rect2(r.position + Vector2(2, 5 + i), Vector2(r.size.x - 4.0, 1)), line, true)
	_halo(ci, r, 0.25 * a, 0, UITheme.MARK)
	_ring(ci, r.grow(-1), Color(UITheme.MARK, a))
	var bw := floorf((r.size.x - 6.0) * minf(1.0, t * 1.5))
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(bw, 1)), Color(UITheme.MARK, 0.7 * a), true)
	if t >= 1.0 and ph == 0:
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 6.0, 2), Vector2(3, 2)), Color(UITheme.MARK, a), true)
	_arrow(ci, r, point, t, Color(UITheme.MARK, a))


## Look 19: a bright line sweeps down the box as it opens and shows it row by row; again,
## faint, in the last quarter second of every `RESCAN`.
static func _vscan(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, ph: int) -> void:
	var h := int(r.size.y)
	var shown := h if t >= 1.0 else int(t * h)
	var part := Rect2(r.position, Vector2(r.size.x, shown))
	if shown >= 3:
		_fill(ci, part, a)
		var line := Color(SCAN, 0.92 * a)
		for i in maxi(0, shown - 4):
			if i % 3 == 1:
				ci.draw_rect(Rect2(r.position + Vector2(2, 2 + i), Vector2(r.size.x - 4.0, 1)), line, true)
		_halo(ci, part, 0.25 * a, 0, UITheme.MARK)
		_ring(ci, part.grow(-1), Color(UITheme.MARK, a))
	var y := -1
	var al := 0.0
	if t < 1.0:
		y = shown
		al = 0.9
	elif ph > 0:
		y = int(float(ph - 1) / 1000.0 * h)
		al = 0.3
	if y >= 0 and y < h:
		ci.draw_rect(Rect2(r.position + Vector2(1, y), Vector2(r.size.x - 2.0, 1)), Color(UITheme.MARK, al * a), true)
	_arrow(ci, r, point, t, Color(UITheme.MARK, a))


## Look 20: a cheap projector: the glow breathes (the ring at 0.75 or 0.55 every `BREATHE`),
## noise in the fill from a fixed hash that shifts every `NOISE`.
static func _cheap(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, ph: int) -> void:
	_fill(ci, r, a)
	_scan(ci, r, a, 0, t)
	var w := int(r.size.x)
	var h := int(r.size.y)
	var salt := ph / 2
	var grain := Color("#143026", 0.9 * a)
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			var hsh := ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) >> 5
			if (hsh & 15) == 0:
				ci.draw_rect(Rect2(r.position + Vector2(x, y), Vector2.ONE), grain, true)
	var breath := 0.75 if ph % 2 == 0 else 0.55
	_halo(ci, r, 0.2 * a, 0, UITheme.MARK)
	_ring(ci, r.grow(-1), Color(UITheme.MARK, breath * a))
	_arrow(ci, r, point, t, Color(UITheme.MARK, breath * a))
