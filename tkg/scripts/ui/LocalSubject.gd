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
##           `resolve`). Never the fight's own coded ship (`EnemyArt`): Jon
##           picked kept pool ships on LOCAL, and the fight draws its own
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
##   dock    group: {to = <index of another ship in the group>}: this one is ON
##           that one -- set down on its top edge, touching it and not crossing
##           it, clamped there (two clamps drawn over the seam), moving with it
## And on a stage: `strobe` (a light run along the line of its ships).
##
## NOTHING IS DRAWN ACROSS ANYTHING ELSE (Jon: "why are they stacked on top of
## each other"; "it has to make sense where it stands"). No two pieces' opaque
## pixels come within the drift each can travel of one another (`mask_of`,
## `drift_of`, `clear_of`), except a piece on its own rock or round its own body,
## and a declared `dock`, which touches along an edge. `-- subjecttest` holds
## every subject to it.
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
## Glows for the lights, by "radius:colour".
static var _glows: Dictionary = {}
## Opaque-pixel masks of pieces as drawn (`mask_of`), and dilated ones.
static var _masks: Dictionary = {}
## The stagings the last `plan` drew fewer of than asked, to keep them clear.
static var short: Array[String] = []

## Which option this draws, at which system (so a refresh only rebuilds when it
## changes).
var key := ""
var subject: Variant = null
## The encounter it is (its ships are picked by it) and the system's danger.
var oid: StringName = &""
var danger := 1
## What it drew, piece by piece, once resolved.
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
## Where a docked piece's clamps are drawn (over the pieces, plain).
var _links: Node2D = null
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


## A piece's record, from the index.
static func piece_info(id: StringName) -> Dictionary:
	return index().get(String(id), {})


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
	var stage_i := -1
	short.clear()
	for st: Dictionary in stages_of(resolve(s, oid, danger)):
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
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.far) > float(b.far) if not is_equal_approx(float(a.far), float(b.far)) else int(a.get("z", 0)) < int(b.get("z", 0)))
	var where := {}
	for i in out.size():
		where[int(out[i].idx)] = i
	for m: Dictionary in out:
		if m.has("dock_to"):
			m.dock_to = where[int(m.dock_to)]
	return out


## Set `m` down on top of `host`: from well clear above, lowered a pixel at a
## time until it touches (its mask one pixel from the host's), never crossing.
## The two clamps go where it touches, a quarter of its length in from each end.
static func _dock(m: Dictionary, host: Dictionary) -> void:
	var a := mask_of(m)
	var b := mask_of(host)
	if a.is_empty() or b.is_empty():
		return
	var hp := _corner(host, b)
	var at: Vector2 = m.at
	var y := (host.at as Vector2).y - float(int(b.h) + int(a.h)) * 0.5 - 4.0
	var best := y
	for step in 200:
		m.at = Vector2(at.x, y)
		if touches(a, _corner(m, a), b, hp, 0, 0):
			break
		best = y
		y += 1.0
	m.at = Vector2(at.x, best)
	# the clamps: where its underside meets the host, a quarter in from each end
	var mp := _corner(m, a)
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


## The opaque pixels of a planned piece as it is drawn: its picture (the half or
## quarter one where it is drawn that small, as `_apply_scale` does), turned as it
## is turned, at its size; a painter rock as its lumpy mask, a moon as its disc.
## {w, h, bits (1 per opaque pixel, row by row)}.
static func mask_of(m: Dictionary) -> Dictionary:
	var id := StringName(m.id)
	var sc := float(m.scale)
	var turn := float(m.get("turn", 0.0))
	var r := float(m.get("r", 0.0))
	var flip := bool(m.get("flip", false))
	var key := "%s|%s|%s|%s|%s" % [id, sc, turn, r, flip]
	if _masks.has(key):
		return _masks[key]
	var p := piece_info(id)
	if p.is_empty():
		return {}
	var img: Image = null
	var base := 1.0
	match String(p.get("kind", "")):
		"painter":
			var r0 := float(p.r)
			var k := (r / r0) if r > 0.0 else 1.0
			var w := int(roundf(float(p.w) * k))
			var h := int(roundf(float(p.h) * k))
			if not (p.get("lobes", []) as Array).is_empty():
				img = lumpy_mask(w, h, k, p)
			else:
				img = Image.create(w, h, false, Image.FORMAT_RGBA8)
				var c := Vector2(float(p.cx), float(p.cy)) * k
				for yy in h:
					for xx in w:
						if Vector2(float(xx) + 0.5, float(yy) + 0.5).distance_to(c) <= r0 * k:
							img.set_pixel(xx, yy, Color(1, 0, 0, 1))
		_:
			var path := String(p.file)
			if sc <= 0.25 + 0.001 and p.has("quarter"):
				path = String(p.quarter)
				base = 0.25
			elif sc <= 0.5 + 0.001 and p.has("half"):
				path = String(p.half)
				base = 0.5
			img = _image_of(path)
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if not is_zero_approx(turn):
		img = turned_image(img, turn)
	if flip:
		img.flip_x()
	var f := sc / base
	if not is_equal_approx(f, 1.0):
		img.resize(maxi(1, int(roundf(float(img.get_width()) * f))), maxi(1, int(roundf(float(img.get_height()) * f))), Image.INTERPOLATE_NEAREST)
	var w2 := img.get_width()
	var h2 := img.get_height()
	var bits := PackedByteArray()
	bits.resize(w2 * h2)
	var painter := String(p.get("kind", "")) == "painter"
	for yy in h2:
		for xx in w2:
			var c2 := img.get_pixel(xx, yy)
			bits[yy * w2 + xx] = 1 if (c2.r > 0.5 if painter else c2.a > 0.5) else 0
	var d := {w = w2, h = h2, bits = bits, key = key}
	_masks[key] = d
	return d


