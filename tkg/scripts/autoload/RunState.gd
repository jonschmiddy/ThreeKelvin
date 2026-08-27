extends Node
## Everything that persists across a run: ship, cargo, economy, map position.
## Combat state lives in Combat.gd and is discarded when the fight ends.

var hull: HullData
var installed: Array[ModuleData] = []
var cargo: Array[ModuleData] = []
## Which galaxy this run is flown in. Chosen once at the start so the chart
## is the same shape all the way through — a map that changes shape is not a
## map. 0 two-arm spiral, 1 barred, 2 four-arm.
## Every system you have been to, in order. The route you actually took is the
## story of the run, and it should be on the chart.
var trail: PackedInt32Array = PackedInt32Array()
var galaxy_kind: int = 0
## The rolled parameters for THIS galaxy, and the seed its star field is built
## from. Both fixed for the life of the run: the chart rebuilds its stars from
## the seed, and the map derives system positions from the parameters, so either
## changing mid-run would redraw the sky and move the systems under the player.
var galaxy: Dictionary = {}
var galaxy_seed: int = 0
## How far the whole galaxy is turned. The run starts on the rim at the first
## row of the outermost shell, and that row sat at angle zero — so every run
## began on the right-hand edge of the disc. Turning the entire thing by a
## rolled angle, arms and systems together, moves the start anywhere around the
## rim without disturbing a single relative position.
var galaxy_spin: float = 0.0

var galaxy_name: String = ""
var galaxy_title: String = ""

var hp: int = 35
var heat: int = 0
var heat_cap_bonus: int = 0
var credits: int = 40
## FUEL AND DROSS ANNOUNCE THEMSELVES. See the note below.
var fuel: int = 150:
	set(v):
		fuel = v
		Sig.resources_changed.emit()

## Raw materials, by id. See DB.MATERIALS.
##
## CREDITS are still the only CURRENCY — the ruling has not moved, only the name
## has. These are not a second wallet; nothing on a price tag is denominated in
## them. They are prerequisites: a recipe that costs forty credits is a purchase,
## and a recipe that costs one precursor fragment is a reason to have flown
## somewhere.
##
## ALLOY was the counter-example and it is gone. It came off every part you broke
## down, so it accumulated from the hold you were emptying anyway rather than from
## anywhere you went — a resource with a faucet that large is a second currency
## whatever the ruling calls it.
var materials: Dictionary = {}

## Exotic was a bare int here from the day megafauna existed, and about fifteen
## call sites still read and write it that way. It is now the `exotic` row of
## the ledger above, reached through a property so that every one of those sites
## keeps working against the single store rather than against a copy that would
## drift out of step with it the first time something forgot to update both.
## EMITS, like `fuel` and `dross` and for the same reason. It is a view onto
## `materials`, and `add_material()` — the other door onto the same dictionary —
## has always announced itself. This one did not, so of the five places that
## write `Run.exotic` directly, four left the reading on screen stale until some
## unrelated redraw happened to correct it. That is the third instance of the
## class of bug the header above describes, found by looking for it rather than
## by anyone noticing a wrong number.
var exotic: int:
	get:
		return int(materials.get(&"exotic", 0))
	set(v):
		materials[&"exotic"] = maxi(0, v)
		Sig.resources_changed.emit()
## WHICH malfunctions are lodged in you, not how many.
##
## It was a count, and a count could only ever produce one card sixteen times.
## The ids are stored so the deck can be rebuilt identically on every load and
## every deck-build — rolling which malfunction at build time would have given
## you a different set of junk every time the screen refreshed.
var dross: Array[StringName] = []:
	set(v):
		dross = v
		Sig.ship_changed.emit()

## How much junk, for everything that only wants the number.
func dross_count() -> int:
	return dross.size()

## Lodge one in the ship.
##
## `which` names it; empty rolls one against `danger`. Named beats rolled so an
## enemy or an event can say what it does to you — a spore fusing something into
## the rack is characterisation, and "some junk" is not.
func add_dross(danger: int, which: StringName = &"") -> void:
	var next := dross.duplicate()
	next.append(which if which != &"" else DB.roll_malfunction(danger))
	dross = next

## Take one named malfunction out, and only one. Returns whether it was there.
func clear_dross(which: StringName) -> bool:
	var at := dross.find(which)
	if at < 0:
		return false
	var left := dross.duplicate()
	left.remove_at(at)
	dross = left
	return true

## WHY THESE TWO HAVE SETTERS AND `heat` DOES NOT.
##
## Three bugs in one day had one shape: a field on this object written directly
## from somewhere else, with the signal that redraws it left to the call site to
## remember. `heat_cap_bonus` forgot it entirely and the gauge sat at the old
## number. `found_hull` never moved `hauls`, so a claimed hull could not be seen.
## Both were fixed with a bespoke mutator, one at a time — which cures two call
## sites and leaves the CLASS of bug intact: `fuel` and `dross` are written from
## about twenty places across six files, each one pairing a write with a
## hand-rolled emit.
##
## A setter is the general fix and it costs the call sites nothing: every
## existing `Run.fuel -= n` now redraws by construction, and the manual emits
## beside them become redundant rather than load-bearing. `Sig` is registered
## before `Run` in project.godot, so the initialiser above is safe.
##
## `heat` is deliberately left alone. It is written inside the combat loop —
## every card that costs or vents heat, plus the end-of-turn burn — so a signal
## per write is a screen rebuild per write, several times a turn. That is the
## efficiency problem this pass is also trying to remove. Rare, chunky writes get
## the guardrail; the one field on the hot path keeps manual control, and this
## paragraph is the reason rather than an oversight.
##
## `kills` has no setter for a different reason: nothing on screen reads it, so
## announcing it would be work with no listener.

var map: Array = []
var at: int = 0

var jumps: int = 0
var kills: int = 0
## Wall clock, seconds since the epoch, set when the run begins and carried
## through the save. A run spans sessions now, so a frame counter or a tree
## timer would only ever measure the last sitting.
var started_at: float = 0.0
var won: bool = false
var dead: bool = false
var death_reason: String = ""

## How many times something has ARRIVED in the hold from outside the ship.
##
## Bumped by stow() and by nothing else, which is the whole point: salvage, a
## purchase and a fabrication are hauls, and a part moved off a hardpoint is
## not. The sector screen re-opens its salvage prompt on this rather than on
## `cargo.size()` — the size went up when you unbolted something on the refit
## screen too, so putting your own coolant line in the hold made the sector
## offer it back to you as fresh salvage.
##
## Deliberately outside the save. It is a UI edge, not run state, and a resumed
## run showing its hold once is the behaviour it already had.
var hauls: int = 0

## The salvage rail was dismissed, and the state it was dismissed in.
##
## ON THE RUN, NOT ON THE SCREEN, and that is the whole of a bug rather than a
## preference. `SectorScreen` is rebuilt from scratch on every jump — `Router`
## makes a new one — so a `_stowed` flag living on it was forgotten the instant
## you left the system. Stow a part, jump, and the rail opened again and asked
## the same question about the same cargo, at every system, for the rest of the
## run.
##
## Two numbers rather than a bool, because "dismissed" has to expire on the right
## events and only those: a fresh HAUL is new cargo and should re-open it, and a
## BAG at a system you have not seen is new loot and should too. Arriving
## somewhere new carrying the same parts you already decided about is neither.
##
## DELIBERATELY OUTSIDE THE SAVE, and that is not symmetry for its own sake — it
## is the only way this can be correct. `hauls` above is not saved either, so it
## comes back as 0; save the dismissal beside it and a run resumed after stowing
## at haul 12 has `hauls` 0 against a hush of 12, and `hauls > hushed` is false
## for the next twelve hauls. The rail would stay shut over loot the player had
## just recovered.
##
## Worth naming because the previous version of the rule got away with it: an
## equality test fail-OPENED on that mismatch (0 != 12, so the rail showed), and
## changing it to "is anything new" inverted the failure into a silent one. A
## fix that is correct in isolation can break the thing next to it.
var salvage_hushed_hauls: int = -1
var salvage_hushed_bag: int = -1


## Whether the salvage rail should stay shut. `bag_here` is the index of the
## system you are standing in if it has loose salvage, or -1.
##
## THE TEST IS "IS ANYTHING NEW", NOT "IS THE STATE THE SAME", and the first
## version got that backwards. It asked whether the haul count and the bag
## matched what they were at dismissal — so stowing while standing over a bag
## recorded that bag, and the next system, having no bag, compared -1 against it,
## failed the equality and opened the rail again. A bag you walked away from is
## not new salvage. Nothing happened; something merely stopped.
##
## Two things are new and nothing else is: the hold GREW since you dismissed it,
## or there is a bag at a system that is not the one you dismissed at.
func salvage_hushed(bag_here: int) -> bool:
	if salvage_hushed_hauls < 0:
		return false
	# DIFFERENT, not greater. Within a run `hauls` only climbs, so the two read
	# the same — but `>` quietly assumes that, and the assumption is exactly what
	# broke when the dismissal was persisted and `hauls` (which is not) came back
	# as zero: `0 > 12` is false, so the rail stayed shut over loot already in the
	# hold. The dismissal is no longer saved and this no longer relies on that
	# being true. Any haul count that is not the one dismissed at means the hold
	# is not the hold that was dismissed.
	if hauls != salvage_hushed_hauls:
		return false
	if bag_here >= 0 and bag_here != salvage_hushed_bag:
		return false
	return true

## Work you have taken, in the order you took it. See ContractData.
##
## Nothing in here expires and nothing in here is contested — two ships can hold
## the same job and both be paid for flying it. See Contracts.
var contracts: Array = []
## Handed out on acceptance so a contract can be referred to after it is closed.
var next_contract_id: int = 1

## What each manufacturer thinks of you, by id. Higher is better and it only goes up.
##
## GOODS, NEVER SECRETS. `docs/lore.md` §2 rules that there is no promotion — no
## rank, no inner circle, no point at which a manufacturer starts telling you things —
## and that ruling stands unchanged. This is not a relationship, it is an
## account: deliver their work and their berths pay you better for your parts and
## carry more of their stock. They still never explain anything.
##
## Deliberately not a reputation you can lose. A manufacturer that can be offended is a
## manufacturer you can lock yourself out of by playing badly, which is a punishment for
## the player who most needs the money.
var standing: Dictionary = {}

## Offered for transfer. HAS A SETTER, for the reason the header above gives —
## this is the second of the two bugs that paragraph names, and it was left as a
## bare field when `fuel` and `dross` were fixed. Three places outside this file
## cleared it; two remembered the emit and `Policy.gd` did not.
var found_hull: HullData = null:
	set(v):
		found_hull = v
		Sig.ship_changed.emit()
var whale_boon: bool = false

const MAP_CANVAS := Rect2(60, 50, 900, 430)

## A galaxy exists before any run does — screens can be built and asked to draw
## before start_new_run() has rolled one — so it is never an empty dictionary.
func _ready() -> void:
	# A dive that is already under way when this machine generates its map — and
	# every claim made while it was generating it.
	Sig.party_map_changed.connect(adopt_party_claims)
	if galaxy.is_empty():
		galaxy = GalaxyGen.params(0).duplicate()
	# Max hull is no longer a constant of the chassis, so taking plating off has
	# to take the hull it was holding with it. Hung on the signal rather than
	# called from the four places that move `installed`, because one of those is
	# ShipScreen's drag handler editing the array directly — a rule enforced at
	# every call site is a rule that is one new call site away from being false.
	Sig.ship_changed.connect(_clamp_hp)

func _clamp_hp() -> void:
	if hull == null:
		return
	var cap := max_hp()
	if hp > cap:
		hp = cap
		Sig.resources_changed.emit()

## Begin a run in a given manufacturer's chassis.
##
## The argument is optional and empty means "roll one", which is not a
## convenience: HeadlessSim calls this directly, and a default of Korvan would
## have every one of two hundred simulated runs fly the same ship and report a
## win rate for one seventh of the game. Random here means the sim exercises all
## seven starts for free.
func start_new_run(manufacturer: StringName = &"", w: int = -1) -> void:
	# The seed FIRST, before anything is rolled, because everything below is
	# drawn from it. This is the one number a run IS: `-- seed 12345` replays it
	# exactly, and a co-op host sends this and nothing else to put four ships in
	# one galaxy. See Rng.
	galaxy_seed = Rng.roll_master()
	# ...and which ship in the party is drawing from it. One seed gives four
	# machines one galaxy, which is the point; it must not also give them one
	# hold. See Rng.seat.
	Rng.reseed(galaxy_seed, Net.seat())

	# A weight of -1 rolls one, for the same reason an empty manufacturer does:
	# HeadlessSim calls this directly, and a fixed default would report a win
	# rate for one twenty-first of the possible starts.
	#
	# Off a DERIVED generator rather than the world stream. The starting ship is
	# not part of the world — in a party, four players fly four different hulls
	# through one galaxy — so choosing one must not move the map.
	var start_rng := Rng.derive(&"start", 0)
	var weight: HullData.Weight = w as HullData.Weight
	if w < 0:
		weight = Rng.pick(start_rng, [HullData.Weight.LIGHT,
			HullData.Weight.MEDIUM, HullData.Weight.HEAVY])
	fit_chassis(manufacturer, weight)
	cargo.clear()
	heat = 0
	heat_cap_bonus = 0
	credits = 40
	materials.clear()
	# STILL SCALED TO GALAXY DEPTH, though the reason narrowed. It went in when
	# RIM was derived and the disc was 1.75x wider, which it no longer is -- but
	# a fifteen-ring galaxy still asks for fourteen ring-crossings against nine's
	# eight, plus the lateral travel between them, and a flat 150 was tuned
	# against the shorter one. LAYERS 9 gives back exactly 150.
	fuel = int(round(FUEL_PER_RING_STEP * float(MapGen.LAYERS - 2)))
	dross = []
	jumps = 0
	kills = 0
	hauls = 0
	contracts.clear()
	next_contract_id = 1
	salvage_hushed_hauls = -1
	salvage_hushed_bag = -1
	# Standing is a RUN thing, not a career. It buys prices and stock inside one
	# dive, and starting a fresh dive means walking into the same berths as a
	# stranger again — which is the only shape that does not turn into the
	# meta-progression `Unlocks` was careful to keep power out of.
	standing.clear()
	started_at = Time.get_unix_time_from_system()
	won = false
	dead = false
	death_reason = ""
	found_hull = null
	whale_boon = false
	galaxy_kind = Rng.world.randi() % GalaxyGen.count()
	galaxy = GalaxyGen.roll(galaxy_kind)
	galaxy_spin = Rng.world.randf() * TAU
	galaxy_name = GalaxyGen.roll_name()
	galaxy_title = GalaxyGen.roll_title()
	map = MapGen.generate(MAP_CANVAS)
	# Whatever the party has already used up. A run rolled from the host's seed
	# is generated after the party exists, so the list can predate the map.
	adopt_party_claims()
	_spawn_hellbender()
	at = 0
	trail = PackedInt32Array([0])
	_range_cache.clear()
	Sig.run_started.emit()
	# THE DISH IS ALREADY ON. Without this the first system's neighbours are
	# invisible until the first jump, which reads as sensors not working at
	# all on the one screen a new run opens to.
	chart_from(node_at())
	Sig.resources_changed.emit()
	Sig.ship_changed.emit()
	log_line("Reactor cold-started. The core is twenty jumps coreward, at least.", &"big")

