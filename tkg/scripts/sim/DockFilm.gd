extends Node

## Films the dock on the game's own fixed-fps clock, so the sound stays on its pictures.
## Why: docs/why/DockFilm.md#dock-film

var _tree: SceneTree
var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	# (`steam=heavy|heavier`: the lift's steam at that weight, `LiftPlume.WEIGHTS`)
	if Harness.arg("steam", "") != "":
		LiftPlume.weight = int({"built": 0, "heavy": 1, "heavier": 2}.get(Harness.arg("steam", ""), LiftPlume.weight))
	# (`steam_style=0..3`, `steam_seed=N`: a texture, and one steam for every texture's film)
	if Harness.arg("steam_style", "") != "":
		LiftPlume.style = int(Harness.arg("steam_style", "1"))
	LiftPlume.seed = int(Harness.arg("steam_seed", "-1"))
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	# (`live`: the ladder on the game's own clock, as in play, for timing what is heard against what is drawn)
	ZoomLadder.fixed_dt = -1.0 if "live" in _args else 1.0 / 30.0
	DisplaySettings.reduced_motion = "rm" in _args
	Rng.forced = Harness.seed_arg(1)
	var wt := {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}
	Run.start_new_run(&"korvan", int(wt.get(Harness.arg("weight", "medium"), HullData.Weight.MEDIUM)))
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
	# (`party=N`: N made-up partners in the room, ConvoyTest's, for the co-op stills)
	if Harness.arg("party", "") != "":
		load("res://scripts/sim/ConvoyTest.gd").fake_party(int(Harness.arg("party", "0")))
	var route := Harness.arg("route", "local")
	if route == "parked":
		# (LOCAL at the station, nothing happening: the dust's idle rate)
		Router.show_local()
		for i in 240:
			await _tree.process_frame
			_log_dust(&"parked")
		if Harness.arg("stills", "") != "":
			DirAccess.make_dir_recursive_absolute(Harness.arg("stills", ""))
			await _still(Harness.arg("stills", ""), "parked")
		if "moves" in _args:
			await _partner_moves()
		_tree.quit()
		return
	if route == "first":
		# The dock's arrival is the first system's, five seconds in so both have settled.
		Router.show_local()
		await Harness.frames(_tree, 150)
		# (`stills=<dir>`: the frame before the arrival, then 0.5 s and 1 s into
		# it, at 2x, for judging the dust against the arrival)
		var stills := Harness.arg("stills", "")
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
	if route == "undock":
		# (docked at once, no dock played, and the berth settled -- its decks'
		# power-ons done -- then UNDOCK)
		ZoomLadder.force = 0
		Router.show_station()
		ZoomLadder.force = 1
		await Harness.frames(_tree, 120)
		await _undock()
		if "moves" in _args:
			await _partner_moves()
		# (`redock`: and DOCK again from where the undock left it)
		if "redock" in _args:
			await Harness.frames(_tree, 45)
			await _redock()
		_tree.quit()
		return
	if route == "map":
		Router.show_system()
	else:
		Router.show_local()
	await Harness.frames(_tree, 150)
	var f0 := Engine.get_frames_drawn()
	if route == "map":
		var m := Router.current as SystemMapScreen
		m.panel.show_system()
		await Harness.frames(_tree, 2)
		var card = m.panel._cards.get(&"dock")
		(card._right as Button).pressed.emit()
	else:
		var loc := Router.current as SectorScreen
		var dk := loc.find_child("Dock", true, false) as Button
		dk.pressed.emit()
	var last := &""
	var in_station := -1
	for i in (9000 if "live" in _args else 1500):
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
		# (the landing in the yard: its clock, its flame, the loop's level --
		# `StationScreen.ladder_yard_t`; the clips are in `sfxtape=`)
		var sy := Router.current as StationScreen
		if sy != null and not sy._lad.is_empty() and sy._lad.has("yard_t") and is_instance_valid(sy._mine_view):
			print("  [yard] drawn %d pf %d gc %.4f jets %.2f t %.3f thrust %d sputter %s loop %.2f row %d" % [Engine.get_frames_drawn(), Engine.get_process_frames(), GameClock.now(),
				sy._heavy._jets_k if sy._heavy != null else 0.0, float(sy._lad.yard_t),
				sy._mine_view._thrust_now(), sy._mine_view.sputtering(), Audio._ship_level, int(sy._lad.get("row", -1))])
		if in_station < 0 and Router.current is StationScreen:
			in_station = Engine.get_frames_drawn() - f0
			print("  [dockfilm] frame %d: the station's screen up" % in_station)
		if Router.current is StationScreen and not ZoomLadder.busy():
			print("  [dockfilm] frame %d: the move done" % (Engine.get_frames_drawn() - f0))
			break
	await Harness.frames(_tree, int(float(Harness.arg("after", "2.5")) * 30.0))
	# (`undock`: and out again)
	if "undock" in _args:
		await _undock()
	_tree.quit()


