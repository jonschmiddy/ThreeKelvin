class_name SubjectPlan
extends RefCounted

## Content is data: staging kinds are code, pieces and placement come from the option's `subject`.
## Nothing is drawn across anything else; `-- subjecttest` holds every subject to it.
## Why: docs/why/LocalSubject.md#subject-staging

## The event's band on LOCAL (`LocalEventDrawer.H`) and the air kept round the
## subject's box.
const BAND := 190.0
const PAD := 10.0
## The stagings the last `plan` drew fewer of than asked, to keep them clear.
static var short: Array[String] = []
## A harness's override of `pick` (which kept take is drawn), or -1.
static var force_pick := -1


static func has_piece(id: StringName) -> bool:
	return not SubjectMask.piece_info(id).is_empty()


## Every stage of a subject, back to front.
static func stages_of(s: Variant) -> Array:
	if s is Dictionary:
		var d := s as Dictionary
		if d.has("layers"):
			return d.layers
		return [d]
	return []


# --------------------------------------------------------------- where it goes

## THE SUBJECT'S BOX in a view `w` x `h`: right of centre (your ship is on the
## left), under the sector's name, above the event's band.
static func box_for(view_size: Vector2) -> Rect2:
	var x0 := view_size.x * 0.5 + 12.0
	return Rect2(x0, 36.0, maxf(0.0, view_size.x - x0 - 14.0), maxf(0.0, view_size.y - BAND - 36.0 - PAD))


## Deterministic and draws nothing, so a test can check the fit without a screen.
static func plan(s: Variant, oid: StringName = &"", danger: int = 1, sys: int = -1) -> Array:
	var out: Array = []
	var stage_i := -1
	short.clear()
	for st: Dictionary in stages_of(resolve(s, oid, danger, sys)):
		stage_i += 1
		var at: Vector2 = st.get("at", Vector2.ZERO)
		# what earlier stages placed, in this stage's own frame, to keep clear of
		var prior: Array = []
		for o: Dictionary in out:
			var c: Dictionary = o.duplicate()
			c.at = (o.at as Vector2) - at
			prior.append(c)
		st = st.duplicate()
		st._prior = prior
		var made: Array = []
		match StringName(st.get("stage", &"single")):
			&"single":
				made = _stage_single(st)
			&"row":
				made = _stage_row(st)
			&"tether":
				made = _stage_tether(st)
			&"field":
				made = _stage_field(st)
			&"herd":
				made = _stage_herd(st)
			&"line":
				made = _stage_line(st)
			&"around":
				made = _stage_around(st)
			&"on_rock":
				made = _stage_on_rock(st)
			&"strewn":
				made = _stage_strewn(st)
			&"ring":
				made = _stage_ring(st)
			&"group":
				made = _stage_group(st)
			&"structure":
				made = _stage_structure(st)
			&"ring_arc":
				made = _stage_ring_arc(st)
			&"none", &"fx":
				# (nothing to place: `none` only takes the stand-in's place; an
				# effect is drawn in code by `LocalFx`)
				made = []
		# Anchored stages place from a sky object (world face, rings, star line), not the box.
		var anchor := StringName(st.get("anchor", &"ring" if StringName(st.get("stage", &"")) == &"ring_arc" else &""))
		if anchor != &"":
			for m: Dictionary in made:
				m.anchor = anchor
				m.anchor_on = st.get("on", Vector2.ZERO)
				m.anchor_d = float(st.get("d", 0.0))
				m.anchor_at = at
		# a piece's own look, from its stage: a painter piece cut lumpy (`lumpy`,
		# its outline's seed) or dirtied (`dirt`); and the effects that ride on it
		for m: Dictionary in made:
			for k2: String in ["lumpy", "world", "dirt", "bake", "silhouette", "dust", "glint", "window", "tail"]:
				if st.has(k2) and not m.has(k2):
					m[k2] = st[k2]
		# a staging that could not stand every piece clear shows fewer: say so
		var wanted := int(st.get("count", made.size()))
		var real := 0
		for m: Dictionary in made:
			if not bool(m.get("base_of", false)) and not bool(m.get("welds", false)) and not bool(m.get("tether", false) and (st.get("ends", []) as Array).has(m.id)):
				real += 1
		if st.has("count") and real < wanted:
			short.append("%s %d of %d" % [st.get("stage", &""), real, wanted])
		var first := out.size()
		for m: Dictionary in made:
			m.at = (m.at as Vector2) + at
			m.st_i = stage_i
			if m.has("dock_to"):
				m.dock_to = int(m.dock_to) + first
			# a stage's ship states fall to every piece in it that has not its own
			for k: String in SHIP_STATES:
				if st.has(k) and not m.has(k):
					m[k] = st[k]
			m.strobe_of = st.get("strobe_id", -1)
			out.append(m)
	# A SHIP ON ANOTHER is set down on its top edge: lowered until one more pixel
	# would cross it, so the two touch and neither is drawn over the other
	for m: Dictionary in out:
		if m.has("dock_to"):
			_dock(m, out[int(m.dock_to)])
	# far first, near last (a docked one keeps its host's index through the sort)
	for i in out.size():
		out[i].idx = i
	# (a structure first of all: what belongs to it is in front of it, far or not)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("structure", false)) != bool(b.get("structure", false)):
			return bool(a.get("structure", false))
		return float(a.far) > float(b.far) if not is_equal_approx(float(a.far), float(b.far)) else int(a.get("z", 0)) < int(b.get("z", 0)))
	var where := {}
	for i in out.size():
		where[int(out[i].idx)] = i
	for m: Dictionary in out:
		if m.has("dock_to"):
			m.dock_to = where[int(m.dock_to)]
	return out


