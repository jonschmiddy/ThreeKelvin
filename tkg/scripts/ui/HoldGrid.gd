class_name HoldGrid
extends Control

## The hold, as a grid you pack.
##
## Not a GridContainer, and it cannot be one: a container gives every child a
## cell, and half the catalogue is wider or taller than one. A part is placed at
## `hold_at` and drawn across its own footprint, so the layout is arithmetic on
## a fixed cell rather than something a container decides.
##
## Everything here reads Run and writes nothing. Drops are reported upward and
## the screen owns the state change, which is the same split ModuleCell already
## uses — one place to read when a part ends up somewhere it should not.

## One cell. Small, because a heavy's hold is four wide by ten deep and the
## panel beside the ship has about 200px to spend: at ModuleIcon's own 44 that
## grid would be 176 wide and 440 tall and the bottom four rows would be off the
## screen. 22 makes it 88 by 220, which fits under the hardpoints with room.
const CELL := 22
const GAP := 1

signal dropped(payload: Dictionary, at: Vector2i)

var _cols: int = 4
var _rows: int = 5
## Lit cells during a drag: where the thing being carried would actually fit.
var _beam: Dictionary = {}
var _beam_phase: float = 0.0
var _carrying: ModuleData = null

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
		var icon := ModuleIcon.new()
		icon.setup(m, &"cargo")
		icon.position = _origin(m.hold_at)
		icon.custom_minimum_size = _footprint(m)
		icon.size = _footprint(m)
		# PASS, not STOP: the icon is what you pick UP, and the grid under it is
		# what you drop ONTO. A child that swallowed the hover would leave the
		# grid unable to say which cell the cursor is over.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
	queue_redraw()

func _origin(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * (CELL + GAP), cell.y * (CELL + GAP))

func _footprint(m: ModuleData) -> Vector2:
	return Vector2(maxi(1, m.size.x) * (CELL + GAP) - GAP,
		maxi(1, m.size.y) * (CELL + GAP) - GAP)

## Which cell a point falls in. Outside the grid returns (-1,-1).
func cell_at(p: Vector2) -> Vector2i:
	var c := Vector2i(int(floor(p.x / float(CELL + GAP))),
		int(floor(p.y / float(CELL + GAP))))
	if c.x < 0 or c.y < 0 or c.x >= _cols or c.y >= _rows:
		return -Vector2i.ONE
	return c

func _process(delta: float) -> void:
	_beam_phase = fmod(_beam_phase + delta * 2.4, TAU)
	queue_redraw()

func _draw() -> void:
	for y in _rows:
		for x in _cols:
			var r := Rect2(_origin(Vector2i(x, y)), Vector2(CELL, CELL))
			draw_rect(r, Color("#0b1017"), true)
			draw_rect(r, UITheme.LINE, false, 1.0)
	if _beam.is_empty():
		return
	# The same pulse the hardpoints use, for the same reason: the hold and the
	# hull are answering one question — where does this go — and two different
	# idioms for it would read as two different answers.
	var pulse := 0.62 + 0.38 * sin(_beam_phase)
	var c := UITheme.TRACTOR
	for key in _beam:
		var cell: Vector2i = key
		var r := Rect2(_origin(cell), Vector2(CELL, CELL))
		draw_rect(r, Color(c.r, c.g, c.b, 0.16 * pulse), true)
		draw_rect(r, Color(c.r, c.g, c.b, 0.75 * pulse), false, 1.0)

## Where would `m` land if dropped at `p`, and does it fit there?
##
## Grabbed by the CELL UNDER THE CURSOR rather than by the part's top-left, so a
## wide part dropped with the cursor over its middle does not jump a cell to the
## left. Falls back to first fit when the cursor's cell will not take it, which
## is what makes a careless drop still put the thing somewhere sensible.
func _target_for(m: ModuleData, p: Vector2) -> Vector2i:
	var c := cell_at(p)
	if c != -Vector2i.ONE and Run.can_place(m, c):
		return c
	return Run.find_hold_slot(m)

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("module"):
		return false
	var m: ModuleData = data.module
	if m == null:
		return false
	var target := _target_for(m, at)
	_light(m, target)
	return target != -Vector2i.ONE

func _light(m: ModuleData, target: Vector2i) -> void:
	_beam.clear()
	if target != -Vector2i.ONE:
		for dy in maxi(1, m.size.y):
			for dx in maxi(1, m.size.x):
				_beam[target + Vector2i(dx, dy)] = true
	set_process(not _beam.is_empty())
	queue_redraw()

func _drop_data(at: Vector2, data: Variant) -> void:
	var m: ModuleData = (data as Dictionary).module
	var target := _target_for(m, at)
	_clear_beam()
	if target != -Vector2i.ONE:
		dropped.emit(data as Dictionary, target)

func _clear_beam() -> void:
	_beam.clear()
	_carrying = null
	set_process(false)
	queue_redraw()

func _notification(what: int) -> void:
	# Godot has no "the drag left me" callback, so the light is put out when the
	# mouse leaves and again when any drag anywhere ends — without the second,
	# a cell stays lit after a drop that landed on the hull instead.
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_clear_beam()
