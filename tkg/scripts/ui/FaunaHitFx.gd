class_name FaunaHitFx
extends ShipHitFx

## DAMAGE ON A CREATURE (`FaunaGuard`). Jon: "the damage to the void leviathan
## and voidwhale calf should be more organic... not ship damage", and of the
## three ideas, "damage:A+B+C (all wounds! they're sick)": every hit is one of
## three KINDS, rolled from the fight's seeded generator the way a ship's hit
## marks roll theirs (`roll_organic`), and they build up together. Every mark
## is baked into the picture the motion is cut from (`marks()`, as the ship
## marks are), so it swells and dips with the body; what moves on it (a
## wound's pulse, a dying light) is drawn through the motion's own table; what
## comes off it (drops, scales, vapour) flies free.
##   WOUND   the hide tears in a slit along the body, glowing tissue inside,
##           the torn lip lit above and dark round it. Every wound pulses with
##           one heartbeat, quicker as the hull goes; each weeps a drop of ichor
##           now and then, more often when badly hurt. A hit splashes ichor.
##   BRUISE  the hide bruises purple-dark round the hit.
##   SHED    a patch of scales chips off and tumbles away, raw pale skin under
##           it, cracks running from its edge; a crystal or spine near the hit
##           snaps and falls.
## Whatever the kind, two things build with the hull lost: the creature's own
## lights flicker and die round each hit (more the bigger it was, nearest
## first) until near death it is nearly dark, a dead light sparking back now
## and then; and under 45% it trails a pale vapour from its raw patches (or,
## with none yet, from its marks).
## ONE PICTURE, SO NO FIGHTING: the marks are one baked image, each kind
## leaving tissue (a wound, raw skin) alone -- a bruise or a shed goes round a
## wound, a wound may open on a bruise or on raw skin -- and nothing that moves
## is drawn on a pixel a later wound has opened.
## The hit's white flash (the art's) and the numbers stay as they are.

var body: FaunaGuard.Body
var changes := 0

var _clock := FaunaGuard.Clock.new()
var _skin: FaunaGuard.GuardSkin
var _wl: Image
var _wl_tex: ImageTexture
var _wl_dirty := false
var _bound: FaunaMotion = null
var _last_sig := 0
var _since_step := 0
var _ooze := FaunaGuard.Motes.new()
var _vapour := FaunaGuard.Motes.new()
## Wounds: {c (canvas), low (canvas, the drip point), big, next}
var _wounds: Array = []
## Dying lights: {p (canvas), c (its light colour), t0, len}
var _dying: Array = []
var _dead_lights: Array[Vector2i] = []
var _lights_alive: Array[Vector2i] = []
## Shed: raw skin left (canvas points), the cut-off pixels (canvas), falling bits
var _raw: Array[Vector2i] = []
var _cut := PackedVector2Array()
var _bits: Array = []      ## {tex, at, size, dir, speed, spin, t0}
var _brings: Array = []
var _next_vapour := 0.0

const TISSUE: Array[Color] = [Color("#ffb0a8"), Color("#ff5a6e"), Color("#c22a4a"), Color("#5a0f24")]
const ICHOR: Array = [Color("#fff0f2"), Color("#ff8a9c"), Color("#ff4a68"), Color("#c02848"), Color("#701428")]
const BRUISE: Array[Color] = [Color("#2a1038"), Color("#5a2a78"), Color("#8a4aa8"), Color("#9a8a3a")]
const RAW := Color("#e4b4ac")
const VAPOUR: Array = [Color("#7a6466"), Color("#5c4a4e"), Color("#3a2e32"), Color("#1e181a")]

const SKIN_WOUND := """
uniform float beat = 0.0;
void fragment() {
	ivec2 p = ivec2(floor(UV * csize));
	COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	if (kept(p)) { return; }
	int part;
	ivec2 r = rest_of(p, part);
	if (!inb(r)) { return; }
	vec4 d = texelFetch(TEXTURE, r, 0);
	if (d.a <= 0.0) { return; }
	float L = d.a * (0.3 + 0.75 * beat);
	COLOR = vec4(d.rgb * q8(L, p), 1.0);
}
"""


