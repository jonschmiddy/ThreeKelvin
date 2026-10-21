extends Node

## THE DOCK, FILMED WITH ITS SOUND (`ZoomLadder` 3B, `SectorScreen.ladder_cam`,
## the station's elevator after it):
##   godot --path . --windowed --resolution 1920x1080 --fixed-fps 30
##       --write-movie <dir>/dock.avi -- sheet=DockFilm [route=local|map|first]
##       [seed=N] [weight=light|medium|heavy] [rm]
## A run beside a station, the ladder on, its clock stepped by the game's own
## (`GameClock` through `--fixed-fps`, never the wall's): LOCAL beside the
## station (`route=local`, the default: DOCK pressed on LOCAL's bar) or the map
## parked at the station (`route=map`: the map's DOCK card, down to LOCAL and on
## in), then the dock through to the berth and two seconds of it at rest, and
## quit; `route=first` films instead the arrival a run's first system plays,
## at the same station, for laying the dock's beside (`[ship]` lines: every
## frame of an arrival, your ship's place and size; the AVI's frame is `drawn`),
## quit (`stills=<dir>`: the frame before it and 0.5 s and 1 s into it, at
## 2x). `rm` docks under reduced motion. A half-speed film is this one slowed
## by the encoder, so its sound stays on its pictures. Prints the frame each
## step began on. Needs a window.

var _tree: SceneTree
var _args: PackedStringArray


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	DisplaySettings.reduced_motion = "rm" in _args
	Rng.forced = int(_arg("seed", "1"))
	var wt := {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}
	Run.start_new_run(&"korvan", int(wt.get(_arg("weight", "medium"), HullData.Weight.MEDIUM)))
	StarchartScreen._primed_for = Run.galaxy_seed
	var st := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			st = n.index
			break
	if st < 0:
		print("  [dockfilm] no station")
		_tree.quit(1)
		return
	Run.at = st
	Run.map[st].visited = true
	SectorScreen._approached_at = st
	Router.park_at_station()
	var route := _arg("route", "local")
	if route == "parked":
		# (LOCAL at the station, nothing happening: the dust's idle rate)
		Router.show_local()
		for i in 240:
			await _tree.process_frame
			_log_dust(&"parked")
		_tree.quit()
		return
	if route == "first":
		# (LOCAL at the station, and on it the arrival a run's first system
		# plays, `_begin_arrive`, name card and all -- the dock's, five seconds
		# into the film like it, so the screen has long settled for both)
		Router.show_local()
		await _frames(150)
		# (`stills=<dir>`: the frame before the arrival, then 0.5 s and 1 s into
		# it, at 2x, for judging the dust against the arrival)
		var stills := _arg("stills", "")
		if stills != "":
			DirAccess.make_dir_recursive_absolute(stills)
			await _still(stills, "arrive_0.0s")
		(Router.current as SectorScreen)._begin_arrive()
		for i in 330:
			await _tree.process_frame
			_log_ship()
			_log_dust(&"first")
			if stills != "" and (i == 14 or i == 29):
				await _still(stills, "arrive_%.1fs" % ((i + 1) / 30.0))
		_tree.quit()
		return
	if route == "map":
		Router.show_system()
	else:
		Router.show_local()
	await _frames(150)
	var f0 := Engine.get_frames_drawn()
	if route == "map":
		var m := Router.current as SystemMapScreen
		m.panel.show_system()
		await _frames(2)
		var card = m.panel._cards.get(&"dock")
		(card._right as Button).pressed.emit()
	else:
		var loc := Router.current as SectorScreen
		var dk := loc.find_child("Dock", true, false) as Button
		dk.pressed.emit()
	var last := &""
	var in_station := -1
	for i in 1500:
		await _tree.process_frame
		_log_ship()
		var lcb := Router.current as SectorScreen
		if lcb != null and not lcb._lad.is_empty():
			_log_dust((lcb._lad.get("hall", {}) as Dictionary).get("beat", &""))
		var lc := Router.current as SectorScreen
		if lc != null and not lc._lad.is_empty():
			var b: StringName = (lc._lad.get("hall", {}) as Dictionary).get("beat", &"")
			if b != last:
				print("  [dockfilm] frame %d: beat %s" % [Engine.get_frames_drawn() - f0, b])
				last = b
		if in_station < 0 and Router.current is StationScreen:
			in_station = Engine.get_frames_drawn() - f0
			print("  [dockfilm] frame %d: the station's screen up" % in_station)
		if Router.current is StationScreen and not ZoomLadder.busy():
			print("  [dockfilm] frame %d: the move done" % (Engine.get_frames_drawn() - f0))
			break
	await _frames(75)
	_tree.quit()


## Your ship on LOCAL this frame, while an arrival has it: its place and size.
var _called := -1


func _log_ship() -> void:
	var lc := Router.current as SectorScreen
	var art := lc._view.ship_view() if lc != null and lc._view != null else null
	if art == null:
		return
	if art._arrive_at >= 0 and _called < 0:
		_called = Engine.get_frames_drawn()
		print("  [dockfilm] drawn %d: the arrival called, held %.2f s" % [_called, (art._arrive_at - art._arrive_from) / 1000.0])
	if art._arrive_at >= 0 or (_called >= 0 and Engine.get_frames_drawn() - _called < 200):
		var r := art.fitted_rect_global()
		print("  [ship] drawn %d x %.1f rect %.1f %.1f %.1f %.1f scale %.3f thrust %d" % [Engine.get_frames_drawn(), art.position.x,
			r.position.x, r.position.y, r.size.x, r.size.y, art.scale.x, art._thrust_now()])


## The window as drawn this frame, at 2x (nearest), as `<dir>/<name>.png`.
func _still(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := _tree.root.get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [dir, name])
	print("  [dockfilm] still %s at drawn %d" % [name, Engine.get_frames_drawn()])


## LOCAL's dust this frame (`LocalDust`, through its motes' places as drawn,
## `_rest_at` and the scene's transform): each mote's speed, px a second, and
## what is left of it once its own drift is taken out -- the median and the
## most, and the sky's camera (`LocalSky.cam_follow`) it slides with.
var _dust_prev := {}


func _log_dust(tag: StringName) -> void:
	var lc := Router.current as SectorScreen
	if lc == null or lc._view == null or lc._view.dust == null:
		return
	var d: LocalDust = lc._view.dust
	if d.sky == null or d._motes.is_empty():
		return
	var X := d.get_global_transform()
	var sp: Array[float] = []
	var rs: Array[float] = []
	var now := {}
	for i in d._motes.size():
		var m: Dictionary = d._motes[i]
		var g := X * d._rest_at(m, d._t)
		now[i] = [g, d._t]
		if _dust_prev.has(i):
			var pv: Array = _dust_prev[i]
			var dt := maxf(d._t - float(pv[1]), 1.0 / 30.0)
			var dv: Vector2 = g - (pv[0] as Vector2)
			if dv.length() > 200.0:
				continue
			sp.append(dv.length() / dt)
			rs.append(absf(dv.x - float(m.vx) * (d._t - float(pv[1]))) / dt)
	_dust_prev = now
	if sp.is_empty():
		return
	sp.sort()
	rs.sort()
	print("  [dust] drawn %d %s speed med %.1f max %.1f px/s; beyond its own drift med %.1f max %.1f px/s; cam %.0f" % [
		Engine.get_frames_drawn(), tag, sp[sp.size() / 2], sp[-1], rs[rs.size() / 2], rs[-1], d.sky.cam_follow.x])
