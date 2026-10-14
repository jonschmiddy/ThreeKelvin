extends Node

## YOUR IDLE IS HEARD EXACTLY WHILE IT IS SEEN (Jon, Oct 13: "Let's have a low
## burn sound for the idle engines"):
##   godot --headless --fixed-fps 60 --path . -- sheet=IdleSoundTest
##
## `Audio` makes no sound headless, but it still decides every frame whether the
## bed should be up (`Audio.idle_want`) and runs the fade (`Audio.idle_level`),
## and that decision is the whole of the wiring. Read here against the picture,
## which is `ShipView._thrust_now()` and where the hull is:
##   - a new run's first arrival on LOCAL: silent through the clean burn, up from
##     the first gap after it, and up, at full, once the ship has parked;
##   - only your ship hums: one view in the tree, and no enemy's;
##   - a hyperdrive's dark (engines off) takes it down, within the fade; so does
##     a departure's FULL; parking brings it back;
##   - a fight: your ship idles there, and it is heard there;
##   - the star chart (no ship on screen): silent;
##   - the refit and the transfer: your ship's idle flame is drawn there, so it is
##     heard there too, and only by that one view (the transfer's old frame is
##     quiet);
##   - back on LOCAL: heard again.
## The fade itself: up and down in IDLE_FADE_S, give or take a frame.

var _tree: SceneTree
var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _art() -> ShipView:
	var sc := Router.current as SectorScreen
	if sc == null or sc._view == null:
		return null
	return sc._view.ship_view()


## Every ShipView in the tree that hums.
func _hummers(n: Node, out: Array) -> Array:
	if n is ShipView and (n as ShipView).hums and n.is_inside_tree():
		out.append(n)
	for c in n.get_children():
		_hummers(c, out)
	return out


