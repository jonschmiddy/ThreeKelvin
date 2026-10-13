class_name ShieldFx
extends Control

## BLOCK, DRAWN AS K's HEX BUBBLE (Oct 13, mockups for a pick page; nothing
## here is in a fight yet). In the sim block soaks damage first and is cleared
## when the enemy's turn opens.
##
## Round two, Jon's picks on round one: the BUBBLE, with changes --
##   - fitted: an oval round the picture's own ink, a few pixels out, grown
##     until no hull pixel is under its rim or outside it (`fit`; the harness's
##     `fitcheck` proves it on every enemy picture, the Custodian takes and the
##     player hulls);
##   - the same at rest whatever block is left: no cells dropping per hit, no
##     brightness steps;
##   - alive: now and then (every 3-6 s, seeded per ship) a soft ripple crosses
##     it, or a glitch -- a torn band, a one-pixel jump, a band flickering --
##     for two to four frames; between those it holds still;
##   - a soaked hit shimmers over the whole bubble for 0.4 s, brightest where
##     it struck;
##   - at 0 block it FIZZLES (sputters, flickers and dies over 0.7 s) rather
##     than shattering, and so does leftover block at turn start;
##   - a hit that breaks through still carries on to the hull (`through`).
##
## Every change is held for whole frames and comes from an event or the idle
## schedule; the rest frame is one still picture.

signal moment(kind: StringName, strength: float, length: float)
## The shot that broke the shield goes on, this much, here.
signal through(amount: int, at: Vector2)

const COL := Color("#7cd8ff")
const REST := 0.5
const MARGIN := 4.0
const RIM_FROM := 0.93
const FIZZLE := 0.7
const SHIMMER := 0.42
## Jon, round three: "Idle resting glitches and ripples can be more often and
## more significant. The shields are too static right now." An idle event
## every 0.8-2 s a ship (seeded, so ships are out of step), and between them a
## faint shimmer of single cells, never fully still.
const IDLE_MIN := 0.8
const IDLE_MAX := 2.0
## The always-on shimmer's step: 8 a second, each cell's turn held for it.
const TWINKLE_HZ := 8.0
const SOUND := "gain: shield_up, 0.35 long. idle: shield_ripple (soft, 0.8 long) or shield_glitch (0.07-0.13 long), one every 3-6 s. soaked hit: shield_hit (strength = share of block used), 0.42 long shimmer. break: shield_break (the impact) then shield_fizzle 0.7 long; the hull's own impact 0.1 s on. turn start: shield_fizzle, 0.7 long"

var t := 0.0
var auto := true
var facing := -1
var block := 0

var _origin := Vector2.ZERO
var _cc := Vector2.ZERO
var _rx := 1.0
var _ry := 1.0
var _cells: Array = []
var _rim: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()
var _flashes: Array = []
var _motes: Array = []
var _pending: Array = []
var _up := false
var _fizz_t := -1.0
var _shim_t := -9.0
var _shim_q := Vector2.ZERO
var _shim_s := 1.0
var _next_idle := 1e9
var _idle: Dictionary = {}


class Layer extends Control:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)


## The oval for a picture: centred on its ink, `MARGIN` px out, then grown
## until every hull pixel sits inside the rim band. Canvas coordinates.
static func fit(img: Image, used: Rect2i) -> Dictionary:
	var H := ShipBreakup._hull_pic(img, used, 0)
	var r: Rect2i = H.r
	if int(H.n) == 0:
		return {cc = Vector2(r.get_center()), rx = 8.0, ry = 8.0}
	var x0: int = H.x0
	var x1: int = H.x1
	var y0: int = H.y0
	var y1: int = H.y1
	var cc := Vector2(r.position) + Vector2(x0 + x1 + 1, y0 + y1 + 1) * 0.5
	var rx := float(x1 - x0 + 1) * 0.5 + MARGIN
	var ry := float(y1 - y0 + 1) * 0.5 + MARGIN
	var worst := 0.0
	var mask: PackedByteArray = H.mask
	var w: int = H.w
	for y in int(H.h):
		for x in w:
			if mask[y * w + x] == 0:
				continue
			# the pixel's far corner, so the whole pixel is inside
			var gx := float(r.position.x + x)
			var gy := float(r.position.y + y)
			var px := gx + (1.0 if gx + 0.5 > cc.x else 0.0)
			var py := gy + (1.0 if gy + 0.5 > cc.y else 0.0)
			worst = maxf(worst, Vector2((px - cc.x) / rx, (py - cc.y) / ry).length())
	var k := maxf(1.0, worst / (RIM_FROM - 0.02))
	return {cc = cc, rx = rx * k, ry = ry * k}


