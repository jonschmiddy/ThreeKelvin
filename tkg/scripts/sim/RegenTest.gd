extends Node

## The chart's REGENERATE GALAXY button (developer mode), pressed:
##   godot --path . -- sheet=RegenTest [out=<png>]
## Opens the star chart on a run, presses the button, and checks that a new
## galaxy came of it -- a new seed, a map a new run would have (its start at 0,
## its indices and links in range, its core present), the ship at the start with
## its hull, credits and cargo kept, no contract left naming the old map -- and
## that the chart was made again on the new galaxy, its sky baked for it.
## Prints `regentest: PASS` or each failure. Needs a window (the chart bakes).
## The button autosaves, so the run save on this machine is kept aside first
## and put back after.

var _fails: Array[String] = []


func _ok(what: String, good: bool) -> void:
	print("  %s  %s" % ["ok  " if good else "FAIL", what])
	if not good:
		_fails.append(what)


func _ready() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("out="):
			out = (a as String).substr(4)
	get_viewport().gui_disable_input = true
	_keep_save()
	Rng.forced = 4242
	DevMode.enabled = true
	Run.start_new_run(&"korvan", 1)
	Router.show_starchart()
	await _wait(2.5)
	var scr := Router.current as StarchartScreen
	_ok("the chart is open", scr != null)
	if scr == null:
		_verdict()
		return
	scr.dismiss_primer()
	var old_seed := Run.galaxy_seed
	var hull := Run.hull
	var credits := Run.credits
	var cargo := Run.cargo.size()
	var old_screen := scr
	scr._on_regenerate()
	await _wait(3.0)
	_ok("a new galaxy seed", Run.galaxy_seed != old_seed and Run.galaxy_seed != 0)
	_ok("a map", Run.map.size() > 10)
	var good := true
	var has_core := false
	for i in Run.map.size():
		var n: MapGen.MapNode = Run.map[i]
		if n.index != i:
			good = false
		for l in n.links:
			if l < 0 or l >= Run.map.size():
				good = false
		if n.type == MapGen.NodeType.CORE:
			has_core = true
	_ok("its systems numbered in order, their links in range", good)
	_ok("its core", has_core)
	_ok("the ship at its start", Run.at == 0 and (Run.map[0] as MapGen.MapNode).type == MapGen.NodeType.START)
	_ok("the trail begun again", Run.trail.size() == 1 and Run.trail[0] == 0)
	_ok("the hull, credits and cargo kept", Run.hull == hull and Run.credits == credits and Run.cargo.size() == cargo)
	_ok("no contract naming the old map", Run.contracts.is_empty())
	var now := Router.current as StarchartScreen
	_ok("the chart made again", now != null and now != old_screen)
	if now != null:
		var sky: ChartSky = now._chart._sky
		_ok("its sky baked for the new galaxy", sky != null and sky._key.begins_with(ChartSky.galaxy_key()))
	if out != "":
		# (the new galaxy opens on its first-survey card, as any new galaxy
		# does; put away for the picture, and the screen let fade in)
		if now != null:
			now.dismiss_primer()
		await _wait(2.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
	_verdict()


func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await get_tree().process_frame


## The run save as it was, kept aside and put back.
var _kept: PackedByteArray = PackedByteArray()
var _had_save := false


func _keep_save() -> void:
	_had_save = FileAccess.file_exists(SaveGame.PATH)
	if _had_save:
		_kept = FileAccess.get_file_as_bytes(SaveGame.PATH)


func _restore_save() -> void:
	if _had_save:
		var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_kept)
			f.close()
	elif FileAccess.file_exists(SaveGame.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.PATH))


func _verdict() -> void:
	_restore_save()
	if _fails.is_empty():
		print("regentest: PASS")
	else:
		print("regentest: %d FAILURES" % _fails.size())
	get_tree().quit()
