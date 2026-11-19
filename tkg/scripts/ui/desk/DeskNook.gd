class_name DeskNook
extends DeskLife

## The NOOK, the salvage frames' science nook: a rack bulb under its cone shade, sixteen string bulbs,
## a dozen LEDs, an oscilloscope, the rack's level meter, the old CRT. A port of the approved page's
## `scenes/nook_1.js`: its clocks, levels and CPU layers (pixels: `nook_1.gdshader`).
## Why: docs/why/DeskScene.md#porting-a-room

const GW := 150
const GH := 140
const GLASS := Rect2i(117, 22, 150, 140)
const SC := Rect2i(16, 96, 17, 14)
const SB := Rect2i(100, 139, 36, 48)
const MUG := Vector2i(118, 185)
const MUG_SEED := 3
const T := {fade = 2.5, main = 3.2, str = 3.45, bulb = 4.3, crt = 4.9, rack = 5.95, scope = 6.15, arm = 6.9, bot = 7.55}
const CW := {d0 = 0.075, d1 = 0.255, l1 = 0.495, o1 = 1.35, b1 = 3.45}
const HOLD := 2.5
const WIPE := 0.4
const AFTER := 0.3
const SCP := 1.45
const SCVIS := 1.2
const WAVE := [0, 0, 0, -1, 0, 0, 1, -5, 4, 1, 0, 0, -1, -2, -1, 0, 0]
const GDUR := {&"jit": 0.24, &"rgb": 0.05, &"static": 0.5, &"vhold": 0.27}
## CRT drawings (the shader's g_ph).
enum Ph { FILL, DOT, LINE, OPEN, BOOT, TITLE, PIC }

var strings: Array = []
var leds: Array = []
var sky_k: Dictionary
var leaving := false
var r_clock := 0.0
## When the card wipes into the picture, seconds after T.crt (the page's t1; held by the game).
var roll := 3.45 + HOLD
var _lv_hold := 1.0
var _lv_k := 1.0
var _tints := PackedVector4Array()
var _gl: Array[Dictionary] = []
## The screen's colour, sampled off the glass every third frame and eased (the page's SCH, schN).
var _sch := Vector3(0.55, 0.95, 0.9)
var _sch_n := 0
var _pic := PackedFloat32Array()
var _card := PackedFloat32Array()
var _blink := PackedByteArray()
var _boot := PackedInt32Array()


func _init(m: Dictionary) -> void:
	meta = m
	lamp_at = T.bulb
	crt_at = T.crt
	done_at = 12.3
	title_u = float(T.crt) + float(CW.b1) - 2.5
	title_wipe = WIPE
	small_q = 8
	scan = Vector3(148.0 / 255.0, 1.0, 0.0)
	steam_box = SB
	strings = m.strings
	leds = m.leds
	var on := {}
	var idx: Array[int] = []
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i.ZERO
	for i: float in m.sky.o.idx:
		on[int(i)] = true
		idx.append(int(i))
		lo = lo.min(Vector2i(int(i) % DeskFx.W, int(i) / DeskFx.W))
		hi = hi.max(Vector2i(int(i) % DeskFx.W, int(i) / DeskFx.W))
	port_box = Rect2i(lo, hi - lo + Vector2i.ONE)
	var o: Dictionary = (m.sky.o as Dictionary).duplicate()
	o.idx = idx
	sky_k = {o = o, set = on, S = m.sky.S, stars = m.sky.stars}
	_make_images(Vector2i(1, 1))
	for t: Array in m.tints:
		_tints.append(Vector4(float(t[0]), float(t[1]), float(t[2]), 0.0))
	_tints.resize(32)
	var gl := DeskRoom.plane(String(m.id), "glass", DeskRoom.GLASS, Image.FORMAT_RGBAF).get_image()
	_boot.resize(GW * GH)
	for y in GH:
		for x in GW:
			_boot[y * GW + x] = int(gl.get_pixel(x, y).g)
	_build_glitches()


## Math.imul: the low 32 bits of a product, signed.
static func imul(a: int, b: int) -> int:
	a = posmod(a, 4294967296)
	b = posmod(b, 4294967296)
	var lo := (a * (b & 0xffff)) & 0xffffffff
	var hi16 := ((a * (b >> 16)) & 0xffff) << 16
	var v := (lo + hi16) & 0xffffffff
	return v - 4294967296 if v >= 2147483648 else v


