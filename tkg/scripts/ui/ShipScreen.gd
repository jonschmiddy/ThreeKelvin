class_name ShipScreen
extends Control

## Refit, rebuilt around the six attributes.
##
## The old version was a hull and two lists of modules, which was the whole game
## when hulls were anonymous frames and attributes did not exist. Both of those
## changed: a chassis is now somebody's chassis, and every event check in the
## game reads one of six numbers that this screen is the only place to see.
##
## So it reads top to bottom as an answer to "what am I flying": the maker's
## mark and how close you are to its set, then the ship and its hardpoints, then
## what the ship IS on the six axes, then what is bolted to it.
##
## Hardpoints read as cells like heat and energy do: filled means occupied, an
## ember outline means a pad is free. Slot pressure is the whole install-or-scrap
## decision, so it should be countable at a glance rather than inferred from a
## list of what happens to be fitted.

var _slots: VBoxContainer
var _cargo: VBoxContainer
var _installed: VBoxContainer
var _frame: Label
var _maker: Label
var _sets: HBoxContainer
var _badge: ChassisSelect.Badge
var _attrs: AttrBlock
var _condition: Label

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.ship_changed.connect(_refresh)
	Sig.resources_changed.connect(_refresh)
	_refresh()

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)

	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# --- left: the ship itself, and what it can carry
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var view := ShipView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(view)

	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 3)
	left.add_child(_slots)
	var lw := Widgets.panel_with(left)
	lw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(lw)

	# --- middle: what the ship IS. The reason this screen was rebuilt.
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 5)
	mid.custom_minimum_size = Vector2(210, 0)
	mid.add_child(UITheme.body("ATTRIBUTES", UITheme.COLD, UITheme.FS_SMALL))
	_attrs = AttrBlock.new()
	mid.add_child(_attrs)
	mid.add_child(UITheme.hsep())
	# Hull is the one attribute that moves without a refit, so the screen says
	# out loud what it is reading. Otherwise a HUL that dropped from 4 to 2 over
	# three fights looks like a bug in the table rather than damage.
	_condition = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_condition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(_condition)
	var mgap := Control.new()
	mgap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(mgap)
	body.add_child(Widgets.panel_with(mid))

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

	body.add_child(Widgets.panel_with(right))

## The maker's mark, the hull's name, and how far along its set you are — one
## line, because they are one fact. The hull counts toward the set shown beside
## it, which only reads as sensible if the two sit together.
func _build_header() -> PanelContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)

	_badge = ChassisSelect.Badge.new()
	head.add_child(_badge)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_frame = UITheme.body("", UITheme.ICE, UITheme.FS_SMALL)
	names.add_child(_frame)
	_maker = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	names.add_child(_maker)
	head.add_child(names)

	var hgap := Control.new()
	hgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hgap)

	_sets = HBoxContainer.new()
	_sets.add_theme_constant_override("separation", 3)
	_sets.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_sets)
	return Widgets.panel_with(head)

func _refresh() -> void:
	var man := Run.hull.manufacturer
	var maker: ManufacturerData = DB.manufacturers.get(man)
	var accent := maker.colour if maker != null else UITheme.CHILL

	_badge.man = man
	_badge.mark = accent
	_badge.field = maker.field if maker != null else UITheme.PANEL
	_badge.queue_redraw()

	_frame.text = Run.hull.display_name().to_upper()
	_maker.text = "%s · %s" % [
		DB.manufacturer_name(man).to_upper(), DB.perk_text(Run.hull.perk_id)]
	_maker.add_theme_color_override("font_color", accent)

	_attrs.setup(Run.attributes(), accent)
	_condition.text = "Hull reads your CURRENT plating, not your maximum: %d of %d. Damage is a failed check waiting to happen." % [Run.hp, Run.max_hp()]

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
		var hull_note := "
Includes the hull (+1)." if Run.hull.manufacturer == id else ""
		chip.tooltip_text = "%s
3+: %s — %s
5+: %s — %s%s" % [
			m.name, m.set3_name, m.set3_text, m.set5_name, m.set5_text, hull_note]
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
				# Four filled rects, not draw_rect's outline mode. An unfilled
				# draw_rect strokes the BOUNDARY, so a 1px line straddles it —
				# half a pixel outside the cell and half in. Rounding sends the
				# outside half to a whole pixel on some edges and not others, and
				# an empty pad came out visibly larger than the filled one beside
				# it. Drawn as fills, both are exactly CELL.
				draw_rect(Rect2(pos, CELL), Color("#10161f"), true)
				var e := UITheme.EMBER
				draw_rect(Rect2(pos, Vector2(CELL.x, 1)), e, true)
				draw_rect(Rect2(pos + Vector2(0, CELL.y - 1), Vector2(CELL.x, 1)), e, true)
				draw_rect(Rect2(pos, Vector2(1, CELL.y)), e, true)
				draw_rect(Rect2(pos + Vector2(CELL.x - 1, 0), Vector2(1, CELL.y)), e, true)
