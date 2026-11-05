class_name LabAugment
extends Control

## THE LAB'S AUGMENT PAGE, on the big screen with the camera in the glass
## (science S9 part two; Jon's 1C, Nov 4). Your parts down a rail on the left,
## FITTED and then IN THE HOLD; the part in hand drawn large in the middle as a
## schematic; the Lab's three affixes for it branching off its mount on the
## right, each with what it does to your numbers; and the strip along the
## bottom naming the result and holding the one key that spends.
##
## PORTED FROM THE APPROVED MOCKUP (tk-scratch/science/sheet2/tree/build/
## build.py, `augment`, 2_augment_capital.png): the rail's 46 px rows, the
## phosphor parts, the 5x schematic with its cell grid and centreline, the
## affix rings at (700, 118/248/378), the strip's words and the AUGMENT key
## are drawn where and how it drew them.
##
## STRIP (open call 10) lives on the same page: an augmented part, or one with
## rolled affixes, has a STRIP key on its row. Pressed, the right side lists
## the part's own affixes instead of the offer, and the strip at the bottom
## names the one picked with its own STRIP key and bill: a pick, then a press.
##
## A PICK NEVER MOVES A PART. The rail is drawn, not made of the hold's icons,
## so there is nothing here to drag (HoldGrid's pick mode is the same rule for
## the grid). An augmented part is dimmed and cannot be picked for a second
## augment: picking it shows what can come off it.
##
## BUILT ONCE. The keys (AUGMENT or STRIP, the rows' STRIP keys, MORE) are
## made with the page and only moved, retitled, shown or hidden on a refresh,
## so a click survives the `resources_changed` its own purchase sends.

## Something that glows changed: whoever blooms it (`LabZoom`) redraws.
signal lit_changed

const W := 960
const H := 540
const T := 26
const GLASS := Rect2i(26, 26, 908, 488)
const BG := LabBoard.BG
const OWN := LabBoard.OWN
const OWN_D := LabBoard.OWN_D
const NEXT := LabBoard.NEXT
const NEXT_D := LabBoard.NEXT_D
const HOT := LabBoard.HOT
const LATER_T := LabBoard.LATER_T
const LATER_I := LabBoard.LATER_I
const LATER_R := LabBoard.LATER_R
const BAD := LabBoard.BAD
const ICE := LabBoard.ICE
const CHILL := LabBoard.CHILL
const NR := LabBoard.NR

## The rail: its pips' x, its first row, a row's pitch, and where it must end.
const RAIL_X := 44
const TOP := 62
const ROW := 46
const RAIL_END := 440
## The most rows a page of the rail can hold (the STRIP keys made for them).
const MAX_ROWS := 9
## The schematic's left edge and the line its middle sits on.
const SX := 396
const MID := 250
## The affix rings, three of them; more or fewer share the same column.
const NODE_X := 700
const NODE_Y := [118, 248, 378]
## The gauges in the words the strip uses (the panel's long names, but
## MANEUVER: the mockup's word, and the one that fits a ring's column).
const GAUGE_WORD := {&"hull": "HULL", &"reactor": "REACTOR", &"thrust": "THRUST",
	&"maneuver": "MANEUVER", &"thermal": "THERMAL", &"sensors": "SENSORS", &"stealth": "STEALTH"}

## `stationshot laboffer=a,b,c`: the offer shown, to set beside the mockup's.
static var forced_offer: Array[StringName] = []

static var _pics := {}

var tint := Color(190.0 / 255.0, 240.0 / 255.0, 235.0 / 255.0)
## The light pass (see LabBoard): only what glows.
var light := false
## Every box drawn, for the box test: [name, Rect2i].
var leaves: Array = []
## Every text's box, and every key's, for the test that no line crosses one.
var tboxes: Array = []
var phase := 0.0

## The part in hand, and what the page is doing with it.
var part: ModuleData = null
var mode: StringName = &"augment"
## Which affix on the right is picked (an index into `_affs`), and the one
## under the pointer.
var choice := 0
var hover_node := -1
var hover_row := -1
var page := 0
## What the last press did: {kind, affix, line, part}; empty when nothing was.
var done: Dictionary = {}

var commit_button: LabPlate
## The bill under the key, as drawn ("5 DATA + 15 CREDITS"): what a test reads.
var bill_words := ""
var more_button: LabPlate
var strip_buttons: Array[LabPlate] = []

## Read off the run on each refresh.
var _parts: Array = []      # [{m, where}]
var _pages: Array = []      # [[{m, where, y, cy, head}], ...]
var _rows: Array = []       # this page's
var _affs: Array[AffixData] = []
var _nodes: Array[Vector2i] = []
var _lines := PackedByteArray()
var _line_pts: Array = []   # [{pts, c, lit, style}]
var _live: Control
## Whether the line in from the rail had to run clear of the rail's words
## first: decided on the page's own draw, kept for the light pass.
var _lead := false
var _clock := 0.0
var _frame := -1


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_live = Control.new()
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.size = Vector2(W, H)
	_live.draw.connect(func() -> void:
		paint_live(_live)
		lit_changed.emit())
	add_child(_live)
	commit_button = LabPlate.new("AUGMENT", &"commit")
	commit_button.visible = false
	commit_button.pressed.connect(_commit)
	# ON THE KEY, THE STRIP READS WHAT THE KEY DOES: a ring left under the
	# pointer by a quick move onto the key kept the bill on that ring while a
	# press acted on the one picked
	commit_button.mouse_entered.connect(func() -> void:
		if hover_node >= 0 or hover_row >= 0:
			hover_node = -1
			hover_row = -1
			_restyle())
	add_child(commit_button)
	more_button = LabPlate.new("MORE", &"plate")
	more_button.visible = false
	more_button.size = Vector2(LabBoard.tw("MORE") + 14, 13)
	more_button.pressed.connect(func() -> void:
		page = (page + 1) % maxi(1, _pages.size())
		_relayout())
	add_child(more_button)
	for i in MAX_ROWS:
		var b := LabPlate.new("STRIP", &"plate")
		b.visible = false
		b.size = Vector2(LabBoard.tw("STRIP") + 14, 13)
		b.pressed.connect(_on_strip_key.bind(i))
		add_child(b)
		strip_buttons.append(b)
	mouse_exited.connect(func() -> void:
		if hover_node >= 0 or hover_row >= 0:
			hover_node = -1
			hover_row = -1
			_restyle())


# ------------------------------------------------------------------ the state

