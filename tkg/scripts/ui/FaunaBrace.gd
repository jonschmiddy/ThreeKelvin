class_name FaunaBrace
extends BraceFx

## BRACE ON A CREATURE (`FaunaGuard`), Jon's pick of three ("brace:A", Oct 13):
## HARDENED HIDE. The hide sets hard -- every pixel of it taken onto a dark
## glassy teal by its own brightness (the scales stay scales), a cold rim light
## along its back and crests, a sheen crossing it every few seconds and single
## scales glinting; its lights and eyes show through. Hardens in a wave from the
## head; a hit flashes where it lands and flakes patches of the hard hide off,
## in proportion to the brace left, nearest the hit first. (The other two,
## tensed and crystal growth, were not picked and are gone.)
## Same calls as the plates (`gain`, `absorb`, `shed_to`), same moments.

var body: FaunaGuard.Body
var changes := 0

var _clock := FaunaGuard.Clock.new()
var _skin: FaunaGuard.GuardSkin
var _data: ImageTexture
var _gain_t := -9.0
var _hit_t := -9.0
var _hit_at := Vector2.ZERO
var _bound: FaunaMotion = null
var _last_sig := 0
var _since_step := 0
var _bits := FaunaGuard.Motes.new()
var _flakes: Array = []       ## {tex, at (screen), size, dir, speed, spin, t0}
## The hide's patches (index per pixel in `_pid`), on or off.
var _pid := PackedInt32Array()
var _pon: Image
var _pon_tex: ImageTexture
var _patches: Array = []      ## {c (rest), on, n}
var _cara: Image
var _was_on := false

const SKIN_A := """
uniform sampler2D pid_tex : filter_nearest;
uniform sampler2D pon_tex : filter_nearest;
uniform float fps = 8.0;
uniform float gain_age = -1.0;
uniform float hit_age = -1.0;
uniform vec2 hit_at;

void fragment() {
	ivec2 p = ivec2(floor(UV * csize));
	COLOR = vec4(0.0);
	if (kept(p)) { return; }
	int part;
	ivec2 r = rest_of(p, part);
	if (!inb(r)) { return; }
	vec4 d = texelFetch(TEXTURE, r, 0);
	if (d.a < 0.5) { return; }
	int id = int(round(texelFetch(pid_tex, r, 0).r * 255.0));
	if (texelFetch(pon_tex, ivec2(id, 0), 0).r < 0.5) { return; }
	float u = uof(float(r.x));
	if (gain_age >= 0.0 && gain_age < 0.5) {
		float f = gain_age / 0.4;
		if (u > f) { return; }
	}
	vec3 c = d.rgb;
	float st = floor(ts * fps + 0.001);
	// the sheen: a lit band crossing the hide every 3.2 s
	float sw = fract(ts / 3.2) * 1.8 - 0.4;
	float s = float(r.x) + float(r.y) * 0.8 - mix(ink_x.x - 30.0, ink_x.y + 30.0, sw);
	if (abs(s) < 1.5) { c = mix(c, vec3(0.86, 0.98, 1.0), 0.45); }
	else if (abs(s) < 3.5 && ((r.x + r.y) & 1) == 0) { c = mix(c, vec3(0.86, 0.98, 1.0), 0.2); }
	// single scales glinting
	if (hsh(float(r.x), float(r.y) + st * 0.37) > 0.985 && dot(c, vec3(0.33)) > 0.3) { c = mix(c, vec3(1.0), 0.6); }
	if (hit_age >= 0.0 && hit_age < 0.2 && length(vec2(r) - hit_at) < 7.0) {
		c = mix(c, vec3(1.0), hit_age < 0.08 ? 0.75 : 0.35);
	}
	COLOR = vec4(c * md.rgb, md.a);
}
"""



func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	facing = the_facing
	_origin = origin.round()
	_rng.seed = seed * 389 + 22
	_clock.fps = body.fps
	_cx = body.centre().x
	_cy = body.centre().y
	_build_hide()
	_skin = _new_skin(false, SKIN_A)
	_skin.mat.set_shader_parameter("pid_tex", ImageTexture.create_from_image(_pid_img))
	_skin.mat.set_shader_parameter("pon_tex", _pon_tex)
	_skin.paint = func(ci: CanvasItem) -> void:
		if brace > 0 or _was_on:
			ci.draw_texture(_data, Vector2.ZERO)
	# the flakes that come off, and the light (the hit's dust)
	for k in 2:
		var l := BraceFx.Layer.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if k == 1:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			l.material = mat
			l.paint = _paint_light
		else:
			l.paint = _paint_body
		add_child(l)


