extends Node

## THE ZOOM LADDER'S DOORS, headless (`ZoomLadder`):
##   godot --headless --path . -- sheet=LadderTest
## Every move between the four distances, through the Router's own doors with the
## animation on (`Router.animate_in_harness`) and the ladder's clock stepped
## 1/30 s a frame: each one lands on the screen it was going to; nothing is left
## half-built behind it (no ladder in the tree, the map's camera handed back,
## LOCAL's scene and sky at their own size, the bar back, the hull shown); a key
## pressed mid-move ends it at once and the screen takes input after; the wheel
## past either end of the map, the chart's closest zoom and LOCAL stays put (Tab
## and the tabs are the way between distances, never the wheel); LOCAL's DOCK at a station docks, UNDOCK lands on LOCAL; the
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


## Until no move is under way (or 600 frames: the dock is eight seconds).
func _idle() -> int:
	for i in 600:
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


## 3B, DOCKING (the Drum): on LOCAL your ship sets off from where it sits and
## only ever moves right, the station's lights come on as it goes, and it is all
## in behind the lips before the camera pans; the pan carries the yard in from
## the right; in the yard the hull comes in from the left and only moves right,
## the elevator out of the picture the whole way, the hull ends on its stands,
## and only then does the elevator slide back in.
func _hull_flies_in(dock_b: Button) -> void:
	var loc0 := Router.current as SectorScreen
	dock_b.pressed.emit()
	var xs: Array[float] = []
	var rail_out := true
	var st: StationScreen = null
	# ON LOCAL: your ship on the station's plate, each frame LOCAL draws it, and
	# how far the station's lights have come on
	var last := Rect2()
	var first := Rect2()
	var tails: Array[float] = []
	var power := 0.0
	var shown := 0.0
	var layer_bad := 0
	# THROUGH THE LIPS, ONE MOUTH FOR EVERY SHIP (Jon: "We need to have the ship
	# door opening always be the same size, no matter what ship you are in"):
	# while any of your ship is between the mouth and the recess's end, all of
	# it -- its hull and every part bolted on -- is inside the recess, `LIP_ROOM`
	# px or more from both lips
	var lip_room := INF
	var lip_at := Rect2()
	var whole := Rect2()
	# THE DOCK IN FIVE STEPS (Jon, Oct 20: "I want the ship to enter the screen
	# like it does for the first sector"): the steps as they came, your ship on
	# the plate and its engines through each, the lights through each
	var beats: Array[StringName] = []
	var wait_x: Array[float] = []
	var power_end_wake := 0.0
	var warn_end_wake := 0.0
	# (the station all awake by your ship's first moving frame in)
	var power_first_move := -1.0
	var lit_early := 0.0
	var cut_black := 0.0
	var warn_seen := {}
	# THE ARRIVAL'S OWN ENTRANCE: every ARRIVE frame your ship's place and flame
	# against the arrival's own formula on its own row (`ShipView._tick_arrival`,
	# `_flame_window`, `arrive_thrust`) at the arrival's time; off the left edge
	# on its first frame; the thrusts seen; and its clip
	var arr_frames := 0
	var arr_first_off := false
	_dock_rec = []
	var arr_thr := {}
	var arr_end := Rect2()
	var arr_frame0 := -1
	var arr_clip := &""
	var thr_after := {}
	var thr_enter := {}
	var moor := Rect2()
	var idle_bed := false
	# THE CAMERA STILL (Jon, Oct 20: "Why is there so much parallax? The dust
	# shouldn't move as the ship comes in. The station is stationary."): from
	# the dock's first frame to the dip to black, everything LOCAL draws but your
	# ship -- the station's plate and front and their layers, the wreck row, the
	# dust, the effects, the subject, the sky -- where it was, each frame
	var bg0: Array = []
	var bg_frames := 0
	var bg_moved := 0
	var bg_worst := 0.0
	var bg_at := ""
	Audio.taping = true
	Audio.tape.clear()
	var rail_s := {}
	var hall := loc0 != null and loc0._face != null and is_instance_valid(loc0._face)
	var pan_x: Array[float] = []
	var edge_off := 0
	var elevator_seen := 0
	var yard_x: Array[float] = []
	var track: Array = []
	# F (the default): the dip to black, the empty yard up from it
	var fmode := ZoomLadder.seam3_fade() == "F"
	var dip_seen := false
	var dip_at := Rect2()
	var black_top := 0.0
	var empty_up := 0
	for i in 600:
		await _tree.process_frame
		var blk := _black_a()
		black_top = maxf(black_top, blk)
		if hall and Router.current == loc0 and is_instance_valid(loc0):
			last = _ship_on_plate(loc0)
			whole = _fitted_on_plate(loc0)
			if fmode and not dip_seen and blk > 0.02 and (loc0._lad.get("hall", {}) as Dictionary).get("beat", &"") == &"enter":
				dip_seen = true
				dip_at = whole
			var beat: StringName = (loc0._lad.get("hall", {}) as Dictionary).get("beat", &"")
			if beat != &"" and (beats.is_empty() or beats[-1] != beat):
				beats.append(beat)
			var cx := last.get_center().x
			var hd: Dictionary = loc0._lad.get("hall", {})
			var art_d := loc0._view.ship_view()
			var th := art_d._thrust_now() if art_d != null else -9
			if beat != &"" and not dip_seen:
				var bg := _bg_state(loc0)
				if bg0.is_empty():
					bg0 = bg
				else:
					bg_frames += 1
					var off := _bg_off(bg0, bg)
					if off > 0.0:
						bg_moved += 1
						if off > bg_worst:
							bg_worst = off
							bg_at = "%s frame %d" % [beat, bg_frames]
			if beat == &"cut":
				cut_black = maxf(cut_black, float(hd.get("black", 0.0)))
				if moor.size.x <= 0.0:
					moor = last
			if beat == &"arrive" and art_d != null:
				arr_frames += 1
				if arr_frame0 < 0:
					arr_frame0 = Engine.get_process_frames()
					arr_clip = hd.get("clip", &"")
					# (all of it off the view's left edge)
					arr_first_off = art_d.fitted_rect_global().end.x <= loc0._view.get_global_rect().position.x + 0.5
				# (each frame as drawn, for the first LOCAL's arrival to be laid
				# over: `_arrival_is_first_locals`)
				_dock_rec.append([float(hd.get("t_arrive", 0.0)) - float(hd.get("t_called", 0.0)), art_d.position, art_d.scale, art_d.get_global_rect(),
					art_d.fitted_rect_global(), th, art_d._flameout, art_d.is_visible_in_tree(), art_d._arrive_at >= 0])
				arr_thr[th] = true
				arr_end = last
			if loc0._face.power > 0.0 and (beat == &"cut" or beat == &"arrive" or beat == &"beat"):
				lit_early = maxf(lit_early, loc0._face.power)
			if beat == &"beat" or beat == &"power":
				thr_after[th] = true
			if beat == &"enter" and art_d != null and art_d.is_visible_in_tree():
				thr_enter[th] = true
			if beat == &"beat" or beat == &"power":
				wait_x.append(cx)
				idle_bed = idle_bed or Audio.idle_want
			if beat == &"power":
				power_end_wake = loc0._face.power
				warn_end_wake = loc0._face.warn
			elif beat == &"enter" and power_first_move < 0.0 and not wait_x.is_empty() and absf(cx - wait_x[-1]) > 0.01:
				power_first_move = loc0._face.power
			if beat != &"":
				warn_seen[int(floorf(loc0._face.warn))] = true
			if ZoomLadder.busy() and last.size.x > 0.0:
				# (the arrival, the wait and the way in: three pieces, the wait
				# no motion at all)
				# (the arrival's own motion -- whole pixels, eased out to a drift --
				# is held to the arrival's formula above, not to this)
				var tag := "L" if beat == &"enter" else "H"
				if beat != &"cut" and beat != &"arrive" and beat != &"":
					track.append([tag, last.get_center().x, loc0._lad_zs])
			# (behind the front, over the plate, the two in one place)
			var v := loc0._view
			if not (loc0._face.get_index() < v._row.get_index() and v._row.get_index() < loc0._face_front.get_index()) \
					or not loc0._face.get_global_transform().is_equal_approx(loc0._face_front.get_global_transform()) \
					or loc0._face.origin() != loc0._face_front.origin():
				layer_bad += 1
			# (from the ARRIVE on: under the CUT's black your ship is still at its
			# mooring, and the arrival takes it off the left edge)
			if first.size.x <= 0.0 and beat != &"cut" and beat != &"":
				first = last
				# (the station's width on LOCAL, at rest, before the camera moves)
				shown = loc0._view.get_global_rect().end.x - loc0._face.plate_g(Vector2(StationFace.EDGE_X, StationFace.ROW)).x
			if last.size.x > 0.0 and beat != &"cut" and beat != &"":
				tails.append(last.position.x)
				if whole.end.x > StationFace.LIP_X and whole.position.x < StationFace.RECESS.end.x:
					var room := minf(whole.position.y - StationFace.RECESS.position.y, StationFace.RECESS.end.y - whole.end.y)
					if room < lip_room:
						lip_room = room
						lip_at = whole
			power = loc0._face.power
		if Router.current is StationScreen and ZoomLadder.busy() and ZoomLadder.active.phase == ZoomLadder.Phase.MOVE:
			st = Router.current as StationScreen
			if _elevator_seen(st):
				elevator_seen += 1
			if fmode and blk <= 0.01 and not _ship_on_screen(st):
				empty_up += 1
			if not fmode and ZoomLadder.active._u < ZoomLadder.DOCK_PAN_S:
				pan_x.append(st.position.x)
				track.append(["P", -st.position.x, 1.0])
			elif st._mine_view != null and not st._lad.is_empty():
				xs.append(st._mine_view.position.x)
				track.append(["Y", st._mine_view.position.x, 1.0])
				if st._scene != null:
					yard_x.append(st._scene.get_global_rect().position.x)
				# (the elevator's column: the yard's own hall, while it is away)
				if st._scene == null or st._scene._edge == null or not st._scene._edge.visible or st._scene.get_parent().clip_contents:
					edge_off += 1
			if st._rail != null and not st._lad.is_empty() and st._rail.position.x > float(st._lad.rail_x) - 20.0 					and st._rail.modulate.a > 0.01:
				rail_out = false
		# (the elevator's slide, from its first frame: it starts as the yard's
		# flight lands, while the berth's UI is still arriving)
		_rail_sample(Router.current as StationScreen, rail_s)
		if not ZoomLadder.busy() and Router.current is StationScreen:
			break
	Audio.taping = false
	st = Router.current as StationScreen
	if not _ok("3B DOCK lands in the station", st != null and Router.docked):
		return
	if hall:
		var right := true
		for i in range(1, tails.size()):
			if tails[i] < tails[i - 1] - 0.01:
				right = false
		_ok("3B: on LOCAL your ship comes in from off the left (tail at plate x %.0f) and only moves right" % first.position.x,
			tails.size() > 20 and first.end.x < StationFace.EDGE_X and right)
		_ok("3B: the station's lights are all on before the pan (power %.2f)" % power, power >= 0.999)
		_ok("3B: the dock comes in five steps, in order -- the cut to black, your ship's arrival, a beat, the station powers on, your ship goes in: %s" % [beats],
			beats == [&"cut", &"arrive", &"beat", &"power", &"enter"])
		_ok("3B: THE CAMERA STILL -- nothing but your ship moves on LOCAL from the dock's first frame to the dip to black (%d frames; %d with anything else off where it was, at most %.2f px%s)" % [
			bg_frames, bg_moved, bg_worst, ", at " + bg_at if bg_at != "" else ""], bg_frames > 200 and bg_moved == 0)
		_ok("3B CUT: LOCAL goes all the way to black, your ship taken off its mooring in it (%.2f)" % cut_black, cut_black >= 0.99)
		# THE ENTRANCE IS THE ARRIVAL (Jon, Oct 20: "I want the ship to enter the
		# screen like it does for the first sector")
		var arr_s := ShipView.ARRIVE_LEAD_S + ShipView.ARRIVE_MS / 1000.0
		_ok("3B ARRIVE: your ship starts all off the view's left edge (%s) and the arrival is all there (%d frames, %.1f s; the arrival's lead and approach %.1f s)" % [
			arr_first_off, arr_frames, arr_frames / 30.0, arr_s], arr_first_off and arr_frames >= int(arr_s * 30.0) - 1)
		_ok("3B ARRIVE: the flameout sputters down to the idle -- FULL, the coughs, then only the idle from the beat on (%s; through the beat and power-on %s)" % [arr_thr.keys(), thr_after.keys()],
			arr_thr.has(ThrusterFx.Thrust.FULL) and arr_thr.has(ThrusterFx.Thrust.CRUISE) and arr_thr.has(ThrusterFx.Thrust.IDLE)
				and thr_after.keys() == [ThrusterFx.Thrust.IDLE])
		_ok("3B ENTER: its engines lit for the move in (%s, CRUISE %d)" % [thr_enter.keys(), ThrusterFx.Thrust.CRUISE],
			thr_enter.has(ThrusterFx.Thrust.CRUISE))
		_ok("3B ARRIVE: it comes to rest at its mooring, where it sat (plate x %.1f..%.1f; it sat at %.1f..%.1f)" % [
			arr_end.position.x, arr_end.end.x, moor.position.x, moor.end.x], moor.size.x > 1.0 and absf(arr_end.position.x - moor.position.x) < 0.01 and arr_end.size.is_equal_approx(moor.size))
		var wx := 0.0
		if not wait_x.is_empty():
			wx = wait_x.max() - wait_x.min()
		var want := int((ZoomLadder.DOCK_BEAT_S + ZoomLadder.DOCK_POWER_S) * 30.0 * 0.9)
		_ok("3B: STOPPED before the station lights -- no light through the cut and the arrival (at most %.2f), and it holds still through the beat and the power-on (%d frames, at least %d; it moved %.2f plate px along), its idle heard (%s)" % [
			lit_early, wait_x.size(), want, wx, idle_bed], lit_early <= 0.0 and wait_x.size() >= want and wx < 0.5 and idle_bed)
		_ok("3B: the LIGHTS UP before your ship moves in -- all on (power %.2f at the power-on's end, %.2f on your ship's first moving frame in) and the warning lights green (%.1f)" % [
			power_end_wake, power_first_move, warn_end_wake], power_end_wake >= 0.999 and power_first_move >= 0.999 and warn_end_wake >= 2.0)
		_ok("3B: the warning lights flash while your ship waits and go green before it goes in (%s)" % [warn_seen.keys()],
			warn_seen.has(1) and warn_seen.has(2))
		# THE SOUND FOLLOWS THE PICTURE: the arrival's clip, the one `arrive`
		# handed back for its row at this hull's weight, from its start on the
		# ARRIVE's first frame (its lead is the drive before the ship moves), and
		# no other thruster sound
		var clips: Array = []
		for tp: Array in Audio.tape:
			if String(tp[6]).begins_with("thruster_"):
				clips.append([tp[6], int(tp[5]) - arr_frame0, float(tp[7])])
		_ok("3B: the arrival's clip (%s) is heard once, from its start, as the arrival begins (%s)" % [arr_clip, clips],
			arr_clip != &"" and clips.size() == 1 and StringName(clips[0][0]) == arr_clip and absi(int(clips[0][1])) <= 1 and float(clips[0][2]) == 0.0)
		# (seen only in the recess: wholly past its end, inside the hull's rows --
		# the lips' outer rows, solid on every side, `_front_is_plate_less_recess`
		# -- all of it, parts and all, is 0 pixels seen)
		var hull := HULL_ROWS
		_ok("3B: your ship is all the way into the hull, none of it seen, before the hand-off (on the plate %s; hull past the recess from x %.0f)" % [whole, hull.position.x],
			whole.size.x > 1.0 and hull.encloses(whole))
		if fmode:
			_ok("3B F: your ship is out of sight in the hull before the screen starts to dip to black (on the plate %s)" % dip_at,
				dip_seen and dip_at.size.x > 1.0 and hull.encloses(dip_at))
		_ok("3B: on every frame of the approach your ship is drawn between the station's plate and its front, both placed alike (%d frames out)" % layer_bad,
			layer_bad == 0)
		_ok("3B: the station takes %.0f px of LOCAL's width (at most %.0f)" % [shown, StationFace.SHOWN + 1.0], shown <= StationFace.SHOWN + 1.0 and shown > 150.0)
		_ok("3B: %s goes in between the lips at its own size, %.1f px from them at the closest (at least %.0f; at %s)" % [
			Run.hull.name, lip_room, LIP_ROOM, lip_at], lip_room >= LIP_ROOM and lip_room < INF)
	if fmode:
		_ok("3B F: the screen goes all the way to black at the hand-off (%.2f)" % black_top, black_top >= 0.99)
		_ok("3B F: the yard comes up from black empty, and stays empty with the black gone for %d frames (at least 9, 0.3 s)" % empty_up,
			empty_up >= 9)
	else:
		var slid := pan_x.size() > 5
		for i in range(1, pan_x.size()):
			if pan_x[i] > pan_x[i - 1] + 0.01:
				slid = false
		_ok("3B: the pan carries the yard in from the right (%d frames, from x %.0f)" % [pan_x.size(), pan_x[0] if not pan_x.is_empty() else 0.0],
			slid and pan_x[0] > 200.0 and absf(st.position.x) < 0.5)
	var berth := st._mine_view.position.x if st._mine_view != null else 0.0
	var mono := true
	for i in range(1, xs.size()):
		if xs[i] < xs[i - 1] - 0.01:
			mono = false
	_ok("3B: the hull flies in from the left (%d frames, from x %.0f to its berth %.0f)" % [xs.size(),
		xs[0] if not xs.is_empty() else 0.0, berth], xs.size() > 10 and xs[0] < berth - 200.0 and mono)
	_ok("3B: the elevator is out of the picture while it flies", rail_out)
	_one_motion("3B DOCK", track)
	_ok("3B: the elevator is not seen on any frame of the pan or the flight in (%d frames)" % elevator_seen, elevator_seen == 0)
	var yard_moved := false
	var yard_at := st._scene.get_global_rect().position.x if st._scene != null else 0.0
	for x in yard_x:
		if absf(x - yard_at) > 0.5:
			yard_moved = true
	_ok("3B: the yard stands where it always does while the elevator is away (at x %.0f)" % yard_at, not yard_x.is_empty() and not yard_moved)
	_ok("3B: the yard's hall runs on where the elevator will come in (%d frames without it)" % edge_off, edge_off == 0)
	_ok("3B: the hull ends on its stands", xs.is_empty() or absf(xs[-1] - berth) < 1.0)
	await _rail_comes_in(st, rail_s)
	# SEATED WHERE THE YARD SEATS IT (Jon: "DOCKING IS PERFECT!!!! But the ship
	# sits too high on the stands"): the landed hull exactly where the yard's own
	# stand-up (`YardScene._stand`) puts it -- its picture's rect and its ink's
	# underside on the stand tops -- not where it stood before it was seated
	await _frames(4)
	var seat := _yard_seat(st)
	var landed := st._mine_view.get_rect() if st._mine_view != null else Rect2()
	_ok("3B: the landed hull's rect is the yard's own seat (%s, the yard %s)" % [landed, seat],
		seat.size.x > 1.0 and landed.position.is_equal_approx(seat.position) and landed.size.is_equal_approx(seat.size))
	_clean("3B dock")


