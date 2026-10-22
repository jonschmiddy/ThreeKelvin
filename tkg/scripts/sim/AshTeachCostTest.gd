extends Node

## WHAT HER TEACHING COSTS A FRAME, headless, through the real screens:
##   godot --headless --fixed-fps 60 --path . -- sheet=AshTeachCostTest
##
## Jon, Oct 20: "When opening the starchart for the first time, and A.S.H. is
## reading the tutorial tip, the game becomes SUPER laggy and unresponsive. The
## game comes back after she's done talking." Measured on a 410-system chart:
## 840 ms a frame (2.3 s at most) while her line on the chart's list was up,
## against 6.9 ms with it gone. The cause was `Ash.covers`, the check that her
## box covers nothing a click picks, asked every tenth of a second while a
## teaching line is up (`_lesson_must_go`): it asked the chart's `_node_at` at
## every 3 px of her box, about 1,500 points, and each of those rebuilt the
## visible set over every system (0.8 ms): 1.2 s a check. It asks the systems
## near her box once now (`MapChart.nodes_near`), 1 ms.
##
## THE CLAIM, in the order a first run meets it: a run under way (her
## introduction heard, the launch's step said), the chart opened with nothing
## left to teach there, and its frames timed; then the hints reset, the chart
## opened again, and every frame timed while she says its list's line, types
## it and holds it, and while she says the goal's step after it. No frame over
## MAX_MS, and the mean within MEAN_SLACK of the chart with her silent.
## THE SAME ANSWER: `covers` finds exactly the system the old point-by-point
## scan found, on her box, on every spot she can stand in, and on boxes swept
## over the chart, hits and misses both.
##
## Times frames against the wall clock, so it is one of the gate's SOLO_UNITS.

## Any frame while she teaches; one was 2,305 ms.
const MAX_MS := 100.0
## Her mean frame against the chart without her: within this share, plus
## MEAN_PAD_MS for a headless frame's own noise. The MEAN, not the median: her
## check runs every tenth of a second, one frame in six at 60, so the median
## frame never held it (0.23 ms before the fix, with 43 frames over a second).
const MEAN_SLACK := 0.25
const MEAN_PAD_MS := 1.0
## The run measured: a ball galaxy of 410 systems, the one the lag was found on.
const SEED := 5150

var _tree: SceneTree
var _fails := 0
var _checks := 0


func _ok(what: String, c: bool) -> bool:
	_checks += 1
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _press() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := 0.0
	for x: float in a:
		t += x
	return t / float(a.size())


func _most(a: Array) -> float:
	var m := 0.0
	for x: float in a:
		m = maxf(m, x)
	return m


func _run() -> void:
	_tree = get_tree()
	await _frames(2)
	Ash.forced = true
	Ash.reload()
	Ash.set_on(true)
	Hints.forced = true
	Rng.forced = SEED
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Ash.mark_intro(true)
	print("a run under way: %d systems" % Run.map.size())
	# THE USED STATE: her launch step said on LOCAL, the ship's hint seen
	Hints.reset()
	Hints.mark_seen(&"ship")
	Hints.mark_seen(&"said_step_jump")
	Router.show_local()
	await _frames(60)
	Ash.waiting.clear()
	if Ash.portrait != null:
		Ash.portrait.cut()
	await _frames(4)
	_ok("on: she teaches, the hints are on", Ash.teaches() and Hints.enabled() and Hints.by_ash())

	# THE CHART WITH NOTHING LEFT TO TEACH THERE
	Hints.mark_seen(&"chart")
	Hints.mark_seen(&"said_step_jump_chart")
	Router.show_starchart()
	await _frames(40)
	var quiet := await _time(240, func() -> bool: return true)
	var base := _mean(quiet)
	_ok("the chart with her silent: nothing taught (%s), mean %.2f ms (median %.2f), most %.2f ms" % [Ash.lesson, base, _median(quiet), _most(quiet)],
		Ash.lesson == &"" and not quiet.is_empty())

	# HER LINE ON ITS LIST: opened again with it unsaid, every frame timed from
	# the frame she starts while she types it and holds it
	Hints.mark_seen(&"chart", false)
	Hints.mark_seen(&"said_step_jump_chart", false)
	Router.show_local()
	await _frames(30)
	Router.show_starchart()
	var waited := 0
	# (the frame she starts on timed too: where she stands is found then, every
	# spot asked what it covers -- 2.3 s on that one frame before)
	var first_ms := 0.0
	var tick := Time.get_ticks_usec()
	while Ash.lesson != &"chart" and waited < 300:
		await _tree.process_frame
		var now := Time.get_ticks_usec()
		first_ms = (now - tick) / 1000.0
		tick = now
		waited += 1
	if not _ok("she says the chart's list (%s, after %d frames)" % [Ash.lesson, waited], Ash.lesson == &"chart"):
		_finish()
		return
	_ok("  the frame she starts on: %.2f ms, under %.0f ms" % [first_ms, MAX_MS], first_ms < MAX_MS)
	var typed := {at = -1}
	var list := await _time(300, func() -> bool:
		if typed.at < 0 and Ash.portrait.phase == AshPortrait.Phase.HOLDING:
			typed.at = 1
		return Ash.lesson == &"chart")
	_judge("her line on the chart's list", list, base)
	_ok("  and it typed out and held while timed", typed.at > 0 and Ash.lesson == &"chart")
	_same_answer()
	# ITS ACTION DONE (stood in for: `Hints.spend`): then the goal's step in her
	# voice, no subject of its own
	await _frames(2)
	Hints.spend()
	waited = 0
	while Ash.lesson != &"step_jump_chart" and waited < 400:
		await _tree.process_frame
		waited += 1
	if _ok("then she says the step (%s, after %d frames)" % [Ash.lesson, waited], Ash.lesson == &"step_jump_chart"):
		var step := await _time(600, func() -> bool: return Ash.lesson == &"step_jump_chart")
		_judge("the step's line", step, base)
	_finish()


