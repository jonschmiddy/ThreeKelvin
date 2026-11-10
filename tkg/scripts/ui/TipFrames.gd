class_name TipFrames
extends RefCounted

## TEN BOXES FOR THE ONE TAG, for Jon's pick (Nov 9): each a small pixel texture sliced into
## corners, edge runs and a flat fill, so it fits any text length in whole pixels, plus the marks
## a slice cannot carry, drawn by hand. Each opens in `OPEN` seconds in whole-pixel steps; some
## keep a slow idle loop (`idles`). The words never move. `-- tiplook=N`; 0 is today's torn tag.
## Why: docs/why/TornTag.md#tip-looks

## 1..10 the ten ideas; 11..LOOKS the HOLO family (`HoloFrames`).
const LOOKS := 20
const NAMES: Array[String] = ["TORN", "PLATE", "HOLO", "HUD", "GLASS", "SLATE", "SCOPE",
	"HAZARD", "ORGANIC", "BLUEPRINT", "TRANSPONDER", "CYAN", "BEAM", "INTERLACE", "GLITCH",
	"CORNERS", "GHOST", "DASHED", "HEADER", "VSCAN", "CHEAP"]
## How long each of the first ten's open animation runs, by look; 0 for today's tag.
const OPEN: Array[float] = [0.0, 0.2, 0.2, 0.12, 0.2, 0.15, 0.25, 0.2, 0.2, 0.25, 0.15]
## HUD's words type on over `REVEAL` seconds from `HUD_TYPE_AT`, while its brackets snap out.
const REVEAL := 0.12
const HUD_TYPE_AT := 0.06
## The idle loops' lengths: HOLO's crawl step, SLATE's and ORGANIC's breath, SCOPE's sweep,
## the TRANSPONDER's blink.
const CRAWL := 0.4
const BREATH := 2.0
const SWEEP_EVERY := 2.5
const BLINK_EVERY := 1.5
const UNLIT := Color("#2a3a4c")

static var _boxes: Dictionary[int, StyleBoxTexture] = {}
static var _texes: Dictionary[int, ImageTexture] = {}


## How long the look's open animation runs.
static func open_of(look: int) -> float:
	return HoloFrames.open_of(look) if look >= HoloFrames.FIRST else OPEN[look]


## The words' margins inside the box, by look: left, top, right, bottom.
static func pad(look: int) -> Rect2i:
	if look >= HoloFrames.FIRST:
		return HoloFrames.pad(look)
	match look:
		1: return Rect2i(7, 5, 7, 5)
		2: return Rect2i(6, 5, 6, 5)
		3: return Rect2i(7, 7, 7, 5)
		4: return Rect2i(7, 5, 6, 5)
		5: return Rect2i(11, 5, 6, 5)
		6: return Rect2i(6, 5, 6, 5)
		7: return Rect2i(6, 7, 6, 7)
		8: return Rect2i(8, 6, 8, 6)
		9: return Rect2i(6, 5, 6, 5)
		10: return Rect2i(13, 5, 6, 5)
	return Rect2i(TornTag.PAD_H, TornTag.PAD_V, TornTag.PAD_H, TornTag.PAD_V)


## Whether the look keeps moving once open.
static func idles(look: int) -> bool:
	return HoloFrames.idles(look) if look >= HoloFrames.FIRST else look in [2, 5, 6, 8, 10]


## When the look's open animation is over, the words included.
static func open_done(look: int) -> float:
	return maxf(OPEN[look], HUD_TYPE_AT + REVEAL) if look == 3 else open_of(look)


## Whether the look is still at `age`: its open done and no idle loop.
static func settled(look: int, age: float) -> bool:
	return age >= open_done(look) and not idles(look)


## THE IDLE LOOPS' ONE CLOCK: the step a look's loop is on `idle` seconds after its open, 0
## the resting step (what the still frame shows, and where every loop starts). HOLO's crawl
## row 0..2; SLATE's dim, ORGANIC's breath in and the TRANSPONDER's blink 1 while on; SCOPE's
## sweep 1 + its column while crossing.
static func idle_phase(look: int, idle: float) -> int:
	if look >= HoloFrames.FIRST:
		return HoloFrames.idle_phase(look, idle)
	match look:
		2: return int(idle / CRAWL) % 3
		5: return 1 if fmod(idle, BREATH) >= 1.5 else 0
		6:
			var c := fmod(idle, SWEEP_EVERY)
			return 1 + int((c - (SWEEP_EVERY - OPEN[6])) / OPEN[6] * 1000.0) if c >= SWEEP_EVERY - OPEN[6] else 0
		8: return 1 if fmod(idle, BREATH) >= 1.4 else 0
		10: return 1 if fmod(idle, BLINK_EVERY) >= BLINK_EVERY - 0.1 else 0
	return 0


