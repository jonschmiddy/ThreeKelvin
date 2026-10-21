extends Node

## A NEW RUN'S FIRST ARRIVAL, THE ENGINES AND THE HOVER:
##   godot --headless --fixed-fps 60 --path . -- sheet=ArriveIdleTest [manufacturer=solari] [weight=light]
##
## Jon, Oct 13, of the first sector: "your ship sputters to a stop... the
## engines turn OFF and then there is a hitch... the ship is highlighted and
## then the engines turn to idle. I don't want the engines to turn off... I
## just want them to sputter to an idle. No highlight."
##
## A new run on LOCAL the way the hull pick launches it (`Router.show_local`,
## animated), stepped a frame at a time from the screen's first frame to a
## second after the ship has parked. On every frame:
##   - the flame is never fully off (`ShipView._thrust_now` >= 0): the coughs
##     sputter over the idle, and the idle is what it settles to;
##   - the cutaway's amber outline never shows (park() used to switch it on).
## And the arrival has to have happened: the clean burn at FULL, at least one
## cough, the ship parked, the screen at rest, the idle after.
## Then, at rest, the pointer that was resting where the ship came to rest
## (the event the slot is handed, with the pointer not moved) must not light
## it; and once the pointer has moved, the hover outline works as before.
## THE DUST AT ITS IDLE THROUGH AN ARRIVAL (Jon, Oct 21, for 0.3.0, as the
## dock has it since Oct 20: "The dust move too much"): on every frame from the
## screen's first to a second after the ship parks, every `LocalDust` mote, by
## its place as drawn (`_rest_at`), moves by its own drift and bob and nothing
## more, 0 px beyond, and the sky's camera (`LocalSky.cam_follow`) holds one
## place. Then the same through a jump's arrival at the next system, LOCAL
## opened on it from its map. (It
## followed the ship at `CAM_FOLLOW`: the dust jumped about 209 px on the
## arrival's first frame and slid back over the approach.)

var _tree: SceneTree
var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	Rng.forced = 4242
	# `manufacturer=solari weight=light`: another chassis's arrival (its own
	# engines); Korvan's medium by default, as the gate runs it
	var mk := &"korvan"
	var wt := HullData.Weight.MEDIUM
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("manufacturer="):
			mk = StringName((a as String).substr(13))
		elif (a as String).begins_with("weight="):
			wt = {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM,
				"heavy": HullData.Weight.HEAVY}.get((a as String).substr(7), HullData.Weight.MEDIUM)
	Run.start_new_run(mk, int(wt))
	print("arriveidletest: %s, %d engines" % [Run.hull.name, Run.hull.thrusters.size()])
	Router.show_local()

	var off := 0
	var first_off := -1
	var lit_frames := 0
	var outline := 0
	var first_outline := -1
	var saw_full := false
	var saw_cough := false
	var parked_at := -1
	var art: ShipView = null
	var sc: SectorScreen = null
	var prev := -2
	var levels: Array[int] = []
	var dust := _dust_new()
	for i in 60 * 14:
		await _tree.process_frame
		sc = Router.current as SectorScreen
		if sc == null or sc._view == null:
			continue
		art = sc._view.ship_view()
		if art == null:
			continue
		_dust_step(sc, dust, art._arrive_at >= 0)
		var th := art._thrust_now()
		if th != prev:
			levels.append(th)
			prev = th
		if th < 0:
			off += 1
			if first_off < 0:
				first_off = i
		else:
			lit_frames += 1
		if art._arrive_at >= 0:
			if art._arrive_window == 0 and th == ThrusterFx.Thrust.FULL:
				saw_full = true
			if art._arrive_window >= 1:
				saw_cough = true
		elif parked_at < 0 and saw_full:
			parked_at = i
		if sc._ship_outline != null and sc._ship_outline.visible:
			outline += 1
			if first_outline < 0:
				first_outline = i
		if parked_at >= 0 and i >= parked_at + 60:
			break

	if not _ok("LOCAL is up with your ship on it", art != null and sc != null):
		_finish()
		return
	print("    thrust levels in order: %s" % [levels])
	_ok("the arrival burned clean at FULL", saw_full)
	_ok("and coughed as the drive starved", saw_cough)
	_ok("and parked (frame %d)" % parked_at, parked_at >= 0)
	_ok("the flame was never fully off (%d of %d frames off%s)" % [off, off + lit_frames,
		(", the first at frame %d" % first_off) if first_off >= 0 else ""], off == 0)
	_ok("it settled to the IDLE", art._thrust_now() == ThrusterFx.Thrust.IDLE)
	_ok("the screen is at rest", sc.cutaway_ready())
	_ok("the outline never lit (%d frames%s)" % [outline,
		(", the first at frame %d" % first_outline) if first_outline >= 0 else ""], outline == 0)
	_dust_ok("the first system's arrival", dust)

	# THE POINTER LEFT RESTING WHERE THE SHIP CAME TO REST: the slot is handed
	# a motion at the hull's middle and the pointer has not moved.
	var slot := art.get_parent() as Control
	var mid := art.get_global_transform() * art.hull_rect().get_center()
	var ev := InputEventMouseMotion.new()
	ev.position = slot.get_global_transform().affine_inverse() * mid
	ev.global_position = mid
	_ok("the hull's middle is on the hull", CutawayView.on_hull(art, art.hull_rect().get_center()))
	sc._on_own_ship_input(ev)
	_ok("a pointer resting where the ship parked does not light it",
		sc._ship_outline != null and not sc._ship_outline.visible)
	# and once it has moved, the hover is back
	if "_still_pointer" in sc:
		sc.set("_still_pointer", Vector2.INF)
	sc._on_own_ship_input(ev)
	_ok("a pointer that has moved onto the ship lights it as before",
		sc._ship_outline != null and sc._ship_outline.visible)
	await _next_system()
	_finish()