## A picture's pixels: from the imported texture (what an export carries), or
## from the file itself where there is no renderer to ask (a headless test).
static func _image_of(path: String) -> Image:
	var tex := load(path) as Texture2D
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		img = Image.load_from_file(path)
	return img


## Where a planned piece's picture starts, its top-left pixel.
static func _corner(m: Dictionary, mk: Dictionary) -> Vector2i:
	# floor, not round: a half pixel rounds away from zero, so a piece moved by a
	# whole pixel across the middle would land a pixel off from its neighbours
	return Vector2i(((m.at as Vector2) - Vector2(float(mk.w), float(mk.h)) * 0.5).floor())


## Whether any opaque pixel of `a` (at `pa`) comes within `mx`, `my` px of an
## opaque pixel of `b` (at `pb`). 0, 0: whether they share a pixel.
static func touches(a: Dictionary, pa: Vector2i, b: Dictionary, pb: Vector2i, mx: int, my: int) -> bool:
	var ra := Rect2i(pa, Vector2i(int(a.w), int(a.h)))
	var rb := Rect2i(pb - Vector2i(mx, my), Vector2i(int(b.w) + mx * 2, int(b.h) + my * 2))
	var inter := ra.intersection(rb)
	if inter.size.x <= 0 or inter.size.y <= 0:
		return false
	var bd := _dilated(b, mx, my)
	var ab: PackedByteArray = a.bits
	var bb: PackedByteArray = bd.bits
	var aw := int(a.w)
	var bw := int(bd.w)
	var o := pb - Vector2i(mx, my)
	for y in range(inter.position.y, inter.end.y):
		for x in range(inter.position.x, inter.end.x):
			if ab[(y - pa.y) * aw + (x - pa.x)] != 0 and bb[(y - o.y) * bw + (x - o.x)] != 0:
				return true
	return false


## A mask grown by `mx`, `my` px each way.
static func _dilated(b: Dictionary, mx: int, my: int) -> Dictionary:
	if mx == 0 and my == 0:
		return b
	var key := "dil|%s|%d|%d" % [b.get("key", ""), mx, my]
	if _masks.has(key):
		return _masks[key]
	var w := int(b.w)
	var h := int(b.h)
	var W := w + mx * 2
	var H := h + my * 2
	var src: PackedByteArray = b.bits
	var row := PackedByteArray()
	row.resize(W * h)
	for y in h:
		for x in w:
			if src[y * w + x] != 0:
				for dx in range(0, mx * 2 + 1):
					row[y * W + x + dx] = 1
	var out := PackedByteArray()
	out.resize(W * H)
	for y in h:
		for x in W:
			if row[y * W + x] != 0:
				for dy in range(0, my * 2 + 1):
					out[(y + dy) * W + x] = 1
	var d := {w = W, h = H, bits = out}
	_masks[key] = d
	return d