## The look's texture size and slice margin.
static func _grid(look: int) -> Vector2i:
	if look >= HoloFrames.FIRST:
		return Vector2i(8, 3)
	match look:
		1: return Vector2i(14, 6)
		2: return Vector2i(8, 3)
		3: return Vector2i(16, 7)
		6: return Vector2i(14, 5)
		8: return Vector2i(18, 8)
		10: return Vector2i(12, 5)
	return Vector2i(10, 4)


## The look's texture, built once.
static func texture(look: int) -> ImageTexture:
	if _texes.has(look):
		return _texes[look]
	var g := _grid(look)
	var img := Image.create(g.x, g.x, false, Image.FORMAT_RGBA8)
	for y in g.x:
		for x in g.x:
			img.set_pixel(x, y, _px(look, x, y, g.x))
	_texes[look] = ImageTexture.create_from_image(img)
	return _texes[look]


## The look as a 9-slice, for the plate round a rich body.
static func box(look: int) -> StyleBoxTexture:
	if _boxes.has(look):
		return _boxes[look]
	var sb := StyleBoxTexture.new()
	sb.texture = texture(look)
	sb.set_texture_margin_all(_grid(look).y)
	var tiled := look == 2 or look == 6 or look >= HoloFrames.FIRST
	var mode := StyleBoxTexture.AXIS_STRETCH_MODE_TILE if tiled else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_horizontal = mode
	sb.axis_stretch_vertical = mode
	var p := pad(look)
	sb.set_content_margin(SIDE_LEFT, p.position.x)
	sb.set_content_margin(SIDE_TOP, p.position.y)
	sb.set_content_margin(SIDE_RIGHT, p.size.x)
	sb.set_content_margin(SIDE_BOTTOM, p.size.y)
	_boxes[look] = sb
	return sb


## The look's fill behind the words.
static func fill(look: int) -> Color:
	if look >= HoloFrames.FIRST:
		return HoloFrames.FILL
	match look:
		1: return Color("#0b1119", 0.94)
		2: return Color("#061010", 0.92)
		4: return Color("#121c28", 0.86)
		5: return Color("#0e1520", 0.94)
		6: return Color("#060c09", 0.94)
		7: return Color("#141b26", 0.95)
		8: return Color("#070e0b", 0.94)
		9: return Color("#0c1a2e", 0.92)
		10: return Color("#0e141c", 0.94)
	return TornTag.FILL


## One pixel of the look's texture: `dx`, `dy` are how far in from the nearest edge.
static func _px(look: int, x: int, y: int, n: int) -> Color:
	var dx := mini(x, n - 1 - x)
	var dy := mini(y, n - 1 - y)
	var f := fill(look)
	if look >= HoloFrames.FIRST:
		# the family's plate: HOLO's slice in the look's own edge colour
		if dx == 0 and dy == 0:
			return Color(0, 0, 0, 0)
		if dx == 0 or dy == 0:
			return Color(HoloFrames.edge(look), 0.25)
		if dx == 1 or dy == 1:
			return HoloFrames.edge(look)
		return Color(HoloFrames.SCAN, 0.92) if y % 2 == 1 else f
	match look:
		1:
			# a hull plate: a 2 px steel edge, the corners cut at 45 degrees, a rivet in each
			if dx + dy <= 2:
				return Color(0, 0, 0, 0)
			if dx < 2 or dy < 2 or dx + dy <= 4:
				return UITheme.COLD
			if dx >= 3 and dx <= 4 and dy >= 3 and dy <= 4:
				return UITheme.COLD if dx == 4 and dy == 4 else UITheme.CHILL
			return f
		2:
			# a hologram: a 1 px mint edge with a faint halo outside it, scanlines inside
			if dx == 0 and dy == 0:
				return Color(0, 0, 0, 0)
			if dx == 0 or dy == 0:
				return Color(UITheme.MARK, 0.25)
			if dx == 1 or dy == 1:
				return UITheme.MARK
			return Color("#0a1a16", 0.92) if y % 2 == 1 else f
		3:
			# a terminal: corner brackets only, 2 px thick, 6 px long
			if (dx < 2 and dy < 6) or (dy < 2 and dx < 6):
				return UITheme.CHILL
			return f
		4:
			# cockpit glass: a thin pale edge, the corners rounded a step
			if dx + dy == 0:
				return Color(0, 0, 0, 0)
			if dx == 0 or dy == 0:
				return Color(UITheme.ICE, 0.55)
			return f
		5:
			# a data slate: a 1 px seam line; the spine is drawn by hand
			if dx == 0 or dy == 0:
				return UNLIT
			return f
		6:
			# a scope: a 1 px green edge, a dot grid every 4 px inside
			if dx == 0 or dy == 0:
				return UITheme.GOOD
			return Color("#16301f", 0.94) if x % 4 == 2 and y % 4 == 2 else f
		7:
			# a stencilled plate: a dark seam; the stripes are drawn by hand
			if dx == 0 or dy == 0:
				return Color("#05070b")
			return f
		8:
			return _organic(dx, dy, f)
		9:
			# a blueprint: a pale 1 px edge; the dimension ticks are drawn by hand
			if dx == 0 or dy == 0:
				return Color(UITheme.ICE, 0.7)
			return f
		10:
			# a transponder tag: a 1 px edge, the corner pixel clipped
			if dx + dy == 0:
				return Color(0, 0, 0, 0)
			if dx == 0 or dy == 0:
				return UITheme.CHILL
			return f
	return f


