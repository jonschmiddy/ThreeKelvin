class_name SeqDatamosh
extends JumpSequence

## R15 DATAMOSH (_r15/r15.py, its clock and curves). The hull flickers like the GLITCH
## tooltip, the picture pours forward off it in 8 px blocks until the frame is broken video,
## the tape grinds to a frozen frame, and it snaps back clean with the ship gone. Stateful:
## stepped tick by tick from its start, never sought.
## Why: docs/why/SeqDatamosh.md#datamosh

const WORLD := preload("res://shaders/jump/jump_r15.gdshader")
const STATE := preload("res://shaders/jump/jump_r15_state.gdshader")
const OUT := preload("res://shaders/jump/jump_r15_out.gdshader")
const SORT := preload("res://shaders/jump/jump_r15_sort.gdshader")

const T_WAKE := 0.7
const T_MOSH := 2.2
const T_FULL := 4.9
const T_RIP := 6.0
const T_STOP := 6.15
const T_FREEZE := 6.45
const T_SNAP := 7.05
const T_DEAD_END := 8.9
const FPS := 60.0
const BS := 8
const NBX := 120
const NBY := 68
## A new set of motion vectors every GOP seconds of tape.
const GOP := 0.42
## The drive's pulses (r15.py `pulses()`, r12's accelerating clock, 12 of them).
const PULSES := [0.7, 1.03754, 1.22799, 1.37678, 1.50316, 1.61495, 1.71628, 1.80963, 1.89663, 1.97843, 2.05586, 2.12955]
## The film's tears as it dealt them (rng 4242): tape start, frames, y, h, x0, x1, d, in the
## film's frame; `_tear_rect` places them round this hull.
const TEARS := [
	[0.7, 2, 294, 6, 84, 336, 6], [1.03754, 2, 243, 6, 83, 342, 7], [1.22799, 2, 297, 12, 78, 354, 8],
	[1.37678, 2, 244, 9, 70, 380, 11], [1.50316, 2, 249, 12, 77, 363, 13], [1.61495, 2, 302, 9, 75, 460, -15],
	[1.63162, 2, 287, 6, 81, 389, 11], [1.71628, 3, 259, 6, 72, 380, -15], [1.73295, 3, 260, 6, 71, 380, 16],
	[1.80963, 3, 268, 12, 71, 450, 18], [1.8263, 3, 276, 12, 53, 401, 19], [1.89663, 3, 289, 9, 41, 393, 14],
	[1.9133, 3, 287, 9, 74, 430, 20], [1.97843, 3, 250, 12, 50, 439, 17], [1.9951, 3, 266, 6, 57, 563, 19],
	[2.01177, 3, 242, 12, 52, 429, -23], [2.05586, 3, 282, 6, 44, 530, -23], [2.07253, 3, 264, 6, 54, 373, 17],
	[2.08919, 3, 248, 6, 80, 543, -20], [2.12955, 3, 281, 12, 73, 661, 19], [2.14622, 3, 271, 3, 66, 428, 17],
	[2.16288, 3, 306, 6, 51, 497, 22], [2.2, 5, 254, 9, 80, 720, 30], [2.2, 5, 279, 12, 80, 720, 52],
	[2.2, 5, 302, 6, 80, 720, 22], [2.4, 3, 229, 6, 151, 313, -13], [2.63607, 4, 234, 3, 165, 377, 7],
	[2.89712, 2, 249, 9, 62, 330, 30], [3.13757, 3, 212, 3, 119, 438, 13], [3.37483, 4, 136, 12, 129, 498, -31],
	[3.58855, 3, 239, 9, 124, 539, 45], [3.81818, 2, 494, 3, 68, 532, 52], [4.03573, 3, 412, 6, 94, 604, 60],
	[4.20211, 3, 44, 9, 132, 677, -43], [4.4348, 3, 64, 12, 71, 666, 4], [4.63246, 4, 157, 24, 79, 716, 78],
	[4.78702, 3, 229, 18, 101, 771, 60], [4.94299, 2, 200, 12, 80, 783, 78], [5.11887, 4, 79, 6, 113, 853, 92],
	[5.28442, 3, 81, 18, 8, 783, 91], [5.42198, 2, 320, 6, 8, 813, 72], [5.55291, 3, 396, 24, 8, 841, -22],
	[5.68771, 3, 178, 3, 8, 869, 74], [5.83518, 2, 488, 9, 8, 901, -79], [5.96244, 3, 228, 6, 8, 928, 76],
	[6.08799, 4, 299, 18, 8, 952, 43], [6.346, 30, 269, 12, 120, 610, 34], [6.346, 30, 313, 6, 260, 880, -18],
	[6.346, 30, 186, 24, 380, 820, 64], [6.346, 30, 402, 9, 60, 470, 40]]
## The film's ship and heading, and its frame's world edges.
const FILM_SHIP := Rect2(90.0, 232.0, 236.0, 93.0)
const FILM_AXIS := 282.23
const FILM_X0 := 8.0
const FILM_X1 := 952.0
## The film's 44-colour cut of its scene (and the slipped halves), where this LOCAL kept no palette.
const FILM_PAL := [[75, 71, 74], [29, 22, 24], [17, 14, 23], [5, 13, 21], [19, 12, 19], [8, 12, 21], [8, 11, 20],
	[6, 11, 19], [5, 11, 17], [15, 8, 16], [7, 10, 18], [6, 9, 16], [4, 9, 15], [4, 8, 12], [8, 5, 14], [6, 5, 13],
	[5, 5, 15], [5, 4, 11], [4, 5, 13], [4, 4, 14], [4, 4, 12], [4, 4, 10], [3, 5, 13], [2, 4, 11], [6, 2, 8],
	[3, 3, 12], [3, 1, 12], [3, 2, 9], [3, 2, 7], [1, 3, 9], [2, 3, 8], [1, 2, 7], [2, 1, 6]]
