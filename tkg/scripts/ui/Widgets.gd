class_name Widgets
extends RefCounted

## Shared UI building blocks. Everything is built in code so there is one
## source of truth for how a module row or a stat readout looks.

## Fixed tooltip width, so tooltips along a row of mounts read as one panel, not four.
## Why: docs/why/Widgets.md#tooltips
const TIP_W := 168

## WHAT AN AUGMENTED PART SAYS, in every box that describes a part: the hover popup
## (`module_readout`) and the hull's tip (`module_tip_panel`).
## Why: docs/why/Widgets.md#what-an-augmented-part-says
const AUGMENTED_TEXT := "AUGMENTED. The Lab can't add to it again."


## The AUGMENTED line, in ICE: the colour of the corner mark on the part's plate
## (`ModuleIcon.augment_mark`), so the word and the mark read as one fact.
## Wrapped at `width` when one is given, like the affix lines it sits under.
static func augmented_label(width: float, font_size: int) -> Label:
	var l := UITheme.body(AUGMENTED_TEXT, UITheme.ICE, font_size)
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	return l

## A Control tooltip, as Godot's plain text cannot keep grade, gauges and affixes apart.
## Why: docs/why/Widgets.md#tooltips
static func module_tip_panel(m: ModuleData) -> Control:
	var panel := PanelContainer.new()
	# No border: a tooltip already floats off what is under it, and a frame reads as a window.
	panel.add_theme_stylebox_override("panel",
		UITheme.flat(UITheme.PANEL2, Color(0, 0, 0, 0), 0, 8, 10))
	panel.custom_minimum_size = Vector2(TIP_W, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	top.add_child(UITheme.body(m.name.to_upper(), UITheme.ICE, UITheme.FS_BODY))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UITheme.body(ModuleData.rarity_name(m.rarity),
		ModuleData.rarity_ink(m.rarity), UITheme.FS_SMALL))

	# Manufacturer in its own colour, matching the plate edge and hold border.
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 5)
	box.add_child(meta)
	meta.add_child(UITheme.body(DB.manufacturer_name(m.manufacturer),
		DB.manufacturer_colour(m.manufacturer), UITheme.FS_SMALL))
	meta.add_child(UITheme.body("· %s · %d x %d" % [
		ModuleData.slot_name(m.slot), m.size.x, m.size.y],
		UITheme.COLD, UITheme.FS_SMALL))

	var gauges: PackedStringArray = []
	for g in AffixData.GAUGES:
		# A gauge is a pip count; the part holds it as the fields `PER_PIP` names.
		var per: Dictionary = Run.PER_PIP.get(g, {})
		var v := 0
		if not per.is_empty():
			var field: StringName = per.keys()[0]
			v = int(round(float(m.get(field)) / float(per[field])))
		if v != 0:
			gauges.append("%s%d %s" % ["+" if v > 0 else "", v,
				String(g).to_upper()])
	if not gauges.is_empty():
		box.add_child(UITheme.hsep())
		box.add_child(UITheme.body(" · ".join(gauges), UITheme.ICE,
			UITheme.FS_SMALL))

	# AUGMENTED goes under the affixes, and stands alone when STRIP has taken
	# every affix off: the mark outlives what the Lab added (ModuleData.augmented).
	if not m.affixes.is_empty() or m.augmented:
		box.add_child(UITheme.hsep())
		for a in m.affixes:
			var al := UITheme.body("%s — %s" % [a.name, a.text], UITheme.EMBER,
				UITheme.FS_SMALL)
			al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			al.custom_minimum_size = Vector2(TIP_W - 20, 0)
			box.add_child(al)
		if m.augmented:
			box.add_child(augmented_label(TIP_W - 20, UITheme.FS_SMALL))

	var cards: PackedStringArray = []
	for c in m.resolved_cards():
		cards.append(c.name.to_upper())
	if not cards.is_empty():
		box.add_child(UITheme.hsep())
		box.add_child(UITheme.body("GRANTS  %s" % " · ".join(cards),
			UITheme.CHILL, UITheme.FS_SMALL))
	return panel


