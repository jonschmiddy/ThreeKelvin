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
##           | ring | group | structure
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
##   pick    the stage's pieces are KEPT TAKES OF ONE THING (Jon kept more than
##           one): one of them is drawn, picked per system the way the sky's
##           looks are (`pick_of`: the system's index with the run's galaxy) --
##           the same take at the same system every visit in a run, another
##           take at another system, so every kept take gets seen
##   tumble  a slow tumble, degrees (single)
##   roll    single: turning right over, degrees a second, through the soft
##           turner -- never stepped
##   spin    single: a ring of modules spinning about its own axis, seconds a
##           turn (its index record's `spin`: the ring unwrapped into a strip;
##           `ring_spin.gdshader`), its modules travelling round it, the light
##           staying with the star, its own lights riding round with them
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
## A BIG STRUCTURE YOU ARE PULLING UP TO (`structure`; Jon's "Pulling up to it"
## page: a breaking frame, a repair yard, a clamp tower, a dead yard's cradle, a
## carcass). One picture (`kind` "structure" in the index, 400 x 530 at the
## ships' own pixel size) PINNED to the view's right edge -- its right edge `over`
## px past it, its row `anchor` level with your ship's middle -- so it runs off
## the top, the right and the bottom (under the band), from about x 540, and its
## nearest part is at your height. It never moves for a fight's wrecks: it stays
## BEHIND them (the hulls' row draws after this, and this takes no clicks), dimmed
## the way far pieces are while they are there. It zooms and blurs with the scene
## in the cutaway (`SectorScreen.open_cutaway` hands this control over whole).
## Lit by the star like any piece (`local_subject.gdshader`), but by its edges
## only: a light falling across 530 px would cross it in stepped bands.
##   pieces   [the structure's id]
##   with     [{piece, at (its centre, in the structure's own pixels), scale?,
##            far?, swim?, tumble?, flip?, turn?}]: kept pieces that belong to
##            it, pinned with it, drifting on their own clocks
##   cluster  {pieces, count, rect (Rect2, the structure's own pixels), size
##            [smallest, largest], turns, seed}: a loose knot of small things
##            on it (Jon on the whale's feeders: "more small and ... facing in
##            different directions"), each its own size, facing either way and
##            turned its own way, scattered through `rect` (not round a point),
##            clear of one another, swimming and turning a little through the
##            soft turner
##   add_lights  more `lights` this encounter adds (a berth lit where he waits),
##            each may carry a `cone` (a spill of light that long, leftward, at
##            `cone_k` of the lamp, default a half)
##   with ... and on each `with` entry any ship state (`lights`, `dark`, ...)
##   lines    [{from (the structure's own pixels), to (an index into `with`),
##            to_at (that piece's own 1x pixels)}]: mooring lines, slack
##   (any point on the structure -- a `with`'s `at`, a light's `at`, a line's
##   `from`, the grip's `at` -- may instead NAME one of its `anchors`, plus an
##   `off`: so kept takes of one structure, `pick`ed per system, each put these
##   on their own parts)
##   parted   {from, len, lean?}: a line parted at its far end, hanging and
##            drifting, trailing `lean` px aside at its end (default 8 leftward)
##   grip     {from_x | at}: one clamp's arm run out from the structure (from
##            its first metal on the arm's row near x `from_x`, or the named
##            part), level, all the way to your hull's bow, its jaws
##            on your bow (touching, never across it), a red fault lamp on them
##            -- the one thing that may touch your ship, as a clamp does. Its
##            lattice and jaw are the structure's own (`lattice`, `jaw`)
## Its life is in the index record, in its own pixels, all code and all light:
## `lights` (steady | breathe | blink | flicker | cycle | glint; a light with a
## `part` rides that moving part), `windows` (panes lit
## as their own glow), `glows` (light baked onto its surfaces, breathing),
## `sparks` (a cutting head that runs now and then), `parts` (pictures turned
## live about a pivot by the soft turner and eased: a boom's `sway` or `slide`, a
## cradle's arms on their `cycle`), `caps` (a layer over the parts), `swarm` (specks
## crawling its ribs).
##
## NOTHING IS DRAWN ACROSS ANYTHING ELSE (Jon: "why are they stacked on top of
## each other"; "it has to make sense where it stands"). No two pieces' opaque
## pixels come within the drift each can travel of one another (`mask_of`,
## `drift_of`, `clear_of`), except a piece on its own rock or round its own body,
## and a declared `dock`, which touches along an edge. `-- subjecttest` holds
## every subject to it.
## Lights, drives, floods and strobes are drawn in code over the art, as light
## (gathered, stepped and dithered, eased), never painted on the pictures. A
## piece's own lights are in its index record (`own_lights`, the structure's
## light kinds, at its own 1x pixels): they come round with it as it turns.

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
## A harness's override of `pick` (which kept take is drawn), or -1.
static var force_pick := -1

## Which option this draws, at which system (so a refresh only rebuilds when it
## changes).
var key := ""
var subject: Variant = null
## The encounter it is (its ships are picked by it) and the system's danger.
var oid: StringName = &""
var danger := 1
## the system it is drawn at (`LocalFx` finds the pulsar from it)
var node_index := -1
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
## A BIG STRUCTURE's record when the staging is one (pinned to the right edge,
## never moved for wrecks), else {}; your ship's middle row it was pinned to
## last; whether it is dimmed behind a fight's wrecks now; where its crawling
## specks are drawn (plain paint, over the pieces, under the lights).
var _st: Dictionary = {}
var _ship_y := -1.0
var _dimmed := false
var _life: Node2D = null
## The structure's screen rect, this frame (this control's own space).
var st_rect := Rect2()


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


## A planned piece's record as it is drawn: the index's, with a painter moon cut
## to a lumpy outline when its stage asks (`lumpy`, the outline's seed: the
## rocks' own recipe, `lumpy_mask`, round the moon's disc -- a comet's nucleus,
## a body of dirty ice, from the kept moon recipes).
static func rec_for(m: Dictionary) -> Dictionary:
	var p := piece_info(StringName(m.id))
	# (`world`: the moon recipe painted as another world -- a moon in pieces)
	if m.has("world") and String(p.get("kind", "")) == "painter":
		p = p.duplicate()
		p.world = String(m.world)
	if m.has("lumpy") and String(p.get("kind", "")) == "painter" and (p.get("lobes", []) as Array).is_empty():
		p = p.duplicate()
		p.lobes = [[float(p.cx), float(p.cy), float(p.r) * 1.17, float(m.lumpy)]]
		p.lo = 0.7
		p.amp = 0.34
	return p


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
## Deterministic, so a test can check it fits without a screen. `sys`: the
## system it is drawn at (its `pick`s are made by it), or -1.
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
		# A STAGE STOOD ON SOMETHING IN THE SKY (`anchor`): its pieces placed from
		# that, not from the subject's box -- the world you orbit's face (`near`,
		# `on` the point of it in its radii), its rings (`ring_arc`), or a line
		# out from the star (`star`, `d` px along it)
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
	var key := "%s|%s|%s|%s|%s|%s" % [id, sc, turn, r, flip, m.get("lumpy", "")]
	if _masks.has(key):
		return _masks[key]
	var p := rec_for(m)
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
			# (a kept piece with no small picture of its own: one made the flyby's
			# way, `small_image`)
			if base == 1.0 and sc <= 0.5 + 0.001 and img != null:
				var kk := 4 if sc <= 0.25 + 0.001 else 2
				var sm := small_image(path, kk)
				if sm != null:
					img = sm.duplicate()
					base = 1.0 / float(kk)
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


## Small pictures made here, by "path:k".
static var _smalls: Dictionary = {}


