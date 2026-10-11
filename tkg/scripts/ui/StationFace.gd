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
## WHICH SIDE (`StationSides`): seven kept sides, each with one of thirteen kept
## interiors in its recess, picked per station from the station alone. Every
## side carries the Drum's entrance at the same rows, so everything below about
## the hallway, the recess, the mask and the camera holds for all of them.
##
## THE DRUM, TAKE 1, AS APPROVED (now `StationSides.FLAT`, kept to compare: Jon's
## 2B lit Drum 1 like the other six, its dock unchanged): one painted plate, `art/stations/
## drum_plate.png` (470 x 530, the ships' pixel), and its front layer,
## `drum_front.png` -- the hallway's two lips and the inner door's near jamb,
## the plate's own pixels -- so your ship flies INTO the slot, between them. Its
## lamps are split out of the painting (`art/stations/lamps.py`): `_unlit` is
## the plate with every lamp dark in its housing, `_lamps` the lamps alone, lit,
## drawn over it at each lamp's own power; and round each lit lamp its light is
## drawn as light (gathered, added). The end ring's two strobes and the red
## beacon are always on; the rest stand by, dim, until you dock. Drawn as it
## always was, pixel for pixel (`StationFaceShot` diffs it).
##
## EVERY KEPT SIDE (`art/stations/sides.py`, Jon's 1A for lights and depth): the
## hull in layers, far first, the star's rim and shaded undersides baked in, each
## layer moved by whole pixels as the camera comes in (`par`: the far ones less,
## so the near boxes slide over the far); a dark crevice under them all, so a gap
## opened by the parallax is the hull's own shadow and never a window onto your
## ship behind it; the bay lit from its inner door at the door's power; the
## lamps over it at their own power, and their light drawn as light.
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
## THROUGH THE LIPS, EVERY WEIGHT ALIKE (Jon: "how do large ships look going
## into the station?"): as its nose reaches the lips your ship is at most this
## tall (plate px) -- the medium's own height there, as Jon approved its dock
## (66.9 measured on film; a pixel of room for its bob) -- so the
## heavy, half as tall again, no
## longer has its turrets and fins cut off by the lips like a ship sliding behind
## the station: it shrinks sooner on its way in (`SectorScreen._hall_shrink`),
## the light and the medium exactly as before
const SHIP_LIP_H := 68.0
## THE LIPS AS PIECES (for the mouth opening, "OPEN"): the upper lip's band of
## the front layer (its gold lamp row and outer frame) and the lower lip's, which
## slide apart; the frame's right side (x 212..224), carried on into the gaps;
## and the bay's ceiling and floor slabs (6 rows each), which go with the lips,
## the bay's own wall rows carried on between
const LIP_TOP_BAND := Rect2(76, 196, 148, 10)
const LIP_BOT_BAND := Rect2(76, 284, 148, 10)
const FRAME_SIDE_X := Vector2(212, 224)
const BAY_SLAB := 6
## the camera's anchor along row `ROW` as it follows you in, k 0 -> 1
const A0 := 110.0
const A1 := 175.0
## THE HULL THE CAMERA PANS THROUGH (`draw_hull`): two of the plate's panels,
## seam to seam, which tile; drawn at this scale (the Drum's; every side has its
## own window, `StationSides.SideArt.hull_src`)
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
## (the other sides' lamp strip, a pixel either way of the Drum's: its slices
## are taken this wide)
const STRIP := Rect2(223, 200, 14, 90)
const BEACON := Rect2(200, 99, 12, 14)
const WINDOW := Rect2(200, 392, 13, 18)
const STROBES := [Vector2(90, 43), Vector2(90, 457)]

## a lamp standing by (before you dock): this much of its light
const STANDBY := 0.18
## the bay's light standing by, of its lit picture over its dark one
const BAY_REST := 0.4
## THE POWER-ON, along the approach (`power` 0 -> 1): when each group starts
## coming on, and how long one lamp's flicker takes
const ON_DOOR := 0.0
const ON_SEAM := 0.18
const ON_GUIDE := 0.42
const ON_SPREAD := 0.3
const FLICKER := 0.09
## where the other sides' lamps come on outward from (plate px): the hallway
const ON_FROM := Vector2(160, 245)