## What LOCAL draws besides your ship, where it is: the station's plate and
## front (their place, size and layers' parallax), the wreck row, the dust, the
## effects, the subject (place and size), the sky's zoom and the scene's.
func _bg_state(lc: SectorScreen) -> Array:
	var out: Array = []
	for c: Control in [lc._face, lc._face_front, lc._view._row, lc._view.dust, lc._view.fx, LocalSubject.of(lc._view)]:
		if c != null and is_instance_valid(c):
			out.append(c.get_global_transform())
	for f: StationFace in [lc._face, lc._face_front]:
		if f != null and is_instance_valid(f):
			out.append(f.par.duplicate())
			out.append(f.origin())
	out.append(lc._view.backdrop.zoom if lc._view.backdrop != null else 1.0)
	out.append(lc._lad_zs)
	return out


## How far the background in `b` stands from `a`, px (any parallax step or
## zoom counted as its own size).
func _bg_off(a: Array, b: Array) -> float:
	if a.size() != b.size():
		return 999.0
	var worst := 0.0
	for i in a.size():
		var x: Variant = a[i]
		var y: Variant = b[i]
		if x is Transform2D:
			var tx := x as Transform2D
			var ty := y as Transform2D
			worst = maxf(worst, tx.origin.distance_to(ty.origin))
			worst = maxf(worst, absf(tx.get_scale().x - ty.get_scale().x) * 1000.0)
		elif x is Vector2:
			worst = maxf(worst, (x as Vector2).distance_to(y as Vector2))
		elif x is Dictionary:
			if x != y:
				worst = maxf(worst, 1.0)
		else:
			worst = maxf(worst, absf(float(x) - float(y)) * 1000.0)
	return worst


