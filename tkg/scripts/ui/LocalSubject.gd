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
##           | ring | group
##   pieces  piece ids from the index, cycled; or `role:<name>` (a kept pool
##           ship of that role, the same one for this encounter every time:
##           `resolve`), or `foe` (the ship the event's fight would bring)
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
##   ships   group: [{piece, at, far?, turn?} + any of the ship states below],
##           each placed where it says
##   rx, ry  ring: the ellipse the ships hold, px; the back half far
## A SHIP'S STATE, on a stage (every piece in it) or on one ship of a group:
##   dark    0..1, cold: no heat, no lights, lit only by the star
##   lights  &"run" (running lights) | &"battery" (a few dim ones, breathing) |
##           &"patrol" (red and blue, turn about)
##   drive   its drive lit at the stern
##   flood   a floodlight from its bow, on you
##   tow     a slack tow line off its bow, px long
## And on a stage: `strobe` (a light run along the line of its ships).
## Lights, drives, floods and strobes are drawn in code over the art, as light
## (gathered, stepped and dithered, eased), never painted on the pictures.

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
## Which kept pool ships each role may be (`index.json` "roles").
static var _roles: Dictionary = {}
## The fight's ships, as `EnemyArt` draws them: {"foe:<id>": {tex, w, h, anchors}}
static var _foes: Dictionary = {}
## Glows for the lights, by "radius:colour".
static var _glows: Dictionary = {}
## For a test: the fight's ship to stage instead of the one the fight would bring.
static var foe_override: StringName = &""

## Which option this draws, at which system (so a refresh only rebuilds when it
## changes).
var key := ""
var subject: Variant = null
## The encounter it is (its ships are picked by it) and the system's danger
## (which fight it would bring).
var oid: StringName = &""
var danger := 1
## What it drew, piece by piece, once resolved (the fight's ship as `foe:<id>`).
var cast: Array[StringName] = []
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
## The pieces each `strobe` stage runs its light along, by stage.
var _strobes: Dictionary = {}
## Where the lights are drawn (additive, over the pieces).
var _over: Node2D = null
var _t := 0.0
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
				_roles = (d as Dictionary).get("roles", {})
	return _index


## The kept pool ships a role may be, by piece id.
static func role_ships(role: String) -> Array:
	index()
	return _roles.get(role, [])


## A piece's record: the index's, or for the fight's own ship (`foe:<id>`) one
## made from `EnemyArt`'s drawing of it.
static func piece_info(id: StringName) -> Dictionary:
	var k := String(id)
	if k.begins_with("foe:"):
		return _foe(StringName(k.substr(4)))
	return index().get(k, {})


static func has_piece(id: StringName) -> bool:
	return not piece_info(id).is_empty()


## A piece's size on screen at scale 1, px (a painter piece's from its radius).
static func piece_size(id: StringName, r: float = 0.0) -> Vector2:
	var p: Dictionary = piece_info(id)
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
static func plan(s: Variant, oid: StringName = &"", danger: int = 1) -> Array:
	var out: Array = []
	for st: Dictionary in stages_of(resolve(s, oid, danger)):
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
			&"ring":
				made = _stage_ring(st)
			&"group":
				made = _stage_group(st)
		for m: Dictionary in made:
			m.at = (m.at as Vector2) + at
			# a stage's ship states fall to every piece in it that has not its own
			for k: String in SHIP_STATES:
				if st.has(k) and not m.has(k):
					m[k] = st[k]
			m.strobe_of = st.get("strobe_id", -1)
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
	var far := bool(st.get("far", false))
	return [_m(_piece(st, 0), Vector2.ZERO, 0.5 if far else 1.0, 0.55 if far else 0.0,
		{r = float(st.get("r", 0.0)), tumble = float(st.get("tumble", 0.0)), turn = float(st.get("turn", 0.0))})]


