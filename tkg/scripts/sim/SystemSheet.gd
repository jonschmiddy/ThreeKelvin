extends Node

## The system map's picture for real systems of a real run, one PNG each:
##   godot --path . -- sheet=SystemSheet out=<dir> [seed=N] [systime=S]
## A red giant, an ordinary sun, a blue giant, a station, a system in a nebula,
## a pulsar and the core, as `SystemLayout` lays them out and `SystemView`
## draws them. Needs a window.
##
## THE ZOOM SWEEP, through the real map screen (`SystemMapScreen`, the overlay,
## the orbits and the labels as play shows them):
##   godot --path . -- sheet=SystemSheet sweep=<dir> [style=...] [kinds=red,nebula,...]
##     [zframes=120] [oframes=90] [pframes=60] [only=stills,zoom,zoomw,orbit,pan]
## For each system kind, in `<dir>/<kind>/`:
##   `z<k>.png`      stills at zooms from the whole system to the closest the
##                   wheel reaches (`ZOOM_MAX`), and past both ends as the zoom
##                   ladder carries the map (`l_out.png`, `l_in.png`), centred
##                   on the star; `w<k>.png` held on the system's biggest world
##   `zoom/`         a slow zoom from the whole system to ZOOM_MAX, about the
##                   star, every zoom between (the wheel's ease passes through
##                   them all), the clock stopped: only the camera moves
##   `zoomw/`        the same held on the biggest world (as LOCATION holds it)
##   `orbit/`        in orbit of that world at zoom 3.2, the clock (and the
##                   gas's) running a 30th of a second a frame
##   `pan/`          a slow pan at zoom 2.5, the clock stopped
##   `slow<k>/`      a tenth more zoom over 60 frames at the whole system, 1, 2
##                   and 3.6 about the star (0-3) and 2.5 about the world (4):
##                   the project's flicker measure (flip-back under 0.0035)
## Each clip folder has `f_NNNN.png` (the map window, game pixels) and
## `meta.json`; `times.json` holds each still's frame time (ms, real clock).
## The weather and the far supernovae are held off and the room's sound is
## stopped, so two builds' clips differ only by what they draw.

const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")
const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")

func _ready() -> void:
	var out := "user://systems"
	var t := 30.0
	var sweep := ""
	Rng.forced = 4242
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("out="):
			out = s.substr(4)
		elif s.begins_with("seed="):
			Rng.forced = int(s.substr(5))
		elif s.begins_with("systime="):
			t = float(s.substr(8))
		elif s.begins_with("sweep="):
			sweep = s.substr(6)
	if sweep == "":
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
			elif n.star == MapGen.Star.ORDINARY and want.ordinary == null and _busy(n):
				want.ordinary = n
	if sweep != "":
		await _sweep(want, sweep, t)
		get_tree().quit()
		return
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


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with(name + "="):
			return (a as String).substr(name.length() + 1)
	return fallback


## The map window as it is on screen now, in game pixels.
func _grab(scr: Control) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var w: Rect2 = scr.view.window
	var o: Vector2 = scr._box.get_global_transform_with_canvas().origin
	return img.get_region(Rect2i(Vector2i(o + w.position), Vector2i(w.size)))


## The camera at zoom z, looking at body `wi`'s place (-9: the star).
func _aim(scr: Control, z: float, wi: int) -> void:
	scr._zoom_to = z
	scr.view.zoom = z
	scr.view.pan = -scr.overlay.place_rel(wi) if wi >= 0 else Vector2.ZERO


## Frames drawn at the camera as it is, and how long each took (ms, real clock).
func _settle(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for _i in n:
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)