## Read the run again and put every key where it goes. Never builds a node.
func refresh() -> void:
	_parts.clear()
	var fitted: Array = []
	for m in Run.installed:
		fitted.append(m)
	fitted.sort_custom(func(a: ModuleData, b: ModuleData) -> bool:
		if a.slot != b.slot:
			return int(a.slot) < int(b.slot)
		return a.mount < b.mount)
	for m2 in fitted:
		_parts.append({m = m2, where = &"fitted"})
	var held: Array = []
	for h in Run.cargo:
		if h is ModuleData:
			held.append(h)
	held.sort_custom(func(a: ModuleData, b: ModuleData) -> bool:
		if a.hold_at.y != b.hold_at.y:
			return a.hold_at.y < b.hold_at.y
		return a.hold_at.x < b.hold_at.x)
	for m3 in held:
		_parts.append({m = m3, where = &"hold"})
	if part == null or not _has(part):
		part = _first_pick()
		mode = &"augment"
		choice = 0
		done = {}
	if part != null and part.augmented and mode == &"augment" and done.is_empty() and not part.affixes.is_empty():
		mode = &"strip"
		choice = 0
	_paginate()
	# the page the part in hand is on
	for i in _pages.size():
		for r: Dictionary in _pages[i]:
			if r.m == part:
				page = i
	page = clampi(page, 0, maxi(0, _pages.size() - 1))
	_relayout()


func _has(m: ModuleData) -> bool:
	for p: Dictionary in _parts:
		if p.m == m:
			return true
	return false


## The part the page opens on: the first that can still be augmented.
func _first_pick() -> ModuleData:
	for p: Dictionary in _parts:
		if not (p.m as ModuleData).augmented:
			return p.m
	return null if _parts.is_empty() else _parts[0].m


## The rail cut into pages that fit above the strip, the group's name at the
## top of each page it runs onto.
func _paginate() -> void:
	_pages = _cut(RAIL_END)
	if _pages.size() > 1:
		_pages = _cut(RAIL_END - 24)


func _cut(limit: int) -> Array:
	var out: Array = []
	var cur: Array = []
	var y := TOP
	var group := &""
	for p: Dictionary in _parts:
		var head := false
		if p.where != group or cur.is_empty():
			if y + 13 + 34 > limit or cur.size() >= MAX_ROWS:
				out.append(cur)
				cur = []
				y = TOP
			head = true
			group = p.where
			y += 13
		elif y + 34 > limit or cur.size() >= MAX_ROWS:
			out.append(cur)
			cur = []
			y = TOP + 13
			head = true
		cur.append({m = p.m, where = p.where, y = y, cy = y + ROW / 2 - 2, head = head})
		y += ROW
	if not cur.is_empty():
		out.append(cur)
	return out


## The offer, or the part's own affixes, and where their rings stand.
func _relayout() -> void:
	_rows = _pages[page] if page < _pages.size() else []
	_affs.clear()
	if part != null:
		if mode == &"strip":
			for a in part.affixes:
				_affs.append(a)
		elif not part.augmented or not done.is_empty():
			var n: MapGen.MapNode = Run.node_at()
			if done.get("kind", &"") == &"augment" and done.get("offer") != null:
				_affs.assign(done.offer)
			elif not forced_offer.is_empty():
				for id in forced_offer:
					var a := Science._affix(id)
					if a != null:
						_affs.append(a)
			elif n != null:
				_affs = Science.augment_offer(part, n)
	if choice >= _affs.size():
		choice = 0 if not _affs.is_empty() else -1
	if choice < 0 and not _affs.is_empty() and done.is_empty():
		choice = 0
	_nodes.clear()
	var ys := _node_ys(_affs.size())
	for y in ys:
		_nodes.append(Vector2i(NODE_X, y))
	_restyle()


static func _node_ys(n: int) -> Array:
	match n:
		0:
			return []
		1:
			return [248]
		2:
			return [183, 313]
		3:
			return NODE_Y.duplicate()
	var out: Array = []
	for i in n:
		out.append(104 + roundi(270.0 * i / float(n - 1)))
	return out


## The affix the strip is about: the ring under the pointer, else the one picked.
func shown() -> int:
	return hover_node if hover_node >= 0 else choice


# ------------------------------------------------------------------ the rules

## What a press would cost and whether it can be made: {data, credits, ok, why}.
func bill() -> Dictionary:
	var n: MapGen.MapNode = Run.node_at()
	if n == null or part == null:
		return {data = 0, credits = 0, ok = false, why = ""}
	if mode == &"strip":
		var c := Science.strip_cost(n)
		var a: AffixData = _affs[shown()] if shown() >= 0 and shown() < _affs.size() else null
		var ok := a != null and Science.can_strip(part, a, n)
		var why := ""
		if a != null and not ok and Run.data >= int(c.data) and Run.credits >= int(c.credits):
			why = "THE REACTOR WOULD COME UP SHORT. TAKE A PART OFF FIRST."
		return {data = int(c.data), credits = int(c.credits), ok = ok, why = why}
	var c2 := Science.augment_cost(n)
	return {data = int(c2.data), credits = int(c2.credits), ok = Science.can_augment(part, n), why = ""}


func _commit() -> void:
	var n: MapGen.MapNode = Run.node_at()
	# the affix the strip and its bill are about, whatever is under the pointer
	var at := shown()
	if part == null or n == null or at < 0 or at >= _affs.size():
		return
	choice = at
	var a: AffixData = _affs[at]
	var line := ""
	var offer: Array = _affs.duplicate()
	# (read before the press: after it, the part already carries the affix)
	var before := _stat_runs(a, mode == &"augment")
	# THE PRESS IS RECORDED BEFORE IT IS MADE: the service emits
	# `ship_changed`, and the refresh that runs inside it must already see
	# the page as done (else it reads a freshly augmented part as one to
	# strip, and turns the page over to STRIP under the player).
	var kind := mode
	done = {kind = kind, affix = a.name, line = "", part = part, offer = offer, before = before}
	if kind == &"strip":
		line = Science.strip(part, a, n)
	else:
		line = Science.augment(part, a, n)
	if line.is_empty():
		done = {}
		Audio.denied()
		_relayout()
		return
	Audio.play(&"fabricate", 0.04)
	mode = kind
	done.line = line
	if mode == &"strip":
		choice = -1
	refresh()


func _on_strip_key(i: int) -> void:
	if i >= _rows.size():
		return
	pick_part(_rows[i].m, &"strip")


## Put a part in hand (a click on its row, or its STRIP key).
func pick_part(m: ModuleData, want: StringName = &"augment") -> void:
	part = m
	done = {}
	choice = 0
	mode = want
	if m.augmented and want == &"augment" and not m.affixes.is_empty():
		mode = &"strip"
	_relayout()


## Put affix `i` on the right in hand.
func pick_affix(i: int) -> void:
	if i < 0 or i >= _affs.size():
		return
	choice = i
	done = {}
	_restyle()


# ------------------------------------------------------------------ numbers