## THE PARALLAX (the other sides): a layer of parallax p is moved (1 - p) x
## `PAR_GAIN` of the camera's travel across the plate (its view's middle, in
## plate px, since it was at rest), in whole pixels, holding each step until the
## travel is `PAR_HOLD` px past it (no A, B, A at a step's edge). Over the dock
## the camera crosses about 600 px of plate: the farthest boxes (0.8) end 7 px
## behind the near ones.
const PAR_GAIN := 0.06
const PAR_HOLD := 0.6

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
## the side drawn, and its interior's two pictures ([] for the side's own bay)
var side: StationSides.SideArt = null
var interior: Array = []
## each layer's parallax step now (parallax -> whole plate px)
var par := {}
## THE MOUTH OPENED FOR A BIG HULL (`ZoomLadder.big_hull` "OPEN"): how far the
## upper lip is slid up and the lower lip down now, whole plate px (0: shut, as
## always; the light and the medium never open it)
var open_top := 0
var open_bot := 0
## (what the dock decided for the hull now docking: mode, q, its scale at the
## lips, its body, the mouth's opening -- for harnesses)
static var last_fit := {}
var _clock := 0.0
var _since := 0.0
var _chase := 0.0
var _glow: Control = null


static func make_pair(n: MapGen.MapNode, _view: Control) -> Array:
	var back := StationFace.new()
	var fr := StationFace.new()
	fr.front = true
	var pk := StationSides.pick(n)
	for f: StationFace in [back, fr]:
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.use_side(pk.side, pk.interior)
	return [back, fr]


## Draw this side, with this interior (`StationSides.NONE`: the side's own bay).
func use_side(id: StringName, interior_id: StringName = StationSides.NONE) -> void:
	if id == &"":
		id = &"drum1"
	side = StationSides.side(id)
	interior = StationSides.interior(interior_id)
	par = {}
	# (the parallax follows the camera this frame: processed after the ladder
	# that moves it; Drum take 1 keeps its place in the order)
	process_priority = 0 if side.legacy else 100
	queue_redraw()


func _init() -> void:
	side = StationSides.side(&"drum1")


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
	if front and not side.legacy:
		_parallax()
	_since += delta
	if _since >= 1.0 / 30.0:
		_since = 0.0
		queue_redraw()
		if _glow != null:
			_glow.queue_redraw()


## The camera's look across the plate: the middle of the view this face is
## in, in plate px.
func _look() -> Vector2:
	var p := get_parent() as Control
	if p == null:
		return Vector2.ZERO
	return get_global_transform().affine_inverse() * p.get_global_rect().get_center() - origin()


func _parallax() -> void:
	if dock_k <= 0.0:
		# at rest (and in any zoom that is not the dock's): every layer where
		# the art has it
		par = {}
		return
	# (at rest this face fills its view: the view's middle is its own)
	var travel := _look().x - (size.x * 0.5 - origin().x)
	for l: Array in side.layers:
		var p: float = l[1]
		if p >= 1.0:
			continue
		var want := (1.0 - p) * PAR_GAIN * travel
		var now := float(par.get(p, 0))
		if absf(want - now) > PAR_HOLD:
			par[p] = int(roundf(want))
			queue_redraw()


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


## Where this side's hull tiles start past the plate (plate px, a seam).
func hull_x0() -> float:
	return side.hull_x0


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


## The other sides' own lamps (seam, windows, strings): outward from the
## hallway, as the Drum's seam.
func _extra_at(i: int) -> float:
	var l: Dictionary = side.extra[i]
	# (Drum 1's beacon and lit window: always on, as they always were)
	if l.group == &"always":
		return -1.0
	var d := (l.rect as Rect2).get_center().distance_to(ON_FROM) / 300.0
	return ON_SEAM + ON_SPREAD * clampf(d, 0.0, 1.0) + 0.02 * float(i % 3)


func _guide_at(i: int, n: int) -> float:
	# from the hallway's mouth in toward the door, leading you in
	return ON_GUIDE + ON_SPREAD * float(i) / float(maxi(n - 1, 1))


