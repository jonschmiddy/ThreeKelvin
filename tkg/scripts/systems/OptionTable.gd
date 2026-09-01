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
## `EventTable` WAS DELETED 2026-08-27, its last seven entries ported here. It is
## named below because it is why this shape is what it is, not because you can go
## and read it.
##
## So the shape is that `EventTable` entry plus four fields: `id`, gating,
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
##     choices = [ {label, check?, stay?, effect|met/clean/partial/botched}, ... ],
## }
## ```
##
## `stay = true` MARKS A WALK-AWAY: a choice that rolls nothing, costs nothing
## and pays nothing — "Leave it", "Decline", "Pass". The sector shows its prose
## and does NOT mark the option resolved, so declining a thing leaves it there
## to come back to. It is a declaration, not a detection, because only the
## author knows whether "she goes to ask the next ship" means the encounter is
## narratively spent — a choice whose effect changes anything must never carry
## it.
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
	# PLACED OPTIONS ARE NEVER ROLLED. A quest is the payoff of something you
	# did somewhere else, and meeting the buyer at the far end without having carried the
	# package is the one way it can be worthless. This is the gate rather than
	# a zero weight because a weight of zero still leaves the row in the pool
	# and `roll_for` floors every weight at one.
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
	# A CEILING AS WELL AS A FLOOR, added for batch 04. `long_claim` is a seam
	# nobody works "because hauling ore back costs more than the ore" -- that is
	# false at a city and the option would have been lying wherever it landed.
	#
	# Worth noting how it would have failed: `admits` ignores keys it does not
	# know, so an option carrying an unimplemented gate is not rejected loudly.
	# It simply appears everywhere. A gate that silently does nothing is worse
	# than one that does not exist, because the content reads as if it were
	# placed.
	if o.has("max_development") and int(n.development) > int(o.max_development):
		return false
	if o.has("regions"):
		var rs: Array = o.regions
		if not rs.is_empty() and not rs.has(int(n.region)):
			return false
	if o.has("needs_fauna") and bool(o.needs_fauna) and not n.fauna:
		return false
	# WHAT IS ACTUALLY IN THE SKY. These four options describe a specific thing
	# overhead -- a star throwing tantrums, a gas giant with you in its well, a
	# pulsar sweeping the arc -- and had `min_danger` for a gate, which says
	# "deep enough that it is plausible" and nothing more. `the_sweep` could
	# land on a system with no pulsar within reach and the prose simply lied.
	#
	# The header above says it: a gate that silently does nothing is worse than
	# one that does not exist, because the content reads as if it were placed.
	# These were the four where that was true.
	if o.has("needs_star") and int(n.star) != int(o.needs_star):
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


## Hand over everything an outcome promised, and say what arrived.
##
## ONE PLACE, BECAUSE THREE WAS ALREADY ONE TOO MANY. An outcome dictionary is
## paid in three unrelated files -- `Policy` for the sim, `SectorScreen` for a row
## that resolves in place, `EventScreen` for one that opened the detail view --
## and each held its own copy of the same two lines. They had already drifted:
## `EventScreen` never learned about `module`, so `salvage_rights` paid nothing
## through the only path it can actually be taken by. Nothing failed; the reward
## simply did not arrive.
##
## Batch 04 adds four more payload forms. Four forms across three hand-maintained
## sites is twelve chances to repeat that, so the sites now call this instead.
##
## `fight` is deliberately NOT handled here: it is the CALLER's business, because
## starting a battle means something different in a sim than on a screen. This
## function grants; it does not decide what happens next.
## Whether resolving this puts a THING in the system, as opposed to moving
## numbers around on your ship.
##
## One definition, because three places ask: `pay` to do it, and the two screens
## that resolve an option to decide whether there is a prize to open. It was
## `res.module` read separately in each, which is a fact about the reward model
## living in the UI -- and the moment a second kind of physical payout exists,
## two of the three would go on being right by accident.
## Close everything the option at `i` shares a group with.
##
## RULING 1's other half. The list shows what a choice forecloses; this is the
## foreclosing. A closed option is marked `taken` so nothing offers it again AND
## given `R_GONE`, so the card can say UNAVAILABLE rather than quietly not
## being there -- which is the difference between a rule and a disappearance.
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


static func pays_item(res: Dictionary) -> bool:
	return bool(res.get("module", false))


static func pay(res: Dictionary, n: MapGen.MapNode) -> String:
	if res.is_empty() or n == null:
		return ""
	var got: Array[String] = []
	if pays_item(res):
		# INTO THE SYSTEM, NOT INTO YOUR POCKET. `MATERIALS_NOTE` 3.6: if
		# something hands you a physical thing it hands you a CONTAINER, and you
		# reach in for it with your own hold open beside you.
		#
		# It was `Run.place_in_hold(...)` with the result thrown away, which
		# meant a reward you had earned quietly ceased to exist whenever the
		# hold was full -- 3.4's exact failure, in the one place where the game
		# is supposed to be paying you. A bag cannot fail that way: it sits in
		# the system until you take it or you jump, and if there is no room you
		# can see there is no room and decide what leaves.
		# NOT `n.bagged`. That flag means "the kill bag here has been rolled"
		# and `open_bag` refuses to fill a node that has it -- so an option
		# setting it would silently rob the next fight in this system of its
		# entire payout. An option cannot be taken twice anyway; `n.taken` is
		# what stops that.
		# THE FLOOR, not a wreck: nothing died to produce this, so it lands in
		# the system's own pile beside anything you have put down here.
		Run.sector_jetsam(n).items.append(LootGen.roll_module(n.danger))
	# THE ROLL IS POSITIONAL, like everything else a system decides about itself:
	# derived from the node index so a party at one system is handed the same
	# thing, and so a reload cannot shop for a better item.
	var r := Rng.derive(&"material", n.index)
	# WHAT THIS PUTS SOMEWHERE ELSE. The reward for some options is not a number
	# and not an object -- it is the encounter this plants four jumps deeper.
	if res.has("place"):
		var at := place(n, StringName(res.place))
		if at >= 0:
			got.append("%s MARKED" % quest_name(Run.map[at]))
	if res.has("material"):
		got.append(MaterialTable.grant(MaterialTable.roll(
			StringName(res.material), n.danger, r)))
	if res.has("material_id"):
		# NAMED, AND NOT TIER-GATED. Five options were written around a specific
		# item -- the text of `sweep_glass` describes the moment `the_sweep` hands
		# it over -- so gating the named drop would silently break the pairing the
		# prose depends on.
		got.append(MaterialTable.grant(
			MaterialTable.by_id(StringName(res.material_id))))
	if res.has("consume_material_tier"):
		# UNDER THE SHIM THIS IS THE LEDGER, not the hold. `holding_pattern` asks
		# for one exotic-TIER item and there are no items yet, so it spends the
		# live `exotic` counter -- which is the same thing today, because the
		# ledger is what exotic currently means. It becomes a hold search when
		# materials become items, in this function and nowhere else.
		Run.spend_material_tier(StringName(res.consume_material_tier))
	if bool(res.get("archive_recover", false)):
		# THIS SYSTEM'S DOCUMENT OR NONE. `Archive.at_node` derives from the
		# node's own index, so an option cannot conjure a document -- most systems
		# hold nothing, and the options that offer this pay credits regardless so
		# they stay honest on one that does.
		Archive.recover_at(n, "recovered here")
	got.erase("")
	return ", ".join(got)


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


## Put an option on a system ahead of this one, and say which.
##
## THE MECHANISM IS AN ARRAY APPEND. A system's encounters are `MapNode.options`
## and nothing else, so a consequence that travels is one id written onto a node
## you have not reached. It saves for free -- `options` is already in the file --
## and it survives a jump for the same reason the wrecks do: it is node state.
##
## THE TARGET IS DERIVED, NOT CHOSEN, and that is what makes this work in co-op
## without a single packet. `roll_for`'s note says options are positional
## because "what is AT a place is a property of the place and four machines must
## agree about it" -- a placement is NOT a property of the place, it is a
## consequence of what one ship did elsewhere, so it would have had to be
## replicated. Deriving the target from the SOURCE node's index instead makes it
## a property of the place after all: every machine that resolves the same
## option at the same system computes the same target and nobody has to be told.
##
## `ensure` FIRST, and this is the trap. It rolls a system's own options only
## when the list is EMPTY -- so appending to a system that has not been visited
## yet would leave it non-empty forever, and you would arrive at a place
## offering the quest and nothing else. Rolling it before appending is one line
## and the difference between a working thread and a content bug that surfaces
## months later.
##
## Returns the node index it landed on, or -1 if there was nowhere: near the
## core there may be no unvisited system deep enough, and a thread that never
## pays off is better than one that pays off in the wrong place.
const PLACE_DEPTH := 3