## The NOOK's hash (murmur's finaliser on 32-bit ints, as the page's `hh`).
static func hh(n: float) -> float:
	var x := posmod(int(n), 4294967296) ^ 0x9e3779b9
	x = posmod(imul(x ^ (x >> 16), 0x85ebca6b), 4294967296)
	x = posmod(imul(x ^ (x >> 13), 0xc2b2ae35), 4294967296)
	x ^= x >> 16
	return float(x) / 4294967296.0


## The page's soft knee: values past 200 bend toward 255.
static func soft(v: float) -> float:
	return v if v < 200.0 else 200.0 + 55.0 * (v - 200.0) / (v - 200.0 + 55.0)


static func ez(t: float) -> float:
	return 0.0 if t <= 0.0 else (1.0 if t >= 1.0 else t * t * (3.0 - 2.0 * t))


static func e_out(t: float) -> float:
	return 0.0 if t <= 0.0 else (1.0 if t >= 1.0 else 1.0 - pow(1.0 - t, 3.0))


static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func vnoise(t: float, seed: float) -> float:
	var i := floorf(t)
	var f := t - i
	var k := f * f * (3.0 - 2.0 * f)
	return (hh(i * 13.0 + seed) * (1.0 - k) + hh((i + 1.0) * 13.0 + seed) * k) * 2.0 - 1.0


func hold_title() -> void:
	roll = INF


func release(u: float) -> void:
	roll = maxf(u + 2.5 - float(T.crt), float(CW.b1))


func set_screen(img: Image) -> void:
	_pic.resize(GW * GH * 3)
	for y in GH:
		for x in GW:
			var c := img.get_pixel(x, y)
			var k := (y * GW + x) * 3
			_pic[k] = DeskFx.jround(c.r * 255.0)
			_pic[k + 1] = DeskFx.jround(c.g * 255.0)
			_pic[k + 2] = DeskFx.jround(c.b * 255.0)


func set_card(img: Image) -> void:
	_card.resize(GW * GH * 3)
	_blink.resize(GW * GH)
	for y in GH:
		for x in GW:
			var c := img.get_pixel(x, y)
			var k := (y * GW + x) * 3
			_card[k] = c.r
			_card[k + 1] = c.g
			_card[k + 2] = c.b
			_blink[y * GW + x] = 1 if c.a > 0.5 else 0


## The page's glitch list: one every 3 to 8 s, never the same kind twice running.
func _build_glitches() -> void:
	var tt := 6.0
	var prev := &""
	var kinds := [&"jit", &"rgb", &"jit", &"rgb", &"jit", &"vhold"]
	var n := 0
	while tt < 4000.0:
		var k: StringName = kinds[int(floorf(hh(n * 7 + 301) * kinds.size()))]
		if k == prev:
			k = kinds[(kinds.find(k) + 1 + int(floorf(hh(n + 9) * 3.0))) % 3]
		prev = k
		_gl.append({at = tt, type = k, n = n})
		tt += 3.0 + hh(n * 11 + 303) * 5.0
		n += 1


## The glitch at r: (index, seconds into it), or index -1.
func _glitch(r: float) -> Vector2:
	if r < float(_gl[0].at):
		return Vector2(-1, 0)
	var first := float(_gl[0].at)
	var last := float(_gl[_gl.size() - 1].at)
	if r > last:
		r = first + fmod(r - first, last - first)
	var lo := 0
	var hi := _gl.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if float(_gl[mid].at) <= r:
			lo = mid
		else:
			hi = mid - 1
	var v := r - float(_gl[lo].at)
	return Vector2(lo, v) if v < float(GDUR[_gl[lo].type]) else Vector2(-1, 0)


func _gl_light(g: Vector2) -> float:
	if g.x < 0.0:
		return 1.0
	var e := _gl[int(g.x)]
	match e.type:
		&"jit":
			return 0.97 + 0.03 * hh(floorf(g.y * 15.0) + int(e.n))
		&"rgb":
			return 0.95
		&"vhold":
			return 0.88 if g.y < 0.09 else (1.05 if g.y < 0.17 else 1.0)
	return 1.0


static func flick(r: float) -> float:
	return 1.0 + 0.012 * sin(r * 7.3) + 0.009 * sin(r * 12.1 + 1.0) + 0.006 * sin(r * 19.3 + 2.0)