## A bare Button shows the plain arrow; only `_btn` sets the hand the reticle reads.
static func wear_pointer(c: Control) -> void:
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## `as` answers null for a non-module payload; a typed assignment off the dict raises.
## Why: docs/why/Widgets.md#drag-payloads
static func dragged_module(data: Variant) -> ModuleData:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("module"):
		return null
	return (data as Dictionary).module as ModuleData


## One toggle shape for three screens, including the focus ink a hand-rolled copy forgot.
static func paint_toggle(b: Button, label: String, on: bool,
		lit: Color = UITheme.EMBER) -> void:
	b.text = "%s  %s" % ["[X]" if on else "[ ]", label]
	var tint := lit if on else UITheme.QUOTE
	b.add_theme_color_override("font_color", tint)
	b.add_theme_color_override("font_focus_color", tint)


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
		top.add_child(UITheme.body("%d credits" % price, Color("#d99b29"), UITheme.FS_SMALL))

	box.add_child(UITheme.body(
		"%s · %d nrg · hand %d · %d hull · heat %d/%d · slots %d/%d/%d" % [
			HullData.weight_name(h.weight), h.reactor, h.hand_size, h.max_hull,
			h.heat_cap, h.dissipation, h.weapon_slots, h.system_slots, h.utility_slots,
		], UITheme.COLD, 10))
	# Every perk, not just the manufacturer's: an S-tier carries four and one understated it.
	for pid in h.perks():
		box.add_child(UITheme.body(DB.perk_text(pid), Color("#d4b98f"), 10))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	box.add_child(buttons)
	var take := _btn(label, on_action.bind("take_hull", h))
	if price > 0:
		take.disabled = Run.credits < price
	buttons.add_child(take)
	if price == 0:
		# A FRAME YOU GAVE THE STRIP UP FOR cuts up for what the strip paid
		# (`Run.found_scrap`), in place of LEAVE IT, which would pay nothing.
		var cut := Run.found_scrap_credits() if h == Run.found_hull else 0
		if cut > 0:
			var scrap := _btn("SCRAP +%d" % cut, on_action.bind("scrap_hull", h))
			scrap.name = "ScrapHull"
			scrap.tooltip_text = tip("Cuts it up for credits and one crate of scrap. The crate goes in SECTOR LOOT.")
			buttons.add_child(scrap)
		else:
			buttons.add_child(_btn("LEAVE IT", on_action.bind("leave_hull", h)))
	return panel

static func _btn(text: String, action: Callable, click: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	# The reticle closes on `CURSOR_POINTING_HAND`; Godot's Button default is the plain arrow.
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Sound before action: the action is usually a screen swap, so queue the click first.
	if click:
		b.pressed.connect(Audio.click)
	b.mouse_entered.connect(Audio.hover)
	b.pressed.connect(action)
	# A disabled button never emits `pressed`, so it needs its own answer or looks unregistered.
	b.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and b.disabled:
			Audio.denied())
	return b

## `click` false for a button whose action already makes its own sound, so the
## two do not stack: the HUD's page tabs, which the screen change answers.
static func button(text: String, action: Callable, click: bool = true) -> Button:
	return _btn(text, action, click)

## THE BUTTON THAT COMMITS, in ember: the station's BUY and UNDOCK, the system
## map's GO. Every state is set: disabled, or a GO that cannot go looks like one
## that can; focus, or the theme's grey box draws over the ember.
static func commit(b: Button, pad_v: int = 5, pad_h: int = 14) -> Button:
	b.add_theme_stylebox_override("normal",
		UITheme.flat(Color("#0a0f17"), UITheme.EMBER, 0, pad_v, pad_h))
	b.add_theme_stylebox_override("hover",
		UITheme.flat(Color("#1d1409"), UITheme.FLARE, 0, pad_v, pad_h))
	b.add_theme_stylebox_override("pressed",
		UITheme.flat(UITheme.EMBER, UITheme.HOT, 0, pad_v, pad_h))
	b.add_theme_stylebox_override("focus",
		UITheme.flat(Color("#0a0f17"), UITheme.EMBER, 0, pad_v, pad_h))
	b.add_theme_stylebox_override("disabled",
		UITheme.flat(UITheme.VOID, UITheme.LINE, 0, pad_v, pad_h))
	b.add_theme_color_override("font_color", UITheme.EMBER)
	b.add_theme_color_override("font_hover_color", UITheme.HOT)
	b.add_theme_color_override("font_focus_color", UITheme.EMBER)
	b.add_theme_color_override("font_pressed_color", UITheme.VOID)
	b.add_theme_color_override("font_disabled_color", UITheme.COLD.darkened(0.3))
	return b