## Whether planned piece `m` stands clear of every one of `others` by the drift
## the two can travel apart (`clear_of`'s rule, for placing one at a time).
static func _clear(m: Dictionary, others: Array) -> bool:
	var a := mask_of(m)
	if a.is_empty():
		return true
	var pa := _corner(m, a)
	var da := drift_of(m)
	for o: Dictionary in others:
		var b := mask_of(o)
		if b.is_empty():
			continue
		var d := da + drift_of(o)
		if touches(a, pa, b, _corner(o, b), int(ceilf(d.x)), int(ceilf(d.y))):
			return false
	return true


## How far a planned piece can travel from where it stands: its drift (as
## `_process` moves it) and the reach of its tumble at its ends.
static func drift_of(m: Dictionary) -> Vector2:
	var amp := 3.0 if float(m.far) > 0.0 else 5.0
	var d := Vector2(amp * 0.5, amp * 0.4)
	if bool(m.get("swim", false)):
		d = Vector2(amp * 1.6, 2.0)
	if bool(m.get("tether", false)):
		d = Vector2(0.0, 1.5)
	var tb := float(m.get("tumble", 0.0))
	if tb > 0.0:
		var sz := piece_size(StringName(m.id), float(m.get("r", 0.0))) * float(m.scale)
		d += Vector2(sz.y * 0.5, sz.x * 0.5) * sin(deg_to_rad(tb))
	if float(m.get("roll", 0.0)) != 0.0:
		# turning right over, its corners reach past its box
		var sz2 := piece_size(StringName(m.id)) * float(m.scale)
		var reach := (sz2.length() - minf(sz2.x, sz2.y)) * 0.5
		d += Vector2(reach, reach)
	return d


## WHICH PIECES ARE TOO CLOSE: every pair whose opaque pixels come within the
## drift the two can travel apart of each other -- except a piece on its own
## rock or round its own body, a clamp welding two neighbours, and a docked pair,
## which must instead touch and not cross. ["a ~ b", ...]
static func clear_of(planned: Array) -> Array[String]:
	var bad: Array[String] = []
	var ms: Array = []
	for m: Dictionary in planned:
		ms.append(mask_of(m))
	for i in planned.size():
		for j in range(i + 1, planned.size()):
			var a: Dictionary = planned[i]
			var b: Dictionary = planned[j]
			if ms[i].is_empty() or ms[j].is_empty():
				continue
			var same := int(a.get("st_i", -1)) == int(b.get("st_i", -2))
			if same and ((bool(a.get("on_base", false)) and bool(b.get("base_of", false))) \
					or (bool(b.get("on_base", false)) and bool(a.get("base_of", false))) \
					or bool(a.get("welds", false)) or bool(b.get("welds", false))):
				continue
			var pa := _corner(a, ms[i])
			var pb := _corner(b, ms[j])
			var docked := int(a.get("dock_to", -1)) == j or int(b.get("dock_to", -1)) == i
			if docked:
				if touches(ms[i], pa, ms[j], pb, 0, 0) or not touches(ms[i], pa, ms[j], pb, 1, 1):
					bad.append("%s docked on %s (not touching along an edge)" % [a.id, b.id])
				continue
			var d := drift_of(a) + drift_of(b)
			if touches(ms[i], pa, ms[j], pb, int(ceilf(d.x)), int(ceilf(d.y))):
				bad.append("%s ~ %s" % [a.id, b.id])
	return bad


## `turned`'s pixels, for an Image.
static func turned_image(src: Image, deg: float) -> Image:
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
			var dx := float(x) + 0.5 - ocx
			var dy := float(y) + 0.5 - ocy
			var sx := floori(dx * c + dy * sn + scx)
			var sy := floori(-dx * sn + dy * c + scy)
			if sx >= 0 and sy >= 0 and sx < sw and sy < sh:
				img.set_pixel(x, y, src.get_pixel(sx, sy))
	return img


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
		{r = float(st.get("r", 0.0)), tumble = float(st.get("tumble", 0.0)), turn = float(st.get("turn", 0.0)), flip = bool(st.get("flip", false))})]


## A ROW: a line of them nose to tail along `dir` (`_nose_to_tail`), the first
## `near` at 1x, then `mid` at half, the rest at half -- or, `recede`, the rest at
## a quarter: a queue going back into the dark.
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


