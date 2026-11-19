class_name DeskTwo
extends DeskLife

## DESK 2, the heavy hulls' bridge desk: a shaded lamp, 33 string bulbs, the old CRT. A port of
## the approved page's `scenes/desk_2.js`: clocks, levels and CPU layers (pixels: `desk_2.gdshader`).
## Its screen light follows the picture's sampled mean and a colour eased 30% a frame, so a frame
## depends on the one before it, as on the page.
## Why: docs/why/DeskScene.md#porting-a-room

const GLASS := Rect2i(117, 22, 150, 140)
const GW := 150
const GH := 140
const SB := Rect2i(252, 144, 36, 48)
const MUG := Vector2i(270, 190)
const MUG_SEED := 2.0
const T := {room = 2.5, roomIn = 0.6, lamp = 3.45, str = 4.7, crt = 5.6, iron = 7.2}
## The CRT's warm-up, seconds after T.crt + 0.12.
const CRT0 := 5.72
const CB := {dot = 0.105, line = 0.405, open = 0.78, boot = 3.68}
const HOLD := 2.5
const WIPE := 0.4
const STR_ON := [0.0, 0.32, 0.16, 0.5]
const STR_P := [11.3, 13.7, 12.4, 15.1]
const STR_T0 := [0.0, 5.5, 2.7, 8.1]
const AFTER := 0.3
const BLANK := Vector3(14, 24, 30)
## The glitch round: five slots, the fifth names no kind (the page's GL_KINDS has four), so that
## slot shows nothing but dims the screen's light 5% until the next.
const GL_KINDS := [&"jitter", &"rgb", &"jitter", &"vhold", &""]
const GL_DUR := {&"jitter": 0.32, &"rgb": 0.05, &"vhold": 0.36}
const JIT := [1, 2, -1, 1, 0, 2, -1]
## CRT states (the shader's g_st).
enum St { OFF, DOT, LINE, SHRINK, OPEN, TITLE, BOOT, PIC }

var strings: Array = []
var sky_k: Dictionary
var leaving := false
## When the card wipes into the picture, seconds after CRT0 (the page's boot + hold; held by the game).
var roll := 3.68 + HOLD
var _lv_hold := 1.0
var _lv_k := 1.0
var _scr_col := Vector3(0.5, 0.95, 0.9)
var _cult_mean := 0.3
var _gl_starts: Array[float] = []
var _gl_types: Array[StringName] = []
## The picture and the card as floats, for the screen light's samples.
var _pic := PackedFloat32Array()
var _card := PackedFloat32Array()
var _blink := PackedByteArray()
## Each glass pixel's place in the boot text's typing order (-1 none), from the bake.
var _boot := PackedInt32Array()
var _boot_lines: Array = []
var _tints := PackedVector4Array()
var _cream := PackedFloat32Array()


func _init(m: Dictionary) -> void:
	meta = m
	lamp_at = T.lamp
	crt_at = T.crt
	done_at = 12.8
	title_u = CRT0 + float(CB.boot) - 2.5
	title_wipe = WIPE
	small_q = 16
	scan = Vector3(179.0 / 256.0, 1.0, 1.0)
	steam_box = SB
	strings = m.strings
	var on := {}
	var idx: Array[int] = []
	var x0 := 9999
	var y0 := 9999
	var x1 := 0
	var y1 := 0
	for i: float in m.sky.o.idx:
		on[int(i)] = true
		idx.append(int(i))
		x0 = mini(x0, int(i) % DeskFx.W)
		x1 = maxi(x1, int(i) % DeskFx.W)
		y0 = mini(y0, int(i) / DeskFx.W)
		y1 = maxi(y1, int(i) / DeskFx.W)
	port_box = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	var o: Dictionary = (m.sky.o as Dictionary).duplicate()
	o.idx = idx
	sky_k = {o = o, set = on, S = m.sky.S, stars = m.sky.stars}
	_make_images(Vector2i(1, 1))
	for s: Dictionary in strings:
		var col: Array = s.col
		_tints.append(Vector4(0.5 + 0.5 * float(col[0]), 0.41 + 0.5 * float(col[1]), 0.31 + 0.5 * float(col[2]), 0.0))
		_cream.append(1.0 if bool(s.cream) else 0.0)
	_tints.resize(64)
	_boot_lines = m.boot
	var gl := DeskRoom.plane(String(m.id), "glass", DeskRoom.GLASS, Image.FORMAT_RGBAF).get_image()
	_boot.resize(GW * GH)
	for y in GH:
		for x in GW:
			_boot[y * GW + x] = int(gl.get_pixel(x, y).g)
	# the page's own picture sets the scale the screen light is read against (cultMean)
	var cul := DeskRoom.SCREEN.get_image()
	var sm := 0.0
	var n := 0
	for y in range(1, GH, 3):
		for x in range(1, GW, 3):
			var c := cul.get_pixel(x, y)
			sm += 0.3 * DeskFx.jround(c.r * 255.0) + 0.59 * DeskFx.jround(c.g * 255.0) + 0.11 * DeskFx.jround(c.b * 255.0)
			n += 1
	_cult_mean = sm / n / 255.0