## THE DOCK'S ARRIVAL, frame by frame as `_hull_flies_in` saw it: [its time,
## position, scale, rect, everything bolted on, flame, flameout row, shown,
## still arriving].
var _dock_rec: Array = []
## THE FIRST LOCAL'S ARRIVAL on the same LOCAL, by frame (`_first_locals`):
## [position, scale, rect, everything bolted on, shown, still arriving, the
## flame on each flameout row].
var _first_rec: Array = []


## THE FIRST LOCAL'S ARRIVAL, recorded where the dock will start (Jon, Oct 20:
## "Why doesn't the ship enter like the first local?"): on LOCAL at the
## station, the arrival a run's first system plays (`SectorScreen._begin_arrive`,
## name card and all), stepped (`arrive_step`) to every 1/30 s after its card,
## the flame read on every flameout row; then put away, the ship at rest.
func _first_locals() -> void:
	_first_rec = []
	var loc := Router.current as SectorScreen
	if loc == null:
		return
	var art := loc._view.ship_view()
	loc._begin_arrive()
	art.arrive_driven = true
	var n := int(ceilf((ShipView.ARRIVE_LEAD_S + ShipView.ARRIVE_MS / 1000.0) * 30.0)) + 4
	for k in n:
		var t := float(k) / 30.0 + SectorScreen.CARD_TOTAL
		var thr: Array = []
		var still := false
		var rec: Array = []
		for row in ShipView.FLAMEOUTS.size():
			if art._arrive_at < 0:
				thr.append(art._thrust_now())
				continue
			art._flameout = row
			art.arrive_step(t)
			thr.append(art._thrust_now())
			if rec.is_empty():
				still = art._arrive_at >= 0
				rec = [art.position, art.scale, art.get_global_rect(), art.fitted_rect_global(), art.is_visible_in_tree(), still]
		if rec.is_empty():
			rec = [art.position, art.scale, art.get_global_rect(), art.fitted_rect_global(), art.is_visible_in_tree(), false]
		rec.append(thr)
		_first_rec.append(rec)
	if loc._cine != null and loc._cine.is_valid():
		loc._cine.kill()
	loc._drop_card()
	loc._phase = SectorScreen.Phase.NONE
	loc._open_drawer(true)
	art.park()
	art.refresh()
	await _frames(3)


## THE DOCK'S ARRIVAL IS THE FIRST LOCAL'S: laid over it frame by frame -- your
## ship in the same place, at the same size, with the same flame on its row,
## shown alike, on every one of the dock's arrival frames (once it rests, its
## idle bob runs on the game's clock: its place and size then, the phase aside).
func _arrival_is_first_locals() -> void:
	if not _ok("first LOCAL's arrival recorded (%d frames) and the dock's (%d)" % [_first_rec.size(), _dock_rec.size()],
			not _first_rec.is_empty() and not _dock_rec.is_empty()):
		return
	var bad := 0
	var at := ""
	for r: Array in _dock_rec:
		var k := int(roundf(float(r[0]) * 30.0))
		if k < 0 or k >= _first_rec.size():
			bad += 1
			continue
		var f: Array = _first_rec[k]
		var fr: Rect2 = f[3]
		var fr0: Rect2 = r[4]
		var fit_same := fr.is_equal_approx(fr0) if bool(r[8]) else (is_equal_approx(fr.position.x, fr0.position.x) and fr.size.is_equal_approx(fr0.size))
		var thr := int((f[6] as Array)[int(r[6])])
		var same: bool = f[0] == r[1] and f[1] == r[2] and (f[2] as Rect2).position.x == (r[3] as Rect2).position.x 			and (f[2] as Rect2).size == (r[3] as Rect2).size and fit_same and thr == int(r[5]) and bool(f[4]) == bool(r[7])
		if not same:
			bad += 1
			if at == "":
				at = "frame %d: %s %s %s thrust %d (the dock's %s %s %s thrust %d)" % [k, f[0], f[1], fr, thr, r[1], r[2], fr0, int(r[5])]
	_ok("3B ARRIVE IS THE FIRST LOCAL'S: your ship in the same place, at the same size, with the same flame on every one of the dock's %d arrival frames (%d differ%s)" % [
		_dock_rec.size(), bad, "; first " + at if at != "" else ""], bad == 0)


## A PRESS MID-DOCK, the plain version (`ZoomLadder.finish_now`): a key mid-
## arrival lands in the berth at once -- the elevator already in its place, no
## slide, the arrival parked -- and UNDOCK goes back.
func _dock_skipped(dock_b: Button) -> void:
	var loc := Router.current as SectorScreen
	var art := loc._view.ship_view() if loc != null else null
	dock_b.pressed.emit()
	var in_fly := false
	for i in 120:
		await _tree.process_frame
		if loc != null and is_instance_valid(loc) and not loc._lad.is_empty() 				and (loc._lad.get("hall", {}) as Dictionary).get("beat", &"") == &"arrive" 				and float((loc._lad.get("hall", {}) as Dictionary).get("t_arrive", 0.0)) > ShipView.ARRIVE_LEAD_S + 0.5:
			in_fly = true
			break
	var k := InputEventKey.new()
	k.keycode = KEY_SHIFT
	k.physical_keycode = KEY_SHIFT
	k.pressed = true
	Input.parse_input_event(k)
	await _frames(1)
	var u := k.duplicate() as InputEventKey
	u.pressed = false
	Input.parse_input_event(u)
	var n := await _idle()
	await _frames(2)
	var st := Router.current as StationScreen
	_ok("3B: a key mid-arrival (%s) lands in the berth at once (%d frames), the elevator in its place with no slide" % [in_fly, n],
		in_fly and n >= 0 and n <= 3 and st != null and Router.docked and st._rail_slide == null and st._rail_back == null
			and PanelSlide.live.is_empty())
	_ok("3B: and nothing of the arrival is left on your ship (parked, not driven)", art == null or not is_instance_valid(art)
		or (art._arrive_at < 0 and not art.arrive_driven))
	_clean("3B dock, skipped")
	Router.show_sector()
	await _idle()
	_ok("3B: UNDOCK after the skipped dock lands on LOCAL", Router.current is SectorScreen and not Router.docked)


