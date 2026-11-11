class_name TierGalaxy
extends Control

## The tier's galaxy on the LAUNCH A RUN box (Jon's v2, Nov 9): 112 px of
## procedural pixel art, animated. The body is a dithered glow drawn by
## `tier_galaxy.gdshader`; over it, whole-pixel stars that move smoothly and
## twinkle, and flares from the core. Everything rises with the tier.
## Why: docs/why/Ladder.md#the-galaxy

const G := 112
const RED := Color8(255, 60, 40)
const MID := [Color8(120, 150, 225), Color8(235, 185, 105), Color8(245, 115, 55), Color8(255, 80, 70)]
const COOL := Color8(140, 165, 230)
const PANEL := Color8(17, 24, 35)
## The stars step on a 30 Hz clock, as a film of them would.
const HZ := 30.0

var tier: int = 0
var form: int = 0
var heat: float = 0.0
var omega: float = 0.12
var twinkle: float = 0.12
var pulse_amp: float = 0.04
var pulse_t: float = 3.4
var flare_rate: float = 0.0
var glare: float = 0.0
var bloom: float = 0.65
var tilt: float = 0.52
var rot: float = 0.0
var mid: Color = MID[0]
var core: Color = Color8(255, 244, 220)

var _t: float = 0.0
var _tick: int = -1
var _stars: Array[Dictionary] = []
var _far: Array[Vector2i] = []
var _flares: Array[Array] = []
var _rng := RandomNumberGenerator.new()
var _body: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(G, G)
	size = Vector2(G, G)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body = ColorRect.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = Vector2(G, G)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/tier_galaxy.gdshader")
	_body.material = _mat
	add_child(_body)
	# the far stars behind it, the same every time
	var far := RandomNumberGenerator.new()
	far.seed = 3
	for i in 26:
		_far.append(Vector2i(far.randi_range(0, G - 1), far.randi_range(0, G - 1)))


## Build the galaxy for a tier: its heat, colours, shape and stars.
func set_tier(t: int) -> void:
	tier = clampi(t, 0, Ladder.count() - 1)
	form = int(Ladder.form(tier))
	var h := float(tier) / 10.0
	heat = h
	omega = 0.12 + 1.2 * pow(h, 1.6)
	twinkle = 0.12 + 0.7 * h
	pulse_amp = 0.04 + 0.36 * h
	pulse_t = 3.4 - 2.8 * h
	flare_rate = 0.0 if tier < 4 else (0.4 + 1.2 * float(tier - 4) / 6.0)
	glare = maxf(0.0, float(tier - 2) / 8.0)
	bloom = 0.65 + 0.6 * h
	var within: float = [h * 10.0 / 3.0, float(tier - 4) / 2.0, float(tier - 7) / 2.0, 1.0][form]
	mid = MID[form].lerp(RED, 0.35 * clampf(within, 0.0, 1.0))
	core = Color8(255, 244, 220).lerp(Color8(255, 200, 170), h)
	tilt = [0.52, 0.28, 0.92, 0.5][form]
	rot = deg_to_rad(-22.0) if form == 3 else 0.0
	_rng.seed = 7 + tier
	_stars.clear()
	_flares.clear()
	_seed_stars()
	_mat.set_shader_parameter(&"form", form)
	_mat.set_shader_parameter(&"omega", omega)
	_mat.set_shader_parameter(&"bloom", bloom)
	_mat.set_shader_parameter(&"glare", glare)
	_mat.set_shader_parameter(&"heat", heat)
	_mat.set_shader_parameter(&"tilt", tilt)
	_mat.set_shader_parameter(&"rot", rot)
	_mat.set_shader_parameter(&"mid", Vector3(mid.r, mid.g, mid.b))
	_mat.set_shader_parameter(&"core", Vector3(core.r, core.g, core.b))
	_mat.set_shader_parameter(&"cool", Vector3(COOL.r, COOL.g, COOL.b))
	_mat.set_shader_parameter(&"panel", Vector3(PANEL.r, PANEL.g, PANEL.b))
	_tick = -1
	queue_redraw()


