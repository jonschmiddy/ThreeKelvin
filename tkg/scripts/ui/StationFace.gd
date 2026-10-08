class_name StationFace
extends Control

## THE STATION, PULLED UP TO (Jon, on the dock: "the station becomes something on
## the far right of the screen that the ship flies into .... and THAT becomes the
## shipyard"). LOCAL at a station, with the one-camera flow on (`ZoomLadder`):
## the station's side, side on, pinned to the view's right edge and running off
## it, the way LOCAL's structures stand (`LocalSubject`'s `structure`), its
## hangar mouth open at your ship's height and facing you. DOCK flies your ship
## into the mouth and the camera after it; the hangar inside is the shipyard.
##
## NO PICTURE OF IT EXISTS YET, so it is drawn here in the station's own
## vocabulary -- the steel ramp, lit bodies, warm windows and cold strobes the
## ring on LOCAL is drawn in (`EncounterView.AreaView._station`) -- and the hangar
## seen through the mouth is the station's own yard (`hall_<level>.png`, the hall
## the Shipyard stands in), dimmed with depth. A painted side for it is new art.
##
## Two of these are made: the hull and the hangar behind your ship (`front`
## false), and the mouth's frame in front of it (`front` true), so the ship flies
## INTO the opening.

const W := 360.0
## how far the hull runs past the view's right edge
const OVER := 70.0
const MOUTH := Vector2(150, 92)
## the mouth's left edge, from the hull's
const MOUTH_IN := 46.0
const STEEL := [Color("#141721"), Color("#1e202a"), Color("#2e313e"), Color("#424758"), Color("#5c6376"), Color("#80889e")]
const INK := Color("#0b0f16")
const HEAT := [Color("#5c280c"), Color("#964214"), Color("#cc641c"), Color("#ffa63c"), Color("#ffdca0"), Color("#fff6e2")]
const HAZARD := Color("#c88a2a")
const STROBE := Color("#8ec8e6")

var front := false
## your ship's middle (this control's own px), which the mouth is level with
var ship_y := 270.0
## the star's light on its edges
var tint := Color(1, 1, 1)
var _seed := 1
var _hall: Texture2D = null
var _clock := 0.0
var _since := 0.0


static func make_pair(n: MapGen.MapNode, view: Control) -> Array:
	var back := StationFace.new()
	var fr := StationFace.new()
	fr.front = true
	for f: StationFace in [back, fr]:
		f._seed = absi(hash([Run.galaxy_seed, n.index, "face"]))
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lvl := ShopScene.level_name(int(n.get("development")) if n.get("development") != null else 0)
	var p := "res://art/sprites/station/yard/hall_%s.png" % lvl
	if not ResourceLoader.exists(p):
		p = "res://art/sprites/station/yard/hall_unclaimed.png"
	if ResourceLoader.exists(p):
		back._hall = load(p)
	return [back, fr]


func _process(delta: float) -> void:
	_clock += delta
	_since += delta
	if _since >= 1.0 / 12.0:
		_since = 0.0
		queue_redraw()


## The hull's left edge (this control's px).
func hull_x() -> float:
	return roundf(size.x + OVER - W)


## The mouth, in this control's px.
func mouth() -> Rect2:
	var x := hull_x() + MOUTH_IN
	return Rect2(Vector2(x, roundf(ship_y - MOUTH.y * 0.5)), MOUTH)


## The mouth's middle on screen.
func mouth_g() -> Vector2:
	return get_global_transform() * mouth().get_center()


func _draw() -> void:
	if front:
		_draw_frame()
	else:
		_draw_hull()


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _seed
	return r


func _lit(c: Color, k: float) -> Color:
	return c.lerp(c * tint, k)


