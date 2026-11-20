class_name MaterialTable

## Materials are a second item class in the hold, not a currency: they sell, they never price.
## Draft 2 (Jon, Nov 18): six sources, each with its own list at every tier it has.
## Why: docs/why/MaterialTable.md#material-catalogue


## Where a material comes from: the table that rolls it, and the word its tooltip says.
## `cosmic` was SKY until Nov 18. Why: docs/why/MaterialTable.md#sources
const SOURCES: Array[StringName] = [&"wreck", &"mining", &"event", &"fight", &"fauna", &"cosmic"]

## The grades in ladder order, as `ModuleData.Rarity` counts them; `pick` walks down it.
const TIERS: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary",
	&"exotic", &"artifact", &"contraband"]

## Cut rows a save may still hold, read as the row that took their source and tier.
## Why: docs/why/MaterialTable.md#retired-ids
const RETIRED: Dictionary = {
	&"mooring_pins": &"gasket_rings",
	&"packing_foam": &"hull_paint",
	&"sweep_mirrors": &"korvan_cold_iron",
	&"hellbender_chitin": &"hellbender_plate",
	&"hellbender_tooth": &"one_true_metre",
	&"pressed_relics": &"void_labels",
	&"grey_coolant": &"void_labels",
	&"hot_plate": &"void_labels",
	&"counterfeit_seals": &"void_labels",
}

## Same gates as `LootGen` by reference: rarity follows where you stand. Raw danger was the bug.
## Contraband is ungated as its gate is risk, and exotic because it is live.
## Why: docs/why/MaterialTable.md#tier-gates
const TIER_MIN: Dictionary = {
	&"epic": LootGen.EPIC_TIER,
	&"legendary": LootGen.LEGENDARY_TIER,
	&"artifact": LootGen.LEGENDARY_TIER,
}

## Deep wrecks pay more, rising with depth (Jon, Nov 19: "Bump it I think. but they can also
## get artifacts, too."): a WRECK roll's shares per grade at each tier; unlisted 1, 0 closed.
## Why: docs/why/MaterialTable.md#deep-wrecks
const WRECK_SHARES: Dictionary = {
	3: {&"epic": 2},
	4: {&"uncommon": 0, &"rare": 2, &"epic": 2, &"legendary": 2},
	5: {&"uncommon": 0, &"rare": 2, &"epic": 3, &"legendary": 4, &"artifact": 2},
}
## From this tier a wreck also turns up the precursor pieces (`precursor = true`) of other lists.
const WRECK_PRECURSOR_TIER := LootGen.LEGENDARY_TIER

## Whether a system of this danger rolls this grade: its gate is open, and it is
## not a common from halfway in (`LootGen.NO_COMMON_TIER`, the module rule).
static func admits(tier: StringName, danger: int) -> bool:
	# Every threshold here is a tier, as in LootGen. Read the wider scale
	# through tier() rather than restating them in danger.
	var t := MapGen.tier(danger)
	if tier == &"common" and t >= LootGen.NO_COMMON_TIER:
		return false
	return _opens(tier, t)


static func _opens(tier: StringName, t: int) -> bool:
	return t >= int(TIER_MIN.get(tier, 1))


## A row's shares in a `source` roll at tier `t`: 1, except a wreck's (`WRECK_SHARES`).
static func shares(source: StringName, tier: StringName, t: int) -> int:
	if source != &"wreck":
		return 1
	return int((WRECK_SHARES.get(t, {}) as Dictionary).get(tier, 1))


## Whether `row` is in a `source` roll at tier `t`: its own list, and a deep wreck's precursors.
static func rolls_in(row: Dictionary, source: StringName, t: int) -> bool:
	if row.get("named", false):
		return false
	if row.source == source:
		return true
	return source == &"wreck" and t >= WRECK_PRECURSOR_TIER and row.get("precursor", false)


