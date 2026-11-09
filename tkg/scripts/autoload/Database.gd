extends Node
## Content is plain dictionaries seeded into typed Resources at boot, so it diffs cleanly.
## The rest of the code only sees `ModuleData`, `HullData` and `EnemyTemplate`.
## Why: docs/why/Database.md#content-database

## Only these manufacturers can drop, empty means all. Narrowed for depth over breadth.
## A part also needs the profile to have unlocked its manufacturer (`LootGen.can_appear`).
## Why: docs/why/Database.md#loot-pool-gate
const ACTIVE_MANUFACTURERS: Array[StringName] = [&"korvan", &"solari"]

var manufacturers: Dictionary = {}      ## StringName -> ManufacturerData
var modules: Dictionary = {}            ## StringName -> ModuleData (templates)
var hull_frames: Array[HullData] = []
var enemies: Dictionary = {}            ## StringName -> EnemyTemplate
var affixes: Array[AffixData] = []
var hull_perks: Dictionary = {}         ## StringName -> {name, text}
## The Lab's routines (Phase 12, science). See `_seed_routines`.
var routines: Dictionary = {}           ## StringName -> {name, text, branch, rank, pips, raw}

## One branded weapon and a hull, the rest generic, so identity is assembled mid-run.
## The manufacturer picks the direction of a run, not its destination.
## Why: docs/why/Database.md#starting-kit
const GENERIC_KIT: Array[StringName] = [&"beam", &"plating", &"board", &"coolline"]

## Walked by `RunState._top_up_deck` in order, over distinct parts, so no doubled plates.
const GENERIC_STOCK: Array[StringName] = [
	&"beam", &"slug", &"torch",
	&"plating", &"board", &"bracing",
	&"coolline", &"scope", &"patchkit",
]

## Common or Uncommon, never Rare: melt value is indexed by rarity, so a rare gun was free money.
## Why: docs/why/Database.md#starter-weapon
const STARTER_WEAPON: Dictionary = {
	&"korvan": &"kh20",
	&"solari": &"emberlance",
	&"probate": &"breaker",
	&"redline": &"needle",
	&"cygnet": &"dronebay",
	&"verity": &"markone",
	&"calyx": &"barb",
}

## All seven stay flyable so the other six still pay for themselves at run start.
## Their 3+ and 5+ set bonuses are unreachable while the loot pool is narrowed.
## Why: docs/why/Database.md#startable-manufacturers
const STARTABLE: Array[StringName] = [
	&"korvan", &"solari", &"probate", &"redline", &"cygnet", &"verity", &"calyx",
]

## Branded weapon first, so a light frame drops generic parts before the one that names you.
func starter_kit(manufacturer: StringName) -> Array:
	var out: Array = [STARTER_WEAPON.get(manufacturer, &"kh20")]
	out.append_array(GENERIC_KIT)
	return out

func _ready() -> void:
	_seed_manufacturers()
	_seed_affixes()
	_seed_modules()
	_seed_hulls()
	_seed_enemies()
	_seed_perks()
	_seed_routines()

# ---------------------------------------------------------------- manufacturers

func _seed_manufacturers() -> void:
	var raw := [
		[&"korvan", "Korvan Heavy Works", "It fires. Every time.", "#d97b2e", "#8a4517",
			"Ex-military surplus parts. Ballistics run cold; ordnance and plate run hot.",
			"Standard Issue", "Charge cards charge 1 turn faster.",
			"Full Broadside", "Salvo applies to your first attack too."],
		# Field is a white heat-shield to match the hulls' pale ceramic tile (Jon, Oct 15).
		[&"solari", "Solari Foundry", "The line between reactor and weapon is philosophy.", "#ef9f27", "#f2eee6",
			"Weapons that hit harder the hotter you run.",
			"Sunward", "Plasma weapons gain +2 damage.",
			"Ignition", "Overheat damage halved."],
		[&"probate", "The Probate Combine", "Everything is salvage. Even you.", "#b3924e", "#6e5a2e",
			"Scrap pays and plate holds. It wins slowly and pays well.",
			"Company Rates", "+50% credits from wrecks.",
			"Foundry Line", "Brace cards give +2."],
		[&"redline", "Redline Shipyards", "Still flying? Then we did our job.", "#e24b4a", "#1c2127",
			"Salvaged tech, stealth and refits. Deals in contraband.",
			"Chop Shop", "Draw 1 extra card each turn.",
			"Ghost Protocol", "First enemy attack each combat is negated."],
		[&"verity", "Verity Ateliers", "Made once, made properly.", "#8a7340", "#e8e0cc",
			"Few hulls, each one signed. The parts are rare, exact and costly.",
			"Bespoke", "Verity cards cost 1 less energy.",
			"Provenance", "Start each combat with 1 extra energy."],
		[&"cygnet", "Cygnet Dynamics", "You are never alone.", "#58c8d8", "#16202e",
			"Autonomous drones that fight and intercept for you.",
			"Swarm Logic", "Drones act twice on the turn they launch.",
			"Hive Mind", "Drones persist between encounters."],
		[&"calyx", "Calyx Biosystems", "Grown, not built.", "#3f8f6b", "#e2ece6",
			"Biotech hulls that regenerate, with cards that change as you use them.",
			"Cultivar", "Heal 3 after each combat.",
			"Symbiosis", "Gain 1 exotic material after each fauna encounter."],
	]
	for r in raw:
		var m := ManufacturerData.new()
		m.id = r[0]
		m.name = r[1]
		m.tagline = r[2]
		m.colour = Color(r[3])
		m.field = Color(r[4])
		m.identity = r[5]
		m.set3_name = r[6]
		m.set3_text = r[7]
		m.set5_name = r[8]
		m.set5_text = r[9]
		m.backstory = BACKSTORY.get(m.id, "")
		manufacturers[m.id] = m

## Kept out of the table above: paragraphs in positional array indices are unmergeable.
## Keyed by id so a missing entry is blank, not a shifted column.
## Why: docs/why/Database.md#manufacturer-backstory
const BACKSTORY := {
	&"korvan": "Korvan stamps parts to an old navy specification. The navy is gone, and its war ended two hundred years ago, but Korvan kept the jigs. It never designed a weapon of its own. The parts are not clever, and they still work.",
	&"solari": "Solari is a guild of thermal engineers. They lost an argument about safety margins and left to prove they were right. Their hulls take more heat than their crews can. The company line is that heat is only waste if you fail to aim it.",
	&"probate": "The Combine is nine breaker yards that stopped competing and joined up. It does not prospect, explore or build from raw stock. It follows other people's wrecks and files the claim first. Its hulls are made from ships that once had names.",
	&"redline": "Redline runs chop shops under a trademark. It registers no serials, honours no warranty, and has never been found at the address on its invoices. It sells speed and parts with no record. How legal that is depends on how closely your inspector looks.",
	&"verity": "Verity has built fewer than four hundred hulls in two centuries, each made to order and signed. It does not mass produce, discount, or replace what it sold you. It will always repair it, at a price.",
	&"cygnet": "Cygnet's drone designers solved autonomy forty years ago and have not discussed it since. A Cygnet ship is a hangar with an engine for the swarm to come back to. Pilots say the drones act before they are told. Cygnet has never explained it.",
	&"calyx": "Calyx is a clinical, corporate biotech firm. Its hulls are grown to a specification, then trimmed, and they heal and adapt. Every contract has a clause about feeding a hull something it was not rated for. No customer has seen what happens.",
}

## Sixteen cards from three keywords, readable at a glance, not sixteen written sentences.
## Fused is the only one that compounds, and the only one worth spending a Discard on.
## Why: docs/why/Database.md#malfunctions
const MALFUNCTIONS: Array = [
	# id, name, corrode, smoulder, fused
	[&"dross",     "Dross",           0, 0, false],
	[&"hairline",  "Hairline Crack",  1, 0, false],
	[&"coolloss",  "Coolant Loss",    0, 2, false],
	[&"scored",    "Scored Barrel",   2, 0, false],
	[&"coupling",  "Blown Coupling",  0, 3, false],
	[&"deadcell",  "Dead Cell",       1, 1, false],
	[&"ordnance",  "Loose Ordnance",  3, 0, false],
	[&"arcfault",  "Arc Fault",       0, 4, false],
	[&"tornliner", "Torn Liner",      2, 1, false],
	[&"fouled",    "Fouled Optics",   2, 2, false],
	[&"ballast",   "Ballast",         0, 0, true],
	[&"jammed",    "Jammed Feed",     1, 0, true],
	[&"slowburn",  "Slow Burn",       0, 1, true],
	[&"ghost",     "Ghost Signal",    2, 0, true],
	[&"slag",      "Slag",            0, 3, true],
	[&"seized",    "Seized Actuator", 1, 1, true],
]

## One malfunction card, built fresh. A copy per call, because these go into a
## deck and a shared resource would have every copy of Slag be the same object.
func malfunction(id: StringName) -> CardData:
	for row in MALFUNCTIONS:
		if row[0] != id:
			continue
		var c := CardData.new()
		c.name = row[1]
		c.energy = 1
		c.unplayable = true
		c.hand_damage = row[2]
		c.hand_heat = row[3]
		c.fused = row[4]
		c.source_module = "spore residue"
		# Keyed on the id, not the name slug: ids are stable, display names get reworded.
		c.art = row[0]
		c.sprite = card_art(c.art_key())
		return c
	return malfunction(&"dross")

## Rolled from `Rng.foe` so what an enemy does to you replays from the seed.
## Weights are table position, mildest first, so the front is common.
## Why: docs/why/Database.md#malfunctions
func roll_malfunction(danger: int, r: RandomNumberGenerator = Rng.foe) -> StringName:
	var reach := clampi(4 + danger, 4, MALFUNCTIONS.size())
	return MALFUNCTIONS[r.randi() % reach][0]

func manufacturer_colour(id: StringName) -> Color:
	if id == &"" or not manufacturers.has(id):
		return Color("#5a6a7a")
	return (manufacturers[id] as ManufacturerData).colour

func manufacturer_name(id: StringName) -> String:
	if id == &"" or not manufacturers.has(id):
		return "unbranded"
	return (manufacturers[id] as ManufacturerData).name

## Taking the first word turns 'The Probate Combine' into 'The', so the article goes first.
func short_name(full: String) -> String:
	var n := full
	if n.begins_with("The "):
		n = n.substr(4)
	return n.split(" ")[0]

# ---------------------------------------------------------------------- affixes

## AN AFFIX'S OLD NAME, AND ITS NAME NOW. A save stores an affix by its name
## (`SaveGame._module_to`), and a name the table no longer has is dropped on
## load, so a renamed affix is mapped here wherever a name is read back.
## "Stripped" became "Lightened" (Jon, Nov 5).
const AFFIX_RENAMED := {"Stripped": "Lightened"}


## The affix the table holds under `nm` (or under the name it had before a
## rename, `AFFIX_RENAMED`), or null.
func affix_named(nm: String) -> AffixData:
	var want := str(AFFIX_RENAMED.get(nm, nm))
	for a in affixes:
		if a.name == want:
			return a
	return null


func _seed_affixes() -> void:
	# Paid in ship attributes, not card numbers: a card whose face changes cannot be learned.
	# No `text` field: it is generated from the pips so the panel cannot disagree with them.
	# Why: docs/why/Database.md#affixes
	var raw := [
		{name = "Reinforced", hull = 1},
		{name = "Cryo-Lined", thermal = 1},
		{name = "Gyro-Trimmed", maneuver = 1},
		{name = "Wide-Banded", sensors = 1},
		{name = "Signature-Damped", stealth = 1},
		{name = "Tuned Injectors", thrust = 1},
		{name = "Double-Plated", hull = 2},
		# The tradeoff pair: lighter and thinner, louder and hotter.
		# LIGHTENED, once "Stripped" (Jon, Nov 5): lightening holes, the holes
		# cut in brackets and ribs to take weight out. Old saves say "Stripped"
		# (`AFFIX_RENAMED`).
		{name = "Lightened", maneuver = 2, hull = -1},
		{name = "Bus-Fed", reactor = 1, weight = 0.35},
		{name = "Deregulated", reactor = 2, stealth = -1,
			contraband = true, weight = 0.5},
	]
	for d in raw:
		var a := AffixData.new()
		for k in d.keys():
			a.set(k, d[k])
		a.text = a.gauge_text()
		affixes.append(a)

# ---------------------------------------------------------------------- modules

## Cards more than one module may grant, written once so copies cannot drift apart.
## All common, so a shared card is never worth more on one part than another.
## Why: docs/why/Database.md#shared-cards
const SHARED := {
	# Named Bolt On, not Brace: Brace is the keyword, and no other card is named after a rule.
	&"brace":    {name = "Bolt On", energy = 1, rarity = 0, brace = 5},
	&"block":    {name = "Hold Fast", energy = 1, rarity = 0, block = 7},
	&"vent":     {name = "Bleed Heat", energy = 1, rarity = 0, vent = 3},
	&"reroute":  {name = "Reroute", energy = 1, rarity = 0, draw = 1},
	# +2 and not +3, so Korvan's own Lock On has a reason to cost energy.
	# At +3 the free shared card made the Targeting Servo a worse Ranging Optics.
	# Why: docs/why/Database.md#shared-cards
	&"range":    {name = "Range", energy = 0, rarity = 0, lock_on = 2},
	&"slug":     {name = "Slug", energy = 1, rarity = 0, damage = 4, hits = 2},
	&"cut":      {name = "Cutting Beam", energy = 1, rarity = 0, damage = 6},
	&"patch":    {name = "Patch", energy = 1, rarity = 0, heal = 1, heal_scale = 5},
	&"scuttle":  {name = "Scuttle", energy = 0, rarity = 0, decommission = 1},
	&"sort":     {name = "Sort", energy = 1, rarity = 0, discard = 1, draw = 1},
	&"feed":     {name = "Feed", energy = 1, rarity = 0, salvo = 2},
}