## THE NUMBER AN AFFIX MOVES, for each gauge it touches: [what, before, after].
## A fitted part reads the ship's numbers with the affix put on (or taken off)
## for the question and back before anything can see it, emitting nothing (as
## `Science._powered_without` does); a part in the hold reads its own.
func _stat_runs(a: AffixData, adding: bool) -> Array:
	var out: Array = []
	if part == null or a == null:
		return out
	var fitted := Run.installed.has(part)
	var keep := part.affixes
	var with_a: Array[AffixData] = keep.duplicate()
	var without: Array[AffixData] = keep.duplicate()
	if adding:
		with_a.append(a)
	else:
		for i in without.size():
			if without[i].name == a.name:
				without.remove_at(i)
				break
	var gs := _gauges(a)
	for g: StringName in gs:
		part.affixes = without
		var lo := _read(g, fitted)
		part.affixes = with_a
		var hi := _read(g, fitted)
		part.affixes = keep
		var before: String = lo[1] if adding else hi[1]
		var after: String = hi[1] if adding else lo[1]
		out.append([lo[0], before, after])
	part.affixes = keep
	return out


## The gauges an affix moves, what it gains first.
static func _gauges(a: AffixData) -> Array:
	var up: Array = []
	var down: Array = []
	for g in AffixData.GAUGES:
		var pips: int = int(a.get(g))
		if pips > 0:
			up.append(g)
		elif pips < 0:
			down.append(g)
	return up + down


## [its name, its value as words] for gauge `g`: the ship's, or the part's own.
func _read(g: StringName, fitted: bool) -> Array:
	var m := part
	match g:
		&"hull":
			return ["MAX HULL", str(Run.max_hp())] if fitted else ["MAX HULL", "%+d" % (m.max_hull + m.affix_int(&"max_hull"))]
		&"maneuver":
			return ["DODGE", "%d%%" % roundi(Run.dodge() * 100.0)] if fitted \
				else ["DODGE", "%+d%%" % roundi((m.dodge + m.affix_raw(&"dodge")) * 100.0)]
		&"sensors":
			return ["SENSORS", str(Run.attr_sensors())] if fitted else ["SENSORS", "%+d" % (m.sensors + m.affix_int(&"sensors"))]
		&"stealth":
			return ["STEALTH", str(Run.attr_stealth())] if fitted else ["STEALTH", "%+d" % (m.stealth + m.affix_int(&"stealth"))]
		&"thrust":
			return ["THRUST", str(Run.attr_thrust())] if fitted else ["THRUST", "%+d" % (m.thrust + m.affix_int(&"thrust"))]
		&"reactor":
			return ["CELLS", str(Run.power_cap())] if fitted else ["REACTOR", "%+d" % (m.reactor + m.affix_int(&"reactor"))]
		&"thermal":
			return ["HEAT CAP", str(Run.heat_cap())] if fitted else ["HEAT CAP", "%+d" % (m.heat_cap + m.affix_int(&"heat_cap"))]
	return [String(g).to_upper(), "0"]


## "+1 HULL", "+2 MANEUVER, -1 HULL": the affix in the strip's words.
static func gauge_words(a: AffixData, sign: int = 1) -> String:
	var bits: PackedStringArray = []
	for g: StringName in _gauges(a):
		bits.append("%+d %s" % [int(a.get(g)) * sign, GAUGE_WORD.get(g, String(g).to_upper())])
	return ", ".join(bits)


## The part's name without its model number: KH-40 RIPSAW is the RIPSAW.
static func short_part(name: String) -> String:
	var keep: PackedStringArray = []
	for w in name.to_upper().split(" ", false):
		if not w.contains("0") and not w.contains("1") and not w.contains("2") and not w.contains("3") \
				and not w.contains("4") and not w.contains("5") and not w.contains("6") and not w.contains("7") \
				and not w.contains("8") and not w.contains("9"):
			keep.append(w)
	return " ".join(keep) if not keep.is_empty() else name.to_upper()


func _kind_line(p: ModuleData) -> String:
	var who := ""
	if p.manufacturer != &"" and DB.manufacturers.has(p.manufacturer):
		who = DB.short_name(DB.manufacturer_name(p.manufacturer)).to_upper() + " "
	var where := "FITTED" if Run.installed.has(p) else "IN THE HOLD"
	return "%s%s  ·  %s  ·  %d X %d CELLS" % [who, ModuleData.slot_name(p.slot).to_upper(), where, maxi(1, p.size.x), maxi(1, p.size.y)]


static func _affix_names(p: ModuleData) -> String:
	var bits: PackedStringArray = []
	for a in p.affixes:
		bits.append((a as AffixData).name.to_upper())
	return ", ".join(bits)


# ------------------------------------------------------------------ input

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	var f := int(floorf(_clock / LabBoard.FRAME_S)) % LabBoard.FRAMES
	if f != _frame:
		_frame = f
		phase = float(f) / float(LabBoard.FRAMES)
		_live.queue_redraw()


func hold_phase(p: float) -> void:
	set_process(false)
	phase = p
	_live.queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm != null:
		var nd := node_at(mm.position)
		var rw := row_at(mm.position) if nd < 0 else -1
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if nd >= 0 or rw >= 0 else Control.CURSOR_ARROW
		if nd != hover_node or rw != hover_row:
			hover_node = nd
			hover_row = rw
			_restyle()
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var nd2 := node_at(mb.position)
		if nd2 >= 0:
			pick_affix(nd2)
			Audio.click()
			accept_event()
			return
		var rw2 := row_at(mb.position)
		if rw2 >= 0:
			pick_part(_rows[rw2].m)
			Audio.click()
			accept_event()


## The affix ring under `p` (page px), or -1. None just after an augment:
## the part is done, and its rings only say what it got.
func node_at(p: Vector2) -> int:
	if done.get("kind", &"") == &"augment":
		return -1
	for i in _nodes.size():
		if p.distance_to(Vector2(_nodes[i])) <= NR + 4:
			return i
	return -1


## The rail row under `p`, or -1: its picture, its words, the room between.
func row_at(p: Vector2) -> int:
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if Rect2(RAIL_X - 4, int(r.y) + 1, 300, ROW - 4).has_point(p):
			return i
	return -1


# ------------------------------------------------------------------ restyle

## Every key to its place and word for what is on the page now.
func _restyle() -> void:
	for i in MAX_ROWS:
		var b := strip_buttons[i]
		var show := i < _rows.size() and not (_rows[i].m as ModuleData).affixes.is_empty() and not Run.science_off
		b.visible = show
		if show:
			var m: ModuleData = _rows[i].m
			var tx := RAIL_X + 82 + LabBoard.tw(_line2(m)) + 8
			b.position = Vector2(tx, int(_rows[i].cy) + 1)
			b.queue_redraw()
	more_button.visible = _pages.size() > 1
	if more_button.visible:
		more_button.position = Vector2(RAIL_X + 12, RAIL_END - 14)
	var show_commit := part != null and done.is_empty() and shown() >= 0 and shown() < _affs.size() \
		and (mode == &"strip" or not part.augmented)
	commit_button.visible = show_commit
	if show_commit:
		commit_button.label = "STRIP" if mode == &"strip" else "AUGMENT"
		commit_button.size = Vector2(150, 19)
		commit_button.position = Vector2(W - T - 14 - 150, 461)
		commit_button.disabled = not bool(bill().ok)
		commit_button.queue_redraw()
	queue_redraw()
	_live.queue_redraw()
	lit_changed.emit()


