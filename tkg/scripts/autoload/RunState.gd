extends Node
## Everything that persists across a run: ship, cargo, economy, map position.
## Combat state lives in Combat.gd and is discarded when the fight ends.

var hull: HullData
## Empty until the pilot names it, so a hull swap keeps the name instead of renaming the ship.
## Why: docs/why/RunState.md#ship-name
var ship_name: String = ""

## Which manufacturer this run launched as, for unlocks: a swap onto an unbranded
## frame must not erase who you won with, so it is set once at launch.
var launched_as: StringName = &""

## Every place that shows the player's ship calls this, so the masthead and combat plate agree.
## Why: docs/why/RunState.md#ship-name
func display_name() -> String:
	var named := ship_name.strip_edges()
	if named != "":
		return named
	return hull.name if hull != null else ""
var installed: Array[ModuleData] = []
var cargo: Array[HoldItem] = []
## Galaxy kind (0 two-arm, 1 barred, 2 four-arm) is fixed: a map that changes shape is not a map.
## The trail is every system visited, in order: the route taken is the run's story.
var trail: PackedInt32Array = PackedInt32Array()
var galaxy_kind: int = 0
## Both fixed for the run: the chart rebuilds from them, so a change mid-run would
## move the sky and the systems under the player.
var galaxy: Dictionary = {}
var galaxy_seed: int = 0
## The galaxy is turned by a rolled angle so the rim start can be anywhere, not always
## the right-hand edge, without moving any relative position.
var galaxy_spin: float = 0.0

var galaxy_name: String = ""
var galaxy_title: String = ""

var hp: int = 35
var heat: int = 0
var heat_cap_bonus: int = 0

## Overflow from the old ship waits here instead of being deleted to keep cargo's grid invariant.
## Why: docs/why/RunState.md#moving-ships
var pad: Array[HoldItem] = []

## The old frame stays a real hull until the move ends, so the transfer screen can draw it.
## Why: docs/why/RunState.md#moving-ships
var old_hull: HullData = null

## Undo is a snapshot of an untouched state; not saved, and cleared by a load.
## Why: docs/why/RunState.md#moving-ships
var _undo_move: Dictionary = {}
var credits: int = 40
## FUEL AND DROSS ANNOUNCE THEMSELVES. See the note below.
var fuel: int = FUEL_TANK:
	set(v):
		# A tank with a top: every write passes here, so no site can miss the cap. See FUEL_TANK.
		fuel = mini(v, fuel_cap())
		Sig.resources_changed.emit()

## Materials are prerequisites, never a second currency; credits stay the only currency.
## Why: docs/why/RunState.md#materials

## Read-only total of exotic-tier things, counted by tier, for the run record only.
## Why: docs/why/RunState.md#materials
var exotic: int:
	get:
		var n := 0
		for raw in cargo:
			var m := raw as MaterialData
			if m != null and m.tier == &"exotic":
				n += 1
		return n
## Stores which malfunctions, not a count, so the deck rebuilds identically on every load.
## Why: docs/why/RunState.md#dross
var dross: Array[StringName] = []:
	set(v):
		dross = v
		Sig.ship_changed.emit()

## How much junk, for everything that only wants the number.
func dross_count() -> int:
	return dross.size()

## Lodge one in the ship. `which` names it; empty rolls one against `danger`. Named
## beats rolled so an enemy or event can say what it does to you.
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

## Fields written from many places emit in their setter; heat does not, as it is on the combat hot path.
## Why: docs/why/RunState.md#setters-that-emit

var map: Array = []
var at: int = 0
## Each system's map time is kept so a binary's suns resume where they were when the map reopens.
## Why: docs/why/RunState.md#map-clock
var map_clock: Dictionary = {}

var jumps: int = 0
## The lead ship's jumps, so the Custodian is the same for the whole party, late joiners too.
## Why: docs/why/RunState.md#custodian-jump-count
var party_jumps: int = 0
## Not saved: the save lands before the badge shows, so a saved figure would replay it on CONTINUE.
## Why: docs/why/RunState.md#custodian-jump-count
var custodian_seen: int = 0
var kills: int = 0
## Wall clock at run start, saved with the run: a run spans sessions, so a frame
## counter would only time the last sitting.
var started_at: float = 0.0
var won: bool = false
var dead: bool = false
var death_reason: String = ""

## Counts arrivals from outside only, so unbolting a part never re-offers it as salvage. Not saved.
## Why: docs/why/RunState.md#salvage-rail-dismissal
var hauls: int = 0

## On the run because the screen is rebuilt every jump; unsaved because `hauls` is unsaved.
## Why: docs/why/RunState.md#salvage-rail-dismissal
var salvage_hushed_hauls: int = -1
var salvage_hushed_bag: int = -1


## Asks whether anything is new, not whether the state matches: walking away from a bag is not new.
## Why: docs/why/RunState.md#salvage-rail-dismissal
func salvage_hushed(bag_here: int) -> bool:
	if salvage_hushed_hauls < 0:
		return false
	# Different, not greater: never assume `hauls` only climbs.
	# Why: docs/why/RunState.md#salvage-rail-dismissal
	if hauls != salvage_hushed_hauls:
		return false
	if bag_here >= 0 and bag_here != salvage_hushed_bag:
		return false
	return true

## Work you have taken, in order (see ContractData). Nothing expires or is contested:
## two ships can hold the same job and both be paid. See Contracts.
var contracts: Array = []
## Handed out on acceptance so a contract can be referred to after it is closed.
var next_contract_id: int = 1

## Records where an event quest came from and what it paid; the map stays the truth of what is open.
## Why: docs/why/RunState.md#event-quests
var event_quests: Array = []
## Finished quests in order ("c<id>" contract, "e<at>" event quest) for the COMPLETED rows.
## Saved (VERSION 35); a contract closed under an older save lists after these.
var quests_done: Array[String] = []

## Standing buys better bids and stock, never secrets, and can never be lost.
## Why: docs/why/RunState.md#standing
var standing: Dictionary = {}

## Offered for transfer. Has a setter (see the setters note above) because a site
## outside this file once cleared it without the emit.
var found_hull: HullData = null:
	set(v):
		found_hull = v
		# The pay belongs to the hull it came with, so another hull clears it; the doors that
		# replace a paying frame pay it out first, never this setter.
		found_scrap = {}
		Sig.ship_changed.emit()
## What cutting up the offered hull pays, `{credits, material}`, or empty. Carried with
## the frame, so claiming it and not flying it never costs the strip.
var found_scrap: Dictionary = {}
## Counts yard purchases only, which is what A.S.H.'s New body moment keys on. Not saved.
## Why: docs/why/RunState.md#hulls-bought
var hulls_bought: int = 0
var whale_boon: bool = false
## Read once at run start and saved, so CONTINUE finds the world it left.
## Why: docs/why/RunState.md#unlocked-manufacturers
var unlocked_manufacturers: Array[StringName] = [&"korvan"]

const MAP_CANVAS := Rect2(60, 50, 900, 430)

## A galaxy exists before any run does — screens can be built and asked to draw
## before start_new_run() has rolled one — so it is never an empty dictionary.
func _ready() -> void:
	# WHICH BUILD WROTE THIS LOG, first thing: every `godot.log` a friend sends
	# says what they were playing (`BuildInfo`).
	print("[build] %s" % BuildInfo.line())
	# A dive that is already under way when this machine generates its map — and
	# every claim made while it was generating it.
	Sig.party_map_changed.connect(adopt_party_claims)
	if galaxy.is_empty():
		galaxy = GalaxyGen.params(0).duplicate()
	# On the signal, not at each call site, so removing plating always clamps hull,
	# including ShipScreen's direct edit of `installed`.
	Sig.ship_changed.connect(_clamp_hp)

## Refits move max hull and carry the damage across, so a full ship stays full.
## Why: docs/why/RunState.md#missing-hull-stays-missing
var _hull_seen: HullData = null
var _max_seen := 0

func _clamp_hp() -> void:
	if hull == null:
		return
	var cap := max_hp()
	if hull == _hull_seen and _max_seen > 0 and cap != _max_seen and hp > 0:
		var missing := maxi(0, _max_seen - hp)
		var want := clampi(cap - missing, 1, cap)
		if want != hp:
			hp = want
			Sig.resources_changed.emit()
	elif hp > cap:
		hp = cap
		Sig.resources_changed.emit()
	_hull_seen = hull
	_max_seen = cap

## Empty rolls a manufacturer, so the simulator covers every start and not only Korvan.
## Why: docs/why/RunState.md#starting-a-run
func start_new_run(manufacturer: StringName = &"", w: int = -1) -> void:
	# The seed first: everything below is drawn from it, and it alone replays a run or
	# puts a co-op party in one galaxy. See Rng.
	galaxy_seed = Rng.roll_master()
	# Into the log with the build, so a report names the run AND what ran it.
	# Not for the balance sim, which starts hundreds.
	if not "sim" in OS.get_cmdline_user_args():
		print("[run] new run, seed %d, %s" % [galaxy_seed, BuildInfo.stamp()])
	# Reseeded per seat: one seed gives a party one galaxy, but not one hold. See Rng.seat.
	Rng.reseed(galaxy_seed, Net.seat())
	# What this run's world may hold. Before anything is rolled, and once.
	unlocked_manufacturers = Unlocks.for_new_run()
	# And how hard it is: the ascension level, before the map and the
	# Hellbender, which reads it. See `ascension_for_new_run`.
	ascension = ascension_for_new_run()

	# Random weight for the sim, off a derived generator so picking a ship never moves the map.
	# Why: docs/why/RunState.md#starting-a-run
	var start_rng := Rng.derive(&"start", 0)
	var weight: HullData.Weight = w as HullData.Weight
	if w < 0:
		weight = Rng.pick(start_rng, [HullData.Weight.LIGHT,
			HullData.Weight.MEDIUM, HullData.Weight.HEAVY])
	fit_chassis(manufacturer, weight)
	launched_as = hull.manufacturer
	cargo.clear()
	ship_name = ""
	heat = 0
	heat_cap_bonus = 0
	pad.clear()
	old_hull = null
	_undo_move.clear()
	credits = 40
	# A full tank, which is now a small one. See FUEL_TANK.
	fuel = start_fuel()
	dross = []
	jumps = 0
	party_jumps = 0
	custodian_seen = 0
	kills = 0
	hauls = 0
	contracts.clear()
	next_contract_id = 1
	event_quests = []
	quests_done.clear()
	salvage_hushed_hauls = -1
	salvage_hushed_bag = -1
	# Standing is per run, not a career, so it never becomes the meta-progression
	# `Unlocks` keeps power out of.
	standing.clear()
	# (each system's map clock is this run's: kept by system index, a new run's
	# binary would open its suns where the last run's were left)
	map_clock.clear()
	started_at = Time.get_unix_time_from_system()
	won = false
	dead = false
	death_reason = ""
	found_hull = null
	hulls_bought = 0
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
	# The dish is already on, or a new run's first screen shows no neighbours.
	chart_from(node_at())
	Sig.resources_changed.emit()
	Sig.ship_changed.emit()
	log_line("Reactor cold-started. The core is at least twenty jumps away.", &"big")

