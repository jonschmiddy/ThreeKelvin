extends Node

## The science mini games, headless (`-- sheet=MiniGameTest [seeds=50]`): per game, 50 seeds at each
## depth deal the same puzzle twice, a scripted solve scores about 1, a give-up 0 to 0.2; then a
## solve through the shell's glass pays its tier, with the win then the reward sound.
## Why: docs/why/MiniGame.md#tests

const STEP := 1.0 / 30.0

var _h := Harness.new()
var _score := -1.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var seeds := int(Harness.arg("seeds", "50"))
	if Harness.arg("dump") != "":
		_dump(Harness.arg("dump"))
	_cost()
	_tiers()
	_haul()
	for id: StringName in MiniGames.ORDER:
		var t0 := Time.get_ticks_msec()
		for d in range(1, 6):
			var dealt := 0
			var same := 0
			var solved := 0
			var perfect := 0
			var quits := 0
			var worst := 1.0
			for s in range(1, seeds + 1):
				var sens := s % 6
				var a := _deal(id, d, sens, s)
				var b := _deal(id, d, sens, s)
				if a.is_empty():
					_h._fail("%s depth %d seed %d dealt no puzzle" % [id, d, s])
					continue
				dealt += 1
				if var_to_str(a) == var_to_str(b):
					same += 1
				var sc := _solve(id, d, sens, s)
				if sc >= 0.0:
					solved += 1
					worst = minf(worst, sc)
					if sc >= 0.95:
						perfect += 1
				var q := _quit(id, d, sens, s)
				if q >= 0.0 and q <= 0.2:
					quits += 1
			print("minigame %s depth %d: %d dealt, %d same twice, %d solved (worst %.2f), %d scored about 1, %d give-ups at 0 to 0.2"
				% [id, d, dealt, same, solved, worst, perfect, quits])
			_h._ok("%s depth %d: every seed deals a puzzle" % [id, d], dealt == seeds)
			_h._ok("%s depth %d: the same seed deals the same puzzle" % [id, d], same == seeds)
			_h._ok("%s depth %d: the solver solves every puzzle" % [id, d], solved == seeds)
			_h._ok("%s depth %d: a perfect solve scores about 1" % [id, d], perfect == seeds)
			_h._ok("%s depth %d: a give-up scores 0 to 0.2" % [id, d], quits == seeds)
		print("minigame %s: %d ms" % [id, Time.get_ticks_msec() - t0])
		_shell(id)
	_h.verdict("minigametest")
	get_tree().quit(_h.code())


## The puzzle as data, for comparing two deals.
func _deal(id: StringName, d: int, sens: int, s: int) -> Dictionary:
	match id:
		&"coolant":
			return GameCoolant.gen(d, sens, MiniGames.stream(s))
		&"centrifuge":
			return GameCentrifuge.gen(MiniGames.stream(s), d)
	return {}


func _mount(id: StringName, d: int, sens: int, s: int) -> MiniGame:
	var g := MiniGames.make(id)
	_score = -1.0
	g.finished.connect(func(sc: float, _detail: String) -> void: _score = sc)
	g.mount(d, sens, MiniGames.stream(s))
	return g


## The score a scripted solve earns through the game's input, or -1 if it never finished.
func _solve(id: StringName, d: int, sens: int, s: int) -> float:
	var g := _mount(id, d, sens, s)
	if g is GameCoolant:
		CoolantSolver.solve(g as GameCoolant)
	else:
		CentrifugeSolver.solve(g as GameCentrifuge)
	for k in 300:
		if _score >= 0.0:
			break
		g.tick(STEP)
	return _score


func _quit(id: StringName, d: int, sens: int, s: int) -> float:
	var g := _mount(id, d, sens, s)
	g.tick(STEP)
	g.give_up()
	return _score


