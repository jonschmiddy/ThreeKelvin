class_name BraceFx
extends Control

## BRACE, DRAWN: a plated overlay (Jon's pick, "brace:I", Oct 13). Brace is
## lasting armour that soaks after block. Jon wanted "the whole ship to have some
## type of armor on top... like that is visually like OK i have brace": a
## see-through steel layer over the whole hull, a pixel proud of its outline,
## panel lines and rivets solid on it and a sheen band across it, the ship
## dimmed beneath, in steel with the brace chip's teal so it never reads as the
## hull. Windows and engine glow show through.
## Gain: the panels clamp on in a quick wave from the side facing the enemy,
## each landing with a glint. A hit it takes: a clang flash, sparks, and a dent
## where it landed. As brace drops the panels nearest the hits come off in
## proportion and tumble away; at 0 the last go. Still at rest but for a rare
## glint. (The other two round-three looks, a plate shell and bands, were not
## picked and are gone.)

signal moment(kind: StringName, strength: float, length: float)

const SOUND := "gain: bolt_on ticks as the pieces land (about 0.3 s), then clamp (a heavy lock). rest: brace_glint every 4-7 s (optional faint shing). hit: clang (strength by the share of brace taken); plate_off when pieces come away (length 0.6, a clatter). spent: plate_off (the last of it)"

const TINT := Color("#3a5a6e")
const STEEL := Color(0.46, 0.63, 0.74)   ## steel with the brace chip's teal in it, so it never reads as the hull
const OUTLINE := Color(0.07, 0.09, 0.12)
const RIVET := Color(0.16, 0.19, 0.23)

var t := 0.0
var auto := true
var facing := -1
var brace := 0

var _origin := Vector2.ZERO
var _H: Dictionary = {}
var _r := Rect2i()
var _w := 0
var _h := 0
var _cx := 0.0
var _cy := 0.0
var _peak := 1
var _rng := RandomNumberGenerator.new()
var _pieces: Array = []      ## {img, tex, at (screen), c (screen), out (Vector2), on, t_on}
var _flashes: Array = []
var _motes: Array = []
var _chips: Array = []
var _next_glint := 1e9
var _glint_t := -9.0
var _glint_px: Array = []    ## [screen point, k] armour pixels for the glint sweep


class Layer extends Control:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)


func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	facing = the_facing
	_origin = origin.round()
	_rng.seed = seed * 389 + 22
	_H = ShipBreakup._hull_pic(img, used, 3)
	_r = _H.r
	_w = _H.w
	_h = _H.h
	if int(_H.n) == 0:
		return
	_cx = _H.cx
	_cy = _H.cy
	_build()
	for k in 2:
		var l := Layer.new()
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


func _screen(p: Vector2i) -> Vector2:
	return _origin + Vector2(_r.position) + Vector2(p)


