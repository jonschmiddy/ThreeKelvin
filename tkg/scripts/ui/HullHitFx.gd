class_name HullHitFx
extends ShipHitFx

## A SHIP'S HULL TAKING HITS WITHOUT HOLES IN IT (Oct 17, three looks for
## Jon's pick; `ShipHitFx.look` chooses, today's marks until he does).
##
## James, a playtester, of today's marks: when ships are damaged they get big
## holes in the hull, and ships can't really have holes in them. Jon: "Can we
## update the damage shader to be more realistic and prettier?" What read as a
## hole was measured, not guessed: Chain's bite (a near-black disc 9 to 17 px
## across on a full sheet, its pixels flown off as chips), the vent's punched
## disc, and the black-brown core of every soot disc, which on a dark hull is the
## same colour as space. So every look here is armour taking punishment, and
## nothing in it is see-through or punched out to space:
##
##   A  BATTLE-WORN PLATING. Dents (the plating's own shading bent: shadow under
##      the top of the dish, light on its floor, a raised lip), soot streaks
##      thrown from the blast, paint scraped back to the metal, popped rivets
##      along a lifted panel line. Grounded and quiet; at low hull, split seams
##      at the edge sputter vapour.
##   B  HEAT AND STRESS. Every impact leaves a heat bloom on the plating that
##      cools white, orange, dull red, then a dark scorch over about four
##      seconds; under 60% hull the hull's own panel lines glow where the hits
##      are, more of them the lower it goes, throwing sparks.
##   C  PLATES CRACK AND PEEL. A big hit tears a plate and curls it back over its
##      hinge, showing the ribs and stringers under it (lit and shadowed, never
##      empty); a small one cracks a plate along its panel lines. Under half
##      hull, each breach sputters vapour and throws sparks.
##   D  ALL THREE, MIXED PER HIT (Jon: "What would battleworn + heat + stress
##      and crack and peel look like together?"), as a creature's hits mix
##      wounds, bruises and shed. Small hits lean to A's dents and scrapes and
##      C's knocked panels, big ones to B's blooms and C's peels; every hit
##      also gets B's bloom cooling to a scorch (smaller on a small hit), the
##      mark that reads on a dark hull. Low hull brings B's glowing lines, C's
##      breaches and A's split edges together, each held down (fewer lines, the
##      newest three breaches and two splits) so it stays quieter than today's.
##
## THE SAME RULES AS EVERY MARK SINCE: on the hull's own pixels, never its
## outline (the silhouette never changes); every colour is one the sprite
## already has (`_snap`, HullWear's guarantee) or the heat ramp; light has a
## falloff in held steps with dithered edges, and whatever glows changes shape
## twelve times a second (`GLOW_HZ`); a mote that leaves the hull stays inside
## the shield's oval (`ShieldFx.fit`, which the pack layout keeps clear of the
## words, name and bars). Each hit is rolled from the fight's seeded stream as
## today, so two machines draw the same marks; what moves with time alone (a
## spark, a puff) draws from its own stream so it can never move a mark.
##
## The marks are `marks()` like today's, so a wreck and a death keep them.

const GLOW_HZ := 12.0
const NAMES_A := ["DENT", "SOOT", "SCRAPE", "RIVETS", "SPLIT"]
const NAMES_B := ["BLOOM", "SPLASH", "STRESS"]
const NAMES_C := ["PEEL", "KNOCK", "SOOT"]
const NAMES_D := ["DENT", "SCRAPE", "RIVETS", "SOOT", "BLOOM", "PEEL", "KNOCK", "SPLIT"]
## D at most this many breaches sputtering and this many split edges, the
## newest, so a wrecked hull does not turn into noise.
const D_BREACHES := 3
const D_SPLITS := 2

## 1 A, 2 B, 3 C, 4 D (all three mixed per hit; `ShipHitFx.look`).
var style := 1
## Drawing a mark that belongs on the plate (a dent, a scrape, rivets, a knocked
## panel, a split edge): it leaves alone the structure a peel has bared, so a
## dent never sits inside a plate that is already peeled back.
var _plate := false

var _lum := PackedFloat32Array()
var _seam := PackedByteArray()
var _edge := PackedByteArray()
var _pal := PackedColorArray()
var _snapc := {}
var _vap: Array[Color] = []
var _ovc := Vector2.ZERO
var _ovr := Vector2.ONE
var _fx := RandomNumberGenerator.new()
var _clock := -1.0

# the light on the plating, rebuilt GLOW_HZ times a second
var _temp := PackedFloat32Array()
var _listed := PackedByteArray()
var _tl := PackedInt32Array()
var _glow: Image
var _glow_tex: ImageTexture
var _gstep := -1
var _gdirty := false
var _blooms: Array = []        ## {p, r, t0, tau, peak, s}
var _lit: Dictionary = {}      ## B: a glowing seam pixel -> its heat
var _lit_px := PackedInt32Array()
var _next_spark := 0.0
var _vents2: Array = []        ## A's split seams, C's breaches: {p, n, px, next, until, sparks}
var _pm: Array = []            ## motes: {p, v, age, life, k (0 spark, 1 vapour, 2 fleck), c, drag}


func _build_network() -> void:
	pass   # today's crack network; nothing here uses it


func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	super.setup(img, used, origin, seed, the_facing)
	_fx.seed = seed * 31 + 17
	var n := _w * _h
	_lum.resize(n)
	_seam.resize(n)
	_edge.resize(n)
	_temp.resize(n)
	_listed.resize(n)
	_glow = Image.create(maxi(1, _w), maxi(1, _h), false, Image.FORMAT_RGBA8)
	_glow_tex = ImageTexture.create_from_image(_glow)
	var ov := ShieldFx.fit(img, used)
	_ovc = _origin + (ov.cc as Vector2)
	_ovr = Vector2(float(ov.rx), float(ov.ry))
	if int(_H.n) == 0:
		return
	var seen := {}
	for i in n:
		if _mask[i] == 0:
			continue
		var c := _orig[i]
		_lum[i] = c.get_luminance()
		var key := _key(c)
		if not seen.has(key):
			seen[key] = true
			_pal.append(Color(c.r, c.g, c.b, 1.0))
	for y in _h:
		for x in _w:
			var i := y * _w + x
			if _mask[i] == 0:
				continue
			if x == 0 or y == 0 or x == _w - 1 or y == _h - 1 or _mask[i - 1] == 0 or _mask[i + 1] == 0 \
					or _mask[i - _w] == 0 or _mask[i + _w] == 0:
				_edge[i] = 1
	_find_seams()
	_find_gas()


static func _key(c: Color) -> int:
	return (int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)


