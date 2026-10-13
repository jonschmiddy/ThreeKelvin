extends Node

## WHICH WAY THINGS DIE (Jon's picks, Oct 13).
##   godot --headless --path . -- sheet=DeathPoolTest
## Over many seeded kills: every kept ship style and every creature style is
## reachable; the cut styles (E CHAIN, H SLICE) never play; a ship never rolls a
## creature's death and a creature never rolls a ship's; the Custodian rolls
## from the ships' pool; the same place gives the same death every time. Then a
## real fight won: each wreck lies in the slot the fight assumed when it chose
## its death, so LOCAL's wreck is the wreck the animation ended on.

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	h.seed_run(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var cut := [ShipBreakup.Style.CHAIN, ShipBreakup.Style.SLICE]
	var creatures := [ShipBreakup.Style.GLOWOUT, ShipBreakup.Style.BLOOM, ShipBreakup.Style.PART]
	h._ok("the ship pool is the eleven kept styles, A B C D F G I J K L M",
		EnemyArt.SHIP_STYLES == [0, 1, 2, 3, 5, 6, 8, 9, 10, 11, 12])
	h._ok("the creature pool is N O P", EnemyArt.CREATURE_STYLES == [13, 14, 15])
	var ships := {}
	var beasts := {}
	var crossed := 0
	var cut_played := 0
	var unstable := 0
	for id in DB.enemies.keys():
		var t: EnemyTemplate = DB.enemies[id]
		for node in 160:
			for slot in 6:
				var s := EnemyArt.death_style(t, node, slot)
				if s != EnemyArt.death_style(t, node, slot):
					unstable += 1
				if s in cut:
					cut_played += 1
				if t.fauna:
					beasts[s] = true
					if not s in creatures:
						crossed += 1
				else:
					ships[s] = true
					if s in creatures:
						crossed += 1
	for s2 in EnemyArt.SHIP_STYLES:
		h._ok("ship style %s is reachable" % ShipBreakup.NAMES[s2], ships.has(s2))
	for s3 in EnemyArt.CREATURE_STYLES:
		h._ok("creature style %s is reachable" % ShipBreakup.NAMES[s3], beasts.has(s3))
	h._ok("the cut styles never play (%d)" % cut_played, cut_played == 0)
	h._ok("ships and creatures never cross (%d)" % crossed, crossed == 0)
	h._ok("the same place gives the same death (%d unstable)" % unstable, unstable == 0)
	var boss: EnemyTemplate = DB.enemies[&"custodian"]
	h._ok("the Custodian rolls from the ships' pool",
		EnemyArt.death_style(boss, 3, 0) in EnemyArt.SHIP_STYLES)

	# A won fight's wrecks lie where the fight said they would.
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	Run.at = idx
	var node: MapGen.MapNode = Run.node_at()
	var before := 0
	for raw0 in node.jetsam:
		if (raw0 as MapGen.Jetsam).is_wreck():
			before += 1
	var cb := Combat.new()
	cb.start(DB.enemies[&"cutter"], node.danger, [DB.enemies[&"lancer"], DB.enemies[&"whale"]])
	var planned: Array = []
	for i in cb.enemies.size():
		planned.append(EnemyArt.death_style(cb.enemies[i].template, node.index, before + i))
	for e in cb.enemies:
		cb.damage_enemy(9999, 1, "test", e)
	h._ok("the fight was won", cb.result == &"victory")
	var wrecks: Array = []
	for raw in node.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			wrecks.append(raw)
	h._ok("one wreck per enemy (%d)" % wrecks.size(), wrecks.size() == cb.enemies.size())
	for i2 in mini(wrecks.size(), cb.enemies.size()):
		var w: MapGen.Jetsam = wrecks[i2]
		var t2: EnemyTemplate = DB.enemies[w.art]
		h._ok("wreck %d (%s) is the system's wreck %d and dies the way the fight chose"
			% [i2, w.art, before + i2],
			t2.id == cb.enemies[i2].template.id and EnemyArt.death_style(t2, node.index, before + i2) == planned[i2])
	h.verdict("deathpooltest")
	get_tree().quit(h.code())
