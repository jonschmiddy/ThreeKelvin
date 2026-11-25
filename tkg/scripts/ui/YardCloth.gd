class_name YardCloth
extends Node

## THE BANNERS' CLOTH (Jon, Nov 24, on the banner page: "THIS IS EXACTLY WHAT I WANTED ... The movement is
## PERFECT"): each banner a 13 x 25 Verlet cloth pinned to a rod that swings on its chains, leaning, turning
## and folding in the hall's breeze, shoved by the pointer, stirred now and then when nobody points, lit by
## the room's own lamps and throwing its shadow on the wall. The cloth runs on the GPU; this sets its forces.
## Why: docs/why/YardBanner.md#gpu

const NX := 13
const NY := 25
const HS := 1.0 / 120.0
## Jacobi passes a step, and their relaxation: hangs and swings within a fifth of a pixel (RMS) of the page's
## six Gauss-Seidel sweeps over the same scene.
## Why: docs/why/YardBanner.md#gpu
const PASSES := 14
const OMEGA := 0.55
## Steps a frame at most (two at 60 fps, four at a 30 fps film).
const MAX_STEPS := 4
## The 3 s the page hangs its cloths before its first frame, baked (`banner/hung.png`).
const T0 := 3.0
const STRIP := Vector2i(960, 160)
const WALL := Vector2i(960, ShipRoom.WALL_FOOT + 1)
## The page's breezy air, the game's (Jon, Nov 24): lean, twist, fold, breeze, gust.
const W_LEAN := 76.0
const W_TWIST := 12.0
const W_FOLD := 48.0
const W_BREEZE := 21.0
const W_GUST := 1.0
## The page's gust walks 70 px/s from 40 px left of its strip (frame x 108); it lets go past the last banner.
const GUST_X0 := 108.0
## Loaded only with a renderer: headless (the tests) the cloth's shaders are never compiled.
const SH := "res://shaders/yard_cloth_%s.gdshader"
const HUNG := "res://art/sprites/station/shiprooms/banner/hung.png"

var yard: YardFront = null
var banners: Array[YardBanner] = []
## The cloth's own clock (process time, so a --fixed-fps film runs true), its whole steps, the page's tSim.
var clock := 0.0
var steps := 0
var t_sim := T0
## The room it is lit for.
var room_id: StringName = &""
## The last frame's own work, microseconds (a shot's perf line).
var last_us := 0

var _gpu := false
var _n := 0
var _bx := PackedFloat32Array()
var _sim: SubViewport
var _groups: Array[Node2D] = []
var _integ: Array[ShaderMaterial] = []
var _lit_vp: SubViewport
var _lit_mat: ShaderMaterial
var _field_mat: ShaderMaterial
var _wall_vp: SubViewport
var _wall_mats: Array[ShaderMaterial] = []
var _show: ColorRect
var _show_mat: ShaderMaterial
var _shade: ColorRect = null
var _shade_mat: ShaderMaterial
var _room: YardClothLight.Room = null
## Each step's forces, reused: (lean, twist, breeze in z, fold), (phase, push, push x, push y), (pointer x, y, bx).
var _fa := PackedVector4Array()
var _fb := PackedVector4Array()
var _fc := PackedVector4Array()
var _lv := PackedVector4Array()
var _rc := PackedVector4Array()
var _air := YardClothAir.new()
var _sh := {}


## Hang the yard's banners: headless (the tests) they keep their click targets and hang at rest.
func setup(y: YardFront) -> void:
	yard = y
	banners = y.banners
	_n = mini(banners.size(), 7)
	_bx.resize(7)
	for i in _n:
		_bx[i] = float(banners[i].hall_x)
	_air.setup(_bx, _n)
	_gpu = DisplayServer.get_name() != "headless"
	if not _gpu:
		return
	for k: String in ["sim", "lit", "wall", "show", "shade"]:
		_sh[k] = load(SH % k)
	var tex := YardClothMesh.atlas(banners, _n)
	_build_sim()
	_build_lit(tex)
	_build_wall(tex[0])
	_show_mat = ShaderMaterial.new()
	_show_mat.shader = _sh["show"]
	_show_mat.set_shader_parameter(&"lit", _lit_vp.get_texture())
	_show_mat.set_shader_parameter(&"state", _sim.get_texture())
	_show_mat.set_shader_parameter(&"bx", _bx)
	_show_mat.set_shader_parameter(&"mark", UITheme.MARK)
	_show = ColorRect.new()
	_show.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show.size = Vector2(STRIP)
	_show.material = _show_mat
	y.add_child(_show)
	_shade_mat = ShaderMaterial.new()
	_shade_mat.shader = _sh["shade"]
	_shade_mat.set_shader_parameter(&"mask", _wall_vp.get_texture())