## A line receding: the nearest at 1x in front, the rest far, along `dir`.
## `recede`: a queue going back into the dark, nose to tail -- the first `near`
## at 1x, the next `mid` at half, the rest at a quarter, each spaced by its own
## length (`overlap` of it tucked behind the one in front).
static func _stage_row(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 3))
	var near := int(st.get("near", n))
	var span := float(st.get("span", 300.0))
	var dir: Vector2 = st.get("dir", Vector2(1.0, -0.3))
	dir = dir.normalized()
	if bool(st.get("recede", false)):
		var mid := int(st.get("mid", 3))
		var overlap := float(st.get("overlap", 0.2))
		var scs: Array[float] = []
		var ws: Array[float] = []
		for i in n:
			var sc := 1.0 if i < near else (0.5 if i < near + mid else 0.25)
			scs.append(sc)
			ws.append(piece_size(_piece(st, i)).x * sc)
		var xs: Array[float] = [0.0]
		for i in range(1, n):
			xs.append(xs[i - 1] + (ws[i - 1] + ws[i]) * 0.5 * (1.0 - overlap))
		# (a queue can run off to the left as well: `dir` with x below 0)
		var c := xs[n - 1] * 0.5
		var sx := -1.0 if dir.x < 0.0 else 1.0
		for i in n:
			var x := (xs[i] - c) * sx
			var far := 0.0 if scs[i] >= 1.0 else (0.4 if scs[i] >= 0.5 else 0.6)
			out.append(_m(_piece(st, i), Vector2(x, x * dir.y / maxf(absf(dir.x), 0.05) * sx).round(), scs[i], far, {z = -i}))
		return out
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
		out.append(_m(id, Vector2(x, y), sc, 0.55 if far else 0.0, {swim = bool(st.get("swim", true)), flip = bool(st.get("flip", false)), z = i}))
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
		out.append(_m(id, Vector2(lerpf(-span * 0.5, span * 0.5, t), lerpf(rise * -0.5, rise * 0.5, t)), 0.5 if far else 1.0, 0.55 if far else 0.0, {swim = bool(st.get("swim", true)), flip = bool(st.get("flip", false)), z = -i}))
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


## The ship states a stage hands down to its pieces.
const SHIP_STATES := ["dark", "lights", "drive", "flood", "tow"]


## THE SAME SHIPS FOR THE SAME ENCOUNTER. Every `role:<name>` in a subject
## becomes a kept pool ship of that role: the encounter's id picks where in the
## role's list it starts, and each further ship of that role in it takes the
## next one along. So one encounter shows the same ships every time, the ships
## inside it differ, and two encounters land on different ones. `foe` becomes
## the ship the event's fight would bring (`fight_foe`), so the scene before a
## fight hands over to the fight's own ship. A stage with a `count` and roles in
## its pieces gets one pick per ship, not one per entry.
static func resolve(s: Variant, oid: StringName, danger: int = 1) -> Variant:
	var used := {}
	var out: Array = []
	var i := 0
	for st: Dictionary in stages_of(s):
		var st2: Dictionary = st.duplicate(true)
		st2.strobe_id = i if bool(st.get("strobe", false)) else -1
		i += 1
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


static func _is_cast(id: StringName) -> bool:
	return String(id).begins_with("role:") or id == &"foe"


static func _resolve_one(id: StringName, oid: StringName, used: Dictionary, danger: int) -> StringName:
	var k := String(id)
	if id == &"foe":
		return StringName("foe:%s" % fight_foe(danger))
	if not k.begins_with("role:"):
		return id
	var role := k.substr(5)
	var ships := role_ships(role)
	if ships.is_empty():
		return id
	var start := absi(("%s:%s" % [role, oid]).hash()) % ships.size()
	var n := int(used.get(role, 0))
	used[role] = n + 1
	return StringName(ships[(start + n) % ships.size()])


## THE SHIP THE EVENT'S FIGHT WOULD BRING: an event's fight is
## `Router.start_ambush`, one pick from this danger's pool off `Rng.foe`. Read
## from a copy of that stream, so looking does not move it, and the scene before
## the fight shows the ship the fight then draws.
static func fight_foe(danger: int) -> StringName:
	if foe_override != &"":
		return foe_override
	var pool := DB.fight_pool(danger, false)
	if pool.is_empty():
		return &"cutter"
	var r := RandomNumberGenerator.new()
	r.seed = Rng.foe.seed
	r.state = Rng.foe.state
	return StringName(Rng.pick(r, pool))


