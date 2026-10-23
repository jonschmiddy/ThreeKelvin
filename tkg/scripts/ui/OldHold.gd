class_name OldHold
extends Control

## The hold of the ship you are LEAVING, with whatever is still in it.
##
## A SOURCE, NEVER A TARGET, and that is what keeps it cheap. `HoldGrid` is
## coupled to `Run` all the way down -- `hold_grid`, `hold_taken`, `fits_at`,
## `cargo` -- because it has to answer "does this fit here" on every frame of a
## drag. None of that applies to a ship being abandoned: you drag things OUT of
## this and never arrange anything in it, so it needs no fit test, no beam and
## no drop handler. Generalising HoldGrid to cover both would have meant
## threading a second hold through five methods of the one widget the whole
## refit screen rests on, to buy a feature this side does not want.
##
## It reads `Run.pad` for its contents and `Run.old_hull` for its shape.

const CELL := HoldGrid.CELL
const GAP := HoldGrid.GAP

var _cols: int = 5
var _rows: int = 4

func refresh() -> void:
	Widgets.clear(self)
	var g := Vector2i(5, 4) if Run.old_hull == null else Run.old_hull.hold_grid
	_cols = maxi(1, g.x)
	_rows = maxi(1, g.y)

	# THE STRAYS SIT WHERE THEY SAT. `transfer_to_hull` preserves `hold_at` for
	# anything that does not make the crossing, so the grid you are looking at
	# is the hold you packed rather than a bin the leftovers were tipped into.
	#
	# The exception is a thing with no cell of its own in this grid: a part that
	# came off a HARDPOINT with no old ship to draw it on, or a cell outside the
	# grid, or one something else already sits in. Each of those takes the first
	# gap that fits, and below the lattice when the lattice is full -- never at
	# a cell on top of something else, and never in one long row out past the
	# edge of the column, which is how a pad of fourteen used to draw.
	var taken := {}
	var placed: Array = []
	var loose: Array[HoldItem] = []
	for m in Run.pad:
		# WHAT IS BOLTED ON IS NOT IN THE HOLD. A pad module remembers the
		# hardpoint it was fitted to, and the ship above this grid draws it
		# there -- so listing it here as well put every gun on screen twice,
		# once on the hull and once in a row of leftovers spilling out past the
		# edge of a hold it was never in. UNLESS THERE IS NO SHIP above it to
		# draw it (`Run.old_hull` null): then here is the only place it shows.
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


## The lattice, in the ink the rest of the game uses for something being lost.
##
## NOT the hold's own grey. This grid sits three inches from a live one and the
## two say opposite things -- that is where your things go, this is where your
## things are stranded -- so drawing them the same would read as one hold with
## nine rows rather than as two ships.
func _draw() -> void:
	var ink := UITheme.LEAVE
	ink.a = 0.22
	for y in _rows:
		for x in _cols:
			draw_rect(Rect2(Vector2(x * (CELL + GAP), y * (CELL + GAP)),
				Vector2(CELL, CELL)), ink, false, 1.0)
