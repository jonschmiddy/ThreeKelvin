class_name MapScreen
extends Control

## Star chart. Nodes are drawn in region colours; reachable ones are outlined
## and show their fuel cost. Lateral hops are cheap, so farming a danger band
## before descending is always an option — that is the greed clock.

var _chart: MapChart
var _where: RichTextLabel
var _jump_list: VBoxContainer
var _cargo_list: VBoxContainer
var _installed_list: VBoxContainer
var _ship_view: ShipView
var _ship_stats: Label
var _ship_perk: Label
var _deck_label: Label
var _found_hull_box: VBoxContainer

func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.ship_changed.connect(_refresh)
	Sig.resources_changed.connect(_refresh)
	Sig.map_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# --- left: the chart itself
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)

	var chart_section := Widgets.section("galaxy")
	_chart = MapChart.new()
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.node_activated.connect(_on_node_clicked)
	chart_section.add_child(_chart)
	_where = RichTextLabel.new()
	_where.bbcode_enabled = true
	_where.fit_content = true
	_where.custom_minimum_size = Vector2(0, 40)
	_where.add_theme_stylebox_override("normal", UITheme.empty())
	chart_section.add_child(_where)
	var chart_panel := Widgets.panel_with(chart_section)
	chart_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(chart_panel)

	var cargo_section := Widgets.section("cargo — uninstalled")
	_found_hull_box = VBoxContainer.new()
	_found_hull_box.add_theme_constant_override("separation", 6)
	cargo_section.add_child(_found_hull_box)
	_cargo_list = VBoxContainer.new()
	_cargo_list.add_theme_constant_override("separation", 6)
	cargo_section.add_child(Widgets.scroller(_cargo_list, 180))
	left.add_child(Widgets.panel_with(cargo_section))

	# --- right: jump options and ship
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(340, 0)
	root.add_child(right)

	var jump_section := Widgets.section("jump")
	_jump_list = VBoxContainer.new()
	_jump_list.add_theme_constant_override("separation", 5)
	jump_section.add_child(_jump_list)
	right.add_child(Widgets.panel_with(jump_section))

	var ship_section := Widgets.section("ship")
	_ship_view = ShipView.new()
	ship_section.add_child(_ship_view)
	_ship_stats = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_ship_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_section.add_child(_ship_stats)
	_ship_perk = UITheme.body("", Color("#d4b98f"), UITheme.FS_SMALL)
	_ship_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_section.add_child(_ship_perk)
	_deck_label = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	ship_section.add_child(_deck_label)
	_installed_list = VBoxContainer.new()
	_installed_list.add_theme_constant_override("separation", 6)
	ship_section.add_child(Widgets.scroller(_installed_list, 240))
	var ship_panel := Widgets.panel_with(ship_section)
	ship_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(ship_panel)

func _refresh() -> void:
	if Run.hull == null:
		return
	_chart.queue_redraw()
	var n: MapGen.MapNode = Run.node_at()
	var maker := ""
	if n.manufacturer != &"":
		maker = " — %s" % DB.manufacturer_name(n.manufacturer)
	_where.clear()
	_where.append_text("[color=#%s]%s%s[/color] · danger %d\n[color=#%s]%s[/color]" % [
		UITheme.ICE.to_html(false), MapGen.region_name(n.region), maker, n.danger,
		UITheme.COLD.to_html(false), MapGen.region_blurb(n.region)])

	# Jump options
	for c in _jump_list.get_children():
		c.queue_free()
	for idx in n.links:
		var target: MapGen.MapNode = Run.map[idx]
		var label := "%s%s\n%s · danger %d · %d fuel%s" % [
			MapGen.region_name(target.region),
			"" if target.manufacturer == &"" else " · " + DB.manufacturer_name(target.manufacturer).split(" ")[0],
			MapGen.type_label(target.type).to_lower(), target.danger,
			Run.fuel_cost_to(target),
			" · cleared" if target.cleared else "",
		]
		var b := Widgets.button(label, _on_jump.bind(idx))
		b.custom_minimum_size = Vector2(0, 44)
		b.disabled = not Run.can_jump_to(target)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_jump_list.add_child(b)

	# Ship
	_ship_stats.text = "%s · %d nrg · hand %d · %d hp · heat %d/%d · fuel ×%.1f" % [
		HullData.weight_name(Run.hull.weight), Run.reactor(), Run.hand_size(),
		Run.max_hp(), Run.heat_cap(), Run.dissipation(), Run.hull.fuel_factor]
	_ship_perk.text = DB.perk_text(Run.hull.perk_id)
	var summary := DeckBuilder.summarise()
	_deck_label.text = "deck %d cards%s" % [
		summary.size,
		"" if Run.dross == 0 else " · %d Dross (purge at a station)" % Run.dross]

	# Found hull offer
	for c in _found_hull_box.get_children():
		c.queue_free()
	if Run.found_hull != null:
		_found_hull_box.add_child(
			Widgets.hull_row(Run.found_hull, "TRANSFER", 0, _on_module_action))

	# Cargo and installed
	for c in _cargo_list.get_children():
		c.queue_free()
	if Run.cargo.is_empty():
		_cargo_list.add_child(UITheme.body("Cargo empty.", UITheme.COLD, UITheme.FS_SMALL))
	for m in Run.cargo:
		_cargo_list.add_child(
			Widgets.module_row(m, Widgets.ModuleContext.CARGO, 0, _on_module_action))

	for c in _installed_list.get_children():
		c.queue_free()
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		_installed_list.add_child(UITheme.body(
			"%s hardpoints %d/%d" % [ModuleData.slot_name(s), Run.slots_used(s), Run.slots_for(s)],
			UITheme.COLD, 10))
		for m in Run.installed:
			if m.slot == s:
				_installed_list.add_child(
					Widgets.module_row(m, Widgets.ModuleContext.INSTALLED, 0, _on_module_action))

