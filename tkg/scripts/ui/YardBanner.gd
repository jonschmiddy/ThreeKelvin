class_name YardBanner
extends Control

## One manufacturer's banner on the front door's gantry (Jon's W2 v10, Nov 10):
## long cloth on a rod, the name high up, the emblem under it, a forked foot.
## Clicking it picks the manufacturer. The cloth hangs and moves in `YardCloth` (Jon, Nov 24, the
## banner page: "The movement is PERFECT"); this is its click target, at rest, and its picture.
## Why: docs/why/YardBanner.md#cloth

signal pressed

const BW := 48
## A third longer than the mockup's 76 (Jon, Nov 11: "the banners can be longer").
const CLOTH := 100
## The click rect's margin either side of the cloth (the rod's overhang).
const MARGIN := 4
const TRUSS_Y := 18
const ROD_Y := 34
## The cloths' three flat bands' first rows, and the ??? cloths as the films hang them.
const HEAD_END := 22
const MID_END := 86
## The ??? cloth (Jon, Nov 24): dark grey in the three lighting bands, its marks light grey.
const LOCKED_FIELD := Color8(38, 40, 48)
const LOCKED_INK := Color8(168, 173, 184)
## The name on a light field (Verity's, Calyx's) is dark ink; the emblem keeps the manufacturer's colour.
const DARK_INK := Color8(34, 24, 14)
## Korvan's grey with orange marks and a trim along its foot; Solari's amber with dark marks (Jon, Nov 24):
## head, mid, foot, ink, outline, trim.
const MANUFACTURER_CLOTH := {
	&"korvan": [Color8(126, 132, 142), Color8(106, 112, 122), Color8(86, 90, 98), Color8(224, 136, 46), Color8(20, 22, 26), true],
	&"solari": [Color8(236, 160, 52), Color8(214, 140, 42), Color8(178, 112, 32), Color8(44, 26, 12), Color8(40, 22, 10), false],
}
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
## The flat cloth (bands, marks, outline, trim), 48 x 100, before its material (`YardClothTex`).
var cloth: Image = null

