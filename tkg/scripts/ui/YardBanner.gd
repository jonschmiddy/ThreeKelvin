class_name YardBanner
extends Control

## One manufacturer's banner on the front door's gantry (Jon's W2 v10, Nov 10):
## long cloth on a rod, the name high up, the emblem under it, a forked foot.
## Clicking it picks the manufacturer. The cloth sways in a slow wave down its
## rows (Jon, Nov 24: "can be smoother"); the rod and chains never move.
## Why: docs/why/ShipRoom.md#banners

signal pressed

const BW := 48
## A third longer than the mockup's 76 (Jon, Nov 11: "the banners can be longer").
const CLOTH := 100
## The margin a posed cloth needs either side of the rod for its shear.
const MARGIN := 4
const TRUSS_Y := 18
const ROD_Y := 34
## The wave: offset(r) = A (r/99)^1.5 sin(2 pi t / P - K r + phase), A at the foot, K half a
## wavelength on the cloth, each banner its own period and phase (bandfix.wave_offsets).
const WAVE_A := 1.5
const WAVE_K := PI / 100.0
const WAVE_P := [5.0, 6.0, 7.5, 10.0, 6.0, 7.5, 5.0]
const WAVE_PHASE := [0.0, 1.7, 3.1, 4.4, 0.9, 5.3, 2.6]
## The cloths' three flat bands' first rows, and the ??? cloths as the films hang them.
const HEAD_END := 22
const MID_END := 86
const LOCKED_BANDS := [Color8(26, 27, 33), Color8(22, 22, 27), Color8(19, 19, 23)]
const LOCKED_OUTLINE := Color8(16, 17, 22)
## Korvan's grey with orange marks and a trim along its foot; Solari's amber with dark marks (Jon, Nov 24):
## head, mid, foot, ink, outline, trim.
const MAKER_CLOTH := {
	&"korvan": [Color8(126, 132, 142), Color8(106, 112, 122), Color8(86, 90, 98), Color8(224, 136, 46), Color8(20, 22, 26), true],
	&"solari": [Color8(236, 160, 52), Color8(214, 140, 42), Color8(178, 112, 32), Color8(44, 26, 12), Color8(40, 22, 10), false],
}
const STEEL := Color8(74, 82, 96)
const CHAIN := Color8(118, 112, 96)
const LOCKED_INK := Color8(104, 110, 124)
## The game's emblems (`CardView.draw_emblem`), as rects in mark units, for the cloth's pixels.
const EMBLEM := {
	&"korvan": [[-4.5, -5, 9, 2], [-3.5, -1, 7, 2], [-2.5, 3, 5, 2]],
	&"solari": [[-0.5, -4.5, 1, 9], [-4.5, -0.5, 9, 1], [-1.5, -1.5, 3, 3]],
	&"probate": [[-4.5, -4.5, 9, 2], [-3.5, -2.5, 7, 2], [-2.5, -0.5, 5, 2], [-2.5, 2.5, 1, 2], [-0.5, 2.5, 1, 2], [1.5, 2.5, 1, 2]],
	&"redline": [[-4.5, -1.5, 4, 3], [0.5, -1.5, 4, 3]],
	&"verity": [[-4.5, -2.5, 9, 2], [-4.5, 0.5, 9, 2]],
	&"cygnet": [[-1.5, -0.5, 3, 3], [-4.5, -2.5, 9, 1], [-3.5, -4.5, 7, 1], [-0.5, 2.5, 1, 2]],
	&"calyx": [[-1.5, -4.5, 3, 9], [-4.5, -1.5, 9, 3]],
}

var index: int = 0
var manufacturer: StringName = &""
## Named and marked, or a ??? cloth.
var open: bool = true
## The frame x of the rod's left end (the cloth's left edge).
var hall_x: int = 0
var hover: bool = false
## Dimmed with the room (1: as hung).
var gloom: float = 1.0

var _cloth: ImageTexture
var _ring: ImageTexture
## The cloth's edge colours per row (left, right), for the edge's fractional creep.
var _edge_l := PackedColorArray()
var _edge_r := PackedColorArray()
var _ink := Color.WHITE
var _font: Font
## This frame's offset of each row, in pixels (drawn whole, the edge taking the fraction).
var _off := PackedFloat32Array()
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font = UITheme.pixel_font()
	_off.resize(CLOTH)