func _viewport(sz: Vector2i, keep: bool) -> SubViewport:
	var v := SubViewport.new()
	v.size = sz
	v.transparent_bg = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER if keep else SubViewport.CLEAR_MODE_ALWAYS
	v.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(v)
	return v


## The state texture, never cleared: each frame's steps as groups of passes, each reading the last.
func _build_sim() -> void:
	_sim = _viewport(Vector2i(NX * 6, NY * 7), true)
	var relax := _sim_mat(1)
	var last := _sim_mat(2)
	var bb0 := BackBufferCopy.new()
	bb0.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_sim.add_child(bb0)
	var init := ColorRect.new()
	init.size = Vector2(NX * 6, NY * 7)
	init.material = _sim_mat(3)
	_sim.add_child(init)
	for g in MAX_STEPS:
		var grp := Node2D.new()
		grp.visible = false
		_sim.add_child(grp)
		var integ := _sim_mat(0)
		_integ.append(integ)
		for k in PASSES + 1:
			var bb := BackBufferCopy.new()
			bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			grp.add_child(bb)
			var r := ColorRect.new()
			r.size = Vector2(NX * 6, NY * 7)
			r.material = integ if k == 0 else (last if k == PASSES else relax)
			grp.add_child(r)
		_groups.append(grp)
	_fa.resize(7)
	_fb.resize(7)
	_fc.resize(7)


func _sim_mat(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _sh["sim"]
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"omega", OMEGA)
	m.set_shader_parameter(&"hung", load(HUNG))
	return m


## The lit cloth over the field colour each pixel shows (the rims' colour), one orthographic 3D render.
func _build_lit(tex: Array) -> void:
	_lit_vp = _viewport(Vector2i(STRIP.x, STRIP.y * 2), false)
	_lit_vp.own_world_3d = true
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = float(STRIP.y * 2)
	cam.position = Vector3(STRIP.x / 2.0, -float(STRIP.y), 100.0)
	cam.near = 1.0
	cam.far = 300.0
	_lit_vp.add_child(cam)
	var mesh := YardClothMesh.cloth_3d(_bx, _n)
	_lit_mat = _lit_material(0, tex)
	_field_mat = _lit_material(1, tex)
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _lit_mat if k == 0 else _field_mat
		mi.position = Vector3(0, -float(STRIP.y * k), 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lit_vp.add_child(mi)


func _lit_material(mode: int, tex: Array) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _sh["lit"]
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"state", _sim.get_texture())
	m.set_shader_parameter(&"atlas", tex[0])
	m.set_shader_parameter(&"field", tex[1])
	m.set_shader_parameter(&"bx", _bx)
	return m


## The shadow on the wall: chains first, then the rod and the cloth over them (the page's max).
func _build_wall(atlas: Texture2D) -> void:
	_wall_vp = _viewport(WALL, false)
	var meshes := [YardClothMesh.rig_2d(_n, 2), YardClothMesh.rig_2d(_n, 1), YardClothMesh.cloth_2d(_n)]
	for k in 3:
		var m := ShaderMaterial.new()
		m.shader = _sh["wall"]
		m.set_shader_parameter(&"part", [2, 1, 0][k])
		m.set_shader_parameter(&"state", _sim.get_texture())
		m.set_shader_parameter(&"atlas", atlas)
		m.set_shader_parameter(&"bx", _bx)
		_wall_mats.append(m)
		var mi := MeshInstance2D.new()
		mi.mesh = meshes[k]
		mi.material = m
		_wall_vp.add_child(mi)


## The room is in: the shadow goes on its wall, the last thing in its `under`, and the cloth is lit for it.
func attach(r: ShipRoom) -> void:
	if not _gpu or r == null:
		return
	if _shade == null or not is_instance_valid(_shade) or _shade.is_queued_for_deletion():
		_shade = ColorRect.new()
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shade.size = Vector2(WALL)
		_shade.material = _shade_mat
	if _shade.get_parent() != r.under:
		if _shade.get_parent() != null:
			_shade.get_parent().remove_child(_shade)
		r.under.add_child(_shade)
	_to_end()
	if r.id != room_id:
		_relight(r.id)


