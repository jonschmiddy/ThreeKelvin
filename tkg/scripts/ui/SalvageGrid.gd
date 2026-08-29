class_name SalvageGrid
extends Control

## What is loose out here, laid out as a grid you reach into.
##
## The other half of `HoldGrid`, and deliberately a different thing. Your hold
## is a PACKING PUZZLE -- every item has a cell you chose, it is remembered
## across jumps, and the whole game of it is deciding what fits. A wreck is not
## a puzzle. Nobody arranged it. It is a pile, and the only question it asks is
## which of these you want.
##
## It places things itself, first-fit, and then REMEMBERS. The first version
## re-laid-out on every change, on the reasoning that nobody arranges a wreck and
## letting you would imply it mattered. That was wrong in practice for a reason
## that has nothing to do with wrecks: taking one thing out made everything else
## jump to a new cell and the container change height, so the pile you were
## halfway through reading rearranged itself under your hand every time you
## touched it.
##
## Positions last as long as the view is open. Close it and come back and the
## pile is tidied again, which is the one place the original reasoning still
## holds -- you did not arrange it, so it owes you nothing across a visit.
##
## Same 40-pixel cell and same lattice as the hold beside it, because the whole
## point of showing them together is that a shape means the same thing on both
## sides -- a 2x2 that will not go in your hold is a 2x2 you can see will not go.
##
## `MATERIALS_NOTE` 3.6: every physical grant is a container, not an item. This
## is that container. A kill fills one, an event hands you one, and what you
## jettison lands in one.

signal picked(item: HoldItem)

const CELL := HoldGrid.CELL
const EDGE := 2.0

## How wide a container reads. A constant rather than an argument, because the
## frame around it has to reserve the width BEFORE there is anything in it --
## see `TransferView.BAR`.
const COLS := 5
var _cols: int = COLS
var _rows: int = 1
var _items: Array = []
## Where this grid decided to draw each item, keyed by the item itself so it
## survives a rebuild. Identity, not index: the list is filtered and reordered
## between refreshes and an index means nothing across one.
var _at: Dictionary = {}
## The tallest the grid has been this visit. It does not shrink, because a
## container that gets shorter as you empty it moves everything still in it.
var _high: int = 0
## The cells a carried thing would cover if you let go now, or empty.
##
## The hold has had this since it became a grid and the container had none, so
## dragging something out here lit nothing up and read as a dead surface -- which
## is half of why it looked like the drop was being refused when it was being
## accepted and not drawn.
var _beam: Rect2i = Rect2i()

## HOW FAST THE SWEEP CROSSES THE CONTAINER, in cells per second.
##
## 1.6 cells a second: a six-row container takes about three and three quarter
## seconds, and the two-row case a shade over one.
##
## This has been 14, then 4.5, then 2.6, and every one of them was too quick for
## the same reason -- the sweep finished before it had cost you anything, so it
## was decoration laid over a container that was simply there. At this rate
## opening a wreck TAKES a moment, and the moment is the point: you are reading
## the top row while the bottom is still dark, and deciding before you have seen
## everything.
const SCAN_CELLS_PER_SEC := 1.6

## The steps one thing goes through on its way out of the dark.
##
## Colour, horizontal offset, and how long to hold there. Deliberately a LIST OF
## STATES rather than a duration to interpolate over: a smooth fade is a light
## being turned up, and what this wants to be is a signal resolving -- a couple
## of false starts, a tear sideways, and then the thing is simply there.
##
## The offsets are small on purpose. Four pixels at a forty-pixel cell reads as
## the picture failing to hold still; twelve would read as the crate being in
## the wrong place, which is a bug rather than an effect.
const GLITCH: Array = [
	[0.85, 3.0, 0.045],
	[0.08, -4.0, 0.035],
	[1.00, 2.0, 0.050],
	[0.20, -2.0, 0.030],
	[0.90, 1.0, 0.045],
	[0.45, 0.0, 0.030],
]
## How far down the sweep has reached, in pixels, or -1 when it is not running.
var _scan: float = -1.0
## What the sweep has already found, so a rebuild mid-scan does not make a crate
## materialise twice.
var _lit: Dictionary = {}


## Sweep the container and let the contents in behind the line.
##
## Called once when the view opens, not on every refresh: this is what OPENING
## something looks like, and replaying it each time a crate moved would make
## every take feel like a new discovery.
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
		_materialise(ic)


