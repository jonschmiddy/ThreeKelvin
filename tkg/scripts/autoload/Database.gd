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
## Dredge, Halcyon and Calyx had no common weapon at all, so their floor was C2.
## That leaked somewhere invisible. Market.melt() reads scrap_value, which is a
## table indexed by RARITY, so a Dredge player could scrap their free gun for
## roughly four times what a Korvan player got before anything had happened —
## with salvage_rack multiplying exactly that. An economic head start nothing on
## screen accounted for, in a game whose difficulty lives in the economy.
##
## Breaker Cannon, Halcyon Mark I and Calyx Barb were written to close it, and
## they also even out a common tier of the drop pool that was six-sevenths
## Korvan.
##
## STILL UNEVEN, deliberately for now: Solari, Redline and Cygnet start on
## Uncommons, which melt for 16 against Korvan's 8. Half the gap that was there
## and a quarter of what Dredge had, but not zero — closing it means three more
## modules, and that is a content decision rather than a bug fix.
const STARTER_WEAPON: Dictionary = {
	&"korvan": &"kh20",
	&"solari": &"plasma",
	&"dredge": &"breaker",
	&"redline": &"needle",
	&"cygnet": &"dronebay",
	&"halcyon": &"markone",
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
	&"korvan", &"solari", &"dredge", &"redline", &"cygnet", &"halcyon", &"calyx",
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
		[&"dredge", "The Dredge Combine", "Everything is salvage. Even you.", "#b3924e", "#6e5a2e",
			"Scrap economy and armor sustain. Wins slowly, wins rich.",
			"Company Rates", "+50% credits from wrecks.",
			"Foundry Line", "Brace cards give +2 armor."],
		[&"redline", "Redline Shipyards", "Still flying? Then we did our job.", "#e24b4a", "#1c2127",
			"Salvage tech, stealth and refits. Innate contraband affinity.",
			"Chop Shop", "Draw 1 extra card each turn.",
			"Ghost Protocol", "First enemy attack each combat is negated."],
		[&"halcyon", "Halcyon Ateliers", "Made once, made properly.", "#8a7340", "#e8e0cc",
			"Few hulls, each one signed. Sparse, exact, and priced accordingly.",
			"Bespoke", "Halcyon cards cost 1 less energy.",
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
	&"dredge": "Nine breaker yards that stopped competing and started invoicing. The Combine does not prospect, explore, or build from raw stock — it follows other people's disasters and files the paperwork first. Their hulls are made of ships that had names.",
	&"redline": "Chop shops with a trademark. Redline registers no serials, honours no warranty, and has never once been found at the address on its invoices. What they sell is speed and the absence of a record, and both are exactly as legal as your inspector is thorough.",
	&"halcyon": "Fewer than four hundred hulls in two centuries, each one commissioned, each one signed. Halcyon does not scale, does not discount, and does not replace what it sold you — it repairs it, at a price, forever. Owning one is less a purchase than an arrangement.",
	&"cygnet": "Drone architects who solved autonomy and then spent forty years not discussing it. A Cygnet ship is a hangar with an engine, somewhere for the swarm to return to. Pilots report the drones anticipate them. The literature does not address this.",
	&"calyx": "Clinical, corporate and entirely organic — Calyx hulls are cultured to a specification and then trimmed. They heal. They adapt. Every contract has a clause about feeding one something it was not rated for, and no customer has seen the results.",
}

func manufacturer_colour(id: StringName) -> Color:
	if id == &"" or not manufacturers.has(id):
		return Color("#5a6a7a")
	return (manufacturers[id] as ManufacturerData).colour

func manufacturer_name(id: StringName) -> String:
	if id == &"" or not manufacturers.has(id):
		return "unbranded"
	return (manufacturers[id] as ManufacturerData).name

## One-word display name for chips and map labels. Taking the first word works
## for six of the seven makers but turns "The Dredge Combine" into "The", so the
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
	var arr: Array[CardData] = []
	for cd in cards:
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
	_module(&"kh20", "KH-20 Chatterbox", &"korvan", W, C0,
		"Autocannon. Cheap, kinetic, relentless.",
		[{name = "Suppressing Fire", energy = 1, heat = 0, damage = 3, hits = 2, salvo = 2, copies = 2}])
	_module(&"km4", "KM-4 Mass Driver", &"korvan", W, C0,
		"Slow ordnance. Bank the shot, land the hammer.",
		[{name = "Charged Slug", energy = 2, heat = 3, damage = 16, charge_turns = 1, copies = 1}])
	_module(&"plate", "Ablative Plate Welder", &"korvan", S, C0,
		"Armor that persists, heat that lingers.",
		[{name = "Brace", energy = 1, armor = 5, copies = 2}])
	_module(&"coolant", "Coolant Flush Assembly", &"korvan", S, C0,
		"Dumps heat into the dark.",
		[{name = "Emergency Vent", energy = 0, vent = 4, draw = 1, copies = 1}])
	_module(&"servo", "Targeting Servo", &"korvan", U, C0,
		"Paints the target for whatever fires next.",
		[{name = "Lock On", energy = 1, lock_on = 4, copies = 1}])
	_module(&"kh88", "KH-88 Jackhammer", &"korvan", W, C2,
		"Rotary cannon. Volume as a philosophy.",
		[{name = "Full Auto", energy = 2, heat = 1, damage = 2, hits = 5, salvo = 1, copies = 2}])
	_module(&"widow", "Widowmaker Siege Driver", &"korvan", W, C3,
		"Two turns of silence, then nothing left.",
		[{name = "Siege Round", energy = 3, heat = 6, damage = 40, charge_turns = 2, copies = 1}])
	_module(&"reactive", "Reactive Plating Array", &"korvan", S, C4,
		"Armor that answers back.",
		[{name = "Bulwark", energy = 2, heat = 1, armor = 8, riposte = 4, copies = 1}])

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
	## damage_equals_heat (Solari IS weaponised heat), credit_gain (Dredge),
	## drones and evoke (Cygnet), negate_next (Redline), adapt and heal (Calyx).
	## A house that borrows another's verb at a higher rarity does not read as
	## stronger, it reads as the other house.

	# Ballistics, the middle rung. Between the Chatterbox's 6/10 and the
	# Jackhammer's 10/15, and cheaper than either to fire twice in a turn.
	_module(&"kh40", "KH-40 Ripsaw", &"korvan", W, C1,
		"Three barrels, one trigger, no subtlety.",
		[{name = "Ripple Fire", energy = 1, heat = 1, damage = 2, hits = 3, salvo = 2, copies = 2}])
	# The top of the KH line, and the payoff for the whole salvo spine: 20 cold,
	# 40 once anything has already fired. Three energy and one copy, so it is a
	# HEAVY's card by construction — a reactor of four plays a Ripsaw into this and
	# a reactor of three does not. That is the Korvan hull signature (slow, tough,
	# patient) written as a weapon, and at five set pieces the enabler is free.
	_module(&"kh500", "KH-500 Drumfire", &"korvan", W, C4,
		"The last argument of a slow ship.",
		[{name = "Drumfire", energy = 3, heat = 5, damage = 4, hits = 5, salvo = 4, copies = 1}])

	# Systems climb ARMOUR, and the verb arrives at the top rather than along the
	# way: C1 marries the two Commons, C2 buys a different defence entirely, C3
	# buys scale, and the Legendary above is where armour starts hitting back.
	_module(&"sinkplate", "Heat Sink Plating", &"korvan", S, C1,
		"Plate that drinks the heat it stops.",
		[{name = "Sink Plate", energy = 1, armor = 4, vent = 2, copies = 2}])
	# BLOCK, which Korvan has never had. Armour persists and costs heat to hold;
	# block decays and costs nothing. So this is the card for the turn a Mass
	# Driver is charging and there is nothing to do but be hit — the one turn in
	# the house's whole design where a decaying shield is exactly right.
	_module(&"braceframe", "Brace Frame", &"korvan", S, C2,
		"For the turn you have nothing to shoot with.",
		[{name = "Dig In", energy = 1, block = 8, armor = 2, copies = 2}])
	_module(&"bulkhead", "Bulkhead Array", &"korvan", S, C3,
		"Korvan's answer to most questions.",
		[{name = "Bulkhead", energy = 1, heat = 1, armor = 7, copies = 2}])

	# Four rungs of lock-on, which is the column Korvan had one card in.
	# Deliberately CHEAP rather than large: Solari's Flare Rack is lock-on 6 for a
	# Common-adjacent price and pays 2 heat for it, and Korvan undercutting that on
	# heat instead of beating it on size is the difference between the two houses.
	_module(&"optics", "Ranging Optics", &"korvan", U, C1,
		"Cheap glass. Correct answers.",
		[{name = "Range Finding", energy = 0, lock_on = 3, copies = 2}])
	_module(&"coldsights", "Cold Sights", &"korvan", U, C2,
		"Cools the barrel and the arithmetic.",
		[{name = "Cold Sights", energy = 1, vent = 3, lock_on = 4, copies = 2}])
	# The other half of the charged-weapon problem: a free card for the turn you
	# cannot attack, which vents the ordnance heat you are still carrying from the
	# last one. Pairs with Brace Frame by design — one blocks, one cools.
	_module(&"standfast", "Standfast Rig", &"korvan", U, C3,
		"Sit still. Take it. Wait for the tone.",
		[{name = "Hold Fast", energy = 0, armor = 6, vent = 4, copies = 2}])
	# The capstone, and it is an ENGINE rather than a hammer — the hammer is the
	# Drumfire. Free to play, returns the energy, marks the target: the card that
	# turns a hand of Korvan guns into one enormous turn. Three heat a play is the
	# brake, and the only reason it is not degenerate.
	_module(&"director", "KX-9 Fire Director", &"korvan", U, C4,
		"It decides. You pull.",
		[{name = "Fire Director", energy = 0, heat = 3, lock_on = 5, energy_gain = 1, copies = 2}])

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

	# --- Dredge: scrap and sustain
	_module(&"claw", "Salvage Claw", &"dredge", U, C0,
		"Strips value off things still moving.",
		[{name = "Strip Mine", energy = 1, damage = 5, credit_gain = 3, copies = 2}])
	_module(&"slag", "Slag Armor Kit", &"dredge", S, C1,
		"Ugly, heavy, pays for itself.",
		[{name = "Slag Plate", energy = 1, armor = 4, credit_gain = 2, copies = 2}])
	_module(&"refinery", "Field Refinery", &"dredge", U, C2,
		"Feeds salvage into the armor press.",
		[{name = "Smelt", energy = 1, credit_cost = 5, armor = 10, copies = 1}])
	_module(&"ripper", "Dredge Tear-Down Rig", &"dredge", W, C2,
		"Disassembles hulls that object.",
		[{name = "Tear Down", energy = 2, heat = 1, damage = 7, hits = 2, credit_gain = 4, copies = 2}])
	## Issued weapon. See STARTER_WEAPON for why these three exist.
	_module(&"breaker", "Breaker Cannon", &"dredge", W, C0,
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
		[{name = "Launch Drone", energy = 1, drone_damage = 3, copies = 2}])
	_module(&"wasp", "Shield Wasp Cradle", &"cygnet", S, C1,
		"A drone that flies between you and it.",
		[{name = "Wasp Screen", energy = 1, drone_armor = 3, copies = 2}])
	_module(&"evoke", "Evoke Node", &"cygnet", U, C2,
		"Spends the swarm all at once.",
		[{name = "Evoke", energy = 1, evoke = 7, copies = 1}])

	# --- Halcyon: precision
	## Issued weapon. Hits harder per card than the other two starters on
	## purpose: Halcyon grants one fewer card than anybody, so this is the only
	## copy of it in the deck and a merely-average Common would have left the
	## house opening a fight with a single mediocre attack.
	_module(&"markone", "Halcyon Mark I", &"halcyon", W, C0,
		"Numbered, signed, and the cheapest thing they will sell you.",
		[{name = "Sidearm", energy = 1, damage = 7, copies = 2}])
	_module(&"rail", "Aurelian Rail", &"halcyon", W, C2,
		"Nothing wasted. Nothing missed.",
		[{name = "Precise Shot", energy = 1, heat = 1, damage = 9, draw = 1, copies = 2}])
	_module(&"auspex", "Auspex Array", &"halcyon", U, C1,
		"You always have the card you need.",
		[{name = "Foresight", energy = 0, draw = 2, copies = 2}])
	_module(&"halcyon", "Halcyon Deflector", &"halcyon", S, C3,
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
	# tempo, Solari in heat, Dredge in credits, Redline in nothing much and not
	# much back, Halcyon in energy, Cygnet in time.
	#
	# THEY ARE ALL LIFELINES, AND THAT IS THE SECOND REWRITE OF THIS BLOCK.
	#
	# The first pass priced them as economy cards — flat heals, two and three
	# energy — and priced them for a HEALTHY turn, which is the one turn that does
	# not need them. At three hull and one energy left, a card that costs two is
	# not a card. Every one of these now costs at most one energy (Halcyon's costs
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
		[{name = "Field Weld", energy = 1, heal = 2, heal_scale = 4, copies = 1}])
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
	_module(&"reclaim", "Hull Reclamation Rig", &"dredge", S, C1,
		"Feeds the frame on whatever the frame used to be.",
		[{name = "Reclaim", energy = 1, heal = 2, heal_scale = 3, credit_cost = 8, copies = 1}])
	## Cheap, fast, and not very good — which is Redline. Free to play and it
	## replaces itself, so it costs a card slot rather than a turn, and Chop Shop
	## (3-set, draw 1 extra) is a house that can afford to run thin cards.
	_module(&"bodge", "Bodge Kit", &"redline", U, C0,
		"Foam, tape, and no paperwork. Still flying? Then we did our job.",
		[{name = "Bodge", energy = 0, heal = 1, heal_scale = 5, draw = 1, copies = 2}])
	## The warranty, as a card. Twenty hull in one go for three energy — two
	## under Bespoke (3-set, Halcyon cards cost 1 less), which is the difference
	## between unplayable and a turn you plan a fight around. See `docs/lore.md`
	## §3: the word in the rider is perpetuity, and the Company does not define it.
	_module(&"perpetuity", "Perpetuity Clause", &"halcyon", S, C3,
		"The Company will maintain this hull. The Company does not say for how long.",
		[{name = "Perpetuity", energy = 2, heal = 4, heal_scale = 3, copies = 1}])
	## Two small welds rather than one big one, which is how a swarm does
	## anything. Worse per card than Knit and worse per energy, and it arrives
	## twice — Cygnet repairs the way Cygnet fights.
	_module(&"menders", "Mender Swarm", &"cygnet", S, C2,
		"They find the hole before you do. Nobody has asked how.",
		[{name = "Mend", energy = 1, heal = 1, heal_scale = 5, copies = 2}])

	# --- Unbranded: exotic (grown) and artifact (precursor)
	_module(&"organ", "Voidwhale Ganglion", &"", U, C5,
		"Still faintly warm. Three Kelvin says otherwise.",
		[{name = "Whale Song", energy = 1, heal = 8, vent = 3, copies = 1}])
	_module(&"lattice", "Precursor Lattice", &"", S, C6,
		"Nobody built this. It simply persists.",
		[{name = "Lattice", energy = 0, armor = 6, draw = 1, copies = 2}])
	_module(&"singing", "Singing Core", &"", W, C6,
		"It hums. Things nearby come apart.",
		[{name = "Resonance", energy = 2, heat = 2, damage = 11, hits = 2, copies = 1}])

	# --- Junk
	_module(&"dross", "Dross", &"", U, C0,
		"Spore residue fused into your systems.",
		[{name = "Dross", energy = 1, unplayable = true, copies = 1}])

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
		[{name = "Cutting Beam", energy = 1, heat = 1, damage = 6, copies = 2}])
	_module(&"slug", "Slug Thrower", &"", W, C0,
		"Chemical propellant and a tube. Older than spaceflight.",
		[{name = "Slug", energy = 1, damage = 4, hits = 2, copies = 2}])
	_module(&"torch", "Cutting Torch", &"", W, C0,
		"Meant for hulls that are already dead.",
		[{name = "Torch", energy = 0, heat = 3, damage = 5, copies = 2}])

	_module(&"plating", "Hull Plating", &"", S, C0,
		"Steel, bolted on. It does not have to be clever.",
		[{name = "Reinforce", energy = 1, armor = 5, copies = 2}])
	_module(&"board", "Signal Board", &"", S, C0,
		"Sorts what the sensors are shouting about into an order.",
		[{name = "Reroute", energy = 0, draw = 1, copies = 2}])
	_module(&"bracing", "Impact Bracing", &"", S, C0,
		"Struts that take one hit and are then scrap.",
		[{name = "Hold Fast", energy = 1, block = 7, copies = 2}])

	_module(&"coolline", "Coolant Line", &"", U, C0,
		"A hose and a pump. Standard on everything that burns.",
		[{name = "Bleed Heat", energy = 0, vent = 3, copies = 1}])
	_module(&"scope", "Ranging Scope", &"", U, C0,
		"Tells the guns where the thing is. That is all it does.",
		[{name = "Range", energy = 0, lock_on = 3, copies = 1}])
	## YARD STOCK, AND THE FIRST LIFELINE ANYBODY HOLDS. Scaled like the branded
	## repairs below it rather than left flat, because the turn this card exists
	## for is the same turn theirs do — and a run whose only repair is a flat 4 is
	## a run that learns repair does not save you before it ever finds one that
	## does.
	_module(&"patchkit", "Patch Kit", &"", U, C0,
		"Foam, tape, and a prayer to whoever welded the frame.",
		[{name = "Patch", energy = 1, heal = 1, heal_scale = 5, copies = 1}])

	for id in GENERIC_STOCK:
		(modules[id] as ModuleData).starter_only = true

	_seed_module_attributes()
	_seed_module_passives()

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
func _seed_module_attributes() -> void:
	# `board` and `scope` are yard stock and were carrying their names as pure
	# flavour: a Signal Board that reads no signals and a Ranging Scope that
	# ranges nothing. They are the floor of the sensor axis now, which is also
	# what makes an Auspex Array at 2 legible as an upgrade from something.
	#
	# Korvan's four new utility rungs carry the sensor axis up with them, which is
	# the same "latent in the name" test: optics range, sights see, a fire director
	# is the thing that decides. It also matters more than it looks while
	# ACTIVE_MAKERS is narrowed — with only Korvan dropping, these are the ONLY
	# modules a run can find that raise Sensors at all, and Sensors is what the
	# skill checks read.
	var sensors := {&"auspex": 2, &"servo": 1, &"evoke": 1, &"board": 1, &"scope": 1,
		&"optics": 1, &"coldsights": 2, &"director": 3}
	var stealth := {&"ghost": 2, &"chaff": 1, &"sporevent": 1, &"flare": -1}
	for id in sensors:
		(modules[id] as ModuleData).sensors = sensors[id]
	for id in stealth:
		(modules[id] as ModuleData).stealth = stealth[id]