## Look 8: a rounded shell, radius 6, a green rim and a dimmer membrane two pixels in.
static func _organic(dx: int, dy: int, f: Color) -> Color:
	var depth := float(mini(dx, dy))
	if dx < 6 and dy < 6:
		depth = 6.0 - Vector2(5.5 - dx, 5.5 - dy).length()
	if depth < 0.0:
		return Color(0, 0, 0, 0)
	if depth < 1.0:
		return UITheme.GOOD
	if depth >= 2.0 and depth < 3.0:
		return Color(UITheme.HULL_GREEN, 0.5)
	return f


## THE SLICE BY HAND: the fill, the four corners, and each edge run drawn to a fraction of
## its length (`runs`: top, right, bottom, left; 1 whole, 0 none; negative runs from the far
## end), so an open animation can draw the edge out. Whole pixels throughout.
static func slice(ci: CanvasItem, look: int, r: Rect2, a: float, runs: Vector4 = Vector4.ONE) -> void:
	var tex := texture(look)
	var n := _grid(look).x
	var m := float(_grid(look).y)
	var mod := Color(1, 1, 1, a)
	var o := r.position
	var w := r.size.x
	var h := r.size.y
	# the fill reaches under the edge, 2 px in: the edge's opaque line covers it, and no
	# look's cut corner reaches that far
	var f := fill(look)
	ci.draw_rect(Rect2(o + Vector2(2, 2), Vector2(w - 4.0, h - 4.0)), Color(f, f.a * a), true)
	ci.draw_texture_rect_region(tex, Rect2(o, Vector2(m, m)), Rect2(0, 0, m, m), mod)
	ci.draw_texture_rect_region(tex, Rect2(o + Vector2(w - m, 0), Vector2(m, m)), Rect2(n - m, 0, m, m), mod)
	ci.draw_texture_rect_region(tex, Rect2(o + Vector2(0, h - m), Vector2(m, m)), Rect2(0, n - m, m, m), mod)
	ci.draw_texture_rect_region(tex, Rect2(o + Vector2(w - m, h - m), Vector2(m, m)), Rect2(n - m, n - m, m, m), mod)
	var lw := w - 2.0 * m
	var lh := h - 2.0 * m
	var tl := floorf(lw * minf(1.0, absf(runs.x)))
	var rl := floorf(lh * minf(1.0, absf(runs.y)))
	var bl := floorf(lw * minf(1.0, absf(runs.z)))
	var ll := floorf(lh * minf(1.0, absf(runs.w)))
	if tl > 0.0:
		var x0 := m if runs.x > 0.0 else w - m - tl
		ci.draw_texture_rect_region(tex, Rect2(o + Vector2(x0, 0), Vector2(tl, m)), Rect2(m, 0, 1, m), mod)
	if rl > 0.0:
		var y0 := m if runs.y > 0.0 else h - m - rl
		ci.draw_texture_rect_region(tex, Rect2(o + Vector2(w - m, y0), Vector2(m, rl)), Rect2(n - m, m, m, 1), mod)
	if bl > 0.0:
		var x0 := w - m - bl if runs.z > 0.0 else m
		ci.draw_texture_rect_region(tex, Rect2(o + Vector2(x0, h - m), Vector2(bl, m)), Rect2(m, n - m, 1, m), mod)
	if ll > 0.0:
		var y0 := h - m - ll if runs.w > 0.0 else m
		ci.draw_texture_rect_region(tex, Rect2(o + Vector2(0, y0), Vector2(m, ll)), Rect2(0, m, m, 1), mod)