## How many hull pixels of a picture fall outside the oval (x) and under its
## rim (y). Both must be 0.
static func outside(img: Image, used: Rect2i) -> Vector2i:
	var f := fit(img, used)
	var H := ShipBreakup._hull_pic(img, used, 0)
	if int(H.n) == 0:
		return Vector2i.ZERO
	var r: Rect2i = H.r
	var mask: PackedByteArray = H.mask
	var w: int = H.w
	var out := 0
	var rim := 0
	for y in int(H.h):
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var rn := Vector2((float(r.position.x + x) + 0.5 - float(f.cc.x)) / float(f.rx),
				(float(r.position.y + y) + 0.5 - float(f.cc.y)) / float(f.ry)).length()
			if rn > 1.0:
				out += 1
			elif rn >= RIM_FROM:
				rim += 1
	return Vector2i(out, rim)


func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	facing = the_facing
	_origin = origin.round()
	_rng.seed = seed * 613 + 1
	var f := fit(img, used)
	_cc = f.cc
	_rx = f.rx
	_ry = f.ry
	_build_cells()
	var light := Layer.new()
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = mat
	light.paint = _paint
	add_child(light)


## Hexagon outlines over the oval, brightest toward the rim; each cell its own
## little picture of light levels.
func _build_cells() -> void:
	var s := 6.0
	var dx := 1.5 * s
	var dy := sqrt(3.0) * s
	var lo := Vector2i(int(floor(_cc.x - _rx)) - 1, int(floor(_cc.y - _ry)) - 1)
	var W := int(ceil(2.0 * _rx)) + 3
	var Hh := int(ceil(2.0 * _ry)) + 3
	var ids := PackedInt32Array()
	ids.resize(W * Hh)
	ids.fill(-1)
	var rns := PackedFloat32Array()
	rns.resize(W * Hh)
	for y in Hh:
		for x in W:
			var px := float(lo.x + x) + 0.5
			var py := float(lo.y + y) + 0.5
			var rn := Vector2((px - _cc.x) / _rx, (py - _cc.y) / _ry).length()
			if rn > 1.0:
				continue
			var fi := floorf((px - _cc.x) / dx)
			var best := 1e9
			var bid := 0
			for i in range(int(fi) - 1, int(fi) + 3):
				var ox := _cc.x + float(i) * dx
				var oyoff := dy * 0.5 if (i & 1) == 1 else 0.0
				var fj := floorf((py - _cc.y - oyoff) / dy)
				for j in range(int(fj) - 1, int(fj) + 3):
					var oy := _cc.y + float(j) * dy + oyoff
					var d2 := (px - ox) * (px - ox) + (py - oy) * (py - oy)
					if d2 < best:
						best = d2
						bid = (i + 500) * 1000 + (j + 500)
			ids[y * W + x] = bid
			rns[y * W + x] = rn
	# THE RIM IS A FINE LINE (Jon: "The edge of the shield is toooo thickkk"):
	# the oval's own edge pixel at full light, and the pixel inside it a
	# dimmer line, dithered -- two pixels, not the band of the outer 7% it was.
	var outer_at := PackedByteArray()
	outer_at.resize(W * Hh)
	for y in Hh:
		for x in W:
			var i0 := y * W + x
			if ids[i0] < 0:
				continue
			if x + 1 >= W or ids[i0 + 1] < 0 or x == 0 or ids[i0 - 1] < 0 \
					or y + 1 >= Hh or ids[i0 + W] < 0 or y == 0 or ids[i0 - W] < 0:
				outer_at[i0] = 1
	var cells := {}
	for y in Hh:
		for x in W:
			var i2 := y * W + x
			var id := ids[i2]
			if id < 0:
				continue
			var rn2 := rns[i2]
			var edge := (x + 1 < W and ids[i2 + 1] >= 0 and ids[i2 + 1] != id) \
				or (y + 1 < Hh and ids[i2 + W] >= 0 and ids[i2 + W] != id)
			var outer := outer_at[i2] == 1
			var inner := not outer and ((x + 1 < W and outer_at[i2 + 1] == 1) or (x > 0 and outer_at[i2 - 1] == 1) \
				or (y + 1 < Hh and outer_at[i2 + W] == 1) or (y > 0 and outer_at[i2 - W] == 1))
			var rim := outer or (inner and ((lo.x + x + lo.y + y) & 1) == 0)
			if not edge and not rim:
				continue
			var lvl := 0.0
			if rim:
				lvl = 1.0 if outer else 0.4
			else:
				var fr := 0.22 + 0.78 * pow(rn2, 3.0)
				lvl = 1.0 if fr > 0.8 else (0.7 if fr > 0.55 else (0.45 if fr > 0.33 else 0.25))
				if lvl <= 0.25 and ((lo.x + x + lo.y + y) & 1) == 1:
					continue
			if outer:
				_rim.append(Vector2(lo.x + x, lo.y + y))
			if not cells.has(id):
				cells[id] = []
			(cells[id] as Array).append([Vector2i(lo.x + x, lo.y + y), lvl])
	for id2 in cells:
		var arr: Array = cells[id2]
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-(1 << 20), -(1 << 20))
		var sum := Vector2.ZERO
		for e in arr:
			var p: Vector2i = e[0]
			mn = Vector2i(mini(mn.x, p.x), mini(mn.y, p.y))
			mx = Vector2i(maxi(mx.x, p.x), maxi(mx.y, p.y))
			sum += Vector2(p)
		var im := Image.create(mx.x - mn.x + 1, mx.y - mn.y + 1, false, Image.FORMAT_RGBA8)
		for e2 in arr:
			var p2: Vector2i = e2[0]
			var l: float = e2[1]
			im.set_pixel(p2.x - mn.x, p2.y - mn.y, Color(l, l, l, 1.0))
		_cells.append({tex = ImageTexture.create_from_image(im), at = Vector2(mn), c = sum / float(arr.size()),
			on = false, t_on = -9.0, die = 0.0, h = _rng.randi() % 1024})