## A LINE OF THEM, NOSE TO TAIL (Jon on the queues, convoys and strings of cargo:
## "why are they so weirdly stacked"). Each next one goes on along the line only
## once it is clear of the one before it SIDEWAYS -- `gap` px of air between the
## one's tail and the next one's nose -- never set above or below it, so the line
## reads as things one behind another and never piles into a column or a
## staircase. The line runs nearly level, at most `MAX_SLOPE` up or down (`dir`
## gives which way it goes and its lean): the far end a little higher, as far
## things sit nearer the horizon. Its gaps close up as its pieces get smaller
## (further off, closer together). Only as many as `span` holds either side of
## the middle; the rest are past the edge of what you see. `jitter` lifts or drops
## each one a few px off the line and `turns` turns each a few degrees (a drifting
## string, not a parade), from `seed`. Centred, and any that would cross what the
## scene already holds left out.
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
		var w := turned_size(piece_size(StringName(m.id)), float(m.get("turn", 0.0))).x * sc
		if not out.is_empty():
			run += (prev_w + w) * 0.5 + maxf(gap * minf(sc, prev_sc), 3.0)
		var placed := false
		while run <= span:
			m.at = Vector2(sx * run, slope * run + lift).round()
			if _clear(m, out):
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
		if _clear(m, prior):
			kept.append(m)
	return kept


## A tether: pieces hung at even steps on a line that sags a little, between two
## ends (painter rocks, or bare). ONE LINE AT ONE DEPTH (Jon: "why are they so
## weirdly stacked"): its ends and everything on it the one size -- 1x, or half
## and dimmed when `far` -- never big ones and small ones on the same string, which
## no distance makes. The line keeps nearly level (`tilt`, at most `MAX_SLOPE`).
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
		inner -= (piece_size(StringName(e), er).x * 0.5 + 12.0) * sc
	var ws: Array[float] = []
	var total := 0.0
	for i in n:
		var w := piece_size(_piece(st, i)).x * sc
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
	# NOT COPIES PASTED IN (Jon on the mine drift and the scatter: "super busy?
	# idk they look just copy and pasted in"), when a field asks: `turns`, each
	# piece turned its own way up to that many degrees (once, pixel for pixel);
	# `deep`, the last that many a quarter size, further off still, so the field
	# has three distances and not two; `band`, the field a stream leaning that
	# many degrees, things drifting through along a line, not a round cloud.
	var turns := float(st.get("turns", 0.0))
	var deep := int(st.get("deep", 0))
	var band := deg_to_rad(float(st.get("band", 0.0)))
	# A LOOSE GROUP, NOT A LINE (Jon on every evenly spaced row: "why are they so
	# weirdly stacked"): ships waiting off a dock, a convoy, a knot of tanks --
	# `flip` faces them all one way (ships, a herd) instead of each at random,
	# and `lift` sets the further ones that much higher at a quarter size (half
	# that at half size), as far things sit nearer the horizon
	var lift := float(st.get("lift", 0.0))
	for i in n:
		var far := i >= near
		var id := _piece(st, i)
		var sc := 0.5 if far else 1.0
		if i >= n - deep and far:
			sc = 0.25
		var turn := roundf(R.randf_range(-turns, turns)) if turns > 0.0 else 0.0
		var sz := turned_size(piece_size(id), turn) * sc
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
				{flip = flip, tumble = float(st.get("tumble", 4.0)), z = i, turn = turn})
			# CLEAR of every piece already placed, this field's and the scene's
			if _clear(m, out + prior):
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
		var sz := piece_size(id) * sc
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


## `m` where it stands if that is clear of `others`, else the nearest clear place
## round it inside `room` (rings of tries, growing); {} if there is none -- then
## the piece is left out, rather than drawn across another.
static func _nearest_clear(m: Dictionary, others: Array, room: Rect2, R: RandomNumberGenerator) -> Dictionary:
	var home: Vector2 = m.at
	var sz := piece_size(StringName(m.id), float(m.get("r", 0.0))) * float(m.scale)
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
			if _clear(m, others):
				return m
	return {}


## A line of them crossing (creatures swimming, ships under way): nose to tail
## (`_nose_to_tail`), the first `near` at 1x, the next `mid` at half, the rest at
## a quarter, the line leaning `rise` over `span`.
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
			if _clear(m, round + prior):
				round.append(m)
				break
	out.append_array(round)
	return out


