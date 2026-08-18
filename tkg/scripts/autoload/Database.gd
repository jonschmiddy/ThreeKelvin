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
## NOTE: with a single active maker, set bonuses stop being a choice — you will
## always hold 5+ from one maker. That contradicts the "set bonuses are the
## class system" ruling in CLAUDE.md and is a deliberate scope cut, not a
## balance change. Restore the full list before judging build variety.
const ACTIVE_MAKERS: Array[StringName] = [&"korvan"]

var manufacturers: Dictionary = {}      ## StringName -> ManufacturerData
var modules: Dictionary = {}            ## StringName -> ModuleData (templates)
var hull_frames: Array[HullData] = []
var enemies: Dictionary = {}            ## StringName -> EnemyTemplate
var affixes: Array[AffixData] = []
var hull_perks: Dictionary = {}         ## StringName -> {name, text}

const STARTER_KIT: Array[StringName] = [&"kh20", &"km4", &"plate", &"coolant", &"servo"]

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
		[&"korvan", "Korvan Heavy Works", "It fires. Every time.", "#8a6a3a",
			"Ex-military surplus parts. Ballistics run cold; ordnance and armor run hot.",
			"Standard Issue", "Charge cards charge 1 turn faster.",
			"Full Broadside", "Salvo applies to your first attack too."],
		[&"solari", "Solari Foundry", "The line between reactor and weapon is philosophy.", "#b1531f",
			"Weaponised heat. Damage scales with your own fever.",
			"Sunward", "Plasma weapons gain +2 damage.",
			"Ignition", "Overheat damage halved."],
		[&"dredge", "The Dredge Combine", "Everything is salvage. Even you.", "#6b6250",
			"Scrap economy and armor sustain. Wins slowly, wins rich.",
			"Company Rates", "+50% scrap from wrecks.",
			"Foundry Line", "Brace cards give +2 armor."],
		[&"redline", "Redline Shipyards", "Still flying? Then we did our job.", "#5a7a6a",
			"Salvage tech, stealth and refits. Innate contraband affinity.",
			"Chop Shop", "Draw 1 extra card each turn.",
			"Ghost Protocol", "First enemy attack each combat is negated."],
		[&"veyra", "Veyra Ateliers", "Made once, made properly.", "#8a7a9a",
			"The thin, perfect deck. Few slots, superb cards, expensive everything.",
			"Bespoke", "Veyra cards cost 1 less energy.",
			"Provenance", "Start each combat with 1 extra energy."],
		[&"cygnet", "Cygnet Dynamics", "You are never alone.", "#5a7a94",
			"Autonomous drones that fight and intercept for you.",
			"Swarm Logic", "Drones act twice on the turn they launch.",
			"Hive Mind", "Drones persist between encounters."],
		[&"calyx", "Calyx Systems", "Grown, not built.", "#6a8a6a",
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
		m.identity = r[4]
		m.set3_name = r[5]
		m.set3_text = r[6]
		m.set5_name = r[7]
		m.set5_text = r[8]
		manufacturers[m.id] = m

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
		{name = "Salvaged", text = "+2 scrap on play", add_scrap = 2},
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

	# --- Dredge: scrap and sustain
	_module(&"claw", "Salvage Claw", &"dredge", U, C0,
		"Strips value off things still moving.",
		[{name = "Strip Mine", energy = 1, damage = 5, scrap_gain = 3, copies = 2}])
	_module(&"slag", "Slag Armor Kit", &"dredge", S, C1,
		"Ugly, heavy, pays for itself.",
		[{name = "Slag Plate", energy = 1, armor = 4, scrap_gain = 2, copies = 2}])
	_module(&"refinery", "Field Refinery", &"dredge", U, C2,
		"Feeds scrap into the armor press.",
		[{name = "Smelt", energy = 1, scrap_cost = 5, armor = 10, copies = 1}])
	_module(&"ripper", "Dredge Tear-Down Rig", &"dredge", W, C2,
		"Disassembles hulls that object.",
		[{name = "Tear Down", energy = 2, heat = 1, damage = 7, hits = 2, scrap_gain = 4, copies = 2}])

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

	# --- Veyra: precision
	_module(&"rail", "Aurelian Rail", &"veyra", W, C2,
		"Nothing wasted. Nothing missed.",
		[{name = "Precise Shot", energy = 1, heat = 1, damage = 9, draw = 1, copies = 2}])
	_module(&"auspex", "Auspex Array", &"veyra", U, C1,
		"You always have the card you need.",
		[{name = "Foresight", energy = 0, draw = 2, copies = 2}])
	_module(&"halcyon", "Halcyon Deflector", &"veyra", S, C3,
		"Elegance, quantified.",
		[{name = "Deflect", energy = 1, block = 12, copies = 2}])

	# --- Calyx: regrowth and adaptation
	_module(&"weave", "Vital Weave", &"calyx", S, C1,
		"The hull knits itself. Slowly.",
		[{name = "Knit", energy = 1, heal = 5, copies = 2}])
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

# ------------------------------------------------------------------------ hulls

func _seed_hulls() -> void:
	var raw := [
		{name = "Skiff Frame", weight = HullData.Weight.LIGHT, reactor = 3, hand_size = 6,
			max_hull = 24, heat_cap = 8, dissipation = 5, dodge = 0.18, initiative = 2,
			fuel_factor = 0.8, weapon_slots = 2, system_slots = 1, utility_slots = 2},
		{name = "Medium Frame", weight = HullData.Weight.MEDIUM, reactor = 3, hand_size = 5,
			max_hull = 35, heat_cap = 12, dissipation = 3, dodge = 0.05, initiative = 0,
			fuel_factor = 1.2, weapon_slots = 3, system_slots = 2, utility_slots = 1},
		{name = "Bulk Frame", weight = HullData.Weight.HEAVY, reactor = 4, hand_size = 4,
			max_hull = 52, heat_cap = 18, dissipation = 2, dodge = 0.0, initiative = -2,
			fuel_factor = 1.8, weapon_slots = 4, system_slots = 2, utility_slots = 1},
	]
	for d in raw:
		var h := HullData.new()
		for k in d.keys():
			h.set(k, d[k])
		hull_frames.append(h)

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

# ---------------------------------------------------------------------- enemies

func _intent(d: Dictionary) -> IntentData:
	var i := IntentData.new()
	for k in d.keys():
		i.set(k, d[k])
	return i

func _enemy(id: StringName, name: String, tag: String, hp: int, armor: int,
		scrap: int, art: StringName, loop: Array, pool: Array,
		fauna: bool = false, boss: bool = false) -> void:
	var e := EnemyTemplate.new()
	e.id = id
	e.name = name
	e.tag = tag
	e.max_hull = hp
	e.armor = armor
	e.scrap_reward = scrap
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
