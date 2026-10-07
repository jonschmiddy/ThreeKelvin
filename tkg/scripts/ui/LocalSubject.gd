class_name LocalSubject
extends Control

## WHAT AN ENCOUNTER IS ABOUT, IN LOCAL'S SCENE (Jon: LOCAL scenes "rich and
## unique"; the audit, scratchpad `local_role/subjects.md`). An option in
## `OptionTable` may carry a `subject`: which kept pieces of art, and how they are
## staged -- one crate, six tanks on a tether, nine of them in a line, a field of
## mines, a herd round a body of ice, containers clamped to a rock in rows. While
## that event is open on LOCAL, and while you are parked where it stands, this
## draws it: on the subject side, right of centre and opposite your ship, at the
## ships' own pixel scale, above the event's band, behind the hulls.
##
## GROUNDED, NOT PASTED ON ("ground what you draw over the scene"): every piece is
## lit from the system's star side and shaded on its far side in steps, its
## star-facing edge caught in the star's colour, far ones dimmed toward the sky,
## and pulled toward the system's own palette where LOCAL has one
## (`local_subject.gdshader`); PAINTED steps its light harder instead. The rocks
## and the ice moon are not sprites: the planet painter draws them (`PlanetView`,
## lit by the star like any world), cut to a lumpy outline as the approved
## samples were.
##
## ONLY GENTLE MOTION: pieces drift a few pixels and turn a degree or two over
## many seconds, creatures swim as slowly, a tumbling pod tumbles slowly.
## Nothing here moves fast, and nothing at all under reduced motion.
##
## CONTENT IS DATA. The staging kinds are the code (`_stage_*`); which pieces,
## how many and where are the option's `subject` (see `OptionTable`), and the art
## is `art/subjects/` with its `index.json` (`tools`: the scratchpad's
## `sync_subjects.py` copies Jon's KEEPs in).
##
## A `subject` is one stage, or `{layers = [stage, ...]}` drawn back to front.
## A stage:
##   stage   single | row | tether | field | herd | line | around | on_rock | strewn
##   pieces  piece ids from the index, cycled
##   count   how many (row, tether, field, herd, line, around, on_rock)
##   at      offset of this stage from the subject's centre, px
##   r       a painter piece's radius, px (else the recipe's own)
##   base    a painter rock or moon the stage sits on or round (around, on_rock)
##   span    how far it runs, px (row, tether, line, herd, field)
##   near    how many of a row/herd/line/field are near (1x); the rest are far
##           (half scale, dimmed toward the sky)
##   seed    the scatter's seed
##   tumble  a slow tumble, degrees (single)
##   lift    strewn: each piece's offset down (+) or up (-) from the line, px
##   turn    strewn: each piece's turn, degrees -- turned once when it is built,
##           pixel for pixel (`turned`), never turned on screen, so it does not
##           shimmer; it only drifts
##   gap     strewn: the air between neighbours, px
##   far     strewn: the whole stage far (half size, dimmed toward the sky)

const INDEX_PATH := "res://art/subjects/index.json"
const SHADER := preload("res://shaders/local_subject.gdshader")
## The event's band on LOCAL (`LocalEventDrawer.H`) and the air kept round the
## subject's box.
const BAND := 190.0
const PAD := 10.0
## The air kept between the subject and a wreck left by a fight here.
const WRECK_GAP := 8.0

static var _index: Dictionary = {}
## Pieces turned at load (`turned`), by "id:degrees".
static var _turned: Dictionary = {}

## Which option this draws, at which system (so a refresh only rebuilds when it
## changes).
var key := ""
var subject: Variant = null
var sky: LocalSky = null
## The placed pieces: [{node, base pos, scale, far, drift, spin, phase, sprite?,
## planet?}]
var _placed: Array = []
var _tethers: Array = []
var _box := Rect2()
## the planned staging's own bounds, so its middle (not its origin) sits in the
## middle of the box
var _bounds := Rect2()
var _pal_set := false
## The size the staging is drawn at (`fit`): 1x, or half when it has to keep
## clear of the wrecks a fight left and only fits small.
var _scale := 1.0
## LOCAL's drawn place, held hidden while this is up (see `_process`)
var _area: Control = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --------------------------------------------------------------- the index

