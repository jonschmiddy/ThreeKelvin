extends Harness

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
## contracts to one manufacturer.


func run() -> void:
	seed_run(31337)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	_boards()
	_fetch()
	_hunt()
	_heat()
	_standing()
	_salvage_hush()
	# LAST, because it starts runs of its own on other seeds. Nothing in it
	# waits on a signal, so it finishes before `run` returns.
	await _every_job_lands()

	print("")
	verdict("contracttest")


## A board belongs to the place, not to the visit.
func _boards() -> void:
	var station := _find(MapGen.NodeType.STATION)
	if not _ok("the galaxy holds a station", station >= 0):
		return
	var n: MapGen.MapNode = Run.map[station]
	var a := Contracts.board(n)
	var b := Contracts.board(n)
	_ok("a station posts the same board twice", _same(a, b))
	# Not every station has a manufacturer behind it, so an empty board is legal. What
	# is not legal is a board with work on it that nobody is paying for.
	var has_manufacturer := true
	for c in a:
		if (c as ContractData).manufacturer == &"" or (c as ContractData).pay <= 0:
			has_manufacturer = false
	_ok("and every offer on it has a manufacturer and a price", has_manufacturer)
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
	# Somewhere else entirely: the contract must not close for a pickup anywhere.
	Run.reach_contract_target(_other_than(mine.at))
	_ok("a pickup somewhere else does nothing",
		mine.state == ContractData.State.TAKEN)

	Run.reach_contract_target(mine.at)
	_ok("the pickup at the target recovers it",
		mine.state == ContractData.State.READY)
	# THE HOLD IS NOT TOUCHED. A recovered item is named and not carried — a
	# contract that can be soft-locked by a full hold, or completed and then
	# accidentally scrapped, is a bug wearing a decision's clothes.
	_ok("and does not put anything in the hold", Run.cargo.is_empty())

	var berth := _berth(mine.manufacturer)
	if not _ok("the galaxy holds one of their berths", berth >= 0):
		return
	var n: MapGen.MapNode = Run.map[berth]
	_ok("which is where it can be delivered",
		Run.deliverable_at(n).has(mine))
	Run.deliver_contract(mine)
	_ok("delivering pays", Run.credits == before + mine.pay)
	_ok("and closes it", mine.state == ContractData.State.CLOSED)
	_ok("and raises standing", Run.standing_with(mine.manufacturer) > 0)
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
	var berth := _berth(mine.manufacturer)
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
	# A station with a DOMINANT manufacturer, not just any station — standing is read
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


## THE WORK IS WHERE THE NOTE SAYS IT IS, flown end to end on many galaxies.
##
## Jon, Oct 22: "Quests don't show up in the sectors they say they are." Three
## things were wrong and the checks above could see none of them, because they
## called `reach_contract_target(mine.at)` on the index and never read the note:
##
## - THE NAME MEANT TWO PLACES. `MapGen.star_name` hashed the index and gave
##   38% of systems a name another system also had, so a note naming "OMEGA
##   THORN REACH" sent the reader to whichever one they found;
## - THE LAYER WAS ONE SHORT. The note printed `layer` from zero; the chart and
##   the sector count from one;
## - NOTHING WAS THERE. No contract put anything on the named system's map: a
##   fetch closed itself on arrival with one log line (a quarter of them at a
##   station), and a hunt waited for a fight that was gone if you had won it
##   before you signed.
##
## So for every kind, on every seed: sign at a station, read the note, find the
## one system it names, fly there hop by hop through `Run.jump_to` and the
## arrival door (`Router.settle_arrival`), see the work on that system's map,
## do it, fly to a yard and DELIVER. A third of the targets are emptied before
## signing and a third after (a cleared system refuses every event), and every
## other hunt is fled and found again on the next arrival.
const JOB_SEEDS := [11, 23, 47, 101, 233, 512, 777, 1009, 2048, 4099, 31337, 65521]
const JOBS_PER_KIND := 4


