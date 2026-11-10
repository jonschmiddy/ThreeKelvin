class_name TipFrames
extends RefCounted

## TEN BOXES FOR THE ONE TAG, for Jon's pick (Nov 9: "the borders of the tool tips more
## sci fi"): each a small pixel texture 9-sliced to any text length, plus the few marks that
## cannot be sliced (a stripe band, a spine, a notch), drawn by hand in whole pixels. The words
## do not change. `-- tiplook=N`, 1..LOOKS; 0 is today's torn tag and stays until he picks.
## Why: docs/why/TornTag.md#tip-looks

const LOOKS := 10
const NAMES: Array[String] = ["TORN", "PLATE", "HOLO", "HUD", "GLASS", "SLATE", "SCOPE",
	"HAZARD", "ORGANIC", "BLUEPRINT", "TRANSPONDER"]
## How long HUD's words take to type on.
const REVEAL := 0.12

static var _boxes: Dictionary[int, StyleBoxTexture] = {}


## The words' margins inside the box, by look: left, top, right, bottom.
static func pad(look: int) -> Rect2i:
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


## The look's texture size and slice margin.
static func _grid(look: int) -> Vector2i:
	match look:
		1: return Vector2i(14, 6)
		2: return Vector2i(8, 3)
		3: return Vector2i(16, 7)
		6: return Vector2i(14, 5)
		8: return Vector2i(18, 8)
		10: return Vector2i(12, 5)
	return Vector2i(10, 4)


## Whether the look's middle tiles (a pattern) or stretches (flat).
static func _tiles(look: int) -> bool:
	return look == 2 or look == 6


## The look's 9-slice, built once.
static func box(look: int) -> StyleBoxTexture:
	if _boxes.has(look):
		return _boxes[look]
	var g := _grid(look)
	var img := Image.create(g.x, g.x, false, Image.FORMAT_RGBA8)
	for y in g.x:
		for x in g.x:
			img.set_pixel(x, y, _px(look, x, y, g.x))
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(g.y)
	var mode := StyleBoxTexture.AXIS_STRETCH_MODE_TILE if _tiles(look) else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
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
				return Color("#2a3a4c")
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


## The box in `r`, then the marks a slice cannot carry. `point` is 1 for a tag above its
## thing, -1 below it, 0 for neither; `a` the whole tag's alpha.
static func draw(ci: CanvasItem, r: Rect2, look: int, a: float, point: int) -> void:
	var sb := box(look)
	sb.modulate_color = Color(1, 1, 1, a)
	sb.draw(ci.get_canvas_item(), r)
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	match look:
		2:
			_notch(ci, r, point, Color(UITheme.MARK, a))
		3:
			# the header tab, a short mint strip under the top-left bracket
			ci.draw_rect(Rect2(o + Vector2(3, 3), Vector2(minf(10.0, w - 6.0), 2)), Color(UITheme.MARK, 0.8 * a), true)
		4:
			# a reflection streak across the top-left corner, two 45 degree runs
			var streak := Color(UITheme.ICE, 0.22 * a)
			var n := int(minf(6.0, h - 4.0))
			for i in n:
				ci.draw_rect(Rect2(o + Vector2(2 + i, 1 + n - i), Vector2.ONE), streak, true)
			for i in mini(3, n):
				ci.draw_rect(Rect2(o + Vector2(6 + i, 1 + n - i), Vector2.ONE), streak, true)
		5:
			_spine(ci, r, a)
		6:
			# crosshair ticks: the edge lines run 2 px past each corner
			var g := Color(UITheme.GOOD, a)
			for c: Vector2 in [Vector2(0, 0), Vector2(w - 1, 0), Vector2(0, h - 1), Vector2(w - 1, h - 1)]:
				var sx := -2.0 if c.x == 0.0 else 1.0
				var sy := -2.0 if c.y == 0.0 else 1.0
				ci.draw_rect(Rect2(o + c + Vector2(sx, 0), Vector2(2, 1)), g, true)
				ci.draw_rect(Rect2(o + c + Vector2(0, sy), Vector2(1, 2)), g, true)
		7:
			_stripes(ci, r, a)
		9:
			_ticks(ci, r, a)
		10:
			_punch(ci, r, a)