## A button beside a `commit` one: the OUTLINE style whatever the theme's, its
## words in CHILL.
static func quiet(b: Button) -> Button:
	var o := UITheme.outline_boxes()
	for state: String in o:
		b.add_theme_stylebox_override(state, o[state])
	b.add_theme_stylebox_override("focus", o.normal)
	b.add_theme_color_override("font_color", UITheme.CHILL)
	b.add_theme_color_override("font_focus_color", UITheme.CHILL)
	return b

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

## Free now, not deferred: queue_free left old and new children laid out together a frame.
## Refit's icon grid splashed a surplus row for a frame when a part went into the hold.
## Why: docs/why/Widgets.md#layout-helpers
static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

## Wrap in the string: a Label under a themed TooltipPanel cannot take autowrap from the theme.
## Why: docs/why/Widgets.md#tooltips
static func tip(text: String) -> String:
	var out: PackedStringArray = []
	for para in text.split("\n"):
		var line := ""
		for word in (para as String).split(" "):
			if line == "":
				line = word
			elif line.length() + 1 + (word as String).length() <= UITheme.TOOLTIP_WRAP:
				line += " " + word
			else:
				out.append(line)
				line = word
		out.append(line)
	return "\n".join(out)

## One `pad()` replaces four private copies; `child` is optional as many build the margin first.
## Why: docs/why/Widgets.md#layout-helpers
static func pad(child: Control = null, h: int = 8, v: int = 6) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, h)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, v)
	if child != null:
		m.add_child(child)
	return m

## The alpha is load-bearing: a solid fill covered the sky `SpaceLayer` draws behind panels.
## Why: docs/why/Widgets.md#layout-helpers
static func panel_with(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",
		UITheme.flat(Color(UITheme.PANEL, UITheme.PANEL_A), UITheme.LINE, 0, 12, 12))
	p.add_child(child)
	return p

## A dimmed prompt over `host`: the shade eats input and a left click on its margin calls
## `on_dismiss`. Put the card (mouse STOP, so only the margin dismisses) in the returned centre.
static func prompt(host: Control, on_dismiss: Callable, alpha: float = 0.80) -> CenterContainer:
	var shade := ColorRect.new()
	shade.color = Color(NoteCard.DIM, alpha)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			on_dismiss.call())
	host.add_child(shade)
	var mid := CenterContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(mid)
	return mid