static func index() -> Dictionary:
	if _index.is_empty():
		var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_index = (d as Dictionary).get("pieces", {})
	return _index


static func has_piece(id: StringName) -> bool:
	return index().has(String(id))


## A piece's size on screen at scale 1, px (a painter piece's from its radius).
static func piece_size(id: StringName, r: float = 0.0) -> Vector2:
	var p: Dictionary = index().get(String(id), {})
	if p.is_empty():
		return Vector2.ZERO
	if String(p.get("kind", "")) == "painter":
		var rr := r if r > 0.0 else float(p.get("r", 40))
		var k := rr / float(p.get("r", 40))
		return Vector2(float(p.w), float(p.h)) * k
	return Vector2(float(p.w), float(p.h))


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
	return Rect2(x0, 36.0, view_size.x - x0 - 14.0, view_size.y - BAND - 36.0 - PAD)


## THE STAGING, worked out without drawing anything: every piece as
## {id, at (centre, px from the subject's centre), scale, far, r, flip, kind}.
## Deterministic, so a test can check it fits without a screen.
static func plan(s: Variant) -> Array:
	var out: Array = []
	for st: Dictionary in stages_of(s):
		var at: Vector2 = st.get("at", Vector2.ZERO)
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
		for m: Dictionary in made:
			m.at = (m.at as Vector2) + at
			out.append(m)
	# far first, near last
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.far) > float(b.far) if not is_equal_approx(float(a.far), float(b.far)) else int(a.get("z", 0)) < int(b.get("z", 0)))
	return out


## The rect a planned piece covers, px from the subject's centre.
static func rect_of(m: Dictionary) -> Rect2:
	var sz := turned_size(piece_size(StringName(m.id), float(m.get("r", 0.0))), float(m.get("turn", 0.0))) * float(m.scale)
	return Rect2((m.at as Vector2) - sz * 0.5, sz)


## The box a `sz` picture needs once turned `deg` degrees.
static func turned_size(sz: Vector2, deg: float) -> Vector2:
	if is_zero_approx(deg):
		return sz
	var a := deg_to_rad(deg)
	var c := absf(cos(a))
	var sn := absf(sin(a))
	return Vector2(ceilf(sz.x * c + sz.y * sn), ceilf(sz.x * sn + sz.y * c))


static func bounds_of(planned: Array) -> Rect2:
	var b := Rect2()
	for i in planned.size():
		var r := rect_of(planned[i])
		b = r if i == 0 else b.merge(r)
	return b


static func _piece(st: Dictionary, i: int) -> StringName:
	var ps: Array = st.get("pieces", [])
	return StringName(ps[i % ps.size()]) if not ps.is_empty() else &""


static func _m(id: StringName, at: Vector2, sc: float = 1.0, far: float = 0.0, extra: Dictionary = {}) -> Dictionary:
	var d := {id = id, at = at, scale = sc, far = far, r = 0.0, flip = false, z = 0}
	d.merge(extra, true)
	return d


static func _stage_single(st: Dictionary) -> Array:
	return [_m(_piece(st, 0), Vector2.ZERO, 1.0, 0.0, {r = float(st.get("r", 0.0)), tumble = float(st.get("tumble", 0.0))})]


## A line receding: the nearest at 1x in front, the rest far, along `dir`.
static func _stage_row(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 3))
	var near := int(st.get("near", n))
	var span := float(st.get("span", 300.0))
	var dir: Vector2 = st.get("dir", Vector2(1.0, -0.3))
	dir = dir.normalized()
	for i in n:
		var t := (float(i) / maxf(float(n - 1), 1.0)) - 0.5
		var far := i >= near
		out.append(_m(_piece(st, i), dir * span * t, 0.5 if far else 1.0, 0.6 if far else 0.0, {z = -i}))
	return out


