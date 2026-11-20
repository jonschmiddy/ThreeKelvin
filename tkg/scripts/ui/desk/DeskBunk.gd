class_name DeskBunk
extends DeskLife

## The BUNK, the light hulls' fold-out shelf by a bunk: starlight on the blanket, a clip lamp, 25 string
## bulbs round the photos, LEDs, the old CRT. A port of the approved page's `scenes/bunk_1.js`: its
## clocks, levels and CPU layers (pixels: `bunk_1.gdshader`). The screen's light follows the lower
## half of the picture, read here from the page's own samples.
## Why: docs/why/DeskScene.md#porting-a-room

const GLASS := Rect2i(117, 22, 150, 140)
const GW := 150
const GH := 140
const SB := Rect2i(259, 137, 36, 48)
const MUG := Vector2i(277, 183)
const MUG_SEED := 5
const T_FADE := 2.5
const T_LAMP := 3.55
const T_STRING := 4.35
const T_CRT := 5.95
const T_LEDS := 5.6
const WARM := 1.5
const BOOT_END := 1.75 * WARM
const HOLD := 2.5
const WIPE := 0.4
const AFTER := 0.3
## The page's glitch list starts after its own card (T_CRT + its CRT_ON + 1.6).
const GL_AT := T_CRT + BOOT_END + HOLD + WIPE + 0.5 + 1.6
const GL_KINDS := [&"jitter", &"split", &"jitter", &"split", &"vhold"]
const JIT := [1, -2, 2, -1, 1]
## CRT phases (the shader's g_ph).
enum Ph { OFF, DOT, LINE, OPEN, BOOT, COLLAPSE, TITLE, PIC }

## The second boot line's length ("BOOT OK", or the site being read).
var _line2 := 7
var bulbs: Array = []
var leds: Array = []
var pillow: Array = []
var nb := 25
var nl := 5
var sky_k: Dictionary
var leaving := false
var r_clock := 0.0
## When the card wipes into the picture, seconds after T_CRT (the page's boot end + hold; held by the game).
var roll := BOOT_END + HOLD
var _lv_hold := 1.0
var _lv_k := 1.0
var _tints := PackedVector4Array()
var _gl: Array[Dictionary] = []
## The picture times the vignette (V) and its blur (B) at the screen light's samples, and the sum
## the page reads it against (refBottom).
var _v_pic := PackedFloat32Array()
var _b_smp := PackedFloat32Array()
var _v_smp := PackedFloat32Array()
var _ref := 1.0


func _init(m: Dictionary) -> void:
	meta = m
	_line2 = DeskRoom.boot_line("bunk_1").length()
	lamp_at = T_LAMP
	crt_at = T_CRT
	done_at = 12.1
	title_u = T_CRT + BOOT_END - 2.5
	title_wipe = WIPE
	small_q = 8
	scan = Vector3(158.0 / 255.0, 1.0, 0.0)
	steam_box = SB
	bulbs = m.bulbs
	leds = m.leds
	pillow = m.pillow
	nb = int(m.nb)
	nl = int(m.nl)
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
	_make_images(Vector2i(GW, GH))
	for t: Array in m.tints:
		_tints.append(Vector4(float(t[0]), float(t[1]), float(t[2]), 0.0))
	_tints.resize(32)
	_build_glitches()
	var cul := DeskRoom.SCREEN.get_image()
	var sm := 0.0
	for y in range(GH - 70, GH, 2):
		for x in range(0, GW, 3):
			var c := cul.get_pixel(x, y)
			sm += DeskFx.jround(c.r * 255.0) + DeskFx.jround(c.g * 255.0) + DeskFx.jround(c.b * 255.0)
	_ref = sm * 1.02


## The BUNK's own hash: an integer mix in JS's doubles (the products are doubles, not 32-bit
## multiplies, so they lose their low bits past 2^53 as the page's do).
static func bh(n: float) -> float:
	var a := _i32(float(_i32(n)) * 374761393.0 + 668265263.0)
	a = _i32(float(a ^ (_u32(a) >> 13)))
	a = _i32(float(a) * 1274126177.0)
	a = a ^ (_u32(a) >> 16)
	return float(_u32(a) % 100000) / 100000.0