func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	super.setup(img, used, origin, seed, the_facing)
	_clock.fps = body.fps
	var b := body
	for i in b.W * b.H:
		if b.glow[i] == 1:
			_lights_alive.append(Vector2i(i % b.W, i / b.W))
	_wl = Image.create(b.W, b.H, false, Image.FORMAT_RGBA8)
	_wl_tex = ImageTexture.create_from_image(_wl)
	_skin = FaunaGuard.GuardSkin.new()
	_skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skin.make(b, FaunaGuard.skin_code(true, SKIN_WOUND))
	_skin.paint = func(ci: CanvasItem) -> void:
		if not _wounds.is_empty():
			ci.draw_texture(_wl_tex, Vector2.ZERO)
	add_child(_skin)
	move_child(_skin, 1)


func _canvas(p: Vector2i) -> Vector2i:
	return p + _r.position


func _local(c: Vector2i) -> Vector2i:
	return c - _r.position


## What came off the picture (canvas pixels): `EnemyArt` clears them.
func cut_px() -> PackedVector2Array:
	return _cut


func damaged(img: Image) -> Image:
	var out := super.damaged(img)
	for q in _cut:
		out.set_pixel(int(q.x), int(q.y), Color(0, 0, 0, 0))
	return out


func hit(amount: int, hp_after: int, max_hp: int, kind: int = -1, near: Vector2 = Vector2.INF) -> int:
	if int(_H.n) == 0:
		return Kind.SCORCH
	var frac := float(amount) / float(maxi(1, max_hp))
	var big := frac >= 0.12
	_hp = float(hp_after) / float(maxi(1, max_hp))
	if kind < 0 or kind > Organic.SHED:
		kind = roll_organic(frac)
	var p := _on_hide(_pick(false, 6.0 if big else 4.5, near))
	_mark(kind, p, big, frac, false)
	_dim_lights(p, big, frac, kind == Organic.BRUISE)
	moment.emit(&"impact", 0.35 + 0.55 * minf(1.0, frac / 0.3), 0.0)
	var extras := 0 if _hp > 0.75 else (1 if _hp > 0.5 else (2 if _hp > 0.25 else 3))
	_quiet = true
	_sc = SIZE * 0.7 * mark_scale
	for e in extras:
		_mark(roll_organic(0.03), _on_hide(_pick(false, 4.0, Vector2.INF, Vector2(p))), false, frac * 0.3, true)
	_sc = SIZE * mark_scale
	_quiet = false
	return kind


enum Organic { WOUND, BRUISE, SHED }
## Forced kind for a harness (-1: rolled).
static var force_kind := -1


## Which kind a hit is, from the fight's generator (repeatable): small hits
## lean to bruises, big ones tear and shed.
func roll_organic(frac: float) -> int:
	if force_kind >= 0:
		return force_kind
	var small := frac < 0.12
	var w := [0.3, 0.45, 0.25] if small else [0.45, 0.2, 0.35]
	var r := _rng.randf()
	for k in 3:
		r -= float(w[k])
		if r < 0.0:
			return k
	return Organic.WOUND


## A hit lands on the hide, not on a spine (the pale crystals drew `_pick`'s
## eye): down its column to the first hide pixel.
func _on_hide(p: Vector2i) -> Vector2i:
	var b := body
	var c := _canvas(p)
	for k in 24:
		var q := c + Vector2i(0, k)
		if q.y >= b.H:
			break
		var i := q.y * b.W + q.x
		if b.ink[i] == 1 and b.spine[i] == 0 and b.glow[i] == 0 and b.din[i] >= 6:
			return _local(q)
	return p


func _mark(kind: int, p: Vector2i, big: bool, frac: float, extra: bool) -> void:
	match kind:
		Organic.WOUND:
			_wound(p, big, extra)
		Organic.BRUISE:
			_bruise(p, big, frac, extra)
		_:
			_shed(p, big, extra)


# ------------------------------------------------------------------ wounds

