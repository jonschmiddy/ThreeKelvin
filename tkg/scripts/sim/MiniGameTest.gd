extends Node

## The science mini games, headless (`-- sheet=MiniGameTest [seeds=50] [games=a,b]`): per game, 50
## seeds at each depth deal the same puzzle twice, a scripted solve scores about 1, a give-up 0 to
## 0.2; then a solve through the shell's glass pays its tier, with the win then the reward sound.
## Why: docs/why/MiniGame.md#tests

const STEP := 1.0 / 30.0
## A scripted run gives up after this many steps (Four Kelvin's longest belt takes about 2,000).
const STEPS_MAX := 4000

var _h := Harness.new()
var _score := -1.0


func _ready() -> void:
	_run.call_deferred()


func _games() -> Array[StringName]:
	var out: Array[StringName] = []
	for g: String in Harness.arg("games", ",".join(MiniGames.ORDER)).split(",", false):
		out.append(StringName(g))
	return out


func _run() -> void:
	GameTray.memo_on = true
	var seeds := int(Harness.arg("seeds", "50"))
	if Harness.arg("dump") != "":
		_dump(Harness.arg("dump"))
	_cost()
	_tiers()
	_haul()
	if _games().has(&"tray"):
		_prefetch()
	for id in _games():
		var t0 := Time.get_ticks_msec()
		for d in range(1, 6):
			_depth(id, d, seeds)
		print("minigame %s: %d ms" % [id, Time.get_ticks_msec() - t0])
		_shell(id)
	_h.verdict("minigametest")
	get_tree().quit(_h.code())


func _depth(id: StringName, d: int, seeds: int) -> void:
	var t0 := Time.get_ticks_msec()
	var dealt := 0
	var same := 0
	var solved := 0
	var perfect := 0
	var quits := 0
	var worst := 1.0
	var slow := 0
	for s in range(1, seeds + 1):
		var sens := s % 6
		var t1 := Time.get_ticks_msec()
		var a := _deal(id, d, sens, s)
		slow = maxi(slow, Time.get_ticks_msec() - t1)
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
		else:
			print("  %s depth %d seed %d sensors %d: the scripted run never finished" % [id, d, s, sens])
		var q := _quit(id, d, sens, s)
		if q >= 0.0 and q <= 0.2:
			quits += 1
	print("minigame %s depth %d: %d dealt, %d same twice, %d solved (worst %.2f), %d scored about 1, %d give-ups at 0 to 0.2 (%d ms, slowest deal %d ms)"
		% [id, d, dealt, same, solved, worst, perfect, quits, Time.get_ticks_msec() - t0, slow])
	_h._ok("%s depth %d: every seed deals a puzzle" % [id, d], dealt == seeds)
	_h._ok("%s depth %d: the same seed deals the same puzzle" % [id, d], same == seeds)
	_h._ok("%s depth %d: the solver solves every puzzle" % [id, d], solved == seeds)
	_h._ok("%s depth %d: a perfect solve scores about 1" % [id, d], perfect == seeds)
	_h._ok("%s depth %d: a give-up scores 0 to 0.2" % [id, d], quits == seeds)


## The puzzle as data, for comparing two deals.
func _deal(id: StringName, d: int, sens: int, s: int) -> Dictionary:
	var r := MiniGames.stream(s)
	match id:
		&"coolant":
			return GameCoolant.gen(d, sens, r)
		&"centrifuge":
			return GameCentrifuge.gen(r, d)
		&"icecore":
			return GameIceCore.gen(r, d)
		&"pulsar":
			return GamePulsar.gen(r, d, sens)
		&"tray":
			# a real search, kept: the scripted solve and the give-up mount it without searching again
			var key := "%d:%d:%d" % [d, r.seed, r.state]
			var p := GameTray.gen(d, r)
			GameTray.memo[key] = {P = p.duplicate(true), end = r.state}
			return p
		&"anomaly":
			return GameAnomaly.gen(r, d)
		&"beams":
			return GameBeams.gen(r, d, sens)
		&"spectrum":
			return GameSpectrum.gen(r, d)
		&"fourkelvin":
			return GameFourKelvin.gen(r, d)
		&"torch":
			return TorchSim.gen(d, sens, r)
		&"leak":
			return GameLeak.gen(d, sens, r)
	return {}


