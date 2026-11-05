class_name LabBoard
extends Control

## THE LAB'S RESEARCH BOARD, AS A STAR CHART (science S9; Jon's 1C, Nov 4): the
## run's dealt board drawn on the Lab's big screen with the camera zoomed into
## the glass (`LabZoom`). Three arms, FRAME, CORE and DRIVE, spiral out of the
## FLIGHT COMPUTER on the galaxy's core; each arm is a branch's three steps in
## the order they are bought. A step that is running is teal and lit, the next
## one EMBER with its price (muted, its price red, when the DATA is short), and
## the steps after it dim. The strip at the bottom says what the step in hand
## does, and holds the one key that spends: BUY, on the next step only.
##
## PORTED FROM THE APPROVED MOCKUP, NOT REDRAWN: every position, ink, ring,
## dither, arm curve and label rule is `build.py`'s (tk-scratch/science/sheet2/
## tree/build/), on the same 960x540 board, so the screen is the picture Jon
## picked. The galaxy and the glass's finish are shaders (`lab_chart`,
## `lab_finish_*`); the icons are `LabIcons`. The labels go where the mockup's
## `Placer` puts them: off every step, every other label and every arm line,
## outward first, so what reads where depends on the deal and on nothing else.
##
## THE SAME BOARD AT EVERY LAB. The arms, the steps and the words stand where
## they stand at a capital and at an outpost; only the glass's tint changes.
##
## BUILT ONCE. The board is drawn, not made of nodes, except BUY: one Button,
## made with the board and only moved, retitled and shown or hidden, so a click
## on it survives the `resources_changed` its own purchase sends.

## Pressed BUY on branch `b`'s next step.
signal buy(b: int)

const W := 960
const H := 540
const T := 26
const GLASS := Rect2i(26, 26, 908, 488)

const BG := Color("#0a0e15")
const OWN := Color("#4fe0cc")
const OWN_D := Color("#1f6f66")
const NEXT := Color("#ff9d3d")
const NEXT_D := Color("#4a2a0c")
const HOT := Color("#ffd28a")
const EMBER := Color("#d97b29")
const LATER_T := Color("#7a8796")
const LATER_I := Color("#5c6876")
const LATER_R := Color("#4a5a6c")
const BAD := Color("#c8503c")
const DOT := Color("#71839a")
const ICE := Color("#c3d2e2")
const CHILL := Color("#8fa3ba")
const WHITE := Color("#ffffff")

const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

const BRANCH := ["FRAME", "CORE", "DRIVE"]
## The flight computer, on the galaxy's core.
const CX := 480
const CY := 250
## The disc, tipped like the chart's galaxy.
const SX := 1.12
const SY := 0.47
## An arm turns 48 degrees each 120 px out.
const WIND := 0.006981317007977318
## A step's distance out along its arm.
const RHO := [150, 250, 350]
## Where each arm leaves the core, its first step 120 degrees from the next:
## FRAME up-left and falling left, CORE right and climbing, DRIVE down and
## running right (the mockup's search for the most room between steps).
const PHI0 := [1.0471975511965976, -1.0471975511965976, 3.141592653589793]
## A step's ring (41 px across) and the flight computer's (63 px).
const NR := 20
const HR := 31
## Where the board's labels may stand.
const TREE := Rect2i(36, 62, 888, 378)
## The board's loop: the mockup's sixteen frames at 90 ms each, stepped, so
## the pulses move in whole pixels at the rate Jon saw them.
const FRAMES := 16
const FRAME_S := 0.09
## How long the step just bought flashes.
const FLASH_S := 1.5

## The lab's screen tint (labs.json `screen.tint`, 0..1): the arm names and
## the rules take it, so each lab's screen keeps its own colour.
var tint := Color(190.0 / 255.0, 240.0 / 255.0, 235.0 / 255.0)
## The one key that spends.
var buy_button: LabPlate
## The step under the pointer, and the one clicked (Vector2i(branch, step)).
var hover := Vector2i(-1, -1)
var pick := Vector2i(-1, -1)
## The step just bought: the strip says it runs from the next fight.
var bought := Vector2i(-1, -1)
var _flash_until := -1.0