## A KEPT PICTURE AT 1/k, MADE THE FLYBY'S WAY (`tools/flyby_ships.py` `reduce`,
## which made the pool ships' own half and quarter pictures): each k x k block
## averaged by its cover, kept where it is at least half covered, and snapped to
## the picture's own commonest colours -- pixel art at its size, never every
## k-th pixel of the big one. For kept pieces drawn small that have no small
## picture of their own (a gutted frame in a ring, glazed hulls far off).
static func small_image(path: String, k: int) -> Image:
	var key := "%s:%d" % [path, k]
	if _smalls.has(key):
		return _smalls[key]
	var src := _image_of(path)
	if src == null:
		return null
	src = src.duplicate()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	# its own colours, the commonest 24 opaque ones
	var counts := {}
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a > 0.5:
				var hx := c.to_rgba32()
				counts[hx] = int(counts.get(hx, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return int(counts[a]) > int(counts[b]))
	var pal: Array[Color] = []
	for i in mini(24, keys.size()):
		var cc := Color.hex(int(keys[i]))
		pal.append(cc)
	var W := (w + k - 1) / k
	var H := (h + k - 1) / k
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for by in H:
		for bx in W:
			var cov := 0.0
			var acc := Vector3.ZERO
			for yy in k:
				for xx in k:
					var x := bx * k + xx
					var y := by * k + yy
					if x >= w or y >= h:
						continue
					var c := src.get_pixel(x, y)
					cov += c.a
					acc += Vector3(c.r, c.g, c.b) * c.a
			if cov / float(k * k) < 0.5:
				continue
			var avg := acc / maxf(cov, 1e-6)
			var best := Color(avg.x, avg.y, avg.z)
			var bd := 1e9
			for pc in pal:
				var d := Vector3(pc.r - avg.x, pc.g - avg.y, pc.b - avg.z).length_squared()
				if d < bd:
					bd = d
					best = pc
			best.a = 1.0
			out.set_pixel(bx, by, best)
	_smalls[key] = out
	return out


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
	if bool(m.get("structure", false)):
		return Vector2.ZERO
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
	# (turning right over, it sweeps the square of its diagonal)
	if float(m.get("roll", 0.0)) != 0.0:
		sz = Vector2.ONE * ceilf(sz.length())
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
		if rr_range.size() == 2 and String(piece_info(id).get("kind", "")) == "painter":
			pr = roundf(lerpf(float(rr_range[0]), float(rr_range[1]), R.randf()))
		var sz := turned_size(piece_size(id, pr), turn) * sc
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
## A stage of kept takes (`pick`) keeps the one take this system draws.
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


## WHICH KEPT TAKE A SYSTEM DRAWS, of `n` (a stage's `pick`): seeded from the
## system as its sky's looks are (`SkyBake.hash2` on its index, here with the
## run's galaxy too, so another run deals them again) and the encounter, so the
## same system shows the same take every visit, and the systems an encounter
## turns up at between them show all of them. `sys` -1 (no system): the first.
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


## A BIG STRUCTURE (see the header): the structure itself, at the middle of its
## own picture, and the kept pieces that go with it, each where its `at` puts it
## in the structure's own pixels -- all of them pinned with it.
static func _stage_structure(st: Dictionary) -> Array:
	var id := _piece(st, 0)
	var p := piece_info(id)
	var out: Array = [_m(id, Vector2.ZERO, 1.0, 0.0, {z = -100, structure = true, pinned = true, base_of = true})]
	# what this encounter adds to it: lamps, mooring lines, a parted line, a
	# clamp's arm -- their points on THIS structure's own parts (`_anchor_pt`:
	# a name of its `anchors`, so each kept take puts them on its own berth)
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
				if _clear(m, placed + out.slice(1)):
					placed.append(m)
					break
		out.append_array(placed)
	return out


## A POINT OF A STRUCTURE, as an encounter names it: its own pixels ([x, y] or
## a Vector2), or the name of one of its `anchors` (its index record's own parts:
## a dock face's cargo berth, its collar, the lugs under its mast), plus `off`.
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


## The radius LOCAL draws a giant you orbit at, near enough (`LocalSky`
## NEAR_GIANT_R), to plan a stage stood on it before it is drawn.
const NEAR_R := 150.0


## IN THE RINGS OF THE WORLD YOU ORBIT (`ring_arc`): each piece on the ring's
## far arc, where it shows past the world's limb above the event's band, at
## `u` across it (-1 its left end, 1 its right; past the limb is |u| over about
## a half) and `lift` px off the ring's middle line, at `size` (a quarter: far
## off, as big as hulls in a ring a hundred thousand kilometres across look).
## Planned with the giant at its usual size; drawn where the giant is
## (`_ring_point`).
static func _stage_ring_arc(st: Dictionary) -> Array:
	var out: Array = []
	var us: Array = st.get("u", [-0.6, 0.6])
	var lifts: Array = st.get("lift", [0.0])
	var sc := float(st.get("size", 0.25))
	for i in us.size():
		var u := float(us[i])
		var lift := float(lifts[i % lifts.size()])
		var m := _m(_piece(st, i), ring_point(u, lift, NEAR_R, 1.5, 2.2, 0.28).round(), sc, float(st.get("far", 0.3)),
			{z = i, flip = u > 0.0 if not st.has("flip") else bool(st.flip), ring_u = u, ring_lift = lift})
		out.append(m)
	return out


## A point on a ring's far arc, from the world's centre: `u` across it, `lift`
## px off its middle line, round a world of radius `r` whose ring runs from
## `rin` to `rout` of it, squashed to `open`.
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


## WHERE A STRUCTURE IS DRAWN in a view `view_size` with your ship's middle at
## `ship_y` (the view's own space): its picture's rect, the right edge `over` px
## past the view's, its `anchor` row level with your ship.
static func structure_rect(id: StringName, view_size: Vector2, ship_y: float) -> Rect2:
	return _structure_rect_of(piece_info(id), view_size, ship_y)


static func _structure_rect_of(p: Dictionary, view_size: Vector2, ship_y: float) -> Rect2:
	var w := float(p.get("w", 0))
	var h := float(p.get("h", 0))
	var at := Vector2(view_size.x + float(p.get("over", 1)) - w, ship_y - float(p.get("anchor", h * 0.5)))
	return Rect2(at.round(), Vector2(w, h))


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
## 1x if it fits there and at half size, dimmed as far off, if only that does
## (a quarter if not even half does).
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
	# (a quarter only when not even half fits: a ring turning right over sweeps
	# the square of its diagonal)
	for sc: float in [1.0, 0.5, 0.25]:
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
	cur.node_index = n.index
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
	_grip_image = null
	_tethers.clear()
	_pal_set = false
	_strobes.clear()
	_st = {}
	_dimmed = false
	_life = null
	_ship_y = -1.0
	var planned := plan(subject, oid, danger, node_index)
	_bounds = box_bounds(planned)
	var painted := LocalSky.style_now() == &"painted"
	cast.clear()
	for m: Dictionary in planned:
		var id := StringName(m.id)
		cast.append(id)
		var p: Dictionary = rec_for(m)
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
			turn_deg = turn, rolled = 1e9, src = null,
			# (`PixelTurn`, off unless asked: the pictures unturned, each turned with
			# its tumble in one go by `pixel_turn.gdshader`; its turner; its flip; the
			# turn it shows beyond its own, for its lights)
			orig = {}, turner = null, flip = bool(m.flip), vrot = 0.0, vshift = Vector2.ZERO,
			# (stood on something in the sky, `anchor`; its light on the beam's
			# pass or its glaze, `glint`; a lit window; a comet's tails from it)
			anchor = StringName(m.get("anchor", &"")), anchor_on = m.get("anchor_on", Vector2.ZERO),
			anchor_d = float(m.get("anchor_d", 0.0)), ring_u = float(m.get("ring_u", 0.0)), ring_lift = float(m.get("ring_lift", 0.0)),
			glint = StringName(m.get("glint", &"")), window = m.get("window", []), tail = bool(m.get("tail", false)),
			pts = [], blink_at = -99.0, st_i = int(m.get("st_i", 0)), id = id,
			# (its own lamps, from the index; which of a structure's `with` it is)
			own_lights = p.get("own_lights", []), with_i = int(m.get("with_i", -1))}
		for k4: String in ["st_add_lights", "st_lines", "st_parted", "st_grip"]:
			if m.has(k4):
				rec[k4] = m[k4]
		for k3: String in ["bake", "silhouette", "dust", "dirt"]:
			if m.has(k3):
				mat.set_shader_parameter(k3, float(m[k3]))
		var kind := String(p.get("kind", ""))
		if kind == "painter":
			_painter(rec, p, float(m.get("r", 0.0)), bool(m.get("planet", false)))
		else:
			var tex := load(String(p.file)) as Texture2D
			rec.orig[1.0] = tex
			rec.full = turned(id, tex, turn) if not is_zero_approx(turn) and tex != null else tex
			for size: String in ["half", "quarter"]:
				if p.has(size) and ResourceLoader.exists(String(p[size])):
					var hx := load(String(p[size])) as Texture2D
					rec.orig[0.5 if size == "half" else 0.25] = hx
					rec[size] = turned(StringName("%s_%s" % [id, size]), hx, turn) if not is_zero_approx(turn) and hx != null else hx
			# (drawn small with no small picture of its own: one made here)
			for kk: int in [2, 4]:
				var nm := "half" if kk == 2 else "quarter"
				if rec[nm] == null and float(m.scale) <= 1.0 / float(kk) + 0.001 and p.has("file"):
					var sm := small_image(String(p.file), kk)
					if sm != null:
						var stx := ImageTexture.create_from_image(sm)
						rec.orig[1.0 / float(kk)] = stx
						rec[nm] = turned(StringName("%s_%s_made" % [id, nm]), stx, turn) if not is_zero_approx(turn) else stx
			spr.texture = rec.full
			# A RING SPINNING ABOUT ITS OWN AXIS (`spin`, its stage's seconds a
			# turn; the index record's unwrapped strip): drawn by
			# `ring_spin.gdshader` into a picture of its own each frame
			if p.has("spin") and float(m.get("spin", 0.0)) > 0.0:
				_spin_setup(rec, p, float(m.spin))
		rec.pinned = bool(m.get("pinned", false))
		if kind == "structure":
			_structure_parts(rec, p)
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
	# (a clamp's arm repeats its lattice along itself: `_draw_grip`)
	_links.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_links.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_links.draw.connect(_draw_links)
	add_child(_links)
	# A STRUCTURE'S CRAWLING SPECKS, over it and what goes with it, in paint
	if not _st.is_empty():
		_life = Node2D.new()
		_life.draw.connect(_draw_life)
		add_child(_life)
	# THE LIGHTS go over everything else here, added to what is behind them
	_over = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_over.material = add
	_over.draw.connect(_draw_over)
	add_child(_over)
	# THE EFFECTS DRAWN IN CODE (`LocalFx`: a beam, a glare, a bank of dust, a
	# front, a comet's tails), behind the pieces; what they paint on a piece
	# (marks on a rock) over it
	if fx != null and is_instance_valid(fx):
		fx.leave()
	fx = null
	var fxs: Array = []
	for st: Dictionary in stages_of(subject):
		if StringName(st.get("stage", &"")) == &"fx":
			fxs.append(st)
	var tails := planned.any(func(m: Dictionary) -> bool: return bool(m.get("tail", false)))
	if not fxs.is_empty() or tails:
		fx = LocalFx.new()
		fx.sub = self
		add_child(fx)
		move_child(fx, 0)
		fx.build(fxs)
	_layout()