func _door_at(j: int) -> float:
	return ON_DOOR + 0.025 * float(DOOR_SLICES - 1 - j)


## How much of the door's light is on (0..1): the bay is lit by it.
func door_on() -> float:
	var on := 0.0
	for j in DOOR_SLICES:
		on += lamp_on(power, _door_at(j)) / float(DOOR_SLICES)
	return on


## How lit the bay (or its interior) is: some of the door's light standing by
## (a dark bay at rest read as a hole), all of it once the door is on.
func bay_lit() -> float:
	return lerpf(BAY_REST, 1.0, door_on())


func _draw() -> void:
	# GROUNDED IN THE STAR'S LIGHT: the plate seen in this sky's star
	var m := Color(1, 1, 1).lerp(tint, 0.2)
	var o := origin()
	if side.legacy:
		_draw_drum(m, o)
	else:
		_draw_side(m, o)


## Drum take 1, as it was approved.
func _draw_drum(m: Color, o: Vector2) -> void:
	draw_texture(FRONT_UNLIT if front else PLATE_UNLIT, o, m)
	# (the back: only its recess is ever seen, and it holds no lamp)
	if not front:
		_draw_interior(m, o)
		return
	# past the plate's right end the drum runs on, its own panels tiled -- the
	# camera follows your ship in, and your ship flies on deep into the hull,
	# which is in front of it here as everywhere outside the recess
	draw_hull(self, Rect2(o.x + PLATE_W, o.y + HULL_SRC.position.y, HULL_RUN, HULL_SRC.size.y), o.x + HULL_X0,
		o.y + ROW, m, 1.0)
	var lamps: Texture2D = FRONT_LAMPS
	_draw_entrance_lamps(lamps, m, DOOR_LIGHT)
	# always on: the beacon, the lit window
	_lit(lamps, BEACON, 0.55 + 0.45 * _pulse(2.4, 0.0), m)
	_lit(lamps, WINDOW, 1.0, m)


## The entrance's lamps (every side has the Drum's): both lips' guide lights and
## the strip beside the door, from `lamps`, each at its own power.
func _draw_entrance_lamps(lamps: Texture2D, m: Color, strip: Rect2) -> void:
	# (the guide lights ride their lips when the mouth opens)
	var up := Vector2(0, -open_top)
	var down := Vector2(0, open_bot)
	for i in GUIDE_TOP.size():
		_lit(lamps, GUIDE_TOP[i], _lamp(_guide_at(i, GUIDE_TOP.size())), m, up)
	for i in GUIDE_LOW_N:
		_lit(lamps, Rect2(GUIDE_LOW_X0 + 4.0 * float(i), GUIDE_LOW_Y, 4, 3), _lamp(_guide_at(i, GUIDE_LOW_N)), m, down)
	if lamps == FRONT_LAMPS:
		for i in SEAM_LAMPS.size():
			var p: Vector2 = SEAM_LAMPS[i]
			_lit(lamps, Rect2(p - Vector2(4, 4), Vector2(9, 9)), _lamp(_seam_at(i)), m)
	var sl := strip.size.y / float(DOOR_SLICES)
	for j in DOOR_SLICES:
		var r := Rect2(strip.position.x, strip.position.y + sl * float(j), strip.size.x, ceilf(sl))
		_lit(lamps, r, _lamp(_door_at(j)), m)


## The interior in the recess, over the bay: dark, and lit at the door's power.
func _draw_interior(m: Color, o: Vector2) -> void:
	if interior.is_empty():
		return
	var at := o + StationSides.INTERIOR_AT
	# (the hallway's wall above and below it when the mouth opens: the side's own
	# bay, dark and lit as the interior is)
	var bd: Texture2D = side.bay_dark if not side.legacy else null
	var bl: Texture2D = side.bay_lit if not side.legacy else null
	_bay_open(interior[0], at, m, bd, o + side.bay_at)
	var k := bay_lit()
	if k > 0.01:
		_bay_open(interior[1], at, Color(m.r, m.g, m.b, k), bl, o + side.bay_at)


