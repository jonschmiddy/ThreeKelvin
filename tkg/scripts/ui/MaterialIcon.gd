class_name MaterialIcon
extends Control

## A material sitting in the hold.
##
## The counterpart to `ModuleIcon`, and deliberately NOT a variant of it. A
## module icon draws the part -- a barrel, an array, a bay -- because the whole
## reason it shares a silhouette with the thing on the hull is so you recognise
## the gun you are about to bolt on. A material has no hull form to echo. It is
## cargo: a crate, a spool, a drum, and what you actually need to read off it is
## how much room it takes and how good it is.
##
## So this draws a CONTAINER, sized to its footprint, coloured by its tier. Same
## flat rectangles and same 40-pixel cell as the module icons beside it, so a
## packed hold reads as one surface with two kinds of thing in it rather than as
## two art styles sharing a grid.

var item: MaterialData = null

## Where it came from, matching `ModuleIcon.origin` -- the drag payload carries
## it so a drop knows whether it is a move inside the hold or an arrival.
var origin: StringName = &"cargo"


func setup(m: MaterialData, from: StringName) -> void:
	item = m
	origin = from
	tooltip_text = "%s\n\n%s\n\nSells for %d." % [m.name, m.text, m.value]
	queue_redraw()


func _draw() -> void:
	if item == null:
		return
	var tint := UITheme.tier_colour(item.tier)
	var lit := tint.lerp(Color.WHITE, 0.28)
	var dim := tint.lerp(Color("#0b0f16"), 0.52)
	var ink := Color("#0b0f16")

	# The body fills the footprint less a hairline, so two crates in adjacent
	# cells read as two objects rather than one long one.
	var box := Rect2(Vector2.ONE, size - Vector2(2, 2))
	draw_rect(box, dim, true)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 2)), lit, true)
	draw_rect(box, tint, false, 1.0)

	# BANDING ACROSS THE SHORT AXIS, which is what makes it read as a crate
	# rather than as a coloured rectangle. Spaced off the cell rather than off
	# the box, so a 2x1 gets twice the bands of a 1x1 instead of the same two
	# stretched -- the strapping belongs to the object's length, not to its icon.
	var along := box.size.x >= box.size.y
	var run := box.size.x if along else box.size.y
	var bands := maxi(2, int(run / 14.0))
	for i in bands:
		var t := (float(i) + 0.5) / float(bands)
		if along:
			var x := box.position.x + run * t
			draw_rect(Rect2(x - 1.0, box.position.y + 3.0, 2.0,
				box.size.y - 6.0), ink, true)
		else:
			var y := box.position.y + run * t
			draw_rect(Rect2(box.position.x + 3.0, y - 1.0,
				box.size.x - 6.0, 2.0), ink, true)

	# A corner pip in the tier's own colour. The band colour is already the tier,
	# but a crate seen against a lit neighbour loses it -- the pip sits on ink and
	# does not.
	draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(4, 4)), lit, true)
