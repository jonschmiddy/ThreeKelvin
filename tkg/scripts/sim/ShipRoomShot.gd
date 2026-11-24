extends Node

## The ship-select rooms as a player meets them, to lay beside the approved films:
## `room=korvan|solari|old at=0,5,10 out=<dir> [pick=medium] [film=S]`, with `--fixed-fps 30`
## so the room's clock steps as the films' did; needs a window (render.sh). docs/tests.md.

var _out := ""


func _ready() -> void:
	_out = Harness.arg("out", "user://shiproom")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run.call_deferred()


func _run() -> void:
	await Harness.frames(get_tree(), 2)
	if DevMode.available:
		DevMode.enabled = false
	var room := Harness.arg("room", "korvan")
	# Solari's casting bed needs Solari open: a won flight on the scratch record opens it
	if room == "solari":
		RunHistory.record(RunHistory.Outcome.WON, "ShipRoomShot")
	Router.new_run(4242)
	var cs: ChassisSelect = null
	for i in 600:
		cs = Router.current as ChassisSelect
		if cs != null and cs._yard != null and cs._yard.room != null:
			break
		await get_tree().process_frame
	if cs == null:
		print("shiproomshot: no hull pick")
		get_tree().quit(1)
		return
	cs._select(0 if room == "korvan" else 1)
	# no run has a hull yet, so the record above cannot open Solari: stand its set in its room
	if room == "solari" and cs._yard.room.id != &"solari":
		cs._yard.show_set(&"solari", true, 0)
	var pick := Harness.arg("pick", "")
	if pick != "":
		cs._pick_weight({"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM,
			"heavy": HullData.Weight.HEAVY}[pick])
	var y := cs._yard
	print("shiproomshot: %s room, %s set" % [y.room.id, y.manufacturer])
	for w: HullData.Weight in y.sets:
		var s: YardStandSet = y.sets[w]
		print("  %-6s thing %s posts %s top %d feet %d guns %s" % [HullData.weight_name(w), s.thing, s.post_x,
			s.post_top, s.feet, s.guns])
	var film := float(Harness.arg("film", "0"))
	if film > 0.0:
		var t0 := y.room.t
		while y.room.t - t0 < film:
			await get_tree().process_frame
		print("shiproomshot: filmed %.1f s" % film)
		get_tree().quit()
		return
	var ats: Array[float] = []
	for a in Harness.arg("at", "0,5,10").split(",", false):
		ats.append(float(a))
	ats.sort()
	for a in ats:
		while y.room.t < a:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_shot("%s_%05.1f" % [room, a])
	print("shiproomshot: done, %s" % _out)
	get_tree().quit()


func _shot(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("  wrote %s/%s.png (%dx%d)" % [_out, name, img.get_width(), img.get_height()])