## A picture of the bay (the recess's rows 206..283) with the mouth opened by
## `open_top` / `open_bot`: its ceiling slab goes up with the upper lip and its
## floor slab down with the lower, and the gaps between are the hallway's own
## wall carried on -- the rows of the side's bay picture `wall` (its plain
## panels, which run top to bottom) just inside the ceiling and the floor. An
## interior keeps everything between its ceiling and floor where it is (its
## iris, its door, its clamps and crates are never cut or doubled); the
## hallway's wall shows above and below it. Shut, the picture as it is.
func _bay_open(t: Texture2D, at: Vector2, mod: Color, wall: Texture2D = null, wall_at := Vector2.ZERO) -> void:
	if open_top <= 0 and open_bot <= 0:
		draw_texture(t, at, mod)
		return
	if wall == null:
		wall = t
		wall_at = at
	wall = _plain_wall(wall)
	var w := float(t.get_width())
	var h := float(t.get_height())
	var a := float(BAY_SLAB)
	var dt := float(open_top)
	var db := float(open_bot)
	# the walls, where they always are
	draw_texture_rect_region(t, Rect2(at + Vector2(0, a), Vector2(w, h - 2.0 * a)), Rect2(0, a, w, h - 2.0 * a), mod)
	# the hallway's own wall carried on up under the raised ceiling and down over
	# the lowered floor (the bay picture's columns under this picture's)
	var ox := at.x - wall_at.x
	var wh := float(wall.get_height())
	if dt > 0.0:
		draw_texture_rect_region(wall, Rect2(at + Vector2(0, a - dt), Vector2(w, dt)), Rect2(ox, a, w, dt), mod)
	if db > 0.0:
		draw_texture_rect_region(wall, Rect2(at + Vector2(0, h - a), Vector2(w, db)), Rect2(ox, wh - a - db, w, db), mod)
	# the ceiling and the floor, with the lips
	draw_texture_rect_region(t, Rect2(at + Vector2(0, -dt), Vector2(w, a)), Rect2(0, 0, w, a), mod)
	draw_texture_rect_region(t, Rect2(at + Vector2(0, h - a + db), Vector2(w, a)), Rect2(0, h - a, w, a), mod)


## THE HALLWAY'S PLAIN WALL, for the gaps an opened mouth shows: a bay picture
## with the inner door's columns (bay x 44..105, the door and its frame) given
## the wall panels' own columns from left of it, tiled -- so a gap shows panels
## running on, never a piece of the door. Made once per picture.
static var _walls := {}


static func _plain_wall(t: Texture2D) -> Texture2D:
	var key := t.get_rid()
	if _walls.has(key):
		return _walls[key]
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img = img.duplicate()
	var x0 := 44
	var x1 := mini(106, img.get_width())
	var src0 := 8
	var src1 := 44
	var n := src1 - src0
	for x in range(x0, x1):
		var sx := src0 + (x - x0) % n
		for y in img.get_height():
			img.set_pixel(x, y, img.get_pixel(sx, y))
	var out := ImageTexture.create_from_image(img)
	_walls[key] = out
	return out