## THE ELEVATOR, AFTER YOUR SHIP IS IN, LIKE THE GAME'S OTHER PANELS (Jon, Oct
## 20: "The left panel coming into the station doesn't come in correctly"):
## it starts only once the yard's flight is done (the yard's `_lad` empty on its first
## frame), slides as a `PanelSlide` on the panels' curve, in whole pixels, only
## ever right, carrying its ground (`_RailBack`) with it so the yard's hall is
## never seen through it nor gone from under it at once; nothing on it takes a
## click while it moves; and it lands in its place, the hall gone.
func _rail_comes_in(st: StationScreen, rs: Dictionary) -> void:
	if st._rail == null:
		return
	_ok("3B: the elevator comes in only after your ship is on its stands (its slide's first frame %d, the yard's flight %s)" % [
		int(rs.get("from", -1)), "still on" if bool(rs.get("lad", true)) else "done"], int(rs.get("from", -1)) >= 0 and not bool(rs.get("lad", true)))
	var tab0: StringName = st._tab
	for i in 120:
		if st._rail_slide == null:
			break
		_rail_sample(st, rs)
		await _tree.process_frame
	var xs: Array = rs.get("xs", [])
	var whole := bool(rs.get("whole", true))
	var right := bool(rs.get("right", true))
	var ground := bool(rs.get("ground", true))
	var blocked := bool(rs.get("blocked", true))
	var n := xs.size()
	var want := int(ZoomLadder.CALM_SLIDE_S * 30.0)
	_ok("3B: the elevator slides in as the other panels do, %d frames (%d is `CALM_SLIDE_S`), whole pixels %s, only right %s, from off the view's left (%.0f -> %.0f)" % [
		n, want, whole, right, xs[0] if n > 0 else 0.0, xs[-1] if n > 0 else 0.0],
		n >= want - 2 and n <= want + 3 and whole and right and n > 0 and xs[0] < -100.0)
	_ok("3B: the elevator carries its ground with it, just under it, on every frame it slides", ground and n > 0)
	_ok("3B: nothing on the elevator takes a click while it slides", blocked and n > 0)
	var hall_off := st._scene == null or st._scene._edge == null or not st._scene._edge.visible
	_ok("3B: it lands in its place, on a whole pixel, its ground and the yard's hall in its column gone (x %.1f, hall shown %s)" % [
		st._rail.get_global_rect().position.x, not hall_off],
		st._rail_slide == null and st._rail_back == null and st._rail_block == null and hall_off and PanelSlide.live.is_empty()
			and absf(st._rail.position.x - roundf(st._rail.position.x)) < 0.001 and st._tab == tab0)


## One frame of the elevator's slide, if it is sliding, into `rs`: where it is,
## and whether it is on a whole pixel, only going right, its ground moved with
## it just under it, and nothing on it clickable.
func _rail_sample(st: StationScreen, rs: Dictionary) -> void:
	if st == null or st._rail == null or st._rail_slide == null:
		return
	if not rs.has("xs"):
		rs.xs = []
		rs.from = Engine.get_process_frames()
		rs.lad = not st._lad.is_empty()
	var xs: Array = rs.xs
	var gx := st._rail.get_global_rect().position.x
	xs.append(gx)
	if absf(gx - roundf(gx)) > 0.001:
		rs.whole = false
	if xs.size() > 1 and gx < float(xs[-2]) - 0.001:
		rs.right = false
	var bk := st._rail_back
	var under := bk != null and is_instance_valid(bk) and (bk.z_index < st._rail.z_index
		or (bk.z_index == st._rail.z_index and bk.get_index() == 0) or st._rail.modulate.a <= 0.0)
	if not under or absf((bk.position.x - st._rail_back_x0) - (st._rail.position.x - st._rail_slide.rest.x)) > 0.001:
		rs.ground = false
	if st._rail_block == null or not is_instance_valid(st._rail_block) or st._rail_block.mouse_filter != Control.MOUSE_FILTER_STOP:
		rs.blocked = false


## 3B, UNDOCKING: the elevator out first, then the hull off to the left; the pan
## the other way, LOCAL coming in from the left; your ship from the bay back out
## of the hallway, never back in, and the station's lights down behind it.
func _hull_flies_out() -> void:
	var st := Router.current as StationScreen
	if st == null:
		return
	var rail0 := st._rail.position.x if st._rail != null else 0.0
	var ship0 := st._mine_view.position.x if st._mine_view != null else 0.0
	Router.show_sector()
	var rail_first := true
	var left := false
	var noses: Array[float] = []
	var pan_x: Array[float] = []
	var last_seen := false
	var tails0 := 0.0
	var track: Array = []
	var fmode := ZoomLadder.seam3_fade() == "F"
	var empty_down := 0
	var black_last := 0.0
	for i in 600:
		await _tree.process_frame
		var blk := _black_a()
		if Router.current == st and is_instance_valid(st):
			last_seen = _elevator_seen(st)
			black_last = blk
			if fmode and ZoomLadder.busy() and not _ship_on_screen(st) and blk < 0.99 and (st._rail == null or st._rail.modulate.a < 0.01):
				empty_down += 1
			# (once the elevator is out: the hull's flight off its stands)
			if ZoomLadder.busy() and st._mine_view != null and (st._rail == null or st._rail.modulate.a < 0.01):
				track.append(["Y", -st._mine_view.position.x, 1.0])
		var c := Router.current as SectorScreen
		if c != null and ZoomLadder.busy() and ZoomLadder.active.phase == ZoomLadder.Phase.MOVE:
			if not fmode and ZoomLadder.active._u < ZoomLadder.DOCK_PAN_S:
				pan_x.append(c.position.x)
				track.append(["P", c.position.x, 1.0])
			elif c._face != null and is_instance_valid(c._face) and not c._lad.is_empty():
				var r := _ship_on_plate(c)
				if r.size.x > 1.0:
					track.append(["L", -r.get_center().x, c._lad_zs])
					if noses.is_empty():
						tails0 = r.position.x
					noses.append(r.end.x)
		if Router.current == st and is_instance_valid(st) and st._mine_view != null:
			var gone := st._rail == null or st._rail.position.x < rail0 - 20.0
			if st._mine_view.position.x < ship0 - 5.0 and not gone:
				rail_first = false
			if st._mine_view.position.x < ship0 - 100.0:
				left = true
		if not ZoomLadder.busy() and Router.current is SectorScreen:
			break
	_ok("3B UNDOCK: the elevator goes before the hull moves", rail_first)
	_one_motion("3B UNDOCK", track)
	_ok("3B UNDOCK: the elevator is all the way out before the pan", not last_seen)
	_ok("3B UNDOCK: the hull leaves to the left", left)
	if fmode:
		_ok("3B F UNDOCK: the empty yard holds, then slowly goes to black, before LOCAL (%d frames empty; black %.2f at the hand-off)" % [empty_down, black_last],
			empty_down >= 9 and black_last >= 0.99)
	else:
		var slid := pan_x.size() > 5
		for i in range(1, pan_x.size()):
			if pan_x[i] < pan_x[i - 1] - 0.01:
				slid = false
		_ok("3B UNDOCK: the pan brings LOCAL in from the left (%d frames, from x %.0f)" % [pan_x.size(), pan_x[0] if not pan_x.is_empty() else 0.0],
			slid and pan_x[0] < -200.0)
	if not noses.is_empty():
		var back_in := false
		for i in range(1, noses.size()):
			if noses[i] > noses[i - 1] + 0.5:
				back_in = true
		_ok("3B UNDOCK: your ship starts inside the hull (tail at plate x %.0f) and flies out through the lips (nose to %.0f), never back in" % [
			tails0, noses[-1]], tails0 >= StationFace.RECESS.end.x and noses[-1] < StationFace.SLOT.position.x and not back_in)
	_ok("3B UNDOCK lands on LOCAL, undocked", Router.current is SectorScreen and not Router.docked)
	var lc2 := Router.current as SectorScreen
	if lc2 != null and lc2._face != null:
		_ok("3B UNDOCK: the station's lights are back on standby (power %.2f)" % lc2._face.power, lc2._face.power <= 0.001)
	_clean("3B undock")