## DESK 2's own hash (not ROOMFX's): fract(sin(n * 127.1 + 311.7) * 43758.5453), in doubles.
static func rnd(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


static func vnoise(t: float, sd: float) -> float:
	var i := floorf(t)
	var f := t - i
	var k := f * f * (3.0 - 2.0 * f)
	return (rnd(i * 1.91 + sd) * (1.0 - k) + rnd((i + 1.0) * 1.91 + sd) * k) * 2.0 - 1.0


static func ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - DeskFx.sat(k), 3.0)


func hold_title() -> void:
	roll = INF


func release(u: float) -> void:
	roll = maxf(u + 2.5 - CRT0, float(CB.boot))


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


func _afterglow(a: float) -> float:
	if a <= 0.0:
		return 1.0
	if a >= AFTER:
		return 0.0
	var x := 1.0 - a / AFTER
	return DeskFx.jround(x * x * 8.0) / 8.0


## The filament catches: two stutters, then it warms from deep orange to amber. (p, warm)
func _lamp_power(t: float) -> Vector2:
	var s := t - float(T.lamp)
	if s < 0.0:
		return Vector2(0, 0)
	if s < 0.06:
		return Vector2(0.35, 0)
	if s < 0.13:
		return Vector2(0.04, 0)
	if s < 0.21:
		return Vector2(0.5, 0.05)
	if s < 0.27:
		return Vector2(0.12, 0.05)
	var k := ease_out((s - 0.27) / 1.1)
	return Vector2(0.55 + 0.45 * k, k)


func _bulb_power(b: Dictionary, n: int, t: float, r: float) -> float:
	var side := int(b.side)
	var k := float(b.k)
	var on := float(T.str) + float(STR_ON[side]) + k * 0.085 + (rnd(k * 3.0 + side * 50.0) - 0.5) * 0.05
	var s := t - on
	if s < 0.0:
		return 0.0
	if s < 0.04:
		return 0.7
	if s < 0.09:
		return 0.1
	var kk := clampf((s - 0.09) / 0.22, 0.0, 1.0)
	var per := float(b.per)
	var ph := float(b.ph)
	var tw := 0.8 + 0.12 * sin(r * 2.0 * PI / per + ph * 6.28) + 0.08 * sin(r * 2.0 * PI / (per * 0.43) + float(b.ph2) * 6.28)
	var ep := floorf((r + ph * 13.0) / (9.0 + per * 2.0))
	var tin := (r + ph * 13.0) - ep * (9.0 + per * 2.0)
	var dip := 1.0
	if rnd(ep * 7.0 + k + side * 40.0) < 0.22 and tin < 0.5:
		dip = 0.5 if tin < 0.12 else (0.85 if tin < 0.2 else (0.55 if tin < 0.32 else 0.85 + (tin - 0.32) / 0.18 * 0.15))
	return (0.25 + 0.75 * kk) * tw * (1.0 if kk < 1.0 else dip * _swell(b, r))


## Now and then a slow swell drifts along each string, from the monitor end outward.
func _swell(b: Dictionary, t: float) -> float:
	var side := int(b.side)
	var p: float = STR_P[side]
	var t0 := 7.0 + float(STR_T0[side])
	if t < t0:
		return 1.0
	var n := floorf((t - t0) / p)
	var s := (t - t0) - n * p
	if rnd(n * 5.1 + side * 9.0) < 0.25:
		return 1.0
	var d := (float(b.k) - (-2.0 + s * 3.2)) / 1.8
	return 1.0 + 0.38 * exp(-d * d)