## Developer-only reroll of the galaxy under the same ship; contracts drop and co-op refuses.
## Why: docs/why/RunState.md#regenerate-galaxy
func dev_regenerate_galaxy() -> bool:
	if Net.is_networked():
		return false
	var old := galaxy_seed
	galaxy_seed = randi() & 0x7FFFFFFF
	while galaxy_seed == old or galaxy_seed == 0:
		galaxy_seed = randi() & 0x7FFFFFFF
	Rng.reseed(galaxy_seed, Net.seat())
	galaxy_kind = Rng.world.randi() % GalaxyGen.count()
	galaxy = GalaxyGen.roll(galaxy_kind)
	galaxy_spin = Rng.world.randf() * TAU
	galaxy_name = GalaxyGen.roll_name()
	galaxy_title = GalaxyGen.roll_title()
	map = MapGen.generate(MAP_CANVAS)
	contracts.clear()
	event_quests = []
	quests_done.clear()
	_undo_move = {}
	_spawn_hellbender()
	at = 0
	trail = PackedInt32Array([0])
	_range_cache.clear()
	chart_from(node_at())
	Sig.resources_changed.emit()
	Sig.ship_changed.emit()
	log_line("A new galaxy rolled under the ship: %s." % galaxy_name, &"big")
	return true


## Separate from start_new_run so browsing ships never rerolls the world; `tier` is a dev affordance.
## Why: docs/why/RunState.md#fitting-a-chassis
func fit_chassis(manufacturer: StringName = &"",
		w: HullData.Weight = HullData.Weight.MEDIUM, tier: int = 0) -> void:
	var chosen := manufacturer
	if chosen == &"" or not DB.STARTER_WEAPON.has(chosen):
		chosen = Rng.pick(Rng.derive(&"start", 1), DB.STARTABLE)
	hull = DB.at_tier(DB.hull_for(chosen, w) as HullData, tier)
	installed.clear()
	# Only what fits: hardpoints belong to the weight class, and installing past them would
	# hand you a ship the refit screen calls illegal.
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

## How many cells the hold has. Kept under its old name: callers still ask how big the hold is.
func cargo_slots() -> int:
	return hold_grid().x * hold_grid().y

## Cells currently occupied.
func cargo_used() -> int:
	var n := 0
	for m in cargo:
		n += m.cells()
	return n

## Fit is per part on a grid; `leaving` frees a part's cells as it vacates them, so swaps work.
## Why: docs/why/RunState.md#room-in-the-hold
func has_room_for(m: HoldItem, leaving: HoldItem = null) -> bool:
	# A full hold cannot refuse money: credits take no cell.
	if m is CreditChit:
		return true
	return find_hold_slot(m, leaving) != -Vector2i.ONE

## True when nothing at all will fit — the honest replacement for `hold_full`,
## used where there is no particular module in hand.
func hold_full() -> bool:
	# A bare HoldItem, because the question is whether one cell is free.
	var one := HoldItem.new()
	one.size = Vector2i.ONE
	return not has_room_for(one)

