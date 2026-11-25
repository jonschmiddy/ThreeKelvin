class_name ShipRoomOld
extends ShipRoom

## The Old hangar's mothball racks (Jon, Nov 24: A16 approved, A17's lamp): a locked manufacturer's tarps
## under one failing sodium lamp, lit as two layers (ambient, and the lamp x its level).
## Why: docs/why/ShipRoomOld.md#two-layers

## The film's loop: the lamp's schedule, the wind and the dust all run on it (each seamless at the wrap).
const LOOP := 10.0
const FPS := 30.0
## The lamp's long outages: (start s, seconds out, the frames of the stutter back on).
const OFFS := [[2.05, 0.75, [1.0, 1.0, 0.03, 0.03, 1.0, 0.05, 1.0, 1.0, 0.04]],
	[5.55, 1.30, [1.0, 0.03, 0.03, 1.0, 1.0, 0.05, 0.05, 0.05, 1.0, 0.06]]]
## Its flickers: (start s, one level a frame at 30 fps).
const BURSTS := [[1.30, [0.08, 0.08, 1, 1, 1, 0.10, 1, 1, 0.06, 0.06, 0.06, 1, 1, 0.12, 1, 1, 1, 1, 0.08, 0.08]],
	[3.10, [0.10, 0.10]],
	[4.70, [0.07, 1, 1, 0.10, 0.10, 1, 0.08, 0.08]],
	[7.40, [0.10, 0.10, 1, 0.06, 1, 1, 1, 0.10, 0.10, 0.10, 1, 1, 0.08, 1, 1, 0.12, 0.12, 1, 1, 1, 0.06, 0.06]],
	[8.90, [0.08]]]

## A dead hose's sprite corner from where it leaves its post (stands8.dead_hose: 9 px out from the
## post's middle, 40 rows over its feet), left post's hose and right post's.
const HOSE_AT := {-1: Vector2i(-27, -1), 1: Vector2i(4, -1)}

var _level := 1.0
var _dust: Array[ShaderMaterial] = []


func hull_amb() -> float:
	return 0.35


func tuck() -> int:
	return 4


func band_colour() -> Color:
	return Color8(9, 8, 7)


func _build() -> void:
	var sh := preload("res://shaders/ship_room_old.gdshader")
	for m: ShaderMaterial in [_mat_room, _mat_thing, _mat_hull]:
		m.shader = sh
		m.set_shader_parameter(&"albedo", tex(id, "albedo.png"))
		m.set_shader_parameter(&"amb", tex(id, "amb.png"))
		m.set_shader_parameter(&"lamp", tex(id, "lamp.png"))
		m.set_shader_parameter(&"emissive", tex(id, "emissive.png"))
	# the far dust hangs behind the stands and tarps; the near dust in front of them, under the banners
	under.add_child(_motes("motes_back.png"))
	above.add_child(_motes("motes_front.png"))
	_tick(0.0)


## The dust: one instance a mote, its track in the texture (one row each), placed by its shader.
## Why: docs/why/ShipRoomOld.md#dust
func _motes(file: String) -> Control:
	var c := Motes.new()
	var tx := tex(id, file)
	if tx == null:
		return c
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)])
	a[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = mesh
	mm.instance_count = tx.get_height()
	mm.custom_aabb = AABB(Vector3.ZERO, Vector3(W, H, 0))
	for i in mm.instance_count:
		mm.set_instance_transform_2d(i, Transform2D.IDENTITY)
	c.mm = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ship_room_old_motes.gdshader")
	m.set_shader_parameter(&"motes", tx)
	c.material = m
	_dust.append(m)
	return c


## Each tarp takes its dusty, padded wind texture (`export.py`), stencilled as its art is (`TarpMark`);
## a manufacturer with none wears Solari's. Each post gets its dead hose, over the post and under the tarp.
## Why: docs/why/ShipRoomOld.md#hoses
func _placed() -> void:
	for st: Variant in sets:
		var s := st as YardStandSet
		if s == null:
			continue
		_hoses(s)
		if s._tarp == null or s._tarp.texture == null:
			continue
		var dir := (DIR % String(id)) + "tarps/"
		var wt := TarpMark.texture(dir + s._tarp.file.get_file(), YardStandSet.Tarp.WIND_PAD)
		if wt == null:
			wt = TarpMark.texture(dir + "solari_%s.png" % YardStandSet.TARP_WEIGHT[s.weight], YardStandSet.Tarp.WIND_PAD)
		s._tarp.set_wind(wt)


func _hoses(s: YardStandSet) -> void:
	for i in s.post_x.size():
		var side := -1 if i == 0 else 1
		var tx := tex(id, "hose_l.png" if side < 0 else "hose_r.png")
		if tx == null:
			continue
		var off: Vector2i = HOSE_AT[side]
		var at := Vector2i(s.post_x[i] + s.post_w / 2 + side * 9, s.feet - 40) + off
		var tr := TextureRect.new()
		tr.texture = tx
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.material = thing_material()
		tr.position = Vector2(at) - s.position
		s.add_child(tr)
		if s._tarp != null:
			s.move_child(tr, s._tarp.get_index())


## The lamp's level `u` seconds into the loop: out is out (0), the stutters and flickers are
## whole frames at 30 fps, and a steady lamp hums +-3 %.
## Why: docs/why/ShipRoomOld.md#the-lamp
static func lamp_at(u: float) -> float:
	return lamp_step(u) * (1.0 + 0.018 * sin(TAU * 3.0 * u / LOOP) + 0.012 * sin(TAU * 7.0 * u / LOOP + 1.0))


## The lamp's step `u` into the loop, without the steady hum: 0 out, under 1 a flicker or a stutter, 1 lit.
static func lamp_step(u: float) -> float:
	for o: Array in OFFS:
		var t0 := float(o[0])
		var ln := float(o[1])
		if u >= t0 and u < t0 + ln:
			return 0.0
		var back: Array = o[2]
		var k := int(roundf((u - t0 - ln) * FPS))
		if k >= 0 and k < back.size():
			return float(back[k])
	var f := 1.0
	for b: Array in BURSTS:
		var steps: Array = b[1]
		var k := int(roundf((u - float(b[0])) * FPS))
		if k >= 0 and k < steps.size():
			f = float(steps[k])
	return f


## The lamp as it is drawn this frame (its schedule times a launch's beat): what its hum follows.
func level() -> float:
	return _level


func _tick(_dt: float) -> void:
	var u := fmod(t, LOOP)
	_level = lamp_at(u) * lamp_k
	for m: ShaderMaterial in [_mat_room, _mat_thing, _mat_hull]:
		m.set_shader_parameter(&"level", _level)
		m.set_shader_parameter(&"t", u)
	var f := int(floor(u * FPS + 0.0001)) % int(LOOP * FPS)
	for m in _dust:
		m.set_shader_parameter(&"frame", f)
		m.set_shader_parameter(&"level", _level)


## The dust's one draw: every mote at once (`ship_room_old_motes.gdshader` moves them).
class Motes extends Control:
	var mm: MultiMesh = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(ShipRoom.W, ShipRoom.H)

	func _draw() -> void:
		if mm != null:
			draw_multimesh(mm, null)
