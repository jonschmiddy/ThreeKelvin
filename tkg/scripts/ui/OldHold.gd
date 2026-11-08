class_name OldHold
extends Control

## A source, never a target: HoldGrid is coupled to Run for fit tests a hold being abandoned
## never needs. Generalising HoldGrid meant threading a second hold through five methods.
## Why: docs/why/OldHold.md#old-hold

const CELL := HoldGrid.CELL
const GAP := HoldGrid.GAP

var _cols: int = 5
var _rows: int = 4

func refresh() -> void:
	Widgets.clear(self)
	var g := Vector2i(5, 4) if Run.old_hull == null else Run.old_hull.hold_grid
	_cols = maxi(1, g.x)
	_rows = maxi(1, g.y)

	# Strays sit where they sat, as `transfer_to_hull` keeps `hold_at`; those without a cell take
	# the first gap. Never on top of something, and never in one long row past the column edge.
	# Why: docs/why/OldHold.md#strays
	var taken := {}
	var placed: Array = []
	var loose: Array[HoldItem] = []
	for m in Run.pad:
		# Bolted-on modules are not in the hold: listing them put every gun on screen twice.
		# Unless there is no old ship above to draw them.
		# Why: docs/why/OldHold.md#strays
		var mod := m as ModuleData
		if mod != null and mod.mount >= 0 and Run.old_hull != null:
			continue
		if _fits(taken, m, m.hold_at, _rows):
			_take(taken, m, m.hold_at)
			placed.append([m, m.hold_at])
		else:
			loose.append(m)
	var deep := _rows
	for m in loose:
		var at := _gap(taken, m)
		_take(taken, m, at)
		placed.append([m, at])
		deep = maxi(deep, at.y + m.footprint().y)
	var wide := _cols
	for pm: Array in placed:
		var m: HoldItem = pm[0]
		var at: Vector2i = pm[1]
		var icon := ItemIcon.make(m, &"pad")
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
		icon.custom_minimum_size = Vector2.ZERO
		var f := m.footprint()
		wide = maxi(wide, at.x + f.x)
		icon.position = Vector2(at.x * (CELL + GAP), at.y * (CELL + GAP))
		icon.size = Vector2(f.x * CELL + (f.x - 1) * GAP,
			f.y * CELL + (f.y - 1) * GAP)
	custom_minimum_size = Vector2(wide * (CELL + GAP) - GAP,
		deep * (CELL + GAP) - GAP)
	queue_redraw()


## Whether `m` sits at `at` inside the grid's width and `rows` rows, off `taken`.
func _fits(taken: Dictionary, m: HoldItem, at: Vector2i, rows: int) -> bool:
	var f := m.footprint()
	if at.x < 0 or at.y < 0 or at.x + f.x > maxi(_cols, f.x) or at.y + f.y > rows:
		return false
	for dy in f.y:
		for dx in f.x:
			if taken.has(at + Vector2i(dx, dy)):
				return false
	return true


func _take(taken: Dictionary, m: HoldItem, at: Vector2i) -> void:
	var f := m.footprint()
	for dy in f.y:
		for dx in f.x:
			taken[at + Vector2i(dx, dy)] = true


## The first gap `m` fits, reading the grid row by row and carrying on below it.
func _gap(taken: Dictionary, m: HoldItem) -> Vector2i:
	var f := m.footprint()
	for y in 256:
		for x in maxi(1, _cols - f.x + 1):
			var at := Vector2i(x, y)
			if _fits(taken, m, at, 1 << 20):
				return at
	return Vector2i(0, 256)


## Drawn in the ink for loss, not the hold's grey:
## it sits beside a live hold and says the opposite thing.
## Why: docs/why/OldHold.md#lattice-ink
func _draw() -> void:
	var ink := UITheme.LEAVE
	ink.a = 0.22
	for y in _rows:
		for x in _cols:
			draw_rect(Rect2(Vector2(x * (CELL + GAP), y * (CELL + GAP)),
				Vector2(CELL, CELL)), ink, false, 1.0)