## A tether: pieces hung at even steps on a line that sags a little, between two
## ends (painter rocks, or bare).
static func _stage_tether(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 6))
	var span := float(st.get("span", 320.0))
	var sag := float(st.get("sag", 18.0))
	var tilt := float(st.get("tilt", -0.12))
	var ends: Array = st.get("ends", [])
	var er := float(st.get("r", 34.0))
	for k in ends.size():
		var x := (-0.5 if k == 0 else 0.5) * span
		out.append(_m(StringName(ends[k]), Vector2(x, x * tilt), 1.0, 0.0, {r = er, z = -1, tether = true}))
	var inner := span - (er * 2.4 if not ends.is_empty() else 0.0)
	# (the first `near` at 1x, the rest half size and dimmed, receding along it:
	# six tanks a hundred pixels long do not hang in a line four hundred wide)
	var near := int(st.get("near", n))
	var ws: Array[float] = []
	var total := 0.0
	for i in n:
		var w := piece_size(_piece(st, i)).x * (1.0 if i < near else 0.5)
		ws.append(w)
		total += w
	var gap := maxf((inner - total) / maxf(float(n - 1), 1.0), 4.0)
	var x := -(total + gap * float(n - 1)) * 0.5
	for i in n:
		x += ws[i] * 0.5
		var t := x / maxf(inner, 1.0)
		var y := x * tilt + sag * (1.0 - 4.0 * t * t)
		var far := i >= near
		out.append(_m(_piece(st, i), Vector2(x, y), 0.5 if far else 1.0, 0.55 if far else 0.0, {tether = true, z = i}))
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
	var taken: Array[Rect2] = []
	for i in n:
		var far := i >= near
		var id := _piece(st, i)
		var sc := 0.5 if far else 1.0
		var sz := piece_size(id) * sc
		var at := Vector2.ZERO
		for tries in 40:
			var a := R.randf() * TAU
			var rr := sqrt(R.randf())
			at = Vector2(cos(a) * span * 0.5 * rr, sin(a) * hgt * 0.5 * rr)
			# clear of what is already placed at the same depth
			var r := Rect2(at - sz * 0.5, sz).grow(3.0)
			var clash := false
			for q in taken:
				if q.intersects(r):
					clash = true
					break
			if not clash or tries == 39:
				# kept inside the field's own ellipse box
				at.x = clampf(at.x, -span * 0.5 + sz.x * 0.5, span * 0.5 - sz.x * 0.5)
				at.y = clampf(at.y, -hgt * 0.5 + sz.y * 0.5, hgt * 0.5 - sz.y * 0.5)
				taken.append(Rect2(at - sz * 0.5, sz))
				break
		out.append(_m(id, at, sc, 0.55 if far else 0.0, {flip = R.randf() < 0.5, tumble = float(st.get("tumble", 4.0)), z = i}))
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
		var sz := piece_size(id) * sc
		var x := 0.0
		var y := 0.0
		if far:
			x = lerpf(-span * 0.5 + sz.x * 0.5, span * 0.5 - sz.x * 0.5, (float(i - near) + 0.5) / maxf(float(n - near), 1.0)) + R.randf_range(-10.0, 10.0)
			y = -hgt * 0.5 + sz.y * 0.5 + R.randf_range(0.0, hgt * 0.35)
		else:
			x = lerpf(-span * 0.5 + sz.x * 0.5, span * 0.5 - sz.x * 0.5, (float(i) + 0.5) / maxf(float(near), 1.0))
			y = hgt * 0.5 - sz.y * 0.5 - R.randf_range(0.0, hgt * 0.2)
		x = clampf(x, -span * 0.5 + sz.x * 0.5, span * 0.5 - sz.x * 0.5)
		y = clampf(y, -hgt * 0.5 + sz.y * 0.5, hgt * 0.5 - sz.y * 0.5)
		out.append(_m(id, Vector2(x, y), sc, 0.55 if far else 0.0, {swim = true, flip = bool(st.get("flip", false)), z = i}))
	return out