## Frames until the fade has gone all the way to `to`, or -1.
func _settle(to: float, limit: int) -> int:
	for i in limit:
		await _tree.process_frame
		if is_equal_approx(Audio.idle_level, to):
			return i + 1
	return -1


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	var fade_frames := int(ceil(Audio.IDLE_FADE_S * 60.0))

	# ---- the first arrival, frame by frame
	var art: ShipView = null
	var burn_heard := 0
	var burn_frames := 0
	var lit_heard := 0
	var first_gap := -1
	var first_up := -1
	var parked_at := -1
	var saw_burn := false
	for i in 60 * 14:
		await _tree.process_frame
		art = _art()
		if art == null:
			continue
		var th := art._thrust_now()
		var arriving := art._arrive_at >= 0
		if arriving and art._arrive_window == 0:
			burn_frames += 1
			saw_burn = true
			if Audio.idle_want:
				burn_heard += 1
		# lit harder than the idle, and not the arrival's coughs: never heard
		if th > ThrusterFx.Thrust.IDLE and not (arriving and art._arrive_window >= 1) \
				and Audio.idle_want:
			lit_heard += 1
		if saw_burn and arriving and art._arrive_window != 0 and first_gap < 0:
			first_gap = i
		if Audio.idle_want and first_up < 0:
			first_up = i
		if saw_burn and not arriving and parked_at < 0:
			parked_at = i
		if parked_at >= 0 and i >= parked_at + 60:
			break
	if not _ok("LOCAL is up with your ship on it", art != null):
		return _finish()
	_ok("the arrival burned clean (%d frames)" % burn_frames, burn_frames > 0)
	_ok("and the bed was silent through all of it (%d heard)" % burn_heard, burn_heard == 0)
	_ok("never heard while the flame is up past the idle (%d)" % lit_heard, lit_heard == 0)
	_ok("it came up on the first gap after the burn (gap %d, up %d)" % [first_gap, first_up],
			first_gap >= 0 and first_up == first_gap)
	_ok("parked at the IDLE (frame %d)" % parked_at,
			parked_at >= 0 and art._thrust_now() == ThrusterFx.Thrust.IDLE)
	_ok("and heard at full there (want %s, level %.2f)" % [Audio.idle_want, Audio.idle_level],
			Audio.idle_want and is_equal_approx(Audio.idle_level, 1.0))
	var hum := _hummers(_tree.root, [])
	_ok("one view hums, and it is your ship (%d)" % hum.size(), hum.size() == 1 and hum[0] == art)

	# ---- the hyperdrive's dark
	art.depart(true)
	var heard := 0
	var down := -1
	for i in 40:
		await _tree.process_frame
		if Audio.idle_want:
			heard += 1
		if down < 0 and Audio.idle_level <= 0.0:
			down = i + 1
	_ok("a hyperdrive's dark is silent (%d frames heard)" % heard, heard == 0)
	_ok("and the bed is gone within the fade (%d frames, fade %d)" % [down, fade_frames],
			down > 0 and down <= fade_frames + 1)
	art.park()
	var up := await _settle(1.0, 60)
	_ok("parked again, it comes back up in the fade (%d frames)" % up,
			up >= fade_frames - 1 and up <= fade_frames + 1)

	# ---- idling, but not on screen: hidden, or moved out of the window
	art.visible = false
	await _tree.process_frame
	_ok("a hidden ship is not heard", not Audio.idle_want)
	art.visible = true
	await _tree.process_frame
	var home := art.position
	art.position.x = -(art.get_global_rect().end.x + 64.0)
	await _tree.process_frame
	_ok("nor one out of the window (hull at x %.0f)" % art.get_global_rect().position.x,
			not Audio.idle_want)
	art.position = home
	await _tree.process_frame
	_ok("and back in view it is", Audio.idle_want)
	await _settle(1.0, 60)

	# ---- a departure under thrust (FULL): not the idle
	art.depart(false)
	await _tree.process_frame
	_ok("a departure's burn is not the idle", not Audio.idle_want)
	art.park()
	await _settle(1.0, 60)

	# ---- a fight: your ship idles in it
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	for i in 60 * 5:
		await _tree.process_frame
	var fart := _art()
	var fsc := Router.current as SectorScreen
	_ok("a fight is up", fsc != null and fsc.fighting() and fart != null)
	if fart != null:
		_ok("your ship idles in it (thrust %d)" % fart._thrust_now(),
				fart._thrust_now() == ThrusterFx.Thrust.IDLE)
		_ok("and is heard there (want %s, level %.2f)" % [Audio.idle_want, Audio.idle_level],
				Audio.idle_want and is_equal_approx(Audio.idle_level, 1.0))
	var fhum := _hummers(_tree.root, [])
	var enemy_hums := 0
	for v in fhum:
		if v != fart:
			enemy_hums += 1
	_ok("only your ship hums in a fight (%d views, %d not yours)" % [fhum.size(), enemy_hums],
			fhum.size() == 1 and enemy_hums == 0)

	# ---- screens without your ship on LOCAL
	Router.combat = null
	Router.show_starchart()
	var gone := await _settle(0.0, 120)
	_ok("the star chart is silent (want %s, level 0 in %d frames)" % [Audio.idle_want, gone],
			not Audio.idle_want and gone > 0)
	Router.show_ship()
	var refit := await _settle(1.0, 120)
	_ok("the refit is heard: your ship's idle flame is drawn there (%d frames)" % refit,
			refit > 0 and Audio.idle_want)
	Router.show_transfer()
	var moved := await _settle(1.0, 120)
	var thum := _hummers(_tree.root, [])
	_ok("the transfer is heard, by your new hull alone (%d frames, %d humming views)"
			% [moved, thum.size()], moved > 0 and Audio.idle_want and thum.size() == 1)

	# ---- and back
	Router.animate_in_harness = false
	Router.show_local()
	var back := await _settle(1.0, 240)
	_ok("back on LOCAL, heard again (%d frames)" % back, back > 0 and Audio.idle_want)
	_finish()


func _finish() -> void:
	print("idlesoundtest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(0 if _fails == 0 else 1)