## The lamp's warm-cool drift and its rare brown-out. (drift, brown)
func _lamp_life(t: float) -> Vector2:
	var drift := 0.6 * sin(t * 2.0 * PI / 13.1) + 0.4 * sin(t * 2.0 * PI / 5.3 + 2.0)
	var brown := 1.0
	if t > 8.0:
		var p := 8.7
		var n := floorf((t - 8.0) / p)
		var s := (t - 8.0) - n * p - rnd(n * 3.3) * 4.0
		if rnd(n * 7.7) < 0.3 and s >= 0.0 and s < 0.7:
			var depth := 0.16 + 0.1 * rnd(n * 1.9)
			brown = 1.0 - depth * (s / 0.08) if s < 0.08 else (1.0 - depth * 0.55 if s < 0.16 else (1.0 - depth if s < 0.28 else 1.0 - depth * (1.0 - ease_out((s - 0.28) / 0.42))))
	return Vector2(drift, brown)


## The CRT's state at t: st, k, and the shrink's flare, the wipe's card time.
func _crt(t: float) -> Dictionary[StringName, Variant]:
	var o: Dictionary[StringName, Variant] = {}
	o.assign(_crt_raw(t))
	return o


func _crt_raw(t: float) -> Dictionary[Variant, Variant]:
	var s := t - CRT0
	if leaving:
		var u := minf(1.0, s / 3.4)
		if s < 0.0:
			return {st = St.OFF, k = 0.0}
		if u > 0.86:
			return {st = St.PIC, k = 0.0, flare = clampf((1.0 - u) / 0.14, 0.0, 1.0), on = true}
		if u > 0.45:
			return {st = St.SHRINK, k = (u - 0.45) / 0.41}
		if u > 0.2:
			return {st = St.LINE, k = (u - 0.2) / 0.25}
		return {st = St.DOT, k = u / 0.2, fade_dot = true}
	if s < 0.0:
		return {st = St.OFF, k = 0.0}
	if s < CB.dot:
		return {st = St.DOT, k = s / CB.dot}
	if s < CB.line:
		return {st = St.LINE, k = (s - CB.dot) / (CB.line - CB.dot)}
	if s < CB.open:
		return {st = St.OPEN, k = (s - CB.line) / (CB.open - CB.line)}
	if s < CB.boot:
		return {st = St.BOOT, k = (s - CB.open) / 1.5}
	var tt := s - float(CB.boot)
	if s < roll:
		return {st = St.TITLE, k = tt}
	if s < roll + WIPE:
		return {st = St.PIC, k = (s - roll) / WIPE, tt = tt, wipe = true}
	if s < roll + WIPE + 0.5:
		return {st = St.PIC, k = (s - roll - WIPE) / 0.5, settle = true}
	return {st = St.PIC, k = tt, on = true}


## Glitches: one every 3 to 8 s from a fixed list of start times (on the free clock).
func _glitch(t: float) -> Dictionary[StringName, Variant]:
	var t0 := CRT0 + float(CB.boot) + HOLD + WIPE + 0.5 + 1.5
	var none: Dictionary[StringName, Variant] = {}
	if t < t0:
		return none
	while _gl_starts.is_empty() or _gl_starts[_gl_starts.size() - 1] < t:
		var n := _gl_starts.size()
		var prev := _gl_starts[n - 1] if n > 0 else t0
		_gl_starts.append(prev + 3.0 + 5.0 * rnd(n * 2.71 + 0.3))
		var ty: StringName = GL_KINDS[n % 5]
		if ty == &"vhold" and int(floorf(n / 5.0)) % 2 == 1:
			ty = &"rgb"
		_gl_types.append(ty)
	var k := _gl_starts.bsearch(t, false) - 1
	if k < 0:
		return none
	var ty := _gl_types[k]
	var s := t - _gl_starts[k]
	if GL_DUR.has(ty) and s > float(GL_DUR[ty]):
		return none
	none.assign({type = ty, s = s, r1 = rnd(k * 3.1 + 0.7), r2 = rnd(k * 4.9 + 0.2)})
	return none


static func _spill(gl: Dictionary[StringName, Variant]) -> float:
	if gl.is_empty():
		return 1.0
	match gl[&"type"]:
		&"vhold":
			return 0.9 if float(gl[&"s"]) < 0.09 else 0.97
		&"jitter":
			return 0.96 if int(floorf(float(gl[&"s"]) / 0.07)) % 2 == 1 else 1.03
	return 0.95


static func _crt_life(t: float) -> float:
	return 1.0 + 0.014 * sin(t * 2.0 * PI / 4.1) + 0.009 * sin(t * 2.0 * PI / 1.7 + 0.8) + 0.006 * sin(t * 2.0 * PI / 0.53 + 2.1)


