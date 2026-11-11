class_name YardBanner
extends Control

## One manufacturer's banner on the front door's gantry (Jon's W2 v10, Nov 10):
## long cloth on a rod, the name high up, the emblem under it, a forked foot.
## Clicking it picks the manufacturer. The sway is a whole-pixel shear of the
## cloth, more at the foot than the head, so it steps rather than glides.
## Why: docs/why/ChassisSelect.md#banner-yard

signal pressed

const BW := 48
## A third longer than the mockup's 76 (Jon, Nov 11: "the banners can be longer").
const CLOTH := 100
## The cloth's lighting bands: lit head, mid, shaded foot (the 76-row cloth's 22 and 48).
const HEAD_ROWS := 22
const MID_ROWS := 64
## The margin a posed cloth needs either side of the rod for its shear.
const MARGIN := 4
const TRUSS_Y := 18
const ROD_Y := 34
## The biggest shear at the foot, in pixels: nine poses, -4 to 4.
const SWAY_PX := 4
const STEEL := Color8(74, 82, 96)
const CHAIN := Color8(118, 112, 96)
const LOCKED_FIELD := Color8(38, 40, 48)
const LOCKED_INK := Color8(104, 110, 124)
const LAMP := Vector3(1.0, 0.93, 0.82)
## The hall's ceiling lamps, and the first one again where the hall is continued.
const LAMPS := [100.0, 256.0, 411.0, 570.0, 727.0, 866.0]
## Each banner's own period and phase, so no two sway together.
const SWAY := [[4.0, 0.0], [4.4, 1.1], [3.7, 2.3], [4.2, 3.4], [3.9, 4.6], [4.6, 5.5], [3.8, 0.7]]
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
## The hall x of the rod's left end (the cloth's left edge).
var hall_x: int = 0
var hover: bool = false
## Dimmed with the hall when a locked set is shown.
var gloom: float = 1.0

var _poses: Array[ImageTexture] = []
var _rings: Array[ImageTexture] = []
var _k: int = 0
var _t: float = 0.0
var _period: float = 4.0
var _phase: float = 0.0
var _font: Font
var _light_head: float = 1.0
var _light_mid: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font = UITheme.pixel_font()


## Build the cloth once for this manufacturer, open or locked, and its nine poses.
func setup(i: int, m: StringName, is_open: bool, x: int) -> void:
	index = i
	manufacturer = m
	open = is_open
	hall_x = x
	position = Vector2(x - MARGIN, TRUSS_Y)
	size = Vector2(BW + 2 * MARGIN, ROD_Y - TRUSS_Y + 4 + CLOTH)
	var sw: Array = SWAY[i % SWAY.size()]
	_period = float(sw[0])
	_phase = float(sw[1])
	var md: ManufacturerData = DB.manufacturers.get(m)
	var name := DB.short_name(md.name).to_upper() if md != null else String(m).to_upper()
	tooltip_text = Widgets.tip("%s\n%s" % [md.name if open else "????", md.identity]) if md != null else ""
	if not open:
		tooltip_text += Widgets.tip("\n\n%s" % Unlocks.lock_line(m))
	_bake(md, name)
	queue_redraw()


