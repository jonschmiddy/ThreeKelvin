class_name MiniSolver
extends RefCounted

## A scripted player for every ported mini game, playing a perfect run through the game's own input:
## each tick `act` hands back the events to send now ({k: down, move, up, key or keyup; p: the canvas
## point; key}), which the caller sends straight in, onto the glass or onto the screen.
## Why: docs/why/MiniGame.md#tests

var plan: Array[Dictionary] = []
var _i := 0
var _wait := 0.0
var _dyn := ""


static func for_game(g: MiniGame) -> MiniSolver:
	var s := MiniSolver.new()
	match g.id():
		&"coolant":
			s.plan = taps(CoolantSolver.taps(g as GameCoolant))
		&"centrifuge":
			s.plan = taps(CentrifugeSolver.taps(g as GameCentrifuge), 0.1)
		&"icecore":
			s.plan = _icecore(g as GameIceCore)
		&"tray":
			s.plan = _tray(g as GameTray)
		&"anomaly":
			s.plan = _anomaly(g as GameAnomaly)
		&"pulsar":
			s.plan = _pulsar(g as GamePulsar)
		&"leak":
			s.plan = _leak(g as GameLeak)
		&"beams":
			s.plan = _beams(g as GameBeams)
		&"spectrum":
			s.plan = _spectrum(g as GameSpectrum)
		&"sling":
			s.plan = SlingSolver.plan(g as GameSling)
		&"tuning":
			s.plan = _tuning(g as GameTuning)
		&"seismic":
			s.plan = _seismic(g as GameSeismic)
		&"corescan":
			s.plan = _corescan(g as GameCoreScan)
		&"culture":
			s.plan = _culture(g as GameCulture)
		&"fourkelvin", &"torch", &"dock", &"skim", &"flick", &"geyser":
			s._dyn = String(g.id())
	return s


## The events due now; [] while waiting or done.
func act(g: MiniGame, dt: float) -> Array[Dictionary]:
	if _dyn == "fourkelvin":
		return KelvinPilot.act(g as GameFourKelvin)
	if _dyn == "torch":
		return TorchPilot.act(g as GameTorch)
	if _dyn == "dock":
		return DockPilot.act(g as GameDock)
	if _dyn == "skim":
		return SkimPilot.act(g as GameSkim)
	if _dyn == "flick":
		return FlickPilot.act(g as GameFlick)
	if _dyn == "geyser":
		return GeyserPilot.act(g as GameGeyser)
	var out: Array[Dictionary] = []
	_wait -= dt
	while _i < plan.size() and _wait <= 0.0:
		var e := plan[_i]
		_i += 1
		out.append(e)
		_wait = float(e.get("wait", 0.0))
	return out


