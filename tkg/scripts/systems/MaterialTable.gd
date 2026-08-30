class_name MaterialTable

## Everything a system can hand you that is not a module.
##
## DRAFT 1, 64 items, authored 2026-08-27. `docs/briefs/MATERIALS_NOTE.md` is
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
##     tier    artifact 4 · common 16 · contraband 8 · epic 9 · exotic 9 · legendary 5 · rare 13
##     table   event 20 · fauna 8 · fight 7 · mining 2 · wreck 22 · named 5
##     cells   1x1 40 · 2x1 14 · 2x2 4 · 3x1 4 · 4x1 2
##
## WHAT LEAVING COSTS THE TABLES, because it is a real thinning at the top and
## not only tidiness: `event` loses its only ARTIFACT and `wreck` both of its
## EXOTICS. Nothing can roll empty -- every table keeps ungated commons and
## rares, and `admits` is a floor rather than a band -- but a deep-galaxy event
## can no longer pay out a hundred and ninety credits in one row. If it should,
## the answer is a generic artifact authored for the table, not a story item
## borrowed back into it.
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

## Which tiers a system of this danger may roll.
##
## THE SAME SHAPE `LootGen` USES FOR MODULES, deliberately: rarity is a property
## of where you are standing, so a rim system cannot hand out the good stuff and
## the deep galaxy is worth the trip.
##
## Two exceptions, both from `MATERIALS_NOTE`. CONTRABAND is ungated because its
## gate IS the risk -- security scans care what you are carrying, so a rim run
## with contraband aboard is already paying for it. EXOTIC is ungated because it
## is live today and gating it would be a migration.
static func admits(tier: StringName, danger: int) -> bool:
	match tier:
		&"epic": return danger >= 3
		&"legendary": return danger >= 4
		&"artifact": return danger >= 4
	return true


