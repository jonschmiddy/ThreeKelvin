extends Node

## Worker threads do pure CPU work only. Before Oct 14 they made textures and raced the main thread.
## That gave 26 errors in 20 s; now the main thread makes nodes and textures and workers only cut.
## Why: docs/why/ThreadStress.md#thread-stress

const IDS := ["custodian", "whale", "leviathan"]
const FAUNA_JOBS := 6
const BREAK_JOBS := 3
const VOICE_JOBS := 2
const PLAN_SHIPS := 2
const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")


class Counter extends Logger:
	var n := 0
	var first: Array[String] = []
	var lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lock.lock()
		n += 1
		if first.size() < 8:
			first.append("%s  (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _tree: SceneTree
var _log := Counter.new()
var _secs := 20.0
## Real time a plan let go of gets to finish (Jon, Nov 8: seconds, not frames;
## headless frames run uncapped, so 600 of them ran out on a busy gate).
const DRAIN_MS := 10000
## Real time for a clicked flight to fly once the workers are free, when the stress window had none.
const CLICK_GRACE_MS := 30000


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs="):
			_secs = float(a.substr(5))
	_run.call_deferred()


func _enemy(id: StringName) -> Combat.EnemyState:
	var e := Combat.EnemyState.new()
	e.template = DB.enemies[id]
	e.max_hp = e.template.max_hull
	e.hp = e.max_hp
	e.look = 0
	return e


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	OS.add_logger(_log)
	# What the workers cut: the three's pictures, full and half; and a dead
	# canvas of every kind, with its death styles.
	var cuts: Array = []
	for id in IDS:
		var e := _enemy(StringName(id))
		for sc in [1.0, 0.5]:
			cuts.append({img = FaunaMotion.still_canvas(e, e.hp, sc), k = FaunaMotion.kind_of(e.template.id),
				sc = sc, pic = FaunaMotion.picture_name(e)})
	var deaths: Array = []
	for id: StringName in DB.enemies:
		var e2 := _enemy(id)
		var dc := EnemyArt.dead_canvas(e2, null, 1.0)
		for n in 2:
			deaths.append({img = dc[0], used = dc[1], seed = EnemyArt.wreck_seed(e2.template),
				boss = e2.template.boss, style = EnemyArt.death_style(e2.template, 3, n)})
	var cards: Array = []
	for f in DirAccess.get_files_at("res://art/sprites/cards"):
		if f.ends_with(".png"):
			cards.append("res://art/sprites/cards/" + f)
	var takes: Array = []
	for f in DirAccess.get_files_at("res://assets/audio/voice/ash"):
		if f.ends_with(".ogg"):
			takes.append("res://assets/audio/voice/ash/" + f)
	var small := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	small.fill(Color(0.4, 0.6, 0.8, 1.0))
	print("threadstress: %.0f s, %d pictures to cut, %d deaths, %d card pictures" % [_secs, cuts.size(), deaths.size(), cards.size()])

	# the map's ships, each on a world's ring in a twin built to the
	# prototype's geometry (`SolveTest.twin_layout`)
	var twin_l: SystemLayout = load("res://scripts/sim/SolveTest.gd").twin_layout(300.0)
	var ships: Array = []
	for k in PLAN_SHIPS:
		var fl = ShipFlightS.new()
		fl.setup(twin_l, Vector2(-twin_l.edge * 0.95, 0.0), 0.0)
		fl.place_at(k % 2, 0.0)
		ships.append({fl = fl, next = 0})
	var places: Array[int] = [-1, SystemLayout.STAR_B, 0, 1, 2]
	# (a system of one star, every plan today's planner's on the worker)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var one_l: SystemLayout = null
	for raw in Run.map:
		var nd: MapGen.MapNode = raw
		if nd.type == MapGen.NodeType.SYSTEM and not nd.twin:
			var lo := SystemLayout.of(nd)
			var nw := 0
			for b in lo.bodies:
				if b.world != &"":
					nw += 1
			if nw >= 3:
				one_l = lo
				break
	var one_places: Array[int] = [-1]
	for b2 in one_l.bodies:
		if b2.world != &"":
			one_places.append(b2.index)
	var fo = ShipFlightS.new()
	fo.setup(one_l, Vector2(-one_l.edge * 0.95, 0.0), 0.0)
	fo.old_only = true
	fo.place_at(one_places[1], 0.0)
	ships.append({fl = fo, next = 0, places = one_places})
	for sh0: Dictionary in ships:
		if not sh0.has("places"):
			sh0.places = places
	var clicker = ShipFlightS.new()
	clicker.setup(twin_l, Vector2(-twin_l.edge * 0.95, 0.0), 0.0)
	clicker.place_at(0, 0.0)
	var n_click := 0
	var n_click_flown := 0
	var n_w := 0
	var n_setup := 0
	var n_freed := 0
	var ck_next := 0
	var n_plan := 0
	var n_old := 0
	var worst_plan := 0
	var plan_t := 0.0

	var fauna: Array = []    # in flight: {task, held}
	var breaks: Array = []
	var voices: Array = []
	var n_voice := 0
	var worst_voice := 0
	var vi := 0
	var n_cut := 0
	var n_break := 0
	var n_tex := 0
	var n_load := 0
	var worst_take := 0
	var worst_break := 0
	var ci := 0
	var di := 0
	var t_end := Time.get_ticks_msec() + int(_secs * 1000.0)
	while Time.get_ticks_msec() < t_end:
		# take in what finished, the way the game does, and start more
		for j in range(fauna.size() - 1, -1, -1):
			if WorkerThreadPool.is_task_completed(fauna[j].task):
				var t0 := Time.get_ticks_usec()
				var fm: FaunaMotion = _take_cut(fauna[j])
				worst_take = maxi(worst_take, Time.get_ticks_usec() - t0)
				if fm != null:
					fm.free()
				fauna.remove_at(j)
				n_cut += 1
		while fauna.size() < FAUNA_JOBS:
			fauna.append(_start_cut(cuts[ci % cuts.size()]))
			ci += 1
		for j in range(breaks.size() - 1, -1, -1):
			if WorkerThreadPool.is_task_completed(breaks[j].task):
				var t1 := Time.get_ticks_usec()
				var b: ShipBreakup = _take_break(breaks[j])
				worst_break = maxi(worst_break, Time.get_ticks_usec() - t1)
				if b != null:
					b.free()
				breaks.remove_at(j)
				n_break += 1
		while breaks.size() < BREAK_JOBS:
			breaks.append(_start_break(deaths[di % deaths.size()]))
			di += 1
		for j in range(voices.size() - 1, -1, -1):
			if WorkerThreadPool.is_task_completed(voices[j].task):
				var t3 := Time.get_ticks_usec()
				if _take_voice(voices[j]) != null:
					n_voice += 1
				worst_voice = maxi(worst_voice, Time.get_ticks_usec() - t3)
				voices.remove_at(j)
		while voices.size() < VOICE_JOBS and not takes.is_empty():
			voices.append(_start_voice(takes[vi % takes.size()]))
			vi += 1
		# the map's flight plans: taken in when done, the next asked for
		plan_t += 1.0 / 60.0
		for sh: Dictionary in ships:
			var fl = sh.fl
			var pls: Array[int] = sh.places
			fl.step(1.0 / 60.0, plan_t, {"w": false, "a": false, "s": false, "d": false})
			var t4 := Time.get_ticks_usec()
			var got: Dictionary = fl.take_bg(&"preview", plan_t)
			if not got.is_empty():
				worst_plan = maxi(worst_plan, Time.get_ticks_usec() - t4)
				if got.get("plan") != null:
					n_plan += 1
					if got.plan.res == null:
						n_old += 1
			if not fl.planning(&"preview"):
				var to: int = pls[int(sh.next) % pls.size()]
				sh.next = int(sh.next) + 1
				if to == fl.orbit_body():
					to = pls[int(sh.next) % pls.size()]
					sh.next = int(sh.next) + 1
				fl.plan_bg(to, plan_t, {}, &"preview", 1600)
		# The clicker as the map clicks: every third click
		# let go with W, every fifth set up afresh mid-plan.
		var none4 := {"w": false, "a": false, "s": false, "d": false}
		var cw := false
		if not (clicker._pend as Dictionary).is_empty() and ck_next % 3 == 1:
			cw = true
			n_w += 1
		clicker.step(1.0 / 60.0, plan_t, {"w": cw, "a": false, "s": false, "d": false} if cw else none4)
		if cw:
			clicker.place_at(0, plan_t)
		if clicker.can_fly() and (clicker._pend as Dictionary).is_empty():
			var to2: int = places[ck_next % places.size()]
			ck_next += 1
			if to2 != clicker.orbit_body():
				clicker.plan_bg(to2, plan_t, {}, &"preview", 1600)
				if clicker.fly_bg(to2, plan_t, func() -> void: pass):
					n_click += 1
				if ck_next % 5 == 0:
					clicker.setup(twin_l, Vector2(-twin_l.edge * 0.95, 0.0), plan_t)
					clicker.place_at(1, plan_t)
					n_setup += 1
		elif clicker.mode == &"fly" or clicker.rail.has("phase") and not clicker.rail.phase.get("wait", false):
			n_click_flown += 1
			clicker.place_at(ck_next % 2, plan_t)
		# A SHIP FREED MID-PLAN (the map left with a plan out): its task reaped
		if int(plan_t * 60.0) % 30 == 0:
			var tmp = ShipFlightS.new()
			tmp.setup(twin_l, Vector2(-twin_l.edge * 0.95, 0.0), plan_t)
			tmp.place_at(2, plan_t)
			if tmp.plan_bg(-1, plan_t, {}, &"preview", 1600):
				n_freed += 1
			tmp = null
		# the main thread's own textures, as many as a busy frame makes
		for k in 4:
			var tex := ResourceLoader.load(cards[(n_load + k) % cards.size()], "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			if tex != null:
				n_load += 1
		for k in 40:
			var t2 := ImageTexture.create_from_image(small)
			if t2.get_width() == 24:
				n_tex += 1
		for k in 10:
			Control.new().free()
		await _tree.process_frame
	for f in fauna:
		var fm2: FaunaMotion = _take_cut(f)
		if fm2 != null:
			fm2.free()
	for b2 in breaks:
		var bb: ShipBreakup = _take_break(b2)
		if bb != null:
			bb.free()
	for v in voices:
		_take_voice(v)
	# A two-core runner can fill the window planning (2 clicks in 20 s). With no new work the plan lands.
	var fly_until := Time.get_ticks_msec() + CLICK_GRACE_MS
	while n_click_flown == 0 and Time.get_ticks_msec() < fly_until:
		plan_t += 1.0 / 60.0
		clicker.step(1.0 / 60.0, plan_t, {"w": false, "a": false, "s": false, "d": false})
		if clicker.can_fly() and (clicker._pend as Dictionary).is_empty():
			var to3: int = places[ck_next % places.size()]
			ck_next += 1
			if to3 != clicker.orbit_body():
				clicker.plan_bg(to3, plan_t, {}, &"preview", 1600)
				if clicker.fly_bg(to3, plan_t, func() -> void: pass):
					n_click += 1
		elif clicker.mode == &"fly" or clicker.rail.has("phase") and not clicker.rail.phase.get("wait", false):
			n_click_flown += 1
		await _tree.process_frame
	# Take the last plans in a frame at a time; waiting
	# first hands `take_bg` a task the pool let go.
	for sh2: Dictionary in ships:
		var fl2 = sh2.fl
		var until := Time.get_ticks_msec() + DRAIN_MS
		while fl2.planning(&"preview") and Time.get_ticks_msec() < until:
			if fl2.take_bg(&"preview", plan_t).get("plan") != null:
				n_plan += 1
			await _tree.process_frame
		if fl2.planning(&"preview"):
			print("threadstress: a flight plan still being made after %.0f s" % (DRAIN_MS / 1000.0))
			_log.n += 1
	# (and every task let go of reaped, waited for as each finishes, no sooner)
	var until2 := Time.get_ticks_msec() + DRAIN_MS
	clicker._cancel_flight()
	while not ShipFlightS._reap.is_empty() and Time.get_ticks_msec() < until2:
		ShipFlightS.reap()
		await _tree.process_frame
	if not ShipFlightS._reap.is_empty():
		print("threadstress: %d flight plans let go of never finished" % ShipFlightS._reap.size())
		_log.n += 1
	OS.remove_logger(_log)
	print("threadstress: %d motion cuts, %d breakups, %d glitched takes, %d flight plans (%d today's planner's, made on the worker), %d card loads, %d main-thread textures" % [n_cut, n_break, n_voice, n_plan, n_old, n_load, n_tex])
	print("threadstress: the clicker: %d clicks, %d under way, %d let go of with W while planned, %d set up afresh mid-plan; %d ships freed mid-plan" % [n_click, n_click_flown, n_w, n_setup, n_freed])
	print("threadstress: slowest take-in on the main thread: a motion %.1f ms, a breakup %.1f ms, a take %.1f ms, a flight plan %.1f ms"
		% [worst_take / 1000.0, worst_break / 1000.0, worst_voice / 1000.0, worst_plan / 1000.0])
	for l in _log.first:
		print("  error: " + l)
	var ok := _log.n == 0 and n_cut > 0 and n_break > 0 and n_voice > 0 and n_plan > 0 and n_old > 0 and n_click_flown > 0 and n_freed > 0
	print("threadstress: %s (%d engine errors)" % ["PASS" if ok else "FAIL", _log.n])
	_tree.quit(0 if ok else 1)


# ------------------------------------------------- the jobs, as the game runs them

func _start_cut(c: Dictionary) -> Dictionary:
	var held := {}
	var img: Image = c.img
	var k: int = c.k
	var sc: float = c.sc
	var pic: String = c.pic
	var fm := FaunaMotion.new()
	var task := WorkerThreadPool.add_task(func() -> void:
		fm.cut(img, k, sc, pic)
		held.fm = fm)
	return {task = task, held = held}


func _take_cut(j: Dictionary) -> FaunaMotion:
	WorkerThreadPool.wait_for_task_completion(j.task)
	var fm: FaunaMotion = j.held.get("fm")
	if fm != null:
		fm.auto = false
		fm.attach()
	return fm


func _start_break(d: Dictionary) -> Dictionary:
	var held := {b = null, w = null}
	var img: Image = d.img
	var used: Rect2i = d.used
	var style: int = d.style
	var seed: int = d.seed
	var boss: bool = d.boss
	var b := ShipBreakup.new()
	var task := WorkerThreadPool.add_task(func() -> void:
		b.setup(img, used, Vector2.ZERO, style, seed, boss)
		held.b = b
		held.w = ShipBreakup.wreck_image(img, used, seed, boss, style))
	return {task = task, held = held}


func _take_break(j: Dictionary) -> ShipBreakup:
	WorkerThreadPool.wait_for_task_completion(j.task)
	var b: ShipBreakup = j.held.b
	if b != null:
		b.finish()
	return b


func _start_voice(path: String) -> Dictionary:
	var st := load(path) as AudioStream
	var held := {}
	var pb := st.instantiate_playback()
	var secs := st.get_length()
	var sr := AudioServer.get_mix_rate()
	var plan := LowHull.plan_for(secs, 0.05, LowHull.LOOKS[LowHull.Preset.STRONG])
	var task := WorkerThreadPool.add_task(func() -> void:
		held.b = VoiceGlitch.bake_placed(pb, secs, sr, plan).pcm)
	return {task = task, held = held, sr = sr}


func _take_voice(j: Dictionary) -> AudioStream:
	WorkerThreadPool.wait_for_task_completion(j.task)
	return VoiceGlitch.from_pcm(j.held.get("b", PackedByteArray()), float(j.sr))