static func screen_gain(r: float) -> float:
	return 1.0 + 0.035 * sin(r * 6.283 / 6.7) + 0.02 * sin(r * 6.283 / 2.3 + 1.3)


func _idle_amp() -> float:
	return 0.72 * screen_gain(r_clock) * flick(r_clock) * (1.0 if leaving else _gl_light(_glitch(r_clock)))


func _crt_amp(t: float) -> float:
	var u := t - float(T.crt)
	if u < 0.05:
		return 0.0
	if leaving:
		if u >= 1.4:
			return _idle_amp()
		if u >= 0.7:
			var s := (u - 0.7) / 0.7
			return _idle_amp() * (0.25 + 0.75 * s) * (1.0 + 0.5 * (1.0 - s))
		return 0.12 if u >= 0.4 else 0.05 * (u - 0.05) / 0.35
	if u < CW.d1:
		return 0.04
	if u < CW.l1:
		return 0.12
	if u < 0.825:
		return 0.12 + 0.6 * ez((u - float(CW.l1)) / 0.33)
	if u < CW.o1:
		return 0.72 - 0.42 * ez((u - 0.825) / 0.525)
	if u < CW.b1:
		return 0.3
	if u < roll:
		return 0.42
	if u < roll + WIPE + 0.5:
		return 0.42 + (_idle_amp() - 0.42) * ez((u - roll) / (WIPE + 0.5))
	return _idle_amp()


func _str_b(s: Dictionary, k: int, t: float) -> float:
	var u := t - float(s.on)
	if u < 0.0:
		return 0.0
	var b := 0.0
	var fl := bool(s.flick)
	if fl and u < 0.16:
		b = 0.45 if u < 0.05 else (0.04 if u < 0.09 else (0.7 if u < 0.13 else 0.3))
	else:
		b = 0.2 + 0.8 * e_out((u - (0.16 if fl else 0.0)) / 0.35)
	var r := r_clock
	b *= 1.0 + 0.12 * sin(r * 6.283 / float(s.p) + float(s.ph)) + 0.05 * sin(r * 6.283 / float(s.p2) + float(s.ph) * 2.1)
	b *= 1.0 + _swell(k, r)
	if k == 9:
		var e := floorf((r - 6.0) / 13.0)
		var v := r - (6.0 + e * 13.0 + 3.0 + hh(e + 31.0) * 8.0)
		if e >= 0.0 and v >= 0.0 and v < 0.3:
			b *= 0.55 if v < 0.06 else (1.0 if v < 0.12 else (0.65 if v < 0.18 else 1.0))
	return b


func _swell(k: int, r: float) -> float:
	var e := floorf((r - 8.0) / 9.0)
	var g := 0.0
	for q: float in [e - 1.0, e]:
		if q < 0.0:
			continue
		var v := r - (8.0 + q * 9.0 + hh(q * 7.0 + 41.0) * 3.0)
		if v < 0.0 or v > 4.5:
			continue
		var n := strings.size()
		var pos := -4.0 + v * ((n + 8) / 4.5)
		var kk := k if hh(q * 3.0 + 17.0) < 0.5 else n - 1 - k
		var z := (kk - pos) / 3.2
		g += 0.45 * exp(-z * z)
	return g


static func _bulb_steady(u: float) -> float:
	if u < 0.0:
		return 0.0
	if u < 0.12:
		return 0.22
	if u < 0.18:
		return 0.05
	if u < 0.25:
		return 0.55
	if u < 0.3:
		return 0.18
	return 0.32 + 0.68 * ez((u - 0.3) / 0.75)


func _bulb_b(t: float) -> float:
	var u := t - float(T.bulb)
	if u < 0.0:
		return 0.0
	var r := r_clock
	var k := (1.0 + 0.045 * sin(r * 6.283 / 5.3) + 0.02 * sin(r * 6.283 / 1.37 + 1.0)) * (1.0 - _brown(r))
	k *= 1.0 + 0.022 * vnoise(r * 1.7, 61.0) + 0.012 * vnoise(r * 4.3, 67.0)
	var ci := floorf(r / 10.0)
	var a := r - ci * 10.0 - (1.5 + hh(ci * 39.0 + 1.0) * 6.0)
	var ln := 0.45 + hh(ci * 22.0) * 0.25
	if a > 0.0 and a < ln:
		k *= 1.0 - (0.06 + hh(ci * 71.0) * 0.03) * sin(PI * a / ln)
	return _bulb_steady(u) * k


