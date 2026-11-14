class_name ChitIcon
extends ItemIcon

## Drawn as notes, not a crate: it must not look like cargo that costs room, or players leave it.
## Why: docs/why/ChitIcon.md#credit-chit

var chit: CreditChit = null
## The credit chit's ink and brass.
const CHIT_INK := Color("#0b0f16")
const CHIT_BRASS := Color("#b8894a")


func setup(c: CreditChit, from: StringName) -> void:
	chit = c
	origin = from
	tooltip_text = tip_text(c)
	queue_redraw()


## The tooltip's words: the same rule the top bar states, plus the two facts
## only the object has. Also the cutaway's card for it (`MaterialIcon.tip_for`).
static func tip_text(c: CreditChit) -> String:
	return Widgets.tip("%d CREDITS\n\n%s\n\nTakes no room in your hold."
		% [c.amount, CreditChit.WHAT_MONEY_IS])


func held_item() -> HoldItem:
	return chit


func _ghost() -> Control:
	var g := ChitIcon.new()
	g.setup(chit, origin)
	return ItemIcon.wrap_ghost(g, global_position)


func _draw() -> void:
	if chit == null:
		return
	# Brass is the only warm colour in a hold of steel and ore, so money draws the eye.
	var ink := CHIT_INK
	var note := CHIT_BRASS
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
