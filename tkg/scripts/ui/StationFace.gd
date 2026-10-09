class_name StationFace
extends Control

## THE STATION, PULLED UP TO (Jon, on the dock: "the station becomes something on
## the far right of the screen that the ship flies into .... and THAT becomes the
## shipyard"). LOCAL at a station, with the one-camera flow on (`ZoomLadder`):
## the station's side, side on, pinned to the view's right edge and running off
## it, its landing hallway open at your ship's height and facing you.
##
## DOCKING (Jon: "it's an arrival, let it breathe"): your ship sets off from
## where it sits and slowly flies in toward the station; the station's lights
## flicker on to meet it (a welcome: the inner door's glow, then the seam's lamps
## outward from the hallway, then the guide lights along both lips, which then
## run in toward the door); your ship goes in behind the lips and on into the
## bay, and once its tail is inside the camera pans sideways through the
## station's own hull into the yard (`ZoomLadder`'s pan, `draw_hull`).
## Undocking is all of it the other way round.
##
## THE DRUM (Jon: "literally perfect"): one painted plate, `art/stations/
## drum_plate.png` (470 x 530, the ships' pixel), and its front layer,
## `drum_front.png` -- the hallway's two lips and the inner door's near jamb,
## the plate's own pixels -- so your ship flies INTO the slot, between them. Its
## lamps are split out of the painting (`art/stations/lamps.py`): `_unlit` is
## the plate with every lamp dark in its housing, `_lamps` the lamps alone, lit,
## drawn over it at each lamp's own power; and round each lit lamp its light is
## drawn as light (gathered, added). The end ring's two strobes and the red
## beacon are always on; the rest stand by, dim, until you dock.
##
## Two of these are made: the plate behind your ship (`front` false) and the
## front layer over it (`front` true).

const PLATE := preload("res://art/stations/drum_plate.png")
const PLATE_UNLIT := preload("res://art/stations/drum_plate_unlit.png")
const PLATE_LAMPS := preload("res://art/stations/drum_plate_lamps.png")
const FRONT_UNLIT := preload("res://art/stations/drum_front_unlit.png")
const FRONT_LAMPS := preload("res://art/stations/drum_front_lamps.png")
## where the plate stands: its left edge this far in from the view's right edge,
## its row `ROW` level with your ship's middle. SHORTER ON SCREEN (Jon: "make
## the length of the space station shorter horizontally"): pinned further right,
## so of the drum only its end ring, the hallway with its door, and the seam's
## groove and bend show -- `SHOWN` px of the view, where it was 317 -- and the
## rest of its length runs on past the view's edge
const IN_FROM_RIGHT := 312.0
const SHOWN := 230.0
const ROW := 250.0
## THE HALLWAY (plate px): open to space at x 90, its inner door at 222..234, its
## rows between the lips 203..285; the lips start at x 83
const SLOT := Rect2(90, 203, 132, 82)
const DOOR_X := 222.0
const LIP_X := 83.0
const EDGE_X := 82.0
## INTO THE HOLE AND COVERED UP (Jon: "have the ship go INTO the hole and be
## covered up"; then, "The mask is wrong here"): the only part of the station
## your ship is ever seen in front of is the bay's RECESS -- its dark interior,
## from the open end to its back corner (`art/stations/lamps.py` finds it in the
## art: rows 206..283, x < 212). Everything else is hull and is drawn OVER your
## ship (`drum_front.png` is the plate less the recess): the lips, the frame
## round the opening, the lit strip beside it, the plating beyond. So your ship
## flies down the hallway and on past the recess's end, behind the hull, its
## tail in past the recess's end a few frames before the camera pans (it is
## still moving then: `TAIL_IN` is where the curve ends, deeper in) -- none of
## it seen when the pan starts. Its size at most, as it goes deeper:
const RECESS := Rect2(0, 206, 212, 78)
const TAIL_IN := 380.0
const SHIP_END_SCALE := 0.62
const SHIP_END_LEN := 125.0
const SHIP_END_H := 56.0
## the camera's anchor along row `ROW` as it follows you in, k 0 -> 1
const A0 := 110.0
const A1 := 175.0
## THE HULL THE CAMERA PANS THROUGH (`draw_hull`): two of the plate's panels,
## seam to seam, which tile; drawn at this scale
const HULL_SRC := Rect2(318, 38, 109, 425)
const HULL_K := 2.0
## the plate's width, where its own panels' tiling starts (`HULL_X0`, a seam,
## so the tiles carry the plate's own rhythm on), and how far it runs on
const PLATE_W := 470.0
const HULL_X0 := 427.0
const HULL_RUN := 1600.0

