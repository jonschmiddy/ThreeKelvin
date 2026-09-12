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


## HOW MUCH DEEPER IS WORTH, as a multiple of the same thing on the rim.
##
## MEASURED FIRST, and the measurement is why this exists. With every payout a
## literal, the ladder came out FLAT: average credits per tier read 50, 50, 49,
## 52, 56 from EASY to LETHAL, and the top prize was 190 at every tier including
## the first. Hull cost was flat from HARD up, and BRUTAL cost LESS than HARD.
## Depth controlled which encounters you met and nothing about what they were
## worth.
##
## It could not have been otherwise. THIRTY-ONE of forty-seven encounters span
## three tiers and four span all five, so one literal has to serve danger 3 and
## danger 8 at once. Narrowing every band would have worked and would have cost
## the table most of its range; scaling the number costs nothing.
##
## The author writes what a thing is worth ON THE RIM and the tier multiplies
## it. `pay(30)` is thirty credits at EASY and two hundred and sixteen at
## LETHAL.
##
## SAFE FOR THE PROSE, and that was checked before a line of this was written:
## of 207 outcome texts, ZERO quote a credit sum and only twenty contain a digit
## at all -- those count hours and racks, not money. The ledger rail under the
## result already prints what actually moved. So the words never have to agree
## with a figure, and the rule going forward is that they never may.
const PAY_SCALE: Array[float] = [0.0, 1.0, 1.8, 3.0, 4.7, 7.2]

## Hull is the currency depth is bought with, and it climbs less steeply than
## the reward on purpose -- 5.8x against 7.2x. A ladder where the cost outruns
## the prize is a ladder nobody climbs twice.
const TOLL_SCALE: Array[float] = [0.0, 1.0, 1.9, 3.0, 4.3, 5.8]


## The danger of the system this is resolving in. One for anywhere that has no
## node -- the simulator poses options without a map under them.
static func _here_danger() -> int:
	var n: MapGen.MapNode = Run.node_at()
	return 1 if n == null else n.danger


## What a rim-priced reward is worth here.
##
## NOT `pay`. That name was already taken by the function that turns a resolved
## outcome into the REWARD line -- a different job entirely, and the collision
## was a parse error rather than a silent shadow only because GDScript refuses
## two functions of one name.
static func purse(base: int) -> int:
	return maxi(1, int(round(float(base)
		* PAY_SCALE[MapGen.tier(_here_danger())])))