func _process(delta: float) -> void:
	if auto:
		advance(delta)


func _span() -> float:
	return maxf(_rx, _ry)


func gain(amount: int) -> void:
	if amount <= 0:
		return
	block += amount
	if not _up or _fizz_t >= 0.0:
		# shimmers up: cells light in a sweep from the middle
		_up = true
		_fizz_t = -1.0
		for c in _cells:
			var d := (Vector2(c.c) - _cc).length() / _span()
			c.on = true
			c.t_on = t + 0.28 * d + _rng.randf_range(0.0, 0.04)
		_next_idle = t + _rng.randf_range(IDLE_MIN, IDLE_MAX)
	else:
		# more on an up shield: a soft shimmer from the middle
		_shimmer(_cc, 0.5)
	moment.emit(&"shield_up", minf(1.0, float(amount) / 10.0), 0.35)


## A shot for `amount`. Returns what goes on to the hull.
func hit(amount: int) -> int:
	if block <= 0 or _cells.is_empty():
		return amount
	var q := _impact()
	var qs := _origin + q
	if amount < block:
		var frac := float(amount) / float(block)
		block -= amount
		_shimmer(q, 1.0)
		_flashes.append({p = qs, t0 = t, r = 10, s = 0.5 + 0.4 * frac, life = 0.2})
		moment.emit(&"shield_hit", frac, SHIMMER)
		return 0
	var over := amount - block
	block = 0
	_flashes.append({p = qs, t0 = t, r = 12, s = 0.9, life = 0.22})
	moment.emit(&"shield_break", 1.0, 0.0)
	_fizzle()
	if over > 0:
		_pending.append({t = t + 0.1, amount = over, at = qs})
	return over


## Turn start: whatever block is left goes, the same way.
func expire() -> void:
	if block <= 0:
		return
	block = 0
	_fizzle()


func _fizzle() -> void:
	if not _up:
		return
	_fizz_t = t
	_idle = {}
	_next_idle = 1e9
	for c in _cells:
		c.die = _rng.randf_range(0.25, FIZZLE)
	for i in 6:
		var p := _rim[_rng.randi() % _rim.size()] if not _rim.is_empty() else _cc
		var dv := (p - _cc).normalized()
		_motes.append({p = _origin + p, v = dv * _rng.randf_range(15.0, 40.0), age = -_rng.randf_range(0.0, 0.4),
			life = _rng.randf_range(0.15, 0.3)})
	moment.emit(&"shield_fizzle", 0.5, FIZZLE)


