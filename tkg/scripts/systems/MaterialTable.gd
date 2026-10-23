class_name MaterialTable

## Everything a system can hand you that is not a module.
##
## DRAFT 1, 68 items, authored 2026-08-27 (two artifacts added 2026-09-04). `docs/briefs/MATERIALS_NOTE.md` is
## the contract
## this is built to and is worth reading before editing: materials are becoming a
## second ITEM CLASS in the existing spatial hold -- tiers, shaped cells, sold at
## stations -- not a new storage system and not a currency. `RunState` still says
## CREDITS ARE THE ONLY CURRENCY; these sell, they never price.
##
## WHAT IS REAL TONIGHT AND WHAT IS NOT. The catalogue is real: ids, tiers,
## shapes, values and text all ship. The ITEM is not -- there is no instance, no
## hold cell, no sale screen. `grant()` therefore rolls a real row and pays its
## `value` in credits, which is the shim `MATERIALS_NOTE` specifies in as many
## words: one function body to swap when the hold learns about items.
##
## `cells` is carried unused for exactly that reason. It is the shape the item
## will occupy, it was authored with the rest of the row, and deriving it later
## from a name would be guessing at what somebody already decided.
##
## THE ZERO-MIGRATION RULE. `exotic` and `relic` are live ids in the material
## ledger today and appear here with their values and text unchanged, so recipes,
## combat drops and saved runs keep working. Every other row is additive.
##
## `drops` is a LOOT-TABLE KEY and never a fiction: which table a row rolls from.
## Five of them roll; `named` is the sixth and nothing asks for it -- see `NAMED`.
## Precursor pieces sit in `wreck` because the lore says fragments come off deep
## wrecks and nowhere else.
##
##     tier    artifact 7 · common 16 · contraband 8 · epic 9 · exotic 10 · legendary 5 · rare 13
##     table   event 20 · fauna 8 · fight 7 · mining 2 · named 7 · wreck 24
##     cells   1x1 42 · 2x1 14 · 2x2 6 · 3x1 4 · 4x1 2
##
## WHAT LEAVING COSTS THE TABLES, because it is a real thinning at the top and
## not only tidiness: `event` loses its only ARTIFACT and `wreck` both of its
## EXOTICS. Nothing can roll empty -- every table keeps a grade open at every
## depth, and its commons stand in when nothing else is (see `roll`) -- but a
## deep-galaxy event can no longer pay out a hundred and ninety credits in one
## row. If it should, the answer is a generic artifact authored for the table,
## not a story item borrowed back into it.
##
## MINING IS THE THIN TABLE and is known to be -- the mining-flavoured options
## are where its rolls come from, and the next materials batch should feed it.


## THE POOL THAT NOTHING ROLLS. A material written FOR one encounter is handed
## over by name -- `{material_id = &"counting_core"}` -- and has no business in a
## generic table: a delivery drone paid out COUNTING CORE, whose own flavour text
## is about a relay counting down on an approach three encounters away, because
## it was sitting in `event` alongside the ration bricks.
##
## `roll` filters on `drops`, so parking them under a table nobody asks for is
## the whole mechanism. They are still reachable, and only the way they were
## written to be reached.
const NAMED := &"named"

## The lowest TIER (`MapGen.tier`, 1-5) each grade may roll at.
##
## THE SAME GATES `LootGen` USES FOR MODULES, deliberately and by reference:
## rarity is a property of where you are standing, so a rim system cannot hand
## out the good stuff and the deep galaxy is worth the trip. Artifact opens with
## Legendary, the top of the manufactured ladder.
##
## THEY WERE DANGER, AND THAT WAS THE BUG. Authored as 3 / 4 / 4 against RAW
## danger (742bb953, Aug 27), nine days after danger widened to 1-10 and
## `roll_module` began reading it through `tier()` (6226d1d0, Aug 18). Same
## numbers, different scale: Epic materials opened at danger 3 and Legendary
## and Artifact at 4, against Epic and Legendary modules at 5 and 7.
##
## Two exceptions, both from `MATERIALS_NOTE`. CONTRABAND is ungated because its
## gate IS the risk -- security scans care what you are carrying, so a rim run
## with contraband aboard is already paying for it. EXOTIC is ungated because it
## is live today and gating it would be a migration.
const TIER_MIN: Dictionary = {
	&"epic": LootGen.EPIC_TIER,
	&"legendary": LootGen.LEGENDARY_TIER,
	&"artifact": LootGen.LEGENDARY_TIER,
}

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


