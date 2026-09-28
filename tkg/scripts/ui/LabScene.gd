class_name LabScene
extends StationRoom

## The Laboratory: one of Jon's five painted labs, lit and running.
##
## IT WAS A ROOM DRAWN IN CODE -- a fume hood, a whiteboard, two culture tanks
## -- with the recipes behind the hood's glass. It is one picture per
## development level now, each a PixelLab take Jon chose and had edited by hand,
## and each lit the way Five Labs, Lit lit it: the artifact he judged them on,
## and the reference for everything below. `tools/lab_install.py` installed
## them (`art/sprites/station/lab/`) with every light's pool worked out ahead of
## time; what happens here is the part that moves.
##
## THREE LAYERS, AND THE RECIPES BETWEEN THEM.
##
##   this node   the picture, lit (`lab_light.gdshader`), and its life: the
##               small monitors typing, bubbles in the capital's tanks, the
##               flasks on its counter fizzing
##   (rows)      the recipe rows, `StationScreen`'s, standing in the picture's
##               own screen (`win_rect`), clipped so the power-on's scan can
##               bring them up
##   fx_layer()  what the big screen does, over the rows: the city's sweep,
##               the outpost's and settlement's bad signal, the unclaimed
##               screen failing with its bulb, the capital's rim light
##
## ON A 30 HZ CLOCK, like the shop, because the prototype drew at 30 and every
## fault was shaped for that rate. Each lab powers on from black the first time
## you step onto the deck at a station: the lamps strike, the room fades up,
## the screen scans the recipes on.
##
## Drawn at 1:1 at the top-left, like the shop's rooms: every lab is the
## 740x431 wall they were laid out on.

const LAB_DIR := "res://art/sprites/station/lab/"
const LAB_JSON := LAB_DIR + "labs.json"
const LIGHT_SHADER := preload("res://shaders/lab_light.gdshader")
const GLASS_SHADER := preload("res://shaders/lab_glass.gdshader")
const PANEL := Vector2(740.0, 431.0)
const HZ := 30.0

## What the life may draw over, as `lab_install.py` marked it in G (its MASK).
const MASK_TANK := 1
const MASK_FLASK := 2
const MASK_MONITOR := 4
const MASK_GLASS := 8

## The small monitors' inks (ink, mid, pale): on a lit screen, and on a dark one.
const LIGHTPAL := [Color("#18687e"), Color("#4a9eb0"), Color("#76c8d6")]
const DARKPAL := [Color("#82f0d2"), Color("#46a596"), Color("#2d6e69")]

## The clock held at this many seconds after power-on, for `stationshot
## labclock=`: a lab caught at a known moment. Below zero the clock runs.
static var pin_clock := -1.0

static var _doc: Dictionary = {}
static var _doc_read := false


## labs.json, read once.
static func doc() -> Dictionary:
	if not _doc_read:
		_doc_read = true
		if FileAccess.file_exists(LAB_JSON):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAB_JSON))
			if parsed is Dictionary:
				_doc = parsed
	return _doc


## This station's lab, as the installer wrote it.
var lab: Dictionary = {}
## The recipe rows' holder, which the screen places at `win_rect` and this
## opens as the power-on's scan passes.
var rows_clip: Control = null

var _level := ""
var _pic: TextureRect
var _mat: ShaderMaterial
var _life: _Life
var _glass: _Glass
## The light and the emitter files, as bytes: the fizz reads the light at a
## cell, the life reads what it may draw over.
var _pools := PackedByteArray()
var _own := PackedByteArray()

var _lab_clock := 0.0
var _tick_n := -1
var _boot_at := 0.0
var _powered := false
## This tick: the time, the time since power-on, and the room's own power-on.
var _now := 0.0
var _tb := 1000.0
var _room := 1.0
## This tick's weight per light or emitter, steady times breathing.
var _w: Dictionary = {}
## Per light, its steady and breathing parts; and the room between the lights.
var _lwb := PackedFloat32Array()
var _lwm := PackedFloat32Array()
var _amb := 0.0


func _init() -> void:
	super()
	_mat = ShaderMaterial.new()
	_mat.shader = LIGHT_SHADER
	_pic = TextureRect.new()
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.stretch_mode = TextureRect.STRETCH_KEEP
	_pic.material = _mat
	_pic.size = PANEL
	add_child(_pic)
	_life = _Life.new()
	_life.lab = self
	_life.size = PANEL
	add_child(_life)
	_glass = _Glass.new()
	_glass.lab = self
	_lwb.resize(8)
	_lwm.resize(8)


## The room is the picture: nothing of the drawn station goes behind it.
func _draw() -> void:
	pass


