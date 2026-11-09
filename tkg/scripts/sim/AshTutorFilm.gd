extends Node

## Films A.S.H. teaching a first run (Jon's tutorial A, Oct 17) with her real clocks.
## Why: docs/why/AshTutorFilm.md#tutor-film

var _tree: SceneTree
var _f0 := 0
var _marks: Array = []


func _ready() -> void:
	_run.call_deferred()


func _secs() -> float:
	return float(Engine.get_frames_drawn() - _f0) / 30.0


func _wait(s: float) -> void:
	await _tree.create_timer(s).timeout


## Until she is saying line `lid`, then read it and click it away (a hint) or
## let it go on its own (a goal step). Marks it.
func _hear(lid: StringName, limit: float = 12.0) -> void:
	var t0 := GameClock.now()
	while not (Ash.lesson == lid and Ash.lesson_up()) and GameClock.now() - t0 < limit:
		await _tree.process_frame
	if Ash.lesson != lid:
		print("MISSING %s" % lid)
		return
	var p := Ash.portrait
	var m := {line = String(lid), words = p.line, start = _secs(), spot = String(Ash.said_log.back().spot)}
	print("mark %s %.2f" % [lid, m.start])
	var step := Ash.lesson_hint == &""
	while p.speaking() and p.phase != AshPortrait.Phase.HOLDING and GameClock.now() - t0 < limit + 20.0:
		await _tree.process_frame
	if step:
		while p.speaking() and GameClock.now() - t0 < limit + 30.0:
			await _tree.process_frame
	else:
		await _wait(AshPortrait.HOLD_MIN_S + AshPortrait.HOLD_PER_CHAR_S * float(p.line.length()))
		Hints.spend()
		await Harness.frames(_tree, 1)
	m["end"] = _secs()
	_marks.append(m)


func _seen_all_but(keep: Array) -> void:
	Hints.reset()
	for id in Hints.ORDER:
		if not keep.has(id):
			Hints.mark_seen(id)
	for id in Hints.STEP_LINES:
		if not keep.has(id):
			Hints.mark_seen(StringName("said_" + String(id)))
	# (the goal line's own steps stay pending, as on a first run: only her
	# lines for them are marked said)


func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not m.cleared and not Router.no_fights_at(m):
			Run.at = m.index
			m.visited = true
			SectorScreen._approached_at = m.index
			OptionTable.ensure(m)
			return m
	return null


func _plant_event(n: MapGen.MapNode) -> int:
	for o in OptionTable.all():
		if (o.get("choices", []) as Array).size() >= 2 and not (o.get("tags", []) as Array).has(&"fight") \
				and o.has("subject"):
			n.options.append(StringName(o.id))
			return n.options.size() - 1
	return -1


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	Hints.forced = true
	Rng.forced = Harness.seed_arg(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var seg := Harness.arg("segment", "jump")
	var n := _system()
	Ash.waiting.clear()
	match seg:
		"jump":
			_seen_all_but([&"chart", &"step_jump", &"step_jump_chart"])
			Run.jumps = 0
			Router.show_local()
			_f0 = Engine.get_frames_drawn()
			await _hear(&"step_jump")
			await _wait(0.8)
			Router.show_starchart()
			await _hear(&"chart")
			await _hear(&"step_jump_chart")
			await _wait(1.5)
		"chart":
			_seen_all_but([&"chart"])
			Run.jumps = 1
			Router.show_starchart()
			_f0 = Engine.get_frames_drawn()
			await _hear(&"chart")
			await _wait(1.5)
		"events":
			_seen_all_but([&"events", &"step_event_map"])
			Run.jumps = 1
			if n.options.is_empty():
				_plant_event(n)
			Router.show_system()
			_f0 = Engine.get_frames_drawn()
			# (a hint due on a screen comes before the step's line there)
			await _hear(&"events")
			await _hear(&"step_event_map")
			await _wait(1.5)
		"drawer":
			_seen_all_but([&"drawer"])
			Run.jumps = 1
			var pe := _plant_event(n)
			Router.show_local()
			_f0 = Engine.get_frames_drawn()
			await _wait(1.5)
			var sc := Router.current as SectorScreen
			sc._events.open(pe)
			await _hear(&"drawer", 20.0)
			await _wait(1.5)
		"fight":
			_seen_all_but([&"hand", &"intent", &"endturn", &"heat"])
			Run.jumps = 1
			Router.show_local()
			await _wait(1.0)
			Run.heat = 0
			Router.start_combat(DB.enemies[&"cutter"], [], false, false)
			_f0 = Engine.get_frames_drawn()
			var cb: Combat = Router.combat
			for e in cb.enemies:
				(e as Combat.EnemyState).max_hp = 999
				(e as Combat.EnemyState).hp = 999
			await _hear(&"hand", 15.0)
			await _play_one(cb)
			await _hear(&"intent")
			while await _play_one(cb):
				pass
			await _hear(&"endturn")
			var fs := Router.current as SectorScreen
			fs._on_end_turn()
			for i in 900:
				await _tree.process_frame
				if not fs._hold and not fs._opening and fs._end_button.is_visible_in_tree() and not fs._end_button.disabled:
					break
			if Run.heat <= 0:
				Run.heat = 2
			await _hear(&"heat")
			await _wait(1.5)
		"wreck":
			_seen_all_but([&"wreck", &"salvage"])
			Run.jumps = 1
			var w := Run.new_wreck(n, DB.enemies[&"cutter"])
			w.items.append(CreditChit.of(40))
			Router.show_local()
			_f0 = Engine.get_frames_drawn()
			await _hear(&"wreck", 15.0)
			var sc := Router.current as SectorScreen
			sc._open_jetsam(w)
			await _hear(&"salvage")
			await _wait(1.0)
			sc._close_transfer()
			await _wait(1.0)
		"dock":
			_seen_all_but([&"dock"])
			Run.jumps = 1
			for raw in Run.map:
				var m: MapGen.MapNode = raw
				if m.type == MapGen.NodeType.STATION:
					Run.at = m.index
					m.visited = true
					break
			Router.show_station()
			_f0 = Engine.get_frames_drawn()
			await _hear(&"dock", 20.0)
			await _wait(1.5)
	var out := Harness.arg("out", "")
	if out != "":
		var f := FileAccess.open(out.path_join("marks.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({segment = seg, start_frame = _f0, marks = _marks}, "  "))
		f.close()
	print("film done %s %.2f" % [seg, _secs()])
	Hints.forced = false
	Ash.forced = false
	_tree.quit()


func _play_one(cb: Combat) -> bool:
	for i in cb.hand.size():
		var c: CardData = cb.hand[i]
		if cb.can_play(c):
			cb.play(i, 0)
			await _wait(0.8)
			return true
	return false
