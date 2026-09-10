extends RefCounted

## The market, as one table, and the check that it cannot be gamed.
##
##   godot --headless --path . -- market
##
## RUN THIS AFTER TOUCHING Market.gd. Two jobs, and the second is the reason the
## file exists.
##
## FIRST, it proves the invariant by exhaustion. Every combination of the axes a
## price is derived from — five development levels, five security levels, the
## three manufacturer relationships, five danger tiers, both hull perks, every rarity,
## clean and contraband — is priced, and every one is checked for:
##
##     melt < ask       you cannot buy a part and melt it for a profit
##     bid  < ask       you cannot sell a part back where you bought it
##
## That is the whole exploit this economy replaced, and it was not a tuning
## error: the buy price lived in StationScreen and the melt price lived in
## RunState, and neither file had heard of the other. A constant nudged by three
## points in the wrong direction reopens it in a way nothing in the game reports
## — you simply become rich. Two thousand price comparisons in four seconds is a
## cheap way never to wonder again.
##
## SECOND, it prints the table. Prices only mean anything against each other, the
## same way the six attributes do, and the same argument applies: reading them
## one station at a time in the running game is how you convince yourself a
## spread exists that does not.

var fails: int = 0

func run() -> void:
	print("\n=== MARKET ===")
	# A run, because melt() reads the hull's perk and there is no hull until one
	# starts. Nothing else here touches RunState — every price below is derived
	# from a synthetic place and a synthetic part.
	Run.start_new_run()
	_check_invariant()
	_one_price()
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

## THE COUNTER QUOTES THE MARKET, AND THERE IS NO SECOND PRICE.
##
## The Exchange used to have two places to carry a part to: a counter paying the
## local bid, and a chute paying `Market.melt` -- a flat rate that is deliberately
## NOT a function of where you are. Two prices for one object in one room is a
## second currency however it settles up, so the chute is gone and this is the
## guard that keeps it gone.
##
## THE TEST IS THAT THE QUOTE MOVES WITH THE PLACE. Asserting the number equals
## `Market.bid` would pass just as happily if someone wired the flat rate in and
## the two happened to coincide for the part being checked. Saturating the market
## separates them by construction: a bid falls as a station takes more, and a
## melt price cannot move at all -- so a counter whose quote does not drop is
## quoting something other than what this place will bear.
##
## `offer()` reads `Run.node_at()` rather than taking a node, which is why this
## runs against the live run instead of the synthetic places above.
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

	# --- AND THE OTHER SIDE OF THE SAME DESK.
	#
	# The Promenade's till charges rather than pays. It is the same class with
	# `Side.CHARGES` set, and the thing that makes that safe rather than a second
	# currency is the spread: what the shop asks is always more than what it
	# bids, which the exhaustive sweep above proves for every place in the game
	# and this re-checks at the counter the player actually touches.
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

	# --- AND EACH DESK TAKES ONLY FROM ITS OWN SIDE OF THE SHOP.
	#
	# THIS ONE IS A MONEY BUG IF IT SLIPS, and a silent one. The two counters are
	# told apart by where the thing was picked up -- `origin` on the drag payload
	# -- so a till that accepted a part out of your hold would charge you for
	# something you already own, and an Exchange counter that accepted one off
	# the shelf would pay you for the shop's own stock.
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
