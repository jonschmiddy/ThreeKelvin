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
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("orbitclip="):
			await _orbit_clip((a as String).substr(10))
			get_tree().quit()
			return
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


## `orbitclip=<dir>`: ONE PLANET TO ANOTHER, filmed through the real Router (run
## with `--fixed-fps 30` so the frames play at true speed): in orbit of world A on
## the map, LOCAL by the HUD's tab, the map again, a flight to world B, LOCAL
## once. Every frame of the game's 960x540 view as `f_####.png`; then LOCAL's
## sky at B bare (ships and labels hidden) as `sky/f_####.png` for the flicker
## measure. Prints what LOCAL drew each time, the frame LOCAL first showed B on
## and that frame's brightness against a settled one (a dark first frame shows).
func _orbit_clip(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var idx := -1
	var ws: Array[int] = []
	for m: MapGen.MapNode in Run.map:
		if m.type != MapGen.NodeType.SYSTEM:
			continue
		var L := SystemLayout.of(m)
		var w: Array[int] = []
		for bi in L.bodies.size():
			if L.bodies[bi].world != &"":
				w.append(bi)
		if w.size() >= 2:
			idx = m.index
			ws = w
			break
	if idx < 0:
		print("  orbitclip: no system with two worlds")
		return
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	var a := ws[0]
	var b := ws[ws.size() - 1]
	var Lb := SystemLayout.of(Run.node_at())
	print("  orbitclip: system %d, A = %d %s, B = %d %s" % [idx, a, Lb.bodies[a].name, b, Lb.bodies[b].name])
	var gv := GameShell.input_target(get_tree())
	var k := [0]
	var rec := func(n: int) -> void:
		for i in n:
			await RenderingServer.frame_post_draw
			gv.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, k[0]])
			k[0] += 1
	var map := await _map_up()
	map.flight.place_at(a, map.view.t)
	map._was_at = map.flight.reached()
	map.select_body(a)
	await rec.call(45)
	Router.show_local()
	await rec.call(75)
	print("  orbitclip: LOCAL 1 draws %d (A %d)" % [_orbit_now(), a])
	map = await _map_up()
	await rec.call(30)
	map.frozen = false
	map.select_body(b)
	map.fly_to_body(b)
	var guard := 0
	while map.flight.reached() != b and guard < 900:
		await rec.call(1)
		guard += 1
	await rec.call(25)
	var first: int = k[0]
	Router.show_local()
	await rec.call(90)
	print("  orbitclip: LOCAL 2 draws %d (B %d) from frame %d" % [_orbit_now(), b, first])
	var means: Array[String] = []
	for j in [0, 1, 2, 3, 4, 5, 6, 8, 10, 60]:
		means.append("+%d %.4f" % [j, _mean(Image.load_from_file("%s/f_%04d.png" % [dir, first + j]))])
	print("  orbitclip: LOCAL 2's frames' mean brightness: %s" % ", ".join(means))
	# THE SKY BARE, for the flicker measure
	var sc := Router.current as SectorScreen
	if sc == null:
		return
	var view := sc._view
	var hid: Array[CanvasItem] = []
	for c in view.get_children():
		if c is CanvasItem and c != view.backdrop and c != view.weather and c != view.get("dust") and (c as CanvasItem).visible:
			(c as CanvasItem).visible = false
			hid.append(c)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var vr := view.get_global_rect()
	var arena := Rect2i(int(vr.position.x), int(vr.position.y), int(vr.size.x), 297)
	DirAccess.make_dir_recursive_absolute(dir + "/sky")
	for i in 61:
		await RenderingServer.frame_post_draw
		gv.get_texture().get_image().get_region(arena).save_png("%s/sky/f_%04d.png" % [dir, i])
	for c in hid:
		c.visible = true
	print("  orbitclip: %d frames, sky clip 61" % k[0])


func _map_up() -> SystemMapScreen:
	Router.show_system()
	for i in 240:
		await get_tree().process_frame
		var m := Router.current as SystemMapScreen
		if m != null and m.flight != null:
			m.frozen = true
			return m
	return null


func _orbit_now() -> int:
	var sc := Router.current as SectorScreen
	return sc._view.backdrop.orbit_target if sc != null else -99


func _mean(img: Image) -> float:
	if img == null:
		return -1.0
	var s := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			s += img.get_pixel(x, y).get_luminance()
			n += 1
	return s / maxf(n, 1.0)


func _shot(name: String, frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