## THE SPIN (`_build`): a viewport the picture's size and `SPIN_PAD` px round
## it, a rect running `ring_spin.gdshader` over the index record's strip, and
## the piece shown through it -- still lit and paletted by its own material,
## its edge soft as the soft turner's.
const SPIN_PAD := 8
const SPIN_SHADER := preload("res://shaders/ring_spin.gdshader")


func _spin_setup(rec: Dictionary, p: Dictionary, secs: float) -> void:
	var sp: Dictionary = p.spin
	var strip := load(String(sp.strip)) as Texture2D
	var env := load(String(sp.env)) as Texture2D
	var geo := load(String(sp.geo)) as Texture2D
	if strip == null or env == null or geo == null:
		return
	var size := Vector2i(int(p.w) + 2 * SPIN_PAD, int(p.h) + 2 * SPIN_PAD)
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var r := ColorRect.new()
	r.size = Vector2(size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SPIN_SHADER
	for k: String in ["n", "m", "r0", "r1", "tilt"]:
		mat.set_shader_parameter(k, float(sp[k]))
	mat.set_shader_parameter("strip", strip)
	mat.set_shader_parameter("env", env)
	mat.set_shader_parameter("geo", geo)
	mat.set_shader_parameter("out_size", Vector2(size))
	mat.set_shader_parameter("pad", float(SPIN_PAD))
	mat.set_shader_parameter("centre", Vector2(float(sp.cx), float(sp.cy)))
	mat.set_shader_parameter("radii", Vector2(float(sp.ra), float(sp.rb)))
	r.material = mat
	vp.add_child(r)
	add_child(vp)
	rec.spin_mat = mat
	rec.spin_secs = secs
	rec.full = vp.get_texture()
	(rec.sprite as Sprite2D).texture = rec.full
	var smat: ShaderMaterial = rec.mat
	smat.set_shader_parameter("unpremul", true)
	smat.set_shader_parameter("snap_alpha", false)


## How far round a spinning ring has turned at `t`, radians.
static func spin_phi(rec: Dictionary, t: float) -> float:
	return t * TAU / maxf(float(rec.get("spin_secs", 75.0)), 1.0) + float(rec.get("phase", 0.0))


## Where a spinning ring's `i`th own light is now, in its picture's own pixels:
## its place on the strip (`spin.lamps`: angle, fraction across the band) taken
## round by the turn and back onto the ellipse, the band as thick as it is drawn
## there.
static func spin_at(p: Dictionary, i: int, phi: float) -> Array:
	var sp: Dictionary = p.spin
	var la: Array = (sp.lamps as Array)[i]
	var n := int(sp.n)
	var th := float(la[0]) + phi
	var j := int(floor(fposmod((th + PI) / TAU * float(n), float(n)))) % n
	var inner: Array = sp.inner
	var outer: Array = sp.outer
	var rr := float(inner[j]) + float(la[1]) * (float(outer[j]) - float(inner[j]))
	var rho := float(sp.r0) + rr / float(sp.m) * (float(sp.r1) - float(sp.r0))
	var e := Vector2(cos(th) * float(sp.ra), sin(th) * float(sp.rb)) * rho
	var q := Vector2(float(sp.cx), float(sp.cy)) + e.rotated(float(sp.tilt))
	return [q.x - 0.5, q.y - 0.5]


## The edge-only light a structure takes: the star's reach across it so long
## that no step of it falls inside the picture, so only the edges facing the star
## catch it (`span_px`; see the header).
const STRUCT_SPAN := 4000.0


## A STRUCTURE'S MOVING PARTS GLIDE (Jon, round two: "can the motion be more
## smooth?"; stepped poses and whole-pixel sways were the first round). Each
## part is a picture with its pivot at its middle (a boom's joint, an arm's
## shoulder), turned live about it by the soft turner (`PixelTurn.Turner`: 16
## points a pixel averaged, its edge partly clear -- the turn Jon picked for
## sprites), eased on its clock (`_structure_clock`), never rotated on screen
## and never stepped. Its own material, lit as the structure is. Then `caps`, a
## layer the structure's own size over them (the arms' shoulder discs).
func _structure_parts(rec: Dictionary, p: Dictionary) -> void:
	_st = rec
	rec.structure = true
	var mat: ShaderMaterial = rec.mat
	mat.set_shader_parameter("span_px", STRUCT_SPAN)
	var holder: Node2D = rec.node
	var parts: Array = []
	var mats: Array = []
	var half := Vector2(float(p.get("w", 0)), float(p.get("h", 0))) * 0.5
	for d: Dictionary in p.get("parts", []):
		var tex := load(String(d.file)) as Texture2D
		if tex == null:
			continue
		var m2 := mat.duplicate() as ShaderMaterial
		var soft := PixelTurn.soft_edge()
		m2.set_shader_parameter("unpremul", soft)
		m2.set_shader_parameter("snap_alpha", not soft)
		var tr := PixelTurn.Turner.new(self, tex, 1.0, false, int(d.get("pad", 0)))
		var s := Sprite2D.new()
		s.texture = tr.texture()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = true
		s.material = m2
		var pv: Array = d.get("pivot", [half.x, half.y])
		s.position = Vector2(float(pv[0]), float(pv[1])) - half
		holder.add_child(s)
		tr.turn(0.0)
		parts.append({sprite = s, def = d, turner = tr, shift = Vector2.ZERO, angle = 0.0})
		mats.append(m2)
	rec.parts = parts
	rec.extra_mats = mats
	if p.has("caps"):
		_layer(holder, String(p.caps), mat)


func _layer(holder: Node2D, file: String, mat: ShaderMaterial) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(file) as Texture2D
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.material = mat
	holder.add_child(s)
	return s


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
		if rec.host != null:
			(rec.host as Dictionary).hosting = true


## TWO CLAMPS where a docked piece meets its host: a short steel bar standing
## across the seam, lit on its top, dark round its edge.
func _draw_links() -> void:
	_draw_grip()
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


## Room round a turned piece's picture for its drift (`_turn`, BLENDED), px a side.
const DRIFT_PAD := 10


## A PIECE TURNED IN A PICTURE OF ITS OWN (`PixelTurn`, STEPPED or BLENDED; off
## unless asked): its own turn and this frame's tumble or roll (`rot`), turned
## in one go from the unturned picture its size draws, by `pixel_turn.gdshader`,
## and shown unrotated at 1:1. A mirrored piece turns the other way about its
## own turn (`Sprite2D` mirrors the turned picture). Its light is worked out in
## the screen's frame, as before (`to_star`, the caller).
func _turn(rec: Dictionary, rot: float, shift: Vector2) -> void:
	var t0 := Time.get_ticks_usec() if PixelTurn.cost_on else 0
	var k := float(rec.tex_k)
	var src: Texture2D = rec.orig.get(k, rec.orig.get(1.0))
	if src == null:
		return
	var px := float(rec.scale) * _scale / k
	var flip := bool(rec.flip)
	var tr: PixelTurn.Turner = rec.turner
	if tr == null or not tr.fits(src, px, flip):
		if tr != null:
			tr.free_all()
		tr = PixelTurn.Turner.new(self, src, px, flip, DRIFT_PAD)
		rec.turner = tr
	var own := float(rec.turn) * (-1.0 if flip else 1.0)
	tr.turn(own + rot, shift)
	var spr: Sprite2D = rec.sprite
	spr.texture = tr.texture()
	spr.scale = Vector2.ONE
	spr.flip_h = false
	var mat: ShaderMaterial = rec.mat
	var soft := PixelTurn.soft_edge()
	mat.set_shader_parameter("snap_alpha", not soft)
	mat.set_shader_parameter("unpremul", soft)
	# (as far across as the light reached on the turned picture it would have shown)
	mat.set_shader_parameter("span_px", maxf(turned_size(Vector2(src.get_size()), float(rec.turn_deg)).length() * 0.5 * px, 1.0))
	if PixelTurn.cost_on:
		PixelTurn.cpu_us += Time.get_ticks_usec() - t0


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
	# BLENDED (`PixelTurn`): a whole moon drifts inside its picture, a fraction of
	# a pixel at a time, so its surface's memory sees the drift as it sees the
	# turn (`_process`); room for it on every side
	var shards := StringName(p.world) == &"shattered"
	var pad := DRIFT_PAD if PixelTurn.world_mode == PixelTurn.Mode.BLENDED and (p.get("lobes", []) as Array).is_empty() and not shards else 0
	rec.drift_pv = pad > 0
	if shards:
		# A MOON IN PIECES (`ShatteredView`): its rubble reaches past the disc, so
		# its picture is as big as the painter says it reaches
		var hs := Worlds.half_size(&"shattered", r0 * k)
		pad = maxi(0, hs - mini(w, h) / 2 + 1)
	var vp := SubViewport.new()
	vp.size = Vector2i(w + 2 * pad, h + 2 * pad)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var pv: Node2D = Worlds.view_for(StringName(p.world))
	pv.position = Vector2(roundf(float(p.cx) * k) + pad, roundf(float(p.cy) * k) + pad)
	vp.add_child(pv)
	pv.call("set_world", StringName(p.world), int(p.seed), r0 * k)
	if shards:
		pv.call("set_cell", 1)
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
	elif what == NOTIFICATION_PREDELETE:
		# (what an effect asked of the sky -- the gas closed in -- goes with it)
		if fx != null and is_instance_valid(fx):
			fx.leave()


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
		# (an effect alone, drawn in code: the sky's weather, a beam)
		if fx != null:
			_t = 0.0 if DisplaySettings.reduced_motion else _clock()
			_frame_ctx()
			fx.step(_t)
		return
	var t := 0.0 if DisplaySettings.reduced_motion else _clock()
	var centre := Vector2.ZERO
	if not _st.is_empty():
		# A BIG STRUCTURE: pinned to the right edge at your ship's height, never
		# moved for the wrecks -- behind them, dimmed while they are there
		_pin()
		centre = st_rect.get_center()
	else:
		# out of the way of any wreck a fight left here (`fit`)
		var f := fit(_box, _bounds, _wrecks())
		centre = f.centre
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
					for m: ShaderMaterial in [rec.mat] + (rec.get("extra_mats", []) as Array):
						m.set_shader_parameter("pal", pal)
						m.set_shader_parameter("pal_n", pn)
	var star_col := Vector3(0.55, 0.55, 0.55) + tint * 0.45
	# WHAT THE SKY HOLDS THIS FRAME, in this control's own px: the star, the world
	# you orbit (what `anchor`ed stages stand on), your ship, the band's top
	_frame_ctx()
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
			rot = deg_to_rad(sin(t * TAU / 37.0 + ph) * float(rec.tumble) * PixelTurn.TUMBLE_K)
		# TURNED IN A PICTURE OF ITS OWN (`PixelTurn` STEPPED, BLENDED or a trial,
		# off unless asked): never rotated on screen; its tumble and its roll turned
		# with its own turn by `pixel_turn.gdshader` (`_turn`)
		var turning: bool = PixelTurn.turner() and rec.planet == null and not rec.orig.is_empty() \
				and (float(rec.tumble) > 0.0 or float(rec.roll) != 0.0)
		# STILL (a trial): never turned; the turn it would have shown goes to its light
		var still: bool = PixelTurn.mode == PixelTurn.Mode.STILL and rec.planet == null and not rec.orig.is_empty() \
				and not bool(rec.get("structure", false))
		if float(rec.roll) != 0.0:
			if turning or PixelTurn.roll_live or still:
				rot += deg_to_rad(fposmod(t * float(rec.roll) * PixelTurn.TUMBLE_K + float(rec.phase) * 57.0, 360.0))
			else:
				_roll(rec, t)
		if bool(rec.tether):
			off = Vector2(0.0, sin(t * TAU / 29.0 + ph * 0.3) * 1.5)
		if rec.get("host") != null:
			off = (rec.host as Dictionary).off
		if bool(rec.get("structure", false)):
			# (a structure stands where it is pinned; its parts move instead)
			off = Vector2.ZERO
			rot = 0.0
			_structure_clock(rec, t)
		rec.off = off
		var node: Node2D = rec.node
		var base := _base_of(rec, centre)
		node.position = (base + off).round()
		rec.vrot = 0.0
		rec.vshift = Vector2.ZERO
		if turning:
			# BLENDED: its drift turned in with it, a fraction of a pixel at a time and
			# held as the turn is, about where it rests -- unless it is docked or has
			# something docked on it, which keep to whole pixels together
			if PixelTurn.mode != PixelTurn.Mode.STEPPED and rec.get("host") == null and not bool(rec.get("hosting", false)):
				node.position = base.round()
				rec.vshift = base + off - node.position
			_turn(rec, rot, rec.vshift)
			rec.vrot = rot
			rot = 0.0
		elif bool(rec.get("drift_pv", false)) and rot == 0.0 and rec.get("host") == null and not bool(rec.get("hosting", false)):
			node.position = base.round()
			rec.vshift = base + off - node.position
			(rec.planet as PlanetView).set_drift(rec.vshift / (float(rec.scale) * _scale))
		var light_rot := 0.0
		if still:
			light_rot = rot * PixelTurn.LIGHT_K
			rot = 0.0
		node.rotation = rot
		var g := node.get_global_transform()
		var dirv := star - g.origin
		var ts := dirv.normalized() if dirv.length() > 1.0 else Vector2(-1.0, -0.4).normalized()
		var spr: Sprite2D = rec.sprite
		var local := ts.rotated(-rot - light_rot - float(rec.turn))
		if spr.flip_h:
			local.x = -local.x
		var mat: ShaderMaterial = rec.mat
		mat.set_shader_parameter("to_star", local)
		if still:
			# the glint: where the hull would catch the star, rolling across it as it
			# tumbles (end to end over a full swing of the tumble, or round with the roll)
			var tx := spr.texture
			var half := 0.5 * Vector2(tx.get_size()).length() if tx != null else 8.0
			var swing := deg_to_rad(maxf(float(rec.tumble) * PixelTurn.TUMBLE_K, 1.0)) * PixelTurn.LIGHT_K
			var u := sin(light_rot / swing * PI * 0.5) if float(rec.roll) == 0.0 else sin(light_rot)
			mat.set_shader_parameter("glint", 0.22 * (1.0 - absf(u) * 0.5))
			mat.set_shader_parameter("glint_at", u * half * 0.8)
			mat.set_shader_parameter("glint_w", maxf(1.0, half * 0.08))
		mat.set_shader_parameter("star_col", star_col)
		for m2: ShaderMaterial in rec.get("extra_mats", []):
			m2.set_shader_parameter("to_star", local)
			m2.set_shader_parameter("star_col", star_col)
		if rec.planet != null:
			(rec.planet as Node2D).call("step", t, Vector3(ts.x, ts.y, 0.47), 1.0)
		if rec.get("spin_mat") != null:
			(rec.spin_mat as ShaderMaterial).set_shader_parameter("phi", spin_phi(rec, t))
	_t = t
	if fx != null:
		fx.step(t)
	queue_redraw()
	if _over != null:
		_over.queue_redraw()
	if _links != null:
		_links.queue_redraw()
	if _life != null:
		_life.queue_redraw()


## This frame's sky, in this control's own px (`_frame_ctx`): the star's centre
## and drawn radius, the world you orbit ({at, r, ring_in, ring_out, open}, or {}),
## your ship's rect, the event band's top.
var star_l := Vector2(480.0, -40.0)
var star_r := 20.0
var near_l: Dictionary = {}
var ship_l := Rect2(-999.0, -999.0, 0.0, 0.0)
var band_y := 9999.0
## The effects drawn in code (`LocalFx`), or null.
var fx: LocalFx = null


func _frame_ctx() -> void:
	var inv := get_global_transform().affine_inverse()
	near_l = {}
	if sky != null and is_instance_valid(sky):
		star_l = inv * sky.star_global()
		star_r = sky.star_px() * inv.get_scale().x
		var ni := sky.near_info()
		if not ni.is_empty():
			near_l = ni.duplicate()
			near_l.at = inv * (ni.at as Vector2)
			near_l.r = float(ni.r) * inv.get_scale().x
	else:
		star_l = Vector2(size.x * 0.5, -40.0)
	var view := get_parent()
	ship_l = Rect2(-999.0, -999.0, 0.0, 0.0)
	if view != null and view.has_method(&"ship_view"):
		var sv := view.call(&"ship_view") as Control
		if sv != null and is_instance_valid(sv) and sv.is_inside_tree() and sv.has_method(&"ship_rect"):
			var r: Rect2 = sv.call(&"ship_rect")
			var g := sv.get_global_transform()
			ship_l = Rect2(inv * (g * r.position), (inv.get_scale() * g.get_scale()) * r.size)
	band_y = size.y - BAND


## Where a placed piece rests this frame, before its drift: in the subject's box,
## or stood on what its stage is anchored to.
func _base_of(rec: Dictionary, centre: Vector2) -> Vector2:
	var at: Vector2 = rec.at
	match StringName(rec.anchor):
		&"near":
			if not near_l.is_empty():
				return (near_l.at as Vector2) + (rec.anchor_on as Vector2) * float(near_l.r) + at * _scale
		&"ring":
			if not near_l.is_empty() and float(near_l.ring_out) > 0.0:
				return (near_l.at as Vector2) + ring_point(float(rec.ring_u), float(rec.ring_lift), float(near_l.r),
					float(near_l.ring_in), float(near_l.ring_out), float(near_l.open))
		&"star":
			# a line out from the star, through the subject's box
			var dirv := (centre - star_l)
			var d := dirv.normalized() if dirv.length() > 1.0 else Vector2(0.8, 0.6)
			return star_l + d * float(rec.anchor_d) + at.rotated(d.angle())
	return centre + at * _scale


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


## WHERE THE STRUCTURE IS THIS FRAME (`st_rect`): pinned to the right edge at
## your ship's middle row -- held unless your ship's row moves by more than a
## pixel and a half, so nothing shivers -- and dimmed behind a fight's wrecks.
func _pin() -> void:
	# (not while the cutaway has this zoomed: its rounding moves the ship's row
	# by fractions, and the structure holds still in the scene)
	if _ship_y < 0.0 or scale.is_equal_approx(Vector2.ONE):
		var y := _ship_mid()
		if _ship_y < 0.0 or absf(y - _ship_y) > 1.5:
			_ship_y = roundf(y)
	st_rect = _structure_rect_of(_st.info, size, _ship_y)
	var dim := not _wrecks().is_empty()
	if dim != _dimmed:
		_dimmed = dim
		for rec: Dictionary in _placed:
			for m: ShaderMaterial in [rec.mat] + (rec.get("extra_mats", []) as Array):
				m.set_shader_parameter("far", maxf(float(rec.far), WRECK_DIM) if dim else float(rec.far))


## How far toward the sky a structure is dimmed behind a fight's wrecks.
const WRECK_DIM := 0.35


## Your ship's middle row on LOCAL, in this control's own space (its slot's
## middle: the hull is drawn centred in it, and the slot does not bob). In the
## cutaway this control and the hulls' row are zoomed together, so it holds.
func _ship_mid() -> float:
	var view := get_parent()
	if view != null and view.has_method(&"ship_view"):
		var sv := view.call(&"ship_view") as Control
		if sv != null and is_instance_valid(sv) and sv.is_inside_tree() and sv.size.y > 0.0:
			return (get_global_transform().affine_inverse() * sv.get_global_rect().get_center()).y
	return size.y * 0.5


## A point of the structure's own picture, on screen now.
func _sp(a: Variant) -> Vector2:
	return st_rect.position + Vector2(float(a[0]) + 0.5, float(a[1]) + 0.5)


## THE STRUCTURE'S MOVING PARTS ON THEIR CLOCKS, turned or moved live and eased,
## never stepped: a boom swaying about its joint (`sway`: `deg` either way over
## `period` s, a sine); a boom sliding to and fro along its girder (`slide`:
## between `dx[0]` and `dx[1]` px, eased, by any fraction of a pixel -- the soft
## turner's shift, in its `pad`); a cradle's arms gliding shut and open again
## (`cycle`: `deg` at shut, eased by `cycle_close`).
func _structure_clock(rec: Dictionary, t: float) -> void:
	var cyc: Dictionary = (rec.info as Dictionary).get("cycle", {})
	for pt: Dictionary in rec.get("parts", []):
		var d: Dictionary = pt.def
		var a := 0.0
		var sh := Vector2.ZERO
		match String(d.get("anim", "")):
			"slide":
				var dx: Array = d.get("dx", [0, 0])
				sh.x = lerpf(float(dx[0]), float(dx[1]), 0.5 - 0.5 * cos(t * TAU / float(d.get("period", 9.0))))
			"sway":
				a = deg_to_rad(float(d.get("deg", 2.0))) * sin(t * TAU / float(d.get("period", 7.0)))
			"cycle":
				a = deg_to_rad(float(d.get("deg", 14.0))) * cycle_close(cyc, t)
		pt.shift = sh
		pt.angle = a
		(pt.turner as PixelTurn.Turner).turn(a, sh)


## How far shut a cradle's arms are at `t`, 0 open to 1 shut: open, held for
## `open` s; gliding shut over `move` s, eased in and out; shut on nothing for
## `shut` s; gliding open again; open for the rest of the `period`.
static func cycle_close(cyc: Dictionary, t: float) -> float:
	var period := float(cyc.get("period", 12.0))
	var open := float(cyc.get("open", 5.0))
	var move := maxf(float(cyc.get("move", 1.6)), 0.01)
	var shut := float(cyc.get("shut", 2.8))
	var u := fposmod(t, period)
	if u < open:
		return 0.0
	u -= open
	if u < move:
		return smoothstep(0.0, 1.0, u / move)
	u -= move
	if u < shut:
		return 1.0
	u -= shut
	if u < move:
		return 1.0 - smoothstep(0.0, 1.0, u / move)
	return 0.0


## How lit a cradle's cycle lamp is at `t`: dark while the arms rest open, then
## eased blinks from just before they move until just after they are open again.
static func cycle_lamp(cyc: Dictionary, t: float) -> float:
	var period := float(cyc.get("period", 12.0))
	var open := float(cyc.get("open", 5.0))
	var busy := float(cyc.get("move", 1.6)) * 2.0 + float(cyc.get("shut", 2.8))
	var u := fposmod(t, period) - (open - 0.6)
	if u < 0.0 or u > busy + 1.2:
		return 0.0
	return _blink(u, 1.0, 0.6)


## A light's weight at `t` (its `kind`; a `cycle` light follows the cradle).
func _light_k(l: Dictionary, t: float) -> float:
	var k := float(l.get("k", 1.0))
	var ph := float(l.get("phase", 0.0))
	match String(l.get("kind", "steady")):
		"breathe":
			return k * (0.78 + 0.22 * sin((t + ph) * TAU / float(l.get("period", 4.0))))
		"blink":
			return k * _blink(t + ph, float(l.get("period", 2.0)), float(l.get("on", 0.6)))
		"flicker":
			# steady, but once a `period` a quick eased dip, as a tired lamp does
			var per := float(l.get("period", 3.0))
			var u := fposmod(t + ph, per)
			return k * (1.0 - 0.55 * _blink(u - per * 0.7, per, 0.3))
		"cycle":
			return k * cycle_lamp((_st.info as Dictionary).get("cycle", {}), t) if not _st.is_empty() else 0.0
		"glint":
			# a glaze catching the light: a slow rise and fall over the first half
			# of its clock, then dark
			var per2 := float(l.get("period", 6.0))
			var u2 := fposmod(t + ph, per2) / per2
			var w := sin(clampf(u2 * 2.0, 0.0, 1.0) * PI)
			return k * w * w
	return k


## THE STRUCTURE'S LIGHTS, as light (added over it, under the hulls): its glows
## breathing on its surfaces, its windows (each pane its own even glow, never
## stepped across), its lamps, a cutting head's sparks.
func _draw_structure_light(t: float) -> void:
	var p: Dictionary = _st.info
	var dim := 1.0 - 0.5 * (WRECK_DIM if _dimmed else 0.0)
	for g: Dictionary in p.get("glows", []):
		var tex := _tex(String(g.file))
		if tex == null:
			continue
		var lo := float(g.get("lo", 0.6))
		var hi := float(g.get("hi", 1.0))
		var w := lerpf(lo, hi, 0.5 + 0.5 * sin(t * TAU / float(g.get("period", 5.0)))) * dim
		_over.draw_texture(tex, st_rect.position, Color(w, w, w, 1.0))
	var wc := Color(String(p.get("window_col", "#ffd9a0")))
	var wk := float(p.get("window_k", 0.6)) * dim
	for r: Array in p.get("windows", []):
		var rr := Rect2(st_rect.position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))
		_over.draw_rect(rr, Color(wc.r * wk, wc.g * wk, wc.b * wk, 1.0))
		_glow(rr.get_center(), maxi(int(maxf(rr.size.x, rr.size.y)) + 2, 3), wc, wk * 0.35)
	for px: Array in p.get("window_px", []):
		_over.draw_rect(Rect2(st_rect.position + Vector2(float(px[0]), float(px[1])), Vector2.ONE), Color(wc.r * wk, wc.g * wk, wc.b * wk, 1.0))
	for l: Dictionary in (p.get("lights", []) as Array) + (_st.get("st_add_lights", []) as Array):
		var at := _sp(l.at)
		# (riding a moving part: turned with it about its pivot, and slid with it)
		var parts: Array = _st.get("parts", [])
		if l.has("part") and int(l.part) < parts.size():
			var pt: Dictionary = parts[int(l.part)]
			var pv: Array = (pt.def as Dictionary).get("pivot", [0, 0])
			var c := st_rect.position + Vector2(float(pv[0]), float(pv[1]))
			at = c + (at - c).rotated(float(pt.angle)) + (pt.shift as Vector2)
		var col := Color(String(l.get("col", "#ffffff")))
		var e := _light_k(l, t) * dim
		if l.has("cone") and e > 0.01:
			# a spill of light out of it, leftward, falling off in dithered steps
			var tex := _cone_tex(int(l.cone))
			var sz := tex.get_size()
			var a2 := float(l.get("cone_k", 0.5)) * e
			_over.draw_texture(tex, (at - Vector2(sz.x, sz.y * 0.3)).round(), Color(col.r * a2, col.g * a2, col.b * a2, 1.0))
		_glow(at, int(l.get("r", 4)), col, e)
	var sp: Dictionary = p.get("sparks", {})
	if not sp.is_empty():
		_sparks(sp, t, dim)


