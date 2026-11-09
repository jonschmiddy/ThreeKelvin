class_name ModuleGalleryScreen
extends Control

## A dev page of every part, as a part could be wrong for ages if nobody is handed it.
## Shows each plate at its hold size and groups by manufacturer so marks can be compared.
## Why: docs/why/ModuleGalleryScreen.md#gallery-purpose

## Fixed readout width: a label column sized by its
## contents makes the page reflow on every cursor move.

## Plates draw at the same 2x as the hold and refit hull: this page asked for a 3x box and
## got a 2x sprite. Closed downward, as 3x was bigger than the screen where parts are handled.
## Why: docs/why/ModuleGalleryScreen.md#plate-scale
const GALLERY_K := ModuleIcon.HOLD_K

var _filter: GalleryFilter
var _col: VBoxContainer
var _shown: int = 0
var _count: Label
## LEAVE is handed in by Router, as these pages open from anywhere and only the screen below knows.
var _back: Callable


func setup(back: Callable = Callable()) -> void:
	_back = back
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UITheme.header("MODULE GALLERY"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_count = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	# A HUD tab does not untoggle, so without LEAVE
	# the only way off was picking another destination.
	head.add_child(Widgets.button("LEAVE", func() -> void:
		if _back.is_valid():
			_back.call()
		else:
			Router.show_sector()))
	root.add_child(head)

	# The same filters as the yard manifest and card gallery, so a filter is learned once.
	_filter = GalleryFilter.new()
	_filter.setup([[
		{key = &"manufacturer", label = "Manufacturer", options = GalleryFilter.manufacturer_options()},
	], [
		{key = &"grade", label = "Grade", options = GalleryFilter.grade_options()},
		{key = &"slot", label = "Slot", options = GalleryFilter.slot_options()},
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

	# `_col` is kept: it was lost once when a slice swallowed the line, and `Widgets.clear(null)`
	# threw on every press while the page silently showed the first build.
	# Why: docs/why/ModuleGalleryScreen.md#column-reference
	_col = col
	var n := _fill(col)
	_count.text = "%d of %d modules · %d cards" % [_shown, DB.modules.size(), n]

## The list is rebuilt on every press, not hidden: headings would need to track how many
## of their children still show, and a rebuild does that for free.
## Why: docs/why/ModuleGalleryScreen.md#rebuild-on-press
func _fill(col: VBoxContainer) -> int:
	Widgets.clear(col)
	var f: Dictionary = _filter.state() if _filter != null else {}
	var manufacturer: Variant = f.get(&"manufacturer", &"")
	var grade: int = int(f.get(&"grade", -1))
	var slot: int = int(f.get(&"slot", -1))

	var kept: Array[ModuleData] = []
	for k in DB.modules:
		var m: ModuleData = DB.modules[k]
		# `(unbranded)` rather than the empty StringName, because empty is also
		# what "All" uses and the two would be the same button.
		if manufacturer == &"(unbranded)":
			if m.manufacturer != &"":
				continue
		elif manufacturer != &"" and m.manufacturer != manufacturer:
			continue
		if grade >= 0 and int(m.rarity) != grade:
			continue
		if slot >= 0 and int(m.slot) != slot:
			continue
		kept.append(m)

	var groups: Array = []
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
		# A rule between manufacturers, as quieter subheadings alone read as one long list.
		if col.get_child_count() > 0:
			col.add_child(UITheme.hsep())
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 5)
		var swatch := ColorRect.new()
		swatch.color = g.colour
		swatch.custom_minimum_size = Vector2(4, 12)
		bar.add_child(swatch)
		# The manufacturer name uses its own colour:
		# it owns one everywhere else, and was a 4px tick here.
		bar.add_child(UITheme.body("%s — %d" % [g.label, (g.parts as Array).size()],
			g.colour, UITheme.FS_SMALL))
		col.add_child(bar)

		# One row per shape, walking the sorted parts, so subsections cannot disagree with the
		# sort. A single flow ran a 1x1 and a 2x2 together and the eye had to find the size change.
		# Why: docs/why/ModuleGalleryScreen.md#shape-rows
		var flow: HFlowContainer = null
		var shape := Vector2i(-1, -1)
		for raw2 in g.parts:
			var m2: ModuleData = raw2
			cards += m2.resolved_cards().size()
			if m2.footprint() != shape:
				shape = m2.footprint()
				col.add_child(_shape_head(shape, g.parts))
				flow = HFlowContainer.new()
				flow.add_theme_constant_override("h_separation", 4)
				flow.add_theme_constant_override("v_separation", 4)
				flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				col.add_child(flow)
			var icon := ModuleIcon.new()
			icon.setup(m2, &"gallery")
			# Box and body get the same 2x so they cannot drift; 3x blew sprites past their size.
			# `custom_minimum_size`, not size: a flow decides placement (a size drew 1x1 at 44px).
			# Why: docs/why/ModuleGalleryScreen.md#plate-scale
			icon.custom_minimum_size = ModuleIcon.footprint_box(m2, GALLERY_K)
			# THE SAME k THE BOX WAS SIZED WITH, always. Passing one and not the
			# other is the defect above.
			icon.plate_scale = GALLERY_K
			# Shrink, or the flow stretches a 2x1 beside a 2x2
			# to the row height and shows the wrong shapes.
			icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_PASS
			# Parts rise on hover as the hold's rows slide. Set by `position`: the flow
			# rewrites its own on sort. Two pixels is the smallest move at 2x.
			# Why: docs/why/ModuleGalleryScreen.md#hover-lift
			icon.mouse_entered.connect(func() -> void:
				Audio.hover()
				_raise(icon, true))
			icon.mouse_exited.connect(_raise.bind(icon, false))
			flow.add_child(icon)
	if groups.is_empty():
		col.add_child(UITheme.body("NOTHING MATCHES", UITheme.COLD, UITheme.FS_SMALL))
	_shown = kept.size()
	return cards


## Shape label is dimmer and indented, a subdivision, or a five-shape manufacturer reads as five.
func _shape_head(shape: Vector2i, parts: Array) -> Control:
	var n := 0
	for raw in parts:
		if (raw as ModuleData).footprint() == shape:
			n += 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(9, 0)
	row.add_child(pad)
	row.add_child(UITheme.body("%dx%d · %d" % [shape.x, shape.y, n],
		UITheme.COLD, UITheme.FS_SMALL))
	return row


## Height first, then width, so one-deep parts form a progression; by cells a
## 2x2 sat in the middle of the bars. Database order before that read as noise.
## Why: docs/why/ModuleGalleryScreen.md#shape-sort
func _by_size(parts: Array) -> void:
	parts.sort_custom(func(a: ModuleData, b: ModuleData) -> bool:
		var fa := a.footprint()
		var fb := b.footprint()
		if fa.y != fb.y:
			return fa.y < fb.y
		if fa.x != fb.x:
			return fa.x < fb.x
		# Then by grade, so a row climbs and the ladder is seen; alphabetical ordered
		# identical plates by a word written nowhere on them.
		# Why: docs/why/ModuleGalleryScreen.md#shape-sort
		if a.rarity != b.rarity:
			return int(a.rarity) < int(b.rarity)
		return a.name < b.name)


func _on_filter(_state: Dictionary) -> void:
	var n := _fill(_col)
	_count.text = "%d of %d modules · %d cards" % [_shown, DB.modules.size(), n]


## Short at 0.09 s, since a hover is not an event;
## killed on re-entry so a fast sweep cannot stack tweens.
## Why: docs/why/ModuleGalleryScreen.md#hover-lift
const LIFT_PX := 2.0
const LIFT_S := 0.09

func _raise(icon: Control, up: bool) -> void:
	if not is_instance_valid(icon):
		return
	# has_meta first: Godot reads a null default as no default and complains.
	var running: Variant = icon.get_meta(&"lift") if icon.has_meta(&"lift") else null
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	if not Router.animating():
		icon.position.y = -LIFT_PX if up else 0.0
		return
	var t := icon.create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(icon, "position:y", -LIFT_PX if up else 0.0, LIFT_S)
	icon.set_meta(&"lift", t)
