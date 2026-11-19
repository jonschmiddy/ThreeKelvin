class_name SalvageGrid
extends Control

## A loose pile, not a packing puzzle: it places first-fit, then remembers so nothing jumps
## under the hand. Same 40 px cell as the hold, so a shape means the same thing on both sides.
## Why: docs/why/SalvageGrid.md#salvage-grid

signal picked(item: HoldItem)
## A signal, not a call into Audio: this grid draws a container and knows no rarity sounds.
## Why: docs/why/SalvageGrid.md#reveal-signal
signal revealed(item: HoldItem, index: int)
## The rest revealed at once by a skip, so the view can ring one sound for them.
signal skipped(items: Array)

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

## Jon, Nov 18: one item at a time in reading order, a second apart start to start (no overlap),
## each through `SpectroReveal`; it lands and rings at its peak. Replaced the vertical sweep.
## Why: docs/why/SalvageGrid.md#reveal-order
const REVEAL_STEP := SpectroReveal.LEN
## A beat before the first, so it does not land on the container's own opening sound.
const REVEAL_LEAD := 0.15
## An empty cell's well.
const CELL_WELL := Color("#0b1017")
## Seconds since the reveal began, or -1 when nothing is being revealed.
var _reveal_t: float = -1.0
## The things being revealed, in reading order (top row left to right, then down).
var _order: Array[HoldItem] = []
## What has landed already, so a rebuild mid-reveal does not hide it or ring it twice.
var _lit: Dictionary = {}
var _fx: SpectroReveal = null


## Called once on open, not each refresh, or every take would feel like a new discovery.
## `seen`: things found before (an opened wreck's leftovers in SECTOR LOOT), shown at once.
func scan(seen: Array = []) -> void:
	_order.clear()
	for i in _items.size():
		if not _spent.has(i) and not seen.has(_items[i]):
			_order.append(_items[i])
	_order.sort_custom(func(a: HoldItem, b: HoldItem) -> bool:
		var pa: Vector2i = _at.get(a, Vector2i.ZERO)
		var pb: Vector2i = _at.get(b, Vector2i.ZERO)
		return pa.y < pb.y or (pa.y == pb.y and pa.x < pb.x))
	_lit.clear()
	_reveal_t = 0.0
	set_process(true)
	_apply_reveal()


## Everything visible, now, and silent. For a container already seen, the harness, and the end.
func skip_scan() -> void:
	_reveal_t = -1.0
	set_process(false)
	_apply_reveal()


## True while things are still arriving.
func revealing() -> bool:
	return _reveal_t >= 0.0


## Whether `m` is out of the dark: a thing not yet revealed cannot be taken.
func shown(m: HoldItem) -> bool:
	return _reveal_t < 0.0 or _lit.has(m) or not _order.has(m)


## The rest at once (a click on the grid): one sound for all of them, the view picks it.
## Why: docs/why/SalvageGrid.md#skip
func skip_reveal() -> void:
	if not revealing():
		return
	var rest: Array[HoldItem] = []
	for m in _order:
		if not _lit.has(m) and _items.has(m):
			rest.append(m)
			_lit[m] = true
	skip_scan()
	if not rest.is_empty():
		skipped.emit(rest)


func _start(k: int) -> float:
	return REVEAL_LEAD + REVEAL_STEP * float(k)


func _process(delta: float) -> void:
	if _reveal_t < 0.0:
		set_process(false)
		return
	_reveal_t += delta
	_apply_reveal()
	if _reveal_t >= _start(_order.size() - 1) + SpectroReveal.LEN:
		skip_scan()