## A CUTTING HEAD AT WORK (`sparks`; Jon: "Can we have the arm that makes the
## sparks actually interacting with the ship?"): every `period` s it runs for
## `run` s from `start`, eased in and out, where its rim meets the plating (`at`,
## riding the part that carries it, `part`) -- its nozzles burning blue-white, a
## hot spot on the plating, and sparks thrown off along the surface in cones
## (`degs`, each +- `spread`), each flying straight, fading over its own short
## life.
func _sparks(sp: Dictionary, t: float, dim: float) -> void:
	var period := float(sp.get("period", 12.0))
	var run := float(sp.get("run", 4.0))
	var u := fposmod(t, period) - float(sp.get("start", 4.0))
	if u < 0.0 or u > run:
		return
	var e := clampf(minf(u, run - u) / 0.35, 0.0, 1.0)
	var at := _sp(sp.at)
	# (riding the part that carries the head, as it moves)
	var parts: Array = _st.get("parts", [])
	if sp.has("part") and int(sp.part) < parts.size():
		at += (parts[int(sp.part)] as Dictionary).shift
	# the hot spot it makes on the plating it is cutting
	_glow(at, 16, Color(1.0, 0.55, 0.22), 0.5 * e * dim)
	var fl := 0.8 + 0.2 * sin(t * 37.0) * sin(t * 23.0)
	_glow(at, 10, Color(0.7, 0.88, 1.0), 0.85 * e * fl * dim)
	_glow(at, 3, Color(0.95, 0.98, 1.0), e * dim)
	var n := int(sp.get("count", 24))
	var degs: Array = sp.get("degs", [sp.get("deg", 90.0)])
	var spread := deg_to_rad(float(sp.get("spread", 45.0)))
	for i in n:
		var h1 := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(float(i) * 78.233) * 12543.1234, 1.0)
		var life := 0.45 + 0.6 * h1
		var age := fposmod(u + h2 * life, life)
		var gen := floorf((u + h2 * life) / life)
		# each new spark of this one flies its own way
		var h3 := fposmod(sin((float(i) + gen * 17.0) * 3.7) * 9631.77, 1.0)
		var base := deg_to_rad(float(degs[i % degs.size()]))
		var dir := Vector2.from_angle(base + (h3 * 2.0 - 1.0) * spread)
		var v := 28.0 + 50.0 * fposmod(h3 * 7.31, 1.0)
		var q := (at + dir * v * age).round()
		var a := (1.0 - age / life) * e * dim
		if a <= 0.02:
			continue
		var hot := Color(1.0, 0.85, 0.45).lerp(Color(1.0, 0.45, 0.15), age / life)
		_over.draw_rect(Rect2(q, Vector2.ONE), Color(hot.r * a, hot.g * a, hot.b * a, 1.0))
		if age < life * 0.4:
			_glow(q, 2, hot, a * 0.5)