## Put a manufacturer's chassis and starting kit under the player, at full hull.
##
## Separate from start_new_run because the chassis select calls it once per
## click while you browse the seven. Folded together, changing your mind about a
## ship would roll a new galaxy, a new name and a new map each time — so the
## world you were about to fly into would quietly change while you compared
## Thermal numbers. Rolling the world is a run-start concern; fitting a ship is
## not.
## `tier` is a DEV affordance and defaults to C, which is what every real run
## starts on. Nothing in the game grants a graded frame at the yard — you find
## those in wrecks. The chassis select exposes it behind Developer Mode so a
## build can be flown at the grade it was designed around without playing to it.
func fit_chassis(manufacturer: StringName = &"",
		w: HullData.Weight = HullData.Weight.MEDIUM, tier: int = 0) -> void:
	var chosen := manufacturer
	if chosen == &"" or not DB.STARTER_WEAPON.has(chosen):
		chosen = Rng.pick(Rng.derive(&"start", 1), DB.STARTABLE)
	hull = DB.at_tier(DB.hull_for(chosen, w) as HullData, tier)
	installed.clear()
	# Only what fits. The kit is written per manufacturer but the hardpoints
	# belong to the weight class, so a light frame launches with fewer modules
	# than a heavy one carrying the same kit — you traded guns for speed and the
	# loadout says so. Installing past the slot count would let the select screen
	# hand you a ship the refit screen considers illegal.
	for id in DB.starter_kit(chosen):
		var m := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
		if slots_used(m.slot) >= slots_for(m.slot):
			continue
		# AND THE REACTOR HAS TO CARRY IT. A C-grade frame is issued less of its
		# own kit than an S-grade one, which is what the letter means.
		if not can_power(m):
			continue
		m.mount = free_mount(m.slot)
		installed.append(m)
	_top_up_deck()
	hp = max_hp()
	heat = 0
	Sig.ship_changed.emit()
	Sig.resources_changed.emit()

## The lowest hardpoint of this type nothing is bolted to, or -1 if full.
func free_mount(s: ModuleData.Slot) -> int:
	for i in slots_for(s):
		if module_at(s, i) == null:
			return i
	return -1

## What is bolted to one specific hardpoint.
func module_at(s: ModuleData.Slot, index: int) -> ModuleData:
	for m in installed:
		if m.slot == s and m.mount == index:
			return m
	return null

## The hold's shape, in cells. See HullData.hold_grid.
func hold_grid() -> Vector2i:
	return hull.hold_grid if hull != null else Vector2i(4, 5)

## How many CELLS the hold has. Was a module count; a module now has a size.
##
## Kept under its old name because everything that reads it — the dock, the
## chassis select, the sector audio cue — is asking "how big is this ship's
## hold", and that question did not change.
func cargo_slots() -> int:
	return hold_grid().x * hold_grid().y

## Cells currently occupied.
func cargo_used() -> int:
	var n := 0
	for m in cargo:
		n += m.cells()
	return n

## Whether a SPECIFIC part fits, which is the only form of the question a grid
## can answer.
##
## `hold_full()` used to be a property of the hold alone. It cannot be any more:
## a hold with four free cells has room for four fittings, one bulky array, or a
## long gun only if three of those cells happen to lie in a row. Callers that
## want a yes/no now have to say what they are trying to put down.
func has_room_for(m: ModuleData) -> bool:
	return find_hold_slot(m) != -Vector2i.ONE

## True when nothing at all will fit — the honest replacement for `hold_full`,
## used where there is no particular module in hand.
func hold_full() -> bool:
	var one := ModuleData.new()
	one.size = Vector2i.ONE
	return not has_room_for(one)