func _every_job_lands() -> void:
	var flown := {ContractData.Kind.FETCH: 0, ContractData.Kind.HUNT: 0, ContractData.Kind.HEAT: 0}
	var wrong: Dictionary = {}
	var count := 0
	for sd in JOB_SEEDS:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var names := {}
		for raw in Run.map:
			var nm := MapGen.star_name(raw as MapGen.MapNode)
			if names.has(nm):
				_note(wrong, "two systems share a name", "seed %d: %s" % [sd, nm])
			names[nm] = true
		var links := _links()
		for kind in [ContractData.Kind.FETCH, ContractData.Kind.HUNT, ContractData.Kind.HEAT]:
			var got := 0
			for raw in Run.map:
				if got >= JOBS_PER_KIND:
					break
				var st: MapGen.MapNode = raw
				for c in Contracts.board(st):
					var job: ContractData = c
					if job.kind != kind or Run.holds_contract(job):
						continue
					count += 1
					var why: String = await _fly_job(st, job, links, count)
					if why != "":
						_note(wrong, why, "seed %d, %s posted at %s" % [sd,
							ContractData.Kind.keys()[kind], MapGen.star_name(st)])
					else:
						flown[kind] += 1
					got += 1
					break
	print("  flown end to end on %d seeds: %d fetch, %d hunt, %d heat" % [JOB_SEEDS.size(),
		flown[ContractData.Kind.FETCH], flown[ContractData.Kind.HUNT], flown[ContractData.Kind.HEAT]])
	for why in wrong:
		print("    %s (%d), first: %s" % [why, int(wrong[why][0]), String(wrong[why][1])])
	_ok("every system's name is its own", not wrong.has("two systems share a name"))
	for kind in flown:
		_ok("every %s signed was found where its note says, done and delivered (%d of %d)"
			% [String(ContractData.Kind.keys()[kind]).to_lower(), int(flown[kind]),
				JOB_SEEDS.size() * JOBS_PER_KIND],
			int(flown[kind]) == JOB_SEEDS.size() * JOBS_PER_KIND)
	_ok("and nothing went wrong on the way", wrong.is_empty())


