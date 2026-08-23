extends Node
## Content database.
##
## Content is authored here as plain dictionaries and seeded into typed
## Resources at boot. Two reasons: it diffs cleanly in git, and tools/
## export_resources.gd can dump it to .tres files once you want to edit
## modules in the Godot inspector instead. Either way the rest of the
## codebase only ever sees ModuleData / HullData / EnemyTemplate.

## Loot-pool gate. While this is non-empty, only these manufacturers can drop;
## an empty array means every maker is live. Nothing is deleted — all 33 modules
## stay authored and seeded, so flipping a maker back on is a one-word edit and
## the sim can A/B a narrow pool against the full one.
##
## Brand-agnostic modules are never gated: Exotic is harvested and Artifact is
## precursor tech, so they have no manufacturer to gate on.
##
## NARROWED TO KORVAN, deliberately, and this is the second time. It was opened
## to all seven when manufacturer hulls landed, because a chassis select offering
## seven makers over a Korvan-only loot pool would have made six choices
## unplayable. STARTABLE has now been cut to match, so that objection is answered
## rather than ignored: there is one house, and it is the only one you can fly.
##
## The reason is depth over breadth. Seven houses at three modules each is seven
## shallow loot streams; one house with a full ladder is a run where the next
## wreck can plausibly hold something you want. Korvan is the one to do first —
## ballistics and charged ordnance, no gimmick, the tutorial house.
##
## Restoring the others means putting this back to [] and STARTABLE back to all
## seven. Nothing else is gated on it.
const ACTIVE_MAKERS: Array[StringName] = [&"korvan"]

var manufacturers: Dictionary = {}      ## StringName -> ManufacturerData
var modules: Dictionary = {}            ## StringName -> ModuleData (templates)
var hull_frames: Array[HullData] = []
var enemies: Dictionary = {}            ## StringName -> EnemyTemplate
var affixes: Array[AffixData] = []
var documents: Dictionary = {}           ## StringName -> DocumentData
var hull_perks: Dictionary = {}         ## StringName -> {name, text}

## ONE branded weapon, and yard stock for the rest.
##
## This used to hand you a manufacturer's whole catalogue — five Korvan modules,
## four Redline — which meant the run opened with its set bonus already earned
## and its identity already finished. Nothing you found afterwards could change
## what you were; the best it could do was be a slightly better version of it.
##
## Now the maker gives you a gun and a hull, which is two of the three a set
## needs. Everything else is generic. The third piece is out there in a wreck or
## behind a station's counter, and until you go and get it you are flying a
## chassis with a good weapon bolted to it — which is a much better description
## of the start of a run than "a finished Korvan build".
##
## It also puts CLAUDE.md's ruling back the right way up. Identity is assembled
## mid-run again; choosing a manufacturer picks the direction, not the
## destination.
## What every ship is issued, in the order it goes on. Seven cards between them
## — two attacks, two armor, two draws, one vent — against the two the branded
## weapon grants. Nine to open with, which is the shape a starting deck wants:
## enough that a hand of five is a draw rather than your whole hand, and thin
## enough that one good find changes it.
const GENERIC_KIT: Array[StringName] = [&"beam", &"plating", &"board", &"coolline"]

## Everything in the yard, three per slot. RunState._top_up_deck walks this to
## fill spare mounts on frames the kit above cannot fill on its own, and walking
## a list of DISTINCT parts is why a Cygnet light no longer launches carrying two
## of the same plate. Order matters: it is the order they get bolted on.
const GENERIC_STOCK: Array[StringName] = [
	&"beam", &"slug", &"torch",
	&"plating", &"board", &"bracing",
	&"coolline", &"scope", &"patchkit",
]

## The one module each yard sends you off with. Common or Uncommon — never Rare,
## which it used to be for three of them.
##
## The rule was "each maker's cheapest weapon", which sounded even and was not:
## Probate, Verity and Calyx had no common weapon at all, so their floor was C2.
## That leaked somewhere invisible. Market.melt() reads scrap_value, which is a
## table indexed by RARITY, so a Probate player could scrap their free gun for
## roughly four times what a Korvan player got before anything had happened —
## with salvage_rack multiplying exactly that. An economic head start nothing on
## screen accounted for, in a game whose difficulty lives in the economy.
##
## Breaker Cannon, Verity Mark I and Calyx Barb were written to close it, and
## they also even out a common tier of the drop pool that was six-sevenths
## Korvan.
##
## STILL UNEVEN, deliberately for now: Solari, Redline and Cygnet start on
## Uncommons, which melt for 16 against Korvan's 8. Half the gap that was there
## and a quarter of what Probate had, but not zero — closing it means three more
## modules, and that is a content decision rather than a bug fix.
const STARTER_WEAPON: Dictionary = {
	&"korvan": &"kh20",
	&"solari": &"plasma",
	&"probate": &"breaker",
	&"redline": &"needle",
	&"cygnet": &"dronebay",
	&"verity": &"markone",
	&"calyx": &"barb",
}

## The makers you can start as, in the order the chassis select shows them.
## Korvan first because it is the tutorial ship: no gimmick, all three slots
## filled, nothing that needs explaining before the first fight.
##
## ALL SEVEN, even though only Korvan parts drop — see ACTIVE_MAKERS. The focus
## is on what gets BUILT, not on what you may fly, and the run-start choice is
## the one place the other six houses still pay for themselves: seven attribute
## signatures, seven hulls, seven palettes, all authored and all reachable.
##
## THE COST, on the record. A loot pool gated to Korvan means a Solari ship
## finds no second Solari part, so the 3+ and 5+ set bonuses of the other six
## are unreachable for as long as ACTIVE_MAKERS is narrowed. You can fly them;
## you cannot complete them.
const STARTABLE: Array[StringName] = [
	&"korvan", &"solari", &"probate", &"redline", &"cygnet", &"verity", &"calyx",
]

## Branded weapon first, so that when a light frame runs out of hardpoints it is
## the generic parts that fall off the end rather than the one module that says
## who you fly for.
func starter_kit(man: StringName) -> Array:
	var out: Array = [STARTER_WEAPON.get(man, &"kh20")]
	out.append_array(GENERIC_KIT)
	return out

func _ready() -> void:
	_seed_manufacturers()
	_seed_affixes()
	_seed_modules()
	_seed_hulls()
	_seed_enemies()
	_seed_perks()
	_seed_documents()

# ---------------------------------------------------------------- manufacturers