## Lowered a pixel at a time until it touches, never crossing; clamps go a quarter in.
static func _dock(m: Dictionary, host: Dictionary) -> void:
	var a := SubjectMask.mask_of(m)
	var b := SubjectMask.mask_of(host)
	if a.is_empty() or b.is_empty():
		return
	var hp := SubjectMask._corner(host, b)
	var at: Vector2 = m.at
	var y := (host.at as Vector2).y - float(int(b.h) + int(a.h)) * 0.5 - 4.0
	var best := y
	for step in 200:
		m.at = Vector2(at.x, y)
		if SubjectMask.touches(a, SubjectMask._corner(m, a), b, hp, 0, 0):
			break
		best = y
		y += 1.0
	m.at = Vector2(at.x, best)
	# the clamps: where its underside meets the host, a quarter in from each end
	var mp := SubjectMask._corner(m, a)
	var links: Array = []
	for f: float in [0.25, 0.75]:
		var x := int(round(float(int(a.w)) * f))
		var bits: PackedByteArray = a.bits
		var low := -1
		for yy in range(int(a.h) - 1, -1, -1):
			if bits[yy * int(a.w) + x] != 0:
				low = yy
				break
		if low >= 0:
			links.append(Vector2(mp.x + x, mp.y + low + 1) - (m.at as Vector2))
	m.links = links


## The rect a planned piece covers, px from the subject's centre.
static func rect_of(m: Dictionary) -> Rect2:
	var sz := SubjectMask.turned_size(SubjectMask.piece_size(StringName(m.id), float(m.get("r", 0.0))), float(m.get("turn", 0.0))) * float(m.scale)
	# (turning right over, it sweeps the square of its diagonal)
	if float(m.get("roll", 0.0)) != 0.0:
		sz = Vector2.ONE * ceilf(sz.length())
	return Rect2((m.at as Vector2) - sz * 0.5, sz)


static func _piece(st: Dictionary, i: int) -> StringName:
	var ps: Array = st.get("pieces", [])
	return StringName(ps[i % ps.size()]) if not ps.is_empty() else &""


static func _m(id: StringName, at: Vector2, sc: float = 1.0, far: float = 0.0, extra: Dictionary = {}) -> Dictionary:
	var d := {id = id, at = at, scale = sc, far = far, r = 0.0, flip = false, z = 0}
	d.merge(extra, true)
	return d


static func _stage_single(st: Dictionary) -> Array:
	var far := bool(st.get("far", false))
	# `size`: drawn that much smaller (its own half or quarter picture), dimmed
	# toward the sky by `far_k` (none unless asked: small, not far)
	var sc := float(st.get("size", 0.5 if far else 1.0))
	var m := _m(_piece(st, 0), Vector2.ZERO, sc, float(st.get("far_k", 0.55 if far else 0.0)),
		{r = float(st.get("r", 0.0)), tumble = float(st.get("tumble", 0.0)), turn = float(st.get("turn", 0.0)), flip = bool(st.get("flip", false))})
	# `roll`: turning right over (the soft turner; `_process`)
	if st.has("roll"):
		m.roll = float(st.roll)
	# `spin`: a ring spinning about its own axis (`_spin_setup`)
	if st.has("spin"):
		m.spin = float(st.spin)
	return [m]


## A row runs nose to tail: near ones at 1x, the rest at half, or a quarter with `recede`.
static func _stage_row(st: Dictionary) -> Array:
	var n := int(st.get("count", 3))
	var near := int(st.get("near", n))
	var recede := bool(st.get("recede", false))
	var mid := int(st.get("mid", 3 if recede else n))
	var made: Array = []
	for i in n:
		var sc := 1.0 if i < near else (0.5 if i < near + mid else 0.25)
		made.append(_m(_piece(st, i), Vector2.ZERO, sc, _far_of(sc), {z = -i, flip = bool(st.get("flip", false))}))
	return _nose_to_tail(made, st, float(st.get("span", 300.0)))


## How far off a piece drawn at `sc` is seen: dimmed toward the sky the smaller it is.
static func _far_of(sc: float) -> float:
	return 0.0 if sc >= 1.0 else (0.45 if sc >= 0.5 else 0.6)


## The steepest a line of things runs (rise over run).
const MAX_SLOPE := 0.3


