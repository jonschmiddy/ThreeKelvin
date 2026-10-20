extends Node

## THE HULL FAILING (`LowHull`, `low_hull.gdshader`, `VoiceGlitch`), headless:
##   godot --headless --path . --fixed-fps 60 -- sheet=LowHullTest
## From a run under way, animated (`Router.animate_in_harness`):
##   * the state: off at half the hull; on at TIER1_AT exactly and stepping up
##     at TIER2_AT; easing in over EASE_S (part way at half of it, whole after
##     it) and out the same way when the hull is repaired; off at 0 hull, on the
##     title and with no run;
##   * every place a run is played: LOCAL, the sector map, the star chart, a
##     fight, the station;
##   * the red breathes, and never reaches the middle of the screen;
##   * the text glitches: some, at about the preset's rate, each on a text that
##     is on screen, none longer than GLITCH_S, none on the HUD's hull readout;
##   * NOTHING PRESSABLE MOVES: every control that takes the mouse keeps its rect
##     on every frame while it is on, and the glass ignores the mouse;
##   * reduced motion: the red still and faint (REDUCED_RED), no glitch at all;
##   * her voice: every preset's plan inside her words, short windows, a few at
##     most; rendered through Godot's decoder the take keeps its length to the
##     sample, is untouched outside its windows, and starts and ends each window
##     without a step; her portrait slips once for each glitch (none under
##     reduced motion, where her voice keeps the subtle preset's glitches).
## No pixels are looked at (headless draws nothing): the films are
## `-- sheet=LowHullFilm`'s.

var _tree: SceneTree
var _fails := 0


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


func _secs(s: float) -> void:
	var t0 := GameClock.now()
	while GameClock.now() - t0 < s:
		await _tree.process_frame


func _set_share(s: float) -> void:
	Run.hp = maxi(0, int(floorf(Run.max_hp() * s + 0.00001)))
	SectorScreen.shown_hull = -1
	Sig.resources_changed.emit()