## No banners: the picture is Jon's, and a hung banner would be painted over it.
func banner_spots() -> Array:
	return []


## What the big screen does, over the recipe rows. The screen stacks it last.
func fx_layer() -> Control:
	return _glass


## Where the recipe rows stand: inside the picture's screen, where the
## prototype drew them.
func win_rect() -> Rect2:
	var w: Array = lab.get("win", [])
	if w.size() < 4:
		return Rect2(170.0, 110.0, 400.0, 180.0)
	return Rect2(float(w[0]) + 6.0, float(w[1]) + 4.0, float(w[2]) - 12.0, float(w[3]) - 8.0)


## Load the lab of this room's level (`dev`, set by `StationScreen._dress_room`).
func load_level() -> void:
	var lv := ShopScene.level_name(dev)
	if lv == _level:
		return
	_level = lv
	lab = ((doc().get("labs", {}) as Dictionary).get(lv, {}) as Dictionary)
	if lab.is_empty():
		push_warning("lab: no %s lab installed -- run tools/lab_install.py" % lv)
		_pic.texture = null
		return
	var li := _read(String(lab.get("light", "")))
	var oi := _read(String(lab.get("own", "")))
	if li == null or oi == null:
		lab = {}
		_pic.texture = null
		return
	_pic.texture = load(LAB_DIR + String(lab.get("picture", ""))) as Texture2D
	_pools = li.get_data()
	_own = oi.get_data()
	_mat.set_shader_parameter(&"light_map", ImageTexture.create_from_image(li))
	_mat.set_shader_parameter(&"own_map", ImageTexture.create_from_image(oi))
	var lights: Array = lab.get("lights", [])
	var cols := PackedVector4Array()
	cols.resize(8)
	for i in mini(lights.size(), 8):
		var l: Dictionary = lights[i]
		var c: Array = l.get("c", [1.0, 1.0, 1.0])
		cols[i] = Vector4(float(c[0]), float(c[1]), float(c[2]), float(l.get("p", 1.0)))
	_mat.set_shader_parameter(&"lcol", cols)
	_mat.set_shader_parameter(&"nlights", mini(lights.size(), 8))
	_mat.set_shader_parameter(&"scale", float(lab.get("scale", 2.0)))
	var ac: Array = lab.get("ambc", [1.0, 1.0, 1.0])
	_mat.set_shader_parameter(&"ambc", Vector3(float(ac[0]), float(ac[1]), float(ac[2])))
	_mat.set_shader_parameter(&"fullbright", ShopScene.fullbright)
	_glass.setup()
	_tick_n = -1


