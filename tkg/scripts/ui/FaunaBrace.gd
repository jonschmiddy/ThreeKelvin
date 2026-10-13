class_name FaunaBrace
extends BraceFx

## BRACE ON A CREATURE (`FaunaGuard`): three ideas, `FaunaGuard.brace_look`.
##   A  HARDENED HIDE: the hide sets hard -- every pixel of it taken onto a dark
##      glassy teal by its own brightness (the scales stay scales), a cold rim
##      light along its back and crests, a sheen crossing it every few seconds
##      and single scales glinting; its lights and eyes show through. Hardens in
##      a wave from the head; a hit flashes where it lands and flakes patches of
##      the hard hide off, in proportion to the brace left, nearest the hit first.
##   B  TENSED: the creature braces itself (`FaunaMotion.pose`): holds its
##      breath, spines standing up with a tremor through them, flippers drawn
##      in, spine tips lit cold. A hit: it flinches. As brace goes the spines
##      come down a pixel; at 0 it lets its breath go.
##   C  CRYSTAL GROWTH: ice crystals erupt along its back, head to tail, each
##      growing out of the hide in three steps; a light climbs them now and
##      then. A hit shatters the nearest into tumbling shards; they go in
##      proportion to the brace left.
## Same calls as the plates (`gain`, `absorb`, `shed_to`), same moments.

var body: FaunaGuard.Body
var look := 0
var changes := 0

var _clock := FaunaGuard.Clock.new()
var _skin: FaunaGuard.GuardSkin
var _glow: FaunaGuard.GuardSkin
var _top: FaunaGuard.GuardSkin
var _data: ImageTexture
var _gain_t := -9.0
var _hit_t := -9.0
var _hit_at := Vector2.ZERO
var _bound: FaunaMotion = null
var _last_sig := 0
var _since_step := 0
var _bits := FaunaGuard.Motes.new()
var _flakes: Array = []       ## {tex, at (screen), size, dir, speed, spin, t0}
## A: the hide's patches (index per pixel in `_pid`), on or off.
var _pid := PackedInt32Array()
var _pon: Image
var _pon_tex: ImageTexture
var _patches: Array = []      ## {c (rest), on, n}
var _cara: Image
## C: the crystals: {base (rest Vector2i), img, tex, w, h, lean, on, t_on, t_off, h1}
var _xtals: Array = []
var _ease := 0.0
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

const GLINT_B := """
uniform float fps = 8.0;
uniform float pose = 0.0;
uniform float gain_age = -1.0;
uniform float hit_age = -1.0;

void fragment() {
	ivec2 p = ivec2(floor(UV * csize));
	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	if (kept(p) || pose <= 0.0) { return; }
	int part;
	ivec2 r = rest_of(p, part);
	if (!inb(r)) { return; }
	vec4 d = texelFetch(TEXTURE, r, 0);
	if (d.a < 0.5) { return; }
	float st = floor(ts * fps + 0.001);
	float u = uof(float(r.x));
	float L = d.r * (0.6 + 0.3 * pose);
	// a light running along the crests, and single tips catching it
	float pos = fract(ts / 2.2) * 1.4 - 0.2;
	L += d.r * 0.7 * bump((u - pos) / 0.06);
	if (hsh(float(r.x), st) > 0.9) { L += 0.5 * d.r; }
	if (gain_age >= 0.0 && gain_age < 0.4) { L += 0.8 * d.r * (1.0 - gain_age / 0.4); }
	if (hit_age >= 0.0 && hit_age < 0.25) { L += 0.6 * d.r; }
	COLOR = vec4(vec3(0.62, 0.92, 1.0) * q8(L, p) * md.rgb, 1.0);
}
"""


func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	facing = the_facing
	_origin = origin.round()
	_rng.seed = seed * 389 + 22
	look = clampi(FaunaGuard.brace_look, 0, 2)
	_clock.fps = body.fps
	_cx = body.centre().x
	_cy = body.centre().y
	match look:
		0:
			_build_hide()
			_skin = _new_skin(false, SKIN_A)
			_skin.mat.set_shader_parameter("pid_tex", ImageTexture.create_from_image(_pid_img))
			_skin.mat.set_shader_parameter("pon_tex", _pon_tex)
			_skin.paint = func(ci: CanvasItem) -> void:
				if brace > 0 or _was_on:
					ci.draw_texture(_data, Vector2.ZERO)
		1:
			_build_tips()
			_glow = _new_skin(true, GLINT_B)
			_glow.paint = func(ci: CanvasItem) -> void:
				ci.draw_texture(_data, Vector2.ZERO)
		2:
			_build_crystals()
	# the bits that come off (flakes, shards) and the light (glints, motes)
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