## Each piece goes on only once clear sideways, so lines never pile into a column (Jon).
## Why: docs/why/LocalSubject.md#nose-to-tail
static func _nose_to_tail(made: Array, st: Dictionary, span: float) -> Array:
	var dir: Vector2 = st.get("dir", Vector2(1.0, -0.2))
	var sx := -1.0 if dir.x < 0.0 else 1.0
	var slope := clampf(dir.y / maxf(absf(dir.x), 0.001), -MAX_SLOPE, MAX_SLOPE)
	var gap := float(st.get("gap", 10.0))
	var jit := float(st.get("jitter", 0.0))
	var turns := float(st.get("turns", 0.0))
	var R := RandomNumberGenerator.new()
	R.seed = int(st.get("seed", 5))
	var out: Array = []
	var run := 0.0
	var prev_w := 0.0
	var prev_sc := 1.0
	for m: Dictionary in made:
		var sc := float(m.scale)
		if turns > 0.0:
			m.turn = roundf(R.randf_range(-turns, turns))
		var lift := R.randf_range(-jit, jit) * sc if jit > 0.0 else 0.0
		var w := SubjectMask.turned_size(SubjectMask.piece_size(StringName(m.id)), float(m.get("turn", 0.0))).x * sc
		if not out.is_empty():
			run += (prev_w + w) * 0.5 + maxf(gap * minf(sc, prev_sc), 3.0)
		var placed := false
		while run <= span:
			m.at = Vector2(sx * run, slope * run + lift).round()
			if SubjectMask._clear(m, out):
				placed = true
				break
			run += 2.0
		if not placed:
			break
		out.append(m)
		prev_w = w
		prev_sc = sc
	if out.is_empty():
		return out
	# only what fits in `span`, measured from the line's own middle
	while out.size() > 1:
		var a: Rect2 = rect_of(out[0])
		var b: Rect2 = rect_of(out[out.size() - 1])
		if a.merge(b).size.x <= span:
			break
		out.pop_back()
	# (a whole-pixel shift, so the spacing found is the spacing drawn)
	var c := (((out[0].at as Vector2) + (out[out.size() - 1].at as Vector2)) * 0.5).round()
	var kept: Array = []
	var prior: Array = st.get("_prior", [])
	for m: Dictionary in out:
		m.at = ((m.at as Vector2) - c).round()
		if SubjectMask._clear(m, prior):
			kept.append(m)
	return kept


## One line at one depth: mixed sizes on a single string make no sense at any distance (Jon).
static func _stage_tether(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 6))
	var far := bool(st.get("far", false))
	var sc := 0.5 if far else 1.0
	var fv := _far_of(sc)
	var span := float(st.get("span", 320.0))
	var sag := float(st.get("sag", 18.0)) * sc
	var tilt := clampf(float(st.get("tilt", -0.12)), -MAX_SLOPE, MAX_SLOPE)
	var ends: Array = st.get("ends", [])
	var er := float(st.get("r", 34.0))
	for k in ends.size():
		var x := (-0.5 if k == 0 else 0.5) * span
		out.append(_m(StringName(ends[k]), Vector2(x, x * tilt).round(), sc, fv, {r = er, z = -1, tether = true}))
	# what is left between the ends, past each end's own half-width and some air
	var inner := span
	for e in ends:
		inner -= (SubjectMask.piece_size(StringName(e), er).x * 0.5 + 12.0) * sc
	var ws: Array[float] = []
	var total := 0.0
	for i in n:
		var w := SubjectMask.piece_size(_piece(st, i)).x * sc
		ws.append(w)
		total += w
	var gap := maxf((inner - total) / maxf(float(n - 1), 1.0), 4.0 * sc)
	var x := -(total + gap * float(n - 1)) * 0.5
	for i in n:
		x += ws[i] * 0.5
		var t := x / maxf(inner, 1.0)
		var y := x * tilt + sag * (1.0 - 4.0 * t * t)
		out.append(_m(_piece(st, i), Vector2(x, y).round(), sc, fv, {tether = true, z = i}))
		x += ws[i] * 0.5 + gap
	return out


## A field: pieces scattered through an ellipse, some near and some far, each
## drifting and turning on its own slow clock.
static func _stage_field(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 8))
	var near := int(st.get("near", int(ceil(float(n) * 0.5))))
	var span := float(st.get("span", 360.0))
	var hgt := float(st.get("height", 150.0))
	var R := RandomNumberGenerator.new()
	R.seed = int(st.get("seed", 7))
	var prior: Array = st.get("_prior", [])
	# Fields vary turn, depth and lean so they do not read as copy-pasted (Jon).
	# Why: docs/why/LocalSubject.md#fields
	var turns := float(st.get("turns", 0.0))
	var deep := int(st.get("deep", 0))
	var band := deg_to_rad(float(st.get("band", 0.0)))
	# A loose group, not a line (Jon): `flip` faces all one way, `lift` raises the far ones.
	var lift := float(st.get("lift", 0.0))
	# `r`: [smallest, largest] radius for its painter pieces (rocks and ice in a
	# stream), each its own size from `seed`
	var rr_range: Array = st.get("r", [])
	for i in n:
		var far := i >= near
		var id := _piece(st, i)
		var sc := 0.5 if far else 1.0
		if i >= n - deep and far:
			sc = 0.25
		var turn := roundf(R.randf_range(-turns, turns)) if turns > 0.0 else 0.0
		var pr := 0.0
		if rr_range.size() == 2 and String(SubjectMask.piece_info(id).get("kind", "")) == "painter":
			pr = roundf(lerpf(float(rr_range[0]), float(rr_range[1]), R.randf()))
		var sz := SubjectMask.turned_size(SubjectMask.piece_size(id, pr), turn) * sc
		var flip := R.randf() < 0.5
		if st.has("flip"):
			flip = bool(st.flip)
		for tries in 60:
			var a := R.randf() * TAU
			var rr := sqrt(R.randf())
			var at := Vector2(cos(a) * span * 0.5 * rr, sin(a) * hgt * 0.5 * rr)
			if band != 0.0:
				at = at.rotated(band)
			at.y -= lift * (1.0 - sc) / 0.75
			# kept inside the field's own box
			at.x = clampf(at.x, -span * 0.5 + sz.x * 0.5, span * 0.5 - sz.x * 0.5)
			at.y = clampf(at.y, -hgt * 0.5 + sz.y * 0.5, hgt * 0.5 - sz.y * 0.5)
			var m := _m(id, at.round(), sc, _far_of(sc) if turns > 0.0 or deep > 0 else (0.55 if far else 0.0),
				{flip = flip, tumble = float(st.get("tumble", 4.0)) if pr <= 0.0 else 0.0, z = i, turn = turn, r = pr})
			# CLEAR of every piece already placed, this field's and the scene's
			if SubjectMask._clear(m, out + prior):
				out.append(m)
				break
	return out


