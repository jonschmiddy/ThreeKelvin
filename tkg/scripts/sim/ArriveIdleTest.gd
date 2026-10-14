extends Node

## A NEW RUN'S FIRST ARRIVAL, THE ENGINES AND THE HOVER:
##   godot --headless --fixed-fps 60 --path . -- sheet=ArriveIdleTest
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
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
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
	for i in 60 * 14:
		await _tree.process_frame
		sc = Router.current as SectorScreen
		if sc == null or sc._view == null:
			continue
		art = sc._view.ship_view()
		if art == null:
			continue
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
	_finish()


func _finish() -> void:
	print("arriveidletest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(0 if _fails == 0 else 1)
