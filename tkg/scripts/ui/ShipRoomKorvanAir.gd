class_name ShipRoomKorvanAir
extends RefCounted

## Korvan's air (hero.py): the shafts and the motes in them, added behind the hulls as the film did,
## and the finish over everything under the banners: sheen, haze, bloom.
## Why: docs/why/ShipRoomKorvan.md#air

const F := preload("res://scripts/ui/ShipRoomKorvanFilm.gd")

var life: ShipRoomKorvanLife
var _shafts: ColorRect
var _motes: ShipRoomKorvanPaint
var _post: ColorRect
var _add_mat: ShaderMaterial
var _mote_mat: ShaderMaterial
var _post_mat: ShaderMaterial


func _init(l: ShipRoomKorvanLife) -> void:
	life = l


func _mat(sh: Shader, mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"air0", ShipRoom.tex(&"korvan", "air0.png"))
	m.set_shader_parameter(&"air1", ShipRoom.tex(&"korvan", "air1.png"))
	return m


## The shafts and motes, on the layer `life` is filling now (under, before the girder).
func build_under(c: Control) -> void:
	var sh := preload("res://shaders/ship_room_korvan_air.gdshader")
	_add_mat = _mat(sh, 0)
	_mote_mat = _mat(sh, 1)
	_shafts = ColorRect.new()
	_shafts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shafts.size = Vector2(960, 540)
	_shafts.material = _add_mat
	c.add_child(_shafts)
	_motes = life.paint(ShipRoomKorvanPaint.Blend.UNLIT)
	_motes.material = _mote_mat


## The finish, last in `above`: a fresh copy of the screen, then the pass that reads it.
func build_post(c: Control) -> void:
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	c.add_child(bb)
	_post_mat = _mat(preload("res://shaders/ship_room_korvan_post.gdshader"), 0)
	_post_mat.set_shader_parameter(&"atlas", life.atlas)
	_post = ColorRect.new()
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.size = Vector2(960, 540)
	_post.material = _post_mat
	c.add_child(_post)


func draw(t: float, u: Dictionary[StringName, Variant]) -> void:
	var op := F.opening(F.win(t, F.DOOR_AT))
	for m in [_add_mat, _mote_mat]:
		for n: StringName in [&"tw", &"lk", &"crane", &"drone_load"]:
			(m as ShaderMaterial).set_shader_parameter(n, u[n])
		(m as ShaderMaterial).set_shader_parameter(&"op", op)
	for mt: Array in F.D["motes"]:
		var x := float(mt[0]) + 6.0 * sin(TAU * t / 30.0 + float(mt[2]))
		var y := float(mt[1]) + 4.0 * sin(TAU * 2.0 * t / 30.0 + float(mt[3]))
		var xi := int(floorf(float(int(x)) / 2.0)) * 2
		var yi := int(floorf(float(int(y)) / 2.0)) * 2
		if xi >= 0 and xi < 959 and yi >= 0 and yi < 539:
			var g := 0.6 + 0.4 * sin(TAU * 3.0 * t / 30.0 + float(mt[2]) + float(mt[3]))
			_motes.rect(xi, yi, 2, 1, Color(g, 0, 0))
	_crane_mask(t)


## The crane stays crisp in the haze (mix18: K 0.17 where it is drawn): its pieces' rects for the pass.
func _crane_mask(t: float) -> void:
	var cr := F.crane(t)
	var K := F.K
	var rects := PackedVector4Array()
	var srcs := PackedVector4Array()
	var boxes := PackedVector4Array()
	var add := func(n: String, x: int, y: int) -> void:
		var s := life.src(n)
		rects.append(Vector4(x, y, s.size.x, s.size.y))
		srcs.append(Vector4(s.position.x, s.position.y, 0, 0))
	add.call("part%d_half" % cr.part, cr.lx, cr.ly)
	var tw := int(K["trolley_w"])
	add.call("trolley_half", cr.x - tw / 2, int(K["trolley_y"]))
	var bt := int(K["trolley_y"]) + int(K["trolley_h"]) + 1
	boxes.append(Vector4(F.pyround(cr.x + cr.sway * 0.25) - 8, bt, 17, 19))
	boxes.append(Vector4(cr.lx + 5, cr.ly - 12, cr.lw - 10, 5))
	var d := F.drones(t)
	if d != null:
		add.call(String(d.load), d.xc - d.lw / 2, d.ly)
		for dp in d.d:
			boxes.append(Vector4(dp.x - 15, dp.y, 30, 9))
	while rects.size() < 4:
		rects.append(Vector4.ZERO)
		srcs.append(Vector4.ZERO)
	while boxes.size() < 4:
		boxes.append(Vector4.ZERO)
	_post_mat.set_shader_parameter(&"m_rect", rects)
	_post_mat.set_shader_parameter(&"m_src", srcs)
	_post_mat.set_shader_parameter(&"m_box", boxes)