## A herd: the near ones big in front, the rest far behind and above, all facing
## the way they swim.
static func _stage_herd(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 6))
	var near := int(st.get("near", 2))
	var span := float(st.get("span", 380.0))
	var hgt := float(st.get("height", 140.0))
	var R := RandomNumberGenerator.new()
	R.seed = int(st.get("seed", 11))
	for i in n:
		var far := i >= near
		var id := _piece(st, i)
		var sc := 0.5 if far else 1.0
		var sz := SubjectMask.piece_size(id) * sc
		var x := 0.0
		var y := 0.0
		if far:
			x = lerpf(-span * 0.5 + sz.x * 0.5, span * 0.5 - sz.x * 0.5, (float(i - near) + 0.5) / maxf(float(n - near), 1.0)) + R.randf_range(-10.0, 10.0)
			y = -hgt * 0.5 + sz.y * 0.5 + R.randf_range(0.0, hgt * 0.35)
		else:
			x = lerpf(-span * 0.5 + sz.x * 0.5, span * 0.5 - sz.x * 0.5, (float(i) + 0.5) / maxf(float(near), 1.0))
			y = hgt * 0.5 - sz.y * 0.5 - R.randf_range(0.0, hgt * 0.2)
		var m := _nearest_clear(_m(id, Vector2(x, y).round(), sc, 0.55 if far else 0.0,
			{swim = bool(st.get("swim", true)), flip = bool(st.get("flip", false)), z = i}),
			out + (st.get("_prior", []) as Array), Rect2(-span * 0.5, -hgt * 0.5, span, hgt), R)
		if not m.is_empty():
			out.append(m)
	return out


## Left out when no clear place exists, rather than drawn across another piece.
static func _nearest_clear(m: Dictionary, others: Array, room: Rect2, R: RandomNumberGenerator) -> Dictionary:
	var home: Vector2 = m.at
	var sz := SubjectMask.piece_size(StringName(m.id), float(m.get("r", 0.0))) * float(m.scale)
	for ring in 16:
		var tries := 1 if ring == 0 else 10
		for k in tries:
			var at := home
			if ring > 0:
				var a := R.randf() * TAU
				at = home + Vector2(cos(a), sin(a) * 0.6) * float(ring) * 10.0
			at.x = clampf(at.x, room.position.x + sz.x * 0.5, room.end.x - sz.x * 0.5)
			at.y = clampf(at.y, room.position.y + sz.y * 0.5, room.end.y - sz.y * 0.5)
			m.at = at.round()
			if SubjectMask._clear(m, others):
				return m
	return {}


## A crossing line, nose to tail: near at 1x, then half, then a quarter, leaning `rise`.
static func _stage_line(st: Dictionary) -> Array:
	var n := int(st.get("count", 9))
	var near := int(st.get("near", 1))
	var mid := int(st.get("mid", n))
	var span := float(st.get("span", 380.0))
	var made: Array = []
	for i in n:
		var sc := 1.0 if i < near else (0.5 if i < near + mid else 0.25)
		made.append(_m(_piece(st, i), Vector2.ZERO, sc, _far_of(sc),
			{swim = bool(st.get("swim", true)), flip = bool(st.get("flip", false)), z = -i}))
	var st2 := st.duplicate()
	if not st2.has("dir"):
		st2.dir = Vector2(span, float(st.get("rise", -60.0)))
	return _nose_to_tail(made, st2, span)


## Round a body: the body in the middle; the creatures behind it far, the ones
## in front near.
static func _stage_around(st: Dictionary) -> Array:
	var out: Array = []
	var base := StringName(st.get("base", &""))
	var r := float(st.get("r", 56.0))
	var bx := {r = r, z = 0, base_of = true, turn = float(st.get("base_turn", 0.0)), flip = bool(st.get("base_flip", false))}
	if st.has("base_dark"):
		bx.dark = float(st.base_dark)
	out.append(_m(base, Vector2.ZERO, 1.0, 0.0, bx))
	if bool(st.get("loose", false)):
		out.append_array(_loose_round(st, out[0]))
		return out
	var n := int(st.get("count", 5))
	var rx := float(st.get("rx", r + 70.0))
	var ry := float(st.get("ry", r * 0.55))
	var round: Array = []
	var prior: Array = st.get("_prior", [])
	for i in n:
		var id := _piece(st, i)
		for k in 24:
			var a := TAU * float(i) / float(n) + 0.6 + float(k) * 0.045 * (1.0 if k % 2 == 0 else -1.0) * float((k + 1) / 2)
			var front := sin(a) > 0.0
			var m := _m(id, Vector2(cos(a) * rx, sin(a) * ry).round(), 1.0 if front else 0.5, 0.0 if front else 0.55,
				{swim = true, flip = cos(a) > 0.0, z = 10 + i if front else -10 - i, on_base = true})
			if SubjectMask._clear(m, round + prior):
				round.append(m)
				break
	out.append_array(round)
	return out