func _new_skin(add: bool, code: String) -> FaunaGuard.GuardSkin:
	var s := FaunaGuard.GuardSkin.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.make(body, FaunaGuard.skin_code(add, code))
	s.mat.set_shader_parameter("fps", body.fps)
	add_child(s)
	return s


# ------------------------------------------------------------------ the hide

const CARA: Array[Color] = [Color("#0a1820"), Color("#122c38"), Color("#1d4554"), Color("#2c6474"),
	Color("#478c9a"), Color("#79bcc4"), Color("#b6e6ea")]
const RIM := Color("#d4fbff")
var _pid_img: Image


func _build_hide() -> void:
	var b := body
	var W := b.W
	var H := b.H
	_cara = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_pid_img = Image.create(W, H, false, Image.FORMAT_R8)
	# patches: a rough Voronoi over the hide, a dozen-odd pixels across
	var seeds: Array[Vector2] = []
	var area := 0
	for i in W * H:
		area += b.ink[i]
	var n := clampi(area / 140, 8, 250)
	var tries := 0
	while seeds.size() < n and tries < n * 40:
		tries += 1
		var x := _rng.randi_range(b.r.position.x, b.r.end.x - 1)
		var y := _rng.randi_range(b.r.position.y, b.r.end.y - 1)
		if b.ink[y * W + x] == 1:
			seeds.append(Vector2(x, y))
	var fd := ShipBreakup._field(_rng, W, H, 6)
	for s in seeds:
		_patches.append({c = s, on = false, n = 0})
	# the hide's own range of brightness (5th to 95th): a pale calf hardens
	# as dark as the dark Leviathan, its brightest under the rim's light
	var ls: Array[float] = []
	for i0 in range(0, W * H, 3):
		if b.ink[i0] == 1 and b.glow[i0] == 0:
			ls.append(b.img.get_pixel(i0 % W, i0 / W).get_luminance())
	ls.sort()
	var l_lo := ls[int(ls.size() * 0.05)] if not ls.is_empty() else 0.0
	var l_hi := ls[int(ls.size() * 0.95)] if not ls.is_empty() else 1.0
	_pid.resize(W * H)
	_pid.fill(-1)
	for y in H:
		for x in W:
			var i := y * W + x
			if b.ink[i] == 0:
				continue
			var best := 1e9
			var bi := 0
			for k in seeds.size():
				var dd := Vector2(x, y).distance_to(seeds[k]) + 4.0 * ShipBreakup._nz(fd, x, y)
				if dd < best:
					best = dd
					bi = k
			_pid[i] = bi
			_patches[bi].n += 1
			_pid_img.set_pixel(x, y, Color(float(bi) / 255.0, 0, 0, 1))
			var c := b.img.get_pixel(x, y)
			if b.glow[i] == 1:
				continue   # its lights and eyes show through
			var l := clampf((c.get_luminance() - l_lo) / maxf(0.05, l_hi - l_lo), 0.0, 1.0)
			# up one if lit from above: a pixel with nothing over it
			var lit := y == 0 or b.ink[(y - 1) * W + x] == 0
			var crest := b.spine[i] == 1
			var f := clampf(l * 0.86 + (0.1 if crest else 0.0), 0.0, 0.999) * float(CARA.size() - 1)
			var lo := int(f)
			var fr := f - float(lo)
			var odd := ((x + y) & 1) == 0
			var idx := mini(CARA.size() - 1, lo + (1 if fr > 0.66 or (fr > 0.33 and odd) else 0))
			var cc: Color = CARA[idx]
			cc = cc.lerp(c, 0.12)
			if lit:
				cc = RIM
			elif y >= 2 and b.ink[(y - 2) * W + x] == 0:
				cc = cc.lerp(RIM, 0.45)
			_cara.set_pixel(x, y, Color(cc.r, cc.g, cc.b, 1.0))
	_data = ImageTexture.create_from_image(_cara)
	_pon = Image.create(256, 1, false, Image.FORMAT_R8)
	_pon_tex = ImageTexture.create_from_image(_pon)


func _push_patches() -> void:
	for k in _patches.size():
		_pon.set_pixel(k, 0, Color(1, 0, 0, 1) if _patches[k].on else Color(0, 0, 0, 1))
	_pon_tex.update(_pon)