## JS's ToInt32: truncate, then wrap into 32 signed bits.
static func _i32(d: float) -> int:
	var v := posmod(int(d), 4294967296)
	return v - 4294967296 if v >= 2147483648 else v


static func _u32(a: int) -> int:
	return posmod(a, 4294967296)


static func sstep(a: float, b: float, v: float) -> float:
	var u := clampf((v - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


static func vnoise(t: float, seed: float) -> float:
	var i := floorf(t)
	var f := t - i
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(bh(i * 191.0 + seed * 7.0), bh((i + 1.0) * 191.0 + seed * 7.0), u) * 2.0 - 1.0


func hold_title() -> void:
	roll = INF


func release(u: float) -> void:
	roll = maxf(u + 2.5 - T_CRT, BOOT_END)


func set_screen(img: Image) -> void:
	_v_pic.resize(GW * GH * 3)
	for y in GH:
		var ny := (y - (GH - 1) / 2.0) / (GH / 2.0)
		for x in GW:
			var nx := (x - (GW - 1) / 2.0) / (GW / 2.0)
			var r2 := (nx * nx + ny * ny) * 0.5
			var vig := 1.0 - 0.24 * r2 * r2
			var c := img.get_pixel(x, y)
			var k := (y * GW + x) * 3
			_v_pic[k] = DeskFx.jround(c.r * 255.0) * vig
			_v_pic[k + 1] = DeskFx.jround(c.g * 255.0) * vig
			_v_pic[k + 2] = DeskFx.jround(c.b * 255.0) * vig
	_v_smp.clear()
	_b_smp.clear()
	for y in range(GH - 70, GH, 2):
		for x in range(0, GW, 3):
			for c in 3:
				_v_smp.append(_v_pic[(y * GW + x) * 3 + c])
				_b_smp.append(_blur(func(xx: int, yy: int) -> float: return _v_pic[(yy * GW + xx) * 3 + c], x, y))


## The page's phosphor blur at (x, y): 1-2-1 across, then 1-2-1 down, edges held.
static func _blur(v: Callable, x: int, y: int) -> float:
	var xl := x - 1 if x > 0 else x
	var xr := x + 1 if x < GW - 1 else x
	var yu := y - 1 if y > 0 else y
	var yd := y + 1 if y < GH - 1 else y
	var s := 0.0
	for r: Array in [[yu, 1.0], [y, 2.0], [yd, 1.0]]:
		var yy: int = r[0]
		s += (float(v.call(xl, yy)) + 2.0 * float(v.call(x, yy)) + float(v.call(xr, yy))) * 0.25 * float(r[1])
	return s * 0.25


func _build_glitches() -> void:
	var at := GL_AT
	var ki := 0
	for n in 4000:
		ki = (ki + 1 + int(floorf(bh(n * 157 + 11) * 2.0))) % 5
		var kind: StringName = GL_KINDS[ki]
		var dur := 0.3 if kind == &"jitter" else (0.08 if kind == &"split" else 0.34)
		_gl.append({at = at, kind = kind, dur = dur, n = n, y0 = 8 + int(floorf(bh(n * 29 + 3) * 112.0)),
			rows = 3 + int(floorf(bh(n * 43 + 1) * 4.0))})
		at += dur + 3.0 + 5.0 * bh(n * 61 + 7)


## The glitch showing at t (its index in the list), or -1.
func _glitch(t: float) -> int:
	if t < float(_gl[0].at):
		return -1
	var lo := 0
	var hi := _gl.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if float(_gl[mid].at) <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo if t < float(_gl[lo].at) + float(_gl[lo].dur) else -1


func _afterglow(a: float) -> float:
	if a <= 0.0:
		return 1.0
	if a >= AFTER:
		return 0.0
	var x := 1.0 - a / AFTER
	return DeskFx.jround(x * x * 8.0) / 8.0


## The lamp's power-on steps (no life): the click, the stutter, then it settles.
static func _lamp_steady(a: float) -> float:
	if a < 0.0:
		return 0.0
	if a < 0.05:
		return 0.55
	if a < 0.11:
		return 0.06
	if a < 0.2:
		return 0.7
	if a < 0.26:
		return 0.22
	return lerpf(0.45, 1.0, ease_out((a - 0.26) / 0.75))


func _lamp_level(t: float) -> float:
	var a := t - T_LAMP
	if a < 0.26:
		return _lamp_steady(a)
	var r := r_clock
	var breathe := 1.0 + 0.04 * sin(r * 1.3) + 0.02 * sin(r * 3.1 + 1.2)
	breathe *= 1.0 + 0.022 * vnoise(r * 1.7, 61.0) + 0.012 * vnoise(r * 4.3, 67.0)
	var ci := floorf(r / 10.0)
	var at := 1.5 + bh(ci * 39.0 + 1.0) * 6.0
	var q := r - ci * 10.0 - at
	var ln := 0.45 + bh(ci * 22.0) * 0.25
	if q > 0.0 and q < ln:
		breathe *= 1.0 - (0.06 + bh(ci * 71.0) * 0.03) * sin(PI * q / ln)
	return _lamp_steady(a) * (breathe * _brown(r) if a > 1.0 else 1.0)


## A rare brown-out: the filament sags for a fraction of a second, wavers once, recovers.
static func _brown(t: float) -> float:
	var k := floorf((t - 9.0) / 10.0)
	if k < 0.0:
		return 1.0
	if k > 0.0 and bh(k * 71.0 + 5.0) > 0.5:
		return 1.0
	var at := 9.0 + k * 10.0 + (3.2 if k == 0.0 else 1.0 + 7.0 * bh(k * 37.0 + 2.0))
	var q := t - at
	if q < 0.0 or q > 0.75:
		return 1.0
	var depth := 0.15 + 0.1 * bh(k * 13.0 + 9.0)
	var env := q / 0.08 if q < 0.08 else (1.0 if q < 0.42 else 1.0 - sstep(0.42, 0.75, q))
	var waver := maxf(0.0, sin((q - 0.08) * PI / 0.17))
	return 1.0 - depth * env * (1.0 - 0.3 * waver)


func _lamp_warmth(t: float) -> float:
	var w := sstep(0.0, 1.4, t - T_LAMP)
	var r := r_clock
	var drift := 0.12 * sin(r * 0.23 + 0.7) + 0.06 * sin(r * 0.61)
	return clampf(w * (0.9 + drift) - (1.0 - _brown(r)) * 2.2, 0.0, 1.08)


func _bulb_level(b: Dictionary, t: float) -> float:
	var order := float(b.order)
	var jit := float(b.jit)
	var a := t - (T_STRING + order * 0.058 + jit * 0.035)
	if a < 0.0:
		return 0.0
	var v := 0.3 if a < 0.06 else lerpf(0.3, 1.0, ease_out((a - 0.06) / 0.4))
	if jit < 0.3 and a > 0.14 and a < 0.2:
		v *= 0.45
	var r := r_clock
	var tw := (1.0 + 0.13 * sin(r * float(b.w1) + float(b.ph)) + 0.07 * sin(r * float(b.w2) + float(b.ph2))) * _swell(r, order)
	var slot := 9.0 + jit * 7.0
	var k := floorf((r + float(b.ph)) / slot)
	var dip := 1.0
	if bh(k * 97.0 + order * 13.0) < 0.3:
		var at := (k + 0.2 + 0.6 * bh(k * 41.0 + order)) * slot - float(b.ph)
		var q := (r - at) / 0.5
		if q > 0.0 and q < 1.0:
			dip = 1.0 - 0.42 * sin(q * PI)
	return v * tw * dip


static func _swell(t: float, order: float) -> float:
	var k := floorf((t - 9.0) / 11.0)
	if k < 0.0:
		return 1.0
	var v := 1.0
	for kk: float in [k - 1.0, k]:
		if kk < 0.0 or (kk > 0.0 and bh(kk * 53.0 + 11.0) > 0.7):
			continue
		var at := 9.0 + kk * 11.0 + (1.0 if kk == 0.0 else 2.0 * bh(kk * 19.0 + 4.0))
		var d := (order - ((t - at) * 4.2 - 4.0)) / 2.6
		if absf(d) < 3.0:
			v += 0.32 * exp(-d * d)
	return v


## The CRT at t: its phase, its own clock (po for the warm-up), its light's level.
func _crt(t: float) -> Vector3:
	var p := t - T_CRT
	if p < 0.0:
		return Vector3(Ph.OFF, p, 0.0)
	if leaving and p >= 0.32 and p < 2.45:
		return Vector3(Ph.COLLAPSE, p, lerpf(0.18, 1.0, sstep(0.4, 1.9, p)))
	if leaving and p >= 2.45:
		return Vector3(Ph.PIC, p, 1.0)
	var po := p / WARM
	if leaving:
		return Vector3(Ph.DOT, p, 0.12) if p < 0.12 else Vector3(Ph.LINE, p, 0.2)
	if po < 0.12:
		return Vector3(Ph.DOT, po, 0.12)
	if po < 0.32:
		return Vector3(Ph.LINE, po, 0.2)
	if po < 0.62:
		return Vector3(Ph.OPEN, po, 0.45 - 0.2 * (po - 0.32) / 0.3)
	if po < 1.75:
		return Vector3(Ph.BOOT, po, 0.2)
	if p < roll:
		return Vector3(Ph.TITLE, p, 0.45)
	if p < roll + WIPE:
		return Vector3(Ph.PIC, p, lerpf(0.45, 1.0, (p - roll) / WIPE))
	return Vector3(Ph.PIC, p, 1.0)


## The steam off the mug (`steamField`): each pixel keeps the strongest wisp over it.
func _steam(u: float) -> void:
	steam_img.fill(Color(0, 0, 0, 0))
	var life := 4.6
	var sway := sin(u * 0.31 + MUG_SEED) * 1.6
	for p in 16:
		var age := fposmod(u + p * life / 16.0 + MUG_SEED * 0.37, life)
		var a := age / life
		var ph := bh(p * 31 + MUG_SEED * 7) * 6.28
		var env := pow(sin(PI * minf(1.0, a * 1.25)), 0.7) * (1.0 - a * 0.35)
		for tr in 5:
			var ag := age - tr * 0.1
			if ag < 0.0:
				continue
			var yy := DeskFx.jround(MUG.y - 2 - ag * 8.2)
			var amp := 0.5 + ag * 1.25
			var xx := DeskFx.jround(MUG.x + amp * sin(ag * 1.7 + ph + sin(u * 0.45 + p) * 0.8) + ag * (0.5 + sway * 0.25) - 0.5)
			var al := 0.62 * env * (1.0 - tr * 0.14)
			_mark(xx, yy, al)
			if ag > 0.5:
				_mark(xx + 1, yy, al * 0.75)
			if ag > 1.4:
				_mark(xx - 1, yy, al * 0.6)
				_mark(xx, yy - 1, al * 0.6)
			if ag > 2.4:
				_mark(xx + 2, yy, al * 0.4)
				_mark(xx - 2, yy + 1, al * 0.3)


func _mark(x: int, y: int, a: float) -> void:
	var bx := x - SB.position.x
	var by := y - SB.position.y
	if bx < 0 or by < 0 or bx >= SB.size.x or by >= SB.size.y:
		return
	if a > steam_img.get_pixel(bx, by).r:
		steam_img.set_pixel(bx, by, Color(a, 0, 0, 0))


## The picture through a glitch at glass pixel (x, y), channel c, before the vignette.
func _pic_g(x: int, y: int, c: int, g: Vector4) -> float:
	var sx := x
	var sy := y
	match int(g.x):
		1:
			if y >= int(g.y) and y < int(g.y) + int(g.z):
				var s2 := int(g.w) if (y - int(g.y)) % 2 == 1 else signi(int(g.w))
				sx = clampi(x - s2, 0, GW - 1)
		2:
			if c == 0 and x > 0:
				sx = x - 1
			elif c == 2 and x < GW - 1:
				sx = x + 1
		3:
			sy = y - int(g.y)
	var nx := (x - (GW - 1) / 2.0) / (GW / 2.0)
	var ny := (y - (GH - 1) / 2.0) / (GH / 2.0)
	var r2 := (nx * nx + ny * ny) * 0.5
	var vig := 1.0 - 0.24 * r2 * r2
	if sy < 0:
		return [2.0, 3.0, 4.0][c] * vig
	var k := (sy * GW + sx) * 3 + c
	var nx0 := (sx - (GW - 1) / 2.0) / (GW / 2.0)
	var ny0 := (sy - (GH - 1) / 2.0) / (GH / 2.0)
	var r0 := (nx0 * nx0 + ny0 * ny0) * 0.5
	return _v_pic[k] / (1.0 - 0.24 * r0 * r0) * vig


## The page's read of the lower glass (the picture's bottom half, vignetted and bloomed) against its rest.
func _bottom(m0: float, g: Vector4) -> float:
	var sum := 0.0
	if g.x == 0.0:
		for k in _v_smp.size():
			sum += m0 * _v_smp[k] + maxf(0.0, m0 * _b_smp[k] - 45.0) * 0.3
		return clampf(1.0 + 3.0 * (sum / _ref - 1.0), 0.7, 1.5)
	for y in range(GH - 70, GH, 2):
		for x in range(0, GW, 3):
			for c in 3:
				var v := m0 * _pic_g(x, y, c, g)
				var b := m0 * _blur(func(xx: int, yy: int) -> float: return _pic_g(xx, yy, c, g), x, y)
				sum += v + maxf(0.0, b - 45.0) * 0.3
	return clampf(1.0 + 3.0 * (sum / _ref - 1.0), 0.7, 1.5)


## The lamp's level and warmth at t (leaving: full and alive until the click, then the afterglow),
## its steady level for the stepping and its flicker.
func _lamp(t: float) -> Vector4:
	var lamp := _lamp_level(t)
	var warm := _lamp_warmth(t)
	if not leaving:
		_lv_hold = _lamp_steady(t - T_LAMP)
		_lv_k = clampf(warm, 0.0, 1.0)
	var lv_g := -1.0
	if leaving:
		lv_g = (1.0 if t >= T_LAMP else _afterglow(T_LAMP - t)) * _lv_hold
		if t >= T_LAMP:
			lamp = lv_g * _lamp_level(maxf(t, T_LAMP + 2.0))
			warm = minf(_lamp_warmth(maxf(t, T_LAMP + 2.0)), _lv_k)
		else:
			lamp = lv_g
			warm = 0.35 * lv_g
	var a := t - T_LAMP
	var steady := lv_g if lv_g >= 0.0 else _lamp_steady(a)
	var alive := (t >= T_LAMP and _lv_hold >= 1.0) if lv_g >= 0.0 else a > 1.0
	var fl := DeskFx.tired_bulb(r_clock, 9.0, 1.2) * _brown(r_clock) if alive else 1.0
	return Vector4(lamp, warm, steady, fl)


func _leds(t: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for L: Dictionary in leds:
		var v := 0.0
		match String(L.kind):
			"standby":
				v = 0.85
			"strip":
				v = 1.0 if t > T_LEDS else 0.0
			"beat":
				v = 0.0 if t < T_LEDS + 0.5 else (1.0 if fmod(r_clock - T_LEDS, 2.3) < 0.14 else 0.12)
			"amber":
				v = 0.9 if t > T_LEDS + 0.25 else 0.0
			"amber2":
				v = 0.7 if t > T_LEDS + 0.35 else 0.0
		out.append(v)
	return out


## The glass's uniforms for the CRT's phase: its warm-up numbers, the card, the glitch, the tube's life.
func _glass(t: float, c: Vector3, o: Dictionary[StringName, Variant]) -> Vector4:
	var ph := int(c.x)
	var p := c.y
	var on := ph == Ph.PIC or ph == Ph.TITLE or ph == Ph.BOOT or ph == Ph.COLLAPSE
	var live := ph == Ph.PIC and (leaving or p >= roll + WIPE + 0.5)
	var r := r_clock
	var wob := 1.0 + 0.035 * sin(r * 0.37 + 1.0) + 0.02 * sin(r * 1.05) if live else 1.0
	var flick := 1.0 + 0.011 * sin(r * 5.3) * sin(r * 1.9 + 1.0) + 0.007 * sin(r * 8.7 + 2.0) * sin(r * 0.7) if on else 1.0
	var g := Vector4.ZERO
	var spill := 1.0
	var gi := _glitch(r) if live else -1
	if gi >= 0:
		var e := _gl[gi]
		var q := (r - float(e.at)) / float(e.dur)
		match e.kind:
			&"vhold":
				g = Vector4(3, 3 if q < 0.3 else (1 if q < 0.65 else 0), 0, 0)
				spill *= 0.9 if q < 0.6 else 1.0
				if g.y == 0.0:
					g = Vector4.ZERO
			&"jitter":
				g = Vector4(1, float(e.y0), float(e.rows), JIT[(int(floorf(q * 4.3)) + int(e.n)) % 5])
				spill *= 0.95
			&"split":
				g = Vector4(2, 0, 0, 0)
				spill *= 0.93
	var k := 0.0
	var n := 0
	match ph:
		Ph.DOT:
			k = sstep(0.0, 0.08, p)
		Ph.LINE:
			n = maxi(2, DeskFx.jround(75.0 * ease_out((p - 0.12) / 0.2)))
		Ph.OPEN:
			k = ease_out((p - 0.32) / 0.3)
			n = maxi(2, DeskFx.jround(70.0 * k))
			_noise(floorf(p * 15.0))
		Ph.COLLAPSE:
			k = sstep(0.4, 1.9, p)
			n = maxi(1, DeskFx.jround(70.0 * k))
	var bright := 1.0
	var wipe := Vector3(0.0, p - BOOT_END, -99.0)
	if ph == Ph.TITLE:
		wipe.x = 1.0
	elif ph == Ph.PIC and not leaving and p < roll + WIPE:
		wipe = Vector3(1.0, p - BOOT_END, DeskFx.jround((p - roll) / WIPE * (GH + 4)) - 2.0)
	elif ph == Ph.PIC and not live:
		bright = lerpf(1.15, 1.0, (p - roll - WIPE) / 0.5)
	o.merge({g_ph = ph, g_k = k, g_n = n, g_bright = bright, g_title = wipe, g_glitch = g, g_wob = wob,
		g_on = on, g_flick = flick, g_boot = _boot(p, ph), g_scan = ph != Ph.OFF})
	return Vector4(spill, flick, wob, 1.0 if live else 0.0) if g.x == 0.0 else Vector4(spill, flick, wob, -1.0)


## The boot line typed so far: chars of each line, and the cursor (on, x, y) packed as (n1, n2, x + on * 1000, y).
func _boot(p: float, ph: int) -> Vector4:
	if ph != Ph.BOOT:
		return Vector4.ZERO
	var a := p - 0.72
	var n1 := 0 if a < 0.0 else int(floorf(a / 0.055)) + 1
	var cx := 6 + 4 * clampi(n1, 0, 11)
	var cy := 7
	var n2 := 0
	if a > 0.75:
		# the line types in the boot's last 0.26 (a long site name faster than BOOT OK did)
		n2 = int(floorf((a - 0.75) / minf(0.07, 0.26 / _line2))) + 1
		cx = 6 + 4 * clampi(n2, 0, _line2)
		cy = 15
	var cur := int(floorf(p * 3.0)) % 2 == 0 and a > -0.3
	return Vector4(n1, n2 if a > 0.75 else -1, cx + (1000 if cur else 0), cy)


## The raster's snow while it opens, in the page's doubles.
func _noise(fr: float) -> void:
	noise_new = true
	for y in GH:
		for x in GW:
			noise_img.set_pixel(x, y, Color(bh(x * 7 + y * 1031 + fr * 7919), 0, 0))


func frame(ts: float, real: float, is_leaving: bool) -> Dictionary[StringName, Variant]:
	leaving = is_leaving
	r_clock = real
	noise_new = false
	var t := ts
	var fade := sstep(T_FADE, T_FADE + 0.6, t)
	var lp := _lamp(t)
	var c := _crt(t)
	var bl := PackedFloat32Array()
	for b: Dictionary in bulbs:
		bl.append(_bulb_level(b, t))
	var u_out: Dictionary[StringName, Variant] = {}
	var gs := _glass(t, c, u_out)
	var spill := gs.x * gs.y
	if gs.w != 0.0:
		var g: Vector4 = u_out[&"g_glitch"]
		spill *= _bottom(gs.z, g)
	var warm_q := DeskFx.jround(clampf(lp.y, 0.0, 1.0) * 12.0) / 12.0
	var fade_q := DeskFx.jround(fade * 24.0) / 24.0
	var lc_s := Vector3(1.0, lerpf(0.56, 0.75, warm_q), lerpf(0.28, 0.47, warm_q))
	var lv := _leds(t)
	var jb_on := 1.0 if t > T_LEDS + 0.6 else 0.0
	_small(bl, lv, jb_on, fade_q, u_out)
	var son := 0.0
	var pil := 0.0
	for k in nb:
		son += 1.0 if bl[k] > 0.0 else 0.0
	for k: float in pillow:
		pil += 1.0 if bl[int(k)] > 0.0 else 0.0
	pil /= pillow.size()
	var lc := Vector3(1.0, lerpf(0.56, 0.75, lp.y), lerpf(0.28, 0.47, lp.y))
	_steam(r_clock)
	sky_img.fill(Color(0, 0, 0, 1))
	DeskFx.sky(sky_k, sky_img, port_box.position, r_clock, 1.0)
	DeskFx.dust(meta.dust, dust_img, r_clock, fade, GLASS)
	var s := floorf(r_clock * 2.0)
	var jb := Vector4(jb_on, 0, 0, 0)
	for row in 3:
		jb[row + 1] = 2 + int(floorf(bh(s * 3.0 + row * 101 + (0.0 if row == 1 else floorf(t / 3.0) * 7.0)) * 6.0))
	var rest: Dictionary[StringName, Variant] = {}
	rest.assign({
		w_big = Vector3(DeskFx.jround(lp.z * 24.0) / 24.0 * 1.3, DeskFx.jround(c.z * 16.0) / 16.0 * 1.3, 0.6 * fade_q),
		w_more = Vector4(0.9 * fade_q, 1.3 * pil * fade_q, 0.5 * fade_q, 0.85 * fade_q * son / nb),
		tint_lamp = Vector3.ONE + (lc_s - Vector3.ONE) * 0.7, tint_scr = Vector3(0.8, 0.96, 0.95),
		tint_more_0 = Vector3(0.62, 0.78, 1.0), tint_more_1 = Vector3(1.0, 0.8, 0.55),
		tint_more_2 = Vector3(0.66, 0.8, 1.0), tint_more_3 = Vector3(1.0, 0.78, 0.5),
		st_fade = fade_q, hot_col = lc_s, tint_small_a = _tints,
		port_org = port_box.position,
		fl_lamp = lp.w, fl_scr = spill, fade = fade, canvas_fade = 1.0 - fade,
		lamp = Vector4(minf(1.0, lp.x), lp.y, 0.0, 0.0), str_v = bl, led_v = lv, jb = jb,
		steam_warm = 44.0 * minf(1.0, lp.x) * lc, steam_cool = 46.0 * minf(1.0, c.z) * Vector3(0.6, 0.92, 0.9),
	})
	u_out.merge(rest)
	return u_out


## The small lights: the bulbs, the LEDs, the junction box's readout; their weights and flicker.
func _small(bl: PackedFloat32Array, lv: PackedFloat32Array, jb_on: float, fade_q: float, o: Dictionary[StringName, Variant]) -> void:
	var ws := PackedFloat32Array()
	var fl := PackedFloat32Array()
	for n in nb:
		var on := bl[n] > 0.0
		ws.append((1.3 if on else 0.0) * fade_q)
		fl.append(minf(bl[n], 1.35) * DeskFx.tired_bulb(r_clock, 40.0 + n * 7, 0.9, 5.0 + (n % 4), 23.0 + n) if on else 1.0)
	for k in nl:
		ws.append((1.2 if lv[k] > 0.0 else 0.0) * fade_q)
		fl.append(lv[k] if lv[k] > 0.0 else 1.0)
	ws.append(jb_on * fade_q)
	fl.append(1.0)
	o[&"w_small"] = ws
	o[&"fl_small"] = fl