## Every cell a part covers at a given origin.
func _cells_of(m: ModuleData, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var f := m.footprint()
	for dy in f.y:
		for dx in f.x:
			out.append(at + Vector2i(dx, dy))
	return out

## Can `m` sit at `at`, ignoring itself if it is already down?
func can_place(m: ModuleData, at: Vector2i) -> bool:
	var g := hold_grid()
	if at.x < 0 or at.y < 0:
		return false
	var f := m.footprint()
	if at.x + f.x > g.x or at.y + f.y > g.y:
		return false
	var taken := {}
	for other in cargo:
		if other == m or other.hold_at.x < 0:
			continue
		for c in _cells_of(other, other.hold_at):
			taken[c] = true
	for c in _cells_of(m, at):
		if taken.has(c):
			return false
	return true

## Put a part in the hold, finding it a cell. False when nothing fits.
##
## THE ONLY DOOR INTO `cargo`, with take_from_hold as the only way out. A bare
## append leaves a module at (-1,-1) — in the array, drawn nowhere, overlapping
## everything because it claims no cells — and that is a bug you find later, in
## the UI, looking like a part that vanished.
func place_in_hold(m: ModuleData, at: Vector2i = -Vector2i.ONE) -> bool:
	var cell := at if at != -Vector2i.ONE else find_hold_slot(m)
	if cell == -Vector2i.ONE or not can_place(m, cell):
		return false
	m.hold_at = cell
	if not cargo.has(m):
		cargo.append(m)
	Sig.ship_changed.emit()
	return true

## Take a part out, releasing its cells.
func take_from_hold(m: ModuleData) -> void:
	cargo.erase(m)
	m.hold_at = -Vector2i.ONE

## Re-seat everything, largest first, after the grid changes shape.
##
## Called when the hull is swapped: a heavy's 4x10 hold becomes a light's 4x5 and
## every part below the fifth row is now outside the grid. Largest first because
## first-fit on a fresh grid strands big parts behind small ones — the one place
## a rule other than "leave it where it was" is worth having, since the player
## did not arrange this and cannot be surprised by it.
func repack_hold() -> void:
	var all := cargo.duplicate()
	all.sort_custom(func(a: ModuleData, b: ModuleData) -> bool:
		return a.cells() > b.cells())
	cargo.clear()
	var lost: Array[ModuleData] = []
	for m in all:
		m.hold_at = -Vector2i.ONE
	for m in all:
		var cell := find_hold_slot(m)
		if cell == -Vector2i.ONE:
			lost.append(m)
			continue
		m.hold_at = cell
		cargo.append(m)
	for m in lost:
		log_line("No room for %s in the new hold. Left behind." % m.name, &"them")

## First cell the part fits in, scanning rows then columns, or (-1,-1).
##
## Row-major FIRST FIT rather than best fit. Best fit packs tighter and moves
## things around behind your back to do it; the hold is a place you arranged, so
## a predictable rule you can learn beats a clever one you cannot.
func find_hold_slot(m: ModuleData) -> Vector2i:
	var g := hold_grid()
	for y in g.y:
		for x in g.x:
			var at := Vector2i(x, y)
			if can_place(m, at):
				return at
	return -Vector2i.ONE

## This system is finished: the wreck is stripped, the fight is won, the hail is
## answered. THE ONE DOOR, and the reason it exists is co-op.
##
## A shared seed gives four machines an identical galaxy rather than a shared
## one — every wreck holds the same modules on every machine, because what a
## node holds is drawn from `Rng.derive(tag, node.index)` and depends on where
## it is rather than on who asked. The one thing a seed cannot say is whether
## somebody has already been there. So consuming a node has to be told, and
## telling it from one place means a new way to finish a system is shared by
## construction instead of by somebody remembering to add a line.
##
## `Net.claim()` does nothing in the solo game, which is why every call site
## could be changed without a branch.
func consume_node(n: MapGen.MapNode) -> void:
	take_whole(n)


## The system itself, used up. Marked locally and told to the party without
## waiting for an answer.
##
## Fire and forget is correct HERE and wrong in take_option(). These are the
## outcomes nobody can take out from under you — the fight you just won, the
## hail you were already inside — so a round trip would buy nothing and would
## show the wreck you just stripped as still full while it ran.
func take_whole(n: MapGen.MapNode) -> void:
	if n == null or n.cleared:
		return
	n.cleared = true
	_mark_taken(n, MapGen.OPTION_WHOLE)
	Net.claim(n.index, MapGen.OPTION_WHOLE)


## One option at this system, when only one ship can have it. Returns whether
## you got it, and awaits the party's answer if there is a party.
##
## THE ONE THAT HAS TO ASK. Two ships reach the same wreck in the same second;
## if both assume they won, both roll the loot, and the flag agreeing a moment
## later does not take the module back out of the loser's hold. So the caller
## does not get to act until it is told, and every caller has to actually read
## the answer — which is why this returns a bool instead of quietly doing
## nothing.
##
## Solo returns true immediately: `Net.take()` answers with your own id when
## there is nobody to ask.
func take_option(n: MapGen.MapNode, option: int) -> bool:
	if n == null or n.taken.has(option):
		return false
	var owner := await Net.take(n.index, option)
	# Gone either way, so it is recorded either way. A wreck somebody else
	# stripped is not a wreck you can try again.
	_mark_taken(n, option)
	if option == MapGen.OPTION_WHOLE:
		n.cleared = true
	Sig.map_changed.emit()
	return owner == Net.local_id()


## What a shared kill left floating, rolled once and agreed by everybody.
##
## `drops` is what the fight would have paid one ship. `hands` is how many ships
## were still in it when the last hull came apart — `SharedFight.paid`, frozen by
## the host so that four machines cannot each read a crew list at a different
## point in its unwinding.
##
## POSITIONAL, LIKE EVERYTHING ELSE THAT BELONGS TO A PLACE. `Rng.derive()` seeds
## from the node index, so every machine rolls the identical bag without a byte
## of it crossing the wire — the same trick that lets one seed put one wreck and
## one shelf on four machines. What travels is only which parts are GONE, which
## is the one fact a seed cannot carry.
##
## Deliberately NOT off `Rng.loot`. That stream is salted by seat precisely so
## that what is paid to a PLAYER differs per player; a bag is paid to the party,
## so it must not.
func open_bag(n: MapGen.MapNode, drops: int, hands: int) -> void:
	if n == null or n.bagged or drops <= 0:
		return
	n.bagged = true
	var r := Rng.derive(&"bag", n.index)
	var force := n.manufacturer if n.region == MapGen.Region.TERRITORY else &""
	# Scaled by the crew, so bringing a friend does not halve what the fight is
	# worth to you. The enemy already grew by CREW_SHARE to meet them; this is
	# the other side of that bargain.
	for i in drops * maxi(1, hands):
		n.bag.append(LootGen.roll_module(n.danger, force,
			n.region == MapGen.Region.CORE, r))
	Sig.map_changed.emit()


## Reach into the bag. Returns whether the part is now in your hold.
##
## ASKS AND WAITS, for exactly the reason the wreck does: two ships reach for the
## same part in the same second, and a flag that agrees a moment later does not
## take it back out of the loser's hold.
##
## The hold is checked BEFORE the claim, not after. Claiming a part you have
## nowhere to put would burn it for the whole party — gone from the bag, in
## nobody's hold — which is the shop's "ask, then pay" ordering seen from the
## other end. It is also the solo bug that ordering already fixed once.
func take_from_bag(n: MapGen.MapNode, i: int) -> bool:
	if n == null or i < 0 or i >= n.bag.size():
		return false
	var option := MapGen.OPTION_BAG + i
	if n.taken.has(option):
		return false
	var m: ModuleData = n.bag[i]
	if hold_full():
		log_line("The hold is full. %s stays where it is." % m.name, &"them")
		return false
	if not await take_option(n, option):
		var who := Net.taker_name(n.index, option)
		log_line("%s is already gone.%s" % [m.name,
			" %s took it." % who.to_upper() if who != "" else ""], &"them")
		return false
	stow(m)
	return true


## Whether this system still has something floating in it for you.
##
## Counts what is LEFT, not what was rolled — a bag everybody has emptied is not
## a bag, and the sector rail has to be able to tell the difference without
## walking the taken list itself.
func bag_left(n: MapGen.MapNode) -> int:
	if n == null:
		return 0
	var left := 0
	for i in n.bag.size():
		if not n.taken.has(MapGen.OPTION_BAG + i):
			left += 1
	return left


func _mark_taken(n: MapGen.MapNode, option: int) -> void:
	if not n.taken.has(option):
		n.taken.append(option)


## What the party has already used up, applied to this machine's map.
##
## The whole list every time rather than the new entries. It is tens of systems
## in a dive, it is idempotent, and a list rebuilt from scratch cannot drift the
## way a stream of deltas can the first time one arrives twice.
func adopt_party_claims() -> void:
	if map.is_empty():
		return
	var moved := false
	for key in Net.claims:
		var i := int(key)
		# Out of range cannot happen behind the content fingerprint and a shared
		# seed. It is checked because the alternative is an index error taking
		# the chart down on whoever receives it.
		if i < 0 or i >= map.size():
			continue
		var n: MapGen.MapNode = map[i]
		for option in Net.claims[key]:
			var o := int(option)
			if n.taken.has(o):
				continue
			n.taken.append(o)
			moved = true
			if o == MapGen.OPTION_WHOLE:
				n.cleared = true
	if moved:
		Sig.map_changed.emit()


## Put a part in the hold, or refuse.
##
## The one door into `cargo`, so the hold has a size that means something. It
## returns whether it took the part, and callers are expected to care — a wreck
## that hands you a module you cannot carry has to say so rather than silently
## dropping it or silently exceeding the limit.
##
## Forced moves do NOT come through here. install_module evicts the worst part
## to make room for something you asked to fit, and uninstalling to a full hold
## is refused at the point of asking; neither can be allowed to destroy a module
## because the arithmetic did not work out.
func stow(m: ModuleData) -> bool:
	if not place_in_hold(m):
		log_line("No room in the hold for %s." % m.name, &"them")
		return false
	hauls += 1
	Sig.ship_changed.emit()
	return true

## How many cards the fitted modules put in the deck.
func deck_size() -> int:
	var n := 0
	for m in installed:
		n += m.grant_count()
	return n

## Fill spare mounts with more yard stock until the deck can actually be drawn
## from.
##
## The starting kit is one shape — a weapon, two systems, a utility — and the
## frames are not. Four manufacturers drop a weapon mount, so on a LIGHT frame their
## generic weapon had nowhere to go and two cards vanished, while the same ship
## sat on spare system and utility mounts the kit could not reach. Probate,
## Cygnet, Verity and Calyx lights opened two cards down on Korvan's for no
## reason anyone chose.
##
## The floor is a function of HAND SIZE, because that is what makes it matter:
## a deck no bigger than the hand is not a deck, you simply hold all of it, and
## light frames draw the most. So the ships that need the biggest decks are
## exactly the ones this used to shortchange.
##
## Distinct parts first, in two passes. Yard stock has three of each slot, so a
## frame with spare mounts gets a Slug Thrower and a Ranging Scope rather than a
## second and third Hull Plating — and a starting deck of nine identical cards
## is not a deck either. The second pass allows duplicates only because a frame
## can have more mounts than the yard has distinct parts for that slot.
func _top_up_deck() -> void:
	var target := hand_size() + 4
	for allow_dupes in [false, true]:
		while deck_size() < target:
			var fitted := false
			for id in DB.GENERIC_STOCK:
				var m := DB.modules[id] as ModuleData
				if slots_used(m.slot) >= slots_for(m.slot):
					continue
				if not can_power(m):
					continue
				if not allow_dupes and _has_module(id):
					continue
				var copy := m.duplicate(true) as ModuleData
				copy.mount = free_mount(copy.slot)
				installed.append(copy)
				fitted = true
				break
			# Out of mounts, or out of distinct parts on this pass.
			if not fitted:
				break

func _has_module(id: StringName) -> bool:
	for m in installed:
		if m.id == id:
			return true
	return false

func log_line(text: String, kind: StringName = &"sys") -> void:
	Sig.log_line.emit(text, kind)

# ------------------------------------------------------------------ derived stats

## THE GAUGES. Chassis, then everything bolted to it.
##
## Each of these used to return the hull's field and stop. That made four of the
## six attributes pure chassis properties by accident rather than by ruling —
## Sensors and Stealth summed `installed` because they had no gauge to derive
## from, and the other four silently did not. Armour plating added no armour.
##
## Summing here rather than in attr_hull() and attr_thermal() is the point: an
## attribute is a READING of a gauge, so a plate that only moved the attribute
## would be a plate that shows up on the ship tab and not in the fight. Combat
## calls max_hp() and heat_cap(); it never calls attr_*().
##
## `bare` reports the CHASSIS ALONE — no fitted modules. Only the attribute
## block asks for it, and it asks so the display can separate what the ship is
## from what you bolted to it. It is a parameter rather than six more functions
## because the two readings must never be able to disagree about the formula.
func max_hp(bare: bool = false) -> int:
	var n := hull.max_hull
	if not bare:
		for m in installed:
			n += m.max_hull + m.affix_int(&"max_hull")
	return maxi(1, n)

func heat_cap(bare: bool = false) -> int:
	var n := hull.heat_cap + heat_cap_bonus
	if hull.has_perk(&"heat_sink"):
		n += 2
	if not bare:
		for m in installed:
			n += m.heat_cap + m.affix_int(&"heat_cap")
	return maxi(1, n)

func dissipation(bare: bool = false) -> int:
	var d := hull.dissipation
	if hull.has_perk(&"baffled_vents"):
		d += 1
	if not bare:
		for m in installed:
			d += m.dissipation + m.affix_int(&"dissipation")
	return maxi(0, d)

## Capped at 0.6. Dodge is the enemy's miss chance, so an uncapped sum is a ship
## nothing can hit — and the ruling that only enemies miss means the player never
## sees the roll that would tell them the fight had stopped being a fight.
func dodge(bare: bool = false) -> float:
	var v := hull.dodge
	if not bare:
		for m in installed:
			v += m.dodge + m.affix_raw(&"dodge")
	return clampf(v, 0.0, 0.6)

func initiative(bare: bool = false) -> int:
	var v := hull.initiative
	if not bare:
		for m in installed:
			v += m.initiative + m.affix_int(&"initiative")
	return v

## Floored well above zero: this multiplies the price of every jump, and a ship
## that had driven it to 0 would cross the galaxy free.
func fuel_factor(bare: bool = false) -> float:
	var v := hull.fuel_factor
	if not bare:
		for m in installed:
			v += m.fuel_factor
	# AFTER the modules, because it is a discount on what the ship actually
	# burns rather than on the hull it started as. Multiplicative and small:
	# this number prices every jump in the game, and the floor below it is
	# there because a ship that drove it to zero would cross the galaxy free.
	if hull.has_perk(&"deep_tanks"):
		v *= 0.9
	return maxf(0.3, v)

## HEAT SHEDS BETWEEN SYSTEMS, NOT ONLY BETWEEN TURNS.
##
## `dissipation()` was read in exactly one gameplay site — Combat.end_turn() —
## so heat carried out of a fight stayed on the hull forever. Ten jumps later
## the gauge still read what it read when the shooting stopped, and the only
## ways down were a purge card, one event, or the next fight. That made the
## number a fossil between fights, and it made "cool off before you go in" a
## thing a player could want and had no way to do.
##
## HALF A TURN'S WORTH PER JUMP, FLOOR OF ONE. Measured, not chosen: at a full
## turn's worth the average signature on arrival fell from 0.32 to 0.05 over a
## thousand runs, which did not make heat manageable between systems, it deleted
## it. A jump you were making anyway must not be a free vent.
##
## At half rate a medium frame carries a hard fight about six systems, a light
## frame three, and a Solari heavy most of the way to the next station — the
## same trade those hulls already make in combat, now visible on the map. The
## floor of one exists so that the worst dissipation in the game still cools
## eventually rather than fossilising at capacity for the rest of the run.
func cool_in_transit() -> void:
	# HALF RATE, and full rate was tried on 2026-08-25 and put back. The
	# argument for trying it was good and the measurement refused it.
	#
	# THE ARGUMENT: an older comment here recorded full rate deleting the map
	# mechanic -- average arrival signature 0.32 down to 0.05 -- but that test
	# ran with in-combat dissipation still active, so fights ended cool and
	# full-rate transit was compounding an already-cool start. With the
	# end-of-turn shed now deleted, fights end near capacity, so full rate
	# should have been a counterweight rather than a second pull the same way.
	#
	# THE MEASUREMENT, 500 runs each, combat change held constant:
	#
	#     transit      arrival sig   arrived hot   ambush/run   win
	#     full rate       0.04           5.5%         0.21       30%
	#     half rate       0.07           9.4%         0.24       29%
	#
	# Half rate is better on every axis the change was FOR, and the win rate
	# difference is inside the noise of 500 runs. So the ruling is reverted.
	#
	# THE REAL FINDING IS THAT THIS RATE IS NOT THE LEVER. Fights now end at
	# 0.31 signature -- more than double what they did -- and arrival is still
	# 0.07 against a SIGNATURE_FLOOR of 0.25. Cooling is charged PER JUMP and
	# there are roughly four jumps per fight, so whatever a fight builds is
	# spent long before the next one. Halving the rate cannot fix that and
	# neither can doubling it; the dials that would are the per-jump floor
	# below, the number of jumps between fights, or the floor itself.
	#
	# The floor of 1 stays regardless: it is what stops the worst dissipation
	# in the game fossilising at capacity.
	heat = maxi(0, heat - maxi(1, int(dissipation() / 2.0)))

## How loud you are: 0.0 stone cold, 1.0 at capacity, higher while overheating.
##
## Everything on the map layer that cares about heat asks this rather than the
## raw number, because raw heat is not comparable across hulls — 11 heat is
## nearly cooked on a light frame and idling on a heavy one.
func signature() -> float:
	return float(heat) / float(maxi(1, heat_cap()))

## Below this fraction of capacity nothing finds you. The main doc's ruling is
## that cold light ships slip past, and a ceiling of "almost never" is not the
## same promise as "not at all" — a player who has decided to run cold has
## bought silence and should get it, not a low roll that occasionally ignores
## the decision.
const SIGNATURE_FLOOR := 0.25
## Odds at capacity, on unclaimed ground, in a ship with no stealth at all.
const AMBUSH_AT_CAP := 0.30

## Whether something followed the heat in, and how likely that was.
##
## Three terms, and the order matters. Signature is the gate: run cold and the
## rest never applies. Danger scales it, because deep systems have more in them
## to notice you. Stealth divides it last, so the hull and the modules you fitted
## are the answer to a problem your own throttle created.
func ambush_chance(n: MapGen.MapNode) -> float:
	var sig := signature()
	if sig <= SIGNATURE_FLOOR:
		return 0.0
	var p := AMBUSH_AT_CAP * (sig - SIGNATURE_FLOOR) / (1.0 - SIGNATURE_FLOOR)
	p *= 1.0 + float(n.danger - 1) * 0.08
	# CLAMPED HERE, not at the gauge. Attributes go over ten now, and a stealth
	# of 17 would drive this ratio past 1 and the probability below zero — a ship
	# that is ambushed a negative amount of the time. Sixty per cent off is the
	# most stealth can buy, however much of it you have.
	p *= 1.0 - minf(1.0, float(attr_stealth()) / float(ATTR_MAX)) * AMBUSH_RELIEF
	return clampf(p, 0.0, 0.6)

## WHAT A REACTOR LEVEL IS. Three cells of hardware, and a step of energy
## every second level.
##
##     REACTOR   4    5    6    7    8    9   10   11   12   13   14
##     cells    12   15   18   21   24   27   30   33   36   39   42
##     energy    3    3    4    4    5    5    6    6    7    7    8
##
## THE LEVEL IS THE STAT AND THE OTHER TWO ARE READ OFF IT, which is the
## opposite of how this started. It was a SCORE: you had energy and cells and
## the bar weighed them into a number. That could not be read backwards —
## REACTOR 10 meant "at least this good", not any particular ship — and on the
## one gauge whose raw unit is printed directly under it, being unreadable
## backwards is the whole complaint.
##
## IT WAS AN ELEVEN-ROW TABLE AND THE TABLE WAS THE CEILING. Attributes go over
## ten now (Pillar 5), and every other one of them does — but a lookup clamps at
## its own length, so REACTOR alone stopped at 10 while the rule said otherwise.
## Two lines of arithmetic have no length. The table is kept above as the
## LADDER, which is what anybody actually wanted to read off it.
##
## The arithmetic and the old table disagree at levels 1 and 3, by one point of
## energy. Nothing in the game is ever there: the worst frame is 4 and nothing
## lowers a reactor.
const CELLS_PER_LEVEL := 3


## THE REACTOR LEVEL ITSELF: the hull grade, plus every part that raises it.
##
## Floored at zero and NOT capped. attr_reactor is this number and nothing
## else — no weighting, no formula, no offset — so a ship carrying four
## couplings reads 16 and means it.
func reactor_level(bare: bool = false) -> int:
	var n := hull.reactor
	if not bare:
		for m in installed:
			n += m.reactor + m.affix_int(&"reactor")
	return maxi(0, n)


## Energy a turn. A step every second level from 3 at REACTOR 4, then the two
## things that grant energy DIRECTLY rather than by growing the reactor — a
## perk and a set bonus, which stay as they were because a bonus that sometimes
## did nothing (a level landing between steps) is a bonus nobody can price.
func reactor() -> int:
	var e := maxi(1, 3 + floori(float(reactor_level() - 4) / 2.0))
	if hull.has_perk(&"overspec_reactor"):
		e += 1
	if has_set(&"verity", 5):
		e += 1
	return e


func power_cap() -> int:
	return reactor_level() * CELLS_PER_LEVEL

## What is bolted on right now, in cells. The SAME number the hold counts a
## part in, deliberately: a player already knows a 2x2 bay is four, and a
## second unit for the same quantity is how two halves of a game drift apart.
func power_draw() -> int:
	var d := 0
	for m in installed:
		d += m.cells()
	return d

## Can this part be RUN, ignoring whether there is a mount for it.
##
## Two questions, never one. `slots_used < slots_for` asks whether the frame
## has somewhere to bolt it; this asks whether the reactor can carry it. A
## heavy has four weapon mounts and cannot power four four-cell cannons, and
## the whole interest of the system is in the gap between those two answers.
##
## `replacing` is the part coming off to make room, whose draw is freed first
## — without it a straight swap of like for like would be refused at cap.
func can_power(m: ModuleData, replacing: ModuleData = null) -> bool:
	if m == null:
		return false
	var draw := power_draw() + m.cells()
	# The cap WITH this part on, which matters because a coupling raises the
	# level it is being measured against. Read off the table rather than added,
	# since a level is not a number of cells until the table says so.
	var level := reactor_level() + m.reactor + m.affix_int(&"reactor")
	if replacing != null:
		draw -= replacing.cells()
		level -= replacing.reactor
	var cap := maxi(0, level) * CELLS_PER_LEVEL
	return draw <= cap

## Development override, set by `-- fight N`. Zero means "use the real value".
## Lives here rather than in Main so Combat's redraw each turn honours it too —
## a hand that is ten on turn one and five on turn two would test the layout
## exactly once.
var hand_size_override: int = 0

func hand_size() -> int:
	if hand_size_override > 0:
		return hand_size_override
	var h := hull.hand_size
	if hull.has_perk(&"quick_hands"):
		h += 1
	if has_set(&"redline", 3):
		h += 1
	return h

func slots_for(s: ModuleData.Slot) -> int:
	# NO PERK ADDS A MOUNT ANY MORE. `spare_bay` did, and a mount is a place on
	# a hull that somebody rigged by hand -- the extra one had no anchor and
	# landed wherever the fallback line put it.
	return hull.slots_for(s)

func slots_used(s: ModuleData.Slot) -> int:
	var n := 0
	for m in installed:
		if m.slot == s:
			n += 1
	return n

## Modules from this manufacturer, PLUS the hull if it built one.
##
## The hull counting is what makes choosing a chassis a build decision instead
## of a stat decision: a Korvan hull puts you one module from Standard Issue,
## and swapping to a found Redline frame costs you that piece. It is also the
## price of the reversal — hull swaps are no longer identity-neutral, which the
## old "hulls have no manufacturer" ruling existed to guarantee.
func manufacturer_count(id: StringName) -> int:
	var n := 0
	if hull != null and hull.manufacturer == id and id != &"":
		n += 1
	for m in installed:
		if m.manufacturer == id:
			n += 1
	return n

## Set bonuses are the class system: identity is assembled, not chosen.
func has_set(id: StringName, threshold: int) -> bool:
	return manufacturer_count(id) >= threshold

# ------------------------------------------------------------------- attributes
#
# The six numbers events check against, per attributes-and-checks.md.
#
# THE RULE, from §0: every attribute is a number the game ALREADY TRACKS. These
# are functions, never fields. Nothing writes an attribute; there is no second
# copy of your ship's condition to drift out of sync with the first, and no
# "recalculate attributes" call anyone can forget after a refit.
#
# The consequence worth stating out loud is that checks read the CURRENT value.
# A holed ship really does fail Hull checks it would have passed at full — the
# attribute is the damage, not a rating the damage is compared against.
#
# All six are 0-6. The constants below are FIRST VALUES, tuned against the three
# unbranded frames and not yet against the seven manufacturer hulls or against
# any real event table. Expect to move them.

## Ten, not six. Six cells could not separate twenty-one chassis: half the
## Thermal column landed on the same number and the difference between a Korvan
## medium and a Solari medium — which is most of what those two manufacturers ARE —
## rounded away. Every constant below was rescaled with it, not multiplied
## through: the point of the wider scale is that the ships spread out in it.
## HOW MANY CELLS THE BAR DRAWS. NOT a ceiling on the value.
##
## Attributes go over ten and are meant to. Pillar 5: the ceiling is meant to
## break, and a gauge that clamps is a gauge that hides the one moment the
## whole loot loop exists to produce. A stealth build that reads 14 should say
## 14 — the bar runs out of cells, and the bar running out IS the readout.
##
## THE FLOOR STAYS. Zero is still zero; nothing reads negative. See attr_sensors
## for why that one is enforced and where.
##
## WHAT DOES CAP IS EVERY CONSUMER, at its own call site rather than here. The
## ambush roll divides by this and would take a probability negative at 17
## stealth; it clamps its own ratio now. That is the correct place for it: the
## gauge reports what you built, and each rule decides how much of it it can
## use.
const ATTR_MAX := 10

## The most stealth can take off an ambush, at ATTR_MAX. Named because the
## attribute tooltip quotes it: a percentage typed into a hint and a constant
## used by the maths drift apart the first time either is touched.
const AMBUSH_RELIEF := 0.6

## Hull is measured against a fixed reference, not against your own maximum.
##
## Dividing by max_hp was the obvious version and it is wrong: it reads 6 for a
## full Skiff and 6 for a full Ore Barge, so the attribute would say the two
## ships are equally sturdy while one has less than half the other's plating.
## A fixed reference makes frame size and damage both count, which is the whole
## point of a Hull check.
##
## 70 rather than 60 because 60 put the Ore Barge at 6 on the first turn of the
## run, and an attribute already at its ceiling cannot be improved by the tier
## upgrades and found hulls that are supposed to improve it.
const HULL_REF := 70.0

## `bare` everywhere below means "read the chassis with nothing fitted". Hull is
## the awkward one: it reads CURRENT hp, so the bare reading caps at what the
## bare frame could have held — hull you are carrying above that is the plating's
## doing, and it should show as the plating's.
func attr_hull(bare: bool = false) -> int:
	var v := mini(hp, max_hp(true)) if bare else hp
	return maxi(0, int(round(ATTR_MAX * float(v) / HULL_REF)))

## Thrust reads off fuel burn: a bigger engine moves more ship and drinks more
## doing it, so the factor that prices your jumps is already the number.
func attr_thrust(bare: bool = false) -> int:
	var n := hull.thrust
	if not bare:
		for m in installed:
			n += m.thrust + m.affix_int(&"thrust")
	return maxi(0, n)

## Dodge is the bulk of it; initiative tilts it. The +1 floor is there because
## without it every chassis with dodge under 0.05 and negative initiative read
## exactly 0 — the Ironside Cutter, a medium warship, scored the same
## Maneuver as an ore barge, which is not a distinction worth erasing. A barge
## can still reach 0 by being an actual barge.
func attr_maneuver(bare: bool = false) -> int:
	# 0.5 AND NOT 0.9 on initiative, so that HALF a pip is exactly one whole
	# point of it. A part that raises MANEUVER raises both terms, and both terms
	# have to be able to carry half a pip in their own unit — initiative is an
	# int, so at 0.9 it could not. Only one reading moves: a heavy goes from 0 to
	# 1, which the floor below was arguably always meant to give it.
	return maxi(0, int(round(dodge(bare) * 23.0 + initiative(bare) * 0.5 + 1.5)))

## VENT, not "shedding". The card face says "Vent 3" and the field is called
## dissipation; a third word for the same quantity in the comments is how two
## halves of a game stop being about the same thing.
##
## Thermal is capacity AND venting, per §1.4, because an event that asks "can
## you sit in this heat" is asking about both and would otherwise need two
## attributes to answer.
##
## Capacity carries most of the weight, and this took a measurement to get
## right. The first version was `cap/6 + diss/2.5`, which read 3 or 4 for every
## chassis in the game — the Emberwright caps at 20 and vents 2, the Brood
## Tender caps at 12 and vents 4, and the two terms cancelled so cleanly that
## the heat manufacturer and the drone manufacturer scored identically. Weighting
## capacity harder and subtracting a floor spreads it 2-6, with Solari at the
## top where the whole manufacturer says it should be.
##
## They are not interchangeable in fiction and must not be in the formula:
## capacity is how much you can take, dissipation is how fast you get rid of it,
## and only the first decides whether you survive sitting in a corona.
##
## Divisors widened once already. At 2.4/2.0 the attribute saturated: five of
## the seven heavy frames pinned at 6, so a Probate ore barge and a Solari
## Furnace Baron read identically on the axis Solari exists to own. A ceiling
## that everything large reaches is not a measurement. Now exactly one chassis
## in the game reads 6, and it is the one built by the heat manufacturer.
const THERMAL_FLOOR := 8.0

## THE GRADE, AS A GAUGE. Output and capacity are one attribute because they
## are one piece of hardware — the same argument THERMAL makes for heat
## capacity and dissipation, and it is wrong here for the same reason it would
## be wrong there to split them: a player asking "is this a good reactor" is
## asking one question.
##
## They are not interchangeable and the weights say so. Output is scarce and
## enormous — three points of it across the whole ladder, and each one is a
## card a turn — so it is worth 1.6 a point. Capacity runs 13 to 22 and buys
## room rather than tempo, so it is worth a quarter of a point a cell.
##
## DIVISORS PICKED SO THE TOP DOES NOT PIN, which is the mistake THERMAL made
## once and documents above: an attribute everything good saturates is not a
## measurement. A bare S frame reads 7 of 10. Reaching 10 takes the S grade,
## the overspec perk and two couplings — a build that has actually spent
## itself on power, which is what a full gauge should mean.
##
##     C 2    B 3    A 5    S 7    S, perked and coupled 10
## HOW MANY CELLS ONE PIP OF REACTOR IS WORTH.
##
## Named rather than buried in the formula, because it is the number a coupling
## is priced in: a part that raises REACTOR by 2 grants exactly two of these,
## and Database derives its grant from here rather than authoring a 6 that
## means nothing on its own.
##
## Three, so the gauge and the cells stay legible together. REACTOR is the one
## attribute whose raw unit a player COUNTS — thirteen cells of hardware is a
## number on the ship screen, where nobody counts hull points — so a pip has to
## be a quantity of them small enough to divide the ladder tidily and large
## enough to be worth crossing.
const CELLS_PER_PIP := 3.0

## THE ATTRIBUTE IS THE STAT. No weighting, no offset, no formula — the bar
## reads the reactor level, and the level is what decides the cells and the
## energy. REACTOR 10 is thirty cells and six energy, on every hull in the
## game, and a player who reads the bar and multiplies is right.
##
## It is the only attribute that works this way, and it earned it: it is the
## only one whose raw unit is printed on the same screen. HULL scores your
## plating and THERMAL weighs capacity against vent because nobody counts
## either of those; the ship screen counts cells under the mounts.
func attr_reactor(bare: bool = false) -> int:
	return maxi(0, reactor_level(bare))


func attr_thermal(bare: bool = false) -> int:
	# 2.0 AND 1.0, NOT 2.1 AND 1.5, since the attribute ladder. Both fields are
	# ints, so a divisor that is not a whole number cannot carry a whole pip: a
	# rare vent asked for one pip, got 1.5 rounded to 2, and read back as two.
	# `-- attrtest` caught it on the first run.
	#
	# The readings barely move — a medium reads 3 either way — because the change
	# is a rounding convenience and not a retune. What it buys is that one point
	# of venting is exactly one pip and two of capacity is exactly one pip, so
	# the ladder can be exact instead of nearly right.
	# BOTH TERMS AT 2.0, so one point of capacity and one point of vent are each
	# half a pip and a part that raises THERMAL raises both by one. The only
	# reading that moves is a light, 2 to 1, which is the correct direction for
	# the frame with the smallest tank and the least to shed.
	var v := (heat_cap(bare) - THERMAL_FLOOR) / 2.0 + dissipation(bare) / 2.0
	return maxi(0, int(round(v)))

## Sensors and Stealth are the two with no other gauge in the game, so unlike
## the four above they are summed rather than derived. Hull baseline plus fitted
## modules — the same shape as the others, where the chassis sets the platform
## and what you bolt on adjusts it.
## Sensors and Stealth are authored in small whole numbers — a hull carries 0 to
## 2, a module 1 or 2 — because that is a legible thing to write in a data table.
## The scale they are DISPLAYED on is a different question, so the conversion
## lives here rather than in the catalog. At 1.7 the best sensor ship in the game
## reads 7 and the stealthiest reads 9, which leaves both room to improve.
## ONE, not 1.7, since the attribute ladder. A module now says how many PIPS
## it is worth and the grade decides the number — so a scale that is not 1 makes
## the two sensor axes the only ones where a rare part cannot deliver exactly
## one pip: 1/1.7 is 0.59, the field is an int, and rare and epic both round to
## a raw 1. Two grades reading identically is the failure THERMAL documents.
##
## What it costs is headroom on the hull alone: a chassis carries 0 to 2 of
## these and used to read up to 3.4 on its own. It buys something better —
## Sensors and Stealth become axes you BUILD rather than ones the frame hands
## you, because a legendary dish is now worth more than any hull ever was.
const SENSE_SCALE := 1.0

## AN ATTRIBUTE STOPS AT ZERO. The clamp on the return is what enforces it, and
## these two are the only gauges that could ever have needed it — they are
## summed straight off the hull and its modules, where every other attribute is
## derived from a quantity that was floored on the way here: heat capacity at 1,
## dissipation and dodge at 0.
##
## A part that PRICES a gauge (see Database.PASSIVE_COST) can therefore take a
## real pip off a build that has one, and takes nothing off a build that does
## not. Both halves are checked by `-- attrtest`, which measures the price
## against a supplier and then against an empty gauge.
func attr_sensors(bare: bool = false) -> int:
	var n := hull.sensors
	if not bare:
		for m in installed:
			n += m.sensors + m.affix_int(&"sensors")
	return maxi(0, int(round(n * SENSE_SCALE)))

## Heat comes off the top of Stealth rather than out of the modules that grant
## it, because it is the one thing on the ship you cannot bolt a cover over. A
## cold Redline is the quietest thing in the galaxy; the same hull at capacity is
## a lit match, and no amount of baffling changes that. Four of ten at capacity —
## enough to lose a check you would pass cold, not enough to erase a build.
##
## This is also what makes ambush_chance() a decision rather than a tax: the
## stealth term there reads this, so running hot is punished twice through one
## number, and fitting for stealth answers both.
const HEAT_STEALTH_COST := 4.0

func attr_stealth(bare: bool = false) -> int:
	var n := hull.stealth
	if not bare:
		for m in installed:
			n += m.stealth + m.affix_int(&"stealth")
	# The heat penalty applies to BOTH readings. `bare` means "the chassis with
	# nothing fitted", and heat is not something you fitted — so subtracting it
	# only from the full reading would paint the loss as a module's fault in the
	# attribute block, which draws chassis and modules in different colours.
	var v := float(n) * SENSE_SCALE - signature() * HEAT_STEALTH_COST
	return maxi(0, int(round(v)))

## Every attribute, in display order, as {key, label, short, value, base, text}.
##
## `base` is the same attribute read off the bare chassis, so the display can
## paint what the ship IS separately from what you bolted to it. Both are
## computed here rather than differenced by the caller, because the difference
## has to be taken AFTER the rounding and the clamp — a module worth 0.4 of a
## cell moves neither number, and a caller subtracting raw values would paint a
## bonus cell that the attribute does not actually have.
## One list so the ship tab, the chassis select and any future check UI cannot
## disagree about the order or the names.
## WHAT ONE PIP COSTS, in the raw units the attribute formulas read.
##
## ONE ENTRY PER GAUGE, and a gauge with two terms moves BOTH. A part that
## raises MANEUVER raises dodge and initiative; a part that raises THERMAL
## raises how much heat you hold and how fast you lose it. That is the whole
## simplification: a part says +1 MANEUVER, not "+1 of the initiative half of
## maneuver", and there is nothing to explain in brackets afterwards.
##
## Each term carries HALF a pip, and the divisors above were set to whole
## numbers so that half a pip is one whole point in an int field. That is the
## constraint that decides those divisors, and it is why they are here rather
## than tuned to taste: dodge is a float and can carry a fraction, initiative
## and dissipation cannot.
##
## INVERTED OUT OF THE FUNCTIONS ABOVE, not measured against them. Change one
## of those formulas and this has to change with it, which is exactly what
## `-- attrtest` is for: it bolts every part onto a reference frame and checks
## the gauge actually moved by the number the grade promised.
const PER_PIP := {
	&"hull": {&"max_hull": 7.0},                       ## HULL_REF / ATTR_MAX
	&"thermal": {&"heat_cap": 1.0, &"dissipation": 1.0},
	# DODGE ALONE, and initiative is deliberately not here any more. The comment
	# above still holds for gauges with two live terms -- but initiative is not
	# one: it is summed, it feeds attr_maneuver, and NOTHING else in the game
	# reads it. Combat rolls randf() < Run.dodge() for the enemy to miss and never
	# asks who goes first.
	#
	# So half of every maneuver pip was buying nothing at all, and a part or an
	# affix advertising +1 MANEUVER delivered about 2% of enemy attacks missing
	# where the gauge implied twice that. 1/23 rather than 1/46 makes the whole
	# pip land on the half that works.
	#
	# Hull initiative is untouched: attr_maneuver still reads it, so a light frame
	# still gauges higher than a heavy one. That is the gauge DESCRIBING a chassis,
	# which it does honestly. What it may no longer do is sell a bonus.
	&"maneuver": {&"dodge": 1.0 / 23.0},
	&"sensors": {&"sensors": 1.0},
	&"stealth": {&"stealth": 1.0},
	# THE TWO THAT WERE MISSING. Every other gauge could be graded and these two
	# could not, so a part meant to be worth a pip of REACTOR or THRUST had no
	# unit to be worth it in. Both are one-for-one: a reactor level IS a pip
	# (attr_reactor returns the level), and thrust is now its own field for the
	# same reason -- see attr_thrust.
	#
	# A reactor pip is the dearest thing on this table: three cells of capacity
	# AND half a point of energy, since energy steps every second level.
	&"reactor": {&"reactor": 1.0},
	&"thrust": {&"thrust": 1.0},
}

func attributes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{key = &"hull", label = "HULL", short = "HUL",
			value = attr_hull(), base = attr_hull(true),
			text = "Ramming, boarding, holding together under structural stress.",
			# READS CURRENT HULL, not maximum, which is worth saying out loud:
			# it is the one gauge that falls as you take damage, so a holed ship
			# really does fail a check it would have passed intact.
			effect = "A pip is 7 hull. This gauge reads CURRENT hull, so damage lowers it until you repair."},
		{key = &"reactor", label = "REACTOR", short = "RCT",
			value = attr_reactor(), base = attr_reactor(true),
			text = "Energy to spend in a fight, and hardware the ship can run.",
			# The only gauge no event check reads. It pays in combat instead.
			effect = "A pip is %d more cells of hardware. Energy rises every second pip." % CELLS_PER_LEVEL},
		{key = &"thrust", label = "THRUST", short = "THR",
			value = attr_thrust(), base = attr_thrust(true),
			text = "Outrunning, breaking orbit, pulling free of a gravity well.",
			# The jump range is a FIXED distance now, so this is a plain
			# percentage of a known number rather than of a local accident.
			effect = "A pip is %d%% further travel on the starchart, to a maximum of %d%%, and costs no extra fuel."
				% [int(round(THRUST_REACH * 100.0)),
					int(round((THRUST_REACH_MAX - 1.0) * 100.0))]},
		{key = &"maneuver", label = "MANEUVERABILITY", short = "MNV",
			value = attr_maneuver(), base = attr_maneuver(true),
			text = "Threading debris, evading a lock, choosing how a fight opens.",
			# HALF A PIP IS DODGE and half is initiative, and only the dodge half
			# does anything: Combat rolls `randf() < Run.dodge()` for the enemy
			# to miss, and NOTHING reads initiative. So the honest number is the
			# dodge half alone -- 1/46 of a pip, near enough 2%.
			effect = "A pip is about 4% of enemy attacks missing outright."},
		{key = &"thermal", label = "THERMAL", short = "THM",
			value = attr_thermal(), base = attr_thermal(true),
			text = "Sitting in heat: coronas, reactors, anything that cooks you.",
			effect = "A pip is 1 more heat capacity, and 1 more heat off every vent card you play."},
		{key = &"sensors", label = "SENSORS", short = "SEN",
			value = attr_sensors(), base = attr_sensors(true),
			text = "Reading a wreck, finding the lane, seeing it before it sees you.",
			# SAYS WHAT IT DOES NOW. It used to read "further out than you can
			# fly to", which described sight as a margin over the drive. Sight
			# is live and it is the gate -- you may only jump to what you can
			# see -- so the pip has to be priced against the starchart itself,
			# not against thrust.
			effect = "A pip is %d%% further sight on the starchart. You can only jump to systems you can see."
				% int(round(SENSE_REACH * 100.0))},
		{key = &"stealth", label = "STEALTH", short = "STL",
			value = attr_stealth(), base = attr_stealth(true),
			text = "Going dark, slipping a patrol, arriving unannounced.",
			effect = "A pip is %d%% fewer ambushes, to a maximum of %d%% at %d."
				% [int(round(AMBUSH_RELIEF * 100.0)) / ATTR_MAX,
					int(round(AMBUSH_RELIEF * 100.0)), ATTR_MAX]},
	])
	return out