## The glitch's own colours: the tooltip's fill and scanline, whites, mint, rose and violet ramps.
const EXTRA := [[6, 16, 16], [10, 26, 22], [236, 252, 244], [255, 250, 255], [50, 73, 66], [86, 119, 106],
	[131, 176, 156], [184, 245, 216], [81, 43, 65], [143, 66, 106], [205, 89, 146], [59, 41, 100], [105, 62, 171]]
const WA := Vector3(0.40, 0.66, 0.56)
const WB := Vector3(0.60, 0.34, 0.44)
const MULTS := [0.0, 0.5, 1.0, 1.0, 1.5, 2.0, 3.0]
const MULT_P := [0.10, 0.18, 0.25, 0.17, 0.14, 0.10, 0.06]
const RAILS := [1.5, 2.0, 3.0, 4.0]
## The tooltip's flicker, run out (a dead block going), and the hanging edge's.
const FLICK := [0.45, 1.0, 0.6, 0.25, 0.0]
const RING_FL := [1.0, 1.0, 0.45, 1.0, 0.6, 0.3, 0.0]
const DEAD_N := 15
## With REDUCE FLASHES the vectors step at 4 Hz: one release every 15 ticks.
const REDUCE_TICKS := 15

var _mirror: JumpMirror
var _state: SubViewport
var _sort: SubViewport
var _out: SubViewport
var _sm: ShaderMaterial
var _xm: ShaderMaterial
var _om: ShaderMaterial
var _vec_img: Image
var _vec_tex: ImageTexture
var _info_img: Image
var _info_tex: ImageTexture
var _rows_img: Image
var _rows_tex: ImageTexture
var _vec := PackedByteArray()
var _info := PackedByteArray()
var _rows := PackedByteArray()
var _h := 540
## Per block: when it is infected (tape s), its integrated motion, this GOP's vectors, what
## it owes the state (whole pixels not yet released), and whether it is hull.
var _t_inf := PackedFloat32Array()
var _inf_order := PackedInt32Array()
var _inf_next := 0
var _infected := PackedInt32Array()
var _hull_b := PackedByteArray()
var _ax := PackedFloat32Array()
var _ay := PackedFloat32Array()
var _k := PackedFloat32Array()
var _ky := PackedFloat32Array()
var _pdx := PackedInt32Array()
var _pdy := PackedInt32Array()
var _stuck := PackedInt32Array()
var _prev_stuck := PackedInt32Array()
var _gop := -1
var _dc_gop := -1
var _tick := -1
var _freeze_tick := 387
var _froze := false
var _frozen: Texture2D = null
var _dead: Array[Array] = []
var _epochs := Vector3i(-1, -1, -1)
var axis := 0.0
var ship_l := 0.0
var ship_r := 0.0
## Frame times of the CPU part and of the four viewports on the GPU, for the cine's log (ms).
var cpu_ms := PackedFloat32Array()
var gpu_ms := PackedFloat32Array()
## For the harness: ticks stepped, ticks the vectors were released on, ticks anything slipped.
var advanced := 0
var released := PackedInt32Array()
var slipped := 0


func _init() -> void:
	id = &"r15"
	length = 10.0
	hit_t = T_SNAP
	cut_t = T_FREEZE + 0.03
	commit_t = T_DEAD_END
	_freeze_tick = int(round(T_FREEZE * FPS))


## The glitch's own clock: 1 until the tape stop, then grinding to a halt at the freeze (rate
## 1 - u^2). The vectors, the deals, the tears and the slips read it; the mix's varispeed was
## cut on the same curve (_r15/sound/mix.py).
static func tape(t: float) -> float:
	if t < T_STOP:
		return t
	var u := minf((t - T_STOP) / (T_FREEZE - T_STOP), 1.0)
	return T_STOP + (T_FREEZE - T_STOP) * (u - u * u * u / 3.0)


## Base motion along the heading, px per tick.
static func speed(t: float) -> float:
	if t < T_MOSH:
		return 0.0
	var u := (t - T_MOSH) / (T_FULL - T_MOSH)
	var v := 1.9 + 1.9 * pow(ease3(u), 1.2) + 1.2 * exp(-(t - T_MOSH) / 0.25)
	if t > T_FULL:
		v = 3.8 + 5.0 * ease3((t - T_FULL) / (T_STOP - T_FULL))
	if t > T_STOP:
		v *= maxf(1.0 - pow((t - T_STOP) / (T_FREEZE - T_STOP), 2.0), 0.0)
	return v


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	stage.build(WORLD, place.window)
	axis = place.pc.y
	ship_l = place.ink.position.x + 4.0
	ship_r = place.ink.end.x - 6.0
	var size := Vector2i(stage.get_viewport().get_visible_rect().size)
	_h = size.y
	_out = _viewport(size, false)
	_om = _rect(_out, OUT)
	_sort = _viewport(size, false)
	_xm = _rect(_sort, SORT)
	_state = _viewport(size, true)
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_state.add_child(bb)
	_sm = _rect(_state, STATE)
	var hide: Array[CanvasItem] = [stage]
	_mirror = JumpMirror.of(stage.get_parent() as Control, hide)
	# a viewport draws after the viewports inside it: the mirror, the state, the sort, the output
	_state.add_child(_mirror)
	_sort.add_child(_state)
	_out.add_child(_sort)
	stage.add_child(_out)
	_textures()
	_uniforms(size)
	_bake_blocks()


func _viewport(size: Vector2i, never: bool) -> SubViewport:
	var v := SubViewport.new()
	v.size = size
	v.transparent_bg = false
	v.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	RenderingServer.viewport_set_measure_render_time(v.get_viewport_rid(), true)
	if never:
		v.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	return v