func _shimmer(q: Vector2, s: float) -> void:
	_shim_t = t
	_shim_q = q
	_shim_s = s
	# nothing idle on top of a shimmer: a running one stops, a due one waits
	_idle = {}
	if _next_idle < t + SHIMMER + 0.3:
		_next_idle = t + SHIMMER + _rng.randf_range(0.3, 1.0)


func _impact() -> Vector2:
	var best := -1e9
	var bp := _cc
	for i in 40:
		if _rim.is_empty():
			break
		var p := _rim[_rng.randi() % _rim.size()]
		var s := float(facing) * (p.x - _cc.x) / maxf(1.0, _rx) + _rng.randf() * 0.25
		if s > best:
			best = s
			bp = p
	return bp


func advance(delta: float) -> void:
	t += delta
	var keep: Array = []
	for p in _pending:
		if t >= float(p.t):
			through.emit(int(p.amount), p.at)
		else:
			keep.append(p)
	_pending = keep
	if _fizz_t >= 0.0 and t - _fizz_t >= FIZZLE + 0.05:
		_up = false
		_fizz_t = -1.0
		for c in _cells:
			c.on = false
	if _up and _fizz_t < 0.0 and t >= _next_idle:
		_start_idle()
	if not _idle.is_empty() and t - float(_idle.t0) >= float(_idle.len):
		_idle = {}
	var kept: Array = []
	for mo in _motes:
		mo.age += delta
		if mo.age < mo.life:
			if mo.age > 0.0:
				mo.p += mo.v * delta
			kept.append(mo)
	_motes = kept
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return t - float(f.t0) <= float(f.life))
	queue_redraw()
	for c2 in get_children():
		(c2 as CanvasItem).queue_redraw()


## The idle life, one event at a time:
##   ripple  a wave of light (one, or two from different points at once)
##           spreading over the whole bubble in 0.7 s, lifting the cells it
##           crosses and the rim with them;
##   tear    a band of rows jumping 1-3 px sideways, 3-6 frames;
##   slice   a taller band of cells jumping 3 px, then back;
##   patch   a patch of cells going out, back, out, back;
##   stutter the whole bubble dropping dim for a frame or two.
func _start_idle() -> void:
	_next_idle = t + _rng.randf_range(IDLE_MIN, IDLE_MAX)
	var r := _rng.randf()
	if r < 0.42:
		var pts: Array = [_rim_point()]
		if _rng.randf() < 0.35:
			pts.append(_rim_point())
		_idle = {kind = &"ripple", t0 = t, len = 0.7, pts = pts}
		moment.emit(&"shield_ripple", 0.25 if pts.size() == 1 else 0.35, 0.7)
		return
	var frames := _rng.randi_range(3, 6)
	var kind: StringName = &"tear" if r < 0.62 else (&"slice" if r < 0.77 else (&"patch" if r < 0.92 else &"stutter"))
	var band_h := _rng.randf_range(3.0, 7.0) if kind == &"tear" else _rng.randf_range(8.0, 14.0)
	var y0 := _cc.y + _rng.randf_range(-0.7, 0.7) * _ry - band_h * 0.5
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	if kind == &"stutter":
		frames = _rng.randi_range(1, 2)
	_idle = {kind = kind, t0 = t, len = float(frames) / 30.0 - 0.001, y0 = y0, y1 = y0 + band_h,
		dx = side * float(_rng.randi_range(1, 3)) if kind == &"tear" else side * 3.0,
		p = _cc + Vector2(_rng.randf_range(-0.6, 0.6) * _rx, _rng.randf_range(-0.6, 0.6) * _ry),
		pr = _rng.randf_range(10.0, 18.0)}
	moment.emit(&"shield_glitch", 0.3 if kind != &"stutter" else 0.4, float(frames) / 30.0)


func _rim_point() -> Vector2:
	return _rim[_rng.randi() % _rim.size()] if not _rim.is_empty() else _cc


