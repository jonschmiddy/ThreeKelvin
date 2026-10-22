extends Node

## THE FUEL READOUT AND THE FUEL HINT, as the game draws them:
##   godot --path . --windowed --resolution 1920x1080 -- sheet=FuelShot hints out=<dir>
##
## LOCAL at a system with a dock in reach, the tank at full, a third and near
## empty (`hud_full`, `hud_third`, `hud_near_empty`: the whole window, and a 4x
## crop of the readout beside each), then the fuel hint on LOCAL and on the
## chart (`hint_local`, `hint_chart`), each `HINT_S` after it shows. Every other
## hint is marked seen first, so nothing else comes up. Needs a window.

const HINT_S := 0.6

var _out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	if _out == "":
		_out = "user://fuelshot"
	_run.call_deferred()


func _secs(t: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(t * 1000.0):
		await RenderingServer.frame_post_draw


func _shot(name: String, crop: bool = false) -> void:
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("  fuelshot: %s.png  fuel %d/%d, readout %s" % [name, Run.fuel, Run.fuel_cap(), Router.hud.fuel_rect()])
	if crop:
		# the readout and its neighbours, in window pixels (the picture is drawn
		# at 2x into the 1080p window), blown up 4x more for reading
		var k := float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var r := Router.hud.fuel_rect().grow(6.0)
		r.position.x -= 90.0
		r.size.x += 90.0
		var px := Rect2i(Vector2i(r.position * k), Vector2i(r.size * k)).intersection(
			Rect2i(Vector2i.ZERO, img.get_size()))
		var c := img.get_region(px)
		c.resize(c.get_width() * 4, c.get_height() * 4, Image.INTERPOLATE_NEAREST)
		c.save_png("%s/%s_crop.png" % [_out, name])


func _hint(name: String) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		await RenderingServer.frame_post_draw
		if Hints.card != null and is_instance_valid(Hints.card) and Hints.card.id == &"fuel":
			await _secs(HINT_S)
			_shot(name)
			print("  fuelshot: %s reads \"%s\" / \"%s\"" % [name, Hints.lines(&"fuel")[0], Hints.fuel_dock_line()])
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			Hints.spend()
			await _secs(Hints.GAP_S + 0.3)
			return
	print("  [fuelshot] MISSING %s" % name)


func _run() -> void:
	var tree := get_tree()
	DirAccess.make_dir_recursive_absolute(_out)
	await tree.process_frame
	Hints.reset()
	for id in Hints.ORDER:
		Hints.mark_seen(id)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# a system with a dock in sight, so the hint has one to name
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		Run.at = m.index
		Run.chart_from(m)
		var dock := false
		for t in Run.in_range():
			if (t as MapGen.MapNode).sensed and (t as MapGen.MapNode).type == MapGen.NodeType.STATION:
				dock = true
		if dock:
			m.visited = true
			SectorScreen._approached_at = m.index
			OptionTable.ensure(m)
			break
	Run.jumps = 1
	Router.show_local()
	await _secs(9.0)
	for pair in [[45, "hud_full"], [15, "hud_third"], [3, "hud_near_empty"]]:
		Run.fuel = pair[0]
		Router.hud.refresh()
		await _secs(0.8)
		_shot(pair[1], true)
	# the hint, on LOCAL and on the chart
	Hints.mark_seen(&"fuel", false)
	Run.fuel = 15
	Router.hud.refresh()
	await _hint("hint_local")
	Hints.mark_seen(&"fuel", false)
	Router.show_starchart()
	await _secs(2.5)
	await _hint("hint_chart")
	Hints.reset()
	tree.quit()
