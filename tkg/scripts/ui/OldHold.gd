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
	# The exception is a part that came off a HARDPOINT: it never had a cell, so
	# `_seat_the_pad` finds it one -- and that can fail, because a hull's
	# loadout does not have to fit inside that hull's hold. What has no cell
	# after all that is stacked along the bottom edge rather than drawn at
	# (0,0) on top of whatever is already there.
	var spill := 0
	for m in Run.pad:
		# WHAT IS BOLTED ON IS NOT IN THE HOLD. A pad module remembers the
		# hardpoint it was fitted to, and the ship above this grid draws it
		# there -- so listing it here as well put every gun on screen twice,
		# once on the hull and once in a row of leftovers spilling out past the
		# edge of a hold it was never in.
		var mod := m as ModuleData
		if mod != null and mod.mount >= 0:
			continue
		var icon := ItemIcon.make(m, &"pad")
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
		icon.custom_minimum_size = Vector2.ZERO
		var f := m.footprint()
		var at := m.hold_at
		if at.x < 0:
			at = Vector2i(spill, _rows)
			spill += f.x
		icon.position = Vector2(at.x * (CELL + GAP), at.y * (CELL + GAP))
		icon.size = Vector2(f.x * CELL + (f.x - 1) * GAP,
			f.y * CELL + (f.y - 1) * GAP)
	var deep: int = _rows + (1 if spill > 0 else 0)
	custom_minimum_size = Vector2(maxi(_cols, spill) * (CELL + GAP) - GAP,
		deep * (CELL + GAP) - GAP)
	queue_redraw()


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
