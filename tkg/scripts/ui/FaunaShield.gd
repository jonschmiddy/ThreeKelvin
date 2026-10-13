class_name FaunaShield
extends ShieldFx

## BLOCK ON A CREATURE (`FaunaGuard`), Jon's pick of three ("block:A", Oct 13):
## GLOW SKIN. The creature's own outline lit in block's cold blue, a pixel out
## and two in, breathing with its swell (brighter as it fills), two packets of
## light running head to tail and single pixels sparking. Up: the light runs
## from the head to the tail. A soaked hit: a ring of light runs out over the
## skin from where it struck. At 0 it gutters out, each pixel sputtering and
## going at its own moment. (The other two, spores and a membrane, were not
## picked and are gone.)
## Same calls as the bubble (`gain`, `hit`, `expire`, `through`), same moments.

var body: FaunaGuard.Body
var changes := 0

var _clock := FaunaGuard.Clock.new()
var _skin: FaunaGuard.GuardSkin
var _data: ImageTexture
var _gain_t := -9.0
var _hit_t := -9.0
var _hit_at := Vector2.ZERO
var _hit_s := 0.0
var _bound: FaunaMotion = null
var _last_sig := 0
var _since_step := 0
## Rest-space points just outside the outline, for impacts.
var _edge: Array[Vector2] = []

const FIZZ := 0.7
const BLOCK_COL_V := Vector3(0.486, 0.847, 1.0)


func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	facing = the_facing
	_origin = origin.round()
	_rng.seed = seed * 613 + 1
	_clock.fps = body.fps
	var b := body
	for y in b.H:
		for x in b.W:
			var d := b.dout[y * b.W + x]
			if d >= 3 and d <= 4:
				_edge.append(Vector2(x, y))
	_cc = b.centre()
	_skin = FaunaGuard.GuardSkin.new()
	_skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skin.make(b, FaunaGuard.skin_code(true, SKIN_A))
	_skin.paint = _paint_skin
	_data = ImageTexture.create_from_image(_build_glow())
	_skin.mat.set_shader_parameter("col", BLOCK_COL_V)
	_skin.mat.set_shader_parameter("fps", body.fps)
	add_child(_skin)


# ------------------------------------------------------------------ the picture

## The rim, a pixel out at full, two out faint and dithered, the first
## pixel in at half and the second a quarter, dithered. G: a hash per pixel
## (when it sparks, when it goes out).
func _build_glow() -> Image:
	var b := body
	var im := Image.create(b.W, b.H, false, Image.FORMAT_RGBA8)
	for y in b.H:
		for x in b.W:
			var i := y * b.W + x
			var lv := 0.0
			var o := b.dout[i]
			var n := b.din[i]
			var odd := ((x + y) & 1) == 0
			if o >= 3 and o <= 4:
				lv = 1.0
			elif o >= 6 and o <= 8 and odd:
				lv = 0.3
			elif o == 0 and n >= 3 and n <= 4:
				lv = 0.55
			elif o == 0 and n >= 6 and n <= 8 and odd:
				lv = 0.25
			if lv > 0.0:
				im.set_pixel(x, y, Color(lv, FaunaGuard.hash01(x, y), 0.0, 1.0))
	return im


# ------------------------------------------------------------------ the calls

func gain(amount: int) -> void:
	if amount <= 0:
		return
	var fresh := not _up or _fizz_t >= 0.0
	block += amount
	if fresh:
		_up = true
		_fizz_t = -1.0
		_gain_t = t
	else:
		_hit_t = t
		_hit_at = _cc
		_hit_s = 0.4
	moment.emit(&"shield_up", minf(1.0, float(amount) / 10.0), 0.35)


func hit(amount: int) -> int:
	if block <= 0:
		return amount
	var q := _impact()
	if amount < block:
		var frac := float(amount) / float(block)
		block -= amount
		_soak(q, frac)
		moment.emit(&"shield_hit", frac, SHIMMER)
		return 0
	var over := amount - block
	block = 0
	_soak(q, 1.0)
	moment.emit(&"shield_break", 1.0, 0.0)
	_fizzle()
	if over > 0:
		_pending.append({t = t + 0.1, amount = over, at = _origin + q})
	return over


func _soak(q: Vector2, frac: float) -> void:
	_hit_t = t
	_hit_at = q
	_hit_s = 0.6 + 0.4 * minf(1.0, frac * 2.0)


func expire() -> void:
	if block <= 0:
		return
	block = 0
	_fizzle()


func _fizzle() -> void:
	if not _up:
		return
	_fizz_t = t
	moment.emit(&"shield_fizzle", 0.5, FIZZ)