func _mount(id: StringName, d: int, sens: int, s: int) -> MiniGame:
	var g := MiniGames.make(id)
	_score = -1.0
	g.finished.connect(func(sc: float, _detail: String) -> void: _score = sc)
	g.seed = s
	g.drawing = false
	g.mount(d, sens, MiniGames.stream(s))
	return g


## One scripted event, straight into the game.
static func send(g: MiniGame, e: Dictionary) -> void:
	match String(e.k):
		"key":
			g.key(e.key, true)
			return
		"keyup":
			g.key(e.key, false)
			return
	var p: Vector2 = e.p
	g.pf = p
	var q := Vector2i(p.floor())
	match String(e.k):
		"down":
			g.down(q)
		"move":
			g.move(q)
		"up":
			g.up(q)


## The score a scripted run earns through the game's input, or -1 if it never finished.
func _solve(id: StringName, d: int, sens: int, s: int) -> float:
	var g := _mount(id, d, sens, s)
	var sv := MiniSolver.for_game(g)
	for k in STEPS_MAX:
		if _score >= 0.0:
			break
		for e in sv.act(g, STEP):
			send(g, e)
		g.tick(STEP)
	return _score


func _quit(id: StringName, d: int, sens: int, s: int) -> float:
	var g := _mount(id, d, sens, s)
	g.tick(STEP)
	g.give_up()
	return _score


