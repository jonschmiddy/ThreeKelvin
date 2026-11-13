extends Node

## The front door's LAUNCH as a player meets it (`ShipLift`), from the press to LOCAL's
## first frames, every wait in game seconds. `docs/tests.md` has the command line.
## Prints `mark <name> <frame>` (the AVI's frame) for the encoder's start.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta


func _wait(s: float) -> void:
	var end := _t + s
	while _t < end:
		await get_tree().process_frame


func _mark(name: String) -> void:
	print("mark %s %d %.3f" % [name, Engine.get_frames_drawn(), _t])


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# (`steam=heavy|heavier`: the lift's steam at that weight, `LiftPlume.WEIGHTS`)
	LiftPlume.weight = int({"heavy": 1, "heavier": 2}.get(Harness.arg("steam", ""), 0))
	var tree := get_tree()
	await tree.process_frame
	Router.animate_in_harness = true
	var mk := StringName(Harness.arg("manufacturer", "korvan"))
	var wt: HullData.Weight = {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM,
		"heavy": HullData.Weight.HEAVY}.get(Harness.arg("weight", "medium"), HullData.Weight.MEDIUM)
	# a manufacturer past Korvan: the win that opens it, in the harness's scratch record
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
	await _wait(0.5)
	cs._select(maxi(0, DB.STARTABLE.find(mk)))
	cs._pick_weight(wt)
	await _wait(float(Harness.arg("lead", "1.5")))
	_mark("launch")
	var pressed := false
	for b in cs.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.text.strip_edges() == "LAUNCH" and btn.is_visible_in_tree() and not btn.disabled:
			btn.pressed.emit()
			pressed = true
			break
	if not pressed:
		cs._launch()
	# `stills=<dir> at=0.5,1.5,2.1`: the lift held at each moment and photographed
	# with no smoke, then again with the hull hidden (the hull's mask), for mockups
	var stills := Harness.arg("stills", "")
	if stills != "":
		await _stills(cs, stills)
		tree.quit()
		return
	var guard := 0.0
	while not (Router.current is SectorScreen) and guard < 15.0:
		guard += 1.0 / 30.0
		await tree.process_frame
	_mark("local")
	await _wait(float(Harness.arg("after", "1.0")))
	_mark("end")
	tree.quit()


func _stills(cs: ChassisSelect, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var tree := get_tree()
	for at_s in Harness.arg("at", "0.5,1.5,2.1").split(","):
		var at := float(at_s)
		while cs._yard.lift == null or cs._yard._lift_t < at:
			await tree.process_frame
			if cs._yard.lift != null:
				cs._yard.lift.plume.visible = false
		Engine.time_scale = 0.0
		var view: ShipView = cs._yard.lift.view
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("%s/t%s.png" % [dir, at_s])
		view.visible = false
		await tree.process_frame
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("%s/t%s_nohull.png" % [dir, at_s])
		view.visible = true
		var o := cs._yard.lift.offset()
		var ink := cs._yard.lift._ink
		print("still %s lift %.3f hull ink %s offset %s floor %.0f jets %s" % [at_s, cs._yard._lift_t, ink, o, cs._yard.lift.floor_y,
			cs._yard.lift._jet_pts])
		Engine.time_scale = 1.0