## Pin to the viewport rect, not the screen's: Main's margin left a lighter frame (Jon, Oct 20).
## Why: docs/why/Widgets.md#layout-helpers
static func cover_picture(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var fit := func() -> void:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		var vr := c.get_viewport_rect()
		if c.global_position != vr.position:
			c.global_position = vr.position
		if c.size != vr.size:
			c.size = vr.size
	# (connected while it is in the tree and let go as it leaves: a lambda made
	# here has no object of its own for Godot to drop the connections with)
	c.tree_entered.connect(func() -> void:
		var p := c.get_parent() as CanvasItem
		if p != null and not p.item_rect_changed.is_connected(fit):
			p.item_rect_changed.connect(fit)
		if not c.get_viewport().size_changed.is_connected(fit):
			c.get_viewport().size_changed.connect(fit)
		fit.call_deferred())
	c.tree_exiting.connect(func() -> void:
		var p := c.get_parent() as CanvasItem
		if p != null and p.item_rect_changed.is_connected(fit):
			p.item_rect_changed.disconnect(fit)
		var vp := c.get_viewport()
		if vp != null and vp.size_changed.is_connected(fit):
			vp.size_changed.disconnect(fit))
	c.ready.connect(fit)


static func scroller(child: Control, min_height: int = 200) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(0, min_height)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

## Not a field dump: that said `feedback: 4`, not what feedback does.
## Why: docs/why/Widgets.md#card-readout
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

	# Two pairs: what the card is, then where it came from, so the questions never interleave.
	# Why: docs/why/Widgets.md#card-readout
	var mod: ModuleData = DB.modules.get(c.source_id)
	var rare := ModuleData.rarity_ink(c.source_rarity)
	box.add_child(UITheme.body(c.name.to_upper(), rare, UITheme.FS_SMALL))
	box.add_child(UITheme.body("%s · %s" % [c.type_name().to_upper(),
		ModuleData.rarity_name(c.source_rarity).to_upper()],
		UITheme.COLD, UITheme.FS_SMALL))
	if mod != null:
		# Manufacturer in its own colour; grey was the one place it went unbranded.
		box.add_child(UITheme.body(
			DB.manufacturer_name(mod.manufacturer).to_upper(),
			DB.manufacturer_colour(mod.manufacturer), UITheme.FS_SMALL))
		# Skip the module line when it is the card, or DROSS prints over DROSS.
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

	# Flavour goes last in its own section: among specifications the eye scans past a sentence.
	# Why: docs/why/Widgets.md#card-readout
	if mod != null and mod.flavour != "":
		box.add_child(UITheme.hsep())
		# Colour carries the voice: a second typeface at 8 px reads as a different UI, so dropped.
		# Why: docs/why/Widgets.md#card-readout
		var fl := UITheme.body("\"%s\"" % mod.flavour, UITheme.QUOTE, UITheme.FS_SMALL)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(168, 0)
		box.add_child(fl)
	return panel

## Shared by chassis select and refit so two copies cannot drift; locked rows are dimmed.
## Why: docs/why/Widgets.md#ability-rows
static func ability_row(at: String, title: String, text: String, accent: Color,
		unlocked: bool, count: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var tag := UITheme.body(at, accent if unlocked else UITheme.COLD, UITheme.FS_SMALL)
	tag.custom_minimum_size = Vector2(84, 0)
	row.add_child(tag)
	var have := UITheme.body(count, accent if unlocked else UITheme.CHILL,
		UITheme.FS_SMALL)
	have.custom_minimum_size = Vector2(40, 0)
	row.add_child(have)
	var name_label := UITheme.body(title.to_upper(),
		UITheme.ICE if unlocked else UITheme.COLD, UITheme.FS_SMALL)
	name_label.custom_minimum_size = Vector2(112, 0)
	row.add_child(name_label)
	var what := UITheme.body(text, UITheme.COLD if unlocked else UITheme.QUOTE,
		UITheme.FS_SMALL)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(what)
	return row

## A banner carries no words, so hovering it must name the berth's holder and set bonuses.
## Why: docs/why/Widgets.md#manufacturer-readout
static func manufacturer_readout(id: StringName) -> VBoxContainer:
	var m: ManufacturerData = DB.manufacturers.get(id)
	if m == null:
		return null
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	box.add_child(UITheme.body(m.name.to_upper(), m.colour, UITheme.FS_SMALL))
	if m.tagline != "":
		box.add_child(UITheme.body(tip(m.tagline), UITheme.QUOTE, UITheme.FS_SMALL))
	if m.identity != "":
		box.add_child(UITheme.hsep())
		box.add_child(UITheme.body(tip(m.identity), UITheme.COLD, UITheme.FS_SMALL))

	# Backstory is left out: wrapped at TOOLTIP_WRAP it would be a fourteen-line panel.
	# Why: docs/why/Widgets.md#manufacturer-readout
	box.add_child(UITheme.hsep())
	# Minus one means no run to count: `ChassisSelect` flies these flags before `start_new_run`.
	var have := Run.manufacturer_count(id) if Run.hull != null else -1
	for tier in [3, 5]:
		var nm: String = m.set3_name if tier == 3 else m.set5_name
		var tx: String = m.set3_text if tier == 3 else m.set5_text
		if nm == "":
			continue
		var lit: bool = have >= tier
		var head := "%d+ PARTS — %s" % [tier, nm.to_upper()]
		if have >= 0:
			head = "%d/%d — %s" % [mini(have, tier), tier, nm.to_upper()]
		box.add_child(UITheme.body(head, m.colour if lit else UITheme.COLD,
			UITheme.FS_SMALL))
		var what := UITheme.body(tip(tx),
			UITheme.COLD if lit else UITheme.QUOTE, UITheme.FS_SMALL)
		box.add_child(what)
	return box


## Built as a list so a caller can drop the rows into whatever container it has.
static func ability_rows(manufacturer: StringName, perk_id: StringName, have: int) -> Array:
	var out: Array = []
	var m: ManufacturerData = DB.manufacturers.get(manufacturer)
	if m == null:
		return out
	# The perk row moved to the masthead; four always-on rows would crowd the two tracker rows.
	# Why: docs/why/Widgets.md#ability-rows
	var short := DB.short_name(m.name).to_upper()
	out.append(ability_row("3+ %s" % short, m.set3_name, m.set3_text,
		m.colour, have >= 3, "%d / 3" % have))
	out.append(ability_row("5+ %s" % short, m.set5_name, m.set5_text,
		m.colour, have >= 5, "%d / 5" % have))
	return out


## States what a part is, not what its cards do; the cards sit beside it.
## `width` fixes the box: a minimum let long names widen the panel and ragged the column.
## Why: docs/why/Widgets.md#module-readout
static func module_readout(m: ModuleData, width: float = 0.0) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 7, 8)
	sb.border_width_left = 3
	sb.border_color = DB.manufacturer_colour(m.manufacturer)
	panel.add_theme_stylebox_override("panel", sb)
	# A card's width, so the three boxes read as one object, not a panel with two cards.
	var w := width if width > 0.0 else float(CardView.CARD_W)
	panel.custom_minimum_size = Vector2(w, 0)
	if width > 0.0:
		# SHRINK_BEGIN so the parent row cannot stretch it past the minimum;
		# together they make the minimum an exact size.
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var nm := UITheme.body(m.name.to_upper(),
		ModuleData.rarity_ink(m.rarity), UITheme.FS_SMALL)
	if width > 0.0:
		# The name is the only line long enough to set the width, so it is the
		# only one that has to be allowed to wrap.
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(0, 0)
	box.add_child(nm)
	var f := m.footprint()
	box.add_child(UITheme.body("%s \u00b7 %s" % [
		ModuleData.rarity_name(m.rarity).to_upper(),
		ModuleData.slot_name(m.slot).to_upper()], UITheme.COLD, UITheme.FS_SMALL))
	var mk := UITheme.body("%s" % (DB.manufacturer_name(m.manufacturer)
		if m.manufacturer != &"" else "Unbranded"),
		DB.manufacturer_colour(m.manufacturer), UITheme.FS_SMALL)
	if width > 0.0:
		# The manufacturer line is the widest, not the name, so wrap it or the column is ragged.
		mk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mk)
	box.add_child(UITheme.body("%dx%d \u00b7 %d %s" % [f.x, f.y, m.cells(),
		"cell" if m.cells() == 1 else "cells"], UITheme.CHILL, UITheme.FS_SMALL))

	# Zero is not printed (reverses the earlier ruling): +0 sat on two thirds of the catalogue.
	# A common plate and a Ripsaw now read alike here; the manifest still prints +0 dashed.
	# Why: docs/why/Widgets.md#module-readout
	var gauges: Array = []
	for axis in DB.PASSIVE_AXIS.get(m.id, []):
		var pips: int = DB.ATTR_BUMP[int(m.rarity)]
		if pips == 0:
			continue
		gauges.append(["%s +%d" % [String(axis).to_upper(), pips],
			UITheme.ICE])
	if DB.PASSIVE_COST.has(m.id):
		var row: Array = DB.PASSIVE_COST[m.id]
		gauges.append(["%s \u2212%d" % [String(row[0]).to_upper(),
			int(row[1])], UITheme.LEAVE])
	if m.reactor != 0:
		gauges.append(["REACTOR +%d" % m.reactor, UITheme.ICE])
	if not gauges.is_empty():
		box.add_child(UITheme.hsep())
		for raw in gauges:
			var g: Array = raw
			box.add_child(UITheme.body(String(g[0]), g[1], UITheme.FS_SMALL))

	# Affixes wrap at the flavour's cap: one unwrapped affix sentence set the whole panel's width.
	# Why: docs/why/Widgets.md#module-readout
	for a in m.affixes:
		var al := UITheme.body("%s \u2014 %s" % [a.name, a.text],
			UITheme.EMBER, UITheme.FS_SMALL)
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.custom_minimum_size = Vector2(CardView.CARD_W - 14, 0)
		box.add_child(al)
	if m.augmented:
		box.add_child(augmented_label(CardView.CARD_W - 14, UITheme.FS_SMALL))

	if m.flavour != "":
		box.add_child(UITheme.hsep())
		var q := UITheme.body(m.flavour, UITheme.QUOTE, UITheme.FS_SMALL)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size = Vector2(CardView.CARD_W - 14, 0)
		box.add_child(q)
	return panel