func _wound(p: Vector2i, big: bool, extra: bool) -> void:
	var k := _sc / SIZE
	var hl := (7.5 if big else 5.5) * k
	var hw := (1.9 if big else 1.4) * k
	var ang := _rng.randf_range(-0.4, 0.4)
	var ca := cos(ang)
	var sa := sin(ang)
	var core: Array[Vector2i] = []
	var low := p
	var reach := int(ceil(hl)) + 3
	for y in range(p.y - reach, p.y + reach + 1):
		for x in range(p.x - reach, p.x + reach + 1):
			if x < 0 or y < 0 or x >= _w or y >= _h:
				continue
			var i := y * _w + x
			if _mask[i] == 0:
				continue
			var dx := float(x - p.x)
			var dy := float(y - p.y)
			var al := dx * ca + dy * sa
			var ac := -dx * sa + dy * ca
			var e := (al / hl) * (al / hl) + (ac / hw) * (ac / hw)
			var o := _orig[i]
			if e <= 0.3:
				_put_px(i, Color(TISSUE[1].r, TISSUE[1].g, TISSUE[1].b, o.a))
				_what[i] = 2
				core.append(Vector2i(x, y))
				if y > low.y:
					low = Vector2i(x, y)
			elif e <= 1.0:
				_put_px(i, Color(TISSUE[2].r, TISSUE[2].g, TISSUE[2].b, o.a))
				_what[i] = 2
				core.append(Vector2i(x, y))
			elif e <= 2.2 and _what[i] != 2:
				# the torn lip: lit above, dark and bloodied below and round
				var c := _col[i]
				var q: Color
				if ac < 0.0 and e > 1.5:
					q = Color(minf(1.0, c.r * 1.3 + 0.05), minf(1.0, c.g * 1.25 + 0.03), minf(1.0, c.b * 1.2 + 0.03))
				else:
					q = Color(c.r * 0.45, c.g * 0.4, c.b * 0.45).lerp(TISSUE[3], 0.35)
				_put_px(i, Color(q.r, q.g, q.b, o.a))
				_what[i] = 1
	if core.is_empty():
		return
	for q2 in core:
		var cv := _canvas(q2)
		var hot := Vector2(q2 - p).length() < hl * 0.45
		_wl.set_pixel(cv.x, cv.y, Color(1.0, 0.42, 0.5, 1.0 if hot else 0.55))
	_wl_dirty = true
	var cp := _canvas(p)
	_wounds.append({c = cp, low = _canvas(low), big = big, next = t + _rng.randf_range(0.3, 0.9)})
	_marks.append({p = Vector2(p), r = hl + 2.0})
	# the splash: ichor flung out, away from the shot
	var fm := FaunaGuard.motion_of(self)
	var at := FaunaGuard.shown(fm, Vector2(cp))
	for i2 in (4 if extra else (12 if big else 8)):
		var dv := (Vector2(float(-facing) * 0.8, -0.2) + Vector2.RIGHT.rotated(_rng.randf() * TAU)).normalized()
		_ooze.add(at, dv * _rng.randf_range(25.0, 65.0), _rng.randf_range(0.35, 0.7), t, ICHOR, 3.0, 40.0, _rng.randf() < 0.3)
	if not _quiet:
		moment.emit(&"sizzle", 0.25, 0.3)


# ------------------------------------------------------------------ bruises

func _bruise(p: Vector2i, big: bool, _frac: float, _extra: bool) -> void:
	var k := _sc / SIZE
	var R := (9.0 if big else 6.5) * k
	var fd := ShipBreakup._field(_rng, _w, _h, 3)
	var reach := int(ceil(R)) + 2
	for y in range(p.y - reach, p.y + reach + 1):
		for x in range(p.x - reach, p.x + reach + 1):
			if x < 0 or y < 0 or x >= _w or y >= _h:
				continue
			var i := y * _w + x
			if _mask[i] == 0 or _what[i] == 2:
				continue
			var d := Vector2(x - p.x, y - p.y).length() / R + 0.18 * ShipBreakup._nz(fd, x, y)
			var odd := ((x + y + _r.position.x + _r.position.y) & 1) == 0
			var c := _col[i]
			var q := c
			var lum := c.get_luminance()
			if d < 0.4:
				q = c.lerp(BRUISE[0], 0.7)
			elif d < 0.7:
				q = c.lerp(BRUISE[1] * (0.55 + 0.7 * lum), 0.6)
			elif d < 0.95:
				q = c.lerp(BRUISE[2] * (0.5 + 0.6 * lum), 0.45 if odd else 0.3)
			elif d < 1.2 and odd:
				q = c.lerp(BRUISE[3] * (0.5 + 0.6 * lum), 0.3)
			else:
				continue
			_put_px(i, Color(q.r, q.g, q.b, _orig[i].a))
			if _what[i] == 0:
				_what[i] = 1
	_marks.append({p = Vector2(p), r = R})
	_brings.append({p = Vector2(_canvas(p)), t0 = t, r1 = 9.0 if big else 6.0})
	if not _quiet:
		moment.emit(&"thud", 0.4, 0.0)