## Patches to have on for the brace left.
func _want() -> int:
	if brace <= 0:
		return 0
	var n := _patches.size()
	return clampi(int(ceil(float(n) * float(brace) / float(maxi(1, _peak)))), 1, n)


## A patch of hard hide flaking off: its pixels as three or four flakes,
## tumbling away from the body and falling.
func _flake(k: int, toward: float) -> void:
	var b := body
	var px: Array[Vector2i] = []
	for i in _pid.size():
		if _pid[i] == k and b.glow[i] == 0:
			px.append(Vector2i(i % b.W, i / b.W))
	if px.is_empty():
		return
	var c: Vector2 = _patches[k].c
	var fm := FaunaGuard.motion_of(self)
	var cells := {}
	for q in px:
		var key := Vector2i(q.x / 3, q.y / 3)
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(q)
	var keys := cells.keys()
	keys.shuffle()
	for key2 in keys.slice(0, 9):
		var arr: Array = cells[key2]
		var mn := Vector2i(key2) * 3
		var im := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		for q3 in arr:
			im.set_pixel(q3.x - mn.x, q3.y - mn.y, _cara.get_pixel(q3.x, q3.y))
		var dir := ((Vector2(mn) - c).normalized() * 0.6 + (Vector2(mn) - body.centre()).normalized() + Vector2(toward * 0.5, -0.4)).normalized()
		_flakes.append({tex = ImageTexture.create_from_image(im), at = FaunaGuard.shown(fm, Vector2(mn)), size = 3,
			dir = dir, speed = _rng.randf_range(25.0, 60.0), spin = _rng.randf_range(6.0, 10.0) * (1.0 if _rng.randf() < 0.5 else -1.0),
			t0 = t + _rng.randf_range(0.0, 0.1)})


# ------------------------------------------------------------------ the calls

func gain(amount: int) -> void:
	if amount <= 0:
		return
	var fresh := brace <= 0
	brace += amount
	_peak = maxi(_peak, brace) if not fresh else brace
	if fresh:
		_gain_t = t
	var n := _want()
	var off: Array = range(_patches.size()).filter(func(k: int) -> bool: return not _patches[k].on)
	off.sort_custom(func(a: int, c: int) -> bool:
		return float(facing) * (_patches[a].c as Vector2).x > float(facing) * (_patches[c].c as Vector2).x)
	var have := _patches.size() - off.size()
	for i in mini(n - have, off.size()):
		_patches[off[i]].on = true
	_push_patches()
	moment.emit(&"bolt_on", minf(1.0, float(amount) / 10.0), 0.4)
	_flashes.append({p = Vector2.ZERO, t0 = t + 0.4, kind = &"clamp"})


func shed_to(n: int) -> void:
	brace = maxi(0, n)
	_drop(Vector2.INF, false)


func absorb(amount: int, at: Vector2 = Vector2.INF) -> int:
	if brace <= 0 or amount <= 0:
		return amount
	var took := mini(amount, brace)
	brace -= took
	var q := at if at != Vector2.INF else _front()
	_hit_t = t
	_hit_at = q
	var fm := FaunaGuard.motion_of(self)
	# a puff of hide dust where it struck
	var dust: Array = [Color("#d4fbff"), Color("#79bcc4"), Color("#2c6474")]
	for i in 6:
		_bits.add(FaunaGuard.shown(fm, q), (Vector2(float(facing), 0) + Vector2.RIGHT.rotated(_rng.randf() * TAU)).normalized() * _rng.randf_range(20.0, 45.0),
			_rng.randf_range(0.2, 0.4), t, dust, 4.0)
	moment.emit(&"clang", 0.5 + 0.5 * float(took) / float(maxi(1, _peak)), 0.0)
	_drop(q, true)
	return amount - took


## Down to what the brace left wants: the nearest the hit first (a quiet shed:
## the far side first).
func _drop(q: Vector2, _hard: bool) -> void:
	var n := _want()
	var toward := float(-facing)
	var on: Array = range(_patches.size()).filter(func(k: int) -> bool: return _patches[k].on)
	if q != Vector2.INF:
		on.sort_custom(func(a: int, c: int) -> bool:
			return (_patches[a].c as Vector2).distance_to(q) < (_patches[c].c as Vector2).distance_to(q))
	else:
		on.sort_custom(func(a: int, c: int) -> bool:
			return float(facing) * (_patches[a].c as Vector2).x < float(facing) * (_patches[c].c as Vector2).x)
	var drop := on.size() - n
	for i in maxi(0, drop):
		_patches[on[i]].on = false
		_flake(on[i], toward)
	_push_patches()
	if drop > 0:
		moment.emit(&"plate_off", minf(1.0, float(drop) / 12.0), 0.6)