## One signed job, flown. "" when it all held, or what did not.
func _fly_job(st: MapGen.MapNode, offer: ContractData, links: Dictionary, nth: int) -> String:
	Run.at = st.index
	st.visited = true
	if offer.kind == ContractData.Kind.HEAT:
		return _fly_heat(st, Run.take_contract(offer), links)
	var target: MapGen.MapNode = Run.map[offer.at]
	# the third of the work that names a place you had already emptied
	if nth % 3 == 1:
		_empty(target)
	var was := _worlds(target)
	var mine := Run.take_contract(offer)
	# POSTING MOVES NOTHING: the worlds you saw before you signed are the
	# worlds you see after, and the job's place is clear of all of them.
	if _worlds(target) != was:
		return "posting the work moved the system's own worlds"
	var lay := SystemLayout.of(target)
	var gi := _goal_at(target, Contracts.GOAL[offer.kind])
	var gb := lay.place_of(gi) if gi >= 0 else -2
	if gb >= 0:
		var jb := lay.bodies[gb]
		for b in lay.bodies:
			if b == jb or _is_job_body(target, b):
				continue
			if b.orbit + SystemLayout.reach_of(b) >= jb.orbit - SystemLayout.reach_of(jb):
				return "the job's place overlaps a world's orbit"
		if jb.kind != (&"contact" if offer.kind == ContractData.Kind.HUNT else &"planet"):
			return "the job's place is the wrong kind of place"

	# THE NOTE: its name is one system's and that system is the target, and the
	# layer it prints is the one the chart prints.
	var called := MapGen.star_name(target)
	var same := 0
	for raw in Run.map:
		if MapGen.star_name(raw as MapGen.MapNode) == called:
			same += 1
	if same != 1:
		return "the note's name is %d systems'" % same
	if mine.text.find(called) < 0:
		return "the note does not name its target"
	if mine.status_line().find("layer %d" % (target.layer + 1)) < 0:
		return "the note's layer is not the chart's"
	if not Contracts.holds_goal(target):
		return "the target cannot hold the work"
	if Run.contract_at(target.index) != mine:
		return "the chart does not mark the target"
	if _goal_at(target, Contracts.GOAL[mine.kind]) < 0:
		return "signing put nothing on the target's map"
	# and the third whose place is emptied after you sign (the Hellbender ate it)
	if nth % 3 == 2:
		_empty(target)

	# THERE, through the arrival door
	var why := _fly(target.index, links)
	if why != "":
		return why
	if target.cleared:
		return "the target is still cleared on arrival"
	var i := _goal_at(target, Contracts.GOAL[mine.kind])
	if i < 0:
		return "nothing on the target's map for the job"
	if SystemLayout.of(target).place_of(i) < 0:
		return "the job's event has no place on the system map"

	if mine.kind == ContractData.Kind.HUNT:
		var out: Dictionary = await OptionResolve.take(target, i, 0)
		if not bool(out.get("ok", false)) or not bool((out.get("res", {}) as Dictionary).get("fight", false)):
			return "engaging the hunt's target starts no fight"
		if Router.no_fights_at(target) or Router.option_foe(target, StringName(out.get("foe", &""))) == null:
			return "the hunt's fight has nobody to fight"
		# FLED: the event is spent and the job is not, so leaving and coming
		# back has to post the target again.
		if nth % 2 == 0:
			if mine.state != ContractData.State.TAKEN:
				return "fleeing the hunt closed it"
			why = _fly(_neighbour(target.index, links), links)
			if why != "":
				return why
			why = _fly(target.index, links)
			if why != "":
				return why
			i = _goal_at(target, Contracts.GOAL[mine.kind])
			if i < 0:
				return "a fled hunt's target is not there on the way back"
			out = await OptionResolve.take(target, i, 0)
		# what `Combat._victory` calls when the fight is won here
		Run.clear_contract_target(target.index)
	else:
		var _taken: Dictionary = await OptionResolve.take(target, i, 0)
	if mine.state != ContractData.State.READY:
		return "doing the job did not ready it"
	return _deliver(mine, links)


## A heat job: it needs heat on the hull at one of their yards, within the cap.
func _fly_heat(st: MapGen.MapNode, mine: ContractData, links: Dictionary) -> String:
	if mine.amount > Run.heat_cap():
		return "the heat asked for is over the hull's cap"
	var yard := _yard(mine.manufacturer, st.index, links)
	if yard < 0:
		return "no yard of theirs can be reached"
	var why := _fly(yard, links)
	if why != "":
		return why
	Run.heat = mine.amount
	var n: MapGen.MapNode = Run.map[yard]
	if not Run.heat_deliverable_at(n).has(mine):
		return "docking hot at their yard does not offer the job"
	var before := Run.credits
	Run.deliver_contract(mine)
	if mine.state != ContractData.State.CLOSED or Run.credits != before + mine.pay:
		return "delivering the heat did not pay"
	return ""


## Fly to the nearest of their yards and DELIVER.
func _deliver(mine: ContractData, links: Dictionary) -> String:
	var yard := _yard(mine.manufacturer, Run.at, links)
	if yard < 0:
		return "no yard of theirs can be reached from the target"
	var why := _fly(yard, links)
	if why != "":
		return why
	var n: MapGen.MapNode = Run.map[yard]
	if not Run.deliverable_at(n).has(mine):
		return "their yard does not offer DELIVER"
	var before := Run.credits
	Run.deliver_contract(mine)
	if mine.state != ContractData.State.CLOSED or Run.credits != before + mine.pay:
		return "DELIVER did not pay"
	return ""