## `dump=<dir>`: each game's puzzle (depth 3, sensors 1, seed 5) and its canvas at the start and
## solved but for the last move, for `tools/dev/minigame_diff.py` to hold against the prototype.
func _dump(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for id: StringName in MiniGames.ORDER:
		var g := _mount(id, 3, 1, 5)
		g.px.img.save_png(dir.path_join("%s_start.png" % id))
		var puz: Dictionary = ((g as GameCoolant).P if g is GameCoolant else (g as GameCentrifuge).P).duplicate(true)
		var taps := CoolantSolver.taps(g as GameCoolant) if g is GameCoolant else CentrifugeSolver.taps(g as GameCentrifuge)
		taps.resize(taps.size() - 1)
		for p in taps:
			g.down(p)
			g.up(p)
		g.px.img.save_png(dir.path_join("%s_end.png" % id))
		var f := FileAccess.open(dir.path_join("%s_puzzle.json" % id), FileAccess.WRITE)
		f.store_string(JSON.stringify({puzzle = puz, taps = taps.map(func(p: Vector2i) -> Array: return [p.x, p.y])}))
		f.close()


## What a frame of each game costs at sector 5 (printed, never asserted: it is the machine's).
func _cost() -> void:
	for id: StringName in MiniGames.ORDER:
		var g := _mount(id, 5, 0, 3)
		var cf := g as GameCentrifuge
		if cf != null:
			# a tube held: every move redraws
			cf.down(cf.cell_rect(0).get_center())
		var t0 := Time.get_ticks_usec()
		for k in 60:
			g.tick(STEP)
			if cf != null:
				cf.move(Vector2i(20 + k, 40))
		print("minigame %s: %.2f ms a drawn frame at sector 5" % [id, (Time.get_ticks_usec() - t0) / 60000.0])


func _tiers() -> void:
	var ok := true
	for d in range(1, 6):
		var top := mini(4, 2 + (d - 1) / 2)
		ok = ok and ScienceHaul.tier_of(1.0, d) == top and ScienceHaul.tier_of(0.0, d) == 0 \
			and ScienceHaul.tier_of(0.1, d) == 0 and ScienceHaul.tier_of(0.5, d) <= top
	_h._ok("the tier: depth raises the ceiling (rare, epic, legendary), a failure pays common", ok)


func _haul() -> void:
	var ok := true
	for t in 5:
		var row := ScienceHaul.row_for(t, &"mining", MiniGames.stream(7))
		ok = ok and not row.is_empty() and ScienceHaul.TIER_KEYS.find(StringName(row.tier)) <= t
	_h._ok("every tier pays a material at or under it", ok)


## The shell round a game: a solve through the glass (offset by where the game sits) ends it, the
## tier is the score's at its depth, the win then the reward sound play, the haul line shows.
func _shell(id: StringName) -> void:
	Audio.taping = true
	Audio.tape.clear()
	var sh := MiniShell.new()
	var tiers: Array[int] = []
	sh.scored.connect(func(tr: int) -> void:
		tiers.append(tr)
		sh.set_haul("TEST STOCK"))
	sh.start(MiniGames.make(id), 5, 0, MiniGames.stream(11))
	var g := sh.game
	var at := sh.at
	var taps := CoolantSolver.taps(g as GameCoolant) if g is GameCoolant else CentrifugeSolver.taps(g as GameCentrifuge)
	for p: Vector2i in taps:
		sh.press(p + at)
		sh.release(p + at)
		sh.tick(STEP)
	for k in 300:
		if sh.revealed:
			break
		sh.tick(STEP)
	Audio.taping = false
	var names: Array[String] = []
	for e: Array in Audio.tape:
		names.append(String(e[0]))
	_h._ok("%s on the glass: solved through it, once (tiers %s)" % [id, str(tiers)], tiers.size() == 1 and tiers[0] == ScienceHaul.tier_of(sh.score, 5))
	_h._ok("%s on the glass: a clean solve at sector 5 pays legendary (score %.2f)" % [id, sh.score], tiers.size() == 1 and tiers[0] == 4)
	var win := names.find("mg_win")
	var reward := names.find("mg_reward_4")
	_h._ok("%s: the win, then the reward a beat later (%s)" % [id, ", ".join(names)], win >= 0 and reward > win)
	_h._ok("%s: the haul line is revealed" % id, sh.revealed)
