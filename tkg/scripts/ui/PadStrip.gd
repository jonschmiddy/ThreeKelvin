class_name PadStrip
extends Control

## Not a grid: it is a queue with no positions. Reads `Run.pad`, hidden when empty, drags
## origin `&"pad"`.
## Why: docs/why/PadStrip.md#dock-strip

## Same cell as the hold, so a part reads as one object when dragged across.
const CELL := HoldGrid.CELL
const GAP := HoldGrid.GAP

## A variable set by the caller to the hold's width, so the strip does not look up global
## state.
## Why: docs/why/PadStrip.md#strip-width
var cols: int = 5

func refresh() -> void:
	Widgets.clear(self)
	var x := 0
	var y := 0
	var rows := 1
	for m in Run.pad:
		var w: int = maxi(1, m.size.x)
		var h: int = maxi(1, m.size.y)
		# Wrap before placing: a 4x1 in column 3 of 5 would hang off the edge.
		if x + w > cols:
			x = 0
			y += 1
		var icon := ItemIcon.make(m, &"pad")
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
		# After `add_child` with the minimum cleared: `ModuleIcon.setup` floors at 44x44 and
		# overwrites the size.
		icon.custom_minimum_size = Vector2.ZERO
		icon.position = Vector2(x * (CELL + GAP), y * (CELL + GAP))
		icon.size = Vector2(w * CELL + (w - 1) * GAP, h * CELL + (h - 1) * GAP)
		x += w
		rows = maxi(rows, y + h)
	custom_minimum_size = Vector2(cols * (CELL + GAP) - GAP,
		rows * (CELL + GAP) - GAP)
	queue_redraw()


## Drawn in LEAVE red, as two identical lattices stacked would read as one hold of seven
## rows.
## Why: docs/why/PadStrip.md#dock-lattice
func _draw() -> void:
	var ink := UITheme.LEAVE
	ink.a = 0.20
	var rows := maxi(1, int(round((size.y + GAP) / float(CELL + GAP))))
	for ry in rows:
		for cx in cols:
			draw_rect(Rect2(Vector2(cx * (CELL + GAP), ry * (CELL + GAP)),
				Vector2(CELL, CELL)), ink, false, 1.0)
