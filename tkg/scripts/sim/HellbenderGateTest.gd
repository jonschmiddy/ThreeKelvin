extends Node

## The Hellbender flies only at ascension 7 and up, headless:
##   godot --headless --path . -- sheet=HellbenderGateTest [seeds=60]
## Why: docs/why/HellbenderGateTest.md#hellbender-gate-test

var h := Harness.new()
var _tree: SceneTree
var _log: Array[String] = []


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(k + "="):
			return (a as String).substr(k.length() + 1)
	return d


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _start(seed_v: int, asc: int) -> void:
	Rng.forced = seed_v
	Run.forced_ascension = asc
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.forced_ascension = -1


func _run() -> void:
	await _tree.process_frame
	Sig.log_line.connect(func(text: String, _k: StringName) -> void: _log.append(text))
	var seeds := int(_arg("seeds", "60"))
	_level_zero(seeds)
	_level_seven(seeds)
	_boards()
	_old_save()
	await _fight_at_zero()
	Rng.forced = 0
	h.verdict("hellbendergatetest")
	_tree.quit(1 if h._fails > 0 else 0)


func _names_it(s: String) -> bool:
	return s.to_upper().contains("HELLBENDER")


## Level 0: never there, and nothing a player sees says it is.
func _level_zero(seeds: int) -> void:
	print("-- ascension 0, %d seeds" % seeds)
	var spawned := 0
	var moved := 0
	var eaten := 0
	var placed := 0
	var engage := 0
	var drawer: Array[String] = []
	var stamped := 0
	var jumped := 0
	_log.clear()
	for i in seeds:
		_start(1000 + i * 37, 0)
		if Run.ascension != 0 or Run.hellbender_at != -1 or Run.hellbender_hp != 0 \
				or Run.hellbender_max != 0 or Run.hellbender_alive():
			spawned += 1
		# its clock, as every jump in the party drives it, far past a run's length
		for j in 200:
			Run.hellbender_jumped()
		if Run.hellbender_moves != 0 or Run.hellbender_at != -1:
			moved += 1
		# and a short real flight, so the log is the one a player reads
		for j in 12:
			var pick: MapGen.MapNode = null
			for n in Run.in_range():
				if n.index != Run.at and n.type == MapGen.NodeType.SYSTEM:
					pick = n
					break
			if pick == null:
				break
			Run.fuel = maxi(Run.fuel, Run.fuel_cost_to(pick) + 1)
			if not Run.can_jump_to(pick):
				break
			Run.jump_to(pick.index)
			jumped += 1
		if Run.hellbender_destroyed():
			stamped += 1
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.eaten:
				eaten += 1
			if SystemLayout.hellbender_here(n):
				placed += 1
			if i < 6:
				if Router.at_hellbender(n):
					engage += 1
				var lines: Array = EncounterDrawer.quiet_lines(n)
				for l in lines:
					if _names_it(str(l)):
						drawer.append("%d: %s" % [n.index, l])
	var said := _log.filter(func(t: String) -> bool: return _names_it(t))
	h._ok("no run spawns it (%d of %d did)" % [spawned, seeds], spawned == 0)
	h._ok("200 party jumps a run move nothing (%d moved)" % moved, moved == 0)
	h._ok("no system is eaten (%d)" % eaten, eaten == 0)
	h._ok("no system has its body past the last orbit (%d)" % placed, placed == 0)
	h._ok("ENGAGE is nowhere (%d)" % engage, engage == 0)
	h._ok("no drawer line names it (%s)" % ("none" if drawer.is_empty() else "; ".join(drawer.slice(0, 3))), drawer.is_empty())
	h._ok("no log line names it over %d real jumps (%s)" % [jumped, "none" if said.is_empty() else "; ".join(said.slice(0, 3))],
		jumped > seeds and said.is_empty())
	h._ok("no WANTED poster is stamped DESTROYED (%d)" % stamped, stamped == 0)
	# and the posters read that, not "not alive"
	var src: String = (load("res://scripts/ui/PostingBoard.gd") as GDScript).source_code
	h._ok("PostingBoard stamps only a Hellbender that was there and died",
		src.count("if Run.hellbender_destroyed():\n\t\t_stamp(DEAD_STAMP") == 2
		and not src.contains("if not Run.hellbender_alive():"))