## The hull's own panel lines: a pixel darker than both its neighbours across a
## line, in a run along it (four across, three down), so a speckled texture
## does not count and a drawn seam does.
func _find_seams() -> void:
	const T := 0.05
	var hz := PackedByteArray()
	var vt := PackedByteArray()
	hz.resize(_w * _h)
	vt.resize(_w * _h)
	for y in range(1, _h - 1):
		for x in range(1, _w - 1):
			var i := y * _w + x
			if _mask[i] == 0 or _edge[i] == 1:
				continue
			var l := _lum[i] + T
			if l < _lum[i - _w] and l < _lum[i + _w]:
				hz[i] = 1
			if l < _lum[i - 1] and l < _lum[i + 1]:
				vt[i] = 1
	for y in _h:
		var run := 0
		for x in _w + 1:
			if x < _w and hz[y * _w + x] == 1:
				run += 1
			else:
				if run >= 4:
					for k in run:
						_seam[y * _w + x - 1 - k] = 1
				run = 0
	for x in _w:
		var run2 := 0
		for y in _h + 1:
			if y < _h and vt[y * _w + x] == 1:
				run2 += 1
			else:
				if run2 >= 3:
					for k in run2:
						_seam[(y - 1 - k) * _w + x] = 1
				run2 = 0


## Vapour in the ship's own greys, light to dark: the least coloured of its
## colours at four heights.
func _find_gas() -> void:
	var greys: Array = []
	for c in _pal:
		if c.s < 0.25:
			greys.append(c)
	if greys.size() < 4:
		greys = Array(_pal)
	greys.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	for q in [0.95, 0.8, 0.62, 0.45]:
		_vap.append(greys[clampi(int(q * float(greys.size() - 1)), 0, greys.size() - 1)])


## The nearest colour the sprite already has. The guarantee: a mark cannot
## bring a colour of its own. `char` also lets it be one of the heat ramp's
## three darkest (burnt metal), so soot goes brown-black rather than to the
## nearest dark the art has, which on most ships is a window's navy, the
## colour of space.
const CHAR := [5]


func _snap(c: Color, char: bool = false) -> Color:
	var k := _key(Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0))) * 2 + int(char)
	if _snapc.has(k):
		return _snapc[k]
	var best := _pal[0] if not _pal.is_empty() else c
	var bd := 1e20
	var cands := _pal
	if char:
		cands = _pal.duplicate()
		for j in CHAR:
			cands.append(ShipBreakup.HEAT_RAMP[j])
	for p in cands:
		var dr := (p.r - c.r) * 0.30
		var dg := (p.g - c.g) * 0.59
		var db := (p.b - c.b) * 0.11
		var d := dr * dr + dg * dg + db * db
		if d < bd:
			bd = d
			best = p
	_snapc[k] = best
	return best


## `_snap`, but never darker than `fl`: the nearest colour may be a darker one
## (a window's navy), and a mark that drops to near black reads as a hole.
func _snap_floor(c: Color, fl: float, char: bool) -> Color:
	var q := _snap(c, char)
	if q.get_luminance() >= fl - 0.005:
		return q
	var best := q
	var bd := 1e20
	for p in _pal:
		if p.get_luminance() < fl - 0.005:
			continue
		var dr := (p.r - c.r) * 0.30
		var dg := (p.g - c.g) * 0.59
		var db := (p.b - c.b) * 0.11
		var d := dr * dr + dg * dg + db * db
		if d < bd:
			bd = d
			best = p
	return best


static func _bay(x: int, y: int) -> float:
	return (float(HullWear.BAYER[y & 3][x & 3]) + 0.5) / 16.0


static func _h01(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h >> 8) & 0xffff) / 65535.0


