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

## A galaxy exists before any run does — screens can be built and asked to draw
## before start_new_run() has rolled one — so it is never an empty dictionary.
func _ready() -> void:
	if galaxy.is_empty():
		galaxy = GalaxyGen.params(0).duplicate()
var galaxy_name: String = ""
var galaxy_title: String = ""

var hp: int = 35
var heat: int = 0
var heat_cap_bonus: int = 0
var scrap: int = 40
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

var found_hull: HullData = null      ## offered for transfer
var whale_boon: bool = false

const MAP_CANVAS := Rect2(60, 50, 900, 430)

## Begin a run in a given manufacturer's chassis.
##
## The argument is optional and empty means "roll one", which is not a
## convenience: HeadlessSim calls this directly, and a default of Korvan would
## have every one of two hundred simulated runs fly the same ship and report a
## win rate for one seventh of the game. Random here means the sim exercises all
## seven starts for free.
func start_new_run(manufacturer: StringName = &"", w: int = -1) -> void:
	# A weight of -1 rolls one, for the same reason an empty manufacturer does:
	# HeadlessSim calls this directly, and a fixed default would report a win
	# rate for one twenty-first of the possible starts.
	var weight: HullData.Weight = w as HullData.Weight
	if w < 0:
		weight = [HullData.Weight.LIGHT, HullData.Weight.MEDIUM,
			HullData.Weight.HEAVY].pick_random()
	fit_chassis(manufacturer, weight)
	cargo.clear()
	heat = 0
	heat_cap_bonus = 0
	scrap = 40
	materials.clear()
	fuel = 150
	dross = 0
	jumps = 0
	kills = 0
	started_at = Time.get_unix_time_from_system()
	won = false
	dead = false
	death_reason = ""
	found_hull = null
	whale_boon = false
	galaxy_kind = randi() % GalaxyGen.count()
	galaxy = GalaxyGen.roll(galaxy_kind)
	galaxy_seed = randi()
	galaxy_spin = randf() * TAU
	galaxy_name = GalaxyGen.roll_name()
	galaxy_title = GalaxyGen.roll_title()
	map = MapGen.generate(MAP_CANVAS)
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
		man = DB.STARTABLE.pick_random()
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
		installed.append(m)
	_top_up_deck()
	hp = max_hp()
	heat = 0
	Sig.ship_changed.emit()
	Sig.resources_changed.emit()

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
				installed.append(m.duplicate(true) as ModuleData)
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

func max_hp() -> int:
	return hull.max_hull

func heat_cap() -> int:
	return hull.heat_cap + heat_cap_bonus

func dissipation() -> int:
	var d := hull.dissipation
	if hull.perk_id == &"baffled_vents":
		d += 1
	return d

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

func attr_hull() -> int:
	return clampi(int(round(ATTR_MAX * float(hp) / HULL_REF)), 0, ATTR_MAX)

## Thrust reads off fuel burn: a bigger engine moves more ship and drinks more
## doing it, so the factor that prices your jumps is already the number.
func attr_thrust() -> int:
	return clampi(int(round(hull.fuel_factor * 4.7)), 0, ATTR_MAX)

## Dodge is the bulk of it; initiative tilts it. The +1 floor is there because
## without it every chassis with dodge under 0.05 and negative initiative read
## exactly 0 — the Ironside Cutter, a medium warship, scored the same
## Maneuver as an ore barge, which is not a distinction worth erasing. A barge
## can still reach 0 by being an actual barge.
func attr_maneuver() -> int:
	return clampi(int(round(hull.dodge * 23.0 + hull.initiative * 0.9 + 1.5)), 0, ATTR_MAX)

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

func attr_thermal() -> int:
	var v := (heat_cap() - THERMAL_FLOOR) / 2.1 + dissipation() / 1.5
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

func attr_sensors() -> int:
	var n := hull.sensors
	for m in installed:
		n += m.sensors
	return clampi(int(round(n * SENSE_SCALE)), 0, ATTR_MAX)

func attr_stealth() -> int:
	var n := hull.stealth
	for m in installed:
		n += m.stealth
	return clampi(int(round(n * SENSE_SCALE)), 0, ATTR_MAX)

## Every attribute, in display order, as {key, label, short, value}.
## One list so the ship tab, the chassis select and any future check UI cannot
## disagree about the order or the names.
func attributes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign([
		{key = &"hull", label = "HULL", short = "HUL", value = attr_hull(),
			text = "Ramming, boarding, holding together under structural stress."},
		{key = &"thrust", label = "THRUST", short = "THR", value = attr_thrust(),
			text = "Outrunning, breaking orbit, pulling free of a gravity well."},
		{key = &"maneuver", label = "MANEUVERABILITY", short = "MNV", value = attr_maneuver(),
			text = "Threading debris, evading a lock, choosing how a fight opens."},
		{key = &"thermal", label = "THERMAL", short = "THM", value = attr_thermal(),
			text = "Sitting in heat: coronas, reactors, anything that cooks you."},
		{key = &"sensors", label = "SENSORS", short = "SEN", value = attr_sensors(),
			text = "Reading a wreck, finding the lane, seeing it before it sees you."},
		{key = &"stealth", label = "STEALTH", short = "STL", value = attr_stealth(),
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
	n.cleared = true
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

func add_scrap(n: int) -> void:
	scrap = maxi(0, scrap + n)
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
			cargo.append(worst)
			log_line("Removed %s to make room." % worst.name, &"sys")
	cargo.erase(m)
	installed.append(m)
	log_line("Installed %s." % m.name, &"good")
	Sig.ship_changed.emit()

func uninstall_module(m: ModuleData) -> void:
	installed.erase(m)
	cargo.append(m)
	Sig.ship_changed.emit()

## Melt a part down. Scrap plus whatever the part was MADE of, which is the
## quiet half: every module you decline is now crafting stock, so a drop you do
## not want is still a reason to have opened the wreck. Grown and precursor parts
## do not yield alloy at all — they were never pressed out of plate.
func scrap_module(m: ModuleData) -> void:
	var v := scrap_value_of(m)
	cargo.erase(m)
	add_scrap(v)
	var bits := "%d scrap" % v
	for pair in materials_from(m):
		add_material(pair.id, int(pair.count))
		bits += ", %d %s" % [int(pair.count), DB.material_name(pair.id).to_lower()]
	log_line("Scrapped %s for %s." % [m.name, bits], &"good")
	Sig.ship_changed.emit()

## What melting this part down yields, besides scrap. Here rather than in
## scrap_module so the station can print it on the button before you commit.
func materials_from(m: ModuleData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if m.rarity == ModuleData.Rarity.ARTIFACT:
		out.append({id = &"relic", count = 1})
	elif m.rarity == ModuleData.Rarity.EXOTIC:
		out.append({id = &"exotic", count = 1})
	else:
		var n: int = DB.ALLOY_BY_RARITY[clampi(int(m.rarity), 0, 6)]
		if n > 0:
			out.append({id = &"alloy", count = n})
	return out

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
			cargo.append(worst)
	var ratio := float(hp) / float(max_hp())
	hull = h
	hp = maxi(6, int(round(h.max_hull * ratio)))
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
	return clampi(int(round(hull.fuel_factor * d * FUEL_PER_DISC_RADIUS)),
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
	Sig.resources_changed.emit()
	Sig.jumped.emit(index)
