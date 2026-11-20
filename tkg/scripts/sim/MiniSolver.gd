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
		&"fourkelvin", &"torch":
			s._dyn = String(g.id())
	return s


## The events due now; [] while waiting or done.
func act(g: MiniGame, dt: float) -> Array[Dictionary]:
	if _dyn == "fourkelvin":
		return KelvinPilot.act(g as GameFourKelvin)
	if _dyn == "torch":
		return TorchPilot.act(g as GameTorch)
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
		_tap(out, Vector2(48 + 22, GameLeak.BY + 8))
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
			_tap(out, Vector2(GameSpectrum.row_at(i)) + Vector2(0.5, 0.5))
	return out