## Where a shot strikes: a point just outside the outline on the side it comes
## from (rest space).
func _impact() -> Vector2:
	if _edge.is_empty():
		return _cc
	var best := -1e9
	var bp := _cc
	for i in 40:
		var p := _edge[_rng.randi() % _edge.size()]
		var s := float(facing) * (p.x - _cc.x) / maxf(1.0, float(body.r.size.x) * 0.5) + _rng.randf() * 0.35
		# not under the belly (the readout is there)
		if p.y > _cc.y + float(body.r.size.y) * 0.3:
			s -= 1.0
		if s > best:
			best = s
			bp = p
	return bp


# ------------------------------------------------------------------ time

func advance(delta: float) -> void:
	t += delta
	var keep: Array = []
	for p in _pending:
		if t >= float(p.t):
			through.emit(int(p.amount), p.at)
		else:
			keep.append(p)
	_pending = keep
	if _fizz_t >= 0.0 and t - _fizz_t >= FIZZ + 0.3:
		_up = false
		_fizz_t = -1.0
	var fm := FaunaGuard.motion_of(self)
	if fm != _bound:
		_bound = fm
		_clock.bind(t, fm)
	var tq := _clock.tq(t)
	_skin.follow(fm, tq + _clock.phase, FaunaGuard.keep_of(self))
	_skin.mat.set_shader_parameter("lvl", 1.0 if _up else 0.0)
	_skin.mat.set_shader_parameter("gain_age", tq - _gain_t if _up else -1.0)
	_skin.mat.set_shader_parameter("hit_age", tq - _hit_t if tq - _hit_t < 0.6 else -1.0)
	_skin.mat.set_shader_parameter("hit_at", _hit_at)
	_skin.mat.set_shader_parameter("hit_s", _hit_s)
	_skin.mat.set_shader_parameter("fizz_age", tq - _fizz_t if _fizz_t >= 0.0 else -1.0)
	_skin.visible = _up
	var st := _clock.index(t)
	if st != _clock.step:
		_clock.step = st
		_since_step = 0
		_skin.queue_redraw()
	else:
		_since_step += 1
	# a shape change: the skin's step while it is up (counted once a step, on
	# the frame after it)
	if _since_step == 1:
		var sig := st if _up else 0
		if sig != _last_sig:
			changes += 1
		_last_sig = sig


func _paint_skin(ci: CanvasItem) -> void:
	if _up:
		ci.draw_texture(_data, Vector2.ZERO)


# ------------------------------------------------------------------ the shader

const SKIN_A := """
uniform vec3 col;
uniform float fps = 8.0;
uniform float lvl;
uniform float gain_age = -1.0;
uniform float hit_age = -1.0;
uniform vec2 hit_at;
uniform float hit_s;
uniform float fizz_age = -1.0;

void fragment() {
	ivec2 p = ivec2(floor(UV * csize));
	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	if (kept(p)) { return; }
	int part;
	ivec2 r = rest_of(p, part);
	if (!inb(r)) { return; }
	vec4 d = texelFetch(TEXTURE, r, 0);
	if (d.a < 0.5 || d.r <= 0.0) { return; }
	float u = uof(float(r.x));
	float b = breath(u);
	float base = d.r * (0.62 + 0.38 * b);
	float L = base;
	float pk = 0.0;
	for (int k = 0; k < 2; k++) {
		float pos = fract(ts / 1.9 + float(k) * 0.5) * 1.4 - 0.2;
		pk = max(pk, bump((u - pos) / 0.07));
	}
	L += d.r * 0.6 * pk;
	float st = floor((ts) * fps + 0.001);
	float h = fract(d.g * 113.0 + st * 0.6180339);
	if (h < 0.05) { L += 0.5 * d.r; }
	if (gain_age >= 0.0 && gain_age < 0.45) {
		float f = gain_age / 0.35;
		if (u > f) { L = 0.0; }
		else if (u > f - 0.08) { L += 0.7 * d.r; }
	}
	if (hit_age >= 0.0 && hit_age < 0.55) {
		float rr = hit_age * 170.0;
		float dist = length(vec2(r) - hit_at);
		float dd = abs(dist - rr);
		float f = (1.0 - hit_age / 0.55) * hit_s;
		L += (dd < 3.0 ? 0.9 : (dd < 7.0 ? 0.35 : 0.0)) * f * max(d.r, 0.5);
		if (hit_age < 0.13 && dist < 10.0) { L += 0.9 * hit_s; }
	}
	if (fizz_age >= 0.0) {
		float die = 0.12 + d.g * 0.55;
		if (fizz_age >= die) { return; }
		float hs = fract(d.g * 71.0 + st * 0.37);
		L = hs < 0.2 ? (0.9 * d.r + 0.25) : (hs < 0.55 ? 0.06 : base * (1.0 - fizz_age / die));
	}
	L *= lvl;
	float k8 = q8(L, p);
	COLOR = vec4(col * k8 * md.rgb, 1.0);
}
"""
