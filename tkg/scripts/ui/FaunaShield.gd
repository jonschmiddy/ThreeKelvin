class_name FaunaShield
extends ShieldFx

## BLOCK ON A CREATURE (`FaunaGuard`): three ideas, `FaunaGuard.block_look`.
##   A  GLOW SKIN: the creature's own outline lit in block's cold blue, a pixel
##      out and two in, breathing with its swell (brighter as it fills), two
##      packets of light running head to tail and single pixels sparking. Up:
##      the light runs from the head to the tail. A soaked hit: a ring of light
##      runs out over the skin from where it struck. At 0 it gutters out, each
##      pixel sputtering and going at its own moment.
##   B  SPORES: a cloud of motes hugging the body, two to six pixels out, each
##      circling its own spot, twinkling. Up: they bloom out of the skin. A
##      soaked hit: the motes near it go up in puffs and the cloud thins with
##      the block. At 0 the last of it drifts off.
##   C  MEMBRANE: a faint skin a few pixels out, smoothed round the body, veined,
##      its edge rippling in a slow wave on top of the body's own swell. A soaked
##      hit dents it where it struck, springing back, and lights its veins. At 0
##      it tears open from the hit and the torn edge runs round it.
## Same calls as the bubble (`gain`, `hit`, `expire`, `through`), same moments.

var body: FaunaGuard.Body
var look := 0
var changes := 0

var _clock := FaunaGuard.Clock.new()
var _skin: FaunaGuard.GuardSkin
var _dots: FaunaGuard.GuardSkin
var _data: ImageTexture
var _gain_t := -9.0
var _hit_t := -9.0
var _hit_at := Vector2.ZERO
var _hit_s := 0.0
var _peak := 1
var _bound: FaunaMotion = null
var _last_sig := 0
var _since_step := 0
var _drops := FaunaGuard.Motes.new()
## Look B's cloud: {a (rest Vector2), root (rest), r (orbit), w, ph, big, alive, t_on, t_off}
var _spores: Array = []
var _puffs: Array = []
## Rest-space points just outside the outline, for impacts and tears.
var _edge: Array[Vector2] = []
var _tear_at := Vector2.ZERO

const FIZZ := 0.7


func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	facing = the_facing
	_origin = origin.round()
	_rng.seed = seed * 613 + 1
	look = clampi(FaunaGuard.block_look, 0, 2)
	_clock.fps = body.fps
	var b := body
	for y in b.H:
		for x in b.W:
			var d := b.dout[y * b.W + x]
			if d >= 3 and d <= 4:
				_edge.append(Vector2(x, y))
	_cc = b.centre()
	if look == 1:
		_build_spores()
	else:
		_skin = FaunaGuard.GuardSkin.new()
		_skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_skin.make(b, FaunaGuard.skin_code(true, SKIN_A if look == 0 else SKIN_C))
		_skin.paint = _paint_skin
		_data = ImageTexture.create_from_image(_build_glow() if look == 0 else _build_membrane())
		_skin.mat.set_shader_parameter("col", BLOCK_COL_V)
		_skin.mat.set_shader_parameter("fps", body.fps)
		add_child(_skin)
	_dots = FaunaGuard.GuardSkin.new()
	_dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_dots.material = m
	_dots.paint = _paint_dots
	add_child(_dots)


const BLOCK_COL_V := Vector3(0.486, 0.847, 1.0)


# ------------------------------------------------------------------ the pictures

## Look A: the rim, a pixel out at full, two out faint and dithered, the first
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


