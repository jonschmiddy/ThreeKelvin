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
			if fmode and not dip_seen and blk > 0.02:
				dip_seen = true
				dip_at = last
			if ZoomLadder.busy() and last.size.x > 0.0:
				track.append(["L", last.get_center().x, loc0._lad_zs])
			# (behind the front, over the plate, the two in one place)
			var v := loc0._view
			if not (loc0._face.get_index() < v._row.get_index() and v._row.get_index() < loc0._face_front.get_index()) \
					or not loc0._face.get_global_transform().is_equal_approx(loc0._face_front.get_global_transform()) \
					or loc0._face.origin() != loc0._face_front.origin():
				layer_bad += 1
			if first.size.x <= 0.0:
				first = last
				# (the station's width on LOCAL, at rest, before the camera moves)
				shown = loc0._view.get_global_rect().end.x - loc0._face.plate_g(Vector2(StationFace.EDGE_X, StationFace.ROW)).x
			if last.size.x > 0.0:
				tails.append(last.position.x)
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
		if not ZoomLadder.busy() and Router.current is StationScreen:
			break
	st = Router.current as StationScreen
	if not _ok("3B DOCK lands in the station", st != null and Router.docked):
		return
	if hall:
		var right := true
		for i in range(1, tails.size()):
			if tails[i] < tails[i - 1] - 0.01:
				right = false
		_ok("3B: on LOCAL your ship sets off from where it sat (tail at plate x %.0f) and only moves right" % first.position.x,
			tails.size() > 20 and first.end.x < StationFace.EDGE_X and right)
		_ok("3B: the station's lights are all on before the pan (power %.2f)" % power, power >= 0.999)
		# (seen only in the recess: wholly past its end, inside the hull's rows,
		# your ship is 0 pixels seen -- `_front_is_plate_less_recess`)
		var hull := Rect2(StationFace.RECESS.end.x, StationFace.RECESS.position.y, 2000.0, StationFace.RECESS.size.y)
		_ok("3B: your ship is all the way into the hull, none of it seen, before the hand-off (on the plate %s; hull past the recess from x %.0f)" % [last, hull.position.x],
			last.size.x > 1.0 and hull.encloses(last))
		if fmode:
			_ok("3B F: your ship is out of sight in the hull before the screen starts to dip to black (on the plate %s)" % dip_at,
				dip_seen and dip_at.size.x > 1.0 and hull.encloses(dip_at))
		_ok("3B: on every frame of the approach your ship is drawn between the station's plate and its front, both placed alike (%d frames out)" % layer_bad,
			layer_bad == 0)
		_ok("3B: the station takes %.0f px of LOCAL's width (at most %.0f)" % [shown, StationFace.SHOWN + 1.0], shown <= StationFace.SHOWN + 1.0 and shown > 150.0)
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
	var rx := st._rail.position.x if st._rail != null else 0.0
	await _frames(int(StationScreen.ELEVATOR_S * 30.0) + 6)
	_ok("3B: then the elevator slides in (%.0f -> %.0f)" % [rx, st._rail.position.x if st._rail != null else 0.0],
		st._rail == null or st._rail.position.x > rx + 20.0)
	_clean("3B dock")


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


## THE STATION'S FRONT IS ITS PLATE LESS THE RECESS, pixel for pixel: every
## pixel of the plate that is hull (outside the bay's recess) is solid in the
## front layer, so no ship pixel is ever drawn over hull; and nothing of the
## front is inside the recess, where your ship is seen.
func _front_is_plate_less_recess() -> void:
	var plate := (StationFace.PLATE_UNLIT as Texture2D).get_image()
	var front := (StationFace.FRONT_UNLIT as Texture2D).get_image()
	if plate == null or front == null:
		_ok("station art readable", false)
		return
	var hull_open := 0
	var recess_drawn := 0
	for y in plate.get_height():
		for x in plate.get_width():
			var inside := StationFace.RECESS.has_point(Vector2(x, y))
			var pa := plate.get_pixel(x, y).a
			var fa := front.get_pixel(x, y).a
			if inside and fa > 0.0:
				recess_drawn += 1
			elif not inside and pa > 0.5 and fa < 0.99:
				hull_open += 1
	_ok("station: the front covers every pixel of hull (%d open) and nothing of the recess (%d drawn)" % [hull_open, recess_drawn],
		hull_open == 0 and recess_drawn == 0)


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

	# 1a. 2C BUILDS LOCAL AT THE CLICK (Jon: "2C still has a small delay/hitch"):
	# the screen that arrives is the one built ahead, before anything moved, and
	# the run is written when the move lands, not in the middle of it
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
		_no_fights_at_stations(st)
		_front_is_plate_less_recess()
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
