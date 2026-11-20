class_name DeskOne
extends DeskLife

## DESK 1, the lived-in bridge desk: its power-on and idle, ported from the approved page's
## `scenes/desk_1.js` (tools/desk/page). This is the scalar half: every clock, level and weight
## per frame, and the small CPU layers (dust, steam, the porthole sky, the iron's smoke). The
## per-pixel half is `shaders/desk_1.gdshader`; the baked tables come from `tools/desk/dump_desk.py`.
## Why: docs/why/DeskScene.md#the-plan

const ID := "desk_1"
const GLASS := Rect2i(117, 22, 150, 140)
## The steam's box (`SB`) and the porthole window's box in art pixels.
const SB := Rect2i(250, 120, 50, 66)
const PORT_BOX := Rect2i(296, 8, 32, 32)
const MUG := Vector2i(272, 180)
const MUG_SEED := 1.0
## Sound times in scene seconds (audio.js TIMES: 2.5 + T.click, 2.5 + T.dot).
const LAMP_AT := 3.45
const CRT_AT := 5.1
## When the power-on is done (the shell's `doneAt`): a leave from later starts here.
const DONE_AT := 11.8
const GL_SLOT := 5.5
## The lamp's afterglow when it goes out on leaving, scene seconds (0.14 s real at the 2.2x leave).
const AFTER := 0.3
## The timeline (u = seconds since act 1 went black); roll and idle follow the title card.
const T := {fade = 0.6, click = 0.95, strings = 1.9, monLed = 2.45, dot = 2.6, line = 2.87, open = 3.17,
	boot = 3.62, title = 5.82, solder = 2.3}
const OFF := {pic = 4.6, squeeze = 3.6, line = 3.05, dot = 2.5}
const TITLE_HOLD := 2.5
const TITLE_WIPE := 0.4
const ROLL := 5.82 + TITLE_HOLD
const IDLE := ROLL + TITLE_WIPE + 0.5

var strings: Array = []
var sky_k: Dictionary
var tip: Array = []
var tipc := Vector2i(327, 171)
var smoke := {}
var leaving := false
## When the title card wipes into the picture (u). The page's ROLL; in the game the card holds
## until the tap (`hold_title`), and `release` sets it.
var roll := ROLL
## The lamp's level when the leave began (it never jumps up on the way out).
var _lv_hold := 1.0
var _lv_k := 1.0
var c := 0.0


func _init(m: Dictionary) -> void:
	meta = m
	strings = m.strings
	var on := {}
	var idx: Array[int] = []
	for i: float in m.sky.o.idx:
		on[int(i)] = true
		idx.append(int(i))
	var o: Dictionary = (m.sky.o as Dictionary).duplicate()
	o.idx = idx
	sky_k = {o = o, set = on, S = m.sky.S, stars = m.sky.stars}
	tip = m.TIP
	tipc = Vector2i(int(m.TIPC.x), int(m.TIPC.y))
	smoke = m.SMOKE
	lamp_at = LAMP_AT
	crt_at = CRT_AT
	done_at = DONE_AT
	title_u = T.title
	title_wipe = TITLE_WIPE
	steam_box = SB
	port_box = PORT_BOX
	# noise_img is the raster's noise while it opens (phase 3), in doubles as the page has it:
	# float32's sin at these arguments is a different noise
	_make_images(GLASS.size)


## The game's card: it waits for a tap instead of the page's 2.5 s.
func hold_title() -> void:
	roll = INF


## The tap: the card wipes into the picture now (never before it is up).
func release(u: float) -> void:
	roll = maxf(u, float(T.title))


## Leaving, the lamp holds its full living light until the clock reaches its click, then goes out
## like a switched filament: an afterglow over AFTER scene seconds, (1 - x)^2 held in eighths,
## cooling to deep orange. A leave before it was warm holds the level it had.
func _lamp(u: float) -> Dictionary[StringName, Variant]:
	if not leaving:
		return _lamp_fwd(u)
	var r: Dictionary[StringName, Variant] = {}
	if u >= T.click:
		var f := _lamp_fwd(maxf(u, 2.6))
		r.assign({fil = float(f[&"fil"]) * _lv_hold, k = minf(float(f[&"k"]), _lv_k), brown = 0.0, drift = f[&"drift"],
			w = float(f[&"w"]) * pow(_lv_hold, 1.25)})
		return r
	var g := _afterglow(T.click - u) * _lv_hold
	r.assign({fil = g, k = 0.35 * g, brown = 0.0, drift = 0.0, w = pow(g, 1.25)})
	return r