## A row's second line: the part's affixes, else what it is.
func _line2(m: ModuleData) -> String:
	if not m.affixes.is_empty():
		var s := _affix_names(m)
		if LabBoard.tw(s) > 170:
			s = "%d AFFIXES" % m.affixes.size()
		return s
	if m.augmented:
		return "AUGMENTED"
	return ModuleData.slot_name(m.slot).to_upper()


# ------------------------------------------------------------------ drawing kit

func _px(ci: CanvasItem, x: int, y: int, c: Color, lit: bool = false) -> void:
	if light and not lit:
		return
	ci.draw_rect(Rect2(x, y, 1, 1), c)


func _ring(ci: CanvasItem, cx: int, cy: int, r: int, c: Color, lit: bool = false, dash: int = 0, off: float = 0.0) -> void:
	if light and not lit:
		return
	for p in LabBoard.ring_pts(r):
		if dash > 0:
			var ang := atan2(p.y, p.x) / TAU + off
			if int(ang * dash * 2) % 2 != 0:
				continue
		ci.draw_rect(Rect2(cx + int(p.x), cy + int(p.y), 1, 1), c)


func _disc(ci: CanvasItem, cx: int, cy: int, r: int, c: Color) -> void:
	if light:
		return
	var lim := (r - 0.5) * (r - 0.5) + 0.25
	for dy in range(-r, r + 1):
		var half := -1
		for dx in range(0, r + 1):
			if dx * dx + dy * dy < lim:
				half = dx
		if half >= 0:
			ci.draw_rect(Rect2(cx - half, cy + dy, half * 2 + 1, 1), c)


func _dither_ring(ci: CanvasItem, cx: int, cy: int, r0: int, r1: int, c: Color, a0: float) -> void:
	for dy in range(-r1, r1 + 1):
		for dx in range(-r1, r1 + 1):
			var d := sqrt(float(dx * dx + dy * dy))
			if d >= r0 and d <= r1:
				var t := 1.0 - (d - r0) / maxf(1.0, float(r1 - r0))
				if t * a0 > LabBoard.bayer(cx + dx, cy + dy):
					ci.draw_rect(Rect2(cx + dx, cy + dy, 1, 1), c)


func _icon(ci: CanvasItem, name: String, cx: int, cy: int, c: Color, lit: bool = true) -> void:
	if light and not lit:
		return
	var rows: Array = LabIcons.ICONS.get(name, LabIcons.ICONS.get("STRIPPED"))
	var n := rows.size()
	var c2 := LabBoard.mixc(c, BG, 0.5)
	for j in n:
		var row: String = rows[j]
		for i in row.length():
			var ch := row[i]
			if ch == "#":
				ci.draw_rect(Rect2(cx - n / 2 + i, cy - n / 2 + j, 1, 1), c)
			elif ch == "+":
				ci.draw_rect(Rect2(cx - n / 2 + i, cy - n / 2 + j, 1, 1), c2)
			elif ch == "O":
				ci.draw_rect(Rect2(cx - n / 2 + i, cy - n / 2 + j, 1, 1), LabBoard.WHITE)


func _text(ci: CanvasItem, x: int, ycap: int, s: String, c: Color, sz: int = 8, lit: bool = false, name: String = "") -> int:
	var w := LabBoard.tw(s, sz)
	if light:
		if lit:
			LabBoard.text_at(ci, x, ycap, s, c, sz)
		return w
	LabBoard.text_at(ci, x, ycap, s, c, sz)
	var r := Rect2i(x, ycap - 1, w, (5 if sz == 8 else 10) + 2)
	leaves.append([name if name != "" else s, r])
	tboxes.append([name if name != "" else s, r])
	return w


## Words in several inks on one line, one box (the mockup's `runs`).
func _runs(ci: CanvasItem, x: int, ycap: int, parts: Array, name: String, lit: bool = false) -> int:
	var cx := x
	for p: Array in parts:
		var s: String = p[0]
		if not light or lit:
			LabBoard.text_at(ci, cx, ycap, s, p[1])
		cx += LabBoard.tw(s)
	if not light:
		var r := Rect2i(x, ycap - 1, cx - x, 7)
		leaves.append([name, r])
		tboxes.append([name, r])
	return cx - x


func _leaf(name: String, x: int, y: int, w: int, h: int) -> void:
	if not light:
		leaves.append([name, Rect2i(x, y, w, h)])


func _reticle(ci: CanvasItem, cx: int, cy: int, r: int, ry: int = -1) -> void:
	var r2 := ry if ry > 0 else r
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for k in 5:
				_px(ci, cx + sx * (r - k), cy + sy * r2, ICE, true)
				_px(ci, cx + sx * r, cy + sy * (r2 - k), ICE, true)


func ground_ink(a: float) -> Color:
	return LabBoard.mixc(BG, tint, a)


## THE QUIET WORDS' INK (the rail's heads, a part's kind, NO AFFIX YET): the
## mockup's ground ink at the capital, whose tint is a cold white, at every
## lab. In a warm lab's own tint they came out near the ember the prices and
## keys are drawn in, and read as things to press. The tint stays on rules.
const CAPITAL_TINT := Color(190.0 / 255.0, 240.0 / 255.0, 235.0 / 255.0)


static func word_ink(a: float) -> Color:
	return LabBoard.mixc(BG, CAPITAL_TINT, a)


## A one-pixel curve from `a` to `b`, x even and y eased (the mockup's lines).
static func _curve(a: Vector2, b: Vector2) -> Array[Vector2i]:
	var raw: Array[Vector2i] = []
	for i in 1501:
		var t := float(i) / 1500.0
		var q := Vector2i(LabBoard.pyround(a.x + (b.x - a.x) * t), LabBoard.pyround(a.y + (b.y - a.y) * (t * t * (3.0 - 2.0 * t))))
		if raw.is_empty() or raw[-1] != q:
			raw.append(q)
	var out: Array[Vector2i] = []
	for p in raw:
		if out.size() >= 2:
			var u := out[-2]
			var v := out[-1]
			if absi(p.x - u.x) == 1 and absi(p.y - u.y) == 1 and (v.x == u.x or v.y == u.y):
				out.pop_back()
		out.append(p)
	return out