## `dump=<dir>`: each game at depth 3, sensors 1, seed 5, for `tools/dev/minigame/diff.py`: its deal
## as the page names it, the stream's draws after the deal, its canvas at the start, and after the
## scripted run's moves but the last and the frames the page draws them on.
func _dump(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for id: StringName in _games():
		var g := MiniGames.make(id)
		g.seed = 5
		var r := MiniGames.stream(5)
		g.mount(3, 1, r)
		var after := MiniGames.stream(5)
		_deal_into(id, after)
		var draws: Array[float] = []
		for i in 4000:
			draws.append(after.randf())
		var puz := MiniDump.puzzle(g)
		g.px.img.save_png(dir.path_join("%s_start.png" % id))
		var sv := MiniSolver.for_game(g)
		var evs: Array[Dictionary] = []
		if sv.plan.is_empty():
			evs = sv.act(g, 0.0)
		else:
			evs = sv.plan.slice(0, maxi(0, sv.plan.size() - 2))
		for e in evs:
			send(g, e)
		var ticks: Array = DUMP_TICKS.get(id, [])
		for dt: float in ticks:
			g.tick(dt)
		g.px.img.save_png(dir.path_join("%s_end.png" % id))
		var f := FileAccess.open(dir.path_join("%s_puzzle.json" % id), FileAccess.WRITE)
		f.store_string(JSON.stringify({puzzle = puz, draws = draws, seed = 5, events = MiniDump.js(evs), raf = DUMP_RAF.get(id, [])}))
		f.close()


## The frames each page draws after a move (its loop draws them, not the move), and the ticks here
## that match them: the first frame of most pages is 0.1 s (`last` starts at 0); Leak and Torch draw
## on their second.
const DUMP_RAF := {&"beams": [1100.0], &"spectrum": [1400.0], &"icecore": [1100.0], &"tray": [1100.0], &"anomaly": [1100.0], &"pulsar": [1100.0],
	&"leak": [1000.0, 1050.0], &"torch": [1000.0, 1050.0], &"fourkelvin": [1000.0]}
const DUMP_TICKS := {&"beams": [0.1], &"spectrum": [0.4], &"icecore": [0.1], &"tray": [0.1], &"anomaly": [0.1], &"pulsar": [0.1],
	&"leak": [0.0, 0.05], &"torch": [0.0, 0.05], &"fourkelvin": [0.0]}


## Deals into `r`, leaving it where the game's own deal left its stream.
func _deal_into(id: StringName, r: RandomNumberGenerator) -> void:
	match id:
		&"coolant":
			GameCoolant.gen(3, 1, r)
		&"centrifuge":
			GameCentrifuge.gen(r, 3)
		&"icecore":
			GameIceCore.gen(r, 3)
		&"pulsar":
			GamePulsar.gen(r, 3, 1)
		&"tray":
			GameTray.gen(3, r)
		&"anomaly":
			GameAnomaly.gen(r, 3)
		&"beams":
			GameBeams.gen(r, 3, 1)
		&"spectrum":
			GameSpectrum.gen(r, 3)
		&"fourkelvin":
			GameFourKelvin.gen(r, 3)
		&"torch":
			TorchSim.gen(3, 1, r)
		&"leak":
			GameLeak.gen(3, 1, r)


## What a frame of each game costs at sector 5 (printed, never asserted: it is the machine's).
func _cost() -> void:
	for id in _games():
		var g := MiniGames.make(id)
		g.mount(5, 0, MiniGames.stream(3))
		var sv := MiniSolver.for_game(g)
		var t0 := Time.get_ticks_usec()
		for k in 60:
			for e in sv.act(g, STEP):
				send(g, e)
			g.tick(STEP)
		print("minigame %s: %.2f ms a frame at sector 5, playing" % [id, (Time.get_ticks_usec() - t0) / 60000.0])


## The desk's card starts the tray's search on a worker; the mount takes that deal, the same one
## the search on the spot would have made, and leaves the stream at the same place.
func _prefetch() -> void:
	GameTray.memo_on = false
	GameTray.memo.clear()
	MiniGames.prefetch({id = &"tray", depth = 5, seed = 7})
	var g := MiniGames.make(&"tray") as GameTray
	g.drawing = false
	var r := MiniGames.stream(7)
	g.mount(5, 0, r)
	var r2 := MiniGames.stream(7)
	var want := GameTray.gen(5, r2)
	_h._ok("tray: the card's search on a worker deals what the mount would have", var_to_str(g.P) == var_to_str(want) and r.state == r2.state and GameTray.memo.is_empty())
	GameTray.memo_on = true


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


## The shell round a game: a scripted run through the glass (offset by where the game sits) ends
## it once, at the tier its score earns at sector 5; the win then the reward; NAME [TIER] shows.
func _shell(id: StringName) -> void:
	Audio.taping = true
	Audio.tape.clear()
	var sh := MiniShell.new()
	var tiers: Array[int] = []
	sh.scored.connect(func(tr: int) -> void:
		tiers.append(tr)
		sh.set_haul("TEST STOCK", &"legendary"))
	var g := MiniGames.make(id)
	sh.start(g, 5, 0, MiniGames.stream(11), 11)
	var sv := MiniSolver.for_game(g)
	for k in STEPS_MAX:
		if sh.revealed:
			break
		for e in sv.act(g, STEP):
			_send_glass(sh, e)
		sh.tick(STEP)
	Audio.taping = false
	var names: Array[String] = []
	for e: Array in Audio.tape:
		names.append(String(e[0]))
	_h._ok("%s on the glass: played through it, ended once (tiers %s)" % [id, str(tiers)], tiers.size() == 1 and tiers[0] == ScienceHaul.tier_of(sh.score, 5))
	_h._ok("%s on the glass: a clean run at sector 5 pays legendary (score %.2f)" % [id, sh.score], tiers.size() == 1 and tiers[0] == 4)
	var win := names.find("mg_win")
	var reward := names.find("mg_reward_4")
	_h._ok("%s: the win, then the reward a beat later (%s)" % [id, ", ".join(names.slice(maxi(0, names.size() - 6)))], win >= 0 and reward > win)
	_h._ok("%s: the haul line is revealed" % id, sh.revealed)
	var ink := false
	var quiet := false
	for y in range(MiniShell.STRIP_Y, MiniShell.STRIP_Y + 5):
		for x in MiniShell.GW:
			var c := sh.glass.get_pixel(x, y)
			ink = ink or c.is_equal_approx(UITheme.tier_colour(&"legendary"))
			quiet = quiet or c.is_equal_approx(MiniPix.COLD)
	_h._ok("%s: the line is the name in its tier's ink, then [TIER] quiet" % id, ink and quiet)


static func _send_glass(sh: MiniShell, e: Dictionary) -> void:
	match String(e.k):
		"key":
			sh.key(e.key, true)
		"keyup":
			sh.key(e.key, false)
		"down":
			sh.press((e.p as Vector2) + Vector2(sh.at))
		"move":
			sh.motion((e.p as Vector2) + Vector2(sh.at))
		"up":
			sh.release((e.p as Vector2) + Vector2(sh.at))
