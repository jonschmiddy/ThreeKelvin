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
##     place shows wherever you are, as it did then;
##   - and SECTOR LOOT (Jon, Oct 15: "When a wreck is opened, and all or some of
##     the parts are left behind, those should also show up in the sector loot
##     pool for that sector"): nothing of a wreck before it is opened; once it
##     has been, through LOCAL's own door, the button shows what is left in it,
##     from any place in the system; a take through SECTOR LOOT is the wreck's
##     own claim, a part put down goes on the pile, one put back that came out
##     of the wreck goes back into it; a save keeps which wrecks were opened.

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
	await _sector_loot()
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


func _parts(k: int) -> Array:
	var out: Array = []
	for id in DB.modules:
		var m := DB.modules[id] as ModuleData
		if m.starter_only:
			continue
		out.append(m.duplicate(true))
		if out.size() >= k:
			break
	return out


## The button on LOCAL's bottom bar, and the number on it (0 when it is not there).
func _button() -> int:
	var sc := Router.current as SectorScreen
	if sc == null:
		return -1
	var b := sc.find_child("SectorLoot", true, false) as Button
	if b == null or not b.is_visible_in_tree():
		return 0
	return int(b.text.get_slice("·", 1).strip_edges())


func _sector_loot() -> void:
	Rng.forced = 99
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	for c: MapGen.MapNode in Run.map:
		if c.type == MapGen.NodeType.SYSTEM and c.region != MapGen.Region.FAUNA:
			n = c
			break
	Run.at = n.index
	SystemMapScreen._parked[n.index] = {"at": 0}
	_win(n, &"cutter")
	var w: MapGen.Jetsam = Run.wrecks_here(n)[0]
	w.items.assign(_parts(3))
	Router.show_local()
	for i in 6:
		await get_tree().process_frame
	h._ok("an unopened wreck is not under SECTOR LOOT", Run.sector_loot(n) == null and _button() == 0)
	# opened through LOCAL's own door, one part taken there, then shut
	var sc := Router.current as SectorScreen
	sc._open_jetsam(w)
	await get_tree().process_frame
	h._ok("opening it marks it opened", w.opened)
	await Run.take_from_jetsam(n, w, 0)
	sc._close_transfer()
	for i in 4:
		await get_tree().process_frame
	h._ok("SECTOR LOOT shows the two left in it (%d)" % _button(), _button() == 2)
	# from another place in the system too
	SystemMapScreen._parked[n.index] = {"at": -1}
	Router.show_local()
	for i in 6:
		await get_tree().process_frame
	h._ok("and from the star, where the wreck is not (%d)" % _button(), _button() == 2)
	# a take through SECTOR LOOT is the wreck's own claim
	var v := Run.sector_loot(n)
	var i1 := -1
	for i in v.items.size():
		if not n.taken.has(v.option(i)):
			i1 = i
			break
	var m1: HoldItem = v.items[i1]
	await Run.take_from_jetsam(n, v, i1)
	h._ok("taken through SECTOR LOOT, it is gone from the wreck (%d left)" % Run.jetsam_left(n, w),
		Run.jetsam_left(n, w) == 1 and Run.cargo.has(m1))
	# one put back goes back into the wreck; one put down goes on the pile
	Run.put_in(n, v, m1)
	h._ok("put back, it is in the wreck again (%d)" % Run.jetsam_left(n, w), Run.jetsam_left(n, w) == 2)
	var mine: HoldItem = _parts(4)[3]
	Run.place_in_hold(mine)
	Run.put_in(n, v, mine)
	var pile := Run.sector_jetsam(n, false)
	h._ok("a part put down goes on the system's pile", pile != null and pile.items.has(mine)
		and not w.items.has(mine))
	h._ok("and SECTOR LOOT shows all three (%d)" % Run.jetsam_left(n, Run.sector_loot(n)),
		Run.jetsam_left(n, Run.sector_loot(n)) == 3)
	var back := SaveGame._node_from(SaveGame._node_to(n))
	var opened := false
	for raw in back.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			opened = (raw as MapGen.Jetsam).opened
	h._ok("a save keeps the wreck opened", opened)
