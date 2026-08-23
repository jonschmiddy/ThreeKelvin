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

var _filter: GalleryFilter
var _col: VBoxContainer
var _shown: int = 0
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

	# THE SAME FILTERS THE YARD MANIFEST CARRIES, so the page a designer reads
	# and the screen a player reads sort the same way. Shared with the card
	# gallery, because a filter that drifts between two pages is one a player has
	# to learn twice.
	_filter = GalleryFilter.new()
	_filter.setup([[
		{key = &"house", label = "Manufacturer", options = GalleryFilter.house_options()},
	], [
		{key = &"grade", label = "Grade", options = GalleryFilter.grade_options()},
		{key = &"slot", label = "Slot", options = GalleryFilter.slot_options()},
		{key = &"sort", label = "Sort", options = [
			{value = &"house", text = "By house"},
			{value = &"cells", text = "By cells"}]},
	]])
	_filter.changed.connect(_on_filter)
	root.add_child(_filter)


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

	# KEPT, because every press of the filter refills this exact column. It was
	# lost once: deleting the readout panel took a slice that ran up to the
	# _fill call and swallowed the line above it, so _col stayed null, Widgets
	# .clear(null) threw on every press, and the page silently kept whatever the
	# first build had put there. The buttons lit up and nothing moved.
	_col = col
	var n := _fill(col)
	_count.text = "%d of %d modules · %d cards" % [_shown, DB.modules.size(), n]

## GROUPED BY HOUSE OR BY SIZE, and filtered, from the bar above.
##
## The whole list is rebuilt on every press rather than hiding children. It is
## seventy-seven plates and a flow container that has to reflow anyway, and the
## alternative — keeping every icon alive and toggling visibility — means the
## group headings have to know how many of their own children are still showing.
## That bookkeeping is what a rebuild is for.
func _fill(col: VBoxContainer) -> int:
	Widgets.clear(col)
	var f: Dictionary = _filter.state() if _filter != null else {}
	var house: Variant = f.get(&"house", &"")
	var grade: int = int(f.get(&"grade", -1))
	var slot: int = int(f.get(&"slot", -1))
	var by_size: bool = f.get(&"sort", &"house") == &"cells"

	var kept: Array[ModuleData] = []
	for k in DB.modules:
		var m: ModuleData = DB.modules[k]
		# `(unbranded)` rather than the empty StringName, because empty is also
		# what "All" uses and the two would be the same button.
		if house == &"(unbranded)":
			if m.manufacturer != &"":
				continue
		elif house != &"" and m.manufacturer != house:
			continue
		if grade >= 0 and int(m.rarity) != grade:
			continue
		if slot >= 0 and int(m.slot) != slot:
			continue
		kept.append(m)

	var groups: Array = []
	if by_size:
		# GROUPED AND NOT MERELY SORTED, because the question a size view answers
		# is "what fits in three cells", and that is a bucket rather than a
		# position in a list.
		for n in [1, 2, 3, 4]:
			var bucket: Array[ModuleData] = []
			for m in kept:
				if m.cells() == n:
					bucket.append(m)
			if not bucket.is_empty():
				_by_size(bucket)
				groups.append({label = "%d %s" % [n, "CELL" if n == 1 else "CELLS"],
					colour = UITheme.COLD, parts = bucket})
	else:
		for id in DB.manufacturers:
			var bucket2: Array[ModuleData] = []
			for m in kept:
				if m.manufacturer == id:
					bucket2.append(m)
			if not bucket2.is_empty():
				_by_size(bucket2)
				groups.append({label = DB.manufacturer_name(id).to_upper(),
					colour = DB.manufacturer_colour(id), parts = bucket2})
		var yard: Array[ModuleData] = []
		for m in kept:
			if m.manufacturer == &"":
				yard.append(m)
		if not yard.is_empty():
			_by_size(yard)
			groups.append({label = "UNBRANDED", colour = UITheme.COLD, parts = yard})

	var cards := 0
	for raw in groups:
		var g: Dictionary = raw
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 5)
		var swatch := ColorRect.new()
		swatch.color = g.colour
		swatch.custom_minimum_size = Vector2(4, 12)
		bar.add_child(swatch)
		bar.add_child(UITheme.body("%s — %d" % [g.label, (g.parts as Array).size()],
			UITheme.ICE, UITheme.FS_SMALL))
		col.add_child(bar)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(flow)

		for raw2 in g.parts:
			var m2: ModuleData = raw2
			cards += m2.resolved_cards().size()
			var icon := ModuleIcon.new()
			icon.setup(m2, &"gallery")
			# 2x, THE SIZE THE SHIP TAB DRAWS IT. The hold and the refit hull are
			# both authored there, which is what makes a part the same size in both;
			# a catalogue of parts should match the screen you pack them on.
			#
			# It was 1x for a version — the rectangle a part occupies on a hull at
			# native zoom, which is true and unreadable: a 1x1 sight is fifteen
			# pixels and a page of them tells you nothing.
			#
			# custom_minimum_size and NOT size: a flow container decides where its
			# children go, and asking for a size it did not choose is how the hold
			# once drew 1x1 plates at 44px.
			icon.custom_minimum_size = ModuleIcon.footprint_box(m2)
			# SHRINK, OR THE ROW STRETCHES THEM. An HFlowContainer gives a child
			# the row height by default, so a 2x1 sitting beside a 2x2 was pulled to
			# twice its own height and a page of plates showed the wrong shapes — the
			# one thing this page exists to show.
			#
			# The hold never hit this because it is not a container: it clears the
			# minimum and assigns `size` directly, with a comment about the same
			# 44px floor that bites here.
			icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			flow.add_child(icon)
	if groups.is_empty():
		col.add_child(UITheme.body("NOTHING MATCHES", UITheme.COLD, UITheme.FS_SMALL))
	_shown = kept.size()
	return cards


## BY SHAPE: 1x1, 2x1, 3x1, 4x1, then 2x2.
##
## Height first, then width. That puts every one-deep part in a clean
## progression of lengths and leaves the block on its own at the end, which is
## how somebody describes the catalogue out loud — the ones, the twos, the
## threes, the long ones, and the square.
##
## Sorting by CELLS first was the version before this, and it interleaved the
## thing the eye is following: a 4x1 and a 2x2 are both four cells, so a row of
## lengthening bars had a square dropped into the middle of it.
##
## Before either, a house block came out in DATABASE order — the order somebody
## typed the parts in — so a 2x2 bay sat between two 1x1 sights and the row read
## as noise.
func _by_size(parts: Array) -> void:
	parts.sort_custom(func(a: ModuleData, b: ModuleData) -> bool:
		var fa := a.footprint()
		var fb := b.footprint()
		if fa.y != fb.y:
			return fa.y < fb.y
		if fa.x != fb.x:
			return fa.x < fb.x
		return a.name < b.name)


func _on_filter(_state: Dictionary) -> void:
	var n := _fill(_col)
	_count.text = "%d of %d modules · %d cards" % [_shown, DB.modules.size(), n]