func contraband_count() -> int:
	var n := 0
	for m in installed:
		if m.contraband:
			n += 1
	for m in cargo:
		if m.contraband:
			n += 1
	return n

## What one hull point costs to fix HERE. A float, and local: work is dear on the
## frontier and cheap in a capital, which is most of what makes a developed
## system worth the detour. Market owns the number; this is the reading of it
## that the HUD and the sim want.
func repair_cost_per_hull() -> float:
	return Market.repair_rate(here())

## What a part melts down to. The floor price under every module in the game —
## available anywhere, with no station and no route — and, by construction, below
## what any station in the galaxy would charge for the same part. See the
## invariant at the top of Market.gd.
func scrap_value_of(m: ModuleData) -> int:
	return Market.melt(m)

# --------------------------------------------------------------------- materials

func material(id: StringName) -> int:
	return int(materials.get(id, 0))

func add_material(id: StringName, n: int) -> void:
	if n == 0:
		return
	materials[id] = maxi(0, material(id) + n)
	Sig.resources_changed.emit()

func spend_material(id: StringName, n: int) -> bool:
	if material(id) < n:
		return false
	materials[id] = material(id) - n
	Sig.resources_changed.emit()
	return true

## Everything you are carrying, in table order, as {id, name, count}. One list so
## the HUD, the station and the fabricator cannot disagree about what a material
## is called or what order they come in.
func material_stock() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in DB.MATERIALS:
		var n := material(d.id)
		if n > 0:
			out.append({id = d.id, name = str(d.name), count = n})
	return out

