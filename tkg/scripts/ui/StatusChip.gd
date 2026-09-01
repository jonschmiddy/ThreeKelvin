class_name StatusChip
extends PanelContainer

## One thing currently true about a ship, drawn rather than spelled.
##
## The status row under your hull used to be words in boxes -- "brace 5",
## "lock +2", "salvo up". Words are unambiguous and they are also slow: a row of
## five of them is a paragraph you have to read every turn, it grows wider than
## the ship it belongs to, and at `FS_SMALL` under a sprite it competes with the
## hull number that is the one thing there you must never misread.
##
## An icon is read in the shape rather than in the letters, so five of them are
## still one glance. The cost is that the NAME is gone, and a picture nobody can
## name is worse than a word -- so every chip carries a tooltip that says the
## word out loud, and the magnitude stays as a digit beside the glyph. The icon
## is the index; the tooltip is the entry.
##
## The glyphs are built from the same parts as `CardView`'s keyword art -- flat
## rectangles on a small grid, no curves, no anti-aliasing -- but they are drawn
## at a twelfth of the size, which means they are DIFFERENT drawings and not the
## card art scaled down. A reticle that is legible at 44 pixels is four grey
## smudges at 12.

## The glyph's box. Twelve, because the chip has to sit under a hull without
## crowding the number beside it, and because every icon here is built from
## whole pixels: an odd size gives a centred two-pixel mark nowhere to land.
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
			&"brace":
				# A plate with a point on it. Brace and block are both armour
				# and have to differ in SHAPE rather than in colour, because
				# colour is what tells you whose they are.
				#
				# The taper runs five rows, not two. The first version came off
				# the sheet as a rounded bag: at twelve pixels a point has to be
				# most of the shape or it is not a point.
				_p(1, 1, 10, 1, lit)
				_p(1, 2, 10, 4, tint)
				_p(2, 6, 8, 1, tint)
				_p(3, 7, 6, 1, tint)
				_p(4, 8, 4, 1, dim)
				_p(5, 9, 2, 2, dim)
			&"block":
				# Flat plating, layered. No point on it: block is a slab that
				# soaks one hit, not a shield you hold up.
				_p(1, 3, 10, 2, lit)
				_p(1, 5, 10, 4, tint)
				_p(1, 9, 10, 1, dim)
			&"lock":
				# The reticle, which is the one glyph that also exists on a card
				# -- see `CardView._type_glyph`, `&"lock"`. Same idea, redrawn:
				# the card's version is written out corner by corner because an
				# L has a handedness, and so is this.
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
				# The round going through where the ship WAS. Absence, drawn --
				# the same joke the card's glyph tells, with fewer pixels.
				#
				# The halves have to be BIG. Drawn as narrow stubs they stopped
				# reading as a ship at all and the whole glyph came off the
				# sheet as a division sign.
				_p(1, 0, 5, 4, dim)
				_p(1, 8, 5, 4, dim)
				_p(0, 5, 12, 2, lit)
			&"salvo":
				# Two rounds away, with the tracers behind them. The second
				# volley, which is what the keyword pays for.
				#
				# It was two chevrons and they did not touch: six two-pixel
				# blocks on a diagonal come off the sheet as a checkerboard,
				# not as ">>". Solid shapes read at this size; implied ones do
				# not.
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
				# The drone, standing over a shield. It is a drone that guards
				# rather than shoots, so it is the drone glyph above armour --
				# and the armour is the SAME taper `brace` uses, because it is
				# the same thing being added.
				#
				# The first attempt was two flat bars, which read as neither.
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
				# Level. Nothing is happening and nothing is about to, so the
				# glyph is the absence of a shape: two rules, flat, with air
				# between them.
				#
				# It was a round blob, which at twelve pixels was the same
				# picture as `brace` -- the two sat side by side on the contact
				# sheet and could not be told apart. Thin horizontals are the
				# one thing nothing else in the kit is made of; `block` is a
				# solid mass, and mass is what this has to avoid.
				_p(1, 3, 10, 1, tint)
				_p(1, 7, 10, 1, tint)
			_:
				# An unnamed status still has to appear. A hollow box says "there
				# is something here I have no picture for", which is a bug you
				# can see rather than a status that silently vanished.
				_p(1, 1, 10, 1, tint)
				_p(1, 10, 10, 1, tint)
				_p(1, 2, 1, 8, tint)
				_p(10, 2, 1, 8, tint)


## A glyph, its magnitude, and the word it stands for.
##
## `text` is what the number was: "5", "+2", "1/2". Pass it empty for a status
## that is simply on or off, and the chip is the icon alone.
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
