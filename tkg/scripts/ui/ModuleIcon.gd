class_name ModuleIcon
extends Control

## A module as a thing you can pick up.
##
## Inventory-grid icon, in the vein of Arc Raiders or Marathon: a plate in the
## manufacturer's field colour, a rarity edge, and a glyph saying what the part
## DOES. Three channels, three questions — whose is it, how good is it, what is
## it for — and none of them requires reading a word.
##
## The glyph comes from the module's own first card via CardData.glyph_kind(),
## which is the same classification the card face draws its art from. So a
## weapon that fires and a weapon that charges look different here for exactly
## the reason they look different in your hand, and neither is a second opinion
## about what the module is.

const SIZE := 44

var module: ModuleData
## Where a drag from here would be taking it FROM. The drop target needs to know
## whether this is a refit or an install.
var origin: StringName = &"cargo"

signal picked_up(icon: ModuleIcon)

func setup(m: ModuleData, from: StringName) -> void:
	module = m
	origin = from
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = _hint()
	queue_redraw()

func _hint() -> String:
	if module == null:
		return ""
	var lines := "%s\n%s · %s" % [module.name.to_upper(),
		ModuleData.rarity_name(module.rarity).to_upper(),
		ModuleData.slot_name(module.slot).to_upper()]
	if module.manufacturer != &"":
		lines += "\n%s" % DB.manufacturer_name(module.manufacturer)
	for c in module.resolved_cards():
		lines += "\n· %s" % c.describe()
	if not module.affixes.is_empty():
		for a in module.affixes:
			lines += "\n+ %s (%s)" % [a.name, a.text]
	return lines

## Picking one up. The preview is a copy of the icon rather than the icon
## itself: Godot reparents whatever you return, so handing over the live control
## would tear it out of the grid it is sitting in and leave a hole that only
## closes on the next refresh.
func _get_drag_data(_at: Vector2) -> Variant:
	if module == null:
		return null
	var ghost := ModuleIcon.new()
	ghost.setup(module, origin)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.custom_minimum_size = Vector2(SIZE, SIZE)
	ghost.size = Vector2(SIZE, SIZE)
	set_drag_preview(ghost)
	picked_up.emit(self)
	return {module = module, origin = origin}

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	if module == null:
		return
	var maker: ManufacturerData = DB.manufacturers.get(module.manufacturer)
	var field: Color = maker.field if maker != null else Color("#141c26")
	var mark: Color = maker.colour if maker != null else UITheme.COLD
	draw_rect(r, field, true)

	# A house stripe down the left edge, the same side the cards fly their
	# banner on. At this size an emblem would be four unreadable pixels; a bar
	# of the right colour in the right place says the same thing.
	if maker != null:
		draw_rect(Rect2(0, 0, 3, SIZE), mark, true)

	_glyph(mark)

	# Rarity on the border, because the border is the part that survives being
	# packed shoulder to shoulder in a grid.
	var edge := ModuleData.rarity_colour(module.rarity)
	for side in [Rect2(0, 0, SIZE, 1), Rect2(0, SIZE - 1, SIZE, 1),
			Rect2(0, 0, 1, SIZE), Rect2(SIZE - 1, 0, 1, SIZE)]:
		draw_rect(side, edge, true)