## Every control that takes the mouse on the game's layer, by id: its rect.
func _hit_rects() -> Dictionary:
	var out := {}
	var main := LowHull.instance.get_parent()
	for n in main.find_children("*", "Control", true, false):
		var c := n as Control
		if c.mouse_filter == Control.MOUSE_FILTER_IGNORE or not c.is_visible_in_tree():
			continue
		out[c.get_instance_id()] = LowHull._screen_rect(c)
	return out


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	Router.animate_in_harness = true
	DisplaySettings.reduced_motion = false
	var lh := LowHull.instance
	_ok("the low-hull layer is up, over the game and under the menu (layer %d)" % LowHull.LAYER,
		lh != null and LowHull.LAYER > 0 and LowHull.LAYER < 10)
	if lh == null:
		_tree.quit(1)
		return
	_ok("its glass ignores the mouse and takes no focus",
		lh._rect.mouse_filter == Control.MOUSE_FILTER_IGNORE and lh._rect.focus_mode == Control.FOCUS_NONE)
	_ok("the preset is one constant, subtle by default", LowHull.PRESET == LowHull.Preset.SUBTLE)

	# no run: off
	await _secs(0.3)
	_ok("on the title, off", LowHull.tier == 0 and LowHull.on == 0.0)

	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM and not Router.no_fights_at(m):
			Run.at = m.index
			break
	Run.map[Run.at].visited = true
	Router.show_local()
	_set_share(0.5)
	await _secs(2.5)
	_ok("LOCAL, half the hull: off (tier %d, on %.2f, glass %s)" % [LowHull.tier, LowHull.on, lh._rect.visible],
		LowHull.tier == 0 and LowHull.on == 0.0 and not lh._rect.visible)
	var base := _hit_rects()
	_ok("a LOCAL with controls to keep still (%d)" % base.size(), base.size() > 5)
	# THE CONTROL: the same 8 s with the hull sound, so a control LOCAL moves of
	# its own accord is known before the effect is blamed for it
	var calm := 0
	for i in 480:
		await _tree.process_frame
		var r := _hit_rects()
		for id in base:
			if r.has(id) and not (r[id] as Rect2).is_equal_approx(base[id]):
				calm += 1
				base[id] = r[id]
	print("    (LOCAL moved %d controls of its own over 8 s with the hull sound)" % calm)
	base = _hit_rects()

	# ON, at the line exactly
	var top := Run.max_hp()
	Run.hp = int(floorf(top * LowHull.TIER1_AT))
	Sig.resources_changed.emit()
	var at_line := LowHull.tier_for(Run.hp, top)
	_ok("%d/%d (at %.0f%%) is on" % [Run.hp, top, LowHull.TIER1_AT * 100.0], at_line == 1)
	_ok("one over the line is off", LowHull.tier_for(int(floorf(top * LowHull.TIER1_AT)) + 1, top) == 0)
	_ok("the second step at %.0f%%" % (LowHull.TIER2_AT * 100.0),
		LowHull.tier_for(int(floorf(top * LowHull.TIER2_AT)), top) == 2
		and LowHull.tier_for(int(floorf(top * LowHull.TIER2_AT)) + 1, top) == 1)
	await _secs(LowHull.EASE_S * 0.5)
	var half_on := LowHull.on
	_ok("easing in: part way at half the ease (%.2f)" % half_on, half_on > 0.3 and half_on < 0.7)
	var moved := 0
	var worst := ""
	var worst_id := 0
	var reds: Array[float] = []
	var t0 := GameClock.now()
	LowHull.glitch_log.clear()
	var longest := 0.0
	var hull_hit := false
	var hp_nodes: Array = LowHull.steady()
	var hull_rects: Array[Rect2] = []
	for n in hp_nodes:
		hull_rects.append(LowHull._screen_rect(n as Control))
	var seen := {}
	while GameClock.now() - t0 < 8.0:
		await _tree.process_frame
		reds.append(LowHull.red_now)
		var now_r := _hit_rects()
		for id in base:
			if now_r.has(id) and not (now_r[id] as Rect2).is_equal_approx(base[id]):
				moved += 1
				worst = str(instance_from_id(id))
				worst_id = id
		for g: Dictionary in lh.live():
			var key := "%.5f" % float(g.until)
			if not seen.has(key):
				seen[key] = GameClock.now()
			longest = maxf(longest, float(g.until) - float(seen[key]))
			if hp_nodes.has(g.node):
				hull_hit = true
			for hr in hull_rects:
				if (g.rect as Rect2).intersects(hr):
					hull_hit = true
	_ok("whole after the ease (on %.2f)" % LowHull.on, LowHull.on >= 1.0)
	_ok("nothing that takes the mouse moved over 8 s of it (%d moves%s)" % [moved, (", " + worst) if moved > 0 else ""], moved == 0)
	if moved > 0:
		var wn := instance_from_id(worst_id) as Control
		print("    moved: %s %s -> %s" % [wn.get_path(), base[worst_id], LowHull._screen_rect(wn)])
	var lo := 9.0
	var hi := 0.0
	for r in reds.slice(70):
		lo = minf(lo, r)
		hi = maxf(hi, r)
	var red1: Array = LowHull.look().red
	_ok("the red breathes (%.3f to %.3f, the edge's most %.2f)" % [lo, hi, float(red1[0])],
		hi > lo * 1.3 and hi <= float(red1[0]) + 0.001 and lo > 0.0)
	var n1 := LowHull.glitch_log.size()
	var rate1: float = LowHull.look().rate[0]
	_ok("text glitches at about %.1f a second (%d in 8 s)" % [rate1, n1],
		n1 >= int(rate1 * 8.0 * 0.4) and n1 <= int(ceilf(rate1 * 8.0 * 2.2)))
	_ok("each a few frames at most (longest %.3f s)" % longest, longest <= LowHull.GLITCH_S[1] + 0.02)
	_ok("never on the HUD's hull readout", not hull_hit)
	var on_text := true
	for g: Dictionary in LowHull.glitch_log:
		var c: Node = g.node
		if not (c is Label or c is RichTextLabel or c is Button or c is SignalText):
			on_text = false
	_ok("every glitch on a text", on_text and n1 > 0)

	# THE SECOND STEP
	_set_share(LowHull.TIER2_AT)
	LowHull.glitch_log.clear()
	await _secs(LowHull.EASE_S + 0.1)
	_ok("the second step, eased in (deep %.2f)" % LowHull.deep, LowHull.tier == 2 and LowHull.deep >= 1.0)
	await _secs(8.0)
	var n2 := LowHull.glitch_log.size()
	_ok("more glitches on it (%d in 8 s against %d)" % [n2, n1], n2 >= n1 or n2 >= int(LowHull.look().rate[1] * 8.0 * 0.5))

	# REPAIRED
	_set_share(0.8)
	await _secs(LowHull.EASE_S * 0.5)
	_ok("repaired: easing out (on %.2f)" % LowHull.on, LowHull.on > 0.3 and LowHull.on < 0.7)
	await _secs(LowHull.EASE_S * 0.5 + 0.15)
	_ok("and off (on %.2f, glass %s)" % [LowHull.on, lh._rect.visible], LowHull.on == 0.0 and not lh._rect.visible)
	LowHull.glitch_log.clear()
	await _secs(2.0)
	_ok("no glitch once off", LowHull.glitch_log.is_empty())

	# EVERY PLACE A RUN IS PLAYED
	_set_share(0.2)
	var places := {}
	Router.show_system()
	await _secs(1.5)
	places["the sector map"] = LowHull.tier == 1 and LowHull.on > 0.9
	Router.show_starchart()
	await _secs(1.5)
	places["the star chart"] = LowHull.tier == 1 and LowHull.on > 0.9
	Router.show_local()
	await _secs(1.5)
	places["LOCAL"] = LowHull.tier == 1 and LowHull.on > 0.9
	Run.node_at().danger = maxi(Run.node_at().danger, 3)
	Router.start_combat(DB.enemies[&"cutter"], [], false, false)
	await _secs(1.5)
	places["a fight"] = LowHull.tier == 1 and LowHull.on > 0.9 and Router.current is SectorScreen and Router.combat != null
	# the fight's own count: a hit lands as it is shown
	SectorScreen.shown_hull = int(top * 0.1)
	await _frames(2)
	places["a fight, its shown hull at 10%"] = LowHull.tier == 2
	SectorScreen.shown_hull = -1
	var fight_base := _hit_rects()
	var fmoved := 0
	var plate_hit := false
	var steady := LowHull.steady()
	await _secs(0.5)
	LowHull.glitch_log.clear()
	for i in 360:
		await _tree.process_frame
		var r := _hit_rects()
		for id in fight_base:
			if r.has(id) and not (r[id] as Rect2).is_equal_approx(fight_base[id]):
				fmoved += 1
		for g: Dictionary in lh.live():
			for n in steady:
				if g.node == n or (g.rect as Rect2).intersects(LowHull._screen_rect(n)):
					plate_hit = true
	_ok("in a fight nothing that takes the mouse moved over 6 s (%d)" % fmoved, fmoved == 0)
	_ok("in a fight the plate under your ship is held steady too (%d readout nodes, %d glitches)" % [steady.size(), LowHull.glitch_log.size()],
		steady.size() >= 5 and not plate_hit and LowHull.glitch_log.size() > 0)
	Router.combat = null
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.STATION:
			Run.at = m.index
			m.visited = true
			break
	Router.park_at_station()
	Router.show_station()
	_set_share(0.2)
	await _secs(1.5)
	places["the station"] = LowHull.tier == 1 and LowHull.on > 0.9 and Router.current is StationScreen
	for k in places:
		_ok("on at %s" % k, places[k])
	_set_share(0.0)
	await _frames(2)
	_ok("off at 0 hull (the ship's loss has its own picture)", LowHull.tier == 0)
	_set_share(0.2)
	Router.show_launcher()
	await _frames(2)
	_ok("off on the title", LowHull.tier == 0 and not LowHull.in_run())

	# REDUCED MOTION
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	DisplaySettings.reduced_motion = true
	_set_share(0.2)
	await _secs(LowHull.EASE_S + 0.2)
	LowHull.glitch_log.clear()
	var rlo := 9.0
	var rhi := 0.0
	for i in 240:
		await _tree.process_frame
		rlo = minf(rlo, LowHull.red_now)
		rhi = maxf(rhi, LowHull.red_now)
	var want := float(LowHull.look().red[0]) * LowHull.REDUCED_RED
	_ok("reduced motion: the red stands still and faint (%.3f to %.3f, want %.3f)" % [rlo, rhi, want],
		absf(rhi - rlo) < 0.0001 and absf(rhi - want) < 0.001)
	_ok("reduced motion: no glitch in 4 s", LowHull.glitch_log.is_empty() and lh.live().is_empty())
	_ok("reduced motion: her voice keeps the subtle preset", LowHull.voice_look() == LowHull.LOOKS[LowHull.Preset.SUBTLE])
	DisplaySettings.reduced_motion = false

	await _voice()
	await _portrait()
	DisplaySettings.reduced_motion = false
	print("LowHullTest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


# ------------------------------------------------------------------ her voice

func _takes() -> Array:
	var out: Array = []
	var d := DirAccess.open("res://assets/audio/voice/ash")
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".ogg"):
			out.append("res://assets/audio/voice/ash/" + f)
	out.sort()
	return out


