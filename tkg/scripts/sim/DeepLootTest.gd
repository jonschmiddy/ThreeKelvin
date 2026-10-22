extends Node

## GOING DEEP PAYS (Jon, Oct 22: a hard game, where going deep is worth it).
##   godot --headless --path . -- sheet=DeepLootTest [seed N]
##
## Two rules, and the rarity mix they leave, by tier (`MapGen.tier`):
##
##   1. THE MATERIAL GATES ARE THE MODULE GATES. Materials read danger through
##      `MapGen.tier` as `LootGen.roll_module` does: Epic from tier 3, Legendary
##      and Artifact from tier 4. They used to compare those tier numbers against
##      RAW danger (1-10), so they opened about twice as shallow as modules.
##   2. NO COMMON PAST HALFWAY. From tier 3 (danger 5+) no source rolls a COMMON
##      module or a common material -- and a pool the rule would empty falls back
##      to the same pool with its commons, never to one hard-coded part.
##
## Every source rolled the way the game rolls it, over SEEDS seeded galaxies:
## every wreck a fight could leave (`Combat.roll_wreck`), a kill bag
## (`Run.open_bag`), a derelict's parts (`Router`'s salvage roll), an event's
## floor part and the relic analysis (`LootGen.roll_module`), every station shelf
## (`StationScreen._stock_up`), the custodian's body (`Combat.core_body`), and
## every material table (`MaterialTable.roll`). The tables it prints are the
## rarity mix of each, by tier.

var h := Harness.new()