## Flat cloths by manufacturer and lock: built once a session, not once a visit.
static var _cloths := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Build the cloth once for this manufacturer, open or locked.
func setup(i: int, m: StringName, is_open: bool, x: int) -> void:
	index = i
	manufacturer = m
	open = is_open
	hall_x = x
	position = Vector2(x - MARGIN, TRUSS_Y)
	size = Vector2(BW + 2 * MARGIN, ROD_Y - TRUSS_Y + 4 + CLOTH)
	var md: ManufacturerData = DB.manufacturers.get(m)
	tooltip_text = Widgets.tip("%s
%s" % [md.name if open else "????", md.identity]) if md != null else ""
	if not open:
		tooltip_text += Widgets.tip("

%s" % Unlocks.lock_line(m))
	cloth = flat_cloth(m, open)


## The cloth in code (Jon, Nov 24: "weird artifacts"): three flat bands, the emblem and the name (or the
## ??? marks) in the pixel font, a 1 px outline round the silhouette (forked foot included), Korvan's trim.
## Why: docs/why/YardBanner.md#cloth
static func flat_cloth(m: StringName, is_open: bool) -> Image:
	var key := cloth_key(m, is_open)
	if _cloths.has(key):
		return _cloths[key]
	var md: ManufacturerData = DB.manufacturers.get(m)
	var bands := _bands(LOCKED_FIELD)
	var outline := _scaled(LOCKED_FIELD, 0.35)
	var trim := false
	var ink := LOCKED_INK
	var word_ink := LOCKED_INK
	if is_open and md != null:
		var mc: Array = MANUFACTURER_CLOTH.get(m, [])
		if mc.is_empty():
			bands = _bands(md.field)
			outline = _scaled(md.field, 0.2)
			ink = md.colour
			var light := md.field.r8 + md.field.g8 + md.field.b8 > 1.76 * 255.0
			word_ink = DARK_INK if light else md.colour
		else:
			bands.assign([mc[0], mc[1], mc[2]])
			ink = mc[3]
			word_ink = ink
			outline = mc[4]
			trim = mc[5]
	var img := Image.create(BW, CLOTH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in CLOTH:
		var c: Color = bands[0] if r < HEAD_END else (bands[1] if r < MID_END else bands[2])
		for x in BW:
			if _inside(x, r):
				img.set_pixel(x, r, c)
	if is_open and md != null:
		_emblem(img, m, ink)
		YardClothTex.word(img, DB.short_name(md.name).to_upper(), UITheme.FS_SMALL, 7, word_ink)
	else:
		YardClothTex.word(img, "???", UITheme.FS_SMALL, 7, ink)
		YardClothTex.word(img, "???", UITheme.FS_HEAD, 30, ink)
	var edge := _outline(img, outline)
	if trim:
		_trim(img, edge, Color8(int(ink.r8 * 0.9), int(ink.g8 * 0.9), int(ink.b8 * 0.9)))
	_cloths[key] = img
	return img


## Every ??? cloth is the same cloth.
static func cloth_key(m: StringName, is_open: bool) -> String:
	return String(m) if is_open else "???"


## The game's emblem (`CardView.draw_emblem`), in mark units of two pixels, round row 36.
static func _emblem(img: Image, m: StringName, ink: Color) -> void:
	var rects: Array = EMBLEM.get(m, [[-3.5, -3.5, 7, 7]])
	for e: Array in rects:
		var x0 := int(round(BW / 2.0 + float(e[0]) * 2.0))
		var y0 := int(round(36.0 + float(e[1]) * 2.0))
		for yy in int(float(e[3]) * 2.0):
			for xx in int(float(e[2]) * 2.0):
				var px := x0 + xx
				var py := y0 + yy
				if px >= 0 and px < BW and py >= 0 and py < CLOTH:
					img.set_pixel(px, py, ink)


## Korvan's thin orange line just inside its forked foot's edge.
static func _trim(img: Image, edge: PackedByteArray, col: Color) -> void:
	for x in BW:
		var low := -1
		for r in CLOTH:
			if _inside(x, r):
				low = r
		var rb := low - 1
		if rb > 60 and edge[rb * BW + x] == 0:
			img.set_pixel(x, rb, col)


## The silhouette's own edge pixels in `col` (not the top, which meets the rod); returns which.
static func _outline(img: Image, col: Color) -> PackedByteArray:
	var e := PackedByteArray()
	e.resize(BW * CLOTH)
	for r in range(1, CLOTH):
		for x in BW:
			if not _inside(x, r):
				continue
			var inner := r + 1 < CLOTH and _inside(x, r + 1) and x > 0 and _inside(x - 1, r) 				and x < BW - 1 and _inside(x + 1, r)
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


## A field's three lighting bands (the banner page's make_cloths): the head lifted 15 % (at most 22 a
## channel), the body itself, the foot at 82 %.
static func _bands(f: Color) -> Array[Color]:
	var head := Color8(mini(f.r8 + 22, even(f.r8 * 1.15)), mini(f.g8 + 22, even(f.g8 * 1.15)), mini(f.b8 + 22, even(f.b8 * 1.15)))
	var out: Array[Color] = [head, Color8(f.r8, f.g8, f.b8), _scaled(f, 0.82)]
	return out


static func _scaled(c: Color, k: float) -> Color:
	return Color8(clampi(even(c.r8 * k), 0, 255), clampi(even(c.g8 * k), 0, 255), clampi(even(c.b8 * k), 0, 255))


## Rounded half to even, as the page's Python and its Uint8ClampedArray round.
static func even(v: float) -> int:
	var f := floorf(v)
	var d := v - f
	if d > 0.5 or (d == 0.5 and int(f) % 2 != 0):
		return int(f) + 1
	return int(f)


## Only the cloth is the thing, as it hangs at rest: not the chains, the air beside it, or anything
## below its foot, which once picked from the floor (Jon, Nov 11). Its moving picture never moves this.
func _has_point(p: Vector2) -> bool:
	return on_cloth(p)


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
	elif what == NOTIFICATION_MOUSE_EXIT:
		hover = false