## Level 7: there, as it was, and the world around it the same.
func _level_seven(seeds: int) -> void:
	print("-- ascension 7, %d seeds" % seeds)
	var t: EnemyTemplate = DB.enemies[&"hellbender"]
	var missing := 0
	var wrong := 0
	var world_moved := 0
	var asc_off := 0
	var form_off := 0
	for i in seeds:
		# the same seed at the same tier with the Hellbender kept off (the sim's
		# control seam): the tier's galaxy form moves the world, and nothing else may
		Run.hellbender_off = true
		_start(1000 + i * 37, Run.HELLBENDER_ASCENSION)
		var w0 := _world()
		Run.hellbender_off = false
		_start(1000 + i * 37, Run.HELLBENDER_ASCENSION)
		if Run.ascension != Run.HELLBENDER_ASCENSION:
			asc_off += 1
		if Ladder.form_of_kind(Run.galaxy_kind) != Ladder.form(Run.HELLBENDER_ASCENSION):
			form_off += 1
		if not Run.hellbender_alive():
			missing += 1
			continue
		var n: MapGen.MapNode = Run.map[Run.hellbender_at]
		if Run.hellbender_max != t.max_hull or Run.hellbender_hp != t.max_hull \
				or n.layer < 3 or n.layer > MapGen.LAYERS - 3 or n.type == MapGen.NodeType.STATION \
				or not SystemLayout.hellbender_here(n):
			wrong += 1
		if _world() != w0:
			world_moved += 1
	h._ok("a run at ascension 7 is at 7 (%d were not)" % asc_off, asc_off == 0)
	h._ok("every run spawns it (%d of %d did not)" % [missing, seeds], missing == 0)
	h._ok("at its template hull %d, in the middle shells, never a station, its body placed (%d wrong)" % [t.max_hull, wrong], wrong == 0)
	h._ok("and the world is the one tier 7 rolls without it: its place moves nothing else (%d differ)" % world_moved, world_moved == 0)
	h._ok("its galaxy takes the tier's form, %s, as the ladder says (%d did not)" % [Ladder.form_name(Run.HELLBENDER_ASCENSION), form_off], form_off == 0)
	# the ladder's top is ten; past it reads ten
	Run.forced_ascension = 99
	h._ok("a level past the ladder reads its top (%d)" % Run.ascension_for_new_run(),
		Run.ascension_for_new_run() == Run.ASCENSION_MAX)
	Run.forced_ascension = -1
	h._ok("with nothing asked a new run is at 0 (%d)" % Run.ascension_for_new_run(),
		Run.ascension_for_new_run() == 0 or Array(OS.get_cmdline_user_args()).any(
			func(a: String) -> bool: return a.begins_with("asc=")))


func _world() -> String:
	var parts: Array = [Run.galaxy_kind, Run.galaxy_name, Run.map.size()]
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		parts.append("%d:%d:%d:%d" % [n.index, int(n.type), n.layer, n.options.size()])
	return str(parts)


## The hiring boards keep their Hellbender paper at every level (Jon's hint).
func _boards() -> void:
	var named := 0
	var tables: Array = [BoardScreen.ADS, BoardScreen.STRIPS, BoardScreen.POPUPS, BoardScreen.TICKER,
		BoardScreen.DECOYS, BoardWhite.MORE, BoardCork.POOL, PostingBoard.POSTS]
	for tb: Variant in tables:
		named += str(tb).to_upper().count("HELLBENDER")
	h._ok("the hiring boards still name it, as a hint (%d mentions)" % named, named > 0)


## A save from before the level loads at 0.
func _old_save() -> void:
	_start(4242, Run.HELLBENDER_ASCENSION)
	SaveGame.save()
	var f := FileAccess.open(SaveGame.path, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text()) if f != null else {}
	if f != null:
		f.close()
	h._ok("a save carries the level (%s)" % str(d.get("ascension", "none")), int(d.get("ascension", -1)) == Run.HELLBENDER_ASCENSION)
	d["version"] = 40
	d.erase("ascension")
	var w := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify(d))
		w.close()
	Run.ascension = 5
	var loaded := SaveGame.load_into_run()
	h._ok("a VERSION 40 save with no level loads (%s), at 0 (%d)" % [loaded, Run.ascension], loaded and Run.ascension == 0)
	SaveGame.clear()


## `-- fight foe=hellbender` at level 0: its template hull, not 1.
func _fight_at_zero() -> void:
	print("-- a Hellbender fight with no Hellbender in the run")
	_start(4242, 0)
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(n):
			idx = n.index
			break
	if idx < 0:
		h._fail("no system to fight in")
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	await _frames(4)
	Router.start_combat(DB.enemies[&"hellbender"], [], false, false)
	var opened := false
	for i in 900:
		await _tree.process_frame
		if Router.combat != null and not Router.combat.enemies.is_empty():
			opened = true
			break
	if not h._ok("its fight opens", opened):
		return
	var e: Combat.EnemyState = Router.combat.enemies[0]
	h._ok("at its template hull (%d of %d), not 1" % [e.hp, e.max_hp], e.hp == e.max_hp and e.hp > 1)
	Router.combat.damage_enemy(9999, 1, "test", e)
	for i in 1500:
		if Router.combat == null:
			break
		await _tree.process_frame
	await _frames(10)
	h._ok("and killing it leaves no Hellbender and no stamp (%d, %s)" % [Run.hellbender_at, Run.hellbender_destroyed()],
		Run.hellbender_at == -1 and not Run.hellbender_destroyed())
