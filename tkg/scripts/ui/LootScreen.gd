class_name LootScreen
extends Control

## Post-encounter: what you recovered, and the install-or-scrap decision.
## Every drop is an upgrade, a build piece, or repair money — no dead loot.

var _list: VBoxContainer
var _installed: VBoxContainer
var _hull_box: VBoxContainer

func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.ship_changed.connect(_refresh)
	Sig.resources_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	var section := Widgets.section("recovered")
	_hull_box = VBoxContainer.new()
	_hull_box.add_theme_constant_override("separation", 6)
	section.add_child(_hull_box)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	section.add_child(Widgets.scroller(_list, 380))
	var p := Widgets.panel_with(section)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(p)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)
	var cont := Widgets.section("continue")
	cont.add_child(Widgets.button("BACK TO THE MAP", func(): Router.show_map()))
	right.add_child(Widgets.panel_with(cont))
	var inst := Widgets.section("installed")
	_installed = VBoxContainer.new()
	_installed.add_theme_constant_override("separation", 6)
	inst.add_child(Widgets.scroller(_installed, 340))
	var ip := Widgets.panel_with(inst)
	ip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(ip)

func _refresh() -> void:
	for c in _hull_box.get_children():
		c.queue_free()
	if Run.found_hull != null:
		_hull_box.add_child(Widgets.hull_row(Run.found_hull, "TRANSFER", 0, _on_action))

	for c in _list.get_children():
		c.queue_free()
	if Run.cargo.is_empty():
		_list.add_child(UITheme.body("Nothing recovered.", UITheme.COLD, UITheme.FS_SMALL))
	for m in Run.cargo:
		_list.add_child(Widgets.module_row(m, Widgets.ModuleContext.CARGO, 0, _on_action))

	for c in _installed.get_children():
		c.queue_free()
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		_installed.add_child(UITheme.body(
			"%s %d/%d" % [ModuleData.slot_name(s), Run.slots_used(s), Run.slots_for(s)],
			UITheme.COLD, 10))
		for m in Run.installed:
			if m.slot == s:
				_installed.add_child(
					Widgets.module_row(m, Widgets.ModuleContext.INSTALLED, 0, _on_action))

func _on_action(action: String, thing: Variant) -> void:
	match action:
		"install": Run.install_module(thing as ModuleData)
		"uninstall": Run.uninstall_module(thing as ModuleData)
		"scrap": Run.scrap_module(thing as ModuleData)
		"take_hull": Run.transfer_to_hull(thing as HullData)
		"leave_hull":
			Run.found_hull = null
			Sig.ship_changed.emit()
	_refresh()