func _afterglow(a: float) -> float:
	if a <= 0.0:
		return 1.0
	if a >= AFTER:
		return 0.0
	var x := 1.0 - a / AFTER
	return DeskFx.jround(x * x * 8.0) / 8.0


func _lamp_fwd(u: float) -> Dictionary[StringName, Variant]:
	var fil := 0.0
	if u < T.click:
		fil = 0.0
	elif u < 1.03:
		fil = 0.5
	elif u < 1.10:
		fil = 0.06
	elif u < 1.22:
		fil = 0.72
	elif u < 1.30:
		fil = 0.32
	else:
		fil = lerpf(0.32, 1.0, DeskFx.ease_s((u - 1.30) / 0.85))
	var k := DeskFx.ease_s((u - 1.05) / 1.5)
	var breathe := 1.0
	var brown := 0.0
	var drift := 0.0
	if u > 2.2:
		var b := DeskFx.sat((u - 2.2) / 2.0)
		breathe = 1.0 + b * (0.045 * sin(c * TAU * 0.13) + 0.024 * sin(c * TAU * 0.41 + 1.3) + 0.01 * sin(c * TAU * 1.7 + 0.4))
		breathe *= 1.0 + b * (0.022 * DeskFx.vnoise(c * 1.7, 61.0) + 0.012 * DeskFx.vnoise(c * 4.3, 67.0))
		var ci := floorf(c / 10.0)
		var at := 1.5 + DeskFx.rnd(ci * 3.9 + 1.0) * 6.0
		var a := c - ci * 10.0 - at
		var ln := 0.45 + DeskFx.rnd(ci * 2.2) * 0.25
		if a > 0.0 and a < ln:
			breathe *= 1.0 - b * (0.06 + DeskFx.rnd(ci * 7.1) * 0.03) * sin(PI * a / ln)
		drift = b * sin(c * TAU / 23.0 + 0.7)
	if u > IDLE + 2.0 and not leaving:
		var ci := floorf(c / 17.0)
		var ph := c - ci * 17.0
		if DeskFx.rnd(ci * 7.7 + 3.0) > 0.25:
			var a := ph - (3.0 + DeskFx.rnd(ci * 5.3) * 10.0)
			var depth := 0.15 + DeskFx.rnd(ci * 2.1) * 0.1
			if a > 0.0 and a < 0.95:
				var d := a / 0.08 if a < 0.08 else (1.0 - 0.3 * sin(PI * (a - 0.08) / 0.22) if a < 0.3 else 1.0 - DeskFx.ease_s((a - 0.3) / 0.65))
				brown = depth * d
	var r: Dictionary[StringName, Variant] = {}
	r.assign({fil = fil, k = k, brown = brown, drift = drift, w = pow(fil, 1.25) * breathe * (1.0 - brown)})
	return r


func _string_level(s: Dictionary, u: float) -> float:
	var on := float(T.strings) + float(s.k) * 0.12 + float(s.jit) * 0.05 + (0.04 if int(s.side) != 0 else 0.0)
	var a := u - on
	if a < 0.0:
		return 0.0
	var lv := 1.0
	if bool(s.stutter):
		lv = 0.8 if a < 0.07 else (0.0 if a < 0.2 else (1.3 if a < 0.26 else 1.0))
	else:
		lv = 1.35 if a < 0.05 else 1.0
	if u > IDLE - 3.0:
		var ib := DeskFx.sat((u - IDLE + 3.0) / 2.0)
		lv *= 1.0 + ib * (0.18 * sin(c * 6.283 * float(s.f1) + float(s.p1)) + 0.1 * sin(c * 6.283 * float(s.f2) + float(s.p2)))
		var sw := fposmod(c + (5.2 if int(s.side) != 0 else 0.0), 10.5)
		var dk := float(s.k) - (sw * 3.2 - 2.0)
		lv *= 1.0 + 0.32 * ib * exp(-dk * dk / 2.2)
		var dc := fposmod(c + float(s.dipOff), float(s.dipEvery))
		if dc < 0.9:
			lv *= 1.0 - 0.35 * ib * sin(PI * dc / 0.9)
	return lv


