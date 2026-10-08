extends Node

## THE ZOOM LADDER'S DOORS, headless (`ZoomLadder`):
##   godot --headless --path . -- sheet=LadderTest
## Every move between the four distances, through the Router's own doors with the
## animation on (`Router.animate_in_harness`) and the ladder's clock stepped
## 1/30 s a frame: each one lands on the screen it was going to; nothing is left
## half-built behind it (no ladder in the tree, the map's camera handed back,
## LOCAL's scene and sky at their own size, the bar back, the hull shown); a key
## pressed mid-move ends it at once and the screen takes input after; the wheel
## past either end of the map, the chart's closest zoom and LOCAL steps a
## distance; LOCAL's DOCK at a station docks, UNDOCK lands on LOCAL; the
## defaults are Jon's picks (1A, 2C, 3B), and 3B's dock flies the yard's hull in
## from the left with the elevator out of the picture until it has settled, its
## undock the elevator out first and the hull away to the left; a fight
## opened from the map arrives on LOCAL and its end goes back; every design of
## every seam; and the switch off is today's flow, a plain swap.

var _fails := 0
var _tree: SceneTree


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


## Until no move is under way (or 240 frames).
func _idle() -> int:
	for i in 240:
		if not ZoomLadder.busy():
			await _tree.process_frame
			return i
		await _tree.process_frame
	return -1