## A LOOSE HERD ROUND A BODY (Jon on the ring of feeders: "????????"; then
## "why are they touching the moon"): each somewhere near it at its own distance
## from it -- more in front of it than behind -- at its own size (`size` at
## most, down to a quarter of it behind), turned up to `tilt` degrees and facing
## either way, from `seed`. Each keeps clear of the others, and `apart` px of
## sky clear of the body itself; one that cannot is left out.
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
	var bm := mask_of(body)
	for i in n:
		var id := _piece(st, i)
		for tries in 60:
			var a := R.randf() * TAU
			var front := sin(a) > -0.25
			var sc := (size if R.randf() < 0.85 else size * 0.5) if front else (size * 0.5 if R.randf() < 0.5 else size * 0.25)
			var rr := R.randf_range(1.0, 1.5)
			var m := _m(id, Vector2(cos(a) * rx * rr, sin(a) * ry * rr).round(), sc, _far_of(sc / maxf(size, 0.01)),
				{turn = roundf(R.randf_range(-tilt, tilt)), flip = R.randf() < 0.5, z = 10 + i if front else -10 - i, on_base = true})
			var mm := mask_of(m)
			var d := drift_of(m) + drift_of(body)
			if not bm.is_empty() and touches(mm, _corner(m, mm), bm, _corner(body, bm), apart + int(ceilf(d.x)), apart + int(ceilf(d.y))):
				continue
			if _clear(m, out + prior):
				out.append(m)
				break
	return out


## On a rock: the rock, and pieces on its face in rows, clamps between them.
static func _stage_on_rock(st: Dictionary) -> Array:
	var out: Array = []
	var base := StringName(st.get("base", &""))
	var r := float(st.get("r", 80.0))
	# `planet`: the rock as the planet painter drew it before rocks had form (Jon
	# kept the welded plate on that rock, and the plate on the new one read
	# "pasted on a blotchy rock")
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
			out.append(_m(_piece(st, y * cols + x), p, 1.0, 0.0, {z = 1 + y * cols + x, on_base = true}))
			if clamp_id != &"" and x < cols - 1:
				# a clamp welds two neighbours together: it is on both
				out.append(_m(clamp_id, p + Vector2(gap.x * 0.5, 0.0), 1.0, 0.0, {z = 100 + y * cols + x, on_base = true, welds = true}))
	return out


## CLAMPED WHERE THEY WERE DROPPED, NOT IN ROWS (Jon on the welded rows: "why
## are they so weirdly stacked"): `count` pieces in one patch of the rock's face
## (`spread`, round `face`), each turned up to `turns` degrees, each held by its
## own clamp at its foot, each clear of the others and every corner of it on the
## rock (none hanging past its edge), from `seed`. Side by side, never one above
## another (Jon: "literally a stack"): no two share any width. `size` draws them
## smaller against the rock (half: their own picture's every other pixel, not
## dimmed -- they are on the rock, as near as it is).
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
			var m := _m(id, at.round(), sc, 0.0, {z = 2 + i * 2, on_base = true, turn = deg})
			var foot := Vector2(0.0, (piece_size(id).y * 0.5 - 3.0) * sc).rotated(deg_to_rad(deg))
			var held := _m(clamp_id, (at + foot).round(), sc, 0.0, {z = 1 + i * 2, on_base = true, welds = true, turn = deg}) if clamp_id != &"" else {}
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
			if _clear(m, boxes):
				boxes.append(m)
				out.append(m)
				if not held.is_empty():
					out.append(held)
				break
	return out


## Whether every opaque pixel of planned piece `m` lies on `rock`'s own, a few
## px in from its edge.
static func _on_rock(m: Dictionary, rock: Dictionary) -> bool:
	var a := mask_of(m)
	var b := mask_of(rock)
	if a.is_empty() or b.is_empty():
		return true
	var pa := _corner(m, a)
	var pb := _corner(rock, b)
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


## THE SAME SHIPS FOR THE SAME ENCOUNTER. Every `role:<name>` in a subject
## becomes a kept pool ship of that role: the encounter's id picks where in the
## role's list it starts, and each further ship of that role in it takes the
## next one along. So one encounter shows the same ships every time, the ships
## inside it differ, and two encounters land on different ones. A stage with a
## `count` and roles in its pieces gets one pick per ship, not one per entry.
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
	return String(id).begins_with("role:")


static func _resolve_one(id: StringName, oid: StringName, used: Dictionary, _danger: int) -> StringName:
	var k := String(id)
	if not k.begins_with("role:"):
		return id
	var role := k.substr(5)
	var ships := role_ships(role)
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
		if _clear(m, out + prior):
			out.append(m)
			if big:
				made_near += 1
	return out


