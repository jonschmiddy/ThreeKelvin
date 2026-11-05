extends Node

## THE SIM PILOT'S SCIENCE (Phase 12, plan S12):
##   godot --headless --path . -- sheet=ScienceSimTest
##
## `-- sim science=on|off|ignore` and the pilot that flies it (`Policy`):
##
##   - the flag parses, and each mode sets the world (`Run.science_off`) and
##     the pilot (`policy.science`) the way plan §6 says;
##   - with science off, seed 4242 rolls no science event anywhere (and with it
##     on, the same seed does, so the check can see one), a played run leaves
##     the board unbought and DATA at 0, and the Lab's bench is RELIC ANALYSIS
##     alone, with no step for sale;
##   - a reading's line, on built options: a full tank takes the risky line, a
##     hurt ship or a cautious pilot at long odds the careful one, and the
##     buyer's credits when the tank is at the way out (the fuel gate), when the
##     board is finished or already covered, and with science off; a
##     non-science option gets the old answer; choosing draws from no stream;
##   - at a dock: film and relics are read for DATA before the counter can buy
##     them, the cheapest step is bought first, AUGMENT puts on at most one
##     affix a visit, never takes credits under FUEL_RESERVE and leaves the
##     part's price where it was, and a finished board sells its film;
##   - a better find never replaces an augmented part while a plain one shares
##     its slot;
##   - STRIP's reactor guard (S5) counts SPARE CELLS: Bus-Fed the reactor needs
##     is refused bare and comes off with SPARE CELLS owned;
##   - five seeded runs of the sim's own loop earn DATA and buy a step, and
##     the report's `science:` lines are there (and with science off, the one
##     `science: off` line).
##
## Each key check fails with its rule taken out of Policy: `_choose_science`
## (the line rules), `lab` (no film read, no step bought), `augment`'s reserve
## and one-a-visit, `_worst_fitted`, and the off cell's `apply_science`.

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_flags()
	_off_world()
	_choices()
	_dock()
	_worst_fitted()
	_strip_spare_cells()
	_runs()
	Run.science_off = false
	h.verdict("sciencesimtest")
	get_tree().quit(h.code())

# ---------------------------------------------------------------- the fixtures

func _start(seed_n: int) -> void:
	h.seed_run(seed_n)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

func _station() -> MapGen.MapNode:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			return n
	return null

func _affix(name: String) -> AffixData:
	for a in DB.affixes:
		if a.name == name:
			return a
	return null

func _give(id: StringName, k: int) -> void:
	for i in k:
		Run.stow(MaterialData.of(MaterialTable.by_id(id)))

func _augmented() -> int:
	var k := 0
	for m in Run.installed:
		if (m as ModuleData).augmented:
			k += 1
	return k

## A reading built the way OptionTable writes one: careful, risky, the buyer.
func _reading(need: int, science := true) -> Dictionary:
	var noop := func() -> Dictionary: return {text = "x"}
	return {id = &"test_reading", tags = [&"science"] if science else [], choices = [
		{label = "careful", burns = true, reads = 1, effect = noop},
		{label = "risky", burns = true, reads = 2, check = {attr = &"hull", need = need},
			met = noop, clean = noop, partial = noop, botched = noop},
		{label = "sell", effect = noop},
	]}

# --------------------------------------------------------------------- the flag

func _flags() -> void:
	print("=== THE FLAG ===")
	var said := []
	for s in ["on", "off", "ignore", " OFF ", "maybe", ""]:
		said.append(HeadlessSim.parse_science(s))
	h._ok("science= reads on, off, ignore (any case), and nothing else (%s)" % [said],
		said == [&"on", &"off", &"ignore", &"off", &"", &""])
	var sim := HeadlessSim.new()
	var rows := []
	for mode in [&"on", &"off", &"ignore"]:
		sim.science_mode = mode
		sim.apply_science()
		rows.append([Run.science_off, sim.policy.science])
	h._ok("on flies science; off is the control cell (world and pilot); ignore keeps the world and sells every reading (%s)" % [rows],
		rows == [[false, true], [true, false], [false, false]])
	Run.science_off = false

# --------------------------------------------------------------- the off world