## The whole tag's alpha at `age` (look 2 flickers on); 1 otherwise.
static func alpha_at(look: int, age: float) -> float:
	if look >= HoloFrames.FIRST:
		return HoloFrames.alpha_at(look, age)
	if look == 2 and age < OPEN[2]:
		var steps: Array[float] = [1.0, 0.45, 1.0, 0.6, 1.0]
		return steps[mini(4, int(age / 0.04))]
	return 1.0


## How many of `total` letters show at `age`: look 3 types them on; the rest show all.
static func letters_at(look: int, age: float, total: int) -> int:
	if look >= HoloFrames.FIRST:
		return HoloFrames.letters_at(look, age, total)
	if look != 3:
		return total
	return int(ceilf(total * clampf((age - HUD_TYPE_AT) / REVEAL, 0.0, 1.0)))


## The box in `r` at `age` seconds since it opened (INF for the still frame), then the marks a
## slice cannot carry. `point` is 1 for a tag above its thing, -1 below it, 0 for neither.
static func draw(ci: CanvasItem, r: Rect2, look: int, a: float, point: int, age: float = INF) -> void:
	if look >= HoloFrames.FIRST:
		HoloFrames.draw(ci, r, look, a, point, age)
		return
	var t := 1.0 if age == INF else clampf(age / OPEN[look], 0.0, 1.0)
	var idle := 0.0 if age == INF else maxf(0.0, age - OPEN[look])
	match look:
		1:
			# the edge draws round from the top-left corner, clockwise
			slice(ci, 1, r, a, Vector4(t * 4.0, t * 4.0 - 1.0, t * 4.0 - 2.0, t * 4.0 - 3.0))
		2: _holo(ci, r, a, point, t, idle)
		3: _hud(ci, r, a, t)
		4: _glass(ci, r, a, t)
		5:
			slice(ci, 5, r, a)
			_spine(ci, r, a, t, idle)
		6: _scope(ci, r, a, t, idle)
		7:
			slice(ci, 7, r, a)
			_stripes(ci, r, a, int((1.0 - t) * 12.0))
		8:
			# the rim swells out to its size, then breathes in a pixel for 0.6 s of every 2
			var inset := 3 - int(t * 3.0) if t < 1.0 else idle_phase(8, idle)
			slice(ci, 8, r.grow(-float(inset)), a)
		9: _blueprint(ci, r, a, t)
		10:
			slice(ci, 10, r, a)
			_punch(ci, r, a, t, idle)


## Look 2: the scanlines wipe down as it opens and crawl one row every `CRAWL` after; the
## leader arrow blinks in.
static func _holo(ci: CanvasItem, r: Rect2, a: float, point: int, t: float, idle: float) -> void:
	slice(ci, 2, r, a)
	var line := Color("#0a1a16", 0.92 * a)
	var h := int(r.size.y)
	var rows := h - 4 if t >= 1.0 else int(t * (h - 4))
	var phase := idle_phase(2, idle)
	for i in rows:
		if (i + phase) % 3 == 1:
			ci.draw_rect(Rect2(r.position + Vector2(2, 2 + i), Vector2(r.size.x - 4.0, 1)), line, true)
	if t >= 1.0 or (t >= 0.5 and t < 0.75):
		_notch(ci, r, point, Color(UITheme.MARK, a))