func _card(d: Dictionary) -> CardData:
	var c := CardData.new()
	for k in d.keys():
		c.set(k, d[k])
	# HERE, and not at draw time. See CardData.sprite.
	c.sprite = card_art(c.art_key())
	return c

func _module(id: StringName, name: String, manufacturer: StringName, slot: ModuleData.Slot,
		rarity: ModuleData.Rarity, flavour: String, cards: Array) -> void:
	var m := ModuleData.new()
	m.id = id
	m.name = name
	m.manufacturer = manufacturer
	m.slot = slot
	m.rarity = rarity
	m.flavour = flavour
	# A StringName is a reference into SHARED; a Dictionary is a card this module
	# alone has. Resolved here so the two read the same at every call site.
	var arr: Array[CardData] = []
	for cd in cards:
		if cd is StringName or cd is String:
			var key := StringName(cd)
			assert(SHARED.has(key), "no shared card named %s" % key)
			var sc := _card(SHARED[key])
			sc.shared = true
			arr.append(sc)
		else:
			arr.append(_card(cd))
	m.cards = arr
	m.scrap_value = ModuleData.SCRAP_VALUE[rarity]
	# Null until the art exists, which is what the drawn silhouette is for.
	m.sprite = module_sprite(id)
	modules[id] = m

func _seed_modules() -> void:
	const W := ModuleData.Slot.WEAPON
	const S := ModuleData.Slot.SYSTEM
	const U := ModuleData.Slot.UTILITY
	const C0 := ModuleData.Rarity.COMMON
	const C1 := ModuleData.Rarity.UNCOMMON
	const C2 := ModuleData.Rarity.RARE
	const C3 := ModuleData.Rarity.EPIC
	const C4 := ModuleData.Rarity.LEGENDARY
	const C5 := ModuleData.Rarity.EXOTIC
	const C6 := ModuleData.Rarity.ARTIFACT

	# --- Korvan: ballistics (cold, cheap, multi-hit) and ordnance (hot, charged)
	# One and one: an own card plus a plain shared one, so a starter is not two copies of a verb.
	_module(&"kh20", "KH-20 Chatterbox", &"korvan", W, C0,
		"Autocannon. Cheap rounds, and a lot of them.",
		[{name = "Suppressing Fire", energy = 1, heat = 0, damage = 3, hits = 2, salvo = 2},
			&"slug"])
	_module(&"km4", "KM-4 Mass Driver", &"korvan", W, C0,
		"Charges for a turn, then hits hard.",
		[{name = "Charged Slug", energy = 2, heat = 3, damage = 16, charge_turns = 1, copies = 1}])
	# One and one: it granted the keyword card Brace twice, now shared Bolt On plus its own.
	_module(&"plate", "Ablative Plate Welder", &"korvan", S, C0,
		"Lasting armor that costs heat to hold.",
		[&"brace", {name = "Weld On", energy = 1, brace = 3, vent = 2}])
	_module(&"coolant", "Coolant Flush Assembly", &"korvan", S, C0,
		"Dumps heat into the dark.",
		[{name = "Emergency Vent", energy = 0, vent = 4, draw = 1}, &"vent"])
	_module(&"servo", "Targeting Servo", &"korvan", U, C0,
		"Paints the target for whatever fires next.",
		## Bore Sight and not Lock On: Lock on is the keyword, as with Brace and Bolt On.
		[{name = "Bore Sight", energy = 1, lock_on = 4, copies = 1}])
	_module(&"kh88", "KH-88 Jackhammer", &"korvan", W, C2,
		"Rotary cannon. It fires many small rounds.",
		[{name = "Full Auto", energy = 2, damage = 2, hits = 5, salvo = 1}, &"feed"])
	_module(&"widow", "Widowmaker Siege Driver", &"korvan", W, C3,
		"Charges for two turns, then hits very hard.",
		[{name = "Siege Round", energy = 3, heat = 6, damage = 40, charge_turns = 2, copies = 1}])
	_module(&"reactive", "Reactive Plating Array", &"korvan", S, C4,
		"Armor that hits back at attackers.",
		[{name = "Bulwark", energy = 2, heat = 1, brace = 8, feedback = 4},
			{name = "Overwatch", energy = 2, brace = 4, feedback = 6, draw = 1}])

	## Rarity buys a verb, not a number. The weapon spine is salvo, which Korvan's 5-set doubles.
	## Other manufacturers' verbs stay out: borrowing one reads as that manufacturer.
	## Why: docs/why/Database.md#korvan-ladder

	# Ballistics, the middle rung. Between the Chatterbox's 6/10 and the
	# Jackhammer's 10/15, and cheaper than either to fire twice in a turn.
	_module(&"kh40", "KH-40 Ripsaw", &"korvan", W, C1,
		"Three barrels on one trigger.",
		[{name = "Ripple Fire", energy = 1, damage = 3, hits = 3, salvo = 2}, &"feed"])
	# Top of the salvo spine: 3 energy, one copy, so it is a heavy's card by construction.
	_module(&"kh500", "KH-500 Drumfire", &"korvan", W, C4,
		"A heavy drum-fed gun. Best fired after the others.",
		[{name = "Drumfire", energy = 3, damage = 4, hits = 5, salvo = 4},
			{name = "Walking Fire", energy = 2, damage = 3, hits = 6, salvo = 2}])

	# Systems climb armour, and the verb (armour hitting back) only arrives at the top rung.
	_module(&"sinkplate", "Heat Sink Plating", &"korvan", S, C1,
		"Plate that also sheds heat.",
		[{name = "Sink Plate", energy = 1, brace = 6, vent = 3}, &"brace"])
	# Block decays and costs nothing, unlike armour: right for the turn a Mass Driver charges.
	_module(&"braceframe", "Brace Frame", &"korvan", S, C2,
		"For the turn you have nothing to shoot with.",
		[{name = "Dig In", energy = 1, block = 8, brace = 2},
			{name = "Set Feet", energy = 1, block = 12, feedback = 3}])
	_module(&"bulkhead", "Bulkhead Array", &"korvan", S, C3,
		"Heavy plate, which is Korvan's fix for most problems.",
		[{name = "Bulkhead", energy = 1, heat = 1, brace = 7},
			{name = "Compartment", energy = 2, brace = 9, block = 6}])

	# Cheap lock-on rungs: Korvan undercuts Solari's Flare Rack on heat, not on size.
	_module(&"optics", "Ranging Optics", &"korvan", U, C1,
		"Cheap lenses that still give a correct range.",
		[{name = "Cold Read", energy = 0, lock_on = 4, vent = 1}, &"range"])
	_module(&"coldsights", "Cold Sights", &"korvan", U, C2,
		"Cools the barrel and steadies the aim.",
		[{name = "Cold Sights", energy = 1, vent = 3, lock_on = 4}, &"vent"])
	# A free card for a turn you cannot attack, venting ordnance heat. Pairs with Brace Frame.
	_module(&"standfast", "Standfast Rig", &"korvan", U, C3,
		"Holds and cools the ship while a gun charges.",
		[{name = "Standfast", energy = 0, brace = 6, vent = 4}, &"block"])
	# An engine, not a hammer: free, returns the energy, marks. Three heat a play is the brake.
	_module(&"director", "KX-9 Fire Director", &"korvan", U, C4,
		"It aims for you. You only pull the trigger.",
		[{name = "Fire Director", energy = 0, heat = 3, lock_on = 5, energy_gain = 1}, &"range"])

	# --- Solari: heat as ammunition
	_module(&"plasma", "Solari Plasma Lance", &"solari", W, C1,
		"Hits harder the hotter you run.",
		[{name = "Plasma Lance", energy = 1, heat = 3, damage = 4, heat_scale = 3, copies = 2}])
	_module(&"ventcan", "Thermal Purge Cannon", &"solari", W, C2,
		"Fires all your heat at the enemy.",
		[{name = "Thermal Purge", energy = 1, damage_equals_heat = true, vent_all = true, copies = 1}])
	_module(&"overdrive", "Overdrive Coils", &"solari", S, C1,
		"Extra energy now, paid for in heat.",
		# ONE AND ONE (catalogue §3: a 2-cell uncommon may not be a pair). The
		# second is the same trade at half size, Solari's own verb, so its own card.
		[{name = "Overdrive", energy = 0, heat = 4, energy_gain = 2},
			{name = "Open the Throttle", energy = 0, heat = 2, energy_gain = 1}])
	_module(&"shroud", "Solari Heat Shroud", &"solari", S, C2,
		"Turns your heat into armor.",
		# ONE AND ONE. A plain Solari plate would be Bolt On in Solari colours, so
		# it is Bolt On (catalogue §6, Jon, Oct 15).
		[{name = "Shroud", energy = 1, brace_from_heat = true}, &"brace"])
	## Solari had no utility, so no kit. Korvan's servo read hot: a better mark paid in heat.
	_module(&"flare", "Solari Flare Rack", &"solari", U, C1,
		"A flare that lights the target for your guns.",
		[{name = "Flare", energy = 1, heat = 2, lock_on = 6}, &"range"])

	# Rest of the Solari line (Jon, Oct 15): every attack costs or reads heat, every vent buys.
	# Held by HoldTest `_solari_runs_hot` and `_solari_heat_not_waste`.
	# Why: docs/why/Database.md#solari-line
	_module(&"emberlance", "Ember Lance", &"solari", W, C0,
		"Issued to every new hand on the floor.",
		[{name = "Glowshot", energy = 1, heat = 2, damage = 4, heat_scale = 4},
			{name = "Kindle", energy = 0, heat = 3, damage = 2, heat_scale = 3}])
	# The multi-hit lane: heat scaling adds per hit, and so does Sunward's +2.
	# Sparkfall is the first Flashpoint card a player meets.
	_module(&"sparkthrower", "Spark Thrower", &"solari", W, C1,
		"Sprays what the reactor could not hold.",
		[{name = "Spatter", energy = 1, heat = 3, damage = 2, hits = 3, heat_scale = 6},
			{name = "Sparkfall", energy = 1, heat = 2, damage = 4, hits = 2, flashpoint = 2}])
	# Charge plus heat scaling: the shot reads your heat when it fires, so every
	# hot card played while it charges makes it bigger.
	_module(&"sunspot", "Sunspot Mortar", &"solari", W, C2,
		"Fill it, wait a shift, then aim it.",
		[{name = "Sunspot", energy = 2, heat = 4, damage = 12, heat_scale = 2, charge_turns = 1},
			{name = "Long Noon", energy = 3, heat = 6, damage = 16, heat_scale = 2, charge_turns = 2}])
	# The Flashpoint gun, for a build that lives over its cap on purpose.
	# Ignition (5-set, overheat halved) is what makes that survivable.
	_module(&"overpressure", "Overpressure Cannon", &"solari", W, C3,
		"Rated for the pressure. The crew was not.",
		[{name = "Overpressure", energy = 2, heat = 5, damage = 9, hits = 2, flashpoint = 5},
			{name = "Flashover", energy = 1, heat = 6, damage = 8, flashpoint = 8}])
	# Capstone, four across. Sunburst is the once-a-fight peak, not 'Nova' (the heavy hull).
	_module(&"heliostat", "Heliostat Lance", &"solari", W, C4,
		"Ground for a sun the Foundry no longer has.",
		[{name = "Noon Lance", energy = 3, heat = 6, damage = 10, heat_scale = 1},
			{name = "Sunburst", energy = 3, heat = 8, damage = 4, hits = 3, heat_scale = 2,
				self_decommission = true}])

	# Systems: plate that feeds the guns, and an engine paid in heat.
	_module(&"firebrick", "Firebrick Lining", &"solari", S, C0,
		"Lined to the specification of a smelting floor.",
		[{name = "Firebrick", energy = 1, heat = 2, brace = 6, copies = 2}])
	_module(&"bellows", "Bellows Pump", &"solari", S, C0,
		"It breathes for the furnace. Mind your hands.",
		[{name = "Bellows", energy = 0, heat = 3, draw = 1, copies = 2}])
	# Solari's only block: for the turn a Sunspot is charging.
	_module(&"heathaze", "Heat Haze Projector", &"solari", S, C1,
		"The air bends, and their gunners guess.",
		[{name = "Heat Haze", energy = 1, heat = 2, block = 9},
			{name = "Shimmer", energy = 0, heat = 3, block = 5}])
	_module(&"heatbank", "Heat Bank", &"solari", S, C2,
		"Allocated warmth, held until the schedule calls it.",
		[{name = "Bank the Fire", energy = 2, brace = 6, brace_from_heat = true},
			{name = "Draw Down", energy = 1, vent = 8, draw = 1, energy_gain = 1}])
	_module(&"starfurnace", "Star Furnace", &"solari", S, C3,
		"A smelt charge that never has to stop.",
		[{name = "Stoke", energy = 0, heat = 5, draw = 2, energy_gain = 2},
			{name = "Forced Draft", energy = 1, heat = 4, draw = 3}])
	# Both read the gauge before their own heat lands. (Not "Prominence": that
	# is the medium hull's name.)
	_module(&"sunheart", "Sunheart Core", &"solari", S, C4,
		"The floor calls it the heart. It is a reactor.",
		[{name = "Corona", energy = 1, heat = 3, brace_from_heat = true, feedback = 5},
			{name = "Photosphere", energy = 2, heat = 4, damage_equals_heat = true,
				brace_from_heat = true}])
	# The Solari answer to junk: burn the card and keep the warmth.
	_module(&"crucible", "Smelting Crucible", &"solari", S, C3,
		"Whatever goes in comes out as heat.",
		[{name = "Melt Down", energy = 1, heat = 4, decommission = 2, energy_gain = 1},
			{name = "Render", energy = 0, heat = 3, brace = 6, decommission = 1}])

	# Utility.
	_module(&"heliograph", "Heliograph", &"solari", U, C0,
		"A polished plate and a steady wrist.",
		[{name = "Glint", energy = 0, heat = 2, lock_on = 3, copies = 2}])
	_module(&"incinerator", "Incinerator Hatch", &"solari", U, C0,
		"Burned off the books, and logged as fuel.",
		[{name = "Incinerate", energy = 0, heat = 3, decommission = 1, draw = 1, copies = 2}])
	# Venting aimed at the enemy: damage resolves before the vent, so Backdraft
	# hits for the heat it is about to shed.
	_module(&"bleedvalve", "Bleed Valve", &"solari", U, C1,
		"Opens toward the enemy, by regulation.",
		[{name = "Backdraft", energy = 1, damage = 3, heat_scale = 2, vent = 4},
			{name = "Pressure Drop", energy = 0, block = 4, vent = 2}])
	# A radiator pointed at the enemy. Radiate hits for your heat and sheds 6, so
	# unlike Thermal Purge it leaves you warm enough to keep going.
	_module(&"radiatorsail", "Radiator Sail", &"solari", U, C2,
		"Every other yard points these at the dark.",
		[{name = "Radiate", energy = 2, damage_equals_heat = true, vent = 6, draw = 1},
			{name = "Luff", energy = 1, vent = 3, draw = 2}])
	_module(&"annealer", "Annealing Lamp", &"solari", U, C3,
		"Tempered on the floor, retempered in the field.",
		[{name = "Anneal", energy = 1, heat = 3, brace = 6, heal = 2, heal_scale = 3},
			{name = "Temper", energy = 1, heat = 2, brace = 5, draw = 1}])
	# The engine capstone: one enormous turn a fight.
	_module(&"mirrorarray", "Solstice Mirror Array", &"solari", U, C4,
		"Every mirror on it was aimed by hand.",
		[{name = "Solstice", energy = 0, heat = 8, draw = 2, energy_gain = 3, self_decommission = true},
			{name = "Backfire", energy = 2, heat = 3, damage_equals_heat = true, energy_gain = 1}])

	# --- Probate: scrap and sustain
	_module(&"claw", "Salvage Claw", &"probate", U, C0,
		"Tears salvage off live targets.",
		[{name = "Strip Mine", energy = 1, damage = 5, credit_gain = 3, copies = 2}])
	_module(&"slag", "Slag Armor Kit", &"probate", S, C1,
		"Ugly, heavy plate that pays for itself.",
		[{name = "Slag Plate", energy = 1, brace = 6, credit_gain = 2, copies = 2}])
	_module(&"refinery", "Field Refinery", &"probate", U, C2,
		"Feeds salvage into the armor press.",
		[{name = "Smelt", energy = 1, credit_cost = 5, brace = 10, copies = 1}])
	_module(&"ripper", "Probate Tear-Down Rig", &"probate", W, C2,
		"Takes apart hulls that are still fighting.",
		[{name = "Tear Down", energy = 2, heat = 1, damage = 7, hits = 2, credit_gain = 4, copies = 2}])
	## Issued weapon. See STARTER_WEAPON for why these three exist.
	_module(&"breaker", "Breaker Cannon", &"probate", W, C0,
		"Breaks what it hits into stock you can sell.",
		[{name = "Break Down", energy = 1, damage = 5, credit_gain = 2, copies = 2}])

	# --- Redline: evasion, refit, contraband
	_module(&"chaff", "Chaff Launcher", &"redline", U, C0,
		"Cheap cover that lasts one turn.",
		[{name = "Chaff", energy = 1, block = 6, copies = 2}])
	_module(&"juryrig", "Jury-Rig Kit", &"redline", S, C1,
		"Improvised fixes that give you more options.",
		[{name = "Jury-Rig", energy = 0, draw = 2, copies = 2}])
	_module(&"ghost", "Ghost Drive", &"redline", U, C2,
		"Hides you from the next attack.",
		[{name = "Slip", energy = 1, negate_next = true, copies = 1}])
	_module(&"needle", "Redline Needle Gun", &"redline", W, C1,
		"A stolen gun with the serial filed off.",
		[{name = "Needle", energy = 1, damage = 6, draw = 1, copies = 2}])

	# --- Cygnet: drones
	_module(&"dronebay", "Cygnet Drone Bay", &"cygnet", W, C1,
		"Launches a drone that fights for you.",
		[{name = "Sortie", energy = 1, drone_damage = 3, copies = 2}])
	_module(&"wasp", "Shield Wasp Cradle", &"cygnet", S, C1,
		"A drone that flies between you and it.",
		[{name = "Wasp Screen", energy = 1, drone_brace = 3, copies = 2}])
	_module(&"evoke", "Evoke Node", &"cygnet", U, C2,
		"Spends the swarm all at once.",
		[{name = "Rouse", energy = 1, evoke = 7, copies = 1}])

	# --- Verity: precision
	# Issued weapon hits harder per card: Verity grants one fewer card, so it is the only copy.
	_module(&"markone", "Verity Mark I", &"verity", W, C0,
		"Verity's cheapest gun, still numbered and signed.",
		[{name = "Sidearm", energy = 1, damage = 7, copies = 2}])
	_module(&"rail", "Aurelian Rail", &"verity", W, C2,
		"A precise rail gun that wastes nothing.",
		[{name = "Precise Shot", energy = 1, heat = 1, damage = 9, draw = 1, copies = 2}])
	_module(&"auspex", "Auspex Array", &"verity", U, C1,
		"Draws deep so you find the card you need.",
		## Draw three, throw one: a filter, so it is not the same card as Redline's Jury-Rig.
		## Why: docs/why/Database.md#verity-cards
		[{name = "Foresight", energy = 0, draw = 3, discard = 1, copies = 2}])
	_module(&"verity", "Verity Deflector", &"verity", S, C3,
		"A fine deflector. It blocks well.",
		[{name = "Deflect", energy = 1, block = 12, copies = 2}])

	# --- Calyx: regrowth and adaptation
	_module(&"weave", "Vital Weave", &"calyx", S, C1,
		"The hull slowly knits itself back.",
		[{name = "Knit", energy = 1, heal = 5, copies = 2}])
	## Trimmed from 5/heal 2: sustain made Calyx the strongest of seven at every weight.
	## The old death figures were re-measured 2026-10-17: use the current ones.
	## Why: docs/why/Database.md#calyx-balance
	_module(&"barb", "Calyx Barb", &"calyx", W, C0,
		"A grown spike that heals you as it cuts.",
		[{name = "Barb", energy = 1, damage = 4, heal = 1, copies = 2}])
	_module(&"nodule", "Adaptive Nodule", &"calyx", W, C2,
		"Gets stronger the more you use it in a fight.",
		[{name = "Adapt", energy = 1, damage = 5, adapt = 2, copies = 2}])
	_module(&"sporevent", "Calyx Spore Vent", &"calyx", U, C2,
		"Grown coolant. It is oddly warm to the touch.",
		[{name = "Bloom", energy = 0, vent = 6, heal = 3, copies = 1}])

	# --- Repair, one way per manufacturer
	# All seven can repair, each paid in its own currency, as lifelines scaled on hull missing.
	# Calyx stays flat and gets nothing here: it is already the sustain manufacturer.
	# Why: docs/why/Database.md#repair-cards
	_module(&"weldkit", "Field Weld Kit", &"korvan", U, C1,
		"A surplus kit for one weld, and the weld holds.",
		[{name = "Field Weld", energy = 1, heal = 3, heal_scale = 3}, &"patch"])
	## Heat as the torch: good on a cold turn, deadly on a hot one. Ignition (5-set) fixes that.
	_module(&"cautery", "Cauterising Torch", &"solari", S, C2,
		"Seals hull breaches with heat, and runs hot doing it.",
		[{name = "Cauterise", energy = 1, heat = 4, heal = 2, heal_scale = 3}, &"patch"])
	## Spends credits for hull mid-fight, the only card that does. Company Rates pays for it.
	_module(&"reclaim", "Hull Reclamation Rig", &"probate", S, C1,
		"Rebuilds the frame from salvage, for a price.",
		[{name = "Reclaim", energy = 1, heal = 2, heal_scale = 3, credit_cost = 8, copies = 1}])
	## Cheap and free and replaces itself, so it costs a card slot, not a turn. Fits Chop Shop.
	_module(&"bodge", "Bodge Kit", &"redline", U, C0,
		"Foam and tape, with no paperwork. It keeps you flying.",
		[{name = "Bodge", energy = 0, heal = 1, heal_scale = 5, draw = 1, copies = 2}])
	## The warranty as a card: 3 energy, 2 under Bespoke. See `docs/lore.md` section 3.
	_module(&"perpetuity", "Perpetuity Clause", &"verity", S, C3,
		"The Company will maintain this hull, but does not say for how long.",
		[{name = "Perpetuity", energy = 2, heal = 4, heal_scale = 3, copies = 1}])
	## Two small welds, worse than Knit per card and per energy: Cygnet repairs as it fights.
	_module(&"menders", "Mender Swarm", &"cygnet", S, C2,
		"Repair drones that find a breach before you do.",
		## A swarm that stays: it patches and screens, so it is not the yard's Patch to the decimal.
		[{name = "Mend", energy = 1, heal = 2, heal_scale = 6, drone_brace = 2,
			copies = 2}])

	# --- Unbranded: exotic (grown) and artifact (precursor)
	_module(&"organ", "Voidwhale Ganglion", &"", U, C5,
		"Still faintly warm. The smell is overpowering.",
		[{name = "Whale Song", energy = 1, heal = 8, vent = 3},
			{name = "Deep Song", energy = 1, heal = 6, vent = 6, draw = 1}])
	_module(&"lattice", "Precursor Lattice", &"", S, C6,
		"No one knows who made it, and it does not wear out.",
		[{name = "Lattice", energy = 0, brace = 6, draw = 1},
			{name = "Persist", energy = 1, brace = 8, block = 8}])
	_module(&"singing", "Singing Core", &"", W, C6,
		"It hums, and things near it shake apart.",
		[{name = "Resonance", energy = 2, heat = 2, damage = 11, hits = 2},
			{name = "Sympathetic Burst", energy = 2, heat = 4, damage = 7, hits = 3}])

	# --- Junk
	# No Dross module: it was unreachable. Dross is a count (`Run.dross`) `DeckBuilder` makes junk.
	# Malfunctions live in `MALFUNCTIONS` (see `malfunction()`), not here.
	# Why: docs/why/Database.md#dross

	# --- Clearing the deck.
	# Junk needs an answer or it is arithmetic: spread across manufacturers, not sold by one.
	# Common, as it grants two shared cards and nothing of its own.
	# Why: docs/why/Database.md#clearing-the-deck
	_module(&"scuttle", "Scuttle Chute", &"", U, C0,
		"A hatch that only opens outward. What goes down it is gone for this fight.",
		[&"scuttle", &"sort"])
	_module(&"sortrig", "Sorting Rig", &"redline", U, C2,
		"Sorts the useful from the fused, quickly.",
		[{name = "Cull", energy = 1, rarity = 2, discard = 2, draw = 2}, &"sort"])
	_module(&"blowout", "Blowout Panel", &"korvan", S, C2,
		"Blows out the rack to save the ship.",
		[{name = "Blow Out", energy = 1, discard_hand = true, draw = 3}, &"sort"])

	# --- yard stock: what every ship leaves the dock with, whoever built it.
	# Deliberately dull and unbranded, so the branded find in the next wreck is visibly better.
	# Three per slot so any frame can fill itself without a second identical plate.
	# Why: docs/why/Database.md#yard-stock
	_module(&"beam", "Mining Laser", &"", W, C0,
		"Cuts rock, and ships too.",
		[&"cut", &"slug"])
	_module(&"slug", "Slug Thrower", &"", W, C0,
		"Chemical propellant in a tube, older than spaceflight.",
		[&"slug"])
	_module(&"torch", "Cutting Torch", &"", W, C0,
		"Meant for hulls that are already dead.",
		[{name = "Torch", energy = 0, heat = 3, damage = 5, copies = 2}])

	# Two shared cards and nothing of its own, so a branded plate in a wreck is visibly better.
	_module(&"plating", "Hull Plating", &"", S, C0,
		"Plain steel plate, bolted on.",
		[&"brace"])
	_module(&"board", "Signal Board", &"", S, C0,
		"Ranks what the sensors pick up, most urgent first.",
		[&"reroute", &"range"])
	_module(&"bracing", "Impact Bracing", &"", S, C0,
		"Struts that take one hit and are then scrap.",
		[&"block", {name = "Truss", energy = 1, block = 5, brace = 2}])

	_module(&"coolline", "Coolant Line", &"", U, C0,
		"A hose and a pump. Standard on everything that burns.",
		[&"vent", &"patch"])
	_module(&"scope", "Ranging Scope", &"", U, C0,
		"Tells the guns where the target is, and nothing more.",
		[&"range"])
	## Scaled like the branded repairs: a flat 4 teaches that repair never saves you.
	## Grants the shared Patch, not a copy: holdtest found two different Patch cards.
	## Why: docs/why/Database.md#patch-kit
	_module(&"patchkit", "Patch Kit", &"", U, C0,
		"Foam and tape for small holes in the hull.",
		[&"patch"])


	# --- Korvan: the top of the thermal and sensor ladders, and brass on the deck
	# The ladder had holes: thermal stopped at +2, sensors skipped it. No part, no rung.
	# Why: docs/why/Database.md#attribute-ladder-gaps
	_module(&"cryobat", "Cryogenic Battery", &"korvan", S, C4,
		"A cold store that keeps the guns cool from the start.",
		[{name = "Cold Store", energy = 1, vent = 6, brace = 8},
			{name = "Dead Cold", energy = 2, vent_all = true, brace = 12}])
	_module(&"gunnery", "Gunnery Table", &"korvan", U, C3,
		"Firing solutions worked out before the fight.",
		[{name = "Fire Solution", energy = 0, lock_on = 8, draw = 1},
			{name = "Range Card", energy = 1, damage = 7, lock_on = 3}])
	# Three discard parts: the verb had four cards in the catalogue, two of them Redline's.
	_module(&"brass", "Brass Catcher", &"korvan", U, C1,
		"Spent casings go in the bin. The bin is on the manifest.",
		[{name = "Clear the Breech", energy = 0, discard = 2, damage = 6}, &"sort"])
	_module(&"hoist", "Ammunition Hoist", &"korvan", S, C2,
		"Feeds the guns from below with whatever is nearest.",
		[{name = "Rack and Load", energy = 1, discard = 1, damage = 4, hits = 2,
			salvo = 2},
			{name = "Spent Brass", energy = 0, discard = 1, energy_gain = 1}])
	_module(&"gantry", "Loading Gantry", &"korvan", S, C1,
		"A chain and a rail that keep the guns fed.",
		[{name = "Chain Feed", energy = 1, salvo = 3, draw = 1}, &"feed"])

	# --- Unbranded: the artifact rungs, which are the only place a +4 can live
	# Exotic and Artifact are unbranded, so the yard owns the top rungs. Three gauges had no +4.
	_module(&"keel", "Precursor Keel", &"", S, C6,
		"The hull hangs from this keel.",
		[{name = "Keelbound", energy = 1, brace = 14},
			{name = "Unmade", energy = 2, brace = 10, block = 10, draw = 1}])
	_module(&"sepulchre", "Cold Sepulchre", &"", S, C6,
		"A sealed cold store. Its contents are still inside and still cold.",
		[{name = "Absolute", energy = 1, vent = 12, draw = 2},
			{name = "Long Cold", energy = 0, vent = 6, brace = 8}])
	_module(&"oracle", "Oracle Shard", &"", U, C6,
		"It shows where the shot will land, but not how it knows.",
		[{name = "Foreknowledge", energy = 0, lock_on = 10, draw = 2},
			{name = "Auspice", energy = 1, damage = 8, lock_on = 6}])
	_module(&"ejector", "Ejector Rail", &"", U, C0,
		"A rail and a hatch onto the dark.",
		[{name = "Overside", energy = 0, discard = 2, heal = 2}, &"scuttle"])

	# --- Reactor capacity: the parts that let you run the other parts
	# Self-limiting: a part that grants capacity also occupies it, so it nets at most +2.
	# Capacity only, never energy per turn, and off the grade ladder: it is a budget.
	# Why: docs/why/Database.md#reactor-capacity
	_module(&"buscoupling", "Bus Coupling", &"", S, C0,
		"A second line to the same reactor. Every ship from a yard has one.",
		[{name = "Shunt", energy = 1, vent = 2, draw = 1}, &"reroute"])
	_module(&"foundrybus", "Foundry Bus", &"solari", S, C2,
		"A power bus that runs hot, with its covers off.",
		[{name = "Cold Start", energy = 0, vent = 4, energy_gain = 1}, &"vent"])
	_module(&"trunkline", "Salvaged Trunk Line", &"probate", S, C1,
		"Pulled from a ship that no longer needs it.",
		[{name = "Cannibalise", energy = 1, decommission = 1, brace = 6},
			{name = "Scrap Line", energy = 0, credit_gain = 3, discard = 1}])
	_module(&"jumper", "Jumper Cable", &"redline", U, C1,
		"Extra cable that crossfeeds power between systems.",
		[{name = "Crossfeed", energy = 1, heat = 2, damage = 4, draw = 2}, &"reroute"])
	_module(&"mainbus", "Main Bus Armature", &"korvan", S, C2,
		"Built heavier than it needs to be. It often outlasts the ship.",
		[{name = "Hard Line", energy = 0, brace = 5, block = 4},
			{name = "Standing Load", energy = 2, brace = 12}])

	for id in GENERIC_STOCK:
		(modules[id] as ModuleData).starter_only = true

	_seed_module_passives()
	_seed_module_sizes()