static func place(from: MapGen.MapNode, id: StringName) -> int:
	if from == null:
		return -1
	var what := by_id(id)
	if what.is_empty():
		return -1
	# A QUEST STANDS ALONE. An exclusive set is a choice between things that are
	# both there for you to weigh; a placed payoff is the consequence of
	# something you already did, and putting it in a group means the system it
	# lands on can foreclose it with an option that has nothing to do with the
	# thread. You would lose the delivery by bidding at an auction.
	#
	# Refused rather than stripped: a grouped quest is an authoring mistake, and
	# quietly ungrouping it here would hide the mistake in a place nobody looks.
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
			# ONE THREAD PER SYSTEM. Two payoffs landing on one node reads as a
			# coincidence rather than as a consequence, and the chart can only
			# mark it once.
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
	Sig.map_changed.emit()
	return at


## Does this system hold a placed encounter nobody has taken yet? The chart asks,
## to know whether to mark it.
## THE IDS THAT CAN ONLY BE PLACED, as a set, built once.
##
## `holds_quest` is asked of every system on the chart on every mouse-motion
## frame, and `by_id` is a linear walk of the whole table -- a hundred and ninety
## systems times three options times fifty rows is thirty thousand comparisons a
## frame for an answer that changes about twice a run. `_draw_work` solved the
## same problem by caching in the view; this fixes it at the source instead, so
## nothing downstream has to know it was ever expensive.
static var _placed: Dictionary = {}