## the lamps (plate px), each a rect of `_lamps` with its own power-on
const GUIDE_TOP := [Rect2(90, 203, 6, 3), Rect2(97, 203, 3, 3), Rect2(101, 203, 3, 3), Rect2(105, 203, 3, 3),
	Rect2(109, 203, 3, 3), Rect2(113, 203, 3, 3), Rect2(117, 203, 3, 3), Rect2(121, 203, 3, 3), Rect2(125, 203, 3, 3),
	Rect2(129, 203, 3, 3), Rect2(133, 203, 3, 3), Rect2(137, 203, 3, 3), Rect2(141, 203, 3, 3), Rect2(145, 203, 3, 3),
	Rect2(149, 203, 3, 3), Rect2(153, 203, 3, 3), Rect2(157, 203, 3, 3), Rect2(161, 203, 3, 3), Rect2(165, 203, 3, 3),
	Rect2(169, 203, 3, 3), Rect2(173, 203, 3, 3), Rect2(177, 203, 3, 3), Rect2(181, 203, 3, 3), Rect2(185, 203, 3, 3),
	Rect2(189, 203, 3, 3), Rect2(193, 203, 3, 3), Rect2(197, 203, 3, 3), Rect2(201, 203, 3, 3), Rect2(205, 203, 3, 3),
	Rect2(209, 203, 9, 3)]
## the lower lip's lamps: every 4 px, 2 rows (its lower row in the front layer)
const GUIDE_LOW_X0 := 89.0
const GUIDE_LOW_N := 33
const GUIDE_LOW_Y := 284.0
const SEAM_LAMPS := [Vector2(268, 51), Vector2(268, 71), Vector2(268, 96), Vector2(268, 122), Vector2(268, 146),
	Vector2(268, 170), Vector2(276, 190), Vector2(293, 195), Vector2(316, 195), Vector2(335, 195), Vector2(359, 195),
	Vector2(375, 195), Vector2(388, 195), Vector2(411, 195), Vector2(429, 195), Vector2(449, 195), Vector2(469, 195),
	Vector2(276, 315), Vector2(293, 311), Vector2(316, 311), Vector2(335, 311), Vector2(375, 311), Vector2(388, 311),
	Vector2(411, 311), Vector2(427, 311), Vector2(449, 311), Vector2(469, 311), Vector2(267, 333), Vector2(267, 355),
	Vector2(267, 377), Vector2(267, 401), Vector2(267, 426)]
## the inner door's lit edge, in slices that come on bottom to top
const DOOR_LIGHT := Rect2(225, 202, 9, 84)
const DOOR_SLICES := 6
const BEACON := Rect2(200, 99, 12, 14)
const WINDOW := Rect2(200, 392, 13, 18)
const STROBES := [Vector2(90, 43), Vector2(90, 457)]

## a lamp standing by (before you dock): this much of its light
const STANDBY := 0.18
## THE POWER-ON, along the approach (`power` 0 -> 1): when each group starts
## coming on, and how long one lamp's flicker takes
const ON_DOOR := 0.0
const ON_SEAM := 0.18
const ON_GUIDE := 0.42
const ON_SPREAD := 0.3
const FLICKER := 0.09

const HEAT := [Color("#5c280c"), Color("#964214"), Color("#cc641c"), Color("#ffa63c"), Color("#ffdca0"), Color("#fff6e2")]
const STROBE := Color("#b8e2f4")
const RED := Color("#ff4a36")
const INK := Color("#07090e")

