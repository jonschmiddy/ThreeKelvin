extends RefCounted

## Run after touching Market.gd: every price axis is swept so melt < ask and bid < ask.
## The old exploit was a buy price and a melt price in two files; a nudge reopens it silently.
## Why: docs/why/MarketTest.md#market-sweep

var fails: int = 0

func run() -> void:
	print("\n=== MARKET ===")
	# A run, because `melt()` reads the hull's perk and there is no hull until one starts.
	Run.start_new_run()
	_check_invariant()
	_one_price()
	_augmented_price()
	_print_goods()
	_print_services()
	print("=== %s (%d violations) ===\n" % ["PASS" if fails == 0 else "FAIL", fails])

## A place with the axes set by hand. Every price in the game is a function of
## these fields and nothing else, so a synthetic node is a complete input.
func _place(dev: int, sec: int, berths: Array[StringName], danger: int) -> MapGen.MapNode:
	var n := MapGen.MapNode.new()
	n.development = dev as MapGen.Development
	n.security = sec
	n.berths = berths
	n.manufacturer = berths[0] if not berths.is_empty() else &""
	n.danger = danger
	n.type = MapGen.NodeType.STATION
	return n

func _part(rarity: int, manufacturer: StringName, contraband: bool) -> ModuleData:
	# Built from a real template so `contraband` reads off a real affix rather
	# than a flag nothing in the game sets that way.
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	m.manufacturer = manufacturer
	m.rarity = rarity as ModuleData.Rarity
	m.scrap_value = ModuleData.SCRAP_VALUE[rarity]
	var af: Array[AffixData] = []
	if contraband:
		for a in DB.affixes:
			if a.contraband:
				af.append(a)
				break
	m.affixes = af
	return m

func _check_invariant() -> void:
	var checked := 0
	var worst_ratio := 0.0
	var worst := ""
	for perk in [&"salvage_rack", &"cheap_parts"]:
		Run.hull.perk_id = perk
		for dev in 5:
			for sec in [1, 3, 5]:
				for danger in [1, 3, 5, 7, 10]:
					for manufacturer in [&"korvan", &""]:
						for rarity in 7:
							for cb in [false, true]:
								# Three manufacturer relationships: the part's own
								# holds this place, a rival does, or nobody does.
								for berths in [[] as Array[StringName],
										[&"korvan"] as Array[StringName],
										[&"solari", &"cygnet"] as Array[StringName]]:
									var n := _place(dev, sec, berths, danger)
									var m := _part(rarity, manufacturer, cb)
									var ask := Market.ask(n, m)
									var bid := Market.bid(n, m)
									var melt := Market.melt(m)
									checked += 1
									var ratio := float(melt) / float(ask)
									if ratio > worst_ratio:
										worst_ratio = ratio
										worst = "%s C%d dev%d sec%d d%d %s" % [
											"unbranded" if manufacturer == &"" else manufacturer,
											rarity, dev, sec, danger,
											"contraband" if cb else "clean"]
									if melt >= ask:
										fails += 1
										print("  BUY-AND-MELT  melt %d >= ask %d  (%s, perk %s)" % [
											melt, ask, worst, perk])
									if bid >= ask:
										fails += 1
										print("  SELL-BACK     bid %d >= ask %d  (%s, perk %s)" % [
											bid, ask, worst, perk])
	print("  %d price comparisons, worst melt/ask %.3f at %s" % [
		checked, worst_ratio, worst])

## The counter quotes the market: two prices for one object is a second currency.
## Saturating the market proves it: a bid falls as a station takes more, a melt price cannot.
## Why: docs/why/MarketTest.md#one-price
func _one_price() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n == null:
		fails += 1
		print("  NO NODE       the run has nowhere to be, so nothing can be sold")
		return
	n.trades = 0

	var part := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	var quoted := TradeCounter.offer(part)
	var bid := Market.bid(n, part)
	if quoted != bid:
		fails += 1
		print("  NOT THE BID   counter %d, market %d" % [quoted, bid])

	# A crate is priced by its own table, and that table is also in credits.
	var rows := MaterialTable.all()
	if not rows.is_empty():
		var crate := MaterialData.of(rows[0])
		var mq := TradeCounter.offer(crate)
		var mp := Market.material_price(n, crate.id)
		if mq != mp:
			fails += 1
			print("  NOT THE RATE  counter %d, table %d for %s" % [mq, mp, crate.id])

	# --- AND NOW MOVE THE MARKET UNDER IT.
	var melt_before := Market.melt(part)
	n.trades = 12
	var after := TradeCounter.offer(part)
	var melt_after := Market.melt(part)
	if after >= quoted:
		fails += 1
		print("  FLAT RATE     %d before %d sales, %d after -- the quote did not move"
			% [quoted, n.trades, after])
	if melt_before != melt_after:
		fails += 1
		print("  MELT MOVED    %d then %d, so it is no longer a floor" % [
			melt_before, melt_after])
	n.trades = 0

	# Nothing in hand is not a price of zero credits, it is no quote at all.
	if TradeCounter.offer(null) != 0:
		fails += 1
		print("  EMPTY HANDS   the counter priced nothing at %d" % TradeCounter.offer(null))
	print("  one price: bid %d, %d after a busy day, melt held at %d" % [
		quoted, after, melt_before])

	# The Promenade till charges, safe as a second currency only because ask always exceeds bid.
	# Why: docs/why/MarketTest.md#till-side
	var till := TradeCounter.offer(part, TradeCounter.Side.CHARGES)
	var ask := Market.ask(n, part)
	if till != ask:
		fails += 1
		print("  NOT THE ASK   till %d, market %d" % [till, ask])
	if till <= TradeCounter.offer(part, TradeCounter.Side.PAYS):
		fails += 1
		print("  NO SPREAD     till charges %d and pays %d -- buy it back for free"
			% [till, TradeCounter.offer(part, TradeCounter.Side.PAYS)])

	# --- AND IT SAYS WHY IT IS REFUSING, rather than going quietly dark.
	var purse := Run.credits
	Run.credits = maxi(0, till - 40)
	var short := TradeCounter.refusal(TradeCounter.Side.CHARGES, part)
	if not short.begins_with("NEED"):
		fails += 1
		print("  NO REASON     %d credits against a %d part said '%s'" % [
			Run.credits, till, short])
	Run.credits = till + 1000
	if TradeCounter.refusal(TradeCounter.Side.CHARGES, part) != "":
		fails += 1
		print("  REFUSED RICH  the till would not sell to someone who can pay")
	Run.credits = purse
	print("  the other side: asks %d, pays %d, and says '%s' when you are short" % [
		till, quoted, short])

	# Each desk takes only from its own side by drag `origin`: a slip charges for owned parts.
	# Why: docs/why/MarketTest.md#desk-sides
	var till_desk := TradeCounter.new()
	till_desk.side = TradeCounter.Side.CHARGES
	var pay_desk := TradeCounter.new()
	if not till_desk._accepts(TradeCounter.FROM_SHELF) or till_desk._accepts(&"cargo"):
		fails += 1
		print("  TILL TAKES ALL     it would charge you for your own cargo")
	if pay_desk._accepts(TradeCounter.FROM_SHELF) or not pay_desk._accepts(&"cargo"):
		fails += 1
		print("  COUNTER BUYS STOCK it would pay you for the shop's own shelf")
	till_desk.free()
	pay_desk.free()