# --------------------------------------------------------------------- mutations

## Fly a pulsar's beam: the densest fuel in the galaxy, paid for in hull.
##
## The arithmetic lives here rather than in Router because the simulator has to
## be able to run it. Anything that only exists on a screen is invisible to the
## balance model, and a node type that hands out fuel and takes hull is exactly
## the kind of thing the model needs to see.
func harvest_pulsar() -> void:
	var n := node_at()
	if n.cleared:
		return
	take_whole(n)
	# Scales with danger, so a deep pulsar is both a better haul and a worse
	# idea — which is the shape of this whole map.
	var gain_fuel := 14 + n.danger * 2
	var gain_exotic := 1 + int(n.danger / 4)
	var burn := 6 + int(n.danger * 1.6)
	var gain_heat := 3 + int(n.danger / 3)

	fuel += gain_fuel
	exotic += gain_exotic
	heat += gain_heat
	log_line("Beam sweep. The tank fills in eleven seconds.", &"good")
	log_line("+%d fuel, +%d exotic." % [gain_fuel, gain_exotic], &"good")
	log_line("Hard radiation through the hull. +%d heat." % gain_heat, &"them")
	Sig.resources_changed.emit()
	# Last: it can end the run, and everything above has to have happened first.
	# Dying with the fuel aboard is the point of the trade.
	take_hull_damage(burn, "Cooked by a neutron star. The hull held; nothing inside it did.")

func take_hull_damage(amount: int, reason: String) -> void:
	hp -= amount
	Sig.resources_changed.emit()
	if hp <= 0:
		hp = 0
		die(reason)

func heal(amount: int) -> int:
	var gained := mini(amount, max_hp() - hp)
	hp += gained
	if gained > 0:
		Sig.resources_changed.emit()
	return gained

func add_credits(n: int) -> void:
	credits = maxi(0, credits + n)
	Sig.resources_changed.emit()

## A flyable hull, cut out of a wreck or claimed off an event.
##
## THE THIRD THING THE RAIL SHOWS, and the only one that never went through
## `stow()` — so it never bumped `hauls`, so a dismissed rail stayed dismissed
## over it. Claim a hull after stowing and the transfer was never offered until
## some unrelated haul happened to arrive.
##
## Clears the dismissal outright rather than incrementing `hauls`: a hull is not
## a haul, and the honest statement is "there is something new here", which is
## what an undismissed rail means.
func find_hull(h: HullData) -> void:
	found_hull = h
	salvage_hushed_hauls = -1
	salvage_hushed_bag = -1
	Sig.ship_changed.emit()


## Permanent coolant, bought at a station. Emits, and that is the point.
##
## THE MUTATION OWNS THE SIGNAL. The station used to raise `heat_cap_bonus` by
## hand and rely on the `add_credits()` call above it to redraw — which fires
## BEFORE the cap changes, so every listener repainted the old number and the
## gauge sat at 0/14 while the run was carrying 16. The upgrade worked; nothing
## ever said so, which is indistinguishable from it not working.
##
## `ship_changed` rather than `resources_changed`: a heat cap is a property of
## the ship, and `RunState._clamp_hp` and the gauges are already listening to it
## for exactly this class of change.
##
## ONE SIGNAL, NOT TWO. Every listener that cares about a heat cap is already on
## `ship_changed` — the HUD and the station screen are both on both — so emitting
## the pair meant two full rebuilds per change. Buying coolant fired three: one
## from `add_credits` and two from here.
func add_heat_cap(n: int) -> void:
	heat_cap_bonus += n
	Sig.ship_changed.emit()

func die(reason: String) -> void:
	dead = true
	death_reason = reason
	Sig.run_ended.emit(false, reason)

func win() -> void:
	won = true
	Sig.run_ended.emit(true, "You cross into the light.")

## TWO BUDGETS, AND A PART HAS TO SATISFY BOTH.
##
## A mount of the right kind, and reactor capacity to run it. They fail
## differently and so they clear differently: no mount means the worst part in
## THAT SLOT comes off, because a weapon cannot free a system mount; no
## capacity means the worst part ANYWHERE comes off, because every cell on the
## ship draws from the one reactor.
##
## Worst by scrap value in both cases, which is the only ordering the game has
## that means roughly "how good is this" — and it is the ordering the mount
## rule already used, so a player who has learned one has learned the other.
func install_module(m: ModuleData) -> void:
	if slots_used(m.slot) >= slots_for(m.slot):
		var worst: ModuleData = null
		for x in installed:
			if x.slot == m.slot and (worst == null or x.scrap_value < worst.scrap_value):
				worst = x
		if worst != null:
			installed.erase(worst)
			worst.mount = -1
			# It came OFF the ship, so the hold has just gained the cells `m`
			# is about to vacate. place_in_hold cannot fail here in practice,
			# but a part that finds no cell is dropped rather than duplicated.
			if not place_in_hold(worst):
				log_line("No room for %s. It was left behind." % worst.name, &"them")
			log_line("Removed %s to make room." % worst.name, &"sys")
	# AND THEN THE REACTOR. Cheapest first and only as many as it takes — a
	# 4-cell lance should cost you one 4-cell part, not clear the ship.
	# Guarded rather than `while`: a part bigger than the whole reactor would
	# otherwise strip every mount and still not fit.
	var guard := 0
	while not can_power(m) and guard < 16:
		guard += 1
		var dim: ModuleData = null
		for x in installed:
			if dim == null or x.scrap_value < dim.scrap_value:
				dim = x
		if dim == null:
			break
		installed.erase(dim)
		dim.mount = -1
		if not place_in_hold(dim):
			log_line("No room for %s. It was left behind." % dim.name, &"them")
		log_line("Shut down %s — the reactor cannot carry both." % dim.name, &"sys")
	take_from_hold(m)
	m.mount = free_mount(m.slot)
	installed.append(m)
	log_line("Installed %s." % m.name, &"good")
	Sig.ship_changed.emit()