func _to_end() -> void:
	var u := _shade.get_parent()
	if u != null and _shade.get_index() != u.get_child_count() - 1:
		u.move_child(_shade, -1)


## The page's setRoom: exposure over the hall's banners, each banner's shadow light, the rig's light.
func _relight(id: StringName) -> void:
	room_id = id
	_room = YardClothLight.room(id)
	var bxs: Array[int] = []
	for i in _n:
		bxs.append(int(_bx[i]))
	YardClothLight.fit(_room, bxs)
	YardClothMesh.light_uniforms(_room, _lit_mat, _show_mat, _wall_mats, _n)
	_lv.resize(16)
	_rc.resize(8)
	_frame_light()


func _process(delta: float) -> void:
	if not _gpu:
		return
	if yard.room != null:
		if yard.room.id != room_id or _shade == null or _shade.get_parent() != yard.room.under:
			attach(yard.room)
		_to_end()
	var t0 := Time.get_ticks_usec()
	clock += delta
	var want := int(floor(clock / HS + 1e-6))
	var n := mini(want - steps, MAX_STEPS)
	for g in MAX_STEPS:
		_groups[g].visible = g < n
	for g in n:
		_step(g)
	steps = want
	t_sim = T0 + float(steps) * HS
	_frame_light()
	var hv := -1
	for i in _n:
		if banners[i].hover:
			hv = i
	_show_mat.set_shader_parameter(&"hover", hv)
	last_us = Time.get_ticks_usec() - t0


## One of the page's simStep: the stir, the gust, the pointer's decay, then each banner's forces.
func _step(g: int) -> void:
	_air.tick(t_sim)
	for b in _n:
		_air.forces(b, t_sim)
		_fa[b] = _air.fa
		_fb[b] = _air.fb
		_fc[b] = _air.fc
	var m := _integ[g]
	m.set_shader_parameter(&"fa", _fa)
	m.set_shader_parameter(&"fb", _fb)
	m.set_shader_parameter(&"fc", _fc)
	m.set_shader_parameter(&"waves", Vector2(fmod(TAU * t_sim / 9.5, TAU), fmod(TAU * t_sim / 13.7, TAU)))
	t_sim += HS


## The lamps this frame: Solari's furnaces flicker, the Old hangar's sodium fails as the room's does,
## and a launch's stutter (`lamp_k`) takes every lamp.
func _frame_light() -> void:
	if _room == null:
		return
	var k := yard.room.lamp_k if yard.room != null else 1.0
	if room_id == &"old" and yard.room != null:
		k *= ShipRoomOld.lamp_at(fmod(yard.room.t, ShipRoomOld.LOOP))
	var ri := 0
	for i in _room.lights.size():
		var L := _room.lights[i]
		var f := YardClothLight.fire_at(L, t_sim) * (k if L.point else 1.0)
		_lv[i] = Vector4(L.vw.x, L.vw.y, f, 0.0)
		if L.rim > 0.0 and ri < 8:
			_rc[ri] = Vector4(L.col.x, L.col.y, L.col.z, L.rim * f)
			ri += 1
	_lit_mat.set_shader_parameter(&"lv", _lv)
	_show_mat.set_shader_parameter(&"rc", _rc)


func _input(e: InputEvent) -> void:
	if not _gpu or yard == null or not yard.is_visible_in_tree():
		return
	var mm := e as InputEventMouseMotion
	if mm != null:
		var p := yard.get_global_transform_with_canvas().affine_inverse() * mm.position
		_air.move(p, clock, t_sim)
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed:
		var p := yard.get_global_transform_with_canvas().affine_inverse() * mb.position
		_air.down(p, clock, t_sim)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_air.leave()


## The pointer has left the hall (a shot's script; the window's own leave comes as a notification).
func leave() -> void:
	_air.leave()


## The banners drawn or not (a shot of the room alone); they move on either way.
func show_cloth(on: bool) -> void:
	if _show != null:
		_show.visible = on
		_shade_mat.set_shader_parameter(&"off", not on)


## The cloth's three viewports (the state, the lit cloth, the wall's shadow), none headless.
func viewports() -> Array[SubViewport]:
	var out: Array[SubViewport] = []
	if _sim != null:
		out.assign([_sim, _lit_vp, _wall_vp])
	return out


## The GPU state as it stands (a shot's numbers against the page's), or null headless. Reads the GPU back.
func state_image() -> Image:
	return _sim.get_texture().get_image() if _sim != null else null
