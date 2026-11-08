class_name SalvageGrid
extends Control

## A loose pile, not a packing puzzle: it places first-fit, then remembers so nothing jumps
## under the hand. Same 40 px cell as the hold, so a shape means the same thing on both sides.
## Why: docs/why/SalvageGrid.md#salvage-grid

signal picked(item: HoldItem)
## A signal, not a call into Audio: this grid draws a container and knows no rarity sounds.
## Why: docs/why/SalvageGrid.md#reveal-signal
signal revealed(item: HoldItem, index: int)

## Called with something of yours dropped here; the view, not the grid, knows which container it is.
var on_put: Callable

const CELL := HoldGrid.CELL
const EDGE := 2.0

## A constant: the frame must reserve the width before anything is in it (`TransferView.BAR`).
const COLS := 5
var _cols: int = COLS
var _rows: int = 1
var _items: Array = []
## Keyed by the item itself, not index: the list is filtered and reordered between refreshes.
var _at: Dictionary = {}
## The tallest the grid has been this visit. It does not shrink, because a
## container that gets shorter as you empty it moves everything still in it.
var _high: int = 0
## Without it, dragging out here lit nothing and a drop looked refused when it was only undrawn.
## Why: docs/why/SalvageGrid.md#drop-beam
var _beam: Rect2i = Rect2i()

## Slowed again at Jon's ask: 0.7 cells a second, so each rarity sound is heard on its own.
## Earlier rates (14 down to 1.6) finished before the sweep cost anything.
## Why: docs/why/SalvageGrid.md#sweep-speed
const SCAN_CELLS_PER_SEC := 0.7

## Settle time is in rows of sweep, not seconds, so
## retuning the scan speed keeps the glitch in step.
## Why: docs/why/SalvageGrid.md#glitch-timing
const GLITCH_ROWS := 1.5

## Fourteen cuts over a row and a half is about one a tenth of a second: interference, each seen.
const GLITCH_STEPS := 14

## Six px reads as the picture failing to hold; twenty would read as the crate misplaced, a bug.
const GLITCH_TEAR := 6.0

## A repeating pattern that decays reads as a signal locking on; noise reads as a fault.
const GLITCH_SHAPE: Array[float] = [1.0, -0.8, 0.55, -1.0, 0.3, -0.45]

## Only two of fourteen steps drop out: swinging alpha
## on every cut was a strobe, so the tear carries it.
## Why: docs/why/SalvageGrid.md#glitch-dropouts
const GLITCH_DROPS: Array[int] = [1, 4]

## How far a dropout knocks the brightness down. Not to nothing: a crate at a
## fifth is still a crate, and a crate at zero is a hole.
const GLITCH_DROP_TO := 0.22
## How far down the sweep has reached, in pixels, or -1 when it is not running.
var _scan: float = -1.0
## What the sweep has already found, so a rebuild mid-scan does not make a crate
## materialise twice.
var _lit: Dictionary = {}


## Called once on open, not each refresh, or every take would feel like a new discovery.
func scan() -> void:
	_scan = 0.0
	_lit.clear()
	set_process(true)
	_apply_scan()
	queue_redraw()


## Everything visible, now. For the harness, and for anything that needs the
## container settled rather than pretty.
func skip_scan() -> void:
	_scan = -1.0
	set_process(false)
	_apply_scan()
	queue_redraw()


func _process(delta: float) -> void:
	if _scan < 0.0:
		set_process(false)
		return
	_scan += SCAN_CELLS_PER_SEC * float(CELL) * delta
	if _scan >= float(_rows * CELL):
		skip_scan()
		return
	_apply_scan()
	queue_redraw()


## An item is out of the dark once the line has passed the TOP of it, so a tall
## crate appears as the sweep reaches it rather than after it has cleared it.
func _apply_scan() -> void:
	for c in get_children():
		var ic := c as ItemIcon
		if ic == null:
			continue
		if _scan < 0.0:
			ic.visible = true
			ic.modulate = Color.WHITE
			continue
		var found := ic.position.y < _scan
		ic.visible = found
		if not found:
			continue
		var m := ic.held_item()
		if m == null or _lit.has(m):
			continue
		_lit[m] = true
		revealed.emit(m, _lit.size())
		# Seeded by how many have arrived: no two resolve
		# alike and the same pile resolves the same twice.
		_materialise(ic, _lit.size())