## Take a part off. Refused when the hold is full, because the alternative is
## destroying it — and a refit screen that silently melts what you unbolt is
## worse than one that says no.
func uninstall_module(m: ModuleData) -> bool:
	# Against THIS part, not against the hold in general: a bulky array can be
	# refused by a hold that would still take the sight beside it.
	if not has_room_for(m):
		log_line("No room in the hold for %s." % m.name, &"them")
		return false
	installed.erase(m)
	m.mount = -1
	place_in_hold(m)
	Sig.ship_changed.emit()
	return true

## Break a part down for scrap. Scrap ONLY.
##
## It used to also yield alloy, and that is the half that is gone: a part turning
## into a second resource made alloy behave like a second currency, which is the
## thing the one-currency ruling exists to prevent. Scrap is what a part is
## worth; the fabricator's prerequisites come from places you flew to, not from
## the hold you were going to empty anyway.
##
## SCRAP and MELT were one operation under two names — this function priced by
## Market.melt() and wore a SCRAP label in every screen. The refit screen's melt
## cell is gone; this is the survivor, and it is called scrapping.
func scrap_module(m: ModuleData) -> void:
	var v := scrap_value_of(m)
	take_from_hold(m)
	add_credits(v)
	log_line("Scrapped %s for %d credits." % [m.name, v], &"good")
	Sig.ship_changed.emit()

func transfer_to_hull(h: HullData) -> void:
	# Shed anything that no longer fits, cheapest first.
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		var cap: int = h.slots_for(s)
		while slots_used(s) > cap:
			var worst: ModuleData = null
			for x in installed:
				if x.slot == s and (worst == null or x.scrap_value < worst.scrap_value):
					worst = x
			if worst == null:
				break
			installed.erase(worst)
			worst.mount = -1
			# The new hull's hold may be a different shape, and this runs BEFORE
			# the swap, so a part placed now is placed against the old grid.
			# Re-packed below once `hull` is the new one.
			if not place_in_hold(worst):
				log_line("No room for %s. It was left behind." % worst.name, &"them")
	var ratio := float(hp) / float(max_hp())
	hull = h
	hp = maxi(6, int(round(h.max_hull * ratio)))
	# ...and its own HOLD SHAPE. A heavy's 4x10 becoming a light's 4x5 leaves
	# every part below the fifth row outside the grid entirely, so the hold is
	# re-seated for the same reason the mounts below are.
	repack_hold()
	# The new hull has its own hardpoint count, so a part mounted on weapon 3 of a
	# heavy can be pointing at a mount a light does not have. Re-seated in the
	# order they were carried, which loses the arrangement you chose — that is
	# honest: it is a different ship, and the mounts are places on it.
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		for m in installed:
			if m.slot == s:
				m.mount = -1
		for m in installed:
			if m.slot == s:
				m.mount = free_mount(s)
	found_hull = null
	var said: Array[String] = []
	for pid in h.perks():
		said.append(DB.perk_text(pid))
	log_line("Transferred to %s. %s" % [h.display_name(), " ".join(said)], &"big")
	Sig.ship_changed.emit()
	Sig.resources_changed.emit()

# -------------------------------------------------------------------------- map

func node_at() -> MapGen.MapNode:
	return map[at]

## Where you are, or null when there is nowhere yet.
##
## `node_at()` indexes the map and is right to: every caller inside a run is
## standing somewhere, and a null return would only push the crash one frame
## later. But the chassis select runs with a hull and no galaxy — you pick a ship
## before there is anywhere to fly it — and it draws the HUD, which asks the
## market what repairs cost here. This is the accessor for the handful of callers
## that can legitimately run outside a run.
func here() -> MapGen.MapNode:
	return null if map.is_empty() else map[at]

## Fuel is distance. Not a flat lateral rate and a flat coreward rate — those
## made every jump on the chart cost the same 1 fuel no matter how far it
## plainly was, which is why the numbers beside the systems looked like
## decoration.
##
## An ordinary hop is about 0.11 of a disc radius now that the field is even,
## so this prices one at 1 fuel and a long reach across the cluster at 2.
##
## The attrition of the frontier no longer comes from each hop being dear — it
## comes from there being 42 systems on the rim ring and 14 at the core. Farming
## the edge is a long haul rather than an expensive one, which is a cleaner way
## to say the same thing.
## Raised from 10. At 10 an ordinary hop cost 1 fuel out of a 150-unit tank, so
## wandering was nearly free and a run averaged ninety-odd jumps — the greed
## clock had no hands. At 17 a hop costs 2 and a long reach 3, which prices
## farming without making the map hostile: measured, 62.9 jumps and a 20.3% win
## rate against 93.6 and 21.5% at the old value.
##
## Tuned AFTER fixing the simulator, not before. See HeadlessSim's jump policy —
## the model used to wander on a coin flip regardless of fuel, and tuning this
## against that would have made the real game punitive to correct a bug in the
## thing measuring it.
## 13, down from 17, and this is a UNIT CONVERSION rather than a balance change.
##
## `MapGen.hop_distance` used to measure in the drawn, foreshortened space and
## now measures un-squashed (D1) -- it divides y by the galaxy's squash, which
## averages 0.62, so every distance in the game grew by about a third overnight.
## This constant prices raw distance, so the fuel bill grew with it: measured,
## 1.87 fuel a jump became 2.55, individual hops pinned at the FUEL_MAX_HOP
## ceiling of 6, and 98% of runs ended adrift.
##
## 17 / 1.3 restores the rate the tuning below was measured at. Nothing about
## how dear a jump SHOULD be has been re-decided; the ruler changed length and
## the price per unit had to change with it.
const FUEL_PER_DISC_RADIUS := 13.0

## What one ring-step of the galaxy is worth in starting fuel.
##
## 150/7: the flat 150 that was tuned at LAYERS 9, divided by the seven
## ring-steps that galaxy had. A run now starts with as much fuel as its galaxy
## is deep, and LAYERS 9 reproduces 150 exactly.
const FUEL_PER_RING_STEP := 150.0 / 7.0
const FUEL_MAX_HOP := 6

func fuel_cost_to(n: MapGen.MapNode) -> int:
	var d := MapGen.hop_distance(node_at(), n)
	return clampi(int(round(fuel_factor() * d * FUEL_PER_DISC_RADIUS)),
		1, FUEL_MAX_HOP)

## How many systems the drive can pick from. Range is whatever radius happens
## to enclose this many of your nearest neighbours, so it scales itself: half a
## disc out on the rim where systems are strung far apart, almost nothing near
## the core where they are packed.
##
## Deriving it from the FURTHEST charted link, as this first did, meant one long
## link inflated the radius and dragged a dozen distant systems into range with
## it — the lines that reached across the galaxy while ignoring the neighbour
## sitting right there.
const JUMP_NEIGHBOURS := 6
## Cleared whenever the map changes. Range is a pure function of a system and
## the galaxy, and working it out costs a pass over every system.
var _range_cache: Dictionary = {}

## Reference thrust, and how far a point above it stretches a jump.
##
## REFERENCED TO THE LIGHTEST HULL rather than the middle, because this may only
## ever ADD. See `thrust_reach`.
##
## 0.04 a point is deliberately small: a medium reaches 8% further than a light
## and a heavy 16%, which is a real difference on a crowded map and not a
## different game. These two numbers are the obvious dial for the balance pass.
const THRUST_REF := 4
const THRUST_REACH := 0.04
const THRUST_REACH_MAX := 1.4


## How far this ship's engine stretches a jump, as a multiplier on the map's own
## geometry.
##
## THRUST WAS READ BY EVENT CHECKS AND NOTHING ELSE. `range_from` below derives a
## radius entirely from how densely the galaxy is packed around you -- a fact
## about the MAP, with no term in it for the ship standing on it. The gauge
## described an engine that never moved anything, and a part that raised it
## bought a slightly better roll on a Thrust check and no more.
##
## IT ONLY EVER EXTENDS, and that is a safety property rather than generosity.
## The radius carries a floor -- the third-nearest neighbour, so a sparse ring
## still offers a choice rather than a corridor -- and a multiplier below 1.0
## would cut straight through that floor and could leave a ship with no legal
## jump at all. A low-thrust hull gets no bonus here; it does not get a penalty.
##
## Heavier frames reach further and pay for it in fuel, which they already do:
## `fuel_factor` prices every jump and runs 0.8 / 1.2 / 1.8. Long legs and a big
## tank is a coherent thing for a hauler to be.
func thrust_reach() -> float:
	return clampf(1.0 + float(attr_thrust() - THRUST_REF) * THRUST_REACH,
		1.0, THRUST_REACH_MAX)


## How much further than you can FLY you can SEE, per pip of SENSORS.
##
## 0.25 a pip against a base of the map's own jump radius: a dish worth two pips
## shows you half again as far as you can go. Most hulls launch with no sensors
## at all -- Korvan, Solari and Probate all read zero -- so this is a thing you
## build toward rather than a thing you are given, which is what makes fitting a
## dish a decision instead of a formality.
## The sight a ship has with NO dish at all, as a multiple of the map's own
## jump radius.
##
## Sight is live now -- see `chart_from` -- so a ship at zero sensors would go
## blind and selling a dish would take the chart with it. This is the floor that
## makes that impossible: there is always a baseline neighbourhood.
##
## ON THE RADIUS, NOT ON THE ATTRIBUTE. Flooring `attr_sensors()` was tried and
## it breaks the gauge contract that `-- attrtest` enforces: with the pips
## clamped to 2, a Rare part promising +1 sensors moved the gauge +0 and an
## Artifact promising +4 moved it +2. A dish you fit has to do something. So the
## attribute stays honest from 0 and the BASELINE lives here, which also means
## every pip still buys the same 0.25 on top rather than the first two being
## dead.
##
## It is also the dial for whether a galaxy is playable at all. The base radius
## is RELATIVE to your nearest neighbour rather than absolute -- `_map_range_from`
## takes about 2.5x the nearest, floored at the third and capped at the sixth --
## so a sparse frontier already widens it and a spawn in a system desert is not
## the trap it looks like. If a kind still comes out unplayable, raise this
## before touching the geometry.
## How far a drive reaches, in galaxy units. A FIXED distance.
##
## It used to be derived from local density -- 2.5x your nearest neighbour,
## clamped between the third and sixth, which held the option count near six
## wherever you stood. That worked and it hid the range: measured across one
## galaxy the radius swung 5x, so the reach ellipse resized as the ship moved,
## a rim jump crossed five times what a core jump did and was billed for it,
## and thrust multiplied a local accident rather than a knowable number.
##
## 0.18 measured against the flattened rings in `MapGen.ring_count`: five
## systems in reach at the rim, fourteen at the deepest, never none.
##
## NOT scaled by the galaxy. `reach` already multiplies every position -- see
## MapGen `gal = galaxy_pos(n) * reach` -- so a galaxy authored large is one a
## fixed radius crosses in more hops, which is exactly what that dial is for.
const JUMP_RADIUS := 0.18

const SENSE_FLOOR := 1.5

const SENSE_REACH := 0.25


## How far the ship can see, in the same units as the jump radius.
##
## OFF THE MAP TERM, not off `range_from`, and deliberately: sight should not
## quietly inherit the engine. A hauler with long legs is not more observant.
func sense_radius() -> float:
	if map.is_empty():
		return 0.0
	return sense_radius_of(node_at())


## The same radius around any system, not just the one under the ship.
##
## Needed because SIGHT HAS TO HAVE THE SAME SHAPE AS REACH. `reachable_from` is
## symmetric -- a hop is legal if EITHER end's radius encloses the other -- and
## `chart_from` was not, so anything reachable only through the far end's radius
## could never be seen, and criterion 1 then made it permanently unjumpable.
##
## On a ring galaxy that is the core itself: it sits alone inside the hole, its
## own neighbourhood radius is huge because its nearest neighbour is half a disc
## away, and the inner ring can therefore reach it -- but never sensed it, so the
## ship circled the rim until the run ended. Collisional Ring: 0% wins, 233 jumps.
##
## It reads sensibly too. A system that dominates a large empty region is one you
## can pick out from further off than a system crowded in among others.
func sense_radius_of(here: MapGen.MapNode) -> float:
	if map.is_empty() or here == null:
		return 0.0
	return _map_range_from(here) * (SENSE_FLOOR + float(attr_sensors()) * SENSE_REACH)


## Mark everything within sight of `here` as charted.
##
## STICKY, WHICH IS THE WHOLE DESIGN. `station_heard` refuses to scale with
## sensors because a chart that forgets a system when you sell a dish is worse
## than one that never showed it. A mark that is only ever SET has no such
## failure: refitting costs you what you have not seen yet and never takes back
## what you have. See MapGen.MapNode.sensed.
##
## Called on arrival and at the start of a run, so the first thing a dish does
## is show you where you are standing.
func chart_from(here: MapGen.MapNode) -> void:
	if here == null:
		return
	var r := sense_radius()
	if r <= 0.0:
		return
	# LIVE, NOT REMEMBERED. This mark used to be set and never cleared, so the
	# chart accumulated every system the dish had ever swept and the galaxy was
	# solved after enough hops. Clearing first is what makes the frontier dark
	# and what gives a better dish something to buy.
	#
	# `visited` is NOT cleared and is a separate reason to draw a system -- see
	# StarchartScreen._visible_set. Where you have BEEN is a track record rather
	# than a sighting, `Run.trail` draws it, and it is what you plan routes
	# through. Nor are `station_heard` or a contract's marker: those are things
	# you were TOLD, and being told does not stop being true when you move.
	for n in map:
		(n as MapGen.MapNode).sensed = false
	# THE CORE IS NOT SOMETHING YOU FIND. It is the galactic centre, it is where
	# the run ends, and the chart names it from the first frame -- so criterion 1
	# should never be what stands between a ship and the objective.
	#
	# It has to be said explicitly because the core is the one node that sits
	# outside the rings. On a galaxy with a hole it is alone in the middle, half
	# a disc from its nearest neighbour: `reachable_from` allows the hop through
	# the core's own radius, and `chart_from` -- which only ever measures YOUR
	# dish -- could never mark it seen. Collisional Ring: 0% wins, 233 jumps
	# spent circling a rim, because the destination was unsensed and unjumpable.
	for g in map:
		if (g as MapGen.MapNode).type == MapGen.NodeType.CORE:
			(g as MapGen.MapNode).sensed = true
	for n in map:
		var t: MapGen.MapNode = n
		if t.sensed or t.index == here.index:
			continue
		# YOUR DISH, one-directional. Mirroring `reachable_from`'s symmetry here
		# was tried and is far too generous: a system alone in a sparse region
		# has a huge neighbourhood radius, so every such system became visible
		# from across the galaxy and a Collisional Ring fell to 7.4 jumps.
		if MapGen.hop_distance(here, t) <= r:
			t.sensed = true