static func _brown(r: float) -> float:
	var e := floorf((r - 9.0) / 10.5)
	if e < 0.0 or hh(e * 5.0 + 61.0) > 0.75:
		return 0.0
	var v := r - (9.0 + e * 10.5 + 1.0 + hh(e * 3.0 + 67.0) * 7.0)
	if v < 0.0 or v > 0.55:
		return 0.0
	var env := v / 0.06 if v < 0.06 else (1.0 if v < 0.3 else 1.0 - (v - 0.3) / 0.25)
	return (0.15 + 0.1 * hh(e + 71.0)) * env * (0.8 + 0.2 * sin(v * 40.0))


func _led_b(e: Dictionary, t: float) -> float:
	var u := t - float(e.on)
	if u < 0.0:
		return 0.0
	var b := 1.35 if u < 0.06 else (0.85 if u < 0.14 else 1.0)
	var r := r_clock
	match String(e.mode):
		"busy":
			if hh(floorf(r * 7.0) * 3.0 + 11.0) < 0.22:
				b *= 0.15
		"heart":
			b *= 1.0 if fmod(r, 1.6) < 0.8 else 0.25
		"breathe":
			b *= 0.55 + 0.45 * (0.5 + 0.5 * sin(r * 6.283 / 3.1))
		"lcd":
			b *= 0.96 + 0.04 * sin(r * 2.3)
		"eyes":
			var k := floorf(r / 5.2)
			var v := r - (k * 5.2 + 1.0 + hh(k + 71.0) * 3.0)
			if v >= 0.0 and v < 0.13:
				b *= 0.08
			if u < 0.4:
				b *= 1.0 if u < 0.1 else (0.1 if u < 0.18 else 1.0)
	return b


func _afterglow(a: float) -> float:
	if a <= 0.0:
		return 1.0
	if a >= AFTER:
		return 0.0
	var x := 1.0 - a / AFTER
	return DeskFx.jround(x * x * 8.0) / 8.0


## The CRT's drawing at scene time t, as the shader's uniforms (the page's drawCRT and picture).
func _crt(t: float) -> Dictionary[StringName, Variant]:
	var u := t - float(T.crt)
	var o: Dictionary[StringName, Variant] = {}
	o.assign({g_ph = Ph.FILL, g_fill = Vector3(5, 8, 13), g_k = 0.0, g_n = 0, g_open = Vector2.ZERO, g_boot = Vector4.ZERO,
		g_title = Vector3(0, 0, -99), g_pic = Vector4(1, -1, 70, 1), g_gl = Vector4(0, -1, -1, 0), g_gl2 = Vector2.ZERO})
	if leaving:
		if u < 0.05:
			return o
		o[&"g_fill"] = Vector3(7, 10, 14)
		if u < 0.4:
			o.merge({g_ph = Ph.DOT, g_k = ez((u - 0.05) / 0.35)}, true)
		elif u < 0.7:
			o.merge({g_ph = Ph.LINE, g_n = maxi(1, DeskFx.jround(75.0 * ez((u - 0.4) / 0.3)))}, true)
		else:
			_picture(u, (u - 0.7) / 0.7 if u < 1.4 else -1.0, o)
		return o
	if u < CW.d0:
		o[&"g_fill"] = Vector3(8, 11, 15) if u >= 0.0 else Vector3(5, 8, 13)
	elif u < CW.d1:
		o.merge({g_ph = Ph.DOT, g_fill = Vector3(7, 10, 14), g_k = ez((u - float(CW.d0)) / (float(CW.d1) - float(CW.d0)))}, true)
	elif u < CW.l1:
		o.merge({g_ph = Ph.LINE, g_fill = Vector3(7, 10, 14), g_n = maxi(1, DeskFx.jround(75.0 * e_out((u - float(CW.d1)) / (float(CW.l1) - float(CW.d1)))))}, true)
	elif u < CW.o1:
		var op := e_out((u - float(CW.l1)) / 0.33)
		o.merge({g_ph = Ph.OPEN, g_n = maxi(1, DeskFx.jround(70.0 * op)),
			g_open = Vector2(1.0 if u < 0.825 else 1.0 - ez((u - 0.825) / 0.525), floorf(t * 12.0))}, true)
	elif u < CW.b1:
		var ub := u - float(CW.o1)
		var n1 := mini(11, int(floorf((ub - 0.075) * 10.7)))
		var cur := Vector2(9 + maxi(0, n1) * 4, 9) if ub < 1.275 else Vector2(29, 17)
		var on := int(floorf(ub * 2.2)) % 2 == 0
		o.merge({g_ph = Ph.BOOT, g_boot = Vector4(n1, 1.0 if ub >= 1.275 else 0.0, cur.x + (1000.0 if on else 0.0), cur.y)}, true)
	elif u < roll:
		o.merge({g_ph = Ph.TITLE, g_title = Vector3(1, u - float(CW.b1), -99)}, true)
	else:
		_picture(u, -1.0, o)
		if u < roll + WIPE:
			o[&"g_title"] = Vector3(1, u - float(CW.b1), DeskFx.jround((u - roll) / WIPE * (GH + 4)) - 2.0)
	return o


