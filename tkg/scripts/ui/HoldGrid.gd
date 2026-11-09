class_name HoldGrid
extends Control

## Not a GridContainer: parts span many cells, so layout is arithmetic on a fixed cell.
## Reads Run and writes nothing; drops go upward and the screen owns the state change.
## Why: docs/why/HoldGrid.md#hold-grid

## Forty so the hull draws a cell at twenty: at 30 no module reached PixelLab's 1024px area floor.
## It costs panel (5 columns from 154 to 200 px), a trade made knowingly.
## Why: docs/why/HoldGrid.md#cell-size
const CELL := 40

## Zero with the lattice drawn: a gap of one made cells 31 wide and could not halve for the hull.
## Why: docs/why/HoldGrid.md#cell-gap
const GAP := 0

## The outer edge is a stroke meant to be seen: before, the grid boundary read as the weakest line.
const EDGE := 2.0

## Two cells: far enough to catch a near miss, close enough never to land out of sight.
const NUDGE := 2

signal dropped(payload: Dictionary, at: Vector2i)

var _cols: int = 4
var _rows: int = 5
## Lit cells during a drag: where the thing being carried would actually fit.
var _beam: Dictionary = {}
var _beam_phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

func refresh() -> void:
	var g := Run.hold_grid()
	_cols = maxi(1, g.x)
	_rows = maxi(1, g.y)
	custom_minimum_size = Vector2(_cols * (CELL + GAP) - GAP,
		_rows * (CELL + GAP) - GAP)
	Widgets.clear(self)
	for m in Run.cargo:
		if m.hold_at.x < 0:
			continue
		# A module draws the part, a material a crate; a chit here is a bug you can see.
		# Why: docs/why/HoldGrid.md#mixed-grid
		var icon := ItemIcon.make(m, &"cargo")
		# PASS, not STOP: the icon is picked up, and the grid under it needs the hover.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
		# Sized after `add_child`, minimum cleared: ModuleIcon's 44 floor hung a 1x1 past the grid.
		# Only plates overlapped, so `-- holdtest` passes either way: it was never a packing bug.
		# Why: docs/why/HoldGrid.md#icon-sizing
		icon.custom_minimum_size = Vector2.ZERO
		icon.position = _origin(m.hold_at)
		icon.size = _footprint(m)
	queue_redraw()

func _origin(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * (CELL + GAP), cell.y * (CELL + GAP))

func _footprint(m: HoldItem) -> Vector2:
	return ModuleIcon.footprint_box(m)

## The MODULE plate under a point in SCREEN coordinates, or null. R used to
## turn through this and so never turned a material; it asks `item_at` now.
func icon_at(p: Vector2) -> ModuleIcon:
	for c in get_children():
		if c is ModuleIcon and (c as Control).get_global_rect().has_point(p):
			return c
	return null

## Any hold item's icon, not only modules: LOCAL's cutaway and R need materials found too.
func item_at(p: Vector2) -> ItemIcon:
	for c in get_children():
		if c is ItemIcon and (c as Control).get_global_rect().has_point(p):
			return c
	return null

func _process(delta: float) -> void:
	_beam_phase = fmod(_beam_phase + delta * 2.4, TAU)
	queue_redraw()