func _path(ci: CanvasItem, pts: Array, c: Color, lit: bool, style: StringName, record: bool = true) -> void:
	var n := 0
	for p: Vector2i in pts:
		n += 1
		if record and not light and p.x >= 0 and p.y >= 0 and p.x < W and p.y < H:
			_lines[p.y * W + p.x] = 1
		if style == &"dash" and (n / 4) % 2 == 1:
			continue
		if style == &"dot" and n % 3 != 0:
			continue
		_px(ci, p.x, p.y, c, lit)


# ------------------------------------------------------------------ pictures

## A part's sprite as the mockup's phosphor (two inks off its own light and
## dark) or as its schematic at `k` times (outline, a line at each step of
## its shading, four flat tones). Two textures: as it looks, and what glows.
static func picture(m: ModuleData, kind: StringName, hi: Color, lo: Color, lit: bool, k: int = 1) -> Array:
	var key := "%s|%s|%s|%s|%s|%d" % [m.id, kind, hi.to_html(), lo.to_html(), lit, k]
	if _pics.has(key):
		return _pics[key]
	var img := _source(m)
	var out: Array
	if kind == &"schematic":
		out = _schematic(img, k)
	else:
		out = _phosphor(img, hi, lo, lit)
	_pics[key] = out
	return out


## The part's sprite as an image (or its footprint as a plain block, for a
## part with no art yet), halved when it is too long for the rail (`small`).
static func _source(m: ModuleData) -> Image:
	if m.sprite != null:
		var im := m.sprite.get_image()
		if im != null:
			im = im.duplicate()
			if im.is_compressed():
				im.decompress()
			im.convert(Image.FORMAT_RGBA8)
			return im
	var f := Vector2i(maxi(1, m.size.x), maxi(1, m.size.y)) * 20
	var b := Image.create(f.x, f.y, false, Image.FORMAT_RGBA8)
	b.fill(Color(0, 0, 0, 0))
	for y in range(3, f.y - 3):
		for x in range(2, f.x - 2):
			var edge := y == 3 or y == f.y - 4 or x == 2 or x == f.x - 3
			b.set_pixel(x, y, Color(0.8, 0.8, 0.8) if edge else Color(0.45, 0.45, 0.48))
	return b


## Half size, any opaque pixel of four kept, their colour averaged.
static func _halve(im: Image) -> Image:
	var w := im.get_width() / 2
	var h := im.get_height() / 2
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var acc := Color(0, 0, 0, 0)
			var n := 0
			var a := 0.0
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var c := im.get_pixel(x * 2 + d.x, y * 2 + d.y)
				a = maxf(a, c.a)
				if c.a * 255.0 > 40.0:
					acc += c
					n += 1
			out.set_pixel(x, y, Color(acc.r / n, acc.g / n, acc.b / n, a) if n > 0 else Color(0, 0, 0, 0))
	return out


static func _lum(c: Color) -> float:
	return c.r8 * 0.3 + c.g8 * 0.59 + c.b8 * 0.11


## numpy's percentile (linear) over sorted values.
static func _pct(v: Array, p: float) -> float:
	if v.is_empty():
		return 0.0
	var idx := p / 100.0 * (v.size() - 1)
	var lo := floori(idx)
	var hi := mini(lo + 1, v.size() - 1)
	return float(v[lo]) + (float(v[hi]) - float(v[lo])) * (idx - lo)


static func _phosphor(src: Image, hi: Color, lo: Color, lit: bool) -> Array:
	var im := src
	if im.get_width() > 64 or im.get_height() > 40:
		im = _halve(im)
	var w := im.get_width()
	var h := im.get_height()
	var vals: Array = []
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			if c.a8 > 40:
				vals.append(_lum(c))
	vals.sort()
	var lo_l := _pct(vals, 10.0)
	var hi_l := _pct(vals, 95.0)
	var full := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var glow := Image.create(w, h, false, Image.FORMAT_RGBA8)
	full.fill(Color(0, 0, 0, 0))
	glow.fill(Color(0, 0, 0, 0))
	var mid := LabBoard.mixc(lo, hi, 0.45)
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			if c.a8 <= 40:
				continue
			var t := (_lum(c) - lo_l) / maxf(1.0, hi_l - lo_l)
			var edge := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or im.get_pixel(q.x, q.y).a8 <= 40:
					edge = true
			var col: Color = hi if edge or t > 0.66 else (mid if t > 0.33 else lo)
			full.set_pixel(x, y, col)
			if lit and (edge or t > 0.66):
				glow.set_pixel(x, y, col)
	return [ImageTexture.create_from_image(full), ImageTexture.create_from_image(glow)]


static func _schematic(im: Image, k: int) -> Array:
	var w := im.get_width()
	var h := im.get_height()
	var vals: Array = []
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			if c.a8 > 40:
				vals.append(_lum(c))
	vals.sort()
	var qs := [_pct(vals, 30.0), _pct(vals, 60.0), _pct(vals, 85.0)]
	var band := PackedInt32Array()
	band.resize(w * h)
	for y in h:
		for x in w:
			var c := im.get_pixel(x, y)
			if c.a8 <= 40:
				band[y * w + x] = -1
				continue
			var b := 0
			var l := _lum(c)
			for q: float in qs:
				if l >= q:
					b += 1
			band[y * w + x] = b
	var bw := w * k
	var bh := h * k
	var full := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	var glow := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	full.fill(Color(0, 0, 0, 0))
	glow.fill(Color(0, 0, 0, 0))
	var step_c := LabBoard.mixc(BG, OWN, 0.62)
	var fills := [LabBoard.mixc(BG, OWN, 0.08), LabBoard.mixc(BG, OWN, 0.16), LabBoard.mixc(BG, OWN, 0.27), LabBoard.mixc(BG, OWN, 0.42)]
	var at := func(i: int, j: int) -> int:
		if i < 0 or j < 0 or i >= bw or j >= bh:
			return -1
		return band[(j / k) * w + (i / k)]
	for j in bh:
		for i in bw:
			var me: int = at.call(i, j)
			if me < 0:
				continue
			var edge := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if at.call(i + d.x, j + d.y) < 0:
					edge = true
			if edge:
				full.set_pixel(i, j, OWN)
				glow.set_pixel(i, j, OWN)
				continue
			var step := false
			for d2: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				if at.call(i + d2.x, j + d2.y) > me:
					step = true
			if step:
				full.set_pixel(i, j, step_c)
				glow.set_pixel(i, j, step_c)
			else:
				full.set_pixel(i, j, fills[me])
	# the row its body is widest on: the centreline's
	var best := 0
	var best_n := -1
	for y2 in h:
		var n := 0
		for x2 in w:
			if band[y2 * w + x2] >= 0:
				n += 1
		if n > best_n:
			best_n = n
			best = y2
	return [ImageTexture.create_from_image(full), ImageTexture.create_from_image(glow), best]