func _draw_hull() -> void:
	var x0 := hull_x()
	var m := mouth()
	var r := _rng()
	# THE PLATES, top to bottom: bands of the steel ramp, each a lit body seen
	# from just below its top edge, the hull's face catching the star at its edge
	var y := -20.0
	while y < size.y + 20.0:
		var h := float(r.randi_range(18, 46))
		var deck := 0.18 + r.randf() * 0.12
		_body(Vector2(x0, y), Vector2(W, h), deck)
		# ribs and their rivets
		var rx := x0 + 30.0 + float(r.randi_range(0, 20))
		while rx < x0 + W:
			draw_rect(Rect2(rx, y + 2, 1, h - 4), STEEL[1], true)
			draw_rect(Rect2(rx + 1, y + 2, 1, h - 4), STEEL[3], true)
			rx += float(r.randi_range(34, 70))
		# a row of lit windows on some bands, never across the mouth
		if r.randf() < 0.45 and h > 22.0:
			var wy := y + roundf(h * 0.35)
			var wx := x0 + 18.0 + float(r.randi_range(0, 30))
			while wx < x0 + W - 8.0:
				var wr := Rect2(wx, wy, 5, 3)
				if not wr.grow(4.0).intersects(m) and r.randf() < 0.8:
					_window(wr.position, wr.size)
				wx += float(r.randi_range(9, 16))
		y += h + 1.0
	# THE EDGE TOWARD YOU AND THE STAR: a lit seam down the hull's left side
	draw_rect(Rect2(x0 - 2, 0, 2, size.y), INK, true)
	draw_rect(Rect2(x0, 0, 1, size.y), _lit(STEEL[5], 0.5), true)
	draw_rect(Rect2(x0 + 1, 0, 1, size.y), _lit(STEEL[4], 0.4), true)
	# THE HANGAR: dark, deep, the yard in it, its far lamps
	draw_rect(m.grow(2.0), INK, true)
	draw_rect(m, Color("#07090e"), true)
	if _hall != null:
		# the hall seen far in: the middle of the yard, small, dimmed by depth
		var inner := m.grow(-10.0)
		var ts := _hall.get_size()
		var k := maxf(inner.size.x / ts.x, inner.size.y / ts.y) * 1.35
		var src := Rect2((ts - inner.size / k) * 0.5, inner.size / k)
		draw_texture_rect_region(_hall, inner, src, Color(0.55, 0.53, 0.52))
	# the hangar's sides falling away inside the mouth (darker toward you)
	for i in 10:
		var a := 0.85 - float(i) * 0.07
		draw_rect(Rect2(m.position.x + i, m.position.y + i, 1, m.size.y - 2 * i), Color(0.03, 0.04, 0.06, a), true)
		draw_rect(Rect2(m.end.x - 1 - i, m.position.y + i, 1, m.size.y - 2 * i), Color(0.03, 0.04, 0.06, a * 0.8), true)
	# the inner lamps along the lintel, warm, and their light on the floor
	for i in 6:
		var lx := m.position.x + 18.0 + float(i) * (m.size.x - 36.0) / 5.0
		draw_rect(Rect2(lx - 1, m.position.y + 11, 3, 2), HEAT[4], true)
		_dither(Rect2(lx - 5, m.end.y - 16, 11, 5), HEAT[2], 0.25)
	# THE LIGHT OUT OF THE MOUTH onto the hull round it and into space: warm,
	# stepped, falling off
	for ring in 3:
		var g := m.grow(4.0 + 7.0 * float(ring))
		_dither(Rect2(g.position.x, g.position.y, g.size.x, 3), HEAT[1], 0.22 - 0.06 * float(ring))
		_dither(Rect2(g.position.x, g.end.y - 3, g.size.x, 3), HEAT[1], 0.22 - 0.06 * float(ring))
	_dither(Rect2(m.position.x - 40, m.position.y + 6, 36, m.size.y - 12), HEAT[0], 0.12)
	# strobes, cold, out of step
	draw_rect(Rect2(x0 + 6, 18, 3, 3), Color("#2b4759").lerp(STROBE, _strobe(2.3, 0.0)), true)
	draw_rect(Rect2(x0 + 6, size.y - 22, 3, 3), Color("#2b4759").lerp(STROBE, _strobe(3.1, 1.4)), true)


