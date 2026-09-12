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
			body = "Two ships sit either side of a drifting cargo pod, running lights on, weapons warm in the unenthusiastic way of crews who would rather be paid than shoot. Both are claiming it on the open channel. The pod is not saying anything, but its transponder log knows whose it is, and your dish is the only disinterested one in range.",
			tags = [&"contract"],
			group = &"",
			weight = 10,
			max_danger = 8,
			choices = [
				{label = "Read the log",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "The log is unambiguous: dropped by the smaller ship two days ago in a bad burn. You transmit the timestamps, the bigger ship peels off without a word, and the owner pays a finder's rate for getting it back without shooting."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "Readable enough. The loser argues, briefly, with somebody who can see the timestamps, and then stops."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The log predates both ships. Neither of them owns it, and now all three of you know it, so it gets split three ways, fast, before anyone else arrives to know it too."},
					botched = func() -> Dictionary:
						Run.add_credits(-20)
						return {text = "You call it for the wrong ship, confidently. The right one leaves with the pod, and your reading fee goes back the way it came."}},
				{label = "Snatch it while they argue", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "You burn in and take the thing both of them are shouting about. They stop shouting at each other.", fight = true, material = &"event"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "Two ships, one pod, and an open channel. It was going to be a long afternoon anyway."}},
			],
		},
		{
			id = &"long_claim",
			title = "The long claim",
			body = "A bare rock with a mineral seam glittering down one face, and no transponder anywhere on it. Nobody works this far out, because hauling ore back costs more than the ore. The rich part of the seam runs under an overhang that has been deciding whether to come down for a very long time. A day of cutting. Nothing here is in a hurry and nothing is coming to help.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Work it", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(38))
					return {text = "Most of a day, one cutting head, and enough off the seam to matter at the next station.", material = &"mining"}},
				{label = "Work it hard",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						return {text = "You take the seam and the shelf under it, and the frame does not complain once.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						Run.take_hull_damage(OptionTable.toll(3), "You take more than the seam. Something in the forward bracing makes a noise it has not made before, then stops.")
						return {text = "You take more than the seam. Something in the forward bracing makes a noise it has not made before, then stops."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						Run.take_hull_damage(OptionTable.toll(5), "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for and you are cutting by hand after that.")
						return {text = "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for and you are cutting by hand after that."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "You are still under the overhang when the overhang decides.")
						return {text = "You are still under the overhang when the overhang decides."}},
				{label = "Move on", stay = true, effect = func() -> Dictionary:
					return {text = "It has been here a long time. It is in no hurry."}},
			],
		},
		{
			id = &"slipping_orbit",
			title = "Slipping orbit",
			body = "A gas giant fills half the viewport, and it has you. Not badly, yet. You came in on a lazy transfer to save fuel and the well took the difference. The gauges give you perhaps four minutes to decide whether your engines are the answer. The dish reads something else riding the same track: a spar of old wreckage, plate and frame both, that the well collected a long time ago. A burn hard enough to climb straight out takes you past it close enough for the grapple. A slower one gets out too and spends the tank doing it. One orbit costs you the hour and nothing else.",
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
						return {text = "You climb out of it like it was nothing, and on the way past you snatch a spar of old wreckage the well had collected.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						return {text = "The engines find it, eventually, and drink fourteen units doing it."},
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
			body = "Old mines glint across the debris belt ahead, dozens of them, still keeping perfect station around the ship they were set to guard. Whoever seeded them stopped answering a long time ago and never came back for any of it. That ship is whole, hull unbreached, holds shut. Another hull lies further in, opened along one flank by something that was not the belt, with a module still racked in the open where the grapple could lift it. The mines are old enough that some will not fire, and old enough that you cannot tell which ones from out here.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Thread it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You go through the field like water through a grate, and lift a module off the wreck of somebody who did not.", module = true},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "One of them finds your flank on the way out. Only one.")
						return {text = "One of them finds your flank on the way out. Only one."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Two, then a third. You reverse the last hundred metres with the hull ringing.")
						return {text = "Two, then a third. You reverse the last hundred metres with the hull ringing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The old ones are the worst. This one waits until you are past before it decides.")
						return {text = "The old ones are the worst. This one waits until you are past before it decides."}},
				{label = "Sweep wide", stay = true, effect = func() -> Dictionary:
					return {text = "You give the whole drift a wide margin and lose nothing but time."}},
			],
		},
		{
			id = &"corona",
			title = "The corona",
			body = "The star here is mid-tantrum. It throws a flare every few hours, the instruments call the next one soon, and sitting close in, inside the glare, is a wreck with its holds intact. Everyone else has read the temperature and left. The wreck's lit side has gone amber where years of that light baked the plating, thick enough to cut a plate off whole, and the holds under it are still racked. The vents carry the heat the whole way in and the whole way out, and the instruments will not say how long the star means to wait.",
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
						return {text = "Your vents hold the whole way in and the whole way out. You come away with a plate of the amber the star has baked onto the wreck's lit side, and a rack out of the hold nobody else would reach.", material_id = &"corona_amber", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You get one rack off the wreck and come out with a reactor that will need a minute.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "You get one hold open and the temperature makes the decision for you before anything comes out of it."},
					botched = func() -> Dictionary:
						Run.heat += 20
						return {text = "The flare comes early. You leave with nothing and a ship that is still ticking as it cools."}},
				{label = "Watch it burn", stay = true, effect = func() -> Dictionary:
					return {text = "You hold station outside the corona and log the wreck for somebody with better vents."}},
			],
		},
		{
			id = &"the_wind",
			title = "The wind",
			body = "The star is shedding itself. A blue hypergiant burns through its own mass fast enough to notice, and what comes off it crosses this lane as a front the dish reads from an hour out: thin gas, very fast, all of it moving outward the way you are already going. Turn the hull side on and it carries the ship while the reactor idles. Meet it on the bow and it takes the bow first and the rest of the ship follows. Crossing it at an angle under power costs fuel and gets you through inside the hour. The front is most of a day wide and it will be past by the end of the afternoon.",
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
						return {text = "You put the hull side-on for ninety seconds and let it take you. The tank does not fill; the distance simply stops costing anything."},
					clean = func() -> Dictionary:
						Run.fuel += 14
						return {text = "You catch the edge of it and hold, and the reactor spends the crossing idling."},
					partial = func() -> Dictionary:
						Run.fuel += 8
						Run.heat += 5
						return {text = "You catch it badly and spend the crossing correcting, which costs you most of what it gave."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "The front takes the bow first and the rest of the ship follows, sideways.")
						return {text = "It takes the bow first and the rest of the ship follows, sideways, for longer than anyone aboard enjoys."}},
				{label = "Burn across it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You cross it at an angle, under power the whole way, and come out the far side having paid for every metre."}},
				{label = "Wait it out", stay = true, effect = func() -> Dictionary:
					return {text = "You hold in the lee of nothing in particular until the front has gone past. It costs you the afternoon and nothing else."}},
			],
		},
		{
			id = &"the_glare",
			title = "The glare",
			body = "Everything on this approach is white. A blue hypergiant puts out more light in an hour than most stars manage in a year, and the dish is reading it as a wall: no returns, no shadows, nothing resolvable across a quarter of the sky. The last clean sweep before it whited out had something in it, ship-sized, holding still.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 5,
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
					return {text = "You put the nearest body between yourself and the star and read the sliver of sky that leaves you. The contact is not in it. Something smaller is, and has been drifting there for a while.", material = &"wreck"}},
				{label = "Log the bearing and go", stay = true, effect = func() -> Dictionary:
					return {text = "You write down a number that will mean nothing to anybody who has not been here, and leave it in the archive for somebody who has."}},
			],
		},
		{
			id = &"the_scouring",
			title = "The scouring",
			body = "A hull has been parked in the wind of a blue hypergiant for a long time. Everything soft is gone: paint, markings, seals, the outer layer of everyone who was aboard. What is left is structure and fittings, polished to bare metal and still bolted down. The star does the same to you at a slower rate the entire time you are alongside.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work it until you have to leave",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "Four hours alongside, and you come away with the racks and most of a reactor housing. Your own plating has a shine on the star-facing side that will not come off.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Three hours alongside a blue hypergiant, which is two hours longer than the plating wanted.")
						return {text = "Three hours, one rack, and a hull that needs looking at.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "You stayed alongside until your own plating started arguing with you.")
						return {text = "You get one thing off it before the readings on your own plating start to argue with you.", module = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You misjudged how long is too long beside a blue hypergiant.")
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
			min_danger = 3,
			max_danger = 8,
			max_security = 2,
			choices = [
				{label = "Take it quietly",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "It goes in a void behind the coolant run that nothing scans and nobody knows about. She watches you do it and does not ask what else is in there.", place = &"paid_in_full"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You find somewhere for it that will hold up to an ordinary look.", place = &"paid_in_full"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You stow it badly and spend the next shell aware of exactly where it is.", place = &"paid_in_full"},
					botched = func() -> Dictionary:
						return {text = "You are still finding somewhere for it when a patrol runs a courtesy sweep of the dock. Nothing comes of it. She sees the sweep and takes it back."}},
				{label = "Ask what it is", stay = true, effect = func() -> Dictionary:
					return {text = "She tells you, or tells you something. The parcel stays in her pocket and she stays at the rank, waiting on an answer."}},
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
			body = "He is old, and he is not what you were expecting, and he has been waiting at this dock for eleven days for a thing that fits in one hand. He does not open it in front of you. He pays what she said he would pay, which is considerably more than she was in a position to promise, and then he asks, carefully, as though the answer matters, whether she looked well.",
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
					return {text = "He pays in full, in cash, and thanks you in a register nobody has used on you in a while."}},
				{label = "Tell him she looked tired", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He nods for a while. Then he pays you more than the agreed figure, and gives you a name at a yard two shells in who will fit you something at cost.", module = true}},
			],
		},
		{
			id = &"ghost_signal",
			title = "Ghost signal",
			body = "The dish is pulling a signal out of the background hiss. It is too regular to be a star and too weak to be a station, and it has not moved in the eleven minutes you have been listening to it. It has not drifted a second of arc either, so whatever is transmitting is bolted to something. The chart shows nothing at that bearing. Resolving it means holding position and giving the dish everything, and a dish given everything will follow your own reactor harmonics out to a bearing and spend the fuel getting there.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Resolve it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "A beacon, precursor-old, still transmitting on a cycle nothing alive uses. You cannot read the message. The housing is precursor work, and it comes off its mount on the grapple.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You pinpoint it, and the housing is fused to its mount by however many centuries it has been out here. You take the readings instead, shot straight off the dish and never developed.", material_id = &"survey_film"},
					partial = func() -> Dictionary:
						return {text = "You chase it for an hour and it resolves into your own reactor harmonics, reflected off something you never find."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 12)
						return {text = "You follow it a long way before admitting it was never there. Twelve units of fuel, spent on a bearing."}},
				{label = "Log it and go", stay = true, effect = func() -> Dictionary:
					return {text = "You write the bearing down. Someone with better ears can have it."}},
			],
		},
		{
			id = &"customs_cordon",
			title = "Customs cordon",
			body = "A revenue cutter holds station over a seized hull, two cold escorts off its flanks. Its crew took the hull nine days ago, the impound paperwork is still grinding through, and until that clears the manifest is public and lists what is still aboard. The cutter lets traffic through. It is there to guard the cargo.",
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
				{label = "Hail them and ask", stay = true, effect = func() -> Dictionary:
					return {text = "You hail the cutter, ask what it is sitting on, and get told. It costs an afternoon and nothing else, and the hold stays sealed."}},
			],
		},
		{
			id = &"the_braid",
			title = "The braid",
			body = "Nine of them cross the dish in a line, big enough to read as terrain: megafauna running a migration lane older than anyone who could have named it, shedding a wake you could ride most of the way to the next ring. They are not hostile. They are also not paying attention, and the smallest is longer than your ship.",
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
						return {text = "You slot into the draught behind the third one and let it carry you. It never registers you were there."},
					clean = func() -> Dictionary:
						Run.fuel += 11
						return {text = "You hold the lane most of the way before the turbulence shrugs you out of it."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "You misjudge the interval and spend the whole run fighting the wash instead of using it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The fourth one changes its mind about the lane. You are close enough that the flank takes your dorsal plating with it.")
						return {text = "The fourth one changes its mind about the lane. You are close enough that the flank takes your dorsal plating with it."}},
				{label = "Take what they shed", effect = func() -> Dictionary:
					return {text = "You hold off the lane and collect what works loose in the wake. Their hides carry decades of accreted junk: plate, ice, and today, a whole rack off some ship that once got too close.", module = true, material_id = &"hide_scrap"}},
				{label = "Let them pass", stay = true, effect = func() -> Dictionary:
					return {text = "Nine of them, in line, going somewhere. You wait, and then they are not there any more."}},
			],
		},
		{
			id = &"refinery_still_lit",
			title = "Refinery, still lit",
			body = "A Cygnet refinery hangs over a dead seam, stacks still glowing. It is running without a crew: cracking ore for nobody, four years since the last shift left, stacking the output in a yard nobody has come to empty. The stacks sit at working temperature, and working temperature is not survivable. The yard is still full.",
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
						return {text = "Two passes, and you leave with a full hold and a reactor that will want a minute.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						Run.heat += 15
						return {text = "One pass. You come out with an armful and a cabin you cannot stand in."},
					botched = func() -> Dictionary:
						Run.heat += 24
						return {text = "A tower cycles while you are alongside it. You leave with nothing but the temperature."}},
				{label = "Shut it down first", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "Six hours to talk the control stack into standing down, and it stands down apologetically. The yard is cool by the time you reach it and half of what you wanted has cooked in place.", material = &"mining"}},
				{label = "Leave it running", stay = true, effect = func() -> Dictionary:
					return {text = "It will keep cracking a seam that stopped paying, and stacking a yard nobody comes to. Nothing you do here changes the second part."}},
			],
		},
		{
			id = &"the_sweep",
			title = "The sweep",
			body = "A beam sweeps across this arc every eleven seconds. The pulsar is close and old and keeps the interval to the fraction, and caught inside the sweep is a survey ship that got the arithmetic wrong once. Its instrument rack is still mounted on the dorsal spine. Eleven seconds gets you in. Eleven seconds gets you out. Cutting the rack free takes longer than one gap, so some of the work happens with the beam on the hull, putting heat in faster than the radiators shed it. It also leaves a glass crust that somebody at a refinery buys.",
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
						return {text = "Three intervals, three passes, and you are clear before the fourth. Whatever killed them was not the arithmetic. The hull is crusted with what the beam leaves behind, which somebody grows rich refining.", module = true, material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.heat += 9
						return {text = "Two intervals. You take the rack you came for and eat most of the third pass getting clear.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You get inside, get turned around, and spend the gap finding the way back out."},
					botched = func() -> Dictionary:
						Run.heat += 26
						return {text = "You are still alongside when it comes round. The hull holds. Everything on the hull does not."}},
				{label = "Log the bearing", stay = true, effect = func() -> Dictionary:
					return {text = "You mark the wreck, note the interval, and leave both for somebody with better vents and worse judgement."}},
			],
		},
		{
			id = &"tug_work",
			title = "Tug work",
			body = "A bulk hauler hangs crooked at the head of the dock queue, thrusters dead, nine ships stacked behind it. The dock's own tugs are committed for the next eleven hours, and every hour it sits there the dockmaster grows more interested in whose fault that is. Its pilot needs four minutes of somebody's engine, from a ship willing to put its nose against a hull forty times its mass.",
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
						return {text = "Four minutes, one contact point, no scoring on either hull. The queue moves, and the dockmaster logs which ship did it."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(31))
						return {text = "Six minutes and a stripe down your flank that will polish out. The queue moves."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You get it turned but not clear, and the yard tug that finally arrives gets paid the difference."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You put twelve tonnes of thrust into a hull that was not braced for it and both of you learn something.")
						return {text = "You put twelve tonnes of thrust into a hull that was not braced for it and both of you learn something."}},
				{label = "Sell her the fuel instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 20)
					Run.add_credits(OptionTable.purse(36))
					return {text = "She cannot manoeuvre but she can burn. You sell her enough to get clear under her own power, at a rate she is in no position to argue with."}},
				{label = "Wait in the queue", stay = true, effect = func() -> Dictionary:
					return {text = "Eleven hours. You are not going anywhere in particular, and neither is anyone else."}},
			],
		},
		{
			id = &"silt",
			title = "Silt",
			body = "A dust shoal hangs across the lane: fines and ice-grit, dense enough that the dish loses the far side of it. In the middle, one solid echo, hard and whole and ship-sized, holding its shape while the shoal turns around it. Going in means going in blind, on attitude jets, slow enough that anything harder than dust becomes a real question. The near edge is thin enough to see through, and it has been collecting what drifts down this lane for years: plate, loose fittings, ice with metal frozen through it. The grit is slow and soft and there is a very great deal of it.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 6,
			needs_fauna = true,
			choices = [
				{label = "Feel your way in",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in on attitude jets and touch nothing on the way. It is a survey cutter, intact, nobody has been here first, and it gives up a rack and the fittings around it like it had been expecting somebody.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You clip something soft on the way in and it does not matter. The cutter's racks come away clean.", module = true},
					partial = func() -> Dictionary:
						return {text = "You find it, get one panel open, and lose your bearings badly enough that leaving becomes the priority."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Something in the shoal is harder than the rest of it and you find that out with your bow.")
						return {text = "Something in the shoal is harder than the rest of it and you find that out with your bow."}},
				{label = "Sweep the edge", effect = func() -> Dictionary:
					return {text = "You work the outside of the shoal where the grit is thin, and take what has collected there.", material = &"wreck"}},
				{label = "Go round", stay = true, effect = func() -> Dictionary:
					return {text = "It is a very large amount of dust and it is in no hurry."}},
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
					return {text = "Forty-five credits and a transfer that takes about a minute. You dock nine ships early and she gets something out of two wasted days.", module = true}},
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
			body = "A breaker's yard in Redline colours, and the crew is waving you in. They have a new cutting head and no confidence in it, and they would rather learn what it does wrong on somebody else's plating than on the hull they take apart next week. They are offering money to put your flank against it for an hour. They are very clear that they do not know what it will do.",
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
						return {text = "The head works exactly as advertised and your plating takes it without complaint. They pay, and they pay well, because now they know."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "It bites deeper than the spec said. You come away paid and scored.")
						return {text = "It bites deeper than the spec said. You come away paid and scored."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(4), "It bites much deeper than the spec said, and they stop the test early and pay half.")
						return {text = "It bites much deeper than the spec said, and they stop the test early and pay half."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The head finds a seam. Somebody says a word and somebody else hits the cutoff, and afterwards everyone is very quiet and very apologetic.")
						return {text = "The head finds a seam. Somebody says a word and somebody else hits the cutoff, and afterwards everyone is very quiet and very apologetic."}},
				{label = "Rig them a target instead", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(17))
					return {text = "You weld them a test target out of scrap plating from your own stores. The cutting head has it in pieces by the end of the afternoon."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They take it well. Somebody out here will say yes to this before the week is out."}},
			],
		},
		{
			id = &"quarantine_flag",
			title = "Quarantine flag",
			body = "A station, dark, and a Calyx quarantine flag on every channel it owns. Eight days now. Nothing has gone in or out, and nothing has come to it either: no drones, no decontamination lighters, no Calyx hull anywhere on the dish. The flag is all there is. Two other ships sit off the exclusion line with you, reading the same nothing. Inside is a full station's worth of stock, and every hour the flag holds, it gets cheaper.",
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
						return {text = "The atmosphere reads clean, the hull sits at ambient, and no decontamination cycle has ever run. There is no outbreak behind the flag. There is a stock dispute wearing one, and a station very happy to sell to you, the first ship that notices.", module = true},
					clean = func() -> Dictionary:
						return {text = "Nothing on your instruments supports the flag. Nothing disproves it. You dock braced, buy fast, and leave loaded.", module = true},
					partial = func() -> Dictionary:
						return {text = "Half a read. You buy one crate you can inspect through the airlock glass, and nothing that breathes on you.", material = &"event"},
					botched = func() -> Dictionary:
						Run.add_credits(-50)
						return {text = "You read it wrong in the reassuring direction. The decontamination cycle you sit through afterwards costs more than the stock was worth."}},
				{label = "Wait with the others", stay = true, effect = func() -> Dictionary:
					return {text = "Two ships are already doing this. In eight more days, one of you finds out."}},
			],
		},
		{
			id = &"counterweight",
			title = "Counterweight",
			body = "A habitation ring tumbles end over end ahead, one rotation every ninety seconds, detached from some station and never collected. Everything inside is still bolted down where it was fitted, and the yard at the settlement one jump in buys ring fittings by the tonne without asking which ring. Outside there is plating, and there are antenna mounts, and they come past on every pass. So does the airlock, slow, and never in the same place twice. The ring masses more than the ship and it turns at the same rate the whole time you are working.",
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
						return {text = "You match it, hold it, and walk aboard as though the floor had always been down. Somebody's whole life is still bolted to it.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "You match it well enough. Getting back off is worse than getting on.")
						return {text = "You match it well enough. What you carry out you carry out one-handed, and getting back off is worse than getting on.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						Run.take_hull_damage(OptionTable.toll(2), "You get one hand on it and the rotation takes the decision away from you.")
						return {text = "You get one hand on it and the rotation takes the decision away from you."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Ninety seconds is a long time to be wrong about which way something is going.")
						return {text = "Ninety seconds is a long time to be wrong about which way something is going."}},
				{label = "Take the outside", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(8))
					return {text = "You do not try to board. You strip what is bolted to the exterior, on the pass, one piece at a time.", material = &"wreck"}},
				{label = "Leave it turning", stay = true, effect = func() -> Dictionary:
					return {text = "Once every ninety seconds, with everything still where somebody left it."}},
			],
		},
		{
			id = &"the_auction",
			title = "The auction",
			body = "Probate is clearing a dead crew's hold. There are no heirs, and the terms are as blunt as Probate terms always are: the lot is sealed, the manifest is sealed, the buyer takes it as it lies. Two of the last three lots went for less than the fee. The third went for considerably more, and whoever bought it has not been seen since, in the good way. Bidding closes in an hour and there are four of you.",
			tags = [&"contract"],
			group = &"berth",
			weight = 7,
			min_danger = 5,
			needs_berth = true,
			choices = [
				{label = "Bid on it", cost_credits = 70, effect = func() -> Dictionary:
					Run.add_credits(-70)
					return {text = "Seventy credits and a seal broken in your own hold, forty minutes later, with nobody watching in case it is embarrassing.", module = true, material = &"event"}},
				{label = "Read the room instead",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(13))
						return {text = "You do not bid. You watch who does, and what the Probate clerk's face does when the third bidder names a number. Afterwards you know exactly which lot next week is worth having."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						return {text = "You learn something about two of the bidders that will be worth knowing later."},
					partial = func() -> Dictionary:
						return {text = "You learn that everyone here is better at this than you are."},
					botched = func() -> Dictionary:
						Run.add_credits(-70)
						return {text = "You misread a nod as a bid and win a lot you did not want, at a price you did not choose.", material = &"event"}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "Sealed, unseen, as it lies. Somebody else's forty minutes."}},
			],
		},
		{
			id = &"escort",
			title = "Escort",
			body = "Three haulers and a courier hold station off your bow, unarmed, all headed the way you are, none of them happy about it. The only armed ship in the system has quoted them an escort price worth most of the run. They would rather pay you. All they are asking is that you fly alongside them, visible, with weapons.",
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
			min_danger = 3,
			max_danger = 8,
			max_security = 3,
			choices = [
				{label = "Open it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Reactor fuel, undeclared, in a casing rated for something duller. It is worth four times the freight, he knows it, and he renegotiates without arguing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Not what the manifest says. Not dangerous either. You take the job at a better rate."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You get the casing open, learn nothing useful, and get it closed before he notices. The rate stays the rate."},
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
			body = "A comet: three kilometres of dirty ice on a long slow orbit, no transponder, never claimed, because there is nothing out here to sell water to. Under the crust it is volatiles and a little metal. The crust has been hardening since this system was warm, it is under compression, and it has opinions about being cut.",
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
						return {text = "You take the crust off in sheets and get at the clean ice under it. Volatiles, water, and enough material in the tail to be worth the trip.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 18
						Run.take_hull_damage(OptionTable.toll(3), "The crust goes where you did not want it to. You get most of what you came for and wear the rest.")
						return {text = "The crust goes where you did not want it to. You get most of what you came for and wear the rest."},
					partial = func() -> Dictionary:
						Run.fuel += 10
						Run.take_hull_damage(OptionTable.toll(5), "The face calves while you are on it. You back off with a partial hold and a story.")
						return {text = "The face calves while you are on it. You back off with a partial hold and a story."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Three kilometres of compressed ice releases about eleven seconds of stored temper directly into your bow.")
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
			body = "The star's readings are climbing: a big flare, about forty minutes out, and the instruments are sure of it. Two minutes away is a rock large enough to shadow you, and tucked behind it, a survey drone that has clearly been using it the same way for years. Forty minutes is enough to reach the rock and strip the drone, with not much to spare.",
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
					return {text = "You put the rock between you and the star and wait the flare out. One piece of somebody else's cargo drifts into the shadow with you, and you keep it.", material = &"event"}},
				{label = "Outrun it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 16)
					return {text = "You leave before it peaks. It costs a burn you had not budgeted for and you never find out what was on the drone."}},
			],
		},
		{
			id = &"deadfall",
			title = "Deadfall",
			body = "Nine hundred metres of collapsed gantry lies across the approach: an orbital yard that came down on itself, not explosively, just structurally, over a decade of nobody paying for maintenance. It is still under tension in places and still lets go of a piece now and then. Under the middle of it is a fitting bay, and fitting bays are where the good parts are when the lights go out.",
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
						Run.take_hull_damage(OptionTable.toll(1), "You get in, get the bay open, and take a glancing hit from something that let go behind you.")
						return {text = "You get in, get the bay open, and take a glancing hit from something that let go behind you.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Two hundred metres in, a span shifts across your line and you reverse out past a bay you can see and cannot reach.")
						return {text = "Two hundred metres in, a span shifts across your line and you reverse out past a bay you can see and cannot reach."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A span that has held for a decade lets go while you are under it.")
						return {text = "A span that has held for a decade lets go while you are under it."}},
				{label = "Work the outside", effect = func() -> Dictionary:
					return {text = "The perimeter of the field is safe enough and picked over enough. You take what the last four crews did not think was worth the lift.", material = &"wreck"}},
				{label = "Leave it lying", stay = true, effect = func() -> Dictionary:
					return {text = "Nine hundred metres of somebody's deferred maintenance. It will finish coming down eventually, on its own."}},
			],
		},
		{
			id = &"the_long_tow",
			title = "The long tow",
			body = "A ship hangs dead off your bow, hull lights running on battery, and its crew answers the hail immediately: reactor scrap, six people fine, which is the wrong way round for how these usually go. The dock on the far side of this system will take it, if it can get there. A tow is four hours of your engine at a load it was not built for, with a hull on your stern the whole way that does not steer.",
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
						return {text = "Four hours, one heading, no drama. The dock takes it, and the dockmaster watches you come in with somebody else's ship on the line."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "Five hours and a stern mount you will want looked at. It gets there.")
						return {text = "Five hours and a stern mount you will want looked at. It gets there."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "You get it most of the way before the load tells you it is done. A yard tug comes out for the last of it and takes most of the fee."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 18)
						return {text = "The line parts under load. Nobody is hurt and nothing is lost except four hours, a tow line, and the fuel you burned."}},
				{label = "Sell them a reactor start", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 15)
					Run.add_credits(OptionTable.purse(36))
					return {text = "You have enough fuel aboard to bootstrap its cold reactor if they are not fussy about the margin you leave yourself. They are not fussy."}},
				{label = "Signal it in and go", stay = true, effect = func() -> Dictionary:
					return {text = "You put their position on the emergency band and leave. Somebody will come. Somebody usually comes."}},
			],
		},
		{
			id = &"the_calf",
			title = "The calf",
			body = "A juvenile hangs beside a cold rock, calling, separated from its pod, warm on every instrument, waiting the way the young of everything wait when they are lost. They are all warm. It is why they are hunted, and somewhere behind you a hunter has posted a standing bounty for a tagged calf. The pod is two hours out, answering on a frequency your hull feels rather than hears.",
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
						return {text = "You put your hull where a parent would put its flank, and it follows you all the way in. The pod closes around it, and the wake of nine of them turning at once carries you further than it has any right to."},
					clean = func() -> Dictionary:
						Run.fuel += 8
						return {text = "It follows, eventually, after deciding twice that you are a threat. The pod's wake pays for some of what the herding cost."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "It bolts the wrong way twice and you spend an hour of burn undoing each one before it finally hears the pod itself."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "It panics at exactly the wrong moment and its flank finds you at speed. It reaches the pod anyway. You limp.")
						return {text = "It panics at exactly the wrong moment and its flank finds you at speed. It reaches the pod anyway. You limp."}},
				{label = "Leave it calling", stay = true, effect = func() -> Dictionary:
					return {text = "The pod is two hours out. The hunter is closer. You do not stay to see which arrives first."}},
			],
		},
		{
			id = &"the_manifest",
			title = "The manifest",
			body = "A heat barge sits across the lane inward with its running lights on and its drives cold, and the woman flying it is hailing for a witness. The delivery protocols want a countersignature on the last leg from somebody with nothing to gain by it, and out here that is a short list. She has been holding station a day and a half waiting for a ship that neither pays her nor competes with her. The seal on the load reads nine hundred units, receipted at the last station that still had the authority to receipt anything. Your mass reading puts the barge four points heavy for nine hundred units of anything.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 9,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sign what the seal says", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "You countersign nine hundred units, hold formation for the last leg, and watch the barge become somebody else's jurisdiction. The fee clears before you have finished deciding what you saw. It is clean money for an hour of flying straight, and you will think about the four points again later, when there is less to do."}},
				{label = "Put the dish on the load first",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "Eleven hundred units against a receipt for nine. Somebody upstream is moving two hundred units of something inward and paying tax on the smaller number, and the woman flying it was never told what it is. You sign the honest figure. She pays you for the correction before you have finished logging it, relieved to have handed the problem back to the people who made it."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "The mass settles close enough to the seal that the difference is fuel, ice, and the way a barge rides when it is low on both. You sign, fly the leg, and collect."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(3))
						return {text = "Your figures will not settle and her window will not wait. You decline to sign anything you cannot read, take the standing fee for answering the hail, and watch her go looking for a witness with a worse dish."},
					botched = func() -> Dictionary:
						Run.add_credits(-60)
						return {text = "You sign a number the vault's own scale later disagrees with. The correction is applied to the witness who signed it, because the witness is the only name on the document anybody can find."}},
				{label = "Let her carry on", stay = true, effect = func() -> Dictionary:
					return {text = "She holds another hour on the open channel and then flies the last leg unwitnessed rather than lose the window. Whatever the barge is four points heavy with goes wherever it was going."}},
			],
		},
		{
			id = &"the_last_berth",
			title = "The last counter",
			body = "The deepest dock still lit, and behind its counter, one clerk. She has been logging arrivals for traffic that stopped arriving before her posting began, and she logs yours properly: name, mass, heading, the time to the minute. Her rate sheet has not changed in eleven years, which makes her fuel the cheapest in the galaxy and makes her the only person out here who does not know it. Her archive drawer holds one folder. Thick, unlabelled, and she calls it the observations.",
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
					return {text = "Thirty credits for what a rim station would charge ninety, off a sheet she sees no authority to amend and no reason to doubt. She stamps the receipt twice. The second stamp is for the copy nobody has collected in eleven years, and she makes it as carefully as the first."}},
				{label = "Stay and copy the folder", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "It takes most of a shift and the reactor idling the whole time. Other people's paperwork about the thing at the core: transit logs that stop mid-line, a mass estimate crossed out four times and never replaced, a requisition for instruments that were never sent and never cancelled. She reads over your shoulder the entire time and does not say anything. She has been waiting eleven years for somebody to ask.", archive_recover = true, material_id = &"survey_film", material = &"event"}},
				{label = "Leave her to the ledger", stay = true, effect = func() -> Dictionary:
					return {text = "One clerk, one drawer, one folder. Your arrival is the first entry she has logged in a long while, and she logs it beautifully."}},
			],
		},
		{
			id = &"counting_backwards",
			title = "Counting backwards",
			body = "A relay hangs dead on the approach with its transponder still talking. One number, broadcast once every forty-one years, each one lower than the last. Your archive holds three of them, logged by three different ships across two centuries, and the arithmetic is not hard: the next broadcast is zero. The dish puts that broadcast four days out. The relay is precursor work, older than any name anyone has for it, and it has been patient about whatever it is counting toward.",
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
						return {text = "The cutter opens the housing along a seam the builders left for exactly this, and the core comes away still warm. Forty-one years between one heartbeat and the next and it has never once gone cold. The grapple walks it into the hold, and the count goes with it, and it does not miss a beat for the change of address.", material_id = &"counting_core"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You take it fast and pay for the speed in waste heat the radiators will spend an hour shedding. The core sits in the hold counting down to something, on its own schedule, indifferent to having been moved.", material_id = &"counting_core"},
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
						return {text = "Forty-one years of heat and cold have welded the housing to its frame, and the cutter is not going to argue with that in the time you have. You come away with the readings instead (the interval, the bearing, the decay curve, shot straight off the dish and never developed) and whatever the cutter shook loose on its way back out.", material_id = &"survey_film", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something that had kept itself warm for two centuries objected to the cutter.")
						Run.heat += 20
						return {text = "Whatever has kept that core warm since before there were manufacturers objects to being opened. It objects briefly, and thoroughly, and through the hull."}},
				{label = "Wait out the four days",
					effect = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "Four days on station, holding position on fuel you will want later, watching a number that does not move. On the fourth day it moves. It goes to zero, the transponder stops, and then nothing happens at all: no signal, no light, nothing answering from anywhere in the sky. The recording runs for six more hours of that nothing.", material_id = &"last_broadcast"}},
				{label = "Leave it counting", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and go. It has waited two centuries for company and can wait a little longer for somebody with more fuel and fewer places to be."}},
			],
		},
		{
			id = &"holding_pattern",
			title = "Holding pattern",
			body = "Six ships hold a loose ring ahead with their drives cold and their transponders on. The hulls are weathered unevenly enough that they arrived years apart, and not one of them has moved since your dish first resolved them. They are not a convoy and they are not a blockade. Every one of them is pointed the same way, which is inward, and when you hail the ring the only answer that comes back is a receipt code.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sell them the way out", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(30))
					return {text = "They have been pointed inward long enough that the route behind them has gone out of date, and a current one is worth more than any of them will say out loud. You send the run so far: bearings, what the crossings cost, which stations still have somebody behind a counter. They pay warm-economy prices in credits minted somewhere that still has a mint. Nobody says what they want it for. Two of them ask for a second copy."}},
				{label = "Read their receipts",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "Six codes, one issuing authority, and the authority is a vault. They have delivered everything, by the way the holds read empty, and they are waiting to be paid in whatever it is a vault pays with. The oldest code is forty years old. You copy all six, because somebody further out will want to know what this queue looks like from the back of it.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						return {text = "The codes are vault-issued and sequential, which means this is a queue and somebody built it. It is orderly. It is also old."},
					partial = func() -> Dictionary:
						return {text = "The codes decode into references to a ledger you are never going to see, held somewhere you are not going to be admitted."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "You lean on the nearest transponder hard enough that all six ships light their drives at once, hold them for four seconds, and go cold again. Nothing is said. You burn out of the ring on a heading you did not plan and would rather not explain."}},
				{label = "Hold station with them", stay = true, effect = func() -> Dictionary:
					return {text = "You point inward, kill the drives, and sit in the ring a while. Nothing happens, and none of the six ships so much as trims its attitude. The ring is still there when you leave."}},
			],
		},
		{
			id = &"the_favour",
			title = "The favour",
			body = "A courier is hailing everything with a tank. She is running on fumes. Her charter pays on arrival, which is one ring further in than her fuel is, and she is offering over the odds because the alternative is drifting somewhere unfashionable until her company notices the delivery is late. She is in no danger. The late delivery is what she cannot afford.",
			tags = [&"contract"],
			group = &"",
			weight = 13,
			max_danger = 6,
			choices = [
				{label = "Sell her ten units", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Ten units across a line, at a rate that makes you both wince for different reasons. She is moving again before the transfer pump has cooled."}},
				{label = "Sell her twenty", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 20)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Enough to arrive with margin. She pays the rate without blinking, which tells you what the charter is worth, which stings slightly."}},
				{label = "Wish her luck", stay = true, effect = func() -> Dictionary:
					return {text = "She thanks you politely, notes your registry against the others who said no, and resumes hailing everything with a tank."}},
			],
		},
		{
			id = &"wrong_registry",
			title = "Wrong registry",
			body = "A delivery drone matches your course and runs a docking handshake older than your ship. It is carrying a consignment for a registry one digit off yours (a hull that may not have existed for decades) on a delivery clock so far overdue the penalty has wrapped around to zero. It will wait forever. It is built to.",
			tags = [&"signal"],
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Accept the consignment", effect = func() -> Dictionary:
					return {text = "You spoof the digit and the drone unloads with the ceremony of a machine completing the only thing it was ever for. The consignment is sealed, addressed, and heavier than it looks. The drone logs the delivery complete and turns back onto its route.", module = true, material = &"event"}},
				{label = "Correct its registry",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "You give it the right registry off an old dock ledger, and it recalculates a delivery route to a hull that died before you were flying. It thanks you in protocol, hands over the parcel it can no longer deliver, and burns for the grave.", material = &"event"},
					clean = func() -> Dictionary:
						return {text = "You give it a plausible registry. It accepts, recalculates, leaves a crate off the back of the consignment with you, and goes. Whether the route it is flying exists is not your department.", material = &"event"},
					partial = func() -> Dictionary:
						return {text = "Its verification loop rejects everything you offer, politely, forever. You disengage before it finishes the fourth attempt."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "You feed it a malformed registry and something in its logic decides you are the addressee of every consignment on its manifest. It follows you to the edge of sensor range, waiting."}},
				{label = "Decline the handshake", stay = true, effect = func() -> Dictionary:
					return {text = "It holds formation for exactly one hour, then returns to its route. Somewhere out there is a registry one digit from yours, and its parcel is still coming."}},
			],
		},
		{
			id = &"dead_station",
			title = "Dead station",
			body = "A station hangs dark and unpowered ahead, turning a little off true. The docking clamps still have pressure in them, so the reactor died slowly enough for somebody to shut things down in order, and none of the people who did that are aboard now. The face coming past has open bays with the racks still in them, gear nobody cleared out. The tanks are on the other side of the hub, sealed, with a coupling the grapple can work. Getting from one to the other is an hour of holding station against a hull that is not turning true.",
			tags = [&"salvage"],
			group = &"",
			weight = 12,
			max_danger = 6,
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
			body = "A looping voice repeating coordinates one jump off your route, in the flat cadence of a recording that has been running a long time. Whatever is at the other end has been transmitting through a hull big enough to carry a real transmitter, so it is either worth reaching or worth avoiding, and the recording does not say which.",
			tags = [&"signal", &"fight"],
			group = &"",
			weight = 11,
			max_danger = 6,
			choices = [
				{label = "Answer it", fight = true, effect = func() -> Dictionary:
					return {text = "It was bait, and the hull it was broadcasting from is real: still loaded, still worth taking off whoever is currently using it as a hook. Something is already firing.", fight = true}},
				{label = "Read it from cover",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You sit off the coordinates and listen. The loop has a second signature under it, holding station and not moving, which tells you what this is. You sell the coordinates as a hazard note at the next dock."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "Enough of the carrier resolves to tell you nobody aboard is alive to be rescued. That is worth logging, and a little to whoever buys logs."},
					partial = func() -> Dictionary:
						return {text = "You learn nothing except that it repeats every ninety seconds, which you could have counted from here."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You hold position long enough for the thing under the loop to get a good look at you, and you leave with your bloom up."}},
				{label = "Run silent", stay = true, effect = func() -> Dictionary:
					Run.heat = 0
					return {text = "You cut the reactor and drift past it with everything dark. Heat cleared, and the voice goes on repeating behind you."}},
			],
		},
		{
			id = &"whale_fall",
			title = "Whale fall",
			body = "The corpse of something enormous hangs ahead, coming apart slowly in the dark and feeding a whole economy of smaller things while it does. It has been dead long enough to have a population. Most of them are too small to read on the dish, a few of them are bigger than the ship, and all of them are feeding. Whatever it was made of is worth carrying, and the best of it is down in the seams between the ribs, which means working in among them for as long as the cut takes. Enough has come loose already to fill a bay, out where nothing is feeding.",
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
						return {text = "You work the seam quietly, in the lee of the ribs, and come away loaded before anything that lives here decides you are worth interrupting a meal for.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "You take what you came for. Something the size of a hatch cover watches you do it and elects not to mind."},
					partial = func() -> Dictionary:
						Run.add_material(&"exotic", 1)
						Run.take_hull_damage(OptionTable.toll(3), "Something feeding on the whale fall took an interest in the ship.")
						return {text = "Halfway through the cut the population decides collectively that you are competition. You leave with less than you wanted and a new set of scratches."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The whale fall was still occupied, and it objected.")
						return {text = "There are so many of the small ones, and they all arrive at once, while the big ones go on feeding."}},
				{label = "Take what has come loose", effect = func() -> Dictionary:
					return {text = "There is enough drifting clear of it to fill a bay without cutting anything, or annoying anything.", material = &"fauna"}},
				{label = "Let it rest", stay = true, effect = func() -> Dictionary:
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
						return {text = "They find what you are carrying and price it into the paperwork, and you pay both bills. What is left in the impound is still worth more than the morning cost you.", module = true}
					return {text = "Clean, waved through, and first in line for an impound nobody else waited out. The seizure clerk is glad of the company and the price is what it says on the notice.", module = true, material = &"wreck"}},
				{label = "Talk your way to the front",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Your registry says you are already cleared, because for the forty seconds it took them to read it, it did.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You come out of the queue two hours early and take the smaller half of the impound, which is still a half."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A patrol skiff crowded you off the impound gate.")
						return {text = "They notice, and the noticing is expensive in the way that costs paint rather than credits. You leave with nothing out of the impound."},
					botched = func() -> Dictionary:
						Run.add_credits(-45)
						return {text = "You are fined for the attempt, itemised, and made to wait anyway. The impound is empty by the time you reach it."}},
				{label = "Burn away", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 6)
					Run.take_hull_damage(OptionTable.toll(2), "You ran the lane, and something clipped you on the way out.")
					return {text = "You run: six fuel, a scraped flank, no record. The impound goes to the breakers at the end of the week without you."}},
			],
		},
		{
			id = &"derelict_hauler",
			title = "Derelict hauler",
			body = "An old freight frame, gutted down to structure and still holding its lines. Whoever stripped it took the fittings and left the thing they were bolted to, which is the opposite of the usual order and says they were in a hurry about something other than money. What is left is a spine, a set of dry tanks, and the mounts the racks came off, and none of it reads bent. Establishing that a frame will fly is hours of slow passes and instrument work. Cutting it up is quicker, and plating and wire off a hull this size sell to anybody with a yard.",
			tags = [&"salvage"],
			group = &"",
			weight = 6,
			max_danger = 6,
			min_danger = 2,
			choices = [
				{label = "Claim the hull", effect = func() -> Dictionary:
					Run.find_hull(LootGen.roll_hull(Run.node_at().danger))
					return {text = "The frame is flyable, which you establish the slow way: %s." % Run.found_hull.display_name()}},
				{label = "Strip it for scrap", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(35))
					return {text = "Plating and wire worth selling, and a frame left a little more gutted than you found it.", material = &"wreck"}},
			],
		},
		{
			id = &"hostile_contact",
			title = "Hostile contact",
			body = "A hull sits dead ahead where the chart shows nothing, engines cold, running lights off, and it already has your registry: the query came in before your dish had finished resolving its shape. No hail follows. No demand. It simply turns, unhurried, until its bow is pointed at you, and holds there, waiting to see what you are going to do about that.",
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
					return {text = "You light the drives and close the distance before it finishes deciding you are prey. Whatever it came out here for, it was expecting slower work than this, and the first exchange says so.", fight = true}},
				{label = "Burn past it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You put the throttle down and take the long way round the system, watching its bearing the whole way. It does not follow or hail. It turns back to where it was, and you never learn what it wanted from you."}},
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
					return {text = "You put the grapple on it and cut the racks out through the breach. Whatever killed them did not take the parts. You leave with what would have been somebody's spares, and the hull colder than you found it.", module = true}},
				{label = "Read the log first",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						return {text = "The recorder is intact, and it names which racks were loaded last and what went into them. You pull the best of those, and the crate stowed beside them, and leave the rest where the cold kept it.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "Enough of the log survives to say the hull is not rigged: no scuttling charge, no scavenger trap, just a crew that ran out of heat. You strip it at your own pace.", module = true},
					partial = func() -> Dictionary:
						return {text = "The recorder is slag, and the racks are locked to a registry the slag used to hold. You take what is drifting loose in the open sections and learn nothing about how they died."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something in the dead hull was still charged.")
						return {text = "A cell that should have been flat was not. It discharges into the bow the moment the panel comes off, and you leave the hull with less ship than you arrived with."}},
			],
		},
		{
			id = &"cordon",
			title = "The cordon",
			body = "Three ships hold a line across the lane with their weapons live and a strobe running the width of it: a toll. The hail is polite and has a rate card attached: sixty credits a hull, payable now. Out here there is nobody to complain to, and the ships on the line know exactly how far away the nearest somebody is.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 12,
			regions = [MapGen.Region.LAWLESS],
			max_security = 2,
			min_danger = 5,
			choices = [
				{label = "Pay it", cost_credits = 60, effect = func() -> Dictionary:
					Run.add_credits(-60)
					return {text = "Sixty credits and a wave from whoever is in the chair. The strobe drops, the lane opens, and you fly it end to end without so much as a sensor ping."}},
				{label = "Run it",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						return {text = "You are past the toll before the ships have finished discussing it. They get a shot off at where you were, and the lane is yours without spending a credit or a unit of fuel."},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						return {text = "They get a burn off the moment you commit. You take the lane at full throttle with the strobe chasing you down it, and the tank shows the sprint when you come out the other side."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 26)
						return {text = "You commit, they close the gap, and you take the wide route at speed, the expensive one, out around the reach and back. Through, and lighter by half a ring's fuel."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 40)
						return {text = "You cross the lane twice, both times at full burn, the second time for no reason either of you could name afterwards. They let you go out of something like pity. The tank does not."}},
				{label = "Break it", fight = true, effect = func() -> Dictionary:
					return {text = "You come at the line the way nobody who pays sixty credits ever does. They are not expecting a ship that came out here to do this, and it shows in how long they take to answer.", fight = true}},
			],
		},
		{
			id = &"salvage_rights",
			title = "Salvage rights",
			body = "A wreck lies open along its length, and somebody is already on it: a cutter ship anchored at the stern, floods on, gear deployed, half the racks gone. They watched you arrive. Nobody hails. Out here, salvage rights are a question of who is holding the cutter, and they are. The bow section is still untouched.",
			tags = [&"salvage", &"contract"],
			group = &"wreck",
			weight = 11,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY],
			min_danger = 2,
			choices = [
				{label = "Work the bow", effect = func() -> Dictionary:
					return {text = "You take the bow while they take the stern, two ships working one wreck in silence. When the good rack comes free they hold their floods on you for a second, just to show they saw, and go back to work.", module = true}},
				{label = "Find what they missed",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(35))
						return {text = "Your dish maps the hull's voids and finds the sealed transfer hold their cutting line went straight past. A module, still racked, and a sealed bale of cargo nobody opened. You are gone before they finish the stern.", module = true},
					clean = func() -> Dictionary:
						return {text = "You read the frame, pick the one section their floods never swept, and pull a rack out of it clean. They notice. They decide it is not worth the fuel.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Their cut got everything worth mounting. What is left is small and loose. You sweep what you can of it out of the open sections with their floods tracking you the whole time."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "You cut into the section their anchor line is braced on, and everything stops. The price of it not becoming a fight is twenty-five credits, transferred while their floods hold steady on your cockpit."}},
				{label = "Leave it to them", stay = true, effect = func() -> Dictionary:
					return {text = "One wreck, one cutter crew, and floods that follow you all the way out of sensor range. It was theirs the moment they anchored."}},
			],
		},
		{
			id = &"still_under_warranty",
			title = "Still under warranty",
			body = "A wreck with a Verity plate still bright on the flank, and something aboard still live: a service handshake pings you every ninety seconds, three tones, the same three tones, asking any passing hull to identify itself. The crew that should answer is gone. The bay does not know that. It has been asking for a long time.",
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
						return {text = "You answer with your own registry and the wreck accepts it without a pause. Down the flank, service bays cycle open one after another, and the covered parts release into the dark for whoever the hull now believes you are.", module = true},
					clean = func() -> Dictionary:
						return {text = "The handshake takes your registry on the second try. One bay opens. What is racked inside comes free clean, and the three tones go back to asking the dark.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The wreck accepts you, but the bays stay shut: all it will release is the courtesy locker beside the lock, a few sealed spares with Verity's name on the wrap."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "The handshake flags your registry as not the holder of record, and the bay lock arcs the moment your grapple touches it. The scoring down your flank costs fifteen credits to make right."}},
				{label = "Strip it regardless", effect = func() -> Dictionary:
					return {text = "You cut the racks out with the handshake still asking, every ninety seconds, three tones into the dark. It is asking when you leave. It will be asking for a long time after.", module = true}},
			],
		},
		{
			id = &"collapsed_lane",
			title = "Collapsed lane",
			body = "The short way on runs through a shipbreaker's yard: a lane of dead hulls packed so close the dish reads it as one long wreck, spars crossing the gap at every height. The breakers left them where they lay when the money stopped. Going around is a day you do not have. Going through costs nothing at all if nothing touches you, and the burn you save is real.",
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
						return {text = "Plating screams the length of the lane and holds. Spars pass close enough to read the breaker's chalk marks on them. You come out the far side with every unit of fuel you would have spent going round."},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "The shipbreaker's lane took its cut.")
						Run.fuel += 10
						return {text = "Something gives near the bow, a sound like a hatch going the wrong way. You keep going, and you keep the fuel, and you have a look at the bow later."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The shipbreaker's lane took its cut.")
						return {text = "Halfway in, a spar goes through the forward plating and stops, and the lane is suddenly all spars. You reverse out the way you came, slowly, wearing it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead hull folded the bow in the breaker's lane.")
						return {text = "The lane closes on you between two hulls that were never going to stay where the breakers left them. What comes out the other side is your ship, mostly."}},
				{label = "Go around", stay = true, effect = func() -> Dictionary:
					return {text = "The long way. A day around the yard with the wrecks on your beam the whole time, and nothing happens. You come out the far side a day later than you meant to."}},
			],
		},
		{
			id = &"drifting_lifepod",
			title = "Drifting lifepod",
			body = "A lifepod tumbles across your bow, transponder weak and getting weaker, the rhythm of a battery that has been dying for months. The viewport is frosted from the inside. Someone is still in there, or was. Somebody else has been here first, because the lock housing carries a fresh weld that was never part of any pod's design.",
			tags = [&"signal"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Crack it open", effect = func() -> Dictionary:
					if Rng.event.randf() < 0.6:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You take it on the grapple and cycle the lock from the board. The fresh weld is a scavenger's charge, and it fails to fire when the seal breaks. Inside, no occupant: sellable cargo packed where a person should be."}
					Run.take_hull_damage(OptionTable.toll(5), "A scavenger trap finished what the cold started.")
					return {text = "A scavenger trap. It goes off against your hull."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You let it tumble on, frost side turning slowly toward the star and away again. The transponder is still going when it leaves sensor range, weaker than when you found it."}},
			],
		},
		{
			id = &"the_dust_cloud",
			title = "The dust cloud",
			body = "The star is shedding, and it has been for a long time. What comes off ends up here as warm dust, too fine to see until it is on you. Everything in this system has a coat of it on the side that faces the light. It will stick to your radiators too, and it does not fall off on its own. Deep in the thickest part of the cloud there is a mining ship, dusted over, holds shut, drifting. Nothing out here moves fast enough to have wrecked it, so at some point it simply stopped.",
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
						return {text = "The grapple gets hold of the towing eye and drags it out of the cloud a metre at a time. The dust comes off in sheets once it is moving. The holds were shut, not sealed, and they open for the cutter in about ten minutes.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You pull it out fast and the dust goes everywhere. Every radiator you have is coated, and the vents will be an hour clearing them. The holds are worth the hour.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "It shifts, and then it settles back, and the cloud closes over it again. You spend an hour on it and come away with nothing but a hot ship."},
					botched = func() -> Dictionary:
						Run.heat += 16
						Run.take_hull_damage(OptionTable.toll(4), "Star dust got into the intakes faster than the vents could clear it.")
						return {text = "It comes free all at once and a slab of the crust comes with it, straight into your intakes. The hull holds, and the vents behind it do not."}},
				{label = "Fly the cloud with a hold open", effect = func() -> Dictionary:
					Run.heat += 9
					return {text = "You open one hold and fly the length of the cloud slowly. The dust packs into the corners the way it has packed onto everything else here, and it heats the ship the whole way. You end up with a hold of fine metal the star threw off.", material = &"mining"}},
				{label = "Keep clear of the cloud", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the lit side of the system and leave the ship where it stopped. It has been there for years. It will be there next year."}},
			],
		},
		{
			id = &"the_water_stop",
			title = "The water stop",
			body = "Two people run a water stop sunward of here. They hold tanks of ice out in the light, let the star do the work, and sell the water to anything passing, and have done for eleven years. The plant was parked in a stable orbit and never needed an engine, and the orbit has stopped being stable, slowly, and in the one direction that matters. They are on the open channel asking for a tow. They are asking everyone, because there is not much traffic and they have been asking a while.",
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
						return {text = "You get your nose against the plant and hold a long, slow burn. Forty minutes of that and they are back where they were eleven years ago. They pay out of a box they keep under the console, and they count it twice, and both counts come out the same."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The tow works, though it takes longer than either of you expected, and it puts them high enough to stop worrying. They pay what they said they would. Nobody says out loud that this will need doing again."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.add_credits(OptionTable.purse(7))
						return {text = "You get them moving and the line slips before they are anywhere near safe. They are higher than they were and not high enough. They pay you something for the try, because they will be asking again next month."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A water plant the size of a station came around under tow and the hull was what stopped it.")
						return {text = "The line goes tight off-centre and the plant swings around faster than something that size should. It stops against your side, and the plant is undamaged."}},
				{label = "Sell them fuel instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					Run.add_credits(OptionTable.purse(18))
					return {text = "They have thrusters on the tanks and nothing to run them on, so you sell them fuel. Fourteen units across, at a price you would be happy to pay yourself. They will burn it a little at a time and climb out on their own over the next month. It pays less than the tow, and it comes out of a tank you cannot fill until the next station."}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck and go. The tanks keep melting, the ships keep not coming, and the orbit keeps doing what it is doing. They have months yet, and they know that better than you do."}},
			],
		},
		{
			id = &"the_lit_side",
			title = "The lit side",
			body = "A freighter that has kept the same face to the star for decades. Dead, but dead pointing the right way, which is more luck than most wrecks get. The side that takes the light is glazed over with dust and heat, baked on year after year until it went hard and clear, like amber. You can see the layers in it. The cold side is bare metal, and the holds on that side would open after an hour of cutting. Working the lit side means sitting in the light for as long as it takes.",
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
						return {text = "You sit in the full light and take it off in plates. It comes away solid and still warm through, with the layers stacked in order, decades of this star, one year on top of the next. It goes into the hold hot and it stays hot for a long time.", material_id = &"corona_amber"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get a good amount off before the vents start falling behind. What you have is worth carrying, and the last plate brings a strip of hull with it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 14
						return {text = "The glaze is welded to the plating underneath, and the cutter is doing more heating than cutting. You give it up with a hot ship and an empty hold."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(5), "Ten minutes too long in the full light, and the vents never caught up.")
						return {text = "You stay ten minutes longer than the vents can carry. Nothing catches fire, but things stop working one after another, starting on the side facing the star."}},
				{label = "Take the cold side instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 9)
					return {text = "Sitting in the freighter's shadow means holding the freighter's attitude, and that is a slow drip of fuel for the whole hour. The holds on the cold side hold ordinary cargo, and you take some.", material = &"wreck"}},
				{label = "Leave it facing the star", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go. It has been building that face for decades and it will not stop in the time it takes you to find better work."}},
			],
		},
		{
			id = &"paying_for_shade",
			title = "Paying for shade",
			body = "One rock in this system sits where it stays put, and it throws a shadow long enough to hide a dozen ships. Two ships got here first and they hold the near edge of it. They are not hiding what they are doing: they charge for a spot, cash up front, and they say so on the open channel to everyone who comes in. The instruments put the next flare about ninety minutes out. Further back in the shadow is forty years of what people left behind when they ran: cargo, a dead ship, loose plate.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pay for a spot", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "You pay, take the spot they give you, and sit out the flare with everything turned down. Nobody says anything about the loose plate further back in the shadow, and nobody moves when the grapple goes out for a piece of it. They sold you the shade, and said nothing about what is standing in it.", material = &"wreck"}},
				{label = "Take a spot without paying",
					check = {attr = &"stealth", need = 6},
					met = func() -> Dictionary:
						return {text = "You come in cold along the back edge, where the dead ships are, and sit among them. The flare comes and goes. On the way out you take the best thing you were parked next to. Nobody ever calls you on the channel.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You get a poor spot at the edge, half in the light, and hold it. It is uncomfortable and it is free. Something small drifts against the hull while you wait, and you keep it.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The edge of the shadow moves during the flare and you move with it badly, and spend the worst of it with a third of the ship in the light. You come out hot and carrying nothing."},
					botched = func() -> Dictionary:
						Run.heat += 18
						Run.take_hull_damage(OptionTable.toll(5), "Pushed out of the only shade in the system, twenty minutes before the star made the point.")
						return {text = "They find you inside twenty minutes and put a light on you until you leave, and there is no argument. The flare arrives while you are out in the open."}},
				{label = "Move on before it hits", stay = true, effect = func() -> Dictionary:
					return {text = "You are out of the inner system before the readings mean much. It costs you the shade and everything sitting in it. The rock will still be there next time, and so will they."}},
			],
		},
		{
			id = &"the_century_log",
			title = "The century log",
			body = "A machine sits in a close orbit here, measuring the star. It has been doing it for a hundred years, one reading an hour, every hour, through every flare. Nobody predicts a star this size well, so a hundred years of one is worth money to anybody who has to fly near stars for a living. The people who put it there stopped answering a long time ago. It is cooking now, and only the shaded half still works. After every flare it sends a summary out to a receiver that is not there any more.",
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
						return {text = "You match its roll, put the dish on it, and pull the whole hundred years down in one pass. Every hour, every flare, every gap. The instrument head comes off the mount as well, still cold and still good, and it is sitting beside you when the machine turns away.", module = true, material_id = &"survey_film", archive_recover = true},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get the link, and about forty years of it, before the working half rolls away from you. Forty years of a star like this is still worth carrying. The grapple takes a panel off the housing as you go past.", material_id = &"survey_film", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The link wants an answer the machine has not been asked for in a century, and you cannot give it one in the time you have. You come away with a piece of the housing and none of the readings.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 24
						Run.take_hull_damage(OptionTable.toll(4), "Caught on the lit side of a machine that has been cooking for a hundred years.")
						return {text = "You misjudge the roll and come around on the lit side with nothing between you and the star. It only lasts a few seconds, which is enough."}},
				{label = "Answer it", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "The frequency is in every summary it sends. You send a receipt back on it, in the format a hundred-year-old machine expects, and it treats that as the job being finished. It sends you everything it has. That takes eleven hours with the reactor idling, and when it is done it stops transmitting.", archive_recover = true, material_id = &"survey_film", material = &"event"}},
				{label = "Leave it working", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go. It takes another reading while you are still in range, and another one after that, and it will keep taking them until the shaded half stops being shaded."}},
			],
		},
		{
			id = &"the_failing_shade",
			title = "The failing shade",
			body = "Somebody built a shade here: foil on a frame, kilometres across, hung between the star and a lane that would be no use without it. It is still up, and it has been up long enough that things have collected in the cool behind it: three wrecks, a fuel ship, cargo that came loose from something and stopped where the light stops. One edge of the frame is buckling. When it goes, the shade goes with it, and everything sitting behind it gets the full face of the star.",
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
						return {text = "You go for the fuel ship first, because that is where the fittings are, and you have the good half of it aboard before the frame makes up its mind. What you leave, you leave in daylight.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You work fast and pick well enough. The edge lets go while you are still shortening the last line, and the shade peels back over you as you burn out from under it. You are clear with about four minutes to spare.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You spend too long deciding which of the three wrecks is worth the hour, and the frame decides for you. You leave with an empty hold and a ship that took the last of it in the open."},
					botched = func() -> Dictionary:
						Run.heat += 26
						Run.take_hull_damage(OptionTable.toll(4), "Under a kilometre of failing foil when it let go, with the star straight behind it.")
						return {text = "The buckled edge lets go along its whole length and the rest of the frame follows it. A sheet of foil the size of a town comes down across you on the way past. Then there is nothing between you and the star."}},
				{label = "Hold the frame up", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 15)
					return {text = "You put the grapple on the buckled edge and hold it straight on thrust. It costs a long burn and it buys hours instead of minutes. You work the fuel ship at your own speed with the shade steady over you. It is still up when you let go. It will not be up next year.", material = &"wreck"}},
				{label = "Leave the shade alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log what is behind it and fly on. Nothing you could do here would keep that frame up, and everything in the cool has been sitting there long enough to belong to nobody."}},
			],
		},
		{
			id = &"sixty_containers",
			title = "Sixty containers",
			body = "A hauler broke up here a while ago, and its cargo is spread across the approach in a long line, sixty containers or more, all sitting in the light. The light has burned every label off them. The seals are cooked. Some of what is inside does not mind the light at all, and some of it has been ruined by it, and from outside there is no telling which is which. Metal, ore and tools are fine. Medicine, film and anything with a circuit in it are not.",
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
						return {text = "You get a rough sort out of the dish, good enough to skip the worst of them. Two hours in the light is two hours of heat, and you come out with one container's worth of something the light could not hurt.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The readings all look the same after the first hour. You open the ones that seem heaviest and get one good container in five. The rest is cooked stock, and the ship is hot from the sorting.", material = &"event"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Three hours in the light of a blue hypergiant, reading labels that were not there.")
						return {text = "You spend three hours in the light reading numbers that never add up, and open four containers that hold nothing but ruined stock. Your own lit side has started to read thin by the end of it."}},
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
			body = "A small freighter is calling for help on the open channel, and the help it wants is odd. Its dish array is burned out, since the light here does that to anything pointed at the star, and the pilot cannot swap in the spare, because the spare would start cooking the moment it was mounted. She needs something big to sit between her ship and the star for about an hour. She is offering good money for an hour of sitting still, because sitting still here costs hull, and she knows it.",
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
						Run.take_hull_damage(OptionTable.toll(2), "An hour side-on to a blue hypergiant, for somebody else's antenna.")
						return {text = "You hold the hour. The plating on your lit side is measurably thinner at the end of it. She gets the array mounted and pays what she offered."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(3), "Forty minutes in the light for a stranger's antenna, and the plating did not want thirty of them.")
						return {text = "You hold forty minutes and then the readings on your own plating say stop. She gets the array half mounted and finishes it in the shadow of her own hull, badly. She pays you for the forty minutes."},
					botched = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(5), "Sat in the full light of a blue hypergiant for an hour, and the plating did not last the hour.")
						return {text = "You misjudge what an hour costs here. The array gets mounted behind you. Your lit side comes out of it thinner than any hour should cost, and the money does not cover the difference."}},
				{label = "Tow her into a shadow instead", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					Run.add_credits(OptionTable.purse(16))
					return {text = "There is a rock forty minutes away with a shadow the right size. You tow her there, which costs fuel and most of a day, and she swaps the array in the dark at her own pace. She pays less than she offered for the hour, because the hour was the hard part and you did not do it."}},
				{label = "Leave her calling", stay = true, effect = func() -> Dictionary:
					return {text = "You wish her luck and fly on. She goes back to calling. There is not much traffic here, and the next ship through will be as reluctant as you were."}},
			],
		},
		{
			id = &"the_comet",
			title = "The comet",
			body = "A comet is coming through, close in, and the star is boiling it. Its tail is a hundred thousand kilometres of water, gas and rock, lit white, pointing straight out along the lane you need. There is more clean water in that tail than in every tank on every station within a week of here. There is also more rock in it than the dish can count, all of it moving, none of it small. Riding the tail fills the tank. Riding it badly is how ships end up in the tail for good.",
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
						return {text = "You put the nose into the tail and hold it there for eleven minutes, correcting the whole time, with rock going past on both sides close enough to hear. The tank fills. Ice packs into the open hold along with it, and you come out the far end of the lane heavier than you went in.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 18
						Run.heat += 10
						return {text = "You get most of a tank before the rock gets too thick to fly through. The ship is hot from the light, and it will take the next hour to shed it, but the fuel is real."},
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
					return {text = "You keep to the thin edge of the tail, where the rock is rare and the ice is too. It takes an hour in the light. Ten units of water go into the tank, and the ship will spend the next hour shedding heat."}},
				{label = "Wait for it to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the lane and watch it go by. Three days, and then the sky is clear again and the tank is exactly as full as it was."}},
			],
		},
		{
			id = &"the_beacon_job",
			title = "The beacon job",
			body = "A navigation beacon holds station on the lane inward, and it is dead. The light here kills a circuit board in about four days, so whoever runs the beacon keeps a crate of spares tethered beside it, and there is a standing offer painted on the crate in letters the star has not yet finished with: swap the board, key in the job number, and the fee clears. Nobody is here to watch you do it. Nobody has been here in a while. The crate has eleven boards left in it.",
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
						return {text = "You pull the dead board with the grapple and seat a new one in nine minutes, which is about how long the light gives you before the new one starts to go. The beacon comes up. You key the number and the fee clears. On the way out, the lane is marked again."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes two boards. The first one cooks in the grapple before it is seated. The second goes in fast, the beacon comes up, and you key the number and are paid for one swap, which is what the crate says the job is."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 14
						return {text = "The beacon comes up for forty seconds and goes dark again. You key the number anyway. Something pays out, a fraction for a fraction of a job, and the crate has ten boards in it now."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(4), "Working a dead beacon in the full light of a blue hypergiant.")
						return {text = "You are still working when the board in the grapple lets go, and the beacon housing takes a piece of your hull with it on the way past. The beacon stays dark. The crate has ten boards in it and you have less ship than you came with."}},
				{label = "Take the crate", effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "Eleven boards, sealed against the light, are worth more at a station than one swap pays. You cut the tether and take the crate, and cutting anything here means ten minutes in the light. The beacon stays dark, and the lane stays unmarked for whoever comes next.", material = &"wreck"}},
				{label = "Leave it dark", stay = true, effect = func() -> Dictionary:
					return {text = "You log the beacon as dead and fly the lane by dead reckoning, the way everyone else has been doing. The crate is still there, and the offer still stands."}},
			],
		},
		{
			id = &"the_sorting",
			title = "The sorting",
			body = "The light is strong enough here to push things. Not much, but it does not stop, and given years it moves anything that is not tied down, light things quickly and heavy things slowly. So the wreckage in this system has been sorted. Everything light, meaning foil, film, plastic, anything worth carrying that weighs nothing, is far out on the cold side by now, blown clear years ago. Everything heavy is still here in the light: keels, reactor housings, armour plate, the parts of ships that were built to last. They have lasted. Working them means working in the light.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work the heavy field",
					check = {attr = &"hull", need = 8},
					met = func() -> Dictionary:
						return {text = "Your plating can take an afternoon of this, and an afternoon is what it takes. Armour plate the star could not shift, a reactor housing, keel bolts as thick as a mooring post, the heavy end of forty years of wrecks, all still bolted down, all still good.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "An afternoon in the light of a blue hypergiant, working the heavy field.")
						return {text = "You get most of an afternoon before your own lit side starts to read thin. What you take is the best of the heavy field, and it cost hull to take it.", module = true, material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Stayed in the heavy field an hour longer than the plating could pay for.")
						return {text = "You get one good piece off a keel and then the readings on your own plating say stop. Your lit side is thinner than the piece is worth, and you know it before you are clear.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Stayed in the heavy field until the plating went the way of the paint.")
						return {text = "You stay too long, and the light does to your plating what it has done to everything else here. You leave with nothing in the hold."}},
				{label = "Chase the light things outward", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 16)
					return {text = "You burn out to the cold side and spend a long day among what the light pushed there. Most of it is worthless. Some of it is film and foil that has kept, out of the light, and you take that.", material = &"event"}},
				{label = "Leave it sorted", stay = true, effect = func() -> Dictionary:
					return {text = "You log the field, both halves of it, and go. The light will keep sorting it. In another forty years the heavy things will be a little further out and the light things will be gone entirely."}},
			],
		},
		{
			id = &"clean_hull",
			title = "Clean hull",
			body = "A ship is holding a long way out from the star, and the pilot flying it wants to be closer to the light. He wants his ship towed in until every marking on it burns off, the registry, the yard numbers, the name, down to bare metal, and then towed back out again. His own drive is out, or he says it is, and a ship with no drive drifts in the light. He says a day will do it. He does not say why, and out here nobody asks. He is paying for the tow both ways, and he is paying well.",
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
						return {text = "You tow him in and hold beside him for a day while the star takes his ship's name off it, and then you tow him out. Your own lit side comes out shinier than it went in and no worse than that. He pays in full and says nothing, and you say nothing, and he flies inward as a ship with no name."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "A day in the light of a blue hypergiant, burning somebody else's name off.")
						return {text = "You hold beside him for the day. Your plating is thinner for it, by an amount you will pay to fix. His ship comes out clean, and he pays what he said."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Held a stranger's ship in the light for most of a day, and the plating gave out before the paint did.")
						return {text = "The day is too long for your plating and you pull him out with his markings half gone, unreadable but not clean. He pays for half a job. He is not happy, and he is not in a position to say so."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "A day in the full light of a blue hypergiant, burning somebody else's name off.")
						return {text = "You stay the day and your own ship pays for it. His ship comes out bare, and yours comes out with less plating than a day should cost, and he pays nothing, because the tow out was your job and you had to leave before you finished it."}},
				{label = "Tow him in and come back tomorrow", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You tow him in, let go, and pull back to where the light is only unpleasant. A day later you go in and find him. He has drifted, and the burn is uneven, but his name is gone. He pays for two tows and not for the day, which is what he got."}},
				{label = "Decline the job", stay = true, effect = func() -> Dictionary:
					return {text = "You tell him no, and he takes it well, the way somebody does who has been told no before and expects to be again. He is still holding there when you leave, a long way out from the star, waiting for the next ship through."}},
			],
		},
		{
			id = &"lost_in_the_gas",
			title = "Lost in the gas",
			body = "A hauler is calling on the open channel from somewhere inside the cloud. Two aboard, low on fuel, and lost. Their dish is a small one, and the gas scatters everything it sends out, so they have no fix, no stars, and a heading they stopped trusting an hour ago. They can hear you. That is all they know about where you are. They will pay for a way out, and they will pay more for somebody who comes in and gets them.",
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
						return {text = "Your dish is bigger than theirs. You find them on the third sweep, a cold spot in warmer gas, and read them a heading, and then another one when the gas moves, and then a third. Forty minutes later they come out of the cloud two kilometres off your bow, and they pay before they have finished thanking you."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes two hours and eleven headings, most of them corrections to the one before. They come out in the end, a long way from where you said they would, and pay what they offered for the way out."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You lose them twice and find them once, and in the end you burn out to the edge of the cloud yourself so they have something bright to steer at. They make it. They pay a little, because a little is what they have left."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.take_hull_damage(OptionTable.toll(3), "Went into the gas after a lost hauler, and found a rock first.")
						return {text = "You give them a heading that is wrong, and they burn on it for twenty minutes before either of you knows. So you go in after them. The gas hides a rock the size of a station until you are nearly on it. You get them out, eventually, and nobody pays anybody."}},
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
			body = "Something in the cloud is pinging. A cargo pod, by the sound of the transponder, the kind that gets dropped when a hauler needs to lose weight quickly and means to come back for it. Nobody has come back. The gas scatters the signal so the bearing wanders, five degrees one way, then ten the other, and the pod itself is invisible until you are close enough to touch it with the grapple. The gas is thick enough here to hide rocks as well.",
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
						return {text = "You fly it by ear, correcting every time the bearing jumps, and slow down whenever the gas thickens. The pod is where the last ping said, sealed and cold, and whatever was worth dropping and coming back for is still inside.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 4)
						return {text = "It takes longer than the ping suggests, and the ship spends most of it at walking pace with the lights on. The pod is there. So is a rock, close enough to have mattered if you had been going faster.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "The bearing walks you in a circle twice before you catch on. You find the pod's tether and a case that came off it, and not the pod.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Followed a cargo pod's transponder into the gas, and found the rock first.")
						return {text = "You come around a bank of gas at speed and there is a rock in it. The pod is somewhere on the far side, still pinging. You do not stay to find out where."}},
				{label = "Fly a slow search pattern", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 7)
					return {text = "You give up on the bearing and fly the box the hard way, slowly, lights on, one leg at a time. It costs fuel to fly slowly. You find the pod's tether and one case that came off it, and enough of the pod to know somebody else has already been through it.", material = &"event"}},
				{label = "Leave it pinging", stay = true, effect = func() -> Dictionary:
					return {text = "You log the pod and go. It has been pinging long enough for the gas to have moved around it twice. Whoever dropped it knows where it is, or has stopped caring."}},
			],
		},
		{
			id = &"the_cache",
			title = "The cache",
			body = "Half a kilometre off the lane, deep enough in the cloud that you would never have seen it without the lights, there is a string of sealed containers on a tether between two rocks. Eight of them, all alike, all marked with the same code and nothing else. Nothing gets left here by accident. Out in the open any dish would find them in an hour; in here, nobody looks. Somebody put them here on purpose, and somebody is coming back for them, and it is not you.",
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
						return {text = "You get six of the eight aboard before the lights of another ship show in the gas, a long way off and closing slowly. You leave the last two and go, and it does not follow. Of the six, one is worth having.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "You have one container off the tether when the other ship's lights show in the gas, and you go, fast, with the one. It is not the good one.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "One of the containers in the cache was there to stop people taking the others.")
						return {text = "The second container from the end is not a container. It goes off when the grapple takes the tension off the tether, and you spend the next hour finding out which of your plates are still where they should be."}},
				{label = "Cut one loose and go", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "One container, the one nearest the lane, cut quick and taken quick. It costs fuel to match the tether's drift in the gas and more to get back out. The other seven stay where they were put. Whoever comes back for them will notice, and will not know who.", material = &"wreck"}},
				{label = "Leave it hidden", stay = true, effect = func() -> Dictionary:
					return {text = "You switch the lights off and back out the way you came. The string stays on its tether, eight containers of somebody's business, waiting for somebody."}},
			],
		},
		{
			id = &"no_stars",
			title = "No stars",
			body = "The gas has closed in, and there is nothing to steer by. No stars, no beacon, no fix. The dish reads cloud in every direction, all of it the same. The gyros give you a heading that was true when you entered and has been drifting since, an hour of drift or maybe two, in a direction nobody can name. You are moving. The gas is moving too, at a different speed, and the difference is the thing you cannot see. Somewhere in this cloud is a rock the chart says is a hundred metres across.",
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
						return {text = "You stop, kill the drive, and let the dish listen. Over half an hour the gas thins in one direction just enough to show a star, and then a second one, and that is a fix. On the way out along the new heading you pass a hull the cloud has been hiding for years, and you take what is loose off it.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						return {text = "It takes an hour of listening and two false starts, and then two stars at once, and a heading. You burn out on it and it is right. The gas thins, and there is the lane."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 14)
						return {text = "You get one star and guess the second. The heading is out by ten degrees, which you find out slowly, over two hours of burning in the wrong direction. You come out of the gas a long way from where you meant to."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.take_hull_damage(OptionTable.toll(4), "Burned on a bad fix, in gas, into a rock the chart had marked.")
						return {text = "You get a fix and trust it and burn. The rock is where the chart said. The chart was right about the rock, and wrong about where you were."}},
				{label = "Burn straight up out of the plane", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You burn straight up, at right angles to the lane, and keep burning until the gas thins and the stars come back. It costs fuel to leave the lane and more to come back down to it. Coming back down, you find a marker somebody left at the edge of the gas, with a supply case tied to it for whoever was lost next.", material = &"event"}},
				{label = "Wait for the gas to thin", stay = true, effect = func() -> Dictionary:
					return {text = "You kill the drive and wait, because clouds move. Two days of listening to nothing, and then a thin place goes by and there are stars in it, and you go. It costs nothing but the two days."}},
			],
		},
		{
			id = &"the_dark_ship",
			title = "The dark ship",
			body = "Three kilometres off the lane, in gas thick enough to hide it from any dish but one looking straight at it, a ship is sitting dark. No transponder, no drive, no heat, and it has been there long enough to gather frost. Either it is dead and nobody has found it, or it is alive and does not want to be found, and from here there is no telling which. A ship hiding that well is hiding from something. A ship that dead is worth a great deal to whoever gets there first.",
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
						return {text = "It is dead, and has been for years: frost inside as well as out, and a hold that was full when it stopped. Nobody has been here first. You take the best of it and log the rest.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						return {text = "It is dead, and it is cold enough that the cutter takes twice as long as it should, and the fuel goes on holding station in gas that will not sit still. What you get is worth it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						return {text = "It is alive, and it lights its drive when you are two hundred metres off and goes, fast, deeper into the cloud, and you spend a lot of fuel getting clear of its wake. You never see who."},
					botched = func() -> Dictionary:
						Run.heat += 8
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a dark ship in the gas, and it was not dead.")
						return {text = "It is alive, and it does not leave quietly. Something hits your flank on its way past, a warning or not, and then it is gone into the gas and you are alone with a hull that needs looking at."}},
				{label = "Watch it for a day", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "You hold off in the gas with everything down and watch it for a day. Nothing changes: no heat, no drift, no light. After a day you go closer, slowly, and take what is loose around it, and do not go alongside. It costs a day's fuel to hold still in moving gas.", material = &"wreck"}},
				{label = "Leave it in the dark", stay = true, effect = func() -> Dictionary:
					return {text = "You go on along the lane and say nothing about it on the channel. If it is hiding, it is still hidden. If it is dead, it will keep."}},
			],
		},
		{
			id = &"the_scoop",
			title = "The scoop",
			body = "The giant fills the sky ahead, banded and slow, and its upper air is fuel. Every ship that has ever come through here has dipped into it. Get low enough and the intakes fill themselves. Get too low and the air is thick enough to drag you in and hot enough to strip the plating on the way. The trick is the angle. Skim, and you come out with a tank you did not pay for. Dive, and you come out with more, or you do not come out.",
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
						return {text = "You take it in one long shallow pass, the nose glowing, the intakes roaring the whole way through, and come out the far side climbing with the tank twenty units fuller than it went in."},
					clean = func() -> Dictionary:
						Run.fuel += 12
						Run.heat += 8
						return {text = "You go in a little steep and come out a little hot. The tank takes twelve units. The hull takes an hour to cool, and you spend the hour climbing."},
					partial = func() -> Dictionary:
						Run.fuel += 4
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(2), "Skipped off the top of a gas giant's air, twice, and the second one was hard.")
						return {text = "You skip off the air like a stone off water, twice, and the second skip is a hard one. Four units, a hot ship, and a dent."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Went into the giant's air too steep, and the air kept the difference.")
						return {text = "You go in too steep and the air grabs you. Ninety seconds of the hull screaming and the intakes full of fire, and then you are out, climbing on the last of the burn, with no more fuel than you went in with and a good deal less plating."}},
				{label = "Skim high and slow", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 8
					return {text = "You keep to the very top of the air, where it is thin and the intakes take a long time to fill. An hour of skimming for eight units, and the ship warm all the way through by the end of it."}},
				{label = "Leave the air alone", stay = true, effect = func() -> Dictionary:
					return {text = "You keep your altitude and go around. It will still be here, and so will its air, whenever you come back with a bigger reason."}},
			],
		},
		{
			id = &"the_breaking_moon",
			title = "The breaking moon",
			body = "The giant's innermost moon is coming apart. It has been in too close for too long, and the pull of the planet is stronger on its near side than its far side, and the difference is tearing it. Cracks a kilometre wide run across the surface. Sheets of crust lift off the near side and drift, and behind them is the inside of a moon, dark metal that was never seen or mined, hanging in space at the end of a slow tide. There is a fortune here, and a moon coming apart around it.",
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
						return {text = "You go in slow between the lifted sheets with the cutter running, and come out the other side with a hold of what the moon was made of. Nothing touches you. Behind you a piece of crust the size of a station turns over, slowly, where you were.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Clipped by a piece of a breaking moon.")
						return {text = "You get the hold filled, and a piece of the moon gets your flank on the way out. Not hard, but hard enough to hear from the board and to need looking at.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Spent a pass through a breaking moon avoiding it instead of cutting it.")
						return {text = "A sheet turns over faster than it should and you spend the pass avoiding it instead of cutting. You come out with a scraped hull and an empty hold."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(4), "Caught between two pieces of a breaking moon.")
						return {text = "Two sheets close with the ship between them. You burn out from between them with the hull grinding on both sides, and you do not stop burning until the moon is a long way behind."}},
				{label = "Take what drifts clear", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 9)
					return {text = "You sit a safe distance out and let the moon come to you. Every few hours a piece of the inside drifts clear of the sheets, and you take the best one with the grapple. It costs fuel to hold station off a moon that is pulling itself apart, and it takes a day, and it is safe.", material = &"mining"}},
				{label = "Leave the moon to it", stay = true, effect = func() -> Dictionary:
					return {text = "It has been breaking for a thousand years. It will be breaking for a thousand more, and there will be more of the inside showing every time you pass."}},
			],
		},
		{
			id = &"the_rings",
			title = "The rings",
			body = "The giant has rings, and the rings have been catching things since before anybody came here. Ice and rock, mostly, a few metres thick and a hundred thousand kilometres across, flat as a table. Anything that comes into orbit here at the wrong angle ends up in the plane of the rings sooner or later, going around with everything else. The dish counts eleven hulls in the near arc alone. Getting to one means flying in the plane, at ring speed, with ice going past on every side.",
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
						return {text = "You match the ring's speed and fly with it, and once you are moving with it the ice is not going past at all. It is just there, hanging, and you pick your way between it. The nearest hull is a freighter, whole, that has been going around with the ice for a long time.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "A piece of ring ice, at ring speed.")
						return {text = "You get to the freighter with one knock on the way in and one on the way out, both from ice you never saw. The hold is worth both.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get into the plane and cannot hold it. The ice keeps finding you, and you climb out hot and empty before it finds you properly."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Came into the ring plane at the wrong speed.")
						return {text = "You come into the plane at the wrong speed. It is only a few metres a second of difference, and at ring speed that is enough. Ice, a lot of it, and then you are out of the plane and the ship is quiet in the way ships go quiet when a lot of things have stopped working at once."}},
				{label = "Hold above the plane and fish", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 8)
					return {text = "You hold just above the ring, matching its speed, and drop the grapple into it on a long line, and pull up what it catches. Mostly ice, and once something better, off a hull you never see. It costs fuel to hold above a ring for a day.", material = &"wreck"}},
				{label = "Leave the rings alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log the eleven hulls and go on. They have been going around for years, and they are not going anywhere else. Somebody with more time will come for them."}},
			],
		},
		{
			id = &"the_sunken_freighter",
			title = "The sunken freighter",
			body = "A freighter went into the giant's air eleven years ago and did not come out. It should have been crushed, but it was built for pressure, a gas-mining hull thick as a vault door, and it is still down there, floating at the depth where the air is dense enough to hold it up, going slowly around the planet with the wind. Its transponder still works. Its cargo is still aboard. The air at that depth would crush your ship in about twenty minutes, and it is hot enough to cook it in ten.",
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
						return {text = "You go down through the bands with the pressure climbing the whole way, and find it where the transponder said, hanging in the dark air with its running lights still on. In eight minutes alongside, the cutter gets a hold open and the grapple gets the best of it, and you climb out with the hull creaking.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Twelve minutes at a depth that gives you ten.")
						return {text = "Twelve minutes at depth, which is two too many. The plating comes up with a dent in every panel, and the grapple comes up with the one thing it could reach.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Went down to crushing depth, and came up with nothing.")
						return {text = "You get down to it, but the plating starts to give before the cutter has finished, and you have to climb. You bring up nothing but a hull that has been squeezed."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went down to a freighter at crushing depth, and came up too slowly.")
						return {text = "You go down and the air takes hold of you the way it took hold of the freighter, and for a while it is not clear you are coming up. You do, on the last of the burn, and everything on the outside of the ship has been pushed a little way in."}},
				{label = "Fish for it from above", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You hold at the top of the air and drop the grapple on its longest line. Somebody left a hold open before they left. It takes a day of dropping and pulling to hook anything, and it costs fuel to hold station in the wind, and what comes up is what was nearest the door.", material = &"wreck"}},
				{label = "Leave it down there", stay = true, effect = func() -> Dictionary:
					return {text = "It has been going around for eleven years. It will go around a good while longer, slowly getting lower, until one day it does not."}},
			],
		},
		{
			id = &"the_storm",
			title = "The storm",
			body = "There is a storm on the giant the size of a small continent, and there is a ship in it. A mining tender, drives dead, being carried around the planet by wind at six hundred kilometres an hour. Three aboard. They call on the open channel every time the storm brings them up into range, and then the storm takes them down again and the channel goes quiet for an hour. They have been going around for two days. Their pressure hull is good for another one, they think. They will pay anything for a line.",
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
						return {text = "You go into the top of the storm with the tender's beacon on the dish and match the wind, which means flying at six hundred kilometres an hour through air that wants you lower. The grapple takes them on the second pass. You climb out together, slowly, and the three of them pay everything they said they would."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "Four passes into a storm on a gas giant, for three strangers.")
						return {text = "It takes four passes, and the storm gets a proper hold of you on the third. You come out with the tender on the line and your plating scored from nose to tail, and they pay in full."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Two lines into a storm on a gas giant, and the storm kept most of the second.")
						return {text = "You get a line on them and lose it, and get it again, and the second time it holds long enough to drag them up to where their own thrusters can hold altitude. They finish the climb themselves. They pay what they can, which is less than they said."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went into a storm on a gas giant after three strangers, and the storm did not care which ship it kept.")
						return {text = "You go in after them and the storm takes you the way it took them. An hour of being carried around the planet with the hull groaning, and then a gap, and you burn up through it with nothing on the line. They are still down there, still calling."}},
				{label = "Wait for the storm to bring them up", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You hold above the storm for a day, burning fuel to stay put in a wind that reaches up even here, and wait for it to lift them into range. It does, twice. The second time you get a line on them without going in. Once they are out they pay less than they promised while they were still in there. You did not have to go into the storm for it, so you do not argue."}},
				{label = "Leave them to the storm", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them you cannot, and they say they understand. The storm takes them down again. An hour later they are calling again, to anybody, and you are out of range."}},
			],
		},
		{
			id = &"dead_boards",
			title = "Dead boards",
			body = "There is a pulsar two systems over, and its beam reaches here every fourteen seconds. At this distance it is too weak to hurt a hull. It is not too weak to kill a circuit board that was not built for it, and most of them were not. A hauler in the lane ahead has found this out. Its controls are dead, its drive is stuck on the last setting anybody gave it, and it is sliding slowly toward the one part of the system where the beam is strong enough to matter. Two aboard. They are calling for a tow.",
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
						return {text = "You get a line on them and pull them across the beam's track and out of it, which takes an hour and every bit of thrust you have. Once they are clear their boards come back one at a time, the way things do when the thing killing them stops. They pay in full and ask what you are shielded with."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "The tow takes two hours and the line parts twice. They are out of the beam by the end of it, and their boards are coming back, and you are hot from the pulling. They pay what they offered."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get them moving the right way and then the line parts for good. They are drifting out of the beam now instead of into it, slowly, and they will be clear in a day. They pay you for the direction."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Towed a hauler with a stuck drive, and the hauler towed back.")
						return {text = "The line comes tight while they are still under power on the old setting, and the two ships fight each other for a minute. Your hull comes off worse. They are no better off than they were, and nobody pays."}},
				{label = "Sit between them and the beam", effect = func() -> Dictionary:
					Run.heat += 14
					Run.add_credits(OptionTable.purse(18))
					return {text = "You put your ship in the beam's path with theirs behind it. Your hull takes the beam every fourteen seconds for the two hours it takes them to work around the dead boards, and it warms the whole way through. They pay less than for a tow, because in the end all they needed was something to sit in the beam's way."}},
				{label = "Leave them to the beam", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck. They have a day before the beam is strong enough to matter, and a day is long enough for someone else to come through, or for them to find a way around the boards themselves."}},
			],
		},
		{
			id = &"the_glass_ring",
			title = "The glass ring",
			body = "An old station ring hangs in the lane, dead for longer than anybody has records, and the beam has been sweeping it every four seconds the whole time. Four seconds of pulsar, four seconds at a time, for centuries, leaves something on a hull: a glaze, thick as plate, in colours that do not have names. It is worth a great deal to the right buyer. The beam also comes around once every ninety minutes at an angle that misses the ring, and stays missing for six minutes. Six minutes is what you have.",
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
						return {text = "You go in on the first second of the gap and out on the last, with the cutter running the whole way. What you bring back is a plate of the glaze, still warm, and a piece of the ring that came away under it. Nothing else here has ever been touched.", material_id = &"sweep_glass", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "Six minutes is not enough and you take seven, and the seventh is in the beam. You are out before it can do more than heat you. The glaze is aboard, and so is a piece of the ring.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You are still finding the angle when the gap closes, and you leave with a piece of the ring's frame and a hull that has had a second of pulsar on it, which is a second too long.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 28
						Run.take_hull_damage(OptionTable.toll(4), "Took a full sweep of the beam alongside the glass ring.")
						return {text = "You misjudge the gap by a full sweep. Four seconds of the beam at this range is not a thing a ship is built for, and it goes through you the way it has been going through the ring, and leaves you nothing but heat."}},
				{label = "Take frame from the shadow side", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "You never go near the glaze. The ring throws its own shadow, and in it are pieces of the frame that fell clear of the beam's line a long time ago. Holding in a shadow that moves with the ring costs fuel, and what you take is plain metal, and it is safe.", material = &"wreck"}},
				{label = "Leave it to the beam", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ring and the gap, both, for somebody with a faster ship. The glaze will be a little thicker by the time they get here."}},
			],
		},
		{
			id = &"the_drop_point",
			title = "The drop point",
			body = "This pulsar is a slow one. Its beam comes around once every thirty-one minutes, and at this range one sweep is enough to finish a ship. So everything here lives on a thirty-one-minute clock. Behind a rock the size of a city, in the one shadow the beam never reaches, people have been leaving things for other people for a very long time: crates, tanks, sealed cargo, stacked and tethered and never collected. Nobody guards it except the beam. Getting into the shadow and out again with a load is thirty-one minutes of open sky, at most, and less if you are slow.",
			tags = [&"salvage", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Run for the shadow",
					check = {attr = &"thrust", need = 8},
					met = func() -> Dictionary:
						return {text = "You go the second the beam has passed and are in the shadow with twenty minutes to spare. The stack is deeper than it looked from outside. You take a sealed unit off the top and a crate from under it, and you are back across the open with four minutes left, and the beam comes around behind you.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "You are slower across the open than you meant to be, and slower still coming back, and the edge of the beam catches your stern as you clear it. You get one crate and a hot ship, with twenty-nine minutes gone on a thirty-one-minute clock.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(2), "Turned back halfway to the shadow, and the beam caught the turn.")
						return {text = "You are halfway across when the count says you will not make the shadow and back in time, so you turn around. The beam catches you turning. You come out of it with nothing, and with less hull than you went in with."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "Caught in the open by a thirty-one-minute pulsar, on minute thirty-one.")
						return {text = "You misjudge the clock. The beam finds you in the open at minute thirty-one, and the things it does to ships it does to yours, and then it has passed, and you are drifting at the shadow's edge in a ship that is mostly still there."}},
				{label = "Hook what you can from the edge", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You hold at the edge of the shadow with the beam's line a hundred metres off your bow, and put the grapple in on a long cable. It takes three sweeps of waiting and burning to stay put, and what comes out on the cable is what was nearest the edge, which is what somebody else did not want badly.", material = &"wreck"}},
				{label = "Leave it to the clock", stay = true, effect = func() -> Dictionary:
					return {text = "You log the rock and the interval and go. Whatever is behind it has been waiting a long time, and the beam is not going anywhere."}},
			],
		},
		{
			id = &"the_quiet_beam",
			title = "The quiet beam",
			body = "The pulsar has stopped. Two days ago the beam that has swept this system every second and a half for as long as anyone has been counting simply did not come around, and it has not come around since. Nobody knows why. It has happened before, to other pulsars, and every time it has started again, in an hour or a month, without warning. In the meantime every hull that has sat in the beam's path for centuries is reachable, glazed thick with what the beam leaves, and every ship within a week is coming for them. The first ones are already here.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Work until the last minute",
					check = {attr = &"sensors", need = 8},
					met = func() -> Dictionary:
						return {text = "You put the dish on the pulsar itself and watch it the whole time you work, and it is the dish that tells you, six hours in, that the spin is coming back into line. You leave with a plate of the glaze and a whole sealed unit off the nearest hull, and you are eleven minutes clear when the beam comes around.", material_id = &"sweep_glass", module = true},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "You read the pulsar right and cut it fine, and the first sweep catches your stern as you clear the lane. A plate of glaze and a piece of hull, and a ship that will spend the day cooling.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 20
						return {text = "You cannot make sense of the pulsar's spin on the dish, and you do not trust it, so you take one piece off the nearest hull and go early. The beam comes back four hours later. You were right not to trust it. You are also carrying a piece of hull instead of a fortune.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 32
						Run.take_hull_damage(OptionTable.toll(4), "Working a glassed hull when the beam came back.")
						return {text = "You are still working when the beam comes around. There is no warning, only a second and a half of it, and then another, and you are out of the lane before the third, with everything on the outside of the ship a different colour than it was."}},
				{label = "Take what is nearest and go", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					return {text = "You do not read the pulsar. You take the first thing the grapple can reach off the nearest hull and burn out of the lane, and keep burning until the beam's track is far behind you. Whether it comes back in an hour or a month, it will not find you in it.", material = &"wreck"}},
				{label = "Stay out of the lane", stay = true, effect = func() -> Dictionary:
					return {text = "You watch the others go in from a long way off, and you keep the dish on the pulsar, and you do not go in. Whether they get out before it starts again is their business."}},
			],
		},
		{
			id = &"the_crossing",
			title = "The crossing",
			body = "A herd is crossing the lane. Hundreds of them, slow, packed close, the small ones in the middle and the old ones on the outside, and the whole mass of them moving at walking pace across the exact stretch of sky you need to be in. They are not hostile. They are also not going to move for you, or notice you, and the smallest of them is the size of a hauler. Going around is a day. Going through is an hour, if nothing turns.",
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
						return {text = "You go through at their speed, which is the only speed that works, and none of them so much as turn. Halfway across, an old one on the outside sheds a sheet of hide the size of your ship, and you take it on the way past.", material_id = &"hide_scrap"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "It takes two hours and a great deal of correcting, and one of the young ones follows you part of the way, curious. Something that came off one of them drifts against the hull as you clear the far side, and you keep it.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Brushed by the flank of something the size of a hauler.")
						return {text = "One turns, not at you, just the way something that size turns, and its flank comes across your bow and takes the paint off. You are through, with nothing to show for it but the scrape."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Between two of them when they closed.")
						return {text = "Two of them close, slowly, with you between. You back out of the gap with the hull grinding on both sides, and go around after all, which costs the day as well."}},
				{label = "Follow the old ones around the edge", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 10)
					return {text = "The old ones keep to the outside, and the old ones shed. You follow the edge of the herd for a day, at their pace, and take the one good piece that drops. It costs fuel to fly slowly for a day, and the herd does not mind you doing it.", material = &"fauna"}},
				{label = "Wait for them to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the lane and watch them go by for most of a day. It costs nothing but the day, and it is not a bad way to spend one."}},
			],
		},
		{
			id = &"the_hunters",
			title = "The hunters",
			body = "A hunting ship has made a kill, one of the big ones, the size of a station, dead in the lane with the hunter alongside cutting it. The hunter is a small ship and the body is not, and they are working fast, because the pod is two hours out and coming back. They want the body towed to their tender before that happens, and they will pay for the tow. They will also sell a share of it, cheap, to anyone who would rather not be here when the pod arrives either.",
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
						return {text = "It is the heaviest thing you have ever had on a line, and it moves the way heavy things move, slowly and then all at once. You get it to the tender with forty minutes to spare. They pay in full and start cutting again before the line is off."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes everything the drive has and most of the two hours. The tender has the body under its cutters before the pod is on the dish. They pay what they said."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The line holds and the body barely moves. You get it half the distance before the pod shows on the dish, and the hunters cut it loose and run, and pay you for the half."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Towing a dead one when the pod came back.")
						return {text = "The pod arrives while the body is still on your line, and the first of them comes past close and slow to see what you are doing, and its flank takes your hull the way a wall takes a door. It is not hostile, only not paying attention. The hunters are gone, and nobody pays."}},
				{label = "Buy a share", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "They cut you a share off the flank while the line is still going on, and take your money, and you are gone before the pod is on the dish. It is the cheapest anyone will ever sell you this, because of what is two hours out.", material = &"fauna"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck and go. Two hours is enough for a fast ship to be somewhere else, and you intend to be. What the pod finds when it gets here is between the pod and the hunters."}},
			],
		},
		{
			id = &"the_singer",
			title = "The singer",
			body = "One of them is alone, and it is singing. It is old, the size of a station and scarred along its whole leading edge, and its song is loud enough on every channel to white out the dish for a hundred kilometres around. The others are gone. It is not going anywhere. Whatever is wrong with it is slow, and you can hear it in the song. Someone on a hunting ship two days out has been asking on the channel for exactly this, a singer alone, and will pay for the bearing. Rendered, it is worth more than your ship. Alive, it is a wonder, and it is dying either way.",
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
						return {text = "You go in slow, inside its song, close enough to see the scars. It knows you are there and does not care. What it sheds as it drifts is worth a great deal, a sheet of hide and something smaller that came away with it, and you take both, and it keeps singing.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get close and it turns, slowly, the way something that size turns, and you spend the next hour staying out of the way of it. What you take is what came loose in the turning.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Alongside a singer when it turned.")
						return {text = "It turns, not at you, just turns, and you are in the way of it. You come away with a scraped hull and nothing else, and it goes on singing."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "Alongside a singer when it rolled.")
						return {text = "You are close alongside when it rolls. There is no anger in it. There is a great deal of weight in it, and for a moment your ship is between that weight and nothing, and then it is past. You come away with nothing, and with a hull that will need a yard."}},
				{label = "Sell the bearing", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(20))
					return {text = "You give the hunting ship the bearing, and they pay for it before you have finished reading it out. Two days from now they will be here, and the song will stop. You will be a long way off by then, and you will not hear it stop."}},
				{label = "Leave it singing", stay = true, effect = func() -> Dictionary:
					return {text = "You go, and the song follows you out on every channel for a hundred kilometres, and then it is behind you, and then it is gone. It will go on singing for weeks, most likely, alone, and nobody will have heard it from you."}},
			],
		},
		{
			id = &"turning_the_herd",
			title = "Turning the herd",
			body = "A herd is moving toward the station's approach lane, two hundred of them, slow and not paying attention, and a small ship is trying to turn them. One person aboard, running every light she has along the near flank, and it is not enough. If the herd reaches the lane, everything inbound for a week goes around it or through it. She is asking anyone on the channel to take the far flank: lights on, drive loud, and turn with her. The station will pay her, she says, and she will pay you.",
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
						return {text = "You run the far flank with every light on and the drive at full noise, and the herd leans away from you the way a crowd leans away from a loud thing, slowly and all together, and then it is turning. An hour later the lane is clear and the herd is going somewhere else. She pays you before the station has paid her."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes three hours, and the drive is hot from being loud that long. Most of them turn. Two old slow ones keep going, and two is few enough that the station can route its ships around them. She pays what she offered."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get half of them turned and the other half go through anyway, at their own pace, and the lane is a mess for a week. She pays you for the half, and the station pays her for the half, and nobody is happy."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Too close to the flank of a herd when one of them turned the wrong way.")
						return {text = "You get too close to the flank and one of them turns the wrong way, toward the noise instead of away from it, and its side comes across your bow and takes a metre of plating with it. The herd goes into the lane behind it. Nobody pays."}},
				{label = "Make noise on the herd's channel", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "You do not fly the flank. You put the dish on the frequency they call to each other on and fill it with noise, and the herd does not like it, and leans away from where the noise is coming from. It is slower than a flank, and it heats the dish and everything behind it. They turn. She pays less than she offered for the flank, and says the noise was clever."}},
				{label = "Leave her to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish her luck and go. The herd is a day from the lane. That is long enough for her to think of something, or for the station to send a second ship, or for neither."}},
			],
		},
		{
			id = &"the_grazing",
			title = "The grazing",
			body = "The herd has stopped to feed. Forty of them hang around a body of dirty ice the size of a small moon, close together, mouths to the surface, and they will be there for days. Feeding, they shed: old hide, plates from their leading edges, things that come loose when something that size holds still. It drifts, and it is worth money. They are not hostile, and they are not paying attention, and a herd that is startled moves all at once, in every direction.",
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
						return {text = "You go in with the drive cold and the lights down and drift among them the way the ice drifts, and they never look up. A sheet of shed hide the size of your ship, and a plate of something harder off an old one's leading edge. You are out before any of them has finished a mouthful.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "One of them notices you and does not care. You get one good piece off the drift between them and leave before the others notice too, with the drive warmer than a quiet ship's should be.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Between three startled ones and the ice.")
						return {text = "One of the young ones startles, and the two beside it startle at that, and for a minute the herd is a wall moving in three directions. You back out with a scraped hull and nothing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "In the middle of a feeding herd when the whole herd startled.")
						return {text = "The whole herd startles at once. There is nowhere to go that they are not going, and for thirty seconds your ship is a small thing in a very large crowd, and then they are gone, and the hull has the shape of the crowd in it."}},
				{label = "Wait at the edge for what drifts out", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 9)
					return {text = "You hold a safe distance out and let the shed come to you for a day, and take the one piece worth taking. Holding station off an ice body with forty of them pulling at it costs fuel. What drifts furthest is the oldest, which is worth the least, and it is safe.", material = &"fauna"}},
				{label = "Leave them to feed", stay = true, effect = func() -> Dictionary:
					return {text = "You go around. They will be here for days, and in a week the ice will be a little smaller, the shed will be a little further out, and somebody else will have been through."}},
			],
		},
		{
			id = &"the_timekeeper",
			title = "The timekeeper",
			body = "There is a relay in this system that does one thing: it listens to the pulsar and broadcasts the tick, so every ship in the ring can set its clock by something that never drifts. An old technician runs it alone. The relay's antenna has to point straight at the pulsar to hear it. The motor that turns the antenna has burned out, and the antenna is now pointing at empty sky, a few degrees off. He cannot go outside to turn it. He wants a ship to put the grapple on the antenna's mount and turn it back toward the pulsar, a degree at a time, while he listens for the signal.",
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
						return {text = "You put the grapple on the mount and turn the antenna in degrees, and then in tenths of a degree, with the old technician calling the signal strength over the channel. It takes an hour. The tick comes back all at once, clean, and every ship in the ring that is listening gets its clock back. He pays what he has, which is more than you expected."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						Run.heat += 6
						return {text = "It takes three hours, because the mount sticks, and the drive runs hot holding position that finely for that long. The tick comes back. He pays what he offered."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 6)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You get the antenna close enough that he can hear the pulsar faintly, and not close enough to broadcast a clean tick. He can finish the last degree himself, slowly, once he has rigged a spare motor. He pays you for getting him most of the way."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A relay antenna, swinging, when its mount gave way under the grapple.")
						return {text = "The mount gives way under the grapple and the antenna swings, and your hull is where it stops. It is further off the pulsar than it was. He does not say anything for a while, and then he says it is not your fault."}},
				{label = "Broadcast the tick yourself", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "Your dish is on the pulsar already. You put the tick on his frequency at his power, and for the six hours it takes him to rig a spare motor and turn the antenna himself, you are the relay. It heats the dish and everything behind it. He pays for six hours of being a clock, which is less than he offered for the turning."}},
				{label = "Leave him to his clock", stay = true, effect = func() -> Dictionary:
					return {text = "You give him the time off your own board and go. The ring will drift a little more. Somebody will come through who has the patience for it."}},
			],
		},
		{
			id = &"thin_glaze",
			title = "Thin glaze",
			body = "The beam from the pulsar reaches here every six seconds, faint enough that most ships never notice it. It has been reaching here for a very long time. A debris field hangs in its track, old markers, dead satellites, pieces of things that broke up in the lane, and every piece has a thin skin of what the beam leaves, a glaze in colours the dish cannot name. Thin on one piece, and on a hundred pieces not thin at all. Collecting it means a slow pass through a field of sharp metal, taking hits the whole way.",
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
						return {text = "You go through slow with the grapple out and the hull taking the small stuff, and scrape as you go. After three hours, what comes out of the field is a plate of the glaze, a hundred thin pieces pressed together, and the ship rings for an hour afterwards.", material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Three hours in a field of sharp metal, scraping glaze.")
						return {text = "You get the glaze, and the field gets a piece of your plating for it. Something in the middle of the field hits harder than anything in it should have.", material_id = &"sweep_glass"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Halfway through a debris field, avoiding instead of scraping.")
						return {text = "Halfway through the field you stop scraping and start avoiding, and you come out with a dented hull and one piece of somebody's old satellite, with no glaze worth the name on it.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Broadsided in a debris field by a piece nobody had seen move.")
						return {text = "A piece the size of a door comes out of the field faster than anything in it has a right to move, and takes the hull broadside. You leave the way you came in, with nothing."}},
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
			body = "Every ship that comes this deep does the same arithmetic, and this is where the arithmetic turns: from here, a full tank gets you home, and anything less does not. Somebody painted the numbers on a rock, big enough to read from the approach, years ago. Around the rock are the ships that read them too late. Thirty or forty hulls, all pointed outward, all with their tanks run dry a day or a week short of anywhere. Their holds are still full. Fuel is the only thing they ran out of.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Read every tank on the dish",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 24
						return {text = "Forty hulls, forty tanks, and one of them is not empty: a hauler that made the turn with fuel to spare and died of something else. You take its fuel through the transfer line, and one thing out of its hold, and leave the rest of the field as you found it.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel += 12
						Run.heat += 10
						return {text = "Two hours of reading tanks, most of them dry, and then one with a few units left in the bottom. You get twelve units out of it, and the dish is hot from the reading."},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "Every tank reads dry. You take one thing out of one hold, because you are here, and the dish is hot from three hours of finding nothing.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "A dry tank that was not dry, on a hull that turned back too late.")
						return {text = "One of the tanks is not dry, and what is in it is not fuel either. Something a hauler was carrying has sat in the cold for years, and it goes when the transfer line opens. The hull takes it on the flank. You come away with nothing but the scorch."}},
				{label = "Work the nearest holds", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 12)
					return {text = "You skip the tanks and go hull to hull at a crawl, which costs fuel, and take the best thing out of the nearest three holds. They were full when they stopped, and they are still full apart from what you take.", material = &"wreck"}},
				{label = "Do your own arithmetic and go", stay = true, effect = func() -> Dictionary:
					return {text = "You read the numbers on the rock, read your own tank, and go on while the numbers are still on your side. The hulls have been here for years, and nothing this deep is going to move them."}},
			],
		},
		{
			id = &"the_fuel_cache",
			title = "The fuel cache",
			body = "Six fuel tanks on a tether, marked with a ship's name and a date eleven months old, parked where anybody coming out from the core would pass them. Somebody left their way home here. They went inward with a lighter ship and a plan to come back for this, and they have not come back yet. Eleven months is a long time this deep, but people have come back from longer. The tanks are full, the valves have been in the cold for eleven months, and there is nothing to stop you except the name painted on them.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Take all six",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 30
						return {text = "You warm the valves one at a time and take all six, thirty units in all. Whoever painted their name on these has a lighter ship and a plan, and the plan now has six fewer tanks in it. Nobody will know for months."},
					clean = func() -> Dictionary:
						Run.fuel += 18
						Run.heat += 10
						return {text = "Four of the valves come free and two do not, and the ship runs hot from warming them. You get eighteen units and leave two tanks on the tether with the name still on them, which is not enough to get anybody home."},
					partial = func() -> Dictionary:
						Run.fuel += 6
						Run.take_hull_damage(OptionTable.toll(2), "A frozen fuel valve, opened too fast.")
						return {text = "The first valve lets go before it is warm, and the tank empties itself across your flank. You take six units from the second one, slowly, and stop."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A frozen fuel valve, eleven months in the cold, opened too fast.")
						return {text = "The tank comes apart against the hull when the valve goes. Fuel everywhere, none of it in your tank, and a dent from bow to midships. You leave the other five where they are."}},
				{label = "Take two and leave four", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 12
					return {text = "You take two tanks, slowly, warming the valves the long way, and leave four on the tether with the name still on them. Four is enough to get a lighter ship home from the core, if the pilot is careful."}},
				{label = "Leave them their way home", stay = true, effect = func() -> Dictionary:
					return {text = "You log the name and the date and go. Whoever they are, they are either dead already or they are going to want these very badly. You leave them their tanks."}},
			],
		},
		{
			id = &"three_years_in",
			title = "Three years in",
			body = "A survey ship is holding station here with four people aboard who have been counting things for three years. A company sent them: map the approach, log the traffic, report every ninety days. They have reported every ninety days. Nobody has answered in two years, and nobody has paid them in two and a half, and they are still at it, because the alternative is going home to find out why. Their long-range receiver has been dead for as long as the silence has. They want news, they want fuel, and they have three years of measurements to trade for either.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Fix their receiver",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You find the fault in forty minutes, a board that died two years ago and never told anyone, and when the receiver comes back so do two years of messages, all at once. The company folded eighteen months ago. They pay you from the ship's account, which is theirs now, and give you the three years of measurements, and nobody says much for a while.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes half a day to find the fault, and when the receiver comes back it brings eighteen months of messages and then stops, which is enough. They pay you what they can spare and give you the measurements.", archive_recover = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 10
						return {text = "You get their receiver hearing the near channels and not the far ones. It is enough to know the company is not answering, and not enough to know why. They pay for the attempt, and go back to their instruments."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(3), "A survey ship's power bus, through the connecting line.")
						return {text = "You run the fault down into their power bus and the bus goes. Their ship is dark for an hour, and yours takes a jolt through the connecting line that scorches a metre of plating. Their receiver is no better than it was. Nobody pays."}},
				{label = "Trade fuel for the measurements", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					return {text = "You give them fourteen units, and they give you three years of the approach, every hull that went inward and every one that came back, on film and in the log, and a case of the company's rations, which is what they have plenty of. They ask for news. You give them what you have, and it is not much.", archive_recover = true, material_id = &"survey_film", material = &"event"}},
				{label = "Leave them to their survey", stay = true, effect = func() -> Dictionary:
					return {text = "You give them what news you have on the channel and go. They thank you and go back to their instruments. The next report is due in forty days, and they will send it."}},
			],
		},
		{
			id = &"still_inbound",
			title = "Still inbound",
			body = "Six haulers are crossing the system in formation, drives lit, at a crawl. They have been crossing it for a long time: the dish puts their speed at a few metres a second and their heading at the core. Nobody answers. The hulls are cold on every band but the drives. A convoy set on automatic a long time ago by people who are long dead, still going where they were told. Their holds are sealed. Working them means matching a speed that is not quite zero and cutting on the move, inside a formation that still corrects itself.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match them and cut",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						return {text = "You match the crawl and slide in among them, and they do not notice, because there is nothing left aboard to notice. Two hours alongside the lead hauler gets you a sealed unit out of its rack and a crate from its hold, and then you fall back and let the six of them go on without you.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You match the speed and lose it twice, and the cutter runs hot from starting and stopping. You get one crate out of the last hauler in the line.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The formation shifts, one hauler correcting for another, and you spend the pass staying out of the way of six ships that do not know you are there. You come away with nothing, and hot from the dodging."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "In the gap between two haulers of a dead convoy when one of them corrected.")
						return {text = "You match the wrong hauler. The one behind it corrects into the gap you are in, slowly, and there is nowhere to go that is not a hull. It takes your flank and keeps going, at a few metres a second, toward the core."}},
				{label = "Pace them for a day", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					return {text = "You hold a kilometre off instead of going alongside, and match their crawl for a day, and take the one good piece that comes loose off six old hulls still shaking from their own drives. It costs a day's fuel to fly that slowly.", material = &"wreck"}},
				{label = "Let them go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the heading and the speed and let them go. At that speed they have years yet before they reach anything, and they are not going to turn."}},
			],
		},
		{
			id = &"the_pilgrims",
			title = "The pilgrims",
			body = "Nine people on a ship built for four are going to the core, and they know what that means, and they are going anyway. They are polite about it. Nobody aboard is asking to be talked out of it, and their drive is fine. What they want is fuel, because enough to get there is not enough to be sure of it, and they will pay whatever you ask, because they will not need the money after. They also ask, carefully, whether you would fly with them for the first day, and they will pay for that too.",
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
						return {text = "You turn back at midday. Your plating is reading things a day would not undo, and you say so, and they understand, and pay you for the half day. They go on without you."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.take_hull_damage(OptionTable.toll(4), "Flew a day inward with nine strangers, and hit something that was not on the chart.")
						return {text = "Half a day in, something that is not on the chart takes a piece of your flank, and you burn hard coming back out. They pay nothing, since you were the one who turned around."}},
				{label = "Sell them fuel", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 18)
					Run.add_credits(OptionTable.purse(30))
					return {text = "You sell them eighteen units at a price they do not argue with. They would not have argued with any price. They thank you, and fill their tanks, and go inward, and you watch them on the dish until the dish loses them."}},
				{label = "Decline and go", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them no, and they are polite about that too. They will wait for the next ship, and another ship will come through eventually."}},
			],
		},
		{
			id = &"going_the_other_way",
			title = "Going the other way",
			body = "Every ship you have seen this deep was going in. This one is coming out. It is a long way off and moving fast, running hot, one drive of three lit, and it does not slow down when you hail it. It answers, though. A tired voice says it has no fuel to spare and no time to stop, and something aboard that is worth more than both, from further in than you have been, and it will trade some of that for fuel, if you can match its speed long enough to pass a line, because it is not stopping for anything.",
			tags = [&"signal", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match it and trade",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "You match a ship that is not slowing, close enough to pass a line, and hold there for six minutes while ten units go one way and a sealed case comes the other. The case holds a piece of equipment from further in than the chart goes. The voice tells you three things about the core while the line is connected, and then it is gone.", module = true, archive_recover = true},
					clean = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						return {text = "You hold the match for four minutes, which is long enough for the fuel and not quite long enough for what they meant to send. Something smaller comes across instead. The voice says one thing about the core, and it is gone.", archive_recover = true, material = &"event"},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.heat += 14
						return {text = "You get the line across and the fuel across, and then lose the match, and the line parts before anything comes back. They have your fuel. You have a hot drive from the chase, and a voice on the channel that says sorry, means it, and does not slow down."},
					botched = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 8)
						Run.take_hull_damage(OptionTable.toll(4), "Touched hulls with a ship that was not stopping.")
						return {text = "You get the match wrong and the two hulls touch, at a closing speed that touching was never meant for. They keep going. You spend fuel you did not plan to spend getting the drift off, and drift a while longer before anything on your board answers."}},
				{label = "Give them fuel and ask nothing", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 15)
					return {text = "You put fifteen units into a drop tank and leave it on their line, and they take it at speed without stopping, and the voice talks the whole time it is in range. What it says about the core goes in your archive.", archive_recover = true}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "You let it go. It is out of range in an hour, still running hot on one drive, still going the other way, and the channel is quiet again."}},
			],
		},
		{
			id = &"frost",
			title = "Frost",
			body = "A container ship has split a tank, and what was in the tank was cold: liquid gas, the kind that is only liquid because somebody worked hard to keep it that way. It is not liquid now. It is a cloud around the ship two kilometres across, and it freezes onto anything it touches. Frost a centimetre thick on every surface, including the radiators, which cannot shed heat through ice. The containers inside the cloud are intact. Working them means an hour in a cloud that will coat your vents in the first ten minutes.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Work through the frost",
					check = {attr = &"thermal", need = 8},
					met = func() -> Dictionary:
						return {text = "You run the radiators hot enough to shed the frost as fast as it forms, and go in. An hour in the cloud gets you a sealed unit and a container from the racks nearest the split, and you come out white from bow to stern and warm underneath.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "The vents ice over twice, and twice you back out to shed it and go back in. You get one container. The ship runs hot for a day afterwards, working the frost off.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						return {text = "Ten minutes in, the radiators are ice and the heat has nowhere to go, and you back out with nothing and a ship that has to sit for hours before it can shed what it is carrying."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "Iced radiators in a frost cloud, and a drive section that cooked from the inside.")
						return {text = "You stay in too long and the heat builds with nowhere to go. Something in the drive section gives up before the frost does. You come out of the cloud white, hot, and lighter by a piece of hull that stayed behind."}},
				{label = "Wait for the cloud to thin", effect = func() -> Dictionary:
					Run.fuel = maxi(0, Run.fuel - 14)
					return {text = "The cloud is spreading, slowly. You hold outside it for a day and a half, burning to stay put, and go in when it has thinned enough to work the outer racks without icing. You get one container, from the edge.", material = &"wreck"}},
				{label = "Leave it frozen", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ship and go around the cloud. In a month it will have spread thin enough for anybody, and somebody will have been through."}},
			],
		},
		{
			id = &"the_sleepers",
			title = "The sleepers",
			body = "A ship is drifting on the approach with twelve people aboard, and all twelve are asleep. Cold sleep, the long kind. They went down years ago with the ship set to wake them when help came, and help did not come, and the ship is still waiting. It is failing. The power that keeps them cold is running down. Its transponder carries a standing bounty for a tow toward any station, payable from the ship's own account, and the nearest station that could take them is nine days out in the direction you are not going.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Tow them out to where the traffic runs",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You take them a day outward to the route the traffic uses and leave them on it with their transponder loud. The ship pays you the bounty for the leg, since its account does not know the difference between a station and a day closer to one, and copies you its log. They are a day nearer to somebody going the right way, and still asleep.", archive_recover = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 10
						return {text = "The tow takes two days instead of one, and the drive is hot from the pull. You leave them where the traffic runs. The ship pays for the leg."},
					partial = func() -> Dictionary:
						Run.fuel = maxi(0, Run.fuel - 10)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get them half a day outward and the line parts. You burn an hour of fuel chasing down the loose end and reattaching it. Half a day is not far enough to matter, and the ship pays for half a day."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A sleeping ship, on a tow line, swinging.")
						return {text = "The tow line comes tight wrong and the ship swings into your flank, all of it, slowly. Nobody aboard wakes up, and nobody pays."}},
				{label = "Take what they will not miss", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "Their racks are full and their holds are full and none of the twelve will know. You take a sealed unit and a crate and leave the rest, and the ship's power runs down a little faster for the hour your cutter was in it.", module = true, material = &"wreck"}},
				{label = "Leave them sleeping", stay = true, effect = func() -> Dictionary:
					return {text = "You log the position and the bounty and go. Somebody heading for a station will pass here sooner or later, and the ship will still be asking."}},
			],
		},
	])
	return out