static func placed_ids() -> Dictionary:
	if _placed.is_empty():
		for o in all():
			if bool(o.get("placed", false)):
				_placed[StringName(o.id)] = true
	return _placed


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
		# A partner's claim can arrive BEFORE the options it closes are rolled
		# here -- they took an exclusive option in a system this machine has
		# never visited. Foreclosure is derived from `taken`, so deriving it
		# again the moment the options exist catches everything adoption could
		# not resolve at the time.
		for t in n.taken:
			var i := int(t) - MapGen.OPTION_SITE
			if i >= 0 and i < n.options.size():
				foreclose(n, i)
	return not n.options.is_empty()



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
			id = &"dropped_load",
			title = "The dropped load",
			body = "Two ships sit either side of a drifting cargo pod, running lights on, weapons warm in the unenthusiastic way of crews who would rather be paid than shoot. Both are claiming it on the open channel. The pod is not saying anything — but its transponder log knows whose it is, and your dish is the only disinterested one in range.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			choices = [
				{label = "Read the log",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(50)
						return {text = "The log is unambiguous: dropped by the smaller ship two days ago in a bad burn. You transmit the timestamps, the bigger ship peels off without a word, and the owner pays a finder's rate for getting it back without shooting."},
					clean = func() -> Dictionary:
						Run.add_credits(30)
						return {text = "Readable enough. The loser argues, briefly, with somebody who can see the timestamps, and then stops."},
					partial = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "The log predates both ships. Neither of them owns it, and now all three of you know it — so it gets split three ways, fast, before anyone else arrives to know it too."},
					botched = func() -> Dictionary:
						Run.add_credits(-20)
						return {text = "You call it for the wrong ship, confidently. The right one leaves with the pod, and your reading fee goes back the way it came."}},
				{label = "Snatch it while they argue", fight = true, effect = func() -> Dictionary:
					Run.add_credits(40)
					return {text = "You burn in and take the thing both of them are shouting about. They stop shouting at each other.", fight = true, material = &"event"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "Two ships, one pod, and an open channel. It was going to be a long afternoon anyway."}},
			],
		},
		{
			id = &"long_claim",
			title = "The long claim",
			body = "A bare rock with a mineral seam glittering down one face, and no transponder anywhere on it — nobody works this far out, because hauling ore back costs more than the ore. The rich part of the seam runs under an overhang that has been deciding whether to come down for a very long time. A day of cutting. Nothing here is in a hurry and nothing is coming to help.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Work it", effect = func() -> Dictionary:
					Run.add_credits(45)
					return {text = "Most of a day, one cutting head, and enough off the seam to matter at the next station.", material = &"mining"}},
				{label = "Work it hard",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(70)
						return {text = "You take the seam and the shelf under it, and the frame does not complain once.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(55)
						Run.take_hull_damage(3, "You take more than the seam. Something in the forward bracing makes a noise it has not made before, then stops.")
						return {text = "You take more than the seam. Something in the forward bracing makes a noise it has not made before, then stops."},
					partial = func() -> Dictionary:
						Run.add_credits(30)
						Run.take_hull_damage(6, "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for and you are cutting by hand after that.")
						return {text = "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for and you are cutting by hand after that."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(12, "You are still under the overhang when the overhang decides.")
						return {text = "You are still under the overhang when the overhang decides."}},
				{label = "Move on", effect = func() -> Dictionary:
					return {text = "It has been here a long time. It is in no hurry."}},
			],
		},
		{
			id = &"slipping_orbit",
			title = "Slipping orbit",
			body = "A gas giant fills half the viewport, and it has you. Not badly — yet. You came in on a lazy transfer to save fuel and the well took the difference. The gauges give you perhaps four minutes to decide whether your engines are the answer.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			# A GAS GIANT FILLS HALF THE VIEWPORT. It cannot fill half of
			# anything at a system that does not have one.
			needs_giant = true,
			choices = [
				{label = "Burn out of the well",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(30)
						return {text = "You climb out of it like it was nothing, and on the way past you snatch a spar of old wreckage the well had collected. The alloy is worth thirty at the next dock."},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						return {text = "The engines find it, eventually, and drink fourteen units doing it."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 26)
						return {text = "You get out. The tank shows what it cost and you decide not to look at it again."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 40)
						return {text = "You skim the upper atmosphere on the way up. Forty units, and most of your paint."}},
				{label = "Ride it round", effect = func() -> Dictionary:
					return {text = "One slow orbit, no burn. It costs you nothing but the hour."}},
			],
		},
		{
			id = &"mine_drift",
			title = "Mine drift",
			body = "Old mines glint across the debris belt ahead — dozens, still keeping perfect station around the wreck they were set to guard. Whoever seeded them never came back for it. The wreck is still in there, hull whole, holds shut.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			choices = [
				{label = "Thread it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You go through the field like water through a grate, and lift a module off the wreck of somebody who did not.", module = true},
					clean = func() -> Dictionary:
						Run.take_hull_damage(5, "One of them finds your flank on the way out. Only one.")
						return {text = "One of them finds your flank on the way out. Only one."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(11, "Two, then a third. You reverse the last hundred metres with the hull ringing.")
						return {text = "Two, then a third. You reverse the last hundred metres with the hull ringing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(18, "The old ones are the worst. This one waits until you are past before it decides.")
						return {text = "The old ones are the worst. This one waits until you are past before it decides."}},
				{label = "Sweep wide", effect = func() -> Dictionary:
					return {text = "You give the whole drift a wide margin and lose nothing but time."}},
			],
		},
		{
			id = &"corona",
			title = "The corona",
			body = "The star here is mid-tantrum. It throws a flare every few hours, the instruments call the next one soon, and sitting close in, inside the glare, is a wreck with its holds intact. Everyone else has read the temperature and left.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 7,
			# THE STAR HERE IS MID-TANTRUM, which is a fact about the star and
			# not about how deep you are. Danger stays off it entirely: a
			# flare star on the rim is exactly as dangerous to sit next to.
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Go in hot",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(85)
						return {text = "Your vents hold the whole way in and the whole way out. Eighty-five credits out of a hold nobody else would reach.", material_id = &"corona_amber"},
					clean = func() -> Dictionary:
						Run.add_credits(45)
						Run.heat += 6
						return {text = "You come out carrying forty-five credits and a reactor that will need a minute."},
					partial = func() -> Dictionary:
						Run.add_credits(20)
						Run.heat += 12
						return {text = "You get one hold open and take what is nearest before the temperature makes the decision for you."},
					botched = func() -> Dictionary:
						Run.heat += 20
						return {text = "The flare comes early. You leave with nothing and a ship that is still ticking as it cools."}},
				{label = "Watch it burn", effect = func() -> Dictionary:
					return {text = "You hold station outside the corona and log the wreck for somebody with better vents."}},
			],
		},
		{
			id = &"the_wind",
			title = "The wind",
			body = "The star is shedding itself. A blue hypergiant burns through its own mass fast enough to notice, and what comes off it crosses this lane as a front you can read on the dish — thin, very fast gas, moving outward at a speed nothing here evolved to survive. It is going the way you are going.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Ride the front",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 20
						return {text = "You put the hull side-on for ninety seconds and let it take you. The tank does not fill; the distance simply stops costing anything."},
					clean = func() -> Dictionary:
						Run.fuel += 14
						return {text = "You catch the edge of it and hold, and the reactor spends the crossing idling."},
					partial = func() -> Dictionary:
						Run.fuel += 8
						Run.heat += 5
						return {text = "You catch it badly and spend the crossing correcting, which costs you most of what it gave."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(9, "The front takes the bow first and the rest of the ship follows, sideways.")
						return {text = "It takes the bow first and the rest of the ship follows, sideways, for longer than anyone aboard enjoys."}},
				{label = "Burn across it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You cross it at an angle, under power the whole way, and come out the far side having paid for every metre."}},
				{label = "Wait it out", effect = func() -> Dictionary:
					return {text = "You hold in the lee of nothing in particular until the front has gone past. It costs you the afternoon and nothing else."}},
			],
		},
		{
			id = &"the_glare",
			title = "The glare",
			body = "Everything on this approach is white. A blue hypergiant puts out more light in an hour than most stars manage in a year, and the dish is reading it as a wall — no returns, no shadows, nothing resolvable across a quarter of the sky. The last clean sweep before it whited out had something in it, ship-sized, holding still.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Go in on the last bearing",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "You fly the bearing and trust it, and the thing is exactly where the dish said before the dish stopped being any use. Nobody has been here first. There was never a reason for anybody to look, and it gives up its racks like it had been waiting for the excuse.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You find it on the third pass, which is two more than you wanted and one fewer than you had, and strip what you can reach before the light closes over it again.", module = true},
					partial = func() -> Dictionary:
						return {text = "You find where it was. Something came off it recently enough to still be nearby, and you take that instead.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You spend an hour inside the glare and come out with a hot hull and no idea whether you were ever within ten kilometres of it."}},
				{label = "Sweep the shadow side", effect = func() -> Dictionary:
					return {text = "You put the nearest body between yourself and the star and read the sliver of sky that leaves you. It is not where the contact was. It is where something smaller has been drifting for a while.", material = &"wreck"}},
				{label = "Log the bearing and go", effect = func() -> Dictionary:
					return {text = "You write down a number that will mean nothing to anybody who has not been here, and leave it in the archive for somebody who has."}},
			],
		},
		{
			id = &"the_scouring",
			title = "The scouring",
			body = "A hull has been parked in the wind of a blue hypergiant for a long time. Everything soft is gone — paint, markings, seals, the outer layer of everyone who was aboard — and what is left is structure and fittings, polished to bare metal and still bolted down. The star does the same to you at a slower rate the entire time you are alongside.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 7,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work it until you have to leave",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "Four hours alongside, and you come away with the racks and most of a reactor housing. Your own plating has a shine on the star-facing side that will not come off.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(3, "Three hours alongside a blue hypergiant, which is two hours longer than the plating wanted.")
						return {text = "Three hours, one rack, and a hull that needs looking at.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(7, "You stayed alongside until your own plating started arguing with you.")
						return {text = "You get one thing off it before the readings on your own plating start to argue with you.", module = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(12, "You misjudged how long is too long beside a blue hypergiant.")
						return {text = "You misjudge how long is too long. The wreck keeps its fittings and you leave with less hull than you arrived with."}},
				{label = "Take what is already loose", effect = func() -> Dictionary:
					return {text = "You work the drift downwind of it, where the star has done the removing for you.", material = &"wreck"}},
				{label = "Leave it polished", stay = true, effect = func() -> Dictionary:
					return {text = "It has been there long enough to be a landmark. It will be there considerably longer."}},
			],
		},
		{
			id = &"the_runner",
			title = "The runner",
			body = "She is nineteen at the outside and she is running somebody else's errand with somebody else's ship, and the thing she needs moved fits in one hand. No manifest, no filing, no name on it. She cannot pay much now. She says the one it goes to pays properly and pays on delivery, and she says it like somebody repeating a thing she was told rather than a thing she knows.",
			tags = [&"contract"],
			group = &"",
			weight = 7,
			max_security = 2,
			choices = [
				{label = "Take it quietly",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "It goes in a void behind the coolant run that nothing scans and nobody knows about. She watches you do it and does not ask what else is in there.", place = &"paid_in_full"},
					clean = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "You find somewhere for it that will hold up to an ordinary look.", place = &"paid_in_full"},
					partial = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "You stow it badly and spend the next shell aware of exactly where it is.", place = &"paid_in_full"},
					botched = func() -> Dictionary:
						return {text = "You are still finding somewhere for it when a patrol runs a courtesy sweep of the dock. Nothing comes of it. She sees the sweep and takes it back."}},
				{label = "Ask what it is", effect = func() -> Dictionary:
					return {text = "She tells you, or tells you something. Either way she takes it somewhere else, politely, and you do not see her again."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "She nods like she expected it and goes to ask the next ship along the rank."}},
			],
		},
		{
			# PLACED, NEVER ROLLED. `admits` refuses anything carrying this key,
			# so the only way to reach the buyer is to have taken the package.
			# Ungrouped on purpose -- see `place`: a quest that an auction can
			# foreclose is a consequence you can lose without touching it.
			id = &"paid_in_full",
			title = "Paid in full",
			body = "He is old, and he is not what you were expecting, and he has been waiting at this berth for eleven days for a thing that fits in one hand. He does not open it in front of you. He pays what she said he would pay, which is considerably more than she was in a position to promise, and then he asks — carefully, as though the answer matters — whether she looked well.",
			tags = [&"quest"],
			group = &"",
			placed = true,
			weight = 0,
			choices = [
				# NO FAILING BAND AND NOTHING TO DECLINE. `batch-03`: taxing a
				# reward the player earned four jumps ago teaches them not to
				# take the offer next time. Both of these are gains.
				{label = "Take the money", effect = func() -> Dictionary:
					Run.add_credits(150)
					return {text = "He pays in full, in cash, and thanks you in a register nobody has used on you in a while."}},
				{label = "Tell him she looked tired", effect = func() -> Dictionary:
					Run.add_credits(190)
					return {text = "He nods for a while. Then he pays you more than the agreed figure, and gives you a name at a yard two shells in who will fit you something at cost.", module = true}},
			],
		},
		{
			id = &"ghost_signal",
			title = "Ghost signal",
			body = "The dish is pulling a signal out of the background hiss — too regular to be a star, too weak to be a station, and it has not moved in the eleven minutes you have been listening to it. Resolving it means holding position and giving the dish everything.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Resolve it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(45)
						return {text = "A beacon, precursor-old, still transmitting on a cycle nothing alive uses. You cannot read the message, but the housing is precursor work, and somebody always pays for precursor."},
					clean = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "You pinpoint it, but the housing is fused to its mount by however many centuries it has been out here. You take instruments' worth of readings and sell those."},
					partial = func() -> Dictionary:
						return {text = "You chase it for an hour and it resolves into your own reactor harmonics, reflected off something you never find."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 12)
						return {text = "You follow it a long way before admitting it was never there. Twelve units of fuel, spent on a bearing."}},
				{label = "Log it and go", effect = func() -> Dictionary:
					return {text = "You write the bearing down. Someone with better ears can have it."}},
			],
		},
		{
			id = &"customs_cordon",
			title = "Customs cordon",
			body = "A revenue cutter holds station over a seized hull, two cold escorts off her flanks. She took it nine days ago, the impound paperwork is still grinding through, and until it clears the manifest is public — which is how you know what is still aboard. She is not stopping traffic. She is guarding cargo.",
			tags = [&"signal", &"fight"],
			group = &"",
			weight = 10,
			min_security = 3,
			choices = [
				{label = "Board her dark",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(30)
						return {text = "You go across cold and silent, close enough to read the cutter's hull number on the way past. They never look up, and the seized hold is exactly as public as its manifest said.", module = true},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You hold everything off but the reactor, and the reactor is what you pay with. One rack, six heat, no questions.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They get a partial return and hail you in before you reach it. The fine is forty credits and a lecture."},
					botched = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They light you up from two sides, and something in the cutter's escort decides you are worth the trouble.", fight = true}},
				{label = "Hail them and ask", effect = func() -> Dictionary:
					return {text = "You hail the cutter, ask what she is sitting on, and get told. It costs an afternoon and nothing else, and the hold stays sealed."}},
			],
		},
		{
			id = &"the_braid",
			title = "The braid",
			body = "Nine of them cross the dish in a line, big enough to read as terrain — megafauna running a migration lane older than anyone who could have named it, shedding a wake you could ride most of the way to the next ring. They are not hostile. They are also not paying attention, and the smallest is longer than your ship.",
			tags = [&"signal"],
			group = &"herd",
			weight = 7,
			needs_fauna = true,
			choices = [
				{label = "Ride the wake",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 18
						return {text = "You slot into the draught behind the third one and let it carry you. It never registers you were there."},
					clean = func() -> Dictionary:
						Run.fuel += 11
						return {text = "You hold the lane most of the way before the turbulence shrugs you out of it."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "You misjudge the interval and spend the whole run fighting the wash instead of using it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(14, "The fourth one changes its mind about the lane. You are close enough that the flank takes your dorsal plating with it.")
						return {text = "The fourth one changes its mind about the lane. You are close enough that the flank takes your dorsal plating with it."}},
				{label = "Take what they shed", effect = func() -> Dictionary:
					return {text = "You hold off the lane and collect what works loose in the wake. Their hides carry decades of accreted junk — plate, ice, and today, a whole rack off some ship that once got too close.", module = true, material_id = &"hide_scrap"}},
				{label = "Let them pass", effect = func() -> Dictionary:
					return {text = "Nine of them, in line, going somewhere. You wait, and then they are not there any more."}},
			],
		},
		{
			id = &"refinery_still_lit",
			title = "Refinery, still lit",
			body = "A Cygnet refinery hangs over a dead seam, stacks still glowing. It is running without a crew — cracking ore for nobody, four years since the last shift left, stacking the output in a yard nobody has come to empty. The stacks sit at working temperature. Working temperature is not survivable, which is why the yard is still full.",
			tags = [&"contract"],
			group = &"refinery",
			weight = 8,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Go in for the yard",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(60)
						return {text = "You work the yard in three passes with the vents wide and never once go amber. Four years of output, and you take what fits.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(40)
						Run.heat += 7
						return {text = "Two passes, and you leave with a full hold and a reactor that will want a minute.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.add_credits(25)
						Run.heat += 15
						return {text = "One pass. You come out with an armful and a cabin you cannot stand in."},
					botched = func() -> Dictionary:
						Run.heat += 24
						return {text = "A tower cycles while you are alongside it. You leave with nothing but the temperature."}},
				{label = "Shut it down first", effect = func() -> Dictionary:
					Run.add_credits(25)
					return {text = "Six hours to talk the control stack into standing down, and it stands down apologetically. The yard is cool by the time you reach it and half of what you wanted has cooked in place.", material = &"mining"}},
				{label = "Leave it running", stay = true, effect = func() -> Dictionary:
					return {text = "It will keep cracking a seam that stopped paying, and stacking a yard nobody comes to. Nothing you do here changes the second part."}},
			],
		},
		{
			id = &"the_sweep",
			title = "The sweep",
			body = "A beam sweeps across this arc every eleven seconds — a pulsar, close, older than anything with a name — and caught inside the sweep is a survey ship that got the interval wrong once. Eleven seconds gets you in. Eleven seconds gets you out. Doing both, carrying cargo, is the question.",
			tags = [&"hazard"],
			group = &"refinery",
			weight = 6,
			# A PULSAR, CLOSE. `min_danger 4` meant "deep enough to be
			# plausible"; this means there is one.
			needs_pulsar = true,
			choices = [
				{label = "Time the interval",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "Three intervals, three passes, and you are clear before the fourth. Whatever killed them was not the arithmetic — and the hull is crusted with what the beam leaves behind, which somebody grows rich refining.", module = true, material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.heat += 9
						return {text = "Two intervals. You take the rack you came for and eat most of the third pass getting clear.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You get inside, get turned around, and spend the gap finding the way back out."},
					botched = func() -> Dictionary:
						Run.heat += 26
						return {text = "You are still alongside when it comes round. The hull holds. Everything on the hull does not."}},
				{label = "Log the bearing", effect = func() -> Dictionary:
					return {text = "You mark the wreck, note the interval, and leave both for somebody with better vents and worse judgement."}},
			],
		},
		{
			id = &"tug_work",
			title = "Tug work",
			body = "A bulk hauler hangs crooked at the head of the dock queue, thrusters dead, nine ships stacked behind her. The dock's own tugs are committed for the next eleven hours, and every hour she sits there the dockmaster grows more interested in whose fault that is. She needs four minutes of somebody's engine, and a pilot willing to put their nose against a hull forty times their mass.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			needs_berth = true,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Put your nose on her",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(70)
						return {text = "Four minutes, one contact point, no scoring on either hull. The queue moves, and the dockmaster logs which ship did it."},
					clean = func() -> Dictionary:
						Run.add_credits(55)
						return {text = "Six minutes and a stripe down your flank that will polish out. The queue moves."},
					partial = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "You get her turned but not clear, and the yard tug that finally arrives gets paid the difference."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(8, "You put twelve tonnes of thrust into a hull that was not braced for it and both of you learn something.")
						return {text = "You put twelve tonnes of thrust into a hull that was not braced for it and both of you learn something."}},
				{label = "Sell her the fuel instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 20)
					Run.add_credits(85)
					return {text = "She cannot manoeuvre but she can burn. You sell her enough to get clear under her own power, at a rate she is in no position to argue with."}},
				{label = "Wait in the queue", effect = func() -> Dictionary:
					return {text = "Eleven hours. You are not going anywhere in particular, and neither is anyone else."}},
			],
		},
		{
			id = &"silt",
			title = "Silt",
			body = "A dust shoal hangs across the lane — fines and ice-grit, dense enough that the dish loses the far side of it. In the middle, one solid echo, ship-sized, unmoving. Going in means going in blind. The grit is slow and soft and there is a very great deal of it.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			needs_fauna = true,
			choices = [
				{label = "Feel your way in",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(40)
						return {text = "You go in on attitude jets and touch nothing on the way. It is a survey cutter, intact, nobody has been here first, and it gives up its fittings like it had been expecting somebody.", module = true},
					clean = func() -> Dictionary:
						return {text = "You clip something soft on the way in and it does not matter. The cutter's racks come away clean.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(30)
						return {text = "You find her, get one panel open, and lose your bearings badly enough that leaving becomes the priority."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(13, "Something in the shoal is harder than the rest of it and you find that out with your bow.")
						return {text = "Something in the shoal is harder than the rest of it and you find that out with your bow."}},
				{label = "Sweep the edge", effect = func() -> Dictionary:
					Run.add_credits(20)
					return {text = "You work the outside of the shoal where the grit is thin, and take what it has collected there. Nothing dramatic. Enough to matter.", material = &"wreck"}},
				{label = "Go round", effect = func() -> Dictionary:
					return {text = "It is a very large amount of dust and it is in no hurry."}},
			],
		},
		{
			id = &"the_queue",
			title = "The queue",
			body = "The dock queue is nine ships long and the dockmaster is honest about it: the queue is the queue. But the fourth ship has been fourth for two days — her charter fell through, and she is holding a slot she cannot use and cannot sell back. She can sell it sideways. The dockmaster does not mind who docks, as long as somebody does.",
			tags = [&"contract"],
			group = &"berth",
			weight = 9,
			needs_berth = true,
			min_development = MapGen.Development.CITY,
			choices = [
				{label = "Buy her slot", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "Forty-five credits and a transfer that takes about a minute. You dock nine ships early and she gets something out of two wasted days.", module = true}},
				{label = "Trade her fuel for it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 25)
					return {text = "She has no charter and no reason to sit here. You give her enough to leave and take the slot she was sitting on.", module = true}},
				{label = "Wait your turn", effect = func() -> Dictionary:
					return {text = "The queue is the queue. It moves, eventually, in the order it says it will."}},
			],
		},
		{
			id = &"cold_labour",
			title = "Cold labour",
			body = "A breaker's yard in Redline colours, and the crew is waving you in. They have a new cutting head and no confidence in it, and they would rather learn what it does wrong on somebody else's plating than on the hull they take apart next week. They are offering money to put your flank against it for an hour. They are very clear that they do not know what it will do.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 2,
			choices = [
				{label = "Give them the flank",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(95)
						return {text = "The head works exactly as advertised and your plating takes it without complaint. They pay, and they pay well, because now they know."},
					clean = func() -> Dictionary:
						Run.add_credits(80)
						Run.take_hull_damage(4, "It bites deeper than the spec said. You come away paid and scored.")
						return {text = "It bites deeper than the spec said. You come away paid and scored."},
					partial = func() -> Dictionary:
						Run.add_credits(40)
						Run.take_hull_damage(9, "It bites much deeper than the spec said, and they stop the test early and pay half.")
						return {text = "It bites much deeper than the spec said, and they stop the test early and pay half."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(17, "The head finds a seam. Somebody says a word and somebody else hits the cutoff, and afterwards everyone is very quiet and very apologetic.")
						return {text = "The head finds a seam. Somebody says a word and somebody else hits the cutoff, and afterwards everyone is very quiet and very apologetic."}},
				{label = "Rig them a target instead", effect = func() -> Dictionary:
					Run.add_credits(30)
					return {text = "You weld them a test target out of scrap plating from your own stores. It does not survive the afternoon, which was the point of it."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They take it well. Somebody out here will say yes to this before the week is out."}},
			],
		},
		{
			id = &"quarantine_flag",
			title = "Quarantine flag",
			body = "A station, dark, and a Calyx quarantine flag on every channel it owns. Eight days now. Nothing has gone in or out — and nothing has come to it either: no drones, no decontamination lighters, no Calyx hull anywhere on the dish. The flag is all there is. Two other ships sit off the exclusion line with you, reading the same nothing. Inside is a full station's worth of stock, and every hour the flag holds, it gets cheaper.",
			tags = [&"signal"],
			group = &"",
			weight = 7,
			min_security = 3,
			choices = [
				{label = "Read the flag",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(75)
						return {text = "The atmosphere reads clean, the hull sits at ambient, and no decontamination cycle has ever run. There is no outbreak behind the flag. There is a stock dispute wearing one — and a station very happy to sell to the first ship that notices. You are the first ship that notices.", module = true},
					clean = func() -> Dictionary:
						return {text = "Nothing on your instruments supports the flag. Nothing disproves it. You dock braced, buy fast, and leave loaded.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(25)
						return {text = "Half a read. You buy only what you can inspect through the airlock glass, and nothing that breathes on you."},
					botched = func() -> Dictionary:
						Run.add_credits(-50)
						return {text = "You read it wrong in the reassuring direction. The decontamination cycle you sit through afterwards costs more than the stock was worth."}},
				{label = "Wait with the others", effect = func() -> Dictionary:
					return {text = "Two ships are already doing this. In eight more days, one of you finds out."}},
			],
		},
		{
			id = &"counterweight",
			title = "Counterweight",
			body = "A habitation ring tumbles end over end ahead — detached from some station and never collected, one slow rotation every ninety seconds, everything inside still bolted down. The airlock comes past you once every ninety seconds. It is not moving fast. It is just never in the same place twice.",
			tags = [&"contract"],
			group = &"",
			weight = 7,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Match the tumble",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(50)
						return {text = "You match it, hold it, and walk aboard as though the floor had always been down. Somebody's whole life is still bolted to it.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(3, "You match it well enough. Getting back off is worse than getting on.")
						return {text = "You match it well enough. What you carry out you carry out one-handed, and getting back off is worse than getting on.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(20)
						Run.take_hull_damage(7, "You get one hand on it and the rotation takes the decision away from you.")
						return {text = "You get one hand on it and the rotation takes the decision away from you."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(15, "Ninety seconds is a long time to be wrong about which way something is going.")
						return {text = "Ninety seconds is a long time to be wrong about which way something is going."}},
				{label = "Take the outside", effect = func() -> Dictionary:
					Run.add_credits(25)
					return {text = "You do not try to board. You strip what is bolted to the exterior, on the pass, one piece at a time.", material = &"wreck"}},
				{label = "Leave it turning", stay = true, effect = func() -> Dictionary:
					return {text = "Once every ninety seconds, with everything still where somebody left it."}},
			],
		},
		{
			id = &"the_auction",
			title = "The auction",
			body = "Probate is clearing a dead crew's hold — no heirs, and the terms as blunt as Probate terms always are: the lot is sealed, the manifest is sealed, the buyer takes it as it lies. Two of the last three lots went for less than the fee. The third went for considerably more, and whoever bought it has not been seen since, in the good way. Bidding closes in an hour and there are four of you.",
			tags = [&"contract"],
			group = &"berth",
			weight = 7,
			needs_berth = true,
			choices = [
				{label = "Bid on it", cost_credits = 70, effect = func() -> Dictionary:
					Run.add_credits(-70)
					return {text = "Seventy credits and a seal broken in your own hold, forty minutes later, with nobody watching in case it is embarrassing.", module = true, material = &"event"}},
				{label = "Read the room instead",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(40)
						return {text = "You do not bid. You watch who does, and what the Probate clerk's face does when the third bidder names a number. Afterwards you know exactly which lot next week is worth having."},
					clean = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "You learn something about two of the bidders that will be worth knowing later."},
					partial = func() -> Dictionary:
						return {text = "You learn that everyone here is better at this than you are."},
					botched = func() -> Dictionary:
						Run.add_credits(-70)
						return {text = "You misread a nod as a bid and win a lot you did not want, at a price you did not choose.", material = &"event"}},
				{label = "Let it go", effect = func() -> Dictionary:
					return {text = "Sealed, unseen, as it lies. Somebody else's forty minutes."}},
			],
		},
		{
			id = &"escort",
			title = "Escort",
			body = "Three haulers and a courier hold station off your bow — unarmed, all headed the way you are, none of them happy about it. The only armed ship in the system has quoted them an escort price worth most of the run. They would rather pay you. They are not asking you to win anything. They are asking you to be visible, with weapons.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 11,
			max_security = 2,
			choices = [
				{label = "Take the contract", fight = true, effect = func() -> Dictionary:
					Run.add_credits(60)
					return {text = "You ride the flank for one ring. Something comes out of the shadow of the third moon and decides the convoy looks softer than it is.", fight = true}},
				{label = "Sell them the courier's slot", effect = func() -> Dictionary:
					Run.add_credits(50)
					return {text = "The courier is fast enough to outrun anything out here alone. You tell them so, take a cut for the advice, and the convoy splits."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They pay the other escort most of what the run is worth, and go, and you never learn how it ended."}},
			],
		},
		{
			id = &"nine_tonnes",
			title = "Nine tonnes of nothing",
			body = "A freight crate sits on the dock with someone standing beside it, and the pairing is wrong: the manifest says nine tonnes, the crate is sized for forty, and it reads warm on your sensors. He wants it moved one ring inward, above rate. He is very relaxed about you not asking. He is noticeably less relaxed about you opening it.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			max_security = 3,
			choices = [
				{label = "Open it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(110)
						return {text = "Reactor fuel, undeclared, in a casing rated for something duller. It is worth four times the freight and he knows it, which is why he renegotiates rather than argues."},
					clean = func() -> Dictionary:
						Run.add_credits(65)
						return {text = "Not what the manifest says. Not dangerous either. You take the job at a better rate."},
					partial = func() -> Dictionary:
						Run.add_credits(45)
						return {text = "You get the casing open, learn nothing useful, and get it closed before he notices. The rate stays the rate."},
					botched = func() -> Dictionary:
						return {text = "He notices. The job evaporates and so does he, and the crate goes with him."}},
				{label = "Just take the job", effect = func() -> Dictionary:
					Run.add_credits(45)
					return {text = "Nine tonnes, one ring inward, above rate, no questions. You have carried worse and asked less."}},
				{label = "Pass", stay = true, effect = func() -> Dictionary:
					return {text = "He finds somebody else inside the hour. The crate is still warm when it leaves."}},
			],
		},
		{
			id = &"ice",
			title = "Ice",
			body = "A comet — three kilometres of dirty ice on a long slow orbit, no transponder, never claimed, because there is nothing out here to sell water to. Under the crust it is volatiles and a little metal. The crust has been hardening since this system was warm, it is under compression, and it has opinions about being cut.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Cut deep",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 24
						return {text = "You take the crust off in sheets and get at the clean ice under it. Volatiles, water, and enough material in the tail to be worth the trip.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 18
						Run.take_hull_damage(3, "The crust goes where you did not want it to. You get most of what you came for and wear the rest.")
						return {text = "The crust goes where you did not want it to. You get most of what you came for and wear the rest."},
					partial = func() -> Dictionary:
						Run.fuel += 10
						Run.take_hull_damage(6, "The face calves while you are on it. You back off with a partial hold and a story.")
						return {text = "The face calves while you are on it. You back off with a partial hold and a story."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(14, "Three kilometres of compressed ice releases about eleven seconds of stored temper directly into your bow.")
						return {text = "Three kilometres of compressed ice releases about eleven seconds of stored temper directly into your bow."}},
				{label = "Skim the tail", effect = func() -> Dictionary:
					Run.fuel += 9
					return {text = "You do not touch the body. You run the tail and collect what it is already shedding, which is slower and entirely safe."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "A long ellipse, a hard crust, and nobody out here to sell water to. It will be back around in ninety years."}},
			],
		},
		{
			id = &"flare_shelter",
			title = "Flare shelter",
			body = "The star's readings are climbing — a big flare, about forty minutes out, and the instruments are sure of it. Two minutes away is a rock large enough to shadow you, and tucked behind it, a survey drone that has clearly been using it the same way for years. Forty minutes is enough to reach the rock. It is enough to strip the drone. It is not enough to be leisurely about either.",
			tags = [&"hazard"],
			group = &"",
			weight = 11,
			# The same star, from the other side: one is a hold worth reaching
			# through a flare, the other is forty minutes to get behind a rock.
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Shelter and strip",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "You take the shadow, take the drone apart in the dark, and come out the other side of the flare with a hold and a cold reactor.", module = true, material_id = &"survey_film"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get most of it done before the shadow starts to move and finish the rest in the light.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 17
						return {text = "You get the drone open and the flare arrives while you are inside the housing."},
					botched = func() -> Dictionary:
						Run.heat += 25
						return {text = "You misread the rock's rotation and spend the peak of it on the lit side."}},
				{label = "Just shelter", effect = func() -> Dictionary:
					return {text = "You put the rock between you and the star and wait it out doing nothing at all, which is the correct answer and a dull one."}},
				{label = "Outrun it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 16)
					return {text = "You leave before it peaks. It costs a burn you had not budgeted for and you never find out what was on the drone."}},
			],
		},
		{
			id = &"deadfall",
			title = "Deadfall",
			body = "Nine hundred metres of collapsed gantry lies across the approach — an orbital yard that came down on itself, not explosively, just structurally, over a decade of nobody paying for maintenance. It is still under tension in places and still lets go of a piece now and then. Under the middle of it is a fitting bay, and fitting bays are where the good parts are when the lights go out.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			choices = [
				{label = "Go under it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You pick a line through nine hundred metres of dead scaffolding and nothing so much as brushes you. The bay is exactly as it was left.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(4, "You get in, get the bay open, and take a glancing hit from something that let go behind you.")
						return {text = "You get in, get the bay open, and take a glancing hit from something that let go behind you.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(8, "Two hundred metres in, a span shifts across your line and you reverse out past a bay you can see and cannot reach.")
						return {text = "Two hundred metres in, a span shifts across your line and you reverse out past a bay you can see and cannot reach."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(16, "The thing about tension is that it is patient right up until it is not.")
						return {text = "The thing about tension is that it is patient right up until it is not."}},
				{label = "Work the outside", effect = func() -> Dictionary:
					Run.add_credits(20)
					return {text = "The perimeter of the field is safe enough and picked over enough. You take what the last four crews did not think was worth the lift.", material = &"wreck"}},
				{label = "Leave it lying", stay = true, effect = func() -> Dictionary:
					return {text = "Nine hundred metres of somebody's deferred maintenance. It will finish coming down eventually, on its own."}},
			],
		},
		{
			id = &"the_long_tow",
			title = "The long tow",
			body = "A ship hangs dead off your bow, hull lights running on battery, and her crew answers the hail immediately — reactor scrap, six people fine, which is the wrong way round for how these usually go. The dock on the far side of this system will take her, if she can get there. A tow is four hours of your engine at a load it was not built for, with a hull on your stern the whole way that does not steer.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			needs_berth = true,
			choices = [
				{label = "Take the tow",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(90)
						return {text = "Four hours, one heading, no drama. The dock takes her, and the dockmaster watches you come in with somebody else's ship on the line."},
					clean = func() -> Dictionary:
						Run.add_credits(75)
						Run.take_hull_damage(3, "Five hours and a stern mount you will want looked at. She gets there.")
						return {text = "Five hours and a stern mount you will want looked at. She gets there."},
					partial = func() -> Dictionary:
						Run.add_credits(25)
						return {text = "You get her most of the way before the load tells you it is done. A yard tug comes out for the last of it and takes most of the fee."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 18)
						return {text = "The line parts under load. Nobody is hurt and nothing is lost except four hours, a tow line, and a certain amount of dignity."}},
				{label = "Sell them a reactor start", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 15)
					Run.add_credits(70)
					return {text = "You have enough fuel aboard to bootstrap her cold reactor if they are not fussy about the margin you leave yourself. They are not fussy."}},
				{label = "Signal it in and go", effect = func() -> Dictionary:
					return {text = "You put their position on the emergency band and leave. Somebody will come. Somebody usually comes."}},
			],
		},
		{
			id = &"the_calf",
			title = "The calf",
			body = "A juvenile hangs beside a cold rock, calling — separated from its pod, warm on every instrument, waiting the way the young of everything wait when they are lost. They are all warm. It is why they are hunted, and somewhere behind you a hunter has posted a standing bounty for a tagged calf. The pod is two hours out, answering on a frequency your hull feels rather than hears.",
			tags = [&"signal"],
			group = &"herd",
			weight = 8,
			needs_fauna = true,
			choices = [
				{label = "Tag it for the bounty", effect = func() -> Dictionary:
					Run.add_credits(90)
					return {text = "A transponder dart, a confirmation ping, and money from a ship you never see. The calf carries the tag toward its pod. What reaches it before the pod does is not your business. The bounty terms say so, in writing."}},
				{label = "Herd it home",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 16
						return {text = "You put your hull where a parent would put its flank, and it follows you all the way in. The pod closes around it, and the wake of nine of them turning at once carries you further than it has any right to."},
					clean = func() -> Dictionary:
						Run.fuel += 8
						return {text = "It follows, eventually, after deciding twice that you are a threat. The pod's wake pays for some of what the herding cost."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "It bolts the wrong way twice and you spend an hour of burn undoing each one before it finally hears the pod itself."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(12, "It panics at exactly the wrong moment and its flank finds you at speed. It reaches the pod anyway. You limp.")
						return {text = "It panics at exactly the wrong moment and its flank finds you at speed. It reaches the pod anyway. You limp."}},
				{label = "Leave it calling", stay = true, effect = func() -> Dictionary:
					return {text = "The pod is two hours out. The hunter is closer. You do not stay to see which arrives first."}},
			],
		},
		{
			id = &"the_manifest",
			title = "The manifest",
			body = "A heat barge rides the lane inward under Korvan seal, and her master is hailing for a witness — the delivery protocols want a countersignature on the final leg, and nobody disinterested comes this deep twice. The seal declares nine hundred units, receipted. On your mass reading she sits four points heavy for nine hundred units of anything.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sign and ride along", effect = func() -> Dictionary:
					Run.add_credits(80)
					return {text = "You countersign, hold formation for the last leg, and watch the barge be somewhere else. The fee clears before you have finished deciding what you saw."}},
				{label = "Weigh her first",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(120)
						return {text = "Eleven hundred units against a receipt for nine. Somebody upstream is skimming into the vault and paying tax on the smaller number. You sign the honest figure, and the master pays you for the correction with the specific gratitude of someone now holding a problem that is not theirs."},
					clean = func() -> Dictionary:
						Run.add_credits(80)
						return {text = "The mass checks close enough. You sign, ride the leg, collect."},
					partial = func() -> Dictionary:
						Run.add_credits(15)
						return {text = "Your figures will not settle and the window will not wait. You decline to sign and she takes the long way to find another witness."},
					botched = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "You sign a number the vault's own scale later disagrees with, and the correction lands on the witness who signed it. You."}},
				{label = "Wave her past", effect = func() -> Dictionary:
					return {text = "She holds for another hour, hailing, and then risks the leg unwitnessed. Whatever she was four points heavy with goes wherever it was going."}},
			],
		},
		{
			id = &"the_last_berth",
			title = "The last berth",
			body = "The deepest dock still lit, and behind its counter, one clerk. She has been logging arrivals for traffic that stopped arriving before her posting began. Her rate sheet has not changed in eleven years, which makes her fuel the cheapest in the galaxy, and her archive drawer holds one folder — thick, unlabelled. She calls it the observations.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 8,
			regions = [MapGen.Region.DEEP],
			needs_berth = true,
			choices = [
				{label = "Fill the tank at her rates", cost_credits = 30, effect = func() -> Dictionary:
					Run.add_credits(-30)
					Run.fuel += 40
					return {text = "Thirty credits for what a rim station would charge ninety, off a sheet she sees no authority to amend. She stamps the receipt twice, because the second stamp is for the copy nobody collects."}},
				{label = "Ask about the folder", effect = func() -> Dictionary:
					Run.add_credits(20)
					return {text = "Other people's paperwork about the thing at the core — transit logs that stop mid-line, a mass estimate crossed out four times, a requisition for instruments that were never sent. She lets you copy it. She has been waiting eleven years for someone to ask.", archive_recover = true}},
				{label = "Leave her to the ledger", stay = true, effect = func() -> Dictionary:
					return {text = "One clerk, one drawer, one folder. Your arrival is the first entry she has logged in a while, and she logs it beautifully."}},
			],
		},
		{
			id = &"counting_backwards",
			title = "Counting backwards",
			body = "A dead relay hangs on the approach with its transponder alive, broadcasting a number, and the number is going down. Not counting toward anything the relay knows about — the interval between broadcasts is forty-one years, and it has been counting since before the manufacturers had names. Whatever it is counting toward, it is nearly there.",
			tags = [&"signal"],
			group = &"",
			weight = 7,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Pull the housing",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "The relay's core is precursor work, still warm after all this time, which out here is worth more than the metal. You take the housing and the number keeps counting in your hold, one digit smaller than anyone has ever seen it.", material_id = &"counting_core"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "The housing comes away hot and you carry it hot. The count continues, indifferent to the change of address.", material_id = &"counting_core"},
					partial = func() -> Dictionary:
						Run.add_credits(30)
						return {text = "The housing is fused to the relay by forty-one-year cycles of heat and cold. You take instruments' worth of readings and nothing else."},
					botched = func() -> Dictionary:
						Run.heat += 22
						return {text = "Whatever keeps the core warm objects to being handled, briefly and thoroughly."}},
				{label = "Record it and go", effect = func() -> Dictionary:
					Run.add_credits(35)
					return {text = "You log the number, the interval, and the bearing. Somebody will pay for a reading this deep, if anybody who takes readings is left."}},
				{label = "Let it count", effect = func() -> Dictionary:
					return {text = "Forty-one years to the next broadcast. You will not be here. Neither, possibly, will the number."}},
			],
		},
		{
			id = &"holding_pattern",
			title = "Holding pattern",
			body = "Six ships hold a loose ring ahead — engines cold, transponders on, hulls weathered enough that they arrived years apart. They are not a convoy and not a blockade, and every one of them is pointed the same way. Inward. Hail them and the only answer is a receipt code.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Trade with the waiting", needs_material = &"exotic", effect = func() -> Dictionary:
					Run.add_credits(95)
					return {text = "Whatever they are waiting for, they are provisioned for it, and they will pay warm-economy prices for anything that runs. You sell off the top of your stores to ships that thank you in receipt codes.", consume_material_tier = &"exotic"}},
				{label = "Read their receipts",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(70)
						return {text = "Six receipt codes, one issuing authority, and the authority is a vault. They have delivered — everything, by the empty holds — and they are waiting to be paid in whatever a vault pays. You copy the codes. Somebody inward will want to know what the queue looks like from outside."},
					clean = func() -> Dictionary:
						Run.add_credits(35)
						return {text = "The codes are vault-issued and sequential. Whatever queue this is, it is orderly, and it is old."},
					partial = func() -> Dictionary:
						return {text = "The codes decode to references in a ledger you will never see."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "You interrogate the nearest transponder hard enough that all six ships light their drives for exactly four seconds, in unison, and then go cold again. You leave before learning what that was."}},
				{label = "Hold station with them", effect = func() -> Dictionary:
					return {text = "You point inward, kill the engines, and sit in the ring for a while. Nothing happens. You suspect nothing happening is the whole activity."}},
			],
		},
		{
			id = &"the_favour",
			title = "The favour",
			body = "A courier is hailing everything with a tank. She is running on fumes — her charter pays on arrival, which is one ring further in than her fuel is, and she is offering over the odds because the alternative is drifting somewhere unfashionable until her company notices the delivery is late. She is not in danger. She is in debt, which out here takes longer to kill you.",
			tags = [&"contract"],
			group = &"",
			weight = 13,
			choices = [
				{label = "Sell her ten units", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					Run.add_credits(55)
					return {text = "Ten units across a line, at a rate that makes you both wince for different reasons. She is moving again before the transfer pump has cooled."}},
				{label = "Sell her twenty", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 20)
					Run.add_credits(100)
					return {text = "Enough to arrive with margin. She pays the rate without blinking, which tells you what the charter is worth, which stings slightly."}},
				{label = "Wish her luck", effect = func() -> Dictionary:
					return {text = "She thanks you with the particular politeness of somebody updating a list, and resumes hailing everything with a tank."}},
			],
		},
		{
			id = &"wrong_registry",
			title = "Wrong registry",
			body = "A delivery drone matches your course and runs a docking handshake older than your ship. It is carrying a consignment for a registry one digit off yours — a hull that may not have existed for decades — on a delivery clock so far overdue the penalty has wrapped around to zero. It will wait forever. It is built to.",
			tags = [&"signal"],
			group = &"",
			weight = 12,
			choices = [
				{label = "Accept the consignment", effect = func() -> Dictionary:
					return {text = "You spoof the digit and the drone unloads with the ceremony of a machine completing the only thing it was ever for. The consignment is sealed, addressed, and heavier than it looks. The drone leaves lighter in some way that has nothing to do with mass.", module = true, material = &"event"}},
				{label = "Correct its registry",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(45)
						return {text = "You give it the right registry off an old dock ledger, and it recalculates a delivery route to a hull that died before you were flying. It thanks you in protocol and burns for the grave. You keep the routing fee it insists on paying."},
					clean = func() -> Dictionary:
						Run.add_credits(25)
						return {text = "You give it a plausible registry. It accepts, recalculates, and leaves with purpose. Whether the purpose is achievable is not your department."},
					partial = func() -> Dictionary:
						return {text = "Its verification loop rejects everything you offer, politely, forever. You disengage before it finishes the fourth attempt."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "You feed it a malformed registry and something in its logic decides YOU are the addressee of every consignment on its manifest. It follows you to the edge of sensor range, waiting."}},
				{label = "Decline the handshake", stay = true, effect = func() -> Dictionary:
					return {text = "It holds formation for exactly one hour, then returns to its route. Somewhere out there is a registry one digit from yours, and its parcel is still coming."}},
			],
		},
		{
			id = &"dead_station",
			title = "Dead station",
			body = "A station hangs dark and unpowered, turning a little off true. The docking clamps still have pressure in them, which means the reactor died slowly enough for somebody to shut things down in order. There is no one aboard to ask about that.",
			tags = [&"salvage"],
			group = &"",
			weight = 12,
			choices = [
				{label = "Salvage the racks", effect = func() -> Dictionary:
					return {text = "You pull a module out of a dead bay, and clear the rack around it while you are in there. It all comes away on the first try, which it should not have, after this long.", module = true, material = &"wreck"}},
				{label = "Siphon the tanks", effect = func() -> Dictionary:
					Run.fuel += 12
					return {text = "Four jumps of fuel, tasting of rust."}},
			],
		},
		{
			id = &"distress_beacon",
			title = "Distress beacon",
			body = "A looping voice repeating coordinates one jump off your route, in the flat cadence of a recording that has been running a long time. Whatever is at the other end has been transmitting through a hull big enough to carry a real transmitter — so it is either worth reaching or worth avoiding, and the recording does not say which.",
			tags = [&"signal", &"fight"],
			group = &"",
			weight = 11,
			choices = [
				{label = "Answer it", fight = true, effect = func() -> Dictionary:
					return {text = "It was bait, and the hull it was broadcasting from is real — still loaded, still worth taking off whoever is currently using it as a hook. Something is already firing.", fight = true}},
				{label = "Read it from cover",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(40)
						return {text = "You sit off the coordinates and listen. The loop has a second signature under it, holding station and not moving, which tells you what this is. You sell the coordinates as a hazard note at the next dock."},
					clean = func() -> Dictionary:
						Run.add_credits(20)
						return {text = "Enough of the carrier resolves to tell you nobody aboard is alive to be rescued. That is worth logging, and a little to whoever buys logs."},
					partial = func() -> Dictionary:
						return {text = "You learn nothing except that it repeats every ninety seconds, which you could have counted from here."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You hold position long enough for the thing under the loop to get a good look at you, and you leave with your bloom up."}},
				{label = "Run silent", effect = func() -> Dictionary:
					Run.heat = 0
					return {text = "You cut the reactor and drift past it with everything dark. Heat cleared, and the voice goes on repeating behind you."}},
			],
		},
		{
			id = &"whale_fall",
			title = "Whale fall",
			body = "The corpse of something enormous, coming apart slowly in the dark and feeding a whole economy of smaller things while it does. It has been dead long enough to have a population. Most of them are too small to matter and a few of them are not, and all of them are busy.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			needs_fauna = true,
			choices = [
				{label = "Cut into it",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "You work the seam quietly, in the lee of the ribs, and come away loaded before anything that lives here decides you are worth interrupting a meal for.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "You take what you came for. Something the size of a hatch cover watches you do it and elects not to mind."},
					partial = func() -> Dictionary:
						Run.add_material(&"exotic", 1)
						Run.take_hull_damage(5, "Something feeding on the whale fall took an interest in the ship.")
						return {text = "Halfway through the cut the population decides collectively that you are competition. You leave with less than you wanted and a new set of scratches."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(11, "The whale fall was still occupied, and it objected.")
						return {text = "It is not the big ones. It is that there are so many of the small ones, and that they all arrive at once."}},
				{label = "Take what has come loose", effect = func() -> Dictionary:
					return {text = "There is enough drifting clear of it to fill a bay without cutting anything, or annoying anything.", material = &"fauna"}},
				{label = "Let it rest", effect = func() -> Dictionary:
					return {text = "You hold station a while and take nothing off it. It is doing something on its own schedule and will be doing it long after you are not."}},
			],
		},
		{
			id = &"inspection_sweep",
			title = "Inspection sweep",
			body = "A patrol is stopping everything through this lane, and the reason is parked behind them: a hauler pulled over two days ago and abandoned by its crew, its load sitting in the impound under a seizure notice nobody has come to execute. The queue moves slowly. Whatever is still in the impound at the end of the week goes to the breakers.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_security = 3,
			choices = [
				{label = "Wait your turn and bid on the load", cost_credits = 40, effect = func() -> Dictionary:
					var lost := Run.contraband_count()
					if lost > 0:
						Run.add_credits(-20 * lost)
						return {text = "They find what you are carrying and price it into the paperwork, and you pay both bills. What is left in the impound is still worth more than the morning cost you.", module = true}
					return {text = "Clean, waved through, and first in line for an impound nobody else waited out. The seizure clerk is glad of the company and the price is what it says on the notice.", module = true, material = &"wreck"}},
				{label = "Talk your way to the front",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(70)
						return {text = "Your registry says you are already cleared, because for the forty seconds it took them to read it, it did.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(30)
						return {text = "You come out of the queue two hours early and take the smaller half of the impound, which is still a half."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(4, "A patrol skiff crowded you off the impound gate.")
						return {text = "They notice, and the noticing is expensive in the way that costs paint rather than credits. You leave with nothing out of the impound."},
					botched = func() -> Dictionary:
						Run.add_credits(-45)
						return {text = "You are fined for the attempt, itemised, and made to wait anyway. The impound is empty by the time you reach it."}},
				{label = "Burn away", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 6)
					Run.take_hull_damage(4, "You ran the lane, and something clipped you on the way out.")
					return {text = "You run. Six fuel, four hull, no record — and the impound goes to the breakers on Friday without you."}},
			],
		},
		{
			id = &"derelict_hauler",
			title = "Derelict hauler",
			body = "An old freight frame, gutted down to structure and still holding its lines. Whoever stripped it took the fittings and left the thing they were bolted to, which is the opposite of the usual order and says they were in a hurry about something other than money.",
			tags = [&"salvage"],
			group = &"",
			weight = 6,
			min_danger = 2,
			choices = [
				{label = "Claim the hull", effect = func() -> Dictionary:
					Run.find_hull(LootGen.roll_hull(Run.node_at().danger))
					return {text = "The frame is flyable, which you establish the slow way: %s." % Run.found_hull.display_name()}},
				{label = "Strip it for scrap", effect = func() -> Dictionary:
					Run.add_credits(35)
					return {text = "Thirty-five credits of plating and wire, and a frame left a little more gutted than you found it.", material = &"wreck"}},
			],
		},
		{
			id = &"hostile_contact",
			title = "Hostile contact",
			body = "Something is holding station where nothing should be, and it has your registry already. No hail, no demand. It simply turns to face you.",
			tags = [&"fight"],
			group = &"",
			weight = 16,
			choices = [
				# TWO STATEMENTS, NOT ONE, and collapsing them broke RULING 5.
				#
				# `fight` in the RETURNED dictionary is the TRIGGER: it is what
				# `EventScreen._choose` reads to start the fight, and it is how
				# EventTable's two hostile endings have always worked. It is only
				# knowable by running the callable.
				#
				# `fight` on the CHOICE is a DECLARATION: this row leads to a
				# fight. The sector list has to print a contact reading BEFORE the
				# click, so it needs an answer that does not require resolving the
				# option first. Removing it made every hostile row print nothing.
				#
				# An outcome may still open a fight the choice did not declare --
				# that is a twist, and it is why the trigger is the runtime one.
				{label = "Engage", fight = true, effect = func() -> Dictionary:
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
						return {text = "The log is intact and says who they were owed money by. The debt is transferable, and so is everything still in the racks.", module = true},
					clean = func() -> Dictionary:
						return {text = "Enough of the log survives to say the hull is not booby-trapped, which is the part worth knowing. You strip it at your own pace.", module = true},
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
				{label = "Break it", fight = true, effect = func() -> Dictionary:
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
				{label = "Leave it to them", stay = true, effect = func() -> Dictionary:
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
					return {text = "You take what you came for. The notice is still transmitting when you leave, and it will be transmitting for a long time.", module = true}},
			],
		},
		{
			id = &"collapsed_lane",
			title = "Collapsed lane",
			body = "The short way on runs through a shipbreaker's yard, a lane of dead hulls packed too close to thread. Going around costs a day and a tank.",
			tags = [&"hazard"],
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
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "It tumbles on. The transponder is still going when it leaves sensor range."}},
			],
		},
	])
	return out
