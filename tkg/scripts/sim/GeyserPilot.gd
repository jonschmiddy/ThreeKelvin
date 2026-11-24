class_name GeyserPilot
extends RefCounted

## A scripted Geyser player (`MiniSolver`), through the pointer's x as a player would: it rides the
## core of its jet and hops to the next vent. When to leave is planned: before each hop it flies the
## rest of the run on a ghost of the game for a few leaving times (and for staying put) and takes the
## best. It steers the thrusters for the acceleration it wants, with the gas's push and pull taken out.
## Why: docs/why/MiniGame.md#geyser

## The acceleration a hop is planned at (the thrusters give 55), the approach's gains.
const A := 45.0
const KP := 3.0
const KV := 7.0
## A jet counts as burning this long after it wakes; reach is this far inside the glass's edge.
const RAMP := 0.3
const REACH := 8.0
## The plain rule for a hop no ghost plans: leave this long before `plain_leave` says.
const EARLY := 0.8
## The leaving times tried for a hop, around `plain_leave`'s; INF stays in the jet for good. A ghost
## chooses its own next hop from SUB, and later ones by the plain rule.
const TRY: Array[float] = [-2.4, -2.0, -1.6, -1.2, -0.8, -0.4, 0.0, 0.4, 0.8, INF]
const SUB: Array[float] = [-1.6, -0.8, 0.0, 0.8]
const LEVELS := 2
const STEP := 1.0 / 30.0
const COPIED: Array[String] = ["T", "V", "W0", "SWAY", "GUST", "PUSH", "RATE", "gt", "started", "fill", "prx", "pry", "prvx", "prvy",
	"ptr_x", "thr", "fill_on", "_acc"]
## Each game's ride, by instance: [vent index, the planned leaving time of the next hop or NAN].
static var _ride := {}


static func act(g: GameGeyser) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if g.is_done() or g.over:
		_ride.erase(g.get_instance_id())
		return out
	if not g.started:
		out.append({k = "down", p = Vector2(g.prx, g.pry + 14.0).floor() + Vector2(0.5, 0.5)})
		return out
	out.append({k = "move", p = Vector2(steer(g, _target(g, LEVELS)), g.pry)})
	return out


## The pointer's x (a pixel's middle) that gives the acceleration wanted toward vent `v`'s core:
## near time-optimal toward it, matching its drift and sway.
static func steer(g: GameGeyser, v: Dictionary) -> float:
	var tt := g.gt
	var xc := core_x(g, v, tt)
	var vc := (core_x(g, v, tt + 0.05) - xc) / 0.05
	var err := xc - g.prx
	var vdes := vc + signf(err) * minf(sqrt(2.0 * A * absf(err)), KP * absf(err))
	var gs := g.gas(g.prx, g.pry, tt)
	var gx := (75.0 - g.prx) / (GameGeyser.CY - g.pry) * GameGeyser.G
	var want := (vdes - g.prvx) * KV - gs[0] - gx
	return floorf(clampf(g.prx + (want + g.prvx * 4.5) / 10.0, 2.0, GameGeyser.W - 3.0)) + 0.5


## The x of a vent's core at the sampler's height at time `tt`.
static func core_x(g: GameGeyser, v: Dictionary, tt: float) -> float:
	var a := g.axis(v, tt)
	if a[3] >= -0.01:
		return a[0]
	var al := maxf(0.0, (g.pry - a[1]) / a[3])
	return a[0] + a[2] * al


## When vent `v` is burning and its core is within reach of the sampler's height.
static func ready_at(g: GameGeyser, v: Dictionary) -> float:
	var tau := maxf(g.gt, g.t_ign(v) + RAMP)
	while tau < g.t_die(v) and core_x(g, v, tau) > GameGeyser.W - REACH:
		tau += 0.1
	return tau


## The plain rule's leaving time for the hop from vent i: get there just as the next is ready, or
## leave once the old one's strong life ends, whichever is later.
static func plain_leave(g: GameGeyser, i: int) -> float:
	var nx := g.vents[i + 1]
	var ok := ready_at(g, nx)
	var travel := 2.0 * sqrt(absf(core_x(g, nx, ok) - g.prx) / A)
	return maxf(ok - travel, g.t_die(g.vents[i]) - 1.1 - RAMP)


## The vent to ride now. At `level` 1 or more each hop's leaving time is planned on ghosts (TRY at
## the top, SUB below); at 0, by the plain rule.
static func _target(g: GameGeyser, level: int) -> Dictionary:
	var key := g.get_instance_id()
	var ride: Array = _ride.get(key, [0, NAN])
	var i: int = ride[0]
	var n := g.vents.size()
	while i < n - 1 and g.t_die(g.vents[i]) <= g.gt:
		i += 1
		ride[1] = NAN
	if i + 1 < n:
		if level <= 0:
			# reckoned once, as it reaches each vent
			if is_nan(float(ride[1])):
				ride[1] = plain_leave(g, i) - EARLY
		else:
			var base := plain_leave(g, i)
			var grid: Array[float] = TRY if level >= LEVELS else SUB
			if is_nan(float(ride[1])) and g.gt >= base + grid[0]:
				ride[1] = _choose(g, i, base, grid, level)
		if not is_nan(float(ride[1])) and g.gt >= float(ride[1]):
			i += 1
			ride[1] = NAN
	ride[0] = i
	_ride[key] = ride
	return g.vents[i]


## The leaving time whose ghost run ends fullest (the earlier on a tie).
static func _choose(g: GameGeyser, i: int, base: float, grid: Array[float], level: int) -> float:
	var best := base
	var top := -1.0
	for d in grid:
		var leave := INF if d == INF else maxf(g.gt, base + d)
		var sc := _ghost(g, i, leave, level - 1)
		if sc > top + 0.001:
			top = sc
			best = leave
	return best


## The score of the rest of the run flown on a copy of the game's physics (no motes, nothing drawn),
## hopping from vent i at `leave`, its later hops chosen at `level`.
static func _ghost(g: GameGeyser, i: int, leave: float, level: int) -> float:
	var c := GameGeyser.new()
	c.drawing = false
	c.depth = g.depth
	c.sensors = g.sensors
	c.vents = g.vents
	for k in COPIED:
		c.set(k, g.get(k))
	var score := [-1.0]
	c.finished.connect(func(s: float, _d: String) -> void: score[0] = s)
	var key := c.get_instance_id()
	var held := true
	while float(score[0]) < 0.0:
		if held and c.gt >= leave:
			held = false
			_ride[key] = [i + 1, NAN]
		var v: Dictionary = g.vents[i] if held else _target(c, level)
		c.move(Vector2i(int(steer(c, v)), 0))
		c.tick(STEP)
	_ride.erase(key)
	return float(score[0])