## Each keeps clear of the others and of the body, so none touches the moon (Jon).
## Why: docs/why/LocalSubject.md#loose-herd
static func _loose_round(st: Dictionary, body: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 6))
	var rx := float(st.get("rx", 120.0))
	var ry := float(st.get("ry", 70.0))
	var size := float(st.get("size", 0.5))
	var tilt := float(st.get("tilt", 14.0))
	var apart := int(st.get("apart", 8))
	var R := RandomNumberGenerator.new()
	R.seed = int(st.get("seed", 5))
	var prior: Array = st.get("_prior", [])
	var bm := SubjectMask.mask_of(body)
	for i in n:
		var id := _piece(st, i)
		for tries in 60:
			var a := R.randf() * TAU
			var front := sin(a) > -0.25
			var sc := (size if R.randf() < 0.85 else size * 0.5) if front else (size * 0.5 if R.randf() < 0.5 else size * 0.25)
			var rr := R.randf_range(1.0, 1.5)
			var m := _m(id, Vector2(cos(a) * rx * rr, sin(a) * ry * rr).round(), sc, _far_of(sc / maxf(size, 0.01)),
				{turn = roundf(R.randf_range(-tilt, tilt)), flip = R.randf() < 0.5, z = 10 + i if front else -10 - i, on_base = true})
			var mm := SubjectMask.mask_of(m)
			var d := SubjectMask.drift_of(m) + SubjectMask.drift_of(body)
			if not bm.is_empty() and SubjectMask.touches(mm, SubjectMask._corner(m, mm), bm, SubjectMask._corner(body, bm), apart + int(ceilf(d.x)), apart + int(ceilf(d.y))):
				continue
			if SubjectMask._clear(m, out + prior):
				out.append(m)
				break
	return out


## On a rock: the rock, and pieces on its face in rows, clamps between them.
static func _stage_on_rock(st: Dictionary) -> Array:
	var out: Array = []
	var base := StringName(st.get("base", &""))
	var r := float(st.get("r", 80.0))
	# `planet` keeps the old planet-painter look, as Jon kept the welded plate on that rock.
	out.append(_m(base, Vector2.ZERO, 1.0, 0.0, {r = r, z = 0, base_of = true, planet = bool(st.get("planet", false))}))
	var rows := int(st.get("rows", 1))
	var cols := int(st.get("count", 1))
	var gap: Vector2 = st.get("gap", Vector2(56.0, 46.0))
	var clamp_id := StringName(st.get("clamp", &""))
	var face: Vector2 = st.get("face", Vector2.ZERO)
	if bool(st.get("loose", false)):
		out.append_array(_loose_on(st, clamp_id, face, out[0]))
		return out
	for y in rows:
		for x in cols:
			var p := face + Vector2((float(x) - float(cols - 1) * 0.5) * gap.x, (float(y) - float(rows - 1) * 0.5) * gap.y)
			out.append(_m(_piece(st, y * cols + x), p, 1.0, 0.0, {z = 1 + y * cols + x, on_base = true, rides = true}))
			if clamp_id != &"" and x < cols - 1:
				# a clamp welds two neighbours together: it is on both
				out.append(_m(clamp_id, p + Vector2(gap.x * 0.5, 0.0), 1.0, 0.0, {z = 100 + y * cols + x, on_base = true, welds = true, rides = true}))
	return out


## Side by side on the rock's face, never stacked, each clamped at its foot (Jon).
## Why: docs/why/LocalSubject.md#clamped-pieces
static func _loose_on(st: Dictionary, clamp_id: StringName, face: Vector2, rock: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 5))
	var spread: Vector2 = st.get("spread", Vector2(180.0, 120.0))
	var turns := float(st.get("turns", 10.0))
	var sc := float(st.get("size", 1.0))
	var R := RandomNumberGenerator.new()
	R.seed = int(st.get("seed", 4))
	var boxes: Array = []
	for i in n:
		var id := _piece(st, i)
		for tries in 50:
			var at := face + Vector2(R.randf_range(-0.5, 0.5) * spread.x, R.randf_range(-0.5, 0.5) * spread.y)
			var deg := roundf(R.randf_range(-turns, turns))
			var m := _m(id, at.round(), sc, 0.0, {z = 2 + i * 2, on_base = true, rides = true, turn = deg})
			var foot := Vector2(0.0, (SubjectMask.piece_size(id).y * 0.5 - 3.0) * sc).rotated(deg_to_rad(deg))
			var held := _m(clamp_id, (at + foot).round(), sc, 0.0, {z = 1 + i * 2, on_base = true, welds = true, rides = true, turn = deg}) if clamp_id != &"" else {}
			var beside := true
			for o: Dictionary in boxes:
				var ra := rect_of(m)
				var rb := rect_of(o)
				if ra.position.x < rb.end.x + 4.0 and rb.position.x < ra.end.x + 4.0:
					beside = false
			if not beside:
				continue
			if not _on_rock(m, rock) or (not held.is_empty() and not _on_rock(held, rock)):
				continue
			if SubjectMask._clear(m, boxes):
				boxes.append(m)
				out.append(m)
				if not held.is_empty():
					out.append(held)
				break
	return out