var front := false
## your ship's middle (this control's own px), which the hallway is level with
var ship_y := 270.0
## the star's light, which the plate is seen in
var tint := Color(1, 1, 1)
## how far into the dock the camera is (0 at rest, 1 in the bay): the guide
## lights run in faster as it goes
var dock_k := 0.0
## the station's lights coming on to meet you, 0 (standing by) to 1 (all on)
var power := 0.0
var _clock := 0.0
var _since := 0.0
var _chase := 0.0
var _glow: Control = null


static func make_pair(_n: MapGen.MapNode, _view: Control) -> Array:
	var back := StationFace.new()
	var fr := StationFace.new()
	fr.front = true
	for f: StationFace in [back, fr]:
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return [back, fr]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# THE LIGHTS, added to what is under them (light, not paint)
	_glow = _Glow.new()
	_glow.face = self
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)


func _process(delta: float) -> void:
	_clock += delta
	# (the chase's own clock, once the guide lights are on: faster the further in)
	if power >= ON_GUIDE + ON_SPREAD:
		_chase += delta * lerpf(40.0, 150.0, clampf(dock_k * 1.6, 0.0, 1.0))
	_since += delta
	if _since >= 1.0 / 30.0:
		_since = 0.0
		queue_redraw()
		if _glow != null:
			_glow.queue_redraw()


## The plate's top-left corner (this control's px).
func origin() -> Vector2:
	return Vector2(roundf(size.x - IN_FROM_RIGHT), roundf(ship_y - ROW))


## A point of the plate, in this control's px / on screen.
func plate_local(p: Vector2) -> Vector2:
	return origin() + p


func plate_g(p: Vector2) -> Vector2:
	return get_global_transform() * plate_local(p)


## The hull's left edge (this control's px).
func hull_x() -> float:
	return origin().x + EDGE_X


## The hallway, in this control's px.
func mouth() -> Rect2:
	return Rect2(origin() + SLOT.position, SLOT.size)


## The hallway's middle on screen.
func mouth_g() -> Vector2:
	return get_global_transform() * mouth().get_center()


# ------------------------------------------------------------------ the power-on

## One lamp's power at the station's `power`: standing by until its turn, then
## a stutter on (on, off, on, a blink, on) over `FLICKER`, then on.
static func lamp_on(p: float, at: float) -> float:
	if p <= at:
		return 0.0
	var u := (p - at) / FLICKER
	if u >= 1.0:
		return 1.0
	# the stutter, in fifths of the flicker
	return 1.0 if int(floorf(u * 5.0)) % 2 == 0 else 0.15


## How lit one lamp is (0..1 of its full light), its turn `at`.
func _lamp(at: float) -> float:
	return lerpf(STANDBY, 1.0, lamp_on(power, at))


func _seam_at(i: int) -> float:
	# outward from the hallway: the lamps nearest the slot first
	var p: Vector2 = SEAM_LAMPS[i]
	var d := p.distance_to(Vector2(268, 250)) / 260.0
	return ON_SEAM + ON_SPREAD * clampf(d, 0.0, 1.0) + 0.02 * float(i % 3)


func _guide_at(i: int, n: int) -> float:
	# from the hallway's mouth in toward the door, leading you in
	return ON_GUIDE + ON_SPREAD * float(i) / float(maxi(n - 1, 1))


func _door_at(j: int) -> float:
	return ON_DOOR + 0.025 * float(DOOR_SLICES - 1 - j)