## A LATER SYSTEM'S ARRIVAL ON LOCAL: a jump to the next system in reach
## (`Router.commit_jump`) with something waiting there (`ambush_pending`), so
## the fight meets you on arrival and your ship flies in on LOCAL before it
## starts (`_hold_for_arrival`). (A quiet jump lands on the system's map, which
## plays its own arrival and spends LOCAL's.) Stepped from the first frame to a
## second after the ship parks, the dust measured as above.
func _next_system() -> void:
	var to := -1
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != Run.at and Run.can_jump_to(m) and m.type == MapGen.NodeType.SYSTEM \
				and not Router.ambush_pack(m).is_empty():
			to = m.index
			break
	if not _ok("a system in reach to jump to, with a fight to wait there (%d)" % to, to >= 0):
		return
	(Run.map[to] as MapGen.MapNode).ambush_pending = true
	Router.commit_jump(to)
	var dust := _dust_new()
	var parked_at := -1
	var arrived := 0
	var in_fight := false
	for i in 60 * 14:
		await _tree.process_frame
		var sc := Router.current as SectorScreen
		if sc == null or sc._view == null or Run.at != to:
			continue
		var art := sc._view.ship_view()
		if art == null:
			continue
		in_fight = in_fight or sc.fighting()
		var arriving := art._arrive_at >= 0
		if arriving:
			arrived += 1
		elif arrived > 0 and parked_at < 0:
			parked_at = i
		_dust_step(sc, dust, arriving)
		if parked_at >= 0 and i >= parked_at + 60:
			break
	_ok("the next system: met by a fight on LOCAL, your ship flew in (%d frames) and parked" % arrived,
		in_fight and arrived > 60 and parked_at >= 0)
	_dust_ok("the next system's arrival (%s)" % MapGen.star_name(Run.node_at()), dust)


func _dust_new() -> Dictionary:
	return {prev = {}, frames = 0, arriving = 0, over = 0, worst = 0.0, cam = {}}


## One frame of the dust: each mote's place as drawn (`_rest_at` through the
## dust's transform, as `DockFilm` logs it) against the frame before, less its
## own drift (`vx`) and the most its bob can move it. A mote wrapping round its
## strip (`LocalDust.WRAP` past each side) is taken back by the strip's width,
## so a jump of the camera cannot hide as a wrap.
func _dust_step(sc: SectorScreen, d: Dictionary, arriving: bool) -> void:
	var du: LocalDust = sc._view.dust
	if du == null or du._motes.is_empty() or du.sky == null:
		return
	var xf := du.get_global_transform()
	var sx := xf.get_scale().x
	var strip := (du.size.x + LocalDust.WRAP * 2.0) * sx
	var prev: Dictionary = d.prev
	var seen := false
	var over_any := false
	d.cam[du.sky.cam_follow.x] = true
	for mi in du._motes.size():
		var mo: Dictionary = du._motes[mi]
		var gp := xf * du._rest_at(mo, du._t)
		if prev.has(mi):
			var pv: Array = prev[mi]
			var ddt := du._t - float(pv[1])
			var dd: Vector2 = gp - (pv[0] as Vector2)
			var ex := dd.x - float(mo.vx) * ddt * sx
			ex = fposmod(ex + strip * 0.5, strip) - strip * 0.5
			var over := maxf(absf(ex), absf(dd.y) - 0.15 * float(mo.bob) * ddt * sx)
			seen = true
			d.worst = maxf(float(d.worst), over)
			if over > 0.01:
				over_any = true
		prev[mi] = [gp, du._t]
	if seen:
		d.frames += 1
		if arriving:
			d.arriving += 1
		if over_any:
			d.over += 1


func _dust_ok(what: String, d: Dictionary) -> void:
	var cams: Array = d.cam.keys()
	cams.sort()
	_ok("%s: every dust mote moves by its own drift and bob alone (%d frames, %d of them arriving; beyond them at most %.3f px, %d frames over), the sky's camera held (%d place%s, %s)" % [
		what, d.frames, d.arriving, d.worst, d.over, cams.size(), "" if cams.size() == 1 else "s",
		str(cams) if cams.size() <= 3 else "%.0f to %.0f" % [cams[0], cams[-1]]],
		d.arriving > 60 and d.over == 0 and d.cam.size() == 1)


func _finish() -> void:
	print("arriveidletest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(0 if _fails == 0 else 1)