## Each icon hidden until its turn, landing at its peak; reduced motion fades it in instead.
## Why: docs/why/SalvageGrid.md#reveal-order
func _apply_reveal() -> void:
	var calm := DisplaySettings.reduced_motion
	var icons: Dictionary = {}
	for c in get_children():
		var ic := c as ItemIcon
		if ic == null:
			continue
		icons[ic.held_item()] = ic
		ic.visible = true
		ic.modulate = _rest_tint(ic)
	var active: Array[Dictionary] = []
	# told after every icon is set, so a listener sees the grid as it will be drawn
	var landed: Array[HoldItem] = []
	if _reveal_t >= 0.0:
		for k in _order.size():
			var m := _order[k]
			var ic: ItemIcon = icons.get(m)
			# gone, or claimed by a partner mid-reveal: shown greyed now, never rung
			if ic == null or _spent.has(_items.find(m)):
				continue
			var tau := _reveal_t - _start(k) - SpectroReveal.PRE
			if tau >= 0.0 and not _lit.has(m):
				_lit[m] = true
				landed.append(m)
			if _lit.has(m) and tau < 0.0:
				continue
			if tau < 0.0:
				var f := clampf((tau + SpectroReveal.PRE) / SpectroReveal.PRE, 0.0, 1.0)
				ic.visible = calm and f > 0.0
				ic.modulate.a = f
			if not calm and tau >= -SpectroReveal.PRE and tau < SpectroReveal.POST:
				active.append({m = m, r = Rect2(ic.position, ic.size), tau = tau, col = ink_of(m)})
	for m in landed:
		revealed.emit(m, _lit.size() - landed.size() + landed.find(m) + 1)
	if active.is_empty() and _fx == null:
		return
	if _fx == null:
		_fx = SpectroReveal.new()
		add_child(_fx)
	_fx.size = size
	move_child(_fx, -1)
	_fx.show_frame(active)


## The grade colour a thing is revealed in; money in the sweep's own teal.
static func ink_of(m: HoldItem) -> Color:
	if m is ModuleData:
		return ModuleData.rarity_ink((m as ModuleData).rarity)
	if m is MaterialData:
		return ModuleData.rarity_ink(UITheme.tier_rarity((m as MaterialData).tier))
	return UITheme.TRACTOR


## A click on the grid, not on a thing already shown, reveals the rest at once.
func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or not revealing():
		return
	for c in get_children():
		var ic := c as ItemIcon
		if ic != null and ic.visible and Rect2(ic.position, ic.size).has_point(mb.position):
			return
	accept_event()
	skip_reveal()


## A claimed bag row still takes space: a hole is information, a silently reflowed grid is not.
var _spent: Dictionary = {}
const SPENT_TINT := Color(0.42, 0.42, 0.48, 0.7)


## Where an item's colour comes to rest: grey if somebody already took it, else white.
func _rest_tint(ic: ItemIcon) -> Color:
	return SPENT_TINT if _spent.has(_items.find(ic.held_item())) else Color.WHITE


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
	_fx = null
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
		if _spent.has(i):
			# Still drawn, still in its cell, plainly not yours. See `_spent`.
			icon.modulate = SPENT_TINT
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.tooltip_text = Widgets.tip("Already taken.")
	# Mid-reveal, a rebuild must not show what is still to come, nor ring what has landed.
	_apply_reveal()
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
				CELL_WELL, true)
	for x in range(1, _cols):
		draw_line(Vector2(x * CELL, 0.0), Vector2(x * CELL, h),
			UITheme.LINE, 1.0)
	for y in range(1, _rows):
		draw_line(Vector2(0.0, y * CELL), Vector2(w, y * CELL),
			UITheme.LINE, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), UITheme.LINE, false, EDGE)
	if _beam.size.x <= 0:
		return
	# The hold's own ink for the same question, where
	# does this go; two idioms would read as two answers.
	var c := UITheme.TRACTOR
	var r := Rect2(Vector2(_beam.position) * float(CELL),
		Vector2(_beam.size) * float(CELL))
	draw_rect(r, Color(c.r, c.g, c.b, 0.14), true)
	draw_rect(r, Color(c.r, c.g, c.b, 0.7), false, 1.0)


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