## Stepped hard cuts in the sweep's colour, landing on white at the end, so the sweep reveals it.
## Why: docs/why/SalvageGrid.md#materialise
func _materialise(ic: ItemIcon, seed_at: int) -> void:
	var glow := UITheme.TRACTOR
	var home := ic.position
	# Each settles at its own pace, within a fifth either side, so they do not arrive in lockstep.
	var spread := 1.0 + (float(seed_at % 5) - 2.0) * 0.09
	var hold := (GLITCH_ROWS / SCAN_CELLS_PER_SEC) * spread / float(GLITCH_STEPS)
	ic.modulate = Color(glow.r, glow.g, glow.b, 0.0)
	var t := ic.create_tween()
	for i in GLITCH_STEPS:
		# `wild` decays 1 to 0, so the first cut is loudest: intensity is a decay, not a constant.
		var wild := 1.0 - float(i) / float(GLITCH_STEPS)
		var settled := 1.0 - wild
		# The pattern is walked from a different place per item, so one crate
		# tears left first and the next tears right.
		var swing: float = GLITCH_SHAPE[(i + seed_at) % GLITCH_SHAPE.size()]
		# Visible from the first cut and rising; only the
		# two `GLITCH_DROPS` dim it, and not to nothing.
		var a := 0.6 + settled * 0.4
		# And it blinks on different cuts. Still twice -- see `GLITCH_DROPS` --
		# but not the same twice as its neighbour.
		if GLITCH_DROPS.has((i + seed_at) % GLITCH_STEPS):
			a *= GLITCH_DROP_TO
		# And it cools out of the sweep's colour into its own as it settles.
		var col := Color(glow.r, glow.g, glow.b).lerp(Color.WHITE, settled)
		col.a = a
		var dx := swing * wild * GLITCH_TEAR
		t.tween_callback(func() -> void:
			ic.modulate = col
			ic.position = home + Vector2(dx, 0.0))
		t.tween_interval(hold)
	# AND THEN IT IS SIMPLY THERE. Snapping home rather than easing to it: the
	# last thing a glitch should do is look like it was always going to land.
	t.tween_callback(func() -> void:
		ic.modulate = Color.WHITE
		ic.position = home)
## A claimed bag row still takes space: a hole is information, a silently reflowed grid is not.
var _spent: Dictionary = {}


func _init() -> void:
	# STOP, not PASS: PASS would hand drops on to the scroll container behind. Icons stay PASS.
	mouse_filter = Control.MOUSE_FILTER_STOP


## `spent` holds claimed indices (greyed, not pickable); `cols` is the width and rows follow.
func setup(items: Array, spent: Dictionary, cols: int = COLS) -> void:
	_items = items
	_spent = spent
	_cols = maxi(1, cols)
	_layout()
	_rebuild()


## First fit, largest first, as `RunState.reseat` does: plain first-fit strands big things.
func _layout() -> void:
	# Placed items keep their cell; new loot lands in the gaps instead of reshuffling the pile.
	var taken := _occupied()
	var fresh: Array[HoldItem] = []
	for m0 in _items:
		if not _at.has(m0):
			fresh.append(m0)
	# Largest first among the new ones, the same rule `reseat` uses: first-fit
	# on a fresh grid strands big things behind small ones.
	fresh.sort_custom(func(a: HoldItem, b: HoldItem) -> bool:
		return a.cells() > b.cells())
	for m2 in fresh:
		var f2 := m2.footprint()
		var at2 := _first_fit(taken, f2)
		_at[m2] = at2
		for dy2 in f2.y:
			for dx2 in f2.x:
				taken[at2 + Vector2i(dx2, dy2)] = true

	# Anything no longer here forgets its cell, or the map grows forever.
	for key in _at.keys():
		if not _items.has(key):
			_at.erase(key)

	_rows = 1
	for m3 in _items:
		var mm: HoldItem = m3
		_rows = maxi(_rows, (_at[mm] as Vector2i).y + mm.footprint().y)
	# One spare row always: with every cell full there was nowhere to aim a jettison drop.
	# Why: docs/why/SalvageGrid.md#spare-row
	_rows += 1
	# Never shorter than it has been, or emptying a container moved every item up under the cursor.
	_high = maxi(_high, _rows)
	_rows = _high
	# The minimum is the picture; the control may be
	# larger (`_draw`), as the column is the drop place.
	custom_minimum_size = Vector2(_cols * CELL, _rows * CELL)


