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
	# The ghost carries the part's SHAPE, not a square. What you are dragging
	# has to look like what will land: the hold is a grid you pack, and a 1x3
	# gun previewed as a 1x1 tile tells you nothing about whether it will fit
	# in the row you are aiming at.
	var g := Vector2(maxi(1, module.size.x), maxi(1, module.size.y))
	ghost.custom_minimum_size = g * float(HoldGrid.CELL)
	ghost.size = g * float(HoldGrid.CELL)
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

	# The SAME silhouette the hull draws at this part's mount, scaled to the
	# plate. It replaced a glyph derived from the card — richer, but it meant a
	# gun in your hold and the same gun on your ship were two different pictures,
	# and the hold is where you decide which one to bolt on.
	draw_part(self, module.slot, size * 0.5,
		mark, minf(size.x, size.y) / 26.0)

	# Rarity on the border, because the border is the part that survives being
	# packed shoulder to shoulder in a grid.
	var edge := ModuleData.rarity_colour(module.rarity)
	for side in [Rect2(0, 0, size.x, 1), Rect2(0, size.y - 1, size.x, 1),
			Rect2(0, 0, 1, size.y), Rect2(size.x - 1, 0, 1, size.y)]:
		draw_rect(side, edge, true)

## THE SILHOUETTE A PART READS AS, drawn the same way wherever it appears.
##
## One function, called by the hold and by the hull, because the alternative is
## two drawings of a gun that drift apart — and the whole value of a part having
## a shape is that you recognise the thing you just dragged when it lands.
##
## SLOT decides the form: a weapon is a housing with a barrel out of the front, a
## system is a plate, a utility is a mast. `s` scales it — the hull draws these
## at 1 against a hull 30 to 50 rows deep, the hold at rather more in a cell it
## has to fill.
static func draw_part(ci: CanvasItem, slot: ModuleData.Slot, at: Vector2,
		col: Color, s: float = 1.0) -> void:
	var dark := col.lerp(Color("#0a0e13"), 0.55)
	var lite := col.lerp(Color.WHITE, 0.3)
	match slot:
		ModuleData.Slot.WEAPON:
			ci.draw_rect(Rect2(at.x - 4.0 * s, at.y - 2.5 * s, 9.0 * s, 5.0 * s), dark, true)
			ci.draw_rect(Rect2(at.x - 4.0 * s, at.y - 2.5 * s, 9.0 * s, 1.0 * s), lite, true)
			ci.draw_rect(Rect2(at.x + 5.0 * s, at.y - 1.0 * s, 7.0 * s, 2.0 * s), col, true)
			ci.draw_rect(Rect2(at.x + 12.0 * s, at.y - 1.0 * s, 2.0 * s, 2.0 * s),
				UITheme.VOID, true)
		ModuleData.Slot.SYSTEM:
			ci.draw_rect(Rect2(at.x - 5.5 * s, at.y - 2.0 * s, 11.0 * s, 4.0 * s), dark, true)
			ci.draw_rect(Rect2(at.x - 5.5 * s, at.y - 2.0 * s, 11.0 * s, 1.0 * s), col, true)
			ci.draw_rect(Rect2(at.x - 3.5 * s, at.y, 3.0 * s, 1.0 * s), lite, true)
		_:
			ci.draw_rect(Rect2(at.x - 1.5 * s, at.y - 3.5 * s, 3.0 * s, 7.0 * s), dark, true)
			ci.draw_rect(Rect2(at.x - 0.5 * s, at.y - 6.5 * s, 1.0 * s, 4.0 * s), col, true)
			ci.draw_rect(Rect2(at.x - 0.5 * s, at.y - 7.5 * s, 1.0 * s, 1.0 * s), lite, true)

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