func _seed_stars() -> void:
	var r := _rng
	if form == 3:
		for i in 90:
			_stars.append({kind = &"core", r = r.randf(), a = r.randf() * 6.3, b = r.randf_range(0.5, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.12})
		for i in 170:
			_stars.append({kind = &"tail", u = r.randf(), w = r.randfn(0.0, 2.6), sp = r.randf_range(0.05, 0.11), b = r.randf_range(0.5, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.15})
		for i in 120:
			var arm := r.randi_range(0, 1)
			var rr := 8.0 + 50.0 * pow(r.randf(), 0.85)
			var a := float(arm) * PI + log(1.0 + rr / 7.0) * 2.1 + r.randfn(0.0, 0.2)
			_stars.append({kind = &"arm", r = rr, a = a, b = r.randf_range(0.4, 0.9), ph = r.randf() * 6.3, big = r.randf() < 0.06})
		return
	var n: int = [240, 200, 300][form]
	for i in n:
		var u := r.randf()
		if form == 0:
			var arm := r.randi_range(0, 1)
			var rr := 5.0 + 46.0 * pow(u, 0.85)
			var a := float(arm) * PI + log(1.0 + rr / 6.0) * 2.1 + r.randfn(0.0, 0.22)
			_stars.append({kind = &"orbit", r = rr, a = a, s = 1.0, inc = 0.0, b = r.randf_range(0.5, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.08})
		elif form == 1:
			var rr := 4.0 + 48.0 * pow(u, 0.6)
			_stars.append({kind = &"orbit", r = rr, a = r.randf() * 6.3, s = 1.0, inc = 0.0, b = r.randf_range(0.4, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.06})
		else:
			var rr := 3.0 + 48.0 * pow(u, 1.7)
			var sp := r.randf_range(0.5, 1.6) * (-1.0 if r.randf() < 0.5 else 1.0)
			_stars.append({kind = &"ball", r = rr, a = r.randf() * 6.3, s = sp, inc = r.randf() * PI, b = r.randf_range(0.5, 1.0), ph = r.randf() * 6.3, big = r.randf() < 0.1})


func pulse() -> float:
	var p := sin(TAU * _t / pulse_t)
	if form == 3:
		# a stutter: the beat holds, drops, jumps, by a hash of the moment
		var step := int(_t * 9.0)
		var j := float((step * 7919) % 11) / 10.0
		p = 1.0 if j > 0.45 else -0.6
	return 1.0 + pulse_amp * p


func _process(delta: float) -> void:
	_t += delta
	var tick := int(floorf(_t * HZ))
	if tick == _tick:
		return
	var dt := float(tick - _tick) / HZ if _tick >= 0 else 0.0
	_tick = tick
	_mat.set_shader_parameter(&"t", _t)
	_mat.set_shader_parameter(&"pulse", pulse())
	if _rng.randf() < flare_rate * dt:
		_flares.append([_rng.randf() * 6.3, _t, _rng.randf_range(0.25, 0.5), _rng.randf_range(18.0, 40.0)])
	var keep: Array[Array] = []
	for f in _flares:
		if _t - float(f[1]) < float(f[2]):
			keep.append(f)
	_flares = keep
	queue_redraw()


func _bez(u: float) -> Vector2:
	var p0 := Vector2(90, 86)
	var p1 := Vector2(66, 112)
	var p2 := Vector2(24, 100)
	var p3 := Vector2(46, 60)
	var v := 1.0 - u
	return v * v * v * p0 + 3.0 * v * v * u * p1 + 3.0 * v * u * u * p2 + u * u * u * p3


func _draw() -> void:
	# the far stars behind the body are under the ColorRect: drawn by the parent, they
	# would be over it, so the body rect is kept transparent where the glow is none
	for p in _far:
		draw_rect(Rect2(p.x, p.y, 1, 1), Color8(40, 52, 68) if (p.x * 7 + p.y * 13) % 10 < 7 else Color8(70, 84, 104))
	var th := omega * _t
	var c := G / 2.0
	var dw := Vector2(90, 86)
	for st in _stars:
		var x := 0.0
		var y := 0.0
		var fade := 1.0
		var base := mid
		match st.kind:
			&"core":
				var rr := pow(float(st.r), 0.7) * 8.0
				var a := float(st.a) + th * 0.8
				x = dw.x - c + rr * cos(a)
				y = dw.y - c + rr * sin(a) * 0.8
			&"tail":
				var u := fmod(float(st.u) + _t * float(st.sp), 1.0)
				var p := _bez(u)
				var a0 := _bez(maxf(0.0, u - 0.01))
				var b0 := _bez(minf(1.0, u + 0.01))
				var tg := (b0 - a0).normalized()
				var nrm := Vector2(-tg.y, tg.x)
				x = p.x - c + nrm.x * float(st.w)
				y = p.y - c + nrm.y * float(st.w)
				fade = 1.0 - u * u * 0.9
				base = mid.lerp(COOL, u * u)
			&"arm":
				var a := float(st.a) + th * 0.3
				x = 34.0 - c + float(st.r) * cos(a)
				y = 30.0 - c + float(st.r) * sin(a) * 0.55
				base = COOL
			&"ball":
				var a := float(st.a) + th * float(st.s)
				x = float(st.r) * cos(a)
				y = float(st.r) * sin(a) * cos(float(st.inc)) * 0.92
			_:
				var a := float(st.a) + th
				x = float(st.r) * cos(a)
				y = float(st.r) * sin(a) * tilt
		var tw := 1.0 - twinkle * (0.5 + 0.5 * sin(_t * (2.5 + 9.0 * heat) + float(st.ph)))
		var b := float(st.b) * tw * fade
		if b < 0.18:
			continue
		var px := int(round(c + x))
		var py := int(round(c + y))
		if px < 0 or px >= G or py < 0 or py >= G:
			continue
		var col := base.lerp(Color.WHITE, minf(1.0, b))
		draw_rect(Rect2(px, py, 1, 1), col)
		if bool(st.big) and b > 0.6:
			var half := col.lerp(mid, 0.5)
			draw_rect(Rect2(px + 1, py, 1, 1), half)
			draw_rect(Rect2(px, py + 1, 1, 1), half)
	var fc := dw if form == 3 else Vector2(c, c)
	for f in _flares:
		var age := (_t - float(f[1])) / float(f[2])
		var L := float(f[3]) * (0.5 if form == 3 else 1.0) * minf(1.0, age * 3.0)
		var a := float(f[0])
		var from := Vector2(fc.x + cos(a) * 6.0, fc.y + sin(a) * 6.0 * tilt).round()
		var to := Vector2(fc.x + cos(a) * L, fc.y + sin(a) * L * tilt).round()
		draw_line(from, to, mid.lerp(Color.WHITE, (1.0 - age) * 0.9), 1.0)
