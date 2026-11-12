class_name YardFrontPools
extends RefCounted

## The front door's floor lamps, as the Shipyard deck's (Jon's D, Nov 12): the
## deck's pools with the hulls' shadows in them (`yard_bay.gdshader`), over the
## whole frame, the front berths' hulls at their depth and the heavy at its own.
## Baked when the hulls change (a banner), never on a pick.
## Why: docs/why/ChassisSelect.md#lit-as-the-shipyard

## The half grid the frame's 960 columns need (the hall's is 384).
const GRID := Vector2i(481, 242)

static var _gen := 0


## Bake the pools round `front`'s hulls and hand them to the light when done.
static func bake(front: YardFront) -> void:
	var sc := front.scene
	_gen += 1
	var gen := _gen
	if sc._quiet:
		# headless: no pictures to bake on, so no pools (as the deck does)
		sc.light.set_bay(null)
		_shown(sc)
		return
	var m := material_for(front)
	var vp := SubViewport.new()
	vp.size = GRID
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := ColorRect.new()
	r.size = Vector2(GRID)
	r.material = m
	vp.add_child(r)
	front.add_child(vp)
	await RenderingServer.frame_post_draw
	if is_instance_valid(vp) and gen == _gen:
		var img := vp.get_texture().get_image()
		if img != null and img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		sc.light.set_bay(img)
		_shown(sc)
	if is_instance_valid(vp):
		vp.queue_free()


## The bake's material: the deck's lamps and camera, and the two rows of hulls.
static func material_for(front: YardFront) -> ShaderMaterial:
	var rows := [[YardSlot.FRONT_FEET, [HullData.Weight.LIGHT, HullData.Weight.MEDIUM]],
		[YardSlot.BACK_FEET, [HullData.Weight.HEAVY]]]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/yard_bay.gdshader")
	_dress(m, front.scene)
	for k in 2:
		var mask := Image.create(YardFront.W, YardFront.HALL_H, false, Image.FORMAT_RGBA8)
		mask.fill(Color(0, 0, 0, 0))
		var box := Rect2i()
		for w: HullData.Weight in rows[k][1]:
			var b := (front.sets[w] as YardStandSet).hull_into(mask)
			if b.size != Vector2i.ZERO:
				box = b if box.size == Vector2i.ZERO else box.merge(b)
		_row(m, k, mask, box, float(rows[k][0]))
	return m


## Nothing of the hall shows until its floor lamps are in (`YardScene._show`).
static func _shown(sc: YardScene) -> void:
	sc._bay_ready = true
	sc._show(true)


## The deck's floor lamps and camera, from yard.json, as `YardScene._bake_bay` sets them.
static func _dress(m: ShaderMaterial, sc: YardScene) -> void:
	var cam: Dictionary = YardScene.doc().get("cam", {})
	var fx: Array = sc.lv.get("floorX", [])
	var fl := PackedFloat32Array()
	fl.resize(12)
	for i in mini(12, fx.size()):
		fl[i] = float(fx[i])
	var rows: Array = sc.lv.get("floor", [])
	var rv := PackedVector2Array()
	rv.resize(4)
	for i in mini(4, rows.size()):
		rv[i] = Vector2(float(rows[i][0]), float(rows[i][1]))
	var bay: Dictionary = YardScene.doc().get("bay", {})
	m.set_shader_parameter(&"floorx", fl)
	m.set_shader_parameter(&"nfloor", mini(12, fx.size()))
	m.set_shader_parameter(&"rows", rv)
	m.set_shader_parameter(&"nrows", mini(4, rows.size()))
	m.set_shader_parameter(&"vx", float(cam.get("vx", 383)))
	m.set_shader_parameter(&"hy", float(cam.get("hy", 30)))
	m.set_shader_parameter(&"f", float(cam.get("f", 500)))
	m.set_shader_parameter(&"ch", float(cam.get("ch", 300)))
	m.set_shader_parameter(&"wallrow", float(YardScene.doc().get("wallrow", 207)))
	m.set_shader_parameter(&"bayr", float(bay.get("r", 115)))
	m.set_shader_parameter(&"lamph", float(bay.get("lamph", 330)))
	m.set_shader_parameter(&"scale", YardLight.BSCALE)
	m.set_shader_parameter(&"grid", Vector2(GRID))


## One row of ships into the bake: its mask, its depth from its floor row, and
## the box of its hulls in the floor's terms (across, height), the shader's cull.
static func _row(m: ShaderMaterial, k: int, mask: Image, box: Rect2i, feet: float) -> void:
	var cam: Dictionary = YardScene.doc().get("cam", {})
	var vx := float(cam.get("vx", 383))
	var hy := float(cam.get("hy", 30))
	var f := float(cam.get("f", 500))
	var ch := float(cam.get("ch", 300))
	var zs := ch * f / maxf(0.5, feet - hy)
	var zsf := f / zs
	var any := box.size != Vector2i.ZERO
	var bd := Vector4.ZERO
	if any:
		bd = Vector4((float(box.position.x) - vx) / zsf, (float(box.end.x - 1) - vx) / zsf,
			ch - (float(box.end.y - 1) - hy) / zsf, ch - (float(box.position.y) - hy) / zsf)
	var sfx := "" if k == 0 else "2"
	m.set_shader_parameter(StringName("mask" + sfx), ImageTexture.create_from_image(mask))
	m.set_shader_parameter(StringName("zs" + sfx), zs)
	m.set_shader_parameter(StringName("zsf" + sfx), zsf)
	m.set_shader_parameter(StringName("bounds" + sfx), bd)
	m.set_shader_parameter(StringName("ships" + sfx), any)
