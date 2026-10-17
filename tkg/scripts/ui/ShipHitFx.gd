class_name ShipHitFx
extends Control

## HITS ON A SHIP, made of the death styles' pieces (Oct 13, mockups for a pick
## page; nothing here is in a fight yet).
##
## Jon loved the deaths and wants "these effects used during the fight, for
## damage and so on", then: "The bullet holes from chain are also GREAT", and
## then that he wants all of it, for variety, the way deaths roll. So a hit is
## one of four KINDS, rolled per hit from the fight's seeded generator:
##   SCORCH  a sharp flash and a spray of sparks; a scorch mark stays.
##   HOLE    E CHAIN's blast hole: a ragged bite punched in, scorched round,
##           its chips flying off, its lip glowing and cooling.
##   CRACK   cracks run from the hit along a network laid over the hull,
##           white-hot, cooling to dark lines, joining up as hits add up.
##   VENT    a puncture at the edge, air jetting out; from then on, while the
##           hull is low, the hole sputters now and then.
## Small hits lean to scorch, big ones to holes and cracks; venting only once
## the hull is at half or less (`roll`). Every mark stays and they build up
## together, each placed clear of the others on the side the shots come from,
## so a badly hurt ship is a mix and not a pile.
##
## AN OVERLAY, NEVER A REDRAW. The ship is drawn by its owner (EnemyArt,
## ShipView); this is handed its pixels only to know where the hull is and what
## a scorched pixel becomes. What stays is a picture of the changed pixels
## alone, transparent elsewhere, drawn over the ship and never moved: it cannot
## shimmer. Everything that moves is light or a mote, in whole pixels, stepped,
## and out within half a second, except a vent's sputters (a short puff
## seconds apart).
##
## THE MARKS OUTLIVE THE SHIP. `damaged(img)` is the ship's picture with every
## mark on it; hand that to ShipBreakup.setup and to wreck_image and the pieces
## and the wreck keep the damage (one blend; the owner keeps that image for the
## wreck instead of the clean one).
##
## `moment` names each visible event for sound, as ShipBreakup's does.

signal moment(kind: StringName, strength: float, length: float)

enum Kind { SCORCH, HOLE, CRACK, VENT }

const NAMES := {Kind.SCORCH: "SCORCH", Kind.HOLE: "HOLE", Kind.CRACK: "CRACK", Kind.VENT: "VENT"}
const BLURB := {
	Kind.SCORCH: "A sharp flash and a spray of sparks; a scorch mark stays.",
	Kind.HOLE: "Chain's blast hole: a ragged bite punched in, scorched round, chips flying, its lip glowing then cooling.",
	Kind.CRACK: "Cracks run from the hit, white-hot then cooling dark, and join up as hits add up.",
	Kind.VENT: "A puncture at the edge and a jet of air; while the hull is low the hole keeps sputtering."}
const SOUND := {
	Kind.SCORCH: "0.00 impact (by size); 0.00 sizzle, 0.45 long",
	Kind.HOLE: "0.00 impact; 0.00 punch (a crunching bite); 0.00 sizzle, 0.45 long",
	Kind.CRACK: "0.00 impact; 0.00 crack, 0.15-0.35 long (the crack running)",
	Kind.VENT: "0.00 impact; 0.00 hiss, 0.35-0.45 long; below half hull, sputter every 1-3 s per hole, 0.15-0.25 long"}

## WHICH LOOK A SHIP'S HULL TAKES ITS HITS IN (Oct 17, for Jon's pick): 0 today's
## (this file), 1 A battle-worn plating, 2 B heat and stress, 3 C plates
## cracking and peeling (`HullHitFx`). `HitLayers` reads it. `-- hull=A|B|C` on
## the command line plays one.
static var look := _look_arg()


static func _look_arg() -> int:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("hull="):
			return {"A": 1, "B": 2, "C": 3}.get((a as String).substr(5).to_upper(), 0)
	return 0

const SOOT := Color(0.17, 0.12, 0.10)
const HOLE_COL := Color(0.05, 0.045, 0.055)
const MAX_VENTS := 3
## Jon picked "More" (Oct 13): marks half as big again, and more of them per
## hit as the hull goes, so half hull already looks battered and a quarter
## looks wrecked. `extras` is how many smaller marks a hit adds round its own.
const SIZE := 1.5
## Hull at or under which a hit can vent (Jon: from 60%, not 50%).
const VENT_FROM := 0.6

var t := 0.0
## Off for a harness that steps `advance` by hand.
var auto := true
## Where the shots come from: -1 the left (an enemy is shot from your side), 1 the right (you).
var facing := -1