func _off_world() -> void:
	print("=== SCIENCE OFF ===")
	var counts := []
	for off in [true, false]:
		Run.science_off = off
		_start(4242)
		var sci := 0
		var all := 0
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if not OptionTable.ensure(n):
				continue
			for id in n.options:
				all += 1
				if OptionTable.is_science(OptionTable.by_id(id)):
					sci += 1
		counts.append([sci, all])
	h._ok("seed 4242 rolls no science event with science off (%d of %d), and some with it on (%d of %d)"
			% [counts[0][0], counts[0][1], counts[1][0], counts[1][1]],
		counts[0][0] == 0 and counts[0][1] > 0 and counts[1][0] > 0)

	Run.science_off = true
	_start(4242)
	var n := _station()
	if not h._ok("the run has a station", n != null):
		return
	var ids := []
	for r in Fabricator.available(n):
		ids.append(r.id)
	Run.data = 99
	var sells := false
	for b in DB.BRANCHES.size():
		sells = sells or Science.can_buy(b)
	var p := Policy.new()
	p.lab(n)
	h._ok("its Lab's bench is RELIC ANALYSIS alone (%s) and no step is for sale, with 99 DATA held (owned %s)"
			% [ids, Array(Run.board_owned)],
		ids == [&"analysis"] and not sells and Array(Run.board_owned) == [0, 0, 0] and Run.data == 99)

	var sim := HeadlessSim.new()
	sim.science_mode = &"off"
	sim.apply_science()
	sim.listen_data()
	sim.policy.fight_cb = sim._option_fight
	sim.seed_base = 4242
	sim._play_one(&"korvan", -1, 0)
	h._ok("a played run with science off: board unbought (%s), DATA %d, %d readings met, jumps %d"
			% [Array(Run.board_owned), Run.data, int(sim.policy.sci.met), Run.jumps],
		Array(Run.board_owned) == [0, 0, 0] and Run.data == 0 and int(sim.policy.sci.met) == 0
		and Run.jumps > 0)
	var lines := sim.science_lines()
	h._ok("its report says `science: off` and nothing else science (%s)" % " | ".join(lines),
		lines.size() == 2 and lines[0].begins_with("science: off") and lines[1].begins_with("credits: "))
	Run.science_off = false

# ------------------------------------------------------------------ the choices

func _choices() -> void:
	print("=== A READING'S LINE ===")
	Run.science_off = false
	_start(777)
	var p := Policy.new()
	var opt := _reading(1)
	var floor_n := Run.fuel_floor()
	var cost := OptionTable.science_fuel()
	h._ok("the start has a way out to keep (floor %d) and a full tank clears it (%d + %d of %d)"
			% [floor_n, floor_n, cost, Run.fuel_cap()],
		floor_n > 0 and floor_n + cost <= Run.fuel_cap())
	Run.fuel = Run.fuel_cap()
	Run.hp = Run.max_hp()
	var rng0 := Rng.state()
	var pilot0 := p.pilot.state
	var full := p._choose_line(opt)
	h._ok("a full tank and a whole hull take the risky line (%d)" % full, full == 1)
	var real := p._choose_line(OptionTable.by_id(&"the_first_look"))
	h._ok("so does the real event, The first look (%d)" % real, real == 1)

	Run.hp = int(Run.max_hp() * 0.4)
	var hurt := p._choose_line(opt)
	Run.hp = Run.max_hp()
	h._ok("under half hull, the careful line (%d)" % hurt, hurt == 0)

	p.risk_averse = true
	var cautious := p._choose_line(_reading(99))
	var cautious_ok := p._choose_line(_reading(1))
	p.risk_averse = false
	h._ok("a cautious pilot at long odds takes the careful line (%d), at good odds the risky one (%d)"
			% [cautious, cautious_ok], cautious == 0 and cautious_ok == 1)

	Run.fuel = floor_n
	var refused0 := int(p.sci.refused)
	var gated := p._choose_line(opt)
	Run.fuel = floor_n + cost
	var at_edge := p._choose_line(opt)
	Run.fuel = Run.fuel_cap()
	h._ok("fuel at the way out sells the reading (%d, counted %d); one reading over it reads (%d)"
			% [gated, int(p.sci.refused) - refused0, at_edge],
		gated == 2 and int(p.sci.refused) == refused0 + 1 and at_edge == 1)

	Run.board_owned = PackedInt32Array([3, 3, 3])
	var finished := p._choose_line(opt)
	Run.board_owned = PackedInt32Array([0, 0, 0])
	Run.data = Policy.board_left()
	var covered := p._choose_line(opt)
	Run.data = 0
	h._ok("a finished board sells (%d); so does one the DATA held already covers (%d)" % [finished, covered],
		finished == 2 and covered == 2)

	p.science = false
	var off_pilot := p._choose_line(opt)
	p.science = true
	Run.science_off = true
	var off_world := p._choose_line(opt)
	Run.science_off = false
	h._ok("science off sells it, the pilot's (%d) or the world's (%d)" % [off_pilot, off_world],
		off_pilot == 2 and off_world == 2)

	# The old rule: the first line with a check that clears the floor, else the
	# first line without one.
	var plain := p._choose_line(_reading(1, false))
	p.risk_averse = true
	var plain_cautious := p._choose_line(_reading(99, false))
	p.risk_averse = false
	Run.fuel = floor_n
	var plain_low := p._choose_line(_reading(1, false))
	Run.fuel = Run.fuel_cap()
	h._ok("a non-science option gets the old answer: the check (%d), the first plain line when cautious (%d), and the fuel gate is science's alone (%d)"
			% [plain, plain_cautious, plain_low],
		plain == 1 and plain_cautious == 0 and plain_low == 1)
	h._ok("choosing drew from no stream, the pilot's included",
		Rng.state() == rng0 and p.pilot.state == pilot0)