## Sensors and stealth are named on existing parts, not new content (CLAUDE.md priority five).
## Size is a default per slot plus exceptions, only for parts whose name says otherwise.
## Why: docs/why/Database.md#module-sizes
func _seed_module_sizes() -> void:
	# 4x1 is the one shape a light hold (4x3) cannot rotate, so hull weight bites in the hold.
	# Why: docs/why/Database.md#module-sizes
	const SPINE := Vector2i(4, 1)
	const LONG := Vector2i(3, 1)
	const BULK := Vector2i(2, 2)
	const UNIT := Vector2i(2, 1)
	const FIT := Vector2i(1, 1)

	# The four the hull is built AROUND rather than hung with.
	var spinal: Array[StringName] = [&"widow", &"kh500", &"rail", &"heliostat"]
	# Barrels, lances and rails. The shape IS the barrel.
	var long_ones: Array[StringName] = [
		&"km4", &"widow", &"kh500", &"plasma", &"ventcan", &"breaker",
		&"needle", &"rail", &"beam", &"slug",
		# A trunk line IS its length.
		&"trunkline",
		&"emberlance", &"overpressure",
	]
	# Bays, arrays, cradles and heavy plate — things with a volume rather than a
	# barrel. `singing` and `lattice` are precursor artifacts and read as blocks.
	var bulky: Array[StringName] = [
		&"dronebay", &"ripper", &"singing",
		&"reactive", &"bulkhead", &"verity", &"lattice", &"braceframe", &"slag",
		&"refinery", &"organ", &"mainbus", &"cryobat", &"keel", &"sepulchre",
		&"sunspot", &"heatbank", &"starfurnace", &"sunheart", &"crucible",
	]
	# Utility that is a piece of EQUIPMENT rather than an instrument.
	var util_units: Array[StringName] = [
		&"flare", &"chaff", &"claw", &"ghost", &"standfast", &"director",
		&"radiatorsail", &"annealer", &"mirrorarray",
	]

	# Every coupling raises reactor by the same +2 levels, flat across grades.
	# Seeded in its own pass because `_module` takes what a part is, not what it carries.
	# Why: docs/why/Database.md#reactor-capacity
	for id in [&"buscoupling", &"foundrybus", &"trunkline", &"jumper", &"mainbus"]:
		(modules[id] as ModuleData).reactor = REACTOR_BUMP

	for id in modules:
		var m: ModuleData = modules[id]
		if id in spinal:
			m.size = SPINE
		elif id in long_ones:
			m.size = LONG
		elif id in bulky:
			m.size = BULK
		elif id in util_units:
			m.size = UNIT
		elif m.slot == ModuleData.Slot.UTILITY:
			m.size = FIT
		else:
			m.size = UNIT

