class_name StatusChip
extends PanelContainer

## Icons replace words in the status row: read by shape, with a tooltip as the entry.
## Why: docs/why/StatusChip.md#status-chips

## Twelve pixels, so the chip fits under a hull and icons sit on whole pixels.
const ICON := 12


## The picture half of a chip.
class Glyph extends Control:
	var kind: StringName
	var tint: Color

	func _init(k: StringName, t: Color) -> void:
		kind = k
		tint = t
		custom_minimum_size = Vector2(StatusChip.ICON, StatusChip.ICON)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## One rectangle, in glyph pixels.
	func _p(x: int, y: int, w: int, h: int, c: Color) -> void:
		draw_rect(Rect2(float(x), float(y), float(w), float(h)), c, true)

	func _draw() -> void:
		var lit := tint.lerp(Color.WHITE, 0.35)
		var dim := tint.lerp(Color("#0b0f16"), 0.35)
		match kind:
			&"block":
				# Flat plating, layered. No point on it: block is a slab that
				# soaks one hit, not a shield you hold up.
				_p(1, 3, 10, 2, lit)
				_p(1, 5, 10, 4, tint)
				_p(1, 9, 10, 1, dim)
			&"lock":
				# The reticle, redrawn from the card's, written corner by corner (L is handed).
				_p(1, 1, 4, 1, tint)
				_p(1, 1, 1, 4, tint)
				_p(7, 1, 4, 1, tint)
				_p(10, 1, 1, 4, tint)
				_p(1, 10, 4, 1, tint)
				_p(1, 7, 1, 4, tint)
				_p(7, 10, 4, 1, tint)
				_p(10, 7, 1, 4, tint)
				_p(5, 5, 2, 2, UITheme.HOT)
			&"slip":
				# The halves must be big, or the missed-round glyph read as a division sign.
				# Why: docs/why/StatusChip.md#glyph-design
				_p(1, 0, 5, 4, dim)
				_p(1, 8, 5, 4, dim)
				_p(0, 5, 12, 2, lit)
			&"salvo":
				# Solid chevrons: implied diagonals of blocks read as a checkerboard at this size.
				# Why: docs/why/StatusChip.md#glyph-design
				_p(1, 2, 3, 1, dim)
				_p(4, 1, 5, 3, tint)
				_p(9, 1, 2, 3, lit)
				_p(1, 9, 3, 1, dim)
				_p(4, 8, 5, 3, tint)
				_p(9, 8, 2, 3, lit)
			&"feedback":
				# An arrow pointing back at the sender. Damage returning is the
				# whole of the keyword, so the glyph is just the direction.
				_p(4, 5, 7, 2, tint)
				_p(2, 4, 2, 4, lit)
				_p(1, 5, 1, 2, lit)
			&"adapt":
				# Bars getting taller. It grows every time it fires, so the
				# picture is the growth rather than the thing growing.
				_p(1, 8, 3, 3, dim)
				_p(4, 5, 3, 6, tint)
				_p(7, 2, 3, 9, lit)
			&"drone":
				# A small craft with rotors: body, two mounts, a nose.
				_p(3, 4, 6, 3, tint)
				_p(2, 2, 2, 2, dim)
				_p(2, 7, 2, 2, dim)
				_p(9, 5, 2, 1, lit)
			&"wasp":
				# The guard drone: the drone glyph over a tapered plate of armour.
				# Why: docs/why/StatusChip.md#glyph-design
				_p(4, 0, 4, 2, tint)
				_p(2, 0, 2, 1, dim)
				_p(8, 0, 2, 1, dim)
				_p(2, 4, 8, 1, lit)
				_p(2, 5, 8, 3, tint)
				_p(3, 8, 6, 1, tint)
				_p(4, 9, 4, 1, dim)
				_p(5, 10, 2, 1, dim)
			&"charging":
				# An hourglass. The card is not doing anything yet and the only
				# fact about it is how long until it does.
				_p(2, 1, 8, 1, lit)
				_p(3, 2, 6, 1, tint)
				_p(4, 3, 4, 1, tint)
				_p(5, 4, 2, 1, tint)
				_p(5, 5, 2, 2, dim)
				_p(5, 7, 2, 1, tint)
				_p(4, 8, 4, 1, tint)
				_p(3, 9, 6, 1, tint)
				_p(2, 10, 8, 1, lit)
			&"peaceful":
				# Level is two thin rules; `block` is a solid mass.
				# Why: docs/why/StatusChip.md#glyph-design
				_p(1, 3, 10, 1, tint)
				_p(1, 7, 10, 1, tint)
			_:
				# An unnamed status shows a hollow box, a visible bug rather than a silent vanish.
				_p(1, 1, 10, 1, tint)
				_p(1, 10, 10, 1, tint)
				_p(1, 2, 1, 8, tint)
				_p(10, 2, 1, 8, tint)


## `text` is the number; pass empty for an on or off status and the chip is the icon alone.
static func make(kind: StringName, text: String, colour: Color,
		tip: String) -> StatusChip:
	var chip := StatusChip.new()
	chip.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0, 0, 0, 0), colour, 2, 2, 4))
	# THE WHOLE CHIP ANSWERS THE HOVER. A tooltip on the glyph alone leaves the
	# digit beside it inert, which reads as two things when it is one.
	chip.tooltip_text = Widgets.tip(tip)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)

	var g := Glyph.new(kind, colour)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)

	if text != "":
		var n := UITheme.body(text, UITheme.CHILL, 10)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(n)
	return chip
