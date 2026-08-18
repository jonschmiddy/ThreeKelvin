class_name StationScreen
extends Control

## Stations are paid campfires. Every service costs scrap, and scrap is the same
## currency you would rather spend on modules — that tension IS the difficulty.

var _header: RichTextLabel
var _services: VBoxContainer
var _stock: VBoxContainer
var _hull_box: VBoxContainer

func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.resources_changed.connect(_refresh)
	Sig.ship_changed.connect(_refresh)
	_stock_up()
	_refresh()

func _build() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)

	var head_section := Widgets.section("station")
	_header = RichTextLabel.new()
	_header.bbcode_enabled = true
	_header.fit_content = true
	_header.add_theme_stylebox_override("normal", UITheme.empty())
	head_section.add_child(_header)
	_services = VBoxContainer.new()
	_services.add_theme_constant_override("separation", 5)
	head_section.add_child(_services)
	left.add_child(Widgets.panel_with(head_section))

	var stock_section := Widgets.section("stock")
	_hull_box = VBoxContainer.new()
	_hull_box.add_theme_constant_override("separation", 6)
	stock_section.add_child(_hull_box)
	_stock = VBoxContainer.new()
	_stock.add_theme_constant_override("separation", 6)
	stock_section.add_child(Widgets.scroller(_stock, 300))
	var sp := Widgets.panel_with(stock_section)
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)
	var depart := Widgets.section("depart")
	depart.add_child(Widgets.button("RETURN TO MAP", func(): Router.show_map()))
	right.add_child(Widgets.panel_with(depart))
	var ship := Widgets.section("ship")
	ship.add_child(ShipView.new())
	right.add_child(Widgets.panel_with(ship))

func _stock_up() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if not n.shop.is_empty():
		return
	var count := 5 if n.region == MapGen.Region.COSMOPOLITAN else 3
	for i in count:
		var force := &""
		if n.region == MapGen.Region.TERRITORY:
			force = n.manufacturer
		elif n.region == MapGen.Region.COSMOPOLITAN:
			# Cosmopolitan hubs carry multiple makers side by side.
			force = DB.manufacturers.keys().pick_random()
		var danger := n.danger + 2 if n.region == MapGen.Region.LAWLESS else maxi(1, n.danger - 1)
		var m := LootGen.roll_module(danger, force, n.region == MapGen.Region.LAWLESS)
		# Legitimate markets do not move Legendary and above.
		if n.region == MapGen.Region.COSMOPOLITAN and m.rarity > ModuleData.Rarity.EPIC:
			m.rarity = ModuleData.Rarity.EPIC
		var markup := 1.2
		if n.region == MapGen.Region.COSMOPOLITAN:
			markup = 1.5
		elif n.region == MapGen.Region.LAWLESS:
			markup = 1.9
		m.set_meta("price", int(round(m.scrap_value * markup)))
		n.shop.append(m)
	if n.region != MapGen.Region.LAWLESS and randf() < 0.4:
		n.shop_hull = LootGen.roll_hull(n.danger)

	# High-law space inspects; lawless space does not.
	if n.region == MapGen.Region.COSMOPOLITAN and not n.inspected and Run.contraband_count() > 0:
		n.inspected = true
		var c := Run.contraband_count()
		var fine := 20 * c
		Run.add_scrap(-fine)
		Run.log_line("Inspection: %d illegal part%s found. Fined %d scrap." % [
			c, "" if c == 1 else "s", fine], &"heat")

