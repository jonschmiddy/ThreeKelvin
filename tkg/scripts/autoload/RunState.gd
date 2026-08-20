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
var fuel: int = 150

## Raw materials, by id. See DB.MATERIALS.
##
## Scrap is still the only CURRENCY — the ruling has not moved. These are not a
## second wallet; nothing on a price tag is denominated in them. They are
## prerequisites: a recipe that costs forty scrap is a purchase, and a recipe
## that costs one precursor fragment is a reason to have flown somewhere.
var materials: Dictionary = {}

## Exotic was a bare int here from the day megafauna existed, and about fifteen
## call sites still read and write it that way. It is now the `exotic` row of
## the ledger above, reached through a property so that every one of those sites
## keeps working against the single store rather than against a copy that would
## drift out of step with it the first time something forgot to update both.
var exotic: int:
	get:
		return int(materials.get(&"exotic", 0))
	set(v):
		materials[&"exotic"] = maxi(0, v)
var dross: int = 0

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

var found_hull: HullData = null      ## offered for transfer
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
	Rng.reseed(galaxy_seed)

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
	fuel = 150
	dross = 0
	jumps = 0
	kills = 0
	hauls = 0
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
	at = 0
	trail = PackedInt32Array([0])
	_range_cache.clear()
	Sig.run_started.emit()
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
func fit_chassis(manufacturer: StringName = &"",
		w: HullData.Weight = HullData.Weight.MEDIUM) -> void:
	var man := manufacturer
	if man == &"" or not DB.STARTER_WEAPON.has(man):
		man = Rng.pick(Rng.derive(&"start", 1), DB.STARTABLE)
	hull = (DB.hull_for(man, w) as HullData).duplicate(true) as HullData
	hull.tier = 0
	installed.clear()
	# Only what fits. The kit is written per manufacturer but the hardpoints
	# belong to the weight class, so a light frame launches with fewer modules
	# than a heavy one carrying the same kit — you traded guns for speed and the
	# loadout says so. Installing past the slot count would let the select screen
	# hand you a ship the refit screen considers illegal.
	for id in DB.starter_kit(man):
		var m := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
		if slots_used(m.slot) >= slots_for(m.slot):
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

## How many SLOTS the hold has. See HullData.cargo_slots.
##
## Slots, not modules: a slot is a place and a module is one of the things that
## can occupy one.
func cargo_slots() -> int:
	return hull.cargo_slots if hull != null else 8

func hold_full() -> bool:
	return cargo.size() >= cargo_slots()

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
	if hold_full():
		log_line("The hold is full. %s left behind." % m.name, &"them")
		return false
	cargo.append(m)
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
## frames are not. Four makers drop a weapon mount, so on a LIGHT frame their
## generic weapon had nowhere to go and two cards vanished, while the same ship
## sat on spare system and utility mounts the kit could not reach. Dredge,
## Cygnet, Halcyon and Calyx lights opened two cards down on Korvan's for no
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
			n += m.max_hull
	return maxi(1, n)

func heat_cap(bare: bool = false) -> int:
	var n := hull.heat_cap + heat_cap_bonus
	if not bare:
		for m in installed:
			n += m.heat_cap
	return maxi(1, n)

func dissipation(bare: bool = false) -> int:
	var d := hull.dissipation
	if hull.perk_id == &"baffled_vents":
		d += 1
	if not bare:
		for m in installed:
			d += m.dissipation
	return maxi(0, d)

## Capped at 0.6. Dodge is the enemy's miss chance, so an uncapped sum is a ship
## nothing can hit — and the ruling that only enemies miss means the player never
## sees the roll that would tell them the fight had stopped being a fight.
func dodge(bare: bool = false) -> float:
	var v := hull.dodge
	if not bare:
		for m in installed:
			v += m.dodge
	return clampf(v, 0.0, 0.6)

func initiative(bare: bool = false) -> int:
	var v := hull.initiative
	if not bare:
		for m in installed:
			v += m.initiative
	return v

## Floored well above zero: this multiplies the price of every jump, and a ship
## that had driven it to 0 would cross the galaxy free.
func fuel_factor(bare: bool = false) -> float:
	var v := hull.fuel_factor
	if not bare:
		for m in installed:
			v += m.fuel_factor
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
	p *= 1.0 - float(attr_stealth()) / float(ATTR_MAX) * 0.6
	return clampf(p, 0.0, 0.6)

func reactor() -> int:
	var e := hull.reactor
	if hull.perk_id == &"overspec_reactor":
		e += 1
	if has_set(&"halcyon", 5):
		e += 1
	return e

## Development override, set by `-- fight N`. Zero means "use the real value".
## Lives here rather than in Main so Combat's redraw each turn honours it too —
## a hand that is ten on turn one and five on turn two would test the layout
## exactly once.
var hand_size_override: int = 0

