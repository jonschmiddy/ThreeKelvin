class_name OptionTable

## What a system holds, and the rules for picking it.
##
## `ENCOUNTER_REBUILD.md` §4–§5. A system rolls 2–4 of these on arrival; each one
## is a SITUATION with its own choices inside it, and the chart never says what
## they are.
##
## NESTED RATHER THAN FLAT, ruled 2026-08-26. §4 of that brief specifies a flat
## option -- one label, one resolution -- and all thirteen authored options in
## `batch-02-draft.md` are written the other way: a title, shared prose, and two
## or three lines to take. Flattening them would turn 13 into ~33, repeat the
## prose on every line, and lose the thing `group` is for -- the authored groups
## pair WHOLE situations ("salvage_rights competes with still_under_warranty"),
## not individual lines.
##
## So the shape is today's `EventTable` entry plus four fields: `id`, gating,
## `group`, `weight`. That is also why the port is cheap -- OPT-007 to 012 are
## literally existing events with a header written on them.
##
## ```gdscript
## {
##     id = &"salvage_rights",          # stable identity, never the title
##     title = "Salvage rights",
##     body = "A hull lies open across two claims...",
##     tags = [&"salvage", &"contract"],
##     group = &"wreck",                # &"" is independent
##     weight = 11,
##     regions = [MapGen.Region.LAWLESS], min_danger = 2,   # gating, all ANDed
##     choices = [ {label, check?, effect|met/clean/partial/botched}, ... ],
## }
## ```
##
## IDENTITY IS THE `id`, NEVER THE TITLE. `EventTable.by_key()` matches on
## `str(e.title)`, so renaming "Whale fall" invalidates every save that rolled
## it. That is not carried forward: the title is copy and the id is a key.

## Where a system's option ids live: `OPTION_SITE + i` is the i-th one.
##
## On MapGen with the others -- see `MapGen.OPTION_SITE` for why 300 and why the
## list must never shrink.

## Every option in the game.
##
## STATIC AND BUILT ONCE. `EventTable.build_all()` reconstructs fourteen
## dictionaries and every closure inside them on each call, including from
## `by_key()`, which then linear-searches. At ~290 systems each rolling its own
## list that pattern stops being merely wasteful -- `ENCOUNTER_REBUILD.md` §5a
## says so in as many words.
## How often the anchor floor had to step in. See `_anchor_floor`.
##
## THIS IS THE DELETION DATE. The floor is scaffolding for a thin table; when
## this reaches zero over a full sim the pool is supplying anchors on its own and
## the floor is dead code with a test saying so.
static var floor_fired: int = 0

static var _all: Array[Dictionary] = []
static var _by_id: Dictionary = {}


## The table, resolved once and held.
static func all() -> Array[Dictionary]:
	if _all.is_empty():
		_build()
	return _all


## One option by id, or an empty dictionary.
##
## Returns empty rather than pushing an error: a save may name an option this
## build no longer has, and `ENCOUNTER_REBUILD.md` §4 rules that the right answer
## is to drop it with a warning rather than refuse the save.
static func by_id(id: StringName) -> Dictionary:
	if _all.is_empty():
		_build()
	return _by_id.get(id, {})


## Does this option's gating admit this system?
##
## Every clause is optional and they are ANDed. All seven axes already exist on
## `MapNode` and are richly generated -- and `EventTable.pick_key()` reads none
## of them, which is most of why fourteen events feel same-y: a whale fall can
## surface in the core, a customs cordon in unclaimed space.
static func admits(o: Dictionary, n: MapGen.MapNode) -> bool:
	if n == null:
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
	if o.has("regions"):
		var rs: Array = o.regions
		if not rs.is_empty() and not rs.has(int(n.region)):
			return false
	if o.has("needs_fauna") and bool(o.needs_fauna) and not n.fauna:
		return false
	if o.has("needs_berth") and bool(o.needs_berth) and n.berths.is_empty():
		return false
	if o.has("berth") and not n.berths.has(StringName(o.berth)):
		return false
	return true


## How many options a system of this tier holds, and how many share a group.
##
## `ENCOUNTER_REBUILD.md` §4. COUNTS STAY FLAT and only the grouping moves --
## the galaxy already applies a depth gradient through `ring_count`, and applying
## it twice compounds. Depth changes what the options cost you and how many you
## must give up, not how many there are.
const TIER_PLAN := {
	1: {"lo": 2, "hi": 3, "groups": 0},
	2: {"lo": 2, "hi": 4, "groups": 1},
	3: {"lo": 2, "hi": 4, "groups": 1},
	4: {"lo": 3, "hi": 4, "groups": 2},
	5: {"lo": 3, "hi": 4, "groups": 9},
}