## The armour: the hull grown a pixel, less what shows through (windows: bright
## and blue; engines: bright and warm), cut into pieces, each piece drawn as
## steel shaded by the ship's form under it and lit from above.
func _build() -> void:
	var mask: PackedByteArray = _H.mask
	var raw: PackedColorArray = _H.raw
	var w := _w
	var h := _h
	var A := PackedByteArray()
	A.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			var on := mask[i] == 1
			if not on:
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + o.x
					var ny: int = y + o.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h and mask[ny * w + nx] == 1:
						on = true
			if on and mask[i] == 1:
				var c := raw[i]
				var bright := c.get_luminance() > 0.5
				if bright and ((c.b > c.r + 0.12) or (c.r > 0.75 and c.r >= c.b + 0.25)):
					on = false   # a window or an engine: it shows through
			if on:
				A[i] = 1
	var x0: int = int(_H.x0) - 1
	var y0: int = int(_H.y0) - 1
	var bw := float(int(_H.x1) - int(_H.x0) + 3)
	var bh := float(int(_H.y1) - int(_H.y0) + 3)
	var mean_l := 0.0
	var nl := 0
	for i2 in w * h:
		if mask[i2] == 1:
			mean_l += raw[i2].get_luminance()
			nl += 1
	mean_l /= maxf(1.0, float(nl))
	# which piece each armour pixel belongs to (-1 none)
	var pid := PackedInt32Array()
	pid.resize(w * h)
	pid.fill(-1)
	var PW := 13
	var PH := maxi(8, int(bh / 3.0))
	for y in h:
		for x in w:
			var i3 := y * w + x
			if A[i3] == 0:
				continue
			var row := (y - y0) / PH
			var col := (x - x0 + (row % 2) * (PW / 2)) / PW
			pid[i3] = row * 1000 + col
	var groups := {}
	for y2 in h:
		for x2 in w:
			var id := pid[y2 * w + x2]
			if id < 0:
				continue
			if not groups.has(id):
				groups[id] = []
			(groups[id] as Array).append(Vector2i(x2, y2))
	for id2 in groups:
		var arr: Array = groups[id2]
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-1, -1)
		var sum := Vector2.ZERO
		for p in arr:
			var q: Vector2i = p
			mn = Vector2i(mini(mn.x, q.x), mini(mn.y, q.y))
			mx = Vector2i(maxi(mx.x, q.x), maxi(mx.y, q.y))
			sum += Vector2(q)
		var im := Image.create(mx.x - mn.x + 1, mx.y - mn.y + 1, false, Image.FORMAT_RGBA8)
		for p2 in arr:
			var q2: Vector2i = p2
			var i4 := q2.y * w + q2.x
			# the form underneath: a lit part of the ship is a lit part of the armour
			var under := raw[i4].get_luminance() if mask[i4] == 1 else mean_l
			var form := clampf(0.82 + 0.6 * (under - mean_l), 0.62, 1.12)
			var light := 1.12 - 0.3 * clampf((float(q2.y) - float(y0)) / bh, 0.0, 1.0)
			var c2 := STEEL * form * light
			c2.a = 1.0
			var outside := false
			var seam := false
			var top := false
			var bottom := false
			for o2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx2: int = q2.x + o2.x
				var ny2: int = q2.y + o2.y
				if nx2 < 0 or ny2 < 0 or nx2 >= w or ny2 >= h or A[ny2 * w + nx2] == 0:
					outside = true
				elif pid[ny2 * w + nx2] != int(id2):
					if o2 == Vector2i(1, 0) or o2 == Vector2i(0, 1):
						seam = true
				if o2 == Vector2i(0, -1) and (ny2 < 0 or pid[maxi(0, ny2) * w + nx2] != int(id2)):
					top = true
				if o2 == Vector2i(0, 1) and (ny2 >= h or pid[mini(h - 1, ny2) * w + nx2] != int(id2)):
					bottom = true
			if outside or seam:
				c2 = OUTLINE
			elif top:
				c2 = c2.lerp(Color.WHITE, 0.35)
			elif bottom:
				c2 = c2 * 0.72
			c2 = Color(minf(1.0, c2.r), minf(1.0, c2.g), minf(1.0, c2.b), 1.0)
			if true:
				# see-through steel: the plate thin, its lines and rivets solid,
				# a lighter sheen band across it
				var sheen := absf(fposmod(float(q2.x + q2.y), 40.0) - 20.0) < 3.0
				var a := 0.5 if not (outside or seam) else 0.9
				if sheen and not (outside or seam):
					c2 = c2.lerp(Color.WHITE, 0.3)
					a = 0.62
				c2.a = a
			im.set_pixel(q2.x - mn.x, q2.y - mn.y, c2)
		# rivets: a dark dot, its lit side up-left
		var rivets: Array = [Vector2i(mn.x + 2, mn.y + 2), Vector2i(mx.x - 2, mn.y + 2), Vector2i(mn.x + 2, mx.y - 2), Vector2i(mx.x - 2, mx.y - 2)]
		for rv in rivets:
			var v: Vector2i = rv
			if v.x <= mn.x or v.y <= mn.y or v.x >= mx.x or v.y >= mx.y:
				continue
			if pid[v.y * w + v.x] != int(id2) or pid[(v.y - 1) * w + v.x - 1] != int(id2):
				continue
			var rc := RIVET
			rc.a = 0.95
			im.set_pixel(v.x - mn.x, v.y - mn.y, rc)
			var hl := STEEL.lerp(Color.WHITE, 0.6)
			hl.a = 0.9
			im.set_pixel(v.x - 1 - mn.x, v.y - 1 - mn.y, hl)
		var c3 := sum / float(arr.size())
		var out := (c3 - Vector2(_cx, _cy))
		_pieces.append({img = im, tex = ImageTexture.create_from_image(im), at = _screen(mn), c = _screen(Vector2i(c3.round())),
			out = out.normalized() if out.length() > 0.5 else Vector2.UP, on = false, t_on = -9.0})
		for p3 in arr:
			if _rng.randf() < 0.5:
				_glint_px.append(_screen(p3))


func _process(delta: float) -> void:
	if auto:
		advance(delta)


func _target() -> int:
	if brace <= 0:
		return 0
	return clampi(int(ceil(float(_pieces.size()) * float(brace) / float(_peak))), 1, _pieces.size())


