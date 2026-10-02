class_name ShatteredView
extends Node2D

## A WORLD IN PIECES on screen: rubble behind, the nine pieces and the molten
## heart (`shattered.gdshader`), rubble in front. Jon's pick, "Shards".
##
## The pieces' seed points and the rubble come from the world's seed through the
## mockup's own generator, in its order of draws, so it breaks the same way.

const SHADER := preload("res://shaders/shattered.gdshader")
const K := 9
const PUSH := 0.5
const SCALE := 0.64
const CORE := 0.24
const RUBBLE := 60

var spec: Dictionary = {}
var _disc: ColorRect
var _mat: ShaderMaterial
var _back: _Rubble
var _front: _Rubble
var _rub: Array = []
var _t: float = 0.0
var _light: Vector3 = Vector3(-0.83, -0.31, 0.47)


## Rubble wheeling outward round the pieces: small motes lit by the core, big
## lumps dark with their face toward the middle lit.
class _Rubble extends Node2D:
	var view: ShatteredView
	var front: bool = false
	## 2 on the map: each rubble pixel a 2x2 block on the place's grid
	var block := 1

	func _draw() -> void:
		var v := view
		if v.spec.is_empty():
			return
		var r: float = v.spec.r * SCALE
		var reach := 1.0 + PUSH * 1.15
		for q in v._rub:
			var u := fmod(q.u0 + v._t * q.spd, 1.0)
			var fade := (1.0 - u) / 0.15 if u > 0.85 else (u / 0.08 if u < 0.08 else 1.0)
			var rad := (reach * 0.85 + u * 0.9) * r
			var P: Vector3 = q.p * rad
			if (P.z >= 0.0) != front:
				continue
			var ix := roundi(P.x)
			var iy := roundi(P.y)
			var dc := maxf(0.001, Vector2(P.x, P.y).length())
			var near := 1.0 / (1.0 + pow(dc / (r * 1.2), 2.0))
			for o: Vector2i in q.shape:
				var c: Color
				if not q.big:
					c = Worlds.ramp_color(&"glow", (0.1 + near * 0.3) * fade, ix + o.x, iy + o.y)
				else:
					var facing := -(o.x * P.x + o.y * P.y) / dc
					if facing > q.sz * 0.5:
						c = Worlds.ramp_color(&"glow", (0.4 + near * 0.5) * fade, ix + o.x, iy + o.y)
					else:
						c = Color("#262a34") if facing > 0.0 else Color("#15171d")
				var at := Vector2(ix + o.x, iy + o.y)
				if block > 1:
					at = ((global_position + at) / float(block)).floor() * float(block) - global_position
				draw_rect(Rect2(at, Vector2.ONE * block), c)


func _init() -> void:
	_back = _Rubble.new()
	_back.view = self
	add_child(_back)
	_disc = ColorRect.new()
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_disc.material = _mat
	add_child(_disc)
	_front = _Rubble.new()
	_front.view = self
	_front.front = true
	add_child(_front)


## THE MAP'S WORLDS IN 2x2 BLOCKS: the disc's own dither, and the rings or
## rubble round it, on the place's grid. The panel's portrait stays at 1.
func set_cell(c: int) -> void:
	_mat.set_shader_parameter("cell", c)
	_back.block = c
	_front.block = c


func set_world(world: StringName, seed: int, r: float, _over: Dictionary = {}) -> void:
	spec = Worlds.spec(world, seed, r)
	var R := Worlds.XRng.new(floor(spec.seed * 37.0) + 5.0)
	var seeds := PackedVector3Array()
	for i in K:
		var p := Worlds.sphere_rand(R)
		var d := 0.4 + R.next() * 0.25
		seeds.append(p * d)
	for i in K:
		R.next()
	_rub.clear()
	for i in RUBBLE:
		var big := i < RUBBLE * 0.35
		var sz := 1.2 + R.next() * 2.2 if big else 0.0
		var shape: Array[Vector2i] = []
		if big:
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var a := atan2(dy, dx)
					var rr := sz * (0.8 + 0.3 * sin(a * 3.0 + i) + 0.15 * sin(a * 5.0 + i * 2))
					if dx * dx + dy * dy <= rr * rr:
						shape.append(Vector2i(dx, dy))
		else:
			shape.append(Vector2i.ZERO)
		var p2 := Worlds.sphere_rand(R)
		var u0 := R.next()
		var off := R.next() + R.next() - 1.0
		var spd := 0.01 + R.next() * 0.02
		var z := R.next() - 0.5
		_rub.append({"p": p2, "u0": u0, "off": off, "spd": spd, "z": z, "big": big, "sz": sz, "shape": shape})
	var rs := r * SCALE
	var G := int(ceil(rs * (1.0 + PUSH * 1.15) * 1.6)) + 4
	_disc.position = Vector2(-G, -G)
	_disc.size = Vector2(2 * G + 1, 2 * G + 1)
	var m := _mat
	m.set_shader_parameter("ramps", Worlds.ramp_texture())
	m.set_shader_parameter("seeds", seeds)
	m.set_shader_parameter("k_count", K)
	m.set_shader_parameter("r", rs)
	m.set_shader_parameter("half_size", G)
	m.set_shader_parameter("push", PUSH)
	m.set_shader_parameter("core_r", CORE)
	m.set_shader_parameter("spin", spec.spin)
	m.set_shader_parameter("seed", spec.seed)


func step(t: float, light: Vector3, k_light: float = 1.0, star_at: Vector2 = Vector2(-9999, -9999), star_r: float = 0.0) -> void:
	_t = t
	_light = light.normalized()
	_mat.set_shader_parameter("time", t)
	_mat.set_shader_parameter("light", _light)
	_mat.set_shader_parameter("k_light", k_light)
	_mat.set_shader_parameter("centre", position)
	_mat.set_shader_parameter("star_at", star_at)
	_mat.set_shader_parameter("star_r", star_r)
	_back.queue_redraw()
	_front.queue_redraw()