## A STRUCTURE'S SWARM: specks crawling its ribs (`swarm.lines`, each a rib's
## centre [x, y, width] from top to bottom), each on its own rib, edge and pace,
## going up and down it a little and on along it slowly -- never still. A dark
## body a pixel or two, its back caught pale. Whole pixels, in paint.
func _draw_life() -> void:
	if _st.is_empty():
		return
	var sw: Dictionary = (_st.info as Dictionary).get("swarm", {})
	var lines: Array = sw.get("lines", [])
	if lines.is_empty():
		return
	var t := _t
	var n := int(sw.get("count", 30))
	var body := Color(0.11, 0.08, 0.09)
	var back := Color(0.62, 0.55, 0.52)
	if _dimmed:
		body = body.lerp(Color(0.035, 0.045, 0.075), WRECK_DIM)
		back = back.lerp(Color(0.035, 0.045, 0.075), WRECK_DIM)
	for i in n:
		var line: Array = lines[i % lines.size()]
		var h1 := fposmod(sin(float(i) * 91.7) * 4375.85, 1.0)
		var h2 := fposmod(sin(float(i) * 17.3) * 9137.11, 1.0)
		var m := float(line.size() - 1)
		# along the rib: a slow creep one way, a wander back and forth on top
		var s := fposmod(h1 * m + t * (0.05 + 0.12 * h2) * (1.0 if i % 2 == 0 else -1.0) + sin(t * (0.4 + h2) + h1 * 6.0) * 0.6, m)
		var k := int(s)
		var f := s - float(k)
		var a: Array = line[k]
		var b: Array = line[mini(k + 1, line.size() - 1)]
		var c := Vector2(lerpf(float(a[0]), float(b[0]), f), lerpf(float(a[1]), float(b[1]), f))
		var half := lerpf(float(a[2]), float(b[2]), f) * 0.5
		var side := -1.0 if h2 < 0.5 else 1.0
		var q := (st_rect.position + c + Vector2(side * (half + 0.5), 0.0)).round()
		var big := h1 > 0.45
		_life.draw_rect(Rect2(q, Vector2(2.0 if big else 1.0, 2.0 if big else 1.0)), body)
		_life.draw_rect(Rect2(q + Vector2(0.0 if side < 0.0 else (1.0 if big else 0.0), -1.0), Vector2.ONE), back)