func gain(amount: int) -> void:
	if amount <= 0:
		return
	brace += amount
	_peak = maxi(_peak, brace)
	var n := _target()
	var off: Array = _pieces.filter(func(p: Dictionary) -> bool: return not p.on)
	# the side facing the enemy first, the wave running back over the hull
	off.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(facing) * (a.c as Vector2).x > float(facing) * (b.c as Vector2).x)
	var have := _pieces.size() - off.size()
	var span := 0.3
	for i in mini(n - have, off.size()):
		var p: Dictionary = off[i]
		p.on = true
		p.t_on = t + span * float(i) / float(maxi(1, n - have))
	moment.emit(&"bolt_on", minf(1.0, float(amount) / 10.0), span)
	_flashes.append({p = Vector2.ZERO, t0 = t + span + 0.05, kind = &"clamp"})
	_next_glint = t + _rng.randf_range(4.0, 7.0)


## Brace lost without a hit (a fight's own rules): the panels go quietly, the
## far side first, tumbling off without a clang.
func shed_to(n: int) -> void:
	brace = maxi(0, n)
	var on: Array = _pieces.filter(func(p: Dictionary) -> bool: return p.on)
	on.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(facing) * (a.c as Vector2).x < float(facing) * (b.c as Vector2).x)
	var drop := on.size() - _target()
	for i in maxi(0, drop):
		var p2: Dictionary = on[i]
		p2.on = false
		_chips.append({tex = p2.tex, at = p2.at, size = Vector2((p2.img as Image).get_size()), t0 = t + 0.03 * i,
			dir = (p2.out as Vector2), speed = _rng.randf_range(20.0, 45.0), spin = 3.0})
	if drop > 0:
		moment.emit(&"plate_off", minf(1.0, float(drop) / 12.0), 0.6)


## A hit of `amount` reaching the brace (after any block). Returns what goes on
## to the hull.
func absorb(amount: int, at: Vector2 = Vector2.INF) -> int:
	if brace <= 0 or amount <= 0:
		return amount
	var took := mini(amount, brace)
	brace -= took
	var q := at if at != Vector2.INF else _front_point()
	var on: Array = _pieces.filter(func(p: Dictionary) -> bool: return p.on)
	if on.is_empty():
		return amount - took
	on.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.c as Vector2).distance_to(q) < (b.c as Vector2).distance_to(q))
	var hit: Dictionary = on[0]
	var hp := (hit.c as Vector2)
	# the clang: a white flash and sparks glancing back toward the shooter
	_flashes.append({p = hp, t0 = t, kind = &"clang", r = 10, s = 1.0, life = 0.2})
	for i in 16:
		var dv := (Vector2(float(facing), 0.0) + Vector2.RIGHT.rotated(_rng.randf() * TAU) * 0.9).normalized()
		_motes.append({p = hp, v = dv * _rng.randf_range(90.0, 220.0), age = 0.0, life = _rng.randf_range(0.1, 0.26)})
	_dent(hit, hp)
	moment.emit(&"clang", 0.5 + 0.5 * float(took) / float(maxi(1, _peak)), 0.0)
	var drop := on.size() - _target()
	for i2 in maxi(0, drop):
		var p2: Dictionary = on[i2]
		p2.on = false
		var sz: Vector2 = Vector2((p2.img as Image).get_size())
		_chips.append({tex = p2.tex, at = p2.at, size = sz, t0 = t + 0.06 + 0.03 * i2,
			dir = ((p2.out as Vector2) + Vector2(float(facing) * 0.5, 0.0)).normalized(),
			speed = _rng.randf_range(30.0, 70.0), spin = _rng.randf_range(3.0, 6.0) * (1.0 if _rng.randf() < 0.5 else -1.0)})
	if drop > 0:
		moment.emit(&"plate_off", minf(1.0, float(drop) / 12.0), 0.6)
	return amount - took


## A dent where the shot landed: a few darker pixels with a lit lip, on the
## piece's own picture, so it stays until the piece comes off.
func _dent(p: Dictionary, at: Vector2) -> void:
	var im: Image = p.img
	var lp := Vector2i((at - Vector2(p.at)).round())
	for y in range(lp.y - 2, lp.y + 3):
		for x in range(lp.x - 2, lp.x + 3):
			if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height():
				continue
			var c := im.get_pixel(x, y)
			if c.a <= 0.0 or c == OUTLINE:
				continue
			var d := Vector2(x - lp.x, y - lp.y).length()
			if d <= 1.2:
				im.set_pixel(x, y, Color(c.r * 0.45, c.g * 0.45, c.b * 0.5, maxf(c.a, 0.9)))
			elif d <= 2.3 and (x - lp.x) + (y - lp.y) < 0:
				im.set_pixel(x, y, Color(minf(1, c.r * 1.35), minf(1, c.g * 1.35), minf(1, c.b * 1.35), c.a))
	(p.tex as ImageTexture).update(im)


