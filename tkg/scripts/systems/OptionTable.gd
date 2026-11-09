class_name OptionTable

## Nested situations, not flat lines (ruled 2026-08-26), so groups pair WHOLE situations.
## Identity is `id`, never the title.
## Why: docs/why/OptionTable.md#option-shape

## Option ids live on MapGen with the others: `MapGen.OPTION_SITE` says why 300 and why it
## never shrinks.

## Static and built once: `EventTable.build_all()` rebuilt every closure per call, too dear
## at ~290 systems.
## Why: docs/why/OptionTable.md#static-option-table
static var _all: Array[Dictionary] = []
static var _by_id: Dictionary = {}


## The table, resolved once and held.
static func all() -> Array[Dictionary]:
	if _all.is_empty():
		_build()
	return _all


## Returns empty, not an error: a save may name an option this build lacks, and it is
## dropped with a warning.
static func by_id(id: StringName) -> Dictionary:
	if _all.is_empty():
		_build()
	return _by_id.get(id, {})


## Measured flat: credits per tier read 50,50,49,52,56. Authors price on the rim and the
## tier multiplies it.
## Why: docs/why/OptionTable.md#depth-pay-scale
const PAY_SCALE: Array[float] = [0.0, 1.0, 1.8, 3.0, 4.7, 7.2]

## Toll climbs less steeply than pay on purpose (5.8x against 7.2x): a ladder costing more
## than it pays is climbed once.
## Why: docs/why/OptionTable.md#depth-pay-scale
const TOLL_SCALE: Array[float] = [0.0, 1.0, 1.9, 3.0, 4.3, 5.8]


## The danger of the system this is resolving in. One for anywhere that has no
## node -- the simulator poses options without a map under them.
static func _here_danger() -> int:
	var n: MapGen.MapNode = Run.node_at()
	return 1 if n == null else n.danger


## Not named `pay`: that name is taken by the outcome-to-REWARD function, and the clash
## would be a parse error.
## In an n-player game it pays `PartyScale.loot(n)` of it (Jon, Nov 5).
## Why: docs/why/OptionTable.md#purse-naming
static func purse(base: int) -> int:
	return PartyScale.pay(maxi(1, int(round(float(base)
		* PAY_SCALE[MapGen.tier(_here_danger())]))))


## What a rim-priced injury costs here.
static func toll(base: int) -> int:
	return maxi(1, int(round(float(base)
		* TOLL_SCALE[MapGen.tier(_here_danger())])))


## Gating clauses are ANDed. Without them a whale fall could surface in the core and a
## cordon in unclaimed space.
## Why: docs/why/OptionTable.md#option-gating
static func admits(o: Dictionary, n: MapGen.MapNode) -> bool:
	if n == null:
		return false
	# Placed options are never rolled: a quest buyer without the package is worthless. A gate,
	# as weight 0 floors to 1.
	if bool(o.get("placed", false)):
		return false
	if o.has("min_danger") and n.danger < int(o.min_danger):
		return false
	if o.has("max_danger") and n.danger > int(o.max_danger):
		return false
	if o.has("min_security") and n.security < int(o.min_security):
		return false
	if o.has("max_security") and n.security > int(o.max_security):
		return false
	if o.has("min_development") and int(n.development) < int(o.min_development):
		return false
	# `admits` ignores unknown keys, so an unimplemented gate silently appears everywhere.
	# `max_development` is a ceiling so `long_claim` is not offered at a city.
	# Why: docs/why/OptionTable.md#silent-gate-failure
	if o.has("max_development") and int(n.development) > int(o.max_development):
		return false
	if o.has("regions"):
		var rs: Array = o.regions
		if not rs.is_empty() and not rs.has(int(n.region)):
			return false
	if o.has("needs_fauna") and bool(o.needs_fauna) and not n.fauna:
		return false
	# Sky-specific options need real gates: `min_danger` let `the_sweep` land with no pulsar
	# and the prose lied.
	# Why: docs/why/OptionTable.md#silent-gate-failure
	if o.has("needs_star") and int(n.star) != int(o.needs_star):
		return false
	# `in_nebula` was the one sky fact with no gate, so nebula content could not be written.
	if o.has("needs_nebula") and bool(o.needs_nebula) and not n.in_nebula:
		return false
	if o.has("needs_giant") and bool(o.needs_giant) and not n.gas_giant:
		return false
	if o.has("needs_pulsar") and bool(o.needs_pulsar) and not n.near_pulsar:
		return false
	if o.has("needs_berth") and bool(o.needs_berth) and n.berths.is_empty():
		return false
	if o.has("berth") and not n.berths.has(StringName(o.berth)):
		return false
	return true