## Look C: the membrane, the body grown six pixels and smoothed (a box blur
## thresholded), so it is one soft skin and not the spines' outline. R its edge
## (the outer pixel full, the next in dithered), G its fill (outside the body
## faint, over the body fainter), B its veins (random walks out from the body),
## A 1 inside it.
func _build_membrane() -> Image:
	var b := body
	var W := b.W
	var H := b.H
	var grow := 6 if b.scale >= 1.0 else 4
	var m := PackedFloat32Array()
	m.resize(W * H)
	for i in W * H:
		m[i] = 1.0 if b.dout[i] <= grow * 3 else 0.0
	var rad := 3
	var tmp := PackedFloat32Array()
	tmp.resize(W * H)
	for y in H:
		for x in W:
			var s := 0.0
			for dx in range(-rad, rad + 1):
				s += m[y * W + clampi(x + dx, 0, W - 1)]
			tmp[y * W + x] = s / float(rad * 2 + 1)
	var env := PackedByteArray()
	env.resize(W * H)
	for y in H:
		for x in W:
			var s2 := 0.0
			for dy in range(-rad, rad + 1):
				s2 += tmp[clampi(y + dy, 0, H - 1) * W + x]
			env[y * W + x] = 1 if s2 / float(rad * 2 + 1) > 0.5 else 0
	# the body is always inside
	for i in W * H:
		if b.ink[i] == 1:
			env[i] = 1
	var im := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var edge := PackedByteArray()
	edge.resize(W * H)
	for y in H:
		for x in W:
			var i := y * W + x
			if env[i] == 0:
				continue
			var e := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + o.x
				var yy: int = y + o.y
				if xx < 0 or yy < 0 or xx >= W or yy >= H or env[yy * W + xx] == 0:
					e = true
			edge[i] = 1 if e else 0
	for y in H:
		for x in W:
			var i := y * W + x
			if env[i] == 0:
				continue
			var r := 0.0
			if edge[i] == 1:
				r = 1.0
			else:
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var j: int = (y + o.y) * W + x + o.x
					if edge[j] == 1 and ((x + y) & 1) == 0:
						r = 0.4
			var g := 0.0 if r > 0.0 else (0.45 if b.ink[i] == 1 else 1.0)
			im.set_pixel(x, y, Color(r, g, 0.0, 1.0))
	# veins: from the body's edge out into the skin, wandering, one branch each
	var starts: Array[Vector2i] = []
	for y in H:
		for x in W:
			var i := y * W + x
			if b.dout[i] >= 3 and b.dout[i] <= 4 and env[i] == 1:
				starts.append(Vector2i(x, y))
	var nv := clampi(starts.size() / 22, 8, 26)
	for k in nv:
		if starts.is_empty():
			break
		var p: Vector2i = starts[_rng.randi() % starts.size()]
		var away := (Vector2(p) - b.centre()).normalized()
		_vein(im, env, b, p, away, 5 + _rng.randi() % 6, true)
	return im


func _vein(im: Image, env: PackedByteArray, b: FaunaGuard.Body, p0: Vector2i, dir: Vector2, n: int, branch: bool) -> void:
	var p := Vector2(p0)
	var d := dir
	for s in n:
		d = d.rotated(_rng.randf_range(-0.6, 0.6)).normalized()
		p += d
		var q := Vector2i(p.round())
		if q.x < 0 or q.y < 0 or q.x >= b.W or q.y >= b.H or env[q.y * b.W + q.x] == 0:
			return
		var c := im.get_pixel(q.x, q.y)
		if c.r >= 1.0:
			return
		im.set_pixel(q.x, q.y, Color(c.r, c.g, 1.0 if s < n / 2 else 0.6, 1.0))
		if branch and s == n / 2:
			_vein(im, env, b, q, d.rotated(0.9 * (1.0 if _rng.randf() < 0.5 else -1.0)), n / 2, false)


## Look B: the cloud's motes, on spots two to six pixels out (not under the
## belly far: a cloud hanging toward the readout is cut there anyway).
func _build_spores() -> void:
	var b := body
	var cand: Array[Vector2i] = []
	for y in b.H:
		for x in b.W:
			var d := b.dout[y * b.W + x]
			if d >= 4 and d <= 16:
				cand.append(Vector2i(x, y))
	var n := clampi(_edge.size(), 140, 320)
	if b.scale < 1.0:
		n = n / 2
	for k in n:
		if cand.is_empty():
			break
		var a: Vector2i = cand[_rng.randi() % cand.size()]
		# the root: the nearest ink in its column, else its own spot
		var root := Vector2(a)
		var tp := b.top[a.x]
		var bt := b.bot[a.x]
		if tp >= 0:
			root = Vector2(a.x, clampi(a.y, tp, bt))
		_spores.append({a = Vector2(a), root = root, r = 1.0 + float(_rng.randi() % 2), w = TAU / _rng.randf_range(1.2, 2.6),
			ph = _rng.randf() * TAU, big = _rng.randf() < 0.3, alive = false, t_on = -9.0, t_off = -9.0,
			h = _rng.randi() % 997, kick = Vector2.ZERO, kick_t = -9.0})


# ------------------------------------------------------------------ the calls