## Every hit: its own lights die round it, nearest first, more the bigger it
## was (a bruise, more again), so the creature goes dark as its hull goes.
func _dim_lights(p: Vector2i, big: bool, frac: float, bruise: bool) -> void:
	var cp := Vector2(_canvas(p))
	var total := maxi(1, _lights_alive.size() + _dead_lights.size())
	var kill := maxi(4 if big else 2, int(round(float(total) * frac * (1.6 if bruise else 1.25))))
	_lights_alive.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(cp) < Vector2(b).distance_squared_to(cp))
	var n := mini(kill, _lights_alive.size())
	for j in n:
		var lp: Vector2i = _lights_alive[j]
		var loc := _local(lp)
		if loc.x < 0 or loc.y < 0 or loc.x >= _w or loc.y >= _h:
			continue
		var li := loc.y * _w + loc.x
		var oc := _orig[li]
		_put_px(li, Color(oc.r * 0.22, oc.g * 0.16, oc.b * 0.26, oc.a))
		_what[li] = 1
		_dead_lights.append(lp)
		_dying.append({p = lp, c = oc, t0 = t + float(j) * 0.02, len = _rng.randf_range(0.45, 0.9), h = _rng.randi() % 997})
	_lights_alive = _lights_alive.slice(n)


# ------------------------------------------------------------------ shed

func _shed(p: Vector2i, big: bool, extra: bool) -> void:
	var k := _sc / SIZE
	var R := (4.5 if big else 3.2) * k
	var fd := ShipBreakup._field(_rng, _w, _h, 3)
	var patch: Array[Vector2i] = []
	var reach := int(ceil(R)) + 3
	for y in range(p.y - reach, p.y + reach + 1):
		for x in range(p.x - reach, p.x + reach + 1):
			if x < 0 or y < 0 or x >= _w or y >= _h:
				continue
			var i := y * _w + x
			if _mask[i] == 0:
				continue
			var d := Vector2(x - p.x, y - p.y).length() - 1.2 * ShipBreakup._nz(fd, x, y)
			if d <= R:
				if _what[i] != 2:
					patch.append(Vector2i(x, y))
			elif d <= R + 1.3 and _what[i] == 0:
				var c := _col[i]
				var q := Color(minf(1.0, c.r * 1.3), minf(1.0, c.g * 1.3), minf(1.0, c.b * 1.3)) if y < p.y \
					else Color(c.r * 0.5, c.g * 0.48, c.b * 0.5)
				_put_px(i, Color(q.r, q.g, q.b, _orig[i].a))
				_what[i] = 1
	if patch.is_empty():
		return
	_fly(patch, p, 3)
	for q in patch:
		var i2 := q.y * _w + q.x
		var o := _orig[i2]
		var l := o.get_luminance()
		var raw := RAW * (0.62 + 0.5 * l)
		var odd := ((q.x + q.y) & 1) == 0
		if Vector2(q - p).length() > R - 1.2 and odd:
			raw = raw * 0.82
		_put_px(i2, Color(minf(1.0, raw.r), minf(1.0, raw.g), minf(1.0, raw.b), o.a))
		_what[i2] = 2
		_raw.append(_canvas(q))
	# cracks running from the edge
	for c2 in (3 if big else 2):
		var a := _rng.randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		var pp := Vector2(p) + dir * (R + 1.0)
		for s in _rng.randi_range(3, 7):
			dir = dir.rotated(_rng.randf_range(-0.5, 0.5))
			pp += dir
			var qi := Vector2i(pp.round())
			if qi.x < 0 or qi.y < 0 or qi.x >= _w or qi.y >= _h:
				break
			var j := qi.y * _w + qi.x
			if _mask[j] == 0 or _what[j] == 2:
				break
			var oc := _col[j]
			_put_px(j, Color(oc.r * 0.35, oc.g * 0.33, oc.b * 0.38, _orig[j].a))
			_what[j] = 3
	_marks.append({p = Vector2(p), r = R + 1.0})
	# a crystal or spine near it snaps
	if not extra:
		_snap(_canvas(p), 10.0 if big else 7.0)
	if not _quiet:
		moment.emit(&"crack", 0.4, 0.15)


