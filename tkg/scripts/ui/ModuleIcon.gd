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

## Drawn to the control's OWN size, not to SIZE.
##
## A 1x1 fitting and a 1x3 gun are the same icon at different footprints once
## the hold is a grid, so the plate, the house stripe and the rarity border all
## measure themselves off `size`. Every existing use is a 44x44 cell and is
## unchanged by this; the glyph was already centre-relative.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
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
		draw_rect(Rect2(0, 0, 3, size.y), mark, true)

	_glyph(mark)

	# Rarity on the border, because the border is the part that survives being
	# packed shoulder to shoulder in a grid.
	var edge := ModuleData.rarity_colour(module.rarity)
	for side in [Rect2(0, 0, size.x, 1), Rect2(0, size.y - 1, size.x, 1),
			Rect2(0, 0, 1, size.y), Rect2(size.x - 1, 0, 1, size.y)]:
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
	var c := Vector2(size.x * 0.5 + 1.0, size.y * 0.5)
	var ink := mark.lightened(0.25)
	var dim := mark.darkened(0.35)
	match kind:
		&"attack":
			# A barrel and its muzzle flash.
			draw_rect(Rect2(c + Vector2(-11, -2), Vector2(15, 5)), ink, true)
			draw_rect(Rect2(c + Vector2(4, -5), Vector2(3, 11)), dim, true)
			draw_rect(Rect2(c + Vector2(7, -2), Vector2(4, 5)), ink, true)
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
		&"defend":
			# A plate with a bevel, which is how armour reads everywhere else in
			# this game.
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 15)), dim, true)
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(16, 3)), ink, true)
			draw_rect(Rect2(c + Vector2(-8, -9), Vector2(3, 15)), ink, true)
		&"malfunction":
			# A crack. Nothing else in the set is diagonal.
			for i in 5:
				draw_rect(Rect2(c + Vector2(-8 + i * 4, -8 + i * 3), Vector2(4, 3)),
					ink, true)
		_:
			# Utility: a vent throwing heat off in slats.
			draw_rect(Rect2(c + Vector2(-10, 2), Vector2(20, 5)), dim, true)
			for i in 3:
				draw_rect(Rect2(c + Vector2(-8 + i * 7, -9), Vector2(4, 10)), ink, true)