## A line of them crossing, receding: one near, the rest far along a shallow
## diagonal.
static func _stage_line(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 9))
	var near := int(st.get("near", 1))
	var span := float(st.get("span", 380.0))
	var rise := float(st.get("rise", -90.0))
	for i in n:
		var far := i >= near
		var id := _piece(st, i)
		var t := float(i) / maxf(float(n - 1), 1.0)
		out.append(_m(id, Vector2(lerpf(-span * 0.5, span * 0.5, t), lerpf(rise * -0.5, rise * 0.5, t)), 0.5 if far else 1.0, 0.55 if far else 0.0, {swim = true, flip = bool(st.get("flip", false)), z = -i}))
	return out


## Round a body: the body in the middle; the creatures behind it far, the ones
## in front near.
static func _stage_around(st: Dictionary) -> Array:
	var out: Array = []
	var base := StringName(st.get("base", &""))
	var r := float(st.get("r", 56.0))
	out.append(_m(base, Vector2.ZERO, 1.0, 0.0, {r = r, z = 0}))
	var n := int(st.get("count", 5))
	var rx := float(st.get("rx", r + 70.0))
	var ry := float(st.get("ry", r * 0.55))
	for i in n:
		var a := TAU * float(i) / float(n) + 0.6
		var front := sin(a) > 0.0
		var id := _piece(st, i)
		out.append(_m(id, Vector2(cos(a) * rx, sin(a) * ry), 1.0 if front else 0.5, 0.0 if front else 0.55,
			{swim = true, flip = cos(a) > 0.0, z = 10 + i if front else -10 - i}))
	return out


## On a rock: the rock, and pieces on its face in rows, clamps between them.
static func _stage_on_rock(st: Dictionary) -> Array:
	var out: Array = []
	var base := StringName(st.get("base", &""))
	var r := float(st.get("r", 80.0))
	out.append(_m(base, Vector2.ZERO, 1.0, 0.0, {r = r, z = 0}))
	var rows := int(st.get("rows", 1))
	var cols := int(st.get("count", 1))
	var gap: Vector2 = st.get("gap", Vector2(56.0, 46.0))
	var clamp_id := StringName(st.get("clamp", &""))
	var face: Vector2 = st.get("face", Vector2.ZERO)
	for y in rows:
		for x in cols:
			var p := face + Vector2((float(x) - float(cols - 1) * 0.5) * gap.x, (float(y) - float(rows - 1) * 0.5) * gap.y)
			out.append(_m(_piece(st, y * cols + x), p, 1.0, 0.0, {z = 1 + y * cols + x}))
			if clamp_id != &"" and x < cols - 1:
				out.append(_m(clamp_id, p + Vector2(gap.x * 0.5, 0.0), 1.0, 0.0, {z = 100 + y * cols + x}))
	return out


## Strewn: the pieces of one broken thing, left to right in their own order,
## each a little up or down and turned a little its own way (Jon on the snapped
## truss: "Let's have these not in a perfect line."), drifting on their own slow
## clocks.
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
		var w := turned_size(piece_size(_piece(st, i)), deg).x * sc
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