## Every cell a part covers at a given origin.
func _cells_of(m: HoldItem, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var f := m.footprint()
	for dy in f.y:
		for dx in f.x:
			out.append(at + Vector2i(dx, dy))
	return out

## Public so drag paths build the occupancy map once instead of once per probed cell.
## Why: docs/why/RunState.md#room-in-the-hold
func hold_taken(m: HoldItem = null, leaving: HoldItem = null) -> Dictionary:
	var taken := {}
	for other in cargo:
		if other == m or other == leaving or other.hold_at.x < 0:
			continue
		for c in _cells_of(other, other.hold_at):
			taken[c] = true
	return taken


## Whether `m` at `at` stays inside the grid and off the `taken` cells.
func fits_at(taken: Dictionary, m: HoldItem, at: Vector2i) -> bool:
	var g := hold_grid()
	if at.x < 0 or at.y < 0:
		return false
	var f := m.footprint()
	if at.x + f.x > g.x or at.y + f.y > g.y:
		return false
	for c in _cells_of(m, at):
		if taken.has(c):
			return false
	return true


## Can `m` sit at `at`, ignoring itself if it is already down?
func can_place(m: HoldItem, at: Vector2i, leaving: HoldItem = null) -> bool:
	return fits_at(hold_taken(m, leaving), m, at)

## The only way into `cargo`: a bare append leaves a part claimed by no cell and drawn nowhere.
## Why: docs/why/RunState.md#doors-into-the-hold
func place_in_hold(m: HoldItem, at: Vector2i = -Vector2i.ONE) -> bool:
	var cell := at if at != -Vector2i.ONE else find_hold_slot(m)
	if cell == -Vector2i.ONE or not can_place(m, cell):
		return false
	m.hold_at = cell
	# Off the pad on the way in, or the item sits in both lists and holds the dock shut.
	pad.erase(m)
	if not cargo.has(m):
		cargo.append(m)
	Sig.ship_changed.emit()
	return true

## Events are measured by snapshot and diff, so the record cannot disagree with the ledger.
## Why: docs/why/RunState.md#event-ledger
func ledger() -> Dictionary:
	return {credits = credits, fuel = fuel, heat = heat, hp = hp}


## The one disposal door, for cargo and the pad, so sell, scrap and jettison all cover both.
## Why: docs/why/RunState.md#doors-into-the-hold
func take_from_hold(m: HoldItem) -> void:
	cargo.erase(m)
	pad.erase(m)
	m.hold_at = -Vector2i.ONE

## One container per kill, never reused: claims are numbered from the slot, so a reused
## slot would inherit the last wreck's claims.
func new_wreck(n: MapGen.MapNode, t: EnemyTemplate, look: int = 0) -> MapGen.Jetsam:
	var h := MapGen.Jetsam.new()
	h.slot = n.jetsam.size()
	h.art = t.id
	h.look = look
	h.label = String(t.name).to_upper()
	h.site = site_here(n)
	n.jetsam.append(h)
	Sig.map_changed.emit()
	return h


## Where your ship is in a system: the body it orbits, -1 star A, STAR_B (-4), or -9 open
## space. A system the map has not flown you round is open space, at its edge.
func site_here(n: MapGen.MapNode = null) -> int:
	if n == null:
		n = node_at()
	if n == null:
		return -9
	return star_site(n, int(SystemMapScreen._parked.get(n.index, {}).get("at", -9)))


## A STAR_B place in a one-sun system is star A, so an older save's ship or wreck
## there is at the star rather than nowhere.
static func star_site(n: MapGen.MapNode, site: int) -> int:
	if site == SystemLayout.STAR_B and not (n.twin and MapGen.twin_ok(n)):
		return -1
	return site


## The wrecks at your ship's place, in death order. Each belongs to its fight's site,
## so the next world along has none of them.
func wrecks_here(n: MapGen.MapNode = null) -> Array:
	if n == null:
		n = node_at()
	var out: Array = []
	if n == null:
		return out
	var site := site_here(n)
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		if h.is_wreck() and (star_site(n, h.site) == site or h.site == MapGen.SITE_ANY):
			out.append(h)
	return out


## A wreck's number among its system's wrecks, in death order: what its death roll and
## marks were keyed on.
func wreck_ordinal(n: MapGen.MapNode, h: MapGen.Jetsam) -> int:
	var k := 0
	for raw in n.jetsam:
		if raw == h:
			return k
		if (raw as MapGen.Jetsam).is_wreck():
			k += 1
	return k


## The system's own pile. Made on demand and kept: a floor with nothing on it is not a container.
func sector_jetsam(n: MapGen.MapNode, make: bool = true) -> MapGen.Jetsam:
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		if not h.is_wreck():
			return h
	if not make:
		return null
	var fresh := MapGen.Jetsam.new()
	fresh.slot = n.jetsam.size()
	n.jetsam.append(fresh)
	return fresh


## SECTOR LOOT: the system's pile plus opened wrecks, as one container (`MapGen.PileView`).
## Null while there is neither.
func sector_loot(n: MapGen.MapNode) -> MapGen.Jetsam:
	if n == null:
		return null
	var pile := sector_jetsam(n, false)
	var v := MapGen.PileView.new()
	v.pile = pile
	if pile != null:
		for i in pile.items.size():
			v.add(pile, i)
	var any := pile != null
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		if h.is_wreck() and h.opened:
			any = true
			for i in h.items.size():
				v.add(h, i)
	if not any:
		return null
	# a wreck's leftovers were seen when it was opened: only the pile can sweep
	v.scanned = pile == null or pile.scanned
	return v


## What is still unclaimed in one container.
func jetsam_left(n: MapGen.MapNode, h: MapGen.Jetsam) -> int:
	if n == null or h == null:
		return 0
	var left := 0
	for i in h.items.size():
		if not n.taken.has(h.option(i)):
			left += 1
	return left


## And across all of them, which is what a button in the sector wants to say.
func loose_here(n: MapGen.MapNode) -> int:
	if n == null:
		return 0
	var left := 0
	for raw in n.jetsam:
		left += jetsam_left(n, raw as MapGen.Jetsam)
	return left


## Take the i-th thing out of a container: the hold is checked before the claim is spent,
## and the claim is awaited because in a party it is a round trip.
func take_from_jetsam(n: MapGen.MapNode, h: MapGen.Jetsam, i: int) -> bool:
	if n == null or h == null or i < 0 or i >= h.items.size():
		return false
	var option := h.option(i)
	if n.taken.has(option):
		return false
	var m: HoldItem = h.items[i]
	if not has_room_for(m):
		log_line("The hold is full. %s stays where it is." % m.name, &"them")
		return false
	if not await take_option(n, option):
		var who := Net.taker_name(n.index, option)
		log_line("%s is already gone.%s" % [m.name,
			" %s took it." % who.to_upper() if who != "" else ""], &"them")
		return false
	stow(m)
	return true


## The icon knows only the item, so finding its container is the bag's job; awaits the claim.
## Why: docs/why/RunState.md#loose-items-and-containers
func take_item(m: HoldItem) -> bool:
	if m == null:
		return false
	var n: MapGen.MapNode = node_at()
	if n == null:
		return false
	# The first unclaimed entry: `find` alone returns a spent one, since taking marks an
	# index. Every container, because the icon does not know which pile.
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		for i in h.items.size():
			if h.items[i] == m and not n.taken.has(h.option(i)):
				return await take_from_jetsam(n, h, i)
	for i in n.bag.size():
		if n.bag[i] == m and not n.taken.has(MapGen.OPTION_BAG + i):
			return await take_from_bag(n, i)
	return false


## A drop goes into the container on screen; `jettison` is this with the floor chosen for you.
## Why: docs/why/RunState.md#loose-items-and-containers
func put_in(n: MapGen.MapNode, h: MapGen.Jetsam, m: HoldItem) -> bool:
	# Either list: the hatch must take a pad item, since it is sometimes that item's only exit.
	if m == null or n == null or h == null:
		return false
	if not cargo.has(m) and not pad.has(m):
		return false
	take_from_hold(m)
	m.hold_at = -Vector2i.ONE
	# Putting back an item already listed clears its claim rather than appending a duplicate.
	# Why: docs/why/RunState.md#loose-items-and-containers
	var already := h.items.find(m)
	if already >= 0:
		# A PackedInt32Array, so remove by position: the reverse of `_mark_taken`.
		var slot := n.taken.find(h.option(already))
		if slot >= 0:
			n.taken.remove_at(slot)
	elif h is MapGen.PileView:
		# onto the real pile, and onto the end of the view showing it
		var v := h as MapGen.PileView
		var real := sector_jetsam(n)
		real.items.append(m)
		v.pile = real
		v.add(real, real.items.size() - 1)
	else:
		h.items.append(m)
	log_line("%s goes overboard. It stays in this system." % m.name, &"sys")
	Sig.ship_changed.emit()
	Sig.map_changed.emit()
	return true


## Overboard to the system's floor: the right-click path has no open container to say
## where you meant.
func jettison(m: HoldItem) -> bool:
	var n: MapGen.MapNode = node_at()
	if n == null:
		return false
	return put_in(n, sector_jetsam(n), m)


## Turning mid-drag mutates the part, so a cancelled drag must reseat it or the hold corrupts.
## Why: docs/why/RunState.md#settling-a-turned-part
func settle(m: HoldItem) -> bool:
	if m == null or not cargo.has(m):
		return false
	if m.hold_at.x >= 0 and can_place(m, m.hold_at):
		return true
	var at := find_hold_slot(m)
	if at != -Vector2i.ONE:
		m.hold_at = at
		Sig.ship_changed.emit()
		return true
	m.turned = not m.turned
	at = find_hold_slot(m)
	if at != -Vector2i.ONE:
		m.hold_at = at
		Sig.ship_changed.emit()
		return true
	m.turned = not m.turned
	return false


## Largest first after the grid shrinks, since first fit strands big parts behind small ones.
## Why: docs/why/RunState.md#repacking-the-hold
func repack_hold() -> void:
	var all := cargo.duplicate()
	# Typed `HoldItem`, not `ModuleData`: the hold carries materials, and a narrower
	# lambda type fails the whole sort at runtime.
	all.sort_custom(func(a: HoldItem, b: HoldItem) -> bool:
		return a.cells() > b.cells())
	cargo.clear()
	var lost: Array[HoldItem] = []
	for m in all:
		m.hold_at = -Vector2i.ONE
	for m in all:
		var cell := find_hold_slot(m)
		if cell == -Vector2i.ONE:
			lost.append(m)
			continue
		m.hold_at = cell
		cargo.append(m)
	# Onto the pad, not overboard: the loader reaches this, and a mismatched save must not lose crates.
	for m in lost:
		pad.append(m)
	if not lost.is_empty():
		log_line("%d thing%s left on the pad. The hold is full." % [lost.size(),
			"" if lost.size() == 1 else "s"], &"them")

## First cell the part fits, row-major, or (-1,-1). First fit, not best fit: a
## predictable rule beats one that rearranges your hold.
func find_hold_slot(m: HoldItem, leaving: HoldItem = null) -> Vector2i:
	var g := hold_grid()
	var taken := hold_taken(m, leaving)
	for y in g.y:
		for x in g.x:
			var at := Vector2i(x, y)
			if fits_at(taken, m, at):
				return at
	return -Vector2i.ONE

## One door for finishing a system, so co-op sharing comes by construction.
## Why: docs/why/RunState.md#claims-in-co-op
func consume_node(n: MapGen.MapNode) -> void:
	take_whole(n)


## Fire and forget: nobody can take these outcomes from you, so a round trip buys nothing.
## Why: docs/why/RunState.md#claims-in-co-op
func take_whole(n: MapGen.MapNode) -> void:
	if n == null or n.cleared:
		return
	n.cleared = true
	_mark_taken(n, MapGen.OPTION_WHOLE)
	Net.claim(n.index, MapGen.OPTION_WHOLE)


## Must wait for the party's answer, or two ships both roll the same loot.
## Why: docs/why/RunState.md#claims-in-co-op
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


## Rolled positionally so every machine rolls the same bag; only what is gone travels.
## Why: docs/why/RunState.md#the-shared-bag
func open_bag(n: MapGen.MapNode, drops: int, hands: int) -> void:
	if n == null or n.bagged or drops <= 0:
		return
	n.bagged = true
	var r := Rng.derive(&"bag", n.index)
	var force := n.manufacturer if n.region == MapGen.Region.TERRITORY else &""
	# Scaled by the crew, so bringing a friend does not halve the fight's worth to you.
	# The enemy was built for the party (`PartyScale`); this is the other side of that bargain.
	for i in drops * maxi(1, hands):
		n.bag.append(LootGen.roll_module(n.danger, force,
			n.region == MapGen.Region.DEEP, r))
	Sig.map_changed.emit()


## Asks and waits, and checks the hold before claiming so a full hold never burns a part.
## Why: docs/why/RunState.md#the-shared-bag
func take_from_bag(n: MapGen.MapNode, i: int) -> bool:
	if n == null or i < 0 or i >= n.bag.size():
		return false
	var option := MapGen.OPTION_BAG + i
	if n.taken.has(option):
		return false
	# A HoldItem: jettison puts materials in the same bag a kill fills.
	var m: HoldItem = n.bag[i]
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


## What is LEFT for you here, not what was rolled, so the rail can tell an emptied bag.
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


## The party's claims applied to this map, the whole list each time: idempotent, and
## a rebuilt list cannot drift the way deltas can.
func adopt_party_claims() -> void:
	if map.is_empty():
		return
	var moved := false
	for key in Net.claims:
		var i := int(key)
		# Cannot happen with a shared seed; checked so a bad index never takes the chart down.
		if i < 0 or i >= map.size():
			continue
		var n: MapGen.MapNode = map[i]
		for option in Net.claims[key]:
			var o := int(option)
			if n.taken.has(o):
				continue
			# A partner's own option is not mine, so its claim must not close my option at that index.
			# Why: docs/why/RunState.md#adopting-party-claims
			if o >= MapGen.OPTION_SITE and o < MapGen.OPTION_JETSAM and not n.options.is_empty():
				var k := o - MapGen.OPTION_SITE
				if k >= n.options.size() or OptionTable.is_mine(n.options[k]):
					continue
			n.taken.append(o)
			moved = true
			if o == MapGen.OPTION_WHOLE:
				n.cleared = true
			elif o >= MapGen.OPTION_SITE and o - MapGen.OPTION_SITE < n.options.size():
				# Foreclosure is derived on every machine from the same claim, never sent.
				# Why: docs/why/RunState.md#adopting-party-claims
				OptionTable.foreclose(n, o - MapGen.OPTION_SITE)
	if moved:
		Sig.map_changed.emit()


## Returns whether it took the part, and callers must care; forced moves never come through here.
## Why: docs/why/RunState.md#doors-into-the-hold
func stow(m: HoldItem) -> bool:
	# Money is cashed, not placed. Every route into the hold runs through here, so this
	# one branch covers all of them.
	if m is CreditChit:
		var chit := m as CreditChit
		add_credits(chit.amount)
		log_line("%d credits aboard." % chit.amount, &"good")
		hauls += 1
		Sig.ship_changed.emit()
		return true
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

## Fills spare mounts until the deck outgrows the hand, distinct parts first.
## Why: docs/why/RunState.md#topping-up-the-deck
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

## Gauges sum chassis and modules, so an attribute reads what combat uses; `bare` is chassis alone.
## Why: docs/why/RunState.md#gauges
func max_hp(bare: bool = false) -> int:
	var n := hull.max_hull
	if not bare:
		for m in installed:
			n += m.max_hull + m.affix_int(&"max_hull")
	return maxi(1, n)

func heat_cap(bare: bool = false) -> int:
	# `heat_cap_bonus` has no setter left but is saved; retiring it needs a save version bump.
	var n := hull.heat_cap + heat_cap_bonus
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

## Capped at 0.6: dodge is the enemy's miss chance, and an uncapped sum is a ship nothing can hit.
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
	# After the modules: a discount on what the ship burns. Small and floored, because
	# this prices every jump.
	if hull.has_perk(&"deep_tanks"):
		v *= 0.9
	return maxf(0.3, v)

## Heat sheds half a turn's worth per jump (floor one): it matters between fights, but no free vent.
## Why: docs/why/RunState.md#cooling-in-transit
func cool_in_transit() -> void:
	# Half rate measured better than full rate (Aug 25), and this rate is not the lever.
	# Why: docs/why/RunState.md#cooling-in-transit
	heat = maxi(0, heat - maxi(1, int(dissipation() / 2.0)))

## How loud you are: 0 cold, 1 at capacity. Map rules ask this, not raw heat, which
## is not comparable across hulls.
func signature() -> float:
	return float(heat) / float(maxi(1, heat_cap()))

## Below this fraction of capacity nothing finds you: running cold buys silence, not a low roll.
const SIGNATURE_FLOOR := 0.25
## Odds at capacity, on unclaimed ground, in a ship with no stealth at all.
const AMBUSH_AT_CAP := 0.30

## Signature gates it, danger scales it, and stealth divides it last.
## Why: docs/why/RunState.md#ambush-chance
func ambush_chance(n: MapGen.MapNode) -> float:
	var sig := signature()
	# STUDY ONLY (`study_ambush_deep`, balance/run-length): off unless set.
	if study_ambush_deep > 0.0 and n.danger > 6:
		var floor_p := study_ambush_deep * float(n.danger - 6)
		if sig <= SIGNATURE_FLOOR:
			return clampf(floor_p, 0.0, 0.6)
	if sig <= SIGNATURE_FLOOR:
		return 0.0
	var p := AMBUSH_AT_CAP * (sig - SIGNATURE_FLOOR) / (1.0 - SIGNATURE_FLOOR)
	p *= 1.0 + float(n.danger - 1) * 0.08
	# Clamped here: stealth over ten would push the ambush probability below zero.
	p *= 1.0 - minf(1.0, float(attr_stealth()) / float(ATTR_MAX)) * AMBUSH_RELIEF
	if study_ambush_deep > 0.0 and n.danger > 6:
		p = maxf(p, study_ambush_deep * float(n.danger - 6))
	return clampf(p, 0.0, 0.6)

## The level is the stat; cells and energy are read off it by arithmetic with no ceiling.
## Why: docs/why/RunState.md#reactor-level
const CELLS_PER_LEVEL := 3


## The reactor level: hull grade plus every part that raises it. Floored at 0, not capped.
func reactor_level(bare: bool = false) -> int:
	var n := hull.reactor
	if not bare:
		for m in installed:
			n += m.reactor + m.affix_int(&"reactor")
	return maxi(0, n)


## Energy a turn: a step every second level from 3 at REACTOR 4, plus direct grants kept
## flat, so a bonus never lands between steps and does nothing.
func reactor() -> int:
	var e := maxi(1, 3 + floori(float(reactor_level() - 4) / 2.0))
	if hull.has_perk(&"overspec_reactor"):
		e += 1
	if has_set(&"verity", 5):
		e += 1
	return e


func power_cap() -> int:
	return reactor_level() * CELLS_PER_LEVEL

## Draw in cells, the same unit the hold counts a part in, so the game's two halves agree.
func power_draw() -> int:
	var d := 0
	for m in installed:
		d += m.cells()
	return d

## A mount and reactor capacity are separate questions; `replacing` frees its draw for swaps.
## Why: docs/why/RunState.md#mounts-and-the-reactor
func can_power(m: ModuleData, replacing: ModuleData = null) -> bool:
	if m == null:
		return false
	var draw := power_draw() + m.cells()
	# The cap with this part on, since a coupling raises the level it is measured against.
	var level := reactor_level() + m.reactor + m.affix_int(&"reactor")
	if replacing != null:
		draw -= replacing.cells()
		# (its affix's share too, as `reactor_level` counts it)
		level -= replacing.reactor + replacing.affix_int(&"reactor")
	var cap := maxi(0, level) * CELLS_PER_LEVEL
	return draw <= cap

## Dev override from `-- fight N`; 0 uses the real value. Lives here so Combat's
## redraw each turn honours it too.
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
	# No perk adds a mount: a mount is a place on the hull that somebody rigged by hand.
	return hull.slots_for(s)

func slots_used(s: ModuleData.Slot) -> int:
	var n := 0
	for m in installed:
		if m.slot == s:
			n += 1
	return n

## The hull counts toward its manufacturer's set, which makes the chassis a build decision.
## Why: docs/why/RunState.md#manufacturer-count
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

# Attributes are functions of tracked state, never fields, so checks read current values.
# Why: docs/why/RunState.md#attributes

## Ten is how many cells the bar draws, not a ceiling: each consumer caps its own use.
## Why: docs/why/RunState.md#attributes
const ATTR_MAX := 10

## The most stealth can take off an ambush. Named because the tooltip quotes it.
const AMBUSH_RELIEF := 0.6

## A fixed reference so frame size and damage both count; 70 leaves the biggest hull room to grow.
## Why: docs/why/RunState.md#hull-reference
const HULL_REF := 70.0

## Hull reads current hp; the bare reading caps at the bare frame's max, so hull
## above that shows as the plating's.
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

## Dodge is the bulk, initiative tilts it. The +1 floor keeps a warship from reading
## the same as an ore barge.
func attr_maneuver(bare: bool = false) -> int:
	# 0.5 on initiative, so half a pip is one whole point of an int field.
	return maxi(0, int(round(dodge(bare) * 23.0 + initiative(bare) * 0.5 + 1.5)))

## Capacity weighs most and a floor is subtracted, so hulls spread out and only Solari reads 6.
## Why: docs/why/RunState.md#thermal
const THERMAL_FLOOR := 8.0

## Three cells a pip, named because a coupling is priced in it.
## Why: docs/why/RunState.md#reactor-level
const CELLS_PER_PIP := 3.0

## The attribute is the reactor level itself: the only gauge whose raw unit is on screen.
## Why: docs/why/RunState.md#reactor-level
func attr_reactor(bare: bool = false) -> int:
	return maxi(0, reactor_level(bare))


func attr_thermal(bare: bool = false) -> int:
	# Whole divisors, so one point of capacity or vent is exactly half a pip.
	# Why: docs/why/RunState.md#thermal
	var v := (heat_cap(bare) - THERMAL_FLOOR) / 2.0 + dissipation(bare) / 2.0
	return maxi(0, int(round(v)))

## Scale 1 so a part's pips land exactly; sensors and stealth become axes you build.
## Why: docs/why/RunState.md#sensors-and-stealth
const SENSE_SCALE := 1.0

## Clamped at zero: these two are summed raw, so a priced part could push them negative.
## Why: docs/why/RunState.md#sensors-and-stealth
func attr_sensors(bare: bool = false) -> int:
	var n := hull.sensors
	if not bare:
		for m in installed:
			n += m.sensors + m.affix_int(&"sensors")
	return maxi(0, int(round(n * SENSE_SCALE)))

## Heat takes up to 4 stealth at capacity, since heat is the one thing you cannot cover.
## Why: docs/why/RunState.md#sensors-and-stealth
const HEAT_STEALTH_COST := 4.0

func attr_stealth(bare: bool = false) -> int:
	var n := hull.stealth
	if not bare:
		for m in installed:
			n += m.stealth + m.affix_int(&"stealth")
	# Heat applies to both readings: heat is not fitted, so the loss must not look like a module's.
	var v := float(n) * SENSE_SCALE - signature() * HEAT_STEALTH_COST
	return maxi(0, int(round(v)))

## One pip's cost in raw units, inverted from the formulas above; `-- attrtest` checks they agree.
## Why: docs/why/RunState.md#pip-costs
const PER_PIP := {
	&"hull": {&"max_hull": 7.0},                       ## HULL_REF / ATTR_MAX
	&"thermal": {&"heat_cap": 1.0, &"dissipation": 1.0},
	# Dodge alone: nothing in combat reads initiative, so a maneuver pip must buy dodge.
	# Why: docs/why/RunState.md#pip-costs
	&"maneuver": {&"dodge": 1.0 / 23.0},
	&"sensors": {&"sensors": 1.0},
	&"stealth": {&"stealth": 1.0},
	# Reactor and thrust pips are one for one.
	# Why: docs/why/RunState.md#pip-costs
	&"reactor": {&"reactor": 1.0},
	&"thrust": {&"thrust": 1.0},
}

## Short and full gauge names are spelled once; the short forms fit a 93 px card readout.
## Why: docs/why/RunState.md#gauge-names
const ATTR_LABEL := {
	&"hull": "HULL",
	&"reactor": "REACTOR",
	&"thrust": "THRUST",
	&"maneuver": "MANEUVERABILITY",
	&"thermal": "THERMAL",
	&"sensors": "SENSORS",
	&"stealth": "STEALTH",
}

const ATTR_SHORT := {
	&"hull": "HUL",
	&"reactor": "RCT",
	&"thrust": "THR",
	&"maneuver": "MNV",
	&"thermal": "THM",
	&"sensors": "SEN",
	&"stealth": "STL",
}

## Stands the hull in for one call so the formulas are not copied; emits and saves nothing.
## Why: docs/why/RunState.md#bare-hull-attributes
func hull_attributes(h: HullData) -> Array[Dictionary]:
	if h == null:
		return []
	var was_hull := hull
	var was_installed := installed
	var was_hp := hp
	hull = h
	installed = []
	# At full: a hull on the blocks has not been shot at, and your damage must not price it.
	hp = h.max_hull
	var out := attributes()
	hull = was_hull
	installed = was_installed
	hp = was_hp
	return out


func attributes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{key = &"hull", label = ATTR_LABEL[&"hull"], short = ATTR_SHORT[&"hull"],
			value = attr_hull(), base = attr_hull(true),
			# THE HULL THE PIPS ARE ROUNDED FROM, for a block that prints it
			# beside them (`AttrBlock.setup`'s `amounts`; ruling 12 C).
			amount = "%d hull" % hp,
			text = "Used for ramming, boarding and holding together under stress.",
			# Says about 7 and does the sum on your hull, because the pips are rounded.
			# Why: docs/why/RunState.md#hull-pip-wording
			effect = "A pip is about %d hull. Your %d hull rounds to %d %s. This gauge reads CURRENT hull, so damage lowers it until you repair." % [
				int(round(HULL_REF / ATTR_MAX)), hp, attr_hull(),
				"pip" if attr_hull() == 1 else "pips"]},
		{key = &"reactor", label = ATTR_LABEL[&"reactor"], short = ATTR_SHORT[&"reactor"],
			value = attr_reactor(), base = attr_reactor(true),
			text = "Energy to spend in a fight, and hardware the ship can run.",
			# The only gauge no event check reads. It pays in combat instead.
			effect = "A pip is %d more cells of hardware. Energy rises every second pip." % CELLS_PER_LEVEL},
		{key = &"thrust", label = ATTR_LABEL[&"thrust"], short = ATTR_SHORT[&"thrust"],
			value = attr_thrust(), base = attr_thrust(true),
			text = "Used for outrunning, breaking orbit and escaping a gravity well.",
			# The jump range is a FIXED distance now, so this is a plain
			# percentage of a known number rather than of a local accident.
			effect = "A pip is %d%% further travel on the starchart, to a maximum of %d%%, and costs no extra fuel."
				% [int(round(THRUST_REACH * 100.0)),
					int(round((THRUST_REACH_MAX - 1.0) * 100.0))]},
		{key = &"maneuver", label = ATTR_LABEL[&"maneuver"], short = ATTR_SHORT[&"maneuver"],
			value = attr_maneuver(), base = attr_maneuver(true),
			text = "Used for threading debris, evading a lock and breaking contact.",
			# Only the dodge half of a maneuver pip does anything, so the text quotes dodge alone.
			effect = "A pip is about 4% of enemy attacks missing outright."},
		{key = &"thermal", label = ATTR_LABEL[&"thermal"], short = ATTR_SHORT[&"thermal"],
			value = attr_thermal(), base = attr_thermal(true),
			text = "Used for sitting in heat, such as coronas and hot reactors.",
			effect = "A pip is 1 more heat capacity, and 1 more heat off every vent card you play."},
		{key = &"sensors", label = ATTR_LABEL[&"sensors"], short = ATTR_SHORT[&"sensors"],
			value = attr_sensors(), base = attr_sensors(true),
			text = "Used for reading wrecks, finding lanes and spotting threats first.",
			# Sight is the gate for jumping, so a sensors pip is priced against the starchart.
			effect = "A pip is %d%% further sight on the starchart. You can only jump to systems you can see."
				% int(round(SENSE_REACH * 100.0))},
		{key = &"stealth", label = ATTR_LABEL[&"stealth"], short = ATTR_SHORT[&"stealth"],
			value = attr_stealth(), base = attr_stealth(true),
			text = "Used for going dark, slipping past patrols and arriving unseen.",
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
	# The hold carries materials too, and a material has no `contraband`: reading
	# it crashed every inspection of a hold with ore in it (Oct 18, the fuel sims)
	for m in cargo:
		if m is ModuleData and m.contraband:
			n += 1
	return n

## What one hull point costs to fix here: local, since work is dear on the frontier.
## Market owns the number.
func repair_cost_per_hull() -> float:
	return Market.repair_rate(here())

## What a part melts down to: the floor under every price, below any station's. See Market.gd.
func scrap_value_of(m: ModuleData) -> int:
	return Market.melt(m)

# --------------------------------------------------------------------- materials

## Counted off the hold's objects; a separate tally was a second store for one fact.
## Why: docs/why/RunState.md#materials
func material(id: StringName) -> int:
	var n := 0
	for raw in cargo:
		var m := raw as MaterialData
		if m != null and m.id == id:
			n += 1
	return n


## Grants go into the system as a container, so a full hold can refuse a reward without losing it.
## Every material is paid: an n-player game puts `PartyScale.pay(n)` of them in the system.
## Why: docs/why/RunState.md#materials
func add_material(id: StringName, n: int) -> Array[MaterialData]:
	var made: Array[MaterialData] = []
	var row := MaterialTable.by_id(id)
	if row.is_empty() or n <= 0:
		return made
	n = PartyScale.pay(n)
	for i in n:
		made.append(MaterialData.of(row))
	var here := node_at()
	if here != null:
		for m in made:
			sector_jetsam(here).items.append(m)
		Sig.map_changed.emit()
	Sig.resources_changed.emit()
	return made


## Take some off the hold. False, and nothing moves, if you are not carrying
## enough -- a recipe that half-charged you would be worse than one that refused.
func spend_material(id: StringName, n: int) -> bool:
	var found: Array[HoldItem] = []
	for raw in cargo:
		var m := raw as MaterialData
		if m != null and m.id == id:
			found.append(m)
			if found.size() >= n:
				break
	if found.size() < n:
		return false
	for m2 in found:
		take_from_hold(m2)
	Sig.resources_changed.emit()
	return true


## Spend one material of this tier; which one is the hold's choice, not the option's.
func spend_material_tier(tier: StringName) -> bool:
	for raw in cargo:
		var m := raw as MaterialData
		if m != null and m.tier == tier:
			take_from_hold(m)
			Sig.resources_changed.emit()
			return true
	return false

## Everything carried, in table order, as {id, name, count}: one list, so the HUD,
## the station and the fabricator agree.
func material_stock() -> Array[Dictionary]:
	# One pass over the hold, then the table: per-row counting rescanned cargo every HUD refresh.
	var counts: Dictionary = {}
	for raw in cargo:
		var m := raw as MaterialData
		if m != null:
			counts[m.id] = int(counts.get(m.id, 0)) + 1
	var out: Array[Dictionary] = []
	for d in MaterialTable.all():
		var n: int = counts.get(d.id, 0)
		if n > 0:
			out.append({id = d.id, name = str(d.name), count = n})
	return out

# --------------------------------------------------------------------- mutations

## Lives here so the simulator can run it; the drop is named once so nothing drifts.
## Why: docs/why/RunState.md#pulsar-harvest
const PULSAR_DROP := &"magnetar_silt"

func harvest_pulsar() -> void:
	var n := node_at()
	if n.cleared:
		return
	take_whole(n)
	# Scales with danger: a deep pulsar is a better haul and a worse idea. About half a
	# tank (Jon, Oct 17: "pulsar:C"); the setter keeps it under the top.
	var gain_fuel := 14 + n.danger
	var gain_exotic := 1 + int(n.danger / 4)
	var burn := 6 + int(n.danger * 1.6)
	var gain_heat := 3 + int(n.danger / 3)

	fuel += gain_fuel
	# The drop lands in the system and has a real name, not the placeholder Exotic.
	# Why: docs/why/RunState.md#pulsar-harvest
	# (in a party's game more is made, `PartyScale`: the line says what was)
	var adrift := add_material(PULSAR_DROP, gain_exotic).size()
	heat += gain_heat
	log_line("Beam sweep. Fuel pours into the tank for eleven seconds.", &"good")
	# The name comes off the table rather than being written here twice.
	var silt: Dictionary = MaterialTable.by_id(PULSAR_DROP)
	log_line("+%d fuel, and %d %s adrift alongside." % [gain_fuel, adrift,
		String(silt.get("name", "exotic")).to_lower()], &"good")
	log_line("Hard radiation through the hull. +%d heat." % gain_heat, &"them")
	Sig.resources_changed.emit()
	# Last: it can end the run, and everything above has to have happened first.
	# Dying with the fuel aboard is the point of the trade.
	take_hull_damage(burn, "A neutron star's beam killed the crew. The hull held.")

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

## Clears the rail's dismissal, and cuts up a frame still on offer so its pay is not lost.
## Why: docs/why/RunState.md#found-hulls
func find_hull(h: HullData, scrap: Dictionary = {}) -> void:
	if h != found_hull:
		scrap_found_hull()
	found_hull = h
	found_scrap = scrap.duplicate() if h != null else {}
	salvage_hushed_hauls = -1
	salvage_hushed_bag = -1
	Sig.ship_changed.emit()


## What SCRAP on the hull on offer pays in credits, or 0 when it has no SCRAP.
func found_scrap_credits() -> int:
	if found_hull == null or found_scrap.is_empty():
		return 0
	return int(found_scrap.get("credits", 0))


## Pays once, the crate to SECTOR LOOT, and the log says where it went.
## Why: docs/why/RunState.md#found-hulls
func scrap_found_hull() -> bool:
	if found_scrap_credits() <= 0:
		return false
	var pay := found_scrap.duplicate()
	var what := found_hull.display_name()
	found_hull = null
	add_credits(int(pay.get("credits", 0)))
	var said := "Scrapped the %s for %d credits." % [what, int(pay.get("credits", 0))]
	var mat := StringName(pay.get("material", &""))
	if mat != &"":
		var made := add_material(mat, 1)
		if made.size() == 1 and node_at() != null:
			said += " A crate of %s is in SECTOR LOOT." % made[0].name
		elif made.size() > 1 and node_at() != null:
			# (a party's game makes one a player, `PartyScale`)
			said += " %d crates of %s are in SECTOR LOOT." % [made.size(), made[0].name]
	log_line(said, &"good")
	return true


## The mutation emits `ship_changed` itself, once, so the gauge never shows the old cap.
## Why: docs/why/RunState.md#heat-cap-upgrades
func add_heat_cap(n: int) -> void:
	heat_cap_bonus += n
	Sig.ship_changed.emit()

func die(reason: String) -> void:
	dead = true
	death_reason = reason
	Sig.run_ended.emit(false, reason)

func win() -> void:
	won = true
	Sig.run_ended.emit(true, "You reach the core.")

## One place a hand moves parts between hold, dock and mounts, so every screen agrees.
## Why: docs/why/RunState.md#the-refit-rule
enum Refit { REFUSED, MOVED, FITTED }


## Off the ship, into the hand. Returns the mount it came off (-1: not fitted).
func lift_part(m: ModuleData) -> int:
	if m == null or not installed.has(m):
		return -1
	var was := m.mount
	installed.erase(m)
	m.mount = -1
	Sig.ship_changed.emit()
	return was


## A lifted part that never landed goes back exactly where it was: picking a
## thing up is not a decision to get rid of it.
func unlift_part(m: ModuleData, mount: int) -> void:
	if m == null or installed.has(m) or cargo.has(m):
		return
	m.mount = mount
	installed.append(m)
	Sig.ship_changed.emit()


## `m` dropped on hardpoint `index` of `slot`; `lifted_from` is its mount, or -1.
## The mount is a place, so `index` is carried to the part.
func fit_at_mount(m: ModuleData, slot: ModuleData.Slot, index: int, lifted_from: int = -1) -> Refit:
	# THE GATE IS `refit_allowed`, the one the hull asks while a part is carried
	# (`MountPoints.takes`): what it lights is what this does, by construction.
	if not refit_allowed(m, slot, index, lifted_from):
		var was := module_at(slot, index) if m != null and m.slot == slot else null
		if was != null and was == m:
			return Refit.REFUSED
		if m != null and m.slot == slot and not _refit_powered(m, was, lifted_from):
			log_line("The reactor cannot carry %s." % m.name, &"them")
		elif was != null:
			log_line("No room in the hold for %s." % was.name, &"them")
		return Refit.REFUSED
	var resident := module_at(slot, index)
	# Two fitted parts trade mounts, and a part in the hand counts as fitted.
	# Why: docs/why/RunState.md#the-refit-rule
	var lifted := lifted_from >= 0 and not installed.has(m)
	var was_fitted := installed.has(m) or lifted
	if resident != null and was_fitted:
		var there := lifted_from if lifted else m.mount
		m.mount = index
		resident.mount = there
		if lifted:
			installed.append(m)
		Sig.ship_changed.emit()
		log_line("Moved %s." % m.name, &"sys")
		return Refit.MOVED
	# Refused before anything moves if the resident cannot fit the hold, with `m`'s cells counted free.
	# Why: docs/why/RunState.md#the-refit-rule
	var was_at := m.hold_at
	if cargo.has(m):
		take_from_hold(m)
	if resident != null:
		installed.erase(resident)
		resident.mount = -1
		if not place_in_hold(resident):
			# Cannot happen -- has_room_for said yes a moment ago and nothing has
			# taken cells since. Put everything back rather than trust that.
			resident.mount = index
			installed.append(resident)
			if was_at.x >= 0:
				place_in_hold(m, was_at)
			log_line("No room in the hold for %s." % resident.name, &"them")
			return Refit.REFUSED
	installed.erase(m)
	m.mount = index
	installed.append(m)
	Sig.ship_changed.emit()
	log_line("Fitted %s." % m.name, &"good")
	return Refit.FITTED


## The refit yes or no: matching kind, a trade or hold room, and reactor capacity.
## Why: docs/why/RunState.md#the-refit-rule
func refit_allowed(m: ModuleData, slot: ModuleData.Slot, index: int, lifted_from: int = -1) -> bool:
	# STAYS a ModuleData, and that is the guard. A mount is a hardpoint on the
	# hull; a crate of ore has no slot to match and no power to draw.
	if m == null or m.slot != slot:
		return false
	var resident := module_at(slot, index)
	if resident != null and resident == m:
		return false
	if not _refit_powered(m, resident, lifted_from):
		return false
	if resident == null:
		return true
	var lifted := lifted_from >= 0 and not installed.has(m)
	if installed.has(m) or lifted:
		return true
	return has_room_for(resident, m)


## The reactor half of `refit_allowed`: a part already aboard draws nothing new, and
## a displaced resident frees its draw.
func _refit_powered(m: ModuleData, resident: ModuleData, lifted_from: int) -> bool:
	if installed.has(m) or lifted_from >= 0:
		return true
	return can_power(m, resident)


## Separate from fit_at_mount: the hold asks whether this shape fits here.
## Why: docs/why/RunState.md#the-refit-rule
func stow_at(m: HoldItem, at: Vector2i, lifted: bool = false) -> bool:
	if m == null:
		return false
	var was_at := m.hold_at
	# (only a module can be on the ship; asked of a crate, the typed list complains)
	var from_ship := (m is ModuleData and installed.has(m as ModuleData)) or lifted
	# Off the dock is a third origin: the pad is not cargo, so it needs its own removal.
	var from_pad := pad.has(m)
	if from_pad:
		pad.erase(m)
	elif cargo.has(m):
		take_from_hold(m)
	if not place_in_hold(m, at):
		# A refused drop costs nothing: back on the dock, or back exactly where it
		# was in the hold (a part off the ship stays in the hand for its caller).
		if from_pad:
			pad.append(m)
		elif not from_ship and was_at.x >= 0:
			place_in_hold(m, was_at)
		return false
	if from_ship and m is ModuleData:
		installed.erase(m as ModuleData)
		(m as ModuleData).mount = -1
		log_line("Stowed %s." % m.name, &"sys")
	Sig.ship_changed.emit()
	return true


## No mount clears the worst part in that slot; no capacity clears the worst part anywhere.
## Why: docs/why/RunState.md#mounts-and-the-reactor
func install_module(m: ModuleData) -> void:
	if slots_used(m.slot) >= slots_for(m.slot):
		var worst: ModuleData = null
		for x in installed:
			if x.slot == m.slot and (worst == null or x.scrap_value < worst.scrap_value):
				worst = x
		if worst != null:
			installed.erase(worst)
			worst.mount = -1
			# `m`'s cells just freed up, so this should not fail; if it does, drop rather than duplicate.
			if not place_in_hold(worst):
				log_line("No room for %s. It was left behind." % worst.name, &"them")
			log_line("Removed %s to make room." % worst.name, &"sys")
	# Then the reactor: cheapest first, only as many as it takes. Guarded, so a part
	# bigger than the reactor cannot strip every mount.
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
		log_line("Shut down %s. The reactor cannot carry both." % dim.name, &"sys")
	take_from_hold(m)
	m.mount = free_mount(m.slot)
	installed.append(m)
	log_line("Installed %s." % m.name, &"good")
	Sig.ship_changed.emit()

## Take a part off. Refused when the hold is full, rather than destroying the part.
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

## Scrap only: parts no longer yield alloy, which acted as a second currency.
## Why: docs/why/RunState.md#scrapping
func scrap_module(m: ModuleData) -> void:
	var v := scrap_value_of(m)
	take_from_hold(m)
	add_credits(v)
	log_line("Scrapped %s for %d credits." % [m.name, v], &"good")
	Sig.ship_changed.emit()

## Everything comes off and you re-rig it, because only you know which parts you want.
## Why: docs/why/RunState.md#moving-ships
func transfer_to_hull(h: HullData, paid: int = 0,
		node: MapGen.MapNode = null) -> void:
	# The old ship keeps everything until a hand moves it, so the screen shows it as it was.
	# Why: docs/why/RunState.md#moving-ships
	if h != found_hull:
		scrap_found_hull()
	old_hull = hull
	# The way back, taken before anything moves: every part's mount and crate's cell,
	# plus the frame and its hull points.
	var places: Dictionary = {}
	for m in installed:
		places[m] = [m.mount, m.hold_at]
	for m in cargo:
		# A crate has no mount: reading `mount` off a MaterialData is a hard error mid-swap.
		var mod := m as ModuleData
		places[m] = [mod.mount if mod != null else -1, m.hold_at]
	_undo_move = {
		hull = hull,
		hp = hp,
		paid = paid,
		node = node,
		places = places,
		# A found hull goes back on the rail if the move is called off.
		found = found_hull,
		# And with what it cuts up for, so backing out keeps its SCRAP.
		scrap = found_scrap.duplicate(),
	}

	pad.clear()
	pad.append_array(installed)
	pad.append_array(cargo)
	installed.clear()
	cargo.clear()

	var ratio := float(hp) / float(max_hp())
	hull = h
	hp = maxi(6, int(round(h.max_hull * ratio)))
	# Bought off a station's rack (the yard passes its node); a found hull is not.
	if node != null:
		hulls_bought += 1

	found_hull = null
	var said: Array[String] = []
	for pid in h.perks():
		said.append(DB.perk_text(pid))
	log_line("Transferred to %s. %s" % [h.display_name(), " ".join(said)], &"big")
	if not pad.is_empty():
		log_line("%d thing%s still aboard the %s." % [pad.size(),
			"" if pad.size() == 1 else "s", old_hull.name], &"them")
	Sig.ship_changed.emit()
	Sig.resources_changed.emit()


## Whether the move can still be called off.
func can_abandon_move() -> bool:
	return not _undo_move.is_empty() and old_hull != null


## Restores what still exists, not what you sold or dumped; in co-op a stale refusal can remain.
## Why: docs/why/RunState.md#moving-ships
func abandon_move() -> void:
	if not can_abandon_move():
		return
	var places: Dictionary = _undo_move.get("places", {})
	var mine: Array[HoldItem] = []
	mine.append_array(pad)
	mine.append_array(installed)
	mine.append_array(cargo)

	installed.clear()
	cargo.clear()
	pad.clear()
	for it in mine:
		if not places.has(it):
			# Acquired during the move (nothing does this today); kept on the pad, not lost.
			pad.append(it)
			continue
		var was: Array = places[it]
		var mod := it as ModuleData
		if mod != null and int(was[0]) >= 0:
			mod.mount = int(was[0])
			mod.hold_at = -Vector2i.ONE
			installed.append(mod)
			continue
		it.hold_at = was[1]
		if mod != null:
			mod.mount = -1
		cargo.append(it)

	hull = _undo_move.get("hull", hull)
	hp = int(_undo_move.get("hp", hp))
	add_credits(int(_undo_move.get("paid", 0)))
	var n: MapGen.MapNode = _undo_move.get("node", null)
	if n != null:
		n.taken.erase(MapGen.OPTION_SHOP_HULL)
	var found: HullData = _undo_move.get("found", null)
	if found != null:
		found_hull = found
		found_scrap = (_undo_move.get("scrap", {}) as Dictionary).duplicate()
	# `display_name`, so a named ship is called by its name, not its chassis.
	log_line("Changed your mind. Still flying the %s." % display_name(), &"them")
	old_hull = null
	_undo_move.clear()
	Sig.ship_changed.emit()
	Sig.resources_changed.emit()
	Sig.map_changed.emit()


## Old mount to new mount directly, so a full hold never blocks a free hardpoint.
## Why: docs/why/RunState.md#moving-ships
func pad_to_mount(m: ModuleData, slot: ModuleData.Slot, index: int) -> bool:
	if m == null or not pad.has(m) or m.slot != slot:
		return false
	if not can_power(m):
		return false
	if module_at(slot, index) != null:
		return false
	if index < 0 or index >= slots_for(slot):
		return false
	pad.erase(m)
	m.hold_at = -Vector2i.ONE
	m.mount = index
	installed.append(m)
	Sig.ship_changed.emit()
	return true



## Carry one thing off the pad and into the hold. False if there is no room.
func pad_to_hold(m: HoldItem) -> bool:
	if not pad.has(m):
		return false
	var cell := find_hold_slot(m)
	if cell == -Vector2i.ONE:
		return false
	pad.erase(m)
	m.hold_at = cell
	# Clear the old mount: a stowed part still claiming one would be in the hold and fitted at once.
	var mod := m as ModuleData
	if mod != null:
		mod.mount = -1
	cargo.append(m)
	Sig.ship_changed.emit()
	return true


## Undocking needs an empty pad and a deck bigger than the hand, since a swap empties the deck.
## Why: docs/why/RunState.md#ready-to-fly
func ready_to_fly() -> Array[String]:
	var why: Array[String] = []
	if not pad.is_empty():
		why.append("%d thing%s still on the pad" % [pad.size(),
			"" if pad.size() == 1 else "s"])
	if deck_size() < hand_size():
		why.append("deck of %d is smaller than a hand of %d"
			% [deck_size(), hand_size()])
	return why


## Puts right a loaded ship that an older build stranded, and drops nothing.
## Why: docs/why/RunState.md#mending-a-loadout
func mend_loadout() -> int:
	var moved := 0
	var seen := {}
	var astray: Array[ModuleData] = []
	for m in installed:
		var key := "%d:%d" % [int(m.slot), m.mount]
		if m.mount < 0 or m.mount >= slots_for(m.slot) or seen.has(key):
			astray.append(m)
			continue
		seen[key] = true
	for m in astray:
		installed.erase(m)
		moved += 1
		var free := free_mount(m.slot)
		if free >= 0:
			m.mount = free
			installed.append(m)
			continue
		m.mount = -1
		m.hold_at = -Vector2i.ONE
		if not place_in_hold(m):
			pad.append(m)
	if pad.is_empty():
		old_hull = null
	elif old_hull == null:
		for raw in pad:
			var mod := raw as ModuleData
			if mod != null and mod.mount >= 0:
				mod.mount = -1
				moved += 1
	return moved


# -------------------------------------------------------------------------- map

## Floored at your own jumps, so your own jump needs no round trip; solo it is `jumps`.
## Why: docs/why/RunState.md#custodian-jump-count
func custodian_jumps() -> int:
	return maxi(party_jumps, jumps)


func node_at() -> MapGen.MapNode:
	return map[at]


## System `index`'s map clock (`map_clock`): where its map was put away, 0 for
## one never opened.
func map_t(index: int) -> float:
	return float(map_clock.get(index, 0.0))

## Null-safe, for callers like the chassis select that run before a galaxy exists.
## Why: docs/why/RunState.md#where-you-are
func here() -> MapGen.MapNode:
	return null if map.is_empty() else map[at]

## Fuel is distance; 13 is the tuned 17 converted after distances were un-squashed.
## Why: docs/why/RunState.md#fuel-per-distance
const FUEL_PER_DISC_RADIUS := 13.0

const FUEL_MAX_HOP := 6

## 45 is about one winning run, so fuel feels painful (Jon, Oct 17).
## Why: docs/why/RunState.md#fuel-tank
const FUEL_TANK := 45

## The fuel hint and the HUD's amber: a third of the tank (Jon: "warn:A"). The old
## threshold fired one to three jumps from stranding.
const FUEL_LOW_FRACTION := 1.0 / 3.0

## What a new run starts with: a full tank.
func start_fuel() -> int:
	return FUEL_TANK

## The top of the tank.
func fuel_cap() -> int:
	return FUEL_TANK

## At or under this the tank is LOW: the hint fires and the HUD turns amber.
func fuel_low_at() -> int:
	return int(ceil(float(fuel_cap()) * FUEL_LOW_FRACTION))

func fuel_low() -> bool:
	return fuel <= fuel_low_at()

## Critical, and the HUD turns red: fewer than two of the dearest jump on offer are left.
func fuel_critical() -> bool:
	if map.is_empty() or node_at() == null:
		return false
	var dear := 0
	for raw in in_range():
		var n: MapGen.MapNode = raw
		if n.sensed:
			dear = maxi(dear, fuel_cost_to(n))
	if dear == 0:
		dear = FUEL_MAX_HOP
	return fuel < dear * 2

## Routes only over hops the ship can take when it gets there, never over the chart.
## Why: docs/why/RunState.md#nearest-dock
func nearest_dock() -> Dictionary:
	if map.is_empty() or node_at() == null:
		return {}
	var here := node_at()
	if here.type == MapGen.NodeType.STATION:
		return {node = here, jumps = 0, fuel = 0}
	var known: Array = []
	for raw in map:
		var t: MapGen.MapNode = raw
		if t.type != MapGen.NodeType.CORE:
			known.append(t)
	# Breadth first by jumps, keeping the cheapest fuel to reach each system at
	# that depth; a ring of a few dozen charted systems, so this is small.
	var best_fuel := {here.index: 0}
	var frontier: Array = [here]
	var jumps := 0
	var found: Dictionary = {}
	while not frontier.is_empty() and found.is_empty():
		jumps += 1
		var next: Array = []
		for raw in frontier:
			var from: MapGen.MapNode = raw
			var spent: int = best_fuel[from.index]
			var dish := sense_radius_of(from)
			for raw2 in known:
				var t: MapGen.MapNode = raw2
				if t.index == from.index or not reachable_from(from, t) \
						or not hop_seen(here, from, t, dish):
					continue
				var c := spent + _hop_cost(from, t)
				if c > fuel or (best_fuel.has(t.index) and best_fuel[t.index] <= c):
					continue
				best_fuel[t.index] = c
				next.append(t)
				if t.type == MapGen.NodeType.STATION 						and (found.is_empty() or c < int(found.fuel)):
					found = {node = t, jumps = jumps, fuel = c}
		frontier = next
	return found

## A hop counts only if arriving at its start will show its end.
## Why: docs/why/RunState.md#nearest-dock
func hop_seen(here: MapGen.MapNode, from: MapGen.MapNode, t: MapGen.MapNode, dish: float) -> bool:
	if from.index == here.index:
		return t.sensed
	return MapGen.hop_distance(from, t) <= dish

## `fuel_cost_to` from somewhere other than where the ship is.
func _hop_cost(from: MapGen.MapNode, to: MapGen.MapNode) -> int:
	var d := MapGen.hop_distance(from, to)
	return clampi(int(round(fuel_factor() * d * FUEL_PER_DISC_RADIUS)), 1, FUEL_MAX_HOP)

## Events never drain the fuel needed to reach a dock, or three cheapest jumps when none is seen.
## Why: docs/why/RunState.md#no-fuel-dead-ends
func drain_fuel(n: int) -> void:
	if map.is_empty() or node_at() == null:
		fuel = maxi(0, fuel - n)
		return
	var limp := 0
	var dock := 0
	for raw in in_range():
		var t: MapGen.MapNode = raw
		if not t.sensed:
			continue
		var c := fuel_cost_to(t)
		limp = c if limp == 0 else mini(limp, c)
		if t.type == MapGen.NodeType.STATION:
			dock = c if dock == 0 else mini(dock, c)
	var keep := dock if dock > 0 else limp * 3
	fuel = maxi(mini(fuel, keep), fuel - n)

## Why REFUEL cannot sell here right now ("" when it can). Credits are the
## caller's business.
func refuel_blocked(_n: MapGen.MapNode) -> String:
	return "TANK FULL" if fuel >= fuel_cap() else ""

## One REFUEL here: a can, or the room left, charged by the unit. Docked, broke and
## stranded, it is `dock_rescue`'s offer instead.
func refuel_offer(n: MapGen.MapNode) -> Dictionary:
	var r := dock_rescue(n)
	return r if not r.is_empty() else _can_offer(n)

func _can_offer(n: MapGen.MapNode) -> Dictionary:
	var units := clampi(fuel_cap() - fuel, 0, Market.REFUEL_UNITS)
	var cost := Market.refuel_price(n)
	if units < Market.REFUEL_UNITS:
		cost = maxi(1, int(ceil(float(cost) * units / Market.REFUEL_UNITS)))
	return {units = units, cost = cost}

## Docked and broke, the dock sells exactly the fuel to reach another dock (Jon, Oct 18).
## Why: docs/why/RunState.md#no-fuel-dead-ends
func dock_rescue(n: MapGen.MapNode) -> Dictionary:
	if n == null or n.type != MapGen.NodeType.STATION or node_at() != n:
		return {}
	if credits >= int(_can_offer(n).cost):
		return {}
	var d := nearest_other_dock()
	if d.is_empty():
		return {}
	var need := int(d.fuel) - fuel
	if need <= 0:
		return {}
	var price := int(ceil(float(Market.refuel_price(n)) * need / Market.REFUEL_UNITS))
	return {units = need, cost = clampi(price, 0, maxi(0, credits)), rescue = true, dock = d.node}

## Routes over the hops sight will allow on arrival, not over the chart.
## Why: docs/why/RunState.md#nearest-dock
func nearest_other_dock() -> Dictionary:
	if map.is_empty() or node_at() == null:
		return {}
	var here := node_at()
	var known: Array = []
	for raw in map:
		var t: MapGen.MapNode = raw
		if t.type != MapGen.NodeType.CORE:
			known.append(t)
	var best := {here.index: 0}
	var hops := {here.index: 0}
	var open: Array = [here]
	var done := {}
	while not open.is_empty():
		var bi := 0
		for k in open.size():
			if int(best[(open[k] as MapGen.MapNode).index]) < int(best[(open[bi] as MapGen.MapNode).index]):
				bi = k
		var from: MapGen.MapNode = open[bi]
		open.remove_at(bi)
		if done.has(from.index):
			continue
		done[from.index] = true
		if from.type == MapGen.NodeType.STATION and from.index != here.index:
			return {node = from, jumps = int(hops[from.index]), fuel = int(best[from.index])}
		var dish := sense_radius_of(from)
		for raw2 in known:
			var t: MapGen.MapNode = raw2
			if done.has(t.index) or not reachable_from(from, t) or not hop_seen(here, from, t, dish):
				continue
			var c := int(best[from.index]) + _hop_cost(from, t)
			if c > fuel_cap() or (best.has(t.index) and int(best[t.index]) <= c):
				continue
			best[t.index] = c
			hops[t.index] = int(hops[from.index]) + 1
			open.append(t)
	return {}

## The plain line for a rescue offer, for the drone's tooltip and the log.
func rescue_line(o: Dictionary) -> String:
	var name := MapGen.star_name(o.dock)
	if credits <= 0:
		return "Enough fuel to reach %s. You have no credits, so it is free." % name
	if int(o.cost) >= credits:
		return "Enough fuel to reach %s: all your credits." % name
	return "Enough fuel to reach %s: %d credits." % [name, int(o.cost)]

## One REFUEL, paid. The station screen, the simulator and the party bot all
## buy through this, so the tank's rule is in one place.
func buy_refuel(n: MapGen.MapNode) -> bool:
	var o := refuel_offer(n)
	if credits < int(o.cost) or refuel_blocked(n) != "":
		return false
	add_credits(-int(o.cost))
	fuel += int(o.units)
	return true

func fuel_cost_to(n: MapGen.MapNode) -> int:
	return _hop_cost(node_at(), n)

## Range from the nearest few neighbours, not the furthest link, so one long link cannot inflate it.
## Why: docs/why/RunState.md#jump-neighbours
const JUMP_NEIGHBOURS := 6
## Cleared whenever the map changes. Range is a pure function of a system and
## the galaxy, and working it out costs a pass over every system.
var _range_cache: Dictionary = {}

## Referenced to the lightest hull so thrust only adds; 0.15 a point makes the class ladder visible.
## Why: docs/why/RunState.md#thrust-reach
const THRUST_REF := 4
const THRUST_REACH := 0.15
const THRUST_REACH_MAX := 1.6


## Thrust extends a jump and never shortens one, so the radius floor always holds.
## Why: docs/why/RunState.md#thrust-reach
func thrust_reach() -> float:
	return clampf(1.0 + float(attr_thrust() - THRUST_REF) * THRUST_REACH,
		1.0, THRUST_REACH_MAX)


## A fixed radius keeps reach knowable; the sight floor means a ship with no dish is never blind.
## Why: docs/why/RunState.md#jump-radius
const JUMP_RADIUS := 0.18

const SENSE_FLOOR := 1.0

const SENSE_REACH := 0.25


## One definition of what the chart draws, so the screen and the harnesses agree.
## Why: docs/why/RunState.md#what-the-chart-draws
func charted(n: MapGen.MapNode) -> bool:
	if n == null:
		return false
	# `station_heard` is deliberately absent: see the note above. It cannot admit
	# a system that `visited` has not already admitted.
	return n.sensed or n.visited or n.index == at \
		or contract_at(n.index) != null


func sense_radius() -> float:
	if map.is_empty():
		return 0.0
	return sense_radius_of(node_at())


## Sight from any system, not only the ship's, so sight can match the shape of reach.
## Why: docs/why/RunState.md#sight
func sense_radius_of(here: MapGen.MapNode) -> float:
	if map.is_empty() or here == null:
		return 0.0
	# The dish alone: reach can outrun sight on purpose (ruled 2026-08-28).
	# Why: docs/why/RunState.md#sight
	return _map_range_from(here) * (SENSE_FLOOR + float(attr_sensors()) * SENSE_REACH)


## Marks everything in sight of here, on arrival and at run start.
## Why: docs/why/RunState.md#sight
func chart_from(here: MapGen.MapNode) -> void:
	if here == null:
		return
	var r := sense_radius()
	if r <= 0.0:
		return
	# Live, not remembered: cleared first so the frontier stays dark; visited and told marks stay.
	# Why: docs/why/RunState.md#sight
	for n in map:
		(n as MapGen.MapNode).sensed = false
	# The core is always sensed: it is the objective and sits outside the rings.
	# Why: docs/why/RunState.md#sight
	for g in map:
		if (g as MapGen.MapNode).type == MapGen.NodeType.CORE:
			(g as MapGen.MapNode).sensed = true
	for n in map:
		var t: MapGen.MapNode = n
		if t.sensed or t.index == here.index:
			continue
		# Your dish only, one-directional: mirroring reach's symmetry made sparse systems
		# visible from across the galaxy.
		if MapGen.hop_distance(here, t) <= r:
			t.sensed = true


## The jump radius from `here`, engine included.
func range_from(here: MapGen.MapNode) -> float:
	return _map_range_from(here) * thrust_reach()


## The map term is cached apart from the ship's multiplier, so fitting a thruster invalidates nothing.
## Why: docs/why/RunState.md#jump-radius
func _map_range_from(here: MapGen.MapNode) -> float:
	return JUMP_RADIUS * study_radius_scale(here)


## All off by default; only sim and sheet runs set them, so Jon's options can be flown.
## Why: docs/why/RunState.md#balance-study-flags
var study_ambush_deep := 0.0
var study_radius_rim := 1.0
var study_radius_deep := 1.0

func study_radius_scale(here: MapGen.MapNode) -> float:
	if study_radius_rim == 1.0 and study_radius_deep == 1.0:
		return 1.0
	var layer := 0 if here == null else here.layer
	var t := clampf(float(layer) / float(maxi(1, MapGen.LAYERS - 2)), 0.0, 1.0)
	return lerpf(study_radius_rim, study_radius_deep, t)

## The smallest radius scale anywhere, for the generator's flyability walk.
func study_radius_min() -> float:
	return minf(study_radius_rim, study_radius_deep)

## At most two rings deeper a jump, so a dive to the core is held back (Jon, Oct 27).
## Why: docs/why/RunState.md#depth-cap
const DEPTH_STEP := 2
var depth_step := DEPTH_STEP


## True when `n` lies more rings in from `here` than one jump may go.
func too_deep(here: MapGen.MapNode, n: MapGen.MapNode) -> bool:
	if depth_step <= 0 or here == null or n == null:
		return false
	return n.layer - here.layer > depth_step


## Refused only for depth: within reach but three or more rings in. The chart's word
## for it is TOO DEEP.
func too_deep_only(here: MapGen.MapNode, n: MapGen.MapNode) -> bool:
	if not too_deep(here, n):
		return false
	if n.type == MapGen.NodeType.CORE:
		return true
	var d := MapGen.hop_distance(here, n)
	return d <= range_from(here) or d <= range_from(n)


## Within the depth cap, then distance, and symmetric so no hop is a one-way door.
## Why: docs/why/RunState.md#reachable
func reachable_from(here: MapGen.MapNode, n: MapGen.MapNode) -> bool:
	if n.index == here.index:
		return false
	# The last ring can always reach the core, so a ring galaxy's hole never blocks the end.
	# Why: docs/why/RunState.md#reachable
	if n.type == MapGen.NodeType.CORE and here.layer >= MapGen.LAYERS - 2:
		return true
	# Two rings deeper at most (DEPTH_STEP), so only the last two rings lead into the core.
	if too_deep(here, n):
		return false
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

## See it, afford it, reach it; the base radius guarantees some jump is always legal.
## Why: docs/why/RunState.md#can-jump-to
func can_jump_to(n: MapGen.MapNode) -> bool:
	return n.sensed and reachable(n) and fuel >= fuel_cost_to(n)

## True while at least one link out of the current node is affordable.
func has_legal_jump() -> bool:
	for n in map:
		if can_jump_to(n):
			return true
	return false

## Ends the run when no jump is affordable, or the ship soft-locks. Call only once the
## node is resolved, since a refuel or an event can still rescue it.
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
	# The hellbender moves on the party's clock, and a jump is the tick. After `at` is
	# set; a no-op on a client, where the host counts.
	hellbender_jumped()
	Sig.resources_changed.emit()
	Sig.jumped.emit(index)


# ----------------------------------------------------------------- the hellbender
## Host-authoritative because it moves and the game has no shared clock.
## Why: docs/why/RunState.md#the-hellbender

## Jumps between moves, SOLO. At ~65 jumps a run this is ~20 moves — enough to
## matter on the chart, slow enough to be caught.
const HELLBENDER_STRIDE := 3
## Scaled per ship, so a bigger crew does not outrun it.
## Why: docs/why/RunState.md#the-hellbender
const HELLBENDER_STRIDE_CREW := 2
## Hops taken all at once when it breaks off a fight. Two, so it is out of the
## system and out of jump range, but never out of the story.
const HELLBENDER_FLEE_HOPS := 2
## Hull mended per ordinary move, never per flee hop, so it escapes hurt and stays
## hurt: the mending window is the chase.
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

## The ascension level the Hellbender first flies at (Jon, Nov 8); the hiring boards still name it below.
## Why: docs/why/RunState.md#hellbender-ascension
const HELLBENDER_ASCENSION := 7
## The highest ascension level: the ladder's ten (Nov 7 ruling).
const ASCENSION_MAX := 10

## THIS RUN'S ASCENSION LEVEL. 0 is the game as it was before the ladder: the
## spiral, no Hellbender. Set once by `start_new_run`, saved with the run (a
## save from before it loads at 0), and in a party the host's (`Net.dive_ascension`).
## There is no picker yet; the ladder build adds one. Until then `-- asc=N`.
var ascension: int = 0
## Test seam: the level the next `start_new_run` uses, or -1 to read the
## command line. Never set from game code, the same discipline as `Rng.forced`.
var forced_ascension: int = -1

## The level a new run starts at. In a dive, the host's (sent with the seed,
## PROTOCOL 19), so four ships fly one galaxy with one rival or none. Solo, the
## test seam, then `-- asc=N` on the command line (sims, tests, a dev's run),
## then 0.
func ascension_for_new_run() -> int:
	if Net.state == NetSession.State.DIVING and Net.dive_seed != 0:
		return clampi(Net.dive_ascension, 0, ASCENSION_MAX)
	if forced_ascension >= 0:
		return clampi(forced_ascension, 0, ASCENSION_MAX)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("asc="):
			return clampi(int(arg.substr(4)), 0, ASCENSION_MAX)
	return 0

## Whether this run's ascension level brings the Hellbender at all.
func hellbender_in_play() -> bool:
	return ascension >= HELLBENDER_ASCENSION

func hellbender_alive() -> bool:
	return hellbender_at >= 0 and hellbender_hp > 0

## Whether this run HAD a Hellbender and it is gone. Not just "not alive": below
## HELLBENDER_ASCENSION there never was one (`hellbender_max` 0), and a board
## that stamped its WANTED poster DESTROYED would tell the player a story that
## never happened.
func hellbender_destroyed() -> bool:
	return hellbender_max > 0 and not hellbender_alive()

## Whether this machine is the one that moves it: the host, or nobody's client.
func _hellbender_authority() -> bool:
	return not Net.is_networked() or Net.is_host()

## Placed off a positional roll so the world stream does not shift. Middle shells: not
## on a fresh chassis, but on every run's ground.
func _spawn_hellbender() -> void:
	hellbender_at = -1
	hellbender_hp = 0
	hellbender_max = 0
	hellbender_moves = 0
	hellbender_ticks = 0
	# Ascension 7 and up only (HELLBENDER_ASCENSION). `hellbender_max` stays 0
	# below it, which is how a board tells "never here" from "killed".
	if hellbender_off or not hellbender_in_play():
		return
	var t: EnemyTemplate = DB.enemies.get(&"hellbender")
	if t == null or map.is_empty():
		return
	var candidates: Array = []
	for n in map:
		var node: MapGen.MapNode = n
		# (never a station: there are no fights at stations, `Router.no_fights_at`)
		if node.layer >= 3 and node.layer <= MapGen.LAYERS - 3 and node.type != MapGen.NodeType.STATION:
			candidates.append(node.index)
	if candidates.is_empty():
		return
	hellbender_max = t.max_hull
	hellbender_hp = hellbender_max
	hellbender_at = Rng.pick(Rng.derive(&"hellbender", 0), candidates)

## Compared with `<`, so a crew that shrinks still moves it on the next jump.
## Why: docs/why/RunState.md#the-hellbender
func hellbender_stride() -> int:
	var crew := maxi(1, Net.party_size())
	return HELLBENDER_STRIDE if crew <= 1 else HELLBENDER_STRIDE_CREW * crew

## A jump happened somewhere in the party; the authority guard makes every caller safe.
func hellbender_jumped() -> void:
	if not hellbender_alive() or not _hellbender_authority():
		return
	# Pinned while anyone is in its fight: it leaves only by the escape burn.
	if Net.fight_open_at(hellbender_at):
		return
	hellbender_ticks += 1
	if hellbender_ticks < hellbender_stride():
		return
	hellbender_ticks = 0
	_hellbender_step(true)
	Net.push_hellbender(true)

## A flee hop does not feed and never lands back where it fled from.
## Why: docs/why/RunState.md#the-hellbender
func _hellbender_step(feeding: bool, away_from: int = -1) -> void:
	if not hellbender_alive():
		return
	hellbender_moves += 1
	var r := Rng.derive(&"hellbender", hellbender_moves)
	var here_n: MapGen.MapNode = map[hellbender_at]
	var options: Array = []
	var food: Array = []
	for i in here_n.links:
		if i == away_from:
			continue
		var n: MapGen.MapNode = map[i]
		# Not the rim's first system and not the core: one is the front door,
		# and the other already has a custodian in it.
		if n.type == MapGen.NodeType.START or n.type == MapGen.NodeType.CORE:
			continue
		# nor a station: there are no fights at stations (`Router.no_fights_at`)
		if n.type == MapGen.NodeType.STATION:
			continue
		options.append(i)
		# What is actually here, not the node's label: a wreck is a system with salvage to strip.
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

## Apply a landing, on the authority and on clients alike: a pure function of the
## landing, so the party cannot disagree.
func hellbender_land(to: int, feeding: bool) -> void:
	if to < 0 or to >= map.size():
		return
	hellbender_at = to
	var n: MapGen.MapNode = map[to]
	if feeding and OptionTable.system_has_tag(n, &"salvage") and not n.cleared:
		# Consumed locally, not via Net.claim(): the movement push is already the shared fact.
		n.cleared = true
		n.eaten = true
		_mark_taken(n, MapGen.OPTION_WHOLE)
		log_line("The wreck at %s goes dark on the scope. The Hellbender stripped it." % MapGen.star_name(n), &"them")
	if to == at:
		log_line("A very hot signature fills the scope. THE HELLBENDER IS HERE.", &"big")
	Sig.map_changed.emit()

## A fight ended without a kill; the hull it lost stays lost between engagements.
func hellbender_scarred(hp: int) -> void:
	if not hellbender_alive() or not _hellbender_authority():
		return
	hellbender_hp = clampi(hp, 1, hellbender_max)
	Net.push_hellbender(false)

## The escape burn went unchecked: damage written back, then HELLBENDER_FLEE_HOPS at once.
func hellbender_breaks_off(hp: int) -> void:
	if not hellbender_alive() or not _hellbender_authority():
		return
	hellbender_hp = clampi(hp, 1, hellbender_max)
	var fled_from := hellbender_at
	for i in HELLBENDER_FLEE_HOPS:
		_hellbender_step(false, fled_from)
	Net.push_hellbender(false)

## The kill. Idempotent, because in a party several callers fire it.
func hellbender_defeated() -> void:
	if hellbender_at < 0:
		return
	hellbender_at = -1
	hellbender_hp = 0
	log_line("The Hellbender breaks apart. All the heat it stole this run leaks into space.", &"good")
	Sig.map_changed.emit()
	Net.push_hellbender(false)

## Position, hull and counter arrive whole from the host, so a dropped push costs one
## update rather than a drift.
func hellbender_adopt(to: int, hp: int, moves: int, feeding: bool) -> void:
	hellbender_moves = moves
	hellbender_hp = hp
	if to < 0:
		# Only a machine not in the fight gets here still thinking it alive, so this line
		# tells it what it missed.
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

## Take a job, returning the ledger's copy; the board keeps its own, so a partner is
## offered the same work.
func take_contract(c: ContractData) -> ContractData:
	var mine := ContractData.from_wire(c.to_wire())
	mine.id = next_contract_id
	next_contract_id += 1
	mine.state = ContractData.State.TAKEN
	contracts.append(mine)
	# The work goes on the named system's map now, so it is there to find
	# however you get there (`Contracts.post_goal`).
	Contracts.post_goal(mine)
	log_line("Signed: %s. It pays %d credits on delivery." % [
		_contract_short(mine), mine.pay], &"sys")
	Sig.contracts_changed.emit()
	return mine

## Whether this work is already yours, compared by content, since the board
## regenerates its objects every draw.
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

## A heat contract can be closed only while docked and still carrying the heat.
## Why: docs/why/RunState.md#heat-contracts
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
		log_line("Offloaded %d heat." % job.amount, &"heat")
	job.state = ContractData.State.CLOSED
	quests_done.append("c%d" % job.id)
	add_credits(job.pay)
	standing[job.manufacturer] = int(standing.get(job.manufacturer, 0)) + job.standing
	log_line("Delivered. %d credits. %s account in good order." % [
		job.pay, DB.short_name(DB.manufacturer_name(job.manufacturer))], &"good")
	Sig.contracts_changed.emit()
	Sig.resources_changed.emit()

## An event placed option `id` on `at`, from option `from`. One record a system,
## since the chart marks a system only once.
func note_placed(at: int, id: StringName, from: StringName) -> void:
	for i in range(event_quests.size() - 1, -1, -1):
		if int((event_quests[i] as Dictionary).get("at", -1)) == at:
			event_quests.remove_at(i)
	event_quests.append({at = at, id = id, from = from})


## The record of the event quest on system `at`, or {} (a save from before
## the records, or nothing placed there).
func event_quest_at(at: int) -> Dictionary:
	for raw in event_quests:
		var r: Dictionary = raw
		if int(r.get("at", -1)) == at:
			return r
	return {}


## Option `slot` at `n` was taken: if it is an event quest, record its pay and finish
## it. A signed job's quest is its contract.
func finish_event_quest(n: MapGen.MapNode, slot: int, paid: int, got: Array) -> void:
	if n == null or slot < 0 or slot >= n.options.size():
		return
	var id: StringName = n.options[slot]
	if not OptionTable.placed_ids().has(id):
		return
	var r := event_quest_at(n.index)
	if r.is_empty() or StringName(r.get("id", &"")) != id:
		# placed under a save from before the records: what is known now
		note_placed(n.index, id, &"")
		r = event_quest_at(n.index)
	r["credits"] = paid
	r["got"] = got.duplicate()
	var key := "e%d" % n.index
	quests_done.erase(key)
	quests_done.append(key)
	Sig.contracts_changed.emit()


## A recovered item is named, not carried, so a contract cannot soft-lock on inventory.
## Why: docs/why/RunState.md#fetch-contracts
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
		log_line("Recovered: %s. Strapped to the frame until you deliver it." % job.item,
			&"good")
	if moved:
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

## The bonus is on the bid only: a discount on the ask would open a buy-and-melt exploit.
## Why: docs/why/RunState.md#standing
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


## The open contract pointing at this system, or null. First match wins: the chart
## can say so only once.
func contract_at(index: int) -> ContractData:
	for c in contracts:
		var job: ContractData = c
		if job.state == ContractData.State.TAKEN and job.at == index:
			return job
	return null


## Marks where to hand finished work in, the half of the trip that costs fuel.
## Why: docs/why/RunState.md#delivery-markers
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


## A contract reveals where and nothing more; a station counts only once sensed or visited.
## Why: docs/why/RunState.md#stations-heard
func station_heard(index: int) -> bool:
	if index < 0 or index >= map.size():
		return false
	var n: MapGen.MapNode = map[index]
	if n.type != MapGen.NodeType.STATION:
		return false
	if n.visited or index == at:
		return true
	# Ruled 2026-08-26: you can only see what you can see, so nothing else reveals a station.
	# Why: docs/why/RunState.md#stations-heard
	return false


func known_only_by_contract(index: int) -> bool:
	if index < 0 or index >= map.size():
		return false
	if contract_at(index) == null:
		return false
	var n: MapGen.MapNode = map[index]
	# `station_heard`, not "is a station": an unheard station is unexplored, and the
	# panel has to say so.
	if n.visited or station_heard(index) or index == at:
		return false
	for r in in_range():
		if (r as MapGen.MapNode).index == index:
			return false
	return true