## The mouth's frame, in front of anything flying in: the jambs with their
## hazard paint, the lintel and the sill, and the sill's landing lights running
## in toward the hangar.
func _draw_frame() -> void:
	var m := mouth()
	var j := 9.0
	for side in [-1.0, 1.0]:
		var x := m.position.x - j if side < 0.0 else m.end.x
		var jr := Rect2(x, m.position.y - 8, j, m.size.y + 16)
		draw_rect(jr.grow(1.0), INK, true)
		draw_rect(jr, STEEL[2], true)
		draw_rect(Rect2(jr.position.x, jr.position.y, 1 if side < 0.0 else 2, jr.size.y), _lit(STEEL[5], 0.5) if side < 0.0 else STEEL[1], true)
		# hazard stripes, every 6 px, diagonal in whole pixels
		for yy in int(jr.size.y):
			for xx in int(j - 2):
				if ((xx + yy) / 3) % 2 == 0:
					draw_rect(Rect2(jr.position.x + 1 + xx, jr.position.y + yy, 1, 1), HAZARD.darkened(0.25), true)
	var lint := Rect2(m.position.x - j, m.position.y - 8, m.size.x + 2 * j, 8)
	var sill := Rect2(m.position.x - j, m.end.y, m.size.x + 2 * j, 8)
	for b: Rect2 in [lint, sill]:
		draw_rect(b.grow(1.0), INK, true)
		draw_rect(b, STEEL[3], true)
		draw_rect(Rect2(b.position, Vector2(b.size.x, 1)), _lit(STEEL[5], 0.5), true)
		draw_rect(Rect2(b.position + Vector2(0, b.size.y - 2), Vector2(b.size.x, 2)), STEEL[1], true)
	# landing lights: a chaser along the sill, into the hangar
	var n := 9
	var step := int(floor(fposmod(_clock * 6.0, float(n))))
	for i in n:
		var lx := sill.position.x + 8.0 + float(i) * (sill.size.x - 16.0) / float(n - 1)
		var on := i == step or i == (step + n - 1) % n
		draw_rect(Rect2(lx - 1, sill.position.y + 2, 3, 2), HEAT[4] if on else HEAT[0], true)


func _body(pos: Vector2, dim: Vector2, deck: float) -> void:
	var p := pos.round()
	var w := maxf(1.0, roundf(dim.x))
	var h := maxf(2.0, roundf(dim.y))
	var d := clampf(roundf(h * deck), 1.0, h - 1.0)
	draw_rect(Rect2(p - Vector2(0, 1), Vector2(w, h + 2)), INK, true)
	draw_rect(Rect2(p, Vector2(w, d)), STEEL[3], true)
	draw_rect(Rect2(p, Vector2(w, 1)), _lit(STEEL[4], 0.4), true)
	draw_rect(Rect2(p + Vector2(0, d), Vector2(w, h - d)), STEEL[2], true)
	_dither(Rect2(p + Vector2(0, d + 1), Vector2(w, 2)), STEEL[3], 0.4)
	_dither(Rect2(p + Vector2(0, h - 4), Vector2(w, 3)), STEEL[1], 0.5)
	draw_rect(Rect2(p + Vector2(0, h - 1), Vector2(w, 1)), STEEL[0], true)


func _window(pos: Vector2, dim: Vector2) -> void:
	draw_rect(Rect2(pos - Vector2.ONE, dim + Vector2(2, 2)), INK, true)
	draw_rect(Rect2(pos, dim), HEAT[1], true)
	draw_rect(Rect2(pos, Vector2(dim.x, maxf(1.0, dim.y * 0.5))), HEAT[3], true)


func _dither(r: Rect2, col: Color, density: float) -> void:
	var th := [0.0, 0.5, 0.75, 0.25]
	for jj in int(r.size.y):
		for i in int(r.size.x):
			if th[(i % 2) + (jj % 2) * 2] < density:
				draw_rect(Rect2(r.position + Vector2(i, jj), Vector2.ONE), col, true)


func _strobe(period: float, offset: float) -> float:
	var u := fposmod(_clock + offset, period) / period
	return clampf(1.0 - u * 7.0, 0.0, 1.0)
