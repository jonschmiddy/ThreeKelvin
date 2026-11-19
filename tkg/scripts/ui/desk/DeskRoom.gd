class_name DeskRoom
extends Control

## One science desk room drawn as the approved page draws it: the room lit at art size (384 x 216) in
## its own viewport by the room's shader, then scaled to the window through the tube (`desk_tube`),
## which reads the canvas the page would have drawn (5x art, the CRT's scanlines). The room's clocks
## and small layers are its life (`DeskLife`: `DeskOne`, `DeskTwo`); the bake is `tools/desk/dump_desk.py`'s.
## Why: docs/why/DeskScene.md#the-plan

const BAKE_DIR := "res://art/desk/bake/%s/"
const ART := Vector2i(384, 216)
const GLASS := Vector2i(150, 140)
## The page's canvas: what the tube's numbers are in.
const CANVAS := Vector2(1920.0, 1080.0)
const SHADERS := {"desk_1": preload("res://shaders/desk_1.gdshader"), "desk_2": preload("res://shaders/desk_2.gdshader"),
	"bunk_1": preload("res://shaders/bunk_1.gdshader"),
	"nook_1": preload("res://shaders/nook_1.gdshader")}
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
var life: DeskLife = null
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
	life = _life(room, meta)
	_room_mat = ShaderMaterial.new()
	_room_mat.shader = SHADERS[room]
	var f := Image.FORMAT_RGBAF
	for n: String in ["a2c", "fields", "small_i", "small_v", "px", "small_i2", "small_v2", "small_i3", "small_v3", "art", "fields2"]:
		if FileAccess.file_exists((BAKE_DIR % room) + n + ".bin.gz"):
			_room_mat.set_shader_parameter(n + "_tex", plane(room, n, ART, f))
	_room_mat.set_shader_parameter(&"role_tex", plane(room, "role", ART, Image.FORMAT_RF))
	if FileAccess.file_exists((BAKE_DIR % room) + "pick.bin.gz"):
		_room_mat.set_shader_parameter(&"pick_tex", plane(room, "pick", ART, Image.FORMAT_RF))
	_room_mat.set_shader_parameter(&"glass_tex", plane(room, "glass", GLASS, f))
	set_card("")
	_room_mat.set_shader_parameter(&"screen_tex", SCREEN)
	life.set_screen(SCREEN.get_image())
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
	_tube_mat.set_shader_parameter(&"scan_mul", life.scan)
	mean_mat.set_shader_parameter(&"scan_mul", life.scan)
	var tube := ColorRect.new()
	tube.material = _tube_mat
	tube.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tube.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tube)
	return true


## The room's scalar half (its page script's port).
static func _life(room: String, m: Dictionary) -> DeskLife:
	match room:
		"desk_2":
			return DeskTwo.new(m)
		"bunk_1":
			return DeskBunk.new(m)
		"nook_1":
			return DeskNook.new(m)
	return DeskOne.new(m)


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


## The title card naming the site ("": the page's own).
func set_card(site: String) -> void:
	var card := DeskCard.title(site)
	_room_mat.set_shader_parameter(&"title_tex", ImageTexture.create_from_image(card))
	if life != null:
		life.set_card(card)


## What the picture phase shows on the glass (150 x 140).
func set_screen(img: Image) -> void:
	_room_mat.set_shader_parameter(&"screen_tex", ImageTexture.create_from_image(img))
	life.set_screen(img)


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
			&"w_small", &"fl_small", &"str_v", &"str_cream":
				_room_mat.set_shader_parameter(k, _quads(v, life.small_q))
			&"led_v":
				_room_mat.set_shader_parameter(k, _quads(v, 2))
			&"led_b":
				_room_mat.set_shader_parameter(k, _quads(v, 3))
			&"str_w":
				_room_mat.set_shader_parameter(k, _quads(v, life.small_q))
			&"trace":
				var tr: PackedVector4Array = (v as PackedVector4Array).duplicate()
				_room_mat.set_shader_parameter(&"trace_n", tr.size())
				tr.resize(17)
				_room_mat.set_shader_parameter(k, tr)
			&"canvas_fade", &"scan2_on":
				_tube_mat.set_shader_parameter(k, v)
				(_mean_vp.get_child(0) as ColorRect).material.set_shader_parameter(k, v)
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


## Floats as q vec4s (four to a vec4, zero past the end).
static func _quads(a: PackedFloat32Array, q: int = 4) -> PackedVector4Array:
	var f := a.duplicate()
	f.resize(q * 4)
	var b := PackedVector4Array()
	for i in q:
		b.append(Vector4(f[i * 4], f[i * 4 + 1], f[i * 4 + 2], f[i * 4 + 3]))
	return b
