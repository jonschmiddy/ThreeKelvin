extends Node

## The system map's picture for real systems of a real run, one PNG each:
##   godot --path . -- sheet=SystemSheet out=<dir> [seed=N] [systime=S]
## A red giant, an ordinary sun, a blue giant, a station, a system in a nebula,
## a pulsar and the core, as `SystemLayout` lays them out and `SystemView`
## draws them. Needs a window.

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")

func _ready() -> void:
	var out := "user://systems"
	var t := 30.0
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("out="):
			out = s.substr(4)
		elif s.begins_with("seed="):
			Rng.forced = int(s.substr(5))
		elif s.begins_with("systime="):
			t = float(s.substr(8))
	DirAccess.make_dir_recursive_absolute(out)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var want := {"red": null, "ordinary": null, "blue": null, "station": null, "nebula": null, "pulsar": null, "core": null}
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.PULSAR and want.pulsar == null:
			want.pulsar = n
		elif n.type == MapGen.NodeType.CORE:
			want.core = n
		elif n.type == MapGen.NodeType.STATION and want.station == null:
			want.station = n
		elif n.type == MapGen.NodeType.SYSTEM:
			if n.in_nebula and want.nebula == null:
				want.nebula = n
			elif n.star == MapGen.Star.RED and n.gas_giant and want.red == null:
				want.red = n
			elif n.star == MapGen.Star.BLUE and want.blue == null:
				want.blue = n
			elif n.star == MapGen.Star.ORDINARY and want.ordinary == null and n.options.size() >= 2:
				want.ordinary = n
	var view: Control = SystemViewS.new()
	add_child(view)
	for key in want:
		var n: MapGen.MapNode = want[key]
		if n == null:
			continue
		view.t = t
		var t0 := Time.get_ticks_msec()
		await view.show_system(n)
		view.t = t
		for _i in 12:
			await get_tree().process_frame
		var t1 := Time.get_ticks_usec()
		for _i in 30:
			await get_tree().process_frame
		var per := float(Time.get_ticks_usec() - t1) / 30000.0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, key])
		print("  systemsheet: %s (system %d, %d bodies) baked in %d ms, %.1f ms a frame" % [key, n.index, view.layout.bodies.size(), Time.get_ticks_msec() - t0, per])
	get_tree().quit()
