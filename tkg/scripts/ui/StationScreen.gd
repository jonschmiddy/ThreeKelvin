class_name StationScreen
extends Control

## Stations are paid campfires. Every service costs credits, and credits are the same
## currency you would rather spend on modules — that tension IS the difficulty.
##
## A station is now four things rather than two: a shelf, a service desk, a
## BUYER for what is in your hold, and — where the place is developed enough to
## have a laboratory — a fabricator. Every price on the screen comes from
## `Market` or `Fabricator`, and none of them is stored: a price is a function of
## this place and that part, so there is nothing here to drift, to save, or to
## come back from a save as a discount.

var _header: RichTextLabel
var _trade: Label
var _services: VBoxContainer
var _stock: VBoxContainer
var _hull_box: VBoxContainer
var _hold: VBoxContainer
var _bench: VBoxContainer
var _bench_panel: PanelContainer

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Sig.resources_changed.connect(_refresh)
	Sig.ship_changed.connect(_refresh)
	# Somebody else bought something off this shelf. The stock is one list the
	# whole party is standing in front of, so it has to empty while you watch
	# rather than the next time you happen to reopen the screen.
	Sig.party_map_changed.connect(_refresh)
	Sig.map_changed.connect(_refresh)
	_stock_up()
	_inspect()
	_refresh()

func _build() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# Who this market is short of, said in words. The rule behind the prices is
	# simple enough to state, so state it — a trade economy the player has to
	# reverse-engineer from receipts is a puzzle, not an economy.
	_trade = UITheme.body("", Color("#d99b29"), UITheme.FS_SMALL)
	head_section.add_child(_trade)
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
	# Expands into whatever the panel has left rather than demanding 300px.
	#
	# A fixed 300 minimum put the column's minimum height above the 540 the
	# viewport actually has — head panel, plus the stock header, plus the hull
	# on the pad, plus 300 — so the bottom of the list was clipped by the
	# window instead of scrolled to. The scrollbar could not reach the last
	# item because the ScrollContainer itself was hanging off the screen.
	var stock_scroll := Widgets.scroller(_stock, 90)
	stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stock_section.add_child(stock_scroll)
	var sp := Widgets.panel_with(stock_section)
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)

	# The hold, with a buyer standing in front of it. This is the other half of
	# the shelf and it belongs on the same screen: what you sell and what you buy
	# are one decision made out of one pocket.
	var hold_section := Widgets.section("your hold")
	_hold = VBoxContainer.new()
	_hold.add_theme_constant_override("separation", 6)
	var hold_scroll := Widgets.scroller(_hold, 90)
	hold_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hold_section.add_child(hold_scroll)
	var hp2 := Widgets.panel_with(hold_section)
	hp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(hp2)

	var bench_section := Widgets.section("fabricator")
	_bench = VBoxContainer.new()
	_bench.add_theme_constant_override("separation", 5)
	bench_section.add_child(_bench)
	_bench_panel = Widgets.panel_with(bench_section)
	left.add_child(_bench_panel)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)
	var depart := Widgets.section("depart")
	depart.add_child(Widgets.button("UNDOCK", func(): Router.show_sector()))
	right.add_child(Widgets.panel_with(depart))
	var ship := Widgets.section("ship")
	ship.add_child(ShipView.new())
	right.add_child(Widgets.panel_with(ship))

## Roll what is on the shelf, ONCE per system per run.
##
## The guard used to be `shop.is_empty()`, and that was an exploit rather than a
## style choice: buying the shelf out emptied the array, so leaving and coming
## back re-rolled a full one. An unlimited supply of parts at a fixed price is an
## unlimited supply of money the moment any part is worth more melted than
## bought, which is exactly what happened. `stocked` says what was meant — this
## station has been visited, and what somebody brought here is what there is.
##
## Nothing is priced here any more. Market prices a part from the place it is
## standing in, so the shelf holds parts and not price tags.
func _stock_up() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.stocked:
		return
	n.stocked = true
	# Positional. What is on a station's shelf belongs to the station, and
	# `n.stocked` already says the shelf is rolled once and kept — this is the
	# same rule, now expressed so that four ships docking in four different
	# orders see one shelf instead of four. See Rng.derive().
	var r := Rng.derive(&"shop", n.index)
	var count := 5 if n.region == MapGen.Region.COSMOPOLITAN else 3
	for i in count:
		var force := &""
		if n.region == MapGen.Region.TERRITORY:
			force = n.manufacturer
		elif n.region == MapGen.Region.COSMOPOLITAN:
			# Cosmopolitan hubs carry multiple makers side by side.
			force = Rng.pick(r, DB.manufacturers.keys())
		var danger := n.danger + 3 if n.region == MapGen.Region.LAWLESS else maxi(1, n.danger - 2)
		var m := LootGen.roll_module(danger, force, n.region == MapGen.Region.LAWLESS, r)
		# Legitimate markets do not move Legendary and above.
		if n.region == MapGen.Region.COSMOPOLITAN and m.rarity > ModuleData.Rarity.EPIC:
			m.rarity = ModuleData.Rarity.EPIC
		n.shop.append(m)
	if n.region != MapGen.Region.LAWLESS and r.randf() < 0.4:
		n.shop_hull = LootGen.roll_hull(n.danger, r)