## Pixels (local) flung off as tumbling chips in their own colours.
func _fly(px: Array, from: Vector2i, n: int) -> void:
	var groups := {}
	for q in px:
		var v: Vector2i = q
		var a := atan2(float(v.y - from.y), float(v.x - from.x))
		var g := int(fposmod(a, TAU) / (TAU / float(n)))
		if not groups.has(g):
			groups[g] = []
		(groups[g] as Array).append(v)
	var fm := FaunaGuard.motion_of(self)
	for g2 in groups.values():
		var arr: Array = g2
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-1, -1)
		for q2 in arr:
			mn = Vector2i(mini(mn.x, q2.x), mini(mn.y, q2.y))
			mx = Vector2i(maxi(mx.x, q2.x), maxi(mx.y, q2.y))
		var side := maxi(mx.x - mn.x + 1, mx.y - mn.y + 1)
		var im := Image.create(side, side, false, Image.FORMAT_RGBA8)
		for q3 in arr:
			im.set_pixel(q3.x - mn.x, q3.y - mn.y, _col[q3.y * _w + q3.x])
		var mid := Vector2(mn) + Vector2(side, side) * 0.5
		var dir := ((mid - Vector2(from)).normalized() + Vector2(float(-facing) * 0.7, -0.5)).normalized()
		_bits.append({tex = ImageTexture.create_from_image(im), at = FaunaGuard.shown(fm, Vector2(_canvas(mn))), size = side,
			dir = dir, speed = _rng.randf_range(35.0, 70.0), spin = _rng.randf_range(5.0, 9.0) * (1.0 if _rng.randf() < 0.5 else -1.0),
			t0 = t})


## The nearest spine (a crystal on the Leviathan, a line on the calf) within
## `reach` of canvas point `c` loses its top half: cleared from the picture,
## falling as a chip.
func _snap(c: Vector2i, reach: float) -> void:
	var b := body
	var best := -1
	var bd := reach * reach
	for y in range(maxi(0, c.y - int(reach)), mini(b.H, c.y + int(reach) + 1)):
		for x in range(maxi(0, c.x - int(reach)), mini(b.W, c.x + int(reach) + 1)):
			var i := y * b.W + x
			if b.spine[i] == 1:
				var d := float((x - c.x) * (x - c.x) + (y - c.y) * (y - c.y))
				if d < bd:
					bd = d
					best = i
	if best < 0:
		# none near: the nearest above it, along the back
		for dy in range(1, 30):
			var y2 := c.y - dy
			if y2 < 0:
				break
			for dx in range(-6, 7):
				var x2 := c.x + dx
				if x2 >= 0 and x2 < b.W and b.spine[y2 * b.W + x2] == 1:
					best = y2 * b.W + x2
					break
			if best >= 0:
				break
	if best < 0:
		return
	var comp: Array[int] = [best]
	var seen := {best: true}
	var k := 0
	while k < comp.size() and comp.size() < 400:
		var i0 := comp[k]
		k += 1
		for dy2 in range(-1, 2):
			for dx2 in range(-1, 2):
				var j := i0 + dy2 * b.W + dx2
				if j >= 0 and j < b.spine.size() and b.spine[j] == 1 and not seen.has(j):
					seen[j] = true
					comp.append(j)
	# its own columns only (a row of crystals touches along the back)
	var bx := best % b.W
	var own: Array[int] = []
	for i5 in comp:
		if absi(i5 % b.W - bx) <= 5:
			own.append(i5)
	comp = own
	var y0 := 1 << 20
	var y1 := -1
	for i1 in comp:
		y0 = mini(y0, i1 / b.W)
		y1 = maxi(y1, i1 / b.W)
	var cut_below := y0 + int(float(y1 - y0) * 0.45)
	var off: Array = []
	for i2 in comp:
		var yy := i2 / b.W
		var xx := i2 % b.W
		# a jagged break: the line steps a pixel or two by column
		var jag := int(FaunaGuard.hash01(xx, 31) * 3.0) - 1
		if yy <= cut_below + jag:
			off.append(Vector2i(xx, yy))
			b.spine[i2] = 0
	if off.size() < 2:
		return
	var loc: Array = []
	for q in off:
		var l := _local(q)
		if l.x >= 0 and l.y >= 0 and l.x < _w and l.y < _h:
			loc.append(l)
		_cut.append(Vector2(q))
	version += 1
	if not loc.is_empty():
		_fly(loc, _local(Vector2i((off[0] as Vector2i).x, cut_below + 2)), 2)


