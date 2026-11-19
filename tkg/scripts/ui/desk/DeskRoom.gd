class_name DeskRoom
extends Control

## One science desk room drawn as the approved page draws it: the room lit at art size (384 x 216) in
## its own viewport by the room's shader, then scaled to the window through the tube (`desk_tube`),
## which reads the canvas the page would have drawn (5x art, the CRT's scanlines). The room's clocks
## and small layers are its life (`DeskOne`); the bake is `tools/desk/dump_desk.py`'s.
## Why: docs/why/DeskScene.md#the-plan

const BAKE_DIR := "res://art/desk/bake/%s/"
const ART := Vector2i(384, 216)
const GLASS := Vector2i(150, 140)
## The page's canvas: what the tube's numbers are in.
const CANVAS := Vector2(1920.0, 1080.0)
const SHADERS := {"desk_1": preload("res://shaders/desk_1.gdshader")}
const MEAN_SHADER := preload("res://shaders/desk_mean.gdshader")
const TUBE_SHADER := preload("res://shaders/desk_tube.gdshader")
const SCREEN := preload("res://art/desk/screen_culture.png")
## What each emitter pixel is (the bake's role plane).
const ROLE_BULB := 1
const ROLE_FILAMENT := 2
const ROLE_GLASS := 8
const ROLE_STRING0 := 16

var id := ""
var meta: Dictionary = {}
var life: DeskOne = null
var _room_vp: SubViewport
var _room_mat: ShaderMaterial
var _mean_vp: SubViewport
var _tube_mat: ShaderMaterial
var _steam_tex: ImageTexture
var _sky_tex: ImageTexture
var _dust_tex: ImageTexture
var _noise_tex: ImageTexture


## The room's bake: meta.json and its planes. Empty when it is missing.
static func load_meta(room: String) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var txt := FileAccess.get_file_as_string((BAKE_DIR % room) + "meta.json")
	var m: Variant = JSON.parse_string(txt) if txt != "" else null
	if m is Dictionary:
		out.assign(m)
	return out


static func plane(room: String, name: String, size: Vector2i, fmt: Image.Format) -> ImageTexture:
	var gz := FileAccess.get_file_as_bytes((BAKE_DIR % room) + name + ".bin.gz")
	var raw := gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var img := Image.create_from_data(size.x, size.y, false, fmt, raw)
	return ImageTexture.create_from_image(img)


func setup(room: String) -> bool:
	id = room
	meta = load_meta(room)
	if meta.is_empty() or not SHADERS.has(room):
		push_error("DeskRoom: no bake for %s" % room)
		return false
	life = DeskOne.new(meta)
	_room_mat = ShaderMaterial.new()
	_room_mat.shader = SHADERS[room]
	var f := Image.FORMAT_RGBAF
	for n: String in ["a2c", "fields", "small_i", "small_v", "px"]:
		_room_mat.set_shader_parameter(n + "_tex", plane(room, n, ART, f))
	_room_mat.set_shader_parameter(&"role_tex", plane(room, "role", ART, Image.FORMAT_RF))
	_room_mat.set_shader_parameter(&"glass_tex", plane(room, "glass", GLASS, f))
	_room_mat.set_shader_parameter(&"title_tex", plane(room, "title", GLASS, f))
	_room_mat.set_shader_parameter(&"screen_tex", SCREEN)
	_steam_tex = ImageTexture.create_from_image(life.steam_img)
	_sky_tex = ImageTexture.create_from_image(life.sky_img)
	_dust_tex = ImageTexture.create_from_image(life.dust_img)
	_room_mat.set_shader_parameter(&"steam_tex", _steam_tex)
	_room_mat.set_shader_parameter(&"sky_tex", _sky_tex)
	_room_mat.set_shader_parameter(&"dust_tex", _dust_tex)
	_noise_tex = ImageTexture.create_from_image(life.noise_img)
	_room_mat.set_shader_parameter(&"noise_tex", _noise_tex)
	_room_vp = _viewport(ART, _room_mat)
	var mean_mat := ShaderMaterial.new()
	mean_mat.shader = MEAN_SHADER
	mean_mat.set_shader_parameter(&"room_tex", _room_vp.get_texture())
	_mean_vp = _viewport(Vector2i(2, 1), mean_mat)
	_tube_mat = ShaderMaterial.new()
	_tube_mat.shader = TUBE_SHADER
	_tube_mat.set_shader_parameter(&"room_tex", _room_vp.get_texture())
	_tube_mat.set_shader_parameter(&"mean_tex", _mean_vp.get_texture())
	_tube_mat.set_shader_parameter(&"tube_scale", float(meta.tubeScale))
	_tube_mat.set_shader_parameter(&"canvas", CANVAS)
	var tube := ColorRect.new()
	tube.material = _tube_mat
	tube.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tube.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tube)
	return true


func _viewport(size: Vector2i, mat: ShaderMaterial) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var r := ColorRect.new()
	r.material = mat
	r.size = Vector2(size)
	vp.add_child(r)
	add_child(vp)
	return vp


## Draw the room at scene time `ts` (backwards while leaving) on the free clock `real`.
func show_at(ts: float, real: float, leaving: bool) -> void:
	if life == null:
		return
	var u := life.frame(ts, real, leaving)
	_steam_tex.update(life.steam_img)
	_sky_tex.update(life.sky_img)
	_dust_tex.update(life.dust_img)
	if life.noise_new:
		_noise_tex.update(life.noise_img)
	for k: StringName in u:
		var v: Variant = u[k]
		match k:
			&"glow_a":
				_room_mat.set_shader_parameter(k, _pad4(v, 8))
				_room_mat.set_shader_parameter(&"glow_n", (v as PackedVector4Array).size())
			&"glow_c":
				_room_mat.set_shader_parameter(k, _v4(v, 8))
			&"wisp":
				_room_mat.set_shader_parameter(k, _v4(v, 24))
				_room_mat.set_shader_parameter(&"wisp_n", mini((v as PackedVector3Array).size(), 24))
			&"w_small", &"fl_small", &"str_v":
				_room_mat.set_shader_parameter(k, _quads(v))
			&"g_scan":
				_tube_mat.set_shader_parameter(&"scan_on", v)
				_mean_mat_scan(v)
			_:
				_room_mat.set_shader_parameter(k, v)
	_tube_mat.set_shader_parameter(&"tube_on", ts >= 2.5)


## A debug view of the room's planes (`-- sheet=DeskRooms dbg=1`), 0 for the room.
func debug(mode: int) -> void:
	_room_mat.set_shader_parameter(&"dbg", mode)


func _mean_mat_scan(on: bool) -> void:
	var r := _mean_vp.get_child(0) as ColorRect
	(r.material as ShaderMaterial).set_shader_parameter(&"scan_on", on)


static func _pad4(a: PackedVector4Array, n: int) -> PackedVector4Array:
	var b := a.duplicate()
	b.resize(n)
	return b


## vec3s as vec4s, n of them (the shader's arrays are vec4: see desk_room.gdshaderinc).
static func _v4(a: PackedVector3Array, n: int) -> PackedVector4Array:
	var b := PackedVector4Array()
	b.resize(n)
	for i in mini(a.size(), n):
		b[i] = Vector4(a[i].x, a[i].y, a[i].z, 0.0)
	return b


## Sixteen floats as four vec4s.
static func _quads(a: PackedFloat32Array) -> PackedVector4Array:
	var f := a.duplicate()
	f.resize(16)
	var b := PackedVector4Array()
	for i in 4:
		b.append(Vector4(f[i * 4], f[i * 4 + 1], f[i * 4 + 2], f[i * 4 + 3]))
	return b