func _ladders() -> int:
	var n := 0
	var stack: Array[Node] = [_tree.root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is ZoomLadder and not x.is_queued_for_deletion():
			n += 1
		stack.append_array(x.get_children())
	return n


## Nothing of a move left behind on whatever screen is up.
func _clean(where: String) -> void:
	var s := Router.current
	_ok("%s: no ladder left in the tree" % where, _ladders() == 0 and not ZoomLadder.busy())
	if s is SystemMapScreen:
		var m := s as SystemMapScreen
		_ok("%s: the map has its camera back" % where, not m.cam_held and m._lad.is_empty())
	elif s is SectorScreen:
		var l := s as SectorScreen
		var whole := true
		for c: Control in [LocalSubject.of(l._view), l._view._row, l._view.dust, l._view.fx]:
			if c != null and c.scale != Vector2.ONE:
				whole = false
		_ok("%s: LOCAL's scene at its own size" % where, whole and l._lad.is_empty() and is_equal_approx(l._lad_zs, 1.0))
		_ok("%s: LOCAL's sky unzoomed" % where, l._view.backdrop == null or is_equal_approx(l._view.backdrop.zoom, 1.0))
		_ok("%s: LOCAL's bar shown" % where, l._quiet_holder == null or l._quiet_holder.modulate.a > 0.99)
		var art := l._view.ship_view()
		_ok("%s: your hull shown" % where, art == null or art.visible)
	elif s is StarchartScreen:
		var c := s as StarchartScreen
		_ok("%s: the chart's view handed back" % where, c._chart == null or c._chart._lad.is_empty())
	elif s is StationScreen:
		var st := s as StationScreen
		_ok("%s: the yard's hull shown" % where, st._mine_view == null or st._mine_view.visible)


func _go(label: String, call: Callable, want: Script) -> void:
	call.call()
	var n := await _idle()
	_ok("%s lands on %s (%d frames)" % [label, want.get_global_name(), n],
		n >= 0 and Router.current != null and Router.current.get_script() == want)
	_clean(label)


## 3B, DOCKING: the hull comes in from the left edge and only moves right, the
## elevator stays out of the picture the whole way, the hull ends on its stands,
## and only then does the elevator slide back in.
func _hull_flies_in(dock_b: Button) -> void:
	dock_b.pressed.emit()
	var xs: Array[float] = []
	var rail_out := true
	var st: StationScreen = null
	for i in 240:
		await _tree.process_frame
		if Router.current is StationScreen and ZoomLadder.busy() and ZoomLadder.active.phase == ZoomLadder.Phase.MOVE:
			st = Router.current as StationScreen
			if st._mine_view != null and not st._lad.is_empty():
				xs.append(st._mine_view.position.x)
				if st._rail != null and st._rail.position.x > float(st._lad.rail_x) - 20.0:
					rail_out = false
		if not ZoomLadder.busy() and Router.current is StationScreen:
			break
	st = Router.current as StationScreen
	if not _ok("3B DOCK lands in the station", st != null and Router.docked):
		return
	var berth := st._mine_view.position.x if st._mine_view != null else 0.0
	var mono := true
	for i in range(1, xs.size()):
		if xs[i] < xs[i - 1] - 0.01:
			mono = false
	_ok("3B: the hull flies in from the left (%d frames, from x %.0f to its berth %.0f)" % [xs.size(),
		xs[0] if not xs.is_empty() else 0.0, berth], xs.size() > 10 and xs[0] < berth - 200.0 and mono)
	_ok("3B: the elevator is out of the picture while it flies", rail_out)
	_ok("3B: the hull ends on its stands", xs.is_empty() or absf(xs[-1] - berth) < 1.0)
	var rx := st._rail.position.x if st._rail != null else 0.0
	await _frames(20)
	_ok("3B: then the elevator slides in (%.0f -> %.0f)" % [rx, st._rail.position.x if st._rail != null else 0.0],
		st._rail == null or st._rail.position.x > rx + 20.0)
	_clean("3B dock")


## 3B, UNDOCKING: the elevator out first, then the hull off to the left, then
## LOCAL beside the station with your hull where it sits.
func _hull_flies_out() -> void:
	var st := Router.current as StationScreen
	if st == null:
		return
	var rail0 := st._rail.position.x if st._rail != null else 0.0
	var ship0 := st._mine_view.position.x if st._mine_view != null else 0.0
	Router.show_sector()
	var rail_first := true
	var left := false
	for i in 240:
		await _tree.process_frame
		if Router.current == st and is_instance_valid(st) and st._mine_view != null:
			var gone := st._rail == null or st._rail.position.x < rail0 - 20.0
			if st._mine_view.position.x < ship0 - 5.0 and not gone:
				rail_first = false
			if st._mine_view.position.x < ship0 - 100.0:
				left = true
		if not ZoomLadder.busy() and Router.current is SectorScreen:
			break
	_ok("3B UNDOCK: the elevator goes before the hull moves", rail_first)
	_ok("3B UNDOCK: the hull leaves to the left", left)
	_ok("3B UNDOCK lands on LOCAL, undocked", Router.current is SectorScreen and not Router.docked)
	_clean("3B undock")


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	Rng.forced = 7
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await _frames(30)
	_ok("a run opens on LOCAL", Router.current is SectorScreen)
	SectorScreen._approached_at = Run.at

	# 1. the four distances, out and back in, every design of every seam
	for d in ["A", "B", "C"]:
		ZoomLadder.force_design = {1: d, 2: d, 3: d}
		await _go("%s LOCAL -> map" % d, Router.show_system, SystemMapScreen)
		await _go("%s map -> chart" % d, Router.show_starchart, StarchartScreen)
		await _go("%s chart -> map" % d, Router.show_system, SystemMapScreen)
		await _go("%s map -> LOCAL" % d, Router.show_local, SectorScreen)
	ZoomLadder.force_design = {}
	await _go("LOCAL -> chart (two distances)", Router.show_starchart, StarchartScreen)
	await _go("chart -> LOCAL (two distances)", Router.show_local, SectorScreen)

	# 1b. 2C HANDS OVER THE MAP'S OWN WORLD: the node LOCAL draws as the world you
	# orbit, once the move is over, is the very node the map drew it with
	var lay := SystemLayout.of(Run.node_at())
	var wb := -1
	for b in lay.bodies:
		if b.world != &"" and b.kind != &"belt":
			wb = b.index
			break
	if wb >= 0:
		ZoomLadder.force_design = {2: "C"}
		SystemMapScreen._parked[Run.at] = {"at": wb, "mode": &"rail"}
		await _go("2C to the map, in orbit", Router.show_system, SystemMapScreen)
		var mp := Router.current as SystemMapScreen
		var mv: Node = mp.view._views.get(wb) if mp != null else null
		Router.show_local()
		var handed := false
		for i in 240:
			await _tree.process_frame
			var lc := Router.current as SectorScreen
			if lc != null and lc._view.backdrop != null and not lc._view.backdrop._hand.is_empty():
				handed = true
			if not ZoomLadder.busy() and Router.current is SectorScreen:
				break
		var ls := Router.current as SectorScreen
		var now_world: Node = ls._view.backdrop._near_world if ls != null and ls._view.backdrop != null else null
		# (headless, LOCAL's sky builds no near picture and the map no turning
		# worlds to hand: the windowed films are where this is seen)
		if now_world == null or not (mv is PlanetView):
			print("  --   2C handover not checkable headless (no near world drawn): map world %s, LOCAL world %s" % [mv, now_world])
		else:
			_ok("2C: the map's world is handed to LOCAL mid-move", handed)
			_ok("2C: and IS LOCAL's world after it (one world, never a second)", now_world == mv)
		_clean("2C handover")
		ZoomLadder.force_design = {}

	# 2. the pre-roll defers the swap, and a key mid-move ends the move at once
	Router.show_system()
	_ok("the screen being left moves first (LOCAL still up)", Router.current is SectorScreen and ZoomLadder.busy())
	for i in 40:
		if ZoomLadder.busy() and ZoomLadder.active.phase == ZoomLadder.Phase.MOVE:
			break
		await _tree.process_frame
	_ok("then the move is under way on the map", Router.current is SystemMapScreen and ZoomLadder.busy())
	await _frames(4)
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_ok("a key mid-move ends it", not ZoomLadder.busy())
	var m := Router.current as SystemMapScreen
	_clean("after the key")
	if m != null:
		_ok("and the map is at rest (zoom %.2f, its fit %.2f)" % [m.view.zoom, m.zoom_min], absf(m.view.zoom - m.zoom_min) < 0.01)
		# the map takes the wheel after a move
		var z0: float = m._zoom_to
		m._zoom_by(SystemMapScreen.ZOOM_STEP, Vector2(480, 270))
		_ok("and takes the wheel after it", m._zoom_to > z0)
		m._zoom_to = m.zoom_min
		m.view.zoom = m.zoom_min
		await _frames(2)

	# 3. the wheel past the ends
	if m != null:
		m._zoom_to = m.zoom_min
		m._zoom_by(1.0 / SystemMapScreen.ZOOM_STEP, Vector2(480, 270))
		_ok("one notch out past the sector is not yet the chart", Router.current == m)
		m._zoom_by(1.0 / SystemMapScreen.ZOOM_STEP, Vector2(480, 270))
		await _idle()
		_ok("the second is (the chart)", Router.current is StarchartScreen)
		_clean("wheel out")
	var ch := Router.current as StarchartScreen
	if ch != null:
		ch._chart.zoom = StarchartScreen.MapChart.ZOOM_MAX
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = ch._chart.size * 0.5
		ch._chart._gui_input(wheel)
		ch._chart._gui_input(wheel)
		await _idle()
		_ok("the wheel in past the chart's closest zoom is the map", Router.current is SystemMapScreen)
		_clean("wheel in (chart)")
	m = Router.current as SystemMapScreen
	if m != null:
		m._zoom_to = m.view.ZOOM_MAX
		m._zoom_by(SystemMapScreen.ZOOM_STEP, Vector2(480, 270))
		m._zoom_by(SystemMapScreen.ZOOM_STEP, Vector2(480, 270))
		await _idle()
		_ok("the wheel in past the map's closest zoom is LOCAL", Router.current is SectorScreen)
		_clean("wheel in (map)")
	var loc := Router.current as SectorScreen
	if loc != null:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_WHEEL_DOWN
		down.pressed = true
		loc._on_view_wheel(down)
		loc._on_view_wheel(down)
		await _idle()
		_ok("the wheel out on LOCAL is the map", Router.current is SystemMapScreen)
		_clean("wheel out (LOCAL)")

	# 4. a fight opened from the map arrives on LOCAL, and its end goes back
	Router.start_ambush()
	await _idle()
	_ok("a fight from the map lands on LOCAL, fighting", Router.current is SectorScreen and Router.in_combat())
	_clean("into a fight")
	if Router.combat != null:
		Router.combat.finished = true
	Router.after_combat(null)
	await _idle()
	_ok("its end (not won) goes back to the map", Router.current is SystemMapScreen)
	_clean("out of a fight")

	# 5. a station: DOCK from LOCAL, UNDOCK to LOCAL, the map from the berth
	var st := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			st = n.index
			break
	if _ok("the run has a station", st >= 0):
		Run.at = st
		Run.map[st].visited = true
		SectorScreen._approached_at = st
		await _go("to LOCAL at the station", Router.show_local, SectorScreen)
		loc = Router.current as SectorScreen
		var dock_b: Button = loc.find_child("Dock", true, false) as Button if loc != null else null
		_ok("the defaults are 1A 2C 3B", ZoomLadder.design_for(1) == "A" and ZoomLadder.design_for(2) == "C"
			and ZoomLadder.design_for(3) == "B")
		if dock_b != null:
			await _hull_flies_in(dock_b)
			await _hull_flies_out()
			loc = Router.current as SectorScreen
			dock_b = loc.find_child("Dock", true, false) as Button if loc != null else null
		if _ok("LOCAL's bar offers DOCK at a station", dock_b != null):
			for d in ["A", "B", "C", "D"]:
				ZoomLadder.force_design = {3: d}
				loc = Router.current as SectorScreen
				dock_b = loc.find_child("Dock", true, false) as Button if loc != null else null
				if dock_b == null:
					_ok("%s: DOCK still on the bar" % d, false)
					break
				dock_b.pressed.emit()
				var n2 := await _idle()
				_ok("%s DOCK lands in the station (%d frames)" % [d, n2], Router.current is StationScreen and Router.docked)
				_clean("%s dock" % d)
				await _frames(10)
				Router.show_sector()
				await _idle()
				_ok("%s UNDOCK lands on LOCAL, undocked" % d, Router.current is SectorScreen and not Router.docked)
				_clean("%s undock" % d)
			ZoomLadder.force_design = {}
			Router.show_station()
			await _idle()
			await _go("the map from the berth (two distances)", Router.show_system, SystemMapScreen)
			# THE MAP'S DOCK ON THE LADDER (3B): down to LOCAL by the station's side,
			# and on into the hangar, one call
			Router.show_station()
			var saw_local := false
			for i in 400:
				await _tree.process_frame
				if Router.current is SectorScreen:
					saw_local = true
				if Router.current is StationScreen and not ZoomLadder.busy() and ZoomLadder.chain == &"":
					break
			_ok("the map's DOCK goes by LOCAL (%s) into the berth" % saw_local, saw_local and Router.current is StationScreen and Router.docked)
			_clean("map dock")
			Router.show_sector()
			await _idle()

	# 6. the switch off: today's flow, a plain swap
	ZoomLadder.force = 0
	Router.show_system()
	_ok("off: the map at once, no move", Router.current is SystemMapScreen and not ZoomLadder.busy())
	Router.show_local()
	_ok("off: LOCAL at once", Router.current is SectorScreen and not ZoomLadder.busy())
	await _frames(4)
	_clean("off")
	ZoomLadder.force = -1
	ZoomLadder.fixed_dt = -1.0
	print("laddertest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