## The four gauges a module can move, laid on modules that already exist.
##
## Same discipline as _seed_module_attributes above, and the same reason: every
## one of these already reads as the thing it now does. An Ablative Plate Welder
## welds plate. A Coolant Flush Assembly flushes coolant. The stat was latent in
## the name and the catalog was carrying it as flavour.
##
## Until now a module's ONLY passive effects were sensors and stealth, so armour
## modules armoured nothing — they granted a block card and left max_hp exactly
## where the bare chassis had it. These numbers are small on purpose: a medium
## frame is 35 hull, 12 heat cap and 3 dissipation, so +3 plate is a tenth of a
## hull rather than a second one, and the cards a module grants are still the
## bulk of what it is worth.
##
## NOTHING carries fuel_factor. It is the one signed field that cuts both ways —
## it raises Thrust and the price of every jump together — and the simulator
## already ends 30-40% of runs stranded. A number invented for it here would move
## the most fragile figure in the game for the sake of an attribute nobody has
## asked to change. The gauge sums it; the catalog waits for an engine.
func _seed_module_passives() -> void:
	# Plate, bracing, armour. Rarity buys magnitude, per the ladder.
	var hull_plus := {
		&"plating": 3, &"bracing": 2,          # generic yard stock
		&"plate": 2, &"reactive": 6,           # korvan
		&"sinkplate": 3, &"braceframe": 2, &"bulkhead": 5,
		&"slag": 4,                            # dredge
		&"weave": 3,                           # calyx
		&"lattice": 8,                         # precursor artifact
	}
	# Capacity: how much heat you can hold. Solari's whole axis.
	var heat_plus := {&"shroud": 5, &"overdrive": 3, &"ventcan": 2}
	# Shedding: how fast you get rid of it. Deliberately scarcer than capacity —
	# FOUR bearers at +1 — because dissipation compounds every single turn and a
	# medium frame only starts with 3.
	#
	# Cold Sights is the fourth and it went in with its eyes open. Of the other
	# three, one is generic yard stock that never drops and one is Calyx, so a
	# Korvan-only loot pool could previously find exactly ONE module in the game
	# that sheds heat faster. A house whose entire identity is running cold could
	# not buy the stat. Reopen ACTIVE_MAKERS and this is the rung to re-measure.
	var vent_plus := {&"coolant": 1, &"coolline": 1, &"sporevent": 1, &"coldsights": 1}
	# Evasion, and only from Redline, whose set is named for it.
	var dodge_plus := {&"ghost": 0.04, &"chaff": 0.02}
	# Acting sooner. The same three modules that already grant Sensors, because
	# seeing first and moving first are the same sentence.
	var init_plus := {&"servo": 1, &"evoke": 1, &"singing": 1, &"director": 1}

	for id in hull_plus:
		(modules[id] as ModuleData).max_hull = hull_plus[id]
	for id in heat_plus:
		(modules[id] as ModuleData).heat_cap = heat_plus[id]
	for id in vent_plus:
		(modules[id] as ModuleData).dissipation = vent_plus[id]
	for id in dodge_plus:
		(modules[id] as ModuleData).dodge = dodge_plus[id]
	for id in init_plus:
		(modules[id] as ModuleData).initiative = init_plus[id]


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
		reactor = 3, hand_size = 6, max_hull = 24, heat_cap = 8, dissipation = 2,
		dodge = 0.18, initiative = 2, fuel_factor = 0.8, cargo_slots = 8,
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
		reactor = 3, hand_size = 5, max_hull = 35, heat_cap = 12, dissipation = 1,
		dodge = 0.05, initiative = 0, fuel_factor = 1.2, cargo_slots = 12,
		weapon_slots = 3, system_slots = 2, utility_slots = 2},
	HullData.Weight.HEAVY: {
		reactor = 4, hand_size = 4, max_hull = 52, heat_cap = 18, dissipation = 1,
		dodge = 0.0, initiative = -2, fuel_factor = 1.8, cargo_slots = 16,
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
const TIER_DELTA := [
	{scale = 1.00, weapon = 0, system = 0, reactor = 0, dissipation = 0},
	{scale = 1.15, weapon = 0, system = 0, reactor = 0, dissipation = 0},
	{scale = 1.32, weapon = 1, system = 0, reactor = 0, dissipation = 1},
	{scale = 1.52, weapon = 1, system = 1, reactor = 1, dissipation = 1},
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
	&"dredge": {
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
	&"halcyon": {
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
	# Floors, because a delta table cannot see what it collides with: Halcyon's
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
	var stem := ""
	match w:
		HullData.Weight.LIGHT: stem = "light"
		HullData.Weight.MEDIUM: stem = "medium"
		HullData.Weight.HEAVY: stem = "heavy"
		_: return null
	# TIER_NAMES is an untyped Array, so an element comes back as Variant and
	# `:=` has nothing to infer from. Declared rather than inferred.
	var letter: String = HullData.TIER_NAMES[clampi(cls, 0, 3)]
	return load("res://art/sprites/hull_%s_%s.png"
		% [stem, letter.to_lower()]) as Texture2D

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
## free identity: a Dredge heavy called a Barge and a Halcyon heavy called a
## Barque tell you who built them before you have read the maker name, and the
## hull names were already doing this work while the line underneath them said a
## flat "HEAVY CHASSIS".
##
## Korvan and Solari are the two warship lines because they are the two houses
## that mirror each other mechanically. Dredge gets working boats: nobody names a
## barge to impress you. Redline gets fast rigs and a smuggling term. Cygnet gets
## the three real vessel types that exist to carry OTHER vessels, which is the
## house motto stated as a hull class. Halcyon gets sailing rigs, where the rig
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
	&"dredge":  ["Trawler", "Dredger", "Barge"],
	&"redline": ["Sloop", "Runner", "Clipper"],
	&"cygnet":  ["Pinnace", "Tender", "Carrier"],
	&"halcyon": ["Yawl", "Schooner", "Barque"],
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
	h.reactor += int(d.reactor)
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
		fauna: bool = false, boss: bool = false, miniboss: bool = false) -> void:
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
		{name = "Spore Breath", text = "Deal 3, +1 Dross", damage = 3, dross = 1, weight = 30},
	], true)
	_enemy(&"leviathan", "Void Leviathan", "megafauna · adult", 88, 4, 0, &"whale", [], [
		{name = "Sounding", text = "Heals 8", heal = 8, weight = 20},
		{name = "Breach", text = "Deal 15", damage = 15, weight = 45},
		{name = "Spore Storm", text = "Deal 5, +2 Dross", damage = 5, dross = 2, weight = 35},
	], true)
	# THE HELLBENDER: the galaxy's other harvester crew, and the only enemy with a
	# position instead of an address. Hand-tuned like the custodian — it is a
	# set piece wherever you catch it, so danger scaling would make WHERE you
	# fight it matter more than WHETHER you are ready to. Numbers sit between
	# the sentinel and the custodian: a party kills it comfortably, one ship
	# kills it with a good build and a reason. Below 35% hull it spools an
	# escape burn and leaves — see Combat.escape_intent() — so the loop below
	# is what it does while it still thinks it is winning.
	#
	# The name is a real salamander, and the crew is in on the joke: the hull
	# flies the heraldic salamander — the beast drawn sitting unharmed in
	# flames — which is what a ship built to drink heat would paint on itself.
	# The device lives in the tag and, someday, in an archive document that
	# describes the emblem without explaining it. Nobody explains anything in
	# this galaxy; see docs/lore.md.
	_enemy(&"hellbender", "The Hellbender", "rival harvester · a salamander device on the hull", 90, 6, 90, &"hulk", [
		{name = "Heat Lance", text = "Deal 11", damage = 11},
		{name = "Slag Guns", text = "Deal 4 × 3", damage = 4, hits = 3},
		{name = "Ashplate", text = "Gain 10 block", block = 10},
		{name = "Furnace Bleed", text = "Deal 7, +1 Dross", damage = 7, dross = 1},
	], [], false, false, true)
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
## **The epochs do not reconcile.** Korvan counts surveys, Dredge counts filings,
## Halcyon counts commissions and the transponders count nothing at all. A
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

	_doc(&"dredge_filing", "FILING 8812-C, SALVAGE PRIORITY", "a claims officer, The Dredge Combine",
		"filing year 8812", &"dredge", 1,
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

	_doc(&"halcyon_rider", "RIDER TO A COMMISSION, CLAUSE 4", "counsel, Halcyon",
		"commission three hundred and eleven", &"halcyon", 2,
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

107. Same. Sold at the Dredge berth, they did not haggle, they never haggle.

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

While he talked he kept putting his hand flat on the counter, palm down, and leaving it, and taking it away, and putting it back. He said he had been down one hundred and seventeen times, and when I asked was he sure, he said it again, one hundred and seventeen, like I had asked him his name.

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



	# --- The second shelf: threads, arcs, constants and The Non-Return. -------
	#
	# Written to `docs/lore-threads.md`, which extends `docs/lore.md` §5 with
	# three additions worth restating at the point of use:
	#
	# **Hard keys.** Two entries in one storyline share an exact, checkable
	# token — a name, a count, a number — so membership is provable while
	# meaning stays open. Do not "fix" an odd number or phrase here without
	# checking §3/§4 of that document; it is probably load-bearing.
	#
	# **Constants.** ELEVEN, FORTY-ONE, the LONG MERIDIAN, Kestrel Reach,
	# Station Var, the schedule, and the QUERY CLOSED stamp family recur across
	# storylines on purpose, per the rationed roster in §2. The walker (the
	# LONG MERIDIAN) is never the subject of any entry, ever.
	#
	# **Voices.** Every entry below was authored through a different language
	# and blind back-translated (§7), which is why no two clerks share a prose
	# style. The wording is the voice; edit meaning, not music.

	_doc(&"asphodel_stores", "VICTUALLING ORDER, OUTBOUND", "a victualler, station not named",
		"no year given", &"", 1,
		"Laid in against the ASPHODEL, outbound: dry stores to fourteen berths, the good flour not the grey, water topped to tankage, galley fuel to what the master set down. Master Maurel pays on collection and always has, which is more than I can say for half this dock.

Kitchen to note: hot meals, second watch, the whole way out, his standing order. No return leg on this one so cost it single. He asked after candles too, wax ones, a full case. A case of candles is a case of candles and it is paid for.

The grey flour goes back to Herron. Third time now.")

	_doc(&"asphodel_claim", "FILING 214-C, THE ASPHODEL", "a claims officer, The Dredge Combine",
		"filing year 9,904", &"dredge", 3,
		"Reviewed annual per standing order, claim 214-C, the ASPHODEL, hull and cargo arising. Open. Nothing arisen.

Same note as last year and I will keep making it while I hold this desk: oldest claim on the register, carried in from the register before this one, unsigned, which they allowed then. If the Combine wants my opinion, the officer who filed it is longer dead than some of what we salvage. Recommend closure.

Declined above my signature, same hand as last year, same words: we do not close before the loss.

Down the reach they say the berth is still lit for her. Dock talk. Reviewed, open, next year.")

	_doc(&"halcyon_attendance", "ATTENDANCE, COMMISSION 311", "a service supervisor, Halcyon",
		"commission three hundred and eleven, ninety-first attendance", &"halcyon", 5,
		"Attendance ninety-one, commission 311. Out and back eleven days, crew of two, allowance claimed for both.

Work: forward hatch reseated, one plate faired where something had leaned on it, name repainted. Eight letters, and the paint we carry is matched to her first coat, the tin says so in a hand nobody at the yard writes anymore.

She sat where the schedule had her. She always sits where the schedule has her. Piet asked how does the schedule know, and I said the schedule is old, which is not an answer, but Piet is new.

Owner absent, as since the fourth attendance. Obligation unaffected. Next attendance is in the schedule.")

	_doc(&"halcyon_exemplar", "EXAMINATION, NOTARY'S SEAL", "an examiner, Halcyon",
		"exemplar volume forty", &"halcyon", 5,
		"Six candidates today, passed four. Room too cold again, told Wren about the stove, Wren says talk to the yard, the yard says talk to Wren.

Countersign exercise from the current exemplar, third sheet passes for all four, usual. One asked the usual question too, why the exemplar volumes are not sorted by author when the countersign in volume forty and the countersign in volume one are the same hand. Gave the syllabus answer, they are sorted by author. He looked at me the way they all look at me and I gave him his seal.

Tomorrow, eight more. Wren says the stove is my problem. The stove is nobody's problem, that is the trouble with this house, everything is in perpetuity except the heat.")

	_doc(&"denial_notice", "NOTICE OF DENIAL", "a claims adjuster, underwriters not named",
		"policy year forty-four", &"", 4,
		"Denial under policy 7,7112, hull and fittings, total loss.

Grounds, clause two: cover extends to fitted equipment purchased or salvaged, receipts or salvage docket to show. The module the claimant names has no catalogue entry, no maker's mark, no serial, no stamp, no docket, and the claimant, who fitted it with his own hands, when asked where he got it, wrote on the form: it was aboard when I needed it.

My colleague B. denied one like it in the spring and I have used her wording where it serves, the schedule covers what is bought and what is salvaged and not what arrives, the underwriters liked that.

Appeal lies within the term. He signed the form like a man paying a toll and thanked me on the way out, for what I could not tell you. Copy to file.")

	_doc(&"rendering_account", "RENDERING ACCOUNT, ONE CARCASS", "a rendering foreman",
		"season's books", &"", 2,
		"One adult, taken at the mouth of Kestrel Reach. The Dredge man was at the gate before we had her half in, waved his claim, settled at the standard cut.

Oil, eleven barrels. Plate-bone graded and sold. Organs forward at posted. A spotter's tag out of the left flank, logged, sent back up to the post like they ask.

Cooling is the loss on this account and I want it minuted for the next one: eleven days at intake heat. The men will not work the first week of that, and small blame to them, you put your hand to the flank and it is like a wall with a fire on the far side, and then between one watch and the next, cold through, all of it at once, and we lost half a shift standing around feeling it.

Settled less cooling. Quote higher next season.")

	_doc(&"no_claim", "STATEMENT OF NO CLAIM", "a surveyor for underwriters",
		"policy year fifty-one", &"", 5,
		"Attended the LONG MERIDIAN at the pilot's request, a first for me in thirty years of forms: a vessel asking a surveyor to certify that nothing happened.

His account: fauna, adult, came up on the warm side in deep transit and held there six hours, matched to his speed. He did not fire. No damage, no discharge, nothing for the underwriters, I said as much, he said write it anyway and paid the attendance, so it is written.

Heading at its leaving was inward, passed to the spotters' post as required. There is no register entry for the vessel, the office can chase that if the office cares, my fee stops at the hull.

He kept the cabin hot as a laundry the whole interview. Copy to him. None retained.")

	_doc(&"sightings_tally", "TALLY, SEASON'S SIGHTINGS", "a spotter, post not named",
		"no year given", &"", 6,
		"Season closed. Forty-one sighted, the big ones early, then the yearlings, headings taken on every one.

Inward, all of them, same as last season, and the one before that is the last mixed page in this book. I still take the bearings because taking the bearings is the post, but I have given up drawing them, the chart is one arrow and decoration is somebody else's trade.

Tags returned this season, one, off a rendering yard down the reach with a polite note. One in forty-one. The rest are somewhere warm, or somewhere warmer anyway.

Requisition renewed for lamp oil and a second stove, third year of asking. Book closed, new book opened.")

	_doc(&"chart_errata", "CHART ERRATA, ELEVENTH SURVEY", "a cartographer's assistant",
		"eleventh survey, month two", &"", 3,
		"Errata to the tenth, compiled for the eleventh, month two. My eyes are ruined and Master Quill owes me for two candles.

Newly lit, none, which saves ink. Newly dark, ninety-two, all confirmed twice per the rule. Struck from the station index, forty. Eleven of the forty still answer when hailed, Var being one, and the practice on those is the practice since the ninth survey: strike them, the chart is what is there, an answer is not a station. I copy that ruling out every survey, and every survey some new hand queries it and is told.

Bundle to binding on the fourth. No word on when the twelfth is commissioned, or whether. Quill says in his day there was a survey every twenty years, like a heartbeat. Quill says a lot of things.")

	_doc(&"audit_minute", "AUDIT MINUTE, THERMAL ACCOUNTS", "an auditor, engagement not stated",
		"audit year not entered", &"", 7,
		"Thermal deliveries sampled across seven berths, one to a house, receipt numbers running seven figures. Weighed, receipted, paid at posted, every one, and I will say for the berths that their paper is cleaner than most of what this profession walks through.

The seller keeps the receipt. The house keeps nothing. I confirmed that at head office level for all seven, in writing, and the confirmations came back by return post as if I had asked the colour of the sky.

I was twenty years at grain accounts. A granary that pays on the scale and keeps no tally of what came over it, I would have had shut by winter. I put the question to the engagement partner in those words, and the minute records that the question was put.

No irregularities found within the scope set for me, and the scope was set for me. Engagement closed. Fee rendered.")

	_doc(&"solari_schedule", "SCHEDULE EXTRACT, THERMAL", "a scheduling clerk, Solari Foundry",
		"foundry year 890", &"solari", 8,
		"Queue as held, foundry year 890, extract for the floor meeting.

Smelt charge, four allocations, two urgent. Habitat mains, two, the north ring again, their pipes are older than my grandmother. Foundry restart, one, priority, dated.

TERMINAL APPLICATION, last line, no date, no site, no allocation, carried at the last line since before my ledger and before the ledger I inherited. I asked what feeds its date field, being new, and Ansel said the field is not fed, it is awaited, and went back to his soup. I have written it here the way he said it because I was told extracts are verbatim.

Copies to the floor. The north ring numbers are the ones they will shout about.")

	_doc(&"redline_jacket", "FOUND FOLDED IN A FLIGHT JACKET", "unknown",
		"undated", &"redline", 6,
		"Sold R. the whole bank at the meet, off station, over posted, no receipt, same as ever. Weighed on his scale, which reads fair, I check it against mine, he knows I check and likes me for it I think.

Asked him straight this time, what do you do with it. He laughed. He said same as you, hold it while I can, sell it while I still can. Sell to WHO, I said, and he counted out the extra and told me to buy my girl something warm, and we talked about the Perse fight like every time, and that was that.

Next meet is fixed for after the dark quarter. Bring the small cells too, he says, he will take those now as well.")

	_doc(&"expense_claim", "EXPENSE CLAIM, DISALLOWED", "a finance clerk, house not stated",
		"claim period as stamped", &"", 7,
		"Hazard claim, four crew, deep transit to the core approach and return, standard rate sought for the days out.

Denied on the schedule of hazards, first pass. Their account gives no shot fired, no pursuit, no damage, no loss, and the words they put in the box were four days of being watched, and I have no line for that. Told them to resubmit. They resubmitted with the box empty, which is four days of nothing, and I have no line for that either.

Passed it up rather than deny twice, which is allowed at my discretion, and my discretion was the four of them in the corridor, big men, quiet, holding their caps like boys outside an office. Paid under goodwill.

Ledger note: none of the four has taken deep work since. The postings sit a week now.")

	_doc(&"seven_clauses", "NON-RETURN, ALL HOUSES", "a contracts clerk, compiled for training",
		"undated, marked CURRENT", &"", 0,
		"For the training intake, who asked what happens when a contractor does not come back, and wanted more than the short answer. Compiled from the standard terms as filed, one line in each house's own words. Check them against the registry, that is what it is for.

Korvan, clause nine: the line of credit closes and accounts settle against the hull.
Solari: unspent advances revert to the schedule.
Dredge: the Combine's claim to the wreckage precedes the wreckage.
Redline: no clause on file.
Halcyon: the company's obligation to the hull survives the owner.
Cygnet: recovery, where undertaken, is recovery of equipment.
Calyx: the specimen is retained.

The short answer was nothing, and the long answer above says the same at greater length, in better ink.

File under training. The intake is eleven this year, big for the season.")

	_doc(&"replacement_posting", "WORK POSTED, BOARD COPY", "a posting clerk",
		"board cycle as stamped", &"", 0,
		"FETCH, standard terms, rate scaled to the run, sign at the berth office. Bring your own lashings, the office is out of lashings.

Posted forty-one times, filled forty-one times. The new clerk asked could we print a fresh notice instead of correcting the date, and was told the board is full and the notice serves. He then asked how many of the forty-one came back, and was sent to count the lashings.

Date corrected. Board note: somebody keeps taking the chalk from the gate for the wall, which is allowed, but bring it back.")

	_doc(&"effects_manifest", "PERSONAL EFFECTS, DISPOSITION", "a berth office clerk",
		"file year not entered", &"", 1,
		"Box, standard, sealed at the berth office. Contents as found: coat, worn at the cuffs. Photograph, three people on a dock somewhere green, no names on the back, nobody here knows them. Instruments, personal, one set, good ones, older than the man by the look of the case. Sundries to weight.

Held the year as prescribed. No claimant come. The freight on the box went to his account, the account is in the negative, the negative is written off, and I signed the write-off by hand because the stamp was drying, and I am glad it was, one paper in the file ought to have a person on it.

Box to disposal on the fifth. I kept the photograph out. Procedure can want it back, file a complaint.")

	_doc(&"chalk_wall", "NOTICE AT THE DOCK GATE", "the dockmaster's office",
		"undated, weathered", &"", 1,
		"The chalk wall is not to be cleaned. This replaces the notice ordering it cleaned. The officer who posted that one has been spoken to, and has himself written a name on the wall since, so the matter is considered understood.

Chalk is at the gatehouse, and the gatehouse keeps no book on who takes it, and the dockmaster has said that if the chalk budget is queried again, the querier can come stand at the gate through the dark quarter and read the wall, and then raise it with her personally.

Names go at the base where there is room. There is room.

Gate hours unchanged. Mind the hoist chains, they have been greased.")

	_doc(&"actuarial_note", "AMORTIZATION SCHEDULE, EXTRACT", "an actuarial clerk, house not stated",
		"revision eleven", &"", 2,
		"Extract, revision eleven current, requested by the western office and sent with the usual reminder that extracts are not the schedule.

A contracted hull amortizes by deliveries, not years. The assumption under that is loss, not wear, and it has held inside tolerance since the first drawing of the schedule, which is longer than the western office has existed, they may put that in their pipe.

Their actual question, whether there is a contractor column to match the hull column: there was. Struck at revision eleven. The figure sat still across grades, regions and houses, too still to be worth the printing, one figure serves, it is folded into the hull line. Any first-year could confirm it from the loss books, and the western office is welcome to a first-year.

Postage to their account.")

	_doc(&"repair_declined", "REPAIR ESTIMATE, DECLINED", "a yard estimator",
		"no year given", &"", 0,
		"Forward plate, fair and patch, scoring aft of the collar dressed, repaint to the line. Priced kind, slow season, told him so.

He went along the hull while I talked, hand over the dents the way you would check a horse, and said seal the edges and leave the rest. I said the plate is sound but ugly, and he said ugly how, and every answer I had was worth less than the paint.

Wrote the waiver, he signed it, said the dents are how the ship knows it went somewhere. Took the sealing work, half a day, paid cash, and stood us the tea after, and told a long story about a customs man and a coat that deserves better telling than mine.

Quote for the paint stands till spring.")

	_doc(&"pilot_log_2", "PRIVATE LOG, CONTINUED", "a pilot, hull not named",
		"dives one hundred thirteen to one hundred sixteen", &"", 6,
		"113. Eight again. Palm flat on the hull the whole transit like an idiot, arm dead to the shoulder after. Right, though. Warmer. [several lines lost]

114. Sold the spare coil to Herron, the second suit, the plate I kept for a bad day. Bad day came and a plate was no help. Ship rides light. Sleep bad.

115. [lost]

116. Gauges say colder. Wrote WARM on a slip and stuck it over the readout so we are both saying our piece. Nine tomorrow. Fuel for nine and about half of eight, which is a number I have decided to look at exactly once. If Herron reads this, the coil was tested, the rest of it I am sorry about.")

	_doc(&"hull_sale", "BILL OF SALE, ONE HULL, AS LYING", "a yard broker, rim yard",
		"no year given", &"", 2,
		"One hull sold as lying, deep-rated, high hours, better kept than the price, and I said so, the price was his idea.

Allowance against the thermal suite, reads cold at every range. He would not hear that it was broken, so we wrote the allowance as recalibration and he signed with his mouth shut. Bench tested it after: within tolerance. Buyer keeps the allowance anyway, my error, my ledger.

He left the log in the chart drawer on purpose, entries one to one hundred and seventeen, said the ship should keep her own account. Buyer to be told it is there.

No forwarding address, said mail could not reach where he was going, and then got on the ring shuttle with everybody's groceries, which I suppose is a kind of address. Sale closed, fees taken.")

	_doc(&"ring_minutes", "MINUTES, RING COUNCIL", "a recording secretary",
		"winter session, year not entered", &"", 1,
		"Winter session, quorum met, twenty-one seated, the hall cold enough that nobody took their coat off, which I minute because the allocation item will read strange without it.

Allocation carried as amended, mains full through the dark quarter, schools and infirmary first, dock lights to navigation minimum. Eleven hundred on the roll this winter, four more than last, two births and some arrivals.

From the floor, the standing Cygnet offer on the ring's banked heat, renewed, improved again. Moved to accept. The chair spoke against, standing, and ordered his remarks off the minute, and struck the table once, and I have been taking these minutes eleven years and had never heard him strike anything.

Not carried, eleven to ten.

Also carried: the school stove. Session closed.")

	_doc(&"successor_ledger", "DAY BOOK, NEW HAND", "a yard broker, name not yet worn in",
		"no year given", &"", 3,
		"Same book. He would have hated a new book, so.

Plate, nine sheets, took the lot, paid over, his rates, the sellers watch me do the sums the way they watched him and I let them. Coil, one, tested sound this time, took it at my rate. Herron still shorting the wire spools and still sorry about it.

Cygnet came Tuesday about the banked heat. The terms he turned away for twenty years, a quarter over posted now, an arrears clause I read three times and will have Marn read too. Eleven hundred upstairs, the dark quarter six weeks off, the mains drink what they drink.

Signed it. They did not gloat, I doubt it is in them. Wrote it in their book before they were off the ramp. He used to say they write everything down, like a curse.

Thursday: settle Herron, chase the school stove flue, plate wants reordering already.")

	_doc(&"warm_consolidated", "IRREGULARITIES, CONSOLIDATED", "a customs officer, station unnamed",
		"shift logs, four quarters attached", &"", 4,
		"To the superintendent, consolidated as instructed when I raised the third one verbally and was told to come back with a year.

A year: nineteen vessels presented warm, no thermal cargo declared, none found, all released, no seizable condition. Table attached, berth, date, watch, degrees over ambient. The first row is the one I logged myself, berth 9, second watch, eleven degrees, pilot in a coat with the heaters allegedly on. The degrees in the table climb a little across the year. The table says it better than I can.

Petition: add thermal state inconsistent with declared cargo to the schedule of seizable conditions.

I know how it reads, sir. The logs are attached so it stops reading that way. Also attached, my leave request, unrelated.")

	_doc(&"warm_reply", "MEMORANDUM IN REPLY", "a superintendent of customs",
		"reference year as marked", &"", 5,
		"Your consolidated report is received. Your diligence is noted at grade, and I have initialled the table myself.

The petition is declined. The schedule of seizable conditions enumerates property. Warmth is not property, a vessel's temperature is a circumstance of the vessel, and circumstances are not seized. Counsel's opinion is attached and is final, and I gave up at its second page, which stays between us.

Your transfer to the rim posting is approved with regret, effective the first. The leave is also approved. Take the leave first.

In hand at the foot: your nineteen is right. It was eleven the year I sat your desk, and it will not be nineteen next year. Nobody disputes your table. Go to the rim, the fishing is better than they say.")

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