var _origin := Vector2.ZERO
var _H: Dictionary = {}
var _r := Rect2i()
var _w := 0
var _h := 0
var _mask := PackedByteArray()
var _orig := PackedColorArray()
var _col := PackedColorArray()
var _what := PackedByteArray()   ## 0 clean, 1 scorched, 2 hole, 3 crack
var _dmg: Image
var _dmg_tex: ImageTexture
var _dirty := false
var _rng := RandomNumberGenerator.new()
var _hp := 1.0
var _marks: Array = []          ## {p (local Vector2), r} -- spacing
var _flashes: Array = []
var _rings: Array = []
var _motes: Array = []
var _chips: Array = []
var _embers: Array = []
var _lips: Array = []           ## a hole's rim glowing and cooling: {px (PackedVector2Array screen), t0}
var _net := PackedByteArray()
var _net_px: Array[Vector2i] = []
var _crack_live: Array = []
var _vents: Array = []
var _sc := SIZE   ## the size of the mark being made (an extra is smaller)
## How big marks are on this picture: 1 on a full sheet, less on a half one, so
## a hole is the same size on the ship whichever sheet draws it.
var mark_scale := 1.0
## False when the owner bakes the marks into its own picture (EnemyArt does, so
## its dark blend and its wreck cut take them); this then draws only the light,
## the chips and the vents.
var draw_marks := true
## Goes up whenever a mark changes, so an owner that bakes them knows to redraw.
var version := 0
var _quiet := false   ## making an extra: its moments are the hit's
## Every hit's kind, in order, for a harness.
var rolled: Array = []


class Layer extends Control:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)