func _seed_manufacturers() -> void:
	var raw := [
		[&"korvan", "Korvan Heavy Works", "It fires. Every time.", "#d97b2e", "#8a4517",
			"Ex-military surplus parts. Ballistics run cold; ordnance and armor run hot.",
			"Standard Issue", "Charge cards charge 1 turn faster.",
			"Full Broadside", "Salvo applies to your first attack too."],
		[&"solari", "Solari Foundry", "The line between reactor and weapon is philosophy.", "#ef9f27", "#3a2408",
			"Weaponised heat. Damage scales with your own fever.",
			"Sunward", "Plasma weapons gain +2 damage.",
			"Ignition", "Overheat damage halved."],
		[&"probate", "The Probate Combine", "Everything is salvage. Even you.", "#b3924e", "#6e5a2e",
			"Scrap economy and armor sustain. Wins slowly, wins rich.",
			"Company Rates", "+50% credits from wrecks.",
			"Foundry Line", "Brace cards give +2 armor."],
		[&"redline", "Redline Shipyards", "Still flying? Then we did our job.", "#e24b4a", "#1c2127",
			"Salvage tech, stealth and refits. Innate contraband affinity.",
			"Chop Shop", "Draw 1 extra card each turn.",
			"Ghost Protocol", "First enemy attack each combat is negated."],
		[&"verity", "Verity Ateliers", "Made once, made properly.", "#8a7340", "#e8e0cc",
			"Few hulls, each one signed. Sparse, exact, and priced accordingly.",
			"Bespoke", "Verity cards cost 1 less energy.",
			"Provenance", "Start each combat with 1 extra energy."],
		[&"cygnet", "Cygnet Dynamics", "You are never alone.", "#58c8d8", "#16202e",
			"Autonomous drones that fight and intercept for you.",
			"Swarm Logic", "Drones act twice on the turn they launch.",
			"Hive Mind", "Drones persist between encounters."],
		[&"calyx", "Calyx Biosystems", "Grown, not built.", "#3f8f6b", "#e2ece6",
			"Clean corporate biotech. Regeneration and cards that mutate through use.",
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

## Who each house is, as opposed to what flying it does.
##
## Kept out of the table above because that table is already ten columns wide
## and these are paragraphs; a wall of prose wedged into positional array
## indices is unreadable and unmergeable. Keyed by id so a missing one is blank
## rather than a shifted column.
##
## The rule for writing these: company, not mechanics. `identity` already says
## what the set bonuses do. A player picking a chassis at run start is choosing
## an allegiance before they can evaluate a single number, and this is what they
## are actually choosing between.
const BACKSTORY := {
	&"korvan": "Tooled to a navy specification that outlived the navy. Korvan never designed a weapon — they inherited the jigs and kept stamping parts for a war that ended two centuries ago. Nothing they build is clever. Everything they build still works.",
	&"solari": "A guild of thermal engineers who lost an argument about safety margins and left to prove they were right. Solari hulls are rated for temperatures their crews are not. The company line is that heat is only waste if you fail to aim it.",
	&"probate": "Nine breaker yards that stopped competing and started invoicing. The Combine does not prospect, explore, or build from raw stock — it follows other people's disasters and files the paperwork first. Their hulls are made of ships that had names.",
	&"redline": "Chop shops with a trademark. Redline registers no serials, honours no warranty, and has never once been found at the address on its invoices. What they sell is speed and the absence of a record, and both are exactly as legal as your inspector is thorough.",
	&"verity": "Fewer than four hundred hulls in two centuries, each one commissioned, each one signed. Verity does not scale, does not discount, and does not replace what it sold you — it repairs it, at a price, forever. Owning one is less a purchase than an arrangement.",
	&"cygnet": "Drone architects who solved autonomy and then spent forty years not discussing it. A Cygnet ship is a hangar with an engine, somewhere for the swarm to return to. Pilots report the drones anticipate them. The literature does not address this.",
	&"calyx": "Clinical, corporate and entirely organic — Calyx hulls are cultured to a specification and then trimmed. They heal. They adapt. Every contract has a clause about feeding one something it was not rated for, and no customer has seen the results.",
}

## SIXTEEN MALFUNCTIONS, out of three keywords.
##
## Written as combinations rather than as sixteen sentences. Sixteen sentences is
## what this was first drafted as and it came out as three behaviours with
## different numbers on them; three keywords and a number each is sixteen cards a
## player can read at a glance, which is how Brace, Salvo and Charge already work.
##
##   CORRODE n   damage at the end of your turn while it is in your hand
##   SMOULDER n  heat, the same way
##   FUSED       not discarded at end of turn — it stays until you deal with it
##
## FUSED IS THE ONLY ONE THAT COMPOUNDS. The others charge you once and go with
## the hand. A fused card charges you again every turn and holds a hand slot the
## whole time, which is what makes it worth spending a Discard on — and a
## Decommission if you would rather it did not come back at all.
##
## Eight of these are severities of the same two verbs, and that is deliberate:
## Corrode 1/2/3 and Smoulder 2/3/4 are a ladder you learn to read, not eight
## separate rules to remember.
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
		return c
	return malfunction(&"dross")

## Which malfunction lodges in you, weighted so the mild ones are common.
##
## Rolled from `Rng.foe` rather than the global generator, because what an enemy
## does to you is part of the fight and has to replay from the seed. The weights
## are the row's own position: the table is written mildest-first, so the front
## of it is common and the compounding ones at the back are rare.
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

## One-word display name for chips and map labels. Taking the first word works
## for six of the seven makers but turns "The Probate Combine" into "The", so the
## article goes first.
func short_name(full: String) -> String:
	var n := full
	if n.begins_with("The "):
		n = n.substr(4)
	return n.split(" ")[0]

# ---------------------------------------------------------------------- affixes

func _seed_affixes() -> void:
	var raw := [
		{name = "Overbored", text = "+2 damage", add_damage = 2},
		{name = "Heat-Sinked", text = "-2 heat", reduce_heat = 2},
		{name = "Reinforced", text = "+3 armor", add_armor = 3},
		{name = "Autoloader", text = "draw 1 on play", add_draw = 1},
		{name = "Deregulated", text = "+4 damage, +2 heat", add_damage = 4, add_heat = 2, contraband = true},
		{name = "Salvaged", text = "+2 credits on play", add_credits = 2},
		{name = "Cryo-Lined", text = "vent 2 on play", add_vent = 2},
		{name = "Mass-Fed", text = "+1 hit", add_hits = 1},
		{name = "Efficient", text = "-1 energy", reduce_energy = 1},
		{name = "Grafted", text = "heal 2 on play", add_heal = 2},
	]
	for d in raw:
		var a := AffixData.new()
		for k in d.keys():
			a.set(k, d[k])
		affixes.append(a)

# ---------------------------------------------------------------------- modules

## THE SHARED VOCABULARY. Cards more than one module is allowed to grant.
##
## Every card used to be a literal written inside the one module that granted
## it, which meant nothing could be shared even when it plainly should be: a
## Korvan plate and an unbranded plate both Brace, and writing that twice makes
## two cards that have to be kept in step by somebody remembering to.
##
## So a module's card list takes either a Dictionary — a card only it has — or a
## StringName naming one of these. That is what lets the catalogue have three
## shapes rather than one:
##
##   two shared      yard stock. Honest, dull, and the thing better parts beat
##   one and one     the common case: a headline card and a plain one beside it
##   two special     a part that is entirely itself, and rare because of it
##
## EVERY ONE OF THESE IS COMMON, and that is what makes them shareable: a card a
## legendary bay and a starter plate both grant cannot be worth more on one than
## the other. It is also why they slot into the second half of the rarity law
## without ever breaking it.
##
## Deliberately NOT a card for every verb. These are the ones a dozen parts
## could plausibly grant; anything with a house's fingerprints on it stays
## written where it is granted, because that is what makes it that part's card.
const SHARED := {
	# "Bolt On" and not "Brace". Brace is the KEYWORD — the card face already
	# reads "Brace 5" — so a card called Brace is the rule wearing its own name,
	# and every other card in the game is a thing rather than a rule.
	&"brace":    {name = "Bolt On", energy = 1, rarity = 0, armor = 5},
	&"block":    {name = "Hold Fast", energy = 1, rarity = 0, block = 7},
	&"vent":     {name = "Bleed Heat", energy = 1, rarity = 0, vent = 3},
	&"reroute":  {name = "Reroute", energy = 1, rarity = 0, draw = 1},
	# +2 AND NOT +3, so that Korvan's own Lock On has a reason to cost energy.
	# At +3 the shared card was 0 energy for one point less than a 1-energy
	# house card, which is a full energy for one point of mark — nobody would
	# ever pay it, and the Targeting Servo was a worse Ranging Optics. Surfaced
	# by holdtest's single-verb report, which exists to put exactly this kind of
	# near-twin next to itself.
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
	return c

func _module(id: StringName, name: String, man: StringName, slot: ModuleData.Slot,
		rarity: ModuleData.Rarity, flavour: String, cards: Array) -> void:
	var m := ModuleData.new()
	m.id = id
	m.name = name
	m.manufacturer = man
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
			arr.append(_card(SHARED[key]))
		else:
			arr.append(_card(cd))
	m.cards = arr
	m.scrap_value = ModuleData.SCRAP_VALUE[rarity]
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
	# ONE AND ONE, which is the common shape: a card that is this part's own,
	# and a plain one beside it out of the shared vocabulary. It is what stops a
	# starter weapon being two copies of the same verb.
	_module(&"kh20", "KH-20 Chatterbox", &"korvan", W, C0,
		"Autocannon. Cheap, kinetic, relentless.",
		[{name = "Suppressing Fire", energy = 1, heat = 0, damage = 3, hits = 2, salvo = 2},
			&"slug"])
	_module(&"km4", "KM-4 Mass Driver", &"korvan", W, C0,
		"Slow ordnance. Bank the shot, land the hammer.",
		[{name = "Charged Slug", energy = 2, heat = 3, damage = 16, charge_turns = 1, copies = 1}])
	# ONE AND ONE. It granted two copies of a card called "Brace", which is the
	# keyword wearing its own name twice — it is the shared Bolt On plus a card
	# that is actually this welder's.
	_module(&"plate", "Ablative Plate Welder", &"korvan", S, C0,
		"Armor that persists, heat that lingers.",
		[&"brace", {name = "Weld On", energy = 1, armor = 3, vent = 2}])
	_module(&"coolant", "Coolant Flush Assembly", &"korvan", S, C0,
		"Dumps heat into the dark.",
		[{name = "Emergency Vent", energy = 0, vent = 4, draw = 1}, &"vent"])
	_module(&"servo", "Targeting Servo", &"korvan", U, C0,
		"Paints the target for whatever fires next.",
		## BORE SIGHT and not "Lock On". Lock on is the KEYWORD — the card face
		## already reads "Lock on +4" — so a card called Lock On is the rule
		## wearing its own name, exactly as Brace was before it became Bolt On.
		## Bore sighting is what you do to a gun this size before you fire it.
		[{name = "Bore Sight", energy = 1, lock_on = 4, copies = 1}])
	_module(&"kh88", "KH-88 Jackhammer", &"korvan", W, C2,
		"Rotary cannon. Volume as a philosophy.",
		[{name = "Full Auto", energy = 2, damage = 2, hits = 5, salvo = 1}, &"feed"])
	_module(&"widow", "Widowmaker Siege Driver", &"korvan", W, C3,
		"Two turns of silence, then nothing left.",
		[{name = "Siege Round", energy = 3, heat = 6, damage = 40, charge_turns = 2, copies = 1}])
	_module(&"reactive", "Reactive Plating Array", &"korvan", S, C4,
		"Armor that answers back.",
		[{name = "Bulwark", energy = 2, heat = 1, armor = 8, feedback = 4},
			{name = "Overwatch", energy = 2, armor = 4, feedback = 6, draw = 1}])

	## The nine rungs Korvan was missing, and the shape they were authored to.
	##
	## RARITY BUYS A VERB, NOT A NUMBER. A Legendary is not a bigger lump of a
	## Common, it is a cleverer one. Where a rung below already says the thing, the
	## rung above says a different thing rather than the same thing louder.
	##
	## The spine of the weapon line is SALVO, and that is not a preference. Korvan's
	## five-piece set makes salvo fire on the FIRST attack of the turn
	## (CardResolver, `has_set(&"korvan", 5)`), so every point of it is worth double
	## to a committed Korvan build and nothing at all to a tourist. It is the one
	## number in this catalog that measures how far in you are.
	##
	## Utility is built on LOCK-ON for the mirror reason: lock-on adds per HIT, so
	## it multiplies by the thing Korvan's guns already do. Servo into Jackhammer
	## was the house's best combo and its only one; there are now four rungs of it.
	##
	## What Korvan does NOT get, however well it would fit: heat_scale and
	## damage_equals_heat (Solari IS weaponised heat), credit_gain (Probate),
	## drones and evoke (Cygnet), negate_next (Redline), adapt and heal (Calyx).
	## A house that borrows another's verb at a higher rarity does not read as
	## stronger, it reads as the other house.

	# Ballistics, the middle rung. Between the Chatterbox's 6/10 and the
	# Jackhammer's 10/15, and cheaper than either to fire twice in a turn.
	_module(&"kh40", "KH-40 Ripsaw", &"korvan", W, C1,
		"Three barrels, one trigger, no subtlety.",
		[{name = "Ripple Fire", energy = 1, damage = 2, hits = 3, salvo = 2}, &"feed"])
	# The top of the KH line, and the payoff for the whole salvo spine: 20 cold,
	# 40 once anything has already fired. Three energy and one copy, so it is a
	# HEAVY's card by construction — a reactor of four plays a Ripsaw into this and
	# a reactor of three does not. That is the Korvan hull signature (slow, tough,
	# patient) written as a weapon, and at five set pieces the enabler is free.
	_module(&"kh500", "KH-500 Drumfire", &"korvan", W, C4,
		"The last argument of a slow ship.",
		[{name = "Drumfire", energy = 3, damage = 4, hits = 5, salvo = 4},
			{name = "Walking Fire", energy = 2, damage = 3, hits = 6, salvo = 2}])

	# Systems climb ARMOUR, and the verb arrives at the top rather than along the
	# way: C1 marries the two Commons, C2 buys a different defence entirely, C3
	# buys scale, and the Legendary above is where armour starts hitting back.
	_module(&"sinkplate", "Heat Sink Plating", &"korvan", S, C1,
		"Plate that drinks the heat it stops.",
		[{name = "Sink Plate", energy = 1, armor = 4, vent = 2}, &"brace"])
	# BLOCK, which Korvan has never had. Armour persists and costs heat to hold;
	# block decays and costs nothing. So this is the card for the turn a Mass
	# Driver is charging and there is nothing to do but be hit — the one turn in
	# the house's whole design where a decaying shield is exactly right.
	_module(&"braceframe", "Brace Frame", &"korvan", S, C2,
		"For the turn you have nothing to shoot with.",
		[{name = "Dig In", energy = 1, block = 8, armor = 2},
			{name = "Set Feet", energy = 1, block = 12, feedback = 3}])
	_module(&"bulkhead", "Bulkhead Array", &"korvan", S, C3,
		"Korvan's answer to most questions.",
		[{name = "Bulkhead", energy = 1, heat = 1, armor = 7},
			{name = "Compartment", energy = 2, armor = 9, block = 6}])

	# Four rungs of lock-on, which is the column Korvan had one card in.
	# Deliberately CHEAP rather than large: Solari's Flare Rack is lock-on 6 for a
	# Common-adjacent price and pays 2 heat for it, and Korvan undercutting that on
	# heat instead of beating it on size is the difference between the two houses.
	_module(&"optics", "Ranging Optics", &"korvan", U, C1,
		"Cheap glass. Correct answers.",
		[{name = "Cold Read", energy = 0, lock_on = 4, vent = 1}, &"range"])
	_module(&"coldsights", "Cold Sights", &"korvan", U, C2,
		"Cools the barrel and the arithmetic.",
		[{name = "Cold Sights", energy = 1, vent = 3, lock_on = 4}, &"vent"])
	# The other half of the charged-weapon problem: a free card for the turn you
	# cannot attack, which vents the ordnance heat you are still carrying from the
	# last one. Pairs with Brace Frame by design — one blocks, one cools.
	_module(&"standfast", "Standfast Rig", &"korvan", U, C3,
		"Sit still. Take it. Wait for the tone.",
		[{name = "Standfast", energy = 0, armor = 6, vent = 4}, &"block"])
	# The capstone, and it is an ENGINE rather than a hammer — the hammer is the
	# Drumfire. Free to play, returns the energy, marks the target: the card that
	# turns a hand of Korvan guns into one enormous turn. Three heat a play is the
	# brake, and the only reason it is not degenerate.
	_module(&"director", "KX-9 Fire Director", &"korvan", U, C4,
		"It decides. You pull.",
		[{name = "Fire Director", energy = 0, heat = 3, lock_on = 5, energy_gain = 1}, &"range"])

	# --- Solari: heat as ammunition
	_module(&"plasma", "Solari Plasma Lance", &"solari", W, C1,
		"Hotter you run, harder it bites.",
		[{name = "Plasma Lance", energy = 1, heat = 3, damage = 4, heat_scale = 3, copies = 2}])
	_module(&"ventcan", "Thermal Purge Cannon", &"solari", W, C2,
		"Fires your own fever at them.",
		[{name = "Thermal Purge", energy = 1, damage_equals_heat = true, vent_all = true, copies = 1}])
	_module(&"overdrive", "Overdrive Coils", &"solari", S, C1,
		"Energy now, consequences shortly.",
		[{name = "Overdrive", energy = 0, heat = 4, energy_gain = 2, copies = 2}])
	_module(&"shroud", "Solari Heat Shroud", &"solari", S, C2,
		"Converts fever into shielding.",
		[{name = "Shroud", energy = 1, armor_from_heat = true, copies = 2}])
	## Solari was the one maker with no utility at all, which made a Solari
	## starting kit impossible. Deliberately Korvan's Targeting Servo read hot:
	## a better mark, paid for in heat — the whole maker in one card.
	_module(&"flare", "Solari Flare Rack", &"solari", U, C1,
		"Burns bright enough that everyone can see what you meant.",
		[{name = "Flare", energy = 1, heat = 2, lock_on = 6, copies = 2}])

	# --- Probate: scrap and sustain
	_module(&"claw", "Salvage Claw", &"probate", U, C0,
		"Strips value off things still moving.",
		[{name = "Strip Mine", energy = 1, damage = 5, credit_gain = 3, copies = 2}])
	_module(&"slag", "Slag Armor Kit", &"probate", S, C1,
		"Ugly, heavy, pays for itself.",
		[{name = "Slag Plate", energy = 1, armor = 4, credit_gain = 2, copies = 2}])
	_module(&"refinery", "Field Refinery", &"probate", U, C2,
		"Feeds salvage into the armor press.",
		[{name = "Smelt", energy = 1, credit_cost = 5, armor = 10, copies = 1}])
	_module(&"ripper", "Probate Tear-Down Rig", &"probate", W, C2,
		"Disassembles hulls that object.",
		[{name = "Tear Down", energy = 2, heat = 1, damage = 7, hits = 2, credit_gain = 4, copies = 2}])
	## Issued weapon. See STARTER_WEAPON for why these three exist.
	_module(&"breaker", "Breaker Cannon", &"probate", W, C0,
		"Point it at something and it becomes stock.",
		[{name = "Break Down", energy = 1, damage = 5, credit_gain = 2, copies = 2}])

	# --- Redline: evasion, refit, contraband
	_module(&"chaff", "Chaff Launcher", &"redline", U, C0,
		"Cheap, temporary, better than nothing.",
		[{name = "Chaff", energy = 1, block = 6, copies = 2}])
	_module(&"juryrig", "Jury-Rig Kit", &"redline", S, C1,
		"Finds you options you did not have.",
		[{name = "Jury-Rig", energy = 0, draw = 2, copies = 2}])
	_module(&"ghost", "Ghost Drive", &"redline", U, C2,
		"You were never there.",
		[{name = "Slip", energy = 1, negate_next = true, copies = 1}])
	_module(&"needle", "Redline Needle Gun", &"redline", W, C1,
		"Stolen barrel, filed serial.",
		[{name = "Needle", energy = 1, damage = 6, draw = 1, copies = 2}])

	# --- Cygnet: drones
	_module(&"dronebay", "Cygnet Drone Bay", &"cygnet", W, C1,
		"Launches something that fights for you.",
		[{name = "Sortie", energy = 1, drone_damage = 3, copies = 2}])
	_module(&"wasp", "Shield Wasp Cradle", &"cygnet", S, C1,
		"A drone that flies between you and it.",
		[{name = "Wasp Screen", energy = 1, drone_armor = 3, copies = 2}])
	_module(&"evoke", "Evoke Node", &"cygnet", U, C2,
		"Spends the swarm all at once.",
		[{name = "Rouse", energy = 1, evoke = 7, copies = 1}])

	# --- Verity: precision
	## Issued weapon. Hits harder per card than the other two starters on
	## purpose: Verity grants one fewer card than anybody, so this is the only
	## copy of it in the deck and a merely-average Common would have left the
	## house opening a fight with a single mediocre attack.
	_module(&"markone", "Verity Mark I", &"verity", W, C0,
		"Numbered, signed, and the cheapest thing they will sell you.",
		[{name = "Sidearm", energy = 1, damage = 7, copies = 2}])
	_module(&"rail", "Aurelian Rail", &"verity", W, C2,
		"Nothing wasted. Nothing missed.",
		[{name = "Precise Shot", energy = 1, heat = 1, damage = 9, draw = 1, copies = 2}])
	_module(&"auspex", "Auspex Array", &"verity", U, C1,
		"You always have the card you need.",
		## DRAW THREE AND THROW ONE, not draw two — which is what this said until
		## the twin check put it next to Redline's Jury-Rig and they were the same
		## card. Both houses want cards; only one of them wants THE RIGHT card,
		## and that is a filter, not a bigger number. Verity grants one card where
		## everyone else grants two, so the one is allowed to be the better one.
		[{name = "Foresight", energy = 0, draw = 3, discard = 1, copies = 2}])
	_module(&"verity", "Verity Deflector", &"verity", S, C3,
		"Elegance, quantified.",
		[{name = "Deflect", energy = 1, block = 12, copies = 2}])

	# --- Calyx: regrowth and adaptation
	_module(&"weave", "Vital Weave", &"calyx", S, C1,
		"The hull knits itself. Slowly.",
		[{name = "Knit", energy = 1, heal = 5, copies = 2}])
	## Issued weapon. Bites and knits at once, which is the house in miniature.
	##
	## Trimmed from 5/heal 2. Calyx measured strongest of the seven at every
	## weight, and sustain is why: a weapon that repairs while it fires is worth
	## more than one that hits harder, and two points of healing on two copies of
	## a card in a nine-card deck was quietly the best starter in the game.
	##
	## THE FIGURE THAT USED TO BE HERE IS OUT OF DATE, and it is left corrected
	## rather than deleted because the decision it justified still stands. It said
	## hull loss causes half the deaths. Measured again over 600 runs while the
	## repair modules below were being added: 105 of 338 deaths, so 31%, against
	## 56% for running the tank dry. Hull loss is the second killer in this game
	## and has been for a while.
	##
	## The trim was still right — Calyx was strongest and this is why — but
	## anybody reaching for "sustain decides the game" as a reason to refuse
	## something should reach for the current number instead.
	_module(&"barb", "Calyx Barb", &"calyx", W, C0,
		"Grown to a point. Feeds on what it opens.",
		[{name = "Barb", energy = 1, damage = 4, heal = 1, copies = 2}])
	_module(&"nodule", "Adaptive Nodule", &"calyx", W, C2,
		"Learns the shape of this fight.",
		[{name = "Adapt", energy = 1, damage = 4, adapt = 2, copies = 2}])
	_module(&"sporevent", "Calyx Spore Vent", &"calyx", U, C2,
		"Grown coolant. Unsettlingly warm.",
		[{name = "Bloom", energy = 0, vent = 6, heal = 3, copies = 1}])

	# --- Repair, one way per house
	#
	# Healing used to be Calyx's and nobody else's — Knit, Barb and Bloom, plus
	# the yard's Patch Kit and the Voidwhale Ganglion. Every other house had to
	# buy its hull back at a station, which is correct as an economy and wrong as
	# a deck: a build with no answer to being hurt has one answer to being hurt,
	# and it is "leave".
	#
	# So all seven can repair now, and NOT ONE OF THEM DOES IT THE SAME WAY. A
	# heal card handed identically to seven houses is seven houses minus their
	# differences, and the differences are the class system. Each of these pays
	# for its hull points in the currency its house already trades in: Korvan in
	# tempo, Solari in heat, Probate in credits, Redline in nothing much and not
	# much back, Verity in energy, Cygnet in time.
	#
	# THEY ARE ALL LIFELINES, AND THAT IS THE SECOND REWRITE OF THIS BLOCK.
	#
	# The first pass priced them as economy cards — flat heals, two and three
	# energy — and priced them for a HEALTHY turn, which is the one turn that does
	# not need them. At three hull and one energy left, a card that costs two is
	# not a card. Every one of these now costs at most one energy (Verity's costs
	# two, and one under Bespoke, which is that house answering the question its
	# own way) and every one of them scales on hull MISSING rather than paying a
	# flat number. See CardData.heal_scale.
	#
	# The shape that buys: nearly dead weight at full hull, the biggest card in
	# the deck at three. Worth exactly as much as the trouble you are in.
	#
	# CALYX IS FLAT AND STAYS FLAT, which is now a real distinction rather than an
	# omission: Calyx heals you all fight and the other six save you at the end of
	# one. Knit for 5 twice over is better than any of these on a turn you are
	# winning and worse than all of them on a turn you are not. That is the house
	# that grows hulls versus the houses that patch them.
	#
	# CALYX GETS NOTHING HERE, deliberately. It already has three, it is the
	# sustain house, and `barb` above records what happened last time sustain was
	# handed out freely: Calyx measured strongest of the seven at every weight.
	# Widening the thing that made it strongest is not how the other six catch up.
	# Every rate below is deliberately worse than Knit's 10 hull for 2 energy.
	_module(&"weldkit", "Field Weld Kit", &"korvan", U, C1,
		"Surplus. One kit, one weld, and it holds.",
		[{name = "Field Weld", energy = 1, heal = 2, heal_scale = 4}, &"patch"])
	## Heat as the welding torch, which is the house's whole argument. Costs four
	## heat to buy seven hull, so it is a good trade on a cold turn and a way to
	## kill yourself on a hot one — and Ignition (5-set, overheat halved) is what
	## turns the second case back into the first.
	_module(&"cautery", "Cauterising Torch", &"solari", S, C2,
		"Aim it at the hole. Heat is only waste if you fail to aim it.",
		[{name = "Cauterise", energy = 1, heat = 4, heal = 2, heal_scale = 3, copies = 1}])
	## Repairs out of the hold, at Combine rates. The credit cost is the point:
	## it is the only card in the game that spends the run's currency to buy hull
	## back mid-fight, and Company Rates (3-set, +50% from wrecks) is what pays
	## for it. A fight you cannot afford is a fight you have to win cheaply.
	_module(&"reclaim", "Hull Reclamation Rig", &"probate", S, C1,
		"Feeds the frame on whatever the frame used to be.",
		[{name = "Reclaim", energy = 1, heal = 2, heal_scale = 3, credit_cost = 8, copies = 1}])
	## Cheap, fast, and not very good — which is Redline. Free to play and it
	## replaces itself, so it costs a card slot rather than a turn, and Chop Shop
	## (3-set, draw 1 extra) is a house that can afford to run thin cards.
	_module(&"bodge", "Bodge Kit", &"redline", U, C0,
		"Foam, tape, and no paperwork. Still flying? Then we did our job.",
		[{name = "Bodge", energy = 0, heal = 1, heal_scale = 5, draw = 1, copies = 2}])
	## The warranty, as a card. Twenty hull in one go for three energy — two
	## under Bespoke (3-set, Verity cards cost 1 less), which is the difference
	## between unplayable and a turn you plan a fight around. See `docs/lore.md`
	## §3: the word in the rider is perpetuity, and the Company does not define it.
	_module(&"perpetuity", "Perpetuity Clause", &"verity", S, C3,
		"The Company will maintain this hull. The Company does not say for how long.",
		[{name = "Perpetuity", energy = 2, heal = 4, heal_scale = 3, copies = 1}])
	## Two small welds rather than one big one, which is how a swarm does
	## anything. Worse per card than Knit and worse per energy, and it arrives
	## twice — Cygnet repairs the way Cygnet fights.
	_module(&"menders", "Mender Swarm", &"cygnet", S, C2,
		"They find the hole before you do. Nobody has asked how.",
		## A SWARM THAT STAYS. This was the yard's Patch to the decimal — same
		## energy, same 1, same scale of 5 — on a rare part of a house that does
		## not repair by hand. Cygnet sends things, so the repair leaves the things
		## behind: it patches the hole and screens what it patched.
		[{name = "Mend", energy = 1, heal = 2, heal_scale = 6, drone_armor = 2,
			copies = 2}])

	# --- Unbranded: exotic (grown) and artifact (precursor)
	_module(&"organ", "Voidwhale Ganglion", &"", U, C5,
		"Still faintly warm. Three Kelvin says otherwise.",
		[{name = "Whale Song", energy = 1, heal = 8, vent = 3},
			{name = "Deep Song", energy = 1, heal = 6, vent = 6, draw = 1}])
	_module(&"lattice", "Precursor Lattice", &"", S, C6,
		"Nobody built this. It simply persists.",
		[{name = "Lattice", energy = 0, armor = 6, draw = 1},
			{name = "Persist", energy = 1, armor = 8, block = 8}])
	_module(&"singing", "Singing Core", &"", W, C6,
		"It hums. Things nearby come apart.",
		[{name = "Resonance", energy = 2, heat = 2, damage = 11, hits = 2},
			{name = "Sympathetic Burst", energy = 2, heat = 4, damage = 7, hits = 3}])

	# --- Junk
	#
	# THE MALFUNCTION TABLE lives in `_seed_malfunctions` below, because a
	# malfunction is not a module and never was. See the ruling.
	#
	# THERE IS NO DROSS MODULE. There was one, and it was unreachable: the loot
	# pool skipped it by id, and the only thing that could hand it over was
	# `LootGen.make_dross()`, which nothing called. It still showed up in the
	# module gallery and still counted toward the unbranded catalogue, so the
	# yard looked like it stocked a part nobody could ever be given.
	#
	# Dross is a COUNT, not a part. `Run.dross` goes up when a spore enemy
	# breathes on you and `DeckBuilder` turns it into unplayable cards at
	# deck-build time — junk in the deck without a hold cell or a hardpoint,
	# which is what junk arriving unasked should be. Two mechanisms for one idea
	# is one too many, and this was the dead one.

	# --- Clearing the deck.
	#
	# There has to be an ANSWER to junk or it is only arithmetic. A malfunction
	# now charges you at the end of the turn if you are still holding it, which
	# makes it a question — and these are what you answer it with. Spread across
	# houses rather than sold by one, because every ship gets junk and a mechanic
	# only one manufacturer can address is a mechanic six of them play around.
	# COMMON, not uncommon. It grants two shared cards and nothing of its own,
	# which is the definition of yard stock — and the rarity law is what caught
	# it: an uncommon part has to bring one uncommon card and this brings none.
	_module(&"scuttle", "Scuttle Chute", &"", U, C0,
		"A hatch that only opens outward. Whatever went down it is not coming back.",
		[&"scuttle", &"sort"])
	_module(&"sortrig", "Sorting Rig", &"redline", U, C2,
		"Sorts the useful from the fused. Quickly, and without asking.",
		[{name = "Cull", energy = 1, rarity = 2, discard = 2, draw = 2}, &"sort"])
	_module(&"blowout", "Blowout Panel", &"korvan", S, C2,
		"Surplus. Blows the whole rack clear and lets you start the hand again.",
		[{name = "Blow Out", energy = 1, discard_hand = true, draw = 3}, &"sort"])

	# --- yard stock: what every ship leaves the dock with, whoever built it.
	#
	# Deliberately dull. These are the colourless commons of the game: a beam, a
	# plate, a coolant line. They do one obvious thing at a fair price and none
	# of them is a reason to do anything — which is the point, because the
	# branded module you find in the next wreck has to be visibly better than
	# something.
	#
	# Unbranded, so they count toward no set. A ship launches with its hull and
	# ONE weapon from its maker, which is two of the three you need — the third
	# is out there.
	# Three of each slot, so a frame of any shape can fill itself from stock.
	# The kit is one shape and the frames are not — four makers drop a weapon
	# mount, three add a utility — so without a spread here the top-up ran out
	# of things that fit and fell back on bolting on a second identical plate.
	_module(&"beam", "Mining Laser", &"", W, C0,
		"Cuts rock. Cuts other things.",
		[&"cut", &"slug"])
	_module(&"slug", "Slug Thrower", &"", W, C0,
		"Chemical propellant and a tube. Older than spaceflight.",
		[&"slug"])
	_module(&"torch", "Cutting Torch", &"", W, C0,
		"Meant for hulls that are already dead.",
		[{name = "Torch", energy = 0, heat = 3, damage = 5, copies = 2}])

	# TWO SHARED CARDS. Yard stock grants the common vocabulary and nothing of
	# its own, which is the point of it: the branded plate in the next wreck has
	# to be visibly better than something.
	_module(&"plating", "Hull Plating", &"", S, C0,
		"Steel, bolted on. It does not have to be clever.",
		[&"brace"])
	_module(&"board", "Signal Board", &"", S, C0,
		"Sorts what the sensors are shouting about into an order.",
		[&"reroute", &"range"])
	_module(&"bracing", "Impact Bracing", &"", S, C0,
		"Struts that take one hit and are then scrap.",
		[&"block", {name = "Truss", energy = 1, block = 5, armor = 2}])

	_module(&"coolline", "Coolant Line", &"", U, C0,
		"A hose and a pump. Standard on everything that burns.",
		[&"vent", &"patch"])
	_module(&"scope", "Ranging Scope", &"", U, C0,
		"Tells the guns where the thing is. That is all it does.",
		[&"range"])
	## YARD STOCK, AND THE FIRST LIFELINE ANYBODY HOLDS. Scaled like the branded
	## repairs below it rather than left flat, because the turn this card exists
	## for is the same turn theirs do — and a run whose only repair is a flat 4 is
	## a run that learns repair does not save you before it ever finds one that
	## does.
	_module(&"patchkit", "Patch Kit", &"", U, C0,
		"Foam, tape, and a prayer to whoever welded the frame.",
		[{name = "Patch", energy = 1, heal = 1, heal_scale = 5, copies = 1}])


	# --- Korvan: the top of the thermal and sensor ladders, and brass on the deck
	#
	# THE LADDER HAD HOLES IN IT. Every gauge is supposed to be reachable at +1,
	# +2, +3 and +4, and thermal stopped at +2 while sensors skipped +2 entirely.
	# A rung nobody can buy is a rung that does not exist, and a player building
	# for an attribute finds that out by not finding the part.
	_module(&"cryobat", "Cryogenic Battery", &"korvan", S, C4,
		"A tank of cold. Korvan does not cool the gun down, it starts the gun\n"
		+ "colder, which is the same trick done earlier and cheaper.",
		[{name = "Cold Store", energy = 1, vent = 6, armor = 8},
			{name = "Dead Cold", energy = 2, vent_all = true, armor = 12}])
	_module(&"gunnery", "Gunnery Table", &"korvan", U, C3,
		"Somebody worked the problem before the shooting started. That is the\n"
		+ "whole advantage and it is enormous.",
		[{name = "Fire Solution", energy = 0, lock_on = 8, draw = 1},
			{name = "Range Card", energy = 1, damage = 7, lock_on = 3}])
	# DISCARD, and three parts of it, because the verb had four cards in the whole
	# catalogue and two of those were Redline's. A deck that cannot throw anything
	# away is a deck that draws its malfunctions forever.
	_module(&"brass", "Brass Catcher", &"korvan", U, C1,
		"Spent casings go somewhere. On a Korvan boat they go into a bin, and the\n"
		+ "bin is on the manifest.",
		[{name = "Clear the Breech", energy = 0, discard = 2, damage = 6}, &"sort"])
	_module(&"hoist", "Ammunition Hoist", &"korvan", S, C2,
		"Feeds the guns from below. What it feeds them is whatever is nearest.",
		[{name = "Rack and Load", energy = 1, discard = 1, damage = 4, hits = 2,
			salvo = 2},
			{name = "Spent Brass", energy = 0, discard = 1, energy_gain = 1}])
	_module(&"gantry", "Loading Gantry", &"korvan", S, C1,
		"Nothing about it is clever. It is a chain and a rail and it never stops.",
		[{name = "Chain Feed", energy = 1, salvo = 3, draw = 1}, &"feed"])

	# --- Unbranded: the artifact rungs, which are the only place a +4 can live
	#
	# Exotic and Artifact are unbranded by definition, so the top of every ladder
	# is the yard's problem and nobody else's. Three of the five gauges had no +4
	# at all.
	_module(&"keel", "Precursor Keel", &"", S, C6,
		"It is not attached to the hull. The hull is attached to it.",
		[{name = "Keelbound", energy = 1, armor = 14},
			{name = "Unmade", energy = 2, armor = 10, block = 10, draw = 1}])
	_module(&"sepulchre", "Cold Sepulchre", &"", S, C6,
		"Whatever it was built to keep cold is still in there, and still cold.",
		[{name = "Absolute", energy = 1, vent = 12, draw = 2},
			{name = "Long Cold", energy = 0, vent = 6, armor = 8}])
	_module(&"oracle", "Oracle Shard", &"", U, C6,
		"It tells you where the shot goes. It does not tell you how it knows, and\n"
		+ "the archive has three riders about not asking.",
		[{name = "Foreknowledge", energy = 0, lock_on = 10, draw = 2},
			{name = "Auspice", energy = 1, damage = 8, lock_on = 6}])
	_module(&"ejector", "Ejector Rail", &"", U, C0,
		"A rail, a hatch, and the dark. Yard stock, and the most honest thing in\n"
		+ "the catalogue.",
		[{name = "Overside", energy = 0, discard = 2, heal = 2}, &"scuttle"])

	# --- Reactor capacity: the parts that let you run the other parts
	#
	# A hull's REACTOR LEVEL decides the cells of hardware it can carry, and these
	# are how a build buys more of it without finding a better frame. THEY ARE
	# SELF-LIMITING BY CONSTRUCTION — a part that grants capacity also occupies
	# it, and it occupies a mount that could have held a gun. The most any of
	# them nets is +2, which `-- reactor` enforces: two cells is one small part's
	# worth, so a ship that gives half its mounts to couplings has bought itself
	# about one extra weapon and has nowhere left to put it.
	#
	# THE ATTRIBUTE LADDER DOES NOT GOVERN THESE, and that is a ruling. Every
	# other passive in the game takes its size from the part grade; capacity does
	# not, and the nets are nearly flat across all five — +1, +2, +2, +2, +2.
	#
	# Capacity is a BUDGET rather than power. A legendary plate giving three times
	# a common one gives you more hull; a legendary coupling giving three times a
	# common one changes how much SHIP you can hold, which compounds through every
	# part you fit afterwards. Same number, much bigger swing, so the ladder stops
	# at the reactor door.
	#
	# ALWAYS READ THE NET. The grant alone means nothing: a 4-cell armature
	# granting 6 leaves room for 2, which is exactly what a 1-cell cable granting
	# 3 leaves. Printing the grant made the armature look like three times the
	# cable, and somebody asked why, which is how the display got fixed.
	#
	# CAPACITY ONLY, NEVER OUTPUT. None of them hands out energy per turn. Energy
	# is the axis every card is priced against — three of it plays two cards and
	# five plays four — so it stays with the hull, the `overspec_reactor` perk and
	# the Verity five-set, where there are exactly three of it and it can be
	# reasoned about. What these sell is ROOM.
	#
	# Four houses and the yard, and not the other three, because a power bus is a
	# thing a maker has an opinion about: Solari runs the reactor, the Combine
	# pulls one out of something else, Redline adds cable, and Korvan overbuilds
	# the armature. Cygnet, Verity and Calyx have nothing to say about it.
	_module(&"buscoupling", "Bus Coupling", &"", S, C0,
		"A second line to the same reactor. Not clever, not new, and on every
"
		+ "ship that ever came out of a yard.",
		[{name = "Shunt", energy = 1, vent = 2, draw = 1}, &"reroute"])
	_module(&"foundrybus", "Foundry Bus", &"solari", S, C2,
		"Solari runs power the way Solari runs everything: hot, and with the
"
		+ "covers off so you can watch it.",
		[{name = "Cold Start", energy = 0, vent = 4, energy_gain = 1}, &"vent"])
	_module(&"trunkline", "Salvaged Trunk Line", &"probate", S, C1,
		"Pulled from something that had stopped needing it. The Combine does not
"
		+ "ask what, and the rider says you agreed not to either.",
		[{name = "Cannibalise", energy = 1, decommission = 1, armor = 6},
			{name = "Scrap Line", energy = 0, credit_gain = 3, discard = 1}])
	_module(&"jumper", "Jumper Cable", &"redline", U, C1,
		"Redline's answer to a power problem is more cable. It has worked every
"
		+ "time so far, which is the only figure they publish.",
		[{name = "Crossfeed", energy = 1, heat = 2, damage = 4, draw = 2}, &"reroute"])
	_module(&"mainbus", "Main Bus Armature", &"korvan", S, C2,
		"Korvan builds a power bus the way it builds a gun mount: heavier than it
"
		+ "needs to be, and still bolted on when the rest of the ship is gone.",
		[{name = "Hard Line", energy = 0, armor = 5, block = 4},
			{name = "Standing Load", energy = 2, armor = 12}])

	for id in GENERIC_STOCK:
		(modules[id] as ModuleData).starter_only = true

	_seed_module_passives()
	_seed_module_sizes()

## Sensors and Stealth, laid on modules that already exist.
##
## Adding six attribute-bearing modules would have been the obvious move and the
## wrong one — CLAUDE.md's fifth priority is to resist adding content until the
## loop feels good. Every one of these already reads as the thing it now does:
## an Auspex Array is a sensor, a Ghost Drive hides you, a flare rack does the
## exact opposite. The attribute was latent in the catalog; this names it.
##
## Kept in one table rather than as two more arguments on _module() because it
## is a property of six modules out of thirty-four, and thirty-four call sites
## carrying `0, 0` would bury the six that matter.
## How much hold each part takes. See ModuleData.size for what a shape MEANS.
##
## A default per slot and a list of exceptions, rather than 55 sizes written out
## one at a time. The default is the honest claim — a system is a compact unit, a
## utility is a fitting — and every entry below is a part whose NAME already says
## it is not: a Lance is long, a Bay is bulky, a Scope is neither.
##
## The test applied to each was "would you be surprised to see this shape in the
## hold". A Precursor Lattice at 2x2 is not surprising; a Coolant Line at
## anything but 1x1 would be.
func _seed_module_sizes() -> void:
	# FOUR ACROSS, and the only shape a light hull cannot rotate. A light hold is
	# 4x3, so a spinal gun fills an entire row of the twelve cells a skiff has and
	# stood on end does not fit at all — the grid refuses it, because 1x4 runs off
	# the bottom. That is a real decision rather than a side effect: it makes hull
	# weight bite in the HOLD, where until now it only bit in the mount count.
	#
	# Three guns carry it and they are the three whose names already said so: a
	# siege driver, a drumfire and a rail are things a frame is built around.
	const SPINE := Vector2i(4, 1)
	const LONG := Vector2i(3, 1)
	const BULK := Vector2i(2, 2)
	const UNIT := Vector2i(2, 1)
	const FIT := Vector2i(1, 1)

	# The three the hull is built AROUND rather than hung with.
	var spinal: Array[StringName] = [&"widow", &"kh500", &"rail"]
	# Barrels, lances and rails. The shape IS the barrel.
	var long_ones: Array[StringName] = [
		&"km4", &"widow", &"kh500", &"plasma", &"ventcan", &"breaker",
		&"needle", &"rail", &"beam", &"slug",
		# A trunk line IS its length.
		&"trunkline",
	]
	# Bays, arrays, cradles and heavy plate — things with a volume rather than a
	# barrel. `singing` and `lattice` are precursor artifacts and read as blocks.
	var bulky: Array[StringName] = [
		&"dronebay", &"ripper", &"singing",
		&"reactive", &"bulkhead", &"verity", &"lattice", &"braceframe", &"slag",
		&"refinery", &"organ", &"mainbus", &"cryobat", &"keel", &"sepulchre",
	]
	# Utility that is a piece of EQUIPMENT rather than an instrument.
	var util_units: Array[StringName] = [
		&"flare", &"chaff", &"claw", &"ghost", &"standfast", &"director",
	]

	# WHAT THE REACTOR CAN CARRY, granted by a part. Here rather than in the
	# `_module` call because `_module` takes what a part IS and the passives are
	# seeded in a pass of their own, the same as sensors and stealth.
	# EVERY COUPLING RAISES REACTOR BY THE SAME +2 LEVELS, which the table turns
	# into six cells and, where the step falls, a point of energy. The part's
	# number and the number on the bar are now the same number — somebody asked
	# why the armature granted six, and the honest answer used to be that six was
	# picked to make its net come out at two.
	#
	# FLAT ACROSS ALL FIVE. Capacity is a budget and does not climb with grade;
	# what differs is what each part COSTS to run, so a 1-cell cable keeps more of
	# its own six than a 2x2 armature does.
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

## THE ATTRIBUTE LADDER. What a grade is worth, in PIPS on the one gauge a part
## moves. Indexed by ModuleData.Rarity.
##
##     COMMON 0   UNCOMMON 0   RARE 1   EPIC 2   LEGENDARY 3
##     EXOTIC 3   ARTIFACT 4   CONTRABAND 2
##
## COMMON AND UNCOMMON GIVE NOTHING, which is a statement and not an oversight:
## yard stock is CARDS. Hull Plating used to carry +3 hull while a Brace Frame,
## which is two grades rarer, carried +2 — the table was authored one part at a
## time and had drifted into saying a common was better than a rare at the thing
## the rare is named for. A ladder cannot drift.
##
## The cost of that is real and worth knowing: a run now opens with no passive
## stats at all, because the entire starting kit is common. The first rare part
## you bolt on is the first pip you have ever had.
##
## EXOTIC MATCHES LEGENDARY AND PAYS FOR IT somewhere else. Grown things are
## alive and inconvenient, and the trade is the identity rather than a bigger
## number — a Voidwhale Ganglion hears everything in the system, and everything
## in the system hears it. ARTIFACT is the top of the found ladder and there are
## two of them. CONTRABAND sits at Epic on purpose: it is not a quality grade at
## all, it is a fact about who sold it to you, so it performs like an epic and
## carries risk instead of power.
## The script, not the singleton. RunState carries no class_name and Database
## is the autoload BEFORE it, so `Run.PER_PIP` is a null dereference at the
## moment the catalogue is built. A preload reaches the constants without
## needing the node to exist.
const RUNSTATE := preload("res://scripts/autoload/RunState.gd")

const ATTR_BUMP := [0, 0, 1, 2, 3, 3, 4, 2]

## WHAT A COUPLING IS WORTH, in pips of REACTOR. Flat, and deliberately off the
## ladder above — the ruling is written beside the parts themselves.
const REACTOR_BUMP := 2

## WHICH GAUGE A PART MOVES. The size is not here — it comes from the grade,
## through ATTR_BUMP and RunState.PER_PIP. This table only answers "which one".
##
## ONE GAUGE FOR MOST PARTS, AND TWO FOR A FEW. Cold Sights used to carry vent AND
## sensors, Ghost Drive dodge AND stealth, the Fire Director initiative AND
## sensors — so "a rare part is worth one pip" could not be true of any of them,
## and a part quietly moving two gauges was worth double its grade with nothing
## on the screen saying so. The axis is the one the NAME picks: sights see, a
## drive is how you are not there, a director decides.
##
## A part with no entry moves nothing, and most of the catalogue has none. That
## is deliberate as well: the axis has to be latent in what the part IS, and a
## gun is not a claim about any of the six.
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
	# TWO GAUGES, AND THE FULL BUMP ON BOTH. A part that does two things gets
	# paid for two things — Pillar 5, and the reason a build that comes together
	# should feel absurd. The Standfast Rig grants Standfast (armour AND vent) and
	# Hold Fast; it plants you and it sheds what planting costs, and it was
	# reading as neither.
	&"standfast": [&"hull", &"thermal"],
	# The rungs that had nobody on them.
	&"cryobat": [&"thermal"], &"gunnery": [&"sensors"],
	&"keel": [&"hull"], &"sepulchre": [&"thermal"], &"oracle": [&"sensors"],
}


## WHAT A PART COSTS YOU, in pips, on a gauge that is not its own.
##
## Not a grade bump and not on the ladder — these are prices, authored per part,
## and they are what lets the ladder stay flat at the top. A Solari flare rack
## lights you up. A Voidwhale Ganglion is a living antenna and transmits as well
## as it listens. Both were true in the flavour before they were true in the
## numbers.
const PASSIVE_COST := {
	&"flare": [&"stealth", 1],
	&"organ": [&"stealth", 1],
}


## Every passive in the catalogue, derived rather than authored.
##
## This replaces two hand-written tables of raw numbers — one for sensors and
## stealth, one for the four gauges under them — and the point of replacing them
## is that a hand-written number cannot be checked against a rule. It is now
## impossible to author a common that out-plates a rare, because nobody authors
## the plating: the grade does.
##
## Rounded into the field it lands in. `dodge` is a float and keeps its
## fraction; everything else is an int, so a pip of venting is 2 rather than
## 1.5. That rounding is exactly why `-- attrtest` measures the gauge instead of
## trusting this.
func _seed_module_passives() -> void:
	for id in PASSIVE_AXIS:
		var m: ModuleData = modules[id]
		for axis in PASSIVE_AXIS[id]:
			_lay_pips(m, axis, ATTR_BUMP[int(m.rarity)])
	for id in PASSIVE_COST:
		var row: Array = PASSIVE_COST[id]
		_lay_pips(modules[id] as ModuleData, row[0], -int(row[1]))


## Move one gauge by `pips`, through every field that gauge is made of.
##
## THERMAL and MANEUVER each have two, and BOTH move. That is the whole point
## of a gauge being one entry: a part says +1 MANEUVER and gets faster and
## harder to hit, because those are not two things a player weighs separately
## while reading one bar.
##
## `+=` and not `=`, so a part can take a bump on one axis and a price on
## another without the second overwriting the first. The Voidwhale Ganglion is
## the part that needs it, and it would have silently lost its bump.
func _lay_pips(m: ModuleData, axis: StringName, pips: int) -> void:
	if pips == 0:
		return
	var fields: Dictionary = RUNSTATE.PER_PIP[axis]
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


# ------------------------------------------------------------------------ hulls

## Twenty-four hulls: each of seven manufacturers in all three weight classes,
## plus the three unbranded salvage frames.
##
## AUTHORED AS BASELINE + SIGNATURE, not as twenty-four stat blocks. Weight class
## decides the shape of a ship — a light frame is fast and thin whoever welded
## it — and the manufacturer decides how that shape is bent. Writing all
## twenty-four out by hand would scatter each maker's identity across three
## rows, so "what IS Solari" would only be answerable by diffing three tables,
## and a signature could drift between weights without anyone noticing.
##
## Here it is one line per maker. Solari is +8 heat capacity, -1 dissipation and
## -2 stealth, on every frame it builds. That is the whole manufacturer.
##
## DISSIPATION IS SMALL ON PURPOSE — one or two a turn, four at the very top.
## It used to run to eight, which vented a full combat's worth of heat for free
## and made the cooling cards decorative: you could fire the hot weapon every
## turn and the hull paid it off behind you. Passive venting is now a trickle,
## so getting heat off is something you spend a card on, and capacity is what
## decides how long you can put that off.
const WEIGHT_BASE := {
	# Two system mounts, not one. A light frame has the BIGGEST hand and the
	# FEWEST mounts, and those compound the wrong way: fewer mounts is fewer
	# modules is fewer cards, so the ship that draws six was the ship with a
	# five-card deck. Measured, an Atelier Yacht opened with four cards against
	# a hand of five — every turn identical, nothing to sequence, no deck at all.
	# The extra system slot is where the floor comes from.
	HullData.Weight.LIGHT: {
		hand_size = 6, max_hull = 24, heat_cap = 8, dissipation = 2,
		dodge = 0.18, initiative = 2, fuel_factor = 0.8, cargo_slots = 12,
		hold_grid = Vector2i(4, 3),
		weapon_slots = 2, system_slots = 2, utility_slots = 2},
	# A second utility mount, because the middle had nothing of its own.
	#
	# Measured across 250 runs on each of twenty-one chassis, mediums averaged
	# 15.2% against 20.2% for lights and 21.7% for heavies — and Switchback, the
	# worst ship in the game, was the worst case of that rather than its own
	# problem. A medium had six mounts like a light and a hand of five like
	# nothing else: strictly between the two, with no compensating advantage.
	# Seven mounts is the compensation, and versatility is a coherent thing for
	# the middle of a range to be.
	HullData.Weight.MEDIUM: {
		hand_size = 5, max_hull = 35, heat_cap = 12, dissipation = 1,
		dodge = 0.05, initiative = 0, fuel_factor = 1.2, cargo_slots = 20,
		hold_grid = Vector2i(5, 4),
		weapon_slots = 3, system_slots = 2, utility_slots = 2},
	HullData.Weight.HEAVY: {
		hand_size = 4, max_hull = 52, heat_cap = 18, dissipation = 1,
		dodge = 0.0, initiative = -2, fuel_factor = 1.8, cargo_slots = 30,
		hold_grid = Vector2i(6, 5),
		weapon_slots = 4, system_slots = 2, utility_slots = 1},
}

## The four specification classes a frame comes in, worst to best. A hull is a
## SHAPE and a CLASS: an S-class Ironside is the same yard's answer to the same
## job, built to a better standard — not a C-class that somebody looked after.
##
## That distinction is load-bearing and was got wrong once. This table grows
## HARDPOINTS at A and S, which no amount of maintenance does; condition is a
## separate axis entirely, lives on hull points, and is drawn by HullWear onto
## the sprite. One letter cannot mean both.
##
## Tier has existed on HullData since the beginning and was never authored — it
## was a bag of random bumps inside LootGen.roll_hull, applied to whatever frame
## came out of the pick. That had two problems worth naming. It was NOT
## REPRODUCIBLE as a description: "an A-class Bastion" named a distribution
## rather than a ship, and two of them could differ by a hardpoint, because a
## weapon mount was granted on a coin flip at B. And it was invisible — nothing
## in the interface has ever shown the player a letter.
##
## SCALE rather than flat bonuses, so a grade is the same PROPORTIONAL upgrade on
## every frame it is applied to. A flat +21 hull is 87% of a light and 40% of a
## heavy; +52% is +52% of both. The numbers below compound to roughly half again
## the hull from C to S, which is about what the random bumps averaged out to —
## the one thing here chosen to match the old behaviour rather than improve on it.
##
## MOUNTS ARE THE REWARD, and only at the top two grades. A is where a frame
## grows a weapon hardpoint; S adds a system one and the reactor to run it. That
## is deliberately a bigger jump than more hull, because a mount is a card, and a
## card is the thing this game is actually made of.
##
## Applied ONLY to a tier-0 frame. `at_tier` SCALES, so handing it a hull that
## already carries a grade compounds it silently. Everything in `hull_frames` is
## tier 0 by construction; nothing else should be passed.
## Named in HullData, which owns what a grade IS. This table owns what it DOES,
## and the two are indexed the same — keep them the same length.
## THE REACTOR LEVEL IS SET, NOT ADDED. Every other field here is a delta on
## the frame; this one is absolute, because the grade letter is the only thing
## that decides it. It used to be the weight class with a delta on top — heavy
## carried a reactor of 4 and S added one — which meant C and B were the same
## ship twice and the letter told a player almost nothing.
##
## 4 / 5 / 7 / 8, which RunState.REACTOR_TABLE turns into:
##
##     C   12 cells, 3 energy       A   21 cells, 4 energy
##     B   15 cells, 3 energy       S   24 cells, 5 energy
##
## A AND S SKIP A RUNG EACH, which is where the energy steps are. The gap from
## B to A is the largest on the ladder and it is meant to be: it is the one
## that buys a fourth point of energy, and energy is the axis every card is
## priced against.
##
## 24 AT THE TOP STILL BITES. A fully mounted S heavy is five weapons, three
## systems and a utility, and the catalogue averages 2.80 / 2.55 / 1.57 cells
## for those — 23.2 to fill it, against 24 with nothing spare for a big gun.
## The best hull in the game still cannot run everything it can bolt on.
const TIER_DELTA := [
	{scale = 1.00, weapon = 0, system = 0, reactor = 4, dissipation = 0},
	{scale = 1.15, weapon = 0, system = 0, reactor = 5, dissipation = 0},
	{scale = 1.32, weapon = 1, system = 0, reactor = 7, dissipation = 1},
	{scale = 1.52, weapon = 1, system = 1, reactor = 8, dissipation = 1},
]

## Per-maker deltas applied on top, and the three names. `names` runs
## light, medium, heavy.
const MAKER_HULLS := {
	&"korvan": {
		names = ["Picket Cutter", "Ironside Cutter", "Bastion Monitor"],
		perk_id = &"baffled_vents",
		d = {max_hull = 5, heat_cap = 2, dodge = -0.02, initiative = -1}},
	&"solari": {
		names = ["Cinder Skiff", "Emberwright", "Furnace Baron"],
		perk_id = &"overspec_reactor",
		d = {heat_cap = 8, dissipation = -1, stealth = -2, fuel_factor = 0.1}},
	&"probate": {
		names = ["Tin Picker", "Scrap Hauler", "Ore Barge"],
		perk_id = &"salvage_rack",
		d = {max_hull = 8, heat_cap = 2, dissipation = -1, initiative = -1,
			fuel_factor = 0.2, stealth = -1, utility_slots = 1, weapon_slots = -1}},
	# Measured worst in the game by a wide margin — a Switchback won 8.6% where a
	# Greatvine won 31.8% — and the trade is why: -6 hull off a 35-point medium
	# is seventeen per cent of the ship, bought with three per cent of dodge.
	# That was never going to pay.
	#
	# It also had the one perk we PROVED does nothing. cheap_parts halves repair
	# prices, and cutting repair prices by 40% across the whole game moved the
	# win rate inside its own noise band — so Redline was effectively flying
	# without a perk. spare_bay gives it a mount instead, which suits a house
	# whose whole business is refits.
	&"redline": {
		names = ["Hairpin", "Switchback", "Blindside"],
		perk_id = &"spare_bay",
		d = {max_hull = -3, dodge = 0.06, initiative = 1, fuel_factor = -0.1,
			sensors = 1, stealth = 2}},
	&"cygnet": {
		names = ["Fledgling", "Brood Tender", "Rookery"],
		perk_id = &"spare_bay",
		d = {max_hull = -3, dissipation = 1, dodge = 0.03, initiative = 1,
			fuel_factor = -0.1, sensors = 2, utility_slots = 1, weapon_slots = -1}},
	&"verity": {
		names = ["Atelier Yacht", "Commission", "Magnum Opus"],
		perk_id = &"overspec_reactor",
		d = {max_hull = -2, reactor = 1, hand_size = -1, dodge = 0.05, initiative = 1,
			fuel_factor = -0.1, sensors = 2, stealth = 1, weapon_slots = -1}},
	# Strongest maker at every weight, measured twice. The hull bonus is the part
	# that had no business being there: Calyx is regeneration and adaptation, not
	# armour, and +2 max hull on top of the extra system mount and the best
	# dissipation in the game made its heavy the best chassis by six points.
	# It keeps everything that is actually its identity.
	&"calyx": {
		names = ["Spore Cutter", "Vivarium", "Greatvine"],
		perk_id = &"baffled_vents",
		d = {dissipation = 1, dodge = 0.02, fuel_factor = -0.1,
			sensors = 1, stealth = 1, system_slots = 1, weapon_slots = -1}},
}

func _seed_hulls() -> void:
	# The unbranded three, kept exactly as this game shipped them. A derelict has
	# to be able to offer a chassis that carries no allegiance — it is what keeps
	# "identity is assembled mid-run" true after choosing a maker at the start,
	# because taking a salvage frame COSTS you a set piece.
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
		apply_hull_lines(h)
		h.exhaust = hull_exhaust(d.weight)
		h.exhaust_frames = EXHAUST_FRAMES
		h.exhaust_offset = hull_exhaust_at(d.weight)
		hull_frames.append(h)

	for man in MAKER_HULLS:
		var spec: Dictionary = MAKER_HULLS[man]
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			hull_frames.append(_maker_hull(man, w, spec))

func _maker_hull(man: StringName, w: HullData.Weight, spec: Dictionary) -> HullData:
	var h := HullData.new()
	var base: Dictionary = WEIGHT_BASE[w]
	for k in base.keys():
		h.set(k, base[k])
	var d: Dictionary = spec.d
	for k in d.keys():
		h.set(k, h.get(k) + d[k])
	# Floors, because a delta table cannot see what it collides with: Verity's
	# -1 weapon slot on a light frame would otherwise build a warship with one
	# gun and Calyx's would build one with none.
	h.weapon_slots = maxi(1, h.weapon_slots)
	h.system_slots = maxi(1, h.system_slots)
	h.utility_slots = maxi(1, h.utility_slots)
	h.dissipation = maxi(1, h.dissipation)
	h.dodge = maxf(0.0, h.dodge)
	h.fuel_factor = maxf(0.5, h.fuel_factor)
	# WEIGHT_BASE holds stats, not identity, so the weight itself is not among
	# the keys copied above. Without this every maker hull stayed at HullData's
	# default MEDIUM and hull_for(man, LIGHT) matched nothing.
	h.weight = w
	h.manufacturer = man
	h.name = spec.names[int(w)]
	h.perk_id = spec.perk_id
	h.sprite = hull_sprite(w)
	apply_hull_lines(h)
	h.exhaust = hull_exhaust(w)
	h.exhaust_frames = EXHAUST_FRAMES
	h.exhaust_offset = hull_exhaust_at(w)
	return h

## The art for a weight class at a specification class, or null to fall back to
## ShipView's procedural drawing.
##
## Every sprite is given to every manufacturer, not just Korvan's. That is
## knowingly wrong: these hulls wear Korvan amber and a Solari one should not. It
## stands because the point of the step is to judge real hulls in the running
## game, and hiding them behind a single chassis would mean almost never seeing
## them. Per-manufacturer hulls, or a livery tint over a neutral one, is the next
## art decision — see ART_CONTRACT.md §5.
##
## KEYED ON CLASS AS WELL AS WEIGHT, which is what finally makes C through S
## something a player can SEE. TIER_DELTA has granted an A-class frame an extra
## weapon hardpoint and an S-class one a system mount since it was written, and
## none of it was visible — a C and an S were the same picture with different
## numbers behind them.
##
## Four sprites per weight rather than a base plus composited fittings. That was
## the other plan and it lost: bays measured off the medium, a fitting engine to
## bolt things into them, a template pipeline to force the profile. Every part
## worked and the sum was worse than picking four hulls out of thirty. The
## fitting engine survives in HullFit for whenever a hull has room for it.
##
## ALL THREE WEIGHTS, twelve sprites, so the procedural path no longer draws any
## player hull. `hull_medium_cold.png` stays on disk and stays the canonical
## style reference every generation is seeded from — it is simply no longer the
## thing rendered.
func hull_sprite(w: HullData.Weight, cls: int = 0) -> Texture2D:
	var n := hull_art_name(w, cls)
	if n == "":
		return null
	return load("res://art/sprites/%s.png" % n) as Texture2D

## The art file for a weight and class, without the extension. One place the
## naming convention is written, so the sprite and its measured lines cannot
## disagree about which hull they describe.
func hull_art_name(w: HullData.Weight, cls: int = 0) -> String:
	var stem := ""
	match w:
		HullData.Weight.LIGHT: stem = "light"
		HullData.Weight.MEDIUM: stem = "medium"
		HullData.Weight.HEAVY: stem = "heavy"
		_: return ""
	# TIER_NAMES is an untyped Array, so an element comes back as Variant and
	# `:=` has nothing to infer from. Declared rather than inferred.
	var letter: String = HullData.TIER_NAMES[clampi(cls, 0, 3)]
	return "hull_%s_%s" % [stem, letter.to_lower()]

## Copy the measured dorsal, ventral and flank lines onto a hull.
##
## Called wherever the SPRITE is set, and for the same reason `exhaust_offset`
## is: the lines are measured against one specific image, so a hull carrying
## another hull's lines mounts its guns in mid-air. Keeping the two assignments
## adjacent is what stops them drifting apart.
func apply_hull_lines(h: HullData) -> void:
	var key := hull_art_name(h.weight, h.tier)
	if not HULL_LINES.has(key):
		return
	var d: Dictionary = HULL_LINES[key]
	h.dorsal = PackedVector2Array(d.dorsal)
	h.ventral = PackedVector2Array(d.ventral)
	h.flank = PackedVector2Array(d.flank)

## Measured off each hull's own silhouette by `art/tools/anchors.py`.
##
## GENERATED. Re-run the tool after replacing a hull sprite; a line measured
## against art that has since changed puts mounts in mid-air, and nothing about
## that fails loudly. `-- mounts` is what makes it fail loudly.
##
## Lines rather than points, because a hull carries one to five mounts of a kind
## depending on weight, class and maker — a fixed list of five used two at a time
## clusters both at one end of the ship. See HullData.mounts_along().
##
## Plain Vector2 arrays, not PackedVector2Array: the packed constructor is a CALL
## and a `const` needs an expression the compiler can fold. Converted on assignment.
const HULL_LINES := {
	"hull_heavy_a": {
		dorsal = [Vector2(38, 5), Vector2(54, 5), Vector2(69, 5), Vector2(84, 5), Vector2(100, 5), Vector2(116, 5), Vector2(131, 5), Vector2(146, 5), Vector2(162, 5)],
		ventral = [Vector2(38, 54), Vector2(54, 54), Vector2(69, 54), Vector2(84, 54), Vector2(100, 54), Vector2(116, 54), Vector2(131, 54), Vector2(146, 54), Vector2(162, 54)],
		flank = [Vector2(38, 29), Vector2(54, 29), Vector2(69, 29), Vector2(84, 29), Vector2(100, 29), Vector2(116, 29), Vector2(131, 29), Vector2(146, 29), Vector2(162, 29)],
	},
	"hull_heavy_b": {
		dorsal = [Vector2(38, 5), Vector2(54, 5), Vector2(69, 5), Vector2(84, 5), Vector2(100, 5), Vector2(116, 5), Vector2(131, 5), Vector2(146, 5), Vector2(162, 5)],
		ventral = [Vector2(38, 54), Vector2(54, 54), Vector2(69, 54), Vector2(84, 54), Vector2(100, 54), Vector2(116, 54), Vector2(131, 54), Vector2(146, 54), Vector2(162, 54)],
		flank = [Vector2(38, 29), Vector2(54, 29), Vector2(69, 29), Vector2(84, 29), Vector2(100, 29), Vector2(116, 29), Vector2(131, 29), Vector2(146, 29), Vector2(162, 29)],
	},
	"hull_heavy_c": {
		dorsal = [Vector2(38, 5), Vector2(54, 5), Vector2(69, 5), Vector2(84, 5), Vector2(100, 5), Vector2(116, 5), Vector2(131, 5), Vector2(146, 5), Vector2(162, 5)],
		ventral = [Vector2(38, 54), Vector2(54, 54), Vector2(69, 54), Vector2(84, 54), Vector2(100, 54), Vector2(116, 54), Vector2(131, 54), Vector2(146, 54), Vector2(162, 54)],
		flank = [Vector2(38, 29), Vector2(54, 29), Vector2(69, 29), Vector2(84, 29), Vector2(100, 29), Vector2(116, 29), Vector2(131, 29), Vector2(146, 29), Vector2(162, 29)],
	},
	"hull_heavy_s": {
		dorsal = [Vector2(38, 5), Vector2(54, 5), Vector2(69, 5), Vector2(84, 5), Vector2(100, 5), Vector2(116, 5), Vector2(131, 5), Vector2(146, 5), Vector2(162, 5)],
		ventral = [Vector2(38, 54), Vector2(54, 54), Vector2(69, 54), Vector2(84, 54), Vector2(100, 54), Vector2(116, 54), Vector2(131, 54), Vector2(146, 54), Vector2(162, 54)],
		flank = [Vector2(38, 29), Vector2(54, 29), Vector2(69, 29), Vector2(84, 29), Vector2(100, 29), Vector2(116, 29), Vector2(131, 29), Vector2(146, 29), Vector2(162, 29)],
	},
	"hull_light_a": {
		dorsal = [Vector2(38, 5), Vector2(47, 5), Vector2(56, 5), Vector2(66, 5), Vector2(75, 5), Vector2(84, 5), Vector2(94, 5), Vector2(103, 5), Vector2(112, 5)],
		ventral = [Vector2(38, 34), Vector2(47, 34), Vector2(56, 34), Vector2(66, 34), Vector2(75, 34), Vector2(84, 34), Vector2(94, 34), Vector2(103, 34), Vector2(112, 34)],
		flank = [Vector2(38, 19), Vector2(47, 19), Vector2(56, 19), Vector2(66, 19), Vector2(75, 19), Vector2(84, 19), Vector2(94, 19), Vector2(103, 19), Vector2(112, 19)],
	},
	"hull_light_b": {
		dorsal = [Vector2(38, 5), Vector2(47, 5), Vector2(56, 5), Vector2(66, 5), Vector2(75, 5), Vector2(84, 5), Vector2(94, 5), Vector2(103, 5), Vector2(112, 5)],
		ventral = [Vector2(38, 34), Vector2(47, 34), Vector2(56, 34), Vector2(66, 34), Vector2(75, 34), Vector2(84, 34), Vector2(94, 34), Vector2(103, 34), Vector2(112, 34)],
		flank = [Vector2(38, 19), Vector2(47, 19), Vector2(56, 19), Vector2(66, 19), Vector2(75, 19), Vector2(84, 19), Vector2(94, 19), Vector2(103, 19), Vector2(112, 19)],
	},
	"hull_light_c": {
		dorsal = [Vector2(38, 5), Vector2(47, 5), Vector2(56, 5), Vector2(66, 5), Vector2(75, 5), Vector2(84, 5), Vector2(94, 5), Vector2(103, 5), Vector2(112, 5)],
		ventral = [Vector2(38, 34), Vector2(47, 34), Vector2(56, 34), Vector2(66, 34), Vector2(75, 34), Vector2(84, 34), Vector2(94, 34), Vector2(103, 34), Vector2(112, 34)],
		flank = [Vector2(38, 19), Vector2(47, 19), Vector2(56, 19), Vector2(66, 19), Vector2(75, 19), Vector2(84, 19), Vector2(94, 19), Vector2(103, 19), Vector2(112, 19)],
	},
	"hull_light_s": {
		dorsal = [Vector2(38, 5), Vector2(47, 5), Vector2(56, 5), Vector2(66, 5), Vector2(75, 5), Vector2(84, 5), Vector2(94, 5), Vector2(103, 5), Vector2(112, 5)],
		ventral = [Vector2(38, 34), Vector2(47, 34), Vector2(56, 34), Vector2(66, 34), Vector2(75, 34), Vector2(84, 34), Vector2(94, 34), Vector2(103, 34), Vector2(112, 34)],
		flank = [Vector2(38, 19), Vector2(47, 19), Vector2(56, 19), Vector2(66, 19), Vector2(75, 19), Vector2(84, 19), Vector2(94, 19), Vector2(103, 19), Vector2(112, 19)],
	},
	"hull_medium_a": {
		dorsal = [Vector2(38, 5), Vector2(50, 5), Vector2(63, 5), Vector2(75, 5), Vector2(88, 5), Vector2(100, 5), Vector2(112, 5), Vector2(125, 5), Vector2(137, 5)],
		ventral = [Vector2(38, 44), Vector2(50, 44), Vector2(63, 44), Vector2(75, 44), Vector2(88, 44), Vector2(100, 44), Vector2(112, 44), Vector2(125, 44), Vector2(137, 44)],
		flank = [Vector2(38, 24), Vector2(50, 24), Vector2(63, 24), Vector2(75, 24), Vector2(88, 24), Vector2(100, 24), Vector2(112, 24), Vector2(125, 24), Vector2(137, 24)],
	},
	"hull_medium_b": {
		dorsal = [Vector2(38, 5), Vector2(50, 5), Vector2(63, 5), Vector2(75, 5), Vector2(88, 5), Vector2(100, 5), Vector2(112, 5), Vector2(125, 5), Vector2(137, 5)],
		ventral = [Vector2(38, 44), Vector2(50, 44), Vector2(63, 44), Vector2(75, 44), Vector2(88, 44), Vector2(100, 44), Vector2(112, 44), Vector2(125, 44), Vector2(137, 44)],
		flank = [Vector2(38, 24), Vector2(50, 24), Vector2(63, 24), Vector2(75, 24), Vector2(88, 24), Vector2(100, 24), Vector2(112, 24), Vector2(125, 24), Vector2(137, 24)],
	},
	"hull_medium_c": {
		dorsal = [Vector2(38, 5), Vector2(50, 5), Vector2(63, 5), Vector2(75, 5), Vector2(88, 5), Vector2(100, 5), Vector2(112, 5), Vector2(125, 5), Vector2(137, 5)],
		ventral = [Vector2(38, 44), Vector2(50, 44), Vector2(63, 44), Vector2(75, 44), Vector2(88, 44), Vector2(100, 44), Vector2(112, 44), Vector2(125, 44), Vector2(137, 44)],
		flank = [Vector2(38, 24), Vector2(50, 24), Vector2(63, 24), Vector2(75, 24), Vector2(88, 24), Vector2(100, 24), Vector2(112, 24), Vector2(125, 24), Vector2(137, 24)],
	},
	"hull_medium_s": {
		dorsal = [Vector2(38, 5), Vector2(50, 5), Vector2(63, 5), Vector2(75, 5), Vector2(88, 5), Vector2(100, 5), Vector2(112, 5), Vector2(125, 5), Vector2(137, 5)],
		ventral = [Vector2(38, 44), Vector2(50, 44), Vector2(63, 44), Vector2(75, 44), Vector2(88, 44), Vector2(100, 44), Vector2(112, 44), Vector2(125, 44), Vector2(137, 44)],
		flank = [Vector2(38, 24), Vector2(50, 24), Vector2(63, 24), Vector2(75, 24), Vector2(88, 24), Vector2(100, 24), Vector2(112, 24), Vector2(125, 24), Vector2(137, 24)],
	},
}

## The widest canvas any player hull draws into, measured rather than typed.
##
## Anything that CROPS a hull has to know this, and the one place that does —
## the convoy strip — had it as a literal. That literal was correct against the
## procedural drawing it was written for and quietly wrong the moment real art
## landed: the sprites are cropped tight to their ships and run from 152 to 237
## across, so a constant sized for the old canvas took the nose off every heavy
## in the party. The strip's own comment said "nothing is ever cropped
## nose-first, which reads as a mistake rather than as distance", which is
## exactly what it then did.
##
## So it is asked rather than remembered. Twelve `load()` calls behind Godot's
## resource cache, once, on the first ask — the same twelve textures the hulls
## are already built from.
static var _widest: int = 0
func widest_hull() -> int:
	if _widest > 0:
		return _widest
	for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
		for cls in HullData.TIER_NAMES.size():
			var tex := hull_sprite(w, cls)
			if tex != null:
				_widest = maxi(_widest, tex.get_width())
	# A build with no hull art at all falls back to the procedural canvas rather
	# than to zero, which would crop every ship to nothing.
	return maxi(_widest, ShipView.W)

## The engine plume for a weight class: a 9-frame strip, cropped tight, which is
## why it carries an offset. See HullData.exhaust.
const EXHAUST_FRAMES := 9
## One frame of that strip is 32px tall.
const EXHAUST_H := 32
## The hull canvas is cropped tight around the ship so STRETCH_KEEP_CENTERED
## actually centres it. With 70px of dead space on the right the content sat
## left of centre, and at 2x the view clipped the flames off first.
##
## Kept as the fallback for a hull with no sprite to measure.
const EXHAUST_AT := Vector2i(0, 27)

func hull_exhaust(w: HullData.Weight) -> Texture2D:
	if w != HullData.Weight.MEDIUM:
		return null
	return load("res://art/sprites/hull_medium_exhaust.png") as Texture2D

## Where the plume attaches, DERIVED from the hull it attaches to.
##
## It used to be one constant, which was correct while there was one medium
## sprite and silently wrong the moment there were four: each is cropped tight to
## its own ship, so they are 54 to 81 pixels tall and a fixed offset would hang
## the flame off the bottom of the shortest. Every medium is composed with 38px
## of clearance to the left of its engines — the geometry the one hull already
## had — so the plume centres on the hull's own canvas and nothing needs a table
## that a new sprite could fall out of step with.
func hull_exhaust_at(w: HullData.Weight, cls: int = 0) -> Vector2i:
	var tex := hull_sprite(w, cls)
	if tex == null:
		return EXHAUST_AT
	return Vector2i(0, tex.get_height() / 2 - EXHAUST_H / 2)

## What each manufacturer CALLS its three weight classes.
##
## AUTHORED BUT NOT DISPLAYED. The screens print plain LIGHT / MEDIUM / HEAVY,
## because that is what reads for a player: weight class is the fact you compare
## ACROSS makers, and this turns one shared word into twenty-one to learn. Kept
## because the names are content rather than code, and the moment there is
## somewhere flavour costs nothing — a tooltip, a shipyard, a flight record —
## hull_class() is already here.
##
## Real vessel types, one coherent family per maker, escalating in size. This is
## free identity: a Probate heavy called a Barge and a Verity heavy called a
## Barque tell you who built them before you have read the maker name, and the
## hull names were already doing this work while the line underneath them said a
## flat "HEAVY CHASSIS".
##
## Korvan and Solari are the two warship lines because they are the two houses
## that mirror each other mechanically. Probate gets working boats: nobody names a
## barge to impress you. Redline gets fast rigs and a smuggling term. Cygnet gets
## the three real vessel types that exist to carry OTHER vessels, which is the
## house motto stated as a hull class. Verity gets sailing rigs, where the rig
## itself is the craftsmanship. Calyx gets the three real hulls with no cut
## timber and no metal in them at all: a coracle is woven willow under a stretched
## hide, a pirogue is one hollowed tree, and an umiak is driftwood ribs under
## sewn skin, big enough to carry a whole crew. Grown, not built, literally.
##
## The MECHANICAL word is not replaced by these, only fronted. Weight class is
## what a player compares across makers, and this turns one shared word into
## twenty-one — so `HullData.weight_name()` stays, and the screens print both.
const CLASS_NAMES := {
	&"korvan":  ["Cutter", "Frigate", "Monitor"],
	&"solari":  ["Skiff", "Corvette", "Dreadnought"],
	&"probate": ["Trawler", "Scow", "Barge"],
	&"redline": ["Sloop", "Runner", "Clipper"],
	&"cygnet":  ["Pinnace", "Tender", "Carrier"],
	&"verity":  ["Yawl", "Schooner", "Barque"],
	&"calyx":   ["Coracle", "Pirogue", "Umiak"],
}

## The maker's name for a weight class, or the plain word for an unbranded frame.
##
## Not called class_name() — that is a GDScript keyword.
func hull_class(man: StringName, w: HullData.Weight) -> String:
	if CLASS_NAMES.has(man):
		return CLASS_NAMES[man][int(w)]
	return HullData.weight_name(w)

## The hull a manufacturer builds in a given weight class. Lookup by value
## rather than by index: an index would work today and break the moment anyone
## reorders the tables above, which is exactly the edit those tables invite.
func hull_for(man: StringName, w: HullData.Weight = HullData.Weight.MEDIUM) -> HullData:
	for h in hull_frames:
		if h.manufacturer == man and h.weight == w:
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
	# AND THE ART. A class grants hardpoints and a reactor, and now it grants a
	# different hull — which is the whole point of the letter and was invisible
	# until there were four sprites to choose between.
	#
	# The plume has to move with it. Each sprite is cropped tight to its own
	# ship, so the four mediums are 54 to 81 pixels tall; swapping the texture
	# and keeping the frame's offset would hang the flame off the bottom of the
	# short ones.
	h.sprite = hull_sprite(h.weight, t)
	apply_hull_lines(h)
	h.exhaust_offset = hull_exhaust_at(h.weight, t)
	return h

func _seed_perks() -> void:
	hull_perks = {
		&"salvage_rack": {name = "Salvage Rack", text = "Scrapping modules pays +50%."},
		&"baffled_vents": {name = "Baffled Vents", text = "+1 heat dissipation."},
		&"overspec_reactor": {name = "Overspec Reactor", text = "+1 energy per turn."},
		&"spare_bay": {name = "Spare Bay", text = "+1 utility hardpoint."},
		&"cheap_parts": {name = "Cheap Parts", text = "Station repairs cost half."},
	}

func perk_text(id: StringName) -> String:
	if hull_perks.has(id):
		var p: Dictionary = hull_perks[id]
		return "%s: %s" % [p.name, p.text]
	return ""

# -------------------------------------------------------------------- materials
#
# The second half of the economy: things you take OFF a wreck rather than out of
# it. Credits are the currency and stay the only one — the ruling has not moved,
# only the name has — but a currency cannot be a prerequisite. A recipe that costs
# "40 credits" is a purchase; a recipe that costs "one precursor fragment" is a
# reason to have gone somewhere. Materials are what crafting is made of, and
# credits are what it costs.
#
# `exotic` is not new. It has existed since megafauna did, as a bare int on
# RunState, and it is now simply the first row of this table — same number, same
# sources, one ledger. Everything that said `Run.exotic` still does.

const MATERIALS: Array[Dictionary] = [
	{id = &"exotic", name = "Exotic", short = "EXO", colour = "#4fbfa8", value = 45,
		text = "Grown, not manufactured. Megafauna organs and whatever a pulsar leaves behind."},
	{id = &"relic", name = "Relic", short = "RLC", colour = "#d4614f", value = 90,
		text = "Precursor fragment. Nobody presses more of these and nobody knows how."},
]

## RETIRED with alloy. Kept as a comment rather than a constant so the shape is
## on record if parts ever break down into materials again: it was flat at the
## top on purpose, because rarity buys better verbs, not more metal — a Legendary is not
## a bigger lump of a Common, it is a cleverer one.

func material(id: StringName) -> Dictionary:
	for m in MATERIALS:
		if m.id == id:
			return m
	return {}

func material_name(id: StringName) -> String:
	var m := material(id)
	return str(m.get("name", id))

func material_value(id: StringName) -> int:
	return int(material(id).get("value", 1))

func material_colour(id: StringName) -> Color:
	return Color(str(material(id).get("colour", "#8fa3ba")))

# -------------------------------------------------------------------- recipes
#
# The fabricator, as data. Every recipe is {what it costs} -> {one effect the
# game already knows how to apply}, so adding one is a dictionary entry and
# never a new branch — the same law modules and cards are held to.
#
# `dev` is the minimum Development the place needs. Anywhere with a docking ring
# has a welder and a still; anything involving a laboratory needs a city. That is
# what makes the fabricator a REASON to visit a developed system rather than a
# button that follows you around the galaxy — and it is why the two basic recipes
# are dev 0. A station on unclaimed ground is still a station, and gating cheap
# fuel behind a flag on the wall is what strands people.
#
# Deliberately four. This is the stage crafting is built on, not crafting: the
# ledger, the recipe shape, the resolver and the place it happens. Recipes that
# reach into a specific module in the hold need a picker and a target, which is
# the next piece of work and not this one.

const RECIPES: Array[Dictionary] = [
	{id = &"braid", name = "COOLANT BRAID", kind = &"heat_cap", amount = 3, dev = 3,
		credits = 25, mats = {&"exotic": 1},
		text = "Organic capillary loop. +3 heat cap, permanently."},
	{id = &"analysis", name = "RELIC ANALYSIS", kind = &"artifact", amount = 1, dev = 3,
		credits = 40, mats = {&"relic": 1},
		text = "Have the fragment read. Fabricates a precursor module into the hold."},
]

# ---------------------------------------------------------------------- enemies

func _intent(d: Dictionary) -> IntentData:
	var i := IntentData.new()
	for k in d.keys():
		i.set(k, d[k])
	return i

func _enemy(id: StringName, name: String, tag: String, hp: int, armor: int,
		credits: int, art: StringName, loop: Array, pool: Array,
		fauna: bool = false, boss: bool = false) -> void:
	var e := EnemyTemplate.new()
	e.id = id
	e.name = name
	e.tag = tag
	e.max_hull = hp
	e.armor = armor
	e.credit_reward = credits
	e.art = art
	e.fauna = fauna
	e.boss = boss
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
	# Ships run fixed loops — machines are predictable.
	_enemy(&"cutter", "Rustjaw Cutter", "pirate skirmisher", 26, 0, 15, &"cutter", [
		{name = "Strafe", text = "Deal 5", damage = 5},
		{name = "Twin Guns", text = "Deal 3 × 2", damage = 3, hits = 2},
		{name = "Juke", text = "Gain 7 block", block = 7},
	], [])
	_enemy(&"lancer", "Corsair Lancer", "raider · fast", 34, 2, 22, &"cutter", [
		{name = "Lance", text = "Deal 9", damage = 9},
		{name = "Sear", text = "Deal 4 × 2", damage = 4, hits = 2},
		{name = "Vent Bloom", text = "Gain 5 block", block = 5},
	], [])
	_enemy(&"hulk", "Dreg Hulk", "salvage barge", 52, 6, 30, &"hulk", [
		{name = "Reinforce", text = "Gain 8 block", block = 8},
		{name = "Winding up…", text = "Charging a ram", telegraph = true},
		{name = "RAM", text = "Deal 14", damage = 14},
	], [])
	_enemy(&"marauder", "Vex Marauder", "raider · heavy weapons", 46, 4, 34, &"cutter", [
		{name = "Rake", text = "Deal 8", damage = 8},
		{name = "Barrage", text = "Deal 5 × 3", damage = 5, hits = 3},
		{name = "Harden", text = "Gain 8 block", block = 8},
	], [])
	_enemy(&"sentinel", "Combine Sentinel", "corporate security", 58, 8, 42, &"hulk", [
		{name = "Lock Plates", text = "Gain 9 block", block = 9},
		{name = "Pulse", text = "Deal 11", damage = 11},
		{name = "Sweep", text = "Deal 4 × 3", damage = 4, hits = 3},
	], [])
	# Fauna use weighted random pools — animals are not predictable.
	_enemy(&"whale", "Voidwhale Calf", "megafauna · pacifiable", 40, 0, 0, &"whale", [], [
		{name = "Drift Song", text = "Heals 4", heal = 4, weight = 30},
		{name = "Tail Sweep", text = "Deal 7", damage = 7, weight = 40},
		{name = "Spore Breath", text = "Deal 3, +1 Dross", damage = 3, dross = 1,
			dross_id = &"slowburn", weight = 30},
	], true)
	_enemy(&"leviathan", "Void Leviathan", "megafauna · adult", 88, 4, 0, &"whale", [], [
		{name = "Sounding", text = "Heals 8", heal = 8, weight = 20},
		{name = "Breach", text = "Deal 15", damage = 15, weight = 45},
		{name = "Spore Storm", text = "Deal 5, +2 Dross", damage = 5, dross = 2,
			dross_id = &"slag", weight = 35},
	], true)
	# Boss: unscaled, tuned by hand.
	_enemy(&"custodian", "The Custodian", "guardian of the light", 120, 8, 120, &"hulk", [
		{name = "Plated Up", text = "Gain 12 block", block = 12},
		{name = "Volley", text = "Deal 6 × 3", damage = 6, hits = 3},
		{name = "Charging…", text = "Something is spooling up", telegraph = true},
		{name = "Annihilate", text = "Deal 22", damage = 22},
	], [], false, true)

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

# -------------------------------------------------------------------- archive

## Somebody else's paperwork, recovered out of the dark.
##
## See `docs/lore.md` §5 for the rules these are written to. The short version,
## because it is the part that is easy to break: PRIMARY SOURCES, NEVER
## EXPOSITION. Every one of these was written by a person with a job, for a
## reader who already knew the context, and none of them is trying to tell you
## anything. The world arrives sideways or it does not arrive.
##
## Two invariants worth stating because they are invisible in the data:
##
## **The epochs do not reconcile.** Korvan counts surveys, Probate counts filings,
## Verity counts commissions and the transponders count nothing at all. A
## careful reader should come away certain that a very long time has passed and
## unable to say how long. Duration is the horror; a timeline is a wiki.
##
## **Nothing here answers what the heat is for.** There is no answer written down
## anywhere, including in the design documents, and that is a commitment rather
## than an omission — the moment one exists somebody will eventually put it in an
## entry, and the game is worse the day they do.
func _seed_documents() -> void:
	# depth is the shallowest shell it can be recovered from, 0 at the rim. The
	# entries that unsettle most sit deepest, so that going one jump too far has
	# something down there that is not a better gun.
	_doc(&"korvan_invoice", "INVOICE 44,120-K", "a billing clerk, Korvan Heavy Works",
		"eleventh survey, month four", &"korvan", 0,
		"Shipped this quarter to Ordnance Receiving, Station Var: forty-one recoil assemblies, twelve mount collars, three crates of shim stock to the drawing revision current at time of order.

Receiving has not acknowledged a delivery since the eighth survey. Payment continues to clear on schedule and in full.

Query raised previously and closed as answered. Closing again. The account is current, the drawings have not changed, and the jigs are set. It is not this office's business to ask who is signing.

Next shipment as scheduled.")

	_doc(&"broker_ledger", "DAY BOOK, THIRD QUARTER", "a yard broker, name torn off",
		"no year given", &"", 0,
		"Hull plate, sixteen sheets — took the lot, paid over. Reactor coil, one, tested — turned it away, it is scrap with a certificate.

The Cygnet berth came round again about banked thermal. Four times the yard rate, and they still will not say where it goes.

I told them what I tell them. I have a ring to keep turning and eleven hundred people on it who want the lights on this winter. They can have the whole sky in twenty years. I will not be here to hand it over.

They wrote that down. They write everything down.")

	_doc(&"probate_filing", "FILING 8812-C, SALVAGE PRIORITY", "a claims officer, The Probate Combine",
		"filing year 8812", &"probate", 1,
		"Priority claim, all wrecks arising, Kestrel Reach and its approaches. Combine to have first survey, first cut and first refusal on any hull, part or cargo recovered.

Filed in anticipation. Standard.

Note appended by the same hand, undated: claim opened four hundred and six days before the loss. Reviewed. No irregularity. The Combine files ahead of the schedule, not ahead of the event.

Claim remains open. Nothing has arisen yet.")

	_doc(&"inspection_note", "INSPECTION NOTE, BERTH 9", "a customs officer, station unnamed",
		"shift log, second watch", &"", 1,
		"Vessel presented for inspection. Manifest declared no thermal cargo and no thermal cargo was found.

Vessel was warm.

Not warm in the reactor. Warm in the hold, in the plate, in the deck under my boots, eleven degrees over the berth and holding while I stood in it. Pilot said the heaters were on. Pilot was wearing a coat.

Released. Nothing to seize and nothing on the schedule that covers being warm.

Third one this month.")

	_doc(&"verity_rider", "RIDER TO A COMMISSION, CLAUSE 4", "counsel, Verity",
		"commission three hundred and eleven", &"verity", 2,
		"The Company shall maintain this hull in perpetuity.

The Company does not define perpetuity, and the Owner acknowledges that no definition is offered, requested or implied.

Where the Owner is deceased, the obligation passes to the Owner's descendants without limit of generation.

Where no descendant survives, the obligation does not lapse. The Company will continue to maintain the hull.

Signed, and countersigned by a hand that has signed every commission since the first.")

	_doc(&"redline_scratch", "SCRATCHED INSIDE AN ACCESS PANEL", "unknown, a hand and a blade",
		"undated", &"redline", 2,
		"IF YOU ARE READING THIS THE PANEL CAME OFF EASY.
THAT IS THE ONLY WARRANTY YOU GET.

DO NOT SELL THEM THE WARM STUFF AT THE POSTED RATE. THEY WILL GO HIGHER. THEY WILL ALWAYS GO HIGHER.

ASK YOURSELF WHY THEY WILL ALWAYS GO HIGHER.

THEN TAKE THE MONEY. I DID.")

	_doc(&"transponder_loop", "TRANSPONDER TRANSCRIPT, PARTIAL", "recovered off a repeating carrier",
		"cycle length forty-one years", &"", 3,
		"...BERTH FOUR HELD FOR THE ASPHODEL, ARRIVING. BERTH SEVEN HELD FOR THE LONG MERIDIAN, ARRIVING. BERTH NINE CLEAR. FUEL AVAILABLE. REPAIR AVAILABLE. HOT MEALS SECOND WATCH.

BERTH FOUR HELD FOR THE ASPHODEL, ARRIVING. BERTH SEVEN HELD FOR THE LONG MERIDIAN, ARRIVING...

Surveyor's note: the loop is intact and has not degraded. There is no station at this position and no wreckage at this position. The carrier is coming from the position.

The Asphodel is not on any register. Neither is the Long Meridian.

Hot meals, second watch.")

	_doc(&"cygnet_receipt", "DELIVERY RECEIPT, THERMAL", "generated, Cygnet berth",
		"receipt 6,004,192", &"cygnet", 3,
		"RECEIVED: banked thermal, one unit, sealed.
WEIGHED: yes.
ASSAYED: yes.
CONDITION: as declared.
PAID: at rate, on presentation.

RECEIVED BY: —

DELIVERED TO: routing follows.

This receipt was generated. No party was present at the berth at the time of delivery. No party is required to be present at the berth at the time of delivery.

Retain for your records. Cygnet does not retain a copy.")

	_doc(&"pilot_log", "PRIVATE LOG, LAST FOUR ENTRIES", "a pilot, hull not named",
		"dive one hundred and nine", &"", 4,
		"106. Down to seven. Cold the whole way. Good haul, nothing to say about it.

107. Same. Sold at the Probate berth, they did not haggle, they never haggle.

108. Went to eight. It is not colder down there. I have said this to four people now and all four told me I had it backwards.

109. It is not colder down there. The instruments say colder. I am telling you what the ship felt like with my hand flat on the inside of the hull at eight and my hand flat on the inside of the hull at two, and the instruments are wrong, or the instruments are measuring something that is not what I was touching.

I am not going back down. I will go back down.")

	_doc(&"rate_schedule", "POSTED RATE, THERMAL — REVISION 209", "a posting clerk, house not stated",
		"revision two hundred and nine", &"", 4,
		"Rate per banked unit, all houses, all berths, effective immediately and until revised.

[figure struck out and rewritten in the same figure]

Revision history appended for audit: revisions one through two hundred and nine.

The rate is unchanged at revision two hundred and nine. The rate is unchanged at every revision.

Auditor's note, filed and closed: a posted rate that does not move across two hundred and nine revisions is not a market rate. Recommend the schedule be discontinued as it conveys no information.

Recommendation declined. The schedule is to be posted.")

	_doc(&"calyx_incident", "INCIDENT FORM 12, COMPLETED", "an attending technician, Calyx Biosystems",
		"culture year 1,904", &"calyx", 5,
		"SPECIMEN: hull, cultured, commissioned, in service eleven years.
EVENT: specimen was fed a quantity of banked thermal substantially in excess of its rating.
FED BY: owner.
OWNER'S STATED REASON: [field left blank]

OBSERVED, HOUR ONE: uptake. No distress.
OBSERVED, HOUR SIX: uptake continuing. No distress. Rating exceeded by a factor of nine.
OBSERVED, HOUR FORTY: uptake continuing.

SPECIMEN DISPOSITION: retained.
OWNER DISPOSITION: [field left blank]

Every contract carries the clause. This is the first time the clause has been operated. The clause does not say what to do afterwards.")

	_doc(&"precursor_survey", "STRUCTURAL SURVEY, HULK 4", "a surveyor, contract work",
		"eleventh survey, month nine", &"", 5,
		"Frame is sound. Frame is older than the yards that would have laid it and older than the alloys we would have laid it in, and it is sound, which is annoying.

Mass is wrong. Not distributed for thrust, not distributed for spin, not distributed for anything I would put a crew inside. Distributed for something.

Nine bays. Seven open onto compartments. Two open onto the frame — sealed on both faces, no hatch, no service run, no reason. Machined to the same tolerance as the rest.

I am paid by the hulk and not by the hour so I will say this once: whoever built this was not bad at it.

Recommend strip and cut. Nothing here is worth preserving except the question.")

	_doc(&"solari_memo", "INTERNAL, THERMAL APPLICATIONS", "a section head, Solari Foundry",
		"foundry year 812", &"solari", 6,
		"To the floor, all shifts.

I am tired of the mood. The sky is going out. It has been going out the entire time any of us have been alive and it will continue going out on a schedule we cannot move, and in the meantime there is more unspent warmth lying loose in this galaxy than the Foundry has processed in its history.

Grief is a failure of nerve and I will not have it on my floor.

Aim it. That is the whole discipline. Heat is only waste if you fail to aim it, and I have never once been shown a problem that was not improved by aiming it at something.

The terminal application is on the schedule like everything else. Work the schedule.")

	_doc(&"crew_roster", "ROSTER, BERTHS 1-14", "a purser, vessel unnamed",
		"no year given", &"", 6,
		"Berth 1 — MAUREL, T. — master
Berth 2 — OKONKWO, A. — engines
Berth 3 — SAAR — engines
Berth 4 — VELA, I. — hold
[...]
Berth 14 — vacant

A second column has been added in a different hand, in pencil, against every name including the vacancy. The column is unlabelled. The entries are temperatures.

They descend down the page in the order the berths are numbered.

The vacancy has a temperature.")

	_doc(&"custodian_note", "STATEMENT, TAKEN AT A STATION", "taken down by a station clerk",
		"undated, marked NOT FOR FILING", &"", 7,
		"He would not give a name and he would not sit down. Taking it as given.

He says he reached the core. He says there is something at it and that it did not attack him.

He says it made room.

He said that four times and I asked him four times what he meant and he could not say it another way. It made room. It moved so that he could be where it had been and it waited while he decided.

He says he did not go in.

He says he does not know why he did not go in and that this is the part he wants written down.

Not for filing. He would not take a drink and he would not take the money.")

	_doc(&"vault_routing", "ROUTING MANIFEST, BANKED THERMAL", "a logistics clerk, house not stated",
		"undated, appended to a formatting query", &"", 8,
		"Raising this as a formatting fault rather than an operational one.

The destination field on every thermal manifest crossing this desk resolves to a code in three segments. Segment one is the house. Segment two is the berth of origin. Segment three is the destination and is supposed to be a location.

It is not a location. It is not in the location tables, it does not parse as a bearing, and it is identical on all seven houses' manifests, which it should not be.

It parses as a temperature.

I have checked it against the background and it sits below it. There is nowhere that is below it.

Requesting the field be corrected or the tables be updated. Low priority.

[query closed: no fault found]")


func _doc(id: StringName, title: String, by: String, dated: String,
		house: StringName, depth: int, body: String) -> void:
	var d := DocumentData.new()
	d.id = id
	d.title = title
	d.by = by
	d.dated = dated
	d.house = house
	d.depth = depth
	d.body = body
	documents[id] = d


## Every entry a system this deep could hold, shallowest first.
##
## `depth` is a FLOOR, not a band: a rim document is still findable at the core,
## because the paperwork of ordinary commerce does not stop existing because you
## flew inward. The reverse is not true, and that asymmetry is the whole gate.
func documents_by_depth(layer: int) -> Array:
	var out: Array = []
	for id in documents:
		var d: DocumentData = documents[id]
		if d.depth <= layer:
			out.append(d)
	out.sort_custom(func(a: DocumentData, b: DocumentData) -> bool:
		return a.depth < b.depth if a.depth != b.depth else String(a.id) < String(b.id))
	return out