const SEEDS := 4
## Rolls a table is asked for at each system.
const MAT_ROLLS := 6
const TIERS := [1, 2, 3, 4, 5]
const MODS := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Exotic", "Artifact", "Contraband"]
const MATS := [&"common", &"rare", &"epic", &"legendary", &"exotic", &"artifact", &"contraband"]
const TABLES := [&"event", &"wreck", &"fight", &"fauna", &"mining"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_gates()
	_direct()
	_sources()
	_fallbacks()
	h.verdict("deeploottest")
	get_tree().quit(h.code())


# ------------------------------------------------------------------- gates

## The material gate, at every danger, against the module gate's tiers.
func _gates() -> void:
	print("=== MATERIAL GATES ===")
	var bad: Array[String] = []
	for d in range(1, MapGen.DANGER_MAX + 1):
		var t := MapGen.tier(d)
		var want := {
			&"common": t < 3,
			&"rare": true,
			&"epic": t >= 3,
			&"legendary": t >= 4,
			&"artifact": t >= 4,
			&"exotic": true,
			&"contraband": true,
		}
		for tier in want:
			if MaterialTable.admits(tier, d) != bool(want[tier]):
				bad.append("%s at danger %d (tier %d)" % [tier, d, t])
	h._ok("Epic from tier 3, Legendary and Artifact from tier 4, Common below tier 3%s"
		% ("" if bad.is_empty() else ": wrong for " + ", ".join(bad)), bad.is_empty())
	h._ok("the gates are LootGen's own (epic %d, legendary %d, no common from %d)"
		% [LootGen.EPIC_TIER, LootGen.LEGENDARY_TIER, LootGen.NO_COMMON_TIER],
		LootGen.EPIC_TIER == 3 and LootGen.LEGENDARY_TIER == 4 and LootGen.NO_COMMON_TIER == 3)
	# In danger, which is what a player reads off the chart.
	var first := {}
	for tier in [&"epic", &"legendary", &"artifact"]:
		for d in range(1, MapGen.DANGER_MAX + 1):
			if MaterialTable.admits(tier, d):
				first[tier] = d
				break
	print("  first danger: epic %d · legendary %d · artifact %d"
		% [int(first.get(&"epic", 0)), int(first.get(&"legendary", 0)), int(first.get(&"artifact", 0))])


# ----------------------------------------------------------- roll_module itself

## `roll_module` at every danger, every way it is called: open, with precursor
## parts, and forced to each manufacturer this run can find.
func _direct() -> void:
	print("=== ROLL_MODULE, EVERY DANGER ===")
	h.seed_run(7300)
	Run.start_new_run(&"korvan", 1)
	var forces: Array[StringName] = [&""]
	for m in DB.manufacturers.keys():
		if LootGen.can_appear(m):
			forces.append(m)
	var commons_deep := 0
	var commons_shallow := 0
	var rolls := 0
	for d in range(1, MapGen.DANGER_MAX + 1):
		var r := Rng.derive(&"deeploot", d)
		for f in forces:
			for unbranded in [false, true]:
				for i in 60:
					var m := LootGen.roll_module(d, f, unbranded, r)
					rolls += 1
					if m.rarity != ModuleData.Rarity.COMMON:
						continue
					if MapGen.tier(d) >= 3:
						commons_deep += 1
					else:
						commons_shallow += 1
	h._ok("no COMMON from danger 5 up, over %d rolls (%d)" % [rolls, commons_deep], commons_deep == 0)
	h._ok("and commons still roll shallower (%d)" % commons_shallow, commons_shallow > 0)


# ------------------------------------------------------------------- sources

func _sources() -> void:
	print("=== EVERY SOURCE, %d GALAXIES ===" % SEEDS)
	var mix: Dictionary = {}   # source -> tier -> key -> count
	for i in SEEDS:
		h.seed_run(7400 + i)
		Run.start_new_run(&"korvan", i % 3)
		_roll_everything(mix)
	var srcs := mix.keys()
	srcs.sort()
	for src in srcs:
		var is_mat := String(src).begins_with("material")
		print("  %s" % src)
		_table(mix[src], MATS if is_mat else MODS)
		var deep_common := 0
		var shallow_common := 0
		var early: Array[String] = []
		for t in mix[src]:
			var row: Dictionary = mix[src][t]
			var c := int(row.get(&"common" if is_mat else "Common", 0))
			if int(t) >= 3:
				deep_common += c
			else:
				shallow_common += c
			if is_mat:
				if int(t) < 3 and int(row.get(&"epic", 0)) > 0:
					early.append("epic at tier %d" % t)
				for top in [&"legendary", &"artifact"]:
					if int(t) < 4 and int(row.get(top, 0)) > 0:
						early.append("%s at tier %d" % [top, t])
		h._ok("%s: no common at tier 3+ (%d)" % [src, deep_common], deep_common == 0)
		if is_mat:
			h._ok("%s: nothing above its gate%s" % [src,
				"" if early.is_empty() else ": " + ", ".join(early)], early.is_empty())


## Every source, as the game rolls it, into `mix`.
func _roll_everything(mix: Dictionary) -> void:
	var kinds: Array[EnemyTemplate] = []
	for id in DB.enemies:
		var t: EnemyTemplate = DB.enemies[id]
		if not (t.boss or t.miniboss or t.fauna):
			kinds.append(t)
	var stocker := StationScreen.new()
	var at_was := Run.at
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		var t := MapGen.tier(n.danger)
		match n.type:
			MapGen.NodeType.SYSTEM:
				for k in kinds.size():
					_count(mix, "wrecks", t, Combat.roll_wreck(n, kinds[k], k, 1))
				n.bagged = false
				n.bag.clear()
				Run.open_bag(n, 2, 1)
				_count(mix, "kill bags", t, n.bag)
				# `Router`'s derelict, rolled the way it rolls it.
				var r := Rng.derive(&"salvage", n.index)
				var force := n.manufacturer if n.region == MapGen.Region.TERRITORY else &""
				for j in 2:
					_count(mix, "derelict parts", t, [LootGen.roll_module(n.danger, force,
						n.region == MapGen.Region.DEEP or n.region == MapGen.Region.FAUNA, r)])
				_count(mix, "event floor parts", t, [LootGen.roll_module(n.danger)])
				_count(mix, "relic analysis", t, [LootGen.roll_module(n.danger, &"", true)])
				for table in TABLES:
					var mr := Rng.derive(&"material", n.index)
					for j in MAT_ROLLS:
						var row := MaterialTable.roll(table, n.danger, mr)
						if not row.is_empty():
							_count(mix, "material: %s" % table, t, [MaterialData.of(row)])
			MapGen.NodeType.STATION:
				Run.at = n.index
				n.stocked = false
				n.shop.clear()
				n.shop_hull = null
				stocker._stock_up()
				_count(mix, "station shelves", t, n.shop)
			MapGen.NodeType.CORE:
				var body := Combat.core_body(n, DB.enemies[&"custodian"])
				_count(mix, "the custodian's body", t, body.items)
	Run.at = at_was
	stocker.free()


func _count(mix: Dictionary, src: String, t: int, items: Array) -> void:
	for it in items:
		var key: Variant = null
		if it is ModuleData:
			key = MODS[(it as ModuleData).rarity]
		elif it is MaterialData:
			key = (it as MaterialData).tier
		if key == null:
			continue
		if not mix.has(src):
			mix[src] = {}
		if not mix[src].has(t):
			mix[src][t] = {}
		mix[src][t][key] = int(mix[src][t].get(key, 0)) + 1


func _table(by_tier: Dictionary, keys: Array) -> void:
	var head := "    tier %5s" % "n"
	for k in keys:
		head += " %6s" % String(k).substr(0, 6)
	print(head)
	for t in TIERS:
		if not by_tier.has(t):
			continue
		var row: Dictionary = by_tier[t]
		var total := 0
		for k in keys:
			total += int(row.get(k, 0))
		var line := "    %4d %5d" % [t, total]
		for k in keys:
			line += " %5.1f%%" % (100.0 * int(row.get(k, 0)) / maxi(1, total))
		print(line)


# ----------------------------------------------------------------- fallbacks

## A pool the rule would empty keeps its commons; it never collapses to one part.
func _fallbacks() -> void:
	print("=== FALLBACKS ===")
	h.seed_run(7500)
	Run.start_new_run(&"korvan", 1)
	# Every Korvan part made COMMON for the length of this check, so Korvan
	# space at danger 9 has nothing the rule lets through.
	var was: Dictionary = {}
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.manufacturer == &"korvan" and not m.starter_only:
			was[id] = m.rarity
			m.rarity = ModuleData.Rarity.COMMON
	var ids: Dictionary = {}
	var korvan := true
	var r := Rng.derive(&"deeploot", 99)
	for i in 200:
		var m := LootGen.roll_module(9, &"korvan", false, r)
		ids[m.id] = true
		korvan = korvan and m.manufacturer == &"korvan"
	for id in was:
		(DB.modules[id] as ModuleData).rarity = was[id]
	h._ok("an all-common Korvan pool deep still rolls Korvan parts", korvan)
	h._ok("from the whole pool, not one fallback part (%d different of %d)" % [ids.size(), was.size()],
		ids.size() > 1)
	# A table whose only rows are common, deep: the table's own commons.
	var all := MaterialTable.all()
	var probe := {id = &"deeploot_probe", name = "PROBE", tier = &"common", cells = "1x1",
		value = 1, drops = &"deeploot_probe", text = ""}
	all.append(probe)
	var row := MaterialTable.roll(&"deeploot_probe", 9, Rng.derive(&"deeploot", 98))
	all.erase(probe)
	h._ok("an all-common material table deep still pays its own row",
		StringName(row.get("id", &"")) == &"deeploot_probe")