# ------------------------------------------------------------------ A: the hide

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
	var n := _patches.size() if look == 0 else _xtals.size()
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


# ------------------------------------------------------------------ B: the tips

## The crests: the top two pixels of each column of spine (the calf's lines,
## the Leviathan's crystals), and the top pixel of its back, faint.
func _build_tips() -> void:
	var b := body
	var im := Image.create(b.W, b.H, false, Image.FORMAT_RGBA8)
	for x in b.W:
		var seen := 0
		for y in b.H:
			var i := y * b.W + x
			if b.spine[i] == 1:
				if seen < 2:
					im.set_pixel(x, y, Color(1.0 if seen == 0 else 0.55, 0, 0, 1))
				seen += 1
		if seen == 0 and b.top[x] >= 0 and ((x & 1) == 0):
			im.set_pixel(x, b.top[x], Color(0.22, 0, 0, 1))
	_data = ImageTexture.create_from_image(im)


# ------------------------------------------------------------------ C: crystals

const ICE: Array[Color] = [Color("#0e3a44"), Color("#1f8a94"), Color("#45d0d0"), Color("#a8fff4"), Color("#ffffff")]


## Sites along the top of the back (where it has no crystal of its own), and a
## few on the upper flank; each a shard leaning back, lit on its front face.
func _build_crystals() -> void:
	var b := body
	var span := float(maxi(1, b.x1 - b.x0))
	var big := b.scale >= 1.0
	var step := 7 if b.kind == FaunaMotion.Kind.LEVIATHAN else 8
	if not big:
		step = 5
	var x := b.x0 + 6
	while x < b.x1 - 4:
		var u := (float(x) - float(b.x0)) / span
		var tp := b.top[x]
		if tp < 0 or u < 0.06 or u > 0.93:
			x += 2
			continue
		# the body's own top here (under any spine)
		var y := tp
		while y < b.bot[x] and (b.spine[y * b.W + x] == 1 or b.ink[y * b.W + x] == 0):
			y += 1
		if y >= b.bot[x]:
			x += 2
			continue
		var h := int(round(lerpf(6.0, 13.0, 1.0 - absf(u - 0.45) * 1.6) * (1.0 if big else 0.6)))
		h = clampi(h + _rng.randi_range(-1, 2), 4, 15)
		var w := maxi(4, int(round(h * 0.75)))
		_xtals.append(_shard(Vector2i(x, y + 1), w, h, 0.35 + _rng.randf() * 0.3))
		x += step + _rng.randi_range(0, 3)
	# the flank: a short row a third of the way down, smaller
	x = b.x0 + int(span * 0.2)
	while x < b.x0 + int(span * 0.75):
		var tp2 := b.top[x]
		var bt2 := b.bot[x]
		if tp2 >= 0 and bt2 - tp2 > 10:
			var y2 := tp2 + int((bt2 - tp2) * 0.3)
			if b.ink[y2 * b.W + x] == 1 and b.glow[y2 * b.W + x] == 0 and b.fin[y2 * b.W + x] == 0:
				var h2 := 5 if big else 3
				_xtals.append(_shard(Vector2i(x, y2), 4, h2 + _rng.randi_range(0, 2), 0.5))
		x += step + 4 + _rng.randi_range(0, 4)
	# grown head to tail
	_xtals.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return (a.base as Vector2i).x < (c.base as Vector2i).x)