## `img` the ship's canvas, `used` its box in it, `origin` where the canvas's
## top-left sits in this control. `seed` from the fight (Rng.derive), so the same
## fight rolls the same hits.
func setup(img: Image, used: Rect2i, origin: Vector2, seed: int, the_facing: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	facing = the_facing
	_origin = origin.round()
	_rng.seed = seed * 977 + 5
	_sc = SIZE * mark_scale
	_H = ShipBreakup._hull_pic(img, used, 0)
	_r = _H.r
	_w = _H.w
	_h = _H.h
	if int(_H.n) > 0:
		_mask = _H.mask
		_orig = _H.raw
	else:
		_mask.resize(_w * _h)
		_orig.resize(_w * _h)
	_col = _orig.duplicate()
	_what.resize(_w * _h)
	_dmg = Image.create(maxi(1, _w), maxi(1, _h), false, Image.FORMAT_RGBA8)
	_dmg_tex = ImageTexture.create_from_image(_dmg)
	if int(_H.n) > 0:
		_build_network()
	var body := Layer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.paint = _paint_body
	add_child(body)
	var light := Layer.new()
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = mat
	light.paint = _paint_light
	add_child(light)


## The crack network: the borders of a rough Voronoi over the hull, one pixel
## wide. Cracks reveal it from where hits land, so they join up.
func _build_network() -> void:
	var n := clampi(int(_H.n) / 450, 5, 12)
	var seeds: Array[Vector2] = []
	var fields: Array = []
	for i in n:
		for tries in 60:
			var x := _rng.randi_range(0, _w - 1)
			var y := _rng.randi_range(0, _h - 1)
			if _mask[y * _w + x] == 1:
				seeds.append(Vector2(x, y))
				break
		fields.append(ShipBreakup._field(_rng, _w, _h, 5))
	var amp := 0.5 * sqrt(float(_H.n) / float(maxi(1, seeds.size())))
	var lab := PackedInt32Array()
	lab.resize(_w * _h)
	lab.fill(-1)
	for y in _h:
		for x in _w:
			var i := y * _w + x
			if _mask[i] == 0:
				continue
			var best := 1e9
			var bi := 0
			for s in seeds.size():
				var d := Vector2(x, y).distance_to(seeds[s]) + amp * ShipBreakup._nz(fields[s], x, y)
				if d < best:
					best = d
					bi = s
			lab[i] = bi
	_net.resize(_w * _h)
	for y in _h:
		for x in _w:
			var i := y * _w + x
			if lab[i] < 0:
				continue
			if (x + 1 < _w and lab[i + 1] >= 0 and lab[i + 1] != lab[i]) \
					or (y + 1 < _h and lab[i + _w] >= 0 and lab[i + _w] != lab[i]):
				_net[i] = 1
				_net_px.append(Vector2i(x, y))


func _process(delta: float) -> void:
	if auto:
		advance(delta)


## Which kind a hit is: small hits lean to scorch, big ones to holes and
## cracks, and venting only once the hull is at half or less (three at most).
func roll(frac: float, hp_after: float) -> int:
	var small := frac < 0.12
	var w := [0.5 if small else 0.2, 0.3 if small else 0.4, 0.2 if small else 0.4, 0.0]
	if hp_after <= VENT_FROM and _vents.size() < MAX_VENTS:
		w[Kind.VENT] = 0.35
	var tot := 0.0
	for x in w:
		tot += float(x)
	var r := _rng.randf() * tot
	for k in w.size():
		r -= float(w[k])
		if r < 0.0:
			return k
	return Kind.SCORCH


## A point on the hull on the side the shots come from, clear of the marks
## already there when it can be. `edge`: on the outline (a puncture vents
## outward from there); else well inside it. `near`: as close as it gets to a
## screen point (a shot that came through a shield).
func _pick(edge: bool, rad: float, near: Vector2 = Vector2.INF, around: Vector2 = Vector2.INF) -> Vector2i:
	var best := -1e9
	var bp := Vector2i(int(float(_H.get("cx", 0.0))), int(float(_H.get("cy", 0.0))))
	var bw := maxf(1.0, float(int(_H.get("x1", 1)) - int(_H.get("x0", 0)) + 1))
	var cx: float = _H.get("cx", 0.0)
	# The best of a dozen fair candidates, not of hundreds: with hundreds the
	# side bias always won and every hit landed on the nose.
	var found := 0
	for tries in 400:
		if found >= 12:
			break
		var x := _rng.randi_range(2, maxi(2, _w - 3))
		var y := _rng.randi_range(2, maxi(2, _h - 3))
		var i := y * _w + x
		if i >= _mask.size() or _mask[i] == 0:
			continue
		var empty := 0
		var deep := true
		for o in [1, -1, _w, -_w]:
			var q: int = i + int(o)
			if q < 0 or q >= _mask.size() or _mask[q] == 0:
				empty += 1
		if not edge:
			for o2 in [2, -2, 2 * _w, -2 * _w]:
				var q2: int = i + int(o2)
				if q2 < 0 or q2 >= _mask.size() or _mask[q2] == 0:
					deep = false
		if edge != (empty > 0) or (not edge and not deep):
			continue
		if edge:
			# a puncture vents into open space above or below the hull, not
			# into its own underside
			var nrm := ShipBreakup._normal_at(_H, _mask, Vector2i(x, y))
			if absf(nrm.y) < 0.5:
				continue
		found += 1
		var score: float
		# where the plating is light enough for a mark to show
		var lum := _orig[i].get_luminance()
		if around != Vector2.INF:
			# an extra lands round the hit, a mark's width or two away
			score = -absf(Vector2(x, y).distance_to(around) - 16.0) / 16.0 + 0.3 * lum + _rng.randf() * 0.5
		elif near != Vector2.INF:
			score = -_screen(Vector2i(x, y)).distance_to(near) * 0.05 + _rng.randf() * 0.4
		else:
			# leaning to the side the shots come from, spread over most of the hull
			score = 0.45 * float(facing) * (float(x) - cx) / bw + 0.6 * lum + _rng.randf() * 0.5
		for m in _marks:
			if Vector2(x, y).distance_to(m.p) < rad * _sc / SIZE + float(m.r) + 1.5:
				score -= 10.0
		if score > best:
			best = score
			bp = Vector2i(x, y)
	return bp


func _screen(p: Vector2i) -> Vector2:
	return _origin + Vector2(_r.position) + Vector2(p)


## A hit for `amount`, leaving `hp_after` of `max_hp`. `kind` -1 rolls one.
## Returns the kind it was.
func hit(amount: int, hp_after: int, max_hp: int, kind: int = -1, near: Vector2 = Vector2.INF) -> int:
	if int(_H.n) == 0:
		return Kind.SCORCH
	var frac := float(amount) / float(maxi(1, max_hp))
	var big := frac >= 0.15
	_hp = float(hp_after) / float(maxi(1, max_hp))
	if kind < 0:
		kind = roll(frac, _hp)
	rolled.append(NAMES[kind])
	var p: Vector2i
	match kind:
		Kind.SCORCH:
			p = _pick(false, 8.0 if big else 5.0, near)
			_scorch(p, big)
		Kind.HOLE:
			p = _pick(false, 9.2 if big else 8.0, near)
			_hole_hit(p, big)
		Kind.CRACK:
			p = _pick(false, 3.0, near)
			_crack(p, frac, big)
		Kind.VENT:
			p = _pick(true, 6.0, near)
			_vent(p, big)
	var sp := _screen(p)
	moment.emit(&"impact", 0.35 + 0.55 * minf(1.0, frac / 0.3), 0.0)
	# More marks per hit as the hull goes: shrapnel strikes round the hit,
	# smaller, scorch and holes mostly. No sound of their own (the hit's covers them).
	var extras := 0 if _hp > 0.75 else (1 if _hp > 0.5 else (2 if _hp > 0.25 else 3))
	_quiet = true
	_sc = SIZE * 0.7 * mark_scale
	for e in extras:
		var r2 := _rng.randf()
		if r2 < 0.45:
			_scorch(_pick(false, 5.0, Vector2.INF, Vector2(p)), false)
		elif r2 < 0.8:
			_hole_hit(_pick(false, 8.0, Vector2.INF, Vector2(p)), false)
		else:
			_crack(_pick(false, 3.0, Vector2.INF, Vector2(p)), 0.03, false)
	_sc = SIZE * mark_scale
	_quiet = false
	# Sparks fly back the way the shot came.
	_spray(sp, 20 if big else 9, 190.0 if big else 130.0, Vector2(float(facing) * 0.9, 0.0))
	return kind


## The ship's picture with every mark on it, for the death and the wreck.
## The marks alone (every changed pixel, transparent elsewhere) and where they
## go on the canvas: for an owner that bakes them in.
func marks() -> Image:
	return _dmg


func marks_at() -> Vector2i:
	return _r.position


## Canvas pixels a hit took off the picture altogether (none, on a ship: a
## creature's snapped crystal, `FaunaHitFx`). `EnemyArt` clears them.
func cut_px() -> PackedVector2Array:
	return PackedVector2Array()


func damaged(img: Image) -> Image:
	var out: Image = img.duplicate()
	out.blend_rect(_dmg, Rect2i(Vector2i.ZERO, _dmg.get_size()), _r.position)
	return out


## True while a hit's light or a crack is still running (a death should wait).
func busy() -> bool:
	for c in _crack_live:
		if not c.applied:
			return true
	return false


func _darken(i: int, k: float) -> void:
	if _what[i] == 2:
		return
	var c := _col[i]
	var o := _orig[i]
	var q := Color(c.r * k, c.g * k, c.b * k).lerp(SOOT, (1.0 - k) * 0.35)
	# Never past a floor: a much-hit patch is black-brown, not another hole.
	q = Color(maxf(q.r, o.r * 0.22), maxf(q.g, o.g * 0.22), maxf(q.b, o.b * 0.22), o.a)
	_put_px(i, q)
	if _what[i] == 0:
		_what[i] = 1


func _put_px(i: int, c: Color) -> void:
	version += 1
	_col[i] = c
	_dmg.set_pixel(i % _w, i / _w, c)
	_dirty = true


## Soot in held steps, darker inward, the outer two dithered (as Chain's).
func _soot_disc(p: Vector2i, rad: float) -> void:
	for y in range(p.y - int(rad) - 2, p.y + int(rad) + 3):
		for x in range(p.x - int(rad) - 2, p.x + int(rad) + 3):
			if x < 0 or y < 0 or x >= _w or y >= _h:
				continue
			var i := y * _w + x
			if _mask[i] == 0:
				continue
			var d := Vector2(x, y).distance_to(Vector2(p)) / rad
			var odd := ((x + y + _r.position.x + _r.position.y) & 1) == 0
			var k := 1.0
			if d < 0.45:
				k = 0.3
			elif d < 0.7:
				k = 0.48
			elif d < 0.88:
				k = 0.72 if odd else 0.86
			elif d < 1.05:
				k = 0.86 if odd else 1.0
			if k < 1.0:
				_darken(i, k)
			# heat tint: a ring of discoloured metal, brown going to straw,
			# dithered at its rim. Darkening alone vanished on dark hulls.
			if d >= 0.55 and d < 1.2 and _what[i] != 2:
				var amt := 0.42 if d < 0.88 else (0.28 if odd else 0.0)
				if amt > 0.0:
					var c := _col[i]
					var l := maxf(0.3, c.get_luminance() * 1.1)
					var tint := Color(0.62, 0.42, 0.26) * l * 1.35
					var q := c.lerp(tint, amt)
					_put_px(i, Color(q.r, q.g, q.b, c.a))
					if _what[i] == 0:
						_what[i] = 1


func _scorch(p: Vector2i, big: bool) -> void:
	var sp := _screen(p)
	var rad := (8.0 if big else 5.0) * _sc
	_soot_disc(p, rad)
	_marks.append({p = Vector2(p), r = rad})
	_embers.append({p = sp, t0 = t, big = big})
	_flashes.append({p = sp, t0 = t, r = 14 if big else 8, s = 1.0 if big else 0.7, life = 0.3 if big else 0.22})
	if not _quiet:
		moment.emit(&"sizzle", 0.3 if big else 0.2, 0.45)


## Chain's hole: a ragged bite of the hull, dark inside, scorched round to
## twice its size; the bitten pixels fly off as chips; its lip glows and cools.
func _hole_hit(p: Vector2i, big: bool) -> void:
	var rb := (4.2 if big else 3.0) * _sc
	var fd := ShipBreakup._field(_rng, _w, _h, 3)
	var bite: Array[Vector2i] = []
	for y in range(p.y - 12, p.y + 13):
		for x in range(p.x - 12, p.x + 13):
			if x < 0 or y < 0 or x >= _w or y >= _h:
				continue
			var i := y * _w + x
			if _mask[i] == 0 or _what[i] == 2:
				continue
			if Vector2(x, y).distance_to(Vector2(p)) <= rb + 1.1 * ShipBreakup._nz(fd, x, y):
				bite.append(Vector2i(x, y))
	_soot_disc(p, rb + 5.0 * _sc)
	# chips: the bitten pixels in their own colours, a few pieces by angle
	var groups := {}
	for q in bite:
		var a := atan2(float(q.y - p.y), float(q.x - p.x))
		var g := int(fposmod(a, TAU) / (TAU / 3.0))
		if not groups.has(g):
			groups[g] = []
		(groups[g] as Array).append(q)
	var sp := _screen(p)
	for g in groups.values():
		var arr: Array = g
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-1, -1)
		for q2 in arr:
			var v: Vector2i = q2
			mn = Vector2i(mini(mn.x, v.x), mini(mn.y, v.y))
			mx = Vector2i(maxi(mx.x, v.x), maxi(mx.y, v.y))
		var side := maxi(mx.x - mn.x + 1, mx.y - mn.y + 1)
		var im := Image.create(side, side, false, Image.FORMAT_RGBA8)
		for q3 in arr:
			var v3: Vector2i = q3
			im.set_pixel(v3.x - mn.x, v3.y - mn.y, _col[v3.y * _w + v3.x])
		var mid := Vector2(mn) + Vector2(side, side) * 0.5
		var dir := ((mid - Vector2(p)).normalized() + Vector2(float(facing) * 0.8, 0.0)).normalized()
		_chips.append({tex = ImageTexture.create_from_image(im), at = _screen(mn), size = side, dir = dir,
			speed = _rng.randf_range(60.0, 120.0), spin = _rng.randf_range(4.0, 9.0), t0 = t})
	var lip := PackedVector2Array()
	var in_bite := {}
	for q4 in bite:
		in_bite[q4] = true
		_put_px(q4.y * _w + q4.x, Color(HOLE_COL.r, HOLE_COL.g, HOLE_COL.b, _orig[q4.y * _w + q4.x].a))
		_what[q4.y * _w + q4.x] = 2
	for q5 in bite:
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n5: Vector2i = q5 + o
			if n5.x < 0 or n5.y < 0 or n5.x >= _w or n5.y >= _h:
				continue
			if in_bite.has(n5) or _mask[n5.y * _w + n5.x] == 0:
				continue
			lip.append(_screen(n5))
			in_bite[n5] = true
	_lips.append({px = lip, t0 = t})
	_marks.append({p = Vector2(p), r = rb + 5.0 * _sc})
	_flashes.append({p = sp, t0 = t, r = 12, s = 0.85 if big else 0.65, life = 0.24})
	_rings.append({p = sp, t0 = t, r0 = 3.0, r1 = 15.0 if big else 11.0, dur = 0.2, s = 0.6})
	for i2 in (8 if big else 5):
		var dv := Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_motes.append({p = sp + dv * 2.0, v = dv * _rng.randf_range(6.0, 16.0), age = 0.0,
			life = _rng.randf_range(0.3, 0.5), kind = 1, big = _rng.randf() < 0.3, drag = 0.5})
	if not _quiet:
		moment.emit(&"punch", 0.75 if big else 0.55, 0.0)
	if not _quiet:
		moment.emit(&"sizzle", 0.3 if big else 0.2, 0.45)


