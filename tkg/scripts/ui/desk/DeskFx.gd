class_name DeskFx
extends RefCounted

## The science desk's shared small effects, ported from the approved page's `roomfx.js` (tools/desk/page):
## the hash every clock rolls from, value noise, the tired bulb, dust in the air and the living porthole.
## All of it runs at art resolution in whole pixels on the room's free clock C, as the page does.
## Why: docs/why/DeskScene.md#the-plan

const W := 384
const H := 216
const BAYER: Array[float] = [0.5 / 16, 8.5 / 16, 2.5 / 16, 10.5 / 16, 12.5 / 16, 4.5 / 16, 14.5 / 16,
	6.5 / 16, 3.5 / 16, 11.5 / 16, 1.5 / 16, 9.5 / 16, 15.5 / 16, 7.5 / 16, 13.5 / 16, 5.5 / 16]


## The page's hash: fract(sin(n * 12.9898 + 78.233) * 43758.5453), in doubles as JS has it.
static func hash(n: float) -> float:
	var s := sin(n * 12.9898 + 78.233) * 43758.5453
	return s - floor(s)


static func sat(v: float) -> float:
	return 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)


## The rooms' ease: smoothstep of a clamped t.
static func ease_s(t: float) -> float:
	t = sat(t)
	return t * t * (3.0 - 2.0 * t)


static func bay(x: int, y: int) -> float:
	return BAYER[(y & 3) * 4 + (x & 3)]


static func vnoise(t: float, seed: float) -> float:
	var i := floor(t)
	var f := t - i
	var s := f * f * (3.0 - 2.0 * f)
	return lerpf(hash(i * 1.91 + seed), hash((i + 1.0) * 1.91 + seed), s) * 2.0 - 1.0


## JS's Math.round: halves go up.
static func jround(v: float) -> int:
	return int(floor(v + 0.5))


## A Uint8ClampedArray store: clamped, halves to even.
static func u8(v: float) -> int:
	if not (v > 0.0):
		return 0
	if v >= 255.0:
		return 255
	var f := floor(v)
	var d := v - f
	if d > 0.5 or (d == 0.5 and int(f) % 2 == 1):
		return int(f) + 1
	return int(f)


## A lamp's flicker, a brightness multiplier, mostly 1: a slow waver, an eased dip in each `every`
## slot, and in about half the `stutter_every` slots two or three quick drops.
static func tired_bulb(c: float, seed: float, depth: float = 1.0, every: float = 6.5, stutter_every: float = 19.0) -> float:
	var cs := c + hash(seed * 1.37) * 97.0
	var m := 1.0 + depth * (0.012 * vnoise(cs * 1.3, seed) + 0.008 * vnoise(cs * 3.7, seed + 5.0))
	var ci := floor(cs / every)
	var at := hash(ci * 3.1 + seed) * (every - 1.0)
	var a := cs - ci * every - at
	var ln := 0.25 + hash(ci * 1.7 + seed) * 0.3
	if a > 0.0 and a < ln:
		m *= 1.0 - depth * (0.05 + hash(ci * 5.3 + seed) * 0.06) * sin(PI * a / ln)
	var c2 := floor(cs / stutter_every)
	if hash(c2 * 7.7 + seed * 2.3) < 0.55:
		var a2 := cs - c2 * stutter_every - (1.0 + hash(c2 * 4.9 + seed) * (stutter_every - 2.0))
		if a2 > 0.0 and a2 < 0.34:
			var n3 := hash(c2 * 2.2 + seed) < 0.5
			if a2 < 0.05:
				m *= 1.0 - depth * 0.28
			elif a2 > 0.1 and a2 < 0.14:
				m *= 1.0 - depth * 0.16
			elif n3 and a2 > 0.22 and a2 < 0.26:
				m *= 1.0 - depth * 0.1
	return m


