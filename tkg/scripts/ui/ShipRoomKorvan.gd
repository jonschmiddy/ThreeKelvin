class_name ShipRoomKorvan
extends ShipRoom

## Korvan's Parts depot (Jon, Nov 24: mix18 approved): the steel hall under its tubes, lit as
## its film was, with the film's life on the film's 30 s clock.
## Why: docs/why/ShipRoomKorvan.md#light

const SHADER := preload("res://shaders/ship_room_korvan.gdshader")
const LIGHT_TEX := 8
const DYN_TEX := 4

var _mats: Array[ShaderMaterial] = []
var _room_mat: ShaderMaterial
var _post_mat: ShaderMaterial
var _hull_mat: ShaderMaterial
var _life_mat: ShaderMaterial
var _light := ShipRoomKorvanLight.new()
var life: ShipRoomKorvanLife
var back: ShipRoomKorvanBack
var front: ShipRoomKorvanFront
var air: ShipRoomKorvanAir
var _shown := -1
var _sent: Dictionary[StringName, Variant] = {}


func hull_amb() -> float:
	return 0.6


func band_colour() -> Color:
	return Color8(14, 16, 22)


func _build() -> void:
	_room_mat = _korvan_mat(0)
	_post_mat = _korvan_mat(1)
	_hull_mat = _korvan_mat(2)
	_life_mat = _korvan_mat(3)
	(under.get_child(0) as CanvasItem).material = _room_mat
	life = ShipRoomKorvanLife.new(_life_mat)
	back = ShipRoomKorvanBack.new(life)
	life.on(under)
	back.build_edits()
	air = ShipRoomKorvanAir.new(life)
	air.build_under(under)
	back.build()
	front = ShipRoomKorvanFront.new(life)
	life.on(above)
	front.build(air)
	air.build_post(above)
	_tick(0.0)


func _korvan_mat(m: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"mode", m)
	mat.set_shader_parameter(&"albedo", tex(id, "albedo.png"))
	mat.set_shader_parameter(&"emissive", tex(id, "emissive.png"))
	for i in LIGHT_TEX:
		mat.set_shader_parameter(StringName("lt%d" % i), tex(id, "light%d.png" % i))
	for i in DYN_TEX:
		mat.set_shader_parameter(StringName("dy%d" % i), tex(id, "dyn%d.png" % i))
	_mats.append(mat)
	return mat


func hull_material() -> Material:
	return _hull_mat


func thing_material() -> Material:
	return _post_mat


## The material a piece of the room's life is lit with (`ShipRoomKorvanLife`).
func life_material() -> Material:
	return _life_mat


func _placed() -> void:
	var posts: Array[Vector4] = []
	for st: Variant in sets:
		var s := st as YardStandSet
		if s == null:
			continue
		for x: int in s.post_x:
			posts.append(Vector4(x, s.post_top, s.post_w, s.feet - s.post_top))
	while posts.size() < 6:
		posts.append(Vector4(-9999, -9999, 0, 0))
	_uniform(&"posts", posts)
	for st: Variant in sets:
		_hull_rows(st as YardStandSet)


## The film lit a hull's rows from its top to its foot with its guns on (hull_light's r0, r1), and its
## guns as part of it: the view and every gun drawn with its material get those rows.
func _hull_rows(s: YardStandSet) -> void:
	if s == null or s._view == null:
		return
	var at := Vector2i(s.position + s._view.position)
	var pics: Array = s.mounts.gun_pictures_canvas() if s.mounts != null else []
	var used := Rect2(s._view.canvas().get_used_rect())
	for p: Array in pics:
		var img: Image = p[1]
		if img != null:
			var r: Rect2 = p[0]
			var k := r.size / Vector2(img.get_size())
			var u := Rect2(img.get_used_rect())
			used = used.merge(Rect2(r.position + u.position * k, u.size * k))
	var rows := Vector2(at.y + floorf(used.position.y), at.y + ceilf(used.end.y) - 1)
	var todo: Array[Node] = [s._view]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is CanvasItem:
			(n as CanvasItem).set_instance_shader_parameter(&"rows", rows)
		todo.append_array(n.get_children())


func _uniform(n: StringName, v: Variant) -> void:
	# each set is a call into the renderer: only what changed since the last frame is sent
	if _sent.has(n) and _sent[n] == v:
		return
	_sent[n] = v
	for m in _mats:
		m.set_shader_parameter(n, v)


## The film frame on show: the room's clock snapped to the film's 30 fps, wrapped at its 30 s.
func frame() -> int:
	return ShipRoomKorvanFilm.pyround(t * 30.0) % ShipRoomKorvanFilm.NF


func _tick(_dt: float) -> void:
	var f := frame()
	if f == _shown:
		return
	_shown = f
	_light.build(f)
	for n: StringName in _light.u:
		_uniform(n, _light.u[n])
	life.clear_all()
	back.draw(f, float(f) / 30.0, float(_light.u[&"lk"]))
	front.draw(f, float(f) / 30.0)
	air.draw(float(f) / 30.0, _light.u)