## One row from `table`, respecting `danger`. Empty if the table has nothing legal.
##
## A table with nothing but commons open this deep pays one of its commons
## rather than nothing, as `LootGen.roll_module` does: the no-common rule thins a
## pool, it never empties one.
static func roll(table: StringName, danger: int,
		r: RandomNumberGenerator) -> Dictionary:
	var t := MapGen.tier(danger)
	var pool: Array[Dictionary] = []
	var commons: Array[Dictionary] = []
	for row in all():
		if StringName(row.drops) != table:
			continue
		var tier := StringName(row.tier)
		if not _opens(tier, t):
			continue
		if admits(tier, danger):
			pool.append(row)
		else:
			commons.append(row)
	if pool.is_empty():
		pool = commons
	if pool.is_empty():
		return {}
	return pool[r.randi() % pool.size()]


## Hand one over, and say what it was.
##
## THE SHIM IS GONE, and this is the body it was always going to become. It paid
## the row's `value` in credits because the hold could not carry an object; the
## hold can, so this makes the object and puts it in the system beside you --
## `RunState.add_material` -- and a station is where it turns back into money.
##
## The note promised no option, no screen and no policy would have to be touched
## when this changed. That held: the payload still says `{material = &"wreck"}`.
static func grant(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	Run.add_material(StringName(row.get("id", &"")), 1)
	return String(row.get("name", ""))


static func by_id(id: StringName) -> Dictionary:
	for row in all():
		if StringName(row.id) == id:
			return row
	return {}


static var _all: Array[Dictionary] = []


## Built once. `EventTable.build_all()` rebuilding its dictionaries on every call
## is the pattern this exists not to repeat.
static func all() -> Array[Dictionary]:
	if not _all.is_empty():
		return _all
	_all = [
		{id = &"deck_plate", name = "DECK PLATE", tier = &"common", cells = "2x1",
			value = 10, drops = &"wreck",
			text = "Standard tread, worn smooth down the middle. Every dock buys it without asking where it came from."},
		{id = &"coil_stock", name = "COIL STOCK", tier = &"common", cells = "1x1",
			value = 9, drops = &"wreck",
			text = "Copper on a spool, gauge stamped every metre. The stamp is worth more than the copper."},
		{id = &"ballast_sand", name = "BALLAST SAND", tier = &"common", cells = "3x1",
			value = 8, drops = &"mining",
			text = "Graded regolith in bags. It is worth little, but someone always needs mass."},
		{id = &"ration_bricks", name = "RATION BRICKS", tier = &"common", cells = "1x1",
			value = 8, drops = &"event",
			text = "Bricks of food with every nutrient. Each manufacturer prints ALMOND on them, and none of them contain any."},
		{id = &"frayed_line", name = "TOW LINE, USED", tier = &"common", cells = "2x1",
			value = 11, drops = &"wreck",
			text = "Rated for four hundred tonnes, once. The fray tells you which end let go."},
		{id = &"bearing_race", name = "BEARING RACES", tier = &"common", cells = "1x1",
			value = 12, drops = &"wreck",
			text = "A crate of bearing races. Most moving parts on a ship turn on one."},
		{id = &"cold_solder", name = "COLD SOLDER", tier = &"common", cells = "1x1",
			value = 10, drops = &"event",
			text = "Solder that bonds in vacuum and cures in shade. The tin warns NOT FOR HULL USE."},
		{id = &"filter_stacks", name = "FILTER STACKS", tier = &"common", cells = "2x1",
			value = 12, drops = &"wreck",
			text = "Part-used air filters, still holding whatever they caught."},
		{id = &"bulk_girder", name = "BULK GIRDER", tier = &"common", cells = "4x1",
			value = 14, drops = &"wreck",
			text = "Girder sold by the metre. It is heavy to haul and only worth much once delivered."},
		{id = &"patch_fabric", name = "PATCH FABRIC", tier = &"common", cells = "1x1",
			value = 9, drops = &"event",
			text = "Self-sealing weave for small holes, up to a palm across. It will not seal anything larger."},
		{id = &"gasket_rings", name = "GASKET RINGS", tier = &"common", cells = "1x1",
			value = 10, drops = &"wreck",
			text = "Every hatch leaks past one of these sooner or later, so ships always need more."},
		{id = &"scrap_optics", name = "SCRAP OPTICS", tier = &"common", cells = "1x1",
			value = 13, drops = &"wreck",
			text = "Cracked lenses and one good one. The one good one pays for the crate."},
		{id = &"hull_paint", name = "HULL PAINT", tier = &"common", cells = "2x1",
			value = 11, drops = &"event",
			text = "Forty units covers a light hull. Out here, paint wears off and needs replacing."},
		{id = &"union_pipe", name = "UNION PIPE", tier = &"common", cells = "3x1",
			value = 12, drops = &"wreck",
			text = "Threaded both ends, bent in the middle. The bend is why it is for sale."},
		{id = &"mooring_pins", name = "MOORING PINS", tier = &"common", cells = "1x1",
			value = 9, drops = &"event",
			text = "Used pins that held a ship to a dock. Sold as seen."},
		{id = &"packing_foam", name = "PACKING FOAM", tier = &"common", cells = "2x2",
			value = 7, drops = &"event",
			text = "Light, bulky foam for packing fragile cargo. It always sells."},
		{id = &"verity_gaskets", name = "VERITY GASKETS", tier = &"rare", cells = "1x1",
			value = 30, drops = &"wreck",
			text = "Verity gaskets outlast the seal, the hatch and the owner."},
		{id = &"solari_lens", name = "SOLARI LENS STOCK", tier = &"rare", cells = "1x1",
			value = 38, drops = &"wreck",
			text = "Lenses ground for studying stars up close, as Solari does."},
		{id = &"redline_teeth", name = "REDLINE SAW TEETH", tier = &"rare", cells = "1x1",
			value = 34, drops = &"event",
			text = "Cutting teeth for a breaker's saw. Redline sells them by weight and buys them back blunt."},
		{id = &"mirror_foil", name = "MIRROR FOIL", tier = &"rare", cells = "2x1",
			value = 29, drops = &"wreck",
			text = "Reflects most of what a star can do at this range. Creases where somebody folded it in a hurry."},
		{id = &"gyro_cores", name = "GYRO CORES", tier = &"rare", cells = "1x1",
			value = 36, drops = &"fight",
			text = "Still spinning in the crate. They spin for years after the ship stops."},
		{id = &"charge_wool", name = "CHARGE WOOL", tier = &"rare", cells = "2x1",
			value = 31, drops = &"wreck",
			text = "Baled capacitor fibre. Wear gloves to handle it."},
		{id = &"cygnet_flux", name = "CYGNET FLUX", tier = &"rare", cells = "1x1",
			value = 33, drops = &"event",
			text = "Catalyst for cracking fuel, enough for one refinery. Cygnet sells it a little at a time."},
		{id = &"keel_bolts", name = "KEEL BOLTS", tier = &"rare", cells = "1x1",
			value = 28, drops = &"fight",
			text = "The eight bolts that hold a keel. These are used, so they sell cheap."},
		{id = &"survey_film", name = "SURVEY FILM", tier = &"rare", cells = "1x1",
			value = 35, drops = NAMED,
			text = "Survey film, used once and never developed. Whoever took it never looked at what it shows."},
		{id = &"probate_ledger_stock", name = "LEDGER STOCK", tier = &"rare", cells = "1x1",
			value = 27, drops = &"event",
			text = "Probate's archival paper, acid-free for four centuries. It is made to outlast the people it records."},
		{id = &"dock_lamp", name = "DOCK LAMPS", tier = &"rare", cells = "2x1",
			value = 26, drops = &"event",
			text = "Green dock approach lights. Crews on long runs hang one in the cabin."},
		{id = &"calyx_agar", name = "CALYX AGAR", tier = &"rare", cells = "1x1",
			value = 37, drops = &"event",
			text = "Growth medium, sterile until opened. Calyx sells the plate and rents what grows on it."},
		{id = &"armor_wedge", name = "ARMOUR WEDGES", tier = &"rare", cells = "2x2",
			value = 44, drops = &"fight",
			text = "Ablative sections cut for another hull. Refitting takes a day of grinding, and they never quite match."},
		{id = &"korvan_cold_iron", name = "KORVAN COLD IRON", tier = &"epic", cells = "2x1",
			value = 85, drops = &"wreck",
			text = "Poured in vacuum and cooled over a year. Slow-cooled iron rings differently, and Korvan will not say why."},
		{id = &"reactor_liner", name = "REACTOR LINER", tier = &"epic", cells = "2x2",
			value = 95, drops = &"wreck",
			text = "A liner rated for the inside of a star, lightly used. The certificate comes with it."},
		{id = &"navigators_gel", name = "NAVIGATOR'S GEL", tier = &"epic", cells = "1x1",
			value = 78, drops = &"wreck",
			text = "Inertial reference gel from a dead ship. It still holds every course that ship flew."},
		{id = &"sweep_mirrors", name = "SWEEP MIRRORS", tier = &"epic", cells = "3x1",
			value = 88, drops = &"wreck",
			text = "Survived inside a pulsar's arc long enough to be worth grinding flat again. The tint does not polish out."},
		{id = &"hellbender_chitin", name = "HELLBENDER CHITIN", tier = &"epic", cells = "2x1",
			value = 110, drops = &"fight",
			text = "A plate off the Hellbender, which eats systems. Few pilots go back for a second one."},
		{id = &"vault_packing", name = "VAULT PACKING", tier = &"epic", cells = "1x1",
			value = 72, drops = &"event",
			text = "Crating for heat delivery, marked with a destination that is not a place. On paper it is always empty."},
		{id = &"silent_bearings", name = "SILENT BEARINGS", tier = &"epic", cells = "1x1",
			value = 76, drops = &"fight",
			text = "Bearings machined to run without a sound."},
		{id = &"flare_glass", name = "FLARE GLASS", tier = &"epic", cells = "1x1",
			value = 81, drops = &"mining",
			text = "Sand fused in a storm into glass that should not be possible. Solari buys every piece and logs each one as an incident."},
		{id = &"grown_conduit", name = "GROWN CONDUIT", tier = &"epic", cells = "3x1",
			value = 90, drops = &"fauna",
			text = "Calyx trains it along a frame like a vine. Cut lengths keep growing, slowly, toward the nearest reactor."},
		{id = &"one_true_metre", name = "THE ONE TRUE METRE", tier = &"legendary", cells = "1x1",
			value = 210, drops = &"event",
			text = "The bar every scale in three shells is set by. Whoever holds it sets the weights for all three."},
		{id = &"first_keel", name = "FIRST-POUR KEEL SECTION", tier = &"legendary", cells = "4x1",
			value = 240, drops = &"wreck",
			text = "From the first hull a manufacturer ever poured, any of them. They buy these back at any price and melt them in private."},
		{id = &"custodian_shadow", name = "INSTRUMENT SHADOW", tier = &"legendary", cells = "1x1",
			value = 260, drops = &"event",
			text = "A sensor plate burned with the shadow of something that passed between it and the core. The shape matches nothing, and no one has a better picture."},
		{id = &"hellbender_tooth", name = "HELLBENDER TOOTH", tier = &"legendary", cells = "2x1",
			value = 230, drops = &"fight",
			text = "It was growing back before it hit the deck. Sell it before it grows any more."},
		{id = &"closed_auction_lot", name = "SEALED LOT, UNCLAIMED", tier = &"legendary", cells = "2x2",
			value = 180, drops = &"event",
			text = "A Probate seal no one alive can open legally. Sealed, it is worth this. Opened, it may be worth much more or much less."},
		{id = &"exotic", name = "Exotic", tier = &"exotic", cells = "1x1",
			value = 45, drops = &"fauna",
			text = "Megafauna organs and what pulsars leave behind. None of it is made in a yard."},
		{id = &"singers_oil", name = "SINGER'S OIL", tier = &"exotic", cells = "1x1",
			value = 58, drops = &"fauna",
			text = "Oil from the megafauna that sing. It burns warm and even, and the pod remembers who rendered it."},
		{id = &"flank_ivory", name = "FLANK IVORY", tier = &"exotic", cells = "2x1",
			value = 52, drops = &"fauna",
			text = "Ivory from a megafauna's leading edge, worn smooth by travel. It carves like old bone."},
		{id = &"heart_brine", name = "HEART BRINE", tier = &"exotic", cells = "1x1",
			value = 62, drops = &"fauna",
			text = "Fluid from a four-chambered heart the size of a shuttle. It stays warm for months, and manufacturers buy it for that."},
		{id = &"nerve_silk", name = "NERVE SILK", tier = &"exotic", cells = "1x1",
			value = 66, drops = &"fauna",
			text = "Conductive thread from along a spine longer than your ship. Calyx pays double and asks you to sign something."},
		{id = &"magnetar_silt", name = "MAGNETAR SILT", tier = &"exotic", cells = "1x1",
			value = 48, drops = NAMED,
			text = "Fine, dense silt that lines up with anything magnetic near it. Refiners bid on it sight unseen."},
		{id = &"sweep_glass", name = "SWEEP GLASS", tier = &"exotic", cells = "1x1",
			value = 49, drops = NAMED,
			text = "Glaze a pulsar's beam leaves on a hull, eleven seconds at a time, over centuries. It scrapes off in strange colours."},
		{id = &"corona_amber", name = "CORONA AMBER", tier = &"exotic", cells = "1x1",
			value = 55, drops = NAMED,
			text = "Star-fused resin, found only on wrecks that stayed too close. Something was alive in it, and it may still be."},
		{id = &"hide_scrap", name = "HIDE SCRAP", tier = &"exotic", cells = "2x1",
			value = 41, drops = NAMED,
			text = "Shed hide with forty years of accreted junk in it. The junk is worth sorting. The hide is worth more."},
		{id = &"grave_pollen", name = "GRAVE POLLEN", tier = &"exotic", cells = "1x1",
			value = 47, drops = &"fauna",
			text = "Seed dust a megafauna releases once, when it dies. It drifts toward warmth, such as your ship."},
		{id = &"unmarked_cells", name = "UNMARKED CELLS", tier = &"contraband", cells = "1x1",
			value = 95, drops = &"fight",
			text = "Power cells with the serials ground off. Each one holds a perfect charge, better than any legal cell."},
		{id = &"pressed_relics", name = "PRESSED RELICS", tier = &"contraband", cells = "1x1",
			value = 80, drops = &"event",
			text = "Fake precursor fragments. Real ones cannot be made any more, so a new one is a fake."},
		{id = &"grey_coolant", name = "GREY COOLANT", tier = &"contraband", cells = "2x1",
			value = 74, drops = &"event",
			text = "Coolant cut with something cheaper that works better. All manufacturers ban it, and their ships all run cooler than spec."},
		{id = &"tagged_organs", name = "TAGGED ORGANS", tier = &"contraband", cells = "1x1",
			value = 120, drops = &"fauna",
			text = "Bounty-tagged megafauna organs. Selling them states, in writing, where you got them."},
		{id = &"hot_plate", name = "REGISTERED PLATE", tier = &"contraband", cells = "2x1",
			value = 70, drops = &"event",
			text = "Deck plating with a seized hull's registry still in the grain. Scrubbing it off is illegal, and leaving it on is worse."},
		{id = &"counterfeit_seals", name = "COUNTERFEIT SEALS", tier = &"contraband", cells = "1x1",
			value = 130, drops = &"event",
			text = "Fake Korvan delivery seals that pass for real. Korvan treats any seal that passes as its own property."},
		{id = &"orphan_charts", name = "ORPHAN CHARTS", tier = &"contraband", cells = "1x1",
			value = 88, drops = &"wreck",
			text = "Survey charts of shells no manufacturer has claimed. Owning them is legal, but reading them is not."},
		{id = &"void_labels", name = "VOID LABELS", tier = &"contraband", cells = "1x1",
			value = 64, drops = &"event",
			text = "Blank cargo labels, pre-approved. What you write on them stands until a scan proves it false."},
		{id = &"relic", name = "Relic", tier = &"artifact", cells = "1x1",
			value = 90, drops = &"wreck",
			text = "A precursor fragment. Whoever made it is gone, and no one knows how to make more."},
		{id = &"closed_bay_key", name = "CLOSED-BAY KEY", tier = &"artifact", cells = "1x1",
			value = 140, drops = &"wreck",
			text = "It fits the bays that open onto nothing. Turning it does something, but no one agrees on what."},
		{id = &"wrong_mass", name = "WRONG MASS", tier = &"artifact", cells = "1x1",
			value = 165, drops = &"wreck",
			text = "Fist-sized, weighs like a hull section, and the weight moves a half-second after you do. The deep wrecks it comes off are balanced the same way."},
		{id = &"last_broadcast", name = "LAST BROADCAST", tier = &"artifact", cells = "1x1",
			value = 150, drops = NAMED,
			text = "A recording of the last number, sent forty-one years after the one before it. Buyers pay for what plays after the number."},
		{id = &"counting_core", name = "COUNTING CORE", tier = &"artifact", cells = "1x1",
			value = 190, drops = NAMED,
			text = "Warm after all this time, and still counting down. The number is smaller than it was when you picked it up."},
		# THE FIRST TWO MATERIALS WITH A PICTURE, and the first artifacts that are
		# not 1x1. Both were drawn as module art and were too good to spend on a
		# plate you bolt on and stop looking at -- a thing you CARRY and decide
		# whether to keep four cells clear for is the better job for them.
		#
		# 2x2 at artifact value is the whole point: four cells is a quarter of a
		# small hold, so carrying one out is a decision rather than a pickup.
		{id = &"singing_tine", name = "SINGING TINE", tier = &"artifact", cells = "2x2",
			value = 210, drops = &"wreck",
			text = "One tine in a cradle, already ringing when it was found. Set it on the deck and the plates ring with it. It has never been heard to stop."},
		{id = &"caged_sphere", name = "CAGED SPHERE", tier = &"artifact", cells = "2x2",
			value = 240, drops = &"wreck",
			text = "The cage was built around it where it sat. It has never touched the arms or drifted off centre, through every burn you have made."},
	]
	return _all