# ------------------------------------------------------------------ time

func advance(delta: float) -> void:
	t += delta
	var fm := FaunaGuard.motion_of(self)
	if fm != _bound:
		_bound = fm
		_clock.bind(t, fm)
	var tq := _clock.tq(t)
	var ks := FaunaGuard.keep_of(self)
	if true:
		# drips: a drop from each wound now and then, more often when hurt
		var gap := 1.5 if _hp > 0.6 else (1.0 if _hp > 0.3 else 0.6)
		for w in _wounds:
			if t >= float(w.next):
				w.next = t + _rng.randf_range(0.6, 1.4) * gap
				var at := FaunaGuard.shown(fm, Vector2(w.low as Vector2i)) + Vector2(0, 1)
				_ooze.add(at, Vector2(_rng.randf_range(-3.0, 3.0) + float(-facing) * 4.0, _rng.randf_range(5.0, 10.0)),
					_rng.randf_range(1.0, 1.6), t, ICHOR, 0.6, 8.0, _rng.randf() < 0.6)
		if _wl_dirty:
			_wl_dirty = false
			_wl_tex.update(_wl)
		var per := lerpf(0.75, 1.5, clampf(_hp, 0.0, 1.0))
		var ph := fposmod(tq + _clock.phase, per) / per
		var beat := 1.0 if ph < 0.08 else (0.45 if ph < 0.16 else (0.85 if ph < 0.24 else (0.35 if ph < 0.36 else (0.12 if ph < 0.6 else 0.0))))
		_skin.follow(fm, tq + _clock.phase, ks)
		_skin.mat.set_shader_parameter("beat", beat)
	if _hp < 0.45 and not _marks.is_empty() and t >= _next_vapour:
		_next_vapour = t + (0.16 if _hp > 0.25 else 0.09)
		var src: Vector2i
		if not _raw.is_empty():
			src = _raw[_rng.randi() % _raw.size()]
		else:
			src = _canvas(Vector2i((_marks[_rng.randi() % _marks.size()].p as Vector2).round()))
		var at2 := FaunaGuard.shown(fm, Vector2(src))
		_vapour.add(at2, Vector2(float(-facing) * _rng.randf_range(6.0, 14.0), -_rng.randf_range(6.0, 14.0)),
			_rng.randf_range(0.8, 1.2), t, [Color("#fff2ee"), Color("#f0d0cc"), Color("#c8a6a8"), Color("#8a7478"), Color("#4a3c40")], 0.8,
			0.0, _rng.randf() < 0.5)
	_ooze.prune(tq)
	_vapour.prune(tq)
	_dying = _dying.filter(func(d: Dictionary) -> bool: return tq - float(d.t0) < float(d.len))
	_bits = _bits.filter(func(c: Dictionary) -> bool: return tq - float(c.t0) < 0.8)
	_brings = _brings.filter(func(r: Dictionary) -> bool: return tq - float(r.t0) < 0.3)
	if _dirty:
		_dmg_tex.update(_dmg)
		_dirty = false
	var st := _clock.index(t)
	if st != _clock.step:
		_clock.step = st
		_since_step = 0
		for c in get_children():
			(c as CanvasItem).queue_redraw()
	else:
		_since_step += 1
	var sig := 0
	for c2 in get_children():
		sig = sig * 7919 + int(c2.get_meta(&"sig", 0))
	if not _wounds.is_empty():
		sig = sig * 31 + int(_skin.mat.get_shader_parameter("beat") * 8.0)
	# counted once a step, on the frame after it (the step's paint is in)
	if _since_step == 1:
		if sig != _last_sig:
			changes += 1
		_last_sig = sig