## Look 3: the brackets snap from the centre out to the corners in four steps; the tab stays.
static func _hud(ci: CanvasItem, r: Rect2, a: float, t: float) -> void:
	var o := r.position
	var w := r.size.x
	if t >= 1.0:
		slice(ci, 3, r, a)
	else:
		ci.draw_rect(r, Color(fill(3), fill(3).a * a), true)
		var k := minf(4.0, floorf(t * 5.0))
		var c := (r.size * 0.5).floor()
		var col := Color(UITheme.CHILL, a)
		for q: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var corner := Vector2(q.x * (w - 1.0), q.y * (r.size.y - 1.0))
			var p := (c + (corner - c) * (k / 4.0)).floor()
			var hx := p.x if q.x == 0.0 else p.x - 5.0
			var hy := p.y if q.y == 0.0 else p.y - 5.0
			ci.draw_rect(Rect2(o + Vector2(hx, p.y if q.y == 0.0 else p.y - 1.0), Vector2(6, 2)), col, true)
			ci.draw_rect(Rect2(o + Vector2(p.x if q.x == 0.0 else p.x - 1.0, hy), Vector2(2, 6)), col, true)
	ci.draw_rect(Rect2(o + Vector2(3, 3), Vector2(minf(10.0, w - 6.0), 2)), Color(UITheme.MARK, 0.8 * a), true)


## Look 4: the resting streak, and as it opens a glint that crosses the pane once, 2 px a step.
static func _glass(ci: CanvasItem, r: Rect2, a: float, t: float) -> void:
	slice(ci, 4, r, a)
	var o := r.position
	var h := r.size.y
	var w := r.size.x
	var streak := Color(UITheme.ICE, 0.22 * a)
	var n := int(minf(6.0, h - 4.0))
	for i in n:
		ci.draw_rect(Rect2(o + Vector2(2 + i, 1 + n - i), Vector2.ONE), streak, true)
	for i in mini(3, n):
		ci.draw_rect(Rect2(o + Vector2(6 + i, 1 + n - i), Vector2.ONE), streak, true)
	if t < 1.0:
		var glint := Color(UITheme.ICE, 0.3 * a)
		var xo := floorf(t * (w + h) * 0.5) * 2.0
		for y in range(1, int(h) - 1):
			var x := xo - (y - 1)
			if x >= 1.0 and x < w - 1.0:
				ci.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), glint, true)


## Look 5's spine: a 4 px steel bar down the left; the lights come on in turn as it opens,
## and the top one dims for half a second of every `BREATH`.
static func _spine(ci: CanvasItem, r: Rect2, a: float, t: float, idle: float) -> void:
	var o := r.position
	ci.draw_rect(Rect2(o + Vector2(1, 1), Vector2(4, r.size.y - 2)), Color(UITheme.COLD, a), true)
	var lit := 3 if t >= 1.0 else int(t * 3.0)
	var top := UITheme.MARK if idle_phase(5, idle) == 0 else UITheme.HULL_GREEN
	var cols: Array[Color] = [top, UITheme.FLARE, UNLIT]
	var room := 1 + (1 if r.size.y >= 14 else 0) + (1 if r.size.y >= 18 else 0)
	for i in room:
		var c: Color = cols[i] if i < lit else UNLIT
		ci.draw_rect(Rect2(o + Vector2(2, 3 + 4 * i), Vector2(2, 2)), Color(c, a), true)


## Look 6: the dot grid by hand, a sweep line across it as it opens and again in the last
## quarter second of every `SWEEP_EVERY`, and crosshair ticks past the corners.
static func _scope(ci: CanvasItem, r: Rect2, a: float, t: float, idle: float) -> void:
	slice(ci, 6, r, a)
	var o := r.position
	var w := int(r.size.x)
	var h := int(r.size.y)
	var dot := Color("#16301f", 0.94 * a)
	for y in range(2, h - 2, 4):
		for x in range(2, w - 2, 4):
			ci.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), dot, true)
	var sweep := -1.0
	if t < 1.0:
		sweep = t
	elif idle_phase(6, idle) > 0:
		sweep = float(idle_phase(6, idle) - 1) / 1000.0
	if sweep >= 0.0:
		var x := 1 + int(sweep * (w - 3))
		var fade: Array[float] = [1.0, 0.5, 0.25]
		for k in 3:
			if x - k >= 1:
				ci.draw_rect(Rect2(o + Vector2(x - k, 1), Vector2(1, h - 2)), Color(UITheme.GOOD, a * fade[k]), true)
	var g := Color(UITheme.GOOD, a)
	for c: Vector2 in [Vector2(0, 0), Vector2(w - 1, 0), Vector2(0, h - 1), Vector2(w - 1, h - 1)]:
		var sx := -2.0 if c.x == 0.0 else 1.0
		var sy := -2.0 if c.y == 0.0 else 1.0
		ci.draw_rect(Rect2(o + c + Vector2(sx, 0), Vector2(2, 1)), g, true)
		ci.draw_rect(Rect2(o + c + Vector2(0, sy), Vector2(1, 2)), g, true)