func _rect(v: SubViewport, sh: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	var r := ColorRect.new()
	r.size = Vector2(v.size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = m
	v.add_child(r)
	return m


func _textures() -> void:
	_vec.resize(NBX * NBY * 2)
	_vec.fill(128)
	_vec_img = Image.create_from_data(NBX, NBY, false, Image.FORMAT_RG8, _vec)
	_vec_tex = ImageTexture.create_from_image(_vec_img)
	_info.resize(NBX * NBY * 4)
	_info.fill(0)
	_info_img = Image.create_from_data(NBX, NBY, false, Image.FORMAT_RGBA8, _info)
	_info_tex = ImageTexture.create_from_image(_info_img)
	_rows.resize(_h * 4)
	_rows.fill(0)
	for y in _h:
		_rows[y * 4 + 2] = 128
	_rows_img = Image.create_from_data(_h, 1, false, Image.FORMAT_RGBA8, _rows)
	_rows_tex = ImageTexture.create_from_image(_rows_img)


func _uniforms(size: Vector2i) -> void:
	var wr := Vector4(place.window.position.x, place.window.position.y, place.window.size.x, place.window.size.y)
	var sr := Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y)
	var ink := Vector4(place.ink.position.x, place.ink.position.y, place.ink.size.x, place.ink.size.y)
	var pt := PackedFloat32Array()
	var ps := PackedFloat32Array()
	for tp: float in PULSES:
		pt.append(tp)
		ps.append((tp - T_WAKE) / (T_MOSH - T_WAKE))
	for m: ShaderMaterial in [_sm, _om]:
		m.set_shader_parameter(&"world", wr)
		m.set_shader_parameter(&"ship", sr)
		m.set_shader_parameter(&"ink_s", ink)
		m.set_shader_parameter(&"live", _mirror.get_texture())
		m.set_shader_parameter(&"info", _info_tex)
	_sm.set_shader_parameter(&"vecs", _vec_tex)
	_sm.set_shader_parameter(&"core", place.core)
	_sm.set_shader_parameter(&"pc", place.pc)
	_sm.set_shader_parameter(&"pulse_t", pt)
	_sm.set_shader_parameter(&"pulse_s", ps)
	_sm.set_shader_parameter(&"pulse_n", PULSES.size())
	_sm.set_shader_parameter(&"axis", axis)
	_sm.set_shader_parameter(&"ship_l", ship_l)
	_sm.set_shader_parameter(&"aura_dx", place.along(70.0))
	_sm.set_shader_parameter(&"t_mosh", T_MOSH)
	_sm.set_shader_parameter(&"t_span", T_FULL - T_MOSH)
	_sm.set_shader_parameter(&"dc_amp", 0.5 if reduce else 1.0)
	var pxs := Vector2(1.0 / float(size.x), 1.0 / float(size.y))
	for m: ShaderMaterial in [_om, _xm]:
		m.set_shader_parameter(&"state", _state.get_texture())
		m.set_shader_parameter(&"rows", _rows_tex)
		m.set_shader_parameter(&"PX", pxs)
		m.set_shader_parameter(&"world", wr)
	_om.set_shader_parameter(&"sorted_tex", _sort.get_texture())
	var pal := _palette()
	for m: ShaderMaterial in [_om, stage.mat1]:
		m.set_shader_parameter(&"pal", pal)
		m.set_shader_parameter(&"pal_n", pal.size())
	stage.set1(&"ship", sr)
	stage.set1(&"mosh", _out.get_texture())
	stage.set1(&"mode", 0)


## The palette the glitch snaps to: its own colours, then this LOCAL's (`LocalSky.palette_for`)
## and their mint and rose halves, or the film's cut where the sky kept none. 64 at most.
func _palette() -> PackedVector3Array:
	var cols: Array[Vector3] = []
	for c: Array in EXTRA:
		cols.append(Vector3(c[0], c[1], c[2]))
	var own: Array = LocalSky.palette_for(Run.node_at()) if Run.node_at() != null else []
	var n := int(own[1]) if own.size() == 2 else 0
	if n > 0:
		var arr: PackedVector3Array = own[0]
		for i in mini(n, 24):
			cols.append(arr[i] * 255.0)
		for i in mini(n, 24):
			cols.append((arr[i] * 255.0 * WA * 1.6).clamp(Vector3.ZERO, Vector3(255, 255, 255)))
			cols.append((arr[i] * 255.0 * WB * 1.6).clamp(Vector3.ZERO, Vector3(255, 255, 255)))
	else:
		for c: Array in FILM_PAL:
			cols.append(Vector3(c[0], c[1], c[2]))
	var out := PackedVector3Array()
	for c in cols:
		if out.size() >= 64:
			break
		var dup := false
		for o in out:
			if o.distance_to(c) < 4.0:
				dup = true
				break
		if not dup:
			out.append(c)
	return out


## When each block is corrupted: a front from the hull, fast along the heading, slow behind
## and off the axis, ragged in clumps, a few blocks running ahead; the hull's blocks first.
func _bake_blocks() -> void:
	var nb := NBX * NBY
	_t_inf.resize(nb)
	_ax.resize(nb)
	_ay.resize(nb)
	_k.resize(nb)
	_ky.resize(nb)
	_pdx.resize(nb)
	_pdy.resize(nb)
	_ax.fill(0.0)
	_ay.fill(0.0)
	_k.fill(0.0)
	_ky.fill(0.0)
	_pdx.fill(0)
	_pdy.fill(0)
	_hull_b.resize(nb)
	_hull_b.fill(0)
	_mark_hull(null)
	var r := RandomNumberGenerator.new()
	r.seed = 1515
	var lo := PackedFloat32Array()
	lo.resize(nb)
	for i in nb:
		lo[i] = r.randfn(0.0, 1.0)
	lo = _box5(lo)
	var reach := place.ahead(760.0)
	for by in NBY:
		for bx in NBX:
			var i := by * NBX + bx
			var cx := float(bx * BS) + 4.0
			var cy := float(by * BS) + 4.0
			var d := Vector2(maxf(cx - ship_r, 0.0) + maxf(ship_l - cx, 0.0) * 2.4, maxf(absf(cy - axis) - 30.0, 0.0) * 2.0).length()
			var ti := T_MOSH + 0.15 + pow(d / reach, 0.8) * (T_FULL - T_MOSH - 0.35) + 0.22 * lo[i] * 2.2 + 0.12 * r.randfn(0.0, 1.0)
			if r.randf() < 0.06 and absf(cy - axis) < 60.0:
				ti -= r.randf_range(0.3, 0.9)
			_t_inf[i] = clampf(ti, T_MOSH, T_FULL)
	_order_inf()


## A 5x5 box mean, edges clamped (scipy's `uniform_filter(.., 5, mode="nearest")`), separable.
func _box5(f: PackedFloat32Array) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(f.size())
	var o := PackedFloat32Array()
	o.resize(f.size())
	for by in NBY:
		for bx in NBX:
			var s := 0.0
			for d in range(-2, 3):
				s += f[by * NBX + clampi(bx + d, 0, NBX - 1)]
			a[by * NBX + bx] = s / 5.0
	for by in NBY:
		for bx in NBX:
			var s := 0.0
			for d in range(-2, 3):
				s += a[clampi(by + d, 0, NBY - 1) * NBX + bx]
			o[by * NBX + bx] = s / 5.0
	return o


## Block indices in order of a score, by a native sort of (score, index) packed into one int.
static func _ranked(score: PackedFloat32Array, scale: float, descending: bool) -> PackedInt32Array:
	var keys := PackedInt64Array()
	for i in score.size():
		var v := int(roundf(score[i] * scale))
		keys.append((-v if descending else v) * 16384 + i)
	keys.sort()
	var out := PackedInt32Array()
	out.resize(keys.size())
	for i in keys.size():
		out[i] = int(posmod(keys[i], 16384))
	return out


## The hull's blocks: from the baked alpha when there is one, else its ink.
func _mark_hull(img: Image) -> void:
	_hull_b.fill(0)
	if img == null:
		var r := Rect2i(place.ink)
		for by in range(r.position.y / BS, (r.end.y - 1) / BS + 1):
			for bx in range(r.position.x / BS, (r.end.x - 1) / BS + 1):
				if by >= 0 and by < NBY and bx >= 0 and bx < NBX:
					_hull_b[by * NBX + bx] = 1
		return
	var org := Vector2i(place.canvas.position)
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.5:
				var bx := (org.x + x) / BS
				var by := (org.y + y) / BS
				if by >= 0 and by < NBY and bx >= 0 and bx < NBX:
					_hull_b[by * NBX + bx] = 1


func _order_inf() -> void:
	var nb := NBX * NBY
	for i in nb:
		if _hull_b[i] == 1:
			_t_inf[i] = T_MOSH
	var rel := PackedFloat32Array()
	rel.resize(nb)
	for i in nb:
		rel[i] = _t_inf[i] - T_MOSH
	_inf_order = _ranked(rel, 100000.0, false)
	for i in nb:
		_info[i * 4 + 1] = clampi(int(roundf((_t_inf[i] - T_MOSH) / (T_FULL - T_MOSH) * 255.0)), 0, 255)
		_info[i * 4] = 2 if _hull_b[i] == 1 else 0


func hull_ready() -> void:
	super()
	for m: ShaderMaterial in [_sm, _om]:
		m.set_shader_parameter(&"hull", hull.tex)
		m.set_shader_parameter(&"aux", hull.aux)
		m.set_shader_parameter(&"sdf", hull.sdf)
		m.set_shader_parameter(&"sdf_pad", float(JumpHull.PAD))
		m.set_shader_parameter(&"ink_rect", Vector4(hull.ink.position.x, hull.ink.position.y, hull.ink.size.x, hull.ink.size.y))
		m.set_shader_parameter(&"hull_on", 1.0)
	if hull.image != null and _inf_next == 0:
		_mark_hull(hull.image)
		_order_inf()


func step(t: float) -> void:
	if t >= T_SNAP:
		_after(t)
		return
	set_shake(Vector2.ZERO)
	if _froze:
		return
	if _tick >= _freeze_tick:
		_freeze()
		return
	var cur := mini(int(floor(t * FPS + 1e-3)), _freeze_tick)
	if cur <= _tick:
		return
	if _tick >= 0:
		var g := 0.0
		for v: SubViewport in [_mirror, _state, _sort, _out]:
			g += RenderingServer.viewport_get_measured_render_time_gpu(v.get_viewport_rid())
		gpu_ms.append(g)
	var t0 := Time.get_ticks_usec()
	for k in range(_tick + 1, cur + 1):
		_advance(k)
	_tick = cur
	_publish(cur)
	cpu_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)