## The boot text typed so far: chars shown, and the cursor's place.
func _boot_at(k: float) -> Vector3:
	var s0 := int(floorf(k * 33.0)) - 4
	var shown := s0
	var cy := 6
	var last := Vector2i(6, 6)
	for line: String in _boot_lines:
		var cx := 6
		for c in line.length():
			if shown <= 0:
				break
			cx += 4
			shown -= 1
		last = Vector2i(cx, cy)
		if shown <= 0:
			break
		shown -= 3
		cy += 8
	return Vector3(s0, last.x, last.y)


## The card over the picture at glass pixel k (the shell's titleCard): tt, the wipe line.
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


func _pic_px(x: int, y: int) -> Vector3:
	var k := (y * GW + x) * 3
	return Vector3(_pic[k], _pic[k + 1], _pic[k + 2])


## What the page's fillScreen puts at glass pixel (x, y) this frame (before the bloom).
func _scr(x: int, y: int, c: Dictionary[StringName, Variant], g: Dictionary[StringName, Variant]) -> Vector3:
	match int(c[&"st"]):
		St.DOT:
			if x >= 74 and x <= 75 and y >= 69 and y <= 70:
				return Vector3(230, 250, 255) * float(g[&"dk"])
		St.LINE:
			var hw: int = g[&"n"]
			if x >= 75 - hw and x < 75 + hw:
				if y == 69:
					return Vector3(210, 240, 250)
				if y == 70:
					return Vector3(120, 170, 190)
		St.SHRINK:
			var hh: int = g[&"n"]
			if y >= 70 - hh and y < 70 + hh:
				var k := float(c[&"k"])
				var sy := mini(GH - 1, int(floorf(float(y - (70 - hh)) / (2 * hh) * GH)))
				var v := _pic_px(x, sy) * float(g[&"boost"]) + Vector3(40, 55, 60) * (1.0 - k)
				return Vector3(minf(255, v.x), minf(255, v.y), minf(255, v.z))
		St.OPEN:
			var hh: int = g[&"n"]
			if y >= 70 - hh and y < 70 + hh:
				var gl := 1.0 - float(c[&"k"])
				var e := gl if absf(y - 69.5) < 2.0 else 0.0
				return BLANK * (1.0 + 1.5 * gl) + Vector3(190, 220, 230) * e
		St.TITLE:
			return _card_px(Vector3.ZERO, x, y, float(c[&"k"]), -99)
		St.BOOT:
			var b: Vector3 = g[&"boot"]
			if g[&"cursor"] and x >= int(b.y) and x < int(b.y) + 3 and y >= int(b.z) and y < int(b.z) + 5:
				return Vector3(150, 222, 186) * 0.85
			var i := _boot[y * GW + x]
			if i >= 0 and i < int(b.x):
				return Vector3(150, 222, 186)
			return BLANK
		St.PIC:
			var v := _pic_px(x, y) * float(g[&"bright"])
			if c.has(&"wipe"):
				v = _card_px(v, x, y, float(c[&"tt"]), int(g[&"wy"]))
			return v
	return Vector3.ZERO


## The glass's state for this frame, its mean brightness (0..1) as the page samples it, and the
## eased colour of what it shows.
func _fill(r: float, c: Dictionary[StringName, Variant]) -> Dictionary[StringName, Variant]:
	var g: Dictionary[StringName, Variant] = {}
	g.assign({dk = 1.0, n = 0, boost = 1.0, bright = 1.0, wy = -99, cursor = false, boot = Vector3.ZERO, mean = 0.0})
	if int(c[&"st"]) == St.OFF:
		return g
	var k := float(c[&"k"])
	match int(c[&"st"]):
		St.DOT:
			g[&"dk"] = k if c.has(&"fade_dot") else 1.0
		St.LINE:
			g[&"n"] = maxi(1, DeskFx.jround(ease_out(k) * 75.0))
		St.SHRINK:
			g[&"n"] = maxi(1, DeskFx.jround(ease_out(k) * 70.0))
			g[&"boost"] = 1.0 + (1.0 - k) * 1.4
		St.OPEN:
			g[&"n"] = maxi(1, DeskFx.jround(ease_out(k) * 70.0))
		St.BOOT:
			g[&"boot"] = _boot_at(k)
			g[&"cursor"] = int(floorf(r * 2.6)) % 2 == 0
		St.PIC:
			if c.has(&"flare"):
				g[&"bright"] = 1.0 + 0.25 * (1.0 - float(c[&"flare"]))
			if c.has(&"wipe"):
				g[&"wy"] = DeskFx.jround(k * (GH + 4)) - 2
	var sum := 0.0
	var n := 0
	var sc := Vector3.ZERO
	for y in range(1, GH, 3):
		for x in range(1, GW, 3):
			var v := _scr(x, y, c, g)
			sum += 0.3 * v.x + 0.59 * v.y + 0.11 * v.z
			sc += v
			n += 1
	var m := maxf(sc.x, maxf(sc.y, sc.z))
	if m > 1e3:
		_scr_col += (sc / m - _scr_col) * 0.3
	g[&"mean"] = sum / n / 255.0
	return g