## What a rim-priced injury costs here.
static func toll(base: int) -> int:
	return maxi(1, int(round(float(base)
		* TOLL_SCALE[MapGen.tier(_here_danger())])))


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
	# INSIDE THE GAS, which every node already knows and no encounter could ask.
	# `in_nebula` is generated, saved, drawn on the chart and printed in the
	# destination panel's WARNING row -- it was the one sky fact with no gate, so
	# the category had zero content and no way to write any.
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
	# NOTHING USES THIS, AND THAT IS A RULING RATHER THAN AN ACCIDENT.
	#
	# `holding_pattern` was the only caller. `spend_material_tier` takes the FIRST
	# item of that tier it finds in the hold, so the encounter reached in and chose
	# for you -- tolerable while materials were a ledger counter, indefensible now
	# they are objects with names, values and cells. THE HOLD IS THE PLAYER'S.
	#
	# The mechanism stays because a future encounter might legitimately want to
	# take something NAMED that the player has already agreed to hand over. It must
	# not be used to take a tier and let the code pick.
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
			body = "Two ships sit either side of a drifting cargo pod. Both have running lights on and weapons warm. Neither crew looks keen on a fight. They would rather be paid than shoot. Both are claiming the pod on the open channel. The pod says nothing for itself. Its transponder log knows who dropped it. Your dish is the only one in range with no stake in the answer.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			max_danger = 8,
			choices = [
				{label = "Read the log",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The log is clear. The smaller ship dropped it two days ago in a bad burn. You send the timestamps out on the open channel. The bigger ship peels off without a word. The owner pays a finder's rate for getting the pod back with no shot fired."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The log reads well enough. The losing crew argues for a while. They are arguing with somebody who can see the timestamps. Then they stop."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The log is older than both ships. Neither crew owns the pod. Now all three of you know that. You split it three ways, fast, before another ship turns up to make it four."},
					botched = func() -> Dictionary:
						Run.add_credits(-20)
						return {text = "You call it for the wrong ship, and you sound sure of it. The right ship leaves with the pod. Your reading fee goes back the way it came."}},
				{label = "Snatch it while they argue", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "You burn in and take the pod both crews are shouting about. They stop shouting at each other. Then they both start shouting at you.", fight = true, material = &"event"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "Two ships, one pod, one open channel. You fly on and leave them to it. The arguing is still on the band long after the pod is behind you."}},
			],
		},
		{
			id = &"long_claim",
			title = "The long claim",
			body = "A bare rock turns off your bow with a mineral seam glittering down one face. There is no transponder on it anywhere. Nobody works this far out. Hauling ore back costs more than the ore is worth. The rich part of the seam runs under an overhang. That shelf has been about to come down for a long time. It is a day of cutting to take the seam. No other ship is out here, and none is coming.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Work it", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(38))
					return {text = "It takes most of a day and one cutting head. You come away with enough off the seam to sell at the next station.", material = &"mining"}},
				{label = "Work it hard",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						return {text = "You take the seam and the shelf under it as well. The frame does not complain once.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						Run.take_hull_damage(OptionTable.toll(3), "You take more than the seam. Something in the forward bracing makes a noise it has not made before, then stops.")
						return {text = "You take more than the seam. Something in the forward bracing makes a noise it has not made before, then stops."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						Run.take_hull_damage(OptionTable.toll(5), "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for. The rest of the seam stays in the rock.")
						return {text = "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for. The rest of the seam stays in the rock."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The overhang comes down while you are still under it. It lands on the bow and the rock takes the rest.")
						return {text = "The overhang comes down while you are still under it. It lands on the bow and the rock takes the rest."}},
				{label = "Move on", stay = true, effect = func() -> Dictionary:
					return {text = "You log the seam and leave the overhang where it is. No other ship is close enough to work it before you return."}},
			],
		},
		{
			id = &"slipping_orbit",
			title = "Slipping orbit",
			body = "A gas giant fills half the viewport. It has you. Not badly, not yet. You came in on a lazy transfer to save fuel, and the well took the difference. The gauges give you about four minutes to decide if the engines can do it. The dish reads something else on the same track. It is a spar of old wreckage, plate and frame both, that the well caught long ago. A hard burn climbs straight out and takes you past it, close enough to grapple. A slower burn gets out too and drinks the tank. One orbit costs you an hour and nothing else.",
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
						return {text = "You climb out of it like it was nothing. On the way past, the grapple takes the spar of old wreckage the well had collected.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						return {text = "The engines get you out of the well in the end. They drink fourteen units doing it."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 26)
						return {text = "You get out. The tank shows what it cost and you decide not to look at it again."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 40)
						return {text = "You skim the upper atmosphere on the way up. Forty units, and most of your paint."}},
				{label = "Ride it round", stay = true, effect = func() -> Dictionary:
					return {text = "One slow orbit, no burn. It costs you nothing but the hour."}},
			],
		},
		{
			id = &"mine_drift",
			title = "Mine drift",
			body = "Old mines glint across the debris belt ahead. There are dozens of them. They still keep perfect station around the ship they were set to guard. Whoever seeded them stopped answering a long time ago. Nobody came back for any of it. That ship is whole, hull unbreached, holds shut. Another hull lies further in, opened along one flank by something that was not the belt. A module is still racked in the open where the grapple could lift it. Some of the mines are too old to fire. From out here you cannot tell which ones.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Thread it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You go through the field like water through a grate. Somebody else did not. You lift a module off their wreck on the way out.", module = true},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "One mine finds your flank on the way out, and only the one.")
						return {text = "One mine finds your flank on the way out, and only the one."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Two of them hit, then a third. You reverse the last hundred metres with the hull ringing.")
						return {text = "Two of them hit, then a third. You reverse the last hundred metres with the hull ringing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The old mines are the worst. This one waits until you are past before it decides to fire.")
						return {text = "The old mines are the worst. This one waits until you are past before it decides to fire."}},
				{label = "Sweep wide", stay = true, effect = func() -> Dictionary:
					return {text = "You give the whole drift a wide margin and lose nothing but time. The mines keep station behind you. They are still there when the belt drops off the dish."}},
			],
		},
		{
			id = &"corona",
			title = "The corona",
			body = "The star here throws a flare every few hours. The instruments say the next one is due soon. Close in, inside the glare, a wreck sits with its holds intact. Every other ship read the temperature and left. The wreck's lit side has gone amber where the light baked the plating. It is thick enough for the cutter to take a plate off whole. The holds under it are still racked. Your vents have to carry that heat the whole way in and the whole way out. Nothing on the board says when the next one comes.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 7,
			min_danger = 5,
			# THE STAR HERE IS MID-TANTRUM, which is a fact about the star and
			# not about how deep you are. Danger stays off it entirely: a
			# flare star on the rim is exactly as dangerous to sit next to.
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Go in hot",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "Your vents hold the whole way in and the whole way out. The cutter takes a plate of the amber off the wreck's lit side. The star baked it there over years. The grapple pulls a rack out of a hold nobody else would reach.", material_id = &"corona_amber", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "The grapple takes one rack off the wreck. You come out with a reactor that needs a minute to cool.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "You get one hold open. The heat then makes the call for you, and you back off before anything comes out of it."},
					botched = func() -> Dictionary:
						Run.heat += 20
						return {text = "The flare comes early. You leave with nothing and a ship that is still ticking as it cools."}},
				{label = "Watch it burn", stay = true, effect = func() -> Dictionary:
					return {text = "You hold station outside the corona and log the wreck. Some ship with better vents can go in for it."}},
			],
		},
		{
			id = &"the_wind",
			title = "The wind",
			body = "The star is shedding itself. A blue hypergiant burns through its own mass fast enough to notice. What comes off it crosses this lane as a front. The dish reads it an hour out. It is thin gas, very fast, all of it moving outward the way you are going. Turn the hull side on and the gas carries the ship while the reactor idles. Meet it bow first and it takes the bow, and the rest of the ship follows. Crossing at an angle under power costs fuel and gets you through inside the hour. The front is most of a day wide. It will be past by the end of the afternoon.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Ride the front",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 20
						return {text = "You put the hull side on for ninety seconds and let the front take you. The tank does not fill. The distance simply stops costing you anything."},
					clean = func() -> Dictionary:
						Run.fuel += 14
						return {text = "You catch the edge of the front and hold it there. The reactor spends the whole crossing idling."},
					partial = func() -> Dictionary:
						Run.fuel += 8
						Run.heat += 5
						return {text = "You catch it badly and spend the crossing correcting. That costs you most of what the front gave you."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "The front takes the bow first. The rest of the ship follows it, sideways.")
						return {text = "The front takes the bow first, and the rest of the ship follows it sideways. It goes on for longer than anyone aboard enjoys."}},
				{label = "Burn across it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You cross the front at an angle, under power the whole way. You come out the far side having paid for every metre."}},
				{label = "Wait it out", stay = true, effect = func() -> Dictionary:
					return {text = "You hold in the lee of nothing in particular until the front has gone past. It costs you the afternoon and nothing else."}},
			],
		},
		{
			id = &"the_glare",
			title = "The glare",
			body = "Everything on this approach is white. A blue hypergiant puts out more light in an hour than most stars manage in a year. The dish reads it as a wall. No returns, no shadows, nothing you can pick out across a quarter of the sky. The last clean sweep before the dish whited out had something in it. It was ship sized and it was holding still.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Go in on the last bearing",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "You fly the bearing and trust it. The thing is exactly where the dish said it was. Nobody has been here first. There was never a reason for anybody to look. It gives up its racks like it had been waiting for the excuse.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You find it on the third pass. That is two more than you wanted and one fewer than you had. You strip what you can reach before the light closes over it again.", module = true},
					partial = func() -> Dictionary:
						return {text = "You find the place where it was. Something came off it not long ago and is still nearby. You take that instead and go.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You spend an hour inside the glare. You come out with a hot hull. You have no idea whether you ever got within ten kilometres of it."}},
				{label = "Sweep the shadow side", effect = func() -> Dictionary:
					return {text = "You put the nearest rock between yourself and the star. That leaves you a sliver of sky to read. The contact is not in it. Something smaller is, and it has been drifting there a while.", material = &"wreck"}},
				{label = "Log the bearing and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and the time, and you put both in the archive. Then you turn out of the glare and take the long way in. The white stays on the dish for another hour."}},
			],
		},
		{
			id = &"the_scouring",
			title = "The scouring",
			body = "A hull sits in the wind of a blue hypergiant. It has been there a long time. Everything soft on it is gone. The paint, the markings, the seals, and the outer layer of everyone aboard. What is left is frame and fittings, polished to bare metal and still bolted down. The star does the same to your plating the whole time you are alongside. It works slower on you than it did on them.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work it until you have to leave",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "Four hours alongside, and the grapple takes the racks. Most of a reactor housing comes off with them. Your own plating keeps a shine on the star-facing side that will not come off.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Three hours alongside a blue hypergiant is two hours too many. The plating gives out on the star-facing side.")
						return {text = "Three hours, one rack, and a hull that needs looking at.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "You stayed alongside longer than the plating could take. The star went through it and into the frame.")
						return {text = "You get one rack off it and no more. Then the readings on your own plating start to argue with you.", module = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You misjudged how long is too long beside a blue hypergiant. The star cut through your plating while you worked.")
						return {text = "You misjudge how long is too long. The wreck keeps its fittings and you leave with less hull than you arrived with."}},
				{label = "Take what is already loose", effect = func() -> Dictionary:
					return {text = "You work the drift downwind of the hull instead. The star has already stripped all of that loose for you.", material = &"wreck"}},
				{label = "Leave it polished", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off and take nothing off it. The hull keeps its fittings and the star goes on polishing it."}},
			],
		},
		{
			id = &"the_runner",
			title = "The runner",
			body = "She is nineteen at the outside. She is running somebody else's errand in somebody else's ship. The thing she needs moved is small enough to fit in a pocket. No manifest, no filing, no name on it. She cannot pay much now. She says the one it goes to pays properly, and pays on delivery. She says it like somebody repeating what she was told. It does not sound like a thing she knows.",
			tags = [&"contract"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 8,
			max_security = 2,
			choices = [
				{label = "Take it quietly",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "It goes into a void behind the coolant run that nothing scans. Nobody else knows the void is there. She watches you stow it and does not ask what else is in there.", place = &"paid_in_full"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You find a place for it inside the ship. That place will hold up to an ordinary look.", place = &"paid_in_full"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You stow it badly. For the whole next shell you know exactly where it sits.", place = &"paid_in_full"},
					botched = func() -> Dictionary:
						return {text = "You are still finding somewhere for it when a patrol runs a courtesy sweep of the dock. Nothing comes of it. She sees the sweep and takes it back."}},
				{label = "Ask what it is", stay = true, effect = func() -> Dictionary:
					return {text = "She tells you, or tells you something. The parcel stays in her pocket and she stays at the rank, waiting on an answer."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "She nods like she expected it. She goes to ask the next ship along the rank."}},
			],
		},
		{
			# PLACED, NEVER ROLLED. `admits` refuses anything carrying this key,
			# so the only way to reach the buyer is to have taken the package.
			# Ungrouped on purpose -- see `place`: a quest that an auction can
			# foreclose is a consequence you can lose without touching it.
			id = &"paid_in_full",
			title = "Paid in full",
			body = "He is old, and he is not what you were expecting. He has been waiting at this dock for eleven days. The thing he is waiting for is one small sealed package. He does not open it where you can see. He pays what she said he would pay. It is a lot more than she was in any position to promise. Then he asks whether she looked well. He asks it carefully, like the answer matters.",
			tags = [&"quest"],
			group = &"",
			placed = true,
			weight = 0,
			choices = [
				# NO FAILING BAND AND NOTHING TO DECLINE. `batch-03`: taxing a
				# reward the player earned four jumps ago teaches them not to
				# take the offer next time. Both of these are gains.
				{label = "Take the money", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He pays in full and he pays in cash. Then he thanks you. Nobody has used that tone of voice on you in a long while."}},
				{label = "Tell him she looked tired", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He nods for a long while. Then he pays you more than the agreed rate. He gives you a name at a yard two shells in. They will fit you something at cost.", module = true}},
			],
		},
		{
			id = &"ghost_signal",
			title = "Ghost signal",
			body = "The dish is pulling a signal out of the background hiss. It is too regular to be a star. It is too weak to be a station. You have listened for eleven minutes and it has not moved. It has not drifted a second of arc either. Whatever is sending it is bolted to something solid. The chart shows nothing at that bearing. To resolve it you hold position and give the dish everything. A dish given everything will chase your own reactor harmonics out to a bearing. Then it spends your fuel getting there.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Resolve it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "A beacon, precursor-old, still sending on a cycle nothing alive uses. You cannot read a word of it. The housing is precursor work. It comes off its mount on the grapple and into the hold.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You pinpoint it, and the housing is fused to its mount and will not come off. Nobody knows how many centuries it has been out here. You take the readings instead. They are shot straight off the dish and never developed.", material_id = &"survey_film"},
					partial = func() -> Dictionary:
						return {text = "You chase it for an hour and it will not come clear. In the end it is your own reactor harmonics. They came back to you off something you never find."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 12)
						return {text = "You follow it a long way before admitting it was never there. Twelve units of fuel, spent on a bearing."}},
				{label = "Log it and go", stay = true, effect = func() -> Dictionary:
					return {text = "You write the bearing down and move on. Some ship with a better dish than yours can have it."}},
			],
		},
		{
			id = &"customs_cordon",
			title = "Customs cordon",
			body = "A revenue cutter holds station over a seized hull, with two cold escorts off its flanks. Its crew seized that hull nine days ago. The impound paperwork is still grinding through. Until the paperwork clears, the manifest is public, and it lists what is still aboard. The cutter lets traffic through. It is here to guard the cargo.",
			tags = [&"signal", &"fight"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			min_security = 3,
			choices = [
				{label = "Board it dark",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You go across cold and silent, close enough to read the cutter's hull number. Nobody on it looks up. The seized hold is as open as its manifest said.", module = true},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You hold everything off but the reactor, and the reactor is what you pay with. One rack, six heat, no questions.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They get a partial return and hail you in before you reach it. You pay the fine and sit through the lecture."},
					botched = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They light you up from two sides at once. Something in the cutter's escort decides you are worth the trouble.", fight = true}},
				{label = "Hail them and ask", stay = true, effect = func() -> Dictionary:
					return {text = "You hail the cutter, ask what it is sitting on, and get told. It costs an afternoon and nothing else, and the hold stays sealed."}},
			],
		},
		{
			id = &"the_braid",
			title = "The braid",
			body = "Nine of them cross the dish in a line. They are big enough that the dish reads them as terrain. They are megafauna, running a lane older than anyone who could have named it. The wake behind them would carry you most of the way to the next ring. They are not hostile. They are also not paying attention. The smallest one is longer than your ship.",
			tags = [&"signal"],
			group = &"herd",
			weight = 7,
			min_danger = 3,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Ride the wake",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 18
						return {text = "You slot into the draught behind the third one and let it carry you. It never notices you were there at all."},
					clean = func() -> Dictionary:
						Run.fuel += 11
						return {text = "You hold the lane most of the way. Then the wash shrugs you out of it and the wake closes over."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "You misjudge the gap and drop in late. You spend the whole run fighting the wash instead of riding it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The fourth one changes its mind about the lane. You are far too close in when it turns. Its flank takes your dorsal plating away with it.")
						return {text = "The fourth one changes its mind about the lane. You are far too close in when it turns. Its flank takes your dorsal plating away with it."}},
				{label = "Take what they shed", effect = func() -> Dictionary:
					return {text = "You hold off the lane and collect what works loose in the wake. Their hides carry decades of junk. There is plate and there is ice. Today there is also a whole rack off some ship that got too close.", module = true, material_id = &"hide_scrap"}},
				{label = "Let them pass", stay = true, effect = func() -> Dictionary:
					return {text = "Nine of them, in line, going somewhere. You hold off and wait. The dish clears, and then they are not there any more."}},
			],
		},
		{
			id = &"refinery_still_lit",
			title = "Refinery, still lit",
			body = "A Cygnet refinery hangs over a dead seam with its stacks still glowing. It is running without a crew. It cracks ore for nobody and stacks the output in a yard. Four years since the last shift left, and nobody has come to empty it. The stacks sit at working temperature, and working temperature is not survivable. The yard is still full.",
			tags = [&"contract"],
			group = &"refinery",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Go in for the yard",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(33))
						return {text = "You work the yard in three passes with the vents wide and never once go amber. Four years of output, and you take what fits.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.heat += 7
						return {text = "Two passes is all you get. You leave with a full hold and a reactor that will want a minute.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						Run.heat += 15
						return {text = "One pass, and the hold takes what little the grapple reaches. The cabin gets too hot to sit in."},
					botched = func() -> Dictionary:
						Run.heat += 24
						return {text = "A tower cycles while you are still alongside it. You leave with nothing at all and a reactor running hot."}},
				{label = "Shut it down first", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "Six hours to talk the control stack into standing down. It stands down and sounds sorry about it. The yard is cool by the time you reach it. Half of what you wanted has cooked in place.", material = &"mining"}},
				{label = "Leave it running", stay = true, effect = func() -> Dictionary:
					return {text = "It goes on cracking a seam that stopped paying. It goes on stacking a yard nobody comes to empty. You leave the stacks lit behind you."}},
			],
		},
		{
			id = &"the_sweep",
			title = "The sweep",
			body = "A beam sweeps across this arc every eleven seconds. The pulsar is close and old, and it keeps the interval to the fraction. Caught inside the sweep is a survey ship that got the arithmetic wrong once. Its instrument rack is still mounted on the dorsal spine. Eleven seconds gets you in. Eleven seconds gets you out. Cutting the rack free takes longer than one gap. So some of the work happens with the beam on the hull. It puts heat in faster than the radiators shed it. It also leaves a glass crust that a refinery will buy.",
			tags = [&"hazard"],
			group = &"refinery",
			weight = 6,
			min_danger = 7,
			# A PULSAR, CLOSE. `min_danger 4` meant "deep enough to be
			# plausible"; this means there is one.
			needs_pulsar = true,
			choices = [
				{label = "Time the interval",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "Three intervals, three passes, and you are clear before the fourth. The arithmetic did not kill them. Something else did. The hull comes away crusted with what the beam leaves behind. A refinery pays for that crust.", module = true, material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.heat += 9
						return {text = "Two intervals. You take the rack you came for and eat most of the third pass getting clear.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You get inside and get turned around. You spend the gap finding the way back out."},
					botched = func() -> Dictionary:
						Run.heat += 26
						return {text = "You are still alongside when the beam comes around. The hull holds, and what is bolted to the outside of it cooks."}},
				{label = "Log the bearing", stay = true, effect = func() -> Dictionary:
					return {text = "You mark the wreck and you note the interval. You leave both of them for somebody with better vents than you have."}},
			],
		},
		{
			id = &"tug_work",
			title = "Tug work",
			body = "A bulk hauler hangs crooked at the head of the dock queue. Its thrusters are dead and nine ships are stacked behind it. The dock has tugs of its own. All of them are booked for the next eleven hours. Every hour it sits there the dockmaster gets keener to know whose fault it is. Its pilot needs four minutes of somebody else's engine. It has to come from a ship willing to put its nose on a hull forty times its mass.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			needs_berth = true,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Put your nose on it",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Four minutes, one contact point, no scoring on either hull. The queue starts moving again. The dockmaster logs which ship did it."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(31))
						return {text = "Six minutes, and a stripe down your flank that will polish out. The queue starts moving again."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You get it turned, but you do not get it clear. A yard tug comes out in the end and gets paid the difference."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You put twelve tonnes of thrust into a hull that was not braced for it. It gives way, and your bow goes in with it.")
						return {text = "You put twelve tonnes of thrust into a hull that was not braced for it. It gives way, and your bow goes in with it."}},
				{label = "Sell her the fuel instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 20)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Her ship cannot steer. It can still burn fuel. You pump her enough to get clear under her own power. The rate is one she is in no position to argue with."}},
				{label = "Wait in the queue", stay = true, effect = func() -> Dictionary:
					return {text = "Eleven hours in the queue. The hauler is still crooked at the head of it when your turn comes."}},
			],
		},
		{
			id = &"silt",
			title = "Silt",
			body = "A dust shoal hangs across the lane, fines and ice-grit together. It is dense enough that the dish loses the far side of it. In the middle sits one solid echo, hard and whole and ship-sized. It holds its shape while the shoal turns around it. Going in means going in blind on attitude jets. You go slow, because anything harder than dust becomes a real question. The near edge is thin enough to see through. It has been catching what drifts down this lane for years. Plate, loose fittings, and ice with metal frozen through it.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 6,
			choices = [
				{label = "Feel your way in",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in on attitude jets and touch nothing on the way. It is a survey cutter, intact. Nobody has been here first. It gives up a rack and the fittings around it without a fight.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You clip something soft on the way in and it does not matter. The cutter's racks come away clean.", module = true},
					partial = func() -> Dictionary:
						return {text = "You find it and you get one panel open. Then you lose your bearings in the dust. Getting out again becomes the only job you have."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Something in the shoal is a lot harder than dust. You find that out with your bow at speed.")
						return {text = "Something in the shoal is a lot harder than dust. You find that out with your bow at speed."}},
				{label = "Sweep the edge", effect = func() -> Dictionary:
					return {text = "You work the outside of the shoal where the grit is thin. You take what has collected there over the years.", material = &"wreck"}},
				{label = "Go round", stay = true, effect = func() -> Dictionary:
					return {text = "You put the shoal on your beam and fly around it. The echo in the middle is still there when you look back."}},
			],
		},
		{
			id = &"the_queue",
			title = "The queue",
			body = "The dock queue is nine ships long and the dockmaster is honest about it: the queue is the queue. But the fourth ship has been fourth for two days. The pilot's charter fell through, and she is holding a slot she cannot use and cannot sell back. She can sell it sideways. The dockmaster does not mind who docks, as long as somebody does.",
			tags = [&"contract"],
			group = &"berth",
			weight = 9,
			min_danger = 3,
			max_danger = 8,
			needs_berth = true,
			min_development = MapGen.Development.CITY,
			choices = [
				{label = "Buy her slot", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "You pay her, and the transfer takes about a minute. You dock nine ships early, and she gets something out of two wasted days.", module = true}},
				{label = "Trade her fuel for it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 25)
					return {text = "She has no charter and no reason to sit here. You give her enough to leave and take the slot she was sitting on.", module = true}},
				{label = "Wait your turn", stay = true, effect = func() -> Dictionary:
					return {text = "The queue is the queue. It moves, eventually, in the order it says it will."}},
			],
		},
		{
			id = &"cold_labour",
			title = "Cold labour",
			body = "A breaker's yard in Redline colours. The crew there is waving you in. They have a new cutting head and no faith in it at all. They would rather learn what it does wrong on somebody else's plating than on the hull they take apart next week. They will pay you to hold your flank against the head for an hour. They are very clear that they do not know what it will do.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			max_danger = 8,
			min_danger = 3,
			choices = [
				{label = "Give them the flank",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The head works just as the spec said it would. Your plating takes it without complaint. They pay, and they pay well, because now they know."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "It bites deeper than the spec said. You come away paid, and scored down one flank.")
						return {text = "It bites deeper than the spec said. You come away paid, and scored down one flank."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(4), "It bites much deeper than the spec said. They stop the test early and pay you half of it.")
						return {text = "It bites much deeper than the spec said. They stop the test early and pay you half of it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The head finds a seam and goes through it. Somebody shouts, and somebody else hits the cutoff. The yard is very quiet after that, and very sorry.")
						return {text = "The head finds a seam and goes through it. Somebody shouts, and somebody else hits the cutoff. The yard is very quiet after that, and very sorry."}},
				{label = "Rig them a target instead", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(17))
					return {text = "Your cutter shapes them a test target. It comes out of scrap plating from your own hold. The new head has it in pieces by the end of the afternoon."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They take it well. The yard is waving at the next ship along before you are clear of the dock."}},
			],
		},
		{
			id = &"quarantine_flag",
			title = "Quarantine flag",
			body = "A station sits dark with a Calyx quarantine flag on every channel it owns. It has been eight days. Nothing has gone in or out. Nothing has come to it either. No drones, no decontamination lighters, no Calyx hull anywhere on the dish. The flag is all there is. Two other ships hold off the exclusion line with you, reading the same nothing. Inside is a full station's worth of stock. Every hour the flag holds, that stock gets cheaper.",
			tags = [&"signal"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 8,
			min_security = 3,
			choices = [
				{label = "Read the flag",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						return {text = "The atmosphere reads clean and the hull sits at ambient. No decontamination cycle has ever run here. The flag is covering a stock dispute. The station is glad to sell to the first ship that turns up.", module = true},
					clean = func() -> Dictionary:
						return {text = "Nothing on your instruments backs the flag up and nothing knocks it down. You dock braced, you buy fast, and you leave loaded.", module = true},
					partial = func() -> Dictionary:
						return {text = "Half a read. You buy one crate you can inspect through the airlock glass, and nothing that breathes on you.", material = &"event"},
					botched = func() -> Dictionary:
						Run.add_credits(-50)
						return {text = "You read it wrong, in the direction you wanted to read it. Then you sit through a decontamination cycle. It costs you more than the stock was ever worth."}},
				{label = "Wait with the others", stay = true, effect = func() -> Dictionary:
					return {text = "Two other ships are already doing this, off the same exclusion line. In eight more days one of you finds out what the flag was."}},
			],
		},
		{
			id = &"counterweight",
			title = "Counterweight",
			body = "A habitation ring tumbles end over end ahead, one turn every ninety seconds. It came off some station. Nobody ever collected it. Everything inside is still bolted down where it was fitted. The yard at the settlement one jump in buys ring fittings by the tonne. It does not ask which ring. Outside there is plating, and there are antenna mounts. They come past on every pass. So does the airlock, slow, and never in the same place twice. The ring masses more than your ship. It turns at the same rate the whole time you work.",
			tags = [&"contract"],
			group = &"",
			weight = 7,
			min_danger = 5,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Match the tumble",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You match the tumble and hold it, steady enough that the ring might as well be still. The grapple works through the lock and takes out what the yard will weigh. Somebody's whole life is still bolted in there.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "You match it well enough. Backing the ship out is worse than going in was.")
						return {text = "You match it well enough. The grapple reaches one rack through the lock and no more. Backing the ship out is worse than going in was.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						Run.take_hull_damage(OptionTable.toll(2), "The grapple gets one bite of it. Then the rotation takes the decision away from you.")
						return {text = "The grapple gets one bite of it. Then the rotation takes the decision away from you."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You get the direction of the spin wrong. Ninety seconds is a long time to be wrong about that.")
						return {text = "You get the direction of the spin wrong. Ninety seconds is a long time to be wrong about that."}},
				{label = "Take the outside", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(8))
					return {text = "You do not go inside. The grapple takes what is bolted to the exterior, one piece at a time, on the pass.", material = &"wreck"}},
				{label = "Leave it turning", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the ring where it is and let it turn. It comes back around once every ninety seconds. All of it is still bolted down in there."}},
			],
		},
		{
			id = &"the_auction",
			title = "The auction",
			body = "Probate is clearing a dead crew's hold. There are no heirs. The terms are as blunt as Probate terms always are. The lot is sealed, the manifest is sealed, and the buyer takes it as it lies. Two of the last three lots went for less than the fee. The third went for a great deal more. Whoever bought that one has not been seen since, in the good way. Bidding closes in an hour and there are four of you.",
			tags = [&"contract"],
			group = &"berth",
			weight = 7,
			min_danger = 5,
			needs_berth = true,
			choices = [
				{label = "Bid on it", cost_credits = 70, effect = func() -> Dictionary:
					Run.add_credits(-70)
					return {text = "You pay the fee and take the lot as it lies. Forty minutes later the seal comes off in your own hold. Nobody is watching, in case it turns out to be embarrassing.", module = true, material = &"event"}},
				{label = "Read the room instead",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(13))
						return {text = "You do not bid. You watch who does. You watch the Probate clerk's face when the third bidder names a price. Afterwards you know which lot next week is worth having, and you sell what you know."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						return {text = "You learn something about two of the bidders. It will be worth knowing later, and worth money sooner than that."},
					partial = func() -> Dictionary:
						return {text = "You learn one thing here. Everyone else in the room is better at this than you are."},
					botched = func() -> Dictionary:
						Run.add_credits(-70)
						return {text = "You read a nod across the room as a bid. You win a lot you did not want, at a price you did not pick.", material = &"event"}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "Sealed, unseen, as it lies. One of the other three pays the fee and gets the forty minutes."}},
			],
		},
		{
			id = &"escort",
			title = "Escort",
			body = "Three haulers and a courier hold station off your bow. None of them is armed. They are all headed the way you are, and none of them is happy about it. The only armed ship in the system quoted them a price worth most of the run. They would rather pay you. All they want is for you to fly alongside them, visible, with weapons.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 11,
			min_danger = 3,
			max_danger = 8,
			max_security = 2,
			choices = [
				{label = "Take the contract", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(33))
					return {text = "You ride the flank for one ring. Something comes out of the shadow of the third moon and decides the convoy looks softer than it is.", fight = true}},
				{label = "Sell them the courier's slot", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(28))
					return {text = "The courier is fast enough to outrun anything out here alone. You tell them so, take a cut for the advice, and the convoy splits."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They pay the other escort most of what the run is worth. Then they go, and you never learn how it ended."}},
			],
		},
		{
			id = &"nine_tonnes",
			title = "Nine tonnes of nothing",
			body = "A freight crate sits on the dock, with somebody standing beside it. The numbers on it do not match. The manifest says nine tonnes and the crate is sized for forty. It also reads warm on your sensors. He wants it moved one ring inward, above rate. He is very relaxed about you not asking what is in it. Opening it is a different matter.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			max_security = 3,
			choices = [
				{label = "Open it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Reactor fuel, undeclared, in a casing rated for something duller. It is worth four times the freight. He knows that, and he pays the new rate without arguing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Not what the manifest says. Not dangerous either. You take the job at a better rate."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You get the casing open, find nothing worth knowing, and shut it before he notices. The rate stays what it was."},
					botched = func() -> Dictionary:
						return {text = "He notices. The job evaporates and so does he, and the crate goes with him."}},
				{label = "Just take the job", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(25))
					return {text = "Nine tonnes, one ring inward, above rate, no questions. You have carried worse and asked less."}},
				{label = "Pass", stay = true, effect = func() -> Dictionary:
					return {text = "He finds somebody else inside the hour. The crate is still warm when it leaves."}},
			],
		},
		{
			id = &"ice",
			title = "Ice",
			body = "A comet hangs off your bow. It is three kilometres of dirty ice on a long slow orbit. It has no transponder and no claim on it. There is nothing out here to sell water to. Under the crust there are volatiles and a little metal. The crust has been getting harder since this system was warm. It is under pressure, and it has views about being cut.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Cut deep",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 24
						return {text = "You take the crust off in sheets and get at the clean ice under it. There are volatiles and water. There is enough left in the tail to make the trip pay.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 18
						Run.take_hull_damage(OptionTable.toll(3), "The crust goes where you did not want it to go. You get most of what you came for. You wear the rest down one side.")
						return {text = "The crust goes where you did not want it to go. You get most of what you came for. You wear the rest down one side."},
					partial = func() -> Dictionary:
						Run.fuel += 10
						Run.take_hull_damage(OptionTable.toll(5), "The face calves while you are cutting it. You back off with a half hold and a dented bow.")
						return {text = "The face calves while you are cutting it. You back off with a half hold and a dented bow."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Three kilometres of hard ice lets go all at once. About eleven seconds of it goes straight into your bow.")
						return {text = "Three kilometres of hard ice lets go all at once. About eleven seconds of it goes straight into your bow."}},
				{label = "Skim the tail", effect = func() -> Dictionary:
					Run.fuel += 9
					return {text = "You leave the body of it alone. You run the tail instead and take what it is already shedding. It is slow, and it is safe."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "A long orbit, a hard crust, and nobody out here to sell water to. You log it and fly on. It comes back around in ninety years."}},
			],
		},
		{
			id = &"flare_shelter",
			title = "Flare shelter",
			body = "The star's readings are climbing. A big flare is about forty minutes out and the instruments are sure of it. Two minutes away is a rock big enough to shadow you. Tucked in behind it is a survey drone. It has been using that rock the same way for years. Forty minutes is enough to reach the rock and strip the drone. There is not much to spare in that.",
			tags = [&"hazard"],
			group = &"",
			weight = 11,
			min_danger = 3,
			max_danger = 8,
			# The same star, from the other side: one is a hold worth reaching
			# through a flare, the other is forty minutes to get behind a rock.
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Shelter and strip",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "You take the shadow. The cutter opens the drone in the dark. You come out the far side of the flare with its readings, a rack off its frame, and a cold reactor.", module = true, material_id = &"survey_film"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get most of it done before the shadow starts to move. You finish the rest out in the light.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 17
						return {text = "The cutter gets the drone open and no more than that. The flare lands on you with the hold still empty."},
					botched = func() -> Dictionary:
						Run.heat += 25
						return {text = "You misread how the rock turns. You spend the peak of the flare out on the lit side."}},
				{label = "Just shelter", effect = func() -> Dictionary:
					return {text = "You put the rock between you and the star and wait the flare out. One piece of somebody else's cargo drifts into the shadow with you. The grapple takes it in.", material = &"event"}},
				{label = "Outrun it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 16)
					return {text = "You leave before it peaks. It costs a burn you had not budgeted for and you never find out what was on the drone."}},
			],
		},
		{
			id = &"deadfall",
			title = "Deadfall",
			body = "Nine hundred metres of collapsed gantry lies across the approach. It was an orbital yard once, and it came down on itself slowly. Nothing about it blew up. A decade of nobody paying for maintenance did the work. The wreck is still under tension in places, and it still lets go of a piece now and then. Under the middle of it is a fitting bay. That is where the good parts sit in a yard like this one.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Go under it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You pick a line through nine hundred metres of dead scaffolding and nothing so much as brushes you. The bay is exactly as it was left.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "You get in and get the bay open. Something lets go behind you and clips the hull on its way past.")
						return {text = "You get in and get the bay open. Something lets go behind you and clips the hull on its way past.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Two hundred metres in, a span shifts across your line. You reverse out past a fitting bay you can see and cannot reach.")
						return {text = "Two hundred metres in, a span shifts across your line. You reverse out past a fitting bay you can see and cannot reach."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A span has held there for a decade. It lets go while you are under it.")
						return {text = "A span has held there for a decade. It lets go while you are under it."}},
				{label = "Work the outside", effect = func() -> Dictionary:
					return {text = "The perimeter of the field is safe enough and picked over enough. You take what the last four crews did not think was worth the lift.", material = &"wreck"}},
				{label = "Leave it lying", stay = true, effect = func() -> Dictionary:
					return {text = "You hold your line clear of it and fly on. Nine hundred metres of dead gantry sits there. It will come down the rest of the way on its own."}},
			],
		},
		{
			id = &"the_long_tow",
			title = "The long tow",
			body = "A ship hangs dead off your bow with its hull lights running on battery. Its crew answers the hail at once. The reactor is scrap and all six of them are fine. That is the wrong way around for how these usually go. The dock on the far side of this system will take the ship. It has to get there first. A tow is four hours of your engine at a load it was not built for. There is a hull on your stern the whole way, and it does not steer.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			needs_berth = true,
			choices = [
				{label = "Take the tow",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Four hours, one heading, nothing goes wrong. The dock takes the ship. The dockmaster watches you come in with somebody else's hull on your line."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "Five hours, and a stern mount you will want looked at. The ship gets there.")
						return {text = "Five hours, and a stern mount you will want looked at. The ship gets there."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "You get it most of the way before your engine says it is done. A yard tug comes out for the last leg. It takes most of the fee with it."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 18)
						return {text = "The line parts under load. Nobody is hurt. You lose four hours, one tow line, and all the fuel you burned getting that far."}},
				{label = "Sell them a reactor start", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 15)
					Run.add_credits(OptionTable.purse(36))
					return {text = "You have enough fuel aboard to start its cold reactor. That only works if they are not fussy about the margin it leaves you. They are not fussy."}},
				{label = "Signal it in and go", stay = true, effect = func() -> Dictionary:
					return {text = "You put their position on the emergency band and fly on. Their hull lights are still running on battery when they drop off your dish."}},
			],
		},
		{
			id = &"the_calf",
			title = "The calf",
			body = "A juvenile hangs beside a cold rock, calling. It has lost its pod. It waits the way the young of anything waits when it is lost. It reads warm on every instrument, the way all of them do. That warmth is why they are hunted. A hunter somewhere behind you has posted a standing bounty for a tagged calf. The pod is two hours out, answering on a frequency your hull feels rather than hears.",
			tags = [&"signal"],
			group = &"herd",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Tag it for the bounty", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "A transponder dart, a confirmation ping, and money from a ship you never see. The calf carries the tag toward its pod. What reaches it before the pod does is not your business. The bounty terms say so, in writing."}},
				{label = "Herd it home",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 16
						return {text = "You put your hull where a parent would put its flank. It follows you all the way in. The pod closes around it. Nine of them turn at once, and the wake carries you a long way for free."},
					clean = func() -> Dictionary:
						Run.fuel += 8
						return {text = "It follows, eventually, after deciding twice that you are a threat. The pod's wake pays for some of what the herding cost."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "It bolts the wrong way twice. You spend an hour of burn undoing each of those. Then it hears the pod itself and goes in alone."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "It panics at exactly the wrong moment, and its flank finds you at speed. It reaches the pod anyway, and you limp home.")
						return {text = "It panics at exactly the wrong moment, and its flank finds you at speed. It reaches the pod anyway, and you limp home."}},
				{label = "Leave it calling", stay = true, effect = func() -> Dictionary:
					return {text = "The pod is two hours out. The hunter behind you is closer than that. You do not stay to see which one gets there first."}},
			],
		},
		{
			id = &"the_manifest",
			title = "The manifest",
			body = "A heat barge sits across the lane inward, running lights on, drives cold. The woman flying it is hailing for a witness. The rules want a second signature on the last leg. It has to come from somebody with nothing to gain by it. Out here that is a short list. She has held station a day and a half, waiting for a ship that neither pays her nor competes with her. The seal on the load reads nine hundred units. It was signed off at the last station that still had the power to sign off anything. Your mass reading puts the barge four points heavy for nine hundred units of anything.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 9,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sign what the seal says", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "You sign for nine hundred units. You hold formation for the last leg and watch the barge become somebody else's problem. The fee clears before you have finished deciding what you saw. It is clean money for an hour of flying straight. You will think about the four points again later, when there is less to do."}},
				{label = "Put the dish on the load first",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "Eleven hundred units against a seal for nine. Somebody up the line is moving two hundred units of something inward. They pay tax on the small number. The woman flying it was never told what it is. You sign the true figure. She pays you for the fix before you have finished logging it. She is glad the problem goes back to the ones who made it."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "The mass settles close enough to the seal. The difference is fuel, ice, and the way a barge rides when it is low on both. You sign, fly the leg, and collect."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(3))
						return {text = "Your figures will not settle, and her window will not wait. You will not sign anything you cannot read. You take the standing fee for answering the hail. She goes looking for a witness with a worse dish."},
					botched = func() -> Dictionary:
						Run.add_credits(-60)
						return {text = "You sign a number. The vault's own scale does not agree with it later. The fine lands on the witness who signed. The witness is the only name on the paper anybody can find."}},
				{label = "Let her carry on", stay = true, effect = func() -> Dictionary:
					return {text = "She holds another hour on the open channel. Then she flies the last leg with no witness at all, rather than lose the window. Whatever the barge is four points heavy with goes wherever it was going."}},
			],
		},
		{
			id = &"the_last_berth",
			title = "The last counter",
			body = "The deepest dock still lit, and one clerk behind its counter. She logs arrivals for traffic that stopped arriving before her posting began. She logs yours properly: name, mass, heading, the time to the minute. Her rate sheet has not changed in eleven years. Her fuel is the cheapest in the galaxy. She is the only person out here who does not know that. Her archive drawer holds one folder. It is thick and it carries no label. She calls it the observations.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 8,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			needs_berth = true,
			choices = [
				{label = "Fill the tank at her rates", cost_credits = 30, effect = func() -> Dictionary:
					Run.add_credits(-30)
					Run.fuel += 40
					return {text = "She charges you a third of what a rim station would take. The rate comes off a sheet she has no power to change and no reason to doubt. She stamps the receipt twice. The second stamp is for a copy nobody has collected in eleven years. She makes that one as carefully as the first."}},
				{label = "Stay and copy the folder", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "It takes most of a shift, with the reactor idling the whole time. It is other crews' paperwork about the thing at the core. There are transit logs that stop in mid line. There is a mass estimate crossed out four times and never put back. There is an order for instruments that were never sent and never called off. She reads along with you and says nothing at all. She has waited eleven years for someone to ask.", archive_recover = true, material_id = &"survey_film", material = &"event"}},
				{label = "Leave her to the ledger", stay = true, effect = func() -> Dictionary:
					return {text = "One clerk, one drawer, one folder. Yours is the first arrival she has logged in a long while. She logs it beautifully, down to the minute."}},
			],
		},
		{
			id = &"counting_backwards",
			title = "Counting backwards",
			body = "A relay hangs dead on the approach with its transponder still talking. It sends one number, once every forty-one years. Each one is lower than the last. Your archive holds three of them, logged by three ships across two centuries. The arithmetic is not hard. The next number it sends is zero. The relay is precursor work, older than any name anyone has for it. The dish puts that broadcast four days out.",
			tags = [&"signal"],
			group = &"",
			weight = 7,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				# NOBODY IS OUT HERE TO PAY YOU, so nothing here pays in credits.
				# Every branch hands over an OBJECT and the object becomes money at
				# a station, where somebody is standing behind a counter. See the
				# note on `purse` -- cash is what people give you, and a relay two
				# centuries dead is not people.
				{label = "Cut the core out",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "The cutter opens the housing along a seam the builders left for this. The core comes away still warm. Forty-one years between one signal and the next, and it has never gone cold. The grapple walks it into the hold. The count goes with it and does not stop.", material_id = &"counting_core"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You take it fast and pay for the speed in waste heat. The radiators will spend an hour shedding that. The core sits in the hold and counts down on its own schedule.", material_id = &"counting_core"},
					partial = func() -> Dictionary:
						Run.heat += 8
						# NAMED FOR THE STORY, ROLLED FOR THE SCALE, and a branch this
						# deep wants both. `survey_film` is the readings and is worth
						# 35 whatever the danger -- a named material has a FIXED value
						# and is the one kind of payout the tier ladder cannot reach.
						# Alone it made a LETHAL partial pay less than an EASY
						# success. The rolled wreck material beside it goes through
						# `MaterialTable.roll(table, danger)`, which grades, so the
						# depth is paid for by the half of the haul that can be.
						return {text = "Forty-one years of heat and cold have welded the housing to its frame. The cutter will not argue with that in the time you have. You take the readings instead. The interval, the bearing, and the decay curve. All shot straight off the dish and never developed. The cutter shook something loose on its way out, and you take that too.", material_id = &"survey_film", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something in the core kept itself warm for two hundred years. It objected to the cutter and came through the hull.")
						Run.heat += 20
						return {text = "Whatever has kept that core warm objects to being opened. It has been warm since before there were manufacturers. It objects fast, and hard, and through the hull."}},
				{label = "Wait out the four days",
					effect = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "Four days on station, holding position on fuel you will want later, watching a number that does not move. On the fourth day it moves. It goes to zero and the transponder stops. Then nothing happens at all. No signal, no light, nothing answering from anywhere in the sky. The recording runs six more hours of that nothing.", material_id = &"last_broadcast"}},
				{label = "Leave it counting", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and leave it counting. The relay has waited two centuries already for company. It will still be sending when the next ship comes through."}},
			],
		},
		{
			id = &"holding_pattern",
			title = "Holding pattern",
			body = "Six ships hold a loose ring ahead of you. Their drives are cold and their transponders are on. The hulls are weathered unevenly, so they arrived years apart. Not one of them has moved since your dish first resolved them. They are not a convoy and they are not a blockade. Every one of them points the same way, and that way is inward. You hail the ring, and the only answer that comes back is a receipt code.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sell them the way out", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(30))
					return {text = "They have pointed inward long enough that the route behind them is out of date. A current one is worth more than any of them will say out loud. You send them the run so far. Bearings, what the crossings cost, which stations still have somebody behind a counter. They pay warm-economy prices. The credits are minted somewhere that still has a mint. Nobody says what they want it for. Two of them ask for a second copy."}},
				{label = "Read their receipts",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "Six codes, one issuing authority, and that authority is a vault. The holds all read empty, so they have delivered everything. Now they wait to be paid in whatever it is a vault pays with. The oldest code is forty years old. You copy all six. Somebody further out will want to know what this queue looks like from the back.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						return {text = "The codes are vault-issued and run in sequence. So this is a queue, and somebody built it. It is orderly, and it is old."},
					partial = func() -> Dictionary:
						return {text = "The codes point at a ledger and nothing else. You are never going to see that ledger. It is kept somewhere you will never be let in."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "You lean on the nearest transponder hard enough that all six ships answer. They light their drives at once, hold them for four seconds, and go cold again. Nothing is said. You burn out of the ring on a heading you did not plan. You would rather not explain it."}},
				{label = "Hold station with them", stay = true, effect = func() -> Dictionary:
					return {text = "You point inward, kill the drives, and sit in the ring a while. Nothing happens. None of the six ships so much as trims its attitude. After a while you light the drives and go."}},
			],
		},
		{
			id = &"the_favour",
			title = "The favour",
			body = "A courier is hailing every ship with a tank. She is running on fumes. Her charter pays when she gets there. Where she is going is one ring further in than her fuel goes. So she is offering over the odds for a top up. The other choice is drifting somewhere dull. She waits there until the people who hired her notice she is late. She is in no danger out here. It is the late delivery she cannot afford.",
			tags = [&"contract"],
			group = &"",
			weight = 13,
			max_danger = 6,
			choices = [
				{label = "Sell her ten units", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					Run.add_credits(OptionTable.purse(20))
					return {text = "Ten units across a line. The rate makes you both wince, for different reasons. She is moving again before the transfer pump has cooled."}},
				{label = "Sell her twenty", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 20)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Twenty units is enough for her to arrive with margin. She pays the rate without blinking. That tells you what the charter is worth, and it stings a little."}},
				{label = "Wish her luck", stay = true, effect = func() -> Dictionary:
					return {text = "She thanks you politely. She notes your registry down with the others who said no. Then she goes back to hailing everything with a tank."}},
			],
		},
		{
			id = &"wrong_registry",
			title = "Wrong registry",
			body = "A delivery drone matches your course and runs a docking handshake. The handshake is older than your ship. It has a consignment on it for a registry one digit off yours. That hull may not have been flying for decades. The clock on the job is long past due. The penalty has run so far past that it has wrapped around to zero. It will wait forever, because it was built to wait.",
			tags = [&"signal"],
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Accept the consignment", effect = func() -> Dictionary:
					return {text = "You spoof the digit and the drone unloads. It does it like a machine. This is the only job it ever had. The consignment comes over sealed, addressed, and heavier than it looks. The drone logs the delivery complete and turns back onto its route.", module = true, material = &"event"}},
				{label = "Correct its registry",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "You give it the right registry off an old dock ledger. It works out a delivery route to a hull. That hull died before you were flying. It thanks you in protocol. It releases the parcel it can no longer deliver and burns for the grave.", material = &"event"},
					clean = func() -> Dictionary:
						return {text = "You give it a registry that looks right. It accepts and works out a new route. It leaves a crate off the back of the consignment with you and goes. Whether that route exists is not your problem.", material = &"event"},
					partial = func() -> Dictionary:
						return {text = "Its check loop turns down everything you offer, and it does it politely. It will go on doing that forever. You break off before it finishes the fourth try."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "You feed it a bad registry. Something in its logic decides you are the one it was looking for. Every parcel on its manifest is now yours. It follows you out to the edge of sensor range and waits there."}},
				{label = "Decline the handshake", stay = true, effect = func() -> Dictionary:
					return {text = "It holds formation for exactly one hour, then goes back to its route. Somewhere out there is a registry one digit from yours. Its parcel is still coming."}},
			],
		},
		{
			id = &"dead_station",
			title = "Dead station",
			body = "A station hangs dark and unpowered ahead, turning a little off true. The docking clamps still have pressure in them. So the reactor died slowly, and somebody shut things down in order. None of the people who did that are aboard now. The face coming past has open bays with the racks still in them. Nobody cleared that gear out. The tanks are on the far side of the hub, sealed, with a coupling the grapple can work. Getting from one to the other is an hour of holding station against a hull that is not turning true.",
			tags = [&"salvage"],
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Salvage the racks", effect = func() -> Dictionary:
					return {text = "The grapple pulls a module out of a dead bay, and clears the rack around it on the same pass. It all comes away on the first try. After this long, it should not have.", module = true, material = &"wreck"}},
				{label = "Siphon the tanks", effect = func() -> Dictionary:
					Run.fuel += 12
					return {text = "Four jumps of fuel, tasting of rust."}},
			],
		},
		{
			id = &"distress_beacon",
			title = "Distress beacon",
			body = "A looping voice repeats a set of coordinates. They are one jump off your route. It has the flat sound of a recording. It has been running a long time. Whatever is at the far end is sending through a hull. The hull is big enough to carry a real transmitter. So it is either worth reaching or worth staying well away from. The recording does not say which.",
			tags = [&"signal", &"fight"],
			group = &"",
			weight = 11,
			max_danger = 6,
			choices = [
				{label = "Answer it", fight = true, effect = func() -> Dictionary:
					return {text = "It was bait. The hull it was sending from is real. It is still loaded, and still worth taking off whoever is using it as a hook. Something out there is already firing.", fight = true}},
				{label = "Read it from cover",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You sit off the coordinates and listen. There is a second signature under the loop, holding station. That tells you what this is. You sell the coordinates as a hazard note at the next dock."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "Enough of the carrier comes through to tell you nobody there is alive to rescue. That is worth logging. It is worth a little to whoever buys logs."},
					partial = func() -> Dictionary:
						return {text = "You learn one thing only. It repeats every ninety seconds. You could have counted that from where you started."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You hold position too long. The thing under the loop gets a good look at you. You leave with your bloom up and burning."}},
				{label = "Run silent", stay = true, effect = func() -> Dictionary:
					Run.heat = 0
					return {text = "You cut the reactor and drift past it with everything dark. Your heat goes to nothing. The voice keeps repeating behind you."}},
			],
		},
		{
			id = &"whale_fall",
			title = "Whale fall",
			body = "The corpse of something enormous hangs ahead of you. It is coming apart slowly in the dark and feeding a whole crowd of smaller things. It has been dead long enough to have a population. Most of them are too small to read on the dish. A few of them are bigger than your ship. All of them are feeding. What it is made of is worth carrying. The best of that sits down in the seams between the ribs. Working there means sitting in among them for as long as the cut takes. Enough has come loose already to fill a bay, out where nothing is feeding.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Cut into it",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "You work the seam quietly, in the lee of the ribs. You come away loaded. Nothing living here stops feeding long enough to look at you.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "You take what you came for. Something the size of a hatch cover watches you do it and elects not to mind."},
					partial = func() -> Dictionary:
						Run.add_material(&"exotic", 1)
						Run.take_hull_damage(OptionTable.toll(3), "Something feeding on the whale fall took an interest in the ship. It was one of the ones bigger than you.")
						return {text = "Halfway through the cut, the whole population decides you are competition. You leave with less than you wanted. The hull picks up a new set of scratches."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The whale fall was still full of things that feed. They came for the hull all at once and did not stop.")
						return {text = "There are so many of the small ones, and they all arrive at once. The big ones never stop feeding while it happens."}},
				{label = "Take what has come loose", effect = func() -> Dictionary:
					return {text = "Enough has drifted clear of the ribs to fill a bay. You take that instead and cut nothing, and annoy nothing.", material = &"fauna"}},
				{label = "Let it rest", stay = true, effect = func() -> Dictionary:
					return {text = "You hold station a while and take nothing off it. The small ones go on feeding, and the big ones never stop either. You leave it to them."}},
			],
		},
		{
			id = &"inspection_sweep",
			title = "Inspection sweep",
			body = "A patrol is stopping everything through this lane. The reason is parked behind them. A hauler was pulled over two days ago and its crew left it there. Its load sits in the impound under a seizure notice. Nobody has come to act on the notice. The queue moves slowly. Whatever is still in the impound at the end of the week goes to the breakers.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			min_security = 3,
			choices = [
				{label = "Wait your turn and bid on the load", cost_credits = 40, effect = func() -> Dictionary:
					# The bid itself, which every other priced choice spends in its
					# own effect. This one leaned on the screen deducting it, and
					# the screen no longer does.
					Run.add_credits(-40)
					var lost := Run.contraband_count()
					if lost > 0:
						Run.add_credits(-20 * lost)
						return {text = "They find what you are carrying and price it into the paperwork. You pay both bills. What is left in the impound is still worth more than the morning cost you.", module = true}
					return {text = "Clean, waved through, and first in line for an impound nobody else waited out. The seizure clerk is glad of the company. The price is what the notice says.", module = true, material = &"wreck"}},
				{label = "Talk your way to the front",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Your registry says you are already cleared. For the forty seconds they spent reading it, that is what it said.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You come out of the queue two hours early, and you take the smaller half of the impound. It is still half of it."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A patrol skiff crowded you off the impound gate.")
						return {text = "They notice, and a patrol skiff crowds you off the gate. The damage is to your paint. You leave with nothing out of the impound."},
					botched = func() -> Dictionary:
						Run.add_credits(-45)
						return {text = "You are fined for trying it, item by item, and made to wait anyway. The impound is empty by the time you get to it."}},
				{label = "Burn away", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 6)
					Run.take_hull_damage(OptionTable.toll(2), "You ran the lane, and something clipped you on the way out.")
					return {text = "You run for it: six fuel, a scraped flank, no record. The impound goes to the breakers at the end of the week without you."}},
			],
		},
		{
			id = &"derelict_hauler",
			title = "Derelict hauler",
			body = "An old freight frame, gutted down to structure and still holding its lines. Whoever stripped it lifted the fittings off and left what they were bolted to. That is the opposite of the usual order. They were in a hurry about something other than money. What is left is a spine, a set of dry tanks, and the mounts the racks came off. None of it reads bent. Proving a frame will fly takes hours of slow passes and instrument work. Cutting it up is quicker. Plating and wire off a hull this size sell to anybody with a yard.",
			tags = [&"salvage"],
			group = &"",
			weight = 6,
			max_danger = 6,
			min_danger = 2,
			choices = [
				{label = "Claim the hull", effect = func() -> Dictionary:
					Run.find_hull(LootGen.roll_hull(Run.node_at().danger))
					return {text = "The frame will fly. You prove it the slow way, with hours of passes and instrument work: %s." % Run.found_hull.display_name()}},
				{label = "Strip it for scrap", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(35))
					return {text = "Your cutter takes off plating and wire worth selling. You leave the frame a little more gutted than you found it.", material = &"wreck"}},
				{label = "Leave the frame", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and fly on. The frame is still out there on the dish an hour later. It is still holding its lines."}},
			],
		},
		{
			id = &"hostile_contact",
			title = "Hostile contact",
			body = "A hull sits dead ahead of you where the chart shows nothing. Its engines are cold and its running lights are off. It already has your registry. The query came in before your dish had finished resolving its shape. No hail follows, and no demand. It turns, slowly, until its bow is pointed at you. Then it holds there and waits to see what you do about that.",
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
					return {text = "You light the drives and close before it finishes deciding you are prey. Whatever it came out here for, it expected slower work than this. The first exchange says so.", fight = true}},
				{label = "Burn past it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You put the throttle down and take the long way around the system. You watch its bearing the whole way. It does not follow or hail. It turns back to where it was, and you never learn what it wanted from you."}},
			],
		},
		{
			id = &"dead_hull",
			title = "A dead hull",
			body = "A hull drifts across the lane, cold all the way through: no heat on any band, no beacon, no claim transponder answering. Whatever registry it flew under is not one your dish can reach from here. The airlocks are shut. The racks, on the long-range read, are still full. It has been here long enough that nobody is coming for it.",
			tags = [&"salvage"],
			group = &"",
			weight = 14,
			choices = [
				{label = "Strip it", effect = func() -> Dictionary:
					return {text = "You put the grapple on it and cut the racks out through the breach. Whatever killed them did not take the parts. You leave with what would have been somebody's spares.", module = true}},
				{label = "Read the log first",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						return {text = "The recorder is intact. It names which racks were loaded last and what went into them. You take the best of those, and the crate stowed beside them. The rest stays where the cold kept it.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "Enough of the log survives to say the hull is not rigged. No scuttling charge, no scavenger trap. Just a crew that ran out of heat. You strip it at your own pace.", module = true},
					partial = func() -> Dictionary:
						return {text = "The recorder is slag. The racks are locked to a registry that the slag used to hold. You take what is drifting loose in the open sections. You learn nothing about how they died."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something in the dead hull was still charged.")
						return {text = "A cell that should have been flat was not. It discharges into the bow the moment the panel comes off. You leave with less ship than you arrived with."}},
			],
		},
		{
			id = &"cordon",
			title = "The cordon",
			body = "Three ships hold a line across the lane with their weapons live. A strobe runs the width of it. It is a toll. The hail is polite and has a rate card attached. One rate for every hull, payable now. Out here there is nobody to complain to. The ships on the line know exactly how far off the nearest somebody is, to the hour.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 12,
			regions = [MapGen.Region.LAWLESS],
			max_security = 2,
			min_danger = 5,
			choices = [
				{label = "Pay it", cost_credits = 60, effect = func() -> Dictionary:
					Run.add_credits(-60)
					return {text = "You pay the rate and get a wave from whoever is in the chair. The strobe drops and the lane opens. You fly it end to end without so much as a sensor ping."}},
				{label = "Run it",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						return {text = "You are past the line before the three of them have finished talking about it. They get a shot off at where you were. The lane is yours, and it cost you nothing at all."},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						return {text = "They get a burn off the moment you commit. You take the lane at full throttle with the strobe chasing you down it. The tank shows the sprint at the far end."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 26)
						return {text = "You commit and they close the gap. You take the wide route at speed, out around the reach and back. You get through, and the tank is lighter by half a ring."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 40)
						return {text = "You cross the lane twice, both times at full burn. The second crossing had no reason anybody could name afterwards. They let you go in the end, out of something like pity. The tank takes the whole sprint."}},
				{label = "Break it", fight = true, effect = func() -> Dictionary:
					return {text = "You come at the line the way nobody who pays the toll ever does. They are not expecting a ship that came out here to do this. It shows in how long they take to answer.", fight = true}},
			],
		},
		{
			id = &"salvage_rights",
			title = "Salvage rights",
			body = "A wreck lies open along its length, and somebody is already on it. A cutter ship is anchored at the stern with its floods on and its gear out. Half the racks are gone. They watched you arrive and nobody hails. Out here, salvage rights come down to who is holding the cutter, and they are. The bow section is still untouched.",
			tags = [&"salvage", &"contract"],
			group = &"wreck",
			weight = 11,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY],
			min_danger = 2,
			choices = [
				{label = "Work the bow", effect = func() -> Dictionary:
					return {text = "You take the bow while they take the stern. Two ships work one wreck in silence. When the good rack comes free they put their floods on you for a second. They want you to know they saw. Then they go back to work.", module = true}},
				{label = "Find what they missed",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(35))
						return {text = "Your dish maps the hull's voids. It finds a sealed transfer hold their cutting line went straight past. Inside is a module, still racked, and a sealed bale of cargo nobody opened. You are gone before they finish the stern.", module = true},
					clean = func() -> Dictionary:
						return {text = "You read the frame, pick the one section their floods never swept, and pull a rack out of it clean. They notice. They decide it is not worth the fuel.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Their cut got everything worth mounting. What is left is small and loose. You sweep what you can of it out of the open sections with their floods tracking you the whole time."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "You cut into the section their anchor line is braced on. Everything stops. You pay them to keep it from becoming a fight. The transfer goes through while their floods hold steady on your cockpit."}},
				{label = "Leave it to them", stay = true, effect = func() -> Dictionary:
					return {text = "One wreck, one cutter crew, and floods that follow you all the way out of sensor range. It was theirs the moment they anchored."}},
			],
		},
		{
			id = &"still_under_warranty",
			title = "Still under warranty",
			body = "A wreck drifts past with a Verity plate still bright on its flank, and something aboard it is still live. A service handshake pings you every ninety seconds: three tones, the same three tones, asking any passing hull to name itself. The crew that should answer is gone. The bay does not know that. It has been asking for a long time.",
			tags = [&"salvage"],
			group = &"wreck",
			weight = 6,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY,
				MapGen.Region.COSMOPOLITAN],
			berth = &"verity",
			choices = [
				{label = "Answer the handshake",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "You answer with your own registry. The wreck accepts it without a pause. Down the flank, service bays cycle open one after another. The covered parts release into the dark for whoever the hull now thinks you are.", module = true},
					clean = func() -> Dictionary:
						return {text = "The handshake takes your registry on the second try. One bay opens. What is racked inside comes free clean, and the three tones go back to asking the dark.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The wreck accepts you, but the bays stay shut. All it will release is the courtesy locker beside the lock. Inside are a few sealed spares with Verity's name on the wrap."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "The handshake flags your registry as the wrong holder of record. The bay lock arcs the moment your grapple touches it. The scoring down your flank costs credits to make right."}},
				{label = "Strip it regardless", effect = func() -> Dictionary:
					return {text = "You cut the racks out with the handshake still asking, every ninety seconds, three tones into the dark. It is asking when you leave. It will be asking for a long time after.", module = true}},
			],
		},
		{
			id = &"collapsed_lane",
			title = "Collapsed lane",
			body = "The short way on runs through a shipbreaker's yard. It is a lane of dead hulls packed so close the dish reads it as one long wreck. Spars cross the gap at every height. The breakers left them where they lay when the money stopped. Going around costs a day you do not have. Going through costs nothing at all if nothing touches you. The fuel you save is real.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.COSMOPOLITAN,
				MapGen.Region.TERRITORY],
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Push through the wrecks",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 10
						return {text = "Plating screams the length of the lane and holds. Spars pass close enough to read the chalk marks the breakers left on them. You come out the far side with all the fuel you would have spent going around."},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A spar in the shipbreaker's lane opened the bow.")
						Run.fuel += 10
						return {text = "Something gives near the bow. It sounds like a hatch going the wrong way. You keep going and you keep the fuel. You have a look at the bow later."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A spar went through the forward plating and stayed there.")
						return {text = "Halfway in, a spar goes through the forward plating and stops. The lane is suddenly all spars. You reverse out the way you came, slowly, wearing it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead hull folded the bow in the breaker's lane.")
						return {text = "The lane closes on you between two hulls. They were never going to stay where the breakers left them. What comes out the far side is your ship, mostly."}},
				{label = "Go around", stay = true, effect = func() -> Dictionary:
					return {text = "The long way around. A day past the yard with the wrecks on your beam the whole time. Nothing happens. You come out the far side a day later than you meant to."}},
			],
		},
		{
			id = &"drifting_lifepod",
			title = "Drifting lifepod",
			body = "A lifepod tumbles across your bow with a weak transponder on it. The signal is getting weaker. It has the rhythm of a battery that has been dying for months. The viewport is frosted from the inside. Someone is still in there, or was. Somebody else has been here first. The lock housing carries a fresh weld that was never part of any pod's design.",
			tags = [&"signal"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Crack it open", effect = func() -> Dictionary:
					if Rng.event.randf() < 0.6:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You take it on the grapple and cycle the lock from the board. The fresh weld is a scavenger's charge. It fails to fire when the seal breaks. Inside there is no occupant. There is cargo you can sell, packed where a person should be."}
					Run.take_hull_damage(OptionTable.toll(5), "The fresh weld was a scavenger trap. It fired against the hull and finished what the cold started.")
					return {text = "The fresh weld is a scavenger trap. It fires when the seal breaks and goes off against your hull."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You let it tumble on. The frosted side turns slowly toward the star and away again. The transponder is still going when it leaves sensor range. It is weaker than when you found it."}},
			],
		},
		{
			id = &"the_dust_cloud",
			title = "The dust cloud",
			body = "The star is shedding. It has been for a long time. What comes off ends up here as warm dust. It is too fine to see until it is on you. Everything in this system has a coat of it on the side that faces the light. It will stick to your radiators too. It does not fall off on its own. Deep in the thickest part of the cloud there is a mining ship. It is dusted over, holds shut, drifting. Nothing out here moves fast enough to have wrecked it. At some point it just stopped.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pull the mining ship out",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						return {text = "The grapple takes the towing eye. It drags the ship out of the cloud a metre at a time. The dust comes off in sheets once it is moving. The holds were shut, not sealed. They open for the cutter in about ten minutes.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You pull it out fast and the dust goes everywhere. Every radiator you have is coated, and the vents will be an hour clearing them. The holds are worth the hour.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "It shifts. Then it settles back, and the cloud closes over it again. You spend an hour on it. You come away with nothing but a hot ship."},
					botched = func() -> Dictionary:
						Run.heat += 16
						Run.take_hull_damage(OptionTable.toll(4), "Star dust got into the intakes faster than the vents could clear it.")
						return {text = "It comes free all at once. A slab of the crust comes with it, straight into your intakes. The hull holds. The vents behind it do not."}},
				{label = "Fly the cloud with a hold open", effect = func() -> Dictionary:
					Run.heat += 9
					return {text = "You open one hold and fly the length of the cloud slowly. The dust packs into the corners. It packs the way it has packed onto everything else here. It heats the ship the whole way. You end up with a hold of fine metal the star threw off.", material = &"mining"}},
				{label = "Keep clear of the cloud", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the lit side of the system and leave the ship where it stopped. It has been there for years. It will be there next year."}},
			],
		},
		{
			id = &"the_water_stop",
			title = "The water stop",
			body = "Two people run a water stop sunward of here. They hold tanks of ice out in the light and let the star do the work. They sell the water to anything passing. They have done it for eleven years. The plant was parked in a stable orbit and never needed an engine. The orbit has stopped being stable. It is going the one way that matters, and it is going slowly. They are on the open channel asking for a tow. They are asking everyone. There is not much traffic, and they have been asking a while.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Tow them back out",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You get your nose against the plant and hold a long, slow burn. Forty minutes of that puts them back where they were eleven years ago. They pay out of a box they keep under the console. They count it twice. Both counts come out the same."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The tow works, though it takes longer than either of you expected, and it puts them high enough to stop worrying. They pay what they said they would. Nobody says out loud that this will need doing again."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.add_credits(OptionTable.purse(7))
						return {text = "You get them moving and the line slips before they are anywhere near safe. They are higher than they were and not high enough. They pay you something for the try, because they will be asking again next month."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A water plant the size of a station came around under tow. The hull stopped it.")
						return {text = "The line goes tight off centre. The plant swings around faster than something that size should. It stops against your side. The plant is not damaged."}},
				{label = "Sell them fuel instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					Run.add_credits(OptionTable.purse(18))
					return {text = "They have thrusters on the tanks and nothing to run them on. So you sell them fuel. Fourteen units across, at a price you would be glad to pay yourself. They will burn it a little at a time. They will climb out on their own over the next month. It pays less than the tow. The fuel comes out of a tank you cannot fill until the next station."}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck and go. The tanks keep melting, the ships keep not coming, and the orbit keeps doing what it is doing. They have months yet, and they know that better than you do."}},
			],
		},
		{
			id = &"the_lit_side",
			title = "The lit side",
			body = "A freighter has kept the same face to the star for decades. It is dead, but it is dead pointing the right way. That is more luck than most wrecks get. The side that takes the light is glazed over with dust and heat. It baked on year after year until it went hard and clear, like amber. You can see the layers in it. The cold side is bare metal. The holds there would open after an hour of cutting. Working the lit side means sitting in the light for as long as it takes.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Cut the glaze off",
					check = {attr = &"thermal", need = 6},
					met = func() -> Dictionary:
						return {text = "You sit in the full light and take it off in plates. It comes away solid and still warm through. The layers are stacked in order, decades of this star, one year on top of the next. It goes into the hold hot. It stays hot for a long time.", material_id = &"corona_amber"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get a good amount off before the vents start falling behind. What you have is worth the heat. The last plate brings a strip of hull with it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 14
						return {text = "The glaze is welded to the plating underneath. The cutter is doing more heating than cutting. You give it up. Your ship is hot and your hold is empty."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(5), "Ten minutes too long in the full light. The vents never caught up.")
						return {text = "You stay ten minutes longer than the vents can carry. Nothing catches fire. Things stop working one after another. The lit side goes first."}},
				{label = "Take the cold side instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 9)
					return {text = "You sit in the freighter's shadow. Holding that spot burns a slow drip of fuel for the whole hour. The holds on the cold side have ordinary cargo in them. You take some.", material = &"wreck"}},
				{label = "Leave it facing the star", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go. It has been building that face for decades. It will not stop in the time it takes you to find better work."}},
			],
		},
		{
			id = &"paying_for_shade",
			title = "Paying for shade",
			body = "One rock in this system stays put. It throws a shadow long enough to hide a dozen ships. Two ships got here first. They hold the near edge of it. They are not hiding what they do. They charge for a spot, cash up front. They say so on the open channel to everyone who comes in. The instruments put the next flare about ninety minutes out. Further back in the shadow is forty years of what people left when they ran: cargo, a dead ship, loose plate.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pay for a spot", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "You pay and take the spot they give you. You sit out the flare with everything turned down. Nobody says anything about the loose plate further back in the shadow. Nobody moves when the grapple goes out for a piece of it. They sold you the shade. The plate was not part of the price.", material = &"wreck"}},
				{label = "Take a spot without paying",
					check = {attr = &"stealth", need = 6},
					met = func() -> Dictionary:
						return {text = "You come in cold along the back edge, where the dead ships are, and sit among them. The flare comes and goes. On the way out you take the best thing you were parked next to. Nobody ever calls you on the channel.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You get a poor spot at the edge, half in the light, and hold it. It is uncomfortable and it is free. Something small drifts against the hull while you wait, and you keep it.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The edge of the shadow moves during the flare. You move with it badly. You spend the worst of it with a third of the ship in the light. You come out hot, with an empty hold."},
					botched = func() -> Dictionary:
						Run.heat += 18
						Run.take_hull_damage(OptionTable.toll(5), "Pushed out of the only shade in the system. The flare came twenty minutes later.")
						return {text = "They find you inside twenty minutes. They put a light on you until you leave. There is no argument. The flare arrives while you are out in the open."}},
				{label = "Move on before it hits", stay = true, effect = func() -> Dictionary:
					return {text = "You are out of the inner system before the readings mean much. It costs you the shade and everything sitting in it. The rock will still be there next time, and so will they."}},
			],
		},
		{
			id = &"the_century_log",
			title = "The century log",
			body = "A machine sits in a close orbit here, measuring the star. It has done it for a hundred years. One reading an hour, every hour, through every flare. Nobody predicts a star this size well. A hundred years of one is worth money to anyone who flies near stars for a living. The people who put it there stopped answering a long time ago. It is cooking now, and only the shaded half still works. After every flare it sends a summary out to a receiver that is not there any more.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Take the readings off it",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						return {text = "You match its roll and put the dish on it. You pull the whole hundred years down in one pass. Every hour, every flare, every gap. The instrument head comes off the mount as well, still cold and still good. It is aboard when the machine turns away.", module = true, material_id = &"survey_film", archive_recover = true},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get the link and about forty years of it. Then the working half rolls away from you. Forty years of a star like this is still worth having. The grapple takes a panel off the housing as you go past.", material_id = &"survey_film", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The link wants an answer. The machine has not been asked for it in a century. You cannot find it in the time you have. You come away with a piece of the housing and none of the readings.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 24
						Run.take_hull_damage(OptionTable.toll(4), "Caught on the lit side of a machine. It has been cooking for a hundred years.")
						return {text = "You misjudge the roll and come around on the lit side. There is nothing between you and the star. It only lasts a few seconds."}},
				{label = "Answer it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "The frequency is in every summary it sends. You send a receipt back on it, in the format a hundred-year-old machine expects. It treats that as the job being finished. It sends you everything it has. That takes eleven hours with the reactor idling. When it is done it stops transmitting.", archive_recover = true, material_id = &"survey_film", material = &"event"}},
				{label = "Leave it working", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go. It takes another reading while you are still in range, and another after that. It will keep taking them until the shaded half stops being shaded."}},
			],
		},
		{
			id = &"the_failing_shade",
			title = "The failing shade",
			body = "Somebody built a shade here. Foil on a frame, kilometres across, hung between the star and a lane that would be no use without it. It is still up. It has been up long enough that things have collected in the cool behind it. Three wrecks, a fuel ship, and cargo that came loose from something and stopped where the light stops. One edge of the frame is buckling. When it goes, the shade goes with it. Everything behind it gets the full face of the star.",
			tags = [&"salvage", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Work fast under it",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						return {text = "You go for the fuel ship first, because that is where the fittings are. You have the good half of it aboard before the frame lets go. What you leave stays out in the light.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You work fast and pick well enough. The edge lets go while you are still shortening the last line. The shade peels back over you as you burn out from under it. You are clear with about four minutes to spare.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You spend too long deciding which of the three wrecks is worth the hour. The frame decides for you. You leave with an empty hold. The ship took the last of the light in the open."},
					botched = func() -> Dictionary:
						Run.heat += 26
						Run.take_hull_damage(OptionTable.toll(4), "Under a kilometre of failing foil when it let go. The star was straight behind it.")
						return {text = "The buckled edge lets go along its whole length. The rest of the frame follows it. A sheet of foil the size of a town comes down across you. Then there is nothing between you and the star."}},
				{label = "Hold the frame up", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 15)
					return {text = "You put the grapple on the buckled edge and hold it straight on thrust. It costs a long burn and it buys hours instead of minutes. You work the fuel ship at your own speed with the shade steady over you. It is still up when you let go. It will not be up next year.", material = &"wreck"}},
				{label = "Leave the shade alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log what is behind it and fly on. Nothing you could do would keep that frame up. The wrecks in the cool have been there for years, and nobody has come back for them."}},
			],
		},
		{
			id = &"sixty_containers",
			title = "Sixty containers",
			body = "A hauler broke up here a while ago. Its cargo is spread across the approach in a long line. Sixty containers or more, all sitting in the light. The light has burned every label off them. The seals are cooked. Some of what is inside does not mind the light at all. Some of it has been ruined. From outside there is no telling which is which. Metal, ore and tools are fine. Medicine, film and anything with a circuit in it are not.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Read them with the dish",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "You scan the line container by container. Mass, density, how each one has warmed in the light. It takes two hours, and at the end of it you know which eleven are worth opening, and you open those. Plate, and a rack of parts the light never reached.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You get a rough sort out of the dish. It is good enough to skip the worst of them. Two hours in the light is two hours of heat. You come out with one container of something the light could not hurt.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The readings all look the same after the first hour. You open the ones that seem heaviest and get one good container in five. The rest is cooked stock, and the ship is hot from the sorting.", material = &"event"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Three hours in the light of a blue hypergiant. The labels were not there to read.")
						return {text = "You spend three hours in the light reading numbers that never add up. You open four containers. All four hold nothing but ruined stock. Your own lit side reads thin by the end of it."}},
				{label = "Open them at random", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You do not have two hours. You move down the line opening whatever is nearest, and it costs fuel to keep stopping and starting. Six containers: five of ruined stock, and one that the light could not hurt.", material = &"wreck"}},
				{label = "Leave them in the light", stay = true, effect = func() -> Dictionary:
					return {text = "You log the line and move on. Whatever was worth having in there will still be worth having next year. Whatever was not is already gone."}},
			],
		},
		{
			id = &"the_shield_job",
			title = "The shield job",
			body = "A small freighter is calling for help on the open channel. The help it wants is odd. Its dish array is burned out. The light here does that to anything pointed at the star. The pilot cannot swap in the spare. The spare would start cooking the moment it went on the mount. She needs something big to sit between her ship and the star for about an hour. She is offering good money for an hour of sitting still. Sitting still here costs hull, and she knows it.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Sit in the light for her",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You put the ship between her and the star and hold there. An hour is a long time. Your lit side comes out with a shine on it that will not wash off, and nothing worse. She has the spare mounted in fifty minutes and pays for the full hour anyway."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.take_hull_damage(OptionTable.toll(2), "An hour in the light of a blue hypergiant. The antenna was not yours.")
						return {text = "You hold the hour. The plating on your lit side is measurably thinner at the end of it. She gets the array mounted and pays what she offered."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(3), "Forty minutes in the light for a stranger's dish. The plating gave out at thirty.")
						return {text = "You hold forty minutes. Then the readings on your own plating say stop. She gets the array half mounted. She finishes it in the shadow of her own hull, badly. She pays you for the forty minutes."},
					botched = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(5), "Sat in the full light of a blue hypergiant for an hour. The plating did not last it.")
						return {text = "You misjudge what an hour costs here. The array gets mounted behind you. Your lit side comes out of it thinner than any hour should cost, and the money does not cover the difference."}},
				{label = "Tow her into a shadow instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					Run.add_credits(OptionTable.purse(16))
					return {text = "There is a rock forty minutes away with a shadow the right size. You tow her there. It costs fuel and most of a day. She swaps the array in the dark at her own pace. She pays less than she offered. The hour in the light was the hard part, and you did not do it."}},
				{label = "Leave her calling", stay = true, effect = func() -> Dictionary:
					return {text = "You wish her luck and fly on. She goes back to calling. There is not much traffic here, and the next ship through will be as reluctant as you were."}},
			],
		},
		{
			id = &"the_comet",
			title = "The comet",
			body = "A comet is coming through, close in, and the star is boiling it. Its tail is a hundred thousand kilometres of water, gas and rock. It is lit white and points straight out along the lane you need. That tail holds more clean water than every tank on every station within a week of here. There is more rock in it than the dish can count. All of it is moving and none of it is small. Riding the tail fills the tank. Riding it badly leaves the ship in the tail for good.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Ride the tail",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 30
						return {text = "You put the nose into the tail and hold it there for eleven minutes. You correct the whole time, with rock going past on both sides close enough to hear. The tank fills. Ice packs into the open hold along with it. You come out the far end of the lane heavier than you went in.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 18
						Run.heat += 10
						return {text = "You get most of a tank before the rock gets too thick to fly through. The ship is hot from the light. It will take the next hour to shed the heat. The fuel is real."},
					partial = func() -> Dictionary:
						Run.fuel += 8
						Run.take_hull_damage(OptionTable.toll(2), "A comet's tail, rock first.")
						return {text = "You get eight minutes of tail before a piece of rock the size of a door finds you. The tank is a third full. The hull has a dent in it the size of a door."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Went into a comet's tail at the wrong angle.")
						return {text = "You go in at the wrong angle and the tail takes you sideways for six kilometres. Rock, ice and light, in that order, and then quiet. The tank is no fuller than it was."}},
				{label = "Skim the edge for ice", effect = func() -> Dictionary:
					Run.heat += 14
					Run.fuel += 10
					return {text = "You keep to the thin edge of the tail, where the rock is rare and the ice is too. It takes an hour in the light. Ten units of water go into the tank. The ship spends the next hour shedding heat."}},
				{label = "Wait for it to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the lane and watch it go by. It takes three days. Then the sky is clear again. The tank is exactly as full as it was."}},
			],
		},
		{
			id = &"the_beacon_job",
			title = "The beacon job",
			body = "A navigation beacon holds station on the lane inward, and it is dead. The light here kills a circuit board in about four days. So whoever runs the beacon keeps a crate of spares tethered beside it. There is a standing offer painted on the crate, in letters the star has not yet burned off. Swap the board, key in the job number, and the fee clears. Nobody is here to watch you do it. Nobody has been here in a while. The crate has eleven boards left in it.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Swap the board",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You pull the dead board with the grapple and seat a new one in nine minutes. That is about how long the light gives you before the new one starts to go. The beacon comes up. You key the number and the fee clears. On the way out, the lane is marked again."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes two boards. The first cooks in the grapple before it is seated. The second goes in fast and the beacon comes up. You key the number and are paid for one swap. That is what the crate says the job is."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 14
						return {text = "The beacon comes up for forty seconds and goes dark again. You key the number anyway. Something pays out, a fraction for a fraction of a job, and the crate has ten boards in it now."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(4), "Working a dead beacon in the full light of a blue hypergiant.")
						return {text = "You are still working when the board in the grapple lets go. The beacon housing takes a piece of your hull with it on the way past. The beacon stays dark. The crate has ten boards in it. You have less ship than you came with."}},
				{label = "Take the crate", effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "Eleven boards, sealed against the light, are worth more at a station than one swap pays. You cut the tether and take the crate. Cutting anything here means ten minutes in the light. The beacon stays dark. The lane stays unmarked for whoever comes next.", material = &"wreck"}},
				{label = "Leave it dark", stay = true, effect = func() -> Dictionary:
					return {text = "You log the beacon as dead. You fly the lane by dead reckoning, the way everyone else has. The crate is still there. The offer still stands."}},
			],
		},
		{
			id = &"the_sorting",
			title = "The sorting",
			body = "The light here is strong enough to push things. Not much, but it does not stop. Given years it moves anything that is not tied down. Light things go quickly and heavy things go slowly. So the wreckage in this system has been sorted. Everything light is far out on the cold side by now, blown clear years ago. That means foil, film, plastic, anything worth having that weighs nothing. Everything heavy is still here in the light. Keels, reactor housings, armour plate, the parts of ships that were built to last. Working them means working in the light.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work the heavy field",
					check = {attr = &"hull", need = 8},
					met = func() -> Dictionary:
						return {text = "Your plating can take an afternoon of this. An afternoon is what it takes. Armour plate the star could not shift. A reactor housing. Keel bolts as thick as a mooring post. It is the heavy end of forty years of wrecks, still bolted down and still good.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "An afternoon in the light of a blue hypergiant. Working the heavy field.")
						return {text = "You get most of an afternoon before your own lit side starts to read thin. What you take is the best of the heavy field. It cost hull to take it.", module = true, material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Stayed in the heavy field an hour too long. The plating could not pay for it.")
						return {text = "You get one good piece off a keel. Then the readings on your own plating say stop. Your lit side is thinner than the piece is worth. You know it before you are clear.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Stayed in the heavy field. The plating went the way of the paint.")
						return {text = "You stay too long, and the light does to your plating what it has done to everything else here. You leave with nothing in the hold."}},
				{label = "Chase the light things outward", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 16)
					return {text = "You burn out to the cold side. You spend a long day among what the light pushed there. Most of it is worthless. Some of it is film and foil that has kept out of the light. You take that.", material = &"event"}},
				{label = "Leave it sorted", stay = true, effect = func() -> Dictionary:
					return {text = "You log the field, both halves of it, and go. The light will keep sorting it. In another forty years the heavy things will be a little further out and the light things will be gone entirely."}},
			],
		},
		{
			id = &"clean_hull",
			title = "Clean hull",
			body = "A ship is holding a long way out from the star. The pilot wants to be closer to the light. He wants his ship towed in until every marking on it burns off. The registry, the yard numbers, the name, down to bare metal. Then towed back out again. His own drive is out, or he says it is. A ship with no drive drifts in the light. He says a day will do it. He does not say why, and out here nobody asks. He is paying for the tow both ways, and he is paying well.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Tow him in and hold him there",
					check = {attr = &"hull", need = 8},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You tow him in and hold beside him for a day. The star takes his ship's name off it. Then you tow him out. Your own lit side comes out shinier than it went in and no worse. He pays in full and says nothing. You say nothing either. He flies inward in a ship with no name."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "A day in the light of a blue hypergiant. Burning a stranger's name off.")
						return {text = "You hold beside him for the day. Your plating is thinner for it, by an amount you will pay to fix. His ship comes out clean, and he pays what he said."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Held a stranger's ship in the light for most of a day. The plating gave out before the paint did.")
						return {text = "The day is too long for your plating. You pull him out with his markings half gone. They cannot be read, but they are not clean either. He pays for half a job. He is not happy, and he is in no position to say so."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "A day in the full light of a blue hypergiant. Burning a stranger's name off.")
						return {text = "You stay the day and your own ship pays for it. His ship comes out bare. Yours comes out with less plating than a day should cost. He pays nothing. The tow out was your job, and you had to leave before you finished it."}},
				{label = "Tow him in and come back tomorrow", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You tow him in, let go, and pull back to where the light is only unpleasant. A day later you go in and find him. He has drifted, and the burn is uneven. His name is gone. He pays for two tows and not for the day. That is what he got."}},
				{label = "Decline the job", stay = true, effect = func() -> Dictionary:
					return {text = "You tell him no. He takes it well. He has been told no before and expects to be told again. He is still holding there when you leave, a long way out from the star. He is waiting for the next ship through."}},
			],
		},
		{
			id = &"lost_in_the_gas",
			title = "Lost in the gas",
			body = "A hauler is calling on the open channel from somewhere inside the cloud. Two aboard, low on fuel, and lost. Their dish is a small one, and the gas scatters everything it sends out. They have no fix and no stars. The heading they were flying stopped being any use an hour ago. They can hear you. That is all they know about where you are. They will pay for a way out. They will pay more for somebody who comes in and gets them.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			needs_nebula = true,
			choices = [
				{label = "Talk them out",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "Your dish is bigger than theirs. You find them on the third sweep, a cold spot in warmer gas. You read them a heading. You read them another when the gas moves, and then a third. Forty minutes later they come out of the cloud two kilometres off your bow. They pay before they have finished thanking you."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes two hours and eleven headings. Most of them are corrections to the one before. They come out in the end, a long way from where you said they would. They pay what they offered for the way out."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You lose them twice and find them once. In the end you burn out to the edge of the cloud yourself. They have something bright to steer at. They make it. They pay a little. A little is what they have left."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.take_hull_damage(OptionTable.toll(3), "Went into the gas after a lost hauler, and found a rock first.")
						return {text = "You give them a heading that is wrong. They burn on it for twenty minutes before either of you knows. So you go in after them. The gas hides a rock the size of a station until you are nearly on it. You get them out in the end. Nobody pays anybody."}},
				{label = "Go in and get them", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					Run.add_credits(OptionTable.purse(24))
					return {text = "You go in on the bearing of their voice and find them the slow way, with the lights on. Then you lead them out, close, so they can see your drive. It costs a lot of fuel to fly slowly in gas. They pay the higher price without being asked."}},
				{label = "Leave them to find their own way", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them which way the edge is, as best you can, and go on. They thank you, though it is not much help. Somebody else will come through, or the gas will thin, or it will not."}},
			],
		},
		{
			id = &"the_dropped_pod",
			title = "The dropped pod",
			body = "Something in the cloud is pinging. The transponder says it is a cargo pod. A hauler drops one of those when it has to lose weight fast. They mean to come back for it. Nobody has come back for this one. The gas scatters the signal, so the bearing wanders. Five degrees one way. Then ten the other. The pod stays invisible until you are close enough to put the grapple on it. The gas is thick enough here to hide rocks as well.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 1,
			max_danger = 2,
			needs_nebula = true,
			choices = [
				{label = "Follow the ping in",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You fly it by ear. Every time the bearing jumps you correct. Where the gas thickens you slow down. The pod is where the last ping said, sealed and cold. What was worth dropping and coming back for is still inside.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 4)
						return {text = "It takes longer than the ping suggests. The ship crawls most of the way with the lights on. The pod is there. So is a rock. It was close enough to matter if you had been going faster.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "The bearing walks you in a circle twice before you catch on. You find the pod's tether. You find a case that came off it. You never find the pod.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Followed a cargo pod's transponder into the gas. Found the rock first.")
						return {text = "You come around a bank of gas at speed and there is a rock in it. The pod is somewhere on the far side, still pinging. You do not stay to find out where."}},
				{label = "Fly a slow search pattern", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 7)
					return {text = "You give up on the bearing and fly the box the hard way. Slow, lights on, one leg at a time. Flying slow costs fuel. You find the pod's tether and one case that came off it. You find enough of the pod to know somebody else got here first.", material = &"event"}},
				{label = "Leave it pinging", stay = true, effect = func() -> Dictionary:
					return {text = "You log the pod and go. It has been pinging long enough for the gas to have moved around it twice. Whoever dropped it knows where it is, or has stopped caring."}},
			],
		},
		{
			id = &"the_cache",
			title = "The cache",
			body = "Half a kilometre off the lane, deep in the cloud, there is a string of sealed containers. They hang on a tether between two rocks. You would never have seen them without the lights. Eight of them, all alike. Each one has the same code and nothing else. Out in the open, any dish would find them within an hour. In here, nobody looks. Somebody put them here on purpose. Somebody is coming back for them.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			needs_nebula = true,
			choices = [
				{label = "Take the string",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "You cut the tether at both ends and take the whole string aboard. It takes an hour, and nobody comes. Six of the eight are somebody's supplies, worth nothing to you. One holds a ship's part, still packed. One holds the thing they were hiding, and nothing in any of them says who.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You get six of the eight aboard. Then another ship's lights show in the gas, a long way off and closing. You leave the last two and go. It does not follow. Of the six, one is worth having.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "You have one container off the tether when the other ship's lights show. You go fast, with the one you have. It is not the good one.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "One container in the cache was not cargo. It was there to stop the other seven being taken.")
						return {text = "The second container from the end is not a container. It goes off when the grapple takes the tension off the tether. You spend the next hour finding out which plates you still have."}},
				{label = "Cut one loose and go", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "One container, the one nearest the lane, cut quick and taken quick. It costs fuel to match the tether's drift in the gas and more to get back out. The other seven stay where they were put. Whoever comes back for them will notice, and will not know who.", material = &"wreck"}},
				{label = "Leave it hidden", stay = true, effect = func() -> Dictionary:
					return {text = "You switch the lights off and back out the way you came. The string stays on its tether. Eight containers of somebody's business, still waiting."}},
			],
		},
		{
			id = &"no_stars",
			title = "No stars",
			body = "The gas has closed in. There is nothing to steer by. No stars, no beacon, no fix. The dish reads cloud in every direction, all of it the same. The gyros give you a heading. It was true when you entered and has been drifting since. An hour of drift, or maybe two, in a direction nobody can name. You are moving. The gas is moving too, at a different speed. That difference is the thing you cannot see. Somewhere in this cloud is a rock the chart calls a hundred metres across.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_nebula = true,
			choices = [
				{label = "Rebuild the fix",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						return {text = "You stop, kill the drive, and let the dish listen. Over half an hour the gas thins in one direction. It shows you a star, and then a second one. That is a fix. You burn out on the new heading. On the way you pass a hull the cloud has been hiding for years. You take what is loose off it.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						return {text = "It takes an hour of listening and two false starts, and then two stars at once, and a heading. You burn out on it and it is right. The gas thins, and there is the lane."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						return {text = "You get one star and guess the second. The heading is out by ten degrees. You find that out slowly, over two hours of burning the wrong way. You come out of the gas a long way from where you meant to."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.take_hull_damage(OptionTable.toll(4), "Burned on a bad fix, in gas. The chart had the rock marked.")
						return {text = "You get a fix and trust it and burn. The rock is where the chart said. The chart was right about the rock, and wrong about where you were."}},
				{label = "Burn straight up out of the plane", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You burn straight up, at right angles to the lane. You keep burning until the gas thins and the stars come back. Leaving the lane costs fuel. Coming back down to it costs more. On the way down you find a marker at the edge of the gas. Somebody left a supply case on it for whoever got lost next.", material = &"event"}},
				{label = "Wait for the gas to thin", stay = true, effect = func() -> Dictionary:
					return {text = "You kill the drive and wait, because clouds move. Two days of listening to nothing, and then a thin place goes by and there are stars in it, and you go. It costs nothing but the two days."}},
			],
		},
		{
			id = &"the_dark_ship",
			title = "The dark ship",
			body = "Three kilometres off the lane, a ship is sitting dark. The gas is thick enough to hide it from any dish not looking straight at it. No transponder, no drive, no heat. It has been there long enough to gather frost. Either it is dead and nobody has found it yet, or it is alive and does not want to be found. From here there is no telling which. A ship that dead is worth a great deal to whoever gets to it first.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 6,
			needs_nebula = true,
			choices = [
				{label = "Go alongside and look",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "It is dead, and has been for years. Frost inside as well as out. The hold was full when it stopped. Nobody got here first. You take the best of it and log the rest.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						return {text = "It is dead, and cold. The cutter takes twice as long as it should. The gas will not sit still, so the fuel goes on holding station. What you get is worth it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "It is alive. It lights its drive when you are two hundred metres off. It goes fast, deeper into the cloud. You spend a lot of fuel getting clear of its wake. You never see who."},
					botched = func() -> Dictionary:
						Run.heat += 8
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a dark ship in the gas, and it was not dead.")
						return {text = "It is alive, and it does not leave quietly. Something hits your flank on its way past. A warning, maybe. Then it is gone into the gas. You are alone with a hull that needs looking at."}},
				{label = "Watch it for a day", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "You hold off in the gas with everything down and watch it for a day. Nothing changes. No heat, no drift, no light. Then you go closer, slowly. You take what is loose around it and never go alongside. Holding still in moving gas costs a day of fuel.", material = &"wreck"}},
				{label = "Leave it in the dark", stay = true, effect = func() -> Dictionary:
					return {text = "You go on along the lane and say nothing about it on the channel. If it is hiding, it is still hidden. If it is dead, it will keep."}},
			],
		},
		{
			id = &"the_scoop",
			title = "The scoop",
			body = "The giant fills the sky ahead, banded and slow, and its upper air is fuel. Every ship that has ever come through here has dipped into it. Get low enough and the intakes fill themselves. Get too low and the air drags you in. It is hot enough to strip the plating on the way down. The trick is the angle. Skim, and you come out with a tank you did not pay for. Dive, and you come out with more, or you do not come out.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			needs_giant = true,
			choices = [
				{label = "Dip into the air",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 20
						return {text = "You take it in one long shallow pass. The nose glows. The intakes roar the whole way through. You come out the far side climbing, with twenty more units in the tank than you went in with."},
					clean = func() -> Dictionary:
						Run.fuel += 12
						Run.heat += 8
						return {text = "You go in a little steep and come out a little hot. The tank takes twelve units. The hull takes an hour to cool, and you spend the hour climbing."},
					partial = func() -> Dictionary:
						Run.fuel += 4
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(2), "Skipped off the top of a gas giant's air, twice. The second one was hard.")
						return {text = "You skip off the top of the air twice, and you do not mean to. The second skip is a hard one. Four units of fuel, a hot ship, and a dent."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Went into the giant's air too steep, and the air kept the difference.")
						return {text = "You go in too steep and the air grabs you. Ninety seconds of the hull screaming. The intakes are full of fire. Then you are out, climbing on the last of the burn. You have no more fuel than you went in with. You have a good deal less plating."}},
				{label = "Skim high and slow", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 8
					return {text = "You keep to the very top of the air. It is thin there, and the intakes take a long time to fill. An hour of skimming buys eight units. The ship is warm all the way through by the end of it."}},
				{label = "Leave the air alone", stay = true, effect = func() -> Dictionary:
					return {text = "You keep your altitude and go around. It will still be here, and so will its air, whenever you come back with a bigger reason."}},
			],
		},
		{
			id = &"the_breaking_moon",
			title = "The breaking moon",
			body = "The giant's innermost moon is coming apart. It has been in too close for too long. The planet pulls harder on its near side than on its far side, and the difference is tearing it. Cracks a kilometre wide run across the surface. Sheets of crust lift off the near side and drift. Behind them is the inside of a moon. Dark metal, never seen and never mined, hanging there at the end of a slow tide. There is a fortune here, inside a moon coming apart.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_giant = true,
			choices = [
				{label = "Fly in among the pieces",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in slow between the lifted sheets with the cutter running. You come out the other side with a hold of what the moon was made of. Nothing touches you. Behind you a piece of crust the size of a station turns over, slowly, where you were.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Clipped by a piece of a breaking moon.")
						return {text = "You get the hold filled. A piece of the moon gets your flank on the way out. Not hard, but you hear it from the board. The flank needs looking at.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Spent a pass inside a breaking moon. Dodged sheets instead of cutting them.")
						return {text = "A sheet turns over faster than it should. You spend the pass avoiding it instead of cutting. You come out with a scraped hull and an empty hold."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(4), "Caught between two pieces of a breaking moon.")
						return {text = "Two sheets close with the ship between them. You burn out with the hull grinding on both sides. You do not stop burning until the moon is a long way behind."}},
				{label = "Take what drifts clear", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 9)
					return {text = "You sit a safe distance out and let the moon come to you. Every few hours a piece of the inside drifts clear of the sheets. You take the best one with the grapple. Holding station off a moon that is tearing itself apart costs fuel. It takes a day. It is safe.", material = &"mining"}},
				{label = "Leave the moon to it", stay = true, effect = func() -> Dictionary:
					return {text = "It has been breaking for a thousand years. It will break for a thousand more. There will be more of the inside showing every time you pass."}},
			],
		},
		{
			id = &"the_rings",
			title = "The rings",
			body = "The giant has rings, and they have been catching things since before anybody came here. Ice and rock, mostly. A few metres thick, a hundred thousand kilometres across, and flat all the way out. Anything that enters orbit here at the wrong angle ends up in the plane of the rings. It goes around with everything else. The dish counts eleven hulls in the near arc alone. To reach one you fly in the plane, at ring speed, with ice going past on every side.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			needs_giant = true,
			choices = [
				{label = "Fly the plane",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You match the ring's speed and fly with it. Once you are moving with it, the ice is not going past at all. It is just there, hanging. You pick your way between it. The nearest hull is a freighter, whole. It has been going around with the ice for a long time.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "A piece of ring ice, at ring speed.")
						return {text = "You get to the freighter with one knock on the way in. You take one more on the way out. Both come from ice you never saw. The hold is worth both.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get into the plane and cannot hold it. The ice keeps finding you, and you climb out hot and empty before it finds you properly."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Came into the ring plane at the wrong speed.")
						return {text = "You come into the plane at the wrong speed. It is only a few metres a second out. At ring speed that is enough. Ice, a lot of it. Then you are out of the plane, and the ship is quiet. A lot of things have stopped working at once."}},
				{label = "Hold above the plane and fish", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You hold just above the ring, matching its speed. You drop the grapple into it on a long line and pull up what it catches. Mostly ice. Once, something better, off a hull you never see. Holding above a ring for a day costs fuel.", material = &"wreck"}},
				{label = "Leave the rings alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log the eleven hulls and go on. They have been going around for years, and they are not going anywhere else. Somebody with more time will come for them."}},
			],
		},
		{
			id = &"the_sunken_freighter",
			title = "The sunken freighter",
			body = "A freighter went into the giant's air eleven years ago and did not come out. It should have been crushed. It was built for pressure, a gas-mining hull with plating thick all the way around. It is still down there. It floats at the depth where the air is dense enough to hold it up. It goes around the planet with the wind. Its transponder still works. Its cargo is still aboard. The air at that depth would crush your ship in about twenty minutes. It is hot enough to cook it in ten.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_giant = true,
			choices = [
				{label = "Go down to it",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "You go down through the bands with the pressure climbing the whole way. It is where the transponder said. It hangs in the dark air with its running lights still on. You get eight minutes alongside. The cutter opens a hold. The grapple takes the best of it. You climb out with the hull creaking.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Twelve minutes at a depth that gives you ten.")
						return {text = "Twelve minutes at depth. That is two too many. The plating comes up with a dent in every panel. The grapple comes up with the one thing it could reach.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Went down to crushing depth, and came up with nothing.")
						return {text = "You get down to it. The plating starts to give before the cutter has finished. You have to climb. You bring up nothing but a hull that has been squeezed."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went down to a freighter at crushing depth, and came up too slowly.")
						return {text = "You go down. The air catches you the way it caught the freighter. For a while it is not clear you are coming up. You do come up, on the last of the burn. Everything on the outside of the ship has been pushed a little way in."}},
				{label = "Fish for it from above", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You hold at the top of the air and drop the grapple on its longest line. Somebody left a hold open before they went. It takes a day of dropping and pulling to hook anything. Holding station in the wind costs fuel. What comes up is what was nearest the door.", material = &"wreck"}},
				{label = "Leave it down there", stay = true, effect = func() -> Dictionary:
					return {text = "It has been going around down there for eleven years. It will go around a good while longer, getting lower as it goes. One day it will not come around at all."}},
			],
		},
		{
			id = &"the_storm",
			title = "The storm",
			body = "There is a storm on the giant the size of a small continent. There is a ship in it. A mining ship with dead drives, pushed around the planet by wind at six hundred kilometres an hour. Three aboard. They call on the open channel every time the storm brings them up into range. Then the storm takes them down again and the channel goes quiet for an hour. They have been going around for two days. Their pressure hull is good for one more, they think. They will pay anything for a line.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_giant = true,
			choices = [
				{label = "Match the wind and grapple them",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You go into the top of the storm with their beacon on the dish. You match the wind. That means flying at six hundred kilometres an hour through air that wants you lower. The grapple takes them on the second pass. You climb out together, slowly. The three of them pay everything they said they would."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "Four passes into a storm on a gas giant, for three strangers.")
						return {text = "It takes four passes. The storm gets a proper hold of you on the third. You come out with their ship on the line. Your plating is scored from nose to tail. They pay in full."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Two lines into a storm on a gas giant. The storm kept most of the second.")
						return {text = "You get a line on them and lose it. You get it again. The second time it holds. It drags them up to where their own thrusters can hold altitude. They finish the climb themselves. They pay what they can. It is less than they said."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went into a storm on a gas giant after three strangers. It kept both ships.")
						return {text = "You go in after them and the storm takes you the way it took them. An hour of going around the planet with the hull groaning. Then a gap. You burn up through it with nothing on the line. They are still down there, still calling."}},
				{label = "Wait for the storm to bring them up", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You hold above the storm for a day. The wind reaches up even here, so you burn fuel to stay put. You wait for it to lift them into range. It does, twice. The second time you get a line on them without going in. Once they are out, they pay less than they promised from inside. You never went into the storm, so you do not argue."}},
				{label = "Leave them to the storm", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them you cannot, and they say they understand. The storm takes them down again. An hour later they are calling again, to anybody, and you are out of range."}},
			],
		},
		{
			id = &"dead_boards",
			title = "Dead boards",
			body = "There is a pulsar two systems over. Its beam reaches here every fourteen seconds. At this distance it is too weak to hurt a hull. It is not too weak to kill a circuit board that was not built for it, and most were not. A hauler in the lane ahead has found this out. Its controls are dead. Its drive is stuck on the last setting anybody gave it. It is sliding toward the one part of the system where the beam is strong enough to matter. Two aboard. They are calling for a tow.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			needs_pulsar = true,
			choices = [
				{label = "Tow them out of the beam",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You get a line on them and pull them across the beam's track. It takes an hour and every bit of thrust you have. Once they are clear, their boards come back one at a time. They pay in full. They ask what you are shielded with."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "The tow takes two hours and the line parts twice. They are out of the beam by the end of it. Their boards are coming back. You are hot from the pulling. They pay what they offered."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get them moving the right way. Then the line parts for good. They are drifting out of the beam now instead of into it. They will be clear in a day. They pay you for the direction."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Towed a hauler with a stuck drive, and the hauler towed back.")
						return {text = "The line comes tight while they are still under power on the old setting. The two ships fight each other for a minute. Your hull comes off worse. They are no better off than they were. Nobody pays."}},
				{label = "Sit between them and the beam", effect = func() -> Dictionary:
					Run.heat += 14
					Run.add_credits(OptionTable.purse(18))
					return {text = "You put your ship in the beam's path with theirs behind it. Your hull takes the beam every fourteen seconds. It goes on for the two hours they need to work around the dead boards. The ship warms the whole way through. They pay less than they would for a tow. All they needed was something to sit in the beam's way."}},
				{label = "Leave them to the beam", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck. They have a day before the beam is strong enough to matter. In a day another ship could come through. They could also find a way around the boards themselves."}},
			],
		},
		{
			id = &"the_glass_ring",
			title = "The glass ring",
			body = "An old station ring hangs in the lane. It has been dead for longer than anybody has records. The beam has swept it every four seconds the whole time. Centuries of that leaves something on a hull. A glaze, thick as the plating under it, in colours that do not have names. It is worth a great deal to the right buyer. Once every ninety minutes the beam comes around at an angle that misses the ring. It stays missing for six minutes. Six minutes is what you have.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_pulsar = true,
			choices = [
				{label = "Work the gap",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "You go in on the first second of the gap and out on the last. The cutter runs the whole way. You bring back a plate of the glaze, still warm. You bring back a piece of the ring that came away under it. Nothing else here has ever been touched.", material_id = &"sweep_glass", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "Six minutes is not enough and you take seven, and the seventh is in the beam. You are out before it can do more than heat you. The glaze is aboard, and so is a piece of the ring.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You are still finding the angle when the gap closes. You leave with a piece of the ring's frame. Your hull has had a second of pulsar on it. That is a second too long.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 28
						Run.take_hull_damage(OptionTable.toll(4), "Took a full sweep of the beam alongside the glass ring.")
						return {text = "You misjudge the gap by a full sweep. No ship is built for four seconds of the beam at this range. It goes through you the way it has been going through the ring. It leaves you nothing but heat."}},
				{label = "Take frame from the shadow side", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "You never go near the glaze. The ring throws its own shadow. In it are pieces of the frame that fell clear of the beam's line a long time ago. Holding in a shadow that moves with the ring costs fuel. What you take is plain metal, and it is safe.", material = &"wreck"}},
				{label = "Leave it to the beam", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ring and the gap, both. Somebody with a faster ship can come for the glaze. The glaze will be a little thicker by then."}},
			],
		},
		{
			id = &"the_drop_point",
			title = "The drop point",
			body = "This pulsar is a slow one. Its beam comes around once every thirty-one minutes. At this range one sweep is enough to finish a ship. So everything here runs on that clock. There is a rock the size of a city. Behind it is the one shadow the beam never reaches. People have been leaving things there for other people for a very long time. Crates, tanks, sealed cargo, stacked and tethered and still here. Nobody guards it but the beam. Going in with a load and back out gives you thirty-one minutes of open sky. Less, if you are slow.",
			tags = [&"salvage", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Run for the shadow",
					check = {attr = &"thrust", need = 8},
					met = func() -> Dictionary:
						return {text = "You go the second the beam has passed. You are in the shadow with twenty minutes to spare. The stack is deeper than it looked from outside. You take a sealed unit off the top and a crate from under it. You are back across the open with four minutes left. The beam comes around behind you.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "You are slower across the open than you meant to be. You are slower still coming back. The edge of the beam catches your stern as you clear it. You get one crate and a hot ship. Twenty-nine minutes gone on a thirty-one-minute clock.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(2), "Turned back halfway to the shadow, and the beam caught the turn.")
						return {text = "You are halfway across when the count turns against you. There is not time to make the shadow and get back. You turn around. The beam catches you turning. You come out with nothing, and with less hull than you went in with."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "Caught in the open by a slow pulsar. It came around on minute thirty-one.")
						return {text = "You misjudge the clock. The beam finds you in the open at minute thirty-one. It does to your ship what it does to any ship. Then it has passed. You are drifting at the shadow's edge in a ship that is mostly still there."}},
				{label = "Hook what you can from the edge", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You hold at the edge of the shadow. The beam's line is a hundred metres off your bow. You put the grapple in on a long cable. Three sweeps of waiting and burning go by. What comes up is what was nearest the edge. Somebody else left it there.", material = &"wreck"}},
				{label = "Leave it to the clock", stay = true, effect = func() -> Dictionary:
					return {text = "You log the rock and the interval and go. Whatever is behind it has been waiting a long time, and the beam is not going anywhere."}},
			],
		},
		{
			id = &"the_quiet_beam",
			title = "The quiet beam",
			body = "The pulsar has stopped. For as long as anyone has counted, its beam swept this system every second and a half. Two days ago it did not come around. It has not come around since. Nobody knows why. It has happened before, to other pulsars. Every time, the beam started again, in an hour or a month, with no warning. Until then, every hull that has sat in its path for centuries can be reached. They are glazed thick with what the beam leaves. Every ship within a week is coming for them. The first ones are already here.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Work until the last minute",
					check = {attr = &"sensors", need = 8},
					met = func() -> Dictionary:
						return {text = "You put the dish on the pulsar. You watch it the whole time you work. Six hours in, it tells you the spin is coming back into line. You leave with a plate of the glaze. You also take a whole sealed unit off the nearest hull. You are eleven minutes clear when the beam comes around.", material_id = &"sweep_glass", module = true},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "You read the pulsar right and cut it fine. The first sweep catches your stern as you clear the lane. A plate of glaze and a piece of hull. The ship spends the rest of the day cooling.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 20
						return {text = "You cannot make sense of the pulsar's spin on the dish, and you do not trust it. You take one piece off the nearest hull and go early. The beam comes back four hours later. You were right not to trust it. You leave with a piece of hull instead of a fortune.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 32
						Run.take_hull_damage(OptionTable.toll(4), "Working a glassed hull when the beam came back.")
						return {text = "You are still working when the beam comes around. There is no warning. A second and a half of it, and then another. You are out of the lane before the third. Everything on the outside of the ship is a different colour than it was."}},
				{label = "Take what is nearest and go", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					return {text = "You do not read the pulsar. You take the first thing the grapple can reach off the nearest hull. You burn out of the lane and keep burning until the beam's track is far behind you. It can come back in an hour or a month. It will not find you in the lane.", material = &"wreck"}},
				{label = "Stay out of the lane", stay = true, effect = func() -> Dictionary:
					return {text = "You watch the others go in from a long way off. You keep the dish on the pulsar. You do not go in. Whether they get out before it starts again is their business."}},
			],
		},
		{
			id = &"the_crossing",
			title = "The crossing",
			body = "A herd is crossing the lane. There are hundreds of them, slow and packed close. The small ones are in the middle. The old ones are on the outside. The whole mass of them is barely moving, and it covers the one stretch of sky you need. They are not hostile. They will not move for you, and they will not notice you. The smallest of them is the size of a hauler. Going around costs a day. Going through costs an hour, if nothing turns.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Thread the herd",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You go through at their speed. It is the only speed that works. None of them so much as turn. Halfway across, an old one on the outside sheds a sheet of hide. It is the size of your ship. You take it on the way past.", material_id = &"hide_scrap"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "It takes two hours and a lot of correcting. One of the young ones follows you part of the way. It is curious. Something that came off one of them drifts against the hull as you clear the far side. You keep it.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Brushed by the flank of something the size of a hauler.")
						return {text = "One turns. It is not turning at you. It is just the way something that size turns. Its flank comes across your bow and takes the paint off. You are through, with nothing but the scrape."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Between two of them when they closed.")
						return {text = "Two of them close in, slowly, with you between. You back out of the gap. The hull grinds on both sides. You go around after all, and it costs the day as well."}},
				{label = "Follow the old ones around the edge", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "The old ones keep to the outside, and the old ones shed. You follow the edge of the herd for a day at their pace. You take the one good piece that drops. Flying that slow for a day costs fuel. The herd does not mind you there.", material = &"fauna"}},
				{label = "Wait for them to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the lane. You watch them go by for most of a day. It costs nothing but the day. The last of them clears the lane, and the sky is empty again."}},
			],
		},
		{
			id = &"the_hunters",
			title = "The hunters",
			body = "A hunting ship has made a kill. The dead one is a big one, the size of a station. It hangs in the lane with the hunter alongside, cutting. The hunter is a small ship and the body is not. They are working fast. The pod is two hours out and coming back. They want the body towed to their tender before that. They will pay for the tow. They will also sell a share of it, cheap, to anyone who would rather not be here when the pod arrives.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 6,
			needs_fauna = true,
			choices = [
				{label = "Tow the body to their tender",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "It is the heaviest thing you have ever had on a line. It moves slowly, and then all at once. You get it to the tender with forty minutes to spare. They pay in full. They start cutting again before the line is off."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes everything the drive has and most of the two hours. The tender has the body under its cutters before the pod is on the dish. They pay what they said."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The line holds and the body barely moves. You get it half the distance. Then the pod shows on the dish. The hunters cut it loose and run. They pay you for the half."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Towing a dead one when the pod came back.")
						return {text = "The pod arrives while the body is still on your line. The first of them comes past close and slow, to see what you are doing. Its flank takes your hull, and the plating gives. It is not hostile. It is just not paying attention. The hunters are gone, and nobody pays."}},
				{label = "Buy a share", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "They cut you a share off the flank while the line is still going on. They take your money. You are gone before the pod is on the dish. Nobody will ever sell you this cheaper, because the pod is two hours out.", material = &"fauna"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck and go. Two hours is enough for a fast ship to be somewhere else, and you intend to be. What the pod finds when it gets here is between the pod and the hunters."}},
			],
		},
		{
			id = &"the_singer",
			title = "The singer",
			body = "One of them is alone, and it is singing. It is old and the size of a station. Scars run the whole length of its leading edge. The song is loud on every channel. It whites out the dish for a hundred kilometres around. The others are gone. It is not going anywhere. Whatever is wrong with it is slow, and you can hear that in the song. A hunting ship two days out has been asking on the channel for just this. They will pay for the bearing. Rendered, it is worth more than your ship. Alive, it is a wonder. Either way it is dying.",
			tags = [&"signal", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 7,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Work close and take what it sheds",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						return {text = "You go in slow, inside its song, close enough to see the scars. It knows you are there and does not care. What it sheds as it drifts is worth a great deal. You take a sheet of hide and something smaller that came away with it. It keeps singing.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get close and it turns, slowly, the way something that size turns. You spend the next hour staying out of its way. What you take is what came loose in the turn.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Too close to a singer when it turned.")
						return {text = "It turns. It is not turning at you. It just turns, and you are in the way of it. You come away with a scraped hull and nothing else. It goes on singing."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "Too close to a singer when it rolled.")
						return {text = "You are close alongside when it rolls. There is no anger in it. There is a great deal of weight. For a moment your ship is between that weight and nothing. Then it is past. You come away with nothing, and with a hull that will need a yard."}},
				{label = "Sell the bearing", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(20))
					return {text = "You give the hunting ship the bearing. They pay for it before you have finished reading it out. In two days they will be here, and the song will stop. You will be a long way off by then. You will not hear it stop."}},
				{label = "Leave it singing", stay = true, effect = func() -> Dictionary:
					return {text = "You go. The song follows you out on every channel for a hundred kilometres. Then it is behind you. Then it is gone. It will go on singing for weeks, alone. Nobody will hear about it from you."}},
			],
		},
		{
			id = &"turning_the_herd",
			title = "Turning the herd",
			body = "A herd is moving toward the station's approach lane. There are two hundred of them, slow and not paying attention. A small ship is trying to turn them. One person is aboard it. She is running every light she has along the near flank. It is not enough. If the herd reaches the lane, everything inbound for a week goes around it or through it. She is asking anyone on the channel to take the far flank. Lights on, drive loud, and turn with her. The station will pay her, she says, and she will pay you.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Take the far flank",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You run the far flank with every light on and the drive at full noise. The herd leans away from you, slowly and all together. Then it is turning. An hour later the lane is clear and the herd is going somewhere else. She pays you before the station has paid her."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes three hours, and the drive is hot from being loud that long. Most of them turn. Two old slow ones keep going, and two is few enough that the station can route its ships around them. She pays what she offered."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get half of them turned. The other half go through anyway, at their own pace, and the lane is a mess for a week. She pays you for the half. The station pays her for the half. Nobody is happy."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Too close to the herd's flank. One of them turned the wrong way.")
						return {text = "You get too close to the flank. One of them turns the wrong way, toward the noise instead of away from it. Its side comes across your bow and takes a metre of plating with it. The herd goes into the lane behind it. Nobody pays."}},
				{label = "Make noise on the herd's channel", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "You do not fly the flank. You put the dish on the frequency they call to each other on. You fill it with noise. The herd does not like it. It leans away from where the noise comes from. That is slower than flying a flank, and it heats the dish and everything behind it. They turn. She pays less than she offered for the flank. She says the noise was clever."}},
				{label = "Leave her to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish her luck and go. The herd is a day from the lane. That is long enough for her to think of something, or for the station to send a second ship, or for neither."}},
			],
		},
		{
			id = &"the_grazing",
			title = "The grazing",
			body = "The herd has stopped to feed. Forty of them hang around a body of dirty ice the size of a small moon. They are close together, mouths to the surface, and they will be there for days. Feeding, they shed. What comes off is old hide, plates off their leading edges, and things that come loose when something that size holds still. It drifts, and it is worth money. They are not hostile and they are not paying attention. A startled herd moves all at once, in every direction.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Work among them, quietly",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in with the drive cold and the lights down. You drift among them the way the ice drifts. They never look up. You take a sheet of shed hide the size of your ship. You also take a plate of something harder off an old one's leading edge. You are out before any of them has finished a mouthful.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "One of them notices you and does not care. You get one good piece off the drift between them. You leave before the others notice too. The drive is warmer than a quiet ship's should be.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Between three startled ones and the ice.")
						return {text = "One of the young ones startles. The two beside it startle at that. For a minute the herd is a wall moving in three directions. You back out with a scraped hull and nothing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "In the middle of a feeding herd when the whole herd startled.")
						return {text = "The whole herd startles at once. There is nowhere to go that they are not going. For thirty seconds your ship is a small thing in a very large crowd. Then they are gone. The hull has the shape of the crowd in it."}},
				{label = "Wait at the edge for what drifts out", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 9)
					return {text = "You hold a safe distance out. You let the shed come to you for a day, and take the one piece worth taking. Holding station off an ice body with forty of them pulling at it costs fuel. What drifts furthest is the oldest, and the oldest is worth the least.", material = &"fauna"}},
				{label = "Leave them to feed", stay = true, effect = func() -> Dictionary:
					return {text = "You go around. They will be here for days. In a week the ice will be a little smaller. The shed will be further out, and somebody else will have been through."}},
			],
		},
		{
			id = &"the_timekeeper",
			title = "The timekeeper",
			body = "There is a relay in this system that does one thing. It listens to the pulsar and broadcasts the tick. Every ship in the ring sets its clock by it, because the tick never drifts. An old technician runs the relay alone. The antenna has to point straight at the pulsar to hear it. The motor that turns the antenna has burned out. The antenna points at empty sky now, a few degrees off. He cannot go outside to turn it. He wants a ship to put the grapple on the mount and turn it back toward the pulsar. A degree at a time, while he listens for the signal.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_pulsar = true,
			choices = [
				{label = "Nudge the dish back on",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You put the grapple on the mount and turn the antenna in degrees. Then in tenths of a degree. The old technician calls the signal strength over the channel. It takes an hour. The tick comes back all at once, clean. Every ship in the ring that is listening gets its clock back. He pays what he has. It is more than you expected."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						Run.heat += 6
						return {text = "It takes three hours, because the mount sticks, and the drive runs hot holding position that finely for that long. The tick comes back. He pays what he offered."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You get the antenna close enough that he can hear the pulsar faintly. It is not close enough to broadcast a clean tick. He can finish the last degree himself, once he has a spare motor rigged. He pays you for getting him most of the way."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "The mount gave way under the grapple, and the antenna swung.")
						return {text = "The mount gives way under the grapple. The antenna swings, and your hull is where it stops. It is further off the pulsar than it was. He says nothing for a while. Then he says it is not your fault."}},
				{label = "Broadcast the tick yourself", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "Your dish is on the pulsar already. You put the tick on his frequency, at his power. For six hours you are the relay. That is how long he needs to rig a spare motor and turn the antenna himself. It heats the dish and everything behind it. He pays for six hours of being a clock. That is less than he offered for the turning."}},
				{label = "Leave him to his clock", stay = true, effect = func() -> Dictionary:
					return {text = "You give him the time off your own board and go. The ring will drift a little more. Somebody will come through who has the patience for it."}},
			],
		},
		{
			id = &"thin_glaze",
			title = "Thin glaze",
			body = "The pulsar beam reaches here every six seconds. It is faint. Most ships never notice it. It has been doing that for a very long time. A debris field hangs in its track. It is old markers, dead satellites, and pieces of things that broke up in the lane. Every piece wears a thin skin of what the beam leaves. It is a glaze in colours the dish cannot name. On one piece it is thin. On a hundred pieces it is not thin at all. To take it you fly slow through sharp metal. The hull takes hits the whole way.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			needs_pulsar = true,
			choices = [
				{label = "Sweep the field",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "You go through slow with the grapple out. The hull takes the small stuff. You scrape as you go. Three hours later you come out with a plate of the glaze. It is a hundred thin pieces pressed together. The ship rings for an hour after.", material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Three hours in a field of sharp metal, scraping glaze.")
						return {text = "You get the glaze. The field takes a piece of your plating for it. Something in the middle of the field hits harder than anything there should hit.", material_id = &"sweep_glass"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Dodging, not scraping, halfway through a field of sharp metal.")
						return {text = "Halfway through the field you stop scraping and start dodging. You come out with a dented hull. You also come out with one piece of somebody's old satellite. There is no glaze on it worth the name.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Hit broadside in a debris field, by a piece nobody saw move.")
						return {text = "A piece the size of a door comes out of the field. It moves faster than anything in there should. It takes the hull broadside. You leave the way you came in, with nothing."}},
				{label = "Take the nearest piece", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You do not go into the field. You hold at its edge and take the nearest piece with the grapple, and scrape it, and it is not much glaze. The metal under it is old but sound. It costs fuel to hold at the edge of something that is drifting.", material = &"wreck"}},
				{label = "Leave it to the beam", stay = true, effect = func() -> Dictionary:
					return {text = "You log the field and go. Another century of six seconds at a time and the glaze will be worth somebody's while. It will not be yours, and that is fine."}},
			],
		},
		{
			id = &"the_last_turn",
			title = "The last turn",
			body = "Every ship this deep does the same sum, and this is where the sum turns. From here a full tank gets you home. Anything less does not. Somebody painted the numbers on a rock years ago, big enough to read from the approach. Around the rock are the ships that read them too late. There are thirty or forty hulls, all pointed outward. Every one of them ran its tank dry a day or a week short of anywhere. Their holds are still full. Fuel is the only thing they ran out of.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Read every tank on the dish",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 24
						return {text = "Forty hulls, forty tanks, and one of them is not empty. It is a hauler that made the turn with fuel to spare and died of something else. You take its fuel through the transfer line. You take one thing out of its hold. The rest of the field you leave as you found it.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel += 12
						Run.heat += 10
						return {text = "Two hours of reading tanks. Most of them are dry. Then one has a few units left in the bottom. You get twelve units out of it. The dish is hot from the reading."},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "Every tank reads dry. You take one thing out of one hold, because you are here. The dish is hot from three hours of finding nothing.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "A dry tank that was not dry. It sat on a hull that turned back too late.")
						return {text = "One of the tanks is not dry, and what is in it is not fuel either. Something a hauler was carrying has sat in the cold for years, and it goes when the transfer line opens. The hull takes it on the flank. You come away with nothing but the scorch."}},
				{label = "Work the nearest holds", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You skip the tanks and go hull to hull at a crawl. That costs fuel. You take the best thing out of the nearest three holds. They were full when they stopped. They are still full apart from what you take.", material = &"wreck"}},
				{label = "Do your own arithmetic and go", stay = true, effect = func() -> Dictionary:
					return {text = "You read the numbers on the rock. You read your own tank. You go on while the numbers are still on your side. The hulls have been here for years. Nothing this deep is going to move them."}},
			],
		},
		{
			id = &"the_fuel_cache",
			title = "The fuel cache",
			body = "Six fuel tanks hang on a tether. They are marked with a ship's name and a date eleven months old. They sit where anybody coming out from the core would pass them. Somebody left their way home here. They went inward with a lighter ship and a plan to come back for this. They have not come back yet. Eleven months is a long time this deep. People have come back from longer. The tanks are full. The valves have been in the cold for eleven months. Nothing stops you except the name painted on them.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Take all six",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 30
						return {text = "You warm the valves one at a time and take all six. That is thirty units. Whoever painted their name on these has a lighter ship and a plan. The plan now has six fewer tanks in it. Nobody will know for months."},
					clean = func() -> Dictionary:
						Run.fuel += 18
						Run.heat += 10
						return {text = "Four of the valves come free and two do not. The ship runs hot from warming them. You get eighteen units. Two tanks stay on the tether with the name still on them. Two is not enough to get anybody home."},
					partial = func() -> Dictionary:
						Run.fuel += 6
						Run.take_hull_damage(OptionTable.toll(2), "A frozen fuel valve, opened too fast.")
						return {text = "The first valve lets go before it is warm. The tank empties itself across your flank. You take six units from the second one, slowly, and stop."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A fuel valve, eleven months in the cold. It was opened too fast.")
						return {text = "The tank comes apart against the hull when the valve goes. Fuel everywhere, none of it in your tank, and a dent from bow to midships. You leave the other five where they are."}},
				{label = "Take two and leave four", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 12
					return {text = "You take two tanks, slowly, warming the valves the long way. Four stay on the tether with the name still on them. Four is enough to get a lighter ship home from the core, if the pilot is careful."}},
				{label = "Leave them their way home", stay = true, effect = func() -> Dictionary:
					return {text = "You log the name and the date and go. Whoever they are, they are either dead already or they are going to want these very badly. You leave them their tanks."}},
			],
		},
		{
			id = &"three_years_in",
			title = "Three years in",
			body = "A survey ship is holding station here. Four people are aboard. They have been counting things for three years. A company sent them to map the approach, log the traffic, and report every ninety days. They have reported every ninety days. Nobody has answered in two years. Nobody has paid them in two and a half. They are still at it, because the other choice is going home to find out why. Their long-range receiver has been dead as long as the silence has. They want news and they want fuel. They have three years of measurements to trade for either.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Fix their receiver",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You find the fault in forty minutes. It is a board that died two years ago and never told anyone. The receiver comes back, and so do two years of messages, all at once. The company folded eighteen months ago. They pay you from the ship's account, which is theirs now. They give you the three years of measurements. Nobody says much for a while.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes half a day to find the fault. The receiver comes back. It brings eighteen months of messages and then stops. That is enough. They pay you what they can spare. They give you the measurements.", archive_recover = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 10
						return {text = "You get their receiver hearing the near channels and not the far ones. That is enough to know the company is not answering. It is not enough to know why. They pay for the attempt. They go back to their instruments."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(3), "A survey ship's power bus, through the connecting line.")
						return {text = "You run the fault down into their power bus and the bus goes. Their ship is dark for an hour, and yours takes a jolt through the connecting line that scorches a metre of plating. Their receiver is no better than it was. Nobody pays."}},
				{label = "Trade fuel for the measurements", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					return {text = "You give them fourteen units. They give you three years of the approach. That is every hull that went inward and every one that came back, on film and in the log. They also give you a case of the company's rations, which is what they have plenty of. They ask for news. You give them what you have, and it is not much.", archive_recover = true, material_id = &"survey_film", material = &"event"}},
				{label = "Leave them to their survey", stay = true, effect = func() -> Dictionary:
					return {text = "You give them what news you have on the channel and go. They thank you and go back to their instruments. The next report is due in forty days, and they will send it."}},
			],
		},
		{
			id = &"still_inbound",
			title = "Still inbound",
			body = "Six haulers are crossing the system in formation, drives lit, at a crawl. They have been crossing it for a long time. The dish puts their speed at a few metres a second. Their heading is the core. Nobody answers. The hulls are cold on every band but the drives. This is a convoy set on automatic long ago by people who are long dead. It is still going where it was told. Their holds are sealed. Working them means matching a speed that is not quite zero. It means cutting on the move, inside a formation that still corrects itself.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match them and cut",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						return {text = "You match the crawl and slide in among them. They do not notice. There is nothing left aboard to notice. Two hours alongside the lead hauler gets you a sealed unit out of its rack and a crate from its hold. Then you fall back and let the six of them go on without you.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You match the speed and lose it twice. The cutter runs hot from starting and stopping. You get one crate out of the last hauler in the line.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The formation shifts, one hauler correcting for another. You spend the pass staying out of the way of six ships that do not know you are there. You come away with nothing, and hot from the dodging."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "In the gap between two haulers of a dead convoy. One of them corrected.")
						return {text = "You match the wrong hauler. The one behind it corrects into the gap you are in, slowly. There is nowhere to go that is not a hull. It takes your flank and keeps going, at a few metres a second, toward the core."}},
				{label = "Pace them for a day", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					return {text = "You hold a kilometre off instead of going alongside. You match their crawl for a day. Six old hulls are still shaking from their own drives. You take the one good piece that comes loose. Flying that slow for a day costs fuel.", material = &"wreck"}},
				{label = "Let them go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the heading and the speed and let them go. At that speed they have years yet before they reach anything. They are not going to turn."}},
			],
		},
		{
			id = &"the_pilgrims",
			title = "The pilgrims",
			body = "Nine people on a ship built for four are going to the core. They know what that means. They are going anyway. They are polite about it. Nobody aboard is asking to be talked out of it, and their drive is fine. What they want is fuel. Enough to get there is not enough to be sure of it. They will pay whatever you ask, because they will not need the money after. They also ask, carefully, if you would fly with them for the first day. They will pay for that too.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Fly with them for a day",
					check = {attr = &"hull", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You fly inward with them for a day. Nobody says much on the channel. At the end of it they thank you, and pay, and go on, and you turn around. Your hull comes through it fine."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "A day inward with nine people who were not coming back.")
						return {text = "A day inward with nine people who are not coming back. Your plating comes back marked by whatever is out there that nobody has charted. They pay in full and thank you, and you turn around."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Half a day inward, and the plating did not like it.")
						return {text = "You turn back at midday. Your plating is reading things a day would not undo. You say so. They understand, and pay you for the half day. They go on without you."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.take_hull_damage(OptionTable.toll(4), "Flew a day inward with nine strangers. Hit something that was not on the chart.")
						return {text = "Half a day in, something that is not on the chart takes a piece of your flank. You burn hard coming back out. They pay nothing, since you were the one who turned around."}},
				{label = "Sell them fuel", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 18)
					Run.add_credits(OptionTable.purse(30))
					return {text = "You sell them eighteen units at a price they do not argue with. They would not have argued with any price. They thank you and fill their tanks. They go inward. You watch them on the dish until the dish loses them."}},
				{label = "Decline and go", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them no, and they are polite about that too. They will wait for the next ship, and another ship will come through eventually."}},
			],
		},
		{
			id = &"going_the_other_way",
			title = "Going the other way",
			body = "Every ship you have seen this deep was going in. This one is coming out. It is a long way off and moving fast, running hot, one drive of three lit. It does not slow down when you hail it. It answers, though. A tired voice says it has no fuel to spare and no time to stop. It has something aboard worth more than both, from further in than you have been. They will trade some of that for fuel. You have to match its speed long enough to pass a line. It is not stopping for anything.",
			tags = [&"signal", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match it and trade",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "You match a ship that is not slowing, close enough to pass a line. You hold there for six minutes. Ten units go one way and a sealed case comes the other. The case holds a piece of equipment from further in than the chart goes. The voice tells you three things about the core while the line is connected. Then it is gone.", module = true, archive_recover = true},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "You hold the match for four minutes. That is long enough for the fuel. It is not quite long enough for what they meant to send. Something smaller comes across instead. The voice says one thing about the core, and it is gone.", archive_recover = true, material = &"event"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.heat += 14
						return {text = "You get the line across and the fuel across. Then you lose the match, and the line parts before anything comes back. They have your fuel. You have a hot drive from the chase. A voice on the channel says sorry and means it, and does not slow down."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.take_hull_damage(OptionTable.toll(4), "Touched hulls with a ship that was not stopping.")
						return {text = "You get the match wrong and the two hulls touch. The closing speed is not one that hulls should touch at. They keep going. You spend fuel you did not plan to spend getting the drift off. You drift a while longer before anything on your board answers."}},
				{label = "Give them fuel and ask nothing", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 15)
					return {text = "You put fifteen units into a drop tank and leave it on their line. They take it at speed without stopping. The voice talks the whole time it is in range. What it says about the core goes in your archive.", archive_recover = true}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "You let it go. It is out of range in an hour, still running hot on one drive. It is still going the other way. The channel is quiet again."}},
			],
		},
		{
			id = &"frost",
			title = "Frost",
			body = "A container ship has split a tank. What was in the tank was cold. It was liquid gas, the kind that is only liquid while somebody keeps it that way. It is not liquid now. It is a cloud around the ship two kilometres across, and it freezes onto whatever it touches. The frost is a centimetre thick on every surface. That includes the radiators, which cannot shed heat through ice. The containers inside the cloud are whole. Working them means an hour in a cloud that will coat your vents in the first ten minutes.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Work through the frost",
					check = {attr = &"thermal", need = 8},
					met = func() -> Dictionary:
						return {text = "You run the radiators hot enough to shed the frost as fast as it forms. Then you go in. An hour in the cloud gets you a sealed unit and a container from the racks nearest the split. You come out white from bow to stern, and warm underneath.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "The vents ice over twice, and twice you back out to shed it and go back in. You get one container. The ship runs hot for a day afterwards, working the frost off.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						return {text = "Ten minutes in, the radiators are ice. The heat has nowhere to go. You back out with nothing. The ship has to sit for hours before it can shed what it is carrying."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "Iced radiators in a frost cloud. The drive section cooked from the inside.")
						return {text = "You stay in too long and the heat builds with nowhere to go. Something in the drive section gives up before the frost does. You come out of the cloud white and hot. A piece of the hull stayed behind."}},
				{label = "Wait for the cloud to thin", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					return {text = "The cloud is spreading, slowly. You hold outside it for a day and a half, burning to stay put. You go in when it has thinned enough to work the outer racks without icing. You get one container, from the edge.", material = &"wreck"}},
				{label = "Leave it frozen", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ship and go around the cloud. In a month it will have spread thin enough for anybody, and somebody will have been through."}},
			],
		},
		{
			id = &"the_sleepers",
			title = "The sleepers",
			body = "A ship is drifting on the approach with twelve people aboard. All twelve are asleep. Cold sleep, the long kind. They went down years ago with the ship set to wake them when help came. Help did not come. The ship is still waiting. It is failing. The power that keeps them cold is running down. Its transponder carries a standing bounty for a tow toward any station, payable from the ship's own account. The nearest station that could take them is nine days out, in the direction you are not going.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Tow them out to where the traffic runs",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You take them a day outward, to the route the traffic uses. You leave them on it with their transponder loud. The ship pays you the bounty for the leg. Its account does not know the difference between a station and a day closer to one. It copies you its log. They are a day nearer to somebody going the right way, and still asleep.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 10
						return {text = "The tow takes two days instead of one, and the drive is hot from the pull. You leave them where the traffic runs. The ship pays for the leg."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get them half a day outward and the line parts. You burn an hour of fuel chasing the loose end down and putting it back on. Half a day is not far enough to matter. The ship pays for half a day."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A sleeping ship, on a tow line, swinging.")
						return {text = "The tow line comes tight wrong. The ship swings into your flank, all of it, slowly. Nobody aboard wakes up, and nobody pays."}},
				{label = "Take what they will not miss", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "Their racks are full and their holds are full. None of the twelve will know. You take a sealed unit and a crate, and leave the rest. The ship's power runs down a little faster for the hour your cutter was in it.", module = true, material = &"wreck"}},
				{label = "Leave them sleeping", stay = true, effect = func() -> Dictionary:
					return {text = "You log the position and the bounty and go. Somebody heading for a station will pass here sooner or later. The ship will still be asking."}},
			],
		},
		{
			id = &"first_on_the_wreck",
			title = "First on the wreck",
			body = "Your grapple has been on a dead ore freighter for six hours. The cutter is still out on it. Two ships come in on your bearing and stop a kilometre off the bow. They were headed here before you were. The larger one hails to say the wreck is claimed. It is not. They say they are happy to wait, and they are not. What is left in the racks sits forward of the break. The break is the side those two ships have parked on.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 12,
			min_danger = 1,
			max_danger = 2,
			choices = [
				{label = "Cut forward of the break",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You work in tight against the break. Neither of them can follow without trading paint. The grapple takes a drive module still bolted to its frame. A bay of cut plate comes out with it. You are clear before the larger ship has finished its second hail. They watch you go and nobody fires.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "You take the near racks fast and run the cutter hot to do it. One bay of plate goes aboard. The radiators shed for an hour after that. The two ships sit exactly where they were when you started.", material = &"wreck"},
					partial = func() -> Dictionary:
						return {text = "They drift in on either side of the break. There is no room left to work in. You back the grapple off with nothing in it. Neither ship hails again, and the larger one is on the racks before you have stowed the cutter."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The bow of a dead ore freighter, taken at the wrong angle.")
						return {text = "You commit to a gap that is not as wide as the plate said. The freighter takes a length of your bow and keeps it. The two ships off the break do not move while that happens. They are still not moving when you pull clear."}},
				{label = "Hold the wreck", fight = true, effect = func() -> Dictionary:
					return {text = "You put the ship between them and the break with the weapons live. They have spent six hours talking about waiting. In that time they decided they are owed this one. The larger ship comes first, and the smaller one comes around behind it.", fight = true}},
				{label = "Back off the hull", stay = true, effect = func() -> Dictionary:
					return {text = "You stow the cutter and let the grapple go. The larger ship is on the break before you clear the field. What was forward of it ends up in somebody else's racks."}},
			],
		},
		{
			id = &"the_wrong_writ",
			title = "The wrong writ",
			body = "A patrol boat comes up on your quarter with its lights going. It puts a stop order across the channel. The writ carries a registry prefix that matches yours. The hull number on it does not, and it is off by one digit. An office four rings inward issued it, and that office stopped answering queries in the spring. The pilot reads the order out twice. She is young and she means to do this properly. The ship the writ wants came through this ring an hour ahead of you.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 11,
			min_danger = 1,
			max_danger = 2,
			choices = [
				{label = "Put the registry record on the channel",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You put your own registry entry across in the open. You send the office's numbering scheme with it. She reads both, reads the writ again, and stands the order down. Her service owes a held ship a set sum for a stop it cannot back up. She pays it out of the boat's account before she is done saying sorry."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(12))
						return {text = "It takes three calls and most of an hour. At the end of it she agrees the digit is the digit. She logs the fix and releases you. Her service posts a small fee for the time she took, and she pays it."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "She will not clear a hull on a record she cannot check. The office that could check it is not answering her either. You hold station a day and a half while she files upward. That costs eight units on the reactor. She lets you go without ever being told she was wrong."},
					botched = func() -> Dictionary:
						return {text = "You talk over her twice. She has been told what a ship doing that usually means. The boat comes about with the mount on its bow live. She has the writ to cover whatever she does next.", fight = true}},
				{label = "Sit still for the inspection", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 6)
					return {text = "You hold station cold for most of a day. She works a scanner through the hold against a list written for another ship. She finds nothing on it. Nothing on it was ever here. Her stores owe a detained hull its rations, so she sends a case across before she goes.", material = &"event"}},
				{label = "Hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "You do not answer the order. You do not come off the throttle. The boat keeps your quarter for twenty minutes with its lights going. Then it drops back and goes looking for the hull number it was given."}},
			],
		},
		{
			id = &"the_far_side",
			title = "The far side",
			body = "A scavenger crew has a cutter ship anchored amidships on a passenger hull. Floods run the length of it and half the racks are already out. They watched you come in. Nobody hails and nobody stops working. Their two smallest ships have drifted out to sit between you and the wreck. Neither one quite points at you. The stern of the hull is dark, and nothing at all has come off it yet. They will get to it in a day or two.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Work the stern dark",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						return {text = "You come in under their floods with the reactor down. The radiators point at nothing. The stern is yours for most of an hour. A drive module comes off its mounts, and a bay of cut plate comes with it. The cutter ship amidships never stops working.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get one bay of plate off the stern. Then the reactor has to come back up to move you. The bloom says plainly where you have been, and nobody comes after it. The plate is aboard and the floods stay pointed forward.", material = &"wreck"},
					partial = func() -> Dictionary:
						return {text = "One of the two small ships has been watching the stern the whole time. It does not bother to hail first. Amidships the cutter crew stops working to watch. The floods swing aft to give everyone a better look.", fight = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The stern frame of a passenger hull, hit at speed in the dark.")
						return {text = "You come in dark and you come in wrong. The stern frame is where you find that out. The closing speed is one nobody would choose. You leave the wreck with a torn bow and nothing in the bay."}},
				{label = "Run your cutter on their seam", effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "They take the offer on the second hail. They put you on the seam they were saving for last. You burn your own reactor on their wreck for a full shift. They cut you in for one bay of plate at the end of it. Then they go back to work, and nobody says a word about the stern.", material = &"wreck"}},
				{label = "Leave the stern to them", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and come about. You take the crossing you were on before the dish found the wreck. The two small ships hold their station between you and the hull. They stay there until you are well out of range."}},
			],
		},
		{
			id = &"the_open_toll",
			title = "The open toll",
			body = "An automatic fuel platform turns slowly at the edge of the ring. It pumps for anyone who comes alongside. It has done that since the people who put it there stopped answering. Two ships sit off the intake with a rate card running on the open channel. They have a strobe across the approach. They did not build the platform and they do not maintain it. What they have is the intake. The nearest station that would care is nine days inward.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Burn the approach and take the intake",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 24
						return {text = "You come in high off the strobe and fast. You are coupled before either of them has finished coming about. The pumps do not ask who you are. You leave with a full tank. The rate card is still repeating on the channel behind you."},
					clean = func() -> Dictionary:
						Run.fuel += 14
						Run.heat += 6
						return {text = "You take the approach hot and get most of a tank across. The nearer ship closes in until the coupling gets awkward. You break off with the radiators loaded. The pumps keep running for whoever comes next."},
					partial = func() -> Dictionary:
						Run.fuel += 6
						return {text = "They get a hull across the intake before you are a third full. You come off the coupling with six units, enough to reach the ring. They go back to their station off the arm."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The intake arm of a fuel platform, hit at full burn.")
						return {text = "You commit to the approach at full burn. The intake arm is not where the old plate said. The platform keeps turning and keeps pumping. You come off it with a fold in the bow and the tank no fuller than it was."}},
				{label = "Push them off the intake", fight = true, effect = func() -> Dictionary:
					return {text = "You come in on the two of them instead of the platform. They have been collecting on an open pump for a long time. The rate card was doing all the work. It takes them a while to sort out which one flies the first pass.", fight = true}},
				{label = "Keep clear of the intake", stay = true, effect = func() -> Dictionary:
					return {text = "You take the long way around the platform, well outside the strobe. You leave the ring on the tank you came in with. The rate card repeats on the channel until you are out of range."}},
			],
		},
		{
			id = &"nothing_taken",
			title = "Nothing taken",
			body = "Three haulers come out of the ring together and put their lights on you. Somebody took eleven containers off the second of them four days ago. The ship that did it was the same class as yours and ran the same drive signature. They have stopped every ship of that class since. The woman speaking for them is tired and polite. She is also certain about what she is looking at. They are not going to shoot first. They are not going to stand aside either.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Run the reactor down and let them read it",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						return {text = "You take everything down to the hull and hold it there. Three sets of instruments agree that this ship has not burned hard in a week. She says sorry in one sentence. Then she gives you a bearing eleven minutes old. The hull they want crossed the ring behind them while they were stopping you. She asks whether you are still cold enough to get close to it.", fight = true},
					clean = func() -> Dictionary:
						return {text = "The read settles slowly and it settles clean. She takes a minute over it. Then she says so on the open channel, where the other two can hear her. She pulls the lights off your bow. The three of them go back to stopping ships."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "The radiators will not come down far enough for the reading to settle. She will not clear a hull she cannot rule out. You take the long way out of the ring and burn ten units doing it. Two of the three hold your bearing for six hours. The third sits somewhere behind the moon."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A warning shot from a hauler crew that had made up its mind.")
						return {text = "You come up hot in the middle of the reading, and all three read that the same way. The shot is meant as a warning and it lands as a hit. She says nothing after that. The lights stay on you until you are out of the ring."}},
				{label = "Sell them an escort to the crossing", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					Run.add_credits(OptionTable.purse(26))
					return {text = "She does not clear you. She does not want to spend the afternoon on it either. What she wants is the only armed hull in the ring flying where she can see it. You burn alongside the three of them as far as the crossing. They pay the rate they would have paid anybody. Nobody mentions the containers again."}},
				{label = "Decline the stop", stay = true, effect = func() -> Dictionary:
					return {text = "You tell her what class of hull you fly. You tell her you are not the one she wants. Then you hold your heading through the middle of the three of them. Nobody follows. The eleven containers are somewhere in the ring, and the haulers are still stopping ships."}},
			],
		},
		{
			id = &"the_licensed_seam",
			title = "The licensed seam",
			body = "You are half a shift into a nickel face on a rock nobody has filed on. Three ships come up from the dark side of it in formation. The outfit flying them has held the licence here for nine years. They have worked the rock for two of those. The filing is the first thing they put on the channel. Their smallest ship is bigger than yours. There are three of them. The face under your cutter is the best one on the rock.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 5,
			max_danger = 6,
			choices = [
				{label = "Hold the anchor and finish the cut",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "They come in to lean on you and the ship does not move. Twenty minutes of that changes what the foreman is asking for. He buys the loose half of the cut, at a rate that costs him less than another hour of this. The rest of it stays in your bay. The anchor holds until you decide to move it.", material = &"mining"},
					clean = func() -> Dictionary:
						return {text = "You get the face off the rock clean. The grapple is still walking it in. Their smallest ship comes around the near limb with its mount live and its lights off. The foreman is not on the channel any more. The ore still hangs between the rock and your bay.", fight = true},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "They put two hulls across the face and hold them there. They are close enough that your radiators have nowhere clean to point. You spend an hour of reactor deciding whether to push it. Then you stow the cutter. The cut stays on the rock, most of the way free of it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The overhang over the seam, shaken down by a ship's wash.")
						return {text = "You hold the anchor well past the point where it means anything. The second ship comes in close. It puts its wash across your bow. The overhang above the seam comes down on top of that. You come off the rock with a bent bow and nothing in the bay."}},
				{label = "Buy a day on their licence", cost_credits = 50, effect = func() -> Dictionary:
					Run.add_credits(-50)
					return {text = "The foreman has a rate for this and quotes it without checking anything. He has quoted it before. You pay for the day and finish the cut. Three of their ships hold station close enough to watch every pass of the cutter. You come off the rock with the bay of nickel the face was worth.", material = &"mining"}},
				{label = "Leave them the face", stay = true, effect = func() -> Dictionary:
					return {text = "You stow the cutter and back off the rock. Half a shift is spent and the bay is empty. They are on the face before you have cleared the limb. Nobody says a word on the channel about any of it."}},
			],
		},
		{
			id = &"the_wreckers",
			title = "The wreckers",
			body = "A crew works this crossing with a light. They hang it off a rock where a station light would be. There is nothing behind it. They have been at it long enough that the hulls past the rock are frames now. Two ships sit in the rock's shadow with their drives idling and their lights off. The light still transmits a dock code that was retired forty years ago. Nobody polices this deep, and nobody has for a long while.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Read the rock against the real bearing",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "The code is forty years dead. The rock it comes off has no dock. You work the far side of the field instead. The frames out there are old and the two ships are not. The grapple takes a sealed unit out of one rack and a crate out of another. Both ships are still holding station on the light when you leave.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You find the true bearing under the false one. You work the oldest hull in the field, far enough out that nobody comes to look. One crate comes off it. The reactor ran warm the whole time you were alongside.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The two bearings will not separate. You spend three hours on a dish that keeps agreeing with itself. The frames out past the rock have all been picked over already. The ship is hot from the looking."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You put a strong return across the field. The field is theirs. They have been sitting on that light for eleven days with nothing to show for it. Both ships come out of the rock's shadow with their drives lit.", fight = true}},
				{label = "Burn wide and work the far frames", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "You take the long way in, around the outside of the field. It costs ten units and keeps the rock between you and them. The outermost hull is the oldest, and the only one they have not finished. One crate comes off it. You are gone before either ship trims its attitude.", material = &"wreck"}},
				{label = "Leave the light burning", stay = true, effect = func() -> Dictionary:
					return {text = "You log the false code and the bearing it sits on. You go around wide of both. The light is still running when your dish loses the rock, and neither ship has moved."}},
			],
		},
		{
			id = &"the_hunting_ship",
			title = "The hunting ship",
			body = "A ship rigged for a hunt is coming across the system at you. It has wide holds and a frame on the bow for taking something aboard whole. There is nothing in any of it. The people flying it have been out five months. What they came for has not been where the charts put it since spring. They have said so on the open channel to nobody in particular. They read your mass at a hundred thousand kilometres and turn toward it. The hail is friendly and it asks twice what you are carrying.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Hold station and let them come alongside",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "They come in close and spend twenty minutes reading your plating. What they read is a ship that would cost them theirs. The tone changes after that. They buy the bearing you came in on, at a price nobody argues with. They have five months of pay aboard and nothing out here to spend it on."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "They look you over and decide against whatever they were deciding. They buy the bearing you came in on rather than leave with nothing. It is less than the bearing is worth. You take it anyway."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.add_credits(OptionTable.purse(6))
						return {text = "They hold alongside for most of a day and cannot decide. You hold with them and burn ten units doing it. At the end of it they pay for the bearing, badly. They go on across the system with the frame on the bow still empty."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A hunting ship found the plating thin and put a shot through it.")
						return {text = "They come in closer than alongside and put one through your flank. They wanted to see what the plating does, and it gives. They ask a third time what you are carrying. You are already burning out of the system by then."}},
				{label = "Burn in on their bow first", fight = true, effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "You put the throttle down and close on them. Their ship has wide holds and a frame for cargo. It does not have much else. Five months of nothing has made them slow to answer a change of plan. The reactor takes the whole cost of the run in.", fight = true}},
				{label = "Answer both hails and hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "You say what you are carrying, plainly, and keep your heading. They pace you to the edge of the system. They are working out whether the answer was worth anything. Then they turn back to the search. They are still on the open channel when your dish loses them."}},
			],
		},
		{
			id = &"the_long_crew",
			title = "The long crew",
			body = "A ship hails you. It stopped being a business a long time ago. They have been out here nineteen years. The registry ran out twelve years back, and the manufacturer that built the ship is gone too. The same people have been aboard the whole time. They do not call it a raid. They read you a list of what they need, in order, and they stay armed while they read it. There are forty items on the list. The first one is fuel.",
			tags = [&"fight"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Come at them dark", fight = true,
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						return {text = "You go cold and come in off their blind quarter. The list is still being read out when you come into range. They have been the only armed ship in every talk for nineteen years. That shows in how long they take to answer this one.", fight = true},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get most of the way in cold before the reactor gives you away. That is close enough for what you came to do. They break off the list part way through an item. They light their drives.", fight = true},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You lose the dark halfway across. They watch you come for the rest of it. The list stops part way through the fourth item, and the reactor is hot from holding everything down.", fight = true},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(4), "Came in cold on a crew with nineteen years of practice at it.")
						return {text = "You are lit up before you are halfway across. This has been done to them before, and they know what it looks like from a long way off. They shoot first and finish the list afterwards.", fight = true}},
				{label = "Give them the first item and keep the rest", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 16)
					return {text = "You put sixteen units across. You tell them the other thirty-nine are somebody else's problem. They take the fuel and they take the answer. Then they send one crate back across, off the hulls they have been working since the registry ran out. Nobody aboard sounds surprised.", material = &"wreck"}},
				{label = "Refuse the list", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them no, and they take it the way they have taken it before. They stop reading and they go quiet. They hold their station and you hold your heading. Nothing else goes out on the channel that day."}},
			],
		},
		{
			id = &"six_years_waiting",
			title = "Six years waiting",
			body = "A ship has been holding this crossing for six years. What it is waiting for is a registry. It sends that registry out on a loop, one line, over and over. The number is two digits off yours. The voice under the loop is not angry about anything. She asks you to hold still and let her instruments read your drive. A drive signature is the one thing on a ship that cannot be repainted. She has been almost sure for six years.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Run the reactor off its profile and let her read it",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.heat += 12
						return {text = "You push the reactor outside the envelope it was built for. You hold it there while her instruments work. What comes back matches nothing anybody has a file on. She says sorry, plainly and once. Then she sends you her own file on the ship she is waiting for. It is six years of bearings and dates, in case you ever cross it.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.heat += 16
						return {text = "You hold the reactor off its profile long enough for the reading to come back wrong. The loop stops. She tells you to go on through the crossing. The reactor takes an hour to come back down to where it belongs."},
					partial = func() -> Dictionary:
						Run.heat += 20
						Run.fuel = maxi(0, Run.fuel - 12)
						return {text = "The reading comes back unclear. That is no use to either of you, and she asks for two more days of it. You do not have two days. You burn wide out of the crossing with the loop still running behind you."},
					botched = func() -> Dictionary:
						Run.heat += 18
						return {text = "The profile slips back into its own shape halfway through the reading. What her instruments get is close enough to six years of waiting. Nothing is said after that. The loop stops and the ship comes about.", fight = true}},
				{label = "Tell her where that registry is working now", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(28))
					return {text = "You have seen that number on a hull two rings out. It was working a run it has no business working. You give her the bearing and the date. She pays out of an account that has been filling for six years. The ship lights its drives while the payment is still clearing. The crossing is empty behind it."}},
				{label = "Decline the reading", stay = true, effect = func() -> Dictionary:
					return {text = "You tell her no and hold your heading past the crossing. The loop follows you on the open channel for an hour. It is one line, over and over, and then the range takes it. The ship does not move off its station."}},
			],
		},
		{
			id = &"standing_orders",
			title = "Standing orders",
			body = "A fuel depot sits on the approach with eleven tanks still reading full. In front of it, on station, is the thing left to guard it. It runs itself. It has a firing arc. It sends a challenge every ninety seconds and wants a code back. The code belongs to an authority that stopped issuing anything long ago. Nothing that has come through since has been able to give it. It does not talk and it does not stand down. Nobody is left to tell it to.",
			tags = [&"fight", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Take the tanks from inside its arc",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.fuel += 26
						return {text = "You go in under the arc and stay under it. That means never being where it is pointed, and never stopping. Two hours of that gets you twenty six units off four tanks and out the far side. The challenge is still going out every ninety seconds behind you."},
					clean = func() -> Dictionary:
						Run.fuel += 16
						Run.heat += 12
						return {text = "You get three tanks open before the arc catches up with the line you are flying. You leave the fourth, and sixteen units come across. The ship is hot from two hours of flying that way."},
					partial = func() -> Dictionary:
						Run.fuel += 6
						Run.take_hull_damage(OptionTable.toll(2), "Inside the firing arc of a thing no one can call off.")
						return {text = "You get one tank open and six units across. Then it puts a shot through your flank and you break off the transfer. The challenge goes out again on schedule while you back away."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Crossed the firing arc of a thing left on station with old orders.")
						return {text = "You put your line through the middle of the arc. It does the one thing it was left here to do. You come out of the approach with nothing off the tanks. There is a hole where the transfer line was going to go."}},
				{label = "Put it down and take the depot at leisure", fight = true, effect = func() -> Dictionary:
					Run.heat += 12
					return {text = "You stop trying to fly around a thing that cannot be talked to. You go straight at it, and it answers inside the first second. That is the whole of what it was left here for. The reactor is already hot from the run in.", fight = true}},
				{label = "Leave it its orders", stay = true, effect = func() -> Dictionary:
					return {text = "You log the depot, the arc and the eleven full tanks. You go around all three. The challenge goes out every ninety seconds behind you. It will still be going out after your dish has lost the approach."}},
			],
		},
		{
			id = &"the_back_of_the_line",
			title = "The back of the line",
			body = "Eleven ships hold a line off a fuel point. There are about seven ships' worth left in it. The order is the order they came in, and the log says who came when. The log is the one thing out here that every ship still keeps to. There is a deal about the shortfall. When the point runs dry, the line takes what it needs off whatever sits at the back. Every ship ahead of you has agreed to that, and it has never once been them. You came in a minute ago, and you are eleven.",
			tags = [&"fight"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Take your fuel before your number comes up",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 24
						return {text = "You break the order and reach the point ahead of them. The line spends four minutes deciding whether the deal covers this. It does not. You pull twenty four units and you are past them and burning. The ninth ship is still saying so on the channel."},
					clean = func() -> Dictionary:
						Run.fuel += 14
						Run.heat += 14
						return {text = "You reach the point first and pull fourteen units. The two ships at the front of the line start their drives. You leave with half of what you wanted. The drive is hot from getting out of their way."},
					partial = func() -> Dictionary:
						Run.fuel += 6
						return {text = "You get six units across. Then the line closes on the point with you still on the transfer line. Nobody argues about the log or the order of arrival.", fight = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Cut the line at a deep fuel point and got shot for it.")
						return {text = "You commit late. Four of them are already moving when you reach the point. The first one opens up before you are on the transfer line at all.", fight = true}},
				{label = "Buy the tenth place off the ship ahead of you", cost_credits = 40, effect = func() -> Dictionary:
					Run.add_credits(-40)
					Run.fuel += 12
					return {text = "The ship at ten knows exactly what its place is worth. It names the figure before you have finished asking. You pay and the log is amended. When your number comes up there are twelve units left in the point. The ship that was at ten is at eleven now, and it knew that when it took the money."}},
				{label = "Hold your number and wait", stay = true, effect = func() -> Dictionary:
					return {text = "You sit at the back of the line with your drives cold. The transponder stays on. Four hours later a twelfth ship comes in off the crossing. It logs its arrival and takes the back of the line from you. Nobody on the channel says anything about it."}},
			],
		},
		{
			id = &"seized_clamp",
			title = "The clamp",
			body = "The dock is four clamps wide and one of them has you. Its release motor burned out while you were loading. The woman on the counter says the yard crew comes through on the ninth. That is four days out. She is not sorry and she is not charging you for the days. The clamp holds your collar and a metre of plating around it. Your drives can pull a ship this size off a dead clamp. That works if the collar holds. Nobody can see the collar from where you sit.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			needs_berth = true,
			min_development = MapGen.Development.SETTLEMENT,
			choices = [
				{label = "Pull off the dead clamp",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						return {text = "You bring the drives up slowly and hold them there. The clamp gives before your collar does. The arm shears at its own pin and comes away with you, still shut. The grapple walks it into the hold. The woman on the counter logs the clamp as lost along with its motor.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "It lets go on the third pull, all at once. You are off the dock and drifting before the drives are back down. Nothing is bent. The collar reads the way it read yesterday. The clamp sits open behind you with its motor still dead."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Pulled off a dead clamp and left the collar in its jaws.")
						return {text = "You come off. Some of the plating around the collar stays where it was. It is a small piece and it was holding something. The woman on the counter watches the whole thing from behind the glass. She writes none of it down."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead clamp held on and the collar came out of the hull.")
						return {text = "You go to full against a clamp that will not open, and the collar goes first. It takes plating with it on the way out. The clamp is still shut around what is left of it. You are a kilometre off the dock by then."}},
				{label = "Cut the arm off at its mount", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "Four hours on the cutter with the reactor up the whole time. The mount was built to be replaced and never to be removed. The arm comes off in one piece with your collar still in its jaws. You keep it. The yard has no use for a clamp with a burned motor and a cut mount.", material = &"wreck"}},
				{label = "Wait for the yard crew", stay = true, effect = func() -> Dictionary:
					return {text = "Four days on the dock with the drives cold and the clamp shut. On the ninth the yard crew comes through with a cart of motors. They swap the dead one out in about twenty minutes and move on down the row. Nobody asks you for anything."}},
			],
		},
		{
			id = &"the_split_loop",
			title = "The split loop",
			body = "Two hours out from the station the reactor runs warmer than the board says. The loop is why. There is a split in the coolant line forward of the pump. It is thin and wet and getting longer while you watch. Two hours back is two hours you would rather not fly twice. A supply tender works this lane. It sells to ships that find things out late. The woman running it has a rack of loop sections aboard. Her price does not move.",
			tags = [&"hazard"],
			group = &"",
			weight = 11,
			min_danger = 1,
			max_danger = 2,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Sleeve the split with the pump running",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 8
						return {text = "The sleeve seats on the first try and the loop holds at pressure. The reactor is back where it should be inside the hour. You fly on. You do not fly two hours back and two hours out again. The tank keeps what that second trip would have cost."},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "The sleeve seats on the third try. The loop runs low the whole time and the heat goes nowhere. It holds. You go on warm and you stay warm for the rest of the day. The number on the board does not climb any further."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The sleeve will not seat while the pump is running. You run the loop at half pressure instead. You go on with the reactor hotter than it has been all week. The split stays where it is for the whole afternoon."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(3), "A coolant line opened at the pump with the reactor still hot.")
						return {text = "The line lets go at the pump while you have it open. What was in it goes out through the mount. It takes the plating behind it. You shut the loop down and the reactor with it. The rest of the day goes on cooling."}},
				{label = "Buy a section off the tender", cost_credits = 30, effect = func() -> Dictionary:
					Run.add_credits(-30)
					return {text = "She asks what she asks and she gets it. Nobody else out here sells loop sections to a ship that needs one today. It comes as a whole unit with the pump end included, racked and ready to go in. She watches it aboard. Then she goes looking for the next ship running warm.", module = true}},
				{label = "Turn back and patch it cold", stay = true, effect = func() -> Dictionary:
					return {text = "You fly the two hours back and sit at the station. The reactor goes down and the loop drains. You put a proper sleeve on a line that is not moving. It takes the afternoon and most of the evening. The loop reads clean when you light the reactor again."}},
			],
		},
		{
			id = &"the_scatter",
			title = "The scatter",
			body = "Two ships touched in the approach lanes six days ago. The pieces are still coming through. A traffic office on the station calls the crossings. It calls one every twenty minutes on the open channel. It gives the bearing, the spread, and how wide the gap is. Most of the scatter is too small for the hull to notice. Some of it is plate a metre across and turning. The dish loses a piece like that against the station's own returns. The gap the office is calling now is eleven minutes wide.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 10,
			min_danger = 1,
			max_danger = 2,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Read the spread and cross",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						return {text = "You hold off and put the dish on the spread for a full pass. By the time you move you know where every piece of it will be. You take the gap with time to spare. The grapple takes a plate on the way through. It comes aboard turning and is still by the time you are clear.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You cross on the office's numbers and nothing comes near you. Two pieces go past behind you, both small, both counted. The office is calling the next gap while you are still clearing the lane."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "You are into the gap before the dish finds a piece the office never counted. You spend the rest of the crossing burning to stay behind it. You come out where you meant to. The tank is eight units down and the grapple is empty."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A plate a metre across, turning, six days out of a wreck.")
						return {text = "You cross on a gap the office called twenty minutes ago. The piece that finds you turns slowly enough to watch it come in. There is not enough of the gap left to be anywhere else. It goes into the forward plating and stays there."}},
				{label = "Work the near edge of the spread", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 6)
					return {text = "You put yourself well off the lane, on the near edge. The pieces there are thin and slow. You burn to stay in place while the office works through two more crossings. The grapple gets one piece of somebody's hull plating. It is big enough to be worth the burn.", material = &"wreck"}},
				{label = "Wait for the office to call it clear", stay = true, effect = func() -> Dictionary:
					return {text = "The office says two more days before the lane is worth calling clear. You spend them out of everybody's way with the drives cold. On the second afternoon a tug starts working the lane from the station end. It picks pieces up and stacks them on a line."}},
			],
		},
		{
			id = &"the_parted_line",
			title = "The parted line",
			body = "A cargo lighter is moored to the loading mast outside the station. Its load has moved. Forty tonnes of something has come off its tethers and gone to one end of the hold. The lighter hangs nose down. One mooring line has parted and drifts beside it. The woman flying it asks on the open channel for a ship with a grapple. She wants the low end held for twenty minutes while she runs a new line. The mast is older than she is and the load is still settling.",
			tags = [&"hazard", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 1,
			max_danger = 2,
			needs_berth = true,
			min_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Take the strain on the grapple",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You get the grapple on the low end and hold it there. Your frame carries forty tonnes of somebody else's cargo for twenty minutes. Nothing on the board complains. She runs the new line, then a second one. Then she tethers the load again with the mast crew watching. She pays you what she would have paid a tug."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "You hold the low end for twenty minutes and the frame complains twice. She gets one line on, and that is enough to stop the swing. She pays you out of what she keeps aboard. It is less than a tug would have charged."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						return {text = "The load moves again while you have the strain on. The lighter comes around on the grapple. You let it go before it takes you with it. She gets a line on an hour later on her own, with the load where it ended up. She pays you for the hour you spent on it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Forty tonnes of cargo on the end of a grapple line.")
						return {text = "The load goes all the way to the low end while you have the strain on. The lighter takes the grapple line with it. The line comes back across your flank before the winch lets go. It takes plating on the way past."}},
				{label = "Push the low end up on thrust", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You put your nose under the low end and hold it up on a long steady burn. It costs fuel. It gives her a lighter that is not swinging. She gets both lines on in the time it takes. She has nothing aboard to pay you with. She signs over a case off the load and the mast crew logs it as damaged in transit.", material = &"event"}},
				{label = "Call it in for her", stay = true, effect = func() -> Dictionary:
					return {text = "You put it on the open channel to the station. You give them the mast, the parted line, and the way the lighter hangs. The traffic office says a tug is an hour out and already tasked. She is still talking to them when you lose the channel."}},
			],
		},
		{
			id = &"the_cooling_loop",
			title = "The cooling loop",
			body = "A mining ship forty kilometres off has lost its cooling loop. The reactor is shut down and the crew are calm about it. A reactor that has just gone down still puts out heat. That heat has to go somewhere and theirs has nowhere to go. The pilot puts the numbers on the open channel. There are two coolant lines and one of them is split. The split sits behind the shielding, where none of their own instruments reach. They have about four hours to cut the right one. Your dish reads a hull from outside.",
			tags = [&"hazard", &"contract"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Put the dish on their hull",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You read their hull from the drives forward, warm against cold. The split shows as a cold patch two metres long aft of the shielding. You give them the frame number. They cut that line and the loop comes back on the half that is left. The temperature stops climbing while you are still watching. The pilot pays out of the ship's account and stays on the channel, talking about nothing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(24))
						return {text = "The hull reads cold in two places. You cannot say which one is the split and which is the shadow of a tank. They cut both lines and run the loop on what is left. That holds the temperature flat and does not bring it down. It will be somebody's problem at the next dock. They pay you for the half of the work you did."},
					partial = func() -> Dictionary:
						Run.fuel += 10
						return {text = "Your dish will not separate the two lines at this range. You will not guess for them. You give them the bearing of the warmest plating. They cut on that, and it is the right line. Nobody aboard will ever be sure whose call it was. They have nothing in the account worth sending. They pump ten units of fuel across instead."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Sat alongside a mining ship while its reactor cooked.")
						return {text = "You call the aft line and they cut it. The aft line was the good one. What is left of the loop goes down inside four minutes. The crew get clear in a boat. The ship opens in one place and stays whole everywhere else. You are close enough that a sheet of it reaches you before you turn away."}},
				{label = "Take their cargo off while they work", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 9)
					return {text = "They would rather it went with somebody than went down with the ship. They say so plainly and ask nothing for it. Their hull is holding its attitude badly. Matching it costs you an hour of small corrections and the fuel to make them. One load comes across on the grapple: their stores, their spare seals, a crate of instrument film nobody has opened. The loop is still down when you pull away.", material = &"event"}},
				{label = "Pass the hail inward", stay = true, effect = func() -> Dictionary:
					return {text = "You put their position and their numbers on the relay. The priority you give it is one nobody this far out honours. You fly on. Behind you, two lines run to a reactor and one of them is split. The people aboard have four hours to pick. Nothing comes back on the channel while you are still in range."}},
			],
		},
		{
			id = &"the_front",
			title = "The front",
			body = "Something let go an hour ago, a long way off your track. The dish has been reading what came out of it ever since. Gas, grit and plate, in a shell, spreading out. The leading edge reaches you in about twenty minutes. The shell is wide. Clean sky is two days of burning to either side. The edge will be thin by the time it gets that far. It is not thin here. Nothing is transmitting from where it started, and the chart has nothing there to transmit.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Turn the heavy side to it and hold",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						return {text = "You put the keel and the tanks between the front and everything soft. It arrives as four minutes of gravel on the plating and one long push. When it is past, the ship is where it was. The sky behind it is full of what the shell was carrying. All of it goes the same way at the same speed. The grapple takes plate off the near stuff. Then it takes a module, still racked in its frame and coasting with the rest.", material = &"wreck", module = true},
					clean = func() -> Dictionary:
						return {text = "The heavy side takes it. The plating rings for four minutes and then stops. Nothing is bent that was not bent before. You spend the hour afterwards picking plate out of the sky behind the front. It all ends up there, moving at the same speed and going the same way.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 9
						return {text = "You are still coming around when the edge arrives. It catches the radiators broadside. Whatever let go was hot and the front is still carrying that heat. The ship holds it now. The grit goes past. You come out the other side with nothing aboard and an hour of shedding to do."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A sheet of hull plate, at the speed of whatever let it go.")
						return {text = "The front arrives while the ship is still beam on to it. Gravel first. Then a sheet of plate the size of a cargo door, end over end. It goes into the flank ahead of the frames. The frames are what stop it."}},
				{label = "Put the nearest rock between you and it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "The rock is eleven minutes away under a hard burn. It is not large and it does not have to be. You sit in its lee while the front goes past on both sides. It rings the far face of the rock for four minutes. There is nothing else to do in that time. The cutter takes a load of ice off the shaded side while you wait.", material = &"mining"}},
				{label = "Turn around and run with it", stay = true, effect = func() -> Dictionary:
					return {text = "You put the drives toward the front and run outward ahead of it. It takes six hours to catch you and it is thin by then. Grit on the plating, a reading on the dish, and nothing else. The sky you meant to cross is behind all of it now. You will come at it from the other side."}},
			],
		},
		{
			id = &"the_ice_stream",
			title = "The ice stream",
			body = "A stream of ice and rock crosses the sky ahead. Its orbit brings it through here once every nine years, and this is the year. The head of it reaches your track in about six hours. The band is wide. Going around it costs two days of fuel. In the middle it is thick enough that the dish stops counting pieces and calls it one. Most of it is water ice with grit frozen through. That is worth carrying and worth burning. The fast pieces run out in front.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Burn across ahead of the head",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.fuel += 14
						return {text = "You are across the track and past it with an hour to spare. That puts you outside the stream with the whole leading edge coming to you at walking pace. You work it for most of a day. Water goes into the tank as fast as the cutter can free it. A load of the grit-bearing ice goes into the hold behind that.", material = &"mining"},
					clean = func() -> Dictionary:
						return {text = "The burn starts late and runs long. You cross with the first pieces already going past, close enough to count. On the far side you take what the stream sheds on its own. One load of ice with rock frozen through it comes out of the thin edge. Nothing there is moving fast.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 12)
						return {text = "You misjudge how far ahead the fast pieces run. You spend the whole burn correcting for them and then correcting again. You come out clean on the far side. The tank will not take you as far as it was going to. Nothing is in the hold to show for the crossing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A rock crossing the other way, at the speed of an orbit.")
						return {text = "The dish counts the big pieces all day. It gives you no trouble with them. A piece the size of a bolt comes out of the head of the stream. It arrives at the sum of two orbital speeds and goes into the bow. The frames behind the bow stop what is left of it. The stream keeps going past for another day and a half."}},
				{label = "Sit off the flank and fish the thin edge", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You hold station off the flank for a day and a half, burning to stay level. You take what comes off the outside of the stream, where the pieces are slow and far apart. One load of ice and grit goes into the hold. Nothing came near the hull all day.", material = &"mining"}},
				{label = "Wait for the whole stream to pass", stay = true, effect = func() -> Dictionary:
					return {text = "A day and a half of sitting still. Nine years of orbit goes by in front of you, piece after piece, none of it in any hurry. When the sky is clear you cross. You are later than you meant to be, with nothing aboard that was not aboard this morning."}},
			],
		},
		{
			id = &"the_venting_hold",
			title = "The venting hold",
			body = "A container ship is holed low on one flank. Its hold is coming out through the hole. The jet is steady and it has been turning the ship for some time. One slow turn every three minutes, containers and all. The dish reads the vapour as fuel grade. Anything hot enough will light it. Your radiators are the hottest thing for a long way in any direction. The tank behind the hole runs dry in about a day. The containers on the high side are sealed and nobody has been at them.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 3,
			max_danger = 4,
			choices = [
				{label = "Match the turn and work the high side",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You go around with it, three minutes a turn, always on the side the jet is not. You stay there two hours. The racks on the high side are open to space. One of them still has a module seated in it, tagged for a hull twice this size. The grapple lifts it out between turns. The ship goes on turning without it.", module = true},
					clean = func() -> Dictionary:
						return {text = "Matching the turn takes longer than the turning does. It eats the time you meant to spend working. One container comes free before the jet swings back around toward you. It is sealed and heavy, the stores a ship this size carries for a year. You take it and get out of the arc.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 8
						return {text = "You come around a half turn behind the whole way and cross the jet twice. Nothing lights. What settles on the radiators does not burn and does not leave. The ship carries that heat out of the arc. The hold is as empty as it went in."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "A jet of fuel vapour, lit off the hot radiators.")
						return {text = "You cross the jet with the radiators facing it and the vapour finds them. It goes up along the whole length of the plume in about a second. The ship is inside that for most of it. The fire takes the radiators and then the plating under them. After that the heat stays aboard with nowhere to go."}},
				{label = "Stand off the arc and cut one container free", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 9)
					return {text = "You work from outside the turn. That means matching a container that comes past once every three minutes. You cut only at the near point. It takes four passes and the fuel to make them. One comes away on the fourth: sealed, full of stores, untouched since the day it was loaded.", material = &"event"}},
				{label = "Give it the day and go", stay = true, effect = func() -> Dictionary:
					return {text = "The tank runs dry sometime in the next day. After that it is a ship with a hole in it, turning at whatever rate the jet left it. You log the drift and the heading for whoever is behind you. The containers on the high side will still be sealed then."}},
			],
		},
		{
			id = &"four_on_one_hull",
			title = "Four on one hull",
			body = "A family hull crosses your track with one drive dark. The other runs rich to cover for it. Four of them aboard, two old enough to fly it, nineteen years on this ring taking one charter at a time. The load was made up for two drives. On one, the burn out of this system costs fuel they did not budget for. It also costs hours their delivery window does not have. The oldest of them lays all of that out on the open channel, and then asks. She wants the excess mass carried as far as the next crossing.",
			tags = [&"contract"],
			group = &"",
			weight = 11,
			max_danger = 4,
			choices = [
				{label = "Take the excess onto your frame",
					check = {attr = &"thrust", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "You take eleven containers onto the outer frame and fly the burn heavy. The family hull makes its window behind you with fuel left over. They pay at the crossing, off a charter account. It has nineteen years of small entries in it. The oldest of them asks how your drive frame took the weight. She waits for the whole answer."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "You take what the frame will hold. They spread the rest across the two holds they can still reach. The burn is slower than either of you wanted. Nobody loses the window. They pay for what you carried, to the container."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 4)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You take four containers. That is all your own load leaves room for. You hold the burn long and slow to keep them alongside. The fuel for that is fuel you meant to keep. They pay the standing fee for the hours and say they are sorry it is not more."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A burn flown heavier than the drive frame was ever rated for.")
						return {text = "You take more than the frame wants and hold the burn anyway. Forty seconds in, a mount on the port side moves and does not move back. The containers go across to the family hull again. You shut the drive down and look at what is left of the mount. They fly the window in two trips. Nobody is paid for anything."}},
				{label = "Buy the excess off them", cost_credits = 22, effect = func() -> Dictionary:
					Run.add_credits(-22)
					return {text = "Cash now against a delivery later is a poor trade. She takes it anyway. That delivery is three crossings off and the fuel is this week. The grapple walks one pallet across. It holds ration crates, filter cloth, and drums with another ship's marks still on them. She logs it as a sale and signs the log in two places.", material = &"event"}},
				{label = "Fly your own burn", stay = true, effect = func() -> Dictionary:
					return {text = "They talk it over on the open channel for another hour. Then they split the load and fly it in two trips. That costs them the window and the fuel for a second crossing. The one doing the arithmetic is the youngest aboard. She does it out loud on a channel anybody could be hearing."}},
			],
		},
		{
			id = &"borrowed_radiators",
			title = "Borrowed radiators",
			body = "Two of them on a short-haul hull with the reactor down. The exchanger that should be shifting its heat is split along a weld. They have been sitting cold for nine hours. The repair is an afternoon of work. They cannot start it until the loop stops holding what it is holding. Their own panels went with the exchanger. They want a coupling walked across on the grapple. Then their loop runs through your radiators until the number comes down. They will pay the hours at what a rim yard charges.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Run their loop through your panels",
					check = {attr = &"thermal", need = 5},
					met = func() -> Dictionary:
						Run.heat += 6
						Run.add_credits(OptionTable.purse(26))
						return {text = "Their loop goes through your panels. Your panels give most of it back to the sky as fast as it arrives. You run warm for four hours and never close to anything that matters. They have the weld in and their reactor lit before you have uncoupled. They pay the yard rate off a card. One of them keeps it for the things they do not plan."},
					clean = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(18))
						return {text = "The coupling holds and the transfer works. It is slower than either set of instruments said it would be. You spend five hours warm and an hour of that warmer than you like. Your own reactor is eased back to give the panels room. They light theirs at the end of it and pay what they said."},
					partial = func() -> Dictionary:
						Run.heat += 14
						Run.add_credits(OptionTable.purse(6))
						return {text = "You take about half of what they needed shifted. Then your own panels are as far behind as theirs were. They finish the weld with the loop still hot, slower than they meant to. They pay for the half you took. You carry the heat of it in your own plating all afternoon."},
					botched = func() -> Dictionary:
						Run.heat += 18
						Run.take_hull_damage(OptionTable.toll(3), "A coupling gave way with their coolant loop at full pressure.")
						return {text = "The coupling seats badly and you find that out with their loop at pressure. What comes out goes across the mount and takes the plating behind it. Now you shed their heat and your own through a panel that is short a section. They cut it from their side and say nothing for a while. Then they say sorry."}},
				{label = "Take two hours of it and uncouple", effect = func() -> Dictionary:
					Run.heat += 8
					Run.add_credits(OptionTable.purse(14))
					return {text = "Two hours is what you agree to and two hours is what they get. It takes their loop down far enough to work in and no further. You go on warm. They pay the two hours before the coupling is stowed. Then they go back to a repair that will take the rest of the day."}},
				{label = "Stay cold", stay = true, effect = func() -> Dictionary:
					return {text = "They take the answer and do not argue about it. They go back to the open channel. Somebody will come through this system in a day or two with empty panels. The reactor stays down until then. The two of them sit in a hull going as cold as the sky around it."}},
			],
		},
		{
			id = &"the_spare_module",
			title = "The spare module",
			body = "Three of them working off an old tender. They have one thing left to sell. It is a power module out of a hull they took apart four systems back. The manufacturer's plate has come off the casing with a grinder. The serial under it went the same way. They are selling it here, in open space, because the yard they are headed for keeps a register. That yard asks about parts with no numbers on them. They want cash and they want it today. The price is low and they say so.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Read it under load before you pay",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						Run.add_credits(-16)
						return {text = "The dish reads it cold and then reads it under load. Coil temperatures, the housing, a repair on the third bus. That repair was done in a hurry by somebody who knew the work. The module is sound. The repair is worth arguing about, and you argue about it. The grapple walks it across for less than they opened at. It goes straight into the rack.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(-24)
						return {text = "Nothing on the instruments says the module is other than what they claim. Nothing says where it came from either. You pay close to the asking price and take it aboard. It reads clean on your own bus an hour later. It is still reading clean at the end of the day.", module = true},
					partial = func() -> Dictionary:
						return {text = "The readings will not settle. Under load the third bus wanders. That could be the module or it could be the tender's own supply. There is no telling the two apart from where you sit. You tell them so. They keep the module and go back to waiting for a ship that will not look."},
					botched = func() -> Dictionary:
						Run.add_credits(-24)
						Run.take_hull_damage(OptionTable.toll(3), "A power module bought in open space with its numbers ground off.")
						return {text = "Your readings say sound, so you pay for sound. The module comes aboard, goes in the rack and comes up once. What is wrong with it sits on the far side of the housing. The dish was never going to see it there. It takes a section of bus and the plating behind that on its way out. The tender is four hours gone by then."}},
				{label = "Pay what they are asking", cost_credits = 28, effect = func() -> Dictionary:
					Run.add_credits(-28)
					return {text = "They want it off the tender before the yard. You want a spare power module. Neither of you asks the other a single question. The grapple has it across inside the hour. One of them stays on the channel until you confirm it is racked. Then they wish you a quiet crossing and go back to sorting the rest of the hull into piles.", module = true}},
				{label = "Cross without it", stay = true, effect = func() -> Dictionary:
					return {text = "They put the price down twice on the open channel while you are still in range. Then they stop. Ships come through here every few days. The module sits on the tender until somebody arrives who does not ask about the plate."}},
			],
		},
		{
			id = &"one_number_between_two",
			title = "One number between two",
			body = "A short-haul hauler matches your course and asks for something odd. Its transponder came back from a yard reflashed to the wrong hull number. It is four digits off its own. Every patrol on this ring has stopped it since. Papers, mass check, half a day standing still while somebody inward is queried. The yard that can fix it is two crossings on. The woman flying it wants to make those crossings tucked under your flank. She wants a patrol dish to read one contact. She is offering the fee she loses to one more stop.",
			tags = [&"contract", &"signal"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Fly the crossings with her under your flank",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "She holds under the flank for eleven hours. She never drifts out of the shadow your hull puts on the traffic dish. One patrol queries you on the way through and logs one ship. At the yard she pays the whole fee. Then she stays on the channel a while. She tells you where the reflash was done and which of the two people there did it."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "It works for most of the crossing. Twice she falls far enough back to read as her own contact. Both times nobody is looking. You fly the rest of it slow to keep her close and get in late. She pays what she said she would pay."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 4)
						Run.add_credits(OptionTable.purse(5))
						return {text = "Holding a line that tight is attitude work the whole way. You spend the crossing burning small corrections you do not get back. She is stopped anyway, an hour out from the yard. The patrol reads two contacts and wants to know about the older one. She pays you what she has left after the stop."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Two hulls flying closer than either pilot could hold them.")
						return {text = "Eight hours in she comes up under the flank on a correction you were already making. The touch is slow. It still takes a run of plating off the underside. It puts her attitude jets out on that side. She finishes the crossing a kilometre off and pays nobody anything. The yard gets two jobs now."}},
				{label = "Sit out the patrol window with her", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 5)
					Run.add_credits(OptionTable.purse(12))
					return {text = "The patrol working this ring keeps to a schedule. You can both read it off the traffic channel. You hold at the edge of the system with her and wait for the patrol to pass inward. That costs most of a day and the fuel to hold position. She crosses behind you unstopped. She pays before either of you has lit a drive."}},
				{label = "Send her the times and go", stay = true, effect = func() -> Dictionary:
					return {text = "You send her the last three times you saw a patrol on this ring. You send nothing else and fly your own crossing. She is still at the edge of the system when you lose her off the dish. She is doing the arithmetic on a schedule with three entries in it."}},
			],
		},
		{
			id = &"the_automatic_dock",
			title = "The automatic dock",
			body = "A docking arm sticks out of a rock off the lane. It still keeps its schedule. Every two hours it swings out, holds open twenty minutes, and folds back on the stone. A ship name is painted along the spine, with a rota of four dates a month. The cold has gone through the paint. No ship has come to the arm in a long while. A parts locker is welded to the frame under it. Somebody put it there so their own ships would never wait on a station. The arm takes any hull.",
			tags = [&"salvage"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Fly the approach it wants",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You fly the rota line at the speed the arm wants. It takes you like it was expecting you. The clamps hold you square for the whole twenty minutes. The locker opens on the same cycle. Behind it is a module still in its shipping frame. The cutter goes through the frame, and it is good plate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "The arm takes you on the second try. It holds you steady. Twenty minutes is enough to open the locker and take the module out. It is not enough to cut up the frame it came in.", module = true},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 5)
						return {text = "You miss the window twice. The arm folds back both times with nothing in it. Holding for the next cycle costs more burn than the cycle is worth. You break off before the third one opens."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A dock arm folded on its schedule with the ship still in it.")
						return {text = "You are square in the arm when the twenty minutes run out. It folds on the hour it was built to fold. It closes on your flank and does not notice the difference."}},
				{label = "Cut the parts locker off the frame", effect = func() -> Dictionary:
					Run.heat += 6
					return {text = "The cutter runs hot for half an hour. The bolts were put in to stay. What comes away is a locker of spares kept for four ships that stopped coming. Seals, cable, cells, and a box of parts for a drive nobody makes now. Every drawer is sorted and labelled.", material = &"event"}},
				{label = "Let it keep its schedule", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off and watch one cycle from a distance. The arm swings out and waits its twenty minutes on an empty approach. Then it folds back. The rota says it will do it again in two hours."}},
			],
		},
		{
			id = &"the_dust_counter",
			title = "The dust counter",
			body = "An instrument hangs on a frame out here, counting what goes past. It has one aperture, a stack of cells, and a log. The log writes a number every hour whether anybody reads it or not. A mining outfit put it here to learn if the drift was worth working. The outfit is gone and the answer is still not in. It has been writing since before your ship was fitted. Two cells are left in the stack. The log is nearly full. When it fills it starts over and writes on top of the old numbers.",
			tags = [&"signal"],
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Copy the log before it wraps",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "The dish reads it off in an hour and forty minutes, first entry to last. The first entry is older than the outfit that ordered it. Eleven numbers an hour for four years. Then one an hour ever since. The cells have been going flat that whole time. You clip the spares box off the frame: cable, two cells, a lens the aperture never needed.", archive_recover = true, material = &"event"},
					clean = func() -> Dictionary:
						return {text = "The copy comes off clean for the last four years. Then it hits the wrap. The new numbers are written on top of the old ones, and neither one survives. You take the spares box off the frame and leave the instrument counting.", material = &"event"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 5)
						return {text = "The interface wants a key you do not have. The dish gives you the entry it is writing now, over and over. The reactor idles the whole time. Two hours of that, and you have one number out of a record forty years deep."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A survey frame let go at the weld and put a strut through the plating.")
						return {text = "You come in close to read the housing itself. The frame it is bolted to lets go at the weld. It comes apart slowly. That does not help. One strut finds the plating and goes through it."}},
				{label = "Cut the instrument off its frame", effect = func() -> Dictionary:
					Run.heat += 6
					return {text = "Half an hour of cutter on a frame built to stay put. The aperture, the cell stack and the housing come aboard as metal. The log stops somewhere in the second cut. The frame is still out there, bare, pointed at the drift.", material = &"wreck"}},
				{label = "Note the bearing and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and what it is doing. Anybody else who found it did the same. The count goes on. The log wraps in a month or two, and the first forty years go under the new numbers."}},
			],
		},
		{
			id = &"the_welded_plate",
			title = "The welded plate",
			body = "A rock the size of a station turns slowly off your beam. Somebody welded a hull plate to it. The letters are cut into the steel, not painted: eleven registries and one date. Under the plate is the ship those registries flew, bolted flat so the spin cannot take it. Your dish reads nothing running aboard it. Other ships have been here and taken what a grapple could lift. The tanks are still on it, and they are still full.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Work in close against the spin",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "You sit in against the spin for two hours. The face throws what it throws. The frame is good steel under the bolts. It comes up in lengths once the first row is off. By the end your plating is scoured bright along one side.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 4)
						return {text = "You take one pass at it. Most of a row of frame comes aboard. The rock turns under you the whole time. Holding the nose steady costs more burn than you meant to spend.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						return {text = "An hour of station keeping against a rock that will not hold still. Most of the hour goes on the nose and not the cutter. Somebody put those bolts in with a cutter and no reason to hurry. They are still in."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A rock the size of a station turned. Everything loose on the face came at the speed of the turn.")
						return {text = "You come in under the plate on the wrong side of the spin. What comes off the face is small, and there is a lot of it. It arrives at the speed the rock is turning."}},
				{label = "Pump what is left in the tanks", effect = func() -> Dictionary:
					Run.heat += 5
					Run.fuel += 10
					return {text = "The valves are a standard fitting and they have not frozen shut. The rest of the ship did not manage that. It takes three hours to move the fuel across. The pump runs hot the whole time, with your own lights on the plate. The tanks read empty when you uncouple."}},
				{label = "Log the eleven registries", stay = true, effect = func() -> Dictionary:
					return {text = "You put the dish on the plate and read off all eleven numbers. The date under them goes in the log too. The rock turns the plate out of sight. It brings it back around."}},
			],
		},
		{
			id = &"the_core_drill",
			title = "The core drill",
			body = "A survey rig is anchored to a rock out here. It is still drilling. It has put a line of holes across the face, a few metres apart. It is working on the next one. The cores it cut are stacked in a rack beside it. They are labelled in a code. The code meant something to whoever ordered the survey. A transponder on the mast repeats a claim notice every ninety seconds. The rock is taken, the survey is under way, results pending. The date in the notice is nineteen years old.",
			tags = [&"signal", &"salvage"],
			group = &"",
			weight = 8,
			max_danger = 4,
			choices = [
				{label = "Cut into the face the drill opened",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						return {text = "The holes go deep enough to show what the rig has been paying for. The drill found a seam and never finished it. The cutter works that face for two hours and the grapple brings it in loose. The rig starts the next hole while you are still working. The notice goes out on schedule.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You take the face slowly. The cutter is hotter than you want by the end. What comes aboard is ore in pieces. The vents have an hour of work before you burn out.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.heat += 8
						return {text = "The rock is harder than nineteen years of drilling made it look. It beats the cutter for an hour before you stop. You come away with a hot ship and one more mark on the face."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A rock face came apart on the hull where the drill had been.")
						return {text = "The face parts along a line the drill made. The rock behind it was holding the rest in place. A slab comes out at you slowly. It does not stop when it reaches the hull."}},
				{label = "Take the power rack off the mast", effect = func() -> Dictionary:
					Run.take_hull_damage(OptionTable.toll(2), "The power rack was half cut out. The survey mast came down on the plating.")
					return {text = "The rack is bolted through the mast. The mast was never built to come apart next to anything. You get the rack out in forty minutes. You wear the top of the mast on your way clear. The drill carries on into the hole it was in. The notice does not go out again.", module = true}},
				{label = "Let the claim stand", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and the code on the rack of cores. You log the date in the notice too. The drill starts the next hole while you are still in range. The notice goes out again at ninety seconds."}},
			],
		},
		{
			id = &"quoted_blind",
			title = "Quoted blind",
			body = "A repair crew has a freighter's flank open at a yard on the approach. The price was agreed on the channel before anybody put a light on it. The crack runs a long way past what the quote covers. They cannot go back to the owner for more. They cannot close the plate as it is. So they hail passing ships for a cutter and an hour of somebody else's radiators. The foreman is honest about the money. There is not much of it left. He says so before he says what he wants.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Take the long seam",
					check = {attr = &"thermal", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You run the cutter for a shift and a half with the panels wide. You never let the head get ahead of you. The seam comes out clean the whole way. The crew has the plate back on before their window closes. The foreman pays the rest of the quote. He adds most of what was going to be the crew's margin."},
					clean = func() -> Dictionary:
						Run.heat += 6
						Run.add_credits(OptionTable.purse(14))
						return {text = "You take the seam in one long pass. The radiators saturate toward the end of it. The crew finishes the corners themselves. He pays for the pass at the rate the quote allows. It is the only rate he has."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "Two hours in, the panels are full. The head runs hotter than the plate it is cutting. You stow the cutter and stand off. The crew goes back to doing it their own way, which is slower. Nobody is sore about it. The freighter is still open when you leave."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Cut a long seam on another freighter with the vents full.")
						Run.heat += 10
						return {text = "The head is deep in the seam when the frame under it moves. The freighter's plating comes across your bow. The whole weight of the flank is behind it. The crew gets their people clear. You back off with the cutter still out and a new line in your plating. The seam is longer now than it was."}},
				{label = "Hold the plate flush while they weld", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "Ten units of attitude work over a shift. You hold the plate flush while the crew runs the weld from the inside. It is dull flying and the grapple does most of it. The foreman cannot pay you what the hours are worth. He loads a crate of yard stock into your bay instead: cells, sealant, two spools of line. He counts it out loud, item by item.", material = &"event"}},
				{label = "Leave them the seam", stay = true, effect = func() -> Dictionary:
					return {text = "They keep hailing for a while after you are past. The plate stays open. The yard has other work in front of it. The price on the channel does not change."}},
			],
		},
		{
			id = &"the_even_split",
			title = "The even split",
			body = "A dead ore hauler tumbles slowly out past the loading point. A second salvage ship came up on it inside the same hour you did. Their cutter is bigger than yours. Their pilot puts a line down the hull on the open channel. Bow to them, stern to you. Both crews work their own side and stay off the other. The stern holds the racks. She knows that, and she offered it anyway. The bow is four hours of easy plate. The stern is four hours of matching a tumble.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Work the stern while the tumble is with you",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You take the roll and hold it. For four hours the stern is as still as a dock. A whole rack comes off the mount with its cabling still on it. Behind the rack is a crate of drive spares nobody ever opened. The other crew works the bow the whole time. Neither of you crosses the line.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You match it well enough for the work. You lose the roll twice and find it again. The grapple never does anything it cannot undo. One rack comes off clean. The stern is still rolling when you stow the cutter.", module = true},
					partial = func() -> Dictionary:
						return {text = "The tumble is faster than the dish read it. The racks stay bolted where they are. You settle for what the cutter shakes loose: plate, a length of conduit, and a locker that opened itself.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Matched the roll of an ore hauler one beat late. Its stern came the other way.")
						return {text = "You come in on the roll a beat late. The stern goes one way and you go the other. You meet where the mount is thickest. Your own plating wears most of it. The other crew stops long enough to ask if you want a line. Then they go back to the bow."}},
				{label = "Take the bow and work fast", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "Four hours of easy plate off a half that is not fighting you. Ten units go on holding position against the roll while you cut. It is the side nobody wanted, and it is still a bay of good plate. The other crew is on the stern before your second pass is done. They are still there when you go.", material = &"wreck"}},
				{label = "Let them have the hull", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and go. Their cutter is bigger and their crew is rested. The hauler will be just as dead in four hours. They will still be cutting it then."}},
			],
		},
		{
			id = &"receipted_twice",
			title = "Receipted twice",
			body = "A shipping agent is on the approach channel. She is asking every hull with a dish for a mass reading. A shipment of drive parts was receipted at two stations eight days apart. The ship carrying it called at one of them. Either somebody upstream was paid twice for eleven crates. Or they were paid once for twenty-two crates that were never built. She has the whole filing and nothing to read mass with. She will pay for a reading. She will pay more for a reading with a registry on it that is not hers.",
			tags = [&"contract", &"signal"],
			group = &"",
			weight = 9,
			min_danger = 3, max_danger = 6,
			choices = [
				{label = "Put the dish on the consignment",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "Eleven crates. The mass sits within a point of what eleven crates of drive parts should read. The second receipt was written against a load that was never on any ship. The station that wrote it is four crossings behind you and does not know yet. She pays the reading fee and the correction fee together. She copies the filing across to you as well. She wants it stored somewhere that is not her own drive.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(12))
						return {text = "The mass reads high by enough to matter. It reads low by enough to argue about. You log what the dish says and sign that figure. She takes it away to whoever has to decide what it means. She pays the reading fee without a word."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(4))
						return {text = "The shipment is stacked behind two other loads. Your dish spends an hour reading their plating instead. You give her the figure and flag it as unsure. That makes it useless to her. She pays the standing fee for answering the hail and goes back to asking."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "Your figure is off by a whole crate. The file goes inward with your registry on the reading. Nobody is angry about it. The station at the far end holds the shipment eleven more days. A third instrument settles the argument. The cost of those eleven days goes against your reading."}},
				{label = "Sit with her and copy the filing across", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "Most of a shift with the reactor idling. The dish points at her ship instead of the shipment. Eight days of receipts and two stamps from two stations. There is a transfer note with the wrong registry typed in twice. You take a copy of all of it. She talks the whole time, and about half of it is about the paperwork.", archive_recover = true}},
				{label = "Stay out of the file", stay = true, effect = func() -> Dictionary:
					return {text = "She is still on the channel when you pass out of range. Somebody else will read it for her one day. They will have a worse instrument and more time."}},
			],
		},
		{
			id = &"walking_the_tank",
			title = "Walking the tank",
			body = "A refinery out past the last dock has a freighter's window in eleven hours. Its tender is dead. The ore tank is loaded and sitting where it was filled. Nothing on the site has the thrust to walk it to the loading point in time. The site foreman has been on the channel most of a shift. He is offering the freight rate he was going to pay the tender. That is all the money he has. He wants any ship with a working drive to take it. If nobody does, he tells the freighter it leaves empty.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Put your bow on the tank and push",
					check = {attr = &"thrust", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You get on it square and hold the push for nine hours. The rate stays inside what the anchor points can take. The tank arrives with two hours of the window left. The freighter takes all of it. The foreman pays the freight rate in full. He puts a bay of ore across as well, off the top of the tank. He has more ore than he has money.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "You get it there with forty minutes to spare. Two of the nine hours went on taking out a drift you put in yourself. The freighter takes the tank. The foreman pays the rate and does not mention the drift. Somebody else on the site has mentioned it twice."},
					partial = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(5))
						return {text = "The tank comes off its anchor harder than you meant. You spend the next six hours taking that back out of it. The drive is up and the vents work behind it the whole way. It arrives after the window. The freighter takes what it can hold in the time it has. The rest stays on the tank. He pays part of a rate for part of a job."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed a loaded ore tank past what its anchor points would hold. A corner of it came around into the plating.")
						return {text = "The push goes in off centre. The tank starts a slow yaw you cannot get in front of. One corner comes around into your plating at walking speed. At that mass, walking speed is enough. The tank stops where it stops. The freighter leaves on time and empty."}},
				{label = "Sell the site your reserve", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "Their last working tug can do it in three trips if it has fuel to burn. Twelve units is three trips. It goes across the line in an hour. The tug is moving before the pump is cold. The foreman pays in ore off the top of the tank. He would rather part with the ore than the money. The tug is out at the anchor before he finishes saying it.", material = &"mining"}},
				{label = "Hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "He is still on the channel two hours later. He is offering the same rate to a different set of ships. The tank sits where it was filled. The window closes whether anybody answers him or not."}},
			],
		},
		{
			id = &"the_cracked_frame",
			title = "The cracked frame",
			body = "A hauler is up on a yard's clamps with a crack across two frame members. The quote for the work is more than the woman flying it has. She has had the ship eleven years. She is selling fittings off it to close the gap. A spare pump, a rack of cells, and an instrument head she bought new four years ago. The yard offered for all three at the price a yard offers. So she is on the open channel instead. She is telling everybody on the approach what she has and what she wants for it.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Hold the frame in tension while they weld",
					check = {attr = &"hull", need = 5},
					met = func() -> Dictionary:
						return {text = "The grapple takes the hauler's weight across both members. Your own frame takes it after that, for eleven hours, while the yard runs the weld in passes. Nothing moves more than the yard allows for. She gives you the instrument head. She has not stopped looking at it since she agreed to it. The yard adds the two cut sections of old member, which are good plate.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "Eleven hours of holding still. Your own plating reports numbers the board records and does not explain. The weld takes. She gives you the instrument head in a box, with the calibration sheet still in it.", module = true},
					partial = func() -> Dictionary:
						return {text = "You hold it six hours. Then your own frame starts reporting numbers the board flags. You put the load down while putting it down is still your idea. The yard gets one member welded out of two. The job is not finished, so she keeps the instrument head. She gives you the section they cut out of the first member instead.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Held an eleven-year-old hauler in tension on the grapple. Something in your own frame let go first.")
						return {text = "The load comes on uneven and you correct into it instead of out of it. Something in your own structure goes before anything in hers does. The grapple releases itself, the way it is built to. The hauler comes down on the clamps hard. The yard has to look at all of it again."}},
				{label = "Buy the pump at her figure", cost_credits = 35, effect = func() -> Dictionary:
					Run.add_credits(-35)
					return {text = "She names a figure and it is a fair one. She does not move off it while you think. The pump comes across in a crate with its service record taped to the lid. The money is on the yard's account before your grapple has stowed. She watches the transfer clear without saying anything.", module = true}},
				{label = "Leave her the quote", stay = true, effect = func() -> Dictionary:
					return {text = "She is still listing the fittings on the channel when you pass out of range. The yard is in no hurry. The clamps are rented by the day, and the day is already paid for."}},
			],
		},
		{
			id = &"the_flagged_stack",
			title = "The flagged stack",
			body = "A repair outfit on a busy station has a freighter open and no pump for it. The pump they bought is on a rack outside the dock. There is a hold against it. The shipment it arrived in was filed under a registry that closed last year. The office that can lift the hold answers in nine days. The freighter leaves in two. Their foreman reads you the receipt over the channel twice. Then he asks if your ship is the sort that comes off a rack without lighting up the board.",
			tags = [&"contract", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Come off the rack with the transponder cold",
					check = {attr = &"stealth", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You come in on attitude jets with everything but the grapple cold. The crate goes in the bay and you are back on the lane. The dock's board has nothing to log except a ship that changed heading. An hour later the crate goes across to the outfit in the open. The transfer is entirely legal. They pay the whole figure and the freighter leaves on time."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(16))
						return {text = "The board sees something and logs it as traffic. It stays traffic. You come away with the crate. The outfit pays the figure, less what they spent on somebody at the dock who also saw something."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "A tender works the rack all shift, doing perfectly ordinary things. You hold off it and burn fuel. By the time it clears, the freighter's window is too close to be worth the approach. You break off. The outfit stops answering. The crate is still on the rack when you leave."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Pulled a crate off a station rack before the clamp let go.")
						return {text = "The clamp reads the grapple as a dock loader. It does not release on the schedule you were flying to. You take the crate and a length of the rack with it, across your own plating. The board logs every second of it. The outfit gets the pump. Nobody at the dock says a word to you about the rack."}},
				{label = "Sit off the rack and read the dock for them", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 6)
					Run.add_credits(OptionTable.purse(10))
					return {text = "Six units of station keeping, and most of a shift with the dish on the dock's traffic. You log when the rack is worked and when it is not. Their foreman takes the pattern. He sends his own tender in on the third quiet window. They pay for the watch at the rate they pay their own people. It clears before the tender is back."}},
				{label = "Keep clear of the rack", stay = true, effect = func() -> Dictionary:
					return {text = "The freighter leaves in two days, with a pump in it or without one. The outfit puts the same question to the next ship on the approach. The crate sits on the rack. The hold is still against it."}},
			],
		},
		{
			id = &"the_flat_rate",
			title = "The flat rate",
			body = "A tow was agreed at a flat rate on the channel. Nobody weighed the load first. The outfit that took it is two people with a good drive and no margin. The load is a mining tender full of wet ore that nobody drained before it left. They are four days into a six-hour job. The receiving dock will not take the line until the roll comes off the tender. The pilot cannot fly that part, so he is paying somebody else to do it. The rate was thin the day it was written.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 5, max_danger = 6,
			choices = [
				{label = "Match the roll and take it out of the tender",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "You get alongside and match it. Then you spend three hours giving the tender small corrections, in the places where the ore is not. The roll comes down inside what the dock will accept. The dock takes the line on the first try. He pays the figure he agreed. Then he adds most of what the tow has left him. He works it out on the board in front of you."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "Four hours of correcting a load that answers late every time. The roll comes down to something the dock argues about and then accepts. He pays the figure he agreed. There is nothing left in the rate after it."},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "You take most of the roll out and put some of it back in twice. The drive works the whole time and the vents work behind it. The dock refuses the line at that rate of roll. The two of them settle in to wait. It will damp on its own in about a day. Nobody is paying anybody for that day."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a rolling mining tender full of wet ore. The ore moved before you did.")
						return {text = "You go in close on a load whose centre shifts every time it rolls. This time it shifts early. The tender comes across your flank at the top of the roll. It takes plating with it. The roll is worse afterwards than it was before. The pilot says nothing on the channel for a while. Then he asks if you are all right."}},
				{label = "Take the drained ore as the fee", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "Twelve units of station keeping alongside. They pump the wet ore out of the tender and into your bay. Your bay is the only place to put it. The ore is what they are paying with. The roll comes down as the tank empties. Four hours of dull flying, and you come away with a bay of ore.", material = &"mining"}},
				{label = "Let them finish it themselves", stay = true, effect = func() -> Dictionary:
					return {text = "They are still alongside it when your dish loses them. The tender rolls at the rate it has rolled for four days. The dock at the far end is not expecting anybody early."}},
			],
		},
		{
			id = &"the_thrower",
			title = "The thrower",
			body = "A mass driver sits on a rock, throwing ore canisters out. One goes every eleven minutes. It has been firing since before anybody stopped watching it. The bearing ends at a receiving station that stopped answering years ago. The loader still feeds the rail. Your dish can follow the line of canisters as far as it reaches. The sleds they ride out on come off at the muzzle. They drift back toward the rock in a slow cone.",
			tags = [&"salvage"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Catch one off the stream",
					check = {attr = &"maneuver", need = 7},
					met = func() -> Dictionary:
						return {text = "You sit in the line an hour out from the muzzle. The canisters have spread by then, so you can pick one. The grapple takes it at almost no closing speed. It is ore, graded and packed. Its sled comes aboard with it, guidance unit sealed and still drawing off its own cell. The next canister goes past eleven minutes later on the same bearing.", module = true, material = &"mining"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You burn for an hour to get into the right place. You take one cleanly at the end of that. The drive is hot for it. The canister holds ore, graded and packed and twenty years in the cold. The sled goes on outward without it.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "Two go past while you are still lining up. You touch the third and lose it. It carries on outward with a dent in it and your bearing written across its side. You come away with nothing. The drive is hot from three attempts."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "A loaded ore canister, caught too close to a mass driver's muzzle.")
						return {text = "You try a fourth time, close in near the muzzle. The canister there is still under power. It catches the flank and keeps going on its bearing. It does not lose a metre a second. The plating on that side is opened from bow to midships."}},
				{label = "Work the loading rack at the rock", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You hold station beside the rock. It shakes every eleven minutes and you trim against that. The grapple takes one canister off the rack before the loader can get it to the rail. Holding that close costs a day of fuel. The loader reaches past you for the next one and carries on.", material = &"mining"}},
				{label = "Leave it firing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and the gap between shots and go. The next canister goes out eleven minutes after you do. It takes the same line as all the rest. The station at the far end of that line stopped answering years ago."}},
			],
		},
		{
			id = &"the_bonded_load",
			title = "The bonded load",
			body = "A depot ship sits off the approach with one woman aboard. A sealed load waits in its racks. The order was placed nineteen years ago, by a manufacturer that has since stopped existing. Nobody ever came for it, and her orders say hold until they do. She may close an order that nobody can collect. First somebody has to read its seals against a current registry. Her own reader is older than the load. She has been waiting for a ship with a better one. She says so on the first hail.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Read the seals against the registry",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The seals answer a current reader in about a minute. What they say matches the order in every line but one. The collector is not on any registry you can reach. That is enough for her to close the order out. She pays the reading fee from the depot account. She sends over the file that went with it. Inside are the order, the route it was meant to take, and nineteen years of holding notes.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "Your reader gets four seals out of six. Four is what the depot rules ask for. She closes the order on that. She pays the fee at the reduced rate her sheet allows for a partial reading. Then she puts the file back in the drawer it came out of."},
					partial = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(6))
						return {text = "Two seals read and the rest are dead cells. Two is not enough for anything. She pays the standing rate for the attempt, which is small. She pays it without argument and goes back to holding the load."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "Your reader writes to the seals instead of reading them. The depot locks the load for ninety days. Neither of you can reach the rule that did it. You stay on the channel with her for a day and a half. The reactor idles the whole time, and the load stays locked."}},
				{label = "Buy the load at the order's price", cost_credits = 30, effect = func() -> Dictionary:
					Run.add_credits(-30)
					return {text = "The order priced it nineteen years ago. Her sheet has no field for repricing anything. You pay what the order says. She sends one case across on the line. It holds stores and spares, packed by people who expected to see it again inside a month.", material = &"event"}},
				{label = "Let her hold it", stay = true, effect = func() -> Dictionary:
					return {text = "She logs your arrival against the order. The order has a field for ships that came and did not collect. Then she goes back to waiting. The load has been in the racks longer than she has been aboard."}},
			],
		},
		{
			id = &"the_metered_dock",
			title = "The metered dock",
			body = "An ore dock stands lit with nobody on it. The last fuel delivery came after the last crew left, so the tanks are full. The pumps run off the dock's own power, which has not failed yet. The meter has not failed either. It logs hull number, mass and quantity. It bills an office that stopped answering years ago, and it keeps the record anyway. Below a certain draw rate it writes nothing at all. It was built to ignore a leak.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Draw under the meter",
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 22
						return {text = "You bring the line up slowly. You hold it just under the rate the meter cares about. You sit there most of a day. Twenty-two units come across, and the log shows a dock that used no fuel today. The lights stay on the whole time."},
					clean = func() -> Dictionary:
						Run.fuel += 14
						return {text = "You hold the rate down for six hours. You lose patience in the seventh. The meter starts writing in the eighth. Fourteen units reach the tank, and a line goes into a ledger nobody reads, against a hull number that is yours."},
					partial = func() -> Dictionary:
						Run.heat += 12
						Run.fuel += 6
						return {text = "The pumps stall against a rate that low, and they keep stalling. You spend more of the day restarting them than drawing from them. Six units reach the tank. The ship is warm from nine hours of its own systems, with the drive cold."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A dock's fuel line, frozen for years, opened too fast.")
						return {text = "You push the rate up to where the meter would see it. The line lets go at the boom. What is in it comes out under pressure, across your flank. None of it reaches your tank. The pumps keep running for an hour with nothing to push."}},
				{label = "Settle the sheet and pump", cost_credits = 34, effect = func() -> Dictionary:
					Run.add_credits(-34)
					Run.fuel += 18
					return {text = "The meter takes a settlement from anybody who offers one. The rate was printed the year the dock opened. You pay it and the pumps run at full. Eighteen units come across in under an hour. The receipt prints and drops into a tray that already holds a stack of them."}},
				{label = "Leave the tanks alone", stay = true, effect = func() -> Dictionary:
					return {text = "You go past with your tank as it is. The dock keeps its lights on and its meter running. Nothing on it moves while you are in range."}},
			],
		},
		{
			id = &"the_service_cradle",
			title = "The service cradle",
			body = "A service cradle hangs off a dead yard. Its arms open and close on nothing, on a cycle it has kept for years. It is built for freighters. Whatever it clamps, it services. It pulls the worn units off and puts up whatever is still on its racks. It never asks the ship anything first. The racks are not empty. The arms close at the pressure a freighter is framed for. Nothing that size has come through here in years.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Put the ship in the arms",
					check = {attr = &"hull", need = 7},
					met = func() -> Dictionary:
						return {text = "The arms take you across the middle and hold. The plating carries the pressure the way plating should. The cradle works on you for two hours. It lifts a sealed unit off its rack and leaves it in your grapple. The worn part it pulled goes in there too, because the cradle has nowhere else to put it. Then it opens and goes back to its cycle.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "The arms close harder than you would choose. They hold you there for the whole cycle. You come out with one unit off the racks, which the cradle decided you were short of. The ship is hot from two hours of somebody else's power running through it.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "It clamps and reads whatever it reads off your flank. Nothing on its racks answers that. Two hours in the arms and no work done. The drive is warm from holding attitude against the arms. The cradle will not open until the cycle ends."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(4), "Clamped in a cradle built for freighters, at a freighter's pressure.")
						return {text = "The arms shut at the pressure they were set to twenty years ago. Something gives amidships, and it gives slowly, over about four seconds. The cradle ends its cycle and lets you go. Then it shuts on nothing and starts again."}},
				{label = "Work its racks from outside", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "You stay out of the arms and work the racks with the grapple. You trim the whole time to keep clear of the cycle. The arms do not care where you are. A day of fuel goes into holding that station. You come away with one piece off the nearest rack.", material = &"wreck"}},
				{label = "Leave it cycling", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the yard and leave the cradle to its arms. It closes on nothing, and opens, and closes again. The yard behind it is dark on every band."}},
			],
		},
		{
			id = &"the_uncollected_order",
			title = "The uncollected order",
			body = "A beacon on the approach repeats a work order every hour. Collect the load at this bearing. Deliver it to this address. Payment on delivery against this vault code. The bearing is a tether four hours off, with the load still on it. The load is counted and sealed and labelled in a script nobody uses now. The address is a station that is not there. The vault code is not one anybody will honour. The beacon has been asking for years, and its cell is good for years more.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Open the load and read the list",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						return {text = "The list reads clean once you have the cell voltage right. It says what is in every case, and which of them still hold a charge. One does. You take that one off the tether. The order's own file comes with it: the posting, the address, and the name of whoever signed the job out.", module = true, archive_recover = true},
					clean = func() -> Dictionary:
						return {text = "Half the list reads and the other half went with the cells. You open the cases that answer and find one sealed unit still holding. You take it off the tether. The rest stay counted and sealed, where the order says they are.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "Nothing on the load answers a reader any more. The cutter opens one case on the tether to see what is in it. It holds stores, packed dense and dry. You take that case and leave the others as they were.", material = &"event"},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(3), "A sealed case, still under pressure, cut open on the grapple.")
						return {text = "The case you pick is under pressure. It has been since the day it was packed. It opens along the seam the cutter made. What was in it goes through your bow at speed. The rest of the load hangs on the tether, counted and sealed."}},
				{label = "Record the beacon through a full cycle", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "The order repeats hourly, and the long version runs once a day. That one carries the schedule, the routing, and every amendment made to either. You hold station a full day to get the whole of it. Burning to stay put costs you a day of fuel. You take the recording with you.", archive_recover = true}},
				{label = "Leave the order standing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and go on. The beacon puts the order out again on the hour. The strength is the same. The address it names has not been there for a long time."}},
			],
		},
		{
			id = &"the_outbound_five",
			title = "The five going out",
			body = "Five ships that went in are coming out, in a line, slowly. They pooled their fuel two months ago, and it is still not enough. The heavy one is an ore carrier. Its drive will hold a course and will not build speed. The other four cannot spare the burn to push it. The pilot flying the lead hails to ask what a push is worth. She names a figure before you answer. It is most of what the five of them have left between them.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Push the ore carrier up to speed",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You get your bow on the carrier's stern plate. You push for nine hours. It comes up to a speed the other four can hold without extra burn. They pay the figure she named, out of five accounts. They send over their run inward as well. It has every bearing they took, every place they stopped, and the day they turned around.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(20))
						return {text = "Nine hours of pushing brings the carrier most of the way up. It does not reach the speed they wanted. The drive runs hot the whole time. They pay what she named and do not argue the shortfall. The line forms up around the carrier and goes on out."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The carrier will not hold its line under the push. You spend most of the burn correcting for it. You give it up in the sixth hour, down a day of fuel. They pay you for the hours you put in."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed an ore carrier that would not come up to speed. The two hulls went into each other.")
						return {text = "The carrier yaws under the push in the fourth hour. Your bow goes into its quarter instead of its plate. Both hulls open, and theirs is worse. They stop talking to you. They go to work on their own ship, and nobody is paid."}},
				{label = "Take the mass they cannot carry", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "They are dumping mass to get home and would sooner it went to a ship. You pump twelve units into the carrier's tank. Ore comes back the other way, graded and bagged. The rate suits them, because they are not carrying it either way.", material = &"mining"}},
				{label = "Let them work it out", stay = true, effect = func() -> Dictionary:
					return {text = "You give them the bearings you have and go on past. An hour later the five of them are still in a line. They are still slow and still pointed out. The carrier is still setting the speed."}},
			],
		},
		{
			id = &"the_holding_stack",
			title = "The holding stack",
			body = "Containers are clamped to a rock in rows, forty or fifty of them. They were dropped here for a carrier that stopped coming. The oldest labels carry a date twenty-two years old. They also carry a consignor whose name is on nothing else out here. The clamps were shut warm and have sat at three kelvin ever since. They have cold-welded to the rails. Getting one off means running the cutter until a clamp softens. The heat that takes comes back down the grapple.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Cut a clamp warm and take the container",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "You run the cutter in long passes with the radiators wide. The clamp lets go in about an hour. Not much heat comes back into the ship. The container comes across whole. The consignment papers are in a sleeve on the door. They are printed, stamped twice, and readable from the first line to the last.", material = &"event", archive_recover = true},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "The clamp takes two hours. Most of those hours come back as heat down the grapple. You get the container off the rail. Then you sit a while with the drive cold, shedding what the job put into you.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 22
						return {text = "You pick a clamp on the shaded side. It will not soften at any rate the grapple can carry. You stop when the heat has nowhere left to go. The container is still on the rail. The ship is warm all the way through."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Heat off a cold-welded clamp, taken back down the grapple. It went into the drive section.")
						return {text = "You stay on the clamp past what the radiators can keep up with. The clamp gives, and so does something in the drive section. The container comes off the rail and drifts clear. You are in no state to go after it."}},
				{label = "Run the cutter hot and take one anyway", effect = func() -> Dictionary:
					Run.heat += 20
					return {text = "You put the cutter on the nearest clamp and keep it there. You do not pace the job at all. The container is off the rail in forty minutes. The ship carries what that cost for the rest of the day. The radiators stay wide and the drive stays down.", material = &"event"}},
				{label = "Leave the rows as they are", stay = true, effect = func() -> Dictionary:
					return {text = "You read the labels off the near row and go. The rows are still clamped to the rock when the dish loses them. They sit in the order somebody set them down in twenty-two years ago."}},
			],
		},
	])
	return out