## `label_at` holds node-dependent words; `label` stays plain for the lint and prose tools.
static func label_of(c: Dictionary, n: MapGen.MapNode) -> String:
	var f: Callable = c.get("label_at", Callable())
	if f.is_valid() and n != null:
		return String(f.call(n))
	return String(c.get("label", ""))


## Rolled from the system so the choice can name the frame; before, a heavy pilot claimed a
## light one blind.
## Why: docs/why/OptionTable.md#derelict-frame
static func derelict_frame(n: MapGen.MapNode) -> HullData:
	var at := -1 if n == null else n.index
	var danger := 1 if n == null else n.danger
	return LootGen.roll_hull(danger, Rng.derive(&"derelict_hull", at))


## The claimed frame carries the strip pay, so a frame you do not fly cuts up for what
## stripping paid.
static func strip_pay(n: MapGen.MapNode, base: int) -> Dictionary:
	var row: Dictionary = {}
	if n != null:
		row = MaterialTable.roll(&"wreck", n.danger, Rng.derive(&"material", n.index))
	return {credits = purse(base), material = StringName(row.get("id", &""))}


## Every door that starts an event's fight asks this, then hands the answer to
## `Router.option_foe`.
static func fight_foe(o: Dictionary, c: Dictionary = {}) -> StringName:
	return StringName(c.get("foe", o.get("foe", &"")))


## Counts stay flat: the galaxy already applies a depth gradient via `ring_count`, and
## twice compounds.
## Why: docs/why/OptionTable.md#tier-plan-counts
const TIER_PLAN := {
	1: {"lo": 2, "hi": 3, "groups": 0},
	2: {"lo": 2, "hi": 4, "groups": 1},
	3: {"lo": 2, "hi": 4, "groups": 1},
	4: {"lo": 3, "hi": 4, "groups": 2},
	5: {"lo": 3, "hi": 4, "groups": 9},
}


## One place pays outcomes: three copies drifted and `EventScreen` never paid `module`.
## Closed options get `R_GONE`, so the card says UNAVAILABLE instead of vanishing.
## Why: docs/why/OptionTable.md#paying-outcomes
static func foreclose(n: MapGen.MapNode, i: int) -> void:
	if n == null or i < 0 or i >= n.options.size():
		return
	var g := StringName(by_id(n.options[i]).get("group", &""))
	if g == &"":
		return
	for j in n.options.size():
		if j == i or StringName(by_id(n.options[j]).get("group", &"")) != g:
			continue
		var jid := MapGen.OPTION_SITE + j
		if n.taken.has(jid):
			continue
		n.taken.append(jid)
		n.results[j] = MapGen.R_GONE


## Screens ask what arrived on the pile, not whether a part rolled (Jon, Oct 22: quests
## missed REWARD).
## Why: docs/why/OptionTable.md#reward-display
static func pays_item(res: Dictionary) -> bool:
	return bool(res.get("module", false))


## `src` is the option whose outcome this is: an outcome that places a quest
## (`place`) records it as the quest's giver, which the QUESTS table names.
static func pay(res: Dictionary, n: MapGen.MapNode, src: StringName = &"") -> String:
	if res.is_empty() or n == null:
		return ""
	var got: Array[String] = []
	if pays_item(res):
		# Rewards go into the system pile: `place_in_hold` lost earnings on a full hold. Not
		# `n.bagged`.
		# Why: docs/why/OptionTable.md#pay-into-the-system
		# One more for each player past the first (`PartyScale`), as the event's money is.
		for i in PartyScale.pay(1):
			Run.sector_jetsam(n).items.append(LootGen.roll_module(n.danger))
	# Positional roll from the node index: a party gets the same item and a reload cannot
	# shop.
	var r := Rng.derive(&"material", n.index)
	# WHAT THIS PUTS SOMEWHERE ELSE. The reward for some options is not a number
	# and not an object -- it is the encounter this plants four jumps deeper.
	if res.has("place"):
		var at := place(n, StringName(res.place), src)
		if at >= 0:
			got.append("%s MARKED" % quest_name(Run.map[at]))
	if res.has("material"):
		got.append(MaterialTable.grant(MaterialTable.roll(
			StringName(res.material), n.danger, r)))
	if res.has("material_id"):
		# Named drops are not tier-gated, or the pairing with the prose (`sweep_glass`) would
		# silently break.
		got.append(MaterialTable.grant(
			MaterialTable.by_id(StringName(res.material_id))))
	# Nothing uses this by ruling: taking a tier lets the code pick from the player's hold,
	# which is theirs.
	# Why: docs/why/OptionTable.md#material-consumption-ruling
	if res.has("consume_material_tier"):
		# Under the shim this spends the exotic ledger counter, becoming a hold search here alone
		# later.
		Run.spend_material_tier(StringName(res.consume_material_tier))
	got.erase("")
	return ", ".join(got)