## Pictures a structure's lights draw, loaded once.
static var _texs: Dictionary = {}


static func _tex(path: String) -> Texture2D:
	if not _texs.has(path):
		_texs[path] = load(path) as Texture2D
	return _texs[path]


## A point of a piece's own 1x picture, where it is on screen now (its turn, its
## tumble and its size taken in).
func _at(rec: Dictionary, a: Variant) -> Vector2:
	var p: Dictionary = rec.info
	var v := Vector2(float(a[0]) + 0.5, float(a[1]) + 0.5) - Vector2(float(p.w), float(p.h)) * 0.5
	var node: Node2D = rec.node
	v = v.rotated(float(rec.turn))
	# a ship turned to face the other way: its bow is on its right
	if bool(rec.flip):
		v.x = -v.x
	return node.position + (rec.vshift as Vector2) + v.rotated(node.rotation + float(rec.vrot)) * float(rec.scale) * _scale


## How big a light is drawn on this piece: smaller on far ones.
func _lk(rec: Dictionary) -> float:
	return float(rec.scale) * _scale


## THE LIGHTS, as light: each a glow gathered round a bright core, falling off in
## steps with a dithered edge (`_glow_tex`), added to what is under it, and eased
## on and off, never snapped (a hard blink reads as a fault).
func _draw_over() -> void:
	var t := _t
	if not _st.is_empty():
		_draw_structure_light(t)
	_draw_piece_light(t)
	for rec: Dictionary in _placed:
		var p: Dictionary = rec.info
		if not p.has("bow"):
			continue
		var k := _lk(rec)
		var dim := 1.0 - 0.6 * float(rec.far)
		if bool(rec.drive):
			# a drive at the stern, breathing a little
			var fl := 0.85 + 0.1 * sin(t * 5.1 + float(rec.phase)) + 0.05 * sin(t * 13.7 + float(rec.phase) * 2.0)
			var at := _at(rec, p.stern) + Vector2(-2.0 * k if bool(rec.flip) else 2.0 * k, 0.0)
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