## The schematic's magnification for a part: the mockup's 5, less for a part
## too long or too tall for the middle of the glass.
static func scale_for(w: int, h: int) -> int:
	return clampi(mini(240 / maxi(1, w), 180 / maxi(1, h)), 1, 5)


# ------------------------------------------------------------------ the page

func _draw() -> void:
	leaves.clear()
	tboxes.clear()
	bill_words = ""
	_lines = PackedByteArray()
	_lines.resize(W * H)
	paint(self)


## The page's still parts onto `ci`: as it looks, or (`light`) what glows.
func paint(ci: CanvasItem) -> void:
	if Run.science_off:
		_text(ci, 380, 250, "THE LAB IS SHUT FOR THIS RUN.", CHILL)
		return
	var picked_at := Vector2i(-1, -1)
	var rail_right := 0
	# ---- your parts, on a rail down the left
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var m: ModuleData = r.m
		var cy: int = r.cy
		if r.head:
			_text(ci, RAIL_X + 12, int(r.y) - 13, "FITTED" if r.where == &"fitted" else "IN THE HOLD", word_ink(0.6))
		var picked := m == part
		var dim := m.augmented and not picked
		var hi: Color
		var lo: Color
		if dim:
			hi = LATER_T
			lo = LATER_R
		elif picked:
			hi = OWN
			lo = OWN_D
		else:
			hi = LabBoard.mixc(CHILL, tint, 0.3)
			lo = Color("#2d3d4f")
		var pic: Array = picture(m, &"phosphor", hi, lo, picked)
		var tex: Texture2D = pic[1] if light else pic[0]
		var tsz := Vector2i(tex.get_size())
		var ix := RAIL_X + 12 + (60 - tsz.x) / 2
		var iy := cy - tsz.y / 2
		if not light or picked:
			ci.draw_texture(tex, Vector2(ix, iy))
		_leaf("part " + m.name, ix, iy, tsz.x, tsz.y)
		var tx := RAIL_X + 82
		var name := m.name.to_upper()
		var name_c := ICE if picked or hover_row == i else (LATER_T if m.augmented else CHILL)
		var nw := _text(ci, tx, cy - 7, name, name_c, 8, picked)
		var l2 := _line2(m)
		var l2c: Color = OWN_D if not m.affixes.is_empty() else (LATER_T if m.augmented else word_ink(0.55))
		var l2w := _text(ci, tx, cy + 4, l2, l2c, 8, false, "line 2 of " + name)
		var right := tx + maxi(nw, l2w)
		if strip_buttons[i].visible:
			var b := strip_buttons[i]
			right = maxi(right, int(b.position.x + b.size.x))
			_leaf("[STRIP %s]" % name, int(b.position.x), int(b.position.y), int(b.size.x), int(b.size.y))
			if not light:
				tboxes.append(["[STRIP %s]" % name, Rect2i(b.position, b.size)])
		rail_right = maxi(rail_right, right)
		if picked:
			_reticle(ci, RAIL_X + 42, cy, 34, tsz.y / 2 + 4)
			picked_at = Vector2i(tx + maxi(nw, l2w) + 8, cy - 4)
			if strip_buttons[i].visible:
				picked_at.x = right + 8
		_ring(ci, RAIL_X, cy, 2, LATER_R if dim else hi, picked)
		_leaf("pip " + name, RAIL_X - 2, cy - 2, 5, 5)
	if not _rows.is_empty():
		var last: Dictionary = _rows[-1]
		var pts: Array[Vector2i] = []
		for yy in range(76, int(last.y) + ROW - 18):
			pts.append(Vector2i(RAIL_X, yy))
		_path(ci, pts, ground_ink(0.25), false, &"dot", false)
	if more_button.visible:
		var b2 := more_button
		_leaf("[MORE]", int(b2.position.x), int(b2.position.y), int(b2.size.x), int(b2.size.y))
		if not light:
			tboxes.append(["[MORE]", Rect2i(b2.position, b2.size)])
		_text(ci, int(b2.position.x + b2.size.x) + 8, int(b2.position.y) + 4, "%d OF %d" % [page + 1, _pages.size()], CHILL)
	if part == null:
		_text(ci, SX, 118, "NO PARTS ABOARD", ICE, 16)
		_text(ci, SX, 134, "FIT A PART OR CARRY ONE IN THE HOLD.", CHILL)
		_caption(ci)
		return
	# ---- the part, as a drawing, with its affixes branching off it
	var title := part.name.to_upper()
	var tsize := 16 if LabBoard.tw(title, 16) <= 270 else 8
	_text(ci, SX, 118, title, ICE, tsize, true)
	_text(ci, SX, 134, _kind_line(part), CHILL)
	var l3 := "NO AFFIX YET"
	if part.augmented:
		l3 = "AUGMENTED" + ("  ·  " + _affix_names(part) if not part.affixes.is_empty() else "")
	elif not part.affixes.is_empty():
		l3 = "HAS " + _affix_names(part)
	if LabBoard.tw(l3) > 270:
		l3 = ("AUGMENTED  ·  " if part.augmented else "HAS ") + "%d AFFIXES" % part.affixes.size()
	_text(ci, SX, 145, l3, word_ink(0.6))
	var src := _source(part)
	var k := scale_for(src.get_width(), src.get_height())
	var sch: Array = picture(part, &"schematic", OWN, OWN_D, true, k)
	var stex: Texture2D = sch[1] if light else sch[0]
	var sw := src.get_width() * k
	var sh := src.get_height() * k
	var sy := MID - sh / 2
	var gcol := ground_ink(0.32)
	var cell := 20 * k
	if not light:
		for gy in range(sy, sy + sh + 1, cell):
			for i2 in range(0, sw + 1, 3):
				_px(ci, SX + i2, gy, gcol)
		for gx in range(SX, SX + sw + 1, cell):
			for j2 in range(0, sh + 1, 3):
				_px(ci, gx, sy + j2, gcol)
		for c: Vector2i in [Vector2i(SX, sy), Vector2i(SX + sw, sy), Vector2i(SX, sy + sh), Vector2i(SX + sw, sy + sh)]:
			for t in range(-3, 4):
				_px(ci, c.x + t, c.y, ground_ink(0.6))
				_px(ci, c.x, c.y + t, ground_ink(0.6))
	ci.draw_texture(stex, Vector2(SX, sy))
	var cl: int = sy + int(sch[2]) * k + k / 2
	if not light:
		var n2 := 0
		for xx in range(SX - 12, SX + sw + 8):
			if (n2 % 9 < 5 or n2 % 9 == 6) and not (xx >= SX and xx < SX + sw):
				_px(ci, xx, cl, LabBoard.mixc(BG, OWN_D, 0.9))
			n2 += 1
	_leaf("schematic", SX - 4, sy - 4, sw + 9, sh + 9)
	# the line in from the rail; off the rail's words, all of them
	if picked_at.x >= 0:
		var a0 := Vector2(picked_at)
		var b0 := Vector2(SX - 16, cl)
		var pts2: Array[Vector2i] = _curve(a0, b0)
		if not light:
			_lead = _crosses(pts2)
		if _lead:
			var lead: Array[Vector2i] = []
			for xx2 in range(picked_at.x, rail_right + 9):
				lead.append(Vector2i(xx2, picked_at.y))
			pts2 = lead
			pts2.append_array(_curve(Vector2(rail_right + 8, picked_at.y), b0))
		_path(ci, pts2, OWN_D, true, &"dash")
	var hx := SX + sw + 18
	var hy := cl
	_ring(ci, hx, hy, 4, OWN, true)
	_px(ci, hx, hy, OWN, true)
	_leaf("mount", hx - 5, hy - 5, 11, 11)
	var stub: Array[Vector2i] = []
	for xs in range(SX + sw + 9, SX + sw + 14):
		stub.append(Vector2i(xs, hy))
	_path(ci, stub, OWN, true, &"solid")
	var b := bill()
	var s := shown()
	for i3 in _affs.size():
		var a: AffixData = _affs[i3]
		var nx := _nodes[i3].x
		var ny := _nodes[i3].y
		var st := _node_state(i3)
		var sel := i3 == s and st == &"next"
		var pts3 := _curve(Vector2(hx + 6, hy), Vector2(nx - NR - 6, ny))
		var lc := NEXT if sel else LabBoard.mixc(BG, NEXT, 0.45)
		if st == &"owned":
			lc = OWN
		elif st == &"later":
			lc = LabBoard.mixc(BG, LATER_R, 0.8)
		_path(ci, pts3, lc, sel or st == &"owned", &"solid" if sel or st == &"owned" else &"dash")
		_node_still(ci, nx, ny, a.name.to_upper(), st)
		_leaf("affix " + a.name, nx - NR - 5, ny - NR - 5, 2 * NR + 11, 2 * NR + 11)
		var tx2 := nx + NR + 16
		var an := a.name.to_upper()
		var ac := HOT if sel else (OWN if st == &"owned" else (LATER_T if st == &"later" else ICE))
		_text(ci, tx2, ny - 14, an, ac, 8, sel or st == &"owned")
		_text(ci, tx2, ny - 3, gauge_words(a, 1 if mode == &"augment" else -1), CHILL)
		var stats: Array = _stat_runs(a, mode == &"augment")
		if st == &"owned" and done.has("before"):
			stats = done.before
		for j3 in stats.size():
			var row: Array = stats[j3]
			_runs(ci, tx2, ny + 8 + 11 * j3, [["%s %s → " % [row[0], row[1]], CHILL], [row[2], OWN]],
				"stat %s %d" % [a.name, j3], sel)
	_caption(ci, b)