## What the part does, in rectangles.
##
## Drawn from the module's first card rather than authored per module: forty-six
## modules would be forty-six drawings to keep in step with their own effects,
## and the six verbs below already cover every one of them.
func _glyph(mark: Color) -> void:
	var kind := &"utility"
	if not module.cards.is_empty():
		kind = (module.cards[0] as CardData).glyph_kind()
	var c := Vector2(SIZE * 0.5 + 1.0, SIZE * 0.5)
	var ink := mark.lightened(0.25)
	var dim := mark.darkened(0.35)
	match kind:
		&"slug":
			# A barrel and its muzzle flash. One shot.
			draw_rect(Rect2(c + Vector2(-11, -2), Vector2(15, 5)), ink, true)
			draw_rect(Rect2(c + Vector2(4, -5), Vector2(3, 11)), dim, true)
			draw_rect(Rect2(c + Vector2(7, -2), Vector2(4, 5)), ink, true)
		&"burst":
			# THREE muzzles. At 44px there is no room to count the way the card
			# face does, so this says "more than one" and stops — which is the
			# question the grid is being asked.
			for i in 3:
				draw_rect(Rect2(c + Vector2(-11, -8 + i * 6), Vector2(13, 3)), ink, true)
				draw_rect(Rect2(c + Vector2(4, -8 + i * 6), Vector2(4, 3)), dim, true)
		&"pyre":
			# A barrel fed from the reactor. The one weapon lit from inside.
			draw_rect(Rect2(c + Vector2(-11, -2), Vector2(15, 5)), ink, true)
			draw_rect(Rect2(c + Vector2(-7, -1), Vector2(8, 3)), UITheme.FLARE, true)
			draw_rect(Rect2(c + Vector2(4, -4), Vector2(5, 9)), UITheme.HOT, true)
		&"charge":
			# A capacitor filling: three bars, the last one lit.
			for i in 3:
				var h := 4 + i * 4
				draw_rect(Rect2(c + Vector2(-9 + i * 7, 6 - h), Vector2(5, h)),
					ink if i == 2 else dim, true)
		&"drone":
			# A carrier and the thing it launched.
			draw_rect(Rect2(c + Vector2(-11, -1), Vector2(10, 7)), dim, true)
			draw_rect(Rect2(c + Vector2(2, -8), Vector2(6, 6)), ink, true)
			draw_rect(Rect2(c + Vector2(4, -2), Vector2(2, 3)), ink, true)
		&"armor":
			# A plate with a bevel. Whole, because Brace is a wall you keep.
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 15)), dim, true)
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 3)), ink, true)
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(3, 15)), ink, true)
		&"block":
			# The same footprint, SEGMENTED. Gaps say it falls down at the end of
			# the turn, which is the one distinction that decides a defensive turn.
			for i in 3:
				draw_rect(Rect2(c + Vector2(-8, -9 + i * 6), Vector2(16, 4)),
					ink if i == 1 else dim, true)
		&"riposte":
			# A wall, and a round leaving it.
			draw_rect(Rect2(c + Vector2(-10, -9), Vector2(6, 17)), ink, true)
			draw_rect(Rect2(c + Vector2(0, -2), Vector2(7, 4)), dim, true)
			draw_rect(Rect2(c + Vector2(7, -1), Vector2(4, 2)), UITheme.HOT, true)
		&"slip":
			# The gap the shot goes through.
			draw_rect(Rect2(c + Vector2(-9, -10), Vector2(5, 7)), dim, true)
			draw_rect(Rect2(c + Vector2(-9, 3), Vector2(5, 7)), dim, true)
			draw_rect(Rect2(c + Vector2(-1, -2), Vector2(11, 3)), ink, true)
		&"vent":
			# Heat leaving through slats.
			draw_rect(Rect2(c + Vector2(-10, 2), Vector2(20, 5)), dim, true)
			for i in 3:
				draw_rect(Rect2(c + Vector2(-8 + i * 7, -9), Vector2(4, 10)), ink, true)
		&"repair":
			# A seam and the weld across it.
			draw_rect(Rect2(c + Vector2(-9, -7), Vector2(19, 13)), dim, true)
			draw_rect(Rect2(c + Vector2(-2, -10), Vector2(5, 19)), ink, true)
			draw_rect(Rect2(c + Vector2(-9, -2), Vector2(19, 4)), ink, true)
		&"lock":
			# A reticle, and the only glyph in the set with a hole in the middle.
			#
			# The four corners are written out rather than derived from a loop.
			# The clever version put every vertical arm at the corner's top edge,
			# so the two lower brackets pointed the wrong way and the whole thing
			# read as four unrelated ticks — which at 44px is indistinguishable
			# from damage. An L has a handedness and there are four of them.
			var arm := Vector2(6, 2)
			var leg := Vector2(2, 6)
			draw_rect(Rect2(c + Vector2(-11, -11), arm), ink, true)   ## top left
			draw_rect(Rect2(c + Vector2(-11, -11), leg), ink, true)
			draw_rect(Rect2(c + Vector2(5, -11), arm), ink, true)     ## top right
			draw_rect(Rect2(c + Vector2(9, -11), leg), ink, true)
			draw_rect(Rect2(c + Vector2(-11, 9), arm), ink, true)     ## bottom left
			draw_rect(Rect2(c + Vector2(-11, 5), leg), ink, true)
			draw_rect(Rect2(c + Vector2(5, 9), arm), ink, true)       ## bottom right
			draw_rect(Rect2(c + Vector2(9, 5), leg), ink, true)
			draw_rect(Rect2(c + Vector2(-1, -1), Vector2(3, 3)), UITheme.HOT, true)
		&"draw":
			# Cards, one lifted.
			draw_rect(Rect2(c + Vector2(-10, -3), Vector2(9, 12)), dim, true)
			draw_rect(Rect2(c + Vector2(-5, -6), Vector2(9, 12)), dim, true)
			draw_rect(Rect2(c + Vector2(0, -10), Vector2(9, 13)), ink, true)
		&"power":
			# A cell with a charge in it.
			draw_rect(Rect2(c + Vector2(-7, -9), Vector2(14, 18)), dim, true)
			draw_rect(Rect2(c + Vector2(-2, -6), Vector2(4, 6)), UITheme.FLARE, true)
			draw_rect(Rect2(c + Vector2(-2, 1), Vector2(4, 6)), UITheme.HOT, true)
		&"scrip":
			# Stacked notes.
			for i in 3:
				draw_rect(Rect2(c + Vector2(-9 + i * 2, -7 + i * 5), Vector2(16, 4)),
					ink if i == 2 else dim, true)
		&"malfunction":
			# A crack. Nothing else in the set is diagonal.
			for i in 5:
				draw_rect(Rect2(c + Vector2(-8 + i * 4, -8 + i * 3), Vector2(4, 3)),
					ink, true)
		_:
			# A housing with a fitting on it: an unclassified part.
			draw_rect(Rect2(c + Vector2(-9, -6), Vector2(17, 12)), dim, true)
			draw_rect(Rect2(c + Vector2(-5, -3), Vector2(9, 6)), ink, true)
			draw_rect(Rect2(c + Vector2(8, -2), Vector2(4, 4)), dim, true)