## LIGHT ON A PIECE THAT IS NOT ITS OWN LAMPS, as light (eased, never snapped):
##   glint &"beam"   its high edge catching a pulsar's beam as it crosses
##                   (`LocalFx.beam_hit`): an instrument rack, a field's metal
##   glint &"glaze"  a thick glaze catching the light here and there, each
##                   point brightening and fading on its own slow clock
##   lights &"shaded" a cooked machine's last lights, on its shaded side only,
##                   each blinking once just after a flare of the star
##   window [x, y]   one lit window (someone listening), warm, breathing a
##                   little
func _draw_piece_light(t: float) -> void:
	for rec: Dictionary in _placed:
		var g := StringName(rec.glint)
		var dim := 1.0 - 0.6 * float(rec.far)
		var k := _lk(rec)
		if g != &"" and (rec.pts as Array).is_empty():
			rec.pts = _light_points(rec, &"top" if g == &"beam" else &"any", 4 if g == &"beam" else 3)
		if g == &"beam" and fx != null:
			var hit: float = fx.beam_hit((rec.node as Node2D).position)
			if hit > 0.01:
				for q: Array in rec.pts:
					_glow(_at(rec, q), roundi(5.0 * k) + 2, Color(0.75, 0.88, 1.0), 0.9 * hit * dim)
		elif g == &"glaze":
			var pts: Array = rec.pts
			for j in pts.size():
				var per := 4.0 + fposmod(float(j) * 1.37 + float(rec.phase), 3.0)
				var u := fposmod(t + float(j) * 2.11 + float(rec.phase) * 3.0, per) / per
				# a slow rise and fall over the first half of its clock, then dark
				var w := sin(clampf(u * 2.0, 0.0, 1.0) * PI)
				var hue := Color(0.7, 0.95, 0.9).lerp(Color(1.0, 0.8, 0.95), fposmod(float(j) * 0.37 + float(rec.phase), 1.0))
				_glow(_at(rec, pts[j]), roundi(4.0 * k) + 2, hue, 0.75 * w * w * dim)
		if StringName(rec.lights) == &"shaded":
			if (rec.pts as Array).is_empty():
				rec.pts = _light_points(rec, &"shaded", 3)
			# just after a flare of the star (`LocalSky`'s prominence), a blink
			var fl := float(sky._flare) if sky != null and is_instance_valid(sky) else 0.0
			if fl > 0.35 and t - float(rec.blink_at) > 4.0:
				rec.blink_at = t + 0.8
			var b := 0.0
			var since := t - float(rec.blink_at)
			if since >= 0.0 and since < 0.7:
				b = sin(since / 0.7 * PI)
			for q: Array in rec.pts:
				_glow(_at(rec, q), roundi(3.0 * k) + 1, Color(0.55, 0.95, 0.85), (0.45 + 0.5 * b) * dim)
		var wv: Array = rec.window
		if wv.size() == 2:
			var br := 0.72 + 0.08 * sin(t * TAU / 6.0 + float(rec.phase))
			_glow(_at(rec, wv), roundi(5.0 * k) + 2, Color(1.0, 0.72, 0.38), br * dim)
		# ITS OWN LIGHTS (the index's `own_lights`, at its own 1x pixels): they come
		# round with it as it turns (`_at` takes its turn, its tumble and its roll in)
		var lights: Array = rec.get("own_lights", [])
		for li in lights.size():
			var l: Dictionary = lights[li]
			# (on a spinning ring a pane rides round with its module)
			var at: Variant = l.at
			if rec.get("spin_mat") != null and li < ((rec.info as Dictionary).spin.lamps as Array).size():
				at = spin_at(rec.info, li, spin_phi(rec, t))
			_glow(_at(rec, at), maxi(1, roundi(float(l.get("r", 3)) * k)), Color(String(l.get("col", "#ffffff"))), _light_k(l, t) * dim)
	# A CLAMP'S ARM ON YOUR BOW: its fault lamp, red, blinking on the jaws
	var gp := grip_rect()
	if gp.size.x > 0.0:
		var gd: Dictionary = _st.get("st_grip", {})
		_glow(Vector2(gp.position.x + 6.0, gp.position.y + 3.0), 5, Color(String(gd.get("lamp", "#ff3b2f"))),
			(0.25 + 0.75 * _blink(t, 1.6, 0.7)) * (1.0 - 0.5 * (WRECK_DIM if _dimmed else 0.0)))