## How affix ring `i` stands: &"next" (in hand or yours to pick), &"short"
## (the bill can't be paid), &"owned" (just put on) or &"later" (passed over).
func _node_state(i: int) -> StringName:
	if not done.is_empty():
		if done.kind == &"augment":
			return &"owned" if _affs[i].name == done.affix else &"later"
		return &"plain"
	if mode == &"augment" and part.augmented:
		return &"later"
	var b := bill()
	var payable := Run.data >= int(b.data) and Run.credits >= int(b.credits)
	if i == shown():
		return &"next" if payable else &"short"
	return &"plain" if payable else &"short"


## Whether a line crosses any of the rail's words or keys.
func _crosses(pts: Array[Vector2i]) -> bool:
	for p in pts:
		for t: Array in tboxes:
			var r: Rect2i = t[1]
			if p.x >= r.position.x - 1 and p.x <= r.end.x and p.y >= r.position.y - 1 and p.y <= r.end.y:
				return true
	return false


func _node_still(ci: CanvasItem, x: int, y: int, name: String, st: StringName) -> void:
	match st:
		&"owned":
			_disc(ci, x, y, NR, LabBoard.mixc(BG, OWN, 0.2))
			_ring(ci, x, y, NR, OWN, true)
			_ring(ci, x, y, NR - 2, OWN_D)
			_icon(ci, name, x, y, OWN)
		&"next":
			_disc(ci, x, y, NR, LabBoard.mixc(BG, NEXT, 0.2))
			_ring(ci, x, y, NR, NEXT, true)
			_icon(ci, name, x, y, HOT)
		&"short":
			_disc(ci, x, y, NR, LabBoard.mixc(BG, NEXT, 0.07))
			_ring(ci, x, y, NR, LabBoard.mixc(NEXT, BG, 0.6))
			_icon(ci, name, x, y, LabBoard.mixc(HOT, BG, 0.5), false)
		&"plain":
			# an offer you can afford but have not picked: the mockup's
			# "short" ring lifted back to plain
			_disc(ci, x, y, NR, LabBoard.mixc(BG, NEXT, 0.07))
			_ring(ci, x, y, NR, LabBoard.mixc(BG, NEXT, 0.75))
			_icon(ci, name, x, y, LabBoard.mixc(HOT, BG, 0.25), false)
		_:
			_disc(ci, x, y, NR, BG)
			_ring(ci, x, y, NR, LATER_R, false, 16)
			_icon(ci, name, x, y, LATER_I, false)


func _node_live(ci: CanvasItem, x: int, y: int, st: StringName, p: float) -> void:
	match st:
		&"owned":
			var pr := NR + 2 + LabBoard.pyround(9.0 * p)
			_dither_ring(ci, x, y, pr, pr + 3, OWN_D if p > 0.5 else OWN, 1.0 - p)
		&"next":
			_dither_ring(ci, x, y, NR + 1, NR + 6, NEXT_D, 0.7 + 0.3 * sin(TAU * p))
			_ring(ci, x, y, NR + 4, LabBoard.mixc(BG, NEXT, 0.6), true, 12, p / 12.0)