func _draw() -> void:
	# GROUNDED IN THE STAR'S LIGHT: the plate seen in this sky's star
	var m := Color(1, 1, 1).lerp(tint, 0.2)
	var o := origin()
	draw_texture(FRONT_UNLIT if front else PLATE_UNLIT, o, m)
	# (the back: only its recess is ever seen, and it holds no lamp)
	if not front:
		return
	# past the plate's right end the drum runs on, its own panels tiled -- the
	# camera follows your ship in, and your ship flies on deep into the hull,
	# which is in front of it here as everywhere outside the recess
	draw_hull(self, Rect2(o.x + PLATE_W, o.y + HULL_SRC.position.y, HULL_RUN, HULL_SRC.size.y), o.x + HULL_X0,
		o.y + ROW, m, 1.0)
	var lamps: Texture2D = FRONT_LAMPS
	for i in GUIDE_TOP.size():
		_lit(lamps, GUIDE_TOP[i], _lamp(_guide_at(i, GUIDE_TOP.size())), m)
	for i in GUIDE_LOW_N:
		_lit(lamps, Rect2(GUIDE_LOW_X0 + 4.0 * float(i), GUIDE_LOW_Y, 4, 3), _lamp(_guide_at(i, GUIDE_LOW_N)), m)
	for i in SEAM_LAMPS.size():
		var p: Vector2 = SEAM_LAMPS[i]
		_lit(lamps, Rect2(p - Vector2(4, 4), Vector2(9, 9)), _lamp(_seam_at(i)), m)
	var sl := DOOR_LIGHT.size.y / float(DOOR_SLICES)
	for j in DOOR_SLICES:
		var r := Rect2(DOOR_LIGHT.position.x, DOOR_LIGHT.position.y + sl * float(j), DOOR_LIGHT.size.x, ceilf(sl))
		_lit(lamps, r, _lamp(_door_at(j)), m)
	# always on: the beacon, the lit window
	_lit(lamps, BEACON, 0.55 + 0.45 * _pulse(2.4, 0.0), m)
	_lit(lamps, WINDOW, 1.0, m)


## Part of the lamps layer over the unlit plate, at `k` of its light.
func _lit(lamps: Texture2D, r: Rect2, k: float, m: Color) -> void:
	if k <= 0.01:
		return
	draw_texture_rect_region(lamps, Rect2(origin() + r.position, r.size), r, Color(m.r, m.g, m.b, clampf(k, 0.0, 1.0)))


# ------------------------------------------------------------------ the light

## A light's glow, gathered: full at its middle, falling off as the square of the
## distance in four steps, the step edges dithered (`_glow_tex`). Drawn added.
static var _glows := {}