## Build the cloth once for this manufacturer, open or locked.
func setup(i: int, m: StringName, is_open: bool, x: int) -> void:
	index = i
	manufacturer = m
	open = is_open
	hall_x = x
	position = Vector2(x - MARGIN, TRUSS_Y)
	size = Vector2(BW + 2 * MARGIN, ROD_Y - TRUSS_Y + 4 + CLOTH)
	var md: ManufacturerData = DB.manufacturers.get(m)
	tooltip_text = Widgets.tip("%s\n%s" % [md.name if open else "????", md.identity]) if md != null else ""
	if not open:
		tooltip_text += Widgets.tip("\n\n%s" % Unlocks.lock_line(m))
	_bake(md)
	_t = 0.0
	_wave()
	queue_redraw()


## The cloth in code (Jon, Nov 24: "weird artifacts"): three flat bands, the emblem, a 1 px
## outline round the silhouette (forked foot included), Korvan's orange trim along its foot.
## Why: docs/why/ShipRoom.md#banners
func _bake(md: ManufacturerData) -> void:
	var bands: Array = LOCKED_BANDS
	var outline := LOCKED_OUTLINE
	var trim := false
	_ink = LOCKED_INK
	if open and md != null:
		var mc: Array = MAKER_CLOTH.get(manufacturer, [])
		if mc.is_empty():
			bands = [_sc(md.field, 1.12), md.field, _sc(md.field, 0.86)]
			_ink = md.colour
		else:
			bands = [mc[0], mc[1], mc[2]]
			_ink = mc[3]
			outline = mc[4]
			trim = mc[5]
	var img := Image.create(BW, CLOTH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in CLOTH:
		var c: Color = bands[0] if r < HEAD_END else (bands[1] if r < MID_END else bands[2])
		for x in BW:
			if _inside(x, r):
				img.set_pixel(x, r, c)
	if open:
		_emblem(img)
	var edge := _outline(img, outline)
	if trim:
		_trim(img, edge)
	_edge_l.resize(CLOTH)
	_edge_r.resize(CLOTH)
	for r in CLOTH:
		_edge_l[r] = img.get_pixel(int(_left_edge(r)), r)
		_edge_r[r] = img.get_pixel(int(_right_edge(r)), r)
	_cloth = ImageTexture.create_from_image(img)
	var ring := Image.create(BW + 4, CLOTH + 4, false, Image.FORMAT_RGBA8)
	ring.fill(Color(0, 0, 0, 0))
	for r in CLOTH:
		for x in BW:
			if _inside(x, r):
				ring.fill_rect(Rect2i(x, r, 5, 5), UITheme.MARK)
	_ring = ImageTexture.create_from_image(ring)


## The game's emblem (`CardView.draw_emblem`), in mark units of two pixels, round row 36.
func _emblem(img: Image) -> void:
	var rects: Array = EMBLEM.get(manufacturer, [[-3.5, -3.5, 7, 7]])
	for e: Array in rects:
		var x0 := int(round(BW / 2.0 + float(e[0]) * 2.0))
		var y0 := int(round(36.0 + float(e[1]) * 2.0))
		for yy in int(float(e[3]) * 2.0):
			for xx in int(float(e[2]) * 2.0):
				var px := x0 + xx
				var py := y0 + yy
				if px >= 0 and px < BW and py >= 0 and py < CLOTH:
					img.set_pixel(px, py, _ink)


## Korvan's thin orange line just inside its forked foot's edge.
func _trim(img: Image, edge: PackedByteArray) -> void:
	for x in BW:
		var low := -1
		for r in CLOTH:
			if _inside(x, r):
				low = r
		var rb := low - 1
		if rb > 60 and edge[rb * BW + x] == 0:
			img.set_pixel(x, rb, _sc(_ink, 0.9))


## The silhouette's own edge pixels in `col` (not the top, which meets the rod); returns which.
static func _outline(img: Image, col: Color) -> PackedByteArray:
	var e := PackedByteArray()
	e.resize(BW * CLOTH)
	for r in range(1, CLOTH):
		for x in BW:
			if not _inside(x, r):
				continue
			var inner := r + 1 < CLOTH and _inside(x, r + 1) and x > 0 and _inside(x - 1, r) \
				and x < BW - 1 and _inside(x + 1, r)
			if not inner:
				e[r * BW + x] = 1
				img.set_pixel(x, r, col)
	return e


## The forked foot: full width to ten rows from the foot, then two flaps meeting at the notch.
static func _inside(x: int, r: int) -> bool:
	if r <= CLOTH - 10:
		return true
	var d := float(CLOTH - 1 - r) / 8.0
	return float(x) <= 24.0 * d or float(x) >= 47.0 - 23.0 * d


static func _left_edge(r: int) -> float:
	for x in BW:
		if _inside(x, r):
			return float(x)
	return 0.0


static func _right_edge(r: int) -> float:
	for x in range(BW - 1, -1, -1):
		if _inside(x, r):
			return float(x)
	return float(BW - 1)


static func _sc(c: Color, k: float) -> Color:
	return Color(minf(1.0, c.r * k), minf(1.0, c.g * k), minf(1.0, c.b * k), 1.0)


## This frame's offset of each row: none at the rod, up to WAVE_A at the foot, travelling down.
func _wave() -> void:
	var p: float = WAVE_P[index % WAVE_P.size()]
	var ph := TAU * _t / p + float(WAVE_PHASE[index % WAVE_PHASE.size()])
	for r in CLOTH:
		_off[r] = WAVE_A * pow(float(r) / float(CLOTH - 1), 1.5) * sin(ph - WAVE_K * float(r))


func _process(delta: float) -> void:
	_t += delta
	_wave()
	queue_redraw()


## Only the cloth is the thing, as it hangs this frame: not the chains, the air
## beside it, or anything below its foot, which once picked from the floor (Jon, Nov 11).
func _has_point(p: Vector2) -> bool:
	var r := int(floorf(p.y)) - (ROD_Y - TRUSS_Y + 4)
	var dx := roundf(_off[r]) if r >= 0 and r < CLOTH else 0.0
	return on_cloth(p - Vector2(dx, 0.0))


## Is `p` (in this control) on the cloth at rest, forked foot and all?
static func on_cloth(p: Vector2) -> bool:
	var r := int(floorf(p.y)) - (ROD_Y - TRUSS_Y + 4)
	if r < 0 or r >= CLOTH:
		return false
	var x := int(floorf(p.x)) - MARGIN
	return x >= 0 and x < BW and _inside(x, r)


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Audio.click()
		pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		hover = true
		Audio.hover()
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		hover = false
		queue_redraw()


func _draw() -> void:
	if _cloth == null:
		return
	var g := Color(gloom, gloom, gloom, 1.0)
	# the rig: two chains from the truss, the rod
	var rod_y := float(ROD_Y - TRUSS_Y)
	for cx: float in [MARGIN + 6.0, MARGIN + BW - 6.0]:
		draw_rect(Rect2(cx, 0, 1, rod_y), CHAIN * g, true)
	draw_rect(Rect2(0, rod_y, BW + 2 * MARGIN, 4), _sc(STEEL, 0.9) * g, true)
	draw_rect(Rect2(0, rod_y, BW + 2 * MARGIN, 1), _sc(STEEL, 1.4) * g, true)
	var top := rod_y + 4.0
	var bright := 1.18 if hover else 1.0
	var mod := Color(bright * gloom, bright * gloom, bright * gloom, 1.0)
	if hover:
		for r in CLOTH + 4:
			var o := roundf(_off[clampi(r - 2, 0, CLOTH - 1)])
			draw_texture_rect_region(_ring, Rect2(MARGIN - 2 + o, top - 2.0 + r, BW + 4, 1), Rect2(0, r, BW + 4, 1))
	for r in CLOTH:
		var of := _off[r]
		var dx := roundf(of)
		var y := top + float(r)
		draw_texture_rect_region(_cloth, Rect2(MARGIN + dx, y, BW, 1), Rect2(0, r, BW, 1), mod)
		# the edge creeps by the fraction: one pixel past it at that much alpha
		var fr := of - dx
		if absf(fr) > 0.05:
			var ec: Color = _edge_r[r] if fr > 0.0 else _edge_l[r]
			var ex := MARGIN + dx + (_right_edge(r) + 1.0 if fr > 0.0 else _left_edge(r) - 1.0)
			draw_rect(Rect2(ex, y, 1, 1), Color(ec.r * mod.r, ec.g * mod.g, ec.b * mod.b, absf(fr)), true)
	# the words never move: the wave is under half a pixel over the cloth's top half
	var light := bright * gloom
	var md: ManufacturerData = DB.manufacturers.get(manufacturer)
	if open and md != null:
		_word(DB.short_name(md.name).to_upper(), UITheme.FS_SMALL, top + 7.0, _ink * Color(light, light, light, 1.0))
	else:
		_word("???", UITheme.FS_SMALL, top + 7.0, _ink * Color(light, light, light, 1.0))
		_word("???", UITheme.FS_HEAD, top + 30.0, _ink * Color(0.85 * light, 0.85 * light, 0.85 * light, 1.0))


## A word centred on the cloth, its top at `top`, in the pixel font's own ascent.
func _word(s: String, px: int, top: float, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc := _font.get_ascent(px)
	var x := floorf(MARGIN + (BW - w) / 2.0 + 0.5)
	draw_string(_font, Vector2(x, floorf(top + asc + 0.5)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