## One thing resolving out of the sweep.
##
## Stepped, not interpolated. `tween_callback` sets a state and `tween_interval`
## holds it, so every change is a hard cut -- which is the whole difference
## between a thing switching on and a thing being picked up by an instrument
## that is not quite sure yet.
##
## It runs in the SWEEP'S colour and only lands on white at the end, so for the
## first tenth of a second the crate is the same light as the line that found
## it. Revealed by the sweep, rather than switched on underneath it.
func _materialise(ic: ItemIcon) -> void:
	var glow := UITheme.TRACTOR
	var home := ic.position
	ic.modulate = Color(glow.r, glow.g, glow.b, 0.0)
	var t := ic.create_tween()
	for raw in GLITCH:
		var step: Array = raw
		var a: float = step[0]
		var dx: float = step[1]
		t.tween_callback(func() -> void:
			ic.modulate = Color(glow.r, glow.g, glow.b, a)
			ic.position = home + Vector2(dx, 0.0))
		t.tween_interval(float(step[2]))
	# AND THEN IT IS SIMPLY THERE. Snapping home rather than easing to it: the
	# last thing a glitch should do is look like it was always going to land.
	t.tween_callback(func() -> void:
		ic.modulate = Color.WHITE
		ic.position = home)
## Which entries are spoken for. A bag row someone already claimed still takes
## up space in the picture, because a hole where a part was is information and
## a silently reflowed grid is not.
var _spent: Dictionary = {}


func _init() -> void:
	# STOP, not PASS. This control is a drop target across its whole area, and
	# PASS hands the event on to whatever is behind it -- which in a scroll
	# container is the scroll. The icons inside stay PASS so they can still be
	# picked up while the grid underneath keeps catching drops.
	mouse_filter = Control.MOUSE_FILTER_STOP


## `spent` holds the indices already claimed -- they draw greyed and cannot be
## picked up. `cols` is how wide the container reads; the rows follow from what
## has to fit.
func setup(items: Array, spent: Dictionary, cols: int = COLS) -> void:
	_items = items
	_spent = spent
	_cols = maxi(1, cols)
	_layout()
	_rebuild()


## First fit, largest first, which is the same rule `RunState.reseat` uses and
## for the same reason: first-fit on a fresh grid strands big things behind
## small ones, and a 4x1 that cannot find a row is a 4x1 you cannot see.
func _layout() -> void:
	# WHAT IS ALREADY PLACED KEEPS ITS CELL. Only things this grid has not seen
	# before get a slot found for them, and they get it around what is already
	# there -- so arriving loot lands in the gaps rather than reshuffling the
	# pile you were reading.
	var taken: Dictionary = {}
	var fresh: Array[HoldItem] = []
	for m0 in _items:
		var m: HoldItem = m0
		if _at.has(m):
			var was: Vector2i = _at[m]
			for dy0 in m.footprint().y:
				for dx0 in m.footprint().x:
					taken[was + Vector2i(dx0, dy0)] = true
		else:
			fresh.append(m)
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
	# ONE SPARE ROW, ALWAYS.
	#
	# The grid was exactly as big as its contents, which is tidy and made the
	# other half of the design unreachable: dropping one of YOUR things in here
	# is jettison, and with every cell occupied there was nowhere to aim it. The
	# drop logic worked the whole time and could not be asked.
	#
	# An empty row also says the thing that needs saying without a label -- that
	# this is somewhere you can put something, not just somewhere you take from.
	_rows += 1
	# NEVER SHORTER THAN IT HAS BEEN. Emptying a container used to shrink it,
	# which moved every remaining item up the screen -- the grid was correct and
	# the experience was of the pile squirming away from the cursor.
	_high = maxi(_high, _rows)
	_rows = _high
	# The MINIMUM is the picture. The control is allowed to be larger -- see
	# `_draw` -- and in `TransferView` it is, because the whole column is the
	# place you put things down.
	custom_minimum_size = Vector2(_cols * CELL, _rows * CELL)


## Scans down as far as it needs to. The container has no floor -- unlike a hold,
## which is a fixed box, a pile is however big the pile is, and refusing to show
## the last item because a number ran out would be inventing a rule.
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
		var icon: ItemIcon
		if m is MaterialData:
			var mi := MaterialIcon.new()
			mi.setup(m as MaterialData, &"bag")
			icon = mi
		else:
			var gi := ModuleIcon.new()
			gi.setup(m as ModuleData, &"bag")
			icon = gi
		# `bag`, not `cargo`, and this is the whole wiring. The drop site reads
		# it to know that taking this costs a CLAIM -- one bag, first hand in --
		# rather than being a free rearrangement of something you already own.
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


## The lattice is drawn at its OWN extent, not at the control's.
##
## The control is now bigger than the grid on purpose -- it fills the whole
## right-hand column so that dropping one of your things anywhere on that side
## is jettison. Before, its rect was exactly the packed cells, and Godot only
## offers a drop to the control under the pointer: with every cell occupied
## there was no part of it left to aim at, so `_can_drop_data` was never asked.
## The logic had been right the whole time and unreachable.
##
## So the picture and the target part company here. Everything below draws at
## `_cols` by `_rows`; the control extends past it and is all target.
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
		# THE UNSWEPT PART IS DARK, and the line itself is the brightest thing
		# on the panel for the moment it is there. Two rectangles and a rule --
		# the same flat vocabulary as everything else, and no shader.
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
	# The same ink the hold uses for the same question, because the hold and the
	# container are answering one thing -- where does this go -- and two idioms
	# for it would read as two different answers.
	var c := UITheme.TRACTOR
	var r := Rect2(Vector2(_beam.position) * float(CELL),
		Vector2(_beam.size) * float(CELL))
	draw_rect(r, Color(c.r, c.g, c.b, 0.14), true)
	draw_rect(r, Color(c.r, c.g, c.b, 0.7), false, 1.0)