## The jump radius from `here`, engine included.
func range_from(here: MapGen.MapNode) -> float:
	return _map_range_from(here) * thrust_reach()


## The same radius WITHOUT the ship, which is the half worth caching.
##
## The galaxy's own geometry costs a pass over every system to work out and
## never changes within a run; the engine's multiplier is a property of the ship
## and moves the moment a part is fitted. Keeping them apart means bolting on a
## thruster does not have to invalidate anything.
func _map_range_from(_here: MapGen.MapNode) -> float:
	return JUMP_RADIUS

## Close enough to fly to. Pure distance, nothing else.
##
## There used to be a hard cap of one shell as well. It was a genuine necessity
## when range was a fixed radius wide enough to reach along a rim ring — that
## same radius reached most of the way to the core — but it stopped being one
## the moment range became relative to your nearest neighbour, which is local by
## construction. What it did keep doing was refusing a system you could plainly
## see was nearer than one it offered, because the nearer one happened to lie
## two rings in. A map that contradicts the picture is worse than a map that
## lets you cut a corner.
##
## Charted links do not grant passage either: a link is how generation
## guarantees the galaxy hangs together, not a promise that the place is near.
##
## SYMMETRIC, and it has to be. Range is relative to the neighbourhood you are
## standing in, and two ends of one hop can disagree about it: out on a thin
## frontier your nearest neighbour is far, so the radius is wide and a crowded
## cluster three parsecs off is a legal jump — and once you are down in that
## cluster your nearest neighbour is a hand's width away, the radius shrinks to
## match, and the way you CAME IN is suddenly out of range. A one-way door, and
## the chart still draws the link you flew. So a hop is legal if either end
## thinks the other is close: n is in my neighbourhood, or I am in n's. The
## fuel cost is distance-priced already, so a long way back is expensive rather
## than impossible.
func reachable_from(here: MapGen.MapNode, n: MapGen.MapNode) -> bool:
	if n.index == here.index:
		return false
	# THE FINAL APPROACH IS ALWAYS AVAILABLE FROM THE LAST RING.
	#
	# The core sits at the centre, at radius zero, while the innermost ring sits
	# at `CORE` -- about 0.11 -- so in an ordinary galaxy a fixed reach of 0.19
	# covers that last hop with room to spare and this rule changes nothing.
	#
	# A galaxy with a HOLE is the exception it exists for. `galaxy_pos` maps every
	# ring into the annulus above `ring`, so on a Collisional Ring the innermost
	# ring is at 0.52 and the core is still at zero. Nothing can cross that: the
	# old density-derived radius grew in the sparse middle and bridged it, and a
	# fixed radius cannot. Measured without this: 0% wins and 317 jumps spent
	# circling a rim that has no way in.
	#
	# Shrinking `ring` instead would need it under about 0.09 to close the gap
	# geometrically, which is not a ring galaxy any more.
	#
	# It is the same argument as the core being permanently charted: the middle
	# of the galaxy is where the run ENDS, and it should be the danger that stops
	# you there, never the geometry.
	if n.type == MapGen.NodeType.CORE and here.layer >= MapGen.LAYERS - 2:
		return true
	var d := MapGen.hop_distance(here, n)
	return d <= range_from(here) or d <= range_from(n)

func reachable(n: MapGen.MapNode) -> bool:
	return reachable_from(node_at(), n)

## The local cluster, as the chart draws it.
func in_range_of(here: MapGen.MapNode) -> Array:
	var out: Array = []
	for n in map:
		if reachable_from(here, n):
			out.append(n)
	return out

func in_range() -> Array:
	return in_range_of(node_at())

func jump_range() -> float:
	return range_from(node_at())

## The three criteria, and they are the whole rule: SEE it, AFFORD it, REACH it.
##
## `n.sensed` is the first of them and used to be missing. It was set by
## `chart_from` and read only by the chart's visible set, so sensors decided what
## was DRAWN and never what could be flown to -- and because sight and reach come
## off the same base with different multipliers, any ship whose thrust outran its
## dish could jump to somewhere it had never seen.
##
## Sticky, so this is "have you ever charted it", not "is it lit up right now".
## That is `chart_from`'s design and the right reading here too: a place you
## surveyed last ring does not stop existing when you move on.
##
## Cannot stand a ship still. Sight is base * (1 + sensors * 0.25) and reach is
## base * thrust_reach(), thrust_reach is floored at 1.0, so everything within
## the base radius is always both -- and that set is never empty.
func can_jump_to(n: MapGen.MapNode) -> bool:
	return n.sensed and reachable(n) and fuel >= fuel_cost_to(n)

## True while at least one link out of the current node is affordable.
func has_legal_jump() -> bool:
	for n in map:
		if can_jump_to(n):
			return true
	return false

## Ends the run when no jump is affordable. Without this the ship sits on the
## chart alive and immobile forever — a soft-lock the simulator hit in 9% of runs.
## Call only after a node is fully resolved: a station refuel or an event can
## still rescue an empty tank, so checking on arrival would kill unfairly.
func check_stranded() -> void:
	if dead or won:
		return
	if not has_legal_jump():
		die("Adrift. The tank ran dry between stars.")

func jump_to(index: int) -> void:
	var n: MapGen.MapNode = map[index]
	if not can_jump_to(n):
		return
	fuel -= fuel_cost_to(n)
	at = index
	trail.append(index)
	n.visited = true
	# What the dish picks up on arrival. Before the signals below, so a system
	# revealed by getting near it is on the chart the moment you land.
	chart_from(n)
	jumps += 1
	cool_in_transit()
	# The galaxy's other harvester moves on the party's clock, and a jump is
	# the tick. After `at` is set, so "it is HERE" can be said about the right
	# system. No-op on a client — the host counts every ship's jumps, including
	# this one's, when the presence lands. See the hellbender block below.
	hellbender_jumped()
	Sig.resources_changed.emit()
	Sig.jumped.emit(index)


# ----------------------------------------------------------------- the hellbender
## THE GALAXY'S OTHER HARVESTER. One rival crew per dive, flying a furnace of a
## ship, doing exactly what you are doing — and it is the one enemy with a
## POSITION instead of an address. It rides the same link lattice the player
## does, one hop at a time, eating the derelicts it lands on.
##
## WHO DECIDES WHERE IT IS. The map's other shared facts are positional — a
## seed puts the same wreck on four machines — but a thing that MOVES needs a
## clock, and this game deliberately has no shared one: four ships jump at
## their own pace. So the hellbender is host-authoritative, like a claim. The host
## counts every ship's jumps (its own directly, a client's when the presence
## message lands), moves the hellbender every `hellbender_stride()` of them —
## a threshold that scales with the crew, so a bigger party does not shake it
## off the chart — and pushes the whole state — position, hull, move counter —
## through `Net.push_hellbender()`.
## Solo, this machine IS the host of nothing and runs the same code without a
## wire. WHERE it goes is `Rng.derive(&"hellbender", move counter)` — positional in
## time rather than in space, so a replayed seed replays the pursuit and a
## client handed the counter could re-derive the walk.
##
## WHY IT EATS. §0 of `docs/coop-design.md` measured that attaching more
## fights to a mechanic adds texture, not pressure, because fights pay. The
## hellbender is pressure because AVOIDING it costs: every derelict it reaches
## first is salvage the party does not get. Kill it or route around it, and
## both of those are decisions with prices.
##
## WHY IT HEALS IN TRANSIT. It breaks off at 35% hull (see
## Combat.escape_intent()) carrying its damage, and mends HELLBENDER_MEND per move
## after. That is the chase: the hull you took off it is a debt it pays back
## slowly, so catching it two jumps later finishes a fight you already started,
## and letting it go quiet for twenty is starting over.

## Jumps between moves, SOLO. At ~65 jumps a run this is ~20 moves — enough to
## matter on the chart, slow enough to be caught.
const HELLBENDER_STRIDE := 3
## Jumps between moves in a crew, PER SHIP. The clock counts the whole party's
## jumps, so a flat threshold means the more of you there are the faster it
## runs: at three, two ships moved it every jump and a half each, and it was
## always gone by the time anybody landed on it. Nobody ever met it. Scaled by
## the crew, the cadence is a thing each pilot can feel — two of YOUR jumps per
## port, however many of you are flying — and the second jump is the window
## somebody catches it in. A shade quicker per ship than the solo three,
## because four ships strip a galaxy four times as fast and a rival that cannot
## keep up is not a rival.
const HELLBENDER_STRIDE_CREW := 2
## Hops taken all at once when it breaks off a fight. Two, so it is out of the
## system and out of jump range, but never out of the story.
const HELLBENDER_FLEE_HOPS := 2
## Hull mended per ordinary move while damaged — never per flee hop, so it
## escapes hurt and STAYS hurt until it has had quiet moves. Against a 90
## hull, a fight that left it at 32 is paid back in ten moves — thirty party
## jumps — and that window is the chase.
const HELLBENDER_MEND := 6

## Node index, or -1 once it is dead. There is no `alive` flag; a position is
## the one fact everything else about it hangs off, so absence of one IS death.
var hellbender_at: int = -1
var hellbender_hp: int = 0
var hellbender_max: int = 0
## How many moves it has made. Drives the stride and seeds each move's roll.
var hellbender_moves: int = 0
## Jumps counted toward the next move.
var hellbender_ticks: int = 0
## Test seam: `-- sim nohellbender` measures the control cell. Never set from game
## code — the same discipline as Net.forced_protocol.
var hellbender_off: bool = false

func hellbender_alive() -> bool:
	return hellbender_at >= 0 and hellbender_hp > 0

## Whether this machine is the one that moves it: the host, or nobody's client.
func _hellbender_authority() -> bool:
	return not Net.is_networked() or Net.is_host()

## Placed at generation, off a positional roll rather than the world stream —
## `Rng.world`'s draw order is finished business, and one extra draw here would
## quietly move everything rolled after it. Middle shells: deep enough that a
## fresh chassis is not ambushed by a set piece, shallow enough that every run
## crosses its ground.
func _spawn_hellbender() -> void:
	hellbender_at = -1
	hellbender_hp = 0
	hellbender_moves = 0
	hellbender_ticks = 0
	if hellbender_off:
		return
	var t: EnemyTemplate = DB.enemies.get(&"hellbender")
	if t == null or map.is_empty():
		return
	var candidates: Array = []
	for n in map:
		var node: MapGen.MapNode = n
		if node.layer >= 3 and node.layer <= MapGen.LAYERS - 3:
			candidates.append(node.index)
	if candidates.is_empty():
		return
	hellbender_max = t.max_hull
	hellbender_hp = hellbender_max
	hellbender_at = Rng.pick(Rng.derive(&"hellbender", 0), candidates)

## Party jumps per move, for the crew currently flying. See the constants: the
## count is the whole party's, so the threshold has to be the whole party's too
## or the rival outruns a bigger crew. The call site tests the counter against
## this with `<` rather than an equality, so a crew that SHRINKS mid-run — the
## threshold dropping under a counter already past it — moves the rival on the
## next jump instead of stranding it forever.
func hellbender_stride() -> int:
	var crew := maxi(1, Net.party_size())
	return HELLBENDER_STRIDE if crew <= 1 else HELLBENDER_STRIDE_CREW * crew

## A jump happened somewhere in the party. Called by jump_to() for this ship
## and by NetSession._apply_presence() for everybody else's; the authority
## guard makes both safe to call unconditionally.
func hellbender_jumped() -> void:
	if not hellbender_alive() or not _hellbender_authority():
		return
	# Pinned while anybody is in its fight. The party's other ships keep
	# jumping, but a thing being shot at does not leave except through the
	# escape burn — the clock stopping IS "keeping him on the ropes".
	if Net.fight_open_at(hellbender_at):
		return
	hellbender_ticks += 1
	if hellbender_ticks < hellbender_stride():
		return
	hellbender_ticks = 0
	_hellbender_step(true)
	Net.push_hellbender(true)

## One hop. `feeding` is false on a flee hop — a ship running for its life is
## not stopping to cut salvage, and the client applying the pushed position
## must agree about which kind of landing it was. See hellbender_land().
func _hellbender_step(feeding: bool) -> void:
	if not hellbender_alive():
		return
	hellbender_moves += 1
	var r := Rng.derive(&"hellbender", hellbender_moves)
	var here_n: MapGen.MapNode = map[hellbender_at]
	var options: Array = []
	var food: Array = []
	for i in here_n.links:
		var n: MapGen.MapNode = map[i]
		# Not the rim's first system and not the core: one is the front door,
		# and the other already has a custodian in it.
		if n.type == MapGen.NodeType.START or n.type == MapGen.NodeType.CORE:
			continue
		options.append(i)
		# WHAT IS ACTUALLY HERE, not what the node was labelled. A wreck is a
		# system offering something to strip, which is the same question
		# `NodeType.DERELICT` used to answer and a better-informed one.
		if OptionTable.system_has_tag(n, &"salvage") and not n.cleared:
			food.append(i)
	if options.is_empty():
		return
	# Mending rides the ordinary stride, never a flee hop — it escapes HURT and
	# stays hurt until it has had quiet moves, which is the window the chase is.
	if feeding and hellbender_hp < hellbender_max:
		hellbender_hp = mini(hellbender_max, hellbender_hp + HELLBENDER_MEND)
	# It goes where the salvage is. That is what makes it legible enough to
	# route around — and what makes racing it to a wreck a real race.
	var to: int = Rng.pick(r, food if feeding and not food.is_empty() else options)
	hellbender_land(to, feeding)

