extends Node

## Waits are in game seconds, as the movie writer runs the clock at its own rate.
## Why: docs/why/RunStartFilm.md#run-start-film

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta


func _wait(s: float) -> void:
	var end := _t + s
	while _t < end:
		await get_tree().process_frame


func _mark(name: String) -> void:
	print("mark %s %d" % [name, Engine.get_frames_drawn()])


func _ready() -> void:
	_run.call_deferred()


func _press(root: Node, text: String) -> bool:
	for b in root.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.text.strip_edges() == text and btn.is_visible_in_tree() and not btn.disabled:
			btn.pressed.emit()
			return true
	return false


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Router.animate_in_harness = true
	var mk := StringName(Harness.arg("manufacturer", "solari"))
	var wt: HullData.Weight = {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM,
		"heavy": HullData.Weight.HEAVY}.get(Harness.arg("weight", "medium"), HullData.Weight.MEDIUM)
	# the win that unlocks it, in the scratch record
	var need := Unlocks.prereq(mk)
	if need != &"":
		var f := FileAccess.open(RunHistory.path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": RunHistory.VERSION, "runs": [
			{"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": String(need)}]}))
		f.close()
	Rng.forced = Harness.seed_arg(4242)
	Run.start_new_run(&"korvan", int(wt))
	Router.show_chassis_select()
	var cs := Router.current as ChassisSelect
	_mark("pick")
	await _wait(2.0)
	var i := DB.STARTABLE.find(mk)
	cs._select(i)
	cs._pick_weight(wt)
	print("runstartfilm: %s %s, unlocked %s" % [mk, Run.hull.name, Unlocks.unlocked(mk)])
	await _wait(4.0)
	_mark("launch")
	if not _press(cs, "LAUNCH"):
		cs.launched.emit()
	await _wait(6.0)
	_mark("local")
	# the next system, where something is waiting
	var here: MapGen.MapNode = Run.node_at()
	var to := -1
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != here.index and Run.can_jump_to(m) and not Router.no_fights_at(m) \
				and m.type == MapGen.NodeType.SYSTEM:
			to = m.index
			break
	if to < 0:
		print("runstartfilm: nowhere to jump")
		tree.quit()
		return
	var t: MapGen.MapNode = Run.map[to]
	OptionTable.ensure(t)
	t.ambush_rolled = true
	t.ambush_pending = true
	_mark("jump")
	Router.begin_jump(to)
	var guard := 0.0
	while Router.combat == null and guard < 20.0:
		guard += 1.0 / 30.0
		await tree.process_frame
	_mark("fight")
	# the arrival, then the band up and the hand dealt
	await _wait(9.0)
	# the manufacturer's own gun first (Ember Lance's Glowshot), fired once
	var cb: Combat = Router.combat
	if cb != null:
		var pick := -1
		for k in cb.hand.size():
			var c := cb.hand[k]
			if c.damage > 0 and cb.can_play(c) and (pick < 0 or c.manufacturer == mk):
				pick = k
		if pick >= 0:
			_mark("play")
			print("runstartfilm: plays %s" % cb.hand[pick].name)
			cb.play(pick, 0)
	await _wait(5.0)
	_mark("end")
	tree.quit()