## Whether every opaque pixel of planned piece `m` lies on `rock`'s own, a few
## px in from its edge.
static func _on_rock(m: Dictionary, rock: Dictionary) -> bool:
	var a := SubjectMask.mask_of(m)
	var b := SubjectMask.mask_of(rock)
	if a.is_empty() or b.is_empty():
		return true
	var pa := SubjectMask._corner(m, a)
	var pb := SubjectMask._corner(rock, b)
	var ab: PackedByteArray = a.bits
	var bb: PackedByteArray = b.bits
	var inset := 3
	for y in int(a.h):
		for x in int(a.w):
			if ab[y * int(a.w) + x] == 0:
				continue
			for o: Vector2i in [Vector2i(0, 0), Vector2i(-inset, 0), Vector2i(inset, 0), Vector2i(0, -inset), Vector2i(0, inset)]:
				var bx := pa.x + x + o.x - pb.x
				var by := pa.y + y + o.y - pb.y
				if bx < 0 or by < 0 or bx >= int(b.w) or by >= int(b.h) or bb[by * int(b.w) + bx] == 0:
					return false
	return true


## The ship states a stage hands down to its pieces.
const SHIP_STATES := ["dark", "lights", "drive", "flood", "tow"]


## The encounter id picks the pool ships, so it shows the same ships every time.
## Why: docs/why/LocalSubject.md#role-casting
static func resolve(s: Variant, oid: StringName, danger: int = 1, sys: int = -1) -> Variant:
	var used := {}
	var out: Array = []
	var i := 0
	for st: Dictionary in stages_of(s):
		var st2: Dictionary = st.duplicate(true)
		st2.strobe_id = i if bool(st.get("strobe", false)) else -1
		i += 1
		if bool(st2.get("pick", false)) and (st2.get("pieces", []) as Array).size() > 1:
			var takes: Array = st2.pieces
			st2.pieces = [takes[pick_of(takes.size(), oid, sys)]]
		var ps: Array = st2.get("pieces", [])
		var dynamic := false
		for pid in ps:
			if _is_cast(StringName(pid)):
				dynamic = true
		if dynamic and st2.has("count") and int(st2.count) > ps.size() and not ps.is_empty():
			var grown: Array = []
			for k in int(st2.count):
				grown.append(ps[k % ps.size()])
			ps = grown
		var res: Array = []
		for pid in ps:
			res.append(_resolve_one(StringName(pid), oid, used, danger))
		if st2.has("pieces"):
			st2.pieces = res
		if st2.has("base"):
			st2.base = _resolve_one(StringName(st2.base), oid, used, danger)
		var ships: Array = st2.get("ships", [])
		for sh: Dictionary in ships:
			sh.piece = _resolve_one(StringName(sh.get("piece", &"")), oid, used, danger)
		out.append(st2)
	if s is Dictionary and (s as Dictionary).has("layers"):
		return {layers = out}
	return out[0] if not out.is_empty() else s


## Seeded from system, galaxy and encounter: the same take each visit, all takes seen overall.
static func pick_of(n: int, oid: StringName, sys: int) -> int:
	if n <= 1:
		return 0
	if force_pick >= 0:
		return force_pick % n
	if sys < 0:
		return 0
	var salt := absi(String(oid).hash()) % 100003
	var g := absi(Run.galaxy_seed) % 100003
	return mini(n - 1, int(LocalSky.SkyBakeS.hash2(sys * 7919 + g, salt) * float(n)))


static func _is_cast(id: StringName) -> bool:
	return String(id).begins_with("role:")


static func _resolve_one(id: StringName, oid: StringName, used: Dictionary, _danger: int) -> StringName:
	var k := String(id)
	if not k.begins_with("role:"):
		return id
	var role := k.substr(5)
	var ships := SubjectMask.role_ships(role)
	if ships.is_empty():
		return id
	var start := absi(("%s:%s" % [role, oid]).hash()) % ships.size()
	var n := int(used.get(role, 0))
	# the next one along not already in this encounter (two roles can share a
	# ship); the same one again only when the role has run out
	var drawn: Dictionary = used.get("_drawn", {})
	var pick := StringName(ships[(start + n) % ships.size()])
	for j in ships.size():
		var cand := StringName(ships[(start + n + j) % ships.size()])
		if not drawn.has(cand):
			pick = cand
			n += j
			break
	used[role] = n + 1
	drawn[pick] = true
	used["_drawn"] = drawn
	return pick