func _front() -> Vector2:
	var b := body
	var best := -1e9
	var bp := b.centre()
	for i in 30:
		var x := _rng.randi_range(b.x0, b.x1)
		if b.top[x] < 0:
			continue
		var y := _rng.randi_range(b.top[x], b.bot[x])
		if b.ink[y * b.W + x] == 0:
			continue
		var s := float(facing) * float(x) + _rng.randf() * 40.0
		if s > best:
			best = s
			bp = Vector2(x, y)
	return bp


# ------------------------------------------------------------------ time

func advance(delta: float) -> void:
	t += delta
	for f in _flashes:
		if f.kind == &"clamp" and not f.get("fired", false) and t >= float(f.t0):
			f.fired = true
			moment.emit(&"clamp", 0.6, 0.0)
	_flashes = _flashes.filter(func(f2: Dictionary) -> bool: return not f2.get("fired", false))
	var fm := FaunaGuard.motion_of(self)
	if fm != _bound:
		_bound = fm
		_clock.bind(t, fm)
	var tq := _clock.tq(t)
	_flakes = _flakes.filter(func(c: Dictionary) -> bool: return tq - float(c.t0) < 0.75)
	_bits.prune(tq)
	var ks := FaunaGuard.keep_of(self)
	var L := FaunaGuard.layers_of(self)
	var mod := L.skin_mod if L != null else Color.WHITE
	_was_on = brace > 0
	if _skin != null:
		_skin.follow(fm, tq + _clock.phase, ks)
		_skin.mat.set_shader_parameter("gain_age", tq - _gain_t if tq - _gain_t < 0.6 else -1.0)
		_skin.mat.set_shader_parameter("hit_age", tq - _hit_t if tq - _hit_t < 0.3 else -1.0)
		_skin.mat.set_shader_parameter("hit_at", _hit_at)
		_skin.self_modulate = mod
		_skin.visible = brace > 0
	var st := _clock.index(t)
	if st != _clock.step:
		_clock.step = st
		_since_step = 0
		for c in get_children():
			(c as CanvasItem).queue_redraw()
	else:
		_since_step += 1
	var sig := 0
	if brace > 0:
		sig = st
	for c2 in get_children():
		if c2 is BraceFx.Layer:
			sig = sig * 7919 + int(c2.get_meta(&"sig", 0))
	# counted once a step, on the frame after it (the step's paint is in)
	if _since_step == 1:
		if sig != _last_sig:
			changes += 1
		_last_sig = sig


func _paint_body(ci: CanvasItem) -> void:
	var keep := FaunaGuard.keep_of(self)
	var fm := FaunaGuard.motion_of(self)
	var tq := _clock.tq(t)
	var h := 0
	for c in _flakes:
		var age := tq - float(c.t0)
		if age < 0.0:
			continue
		var dist := float(c.speed) * (1.0 - exp(-2.0 * age)) / 2.0
		var pp := (Vector2(c.at) + (c.dir as Vector2) * dist + Vector2(0, 30.0 * age * age)).round()
		var al := 1.0 if age < 0.4 else (0.6 if age < 0.55 else (0.3 if age < 0.68 else 0.12))
		var sz := float(c.size)
		if FaunaGuard.in_keep(keep, pp, Vector2(sz, sz)):
			continue
		var rot := posmod(int(floor(age * float(c.spin))), 4)
		ci.draw_set_transform(pp + Vector2(sz, sz) * 0.5, float(rot) * PI * 0.5, Vector2.ONE)
		ci.draw_texture(c.tex, -Vector2(sz, sz) * 0.5, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		h = h * 31 + int(pp.x) * 5 + int(pp.y) * 11 + rot
	ci.set_meta(&"sig", h)


func _paint_light(ci: CanvasItem) -> void:
	var keep := FaunaGuard.keep_of(self)
	var fm := FaunaGuard.motion_of(self)
	var tq := _clock.tq(t)
	var st := _clock.index(t)
	var h := 0
	h = h * 31 + _bits.paint(ci, keep, tq)
	ci.set_meta(&"sig", h)
