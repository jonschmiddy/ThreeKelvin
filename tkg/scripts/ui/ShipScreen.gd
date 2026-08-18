class_name ShipScreen
extends Control

## Refit. Your hull on the left with its hardpoints, storage on the right.
##
## Hardpoints read as cells like heat and energy do: filled means occupied, an
## ember outline means a pad is free. Slot pressure is the whole install-or-scrap
## decision, so it should be countable at a glance rather than inferred from a
## list of what happens to be fitted.

var _slots: VBoxContainer
var _cargo: VBoxContainer
var _installed: VBoxContainer
var _frame: Label
var _sets: HBoxContainer

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.ship_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	# --- left: the hull and what it can carry
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_frame = UITheme.body("", UITheme.ICE, UITheme.FS_SMALL)
	head.add_child(_frame)
	var hgap := Control.new()
	hgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hgap)
	_sets = HBoxContainer.new()
	_sets.add_theme_constant_override("separation", 3)
	head.add_child(_sets)
	left.add_child(head)

	var view := ShipView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(view)

	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 3)
	left.add_child(_slots)
	root.add_child(Widgets.panel_with(left))

	# --- right: fitted above, storage below. Fitted always has content, so the
	# column is never the empty rectangle it was when storage led.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	right.custom_minimum_size = Vector2(310, 0)

	var fitted := Widgets.section("fitted")
	_installed = VBoxContainer.new()
	_installed.add_theme_constant_override("separation", 3)
	var fs := Widgets.scroller(_installed, 150)
	fs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fitted.add_child(fs)
	fitted.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fitted)

	var store := Widgets.section("storage")
	_cargo = VBoxContainer.new()
	_cargo.add_theme_constant_override("separation", 3)
	var cs := Widgets.scroller(_cargo, 110)
	cs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	store.add_child(cs)
	store.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(store)

	root.add_child(Widgets.panel_with(right))

func _refresh() -> void:
	_frame.text = "%s - %s" % [Run.hull.display_name().to_upper(), DB.perk_text(Run.hull.perk_id)]
	for c in _sets.get_children():
		c.queue_free()
	# Set bonuses are the class system, so they belong beside the fittings that
	# build them rather than in a HUD you read while doing something else.
	for id in DB.manufacturers.keys():
		var n := Run.manufacturer_count(id)
		if n == 0:
			continue
		var m: ManufacturerData = DB.manufacturers[id]
		var stars := " **" if n >= 5 else (" *" if n >= 3 else "")
		var chip := Widgets.chip("%s %d%s" % [DB.short_name(m.name), n, stars], m.colour)
		chip.tooltip_text = "%s
3+: %s — %s
5+: %s — %s" % [
			m.name, m.set3_name, m.set3_text, m.set5_name, m.set5_text]
		_sets.add_child(chip)

	for c in _slots.get_children():
		c.queue_free()
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		_slots.add_child(_slot_row(s))

	for c in _installed.get_children():
		c.queue_free()
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		for m in Run.installed:
			if m.slot == s:
				_installed.add_child(
					Widgets.module_row(m, Widgets.ModuleContext.INSTALLED, 0, _on_action))

	for c in _cargo.get_children():
		c.queue_free()
	if Run.cargo.is_empty():
		_cargo.add_child(UITheme.body("Storage is empty.", UITheme.COLD, UITheme.FS_SMALL))
	for m in Run.cargo:
		_cargo.add_child(Widgets.module_row(m, Widgets.ModuleContext.CARGO, 0, _on_action))

func _slot_row(slot: ModuleData.Slot) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_map := {
		ModuleData.Slot.WEAPON: "WEAPON",
		ModuleData.Slot.SYSTEM: "SYSTEM",
		ModuleData.Slot.UTILITY: "UTILITY",
	}
	var label := UITheme.body(String(name_map[slot]), UITheme.COLD, UITheme.FS_SMALL)
	label.custom_minimum_size = Vector2(52, 0)
	row.add_child(label)

	var used := Run.slots_used(slot)
	var total := Run.slots_for(slot)
	var pads := SlotPads.new()
	pads.setup(used, total)
	row.add_child(pads)

	row.add_child(UITheme.body("%d/%d" % [used, total], UITheme.CHILL, UITheme.FS_SMALL))
	return row

func _on_action(action: String, thing: Variant) -> void:
	match action:
		"install": Run.install_module(thing as ModuleData)
		"uninstall": Run.uninstall_module(thing as ModuleData)
		"scrap": Run.scrap_module(thing as ModuleData)
	_refresh()


## Hardpoint cells. Filled steel is occupied; an ember outline is a free pad,
## which is what makes an unspent slot read as opportunity rather than absence.
class SlotPads extends Control:
	const CELL := Vector2(9, 11)
	const GAP := 2
	var used := 0
	var total := 0

	func setup(u: int, t: int) -> void:
		used = u
		total = t
		custom_minimum_size = Vector2(total * (CELL.x + GAP), CELL.y)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		queue_redraw()

	func _draw() -> void:
		var y: float = floor((size.y - CELL.y) * 0.5)
		for i in total:
			var pos := Vector2(i * (CELL.x + GAP), y)
			if i < used:
				draw_rect(Rect2(pos, CELL), UITheme.COLD, true)
				draw_rect(Rect2(pos, Vector2(CELL.x, 1)), UITheme.CHILL, true)
				draw_rect(Rect2(pos, Vector2(1, CELL.y)), UITheme.CHILL, true)
			else:
				draw_rect(Rect2(pos, CELL), Color("#10161f"), true)
				draw_rect(Rect2(pos, CELL), UITheme.EMBER, false, 1.0)