func gain(amount: int) -> void:
	if amount <= 0:
		return
	var fresh := not _up or _fizz_t >= 0.0
	block += amount
	if fresh:
		_up = true
		_fizz_t = -1.0
		_peak = block
		_gain_t = t
		_drops.list.clear()
		if look == 1:
			var k := 0
			for s in _spores:
				s.alive = true
				s.t_off = -9.0
				s.t_on = t + 0.35 * FaunaGuard.hash01(int(s.h), 3)
				k += 1
	else:
		_peak = maxi(_peak, block)
		_hit_t = t
		_hit_at = _cc
		_hit_s = 0.4
		if look == 1:
			for s in _spores:
				if not s.alive:
					s.alive = true
					s.t_off = -9.0
					s.t_on = t + 0.3 * FaunaGuard.hash01(int(s.h), 5)
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
	if look == 1:
		_puff(q, frac)


func expire() -> void:
	if block <= 0:
		return
	block = 0
	_fizzle()


func _fizzle() -> void:
	if not _up:
		return
	_fizz_t = t
	_tear_at = _hit_at if t - _hit_t < 0.6 else _impact()
	var fm := FaunaGuard.motion_of(self)
	if look == 1:
		for s in _spores:
			if s.alive:
				s.alive = false
				s.t_off = t + 0.25 * FaunaGuard.hash01(int(s.h), 9)
	elif look == 2:
		# the torn skin flicks off as a few drops
		for i in 10:
			var p := _edge[_rng.randi() % _edge.size()] if not _edge.is_empty() else _cc
			if p.distance_to(_tear_at) > 40.0:
				continue
			var dv := (p - _cc).normalized()
			_drops.add(FaunaGuard.shown(fm, p), dv * _rng.randf_range(14.0, 32.0), _rng.randf_range(0.35, 0.6),
				t + _rng.randf_range(0.0, 0.25), [Color("#cff2ff"), Color("#7cd8ff"), Color("#3a6f90")], 2.0)
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


## Look B: the motes near the hit go up in puffs, more the bigger the share of
## block it took; the rest are shoved off and drift back.
func _puff(q: Vector2, frac: float) -> void:
	var fm := FaunaGuard.motion_of(self)
	_puffs.append({p = FaunaGuard.shown(fm, q), t0 = t, r = 10.0, big = true})
	var near: Array = []
	for s in _spores:
		if s.alive and (s.a as Vector2).distance_to(q) < 22.0:
			near.append(s)
	near.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool:
		return (a.a as Vector2).distance_to(q) < (b2.a as Vector2).distance_to(q))
	var lose := int(ceil(float(near.size()) * clampf(0.25 + frac * 1.2, 0.0, 1.0)))
	for i in near.size():
		var s2: Dictionary = near[i]
		if i < lose:
			s2.alive = false
			s2.t_off = t
			if i % 2 == 0:
				_puffs.append({p = FaunaGuard.shown(fm, s2.a), t0 = t + 0.04 * float(i % 5), r = 3.0 + float(i % 4), big = false})
		else:
			s2.kick = ((s2.a as Vector2) - q).normalized() * 3.0
			s2.kick_t = t
	# the cloud thins to the block left
	var want := int(float(_spores.size()) * (0.3 + 0.7 * float(block) / float(maxi(1, _peak))))
	var alive: Array = _spores.filter(func(s3: Dictionary) -> bool: return s3.alive)
	alive.sort_custom(func(a: Dictionary, b2: Dictionary) -> bool:
		return (a.a as Vector2).distance_to(q) < (b2.a as Vector2).distance_to(q))
	for j in maxi(0, alive.size() - want):
		alive[j].alive = false
		alive[j].t_off = t + 0.05


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
	_puffs = _puffs.filter(func(p2: Dictionary) -> bool: return tq - float(p2.t0) < 0.5)
	_drops.prune(tq)
	var ks := FaunaGuard.keep_of(self)
	if _skin != null:
		_skin.follow(fm, tq + _clock.phase, ks)
		var lvl := 0.0
		if _up:
			lvl = 1.0
		_skin.mat.set_shader_parameter("lvl", lvl)
		_skin.mat.set_shader_parameter("gain_age", tq - _gain_t if _up else -1.0)
		_skin.mat.set_shader_parameter("hit_age", tq - _hit_t if tq - _hit_t < 0.6 else -1.0)
		_skin.mat.set_shader_parameter("hit_at", _hit_at)
		_skin.mat.set_shader_parameter("hit_s", _hit_s)
		_skin.mat.set_shader_parameter("fizz_age", tq - _fizz_t if _fizz_t >= 0.0 else -1.0)
		_skin.mat.set_shader_parameter("tear_at", _tear_at)
		_skin.visible = _up
	var st := _clock.index(t)
	if st != _clock.step:
		_clock.step = st
		_since_step = 0
		if _skin != null:
			_skin.queue_redraw()
		_dots.queue_redraw()
	else:
		_since_step += 1
	# a shape change: the skin's step while it is up and something moves, or
	# the motes' picture changing
	var sig := 0
	if _skin != null and _up:
		sig = st
	sig = sig * 7919 + _dots.sig
	# counted once a step, on the frame after it (the step's paint is in)
	if _since_step == 1:
		if sig != _last_sig:
			changes += 1
		_last_sig = sig


