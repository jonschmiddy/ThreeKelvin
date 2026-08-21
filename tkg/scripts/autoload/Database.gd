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
	m.scrap_value = [8, 16, 30, 55, 95, 120, 160][rarity]
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
	## weight, and sustain is why: hull loss causes half the deaths in this
	## game, so a weapon that repairs while it fires is worth more than one
	## that hits harder. Two points of healing on two copies of a card in a
	## nine-card deck was quietly the best starter in the game.
	_module(&"barb", "Calyx Barb", &"calyx", W, C0,
		"Grown to a point. Feeds on what it opens.",
		[{name = "Barb", energy = 1, damage = 4, heal = 1, copies = 2}])
	_module(&"nodule", "Adaptive Nodule", &"calyx", W, C2,
		"Learns the shape of this fight.",
		[{name = "Adapt", energy = 1, damage = 4, adapt = 2, copies = 2}])
	_module(&"sporevent", "Calyx Spore Vent", &"calyx", U, C2,
		"Grown coolant. Unsettlingly warm.",
		[{name = "Bloom", energy = 0, vent = 6, heal = 3, copies = 1}])

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
	_module(&"patchkit", "Patch Kit", &"", U, C0,
		"Foam, tape, and a prayer to whoever welded the frame.",
		[{name = "Patch", energy = 1, heal = 4, copies = 1}])

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
	var sensors := {&"auspex": 2, &"servo": 1, &"evoke": 1, &"board": 1, &"scope": 1}
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
		&"slag": 4,                            # dredge
		&"weave": 3,                           # calyx
		&"lattice": 8,                         # precursor artifact
	}
	# Capacity: how much heat you can hold. Solari's whole axis.
	var heat_plus := {&"shroud": 5, &"overdrive": 3, &"ventcan": 2}
	# Shedding: how fast you get rid of it. Deliberately scarcer than capacity —
	# three bearers at +1 — because dissipation compounds every single turn and a
	# medium frame only starts with 3.
	var vent_plus := {&"coolant": 1, &"coolline": 1, &"sporevent": 1}
	# Evasion, and only from Redline, whose set is named for it.
	var dodge_plus := {&"ghost": 0.04, &"chaff": 0.02}
	# Acting sooner. The same three modules that already grant Sensors, because
	# seeing first and moving first are the same sentence.
	var init_plus := {&"servo": 1, &"evoke": 1, &"singing": 1}

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
		h.exhaust_offset = EXHAUST_AT
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
	h.exhaust_offset = EXHAUST_AT
	return h

## The real art for a weight class, or null to fall back to ShipView's
## procedural drawing.
##
## MEDIUM only, today. There is exactly one generated hull and it is a medium, so
## light and heavy keep drawing procedurally — which is the partial-migration
## state `docs/art/ASSET_PIPELINE.md` expects, not an oversight.
##
## It is also given to every manufacturer's medium, not just Korvan's. That is
## knowingly wrong: the sprite has Korvan brass on it and a Solari medium should
## not. It stands because the point of this step is to judge ONE real hull in the
## running game, and hiding it behind a single chassis would mean almost never
## seeing it. Per-manufacturer hulls, or a livery tint over a neutral one, is the
## next art decision — see ART_CONTRACT.md §5.
func hull_sprite(w: HullData.Weight) -> Texture2D:
	if w != HullData.Weight.MEDIUM:
		return null
	return load("res://art/sprites/hull_medium_cold.png") as Texture2D

## The engine plume for a weight class: a 9-frame strip, cropped tight, which is
## why it carries an offset. See HullData.exhaust.
const EXHAUST_FRAMES := 9
## The hull canvas is cropped tight around the ship so STRETCH_KEEP_CENTERED
## actually centres it. With 70px of dead space on the right the content sat
## left of centre, and at 2x the view clipped the flames off first.
const EXHAUST_AT := Vector2i(0, 27)

func hull_exhaust(w: HullData.Weight) -> Texture2D:
	if w != HullData.Weight.MEDIUM:
		return null
	return load("res://art/sprites/hull_medium_exhaust.png") as Texture2D

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
		{name = "Spore Breath", text = "Deal 3, +1 Dross", damage = 3, dross = 1, weight = 30},
	], true)
	_enemy(&"leviathan", "Void Leviathan", "megafauna · adult", 88, 4, 0, &"whale", [], [
		{name = "Sounding", text = "Heals 8", heal = 8, weight = 20},
		{name = "Breach", text = "Deal 15", damage = 15, weight = 45},
		{name = "Spore Storm", text = "Deal 5, +2 Dross", damage = 5, dross = 2, weight = 35},
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