## One row from `table`, respecting `danger`. Empty if the table has nothing legal.
static func roll(table: StringName, danger: int,
		r: RandomNumberGenerator) -> Dictionary:
	var pool: Array[Dictionary] = []
	for row in all():
		if StringName(row.drops) != table:
			continue
		if not admits(StringName(row.tier), danger):
			continue
		pool.append(row)
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
			text = "Standard tread, worn smooth down the middle. Every dock buys it and no dock asks where it came from."},
		{id = &"coil_stock", name = "COIL STOCK", tier = &"common", cells = "1x1",
			value = 9, drops = &"wreck",
			text = "Copper on a spool, gauge stamped every metre. The stamp is worth more than the copper."},
		{id = &"ballast_sand", name = "BALLAST SAND", tier = &"common", cells = "3x1",
			value = 8, drops = &"mining",
			text = "Regolith, graded and bagged. Exactly as valuable as it sounds, but somebody always needs mass."},
		{id = &"ration_bricks", name = "RATION BRICKS", tier = &"common", cells = "1x1",
			value = 8, drops = &"event",
			text = "Nutritionally complete. The manufacturers agree on nothing, but they all print ALMOND on these, and none contain any."},
		{id = &"frayed_line", name = "TOW LINE, USED", tier = &"common", cells = "2x1",
			value = 11, drops = &"wreck",
			text = "Rated for four hundred tonnes, once. The fray tells you which end let go."},
		{id = &"bearing_race", name = "BEARING RACES", tier = &"common", cells = "1x1",
			value = 12, drops = &"wreck",
			text = "A crate of circles. Civilisation is mostly circles, when you strip it."},
		{id = &"cold_solder", name = "COLD SOLDER", tier = &"common", cells = "1x1",
			value = 10, drops = &"event",
			text = "Bonds in vacuum, cures in shade. The tin says NOT FOR HULL USE in the tone of a company that has been sued."},
		{id = &"filter_stacks", name = "FILTER STACKS", tier = &"common", cells = "2x1",
			value = 12, drops = &"wreck",
			text = "Air filters, part-used. What they caught stays classified as texture."},
		{id = &"bulk_girder", name = "BULK GIRDER", tier = &"common", cells = "4x1",
			value = 14, drops = &"wreck",
			text = "Sold by the metre, hauled by the regretful. The value is in delivery, which is your problem now."},
		{id = &"patch_fabric", name = "PATCH FABRIC", tier = &"common", cells = "1x1",
			value = 9, drops = &"event",
			text = "Self-sealing weave for holes you can cover with a hand. For larger holes, the label recommends a larger label."},
		{id = &"gasket_rings", name = "GASKET RINGS", tier = &"common", cells = "1x1",
			value = 10, drops = &"wreck",
			text = "Every hatch in the galaxy leaks past one of these eventually. Stock accordingly."},
		{id = &"scrap_optics", name = "SCRAP OPTICS", tier = &"common", cells = "1x1",
			value = 13, drops = &"wreck",
			text = "Cracked lenses and one good one. The one good one pays for the crate."},
		{id = &"hull_paint", name = "HULL PAINT", tier = &"common", cells = "2x1",
			value = 11, drops = &"event",
			text = "Forty units covers a light hull. Most of your paint is a known unit of loss out here."},
		{id = &"union_pipe", name = "UNION PIPE", tier = &"common", cells = "3x1",
			value = 12, drops = &"wreck",
			text = "Threaded both ends, bent in the middle. The bend is why it is for sale."},
		{id = &"mooring_pins", name = "MOORING PINS", tier = &"common", cells = "1x1",
			value = 9, drops = &"event",
			text = "Holds a ship to a dock. Held, anyway. Sold as-seen."},
		{id = &"packing_foam", name = "PACKING FOAM", tier = &"common", cells = "2x2",
			value = 7, drops = &"event",
			text = "Light, bulky, and briefly essential around anything fragile. Buyers pretend not to need it, then buy it."},
		{id = &"verity_gaskets", name = "VERITY GASKETS", tier = &"rare", cells = "1x1",
			value = 30, drops = &"wreck",
			text = "Outlasts the seal, the hatch, and the warranty holder. Verity counts that as a testimonial."},
		{id = &"solari_lens", name = "SOLARI LENS STOCK", tier = &"rare", cells = "1x1",
			value = 38, drops = &"wreck",
			text = "Ground for looking at stars closely, which is a Solari habit that keeps not killing them."},
		{id = &"redline_teeth", name = "REDLINE SAW TEETH", tier = &"rare", cells = "1x1",
			value = 34, drops = &"event",
			text = "Cutting teeth for a breaker's saw. Redline sells them by weight and buys them back blunt, which tells you the margin."},
		{id = &"mirror_foil", name = "MIRROR FOIL", tier = &"rare", cells = "2x1",
			value = 29, drops = &"wreck",
			text = "Reflects most of what a star can do at this range. Creases where somebody folded it in a hurry."},
		{id = &"gyro_cores", name = "GYRO CORES", tier = &"rare", cells = "1x1",
			value = 36, drops = &"fight",
			text = "Still spinning in the crate. They spin for years after the ship stops."},
		{id = &"charge_wool", name = "CHARGE WOOL", tier = &"rare", cells = "2x1",
			value = 31, drops = &"wreck",
			text = "Capacitor fibre, baled. Handle with the gloves you should already be wearing."},
		{id = &"cygnet_flux", name = "CYGNET FLUX", tier = &"rare", cells = "1x1",
			value = 33, drops = &"event",
			text = "Cracking catalyst, one refinery's worth. Cygnet meters it out like an apology."},
		{id = &"keel_bolts", name = "KEEL BOLTS", tier = &"rare", cells = "1x1",
			value = 28, drops = &"fight",
			text = "The eight bolts a hull is allowed to trust. These came off a hull, which is the discount."},
		{id = &"survey_film", name = "SURVEY FILM", tier = &"rare", cells = "1x1",
			value = 35, drops = &"named",
			text = "Exposed once, never developed. Whoever shot it wanted a record more than they wanted to know."},
		{id = &"probate_ledger_stock", name = "LEDGER STOCK", tier = &"rare", cells = "1x1",
			value = 27, drops = &"event",
			text = "Probate's archival sheet, acid-free for four centuries. The paperwork is designed to outlive the subject, and does."},
		{id = &"dock_lamp", name = "DOCK LAMPS", tier = &"rare", cells = "2x1",
			value = 26, drops = &"event",
			text = "Approach lighting, the exact green of arriving somewhere. Half the galaxy's last good memory is this colour."},
		{id = &"calyx_agar", name = "CALYX AGAR", tier = &"rare", cells = "1x1",
			value = 37, drops = &"event",
			text = "Growth medium, sterile until opened. Calyx sells the plate and rents what grows on it."},
		{id = &"armor_wedge", name = "ARMOUR WEDGES", tier = &"rare", cells = "2x2",
			value = 44, drops = &"fight",
			text = "Ablative sections cut for somebody else's hull. Refitting them is a day of grinding and a week of pretending they match."},
		{id = &"korvan_cold_iron", name = "KORVAN COLD IRON", tier = &"epic", cells = "2x1",
			value = 85, drops = &"wreck",
			text = "Poured in vacuum, cooled over a year. Korvan will not say why the slow ones ring differently, and they do."},
		{id = &"reactor_liner", name = "REACTOR LINER", tier = &"epic", cells = "2x2",
			value = 95, drops = &"wreck",
			text = "Rated for the inside of a star, lightly used by one. Certification transfers; confidence is sold separately."},
		{id = &"navigators_gel", name = "NAVIGATOR'S GEL", tier = &"epic", cells = "1x1",
			value = 78, drops = &"wreck",
			text = "Inertial reference suspension. It remembers every course the dead ship held, if you know how to ask."},
		{id = &"sweep_mirrors", name = "SWEEP MIRRORS", tier = &"epic", cells = "3x1",
			value = 88, drops = &"wreck",
			text = "Survived inside a pulsar's arc long enough to be worth grinding flat again. The tint does not polish out."},
		{id = &"hellbender_chitin", name = "HELLBENDER CHITIN", tier = &"epic", cells = "2x1",
			value = 110, drops = &"fight",
			text = "A plate off the thing that eats systems. It is not for sale twice, because nobody goes back for more."},
		{id = &"vault_packing", name = "VAULT PACKING", tier = &"epic", cells = "1x1",
			value = 72, drops = &"event",
			text = "Crating rated for heat delivery, stencilled with a destination that is not a location. Empty. Officially always empty."},
		{id = &"silent_bearings", name = "SILENT BEARINGS", tier = &"epic", cells = "1x1",
			value = 76, drops = &"fight",
			text = "Machined to run without a sound. Ships fitted with these get boarded politely, from habit."},
		{id = &"flare_glass", name = "FLARE GLASS", tier = &"epic", cells = "1x1",
			value = 81, drops = &"mining",
			text = "Sand fused mid-storm into something optically impossible. Solari buys every piece and files every purchase as an incident."},
		{id = &"grown_conduit", name = "GROWN CONDUIT", tier = &"epic", cells = "3x1",
			value = 90, drops = &"fauna",
			text = "Calyx trains it along a frame like a vine. Cut lengths keep growing, slowly, toward the nearest reactor."},
		{id = &"one_true_metre", name = "THE ONE TRUE METRE", tier = &"legendary", cells = "1x1",
			value = 210, drops = &"event",
			text = "A calibration bar every scale in three shells defers to. Whoever holds it is right about weight, which is a dangerous thing to be."},
		{id = &"first_keel", name = "FIRST-POUR KEEL SECTION", tier = &"legendary", cells = "4x1",
			value = 240, drops = &"wreck",
			text = "From the first hull a manufacturer ever poured, any of them. They buy these back at any price and melt them in private."},
		{id = &"custodian_shadow", name = "INSTRUMENT SHADOW", tier = &"legendary", cells = "1x1",
			value = 260, drops = &"event",
			text = "A sensor plate burned in the shape of something that passed between it and the core. The shape does not match anything. It is the best picture anyone has."},
		{id = &"hellbender_tooth", name = "HELLBENDER TOOTH", tier = &"legendary", cells = "2x1",
			value = 230, drops = &"fight",
			text = "It was growing back before it hit the deck. Sell it fast; the buyer's problem is a feature."},
		{id = &"closed_auction_lot", name = "SEALED LOT, UNCLAIMED", tier = &"legendary", cells = "2x2",
			value = 180, drops = &"event",
			text = "A Probate seal nobody alive can open honestly. Worth this much sealed. Worth an unknown amount open, in both directions."},
		{id = &"exotic", name = "Exotic", tier = &"exotic", cells = "1x1",
			value = 45, drops = &"fauna",
			text = "Grown, not manufactured. Megafauna organs and whatever a pulsar leaves behind."},
		{id = &"singers_oil", name = "SINGER'S OIL", tier = &"exotic", cells = "1x1",
			value = 58, drops = &"fauna",
			text = "Rendered from the ones that sing. It burns warm and even, and the pod remembers who renders it."},
		{id = &"flank_ivory", name = "FLANK IVORY", tier = &"exotic", cells = "2x1",
			value = 52, drops = &"fauna",
			text = "Grows along a megafauna's leading edge, where space itself wears things smooth. Carves like regret."},
		{id = &"heart_brine", name = "HEART BRINE", tier = &"exotic", cells = "1x1",
			value = 62, drops = &"fauna",
			text = "The fluid a four-chambered heart the size of a shuttle moves. Keeps its warmth for months, which is the entire economy in one jar."},
		{id = &"nerve_silk", name = "NERVE SILK", tier = &"exotic", cells = "1x1",
			value = 66, drops = &"fauna",
			text = "Conductive thread from along a spine longer than your ship. Calyx pays double and asks you to sign something."},
		{id = &"sweep_glass", name = "SWEEP GLASS", tier = &"exotic", cells = "1x1",
			value = 49, drops = &"named",
			text = "What eleven seconds of pulsar leaves on a hull, eleven seconds at a time, for centuries. Scrapes off in colours with no names."},
		{id = &"corona_amber", name = "CORONA AMBER", tier = &"exotic", cells = "1x1",
			value = 55, drops = &"named",
			text = "Star-fused resin found only on wrecks that stayed too close. Something was alive in the resin. Opinion is divided on whether it still is."},
		{id = &"hide_scrap", name = "HIDE SCRAP", tier = &"exotic", cells = "2x1",
			value = 41, drops = &"named",
			text = "Shed hide with forty years of accreted junk in it. The junk is worth sorting. The hide is worth more."},
		{id = &"grave_pollen", name = "GRAVE POLLEN", tier = &"exotic", cells = "1x1",
			value = 47, drops = &"fauna",
			text = "Megafauna seed-dust, released once, at the end. It drifts toward warmth, which lately means you."},
		{id = &"unmarked_cells", name = "UNMARKED CELLS", tier = &"contraband", cells = "1x1",
			value = 95, drops = &"fight",
			text = "Power cells with the serials milled off. They hold a perfect charge, which is what an honest cell never quite does."},
		{id = &"pressed_relics", name = "PRESSED RELICS", tier = &"contraband", cells = "1x1",
			value = 80, drops = &"event",
			text = "Fake precursor fragments. Nobody presses more of the real ones, which is exactly how you can tell."},
		{id = &"grey_coolant", name = "GREY COOLANT", tier = &"contraband", cells = "2x1",
			value = 74, drops = &"event",
			text = "Cut with something cheaper that works better. Every manufacturer bans it. Every manufacturer's ships run cooler than spec."},
		{id = &"tagged_organs", name = "TAGGED ORGANS", tier = &"contraband", cells = "1x1",
			value = 120, drops = &"fauna",
			text = "Bounty-tagged megafauna organs. Selling them states, in writing, where you got them."},
		{id = &"hot_plate", name = "REGISTERED PLATE", tier = &"contraband", cells = "2x1",
			value = 70, drops = &"event",
			text = "Deck plating with a seized hull's registry still in the grain. Scrubbing it off is illegal. Leaving it on is worse."},
		{id = &"counterfeit_seals", name = "COUNTERFEIT SEALS", tier = &"contraband", cells = "1x1",
			value = 130, drops = &"event",
			text = "Korvan delivery seals, indistinguishable from real. Korvan's position is that they are therefore real, and theirs."},
		{id = &"orphan_charts", name = "ORPHAN CHARTS", tier = &"contraband", cells = "1x1",
			value = 88, drops = &"wreck",
			text = "Survey charts of shells no manufacturer has claimed. Owning the chart is legal. Knowing what is on it is not."},
		{id = &"void_labels", name = "VOID LABELS", tier = &"contraband", cells = "1x1",
			value = 64, drops = &"event",
			text = "Blank cargo labels, pre-certified. They can say anything, and until a scan says otherwise, they do."},
		{id = &"relic", name = "Relic", tier = &"artifact", cells = "1x1",
			value = 90, drops = &"wreck",
			text = "Precursor fragment. Nobody presses more of these and nobody knows how."},
		{id = &"closed_bay_key", name = "CLOSED-BAY KEY", tier = &"artifact", cells = "1x1",
			value = 140, drops = &"wreck",
			text = "It fits the bays that do not open onto anything. Turning it does something. Nobody agrees on what."},
		{id = &"wrong_mass", name = "WRONG MASS", tier = &"artifact", cells = "1x1",
			value = 165, drops = &"wreck",
			text = "Fist-sized, weighs like a hull section, and the weight moves a half-second after you do. The distribution nobody would choose, in miniature."},
		{id = &"counting_core", name = "COUNTING CORE", tier = &"artifact", cells = "1x1",
			value = 190, drops = &"named",
			text = "Warm after all this time, and still counting down. The number is smaller than it was when you picked it up."},
	]
	return _all