## A GROUP: each ship placed where the subject says, with its own depth, turn and
## state -- a seized hull between a cutter and its escorts, a cutter anchored on
## a hull.
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
			dock_to = int(m.get("dock_to", -1)), links = m.get("links", []), off = Vector2.ZERO,
			swim = bool(m.get("swim", false)), tumble = float(m.get("tumble", 0.0)), tether = bool(m.get("tether", false)),
			phase = float(_placed.size()) * 1.731, planet = null, turn = deg_to_rad(turn), info = p,
			lights = StringName(m.get("lights", &"")), drive = bool(m.get("drive", false)),
			flood = bool(m.get("flood", false)), tow = float(m.get("tow", 0.0)), dark = float(m.get("dark", 0.0)),
			full = null, half = null, quarter = null, tex_k = 1.0,
			roll = float(m.get("roll", 0.0)) if not p.has("half") else 0.0, roll_step = float(m.get("roll_step", 15.0)),
			turn_deg = turn, rolled = 1e9, src = null}
		var kind := String(p.get("kind", ""))
		if kind == "painter":
			_painter(rec, p, float(m.get("r", 0.0)), bool(m.get("planet", false)))
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
	# a docked piece rides its host
	_link_hosts(planned)
	# THE CLAMPS of a docked piece, over the seam, in plain paint
	_links = Node2D.new()
	_links.draw.connect(_draw_links)
	add_child(_links)
	# THE LIGHTS go over everything else here, added to what is behind them
	_over = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_over.material = add
	_over.draw.connect(_draw_over)
	add_child(_over)
	_layout()


## Each docked record's host record (the plan's `dock_to`, by plan index).
func _link_hosts(planned: Array) -> void:
	var rec_of := {}
	var j := 0
	for i in planned.size():
		if piece_info(StringName(planned[i].id)).is_empty():
			continue
		rec_of[i] = _placed[j]
		j += 1
	for i in rec_of:
		var rec: Dictionary = rec_of[i]
		rec.host = rec_of.get(int(rec.dock_to), null) if int(rec.dock_to) >= 0 else null


## TWO CLAMPS where a docked piece meets its host: a short steel bar standing
## across the seam, lit on its top, dark round its edge.
func _draw_links() -> void:
	for rec: Dictionary in _placed:
		if rec.get("host") == null:
			continue
		var node: Node2D = rec.node
		var k := float(rec.scale) * _scale
		for l: Vector2 in rec.links:
			var c := (node.position + l * _scale).round()
			var w := maxf(3.0, roundf(4.0 * k))
			var h := maxf(5.0, roundf(9.0 * k))
			var r := Rect2(c - Vector2(roundf(w * 0.5), roundf(h * 0.5)), Vector2(w, h))
			_links.draw_rect(r.grow(1.0), Color(0.06, 0.07, 0.09))
			_links.draw_rect(r, Color(0.42, 0.45, 0.5))
			_links.draw_rect(Rect2(r.position, Vector2(w, 1.0)), Color(0.72, 0.75, 0.8))


## A piece at its size on screen: its own scale times the subject's (`fit`), on
## the half- or quarter-size picture made for it when it is drawn that small
## (pixel art at its size, not every other pixel of the near one).
func _apply_scale(rec: Dictionary) -> void:
	rec.rolled = 1e9
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


## A PIECE TURNING OVER (`roll`), as pixel art turns: never rotated on screen
## (a sprite turned live on nearest filtering ripples), but shown a picture at
## a time, each turned once, pixel for pixel (`turned`), `roll_step` degrees
## apart -- so it steps round like a sprite's frames, a step every second or two.
func _roll(rec: Dictionary, t: float) -> void:
	var step := float(rec.roll_step)
	var ang := fposmod(t * float(rec.roll) + float(rec.phase) * 57.0, 360.0)
	var at := fposmod(roundf(ang / step) * step, 360.0)
	if is_equal_approx(at, float(rec.rolled)):
		return
	rec.rolled = at
	if rec.src == null:
		rec.src = load(String((rec.info as Dictionary).file)) as Texture2D
	if rec.src == null:
		return
	var deg := float(rec.turn_deg) + at
	var spr: Sprite2D = rec.sprite
	spr.texture = turned(StringName("%s" % (rec.info as Dictionary).file), rec.src, deg) if not is_zero_approx(fposmod(deg, 360.0)) else rec.src
	rec.tex_k = 1.0
	spr.scale = Vector2.ONE * float(rec.scale) * _scale
	rec.turn = deg_to_rad(deg)