## The frame's cost at the camera as it is, over n frames (the real clock is held
## to the display's rate, so it is measured as work): the map's own place
## picture on the GPU, the whole window on the GPU, and the CPU's process time.
func _cost(scr: Control, n: int) -> Dictionary:
	var rid: RID = scr.view._scene.get_viewport_rid()
	var root := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	RenderingServer.viewport_set_measure_render_time(root, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var g := 0.0
	var gr := 0.0
	var cpu := 0.0
	for _i in n:
		await RenderingServer.frame_post_draw
		g += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		gr += RenderingServer.viewport_get_measured_render_time_gpu(root)
		cpu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return {"scene_gpu": snappedf(g / n, 0.01), "window_gpu": snappedf(gr / n, 0.01), "cpu": snappedf(cpu / n, 0.01)}


func _sweep(want: Dictionary, dir: String, t: float) -> void:
	var kinds := _arg("kinds", "red,ordinary,blue,station,nebula,pulsar,core").split(",")
	var zf := int(_arg("zframes", "120"))
	var of := int(_arg("oframes", "90"))
	var pf := int(_arg("pframes", "60"))
	var only := _arg("only", "stills,zoom,zoomw,slow,orbit,pan").split(",")
	get_viewport().gui_disable_input = true
	# where Main puts the map, in Main's theme (as SystemShot does)
	var content := Control.new()
	var main := get_parent() as Control
	content.theme = main.theme if main != null and main.theme != null else UITheme.build()
	content.position = Vector2(8, 32)
	content.size = Vector2(944, 501)
	add_child(content)
	var scr: Control = ScreenS.new()
	content.add_child(scr)
	scr.frozen = true
	Audio.room(&"", 0.01)
	var times := {}
	for key: String in kinds:
		var n: MapGen.MapNode = want.get(key)
		if n == null:
			print("  systemsheet: sweep: no %s system in this run" % key)
			continue
		Run.at = n.index
		OptionTable.ensure(n)
		var kd := dir.path_join(key)
		DirAccess.make_dir_recursive_absolute(kd)
		scr.view.hclock = 1000.0
		var tb := Time.get_ticks_msec()
		await scr.show_system(n, t)
		var bake_ms := Time.get_ticks_msec() - tb
		scr.frozen = true
		scr._location_on = false
		scr.overlay.ship_park = 0
		scr._was_at = scr.flight.reached()
		scr.panel.show_system()
		if scr.view._weather != null:
			scr.view._weather.auto = false
		if scr.view._nova != null:
			scr.view._nova.auto = false
		# the palette found at the opening zoom, as the game finds it
		while not scr.view._palette_built:
			await get_tree().process_frame
		await _settle(4)
		_hide(scr)
		var zmin: float = scr.zoom_min
		var zmax: float = scr.view.ZOOM_MAX
		# the biggest world: a giant if there is one
		var wi := -9
		var best := -1.0
		for i: int in scr.view._views:
			var b: SystemLayout.Body = scr.view.layout.bodies[i]
			var sc := b.r + (100.0 if b.kind == &"giant" else 0.0)
			if sc > best:
				best = sc
				wi = i
		var tk := {"bake_ms": bake_ms, "zmin": zmin, "node": n.index, "world": wi, "stills": {}}
		if "stills" in only:
			var zs: Array = []
			for k in 7:
				zs.append(zmin * pow(zmax / zmin, float(k) / 6.0))
			var names: Array = []
			for k in 7:
				names.append("z%d" % k)
			zs.append(zmin * 0.55)
			names.append("l_out")
			zs.append(6.5)
			names.append("l_in")
			for k in zs.size():
				_aim(scr, zs[k], -9)
				await _settle(14)
				var ms := await _cost(scr, 20)
				(await _grab(scr)).save_png(kd.path_join("%s.png" % names[k]))
				ms["zoom"] = snappedf(zs[k], 0.001)
				tk.stills[names[k]] = ms
			if wi >= 0:
				var wz := [1.6, 2.6, zmax]
				for k in wz.size():
					_aim(scr, wz[k], wi)
					await _settle(14)
					var ms2 := await _cost(scr, 20)
					(await _grab(scr)).save_png(kd.path_join("w%d.png" % k))
					ms2["zoom"] = wz[k]
					tk.stills["w%d" % k] = ms2
		for clip: String in ["zoom", "zoomw"]:
			if not clip in only or (clip == "zoomw" and wi < 0):
				continue
			var cd := kd.path_join(clip)
			DirAccess.make_dir_recursive_absolute(cd)
			var rows: Array = []
			var tw: int = wi if clip == "zoomw" else -9
			_aim(scr, zmin, tw)
			await _settle(14)
			var tc := Time.get_ticks_usec()
			for k in zf + 1:
				var z := zmin * pow(zmax / zmin, float(k) / float(zf))
				_aim(scr, z, tw)
				var img := await _grab(scr)
				img.save_png(cd.path_join("f_%04d.png" % k))
				var now := Time.get_ticks_usec()
				rows.append({"zoom": z, "pan": [scr.view.pan.x, scr.view.pan.y], "ms": snappedf(float(now - tc) / 1000.0, 0.01)})
				tc = now
			_write(cd.path_join("meta.json"), rows)
		# THE SLOW ZOOMS (the project's flicker measure: a tenth more zoom over 60
		# frames, frames.py's flip-back under 0.0035): at four depths about the star,
		# and about the biggest world close in
		if "slow" in only:
			var bases := [[zmin, -9], [1.0, -9], [2.0, -9], [3.6, -9], [2.5, wi]]
			for si in bases.size():
				var zb: float = bases[si][0]
				var sw: int = bases[si][1]
				if sw == -9 and si == 4:
					continue
				var sd := kd.path_join("slow%d" % si)
				DirAccess.make_dir_recursive_absolute(sd)
				_aim(scr, zb, sw)
				await _settle(14)
				for k in 61:
					_aim(scr, zb * pow(1.1, float(k) / 60.0), sw)
					(await _grab(scr)).save_png(sd.path_join("f_%04d.png" % k))
		if "orbit" in only and wi >= 0:
			var od := kd.path_join("orbit")
			DirAccess.make_dir_recursive_absolute(od)
			scr.overlay.ship_park = wi
			scr._was_at = scr.flight.reached()
			var oz := 3.2
			var t_open: float = scr.view.t
			var h_open: float = scr.view.hclock
			_aim(scr, oz, wi)
			await _settle(14)
			var rows2: Array = []
			for k in of:
				scr.view.t = t_open + float(k) / 30.0
				scr.view.hclock = h_open + float(k) / 30.0
				_aim(scr, oz, wi)
				(await _grab(scr)).save_png(od.path_join("f_%04d.png" % k))
				rows2.append({"t": scr.view.t})
			_write(od.path_join("meta.json"), rows2)
			scr.view.t = t_open
			scr.view.hclock = h_open
			scr.overlay.ship_park = 0
		if "pan" in only:
			var pd := kd.path_join("pan")
			DirAccess.make_dir_recursive_absolute(pd)
			var pz := 2.5
			var reach := 220.0
			var rows3: Array = []
			for k in pf + 1:
				var u := float(k) / float(pf)
				scr._zoom_to = pz
				scr.view.zoom = pz
				scr.view.pan = Vector2(lerpf(reach, -reach, u), lerpf(reach * 0.2, -reach * 0.2, u))
				if k == 0:
					await _settle(14)
				(await _grab(scr)).save_png(pd.path_join("f_%04d.png" % k))
				rows3.append({"pan": [scr.view.pan.x, scr.view.pan.y]})
			_write(pd.path_join("meta.json"), rows3)
		times[key] = tk
		print("  systemsheet: sweep %s (system %d) baked in %d ms, zoom %.3f..%.1f, world %d" % [key, n.index, bake_ms, zmin, zmax, wi])
	_write(dir.path_join("times.json"), times)


func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " "))
	f.close()