func _draw() -> void:
	# Drawn to the cells' extent, not `size`: a wider header ran the frame 14 px past.
	# Why: docs/why/HoldGrid.md#draw-extent
	var extent := Vector2(_cols * (CELL + GAP) - GAP, _rows * (CELL + GAP) - GAP)
	for y in _rows:
		for x in _cols:
			var r := Rect2(_origin(Vector2i(x, y)), Vector2(CELL, CELL))
			draw_rect(r, Color("#0b1017"), true)
	# The lattice is drawn: with GAP zero, one shared stroke per interior edge.
	for x in range(1, _cols):
		var px := float(x * CELL)
		draw_line(Vector2(px, 0.0), Vector2(px, extent.y), UITheme.LINE, 1.0)
	for y in range(1, _rows):
		var py := float(y * CELL)
		draw_line(Vector2(0.0, py), Vector2(extent.x, py), UITheme.LINE, 1.0)
	draw_rect(Rect2(Vector2.ZERO, extent), UITheme.LINE, false, EDGE)
	if _beam.is_empty():
		return
	# The same pulse as the hardpoints: two idioms for where does this go read as two answers.
	var pulse := 0.62 + 0.38 * sin(_beam_phase)
	var c := UITheme.TRACTOR
	for key in _beam:
		var cell: Vector2i = key
		var r := Rect2(_origin(cell), Vector2(CELL, CELL))
		draw_rect(r, Color(c.r, c.g, c.b, 0.16 * pulse), true)
		draw_rect(r, Color(c.r, c.g, c.b, 0.75 * pulse), false, 1.0)

## Nearest free cell within a couple of cells, else nothing: first-fit teleported parts.
## Measured from the item, not the pointer, as the ghost is centred; rounded, not floored.
## Why: docs/why/HoldGrid.md#drop-target
func target_for(m: HoldItem, p: Vector2) -> Vector2i:
	var g := Run.hold_grid()
	var f := m.footprint()
	var step := float(CELL + GAP)
	var top_left := p - Vector2(f.x, f.y) * step * 0.5
	# Clamped, not rejected: a drop a few pixels outside the grid is aimed at
	# the edge cell, which is what the hand meant.
	var c := Vector2i(
		clampi(int(round(top_left.x / step)), 0, maxi(0, g.x - f.x)),
		clampi(int(round(top_left.y / step)), 0, maxi(0, g.y - f.y)))
	# One occupancy map for the whole probe -- this runs on every drag-over
	# frame, and `can_place` re-derived the map for each of the 26 candidates.
	var taken := Run.hold_taken(m)
	if Run.fits_at(taken, m, c):
		return c
	var best := -Vector2i.ONE
	var best_d := 1e9
	for dy in range(-NUDGE, NUDGE + 1):
		for dx in range(-NUDGE, NUDGE + 1):
			var t := c + Vector2i(dx, dy)
			if t.x < 0 or t.y < 0 or not Run.fits_at(taken, m, t):
				continue
			var d := Vector2(dx, dy).length_squared()
			if d < best_d:
				best_d = d
				best = t
	return best

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("module"):
		return false
	var m: HoldItem = data.module
	if m == null:
		return false
	# Money lights the whole hold: it occupies no cell, so wherever you let go it lands.
	if m is CreditChit:
		_light_all()
		return true
	var target := target_for(m, at)
	_light(m, target)
	return target != -Vector2i.ONE

## Every cell at once, for the one thing that fits in all of them.
func _light_all() -> void:
	var g := Run.hold_grid()
	var want: Dictionary = {}
	for y in g.y:
		for x in g.x:
			want[Vector2i(x, y)] = true
	if want.keys() == _beam.keys():
		return
	_beam = want
	set_process(true)
	queue_redraw()


func _light(m: HoldItem, target: Vector2i) -> void:
	_beam.clear()
	if target != -Vector2i.ONE:
		var f := m.footprint()
		for dy in f.y:
			for dx in f.x:
				_beam[target + Vector2i(dx, dy)] = true
	set_process(not _beam.is_empty())
	queue_redraw()

func _drop_data(at: Vector2, data: Variant) -> void:
	var m: HoldItem = (data as Dictionary).module
	var target := target_for(m, at)
	_clear_beam()
	# Money takes no cell, so a full hold still takes the drop it lit.
	if m is CreditChit and target == -Vector2i.ONE:
		target = Vector2i.ZERO
	if target != -Vector2i.ONE:
		dropped.emit(data as Dictionary, target)

func _clear_beam() -> void:
	_beam.clear()
	set_process(false)
	queue_redraw()

func _notification(what: int) -> void:
	# Godot has no drag-left callback: also clear on any DRAG_END, or a cell stays lit.
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_clear_beam()