## The strip under the page: the result in words, and the one key that spends.
func _caption(ci: CanvasItem, b: Dictionary = {}) -> void:
	for x in range(GLASS.position.x + 10, GLASS.end.x - 10):
		_px(ci, x, 446, ground_ink(0.3))
	if part == null:
		return
	var tx := 96
	var s := shown()
	var a: AffixData = _affs[s] if s >= 0 and s < _affs.size() else null
	if not done.is_empty():
		var st := &"owned" if done.kind == &"augment" else &"plain"
		_node_still(ci, 60, 480, String(done.affix).to_upper(), st)
		_leaf("caption icon", 60 - NR - 4, 480 - NR - 4, 2 * NR + 9, 2 * NR + 9)
		var t1 := "%s %s" % [String(done.affix).to_upper(), short_part(part.name)] if done.kind == &"augment" \
			else "%s IS OFF" % String(done.affix).to_upper()
		_text(ci, tx, 457, t1, OWN, 16, true)
		_text(ci, tx, 475, String(done.line).to_upper(), ICE)
		if done.kind == &"augment":
			_text(ci, tx, 487, "THE LAB DOES EACH PART ONCE. THIS ONE IS DONE.", CHILL)
		elif part.augmented:
			_text(ci, tx, 487, "THE MARK STAYS, SO THIS PART CAN'T BE AUGMENTED AGAIN.", CHILL)
		else:
			var n0: MapGen.MapNode = Run.node_at()
			_text(ci, tx, 487, "IT STILL SELLS FOR %d. ITS CARD IS UNCHANGED." % (Market.bid(n0, part) if n0 != null else part.scrap_value), CHILL)
		return
	if a == null:
		_text(ci, tx, 457, short_part(part.name), ICE, 16)
		if part.augmented:
			_text(ci, tx, 475, "THE LAB HAS AUGMENTED THIS PART. IT DOES EACH PART ONCE.", ICE)
			_text(ci, tx, 487, "NOTHING IS LEFT ON IT TO STRIP.", CHILL)
		else:
			_text(ci, tx, 475, "THE LAB HAS NOTHING TO OFFER FOR THIS PART.", ICE)
		return
	var payable := bool(b.get("ok", false))
	_node_live(ci, 60, 480, &"next" if payable else &"short", 0.35)
	_node_still(ci, 60, 480, a.name.to_upper(), &"next" if payable else &"short")
	_leaf("caption icon", 60 - NR - 4, 480 - NR - 4, 2 * NR + 9, 2 * NR + 9)
	var fitted := Run.installed.has(part)
	var stats: Array = _stat_runs(a, mode == &"augment")
	var goes: PackedStringArray = []
	for row: Array in stats:
		# (SENSORS go, the MAX HULL goes)
		var many := String(row[0]).ends_with("S")
		if row[1] == row[2]:
			goes.append("%s %s AT %s" % [row[0], "STAY" if many else "STAYS", row[2]])
		else:
			goes.append("%s %s %s TO %s" % [row[0], "GO" if many else "GOES", row[1], row[2]])
	var n: MapGen.MapNode = Run.node_at()
	var sells := Market.bid(n, part) if n != null else part.scrap_value
	if mode == &"strip":
		_text(ci, tx, 457, "STRIP %s" % a.name.to_upper(), HOT if payable else LabBoard.mixc(HOT, BG, 0.3), 16, true)
		var l1 := "%s ON THE PART." % gauge_words(a, -1)
		if fitted:
			l1 += " YOUR %s." % ", ".join(goes)
		_text(ci, tx, 475, l1, ICE)
		var why: String = b.get("why", "")
		if why != "":
			_text(ci, tx, 487, why, BAD)
		elif part.augmented:
			_text(ci, tx, 487, "THE MARK STAYS, SO THIS PART CAN'T BE AUGMENTED AGAIN.", CHILL)
		else:
			_text(ci, tx, 487, "IT STILL SELLS FOR %d. ITS CARD IS UNCHANGED." % sells, CHILL)
	else:
		_text(ci, tx, 457, "%s %s" % [a.name.to_upper(), short_part(part.name)], HOT if payable else LabBoard.mixc(HOT, BG, 0.3), 16, true)
		var l1b := "%s ON THE PART." % gauge_words(a)
		if fitted:
			l1b += " YOUR %s." % ", ".join(goes)
		else:
			l1b += " IT COUNTS ONCE YOU FIT IT."
		_text(ci, tx, 475, l1b, ICE)
		_text(ci, tx, 487, "ONCE PER PART. IT STILL SELLS FOR %d. ITS CARD IS UNCHANGED." % sells, CHILL)
	if commit_button.visible:
		var r := Rect2i(commit_button.position, commit_button.size)
		_leaf("[%s]" % commit_button.label, r.position.x, r.position.y, r.size.x, r.size.y)
		if light and not commit_button.disabled:
			var bl := commit_button.label
			LabBoard.text_at(ci, r.position.x + floori((r.size.x - LabBoard.tw(bl)) / 2.0),
				r.position.y + floori((r.size.y - 5) / 2.0), bl, HOT)
		var short_d := Run.data < int(b.data)
		var short_c := Run.credits < int(b.credits)
		var cost := [["%d " % int(b.data), BAD if short_d else LabBoard.OWN], ["DATA", CHILL],
			[" + %d " % int(b.credits), BAD if short_c else ICE], ["CREDITS", CHILL]]
		var cw := 0
		var words := ""
		for p: Array in cost:
			cw += LabBoard.tw(p[0])
			words += String(p[0])
		if not light:
			bill_words = words
		_runs(ci, r.position.x + (r.size.x - cw) / 2, 486, cost, "%s cost" % commit_button.label.to_lower())


## What moves round the page's loop: the halo of the affix in hand, and the
## pulse of one just put on.
func paint_live(ci: CanvasItem) -> void:
	if part == null or Run.science_off:
		return
	for i in _affs.size():
		var st := _node_state(i)
		_node_live(ci, _nodes[i].x, _nodes[i].y, st, fposmod(phase + 0.29 * i, 1.0))
	if not done.is_empty() and done.kind == &"augment":
		_node_live(ci, 60, 480, &"owned", phase)
	var s := shown()
	if s >= 0 and s < _nodes.size() and done.is_empty():
		_reticle(ci, _nodes[s].x, _nodes[s].y, NR + 8)


# ------------------------------------------------------------------ the tests

## THE MOCKUP'S BOX TEST on what is drawn now, with the header's boxes:
## every leaf inside the glass, no two overlapping, no line across a word or
## a key. Empty when it passes.
func check(extra: Array = []) -> PackedStringArray:
	var bad := PackedStringArray()
	var all: Array = leaves.duplicate()
	all.append_array(extra)
	for l: Array in all:
		if not GLASS.encloses(l[1]):
			bad.append("'%s' %s is outside the glass" % [l[0], l[1]])
	for i in all.size():
		for j in range(i + 1, all.size()):
			if (all[i][1] as Rect2i).intersects(all[j][1]):
				bad.append("'%s' overlaps '%s'" % [all[i][0], all[j][0]])
	if _lines.size() == W * H:
		for t: Array in tboxes:
			var r: Rect2i = t[1]
			var hit := false
			for x in range(r.position.x - 1, r.end.x + 1):
				for y in range(r.position.y - 1, r.end.y + 1):
					if x >= 0 and y >= 0 and x < W and y < H and _lines[y * W + x] != 0:
						hit = true
			if hit:
				bad.append("a line crosses '%s'" % t[0])
	return bad