## One tick of the vectors: the GOP's deal, the infection's front, each moving block's motion
## integrated and its whole pixels owed to the state.
func _advance(k: int) -> void:
	advanced += 1
	var tk := float(k) / FPS
	var tt := tape(tk)
	var pre := tk < T_MOSH
	_stuck = _stuck_at(tk)
	if pre:
		for b in _stuck:
			var ox := _ax[b]
			_ax[b] = ox + 2.0
			_pdx[b] += int(floor(ox + 2.0) - floor(ox))
		return
	var g := int(floor(tt / GOP))
	if g != _gop:
		_deal_gop(g, tk)
	while _inf_next < _inf_order.size() and _t_inf[_inf_order[_inf_next]] <= tt:
		var b := _inf_order[_inf_next]
		_infected.append(b)
		_info[b * 4] = _info[b * 4] | 4
		_inf_next += 1
	var sp := speed(tk)
	if sp <= 0.0:
		return
	for b in _infected:
		var kx := _k[b]
		if kx == 0.0:
			continue
		var ox := _ax[b]
		var nx := ox + sp * kx
		_ax[b] = nx
		_pdx[b] += int(floor(nx) - floor(ox))
		var ky := _ky[b]
		if ky != 0.0:
			var oy := _ay[b]
			var ny := oy + sp * ky
			_ay[b] = ny
			_pdy[b] += int(floor(ny) - floor(oy))


