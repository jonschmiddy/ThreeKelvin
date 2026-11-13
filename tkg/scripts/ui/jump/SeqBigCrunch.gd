class_name SeqBigCrunch
extends JumpSequence

## R14 BIG CRUNCH. The drive bites and the whole sky pours into the ship from every edge
## until space is black; the light crushes into a white ball round the hull, shrinks to one
## point, holds, and bursts back out as a shockwave that throws every star home, the ship
## gone. The film's clock (round3/_r14/r14.py); the pour maps the whole LOCAL view.
## Why: docs/why/SeqBigCrunch.md#big-crunch

const POUR := preload("res://shaders/jump/jump_r14_pour.gdshader")
const COMPOSE := preload("res://shaders/jump/jump_r14.gdshader")
const STARS := preload("res://shaders/jump/jump_r14_stars.gdshader")

const T_SLAM := 0.40
const GULPS := [0.40, 0.90, 1.38, 1.82, 2.22, 2.58, 2.90, 3.18, 3.43, 3.65, 3.85, 4.03, 4.19, 4.33]
const T_FULL := 4.50
const BEATS := [4.62, 4.94, 5.20, 5.40]
const REACH := [100.0, 60.0, 28.0, 5.0]
const T_HOLD := 5.62
const T_BURST := 6.30
const BALL_R := 150.0
const NFIL := 720
## The film's 1,700 faint field stars, seen only while space moves; a tenth pass in front.
const EXTRA_N := 1700
const REAL_MAX := 1500
const SPARK_N := 110
const LIL := Vector3(0.88, 0.76, 1.00)
const GREY := Vector3(0.80, 0.80, 0.92)

var pc := Vector2.ZERO
var hk := 1.0
var gw: PackedFloat32Array = PackedFloat32Array()
var compose: ShaderMaterial
var far_real: JumpSparkQuads
var far_extra: JumpSparkQuads
var near_extra: JumpSparkQuads
var sparks: JumpSparkQuads
var _det: SubViewport = null
var _det_frames := 0
var _det_img: Image = null
var _det_row := 0
var _det_data := PackedByteArray()
## Each sky star's lag behind the burst's front (the film's rng 5, 0-40 px).
var _lag_rng := RandomNumberGenerator.new()
var _real_n := 0
var _sky_org := Vector2.ZERO
var _backdrop: LocalSky = null


func _init() -> void:
	id = &"r14"
	length = 10.0
	hit_t = T_BURST
	cut_t = T_HOLD
	commit_t = 8.8
	# the slam takes the hull at 0.40, so the stand-in must be in by then
	swap_t = 0.25
	# the gulps: faster and harder (the weights sum to one)
	var raw: Array[float] = [0.075]
	for i in 13:
		raw.append(0.045 + (0.115 - 0.045) * float(i) / 12.0)
	var sum := 0.0
	for w in raw:
		sum += w
	for w in raw:
		gw.append(w / sum)


static func gulp_step(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 2.5)


## How much of space has been taken (0..1).
func P(t: float) -> float:
	if t < T_SLAM:
		return 0.0
	var cont := pow(clampf((t - T_SLAM) / (T_FULL - T_SLAM), 0.0, 1.0), 0.85)
	var g := 0.0
	for i in GULPS.size():
		g += gw[i] * gulp_step((t - float(GULPS[i])) / 0.16)
	return clampf(0.45 * cont + 0.55 * g, 0.0, 1.0)


func AB(t: float) -> Vector2:
	var p := P(t)
	return Vector2(560.0 * pow(p, 1.5), 330.0 * pow(p, 0.8))


static func throb(t: float) -> float:
	var v := 0.0
	for b: float in GULPS + BEATS:
		var k := t - b
		if k >= 0.0 and k < 0.6:
			v = maxf(v, exp(-k / 0.10))
	return v


## The ball's radius (px about the sink): grows with the pour, then each beat throbs out and snaps in.
func ball_r(t: float) -> float:
	if t >= T_HOLD:
		return 2.5
	if t < float(BEATS[0]):
		return BALL_R * hk * ease3((P(t) - 0.30) / 0.62)
	var r := BALL_R * hk
	for i in BEATS.size():
		var k := t - float(BEATS[i])
		var rt := float(REACH[i]) * hk
		if k < 0.0:
			return r
		if k < 0.06:
			return r + (0.12 * r + 4.0) * sin(PI * k / 0.06)
		if k < 0.17:
			return r + (rt - r) * ease5((k - 0.06) / 0.11)
		r = rt
	return r


