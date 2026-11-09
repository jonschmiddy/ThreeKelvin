class_name PlanetView
extends WorldView

## One world: far ring, the world, near ring. Broken worlds are `ShatteredView`'s.

const SHADER := preload("res://shaders/planet.gdshader")
const RING_SHADER := preload("res://shaders/planet_ring.gdshader")

var _ring_back: _Ring
var _ring_front: _Ring
var _light: Vector3 = Vector3(-0.83, -0.31, 0.47)
var _seed := 0
## The painted rings, far half and near half (`planet_ring.gdshader`).
var _band_back: ColorRect
var _band_front: ColorRect
## Harness switch: off, small worlds are drawn plain, for comparing.
static var no_rich := false
## ICY rings were Jon's pick of three (Oct 3); the others stay as harness options.
## Why: docs/why/PlanetView.md#ring-look
static var ring_style := Rings.Look.ICY
## Memory covers only blocks the picture can show; nothing seen changes.
## Why: docs/why/PlanetView.md#memory-clip
var mem_clip := false
var mem_clip_lead := 0
## Room for how far the picture slides over the world between fresh memory starts.
const MEM_MARGIN := 16
## the blocks worked out this frame (`_mem_window`), the whole memory unclipped
var _mem_win := Rect2i()
## what the memory's pass must see each frame as the world on screen sees it
## (the light, the clock, the zoom; the rest is copied once, `_mem_setup`)
const MEM_LIVE := ["time", "light", "k_light", "lift", "flare", "moon_sh", "n_moon_sh", "r", "ctr_off", "rich", "cell", "unlit"]


## Half a ring of dust as the mockup drew it: far half behind, near half in front, shadowed.
class _Ring extends Node2D:
	var view: PlanetView
	var near: bool = false
	## 2 on the map: each ring pixel a 2x2 block on the place's grid
	var block := 1

	func _draw() -> void:
		var s := view.spec
		if s.is_empty() or not s.get("ring", false):
			return
		var r: float = s.r
		var col: Color = {&"banded": Color("#d8b88a"), &"icegiant": Color("#a8d8e4"), &"storm": Color("#e0a07a"), &"violet": Color("#c0a0e0")}.get(s.world, Color("#b8b0a0"))
		var L := view._light
		for k in 220:
			var a := float(k) / 220.0 * TAU
			if (sin(a) >= 0.0) != near:
				continue
			# in 2x2 blocks the four bands would run together: two, with a gap
			for rr: float in ([1.55, 1.75, 1.95, 2.15] if block == 1 else [1.6, 2.1]):
				if block == 1 and rr == 1.75 and (k & 1) == 1:
					continue
				var x := cos(a) * r * rr
				var y := sin(a) * r * rr * 0.28
				var q := Vector3(cos(a) * rr, sin(a) * rr * 0.28, sin(a) * rr * 0.96)
				var b := q.dot(L)
				var c := q.length_squared() - 1.0
				var lit := 0.04 if (b < 0.0 and b * b - c > 0.0) else 1.0
				var at := Vector2(round(x), round(y))
				if block > 1:
					at = ((global_position + at) / float(block)).floor() * float(block) - global_position
				draw_rect(Rect2(at, Vector2.ONE * block), Color(col, (0.75 if near else 0.4) * lit))


func _init() -> void:
	_ring_back = _Ring.new()
	_ring_back.view = self
	add_child(_ring_back)
	_band_back = _band(false)
	_disc = ColorRect.new()
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_disc.material = _mat
	add_child(_disc)
	_ring_front = _Ring.new()
	_ring_front.view = self
	_ring_front.near = true
	add_child(_ring_front)
	_band_front = _band(true)


func _band(near: bool) -> ColorRect:
	var c := ColorRect.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = RING_SHADER
	m.set_shader_parameter("near", near)
	m.set_shader_parameter("ramps", Worlds.ramp_texture())
	c.material = m
	c.visible = false
	add_child(c)
	return c


## Map worlds use 2x2 blocks; the panel's portrait stays at 1.
func set_cell(c: int) -> void:
	_cell = c
	_mat.set_shader_parameter("cell", c)
	_set_rich()
	_ring_back.block = c
	_ring_front.block = c
	_set_rings()
	_mem_setup()