## High-law space inspects; lawless space does not.
##
## Its own function, and called on every dock rather than from inside the stock
## roll. It used to sit under that early return, which meant the customs officer
## only ever looked at you on the visit that happened to roll the shelves — dock
## clean, fly out, come back carrying, and nobody checked. `n.inspected` is what
## makes it once per system; the shelf has nothing to do with it.
func _inspect() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n.region == MapGen.Region.COSMOPOLITAN and not n.inspected and Run.contraband_count() > 0:
		n.inspected = true
		var c := Run.contraband_count()
		var fine := 20 * c
		Run.add_credits(-fine)
		Run.log_line("Inspection: %d illegal part%s found. Fined %d credits." % [
			c, "" if c == 1 else "s", fine], &"heat")

func _refresh() -> void:
	var n: MapGen.MapNode = Run.node_at()
	var note := ""
	match n.region:
		MapGen.Region.COSMOPOLITAN: note = " · multi-brand stock, strict inspections"
		MapGen.Region.LAWLESS: note = " · fenced goods, no questions"
	_header.clear()
	# Named by what the place is, not by the derived region label — "Frontier
	# station" says less than "Settlement station, moderate security".
	_header.append_text("[color=#%s]%s station[/color] · %s security · danger %d[color=#%s]%s[/color]" % [
		UITheme.ICE.to_html(false), MapGen.development_name(n.development),
		MapGen.security_name(n.security).to_lower(), n.danger,
		UITheme.COLD.to_html(false), note])

	_trade.text = Market.trade_line(n)

	for c in _services.get_children():
		c.queue_free()
	var missing := Run.max_hp() - Run.hp

	var eight := mini(8, maxi(1, missing))
	var eight_cost := Market.repair_price(n, eight)
	var repair := Widgets.button("REPAIR %d HULL · %d credits" % [eight, eight_cost],
		_repair.bind(eight))
	repair.disabled = missing <= 0 or Run.credits < eight_cost
	repair.tooltip_text = Widgets.tip("%.1f credits a point here. Work is dear on the frontier and cheap in a capital." % Market.repair_rate(n))
	_services.add_child(repair)

	var full_cost := Market.repair_price(n, missing)
	var full := Widgets.button("FULL REPAIR · %d credits" % full_cost, _repair.bind(missing))
	full.disabled = missing <= 0 or Run.credits < full_cost
	_services.add_child(full)

	var refuel_cost := Market.refuel_price(n)
	var refuel := Widgets.button("REFUEL +%d · %d credits" % [
		Market.REFUEL_UNITS, refuel_cost], _refuel)
	refuel.disabled = Run.credits < refuel_cost
	_services.add_child(refuel)

	var purge_cost := Market.purge_price(n)
	var purge := Widgets.button("PURGE 1 DROSS · %d credits" % purge_cost, _purge)
	purge.disabled = Run.dross <= 0 or Run.credits < purge_cost
	_services.add_child(purge)

	var coolant_cost := Market.coolant_price(n)
	var coolant := Widgets.button("+2 HEAT CAP · %d credits" % coolant_cost, _coolant)
	coolant.disabled = Run.credits < coolant_cost
	_services.add_child(coolant)

	# One row per material you are carrying, rather than the single hardcoded
	# exotic row this replaced. Materials are worth more where there is somebody
	# who can use them, so a capital pays half again what an outpost does — which
	# makes hauling an organ inward a trade, and not just inventory.
	for stock in Run.material_stock():
		var mid: StringName = stock.id
		var paid := Market.material_price(n, mid)
		var b := Widgets.button("SELL 1 %s → %d SCRAP" % [
			str(stock.name).to_upper(), paid], _sell_material.bind(mid))
		b.tooltip_text = Widgets.tip("You have %d. Laboratories pay for these; mining outposts use them as ballast." % int(stock.count))
		_services.add_child(b)

	for c in _hull_box.get_children():
		c.queue_free()
	if n.shop_hull != null and not n.taken.has(MapGen.OPTION_SHOP_HULL):
		_hull_box.add_child(Widgets.hull_row(n.shop_hull, "PURCHASE",
			Market.hull_price(n, n.shop_hull), _on_action))

	for c in _stock.get_children():
		c.queue_free()
	# What is LEFT, which is not the same as what is on the shelf. A sold part
	# stays in `n.shop` so that everybody's slot numbers keep meaning the same
	# thing — see MapGen.OPTION_SHOP — and is hidden here instead.
	var left := 0
	for i in n.shop.size():
		if n.taken.has(MapGen.OPTION_SHOP + i):
			continue
		left += 1
		var m: ModuleData = n.shop[i]
		_stock.add_child(Widgets.module_row(m, Widgets.ModuleContext.SHOP,
			Market.ask(n, m), _on_action))
	if left == 0:
		_stock.add_child(UITheme.body("Shelves bare. Nothing restocks — what was brought here is gone.",
			UITheme.COLD, UITheme.FS_SMALL))

	for c in _hold.get_children():
		c.queue_free()
	if Run.cargo.is_empty():
		_hold.add_child(UITheme.body("Hold empty.", UITheme.COLD, UITheme.FS_SMALL))
	for m in Run.cargo:
		_hold.add_child(Widgets.module_row(m, Widgets.ModuleContext.HOLD,
			Market.bid(n, m), _on_action))

	for c in _bench.get_children():
		c.queue_free()
	var recipes := Fabricator.available(n)
	_bench_panel.visible = not recipes.is_empty()
	for r in recipes:
		var b := Widgets.button("%s · %s" % [str(r.name), Fabricator.cost_line(n, r)],
			_fabricate.bind(r))
		b.disabled = not Fabricator.can_make(n, r)
		b.tooltip_text = Widgets.tip(str(r.text))
		_bench.add_child(b)