## The cloth's pixels: the field in folds, a lit edge and a shaded one, the rule
## under the name, the emblem; lit from the lamp over it, brighter at the head.
func _bake(md: ManufacturerData, _name: String) -> void:
	var field: Color = md.field if (open and md != null) else LOCKED_FIELD
	var mark: Color = md.colour if md != null else UITheme.CHILL
	var img := Image.create(BW, CLOTH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var lowest := PackedInt32Array()
	lowest.resize(BW)
	for r in CLOTH:
		for x in BW:
			if not _inside(x, r):
				continue
			var k := 1.0
			if x <= 7: k = 1.12
			elif x >= 9 and x <= 16: k = 0.96
			elif x >= 18 and x <= 25: k = 1.06
			elif x >= 30 and x <= 37: k = 0.9
			elif x >= 40: k = 0.8
			if x == 0: k = 1.3
			elif x == BW - 1: k = 0.55
			img.set_pixel(x, r, _sc(field, k))
			lowest[x] = r
	for x in BW:
		img.set_pixel(x, lowest[x], _sc(field, 0.55))
	for x in range(6, BW - 6):
		img.set_pixel(x, 18, _sc(field, 0.7))
	if open:
		var rects: Array = EMBLEM.get(manufacturer, [[-3.5, -3.5, 7, 7]])
		for e: Array in rects:
			var x0 := int(round(BW / 2.0 + float(e[0]) * 2.0))
			var y0 := int(round(36.0 + float(e[1]) * 2.0))
			for yy in int(float(e[3]) * 2.0):
				for xx in int(float(e[2]) * 2.0):
					var px := x0 + xx
					var py := y0 + yy
					if px >= 0 and px < BW and py >= 0 and py < CLOTH:
						img.set_pixel(px, py, mark)
	# the lamp over it, in four steps head to foot
	var cx := float(hall_x + BW / 2)
	var near := 0.0
	for lx: float in LAMPS:
		near = maxf(near, exp(-pow((cx - lx) / 85.0, 2.0)))
	var bl := 0.82 + 0.3 * near
	_light_head = _quant(bl * 1.08)
	_light_mid = _quant(bl * 0.85)
	for r in CLOTH:
		var f := float(r)
		var v: float
		var head_r := float(HEAD_ROWS)
		var mid_r := float(MID_ROWS)
		if f < head_r: v = lerpf(bl * 1.15, bl * 0.95, f / head_r)
		elif f < mid_r: v = lerpf(bl * 0.95, bl * 0.7, (f - head_r) / (mid_r - head_r))
		else: v = lerpf(bl * 0.7, bl * 0.45, (f - mid_r) / float(CLOTH - 1 - MID_ROWS))
		var q := _quant(v)
		for x in BW:
			var c := img.get_pixel(x, r)
			if c.a == 0.0:
				continue
			img.set_pixel(x, r, Color(minf(1.0, c.r * q * (0.92 + 0.08 * LAMP.x)),
				minf(1.0, c.g * q * (0.92 + 0.08 * LAMP.y)), minf(1.0, c.b * q * (0.92 + 0.08 * LAMP.z)), 1.0))
	_poses.clear()
	_rings.clear()
	for k in range(-SWAY_PX, SWAY_PX + 1):
		var posed := Image.create(BW + 2 * MARGIN, CLOTH, false, Image.FORMAT_RGBA8)
		posed.fill(Color(0, 0, 0, 0))
		for r in CLOTH:
			posed.blit_rect(img, Rect2i(0, r, BW, 1), Vector2i(MARGIN + shear(k, r), r))
		_poses.append(ImageTexture.create_from_image(posed))
		var ring := Image.create(BW + 2 * MARGIN, CLOTH, false, Image.FORMAT_RGBA8)
		ring.fill(Color(0, 0, 0, 0))
		for r in CLOTH:
			for x in BW + 2 * MARGIN:
				if posed.get_pixel(x, r).a > 0.15:
					ring.set_pixel(x, r, UITheme.MARK)
		_rings.append(ImageTexture.create_from_image(ring))


## Whole pixels: row r of the cloth moves round(k * (r/h)^1.5), nothing at the rod.
static func shear(k: int, r: int) -> int:
	return int(round(float(k) * pow(float(r) / float(CLOTH - 1), 1.5)))


## The forked foot: full width to ten rows from the foot, then two flaps meeting at the notch.
static func _inside(x: int, r: int) -> bool:
	if r <= CLOTH - 10:
		return true
	var d := float(CLOTH - 1 - r) / 8.0
	return float(x) <= 24.0 * d or float(x) >= 47.0 - 23.0 * d


static func _sc(c: Color, k: float) -> Color:
	return Color(minf(1.0, c.r * k), minf(1.0, c.g * k), minf(1.0, c.b * k), 1.0)


## Five light levels, as the mockup stepped the cloth.
static func _quant(v: float) -> float:
	return clampf(floorf(v * 5.0 + 0.5) / 5.0, 0.2, 1.4)


func _process(delta: float) -> void:
	_t += delta
	var k := int(round(float(SWAY_PX) * sin(TAU * _t / _period + _phase)))
	if k != _k:
		_k = k
		queue_redraw()


## Only the cloth is the thing, as it hangs this frame: not the chains, the air
## beside it, or anything below its foot, which once picked from the floor (Jon, Nov 11).
func _has_point(p: Vector2) -> bool:
	return on_cloth(p, _k)


## Is `p` (in this control) on the cloth posed `k`, forked foot and all?
static func on_cloth(p: Vector2, k: int) -> bool:
	var r := int(floorf(p.y)) - (ROD_Y - TRUSS_Y + 4)
	if r < 0 or r >= CLOTH:
		return false
	var x := int(floorf(p.x)) - MARGIN - shear(k, r)
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
	if _poses.is_empty():
		return
	var g := Color(gloom, gloom, gloom, 1.0)
	# the rig: two chains from the truss, the rod
	var rod_y := float(ROD_Y - TRUSS_Y)
	for cx: float in [MARGIN + 6.0, MARGIN + BW - 6.0]:
		draw_rect(Rect2(cx, 0, 1, rod_y), CHAIN * g, true)
	draw_rect(Rect2(0, rod_y, BW + 2 * MARGIN, 4), _sc(STEEL, 0.9) * g, true)
	draw_rect(Rect2(0, rod_y, BW + 2 * MARGIN, 1), _sc(STEEL, 1.4) * g, true)
	var at := Vector2(0, rod_y + 4)
	var pi := _k + SWAY_PX
	if hover:
		# the mark: a two pixel ring round the cloth's own silhouette
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if dx == 0 and dy == 0:
					continue
				draw_texture(_rings[pi], at + Vector2(dx, dy))
	var bright := 1.18 if hover else 1.0
	draw_texture(_poses[pi], at, Color(bright * gloom, bright * gloom, bright * gloom, 1.0))
	# the words are drawn over the posed cloth: the name rides the rod, which never shears
	var md: ManufacturerData = DB.manufacturers.get(manufacturer)
	var light := _light_head * bright * gloom
	if open and md != null:
		var dark := md.field.r + md.field.g + md.field.b > 1.76
		var ink: Color = Color8(34, 24, 14) if dark else md.colour
		_word(DB.short_name(md.name).to_upper(), UITheme.FS_SMALL, at.y + 7.0 + shear(_k, 7), ink * Color(light, light, light, 1.0))
	else:
		_word("???", UITheme.FS_SMALL, at.y + 7.0 + shear(_k, 7), LOCKED_INK * Color(light, light, light, 1.0))
		var mid := _light_mid * bright * gloom
		_word("???", UITheme.FS_HEAD, at.y + 30.0 + shear(_k, 38), LOCKED_INK * Color(mid, mid, mid, 1.0))


## A word centred on the cloth, its top at `top`, in the pixel font's own ascent.
func _word(s: String, px: int, top: float, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc := _font.get_ascent(px)
	var x := floorf(MARGIN + (BW - w) / 2.0 + 0.5)
	draw_string(_font, Vector2(x, floorf(top + asc + 0.5)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