## This board's deal and state, read off Run on each refresh.
var _names: Array = []       # [b][k] -> the routine's name
var _texts: Array = []       # [b][k] -> what it does
var _owned := [0, 0, 0]
var _data := 0
var _sig := ""
## The layout made for that state: steps, arm pixels, labels.
var _nodes := {}             # Vector2i(b, k) -> Vector2i
var _segs := {}              # Vector2i(b, k) -> Array[Vector2i]
var _lines := PackedByteArray()
var _labels: Array = []      # {x, ycap, s, c, size, name}
var _price_marks: Array = [] # {x, y, c}
## Every box drawn, as the mockup's box test has them: [name, Rect2i].
var leaves: Array = []
## Every text's box, for the test that no word crosses an arm.
var tboxes: Array = []
var _live: Control
var _clock := 0.0
var _frame := -1
var phase := 0.0

static var _rings := {}
static var _dithers := {}
static var _font: Font = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(W, H)
	_live = Control.new()
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live.size = Vector2(W, H)
	_live.draw.connect(func() -> void: _draw_live(_live))
	add_child(_live)
	buy_button = LabPlate.new("BUY", &"commit")
	buy_button.visible = false
	buy_button.pressed.connect(_on_buy)
	add_child(buy_button)
	mouse_exited.connect(func() -> void:
		if hover != Vector2i(-1, -1):
			hover = Vector2i(-1, -1)
			_restyle())


# ------------------------------------------------------------------ the kit

static func font() -> Font:
	if _font == null:
		_font = UITheme.pixel_font()
	return _font


## A run's advance in the pixel font, as the mockup's `tw` measured it.
static func tw(s: String, sz: int = 8) -> int:
	return int(font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x)


static func mixc(a: Color, b: Color, t: float) -> Color:
	var c := a.lerp(b, t)
	return Color8(roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0))


## Python's round, halves to even: the mockup placed its labels with it.
static func pyround(v: float) -> int:
	var f := floorf(v)
	var d := v - f
	if d > 0.5:
		return int(f) + 1
	if d < 0.5:
		return int(f)
	return int(f) if posmod(int(f), 2) == 0 else int(f) + 1


static func bayer(x: int, y: int) -> float:
	return float(BAYER[posmod(y, 4)][posmod(x, 4)]) / 16.0


static func disc_xy(rho: float, phi: float) -> Vector2:
	return Vector2(CX + rho * cos(phi) * SX, CY - rho * sin(phi) * SY)


static func arm_pt(b: int, rho: float) -> Vector2:
	return disc_xy(rho, float(PHI0[b]) + WIND * rho)


static func node_xy(b: int, k: int) -> Vector2i:
	var p := arm_pt(b, float(RHO[k]))
	return Vector2i(pyround(p.x), pyround(p.y))


## The pixels of a ring r across its middle, as the mockup set them.
static func ring_pts(r: int) -> PackedVector2Array:
	if not _rings.has(r):
		var pts := PackedVector2Array()
		for dy in range(-r - 1, r + 2):
			for dx in range(-r - 1, r + 2):
				var d := sqrt(float(dx * dx + dy * dy))
				if d >= r - 0.5 and d < r + 0.5:
					pts.append(Vector2(dx, dy))
		_rings[r] = pts
	return _rings[r]


## An arm from `r0` to `r1` out, sampled and rounded to pixels with its
## L-corners dropped: a clean one-pixel line (the mockup's `pixel_path`).
static func arm_path(b: int, r0: float, r1: float, steps: int = 1500) -> Array[Vector2i]:
	var raw: Array[Vector2i] = []
	for i in steps + 1:
		var p := arm_pt(b, r0 + (r1 - r0) * float(i) / float(steps))
		var q := Vector2i(pyround(p.x), pyround(p.y))
		if raw.is_empty() or raw[-1] != q:
			raw.append(q)
	var out: Array[Vector2i] = []
	for p in raw:
		if out.size() >= 2:
			var a := out[-2]
			var c := out[-1]
			if absi(p.x - a.x) == 1 and absi(p.y - a.y) == 1 and (c.x == a.x or c.y == a.y):
				out.pop_back()
		out.append(p)
	return out


## THE LIGHT PASS: the board draws twice, once as it looks and once with only
## what glows (`lit`), which `LabZoom` blurs into the mockup's bloom. Every
## helper below skips what is not lit while this is on.
var light := false


func _px(ci: CanvasItem, x: int, y: int, c: Color, a: float = 1.0, lit: bool = false) -> void:
	if light and not lit:
		return
	ci.draw_rect(Rect2(x, y, 1, 1), Color(c, a) if a < 1.0 else c)


