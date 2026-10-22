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
##     subject = {stage = &"tether", pieces = [&"...tank_1"], count = 6},   # optional
## }
## ```
##
## `subject` IS WHAT LOCAL SHOWS while the event is open there (`LocalSubject`):
## kept pieces of art from `art/subjects/index.json` and how they are staged --
## one thing, a row, a tether, a field, a herd, a line, round a body, on a rock --
## with the counts the text gives ("six fuel tanks on a tether", "nine of them in
## a line"). Optional: an encounter without one keeps the scene as it is. Filled
## from the subjects audit (scratchpad `local_role/subjects.md`) wherever the
## subject has art Jon kept; the rest wait for theirs.
## Ships are named by what they are, not which picture: `role:hauler` is one of
## Jon's kept pool ships that serve as haulers, the same one for this encounter
## every time; `foe` is the ship the event's fight would bring, so the scene
## before a fight hands over to the fight's own ship.
##
## `foe = &"whale"` (or `&"leviathan"`) IS WHAT THE EVENT'S FIGHT BRINGS, when it
## is a creature: the one named, every time (`fight_foe`, `Router.option_foe`).
## With no `foe` an event's fight brings a ship off the ordinary pool, never a
## creature. Jon, Oct 17: an event's fight may bring megafauna, "but the text
## leading up to the fight should make sense" -- so the creature is a property
## of the TEXT, declared by the author beside it, and never rolled from the
## region: a whale cannot follow a body about pirates, and a ship cannot follow
## one about a whale. A creature event names its creature (a calf is not a
## leviathan), is fauna-gated (`needs_fauna`), and pays what animals pay: the
## body's exotic in its wreck, never credits off the animal. A choice may carry
## its own `foe`, which wins over the option's. `-- sheet=FoeTagTest` holds it.
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


## The creature a fight out of choice `c` of option `o` brings, or `&""` for a
## ship off the ordinary pool. The choice's own `foe` first, then the option's.
## Every door that starts an event's fight asks this and hands the answer to
## `Router.option_foe`: the drawer on LOCAL (through `OptionResolve.take`), the
## old detail view, and the simulator's `Policy`.
static func fight_foe(o: Dictionary, c: Dictionary = {}) -> StringName:
	return StringName(c.get("foe", o.get("foe", &"")))


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


## Whether this outcome's payload asks for a rolled MODULE (`module = true`),
## which `pay` puts on the system's pile.
##
## NOT WHETHER THE RESULT SHOWS REWARD, though it used to be. It was the one
## question the screens asked, and a part is not the only thing that lands on
## the pile: `material` and `material_id` are put there by `MaterialTable.grant`,
## and an effect that calls `Run.add_material` itself (`whale_fall`) puts them
## there with no key at all. Every one of those results said CONTINUE, dropped,
## and left the crate under SECTOR LOOT with nothing on the result to say so
## (Jon, Oct 22: "some quests don't show REWARD... that's super NOT
## intuitive"). The screens now ask what actually arrived on the pile
## (`OptionResolve.shows_reward`), which no payload form can slip past.
static func pays_item(res: Dictionary) -> bool:
	return bool(res.get("module", false))


## `src` is the option whose outcome this is: an outcome that places a quest
## (`place`) records it as the quest's giver, which the QUESTS table names.
static func pay(res: Dictionary, n: MapGen.MapNode, src: StringName = &"") -> String:
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
		var at := place(n, StringName(res.place), src)
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
	# ROLLS THE SYSTEM IF IT HAS NOT BEEN ROLLED, and the hellbender needs that:
	# it scans the whole map, so most systems it cares about are ones nobody has
	# flown to. (A contract board asked too, for a hunt's fight, until a hunt
	# brought its own target -- `Contracts.post_goal`.)
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
##
## AND IT IS WRITTEN DOWN (`Run.note_placed`): the system, the option and `src`,
## the option that placed it, so the QUESTS table can say who gave it. Only on
## the machine that took the event, which is the ship it belongs to: nothing
## here goes to the party.
const PLACE_DEPTH := 3

static func place(from: MapGen.MapNode, id: StringName, src: StringName = &"") -> int:
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
	Run.note_placed(at, id, src)
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
			# A CONTRACT'S EVENT IS NOT A THREAD. It is placed, never rolled,
			# but the chart already marks a signed job's system by the job
			# (`Run.contract_at`), and a second marker by the event's title
			# would say the one thing twice.
			if bool(o.get("placed", false)) and not bool(o.get("job", false)):
				_placed[StringName(o.id)] = true
	return _placed


## Whether this option is a signed contract's work (`Contracts.post_goal`):
## placed on one ship's map for that ship's contract, laid out past the
## system's own worlds (`SystemLayout`), and never raced for over the wire.
static func is_job(id: StringName) -> bool:
	return bool(by_id(id).get("job", false))


