class_name CardGalleryScreen
extends Control

## A dev page of every card, as half the catalog could be wrong for a week if cards only show
## in fights. A lift, not a zoom, in an overlay: moving a flow child reflows the whole catalog.
## Why: docs/why/CardGalleryScreen.md#gallery-purpose

## The lift is enough that the row visibly has a gap; a 2 or 3 px nudge reads as a rendering wobble.
const LIFT := 18.0

var _overlay: Control
var _hot: CardView = null
## Which module granted each view, as the card only carries the module's name.
var _owner: Dictionary = {}

var _col: VBoxContainer
var _filter: GalleryFilter
var _count: Label
## LEAVE is handed in by Router, as these pages open from anywhere and only the screen below knows.
var _back: Callable

var _all: int = 0

func setup(back: Callable = Callable()) -> void:
	_back = back
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var col_root := VBoxContainer.new()
	col_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col_root.add_theme_constant_override("separation", 4)
	add_child(col_root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UITheme.header("CARD GALLERY"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_count = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	# A HUD tab does not untoggle, so without LEAVE there was no way off the page.
	head.add_child(Widgets.button("LEAVE", func() -> void:
		if _back.is_valid():
			_back.call()
		else:
			Router.show_sector()))
	col_root.add_child(head)

	# Grade filters the card and slot filters the part: what does a Korvan utility put in my deck.
	_filter = GalleryFilter.new()
	_filter.setup([[
		{key = &"manufacturer", label = "Manufacturer", options = GalleryFilter.manufacturer_options()},
		# Collapsed by default: duplicates answered what the deck gets, but were noise when asking
		# what art still needs drawing. `All copies` puts the old view back.
		# Why: docs/why/CardGalleryScreen.md#copies-collapsed
		{key = &"dupes", label = "Copies", options = [
			{value = &"one", text = "Collapse"},
			{value = &"all", text = "All copies"}]},
	], [
		{key = &"grade", label = "Grade", options = GalleryFilter.grade_options()},
		{key = &"slot", label = "Slot", options = GalleryFilter.slot_options()},
		{key = &"sort", label = "Sort", options = [
			{value = &"manufacturer", text = "By manufacturer"},
			{value = &"grade", text = "By grade"}]},
	]])
	_filter.changed.connect(_on_filter)
	col_root.add_child(_filter)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_root.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	_col = col
	var total := _fill(col)
	_all = total
	_count.text = "%d of %d cards" % [total, _all]

	# Above everything and deaf to the mouse, or hovering the pop would count as leaving the card.
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

## Unbranded last, as they have no banner to compare. Rebuilt on every press, as headings carry
## counts and tracking visible children is bookkeeping a rebuild does for free.
## Why: docs/why/CardGalleryScreen.md#rebuild-on-press
func _fill(col: VBoxContainer) -> int:
	Widgets.clear(col)
	var f: Dictionary = _filter.state() if _filter != null else {}
	var manufacturer: Variant = f.get(&"manufacturer", &"")
	var grade: int = int(f.get(&"grade", -1))
	var slot: int = int(f.get(&"slot", -1))
	var by_grade: bool = f.get(&"sort", &"manufacturer") == &"grade"
	var collapse: bool = f.get(&"dupes", &"one") != &"all"

	# Every card is carried with its granting module,
	# as filters ask about the part as often as the card.
	var kept: Array = []
	for k in DB.modules:
		var m: ModuleData = DB.modules[k]
		if slot >= 0 and int(m.slot) != slot:
			continue
		# `resolved_cards()`, not `cards`: the Grant
		# Count Law decides what a module puts in a deck.
		for c in m.resolved_cards():
			var cd: CardData = c
			# Filed by the card's own manufacturer, not its part's (Jon, Oct 18):
			# a shared card a Korvan part grants is drawn unbranded, so it files under UNBRANDED.
			# Why: docs/why/CardGalleryScreen.md#card-manufacturer
			if manufacturer == &"(unbranded)":
				if cd.manufacturer != &"":
					continue
			elif manufacturer != &"" and cd.manufacturer != manufacturer:
				continue
			if grade >= 0 and cd.rarity != grade:
				continue
			kept.append({card = cd, part = m})

	# One row per illustration by `art_key()`,
	# so the gallery and the coverage gate agree on the count.
	if collapse:
		var seen := {}
		var thinned: Array = []
		for row4 in kept:
			var key4 := ((row4 as Dictionary).card as CardData).art_key()
			if seen.has(key4):
				continue
			seen[key4] = true
			thinned.append(row4)
		kept = thinned

	# Malfunctions are shown because no module grants them: 16 of 76 illustrations were
	# never on this page. Only with no manufacturer or slot filter, as they have neither.
	# Why: docs/why/CardGalleryScreen.md#malfunctions
	var faults: Array = []
	if manufacturer == &"" and slot < 0:
		for row3 in DB.MALFUNCTIONS:
			var mc := DB.malfunction(row3[0])
			if grade >= 0 and mc.rarity != grade:
				continue
			faults.append({card = mc, part = null})

	var groups: Array = []
	if by_grade:
		for r in ModuleData.Rarity.size():
			var bucket: Array = []
			for row in kept:
				if (row as Dictionary).card.rarity == r:
					bucket.append(row)
			if not bucket.is_empty():
				groups.append({label = ModuleData.rarity_name(r).to_upper(),
					colour = ModuleData.rarity_ink(r), rows = bucket})
	else:
		for id in DB.manufacturers:
			var bucket2: Array = []
			for row in kept:
				if ((row as Dictionary).card as CardData).manufacturer == id:
					bucket2.append(row)
			if not bucket2.is_empty():
				groups.append({label = DB.manufacturer_name(id).to_upper(),
					colour = DB.manufacturer_colour(id), rows = bucket2})
		var yard: Array = []
		for row in kept:
			if ((row as Dictionary).card as CardData).manufacturer == &"":
				yard.append(row)
		if not yard.is_empty():
			groups.append({label = "UNBRANDED", colour = UITheme.COLD, rows = yard})
	# Last in both sorts. A malfunction is not a thing you chose, so it belongs
	# after everything that was.
	if not faults.is_empty():
		groups.append({label = "MALFUNCTIONS", colour = UITheme.BAD,
			rows = faults})

	var total := 0
	for raw in groups:
		var g: Dictionary = raw
		# A rule between groups, and not before the first. Same reason as the
		# module gallery: a heading in a colour is a comparison, a line is a wall.
		if col.get_child_count() > 0:
			col.add_child(UITheme.hsep())
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 5)
		var swatch := ColorRect.new()
		swatch.color = g.colour
		swatch.custom_minimum_size = Vector2(4, 12)
		bar.add_child(swatch)
		bar.add_child(UITheme.body("%s — %d" % [g.label, (g.rows as Array).size()],
			UITheme.ICE, UITheme.FS_SMALL))
		col.add_child(bar)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(flow)

		for row2 in g.rows:
			var v := CardView.new()
			v.setup((row2 as Dictionary).card, true, 1)
			v.mouse_filter = Control.MOUSE_FILTER_PASS
			v.hovered.connect(_on_hover)
			flow.add_child(v)
			total += 1
	if groups.is_empty():
		col.add_child(UITheme.body("NOTHING MATCHES", UITheme.COLD, UITheme.FS_SMALL))
	return total


func _on_filter(_state: Dictionary) -> void:
	var n := _fill(_col)
	_count.text = "%d of %d cards" % [n, _all]


func _on_hover(v: CardView, entered: bool) -> void:
	if not entered:
		# Only the card owning the pop may dismiss it:
		# exited fires after entered between adjacent cards.
		if _hot == v:
			_clear()
		return
	if _hot != null and _hot != v:
		_hot.modulate.a = 1.0
	# The hand's card-hover sound, here too (Jon asked). Only on a NEW card:
	# the lifted copy can re-send `entered` for the card already out.
	if _hot != v:
		Audio.play(&"card_hover", 0.08, 45)
	_hot = v
	Widgets.clear(_overlay)
	# The grid card goes invisible by alpha, not `visible`,
	# which would close the gap the lift opened.
	v.modulate.a = 0.0

	# Only two card scales exist, frozen apart, and between them softens the 8px font. Doubling
	# swallowed a third of the screen, so the card rises instead, at no cost in resolution.
	# Why: docs/why/CardGalleryScreen.md#lift-not-zoom
	var rest := v.global_position - global_position
	# Never above the top edge: a card on the first visible row still has to
	# have somewhere to rise to.
	var pos := Vector2(rest.x, maxf(2.0, rest.y - LIFT))

	# Frame and card ride in one wrapper so one tween moves both and dies with them.
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.position = rest
	_overlay.add_child(wrap)

	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0, 0, 0, 0), UITheme.FLARE, 0, 0, 0))
	frame.position = Vector2(-2, -2)
	frame.size = Vector2(CardView.CARD_W + 4, CardView.CARD_H + 4)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(frame)

	var pop := CardView.new()
	pop.setup(v.card, true, 1)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(pop)

	# Rises from the card's own spot, as a card blinking
	# into a higher place reads as a second card.
	var tw := wrap.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(wrap, "position", pos, 0.14)

	# The readout opens right, or left if no room:
	# a panel off the edge loses the part you hovered for.
	var info := Widgets.card_readout(v.card)
	_overlay.add_child(info)
	var iw := info.custom_minimum_size.x
	var ix := pos.x + CardView.CARD_W + 6
	if ix + iw > size.x - 2.0:
		ix = pos.x - iw - 6.0
	info.position = Vector2(maxf(2.0, ix), pos.y)
	# Fades rather than slides. Two things travelling on different vectors reads
	# as two events; the card moves, the readout simply arrives with it.
	info.modulate.a = 0.0
	var it := info.create_tween()
	it.tween_property(info, "modulate:a", 1.0, 0.12)

	# The panel's height is only known after layout, so it is clamped a frame later;
	# a flat 200px guess ran off the bottom for wordier cards.
	# Why: docs/why/CardGalleryScreen.md#readout-clamp
	await get_tree().process_frame
	if is_instance_valid(info):
		info.position.y = clampf(pos.y, 2.0,
			maxf(2.0, size.y - info.size.y - 2.0))

func _clear() -> void:
	if _hot != null:
		_hot.modulate.a = 1.0
	_hot = null
	Widgets.clear(_overlay)