## Per block (vx, vy) per unit of speed for one GOP (rng 9000 + g): a weighted multiplier, long
## horizontal rails of blocks sharing one, a profile peaked on the heading, a fan off it.
func _deal_gop(g: int, tk: float) -> void:
	_gop = g
	var r := RandomNumberGenerator.new()
	r.seed = 9000 + g
	var nb := NBX * NBY
	var mult := PackedFloat32Array()
	mult.resize(nb)
	for i in nb:
		var u := r.randf()
		var m := 0
		while m < MULT_P.size() - 1 and u >= float(MULT_P[m]):
			u -= float(MULT_P[m])
			m += 1
		mult[i] = MULTS[m]
	for _n in int(10.0 + 30.0 * ease3((tk - T_MOSH) / 3.0)):
		var by := r.randi_range(0, NBY - 1)
		var bx := r.randi_range(0, NBX - 5)
		var v: float = RAILS[r.randi_range(0, RAILS.size() - 1)]
		for x in range(bx, mini(bx + r.randi_range(4, 21), NBX)):
			mult[by * NBX + x] = v
	for by in NBY:
		var dy := float(by * BS) + 4.0 - axis
		var prof := 0.45 + 0.9 * exp(-pow(dy / 70.0, 2.0)) + 0.25 * exp(-pow(dy / 200.0, 2.0))
		var fan := clampf(dy / 520.0, -0.3, 0.3)
		for bx in NBX:
			var i := by * NBX + bx
			_k[i] = mult[i] * prof
			_ky[i] = _k[i] * fan if (float(bx * BS) + 4.0 > ship_l and r.randf() < 0.5) else 0.0