## A PICTURE TURNED PIXEL FOR PIXEL: every pixel of the turned box takes the
## nearest pixel of the original, so the turn is made once, cleanly, and nothing
## on screen ever rotates (a sprite turned live on nearest filtering ripples:
## "turn pixel art in whole-pixel steps").
static func turned(id: StringName, tex: Texture2D, deg: float) -> Texture2D:
	var k := "%s:%s" % [id, deg]
	if _turned.has(k):
		return _turned[k]
	var src := tex.get_image()
	if src == null:
		return tex
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var sw := src.get_width()
	var sh := src.get_height()
	var out_sz := turned_size(Vector2(sw, sh), deg)
	var ow := int(out_sz.x)
	var oh := int(out_sz.y)
	var img := Image.create(ow, oh, false, Image.FORMAT_RGBA8)
	var a := deg_to_rad(deg)
	var c := cos(a)
	var sn := sin(a)
	var ocx := float(ow) * 0.5
	var ocy := float(oh) * 0.5
	var scx := float(sw) * 0.5
	var scy := float(sh) * 0.5
	for y in oh:
		for x in ow:
			# back from the turned box into the original
			var dx := float(x) + 0.5 - ocx
			var dy := float(y) + 0.5 - ocy
			var sx := floori(dx * c + dy * sn + scx)
			var sy := floori(-dx * sn + dy * c + scy)
			if sx >= 0 and sy >= 0 and sx < sw and sy < sh:
				img.set_pixel(x, y, src.get_pixel(sx, sy))
	var t := ImageTexture.create_from_image(img)
	_turned[k] = t
	return t


## WHERE THE STAGING GOES AND HOW BIG: its middle in the middle of `box`, at 1x,
## unless something it must not cover is in the box (`avoid`: the wrecks a
## fight left here, which keep their places because each is a door -- click it
## and its hold opens). Then it takes the biggest stretch of the box left clear
## above, left or right of them (below them are their names, then the band), at
## 1x if it fits there and at half size, dimmed as far off, if only that does.
## {centre (where the staging's own origin goes), scale, clear (the stretch)}.
static func fit(box: Rect2, bounds: Rect2, avoid: Array[Rect2]) -> Dictionary:
	var u := Rect2()
	var any := false
	for r in avoid:
		var g := r.grow(WRECK_GAP)
		if not g.intersects(box):
			continue
		u = g if not any else u.merge(g)
		any = true
	if not any:
		return {centre = (box.get_center() - bounds.get_center()).round(), scale = 1.0, clear = box}
	var spaces: Array[Rect2] = []
	for r: Rect2 in [Rect2(box.position.x, box.position.y, box.size.x, u.position.y - box.position.y),
			Rect2(box.position.x, box.position.y, u.position.x - box.position.x, box.size.y),
			Rect2(u.end.x, box.position.y, box.end.x - u.end.x, box.size.y)]:
		if r.size.x > 0.0 and r.size.y > 0.0:
			spaces.append(r)
	for sc: float in [1.0, 0.5]:
		var best := Rect2()
		for r in spaces:
			if bounds.size.x * sc <= r.size.x and bounds.size.y * sc <= r.size.y and r.get_area() > best.get_area():
				best = r
		if best.get_area() > 0.0:
			return {centre = (best.get_center() - bounds.get_center() * sc).round(), scale = sc, clear = best}
	# nothing clear holds it even at half size: the biggest stretch, at half
	var big := box
	var area := -1.0
	for r in spaces:
		if r.get_area() > area:
			area = r.get_area()
			big = r
	return {centre = (big.get_center() - bounds.get_center() * 0.5).round(), scale = 0.5, clear = big}


## The wrecks on LOCAL's view now, in this control's own space.
func _wrecks() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var view := get_parent()
	if view == null or not (view.get("_slots") is Control):
		return out
	var slots: Control = view.get("_slots")
	if not slots.is_visible_in_tree() or view.get("_slots_mode") != &"wrecks":
		return out
	var inv := get_global_transform().affine_inverse()
	for e: Variant in view.get("_made"):
		if e is EnemySlot and is_instance_valid(e) and (e as EnemySlot).is_visible_in_tree():
			out.append(inv * (e as EnemySlot).holder_rect())
	return out


# --------------------------------------------------------------- on LOCAL