func _picture(u: float, squash: float, o: Dictionary[StringName, Variant]) -> void:
	var gain := 1.0
	var s1 := roll + WIPE + 0.5
	if not leaving and u < s1:
		gain = 0.65 + 0.35 * e_out((u - roll) / (s1 - roll))
	var gl := _glitch(r_clock) if not leaving and u > s1 + 0.3 else Vector2(-1, 0)
	var g := Vector4(0, -1, -1, 0)
	var g2 := Vector2.ZERO
	if gl.x >= 0.0:
		var e := _gl[int(gl.x)]
		g2 = Vector2(floorf(gl.y * 15.0), float(e.n))
		match e.type:
			&"vhold":
				g.x = 2.0 if gl.y < 0.09 else (-1.0 if gl.y < 0.17 else 0.0)
			&"rgb":
				g.w = 1.0
			&"jit":
				g.y = 8 + int(floorf(hh(int(e.n) * 5 + 1) * 118.0))
				g.z = g.y + 3 + int(floorf(hh(int(e.n) * 5 + 2) * 6.0))
	var k0 := gain * flick(r_clock) * screen_gain(r_clock) * 1.03
	var hgt := maxf(0.5, 70.0 * e_out(squash)) if squash >= 0.0 else 70.0
	o.merge({g_ph = Ph.PIC, g_pic = Vector4(k0, squash, hgt, 1.0 + 0.8 * (1.0 - squash) if squash >= 0.0 else 1.0),
		g_gl = g, g_gl2 = g2}, true)


func _card_px(c: Vector3, x: int, y: int, tt: float, wy: int) -> Vector3:
	if y < wy:
		return c
	if y == wy or y == wy + 1:
		return Vector3(200, 245, 225)
	var sh := 1.0 + 0.06 * maxf(0.0, 1.0 - absf(fmod(tt * 22.0, GH + 30.0) - 15.0 - y) / 4.0)
	var k := (y * GW + x) * 3
	var v := Vector3(_card[k] * sh, _card[k + 1] * sh, _card[k + 2] * sh)
	var on := 1.0 if tt < 0.25 else (1.0 if int(floorf((tt - 0.25) * 1.6)) % 2 == 0 else 0.18)
	if on < 1.0 and _blink[y * GW + x] == 1 and y >= wy + 2:
		var b0 := Vector3(7, 13, 11)
		v = b0 + (v - b0) * on
	return v