## Which entry an item is, so a claim can name it. Identity, not equality --
## `n.bag` holds the very objects the icons were built from.
func index_of(m: HoldItem) -> int:
	return _items.find(m)


## Dropping one of YOUR things in here is jettison.
##
## The same motion as taking, mirrored, because it is the same idea seen from the
## other end: this is the floor of the system you are standing in, and putting
## something down on it is exactly what `Run.jettison` does. `MATERIALS_NOTE`
## 3.5 makes it apply to everything, so a gun and a crate leave the same way.
##
## Only things you OWN. An item already loose out here has nowhere further to
## fall, and letting it be dragged around inside the pile would suggest the
## arrangement meant something -- see the note at the top.
## Two kinds of drop land here, and they are different things.
##
## One of YOURS is jettison -- putting it down in the system you are standing in.
## One already out here is a REARRANGEMENT, which the first version refused on
## the grounds that nobody arranges a wreck. That reads as broken rather than as
## principled: the cells are right there, the thing moves under your hand
## everywhere else in the game, and refusing costs a rule nobody asked for.
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
	# One of yours, landing on the cells you are pointing at. The first version
	# framed the WHOLE container, on the grounds that the drop put it wherever
	# there was room -- which was true and was the wrong way round. A drop is a
	# decision about WHERE, and a highlight that cannot say where is a highlight
	# that says nothing.
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
		_at[m] = _cell_of(at, m)
		_layout()
		_rebuild()
		return
	# THE CELL IS CHOSEN BEFORE THE THROW, and recorded after it. `_layout`
	# keeps any cell this grid already knows and only finds slots for items it
	# has not seen -- so writing it here is what makes the thing land where the
	# beam said it would, instead of first-fitting into the top-left corner a
	# frame later.
	var cell := _target_for(at, m)
	if Run.jettison(m):
		_at[m] = cell
		picked.emit(m)


## Where a carried thing would land, measured from the ITEM rather than the
## pointer -- the same correction `HoldGrid.target_for` makes, and for the same
## reason: the plate is centred on the cursor.
func _cell_of(at: Vector2, m: HoldItem) -> Vector2i:
	var f := m.footprint()
	var top_left := at - Vector2(f.x, f.y) * float(CELL) * 0.5
	return Vector2i(
		clampi(int(round(top_left.x / float(CELL))), 0, maxi(0, _cols - f.x)),
		maxi(0, int(round(top_left.y / float(CELL)))))


## The cell a carried thing would actually land on.
##
## Where you aimed if that is clear; otherwise the nearest cell that is, scanned
## outward. The hold does the same thing through `target_for` and its `NUDGE` --
## a drop a cell off is a drop that meant the cell next to it, and refusing it
## outright makes packing a test of aim rather than of arithmetic.
func _target_for(at: Vector2, m: HoldItem) -> Vector2i:
	var want := _cell_of(at, m)
	if _fits(m, want):
		return want
	var best := want
	var best_d := 1e9
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t := want + Vector2i(dx, dy)
			if t.x < 0 or t.y < 0 or not _fits(m, t):
				continue
			var dist := Vector2(dx, dy).length_squared()
			if dist < best_d:
				best_d = dist
				best = t
	if _fits(m, best):
		return best
	# Nowhere near it will do, so anywhere will: a container has no floor and
	# refusing to accept something you are putting down would be inventing a
	# rule the fiction does not have.
	var taken: Dictionary = {}
	for other in _items:
		var o: HoldItem = other
		if o == m or not _at.has(o):
			continue
		var oc: Vector2i = _at[o]
		for dy2 in o.footprint().y:
			for dx2 in o.footprint().x:
				taken[oc + Vector2i(dx2, dy2)] = true
	return _first_fit(taken, m.footprint())


## Whether a cell is clear of everything except the item being moved.
func _fits(m: HoldItem, cell: Vector2i) -> bool:
	var f := m.footprint()
	if cell.x < 0 or cell.y < 0 or cell.x + f.x > _cols:
		return false
	for other in _items:
		var o: HoldItem = other
		if o == m or not _at.has(o):
			continue
		var oc: Vector2i = _at[o]
		var of := o.footprint()
		if cell.x < oc.x + of.x and oc.x < cell.x + f.x \
				and cell.y < oc.y + of.y and oc.y < cell.y + f.y:
			return false
	return true