## Keep the right subject on LOCAL's view: the event open there, or the one you
## are parked at; none in a fight. Called from `SectorScreen._refresh`.
static func sync(view: Control, n: MapGen.MapNode, fighting: bool) -> LocalSubject:
	var cur: LocalSubject = null
	for c in view.get_children():
		if c is LocalSubject:
			cur = c
	var opt := -1
	if n != null and not fighting:
		opt = LocalEventDrawer.bar_option(n)
	var s: Variant = null
	if opt >= 0:
		s = OptionTable.by_id(n.options[opt]).get("subject", null)
	var want := ("%d:%d" % [n.index, opt]) if s != null else ""
	# THE SUBJECT TAKES THE PLACE'S STAND-IN: LOCAL's drawn place (its beacon,
	# its plate) stands where the subject goes, and two things in one spot is a
	# muddle; without a subject the view shows it as it always has
	if cur != null and cur.key == want:
		return cur
	if cur != null:
		cur.queue_free()
		cur = null
	if want == "":
		return null
	cur = LocalSubject.new()
	cur.key = want
	cur.subject = s
	cur.sky = view.get("backdrop") as LocalSky
	var area: Variant = view.get("_area")
	cur._area = area as Control if area is Control else null
	view.add_child(cur)
	# in the scene's depth: in front of the sky and its weather, behind the hulls
	var w: Variant = view.get("weather")
	var at := ((w as Node).get_index() + 1) if w is Node else 1
	view.move_child(cur, at)
	cur._build()
	return cur


## The subject on a view, if one is drawn there.
static func of(view: Control) -> LocalSubject:
	for c in view.get_children():
		if c is LocalSubject and not (c as Node).is_queued_for_deletion():
			return c
	return null


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_placed.clear()
	_tethers.clear()
	_pal_set = false
	var planned := plan(subject)
	_bounds = bounds_of(planned)
	var painted := LocalSky.style_now() == &"painted"
	for m: Dictionary in planned:
		var id := StringName(m.id)
		var p: Dictionary = index().get(String(id), {})
		if p.is_empty():
			continue
		var holder := Node2D.new()
		add_child(holder)
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		spr.flip_h = bool(m.flip)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("far", float(m.far))
		mat.set_shader_parameter("stepped", painted)
		spr.material = mat
		holder.add_child(spr)
		var turn := float(m.get("turn", 0.0))
		var rec := {node = holder, sprite = spr, mat = mat, at = m.at, scale = float(m.scale), far = float(m.far),
			swim = bool(m.get("swim", false)), tumble = float(m.get("tumble", 0.0)), tether = bool(m.get("tether", false)),
			phase = float(_placed.size()) * 1.731, planet = null, turn = deg_to_rad(turn)}
		if String(p.get("kind", "")) == "painter":
			_painter(rec, p, float(m.get("r", 0.0)))
		else:
			var tex := load(String(p.file)) as Texture2D
			spr.texture = turned(id, tex, turn) if not is_zero_approx(turn) and tex != null else tex
		spr.scale = Vector2.ONE * float(m.scale)
		_placed.append(rec)
		if rec.tether:
			_tethers.append(rec)
	_layout()


## A ROCK OR A MOON FROM THE PLANET PAINTER: a PlanetView in a viewport of its
## own, lit each frame from the star, shown through a mask cut to the recipe's
## lumpy lobes with the cut darkened (a moon is the whole disc).
func _painter(rec: Dictionary, p: Dictionary, r: float) -> void:
	var r0 := float(p.r)
	var k := (r / r0) if r > 0.0 else 1.0
	var w := int(roundf(float(p.w) * k))
	var h := int(roundf(float(p.h) * k))
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var pv := PlanetView.new()
	pv.position = Vector2(roundf(float(p.cx) * k), roundf(float(p.cy) * k))
	vp.add_child(pv)
	pv.set_world(StringName(p.world), int(p.seed), r0 * k)
	var spr: Sprite2D = rec.sprite
	spr.texture = vp.get_texture()
	var mat: ShaderMaterial = rec.mat
	mat.set_shader_parameter("lit", 0.0)
	mat.set_shader_parameter("shade", 0.0)
	var lobes: Array = p.get("lobes", [])
	if not lobes.is_empty():
		mat.set_shader_parameter("use_mask", true)
		mat.set_shader_parameter("mask", ImageTexture.create_from_image(lumpy_mask(w, h, k, p)))
	rec.planet = pv