## What the page's drawCRT leaves at glass pixel (x, y) (before the glow), for the screen's colour.
func _scr_at(x: int, y: int, o: Dictionary[StringName, Variant]) -> Vector3:
	var ph: int = o[&"g_ph"]
	var fill: Vector3 = o[&"g_fill"]
	match ph:
		Ph.FILL:
			return fill
		Ph.DOT:
			var k: float = o[&"g_k"]
			if y == 70 and (x == 75 or x == 74):
				return Vector3(230, 255, 250) * k
			if y == 69 and (x == 75 or x == 74):
				return Vector3(90, 120, 120) * k
			if (y == 70 and (x == 76 or x == 73)) or (y == 71 and (x == 75 or x == 74)):
				return Vector3(70, 95, 95) * k
			return fill
		Ph.LINE:
			var w: int = o[&"g_n"]
			if x >= 75 - w and x < 75 + w:
				if y == 70:
					return Vector3(215, 245, 245)
				if y == 69 or y == 71:
					return Vector3(60, 85, 90)
			return fill
		Ph.OPEN:
			var h: int = o[&"g_n"]
			var dy := absi(y - 70)
			if dy > h:
				return Vector3(7, 10, 14)
			var op: Vector2 = o[&"g_open"]
			var n := hh((x * 7 + y * 131) ^ int(op.y * 977.0))
			var v := 18.0 + (68.0 * op.x + 22.0 * n * op.x) * (1.3 if dy >= h - 1 else 1.0)
			return Vector3(v * 0.82 + 6.0, v * 0.95 + 10.0, v + 14.0)
		Ph.BOOT:
			var b: Vector4 = o[&"g_boot"]
			var c := Vector3(8, 14, 18)
			var i := _boot[y * GW + x]
			if i >= 0 and i < 100 and i < int(b.x):
				c = Vector3(150, 232, 180)
			elif i >= 100 and b.y > 0.5:
				c = Vector3(150, 232, 180) * 0.9
			var cx := fmod(b.z, 1000.0)
			if b.z >= 1000.0 and x >= cx and x < cx + 3.0 and y >= b.w and y < b.w + 5.0:
				c = Vector3(150, 232, 180) * 0.85
			return c
		Ph.TITLE:
			var tl: Vector3 = o[&"g_title"]
			return _card_px(Vector3.ZERO, x, y, tl.y, -99)
	return _pic_at(x, y, o)


func _pic_at(x: int, y: int, o: Dictionary[StringName, Variant]) -> Vector3:
	var p: Vector4 = o[&"g_pic"]
	var g: Vector4 = o[&"g_gl"]
	var g2: Vector2 = o[&"g_gl2"]
	var sy := 0
	if p.y >= 0.0:
		var d := y - 70 + 0.5
		if absf(d) > p.z:
			return Vector3(4, 6, 9)
		sy = DeskFx.jround(70.0 + d * 70.0 / p.z)
	else:
		sy = posmod(y - int(g.x), GH + 6)
	var sh := 0
	if y >= int(g.y) and y < int(g.z) and hh(y * 13 + g2.x * 7 + g2.y) >= 0.25:
		sh = (1 if hh(y * 3 + g2.x * 11 + g2.y) < 0.6 else 2) * (-1 if hh(y + g2.x * 5 + g2.y * 3) < 0.5 else 1)
	var c := Vector3(4, 7, 10)
	if sy < GH:
		var sx := clampi(x - sh, 0, GW - 1)
		var k := (sy * GW + sx) * 3
		c = Vector3(_pic[k], _pic[k + 1], _pic[k + 2])
		if g.w > 0.5:
			c.x = _pic[(sy * GW + maxi(0, sx - 1)) * 3]
			c.z = _pic[(sy * GW + mini(GW - 1, sx + 1)) * 3 + 2]
	var kk := p.x * p.w
	var v := c * kk + Vector3(2, 4, 6)
	var tl: Vector3 = o[&"g_title"]
	if tl.x > 0.5:
		v = _card_px(v, x, y, tl.y, int(tl.z))
	return v


## Every third frame the screen's colour eases toward what is on the glass (the page's SCH).
func _sample(o: Dictionary[StringName, Variant]) -> void:
	_sch_n += 1
	if (_sch_n - 1) % 3 != 0:
		return
	var s := Vector3.ZERO
	for y in range(4, GH - 4, 7):
		for x in range(4, GW - 4, 7):
			s += _scr_at(x, y, o)
	var m := maxf(s.x, maxf(s.y, s.z))
	if m > 1e3:
		_sch += (s / m - _sch) * 0.3


## The steam off the mug under the chin; it leans left.
func _steam(u: float) -> void:
	steam_img.fill(Color(0, 0, 0, 0))
	var life := 4.6
	var sway := sin(u * 0.31 + MUG_SEED) * 1.6
	for p in 16:
		var age := fposmod(u + p * life / 16.0 + MUG_SEED * 0.37, life)
		var a := age / life
		var ph := hh(p * 31 + MUG_SEED * 7) * 6.28
		var env := pow(sin(PI * minf(1.0, a * 1.25)), 0.7) * (1.0 - a * 0.35)
		for tr in 5:
			var ag := age - tr * 0.1
			if ag < 0.0:
				continue
			var yy := DeskFx.jround(MUG.y - 2 - ag * 8.2)
			var amp := 0.5 + ag * 1.25
			var xx := DeskFx.jround(MUG.x + amp * sin(ag * 1.7 + ph + sin(u * 0.45 + p) * 0.8) - ag * (0.5 + sway * 0.25) - 0.5)
			var al := 0.62 * env * (1.0 - tr * 0.14)
			_mark(xx, yy, al)
			if ag > 0.5:
				_mark(xx - 1, yy, al * 0.75)
			if ag > 1.4:
				_mark(xx + 1, yy, al * 0.6)
				_mark(xx, yy - 1, al * 0.6)
			if ag > 2.4:
				_mark(xx - 2, yy, al * 0.4)
				_mark(xx + 2, yy + 1, al * 0.3)