## Apply a landing — the shared half, run by the authority when it moves the
## hellbender and by a client when the pushed position arrives. Everything here is
## a pure function of the landing, so the party cannot disagree about it.
func hellbender_land(to: int, feeding: bool) -> void:
	if to < 0 or to >= map.size():
		return
	hellbender_at = to
	var n: MapGen.MapNode = map[to]
	if feeding and OptionTable.system_has_tag(n, &"salvage") and not n.cleared:
		# Consumed locally, not through Net.claim(): the movement push is
		# already the shared fact, and every machine applies this rule to the
		# same landing. `eaten` is what lets the sector say WHO stripped it.
		n.cleared = true
		n.eaten = true
		_mark_taken(n, MapGen.OPTION_WHOLE)
		log_line("The wreck at %s goes dark on the scope. The Hellbender is feeding." % MapGen.star_name(n), &"them")
	if to == at:
		log_line("A furnace-hot signature fills the sky. THE HELLBENDER IS HERE.", &"big")
	Sig.map_changed.emit()

## A fight ended without a kill — somebody fled, died, or the whole crew walked
## out. The hull it lost stays lost; that is the half of "keep him on the
## ropes" that survives between engagements.
func hellbender_scarred(hp: int) -> void:
	if not hellbender_alive() or not _hellbender_authority():
		return
	hellbender_hp = clampi(hp, 1, hellbender_max)
	Net.push_hellbender(false)

## It spooled the escape burn and nobody stopped it. Damage written back, then
## HELLBENDER_FLEE_HOPS at once — gone from the system and from jump range, hurt,
## and mending only as fast as HELLBENDER_MEND allows.
func hellbender_breaks_off(hp: int) -> void:
	if not hellbender_alive() or not _hellbender_authority():
		return
	hellbender_hp = clampi(hp, 1, hellbender_max)
	for i in HELLBENDER_FLEE_HOPS:
		_hellbender_step(false)
	Net.push_hellbender(false)

## The kill. Called wherever the last hull point comes off — Combat._victory()
## solo and on every crew machine, NetSession._apply_hurt() on a host that was
## not in the fight. Idempotent, because in a party several of those fire.
func hellbender_defeated() -> void:
	if hellbender_at < 0:
		return
	hellbender_at = -1
	hellbender_hp = 0
	log_line("The Hellbender comes apart, and a run's worth of stolen heat bleeds into the dark.", &"good")
	Sig.map_changed.emit()
	Net.push_hellbender(false)

## The host said where it is. Position, hull and counter arrive together and
## whole, like every other host-owned fact, so a dropped push costs one update
## rather than a drift.
func hellbender_adopt(to: int, hp: int, moves: int, feeding: bool) -> void:
	hellbender_moves = moves
	hellbender_hp = hp
	if to < 0:
		# Only a machine that was NOT in the fight gets here still believing it
		# alive — the crew already ran hellbender_defeated() in _victory(), and
		# their own copy skips this branch. So the line is the convoy channel
		# telling you what you missed.
		if hellbender_at >= 0:
			hellbender_at = -1
			hellbender_hp = 0
			log_line("Word on the convoy channel: the Hellbender is dead.", &"good")
			Sig.map_changed.emit()
		return
	if to == hellbender_at:
		Sig.map_changed.emit()
		return
	hellbender_land(to, feeding)


# ------------------------------------------------------------------ contracts

## Take a job. Returns the accepted copy, which is the one that goes in the
## ledger — the board's object stays on the board, so a co-op partner docking a
## moment later is offered the same work rather than an empty page.
func take_contract(c: ContractData) -> ContractData:
	var mine := ContractData.from_wire(c.to_wire())
	mine.id = next_contract_id
	next_contract_id += 1
	mine.state = ContractData.State.TAKEN
	contracts.append(mine)
	log_line("Signed: %s. %d credits on delivery." % [
		_contract_short(mine), mine.pay], &"sys")
	Sig.contracts_changed.emit()
	return mine

## Whether this exact piece of work is already in your ledger.
##
## Compared on WHAT IT IS rather than on an id, because the board regenerates its
## objects every time it is drawn — `Contracts.board()` is derived, not stored —
## so the offer you are looking at is never the same object you accepted.
func holds_contract(c: ContractData) -> bool:
	for other in contracts:
		var o: ContractData = other
		if o.state == ContractData.State.CLOSED:
			continue
		if o.manufacturer == c.manufacturer and o.kind == c.kind and o.at == c.at \
				and o.amount == c.amount and o.posted_at == c.posted_at:
			return true
	return false

## Work that is done and waiting to be paid at one of this station's berths.
func deliverable_at(n: MapGen.MapNode) -> Array:
	var out: Array = []
	for c in contracts:
		var job: ContractData = c
		if job.state != ContractData.State.READY:
			continue
		if ContractData.berth_of(n, job.manufacturer):
			out.append(job)
	return out

## Heat contracts you could close RIGHT NOW, standing where you are.
##
## Separate from deliverable_at() because a heat contract is never READY out in
## the dark — it becomes closable at the moment you dock still carrying the heat,
## and it stops being closable the moment you vent. It is the one job whose
## completion is a fact about this second.
func heat_deliverable_at(n: MapGen.MapNode) -> Array:
	var out: Array = []
	for c in contracts:
		var job: ContractData = c
		if job.state != ContractData.State.TAKEN \
				or job.kind != ContractData.Kind.HEAT:
			continue
		if ContractData.berth_of(n, job.manufacturer) and heat >= job.amount:
			out.append(job)
	return out

## Paid. Heat contracts spend the heat; the other two spend the flying you
## already did.
func deliver_contract(job: ContractData) -> void:
	if job == null or job.state == ContractData.State.CLOSED:
		return
	if job.kind == ContractData.Kind.HEAT:
		if heat < job.amount:
			return
		heat -= job.amount
		log_line("Offloaded %d heat. Weighed, receipted, gone." % job.amount, &"heat")
	job.state = ContractData.State.CLOSED
	add_credits(job.pay)
	standing[job.manufacturer] = int(standing.get(job.manufacturer, 0)) + job.standing
	log_line("Delivered. %d credits. %s account in good order." % [
		job.pay, DB.short_name(DB.manufacturer_name(job.manufacturer))], &"good")
	Sig.contracts_changed.emit()
	Sig.resources_changed.emit()

## Arriving somewhere finishes any FETCH pointed at it.
##
## Called from the one door every arrival goes through. A recovered item is
## NAMED AND NOT CARRIED: it does not take a hold slot, cannot be scrapped by
## accident and cannot be lost to a full hold. A contract that soft-locks on
## inventory is a bug wearing a decision's clothes, and there is no version of
## "you sold the thing you were paid to fetch" that is worth what it costs.
func reach_contract_target(index: int) -> void:
	var moved := false
	for c in contracts:
		var job: ContractData = c
		if job.state != ContractData.State.TAKEN or job.at != index:
			continue
		if job.kind != ContractData.Kind.FETCH:
			continue
		job.state = ContractData.State.READY
		moved = true
		log_line("Recovered: %s. Lashed to the frame and not yours yet." % job.item,
			&"good")
	if moved:
		# The paperwork rides with the thing the manufacturer wanted back, and the
		# manufacturer never asks what you read on the way. Fourth door, same hinge —
		# see Archive.recover_at.
		Archive.recover_at(map[index], "folded in with the contract cargo")
		Sig.contracts_changed.emit()

## Winning a fight here finishes any HUNT pointed at it.
func clear_contract_target(index: int) -> void:
	var moved := false
	for c in contracts:
		var job: ContractData = c
		if job.state != ContractData.State.TAKEN or job.at != index:
			continue
		if job.kind != ContractData.Kind.HUNT:
			continue
		job.state = ContractData.State.READY
		moved = true
		log_line("Contact removed. %s will want to hear about it." %
			DB.short_name(DB.manufacturer_name(job.manufacturer)).to_upper(), &"good")
	if moved:
		Sig.contracts_changed.emit()

## How well a manufacturer thinks of you. Zero for six of them, most of the time.
func standing_with(manufacturer: StringName) -> int:
	return int(standing.get(manufacturer, 0))

## What their berths pay OVER the going rate for your parts, as a fraction.
##
## The benefit is on the BID and never on the ask, and that is a hard constraint
## rather than a preference: `Market`'s invariant leaves only about seven percent
## between what a part melts for and the floor under what a station charges, so
## a discount on the ask is a buy-and-melt exploit at four points of standing.
## Paying you more for what you carry in has no such edge and reads the same at
## the counter.
##
## Capped, because bid is a fraction of ask and must stay one.
const STANDING_BID := 0.05
const STANDING_BID_MAX := 0.20
func standing_bid_bonus(manufacturer: StringName) -> float:
	return minf(float(standing_with(manufacturer)) * STANDING_BID, STANDING_BID_MAX)

func _contract_short(c: ContractData) -> String:
	match c.kind:
		ContractData.Kind.HEAT:
			return "%d heat to %s" % [c.amount,
				DB.short_name(DB.manufacturer_name(c.manufacturer))]
		ContractData.Kind.HUNT:
			return "a contact at %s" % MapGen.star_name(map[c.at]) if c.at >= 0 \
				and c.at < map.size() else "a contact"
		_:
			return "%s from %s" % [c.item, MapGen.star_name(map[c.at])] if c.at >= 0 \
				and c.at < map.size() else c.item


## The open contract pointing at this system, or null. First match wins; two
## manufacturers wanting something from one place is legal and the chart only has room
## to say so once.
func contract_at(index: int) -> ContractData:
	for c in contracts:
		var job: ContractData = c
		if job.state == ContractData.State.TAKEN and job.at == index:
			return job
	return null


## Manufacturers with something waiting to be handed over: a heat contract you are
## carrying the heat for, or any job you have already finished out there.
##
## THE THIRD THING THE CHART HAS TO MARK. A fetch and a hunt point at a place
## before you go; this points at a place afterwards, and a heat contract points
## at one and never had a target at all. Without it the chart answers "where is
## the work" and goes silent on "where do I take it", which is the half of the
## trip that actually costs fuel.
func delivery_manufacturers() -> Array:
	var out: Array = []
	for c in contracts:
		var job: ContractData = c
		if job.state == ContractData.State.READY \
				or (job.state == ContractData.State.TAKEN
					and job.kind == ContractData.Kind.HEAT):
			if not out.has(job.manufacturer):
				out.append(job.manufacturer)
	return out


## True when the ONLY reason this system is on the chart is that you signed for
## it — not visited, not a station, not reachable from where you stand.
##
## Signing reveals WHERE, and nothing else. You are told a place exists and given
## its name, because a job that names a system you cannot find is a memory test;
## you are not told what is in it, how policed it is or who operates there,
## because none of that was in the offer. The manufacturer said go here. It did not say
## what here is.
##
## That asymmetry is the whole point and it is worth not smoothing away later: a
## contract is a REASON to fly somewhere unexplored, and it stops being one the
## moment accepting it also explores the place.
## A STATION YOU HAVE HEARD. Stations are on the chart before you visit them,
## and this is how far "before" reaches.
##
## The exception itself is right and stays: the filter is correct about a place
## you might GO and wrong about a place you navigate BY. A station means "you can
## stop here" — repairs, fuel, a market, no danger — and it is most valuable to a
## ship that has not found one yet, so hiding it until you have already been
## there is backwards.
##
## WHAT WAS WRONG WAS THE RANGE, WHICH WAS INFINITE. Every station in the galaxy
## sat on the chart from the first frame of a run, so KNOWN ONLY drew the four or
## five systems you had actually been to and then every station out to the rim —
## a view of what you have earned, dominated by the one thing you had not earned
## any of. It read as a bug because it was one: a filter whose exception is
## larger than its rule.
##
## ONE HOP, and the fiction is the mechanism: a station broadcasts, and you pick
## it up from next door. Having stood in a system means having listened there, so
## a station adjacent to anywhere you have been is a station you know about, and
## one four layers away through systems you have never seen is not.
##
## Deliberately NOT scaled by SENSORS, though it is the obvious next move and the
## attribute would carry it well. A beacon range that changes when you swap a
## dish means the chart forgets systems when you refit, and a map that loses
## places you were told about is worse than one that never said.
func station_heard(index: int) -> bool:
	if index < 0 or index >= map.size():
		return false
	var n: MapGen.MapNode = map[index]
	if n.type != MapGen.NodeType.STATION:
		return false
	if n.visited or index == at:
		return true
	# AND NOTHING ELSE. A station used to be revealed when any VISITED system
	# had a `link` to it, which is a relationship that governs nothing -- links
	# are the graph the chart draws, not the one the ship flies -- and a link
	# can be long. Swapping it for `reachable_from` was more defensible and
	# revealed MORE, because a radius is wider than a link.
	#
	# Ruled 2026-08-26: you can only see what you can see. Sight is live, and a
	# station is a place you sensed, or a place you have been. The old comment
	# above objects that a chart which loses places you were told about is worse
	# than one that never said -- and that is answered rather than overruled,
	# because nothing is lost now: the mark is never gained in the first place,
	# so no refit and no departure can take it away.
	return false


func known_only_by_contract(index: int) -> bool:
	if index < 0 or index >= map.size():
		return false
	if contract_at(index) == null:
		return false
	var n: MapGen.MapNode = map[index]
	# `station_heard` and not "is a station". A station out of beacon range is
	# NOT already on the chart, so a contract naming one is doing the same work
	# it does for any other unexplored system, and the panel has to say so.
	if n.visited or station_heard(index) or index == at:
		return false
	for r in in_range():
		if (r as MapGen.MapNode).index == index:
			return false
	return true