## Common and uncommon give no pips: yard stock is cards, so a common cannot out-plate a rare.
## Why: docs/why/Database.md#attribute-ladder
const ATTR_BUMP := [0, 0, 1, 2, 3, 3, 4, 2]

## WHAT A COUPLING IS WORTH, in pips of REACTOR. Flat, and deliberately off the
## ladder above — the ruling is written beside the parts themselves.
const REACTOR_BUMP := 2

## Names the one gauge a part moves, picked by what its name implies. Size comes from the grade.
## A part moving two gauges silently was worth double its grade.
## Why: docs/why/Database.md#attribute-ladder
const PASSIVE_AXIS := {
	# Plate, bracing, armour.
	&"plating": [&"hull"], &"bracing": [&"hull"], &"plate": [&"hull"],
	&"reactive": [&"hull"], &"sinkplate": [&"hull"], &"braceframe": [&"hull"],
	&"bulkhead": [&"hull"],
	# Heat: how much you hold and how fast you lose it, which is ONE gauge.
	&"shroud": [&"thermal"], &"overdrive": [&"thermal"], &"ventcan": [&"thermal"],
	&"coolant": [&"thermal"], &"coolline": [&"thermal"], &"sporevent": [&"thermal"],
	# A blowout panel is a door that lets the pressure out. It was carrying no
	# gauge at all, which for a part whose entire job is relief was an omission.
	&"blowout": [&"thermal"],
	# Not being hit and going first, which is also one gauge.
	&"chaff": [&"maneuver"], &"singing": [&"maneuver"], &"servo": [&"maneuver"],
	# Seeing.
	&"auspex": [&"sensors"], &"board": [&"sensors"], &"scope": [&"sensors"],
	&"optics": [&"sensors"], &"coldsights": [&"sensors"], &"director": [&"sensors"],
	&"evoke": [&"sensors"], &"organ": [&"sensors"],
	# Not being seen.
	&"ghost": [&"stealth"], &"lattice": [&"stealth"],
	# Two gauges, full bump on both: a part that does two things is paid for two (Pillar 5).
	&"standfast": [&"hull", &"thermal"],
	# The rungs that had nobody on them.
	&"cryobat": [&"thermal"], &"gunnery": [&"sensors"],
	&"keel": [&"hull"], &"sepulchre": [&"thermal"], &"oracle": [&"sensors"],
	# Solari's line: thermal climbs rare to legendary, plus a plate and a sight.
	&"firebrick": [&"hull"], &"annealer": [&"hull"], &"heatbank": [&"thermal"],
	&"radiatorsail": [&"thermal"], &"starfurnace": [&"thermal"], &"sunheart": [&"thermal"],
	&"mirrorarray": [&"sensors"],
}


## Prices in pips on a gauge not the part's own, authored per part, so the ladder stays flat.
## Why: docs/why/Database.md#attribute-ladder
const PASSIVE_COST := {
	&"flare": [&"stealth", 1],
	# The brightest thing on the hull, by design.
	&"radiatorsail": [&"stealth", 1],
	&"organ": [&"stealth", 1],
}


## Derived from the grade, so a common cannot be authored to out-plate a rare.
## Rounded into each field, so `-- attrtest` measures the gauge instead of trusting this.
## Why: docs/why/Database.md#attribute-ladder
func _seed_module_passives() -> void:
	for id in PASSIVE_AXIS:
		var m: ModuleData = modules[id]
		for axis in PASSIVE_AXIS[id]:
			_lay_pips(m, axis, ATTR_BUMP[int(m.rarity)])
	for id in PASSIVE_COST:
		var row: Array = PASSIVE_COST[id]
		_lay_pips(modules[id] as ModuleData, row[0], -int(row[1]))


## Grade and pips move together: loot and saves set `rarity` alone, so readout and gauge split.
## Lays the difference between the two grades (Geno, Oct 22).
## Why: docs/why/Database.md#regrading
func regrade(m: ModuleData, rarity: int) -> void:
	var was := int(m.rarity)
	m.rarity = rarity as ModuleData.Rarity
	var delta: int = ATTR_BUMP[rarity] - ATTR_BUMP[was]
	if delta == 0:
		return
	for axis in PASSIVE_AXIS.get(m.id, []):
		_lay_pips(m, axis, delta)


## A gauge moves every field it is made of, so +1 maneuver is faster and harder to hit.
## `+=` and not `=`, so a bump and a price on different axes do not overwrite each other.
## Why: docs/why/Database.md#attribute-ladder
func _lay_pips(m: ModuleData, axis: StringName, pips: int) -> void:
	if pips == 0:
		return
	var fields: Dictionary = Attributes.PER_PIP[axis]
	for field in fields:
		var unit: float = float(fields[field]) * float(pips)
		match field:
			&"max_hull": m.max_hull += int(round(unit))
			&"heat_cap": m.heat_cap += int(round(unit))
			&"dissipation": m.dissipation += int(round(unit))
			&"dodge": m.dodge += unit
			&"initiative": m.initiative += int(round(unit))
			&"sensors": m.sensors += int(round(unit))
			&"stealth": m.stealth += int(round(unit))
			&"reactor": m.reactor += int(round(unit))
			&"thrust": m.thrust += int(round(unit))


# ------------------------------------------------------------------------ hulls

## Baseline per weight plus one signature per manufacturer, so one line says what a manufacturer is.
## Dissipation is a trickle on purpose, so heat comes off with cards, not for free.
## Why: docs/why/Database.md#hull-baselines
const WEIGHT_BASE := {
	# Light gets two system mounts: with the fewest mounts it had a five-card deck (measured).
	# Why: docs/why/Database.md#hull-baselines
	HullData.Weight.LIGHT: {
		hand_size = 6, max_hull = 24, heat_cap = 8, dissipation = 2,
		dodge = 0.18, initiative = 2, fuel_factor = 0.8, thrust = 4,
			cargo_slots = 12,
		hold_grid = Vector2i(4, 3),
		weapon_slots = 2, system_slots = 2, utility_slots = 2},
	# Medium gets a second utility mount: over 250 runs it won 15.2% against 20.2% and 21.7%.
	# Why: docs/why/Database.md#hull-baselines
	HullData.Weight.MEDIUM: {
		hand_size = 5, max_hull = 35, heat_cap = 12, dissipation = 1,
		dodge = 0.05, initiative = 0, fuel_factor = 1.2, thrust = 6,
			cargo_slots = 20,
		hold_grid = Vector2i(5, 4),
		weapon_slots = 3, system_slots = 2, utility_slots = 2},
	HullData.Weight.HEAVY: {
		hand_size = 4, max_hull = 52, heat_cap = 18, dissipation = 1,
		dodge = 0.0, initiative = -2, fuel_factor = 1.8, thrust = 8,
			cargo_slots = 30,
		hold_grid = Vector2i(6, 5),
		weapon_slots = 4, system_slots = 2, utility_slots = 1},
}