func _mark(x: int, y: int, a: float) -> void:
	var bx := x - SB.position.x
	var by := y - SB.position.y
	if bx < 0 or by < 0 or bx >= SB.size.x or by >= SB.size.y:
		return
	if a > steam_img.get_pixel(bx, by).r:
		steam_img.set_pixel(bx, by, Color(a, 0, 0, 0))


## The scope's trace (`drawScope`): per column its row, the span it joins down from the last, and how
## fresh it is (the page's levels, 0 brightest; -1 none). The sweep runs on the free clock.
func _trace(t: float) -> PackedVector4Array:
	var out := PackedVector4Array()
	var vis := seg(t, float(T.scope) + 0.4, float(T.scope) + 0.75)
	if vis <= 0.0:
		return out
	var s := r_clock / SCP
	var k := floorf(s)
	var ph := (s - k) * SCP
	var prev := -1
	for cx in SC.size.x:
		var hit := float(cx) / SC.size.x * SCVIS
		var kk := k
		var at := k * SCP + hit
		if hit > ph:
			kk = k - 1.0
			at = (k - 1.0) * SCP + hit
		var age := r_clock - at
		var lv := 4
		for i in 4:
			if age < [0.06, 0.3, 0.7, 1.15][i]:
				lv = i
				break
		var y := 103 + DeskFx.jround(WAVE[cx] * (0.75 + 0.45 * hh(kk * 17.0 + 3.0)))
		var lo := y if prev < 0 else mini(y, prev)
		var hi := y if prev < 0 else maxi(y, prev)
		out.append(Vector4(y, lo, hi, lv))
		prev = y
	return out