func _screen_level(u: float) -> float:
	if leaving:
		if u >= OFF.pic:
			return 0.62
		if u >= OFF.squeeze:
			return lerpf(0.28, 0.62, (u - OFF.squeeze) / (OFF.pic - OFF.squeeze))
		if u >= OFF.line:
			return lerpf(0.06, 0.22, (u - OFF.line) / (OFF.squeeze - OFF.line))
		if u >= OFF.dot:
			return 0.08 * (u - OFF.dot) / (OFF.line - OFF.dot)
		return 0.0
	if u < T.dot:
		return 0.0
	if u < T.line:
		return 0.12 * DeskFx.ease_s((u - T.dot) / 0.1)
	if u < T.open:
		return 0.22
	if u < T.boot:
		return lerpf(0.5, 0.2, DeskFx.ease_s((u - T.open) / 0.3))
	if u < T.title:
		return 0.2
	if u < roll:
		return 0.4
	if u < roll + TITLE_WIPE + 0.5:
		return lerpf(0.35, 0.7, DeskFx.ease_s((u - roll) / 0.5))
	return 0.62


## One glitch per 5.5 s slot, never two at once: row jitter, an RGB split, or a v-hold hiccup.
func _glitch(u: float) -> Dictionary[StringName, Variant]:
	if u < IDLE + 1.5 or leaving:
		return {} as Dictionary[StringName, Variant]
	var si := floorf(c / GL_SLOT)
	var ph := c - si * GL_SLOT
	var at := 0.3 + DeskFx.rnd(si * 4.1 + 2.0) * 4.0
	var hk := DeskFx.rnd(si * 6.7 + 9.0)
	var kind := &"jit" if hk < 0.5 else (&"rgb" if hk < 0.88 else &"hold")
	var dur: float = {&"jit": 0.26, &"rgb": 0.05, &"hold": 0.2}[kind]
	var a := ph - at
	if a < 0.0 or a >= dur:
		return {} as Dictionary[StringName, Variant]
	var r: Dictionary[StringName, Variant] = {}
	r.assign({kind = kind, a = a, dur = dur, si = si, y0 = 8 + int(floorf(DeskFx.rnd(si * 9.1) * 118.0)),
		h = 3 + int(floorf(DeskFx.rnd(si * 4.4) * 6.0))})
	return r


func _crt(u: float) -> Dictionary[StringName, Variant]:
	var b := 1.0
	if u >= T.dot:
		b *= 1.0 + 0.014 * DeskFx.vnoise(c * 3.3, 11.0) + 0.009 * DeskFx.vnoise(c * 7.1, 23.0)
	var ib := DeskFx.sat(u - IDLE + 1.0)
	b *= 1.0 + ib * (0.04 * sin(c * TAU / 9.3) + 0.02 * sin(c * TAU / 3.7 + 1.0))
	var gl := _glitch(u)
	if not gl.is_empty():
		match gl[&"kind"]:
			&"jit":
				b *= 0.95
			&"hold":
				b *= 0.88 if float(gl[&"a"]) < 0.1 else 0.95
			&"rgb":
				b *= 0.96
	var r: Dictionary[StringName, Variant] = {}
	r.assign({b = b, gl = gl})
	return r


func _pipe_led(u: float) -> float:
	if u < T.strings + 0.5:
		return 0.35 + 0.3 * (0.5 + 0.5 * sin(c * 2.4))
	var q := fposmod(c, 3.1)
	if q < 0.09 or (q > 0.2 and q < 0.29):
		return 0.25
	return 1.0