## Each point a tap: pressed and let go where it was pressed, `wait` seconds after.
static func taps(pts: Array[Vector2i], wait := 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in pts:
		out.append({k = "down", p = Vector2(p) + Vector2(0.5, 0.5)})
		out.append({k = "up", p = Vector2(p) + Vector2(0.5, 0.5), wait = wait})
	return out


static func _tap(out: Array[Dictionary], p: Vector2, wait := 0.0) -> void:
	out.append({k = "down", p = p})
	out.append({k = "up", p = p, wait = wait})


## Ice Core: each layer tapped into the tube oldest first (a tap fills the lowest gap), then CHECK.
static func _icecore(g: GameIceCore) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in g.n:
		if g.given.has(i):
			continue
		var j := g.pal_kinds.find(int(g.p.truth[i]))
		_tap(out, Vector2(GameIceCore.pal_xy(j)) + Vector2(GameIceCore.PW / 2.0, GameIceCore.PHH / 2.0))
	_tap(out, Vector2(GameIceCore.BCK.x + GameIceCore.BCK.y / 2.0, GameIceCore.BY + GameIceCore.BH / 2.0))
	return out


## Tray: the solver's own path, each move a drag of that canister to its new place.
static func _tray(g: GameTray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pos: Array[int] = g.pos.duplicate()
	for mv: Vector2i in g.P.path:
		var bk: Dictionary = g.B[mv.x]
		var w := int(bk.len) * GameTray.C if bk.h else GameTray.C
		var h := GameTray.C if bk.h else int(bk.len) * GameTray.C
		var at := Vector2(GameTray.GX + (pos[mv.x] if bk.h else int(bk.fix)) * GameTray.C, GameTray.GY + (int(bk.fix) if bk.h else pos[mv.x]) * GameTray.C) + Vector2(w / 2.0, h / 2.0)
		var shift := float(mv.y - pos[mv.x]) * GameTray.C
		var to := at + (Vector2(shift, 0) if bk.h else Vector2(0, shift))
		out.append({k = "down", p = at})
		out.append({k = "move", p = (at + to) / 2.0})
		out.append({k = "move", p = to})
		out.append({k = "up", p = to})
		pos[mv.x] = mv.y
	return out


## Anomaly: every match of each rule in turn.
static func _anomaly(g: GameAnomaly) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ans: Array in g.pz.answers:
		for i: int in ans:
			_tap(out, g.where(i))
	return out


## Pulsar: each pulsar's period set on the strip exactly, then LOCK.
static func _pulsar(g: GamePulsar) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for per: float in g.g0.P:
		var x := GamePulsar.SX + (per - GamePulsar.PMIN) / (GamePulsar.PMAX - GamePulsar.PMIN) * (GamePulsar.SW - 1)
		_tap(out, Vector2(x, GamePulsar.SY + 3))
		_tap(out, Vector2(GamePulsar.LB.get_center()))
	return out


## Leak Hunt: PATCH, then the leak, for each.
static func _leak(g: GameLeak) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in g.P.leaks:
		_tap(out, Vector2(GameLeak.btn("patch")))
		_tap(out, Vector2(l.x, l.y))
	return out


## Beams: the mirrors that differ from the nearest solution, each turned once.
static func _beams(g: GameBeams) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mir: Array = g.P.mir
	var cur := 0
	for k in mir.size():
		cur |= int(g.board[mir[k]].o) << k
	var best := -1
	for s: int in g.P.sols:
		if best < 0 or GameBeams.pop(s ^ cur) < GameBeams.pop(best ^ cur):
			best = s
	for k in mir.size():
		if ((best ^ cur) >> k) & 1:
			_tap(out, Vector2(g.cell_at(mir[k])) + Vector2(0.5, 0.5))
	return out


## Spectrum: the star's tubes not yet on, each switched once.
static func _spectrum(g: GameSpectrum) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in g.T:
		if (int(g.P.set) >> i) & 1 and not ((g.on >> i) & 1):
			_tap(out, Vector2(g.row_at(i)) + Vector2(0.5, 0.5))
	return out


## Tuning: each dial off the nearest matching setting tapped once on that setting's tick, then LOCK.
static func _tuning(g: GameTuning) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := g.best_eq()
	for k in g.knobs.size():
		var key: String = g.knobs[k].key
		if int(g.cur[key]) != int(e[key]):
			_tap(out, g.tick_at(k, int(e[key])))
	_tap(out, Vector2(GameTuning.LOCK.get_center()) + Vector2(0.5, 0.5))
	return out


## Seismic Scan: two scans off the finds (one near the middle, one by the find farthest from it), the
## DIG tool, then a dig on each find, each once the last sweep or drill is done.
static func _seismic(g: GameSeismic) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var deps: Array = g.P.deps
	var on_find := {}
	for q: Dictionary in deps:
		on_find[Vector2i(q.x, q.y)] = true
	var mid := Vector2((g.G - 1) / 2.0, (g.G - 1) / 2.0)
	var first := _seismic_spot(g, on_find, mid)
	var far := Vector2(int(deps[0].x), int(deps[0].y))
	for q: Dictionary in deps:
		if Vector2(q.x, q.y).distance_to(Vector2(first)) > far.distance_to(Vector2(first)):
			far = Vector2(q.x, q.y)
	on_find[first] = true
	var second := _seismic_spot(g, on_find, far + Vector2(0.5, 0.5))
	for c: Vector2i in [first, second]:
		_tap(out, Vector2(g.ccx(c.x), g.ccy(c.y)) + Vector2(0.5, 0.5), 2.0)
	_tap(out, Vector2(GameSeismic.CXL + GameSeismic.CW / 2, GameSeismic.TB_Y[1] + 6) + Vector2(0.5, 0.5), 0.1)
	for q: Dictionary in deps:
		_tap(out, Vector2(g.ccx(q.x), g.ccy(q.y)) + Vector2(0.5, 0.5), 0.9)
	return out


## The cell nearest `to` with no find under it (so a dig there never lands on a beacon).
static func _seismic_spot(g: GameSeismic, on_find: Dictionary, to: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var bd := INF
	for y in g.G:
		for x in g.G:
			var d := Vector2(x, y).distance_to(to)
			if not on_find.has(Vector2i(x, y)) and d < bd:
				bd = d
				best = Vector2i(x, y)
	return best


## Core Scan: every solid cell not yet filled, row by row.
static func _corescan(g: GameCoreScan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in g.n:
		for j in g.n:
			if g.grid[i][j] and g.st[i][j] != 1:
				_tap(out, Vector2(g.cell_xy(i, j)) + Vector2(0.5, 0.5), 0.12)
	return out


## Culture Dish: each seed of the deal's own answer dropped (a press and a lift), then GROW twice a
## ring: a press while the last ring still grows is not taken (the windowed run taps every 0.45 s,
## the ring takes 0.47), so two make sure of one; one past the last ring does nothing.
static func _culture(g: GameCulture) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in g.p.solution:
		_tap(out, Vector2(g.pos[i]) + Vector2(0.5, 0.5))
	out.back().wait = 0.1
	for k in int(g.p.steps) * 2:
		_tap(out, GameCulture.grow_at(), 0.6)
	return out