## The recipe's lumpy outline as a mask: R inside, G the cut's dark rim -- the
## samples' `lumpy` / `cut` (a radius wandering with angle on two octaves of
## noise; two lobes fused at a waist into one body, the rim only outside it).
static func lumpy_mask(w: int, h: int, k: float, p: Dictionary) -> Image:
	var lobes: Array = p.get("lobes", [])
	var waist: Array = p.get("waist", [])
	var lo := float(p.get("lo", 0.72))
	var amp := float(p.get("amp", 0.32))
	var inside := PackedByteArray()
	inside.resize(w * h)
	for y in h:
		for x in w:
			var X := float(x) / k
			var Y := float(y) / k
			var hit := false
			for L: Array in lobes:
				var dx := X - float(L[0])
				var dy := Y - float(L[1])
				var a := atan2(dy, dx)
				var rr := float(L[2]) * (lo + amp * _fbm(cos(a) * 1.7 + float(L[3]), sin(a) * 1.7 + float(L[3]) * 2.1))
				if sqrt(dx * dx + dy * dy) < rr:
					hit = true
					break
			if not hit and waist.size() == 5:
				var x0 := float(waist[0])
				var y0 := float(waist[1])
				var x1 := float(waist[2])
				var y1 := float(waist[3])
				var t := clampf(((X - x0) * (x1 - x0) + (Y - y0) * (y1 - y0)) / ((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)), 0.0, 1.0)
				var px := x0 + (x1 - x0) * t
				var py := y0 + (y1 - y0) * t
				if Vector2(X - px, Y - py).length() < float(waist[4]) * (0.8 + 0.4 * _fbm(X / 30.0, Y / 30.0)):
					hit = true
			inside[y * w + x] = 1 if hit else 0
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if inside[y * w + x] == 0:
				continue
			var edge := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var X2 := x + dx
					var Y2 := y + dy
					if X2 < 0 or Y2 < 0 or X2 >= w or Y2 >= h or inside[Y2 * w + X2] == 0:
						edge = true
			img.set_pixel(x, y, Color(1.0, 1.0 if edge else 0.0, 0.0, 1.0))
	return img


## Value noise, two octaves -- the samples' `fbm2`, near enough: a lumpy outline,
## not the same lumps.
static func _fbm(x: float, y: float) -> float:
	var v := 0.0
	var a := 0.5
	var f := 1.0
	for o in 3:
		v += a * _vnoise(x * f, y * f)
		f *= 2.0
		a *= 0.5
	return v / 0.875


static func _vnoise(x: float, y: float) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - float(ix)
	var fy := y - float(iy)
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_h2(ix, iy), _h2(ix + 1, iy), ux), lerpf(_h2(ix, iy + 1), _h2(ix + 1, iy + 1), ux), uy)