## The steam over the mug (`steamField`): each pixel keeps the strongest wisp over it.
func _steam(u: float) -> void:
	steam_img.fill(Color(0, 0, 0, 0))
	var life := 4.6
	var sway := sin(u * 0.31 + MUG_SEED) * 1.6
	for p in 16:
		var age := fposmod(u + p * life / 16.0 + MUG_SEED * 0.37, life)
		var a := age / life
		var ph := rnd(p * 3.1 + MUG_SEED) * 6.28
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


## The lamp at t: (p, warm), whether it is fully up (its life applies), and its colour.
func _lamp(t: float, r: float) -> Array[Variant]:
	var lp := _lamp_power(t)
	var lf := _lamp_life(r)
	var full := t >= float(T.lamp) + 1.4
	if not leaving:
		_lv_hold = lp.x
		_lv_k = lp.y
	elif t >= float(T.lamp):
		lp = Vector2(_lv_hold, _lv_k)
		full = _lv_hold >= 1.0
	else:
		var g0 := _afterglow(float(T.lamp) - t) * _lv_hold
		lp = Vector2(g0, 0.35 * g0)
		full = false
	var dr := 0.035 * lf.x - 0.25 * (1.0 - lf.y) if full else 0.0
	var lc := Vector3(1.0, 0.40 + 0.34 * lp.y + dr, maxf(0.08, 0.12 + 0.30 * lp.y + 1.2 * dr))
	var flick := DeskFx.tired_bulb(r, 7.0, 1.2) * lf.y if full else 1.0
	var out: Array[Variant] = [lp, lc, flick]
	return out


## The string bulbs: their steady weights, their flicker, and how lit each one's own pixels are.
func _strings(t: float, r: float, fade_q: float, o: Dictionary[StringName, Variant]) -> void:
	var ws := PackedFloat32Array()
	var sfl := PackedFloat32Array()
	var sw := PackedFloat32Array()
	var n := 0
	for b: Dictionary in strings:
		var v := _bulb_power(b, n, t, r)
		ws.append((1.3 * fade_q) if v > 0.0 else 0.0)
		sfl.append(minf(v, 1.35) * DeskFx.tired_bulb(r, 30.0 + n * 7, 0.9, 5.0 + (n % 4), 23.0 + n) if v > 0.0 else 1.0)
		sw.append(clampf(v, 0.0, 1.1))
		n += 1
	o[&"w_small"] = ws
	o[&"fl_small"] = sfl
	o[&"str_v"] = sw


## The glass's uniforms (`drawScreen`): its state, the warm-up's numbers, the glitch, the card.
func _glass(r: float, crt: Dictionary[StringName, Variant], g: Dictionary[StringName, Variant], gl: Dictionary[StringName, Variant], o: Dictionary[StringName, Variant]) -> void:
	var st := int(crt[&"st"])
	var jit := Vector3(-1, -1, 0)
	var vhold := 0
	if not gl.is_empty():
		var s: float = gl[&"s"]
		match gl[&"type"]:
			&"jitter":
				var y0 := 8 + int(floorf(float(gl[&"r1"]) * 110.0))
				jit = Vector3(y0, y0 + 2 + int(floorf(float(gl[&"r2"]) * 5.0)), JIT[int(floorf(s / 0.07)) % 7] * (1 if float(gl[&"r1"]) < 0.5 else -1))
			&"vhold":
				vhold = 2 if s < 0.09 else (-1 if s < 0.2 else (1 if s < 0.3 else 0))
	var boot: Vector3 = g[&"boot"]
	o.assign({g_st = st, g_k = float(crt[&"k"]), g_n = int(g[&"n"]), g_dk = float(g[&"dk"]), g_boost = float(g[&"boost"]),
		g_bright = float(g[&"bright"]),
		g_live = _crt_life(r) if (st == St.BOOT or st == St.TITLE or st == St.PIC) else 1.0,
		g_title = Vector3(1.0 if (st == St.TITLE or crt.has(&"wipe")) else 0.0, float(crt.get(&"tt", crt[&"k"])), float(g[&"wy"])),
		g_boot = Vector4(boot.x, 1.0 if g[&"cursor"] else 0.0, boot.y, boot.z),
		g_jit = jit, g_rgb = (not gl.is_empty()) and gl[&"type"] == &"rgb", g_vhold = vhold,
		g_scan = st != St.OFF})