## A grade is a class of the same ship, not condition: mounts grow only at A and S.
## Scales a tier-0 frame only, as `at_tier` compounds. Reactor level is set, not added.
## Why: docs/why/Database.md#hull-grades
const TIER_DELTA := [
	{scale = 1.00, weapon = 0, system = 0, reactor = 4, dissipation = 0},
	{scale = 1.15, weapon = 0, system = 0, reactor = 5, dissipation = 0},
	{scale = 1.32, weapon = 1, system = 0, reactor = 7, dissipation = 1},
	{scale = 1.52, weapon = 1, system = 1, reactor = 8, dissipation = 1},
]

## Per-manufacturer deltas and three names, one word each (Jon, Oct 15).
const MANUFACTURER_HULLS := {
	&"korvan": {
		# Jon's pick, Oct 15 (the name page, group G: "The works floor" with
		# Hammer for Rivet -- "rivet is weird")
		names = ["Hammer", "Anvil", "Foundry"],
		# One name per weight across grades C to S (Jon, Oct 15): a grade is graded in code.
		# Why: docs/why/Database.md#hull-names
		perk_id = &"baffled_vents",
		d = {max_hull = 5, heat_cap = 2, dodge = -0.02, initiative = -1}},
	&"solari": {
		# Jon's pick, Oct 15 (the name page, group O "Flare, Prominence, Nova")
		names = ["Flare", "Prominence", "Nova"],
		perk_id = &"overspec_reactor",
		d = {heat_cap = 8, dissipation = -1, stealth = -2, fuel_factor = 0.1}},
	&"probate": {
		# Jon's pick, Oct 15 (the name page, group S "The salvage crew")
		names = ["Picker", "Wrecker", "Breaker"],
		perk_id = &"salvage_rack",
		d = {max_hull = 8, heat_cap = 2, dissipation = -1, initiative = -1,
			fuel_factor = 0.2, stealth = -1, utility_slots = 1, weapon_slots = -1}},
	# Redline was the worst in the game (8.6% vs 31.8%): -6 hull goes. It takes `salvage_rack`.
	# `cheap_parts` was measured to do nothing, and `spare_bay` needs a hardpoint no hull carries.
	# Why: docs/why/Database.md#redline-balance
	&"redline": {
		# Jon's pick, Oct 15 (the name page, group B "Lights out")
		names = ["Ghostlight", "Moonrunner", "Blackout"],
		# Was spare_bay. A chop shop that registers no serials is a salvage
		# yard with a shopfront, so it takes the salvage perk outright.
		perk_id = &"salvage_rack",
		d = {max_hull = -3, dodge = 0.06, initiative = 1, fuel_factor = -0.1,
			sensors = 1, stealth = 2}},
	&"cygnet": {
		# Jon's pick, Oct 15 (the name page, group I "Crows")
		names = ["Raven", "Murder", "Nightfall"],
		# Drones are cards, so draw suits Cygnet. Not Redline's, whose 3-set draw would stack.
		perk_id = &"quick_hands",
		d = {max_hull = -3, dissipation = 1, dodge = 0.03, initiative = 1,
			fuel_factor = -0.1, sensors = 2, utility_slots = 1, weapon_slots = -1}},
	&"verity": {
		# Jon's pick, Oct 15 (the name page, group L "Heirloom, Endowment, Inheritance")
		names = ["Heirloom", "Endowment", "Inheritance"],
		perk_id = &"overspec_reactor",
		d = {max_hull = -2, reactor = 1, hand_size = -1, dodge = 0.05, initiative = 1,
			fuel_factor = -0.1, sensors = 2, stealth = 1, weapon_slots = -1}},
	# Calyx was strongest at every weight, measured twice. The hull bonus did not fit its identity.
	&"calyx": {
		# Jon's pick, Oct 15, in chat: a tree, a small group of trees, then
		# the grown room that keeps them
		names = ["Sapling", "Copse", "Vivarium"],
		perk_id = &"baffled_vents",
		d = {dissipation = 1, dodge = 0.02, fuel_factor = -0.1,
			sensors = 1, stealth = 1, system_slots = 1, weapon_slots = -1}},
}

func _seed_hulls() -> void:
	# Unbranded frames let a derelict offer a chassis with no allegiance, at a set piece's cost.
	var salvage := [
		{name = "Skiff Frame", weight = HullData.Weight.LIGHT},
		{name = "Medium Frame", weight = HullData.Weight.MEDIUM},
		{name = "Bulk Frame", weight = HullData.Weight.HEAVY},
	]
	for d in salvage:
		var h := HullData.new()
		for k in (WEIGHT_BASE[d.weight] as Dictionary).keys():
			h.set(k, WEIGHT_BASE[d.weight][k])
		h.name = d.name
		h.weight = d.weight
		h.sprite = hull_sprite(d.weight)
		h.sprite_half = hull_sprite(d.weight, 0, true)
		apply_hull_lines(h)
		set_exhaust(h, DEFAULT_EXHAUST)
		hull_frames.append(h)

	for manufacturer in MANUFACTURER_HULLS:
		var spec: Dictionary = MANUFACTURER_HULLS[manufacturer]
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			hull_frames.append(_manufacturer_hull(manufacturer, w, spec))

## What a manufacturer calls its hull of a weight: one name, whatever the
## grade (Jon, Oct 15). `cls` is kept so callers need not change, and ignored.
func manufacturer_hull_name(manufacturer: StringName, w: HullData.Weight, _cls: int = 0) -> String:
	if not MANUFACTURER_HULLS.has(manufacturer):
		return ""
	return MANUFACTURER_HULLS[manufacturer].names[int(w)]

func _manufacturer_hull(manufacturer: StringName, w: HullData.Weight, spec: Dictionary) -> HullData:
	var h := HullData.new()
	var base: Dictionary = WEIGHT_BASE[w]
	for k in base.keys():
		h.set(k, base[k])
	var d: Dictionary = spec.d
	for k in d.keys():
		h.set(k, h.get(k) + d[k])
	# Floors, as a delta table cannot see collisions: Verity or Calyx would build a gunless light.
	h.weapon_slots = maxi(1, h.weapon_slots)
	h.system_slots = maxi(1, h.system_slots)
	h.utility_slots = maxi(1, h.utility_slots)
	h.dissipation = maxi(1, h.dissipation)
	h.dodge = maxf(0.0, h.dodge)
	h.fuel_factor = maxf(0.5, h.fuel_factor)
	# `WEIGHT_BASE` holds stats, not identity, so weight is set here or every hull stays MEDIUM.
	h.weight = w
	h.manufacturer = manufacturer
	h.name = manufacturer_hull_name(manufacturer, w, 0)
	h.perk_id = spec.perk_id
	h.sprite = hull_sprite(w, 0, false, manufacturer)
	h.sprite_half = hull_sprite(w, 0, true, manufacturer)
	apply_hull_lines(h)
	set_exhaust(h, DEFAULT_EXHAUST)
	return h

## Folder per manufacturer with art, others wear Korvan's: better than a procedural box.
## Keyed on class and weight so a grade is visible. Four sprites per weight beat a fitting engine.
## Why: docs/why/Database.md#hull-art
func hull_sprite(w: HullData.Weight, cls: int = 0, half: bool = false,
		manufacturer: StringName = &"") -> Texture2D:
	var n := hull_art_name(w, cls, manufacturer)
	if n == "":
		return null
	# The filenames are identical inside each folder, so the folder is the
	# whole difference between a Korvan and a Solari medium.
	var sub := "half/" if half else ""
	return load("res://art/sprites/hulls/%s/%s%s.png" % [hull_art_dir(manufacturer), sub, n]) as Texture2D

## Manufacturers with their own hull art, and each weight's base picture (Jon, Oct 14, 15).
const HULL_ART := {
	&"korvan": {"light": "c", "medium": "a", "heavy": "a"},
	&"solari": {"light": "a", "medium": "a", "heavy": "a"},
}

## The folder a manufacturer's hulls are drawn from: its own where it has one,
## Korvan's otherwise (the other five, and the unbranded frames).
func hull_art_dir(manufacturer: StringName) -> String:
	return String(manufacturer) if HULL_ART.has(manufacturer) else "korvan"

## Key for measured tables. Other folders carry a prefix as file names repeat across them.
func hull_art_key(w: HullData.Weight, cls: int = 0, manufacturer: StringName = &"") -> String:
	var n := hull_art_name(w, cls, manufacturer)
	if n == "":
		return ""
	var dir := hull_art_dir(manufacturer)
	return n if dir == "korvan" else "%s/%s" % [dir, n]

## Guarded on `ResourceLoader.exists`: a missing path makes `load()` log an error every call.
## Null is the honest answer, and every drawing site has a procedural fallback.
## Why: docs/why/Database.md#sprite-lookups
func module_sprite(id: StringName) -> Texture2D:
	if id == &"":
		return null
	var path := "res://art/sprites/modules/%s.png" % id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## Same convention as `module_sprite`. Cargo keeps the drawn container (`MaterialIcon`).
## Why: docs/why/Database.md#sprite-lookups
func material_sprite(id: StringName) -> Texture2D:
	if id == &"":
		return null
	var path := "res://art/sprites/materials/%s.png" % id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## Null while a card has no art. The key is the card name slug unless the card names a file.
func card_art(key: StringName) -> Texture2D:
	if key == &"":
		return null
	var path := "res://art/sprites/cards/%s.png" % key
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## ---------------- the three families that are still drawn ----------------
## Places, station and enemies are painted procedurally by decision, and art comes through here.
## Callers keep their procedural body so a family can land one file at a time.
## Why: docs/why/Database.md#sprite-lookups

## Keyed on `id`, not `art`: splitting `art` would break `EnemyArt`'s fallback and redraw the boss.
## Several pictures per kind, one per fight, `look` picks one (Jon, 2026-10-13).
## Why: docs/why/Database.md#enemy-sprites
func enemy_sprite(id: StringName, look: int = 0, half: bool = false) -> Texture2D:
	if id == &"":
		return null
	var files: Array = enemy_sprite_files(id, half)
	var path := "res://art/sprites/enemies/%s.png" % id
	if not files.is_empty():
		path = "res://art/sprites/enemies/%s" % String(files[posmod(look, files.size())])
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## How many pictures a kind has to choose from (0 while it is drawn in code).
func enemy_looks(id: StringName) -> int:
	return enemy_sprite_files(id).size()