func hull_scale(t: float) -> float:
	if t < float(BEATS[0]):
		return 1.0
	return clampf(ball_r(t) / (122.0 * hk), 0.0, 1.0)


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	stage.build(POUR, place.window)
	pc = place.centroid
	hk = place.hull_k
	var wr := Vector4(place.window.position.x, place.window.position.y, place.window.size.x, place.window.size.y)
	stage.set1(&"pc", pc)
	stage.set1(&"win", wr)
	var org := stage.global_position
	far_real = JumpSparkQuads.new(JumpSparkQuads.MODE_STARS, REAL_MAX, org)
	far_real.set_p(&"width", 2.0)
	stage.mid_node(far_real)
	far_extra = JumpSparkQuads.new(JumpSparkQuads.MODE_STARS, EXTRA_N, org)
	stage.mid_node(far_extra)
	compose = stage.mid_pass(COMPOSE)
	compose.set_shader_parameter(&"win", wr)
	compose.set_shader_parameter(&"pc", pc)
	compose.set_shader_parameter(&"core", place.core)
	compose.set_shader_parameter(&"hk", hk)
	compose.set_shader_parameter(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))
	var fil := _fil_texture()
	compose.set_shader_parameter(&"fil_lin", fil)
	compose.set_shader_parameter(&"fil_nn", fil)
	near_extra = JumpSparkQuads.new(JumpSparkQuads.MODE_STARS, EXTRA_N / 5, org)
	stage.mid_node(near_extra)
	sparks = JumpSparkQuads.new(JumpSparkQuads.MODE_BURST, SPARK_N, org)
	stage.mid_node(sparks)
	for m: JumpSparkQuads in [far_real, far_extra, near_extra, sparks]:
		m.set_p(&"pc", pc)
	stage.set2(&"bloom", 0.0)
	_roll_extras()
	_roll_sparks()
	_start_detector()


## The ball's filaments: a smooth random brightness over angle (the film's rng 9), as a texture.
func _fil_texture() -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var raw := PackedFloat32Array()
	for i in NFIL:
		raw.append(r.randf())
	var bytes := PackedByteArray()
	bytes.resize(NFIL)
	for i in NFIL:
		var m := 0.0
		for k in range(-2, 3):
			m += raw[posmod(i + k, NFIL)]
		bytes[i] = clampi(int(roundf(clampf(m / 5.0 * 1.8 - 0.4, 0.0, 1.0) * 255.0)), 0, 255)
	return ImageTexture.create_from_image(Image.create_from_data(NFIL, 1, false, Image.FORMAT_R8, bytes))


## The extra field stars (the film's rng 1414), far and near, in polar form about the sink.
func _roll_extras() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1414
	var w := place.window
	var nf := 0
	var nn := 0
	for i in EXTRA_N:
		var at := Vector2(r.randf_range(w.position.x + 4.0, w.end.x - 5.0), r.randf_range(w.position.y + 2.0, w.end.y - 3.0))
		var d := at - pc
		var eb := pow(r.randf_range(0.15, 0.6), 1.4)
		var near := r.randf() < 0.10
		var col := LIL if r.randf() < 0.3 else GREY
		var lag := r.randf_range(0.0, 70.0)
		var custom := Color(d.length(), atan2(d.y, d.x), eb * (1.8 if near else 1.0), lag)
		if near and nn + 1 < EXTRA_N / 5:
			near_extra.put(nn, Color(col.x, col.y, col.z, 2.0), custom)
			near_extra.put(nn + 1, Color(col.x, col.y, col.z, 3.0), custom)
			nn += 2
		elif nf < EXTRA_N:
			far_extra.put(nf, Color(col.x, col.y, col.z, 1.0), custom)
			nf += 1


## The burst's sparks (the film's rng 66): angle, speed, life, brightness; a third white.
func _roll_sparks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 66
	for i in SPARK_N:
		var col := Vector3(1.0, 0.97, 1.0) if i % 3 == 0 else LIL
		sparks.put(i, Color(col.x, col.y, col.z, 1.0),
			Color(r.randf_range(0.0, TAU), r.randf_range(160.0, 900.0) * r.randf_range(0.6, 1.0), r.randf_range(0.6, 1.9), r.randf_range(0.5, 1.4)))