# ---------------------------------------------------------------------- the dock

func _dock() -> void:
	print("=== AT A DOCK ===")
	Run.science_off = false
	_start(777)
	var n := _station()
	if not h._ok("the run has a station", n != null):
		return
	Run.at = n.index
	Run.hp = Run.max_hp()
	Run.fuel = Run.fuel_cap()
	Run.credits = 200
	Run.data = 0
	_give(&"survey_film", 2)
	_give(&"relic", 1)
	var worth := {}
	for m in Run.installed:
		worth[m] = [m.scrap_value, Market.bid(n, m as ModuleData), Market.base_value(m as ModuleData)]
	var p := Policy.new()
	p.shop(n)
	h._ok("two films and a relic are read, not sold (film %d, relic %d in the hold; %d + %d DATA)"
			% [Run.material(&"survey_film"), Run.material(&"relic"), int(p.sci.data_film), int(p.sci.data_relic)],
		Run.material(&"survey_film") == 0 and Run.material(&"relic") == 0
		and int(p.sci.data_film) == 12 and int(p.sci.data_relic) == 15)
	h._ok("27 DATA buys each branch's first step at 6 (owned %s), 9 left over" % [Array(Run.board_owned)],
		Array(Run.board_owned) == [1, 1, 1])
	var price := Market.augment_price(n)
	var moved := []
	for m in Run.installed:
		var now := [m.scrap_value, Market.bid(n, m as ModuleData), Market.base_value(m as ModuleData)]
		if now != worth[m]:
			moved.append(m.name)
	h._ok("with no step affordable the leftover goes on one part (augmented %d, DATA %d, credits %d = 200 - %d), and no part's price moved %s"
			% [_augmented(), Run.data, Run.credits, price, moved],
		_augmented() == 1 and Run.data == 4 and Run.credits == 200 - price and moved.is_empty()
		and int(p.sci.augments) == 1 and int(p.spend.augment) == price)

	# The reserve: one credit short of it, nothing; exactly at it, the augment.
	Run.data = 9
	Run.credits = Policy.FUEL_RESERVE + price - 1
	p.shop(n)
	var short := _augmented()
	Run.credits = Policy.FUEL_RESERVE + price
	p.shop(n)
	h._ok("AUGMENT never takes credits under FUEL_RESERVE: refused one short (%d augmented), taken at it (%d, credits %d)"
			% [short, _augmented(), Run.credits],
		short == 1 and _augmented() == 2 and Run.credits == Policy.FUEL_RESERVE)

	# The cheapest step first: FRAME's next is 10, the others' 6.
	Run.board_owned = PackedInt32Array([1, 0, 0])
	Run.data = 10
	var want := Policy.cheapest_step()
	p.research(n)
	h._ok("with 10 DATA it buys a 6 (branch %d) over FRAME's 10 (owned %s, DATA %d)"
			% [want, Array(Run.board_owned), Run.data],
		want != 0 and Run.board_owned[0] == 1 and Run.board_owned[want] == 1 and Run.data == 4)

	# A finished board: the film goes to the counter, and one augment a visit.
	Run.board_owned = PackedInt32Array([3, 3, 3])
	Run.data = 30
	Run.credits = 500
	var before := _augmented()
	var film := int(p.sci.data_film)
	_give(&"survey_film", 1)
	p.shop(n)
	h._ok("a finished board sells its film (%d in the hold, DATA from film still %d) and augments one part a visit (%d to %d, DATA %d)"
			% [Run.material(&"survey_film"), int(p.sci.data_film), before, _augmented(), Run.data],
		Run.material(&"survey_film") == 0 and int(p.sci.data_film) == film
		and _augmented() == mini(before + 1, Run.installed.size()) and Run.data == 25)