func _voice() -> void:
	print("her voice")
	var takes := _takes()
	_ok("her takes are there (%d)" % takes.size(), takes.size() >= 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := ""
	var most := 0
	var none_short := 0
	for p in LowHull.Preset.values():
		var lk: Dictionary = LowHull.LOOKS[p]
		for path in takes:
			var secs := (load(path) as AudioStream).get_length()
			for t in [1, 2]:
				var plan := LowHull.plan_for(secs, t, lk, rng)
				most = maxi(most, plan.size())
				if plan.is_empty() and secs > 0.9:
					none_short += 1
				var last := -9.0
				for g: Dictionary in plan:
					var cap := 0.151 if g.kind == &"wobble" else 0.061
					if float(g.at) < 0.1 or float(g.at) + float(g.len) > secs - 0.2 or float(g.len) > cap \
							or float(g.at) - last < 0.2:
						bad = "%s %s %s" % [path.get_file(), g.kind, g.at]
					last = float(g.at) + float(g.len)
	_ok("every plan inside her words, each window short, apart%s" % ((" (" + bad + ")") if bad != "" else ""), bad == "")
	_ok("a few a line at most (%d)" % most, most <= 4 and most >= 2)
	_ok("every line of a second or more gets at least one", none_short == 0)

	# rendered through Godot's decoder
	var worst_edge := 0.0
	var outside := 0
	var changed := true
	var same_len := true
	var ms := 0.0
	var lk2: Dictionary = LowHull.LOOKS[LowHull.Preset.STRONG]
	for path in takes.slice(0, 8):
		var st := load(path) as AudioStream
		var t := Time.get_ticks_usec()
		var d := VoiceGlitch.decode(st)
		var x: PackedVector2Array = d.x
		var sr: float = d.sr
		var plan := LowHull.plan_for(st.get_length(), 2, lk2, rng)
		var y := VoiceGlitch.apply(x.duplicate(), sr, plan)
		var wav := VoiceGlitch.to_wav(y, sr)
		ms = maxf(ms, (Time.get_ticks_usec() - t) / 1000.0)
		if wav == null or absf(wav.get_length() - st.get_length()) > 1.5 / sr + 0.0005 or y.size() != x.size():
			same_len = false
		var inside := PackedByteArray()
		inside.resize(x.size())
		for g: Dictionary in plan:
			var s := int(float(g.at) * sr)
			var n := int(float(g.len) * sr)
			for i in range(s, mini(x.size(), s + n)):
				inside[i] = 1
			var diff := 0.0
			for i in range(s, s + n):
				diff = maxf(diff, (y[i] - x[i]).length())
			if diff < 0.0005 and g.kind != &"gap":
				changed = false
			# the edges: the step into and out of the window against the take's own
			# steps across the window
			var own := 0.0
			for i in range(s - 200, s + n + 200):
				own = maxf(own, (x[i + 1] - x[i]).length())
			var e := 0.0
			for i in [s - 1, s, s + 1, s + n - 2, s + n - 1, s + n]:
				e = maxf(e, (y[i + 1] - y[i]).length())
			worst_edge = maxf(worst_edge, e / maxf(own, 1e-4))
		for i in x.size():
			if inside[i] == 0 and not y[i].is_equal_approx(x[i]):
				outside += 1
	_ok("rendered, her take keeps its length to the sample", same_len)
	_ok("untouched outside its windows (%d samples differ)" % outside, outside == 0)
	_ok("each window changes what she says", changed)
	_ok("no step into or out of a window (worst %.2f x the take's own)" % worst_edge, worst_edge <= 1.05)
	_ok("the worker's whole job (decode, glitch, 16-bit PCM) %.1f ms at worst, inside her power-on (%.2f s)" % [ms, AshPortrait.VOICE_AT],
		ms < AshPortrait.VOICE_AT * 1000.0 * 0.5)


func _portrait() -> void:
	print("her portrait, in step")
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	_set_share(0.2)
	await _secs(1.2)
	var line := ""
	for k in AshLines.MOMENTS:
		for l in AshLines.of(k):
			if AshLines.voice_path(String(l)) != "" and String(l).length() > 40:
				line = String(l)
				break
		if line != "":
			break
	for rm in [false, true]:
		DisplaySettings.reduced_motion = rm
		var p := AshPortrait.new()
		LowHull.instance.get_parent().add_child(p)
		p.say(line, &"hurt")
		var t0 := GameClock.now()
		while p.phase != AshPortrait.Phase.GONE and GameClock.now() - t0 < 14.0:
			await _tree.process_frame
		var plan := Audio.voice_glitches.size()
		if rm:
			_ok("reduced motion: her voice still glitches (%d), the portrait never slips (%d)" % [plan, p.glitch_slips],
				plan > 0 and p.glitch_slips == 0)
		else:
			_ok("her voice glitches (%d) and the portrait slips once for each (%d)" % [plan, p.glitch_slips],
				plan > 0 and p.glitch_slips == plan)
		p.queue_free()
		await _frames(2)
	DisplaySettings.reduced_motion = false

	# MADE OFF THE MAIN THREAD (`Audio.ash_voice_prepare`): the glitched take
	# baked on a worker during her power-on, and her line's start on the main
	# thread costing only the stream made from the bytes
	var path := AshLines.voice_path(line)
	var st := load(path) as AudioStream
	var t_old := Time.get_ticks_usec()
	VoiceGlitch.render(st, LowHull.plan_for(st.get_length(), 1, LowHull.look()))
	var old_ms := (Time.get_ticks_usec() - t_old) / 1000.0
	Audio.bake_headless = true
	var p2 := AshPortrait.new()
	LowHull.instance.get_parent().add_child(p2)
	p2.say(line, &"hurt")
	# HEADLESS GAME TIME RUNS FASTER THAN THE WALL: the 0.35 s of her power-on
	# can pass in a few milliseconds here, where in play it is 0.35 s of real
	# time and the worker's 40 ms fits in it many times. So the wall time her
	# power-on would take is given back to the worker before the game moves on
	# (the worker's own time is checked above, against VOICE_AT).
	var wall := Time.get_ticks_msec()
	while int(Audio._prep.get("task", -1)) >= 0 and not WorkerThreadPool.is_task_completed(int(Audio._prep.task)) \
			and Time.get_ticks_msec() - wall < int(AshPortrait.VOICE_AT * 1000.0):
		OS.delay_msec(1)
	var started := false
	var start_ms := 0.0
	var t1 := GameClock.now()
	while p2.phase != AshPortrait.Phase.GONE and GameClock.now() - t1 < 14.0:
		await _tree.process_frame
		if not started and p2.voice_started_at >= 0.0:
			started = true
			start_ms = Audio.voice_start_usec / 1000.0
	var plan2 := Audio.voice_glitches.size()
	_ok("baked on a worker during her power-on: heard glitched (%s), %d glitches, the portrait in step (%d)" % [
		Audio.voice_heard_glitched, plan2, p2.glitch_slips],
		Audio.voice_heard_glitched and plan2 > 0 and p2.glitch_slips == plan2)
	_ok("her line's start costs the main thread %.2f ms (the old way, all of it on the main thread: %.1f ms)" % [start_ms, old_ms],
		start_ms < 2.0)
	p2.queue_free()
	await _frames(2)
	# NOT READY IN TIME: the clean take, nothing planned, no slips, no wait
	Audio.bake_hold = true
	var p3 := AshPortrait.new()
	LowHull.instance.get_parent().add_child(p3)
	p3.say(line, &"hurt")
	var t2 := GameClock.now()
	var start3 := -1.0
	while p3.phase != AshPortrait.Phase.GONE and GameClock.now() - t2 < 14.0:
		await _tree.process_frame
		if start3 < 0.0 and p3.voice_started_at >= 0.0:
			start3 = Audio.voice_start_usec / 1000.0
	_ok("a take not baked in time: the clean take, no glitches, no slips, no wait (%.2f ms)" % start3,
		not Audio.voice_heard_glitched and Audio.voice_glitches.is_empty() and p3.glitch_slips == 0 and start3 < 2.0)
	p3.queue_free()
	Audio.bake_hold = false
	Audio.bake_headless = false
	await _frames(30)
	_ok("its worker reaped once done", Audio._reap.is_empty())
	_set_share(0.9)
	await _frames(2)
	_ok("the hull sound: no glitches planned", LowHull.voice_plan(3.0).is_empty())