## The sky's own stars: found on the GPU from the LOCAL sky's picture (480x270, drawn at 2x),
## read back once a frame or two in, scanned a few rows a frame, each a two-pixel streak.
func _start_detector() -> void:
	var view := stage.get_parent() as EncounterView
	_lag_rng.seed = 5
	if view == null or LocalSky.headless():
		return
	_backdrop = view.backdrop
	var scene: SubViewport = _backdrop._scene
	if scene == null or _backdrop._box == null:
		return
	_sky_org = _backdrop._box.global_position
	_det = SubViewport.new()
	_det.size = scene.size
	_det.transparent_bg = true
	_det.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size = Vector2(scene.size)
	var m := ShaderMaterial.new()
	m.shader = STARS
	m.set_shader_parameter(&"sky", scene.get_texture())
	rect.material = m
	_det.add_child(rect)
	stage.add_child(_det)


func _poll_detector() -> void:
	if _det != null:
		_det_frames += 1
		if _det_frames < 3:
			return
		_det_img = _det.get_texture().get_image()
		if _det_img != null and _det_img.get_format() != Image.FORMAT_RGBA8:
			_det_img.convert(Image.FORMAT_RGBA8)
		if _det_img != null:
			_det_data = _det_img.get_data()
		_det.queue_free()
		_det = null
		return
	if _det_img == null or _det_row >= _det_img.get_height():
		return
	var w := _det_img.get_width()
	var sc := _backdrop._box.scale.x if _backdrop != null and _backdrop._box != null else 2.0
	var y1 := mini(_det_row + 68, _det_img.get_height())
	for y in range(_det_row, y1):
		for x in w:
			var i := (y * w + x) * 4
			if _det_data[i + 3] < 128:
				continue
			var at := _sky_org + Vector2(x, y) * sc
			if _real_n >= REAL_MAX or not place.window.has_point(at):
				# not drawn as a streak, so not taken out of the sky either
				_det_data[i + 3] = 0
				continue
			var d := at - pc
			far_real.put(_real_n, Color(float(_det_data[i]) / 255.0, float(_det_data[i + 1]) / 255.0, float(_det_data[i + 2]) / 255.0, 0.0),
				Color(d.length(), atan2(d.y, d.x), 1.0, _lag_rng.randf_range(0.0, 40.0)))
			_real_n += 1
	_det_row = y1
	if _det_row >= _det_img.get_height():
		# the sky that pours is the sky without these stars (the film's BARE): they pour as streaks
		var img := Image.create_from_data(w, _det_img.get_height(), false, Image.FORMAT_RGBA8, _det_data)
		stage.set1(&"stars_tex", ImageTexture.create_from_image(img))
		stage.set1(&"sky_box", Vector4(_sky_org.x, _sky_org.y, sc, 1.0))
		_det_img = null
		_det_data = PackedByteArray()


## The hull's textures go to the compose pass, which draws the stand-in.
func hull_ready() -> void:
	stage.hull_textures(hull, compose)
	compose.set_shader_parameter(&"hull_on", 1.0)


func step(t: float) -> void:
	_poll_detector()
	var kb := t - T_BURST
	var p := P(t)
	var th := throb(t)
	var rb := ball_r(t)
	var phase := 0
	if t >= T_SLAM and kb < 0.0:
		phase = 1
	elif kb >= 0.0 and kb < 1.5:
		phase = 2
	var ab0 := AB(t)
	stage.set1(&"phase", phase)
	var abs_ := PackedVector2Array()
	for j in 6:
		abs_.append(AB(t - float(j) * (1.0 / 14.0) / 5.0))
	stage.set1(&"ab", abs_)
	stage.set1(&"p_t", p)
	stage.set1(&"th", th)
	stage.set1(&"rb", rb)
	stage.set1(&"empty", 1.0 - ease3((t - T_FULL) / 0.25))
	stage.set1(&"charge", 0.7 * ease3((t - T_SLAM) / 0.25))
	stage.set1(&"kb", kb)
	# the stars: the pour's (A, B) now and 0.14 s ago, the burst's clock
	var ab1 := AB(t - 0.14)
	for m: JumpSparkQuads in [far_real, far_extra, near_extra]:
		m.set_p(&"phase", phase)
		m.set_p(&"ab0", ab0)
		m.set_p(&"ab1", ab1)
		m.set_p(&"p_t", p)
		m.set_p(&"rb", rb)
		m.set_p(&"vis", ease3((t - T_SLAM) / 0.12) * 0.9)
		m.set_p(&"kb", kb)
	sparks.set_p(&"kb", kb)
	_step_compose(t, kb, p, th, rb, ab0)
	# the finish: two white frames, the fringe and a 7 px shake on the burst
	var fl := 0.0
	if kb >= 0.0 and kb < 0.25:
		fl = 4.0 if kb < 1.5 / 60.0 else 4.0 * exp(-(kb - 1.5 / 60.0) / 0.006)
	set_flash(fl * 10.0, pc, 1.0)
	var cf := 4.0 * exp(-kb / 0.14) if (kb >= 0.0 and kb < 0.6) else 0.0
	stage.set2(&"fringe", cf if cf >= 0.5 else 0.0)
	stage.set2(&"centre", pc)
	var sh := Vector2.ZERO
	if kb >= 0.0 and kb < 0.7:
		sh = Vector2(smooth_noise(t, 0, 14.0), smooth_noise(t, 1, 14.0) * 0.8) * 7.0 * exp(-kb / 0.15)
	set_shake(sh)