## The tags a system needs at least one of, while the table is thin.
##
## `fight` because contracts ask for one and because 5's reward classes make
## fights the only reliable door to the top of the rarity ladder. `salvage`
## because the hellbender eats wrecks, and because a system with neither is a
## system with nothing in it worth crossing a galaxy for.
const ANCHOR_TAGS: Array[StringName] = [&"fight", &"salvage"]


## Does this system offer an option carrying `tag`?
##
## What `NodeType.FIGHT` and `NodeType.DERELICT` used to answer. Contracts ask
## for `fight` and the hellbender eats `salvage`, and both now read what is
## actually here rather than a label that was chosen before anything was rolled.
static func system_has_tag(n: MapGen.MapNode, tag: StringName) -> bool:
	if n == null:
		return false
	# ROLLS THE SYSTEM IF IT HAS NOT BEEN ROLLED, and both callers need that:
	# a contract board looks three layers ahead and the hellbender scans the whole
	# map, so every system either of them cares about is one nobody has flown to.
	# Reading `n.options` raw would have answered "no fight anywhere", which is
	# how the hunt contract stopped being findable.
	#
	# Safe because the answer does not depend on WHEN it is asked. `admits` gates
	# on node properties only -- danger, security, development, region, fauna,
	# berths, all fixed at map generation -- and the draw is positional, which is
	# what `-- optiontest`'s "the same system always rolls the same options" is
	# there to prove. Rolling early writes the list the arrival would have
	# written, so the anti-save-scum contract in `_roll_here` is untouched: it is
	# still decided once and still written before the autosave.
	ensure(n)
	for id in n.options:
		var o := by_id(id)
		if o.is_empty():
			continue
		for t in o.get("tags", []):
			if StringName(t) == tag:
				return true
	return false


## Does this option anchor a system?
static func _anchors(o: Dictionary) -> bool:
	for t in o.get("tags", []):
		if ANCHOR_TAGS.has(StringName(t)):
			return true
	return false


## Make sure a system offers something to fight or something to strip.
##
## SCAFFOLDING. See `floor_fired` for how it ends: when the pool supplies an
## anchor on its own the swap stops happening, and this becomes dead code with a
## measurement proving it rather than a note somebody has to remember.
##
## Swaps rather than appends, so the tier plan's counts are not quietly
## exceeded -- the lowest-weight option goes, because weight is how the table
## says which entries are meant to be common.
static func _anchor_floor(out: Array[StringName], pool: Array[Dictionary],
		r: RandomNumberGenerator) -> void:
	for id in out:
		if _anchors(by_id(id)):
			return
	var anchors: Array[Dictionary] = []
	for o in pool:
		if _anchors(o):
			anchors.append(o)
	if anchors.is_empty():
		return
	var swap: Dictionary = anchors[r.randi() % anchors.size()]
	var worst := 0
	for i in out.size():
		if int(by_id(out[i]).get("weight", 10)) < int(by_id(out[worst]).get("weight", 10)):
			worst = i
	out[worst] = StringName(swap.id)
	floor_fired += 1


## What this system holds. Ids only -- callables are never built here.
##
## POSITIONAL, off `Rng.derive(&"options", n.index)`, because what is AT a place
## is a property of the place and four machines in a co-op session must agree
## about it. What happens TO you comes off a seat-salted stream instead; the
## ambush roll is that and this is not.
##
## Drawn without replacement so a system never offers the same situation twice.
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
		# A GROUP MAY ONLY BE OPENED AS OFTEN AS THE TIER ALLOWS. An option whose
		# group is already spoken for is skipped rather than dropped from the
		# pool for good -- it may still arrive at another system.
		var g := StringName(got.get("group", &""))
		if g != &"":
			if not groups_used.has(g) and groups_used.size() >= int(plan.groups):
				continue
			groups_used[g] = true
		out.append(StringName(got.id))
	# `pool` is what the draw did NOT take, which is exactly the set a swap may
	# come from -- anything already in `out` is either an anchor or was not one.
	if not out.is_empty():
		_anchor_floor(out, pool, r)
	return out