func _shard(base: Vector2i, w: int, h: int, lean: float) -> Dictionary:
	var lw := int(ceil(lean * float(h))) + w + 2
	var im := Image.create(lw, h, false, Image.FORMAT_RGBA8)
	var cx0 := float(w) * 0.5
	for y in h:
		var f := float(y + 1) / float(h)   # 0 at the tip, 1 at the base
		var cx := cx0 + lean * float(h - 1 - y)
		var hw := maxf(0.5, f * float(w) * 0.5)
		var l := int(round(cx - hw))
		var r := int(round(cx + hw)) - 1
		if r < l:
			r = l
		for xx in range(l, r + 1):
			var c: Color
			if xx == r and r > l:
				c = ICE[0]
			elif xx == l:
				c = ICE[3] if y < h - 1 else ICE[1]
			elif xx < int(round(cx)):
				c = ICE[3]
			elif xx == int(round(cx)):
				c = ICE[4] if y < (h * 2) / 3 else ICE[3]
			else:
				c = ICE[2] if y < h - 2 else ICE[1]
			if xx >= 0 and xx < lw:
				im.set_pixel(xx, y, c)
	return {base = base, img = im, tex = ImageTexture.create_from_image(im), w = lw, h = h, lean = lean,
		on = false, t_on = -9.0, t_off = -9.0, h1 = _rng.randi() % 997}


