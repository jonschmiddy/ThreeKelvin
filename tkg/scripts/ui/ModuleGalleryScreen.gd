class_name ModuleGalleryScreen
extends Control

## Every module in the game, on one page.
##
## A development screen, reached with the MODULES tab or `godot --path . -- parts`.
## The sibling of CardGalleryScreen and written for the same complaint one level
## up: the only way to see a module used to be to find one, which means a wreck
## rolling it, which means most of the catalogue is never looked at. A part can
## be wrong — wrong shape, wrong slot, wrong house, a silhouette that reads as
## something else — for as long as nobody happens to be handed it.
##
## SHOWS THE PLATE, not a list row. A module's shape is a fact about it now: a
## 1x3 lance packs differently from a 2x2 bay and reads differently on the hull.
## A table of names would hide the one property this page exists to check, so
## every part is drawn at the size it occupies in the hold, in a flow that lets
## the shapes sit against each other.
##
## Grouped by manufacturer, houses first and the unbranded last — the same order
## and the same reason as the card gallery: a house's mark only works if it does
## not look like the other six, and that is a comparison you can only make with
## them side by side.

## How much room a readout needs beside the grid. Fixed, because it is a column
## of labels and a column of labels that resizes with its contents makes the
## whole page reflow every time the cursor moves.
const READOUT_W := 240

var _readout: VBoxContainer
var _count: Label

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var head := HBoxContainer.new()
	head.add_child(UITheme.header("MODULE GALLERY"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_count = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	head.add_child(_count)
	root.add_child(head)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	# The readout is a SIBLING of the scroller, not an overlay over the grid.
	# The card gallery lifts a card because a card is a picture you want bigger;
	# a module is a plate whose whole content is its shape and colour, and there
	# is nothing to enlarge. What is missing is the words.
	var side := Widgets.panel_with(_make_readout())
	side.custom_minimum_size = Vector2(READOUT_W, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(side)

	var n := _fill(col)
	_count.text = "%d modules · %d cards" % [DB.modules.size(), n]
	_show(null)

func _make_readout() -> Control:
	_readout = VBoxContainer.new()
	_readout.add_theme_constant_override("separation", 3)
	return _readout

## One block per manufacturer, unbranded last.
func _fill(col: VBoxContainer) -> int:
	var by_maker: Dictionary = {}
	for k in DB.modules:
		var m: ModuleData = DB.modules[k]
		var key := String(m.manufacturer)
		if not by_maker.has(key):
			by_maker[key] = []
		by_maker[key].append(m)

	var order: Array = []
	for id in DB.manufacturers:
		if by_maker.has(String(id)):
			order.append(String(id))
	if by_maker.has(""):
		order.append("")

	var cards := 0
	for key in order:
		var label := DB.manufacturer_name(StringName(key)) if key != "" else "Unbranded"
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 5)
		var swatch := ColorRect.new()
		swatch.color = DB.manufacturer_colour(StringName(key))
		swatch.custom_minimum_size = Vector2(4, 12)
		bar.add_child(swatch)
		bar.add_child(UITheme.body("%s — %d" % [label.to_upper(),
			(by_maker[key] as Array).size()], UITheme.ICE, UITheme.FS_SMALL))
		col.add_child(bar)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(flow)

		for raw in by_maker[key]:
			var m: ModuleData = raw
			cards += m.resolved_cards().size()
			var icon := ModuleIcon.new()
			icon.setup(m, &"gallery")
			# The plate at its own footprint, which is the point of the page.
			# custom_minimum_size and NOT size: a flow container decides where
			# its children go and asking for a size it did not choose is how the
			# hold ended up drawing 1x1 plates at 44px.
			icon.custom_minimum_size = ModuleIcon.footprint_box(m)
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			icon.mouse_entered.connect(_show.bind(m))
			flow.add_child(icon)
	return cards

## What the part IS, in the panel beside the grid.
func _show(m: ModuleData) -> void:
	Widgets.clear(_readout)
	if m == null:
		_readout.add_child(UITheme.body("POINT AT A PART", UITheme.COLD,
			UITheme.FS_SMALL))
		return
	var maker := DB.manufacturer_name(m.manufacturer) if m.manufacturer != &"" \
		else "Unbranded"
	_readout.add_child(UITheme.body(m.name.to_upper(), UITheme.ICE, UITheme.FS_SMALL))
	_readout.add_child(UITheme.body(maker,
		DB.manufacturer_colour(m.manufacturer), UITheme.FS_SMALL))
	var f := m.footprint()
	_readout.add_child(UITheme.body("%s · %s · %dx%d · %d cells"
		% [ModuleData.rarity_name(m.rarity).to_upper(),
			ModuleData.slot_name(m.slot).to_upper(), f.x, f.y, m.cells()],
		ModuleData.rarity_colour(m.rarity), UITheme.FS_SMALL))
	if m.flavour != "":
		_readout.add_child(_wrapped(m.flavour, UITheme.CHILL))

	# The cards it GRANTS, which is what a module actually is. resolved_cards()
	# and not `cards`: the Grant Count Law decides how many of them reach a deck,
	# and a part authored with two verbs that grants one has only ever shown one.
	var got := m.resolved_cards()
	_readout.add_child(UITheme.body("GRANTS %d" % got.size(), UITheme.COLD,
		UITheme.FS_SMALL))
	for c in got:
		var cd: CardData = c
		_readout.add_child(_wrapped("· %s — %s" % [cd.name, cd.describe()], UITheme.CHILL))


## A label that wraps. The readout is a fixed-width column and a card's own text
## is written to be read, not to fit — so the alternative is either a panel that
## resizes with the cursor or a sentence running off the edge of the screen.
func _wrapped(text: String, colour: Color) -> Label:
	var l := UITheme.body(text, colour, UITheme.FS_SMALL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(READOUT_W - 28, 0)
	return l