## A front layer (to the plate's cut) with the mouth opened: everything where it
## is but the two lip bands, which are drawn slid apart, and the frame's right
## side carried on into the gaps beside them. Shut, the layer as it is.
func _front_open(t: Texture2D, o: Vector2, mod: Color, cut: float, dx: float) -> void:
	var h := float(t.get_height())
	if (open_top <= 0 and open_bot <= 0) or dx != 0.0:
		draw_texture_rect_region(t, Rect2(o + Vector2(dx, 0), Vector2(cut, h)), Rect2(0, 0, cut, h), mod)
		return
	var dt := float(open_top)
	var db := float(open_bot)
	var tb := LIP_TOP_BAND
	var bb := LIP_BOT_BAND
	var x0 := tb.position.x
	var x1 := tb.end.x
	var parts: Array[Rect2] = [Rect2(0, 0, cut, tb.position.y), Rect2(0, tb.position.y, x0, tb.size.y),
		Rect2(x1, tb.position.y, cut - x1, tb.size.y), Rect2(0, tb.end.y, cut, bb.position.y - tb.end.y),
		Rect2(0, bb.position.y, x0, bb.size.y), Rect2(x1, bb.position.y, cut - x1, bb.size.y),
		Rect2(0, bb.end.y, cut, h - bb.end.y)]
	for r in parts:
		if r.size.x > 0.0 and r.size.y > 0.0:
			draw_texture_rect_region(t, Rect2(o + r.position, r.size), r, mod)
	# the frame's right side, carried on up and down into the gaps
	var fx := FRAME_SIDE_X.x
	var fw := FRAME_SIDE_X.y - FRAME_SIDE_X.x
	if dt > 0.0:
		draw_texture_rect_region(t, Rect2(o + Vector2(fx, tb.end.y - dt), Vector2(fw, dt)), Rect2(fx, tb.end.y, fw, dt), mod)
	if db > 0.0:
		draw_texture_rect_region(t, Rect2(o + Vector2(fx, bb.position.y), Vector2(fw, db)), Rect2(fx, bb.position.y - db, fw, db), mod)
	# the lips, slid apart
	draw_texture_rect_region(t, Rect2(o + tb.position - Vector2(0, dt), tb.size), tb, mod)
	draw_texture_rect_region(t, Rect2(o + bb.position + Vector2(0, db), bb.size), bb, mod)


## THE BODY OF A HULL, measured off its picture (`ZoomLadder.big_hull` "BODY"):
## its opaque pixels opened by 3 x 3 (anything thinner than 3 px -- masts,
## antennae, barrels, fins -- gone), and the rows from the first to the last
## where what is left is at least 30% of its widest row: its main body, the
## length of the hull (a tower or a keel narrower than that is not body: with it
## counted, the heavy's body is its whole height and this is SHRINK again).
## Image rows, [top, bottom).
static func body_rows(img: Image) -> Vector2i:
	if img == null:
		return Vector2i(-1, -1)
	var w := img.get_width()
	var h := img.get_height()
	var a := PackedByteArray()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = 1 if img.get_pixel(x, y).a > 0.5 else 0
	# erode then dilate, each a 3-wide pass across then down
	a = _pass(_pass(a, w, h, true, true), w, h, false, true)
	a = _pass(_pass(a, w, h, true, false), w, h, false, false)
	var counts := PackedInt32Array()
	counts.resize(h)
	var top := 0
	for y in h:
		var n := 0
		for x in w:
			n += a[y * w + x]
		counts[y] = n
		top = maxi(top, n)
	if top <= 0:
		return Vector2i(-1, -1)
	var y0 := -1
	var y1 := -1
	for y in h:
		if counts[y] >= int(0.3 * float(top)):
			if y0 < 0:
				y0 = y
			y1 = y + 1
	return Vector2i(y0, y1)


static func _pass(a: PackedByteArray, w: int, h: int, across: bool, erode: bool) -> PackedByteArray:
	var o := PackedByteArray()
	o.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			var p: int
			var q: int
			if across:
				p = a[i - 1] if x > 0 else 0
				q = a[i + 1] if x < w - 1 else 0
			else:
				p = a[i - w] if y > 0 else 0
				q = a[i + w] if y < h - 1 else 0
			if erode:
				o[i] = 1 if a[i] == 1 and p == 1 and q == 1 else 0
			else:
				o[i] = 1 if a[i] == 1 or p == 1 or q == 1 else 0
	return o


## Any other side: behind your ship its bay (or interior), lit from the door;
## over it the hull's layers, its lamps.
func _draw_side(m: Color, o: Vector2) -> void:
	var s := side
	if not front:
		_bay_open(s.bay_dark, o + s.bay_at, m)
		var k := bay_lit()
		if k > 0.01:
			_bay_open(s.bay_lit, o + s.bay_at, Color(m.r, m.g, m.b, k))
		_draw_interior(m, o)
		return
	# (where the camera is as this frame is drawn)
	_parallax()
	# the plate up to where its hull window starts, then the window tiled on
	var cut := s.hull_x0
	var h := float(s.solid.get_height())
	_front_open(s.solid, o, m, cut, 0.0)
	for l: Array in s.layers:
		var dx := float(par.get(l[1], 0))
		_front_open(l[0], o, m, cut, dx)
	var lk := lerpf(STANDBY, 1.0, power)
	draw_hull(self, Rect2(o.x + cut, o.y, HULL_RUN, h), o.x + cut, o.y + ROW, m, 1.0, s, par, lk, false)
	_draw_entrance_lamps(s.lamps, m, STRIP)
	for i in s.extra.size():
		var l: Dictionary = s.extra[i]
		var r: Rect2 = l.rect
		if r.position.x >= cut:
			continue
		var k := _lamp(_extra_at(i))
		if l.kind == &"beacon_lamp":
			k = 0.55 + 0.45 * _pulse(2.4, 0.0)
		_lit(s.lamps, r, k, m)