static func _glow_tex(r: int) -> Texture2D:
	if _glows.has(r):
		return _glows[r]
	var n := 2 * r + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var bayer := [0.0, 0.5, 0.75, 0.25]
	for y in n:
		for x in n:
			var d := Vector2(x - r, y - r).length() / (float(r) + 0.5)
			var v := clampf(1.0 - d, 0.0, 1.0)
			v = v * v
			# four steps, the in-between pixels dithered to the step above
			var s := v * 4.0
			var lo := floorf(s)
			if s - lo > bayer[(x % 2) + (y % 2) * 2]:
				lo += 1.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(lo / 4.0, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_glows[r] = t
	return t


func _light(c: CanvasItem, p: Vector2, r: int, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	var o := origin() + p - Vector2(r, r)
	c.draw_texture(_glow_tex(r), o.round(), Color(col.r, col.g, col.b, clampf(k, 0.0, 1.0)))


func _pulse(period: float, offset: float) -> float:
	var u := fposmod(_clock + offset, period) / period
	return 0.5 - 0.5 * cos(u * TAU)


func _strobe(period: float, offset: float) -> float:
	var u := fposmod(_clock + offset, period) / period
	return clampf(1.0 - u * 9.0, 0.0, 1.0)


## The light round each lamp, at its own power (only what is lit throws light).
func draw_lights(c: CanvasItem) -> void:
	var sk := Color(1, 1, 1).lerp(tint, 0.2)
	var flick := 0.92 + 0.08 * sin(_clock * 9.0) * sin(_clock * 3.7)
	var door_on := 0.0
	for j in DOOR_SLICES:
		door_on += lamp_on(power, _door_at(j)) / float(DOOR_SLICES)
	if not front:
		# (behind your ship: the lit strip's light down the recess's floor)
		for j in 4:
			_light(c, Vector2(RECESS.end.x - 10.0 - float(j) * 18.0, SLOT.end.y - 6.0), 10, HEAT[2], (0.16 - 0.035 * float(j)) * flick * door_on)
		return
	_guides(c, GUIDE_LOW_Y + 1.0, GUIDE_LOW_N, 0.35)
	for i in 5:
		var on := lamp_on(power, _door_at(i))
		_light(c, Vector2(234, 212 + i * 16), 3, HEAT[2], (0.18 + 0.05 * _pulse(1.7, float(i) * 0.3)) * on)
	# THE AMBER SEAM: each lamp's light as it comes on, then breathing in a slow
	# wave round the bend (the breathing only scales a lamp that is on)
	for i in SEAM_LAMPS.size():
		var on := lamp_on(power, _seam_at(i))
		var w := 0.5 + 0.5 * sin(_clock * 1.6 - float(i) * 0.55)
		var lo := i >= 17
		_light(c, SEAM_LAMPS[i], 3 if lo else 4, (HEAT[2] if lo else HEAT[3] * sk), on * ((0.06 + 0.1 * w) if lo else (0.16 + 0.22 * w)))
	# THE LIT STRIP BESIDE THE BAY'S END, warm
	for j in 6:
		var on := lamp_on(power, _door_at(clampi(DOOR_SLICES - 1 - j, 0, DOOR_SLICES - 1)))
		_light(c, Vector2(DOOR_LIGHT.position.x + 4.0, DOOR_LIGHT.position.y + 7.0 + float(j) * 14.0), 9, HEAT[3], 0.2 * flick * on)
	# the upper lip's guide lights
	_guides(c, 204.0, GUIDE_TOP.size(), 0.3)
	# a red beacon above the slot, slow; a lit window below, steady
	_light(c, BEACON.get_center(), 6, RED, 0.12 + 0.3 * _pulse(2.4, 0.0))
	_light(c, WINDOW.get_center(), 5, HEAT[2], 0.12)
	# THE END RING'S STROBES, cold, out of step
	_light(c, STROBES[0], 8, STROBE, 0.75 * _strobe(1.6, 0.0))
	_light(c, STROBES[1], 8, STROBE, 0.75 * _strobe(2.1, 0.9))


## The guide lights' light along one lip as each comes on; once all are on, a
## run of three lit lamps every sixteen travelling in toward the door.
func _guides(c: CanvasItem, row: float, n: int, base: float) -> void:
	var head := fposmod(_chase / 4.0, 16.0)
	var running := power >= ON_GUIDE + ON_SPREAD + FLICKER
	for i in n:
		var on := lamp_on(power, _guide_at(i, n))
		if on <= 0.0:
			continue
		var run := 0.0
		if running:
			var ph := fposmod(float(i) - head, 16.0)
			run = 1.0 if ph < 1.0 else (0.6 if ph < 2.0 else (0.3 if ph < 3.0 else 0.0))
		var k := (base * 0.6 + run * (0.55 + 0.45 * clampf(dock_k * 2.0, 0.0, 1.0))) * on
		_light(c, Vector2(GUIDE_LOW_X0 + 2.0 + float(i) * 4.0, row), 3 if run >= 0.5 else 2, HEAT[4], k)


# ------------------------------------------------------------------ the hull

## THE STATION'S OWN HULL, close: two of the plate's panels tiled across `r`
## (in `c`'s px) at `HULL_K`, the tiles starting at `x0`, the plate's row `ROW`
## level with `row_y`; what is above and below the drum, its dark. The camera
## pans through it into the yard (`ZoomLadder`).
static func draw_hull(c: CanvasItem, r: Rect2, x0: float, row_y: float, mod: Color = Color(1, 1, 1), k: float = HULL_K) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	c.draw_rect(r, INK, true)
	var tw := HULL_SRC.size.x * k
	var top := roundf(row_y - (ROW - HULL_SRC.position.y) * k)
	var hull := Rect2(r.position.x, top, r.size.x, HULL_SRC.size.y * k).intersection(r)
	if hull.size.x <= 0.0 or hull.size.y <= 0.0:
		return
	var i := floori((hull.position.x - x0) / tw)
	while true:
		var tx := roundf(x0 + float(i) * tw)
		if tx >= hull.end.x:
			break
		var tile := Rect2(tx, top, tw, HULL_SRC.size.y * k).intersection(hull)
		if tile.size.x > 0.0:
			var src := Rect2(HULL_SRC.position + (tile.position - Vector2(tx, top)) / k, tile.size / k)
			c.draw_texture_rect_region(PLATE, tile, src, mod)
		i += 1


class _Glow extends Control:
	var face: StationFace

	func _draw() -> void:
		if face != null:
			face.draw_lights(self)