## A data picture off disk, not imported: its colours are numbers.
static func _read(name: String) -> Image:
	var path := LAB_DIR + name
	if name == "" or not FileAccess.file_exists(path):
		push_warning("lab: %s is missing" % path)
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		push_warning("lab: could not read %s" % path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## Power the lab on from black: the first time the deck is shown at a station.
func power_on() -> void:
	if _powered:
		return
	_powered = true
	_boot_at = floorf(_lab_clock * HZ) / HZ
	_tick_n = -1


func _process(delta: float) -> void:
	if lab.is_empty() or not is_visible_in_tree():
		return
	_lab_clock += delta
	var fr := int(floorf(_lab_clock * HZ))
	if fr == _tick_n:
		return
	_tick_n = fr
	var t := float(fr) / HZ
	if pin_clock >= 0.0:
		t = pin_clock
		_boot_at = 0.0
	_tick(t)


func _tick(t: float) -> void:
	var tb := t - _boot_at
	var boot: Dictionary = lab.get("boot", {})
	var rm: Array = boot.get("room", [1.0, 2.0])
	_room = _smooth(float(rm[0]), float(rm[1]), tb)
	# A WEIGHT IS [steady, breathing] -- see `lab_light.gdshader`.
	var ws := _weights(t, tb)
	var steady := {}
	var breath := {}
	_w.clear()
	for k in ws:
		var v: Variant = ws[k]
		var b := 1.0
		var m := 1.0
		if v is Array:
			b = float(v[0])
			m = float(v[1])
		else:
			b = float(v)
		steady[k] = b
		breath[k] = m
		_w[k] = b * m
	var lights: Array = lab.get("lights", [])
	var lw := PackedVector2Array()
	lw.resize(8)
	for i in mini(lights.size(), 8):
		var id := String((lights[i] as Dictionary).get("id", ""))
		_lwb[i] = float(steady.get(id, 1.0))
		_lwm[i] = float(breath.get(id, 1.0))
		lw[i] = Vector2(_lwb[i], _lwm[i])
	var owners: Array = lab.get("owners", [])
	var ow := PackedFloat32Array()
	ow.resize(8)
	for i in mini(owners.size(), 8):
		ow[i] = float(_w.get(String(owners[i]), _room))
	_amb = float(lab.get("amb", 0.2)) * _room
	_mat.set_shader_parameter(&"lw", lw)
	_mat.set_shader_parameter(&"own_w", ow)
	_mat.set_shader_parameter(&"amb", _amb)
	_now = t
	_tb = tb
	_reveal(tb)
	_life.queue_redraw()
	_glass.frame(t, tb)


## THE SCAN BRINGS THE RECIPES ON. Nothing on the screen until the scan
## starts, then everything above it; the whole screen once it has passed.
func _reveal(tb: float) -> void:
	if rows_clip == null:
		return
	var boot: Dictionary = lab.get("boot", {})
	var rv: Array = boot.get("reveal", [2.3, 2.9])
	var r0 := float(rv[0])
	var r1 := float(rv[1])
	var wr := win_rect()
	var shown := wr.size.y
	if tb < r0:
		shown = 0.0
	elif tb < r1:
		var win: Array = lab.get("win", [0, 0, 0, 0])
		var y := float(win[1]) + (tb - r0) / (r1 - r0) * float(win[3])
		shown = clampf(y - wr.position.y, 0.0, wr.size.y)
	rows_clip.visible = shown > 0.0
	rows_clip.size = Vector2(wr.size.x, shown)


# ---------------------------------------------------------------- each clock
#
# Five Labs, Lit's `weights`, one per lab, line for line: how hard each light
# burns at `t`, `tb` seconds after power-on. A number is steady; a pair is
# [steady, breathing].

func _weights(t: float, tb: float) -> Dictionary:
	match _level:
		"unclaimed":
			# A DEN UNDER ONE BAD BULB: it strikes, then flutters, and every few
			# seconds it is gone for a frame.
			var on := 0.0 if tb < 0.25 else (_strikes(tb, 0.25, 0.95, 7.7) if tb < 1.2 else 1.0)
			return {"bulb": [on, (_loose(t, 1.3) if tb > 3.0 else 1.0) * _flutter(t, 0.4)],
				"screen": _smooth(1.9, 2.4, tb)}
		"outpost":
			# WORK LAMPS THAT CLUNK ON, and an amber status light blinking.
			var st := 0.0 if tb < 1.0 else ((1.0 if int(floorf((tb - 1.0) / 0.12)) % 2 == 1 else 0.1) if tb < 1.7 else 1.0)
			var sm := 1.0 if tb < 1.7 else 0.75 + 0.25 * sin(t * 6.283 / 2.6)
			return {"lampL": [_clunk(tb, 0.35), _flutter(t, 1.1)],
				"lampR": [_clunk(tb, 0.8), _starter(t, 2.2) if tb > 5.0 else 1.0],
				"status": [st, sm], "screen": _smooth(2.0, 2.5, tb)}
		"settlement":
			# THREE LAMPS WARMING UP, swaying as they come on.
			return {"l1": [_warm(tb, 0.3), _sway(t, tb, 0.3, 3.1)],
				"l2": [_warm(tb, 0.75), _sway(t, tb, 0.75, 5.3)],
				"l3": [_warm(tb, 1.2), _sway(t, tb, 1.2, 8.7) * (_loose(t, 4.4) if tb > 5.0 else 1.0)]}
		"city":
			# THE HOOD STRIKES, the tubes stutter on in turn, the monitors pop.
			var hood := _strikes(tb, 0.3, 0.55, 1.3)
			var br := 0.9 + 0.1 * sin(t * 6.283 / 4.5)
			return {"strip": [hood, br], "floor": [hood, br], "hood": [hood, br],
				"tubeL": _strikes(tb, 0.85, 0.45, 2.7),
				"tubeR": [_strikes(tb, 1.2, 0.6, 4.1), _starter(t, 2.0) if tb > 5.0 else 1.0],
				"monL": [_pop_on(tb, 1.75), 0.8 + 0.2 * sin(t * 5.0)],
				"monR": [_pop_on(tb, 1.9), 0.95 + 0.05 * sin(t * 3.3)],
				"meter": _pop_on(tb, 1.8),
				"dev": _pop_on(tb, 2.0) * (1.0 if fmod(t, 1.4) < 1.0 else 0.2)}
		"capital":
			# THE GOLD BAR STRIKES, the tanks come up teal, the glass comes on.
			var tank := [_smooth(0.8, 1.6, tb), 0.9 + 0.1 * sin(t * 6.283 / 3.7)]
			var bar := [_strikes(tb, 0.3, 0.6, 3.3), 0.96 + 0.04 * sin(t * 6.283 / 5.0)]
			return {"bar": bar, "halo": bar, "glass": [1.15 * _smooth(2.0, 2.5, tb), 1.0],
				"tankL": tank, "tankR": tank, "screen": _smooth(2.0, 2.5, tb),
				"monK": [_pop_on(tb, 1.9), 0.95 + 0.05 * sin(t * 2.3)]}
	return {}


static func _clunk(tb: float, at: float) -> float:
	if tb < at:
		return 0.0
	var e := tb - at
	return 1.0 if e < 0.08 else (0.3 if e < 0.14 else minf(1.0, 0.6 + (e - 0.14) * 3.0))


static func _warm(tb: float, at: float) -> float:
	return _smooth(at, at + 0.45, tb)


static func _sway(t: float, tb: float, at: float, s: float) -> float:
	return (1.0 + 0.12 * sin((tb - at) * 9.0) * exp(-maxf(0.0, tb - at) * 2.0)) * _flutter(t, s)


# ---------------------------------------------------------------- the clocks' parts
#
# The prototype's, which are the shop's lamp faults (`ShopLight.flicker_at`) on
# the same 30 Hz clock.

## A repeatable scatter in 0..1.
static func _hash(v: float) -> float:
	var x := sin(v * 127.1) * 43758.5453
	return x - floorf(x)


static func _smooth(a: float, b: float, t: float) -> float:
	var u := clampf((t - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _pop_on(tb: float, at: float) -> float:
	return 0.0 if tb < at else minf(1.0, (tb - at) / 0.1)


## A tube striking: hard on-off for `dur` seconds, then lit.
static func _strikes(tb: float, from: float, dur: float, seed: float) -> float:
	if tb < from:
		return 0.0
	if tb >= from + dur:
		return 1.0
	var h := _hash(floorf((tb - from) / 0.033) * 1.37 + seed * 3.1)
	return 1.0 if h < 0.42 else (0.55 if h < 0.52 else 0.04)


## A STARTER: every six and a half seconds, a burst of strikes.
static func _starter(t: float, seed: float) -> float:
	var per := 6.5
	var u := (t + seed) / per
	var e := (u - floorf(u)) * per
	if e < 0.62:
		var h := _hash(floorf(e / 0.033) * 1.37 + floorf(u) * 3.1 + seed)
		return 1.0 if h < 0.42 else (0.55 if h < 0.52 else 0.05)
	return 1.0


## When a LOOSE lamp's fault falls in window `k`.
static func _blink_at(k: float, seed: float) -> float:
	return (k + 0.05 + 0.9 * _hash(k * 3.77 + seed)) * 3.2 - seed


## LOOSE: dead steady, then gone for a frame, once in every 3.2 seconds.
static func _loose(t: float, seed: float) -> float:
	var k := floorf((t + seed) / 3.2)
	var at := _blink_at(k, seed)
	var fr := floorf((t - at) / 0.033 + 0.5)
	if t >= at and fr == 0.0:
		return 0.02
	if t >= at and fr <= 2.0 and _hash(seed * 5.1 + k) > 0.45:
		return 0.9 if fr == 1.0 else 0.03
	return 1.0


static func _flutter(t: float, seed: float) -> float:
	var a := sin(t * 7.3 + seed) * 0.5 + sin(t * 13.1 + seed * 2.0) * 0.3 + sin(t * 2.1 + seed * 3.0) * 0.2
	return 0.9 + 0.1 * a


## A point walked clockwise round a box's inside edge, from its top-left.
static func _edge_at(p: int, gw: int, gh: int) -> Vector2i:
	if p < gw:
		return Vector2i(p, 0)
	p -= gw
	if p < gh - 1:
		return Vector2i(gw - 1, p + 1)
	p -= gh - 1
	if p < gw - 1:
		return Vector2i(gw - 2 - p, gh - 1)
	p -= gw - 1
	return Vector2i(0, gh - 2 - p)


# ---------------------------------------------------------------- the life

## Whether the room pixel may take a mark of this kind (`MASK_*`).
func _may(x: int, y: int, bit: int) -> bool:
	if x < 0 or y < 0 or x >= int(PANEL.x) or y >= int(PANEL.y):
		return false
	return (_own[(y * int(PANEL.x) + x) * 4 + 1] & bit) != 0


## One picture pixel -- 2x2 room pixels -- wherever the room lets it land.
func _put(ci: CanvasItem, ax: int, ay: int, col: Color, bit: int) -> void:
	var rx := 2 * ax - 30
	var ry := 2 * ay - 16
	var all := true
	for yy in 2:
		for xx in 2:
			if not _may(rx + xx, ry + yy, bit):
				all = false
	if all:
		ci.draw_rect(Rect2(rx, ry, 2, 2), col)
		return
	for yy in 2:
		for xx in 2:
			if _may(rx + xx, ry + yy, bit):
				ci.draw_rect(Rect2(rx + xx, ry + yy, 1, 1), col)


## The light at one cell, as the shader works it out: for the fizz, which is
## lit by the room rather than glowing.
func _light_at(gx: int, gy: int) -> Vector3:
	var lights: Array = lab.get("lights", [])
	var sc := float(lab.get("scale", 2.0))
	var l3 := Vector3.ZERO
	var s0 := 0.0
	var s1 := 0.0
	for i in mini(lights.size(), 8):
		var l: Dictionary = lights[i]
		var k := _lwb[i] * float(l.get("p", 1.0))
		if k <= 0.001:
			continue
		var o := (((gy + (i / 2) * 216) * 370 + gx) * 4) + (i % 2) * 2
		if o < 0 or o + 1 >= _pools.size():
			continue
		var v := (float(_pools[o]) * 256.0 + float(_pools[o + 1])) / 65535.0 * sc
		if v > 0.0:
			v *= k
			var c: Array = l.get("c", [1.0, 1.0, 1.0])
			l3 += v * Vector3(float(c[0]), float(c[1]), float(c[2]))
			s0 += v
			s1 += v * _lwm[i]
	var ac: Array = lab.get("ambc", [1.0, 1.0, 1.0])
	var amb := _amb * Vector3(float(ac[0]), float(ac[1]), float(ac[2]))
	var l := maxf(l3.x, maxf(l3.y, l3.z))
	if l <= 0.0:
		return amb
	var stp := 1.0 / 6.0
	var tq := l if l < 1.5 * stp else minf(floorf(l / stp + 0.5) * stp, 1.0)
	tq = minf(1.0, tq * s1 / s0)
	var tr := l3 / l
	return amb * (1.0 - tq) + (Vector3.ONE - 0.45 * (Vector3.ONE - tr)) * tq


func _draw_life(ci: CanvasItem) -> void:
	var t := _now
	# THE SMALL MONITOR: an animation on its own screen, powered with it.
	var an: Dictionary = lab.get("anim", {})
	if not an.is_empty():
		var ew := float(_w.get(String(an.get("owner", "")), _room))
		if ew > 0.05:
			var scr: Array = an.get("scr", [0, 0, 0, 0])
			var pal: Array = DARKPAL if bool(an.get("dark", false)) else LIGHTPAL
			for cell in _anim(String(an.get("mode", "")), t, int(scr[2]), int(scr[3]), pal):
				var ax: int = cell[0]
				var ay: int = cell[1]
				if ax < 0 or ay < 0 or ax >= int(scr[2]) or ay >= int(scr[3]):
					continue
				var c: Color = cell[2]
				_put(ci, int(scr[0]) + ax, int(scr[1]) + ay, Color(c.r * ew, c.g * ew, c.b * ew), MASK_MONITOR)
	# BUBBLES IN THE TANKS: each rises at its own steady speed, a picture pixel
	# at a time, drawn only over the liquid so the plants stay in front.
	var bb: Dictionary = lab.get("bubbles", {})
	var tanks: Array = bb.get("tanks", [])
	var bown: Array = bb.get("owners", [])
	for ti in tanks.size():
		var eb := float(_w.get(String(bown[ti]) if ti < bown.size() else "", _room))
		if not (eb > 0.05):
			continue
		var tk: Array = tanks[ti]
		var span := float(tk[3]) - float(tk[2])
		var bc := Color(215.0 / 255.0 * eb, 1.0 * eb, 245.0 / 255.0 * eb)
		for bi in 6:
			var sd := float(ti) * 17.3 + float(bi) * 5.1
			var sp := 5.0 + 6.0 * _hash(sd)
			var off := _hash(sd + 2.2) * span
			var by := int(tk[3]) - int(floorf(fmod(t * sp + off, span)))
			var bx := int(tk[0]) + 1 + int(floorf(_hash(sd + 4.4) * (float(tk[1]) - float(tk[0]) - 1.0)))
			if sin(t * 1.3 + sd) > 0.7:
				bx += 1
			# About half are big, two picture pixels square; the rest single.
			if _hash(sd + 7.7) > 0.5:
				for c2: Vector2i in [Vector2i(bx, by), Vector2i(bx + 1, by), Vector2i(bx, by - 1), Vector2i(bx + 1, by - 1)]:
					_put(ci, c2.x, c2.y, bc, MASK_TANK)
			else:
				_put(ci, bx, by, bc, MASK_TANK)
	# THE FLASKS FIZZ: single picture pixels rising through the liquid, each in
	# a new column every time round, lit by the room rather than glowing.
	var fz: Array = lab.get("fizz", [])
	for fi in fz.size():
		var f: Dictionary = fz[fi]
		var fb: Array = f.get("box", [0, 0, 0, 0])
		var fspan := float(fb[3]) - float(fb[2]) + 1.0
		for bj in int(f.get("n", 1)):
			var sdf := float(fi) * 11.7 + float(bj) * 3.9
			var spf := 2.0 + 2.5 * _hash(sdf)
			var run := t * spf + _hash(sdf + 1.3) * fspan
			var lap := floorf(run / fspan)
			var fy := int(fb[3]) - int(floorf(fmod(run, fspan)))
			var fx := int(fb[0]) + int(floorf(_hash(sdf + 2.9 + lap * 0.37) * (float(fb[1]) - float(fb[0]) + 1.0)))
			var m := _light_at(fx - 15, fy - 8)
			_put(ci, fx, fy, Color(minf(1.0, 150.0 / 255.0 * m.x), minf(1.0, 235.0 / 255.0 * m.y),
				minf(1.0, 205.0 / 255.0 * m.z)), MASK_FLASK)


## A small monitor's animation as [x, y, colour] marks in its own picture
## pixels, in drawing order (Five Labs `SCREEN_MODES`).
static func _anim(mode: String, t: float, sw: int, sh: int, pal: Array) -> Array:
	var out := []
	var ink: Color = pal[0]
	var mid: Color = pal[1]
	var pale: Color = pal[2]
	match mode:
		"helix":
			# A DNA HELIX TURNING: rungs first, then the far strand, then the near.
			var ph := floorf(t * 10.0) * (TAU / 40.0)
			var k := TAU / 13.0
			var cy := float(sh - 1) / 2.0
			var amp := float(sh - 3) / 2.0
			var s1: Array[int] = []
			var s2: Array[int] = []
			var near1: Array[bool] = []
			for x in sw:
				var v := sin(k * float(x) + ph)
				s1.append(int(floorf(cy - amp * v + 0.5)))
				s2.append(int(floorf(cy + amp * v + 0.5)))
				near1.append(cos(k * float(x) + ph) > 0.0)
			var x2 := 1
			while x2 < sw:
				for y in range(mini(s1[x2], s2[x2]) + 1, maxi(s1[x2], s2[x2])):
					out.append([x2, y, pale])
				x2 += 3
			for pass_i in 2:
				for x3 in sw:
					var one: bool = near1[x3] == (pass_i == 1)
					var ss: Array[int] = s1 if one else s2
					var y0: int = ss[x3]
					var y1: int = ss[x3 + 1] if x3 + 1 < sw else y0
					for y in range(mini(y0, y1), maxi(y0, y1) + 1):
						if y == y0 or y != y1:
							out.append([x3, y, ink if pass_i == 1 else mid])
		"readout":
			# A READOUT TYPING one line at a time, the lines above scrolling up,
			# a cursor blinking.
			var cps := 14.0
			var rows := sh / 2
			var per := float(sw + 8) / cps
			var li := floorf(t / per)
			var typed := int(floorf((t - li * per) * cps))
			for r in rows:
				var line := li - float(rows - 1 - r)
				var y := 1 + r * 2
				var ln := sw - 1 - int(floorf(_hash(line * 3.3 + 0.7) * 7.0))
				var last := r == rows - 1
				var n := mini(ln, typed) if last else ln
				var x := 0
				while x < n:
					var run := 1 + int(floorf(_hash(line * 7.13 + float(x) * 1.7) * 4.0))
					var i := 0
					while i < run and x < n:
						out.append([x, y, ink if last else mid])
						i += 1
						x += 1
					x += 1
				if last and int(floorf(t * 2.5)) % 2 == 0:
					out.append([mini(n + 1, sw - 1), y, ink])
	return out


class _Life extends Control:
	var lab: LabScene

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if lab != null and not lab.lab.is_empty():
			lab._draw_life(self)


# ---------------------------------------------------------------- the big screen

## WHAT THE BIG SCREEN DOES, over the rows (Five Labs `SCREEN_FX`): worked out
## here each tick and drawn by `lab_glass.gdshader` over a copy of the glass.
## Hidden whenever the screen is doing nothing, which is most of the time, so
## the copy is only taken when something uses it.
class _Glass extends Control:
	var lab: LabScene
	var _copy: BackBufferCopy
	var _rect: ColorRect
	var _mat: ShaderMaterial
	var _g := Rect2()
	var _tint := Vector3.ONE
	# This tick's marks, as the shader takes them.
	var _bands := PackedVector4Array()
	var _snow := PackedVector2Array()
	var _rim := PackedVector3Array()
	var _jolt := 0.0
	var _sag := 1.0
	var _flash := Vector3.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		# THE WHOLE VIEWPORT, NOT THE GLASS'S RECT. Under the compatibility
		# renderer a rect copy is taken from the screen's top-left whatever the
		# node's position, so the glass read black everywhere the two did not
		# overlap. A 960x540 copy, and only on the frames the screen is doing
		# something.
		_copy = BackBufferCopy.new()
		_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(_copy)
		_rect = ColorRect.new()
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mat = ShaderMaterial.new()
		_mat.shader = LabScene.GLASS_SHADER
		_rect.material = _mat
		add_child(_rect)

	func setup() -> void:
		var s: Dictionary = lab.lab.get("screen", {})
		var g: Array = s.get("glass", [0, 0, 0, 0])
		_g = Rect2(float(g[0]), float(g[1]), float(g[2]) - float(g[0]) + 1.0, float(g[3]) - float(g[1]) + 1.0)
		_rect.position = _g.position
		_rect.size = _g.size
		var tn: Array = s.get("tint", [255, 255, 255])
		_tint = Vector3(float(tn[0]), float(tn[1]), float(tn[2])) / 255.0
		var gold: Array = s.get("gold", tn)
		_mat.set_shader_parameter(&"gsize", _g.size)
		_mat.set_shader_parameter(&"gx0", _g.position.x)
		_mat.set_shader_parameter(&"snow_col", _tint * 0.35)
		_mat.set_shader_parameter(&"rim_col", Vector3(float(gold[0]), float(gold[1]), float(gold[2])) / 255.0)

	func frame(t: float, tb: float) -> void:
		var s: Dictionary = lab.lab.get("screen", {})
		var boot: Dictionary = lab.lab.get("boot", {})
		var rv: Array = boot.get("reveal", [2.3, 2.9])
		var r0 := float(rv[0])
		var r1 := float(rv[1])
		var win: Array = lab.lab.get("win", [0, 0, 0, 0])
		var fx := String(s.get("fx", "sweep"))
		_bands.clear()
		_snow.clear()
		_rim.clear()
		_jolt = 0.0
		_sag = 1.0
		_flash = Vector3.ZERO
		var active := false
		# THE SCAN: the power-on's reveal, then -- where the screen sweeps -- a thin
		# line down the rows for 1.4 s in every 7.
		var sy := -1.0
		var sk := 0.0
		if tb >= r0 and tb < r1:
			sy = float(win[1]) + (tb - r0) / (r1 - r0) * float(win[3])
			sk = 2.2
		elif fx == "sweep" and tb >= r1 + 1.0:
			var ph := fmod(t, 7.0) / 1.4
			if ph <= 1.0:
				sy = float(win[1]) + ph * float(win[3])
				sk = 1.0
		var scan := Vector4(-100.0, 0.0, 0.0, 0.0)
		if sy >= 0.0:
			var x0 := float(int(win[0]) & ~1)
			scan = Vector4(floorf(sy / 2.0) * 2.0 - _g.position.y, x0 - _g.position.x,
				x0 + float(int(win[2]) & ~1) - _g.position.x, sk)
			active = true
		if fx != "sweep" and tb >= r1 + 0.5:
			match fx:
				"signal":
					active = _signal(t, s) or active
				"failing":
					# THE DEN'S SCREEN FAILS WITH ITS BULB first, then loses its signal.
					active = (_sag_with_bulb(t, s) or _signal(t, s)) or active
				"rim":
					active = _rim_light(t, s) or active
		visible = active
		if not active:
			return
		_mat.set_shader_parameter(&"scan", scan)
		_mat.set_shader_parameter(&"bands", _pad4(_bands, 4))
		_mat.set_shader_parameter(&"nbands", mini(_bands.size(), 4))
		_mat.set_shader_parameter(&"jolt", _jolt)
		_mat.set_shader_parameter(&"sag", _sag)
		_mat.set_shader_parameter(&"flash", _flash)
		var snow := _snow.duplicate()
		snow.resize(3)
		_mat.set_shader_parameter(&"snow", snow)
		_mat.set_shader_parameter(&"nsnow", mini(_snow.size(), 3))
		var rim := _rim.duplicate()
		rim.resize(16)
		_mat.set_shader_parameter(&"rim", rim)
		_mat.set_shader_parameter(&"nrim", mini(_rim.size(), 16))

	static func _pad4(a: PackedVector4Array, n: int) -> PackedVector4Array:
		var out := a.duplicate()
		out.resize(n)
		return out

	## BAD SIGNAL: once in every `every` seconds, for `dur`, bands of the glass
	## slip sideways and lines of snow flash (Five Labs `signal`).
	func _signal(t: float, s: Dictionary) -> bool:
		var n := int(_g.size.y) >> 1
		var slot := float(s.get("every", 5.2))
		var k := floorf(t / slot)
		var dur := float(s.get("dur", 0.24))
		var start := k * slot + slot * (0.12 + 0.5 * LabScene._hash(k * 1.7 + 0.3))
		if t < start or t >= start + dur:
			return false
		var f := int(floorf((t - start) * 30.0))
		var sh_steps := [2, 4, -2, 2, 0, -4, 2, -2]
		var big := float(s.get("shift", 4)) / 4.0
		if bool(s.get("jolt", false)) and f % 3 == 1:
			_jolt = 2.0
		for b in mini(int(s.get("bands", 2)), 4):
			var bh := 2 * (2 + int(floorf(LabScene._hash(k * 5.5 + float(b) * 1.9) * float(s.get("tall", 4)))))
			var by := 2 * int(floorf(LabScene._hash(k * 3.1 + float(b) * 7.3) * (float(n) - float(bh) / 2.0)))
			# Math.round: halves go up, negative ones too.
			var sh := floorf(float(sh_steps[(f + b * 3) % sh_steps.size()]) * big / 2.0 + 0.5) * 2.0
			var src := by
			if bool(s.get("tear", false)) and b == 0:
				src = 2 * int(floorf(LabScene._hash(k * 2.3 + floorf(float(f) / 2.0) * 0.1) * (float(n) - float(bh) / 2.0)))
			if sh != 0.0 or src != by:
				_bands.append(Vector4(float(by), float(bh), sh, float(src)))
		if f % 2 == 0:
			for s2 in mini(int(s.get("snow", 1)), 3):
				var ly := 2 * int(floorf(LabScene._hash(k * 9.1 + float(f) * 0.77 + float(s2) * 4.1) * float(n)))
				_snow.append(Vector2(float(ly), float(f) * 1.7 + k * 3.3 + float(s2) * 0.9))
		return true

	## THE SAG: when the bulb fails (its own fault clock) the screen goes dark
	## with it, then comes back with a flash and a jolt. `sagEvery` makes it only
	## the bulb's first blink in each that many seconds -- Jon: "it just flashes
	## too much" when it was every blink (2026-09-28).
	func _sag_with_bulb(t: float, s: Dictionary) -> bool:
		var seed := float(s.get("bulbSeed", 1.3))
		var v := LabScene._loose(t, seed)
		var v1 := LabScene._loose(t - 1.0 / 30.0, seed)
		var v2 := LabScene._loose(t - 2.0 / 30.0, seed)
		if v >= 0.5 and v1 >= 0.5 and v2 >= 0.5:
			return false
		if s.has("sagEvery"):
			var every := float(s.get("sagEvery", 10.0))
			var k := floorf((t + seed) / 3.2)
			if floorf(LabScene._blink_at(k, seed) / every) == floorf(LabScene._blink_at(k - 1.0, seed) / every):
				return false
		if v < 0.5:
			_sag = 1.0 - float(s.get("sag", 0.8))
			return true
		_jolt = float(s.get("joltPx", 4))
		_flash = _tint * ((0.16 if v1 < 0.5 else 0.07) * float(s.get("flash", 1.0)))
		return true

	## THE RIM LIGHT: once in every `every` seconds a short gold streak runs once
	## round the glass's inside edge, behind whatever stands in front of it.
	func _rim_light(t: float, s: Dictionary) -> bool:
		var gw := int(_g.size.x) >> 1
		var gh := int(_g.size.y) >> 1
		var per := 2 * (gw + gh) - 4
		var run := float(s.get("run", 3.2))
		var ph := fmod(t, float(s.get("every", 7.0)))
		if ph > run:
			return false
		var head := int(floorf(ph / run * float(per)))
		var tail := int(s.get("tail", 14))
		var masked := s.has("glassCols")
		for i in tail:
			var p := head - i
			if p < 0:
				break
			var q := LabScene._edge_at(p, gw, gh)
			var x := int(_g.position.x) + q.x * 2
			var y := int(_g.position.y) + q.y * 2
			if masked and not lab._may(x, y, LabScene.MASK_GLASS):
				continue
			if _rim.size() < 16:
				_rim.append(Vector3(float(x) - _g.position.x, float(y) - _g.position.y, 0.6 * (1.0 - float(i) / float(tail))))
		return true
