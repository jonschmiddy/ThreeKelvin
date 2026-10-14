extends Node

## WORKER THREADS DO PURE CPU WORK ONLY, under load, headless:
##   godot --headless --path . -- sheet=ThreadStress [secs=20]
## The fight's off-thread jobs, run back to back in parallel the way the game
## starts them -- a creature's or the Custodian's motion cut (`EnemySlot`), a
## breakup cut ahead of a kill (`SectorScreen._prebuild_death`) and a wreck
## warmed (`EnemyArt.warm_wreck`) -- while the main thread makes textures as
## fast as it can: card art loaded fresh from disk (`Database.card_art`'s
## `load`, uncached), pictures uploaded, controls made and freed. Every engine
## error is counted (a `Logger`); there must be none.
## Before Oct 14 the motion cut and the breakup made their textures, nodes and
## materials on the worker, and this raced the main thread's textures:
## "Attempting to initialize the wrong RID" on the worker, `Parameter "t" is
## null` in `texture_2d_initialize` on the main thread -- 26 errors in 20 s
## here alone, 64-94 in 90 s with three running at once; every run. Now the node is made on the main thread, the worker only
## cuts (its textures owed, `OffThread`), and the take-in (`FaunaMotion.attach`,
## `ShipBreakup.finish`) makes them; its slowest is printed (it is on the
## frame a creature's motion or a breakup starts).

const IDS := ["custodian", "whale", "leviathan"]
const FAUNA_JOBS := 6
const BREAK_JOBS := 3


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
	var small := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	small.fill(Color(0.4, 0.6, 0.8, 1.0))
	print("threadstress: %.0f s, %d pictures to cut, %d deaths, %d card pictures" % [_secs, cuts.size(), deaths.size(), cards.size()])

	var fauna: Array = []    # in flight: {task, held}
	var breaks: Array = []
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
	OS.remove_logger(_log)
	print("threadstress: %d motion cuts, %d breakups, %d card loads, %d main-thread textures" % [n_cut, n_break, n_load, n_tex])
	print("threadstress: slowest take-in on the main thread: a motion %.1f ms, a breakup %.1f ms"
		% [worst_take / 1000.0, worst_break / 1000.0])
	for l in _log.first:
		print("  error: " + l)
	var ok := _log.n == 0 and n_cut > 0 and n_break > 0
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
