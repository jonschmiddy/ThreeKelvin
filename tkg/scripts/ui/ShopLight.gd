class_name ShopLight
extends RefCounted

## Ported line for line from the room bench (`tools/room_bench.tmpl.html`), where Jon judged them.
## Runs on the room's 30 Hz clock, the rate the faults were shaped for.
## Why: docs/why/ShopLight.md#shop-light

const MUL := preload("res://shaders/shop_light_mul.gdshader")
const ADD := preload("res://shaders/shop_light_add.gdshader")

## One redraw, in seconds: the finest thing a fault can do (the bench's `FR`).
const FR := 0.033
## How long a starter's burst of strikes lasts, in seconds (`BURST`).
const BURST := 0.62


## A repeatable scatter in 0..1 (`hash1`).
static func hash1(v: float) -> float:
	return UIHash.hash1(v)


static func _vnoise(x: float) -> float:
	var i0 := floorf(x)
	var f := x - i0
	f = f * f * (3.0 - 2.0 * f)
	var a := hash1(i0 * 1.37 + 0.11)
	var b := hash1((i0 + 1.0) * 1.37 + 0.11)
	return a + (b - a) * f


static func _fnoise(x: float) -> float:
	return 0.58 * _vnoise(x) + 0.29 * _vnoise(x * 2.13 + 11.7) + 0.13 * _vnoise(x * 4.71 + 3.19)


## Seconds since this lamp last misbehaved, or a big number (`lastEvent`).
static func _last_event(ts: float, every: float, seed: float, p: float) -> float:
	if not (every > 0.0):
		return 1.0e9
	var k := floorf(ts / every)
	for n in 40:
		if hash1(k * 1.618 + seed * 2.7) <= p:
			var at := (k + 0.05 + 0.9 * hash1(k * 3.77 + seed)) * every
			if at <= ts:
				return ts - at
		k -= 1.0
	return 1.0e9


static func _shape_strike(u: float, per: float, seed: float) -> float:
	var e := u * per
	if e < BURST:
		var fr := floorf(e / FR)
		var h := hash1(fr * 1.37 + seed * 3.1)
		return 1.0 if h < 0.42 else (0.55 if h < 0.52 else 0.04)
	return 1.0 if hash1(floorf(seed * 11.0) * 0.77 + floorf(e / per + 0.5)) < 0.45 else 0.05


## Returns a Color, as a packed array handed to a function is the function's own copy.
static func flicker_at(mode: int, t_ms: float, x: float, y: float, rate0: float) -> Color:
	if mode == 0:
		return Color(1.0, 1.0, 1.0, 1.0)
	var seed := hash1(floorf(x + 0.5) * 0.7131 + floorf(y + 0.5) * 2.9173) * 37.0
	var rate := 1.0 + 0.5 * (hash1(seed * 1.77 + 7.3) - 0.5)
	if rate0 > 0.0:
		rate = rate0 * (1.0 + 0.08 * (hash1(seed * 3.31 + 1.7) - 0.5))
	var ts := t_ms / 1000.0 + seed * 3.9
	match mode:
		1:
			# STARTER -- a burst of hard strikes, then held lit or dark.
			var per := 5.5 / rate
			var u := ts / per
			var uu := u - floorf(u)
			var v := _shape_strike(uu, per, seed)
			if v > 0.3 and uu * per < BURST:
				return Color(0.78, 0.93, 1.30, v)
			return Color(1.0, 1.0, 1.0, v)
		2:
			# FLUTTER -- a tube at the end of its life, surging pink.
			var slow := _fnoise(ts * 2.6 * rate)
			var fast := _fnoise(ts * 6.1 * rate + 11.3)
			var v2 := 0.76 - 0.34 * slow + 0.20 * (fast - 0.5)
			v2 *= 0.94 + 0.06 * hash1(floorf(ts / FR) * 1.7 + seed)
			v2 = clampf(v2, 0.20, 1.0)
			var d := minf(1.0, (1.0 - v2) * 1.35)
			return Color(1.0 + 0.42 * d, 1.0 - 0.34 * d, 1.0 + 0.16 * d, v2)
		3:
			# LOOSE -- dead steady, then gone for a frame.
			var e3 := _last_event(ts, 3.2 / rate, seed, 0.5)
			var fr3 := floorf(e3 / FR + 0.5)
			var v3 := 1.0
			if fr3 == 0.0:
				v3 = 0.02
			elif fr3 <= 2.0 and hash1(seed * 5.1 + 0.7) > 0.55:
				v3 = 0.9 if fr3 == 1.0 else 0.03
			return Color(1.0, 1.0, 1.0, v3)
		_:
			# COOLING -- a filament losing its heat, going orange.
			var e4 := _last_event(ts, 6.0 / rate, seed, 0.6)
			var v4 := 1.0
			if e4 > 4.4:
				v4 = 1.0
			elif e4 < 0.9:
				v4 = 1.0 - 0.86 * pow(e4 / 0.9, 0.75)
			else:
				v4 = 0.14 + 0.86 * pow(minf(1.0, (e4 - 0.9) / 3.5), 1.7)
			v4 = clampf(v4, 0.12, 1.0)
			var d4 := minf(1.0, (1.0 - v4) * 1.1)
			return Color(1.0 + 0.20 * d4, 1.0 - 0.42 * d4, 1.0 - 0.78 * d4, v4)


## `#rrggbb` as three 0..1 floats.
static func rgb_of(col: String) -> Vector3:
	var c := Color(col)
	return Vector3(c.r, c.g, c.b)


# ------------------------------------------------------------------ the layers

## Above the rack and counter: the bench lights them with everything else in the room.
class Overlay extends Control:
	var mul: ColorRect
	var add: ColorRect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for sh in [MUL, ADD]:
			var r := ColorRect.new()
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mat := ShaderMaterial.new()
			mat.shader = sh
			r.material = mat
			add_child(r)
			if sh == MUL:
				mul = r
			else:
				add = r

	## Size both passes to the room and hand them its light.
	func setup(rect: Rect2, params: Dictionary) -> void:
		for r in [mul, add]:
			var cr: ColorRect = r
			cr.position = rect.position
			cr.size = rect.size
			var mat: ShaderMaterial = cr.material
			for k in params:
				mat.set_shader_parameter(k, params[k])

	func set_param(k: StringName, v: Variant) -> void:
		for r in [mul, add]:
			((r as ColorRect).material as ShaderMaterial).set_shader_parameter(k, v)


## Shop marks stay readable however dark the room (option 4A of the port plan).
## `lit_marks = false` on the shop restores the bench's behaviour.
## Why: docs/why/ShopLight.md#shop-marks
class Glow extends Control:
	var shop: ShopScene

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if shop != null and is_instance_valid(shop):
			shop._draw_glow(self)