## A wound has opened (or scales come off) on this canvas pixel since: no
## dying light is drawn on it.
func _opened(c: Vector2i) -> bool:
	var l := _local(c)
	return l.x >= 0 and l.y >= 0 and l.x < _w and l.y < _h and _what[l.y * _w + l.x] == 2


func busy() -> bool:
	return false


func _paint_body(ci: CanvasItem) -> void:
	if draw_marks:
		ci.draw_texture(_dmg_tex, _origin + Vector2(_r.position))
	var keep := FaunaGuard.keep_of(self)
	var tq := _clock.tq(t)
	var h := 0
	for c in _bits:
		var age := tq - float(c.t0)
		if age < 0.0:
			continue
		var dist := float(c.speed) * (1.0 - exp(-2.2 * age)) / 2.2
		var pp := (Vector2(c.at) + (c.dir as Vector2) * dist + Vector2(0, 40.0 * age * age)).round()
		var sz := float(c.size)
		if FaunaGuard.in_keep(keep, pp, Vector2(sz, sz)):
			continue
		var rot := posmod(int(floor(age * float(c.spin))), 4)
		var al := 1.0 if age < 0.45 else (0.6 if age < 0.6 else (0.3 if age < 0.7 else 0.12))
		ci.draw_set_transform(pp + Vector2(sz, sz) * 0.5, float(rot) * PI * 0.5, Vector2.ONE)
		ci.draw_texture(c.tex, -Vector2(sz, sz) * 0.5, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		h = h * 31 + int(pp.x) * 3 + int(pp.y) * 7 + rot
	# vapour is matter, drawn over (not light)
	h = h * 31 + _vapour.paint(ci, keep, tq)
	ci.set_meta(&"sig", h)


func _paint_light(ci: CanvasItem) -> void:
	var keep := FaunaGuard.keep_of(self)
	var fm := FaunaGuard.motion_of(self)
	var tq := _clock.tq(t)
	var st := _clock.index(t)
	var h := 0
	h = _ooze.paint(ci, keep, tq)
	# B: dying lights flickering out, and near death a dead one sparking back
	for d in _dying:
		var a := tq - float(d.t0)
		if a < 0.0:
			continue
		var on := FaunaGuard.hash01(int(d.h), st) < (0.75 - 0.5 * a / float(d.len))
		if on and not _opened(d.p):
			var p := FaunaGuard.shown(fm, Vector2(d.p as Vector2i))
			var c: Color = d.c
			if FaunaGuard.dot(ci, keep, p, Color(c.r * 0.8, c.g * 0.8, c.b * 0.8)):
				h = h * 31 + int(p.x) + int(p.y) * 3
	if _hp < 0.4 and not _dead_lights.is_empty():
		for k in 2:
			if FaunaGuard.hash01(st, 77 + k) < 0.35:
				var lp: Vector2i = _dead_lights[int(FaunaGuard.hash01(st, 11 + k) * float(_dead_lights.size())) % _dead_lights.size()]
				if _opened(lp):
					continue
				var p2 := FaunaGuard.shown(fm, Vector2(lp))
				var oc := body.img.get_pixel(lp.x, lp.y)
				if FaunaGuard.dot(ci, keep, p2, Color(oc.r * 0.6, oc.g * 0.6, oc.b * 0.6)):
					h = h * 31 + int(p2.x) + 5
	for rg in _brings:
		var a2 := tq - float(rg.t0)
		var f := a2 / 0.3
		var rr := int(2.0 + (float(rg.r1) - 2.0) * f)
		var l := 0.45 * (1.0 - f)
		var cp := FaunaGuard.shown(fm, rg.p as Vector2).round()
		var n := int(ceil(TAU * rr)) + 6
		var seen := {}
		for i in n:
			var an := TAU * float(i) / float(n)
			var q := Vector2i(roundi(cos(an) * rr), roundi(sin(an) * rr))
			if seen.has(q):
				continue
			seen[q] = true
			if body.on(int(cp.x) + q.x, int(cp.y) + q.y - (fm.off_at(int(cp.x) + q.x, int(cp.y) + q.y) if fm != null else 0)):
				FaunaGuard.dot(ci, keep, cp + Vector2(q), Color(0.55 * l, 0.35 * l, 0.75 * l))
		h = h * 31 + rr
	ci.set_meta(&"sig", h)