## Dust in the air (`drawDust`): each mote's envelope times its gain, summed into `img` (RGF, W x H):
## R at the mote, G at the pixel right of a two-pixel fleck (its light is read at the mote). The
## shader multiplies by the light there, as the page does. `skip(x, y)` is the glass.
static func dust(motes: Array, img: Image, c: float, fade: float, glass: Rect2i) -> void:
	img.fill(Color(0, 0, 0, 0))
	for m: Dictionary in motes:
		var life: float = m.life
		var age := fposmod(c + float(m.off), life)
		var p := age / life
		var env := pow(sin(PI * p), 1.6) * fade
		if env < 0.02:
			continue
		var x := jround(float(m.x) + float(m.vx) * age + float(m.ax) * sin(age * 6.283 / float(m.px) + float(m.ph)))
		var y := jround(float(m.y) + float(m.vy) * age + 0.6 * sin(age * 6.283 / (float(m.px) * 1.7) + float(m.ph) * 2.0))
		if x < 0 or y < 0 or x >= W - 1 or y >= H:
			continue
		if glass.has_point(Vector2i(x, y)):
			continue
		var e := env * float(m.gain)
		var cur := img.get_pixel(x, y)
		img.set_pixel(x, y, Color(cur.r + e, cur.g, 0, 0))
		if bool(m.fleck) and not glass.has_point(Vector2i(x + 1, y)):
			var c2 := img.get_pixel(x + 1, y)
			img.set_pixel(x + 1, y, Color(c2.r, c2.g + e, 0, 0))


static func _sky_base(o: Dictionary, i: int) -> Vector3:
	var x := i % W
	var y := i / W
	var dn := Vector2(x - (float(o.cx) - 5.0), y - (float(o.cy) + 5.0)).length()
	var neb := 0.5 if dn < 5.0 else (0.5 if dn < 9.0 and bay(x, y) < 0.5 else 0.0)
	return Vector3(5.0 + neb * 9.0, 8.0 + neb * 6.0, 18.0 + neb * 14.0)


## The living porthole (`drawSky`): parallax stars, twinkle, a moon now and then, rare passers-by.
## Writes the window's pixels into `img` (RGBA8) at their place less `org`.
static func sky(k: Dictionary, img: Image, org: Vector2i, c: float, f: float = 1.0) -> void:
	var o: Dictionary = k.o
	var idx: Array = o.idx
	var on: Dictionary = k.set
	var s: float = k.S
	var cx: float = o.cx
	var cy: float = o.cy
	var r: float = o.r
	var ox := cx - s / 2.0
	var oy := cy - s / 2.0
	var col := {}
	for i: int in idx:
		col[i] = _sky_base(o, i)
	var mp := 150.0
	var mc := floor(c / mp)
	var ma := c - mc * mp - 100.0
	var moon := {}
	if ma > 0.0 and ma < 50.0:
		var kk := sin(PI * ma / 50.0)
		var dir := 1.0 if hash(mc * 3.3 + 1.0) < 0.5 else -1.0
		var dd := 26.0 + r + 3.0 - kk * 11.0
		moon = {x = jround(cx + dir * 0.6 * dd), y = jround(cy + 0.8 * dd), R = 26.0, dir = dir}
	for st: Dictionary in k.stars:
		var x := jround(ox + fposmod(float(st.x) - c * float(st.spd), s))
		var y := jround(oy + fposmod(float(st.y) + c * float(st.spd) * 0.3, s))
		if not moon.is_empty() and Vector2(x - int(moon.x), y - int(moon.y)).length() < float(moon.R):
			continue
		var v: float = st.b
		if bool(st.tw):
			var n := floor(c / float(st.per) + float(st.ph))
			var hh := hash(n * 13.1 + float(st.x) * 3.0 + float(st.y))
			v *= 0.45 if hh < 0.18 else (0.85 if hh < 0.7 else 1.12)
		v = minf(1.1, v)
		var warm: bool = float(st.tint) < 0.2
		var blue: bool = float(st.tint) > 0.85
		_set(col, on, x, y, Vector3(30.0 + 215.0 * v * (1.0 if warm else 0.92), 34.0 + 205.0 * v * (0.86 if warm else 0.95),
			46.0 + 200.0 * v * (1.05 if blue else (0.7 if warm else 1.0))))
	if not moon.is_empty():
		for i: int in idx:
			var x := i % W
			var y := i / W
			var dx := float(x - int(moon.x))
			var dy := float(y - int(moon.y))
			var d := Vector2(dx, dy).length()
			if d >= float(moon.R):
				continue
			var lit := (-dx * 0.6 - dy * 0.8) / float(moon.R)
			var md: float = moon.dir
			var sea := Vector2(dx + 8.0 * md, dy + 12.0).length() < 5.0 or Vector2(dx + 2.0 * md, dy + 19.0).length() < 3.5
			var cc: Vector3
			if d > float(moon.R) - 1.5 and lit > 0.1:
				cc = Vector3(196, 200, 206)
			elif lit > 0.25 + (bay(x, y) - 0.5) * 0.12:
				cc = Vector3(92, 96, 106) if sea else Vector3(128, 132, 140)
			elif lit > 0.05:
				cc = Vector3(54, 58, 70) if sea else Vector3(74, 78, 90)
			else:
				cc = Vector3(16, 19, 28)
			col[i] = cc
	_passers(col, on, o, c, not moon.is_empty())
	for i: int in col:
		var v3: Vector3 = col[i]
		img.set_pixel(i % W - org.x, i / W - org.y, Color8(u8(minf(255.0, v3.x) * f), u8(minf(255.0, v3.y) * f), u8(minf(255.0, v3.z) * f)))