func frame(ts: float, real: float, is_leaving: bool) -> Dictionary[StringName, Variant]:
	leaving = is_leaving
	r_clock = real
	var t := ts
	var r := real
	var fade := ez(seg(t, float(T.fade), float(T.fade) + 0.55))
	var sb := PackedFloat32Array()
	var sw := PackedFloat32Array()
	var seg_a := [0.0, 0.0, 0.0, 0.0]
	var seg_n := [0, 0, 0, 0]
	for k in strings.size():
		var s: Dictionary = strings[k]
		sb.append(_str_b(s, k, t))
		sw.append(seg(t, float(s.on), float(s.on) + 0.6))
		seg_a[int(s.seg)] += minf(1.5, sb[k])
		seg_n[int(s.seg)] += 1
	var bb := _bulb_b(t)
	var bw := ez(seg(t, float(T.bulb) + 0.25, float(T.bulb) + 1.4))
	var ca := _crt_amp(t)
	var sg := ez(seg(t, float(T.scope), float(T.scope) + 0.45))
	var steady := _bulb_steady(t - float(T.bulb))
	if not leaving:
		_lv_hold = steady
		_lv_k = bw
	var lv_g := -1.0
	if leaving:
		lv_g = (1.0 if t >= float(T.bulb) else _afterglow(float(T.bulb) - t)) * _lv_hold
		if t >= float(T.bulb):
			bb = _bulb_b(maxf(t, float(T.bulb) + 2.0)) * _lv_hold
			bw = minf(ez(seg(maxf(t, float(T.bulb) + 2.0), float(T.bulb) + 0.25, float(T.bulb) + 1.4)), _lv_k)
		else:
			bb = lv_g
			bw = 0.35 * lv_g
	var crt := _crt(t)
	var u := t - float(T.crt)
	var pic := (not leaving and u >= roll) or (leaving and u >= 0.7)
	var booting := not leaving and u >= CW.o1 and u < roll
	var mc := Vector3(0.45, 1.0, 0.7) if booting else Vector3(0.55, 1.0, 0.89)
	var sm := (_sch.x + _sch.y + _sch.z) / 3.0
	var kc := mc + (Vector3(sm, sm, sm) + (_sch - Vector3(sm, sm, sm)) * 0.5 - mc) * (0.35 if pic else 0.0)
	var on := 0.0
	for q in 4:
		on += seg_a[q] / maxf(1.0, seg_n[q])
	on /= 4.0
	var dr := (0.5 + 0.4 * sin(r * 6.283 / 11.3 + 0.7) + 0.1 * sin(r * 6.283 / 4.1)) * bw
	var br := _brown(r)
	var alive := (t >= float(T.bulb) and _lv_hold >= 1.0) if lv_g >= 0.0 else (t - float(T.bulb)) > 1.2
	var fl_b := DeskFx.tired_bulb(r, 11.0, 1.2) * (1.0 - br) if alive else 1.0
	var bw_q := DeskFx.jround(bw * 12.0) / 12.0
	var col_s := Vector3(1.0, 0.5 + 0.26 * bw_q + 0.04, 0.22 + 0.26 * bw_q + 0.07)
	var u_out := crt
	_lights(t, sb, u_out)
	_steam(r)
	sky_img.fill(Color(0, 0, 0, 1))
	DeskFx.sky(sky_k, sky_img, port_box.position, r, 1.0, true)
	DeskFx.dust(meta.dust, dust_img, r, 1.0, GLASS)
	var ru := t - (float(T.rack) + 0.35)
	var lvl := DeskFx.jround((0.45 + 0.25 * hh(floorf(r * 3.0) * 7.0 + 1.0) + 0.1 * sin(r * 0.7)) * 25.0)
	var cool := 46.0 * minf(1.2, ca / 0.72) * fade * kc
	var rest: Dictionary[StringName, Variant] = {}
	rest.assign({
		w_big = Vector3(DeskFx.jround((lv_g if lv_g >= 0.0 else steady) * 24.0) / 24.0 * 1.3, (1.0 if ca > 0.0 else 0.0) * 1.05, 0.6),
		w_more = Vector4(DeskFx.jround(sg * 12.0) / 12.0 * 0.8, 0, 0, 0), tint_more_0 = Vector3(0.6, 1.0, 0.7),
		tint_lamp = Vector3.ONE + (col_s - Vector3.ONE) * 0.7, tint_scr = Vector3(0.775, 1.0, 0.945),
		st_fade = 1.0, hot_col = col_s, tint_small_a = _tints,
		fl_lamp = fl_b, fl_scr = ca / 0.72, fade = fade, port_org = port_box.position,
		bulb = Vector4(bb, bw, dr, br), str_v = sb, str_w = sw,
		bev = Vector2(minf(1.3, on), minf(1.2, ca / 0.72)),
		readout = Vector2(1.0 if ru >= 0.0 else 0.0, mini(lvl, int(floorf(minf(1.0, ru / 0.5) * 25.0)))),
		scope_g = sg, trace = _trace(t), steam_cool = cool,
		scope_vis = seg(t, float(T.scope) + 0.4, float(T.scope) + 0.75),
		g_scan = u >= 0.05, scan2_on = sg > 0.0,
	})
	u_out.merge(rest, true)
	_sample(crt)
	return u_out


## The string bulbs and LEDs: their weights and flicker, and how lit each LED's own pixels are.
func _lights(t: float, sb: PackedFloat32Array, o: Dictionary[StringName, Variant]) -> void:
	var ws := PackedFloat32Array()
	var fl := PackedFloat32Array()
	var lb := PackedFloat32Array()
	var lc := PackedVector4Array()
	for n in sb.size():
		var lit := sb[n] > 0.0
		ws.append(1.3 if lit else 0.0)
		fl.append(minf(sb[n], 1.35) * DeskFx.tired_bulb(r_clock, 60.0 + n * 7, 0.9, 5.0 + (n % 4), 23.0 + n) if lit else 1.0)
	for e: Dictionary in leds:
		var b := _led_b(e, t)
		ws.append(1.1 if b > 0.0 else 0.0)
		fl.append(b if b > 0.0 else 1.0)
		lb.append(b)
		var c: Array = e.col
		lc.append(Vector4(float(c[0]), float(c[1]), float(c[2]), 0.0))
	o[&"w_small"] = ws
	o[&"fl_small"] = fl
	o[&"led_b"] = lb
	o[&"led_col"] = lc