## Part of the lamps layer over the unlit plate, at `k` of its light.
func _lit(lamps: Texture2D, r: Rect2, k: float, m: Color, off: Vector2 = Vector2.ZERO) -> void:
	if k <= 0.01:
		return
	draw_texture_rect_region(lamps, Rect2(origin() + r.position + off, r.size), r, Color(m.r, m.g, m.b, clampf(k, 0.0, 1.0)))


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
	if not side.legacy:
		_side_lights(c)
		return
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
	_door_lights(c, flick)
	# THE AMBER SEAM: each lamp's light as it comes on, then breathing in a slow
	# wave round the bend (the breathing only scales a lamp that is on)
	for i in SEAM_LAMPS.size():
		var on := lamp_on(power, _seam_at(i))
		var w := 0.5 + 0.5 * sin(_clock * 1.6 - float(i) * 0.55)
		var lo := i >= 17
		_light(c, SEAM_LAMPS[i], 3 if lo else 4, (HEAT[2] if lo else HEAT[3] * sk), on * ((0.06 + 0.1 * w) if lo else (0.16 + 0.22 * w)))
	# THE LIT STRIP BESIDE THE BAY'S END, warm
	_strip_lights(c, flick)
	# the upper lip's guide lights
	_guides(c, 204.0, GUIDE_TOP.size(), 0.3)
	# a red beacon above the slot, slow; a lit window below, steady
	_light(c, BEACON.get_center(), 6, RED, 0.12 + 0.3 * _pulse(2.4, 0.0))
	_light(c, WINDOW.get_center(), 5, HEAT[2], 0.12)
	# THE END RING'S STROBES, cold, out of step
	_light(c, STROBES[0], 8, STROBE, 0.75 * _strobe(1.6, 0.0))
	_light(c, STROBES[1], 8, STROBE, 0.75 * _strobe(2.1, 0.9))


## The inner door's light on its jamb, slice by slice.
func _door_lights(c: CanvasItem, _flick: float) -> void:
	for i in 5:
		var on := lamp_on(power, _door_at(i))
		_light(c, Vector2(234, 212 + i * 16), 3, HEAT[2], (0.18 + 0.05 * _pulse(1.7, float(i) * 0.3)) * on)


func _strip_lights(c: CanvasItem, flick: float) -> void:
	for j in 6:
		var on := lamp_on(power, _door_at(clampi(DOOR_SLICES - 1 - j, 0, DOOR_SLICES - 1)))
		_light(c, Vector2(DOOR_LIGHT.position.x + 4.0, DOOR_LIGHT.position.y + 7.0 + float(j) * 14.0), 9, HEAT[3], 0.2 * flick * on)