func _paint_skin(ci: CanvasItem) -> void:
	if _up:
		ci.draw_texture(_data, Vector2.ZERO)


func _paint_dots(ci: CanvasItem) -> void:
	var keep := FaunaGuard.keep_of(self)
	var fm := FaunaGuard.motion_of(self)
	var tq := _clock.tq(t)
	var st := _clock.index(t)
	var h := 0
	if look == 1:
		h = _paint_spores(ci, keep, fm, tq, st)
	for pf in _puffs:
		var a := tq - float(pf.t0)
		if a < 0.0:
			continue
		var f := a / 0.45
		var rr := 1.0 + (float(pf.r) - 1.0) * (1.0 - pow(1.0 - f, 2.0))
		var lvl := (0.85 if f < 0.25 else (0.6 if f < 0.5 else (0.35 if f < 0.75 else 0.15)))
		var c := FaunaGuard.lv(Color("#bff4ff"), lvl)
		var c2 := FaunaGuard.lv(FaunaGuard.BLOCK_COL, lvl * 0.5)
		var cp := (pf.p as Vector2).round()
		var ri := int(ceil(rr))
		for y in range(-ri, ri + 1):
			for x in range(-ri, ri + 1):
				var d := Vector2(x, y).length()
				if d > rr:
					continue
				if d > rr - 1.2:
					if FaunaGuard.dot(ci, keep, cp + Vector2(x, y), c):
						h = h * 31 + x * 3 + y
				elif ((x + y + st) & 1) == 0:
					FaunaGuard.dot(ci, keep, cp + Vector2(x, y), c2)
	h = h * 31 + _drops.paint(ci, keep, tq)
	_dots.sig = h


func _paint_spores(ci: CanvasItem, keep: Array, fm: FaunaMotion, tq: float, st: int) -> int:
	var h := 0
	var spread := 1.0
	for s in _spores:
		var on := float(s.t_on)
		var off := float(s.t_off)
		var showing: bool = s.alive and tq >= on
		var leaving: bool = not s.alive and off > -1.0 and tq >= off and tq - off < 0.6
		if not showing and not leaving:
			continue
		var a: Vector2 = s.a
		var p := a + Vector2(roundf(cos(float(s.w) * tq + float(s.ph)) * float(s.r)),
			roundf(sin(float(s.w) * tq + float(s.ph)) * float(s.r) * 0.7))
		var lvl := 0.8
		# blooming out of the skin
		var age := tq - on
		if showing and age < 0.3:
			p = (s.root as Vector2).lerp(p, age / 0.3).round()
			lvl = 0.9
		if float(s.kick_t) > -1.0:
			var ka := tq - float(s.kick_t)
			if ka < 0.5:
				p += ((s.kick as Vector2) * (1.0 - ka / 0.5)).round()
		if leaving:
			var la := tq - off
			p += ((a - _cc).normalized() * la * 28.0).round()
			lvl = 0.6 * (1.0 - la / 0.6)
			if _fizz_t >= 0.0 and FaunaGuard.hash01(int(s.h), st) < 0.3:
				lvl = 0.9
		var tw := FaunaGuard.hash01(int(s.h), st)
		if tw < 0.15:
			lvl = 1.15
		elif tw < 0.35:
			lvl *= 0.55
		p = FaunaGuard.shown(fm, p) if not leaving else p + Vector2(0, fm.off_at(int(a.x), int(a.y)) if fm != null else 0)
		var c := FaunaGuard.lv(Color("#a6f0ff"), lvl * spread)
		if FaunaGuard.dot(ci, keep, p, c):
			h = h * 31 + int(p.x) * 5 + int(p.y) * 17 + int(lvl * 8.0)
		# a clump: a second mote beside it, dimmer
		if s.big:
			var o2 := Vector2(1, 0) if (int(s.h) & 1) == 0 else Vector2(0, 1)
			FaunaGuard.dot(ci, keep, p.round() + o2, FaunaGuard.lv(FaunaGuard.BLOCK_COL, lvl * 0.55))
		if s.big and lvl >= 1.0:
			var arm := FaunaGuard.lv(FaunaGuard.BLOCK_COL, 0.35)
			for o in [Vector2(-1, 0), Vector2(0, -1)]:
				FaunaGuard.dot(ci, keep, p.round() + o, arm)
	return h


