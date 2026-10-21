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
## quit. `rm` docks under reduced motion. A half-speed film is this one slowed
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
	if route == "first":
		# (LOCAL at the station, and on it the arrival a run's first system
		# plays, `_begin_arrive`, name card and all -- the dock's, five seconds
		# into the film like it, so the screen has long settled for both)
		Router.show_local()
		await _frames(150)
		(Router.current as SectorScreen)._begin_arrive()
		for i in 330:
			await _tree.process_frame
			_log_ship()
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