func hand_size() -> int:
	if hand_size_override > 0:
		return hand_size_override
	var h := hull.hand_size
	if has_set(&"redline", 3):
		h += 1
	return h

func slots_for(s: ModuleData.Slot) -> int:
	var c := hull.slots_for(s)
	if s == ModuleData.Slot.UTILITY and hull.perk_id == &"spare_bay":
		c += 1
	return c

func slots_used(s: ModuleData.Slot) -> int:
	var n := 0
	for m in installed:
		if m.slot == s:
			n += 1
	return n

## Modules from this maker, PLUS the hull if it built one.
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
## medium and a Solari medium — which is most of what those two makers ARE —
## rounded away. Every constant below was rescaled with it, not multiplied
## through: the point of the wider scale is that the ships spread out in it.
const ATTR_MAX := 10

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
	return clampi(int(round(ATTR_MAX * float(v) / HULL_REF)), 0, ATTR_MAX)

## Thrust reads off fuel burn: a bigger engine moves more ship and drinks more
## doing it, so the factor that prices your jumps is already the number.
func attr_thrust(bare: bool = false) -> int:
	return clampi(int(round(fuel_factor(bare) * 4.7)), 0, ATTR_MAX)

## Dodge is the bulk of it; initiative tilts it. The +1 floor is there because
## without it every chassis with dodge under 0.05 and negative initiative read
## exactly 0 — the Ironside Cutter, a medium warship, scored the same
## Maneuver as an ore barge, which is not a distinction worth erasing. A barge
## can still reach 0 by being an actual barge.
func attr_maneuver(bare: bool = false) -> int:
	return clampi(int(round(dodge(bare) * 23.0 + initiative(bare) * 0.9 + 1.5)),
		0, ATTR_MAX)

## Thermal is capacity AND shedding, per §1.4, because an event that asks "can
## you sit in this heat" is asking about both and would otherwise need two
## attributes to answer.
##
## Capacity carries most of the weight, and this took a measurement to get
## right. The first version was `cap/6 + diss/2.5`, which read 3 or 4 for every
## chassis in the game — the Emberwright caps at 20 and vents 2, the Brood
## Tender caps at 12 and vents 4, and the two terms cancelled so cleanly that
## the heat manufacturer and the drone manufacturer scored identically. Weighting
## capacity harder and subtracting a floor spreads it 2-6, with Solari at the
## top where the whole maker says it should be.
##
## They are not interchangeable in fiction and must not be in the formula:
## capacity is how much you can take, dissipation is how fast you get rid of it,
## and only the first decides whether you survive sitting in a corona.
##
## Divisors widened once already. At 2.4/2.0 the attribute saturated: five of
## the seven heavy frames pinned at 6, so a Dredge ore barge and a Solari
## Furnace Baron read identically on the axis Solari exists to own. A ceiling
## that everything large reaches is not a measurement. Now exactly one chassis
## in the game reads 6, and it is the one built by the heat manufacturer.
const THERMAL_FLOOR := 8.0

func attr_thermal(bare: bool = false) -> int:
	var v := (heat_cap(bare) - THERMAL_FLOOR) / 2.1 + dissipation(bare) / 1.5
	return clampi(int(round(v)), 0, ATTR_MAX)

## Sensors and Stealth are the two with no other gauge in the game, so unlike
## the four above they are summed rather than derived. Hull baseline plus fitted
## modules — the same shape as the others, where the chassis sets the platform
## and what you bolt on adjusts it.
## Sensors and Stealth are authored in small whole numbers — a hull carries 0 to
## 2, a module 1 or 2 — because that is a legible thing to write in a data table.
## The scale they are DISPLAYED on is a different question, so the conversion
## lives here rather than in the catalog. At 1.7 the best sensor ship in the game
## reads 7 and the stealthiest reads 9, which leaves both room to improve.
const SENSE_SCALE := 1.7

func attr_sensors(bare: bool = false) -> int:
	var n := hull.sensors
	if not bare:
		for m in installed:
			n += m.sensors
	return clampi(int(round(n * SENSE_SCALE)), 0, ATTR_MAX)

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
			n += m.stealth
	# The heat penalty applies to BOTH readings. `bare` means "the chassis with
	# nothing fitted", and heat is not something you fitted — so subtracting it
	# only from the full reading would paint the loss as a module's fault in the
	# attribute block, which draws chassis and modules in different colours.
	var v := float(n) * SENSE_SCALE - signature() * HEAT_STEALTH_COST
	return clampi(int(round(v)), 0, ATTR_MAX)

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
func attributes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{key = &"hull", label = "HULL", short = "HUL",
			value = attr_hull(), base = attr_hull(true),
			text = "Ramming, boarding, holding together under structural stress."},
		{key = &"thrust", label = "THRUST", short = "THR",
			value = attr_thrust(), base = attr_thrust(true),
			text = "Outrunning, breaking orbit, pulling free of a gravity well."},
		{key = &"maneuver", label = "MANEUVERABILITY", short = "MNV",
			value = attr_maneuver(), base = attr_maneuver(true),
			text = "Threading debris, evading a lock, choosing how a fight opens."},
		{key = &"thermal", label = "THERMAL", short = "THM",
			value = attr_thermal(), base = attr_thermal(true),
			text = "Sitting in heat: coronas, reactors, anything that cooks you."},
		{key = &"sensors", label = "SENSORS", short = "SEN",
			value = attr_sensors(), base = attr_sensors(true),
			text = "Reading a wreck, finding the lane, seeing it before it sees you."},
		{key = &"stealth", label = "STEALTH", short = "STL",
			value = attr_stealth(), base = attr_stealth(true),
			text = "Going dark, slipping a patrol, arriving unannounced."},
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