## Look 2's leader: a 3 px pixel arrow off the box's edge, pointing at the thing.
static func _notch(ci: CanvasItem, r: Rect2, point: int, col: Color) -> void:
	if point == 0:
		return
	var cx := floorf(r.position.x + r.size.x * 0.5)
	for i in 3:
		var wd := 5 - i * 2
		var y := r.end.y + i if point > 0 else r.position.y - 1 - i
		ci.draw_rect(Rect2(Vector2(cx - (wd - 1) / 2, y), Vector2(wd, 1)), col, true)


## Look 5's spine: a 4 px steel bar down the left with two status lights.
static func _spine(ci: CanvasItem, r: Rect2, a: float) -> void:
	var o := r.position
	ci.draw_rect(Rect2(o + Vector2(1, 1), Vector2(4, r.size.y - 2)), Color(UITheme.COLD, a), true)
	ci.draw_rect(Rect2(o + Vector2(2, 3), Vector2(2, 2)), Color(UITheme.MARK, a), true)
	if r.size.y >= 14:
		ci.draw_rect(Rect2(o + Vector2(2, 7), Vector2(2, 2)), Color(UITheme.FLARE, a), true)
	if r.size.y >= 18:
		ci.draw_rect(Rect2(o + Vector2(2, 11), Vector2(2, 2)), Color("#2a3a4c", a), true)


## Look 7's hazard bands: 3 px of 45 degree stripes along the top and the bottom.
static func _stripes(ci: CanvasItem, r: Rect2, a: float) -> void:
	var warn := Color(UITheme.WARN, a)
	var w := int(r.size.x)
	var h := int(r.size.y)
	for row in 3:
		for y: int in [1 + row, h - 2 - row]:
			var x := 1
			while x < w - 1:
				if (x + y) % 6 < 3:
					var run := 1
					while x + run < w - 1 and (x + run + y) % 6 < 3:
						run += 1
					ci.draw_rect(Rect2(r.position + Vector2(x, y), Vector2(run, 1)), warn, true)
					x += run
				else:
					x += 1


## Look 9's drafting marks: the edge lines run 3 px past each corner, and a tick every 8 px
## stands 1 px off the top and bottom edges.
static func _ticks(ci: CanvasItem, r: Rect2, a: float) -> void:
	var o := r.position
	var w := r.size.x
	var h := r.size.y
	var line := Color(UITheme.ICE, 0.7 * a)
	var tick := Color(UITheme.ICE, 0.35 * a)
	for c: Vector2 in [Vector2(0, 0), Vector2(w - 1, 0), Vector2(0, h - 1), Vector2(w - 1, h - 1)]:
		var sx := -3.0 if c.x == 0.0 else 1.0
		var sy := -3.0 if c.y == 0.0 else 1.0
		ci.draw_rect(Rect2(o + c + Vector2(sx, 0), Vector2(3, 1)), line, true)
		ci.draw_rect(Rect2(o + c + Vector2(0, sy), Vector2(1, 3)), line, true)
	var x := 8
	while x < int(w) - 4:
		ci.draw_rect(Rect2(o + Vector2(x, -1), Vector2.ONE), tick, true)
		ci.draw_rect(Rect2(o + Vector2(x, h), Vector2.ONE), tick, true)
		x += 8


## Look 10's punched hole and divider: a ring on the left, a seam before the words.
static func _punch(ci: CanvasItem, r: Rect2, a: float) -> void:
	var o := r.position
	var cy := floorf(r.size.y * 0.5) - 1.0
	var rim := Color(UITheme.CHILL, a)
	ci.draw_rect(Rect2(o + Vector2(4, cy - 1), Vector2(3, 1)), rim, true)
	ci.draw_rect(Rect2(o + Vector2(4, cy + 1), Vector2(3, 1)), rim, true)
	ci.draw_rect(Rect2(o + Vector2(3, cy), Vector2(1, 1)), rim, true)
	ci.draw_rect(Rect2(o + Vector2(7, cy), Vector2(1, 1)), rim, true)
	ci.draw_rect(Rect2(o + Vector2(4, cy), Vector2(3, 1)), Color(0, 0, 0, 0.9 * a), true)
	ci.draw_rect(Rect2(o + Vector2(10, 2), Vector2(1, r.size.y - 4)), Color(UITheme.COLD, a), true)
