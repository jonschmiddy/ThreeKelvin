class_name HudBar
extends PanelContainer

## Persistent top bar: hull, heat, economy, frame, and live set-bonus progress.

var _row: HBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.flat(UITheme.PANEL, UITheme.LINE, 0, 9, 12))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 16)
	add_child(_row)
	Sig.resources_changed.connect(refresh)
	Sig.ship_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if Run.hull == null:
		return
	for c in _row.get_children():
		c.queue_free()
	var hull_colour := UITheme.ICE
	if Run.hp < Run.max_hp() * 0.35:
		hull_colour = Color("#c98d7a")
	_row.add_child(Widgets.stat("hull", "%d/%d" % [Run.hp, Run.max_hp()], hull_colour))
	var heat_colour := UITheme.FLARE if Run.heat > Run.heat_cap() else UITheme.ICE
	_row.add_child(Widgets.stat("heat", "%d/%d" % [Run.heat, Run.heat_cap()], heat_colour))
	_row.add_child(Widgets.stat("scrap", str(Run.scrap)))
	_row.add_child(Widgets.stat("exotic", str(Run.exotic)))
	_row.add_child(Widgets.stat("fuel", str(Run.fuel)))
	_row.add_child(Widgets.stat("frame", Run.hull.display_name()))

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(sp)

	# Set bonuses are the class system, so they live where you can always see them.
	for id in DB.manufacturers.keys():
		var n := Run.manufacturer_count(id)
		if n == 0:
			continue
		var m: ManufacturerData = DB.manufacturers[id]
		var stars := ""
		if n >= 5:
			stars = " ★★"
		elif n >= 3:
			stars = " ★"
		var chip := Widgets.chip("%s %d%s" % [m.name.split(" ")[0], n, stars], m.colour)
		chip.tooltip_text = "%s\n3+: %s — %s\n5+: %s — %s" % [
			m.name, m.set3_name, m.set3_text, m.set5_name, m.set5_text]
		_row.add_child(chip)
