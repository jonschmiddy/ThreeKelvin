class_name Widgets
extends RefCounted

## Shared UI building blocks. Everything is built in code so there is one
## source of truth for how a module row or a stat readout looks.

enum ModuleContext { CARGO, INSTALLED, SHOP }

## A module entry: name, rarity, manufacturer, rolled affixes, and its cards.
static func module_row(m: ModuleData, ctx: ModuleContext, price: int,
		on_action: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 8, 10)
	sb.border_width_left = 3
	sb.border_color = DB.manufacturer_colour(m.manufacturer)
	if m.contraband:
		sb.border_color = Color("#d4614f")
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(UITheme.body(m.name, UITheme.ICE, UITheme.FS_BODY))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UITheme.body(ModuleData.rarity_name(m.rarity),
		ModuleData.rarity_colour(m.rarity), UITheme.FS_SMALL))

	var meta := "%s · %s" % [DB.manufacturer_name(m.manufacturer), ModuleData.slot_name(m.slot)]
	if m.contraband:
		meta += " · CONTRABAND"
	box.add_child(UITheme.body(meta, UITheme.COLD, 10))

	for a in m.affixes:
		box.add_child(UITheme.body("%s: %s" % [a.name, a.text], Color("#d4b98f"), 10))

	for c in m.resolved_cards():
		var line := "×1  %s · %dnrg%s · %s" % [
			c.name, c.energy,
			"" if c.heat == 0 else " · %dheat" % c.heat,
			c.describe(),
		]
		box.add_child(UITheme.body(line, UITheme.CHILL, 10))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	box.add_child(buttons)
	match ctx:
		ModuleContext.CARGO:
			var full := Run.slots_used(m.slot) >= Run.slots_for(m.slot)
			buttons.add_child(_btn("SWAP IN" if full else "INSTALL",
				on_action.bind("install", m)))
			buttons.add_child(_btn("SCRAP +%d" % Run.scrap_value_of(m),
				on_action.bind("scrap", m)))
		ModuleContext.INSTALLED:
			buttons.add_child(_btn("REMOVE", on_action.bind("uninstall", m)))
		ModuleContext.SHOP:
			var b := _btn("BUY %d" % price, on_action.bind("buy", m))
			b.disabled = Run.scrap < price
			buttons.add_child(b)
	return panel

static func hull_row(h: HullData, label: String, price: int,
		on_action: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 8, 10)
	sb.border_width_left = 3
	sb.border_color = Color("#d99b29")
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	top.add_child(UITheme.body(h.display_name(), UITheme.ICE, UITheme.FS_BODY))
	if price > 0:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sp)
		top.add_child(UITheme.body("%d scrap" % price, Color("#d99b29"), UITheme.FS_SMALL))

	box.add_child(UITheme.body(
		"%s · %d nrg · hand %d · %d hull · heat %d/%d · slots %d/%d/%d" % [
			HullData.weight_name(h.weight), h.reactor, h.hand_size, h.max_hull,
			h.heat_cap, h.dissipation, h.weapon_slots, h.system_slots, h.utility_slots,
		], UITheme.COLD, 10))
	box.add_child(UITheme.body(DB.perk_text(h.perk_id), Color("#d4b98f"), 10))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	box.add_child(buttons)
	var take := _btn(label, on_action.bind("take_hull", h))
	if price > 0:
		take.disabled = Run.scrap < price
	buttons.add_child(take)
	if price == 0:
		buttons.add_child(_btn("LEAVE IT", on_action.bind("leave_hull", h)))
	return panel

static func _btn(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	# Sound before action. Every button in the game is built here, so this is
	# the one place the interface needs wiring — and the action is usually a
	# screen swap, so the click has to be queued before the tree changes.
	b.pressed.connect(Audio.click)
	b.mouse_entered.connect(Audio.hover)
	b.pressed.connect(action)
	# A disabled button never emits `pressed`, so clicking one is completely
	# silent — indistinguishable from the game not registering the click. It
	# did register it. The answer is no, and the interface should say so.
	b.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and b.disabled:
			Audio.denied())
	return b

static func button(text: String, action: Callable) -> Button:
	return _btn(text, action)

## Label + value readout used in the HUD and unit panels.
static func stat(key: String, value: String, value_colour: Color = UITheme.ICE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UITheme.body(key.to_upper(), UITheme.COLD, UITheme.FS_SMALL))
	var v := UITheme.body(value, value_colour, UITheme.FS_SMALL)
	v.name = "Value"
	row.add_child(v)
	return row

static func chip(text: String, colour: Color = UITheme.LINE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UITheme.flat(Color(0, 0, 0, 0), colour, 2, 2, 6)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(UITheme.body(text, UITheme.CHILL, 10))
	return p

static func section(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UITheme.header(title))
	box.add_child(UITheme.hsep())
	return box

static func panel_with(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 12, 12))
	p.add_child(child)
	return p

static func scroller(child: Control, min_height: int = 200) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(0, min_height)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s