func _solder(u: float) -> float:
	if u < T.solder:
		return 0.0
	if u - T.solder < 1.6:
		return 1.0
	var tt := fposmod(c, 40.0)
	var n := 0
	while n <= 200:
		var on := 0.5 + DeskFx.rnd(n * 3.3 + 1.0) * 1.1
		var offd := 0.35 + DeskFx.rnd(n * 5.9 + 2.0) * 0.7
		if tt < on:
			return 1.0
		tt -= on
		if tt < offd:
			return 0.0
		tt -= offd
		n += 1
	return 1.0


## The steam over the mug (`drawSteam`): each pixel keeps the strongest wisp over it.
func _steam() -> void:
	steam_img.fill(Color(0, 0, 0, 0))
	var np := 16
	var life := 4.6
	var sway := sin(c * 0.31 + MUG_SEED) * 1.6
	for p in np:
		var age := fposmod(c + p * life / np + MUG_SEED * 0.37, life)
		var a := age / life
		var ph := DeskFx.rnd(p * 3.1 + MUG_SEED) * 6.28
		var env := pow(sin(PI * minf(1.0, a * 1.25)), 0.7) * (1.0 - a * 0.35)
		for tr in 5:
			var ag := age - tr * 0.1
			if ag < 0.0:
				continue
			var yy := DeskFx.jround(MUG.y - 2 - ag * 8.2)
			var amp := 0.5 + ag * 1.25
			var xx := DeskFx.jround(MUG.x + amp * sin(ag * 1.7 + ph + sin(c * 0.45 + p) * 0.8) + ag * (0.5 + sway * 0.25) - 0.5)
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


