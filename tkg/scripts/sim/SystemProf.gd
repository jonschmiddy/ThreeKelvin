extends Node

## Where a frame of the system map goes: each layer switched off in turn.
##   godot --path . -- sheet=SystemProf
## VSYNC OFF AND NO CAP, from the first frame: with vsync on a windowed run
## reads 16.7 ms for every row and the differences between rows are nothing.
## (It set `max_fps = 0` only after the last row until Oct 27, where it did no
## good.) The line at the end says what the rows ran under in a windowed run;
## headless it always prints vsync=1, as the headless display server ignores
## the call and reports ENABLED whatever was set.
const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")

func _measure() -> float:
	for _i in 10:
		await get_tree().process_frame
	var t1 := Time.get_ticks_usec()
	for _i in 40:
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - t1) / 40000.0

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = Run.map[1]
	var view: Control = SystemViewS.new()
	add_child(view)
	view.t = 30.0
	await view.show_system(n)
	print("  all layers: %.1f ms" % await _measure())
	for name in ["_sky", "_twinkle", "_belts", "_shadows", "_palette", "_lines", "_worlds", "_moons"]:
		var c: CanvasItem = view.get(name)
		c.visible = false
		print("  without %s: %.1f ms" % [name, await _measure()])
		c.visible = true
	view.set_process(false)
	print("  no per-frame script: %.1f ms" % await _measure())
	view.visible = false
	print("  nothing drawn at all: %.1f ms" % await _measure())
	print("  max_fps=%d vsync=%d" % [Engine.max_fps, DisplayServer.window_get_vsync_mode()])
	get_tree().quit()