static func _set(col: Dictionary, on: Dictionary, x: int, y: int, c: Vector3) -> void:
	var i := y * W + x
	if on.has(i):
		col[i] = c


static func _add(col: Dictionary, on: Dictionary, o: Dictionary, x: int, y: int, c: Vector3) -> void:
	var i := y * W + x
	if not on.has(i):
		return
	var b: Vector3 = col[i] if col.has(i) else _sky_base(o, i)
	col[i] = b + c


static func _along(o: Dictionary, k: float, y0: float, slope: float, dir: float) -> Vector2i:
	var r: float = o.r
	return Vector2i(jround(float(o.cx) + dir * (-r - 2.0 + (2.0 * r + 4.0) * k)), jround(y0 + slope * k))


## One passer-by per 12 s slot at most: a far ship, tumbling debris, or a slow meteor.
static func _passers(col: Dictionary, on: Dictionary, o: Dictionary, c: float, moon: bool) -> void:
	var p := 12.0
	var sn := floor(c / p)
	var st := c - sn * p
	var kh := hash(sn * 5.7 + 2.0)
	var cy: float = o.cy
	var r: float = o.r
	if not moon and kh < 0.3:
		var k := st / 9.0
		if k < 1.0:
			var dir := 1.0 if hash(sn * 2.9) < 0.5 else -1.0
			var q := _along(o, k, cy - 6.0 + hash(sn * 4.3) * 10.0, 4.0 - hash(sn) * 8.0, dir)
			var red := fmod(st, 1.3) < 0.22
			_set(col, on, q.x, q.y, Vector3(255, 84, 70) if red else Vector3(196, 206, 222))
			if not red:
				_add(col, on, o, q.x - int(dir), q.y, Vector3(26, 30, 38))
	elif kh < 0.55:
		var k := st / 10.0
		if k < 1.0:
			var dir := 1.0 if hash(sn * 3.1) < 0.5 else -1.0
			var q := _along(o, k, cy - 8.0 + hash(sn * 6.1) * 14.0, 3.0 - hash(sn * 2.0) * 6.0, dir)
			var tum := fposmod(st, 1.4)
			var flash := 1.0 if tum < 0.12 else (0.55 if tum < 0.25 else 0.18)
			var cv := 60.0 + 190.0 * flash
			_set(col, on, q.x, q.y, Vector3(cv, cv * 0.97, cv * 0.9))
			if tum > 0.7:
				_set(col, on, q.x + 1, q.y, Vector3(70, 68, 64))
			else:
				_set(col, on, q.x, q.y + 1, Vector3(52, 50, 48))
	elif kh < 0.66 and not moon:
		var a := st - 4.0 - hash(sn * 8.1) * 4.0
		if a > 0.0 and a < 0.9:
			var k := a / 0.9
			var dir := 1.0 if hash(sn * 1.3) < 0.5 else -1.0
			var hx := float(o.cx) + dir * (-r + 2.0 * r * k)
			var hy := cy - r * 0.6 + r * 1.1 * k
			for tl in 4:
				var v := (1.0 - tl / 4.0) * pow(sin(PI * k), 0.5)
				_add(col, on, o, jround(hx - dir * tl * 1.4), jround(hy - tl * 0.8), Vector3(210.0 * v, 215.0 * v, 200.0 * v))