## The kind's picture files, in the order `look` indexes them.
func enemy_sprite_files(id: StringName, half: bool = false) -> Array:
	if _enemy_art_index.is_empty():
		_enemy_art_index = {"_": true}
		var f := FileAccess.open("res://art/sprites/enemies/index.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary and d.get("enemies") is Dictionary:
				_enemy_art_index.merge(d["enemies"])
			if d is Dictionary and d.get("half") is Dictionary:
				_enemy_half_index = d["half"]
	var got = (_enemy_half_index if half else _enemy_art_index).get(String(id), [])
	return got if got is Array else []

var _enemy_art_index: Dictionary = {}
var _enemy_half_index: Dictionary = {}

## Keyed on a name, not `MapGen.NodeType`: the picture varies with option tags and cleared state.
## Why: docs/why/Database.md#sprite-lookups
func place_sprite(name: StringName) -> Texture2D:
	if name == &"":
		return null
	var path := "res://art/sprites/places/%s.png" % name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## Two layers per plate: livery tints only the trim, as a lerp on a dark wall desaturates it.
## Why: docs/why/Database.md#station-plates
func station_sprite(id: StringName, layer: StringName = &"wall") -> Texture2D:
	if id == &"" or layer == &"":
		return null
	var path := "res://art/sprites/station/%s_%s.png" % [id, layer]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## The one place the art naming convention is written, so sprite and lines cannot disagree.
func hull_art_name(w: HullData.Weight, cls: int = 0, manufacturer: StringName = &"") -> String:
	var stem := ""
	match w:
		HullData.Weight.LIGHT: stem = "light"
		HullData.Weight.MEDIUM: stem = "medium"
		HullData.Weight.HEAVY: stem = "heavy"
		_: return ""
	# One hull per weight where HULL_ART names it: every grade draws from it, `HullGrade` bakes it.
	var base: Dictionary = HULL_ART[StringName(hull_art_dir(manufacturer))]
	if base.has(stem):
		return "hull_%s_%s" % [stem, base[stem]]
	# TIER_NAMES is an untyped Array, so an element comes back as Variant and
	# `:=` has nothing to infer from. Declared rather than inferred.
	var letter: String = HullData.TIER_NAMES[clampi(cls, 0, 3)]
	return "hull_%s_%s" % [stem, letter.to_lower()]


## One hull per weight, four grades baked from it, not twelve ships a manufacturer (Jon, Oct 14).
const GRADE_BASE: Dictionary = HULL_ART[&"korvan"]

## Whether this weight's grades are baked from one hull (HullGrade) rather than
## drawn as four.
func graded(w: HullData.Weight, manufacturer: StringName = &"") -> bool:
	var base: Dictionary = HULL_ART[StringName(hull_art_dir(manufacturer))]
	match w:
		HullData.Weight.LIGHT: return base.has("light")
		HullData.Weight.MEDIUM: return base.has("medium")
		HullData.Weight.HEAVY: return base.has("heavy")
	return false

## Lines belong to one sprite, so set them wherever the sprite is set or guns hang in mid-air.
## Why: docs/why/Database.md#hull-mounts
func apply_hull_lines(h: HullData) -> void:
	var key := hull_art_key(h.weight, h.tier, h.manufacturer)
	if not HULL_LINES.has(key):
		return
	var d: Dictionary = HULL_LINES[key]
	h.dorsal = PackedVector2Array(d.dorsal)
	h.ventral = PackedVector2Array(d.ventral)
	h.flank = PackedVector2Array(d.flank)
	if HULL_MOUNTS.has(key):
		var m: Dictionary = HULL_MOUNTS[key]
		h.weapon_anchors.assign(m.weapon)
		h.system_anchors.assign(m.system)
		h.utility_anchors.assign(m.utility)

## Hand-placed in the rig bench (`art/tools/rig_bench.py korvan`): re-run after replacing a sprite.
## A stale point fails silently, so `-- mounts` is what makes it fail loudly.
## Why: docs/why/Database.md#hull-mounts
const HULL_MOUNTS := {
	"hull_light_c": {
		weapon = [Vector2(220, 27), Vector2(220, 67), Vector2(144, 79)],
		system = [Vector2(144, 39), Vector2(184, 39), Vector2(144, 59), Vector2(184, 59)],
		utility = [Vector2(108, 48), Vector2(227, 47), Vector2(144, 19)],
	},
	"hull_light_b": {
		weapon = [Vector2(204, 30), Vector2(204, 77)],
		system = [Vector2(164, 30), Vector2(164, 73)],
		utility = [Vector2(114, 51), Vector2(204, 51)],
	},
	"hull_light_a": {
		weapon = [Vector2(212, 34), Vector2(212, 73), Vector2(162, 79)],
		system = [Vector2(175, 53), Vector2(212, 53)],
		utility = [Vector2(129, 68), Vector2(129, 28)],
	},
	"hull_light_s": {
		weapon = [Vector2(195, 38), Vector2(171, 75), Vector2(160, 30)],
		system = [Vector2(128, 38), Vector2(128, 71), Vector2(95, 55)],
		utility = [Vector2(171, 55), Vector2(235, 55)],
	},
	"hull_medium_c": {
		weapon = [Vector2(268, 37), Vector2(268, 87), Vector2(188, 87)],
		system = [Vector2(127, 59), Vector2(184, 60)],
		utility = [Vector2(158, 30), Vector2(250, 60)],
	},
	"hull_medium_b": {
		weapon = [Vector2(262, 56), Vector2(262, 90), Vector2(219, 97)],
		system = [Vector2(107, 71), Vector2(244, 71)],
		utility = [Vector2(206, 71), Vector2(156, 71)],
	},
	"hull_medium_a": {
		weapon = [Vector2(271, 50), Vector2(201, 42), Vector2(271, 89), Vector2(184, 103)],
		system = [Vector2(109, 67), Vector2(149, 67), Vector2(189, 67), Vector2(154, 103)],
		utility = [Vector2(251, 67), Vector2(224, 67), Vector2(154, 35)],
	},
	"hull_medium_s": {
		weapon = [Vector2(277, 64), Vector2(277, 91), Vector2(241, 58), Vector2(241, 96)],
		system = [Vector2(108, 77), Vector2(179, 77), Vector2(219, 77)],
		utility = [Vector2(152, 48), Vector2(142, 77)],
	},
	"hull_heavy_c": {
		weapon = [Vector2(326, 72), Vector2(326, 130), Vector2(233, 136), Vector2(201, 136)],
		system = [Vector2(140, 100), Vector2(307, 100)],
		utility = [Vector2(200, 60)],
	},
	"hull_heavy_b": {
		weapon = [Vector2(283, 63), Vector2(329, 107), Vector2(249, 126), Vector2(162, 126)],
		system = [Vector2(132, 83), Vector2(174, 91)],
		utility = [Vector2(249, 53)],
	},
	"hull_heavy_a": {
		weapon = [Vector2(331, 75), Vector2(331, 110), Vector2(258, 64), Vector2(249, 123), Vector2(171, 123)],
		system = [Vector2(133, 92), Vector2(173, 92), Vector2(213, 92), Vector2(253, 92)],
		utility = [Vector2(203, 49), Vector2(297, 92)],
	},
	"hull_heavy_s": {
		weapon = [Vector2(303, 63), Vector2(303, 105), Vector2(205, 42), Vector2(228, 114), Vector2(166, 124)],
		system = [Vector2(135, 84), Vector2(196, 84), Vector2(262, 84)],
		utility = [Vector2(176, 50)],
	},
	# Solari mounts listed in the order grades open them, so a C-grade ship keeps its front pair.
	# Why: docs/why/Database.md#hull-mounts
	"solari/hull_light_a": {
		weapon = [Vector2(166, 32), Vector2(166, 72), Vector2(251, 50)],
		system = [Vector2(156, 52), Vector2(209, 52), Vector2(116, 53)],
		utility = [Vector2(136, 30), Vector2(136, 73)],
	},
	"solari/hull_medium_a": {
		weapon = [Vector2(236, 40), Vector2(236, 88), Vector2(292, 63), Vector2(160, 28)],
		system = [Vector2(150, 61), Vector2(222, 63), Vector2(102, 61)],
		utility = [Vector2(252, 63), Vector2(150, 100)],
	},
	"solari/hull_heavy_a": {
		weapon = [Vector2(290, 51), Vector2(290, 113), Vector2(340, 80), Vector2(200, 41), Vector2(200, 125)],
		system = [Vector2(152, 80), Vector2(215, 80), Vector2(112, 80)],
		utility = [Vector2(256, 80)],
	},
}

## Each hull picks its own plume strip, not derived from weight. Offset is the frame's top-left.
const HULL_EXHAUST := {
	"hull_light_c": [
		{id = 0, at = Vector2i(64, 33), back = false},
		{id = 0, at = Vector2i(64, 50), back = false},
	],
	"hull_light_b": [
		{id = 6, at = Vector2i(49, 33), back = false},
		{id = 9, at = Vector2i(67, 9), back = true},
	],
	"hull_light_a": [
		{id = 17, at = Vector2i(21, 32), back = true},
		{id = 22, at = Vector2i(46, 14), back = true},
	],
	"hull_light_s": [
		{id = 3, at = Vector2i(18, 34), back = true},
	],
	"hull_medium_c": [
		{id = 0, at = Vector2i(58, 38), back = false},
		{id = 0, at = Vector2i(58, 68), back = false},
		{id = 23, at = Vector2i(47, 49), back = false},
	],
	"hull_medium_b": [
		{id = 1, at = Vector2i(33, 57), back = true},
		{id = 9, at = Vector2i(76, 35), back = false},
	],
	"hull_medium_a": [
		{id = 22, at = Vector2i(32, 57), back = false},
		{id = 22, at = Vector2i(32, 66), back = false},
	],
	"hull_medium_s": [
		{id = 10, at = Vector2i(26, 64), back = false},
		{id = 11, at = Vector2i(54, 61), back = true},
		{id = 11, at = Vector2i(54, 76), back = true},
	],
	"hull_heavy_c": [
		{id = 1, at = Vector2i(42, 86), back = true},
	],
	"hull_heavy_b": [
		{id = 16, at = Vector2i(38, 69), back = true},
	],
	"hull_heavy_a": [
		{id = 10, at = Vector2i(40, 72), back = false},
		{id = 10, at = Vector2i(40, 88), back = false},
	],
	"hull_heavy_s": [
		{id = 24, at = Vector2i(44, 64), back = false},
	],
	# Solari strips sit behind its bells, so the flame shows where the bell ends.
	"solari/hull_light_a": [
		{id = 8, at = Vector2i(39, 32), back = true},
	],
	"solari/hull_medium_a": [
		{id = 1, at = Vector2i(17, 39), back = true},
		{id = 1, at = Vector2i(17, 56), back = true},
	],
	"solari/hull_heavy_a": [
		{id = 21, at = Vector2i(37, 60), back = true},
	],
}

## Generated: re-run `art/tools/anchors.py` after a sprite change, and `-- mounts` will check.
## Plain Vector2 arrays: a `const` cannot fold the packed constructor call.
## Why: docs/why/Database.md#hull-mounts
const HULL_LINES := {
	"hull_heavy_a": {
		dorsal = [Vector2(158, 65), Vector2(172, 58), Vector2(186, 49), Vector2(200, 49), Vector2(214, 49), Vector2(228, 49), Vector2(242, 49), Vector2(256, 59), Vector2(270, 67)],
		ventral = [Vector2(158, 115), Vector2(172, 121), Vector2(186, 121), Vector2(200, 121), Vector2(214, 121), Vector2(228, 121), Vector2(242, 121), Vector2(256, 121), Vector2(270, 115)],
		flank = [Vector2(158, 90), Vector2(172, 89), Vector2(186, 85), Vector2(200, 85), Vector2(214, 85), Vector2(228, 85), Vector2(242, 85), Vector2(256, 90), Vector2(270, 91)],
	},
	"hull_heavy_b": {
		dorsal = [Vector2(118, 59), Vector2(140, 65), Vector2(162, 65), Vector2(185, 59), Vector2(207, 59), Vector2(229, 59), Vector2(252, 59), Vector2(274, 59), Vector2(296, 65)],
		ventral = [Vector2(118, 116), Vector2(140, 130), Vector2(162, 130), Vector2(185, 128), Vector2(207, 128), Vector2(229, 130), Vector2(252, 130), Vector2(274, 130), Vector2(296, 121)],
		flank = [Vector2(118, 87), Vector2(140, 97), Vector2(162, 97), Vector2(185, 93), Vector2(207, 93), Vector2(229, 94), Vector2(252, 94), Vector2(274, 94), Vector2(296, 93)],
	},
	"hull_heavy_c": {
		dorsal = [Vector2(137, 69), Vector2(161, 58), Vector2(184, 58), Vector2(208, 58), Vector2(232, 58), Vector2(256, 58), Vector2(280, 73), Vector2(303, 72), Vector2(327, 70)],
		ventral = [Vector2(137, 127), Vector2(161, 127), Vector2(184, 127), Vector2(208, 127), Vector2(232, 127), Vector2(256, 126), Vector2(280, 127), Vector2(303, 127), Vector2(327, 127)],
		flank = [Vector2(137, 98), Vector2(161, 92), Vector2(184, 92), Vector2(208, 92), Vector2(232, 92), Vector2(256, 92), Vector2(280, 100), Vector2(303, 99), Vector2(327, 98)],
	},
	"hull_heavy_s": {
		dorsal = [Vector2(100, 60), Vector2(123, 45), Vector2(146, 45), Vector2(169, 45), Vector2(192, 45), Vector2(215, 45), Vector2(238, 47), Vector2(261, 57), Vector2(284, 59)],
		ventral = [Vector2(100, 108), Vector2(123, 114), Vector2(146, 114), Vector2(169, 114), Vector2(192, 114), Vector2(215, 114), Vector2(238, 113), Vector2(261, 110), Vector2(284, 107)],
		flank = [Vector2(100, 84), Vector2(123, 79), Vector2(146, 79), Vector2(169, 79), Vector2(192, 79), Vector2(215, 79), Vector2(238, 80), Vector2(261, 83), Vector2(284, 83)],
	},
	"hull_light_a": {
		dorsal = [Vector2(96, 33), Vector2(113, 33), Vector2(131, 33), Vector2(148, 33), Vector2(166, 33), Vector2(183, 33), Vector2(200, 34), Vector2(218, 33), Vector2(235, 35)],
		ventral = [Vector2(96, 65), Vector2(113, 73), Vector2(131, 73), Vector2(148, 73), Vector2(166, 73), Vector2(183, 73), Vector2(200, 72), Vector2(218, 73), Vector2(235, 70)],
		flank = [Vector2(96, 49), Vector2(113, 53), Vector2(131, 53), Vector2(148, 53), Vector2(166, 53), Vector2(183, 53), Vector2(200, 53), Vector2(218, 53), Vector2(235, 52)],
	},
	"hull_light_b": {
		dorsal = [Vector2(88, 34), Vector2(108, 29), Vector2(128, 29), Vector2(147, 29), Vector2(167, 29), Vector2(187, 29), Vector2(206, 29), Vector2(226, 30), Vector2(246, 36)],
		ventral = [Vector2(88, 66), Vector2(108, 72), Vector2(128, 72), Vector2(147, 72), Vector2(167, 72), Vector2(187, 72), Vector2(206, 72), Vector2(226, 72), Vector2(246, 67)],
		flank = [Vector2(88, 50), Vector2(108, 50), Vector2(128, 50), Vector2(147, 50), Vector2(167, 50), Vector2(187, 50), Vector2(206, 50), Vector2(226, 51), Vector2(246, 51)],
	},
	"hull_light_c": {
		dorsal = [Vector2(102, 31), Vector2(119, 27), Vector2(136, 27), Vector2(152, 27), Vector2(169, 27), Vector2(186, 27), Vector2(202, 27), Vector2(219, 27), Vector2(236, 31)],
		ventral = [Vector2(102, 64), Vector2(119, 67), Vector2(136, 67), Vector2(152, 67), Vector2(169, 67), Vector2(186, 67), Vector2(202, 67), Vector2(219, 66), Vector2(236, 63)],
		flank = [Vector2(102, 47), Vector2(119, 47), Vector2(136, 47), Vector2(152, 47), Vector2(169, 47), Vector2(186, 47), Vector2(202, 47), Vector2(219, 46), Vector2(236, 47)],
	},
	"hull_light_s": {
		dorsal = [Vector2(85, 38), Vector2(103, 38), Vector2(120, 34), Vector2(138, 34), Vector2(156, 34), Vector2(174, 34), Vector2(192, 34), Vector2(209, 37), Vector2(227, 39)],
		ventral = [Vector2(85, 69), Vector2(103, 71), Vector2(120, 75), Vector2(138, 75), Vector2(156, 75), Vector2(174, 75), Vector2(192, 75), Vector2(209, 72), Vector2(227, 70)],
		flank = [Vector2(85, 53), Vector2(103, 54), Vector2(120, 54), Vector2(138, 54), Vector2(156, 54), Vector2(174, 54), Vector2(192, 54), Vector2(209, 54), Vector2(227, 54)],
	},
	"hull_medium_a": {
		dorsal = [Vector2(128, 43), Vector2(144, 40), Vector2(160, 40), Vector2(176, 40), Vector2(192, 40), Vector2(207, 43), Vector2(223, 50), Vector2(239, 50), Vector2(255, 47)],
		ventral = [Vector2(128, 88), Vector2(144, 89), Vector2(160, 99), Vector2(176, 99), Vector2(192, 99), Vector2(207, 99), Vector2(223, 97), Vector2(239, 88), Vector2(255, 91)],
		flank = [Vector2(128, 65), Vector2(144, 64), Vector2(160, 69), Vector2(176, 69), Vector2(192, 69), Vector2(207, 71), Vector2(223, 73), Vector2(239, 69), Vector2(255, 69)],
	},
	"hull_medium_b": {
		dorsal = [Vector2(99, 42), Vector2(116, 40), Vector2(132, 40), Vector2(149, 40), Vector2(166, 40), Vector2(182, 40), Vector2(199, 44), Vector2(215, 49), Vector2(232, 50)],
		ventral = [Vector2(99, 87), Vector2(116, 99), Vector2(132, 95), Vector2(149, 98), Vector2(166, 99), Vector2(182, 99), Vector2(199, 99), Vector2(215, 99), Vector2(232, 92)],
		flank = [Vector2(99, 64), Vector2(116, 69), Vector2(132, 67), Vector2(149, 69), Vector2(166, 69), Vector2(182, 69), Vector2(199, 71), Vector2(215, 74), Vector2(232, 71)],
	},
	"hull_medium_c": {
		dorsal = [Vector2(88, 41), Vector2(116, 38), Vector2(144, 38), Vector2(172, 38), Vector2(200, 38), Vector2(229, 38), Vector2(257, 38), Vector2(285, 38), Vector2(313, 44)],
		ventral = [Vector2(88, 77), Vector2(116, 87), Vector2(144, 87), Vector2(172, 87), Vector2(200, 87), Vector2(229, 87), Vector2(257, 87), Vector2(285, 87), Vector2(313, 82)],
		flank = [Vector2(88, 59), Vector2(116, 62), Vector2(144, 62), Vector2(172, 62), Vector2(200, 62), Vector2(229, 62), Vector2(257, 62), Vector2(285, 62), Vector2(313, 63)],
	},
	"hull_medium_s": {
		dorsal = [Vector2(106, 42), Vector2(119, 41), Vector2(132, 39), Vector2(146, 39), Vector2(159, 39), Vector2(172, 39), Vector2(186, 39), Vector2(199, 41), Vector2(212, 43)],
		ventral = [Vector2(106, 95), Vector2(119, 96), Vector2(132, 97), Vector2(146, 96), Vector2(159, 98), Vector2(172, 98), Vector2(186, 98), Vector2(199, 98), Vector2(212, 98)],
		flank = [Vector2(106, 68), Vector2(119, 68), Vector2(132, 68), Vector2(146, 67), Vector2(159, 68), Vector2(172, 68), Vector2(186, 68), Vector2(199, 69), Vector2(212, 70)],
	},
	"solari/hull_heavy_a": {
		dorsal = [Vector2(80, 57), Vector2(115, 52), Vector2(149, 51), Vector2(184, 51), Vector2(218, 51), Vector2(253, 51), Vector2(288, 51), Vector2(322, 56), Vector2(357, 61)],
		ventral = [Vector2(80, 97), Vector2(115, 107), Vector2(149, 111), Vector2(184, 111), Vector2(218, 111), Vector2(253, 111), Vector2(288, 111), Vector2(322, 108), Vector2(357, 100)],
		flank = [Vector2(80, 77), Vector2(115, 79), Vector2(149, 81), Vector2(184, 81), Vector2(218, 81), Vector2(253, 81), Vector2(288, 81), Vector2(322, 82), Vector2(357, 80)],
	},
	"solari/hull_light_a": {
		dorsal = [Vector2(91, 38), Vector2(103, 36), Vector2(115, 30), Vector2(127, 30), Vector2(138, 30), Vector2(150, 30), Vector2(162, 30), Vector2(174, 36), Vector2(186, 39)],
		ventral = [Vector2(91, 61), Vector2(103, 63), Vector2(115, 73), Vector2(127, 73), Vector2(138, 73), Vector2(150, 73), Vector2(162, 73), Vector2(174, 65), Vector2(186, 62)],
		flank = [Vector2(91, 49), Vector2(103, 49), Vector2(115, 51), Vector2(127, 51), Vector2(138, 51), Vector2(150, 51), Vector2(162, 51), Vector2(174, 50), Vector2(186, 50)],
	},
	"solari/hull_medium_a": {
		dorsal = [Vector2(70, 45), Vector2(98, 39), Vector2(126, 38), Vector2(153, 38), Vector2(181, 38), Vector2(209, 38), Vector2(236, 40), Vector2(264, 42), Vector2(292, 47)],
		ventral = [Vector2(70, 78), Vector2(98, 83), Vector2(126, 88), Vector2(153, 88), Vector2(181, 88), Vector2(209, 88), Vector2(236, 88), Vector2(264, 85), Vector2(292, 79)],
		flank = [Vector2(70, 61), Vector2(98, 61), Vector2(126, 63), Vector2(153, 63), Vector2(181, 63), Vector2(209, 63), Vector2(236, 64), Vector2(264, 63), Vector2(292, 63)],
	},
}

## Measured, not typed: a literal sized for the old canvas took the nose off every heavy.
## Why: docs/why/Database.md#widest-hull
static var _widest: int = 0
## Cached apart from `_widest`: half-size files may not be exactly half their source.
static var _widest_half: int = 0
func widest_hull(half: bool = false) -> int:
	if half and _widest_half > 0:
		return _widest_half
	if not half and _widest > 0:
		return _widest
	var found := 0
	for mf: StringName in HULL_ART:
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			for cls in HullData.TIER_NAMES.size():
				var tex := hull_sprite(w, cls, half, mf)
				if tex != null:
					found = maxi(found, tex.get_width())
	if half:
		_widest_half = found
		# Half the procedural fallback, so the column stays narrower than the solo view.
		return maxi(found, ShipView.W / 2)
	_widest = found
	# A build with no hull art at all falls back to the procedural canvas rather
	# than to zero, which would crop every ship to nothing.
	return maxi(found, ShipView.W)

## The engine plume: a 9-frame strip, cropped tight, which is why it carries an
## offset. See HullData.exhaust.
const EXHAUST_FRAMES := 9
## Cropped tight so STRETCH_KEEP_CENTERED centres it: dead space clipped the flames at 2x.
const EXHAUST_AT := Vector2i(0, 27)

## A library, any ship may fly any. Ids must stay contiguous or an engine stops burning.
## Frame height is read, not declared, as strips vary from 28x13 to 76x42.
## Why: docs/why/Database.md#exhaust-plumes
const DEFAULT_EXHAUST := 0
const EXHAUST_COUNT := 25

func exhaust_art(id: int) -> Texture2D:
	if id < 0 or id >= EXHAUST_COUNT:
		return null
	return load("res://art/sprites/exhaust/exhaust_%d.png" % id) as Texture2D

## Derived from the hull's own canvas: sprites are 54 to 81 px tall, so a fixed offset misses.
## Why: docs/why/Database.md#exhaust-plumes
func hull_exhaust_at(w: HullData.Weight, cls: int = 0, id: int = 0,
		manufacturer: StringName = &"") -> Vector2i:
	var tex := hull_sprite(w, cls, false, manufacturer)
	var plume := exhaust_art(id)
	if tex == null or plume == null:
		return EXHAUST_AT
	return Vector2i(0, tex.get_height() / 2 - plume.get_height() / 2)

## One call sets texture, offset and id together, as the three fields must agree.
func set_exhaust(h: HullData, id: int, cls: int = 0) -> void:
	# A hull rigged in the bench carries its own strips, offsets and draw order;
	# the computed centring is only for one that has not been rigged yet.
	h.exhaust_frames = EXHAUST_FRAMES
	h.thrusters = []
	var key := hull_art_key(h.weight, cls, h.manufacturer)
	if HULL_EXHAUST.has(key):
		for e in HULL_EXHAUST[key] as Array:
			var d: Dictionary = e
			h.thrusters.append({
				id = int(d.id),
				tex = exhaust_art(int(d.id)),
				at = d.at as Vector2i,
				back = bool(d.get("back", false)),
			})
		return
	# ONE plume, centred, for a hull nobody has rigged. Still a list, so every
	# reader has exactly one shape to handle rather than two.
	h.thrusters.append({
		id = id,
		tex = exhaust_art(id),
		at = hull_exhaust_at(h.weight, cls, id, h.manufacturer),
		back = false,
	})

## Authored but not displayed (Jon, Oct 15): screens print LIGHT, MEDIUM, HEAVY for comparison.
## Kept as content for a tooltip or shipyard, where `hull_class()` is ready.
## Why: docs/why/Database.md#hull-class-names
const CLASS_NAMES := {
	&"korvan":  ["Cutter", "Frigate", "Monitor"],
	&"solari":  ["Skiff", "Corvette", "Dreadnought"],
	&"probate": ["Trawler", "Scow", "Barge"],
	&"redline": ["Sloop", "Runner", "Clipper"],
	&"cygnet":  ["Pinnace", "Tender", "Carrier"],
	&"verity":  ["Yawl", "Schooner", "Barque"],
	&"calyx":   ["Coracle", "Pirogue", "Umiak"],
}

## Not called `class_name()`: that is a GDScript keyword.
func hull_class(manufacturer: StringName, w: HullData.Weight) -> String:
	if CLASS_NAMES.has(manufacturer):
		return CLASS_NAMES[manufacturer][int(w)]
	return HullData.weight_name(w)

## Looked up by value, not index, so reordering the tables above cannot break it.
func hull_for(manufacturer: StringName, w: HullData.Weight = HullData.Weight.MEDIUM) -> HullData:
	for h in hull_frames:
		if h.manufacturer == manufacturer and h.weight == w:
			return h
	return null

static func tier_name(t: int) -> String:
	return HullData.TIER_NAMES[clampi(t, 0, HullData.TIER_NAMES.size() - 1)]

## A frame at a condition grade. Returns a DUPLICATE, always — the caller owns
## the result, and `hull_frames` must never be written through.
func at_tier(frame: HullData, tier: int) -> HullData:
	var t := clampi(tier, 0, HullData.TIER_NAMES.size() - 1)
	var h := frame.duplicate(true) as HullData
	h.tier = t
	var d: Dictionary = TIER_DELTA[t]
	h.max_hull = maxi(1, int(round(float(h.max_hull) * float(d.scale))))
	h.heat_cap = maxi(1, int(round(float(h.heat_cap) * float(d.scale))))
	h.weapon_slots += int(d.weapon)
	h.system_slots += int(d.system)
	# SET, not +=. See TIER_DELTA: the grade owns the reactor outright, and the
	# reactor owns the cells and the energy.
	h.reactor = int(d.reactor)
	h.dissipation += int(d.dissipation)
	# A class also swaps the hull art and adds perks. The plume must move with the new texture.
	# Why: docs/why/Database.md#hull-grades
	h.tier_perks = tier_perks_for(h.manufacturer, t)
	h.sprite = hull_sprite(h.weight, t, false, h.manufacturer)
	h.sprite_half = hull_sprite(h.weight, t, true, h.manufacturer)
	apply_hull_lines(h)
	set_exhaust(h, DEFAULT_EXHAUST, t)
	# AND THE NAME: the weight's one name (`manufacturer_hull_name`). Salvage
	# frames keep theirs -- they have no manufacturer to name them.
	var named := manufacturer_hull_name(h.manufacturer, h.weight, t)
	if named != "":
		h.name = named
	return h

## Authored and cumulative, not rolled: C none, B first, A two, S all, weakest first.
## No `spare_bay` or `cheap_parts`: one moves unrigged geometry, one is a measured no-op.
## Why: docs/why/Database.md#tier-perks
const TIER_PERKS := {
	&"korvan":  [&"salvage_rack", &"deep_tanks", &"overspec_reactor"],
	&"solari":  [&"salvage_rack", &"overspec_reactor", &"baffled_vents"],
	&"probate": [&"deep_tanks", &"salvage_rack", &"overspec_reactor"],
	&"redline": [&"deep_tanks", &"baffled_vents", &"quick_hands"],
	&"cygnet":  [&"salvage_rack", &"deep_tanks", &"baffled_vents"],
	&"verity":  [&"deep_tanks", &"baffled_vents", &"quick_hands"],
	&"calyx":   [&"salvage_rack", &"deep_tanks", &"quick_hands"],
}

## The perks a grade confers on a hull of this manufacturer. Empty at C.
func tier_perks_for(manufacturer: StringName, tier: int) -> Array[StringName]:
	var out: Array[StringName] = []
	if not TIER_PERKS.has(manufacturer):
		return out
	var ladder: Array = TIER_PERKS[manufacturer]
	for i in mini(clampi(tier, 0, 3), ladder.size()):
		out.append(ladder[i])
	return out

func _seed_perks() -> void:
	hull_perks = {
		# +40% is what `MELT_PERK` is: the text said 50 while the code used 1.4.
		&"salvage_rack": {name = "Salvage Rack", text = "Scrapping modules pays +40%."},
		&"baffled_vents": {name = "Baffled Vents", text = "+1 heat dissipation."},
		&"overspec_reactor": {name = "Overspec Reactor", text = "+1 energy per turn."},
		# No `spare_bay`: a hardpoint lands where arithmetic puts it, not on a rigged anchor.
		# The three perks below only move numbers already consumed elsewhere.
		# Why: docs/why/Database.md#tier-perks
		&"deep_tanks": {name = "Deep Tanks", text = "Every jump costs 10% less fuel."},
		&"quick_hands": {name = "Quick Hands", text = "+1 card a turn."},
		&"cheap_parts": {name = "Cheap Parts", text = "Station repairs cost half."},
	}

func perk_text(id: StringName) -> String:
	if hull_perks.has(id):
		var p: Dictionary = hull_perks[id]
		return "%s: %s" % [p.name, p.text]
	return ""

# --------------------------------------------------------------------- routines
# Science: what the Lab writes into the flight computer for DATA, the run's, never the hull's.
# Why: docs/why/Database.md#routines-science

## What a board step costs, by its place in the branch (pick 2B). The whole
## board is 3 x (4 + 10 + 15) = 87. The first was 6 until Jon's S1A, Nov 8.
const BOARD_PRICES: Array[int] = [4, 10, 15]
## The board's three branches, in the order the board is laid out and saved.
const BRANCHES: Array[StringName] = [&"frame", &"core", &"drive"]

## What the Lab's AUGMENT may add to a part (pick 3A). Every affix but two:
## Cryo-Lined gives heat capacity on any part, which is a thermal module's job,
## and Deregulated is contraband. Bus-Fed is drawn at its loot weight (0.35).
const LAB_AFFIXES: Array[StringName] = [&"Reinforced", &"Double-Plated",
	&"Gyro-Trimmed", &"Wide-Banded", &"Signature-Damped", &"Tuned Injectors",
	&"Bus-Fed", &"Lightened"]

func _seed_routines() -> void:
	routines = {
		# FRAME: what the hull takes and survives.
		&"quiet_running": {name = "QUIET RUNNING", branch = &"frame", rank = 0,
			pips = {&"stealth": 1}, raw = {},
			text = "+1 stealth. Fewer ships see you coming."},
		&"patch_crew": {name = "PATCH CREW", branch = &"frame", rank = 1,
			pips = {}, raw = {},
			text = "Mend 3 hull after every fight you win."},
		&"black_box": {name = "BLACK BOX", branch = &"frame", rank = 2,
			pips = {}, raw = {},
			text = "Once a run, a hit in a fight that would kill you leaves you at 1 hull."},
		&"damage_control": {name = "DAMAGE CONTROL", branch = &"frame", rank = 3,
			pips = {&"hull": 1}, raw = {},
			text = "+7 max hull on any frame."},
		# CORE: the reactor and heat, and how a fight opens.
		&"spare_cells": {name = "SPARE CELLS", branch = &"core", rank = 0,
			pips = {}, raw = {&"cells": 3},
			text = "+3 reactor cells. Power to fit more, but no more energy."},
		&"vent_timing": {name = "VENT TIMING", branch = &"core", rank = 1,
			pips = {}, raw = {&"dissipation": 1},
			text = "+1 heat dissipation."},
		&"cold_open": {name = "COLD OPEN", branch = &"core", rank = 2,
			pips = {}, raw = {},
			text = "Drop 4 heat when a fight starts."},
		&"warm_start": {name = "WARM START", branch = &"core", rank = 3,
			pips = {}, raw = {},
			text = "+1 energy on the first turn of a fight only."},
		# DRIVE: engines, nav and fire control.
		&"wide_sweep": {name = "WIDE SWEEP", branch = &"drive", rank = 0,
			pips = {&"sensors": 1}, raw = {},
			text = "+1 sensors. You see farther on the chart."},
		&"fuel_trim": {name = "FUEL TRIM", branch = &"drive", rank = 1,
			pips = {}, raw = {},
			text = "Every jump costs 10% less fuel. Stacks with Deep Tanks."},
		&"evasion_tables": {name = "EVASION TABLES", branch = &"drive", rank = 2,
			pips = {&"maneuver": 1}, raw = {},
			text = "+1 maneuver. More enemy shots miss."},
		&"first_look": {name = "FIRST LOOK", branch = &"drive", rank = 3,
			pips = {}, raw = {},
			text = "Draw 2 more cards on the first turn of a fight."},
	}

## A routine as the Lab and the ship tab print it: "NAME: what it does".
func routine_text(id: StringName) -> String:
	if routines.has(id):
		var r: Dictionary = routines[id]
		return "%s: %s" % [r.name, r.text]
	return ""

## A branch's four routines, weakest first: what the deal drops one of.
func routines_in(branch: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for rank in 4:
		for id in routines:
			var r: Dictionary = routines[id]
			if r.branch == branch and int(r.rank) == rank:
				out.append(id)
	return out

# -------------------------------------------------------------------- materials
# Credits stay the only currency, but a prerequisite must be a thing: materials are that.
# `exotic` is the first row: same number and sources, one ledger.
# Why: docs/why/Database.md#materials

# The table lives in `MaterialTable`: a shadow copy here diverged and sold at 1 credit.
# Why: docs/why/Database.md#materials

## Retired with alloy. It was flat at the top as rarity buys verbs, not metal.

# -------------------------------------------------------------------- recipes
# A recipe is data, a cost and one known effect, so adding one is an entry, never a branch.
# `dev` gate is 0 for relic analysis since every station has all decks (Jon, Nov 3).
# Why: docs/why/Database.md#recipes

# RELIC ANALYSIS'S TEXT SAYS WHAT THE CODE DOES (science spec, Nov 4).
# Why: docs/why/Database.md#relic-analysiss-text-says-what-the
const RECIPES: Array[Dictionary] = [
	{id = &"analysis", name = "RELIC ANALYSIS", kind = &"artifact", amount = 1, dev = 0,
		credits = 40, mats = {&"relic": 1},
		text = "Have the fragment read. It turns out to be a part."},
	{id = &"develop", name = "DEVELOP FILM", kind = &"data", amount = 6, dev = 0,
		credits = 0, mats = {&"survey_film": 1},
		text = "Develop a roll of survey film. The readings on it are DATA."},
	{id = &"read", name = "READ FOR DATA", kind = &"data", amount = 15, dev = 0,
		credits = 0, mats = {&"relic": 1},
		text = "Have the fragment read for DATA, which uses it up."},
]

# ---------------------------------------------------------------------- enemies

func _intent(d: Dictionary) -> IntentData:
	var i := IntentData.new()
	for k in d.keys():
		i.set(k, d[k])
	return i

func _enemy(id: StringName, name: String, tag: String, hp: int, brace: int,
		credits: int, art: StringName, loop: Array, pool: Array,
		fauna: bool = false, boss: bool = false, miniboss: bool = false) -> void:
	var e := EnemyTemplate.new()
	e.id = id
	e.name = name
	e.tag = tag
	e.max_hull = hp
	e.brace = brace
	e.credit_reward = credits
	e.art = art
	e.fauna = fauna
	e.boss = boss
	e.miniboss = miniboss
	var l: Array[IntentData] = []
	for d in loop:
		l.append(_intent(d))
	e.loop = l
	var p: Array[IntentData] = []
	for d in pool:
		p.append(_intent(d))
	e.pool = p
	enemies[id] = e

func _seed_enemies() -> void:
	# Hull x4 for ordinary enemies (Jon, Nov 3) so fights last longer. Damage is unchanged.
	# Study of 400 runs: fights 6.4 to 10.8 turns, run wins 33 to 23.
	# Why: docs/why/Database.md#enemy-hull-scaling
	_enemy(&"cutter", "Rustjaw Cutter", "pirate skirmisher", 104, 0, 15, &"cutter", [
		{name = "Strafe", text = "Deal 5", damage = 5},
		{name = "Twin Guns", text = "Deal 3 × 2", damage = 3, hits = 2},
		{name = "Juke", text = "Gain 4 block", block = 4},
	], [])
	_enemy(&"lancer", "Corsair Lancer", "raider · fast", 136, 2, 22, &"cutter", [
		{name = "Lance", text = "Deal 9", damage = 9},
		{name = "Sear", text = "Deal 4 × 2", damage = 4, hits = 2},
		{name = "Vent Bloom", text = "Gain 3 block", block = 3},
	], [])
	_enemy(&"hulk", "Dreg Hulk", "salvage barge", 208, 6, 30, &"hulk", [
		{name = "Reinforce", text = "Gain 4 block", block = 4},
		{name = "Winding up…", text = "Charging a ram", telegraph = true},
		{name = "RAM", text = "Deal 14", damage = 14},
	], [])
	_enemy(&"marauder", "Vex Marauder", "raider · heavy weapons", 184, 4, 34, &"cutter", [
		{name = "Rake", text = "Deal 8", damage = 8},
		{name = "Barrage", text = "Deal 5 × 3", damage = 5, hits = 3},
		{name = "Harden", text = "Gain 4 block", block = 4},
	], [])
	_enemy(&"sentinel", "Combine Sentinel", "corporate security", 232, 8, 42, &"hulk", [
		{name = "Lock Plates", text = "Gain 5 block", block = 5},
		{name = "Pulse", text = "Deal 11", damage = 11},
		{name = "Sweep", text = "Deal 4 × 3", damage = 4, hits = 3},
	], [])
	# Fauna use weighted random pools — animals are not predictable.
	_enemy(&"whale", "Voidwhale Calf", "megafauna · pacifiable", 160, 0, 0, &"whale", [], [
		{name = "Drift Song", text = "Heals 4", heal = 4, weight = 30},
		{name = "Tail Sweep", text = "Deal 7", damage = 7, weight = 40},
		{name = "Spore Breath", text = "Deal 3, +1 Dross", damage = 3, dross = 1,
			dross_id = &"slowburn", weight = 30},
	], true)
	_enemy(&"leviathan", "Void Leviathan", "megafauna · adult", 352, 4, 0, &"whale", [], [
		{name = "Sounding", text = "Heals 8", heal = 8, weight = 20},
		{name = "Breach", text = "Deal 15", damage = 15, weight = 45},
		{name = "Spore Storm", text = "Deal 5, +2 Dross", damage = 5, dross = 2,
			dross_id = &"slag", weight = 35},
	], true)
	# Hand-tuned like the custodian, so danger scaling cannot make where you meet it matter.
	# Below 35% hull it leaves (`Combat.escape_intent()`), so the loop is what it does till then.
	# Why: docs/why/Database.md#the-hellbender
	_enemy(&"hellbender", "The Hellbender", "rival harvester · a salamander device on the hull", 90, 6, 90, &"hellbender", [
		{name = "Heat Lance", text = "Deal 11", damage = 11},
		{name = "Slag Guns", text = "Deal 4 × 3", damage = 4, hits = 3},
		{name = "Ashplate", text = "Gain 5 block", block = 5},
		{name = "Furnace Bleed", text = "Deal 7, +1 Dross", damage = 7, dross = 1},
	], [], false, false, true)
	# Hull 200 (Jon, Oct 22, Oct 30), growing 4% a jump past 15 and capped at 400 (Jon, Nov 3).
	# Read from `Run.custodian_jumps()` at fight build, so the template stays 200.
	# Why: docs/why/Database.md#the-custodian
	_enemy(&"custodian", "The Custodian", "guardian of the light", 200, 8, 120, &"hulk", [
		{name = "Volley", text = "Deal 6 × 3", damage = 6, hits = 3},
		{name = "Charging…", text = "Charging a heavy attack", telegraph = true},
		{name = "Annihilate", text = "Deal 40", damage = 40},
	], [], false, true)
	var cust: EnemyTemplate = enemies[&"custodian"]
	cust.grow_after = 15
	cust.grow_rate = 1.04
	cust.grow_cap = 2.0

## The fight the run ends on. `CustodianBadge` reads its name, free jumps and cap from here.
const CORE_BOSS := &"custodian"


func core_boss() -> EnemyTemplate:
	return enemies.get(CORE_BOSS) as EnemyTemplate


## Which enemies can appear at a given danger tier. Bosses are never in here.
func fight_pool(danger: int, fauna_region: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if fauna_region:
		out.append(&"whale")
		if danger > 6:
			out.append(&"leviathan")
		return out
	match MapGen.tier(danger):
		1:
			out.assign([&"cutter"])
		2:
			out.assign([&"cutter", &"cutter", &"lancer"])
		3:
			out.assign([&"cutter", &"lancer", &"hulk"])
		4:
			out.assign([&"lancer", &"hulk", &"marauder"])
		_:
			out.assign([&"hulk", &"marauder", &"sentinel"])
	return out