func _repair(amount: int) -> void:
	var n: MapGen.MapNode = Run.node_at()
	var cost := Market.repair_price(n, amount)
	if Run.credits < cost:
		return
	Run.add_credits(-cost)
	var healed := Run.heal(amount)
	Run.log_line("Repaired %d hull for %d credits." % [healed, cost], &"good")

func _refuel() -> void:
	var cost := Market.refuel_price(Run.node_at())
	if Run.credits < cost:
		return
	Run.add_credits(-cost)
	Run.fuel += Market.REFUEL_UNITS
	Run.log_line("Refuelled.", &"good")
	Sig.resources_changed.emit()

func _purge() -> void:
	var cost := Market.purge_price(Run.node_at())
	if Run.credits < cost or Run.dross <= 0:
		return
	Run.add_credits(-cost)
	Run.dross -= 1
	Run.log_line("Purged Dross.", &"good")
	Sig.ship_changed.emit()

func _coolant() -> void:
	var cost := Market.coolant_price(Run.node_at())
	if Run.credits < cost:
		return
	Run.add_credits(-cost)
	Run.heat_cap_bonus += 2
	Run.log_line("Coolant upgraded. Heat cap +2.", &"good")

func _sell_material(id: StringName) -> void:
	var n: MapGen.MapNode = Run.node_at()
	if not Run.spend_material(id, 1):
		return
	var paid := Market.material_price(n, id)
	Run.add_credits(paid)
	Run.log_line("Sold 1 %s for %d credits." % [DB.material_name(id).to_lower(), paid], &"good")

func _fabricate(r: Dictionary) -> void:
	var line := Fabricator.make(Run.node_at(), r)
	if line.is_empty():
		return
	Run.log_line(line, &"good")

func _on_action(action: String, thing: Variant) -> void:
	var n: MapGen.MapNode = Run.node_at()
	match action:
		"buy":
			var m := thing as ModuleData
			var slot := n.shop.find(m)
			var price := Market.ask(n, m)
			if slot < 0 or Run.credits < price:
				return
			# Before the money, not after. Buying into a full hold used to take
			# the credits, erase the part off the shelf and then log "left
			# behind" — the module was gone from both places and paid for.
			if Run.hold_full():
				Run.log_line("The hold is full. Nowhere to put it.", &"them")
				return
			# One shelf, four buyers. ASK, and pay only if you won — a purchase
			# that charged first and lost the race would take credits for a part
			# somebody else is carrying. See RunState.take_option().
			if not await Run.take_option(n, MapGen.OPTION_SHOP + slot):
				var who := Net.taker_name(n.index, MapGen.OPTION_SHOP + slot)
				Run.log_line("Sold.%s" % (" %s got there first." % who.to_upper()
					if who != "" else ""), &"them")
				_refresh()
				return
			Run.add_credits(-price)
			Run.stow(m)
			Run.log_line("Bought %s for %d credits." % [m.name, price], &"good")
			Sig.ship_changed.emit()
		"sell":
			# Every sale here moves this market's price down a notch. One good
			# system must not absorb an unlimited hold at the same rate, or the
			# question stops being "how far do I haul this" and becomes "carry
			# everything to the best place I have seen".
			var sm := thing as ModuleData
			var paid := Market.bid(n, sm)
			if paid <= 0:
				return
			Run.take_from_hold(sm)
			Run.add_credits(paid)
			n.trades += 1
			Run.log_line("Sold %s for %d credits." % [sm.name, paid], &"good")
			Sig.ship_changed.emit()
		"take_hull":
			var h := thing as HullData
			var price2 := Market.hull_price(n, h)
			if Run.credits < price2:
				return
			# One rack, one hull. Same race as the shelf above, and the same
			# order: ask, then pay.
			if not await Run.take_option(n, MapGen.OPTION_SHOP_HULL):
				var who2 := Net.taker_name(n.index, MapGen.OPTION_SHOP_HULL)
				Run.log_line("Gone.%s" % (" %s is flying it." % who2.to_upper()
					if who2 != "" else ""), &"them")
				_refresh()
				return
			Run.add_credits(-price2)
			Run.transfer_to_hull(h)
		"install": Run.install_module(thing as ModuleData)
		"scrap": Run.scrap_module(thing as ModuleData)
	_refresh()
