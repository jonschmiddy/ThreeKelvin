class_name PadStrip
extends Control

## The dock. What came off the old ship with nowhere in the new hold to go.
##
## A SEPARATE CONTROL FROM `HoldGrid` BECAUSE IT IS NOT A GRID. The hold is a
## packing problem -- a part sits at a cell, occupies its footprint, and the
## whole widget exists to let you arrange it. Nothing on the pad has a position
## and nothing here can be arranged: it is a queue of objects waiting for a
## cell, drawn in the order they came off. Giving it `hold_at` semantics would
## have meant inventing a second grid nobody flies.
##
## It reads `Run.pad` and writes nothing. Picking something up is a Godot drag
## with `origin` set to `&"pad"`, which `ShipScreen._on_hold_drop` reads to tell
## an arrival from the dock apart from a move inside the hold -- the same way
## `&"hull"` and `&"bag"` are already told apart.
##
## IT IS ONLY ON SCREEN WHEN IT HAS SOMETHING ON IT. A permanent empty strip
## under the hold would be a widget that means nothing on all but one screen of
## one visit per run; `ShipScreen` hides it when `Run.pad` is empty, which is
## almost always.

## The same cell as the hold, and that is the point of the number rather than a
## coincidence. A part on the dock and the same part stowed have to read as one
## object -- you are about to drag it from here to there and watch it land, and
## a plate that changed size on the way would look like a different thing
## arriving. See `HoldGrid.CELL`, which owns the reasoning.
const CELL := HoldGrid.CELL
const GAP := HoldGrid.GAP

## How wide the strip is allowed to get before it wraps, in CELLS.
##
## Set by the caller to the hold's own width, so the dock and the hold are the
## same rectangle and the eye reads them as two halves of one problem. It is a
## variable and not `Run.hold_grid().x` because the hold whose width matters is
## the one drawn NEXT to this, and a widget that goes looking for global state
## to size itself against is a widget that cannot be put anywhere else.
var cols: int = 5

func refresh() -> void:
	Widgets.clear(self)
	var x := 0
	var y := 0
	var rows := 1
	for m in Run.pad:
		var w: int = maxi(1, m.size.x)
		var h: int = maxi(1, m.size.y)
		# WRAP BEFORE PLACING, not after. A 4x1 spine starting in column 3 of a
		# 5-wide strip would hang two cells off the right edge -- the same class
		# of bug HoldGrid's own footprint sizing had, and invisible in exactly
		# the same way because nothing underneath is wrong.
		if x + w > cols:
			x = 0
			y += 1
		var icon := ItemIcon.make(m, &"pad")
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
		# AFTER add_child, AND the minimum cleared first -- `ModuleIcon.setup`
		# puts a 44x44 floor under itself and the entry pass would otherwise
		# overwrite the size assigned here. HoldGrid.refresh carries the full
		# account of why; this is the same two lines for the same reason.
		icon.custom_minimum_size = Vector2.ZERO
		icon.position = Vector2(x * (CELL + GAP), y * (CELL + GAP))
		icon.size = Vector2(w * CELL + (w - 1) * GAP, h * CELL + (h - 1) * GAP)
		x += w
		rows = maxi(rows, y + h)
	custom_minimum_size = Vector2(cols * (CELL + GAP) - GAP,
		rows * (CELL + GAP) - GAP)
	queue_redraw()


## The empty cells behind the plates, in the LEAVE red rather than the hold's
## own grey.
##
## The hold's lattice says "this is where things go". This one says "these are
## not stowed", which is a different statement and has to look like one -- the
## strip sits directly under the grid, and two identical lattices stacked would
## read as one hold with seven rows.
func _draw() -> void:
	var ink := UITheme.LEAVE
	ink.a = 0.20
	var rows := maxi(1, int(round((size.y + GAP) / float(CELL + GAP))))
	for ry in rows:
		for cx in cols:
			draw_rect(Rect2(Vector2(cx * (CELL + GAP), ry * (CELL + GAP)),
				Vector2(CELL, CELL)), ink, false, 1.0)