## WHETHER THIS OPTION IS ONE SHIP'S OWN: a signed contract's work (`is_job`)
## or an event quest (`placed_ids`, what `place` put on this ship's map for
## what this ship did). Neither is on a partner's map, so neither is raced for
## over the wire (`OptionResolve.take`, `Router.claim_open_option`), and a
## partner's claim on the same slot index never closes it
## (`RunState.adopt_party_claims`): the slot is theirs, not this.
##
## It was jobs only, and a taken PAID IN FULL went to the party as a claim on
## (system, slot), which a partner's machine wrote into its own copy of that
## system whatever sat there: their contract pickup or their own quest at the
## same index came up already taken (Oct 22).
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
		# AND A CLAIM PAST THE ROLLED LIST IS A PARTNER'S OWN OPTION (a job or
		# an event quest on their map, `is_mine`), adopted before this list
		# existed. Dropped, so what this ship's own `place` or `post_goal`
		# appends at that index next is not born taken.
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
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_1"], tumble = 2.0},
			body = "Two ships sit either side of a drifting cargo pod. Both have running lights on and weapons warm. Neither crew looks keen on a fight. They would rather be paid than shoot. Both are claiming the pod on the open channel. The pod's transponder log shows who dropped it. Your dish is the only one in range with no stake in the answer.",
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
						return {text = "The log is clear enough. The losing crew argues with you for a while. You have the timestamps on the channel, and in the end they stop."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The log is older than both ships, so neither crew owns the pod. You split it three ways, fast, before another ship turns up and wants a share."},
					botched = func() -> Dictionary:
						Run.add_credits(-20)
						return {text = "You call it for the wrong ship, and you sound sure of it. The right ship leaves with the pod, and you pay back your reading fee."}},
				{label = "Snatch it while they argue", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "You burn in and take the pod while both crews are shouting about it. They stop shouting at each other and turn their guns on you.", fight = true, material = &"event"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the two crews to sort out the pod. Their argument is still on the open channel long after the pod is out of range."}},
			],
		},
		{
			id = &"long_claim",
			title = "The long claim",
			subject = {stage = &"single", pieces = [&"paint_rock_a2"], r = 86.0},
			body = "A bare rock turns past your bow. One face has a mineral seam down it, and the rock has no transponder. No one mines this far out, because hauling the ore back costs more than it sells for. The best of the seam runs under an overhang that looks ready to fall. Taking the seam is a day of cutting. There is no other ship out here and none on the way.",
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
						return {text = "You take the seam and the shelf under it as well, and the frame takes no damage.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(38))
						Run.take_hull_damage(OptionTable.toll(3), "You take more than the seam. The forward bracing cracks under the strain, then holds.")
						return {text = "You take more than the seam. The forward bracing cracks under the strain, then holds."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						Run.take_hull_damage(OptionTable.toll(5), "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for. The rest of the seam stays in the rock.")
						return {text = "The shelf comes away wrong and takes the cutting head with it. You get half of what you came for. The rest of the seam stays in the rock."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The overhang comes down while you are still under it, and it lands on the bow.")
						return {text = "The overhang comes down while you are still under it, and it lands on the bow."}},
				{label = "Move on", stay = true, effect = func() -> Dictionary:
					return {text = "You log the seam and leave the overhang where it is. No other ship is close enough to work it before you return."}},
			],
		},
		{
			id = &"slipping_orbit",
			site = &"giant",
			subject = {layers = [{stage = &"single", pieces = [&"r5_scatter_spar_1"], turn = -14.0, tumble = 1.5, at = Vector2(40.0, -76.0)}, {stage = &"single", pieces = [&"r4_scatter_torn_plate_1"], turn = 10.0, tumble = 2.0, at = Vector2(-84.0, -56.0)}]},
			title = "Slipping orbit",
			body = "A gas giant fills half the viewport, and its gravity has you. You came in on a slow transfer to save fuel, and the well pulled you lower than you planned. The gauges give you about four minutes to decide whether the engines can climb out. The dish reads a spar of old wreckage on the same track, plate and frame both, caught by the well long ago. A hard burn climbs straight out and passes close enough to grapple it. A slower burn also gets out, but it uses a lot of fuel. One orbit costs you an hour and nothing else.",
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
						return {text = "You climb out cleanly. On the way past, the grapple takes the spar of old wreckage.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "The engines get you out of the well in the end. They burn two units doing it."},
					partial = func() -> Dictionary:
						Run.drain_fuel(4)
						return {text = "You get out, but the climb costs four units."},
					botched = func() -> Dictionary:
						Run.drain_fuel(6)
						return {text = "You skim the atmosphere going up. It costs six units and scorches the paint."}},
				{label = "Orbit once", stay = true, effect = func() -> Dictionary:
					return {text = "You ride one slow orbit without a burn. It costs the hour."}},
			],
		},
		{
			id = &"mine_drift",
			title = "Mine drift",
			subject = {layers = [{stage = &"single", pieces = [&"role:hauler"], far = true, dark = 0.75, at = Vector2(0.0, -6.0)}, {stage = &"ring", pieces = [&"r2_minedrift_limpet_mine_1", &"r4_minedrift_prong_mine_1", &"r2_minedrift_limpet_mine_2", &"r2_minedrift_prong_mine_2", &"r4_minedrift_prong_mine_2", &"r2_minedrift_limpet_mine_1", &"r4_minedrift_prong_mine_1"], count = 7, near = 0, rx = 150.0, ry = 62.0, spin = 0.3, roll = 8.0, roll_step = 15.0, at = Vector2(0.0, -6.0)}, {stage = &"field", pieces = [&"r4_minedrift_buckled_plate_1", &"r2_minedrift_broken_strut_2"], count = 2, near = 2, span = 430.0, height = 240.0, seed = 21, tumble = 4.0, turns = 30.0}]},
			body = "Dozens of old mines sit across the debris belt ahead. They still keep station around the ship they were set to guard. Whoever laid them stopped answering long ago, and no one came back for the ship. It is whole, with its hull unbreached and its holds shut. A second hull lies further in, opened along one flank by something other than the belt. A module is still racked in the open where the grapple could lift it. Some of the mines are too old to fire, but from out here you cannot tell which.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Thread it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You fly through the field without a hit. On the way out you lift a module off the opened wreck.", module = true},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "One mine hits your flank on the way out, and only one.")
						return {text = "One mine hits your flank on the way out, and only one."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Two mines hit, then a third, and you back out the last hundred metres.")
						return {text = "Two mines hit, then a third, and you back out the last hundred metres."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "An old mine fires late, after you are past it, and hits you from behind.")
						return {text = "An old mine fires late, after you are past it, and hits you from behind."}},
				{label = "Sweep wide", stay = true, effect = func() -> Dictionary:
					return {text = "You give the whole drift a wide margin and lose nothing but time."}},
			],
		},
		{
			id = &"corona",
			site = &"star",
			subject = {stage = &"single", pieces = [&"ship_cl_stack"], dark = 0.75, bake = 0.9, at = Vector2(40.0, 10.0)},
			title = "The corona",
			body = "The star here throws a flare every few hours, and the next one is due soon. Close in, inside the glare, a wreck sits with its holds intact. Other ships read the temperature and left. The light has baked the wreck's lit side to an amber crust. It is thick enough for the cutter to take off as a whole plate. The holds under it are still racked. Your vents have to carry the heat the whole way in and out. The board cannot say exactly when the next flare comes.",
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
						return {text = "Your vents hold the whole way in and out. The cutter takes a plate of amber crust off the lit side. The grapple pulls a rack out of a hold.", material_id = &"corona_amber", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "The grapple takes one rack off the wreck. You come out with a reactor that needs a minute to cool.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "You get one hold open, but the heat climbs too fast, and you back off before you can take anything."},
					botched = func() -> Dictionary:
						Run.heat += 20
						return {text = "The flare comes early. You leave with nothing, and the ship runs hot all the way out."}},
				{label = "Log the wreck", stay = true, effect = func() -> Dictionary:
					return {text = "You hold station outside the corona and log the wreck for a ship with better vents."}},
			],
		},
		{
			id = &"the_wind",
			site = &"star",
			subject = {stage = &"fx", fx = &"wind"},
			title = "The wind",
			body = "The star here is a blue hypergiant, losing mass fast enough to measure. The gas it sheds crosses this lane as a front, and the dish reads it an hour out. The gas is thin and very fast, and all of it moves outward the way you are going. Turn the hull side on and it carries the ship while the reactor idles. Meet it bow first and it shoves the bow aside, and the rest of the ship follows. Crossing at an angle under power costs fuel and gets you through inside the hour. The front is most of a day wide and will be past by the end of the afternoon.",
			tags = [&"hazard"],
			group = &"",
			weight = 8,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Ride the front",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 3
						return {text = "You put the hull side on for ninety seconds and let the front carry you. The crossing costs you no fuel at all."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You catch the edge of the front and hold it there. The reactor spends the whole crossing idling."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.heat += 5
						return {text = "You catch it badly and spend the crossing correcting. That costs you most of what the front gave you."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "The front takes the bow first and turns the whole ship sideways.")
						return {text = "The front takes the bow first and turns the whole ship sideways. It takes a long time to bring the ship back under control."}},
				{label = "Burn across it", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You cross the front at an angle, under power the whole way, and pay for it in fuel."}},
				{label = "Wait it out", stay = true, effect = func() -> Dictionary:
					return {text = "You hold position until the front has gone past. It costs you the afternoon and nothing else."}},
			],
		},
		{
			id = &"the_glare",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"glare", reach = 340.0}, {stage = &"single", pieces = [&"ship_lrshuttle"], dark = 1.0, silhouette = 0.9, at = Vector2(60.0, -10.0)}]},
			title = "The glare",
			body = "A blue hypergiant puts out more light in an hour than most stars do in a year. The dish reads this whole approach as white. Across a quarter of the sky it picks out no returns and no shadows. The last clean sweep before the dish whited out had a contact in it. It was the size of a ship, and it was holding still.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Go in on the last bearing",
					check = {attr = &"sensors", need = 6},
					met = func() -> Dictionary:
						return {text = "You fly the bearing and trust it. The contact is a wreck, exactly where the dish put it, and no one has been here before you. The grapple takes its racks.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You find it on the third pass, with one pass to spare. You strip what you can reach before you lose it in the glare again.", module = true},
					partial = func() -> Dictionary:
						return {text = "You find where the contact was, but it has moved. Something that came off it is still nearby, and you take that.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You spend an hour inside the glare and come out with a hot hull. You never find out whether you got within ten kilometres of it."}},
				{label = "Sweep the shadow side", effect = func() -> Dictionary:
					return {text = "You put the nearest rock between you and the star and read the sliver of sky in its shadow. The contact is not there, but something smaller has been drifting there for a while.", material = &"wreck"}},
				{label = "Log the bearing and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and the time. Then you turn out of the glare and take the long way in. The dish stays white for another hour."}},
			],
		},
		{
			id = &"the_scouring",
			title = "The scouring",
			subject = {stage = &"single", pieces = [&"place_derelict"], turn = 4.0},
			body = "A hull has sat in the wind of a blue hypergiant for a long time. The wind has stripped everything soft off it: the paint, the markings, the seals, and the crew's remains. What is left is frame and fittings, polished to bare metal and still bolted down. The star does the same to your plating the whole time you are alongside, though more slowly.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 7,
			min_danger = 5,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work it until you have to leave",
					check = {attr = &"hull", need = 6},
					met = func() -> Dictionary:
						return {text = "You stay alongside for four hours. The grapple takes the racks and most of a reactor housing. Your plating comes away polished on the star-facing side.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "You stay alongside a blue hypergiant for three hours, and the plating on the star-facing side gives out.")
						return {text = "You take one rack in three hours. The hull needs work.", module = true},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "You stayed alongside longer than the plating could take. The star went through it and into the frame.")
						return {text = "You get one rack off it before your plating readings start to drop, and you leave.", module = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You misjudged how long is too long beside a blue hypergiant. The star cut through your plating while you worked.")
						return {text = "You stay too long and get nothing. The wreck keeps its fittings, and you leave with damaged plating."}},
				{label = "Take what is already loose", effect = func() -> Dictionary:
					return {text = "You work the drift downwind of the hull instead and take what the star has already stripped loose.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off and take nothing. The hull keeps its fittings."}},
			],
		},
		{
			id = &"the_runner",
			title = "The runner",
			subject = {stage = &"single", pieces = [&"role:small"], lights = &"run"},
			body = "A pilot is running an errand for someone else, in someone else's ship. The parcel she needs moved is small enough to fit in a pocket. It has no manifest, no filing and no name on it. She cannot pay much now. She says the person it goes to will pay properly on delivery, but she is only repeating what she was told.",
			tags = [&"contract"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 8,
			max_security = 2,
			choices = [
				{label = "Hide it aboard",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "It goes into a space behind the coolant run that no scan reaches and no one else knows about. She watches you stow it and does not ask what else is in there.", place = &"paid_in_full"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You find a place for it inside the ship that will pass an ordinary search.", place = &"paid_in_full"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You stow it badly. For the whole next shell, a search would find it.", place = &"paid_in_full"},
					botched = func() -> Dictionary:
						return {text = "You are still looking for a place to put it when a patrol sweeps the dock. The sweep finds nothing, but she sees it and takes the parcel back."}},
				{label = "Ask what it is", stay = true, effect = func() -> Dictionary:
					return {text = "She tells you something, and you cannot tell if it is true. The parcel stays with her while she waits for your answer."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "She expected that. She goes to ask the next ship along the dock."}},
			],
		},
		{
			# PLACED, NEVER ROLLED. `admits` refuses anything carrying this key,
			# so the only way to reach the buyer is to have taken the package.
			# Ungrouped on purpose -- see `place`: a quest that an auction can
			# foreclose is a consequence you can lose without touching it.
			id = &"paid_in_full",
			title = "Paid in full",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], add_lights = [{at = "collar", off = [-2, 0], r = 12, col = "#ffcf7a", kind = "breathe", period = 6.0, k = 1.8, cone = 90, cone_k = 0.8}]},
			body = "The one waiting for the parcel is old, and not who you expected. He has been at this dock for eleven days. It is one small sealed package, and he does not open it where you can see. He pays what she said he would pay, which is far more than she could have promised. Then he asks carefully whether she looked well.",
			tags = [&"quest"],
			group = &"",
			placed = true,
			# ITS ROW IN THE QUESTS TABLE (`QuestLog`): the task beside the
			# signed jobs' tasks, the chart tag's word, and the note, which is
			# the runner's own line from `the_runner`'s body, word for word
			# (`-- sheet=QuestLogTest` holds it there). `from` is the event that
			# places it, for a save written before the run kept that
			# (`Run.event_quests`).
			quest = {task = "Deliver the runner's parcel", tag = "DELIVER", from = &"the_runner",
				note = "She says the person it goes to will pay properly on delivery, but she is only repeating what she was told."},
			weight = 0,
			choices = [
				# NO FAILING BAND AND NOTHING TO DECLINE. `batch-03`: taxing a
				# reward the player earned four jumps ago teaches them not to
				# take the offer next time. Both of these are gains.
				{label = "Take the money", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He pays in full and in cash, and then he thanks you."}},
				{label = "Tell him she looked tired", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "He nods for a long time and pays more than the agreed rate. He also names a yard two shells in that will fit you something at cost.", module = true}},
			],
		},
		{
			# A SIGNED FETCH'S PICKUP, put on the named system by
			# `Contracts.post_goal` -- never rolled (`placed`), and per ship
			# (`job`). Taking it readies every fetch pointed here; the thing is
			# named and not carried (`RunState.reach_contract_target`).
			id = &"job_pickup",
			title = "Contract pickup",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_1"], tumble = 2.0},
			body = "A cargo pod is parked in orbit here. Its beacon sends the code from your contract. This is the pickup you signed for. The seals are still on it, and the job says to leave them on.",
			tags = [&"quest"],
			group = &"",
			placed = true,
			job = true,
			weight = 0,
			choices = [
				{label = "Bring it aboard", effect = func() -> Dictionary:
					var who := Contracts.payer_here(ContractData.Kind.FETCH)
					Run.reach_contract_target(Run.at)
					return {text = "The grapple pulls the pod in and locks it to the frame. It takes no room in the hold. Take it to any %s yard to be paid." % who}},
				{label = "Leave it for now", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the pod where it is. The beacon keeps sending, and the job stays open."}},
			],
		},
		{
			# A SIGNED HUNT'S TARGET, the same way. The kill is what readies the
			# hunt (`Combat._victory` -> `RunState.clear_contract_target`); flee
			# and the next arrival posts it again.
			id = &"job_target",
			title = "Contract target",
			subject = {stage = &"single", pieces = [&"ship_gunboat"], dark = 0.85},
			body = "A ship sits here with its running lights off. Its transponder matches the one on your contract. It has seen you. It turns its bow toward you and holds there.",
			tags = [&"quest", &"fight"],
			group = &"",
			placed = true,
			job = true,
			weight = 0,
			choices = [
				{label = "Engage", fight = true, effect = func() -> Dictionary:
					return {text = "You close on it and open fire.", fight = true}},
				{label = "Leave it for now", stay = true, effect = func() -> Dictionary:
					return {text = "You keep your distance. It stays where it is, and the job stays open."}},
			],
		},
		{
			id = &"ghost_signal",
			subject = {stage = &"none"},
			title = "Ghost signal",
			body = "The dish is pulling a signal out of the background noise. It is too regular to be a star and too weak to be a station. In eleven minutes it has not drifted a second of arc, so the sender is fixed to something solid. The chart shows nothing at that bearing. Resolving it means holding position and giving the dish full power. At full power the dish can mistake your own reactor harmonics for a signal, and then you spend fuel chasing them.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Resolve it",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "It is a precursor beacon, still sending on a cycle no one uses now. You cannot read any of it. The grapple takes the housing off its mount and into the hold.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You pinpoint it, but the housing is fused to its mount and will not come off. You take the readings instead, shot onto film straight off the dish and never developed.", material_id = &"survey_film"},
					partial = func() -> Dictionary:
						return {text = "You chase it for an hour and it never comes clear. In the end it is your own reactor harmonics, reflected off something you never find."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You follow it a long way before you accept it was never there. It costs two units of fuel."}},
				{label = "Log it and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and move on, and leave it for a ship with a better dish."}},
			],
		},
		{
			id = &"customs_cordon",
			title = "Customs cordon",
			subject = {stage = &"group", ships = [{piece = &"role:hauler", dark = 0.7, at = Vector2(10.0, 50.0), z = 0}, {piece = &"ship_catamaran", fights = true, lights = &"patrol", at = Vector2(-5.0, -45.0), z = 1}, {piece = &"role:armed", fights = true, size = 0.5, dark = 0.6, at = Vector2(-168.0, -40.0), z = 1}, {piece = &"role:armed", fights = true, size = 0.5, dark = 0.6, at = Vector2(165.0, -48.0), z = 1}]},
			body = "A revenue cutter holds station over a seized hull, with two cold escorts off its flanks. Its crew seized that hull nine days ago. The impound paperwork is still not done. Until the paperwork clears, the manifest is public, and it lists what is still aboard. The cutter lets traffic through. It is here to guard the cargo.",
			tags = [&"signal", &"fight"],
			group = &"",
			weight = 10,
			min_danger = 3,
			max_danger = 8,
			min_security = 3,
			choices = [
				{label = "Go in dark",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You go across cold and silent, close enough to read the cutter's hull number. Nobody on it looks up. The seized hold is as open as its manifest said.", module = true},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You shut down all but the reactor, which runs hot. You take one rack for six heat and are not caught.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "Their sensors get a partial return, and they hail you in before you reach the hull. You pay the fine."},
					botched = func() -> Dictionary:
						Run.add_credits(-40)
						return {text = "They light you up from two sides at once and fine you, and the cutter's escorts come in to fight.", fight = true}},
				{label = "Hail them and ask", stay = true, effect = func() -> Dictionary:
					return {text = "You hail the cutter, ask what it is sitting on, and get told. It costs an afternoon and nothing else, and the hold stays sealed."}},
			],
		},
		{
			id = &"the_braid",
			title = "The braid",
			subject = {layers = [{stage = &"field", flip = true, pieces = [&"r2_braid_the_braid_idea2", &"r2_braid_the_braid_idea3", &"r2_braid_the_braid_idea2"], count = 3, near = 0, deep = 1, span = 440.0, height = 120.0, seed = 3, tumble = 0.0, at = Vector2(0.0, -64.0)}, {stage = &"single", flip = true, pieces = [&"r2_braid_the_braid_idea3"], at = Vector2(40.0, 62.0)}]},
			body = "Nine megafauna cross the dish in a line, big enough that the dish reads them as terrain. They follow a lane older than any chart. The wake behind them would carry you most of the way to the next ring. They are not hostile, but they are not watching for ships either. The smallest one is longer than yours.",
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
						Run.fuel += 3
						return {text = "You slot into the wake behind the third one and let it carry you. It never notices you."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You hold the wake most of the way before the wash pushes you out of it."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You misjudge the gap and drop in late. You spend the whole run fighting the wash instead of riding it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The fourth one turns out of the lane while you are close in, and its flank tears off your dorsal plating.")
						return {text = "The fourth one turns out of the lane while you are close in, and its flank tears off your dorsal plating."}},
				{label = "Take what they shed", effect = func() -> Dictionary:
					return {text = "You hold off the lane and collect what works loose in the wake. Their hides carry decades of junk: plate, ice, and today a whole rack off some ship that got too close.", module = true, material_id = &"hide_scrap"}},
				{label = "Let them pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off and wait while the nine of them pass. Then the dish clears."}},
			],
		},
		{
			id = &"refinery_still_lit",
			title = "Refinery, still lit",
			body = "A Cygnet refinery hangs over a dead seam with its stacks still glowing. It runs without a crew, cracking ore and stacking the output in a yard. The last shift left four years ago, and no one has come to empty the yard. The stacks run at working temperature, hot enough to kill a crew that gets close. The yard is still full.",
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
						return {text = "You work the yard in three passes with the vents wide open and never run hot. You take what fits of four years of output.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.heat += 7
						return {text = "You get two passes. You leave with a full hold and a reactor that needs a minute to cool.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						Run.heat += 15
						return {text = "You get one pass and take what little the grapple reaches before the cabin gets too hot."},
					botched = func() -> Dictionary:
						Run.heat += 24
						return {text = "A tower cycles while you are still alongside it. You leave with nothing at all and a reactor running hot."}},
				{label = "Shut it down first", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "It takes six hours to talk the control stack into shutting down. The yard is cool by the time you reach it, but half of what you wanted has cooked in place.", material = &"mining"}},
				{label = "Leave it running", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the refinery running, still cracking a seam that stopped paying and stacking a yard no one empties."}},
			],
		},
		{
			id = &"the_sweep",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 11.0}, {stage = &"single", pieces = [&"ship_rly_dishes"], dark = 0.85, glint = &"beam", at = Vector2(40.0, -20.0)}]},
			title = "The sweep",
			body = "A close, old pulsar sweeps its beam across this arc every eleven seconds, exactly. A survey ship sits inside the sweep, caught when it got the timing wrong. Its instrument rack is still mounted on the dorsal spine. Each gap is long enough to get in or to get out. Cutting the rack free takes longer than one gap, so some of the work happens with the beam on your hull. The beam puts in heat faster than the radiators shed it. It also leaves a glass crust that a refinery will buy.",
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
						return {text = "You make three passes in three gaps and are clear before the fourth. Up close, it was not the beam that killed the survey crew. Your hull comes away crusted with glass, and a refinery will pay for it.", module = true, material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.heat += 9
						return {text = "You take the rack in two gaps, and the beam catches you for most of the third.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You get inside, lose your bearings, and spend the gap finding the way back out."},
					botched = func() -> Dictionary:
						Run.heat += 26
						return {text = "You are still alongside when the beam comes around. The hull holds, and what is bolted to the outside of it cooks."}},
				{label = "Log the bearing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the wreck and the interval and leave them for a ship with better vents."}},
			],
		},
		{
			id = &"tug_work",
			title = "Tug work",
			subject = {layers = [{stage = &"single", pieces = [&"ship_pr_drum"], turn = -7.0, at = Vector2(-118.0, 40.0), lights = &"battery"}, {stage = &"field", pieces = [&"role:hauler", &"role:passenger", &"role:small", &"role:hauler", &"role:barge"], count = 5, near = 0, deep = 3, lift = 12.0, span = 216.0, height = 160.0, seed = 7, tumble = 0.0, at = Vector2(104.0, -36.0), lights = &"run"}]},
			body = "A bulk hauler hangs crooked at the head of the dock queue with dead thrusters. Nine ships are waiting behind it. The dock's own tugs are booked for the next eleven hours. Each hour the dockmaster grows keener to know whose fault it is. The pilot needs four minutes of push from a ship willing to put its nose on a hull forty times its mass.",
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
						return {text = "It takes four minutes on one contact point, with no scoring on either hull. The queue moves, and the dockmaster logs your ship."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(31))
						return {text = "It takes six minutes and leaves a scrape on your flank that will polish out. The queue moves."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(11))
						return {text = "You get it turned, but you do not get it clear. A yard tug comes out in the end and gets paid the difference."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You put twelve tonnes of thrust into a hull that was not braced for it. It gives way, and your bow goes in with it.")
						return {text = "You put twelve tonnes of thrust into a hull that was not braced for it. It gives way, and your bow goes in with it."}},
				{label = "Sell her the fuel instead", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Her ship cannot steer, but it can still burn fuel. You pump her ship enough to get clear under its own power, at a rate she cannot argue with."}},
				{label = "Wait in the queue", stay = true, effect = func() -> Dictionary:
					return {text = "Eleven hours in the queue. The hauler is still crooked at the head of it when your turn comes."}},
			],
		},
		{
			id = &"silt",
			subject = {layers = [{stage = &"fx", fx = &"dust", at = Vector2(30.0, 0.0), radii = Vector2(250.0, 124.0), tilt = 6.0, dens = 0.95}, {stage = &"single", pieces = [&"ship_lattice"], dark = 1.0, silhouette = 0.6, at = Vector2(60.0, -10.0)}, {stage = &"group", ships = [{piece = &"r4_scatter_torn_plate_1", size = 0.5, turn = 12.0, at = Vector2(-172.0, 40.0)}, {piece = &"r4_minedrift_cable_coil_1", size = 0.5, at = Vector2(-196.0, -6.0)}, {piece = &"r2_minedrift_broken_strut_1", size = 0.5, turn = -9.0, at = Vector2(-150.0, 84.0)}]}]},
			title = "Silt",
			body = "A shoal of fine dust and ice grit hangs across the lane, dense enough that the dish loses its far side. In the middle is one solid echo, hard and ship-sized, holding its shape while the shoal turns around it. Going in means going in blind on attitude jets, slowly, in case something in there is harder than dust. The near edge is thin enough to see through. For years it has caught what drifts down this lane: plate, loose fittings, and ice with metal frozen through it.",
			tags = [&"hazard"],
			group = &"",
			weight = 7,
			min_danger = 3,
			max_danger = 6,
			choices = [
				{label = "Feel your way in",
					check = {attr = &"maneuver", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in on attitude jets and touch nothing on the way. The echo is an intact survey cutter no one has reached before. The grapple takes a rack and its fittings.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You clip something soft on the way in, with no damage. The cutter's racks come away clean.", module = true},
					partial = func() -> Dictionary:
						return {text = "You find it and get one panel open. Then you lose your bearings in the dust and spend the rest of the time getting out."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Something in the shoal is much harder than dust, and you hit it bow first.")
						return {text = "Something in the shoal is much harder than dust, and you hit it bow first."}},
				{label = "Sweep the edge", effect = func() -> Dictionary:
					return {text = "You work the outside of the shoal where the grit is thin. You take what has collected there over the years.", material = &"wreck"}},
				{label = "Avoid it", stay = true, effect = func() -> Dictionary:
					return {text = "You keep the shoal on your beam and fly around it."}},
			],
		},
		{
			id = &"the_queue",
			title = "The queue",
			subject = {layers = [{stage = &"single", pieces = [&"place_station_stack"], at = Vector2(150.0, 0.0), lights = &"run"}, {stage = &"field", flip = true, pieces = [&"role:hauler", &"role:passenger", &"role:barge", &"role:small"], count = 5, near = 0, deep = 3, lift = 12.0, span = 290.0, height = 220.0, seed = 21, tumble = 0.0, at = Vector2(-76.0, 4.0), lights = &"run"}]},
			body = "The dock queue is nine ships long, and the dockmaster will not move anyone up it. The fourth ship has been fourth for two days. The pilot's charter fell through, and she is holding a slot she cannot use or sell back to the dock. She can sell it to another ship. The dockmaster does not mind who docks, as long as someone does.",
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
					Run.drain_fuel(4)
					return {text = "She has no charter and no reason to sit here. You give her enough to leave and take the slot she was sitting on.", module = true}},
				{label = "Wait your turn", stay = true, effect = func() -> Dictionary:
					return {text = "You wait your turn. The queue moves slowly, in order."}},
			],
		},
		{
			id = &"cold_labour",
			title = "Cold labour",
			subject = {stage = &"structure", pieces = [&"st_cold_labour"]},
			body = "A breaker's yard in Redline colours is waving you in. The crew has a new cutting head and does not trust it. They want to test it on someone else's plating before they use it on next week's hull. They will pay you to hold your flank against the head for an hour. They tell you plainly that they do not know what it will do.",
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
						return {text = "The head works as the spec said it would, and your plating takes no damage. They pay well for the test."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "It bites deeper than the spec said. You come away paid, and scored down one flank.")
						return {text = "It bites deeper than the spec said. You come away paid, and scored down one flank."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(4), "It bites much deeper than the spec said. They stop the test early and pay you half of it.")
						return {text = "It bites much deeper than the spec said. They stop the test early and pay you half of it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The head finds a seam and cuts through it before the yard crew can hit the cutoff. The crew apologises.")
						return {text = "The head finds a seam and cuts through it before the yard crew can hit the cutoff. The crew apologises."}},
				{label = "Rig them a target instead", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(17))
					return {text = "Your cutter shapes them a test target out of scrap plating. The new head has it in pieces by the end of the afternoon."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They take it well. The yard is waving at the next ship along before you are clear of the dock."}},
			],
		},
		{
			id = &"quarantine_flag",
			title = "Quarantine flag",
			subject = {layers = [{stage = &"single", pieces = [&"place_station_wheel"], dark = 0.8, at = Vector2(70.0, -5.0)}, {stage = &"group", lights = &"run", flip = true, ships = [{piece = &"role:hauler", far = true, at = Vector2(-140.0, 60.0)}, {piece = &"role:passenger", far = true, at = Vector2(-130.0, -70.0)}]}]},
			body = "A station sits dark with a Calyx quarantine flag on all its channels. For eight days nothing has gone in or out. No drones, decontamination lighters or Calyx hulls have come to it either. Two other ships hold off the exclusion line with you, and their dishes read nothing too. Inside is a full station's worth of stock, and it gets cheaper every hour the flag holds.",
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
						return {text = "You get half a read. You buy one crate you can inspect through the airlock glass and nothing else.", material = &"event"},
					botched = func() -> Dictionary:
						Run.add_credits(-50)
						return {text = "You read it wrong, the way you hoped it would read. Then you sit through a decontamination cycle that costs more than the stock was worth."}},
				{label = "Wait with the others", stay = true, effect = func() -> Dictionary:
					return {text = "You wait off the exclusion line with the other two ships. One of you will learn what the flag was in eight more days."}},
			],
		},
		{
			id = &"counterweight",
			title = "Counterweight",
			subject = {stage = &"single", pick = true, pieces = [&"t3_counterweight_1", &"t3_counterweight_2", &"t3_counterweight_4"], at = Vector2(20.0, -20.0)},
			body = "A habitation ring tumbles end over end ahead, one turn every ninety seconds. It came off a station, and no one collected it. Everything inside is still bolted down where it was fitted. The yard at the settlement one jump in buys ring fittings by the tonne and does not ask which ring. Plating and antenna mounts come past outside on every turn. So does the airlock, never in the same place twice. The ring is heavier than your ship and keeps turning at the same rate while you work.",
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
						return {text = "You match the tumble and hold it steady, so the ring is still relative to you. The grapple works through the lock and takes out what the yard will buy.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "You match the tumble, but the ring hits you as you back out.")
						return {text = "You match it well enough, and the grapple reaches one rack through the lock. Backing out, the ring catches your hull.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						Run.take_hull_damage(OptionTable.toll(2), "The grapple gets one hold before the rotation pulls the ship into the ring.")
						return {text = "The grapple gets one hold before the rotation pulls the ship into the ring."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You match the wrong direction of spin, and the ring hits you before you can correct.")
						return {text = "You match the wrong direction of spin, and the ring hits you before you can correct."}},
				{label = "Take the outside", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(8))
					return {text = "You stay outside. The grapple takes what is bolted to the exterior, one piece each turn.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the ring turning, with everything inside still bolted down."}},
			],
		},
		{
			id = &"the_auction",
			title = "The auction",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], with = [{piece = &"r2_holding_old_container_2", at = "cargo", off = Vector2(-26.0, 0.0)}, {piece = &"ship_mkt_slung", scale = 0.5, flip = true, lights = &"run", at = Vector2(10.0, 100.0)}, {piece = &"ship_courier2", scale = 0.5, flip = true, lights = &"run", at = Vector2(0.0, 150.0)}, {piece = &"ship_hp_wards", scale = 0.5, flip = true, lights = &"run", at = Vector2(40.0, 255.0)}]},
			body = "Probate is selling a dead crew's hold. There are no heirs. The lot is sealed, the manifest is sealed, and the buyer takes it as it lies. Two of the last three lots were worth less than the fee. The third was worth a great deal more, and its buyer has not needed to work since. Bidding closes in an hour, and there are four of you.",
			tags = [&"contract"],
			group = &"berth",
			weight = 7,
			min_danger = 5,
			needs_berth = true,
			choices = [
				{label = "Bid on it", cost_credits = 70, effect = func() -> Dictionary:
					Run.add_credits(-70)
					return {text = "You pay the fee and take the lot as it lies. Forty minutes later you break the seal in your own hold, where no one else can see what you got.", module = true, material = &"event"}},
				{label = "Read the room instead",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(13))
						return {text = "You do not bid. You watch who does, and how the Probate clerk reacts to the third bidder's price. Afterwards you know which lot next week is worth having, and you sell that."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(7))
						return {text = "You learn something about two of the bidders. You can sell it now, and it will be useful later."},
					partial = func() -> Dictionary:
						return {text = "You learn only that the other bidders are better at this than you are."},
					botched = func() -> Dictionary:
						Run.add_credits(-70)
						return {text = "You read a nod across the room as a bid. You win a lot you did not want, at a price you did not pick.", material = &"event"}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "One of the other three pays the fee and takes the sealed lot."}},
			],
		},
		{
			id = &"escort",
			title = "Escort",
			subject = {stage = &"field", flip = true, lights = &"run", pieces = [&"role:hauler", &"role:small", &"role:hauler", &"role:hauler"], count = 4, near = 1, deep = 1, lift = 30.0, span = 440.0, height = 240.0, seed = 13, tumble = 0.0},
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
					return {text = "You fly the flank for one ring. Then a ship comes out of the shadow of the third moon and attacks the convoy.", fight = true}},
				{label = "Sell them the courier's slot", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(28))
					return {text = "The courier is fast enough to outrun anything out here alone. You tell them so, take a cut for the advice, and the convoy splits."}},
				{label = "Decline", stay = true, effect = func() -> Dictionary:
					return {text = "They pay the other escort most of what the run is worth and leave without you."}},
			],
		},
		{
			id = &"nine_tonnes",
			title = "Nine tonnes of nothing",
			subject = {stage = &"single", pieces = [&"r2_container_freight_box_1"]},
			body = "A freight crate sits on the dock, and its owner wants it moved one ring inward, above rate. The numbers do not match. The manifest says nine tonnes, but the crate is sized for forty, and it reads warm on your sensors. He is happy for you not to ask what is in it. He is less happy about you opening it.",
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
						return {text = "It is undeclared reactor fuel in a casing rated for something safer, worth four times the freight. He pays the new rate without arguing."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "It is not what the manifest says, but it is safe. You take the job at a better rate."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You get the casing open, find nothing worth knowing, and shut it before he notices. The rate stays what it was."},
					botched = func() -> Dictionary:
						return {text = "He notices, and he leaves with the crate. The job is off."}},
				{label = "Just take the job", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(25))
					return {text = "You move the nine tonnes one ring inward, above rate, and ask no questions."}},
				{label = "Pass", stay = true, effect = func() -> Dictionary:
					return {text = "He finds another ship inside the hour."}},
			],
		},
		{
			id = &"ice",
			subject = {stage = &"single", pieces = [&"paint_moon_europa"], lumpy = 3.3, r = 34.0, dirt = 0.45, at = Vector2(110.0, -80.0)},
			title = "Ice",
			body = "A comet hangs off your bow, three kilometres of dirty ice on a long, slow orbit. It has no transponder and no claim on it, and no one out here buys water. Under the crust are volatiles and a little metal. The crust has hardened since this system was warm, and it is under pressure, so it can crack when you cut it.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			max_danger = 4,
			max_development = MapGen.Development.OUTPOST,
			choices = [
				{label = "Cut deep",
					check = {attr = &"hull", need = 4},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You take the crust off in sheets and get at the clean ice under it. There are volatiles and water. There is enough left in the tail to make the trip pay.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.take_hull_damage(OptionTable.toll(3), "The crust breaks the wrong way. You get most of what you came for, and the rest scrapes down one side of the hull.")
						return {text = "The crust breaks the wrong way. You get most of what you came for, and the rest scrapes down one side of the hull."},
					partial = func() -> Dictionary:
						Run.fuel += 2
						Run.take_hull_damage(OptionTable.toll(5), "The face calves while you are cutting it. You back off with a half hold and a dented bow.")
						return {text = "The face calves while you are cutting it. You back off with a half hold and a dented bow."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The face of hard ice lets go all at once, and it pours into your bow for about eleven seconds.")
						return {text = "The face of hard ice lets go all at once, and it pours into your bow for about eleven seconds."}},
				{label = "Skim the tail", effect = func() -> Dictionary:
					Run.fuel += 1
					return {text = "You leave the body alone and run the tail instead, taking what it is already shedding. It is slow and safe."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the comet and fly on. It comes back around in ninety years."}},
			],
		},
		{
			id = &"flare_shelter",
			site = &"star",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_a1"], r = 58.0, at = Vector2(-30.0, -12.0)}, {stage = &"single", pieces = [&"r2_drone_delivery_drone_2"], dark = 0.55, at = Vector2(122.0, 62.0)}]},
			title = "Flare shelter",
			body = "The star's readings are climbing, and the instruments are sure a big flare is about forty minutes out. Two minutes away is a rock big enough to shadow you. A survey drone is tucked in behind it, where it has sheltered from flares for years. Forty minutes is enough to reach the rock and strip the drone, with little time to spare.",
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
						return {text = "You reach the shadow, and the cutter opens the drone in the dark. You come out of the flare with its readings, a rack off its frame, and a cold reactor.", module = true, material_id = &"survey_film"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get most of it done before the shadow starts to move. You finish the rest out in the light.", module = true},
					partial = func() -> Dictionary:
						Run.heat += 17
						return {text = "The cutter gets the drone open, but no more. The flare hits you with the hold still empty."},
					botched = func() -> Dictionary:
						Run.heat += 25
						return {text = "You misread how the rock turns. You spend the peak of the flare out on the lit side."}},
				{label = "Just shelter", effect = func() -> Dictionary:
					return {text = "You put the rock between you and the star and wait the flare out. One piece of somebody else's cargo drifts into the shadow with you. The grapple takes it in.", material = &"event"}},
				{label = "Outrun it", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					return {text = "You leave before it peaks. It costs a burn you had not budgeted for and you never find out what was on the drone."}},
			],
		},
		{
			id = &"deadfall",
			title = "Deadfall",
			subject = {layers = [{stage = &"strewn", far = true, pieces = [&"r6_gantry_snapped_truss_drifting_2_p3", &"r6_gantry_snapped_truss_drifting_2_p1", &"r6_gantry_snapped_truss_drifting_2_p4", &"r6_gantry_snapped_truss_drifting_2_p2"], turn = [12.0, -7.0, 17.0, -11.0], lift = [0.0, 10.0, -8.0, 6.0], gap = 16.0, at = Vector2(70.0, -78.0)}, {stage = &"strewn", pieces = [&"r6_gantry_snapped_truss_drifting_2_p1", &"r6_gantry_snapped_truss_drifting_2_p2", &"r6_gantry_snapped_truss_drifting_2_p3", &"r6_gantry_snapped_truss_drifting_2_p4"], turn = [-4.0, 9.0, -14.0, 20.0], lift = [8.0, -10.0, 16.0, -4.0], gap = 18.0, at = Vector2(0.0, 22.0)}]},
			body = "Nine hundred metres of collapsed gantry lies across the approach. It was an orbital yard, and it fell in on itself slowly after a decade with no one paying for maintenance. Parts of the wreck are still under tension and let go of a piece now and then. Under the middle of it is a fitting bay, where a yard like this kept its best parts.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 5,
			choices = [
				{label = "Go under it",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You pick a line through nine hundred metres of dead scaffolding, and nothing touches you. The bay is exactly as it was left.", module = true, material = &"wreck"},
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
					return {text = "The edge of the field is safe and already picked over. You take what the last four crews did not think was worth lifting.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You keep clear of the gantry and fly on."}},
			],
		},
		{
			id = &"the_long_tow",
			title = "The long tow",
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 0.55, lights = &"battery", at = Vector2(40.0, 0.0)},
			body = "A ship hangs dead off your bow with its hull lights running on battery. Its crew answers the hail at once. The reactor is scrap, but all six of them are fine. The dock on the far side of this system will take the ship if it can get there. A tow is four hours of your engine at a load it was not built for. The hull on your stern does not steer.",
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
						return {text = "The tow takes four hours on one heading, and nothing goes wrong. The dock takes the ship."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						Run.take_hull_damage(OptionTable.toll(2), "The tow takes five hours and strains a stern mount. The ship gets there.")
						return {text = "The tow takes five hours and strains a stern mount. The ship gets there."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "You get it most of the way before your engine can take no more. A yard tug takes the last leg and most of the fee."},
					botched = func() -> Dictionary:
						Run.drain_fuel(3)
						return {text = "The line parts under load. Nobody is hurt. You lose four hours, one tow line, and all the fuel you burned getting that far."}},
				{label = "Sell them a reactor start", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(36))
					return {text = "You have enough fuel aboard to start its cold reactor, though it leaves a thin safety margin. They take it."}},
				{label = "Signal it in and go", stay = true, effect = func() -> Dictionary:
					return {text = "You put their position on the emergency band and fly on."}},
			],
		},
		{
			id = &"the_calf",
			title = "The calf",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_b4"], r = 80.0, at = Vector2(90.0, -30.0)}, {stage = &"single", pieces = [&"pool_calf_wound"], at = Vector2(-70.0, 40.0)}]},
			body = "A megafauna calf hangs beside a cold rock, calling for the pod it lost. Like all of them, it reads warm on every instrument, and that warmth is why they are hunted. A hunter somewhere behind you has posted a standing bounty for a tagged calf. The pod is two hours out, answering on a frequency so low your hull picks it up as vibration.",
			tags = [&"signal"],
			group = &"herd",
			weight = 8,
			min_danger = 3,
			max_danger = 8,
			needs_fauna = true,
			choices = [
				{label = "Tag it for the bounty", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(36))
					return {text = "You fire a transponder dart, get a confirmation ping, and are paid by a ship you never see. The calf carries the tag toward its pod. The bounty terms say that what happens next is not your business."}},
				{label = "Herd it home",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						Run.fuel += 3
						return {text = "You put your hull where a parent would put its flank. It follows you all the way in. The pod closes around it. Nine of them turn at once, and the wake carries you a long way for free."},
					clean = func() -> Dictionary:
						Run.fuel += 1
						return {text = "It follows in the end, after twice taking you for a threat. The pod's wake pays back some of the fuel."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "It bolts the wrong way twice. You spend an hour of burn undoing each of those. Then it hears the pod itself and goes in alone."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "It panics at the wrong moment and hits you with its flank at speed. It still reaches the pod.")
						return {text = "It panics at the wrong moment and hits you with its flank at speed. It still reaches the pod."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "The pod is two hours out. The hunter behind you is closer than that. You do not stay to see which one gets there first."}},
			],
		},
		{
			id = &"the_manifest",
			title = "The manifest",
			subject = {stage = &"single", pieces = [&"ship_rf_pipes"], lights = &"run"},
			body = "A heat barge sits across the lane inward with its running lights on and drives cold. The woman flying it is hailing for a witness. The rules want a second signature on the last leg, from someone with nothing to gain. She has held station for a day and a half, waiting for a ship that neither pays her nor competes with her. The seal on the load reads nine hundred units, signed at the last station with the authority to sign it. Your mass reading puts the barge four points heavy for nine hundred units of anything.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 9,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sign what the seal says", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(14))
					return {text = "You sign for nine hundred units and hold formation for the last leg. The fee clears before you have decided what you saw. It pays well for an hour of flying, and the four points stay unexplained."}},
				{label = "Put the dish on the load first",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "The load is eleven hundred units against a seal for nine. Someone up the line is moving two hundred units of something inward and paying tax on the smaller number. The pilot was never told what it is. You sign the true figure, and she pays you for it, glad to send the problem back to whoever made it."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(14))
						return {text = "The mass settles close enough to the seal. The difference is fuel and ice, which shift the reading on a barge low on both. You sign, fly the leg and collect."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(3))
						return {text = "Your figures will not settle, and her window will not wait. You refuse to sign a reading you cannot trust and take the standing fee for answering the hail. She looks for another witness."},
					botched = func() -> Dictionary:
						Run.add_credits(-60)
						return {text = "You sign a number that the vault's own scale later disputes. The fine lands on you, because yours is the only name on the paper anyone can find."}},
				{label = "Let her carry on", stay = true, effect = func() -> Dictionary:
					return {text = "She holds another hour on the open channel. Then she flies the last leg without a witness so she does not lose the window."}},
			],
		},
		{
			id = &"the_last_berth",
			title = "The last counter",
			subject = {stage = &"single", pieces = [&"place_station_stack"], lights = &"run"},
			body = "This is the deepest dock still lit, with one clerk behind its counter. She logs arrivals, though the traffic stopped before her posting began. She logs yours properly: name, mass, heading, and the time to the minute. Her rate sheet has not changed in eleven years. That makes her fuel the cheapest in the galaxy, and she does not know it. Her archive drawer holds one thick folder with no label. She calls it the observations.",
			tags = [&"contract"],
			group = &"threshold",
			weight = 8,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			needs_berth = true,
			choices = [
				# 4 for 6 units, so "the cheapest in the galaxy" is true: a
				# capital's REFUEL is 24 for 25, about 1 a unit (fuel:A, Oct 18).
				# It was 30 for 6, five a unit, dearer than any dock.
				{label = "Buy fuel at her rates", cost_credits = 4, effect = func() -> Dictionary:
					Run.add_credits(-4)
					Run.fuel += 6
					return {text = "The rate is on a sheet she cannot change and has no reason to doubt. She stamps the receipt twice, once for you and once for a copy no one has collected in eleven years."}},
				{label = "Stay and copy the folder", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "Copying it takes most of a shift, with the reactor idling. It is other crews' paperwork about the thing at the core. There are transit logs that stop mid line and a mass estimate crossed out four times. There is an order for instruments that were never sent and never cancelled. She reads along with you in silence. In eleven years, no one else has asked to see it.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave her be", stay = true, effect = func() -> Dictionary:
					return {text = "Yours is the first arrival she has logged in a long while. She logs it carefully, down to the minute."}},
			],
		},
		{
			id = &"counting_backwards",
			title = "Counting backwards",
			subject = {stage = &"single", pick = true, pieces = [&"t3_counting_backwards_a_2", &"t3_counting_backwards_b_1", &"t3_counting_backwards_b_2"], tumble = 2.0},
			body = "A dead relay hangs on the approach with its transponder still working. It sends one number every forty-one years, and each is lower than the last. Your charts hold three of them, logged by three ships across two centuries. The next number it sends will be zero. The relay is precursor work, older than any name anyone has for it. The dish puts that broadcast four days out.",
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
						return {text = "The cutter opens the housing along a seam the builders left for this. The core comes away still warm, and the grapple moves it into the hold. It keeps counting.", material_id = &"counting_core"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You take it fast and pay for the speed in waste heat, which the radiators will take an hour to shed. The core keeps counting down in the hold.", material_id = &"counting_core"},
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
						return {text = "Years of heat and cold have welded the housing to its frame, and the cutter cannot free it in time. You take the readings instead: the interval, the bearing and the decay curve, shot onto film straight off the dish. You also take something the cutter shook loose.", material_id = &"survey_film", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something kept the core warm for two hundred years. When the cutter opened it, it came through the hull.")
						Run.heat += 20
						return {text = "Something has kept that core warm since before there were manufacturers. When the cutter opens it, it comes through the hull, fast and hard."}},
				{label = "Wait out the four days",
					effect = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You hold station for four days on fuel you will want later. On the fourth day the number goes to zero and the transponder stops. After that there is no signal, no light, and no answer from anywhere. Your recording runs six more hours of silence.", material_id = &"last_broadcast"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and leave the relay counting down."}},
			],
		},
		{
			id = &"holding_pattern",
			title = "Holding pattern",
			subject = {stage = &"ring", pieces = [&"role:hauler", &"role:passenger", &"role:barge", &"role:small", &"role:tender", &"role:hauler"], count = 6, near = 0, rx = 165.0, ry = 92.0, spin = 0.0, dark = 0.35},
			body = "Six ships hold a loose ring ahead of you with their drives cold and their transponders on. Their hulls are weathered unevenly, so they arrived years apart. None of them has moved since your dish resolved them. They are not a convoy or a blockade, and all of them point inward. You hail the ring, and the only answer that comes back is a receipt code.",
			tags = [&"signal"],
			group = &"",
			weight = 8,
			min_danger = 9,
			regions = [MapGen.Region.DEEP],
			choices = [
				{label = "Sell them the way out", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(30))
					return {text = "They have pointed inward so long that their route is out of date. You send them yours: bearings, what the crossings cost, and which stations are still staffed. They pay warm-economy prices, in credits from somewhere that still has a mint. They do not say what they want it for. Two of them ask for a second copy."}},
				{label = "Read their receipts",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "All six codes come from one issuer, a vault. Their holds read empty, so they have delivered and are waiting to be paid. The oldest code is forty years old. You copy all six to sell further out."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						return {text = "The codes are vault-issued and run in sequence, so this is an old, orderly queue that someone set up."},
					partial = func() -> Dictionary:
						return {text = "The codes point at a ledger kept somewhere you will never get access to."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You push the nearest transponder hard enough that all six ships answer. They light their drives at once, hold them for four seconds, and go cold again without a word. You burn out of the ring on a heading you did not plan."}},
				{label = "Hold station with them", stay = true, effect = func() -> Dictionary:
					return {text = "You point inward, kill the drives, and sit in the ring for a while. None of the six ships moves. Then you light the drives and go."}},
			],
		},
		{
			id = &"the_favour",
			title = "The favour",
			subject = {stage = &"single", pieces = [&"role:small"], lights = &"run", drive = true},
			body = "A courier is hailing every ship with fuel to spare. Her tank is nearly empty, and her charter pays on arrival, one ring further in than her fuel reaches. She is offering above the going rate for a top-up. If no one sells, she drifts until the people who hired her notice she is late. She is in no danger, but she cannot afford a late delivery.",
			tags = [&"contract"],
			group = &"",
			weight = 13,
			max_danger = 6,
			choices = [
				{label = "Sell her two units", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(20))
					return {text = "You pump two units across. The rate is high for her and good for you. She is moving again before the pump has cooled."}},
				{label = "Sell her three", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(36))
					return {text = "Three units is enough for her to arrive with margin. She pays the rate without arguing, so the charter must be worth a lot more."}},
				{label = "Wish her luck", stay = true, effect = func() -> Dictionary:
					return {text = "She thanks you, logs your registry with the others who said no, and goes back to hailing."}},
			],
		},
		{
			id = &"wrong_registry",
			title = "Wrong registry",
			subject = {stage = &"single", pieces = [&"r2_drone_delivery_drone_1"]},
			body = "A delivery drone matches your course and runs a docking handshake older than your ship. It carries a consignment for a registry one digit off yours. That hull may not have flown for decades. The job is long overdue, and the late penalty has run so far it has wrapped around to zero. The drone will keep waiting until someone accepts it.",
			tags = [&"signal"],
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Accept the consignment", effect = func() -> Dictionary:
					return {text = "You spoof the digit and the drone unloads. The consignment comes over sealed, addressed, and heavier than it looks. The drone logs the delivery complete and returns to its route.", module = true, material = &"event"}},
				{label = "Correct its registry",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "You give it the right registry off an old dock ledger. That hull was lost before you started flying. The drone thanks you in protocol, releases the parcel it can no longer deliver, and sets course for the wreck.", material = &"event"},
					clean = func() -> Dictionary:
						return {text = "You give it a registry that looks right. It accepts, plots a new route, and leaves you a crate off the back of the consignment.", material = &"event"},
					partial = func() -> Dictionary:
						return {text = "Its check loop politely turns down everything you offer. You break off before it finishes the fourth try."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "You feed it a bad registry, and it takes you for the ship it was looking for. It bills you for every parcel on its manifest. Then it follows you to the edge of sensor range and waits there."}},
				{label = "Decline the handshake", stay = true, effect = func() -> Dictionary:
					return {text = "It holds formation for exactly one hour, then returns to its route with the parcel."}},
			],
		},
		{
			id = &"dead_station",
			title = "Dead station",
			subject = {stage = &"single", pieces = [&"place_derelict_station"], dark = 0.7, turn = 12.0},
			body = "A station hangs dark and unpowered ahead, turning slightly off true. The docking clamps still hold pressure, so the reactor died slowly and someone shut things down in order. No one is aboard now. The face turning past has open bays with the racks still in them. The tanks are on the far side of the hub, sealed, with a coupling the grapple can work. Getting from one to the other means an hour of holding station against the uneven turn.",
			tags = [&"salvage"],
			group = &"",
			weight = 12,
			max_danger = 6,
			choices = [
				{label = "Salvage the racks", effect = func() -> Dictionary:
					return {text = "The grapple pulls a module out of a dead bay and clears the rack around it on the same pass. After all this time, it comes away on the first try.", module = true, material = &"wreck"}},
				{label = "Siphon the tanks", effect = func() -> Dictionary:
					Run.fuel += 2
					return {text = "The tanks give two units of fuel."}},
			],
		},
		{
			id = &"distress_beacon",
			subject = {stage = &"none"},
			title = "Distress beacon",
			body = "A looping voice repeats a set of coordinates one jump off your route. It sounds like a recording that has been running a long time. Whatever is at the far end is sending through a hull big enough to carry a real transmitter. That makes it worth reaching or worth staying well away from, and the recording does not say which.",
			tags = [&"signal", &"fight"],
			group = &"",
			weight = 11,
			max_danger = 6,
			choices = [
				{label = "Answer it", fight = true, effect = func() -> Dictionary:
					return {text = "It was bait. The hull sending it is real and still loaded, worth taking from whoever is using it as a lure. They are already firing at you.", fight = true}},
				{label = "Read it from cover",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "You sit off the coordinates and listen. Under the loop is a second signature, holding station, so this is a trap. You sell the coordinates as a hazard note at the next dock."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "Enough of the carrier comes through to show there is no one alive to rescue. You log it, and the log is worth a little to a buyer."},
					partial = func() -> Dictionary:
						return {text = "You learn only that it repeats every ninety seconds."},
					botched = func() -> Dictionary:
						Run.heat += 8
						return {text = "You hold position too long, and whatever is under the loop gets a good look at you. You leave running hot."}},
				{label = "Run silent", stay = true, effect = func() -> Dictionary:
					Run.heat = 0
					return {text = "You cut the reactor and drift past with everything dark, and your heat drops to nothing."}},
			],
		},
		{
			id = &"whale_fall",
			title = "Whale fall",
			subject = {stage = &"structure", pieces = [&"st_whale_fall"], cluster = {pieces = [&"pool_discs", &"pool_fan"], count = 9, rect = Rect2(110, 120, 220, 160), size = [0.2, 0.4], turns = 35.0, seed = 7}},
			body = "The corpse of something enormous hangs ahead, coming apart slowly and feeding a crowd of smaller animals. Most of them are too small for the dish to read, and a few are bigger than your ship. The carcass is worth taking, and the best of it is in the seams between the ribs. Cutting there means sitting among the feeders for as long as the cut takes. Enough has already come loose to fill a bay, out where nothing is feeding.",
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
						return {text = "You work the seam slowly, in the lee of the ribs, and come away loaded. None of the feeders pays you any attention.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.add_material(&"exotic", 2)
						return {text = "You take what you came for. A feeder the size of a hatch cover watches you and leaves you alone."},
					partial = func() -> Dictionary:
						Run.add_material(&"exotic", 1)
						Run.take_hull_damage(OptionTable.toll(3), "A feeder at the whale fall, bigger than your ship, attacked the hull.")
						return {text = "Halfway through the cut, the feeders turn on you as competition. You leave with less than you wanted and a scratched hull."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "The feeders at the whale fall came for the hull all at once and did not stop.")
						return {text = "The small feeders all come at you at once, while the big ones keep feeding."}},
				{label = "Take what has come loose", effect = func() -> Dictionary:
					return {text = "You take what has drifted clear of the ribs, enough to fill a bay, and cut nothing.", material = &"fauna"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You hold station a while, take nothing, and leave the carcass to the feeders."}},
			],
		},
		{
			id = &"inspection_sweep",
			title = "Inspection sweep",
			subject = {stage = &"group", ships = [{piece = &"role:hauler", far = true, dark = 0.7, turn = 5.0, at = Vector2(130.0, -75.0), z = -3}, {piece = &"role:hauler", far = true, lights = &"run", at = Vector2(150.0, 15.0), z = -2}, {piece = &"role:passenger", far = true, lights = &"run", at = Vector2(110.0, 70.0), z = -1}, {piece = &"ship_dropship", lights = &"patrol", at = Vector2(-95.0, 5.0), z = 1}]},
			body = "A patrol is stopping everything in this lane because of a hauler parked behind them. They pulled it over two days ago, and its crew abandoned it. Its load sits in the impound under a seizure notice that no one has come to act on. The queue moves slowly. Whatever is still in the impound at the end of the week goes to the breakers.",
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
					return {text = "You are clean, so they wave you through, first in line for the impound. You pay the price on the notice.", module = true, material = &"wreck"}},
				{label = "Talk your way to the front",
					check = {attr = &"stealth", need = 4},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Your registry reads as already cleared for the forty seconds they spend checking it.", module = true},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(17))
						return {text = "You come out of the queue two hours early and take the smaller half of the impound."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A patrol skiff crowded you off the impound gate.")
						return {text = "They notice, and a patrol skiff crowds you off the gate. The damage is to your paint. You leave with nothing out of the impound."},
					botched = func() -> Dictionary:
						Run.add_credits(-45)
						return {text = "You are fined for trying it, item by item, and made to wait anyway. The impound is empty by the time you get to it."}},
				{label = "Burn away", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.take_hull_damage(OptionTable.toll(2), "You ran the lane, and something clipped you on the way out.")
					return {text = "You run for it. It costs one fuel and a scraped flank, and leaves no record."}},
			],
		},
		{
			id = &"derelict_hauler",
			title = "Derelict hauler",
			subject = {stage = &"single", pieces = [&"r3_frame_gutted_frame_1"], tumble = 1.0},
			body = "An old freight frame drifts ahead, gutted to its structure but still straight. Whoever stripped it took the fittings and left what they were bolted to. That is the opposite of the usual order, so they were in a hurry. What is left is a spine, dry tanks, and the mounts the racks came off. None of it reads bent. Proving the frame will fly takes hours of slow passes and instrument work. Cutting it up is quicker, and plating and wire off a hull this size sell at any yard.",
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
					return {text = "You log where it is and fly on."}},
			],
		},
		{
			id = &"hostile_contact",
			title = "Hostile contact",
			subject = {stage = &"single", pieces = [&"ship_gunboat"], dark = 0.85, fights = true},
			body = "A hull sits dead ahead of you where the chart shows nothing. Its engines are cold and its running lights are off. It already has your registry, queried before your dish finished resolving its shape. No hail follows, and no demand. It turns slowly until its bow points at you, then holds there and waits for you to act.",
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
					return {text = "You light the drives and close before it is ready for you. It did not expect you to attack first.", fight = true}},
				{label = "Burn past it", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You put the throttle down and take the long way around the system, watching its bearing. It does not follow or hail, and you never learn what it wanted."}},
			],
		},
		{
			id = &"dead_hull",
			title = "A dead hull",
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 1.0, turn = 8.0},
			body = "A hull drifts across the lane, cold all the way through: no heat on any band, no beacon, no claim transponder answering. Whatever registry it flew under is not one your dish can reach from here. The airlocks are shut. The racks, on the long-range read, are still full. It has been here long enough that nobody is coming for it.",
			tags = [&"salvage"],
			group = &"",
			weight = 14,
			choices = [
				{label = "Strip it", effect = func() -> Dictionary:
					return {text = "You put the grapple on it and cut the racks out through the breach. Whatever killed the crew left the parts, and you take them.", module = true}},
				{label = "Read the log first",
					check = {attr = &"sensors", need = 3},
					met = func() -> Dictionary:
						return {text = "The recorder is intact and names which racks were loaded last and with what. You take the best of those and the crate stowed beside them.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "Enough of the log survives to show the hull has no scuttling charge or scavenger trap. The crew ran out of heat. You strip it at your own pace.", module = true},
					partial = func() -> Dictionary:
						return {text = "The recorder is melted, and the racks are locked to a registry only it held. You take what is drifting loose in the open sections and learn nothing about how the crew died."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Something in the dead hull was still charged.")
						return {text = "A power cell that should have been flat discharges into the bow the moment the panel comes off."}},
			],
		},
		{
			id = &"cordon",
			title = "The cordon",
			subject = {stage = &"group", fights = true, strobe = true, lights = &"run", ships = [{piece = &"ship_gunboat", far = true, at = Vector2(-160.0, -10.0)}, {piece = &"ship_armedtrader", at = Vector2(0.0, 0.0), z = 1}, {piece = &"ship_dropship", far = true, at = Vector2(160.0, -10.0)}]},
			body = "Three ships hold a line across the lane with their weapons live. A strobe runs the width of it. It is a toll. The hail is polite and carries a rate card: one rate for every hull, payable now. Out here there is no one to complain to. The ships on the line know to the hour how far away the nearest help is.",
			tags = [&"fight", &"signal"],
			group = &"",
			weight = 12,
			regions = [MapGen.Region.LAWLESS],
			max_security = 2,
			min_danger = 5,
			choices = [
				{label = "Pay it", cost_credits = 60, effect = func() -> Dictionary:
					Run.add_credits(-60)
					return {text = "You pay the rate, and the strobe drops. You fly the lane end to end without a sensor ping."}},
				{label = "Run it",
					check = {attr = &"thrust", need = 6},
					met = func() -> Dictionary:
						return {text = "You are past the line before the three of them react. Their one shot misses, and the lane costs you nothing."},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "They burn after you the moment you commit. You take the lane at full throttle, and the sprint costs fuel."},
					partial = func() -> Dictionary:
						Run.drain_fuel(4)
						return {text = "They close the gap, so you take the wide route at speed. You get through, and it costs four units of fuel."},
					botched = func() -> Dictionary:
						Run.drain_fuel(6)
						return {text = "You cross the lane twice at full burn, the second time for no good reason. In the end they let you go, and the sprint costs a lot of fuel."}},
				{label = "Break it", fight = true, effect = func() -> Dictionary:
					return {text = "You attack the line. They do not expect it, and they are slow to respond.", fight = true}},
			],
		},
		{
			id = &"salvage_rights",
			subject = {layers = [{stage = &"single", pieces = [&"r3_frame_gutted_frame_1"], dark = 0.7, window = [40, 34], at = Vector2(-20.0, -50.0)}, {stage = &"single", pieces = [&"ship_catamaran"], size = 0.5, lights = &"run", at = Vector2(-150.0, 30.0)}, {stage = &"fx", fx = &"moor", from = &"ship_catamaran", from_at = [0, 16], to = &"r3_frame_gutted_frame_1", to_at = [14, 60]}]},
			title = "Salvage rights",
			body = "A wreck lies open along its length, and another crew is already on it. Their cutter ship is anchored at the stern with floods on and gear out. Half the racks are gone. They watched you arrive and did not hail. Out here, salvage belongs to whoever holds the cutter, and they do. The bow section is untouched.",
			tags = [&"salvage", &"contract"],
			group = &"wreck",
			weight = 11,
			max_danger = 6,
			regions = [MapGen.Region.LAWLESS, MapGen.Region.TERRITORY],
			min_danger = 2,
			choices = [
				{label = "Work the bow", effect = func() -> Dictionary:
					return {text = "You take the bow while they take the stern, and neither ship speaks. When the good rack comes free, they put their floods on you for a second to show they saw. Then they go back to work.", module = true}},
				{label = "Find what they missed",
					check = {attr = &"sensors", need = 5},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(35))
						return {text = "Your dish maps the hull's voids. It finds a sealed transfer hold their cutting line went straight past. Inside is a module, still racked, and a sealed bale of cargo nobody opened. You are gone before they finish the stern.", module = true},
					clean = func() -> Dictionary:
						return {text = "You read the frame, find the one section their floods never swept, and pull a rack out of it clean. They notice and let it go.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(36))
						return {text = "Their cut got everything worth mounting. What is left is small and loose. You sweep what you can of it out of the open sections with their floods tracking you the whole time."},
					botched = func() -> Dictionary:
						Run.add_credits(-25)
						return {text = "You cut into the section their anchor line is braced on, and they stop work. You pay them to keep it from becoming a fight, with their floods on your cockpit."}},
				{label = "Leave it to them", stay = true, effect = func() -> Dictionary:
					return {text = "You leave the wreck to them. Their floods follow you out of sensor range."}},
			],
		},
		{
			id = &"still_under_warranty",
			title = "Still under warranty",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"], tumble = 1.0},
			body = "A wreck drifts past with a Verity plate still bright on its flank, and something aboard is still live. A service handshake pings you every ninety seconds, the same three tones each time. It asks any passing hull to name itself. The crew that should answer is gone, but the bay has kept asking for a long time.",
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
						return {text = "You answer with your own registry, and the wreck accepts it at once. Service bays cycle open down the flank and release the parts under warranty to you.", module = true},
					clean = func() -> Dictionary:
						return {text = "The handshake takes your registry on the second try. One bay opens, and what is racked inside comes free clean.", module = true},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The wreck accepts you, but the bays stay shut. All it will release is the courtesy locker beside the lock. Inside are a few sealed spares with Verity's name on the wrap."},
					botched = func() -> Dictionary:
						Run.add_credits(-15)
						return {text = "The handshake flags your registry as the wrong holder of record. The bay lock arcs the moment your grapple touches it. The scoring down your flank costs credits to make right."}},
				{label = "Strip it regardless", effect = func() -> Dictionary:
					return {text = "You cut the racks out while the handshake keeps pinging every ninety seconds. It is still pinging when you leave.", module = true}},
			],
		},
		{
			id = &"collapsed_lane",
			title = "Collapsed lane",
			subject = {layers = [{stage = &"row", pieces = [&"r3_frame_gutted_frame_1", &"r3_frame_gutted_frame_2"], count = 2, near = 0, mid = 2, gap = 3.0, span = 440.0, dir = Vector2(1.0, -0.06), at = Vector2(0.0, -62.0)}, {stage = &"single", pieces = [&"r3_frame_gutted_frame_2"], at = Vector2(-30.0, 62.0)}]},
			body = "The short way runs through a shipbreaker's yard. It is a lane of dead hulls packed so close the dish reads them as one long wreck. Spars cross the gap at every height, left where they lay when the money stopped. Going around costs a day. Going through costs nothing if nothing touches you, and it saves fuel.",
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
						Run.fuel += 2
						return {text = "Your plating scrapes the length of the lane and holds. Spars pass close enough to read the breakers' chalk marks. You come out the far side with all the fuel you would have spent going around."},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A spar in the shipbreaker's lane opened the bow.")
						Run.fuel += 2
						return {text = "Something gives near the bow, but you keep going and keep the fuel. The bow needs repairs later."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A spar went through the forward plating and stayed there.")
						return {text = "Halfway in, a spar goes through the forward plating and sticks. You reverse out the way you came, slowly, with the spar still in the hull."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead hull folded the bow in the breaker's lane.")
						return {text = "Two hulls shift and close on you in the lane. Your ship comes out the far side badly damaged."}},
				{label = "Go around", stay = true, effect = func() -> Dictionary:
					return {text = "You take the long way around the yard. The trip is safe, and it costs you a day."}},
			],
		},
		{
			id = &"drifting_lifepod",
			title = "Drifting lifepod",
			subject = {stage = &"single", pieces = [&"r2_lifepod_lifepod_1"], tumble = 14.0},
			body = "A lifepod tumbles across your bow with a weak transponder, fading like a battery that has been dying for months. The viewport is frosted from the inside, so someone is still in there, or was. Another ship has been here first. The lock housing carries a fresh weld that is not part of any pod's design.",
			tags = [&"signal"],
			group = &"",
			weight = 10,
			max_danger = 4,
			choices = [
				{label = "Crack it open", effect = func() -> Dictionary:
					if Rng.event.randf() < 0.6:
						Run.add_credits(OptionTable.purse(25))
						return {text = "You take it on the grapple and cycle the lock from the board. The fresh weld is a scavenger's charge, and it fails to fire. There is no one inside, only cargo you can sell, packed where a person should be."}
					Run.take_hull_damage(OptionTable.toll(5), "The fresh weld on a lifepod was a scavenger trap, and it fired against the hull.")
					return {text = "The fresh weld is a scavenger trap. It fires when the seal breaks and goes off against your hull."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You let it tumble on. Its transponder is still going, weaker, when it leaves sensor range."}},
			],
		},
		{
			id = &"the_dust_cloud",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"dust", warm = true, at = Vector2(40.0, -6.0), radii = Vector2(235.0, 118.0), tilt = -8.0, dens = 0.9}, {stage = &"single", pieces = [&"ship_scoop"], dark = 0.8, dust = 0.6, at = Vector2(40.0, 12.0)}]},
			title = "The dust cloud",
			body = "The star has been shedding for a long time. What comes off collects here as warm dust, too fine to see until it is on you. Everything in this system is coated with it on the side facing the light. It will stick to your radiators too, and it does not come off by itself. Deep in the thickest part of the cloud is a mining ship, dusted over, holds shut, drifting. Nothing here moves fast enough to have wrecked it. It just stopped.",
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
						return {text = "It shifts, then settles back into the cloud. You spend an hour on it and come away with nothing but a hot ship."},
					botched = func() -> Dictionary:
						Run.heat += 16
						Run.take_hull_damage(OptionTable.toll(4), "Star dust got into the intakes faster than the vents could clear it.")
						return {text = "It comes free all at once, and a slab of the crust goes straight into your intakes. The hull holds, but the vents behind it fail."}},
				{label = "Fly the cloud with a hold open", effect = func() -> Dictionary:
					Run.heat += 9
					return {text = "You open one hold and fly the length of the cloud slowly. The dust packs into the corners and heats the ship the whole way. You end up with a hold of fine metal the star threw off.", material = &"mining"}},
				{label = "Keep clear of the cloud", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the lit side of the system and leave the mining ship where it is."}},
			],
		},
		{
			id = &"the_water_stop",
			title = "The water stop",
			subject = {stage = &"field", pieces = [&"r5_tank_pressure_tank_1", &"r4_tank_pressure_tank_2", &"r5_tank_pressure_tank_2", &"r5_tank_pressure_tank_1"], count = 4, near = 2, turns = 14.0, span = 400.0, height = 170.0, seed = 15, tumble = 2.0},
			body = "Two people run a water stop sunward of here. For eleven years they have held tanks of ice out in the light and sold the melt water to passing ships. The plant was parked in a stable orbit and has no engine. Now the orbit is slowly decaying toward the star. They have been asking every ship on the open channel for a tow for a while. There is not much traffic.",
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
						return {text = "You put your nose against the plant and hold a slow burn for forty minutes. It puts them back where they were eleven years ago. They pay out of a box under the console and count it twice."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						return {text = "The tow takes longer than either of you expected, but it puts them high enough to stop worrying. They pay what they said they would, though the orbit will need fixing again."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(7))
						return {text = "You get them moving and the line slips before they are anywhere near safe. They are higher than they were and not high enough. They pay you something for the try, because they will be asking again next month."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A water plant the size of a station swung into the ship under tow.")
						return {text = "The line goes tight off centre, and the plant swings around fast and hits your side. The plant is not damaged."}},
				{label = "Sell them fuel instead", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(18))
					return {text = "They have thrusters on the tanks and nothing to run them on, so you sell them two units at a fair price. They will burn it a little at a time and climb out on their own over the next month. It pays less than the tow, and you cannot refill until the next station."}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck and go. Their orbit gives them a few months yet."}},
			],
		},
		{
			id = &"the_lit_side",
			title = "The lit side",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"]},
			body = "A dead freighter has kept the same face to the star for decades. Dust has baked onto the lit side year after year until it went hard and clear like amber. You can see the layers in it. The cold side is bare metal, and its holds would open after an hour of cutting. Working the lit side means sitting in the light for as long as it takes.",
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
						return {text = "You sit in the full light and take the glaze off in plates. It comes away solid and warm, with decades of layers stacked in order. It goes into the hold hot and stays hot for a long time.", material_id = &"corona_amber"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get a good amount off before the vents start falling behind. What you have is worth the heat. The last plate brings a strip of hull with it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 14
						return {text = "The glaze is welded to the plating underneath. The cutter is doing more heating than cutting. You give it up. Your ship is hot and your hold is empty."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(5), "Ten minutes too long in the full light. The vents never caught up.")
						return {text = "You stay ten minutes longer than the vents can handle. Nothing catches fire, but systems fail one after another, starting on the lit side."}},
				{label = "Take the cold side instead", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You sit in the freighter's shadow. Holding that spot burns a slow drip of fuel for the whole hour. The holds on the cold side have ordinary cargo in them. You take some.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go."}},
			],
		},
		{
			id = &"paying_for_shade",
			title = "Paying for shade",
			subject = {stage = &"single", pieces = [&"paint_rock_a1"], r = 96.0},
			body = "One rock in this system holds a stable position and throws a shadow long enough to hide a dozen ships. Two ships got here first and hold the near edge. They charge for a spot, cash up front, and say so on the open channel to everyone who comes in. The instruments put the next flare about ninety minutes out. Further back in the shadow is forty years of what people left when they ran: cargo, a dead ship, and loose plate.",
			tags = [&"hazard"],
			group = &"",
			weight = 10,
			min_danger = 5,
			max_danger = 6,
			needs_star = MapGen.Star.RED,
			choices = [
				{label = "Pay for a spot", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "You pay, take the spot they give you, and sit out the flare with everything turned down. When the grapple goes out for a piece of the loose plate further back, no one objects. They charged only for the shade.", material = &"wreck"}},
				{label = "Take a spot without paying",
					check = {attr = &"stealth", need = 6},
					met = func() -> Dictionary:
						return {text = "You come in cold along the back edge and sit among the dead ships. The flare comes and goes, and no one calls you on the channel. On the way out you take the best thing you were parked next to.", material = &"wreck"},
					clean = func() -> Dictionary:
						return {text = "You get a poor spot at the edge, half in the light, and hold it. It is uncomfortable and it is free. Something small drifts against the hull while you wait, and you keep it.", material = &"event"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The edge of the shadow moves during the flare, and you do not keep up. You spend the worst of it with a third of the ship in the light. You come out hot, with an empty hold."},
					botched = func() -> Dictionary:
						Run.heat += 18
						Run.take_hull_damage(OptionTable.toll(5), "You were pushed out of the shade, and the flare hit you in the open.")
						return {text = "They find you inside twenty minutes and keep a light on you until you leave. The flare arrives while you are out in the open."}},
				{label = "Move on before it hits", stay = true, effect = func() -> Dictionary:
					return {text = "You are out of the inner system before the readings climb far. You give up the shade and everything sitting in it."}},
			],
		},
		{
			id = &"the_century_log",
			site = &"star",
			subject = {stage = &"single", pieces = [&"ship_science"], size = 0.5, dark = 0.7, bake = 0.5, lights = &"shaded", at = Vector2(-110.0, -80.0)},
			title = "The century log",
			body = "A machine in a close orbit here has measured the star once an hour for a hundred years, through every flare. Stars this size are hard to predict, so a century of readings is worth money to anyone who flies near them. The people who put it there stopped answering long ago. The heat is cooking it now, and only its shaded half still works. After every flare it sends a summary to a receiver that is no longer there.",
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
						return {text = "You match its roll, put the dish on it, and pull down the whole hundred years in one pass. The grapple also takes the instrument head off its mount, still cold and still good.", module = true, material_id = &"survey_film"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get the link and about forty years of readings before the working half rolls away from you. The grapple takes a panel off the housing as you pass.", material_id = &"survey_film", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The link wants an access code no one has sent in a century, and you cannot find it in time. You come away with a piece of the housing and none of the readings.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 24
						Run.take_hull_damage(OptionTable.toll(4), "You were caught on the lit side of the machine, in full starlight.")
						return {text = "You misjudge the roll and come around on the lit side, with nothing between you and the star for a few seconds."}},
				{label = "Answer it", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Its summaries carry the return frequency. You send a receipt on it in the format the machine expects, and it treats the job as finished. It sends you everything it has, which takes eleven hours with the reactor idling. Then it stops transmitting.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and go. It keeps taking readings while you are in range."}},
			],
		},
		{
			id = &"the_failing_shade",
			title = "The failing shade",
			subject = {stage = &"single", pieces = [&"r4_shade_foil_shade_idea2"], tumble = 1.0},
			body = "Someone built a shade here. It is foil on a frame, kilometres across, hung between the star and a lane that would be useless without it. It is still up. Over the years, things have collected in the cool behind it: three wrecks, a fuel ship, and loose cargo. One edge of the frame is buckling. When it goes, the whole shade goes, and everything behind it gets the full heat of the star.",
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
						return {text = "You spend too long choosing between the three wrecks, and the frame gives way first. You leave with an empty hold, after taking the starlight in the open."},
					botched = func() -> Dictionary:
						Run.heat += 26
						Run.take_hull_damage(OptionTable.toll(4), "The shade's foil came down on you, with the star straight behind it.")
						return {text = "The buckled edge lets go along its whole length, and the rest of the frame follows. A sheet of foil the size of a town comes down across you. Then nothing stands between you and the star."}},
				{label = "Hold the frame up", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You put the grapple on the buckled edge and hold it straight on thrust. The long burn buys you hours instead of minutes. You work the fuel ship at your own pace with the shade steady over you. It is still up when you let go, but it will not last the year.", material = &"wreck"}},
				{label = "Leave the shade alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log what is behind it and fly on."}},
			],
		},
		{
			id = &"sixty_containers",
			title = "Sixty containers",
			subject = {stage = &"field", pieces = [&"r2_sixty_long_box_sun_bleached_1", &"r2_sixty_short_box_sun_bleached_1", &"r5_sixty_box_burst_open_1", &"r2_sixty_long_box_sun_bleached_2", &"r2_sixty_short_box_sun_bleached_2"], count = 7, near = 2, deep = 2, turns = 25.0, band = -8.0, lift = 30.0, span = 440.0, height = 220.0, seed = 6, tumble = 3.0},
			body = "A hauler broke up here a while ago. More than sixty of its containers are spread across the approach in the light. The light has burned every label off and cooked the seals. Some of the contents are unharmed and some are ruined, and from outside you cannot tell which. Metal, ore and tools survive the light. Medicine, film and anything with a circuit do not.",
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
						return {text = "You scan the containers one by one for mass, density, and how each has warmed. After two hours you know which eleven are worth opening. Inside are plate and a rack of parts the light never reached.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "The dish gives you a rough sort, good enough to skip the worst of them. Two hours in the light heats the ship. You come out with one container of something the light could not hurt.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 12
						return {text = "The readings all look the same after the first hour. You open the ones that seem heaviest and get one good container in five. The rest is cooked stock, and the ship is hot from the sorting.", material = &"event"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "You spent three hours in a blue hypergiant's light, sorting containers.")
						return {text = "You spend three hours in the light reading numbers that never add up. All four containers you open hold ruined stock, and your own lit side is worn thin."}},
				{label = "Open them at random", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You do not have two hours, so you open whatever is nearest. Stopping and starting costs fuel. Of six containers, five hold ruined stock and one holds something the light could not hurt.", material = &"wreck"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You log the containers and move on."}},
			],
		},
		{
			id = &"the_shield_job",
			title = "The shield job",
			subject = {stage = &"single", pieces = [&"role:hauler"], lights = &"run"},
			body = "A small freighter is calling for an unusual kind of help on the open channel. The light here has burned out its dish array, as it does to anything pointed at the star. The pilot cannot fit the spare, because it would start cooking on the mount. She needs something big to sit between her ship and the star for about an hour. She is offering good money, and she knows that sitting still here costs hull.",
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
						return {text = "You put the ship between her and the star and hold. Your lit side comes out polished but otherwise undamaged. She has the spare mounted in fifty minutes and pays for the full hour anyway."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.take_hull_damage(OptionTable.toll(2), "An hour in a blue hypergiant's light, shielding a stranger's dish.")
						return {text = "You hold the hour. The plating on your lit side is measurably thinner at the end of it. She gets the array mounted and pays what she offered."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(3), "You held forty minutes for a stranger's dish. The plating gave out at thirty.")
						return {text = "You hold forty minutes before your plating readings force you to stop. She gets the array half mounted and finishes it badly in the shadow of her own hull. She pays for the forty minutes."},
					botched = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(8))
						Run.take_hull_damage(OptionTable.toll(5), "You sat in a blue hypergiant's full light for an hour, and the plating failed.")
						return {text = "You misjudge what an hour costs here. She gets the array mounted, but your lit side is badly worn, and her money does not cover the repairs."}},
				{label = "Tow her into a shadow instead", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You tow her to a rock forty minutes away with a shadow the right size. It costs fuel and most of a day. She swaps the array in the dark at her own pace and pays less than she offered for the shielding."}},
				{label = "Leave her", stay = true, effect = func() -> Dictionary:
					return {text = "You wish her luck and fly on. She goes back to calling, but there is not much traffic here."}},
			],
		},
		{
			id = &"the_comet",
			site = &"star",
			subject = {stage = &"single", pieces = [&"paint_moon_ice"], lumpy = 7.7, r = 11.0, tail = true, at = Vector2(-120.0, -72.0)},
			title = "The comet",
			body = "A comet is passing close to the star, which is boiling it. Its tail is a hundred thousand kilometres of water, gas and rock, lit white. It points straight along the lane you need. It holds more clean water than all the station tanks within a week of here. It also holds more fast-moving rock than the dish can count, none of it small. Riding the tail puts fuel in the tank. Riding it badly can destroy the ship.",
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
						Run.fuel += 5
						return {text = "You put the nose into the tail and hold it there for eleven minutes. You correct the whole time as rock goes past on both sides. Five units go into the tank, and ice packs into the open hold.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 10
						return {text = "You get three units before the rock gets too thick to fly through. The ship is hot from the light and will take an hour to shed the heat."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "Rock in a comet's tail.")
						return {text = "You get eight minutes in the tail before a rock the size of a door hits you. The tank takes one unit, and the hull has a matching dent."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Went into a comet's tail at the wrong angle.")
						return {text = "You go in at the wrong angle, and the tail throws you sideways for six kilometres through rock and ice. The tank is no fuller than it was."}},
				{label = "Skim the edge for ice", effect = func() -> Dictionary:
					Run.heat += 14
					Run.fuel += 2
					return {text = "You keep to the thin edge of the tail, where the rock is rare and the ice is too. It takes an hour in the light. Two units of water go into the tank. The ship spends the next hour shedding heat."}},
				{label = "Wait for it to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the lane for the three days it takes the comet to pass."}},
			],
		},
		{
			id = &"the_beacon_job",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"buoy", at = Vector2(-60.0, 0.0), tether = &"r2_container_freight_box_2"}, {stage = &"single", pieces = [&"r2_container_freight_box_2"], dark = 0.2, bake = 0.3, at = Vector2(40.0, 30.0)}]},
			title = "The beacon job",
			body = "A navigation beacon on the lane inward is dead. The light here kills a circuit board in about four days. Its owners keep a crate of spare boards tethered beside it. A standing offer is painted on the crate: swap the board, key in the job number, and the fee clears. No one is here to watch, and no one has been for a while. The crate has eleven boards left.",
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
						return {text = "You pull the dead board with the grapple and seat a new one in nine minutes, before the light can damage it. The beacon comes up, you key the number, and the fee clears."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes two boards. The first cooks in the grapple before it is seated, and the second goes in fast. The beacon comes up. You key the number and are paid for one swap."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 14
						return {text = "The beacon comes up for forty seconds and goes dark again. You key the number anyway and get a partial fee. The crate has ten boards left."},
					botched = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(4), "Working a dead beacon in the full light of a blue hypergiant.")
						return {text = "You are still working when the board in the grapple slips. The beacon housing tears a piece off your hull, and the beacon stays dark. The crate has ten boards left."}},
				{label = "Take the crate", effect = func() -> Dictionary:
					Run.heat += 10
					return {text = "Eleven sealed boards are worth more at a station than one swap pays. You spend ten minutes in the light cutting the tether and take the crate. The beacon stays dark.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the beacon as dead and fly the lane by dead reckoning."}},
			],
		},
		{
			id = &"the_sorting",
			site = &"star",
			subject = {layers = [{stage = &"fx", fx = &"drift"}, {stage = &"group", anchor = &"star", d = 150.0, ships = [{piece = &"r4_scatter_cabin_section_1", at = Vector2(0.0, 0.0)}, {piece = &"r4_scatter_tank_half_1", at = Vector2(100.0, 0.0)}, {piece = &"r4_scatter_drive_nozzle_1", at = Vector2(185.0, 0.0)}]}]},
			title = "The sorting",
			body = "The light here is strong enough to push things, slowly but without stopping. Over years it moves anything loose, light things quickly and heavy things slowly. So the wreckage in this system has been sorted. Foil, film, plastic and other light salvage were blown out to the cold side years ago. The heavy parts are still here in the light: keels, reactor housings and armour plate. Working them means working in the light.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_star = MapGen.Star.BLUE,
			choices = [
				{label = "Work the heavy field",
					check = {attr = &"hull", need = 8},
					met = func() -> Dictionary:
						return {text = "Your plating holds for the afternoon it takes. You come away with armour plate, a reactor housing and heavy keel bolts, all still good.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "The light wore through the hull in an afternoon on the heavy field.")
						return {text = "You get most of an afternoon before your lit side starts to wear thin. You take the best of the heavy field, at a cost in hull.", module = true, material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "You stayed in the heavy field an hour too long, and the plating gave out.")
						return {text = "You get one good piece off a keel before your plating readings force you out. The damage to your lit side costs more than the piece is worth.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "The light stripped your plating in the heavy field.")
						return {text = "You stay too long, and the light does to your plating what it has done to everything else here. You leave with nothing in the hold."}},
				{label = "Chase the light things outward", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					return {text = "You burn out to the cold side and spend a long day among what the light pushed there. Most of it is worthless, but you take the film and foil that stayed out of the light.", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log both halves of the field and go."}},
			],
		},
		{
			id = &"clean_hull",
			title = "Clean hull",
			subject = {stage = &"single", pieces = [&"ship_lrshuttle"], lights = &"run"},
			body = "A ship holds a long way out from the star. The pilot wants it towed in close until the light burns off every marking: registry, yard numbers and name. Then he wants it towed back out. He says his drive is out, and a ship with no drive drifts in the light. He says a day will do it. He does not say why, and no one out here asks. He pays well for the tow both ways.",
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
						return {text = "You tow him in and hold beside him for a day while the star burns his ship's name off. Then you tow him out. Your lit side comes out polished but otherwise undamaged. He pays in full without a word."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "You spent a day in a blue hypergiant's light for a stranger.")
						return {text = "You hold beside him for the day, and your plating wears thin enough to need repair. His ship comes out clean, and he pays what he said."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "You held a stranger's ship in the light, and your plating gave out before his paint did.")
						return {text = "The day is too long for your plating, so you pull him out with his markings half gone. They cannot be read, but they are not clean. He pays for half a job, unhappily."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "You spent a day in a blue hypergiant's full light for a stranger.")
						return {text = "You stay the day, and your plating suffers badly. His ship comes out bare, but you have to leave before you can tow him out, so he pays nothing."}},
				{label = "Tow him in and come back tomorrow", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You tow him in, let go, and pull back out of the worst of the light. A day later you go in for him. He has drifted, and the burn is uneven, but his name is gone. He pays for two tows and not for the day."}},
				{label = "Decline the job", stay = true, effect = func() -> Dictionary:
					return {text = "You tell him no, and he takes it well. He is still holding there when you leave, waiting for the next ship."}},
			],
		},
		{
			id = &"lost_in_the_gas",
			subject = {stage = &"none"},
			title = "Lost in the gas",
			body = "A hauler is calling on the open channel from somewhere inside the cloud. Its two crew are low on fuel and lost. Their small dish cannot see through the gas, and they have no fix and no stars. Their heading stopped being any use an hour ago. They can hear you but cannot tell where you are. They will pay for directions out, and more for a ship that comes in and gets them.",
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
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You lose them twice and find them once. In the end you burn out to the edge of the cloud yourself, so they have something bright to steer at. They make it and pay what little they have left."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.take_hull_damage(OptionTable.toll(3), "Went into the gas after a lost hauler, and found a rock first.")
						return {text = "You give them a wrong heading, and they burn on it for twenty minutes before either of you knows. You go in after them, and the gas hides a rock the size of a station until you are nearly on it. You get them out in the end, but they cannot pay."}},
				{label = "Go in and get them", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(24))
					return {text = "You go in on the bearing of their voice and find them the slow way, with the lights on. Then you lead them out, close, so they can see your drive. It costs fuel to fly slowly in gas. They pay the higher price without being asked."}},
				{label = "Leave them to find their own way", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them which way the edge is, as best you can, and go on. They thank you, though it is not much help."}},
			],
		},
		{
			id = &"the_dropped_pod",
			title = "The dropped pod",
			subject = {stage = &"single", pieces = [&"r2_pod_cargo_pod_1"], tumble = 3.0},
			body = "A transponder in the cloud says it is a cargo pod. Haulers drop these when they have to lose weight fast, and they mean to come back. No one has come back for this one. The gas scatters the signal, so the bearing wanders five degrees one way, then ten the other. You will not see the pod until you are close enough to grapple it. The gas here is thick enough to hide rocks too.",
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
						return {text = "You follow the ping, correcting each time the bearing jumps and slowing where the gas thickens. The pod is where the last ping said, sealed and cold, with its cargo still inside.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It takes longer than the ping suggests, crawling most of the way with the lights on. The pod is there, and so is a rock that would have hit you at speed.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "The bearing walks you in a circle twice before you catch on. You find the pod's tether. You find a case that came off it. You never find the pod.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You followed a cargo pod's ping into the gas and hit a rock.")
						return {text = "You come around a bank of gas at speed and there is a rock in it. The pod is somewhere on the far side, still pinging. You do not stay to find out where."}},
				{label = "Fly a slow search pattern", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You give up on the bearing and fly a search box slowly, with the lights on, one leg at a time. It costs fuel. You find the pod's tether, one case, and enough of the pod to know someone else got here first.", material = &"event"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the pod and go."}},
			],
		},
		{
			id = &"the_cache",
			title = "The cache",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_b3"], r = 60.0, at = Vector2(-145.0, 22.0)}, {stage = &"field", pieces = [&"r2_cache_sealed_canister_1", &"r2_cache_sealed_canister_2"], count = 8, near = 2, deep = 3, turns = 20.0, lift = 20.0, span = 230.0, height = 160.0, seed = 11, tumble = 3.0, at = Vector2(45.0, -6.0)}]},
			body = "Half a kilometre off the lane, deep in the cloud, eight sealed containers hang on a tether between two rocks. You only see them because your lights are on. They are all alike, marked with the same code and nothing else. In the open, any dish would find them within an hour, but no one searches in here. Someone hid them on purpose and plans to come back.",
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
						return {text = "You cut the tether at both ends and take the whole string aboard in an hour, and no one comes. Six hold supplies worth nothing to you. One holds a ship's part, still packed. The last holds what they were hiding, with no name on it.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "You get six of the eight aboard. Then another ship's lights show in the gas, a long way off and closing. You leave the last two and go. It does not follow. Of the six, one is worth having.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "You have one container off the tether when the other ship's lights show. You go fast, with the one you have. It is not the good one.", material = &"event"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "One container in the cache was a trap, set to stop the other seven being taken.")
						return {text = "The second container from the end is a charge. It goes off when the grapple takes the tension off the tether. You spend the next hour checking what plating you have left."}},
				{label = "Cut one loose and go", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You cut the container nearest the lane and take it quickly. Matching the tether's drift in the gas costs fuel, and getting back out costs more. The other seven stay where they were put.", material = &"wreck"}},
				{label = "Leave it hidden", stay = true, effect = func() -> Dictionary:
					return {text = "You switch the lights off and back out the way you came, leaving the containers on their tether."}},
			],
		},
		{
			id = &"no_stars",
			subject = {stage = &"fx", fx = &"gas", k = 1.0},
			title = "No stars",
			body = "The gas has closed in, and there is nothing to steer by: no stars, no beacon and no fix. The dish reads the same cloud in every direction. The gyro heading was true when you entered, but it has drifted for an hour or two in an unknown direction. The gas is moving at a different speed from you, and you cannot measure the difference. Somewhere in this cloud is a rock the chart says is a hundred metres across.",
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
						return {text = "You stop, kill the drive, and let the dish listen. Over half an hour the gas thins in one direction and shows you two stars, enough for a fix. On the new heading you pass a hull the cloud has hidden for years and take what is loose off it.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It takes an hour of listening and two false starts before you see two stars and get a heading. You burn out on it, and it is right. The gas thins to show the lane."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You get one star and guess the second. The heading is out by ten degrees. You find that out slowly, over two hours of burning the wrong way. You come out of the gas a long way from where you meant to."},
					botched = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.take_hull_damage(OptionTable.toll(4), "Burned on a bad fix, in gas. The chart had the rock marked.")
						return {text = "You get a fix, trust it, and burn. The rock is where the chart said, but your fix was wrong about where you were."}},
				{label = "Burn straight up out of the plane", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You burn straight up, at right angles to the lane. You keep burning until the gas thins and the stars come back. Leaving the lane costs fuel. Coming back down to it costs more. On the way down you find a marker at the edge of the gas. Somebody left a supply case on it for whoever got lost next.", material = &"event"}},
				{label = "Wait for the gas to thin", stay = true, effect = func() -> Dictionary:
					return {text = "You kill the drive and wait for the cloud to move. After two days a thin patch passes with stars in it, and you go. It costs nothing but the two days."}},
			],
		},
		{
			id = &"the_dark_ship",
			title = "The dark ship",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"], tumble = 1.0},
			body = "Three kilometres off the lane, a ship is sitting dark. The gas is thick enough to hide it from any dish not pointed straight at it. It has no transponder, no drive and no heat, and it has gathered frost. It is either dead and unfound, or alive and hiding, and from here you cannot tell which. A dead ship like this is worth a great deal to whoever reaches it first.",
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
						return {text = "It has been dead for years, with frost inside as well as out. The hold was full when it stopped, and no one has found it. You take the best of it and log the rest.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It is dead, and cold. The cutter takes twice as long as it should. The gas will not sit still, so the fuel goes on holding station. What you get is worth it.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It is alive. It lights its drive when you are two hundred metres off and goes deeper into the cloud, fast. Getting clear of its wake costs fuel."},
					botched = func() -> Dictionary:
						Run.heat += 8
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a dark ship in the gas, and it was not dead.")
						return {text = "It is alive. Something hits your flank as it leaves, perhaps as a warning, and then it is gone into the gas. Your hull needs repairs."}},
				{label = "Watch it for a day", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold off in the gas with everything down and watch it for a day. Nothing changes. No heat, no drift, no light. Then you go closer, slowly. You take what is loose around it and never go alongside. Holding still in moving gas costs a day of fuel.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You go on along the lane and say nothing about it on the channel."}},
			],
		},
		{
			id = &"the_scoop",
			site = &"giant",
			subject = {stage = &"none"},
			title = "The scoop",
			body = "The banded giant fills the sky ahead, and its upper air is fuel. Every ship that passes here dips into it. Get low enough and the intakes fill themselves. Get too low and the air drags you in, hot enough to strip the plating on the way down. A shallow skim gets you free fuel. A dive gets you more, or destroys the ship.",
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
						Run.fuel += 3
						return {text = "You take it in one long, shallow pass with the nose glowing. You come out climbing, with three more units in the tank."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 8
						return {text = "You go in a little steep and come out a little hot. The tank takes two units. The hull takes an hour to cool, and you spend the hour climbing."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(2), "Skipped off the top of a gas giant's air, twice. The second one was hard.")
						return {text = "You skip off the top of the air twice by accident, and the second skip is hard. You get one unit of fuel, a hot ship and a dent."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "You dove into the giant's air too steeply.")
						return {text = "You go in too steep, and the air grabs you for ninety seconds with fire in the intakes. You climb out on the last of the burn with no more fuel than before and much less plating."}},
				{label = "Skim high and slow", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 1
					return {text = "You keep to the very top of the air. It is thin there, and the intakes take a long time to fill. An hour of skimming buys one unit. The ship is warm all the way through by the end of it."}},
				{label = "Leave the air alone", stay = true, effect = func() -> Dictionary:
					return {text = "You keep your altitude and go around."}},
			],
		},
		{
			id = &"the_breaking_moon",
			site = &"giant",
			subject = {layers = [{stage = &"single", pieces = [&"paint_moon_ice"], world = &"shattered", r = 30.0, at = Vector2(70.0, -70.0)}, {stage = &"single", pieces = [&"paint_rock_a1"], r = 7.0, at = Vector2(18.0, -34.0)}, {stage = &"single", pieces = [&"paint_rock_a2"], r = 5.0, at = Vector2(-8.0, -20.0)}, {stage = &"single", pieces = [&"paint_rock_b3"], r = 6.0, at = Vector2(-36.0, -6.0)}]},
			title = "The breaking moon",
			body = "The giant's innermost moon orbits too close, and it is coming apart. The planet pulls harder on its near side than its far side, and the difference is tearing it. Cracks a kilometre wide cross the surface. Sheets of crust lift off the near side and drift, exposing the moon's interior. It is dark metal that has never been mined, and it is worth a fortune.",
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
						return {text = "You go in slowly between the lifted sheets with the cutter running. You come out the other side with a full hold, untouched. Behind you, a piece of crust the size of a station turns over where you were.", material = &"mining"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "Clipped by a piece of a breaking moon.")
						return {text = "You fill the hold, but a piece of the moon hits your flank on the way out. The flank needs repairs.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "You spent a pass inside a breaking moon dodging sheets of crust.")
						return {text = "A sheet turns over faster than it should. You spend the pass avoiding it instead of cutting. You come out with a scraped hull and an empty hold."},
					botched = func() -> Dictionary:
						Run.heat += 10
						Run.take_hull_damage(OptionTable.toll(4), "Caught between two pieces of a breaking moon.")
						return {text = "Two sheets close with the ship between them. You burn out with the hull grinding on both sides. You do not stop burning until the moon is a long way behind."}},
				{label = "Take what drifts clear", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You sit a safe distance out and wait. Every few hours a piece of the interior drifts clear of the sheets, and you take the best one with the grapple. Holding station for the day costs fuel, but it is safe.", material = &"mining"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the moon and fly on. It has been breaking up for a thousand years and will go on for a thousand more."}},
			],
		},
		{
			id = &"the_rings",
			site = &"giant",
			near = {ring = true},
			subject = {stage = &"ring_arc", pieces = [&"place_derelict", &"ship_cl_drums", &"r3_frame_gutted_frame_2", &"ship_lattice"], u = [-0.6, -0.86, 0.78, 0.6], lift = [-2.0, 1.0, -1.0, -16.0], size = 0.25, dark = 0.8},
			title = "The rings",
			body = "The giant's rings are mostly ice and rock, a few metres thick and a hundred thousand kilometres across. They have been catching things for longer than anyone has been here. Anything that enters orbit at the wrong angle ends up in the ring plane and goes around with the rest. The dish counts eleven hulls in the near arc alone. To reach one, you fly in the plane at ring speed, with ice on every side.",
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
						return {text = "You match the ring's speed, so the ice hangs still around you, and pick your way through it. The nearest hull is a whole freighter that has circled with the ice for a long time.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(1), "A piece of ring ice, at ring speed.")
						return {text = "You get to the freighter with one knock on the way in. You take one more on the way out. Both come from ice you never saw. The hold is worth both.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 10
						return {text = "You get into the plane and cannot hold it. The ice keeps finding you, and you climb out hot and empty before it finds you properly."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Came into the ring plane at the wrong speed.")
						return {text = "You come into the plane only a few metres a second off ring speed, and that is enough. A lot of ice hits you. By the time you are out of the plane, many systems have failed at once."}},
				{label = "Hold above the plane and fish", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold just above the ring, matching its speed. You drop the grapple into it on a long line and pull up what it catches. Mostly ice. Once, something better, off a hull you never see. Holding above a ring for a day costs fuel.", material = &"wreck"}},
				{label = "Leave the rings alone", stay = true, effect = func() -> Dictionary:
					return {text = "You log the eleven hulls and go on."}},
			],
		},
		{
			id = &"the_sunken_freighter",
			title = "The sunken freighter",
			subject = {stage = &"single", pieces = [&"r5_split_derelict_1"]},
			body = "A freighter went into the giant's air eleven years ago and did not come out. It was a gas-mining hull built for pressure, so it was not crushed. It floats at the depth where the air holds it up and circles the planet with the wind. Its transponder still works, and its cargo is still aboard. At that depth the air would crush your ship in about twenty minutes and cook it in ten.",
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
						return {text = "You go down through the bands with the pressure climbing. The freighter is where the transponder said, its running lights still on. In eight minutes alongside, the cutter opens a hold and the grapple takes the best of it. You climb out with the hull creaking.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Twelve minutes at a depth that gives you ten.")
						return {text = "You stay twelve minutes at depth, two too many. Every panel of plating is dented, and the grapple brings up the one thing it could reach.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Went down to crushing depth, and came up with nothing.")
						return {text = "You get down to it. The plating starts to give before the cutter has finished. You have to climb. You bring up nothing but a hull that has been squeezed."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went down to a freighter at crushing depth, and came up too slowly.")
						return {text = "You go down, and the air catches you the way it caught the freighter. You climb out on the last of the burn, with the whole outer hull pushed in."}},
				{label = "Fish for it from above", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold at the top of the air and drop the grapple on its longest line. One of the freighter's holds is open. It takes a day to hook anything, and holding station in the wind costs fuel. You get what was nearest the door.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You leave it circling at depth, sinking a little lower each year."}},
			],
		},
		{
			id = &"the_storm",
			site = &"giant",
			near = {storm = {sv = Vector2(-0.42, -0.52), z = 0.55, w = 0.17}},
			subject = {stage = &"single", pieces = [&"ship_bored"], size = 0.25, far_k = 0.1, dark = 0.85, lights = &"battery", anchor = &"near", on = Vector2(-0.42, -0.52)},
			title = "The storm",
			body = "A storm the size of a small continent is carrying a mining ship around the giant. Its drives are dead, and the wind moves at six hundred kilometres an hour. Three crew are aboard. They call on the open channel each time the storm lifts them into range, then go quiet for an hour. They have circled for two days and think their pressure hull will last one more. They will pay anything for a line.",
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
						return {text = "You go into the top of the storm with their beacon on the dish and match the wind. That means six hundred kilometres an hour through air that pulls you down. The grapple takes them on the second pass, and you climb out together. They pay everything they promised."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(22))
						Run.take_hull_damage(OptionTable.toll(2), "Four passes into a storm on a gas giant, for three strangers.")
						return {text = "It takes four passes, and the storm grabs you on the third. You come out with their ship on the line and your plating scored from nose to tail. They pay in full."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Two lines into a storm on a gas giant. The storm kept most of the second.")
						return {text = "You get a line on them, lose it, and get it again. The second line holds and drags them up to where their thrusters can hold altitude. They finish the climb themselves and pay less than they promised."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(5), "Went into a storm on a gas giant after three strangers. It kept both ships.")
						return {text = "You go in after them, and the storm carries you around the planet for an hour. Then a gap opens, and you burn up through it with nothing on the line. They are still down there, calling."}},
				{label = "Wait for the storm to bring them up", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(16))
					return {text = "You hold above the storm for a day, burning fuel against the wind, and wait for it to lift them into range. It does, twice. The second time you get a line on them without going in. They pay less than they promised, and since you never went in, you do not argue."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them you cannot, and they say they understand. The storm takes them down again, and by the time they call again, you are out of range."}},
			],
		},
		{
			id = &"dead_boards",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 14.0, faint = true}, {stage = &"single", pieces = [&"ship_cl_tree"], dark = 0.9, drive = true, flip = true, at = Vector2(30.0, 0.0)}]},
			title = "Dead boards",
			body = "A pulsar two systems over sweeps its beam through here every fourteen seconds. At this distance it cannot hurt a hull, but it can kill an unshielded circuit board, and most are unshielded. A hauler in the lane ahead has lost its controls this way. Its drive is stuck on its last setting. It is pushing the ship toward the one part of the system where the beam is strong enough to matter. Its two crew are calling for a tow.",
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
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get them moving the right way. Then the line parts for good. They are drifting out of the beam now instead of into it. They will be clear in a day. They pay you for the direction."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "You towed a hauler whose stuck drive pulled against you.")
						return {text = "The line comes tight while their drive is still pushing on the old setting. The two ships pull against each other, and your hull comes off worse. They are no better off, and they do not pay."}},
				{label = "Sit between them and the beam", effect = func() -> Dictionary:
					Run.heat += 14
					Run.add_credits(OptionTable.purse(18))
					return {text = "You put your ship in the beam's path with theirs behind it. For two hours your hull takes the beam every fourteen seconds while they work around the dead boards. The ship heats up the whole way through. They pay less than they would for a tow."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck. They have a day before the beam is strong enough to matter. Another ship may come, or they may fix the boards."}},
			],
		},
		{
			id = &"the_glass_ring",
			title = "The glass ring",
			subject = {stage = &"structure", pick = true, pieces = [&"st_the_glass_ring_1", &"st_the_glass_ring_2"]},
			body = "An old station ring hangs in the lane, dead for longer than anyone has records. The pulsar's beam has swept it every four seconds the whole time. Over centuries it has left a glaze on the hull, as thick as the plating under it and in unusual colours. The glaze is worth a great deal to the right buyer. Every ninety minutes the beam's angle misses the ring for six minutes. You have six minutes to work.",
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
						return {text = "You go in on the first second of the gap and out on the last, with the cutter running the whole time. You bring back a warm plate of the glaze and a piece of the ring that came away under it.", material_id = &"sweep_glass", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "You need seven minutes, and the seventh is in the beam. You get out before it does more than heat you, with the glaze and a piece of the ring aboard.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 18
						return {text = "You are still finding the angle when the gap closes. You leave with a piece of the ring's frame and a second of the beam on your hull.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 28
						Run.take_hull_damage(OptionTable.toll(4), "Took a full sweep of the beam alongside the glass ring.")
						return {text = "You misjudge the gap by a full sweep and take four seconds of the beam at this range. No ship is built for that. You leave with nothing but heat."}},
				{label = "Take frame from the shadow side", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You never go near the glaze. The ring throws its own shadow. In it are pieces of the frame that fell clear of the beam's line a long time ago. Holding in a shadow that moves with the ring costs fuel. What you take is plain metal, and it is safe.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ring and the gap and leave the glaze for a faster ship."}},
			],
		},
		{
			id = &"the_drop_point",
			title = "The drop point",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_1"], tumble = 2.0},
			body = "This pulsar is slow, and its beam comes around once every thirty-one minutes. At this range one sweep is enough to destroy a ship, so everything here runs on that clock. Behind a rock the size of a city is the one shadow the beam never reaches. For a very long time, people have left crates, tanks and sealed cargo there for others, stacked and tethered. The beam is the only guard. You have thirty-one minutes to cross the open sky, load up, and get back.",
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
						return {text = "You are slow across the open and slower coming back, and the edge of the beam catches your stern. You get one crate and a hot ship.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 22
						Run.take_hull_damage(OptionTable.toll(2), "Turned back halfway to the shadow, and the beam caught the turn.")
						return {text = "Halfway across, you see there is not time to reach the shadow and get back. The beam catches you as you turn around. You come out with nothing and a damaged hull."},
					botched = func() -> Dictionary:
						Run.heat += 30
						Run.take_hull_damage(OptionTable.toll(4), "Caught in the open by a slow pulsar. It came around on minute thirty-one.")
						return {text = "You misjudge the clock, and the beam finds you in the open at minute thirty-one. When it has passed, you are drifting at the shadow's edge in a badly damaged ship."}},
				{label = "Hook what you can from the edge", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold at the edge of the shadow with the beam's line a hundred metres off your bow. You put the grapple in on a long cable and wait through three sweeps. You get what was nearest the edge.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the rock and the interval and go."}},
			],
		},
		{
			id = &"the_quiet_beam",
			subject = {layers = [{stage = &"group", glint = &"glaze", dark = 0.55, ships = [{piece = &"r3_frame_gutted_frame_2", size = 0.5, turn = -6.0, at = Vector2(-130.0, -92.0)}, {piece = &"place_derelict", size = 0.5, turn = 4.0, at = Vector2(20.0, -60.0)}, {piece = &"r5_split_derelict_1", size = 0.5, turn = -3.0, at = Vector2(120.0, -6.0)}]}, {stage = &"group", ships = [{piece = &"ship_courier2", size = 0.25, drive = true, lights = &"run", at = Vector2(150.0, -108.0)}, {piece = &"ship_catamaran", size = 0.25, drive = true, lights = &"run", at = Vector2(190.0, -86.0)}]}]},
			title = "The quiet beam",
			body = "For as long as anyone has counted, this pulsar's beam swept the system every second and a half. Two days ago it stopped, and no one knows why. Other pulsars have done this. Each time, the beam started again without warning, after an hour or a month. Until it does, you can reach the hulls that sat in its path for centuries, thick with glaze. Every ship within a week is coming for them, and the first are already here.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			needs_pulsar = true,
			choices = [
				{label = "Work until the last minute",
					check = {attr = &"sensors", need = 8},
					met = func() -> Dictionary:
						return {text = "You keep the dish on the pulsar the whole time you work. Six hours in, it shows the spin coming back into line. You leave with a plate of the glaze and a sealed unit off the nearest hull. You are eleven minutes clear when the beam returns.", material_id = &"sweep_glass", module = true},
					clean = func() -> Dictionary:
						Run.heat += 14
						return {text = "You read the pulsar right but cut it fine, and the first sweep catches your stern as you clear the lane. You get a plate of glaze and a piece of hull. The ship spends the day cooling.", material_id = &"sweep_glass", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 20
						return {text = "You cannot read the pulsar's spin on the dish, so you take one piece off the nearest hull and leave early. The beam comes back four hours later.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 32
						Run.take_hull_damage(OptionTable.toll(4), "Working a glassed hull when the beam came back.")
						return {text = "The beam comes back without warning while you are still working. It hits you twice before you get out of the lane and scorches the whole outer hull."}},
				{label = "Take what is nearest and go", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You take the first thing the grapple can reach off the nearest hull. Then you burn out of the lane and keep going until the beam's track is far behind you.", material = &"wreck"}},
				{label = "Stay out of the lane", stay = true, effect = func() -> Dictionary:
					return {text = "You stay well out of the lane with the dish on the pulsar and watch the other ships go in."}},
			],
		},
		{
			id = &"the_crossing",
			title = "The crossing",
			subject = {stage = &"herd", flip = true, pieces = [&"r3_crossing_old_one_1", &"r4_crossing_young_one_1", &"r3_crossing_old_one_2", &"r4_crossing_young_one_1"], count = 8, near = 2, span = 420.0, height = 200.0, seed = 4},
			body = "A herd of hundreds of megafauna is crossing the lane, slow and packed close. The young are in the middle and the old are on the outside. They barely move, and they cover the stretch of sky you need. They are not hostile, but they will not move for you or notice you. The smallest is the size of a hauler. Going around costs a day. Going through costs an hour, if none of them turns.",
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
						return {text = "You go through at their speed, the only speed that works, and none of them turns. Halfway across, an old one on the outside sheds a sheet of hide the size of your ship. You take it.", material_id = &"hide_scrap"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "It takes two hours and a lot of correcting. One of the young ones follows you part of the way. It is curious. Something that came off one of them drifts against the hull as you clear the far side. You keep it.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Brushed by the flank of something the size of a hauler.")
						return {text = "One of them turns, and its flank comes across your bow and scrapes the paint off. You get through with nothing but the scrape."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Between two of them when they closed.")
						return {text = "Two of them close in, slowly, with you between. You back out of the gap. The hull grinds on both sides. You go around after all, and it costs the day as well."}},
				{label = "Follow the old ones around the edge", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "The old ones keep to the outside, and the old ones shed. You follow the edge of the herd for a day at their pace. You take the one good piece that drops. Flying that slow for a day costs fuel. The herd does not mind you there.", material = &"fauna"}},
				{label = "Wait for them to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You hold off the lane while they pass. It takes most of a day and costs nothing else."}},
			],
		},
		{
			id = &"the_hunters",
			title = "The hunters",
			subject = {stage = &"single", pieces = [&"r3_carcass_whale_fall_2"]},
			body = "A small hunting ship has killed a megafauna the size of a station. The body hangs in the lane with the hunter alongside, cutting fast. The rest of the pod is two hours out and coming back. The hunters want the body towed to their tender before then and will pay for the tow. They will also sell a cheap share to anyone who would rather leave before the pod arrives.",
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
						return {text = "It is the heaviest thing you have ever towed. You get it to the tender with forty minutes to spare. They pay in full and start cutting again before the line is off."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 8
						return {text = "It takes everything the drive has and most of the two hours. The tender has the body under its cutters before the pod is on the dish. They pay what they said."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The line holds and the body barely moves. You get it half the distance. Then the pod shows on the dish. The hunters cut it loose and run. They pay you for the half."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Towing a dead one when the pod came back.")
						return {text = "The pod arrives while the body is still on your line. The first of them comes past close and slow, and its flank crushes your plating. It is not hostile, only careless. The hunters are gone, and no one pays."}},
				{label = "Buy a share", cost_credits = 45, effect = func() -> Dictionary:
					Run.add_credits(-45)
					return {text = "They cut you a share off the flank and take your money. You are gone before the pod shows on the dish.", material = &"fauna"}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish them luck and go. Two hours is enough time to be well away before the pod arrives."}},
			],
		},
		{
			id = &"the_singer",
			title = "The singer",
			subject = {stage = &"single", pieces = [&"pool_lev_throat"]},
			body = "An old megafauna the size of a station hangs alone, singing. Scars run the length of its leading edge. The song is loud on every channel and whites out the dish for a hundred kilometres. The rest of its pod is gone, and it stays where it is. It is dying slowly, and you can hear that in the song. A hunting ship two days out has been asking on the channel for one like this. They will pay for the bearing. Rendered, it is worth more than your ship.",
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
						return {text = "You go in slowly, close enough to see the scars. It knows you are there and ignores you. You take a sheet of hide it has shed, and something smaller that came away with it.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 8
						return {text = "You get close, and it turns slowly. You spend the next hour staying out of its way, and you take what came loose in the turn.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Too close to a singer when it turned.")
						return {text = "It turns, and you are in its way. You come away with a scraped hull and nothing else."},
					botched = func() -> Dictionary:
						Run.heat += 12
						Run.take_hull_damage(OptionTable.toll(4), "Too close to a singer when it rolled.")
						return {text = "You are close alongside when it rolls, and its weight comes down on your ship for a moment. You come away with nothing and a hull that needs a yard."}},
				{label = "Sell the bearing", effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(20))
					return {text = "You give the hunting ship the bearing, and they pay before you finish reading it out. They will be here in two days, and you will be long gone."}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You go. The song stays on every channel for a hundred kilometres, and you tell no one about it."}},
			],
		},
		{
			id = &"turning_the_herd",
			title = "Turning the herd",
			subject = {stage = &"herd", flip = true, pieces = [&"r4_turning_the_turning_herd_1", &"r2_turning_the_turning_herd_idea3", &"r4_turning_the_turning_herd_2"], count = 9, near = 3, span = 420.0, height = 190.0, seed = 8},
			body = "A herd of two hundred megafauna is drifting toward the station's approach lane. A small ship with one pilot is trying to turn them. She is running every light she has along the near flank, and it is not enough. If the herd reaches the lane, everything inbound for a week must go around or through it. She is asking for a ship to take the far flank, lights on and drive loud. She says the station will pay her, and she will pay you.",
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
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get half of them turned. The other half go through at their own pace, and the lane is a mess for a week. She pays you for the half, and the station pays her for the half."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Too close to the herd's flank. One of them turned the wrong way.")
						return {text = "You get too close to the flank, and one of them turns toward the noise instead of away. Its side comes across your bow and takes a metre of plating. The herd goes into the lane, and no one pays."}},
				{label = "Make noise on the herd's channel", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "You fill the frequency the herd calls on with noise from your dish. The herd leans away from the noise and slowly turns. It is slower than flying a flank, and it heats the dish and everything behind it. She pays less than she offered for the flank."}},
				{label = "Leave her to it", stay = true, effect = func() -> Dictionary:
					return {text = "You wish her luck and go. The herd is a day from the lane, so she still has some time."}},
			],
		},
		{
			id = &"the_grazing",
			title = "The grazing",
			subject = {layers = [{stage = &"around", base = &"paint_moon_ice", r = 70.0, loose = true, apart = 8, pieces = [&"r3_grazing_feeder_2"], count = 7, size = 0.5, rx = 112.0, ry = 62.0, tilt = 14.0, seed = 7}, {stage = &"field", pieces = [&"r5_grazing_shed_plate_1"], count = 3, near = 0, deep = 1, turns = 70.0, span = 430.0, height = 176.0, seed = 6, tumble = 6.0}]},
			body = "Forty megafauna have stopped to feed on a body of dirty ice the size of a small moon. They are packed close, mouths to the surface, and will be there for days. As they feed they shed old hide, plates off their leading edges, and other loose pieces. It drifts, and it is worth money. They are not hostile and are not watching you. A startled herd moves all at once, in every direction.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 3,
			max_danger = 4,
			needs_fauna = true,
			choices = [
				{label = "Drift in among them",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "You go in with the drive cold and the lights down and drift among them like the ice. They never look up. You take a sheet of shed hide the size of your ship and a hard plate off an old one's leading edge. You are out before any of them notices.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 6
						return {text = "One of them notices you and ignores you. You get one good piece off the drift between them and leave before the others notice. The drive runs warm.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Between three startled ones and the ice.")
						return {text = "One of the young ones startles, and the two beside it startle too. For a minute the herd moves in three directions at once. You back out with a scraped hull and nothing."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "In the middle of a feeding herd when the whole herd startled.")
						return {text = "The whole herd startles at once, and there is nowhere to go that they are not going. For thirty seconds they crowd against your ship. Then they are gone, and the hull is badly dented."}},
				{label = "Wait at the edge for what drifts out", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold a safe distance out for a day and let the shed drift to you. You take the one piece worth taking. Holding station there costs fuel. The pieces that drift furthest are the oldest and worth the least.", material = &"fauna"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You go around the herd and fly on."}},
			],
		},
		{
			id = &"the_timekeeper",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 4.0}, {stage = &"single", pieces = [&"ship_bigdish"], turn = 7.0, dark = 0.6, window = [169, 71], at = Vector2(40.0, -10.0)}]},
			title = "The timekeeper",
			body = "A relay in this system listens to the pulsar and broadcasts its tick. Every ship in the ring sets its clock by it, because the tick never drifts. An old technician runs the relay alone. Its antenna must point straight at the pulsar, but the motor that turns it has burned out. It now points a few degrees off, at empty sky, and he cannot turn it himself. He wants a ship to turn the mount back with its grapple, a degree at a time. He will listen for the signal.",
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
						return {text = "You put the grapple on the mount and turn the antenna by degrees, then by tenths, while he calls the signal strength. After an hour the tick comes back clean, and every ship in the ring gets its clock back. He pays what he has, which is more than you expected."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						Run.heat += 6
						return {text = "It takes three hours, because the mount sticks, and the drive runs hot holding position that finely for that long. The tick comes back. He pays what he offered."},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You get the antenna close enough that he can hear the pulsar faintly. It is not close enough to broadcast a clean tick. He can finish the last degree himself, once he has a spare motor rigged. He pays you for getting him most of the way."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "The mount gave way under the grapple, and the antenna swung.")
						return {text = "The mount gives way under the grapple, and the antenna swings into your hull. It now points further off the pulsar than before. After a while he says it is not your fault."}},
				{label = "Broadcast the tick yourself", effect = func() -> Dictionary:
					Run.heat += 12
					Run.add_credits(OptionTable.purse(16))
					return {text = "Your dish is already on the pulsar, so you broadcast the tick on his frequency, at his power. You do it for six hours while he rigs a spare motor and turns the antenna himself. It heats the dish and everything behind it. He pays for the six hours, less than he offered for the turning."}},
				{label = "Leave him", stay = true, effect = func() -> Dictionary:
					return {text = "You give him the time off your own board and go. The ring's clocks will drift until someone helps him."}},
			],
		},
		{
			id = &"thin_glaze",
			subject = {layers = [{stage = &"fx", fx = &"beam", period = 6.0, faint = true}, {stage = &"field", pieces = [&"r4_cache_tether_anchor_1", &"r2_minedrift_broken_strut_1", &"r2_minedrift_cable_coil_1", &"r5_scatter_spar_2", &"r4_minedrift_cable_coil_2", &"r2_minedrift_broken_strut_2", &"r4_minedrift_buckled_plate_2"], count = 7, near = 3, deep = 2, turns = 30.0, span = 420.0, height = 160.0, seed = 13, tumble = 2.0, glint = &"beam", at = Vector2(0.0, -40.0)}]},
			title = "Thin glaze",
			body = "The pulsar's beam reaches here every six seconds, so faint that most ships never notice it. It has done this for a very long time. A debris field of old markers, dead satellites and broken wreckage hangs in its track. Every piece carries a thin layer of glaze from the beam. One piece holds little, but a hundred pieces together are worth having. To collect it you fly slowly through sharp metal, and the hull takes hits the whole way.",
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
						return {text = "You go through slowly with the grapple out, scraping as you go while the hull takes the small hits. Three hours later you come out with a plate of glaze pressed from a hundred thin pieces.", material_id = &"sweep_glass"},
					clean = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "Three hours in a field of sharp metal, scraping glaze.")
						return {text = "You get the glaze, but something in the middle of the field hits hard and takes a piece of your plating.", material_id = &"sweep_glass"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Dodging, not scraping, halfway through a field of sharp metal.")
						return {text = "Halfway through the field you stop scraping and start dodging. You come out with a dented hull and one piece of an old satellite with almost no glaze on it.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Hit broadside in a debris field, by a piece nobody saw move.")
						return {text = "A piece the size of a door comes out of the field, moving fast, and hits the hull broadside. You leave the way you came in, with nothing."}},
				{label = "Take the nearest piece", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You stay at the edge of the field and take the nearest piece with the grapple. It holds little glaze, but the metal under it is old and sound. Holding at the edge of the drifting field costs fuel.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the field and go."}},
			],
		},
		{
			id = &"the_last_turn",
			subject = {layers = [{stage = &"single", pieces = [&"paint_rock_a1"], r = 50.0, at = Vector2(0.0, -5.0)}, {stage = &"fx", fx = &"marks", on = &"paint_rock_a1", marks = 4, off = Vector2(-4.0, -6.0)}, {stage = &"group", dark = 0.85, ships = [{piece = &"role:hauler", size = 0.25, at = Vector2(-122.0, -62.0)}, {piece = &"role:hauler", size = 0.25, at = Vector2(-146.0, 8.0)}, {piece = &"role:hauler", size = 0.25, at = Vector2(-108.0, 74.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(122.0, -58.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(148.0, 14.0)}, {piece = &"role:hauler", size = 0.25, flip = true, at = Vector2(112.0, 78.0)}]}]},
			title = "The last turn",
			body = "This deep, every ship has to work out its fuel. Here, a full tank still gets you home and anything less does not. Years ago someone painted the numbers on a rock, big enough to read from the approach. Around the rock are thirty or forty hulls that read them too late, all pointed outward. Each ran its tank dry a day or a week short of anywhere. Their holds are still full.",
			tags = [&"hazard", &"salvage"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Read every tank on the dish",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "Of forty tanks, one is not empty. It belongs to a hauler that turned with fuel to spare and died of something else. You take its fuel through the transfer line and one thing from its hold. You leave the rest of the field as it was.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 10
						return {text = "You spend two hours reading tanks, and most are dry. One has two units left in the bottom, and you take them. The dish is hot from the reading."},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "Every tank reads dry. You take one thing out of one hold, because you are here. The dish is hot from three hours of finding nothing.", material = &"wreck"},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "A dead hull's tank held something volatile, and it exploded.")
						return {text = "One of the tanks is not dry, and what is in it is not fuel either. Something a hauler was carrying has sat in the cold for years, and it goes when the transfer line opens. The hull takes it on the flank. You come away with nothing but the scorch."}},
				{label = "Work the nearest holds", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You skip the tanks and go hull to hull at a crawl. That costs fuel. You take the best thing out of the nearest three holds. They were full when they stopped. They are still full apart from what you take.", material = &"wreck"}},
				{label = "Check your tank and go", stay = true, effect = func() -> Dictionary:
					return {text = "You read the numbers on the rock and check your own tank. You go on while you still have the fuel to get home."}},
			],
		},
		{
			id = &"the_fuel_cache",
			title = "The fuel cache",
			subject = {stage = &"field", pieces = [&"r2_fuelcache_marked_fuel_tank_1", &"r2_fuelcache_marked_fuel_tank_2"], count = 6, near = 2, deep = 2, turns = 18.0, lift = 20.0, span = 340.0, height = 180.0, seed = 8, tumble = 3.0},
			body = "Six full fuel tanks hang on a tether, marked with a ship's name and a date eleven months ago. They sit where anyone coming out from the core would pass. Someone left their fuel home here and went inward in a lighter ship, planning to come back. They have not come back yet, though people have returned after longer. The valves have been in the cold all that time. Only the name painted on the tanks says they are not yours.",
			tags = [&"hazard"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Take all six",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 5
						return {text = "You warm the valves one at a time and take all six tanks. The owners will not find out for months."},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 10
						return {text = "Four of the valves come free and two do not, and the ship runs hot from warming them. You get three units. The two tanks left on the tether are not enough to get anyone home."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "A frozen fuel valve, opened too fast.")
						return {text = "The first valve lets go before it is warm. The tank empties itself across your flank. You take one unit from the second one, slowly, and stop."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A frozen valve, opened too fast, burst its tank.")
						return {text = "The tank comes apart against the hull when the valve goes. None of the fuel reaches your tank, and the hull is dented from bow to midships. You leave the other five."}},
				{label = "Take two and leave four", effect = func() -> Dictionary:
					Run.heat += 8
					Run.fuel += 2
					return {text = "You take two tanks, slowly, warming the valves the long way. Four stay on the tether with the name still on them. Four is enough to get a lighter ship home from the core, if the pilot is careful."}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You log the name and the date and leave the tanks for their owners."}},
			],
		},
		{
			id = &"three_years_in",
			title = "Three years in",
			subject = {stage = &"single", pieces = [&"role:survey"], lights = &"run"},
			body = "A survey ship with four crew is holding station here. A company sent them three years ago to map the approach, log the traffic, and report every ninety days. They have reported on time, but no one has answered in two years or paid them in two and a half. They keep working instead of going home to find out why. Their long-range receiver has been dead since the silence began. They want news and fuel, and will trade three years of measurements for either.",
			tags = [&"contract"],
			group = &"",
			weight = 9,
			min_danger = 9,
			choices = [
				{label = "Fix their receiver",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(30))
						return {text = "You find the fault in forty minutes: a board that died two years ago. The receiver comes back with two years of messages at once. The company folded eighteen months ago. They pay you from the ship's account, which is now theirs, and give you the three years of measurements."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "It takes half a day to find the fault. The receiver comes back. It brings eighteen months of messages and then stops. That is enough. They pay you what they can spare. They give you the measurements."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(6))
						Run.heat += 10
						return {text = "You get their receiver hearing the near channels and not the far ones. They learn the company is not answering, but not why. They pay for the attempt and go back to their instruments."},
					botched = func() -> Dictionary:
						Run.heat += 14
						Run.take_hull_damage(OptionTable.toll(3), "A survey ship's power bus, through the connecting line.")
						return {text = "You trace the fault into their power bus, and the bus fails. Their ship is dark for an hour, and the jolt through the connecting line scorches a metre of your plating. Their receiver is no better, and no one pays."}},
				{label = "Trade fuel for the measurements", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You give them two units. They give you three years of the approach: every hull that went inward or came back, on film and in the log. They add a case of the company's rations, which they have in plenty. You give them what little news you have.", material_id = &"survey_film", material = &"event"}},
				{label = "Leave them", stay = true, effect = func() -> Dictionary:
					return {text = "You give them what news you have on the channel and go. They thank you and go back to their instruments."}},
			],
		},
		{
			id = &"still_inbound",
			title = "Still inbound",
			subject = {stage = &"herd", swim = false, pieces = [&"role:hauler"], count = 6, near = 1, span = 420.0, height = 200.0, seed = 5, drive = true, dark = 0.5},
			body = "Six haulers are crawling across the system in formation toward the core, at a few metres a second. No one answers your hail, and the hulls are cold on every band except the drives. People now long dead set this convoy on automatic, and it is still going where it was told. Their holds are sealed. Working them means matching their slow speed and cutting on the move, inside a formation that still corrects itself.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match them and cut",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						return {text = "You match the crawl and slide in among them. No one aboard is alive to notice. In two hours alongside the lead hauler you take a sealed unit from its rack and a crate from its hold. Then you fall back and let them go on.", module = true, material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "You match the speed and lose it twice. The cutter runs hot from starting and stopping. You get one crate out of the last hauler in the line.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "The formation shifts, one hauler correcting for another. You spend the pass staying out of the way of six ships that do not know you are there. You come away with nothing, and hot from the dodging."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "In the gap between two haulers of a dead convoy. One of them corrected.")
						return {text = "You match the wrong hauler, and the one behind it slowly corrects into your gap. There is nowhere to go. It crushes your flank and keeps going toward the core."}},
				{label = "Pace them for a day", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You hold a kilometre off and match their crawl for a day. Their drives shake the old hulls, and you take the one good piece that comes loose. Flying that slowly for a day costs fuel.", material = &"wreck"}},
				{label = "Let them go", stay = true, effect = func() -> Dictionary:
					return {text = "You log their heading and speed and let them go."}},
			],
		},
		{
			id = &"the_pilgrims",
			title = "The pilgrims",
			subject = {stage = &"single", pieces = [&"role:passenger"], lights = &"run", drive = true},
			body = "Nine people on a ship built for four are going to the core. They know they will not come back, and they are going anyway. They are polite and do not want to be talked out of it, and their drive is fine. They want fuel, because they have barely enough to get there. They will pay whatever you ask, since they will not need the money. They also ask if you would fly with them for the first day, and will pay for that too.",
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
						return {text = "You fly a day inward with them, and something uncharted out there marks your plating. They pay in full and thank you, and you turn around."},
					partial = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(10))
						Run.take_hull_damage(OptionTable.toll(3), "Half a day inward, and the plating did not like it.")
						return {text = "You turn back at midday. Your plating is reading things a day would not undo. You say so. They understand, and pay you for the half day. They go on without you."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.take_hull_damage(OptionTable.toll(4), "Flew a day inward with nine strangers. Hit something that was not on the chart.")
						return {text = "Half a day in, something that is not on the chart takes a piece of your flank. You burn hard coming back out. They pay nothing, since you were the one who turned around."}},
				{label = "Sell them fuel", effect = func() -> Dictionary:
					Run.drain_fuel(3)
					Run.add_credits(OptionTable.purse(30))
					return {text = "You sell them three units, and they do not argue the price. They thank you, fill their tanks, and go inward until the dish loses them."}},
				{label = "Decline and go", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them no, and they are polite about that too. They will wait for the next ship, and another ship will come through eventually."}},
			],
		},
		{
			id = &"going_the_other_way",
			title = "Going the other way",
			subject = {stage = &"single", pieces = [&"role:tender"], drive = true, lights = &"run"},
			body = "Every ship you have seen this deep was going in, but this one is coming out. It is a long way off, moving fast and running hot on one drive of three. It does not slow when you hail, but it answers. A tired voice says it has no fuel to spare and no time to stop. It does have something from further in than you have been, and will trade some for fuel. You would have to match its speed long enough to pass a line.",
			tags = [&"signal", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Match it and trade",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You match the ship close enough to pass a line and hold there for six minutes. Two units go across, and a sealed case comes back with equipment from beyond the chart. The voice tells you three things about the core before the ship is gone.", module = true},
					clean = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You hold the match for four minutes. That is long enough for the fuel. It is not quite long enough for what they meant to send. Something smaller comes across instead. The voice says one thing about the core, and it is gone.", material = &"event"},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.heat += 14
						return {text = "You get the line and the fuel across. Then you lose the match, and the line parts before anything comes back. They have your fuel, and your drive is hot from the chase. The voice apologises but does not slow down."},
					botched = func() -> Dictionary:
						Run.drain_fuel(1)
						Run.take_hull_damage(OptionTable.toll(4), "Touched hulls with a ship that was not stopping.")
						return {text = "You get the match wrong, and the hulls touch at a dangerous speed. They keep going. You spend unplanned fuel stopping your drift, and drift a while longer before your systems come back."}},
				{label = "Give them fuel and ask nothing", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(14))
					return {text = "You put two units into a drop tank and leave it on their line. They take it at speed without stopping. The voice talks the whole time it is in range. A payment for the fuel clears an hour later, though you asked for nothing."}},
				{label = "Let it go", stay = true, effect = func() -> Dictionary:
					return {text = "You let it go. It is out of range in an hour, still running hot on one drive."}},
			],
		},
		{
			id = &"frost",
			title = "Frost",
			subject = {stage = &"single", pieces = [&"r5_tank_pressure_tank_1"], tumble = 2.0},
			body = "A container ship has split a tank of liquid gas, which stays liquid only while it is kept cold. It has boiled into a cloud two kilometres across that freezes onto whatever it touches. Frost a centimetre thick covers everything, including the radiators. They cannot shed heat through ice. The containers inside the cloud are whole. Working them means an hour in a cloud that will coat your vents in the first ten minutes.",
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
						return {text = "You stay in too long, and the heat builds with nowhere to go until something in the drive section fails. You come out of the cloud white and hot, missing a piece of the hull."}},
				{label = "Wait for the cloud to thin", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "The cloud is spreading, slowly. You hold outside it for a day and a half, burning to stay put. You go in when it has thinned enough to work the outer racks without icing. You get one container, from the edge.", material = &"wreck"}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the ship and go around the cloud."}},
			],
		},
		{
			id = &"the_sleepers",
			title = "The sleepers",
			subject = {stage = &"single", pieces = [&"role:passenger"], turn = 8.0, dark = 0.5, lights = &"battery"},
			body = "A ship drifts on the approach with twelve people aboard in long-term cold sleep. They went under years ago, with the ship set to wake them when help came. Help never came, and the power that keeps them cold is running down. Its transponder offers a standing bounty, paid from the ship's account, for a tow toward any station. The nearest one that could take them is nine days out, the other way from your route.",
			tags = [&"contract"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Tow them out to where the traffic runs",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(34))
						return {text = "You tow them a day outward to the traffic route and leave them there with their transponder loud. The ship pays the bounty for the leg and copies you its log. They are still asleep, a day nearer to help."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(20))
						Run.heat += 10
						return {text = "The tow takes two days instead of one, and the drive is hot from the pull. You leave them where the traffic runs. The ship pays for the leg."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "You get them half a day outward and the line parts. You burn an hour of fuel chasing the loose end down and putting it back on. Half a day is not far enough to matter. The ship pays for half a day."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A sleeping ship, on a tow line, swinging.")
						return {text = "The tow line comes tight at a bad angle, and the ship swings slowly into your flank. The sleepers do not wake or pay."}},
				{label = "Take what they will not miss", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "Their racks and holds are full, and none of the twelve will know. You take a sealed unit and a crate and leave the rest. The hour your cutter spends inside drains their power a little faster.", module = true, material = &"wreck"}},
				{label = "Leave them sleeping", stay = true, effect = func() -> Dictionary:
					return {text = "You log the position and the bounty and go."}},
			],
		},
		{
			id = &"first_on_the_wreck",
			title = "First on the wreck",
			subject = {stage = &"single", pieces = [&"r3_frame_gutted_frame_1"]},
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
						return {text = "You commit to a gap narrower than the plate showed, and the freighter tears off a length of your bow. The two ships off the break do not move."}},
				{label = "Hold the wreck", fight = true, effect = func() -> Dictionary:
					return {text = "You put the ship between them and the break with the weapons live. They have spent six hours talking about waiting. In that time they decided they are owed this one. The larger ship comes first, and the smaller one comes around behind it.", fight = true}},
				{label = "Back off the hull", stay = true, effect = func() -> Dictionary:
					return {text = "You stow the cutter and let the grapple go. The larger ship is on the break before you clear the field. What was forward of it ends up in somebody else's racks."}},
			],
		},
		{
			id = &"the_wrong_writ",
			title = "The wrong writ",
			subject = {stage = &"single", pieces = [&"ship_courier2"], lights = &"patrol", fights = true},
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
						Run.drain_fuel(1)
						return {text = "She will not clear a hull on a record she cannot check. The office that could check it is not answering her either. You hold station a day and a half while she files upward. That costs one unit on the reactor. She lets you go without ever being told she was wrong."},
					botched = func() -> Dictionary:
						return {text = "You talk over her twice, and she takes it as a sign of guilt. The boat comes about with its bow mount live, and her writ covers whatever she does next.", fight = true}},
				{label = "Sit still for the inspection", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold station cold for most of a day while she scans your hold against a list for another ship. She finds nothing on it. Her stores owe a detained hull its rations, so she sends a case across before she goes.", material = &"event"}},
				{label = "Hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "You do not answer the order. You do not come off the throttle. The boat keeps your quarter for twenty minutes with its lights going. Then it drops back and goes looking for the hull number it was given."}},
			],
		},
		{
			id = &"the_far_side",
			title = "The far side",
			subject = {stage = &"group", ships = [{piece = &"role:passenger", dark = 0.55, lights = &"battery", at = Vector2(85.0, 20.0), z = 0}, {piece = &"ship_gunboat", fights = true, size = 0.5, dock = {to = 0}, at = Vector2(75.0, 0.0), z = 1}, {piece = &"role:small", fights = true, turn = 6.0, lights = &"run", at = Vector2(-118.0, 82.0), z = 2}, {piece = &"role:small", fights = true, far = true, turn = -5.0, lights = &"run", at = Vector2(-150.0, -68.0), z = -1}]},
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
						return {text = "You come in dark at the wrong angle and hit the stern frame hard. You leave the wreck with a torn bow and nothing in the bay."}},
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
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"], tumble = 1.0},
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
						Run.fuel += 4
						return {text = "You come in high off the strobe and fast. You are coupled before either of them has finished coming about. The pumps do not ask who you are. You leave with four more units in the tank. The rate card is still repeating on the channel behind you."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 6
						return {text = "You take the approach hot and get two units across. The nearer ship closes in until the coupling gets awkward. You break off with the radiators loaded. The pumps keep running for whoever comes next."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						return {text = "They get a hull across the intake before you have much across. You come off the coupling with one unit. They go back to their station off the arm."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "The intake arm of a fuel platform, hit at full burn.")
						return {text = "You commit to the approach at full burn. The intake arm is not where the old plate said. The platform keeps turning and keeps pumping. You come off it with a fold in the bow and the tank no fuller than it was."}},
				{label = "Push them off the intake", fight = true, effect = func() -> Dictionary:
					return {text = "You attack the two ships instead of going for the platform. They have relied on the rate card for a long time, and they are slow to respond.", fight = true}},
				{label = "Keep clear of the intake", stay = true, effect = func() -> Dictionary:
					return {text = "You take the long way around the platform, well outside the strobe. You leave the ring on the tank you came in with. The rate card repeats on the channel until you are out of range."}},
			],
		},
		{
			id = &"nothing_taken",
			title = "Nothing taken",
			subject = {stage = &"group", fights = true, flood = true, ships = [{piece = &"role:hauler", far = true, at = Vector2(-120.0, -60.0)}, {piece = &"role:hauler", far = true, at = Vector2(140.0, -55.0)}, {piece = &"ship_armedtrader", at = Vector2(10.0, 35.0), z = 1}]},
			body = "Three haulers come out of the ring together and put their lights on you. Someone took eleven containers off the second of them four days ago. The ship that did it was the same class as yours, with the same drive signature. They have stopped every ship of that class since. The woman speaking for them is tired and polite, and she is sure of what she is looking at. They will not shoot first, but they will not stand aside either.",
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
						Run.drain_fuel(2)
						return {text = "The radiators will not come down far enough for the reading to settle. She will not clear a hull she cannot rule out. You take the long way out of the ring and burn two units doing it. Two of the three hold your bearing for six hours. The third sits somewhere behind the moon."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A warning shot from a hauler crew that had made up its mind.")
						return {text = "You come up hot in the middle of the reading, and all three read that the same way. The shot is meant as a warning and it lands as a hit. She says nothing after that. The lights stay on you until you are out of the ring."}},
				{label = "Sell them an escort to the crossing", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					Run.add_credits(OptionTable.purse(26))
					return {text = "She does not clear you, but she does not want to spend the afternoon on it either. She wants the only armed hull in the ring flying where she can see it. You burn alongside the three of them to the crossing. They pay the rate they would pay anyone, and no one mentions the containers again."}},
				{label = "Decline the stop", stay = true, effect = func() -> Dictionary:
					return {text = "You tell her what class of hull you fly. You tell her you are not the one she wants. Then you hold your heading through the middle of the three of them. Nobody follows. The eleven containers are somewhere in the ring, and the haulers are still stopping ships."}},
			],
		},
		{
			id = &"the_licensed_seam",
			title = "The licensed seam",
			subject = {stage = &"single", pieces = [&"paint_rock_b3"], r = 120.0},
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
					return {text = "You stow the cutter and back off the rock with half a shift spent and the bay empty. They are on the face before you clear the limb, without a word on the channel."}},
			],
		},
		{
			id = &"the_wreckers",
			title = "The wreckers",
			subject = {stage = &"single", pieces = [&"r4_lightmast_false_light_1"]},
			body = "A crew works this crossing with a false light. They hang it off a rock where a station light would be, with nothing behind it. They have done this long enough that the hulls past the rock are bare frames. Two ships sit in the rock's shadow with drives idling and lights off. The light still sends a dock code retired forty years ago. No patrol has come this deep for a long while.",
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
						return {text = "Your strong return across the field gives you away. They have waited on that light for eleven days with nothing to show for it. Both ships come out of the rock's shadow with drives lit.", fight = true}},
				{label = "Burn wide and work the far frames", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You take the long way in, around the outside of the field. It costs two units and keeps the rock between you and them. The outermost hull is the oldest, and the only one they have not finished. One crate comes off it. You are gone before either ship trims its attitude.", material = &"wreck"}},
				{label = "Leave the light burning", stay = true, effect = func() -> Dictionary:
					return {text = "You log the false code and the bearing it sits on. You go around wide of both. The light is still running when your dish loses the rock, and neither ship has moved."}},
			],
		},
		{
			id = &"the_hunting_ship",
			title = "The hunting ship",
			subject = {stage = &"single", pieces = [&"ship_scoop"], lights = &"run", fights = true},
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
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(6))
						return {text = "They hold alongside for most of a day and cannot decide. You hold with them and burn two units doing it. At the end of it they pay for the bearing, badly. They go on across the system with the frame on the bow still empty."},
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
			subject = {stage = &"single", pieces = [&"ship_ringdrive"], lights = &"battery", fights = true},
			body = "A ship hails you. It stopped being a business a long time ago. They have been out here nineteen years. The registry ran out twelve years back, and the manufacturer that built the ship is gone too. The same people have been aboard the whole time. They do not call it a raid. They read you a list of what they need, in order, and they stay armed while they read it. There are forty items on the list. The first one is fuel.",
			tags = [&"fight"],
			group = &"",
			weight = 9,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Come at them dark", fight = true,
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						return {text = "You go cold and come in off their blind quarter while the list is still being read. For nineteen years they have been the only armed ship in every talk, and they are slow to respond.", fight = true},
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
					Run.drain_fuel(3)
					return {text = "You put three units across and tell them the other thirty-nine items are not your problem. They take the fuel and the answer. Then they send one crate back, off the hulls they have worked since the registry ran out.", material = &"wreck"}},
				{label = "Refuse the list", stay = true, effect = func() -> Dictionary:
					return {text = "You tell them no, and they take it as they have before. They stop reading and go quiet. They hold their station, and you hold your heading."}},
			],
		},
		{
			id = &"six_years_waiting",
			title = "Six years waiting",
			subject = {stage = &"single", pieces = [&"ship_forked"], dark = 0.3, lights = &"run", fights = true},
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
						Run.add_credits(OptionTable.purse(14))
						return {text = "You push the reactor outside the envelope it was built for. You hold it there while her instruments work. What comes back matches nothing anybody has a file on. She says sorry, plainly and once. Then she pays you for the hour your reactor ran hot."},
					clean = func() -> Dictionary:
						Run.heat += 16
						return {text = "You hold the reactor off its profile long enough for the reading to come back wrong. The loop stops. She tells you to go on through the crossing. The reactor takes an hour to come back down to where it belongs."},
					partial = func() -> Dictionary:
						Run.heat += 20
						Run.drain_fuel(2)
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
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"]},
			body = "A fuel depot sits on the approach with eleven tanks still reading full. In front of it, on station, is an automatic guard with a firing arc. It sends a challenge every ninety seconds and wants a code back. The code belongs to an authority that stopped issuing anything long ago, and no ship since has been able to give it. It does not talk or stand down, and no one is left to order it to.",
			tags = [&"fight", &"hazard"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Take the tanks from inside its arc",
					check = {attr = &"maneuver", need = 8},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You go in under the arc and stay under it. That means never being where it is pointed, and never stopping. Two hours of that gets you four units off four tanks and out the far side. The challenge is still going out every ninety seconds behind you."},
					clean = func() -> Dictionary:
						Run.fuel += 3
						Run.heat += 12
						return {text = "You get three tanks open before the arc catches up with the line you are flying. You leave the fourth, and three units come across. The ship is hot from two hours of flying that way."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						Run.take_hull_damage(OptionTable.toll(2), "Inside the firing arc of a thing no one can call off.")
						return {text = "You get one tank open and one unit across. Then it puts a shot through your flank and you break off the transfer. The challenge goes out again on schedule while you back away."},
					botched = func() -> Dictionary:
						Run.heat += 20
						Run.take_hull_damage(OptionTable.toll(4), "Crossed the firing arc of a thing left on station with old orders.")
						return {text = "You put your line through the middle of the arc. It does the one thing it was left here to do. You come out of the approach with nothing off the tanks. There is a hole where the transfer line was going to go."}},
				{label = "Put it down and take the depot at leisure", fight = true, effect = func() -> Dictionary:
					Run.heat += 12
					return {text = "You stop trying to fly around it and go straight at it. It fires within the first second. The reactor is already hot from the run in.", fight = true}},
				{label = "Leave it", stay = true, effect = func() -> Dictionary:
					return {text = "You log the depot, the arc and the eleven full tanks, and go around them."}},
			],
		},
		{
			id = &"the_back_of_the_line",
			title = "The back of the line",
			subject = {stage = &"single", pieces = [&"r3_depot_fuel_depot_1"]},
			body = "Eleven ships hold a line off a fuel point that has about seven ships' worth left. The order is the order they arrived in, and the log records it. Every ship out here still keeps to the log. When the point runs dry, the line takes what it needs from the ship at the back. Every ship ahead of you agreed to that. You arrived a minute ago, and you are eleventh.",
			tags = [&"fight"],
			group = &"",
			weight = 8,
			min_danger = 9,
			choices = [
				{label = "Take your fuel before your number comes up",
					check = {attr = &"thrust", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You break the order and reach the point ahead of them. The line spends four minutes deciding whether the deal covers this. It does not. You pull four units and you are past them and burning. The ninth ship is still saying so on the channel."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						Run.heat += 14
						return {text = "You reach the point first and pull two units. The two ships at the front of the line start their drives. You leave with half of what you wanted. The drive is hot from getting out of their way."},
					partial = func() -> Dictionary:
						Run.fuel += 1
						return {text = "You get one unit across before the line closes on the point with you still on the transfer line.", fight = true},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Cut the line at a deep fuel point and got shot for it.")
						return {text = "You commit late. Four of them are already moving when you reach the point. The first one opens up before you are on the transfer line at all.", fight = true}},
				{label = "Buy the tenth place off the ship ahead of you", cost_credits = 40, effect = func() -> Dictionary:
					Run.add_credits(-40)
					Run.fuel += 2
					return {text = "The ship at ten knows exactly what its place is worth. It names the figure before you have finished asking. You pay and the log is amended. When your number comes up there are two units left in the point. The ship that was at ten is at eleven now, and it knew that when it took the money."}},
				{label = "Hold your number and wait", stay = true, effect = func() -> Dictionary:
					return {text = "You sit at the back of the line with your drives cold and the transponder on. Four hours later a twelfth ship arrives, logs its arrival, and takes the back of the line from you."}},
			],
		},
		{
			id = &"seized_clamp",
			title = "The clamp",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], grip = {at = "collar"}},
			body = "The dock is four clamps wide and one of them has you. Its release motor burned out while you were loading. The woman on the counter says the yard crew comes through on the ninth, four days out. She is not sorry, and she is not charging you for the days. The clamp holds your collar and a metre of plating around it. Your drives can pull a ship this size off a dead clamp if the collar holds. You cannot see the collar from where you sit.",
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
						return {text = "You come off, but a small piece of plating around the collar stays in the clamp, and it was holding something. The woman on the counter watches from behind the glass and logs none of it."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A dead clamp held on and the collar came out of the hull.")
						return {text = "You go to full against a clamp that will not open, and the collar goes first. It takes plating with it on the way out. The clamp is still shut around what is left of it. You are a kilometre off the dock by then."}},
				{label = "Cut the arm off at its mount", effect = func() -> Dictionary:
					Run.heat += 8
					return {text = "Four hours on the cutter with the reactor up the whole time. The mount was built to be replaced and never to be removed. The arm comes off in one piece with your collar still in its jaws. You keep it. The yard has no use for a clamp with a burned motor and a cut mount.", material = &"wreck"}},
				{label = "Wait for the yard crew", stay = true, effect = func() -> Dictionary:
					return {text = "You spend four days on the dock with the drives cold. On the ninth the yard crew comes through with a cart of motors. They swap the dead one in about twenty minutes, charge you nothing, and move on down the row."}},
			],
		},
		{
			id = &"the_split_loop",
			subject = {stage = &"single", pieces = [&"ship_orbitarms"], lights = &"run", at = Vector2(20.0, 0.0)},
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
						Run.fuel += 1
						return {text = "The sleeve seats on the first try, and the loop holds at pressure. The reactor is back to normal inside the hour. You fly on and save the fuel of a trip back to the station."},
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
					return {text = "She names her price and gets it, since no one else out here sells loop sections. It comes as a whole unit with the pump end included, ready to fit. She watches it aboard, then goes looking for the next ship running warm.", module = true}},
				{label = "Turn back and patch it cold", stay = true, effect = func() -> Dictionary:
					return {text = "You fly the two hours back and sit at the station. The reactor goes down and the loop drains. You put a proper sleeve on a line that is not moving. It takes the afternoon and most of the evening. The loop reads clean when you light the reactor again."}},
			],
		},
		{
			id = &"the_scatter",
			title = "The scatter",
			subject = {stage = &"field", pieces = [&"r4_scatter_torn_plate_1", &"r4_scatter_cabin_section_1", &"r4_scatter_drive_nozzle_1", &"r5_scatter_spar_2", &"r4_scatter_tank_half_2", &"r4_scatter_torn_plate_2"], count = 6, near = 2, deep = 2, turns = 35.0, band = -14.0, span = 430.0, height = 200.0, seed = 9, tumble = 6.0},
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
						Run.drain_fuel(1)
						return {text = "You are into the gap before the dish finds a piece the office never counted. You spend the rest of the crossing burning to stay behind it. You come out where you meant to. The tank is one unit down and the grapple is empty."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A plate a metre across, turning, six days out of a wreck.")
						return {text = "You cross on a gap the office called twenty minutes ago. The piece that finds you turns slowly enough to watch it come in. There is not enough of the gap left to be anywhere else. It goes into the forward plating and stays there."}},
				{label = "Work the near edge of the spread", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You put yourself well off the lane, on the near edge. The pieces there are thin and slow. You burn to stay in place while the office works through two more crossings. The grapple gets one piece of somebody's hull plating. It is big enough to be worth the burn.", material = &"wreck"}},
				{label = "Wait for the office to call it clear", stay = true, effect = func() -> Dictionary:
					return {text = "The office says two more days before the lane is worth calling clear. You spend them out of everybody's way with the drives cold. On the second afternoon a tug starts working the lane from the station end. It picks pieces up and stacks them on a line."}},
			],
		},
		{
			id = &"the_parted_line",
			title = "The parted line",
			subject = {stage = &"structure", pick = true, pieces = [&"st_dock_face_1", &"st_dock_face_2", &"st_dock_face_3", &"st_dock_face_4"], with = [{piece = &"ship_lightfreighter", scale = 0.5, turn = -62.0, tumble = 1.0, at = "lug0", off = Vector2(-8.0, 69.0)}], lines = [{from = "lug0", to = 0, to_at = [186, 30]}, {from = "lug1", to = 0, to_at = [184, 54]}], parted = {from = "lug2", len = 38.0, lean = -10.0}},
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
					Run.drain_fuel(1)
					return {text = "You put your nose under the low end and hold it up on a long steady burn. It costs fuel. It gives her a lighter that is not swinging. She gets both lines on in the time it takes. She has nothing aboard to pay you with. She signs over a case off the load and the mast crew logs it as damaged in transit.", material = &"event"}},
				{label = "Call it in for her", stay = true, effect = func() -> Dictionary:
					return {text = "You put it on the open channel to the station. You give them the mast, the parted line, and the way the lighter hangs. The traffic office says a tug is an hour out and already tasked. She is still talking to them when you lose the channel."}},
			],
		},
		{
			id = &"the_cooling_loop",
			title = "The cooling loop",
			subject = {stage = &"single", pieces = [&"role:mining"], lights = &"battery"},
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
						Run.fuel += 2
						return {text = "Your dish will not separate the two lines at this range. You will not guess for them. You give them the bearing of the warmest plating. They cut on that, and it is the right line. Nobody aboard will ever be sure whose call it was. They have nothing in the account worth sending. They pump two units of fuel across instead."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Sat alongside a mining ship while its reactor cooked.")
						return {text = "You call the aft line and they cut it. The aft line was the good one. What is left of the loop goes down inside four minutes. The crew get clear in a boat. The ship opens in one place and stays whole everywhere else. You are close enough that a sheet of it reaches you before you turn away."}},
				{label = "Take their cargo off while they work", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "They would rather it went with somebody than went down with the ship. They say so plainly and ask nothing for it. Their hull is holding its attitude badly. Matching it costs you an hour of small corrections and the fuel to make them. One load comes across on the grapple: their stores, their spare seals, a crate of instrument film nobody has opened. The loop is still down when you pull away.", material = &"event"}},
				{label = "Pass the hail inward", stay = true, effect = func() -> Dictionary:
					return {text = "You put their position and their numbers on the relay, at a priority no one this far out honours, and fly on. No reply comes back while you are still in range."}},
			],
		},
		{
			id = &"the_front",
			subject = {stage = &"fx", fx = &"front"},
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
						return {text = "The front arrives while the ship is still beam on to it. Gravel hits first, then a sheet of plate the size of a cargo door, tumbling. It goes into the flank, and the frames stop it."}},
				{label = "Put the nearest rock between you and it", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "The rock is eleven minutes away under a hard burn. It is not large and it does not have to be. You sit in its lee while the front goes past on both sides. It rings the far face of the rock for four minutes. There is nothing else to do in that time. The cutter takes a load of ice off the shaded side while you wait.", material = &"mining"}},
				{label = "Turn around and run with it", stay = true, effect = func() -> Dictionary:
					return {text = "You put the drives toward the front and run outward ahead of it. It takes six hours to catch you and it is thin by then. Grit on the plating, a reading on the dish, and nothing else. The sky you meant to cross is behind all of it now. You will come at it from the other side."}},
			],
		},
		{
			id = &"the_ice_stream",
			subject = {layers = [{stage = &"fx", fx = &"stream", from = Vector2(-215.0, -112.0), to = Vector2(215.0, -8.0), width = 30.0}, {stage = &"field", pieces = [&"paint_rock_a1", &"paint_rock_b3", &"paint_rock_a2", &"paint_moon_ice", &"paint_rock_b4", &"paint_rock_a1", &"paint_rock_b3", &"paint_moon_europa", &"paint_rock_a2", &"paint_rock_b4"], count = 10, near = 10, r = [4.0, 9.0], band = 14.0, span = 430.0, height = 46.0, seed = 17, tumble = 0.0, at = Vector2(0.0, -60.0)}]},
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
						Run.fuel += 2
						return {text = "You are across the track and past it with an hour to spare. That puts you outside the stream with the whole leading edge coming to you at walking pace. You work it for most of a day. Water goes into the tank as fast as the cutter can free it. A load of the grit-bearing ice goes into the hold behind that.", material = &"mining"},
					clean = func() -> Dictionary:
						return {text = "The burn starts late and runs long. You cross with the first pieces already going past, close enough to count. On the far side you take what the stream sheds. One load of ice with rock frozen through it comes from the slow, thin edge.", material = &"mining"},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						return {text = "You misjudge how far ahead the fast pieces run, and you spend the whole burn correcting for them. You come out clean on the far side, with less fuel than you planned and an empty hold."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "A rock crossing the other way, at the speed of an orbit.")
						return {text = "The dish counts the big pieces all day. It gives you no trouble with them. A piece the size of a bolt comes out of the head of the stream. It arrives at the sum of two orbital speeds and goes into the bow. The frames behind the bow stop what is left of it. The stream keeps going past for another day and a half."}},
				{label = "Sit off the flank and fish the thin edge", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					return {text = "You hold station off the flank for a day and a half, burning to stay level. You take what comes off the outside of the stream, where the pieces are slow and far apart. One load of ice and grit goes into the hold, and the hull is never touched.", material = &"mining"}},
				{label = "Wait for the whole stream to pass", stay = true, effect = func() -> Dictionary:
					return {text = "You sit still for a day and a half while the stream goes by. When the sky is clear you cross, later than you meant to and with nothing new aboard."}},
			],
		},
		{
			id = &"the_venting_hold",
			title = "The venting hold",
			subject = {stage = &"field", pieces = [&"r2_container_freight_box_1", &"r2_container_freight_box_2"], count = 6, near = 3, span = 360.0, height = 170.0, seed = 5, tumble = 3.0},
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
					Run.drain_fuel(1)
					return {text = "You work from outside the turn. That means matching a container that comes past once every three minutes. You cut only at the near point. It takes four passes and the fuel to make them. One comes away on the fourth: sealed, full of stores, untouched since the day it was loaded.", material = &"event"}},
				{label = "Give it the day and go", stay = true, effect = func() -> Dictionary:
					return {text = "The tank runs dry sometime in the next day. After that it is a ship with a hole in it, turning at whatever rate the jet left it. You log the drift and the heading for whoever is behind you. The containers on the high side will still be sealed then."}},
			],
		},
		{
			id = &"four_on_one_hull",
			title = "Four on one hull",
			subject = {stage = &"single", pieces = [&"role:family"], lights = &"run", drive = true},
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
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(6))
						return {text = "You take four containers, all your own load leaves room for. You hold the burn long and slow to keep them alongside, using fuel you meant to keep. They pay the standing fee for the hours and say they are sorry it is not more."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A burn flown heavier than the drive frame was ever rated for.")
						return {text = "You take more than the frame wants and hold the burn anyway. Forty seconds in, a mount on the port side bends and stays bent. The containers go back to the family hull, and you shut the drive down to check the mount. They fly the window in two trips, and no one is paid."}},
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
			subject = {stage = &"single", pieces = [&"role:hauler"], dark = 0.6, lights = &"battery"},
			body = "Two crew sit on a short-haul hull with the reactor down. The exchanger that should shed its heat is split along a weld. They have been sitting cold for nine hours. The repair is an afternoon of work, but they cannot start until their loop cools. Their own panels went with the exchanger. They want a coupling walked across on the grapple, so their loop can run through your radiators until the number comes down. They will pay the hours at a rim yard's rate.",
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
					return {text = "You agree to two hours, and you give them two hours. It takes their loop down far enough to work in and no further. You go on warm. They pay before the coupling is stowed, then go back to a repair that will take the rest of the day."}},
				{label = "Stay cold", stay = true, effect = func() -> Dictionary:
					return {text = "They take the answer and do not argue about it. They go back to the open channel. Somebody will come through this system in a day or two with empty panels. The reactor stays down until then. The two of them sit in a hull going as cold as the sky around it."}},
			],
		},
		{
			id = &"the_spare_module",
			title = "The spare module",
			subject = {stage = &"single", pieces = [&"role:tender"], lights = &"run"},
			body = "Three people work off an old tender. They have one thing left to sell, a power module out of a hull they took apart four systems back. Someone has ground the manufacturer's plate and the serial off the casing. They are selling it here, in open space, because the yard they are headed for keeps a register. That yard asks about parts with no numbers on them. They want cash today. The price is low, and they say so.",
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
			subject = {stage = &"single", pieces = [&"role:hauler"], lights = &"run", drive = true},
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
						Run.drain_fuel(1)
						Run.add_credits(OptionTable.purse(5))
						return {text = "Holding a line that tight is attitude work the whole way. You spend the crossing burning small corrections you do not get back. She is stopped anyway, an hour out from the yard. The patrol reads two contacts and wants to know about the older one. She pays you what she has left after the stop."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Two hulls flying closer than either pilot could hold them.")
						return {text = "Eight hours in she comes up under the flank on a correction you were already making. The touch is slow. It still takes a run of plating off the underside. It puts her attitude jets out on that side. She finishes the crossing a kilometre off and pays nobody anything. The yard gets two jobs now."}},
				{label = "Sit out the patrol window with her", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(12))
					return {text = "The patrol working this ring keeps to a schedule. You can both read it off the traffic channel. You hold at the edge of the system with her and wait for the patrol to pass inward. That costs most of a day and the fuel to hold position. She crosses behind you unstopped. She pays before either of you has lit a drive."}},
				{label = "Send her the times and go", stay = true, effect = func() -> Dictionary:
					return {text = "You send her the last three times you saw a patrol on this ring. You send nothing else and fly your own crossing. She is still at the edge of the system when you lose her off the dish. She is doing the arithmetic on a schedule with three entries in it."}},
			],
		},
		{
			id = &"the_automatic_dock",
			title = "The automatic dock",
			subject = {stage = &"structure", pieces = [&"st_the_automatic_dock"]},
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
						Run.drain_fuel(1)
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
			subject = {stage = &"single", pieces = [&"r4_dustcounter_dust_counter_2"], tumble = 3.0},
			body = "An instrument hangs on a frame out here, counting what goes past. It has one aperture, a stack of cells, and a log. The log writes a number every hour whether anybody reads it or not. A mining outfit put it here to learn if the drift was worth working. The outfit is gone and the answer is still not in. It has been writing since before your ship was fitted. Two cells are left in the stack. The log is nearly full. When it fills it starts over and writes on top of the old numbers.",
			tags = [&"signal"],
			group = &"",
			weight = 9,
			max_danger = 4,
			choices = [
				{label = "Copy the log before it wraps",
					check = {attr = &"sensors", need = 4},
					met = func() -> Dictionary:
						return {text = "The dish reads it off in an hour and forty minutes, first entry to last. The first entry is older than the outfit that ordered it. Eleven numbers an hour for four years. Then one an hour ever since. The cells have been going flat that whole time. You clip the spares box off the frame: cable, two cells, a lens the aperture never needed.", material = &"event"},
					clean = func() -> Dictionary:
						return {text = "The copy comes off clean for the last four years. Then it hits the wrap. The new numbers are written on top of the old ones, and neither one survives. You take the spares box off the frame and leave the instrument counting.", material = &"event"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "The interface wants a key you do not have. The dish gives you the entry it is writing now, over and over. The reactor idles the whole time. Two hours of that, and you have one number out of a record forty years deep."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "A survey frame let go at the weld and put a strut through the plating.")
						return {text = "You come in close to read the housing itself. The frame it is bolted to lets go at the weld. It comes apart slowly. That does not help. One strut finds the plating and goes through it."}},
				{label = "Cut the instrument off its frame", effect = func() -> Dictionary:
					Run.heat += 6
					return {text = "Half an hour of cutter on a frame built to stay put. The aperture, the cell stack and the housing come aboard as metal. The log stops somewhere in the second cut. The frame is still out there, bare, pointed at the drift.", material = &"wreck"}},
				{label = "Note the bearing and go", stay = true, effect = func() -> Dictionary:
					return {text = "You log where it is and what it is doing. In a month or two the log will wrap and write over its first forty years."}},
			],
		},
		{
			id = &"the_welded_plate",
			title = "The welded plate",
			subject = {stage = &"on_rock", planet = true, base = &"paint_rock_a1", r = 84.0, pieces = [&"r4_plate_welded_plate_1"], rows = 1, count = 1, face = Vector2(-6.0, 4.0)},
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
						Run.drain_fuel(1)
						return {text = "You take one pass at it. Most of a row of frame comes aboard. The rock turns under you the whole time. Holding the nose steady costs more burn than you meant to spend.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "An hour of station keeping against a rock that will not hold still. Most of the hour goes on the nose and not the cutter. Somebody put those bolts in with a cutter and no reason to hurry. They are still in."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A turning rock the size of a station threw loose debris off its face into the ship.")
						return {text = "You come in under the plate on the wrong side of the spin. What comes off the face is small, and there is a lot of it. It arrives at the speed the rock is turning."}},
				{label = "Pump what is left in the tanks", effect = func() -> Dictionary:
					Run.heat += 5
					Run.fuel += 2
					return {text = "The valves are a standard fitting and they have not frozen shut. The rest of the ship did not manage that. It takes three hours to move the fuel across. The pump runs hot the whole time, with your own lights on the plate. The tanks read empty when you uncouple."}},
				{label = "Log the eleven registries", stay = true, effect = func() -> Dictionary:
					return {text = "You put the dish on the plate and read off all eleven numbers. The date under them goes in the log too. The rock turns the plate out of sight. It brings it back around."}},
			],
		},
		{
			id = &"the_core_drill",
			title = "The core drill",
			subject = {stage = &"single", pieces = [&"r4_drill_drill_rig_1"]},
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
			subject = {stage = &"structure", pieces = [&"st_quoted_blind"]},
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
					Run.drain_fuel(2)
					return {text = "Two units of attitude work over a shift. You hold the plate flush while the crew runs the weld from the inside. It is dull flying and the grapple does most of it. The foreman cannot pay you what the hours are worth. He loads a crate of yard stock into your bay instead: cells, sealant, two spools of line. He counts it out loud, item by item.", material = &"event"}},
				{label = "Leave them the seam", stay = true, effect = func() -> Dictionary:
					return {text = "They keep hailing for a while after you are past. The plate stays open. The yard has other work in front of it. The price on the channel does not change."}},
			],
		},
		{
			id = &"the_even_split",
			title = "The even split",
			subject = {stage = &"single", pieces = [&"r3_frame_gutted_frame_2"], tumble = 1.5},
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
					Run.drain_fuel(2)
					return {text = "Four hours of easy plate off a half that is not fighting you. Two units go on holding position against the roll while you cut. It is the side nobody wanted, and it is still a bay of good plate. The other crew is on the stern before your second pass is done. They are still there when you go.", material = &"wreck"}},
				{label = "Let them have the hull", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and go. Their cutter is bigger and their crew is rested. The hauler will be just as dead in four hours. They will still be cutting it then."}},
			],
		},
		{
			id = &"receipted_twice",
			subject = {stage = &"single", pieces = [&"ship_forked"], size = 0.5, lights = &"run", at = Vector2(60.0, -40.0)},
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
						return {text = "Eleven crates. The mass sits within a point of what eleven crates of drive parts should read. The second receipt was written against a load that was never on any ship. The station that wrote it is four crossings behind you and does not know yet. She pays the reading fee and the correction fee together. She copies the filing across to you as well. She wants it stored somewhere that is not her own drive."},
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
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(8))
					return {text = "Most of a shift with the reactor idling. The dish points at her ship instead of the shipment. Eight days of receipts and two stamps from two stations. There is a transfer note with the wrong registry typed in twice. You take a copy of all of it. She pays you a clerk's fee for the shift. She talks the whole time, and about half of it is about the paperwork."}},
				{label = "Stay out of the file", stay = true, effect = func() -> Dictionary:
					return {text = "She is still on the channel asking when you pass out of range."}},
			],
		},
		{
			id = &"walking_the_tank",
			title = "Walking the tank",
			body = "A refinery out past the last dock has a freighter's window in eleven hours. Its tender is dead. The ore tank is loaded and sitting where it was filled. Nothing on the site has the thrust to walk it to the loading point in time. The site foreman has been on the channel most of a shift. He is offering the freight rate he was going to pay the tender, and it is all the money he has. He wants any ship with a working drive to take it. If no one does, the freighter leaves empty.",
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
						return {text = "You get it there with forty minutes to spare. Two of the nine hours went on correcting a drift you put in yourself. The freighter takes the tank, and the foreman pays the rate without mentioning the drift."},
					partial = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(5))
						return {text = "The tank comes off its anchor harder than you meant. You spend the next six hours taking that back out of it. The drive is up and the vents work behind it the whole way. It arrives after the window. The freighter takes what it can hold in the time it has. The rest stays on the tank. He pays part of a rate for part of a job."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed a loaded ore tank past what its anchor points would hold. A corner of it came around into the plating.")
						return {text = "The push goes in off centre. The tank starts a slow yaw you cannot get in front of. One corner comes around into your plating at walking speed. At that mass, walking speed is enough. The tank stops where it stops. The freighter leaves on time and empty."}},
				{label = "Sell the site your reserve", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "Their last working tug can do it in three trips if it has fuel to burn. Two units go across the line in an hour. The tug is moving before the pump is cold. The foreman pays in ore off the top of the tank. He would rather part with the ore than the money. The tug is out at the anchor before he finishes saying it.", material = &"mining"}},
				{label = "Hold your heading", stay = true, effect = func() -> Dictionary:
					return {text = "He is still on the channel two hours later. He is offering the same rate to a different set of ships. The tank sits where it was filled. The window closes whether anybody answers him or not."}},
			],
		},
		{
			id = &"the_cracked_frame",
			title = "The cracked frame",
			subject = {stage = &"structure", pieces = [&"st_the_cracked_frame"]},
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
			subject = {stage = &"single", pieces = [&"r4_pumprack_pump_on_a_rack_1"]},
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
						Run.drain_fuel(1)
						return {text = "A tender works the rack all shift, doing perfectly ordinary things. You hold off it and burn fuel. By the time it clears, the freighter's window is too close to be worth the approach. You break off. The outfit stops answering. The crate is still on the rack when you leave."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Pulled a crate off a station rack before the clamp let go.")
						return {text = "The clamp reads the grapple as a dock loader and does not release on your schedule. You take the crate and a length of the rack with it, across your own plating. The board logs every second. The outfit gets the pump, and no one at the dock mentions the rack to you."}},
				{label = "Sit off the rack and read the dock for them", effect = func() -> Dictionary:
					Run.drain_fuel(1)
					Run.add_credits(OptionTable.purse(10))
					return {text = "One unit of station keeping, and most of a shift with the dish on the dock's traffic. You log when the rack is worked and when it is not. Their foreman takes the pattern. He sends his own tender in on the third quiet window. They pay for the watch at the rate they pay their own people. It clears before the tender is back."}},
				{label = "Keep clear of the rack", stay = true, effect = func() -> Dictionary:
					return {text = "The freighter leaves in two days, with a pump in it or without one. The outfit puts the same question to the next ship on the approach. The crate sits on the rack. The hold is still against it."}},
			],
		},
		{
			id = &"the_flat_rate",
			title = "The flat rate",
			subject = {stage = &"single", pieces = [&"r4_pod_cargo_pod_2"]},
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
						return {text = "You take most of the roll out and put some of it back in twice. The drive works the whole time and the vents work behind it. The dock refuses the line at that rate of roll. The two of them wait about a day for it to damp on its own, and that day is unpaid."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(5), "Went alongside a rolling mining tender full of wet ore. The ore moved before you did.")
						return {text = "You go in close on a load whose centre shifts every time it rolls. This time it shifts early. The tender comes across your flank at the top of the roll. It takes plating with it. The roll is worse afterwards than it was before. The pilot says nothing on the channel for a while. Then he asks if you are all right."}},
				{label = "Take the drained ore as the fee", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "You spend two units holding station alongside while they pump the wet ore into your bay as payment. The roll comes down as the tank empties. After four hours of dull flying, you have a bay of ore.", material = &"mining"}},
				{label = "Let them finish it themselves", stay = true, effect = func() -> Dictionary:
					return {text = "They are still alongside it when your dish loses them. The tender rolls at the rate it has rolled for four days. The dock at the far end is not expecting anybody early."}},
			],
		},
		{
			id = &"the_thrower",
			title = "The thrower",
			subject = {stage = &"structure", pieces = [&"st_the_thrower"], with = [{piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = 20.0, swim = true, tumble = 3.0, at = Vector2(100.0, 150.0)}, {piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = -30.0, swim = true, tumble = 3.0, flip = true, at = Vector2(138.0, 205.0)}, {piece = &"r2_thrower_canister_on_sled_2", scale = 0.5, turn = 50.0, swim = true, tumble = 3.0, at = Vector2(58.0, 232.0)}]},
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
					Run.drain_fuel(2)
					return {text = "You hold station beside the rock. It shakes every eleven minutes and you trim against that. The grapple takes one canister off the rack before the loader can get it to the rail. Holding that close costs a day of fuel. The loader reaches past you for the next one and carries on.", material = &"mining"}},
				{label = "Leave it firing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and the gap between shots and go. The next canister goes out eleven minutes after you do. It takes the same line as all the rest. The station at the far end of that line stopped answering years ago."}},
			],
		},
		{
			id = &"the_bonded_load",
			title = "The bonded load",
			subject = {stage = &"single", pieces = [&"ship_lightfreighter"], lights = &"battery"},
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
						return {text = "The seals answer a current reader in about a minute. They match the order in every line but one: the collector is on no registry you can reach. That lets her close the order out. She pays the reading fee from the depot account and sends over the file. It holds the order, the route it was meant to take, and nineteen years of holding notes."},
					clean = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(18))
						return {text = "Your reader gets four seals out of six. Four is what the depot rules ask for. She closes the order on that. She pays the fee at the reduced rate her sheet allows for a partial reading. Then she puts the file back in the drawer it came out of."},
					partial = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(6))
						return {text = "Two seals read and the rest are dead cells. Two is not enough for anything. She pays the standing rate for the attempt, which is small. She pays it without argument and goes back to holding the load."},
					botched = func() -> Dictionary:
						Run.drain_fuel(2)
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
			subject = {stage = &"single", pieces = [&"r6_oredock_ore_dock_pushed_3"]},
			body = "An ore dock stands lit with nobody on it. The last fuel delivery came after the last crew left, so the tanks are full. The pumps run off the dock's own power, which has not failed yet. The meter has not failed either. It logs hull number, mass and quantity. It bills an office that stopped answering years ago, and it keeps the record anyway. Below a certain draw rate it writes nothing at all. It was built to ignore a leak.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Draw under the meter",
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						Run.fuel += 4
						return {text = "You bring the line up slowly. You hold it just under the rate the meter cares about. You sit there most of a day. Four units come across, and the log shows a dock that used no fuel today. The lights stay on the whole time."},
					clean = func() -> Dictionary:
						Run.fuel += 2
						return {text = "You hold the rate down for six hours. You lose patience in the seventh. The meter starts writing in the eighth. Two units reach the tank, and a line goes into a ledger nobody reads, against a hull number that is yours."},
					partial = func() -> Dictionary:
						Run.heat += 12
						Run.fuel += 1
						return {text = "The pumps stall against a rate that low, and they keep stalling. You spend more of the day restarting them than drawing from them. One unit reaches the tank. The ship is warm from nine hours of its own systems, with the drive cold."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "A dock's fuel line, frozen for years, opened too fast.")
						return {text = "You push the rate up to where the meter would see it. The line lets go at the boom. What is in it comes out under pressure, across your flank. None of it reaches your tank. The pumps keep running for an hour with nothing to push."}},
				{label = "Settle the sheet and pump", cost_credits = 34, effect = func() -> Dictionary:
					Run.add_credits(-34)
					Run.fuel += 3
					return {text = "The meter takes a settlement from anybody who offers one. The rate was printed the year the dock opened. You pay it and the pumps run at full. Three units come across in under an hour. The receipt prints and drops into a tray that already holds a stack of them."}},
				{label = "Leave the tanks alone", stay = true, effect = func() -> Dictionary:
					return {text = "You go past with your tank as it is. The dock keeps its lights on and its meter running."}},
			],
		},
		{
			id = &"the_service_cradle",
			title = "The service cradle",
			subject = {stage = &"structure", pieces = [&"st_the_service_cradle"]},
			body = "A service cradle hangs off a dead yard. Its arms open and close on nothing, on a cycle it has kept for years. It is built for freighters. Whatever it clamps, it services. It pulls the worn units off and fits whatever is still on its racks, without asking the ship anything first. The racks are not empty. The arms close at the pressure a freighter is framed for. No ship that size has come through here in years.",
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
					Run.drain_fuel(2)
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
						return {text = "The list reads clean once you have the cell voltage right. It says what is in every case, and which of them still hold a charge. One does. You take that one off the tether. The order's own file comes with it: the posting, the address, and the name of whoever signed the job out.", module = true},
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
					Run.drain_fuel(2)
					return {text = "The order repeats hourly, and the long version runs once a day. That one carries the schedule, the routing, and every amendment made to either. You hold station a full day to get the whole of it. Burning to stay put costs you a day of fuel. You take the recording with you, and a coil of spare line off the tether.", material_id = &"frayed_line"}},
				{label = "Leave the order standing", stay = true, effect = func() -> Dictionary:
					return {text = "You log the bearing and go on. The beacon puts the order out again on the hour. The strength is the same. The address it names has not been there for a long time."}},
			],
		},
		{
			id = &"the_outbound_five",
			title = "The five going out",
			subject = {stage = &"field", pieces = [&"role:barge", &"role:hauler", &"role:small", &"role:hauler", &"role:tender"], count = 5, near = 1, deep = 2, lift = 40.0, span = 440.0, height = 240.0, seed = 5, tumble = 0.0, drive = true},
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
						return {text = "You get your bow on the carrier's stern plate. You push for nine hours. It comes up to a speed the other four can hold without extra burn. They pay the figure she named, out of five accounts. They send over their run inward as well. It has every bearing they took, every place they stopped, and the day they turned around."},
					clean = func() -> Dictionary:
						Run.heat += 12
						Run.add_credits(OptionTable.purse(20))
						return {text = "Nine hours of pushing brings the carrier most of the way up. It does not reach the speed they wanted. The drive runs hot the whole time. They pay what she named and do not argue the shortfall. The line forms up around the carrier and goes on out."},
					partial = func() -> Dictionary:
						Run.drain_fuel(2)
						Run.add_credits(OptionTable.purse(8))
						return {text = "The carrier will not hold its line under the push. You spend most of the burn correcting for it. You give it up in the sixth hour, down a day of fuel. They pay you for the hours you put in."},
					botched = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(4), "Pushed an ore carrier that would not come up to speed. The two hulls went into each other.")
						return {text = "The carrier yaws under the push in the fourth hour. Your bow goes into its quarter instead of its plate. Both hulls open, and theirs is worse. They stop talking to you. They go to work on their own ship, and nobody is paid."}},
				{label = "Take the mass they cannot carry", effect = func() -> Dictionary:
					Run.drain_fuel(2)
					return {text = "They are dumping mass to get home and would sooner it went to a ship. You pump two units into the carrier's tank. Ore comes back the other way, graded and bagged. The rate suits them, because they are not carrying it either way.", material = &"mining"}},
				{label = "Let them work it out", stay = true, effect = func() -> Dictionary:
					return {text = "You give them the bearings you have and go on past. An hour later the five of them are still in a line. They are still slow and still pointed out. The carrier is still setting the speed."}},
			],
		},
		{
			id = &"the_holding_stack",
			title = "The holding stack",
			subject = {stage = &"on_rock", loose = true, base = &"paint_rock_a1", r = 104.0, pieces = [&"r2_holding_old_container_1", &"r2_holding_old_container_2", &"r2_holding_old_container_1"], count = 3, size = 0.5, spread = Vector2(124.0, 96.0), turns = 12.0, seed = 5, clamp = &"r4_holding_cold_welded_clamp_1", face = Vector2(-34.0, -6.0)},
			body = "Containers are clamped to a rock in rows, forty or fifty of them. They were dropped here for a carrier that stopped coming. The oldest labels carry a date twenty-two years old. They also carry a consignor whose name is on nothing else out here. The clamps were shut warm and have sat at three kelvin ever since. They have cold-welded to the rails. Getting one off means running the cutter until a clamp softens. The heat that takes comes back down the grapple.",
			tags = [&"salvage"],
			group = &"",
			weight = 8,
			min_danger = 7, max_danger = 8,
			choices = [
				{label = "Cut a clamp warm and take the container",
					check = {attr = &"thermal", need = 7},
					met = func() -> Dictionary:
						return {text = "You run the cutter in long passes with the radiators wide. The clamp lets go in about an hour. Not much heat comes back into the ship. The container comes across whole. The consignment papers are in a sleeve on the door. They are printed, stamped twice, and readable from the first line to the last.", material = &"event"},
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
		# THE CREATURE EVENTS (Jon, Oct 17): an event's fight may bring a creature
		# when the text before it is about that creature. Each one names the one
		# it brings (`foe`, read by `fight_foe`), is fauna-gated, and pays what
		# animals pay: hide and fauna rolls on the quiet branches, the body's
		# exotic in its wreck after the fight, credits only from people.
		{
			id = &"in_the_wake",
			title = "In the wake",
			subject = {stage = &"single", pieces = [&"pool_fan"], fights = true},
			body = "A voidwhale calf has followed your ship since the edge of the system. It is pale and long, with thin spines down its back that fan out when it turns. Your drive is the warmest thing it has found out here. Every few minutes it swings around from the bow to push its nose into the plume. Twice it has bumped the stern hard enough to show on the hull sensors. There is no pod on the dish. A calf this young sheds as it grows, and loose hide is drifting in your wake.",
			tags = [&"fight", &"hazard"],
			group = &"",
			weight = 11,
			min_danger = 3,
			max_danger = 6,
			needs_fauna = true,
			foe = &"whale",
			choices = [
				{label = "Go cold and wait it out",
					check = {attr = &"stealth", need = 5},
					met = func() -> Dictionary:
						return {text = "You shut the drive down and let the hull cool. The calf noses along the stern for an hour and finds nothing warm. Then it leaves. The grapple picks a sheet of its hide out of your wake, and a spine it broke on your stern.", material_id = &"hide_scrap", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.drain_fuel(1)
						return {text = "It takes three hours of drifting cold before the calf loses interest and leaves. Starting the drive again costs fuel. The grapple finds one piece of loose hide in your wake and brings it in.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A voidwhale calf looking for warmth cracked the stern open.")
						return {text = "It does not lose interest. In the dark it bumps the stern twice more, and the second time cracks a plate. Then it finds the warm wake you left behind and follows that away instead."},
					botched = func() -> Dictionary:
						return {text = "The calf does not like the cold hull. It circles the ship twice, faster each time, with its spines spread wide. Then it swings its tail at you.", fight = true}},
				{label = "Drive it off with the guns", fight = true, effect = func() -> Dictionary:
					return {text = "You come about and put a shot across its path to scare it off. It does not run. It spreads its spines wide and comes at the ship, tail first.", fight = true}},
				{label = "Let it follow", stay = true, effect = func() -> Dictionary:
					return {text = "You hold your course and let it nose along behind you. It bumps the stern now and then, and the hull sensors log each bump."}},
			],
		},
		{
			id = &"the_tow_cable",
			title = "The tow cable",
			subject = {layers = [{stage = &"single", pieces = [&"role:barge"], dark = 0.7, at = Vector2(90.0, -40.0)}, {stage = &"single", fights = true, pieces = [&"pool_fan"], at = Vector2(-90.0, 50.0)}]},
			body = "A dead ore barge drifts at the edge of the system with its tow cable still trailing from the stern. A voidwhale calf has wound itself into the cable. It is pale, with thin spines along its back. Every time it pulls, the cable cuts in deeper between the spines. The dish picked up its calls for a while. They have stopped. The barge's forward hold reads full of ore. There is no claim filed on the barge, and the dish shows no other ship in the system.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 11,
			min_danger = 1,
			max_danger = 4,
			needs_fauna = true,
			foe = &"whale",
			choices = [
				{label = "Cut the calf free",
					check = {attr = &"maneuver", need = 4},
					met = func() -> Dictionary:
						return {text = "You bring the cutter in along the cable and take it apart one length at a time. The calf holds still for the last cut. Then it moves off slowly toward the dark. One of its spines broke off in the cable, and the grapple takes it.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 5
						return {text = "It takes two hours with the cutter running hot. The calf pulls once and then holds still until the last length parts. It leaves a broken spine in the cable, and the grapple takes it.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(2), "A barge's tow cable, pulled tight by a frightened calf.")
						return {text = "The calf pulls at the wrong moment, and the cable whips across your bow. It takes a strip of plating with it. The calf tears loose on its own and is gone. The grapple comes back empty."},
					botched = func() -> Dictionary:
						return {text = "The cutter catches the calf instead of the cable. It tears itself free in one pull. Then it turns on your ship with its tail up and its spines spread.", fight = true}},
				{label = "Work the barge's hold around it", fight = true, effect = func() -> Dictionary:
					return {text = "The grapple gets one load of ore out of the forward hold. Then the barge shifts, and the cable cuts into the calf again. It tears loose and comes straight at your ship.", material = &"mining", fight = true}},
				{label = "Leave the barge", stay = true, effect = func() -> Dictionary:
					return {text = "You log the barge's position and the calf beside it, and fly on. The calf has stopped pulling. It is still caught in the cable."}},
			],
		},
		{
			id = &"the_harpoon_line",
			title = "The harpoon line",
			subject = {layers = [{stage = &"single", pieces = [&"ship_scoop"], lights = &"run", at = Vector2(110.0, -55.0)}, {stage = &"single", fights = true, pieces = [&"pool_lev_spine"], at = Vector2(-80.0, 45.0)}]},
			body = "A hunting ship has a harpoon line in a void leviathan, and the leviathan is towing the ship. It is dark blue and plated like a hull, with a ridge of pale crystal down its back. It is longer than the hunting ship. The crew cannot reel it in, and they will not cut the line. Their pilot is on the open channel. She asks for a ship with guns to finish it while she holds on. She will pay as soon as you agree.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 8,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Finish it for her", fight = true, effect = func() -> Dictionary:
					Run.add_credits(OptionTable.purse(24))
					return {text = "She pays. You come in on the leviathan's flank while the line holds it still. It turns away from the line, toward the heat of your drive, and comes at you.", fight = true}},
				{label = "Cut her line",
					check = {attr = &"maneuver", need = 6},
					met = func() -> Dictionary:
						return {text = "You run the cutter along the line until it parts near the harpoon. The leviathan stops pulling and drifts off slowly toward the dark. A crystal broke off its back where the line went in, and the grapple takes it. The pilot is angry and says so on the open channel for some time.", material = &"fauna"},
					clean = func() -> Dictionary:
						Run.heat += 10
						return {text = "The line takes three passes of the cutter, and the third runs hot. When it parts, the leviathan leaves at once. You take one broken crystal from the drift. The hunters do not hail you again.", material = &"fauna"},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Cut a harpoon line under load and stayed in its way.")
						return {text = "The line parts while you are still alongside it. The free end whips across your hull and opens a seam. The leviathan is gone, and so is the hunters' catch. You come away with nothing."},
					botched = func() -> Dictionary:
						return {text = "The cut is slow, and the leviathan feels it through the line. It turns from the hunting ship toward your drive. The line goes slack as it comes for you.", fight = true}},
				{label = "Leave them to it", stay = true, effect = func() -> Dictionary:
					return {text = "You stay off the channel and fly on. The last you read of them, the leviathan is still towing the hunting ship away from the star."}},
			],
		},
		{
			id = &"the_grown_plate",
			title = "The grown plate",
			subject = {stage = &"single", pieces = [&"pool_lev_spine"], fights = true},
			body = "A void leviathan is resting in the shadow of a cold world. It is dark blue and plated like a hull, with pale crystal down its back. One plate on its flank came off a ship. It has grown in at the edges, and a registry number is still painted on it. The registry office at Harl Station lists that number as missing. The clerk there pays for proof of what became of a ship. The leviathan has not moved in a day.",
			tags = [&"fight", &"contract"],
			group = &"",
			weight = 8,
			min_danger = 5,
			max_danger = 10,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Read the number from close in",
					check = {attr = &"sensors", need = 7},
					met = func() -> Dictionary:
						Run.add_credits(OptionTable.purse(28))
						return {text = "You come in slowly until the dish can read the paint, and you record the plate from three sides. The leviathan never wakes. You send the record to the registry office at Harl Station. The clerk checks the number against the list and pays."},
					clean = func() -> Dictionary:
						Run.heat += 10
						Run.add_credits(OptionTable.purse(18))
						return {text = "The dish needs a long look before the paint will read, and the drive runs warm holding you that close. You send the record to Harl Station. The clerk takes it and pays less for one this rough."},
					partial = func() -> Dictionary:
						Run.take_hull_damage(OptionTable.toll(3), "Too close to a sleeping leviathan when it shifted.")
						return {text = "It shifts in its sleep while you are close. A crystal on its back scrapes the length of your hull. The record you got is too poor to send, and you back off with a damaged hull."},
					botched = func() -> Dictionary:
						return {text = "It wakes with your ship a few hundred metres off its flank. The crystals along its back light up, and it comes straight at you.", fight = true}},
				{label = "Cut the plate out", fight = true, effect = func() -> Dictionary:
					return {text = "You get the cutter onto the edge of the plate. The leviathan wakes at the first touch and rolls toward your ship. The plate is still in its flank.", fight = true}},
				{label = "Leave it sleeping", stay = true, effect = func() -> Dictionary:
					return {text = "You log the number and the world it sleeps beside. The clerk at Harl Station only pays for a record, so you send nothing and fly on."}},
			],
		},
		{
			id = &"the_warm_reactor",
			title = "The warm reactor",
			subject = {layers = [{stage = &"single", pieces = [&"role:hauler"], dark = 0.8, at = Vector2(40.0, -60.0)}, {stage = &"single", fights = true, flip = true, pieces = [&"pool_lev_spine"], at = Vector2(80.0, 55.0)}]},
			body = "A dead freighter hangs off the star with its reactor still warm. A void leviathan stays close to the stern to feed on the heat. It is dark blue and plated, and the pale crystal on its back glows in the reactor's light. The freighter's forward holds are sealed and read full. They are at the bow, the far end from the leviathan. The transponder is dead. The leviathan moves only to press closer to the reactor.",
			tags = [&"fight", &"salvage"],
			group = &"",
			weight = 8,
			min_danger = 6,
			max_danger = 10,
			needs_fauna = true,
			foe = &"leviathan",
			choices = [
				{label = "Open the forward holds cold",
					check = {attr = &"stealth", need = 7},
					met = func() -> Dictionary:
						return {text = "You come in cold on the bow and open the first hold with the cutter on its lowest setting. The leviathan never moves from the reactor. The grapple brings out one sealed crate, and you are gone before it stirs.", material = &"wreck"},
					clean = func() -> Dictionary:
						Run.heat += 12
						return {text = "You get one hold open, but running quiet that long lets heat build up inside the ship. The grapple brings out a sealed crate. The leviathan shifts once at the stern and settles again.", material = &"wreck"},
					partial = func() -> Dictionary:
						Run.heat += 16
						return {text = "You get the hold half open before the leviathan lifts its head. You back off and wait. It settles again, but by then the hull is warm and you have nothing aboard."},
					botched = func() -> Dictionary:
						return {text = "A hold door lets go all at once, and the whole freighter shakes. The leviathan leaves the reactor and comes along the freighter's length toward you.", fight = true}},
				{label = "Drive it off the reactor", fight = true, effect = func() -> Dictionary:
					return {text = "You put a shot into the plates on its back from the stern side. It leaves the reactor and turns. It comes at you along the freighter's length.", fight = true}},
				{label = "Leave it feeding", stay = true, effect = func() -> Dictionary:
					return {text = "You keep well clear of the freighter and fly on. You run the drive cold until you are past the star, so the leviathan has no heat to follow."}},
			],
		},
	])
	return out