# ------------------------------------------------------------------ the cargo

func _worst_fitted() -> void:
	print("=== AN AUGMENTED PART STAYS ===")
	_start(777)
	var slot: ModuleData.Slot = ModuleData.Slot.WEAPON
	var found := false
	for m in Run.installed:
		var k := 0
		for x in Run.installed:
			if x.slot == m.slot:
				k += 1
		if k >= 2:
			slot = m.slot
			found = true
			break
	if not h._ok("the ship has a slot with two parts fitted", found):
		return
	var cheap: ModuleData = Policy._worst_fitted(slot)
	cheap.augmented = true
	var then: ModuleData = Policy._worst_fitted(slot)
	h._ok("the cheapest part in the slot (%s) is the one a find replaces, until it is augmented (then %s)"
			% [cheap.name, then.name if then != null else "none"],
		then != null and then != cheap and not then.augmented)
	var alone := 0
	for x in Run.installed:
		if x.slot == cheap.slot:
			x.augmented = true
			alone += 1
	var all_aug: ModuleData = Policy._worst_fitted(slot)
	h._ok("with every part in the slot augmented, the cheapest is still the one (%s)" % all_aug.name,
		all_aug == cheap)
	for x in Run.installed:
		x.augmented = false

# ---------------------------------------------------------------- STRIP's guard

## S5's reactor guard asked of `Run.power_cap()`, with SPARE CELLS owned.
func _strip_spare_cells() -> void:
	print("=== STRIP WITH SPARE CELLS ===")
	_start(777)
	var lab := _station()
	if not h._ok("the run has a station", lab != null):
		return
	var m: ModuleData = Run.installed[0]
	var keep := m.affixes
	var bus := _affix("Bus-Fed")
	m.affixes = [bus] as Array[AffixData]
	Run.data = 50
	Run.credits = 1000
	var hull_reactor := Run.hull.reactor
	# Squeeze the reactor so the fitted parts need Bus-Fed's level: without it
	# the cap is 1 to 3 cells short, which SPARE CELLS' 3 covers.
	Run.hull.reactor -= Run.reactor_level() - int(ceil(float(Run.power_draw()) / Run.CELLS_PER_LEVEL))
	var bare := Science.can_strip(m, bus, lab)
	Run.routines_granted = [&"spare_cells"] as Array[StringName]
	var spare := Science.can_strip(m, bus, lab)
	var line := Science.strip(m, bus, lab)
	h._ok("Bus-Fed the reactor needs: refused bare (%s), off with SPARE CELLS owned (%s), and the ship still powers (draw %d, cap %d)"
			% [bare, spare, Run.power_draw(), Run.power_cap()],
		not bare and spare and line != "" and m.affixes.is_empty()
		and Run.power_draw() <= Run.power_cap())
	Run.routines_granted = [] as Array[StringName]
	Run.hull.reactor = hull_reactor
	m.affixes = keep
	Sig.ship_changed.emit()

# ----------------------------------------------------------------------- the runs

func _runs() -> void:
	print("=== FIVE RUNS ===")
	Run.science_off = false
	var sim := HeadlessSim.new()
	sim.science_mode = &"on"
	sim.apply_science()
	sim.listen_data()
	sim.policy.fight_cb = sim._option_fight
	sim.seed_base = h.seed_run(777)
	for i in 5:
		sim._play_one(&"korvan", -1, i)
		print("  seed %d: DATA in %d, steps %d, readings %d, jumps %d, %s" % [
			sim.seed_base + i, sim.sc_data[i], sim.sc_steps[i], sim.sc_met[i], Run.jumps,
			"won" if Run.won else Run.death_reason.substr(0, 30)])
	var data := 0
	var steps := 0
	for i in 5:
		data += int(sim.sc_data[i])
		steps += int(sim.sc_steps[i])
	h._ok("five seeded runs earn DATA (%d) and buy steps (%d)" % [data, steps], data > 0 and steps >= 1)
	var lines := sim.science_lines()
	var heads := []
	for l in lines:
		heads.append(l.substr(0, l.find(" ")))
	h._ok("the report's lines are there (%s)" % [heads],
		heads == ["science:", "science:", "routines:", "augments:", "strand:", "credits:"]
		and lines[0].begins_with("science: DATA ") and not lines[0].begins_with("science: DATA 0.0 a run"))
	for l in lines:
		print("  | " + l)
