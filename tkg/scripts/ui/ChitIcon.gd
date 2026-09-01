class_name ChitIcon
extends ItemIcon

## Money in a container.
##
## Drawn as stacked notes rather than as a crate, because the one thing it must
## not look like is something that will cost you room -- see `CreditChit`. A
## player who reads it as cargo will leave it behind when the hold is full,
## which is the exact decision this item exists not to make you take.
##
## Same flat rectangles as everything else, and the same stacked-notes idiom
## `CardView` already uses for its `scrip` glyph: "the human economy, which is
## the only kind a card ever pays out in".

var chit: CreditChit = null


func setup(c: CreditChit, from: StringName) -> void:
	chit = c
	origin = from
	# The same rule the top bar states, plus the two facts only the object has.
	tooltip_text = Widgets.tip("%d CREDITS\n\n%s\n\nTakes no room. It goes in whatever your hold looks like."
		% [c.amount, CreditChit.WHAT_MONEY_IS])
	queue_redraw()


func held_item() -> HoldItem:
	return chit


func _ghost() -> Control:
	var g := ChitIcon.new()
	g.setup(chit, origin)
	return ItemIcon.wrap_ghost(g, global_position)


func _draw() -> void:
	if chit == null:
		return
	# Brass, which is what the tier ladder already calls legendary, and the only
	# warm colour in a hold otherwise made of steel and ore. Money should be the
	# thing your eye goes to.
	var ink := Color("#0b0f16")
	var note := Color("#b8894a")
	var lit := note.lerp(Color.WHITE, 0.34)
	var dim := note.lerp(ink, 0.45)

	var box := Rect2(Vector2.ONE, size - Vector2(2, 2))
	# THREE NOTES, OFFSET, so it reads as a quantity rather than as one object.
	# Drawn back to front: the one on top is the one that is fully lit.
	for i in 3:
		var step := float(2 - i)
		var r := Rect2(box.position + Vector2(step * 2.0, step * 2.0),
			box.size - Vector2(6.0, 6.0))
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		draw_rect(r, dim if i < 2 else note, true)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)),
			lit if i == 2 else note, true)
		draw_rect(r, ink, false, 1.0)
	# A mark on the top note. Not a number -- the tooltip carries the amount, and
	# a figure small enough to fit here is a figure nobody can read.
	var c := box.position + box.size * 0.5 - Vector2(3.0, 3.0)
	draw_rect(Rect2(c, Vector2(6.0, 2.0)), ink, true)
	draw_rect(Rect2(c + Vector2(0.0, 4.0), Vector2(6.0, 2.0)), ink, true)