func set_world(world: StringName, seed: int, r: float, spec_override: Dictionary = {}) -> void:
	spec = Worlds.spec(world, seed, r)
	spec.merge(spec_override, true)
	_seed = seed
	var W: Dictionary = Worlds.WORLD[world]
	var G := Worlds.half_size(world, r)
	_disc.position = Vector2(-G, -G)
	_disc.size = Vector2(2 * G + 1, 2 * G + 1)
	var m := _mat
	m.set_shader_parameter("ramps", Worlds.ramp_texture())
	m.set_shader_parameter("world", Worlds.world_id(world))
	var own := Worlds.ramp_id(world)
	m.set_shader_parameter("base_ramp", own if own >= 0 else 0)
	m.set_shader_parameter("seed", spec.seed)
	m.set_shader_parameter("r", r)
	m.set_shader_parameter("half_size", G)
	m.set_shader_parameter("spin", spec.spin)
	m.set_shader_parameter("tilt", spec.tilt)
	m.set_shader_parameter("cloud_rate", spec.cloud_rate)
	m.set_shader_parameter("bands", spec.bands)
	m.set_shader_parameter("ring", spec.ring)
	var cr: Array = spec.craters
	var crp := PackedVector4Array()
	for i in 9:
		crp.append(cr[i] if i < cr.size() else Vector4.ZERO)
	m.set_shader_parameter("craters", crp)
	m.set_shader_parameter("n_craters", cr.size())
	m.set_shader_parameter("spot", spec.spot)
	m.set_shader_parameter("has_spot", spec.has_spot)
	m.set_shader_parameter("storms", PackedVector4Array(spec.storms))
	var ov: Array = spec.ovals
	var ovp := PackedVector4Array()
	for i in 4:
		ovp.append(ov[i] if i < ov.size() else Vector4.ZERO)
	m.set_shader_parameter("ovals", ovp)
	m.set_shader_parameter("n_ovals", mini(4, ov.size()))
	var atm: Variant = W.get("atm", null)
	m.set_shader_parameter("has_atm", atm != null)
	if atm != null:
		var c := Color(String(atm))
		m.set_shader_parameter("atm", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("thick", W.get("thick", false))
	m.set_shader_parameter("caps", float(W.get("caps", 0.0)))
	m.set_shader_parameter("clouds", float(W.get("clouds", 0.0)))
	m.set_shader_parameter("cloud_ramp", Worlds.ramp_id(W.get("cloud_ramp", &"cloud")))
	m.set_shader_parameter("unlit", W.get("unlit", false))
	m.set_shader_parameter("flags", Worlds.flags(world))
	var towns: Array = spec.towns
	var tp := PackedVector4Array()
	for i in 64:
		tp.append(towns[i] if i < towns.size() else Vector4.ZERO)
	m.set_shader_parameter("towns", tp)
	m.set_shader_parameter("n_towns", mini(64, towns.size()))
	m.set_shader_parameter("aur_ax", PackedVector3Array(spec.aur_ax))
	m.set_shader_parameter("aur_e1", PackedVector3Array(spec.aur_e1))
	m.set_shader_parameter("aur_e2", PackedVector3Array(spec.aur_e2))
	_ring_back.queue_redraw()
	_ring_front.queue_redraw()
	_set_rich()
	_set_rings()
	_mem_setup()


## Painted rings: the strip built for this size goes to both halves and the world's shadow.
func _set_rings() -> void:
	if spec.is_empty():
		return
	var on: bool = ring_style != Rings.Look.DOTS and spec.get("ring", false)
	_ring_back.visible = not on
	_ring_front.visible = not on
	_band_back.visible = on
	_band_front.visible = on
	_mat.set_shader_parameter("ring_mode", 1 if on else 0)
	if not on:
		return
	var r: float = spec.r
	var R := Rings.build(ring_style, spec.world, _seed, float(_cell) / r)
	_mat.set_shader_parameter("ring_prof", R.tex)
	_mat.set_shader_parameter("ring_in", R.rin)
	_mat.set_shader_parameter("ring_out", R.rout)
	_mat.set_shader_parameter("ring_cast", R.cast)
	# (a little room past the outer edge: the smooth zoom draws the ring a pixel or
	# two bigger than the size it was built for)
	var hw := int(ceil(float(R.rout) * (r + 2.0))) + 2 * _cell + 2
	var hh := int(ceil(float(R.rout) * (r + 2.0) * 0.28)) + 2 * _cell + 2
	for c: ColorRect in [_band_back, _band_front]:
		c.position = Vector2(-hw, -hh)
		c.size = Vector2(2 * hw + 1, 2 * hh + 1)
		var m := c.material as ShaderMaterial
		m.set_shader_parameter("prof", R.tex)
		m.set_shader_parameter("rin", R.rin)
		m.set_shader_parameter("rout", R.rout)
		m.set_shader_parameter("ramp_a", R.ramp_a)
		m.set_shader_parameter("ramp_b", R.ramp_b)
		m.set_shader_parameter("dark_shadow", R.dark_shadow)
		m.set_shader_parameter("cell", _cell)
		m.set_shader_parameter("r", r)
		m.set_shader_parameter("half_w", hw)
		m.set_shader_parameter("half_h", hh)


## Smooth zoom (Jon): the surface stays on the block grid, only edge and features move.
func set_live(r: float, off: Vector2) -> void:
	_mat.set_shader_parameter("r", r)
	_mat.set_shader_parameter("ctr_off", off)
	if _band_back.visible:
		for c: ColorRect in [_band_back, _band_front]:
			var m := c.material as ShaderMaterial
			m.set_shader_parameter("r", r)
			m.set_shader_parameter("ctr_off", off)


## A world drifting by sub-pixel amounts inside its box, its memory holding through the drift.
func set_drift(off: Vector2) -> void:
	_mat.set_shader_parameter("ctr_off", off)


## Light direction, time, light strength and star disc position, in the parent's pixels.
func step(t: float, light: Vector3, k_light: float = 1.0, star_at: Vector2 = Vector2(-9999, -9999), star_r: float = 0.0) -> void:
	# STEPPED (`PixelTurn`, only to compare against): the clock held, and moved on
	# when the equator has turned a whole block
	if PixelTurn.world_mode == PixelTurn.Mode.STEPPED and not spec.is_empty() and absf(float(spec.spin)) > 1e-4:
		var q := float(_cell) / (float(spec.r) * absf(float(spec.spin)))
		t = floorf(t / q) * q
	_light = light.normalized()
	_mat.set_shader_parameter("time", t)
	_mat.set_shader_parameter("light", _light)
	_mat.set_shader_parameter("k_light", k_light)
	_mat.set_shader_parameter("centre", position)
	_mat.set_shader_parameter("star_at", star_at)
	_mat.set_shader_parameter("star_r", star_r)
	var lt := Worlds.lightning(spec, _light, t)
	var fl: Array = lt[0]
	var bo: Array = lt[1]
	var flp := PackedVector4Array()
	for i in 5:
		flp.append(fl[i] if i < fl.size() else Vector4.ZERO)
	var bop := PackedVector2Array()
	for i in 25:
		bop.append(bo[i] if i < bo.size() else Vector2.ZERO)
	_mat.set_shader_parameter("flashes", flp)
	_mat.set_shader_parameter("n_flashes", fl.size())
	_mat.set_shader_parameter("bolts", bop)
	_mat.set_shader_parameter("n_bolts", bo.size())
	if spec.get("ring", false):
		if _band_back.visible:
			for c: ColorRect in [_band_back, _band_front]:
				var m := c.material as ShaderMaterial
				m.set_shader_parameter("light", _light)
				m.set_shader_parameter("k_light", k_light)
				m.set_shader_parameter("centre", position)
				m.set_shader_parameter("star_at", star_at)
				m.set_shader_parameter("star_r", star_r)
		else:
			_ring_back.queue_redraw()
			_ring_front.queue_redraw()


## Richer the fewer blocks across it is: full at 4 blocks of radius, gone by 9.
func _set_rich() -> void:
	if spec.is_empty():
		return
	var blocks: float = float(spec.r) / float(_cell)
	var k := 0.0 if (_cell <= 1 or no_rich) else clampf((9.0 - blocks) / 5.0, 0.0, 1.0)
	_mat.set_shader_parameter("rich", k)


func _mem_live() -> Array:
	return MEM_LIVE


func _mem_resized(n: int) -> void:
	_mem_win = Rect2i(0, 0, n, n)
	_mem_mat.set_shader_parameter("mem_win", Vector4.ZERO)


func _mem_synced() -> void:
	_mem_window()


## Told to the shader only: resizing the pass rect lagged a frame and drew a second small world.
## Why: docs/why/PlanetView.md#memory-window
func _mem_window() -> void:
	var n := _mem_vp.size.x
	var full := Rect2i(0, 0, n, n)
	var w := full
	if mem_clip:
		var cl := float(maxi(_cell, 1))
		var half := int(_mem_mat.get_shader_parameter("mem_half"))
		var vis := get_global_transform_with_canvas().affine_inverse() * get_viewport().get_visible_rect()
		var x0 := floori(vis.position.x / cl) + half - MEM_MARGIN
		var y0 := floori(vis.position.y / cl) + half - MEM_MARGIN
		var x1 := floori(vis.end.x / cl) + half + MEM_MARGIN + maxi(mem_clip_lead, 0)
		var y1 := floori(vis.end.y / cl) + half + MEM_MARGIN
		w = Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1).intersection(full)
		# (wholly out of the picture: one block, never an empty window, which the
		# shader would read as the whole memory)
		if w.size.x <= 0 or w.size.y <= 0:
			w = Rect2i(0, 0, 1, 1)
	if w == _mem_win:
		return
	_mem_win = w
	_mem_mat.set_shader_parameter("mem_win", Vector4.ZERO if w == full else Vector4(w.position.x, w.position.y, w.end.x, w.end.y))


## Moved from one picture to another with its memory kept (the zoom ladder hands
## the map's world to LOCAL: `LocalSky.adopt_near`): not started afresh.
var keep_mem := false


func _mem_fresh_on_enter() -> int:
	return 0 if keep_mem else 2
