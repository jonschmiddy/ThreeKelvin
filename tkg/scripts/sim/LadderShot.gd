extends Node

## THE ZOOM LADDER'S MOVES, filmed (`ZoomLadder`):
##   godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=LadderShot
##       keepwindow flow=c out=<dir> [seed=N] [seams=1,2,3] [designs=A,B,C] [style=...]
##       [side=<StationSides id>] [interior=<id>|none] [weight=light|medium|heavy] [fit=full]
## For each design of each seam asked for, the move both ways through the
## Router's own doors -- chart <-> map, map <-> LOCAL (in orbit of a world, so the
## world handoff has its world), LOCAL <-> station (DOCK on LOCAL's bar, UNDOCK)
## -- every frame of the game's 960x540 picture saved as
## <dir>/<seam><design>_<in|out>/f_####.png, from a few frames before the call to
## a few after the move. The ladder's clock steps 1/30 s a frame, and with
## `--fixed-fps 30` so does the game's, so the frames play at true speed at
## 30 fps however slowly the window drew. Prints, per clip, the frame the screens
## changed hands on (`swap`). Needs a window.
##
## `designs=picks` films each seam's default (Jon's picks: 1A, 2C, 3B) instead of
## every letter. `post=N` keeps filming N frames after the move ends (default 8),
## so the UI that arrives after it is on the film. `go` films GO on an event from
## the map (`2C_go`, the ship already in orbit where it stands). `dive` films the
## moves two distances long that Tab makes: the chart to LOCAL (`dive_chart_local`),
## and docked, the berth to the map (`dive_station_map`) and the chart back to the
## berth (`dive_chart_station`). `timing` writes no pictures: it logs every real
## frame's length (run it WITHOUT --fixed-fps).

const SVP := preload("res://scripts/ui/sysmap/SystemView.gd")
var _tree: SceneTree
var _out := ""
var _args: PackedStringArray


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


var _pre_us := 0
## (stamped by two nodes that process first and last of all: what part of a
## frame's process is the nodes' own, and what comes after them)
var _first_us := 0
var _last_us := 0


class _Stamp extends Node:
	var on_tick: Callable
	func _process(_d: float) -> void:
		on_tick.call()


var _post_us := 0
var _draws := 0


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	RenderingServer.frame_pre_draw.connect(func() -> void: _pre_us = Time.get_ticks_usec())
	for first in [true, false]:
		var st := _Stamp.new()
		st.process_priority = -1000000 if first else 1000000
		st.process_mode = Node.PROCESS_MODE_ALWAYS
		st.on_tick = (func() -> void: _first_us = Time.get_ticks_usec()) if first else (func() -> void: _last_us = Time.get_ticks_usec())
		add_child(st)
	RenderingServer.frame_post_draw.connect(func() -> void:
		_post_us = Time.get_ticks_usec()
		_draws += 1)
	_run.call_deferred()


func _img() -> Image:
	return GameShell.input_target(_tree).get_texture().get_image()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


## The next frame a player sees. `frame_post_draw` also fires for the draws a
## screen forces while it finishes itself (LOCAL's sky primes in up to 48 of them,
## never presented), so one picture per process frame.
## (read at the top of the next frame: what the last frame finally drew, after
## any draws it forced while building itself -- those are never shown, and the
## first draw of a frame is often one of them)
func _shown() -> void:
	await _tree.process_frame