# ------------------------------------------------------------------ shaders

const SKIN_A := """
uniform vec3 col;
uniform float fps = 8.0;
uniform float lvl;
uniform float gain_age = -1.0;
uniform float hit_age = -1.0;
uniform vec2 hit_at;
uniform float hit_s;
uniform float fizz_age = -1.0;
uniform vec2 tear_at;

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

const SKIN_C := """
uniform vec3 col;
uniform float fps = 8.0;
uniform float lvl;
uniform float gain_age = -1.0;
uniform float hit_age = -1.0;
uniform vec2 hit_at;
uniform float hit_s;
uniform float fizz_age = -1.0;
uniform vec2 tear_at;

void fragment() {
	ivec2 p = ivec2(floor(UV * csize));
	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	if (kept(p)) { return; }
	int part;
	ivec2 r = rest_of(p, part);
	vec2 cc = vec2(ink_x.x + ink_x.y, 0.0) * 0.5;
	vec2 rv = vec2(r);
	float u = uof(rv.x);
	// the edge ripples: a slow wave along the body, a pixel in or out
	float st = floor(ts * fps + 0.001);
	float wob = round(sin(6.2831853 * (ts * 0.55 + rv.x * 0.035)) * 1.0);
	vec2 outv = normalize(rv - vec2(cc.x, csize.y * 0.5) + vec2(0.0001));
	vec2 sp = rv + vec2(0.0, wob * sign(outv.y));
	// a hit dents it where it struck, springing back
	if (hit_age >= 0.0 && hit_age < 0.6) {
		float dist = length(rv - hit_at);
		float fall = max(0.0, 1.0 - dist / 14.0);
		float dent = 3.5 * exp(-hit_age * 5.0) * cos(hit_age * 22.0) * hit_s;
		sp += normalize(rv - vec2(cc.x, csize.y * 0.5) + vec2(0.0001)) * round(dent * fall);
	}
	ivec2 spi = ivec2(round(sp));
	vec4 d = inb(spi) ? texelFetch(TEXTURE, spi, 0) : vec4(0.0);
	if (d.a < 0.5) { return; }
	float b = breath(u);
	float L = d.r * (0.55 + 0.3 * b) + d.g * (0.11 + 0.04 * b) + d.b * 0.22;
	// veins: a pulse running out along them now and then
	float h = fract(float(r.x) * 0.137 + float(r.y) * 0.071 + st * 0.083);
	if (d.b > 0.0 && h < 0.08) { L += 0.25; }
	if (hit_age >= 0.0 && hit_age < 0.6) {
		float dist2 = length(rv - hit_at);
		float f = (1.0 - hit_age / 0.6) * hit_s;
		L += d.b * 0.9 * f * max(0.2, 1.0 - dist2 / 60.0);
		L += d.g * 0.25 * f * max(0.0, 1.0 - dist2 / 16.0);
		L += d.r * 0.5 * f * max(0.0, 1.0 - dist2 / 20.0);
	}
	if (gain_age >= 0.0 && gain_age < 0.45) {
		float g = gain_age / 0.4;
		float dist3 = length(rv - vec2(cc.x, csize.y * 0.5)) / (0.5 * (ink_x.y - ink_x.x) + 8.0);
		if (dist3 > g) { return; }
		if (dist3 > g - 0.12) { L += 0.6 * max(d.r, 0.4); }
	}
	if (fizz_age >= 0.0) {
		float front = fizz_age * 150.0;
		float dist4 = length(rv - tear_at);
		if (dist4 < front) { return; }
		if (dist4 < front + 3.0 && (d.r > 0.0 || d.b > 0.0)) { L = max(L, 0.95); }
		L *= max(0.0, 1.0 - fizz_age / 0.7);
	}
	L *= lvl;
	float k8 = q8(L, p);
	COLOR = vec4(col * k8 * md.rgb, 1.0);
}
"""