## A system with at least two events (its options rolled first: a fresh run has
## not rolled them, and an ordinary sun was never found).
func _busy(n: MapGen.MapNode) -> bool:
	OptionTable.ensure(n)
	return n.options.size() >= 2


## `hide=a,b,...`: layers switched off, to find which one draws a fault -- depth
## (the dust sheets), neb (the cloud), sky, veil, fields, twinkle, galaxies,
## belts, belt_dust, shadows, star, worlds, fabric, lines, moons, palette, overlay.
func _hide(scr: Control) -> void:
	var names := _arg("hide", "")
	if names == "":
		return
	var v = scr.view
	for nm in names.split(","):
		var hit: Array = []
		match nm:
			"depth":
				for e: Array in v._depth:
					for c in v._scene.get_children():
						if c is CanvasItem and (c as CanvasItem).material == e[0]:
							hit.append(c)
			"neb":
				for c in v._scene.get_children():
					if c is CanvasItem and v._neb_mat != null and (c as CanvasItem).material == v._neb_mat:
						hit.append(c)
			"fields":
				hit = v._fields
			"overlay":
				hit = [scr.overlay]
			"star":
				hit = [v.star]
			_:
				var n = v.get("_" + nm)
				if n is CanvasItem:
					hit = [n]
		for c in hit:
			(c as CanvasItem).visible = false
		print("  systemsheet: hid %s (%d)" % [nm, hit.size()])