## The other sides' light: the entrance's (as the Drum's), each own lamp's as
## it comes on, and the strobes and beacons on the hull's edge. Behind your
## ship there is none: the bay's light is its lit panels.
func _side_lights(c: CanvasItem) -> void:
	if not front:
		return
	var sk := Color(1, 1, 1).lerp(tint, 0.2)
	var flick := 0.92 + 0.08 * sin(_clock * 9.0) * sin(_clock * 3.7)
	_guides(c, GUIDE_LOW_Y + 1.0 + float(open_bot), GUIDE_LOW_N, 0.35)
	_door_lights(c, flick)
	_strip_lights(c, flick)
	_guides(c, 204.0 - float(open_top), GUIDE_TOP.size(), 0.3)
	var s := side
	for i in s.extra.size():
		var l: Dictionary = s.extra[i]
		var r: Rect2 = l.rect
		if r.position.x >= s.hull_x0:
			continue
		var on := lamp_on(power, _extra_at(i))
		if on <= 0.0:
			continue
		var at := r.get_center()
		match l.kind:
			&"seam":
				# breathing in a slow wave along the seam, as the Drum's
				var w := 0.5 + 0.5 * sin(_clock * 1.6 - at.x * 0.03 - at.y * 0.02)
				_light(c, at, int(l.radius), HEAT[3] * sk, on * (0.14 + 0.2 * w))
			&"window":
				_light(c, at, int(l.radius), HEAT[3], on * 0.22 * flick)
			&"beacon_lamp":
				_light(c, at, int(l.radius), RED, 0.12 + 0.3 * _pulse(2.4, 0.0))
			&"string":
				# each bulb on its own slow clock
				var tw := 0.5 + 0.5 * sin(_clock * (1.1 + 0.37 * float(i % 5)) + float(i) * 1.7)
				_light(c, at, int(l.radius), l.color, on * (0.25 + 0.3 * tw))
			_:
				_light(c, at, int(l.radius), l.color, on * 0.2)
	for cl: Dictionary in s.code:
		if (cl.at as Vector2).x >= s.hull_x0:
			continue
		if cl.kind == &"strobe":
			_light(c, cl.at, int(cl.radius), cl.color, 0.75 * _strobe(float(cl.period), float(cl.offset)))
		else:
			_light(c, cl.at, int(cl.radius), cl.color, 0.12 + 0.3 * _pulse(float(cl.period), float(cl.offset)))


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
## Any side but the Drum: its own window (`Side.hull_src`) of every layer --
## the crevice, the layers at their parallax `pars`, the lamps at `lamp_k` --
## with `ink` the dark behind it all (the pan's), or space (LOCAL's own).
static func draw_hull(c: CanvasItem, r: Rect2, x0: float, row_y: float, mod: Color = Color(1, 1, 1), k: float = HULL_K,
		s: StationSides.SideArt = null, pars: Dictionary = {}, lamp_k: float = 1.0, ink: bool = true) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	if s != null and not s.legacy:
		_draw_side_hull(c, r, x0, row_y, mod, k, s, pars, lamp_k, ink)
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


static func _draw_side_hull(c: CanvasItem, r: Rect2, x0: float, row_y: float, mod: Color, k: float,
		s: StationSides.SideArt, pars: Dictionary, lamp_k: float, ink: bool) -> void:
	if ink:
		c.draw_rect(r, INK, true)
	var src0 := s.hull_src
	var tw := src0.size.x * k
	var top := roundf(row_y - (ROW - src0.position.y) * k)
	var full := Rect2(r.position.x, top, r.size.x, src0.size.y * k).intersection(r)
	if full.size.x <= 0.0 or full.size.y <= 0.0:
		return
	# every pass: [texture, its shift in plate px, its modulate]
	var passes: Array = [[s.solid, 0.0, mod]]
	for l: Array in s.layers:
		passes.append([l[0], float(pars.get(l[1], 0)), mod])
	if lamp_k > 0.01:
		passes.append([s.lamps, 0.0, Color(mod.r, mod.g, mod.b, clampf(lamp_k, 0.0, 1.0))])
	for p: Array in passes:
		var dx := roundf(float(p[1]) * k)
		var area := Rect2(full.position.x + dx, full.position.y, full.size.x, full.size.y).intersection(r)
		if area.size.x <= 0.0:
			continue
		var i := floori((area.position.x - x0 - dx) / tw)
		while true:
			var tx := roundf(x0 + dx + float(i) * tw)
			if tx >= area.end.x:
				break
			var tile := Rect2(tx, top, tw, src0.size.y * k).intersection(area)
			if tile.size.x > 0.0:
				var src := Rect2(src0.position + (tile.position - Vector2(tx, top)) / k, tile.size / k)
				c.draw_texture_rect_region(p[0], tile, src, p[2])
			i += 1


class _Glow extends Control:
	var face: StationFace

	func _draw() -> void:
		if face != null:
			face.draw_lights(self)