## Points of a piece's own 1x picture for light to land on, from its pixels:
## `top`, its high edge (a pixel with sky above it), spread along it; `shaded`,
## its edge on the side away from the star; `any`, its own metal, spread out.
func _light_points(rec: Dictionary, which: StringName, n: int) -> Array:
	var p: Dictionary = rec.info
	if not p.has("file"):
		return []
	var img := _image_of(String(p.file))
	if img == null:
		return []
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	# (headless keeps no shader settings: then from below the star's side)
	var ts: Variant = (rec.mat as ShaderMaterial).get_shader_parameter("to_star")
	var away := -(ts as Vector2) if ts is Vector2 else Vector2.ZERO
	if away.length() < 0.1:
		away = Vector2(0.6, 0.8)
	# (`to_star` is already in the picture's own frame, mirror and all)
	away = away.normalized()
	var cand: Array = []
	for y in range(1, h - 1, 1):
		for x in range(1, w - 1, 2):
			if img.get_pixel(x, y).a < 0.5:
				continue
			match which:
				&"top":
					if img.get_pixel(x, y - 1).a < 0.5:
						cand.append([x, y])
				&"shaded":
					var o := Vector2i((Vector2(x, y) + away * 2.0).round())
					if o.x < 0 or o.y < 0 or o.x >= w or o.y >= h or img.get_pixel(o.x, o.y).a < 0.5:
						cand.append([x, y])
				_:
					if (x * 7 + y * 13) % 5 == 0:
						cand.append([x, y])
	if cand.is_empty():
		return []
	cand.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var out: Array = []
	for i in n:
		var q: Array = cand[clampi(int((float(i) + 0.5) / float(n) * float(cand.size())), 0, cand.size() - 1)]
		out.append(q)
	return out


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


## YOUR HULL'S BOW on LOCAL, in this control's own space: the point just past
## the furthest-right opaque pixel of the middle half of your ship's rows (its
## nose), riding the ship's bob. INF when there is no ship to find. The scan is
## made once per picture (`_bow`); the bob is added each frame.
var _bow := {}


func bow_point() -> Vector2:
	var view := get_parent()
	if view == null or not view.has_method(&"ship_view"):
		return Vector2.INF
	var sv := view.call(&"ship_view") as ShipView
	if sv == null or not is_instance_valid(sv) or not sv.is_inside_tree():
		return Vector2.INF
	var img: Image = sv.canvas()
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return Vector2.INF
	var key := "%s|%s" % [img.get_size(), sv.ship_rect()]
	if String(_bow.get("key", "")) != key:
		var used := img.get_used_rect()
		var best := Vector2i(-1, -1)
		for y in range(used.position.y + int(used.size.y * 0.25), used.end.y - int(used.size.y * 0.25)):
			for x in range(used.end.x - 1, used.position.x - 1, -1):
				if img.get_pixel(x, y).a > 0.5:
					if x > best.x:
						best = Vector2i(x, y)
					break
		_bow = {key = key, x = best.x, y = best.y - sv.bob_offset()}
	if int(_bow.x) < 0:
		return Vector2.INF
	var kx := sv.canvas_width() / float(img.get_width())
	var origin := (sv.size - Vector2(sv.canvas_width(), sv.canvas_height())) * 0.5
	var p := origin + Vector2(float(_bow.x) + 1.0, float(int(_bow.y) + sv.bob_offset()) + 0.5) * kx
	return get_global_transform().affine_inverse() * (sv.get_global_transform() * p)


## A CLAMP'S ARM this frame (`grip`, see the header): from its jaws on your bow
## to where it leaves the structure, level with your bow; Rect2() when there is
## none.
func grip_rect() -> Rect2:
	if _st.is_empty() or not _st.has("st_grip"):
		return Rect2()
	var b := bow_point()
	if not b.is_finite():
		return Rect2()
	var lat := _tex(String((_st.info as Dictionary).get("lattice", "")))
	var h := float(lat.get_height()) if lat != null else 20.0
	var x0 := roundf(b.x)
	var gd: Dictionary = _st.st_grip
	var fx := float(gd.get("from_x", 156))
	# (from the structure's own metal on the arm's row: the first opaque pixel of
	# its picture there, near the named part -- so it never leaves from the air)
	var img := _grip_img()
	if img != null:
		var row := int(roundf(b.y - st_rect.position.y))
		if row >= 0 and row < img.get_height():
			for x in range(maxi(0, int(fx) - 24), mini(img.get_width(), int(fx) + 80)):
				if img.get_pixel(x, row).a > 0.5:
					fx = float(x)
					break
	var x1 := st_rect.position.x + fx
	if x1 <= x0:
		return Rect2()
	return Rect2(x0, roundf(b.y - h * 0.5), x1 - x0, h)


var _grip_image: Image = null


func _grip_img() -> Image:
	if _grip_image == null and not _st.is_empty():
		_grip_image = _image_of(String((_st.info as Dictionary).file))
		if _grip_image != null and _grip_image.is_compressed():
			_grip_image.decompress()
	return _grip_image


## The arm drawn (`_draw_links`): the structure's own jaw block pressed to your
## bow, then its own lattice repeated back to the structure, level, whole pixels.
func _draw_grip() -> void:
	var r := grip_rect()
	if r.size.x <= 0.0:
		return
	var info: Dictionary = _st.info
	var lat := _tex(String(info.get("lattice", "")))
	var jaw := _tex(String(info.get("jaw", "")))
	var mod := Color.WHITE.lerp(Color(0.035, 0.045, 0.075), WRECK_DIM) if _dimmed else Color.WHITE
	var jw := float(jaw.get_width()) if jaw != null else 0.0
	if lat != null:
		_links.draw_texture_rect(lat, Rect2(r.position.x + jw - 2.0, r.position.y, r.size.x - jw + 2.0, r.size.y), true, mod)
	if jaw != null:
		_links.draw_texture(jaw, Vector2(r.position.x, r.position.y + roundf((r.size.y - float(jaw.get_height())) * 0.5)), mod)


## THE TETHER: a dark line through the hung pieces, one pixel, from end to end.
## And a TOW LINE off a ship's bow: slack, sagging, a clamp at its end.
## And a structure's MOORING LINES (`lines`, to a piece that goes with it) and a
## PARTED LINE (`parted`), hanging from it and drifting slowly.
func _draw() -> void:
	if not _st.is_empty():
		_draw_moorings()
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


func _draw_moorings() -> void:
	var col := Color(0.34, 0.36, 0.4)
	if _dimmed:
		col = col.lerp(Color(0.035, 0.045, 0.075), WRECK_DIM)
	for ln: Dictionary in _st.get("st_lines", []):
		var to: Dictionary = {}
		for rec: Dictionary in _placed:
			if int(rec.get("with_i", -1)) == int(ln.get("to", 0)):
				to = rec
		if to.is_empty():
			continue
		var a := _sp(ln.from)
		var b := _at(to, ln.get("to_at", [0, 0]))
		var prev := a
		for i in range(1, 17):
			var u := float(i) / 16.0
			var q := a.lerp(b, u) + Vector2(0.0, sin(u * PI) * float(ln.get("sag", 3.0)))
			draw_line(prev.round(), q.round(), col, 1.0)
			prev = q
	var pl: Dictionary = _st.get("st_parted", {})
	if not pl.is_empty():
		# hanging from its lug, its free end swinging slowly, more the further down,
		# and trailing outward (`lean`, px at its end; leftward unless positive)
		var a := _sp(pl.from)
		var n := 24
		var len := float(pl.get("len", 40.0))
		var lean := float(pl.get("lean", -8.0))
		var prev := a
		for i in range(1, n + 1):
			var u := float(i) / float(n)
			var q := a + Vector2(sin(u * 2.4 + _t * TAU / 13.0) * 5.0 * u + u * lean, u * len)
			draw_line(prev.round(), q.round(), col, 1.0)
			prev = q
		draw_rect(Rect2((prev - Vector2(1.0, 0.0)).round(), Vector2(3, 2)), col.darkened(0.3))


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
