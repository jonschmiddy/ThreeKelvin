extends Node

## The system map in the real shell, through the real router:
##   godot --path . -- sheet=FlowShot out=<dir> [seed=N]
## Starts a run and photographs where it lands, then jumps to the nearest
## system it can reach (through `Router.commit_jump`, the arrival path), then a
## beacon taken, then back from the ship screen. Needs a window.

var out := "user://flow"


func _ready() -> void:
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("out="):
			out = s.substr(4)
		elif s.begins_with("seed="):
			Rng.forced = int(s.substr(5))
	DirAccess.make_dir_recursive_absolute(out)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_sector()
	await _shot("1_start", 40)
	var to := -1
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != Run.at and Run.can_jump_to(m) and m.type == MapGen.NodeType.SYSTEM:
			to = m.index
			break
	print("  flowshot: start %d (%s), jumping to %d" % [Run.at, Router.current.get_script().resource_path.get_file(), to])
	if to >= 0:
		Router.commit_jump(to)
		await _shot("2_arrived", 20)
		await _shot("3_warped", 90)
		var v0 = Router.current.view
		print("  flowshot: view on screen at %s, viewport %s" % [v0.get_global_transform_with_canvas().origin, v0.get_viewport().get_visible_rect().size])
		var scr = Router.current
		if scr is SystemMapScreen:
			var hit := false
			for bi in scr.view.layout.bodies.size():
				for bc in scr.view.layout.bodies[bi].beacons:
					if not hit and bc.opt >= 0:
						hit = true
						scr.open_beacon(bi, bc)
			await get_tree().create_timer(1.6).timeout
			await _shot("4_beacon", 4)
	Router.show_local()
	await _shot("5_local", 60)
	Router.show_sector()
	await _shot("6_back", 30)
	print("  flowshot: done, at %s" % Router.current.get_script().resource_path.get_file())
	get_tree().quit()


func _shot(name: String, frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