## Hop by hop along the shortest route, through `Run.jump_to` and the arrival
## door, with the tank topped up so the trip is never the thing measured.
func _fly(to: int, links: Dictionary) -> String:
	if to < 0:
		return "nowhere to fly"
	if to == Run.at:
		return ""
	var route := _route(Run.at, to, links)
	if route.is_empty():
		return "no route to the place"
	for next in route:
		var t: MapGen.MapNode = Run.map[next]
		Run.fuel = Run.fuel_cap()
		t.sensed = true
		Run.jump_to(next)
		if Run.at != next:
			return "a jump on the way was refused"
		Router.settle_arrival(t)
	return ""


## Who reaches whom for this ship, once a galaxy: the chart's own rule.
func _links() -> Dictionary:
	var out := {}
	for a in Run.map:
		var na: MapGen.MapNode = a
		var to: Array[int] = []
		for b in Run.map:
			var nb: MapGen.MapNode = b
			if nb.type == MapGen.NodeType.CORE:
				continue
			if Run.reachable_from(na, nb):
				to.append(nb.index)
		out[na.index] = to
	return out


func _route(from: int, to: int, links: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if from == to:
		return out
	var back := {from: -1}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var i: int = queue.pop_front()
		if i == to:
			break
		for j in links.get(i, []):
			if not back.has(j):
				back[j] = i
				queue.append(j)
	if not back.has(to):
		return out
	var k := to
	while k != from:
		out.push_front(k)
		k = int(back[k])
	return out


## The nearest of a manufacturer's yards by hops, or -1.
func _yard(manufacturer: StringName, from: int, links: Dictionary) -> int:
	if ContractData.berth_of(Run.map[from], manufacturer):
		return from
	var best := -1
	var hops := 1 << 30
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if not ContractData.berth_of(n, manufacturer):
			continue
		var r := _route(from, n.index, links)
		if not r.is_empty() and r.size() < hops:
			hops = r.size()
			best = n.index
	return best


func _neighbour(i: int, links: Dictionary) -> int:
	for j in links.get(i, []):
		if (Run.map[j] as MapGen.MapNode).type != MapGen.NodeType.CORE:
			return int(j)
	return -1


## The untaken event `id` on this system, or -1.
func _goal_at(n: MapGen.MapNode, id: StringName) -> int:
	for i in n.options.size():
		if n.options[i] == id and not n.taken.has(MapGen.OPTION_SITE + i):
			return i
	return -1


## A system with everything in it spent, as a visit before or the Hellbender
## after would leave it.
func _empty(n: MapGen.MapNode) -> void:
	OptionTable.ensure(n)
	n.visited = true
	for i in n.options.size():
		if not n.taken.has(MapGen.OPTION_SITE + i):
			n.taken.append(MapGen.OPTION_SITE + i)
	n.cleared = true


## The system's own worlds -- every body but a job's and the Hellbender's -- as
## kind, world and orbit, to compare before and after a posting.
func _worlds(n: MapGen.MapNode) -> Array:
	var out: Array = []
	for b in SystemLayout.of(n).bodies:
		if _is_job_body(n, b):
			continue
		var hb := false
		for bc in b.beacons:
			hb = hb or bc.hellbender
		if not hb:
			out.append([b.kind, b.world, snappedf(b.orbit, 0.01)])
	return out


func _is_job_body(n: MapGen.MapNode, b: SystemLayout.Body) -> bool:
	for bc in b.beacons:
		if bc.opt >= 0 and bc.opt < n.options.size() and OptionTable.is_job(n.options[bc.opt]):
			return true
	return false


func _note(wrong: Dictionary, why: String, where: String) -> void:
	if not wrong.has(why):
		wrong[why] = [0, where]
	wrong[why][0] = int(wrong[why][0]) + 1


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


func _berth(manufacturer: StringName) -> int:
	for i in Run.map.size():
		if ContractData.berth_of(Run.map[i] as MapGen.MapNode, manufacturer):
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
		if x.manufacturer != y.manufacturer or x.kind != y.kind or x.at != y.at \
				or x.pay != y.pay or x.text != y.text:
			return false
	return true