func _ring(ci: CanvasItem, cx: int, cy: int, r: int, c: Color, dash: int = 0, off: float = 0.0, lit: bool = false) -> void:
	if light and not lit:
		return
	for p in ring_pts(r):
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


## A soft halo from r0 out to r1, faded in dithered steps. It glows.
func _dither_ring(ci: CanvasItem, cx: int, cy: int, r0: int, r1: int, c: Color, a0: float) -> void:
	var key := r0 * 1000 + r1
	if not _dithers.has(key):
		var cells := []
		for dy in range(-r1, r1 + 1):
			for dx in range(-r1, r1 + 1):
				var d := sqrt(float(dx * dx + dy * dy))
				if d >= r0 and d <= r1:
					cells.append(Vector3(dx, dy, 1.0 - (d - r0) / maxf(1.0, float(r1 - r0))))
		_dithers[key] = cells
	for v: Vector3 in _dithers[key]:
		var x := cx + int(v.x)
		var y := cy + int(v.y)
		if v.z * a0 > bayer(x, y):
			ci.draw_rect(Rect2(x, y, 1, 1), c)


func _bitmap(ci: CanvasItem, rows: Array, x: int, y: int, c: Color, c2: Color, lit: bool = true) -> void:
	if light and not lit:
		return
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			var ch := row[i]
			if ch == "#":
				ci.draw_rect(Rect2(x + i, y + j, 1, 1), c)
			elif ch == "+":
				ci.draw_rect(Rect2(x + i, y + j, 1, 1), c2)
			elif ch == "O":
				ci.draw_rect(Rect2(x + i, y + j, 1, 1), WHITE)


func _icon(ci: CanvasItem, name: String, cx: int, cy: int, c: Color, lit: bool = true) -> void:
	var rows: Array = LabIcons.ICONS.get(name, [])
	var n := rows.size()
	_bitmap(ci, rows, cx - n / 2, cy - n / 2, c, mixc(c, BG, 0.5), lit)


func _mark(ci: CanvasItem, rows: Array, x: int, y: int, c: Color) -> void:
	_bitmap(ci, rows, x, y, c, mixc(c, BG, 0.55))