func _crack(p: Vector2i, frac: float, big: bool) -> void:
	if _net_px.is_empty():
		_scorch(p, big)
		return
	var q := _net_px[0]
	var bd := 1 << 30
	for np in _net_px:
		var d := (np - p).length_squared()
		if d < bd:
			bd = d
			q = np
	var order: Array[int] = []
	var steps := int(ceil(sqrt(float(bd))))
	if steps <= 16:
		# a spur from the hit to the network
		for s in steps + 1:
			var f := float(s) / float(maxi(1, steps))
			var ip := Vector2i(Vector2(p).lerp(Vector2(q), f).round())
			if ip.x >= 0 and ip.y >= 0 and ip.x < _w and ip.y < _h:
				var ii := ip.y * _w + ip.x
				if _mask[ii] == 1 and _what[ii] != 2 and _what[ii] != 3 and not order.has(ii):
					order.append(ii)
	else:
		q = p
	var want := int(float(maxi(30 if big else 16, int(frac * float(_net_px.size()) * 1.6))) * _sc)
	var seen := {}
	var head := 0
	var queue: Array[Vector2i] = [q]
	seen[q] = true
	var got := 0
	while head < queue.size() and got < want:
		var cur := queue[head]
		head += 1
		var ci := cur.y * _w + cur.x
		if _net[ci] == 1 and _what[ci] != 2 and _what[ci] != 3 and not order.has(ci):
			order.append(ci)
			got += 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx: int = cur.x + dx
				var ny: int = cur.y + dy
				if nx < 0 or ny < 0 or nx >= _w or ny >= _h:
					continue
				var nv := Vector2i(nx, ny)
				if seen.has(nv) or _net[ny * _w + nx] == 0:
					continue
				seen[nv] = true
				queue.append(nv)
	var dt := minf(0.012, 0.25 / float(maxi(1, order.size())))
	for j in order.size():
		_what[order[j]] = 3
		_crack_live.append({i = order[j], t = t + dt * j, applied = false})
	_marks.append({p = Vector2(p), r = 3.0 * _sc})
	var sp := _screen(p)
	_flashes.append({p = sp, t0 = t, r = 10 if big else 7, s = 0.8 if big else 0.6, life = 0.22})
	if not _quiet:
		moment.emit(&"crack", 0.3 + 0.6 * minf(1.0, frac / 0.3), dt * order.size() + 0.1)


