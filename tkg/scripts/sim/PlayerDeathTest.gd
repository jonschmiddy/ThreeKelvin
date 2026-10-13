extends Node

## YOUR SHIP BREAKS UP BEFORE THE RUN ENDS:
##   godot --headless --path . -- sheet=PlayerDeathTest
##
## Jon, Oct 13: "When you die... let's have your ship crack and explode...
## pause for a beat... then the run ended popup shows up."
##
## The same fight twice from the same seed, at 5 hull against a cutter's Strafe
## 5, through END TURN as the button presses it:
##   - ANIMATED (`Router.animate_in_harness`): the killing shot lands, your hull
##     comes apart (`SectorScreen.loss`: a ship style, the boss-length cut, drawn
##     mirrored because your ship faces right, over the hull's own place, the
##     hull hidden), the explosion played on its breaks, and the run's
##     screen appears only once the breakup has finished AND the wreck has been
##     held for WRECK_HOLD_S;
##   - WITHOUT MOTION: no breakup, the run's screen at once;
##   - and the run each leaves behind identical: dead, the reason, hull, heat,
##     fuel, credits, hold, jumps, kills, the record written once as a loss.

var _tree: SceneTree
var _fails := 0
const SEED := 6061


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


func _run() -> void:
	_tree = get_tree()
	await _frames(2)

	Router.animate_in_harness = true
	var a := await _die(true)
	Router.animate_in_harness = false
	var b := await _die(false)

	if a.is_empty() or b.is_empty():
		return _finish()

	# ------------------------------------------------------------ animated
	_ok("animated: the hull came apart (%s)" % a.get("style_name", "-"), a.broke)
	_ok("animated: in a ship style, not a creature's",
		EnemyArt.SHIP_STYLES.has(int(a.get("style", -1))))
	_ok("animated: the boss-length cut", a.get("boss", false))
	_ok("animated: drawn mirrored back (your ship faces right)", float(a.get("scale_x", 1.0)) < 0.0)
	_ok("animated: over the hull's own place (off by %.1f px)" % float(a.get("place_err", 99.0)),
		float(a.get("place_err", 99.0)) <= 4.0)
	_ok("animated: the hull hidden while it breaks", a.get("hull_hidden", false))
	# (Audio is off headless: what is checked is that the screen listens to the
	# breakup's own breaks, and that they fire.)
	_ok("animated: the explosion is played on the breakup's breaks (%d breaks)" % int(a.get("breaks", 0)),
		a.get("listened", false) and int(a.get("breaks", 0)) > 0)
	_ok("animated: the run's screen not up while the hull breaks", not a.get("screen_early", true))
	var need := float(a.get("duration", 0.0)) + SectorScreen.WRECK_HOLD_S
	var took := float(a.get("break_to_screen", 0.0))
	_ok("animated: the run's screen %.2f s after the break began (breakup %.2f + hold %.1f)"
		% [took, float(a.get("duration", 0.0)), SectorScreen.WRECK_HOLD_S],
		took >= need - 0.1 and took <= need + 1.0)
	_ok("animated: the wreck held on screen until then", a.get("wreck_held", false))

	# ---------------------------------------------------------- no motion
	_ok("no motion: no breakup", not b.broke)
	_ok("no motion: the run's screen at once (%d frames)" % int(b.get("frames_to_screen", 999)),
		int(b.get("frames_to_screen", 999)) <= 10)

	# --------------------------------------------------- the same run left
	var same := true
	for k in a.state.keys():
		if a.state[k] != b.state[k]:
			same = false
			print("    %s: %s vs %s" % [k, str(a.state[k]), str(b.state[k])])
	_ok("the run each leaves is identical (%s)" % ", ".join(PackedStringArray(a.state.keys())), same)
	_ok("dead, and recorded once as a loss each time", a.state.dead and a.records == 1 and b.records == 1)
	_finish()