func die(reason: String) -> void:
	dead = true
	death_reason = reason
	Sig.run_ended.emit(false, reason)

func win() -> void:
	won = true
	Sig.run_ended.emit(true, "You cross into the light.")

func install_module(m: ModuleData) -> void:
	if slots_used(m.slot) >= slots_for(m.slot):
		var worst: ModuleData = null
		for x in installed:
			if x.slot == m.slot and (worst == null or x.scrap_value < worst.scrap_value):
				worst = x
		if worst != null:
			installed.erase(worst)
			worst.mount = -1
			cargo.append(worst)
			log_line("Removed %s to make room." % worst.name, &"sys")
	cargo.erase(m)
	m.mount = free_mount(m.slot)
	installed.append(m)
	log_line("Installed %s." % m.name, &"good")
	Sig.ship_changed.emit()

## Take a part off. Refused when the hold is full, because the alternative is
## destroying it — and a refit screen that silently melts what you unbolt is
## worse than one that says no.
func uninstall_module(m: ModuleData) -> bool:
	if hold_full():
		log_line("No room in the hold for %s." % m.name, &"them")
		return false
	installed.erase(m)
	m.mount = -1
	cargo.append(m)
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
	cargo.erase(m)
	add_credits(v)
	log_line("Scrapped %s for %d scrap." % [m.name, v], &"good")
	Sig.ship_changed.emit()

func transfer_to_hull(h: HullData) -> void:
	# Shed anything that no longer fits, cheapest first.
	for s in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		var cap: int = h.slots_for(s)
		if s == ModuleData.Slot.UTILITY and h.perk_id == &"spare_bay":
			cap += 1
		while slots_used(s) > cap:
			var worst: ModuleData = null
			for x in installed:
				if x.slot == s and (worst == null or x.scrap_value < worst.scrap_value):
					worst = x
			if worst == null:
				break
			installed.erase(worst)
			worst.mount = -1
			cargo.append(worst)
	var ratio := float(hp) / float(max_hp())
	hull = h
	hp = maxi(6, int(round(h.max_hull * ratio)))
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
	log_line("Transferred to %s. %s" % [h.display_name(), DB.perk_text(h.perk_id)], &"big")
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
const FUEL_PER_DISC_RADIUS := 17.0
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

func range_from(here: MapGen.MapNode) -> float:
	var hit: float = _range_cache.get(here.index, -1.0)
	if hit >= 0.0:
		return hit
	var ds: Array[float] = []
	for n in map:
		var t: MapGen.MapNode = n
		if t.index == here.index:
			continue
		ds.append(MapGen.hop_distance(here, t))
	if ds.is_empty():
		_range_cache[here.index] = 0.0
		return 0.0
	ds.sort()
	# Relative to your CLOSEST neighbour, not a fixed count.
	#
	# Taking the sixth-nearest meant the drive always reached exactly six
	# systems — so out on the thin frontier it stretched across enormous gaps to
	# find them, and in the crowded deep galaxy it stopped short of things
	# sitting right next to you. Every neighbourhood looked identical however
	# dense the region actually was, which quietly threw away the whole point of
	# populating the rings unevenly.
	#
	# Anything within about two and a half times your nearest neighbour is close
	# enough to be a real option; past that it is a trek. Floored at the third
	# nearest so a sparse ring still offers a choice rather than a corridor, and
	# capped at the sixth so a dense one does not offer twenty.
	var nearest: float = ds[0]
	var lo: float = ds[mini(2, ds.size() - 1)]
	var hi: float = ds[mini(JUMP_NEIGHBOURS - 1, ds.size() - 1)]
	var r: float = clampf(nearest * 2.5, lo, hi) * 1.06
	_range_cache[here.index] = r
	return r

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
func reachable_from(here: MapGen.MapNode, n: MapGen.MapNode) -> bool:
	if n.index == here.index:
		return false
	return MapGen.hop_distance(here, n) <= range_from(here)

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

func can_jump_to(n: MapGen.MapNode) -> bool:
	return reachable(n) and fuel >= fuel_cost_to(n)

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
	jumps += 1
	cool_in_transit()
	Sig.resources_changed.emit()
	Sig.jumped.emit(index)