## A ROCK OR A MOON FROM THE PLANET PAINTER: a PlanetView in a viewport of its
## own, lit each frame from the star, shown through a mask cut to the recipe's
## lumpy lobes with the cut darkened (a moon is the whole disc). A lumpy rock is
## not, unless the stage asks for the `planet` look: see `_rock`.
func _painter(rec: Dictionary, p: Dictionary, r: float, planet: bool = false) -> void:
	var r0 := float(p.r)
	var k := (r / r0) if r > 0.0 else 1.0
	var w := int(roundf(float(p.w) * k))
	var h := int(roundf(float(p.h) * k))
	if not planet and ROCK_RAMP.has(StringName(p.get("world", ""))) and not (p.get("lobes", []) as Array).is_empty():
		_rock(rec, p, k, w, h)
		return
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


## Each painter world's rock colours, darkest first (`Worlds.RAMP`).
const ROCK_RAMP := {&"rock": &"rock", &"moon": &"moon", &"cracked": &"ash"}
## Rock forms built (`rock_form`), by recipe and size.
static var _forms: Dictionary = {}


## A LUMPY ROCK WITH FORM (Jon: "kinda flat rock", "rock sucks kinda boring").
## The planet painter lit a round world and cut a lumpy outline out of it, so its
## light never followed the rock's own shape. Here the rock's own outline makes
## its shape (`rock_form`: a dome that follows the outline, waist and all), and
## the shader lights that from the star every frame (`local_subject.gdshader`,
## `rock`): a lit face in the world's own rock colours stepping down through a
## dithered terminator to a dark side, ridges and lumps from noise, craters with
## a bright lip toward the star and a shadowed bowl, and a rim caught in the
## star's colour -- then the scene's palette over it like every other piece.
func _rock(rec: Dictionary, p: Dictionary, k: float, w: int, h: int) -> void:
	var f := rock_form(p, k, w, h)
	var spr: Sprite2D = rec.sprite
	spr.texture = f.tex
	var mat: ShaderMaterial = rec.mat
	mat.set_shader_parameter("rock", true)
	var ramp := PackedVector3Array()
	for hex: String in Worlds.RAMP[ROCK_RAMP[StringName(p.world)]]:
		var c := Color(hex)
		ramp.append(Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("ramp", ramp)
	mat.set_shader_parameter("rock_seed", float(int(p.get("seed", 1)) % 97) * 7.31)
	mat.set_shader_parameter("craters", f.craters)
	mat.set_shader_parameter("n_craters", (f.craters as PackedVector4Array).size())
	mat.set_shader_parameter("grain", clampf(14.0 * k, 8.0, 22.0))


## The rock's shape as a normal map, built once per recipe and size: its lumpy
## outline (`lumpy_mask`), the distance in from that outline at every pixel
## eased into a rounded profile (so a two-lobed rock is two domes and a saddle,
## not one ball), smoothed, and its slope packed as RG (x, y; 0.5 is flat), B the
## depth in from the edge, A inside. And a few craters on it, where there is room:
## [x, y, radius, depth] in its own pixels. {tex, craters}
static func rock_form(p: Dictionary, k: float, w: int, h: int) -> Dictionary:
	var key := "%s|%s|%d|%d" % [p.get("seed", 0), p.get("world", ""), w, h]
	if _forms.has(key):
		return _forms[key]
	var mask := lumpy_mask(w, h, k, p)
	var n := w * h
	var inside := PackedByteArray()
	inside.resize(n)
	var d := PackedFloat32Array()
	d.resize(n)
	for y in h:
		for x in w:
			var i := y * w + x
			var a := mask.get_pixel(x, y).a > 0.5
			inside[i] = 1 if a else 0
			d[i] = 1e6 if a else 0.0
	# the distance in from the outline (chamfer, two passes)
	var D := 1.0
	var D2 := 1.4142
	for y in h:
		for x in w:
			var i := y * w + x
			if inside[i] == 0:
				continue
			var v := d[i]
			v = minf(v, (d[i - 1] if x > 0 else 0.0) + D)
			v = minf(v, (d[i - w] if y > 0 else 0.0) + D)
			v = minf(v, (d[i - w - 1] if x > 0 and y > 0 else 0.0) + D2)
			v = minf(v, (d[i - w + 1] if x < w - 1 and y > 0 else 0.0) + D2)
			d[i] = v
	var deepest := 1.0
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			if inside[i] == 0:
				continue
			var v := d[i]
			v = minf(v, (d[i + 1] if x < w - 1 else 0.0) + D)
			v = minf(v, (d[i + w] if y < h - 1 else 0.0) + D)
			v = minf(v, (d[i + w + 1] if x < w - 1 and y < h - 1 else 0.0) + D2)
			v = minf(v, (d[i + w - 1] if x > 0 and y < h - 1 else 0.0) + D2)
			d[i] = v
			deepest = maxf(deepest, v)
	# a rounded profile: steep at the edge, flattening over the top
	var R := deepest
	var ht := PackedFloat32Array()
	ht.resize(n)
	for i in n:
		if inside[i] == 0:
			continue
		var u := 1.0 - minf(d[i] / R, 1.0)
		ht[i] = sqrt(maxf(0.0, 1.0 - u * u)) * R * 0.9
	# smoothed (three box passes each way, a sixth of its depth wide), so the
	# crease the distance leaves down a lobe's middle rounds off into a dome
	var soft := maxi(2, int(R / 6.0))
	for blur in 3:
		ht = _blur(ht, w, h, soft, true)
		ht = _blur(ht, w, h, soft, false)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			if inside[i] == 0:
				continue
			var hl := ht[i - 1] if x > 0 else 0.0
			var hr := ht[i + 1] if x < w - 1 else 0.0
			var hu := ht[i - w] if y > 0 else 0.0
			var hd := ht[i + w] if y < h - 1 else 0.0
			var nrm := Vector3((hl - hr) * 0.5, (hu - hd) * 0.5, 1.0).normalized()
			img.set_pixel(x, y, Color(nrm.x * 0.5 + 0.5, nrm.y * 0.5 + 0.5, minf(d[i] / R, 1.0), 1.0))
	# CRATERS where there is room for one: well inside the outline, apart
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1)) * 977 + w
	var cr := PackedVector4Array()
	var want := clampi(int(float(w * h) / 5200.0), 3, 7)
	for tries in 200:
		if cr.size() >= want:
			break
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h - 1)
		var rad := roundf(rng.randf_range(3.5, 11.0) * clampf(k * 1.1, 0.7, 1.4))
		if inside[y * w + x] == 0 or d[y * w + x] < rad * 1.6:
			continue
		var ok := true
		for c4: Vector4 in cr:
			if Vector2(c4.x, c4.y).distance_to(Vector2(x, y)) < (c4.z + rad) * 1.25:
				ok = false
				break
		if ok:
			cr.append(Vector4(x, y, rad, rng.randf_range(0.6, 1.0)))
	var f := {tex = ImageTexture.create_from_image(img), craters = cr}
	_forms[key] = f
	return f