## NO FIGHTS AT A STATION (Jon: "There should never be fights at stations."):
## nothing can start one there, nothing is rolled to jump you there, the
## Hellbender never stops at one, and so no wreck is left at one.
func _no_fights_at_stations(st: int) -> void:
	var was := Run.at
	Run.at = st
	var n: MapGen.MapNode = Run.map[st]
	n.ambush_rolled = false
	n.ambush_pending = false
	Router._roll_ambush(n)
	_ok("station: nothing is rolled to jump you there", not n.ambush_pending)
	Router.start_ambush()
	_ok("station: an ambush cannot start there", not Router.in_combat())
	Router.start_combat(DB.enemies[&"cutter"])
	_ok("station: no fight can start there, whoever asks", not Router.in_combat())
	Router.engage_here()
	_ok("station: ENGAGE starts nothing there", not Router.in_combat())
	var wrecks := 0
	for raw in n.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			wrecks += 1
	_ok("station: no wreck is left there", wrecks == 0)
	# the Hellbender: placed and moved many times over, never at a station
	var at0 := Run.hellbender_at
	var hp0 := Run.hellbender_hp
	var ever := false
	Run._spawn_hellbender()
	for m in 400:
		if Run.hellbender_at >= 0 and Run.map[Run.hellbender_at].type == MapGen.NodeType.STATION:
			ever = true
		if Run.hellbender_at >= 0:
			Run._hellbender_step(m % 2 == 0)
	Run.hellbender_at = at0
	Run.hellbender_hp = hp0
	_ok("station: the Hellbender never stops at one (placed, then 400 moves)", not ever)
	Run.at = was


## EVERY SIDE JON KEPT (`StationSides`), docked into and undocked from, each
## with an interior (Drum take 1 with its own bay): the hallway, the
## mask, the seat and the elevator checks above for every one, and the far
## layers' parallax in whole pixels that only ever grow as the camera comes in
## (no A, B, A), back to none at rest.
func _every_side() -> void:
	# EVERY WEIGHT (Jon: "how do large ships look going into the station?"): the
	# light, the medium and the heavy, every mount filled (turrets and pods on,
	# the tallest each can be), at every side
	for w in [HullData.Weight.MEDIUM, HullData.Weight.LIGHT, HullData.Weight.HEAVY]:
		Run.fit_chassis(&"korvan", w)
		_fit_full()
		print("  -- weight: %s" % Run.hull.name)
		await _every_side_once()
	Run.fit_chassis(&"korvan", HullData.Weight.MEDIUM)


## Every mount filled with the hull's own manufacturer's parts (`StationShot`'s
## `fit=full` rule): couplings first, then the smallest draw, different parts
## before repeats, only what the reactor runs.
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


func _every_side_once() -> void:
	var ints := [StationSides.NONE, &"hallway_130_0", &"hallway_170_1", &"cargo_170_0", &"cargo_90_0", &"hallway_90_1", &"cargo_130_1"]
	# (and Drum take 1 as approved, unlit, kept to compare: its dock still whole)
	var ids: Array = StationSides.IDS.duplicate()
	for i in ids.size():
		var id: StringName = ids[i]
		StationSides.force_side = id
		StationSides.force_interior = ints[i % ints.size()]
		print("  -- side %s, interior %s" % [id, StationSides.force_interior])
		# (LOCAL built again, so its face is this side)
		await _go("%s: to the map" % id, Router.show_system, SystemMapScreen)
		await _go("%s: to LOCAL at the station" % id, Router.show_local, SectorScreen)
		var loc := Router.current as SectorScreen
		if not _ok("%s: LOCAL draws it" % id, loc != null and loc._face != null and loc._face.side.id == id
				and loc._face_front.side == loc._face.side):
			continue
		var dock_b: Button = loc.find_child("Dock", true, false) as Button
		if dock_b == null:
			_ok("%s: DOCK on the bar" % id, false)
			continue
		var steps: Array = []
		var watch := func() -> void:
			var c := Router.current as SectorScreen
			if c != null and c._face_front != null and is_instance_valid(c._face_front) and c._face_front.dock_k > 0.0:
				steps.append([c._face_front.get_instance_id(), c._face_front.par.duplicate()])
		_tree.process_frame.connect(watch)
		await _hull_flies_in(dock_b)
		await _hull_flies_out()
		_tree.process_frame.disconnect(watch)
		var side := StationSides.side(id)
		var far: Array = []
		for l: Array in side.layers:
			if float(l[1]) < 1.0:
				far.append(float(l[1]))
		if far.is_empty():
			continue
		var flips := 0
		var top := 0
		var whole := true
		# (the dock's face is the first seen moving: its layers, the camera
		# still, never move at all)
		var dock_face: int = int(steps[0][0]) if not steps.is_empty() else -1
		var dock_top := 0
		for e: Array in steps:
			if int(e[0]) == dock_face:
				for p in far:
					dock_top = maxi(dock_top, absi(int((e[1] as Dictionary).get(p, 0))))
		# (each face on its own, over its moving frames: the undock's, the
		# camera following your ship back out; at rest it is none, checked below)
		for p in far:
			var last := 0
			var dir := 0
			var who := -1
			for e: Array in steps:
				if int(e[0]) == dock_face:
					continue
				var v: Variant = (e[1] as Dictionary).get(p, 0)
				if e[0] != who:
					who = e[0]
					dir = 0
					last = int(v)
				if typeof(v) != TYPE_INT:
					whole = false
				var x := int(v)
				top = maxi(top, absi(x))
				if x != last:
					var d := signi(x - last)
					if dir != 0 and d != dir:
						flips += 1
					dir = d
					last = x
		if flips > 0:
			var seq := ""
			for e: Array in steps:
				seq += "%d:%d " % [int(e[0]) % 1000, int((e[1] as Dictionary).get(far[0], 0))]
			print("    parallax steps (%s): %s" % [far[0], seq])
		var lc := Router.current as SectorScreen
		# (docking the camera stays where it is -- Jon, Oct 20: "The station is
		# stationary" -- so its layers have no parallax to show: none at all)
		_ok("%s: its far layers stand still while your ship docks, the camera still (at most %d px)" % [id, dock_top],
			dock_face >= 0 and dock_top == 0)
		_ok("%s: undocking, its far layers move in whole pixels, at most %d (no more than 8), never turning back mid-move (%d times)" % [id, top, flips],
			whole and top > 0 and top <= 8 and flips == 0)
		_ok("%s: and none at rest" % id, lc != null and lc._face_front != null and lc._face_front.par.is_empty())
	StationSides.force_side = &""
	StationSides.force_interior = &""
	await _go("back to the map (every side)", Router.show_system, SystemMapScreen)
	await _go("back to LOCAL (every side)", Router.show_local, SectorScreen)


## WHICH SIDE A STATION GETS: from the station alone. Asked twice it answers the
## same; it rolls nothing (the run's random streams where they were); every
## station gets a kept side and interior; and the map's stations do not all
## look alike.
func _station_picks() -> void:
	var stations: Array = []
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			stations.append(n)
	var rng0 := var_to_str(Rng.state())
	var same := true
	var valid := true
	var sides := {}
	for n: MapGen.MapNode in stations:
		var a := StationSides.pick(n)
		var b := StationSides.pick(n)
		if a != b:
			same = false
		if not StationSides.IDS.has(a.side) or not StationSides.INTERIORS.has(a.interior):
			valid = false
		sides[a.side] = true
	_ok("stations: the same side and interior every time asked (%d stations)" % stations.size(), same)
	_ok("stations: every one a kept side with a kept interior", valid)
	_ok("stations: %d different sides among %d stations" % [sides.size(), stations.size()],
		sides.size() >= mini(stations.size(), StationSides.IDS.size()))
	_ok("stations: picking rolls nothing", rng0 == var_to_str(Rng.state()))
	# (drawn from its own pictures: every side and interior loads)
	var loads := true
	for id in StationSides.IDS:
		var s := StationSides.side(id)
		if s == null or s.solid == null or s.lamps == null or s.bay_lit == null or s.layers.is_empty():
			loads = false
	for id in StationSides.INTERIORS:
		if StationSides.interior(id).size() != 2:
			loads = false
	_ok("stations: all %d sides and %d interiors load" % [StationSides.IDS.size(), StationSides.INTERIORS.size()], loads)