func frame(ts: float, real: float, is_leaving: bool) -> Dictionary[StringName, Variant]:
	leaving = is_leaving
	var t := ts
	var r := real
	var fade := clampf((t - float(T.room)) / float(T.roomIn), 0.0, 1.0)
	var lamp := _lamp(t, r)
	var lp: Vector2 = lamp[0]
	var lc: Vector3 = lamp[1]
	var flick: float = lamp[2]
	var crt := _crt(t)
	var g := _fill(r, crt)
	var st := int(crt[&"st"])
	var gl: Dictionary[StringName, Variant] = {}
	if st == St.PIC and crt.has(&"on") and not leaving and t >= CRT0 + roll + WIPE + 0.5 + 1.5:
		gl = _glitch(r)
	var crt_w := 0.0
	if st != St.OFF:
		crt_w = clampf(0.8 * float(g[&"mean"]) / _cult_mean, 0.0, 1.6) * (_crt_life(r) if crt.has(&"on") else 1.0) * _spill(gl)
	var booting := st == St.BOOT or st == St.OPEN or st == St.TITLE
	var cc := Vector3(0.55, 1.0, 0.89)
	if booting:
		cc = Vector3(0.45, 1.0, 0.7)
	elif st == St.PIC:
		var sm := (_scr_col.x + _scr_col.y + _scr_col.z) / 3.0
		cc = cc + ((Vector3(sm, sm, sm) + _scr_col) / 2.0 - cc) * 0.35
	var lp_s := DeskFx.jround(lp.x * 24.0) / 24.0
	var warm_q := DeskFx.jround(lp.y * 12.0) / 12.0
	var fade_q := DeskFx.jround(fade * 24.0) / 24.0
	var lc_s := Vector3(1.0, 0.40 + 0.34 * warm_q, maxf(0.08, 0.12 + 0.30 * warm_q))
	var mc := Vector3(0.45, 1.0, 0.7) if booting else Vector3(0.55, 1.0, 0.89)
	var lamp_w := lp.x * flick
	var ir := 0.0
	if t >= float(T.iron):
		var s := t - float(T.iron)
		ir = 1.0 if s < 1.6 else (1.0 if fposmod(r, 2.9) < 1.9 else 0.0)
		if s < 0.05:
			ir = 0.6
	_steam(r)
	sky_img.fill(Color(0, 0, 0, 1))
	DeskFx.sky(sky_k, sky_img, port_box.position, r, fade)
	DeskFx.dust(meta.dust, dust_img, r, fade, GLASS)
	var u_out: Dictionary[StringName, Variant] = {}
	_glass(r, crt, g, gl, u_out)
	_strings(t, r, fade_q, u_out)
	var rest: Dictionary[StringName, Variant] = {}
	rest.assign({
		w_big = Vector3(lp_s * 1.3, (0.0 if st == St.OFF else 1.0) * 1.05, 0.6 * fade_q),
		tint_lamp = Vector3.ONE + (lc_s - Vector3.ONE) * 0.7,
		tint_scr = Vector3.ONE + (mc - Vector3.ONE) * 0.5,
		st_fade = fade_q, hot_col = lc_s, tint_small_a = _tints,
		fl_lamp = flick, fl_scr = crt_w, fade = fade,
		lamp = Vector4(lp.x, lp.y, flick, 0.0), str_cream = _cream,
		mon_on = 1.0 if t >= float(T.crt) else 0.0, iron_on = ir,
		sheen = Vector4(lamp_w, lc.x, lc.y, lc.z),
		steam_warm = 44.0 * minf(1.0, lamp_w) * lc, steam_cool = 46.0 * minf(1.2, crt_w) * cc,
	})
	u_out.merge(rest)
	return u_out