## The fight's ship as `EnemyArt` draws it in the fight (whole, unhurt), cut to
## the hull, with the canvas's own faint stars taken out.
static func _foe(id: StringName) -> Dictionary:
	var k := "foe:%s" % id
	if _foes.has(k):
		return _foes[k]
	if not DB.enemies.has(id):
		return {}
	var t: EnemyTemplate = DB.enemies[id]
	var art := EnemyArt.new()
	var e := Combat.EnemyState.new()
	e.template = t
	e.max_hp = t.max_hull
	e.hp = t.max_hull
	art.set_enemy(e, false)
	var u := art.used_rect()
	var img: Image = art._img.get_region(u)
	art.free()
	var star := Color("#141c26")
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and absf(c.r - star.r) < 0.004 and absf(c.g - star.g) < 0.004 and absf(c.b - star.b) < 0.004:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var d := {kind = "foe", tex = ImageTexture.create_from_image(img), w = img.get_width(), h = img.get_height()}
	d.merge(anchors_of(img))
	_foes[k] = d
	return d


## Bow (leftmost), stern (rightmost), top and belly of a picture's opaque
## pixels -- where its lights and its drive go.
static func anchors_of(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var x1 := -1
	var y0 := h
	var y1 := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 < 0:
		return {bow = [0, h / 2], stern = [w - 1, h / 2], top = [w / 2, 0], belly = [w / 2, h - 1]}
	var mid_y := func(xa: int, xb: int) -> int:
		var sum := 0
		var n := 0
		for x in range(xa, xb + 1):
			for y in h:
				if img.get_pixel(x, y).a > 0.5:
					sum += y
					n += 1
		return int(roundf(float(sum) / float(maxi(n, 1))))
	var mid_x := func(ya: int, yb: int) -> int:
		var sum := 0
		var n := 0
		for y in range(ya, yb + 1):
			for x in w:
				if img.get_pixel(x, y).a > 0.5:
					sum += x
					n += 1
		return int(roundf(float(sum) / float(maxi(n, 1))))
	# three lamps on the hull's own top line, a third, a half and two thirds along
	var lamps: Array = []
	for f: float in [0.3, 0.5, 0.7]:
		var x := roundi(lerpf(float(x0), float(x1), f))
		var ly := (y0 + y1) / 2
		for y in h:
			if img.get_pixel(x, y).a > 0.5:
				ly = y + 2
				break
		lamps.append([x, ly])
	return {bow = [x0, mid_y.call(x0, x0 + 2)], stern = [x1, mid_y.call(x1 - 2, x1)],
		top = [mid_x.call(y0, y0 + 1), y0], belly = [mid_x.call(y1 - 1, y1), y1], lamps = lamps}


## A RING OF SHIPS HOLDING: round an ellipse, all facing the one way they hold
## (their own), the back half far, the front `near` of them at 1x.
static func _stage_ring(st: Dictionary) -> Array:
	var out: Array = []
	var n := int(st.get("count", 6))
	var rx := float(st.get("rx", 150.0))
	var ry := float(st.get("ry", 60.0))
	var near := int(st.get("near", 0))
	var made_near := 0
	for i in n:
		var a := TAU * float(i) / float(n) + float(st.get("spin", 0.4))
		var front := sin(a) > 0.0
		var big := front and made_near < near
		if big:
			made_near += 1
		out.append(_m(_piece(st, i), Vector2(cos(a) * rx, sin(a) * ry).round(), 1.0 if big else 0.5,
			0.0 if big else (0.35 if front else 0.6), {z = 10 + i if front else -10 - i}))
	return out


## A GROUP: each ship placed where the subject says, with its own depth, turn and
## state -- a seized hull between a cutter and its escorts, a cutter anchored on
## a hull.
static func _stage_group(st: Dictionary) -> Array:
	var out: Array = []
	var i := 0
	for sh: Dictionary in st.get("ships", []):
		var far := bool(sh.get("far", false))
		var m := _m(StringName(sh.get("piece", &"")), sh.get("at", Vector2.ZERO), 0.5 if far else 1.0, 0.55 if far else 0.0,
			{turn = float(sh.get("turn", 0.0)), z = int(sh.get("z", i))})
		for k: String in SHIP_STATES:
			if sh.has(k):
				m[k] = sh[k]
		out.append(m)
		i += 1
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
	cur.oid = n.options[opt]
	cur.danger = n.danger
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
	_strobes.clear()
	var planned := plan(subject, oid, danger)
	_bounds = bounds_of(planned)
	var painted := LocalSky.style_now() == &"painted"
	cast.clear()
	for m: Dictionary in planned:
		var id := StringName(m.id)
		cast.append(id)
		var p: Dictionary = piece_info(id)
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
		mat.set_shader_parameter("dark", float(m.get("dark", 0.0)))
		mat.set_shader_parameter("stepped", painted)
		spr.material = mat
		holder.add_child(spr)
		var turn := float(m.get("turn", 0.0))
		var rec := {node = holder, sprite = spr, mat = mat, at = m.at, scale = float(m.scale), far = float(m.far),
			swim = bool(m.get("swim", false)), tumble = float(m.get("tumble", 0.0)), tether = bool(m.get("tether", false)),
			phase = float(_placed.size()) * 1.731, planet = null, turn = deg_to_rad(turn), info = p,
			lights = StringName(m.get("lights", &"")), drive = bool(m.get("drive", false)),
			flood = bool(m.get("flood", false)), tow = float(m.get("tow", 0.0)), dark = float(m.get("dark", 0.0)),
			full = null, half = null, quarter = null, tex_k = 1.0}
		var kind := String(p.get("kind", ""))
		if kind == "painter":
			_painter(rec, p, float(m.get("r", 0.0)))
		elif kind == "foe":
			spr.texture = turned(id, p.tex, turn) if not is_zero_approx(turn) else p.tex
		else:
			var tex := load(String(p.file)) as Texture2D
			rec.full = turned(id, tex, turn) if not is_zero_approx(turn) and tex != null else tex
			for size: String in ["half", "quarter"]:
				if p.has(size) and ResourceLoader.exists(String(p[size])):
					var hx := load(String(p[size])) as Texture2D
					rec[size] = turned(StringName("%s_%s" % [id, size]), hx, turn) if not is_zero_approx(turn) and hx != null else hx
			spr.texture = rec.full
		_placed.append(rec)
		_apply_scale(rec)
		if rec.tether:
			_tethers.append(rec)
		if int(m.get("strobe_of", -1)) >= 0:
			var k := int(m.strobe_of)
			if not _strobes.has(k):
				_strobes[k] = []
			(_strobes[k] as Array).append(rec)
	# THE LIGHTS go over everything else here, added to what is behind them
	_over = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_over.material = add
	_over.draw.connect(_draw_over)
	add_child(_over)
	_layout()


## A piece at its size on screen: its own scale times the subject's (`fit`), on
## the half- or quarter-size picture made for it when it is drawn that small
## (pixel art at its size, not every other pixel of the near one).
func _apply_scale(rec: Dictionary) -> void:
	var spr: Sprite2D = rec.sprite
	var eff := float(rec.scale) * _scale
	if rec.quarter != null and eff <= 0.25 + 0.001:
		spr.texture = rec.quarter
		rec.tex_k = 0.25
	elif rec.half != null and eff <= 0.5 + 0.001:
		spr.texture = rec.half
		rec.tex_k = 0.5
	elif rec.full != null:
		spr.texture = rec.full
		rec.tex_k = 1.0
	spr.scale = Vector2.ONE * eff / float(rec.tex_k)


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
			_apply_scale(rec)
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
	_t = t
	queue_redraw()
	if _over != null:
		_over.queue_redraw()


## A point of a piece's own 1x picture, where it is on screen now (its turn, its
## tumble and its size taken in).
func _at(rec: Dictionary, a: Variant) -> Vector2:
	var p: Dictionary = rec.info
	var v := Vector2(float(a[0]) + 0.5, float(a[1]) + 0.5) - Vector2(float(p.w), float(p.h)) * 0.5
	var node: Node2D = rec.node
	return node.position + v.rotated(float(rec.turn) + node.rotation) * float(rec.scale) * _scale


## How big a light is drawn on this piece: smaller on far ones.
func _lk(rec: Dictionary) -> float:
	return float(rec.scale) * _scale


## THE LIGHTS, as light: each a glow gathered round a bright core, falling off in
## steps with a dithered edge (`_glow_tex`), added to what is under it, and eased
## on and off, never snapped (a hard blink reads as a fault).
func _draw_over() -> void:
	var t := _t
	for rec: Dictionary in _placed:
		var p: Dictionary = rec.info
		if not p.has("bow"):
			continue
		var k := _lk(rec)
		var dim := 1.0 - 0.6 * float(rec.far)
		if bool(rec.drive):
			# a drive at the stern, breathing a little
			var fl := 0.85 + 0.1 * sin(t * 5.1 + float(rec.phase)) + 0.05 * sin(t * 13.7 + float(rec.phase) * 2.0)
			var at := _at(rec, p.stern) + Vector2(2.0 * k, 0.0)
			_glow(at, roundi(12.0 * k) + 1, Color(1.0, 0.6, 0.28), 0.95 * fl * dim)
			_glow(at, roundi(4.0 * k) + 1, Color(1.0, 0.9, 0.75), fl * dim)
		if bool(rec.flood):
			_flood(rec, k, dim)
		match StringName(rec.lights):
			&"run":
				# red at the bow, green at the stern, a white strobe up top
				_glow(_at(rec, p.bow), roundi(5.0 * k) + 1, Color(1.0, 0.25, 0.2), 0.85 * dim)
				_glow(_at(rec, p.stern), roundi(5.0 * k) + 1, Color(0.3, 1.0, 0.45), 0.8 * dim)
				_glow(_at(rec, p.top), roundi(7.0 * k) + 1, Color(1.0, 1.0, 0.95), _blink(t + float(rec.phase), 2.2, 0.45) * dim)
			&"battery":
				# a few dim lights along the hull's top, slowly breathing
				var lamps: Array = p.get("lamps", [p.top])
				for j in lamps.size():
					var b := 0.55 + 0.2 * sin(t * TAU / 4.5 + float(j) * 1.9 + float(rec.phase))
					_glow(_at(rec, lamps[j]), roundi(4.0 * k) + 1, Color(1.0, 0.7, 0.35), b * dim)
			&"patrol":
				# red and blue, turn about
				var top2: Array = p.top
				var e1 := _blink(t + float(rec.phase), 1.6, 0.5)
				var e2 := _blink(t + float(rec.phase) + 0.8, 1.6, 0.5)
				_glow(_at(rec, [float(top2[0]) - 4.0, float(top2[1])]), roundi(8.0 * k) + 1, Color(1.0, 0.2, 0.2), e1 * dim)
				_glow(_at(rec, [float(top2[0]) + 4.0, float(top2[1])]), roundi(8.0 * k) + 1, Color(0.25, 0.45, 1.0), e2 * dim)
	# A STROBE run along a line of ships: a thin light from one to the next,
	# brightening and fading slowly
	for k2 in _strobes:
		var line: Array = _strobes[k2]
		if line.size() < 2:
			continue
		var pts: Array[Vector2] = []
		for rec: Dictionary in line:
			pts.append((rec.node as Node2D).position)
		pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var e := 0.35 + 0.65 * _blink(t, 2.6, 0.9)
		for i in pts.size() - 1:
			_beam(pts[i], pts[i + 1], Color(1.0, 0.55, 0.25), e)


## 0..1, on for `on` of every `period` seconds, eased in and out.
static func _blink(t: float, period: float, on: float) -> float:
	var ph := fposmod(t, period) / period
	var w := on / period
	if ph > w:
		return 0.0
	return sin(ph / w * PI)


## One light: the halo (`_glow_tex`) tinted, then a hot core over it -- a pixel,
## two square on a big one -- near white in the light's own colour.
func _glow(at: Vector2, r: int, col: Color, a: float) -> void:
	if a <= 0.01 or _over == null:
		return
	var tex := _glow_tex(maxi(r, 1))
	var sz := tex.get_size()
	_over.draw_texture(tex, (at - sz * 0.5).round(), Color(col.r * a, col.g * a, col.b * a, 1.0))
	var hot := col.lerp(Color.WHITE, 0.55)
	var cs := 2.0 if r >= 6 else 1.0
	_over.draw_rect(Rect2((at - Vector2(cs, cs) * 0.5).round(), Vector2(cs, cs)), Color(hot.r * a, hot.g * a, hot.b * a, 1.0))


## A glow `r` px round: a bright core, then three steps of falloff, the outer two
## dithered on a 2x2 pattern. White: the caller tints it.
static func _glow_tex(r: int) -> Texture2D:
	var k := "%d" % r
	if _glows.has(k):
		return _glows[k]
	var n := r * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - r, y - r).length() / float(maxi(r, 1))
			if d > 1.0:
				continue
			var v := pow(1.0 - d, 2.0)
			var step := floorf(v * 4.0 + 0.5) / 4.0
			if d > 0.5 and (x + y) % 2 == 1:
				step *= 0.5
			if r <= 1:
				step = 1.0 if d < 0.5 else 0.5
			img.set_pixel(x, y, Color(step, step, step, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_glows[k] = tex
	return tex


## A floodlight off the bow toward you (`_cone_tex`), added over the scene, a hot
## lamp where it starts.
func _flood(rec: Dictionary, k: float, dim: float) -> void:
	var p: Dictionary = rec.info
	var from := _at(rec, p.bow)
	var tex := _cone_tex(roundi(120.0 * k))
	var sz := tex.get_size()
	var col := Color(1.0, 0.92, 0.75)
	var a := 0.55 * dim
	# the cone's apex is its right edge, a third of the way down (it falls away
	# toward you, below)
	_over.draw_texture(tex, (from - Vector2(sz.x, sz.y * 0.3)).round(), Color(col.r * a, col.g * a, col.b * a, 1.0))
	_glow(from, roundi(4.0 * k) + 1, col, 0.9 * dim)


## A cone of light `len` px long pointing left and a little down: brightest at
## its apex, falling off along it and across it in four steps, the outer two
## dithered on a 2x2 pattern -- light as pixel art lights a thing, not a smooth
## wash. White: the caller tints it.
static func _cone_tex(len: int) -> Texture2D:
	var key := "cone:%d" % len
	if _glows.has(key):
		return _glows[key]
	len = maxi(len, 8)
	var w := len
	var h := int(float(len) * 0.62)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var apex_y := float(h) * 0.3
	for y in h:
		for x in w:
			var u := float(w - 1 - x) / float(w)
			var cy := apex_y + u * float(len) * 0.22
			var hw := 1.0 + u * float(len) * 0.2
			var d := absf(float(y) - cy) / hw
			if d > 1.0:
				continue
			var v := pow(1.0 - u, 1.4) * (1.0 - d * d)
			var step := floorf(v * 4.0 + 0.5) / 4.0
			if step <= 0.0:
				continue
			if step <= 0.5 and (x + y) % 2 == 1:
				continue
			img.set_pixel(x, y, Color(step, step, step, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_glows[key] = tex
	return tex


func _beam(a: Vector2, b: Vector2, col: Color, e: float) -> void:
	_over.draw_line(a.round(), b.round(), Color(col.r * e * 0.25, col.g * e * 0.25, col.b * e * 0.25, 1.0), 3.0)
	_over.draw_line(a.round(), b.round(), Color(col.r * e, col.g * e, col.b * e, 1.0), 1.0)


## THE TETHER: a dark line through the hung pieces, one pixel, from end to end.
## And a TOW LINE off a ship's bow: slack, sagging, a clamp at its end.
func _draw() -> void:
	for rec: Dictionary in _placed:
		if float(rec.tow) <= 0.0 or not (rec.info as Dictionary).has("bow"):
			continue
		var k := _lk(rec)
		var a := _at(rec, (rec.info as Dictionary).bow)
		var len := float(rec.tow) * k
		var b := a + Vector2(-len, 14.0 * k + sin(_t * TAU / 19.0 + float(rec.phase)) * 2.0)
		var prev := a
		for i in range(1, 13):
			var u := float(i) / 12.0
			var q := a.lerp(b, u) + Vector2(0.0, sin(u * PI) * 12.0 * k)
			draw_line(prev.round(), q.round(), Color(0.46, 0.48, 0.52, 0.95), 1.0)
			prev = q
		draw_rect(Rect2((b - Vector2(2.0, 2.0)).round(), Vector2(4, 4)), Color(0.55, 0.52, 0.45))
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
		var sz := spr.texture.get_size() * spr.scale
		var c := (rec.node as Node2D).get_global_transform().origin
		out.append(Rect2(c - sz * 0.5, sz))
	return out
