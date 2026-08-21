extends RefCounted

## The whole contract loop, flown headless:
##   godot --headless --path . -- contracttest
##
## Signing, reaching, killing, docking hot, being paid, and the one thing that
## can go quietly and expensively wrong — standing feeding back into `Market` and
## reopening the buy-and-melt hole that file exists to close.
##
## That last check is the reason this test is not optional. `-- market` proves
## the invariant at standing zero, which is the only standing it has ever been
## able to reach; every price in the game is fine until a player delivers four
## contracts to one house.

var _fails: int = 0


func run() -> void:
	Rng.reseed(31337, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	_boards()
	_fetch()
	_hunt()
	_heat()
	_standing()
	_salvage_hush()

	print("")
	print("contracttest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))


## A board belongs to the place, not to the visit.
func _boards() -> void:
	var station := _find(MapGen.NodeType.STATION)
	if not _ok("the galaxy holds a station", station >= 0):
		return
	var n: MapGen.MapNode = Run.map[station]
	var a := Contracts.board(n)
	var b := Contracts.board(n)
	_ok("a station posts the same board twice", _same(a, b))
	# Not every station has a house behind it, so an empty board is legal. What
	# is not legal is a board with work on it that nobody is paying for.
	var housed := true
	for c in a:
		if (c as ContractData).house == &"" or (c as ContractData).pay <= 0:
			housed = false
	_ok("and every offer on it has a house and a price", housed)
	# Somewhere in a 150-system galaxy there is work, or the feature does not
	# exist for most runs.
	var boards := 0
	for other in Run.map:
		if not Contracts.board(other as MapGen.MapNode).is_empty():
			boards += 1
	_ok("and enough stations carry one to matter", boards >= 3)
	print("  %d of %d systems are posting work" % [boards, Run.map.size()])


func _fetch() -> void:
	var job := _make(ContractData.Kind.FETCH)
	if not _ok("a fetch contract can be found", job != null):
		return
	var mine := Run.take_contract(job)
	_ok("signing puts it in the ledger", Run.contracts.has(mine))
	_ok("and signing it twice is refused", Run.holds_contract(job))

	var before := Run.credits
	# Somewhere else entirely: the contract must not close for arriving anywhere.
	Run.reach_contract_target(_other_than(mine.at))
	_ok("arriving somewhere else does nothing",
		mine.state == ContractData.State.TAKEN)

	Run.reach_contract_target(mine.at)
	_ok("arriving at the target recovers it",
		mine.state == ContractData.State.READY)
	# THE HOLD IS NOT TOUCHED. A recovered item is named and not carried — a
	# contract that can be soft-locked by a full hold, or completed and then
	# accidentally scrapped, is a bug wearing a decision's clothes.
	_ok("and does not put anything in the hold", Run.cargo.is_empty())

	var berth := _berth(mine.house)
	if not _ok("the galaxy holds one of their berths", berth >= 0):
		return
	var n: MapGen.MapNode = Run.map[berth]
	_ok("which is where it can be delivered",
		Run.deliverable_at(n).has(mine))
	Run.deliver_contract(mine)
	_ok("delivering pays", Run.credits == before + mine.pay)
	_ok("and closes it", mine.state == ContractData.State.CLOSED)
	_ok("and raises standing", Run.standing_with(mine.house) > 0)
	# Paid once, however many times the button is pressed.
	var after := Run.credits
	Run.deliver_contract(mine)
	_ok("and cannot be delivered twice", Run.credits == after)


func _hunt() -> void:
	var job := _make(ContractData.Kind.HUNT)
	if not _ok("a hunt contract can be found", job != null):
		return
	var mine := Run.take_contract(job)
	Run.reach_contract_target(mine.at)
	_ok("a hunt does not close by arriving",
		mine.state == ContractData.State.TAKEN)
	Run.clear_contract_target(mine.at)
	_ok("it closes by winning there", mine.state == ContractData.State.READY)


func _heat() -> void:
	var job := _make(ContractData.Kind.HEAT)
	if not _ok("a heat contract can be found", job != null):
		return
	var mine := Run.take_contract(job)
	var berth := _berth(mine.house)
	if berth < 0:
		return
	var n: MapGen.MapNode = Run.map[berth]

	Run.heat = maxi(0, mine.amount - 1)
	_ok("docking one heat short does not close it",
		Run.heat_deliverable_at(n).is_empty())

	Run.heat = mine.amount + 2
	_ok("docking hot enough does", Run.heat_deliverable_at(n).has(mine))
	var before := Run.credits
	Run.deliver_contract(mine)
	_ok("and it is paid", Run.credits == before + mine.pay)
	# THE HEAT IS SPENT. This is the only contract that costs the player
	# something at the counter, and it is the whole reason the kind exists —
	# arriving hot means having chosen not to cool down, which is the ambush
	# layer being offered to the player rather than used against them.
	_ok("and the heat is gone", Run.heat == 2)


## The check `-- market` cannot make, because standing is always zero there.
func _standing() -> void:
	# A station with a DOMINANT house, not just any station — standing is read
	# off `n.manufacturer` and an unbranded desk gives no bonus to check. The
	# first search bailed out silently on exactly that, which is a skipped test
	# wearing a passing test's clothes.
	var n: MapGen.MapNode = null
	var probe: ModuleData = null
	for raw in Run.map:
		var cand: MapGen.MapNode = raw
		if cand.type != MapGen.NodeType.STATION or cand.manufacturer == &"":
			continue
		for id in DB.modules:
			var m: ModuleData = DB.modules[id]
			if m.manufacturer == cand.manufacturer and not m.starter_only:
				probe = m
				break
		if probe != null:
			n = cand
			break
	if not _ok("a branded station and one of its parts exist to price",
			n != null and probe != null):
		return
	var worst := 0.0
	# Well past anything a run can reach, because the ceiling is what has to hold.
	for i in 40:
		Run.standing[n.manufacturer] = i
		var ask := Market.ask(n, probe)
		var bid := Market.bid(n, probe)
		worst = maxf(worst, float(bid) / float(maxi(1, ask)))
		if bid >= ask:
			_ok("standing %d makes a part sell for what it costs" % i, false)
			return
		if Market.melt(probe) >= ask:
			_ok("standing %d makes a part melt for what it costs" % i, false)
			return
	Run.standing.clear()
	_ok("no amount of standing lets a part sell or melt for its own price", true)
	print("  bid peaks at %.0f%% of ask" % (worst * 100.0))


## The salvage rail's dismissal rule, which is pure logic on `Run` and has been
## wrong twice.
##
## It lives in this file rather than its own because this is the gate's test of
## RunState transitions and a second Godot boot to assert four booleans is not
## worth twenty seconds on every commit. If a third RunState rule needs covering,
## split them out then.
##
## First version put the flag on `SectorScreen`, which is REBUILT ON EVERY JUMP,
## so stowing was forgotten the moment you left. Second version moved it to `Run`
## and asked whether the state MATCHED the dismissal — so walking away from a bag
## changed the state and re-opened the rail. The rule is "is anything new".
func _salvage_hush() -> void:
	Run.hauls = 5
	Run.salvage_hushed_hauls = -1
	Run.salvage_hushed_bag = -1
	_ok("an undismissed rail is open", not Run.salvage_hushed(-1))

	# Dismissed at a system with no loose salvage.
	Run.salvage_hushed_hauls = Run.hauls
	Run.salvage_hushed_bag = -1
	_ok("dismissing shuts it", Run.salvage_hushed(-1))
	_ok("and a bag somewhere new opens it", not Run.salvage_hushed(12))

	# THE CASE THE SAVE USED TO BREAK. `hauls` is deliberately not persisted, so
	# it comes back as 0; if the dismissal were persisted beside it the rail
	# would stay shut for the next twelve hauls over loot already in the hold.
	# The dismissal is not saved either, and this is the assertion that says so.
	Run.hauls = 0
	_ok("a haul count reset below the dismissal opens it",
		not Run.salvage_hushed(-1))

	Run.hauls = 6
	_ok("and a fresh haul opens it", not Run.salvage_hushed(-1))

	# Dismissed while standing over a bag: walking away must NOT re-open it.
	Run.hauls = 6
	Run.salvage_hushed_hauls = 6
	Run.salvage_hushed_bag = 12
	_ok("dismissing over a bag shuts it", Run.salvage_hushed(12))
	_ok("and walking away from that bag leaves it shut",
		Run.salvage_hushed(-1))
	_ok("and a DIFFERENT bag still opens it", not Run.salvage_hushed(13))

	# A hull is the third thing the rail shows and the only one that never goes
	# through `stow()`, so it cannot rely on `hauls` moving.
	Run.hauls = 6
	Run.salvage_hushed_hauls = 6
	Run.salvage_hushed_bag = -1
	_ok("dismissed with nothing new", Run.salvage_hushed(-1))
	Run.find_hull(LootGen.roll_hull(3))
	_ok("and claiming a hull opens it", not Run.salvage_hushed(-1))
	Run.found_hull = null


# --- helpers ---------------------------------------------------------------

## The first offer of this kind anywhere in the galaxy.
func _make(kind: ContractData.Kind) -> ContractData:
	for n in Run.map:
		for c in Contracts.board(n as MapGen.MapNode):
			var job: ContractData = c
			if job.kind == kind and not Run.holds_contract(job):
				return job
	return null


func _find(t: MapGen.NodeType) -> int:
	for i in Run.map.size():
		if (Run.map[i] as MapGen.MapNode).type == t:
			return i
	return -1


func _berth(house: StringName) -> int:
	for i in Run.map.size():
		if ContractData.berth_of(Run.map[i] as MapGen.MapNode, house):
			return i
	return -1


func _other_than(index: int) -> int:
	for i in Run.map.size():
		if i != index:
			return i
	return -1


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: ContractData = a[i]
		var y: ContractData = b[i]
		if x.house != y.house or x.kind != y.kind or x.at != y.at \
				or x.pay != y.pay or x.text != y.text:
			return false
	return true


func _ok(what: String, condition: bool) -> bool:
	if condition:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		_fails += 1
	return condition