## The iron's smoke (`drawWisp`): points in drawing order, (x, y, alpha), for the shader to lerp in turn.
func _wisp(k: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var life: float = smoke.life
	var np: int = int(smoke.np)
	var sd: float = smoke.seed
	for p in np:
		var age := fposmod(c + p * life / np + sd * 0.37, life)
		var a := age / life
		for tr in 3:
			var ag := age - tr * 0.15
			if ag < 0.0:
				continue
			var yy := DeskFx.jround(float(smoke.y) - ag * float(smoke.rise))
			var amp := 0.3 + ag * 0.7
			var xx := DeskFx.jround(float(smoke.x) + amp * sin(ag * 1.9 + sd + sin(c * 0.35 + sd) * 1.4) + ag * 0.5)
			if yy < 0 or yy >= DeskFx.H or xx < 0 or xx >= DeskFx.W or GLASS.has_point(Vector2i(xx, yy)):
				continue
			out.append(Vector3(xx, yy, float(smoke.alpha) * k * pow(sin(PI * a), 0.9) * (1.0 - tr * 0.25)))
	return out


## Everything the shader needs this frame. `ts` is the scene time (backwards while leaving), `real`
## the free clock (seconds since the start; only ever forward).
func frame(ts: float, real: float, is_leaving: bool) -> Dictionary[StringName, Variant]:
	var u := ts - 2.5
	leaving = is_leaving
	c = real - 2.5
	var fade := DeskFx.ease_s(u / T.fade)
	if not leaving:
		var lf := _lamp_fwd(u)
		_lv_hold = lf[&"fil"]
		_lv_k = lf[&"k"]
	var lp := _lamp(u)
	var steady_l := pow(float(lp[&"fil"]), 1.25)
	var flick_l := (1.0 - float(lp[&"brown"])) * (DeskFx.tired_bulb(c, 3.0, 1.2) if u > 1.4 else 1.0)
	var kq := DeskFx.jround(float(lp[&"k"]) * 12.0) / 12.0
	var lamp_col := Vector3(1.0, lerpf(0.42, 0.72, kq), lerpf(0.12, 0.4, kq))
	var son := PackedFloat32Array()
	var sfl := PackedFloat32Array()
	var n := 0
	for s: Dictionary in strings:
		var v := _string_level(s, u)
		son.append(1.0 if v > 0.0 else 0.0)
		sfl.append(minf(v, 1.35) * DeskFx.tired_bulb(c, 50.0 + n * 7, 0.9, 5.0 + (n % 4), 23.0 + n) if v > 0.0 else 0.0)
		n += 1
	var scr := _screen_level(u)
	var crt := _crt(u)
	var boot_tint := not leaving and u >= T.boot and u < roll
	var mc := Vector3(0.45, 1.0, 0.7) if boot_tint else Vector3(0.55, 1.0, 0.89)
	var st_l := DeskFx.jround(steady_l * fade * 24.0) / 24.0
	var st_s := DeskFx.jround(scr * 32.0) / 32.0
	var st_f := DeskFx.jround(fade * 24.0) / 24.0
	var f_m: float = float(crt[&"b"]) * float(crt[&"b"])
	var ws := PackedFloat32Array()
	var sm := PackedFloat32Array()
	for k in son.size():
		ws.append(son[k] * 1.3 * st_f)
		sm.append(sfl[k] if son[k] > 0.0 else 1.0)
	var pipe_on := _pipe_led(u)
	var solder_on := _solder(u)
	var mon_on := 1.0 if u >= T.monLed else 0.0
	var tip_on := DeskFx.ease_s((u - T.solder - 0.3) / 1.2) * (1.0 + 0.07 * DeskFx.vnoise(c * 5.3, 41.0) + 0.04 * DeskFx.vnoise(c * 13.1, 43.0)) * fade
	var lwf := steady_l * flick_l * fade
	_steam()
	sky_img.fill(Color(0, 0, 0, 1))
	DeskFx.sky(sky_k, sky_img, PORT_BOX.position, c, 1.0)
	DeskFx.dust(meta.dust, dust_img, c, fade, GLASS)
	var glows := [
		[Vector4(39, 95, pipe_on * 0.9, 4.5), Vector3(1, 0.55, 0.15)],
		[Vector4(340.5, 163, solder_on * 0.8, 3.5), Vector3(1, 0.18, 0.1)],
		[Vector4(tipc.x, tipc.y, tip_on * 0.75, 5), Vector3(1, 0.42, 0.12)],
		[Vector4(tipc.x, tipc.y + 2, tip_on * 0.3, 11), Vector3(1, 0.45, 0.15)],
		[Vector4(128.5, 169.5, mon_on * 0.6, 3), Vector3(0.35, 1, 0.45)]]
	var u_out: Dictionary[StringName, Variant] = {}
	u_out.assign({
		# the compose: steady weights only (they set where the bands fall)
		w_big = Vector3(st_l * 1.3, st_s * 1.05, 0.6 * st_f),
		tint_lamp = Vector3(lerpf(1, lamp_col.x, 0.7), lerpf(1, lamp_col.y, 0.7), lerpf(1, lamp_col.z, 0.7)),
		tint_scr = Vector3(lerpf(1, mc.x, 0.5), lerpf(1, mc.y, 0.5), lerpf(1, mc.z, 0.5)),
		w_small = ws, st_fade = st_f, hot_col = lamp_col,
		# the flicker: multiplies after the stepping
		fl_lamp = flick_l, fl_scr = f_m, fl_small = sm,
		glow_a = PackedVector4Array(glows.map(func(g: Array) -> Vector4: return g[0])),
		glow_c = PackedVector3Array(glows.map(func(g: Array) -> Vector3: return g[1])),
		tip_on = tip_on, fade = fade,
		bulb = Vector4(lp[&"fil"], lp[&"k"], lp[&"brown"], lp[&"drift"]), bulb_w = steady_l * flick_l,
		str_v = sfl, pipe_on = pipe_on, solder_on = solder_on, mon_on = mon_on,
		steam_warm = Vector3(44.0 * lwf * lamp_col.x, 44.0 * lwf * lamp_col.y, 44.0 * lwf * lamp_col.z),
		steam_cool = Vector3(46.0 * scr * f_m * mc.x, 46.0 * scr * f_m * mc.y, 46.0 * scr * f_m * mc.z),
		wisp = _wisp(DeskFx.sat(tip_on)) if tip_on > 0.05 else PackedVector3Array(),
		lwf = lwf,
	})
	_glass(u, crt, u_out)
	return u_out


## The CRT's state for the glass (`drawGlass`): its phase, the warm-up's progress, glitches, the card.
func _glass(u: float, crt: Dictionary, o: Dictionary[StringName, Variant]) -> void:
	var fd := DeskFx.ease_s(u / T.fade)
	var gl: Dictionary = crt[&"gl"]
	var roll_off := 0
	var roll_gain := 1.0
	if not leaving and u >= roll and u < roll + TITLE_WIPE + 0.5:
		roll_gain = 1.0 + 0.15 * (1.0 - (u - roll) / (TITLE_WIPE + 0.5))
	if not gl.is_empty() and gl[&"kind"] == &"hold":
		roll_off = 2 if float(gl[&"a"]) < 0.1 else (-1 if float(gl[&"a"]) < 0.15 else 1)
	var phase := 0
	var p_dot := 0.0
	var p_line := 0.0
	var p_sq := 0.0
	if not leaving:
		phase = 0 if u < T.dot else (1 if u < T.line else (2 if u < T.open else (3 if u < T.boot else (4 if u < T.title else (7 if u < roll else 5)))))
		p_dot = DeskFx.ease_s((u - T.dot) / 0.18)
		p_line = DeskFx.ease_s((u - T.line) / (T.open - T.line))
	elif u >= OFF.pic:
		phase = 5
	elif u >= OFF.squeeze:
		phase = 6
		p_sq = (u - OFF.squeeze) / (OFF.pic - OFF.squeeze)
	elif u >= OFF.line:
		phase = 2
		p_line = DeskFx.ease_s((u - OFF.line) / (OFF.squeeze - OFF.line))
	elif u >= OFF.dot:
		phase = 1
		p_dot = DeskFx.ease_s((u - OFF.dot) / (OFF.line - OFF.dot))
	var jit_dx := 0
	if not gl.is_empty() and gl[&"kind"] == &"jit":
		var q := floorf(float(gl[&"a"]) * 16.0)
		jit_dx = [1, -1, 2, -2, 1][int(floorf(DeskFx.rnd(q * 3.3 + float(gl[&"si"])) * 5.0))]
	var last: Dictionary = meta.boot[meta.boot.size() - 1]
	var nl := String(last.s).length()
	var cursor := phase == 4 and u > float(last.t) + DeskRoom.boot_step(DeskRoom.BOOT_LINE.desk_1, nl) * nl and int(floorf(c * 2.2)) % 2 == 0
	o.g_phase = phase
	o.g_u = u
	o.g_p = Vector4(p_dot, p_line, p_sq, DeskFx.ease_s((u - T.open) / (T.boot - T.open)))
	o.g_off0 = Vector3(2.0 + 2.0 * fd, 3.0 + 3.0 * fd, 5.0 + 5.0 * fd)
	o.g_refl = float(_lamp(u)[&"w"]) * fd
	o.g_roll = Vector2(roll_off, roll_gain)
	o.g_frame = floorf(c * 15.0)
	noise_new = phase == 3
	if noise_new:
		var fr := floorf(c * 15.0)
		for y in GLASS.size.y:
			for x in GLASS.size.x:
				noise_img.set_pixel(x, y, Color(DeskFx.rnd(x * 13.1 + y * 71.7 + fr * 3.3) * 0.12, 0, 0))
	var jit_on: bool = not gl.is_empty() and gl[&"kind"] == &"jit"
	o.g_jit = Vector4(1.0 if jit_on else 0.0, float(gl.get(&"y0", 0)), float(gl.get(&"h", 0)), jit_dx)
	o.g_rgb = (not gl.is_empty()) and gl[&"kind"] == &"rgb"
	o.g_b = float(crt[&"b"]) if phase >= 1 else 1.0
	o.g_leaving = leaving
	o.g_cursor = Vector3(1.0 if cursor else 0.0, int(last.x) + String(last.s).length() * 4 + 1, int(last.y))
	var title_on := not leaving and u >= T.title and u < roll + TITLE_WIPE
	o.g_title = Vector3(1.0 if title_on else 0.0, u - T.title, 0.0 if u < roll else (u - roll) / TITLE_WIPE)
	o.g_scan = u >= (OFF.dot if leaving else T.dot)