## The light's and the hull's part of the instant, to the compose pass.
func _step_compose(t: float, kb: float, p: float, th: float, rb: float, ab0: Vector2) -> void:
	var c := compose
	var gone := kb >= 0.0
	c.set_shader_parameter(&"t", t)
	c.set_shader_parameter(&"p_t", p)
	c.set_shader_parameter(&"th", th)
	c.set_shader_parameter(&"rb", rb)
	c.set_shader_parameter(&"ab0", ab0)
	c.set_shader_parameter(&"kb", kb)
	var edge_on := t >= T_SLAM and t < T_FULL + 0.3 and not gone
	c.set_shader_parameter(&"edge_k", ease3((t - T_SLAM) / 0.08) * (1.0 - ease3((t - T_FULL) / 0.3)) if edge_on else 0.0)
	c.set_shader_parameter(&"lobe_k", ease3((t - T_SLAM) / 0.4))
	var b0 := float(BEATS[0])
	var aura := 0.0
	if t >= T_SLAM and t < b0 + 0.1 and not gone:
		aura = (0.35 + 1.4 * p + 0.9 * th) * (1.0 - ease3((rb - 90.0 * hk) / (60.0 * hk))) * minf(1.0, (t - T_SLAM) / 0.05)
	c.set_shader_parameter(&"aura", aura)
	var ball_on := t >= T_SLAM and rb > 0.5 and t < T_HOLD
	c.set_shader_parameter(&"ball", Vector2(1.0 if ball_on else 0.0, ease3((t - b0) / (T_HOLD - b0))))
	var bk := PackedFloat32Array()
	for b: float in BEATS:
		var k2 := t - b - 0.06
		bk.append(k2 if (k2 >= 0.0 and k2 < 0.5) else -1.0)
	c.set_shader_parameter(&"beat_k", bk)
	var hold := Vector4.ZERO
	if t >= T_HOLD and not gone:
		var k := t - T_HOLD
		var inhale := 1.0 - ease3((t - (T_BURST - 0.07)) / 0.07)
		hold = Vector4(k, inhale, (1.0 + 0.25 * sin(TAU * k / 0.68 - 1.2)) * inhale, 1.0)
	c.set_shader_parameter(&"hold", hold)
	c.set_shader_parameter(&"slam_k", t - T_SLAM if (t >= T_SLAM and t < T_SLAM + 0.5) else -1.0)
	# the hull: lit by the light pouring in, trembling, darkening against the ball, crushed
	var fsc := hull_scale(t)
	var show := not gone and fsc > 0.02 and t < T_HOLD
	c.set_shader_parameter(&"show_ship", 1.0 if show else 0.0)
	c.set_shader_parameter(&"fsc", fsc)
	c.set_shader_parameter(&"sil", ease3((t - 4.25) / 0.35))
	c.set_shader_parameter(&"lit_on", 1.0 if t >= T_SLAM else 0.0)
	var tremble := Vector2.ZERO
	if t > 2.4 and t < b0:
		var s := ease3((t - 2.4) / 1.6)
		var fr := int(floor(t * 24.0))
		if held_rand(fr, 1) < 0.6 * s:
			tremble.x = float(int(held_rand(fr, 2) * 3.0) - 1)
		if held_rand(fr, 3) < 0.6 * s:
			tremble.y = float(int(held_rand(fr, 4) * 3.0) - 1)
	c.set_shader_parameter(&"tremble", tremble)
	var gt := PackedFloat32Array()
	for b: float in GULPS:
		var dtp := t - b
		if dtp >= 0.0 and dtp < 0.5 and gt.size() < 4:
			gt.append(dtp)
	c.set_shader_parameter(&"gulp_n", gt.size())
	gt.resize(4)
	c.set_shader_parameter(&"gulp_t", gt)


func teardown() -> void:
	if _det != null and is_instance_valid(_det):
		_det.queue_free()
	_det = null