## THE STATION'S FRONT IS ITS PLATE LESS THE RECESS: on every side the crevice
## layer under the front is solid wherever any layer is
## drawn, nothing of the front (layers, lamps) is in the recess, and the
## lips' rows (`HULL_ROWS`) are solid hull from the recess's end to the plate's cut and
## across the window tiled past it -- so your ship, flying on into the hull, is
## never seen through it.
func _front_is_plate_less_recess() -> void:
	for id in StationSides.IDS:
		var s := StationSides.side(id)
		var solid := s.solid.get_image()
		var open := 0
		var inside := 0
		var texs: Array = [s.lamps]
		for l: Array in s.layers:
			texs.append(l[0])
		for t: Texture2D in texs:
			var img := t.get_image()
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).a <= 0.0:
						continue
					if StationFace.RECESS.has_point(Vector2(x, y)):
						inside += 1
					elif t != s.lamps and solid.get_pixel(x, y).a < 0.99:
						open += 1
		var holes := 0
		for y in range(int(HULL_ROWS.position.y), int(HULL_ROWS.end.y)):
			for x in range(int(StationFace.RECESS.end.x), int(s.hull_x0)):
				if solid.get_pixel(x, y).a < 0.99:
					holes += 1
			for x in range(int(s.hull_src.position.x), int(s.hull_src.end.x)):
				if solid.get_pixel(x, y).a < 0.99:
					holes += 1
		_ok("station %s: the crevice under every layer (%d open), nothing in the recess (%d), the hallway's rows solid past it (%d holes)" % [
			id, open, inside, holes], open == 0 and inside == 0 and holes == 0)


## THE HULL PAST THE RECESS that hides your ship once it is in: from the upper
## lip's outer edge to the lower lip's (rows 196..341), from the recess's end on;
## solid on every side (`_front_is_plate_less_recess`).
const HULL_ROWS := Rect2(212, 196, 2000, 146)
## ONE MOUTH FOR EVERY SHIP: how close, at the least, any ship (hull and parts)
## may come to the lips as it passes them (px).
const LIP_ROOM := 2.0


## Your ship whole on the station's plate -- its hull's ink and every part bolted
## on (`ShipView.fitted_rect_global`), plate px, as LOCAL draws it now.
func _fitted_on_plate(lc: SectorScreen) -> Rect2:
	var art := lc._view.ship_view() if lc._view != null else null
	if art == null or lc._face == null:
		return Rect2()
	var g := art.fitted_rect_global()
	var to_plate := lc._face.get_global_transform().affine_inverse()
	var a := to_plate * g.position - lc._face.origin()
	var b := to_plate * g.end - lc._face.origin()
	return Rect2(a, b - a).abs()


## ONE SMOOTH MOTION (Jon: "can we make the movement one smooth motion"): what
## carries the move, frame by frame -- your ship along the hallway (LOCAL, its
## plate px times the zoom), the pan (P), your ship in the yard -- in screen px
## a frame. Each piece, from its first movement to its last, never drops below a
## floor (no stop mid-piece) and never jumps against its neighbours (no spike);
## a piece starting where the last ended on screen (the hallway into the pan)
## starts at the speed it ended on. (F's black between the hallway and the yard
## is no piece: your ship is out of sight through it.)
func _one_motion(what: String, track: Array) -> void:
	var pieces: Array = []
	var tags: Array = []
	var cur: Array[float] = []
	for i in range(1, track.size()):
		var a: Array = track[i - 1]
		var b: Array = track[i]
		if a[0] != b[0]:
			pieces.append(cur)
			tags.append(a[0])
			cur = []
			continue
		cur.append((float(b[1]) - float(a[1])) * float(b[2]))
	if not track.is_empty():
		pieces.append(cur)
		tags.append((track[-1] as Array)[0])
	var lo := INF
	var spikes := 0
	var top := 0.0
	var report := ""
	for pi in pieces.size():
		var v: Array = pieces[pi]
		var first := -1
		var last := -1
		# (a piece from rest is allowed its frames gathering speed up to the
		# floor, and one to rest its frames below it at the end: mid-piece is
		# between the first and last frames above the floor)
		for i in v.size():
			if float(v[i]) > ONE_MOTION_FLOOR:
				if first < 0:
					first = i
				last = i
		if first < 0:
			continue
		var plo := INF
		for i in range(first, last + 1):
			plo = minf(plo, float(v[i]))
			if i > 0 and i < v.size() - 1 and float(v[i]) > 2.0 * maxf(float(v[i - 1]), float(v[i + 1])) + 1.0:
				spikes += 1
		for x in v:
			top = maxf(top, float(x))
		lo = minf(lo, plo)
		report += " %s %.1f..%.1f" % [tags[pi], float(v[first]), float(v[last])]
	var joined := true
	var joins := ""
	for pi in range(1, pieces.size()):
		var pair := "%s%s" % [tags[pi - 1], tags[pi]]
		if not (pair in ["LP", "PL"]) or (pieces[pi - 1] as Array).is_empty() or (pieces[pi] as Array).is_empty():
			continue
		var before := float((pieces[pi - 1] as Array)[-1])
		var after := float((pieces[pi] as Array)[0])
		joins += " %s %.1f->%.1f" % [pair, before, after]
		if absf(after - before) > 0.4 * maxf(absf(before), absf(after)) + 1.0:
			joined = false
	_ok("%s: one smooth motion -- each piece (%s) never below %.1f px a frame mid-piece (lowest %.1f), %d spikes, peak %.1f; joins%s" % [
		what, report.strip_edges(), ONE_MOTION_FLOOR, lo, spikes, top, joins if joins != "" else " (none on screen)"],
		lo >= ONE_MOTION_FLOOR and spikes == 0 and joined)


const ONE_MOTION_FLOOR := 0.4


## The ladder's black over the screens now (F's dip), 0 when there is none.
## Where the yard seats your hull: the rect `YardScene._stand` gives its view
## (the picture's corner from the ink's place, the stands' top), Rect2() if none.
func _yard_seat(st: StationScreen) -> Rect2:
	if st == null or st._scene == null or st._scene.placed.is_empty():
		return Rect2()
	var P: Dictionary = st._scene.placed[0]
	if P.is_empty():
		return Rect2()
	var ink: Rect2i = P["ink"]
	var img: Image = P["img"]
	return Rect2(Vector2(float(P["x0"]) - ink.position.x, float(P["top"]) - ink.position.y), Vector2(img.get_size()))


func _black_a() -> float:
	if not ZoomLadder.busy() or ZoomLadder.active._black == null or not is_instance_valid(ZoomLadder.active._black):
		return 0.0
	return ZoomLadder.active._black.color.a if ZoomLadder.active._black.visible else 0.0


## Whether your ship in the yard is on the picture at all (its ink).
func _ship_on_screen(st: StationScreen) -> bool:
	var art := st._mine_view
	if art == null or not is_instance_valid(art) or not art.is_visible_in_tree():
		return false
	var ink := Rect2(art.ink_rect())
	var xf := art.get_global_transform()
	var r := Rect2(xf * art.canvas_to_local(ink.position), Vector2.ZERO).expand(xf * art.canvas_to_local(ink.end))
	return r.intersects(Rect2(Vector2.ZERO, Vector2(960, 540)))


## Whether the yard's elevator can be seen: drawn, and on the screen at all.
func _elevator_seen(st: StationScreen) -> bool:
	var r := st._rail
	if r == null or not is_instance_valid(r) or not r.is_visible_in_tree() or r.modulate.a < 0.01:
		return false
	return r.get_global_rect().intersects(Rect2(Vector2.ZERO, Vector2(960, 540)))