## One row from `source`'s list by its grade's shares (all 1 but a wreck's, so every row alike,
## as `LootGen.roll_module` does). Only closed grades left pays one of them, never nothing.
static func roll(source: StringName, danger: int,
		r: RandomNumberGenerator) -> Dictionary:
	var t := MapGen.tier(danger)
	var pool: Array[Dictionary] = []
	var weights: Array[int] = []
	var closed: Array[Dictionary] = []
	for row in all():
		var tier: StringName = row.tier
		if not rolls_in(row, source, t) or not _opens(tier, t):
			continue
		var w := shares(source, tier, t)
		if admits(tier, danger) and w > 0:
			pool.append(row)
			weights.append(w)
		else:
			closed.append(row)
	if pool.is_empty():
		pool = closed
		weights.assign(closed.map(func(_x: Dictionary) -> int: return 1))
	if pool.is_empty():
		return {}
	var total := 0
	for w in weights:
		total += w
	# With every share 1 this is the old `pool[randi() % size]`, draw for draw.
	var k := r.randi() % total
	for i in pool.size():
		k -= weights[i]
		if k < 0:
			return pool[i]
	return pool[-1]


## One row of `tier` from `source`, else of the nearest grade under it the source has: a
## science haul decides the grade first. Contraband is only ever asked for by name.
## Why: docs/why/MaterialTable.md#picking-a-grade
static func pick(source: StringName, tier: StringName,
		r: RandomNumberGenerator) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var top := TIERS.find(tier)
	var low := top if tier == &"contraband" else 0
	for i in range(top, low - 1, -1):
		if TIERS[i] == &"contraband" and tier != &"contraband":
			continue
		var pool := rows_of(source, TIERS[i])
		if not pool.is_empty():
			out.assign(pool[r.randi() % pool.size()])
			return out
	return out