func _on_jump(index: int) -> void:
	Router.jump_to(index)

func _on_node_clicked(index: int) -> void:
	var target: MapGen.MapNode = Run.map[index]
	if Run.can_jump_to(target):
		Router.jump_to(index)

func _on_module_action(action: String, thing: Variant) -> void:
	match action:
		"install": Run.install_module(thing as ModuleData)
		"uninstall": Run.uninstall_module(thing as ModuleData)
		"scrap": Run.scrap_module(thing as ModuleData)
		"take_hull": Run.transfer_to_hull(thing as HullData)
		"leave_hull":
			Run.found_hull = null
			Sig.ship_changed.emit()
	_refresh()


class MapChart extends Control:
	signal node_activated(index: int)

	func _init() -> void:
		custom_minimum_size = Vector2(0, 400)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				for n in Run.map:
					var node: MapGen.MapNode = n
					if _screen_pos(node).distance_to(mb.position) < 16.0:
						node_activated.emit(node.index)
						return

	func _screen_pos(n: MapGen.MapNode) -> Vector2:
		var canvas := Run.MAP_CANVAS
		var fx := (n.pos.x - canvas.position.x) / canvas.size.x
		var fy := (n.pos.y - canvas.position.y) / canvas.size.y
		return Vector2(24.0 + fx * (size.x - 48.0), 20.0 + fy * (size.y - 44.0))

	func _draw() -> void:
		if Run.map.is_empty():
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color("#070a10"), true)
		# Starfield
		var s := 99
		for i in 120:
			s = (s * 9301 + 49297) % 233280
			var x := float(s) / 233280.0 * size.x
			s = (s * 9301 + 49297) % 233280
			var y := float(s) / 233280.0 * size.y
			draw_rect(Rect2(Vector2(x, y), Vector2.ONE), Color("#141c26"), true)

		var here: MapGen.MapNode = Run.node_at()
		# Routes
		for n in Run.map:
			var node: MapGen.MapNode = n
			for idx in node.links:
				if idx <= node.index:
					continue
				var other: MapGen.MapNode = Run.map[idx]
				draw_line(_screen_pos(node), _screen_pos(other), Color("#1d2836"), 1.0)
		# Reachable routes highlighted warm
		for idx in here.links:
			var other2: MapGen.MapNode = Run.map[idx]
			draw_line(_screen_pos(here), _screen_pos(other2), Color("#5a4028"), 1.5)

		# Nodes
		var font := ThemeDB.fallback_font
		for n in Run.map:
			var node2: MapGen.MapNode = n
			var p := _screen_pos(node2)
			var is_here := node2.index == here.index
			var adjacent := here.links.has(node2.index)
			var r := 9.0 if is_here else (8.0 if node2.type == MapGen.NodeType.GOAL else 6.0)
			var fill := Color("#1d2836") if node2.cleared else MapGen.region_colour(node2)
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r * 2, r * 2)), fill, true)
			var outline := Color("#22303f")
			if is_here:
				outline = UITheme.FLARE
			elif adjacent:
				outline = Color("#8a6a3a")
			draw_rect(Rect2(p - Vector2(r + 2, r + 2), Vector2(r * 2 + 4, r * 2 + 4)),
				outline, false, 2.0 if is_here else 1.0)

			var label := MapGen.type_label(node2.type)
			if node2.cleared and node2.type != MapGen.NodeType.GOAL:
				label = "·"
			var text_colour := UITheme.ICE if (adjacent or is_here) else Color("#4a5a6c")
			draw_string(font, p + Vector2(-18, r + 14), label,
				HORIZONTAL_ALIGNMENT_CENTER, 36, 9, text_colour)
			if adjacent:
				draw_string(font, p + Vector2(-18, -r - 6),
					"%df" % Run.fuel_cost_to(node2),
					HORIZONTAL_ALIGNMENT_CENTER, 36, 9, Color("#8a6a3a"))
