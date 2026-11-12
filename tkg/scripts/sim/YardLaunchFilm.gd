extends Node

## TRIAL FILM (not for landing): the front door's LAUNCH as a player meets it,
## from the press to LOCAL's first frames, every wait in game seconds.
##   render.sh --windowed --resolution 960x540 --fixed-fps 30 --write-movie <dir>/x.avi
##     -- sheet=YardLaunchFilm [manufacturer=korvan] [weight=medium] [yardlaunch=1|2|3] [plume=P1..P6] [after=S]
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
	var tree := get_tree()
	await tree.process_frame
	Router.animate_in_harness = true
	var mk := StringName(Harness.arg("manufacturer", "korvan"))
	var wt: HullData.Weight = {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM,
		"heavy": HullData.Weight.HEAVY}.get(Harness.arg("weight", "medium"), HullData.Weight.MEDIUM)
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
	var guard := 0.0
	while not (Router.current is SectorScreen) and guard < 15.0:
		guard += 1.0 / 30.0
		await tree.process_frame
	_mark("local")
	await _wait(float(Harness.arg("after", "1.0")))
	_mark("end")
	tree.quit()