## Every rolled row of one source at one grade, in table order; named rows never.
static func rows_of(source: StringName, tier: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in all():
		if row.source == source and row.tier == tier and not row.get("named", false):
			out.append(row)
	return out


## The credit shim is gone: the hold carries the object and a station turns it into money.
## Why: docs/why/MaterialTable.md#grant
static func grant(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	Run.add_material(StringName(row.get("id", &"")), 1)
	return String(row.get("name", ""))


## A cut id answers with the row that replaced it, so an old save or a found frame's pay still
## lands. Why: docs/why/MaterialTable.md#retired-ids
static func by_id(id: StringName) -> Dictionary:
	if _by_id.is_empty():
		_index(all())
	return _by_id.get(id, _by_id.get(RETIRED.get(id, &""), {}))


static var _all: Array[Dictionary] = []

# The id index of `_all` (the table never changes once built), first row wins as the old scan did.
static var _by_id: Dictionary = {}


## Built once from `ROWS`. `EventTable.build_all()` rebuilding its dictionaries on every call
## is the pattern this exists not to repeat.
static func all() -> Array[Dictionary]:
	if _all.is_empty():
		_all.assign(ROWS)
	return _all


static func _index(rows: Array[Dictionary]) -> void:
	for r in rows:
		if not _by_id.has(r.id):
			_by_id[r.id] = r


## Draft 2, as Jon approved it on Nov 18 (`tools/fixtures/materials_draft2.json`; MaterialTest
## holds this table to it). Ids are what a save stores, so a live one never changes.
## Why: docs/why/MaterialTable.md#material-catalogue
const ROWS := [
	# WRECK: off a dead hull.
	{id = &"deck_plate", name = "DECK PLATE", tier = &"common", cells = "2x1", value = 10,
		source = &"wreck", text = "Worn deck plating off a hull walkway."},
	{id = &"coil_stock", name = "COIL STOCK", tier = &"common", cells = "1x1", value = 9,
		source = &"wreck", text = "Copper wire wound on a spool."},
	{id = &"bearing_race", name = "BEARING RACES", tier = &"common", cells = "1x1", value = 12,
		source = &"wreck", text = "Bearing races from a ship's drive train."},
	{id = &"bulk_girder", name = "BULK GIRDER", tier = &"common", cells = "4x1", value = 14,
		source = &"wreck", text = "A structural girder cut from a hull frame."},
	{id = &"union_pipe", name = "UNION PIPE", tier = &"common", cells = "3x1", value = 12,
		source = &"wreck", text = "Threaded union pipe pulled from a wreck."},
	{id = &"filter_stacks", name = "FILTER STACKS", tier = &"common", cells = "2x1", value = 12,
		source = &"wreck", text = "Used air filters from a ship's scrubbers."},
	{id = &"scrap_optics", name = "SCRAP OPTICS", tier = &"uncommon", cells = "1x1", value = 16,
		source = &"wreck", text = "Cracked lenses from a ship's sensors."},
	{id = &"cable_loom", name = "CABLE LOOM", tier = &"uncommon", cells = "2x1", value = 18,
		source = &"wreck", text = "A wiring harness cut whole from a ship."},
	{id = &"valve_bodies", name = "VALVE BODIES", tier = &"uncommon", cells = "1x1", value = 17,
		source = &"wreck", text = "Fuel valves cut from a feed line."},
	{id = &"hatch_motors", name = "HATCH MOTORS", tier = &"uncommon", cells = "1x1", value = 21,
		source = &"wreck", text = "Hatch motors unbolted from a wreck."},
	{id = &"radiator_fins", name = "RADIATOR FINS", tier = &"uncommon", cells = "3x1", value = 19,
		source = &"wreck", text = "Radiator fins stripped off a cold hull."},
	{id = &"verity_gaskets", name = "VERITY GASKETS", tier = &"rare", cells = "1x1", value = 30,
		source = &"wreck", text = "Hatch gaskets from a Verity hull."},
	{id = &"solari_lens", name = "SOLARI LENS STOCK", tier = &"rare", cells = "1x1", value = 38,
		source = &"wreck", text = "Heat-rated lenses made by Solari."},
	{id = &"navigators_gel", name = "NAVIGATOR'S GEL", tier = &"rare", cells = "1x1", value = 44,
		source = &"wreck", text = "Inertial reference gel from a ship's nav core."},
	{id = &"grown_conduit", name = "GROWN CONDUIT", tier = &"rare", cells = "3x1", value = 44,
		source = &"wreck", text = "Living conduit cut from a Calyx hull."},
	{id = &"korvan_cold_iron", name = "KORVAN COLD IRON", tier = &"epic", cells = "2x1", value = 85,
		source = &"wreck", text = "Vacuum-cooled iron made to Korvan's navy spec."},
	{id = &"wrong_mass", name = "WRONG MASS", tier = &"epic", cells = "1x1", value = 110,
		source = &"wreck", precursor = true, text = "A precursor lump far heavier than its size."},
	{id = &"first_keel", name = "FIRST-POUR KEEL SECTION", tier = &"legendary", cells = "4x1", value = 240,
		source = &"wreck", text = "A keel section from a manufacturer's first hull."},
	{id = &"relic", name = "PRECURSOR RELIC", tier = &"artifact", cells = "1x1", value = 90,
		source = &"wreck", precursor = true, text = "A precursor fragment from a deep wreck."},
	{id = &"orphan_charts", name = "ORPHAN CHARTS", tier = &"contraband", cells = "1x1", value = 88,
		source = &"wreck", text = "Stolen survey charts of unclaimed shells."},
	# MINING: cut, cored or dug from rock and ice.
	{id = &"ballast_sand", name = "MOON DUST", tier = &"common", cells = "3x1", value = 8,
		source = &"mining", text = "Sacks of dust from the surface of a dead moon."},
	{id = &"iron_ore", name = "IRON ORE", tier = &"common", cells = "2x1", value = 9,
		source = &"mining", text = "Iron ore from a barren moon."},
	{id = &"water_ice", name = "WATER ICE", tier = &"common", cells = "2x2", value = 7,
		source = &"mining", text = "Ice cored from a frozen moon."},
	{id = &"nickel_slugs", name = "NICKEL SLUGS", tier = &"common", cells = "1x1", value = 11,
		source = &"mining", text = "Nickel-iron slugs cut from a belt asteroid."},
	{id = &"carbon_grit", name = "CARBON GRIT", tier = &"common", cells = "1x1", value = 10,
		source = &"mining", text = "Black grit from a carbon asteroid."},
	{id = &"core_samples", name = "CORE SAMPLES", tier = &"common", cells = "3x1", value = 12,
		source = &"mining", text = "Drill cores from a mineral survey."},
	{id = &"cobalt_ore", name = "COBALT ORE", tier = &"uncommon", cells = "2x1", value = 18,
		source = &"mining", text = "Cobalt ore from a belt asteroid."},
	{id = &"ammonia_ice", name = "AMMONIA ICE", tier = &"uncommon", cells = "2x1", value = 16,
		source = &"mining", text = "Ammonia ice from an outer moon."},
	{id = &"impact_glass", name = "IMPACT GLASS", tier = &"uncommon", cells = "1x1", value = 20,
		source = &"mining", text = "Glass beads from an impact crater."},
	{id = &"sulfur_cake", name = "SULFUR CAKE", tier = &"uncommon", cells = "1x1", value = 15,
		source = &"mining", text = "Sulfur scraped from a moon's hot vents."},
	{id = &"titanium_sand", name = "TITANIUM ORE", tier = &"uncommon", cells = "3x1", value = 17,
		source = &"mining", text = "Titanium ore from a barren world."},
	{id = &"platinum_ore", name = "PLATINUM ORE", tier = &"rare", cells = "1x1", value = 40,
		source = &"mining", text = "Platinum ore from a rock of solid metal."},
	{id = &"lithium_brine", name = "LITHIUM SALTS", tier = &"rare", cells = "2x1", value = 32,
		source = &"mining", text = "Lithium salts dug from under an ice crust."},
	{id = &"helium_dust", name = "HELIUM DUST", tier = &"rare", cells = "2x1", value = 34,
		source = &"mining", text = "Helium-rich dust from a barren moon."},
	{id = &"native_gold", name = "NATIVE GOLD", tier = &"rare", cells = "1x1", value = 38,
		source = &"mining", text = "Native gold cut from an asteroid."},
	{id = &"flare_glass", name = "FLARE GLASS", tier = &"epic", cells = "1x1", value = 81,
		source = &"mining", text = "Glass fused by a stellar flare."},
	{id = &"impact_iridium", name = "IMPACT IRIDIUM", tier = &"epic", cells = "1x1", value = 92,
		source = &"mining", text = "Pure iridium from an old impact site."},
	{id = &"core_slab", name = "CORE SLAB", tier = &"legendary", cells = "2x2", value = 200,
		source = &"mining", text = "A cut slab of a broken moon's core."},
	# First pictured non-1x1 artifacts: four cells at artifact value makes carrying a decision.
	# Why: docs/why/MaterialTable.md#pictured-materials
	{id = &"singing_tine", name = "SINGING TINE", tier = &"artifact", cells = "2x2", value = 210,
		source = &"mining", precursor = true, text = "A ringing precursor tine in a cradle."},
	{id = &"jumped_ore", name = "JUMPED ORE", tier = &"contraband", cells = "2x1", value = 72,
		source = &"mining", text = "Ore taken from someone else's claim."},
	# EVENT: cargo and stores an encounter hands over.
	{id = &"ration_bricks", name = "RATION BRICKS", tier = &"common", cells = "1x1", value = 8,
		source = &"event", text = "Pressed food bricks in sealed packs."},
	{id = &"cold_solder", name = "COLD SOLDER", tier = &"common", cells = "1x1", value = 10,
		source = &"event", text = "Solder that bonds in vacuum."},
	{id = &"patch_fabric", name = "PATCH FABRIC", tier = &"common", cells = "1x1", value = 9,
		source = &"event", text = "Self-sealing fabric for small hull holes."},
	{id = &"hull_paint", name = "HULL PAINT", tier = &"common", cells = "2x1", value = 11,
		source = &"event", text = "Hull paint in sealed drums."},
	{id = &"gasket_rings", name = "GASKET RINGS", tier = &"common", cells = "1x1", value = 10,
		source = &"event", text = "Spare hatch gaskets in sealed bags."},
	{id = &"frayed_line", name = "TOW LINE, USED", tier = &"common", cells = "2x1", value = 11,
		source = &"event", text = "A used tow line with a frayed end."},
	{id = &"dock_lamp", name = "DOCK LAMPS", tier = &"uncommon", cells = "2x1", value = 22,
		source = &"event", text = "Green approach lights from a dock."},
	{id = &"med_stores", name = "MED STORES", tier = &"uncommon", cells = "1x1", value = 21,
		source = &"event", text = "A sealed case of medical supplies."},
	{id = &"fuel_stabilizer", name = "FUEL STABILIZER", tier = &"uncommon", cells = "1x1", value = 18,
		source = &"event", text = "Drums of stabilizer for stored fuel."},
	{id = &"pressure_suits", name = "PRESSURE SUITS", tier = &"uncommon", cells = "2x1", value = 24,
		source = &"event", text = "Used pressure suits in a locker."},
	{id = &"mirror_foil", name = "MIRROR FOIL", tier = &"uncommon", cells = "2x1", value = 25,
		source = &"event", text = "A roll of reflective sun-shield foil."},
	{id = &"redline_teeth", name = "REDLINE SAW TEETH", tier = &"rare", cells = "1x1", value = 34,
		source = &"event", text = "Saw teeth made by Redline."},
	{id = &"cygnet_flux", name = "CYGNET FLUX", tier = &"rare", cells = "1x1", value = 33,
		source = &"event", text = "Board flux for Cygnet drone repairs."},
	{id = &"probate_ledger_stock", name = "LEDGER STOCK", tier = &"rare", cells = "1x1", value = 27,
		source = &"event", text = "Archive paper for Probate claim records."},
	{id = &"calyx_agar", name = "CALYX GROWTH GEL", tier = &"rare", cells = "1x1", value = 37,
		source = &"event", text = "Calyx's sterile growing gel, still sealed."},
	{id = &"vault_packing", name = "VAULT PACKING", tier = &"epic", cells = "1x1", value = 72,
		source = &"event", text = "Shielded crates with no port on the label."},
	{id = &"custodian_shadow", name = "INSTRUMENT SHADOW", tier = &"epic", cells = "1x1", value = 110,
		source = &"event", text = "A sensor plate burned near the core."},
	{id = &"closed_auction_lot", name = "SEALED LOT, UNCLAIMED", tier = &"legendary", cells = "2x2", value = 180,
		source = &"event", text = "A sealed Probate auction lot."},
	{id = &"caged_sphere", name = "CAGED SPHERE", tier = &"artifact", cells = "2x2", value = 240,
		source = &"event", precursor = true, text = "A precursor sphere held in a cage."},
	{id = &"void_labels", name = "VOID LABELS", tier = &"contraband", cells = "1x1", value = 64,
		source = &"event", text = "Blank cargo labels stamped as cleared."},
	# FIGHT: off a ship you beat, or out of your own plating.
	{id = &"spent_casings", name = "SPENT CASINGS", tier = &"common", cells = "2x1", value = 7,
		source = &"fight", text = "Spent shell casings from a gun deck."},
	{id = &"burnt_plate", name = "BURNT PLATE", tier = &"common", cells = "2x1", value = 9,
		source = &"fight", text = "Hull plate scorched by weapon fire."},
	{id = &"shrapnel", name = "SHRAPNEL", tier = &"common", cells = "1x1", value = 8,
		source = &"fight", text = "Torn metal cut out of your plating."},
	{id = &"barrel_liners", name = "BARREL LINERS", tier = &"common", cells = "3x1", value = 12,
		source = &"fight", text = "Worn liners from gun barrels."},
	{id = &"drone_husks", name = "DRONE HUSKS", tier = &"common", cells = "1x1", value = 11,
		source = &"fight", text = "Burned-out combat drone frames."},
	{id = &"loose_rounds", name = "LOOSE ROUNDS", tier = &"common", cells = "1x1", value = 13,
		source = &"fight", text = "Unfired rounds from a raider's guns."},
	{id = &"keel_bolts", name = "KEEL BOLTS", tier = &"uncommon", cells = "1x1", value = 22,
		source = &"fight", text = "Keel bolts from a raider's frame."},
	{id = &"gun_sight", name = "GUN SIGHT", tier = &"uncommon", cells = "1x1", value = 20,
		source = &"fight", text = "A cracked gun sight from a raider."},
	{id = &"suppressant_tank", name = "SUPPRESSANT TANK", tier = &"uncommon", cells = "2x1", value = 16,
		source = &"fight", text = "A half-used tank of fire suppressant."},
	{id = &"coolant_lines", name = "COOLANT LINES", tier = &"uncommon", cells = "3x1", value = 18,
		source = &"fight", text = "Coolant lines cut from a gun mount."},
	{id = &"gun_loader", name = "GUN LOADER", tier = &"uncommon", cells = "2x1", value = 24,
		source = &"fight", text = "A jammed gun loader from a raider."},
	{id = &"gyro_cores", name = "GYRO CORES", tier = &"rare", cells = "1x1", value = 36,
		source = &"fight", text = "Gyro cores from a ship's guidance system."},
	{id = &"armor_wedge", name = "ARMOR WEDGES", tier = &"rare", cells = "2x2", value = 44,
		source = &"fight", text = "Armor wedges cut to fit another hull."},
	{id = &"charge_wool", name = "CHARGE STRAND", tier = &"rare", cells = "2x1", value = 31,
		source = &"fight", text = "Coils of capacitor strand pulled from a beam gun."},
	{id = &"silent_bearings", name = "SILENT BEARINGS", tier = &"rare", cells = "1x1", value = 42,
		source = &"fight", text = "Bearings machined to run without noise."},
	{id = &"reactor_liner", name = "REACTOR LINER", tier = &"epic", cells = "2x2", value = 95,
		source = &"fight", text = "A used reactor liner from an enemy ship."},
	{id = &"hellbender_plate", name = "HELLBENDER PLATE", tier = &"epic", cells = "2x1", value = 105,
		source = &"fight", text = "Painted hull plate off the Hellbender."},
	{id = &"one_true_metre", name = "THE ONE TRUE METER", tier = &"legendary", cells = "1x1", value = 210,
		source = &"fight", text = "The bar three shells measure length by."},
	{id = &"closed_bay_key", name = "CLOSED-BAY KEY", tier = &"artifact", cells = "1x1", value = 140,
		source = &"fight", precursor = true, text = "A precursor key for the closed bays."},
	{id = &"unmarked_cells", name = "UNMARKED CELLS", tier = &"contraband", cells = "1x1", value = 95,
		source = &"fight", text = "Power cells with the serials ground off."},
	# FAUNA: shed by or cut from a leviathan.
	{id = &"shed_scale", name = "SHED PLATE", tier = &"common", cells = "2x1", value = 8,
		source = &"fauna", text = "Hide plate shed by a growing leviathan."},
	{id = &"shoal_shells", name = "HORN BUDS", tier = &"common", cells = "1x1", value = 9,
		source = &"fauna", text = "Horn buds shed by a leviathan calf."},
	{id = &"hide_offcuts", name = "HIDE OFFCUTS", tier = &"common", cells = "2x1", value = 10,
		source = &"fauna", text = "Offcuts of leviathan hide."},
	{id = &"heat_crust", name = "HEAT CRUST", tier = &"common", cells = "1x1", value = 11,
		source = &"fauna", text = "Crust from where a leviathan fed."},
	{id = &"egg_cases", name = "EGG CASES", tier = &"common", cells = "1x1", value = 10,
		source = &"fauna", text = "Empty egg cases left by a leviathan herd."},
	{id = &"rendered_fat", name = "DEEP FAT", tier = &"common", cells = "2x1", value = 9,
		source = &"fauna", text = "The heat-holding fat deep under a leviathan's hide."},
	{id = &"ear_stones", name = "BALANCE STONES", tier = &"uncommon", cells = "1x1", value = 18,
		source = &"fauna", text = "Stones from a leviathan's skull that keep its balance."},
	{id = &"sieve_plates", name = "FEEDING COMBS", tier = &"uncommon", cells = "3x1", value = 19,
		source = &"fauna", text = "Combs a leviathan strains dust through as it feeds."},
	{id = &"shoal_glue", name = "HIDE RESIN", tier = &"uncommon", cells = "1x1", value = 16,
		source = &"fauna", text = "Resin that seeps from a leviathan's hide."},
	{id = &"blood_salt", name = "BLOOD CRYSTALS", tier = &"uncommon", cells = "1x1", value = 21,
		source = &"fauna", text = "Crystals left when leviathan blood dries."},
	{id = &"spine_section", name = "SPINE SECTION", tier = &"uncommon", cells = "3x1", value = 23,
		source = &"fauna", text = "A length of calf spine."},
	{id = &"flank_ivory", name = "FLANK HORN", tier = &"rare", cells = "2x1", value = 40,
		source = &"fauna", text = "Horn from a leviathan's leading edge."},
	{id = &"grave_pollen", name = "GRAVE SPORES", tier = &"rare", cells = "1x1", value = 38,
		source = &"fauna", text = "Spores a leviathan sheds as it dies."},
	{id = &"song_crystal", name = "SONG CRYSTAL", tier = &"rare", cells = "1x1", value = 36,
		source = &"fauna", text = "A crystal from a leviathan's throat."},
	{id = &"gas_bladder", name = "LIFT SAC", tier = &"rare", cells = "2x2", value = 30,
		source = &"fauna", text = "An empty lift sac from a leviathan."},
	{id = &"singers_oil", name = "SONG GLAND", tier = &"epic", cells = "1x1", value = 78,
		source = &"fauna", text = "A gland from a singing leviathan's throat."},
	{id = &"nerve_silk", name = "NERVE CORD", tier = &"epic", cells = "1x1", value = 90,
		source = &"fauna", text = "Conductive cord cut from a leviathan's spine."},
	{id = &"heart_brine", name = "HEART FLUID", tier = &"legendary", cells = "2x1", value = 190,
		source = &"fauna", text = "Fluid drawn from a leviathan's heart."},
	{id = &"exotic", name = "EXOTIC TISSUE", tier = &"exotic", cells = "1x1", value = 45,
		source = &"fauna", text = "Tissue cut from a leviathan."},
	{id = &"tagged_organs", name = "TAGGED ORGANS", tier = &"contraband", cells = "1x1", value = 120,
		source = &"fauna", text = "Organs from a leviathan with a bounty tag."},
	# COSMIC: from stars, nebulae and gas giants.
	{id = &"nebula_dust", name = "NEBULA DUST", tier = &"common", cells = "2x1", value = 8,
		source = &"cosmic", text = "Carbon dust swept from a nebula."},
	{id = &"skimmed_hydrogen", name = "SKIMMED HYDROGEN", tier = &"common", cells = "2x2", value = 7,
		source = &"cosmic", text = "Raw hydrogen skimmed from a gas giant."},
	{id = &"star_soot", name = "STAR SOOT", tier = &"common", cells = "1x1", value = 9,
		source = &"cosmic", text = "Soot blown off a red giant."},
	{id = &"methane_frost", name = "METHANE FROST", tier = &"common", cells = "1x1", value = 10,
		source = &"cosmic", text = "Methane frost from a gas giant's clouds."},
	{id = &"wind_foil", name = "WIND FOIL", tier = &"common", cells = "2x1", value = 12,
		source = &"cosmic", text = "Collector foil exposed to a star's wind."},
	{id = &"storm_grit", name = "STORM GRIT", tier = &"common", cells = "1x1", value = 11,
		source = &"cosmic", text = "Grit pulled from a gas giant's storm."},
	{id = &"heavy_water", name = "HEAVY WATER", tier = &"uncommon", cells = "1x1", value = 22,
		source = &"cosmic", text = "Heavy water from the ice in a nebula."},
	{id = &"noble_gas", name = "NOBLE GAS", tier = &"uncommon", cells = "2x1", value = 17,
		source = &"cosmic", text = "Neon and argon bottled from a gas giant."},
	{id = &"nebula_iron", name = "NEBULA IRON", tier = &"uncommon", cells = "1x1", value = 20,
		source = &"cosmic", text = "Iron grains drawn out of nebula dust."},
	{id = &"star_plasma", name = "STAR PLASMA", tier = &"uncommon", cells = "1x1", value = 24,
		source = &"cosmic", text = "Blue star plasma in a magnetic bottle."},
	{id = &"comet_ice", name = "COMET ICE", tier = &"uncommon", cells = "2x2", value = 16,
		source = &"cosmic", text = "Dirty ice from a comet's tail."},
	{id = &"stellar_glass", name = "STELLAR GLASS", tier = &"rare", cells = "1x1", value = 38,
		source = &"cosmic", text = "Glass formed in a blue star's wind."},
	{id = &"pulse_quartz", name = "PULSE QUARTZ", tier = &"rare", cells = "1x1", value = 40,
		source = &"cosmic", text = "Quartz grown near a pulsar."},
	{id = &"heavy_silt", name = "HEAVY SILT", tier = &"rare", cells = "1x1", value = 34,
		source = &"cosmic", text = "Heavy-metal silt from an old red star."},
	{id = &"storm_diamonds", name = "STORM DIAMONDS", tier = &"rare", cells = "1x1", value = 42,
		source = &"cosmic", text = "Diamonds formed deep inside a gas giant."},
	{id = &"metallic_hydrogen", name = "METALLIC HYDROGEN", tier = &"epic", cells = "1x1", value = 105,
		source = &"cosmic", text = "Hydrogen crushed to metal in a gas giant."},
	{id = &"nova_ash", name = "NOVA ASH", tier = &"epic", cells = "1x1", value = 80,
		source = &"cosmic", text = "Ash from the shell of a nova."},
	{id = &"pulsar_crust", name = "PULSAR CRUST", tier = &"legendary", cells = "1x1", value = 230,
		source = &"cosmic", text = "A chip of pulsar crust in a field cage."},
	{id = &"one_kelvin_ice", name = "ONE-KELVIN ICE", tier = &"exotic", cells = "1x1", value = 60,
		source = &"cosmic", text = "Ice from a nebula colder than empty space."},
	{id = &"trapped_antimatter", name = "TRAPPED ANTIMATTER", tier = &"contraband", cells = "1x1", value = 110,
		source = &"cosmic", text = "Antimatter held in a trap with no license."},
	# NAMED: written for one encounter and handed over by id, never rolled.
	# Why: docs/why/MaterialTable.md#named-pool
	{id = &"survey_film", name = "SURVEY FILM", tier = &"rare", cells = "1x1", value = 35,
		source = &"event", named = true, text = "A roll of survey film that was never developed."},
	{id = &"magnetar_silt", name = "MAGNETAR SILT", tier = &"exotic", cells = "1x1", value = 48,
		source = &"cosmic", named = true, text = "Dense magnetic silt from a magnetar."},
	{id = &"sweep_glass", name = "SWEEP GLASS", tier = &"exotic", cells = "1x1", value = 49,
		source = &"wreck", named = true, text = "Glaze scraped from a pulsar-burned hull."},
	{id = &"corona_amber", name = "CORONA SLAG", tier = &"exotic", cells = "1x1", value = 55,
		source = &"wreck", named = true, text = "Glassy slag from a wreck scorched by a star."},
	{id = &"hide_scrap", name = "HIDE SCRAP", tier = &"exotic", cells = "2x1", value = 41,
		source = &"fauna", named = true, text = "Shed leviathan hide full of junk."},
	{id = &"last_broadcast", name = "LAST BROADCAST", tier = &"artifact", cells = "1x1", value = 150,
		source = &"event", named = true, text = "A recording of a relay's last number."},
	{id = &"counting_core", name = "COUNTING CORE", tier = &"artifact", cells = "1x1", value = 190,
		source = &"event", named = true, text = "A warm core that counts down."},
]