## A RING OF SHIPS HOLDING: round an ellipse, all facing the one way they hold
## (their own), the back half far, the front `near` of them at 1x.
static func _stage_ring(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 6))
	var rx := float(st.get("rx", 150.0))
	var ry := float(st.get("ry", 60.0))
	var near := int(st.get("near", 0))
	var made_near := 0
	var prior: Array = st.get("_prior", [])
	for i in n:
		var a := TAU * float(i) / float(n) + float(st.get("spin", 0.4))
		var front := sin(a) > 0.0
		var big := front and made_near < near
		var m := _m(_piece(st, i), Vector2(cos(a) * rx, sin(a) * ry).round(), 1.0 if big else 0.5,
			0.0 if big else (0.35 if front else 0.6), {z = 10 + i if front else -10 - i, flip = bool(st.get("flip", false))})
		# `roll`: each turning over slowly (degrees a second, give or take, every
		# other one the other way), a picture at a time (`_roll`)
		if st.has("roll"):
			m.roll = float(st.roll) * (0.6 + fmod(float(i) * 0.37, 0.8)) * (1.0 if i % 2 == 0 else -1.0)
			m.roll_step = float(st.get("roll_step", 15.0))
		if SubjectMask._clear(m, out + prior):
			out.append(m)
			if big:
				made_near += 1
	return out


## Each ship is placed where the subject says, with its own depth, turn and state.
static func _stage_group(st: Dictionary) -> Array:
	var out: Array = []
	var i := 0
	for sh: Dictionary in st.get("ships", []):
		var far := bool(sh.get("far", false))
		# `size`: a smaller ship at the same distance (its own half picture, not
		# dimmed) -- a small ship docked on a big hull, or sitting by it
		var sc := 0.5 if far else float(sh.get("size", 1.0))
		var m := _m(StringName(sh.get("piece", &"")), sh.get("at", Vector2.ZERO), sc, 0.55 if far else 0.0,
			{turn = float(sh.get("turn", 0.0)), z = int(sh.get("z", i)), flip = bool(sh.get("flip", st.get("flip", false)))})
		for k: String in SHIP_STATES:
			if sh.has(k):
				m[k] = sh[k]
		if sh.has("dock"):
			m.dock_to = int((sh.dock as Dictionary).get("to", 0))
		out.append(m)
		i += 1
	return out


## The pieces of one broken thing, each a little off the line and turned (Jon).
static func _stage_strewn(st: Dictionary) -> Array:
	var out: Array = []
	var ps: Array = st.get("pieces", [])
	var n := int(st.get("count", ps.size()))
	var lift: Array = st.get("lift", [])
	var turn: Array = st.get("turn", [])
	var gap := float(st.get("gap", 14.0))
	var far := bool(st.get("far", false))
	var sc := 0.5 if far else 1.0
	var ws: Array[float] = []
	var total := 0.0
	for i in n:
		var deg := float(turn[i % turn.size()]) if not turn.is_empty() else 0.0
		var w := SubjectMask.turned_size(SubjectMask.piece_size(_piece(st, i)), deg).x * sc
		ws.append(w)
		total += w
	var x := -(total + gap * sc * float(n - 1)) * 0.5
	for i in n:
		x += ws[i] * 0.5
		var deg := float(turn[i % turn.size()]) if not turn.is_empty() else 0.0
		var dy := float(lift[i % lift.size()]) * sc if not lift.is_empty() else 0.0
		out.append(_m(_piece(st, i), Vector2(roundf(x), dy), sc, 0.55 if far else 0.0, {turn = deg, z = i}))
		x += ws[i] * 0.5 + gap * sc
	return out


## The structure and its kept pieces, all pinned with it in its own pixels.
static func _stage_structure(st: Dictionary) -> Array:
	var id := _piece(st, 0)
	var p := SubjectMask.piece_info(id)
	var out: Array = [_m(id, Vector2.ZERO, 1.0, 0.0, {z = -100, structure = true, pinned = true, base_of = true})]
	# Points resolve on this structure's own parts, so each kept take uses its own berth.
	for k: String in ["add_lights", "lines", "parted", "grip"]:
		if not st.has(k):
			continue
		var v: Variant = st[k]
		if v is Array:
			var arr: Array = []
			for e: Dictionary in v:
				var e2 := e.duplicate()
				for key: String in ["at", "from"]:
					if e2.has(key):
						var q := _anchor_pt(p, e2[key], e2.get("off", null))
						e2[key] = [q.x, q.y]
				arr.append(e2)
			v = arr
		elif v is Dictionary:
			var d2 := (v as Dictionary).duplicate()
			if d2.has("from"):
				var q2 := _anchor_pt(p, d2.from, d2.get("off", null))
				d2.from = [q2.x, q2.y]
			if d2.has("at"):
				# (a clamp's arm leaves the structure from that part's own left edge)
				var q3 := _anchor_pt(p, d2.at, d2.get("off", null))
				d2.from_x = q3.x
				d2.from_y = q3.y
			v = d2
		out[0]["st_" + k] = v
	var c := Vector2(float(p.get("w", 0)), float(p.get("h", 0))) * 0.5
	var i := 0
	for w: Dictionary in st.get("with", []):
		var sc := float(w.get("scale", 1.0))
		var wm := _m(StringName(w.get("piece", &"")), (_anchor_pt(p, w.get("at", c), w.get("off", null)) - c).round(), sc,
			float(w.get("far", _far_of(sc))), {z = int(w.get("z", i)), pinned = true, on_base = true,
			swim = bool(w.get("swim", false)), tumble = float(w.get("tumble", 0.0)),
			flip = bool(w.get("flip", false)), turn = float(w.get("turn", 0.0)), with_i = i})
		for k: String in SHIP_STATES:
			if w.has(k):
				wm[k] = w[k]
		out.append(wm)
		i += 1
	# A LOOSE KNOT OF SMALL THINGS ON IT (`cluster`, see the header): each tried
	# up to 60 places in `rect`, kept where it is clear of all placed so far
	var cl: Dictionary = st.get("cluster", {})
	if not cl.is_empty():
		var R := RandomNumberGenerator.new()
		R.seed = int(cl.get("seed", 3))
		var rect: Rect2 = cl.get("rect", Rect2(Vector2.ZERO, c * 2.0))
		var sizes: Array = cl.get("size", [0.25, 0.4])
		var turns := float(cl.get("turns", 30.0))
		var ps: Array = cl.get("pieces", [])
		var placed: Array = []
		for k in int(cl.get("count", 6)):
			if ps.is_empty():
				break
			var pid := StringName(ps[k % ps.size()])
			for tries in 60:
				var sc := snappedf(R.randf_range(float(sizes[0]), float(sizes[1])), 0.05)
				var at := rect.position + Vector2(R.randf() * rect.size.x, R.randf() * rect.size.y)
				var m := _m(pid, (at - c).round(), sc, 0.0, {z = i + k, pinned = true, on_base = true,
					swim = true, tumble = float(cl.get("tumble", 3.0)), flip = R.randf() < 0.5,
					turn = roundf(R.randf_range(-turns, turns))})
				if SubjectMask._clear(m, placed + out.slice(1)):
					placed.append(m)
					break
		out.append_array(placed)
	return out


