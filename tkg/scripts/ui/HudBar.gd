class_name HudBar
extends PanelContainer

## Persistent top bar: navigation, hull, heat, economy, frame, and live set-bonus
## progress.
##
## SHIP and MAP live here rather than inside each screen, so they are in the same
## place everywhere. SHIP greys out during combat instead of disappearing — you
## cannot refit mid-fight, and a button that says so beats one that vanishes.

var _row: HBoxContainer
var _heat: BoxGauge
var _heat_text: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.bevel(UITheme.PANEL, 5, 6))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	add_child(_row)
	Sig.resources_changed.connect(refresh)
	Sig.ship_changed.connect(refresh)
	Sig.screen_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if Run.hull == null:
		return
	for c in _row.get_children():
		c.queue_free()

	var fighting := Router.in_combat()

	# Ship | Sector | Starchart. The page you are on is lit rather than merely
	# disabled, so the nav says where you are as well as where you can go.
	_row.add_child(_tab("SHIP", Router.current is ShipScreen, fighting,
		func() -> void: Router.show_ship(),
		"Install and scrap modules."))
	# Combat happens in the sector, so the tab stays lit through a fight rather
	# than greying out as if you had left.
	_row.add_child(_tab("SECTOR", Router.current is SectorScreen or fighting, false,
		func() -> void: Router.show_sector(),
		"What is around you."))
	_row.add_child(_tab("STARCHART", Router.current is StarchartScreen, fighting,
		func() -> void: Router.show_starchart(),
		"Where to go next."))

	_row.add_child(_divider())

	var hull_colour := UITheme.ICE
	if Run.hp < Run.max_hp() * 0.35:
		hull_colour = Color("#c98d7a")
	_row.add_child(Widgets.stat("hull", "%d/%d" % [Run.hp, Run.max_hp()], hull_colour))

	# Heat reads as countable cells; the number beside it names the cost when
	# you are over cap, because that is the only time the number matters.
	_row.add_child(UITheme.body("HEAT", UITheme.COLD, UITheme.FS_SMALL))
	_heat = BoxGauge.new()
	_heat.setup(BoxGauge.Mode.HEAT, Run.heat_cap(), Run.heat)
	_row.add_child(_heat)
	var over := Run.heat - Run.heat_cap()
	_heat_text = UITheme.body(
		("%d — %d HULL" % [Run.heat, over]) if over > 0 else "%d/%d" % [Run.heat, Run.heat_cap()],
		UITheme.FLARE if over > 0 else UITheme.COLD, UITheme.FS_SMALL)
	_row.add_child(_heat_text)

	_row.add_child(_divider())
	_row.add_child(Widgets.stat("scrap", str(Run.scrap)))
	if Run.exotic > 0:
		_row.add_child(Widgets.stat("exotic", str(Run.exotic)))
	_row.add_child(Widgets.stat("fuel", str(Run.fuel)))

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(sp)

func _divider() -> Control:
	var d := Panel.new()
	d.custom_minimum_size = Vector2(1, 14)
	d.add_theme_stylebox_override("panel", UITheme.flat(UITheme.LINE, Color(0, 0, 0, 0), 0, 0, 0))
	return d

func _tab(label: String, active: bool, fighting: bool, action: Callable,
		hint: String) -> Button:
	var b := Widgets.button(label, action)
	b.disabled = fighting or active
	b.tooltip_text = "Locked during combat." if fighting else hint
	if active and not fighting:
		# Lit, not greyed: an active tab is a statement, not an unavailable option.
		b.add_theme_stylebox_override("normal", UITheme.bevel(Color("#4a2a0c"), 3, 5))
		b.add_theme_stylebox_override("disabled", UITheme.bevel(Color("#4a2a0c"), 3, 5))
		b.add_theme_color_override("font_disabled_color", UITheme.HOT)
	return b
