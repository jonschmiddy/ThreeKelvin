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

	# Grants is a STAT, printed like one. The Grant Count Law only does its job
	# if the count is visible at the point of choice — a law nobody can see is
	# just a rule the designer knows.
	var meta := "%s · %s · grants %d" % [DB.manufacturer_name(m.manufacturer),
		ModuleData.slot_name(m.slot), m.grant_count()]
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

	# Install-time deck delta, at the point of choice.
	#
	# Deck size is a managed resource and this is the only moment the player can
	# act on it, so the number moves where they can see it move — the same
	# philosophy as printing the odds on an event option before they commit.
	# Without it the Grant Count Law is invisible: you would feel a thickening
	# deck three fights later and never know which pickup did it.
	var here := DeckBuilder.build().size()
	var delta := 0
	if ctx == ModuleContext.CARGO or ctx == ModuleContext.SHOP:
		delta = m.grant_count()
		# A swap into a full rack takes the displaced module's cards with it.
		if Run.slots_used(m.slot) >= Run.slots_for(m.slot):
			for inst in Run.installed:
				var im: ModuleData = inst
				if im.slot == m.slot:
					delta -= im.grant_count()
					break
	elif ctx == ModuleContext.INSTALLED:
		delta = -m.grant_count()
	if delta != 0:
		var arrow := "deck %d → %d" % [here, here + delta]
		box.add_child(UITheme.body(arrow,
			UITheme.THEM if delta > 0 else UITheme.GOOD, 10))

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

## Name, what it is, where it came from, and what its rules words mean.
##
## Shared by the card gallery and by combat. A keyword you can only look up on a
## development screen is a keyword the player has to have memorised, which is
## the exact thing a glossary exists to prevent.
##
## Deliberately NOT a field dump. An earlier version printed every non-default
## property on the card, which was self-maintaining and useless: it told you
## `riposte: 4` when what you needed was what riposte does. The numbers are
## already on the card face — this panel exists for the things the card has no
## room to say.
static func card_readout(c: CardData) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 7, 8)
	sb.border_width_left = 3
	sb.border_color = DB.manufacturer_colour(c.manufacturer)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(178, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	# The two NAMES first, then the two CLASSIFICATIONS. What the card is called
	# and what granted it are the pair you are looking for; type, rarity, house
	# and slot are all the same kind of fact and belong together underneath,
	# rather than interleaved so that the eye crosses a category line twice.
	# Two pairs. What the CARD is — its verb and its class — then where it came
	# FROM — the house and the module. Each pair is a name over its
	# classification, and the two questions never interleave.
	var mod: ModuleData = DB.modules.get(c.source_id)
	var rare := ModuleData.rarity_colour(c.source_rarity)
	box.add_child(UITheme.body(c.name.to_upper(), rare, UITheme.FS_SMALL))
	box.add_child(UITheme.body("%s · %s" % [c.type_name().to_upper(),
		ModuleData.rarity_name(c.source_rarity).to_upper()],
		UITheme.COLD, UITheme.FS_SMALL))
	if mod != null:
		# The house in its own colour. It is the only line in the panel that
		# names a brand, and the brand already owns a colour everywhere else on
		# the card — the banner, the emblem, the border down the left of this
		# very panel. Printing it in cold grey was the one place the house went
		# unbranded.
		box.add_child(UITheme.body(
			DB.manufacturer_name(mod.manufacturer).to_upper(),
			DB.manufacturer_colour(mod.manufacturer), UITheme.FS_SMALL))
		# Unless the module is the card. Junk and hull-innate cards are named
		# after their own source, so printing both put DROSS over DROSS — a line
		# that answers a question nobody asked twice.
		if mod.name.to_upper() != c.name.to_upper():
			box.add_child(UITheme.body(mod.name.to_upper(),
				UITheme.ICE, UITheme.FS_SMALL))

	var terms := c.keywords()
	if not terms.is_empty():
		box.add_child(UITheme.hsep())
	for raw in terms:
		var pair: Array = raw
		box.add_child(UITheme.body(String(pair[0]).to_upper(),
			UITheme.ICE, UITheme.FS_SMALL))
		var def := UITheme.body(String(pair[1]), UITheme.COLD, UITheme.FS_SMALL)
		def.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		def.custom_minimum_size = Vector2(168, 0)
		box.add_child(def)

	# The quote last, in its own section.
	#
	# It was sitting with the module's name and slot, where it read as another
	# specification — and flavour next to specifications always loses, because
	# the eye is scanning for facts and finds a sentence in the middle of them.
	# At the bottom, after the rules are answered, it is the thing you read once
	# you have finished needing the panel.
	if mod != null and mod.flavour != "":
		box.add_child(UITheme.hsep())
		# Silkscreen at 8, like everything else — the grey is the whole signal.
		#
		# A second typeface was tried for this and it was the wrong tool. At
		# this resolution a different face does not read as a different VOICE,
		# it reads as a different UI, because there is not enough letterform
		# left at 8px for character to survive. Colour still works perfectly
		# well down here, and it costs no asset, no licence and no size guess.
		var fl := UITheme.body("\"%s\"" % mod.flavour, UITheme.QUOTE, UITheme.FS_SMALL)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(168, 0)
		box.add_child(fl)
	return panel