## Words with their capitals' top on `ycap` (F8's capitals are 5 px, F16's 10).
static func text_at(ci: CanvasItem, x: int, ycap: int, s: String, c: Color, sz: int = 8) -> void:
	ci.draw_string(font(), Vector2(x, ycap + (5 if sz == 8 else 10)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func ground_ink(a: float) -> Color:
	return mixc(BG, tint, a)


# ------------------------------------------------------------------ the state

## Read the run again and redraw what changed. Never builds a node.
func refresh() -> void:
	_names.clear()
	_texts.clear()
	for b in 3:
		var nb: Array = []
		var xb: Array = []
		for k in 3:
			var i := b * 3 + k
			var id: StringName = Run.board[i] if i < Run.board.size() else &""
			var r: Dictionary = DB.routines.get(id, {})
			nb.append(String(r.get("name", "")))
			xb.append(String(r.get("text", "")).to_upper())
		_names.append(nb)
		_texts.append(xb)
	for b in 3:
		_owned[b] = clampi(Run.board_owned[b] if b < Run.board_owned.size() else 0, 0, 3)
	_data = Run.data
	if pick == Vector2i(-1, -1) or not dealt():
		pick = _first_pick()
	var sig := "%s|%s|%s" % [str(_names), str(_owned), str(_states())]
	if sig != _sig:
		_sig = sig
		_layout()
	_restyle()


## Whether this run has a board to draw (every run with science on does).
func dealt() -> bool:
	return Run.board.size() >= 9 and not _names.is_empty() and _names[0][0] != ""


func _states() -> Array:
	var out: Array = []
	for b in 3:
		for k in 3:
			out.append(state(b, k))
	return out


## &"owned", &"next" (yours to buy now), &"short" (next, the DATA short) or
## &"later" (behind the next).
func state(b: int, k: int) -> StringName:
	if k < _owned[b]:
		return &"owned"
	if k == _owned[b]:
		return &"next" if _data >= int(DB.BOARD_PRICES[k]) and not Run.science_off else &"short"
	return &"later"


## The step the strip opens on: the first you can buy, else the first next step.
func _first_pick() -> Vector2i:
	for want: StringName in [&"next", &"short"]:
		for b in [1, 0, 2]:
			if _owned[b] < 3 and state(b, _owned[b]) == want:
				return Vector2i(b, _owned[b])
	return Vector2i(0, 2)


## The step the strip is about: the one under the pointer, else the one picked.
func shown() -> Vector2i:
	return hover if hover.x >= 0 else pick


func _on_buy() -> void:
	var s := shown()
	if s.x < 0 or state(s.x, s.y) != &"next":
		return
	buy.emit(s.x)


## The board's owner bought step `s`: flash it, and say so on the strip.
func mark_bought(s: Vector2i) -> void:
	bought = s
	pick = s
	hover = Vector2i(-1, -1)
	_flash_until = _clock + FLASH_S
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	var f := int(floorf(_clock / FRAME_S)) % FRAMES
	if f != _frame:
		_frame = f
		phase = float(f) / float(FRAMES)
		_live.queue_redraw()


## A frame of the loop held, for a photograph (`stationshot`).
func hold_phase(p: float) -> void:
	set_process(false)
	phase = p
	_live.queue_redraw()


# ------------------------------------------------------------------ input

func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm != null:
		var at := step_at(mm.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if at.x >= 0 else Control.CURSOR_ARROW
		if at != hover:
			hover = at
			_restyle()
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var at2 := step_at(mb.position)
		if at2.x >= 0:
			pick = at2
			if bought != at2:
				bought = Vector2i(-1, -1)
			accept_event()
			_restyle()


## The step whose ring holds `p` (board px), or (-1, -1).
func step_at(p: Vector2) -> Vector2i:
	if not dealt():
		return Vector2i(-1, -1)
	for key: Vector2i in _nodes:
		var c: Vector2i = _nodes[key]
		if p.distance_to(Vector2(c)) <= NR + 4:
			return key
	return Vector2i(-1, -1)


# ------------------------------------------------------------------ the layout

## Where everything stands for this deal and state: the steps, the arms'
## pixels, and every label, placed by the mockup's rule.
func _layout() -> void:
	_nodes.clear()
	_segs.clear()
	_labels.clear()
	_price_marks.clear()
	_lines = PackedByteArray()
	_lines.resize(W * H)
	if not dealt():
		return
	for b in 3:
		for k in 3:
			_nodes[Vector2i(b, k)] = node_xy(b, k)
	var skip: Array = [Vector3(CX, CY, HR + 3)]
	for key: Vector2i in _nodes:
		var c: Vector2i = _nodes[key]
		skip.append(Vector3(c.x, c.y, NR + 3))
	for b in 3:
		for k in 3:
			var r0 := 0.0 if k == 0 else float(RHO[k - 1])
			var pts := arm_path(b, maxf(r0, 1.0), float(RHO[k]))
			var kept: Array[Vector2i] = []
			for p in pts:
				var hit := false
				for s: Vector3 in skip:
					if (p.x - s.x) * (p.x - s.x) + (p.y - s.y) * (p.y - s.y) <= s.z * s.z:
						hit = true
						break
				if not hit:
					kept.append(p)
					if p.x >= 0 and p.y >= 0 and p.x < W and p.y < H:
						_lines[p.y * W + p.x] = 1
			_segs[Vector2i(b, k)] = kept
	var P := _Placer.new()
	P.lines = _lines
	P.boxes.append(Rect2i(CX - HR - 6, CY - HR - 6, 2 * HR + 13, 2 * HR + 13))
	for key: Vector2i in _nodes:
		var c2: Vector2i = _nodes[key]
		P.boxes.append(Rect2i(c2.x - NR - 6, c2.y - NR - 6, 2 * NR + 13, 2 * NR + 13))
	# the flight computer's two lines, under it
	var n_owned: int = _owned[0] + _owned[1] + _owned[2]
	var lab1 := "FLIGHT COMPUTER"
	var lab2 := "%d OF 9 RUNNING" % n_owned
	var hw := maxi(tw(lab1), tw(lab2))
	var hp := P.place(CX, CY, hw, 17, HR + 8, Vector2(0, 1))
	_label(hp.x + floori((hw - tw(lab1)) / 2.0), hp.y + 1, lab1, ICE, 8, "hub label 1")
	_label(hp.x + floori((hw - tw(lab2)) / 2.0), hp.y + 11, lab2, OWN, 8, "hub label 2")
	# each arm's name, beside its last step on the side the arm was running
	# toward; placed before the steps' names, and kept 8 px clear of them
	for b in 3:
		var e := arm_pt(b, float(RHO[2]))
		var f := arm_pt(b, float(RHO[2]) + 30.0)
		var label: String = BRANCH[b]
		var lw := tw(label, 16)
		var lp := P.place(int(e.x), int(e.y), lw, 12, NR + 12, f - e)
		P.boxes[-1] = Rect2i(lp.x - 6, lp.y - 6, lw + 12, 24)
		_label(lp.x, lp.y + 1, label, mixc(CHILL, tint, 0.25), 16, label)
	# the steps' names, and a price on the next one
	for key: Vector2i in _nodes:
		var c3: Vector2i = _nodes[key]
		var name: String = _names[key.x][key.y]
		var st := state(key.x, key.y)
		var ink: Color = ICE
		match st:
			&"next":
				ink = HOT
			&"short":
				ink = mixc(HOT, BG, 0.3)
			&"later":
				ink = LATER_T
		var priced := st == &"next" or st == &"short"
		var w := tw(name)
		var bp := P.place(c3.x, c3.y, w, 17 if priced else 7, NR + 11,
			Vector2(c3.x - CX, (c3.y - CY) / SY))
		_label(bp.x, bp.y + 1, name, ink, 8, name, st == &"owned" or st == &"next")
		if priced:
			var pc := NEXT if st == &"next" else BAD
			var ps := str(DB.BOARD_PRICES[key.y])
			var pw := 8 + tw(ps)
			var px := bp.x + floori((w - pw) / 2.0)
			_price_marks.append({x = px, y = bp.y + 11, c = pc})
			_label(px + 8, bp.y + 11, ps, pc, 8, "price " + name, st == &"next")
	queue_redraw()


func _label(x: int, ycap: int, s: String, c: Color, sz: int, name: String, lit: bool = false) -> void:
	_labels.append({x = x, ycap = ycap, s = s, c = c, size = sz, name = name, lit = lit})


## THE MOCKUP'S `Placer`: a label goes where nothing else is -- not on a step,
## not on another label, not across an arm -- trying its outward side first.
class _Placer:
	var lines: PackedByteArray
	var boxes: Array[Rect2i] = []

	func is_free(bx: int, by: int, w: int, h: int, m: int = 3) -> bool:
		if bx < TREE.position.x or by < TREE.position.y or bx + w > TREE.end.x or by + h > TREE.end.y:
			return false
		for t in boxes:
			if bx < t.position.x + t.size.x + m and t.position.x < bx + w + m \
					and by < t.position.y + t.size.y + m and t.position.y < by + h + m:
				return false
		for x in range(bx - 2, bx + w + 2):
			for y in range(by - 2, by + h + 2):
				if lines[y * W + x] != 0:
					return false
		return true

	func place(x: int, y: int, w: int, h: int, gap: int, out: Vector2) -> Vector2i:
		var n := out.length()
		if n == 0.0:
			n = 1.0
		var o := out / n
		for g in [gap, gap + 6, gap + 12, gap + 20]:
			var r := _try(x, y, w, h, g, o)
			if r.x != -9999:
				return r
		push_warning("lab board: no room for a label at %d,%d" % [x, y])
		boxes.append(Rect2i(x, y, w, h))
		return Vector2i(x, y)

	func _try(x: int, y: int, w: int, h: int, gap: int, o: Vector2) -> Vector2i:
		var cands: Array = []
		for ang in range(0, 360, 15):
			var ux := cos(deg_to_rad(ang))
			var uy := sin(deg_to_rad(ang))
			var bx: float
			var by: float
			if absf(ux) > 0.3:
				bx = x + ux * gap + (0.0 if ux > 0 else -float(w))
				by = y + uy * gap - h / 2.0
			else:
				bx = x - w / 2.0 + ux * w / 2.0
				by = y + (gap if uy > 0 else -gap - h)
			cands.append([-(ux * o.x + uy * o.y), LabBoard.pyround(bx), LabBoard.pyround(by)])
		cands.sort_custom(func(a: Array, b: Array) -> bool:
			if a[0] != b[0]:
				return a[0] < b[0]
			if a[1] != b[1]:
				return a[1] < b[1]
			return a[2] < b[2])
		for c: Array in cands:
			if is_free(c[1], c[2], w, h):
				boxes.append(Rect2i(c[1], c[2], w, h))
				return Vector2i(c[1], c[2])
		return Vector2i(-9999, -9999)


# ------------------------------------------------------------------ restyle

## The strip and BUY for the step in hand, and the leaves for the box test.
## Moves BUY, never makes it.
func _restyle() -> void:
	var s := shown()
	var show_buy := dealt() and s.x >= 0 and state(s.x, s.y) == &"next"
	if show_buy:
		var label := "BUY  %d DATA" % int(DB.BOARD_PRICES[s.y])
		var bw := tw(label) + 30
		buy_button.label = label
		buy_button.position = Vector2(W - T - 14 - bw, 461)
		buy_button.size = Vector2(bw, 19)
		buy_button.queue_redraw()
	buy_button.visible = show_buy
	queue_redraw()
	_live.queue_redraw()
	_lit_changed()


# ------------------------------------------------------------------ drawing

func _leaf(name: String, x: int, y: int, w: int, h: int) -> void:
	if not light:
		leaves.append([name, Rect2i(x, y, w, h)])


func _text(ci: CanvasItem, x: int, ycap: int, s: String, c: Color, sz: int = 8, name: String = "", lit: bool = false) -> int:
	var w := tw(s, sz)
	if light:
		if lit:
			text_at(ci, x, ycap, s, c, sz)
		return w
	text_at(ci, x, ycap, s, c, sz)
	var cap := 5 if sz == 8 else 10
	var r := Rect2i(x, ycap - 1, w, cap + 2)
	leaves.append([name if name != "" else s, r])
	tboxes.append([name if name != "" else s, r])
	return w


func _draw() -> void:
	leaves.clear()
	tboxes.clear()
	paint(self)


## The board's still parts onto `ci`: as it looks, or (`light`) what glows.
func paint(ci: CanvasItem) -> void:
	if not dealt():
		var msg := "NO BOARD IS DEALT FOR THIS RUN."
		_text(ci, CX - tw(msg) / 2, CY, msg, CHILL)
		return
	# THE ARMS: hub to step 1 to 2 to 3. A running stretch is solid and lit; a
	# stretch still to come dotted. The stretch to the next step is dashed, and
	# moves (`paint_live`).
	for key: Vector2i in _segs:
		var st := state(key.x, key.y)
		if st == &"owned":
			for p: Vector2i in _segs[key]:
				_px(ci, p.x, p.y, OWN, 1.0, true)
		elif st == &"later":
			var n := 0
			for p: Vector2i in _segs[key]:
				n += 1
				if n % 3 == 0:
					_px(ci, p.x, p.y, DOT)
	# THE FLIGHT COMPUTER, sat on the galaxy's core: nine slots round its rim,
	# one lit for every routine running
	var n_owned: int = _owned[0] + _owned[1] + _owned[2]
	_disc(ci, CX, CY, HR, mixc(BG, OWN, 0.1))
	_ring(ci, CX, CY, HR, OWN, 0, 0.0, true)
	_ring(ci, CX, CY, HR - 3, OWN_D)
	for i in 9:
		var a := deg_to_rad(90.0 - i * 40.0)
		var sx := pyround(CX + (HR - 7) * cos(a))
		var sy := pyround(CY - (HR - 7) * sin(a))
		var on := i < n_owned
		if on or not light:
			ci.draw_rect(Rect2(sx, sy, 2, 2), OWN if on else mixc(BG, OWN, 0.25))
	_icon(ci, "FLIGHT COMPUTER", CX, CY, OWN)
	_leaf("hub", CX - HR - 1, CY - HR - 1, 2 * HR + 3, 2 * HR + 3)
	# THE STEPS
	for key: Vector2i in _nodes:
		var c: Vector2i = _nodes[key]
		_node_still(ci, c.x, c.y, _names[key.x][key.y], state(key.x, key.y))
		_leaf("node " + String(_names[key.x][key.y]), c.x - NR - 4, c.y - NR - 4, 2 * NR + 9, 2 * NR + 9)
	for m: Dictionary in _price_marks:
		_mark(ci, LabIcons.DATA_MARK, m.x, m.y, m.c)
	for l: Dictionary in _labels:
		_text(ci, l.x, l.ycap, l.s, l.c, l.size, l.name, bool(l.get("lit", false)))
	_caption(ci)


## A step's ring, disc and icon: the parts that hold still.
func _node_still(ci: CanvasItem, x: int, y: int, name: String, st: StringName, r: int = NR) -> void:
	match st:
		&"owned":
			_disc(ci, x, y, r, mixc(BG, OWN, 0.2))
			_ring(ci, x, y, r, OWN, 0, 0.0, true)
			_ring(ci, x, y, r - 2, OWN_D)
			_icon(ci, name, x, y, OWN)
		&"next":
			_disc(ci, x, y, r, mixc(BG, NEXT, 0.2))
			_ring(ci, x, y, r, NEXT, 0, 0.0, true)
			_icon(ci, name, x, y, HOT)
		&"short":
			_disc(ci, x, y, r, mixc(BG, NEXT, 0.07))
			_ring(ci, x, y, r, mixc(NEXT, BG, 0.6))
			_icon(ci, name, x, y, mixc(HOT, BG, 0.5), false)
		_:
			_disc(ci, x, y, r, BG)
			_ring(ci, x, y, r, LATER_R, 16)
			_icon(ci, name, x, y, LATER_I, false)


## A step's halo and pulse, at `p` round its loop: the parts that move.
func _node_live(ci: CanvasItem, x: int, y: int, st: StringName, p: float, r: int = NR) -> void:
	match st:
		&"owned":
			# the pulse: a ring going out from the step, fading as it goes
			var pr := r + 2 + pyround(9.0 * p)
			_dither_ring(ci, x, y, pr, pr + 3, OWN_D if p > 0.5 else OWN, 1.0 - p)
		&"next":
			_dither_ring(ci, x, y, r + 1, r + 6, NEXT_D, 0.7 + 0.3 * sin(TAU * p))
			_ring(ci, x, y, r + 4, mixc(BG, NEXT, 0.6), 12, p / 12.0)


## The strip under the board: the step in hand, in words, and its key.
func _caption(ci: CanvasItem) -> void:
	for x in range(GLASS.position.x + 10, GLASS.end.x - 10):
		_px(ci, x, 446, ground_ink(0.3))
	var s := shown()
	if s.x < 0:
		return
	var b := s.x
	var k := s.y
	var name: String = _names[b][k]
	var st := state(b, k)
	var ix := 60
	var iy := 480
	# the step's own ring, held at one moment of its loop
	_node_live(ci, ix, iy, st, 0.35)
	_node_still(ci, ix, iy, name, st)
	_leaf("caption icon", ix - NR - 4, iy - NR - 4, 2 * NR + 9, 2 * NR + 9)
	var x := 96
	_text(ci, x, 457, name, HOT if st == &"next" else ICE, 16, "", true)
	var tag := "RUNNING" if st == &"owned" else "%s %d OF 3" % [BRANCH[b], k + 1]
	if bought == s:
		tag = "RUNNING FROM YOUR NEXT FIGHT."
	_text(ci, x + tw(name, 16) + 10, 461, tag, OWN if st == &"owned" else CHILL)
	_text(ci, x, 475, _texts[b][k], ICE)
	match st:
		&"next", &"short":
			var tail := "THE LAST STEP ON THIS ARM."
			if k < 2:
				tail = "NEXT: %s, %d." % [_names[b][k + 1], int(DB.BOARD_PRICES[k + 1])]
			_text(ci, x, 487, tail, CHILL)
		&"owned":
			_text(ci, x, 487, "YOURS FOR THE REST OF THE RUN, WHATEVER SHIP YOU FLY.", CHILL)
		&"later":
			_text(ci, x, 487, "BUY %s FIRST." % _names[b][_owned[b]], CHILL)
	if st == &"next":
		var r := Rect2i(buy_button.position, buy_button.size)
		if not light:
			leaves.append(["[BUY]", r])
		else:
			# the key's word glows, as the mockup's commit plate did
			var bl := buy_button.label
			text_at(ci, r.position.x + floori((r.size.x - tw(bl)) / 2.0), r.position.y + floori((r.size.y - 5) / 2.0), bl, HOT)
		var left := "LEAVES %d DATA" % (_data - int(DB.BOARD_PRICES[k]))
		_text(ci, r.position.x + floori((r.size.x - tw(left)) / 2.0), 486, left, CHILL)


func _draw_live(ci: CanvasItem) -> void:
	paint_live(ci)
	_lit_changed()


## What moves round the board's loop: the dashes on the way to each next step,
## DATA on its way in down every running stretch, the computer's glow, each
## step's halo, the step just bought, and the corners round the one in hand.
func paint_live(ci: CanvasItem) -> void:
	if not dealt():
		return
	var p := phase
	for key: Vector2i in _segs:
		var st := state(key.x, key.y)
		if st == &"next" or st == &"short":
			var off := -int(p * 8.0)
			var n := 0
			for q: Vector2i in _segs[key]:
				n += 1
				if posmod(floori(float(n + off) / 4.0), 2) == 1:
					continue
				_px(ci, q.x, q.y, NEXT if st == &"next" else mixc(NEXT, BG, 0.6), 1.0, st == &"next")
	# data on its way in: packets run down every lit stretch toward the computer
	for b in 3:
		for k in _owned[b]:
			var pts: Array = _segs.get(Vector2i(b, k), [])
			if pts.size() < 8:
				continue
			for off2: float in [0.0, 0.5]:
				var t := fposmod(p + off2 + 0.17 * b + 0.29 * k, 1.0)
				var i := int((1.0 - t) * (pts.size() - 1))
				var h: Vector2i = pts[i]
				for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
					_px(ci, h.x + d.x, h.y + d.y, WHITE if d == Vector2i.ZERO else HOT, 1.0, true)
				for ja: Vector2 in [Vector2(1, 0.9), Vector2(2, 0.8), Vector2(3, 0.65), Vector2(4, 0.5), Vector2(5, 0.35), Vector2(6, 0.2)]:
					var ii := mini(pts.size() - 1, i + int(ja.x))
					var tp: Vector2i = pts[ii]
					_px(ci, tp.x, tp.y, WHITE, ja.y, true)
	_dither_ring(ci, CX, CY, HR + 1, HR + 8, OWN_D, 0.8 + 0.2 * sin(TAU * p))
	for key2: Vector2i in _nodes:
		var c: Vector2i = _nodes[key2]
		_node_live(ci, c.x, c.y, state(key2.x, key2.y), fposmod(p + 0.23 * key2.x + 0.37 * key2.y, 1.0))
	if bought.x >= 0 and _clock < _flash_until and _nodes.has(bought):
		var fb: Vector2i = _nodes[bought]
		_ring(ci, fb.x, fb.y, NR + 3, WHITE, 0, 0.0, true)
		_dither_ring(ci, fb.x, fb.y, NR + 4, NR + 9, OWN, 0.9)
	var s := shown()
	if _nodes.has(s):
		var sc: Vector2i = _nodes[s]
		_reticle(ci, sc.x, sc.y, NR + 7)


## The chart's target corners round the step in hand.
func _reticle(ci: CanvasItem, cx: int, cy: int, r: int) -> void:
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for k in 5:
				_px(ci, cx + sx * (r - k), cy + sy * r, ICE, 1.0, true)
				_px(ci, cx + sx * r, cy + sy * (r - k), ICE, 1.0, true)


## Something that glows moved: whoever blooms it (`LabZoom`) redraws.
signal lit_changed


func _lit_changed() -> void:
	lit_changed.emit()


## THE MOCKUP'S BOX TEST, on what is drawn now: every leaf inside the glass,
## no two overlapping, and no word crossing an arm. Empty when it passes.
func check(extra: Array = []) -> PackedStringArray:
	var bad := PackedStringArray()
	var all: Array = leaves.duplicate()
	all.append_array(extra)
	for l: Array in all:
		var r: Rect2i = l[1]
		if not GLASS.encloses(r):
			bad.append("'%s' %s is outside the glass" % [l[0], r])
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Rect2i = all[i][1]
			var c: Rect2i = all[j][1]
			if a.intersects(c):
				bad.append("'%s' overlaps '%s'" % [all[i][0], all[j][0]])
	if _lines.size() == W * H:
		for t: Array in tboxes:
			var r2: Rect2i = t[1]
			var hit := false
			for x in range(r2.position.x - 1, r2.end.x + 1):
				for y in range(r2.position.y - 1, r2.end.y + 1):
					if x >= 0 and y >= 0 and x < W and y < H and _lines[y * W + x] != 0:
						hit = true
			if hit:
				bad.append("text '%s' crosses an arm" % t[0])
	return bad