func _vent(p: Vector2i, big: bool) -> void:
	var n := ShipBreakup._normal_at(_H, _mask, p)
	_soot_disc(p, (6.0 if big else 4.5) * _sc)
	var hr := (2.2 if big else 1.4) * _sc
	for y in range(p.y - 6, p.y + 7):
		for x in range(p.x - 6, p.x + 7):
			if x < 0 or y < 0 or x >= _w or y >= _h:
				continue
			var i := y * _w + x
			if _mask[i] == 1 and Vector2(x, y).distance_to(Vector2(p)) <= hr:
				_put_px(i, Color(HOLE_COL.r, HOLE_COL.g, HOLE_COL.b, _orig[i].a))
				_what[i] = 2
	var burst := 0.45 if big else 0.35
	_vents.append({p = p, n = n, t0 = t, burst = burst, next = t + burst + _rng.randf_range(0.6, 1.6),
		until = -1.0, big = big})
	_marks.append({p = Vector2(p), r = 6.0 * _sc})
	var sp := _screen(p)
	_flashes.append({p = sp, t0 = t, r = 12 if big else 8, s = 0.8 if big else 0.6, life = 0.22})
	moment.emit(&"hiss", 0.5 if big else 0.35, burst)


func _spray(at: Vector2, count: int, speed: float, bias: Vector2 = Vector2.ZERO) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		var v := (Vector2(cos(a), sin(a)) + bias).normalized() * _rng.randf_range(0.35, 1.0) * speed
		_motes.append({p = at, v = v, age = 0.0, life = _rng.randf_range(0.12, 0.32), kind = 0, big = false, drag = 4.5})