func _ok(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return false
	var i := y * _w + x
	return _mask[i] == 1 and _edge[i] == 0


## The plating at `i` lit `f` times as bright (held steps, dithered between
## them), from what is there now so marks stack, and snapped. Never darker than
## 40% of the art (a much-hit patch is dark metal, not another hole), never
## near black where the art was not.
const STEPS: Array[float] = [0.4, 0.5, 0.62, 0.75, 0.88, 1.0, 1.15, 1.3, 1.45]


func _tone(i: int, f: float) -> void:
	if _mask[i] == 0 or _edge[i] == 1:
		return
	var x := i % _w
	var y := i / _w
	var fc := clampf(f, STEPS[0], STEPS[STEPS.size() - 1])
	var fq := fc
	for j in STEPS.size() - 1:
		if fc >= STEPS[j] and fc <= STEPS[j + 1]:
			var u := (fc - STEPS[j]) / (STEPS[j + 1] - STEPS[j])
			fq = STEPS[j + 1] if u > _bay(x + _r.position.x, y + _r.position.y) else STEPS[j]
			break
	if absf(fq - 1.0) < 0.01:
		return
	var c := _col[i]
	# darkening chars: warmer as it goes
	var q := Color(c.r * fq, c.g * fq, c.b * fq) if fq > 1.0 		else Color(c.r * fq, c.g * fq * 0.95, c.b * fq * 0.85)
	var o := _orig[i]
	var floor_l := maxf(o.get_luminance() * 0.4, minf(0.1, o.get_luminance() * 0.75))
	if q.get_luminance() < floor_l:
		var k := floor_l / maxf(0.001, q.get_luminance())
		q = Color(q.r * k, q.g * k, q.b * k)
	_mark_px(i, _snap_floor(q, floor_l, fq < 1.0))


## Metal burnt by heat: one of the heat ramp's own colours (`which` 4 or 5),
## and only where it is darker than the plating's own light would make it read
## as glowing -- on a dark hull it shows as a brown ring, on a light one a rust one.
func _burnt(i: int, which: int) -> void:
	if _mask[i] == 0 or _edge[i] == 1:
		return
	var c: Color = ShipBreakup.HEAT_RAMP[which]
	_mark_px(i, c)


## Lit metal: the plating at `i` brighter by `f`, and at least a clear step
## brighter than it was, so a highlight shows on a dark hull too; snapped.
func _shine(i: int, f: float) -> void:
	if _mask[i] == 0 or _edge[i] == 1:
		return
	var c := _col[i]
	var l := c.get_luminance()
	var q := Color(minf(1.0, c.r * f), minf(1.0, c.g * f), minf(1.0, c.b * f))
	var want := minf(0.95, l + 0.2)
	if q.get_luminance() < want:
		q = q.lerp(Color(want, want, want), 0.5)
		var k := want / maxf(0.001, q.get_luminance())
		q = Color(minf(1.0, q.r * k), minf(1.0, q.g * k), minf(1.0, q.b * k))
	_mark_px(i, _snap(q))


func _mark_px(i: int, c: Color) -> void:
	if _plate and _what[i] == 2:
		return
	_put_px(i, Color(c.r, c.g, c.b, _orig[i].a))
	if _what[i] == 0:
		_what[i] = 1


## Paint scraped back to the metal: a neutral grey a little lighter than the
## plating, or darker than a white one (white paint over grey metal), snapped.
func _bare(i: int, sheen: bool) -> void:
	if _mask[i] == 0 or _edge[i] == 1:
		return
	var l := _lum[i]
	var g := 0.6 if l > 0.66 else clampf(l * 1.6 + 0.16, 0.42, 0.9)
	if sheen:
		g = minf(0.95, g + 0.18)
	_mark_px(i, _snap(Color(g, g, g * 1.02)))


# ----------------------------------------------------------------- a hit

## Where a hit lands: the best of sixteen fair candidates on the hull, leaning
## to the side the shots come from and to plating light enough for a mark to
## show (the 3x3 round it, so a dark seam is not mistaken for dark plating),
## and clear of the marks already there. `edge` on the outline (a split vents
## into open space above or below), `near` as close as it gets to a screen
## point, `around` a mark's width or so from a hit (an extra).
func _pick(edge: bool, rad: float, near: Vector2 = Vector2.INF, around: Vector2 = Vector2.INF) -> Vector2i:
	var best := -1e9
	var bp := Vector2i(int(float(_H.get("cx", 0.0))), int(float(_H.get("cy", 0.0))))
	var bw := maxf(1.0, float(int(_H.get("x1", 1)) - int(_H.get("x0", 0)) + 1))
	var cx: float = _H.get("cx", 0.0)
	var found := 0
	for tries in 500:
		if found >= 16:
			break
		var x := _rng.randi_range(2, maxi(2, _w - 3))
		var y := _rng.randi_range(2, maxi(2, _h - 3))
		var i := y * _w + x
		if _mask[i] == 0:
			continue
		if edge:
			if _edge[i] == 0:
				continue
			if absf(ShipBreakup._normal_at(_H, _mask, Vector2i(x, y)).y) < 0.5:
				continue
		elif not (_ok(x - 2, y) and _ok(x + 2, y) and _ok(x, y - 2) and _ok(x, y + 2)):
			continue
		found += 1
		var lv := 0.0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				lv += _lum[i + dy * _w + dx]
		lv /= 9.0
		var score: float
		if around != Vector2.INF:
			var want := 13.0 * _K()
			score = -absf(Vector2(x, y).distance_to(around) - want) / want + 0.8 * lv + _rng.randf() * 0.5
		elif near != Vector2.INF:
			score = -_screen(Vector2i(x, y)).distance_to(near) * 0.05 + 0.4 * lv + _rng.randf() * 0.4
		else:
			score = 0.35 * float(facing) * (float(x) - cx) / bw + 1.2 * lv + _rng.randf() * 0.6
		if style == 4 and _what[i] == 2:
			score -= 3.0
		for m in _marks:
			var dd := Vector2(x, y).distance_to(m.p)
			var lim := float(m.r) * 0.85 + rad * _K() * 0.5
			if dd < lim:
				score -= 0.6 + 2.0 * (1.0 - dd / lim)
		if score > best:
			best = score
			bp = Vector2i(x, y)
	return bp


func hit(amount: int, hp_after: int, max_hp: int, kind: int = -1, near: Vector2 = Vector2.INF) -> int:
	if int(_H.n) == 0:
		return 0
	var frac := float(amount) / float(maxi(1, max_hp))
	var big := frac >= 0.15
	_hp = float(hp_after) / float(maxi(1, max_hp))
	_sc = SIZE * mark_scale
	if kind < 0:
		kind = _roll_x(frac)
	var edge := (kind == 4 and style == 1) or (kind == 7 and style == 4)
	var p := _pick(edge, 6.0, near)
	_one(kind, p, frac, big)
	rolled.append(_name(kind))
	moment.emit(&"impact", 0.35 + 0.55 * minf(1.0, frac / 0.3), 0.0)
	# more marks a hit as the hull goes, smaller, round the hit (today's rule)
	var extras := 0 if _hp > 0.75 else (1 if _hp > 0.5 else (2 if _hp > 0.25 else 3))
	_quiet = true
	_sc = SIZE * 0.7 * mark_scale
	for e in extras:
		var k2 := _roll_extra()
		_one(k2, _pick(false, 4.0, Vector2.INF, Vector2(p)), 0.03, false)
	_sc = SIZE * mark_scale
	_quiet = false
	# the hit itself, as light on the plating, and sparks back the way it came
	var sp := _screen(p)
	_bloom(p, (7.0 if big else 5.0) * mark_scale, 0.07, 0.95)
	_sparks(sp, 16 if big else 8, 150.0 if big else 110.0, Vector2(float(facing) * 0.9, 0.0))
	if (style == 2 or style == 4) and _hp <= 0.6:
		_stress(p)
	_gdirty = true
	return kind


func _name(k: int) -> String:
	match style:
		1:
			return NAMES_A[k]
		2:
			return NAMES_B[k]
		4:
			return NAMES_D[k]
	return NAMES_C[k]


func _roll_x(frac: float) -> int:
	var small := frac < 0.12
	var w: Array
	match style:
		1:
			w = [0.25, 0.35, 0.25, 0.15, 0.0] if small else [0.45, 0.2, 0.2, 0.15, 0.0]
			if _hp <= VENT_FROM and _vents2.size() < MAX_VENTS:
				w[4] = 0.3
		2:
			w = [0.5, 0.3, 0.2] if small else [0.3, 0.3, 0.4]
		4:
			# small hits lean to A's dents and scrapes and C's knocked
			# panels; big ones to B's blooms and C's peels
			w = [0.28, 0.24, 0.1, 0.1, 0.1, 0.0, 0.18, 0.0] if small 				else [0.1, 0.05, 0.05, 0.05, 0.35, 0.3, 0.1, 0.0]
			if _hp <= VENT_FROM and _count_vents(false) < D_SPLITS:
				w[7] = 0.15
		_:
			w = [0.25, 0.45, 0.3] if small else [0.55, 0.35, 0.1]
	var tot := 0.0
	for x in w:
		tot += float(x)
	var r := _rng.randf() * tot
	for k in w.size():
		r -= float(w[k])
		if r < 0.0:
			return k
	return 0


func _roll_extra() -> int:
	var r := _rng.randf()
	match style:
		1:
			return 1 if r < 0.45 else (0 if r < 0.75 else 2)
		2:
			return 0 if r < 0.6 else 1
		4:
			return 0 if r < 0.3 else (1 if r < 0.55 else (3 if r < 0.8 else 6))
	return 2 if r < 0.4 else (1 if r < 0.75 else 0)


func _count_vents(breach: bool) -> int:
	var n := 0
	for v in _vents2:
		if bool(v.sparks) == breach:
			n += 1
	return n


func _one(kind: int, p: Vector2i, frac: float, big: bool) -> void:
	_marks.append({p = Vector2(p), r = 8.0 * _sc / SIZE})
	match style:
		1:
			match kind:
				0: _dent(p, big)
				1: _soot(p, big)
				2: _scrape(p, big)
				3: _rivets(p, big)
				4: _split(p, big)
		2:
			_heat(p, frac, big, kind)
		3:
			match kind:
				0: _peel(p, big)
				1: _knock(p, big)
				2: _soot(p, big)
		4:
			_mixed(kind, p, frac, big)


## D: one of A's, B's or C's marks, and under every one of them B's bloom,
## cooling to a scorch (smaller on a small hit): the one mark that reads on a
## dark hull. A peel brings its own scorch; a bloom is B's whole hit.
func _mixed(kind: int, p: Vector2i, frac: float, big: bool) -> void:
	if kind == 4:
		_heat(p, frac, big, _rng.randi_range(0, 2))
		return
	var rr := clampf(2.2 + 10.0 * frac, 2.4, 4.2) * _K()
	_bloom(p, rr, 1.2 if big else 0.9, 0.95)
	if kind != 5:
		_blotch(p, rr * 0.7, rr * 0.55)
	_plate = kind != 5 and kind != 3
	match kind:
		0: _dent(p, big)
		1: _scrape(p, big)
		2: _rivets(p, big)
		3: _soot(p, big)
		5: _peel(p, big)
		6: _knock(p, big)
		7: _split(p, big)
	_plate = false


# ------------------------------------------------------- A: battle-worn plating

## Sizes are full-sheet pixels times this: 1 on a full sheet, half on a half
## one, 0.7 of that for an extra.
func _K() -> float:
	return _sc / SIZE * 2.0


## Distance from `p` in an ellipse `rx` by `ry`, its edge broken by `fd`.
func _ed(x: int, y: int, p: Vector2i, rx: float, ry: float, fd: Dictionary, amp: float) -> float:
	var dx := float(x - p.x) / rx
	var dy := float(y - p.y) / ry
	return sqrt(dx * dx + dy * dy) + amp * ShipBreakup._nz(fd, x, y)


## A dent: the plating's own shading bent. Lit from above, so the top wall of
## the dish is in shadow and the bottom wall catches the light; the metal it
## pushed aside stands up round the top as a lit lip and falls away under the
## bottom into shadow. A bright scuff where it struck.
func _dent(p: Vector2i, big: bool) -> void:
	var rx := (4.2 if big else 3.4) * _K()
	var ry := rx * 0.55
	var fd := ShipBreakup._field(_rng, _w, _h, 3)
	for y in range(p.y - int(ry) - 3, p.y + int(ry) + 4):
		for x in range(p.x - int(rx) - 3, p.x + int(rx) + 4):
			if not _ok(x, y):
				continue
			var i := y * _w + x
			var dy := float(y - p.y) / ry
			var d := _ed(x, y, p, rx, ry, fd, 0.1)
			if d < 1.0:
				if dy < -0.55 and d > 0.75:
					# the crease under the lip
					_tone(i, 0.42)
				elif dy < -0.2:
					_tone(i, 0.45 + 0.3 * (dy + 1.0))
				elif dy > 0.25 and d > 0.4:
					_shine(i, 1.0 + 0.5 * dy)
			elif d < 1.28 and dy < 0.0:
				if d < 1.16 or _bay(x, y) < 0.5:
					_shine(i, 1.5)
			elif d < 1.2 and dy > 0.35:
				_tone(i, 0.55)
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1)]:
		var q: Vector2i = p + o
		if _ok(q.x, q.y) and (big or o == Vector2i.ZERO):
			_bare(q.y * _w + q.x, o == Vector2i.ZERO)
	if not _quiet:
		moment.emit(&"punch", 0.6 if big else 0.45, 0.0)