func _front_point() -> Vector2:
	var best := -1e9
	var bp := _origin
	for p in _pieces:
		if not p.on:
			continue
		var s := float(facing) * (p.c as Vector2).x + _rng.randf() * 30.0
		if s > best:
			best = s
			bp = p.c
	return bp


func advance(delta: float) -> void:
	t += delta
	if brace > 0 and t >= _next_glint:
		_glint_t = t
		_next_glint = t + _rng.randf_range(4.0, 7.0)
		moment.emit(&"brace_glint", 0.05, 0.45)
	for f in _flashes:
		if f.kind == &"clamp" and not f.get("fired", false) and t >= float(f.t0):
			f.fired = true
			moment.emit(&"clamp", 0.6, 0.0)
	var kept: Array = []
	for mo in _motes:
		mo.age += delta
		if mo.age < mo.life:
			mo.p += mo.v * delta
			mo.v *= exp(-4.5 * delta)
			kept.append(mo)
	_motes = kept
	_flashes = _flashes.filter(func(f2: Dictionary) -> bool:
		return f2.kind == &"clamp" and not f2.get("fired", false) or t - float(f2.t0) <= float(f2.get("life", 0.2)))
	_chips = _chips.filter(func(c: Dictionary) -> bool: return t - float(c.t0) < 0.75)
	queue_redraw()
	for c2 in get_children():
		(c2 as CanvasItem).queue_redraw()


func _paint_body(ci: CanvasItem) -> void:
	for p in _pieces:
		if not p.on or t < float(p.t_on):
			continue
		# clamping on: slid in three pixels from outside, then home
		var a := t - float(p.t_on)
		var slide := Vector2.ZERO
		if a < 0.034:
			slide = (p.out as Vector2) * 3.0
		elif a < 0.067:
			slide = (p.out as Vector2) * 1.0
		ci.draw_texture(p.tex, (Vector2(p.at) + slide).round())
	for c in _chips:
		var age := t - float(c.t0)
		if age < 0.0:
			continue
		var dist := float(c.speed) * (1.0 - exp(-2.0 * age)) / 2.0
		var pp := (Vector2(c.at) + (c.dir as Vector2) * dist).round()
		var al := 1.0 if age < 0.4 else (0.6 if age < 0.55 else (0.3 if age < 0.68 else 0.12))
		var sz: Vector2 = c.size
		var rot := posmod(int(floor(age * float(c.spin))), 4)
		ci.draw_set_transform(pp + sz * 0.5, float(rot) * PI * 0.5, Vector2.ONE)
		ci.draw_texture(c.tex, -sz * 0.5, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_light(ci: CanvasItem) -> void:
	# a piece landing: two frames of light on it
	for p in _pieces:
		var a := t - float(p.t_on)
		if p.on and a >= 0.067 and a < 0.134:
			ci.draw_texture(p.tex, Vector2(p.at), Color(0.45, 0.5, 0.55, 1))
	# the rare glint: a bright diagonal band crossing the armour
	var ga := t - _glint_t
	if brace > 0 and ga >= 0.0 and ga < 0.45:
		var x0 := _origin.x + float(_r.position.x) + float(int(_H.x0)) - float(_h)
		var x1 := _origin.x + float(_r.position.x) + float(int(_H.x1)) + float(_h)
		var front := lerpf(x0, x1, ga / 0.45)
		for q in _glint_px:
			var d := absf((q as Vector2).x + (q as Vector2).y * 0.7 - front - (_origin.y + float(_r.position.y)) * 0.7)
			if d < 1.5:
				ci.draw_rect(Rect2(q, Vector2.ONE), Color(0.5, 0.55, 0.6, 1))
	for f in _flashes:
		if f.kind != &"clang":
			continue
		var age := t - float(f.t0)
		var x := age / float(f.life)
		var l := (1.0 if x < 0.25 else (0.6 if x < 0.5 else (0.32 if x < 0.75 else 0.14))) * float(f.s)
		var tex := ShipBreakup._white(int(f.r))
		ci.draw_texture(tex, (Vector2(f.p) - Vector2(tex.get_size()) * 0.5).round(), Color(l, l, l * 0.95, 1))
	for mo in _motes:
		var f2: float = mo.age / mo.life
		var c := Color(1, 1, 0.95) if f2 < 0.4 else (Color(1.0, 0.8, 0.45) if f2 < 0.75 else Color(0.55, 0.35, 0.2))
		var p2: Vector2 = (mo.p as Vector2).round()
		ci.draw_rect(Rect2(p2, Vector2.ONE), c)
		var tail: Vector2 = ((mo.p as Vector2) - (mo.v as Vector2).normalized() * 2.0).round()
		if tail != p2:
			ci.draw_rect(Rect2(tail, Vector2.ONE), c * Color(0.5, 0.5, 0.5, 1))