## One cell's light now, and where it is drawn.
func _cell(c: Dictionary) -> Array:
	var at: Vector2 = c.at
	if not c.on:
		return [0.0, at]
	var a := t - float(c.t_on)
	if a < 0.0:
		return [0.0, at]
	var l := REST
	if a < 0.067:
		l = 1.0
	elif a < 0.15:
		l = 0.7
	var cc: Vector2 = c.c
	var sa := t - _shim_t
	if sa >= 0.0 and sa < SHIMMER:
		# the whole bubble shimmers, brightest where it was struck: cells take
		# one of two levels by their own parity, alternating every two frames
		var phase := int(sa * 15.0)
		var fade := 1.0 if sa < 0.1 else (0.66 if sa < 0.22 else (0.4 if sa < 0.34 else 0.2))
		var w := maxf(0.3, 1.0 - (cc - _shim_q).length() / (_span() * 1.1))
		var alt := float((int(c.h) + phase) & 1)
		l = maxf(l, REST + (1.0 - REST) * fade * w * _shim_s * (0.55 + 0.45 * alt))
	# the faint shimmer that never stops: a cell's turn comes up on a hash of
	# its own and the step, lit a little for a step, then a little less
	if _fizz_t < 0.0 and a >= 0.3:
		var step := int(t * TWINKLE_HZ)
		var h := int(c.h)
		if (h * 31 + step * 17) % 19 == 0:
			l = maxf(l, REST + 0.2)
		elif (h * 31 + (step - 1) * 17) % 19 == 0:
			l = maxf(l, REST + 0.09)
	if not _idle.is_empty():
		var ia := t - float(_idle.t0)
		match _idle.kind:
			&"ripple":
				# waves spreading from rim points over the whole bubble; the
				# cells they cross (the rim's among them) lift
				var f := ia / float(_idle.len)
				var radius := f * _span() * 2.2
				for q in _idle.pts:
					var d := absf((cc - (q as Vector2)).length() - radius)
					if d < 4.0:
						l = maxf(l, REST + 0.42 * (1.0 - f * 0.5))
					elif d < 9.0:
						l = maxf(l, REST + 0.2 * (1.0 - f * 0.5))
			&"tear":
				if cc.y >= float(_idle.y0) and cc.y <= float(_idle.y1):
					at = at + Vector2(float(_idle.dx), 0.0)
			&"slice":
				if cc.y >= float(_idle.y0) and cc.y <= float(_idle.y1):
					at = at + Vector2(float(_idle.dx), 0.0)
					l = maxf(l, REST + 0.15)
			&"patch":
				if (cc - (_idle.p as Vector2)).length() < float(_idle.pr):
					l = 0.0 if (int(ia * 30.0) & 1) == 0 else maxf(l, REST + 0.15)
			&"stutter":
				l *= 0.35
	if _fizz_t >= 0.0:
		var fa := t - _fizz_t
		if fa >= float(c.die):
			return [0.0, at]
		# sputters: on, dim, a bright pop now and then, fading as it goes
		var phase2 := int(fa * 15.0)
		var hsh := (int(c.h) * 7 + phase2 * 13) % 9
		var base := REST * (1.0 if fa < 0.18 else (0.7 if fa < 0.36 else (0.45 if fa < 0.54 else 0.25)))
		if hsh == 0:
			l = 0.85
		elif hsh < 4:
			l = 0.1
		else:
			l = base
	return [l, at]


func _paint(ci: CanvasItem) -> void:
	for c in _cells:
		var st := _cell(c)
		var l: float = st[0]
		if l > 0.0:
			ci.draw_texture(c.tex, (_origin + (st[1] as Vector2)).round(), ShipBreakup._lv(COL, l))
	for f in _flashes:
		var age := t - float(f.t0)
		var x := age / float(f.life)
		var l2 := (1.0 if x < 0.25 else (0.6 if x < 0.5 else (0.32 if x < 0.75 else 0.14))) * float(f.s)
		var tex := ShipBreakup._white(int(f.r))
		ci.draw_texture(tex, (Vector2(f.p) - Vector2(tex.get_size()) * 0.5).round(), ShipBreakup._lv(COL, l2))
	for mo in _motes:
		if mo.age < 0.0:
			continue
		var f2: float = mo.age / mo.life
		var l3 := 1.0 if f2 < 0.4 else (0.6 if f2 < 0.75 else 0.3)
		ci.draw_rect(Rect2((mo.p as Vector2).round(), Vector2.ONE), ShipBreakup._lv(COL.lerp(Color.WHITE, 0.4), l3))