## Roll this system's list if it has none, and answer whether it has one.
##
## THE SAME DECISION IN ONE PLACE. `Router._roll_here` rolls on arrival for a
## played run and the headless simulator never goes through Router at all, so
## without this the two would each carry a copy of "which nodes get options"
## and drift the first time either changed.
##
## Stations are excluded because a station IS its option list -- the shelf, the
## rack, repair and fuel -- and it is the one node the chart telegraphs. The core
## is excluded because it is a hand-authored boss.
##
## AND THE START IS QUIET ON PURPOSE. A run opens on a system with nothing in it,
## so the first thing a player does is read the chart rather than resolve an
## encounter -- which matters more now that sight is live and most of the map is
## dark. It is also the one arrival nobody chose, and asking someone to spend a
## decision before they have seen the galaxy is asking them to guess.
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
	return not n.options.is_empty()


## Resolve stored ids back to definitions, dropping any this build no longer has.
##
## `ENCOUNTER_REBUILD.md` §4: a save must be able to rebuild its list after the
## table has changed underneath it. An unknown id is a warning and a gap, never a
## refused save.
static func resolve(ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ids:
		var o := by_id(StringName(id))
		if o.is_empty():
			push_warning("OptionTable: save names option '%s', which this build does not have" % id)
			continue
		out.append(o)
	return out


static func _build() -> void:
	_all = _authored()
	_by_id = {}
	for o in _all:
		var id := StringName(o.id)
		if _by_id.has(id):
			push_error("OptionTable: duplicate id '%s'" % id)
		_by_id[id] = o


## The options themselves, ported from `docs/briefs/batch-02-draft.md`.
##
## THE MACHINE, NOT THE CONTENT. `ROADMAP.md` §11 puts authoring the pool out of
## scope for this phase -- `ENCOUNTER_GENERATION.md` is how it gets filled, and
## that is its own job with its own volume problem. What is here is enough to
## exercise gating, grouping, weighting and the tier plan honestly.
static func _authored() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{
			id = &"hostile_contact",
			title = "Hostile contact",
			body = "Something is holding station where nothing should be, and it has your registry already. No hail, no demand. It simply turns to face you.",
			tags = [&"fight"],
			group = &"",
			weight = 16,
			choices = [
				# THE OUTCOME OPENS THE FIGHT, not the line. `EventScreen._choose`
				# reads `fight` off what the callable RETURNS -- which is how
				# EventTable's two hostile endings have always worked -- so a flag
				# on the line was a flag nothing was reading.
				{label = "Engage", effect = func() -> Dictionary:
					return {text = "It came out here expecting easier work.", fight = true}},
				{label = "Burn past it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You put the throttle down and take the long way round the system. It does not follow, and you do not learn what it wanted."}},
			],
		},
		{
			id = &"dead_hull",
			title = "A dead hull",
			body = "It has been here long enough to go cold all the way through. No beacon, no claim on the board, nothing on any registry you can reach from here.",
			tags = [&"salvage"],
			group = &"",
			weight = 14,
			choices = [
				{label = "Strip it", effect = func() -> Dictionary:
					return {text = "Whatever killed it did not take the parts. You leave with what would have been someone's spares.", module = true}},
				{label = "Read the log first",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "The log is intact and says who they were owed money by. The debt is transferable.", module = true},
					clean = func() -> Dictionary:
						return {text = "Enough of the log survives to say the hull is not booby-trapped, which is the part worth knowing.", module = true},
					partial = func() -> Dictionary:
						return {text = "The recorder is slag. You take what is loose and do not learn anything."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(5, "Something in the dead hull was still charged.")
						return {text = "A cell that should have been flat was not. You leave with less than you arrived with."}},
			],
		},
		{
			id = &"cordon",
			title = "The cordon",
			body = "Someone has strung a picket across the lane and is charging to let ships through it. There is no authority here to complain to. That is the entire business model.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 12,
			regions = [MapGen.Region.LAWLESS],
			max_security = 2,
			min_danger = 3,
			choices = [
				{label = "Pay it", cost_credits = 60, effect = func() -> Dictionary:
					Run.add_credits(-60)
					return {text = "Sixty credits and a wave from whoever is sitting in the chair. The lane is clear the whole way through, which is the galling part."}},
				{label = "Run it",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						return {text = "You are past the picket before the picket is past discussing it."},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						return {text = "They get a burn off. You get through, and the tank shows the sprint."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 26)
						return {text = "You commit, then take the wide route at speed, which is the expensive one. Through, and down half a ring's travel."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 40)
						return {text = "You cross the lane twice, both times at full burn, the second time for no reason either of you could name afterwards."}},
				{label = "Break it", effect = func() -> Dictionary:
					return {text = "They are not expecting a ship that came out here to do this.", fight = true}},
			],
		},
		{
			id = &"salvage_rights",
			title = "Salvage rights",
			body = "A hull lies open across two claims and neither claimant is here. Both filings sit on the local board, dated the same day, each citing the other as the party in error.",
			tags = [&"salvage", &"contract"],
			group = &"wreck",
			weight = 11,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY],
			min_danger = 2,
			choices = [
				{label = "Strip it now", effect = func() -> Dictionary:
					return {text = "You take what is loose and leave before either office establishes which of them was right.", module = true}},
				{label = "File a third claim",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(35)
						return {text = "Your filing is cleaner than either of theirs and predates the dispute by exactly as long as it took you to write it.", module = true},
					clean = func() -> Dictionary:
						return {text = "Your claim holds long enough to matter.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(45)
						return {text = "The board accepts it and one claimant contests it within the hour. You take what you can carry and draft a reply you will never send."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "You file into the middle of a dispute that now has three parties and a docket number. The fee is not refundable."}},
				{label = "Leave it to them", effect = func() -> Dictionary:
					return {text = "Two claims, one wreck, an office each."}},
			],
		},
		{
			id = &"still_under_warranty",
			title = "Still under warranty",
			body = "The wreck carries a Verity plate, and Verity plates carry terms. A service notice is still transmitting on a loop from a hull with no crew, no power and, by any reasonable reading, no remaining obligations.",
			tags = [&"salvage"],
			group = &"wreck",
			weight = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY,
				MapGen.Region.COSMOPOLITAN],
			berth = &"verity",
			choices = [
				{label = "Answer the notice",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "The loop accepts your registry as the holder of record. Coverage, it turns out, continues.", module = true},
					clean = func() -> Dictionary:
						return {text = "The notice concludes its terms and releases what is left.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "The loop refers you to a clause, and the clause refers you to an office that is four rings away."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "You are logged as having made a claim against a policy you do not hold. There is a fee for that."}},
				{label = "Strip it regardless", effect = func() -> Dictionary:
					return {text = "The notice is still transmitting when you leave. It will be transmitting for a long time.", module = true}},
			],
		},
		{
			id = &"collapsed_lane",
			title = "Collapsed lane",
			body = "The short way on runs through a shipbreaker's yard, a lane of dead hulls packed too close to thread. Going around costs a day and a tank.",
			tags = [&"signal"],
			group = &"",
			weight = 9,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.COSMOPOLITAN,
				MapGen.Region.TERRITORY],
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Push through the wrecks",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 10
						return {text = "Plating screams the length of the lane and holds. You come out the far side with the fuel you did not spend going round."},
					clean = func() -> Dictionary:
						Run.take_hull_damage(4, "The shipbreaker's lane took its cut.")
						Run.fuel += 10
						return {text = "Something gives near the bow. You keep going, and you keep the fuel."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(9, "The shipbreaker's lane took its cut.")
						return {text = "Halfway in, a spar goes through the forward plating. You reverse out of the lane the way you came."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(16, "A dead hull folded the bow in the breaker's lane.")
						return {text = "The lane closes on you. What comes out the other side is your ship, mostly."}},
				{label = "Go around", effect = func() -> Dictionary:
					return {text = "The long way. Nothing happens on it, which is the point."}},
			],
		},
		{
			id = &"drifting_lifepod",
			title = "Drifting lifepod",
			body = "A pod tumbles past, transponder weak. Someone is still inside, or was.",
			tags = [&"signal"],
			group = &"",
			weight = 10,
			choices = [
				{label = "Crack it open", effect = func() -> Dictionary:
					if Rng.event.randf() < 0.6:
						Run.add_credits(25)
						return {text = "Cargo, no occupant. Twenty-five credits."}
					Run.take_hull_damage(6, "A scavenger trap finished what the cold started.")
					return {text = "A scavenger trap. Six hull."}},
				{label = "Leave it", effect = func() -> Dictionary:
					return {text = "It tumbles on. The transponder is still going when it leaves sensor range."}},
			],
		},
	])
	return out