## A point is raw pixels or a named `anchors` part, plus `off`.
static func _anchor_pt(p: Dictionary, v: Variant, off: Variant = null) -> Vector2:
	var q := Vector2.ZERO
	if v is String or v is StringName:
		var a: Array = (p.get("anchors", {}) as Dictionary).get(String(v), [0, 0])
		q = Vector2(float(a[0]), float(a[1]))
	elif v is Vector2:
		q = v
	elif v is Array and (v as Array).size() >= 2:
		q = Vector2(float(v[0]), float(v[1]))
	if off is Vector2:
		q += off
	elif off is Array and (off as Array).size() >= 2:
		q += Vector2(float(off[0]), float(off[1]))
	return q


## Planned at a giant's usual size so a stage stood on it can be placed before drawing.
static func near_r() -> float:
	return float((LocalSky.NEAR_SIZES.get(LocalSky.near_size, LocalSky.NEAR_SIZES[&"large"]) as Dictionary).giant) * 0.86


## Planned with the giant at its usual size, drawn where the giant really is (`_ring_point`).
## Why: docs/why/LocalSubject.md#ring-arc
static func _stage_ring_arc(st: Dictionary) -> Array:
	var out: Array = []
	var us: Array = st.get("u", [-0.6, 0.6])
	var lifts: Array = st.get("lift", [0.0])
	var sc := float(st.get("size", 0.25))
	for i in us.size():
		var u := float(us[i])
		var lift := float(lifts[i % lifts.size()])
		var m := _m(_piece(st, i), ring_point(u, lift, near_r(), 1.5, 2.2, 0.28).round(), sc, float(st.get("far", 0.3)),
			{z = i, flip = u > 0.0 if not st.has("flip") else bool(st.flip), ring_u = u, ring_lift = lift})
		out.append(m)
	return out


## A point on a ring's far arc, squashed to `open`, measured from the world's centre.
static func ring_point(u: float, lift: float, r: float, rin: float, rout: float, open: float) -> Vector2:
	var rho := (rin + rout) * 0.5 * r
	return Vector2(u * rho, -open * rho * sqrt(maxf(0.0, 1.0 - u * u)) + lift)


## The structure of a planned staging, or {}.
static func structure_in(planned: Array) -> Dictionary:
	for m: Dictionary in planned:
		if bool(m.get("structure", false)):
			return m
	return {}


## Whether a subject is staged round a big structure.
static func has_structure(s: Variant) -> bool:
	for st: Dictionary in stages_of(s):
		if StringName(st.get("stage", &"")) == &"structure":
			return true
	return false


## The picture's rect: right edge `over` px past the view, `anchor` row level with your ship.
static func structure_rect(id: StringName, view_size: Vector2, ship_y: float) -> Rect2:
	return _structure_rect_of(SubjectMask.piece_info(id), view_size, ship_y)


static func _structure_rect_of(p: Dictionary, view_size: Vector2, ship_y: float) -> Rect2:
	var w := float(p.get("w", 0))
	var h := float(p.get("h", 0))
	var at := Vector2(view_size.x + float(p.get("over", 1)) - w, ship_y - float(p.get("anchor", h * 0.5)))
	return Rect2(at.round(), Vector2(w, h))


## The box's own pieces' bounds (a stage stood on the sky is placed from that).
static func box_bounds(planned: Array) -> Rect2:
	var b := Rect2()
	var first := true
	for m: Dictionary in planned:
		if StringName(m.get("anchor", &"")) != &"":
			continue
		var r := rect_of(m)
		b = r if first else b.merge(r)
		first = false
	return b