func _shatter(x: Dictionary, toward: float, hard: bool) -> void:
	x.on = false
	x.t_off = t
	var fm := FaunaGuard.motion_of(self)
	var b: Vector2i = x.base
	var at := FaunaGuard.shown(fm, Vector2(b)) - Vector2(0, float(x.h))
	var im: Image = x.img
	var hh: int = x.h
	var cuts := [0, hh / 3, (hh * 2) / 3, hh]
	for k in 3:
		var y0: int = cuts[k]
		var y1: int = cuts[k + 1]
		if y1 <= y0:
			continue
		var side := maxi(int(x.w), y1 - y0)
		var piece := Image.create(side, side, false, Image.FORMAT_RGBA8)
		piece.blit_rect(im, Rect2i(0, y0, int(x.w), y1 - y0), Vector2i.ZERO)
		var dir := (Vector2(toward * 0.7, -1.0 + float(k) * 0.45) + Vector2(_rng.randf_range(-0.4, 0.4), 0)).normalized()
		_flakes.append({tex = ImageTexture.create_from_image(piece), at = at + Vector2(0, y0), size = side,
			dir = dir, speed = _rng.randf_range(30.0, 60.0) if hard else _rng.randf_range(10.0, 22.0),
			spin = _rng.randf_range(6.0, 10.0) * (1.0 if _rng.randf() < 0.5 else -1.0), t0 = t})
	var glitter: Array = [Color("#ffffff"), Color("#bff4fb"), Color("#6cc4d4"), Color("#2f7f95")]
	for i in (7 if hard else 3):
		var dv := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_bits.add(at + Vector2(0, float(hh) * 0.5), dv * _rng.randf_range(20.0, 50.0), _rng.randf_range(0.25, 0.45), t, glitter, 3.0)


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
	match look:
		0:
			var off: Array = range(_patches.size()).filter(func(k: int) -> bool: return not _patches[k].on)
			off.sort_custom(func(a: int, c: int) -> bool:
				return float(facing) * (_patches[a].c as Vector2).x > float(facing) * (_patches[c].c as Vector2).x)
			var have := _patches.size() - off.size()
			for i in mini(n - have, off.size()):
				_patches[off[i]].on = true
			_push_patches()
		2:
			var off2: Array = _xtals.filter(func(x: Dictionary) -> bool: return not x.on)
			var have2 := _xtals.size() - off2.size()
			var m := mini(n - have2, off2.size())
			for i in m:
				off2[i].on = true
				off2[i].t_on = t + 0.5 * float(i) / float(maxi(1, m))
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
	if look == 1 and fm != null:
		fm.flinch()
	if look == 0:
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
func _drop(q: Vector2, hard: bool) -> void:
	var n := _want()
	var toward := float(-facing)
	match look:
		0:
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
		2:
			var on2: Array = _xtals.filter(func(x: Dictionary) -> bool: return x.on)
			if q != Vector2.INF:
				on2.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
					return Vector2(a.base).distance_to(q) < Vector2(c.base).distance_to(q))
			else:
				on2.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
					return float(facing) * float((a.base as Vector2i).x) < float(facing) * float((c.base as Vector2i).x))
			var drop2 := on2.size() - n
			for i in maxi(0, drop2):
				_shatter(on2[i], toward, hard)
			if drop2 > 0:
				moment.emit(&"plate_off", minf(1.0, float(drop2) / 6.0), 0.6)


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
	if _glow != null:
		_glow.follow(fm, tq + _clock.phase, ks)
		var pose := 0.0
		if brace > 0:
			pose = clampf(float(brace) / float(maxi(1, _peak)), 0.01, 1.0)
		_glow.mat.set_shader_parameter("pose", pose)
		_glow.mat.set_shader_parameter("gain_age", tq - _gain_t if tq - _gain_t < 0.5 else -1.0)
		_glow.mat.set_shader_parameter("hit_age", tq - _hit_t if tq - _hit_t < 0.3 else -1.0)
		if fm != null:
			fm.pose = pose
	var st := _clock.index(t)
	if st != _clock.step:
		_clock.step = st
		_since_step = 0
		for c in get_children():
			(c as CanvasItem).queue_redraw()
	else:
		_since_step += 1
	var sig := 0
	if (look == 0 and brace > 0) or (look == 1 and brace > 0):
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
	if look == 2:
		for x in _xtals:
			if not x.on or tq < float(x.t_on):
				continue
			var a := tq - float(x.t_on)
			var hh: int = x.h
			# out of the hide in three steps, a pixel proud on the last
			var sh := hh
			var steps := int(a * _clock.fps)
			if steps == 0:
				sh = maxi(1, hh / 3)
			elif steps == 1:
				sh = maxi(2, (hh * 2) / 3)
			var b: Vector2i = x.base
			var foot := FaunaGuard.shown(fm, Vector2(b))
			var lean_w: int = x.w
			var pos := foot + Vector2(-float(lean_w) * 0.0 - 1.0, -float(sh))
			if FaunaGuard.in_keep(keep, pos, Vector2(lean_w, sh)):
				continue
			ci.draw_texture_rect_region(x.tex, Rect2(pos.round(), Vector2(lean_w, sh)), Rect2(0, 0, lean_w, sh))
			h = h * 31 + int(pos.x) * 3 + int(pos.y) * 7 + sh
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
	if look == 2:
		# a light climbing the crystals, one after the other, head to tail
		var on: Array = _xtals.filter(func(x: Dictionary) -> bool: return x.on and tq - float(x.t_on) >= 0.3)
		var cyc := fposmod(tq, 2.6) / 2.6
		var which := int(cyc * float(on.size() + 4)) - 2
		for i in on.size():
			var x: Dictionary = on[i]
			var b: Vector2i = x.base
			var foot := FaunaGuard.shown(fm, Vector2(b))
			var hh: int = x.h
			var lean: float = x.lean
			var cx0 := float(int(x.w) - int(ceil(lean * float(hh))) - 2) * 0.5
			if i == which or i == which + 1:
				var k := int(fposmod(cyc * float(on.size() + 4), 1.0) * float(hh))
				var yy := hh - 1 - k
				var px := foot + Vector2(-1.0 + roundf(cx0 + lean * float(hh - 1 - yy)), -float(hh) + float(yy))
				if FaunaGuard.dot(ci, keep, px, Color(0.7, 0.85, 0.9)):
					h = h * 31 + int(px.x) + int(px.y) * 3
			elif FaunaGuard.hash01(int(x.h1), st) < 0.06:
				var tip := foot + Vector2(-1.0 + roundf(cx0 + lean * float(hh - 1)), -float(hh))
				FaunaGuard.dot(ci, keep, tip, Color(0.6, 0.75, 0.8))
				h = h * 31 + i
			# each lit faintly from within: its lit face's middle a step up
			var mid_y := hh / 2
			var mp := foot + Vector2(-1.0 + roundf(cx0 + lean * float(hh - 1 - mid_y)) - 1.0, -float(hh) + float(mid_y))
			FaunaGuard.dot(ci, keep, mp, Color(0.1, 0.22, 0.22), Vector2(2, 2))
			# a crystal landing: a frame of light at its foot
			var a := tq - float(x.t_on)
			if a >= 0.0 and a < 0.25:
				FaunaGuard.dot(ci, keep, foot + Vector2(-1, -1), Color(0.5, 0.6, 0.65), Vector2(3, 2))
	h = h * 31 + _bits.paint(ci, keep, tq)
	ci.set_meta(&"sig", h)
