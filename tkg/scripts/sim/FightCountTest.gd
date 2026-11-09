extends Node

## Nothing joins a fight (Jon, Oct 13): the enemy count may never rise. `-- sheet=FightCountTest`.
## Why: docs/why/FightCountTest.md#no-reinforcements

var h := Harness.new()
var _shown := 0


func _ok(what: String, c: bool) -> bool:
	if not c:
		h._fails += 1
		if _shown < 20:
			print("  FAIL %s" % what)
			_shown += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var seeds := int(Harness.arg("seeds", "12"))
	var fights := 0
	var past3 := 0
	var turns := 0
	var ids: Array = DB.enemies.keys()
	ids.sort()
	var packs: Array = []
	for raw in ids:
		var id: StringName = raw
		var t: EnemyTemplate = DB.enemies[id]
		packs.append([id])
		if not t.boss and not t.miniboss and not t.fauna:
			packs.append([id, &"cutter"])
	# One galaxy a seed, not one a fight: the system is forced lawless and danger 5 below,
	# so the galaxy never changed what a fight saw. A sixth of the run's time (168 fights).
	for sd in seeds:
		var at := _lawless_system(9000 + sd * 31)
		if not _ok("seed %d: a system to fight in" % sd, at >= 0):
			continue
		for pack: Array in packs:
			var t: EnemyTemplate = DB.enemies[pack[0]]
			var r := await _fight(tree, pack, at, 9000 + sd * 31)
			if not _ok("%s seed %d: the fight started" % ["+".join(pack), sd], not r.is_empty()):
				continue
			fights += 1
			turns += int(r.turns)
			if int(r.turns) > 3:
				past3 += 1
			_ok("%s seed %d: the count never rose (%s)" % ["+".join(pack), sd, r.counts], not bool(r.rose))
			if t.boss or t.miniboss:
				_ok("%s seed %d: fought alone the whole way (%s)" % [pack[0], sd, r.counts], int(r.most) == 1)
	_ok("enough fights ran past turn 3 to have met the old wave (%d of %d)" % [past3, fights], fights > 0 and past3 * 2 >= fights)
	print("fightcounttest: %d fights, %d past turn 3, %.1f turns a fight" % [fights, past3, float(turns) / maxf(1.0, fights)])
	h.verdict("fightcounttest")
	tree.quit(h.code())


## The run's galaxy from the seed, and the index of its first lawless system (or any system), or -1.
func _lawless_system(sd: int) -> int:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var at := -1
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			at = m.index
			if m.region == MapGen.Region.LAWLESS:
				break
	return at


func _fight(tree: SceneTree, pack: Array, at: int, sd: int) -> Dictionary:
	# Each fight from the seed's fresh rolls, whatever fought before it.
	Rng.reseed(sd, Net.seat())
	Run.hp = Run.max_hp()
	Run.dead = false
	Run.at = at
	var node := Run.node_at()
	node.danger = maxi(node.danger, 5)
	node.region = MapGen.Region.LAWLESS
	SectorScreen._approached_at = at
	var extras: Array = []
	for i in range(1, pack.size()):
		extras.append(DB.enemies[pack[i]])
	Router.start_combat(DB.enemies[pack[0]], extras, false, false)
	var cb = Router.combat
	if cb == null:
		return {}
	await tree.process_frame
	var counts: Array = [cb.enemies.size()]
	var rose := false
	var most: int = cb.enemies.size()
	var turn := 1
	while turn < 7 and not cb.finished:
		Run.hp = Run.max_hp()
		var before: int = cb.enemies.size()
		cb.end_turn()
		await tree.process_frame
		turn += 1
		counts.append(cb.enemies.size())
		rose = rose or cb.enemies.size() > before
		most = maxi(most, cb.enemies.size())
	return {"counts": counts, "rose": rose, "most": most, "turns": turn}