## Replaces what `NodeType.FIGHT` and `DERELICT` answered, reading what is really rolled
## here.
static func system_has_tag(n: MapGen.MapNode, tag: StringName) -> bool:
	if n == null:
		return false
	# Rolls the system if needed: the hellbender scans unvisited systems. Safe as the draw is
	# positional.
	# Why: docs/why/OptionTable.md#rolling-early
	ensure(n)
	for id in n.options:
		var o := by_id(id)
		if o.is_empty():
			continue
		for t in o.get("tags", []):
			if StringName(t) == tag:
				return true
	return false


## Placement appends to `MapNode.options`; target derived from the source index. `ensure`
## first, as it rolls only an empty list.
## Why: docs/why/OptionTable.md#placing-options-ahead
const PLACE_DEPTH := 3

static func place(from: MapGen.MapNode, id: StringName, src: StringName = &"") -> int:
	if from == null:
		return -1
	var what := by_id(id)
	if what.is_empty():
		return -1
	# A quest stands alone: in a group, an unrelated option could foreclose it. Refused, not
	# stripped.
	# Why: docs/why/OptionTable.md#quests-stand-alone
	if StringName(what.get("group", &"")) != &"":
		push_warning("placed option %s carries a group; not placed" % id)
		return -1
	var want := from.layer + PLACE_DEPTH
	var picks: Array[int] = []
	# The nearest layer at or past the wanted depth that has anything free.
	while want < MapGen.LAYERS and picks.is_empty():
		for other in Run.map:
			var o: MapGen.MapNode = other
			if o.layer != want or o.visited:
				continue
			if o.type != MapGen.NodeType.SYSTEM:
				continue
			# One thread per system: two payoffs on one node read as coincidence and the chart
			# marks once.
			if holds_quest(o):
				continue
			picks.append(o.index)
		want += 1
	if picks.is_empty():
		return -1
	picks.sort()
	var r := Rng.derive(&"placed", from.index)
	var at: int = picks[r.randi() % picks.size()]
	var node: MapGen.MapNode = Run.map[at]
	ensure(node)
	node.options.append(id)
	Run.note_placed(at, id, src)
	Sig.map_changed.emit()
	return at


## Built once: `holds_quest` runs per system per mouse frame, and `by_id` is linear, ~30k
## comparisons a frame.
## Why: docs/why/OptionTable.md#placed-id-cache
static var _placed: Dictionary = {}


static func placed_ids() -> Dictionary:
	if _placed.is_empty():
		for o in all():
			# A contract's event is not a thread: the chart already marks it by the job
			# (`Run.contract_at`).
			if bool(o.get("placed", false)) and not bool(o.get("job", false)):
				_placed[StringName(o.id)] = true
	return _placed


## A signed job is placed on one ship's map past the system's worlds and never raced over
## the wire.
static func is_job(id: StringName) -> bool:
	return bool(by_id(id).get("job", false))


## Jobs and quests are one ship's own, never raced or closed by a partner's claim at the
## same slot (Oct 22).
## Why: docs/why/OptionTable.md#ship-owned-options
static func is_mine(id: StringName) -> bool:
	return is_job(id) or placed_ids().has(id)


static func holds_quest(n: MapGen.MapNode) -> bool:
	if n == null:
		return false
	var set := placed_ids()
	for i in n.options.size():
		if not set.has(n.options[i]):
			continue
		if not n.taken.has(MapGen.OPTION_SITE + i):
			return true
	return false