## Rows the things take, without the spare row: an item count cannot say it (two 2x2 fill two rows).
func content_rows() -> int:
	var r := 0
	for m in _items:
		r = maxi(r, (_at[m] as Vector2i).y + (m as HoldItem).footprint().y)
	return r


## Scans as far down as needed: a pile has no floor, and refusing the last item would invent a rule.
func _first_fit(taken: Dictionary, f: Vector2i) -> Vector2i:
	var y := 0
	while y < 256:
		for x in maxi(1, _cols - f.x + 1):
			var at := Vector2i(x, y)
			var ok := true
			for dy in f.y:
				for dx in f.x:
					if taken.has(at + Vector2i(dx, dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return at
		y += 1
	return Vector2i(0, 0)


func _rebuild() -> void:
	Widgets.clear(self)
	for i in _items.size():
		var m: HoldItem = _items[i]
		var icon := ItemIcon.make(m, &"bag")
		# `bag`, not `cargo`: the drop site reads it to know taking this costs a CLAIM.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
		icon.custom_minimum_size = Vector2.ZERO
		var cell: Vector2i = _at.get(m, Vector2i.ZERO)
		icon.position = Vector2(cell.x * CELL, cell.y * CELL)
		icon.size = ModuleIcon.footprint_box(m)
		if _scan >= 0.0:
			# Mid-sweep, so a rebuild must not hand the dark back its items --
			# nor replay the arrival of something already found.
			icon.visible = icon.position.y < _scan
			if _lit.has(m):
				icon.modulate = Color.WHITE
		if _spent.has(i):
			# Still drawn, still in its cell, plainly not yours. See `_spent`.
			icon.modulate = Color(0.42, 0.42, 0.48, 0.7)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.tooltip_text = Widgets.tip("Already taken.")
	queue_redraw()


## The lattice draws at its own extent; the control
## is bigger so a full grid still has a drop target.
## Why: docs/why/SalvageGrid.md#lattice-extent
func _draw() -> void:
	var w := float(_cols * CELL)
	var h := float(_rows * CELL)
	for y in _rows:
		for x in _cols:
			draw_rect(Rect2(Vector2(x * CELL, y * CELL), Vector2(CELL, CELL)),
				Color("#0b1017"), true)
	for x in range(1, _cols):
		draw_line(Vector2(x * CELL, 0.0), Vector2(x * CELL, h),
			UITheme.LINE, 1.0)
	for y in range(1, _rows):
		draw_line(Vector2(0.0, y * CELL), Vector2(w, y * CELL),
			UITheme.LINE, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), UITheme.LINE, false, EDGE)
	if _scan >= 0.0:
		# The unswept part is dark and the line is the
		# brightest thing: two rectangles and a rule, no shader.
		var dark := Rect2(0.0, _scan, w, h - _scan)
		if dark.size.y > 0.0:
			draw_rect(dark, Color(0.04, 0.055, 0.08, 0.92), true)
		var glow := UITheme.TRACTOR
		draw_rect(Rect2(0.0, _scan - 6.0, w, 6.0),
			Color(glow.r, glow.g, glow.b, 0.10), true)
		draw_rect(Rect2(0.0, _scan - 1.0, w, 2.0),
			Color(glow.r, glow.g, glow.b, 0.85), true)
	if _beam.size.x <= 0:
		return
	# The hold's own ink for the same question, where
	# does this go; two idioms would read as two answers.
	var c := UITheme.TRACTOR
	var r := Rect2(Vector2(_beam.position) * float(CELL),
		Vector2(_beam.size) * float(CELL))
	draw_rect(r, Color(c.r, c.g, c.b, 0.14), true)
	draw_rect(r, Color(c.r, c.g, c.b, 0.7), false, 1.0)


## Which entry an item is, so a claim can name it. Identity, not equality --
## `n.bag` holds the very objects the icons were built from.
func index_of(m: HoldItem) -> int:
	return _items.find(m)


## Your things dropped here are jettison; ones already
## here are rearranged, as refusing read as broken.
## Why: docs/why/SalvageGrid.md#drops
func _can_drop_data(at: Vector2, data: Variant) -> bool:
	_show_beam(Rect2i())
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return false
	var m: HoldItem = (data as Dictionary).module
	if m == null:
		return false
	var cell := _cell_of(at, m)
	if String((data as Dictionary).get("origin", &"")) == "bag":
		if not (_at.has(m) and _fits(m, cell)):
			return false
		_show_beam(Rect2i(cell, m.footprint()))
		return true
	if not Run.cargo.has(m):
		return false
	# Frame the cells you point at, not the whole container: a drop decides WHERE.
	_show_beam(Rect2i(_target_for(at, m), m.footprint()))
	return true


func _show_beam(r: Rect2i) -> void:
	if r == _beam:
		return
	_beam = r
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_show_beam(Rect2i())


func _drop_data(at: Vector2, data: Variant) -> void:
	var m: HoldItem = (data as Dictionary).module
	if m == null:
		return
	if String((data as Dictionary).get("origin", &"")) == "bag":
		# Re-checked at landing: a partner's refresh mid-drag
		# staled the hover and drew two items on one cell.
		# Why: docs/why/SalvageGrid.md#drop-recheck
		var cell := _cell_of(at, m)
		if not _fits(m, cell):
			cell = _target_for(at, m)
		_at[m] = cell
		_layout()
		_rebuild()
		return
	# The cell is chosen before the throw and recorded
	# after, so the thing lands where the beam said.
	var cell := _target_for(at, m)
	if on_put.is_valid() and on_put.call(m):
		_at[m] = cell
		picked.emit(m)


## Measured from the item, not the pointer, as
## `HoldGrid.target_for` does: the plate is centred on the cursor.
func _cell_of(at: Vector2, m: HoldItem) -> Vector2i:
	var f := m.footprint()
	var top_left := at - Vector2(f.x, f.y) * float(CELL) * 0.5
	return Vector2i(
		clampi(int(round(top_left.x / float(CELL))), 0, maxi(0, _cols - f.x)),
		maxi(0, int(round(top_left.y / float(CELL)))))


## Nearest clear cell if the aimed one is taken, like
## the hold's `NUDGE`: packing tests arithmetic, not aim.
## Why: docs/why/SalvageGrid.md#nudged-landing
func _target_for(at: Vector2, m: HoldItem) -> Vector2i:
	var want := _cell_of(at, m)
	var f := m.footprint()
	# One occupancy map for the whole search -- this runs on every drag-over
	# frame, and rescanning the pile per candidate cell was most of its cost.
	var taken := _occupied(m)
	if _clear_at(taken, want, f):
		return want
	var best := -Vector2i.ONE
	var best_d := 1e9
	for dy in range(-HoldGrid.NUDGE, HoldGrid.NUDGE + 1):
		for dx in range(-HoldGrid.NUDGE, HoldGrid.NUDGE + 1):
			var t := want + Vector2i(dx, dy)
			if not _clear_at(taken, t, f):
				continue
			var dist := Vector2(dx, dy).length_squared()
			if dist < best_d:
				best_d = dist
				best = t
	if best != -Vector2i.ONE:
		return best
	# Nowhere near will do, so anywhere will: a container
	# has no floor and refusing would invent a rule.
	return _first_fit(taken, f)


## Every cell covered by anything placed here, except `exclude`: the one occupancy computation.
func _occupied(exclude: HoldItem = null) -> Dictionary:
	var taken: Dictionary = {}
	for other in _items:
		var o: HoldItem = other
		if o == exclude or not _at.has(o):
			continue
		var oc: Vector2i = _at[o]
		for dy in o.footprint().y:
			for dx in o.footprint().x:
				taken[oc + Vector2i(dx, dy)] = true
	return taken


## Whether a footprint at `cell` stays in the columns and off the `taken` cells.
func _clear_at(taken: Dictionary, cell: Vector2i, f: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x + f.x > _cols:
		return false
	for dy in f.y:
		for dx in f.x:
			if taken.has(cell + Vector2i(dx, dy)):
				return false
	return true


## Whether a cell is clear of everything except the item being moved.
func _fits(m: HoldItem, cell: Vector2i) -> bool:
	return _clear_at(_occupied(m), cell, m.footprint())