## A box blur `rad` px each side along rows (`across`) or columns, a running sum.
static func _blur(src: PackedFloat32Array, w: int, h: int, rad: int, across: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	var lines := h if across else w
	var length := w if across else h
	var step := 1 if across else w
	for l in lines:
		var base := l * w if across else l
		var s := 0.0
		for i in range(-rad, rad + 1):
			s += src[base + clampi(i, 0, length - 1) * step]
		for i in length:
			out[base + i * step] = s / float(rad * 2 + 1)
			s += src[base + clampi(i + rad + 1, 0, length - 1) * step] - src[base + clampi(i - rad, 0, length - 1) * step]
	return out


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
	# hosts before the pieces docked on them, which ride along
	var order: Array = []
	for rec: Dictionary in _placed:
		if rec.get("host") == null:
			order.append(rec)
	for rec: Dictionary in _placed:
		if rec.get("host") != null:
			order.append(rec)
	for rec: Dictionary in order:
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
		if float(rec.roll) != 0.0:
			_roll(rec, t)
		if bool(rec.tether):
			off = Vector2(0.0, sin(t * TAU / 29.0 + ph * 0.3) * 1.5)
		if rec.get("host") != null:
			off = (rec.host as Dictionary).off
		rec.off = off
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
	if _links != null:
		_links.queue_redraw()


## A point of a piece's own 1x picture, where it is on screen now (its turn, its
## tumble and its size taken in).
func _at(rec: Dictionary, a: Variant) -> Vector2:
	var p: Dictionary = rec.info
	var v := Vector2(float(a[0]) + 0.5, float(a[1]) + 0.5) - Vector2(float(p.w), float(p.h)) * 0.5
	var node: Node2D = rec.node
	v = v.rotated(float(rec.turn))
	# a ship turned to face the other way: its bow is on its right
	if (rec.sprite as Sprite2D).flip_h:
		v.x = -v.x
	return node.position + v.rotated(node.rotation) * float(rec.scale) * _scale


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
			var at := _at(rec, p.stern) + Vector2(-2.0 * k if (rec.sprite as Sprite2D).flip_h else 2.0 * k, 0.0)
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