## Film `call` into <out>/<name>: `pre` frames before it, until the ladder is idle,
## then `post` more.
func _film(name: String, call: Callable, pre: int = 6, post: int = -1) -> void:
	if post < 0:
		post = int(_arg("post", "8"))
	var d := "%s/%s" % [_out, name]
	DirAccess.make_dir_recursive_absolute(d)
	var k := 0
	for i in pre:
		await _shown()
		_img().save_png("%s/f_%04d.png" % [d, k])
		k += 1
	var was := Router.current
	# (the click's own frame counted too: from just before the call)
	var t_last := Time.get_ticks_usec()
	call.call()
	var swap := -1
	var anchor := Vector2(480, 270)
	var after := -1
	var track: Array = []
	var timing := "timing" in _args
	var t_prev := t_last
	var worst := 0.0
	var worst_at := -1
	# (real time runs at hundreds of frames a second: room for the whole move)
	for i in (6000 if timing else 600):
		await _shown()
		var wn := _world_now(k)
		# (at a station: your ship's ink on the station's plate, plate px, and its
		# scale -- the dock's fit to the hallway, read off every frame)
		var lc := Router.current as SectorScreen
		if lc != null and lc._face != null and is_instance_valid(lc._face) and lc._view != null:
			var art := lc._view.ship_view()
			if art != null and art.visible:
				var ink := Rect2(art.ink_rect())
				var to_plate := lc._face.get_global_transform().affine_inverse()
				var a := to_plate * (art.get_global_transform() * art.canvas_to_local(ink.position)) - lc._face.origin()
				var b := to_plate * (art.get_global_transform() * art.canvas_to_local(ink.end)) - lc._face.origin()
				var r := Rect2(a, b - a).abs()
				wn["plate"] = [r.position.x, r.position.y, r.size.x, r.size.y]
				# (and all of it, every part bolted on)
				var fg := art.fitted_rect_global()
				var fa := to_plate * fg.position - lc._face.origin()
				var fb := to_plate * fg.end - lc._face.origin()
				wn["fitted"] = [fa.x, fa.y, fb.x - fa.x, fb.y - fa.y]
				wn["scale"] = art.scale.x
		if timing:
			var now := Time.get_ticks_usec()
			var ms := (now - t_last) / 1000.0
			t_last = now
			if ms > worst:
				worst = ms
				worst_at = k
			wn["ms"] = ms
			# (the frame's draw, on its own: from the render starting to it done)
			wn["draw_ms"] = (_post_us - _pre_us) / 1000.0 if _post_us > _pre_us else -1.0
			# (the frame in three: its process up to the draw, the draw, and from
			# the draw to this frame's start -- buffer swap, waits, deletions)
			wn["proc_ms"] = (_pre_us - t_prev) / 1000.0
			# (signal to first node: whatever runs on process_frame; first to last:
			# the nodes' own _process; last to the draw: deferred calls, layout,
			# timers, tweens, deletions)
			wn["sig_ms"] = (_first_us - t_prev) / 1000.0
			wn["nodes_ms"] = (_last_us - _first_us) / 1000.0
			wn["tail_ms"] = (_pre_us - _last_us) / 1000.0
			wn["after_ms"] = (now - _post_us) / 1000.0
			wn["draws"] = _draws
			wn["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			wn["objs"] = Performance.get_monitor(Performance.OBJECT_COUNT)
			wn["mem_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
			wn["vmem_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
			_draws = 0
			t_prev = now
			for kk: String in SVP.prof:
				ZoomLadder.probe["sv:" + kk] = SVP.prof[kk]
			SVP.prof.clear()
			if not ZoomLadder.probe.is_empty():
				wn["probe"] = ZoomLadder.probe.duplicate()
				ZoomLadder.probe.clear()
		else:
			_img().save_png("%s/f_%04d.png" % [d, k])
		track.append(wn)
		if swap < 0 and Router.current != was:
			swap = k
			if ZoomLadder.busy():
				anchor = ZoomLadder.active._a_old
		k += 1
		if after < 0 and not ZoomLadder.busy():
			after = post
		if after >= 0:
			after -= 1
			if after <= 0:
				break
	var mf := FileAccess.open("%s/meta.json" % d, FileAccess.WRITE)
	mf.store_string(JSON.stringify({"frames": k, "swap": swap, "ax": anchor.x, "ay": anchor.y, "track": track}))
	mf.close()
	if timing:
		print("  [ladder] %s: longest real frame %.1f ms at frame %d (swap %d)" % [name, worst, worst_at, swap])
	print("  [ladder] %s: %d frames, swap at %d, on %s" % [name, k, swap,
		Router.current.get_script().get_global_name() if Router.current != null else "-"])


func _fit_full() -> void:
	var own: Array[ModuleData] = []
	for mid in DB.modules:
		var m: ModuleData = DB.modules[mid]
		if m.manufacturer == Run.hull.manufacturer:
			own.append(m)
	own.sort_custom(func(x: ModuleData, y: ModuleData) -> bool:
		if x.reactor != y.reactor:
			return x.reactor > y.reactor
		return x.cells() < y.cells())
	for p in 2:
		for m: ModuleData in own:
			if p == 0 and Run.installed.any(func(on: ModuleData) -> bool: return on.id == m.id):
				continue
			if Run.slots_used(m.slot) < Run.slots_for(m.slot) and Run.can_power(m):
				Run.install_module(m.duplicate(true) as ModuleData)
	print("  [ladder] fit=full: %s, %d parts fitted" % [Run.hull.name, Run.installed.size()])


## THE WORLD YOU ORBIT, where it is on screen this frame: the live screen's own
## (`ladder_world`), and while a move holds the old picture, the held one's (where
## the held world has been carried, and how big), with how far the held picture
## has gone (`t`).
func _world_now(k: int) -> Dictionary:
	var out := {"f": k}
	var s := Router.current
	# (3B's one motion: what carries it this frame -- your ship along the
	# hallway on LOCAL, in plate px, with the zoom; the screen's pan offset; your
	# ship in the yard)
	if s is SectorScreen and (s as SectorScreen)._face != null and is_instance_valid((s as SectorScreen)._face):
		var sc := s as SectorScreen
		var art := sc._view.ship_view()
		if art != null:
			var ink := Rect2(art.ink_rect())
			var to_plate := sc._face.get_global_transform().affine_inverse()
			var c := to_plate * (art.get_global_transform() * art.canvas_to_local(ink.get_center())) - sc._face.origin()
			out["hall"] = [c.x, sc._lad_zs, sc.position.x]
	if s is StationScreen:
		var st := s as StationScreen
		out["yard"] = [st.position.x, st._mine_view.position.x if st._mine_view != null else 0.0,
			st._rail.modulate.a if st._rail != null else 1.0]
	if ZoomLadder.busy():
		out["lad"] = [int(ZoomLadder.active.phase), ZoomLadder.active._u]
	if s != null and s.has_method(&"ladder_world"):
		var w: Dictionary = s.call(&"ladder_world")
		if not w.is_empty():
			out["live"] = [(w.c as Vector2).x, (w.c as Vector2).y, float(w.r)]
	# (1A: your star's mark on the chart, the map's sun)
	if s is StarchartScreen:
		var mk: Vector2 = s.call(&"ladder_anchor", 1, 1, "A")
		out["mark"] = [mk.x, mk.y]
	if s is SystemMapScreen:
		var fr: Rect2 = (s as SystemMapScreen)._frame.get_global_rect()
		out["frame"] = [fr.position.x, fr.position.y, (s as SystemMapScreen)._box.position.x, (s as SystemMapScreen)._box.position.y, (s as SystemMapScreen).view.zoom, (s as SystemMapScreen).view.pan.y, (s as SystemMapScreen).view.TILT]
	if s != null and s.has_method(&"ladder_sun"):
		var sn: Dictionary = s.call(&"ladder_sun")
		if not sn.is_empty():
			out["sun"] = [(sn.c as Vector2).x, (sn.c as Vector2).y, float(sn.r)]
	if ZoomLadder.busy():
		var L := ZoomLadder.active
		out["phase"] = int(L.phase)
		if (L.phase == ZoomLadder.Phase.WAIT or L.phase == ZoomLadder.Phase.MOVE):
			var tp: Vector2 = L._mat.get_shader_parameter(&"to_pt")
			out["held_at"] = [tp.x, tp.y]
		if (L.phase == ZoomLadder.Phase.WAIT or L.phase == ZoomLadder.Phase.MOVE) and not L._old_world.is_empty():
			var m: ShaderMaterial = L._mat
			var fr: Vector2 = m.get_shader_parameter(&"from_pt")
			var to: Vector2 = m.get_shader_parameter(&"to_pt")
			var sc: Vector2 = m.get_shader_parameter(&"scl")
			var c: Vector2 = to + ((L._old_world.c as Vector2) - fr) * sc
			out["held"] = [c.x, c.y, float(L._old_world.r) * sc.x]
			out["t"] = float(m.get_shader_parameter(&"t"))
	return out


## One film of several moves in a row, each when the last has settled.
func _film_seq(name: String, calls: Array, gap: int = 24) -> void:
	var d := "%s/%s" % [_out, name]
	DirAccess.make_dir_recursive_absolute(d)
	var k := 0
	for i in 8:
		await _shown()
		_img().save_png("%s/f_%04d.png" % [d, k])
		k += 1
	for c: Callable in calls:
		c.call()
		var still := 0
		for i in 240:
			await _shown()
			_img().save_png("%s/f_%04d.png" % [d, k])
			k += 1
			still = still + 1 if not ZoomLadder.busy() and ZoomLadder.chain == &"" else 0
			if still >= gap:
				break
	print("  [ladder] %s: %d frames" % [name, k])


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	_out = _arg("out", "user://laddershot")
	DirAccess.make_dir_recursive_absolute(_out)
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	# (real time: the game's own clock, every frame's length and what it spent
	# it on logged -- run WITHOUT --fixed-fps)
	if "timing" in _args:
		ZoomLadder.fixed_dt = -1.0
		ZoomLadder.probe_on = true
		SVP.prof_on = true
	# the frame after the swap held still, to diff it against the frame before
	ZoomLadder.measure_hold = "measure" in _args
	Rng.forced = int(_arg("seed", "1"))
	# (`weight=light|medium|heavy`: the hull flown)
	var wt := {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}
	Run.start_new_run(&"korvan", int(wt.get(_arg("weight", "medium"), HullData.Weight.MEDIUM)))
	# (`fit=full`: every mount the hull has filled with its own manufacturer's
	# parts, turrets and pods on -- `StationShot`'s rule: couplings first, then the
	# smallest draw, different parts before repeats, only what the reactor runs)
	if "fit=full" in _args:
		_fit_full()
	# (the chart's FIRST SURVEY card is the first chart's, not the ladder's)
	StarchartScreen._primed_for = Run.galaxy_seed
	var seams := _arg("seams", "1,2,3").split(",")
	var designs := _arg("designs", "A,B,C").split(",")
	# a system with a world to orbit, the ship in orbit of it
	var sys := Run.at
	var world := -1
	var lay := SystemLayout.of(Run.node_at())
	for b in lay.bodies:
		if b.world != &"" and b.kind != &"belt":
			world = b.index
			break
	if world >= 0:
		SystemMapScreen._parked[sys] = {"at": world, "mode": &"rail"}
	SectorScreen._approached_at = sys
	Router.show_system()
	await _frames(90)
	for s in ["1", "2"]:
		if not s in seams:
			continue
		for d0 in designs:
			var d := String(ZoomLadder.DEFAULTS[int(s)]) if d0 == "picks" else d0
			ZoomLadder.force_design = {int(s): d}
			if s == "1":
				if not Router.current is SystemMapScreen:
					Router.show_system()
					await _frames(60)
				await _film("1%s_out" % d, Router.show_starchart)
				await _frames(40)
				await _film("1%s_in" % d, Router.show_system)
				await _frames(40)
			else:
				if not Router.current is SystemMapScreen:
					Router.show_system()
					await _frames(60)
				var mw: Node = null
				var mp0 := Router.current as SystemMapScreen
				if mp0 != null and mp0._ladder_body() >= 0:
					mw = mp0.view._views.get(mp0._ladder_body())
				# (`twice`: the same moves again in the same session, to tell a
				# first-time cost -- a shader compiled, a cache filled -- from one
				# paid every time)
				for rep in (2 if "twice" in _args else 1):
					var sfx := "" if rep == 0 else "_again"
					if rep > 0:
						var mp1 := Router.current as SystemMapScreen
						mw = mp1.view._views.get(mp1._ladder_body()) if mp1 != null and mp1._ladder_body() >= 0 else null
					await _film("2%s_in%s" % [d, sfx], Router.show_local)
					var lc := Router.current as SectorScreen
					if lc != null and lc._view.backdrop != null:
						print("  [ladder] 2%s: LOCAL's world is the map's own node: %s" % [d, lc._view.backdrop._near_world == mw and mw != null])
					await _frames(50)
					await _film("2%s_out%s" % [d, sfx], Router.show_system)
					await _frames(40)
	# GO ON AN EVENT (the map's GO): the ship in orbit where the event stands,
	# so the move is the zoom down alone, and the event's band after it
	if "go" in _args:
		ZoomLadder.force_design = {}
		var pick := -1
		var pb := -9
		var gsys := -1
		# (the first system, from here on, with an event on a world)
		for j in Run.map.size():
			var n0: MapGen.MapNode = Run.map[(sys + j) % Run.map.size()]
			if n0.type == MapGen.NodeType.STATION:
				continue
			OptionTable.ensure(n0)
			var lay0 := SystemLayout.of(n0)
			for i in n0.options.size():
				if n0.taken.has(i):
					continue
				var b := LocalEventDrawer.body_of(n0, i)
				if b >= 0 and b < lay0.bodies.size() and lay0.bodies[b].world != &"" and lay0.bodies[b].kind != &"belt":
					pick = i
					pb = b
					gsys = n0.index
					break
			if pick >= 0:
				break
		if pick >= 0:
			ZoomLadder.force = 0
			if Router.current is SystemMapScreen:
				Router.show_local()
				await _frames(60)
			Run.at = gsys
			Run.map[gsys].visited = true
			SectorScreen._approached_at = gsys
			SystemMapScreen._parked[gsys] = {"at": pb, "mode": &"rail"}
			Router.show_system()
			await _frames(120)
			ZoomLadder.force = 1
			var mp := Router.current as SystemMapScreen
			if mp != null:
				await _film("2C_go", func() -> void: mp.go_event(pick))
				await _frames(60)
				LocalEventDrawer.pending.clear()
		else:
			print("  [ladder] go: no event on a world here")
	# THE CHART TO LOCAL (Tab from the chart): two distances, one dive
	if "dive" in _args:
		ZoomLadder.force_design = {}
		ZoomLadder.force = 0
		if not Router.current is SystemMapScreen:
			Router.show_system()
			await _frames(60)
		Router.show_starchart()
		await _frames(90)
		ZoomLadder.force = 1
		await _film("dive_chart_local", Router.show_local)
		await _frames(60)
		# (and back: LOCAL to the chart, the HUD's STARCHART tab)
		await _film("dive_local_chart", Router.show_starchart)
		await _frames(60)
	if "3" in seams:
		var st := -1
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type == MapGen.NodeType.STATION:
				st = n.index
				break
		if st >= 0:
			Run.at = st
			Run.map[st].visited = true
			SectorScreen._approached_at = st
			# (`side=<id>` / `interior=<id>`: the station's side and its bay's
			# interior, instead of the station's own pick -- `StationSides`)
			StationSides.force_side = StringName(_arg("side", ""))
			StationSides.force_interior = StringName(_arg("interior", ""))
			# (on the ladder, so LOCAL draws the station's side, but not filmed)
			ZoomLadder.force = 1
			Router.show_local()
			await _frames(120)
			# (`fades=P,F,PF`: 3B's hand-off into the yard, each; named 3B_F_in etc.)
			var fades := _arg("fades", "").split(",", false)
			for d0 in designs:
				var d := String(ZoomLadder.DEFAULTS[3]) if d0 == "picks" else d0
				ZoomLadder.force_design = {3: d}
				for f in (fades if d == "B" and not fades.is_empty() else PackedStringArray([""])):
					ZoomLadder.force_fade = f
					var tag := "" if f == "" or f == "F" else "_" + f
					await _film("3%s%s_in" % [d, tag], func() -> void: Router.show_station(), 6, 30)
					await _frames(90)
					await _film("3%s%s_out" % [d, tag], func() -> void: Router.show_sector())
					await _frames(60)
				ZoomLadder.force_fade = ""
			# (`dive`: docked, Tab from the berth to the map, and from the chart
			# back to the berth -- two and three distances in one go)
			if "dive" in _args:
				ZoomLadder.force_design = {}
				ZoomLadder.force = 0
				if not Router.current is StationScreen:
					Router.show_station()
					await _frames(150)
				ZoomLadder.force = 1
				await _film("dive_station_map", Router.show_system)
				await _frames(60)
				ZoomLadder.force = 0
				Router.show_starchart()
				await _frames(90)
				ZoomLadder.force = 1
				await _film("dive_chart_station", Router.show_station)
				await _frames(90)
				await _film("dive_station_chart", Router.show_starchart)
				await _frames(60)
				ZoomLadder.force = 0
				Router.show_sector()
				await _frames(90)
				ZoomLadder.force = 1
			# (`seatcheck`: the dock's last frame beside the yard as it stands your
			# ship when docked with no move at all -- `seat_dock.png`, `seat_yard.png`
			# -- and both hulls' rects printed against the yard's own seat)
			if "seatcheck" in _args:
				ZoomLadder.force_design = {}
				ZoomLadder.force = 0
				if not Router.current is SectorScreen:
					Router.show_sector()
					await _frames(90)
				Router.show_local()
				await _frames(60)
				ZoomLadder.force = 1
				Router.show_station()
				for i in 900:
					await _tree.process_frame
					if not ZoomLadder.busy():
						break
				await _frames(60)
				await _shown()
				_img().save_png("%s/seat_dock.png" % _out)
				var s1 := Router.current as StationScreen
				var r1 := s1._mine_view.get_rect() if s1 != null and s1._mine_view != null else Rect2()
				ZoomLadder.force = 0
				Router.show_sector()
				await _frames(60)
				Router.show_station()
				await _frames(180)
				await _shown()
				_img().save_png("%s/seat_yard.png" % _out)
				var s2 := Router.current as StationScreen
				var r2 := s2._mine_view.get_rect() if s2 != null and s2._mine_view != null else Rect2()
				var P: Dictionary = s2._scene.placed[0] if s2 != null and s2._scene != null else {}
				var seat := Rect2()
				if not P.is_empty():
					var ink: Rect2i = P["ink"]
					seat = Rect2(Vector2(float(P["x0"]) - ink.position.x, float(P["top"]) - ink.position.y), Vector2((P["img"] as Image).get_size()))
				print("  [ladder] seat %s: docked %s, docked with no move %s, the yard's seat %s" % [_arg("weight", "medium"), r1, r2, seat])
				ZoomLadder.force = 1
			# (`wrecks`: LOCAL at the station with a fight's wrecks in it, and your

			# ship's cutaway opened there: stills, to see the station's side with them)
			if "wrecks" in _args:
				if not Router.current is SectorScreen:
					Router.show_sector()
					await _frames(90)
				Run.new_wreck(Run.map[st], DB.enemies[&"cutter"])
				Run.new_wreck(Run.map[st], DB.enemies[&"cutter"])
				Router.show_local()
				await _frames(90)
				await _shown()
				_img().save_png("%s/station_wrecks.png" % _out)
				var sc := Router.current as SectorScreen
				if sc != null:
					var cut := sc.open_cutaway()
					await _frames(90)
					await _shown()
					_img().save_png("%s/station_cutaway.png" % _out)
					if cut != null and is_instance_valid(cut) and cut.has_method(&"close"):
						cut.call(&"close")
					await _frames(60)
				Run.map[st].jetsam.clear()
				Router.show_sector()
				await _frames(60)
			# (`levels`: 3B's dock at the same station at every development level --
			# the yard behind the inner door is the level's own)
			if "levels" in _args:
				ZoomLadder.force_design = {}
				for dev in 5:
					Run.map[st].development = dev
					if not Router.current is SectorScreen:
						Router.show_sector()
						await _frames(90)
					Router.show_local()
					await _frames(60)
					await _film("3B_in_L%d" % dev, func() -> void: Router.show_station())
					await _frames(60)
					Router.show_sector()
					await _frames(90)
			# THE MAP'S DOCK, the two distances in one go (down to LOCAL, into the
			# hangar), on the default
			if "mapdock" in _args:
				ZoomLadder.force_design = {}
				Router.show_system()
				await _frames(120)
				await _film_seq("3B_map", [func() -> void: Router.show_station()], 40)
	# THE WHOLE LADDER at a station system, the defaults, down and back up
	if "tour" in _args:
		ZoomLadder.force_design = {}
		var st2 := -1
		for raw in Run.map:
			var n2: MapGen.MapNode = raw
			if n2.type == MapGen.NodeType.STATION:
				st2 = n2.index
				break
		if st2 >= 0:
			Run.at = st2
			Run.map[st2].visited = true
			SectorScreen._approached_at = st2
			ZoomLadder.force = 0
			Router.show_starchart()
			await _frames(90)
			ZoomLadder.force = 1
			await _film_seq("tour", [Router.show_system, Router.show_local, Router.show_station,
				Router.show_sector, Router.show_system, Router.show_starchart])
	print("  [ladder] done")
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	_tree.quit()