static func _h2(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Where the subject's centre is: the middle of its box, nudged so its whole
## planned bounds sit inside the box.
func _layout() -> void:
	_box = box_for(size)
	queue_redraw()


func _clock() -> float:
	if ShipView.shot_clock >= 0.0:
		return ShipView.shot_clock
	return float(Time.get_ticks_msec()) / 1000.0


func _process(_d: float) -> void:
	# THE SUBJECT TAKES THE PLACE'S STAND-IN: LOCAL's drawn place (its beacon,
	# its plate) stands where the subject goes, and two things in one spot is a
	# muddle. Held every frame, because the view's own refresh shows it again
	# after this has been built; gone with this, the view shows it as it always has.
	if _area != null and is_instance_valid(_area) and _area.visible:
		_area.visible = false
	if _placed.is_empty():
		return
	var t := 0.0 if DisplaySettings.reduced_motion else _clock()
	# out of the way of any wreck a fight left here (`fit`)
	var f := fit(_box, _bounds, _wrecks())
	var centre: Vector2 = f.centre
	if not is_equal_approx(float(f.scale), _scale):
		_scale = float(f.scale)
		for rec: Dictionary in _placed:
			(rec.sprite as Sprite2D).scale = Vector2.ONE * float(rec.scale) * _scale
			# made small to keep clear, so seen as further off
			(rec.mat as ShaderMaterial).set_shader_parameter("far", maxf(float(rec.far), 0.45) if _scale < 1.0 else float(rec.far))
	var star := Vector2(-1e6, -1e6)
	var tint := Vector3.ONE
	if sky != null and is_instance_valid(sky):
		star = sky.get_global_transform() * sky.origin()
		tint = sky.star_light()
		if not _pal_set and sky._palette_mat != null:
			var pn := int(sky._palette_mat.get_shader_parameter("pal_n"))
			if pn > 0:
				_pal_set = true
				var pal: Variant = sky._palette_mat.get_shader_parameter("pal")
				for rec: Dictionary in _placed:
					(rec.mat as ShaderMaterial).set_shader_parameter("pal", pal)
					(rec.mat as ShaderMaterial).set_shader_parameter("pal_n", pn)
	var star_col := Vector3(0.55, 0.55, 0.55) + tint * 0.45
	for rec: Dictionary in _placed:
		var ph: float = rec.phase
		var off := Vector2.ZERO
		var rot := 0.0
		var amp := (3.0 if float(rec.far) > 0.0 else 5.0) * _scale
		if bool(rec.swim):
			off = Vector2(sin(t * TAU / 26.0 + ph) * amp * 1.6, sin(t * TAU / 17.0 + ph * 1.3) * 2.0)
		else:
			off = Vector2(sin(t * TAU / 31.0 + ph) * amp * 0.5, sin(t * TAU / 23.0 + ph * 0.7) * amp * 0.4)
		if float(rec.tumble) > 0.0:
			rot = deg_to_rad(sin(t * TAU / 37.0 + ph) * float(rec.tumble))
		if bool(rec.tether):
			off = Vector2(0.0, sin(t * TAU / 29.0 + ph * 0.3) * 1.5)
		var node: Node2D = rec.node
		node.position = (centre + (rec.at as Vector2) * _scale + off).round()
		node.rotation = rot
		var g := node.get_global_transform()
		var dirv := star - g.origin
		var ts := dirv.normalized() if dirv.length() > 1.0 else Vector2(-1.0, -0.4).normalized()
		var spr: Sprite2D = rec.sprite
		var local := ts.rotated(-rot - float(rec.turn))
		if spr.flip_h:
			local.x = -local.x
		var mat: ShaderMaterial = rec.mat
		mat.set_shader_parameter("to_star", local)
		mat.set_shader_parameter("star_col", star_col)
		if rec.planet != null:
			var pv: PlanetView = rec.planet
			pv.step(t, Vector3(ts.x, ts.y, 0.47), 1.0)
	queue_redraw()


## THE TETHER: a dark line through the hung pieces, one pixel, from end to end.
func _draw() -> void:
	if _tethers.size() < 2:
		return
	var pts := PackedVector2Array()
	for rec: Dictionary in _tethers:
		pts.append((rec.node as Node2D).position)
	if pts.size() >= 2:
		var sorted := Array(pts)
		sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		for i in sorted.size() - 1:
			draw_line(sorted[i], sorted[i + 1], Color(0.09, 0.1, 0.12, 0.9), 1.0)


## Every placed piece's rect on screen, for the harnesses.
func drawn_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rec: Dictionary in _placed:
		var spr: Sprite2D = rec.sprite
		if spr.texture == null:
			continue
		var sz := spr.texture.get_size() * float(rec.scale) * _scale
		var c := (rec.node as Node2D).get_global_transform().origin
		out.append(Rect2(c - sz * 0.5, sz))
	return out