## One tooltip, perks grouped by source: manufacturer ones persist, grade ones are the upgrade.
## The empty case is printed so a C hull does not read as perks that failed to load.
## Why: docs/why/Widgets.md#perk-tooltip
static func set_tip(id: StringName, have: int, fitted: int) -> String:
	var m: ManufacturerData = DB.manufacturers.get(id)
	if m == null:
		return ""
	var head := "%s · %d toward the set" % [DB.short_name(m.name).to_upper(), have]
	if have > fitted:
		head += " (the hull alone)" if fitted == 0 \
			else " (%d fitted, +1 hull)" % fitted
	var out: PackedStringArray = [head, ""]
	for tier in [3, 5]:
		var nm := m.set3_name if tier == 3 else m.set5_name
		var tx := m.set3_text if tier == 3 else m.set5_text
		# "ON" against a count of what is still owed. A tick and a cross would
		# say less: "2 MORE" is the number the player acts on.
		var lead := "ON    " if have >= tier else "%d MORE" % (tier - have)
		out.append("%s  %d+ %s" % [lead, tier, nm])
		out.append("        %s" % tx)
	return "
".join(out)


static func perk_tip(h: HullData) -> String:
	if h == null:
		return ""
	var out: PackedStringArray = ["PERKS"]
	var manufacturer: ManufacturerData = DB.manufacturers.get(h.manufacturer)
	var own := _perk_line(h.perk_id)
	if own != "":
		out.append("")
		out.append(manufacturer.name.to_upper() if manufacturer != null
			else "UNBRANDED")
		out.append(own)
	out.append("")
	out.append("%s TIER" % h.tier_letter())
	var any := false
	for p in h.tier_perks:
		var line := _perk_line(p)
		if line != "":
			out.append(line)
			any = true
	if not any:
		out.append("No perks. Each tier from B up has one more.")
	return "\n".join(out)