## A scorch from a blast: the blotch (`_blotch`), streaks thrown out from it
## (longest along the hull), bright flecks where the paint blew off, and a
## short ember where it struck.
func _soot(p: Vector2i, big: bool) -> void:
	var rx := (3.8 if big else 3.0) * _K()
	var ry := rx * 0.66
	_blotch(p, rx, ry)
	for j in _rng.randi_range(5, 8):
		var a := (0.0 if _rng.randf() < 0.5 else PI) + _rng.randf_range(-0.8, 0.8)
		if _rng.randf() < 0.25:
			a = _rng.randf() * TAU
		var dir := Vector2(cos(a) * rx, sin(a) * ry).normalized()
		var ln := rx * _rng.randf_range(1.2, 2.0)
		var s := rx * 0.6
		while s < ln:
			var q := Vector2i((Vector2(p) + dir * s).round())
			if _ok(q.x, q.y):
				var f := (s - rx * 0.6) / maxf(1.0, ln - rx * 0.6)
				if f < 0.6 or (1.0 - f) * 2.5 > _bay(q.x, q.y):
					_tone(q.y * _w + q.x, lerpf(0.58, 0.85, f))
			s += 1.0
	for j in _rng.randi_range(3, 5):
		var q2 := p + Vector2i(_rng.randi_range(-int(rx), int(rx)), _rng.randi_range(-int(ry), int(ry)))
		if _ok(q2.x, q2.y):
			_bare(q2.y * _w + q2.x, true)
	_ember(p, big)
	if not _quiet:
		moment.emit(&"sizzle", 0.3 if big else 0.2, 0.45)


## A scorch: a blotch of soot in four held steps, its edge broken by noise and
## each step dithered into the next, its middle burnt brown-black (the heat
## ramp's darkest, mottled with the charred plating). Darkened plating that
## keeps its texture; never one flat near-black that could be an opening.
func _blotch(p: Vector2i, rx: float, ry: float) -> void:
	var fd := ShipBreakup._field(_rng, _w, _h, 3)
	# four held steps, each edge an ordered dither from one to the next
	const LV: Array[float] = [0.4, 0.5, 0.74, 1.0]
	const AT: Array[float] = [0.45, 0.7, 0.88, 1.02]
	for y in range(p.y - int(ry * 1.25) - 1, p.y + int(ry * 1.25) + 2):
		for x in range(p.x - int(rx * 1.25) - 1, p.x + int(rx * 1.25) + 2):
			if not _ok(x, y):
				continue
			var d := _ed(x, y, p, rx, ry, fd, 0.22)
			if d >= AT[3]:
				continue
			var f := LV[0]
			for j in range(1, 4):
				if d >= AT[j - 1]:
					var u := (d - AT[j - 1]) / (AT[j] - AT[j - 1])
					f = LV[j] if u > _bay(x, y) else LV[j - 1]
			if f < 1.0:
				# the middle burnt brown-black, mottled with the charred plating
				if d < AT[0] * 0.8 and _bay(x + 1, y) < 0.6:
					_burnt(y * _w + x, 5)
				else:
					_tone(y * _w + x, f)


## Paint scraped back to the metal: a gouge skidding on away from the shot,
## bare metal along its top, a dark trough under it, flecks of paint lifted
## either side, a curl of metal where it stopped.
func _scrape(p: Vector2i, big: bool) -> void:
	var k := _K()
	var dir := Vector2(-float(facing), _rng.randf_range(-0.3, 0.3)).normalized()
	var ln := _rng.randf_range(8.0, 12.0) * k * (1.25 if big else 1.0)
	var start := Vector2(p) - dir * ln * 0.15
	var s := 0.0
	var last := Vector2i(-1, -1)
	while s < ln:
		var q := Vector2i((start + dir * s).round())
		s += 1.0
		if not _ok(q.x, q.y):
			continue
		last = q
		var i := q.y * _w + q.x
		var f := s / ln
		_bare(i, int(s) % 4 == 0)
		if _ok(q.x, q.y + 1) and _rng.randf() < 0.8:
			_tone(i + _w, 0.5)
		if big and f > 0.2 and f < 0.7 and _ok(q.x, q.y - 1) and _bay(q.x, q.y) < 0.7:
			_bare(i - _w, false)
		if _rng.randf() < 0.12:
			var fl := q + Vector2i(0, -2 if _rng.randf() < 0.5 else 2)
			if _ok(fl.x, fl.y):
				_bare(fl.y * _w + fl.x, false)
	if _ok(p.x, p.y):
		_tone(p.y * _w + p.x, 0.5)
	if last.x >= 0 and _ok(last.x, last.y - 1):
		_bare((last.y - 1) * _w + last.x, true)
	if not _quiet:
		moment.emit(&"crack", 0.3, 0.15)