func _gas(at: Vector2, n: Vector2, count: int) -> void:
	for i in count:
		var dv := n.rotated(_rng.randf_range(-0.32, 0.32))
		_motes.append({p = at, v = dv * _rng.randf_range(50.0, 120.0), age = 0.0, life = _rng.randf_range(0.22, 0.45),
			kind = 2, big = _rng.randf() < 0.5, drag = 1.2})


## The hull now, 0..1, for a vent's sputters (a heal or a new fight sets it).
func set_hull(frac: float) -> void:
	_hp = frac


func advance(delta: float) -> void:
	t += delta
	for c in _crack_live:
		if not c.applied and t >= float(c.t):
			c.applied = true
			var ci := int(c.i)
			var o := _orig[ci]
			_put_px(ci, Color(o.r * 0.22, o.g * 0.22, o.b * 0.25, o.a))
			# the metal's edge along the crack catches light: one lit pixel below it
			var below := ci + _w
			if below < _mask.size() and _mask[below] == 1 and _what[below] == 0:
				var ob := _orig[below]
				_put_px(below, Color(minf(1.0, ob.r * 1.35 + 0.04), minf(1.0, ob.g * 1.35 + 0.04), minf(1.0, ob.b * 1.35 + 0.04), ob.a))
				_what[below] = 4
	var keep: Array = []
	for c2 in _crack_live:
		if t - float(c2.t) < 0.6:
			keep.append(c2)
	_crack_live = keep
	for v in _vents:
		var a := t - float(v.t0)
		var sp := _screen(v.p) + (v.n as Vector2)
		var rate := 0.0
		if a < float(v.burst):
			rate = 230.0 if a < float(v.burst) * 0.5 else 115.0
		elif _hp <= VENT_FROM:
			if t >= float(v.next):
				v.until = t + _rng.randf_range(0.15, 0.25)
				v.next = t + (_rng.randf_range(1.6, 3.0) if _hp > 0.25 else _rng.randf_range(0.9, 1.8))
				moment.emit(&"sputter", 0.15, float(v.until) - t)
			if t < float(v.until):
				rate = 110.0
		if rate > 0.0:
			_gas(sp, v.n, int(rate * delta + _rng.randf()))
	var kept: Array = []
	for mo in _motes:
		mo.age += delta
		if mo.age >= mo.life:
			continue
		mo.p += mo.v * delta
		mo.v *= exp(-float(mo.drag) * delta)
		kept.append(mo)
	_motes = kept
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return t - float(f.t0) <= float(f.life))
	_embers = _embers.filter(func(e: Dictionary) -> bool: return t - float(e.t0) < 0.6)
	_lips = _lips.filter(func(l: Dictionary) -> bool: return t - float(l.t0) < 0.5)
	_chips = _chips.filter(func(c4: Dictionary) -> bool: return t - float(c4.t0) < 0.42)
	_rings = _rings.filter(func(r: Dictionary) -> bool: return t - float(r.t0) <= float(r.dur))
	if _dirty:
		_dmg_tex.update(_dmg)
		_dirty = false
	queue_redraw()
	for c3 in get_children():
		(c3 as CanvasItem).queue_redraw()