## On the late pulses a few blocks round the hull stick for a few frames and slide forward.
func _stuck_at(tk: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	if tk >= T_MOSH:
		return out
	for j in PULSES.size():
		var tp: float = PULSES[j]
		var s := (tp - T_WAKE) / (T_MOSH - T_WAKE)
		if s < 0.3 or tk < tp or tk >= tp + (3.0 + 4.0 * s) / FPS:
			continue
		var r := RandomNumberGenerator.new()
		r.seed = 600 + j
		for _n in int(2.0 + 10.0 * s):
			var by := clampi(int(floor((axis + r.randfn(0.0, 30.0)) / BS)), 0, NBY - 1)
			var bx := int(floor((place.ink.position.x + r.randf_range(0.0, place.ink.size.x + 40.0 * s)) / BS))
			for x in range(clampi(bx, 0, NBX - 1), clampi(bx + r.randi_range(1, 3), 0, NBX)):
				if not out.has(by * NBX + x):
					out.append(by * NBX + x)
	return out


## The tick's numbers out to the passes: vectors released (every tick, or at 4 Hz with fewer
## flashes), moving flags, the deals, and one draw of the mirror, the state and the output.
func _publish(k: int) -> void:
	var tk := float(k) / FPS
	var tt := tape(tk)
	var release := not reduce or k % REDUCE_TICKS == 0
	if release and tk >= T_MOSH:
		released.append(k)
	_vec.fill(128)
	# bit 0 stuck this tick, bit 1 hull, bit 2 infected: a block moves on bit 0 or 2
	for b in _prev_stuck:
		_info[b * 4] = _info[b * 4] & ~1
	for b in _stuck:
		_info[b * 4] = _info[b * 4] | 1
	_prev_stuck = _stuck
	if release:
		for b in _infected:
			_vec[b * 2] = clampi(_pdx[b] + 128, 0, 255)
			_vec[b * 2 + 1] = clampi(_pdy[b] + 128, 0, 255)
			_pdx[b] = 0
			_pdy[b] = 0
		for b in _stuck:
			_vec[b * 2] = clampi(_pdx[b] + 128, 0, 255)
			_pdx[b] = 0
	_vec_img.set_data(NBX, NBY, false, Image.FORMAT_RG8, _vec)
	_vec_tex.update(_vec_img)
	_info_img.set_data(NBX, NBY, false, Image.FORMAT_RGBA8, _info)
	_info_tex.update(_info_img)
	_state_numbers(k, tk, tt, release)
	_out_numbers(tk, tt)
	_mirror.render_target_update_mode = SubViewport.UPDATE_ONCE
	_state.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sort.render_target_update_mode = SubViewport.UPDATE_ONCE
	_out.render_target_update_mode = SubViewport.UPDATE_ONCE
	stage.set1(&"mode", 1)


func _state_numbers(k: int, tk: float, tt: float, release: bool) -> void:
	_sm.set_shader_parameter(&"t", tk)
	_sm.set_shader_parameter(&"tape", tt)
	_sm.set_shader_parameter(&"tick", k)
	var glow := tk >= T_WAKE and tk < T_FREEZE
	_sm.set_shader_parameter(&"glow_on", 1.0 if glow else 0.0)
	_sm.set_shader_parameter(&"wake_s", ease3((tk - T_WAKE) / (T_MOSH - T_WAKE)))
	_sm.set_shader_parameter(&"burn_s", ease3((tk - T_WAKE) / (T_MOSH - T_WAKE + 1.2)))
	_sm.set_shader_parameter(&"aura_a", ease3((tk - T_MOSH + 0.6) / 2.4))
	var p := 0.0
	if tk >= T_MOSH and release:
		p = 0.05 - 0.03 * ease3((tt - T_MOSH) / 2.7) - 0.014 * ease3((tt - T_FULL) / 0.9)
		p *= 1.0 - ease3((tk - T_RIP) / 0.4)
	_sm.set_shader_parameter(&"refresh_p", p)
	var dp := 0.0
	if tk >= T_MOSH + 0.3 and tk < T_RIP + 0.3 and release:
		var g := int(floor(tt / GOP))
		var u := ease3((tt - T_MOSH - 0.3) / (T_FULL - T_MOSH))
		var u2 := ease3((tt - T_FULL) / 1.0)
		dp = 0.0004 + 0.0015 * u + 0.006 * u2 + 0.02 * exp(-(tk - T_MOSH - 0.3) / 0.3)
		if g != _dc_gop:
			dp += 0.006 + 0.012 * u + 0.03 * u2
			_dc_gop = g
		if reduce:
			dp *= 0.5
	_sm.set_shader_parameter(&"dc_p", dp)
	_sm.set_shader_parameter(&"dc_young", 1.0 if tk < T_FULL else 0.0)
	_sm.set_shader_parameter(&"rip_k", ease3((tk - T_RIP) / 0.9) if tk >= T_RIP else -1.0)


func _out_numbers(tk: float, tt: float) -> void:
	_om.set_shader_parameter(&"mask_all", 1.0 if tk >= T_FULL else 0.0)
	_om.set_shader_parameter(&"moshing", 1.0 if tk >= T_MOSH else 0.0)
	_om.set_shader_parameter(&"rip_k", ease3((tk - T_RIP) / 0.9) if tk >= T_RIP else -1.0)
	var a_sort := ease3((tt - T_MOSH - 0.3) / 2.6)
	var a_slip := ease3((tt - T_MOSH) / 2.4) + 0.6 * ease3((tt - T_FULL) / 1.0)
	_deal_rows(tt, a_sort, a_slip)
	_deal_stamps(tt, ease3((tt - T_MOSH - 0.6) / 2.4))
	_xm.set_shader_parameter(&"sort_thr", (52.0 - 40.0 * a_sort) / 255.0)
	_xm.set_shader_parameter(&"sort_tip", a_sort)
	_om.set_shader_parameter(&"k1", 1.0 if (a_slip > 0.5 and not reduce) else 0.0)
	var pk := 0.0
	var tag := 0.0
	var tag_ph := 0.0
	for tp: float in PULSES:
		var s := (tp - T_WAKE) / (T_MOSH - T_WAKE)
		if tk >= tp and tk < tp + 2.0 / FPS and not reduce:
			pk = float(1 + int(2.5 * s))
		if s >= 0.25 and tk >= tp and tk < tp + 3.0 / FPS and tk < T_MOSH:
			var steps := [1.0, 0.45, 0.8]
			var st: float = 0.8 if reduce else steps[mini(int((tk - tp) * FPS), 2)]
			tag = st * (0.5 + 0.5 * s)
			tag_ph = float(int(tp * 37.0))
	_om.set_shader_parameter(&"pulse_k", pk)
	if pk > 0.0 or (a_slip > 0.0 and not reduce):
		slipped += 1
	_om.set_shader_parameter(&"tag_a", tag)
	_om.set_shader_parameter(&"tag_ph", tag_ph)
	_om.set_shader_parameter(&"scan_a", ease3((tt - T_FULL + 0.8) / 1.2))
	_om.set_shader_parameter(&"scan_ph", 0.0 if reduce else float(int(floor(tt / 0.1)) % 3))
	_tears(tt)


## The tears open on the tape clock: the wake's on the pulses, the launch's three, the mosh's
## larger and wider, and the four still open when the tape stops, caught in the frozen frame.
func _tears(tt: float) -> void:
	var rs := PackedVector4Array()
	var ds := PackedFloat32Array()
	for e: Array in TEARS:
		var nf := float(e[1])
		if reduce:
			nf = maxf(nf, 15.0)
		if tt < float(e[0]) or tt >= float(e[0]) + nf / FPS or rs.size() >= 16:
			continue
		rs.append(_tear_rect(e))
		ds.append(float(e[6]))
	_om.set_shader_parameter(&"tear_n", rs.size())
	rs.resize(16)
	ds.resize(16)
	_om.set_shader_parameter(&"tear_r", rs)
	_om.set_shader_parameter(&"tear_d", ds)


## A film tear (y, h, x0, x1) placed round this hull: rows from the heading, columns from the
## hull's tail and nose, the frame's edges kept as this window's edges.
func _tear_rect(e: Array) -> Vector4:
	var y := roundf(_fy(float(e[2])))
	var x0 := place.window.position.x if int(e[4]) <= int(FILM_X0) else roundf(_fx(float(e[4])))
	var x1 := place.window.end.x if int(e[5]) >= int(FILM_X1) else roundf(_fx(float(e[5])))
	y = clampf(y, place.window.position.y, place.window.end.y - float(e[3]))
	return Vector4(y, float(e[3]), x0, minf(x1, place.window.end.x))


func _fx(x: float) -> float:
	if x <= FILM_SHIP.position.x:
		return place.ink.position.x - (FILM_SHIP.position.x - x)
	if x <= FILM_SHIP.end.x:
		return place.ink.position.x + (x - FILM_SHIP.position.x) * place.ink.size.x / FILM_SHIP.size.x
	return place.ink.end.x + place.ahead(x - FILM_SHIP.end.x)


func _fy(y: float) -> float:
	var ky := place.ink.size.y / FILM_SHIP.size.y
	var dy := y - FILM_AXIS
	var inner := minf(absf(dy), 47.0)
	return axis + signf(dy) * (inner * ky + (absf(dy) - inner))


## The rows' deal: pixel-sort bands at 7.5 a second (40 rows at most, spans on the broken
## blocks, never the hull's) and the mint/rose slip by row band at 10 a second (none with
## fewer flashes), into the rows texture.
func _deal_rows(tt: float, a_sort: float, a_slip: float) -> void:
	var ep_sort := int(floor(tt * (4.0 if reduce else 7.5)))
	var ep_slip := int(floor(tt * 10.0))
	if ep_sort == _epochs.x and ep_slip == _epochs.y:
		return
	_epochs.x = ep_sort
	_epochs.y = ep_slip
	_rows.fill(0)
	var entries := PackedVector4Array()
	if a_sort > 0.0:
		entries = _deal_sort(ep_sort, a_sort)
	for y in _h:
		_rows[y * 4 + 2] = 128
	if a_slip > 0.0 and not reduce:
		var r := RandomNumberGenerator.new()
		r.seed = 3131 + ep_slip
		var base := int(roundf(a_slip * 3.0 * (0.6 + 0.4 * sin(tt * 9.0))))
		var y := 0
		var hs := [4, 8, 12, 16, 24, 40]
		while y < _h:
			var hh: int = hs[r.randi_range(0, 5)]
			var extra := 0
			if r.randf() < 0.5 * a_slip + 0.15:
				extra = int(float(r.randi_range(-1, 1) * [1, 2, 4, 7][r.randi_range(0, 3)]) * a_slip * 1.6)
			for yy in range(y, mini(y + hh, _h)):
				_rows[yy * 4 + 2] = clampi(128 + base + extra, 0, 255)
			y += hh
	_rows_img.set_data(_h, 1, false, Image.FORMAT_RGBA8, _rows)
	_rows_tex.update(_rows_img)
	entries.resize(64)
	_xm.set_shader_parameter(&"sort_e", entries)


func _deal_sort(ep: int, a: float) -> PackedVector4Array:
	var r := RandomNumberGenerator.new()
	r.seed = 777 + ep
	var out := PackedVector4Array()
	var rows_used := 0
	var y_top := int(place.window.position.y) + 2
	var y_bot := int(place.window.end.y) - 5
	var hs := [1, 2, 2, 3, 4, 6, 8, 12]
	for _n in int(2.0 + 34.0 * a):
		var hh: int = hs[r.randi_range(0, hs.size() - 1)]
		var y0 := clampi(int(axis + r.randfn(0.0, 26.0 + 140.0 * a)), y_top, y_bot - hh)
		if r.randf() >= 0.55:
			y0 = r.randi_range(y_top, y_bot - hh)
		if rows_used + hh > 40 or out.size() >= 60:
			break
		var clash := false
		for yy in range(y0, y0 + hh):
			if _rows[yy * 4 + 1] != 0:
				clash = true
		if clash:
			continue
		var runs := _mask_runs(y0, y0 + hh)
		if runs.is_empty():
			continue
		rows_used += hh
		var first := out.size()
		for run: Vector2 in runs:
			if out.size() >= 64:
				break
			out.append(Vector4(run.x, run.y, float(y0 + hh / 2), 0.0))
		for yy in range(y0, y0 + hh):
			_rows[yy * 4] = first + 1
			_rows[yy * 4 + 1] = out.size() - first
	return out


## The broken blocks' runs across rows y0..y1, the hull's blocks left out, in screen px.
func _mask_runs(y0: int, y1: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var b0 := clampi(y0 / BS, 0, NBY - 1)
	var b1 := clampi((y1 - 1) / BS, 0, NBY - 1)
	var start := -1
	for bx in NBX + 1:
		var on := bx < NBX
		if on:
			for by in range(b0, b1 + 1):
				var i := by * NBX + bx
				if _hull_b[i] == 1 or not (_info[i * 4] & 5 != 0 or _tick >= int(T_FULL * FPS)):
					on = false
		if on and start < 0:
			start = bx
		elif not on and start >= 0:
			out.append(Vector2(maxf(float(start * BS), place.window.position.x), minf(float(bx * BS), place.window.end.x)))
			start = -1
	return out


## Blocks repeated along the heading, re-dealt 9 times a second (4 with fewer flashes): a
## block-aligned cut, often of the hull, stamped again and again forward.
func _deal_stamps(tt: float, a: float) -> void:
	var ep := int(floor(tt * (4.0 if reduce else 9.0)))
	if ep == _epochs.z:
		return
	_epochs.z = ep
	var st := PackedVector4Array()
	var ss := PackedVector2Array()
	if a > 0.0:
		var r := RandomNumberGenerator.new()
		r.seed = 8800 + ep
		for _n in int(1.0 + 6.0 * a):
			var w: int = [16, 24, 32, 48][r.randi_range(0, 3)]
			var hh: int = [8, 8, 16, 24][r.randi_range(0, 3)]
			var x := 0
			var y := 0
			if r.randf() < 0.6:
				x = r.randi_range(int(place.ink.position.x), maxi(int(place.ink.end.x) - w, int(place.ink.position.x))) / BS * BS
				y = r.randi_range(int(place.ink.position.y) + 4, maxi(int(place.ink.end.y) - hh - 4, int(place.ink.position.y) + 4)) / BS * BS
			else:
				x = r.randi_range(int(place.window.position.x) + 8, int(place.window.end.x) - 52 - w) / BS * BS
				y = clampi(int(axis + r.randfn(0.0, 60.0 + 160.0 * a)), int(place.window.position.y) + 6, int(place.window.end.y) - 12 - hh) / BS * BS
			var gap: int = w + [0, 0, 8][r.randi_range(0, 2)]
			st.append(Vector4(x, y, w, hh))
			ss.append(Vector2(gap, r.randi_range(2, 2 + int(8.0 * a))))
	_om.set_shader_parameter(&"stamp_n", st.size())
	st.resize(16)
	ss.resize(16)
	_om.set_shader_parameter(&"stamp", st)
	_om.set_shader_parameter(&"stamp_s", ss)


## The freeze: the last broken frame is read back once (the frame is dead still, so the
## stall is unseen), held on screen, the dead blocks picked from it, and the feedback buffer
## let go.
func _freeze() -> void:
	_froze = true
	var img: Image = null
	if is_instance_valid(_out) and _out.get_texture() != null:
		img = _out.get_texture().get_image()
	if img != null and not img.is_empty():
		img.convert(Image.FORMAT_RGB8)
		_frozen = ImageTexture.create_from_image(img)
		stage.set1(&"mosh", _frozen)
		stage.set1(&"mode", 1)
	else:
		stage.set1(&"mode", 0)
	_pick_dead(img)
	if is_instance_valid(_out):
		_out.queue_free()
	_out = null
	_sort = null
	_state = null
	_mirror = null


## The dead blocks: runs of blocks of the broken frame, from its busiest parts (8 bright, 7
## coloured), that go out after the snap from where the ship was to the far edge.
func _pick_dead(img: Image) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1508
	var bright := PackedFloat32Array()
	var sat := PackedFloat32Array()
	bright.resize(NBX * NBY)
	sat.resize(NBX * NBY)
	var data := img.get_data() if img != null and not img.is_empty() else PackedByteArray()
	var w := img.get_width() if not data.is_empty() else 0
	var wb := Rect2i(Vector2i(place.window.position) / BS + Vector2i(3, 2), Vector2i(place.window.size) / BS - Vector2i(6, 4))
	for by in range(wb.position.y, wb.end.y):
		for bx in range(wb.position.x, wb.end.x):
			var i := by * NBX + bx
			if data.is_empty():
				bright[i] = r.randf() * exp(-pow((float(by * BS) - axis) / 120.0, 2.0))
				sat[i] = r.randf() * exp(-pow((float(by * BS) - axis) / 160.0, 2.0))
				continue
			var s := 0.0
			var s2 := 0.0
			var sa := 0.0
			for yy in range(0, BS, 2):
				for xx in range(0, BS, 2):
					var o := ((by * BS + yy) * w + bx * BS + xx) * 3
					var c := Vector3(data[o], data[o + 1], data[o + 2])
					var l := c.dot(Vector3(0.30, 0.55, 0.15))
					s += l
					s2 += l * l
					sa += maxf(c.x, maxf(c.y, c.z)) - minf(c.x, minf(c.y, c.z))
			var mean := s / 16.0
			bright[i] = sqrt(maxf(s2 / 16.0 - mean * mean, 0.0)) + 0.3 * mean
			sat[i] = sa / 16.0
	var used := PackedByteArray()
	used.resize(NBX * NBY)
	var dead: Array[Vector4] = []
	for pass_i in 2:
		var score := bright if pass_i == 0 else sat
		var want := 8 if pass_i == 0 else 7
		var got := 0
		for i in _ranked(score, 1000.0, true):
			if got >= want or score[i] <= 0.0:
				break
			var by := i / NBX
			var bx := i % NBX
			if _used_near(used, bx, by):
				continue
			var ln: int = [1, 2, 2, 3, 4, 6][r.randi_range(0, 5)]
			var hh: int = [1, 1, 1, 2][r.randi_range(0, 3)]
			for yy in range(by, mini(by + hh, NBY)):
				for xx in range(bx, mini(bx + ln, NBX)):
					used[yy * NBX + xx] = 1
			dead.append(Vector4(bx, by, ln, hh))
			got += 1
	var keyed: Array[Array] = []
	for d in dead:
		keyed.append([d.x + r.randf_range(-6.0, 6.0), d])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var t0 := T_SNAP + 0.35
	var t1 := T_DEAD_END - 0.3
	_dead.clear()
	for i in keyed.size():
		var d: Vector4 = keyed[i][1]
		var rect := Rect2(d.x * BS, d.y * BS, d.z * BS, d.w * BS).intersection(place.window)
		_dead.append([rect, t0 + (t1 - t0) * pow(float(i) / float(maxi(keyed.size() - 1, 1)), 1.25)])


func _used_near(used: PackedByteArray, bx: int, by: int) -> bool:
	for yy in range(maxi(by - 2, 0), mini(by + 3, NBY)):
		for xx in range(maxi(bx - 4, 0), mini(bx + 5, NBX)):
			if used[yy * NBX + xx] == 1:
				return true
	return false


## After the snap: the clean frame without the ship, the dead blocks going out one by one with
## the tooltip's flicker, the tag's edge hanging and flickering out, the mint/rose slip closing.
func _after(t: float) -> void:
	if not _froze:
		_freeze()
	var k := t - T_SNAP
	stage.set1(&"mode", 2)
	var rects := PackedVector4Array()
	var al := PackedFloat32Array()
	for e in _dead:
		var rc: Rect2 = e[0]
		var td: float = e[1]
		var a := 1.0
		if t >= td:
			var i := int((t - td) / 0.04)
			if reduce:
				a = clampf(1.0 - (t - td) / 0.2, 0.0, 1.0)
			else:
				a = float(FLICK[i]) if i < FLICK.size() else 0.0
		if a <= 0.0 or _frozen == null:
			continue
		rects.append(Vector4(rc.position.x, rc.position.y, rc.size.x, rc.size.y))
		al.append(a)
	rects.resize(15)
	al.resize(15)
	stage.set1(&"dead", rects)
	stage.set1(&"dead_a", al)
	var ri := int(k / 0.04)
	var ra := float(RING_FL[ri]) if ri < RING_FL.size() else 0.0
	if reduce:
		ra = clampf(1.0 - k / 0.28, 0.0, 1.0)
	stage.set1(&"ring_a", ra)
	var sk := 0.0 if reduce else roundf(5.0 * exp(-k / 0.09))
	slipped += 1 if sk > 0.0 else 0
	stage.set1(&"slip_k", sk)
	var sh := Vector2.ZERO
	if k < 0.6:
		sh = Vector2(smooth_noise(t, 0), smooth_noise(t, 1) * 0.8) * 6.0 * exp(-k / 0.13)
	set_shake(sh)


func teardown() -> void:
	if _out != null and is_instance_valid(_out):
		_out.queue_free()
	_out = null
	_sort = null
	_state = null
	_mirror = null