## The nearest panel line within `reach`, or (-1, -1).
func _near_seam(p: Vector2i, reach: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for y in range(maxi(0, p.y - reach), mini(_h, p.y + reach + 1)):
		for x in range(maxi(0, p.x - reach), mini(_w, p.x + reach + 1)):
			if _seam[y * _w + x] == 1:
				var d := (Vector2i(x, y) - p).length_squared()
				if d < bd:
					bd = d
					best = Vector2i(x, y)
	return best


## Follow a panel line from `q` both ways, up to `n` pixels each way. Returns
## the pixels and whether the line runs across (true) or down.
func _seam_run(q: Vector2i, n: int) -> Array:
	var across := (q.x > 0 and _seam[q.y * _w + q.x - 1] == 1) or (q.x < _w - 1 and _seam[q.y * _w + q.x + 1] == 1)
	var out: Array[Vector2i] = [q]
	for sgn in [-1, 1]:
		var cur := q
		for k in n:
			var nxt := Vector2i(-1, -1)
			var cands: Array = [Vector2i(sgn, 0), Vector2i(sgn, -1), Vector2i(sgn, 1)] if across \
				else [Vector2i(0, sgn), Vector2i(-1, sgn), Vector2i(1, sgn)]
			for o in cands:
				var c: Vector2i = cur + (o as Vector2i)
				if c.x >= 0 and c.y >= 0 and c.x < _w and c.y < _h and _seam[c.y * _w + c.x] == 1 and not out.has(c):
					nxt = c
					break
			if nxt.x < 0:
				break
			out.append(nxt)
			cur = nxt
	return [out, across]


## A panel's edge lifted along its line: the line opens a shade darker, the
## raised edge beside it catches the light and the plate beyond it is in its
## shadow.
func _lift(run: Array, across: bool) -> void:
	for q in run:
		var v: Vector2i = q
		_tone(v.y * _w + v.x, 0.55)
		var lit := v + (Vector2i(0, -1) if across else Vector2i(-1, 0))
		if _ok(lit.x, lit.y) and _seam[lit.y * _w + lit.x] == 0:
			_shine(lit.y * _w + lit.x, 1.45)
		var shade := v + (Vector2i(0, 1) if across else Vector2i(1, 0))
		if _ok(shade.x, shade.y) and _seam[shade.y * _w + shade.x] == 0:
			_tone(shade.y * _w + shade.x, 0.75)


## Popped rivets: a panel line near the hit lifts, and the rivets along the
## lifted edge are torn out (a dark pit, a bright torn rim).
func _rivets(p: Vector2i, big: bool) -> void:
	var q := _near_seam(p, int(5.0 * _K()) + 1)
	if q.x < 0:
		_scrape(p, big)
		return
	var got := _seam_run(q, int((4.5 if big else 3.5) * _K()))
	var run: Array = got[0]
	var across: bool = got[1]
	_lift(run, across)
	var off := Vector2i(0, -2) if across else Vector2i(-2, 0)
	for j in run.size():
		if j % 3 != 1:
			continue
		var rv: Vector2i = run[j] + off
		if _ok(rv.x, rv.y) and _ok(rv.x + 1, rv.y + 1):
			_tone(rv.y * _w + rv.x, 0.45)
			_shine((rv.y + 1) * _w + rv.x + 1, 1.5)
	_dent(p, false)
	if not _quiet:
		moment.emit(&"crack", 0.35, 0.12)


## A plate's edge split at the hull's rim (from 60% hull): a short line opened
## a shade, its lip lit, soot round it; from then on it sputters vapour.
func _split(p: Vector2i, big: bool) -> void:
	var n := ShipBreakup._normal_at(_H, _mask, p)
	var inward := Vector2i((Vector2(p) - n * 2.0).round())
	var tang := Vector2(-n.y, n.x)
	var ln := int((2.5 if big else 2.0) * _K())
	var px := PackedInt32Array()
	_soot(inward, false)
	for s in range(-ln, ln + 1):
		var q := Vector2i((Vector2(inward) + tang * float(s)).round())
		if not _ok(q.x, q.y):
			continue
		_tone(q.y * _w + q.x, 0.45)
		px.append(q.y * _w + q.x)
		var lip := Vector2i((Vector2(q) + n).round())
		if _ok(lip.x, lip.y):
			_shine(lip.y * _w + lip.x, 1.45)
	_vents2.append({p = _screen(inward), n = n, px = px, next = t + _fx.randf_range(0.2, 0.6), until = t + (0.45 if big else 0.35),
		sparks = false})
	moment.emit(&"hiss", 0.5 if big else 0.35, 0.4)


## A short ember where it struck, flickering out in half a second.
func _ember(p: Vector2i, big: bool) -> void:
	_bloom(p, (3.0 if big else 2.2) * _K(), 0.22, 0.8)


# --------------------------------------------------------- B: heat and stress

## A heat bloom that cools white, orange, dull red, dark, over about four
## seconds, on the scorch it leaves (soot, metal tempered brown through it).
## `SPLASH` throws molten drops that land round it and cool faster; `STRESS`
## runs a crack from it that glows as it cools.
func _heat(p: Vector2i, frac: float, big: bool, kind: int) -> void:
	var k := _K()
	var rr := clampf(3.0 + 14.0 * frac, 3.2, 5.5) * k
	_bloom(p, rr, 1.45 if big else 1.25, 1.0)
	_blotch(p, rr * 0.85, rr * 0.65)
	if kind == 1:
		for j in _rng.randi_range(5, 8):
			var a := _rng.randf() * TAU
			var q := Vector2i((Vector2(p) + Vector2(cos(a), sin(a) * 0.6) * _rng.randf_range(rr * 1.0, rr * 2.4)).round())
			if not _ok(q.x, q.y):
				continue
			_blooms.append({p = q, r = 1.4 * k, t0 = t + _rng.randf_range(0.04, 0.14), tau = 0.6, peak = 0.82,
				s = _rng.randi() & 0xffff})
			_burnt(q.y * _w + q.x, 5)
	elif kind == 2:
		var cx := p.x
		var cy := p.y
		var bias := 1 if _rng.randf() < 0.5 else -1
		for s in int(_rng.randf_range(7.0, 12.0) * k):
			cx += bias
			if _rng.randf() < 0.35:
				cy += 1 if _rng.randf() < 0.5 else -1
			if not _ok(cx, cy):
				break
			var i2 := cy * _w + cx
			_tone(i2, 0.45)
			if _ok(cx, cy + 1) and s % 2 == 0:
				_tone(i2 + _w, 1.3)
			_blooms.append({p = Vector2i(cx, cy), r = 1.0, t0 = t + 0.02 * s, tau = 1.0, peak = 0.9, s = _rng.randi() & 0xffff})
	if not _quiet:
		moment.emit(&"sizzle", 0.4 if big else 0.28, 1.2)


## Under 60% hull the panel lines near a hit start to glow: from the nearest
## line, along it, more of it the lower the hull, the nearest hottest. A line
## that has glowed stays a shade darker (it carries into the wreck).
func _stress(p: Vector2i) -> void:
	var q := _near_seam(p, int(14.0 * maxf(0.5, mark_scale)))
	if q.x < 0:
		return
	var budget := int((30.0 + 90.0 * clampf((0.6 - _hp) / 0.6, 0.0, 1.0)) * mark_scale * (0.6 if style == 4 else 1.0))
	var seen := {q: 0}
	var queue: Array[Vector2i] = [q]
	var head := 0
	var got := 0
	while head < queue.size() and got < budget:
		var cur := queue[head]
		head += 1
		var i := cur.y * _w + cur.x
		var depth: int = seen[cur]
		var heat := lerpf(0.8, 0.38, clampf(float(depth) / float(maxi(1, budget)), 0.0, 1.0))
		if not _lit.has(i):
			_lit_px.append(i)
			got += 1
			_tone(i, 0.8)
		_lit[i] = maxf(float(_lit.get(i, 0.0)), heat)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nb := cur + Vector2i(dx, dy)
				if nb.x < 0 or nb.y < 0 or nb.x >= _w or nb.y >= _h or seen.has(nb):
					continue
				if _seam[nb.y * _w + nb.x] == 1:
					seen[nb] = depth + 1
					queue.append(nb)
	# lower still, every glowing line runs hotter
	if _hp <= 0.3:
		for j in _lit:
			_lit[j] = minf(0.8, float(_lit[j]) + 0.05)


# ------------------------------------------------ C: plates crack and peel

## A plate torn and curled back over its hinge (on the side away from the
## shot), the structure under it showing: a frame under every panel line and
## every fourth column lit, stringers across, the bays between them in shadow,
## the top wall shaded by the plate's thickness and the bottom wall lit. Never
## empty: every pixel of it is the ship's own metal.
func _peel(p: Vector2i, big: bool) -> void:
	var k := _K()
	var rp := (3.0 if big else 2.4) * k
	var fd := ShipBreakup._field(_rng, _w, _h, 3)
	if not _ok(p.x, p.y):
		_plate_crack(p, big)
		return
	_blotch(p, rp * 1.35, rp * 0.85)
	var region := {p: true}
	var queue: Array[Vector2i] = [p]
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + o
			if region.has(nb) or not _ok(nb.x, nb.y):
				continue
			if _ed(nb.x, nb.y, p, rp * 1.4, rp * 0.85, fd, 0.3) > 1.0:
				continue
			region[nb] = true
			queue.append(nb)
	if region.size() < 6:
		_plate_crack(p, big)
		return
	var y0 := _h
	for q in region:
		y0 = mini(y0, (q as Vector2i).y)
	var phase := _rng.randi_range(0, 3)
	var px := PackedInt32Array()
	for q in region:
		var v: Vector2i = q
		var i := v.y * _w + v.x
		var f := 0.38
		if (v.x + phase) % 4 == 0 or _seam[i] == 1:
			f = 0.9
		elif (v.y - y0) % 4 == 2:
			f = 0.7
		if not region.has(v + Vector2i(0, -1)):
			f = 0.32
		elif not region.has(v + Vector2i(0, -2)):
			f = minf(f, 0.45)
		elif not region.has(v + Vector2i(0, 1)):
			f = 1.1
		_inner(i, f)
		px.append(i)
	# the plate curled back over its hinge: a lit roll two pixels thick, then
	# its shadow on the plating beyond
	var dirx := -facing
	var rows := {}
	for q in region:
		var v2: Vector2i = q
		if not rows.has(v2.y) or (v2.x * dirx > int(rows[v2.y]) * dirx):
			rows[v2.y] = v2.x
	for y in rows:
		var xe: int = rows[y]
		for s in [1, 2, 3, 4]:
			var a := Vector2i(xe + s * dirx, y)
			if not _ok(a.x, a.y) or region.has(a):
				break
			var ia := a.y * _w + a.x
			match s:
				1:
					_bare(ia, true)
				2:
					_bare(ia, false)
				3:
					_tone(ia, 0.5)
				4:
					if _bay(a.x, a.y) < 0.5:
						_tone(ia, 0.72)
	# the torn edge elsewhere: the plate's thickness lit along the top and the
	# shot's side, a shadow along the bottom; burnt metal round it
	var hs := _rng.randi() & 0xffff
	for q in region:
		for o in [Vector2i(-dirx, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var e: Vector2i = (q as Vector2i) + o
			if region.has(e) or not _ok(e.x, e.y):
				continue
			var ie := e.y * _w + e.x
			if o.y > 0:
				_tone(ie, 0.6)
			elif o.y < 0 or (e.y % 2 == 0):
				_shine(ie, 1.4)
			var e2: Vector2i = e + o
			if _ok(e2.x, e2.y) and not region.has(e2) and _h01(e2.y * _w + e2.x + hs, 9) < 0.35:
				_burnt(e2.y * _w + e2.x, 5)
	# and the panel lines round it cracked open
	var q2 := _near_seam(p, int(rp) + 4)
	if q2.x >= 0:
		var got := _seam_run(q2, int(6.0 * k))
		_lift(got[0], got[1])
	# flakes of the plate flung off
	for j in _rng.randi_range(4, 6):
		var src: int = px[_rng.randi_range(0, px.size() - 1)]
		var at := _screen(Vector2i(src % _w, src / _w))
		var dv := Vector2(float(dirx) * _rng.randf_range(0.5, 1.0), _rng.randf_range(-0.8, 0.8)).normalized()
		_pm.append({p = at, v = dv * _rng.randf_range(40.0, 90.0), age = 0.0, life = _rng.randf_range(0.3, 0.55),
			k = 2, c = _orig[src], drag = 3.0})
	var nrm := Vector2(0.0, -1.0 if float(p.y) < float(_H.cy) else 1.0)
	_vents2.append({p = _screen(p), n = nrm, px = px, next = t + _fx.randf_range(0.4, 1.2), until = -1.0, sparks = true})
	if not _quiet:
		moment.emit(&"punch", 0.75 if big else 0.55, 0.0)


## Structure under a plate: the art's own colour at `f`, kept off black
## (never darker than a third of the art, nor than 10% light), snapped.
func _inner(i: int, f: float) -> void:
	var o := _orig[i]
	var q := Color(minf(1.0, o.r * f), minf(1.0, o.g * f), minf(1.0, o.b * f))
	var fl := maxf(0.1, o.get_luminance() * 0.33)
	if q.get_luminance() < fl:
		var kk := fl / maxf(0.001, q.get_luminance())
		q = Color(q.r * kk, q.g * kk, q.b * kk)
	_put_px(i, _snap_floor(q, fl, false))
	_what[i] = 2


## A plate knocked out of true: the panel it struck (bounded by the hull's own
## panel lines) sags a pixel down or is driven a pixel back from the shot. The
## strip it uncovers is the frame under it, in shadow; its leading edge rides
## over the seam beyond and throws a shadow of its own; its trailing edge is lit.
## A short crack from where it struck. Where no panel line bounds the plate
## near the hit, it cracks instead (`_plate_crack`).
func _knock(p: Vector2i, big: bool) -> void:
	var k := _K()
	var lim := Vector2i(int(8.0 * k), int(5.0 * k))
	if not _ok(p.x, p.y) or _seam[p.y * _w + p.x] == 1 or _what[p.y * _w + p.x] == 2:
		_plate_crack(p, big)
		return
	var region := {p: true}
	var queue: Array[Vector2i] = [p]
	var head := 0
	var open := false
	while head < queue.size() and not open:
		var cur := queue[head]
		head += 1
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + o
			if region.has(nb) or not _ok(nb.x, nb.y) or _seam[nb.y * _w + nb.x] == 1 					or _what[nb.y * _w + nb.x] == 2:
				continue
			if absi(nb.x - p.x) > lim.x or absi(nb.y - p.y) > lim.y:
				open = true
				break
			region[nb] = true
			queue.append(nb)
	if open or region.size() < 8:
		_plate_crack(p, big)
		return
	var d := Vector2i(0, 1) if _rng.randf() < 0.55 else Vector2i(-facing, 0)
	var src := {}
	for q in region:
		src[q] = _col[(q as Vector2i).y * _w + (q as Vector2i).x]
	for q in region:
		var v: Vector2i = q
		var i := v.y * _w + v.x
		var from: Vector2i = v - d
		if region.has(from):
			_put_px(i, src[from])
			if _what[i] == 0:
				_what[i] = 1
			# the trailing edge, catching the light
			if not region.has(from - d):
				_shine(i, 1.35)
		else:
			_inner(i, 0.36)
	for q in region:
		var to: Vector2i = (q as Vector2i) + d
		if region.has(to) or not _ok(to.x, to.y):
			continue
		var c: Color = src[q]
		_put_px(to.y * _w + to.x, _snap_floor(Color(c.r * 0.75, c.g * 0.75, c.b * 0.75), 0.1, false))
		var sh := to + d
		if _ok(sh.x, sh.y) and not region.has(sh):
			_tone(sh.y * _w + sh.x, 0.55)
	# where it struck: a short crack and a scuff
	var cx := p.x
	var cy := p.y
	var bias := 1 if _rng.randf() < 0.5 else -1
	for s in int(_rng.randf_range(3.0, 5.0) * k):
		cx += bias
		if _rng.randf() < 0.4:
			cy += 1 if _rng.randf() < 0.5 else -1
		if not region.has(Vector2i(cx, cy)):
			break
		_tone(cy * _w + cx, 0.45)
	_bare(p.y * _w + p.x, true)
	if not _quiet:
		moment.emit(&"crack", 0.4 if big else 0.3, 0.15)


## A plate cracked: a line from the hit to the nearest panel line (dark, its
## lower lip lit), that line lifted either side, the plate dished where it was
## struck.
func _plate_crack(p: Vector2i, big: bool) -> void:
	var k := _K()
	_dent(p, false)
	var q := _near_seam(p, int(7.0 * k) + 1)
	if q.x >= 0:
		var steps := int(ceil((Vector2(q) - Vector2(p)).length()))
		var wob := 0.0
		for s in steps + 1:
			var f := float(s) / float(maxi(1, steps))
			wob += _rng.randf_range(-0.6, 0.6)
			var c := Vector2i((Vector2(p).lerp(Vector2(q), f) + Vector2(0, clampf(wob, -1.0, 1.0))).round())
			if _ok(c.x, c.y):
				_tone(c.y * _w + c.x, 0.45)
				if _ok(c.x, c.y + 1):
					_shine((c.y + 1) * _w + c.x, 1.35)
		var got := _seam_run(q, int((4.5 if big else 3.5) * k))
		_lift(got[0], got[1])
	else:
		var cx := p.x
		var cy := p.y
		var bias := 1 if _rng.randf() < 0.5 else -1
		for s in int(_rng.randf_range(7.0, 12.0) * k):
			cx += bias
			if _rng.randf() < 0.33:
				cy += 1 if _rng.randf() < 0.5 else -1
			if not _ok(cx, cy):
				break
			_tone(cy * _w + cx, 0.45)
			if _ok(cx, cy + 1):
				_tone((cy + 1) * _w + cx, 1.35)
	if not _quiet:
		moment.emit(&"crack", 0.4 if big else 0.3, 0.15)


# ---------------------------------------------------------------- light

func _bloom(p: Vector2i, r: float, tau: float, peak: float) -> void:
	_blooms.append({p = p, r = maxf(0.8, r), t0 = t, tau = tau, peak = peak, s = _rng.randi() & 0xffff})
	_gdirty = true


func _sparks(at: Vector2, count: int, speed: float, bias: Vector2 = Vector2.ZERO) -> void:
	for i in count:
		var a := _fx.randf() * TAU
		var v := (Vector2(cos(a), sin(a)) + bias).normalized() * _fx.randf_range(0.35, 1.0) * speed
		_pm.append({p = at, v = v, age = 0.0, life = _fx.randf_range(0.12, 0.32), k = 0, c = Color.WHITE, drag = 4.5})


func _puff(at: Vector2, n: Vector2, count: int) -> void:
	for i in count:
		var dv := n.rotated(_fx.randf_range(-0.45, 0.45))
		_pm.append({p = at, v = dv * _fx.randf_range(14.0, 34.0), age = 0.0, life = _fx.randf_range(0.45, 0.85),
			k = 1, c = Color.WHITE, drag = 1.4})


## Heat to colour: the ramp's step, and whether this pixel shows it (the
## cooler, the fewer, dithered).
static func _heat_col(T: float) -> Color:
	var R: Array = ShipBreakup.HEAT_RAMP
	if T >= 0.85:
		return R[0]
	if T >= 0.68:
		return R[1]
	if T >= 0.5:
		return R[2]
	if T >= 0.34:
		return R[3]
	if T >= 0.2:
		return R[4]
	return R[5]


static func _cover(T: float) -> float:
	if T >= 0.34:
		return 1.0
	if T >= 0.2:
		return 0.7
	if T >= 0.1:
		return 0.35
	return 0.0


func _heat_at(i: int, T: float) -> void:
	if T <= _temp[i]:
		return
	_temp[i] = T
	if _listed[i] == 0:
		_listed[i] = 1
		_tl.append(i)


## The light on the plating, GLOW_HZ times a second: every bloom and glowing
## line as heat, a pixel's heat jittered and the dither shifted each step, so a
## glow's edge changes shape twelve times a second and no faster. A step that
## happens to come out as the last one is jittered again, then flickered dimmer
## (a small ember can come out the same), so while anything glows, every step
## moves.
func _build_glow(step: int) -> void:
	var prev := _glow.get_data()
	for attempt in 4:
		# the last tries flicker it dimmer or brighter, which even a one-pixel
		# ember shows
		_glow_once(step * 4 + attempt, [1.0, 1.0, 0.62, 1.3][attempt])
		if _glow.is_invisible() or _glow.get_data() != prev:
			break
	_glow_tex.update(_glow)


func _glow_once(step: int, gain: float) -> void:
	for i in _tl:
		_temp[i] = 0.0
		_listed[i] = 0
	_tl.resize(0)
	var tq := t
	var keep: Array = []
	for b in _blooms:
		var age := tq - float(b.t0)
		if age < 0.0:
			keep.append(b)
			continue
		var lvl := float(b.peak) * (1.0 if age < 0.03 else exp(-(age - 0.03) / float(b.tau)))
		if lvl < 0.09:
			continue
		keep.append(b)
		var p: Vector2i = b.p
		var r: float = b.r
		var bs: int = b.s
		for y in range(p.y - int(ceil(r)), p.y + int(ceil(r)) + 1):
			for x in range(p.x - int(ceil(r)), p.x + int(ceil(r)) + 1):
				if x < 0 or y < 0 or x >= _w or y >= _h:
					continue
				var i := y * _w + x
				if _mask[i] == 0:
					continue
				var d := Vector2(x - p.x, y - p.y).length() / r
				d *= 0.92 + 0.16 * _h01(i + bs, step)
				if d >= 1.0:
					continue
				_heat_at(i, lvl * pow(1.0 - d, 1.3) * 1.15)
	_blooms = keep
	if (style == 2 or style == 4) and _hp <= 0.6:
		for i2 in _lit_px:
			var base: float = _lit[i2]
			var pulse := 0.82 + 0.18 * sin(tq * 3.1 + float(i2 % 97) * 0.37)
			_heat_at(i2, base * pulse * (0.8 + 0.4 * _h01(i2, step)))
	_glow.fill(Color(0, 0, 0, 0))
	var ox := int(_h01(step, 7) * 4.0)
	var oy := int(_h01(step, 13) * 4.0)
	for i3 in _tl:
		var T := _temp[i3] * gain
		var cov := _cover(T)
		if cov <= 0.0:
			continue
		var x3 := i3 % _w
		var y3 := i3 / _w
		if cov < 1.0 and cov <= _bay(x3 + ox, y3 + oy):
			continue
		_glow.set_pixel(x3, y3, _heat_col(T))


# ---------------------------------------------------------------- the clock

func _process(_delta: float) -> void:
	if not auto:
		return
	var now := GameClock.now()
	if _clock < 0.0:
		_clock = now
	var dt := clampf(now - _clock, 0.0, 0.25)
	_clock = now
	advance(dt)


func advance(delta: float) -> void:
	t += delta
	# B: a glowing line throws sparks now and then, faster the lower the hull
	if (style == 2 or style == 4) and _hp <= 0.6 and not _lit_px.is_empty() and t >= _next_spark:
		_next_spark = t + _fx.randf_range(0.15, 0.5) * (1.6 if _hp > 0.3 else 1.0) * (1.8 if style == 4 else 1.0)
		var i: int = _lit_px[_fx.randi_range(0, _lit_px.size() - 1)]
		var q := Vector2i(i % _w, i / _w)
		var up := -1.0 if float(q.y) < float(_H.cy) else 1.0
		_sparks(_screen(q), _fx.randi_range(2, 4), 70.0, Vector2(0.0, up * 0.8))
		_blooms.append({p = q, r = 1.5, t0 = t, tau = 0.08, peak = 0.9, s = _fx.randi() & 0xffff})
		moment.emit(&"spark", 0.12, 0.1)
	# A's split seams and C's breaches, while the hull is low: vapour in
	# sputters, and (C) sparks from what is torn open
	var splits := 0
	var breaches := 0
	for vi in range(_vents2.size() - 1, -1, -1):
		var v: Dictionary = _vents2[vi]
		var sp: Vector2 = v.p
		var nv: Vector2 = v.n
		# a split edge sputters from 60% hull, a breach from half
		var low := 0.5 if bool(v.sparks) else VENT_FROM
		# D: only the newest few go on sputtering
		if style == 4:
			if bool(v.sparks):
				breaches += 1
				if breaches > D_BREACHES:
					continue
			else:
				splits += 1
				if splits > D_SPLITS:
					continue
		if t < float(v.until):
			if _fx.randf() < 0.6:
				_puff(sp + nv, nv, 1)
		elif _hp <= low and t >= float(v.next):
			v.next = t + _fx.randf_range(0.6, 1.8) * (1.3 if _hp > 0.25 else 0.8)
			if bool(v.sparks) and _fx.randf() < 0.45:
				var arr: PackedInt32Array = v.px
				var j: int = arr[_fx.randi_range(0, arr.size() - 1)]
				var q2 := Vector2i(j % _w, j / _w)
				_sparks(_screen(q2), _fx.randi_range(3, 6), 80.0, nv * 0.7)
				_blooms.append({p = q2, r = 1.8, t0 = t, tau = 0.1, peak = 0.95, s = _fx.randi() & 0xffff})
				moment.emit(&"spark", 0.15, 0.1)
			else:
				v.until = t + _fx.randf_range(0.2, 0.4)
				moment.emit(&"sputter", 0.15, float(v.until) - t)
	var kept: Array = []
	for mo in _pm:
		mo.age += delta
		if mo.age >= mo.life:
			continue
		mo.p += mo.v * delta
		mo.v *= exp(-float(mo.drag) * delta)
		kept.append(mo)
	_pm = kept
	# (a hair over, so a step lands on the frame it is due whatever the
	# rounding of a sum of frame lengths)
	var step := int(floor(t * GLOW_HZ + 0.001))
	if step != _gstep or _gdirty:
		_gstep = step
		_gdirty = false
		_build_glow(step)
	if _dirty:
		_dmg_tex.update(_dmg)
		_dirty = false
	for c in get_children():
		(c as CanvasItem).queue_redraw()


func busy() -> bool:
	return false


func _in_oval(p: Vector2) -> bool:
	var d := (p - _ovc) / _ovr
	return d.length_squared() <= 1.0


func _paint_body(ci: CanvasItem) -> void:
	var at := _origin + Vector2(_r.position)
	if draw_marks:
		ci.draw_texture(_dmg_tex, at)
	ci.draw_texture(_glow_tex, at)
	for mo in _pm:
		var k: int = mo.k
		if k == 0:
			continue
		var p: Vector2 = (mo.p as Vector2).round()
		if not _in_oval(p):
			continue
		var f: float = mo.age / mo.life
		if k == 2:
			ci.draw_rect(Rect2(p, Vector2.ONE), mo.c)
			continue
		# vapour: grows as it thins, in the ship's own greys, dithered out
		var gi := 0 if f < 0.2 else (1 if f < 0.45 else (2 if f < 0.75 else 3))
		var col: Color = _vap[gi] if not _vap.is_empty() else Color(0.7, 0.7, 0.7)
		if f > 0.75 and ((int(p.x) + int(p.y)) & 1) == 1:
			continue
		ci.draw_rect(Rect2(p, Vector2.ONE), col)
		if f > 0.25 and f < 0.8:
			for o in [Vector2(1, 0), Vector2(0, -1)]:
				if _in_oval(p + o):
					ci.draw_rect(Rect2(p + o, Vector2.ONE), col)


func _paint_light(ci: CanvasItem) -> void:
	var R: Array = ShipBreakup.HEAT_RAMP
	for mo in _pm:
		if int(mo.k) != 0:
			continue
		var f2: float = mo.age / mo.life
		var p2: Vector2 = (mo.p as Vector2).round()
		if not _in_oval(p2):
			continue
		var c2: Color = R[0] if f2 < 0.4 else (R[2] if f2 < 0.75 else R[4])
		ci.draw_rect(Rect2(p2, Vector2.ONE), c2)
		var tail: Vector2 = ((mo.p as Vector2) - (mo.v as Vector2).normalized() * 2.0).round()
		if tail != p2 and _in_oval(tail):
			ci.draw_rect(Rect2(tail, Vector2.ONE), c2 * Color(0.5, 0.5, 0.5, 1))
