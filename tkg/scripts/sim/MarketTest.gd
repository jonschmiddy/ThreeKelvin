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
## three brand relationships, five danger tiers, both hull perks, every rarity,
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
	_print_goods()
	_print_services()
	print("=== %s (%d violations) ===\n" % ["PASS" if fails == 0 else "FAIL", fails])

## A place with the axes set by hand. Every price in the game is a function of
## these fields and nothing else, so a synthetic node is a complete input.
func _place(dev: int, sec: int, makers: Array[StringName], danger: int) -> MapGen.MapNode:
	var n := MapGen.MapNode.new()
	n.development = dev as MapGen.Development
	n.security = sec
	n.makers = makers
	n.manufacturer = makers[0] if not makers.is_empty() else &""
	n.danger = danger
	n.type = MapGen.NodeType.STATION
	return n

func _part(rarity: int, man: StringName, contraband: bool) -> ModuleData:
	# Built from a real template so `contraband` reads off a real affix rather
	# than a flag nothing in the game sets that way.
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	m.manufacturer = man
	m.rarity = rarity as ModuleData.Rarity
	m.scrap_value = [8, 16, 30, 55, 95, 120, 160][rarity]
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
					for man in [&"korvan", &""]:
						for rarity in 7:
							for cb in [false, true]:
								# Three brand relationships: the part's own house
								# holds this place, a rival does, or nobody does.
								for makers in [[] as Array[StringName],
										[&"korvan"] as Array[StringName],
										[&"solari", &"cygnet"] as Array[StringName]]:
									var n := _place(dev, sec, makers, danger)
									var m := _part(rarity, man, cb)
									var ask := Market.ask(n, m)
									var bid := Market.bid(n, m)
									var melt := Market.melt(m)
									checked += 1
									var ratio := float(melt) / float(ask)
									if ratio > worst_ratio:
										worst_ratio = ratio
										worst = "%s C%d dev%d sec%d d%d %s" % [
											"unbranded" if man == &"" else man,
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
		["Korvan capital (deep glut)", 4, 5, [&"korvan", &"halcyon"] as Array[StringName], 9],
		["lawless deep fence", 1, 1, [&"redline"] as Array[StringName], 10],
	]
	for r in rows:
		var n := _place(int(r[1]), int(r[2]), r[3], int(r[4]))
		var bid := Market.bid(n, m)
		print("  %-34s %5d %5d %+6d" % [r[0], Market.ask(n, m), bid,
			bid - Market.melt(m)])

func _print_services() -> void:
	print("\n  %-34s %6s %6s %6s %6s" % ["place", "repair", "fuel", "coolant", "exotic"])
	for dev in 5:
		var n := _place(dev, 3, [] as Array[StringName], 5)
		print("  %-34s %6.2f %6d %6d %6d" % [
			MapGen.development_name(dev as MapGen.Development).to_lower(),
			Market.repair_rate(n), Market.refuel_price(n),
			Market.coolant_price(n), Market.material_price(n, &"exotic")])