## Empty for a perk id not in the table, so a retired perk prints nothing, not a hollow dash.
static func _perk_line(id: StringName) -> String:
	var pd: Dictionary = DB.hull_perks.get(id, {})
	if pd.is_empty():
		return ""
	return "%s \u2014 %s" % [str(pd.name), str(pd.text)]


## Panels match the rest of the game; colour carries state, not an aligned ON gutter.
## Body strings go through `tip()`, as an autowrapping Label measures height from no width.
## Why: docs/why/Widgets.md#perk-tooltip
static func set_readout(id: StringName, have: int, fitted: int) -> VBoxContainer:
	var m: ManufacturerData = DB.manufacturers.get(id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if m == null:
		return box

	# Say MANUFACTURER SET BONUS in full, so the reader knows what the set is of.
	box.add_child(UITheme.body("MANUFACTURER SET BONUS", UITheme.COLD,
		UITheme.FS_SMALL))
	box.add_child(UITheme.hsep())
	box.add_child(UITheme.body(m.name.to_upper(), m.colour, UITheme.FS_SMALL))
	# Say where the count comes from: the hull counts toward the set, so one part shows two pips.
	var from := "%d fitted" % fitted
	if have > fitted:
		from = "the hull" if fitted == 0 else "%d fitted + the hull" % fitted
	box.add_child(UITheme.body("%d of 5 · %s" % [have, from],
		UITheme.COLD, UITheme.FS_SMALL))

	# TYPED, or nothing downstream can be inferred: an untyped array literal
	# yields Variant and `have >= tier` then has no type to give `on`.
	for tier: int in [3, 5]:
		var on: bool = have >= tier
		box.add_child(UITheme.hsep())
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var nm := UITheme.body("%d+  %s" % [tier,
			(m.set3_name if tier == 3 else m.set5_name).to_upper()],
			UITheme.EMBER if on else UITheme.QUOTE, UITheme.FS_SMALL)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		if not on:
			head.add_child(UITheme.body("%d MORE" % (tier - have),
				UITheme.COLD, UITheme.FS_SMALL))
		box.add_child(head)
		box.add_child(pad(UITheme.body(
			tip(m.set3_text if tier == 3 else m.set5_text),
			UITheme.COLD if on else UITheme.QUOTE, UITheme.FS_SMALL), 8, 0))
	return box


static func perk_readout(h: HullData) -> VBoxContainer:
	# No plate of its own: Godot already wraps tooltips in a panel, so a PanelContainer doubled it.
	# Why: docs/why/Widgets.md#perk-tooltip
	var accent := DB.manufacturer_colour(h.manufacturer)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	box.add_child(UITheme.body("PERKS", UITheme.COLD, UITheme.FS_SMALL))

	var manufacturer: ManufacturerData = DB.manufacturers.get(h.manufacturer)
	var own: Dictionary = DB.hull_perks.get(h.perk_id, {})
	if not own.is_empty():
		box.add_child(UITheme.hsep())
		box.add_child(UITheme.body(
			manufacturer.name.to_upper() if manufacturer != null else "UNBRANDED",
			accent, UITheme.FS_SMALL))
		_perk_rows(box, own)

	box.add_child(UITheme.hsep())
	box.add_child(UITheme.body("%s TIER" % h.tier_letter(), UITheme.ICE,
		UITheme.FS_SMALL))
	var any := false
	for p in h.tier_perks:
		var pd: Dictionary = DB.hull_perks.get(p, {})
		if pd.is_empty():
			continue
		_perk_rows(box, pd)
		any = true
	# The empty case is drawn, as in `perk_tip`, so a blank reads as the ladder explaining itself.
	if not any:
		box.add_child(UITheme.body(tip("No perks yet. Each tier from B up has one more."),
			UITheme.QUOTE, UITheme.FS_SMALL))
	return box


## Name in EMBER, effect in COLD, as the module readout does for an affix.
static func _perk_rows(box: VBoxContainer, pd: Dictionary) -> void:
	box.add_child(UITheme.body(str(pd.name), UITheme.EMBER, UITheme.FS_SMALL))
	# Wrap in the string: an off-tree Label measured 309 rows and settled at 168 once laid out.
	# A `custom_minimum_size.x` on the label was tried and still gave 309.
	# Why: docs/why/Widgets.md#perk-tooltip
	var body := UITheme.body(tip(str(pd.text)), UITheme.COLD, UITheme.FS_SMALL)
	box.add_child(pad(body, 8, 0))
