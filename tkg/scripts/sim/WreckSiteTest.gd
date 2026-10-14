extends Node

## EACH PLACE KEEPS ITS OWN WRECKS (Jon, Oct 14: "each planet or POI you can
## visit should contain its own wrecks/fights").
##   godot --headless --path . -- sheet=WreckSiteTest
##
## A wreck lies where your ship was when its hull died (`Jetsam.site`: the body
## it orbited, -1 the star, -9 open space), and LOCAL draws the wrecks of the
## place you are parked at and no other's:
##   - two fights at a world leave their hulls at that world; the star next door
##     has none of them, and its own fight's hull is its alone;
##   - back at the world, its two are there again;
##   - the real LOCAL draws exactly the place's wrecks, each with the death roll
##     and fight marks of its number among the whole system's wrecks (what the
##     kill was keyed on), and open space with none draws the place picture;
##   - a save keeps each wreck's place; a wreck from a save before wrecks had a
##     place shows wherever you are, as it did then.

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	h.seed_run(2718)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	for c: MapGen.MapNode in Run.map:
		if c.type == MapGen.NodeType.SYSTEM and c.region != MapGen.Region.FAUNA:
			n = c
			break
	Run.at = n.index
	var parked := SystemMapScreen._parked

	parked[n.index] = {"at": 0}
	_win(n, &"cutter", [&"lancer"])
	h._ok("two hulls lie at the world fought over (%d)" % Run.wrecks_here(n).size(), Run.wrecks_here(n).size() == 2)
	parked[n.index] = {"at": -1}
	h._ok("the star next door has none of them (%d)" % Run.wrecks_here(n).size(), Run.wrecks_here(n).is_empty())
	_win(n, &"hulk")
	var at_star := Run.wrecks_here(n)
	h._ok("its own fight's hull is its alone (%d)" % at_star.size(), at_star.size() == 1 and at_star[0].site == -1)
	h._ok("and is the system's third wreck", Run.wreck_ordinal(n, at_star[0]) == 2)
	parked[n.index] = {"at": 0}
	h._ok("back at the world, its two are there (%d)" % Run.wrecks_here(n).size(), Run.wrecks_here(n).size() == 2)
	parked.erase(n.index)
	h._ok("open space, where a system starts, has none", Run.wrecks_here(n).is_empty())

	# the real LOCAL at each place
	for site in [0, -1, -9]:
		if site == -9:
			parked.erase(n.index)
		else:
			parked[n.index] = {"at": site}
		Router.show_local()
		for i in 6:
			await get_tree().process_frame
		var sc := Router.current as SectorScreen
		var ev: EncounterView = sc._view if sc != null else null
		var want := Run.wrecks_here(n)
		if ev == null:
			h._fail("LOCAL did not come up at site %d" % site)
			continue
		var drawn: int = ev._made.size() if ev._slots_mode == &"wrecks" and ev._slots.visible else 0
		h._ok("LOCAL at %d draws its %d wrecks (%d)" % [site, want.size(), drawn], drawn == want.size())
		for i in mini(drawn, want.size()):
			var k := Run.wreck_ordinal(n, want[i])
			h._ok("  wreck %d keeps its fight's marks and death (system's #%d)" % [i, k],
				ev._made[i].wreck_id == n.index * 64 + k
				and ev._made[i].death_style == EnemyArt.death_style(DB.enemies[want[i].art], n.index, k))
		if want.is_empty():
			h._ok("  and the place picture instead", ev._area.visible or LocalSubject.of(ev) != null)

	# the save
	var back := SaveGame._node_from(SaveGame._node_to(n))
	var sites: Array = []
	for raw in back.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			sites.append((raw as MapGen.Jetsam).site)
	h._ok("a save keeps every wreck's place %s" % [sites], sites == [0, 0, -1])
	var row: Dictionary = SaveGame._node_to(n)
	for j in (row.jetsam as Array):
		(j as Dictionary).erase("site")
	var old := SaveGame._node_from(row)
	Run.map[n.index] = old
	parked[n.index] = {"at": 3}
	h._ok("a wreck from before places shows wherever you are (%d)" % Run.wrecks_here(old).size(),
		Run.wrecks_here(old).size() == 3)
	Run.map[n.index] = n
	h.verdict("wrecksitetest")
	get_tree().quit(h.code())


func _win(n: MapGen.MapNode, lead: StringName, extras: Array[StringName] = []) -> void:
	var more: Array = []
	for id in extras:
		more.append(DB.enemies[id])
	var cb := Combat.new()
	cb.start(DB.enemies[lead], n.danger, more)
	for e in cb.enemies:
		cb.damage_enemy(9999, 1, "test", e)