## UNDOCK as the station's screen does it, logging dust and ship place every frame on LOCAL.
func _undock() -> void:
	var stills := Harness.arg("stills", "")
	if stills != "":
		DirAccess.make_dir_recursive_absolute(stills)
	print("  [dockfilm] undock: UNDOCK at drawn %d" % Engine.get_frames_drawn())
	Router.show_sector()
	var l0 := -1
	var done := -1
	for i in 900:
		await _tree.process_frame
		var lu := Router.current as SectorScreen
		if lu == null:
			continue
		_log_dust(&"undock")
		var art := lu._view.ship_view() if lu._view != null else null
		if art != null:
			print("  [undock] drawn %d x %.2f scale %.4f thrust %d power %.2f zoom %.3f" % [Engine.get_frames_drawn(), art.position.x,
				art.scale.x, art._thrust_now(), lu._face.power if lu._face != null else -1.0, lu._lad_zs])
		if l0 < 0:
			l0 = i
			print("  [dockfilm] undock: LOCAL up at drawn %d" % Engine.get_frames_drawn())
		var k := i - l0
		if stills != "" and (k == 15 or k == 30 or k == 45):
			await _still(stills, "undock_%.1fs" % (k / 30.0))
		if done < 0 and not ZoomLadder.busy():
			done = i
			print("  [dockfilm] undock: the move done at drawn %d" % Engine.get_frames_drawn())
		if done >= 0 and i > done + 30 and k > 30:
			break
	if stills != "":
		await Harness.frames(_tree, 60)
		await _still(stills, "undocked")


## (`moves`, with `party=N`): the first partner docks, undocks, and a new one
## arrives, on whichever side your ship is moored.
func _partner_moves() -> void:
	var ids: Array = Net.partners().map(func(p: Dictionary) -> int: return int(p.id))
	if ids.is_empty():
		return
	var id: int = ids[0]
	print("  [dockfilm] moves: %d docks at drawn %d" % [id, Engine.get_frames_drawn()])
	Net.roster[id].docked = true
	Sig.party_changed.emit()
	await Harness.frames(_tree, 90)
	print("  [dockfilm] moves: %d undocks at drawn %d" % [id, Engine.get_frames_drawn()])
	Net.roster[id].docked = false
	Sig.party_changed.emit()
	await Harness.frames(_tree, 120)
	var b: ShipBuild = Net.build_of(id)
	print("  [dockfilm] moves: one arrives at drawn %d" % Engine.get_frames_drawn())
	Net.roster[9] = {"id": 9, "name": "ORIN", "hull": &"korvan", "ready": true, "order": 9,
		"build": b.to_wire() if b != null else {}, "at": Run.at, "docked": false}
	Sig.party_changed.emit()
	await Harness.frames(_tree, 120)


## DOCK pressed on LOCAL, run until the station's move is done and a beat after.
func _redock() -> void:
	var loc := Router.current as SectorScreen
	if loc == null:
		print("  [dockfilm] redock: not on LOCAL")
		return
	var dk := loc.find_child("Dock", true, false) as Button
	if dk == null:
		print("  [dockfilm] redock: no DOCK")
		return
	print("  [dockfilm] redock: DOCK at drawn %d (fade only %s)" % [Engine.get_frames_drawn(), ZoomLadder.dock_fade_only])
	dk.pressed.emit()
	print("  [dockfilm] redock: fade only %s" % ZoomLadder.dock_fade_only)
	for i in 900:
		await _tree.process_frame
		if Router.current is StationScreen and not ZoomLadder.busy():
			print("  [dockfilm] redock: the move done at drawn %d" % Engine.get_frames_drawn())
			break
	await Harness.frames(_tree, 45)


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


## Dust speed less its own drift: median and maximum, plus the sky camera it slides with.
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