## Every frame's wall time, ms, for up to `n` frames while `cond` holds. A
## headless frame runs as fast as it can: its wall time is its work.
func _time(n: int, cond: Callable) -> Array:
	var out: Array = []
	var tick := Time.get_ticks_usec()
	for i in n:
		if not cond.call():
			break
		await _tree.process_frame
		var now := Time.get_ticks_usec()
		out.append((now - tick) / 1000.0)
		tick = now
	return out


func _judge(what: String, ms: Array, base: float) -> void:
	var mean := _mean(ms)
	var most := _most(ms)
	var over := ms.filter(func(x: float) -> bool: return x > MAX_MS).size()
	_ok("%s: %d frames, none over %.0f ms (most %.2f ms, %d over)" % [what, ms.size(), MAX_MS, most, over],
		ms.size() >= 60 and over == 0)
	_ok("%s: mean %.2f ms (median %.2f), within %d%% of the chart without her (%.2f ms)" % [what, mean, _median(ms),
		int(MEAN_SLACK * 100.0), base], mean <= base * (1.0 + MEAN_SLACK) + MEAN_PAD_MS)


## `covers` against the scan it replaced: `_node_at` at every 3 px of the box.
func _old_covers(mc: StarchartScreen.MapChart, r: Rect2) -> String:
	var inv := mc.get_global_transform().affine_inverse()
	var y := r.position.y
	while y <= r.end.y:
		var x := r.position.x
		while x <= r.end.x:
			var hit: int = mc._node_at(inv * Vector2(x, y))
			if hit >= 0:
				return "a system (%s)" % MapGen.star_name(Run.map[hit])
			x += 3.0
		y += 3.0
	return ""


func _same_answer() -> void:
	var cur := Router.current as StarchartScreen
	var mc := cur._chart
	var boxes: Array[Rect2] = [Ash.portrait.rect()]
	for s: Dictionary in Ash.tut_spot_boxes(cur, Ash.portrait.size):
		boxes.append(s.rect)
	# boxes swept over the chart, each on a system and between them
	var g := mc.get_global_rect()
	var here := Run.node_at()
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if boxes.size() >= 40:
			break
		var p := mc.get_global_transform() * mc._screen_pos(n)
		if not g.has_point(p) or not Run.charted(n) and n != here:
			continue
		boxes.append(Rect2(p - Vector2(30, 14), Vector2(60, 28)))
		boxes.append(Rect2(p + Vector2(20, 9), Vector2(60, 28)))
	var hits := 0
	var differ: Array[String] = []
	for r in boxes:
		var a := Ash.covers(cur, r)
		var b := _old_covers(mc, r)
		if a != "":
			hits += 1
		if a != b and differ.size() < 4:
			differ.append("%s: %s, was %s" % [r, a, b])
	var t0 := Time.get_ticks_usec()
	Ash.covers(cur, Ash.portrait.rect())
	var one := (Time.get_ticks_usec() - t0) / 1000.0
	_ok("covers finds what the point-by-point scan found on %d boxes (%d on a system), %.2f ms on her box (%s)" % [
		boxes.size(), hits, one, "; ".join(differ) if not differ.is_empty() else "the same on every one"],
		differ.is_empty() and hits > 0 and hits < boxes.size())


func _finish() -> void:
	Ash.forced = false
	Hints.forced = false
	Hints.reset()
	print("  %d checks" % _checks)
	print("AshTeachCostTest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)
