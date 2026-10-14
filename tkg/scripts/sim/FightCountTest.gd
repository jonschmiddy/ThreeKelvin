extends Node

## NOTHING JOINS A FIGHT, headless:
##   godot --headless --path . -- sheet=FightCountTest [seeds=N]
## Jon, Oct 13: "No reinforcements anywhere." A fight is the ships it was
## planned with and only ever loses them. For every kind of enemy, alone and
## (for the five that fly in packs) in a pack of two, over N seeded fights at a
## lawless system of danger 5 or more (where the old wave was likeliest: 25% on
## turn 3), the fight is played turn after turn -- your hull topped up so it
## does not end early -- to turn 7 or its end, and the enemy count read after
## every turn: it may never rise. The Custodian and the Hellbender are checked
## to stand alone the whole way.
##
## Calls only what a fight has always had (`Router.start_combat`, `end_turn`),
## so it runs on a build that still had the wave -- and failed there.

var _fails := 0
var _shown := 0


func _ok(what: String, c: bool) -> bool:
	if not c:
		_fails += 1
		if _shown < 20:
			print("  FAIL %s" % what)
			_shown += 1
	return c


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var seeds := int(_arg("seeds", "12"))
	var fights := 0
	var past3 := 0
	var turns := 0
	var ids: Array = DB.enemies.keys()
	ids.sort()
	for raw in ids:
		var id: StringName = raw
		var t: EnemyTemplate = DB.enemies[id]
		var packs: Array = [[id]]
		if not t.boss and not t.miniboss and not t.fauna:
			packs.append([id, &"cutter"])
		for pack: Array in packs:
			for sd in seeds:
				var r := await _fight(tree, pack, 9000 + sd * 31)
				if r.is_empty():
					continue
				fights += 1
				turns += int(r.turns)
				if int(r.turns) > 3:
					past3 += 1
				_ok("%s seed %d: the count never rose (%s)" % ["+".join(pack), sd, r.counts], not bool(r.rose))
				if t.boss or t.miniboss:
					_ok("%s seed %d: fought alone the whole way (%s)" % [id, sd, r.counts], int(r.most) == 1)
	_ok("enough fights ran past turn 3 to have met the old wave (%d of %d)" % [past3, fights], past3 * 2 >= fights)
	print("fightcounttest: %d fights, %d past turn 3, %.1f turns a fight" % [fights, past3, float(turns) / maxf(1.0, fights)])
	print("fightcounttest: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	tree.quit()


func _fight(tree: SceneTree, pack: Array, sd: int) -> Dictionary:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var at := -1
	for m: MapGen.MapNode in Run.map:
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			at = m.index
			if m.region == MapGen.Region.LAWLESS:
				break
	if at < 0:
		return {}
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