func _paint_body(ci: CanvasItem) -> void:
	if draw_marks:
		ci.draw_texture(_dmg_tex, _origin + Vector2(_r.position))
	for c in _chips:
		var age := t - float(c.t0)
		var dist := float(c.speed) * (1.0 - exp(-2.4 * age)) / 2.4
		var p := (Vector2(c.at) + (c.dir as Vector2) * dist).round()
		var rot := int(floor(age * float(c.spin))) % 4
		var al := 1.0 if age < 0.22 else (0.6 if age < 0.3 else (0.3 if age < 0.36 else 0.12))
		var sz := float(c.size)
		ci.draw_set_transform(p + Vector2(sz, sz) * 0.5, float(rot) * PI * 0.5, Vector2.ONE)
		ci.draw_texture(c.tex, -Vector2(sz, sz) * 0.5, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paint_light(ci: CanvasItem) -> void:
	var R: Array = ShipBreakup.HEAT_RAMP
	for f in _flashes:
		var age := t - float(f.t0)
		var life: float = f.life
		if age < 0.0:
			continue
		var x := age / life
		var l := (1.0 if x < 0.25 else (0.6 if x < 0.5 else (0.32 if x < 0.75 else 0.14))) * float(f.s)
		var tex := ShipBreakup._warm(int(f.r))
		ci.draw_texture(tex, (Vector2(f.p) - Vector2(tex.get_size()) * 0.5).round(), Color(l, l, l, 1))
	for rg in _rings:
		var age5 := t - float(rg.t0)
		var x5 := age5 / float(rg.dur)
		var rr := int(float(rg.r0) + (float(rg.r1) - float(rg.r0)) * (1.0 - pow(1.0 - x5, 3.0)))
		var l5 := float(rg.s) * (1.0 if x5 < 0.33 else (0.6 if x5 < 0.66 else 0.3))
		_ring(ci, rg.p, rr, ShipBreakup._lv(R[1], l5))
	for e in _embers:
		var a := t - float(e.t0)
		var big: bool = e.big
		var s := 1.0 if big else 0.75
		var p: Vector2 = (e.p as Vector2).round()
		if a < 0.07 * s:
			var tx := ShipBreakup._warm(4 if big else 3)
			ci.draw_texture(tx, p - Vector2(tx.get_size()) * 0.5 + Vector2(0.5, 0.5), Color(1, 1, 1, 1))
		elif a < 0.16 * s:
			var tx2 := ShipBreakup._warm(3 if big else 2)
			ci.draw_texture(tx2, p - Vector2(tx2.get_size()) * 0.5 + Vector2(0.5, 0.5), Color(0.75, 0.75, 0.75, 1))
		elif a < 0.3 * s:
			ci.draw_rect(Rect2(p, Vector2.ONE), ShipBreakup._lv(R[2], 0.8))
		elif a < 0.45 * s:
			ci.draw_rect(Rect2(p, Vector2.ONE), ShipBreakup._lv(R[3], 0.6))
		elif a < 0.6 * s:
			ci.draw_rect(Rect2(p, Vector2.ONE), ShipBreakup._lv(R[4], 0.4))
	for lp in _lips:
		var a2 := t - float(lp.t0)
		var lc: Color
		if a2 < 0.08:
			lc = ShipBreakup._lv(R[0], 0.9)
		elif a2 < 0.18:
			lc = ShipBreakup._lv(R[1], 0.75)
		elif a2 < 0.3:
			lc = ShipBreakup._lv(R[2], 0.55)
		elif a2 < 0.42:
			lc = ShipBreakup._lv(R[3], 0.4)
		else:
			lc = ShipBreakup._lv(R[4], 0.25)
		for q in (lp.px as PackedVector2Array):
			if a2 >= 0.3 and ((int(q.x) + int(q.y)) & 1) == 1:
				continue
			ci.draw_rect(Rect2(q, Vector2.ONE), lc)
	for c in _crack_live:
		var age2 := t - float(c.t)
		if age2 < 0.0:
			continue
		var col: Color
		if age2 < 0.06:
			col = ShipBreakup._lv(R[0], 1.0)
		elif age2 < 0.16:
			col = ShipBreakup._lv(R[1], 0.85)
		elif age2 < 0.3:
			col = ShipBreakup._lv(R[2], 0.6)
		elif age2 < 0.45:
			col = ShipBreakup._lv(R[3], 0.4)
		else:
			col = ShipBreakup._lv(R[4], 0.25)
		var i := int(c.i)
		var pp := _screen(Vector2i(i % _w, i / _w))
		ci.draw_rect(Rect2(pp, Vector2.ONE), col)
		if age2 < 0.3 and ((int(pp.x) + int(pp.y)) & 1) == 0:
			var halo := Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 1)
			for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_rect(Rect2(pp + o, Vector2.ONE), halo)
	for mo in _motes:
		var f2: float = mo.age / mo.life
		var p2: Vector2 = (mo.p as Vector2).round()
		match int(mo.kind):
			0:
				var c2: Color = R[0] if f2 < 0.4 else (R[2] if f2 < 0.75 else R[4])
				ci.draw_rect(Rect2(p2, Vector2.ONE), c2)
				var tail: Vector2 = ((mo.p as Vector2) - (mo.v as Vector2).normalized() * 2.0).round()
				if tail != p2:
					ci.draw_rect(Rect2(tail, Vector2.ONE), c2 * Color(0.5, 0.5, 0.5, 1))
			1:
				var c1: Color = R[1] if f2 < 0.25 else (R[2] if f2 < 0.5 else (R[3] if f2 < 0.8 else R[5]))
				ci.draw_rect(Rect2(p2, Vector2(2, 2) if mo.big and f2 < 0.5 else Vector2.ONE), c1)
			_:
				var gi := 0 if f2 < 0.2 else (1 if f2 < 0.5 else (2 if f2 < 0.8 else 3))
				var gl: float = [1.0, 0.75, 0.5, 0.3][gi]
				ci.draw_rect(Rect2(p2, Vector2.ONE), ShipBreakup._lv(ShipBreakup.GAS[gi], gl))
				if mo.big and f2 < 0.4:
					var arm := ShipBreakup._lv(ShipBreakup.GAS[gi], gl * 0.4)
					for o2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
						ci.draw_rect(Rect2(p2 + o2, Vector2.ONE), arm)


func _ring(ci: CanvasItem, c: Vector2, r: int, col: Color) -> void:
	if r < 1:
		return
	var pts := {}
	var n := int(ceil(TAU * r)) + 8
	for i in n:
		var a := TAU * float(i) / float(n)
		pts[Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))] = true
	var cp := c.round()
	for p in pts:
		ci.draw_rect(Rect2(cp + Vector2(p as Vector2i), Vector2.ONE), col)