## Your ship's ink on the station's plate (plate px), as LOCAL draws it now.
func _ship_on_plate(lc: SectorScreen) -> Rect2:
	var art := lc._view.ship_view() if lc._view != null else null
	if art == null or lc._face == null:
		return Rect2()
	var ink := Rect2(art.ink_rect())
	var to_plate := lc._face.get_global_transform().affine_inverse()
	var a := to_plate * (art.get_global_transform() * art.canvas_to_local(ink.position)) - lc._face.origin()
	var b := to_plate * (art.get_global_transform() * art.canvas_to_local(ink.end)) - lc._face.origin()
	return Rect2(a, b - a).abs()


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

	# 1. the four distances, out and back in: THE CALM MOVE (Jon's pick, Oct 17,
	# `-- sheet=CalmLadderTest` watches it frame by frame), then, behind the
	# switch (`calm_force`, a player's `-- calm=off`), every design of every seam as it was
	await _go("calm LOCAL -> map", Router.show_system, SystemMapScreen)
	await _go("calm map -> chart", Router.show_starchart, StarchartScreen)
	await _go("calm chart -> map", Router.show_system, SystemMapScreen)
	await _go("calm map -> LOCAL", Router.show_local, SectorScreen)
	await _go("calm LOCAL -> chart (two distances)", Router.show_starchart, StarchartScreen)
	await _go("calm chart -> LOCAL (two distances)", Router.show_local, SectorScreen)
	ZoomLadder.calm_force = 0
	for d in ["A", "B", "C"]:
		ZoomLadder.force_design = {1: d, 2: d, 3: d}
		await _go("%s LOCAL -> map" % d, Router.show_system, SystemMapScreen)
		await _go("%s map -> chart" % d, Router.show_starchart, StarchartScreen)
		await _go("%s chart -> map" % d, Router.show_system, SystemMapScreen)
		await _go("%s map -> LOCAL" % d, Router.show_local, SectorScreen)
	ZoomLadder.force_design = {}
	await _go("LOCAL -> chart (two distances)", Router.show_starchart, StarchartScreen)
	await _go("chart -> LOCAL (two distances)", Router.show_local, SectorScreen)
	ZoomLadder.calm_force = -1

	# 1c. THE CALM MOVE BUILDS THE SCREEN ARRIVING AT THE CLICK, as 2C did LOCAL:
	# the one shown is the one built ahead, and the run is written once it lands
	await _go("calm LOCAL -> map, for the way back", Router.show_system, SystemMapScreen)
	for want: Array in [[Router.show_local, SectorScreen, "LOCAL"], [Router.show_starchart, StarchartScreen, "the chart"]]:
		(want[0] as Callable).call()
		var built: Control = ZoomLadder.prebuilt
		_ok("calm: %s built at the click" % want[2], built != null and built.get_script() == want[1])
		var mid := false
		for i in 400:
			await _tree.process_frame
			if Router.current == built and ZoomLadder.busy() and ZoomLadder.save_after:
				mid = true
			if not ZoomLadder.busy():
				break
		_ok("calm: the %s built ahead is the one shown" % want[2], Router.current == built and built != null)
		_ok("calm: the run is written when the move lands, not mid-move (%s)" % want[2], mid and not ZoomLadder.save_after)
		_clean("calm built ahead (%s)" % want[2])
		await _go("calm back to the map", Router.show_system, SystemMapScreen)
	await _go("calm back to LOCAL", Router.show_local, SectorScreen)

	# 1a. 2C BUILDS LOCAL AT THE CLICK (Jon: "2C still has a small delay/hitch"):
	# the screen that arrives is the one built ahead, before anything moved, and
	# the run is written when the move lands, not in the middle of it
	ZoomLadder.calm_force = 0
	ZoomLadder.force_design = {2: "C"}
	await _go("2C LOCAL -> map, for the way back", Router.show_system, SystemMapScreen)
	Router.show_local()
	var ahead: Control = ZoomLadder.prebuilt
	_ok("2C: LOCAL built at the click", ahead is SectorScreen)
	var saved_mid := false
	for i in 240:
		await _tree.process_frame
		if Router.current == ahead and ZoomLadder.busy() and ZoomLadder.save_after:
			saved_mid = true
		if not ZoomLadder.busy():
			break
	_ok("2C: the LOCAL built ahead is the one shown", Router.current == ahead and ahead != null)
	_ok("2C: the run is written when the move lands, not mid-move", saved_mid and not ZoomLadder.save_after)
	_clean("2C built ahead")
	ZoomLadder.force_design = {}

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
	ZoomLadder.calm_force = -1

	# 2. THE CALM MOVE: a key mid-move hurries it to its end -- never a cut, and
	# not lost -- landing at rest within a quarter of a second or so
	if not Router.current is SectorScreen:
		await _go("calm to LOCAL (for the key)", Router.show_local, SectorScreen)
	Router.show_system()
	for i in 200:
		if ZoomLadder.busy() and String(ZoomLadder.Phase.keys()[ZoomLadder.active.phase]) == "C_CAM":
			break
		await _tree.process_frame
	await _frames(6)
	var ck := InputEventKey.new()
	ck.keycode = KEY_SHIFT
	ck.pressed = true
	Input.parse_input_event(ck)
	var hurried := -1
	for i in 120:
		await _tree.process_frame
		if not ZoomLadder.busy():
			hurried = i
			break
	_ok("calm: a key mid-move hurries it to its end in %.2f s (not a cut: more than 2 frames; under 0.45 s)" % (hurried / 30.0),
		hurried > 2 and hurried / 30.0 <= 0.45)
	var cm := Router.current as SystemMapScreen
	_clean("calm after the key")
	if cm != null:
		_ok("and the map is at rest (zoom %.2f, its fit %.2f)" % [cm.view.zoom, cm.zoom_min], absf(cm.view.zoom - cm.zoom_min) < 0.01)
	await _go("back to LOCAL (the old flow's key)", Router.show_local, SectorScreen)
	# the old flow (behind the switch): the pre-roll defers the swap, and a key
	# mid-move ends the move at once
	ZoomLadder.calm_force = 0
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
	ZoomLadder.calm_force = -1

	# 3. THE WHEEL STOPS AT EACH SCREEN'S END (Jon, Oct 10: the wheel between
	# distances "isn't intuitive ... and is kinda disruptive"): notch after notch
	# past either end of the map, the chart's closest zoom and LOCAL, and the
	# screen stays where it is; Tab and the tabs are the way between them
	if m != null:
		m._zoom_to = m.zoom_min
		for i in 4:
			m._zoom_by(1.0 / SystemMapScreen.ZOOM_STEP, Vector2(480, 270))
		await _frames(3)
		_ok("the wheel out past the whole sector stays on the map", Router.current == m and not ZoomLadder.busy())
		_ok("and the map's zoom stops at its fit", absf(m._zoom_to - m.zoom_min) < 0.001)
		m._zoom_to = m.view.ZOOM_MAX
		for i in 4:
			m._zoom_by(SystemMapScreen.ZOOM_STEP, Vector2(480, 270))
		await _frames(3)
		_ok("the wheel in past the map's closest zoom stays on the map", Router.current == m and not ZoomLadder.busy())
		_ok("and the map's zoom stops at its closest", absf(m._zoom_to - m.view.ZOOM_MAX) < 0.001)
		m._zoom_to = m.zoom_min
		m.view.zoom = m.zoom_min
		await _frames(2)
	await _go("the chart (for the wheel)", Router.show_starchart, StarchartScreen)
	var ch := Router.current as StarchartScreen
	if ch != null:
		ch._chart.zoom = StarchartScreen.MapChart.ZOOM_MAX
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = ch._chart.size * 0.5
		for i in 4:
			ch._chart._gui_input(wheel)
		await _frames(3)
		_ok("the wheel in past the chart's closest zoom stays on the chart", Router.current == ch and not ZoomLadder.busy())
	await _go("LOCAL (for the wheel)", Router.show_local, SectorScreen)
	var loc := Router.current as SectorScreen
	if loc != null:
		for b in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			var ev := InputEventMouseButton.new()
			ev.button_index = b
			ev.pressed = true
			ev.position = loc._view.size * 0.5
			for i in 4:
				loc._view.gui_input.emit(ev)
		await _frames(3)
		_ok("the wheel on LOCAL stays on LOCAL", Router.current == loc and not ZoomLadder.busy())
	await _go("back to the map", Router.show_system, SystemMapScreen)

	# 3b. THREE BEATS, NEVER OVERLAPPING (Jon, Oct 10: "fast and rushed and
	# chaotic"; and A, Oct 17: the chrome outside the move): the map's UI leaves
	# with its camera still, the camera moves with no UI on either screen, and
	# the chart's UI comes up once it has landed
	var cmm := Router.current as SystemMapScreen
	if cmm != null:
		var cz0: float = cmm.view.zoom
		Router.show_starchart()
		var c_out := false
		var c_in := false
		var c_early := 0
		var c_ui_cam := 0
		for i in 600:
			await _tree.process_frame
			if not ZoomLadder.busy():
				break
			var CL := ZoomLadder.active
			var nm := String(ZoomLadder.Phase.keys()[CL.phase])
			if nm == "C_OUT":
				c_out = true
				if is_instance_valid(cmm) and absf(cmm.view.zoom - cz0) > 0.0001:
					c_early += 1
			if nm == "C_CAM" and CL.new is StarchartScreen:
				var cc := CL.new as StarchartScreen
				if cc._key_row.modulate.a > 0.01 or cc._chart.ui_a > 0.01:
					c_ui_cam += 1
			if nm == "C_IN":
				c_in = true
		_ok("calm: the map's UI leaves before its camera moves (%s, %d frames moved early)" % [c_out, c_early], c_out and c_early == 0)
		_ok("calm: no UI on the chart while the camera moves (%d frames with it)" % c_ui_cam, c_ui_cam == 0)
		var cc3 := Router.current as StarchartScreen
		await _frames(40)
		_ok("calm: and the chart's UI comes up after it lands, all of it", c_in and cc3 != null
			and cc3._ladder_side.modulate.a > 0.99 and cc3._chart.ui_a > 0.99 and cc3._key_row.modulate.a > 0.99)
		_clean("calm UI beats")
		await _go("back to the map (calm UI beats)", Router.show_system, SystemMapScreen)
	ZoomLadder.calm_force = 0
	var mm := Router.current as SystemMapScreen
	if mm != null:
		var z0: float = mm.view.zoom
		Router.show_starchart()
		var saw_out := false
		var saw_in := false
		var cam_in_ui := 0
		var ui_in_move := 0
		for i in 600:
			await _tree.process_frame
			if not ZoomLadder.busy():
				break
			var L := ZoomLadder.active
			if L.phase == ZoomLadder.Phase.UI_OUT:
				saw_out = true
				if is_instance_valid(mm) and absf(mm.view.zoom - z0) > 0.0001:
					cam_in_ui += 1
			# (the side bar is not this UI: it stays through the move and swaps in
			# place, Jon Oct 13 -- `-- sheet=SideBarTest`)
			if L.phase == ZoomLadder.Phase.MOVE and L.new is StarchartScreen:
				var c2 := L.new as StarchartScreen
				if c2._key_row.modulate.a > 0.01 or c2._chart.ui_a > 0.01:
					ui_in_move += 1
			if L.phase == ZoomLadder.Phase.UI_IN:
				saw_in = true
		_ok("the map's UI leaves before its camera moves (%s, %d frames moved early)" % [saw_out, cam_in_ui], saw_out and cam_in_ui == 0)
		_ok("no UI on the chart while the camera moves (%d frames with it)" % ui_in_move, ui_in_move == 0)
		var c3 := Router.current as StarchartScreen
		_ok("and the chart's UI comes up after it lands, all of it", saw_in and c3 != null
			and c3._ladder_side.modulate.a > 0.99 and c3._chart.ui_a > 0.99 and c3._key_row.modulate.a > 0.99)
		_clean("UI beats")
		await _go("back to the map (UI beats)", Router.show_system, SystemMapScreen)
		var m4 := Router.current as SystemMapScreen
		_ok("and the map's panel, strip and key are back whole", m4 != null and m4.panel.get_parent().modulate.a > 0.99
			and m4._strip.modulate.a > 0.99 and m4._key_row.modulate.a > 0.99 and m4.overlay.label_a > 0.99)
	ZoomLadder.calm_force = -1
	# 3c'. THE CHART AND LOCAL ARE THE ONE MOVE TOO (A, Oct 17): no black, LOCAL's
	# own camera moving (its scene scaled about your ship) on the way in and out
	await _go("the chart (for the calm dive)", Router.show_starchart, StarchartScreen)
	for way in [[Router.show_local, SectorScreen, "calm chart to LOCAL"], [Router.show_starchart, StarchartScreen, "calm LOCAL to chart"]]:
		(way[0] as Callable).call()
		var blk := 0.0
		var cam := 0
		for i in 600:
			await _tree.process_frame
			if not ZoomLadder.busy():
				break
			var L := ZoomLadder.active
			if L._black != null and is_instance_valid(L._black):
				blk = maxf(blk, L._black.color.a)
			var cur := Router.current
			if cur is SectorScreen and not is_equal_approx((cur as SectorScreen)._lad_zs, 1.0):
				cam += 1
		_ok("%s is one camera move, no black (%.2f), LOCAL's camera moving (%d frames)" % [way[2], blk, cam], blk <= 0.0 and cam > 10)
		_ok("%s lands" % way[2], Router.current != null and Router.current.get_script() == way[1])
		_clean(String(way[2]))
	ZoomLadder.calm_force = 0
	# 3c. THE CHART AND LOCAL ARE A FADE (Jon, Oct 10: "just do a fade. No
	# transition"): through black both ways, no camera move on either screen,
	# LOCAL built in the black
	await _go("the chart (for the fade)", Router.show_starchart, StarchartScreen)
	for way in [[Router.show_local, SectorScreen, "chart to LOCAL"], [Router.show_starchart, StarchartScreen, "LOCAL to chart"]]:
		(way[0] as Callable).call()
		var black := 0.0
		var moved := 0
		var faded := false
		for i in 600:
			await _tree.process_frame
			if not ZoomLadder.busy():
				break
			var L := ZoomLadder.active
			faded = faded or L._fade
			if L.phase == ZoomLadder.Phase.MOVE or L.phase == ZoomLadder.Phase.WAIT or L.phase == ZoomLadder.Phase.UI_OUT:
				moved += 1
			if L._black != null and is_instance_valid(L._black):
				black = maxf(black, L._black.color.a)
			var cur := Router.current
			if cur is SectorScreen and not (cur as SectorScreen)._lad.is_empty():
				moved += 1
			if cur is StarchartScreen and (cur as StarchartScreen)._chart != null and not (cur as StarchartScreen)._chart._lad.is_empty():
				moved += 1
		_ok("%s is a fade through black (to %.2f), no camera (%d frames moved)" % [way[2], black, moved], faded and black > 0.99 and moved == 0)
		_ok("%s lands" % way[2], Router.current != null and Router.current.get_script() == way[1])
		_clean(String(way[2]))
	await _go("back to the map (after the fade)", Router.show_system, SystemMapScreen)
	ZoomLadder.calm_force = -1
	# (the move lengths: dials in Settings until Jon had them out, Oct 19, and
	# baked at what he had them on -- a settings file's old `[flow]` is not read)
	_ok("the move lengths are Jon's (seam 1 %.2f s, UI out %.2f s, the calm camera %.2f s)" % [ZoomLadder.SEAM1_S, ZoomLadder.UI_OUT_S, ZoomLadder.CALM_CAM_S],
		is_equal_approx(ZoomLadder.SEAM1_S, 1.7) and is_equal_approx(ZoomLadder.UI_OUT_S, 0.22) and is_equal_approx(ZoomLadder.CALM_CAM_S, 0.8)
		and is_equal_approx(ZoomLadder.LIGHT_ON, 1.35))
	# (the dock on LOCAL, its five steps: the cut, the arrival's own length --
	# Jon, Oct 20, "like it does for the first sector" -- and the beat, power-on
	# and way in)
	var dock_want := ZoomLadder.FADE_OUT_S + ShipView.ARRIVE_LEAD_S + ShipView.ARRIVE_MS / 1000.0 		+ ZoomLadder.DOCK_BEAT_S + ZoomLadder.DOCK_POWER_S + ZoomLadder.DOCK_ENTER_S
	_ok("the dock's five steps on LOCAL take %.2f s: the cut, the arrival's own %.1f s, then %.1f + %.1f + %.1f" % [
		ZoomLadder.dock_approach_s(), ShipView.ARRIVE_LEAD_S + ShipView.ARRIVE_MS / 1000.0, ZoomLadder.DOCK_BEAT_S, ZoomLadder.DOCK_POWER_S, ZoomLadder.DOCK_ENTER_S],
		is_equal_approx(ZoomLadder.dock_approach_s(), dock_want))

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
		# (parked at the station's own body: the dock is only there, dock:A)
		Router.park_at_station()
		await _go("to LOCAL at the station", Router.show_local, SectorScreen)
		loc = Router.current as SectorScreen
		var dock_b: Button = loc.find_child("Dock", true, false) as Button if loc != null else null
		_ok("the defaults are 1A 2C 3B", ZoomLadder.design_for(1) == "A" and ZoomLadder.design_for(2) == "C"
			and ZoomLadder.design_for(3) == "B")
		_no_fights_at_stations(st)
		_front_is_plate_less_recess()
		_station_picks()
		if dock_b != null:
			await _first_locals()
			# (LOCAL's bar built again after its arrival: its DOCK anew)
			loc = Router.current as SectorScreen
			dock_b = loc.find_child("Dock", true, false) as Button if loc != null else null
			await _hull_flies_in(dock_b)
			_arrival_is_first_locals()
			await _hull_flies_out()
			loc = Router.current as SectorScreen
			dock_b = loc.find_child("Dock", true, false) as Button if loc != null else null
			if dock_b != null:
				await _dock_skipped(dock_b)
				loc = Router.current as SectorScreen
				dock_b = loc.find_child("Dock", true, false) as Button if loc != null else null
		await _every_side()
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
			# (Jon, Oct 20: "there is a frame where the ship is there? then it
			# goes away? and then it comes back in?": LOCAL is never drawn with
			# your ship on it before the dock's arrival brings it in)
			var arrived := false
			var shown_early := 0
			var calm_seen := false
			for i in 900:
				await _tree.process_frame
				if ZoomLadder.busy() and ZoomLadder.active._calm:
					calm_seen = true
				var lm := Router.current as SectorScreen
				if lm != null:
					saw_local = true
					var hb: StringName = (lm._lad.get("hall", {}) as Dictionary).get("beat", &"")
					if hb in [&"arrive", &"beat", &"power", &"enter"]:
						arrived = true
					var sv := lm._view.ship_view() if lm._view != null else null
					if not arrived and sv != null and sv.is_visible_in_tree():
						shown_early += 1
				if Router.current is StationScreen and not ZoomLadder.busy() and ZoomLadder.chain == &"":
					break
			_ok("the map's DOCK goes by LOCAL (%s) into the berth" % saw_local, saw_local and Router.current is StationScreen and Router.docked)
			_ok("the map's DOCK: down to black and up on LOCAL with your ship off it, no calm move (%s), and no LOCAL frame shows your ship before its arrival (%d frames, arrived %s)" % [
				calm_seen, shown_early, arrived], arrived and shown_early == 0 and not calm_seen)
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
	ZoomLadder.calm_force = -1
	ZoomLadder.fixed_dt = -1.0
	print("laddertest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