## Look 2's leader: a 3 px pixel arrow off the box's edge, pointing at the thing.
static func _notch(ci: CanvasItem, r: Rect2, point: int, col: Color) -> void:
	if point == 0:
		return
	var cx := floorf(r.position.x + r.size.x * 0.5)
	for i in 3:
		var wd := 5 - i * 2
		var y := r.end.y + i if point > 0 else r.position.y - 1 - i
		ci.draw_rect(Rect2(Vector2(cx - (wd - 1) / 2, y), Vector2(wd, 1)), col, true)


## Look 7's hazard bands: 3 px of 45 degree stripes along the top and the bottom, slid by
## `shift` px while it opens.
static func _stripes(ci: CanvasItem, r: Rect2, a: float, shift: int) -> void:
	var warn := Color(UITheme.WARN, a)
	var w := int(r.size.x)
	var h := int(r.size.y)
	for row in 3:
		for y: int in [1 + row, h - 2 - row]:
			var x := 1
			while x < w - 1:
				if (x + y + shift) % 6 < 3:
					var run := 1
					while x + run < w - 1 and (x + run + y + shift) % 6 < 3:
						run += 1
					ci.draw_rect(Rect2(r.position + Vector2(x, y), Vector2(run, 1)), warn, true)
					x += run
				else:
					x += 1


## Look 9: the lines draw out from the top-left corner, the corner extensions and the ticks
## following as the line reaches them.
static func _blueprint(ci: CanvasItem, r: Rect2, a: float, t: float) -> void:
	slice(ci, 9, r, a, Vector4(t, t, -t, -t))
	var o := r.position
	var w := r.size.x
	var h := r.size.y
	var line := Color(UITheme.ICE, 0.7 * a)
	var tick := Color(UITheme.ICE, 0.35 * a)
	for c: Vector2 in [Vector2(0, 0), Vector2(w - 1, 0), Vector2(0, h - 1), Vector2(w - 1, h - 1)]:
		if t < 1.0 and c != Vector2.ZERO:
			continue
		var sx := -3.0 if c.x == 0.0 else 1.0
		var sy := -3.0 if c.y == 0.0 else 1.0
		ci.draw_rect(Rect2(o + c + Vector2(sx, 0), Vector2(3, 1)), line, true)
		ci.draw_rect(Rect2(o + c + Vector2(0, sy), Vector2(1, 3)), line, true)
	var reach := int(floorf(t * w))
	var x := 8
	while x < int(w) - 4 and x <= reach:
		ci.draw_rect(Rect2(o + Vector2(x, -1), Vector2.ONE), tick, true)
		ci.draw_rect(Rect2(o + Vector2(x, h), Vector2.ONE), tick, true)
		x += 8


## Look 10's punched hole and divider: a ring on the left, a seam before the words. The hole
## is a beacon: two blinks as it opens, then a 0.1 s blink at the end of every `BLINK_EVERY`.
static func _punch(ci: CanvasItem, r: Rect2, a: float, t: float, idle: float) -> void:
	var o := r.position
	var cy := floorf(r.size.y * 0.5) - 1.0
	var rim := Color(UITheme.CHILL, a)
	ci.draw_rect(Rect2(o + Vector2(4, cy - 1), Vector2(3, 1)), rim, true)
	ci.draw_rect(Rect2(o + Vector2(4, cy + 1), Vector2(3, 1)), rim, true)
	ci.draw_rect(Rect2(o + Vector2(3, cy), Vector2(1, 1)), rim, true)
	ci.draw_rect(Rect2(o + Vector2(7, cy), Vector2(1, 1)), rim, true)
	var on := int(t * 3.0) % 2 == 0 if t < 1.0 else idle_phase(10, idle) == 1
	ci.draw_rect(Rect2(o + Vector2(4, cy), Vector2(3, 1)), Color(0, 0, 0, 0.9 * a), true)
	if on:
		ci.draw_rect(Rect2(o + Vector2(4, cy), Vector2(3, 1)), Color(UITheme.EMBER, a), true)
		ci.draw_rect(Rect2(o + Vector2(5, cy), Vector2(1, 1)), Color(UITheme.FLARE, a), true)
	ci.draw_rect(Rect2(o + Vector2(10, 2), Vector2(1, r.size.y - 4)), Color(UITheme.COLD, a), true)