func _refresh() -> void:
	var n: MapGen.MapNode = Run.node_at()
	var note := ""
	match n.region:
		MapGen.Region.COSMOPOLITAN: note = " · multi-brand stock, strict inspections"
		MapGen.Region.LAWLESS: note = " · fenced goods, no questions"
	_header.clear()
	_header.append_text("[color=#%s]%s station[/color] · danger %d[color=#%s]%s[/color]" % [
		UITheme.ICE.to_html(false), MapGen.region_name(n.region), n.danger,
		UITheme.COLD.to_html(false), note])

	for c in _services.get_children():
		c.queue_free()
	var rate := Run.repair_cost_per_hull()
	var missing := Run.max_hp() - Run.hp

	var repair := Widgets.button("REPAIR 8 HULL · %d scrap" % (rate * 8), _repair.bind(8))
	repair.disabled = missing <= 0 or Run.scrap < rate * 8
	_services.add_child(repair)

	var full := Widgets.button("FULL REPAIR · %d scrap" % (rate * missing), _repair.bind(missing))
	full.disabled = missing <= 0 or Run.scrap < rate * missing
	_services.add_child(full)

	var refuel := Widgets.button("REFUEL +5 · 12 scrap", _refuel)
	refuel.disabled = Run.scrap < 12
	_services.add_child(refuel)

	var purge := Widgets.button("PURGE 1 DROSS · 15 scrap", _purge)
	purge.disabled = Run.dross <= 0 or Run.scrap < 15
	_services.add_child(purge)

	var coolant := Widgets.button("+2 HEAT CAP · 30 scrap", _coolant)
	coolant.disabled = Run.scrap < 30
	_services.add_child(coolant)

	if Run.exotic > 0:
		_services.add_child(Widgets.button("TRADE 1 EXOTIC → 45 SCRAP", _trade_exotic))

	for c in _hull_box.get_children():
		c.queue_free()
	if n.shop_hull != null:
		var price := 80 + n.shop_hull.tier * 70
		_hull_box.add_child(Widgets.hull_row(n.shop_hull, "PURCHASE", price, _on_action))

	for c in _stock.get_children():
		c.queue_free()
	if n.shop.is_empty():
		_stock.add_child(UITheme.body("Shelves bare.", UITheme.COLD, UITheme.FS_SMALL))
	for m in n.shop:
		_stock.add_child(Widgets.module_row(m, Widgets.ModuleContext.SHOP,
			int(m.get_meta("price", m.scrap_value)), _on_action))

func _repair(amount: int) -> void:
	var cost := Run.repair_cost_per_hull() * amount
	if Run.scrap < cost:
		return
	Run.add_scrap(-cost)
	var healed := Run.heal(amount)
	Run.log_line("Repaired %d hull." % healed, &"good")

func _refuel() -> void:
	if Run.scrap < 12:
		return
	Run.add_scrap(-12)
	Run.fuel += 5
	Run.log_line("Refuelled.", &"good")
	Sig.resources_changed.emit()

func _purge() -> void:
	if Run.scrap < 15 or Run.dross <= 0:
		return
	Run.add_scrap(-15)
	Run.dross -= 1
	Run.log_line("Purged Dross.", &"good")
	Sig.ship_changed.emit()

func _coolant() -> void:
	if Run.scrap < 30:
		return
	Run.add_scrap(-30)
	Run.heat_cap_bonus += 2
	Run.log_line("Coolant upgraded. Heat cap +2.", &"good")

func _trade_exotic() -> void:
	if Run.exotic < 1:
		return
	Run.exotic -= 1
	Run.add_scrap(45)
	Run.log_line("Traded exotic material.", &"good")

func _on_action(action: String, thing: Variant) -> void:
	var n: MapGen.MapNode = Run.node_at()
	match action:
		"buy":
			var m := thing as ModuleData
			var price := int(m.get_meta("price", m.scrap_value))
			if Run.scrap < price:
				return
			Run.add_scrap(-price)
			n.shop.erase(m)
			Run.cargo.append(m)
			Run.log_line("Bought %s." % m.name, &"good")
			Sig.ship_changed.emit()
		"take_hull":
			var h := thing as HullData
			var price2 := 80 + h.tier * 70
			if Run.scrap < price2:
				return
			Run.add_scrap(-price2)
			n.shop_hull = null
			Run.transfer_to_hull(h)
		"install": Run.install_module(thing as ModuleData)
		"scrap": Run.scrap_module(thing as ModuleData)
	_refresh()