## The name a marked system shows on the chart: the quest's own title.
static func quest_name(n: MapGen.MapNode) -> String:
	if n == null:
		return ""
	var set := placed_ids()
	for i in n.options.size():
		if not set.has(n.options[i]):
			continue
		if n.taken.has(MapGen.OPTION_SITE + i):
			continue
		return String(by_id(n.options[i]).get("title", "")).to_upper()
	return ""


## Positional off `Rng.derive`: what is at a place is the place's property, and four
## machines must agree.
## Why: docs/why/OptionTable.md#positional-roll
static func roll_for(n: MapGen.MapNode) -> Array[StringName]:
	var out: Array[StringName] = []
	if n == null:
		return out
	var r := Rng.derive(&"options", n.index)
	var pool: Array[Dictionary] = []
	for o in all():
		if admits(o, n):
			pool.append(o)
	if pool.is_empty():
		return out

	var plan: Dictionary = TIER_PLAN.get(MapGen.tier(n.danger), TIER_PLAN[1])
	var want: int = int(plan.lo) + (r.randi() % maxi(1, int(plan.hi) - int(plan.lo) + 1))
	want = mini(want, pool.size())

	var groups_used: Dictionary = {}
	while out.size() < want and not pool.is_empty():
		var total := 0
		for o in pool:
			total += maxi(1, int(o.get("weight", 10)))
		var pick := r.randi() % maxi(1, total)
		var chosen := -1
		for i in pool.size():
			pick -= maxi(1, int(pool[i].get("weight", 10)))
			if pick < 0:
				chosen = i
				break
		if chosen < 0:
			chosen = pool.size() - 1
		var got: Dictionary = pool[chosen]
		pool.remove_at(chosen)
		# A full group is skipped, not dropped from the pool, as it may still arrive at another
		# system.
		var g := StringName(got.get("group", &""))
		if g != &"":
			if not groups_used.has(g) and groups_used.size() >= int(plan.groups):
				continue
			groups_used[g] = true
		out.append(StringName(got.id))
	return out


## One decision for both `Router._roll_here` and the headless sim, so they cannot drift.
## The start is quiet on purpose: no decision before the player has seen the galaxy.
## Why: docs/why/OptionTable.md#ensure-and-quiet-start
static func ensure(n: MapGen.MapNode) -> bool:
	if n == null:
		return false
	# A station IS its list -- shelf, rack, repair, fuel -- and the core is a
	# hand-authored boss.
	if n.type == MapGen.NodeType.STATION or n.type == MapGen.NodeType.CORE:
		return false
	# And the start is quiet on purpose.
	if n.type == MapGen.NodeType.START:
		return false
	if n.options.is_empty():
		n.options = roll_for(n)
		# A partner's claim can precede our roll, so foreclosure is derived again once the options
		# exist.
		for t in n.taken:
			var i := int(t) - MapGen.OPTION_SITE
			if i >= 0 and i < n.options.size():
				foreclose(n, i)
		# A claim past the list is a partner's own option; dropped so our `place` is not born
		# taken.
		var keep := PackedInt32Array()
		for t in n.taken:
			var k := int(t)
			if k >= MapGen.OPTION_SITE and k < MapGen.OPTION_JETSAM \
					and k - MapGen.OPTION_SITE >= n.options.size():
				continue
			keep.append(k)
		n.taken = keep
	return not n.options.is_empty()



static func _build() -> void:
	_all = _authored()
	_by_id = {}
	for o in _all:
		var id := StringName(o.id)
		if _by_id.has(id):
			push_error("OptionTable: duplicate id '%s'" % id)
		_by_id[id] = o


## The machine, not the content: authoring the pool is out of scope (`ROADMAP.md` 11),
## enough to exercise rules.
## Why: docs/why/OptionTable.md#authored-options-scope
static func _authored() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(OptionsPart01.entries())
	out.append_array(OptionsPart02.entries())
	out.append_array(OptionsPart03.entries())
	out.append_array(OptionsPart04.entries())
	out.append_array(OptionsPart05.entries())
	out.append_array(OptionsPart06.entries())
	out.append_array(OptionsPart07.entries())
	out.append_array(OptionsPart08.entries())
	out.append_array(OptionsPart09.entries())
	out.append_array(OptionsPart10.entries())
	return out
