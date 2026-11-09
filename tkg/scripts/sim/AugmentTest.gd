extends Node

## The Lab's services (science, plan S5) with no screen in the way: `-- sheet=AugmentTest`.
## Why: docs/why/AugmentTest.md#the-labs-services

var _fails := 0
var _lines: Array[String] = []


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	Rng.forced = 777
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Sig.log_line.connect(func(t: String, _k: StringName) -> void: _lines.append(t))
	print("\n=== AUGMENT ===")
	_prices()
	_offer()
	_augment_fitted()
	_augment_hold()
	_strip_contraband()
	_strip_reactor()
	_strip_keeps_offer()
	_lab_only_at_stations()
	_board()
	_bench()
	_science_off()
	print("augmenttest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)

# ---------------------------------------------------------------- the fixtures

## Every station on the map, the Labs the offer is drawn at.
func _stations() -> Array[MapGen.MapNode]:
	var out: Array[MapGen.MapNode] = []
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.STATION:
			out.append(n)
	return out

func _affix(name: String) -> AffixData:
	for a in DB.affixes:
		if a.name == name:
			return a
	return null

func _names(list: Array) -> Array[String]:
	var out: Array[String] = []
	for a in list:
		out.append((a as AffixData).name)
	return out

## A Lab whose offer for `m` holds `want`, or null.
func _lab_offering(m: ModuleData, want: String) -> MapGen.MapNode:
	for n in _stations():
		if _names(Science.augment_offer(m, n)).has(want):
			return n
	return null

## What the cards a part grants read, in order: name, grade and rules line.
func _cards(m: ModuleData) -> Array[String]:
	var out: Array[String] = []
	for c in m.resolved_cards():
		out.append("%s|%d|%s" % [c.name, c.rarity, c.describe()])
	return out

func _purse(data: int, credits: int) -> void:
	Run.data = data
	Run.credits = credits

# -------------------------------------------------------------------- the tests

func _prices() -> void:
	var aug: Array[int] = []
	var strip: Array[int] = []
	for dev in 5:
		var n := MapGen.MapNode.new()
		n.development = dev as MapGen.Development
		aug.append(Market.augment_price(n))
		strip.append(Market.strip_price(n))
	_ok("AUGMENT is 5 DATA + %s credits (22/20/18/16/15 wanted)" % [aug],
		aug == [22, 20, 18, 16, 15] and Science.AUGMENT_DATA == 5)
	_ok("STRIP is 2 DATA + %s credits (11/10/9/8/7 wanted)" % [strip],
		strip == [11, 10, 9, 8, 7] and Science.STRIP_DATA == 2)
	var n0: MapGen.MapNode = _stations()[0]
	var c := Science.augment_cost(n0)
	_ok("augment_cost reads {data 5, credits %d} (%s)" % [Market.augment_price(n0), c],
		int(c.data) == 5 and int(c.credits) == Market.augment_price(n0))

func _offer() -> void:
	var labs := _stations()
	var bad: Array[String] = []
	var short := 0
	var seen := {}
	var offers := 0
	for id in DB.modules:
		var m := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
		for rolled in [[], ["Reinforced"], ["Cryo-Lined", "Gyro-Trimmed"],
				["Deregulated", "Bus-Fed", "Lightened"]]:
			var list: Array[AffixData] = []
			for nm in rolled:
				list.append(_affix(nm))
			m.affixes = list
			for n in labs:
				var o := _names(Science.augment_offer(m, n))
				offers += 1
				if o.size() != 3:
					short += 1
				for nm in o:
					seen[nm] = int(seen.get(nm, 0)) + 1
					if nm == "Cryo-Lined" or nm == "Deregulated" or (rolled as Array).has(nm):
						bad.append("%s on %s %s" % [nm, id, rolled])
	_ok("%d offers over %d parts and %d Labs: never Cryo-Lined, Deregulated or one the part has (%s)"
			% [offers, DB.modules.size(), labs.size(), "none" if bad.is_empty() else ", ".join(bad.slice(0, 4))],
		bad.is_empty() and offers > 100)
	_ok("every offer is three (%d short)" % short, short == 0)
	var lab_all := true
	for nm in DB.LAB_AFFIXES:
		lab_all = lab_all and int(seen.get(String(nm), 0)) > 0
	_ok("all eight of the Lab's affixes are offered somewhere (%s)" % [seen], lab_all and seen.size() == 8)
	# AT ITS LOOT WEIGHT (0.35): well under the others' mean, not just under one.
	var rest := 0.0
	for nm in seen:
		if nm != "Bus-Fed":
			rest += float(seen[nm]) / 7.0
	_ok("Bus-Fed is offered at its weight: %d against the others' mean %.0f (under 0.6 of it)"
			% [int(seen.get("Bus-Fed", 0)), rest],
		float(seen.get("Bus-Fed", 0)) < 0.6 * rest)

	# THE SAME THREE ON REOPENING, and drawing it moves no stream.
	var m: ModuleData = Run.installed[0]
	var n: MapGen.MapNode = labs[0]
	var before := Rng.state()
	var a := _names(Science.augment_offer(m, n))
	var b := _names(Science.augment_offer(m, n))
	_ok("the same three when the Lab is opened again (%s, then %s)" % [a, b], a == b)
	_ok("drawing an offer moves no stream (Rng.state() unchanged)", Rng.state() == before)
	var other := 0
	for l in labs:
		if _names(Science.augment_offer(m, l)) != a:
			other += 1
	_ok("another Lab may offer another three (%d of %d differ)" % [other, labs.size() - 1], other > 0)

func _augment_fitted() -> void:
	# A fitted part with no Reinforced of its own, on a full ship.
	var m: ModuleData = null
	for x in Run.installed:
		if not _names(x.affixes).has("Reinforced"):
			m = x
			break
	if not _ok("a fitted part without Reinforced (%s)" % (m.name if m != null else "none"), m != null):
		return
	var lab := _lab_offering(m, "Reinforced")
	if not _ok("a Lab offers it Reinforced", lab != null):
		return
	Sig.ship_changed.emit()
	Run.hp = Run.max_hp()
	Sig.ship_changed.emit()
	var hp0 := Run.hp
	var max0 := Run.max_hp()
	var scrap0 := m.scrap_value
	var quote0 := TradeCounter.offer(m)
	var ask0 := TradeCounter.offer(m, TradeCounter.Side.CHARGES)
	var cards0 := _cards(m)
	var count0 := m.affixes.size()
	var tmpl0 := _names((DB.modules[m.id] as ModuleData).affixes)
	var price := Market.augment_price(lab)

	# Short on either half: refused, nothing moves.
	_purse(4, 1000)
	_ok("4 DATA: refused", not Science.can_augment(m, lab)
		and Science.augment(m, _affix("Reinforced"), lab) == "" and Run.data == 4 and Run.credits == 1000)
	_purse(50, price - 1)
	_ok("%d credits against %d: refused" % [price - 1, price], not Science.can_augment(m, lab)
		and Science.augment(m, _affix("Reinforced"), lab) == "" and Run.data == 50)
	_purse(50, 1000)
	_ok("an affix not in the offer (Deregulated) is refused",
		Science.augment(m, _affix("Deregulated"), lab) == "" and not m.augmented and Run.data == 50)
	var stranger := (DB.modules[m.id] as ModuleData).duplicate(true) as ModuleData
	_ok("a part that is not yours (not fitted, not in the hold) is refused",
		not Science.can_augment(stranger, lab))

	_lines.clear()
	var line := Science.augment(m, _affix("Reinforced"), lab)
	_ok("AUGMENT Reinforced: '%s'" % line, line != "" and _lines.has(line))
	_ok("  it took 5 DATA and %d credits (50 to %d, 1000 to %d)" % [price, Run.data, Run.credits],
		Run.data == 45 and Run.credits == 1000 - price)
	_ok("  one affix added (%d to %d), the last is Reinforced, the part is AUGMENTED"
			% [count0, m.affixes.size()],
		m.affixes.size() == count0 + 1 and m.affixes[-1].name == "Reinforced" and m.augmented)
	var tmpl1 := _names((DB.modules[m.id] as ModuleData).affixes)
	_ok("  the template's affixes are untouched (%s, then %s)" % [tmpl0, tmpl1], tmpl0 == tmpl1)
	_ok("  scrap value %d to %d, the counter pays %d to %d and asks %d to %d"
			% [scrap0, m.scrap_value, quote0, TradeCounter.offer(m),
			ask0, TradeCounter.offer(m, TradeCounter.Side.CHARGES)],
		m.scrap_value == scrap0 and TradeCounter.offer(m) == quote0
		and TradeCounter.offer(m, TradeCounter.Side.CHARGES) == ask0)
	_ok("  its cards read the same (%d cards)" % cards0.size(), _cards(m) == cards0 and not cards0.is_empty())
	_ok("  fitted on a full ship: %d/%d to %d/%d" % [hp0, max0, Run.hp, Run.max_hp()],
		Run.max_hp() == max0 + 7 and Run.hp == hp0 + 7)

	# ONCE PER PART, EVER.
	_purse(50, 1000)
	var again: AffixData = Science.augment_offer(m, lab)[0]
	_ok("a second AUGMENT is refused (nothing spent)", not Science.can_augment(m, lab)
		and Science.augment(m, again, lab) == "" and Run.data == 50 and Run.credits == 1000)

	# STRIP Reinforced off it: back to where it was, the mark kept.
	var sp := Market.strip_price(lab)
	_lines.clear()
	var off := Science.strip(m, _affix("Reinforced"), lab)
	_ok("STRIP Reinforced: '%s'" % off, off != "" and _lines.has(off))
	_ok("  it took 2 DATA and %d credits" % sp, Run.data == 48 and Run.credits == 1000 - sp)
	_ok("  %d/%d again, %d affixes, still AUGMENTED" % [Run.hp, Run.max_hp(), m.affixes.size()],
		Run.hp == hp0 and Run.max_hp() == max0 and m.affixes.size() == count0 and m.augmented)
	_ok("  and still refused a second AUGMENT", not Science.can_augment(m, lab))
	_ok("  STRIP of an affix it does not have is refused",
		Science.strip(m, _affix("Reinforced"), lab) == "" and Run.data == 48)

func _augment_hold() -> void:
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	m.affixes = [] as Array[AffixData]
	if not _ok("a part in the hold", Run.stow(m) and Run.cargo.has(m)):
		return
	var lab := _lab_offering(m, "Reinforced")
	if not _ok("a Lab offers it Reinforced", lab != null):
		return
	Run.hp = Run.max_hp() - 3
	Sig.ship_changed.emit()
	var hp0 := Run.hp
	var max0 := Run.max_hp()
	_purse(10, 100)
	var line := Science.augment(m, _affix("Reinforced"), lab)
	_ok("AUGMENT Reinforced in the hold: max hull %d to %d, hull %d to %d"
			% [max0, Run.max_hp(), hp0, Run.hp],
		line != "" and m.augmented and Run.max_hp() == max0 and Run.hp == hp0)
	Run.take_from_hold(m)

func _strip_contraband() -> void:
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	m.affixes = [_affix("Deregulated"), _affix("Gyro-Trimmed")] as Array[AffixData]
	if not _ok("a Deregulated part in the hold, contraband", Run.stow(m) and m.contraband):
		return
	var lab: MapGen.MapNode = _stations()[0]
	_purse(1, 1000)
	_ok("1 DATA: STRIP refused", Science.strip(m, _affix("Deregulated"), lab) == "" and m.contraband)
	_purse(2, Market.strip_price(lab) - 1)
	_ok("a credit short: STRIP refused", Science.strip(m, _affix("Deregulated"), lab) == "" and m.contraband)
	_purse(2, Market.strip_price(lab))
	var line := Science.strip(m, _affix("Deregulated"), lab)
	_ok("STRIP Deregulated: clean (%s), Gyro-Trimmed kept, DATA %d, credits %d, not marked"
			% [_names(m.affixes), Run.data, Run.credits],
		line != "" and not m.contraband and _names(m.affixes) == ["Gyro-Trimmed"]
		and Run.data == 0 and Run.credits == 0 and not m.augmented)
	_purse(5, 100)
	_ok("  STRIP never marks a part: it can still be augmented", Science.can_augment(m, lab))
	Run.take_from_hold(m)

## A reactor pip off a fitted part that the ship's parts are drawing on.
func _strip_reactor() -> void:
	var m: ModuleData = Run.installed[0]
	var keep := m.affixes
	m.affixes = [_affix("Bus-Fed")] as Array[AffixData]
	var lab: MapGen.MapNode = _stations()[0]
	_purse(50, 1000)
	# Squeeze the reactor so the fitted parts need that pip.
	var hull_reactor := Run.hull.reactor
	var level := Run.reactor_level()
	Run.hull.reactor -= level - int(ceil(float(Run.power_draw()) / Run.CELLS_PER_LEVEL))
	# The cap without it, as the ship reads it (`Run.power_cap()` with the affix
	# really off), never a copy of the cap's arithmetic: SPARE CELLS (S3) raises
	# that cap, and a copy here would go on agreeing with a refusal that is wrong.
	m.affixes = [] as Array[AffixData]
	var cap_without := Run.power_cap()
	m.affixes = [_affix("Bus-Fed")] as Array[AffixData]
	var needs := Run.power_draw() > cap_without
	_ok("STRIP Bus-Fed off a fitted part the reactor needs (draw %d, cap %d, %d without it) is refused"
			% [Run.power_draw(), Run.power_cap(), cap_without],
		needs and not Science.can_strip(m, _affix("Bus-Fed"), lab)
		and Science.strip(m, _affix("Bus-Fed"), lab) == "" and Run.data == 50)
	Run.hull.reactor = hull_reactor
	_ok("  with the reactor to spare it comes off",
		Science.strip(m, _affix("Bus-Fed"), lab) != "" and m.affixes.is_empty())
	m.affixes = keep
	Sig.ship_changed.emit()

## STRIP BUYS NO FRESH OFFER (open call 11, fixed per part per station). The
## offer is not keyed to the affixes the part has, so taking a rolled affix off
## can only let that one affix back in; every other Lab's three stay put.
func _strip_keeps_offer() -> void:
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	m.affixes = [_affix("Gyro-Trimmed"), _affix("Wide-Banded"), _affix("Lightened")] as Array[AffixData]
	if not _ok("a part with three rolled affixes in the hold", Run.stow(m)):
		return
	var labs := _stations()
	var before: Array = []
	for n in labs:
		before.append(_names(Science.augment_offer(m, n)))
	_purse(2, 1000)
	var line := Science.strip(m, _affix("Wide-Banded"), labs[0])
	var moved: Array[String] = []
	var short := 0
	for k in labs.size():
		var now := _names(Science.augment_offer(m, labs[k]))
		if now.size() != 3:
			short += 1
		for nm in now:
			if not (before[k] as Array).has(nm) and nm != "Wide-Banded":
				moved.append("%s at Lab %d" % [nm, labs[k].index])
	_ok("STRIP Wide-Banded rerolls no Lab's offer: only Wide-Banded may come back in, at %d Labs (%s)"
			% [labs.size(), "none new" if moved.is_empty() else ", ".join(moved.slice(0, 4))],
		line != "" and moved.is_empty() and short == 0)
	Run.take_from_hold(m)

## THE LAB IS ABOARD A STATION. The start, a pulsar or an empty system has none,
## so a caller holding one of those nodes (a pilot, a hint) can buy nothing.
func _lab_only_at_stations() -> void:
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	m.affixes = [_affix("Reinforced")] as Array[AffixData]
	if not _ok("a part in the hold for the Lab", Run.stow(m)):
		return
	_purse(100, 1000)
	var away: Array[String] = []
	var tried := 0
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.STATION:
			continue
		tried += 1
		var offer := Science.augment_offer(m, n)
		if Science.lab_here(n) or Science.can_augment(m, n) or Science.can_strip(m, m.affixes[0], n) 				or (not offer.is_empty() and Science.augment(m, offer[0], n) != "") 				or Science.strip(m, m.affixes[0], n) != "":
			away.append("%s %d" % [MapGen.NodeType.keys()[n.type], n.index])
	_ok("no Lab at %d places that are not stations (%s), nothing spent" % [tried,
			"none served" if away.is_empty() else ", ".join(away.slice(0, 4))],
		tried > 0 and away.is_empty() and Run.data == 100 and Run.credits == 1000 and not m.augmented)
	_ok("  the same part at a station can be augmented", Science.can_augment(m, _stations()[0]))
	Run.take_from_hold(m)

func _board() -> void:
	Run.board_owned = PackedInt32Array([0, 0, 0])
	var st := Science.board_state()
	var shape := st.size() == 3
	for b in st.size():
		shape = shape and (st[b] as Array).size() == 3 and st[b][0].state == &"next" \
			and st[b][1].state == &"locked" and st[b][2].state == &"locked" \
			and st[b][0].id == Run.board[b * 3] and [st[b][0].price, st[b][1].price, st[b][2].price] == [6, 10, 15]
	_ok("a fresh board: each branch next, locked, locked at 6, 10, 15", shape)
	_purse(5, 1000)
	_ok("5 DATA: FRAME's first step is refused, nothing spent",
		not Science.can_buy(0) and Science.buy(0) == "" and Run.data == 5 and Run.board_owned[0] == 0)
	_purse(31, 0)
	var paid: Array[int] = []
	for k in 3:
		var was := Run.data
		var want: StringName = Run.board[k]
		_lines.clear()
		var line := Science.buy(0)
		paid.append(was - Run.data)
		_ok("  FRAME step %d: %s for %d DATA ('%s', logged once)" % [k + 1, DB.routines[want].name, was - Run.data, line],
			line != "" and _lines.count(line) == 1 and Run.has_routine(want) and Run.board_owned[0] == k + 1)
	_ok("FRAME bought in order at %s, 0 DATA left" % [paid], paid == [6, 10, 15] and Run.data == 0)
	_ok("a finished branch sells nothing", not Science.can_buy(0) and Science.buy(0) == "" and Run.data == 0)
	st = Science.board_state()
	_ok("the board reads FRAME owned x3, CORE next",
		st[0].all(func(c: Dictionary) -> bool: return c.state == &"owned") and st[1][0].state == &"next")
	_purse(9, 0)
	Science.buy(1)
	_ok("CORE at 9 DATA: one step, 3 left; the 10 is refused and DATA is still 3",
		Run.board_owned[1] == 1 and Run.data == 3 and Science.buy(1) == "" and Run.data == 3)
	_ok("DRIVE's 2nd step cannot be bought before its 1st (owned %s)" % [Run.board_owned],
		Run.next_step(2) == Run.board[6] and Run.board_owned[2] == 0)
	Run.board_owned = PackedInt32Array([0, 0, 0])
	Sig.ship_changed.emit()

func _bench() -> void:
	var n: MapGen.MapNode = null
	for s in _stations():
		if int(s.development) == 0:
			n = s
	if n == null:
		n = _stations()[0]
	var dev := int(n.development)
	var by := {}
	for r in Fabricator.available(n):
		by[r.id] = r
	_ok("a dev %d Lab's bench has DEVELOP FILM and READ FOR DATA (%s)" % [dev, by.keys()],
		by.has(&"develop") and by.has(&"read"))
	if not (by.has(&"develop") and by.has(&"read")):
		return
	var dvl: Dictionary = by[&"develop"]
	var rd: Dictionary = by[&"read"]
	_ok("both cost 0 credits (%d, %d)" % [Fabricator.price(n, dvl), Fabricator.price(n, rd)],
		Fabricator.price(n, dvl) == 0 and Fabricator.price(n, rd) == 0)
	_ok("DEVELOP's bill reads '%s'" % Fabricator.cost_line(n, dvl),
		Fabricator.cost_line(n, dvl) == "1 survey film → 6 DATA")
	_ok("READ's bill reads '%s'" % Fabricator.cost_line(n, rd),
		Fabricator.cost_line(n, rd) == "1 relic → 15 DATA")
	_ok("RELIC ANALYSIS still prices in credits ('%s')" % Fabricator.cost_line(n, by[&"analysis"]),
		Fabricator.cost_line(n, by[&"analysis"]).ends_with("credits"))
	_purse(0, 0)
	_ok("no film: DEVELOP refused", not Fabricator.can_make(n, dvl) and Fabricator.make(n, dvl) == "")
	Run.stow(MaterialData.of(MaterialTable.by_id(&"survey_film")))
	Run.stow(MaterialData.of(MaterialTable.by_id(&"relic")))
	var line := Fabricator.make(n, dvl)
	_ok("DEVELOP with 0 credits pays 6 DATA ('%s'), the film used" % line,
		line != "" and Run.data == 6 and Run.credits == 0 and Run.material(&"survey_film") == 0)
	line = Fabricator.make(n, rd)
	_ok("READ with 0 credits pays 15 DATA ('%s'), the relic used" % line,
		line != "" and Run.data == 21 and Run.credits == 0 and Run.material(&"relic") == 0)

func _science_off() -> void:
	var n: MapGen.MapNode = _stations()[0]
	var m := (DB.modules[&"kh20"] as ModuleData).duplicate(true) as ModuleData
	m.affixes = [_affix("Gyro-Trimmed")] as Array[AffixData]
	Run.stow(m)
	_purse(100, 1000)
	Run.board_owned = PackedInt32Array([0, 0, 0])
	Run.stow(MaterialData.of(MaterialTable.by_id(&"survey_film")))
	Run.science_off = true
	var kinds: Array[String] = []
	for r in Fabricator.available(n):
		kinds.append(String(r.kind))
	var offer := Science.augment_offer(m, n)
	_ok("science off: no board step", not Science.can_buy(0) and Science.buy(0) == "")
	_ok("science off: no AUGMENT", not Science.can_augment(m, n)
		and Science.augment(m, offer[0], n) == "" and not m.augmented)
	_ok("science off: no STRIP", not Science.can_strip(m, m.affixes[0], n)
		and Science.strip(m, m.affixes[0], n) == "")
	_ok("science off: the bench has no DATA recipe (%s)" % [kinds], not kinds.has("data"))
	var dvl: Dictionary = DB.RECIPES.filter(func(r: Dictionary) -> bool: return r.id == &"develop")[0]
	_ok("science off: DEVELOP cannot be made", not Fabricator.can_make(n, dvl) and Fabricator.make(n, dvl) == "")
	_ok("science off: nothing spent (100 DATA, 1000 credits, %d affix)" % m.affixes.size(),
		Run.data == 100 and Run.credits == 1000 and m.affixes.size() == 1 and Run.board_owned[0] == 0)
	Run.science_off = false