## AN AUGMENT NEVER MOVES A PRICE (science, pick 3A).
## Why: docs/why/MarketTest.md#an-augment-never-moves-a-price
func _augmented_price() -> void:
	var lab := _place(2, 3, [&"korvan"] as Array[StringName], 5)
	lab.index = 7
	var places: Array[MapGen.MapNode] = []
	for dev in 5:
		for sec in [1, 5]:
			for berths in [[] as Array[StringName], [&"korvan"] as Array[StringName],
					[&"solari"] as Array[StringName]]:
				places.append(_place(dev, sec, berths, 1 + dev * 2))
	var checked := 0
	var plain := _part(int(ModuleData.Rarity.RARE), &"korvan", false)
	for k in Science.OFFER_SIZE:
		var part := plain.duplicate(true) as ModuleData
		if not Run.stow(part):
			fails += 1
			print("  NO ROOM       the hold would not take the part to augment")
			return
		var offer := Science.augment_offer(part, lab)
		Run.data = Science.AUGMENT_DATA
		Run.credits = Market.augment_price(lab)
		var line := Science.augment(part, offer[k] if k < offer.size() else null, lab)
		Run.take_from_hold(part)
		if line == "" or not part.augmented or part.affixes.size() != plain.affixes.size() + 1:
			fails += 1
			print("  NOT AUGMENTED the Lab refused offer %d (%s)" % [k, line])
			continue
		for n in places:
			checked += 1
			var a := [Market.ask(n, part), Market.bid(n, part), Market.melt(part)]
			var b := [Market.ask(n, plain), Market.bid(n, plain), Market.melt(plain)]
			if a != b:
				fails += 1
				print("  AUGMENT PAYS  %s with %s: ask/bid/melt %s against %s plain" % [
					part.name, part.affixes[-1].name, a, b])
	print("  augmented: %d prices with each of the 3 offered affixes, all the plain part's" % checked)
	Run.data = 0


## What a Rare Korvan weapon costs and fetches in each kind of place. One row per
## place, because the question a trade route asks is "where", not "what".
func _print_goods() -> void:
	Run.hull.perk_id = &"none"
	var m := _part(int(ModuleData.Rarity.RARE), &"korvan", false)
	print("\n  a Rare Korvan part, base %d, melts for %d anywhere" % [
		m.scrap_value, Market.melt(m)])
	print("  %-34s %5s %5s %6s" % ["place", "ask", "bid", "vs melt"])
	var rows := [
		["unclaimed rim, nobody", 0, 3, [] as Array[StringName], 1],
		["Korvan outpost (its own yard)", 1, 3, [&"korvan"] as Array[StringName], 3],
		["Solari settlement (a rival)", 2, 3, [&"solari"] as Array[StringName], 5],
		["contested city, no Korvan", 3, 4, [&"solari", &"cygnet"] as Array[StringName], 7],
		["Korvan capital (deep glut)", 4, 5, [&"korvan", &"verity"] as Array[StringName], 9],
		["lawless deep fence", 1, 1, [&"redline"] as Array[StringName], 10],
	]
	for r in rows:
		var n := _place(int(r[1]), int(r[2]), r[3], int(r[4]))
		var bid := Market.bid(n, m)
		print("  %-34s %5d %5d %+6d" % [r[0], Market.ask(n, m), bid,
			bid - Market.melt(m)])

func _print_services() -> void:
	print("\n  %-34s %6s %6s %6s" % ["place", "repair", "fuel", "exotic"])
	for dev in 5:
		var n := _place(dev, 3, [] as Array[StringName], 5)
		print("  %-34s %6.2f %6d %6d" % [
			MapGen.development_name(dev as MapGen.Development).to_lower(),
			Market.repair_rate(n), Market.refuel_price(n),
			Market.material_price(n, &"exotic")])