## One fight to the death. Returns what was seen.
func _die(animated: bool) -> Dictionary:
	Rng.forced = SEED
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var records_before := RunHistory.load_all().size()
	var idx := -1
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM and not n.cleared:
			idx = n.index
			break
	if not _ok("a system to fight at", idx >= 0):
		return {}
	Run.at = idx
	Run.map[idx].visited = true
	SectorScreen._approached_at = idx
	Router.show_local()
	await _frames(3)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	var cb: Combat = null
	for i in 240:
		await _tree.process_frame
		cb = Router.combat
		var s0 := Router.current as SectorScreen
		if cb != null and s0 != null and s0.fighting() and not s0._opening:
			break
	var sc := Router.current as SectorScreen
	if not _ok("a cutter fight opens (%s)" % ("animated" if animated else "no motion"), cb != null and sc != null):
		return {}
	# 5 hull against Strafe 5, nothing in the way.
	var e: Combat.EnemyState = cb.enemies[0]
	var hits := maxi(1, e.intent.hits if e.intent != null else 1)
	var dmg := (e.intent.damage if e.intent != null else 0) * hits
	Run.hp = 5 if dmg >= 5 else 1
	cb.block = 0
	cb.brace = 0
	var t0 := Time.get_ticks_msec()
	var out := {broke = false, screen_early = false, wreck_held = true}
	sc._end_button.pressed.emit()
	var frames := 0
	var break_at := -1
	var done_at := -1
	while frames < 900:
		await _tree.process_frame
		frames += 1
		var on_over := Router.current is GameOverScreen
		if is_instance_valid(sc) and sc.loss != null and break_at < 0:
			break_at = Time.get_ticks_msec()
			var b: ShipBreakup = sc.loss
			out.broke = true
			out.style = b.style
			out.style_name = String(ShipBreakup.NAMES.get(b.style, "?"))
			out.boss = b.boss
			out.duration = b.duration
			out.scale_x = b.scale.x
			var v := sc._view.ship_view()
			out.hull_hidden = not v.visible
			# Where the picture's (0,0) lands, against where the hull's canvas is.
			var pic_w := float(v.canvas().get_width())
			var want := (v.get_parent() as Control).get_global_transform() * ShipLoss.canvas_origin(v)
			var got := b.get_global_transform() * Vector2(pic_w, 0.0)
			out.place_err = (want - got).length()
			out.listened = b.broke.get_connections().size() > 0
			out.breaks = 0
			b.broke.connect(func(_s: float) -> void: out.breaks += 1)
		if break_at >= 0 and done_at < 0 and is_instance_valid(sc) and sc.loss != null and sc.loss.done:
			done_at = Time.get_ticks_msec()
		if break_at >= 0 and not on_over and is_instance_valid(sc) and is_instance_valid(sc.loss):
			if done_at >= 0 and not sc.loss.is_inside_tree():
				out.wreck_held = false
		if on_over:
			if break_at >= 0 and done_at < 0:
				out.screen_early = true
			out.frames_to_screen = frames
			out.break_to_screen = (Time.get_ticks_msec() - break_at) / 1000.0 if break_at >= 0 else 0.0
			break
	if not _ok("the run's screen came (%s)" % ("animated" if animated else "no motion"),
			Router.current is GameOverScreen):
		return {}
	var hold := Run.cargo.size() + Run.pad.size()
	out.state = {dead = Run.dead, reason = Run.death_reason, hp = Run.hp, heat = Run.heat,
		fuel = Run.fuel, credits = Run.credits, hold = hold, jumps = Run.jumps, kills = Run.kills,
		outcome = int((RunHistory.load_all().back() as Dictionary).get("outcome", -1))}
	out.records = RunHistory.load_all().size() - records_before
	print("  [%s] %d frames, %.2f s; style %s" % ["animated" if animated else "no motion",
		frames, (Time.get_ticks_msec() - t0) / 1000.0, out.get("style_name", "-")])
	return out


func _finish() -> void:
	print("playerdeathtest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
