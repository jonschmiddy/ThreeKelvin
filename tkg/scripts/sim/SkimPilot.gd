class_name SkimPilot
extends RefCounted

## A scripted Skim player (`MiniSolver`), moving the pointer as a player would. Each step it picks
## the spot behind the head, in the head's own frame, where the most young ice will be a moment on
## and no grit will pass (every rock's line is known: those in flight, and the deal's schedule of the
## rest), then pulls the probe there with the tether's lag taken out.
## Why: docs/why/MiniGame.md#skim

## How far ahead the ice is read, and the grit's window looked through after it.
const LEAD := 0.15
const LOOK := 0.6
const LOOK_STEP := 0.1
## The spots tried: distances past the keep-out ring, and across the tail's line.
const RS: Array[float] = [2.5, 4.0, 6.0, 8.5, 11.5, 15.0]
const LATS: Array[float] = [-13.5, -12.0, -10.5, -9.0, -7.5, -6.0, -4.5, -3.0, -1.5, 0.0, 1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0, 13.5]
## How near a rock may pass the probe.
const SAFE := 6.0
## What a pixel of travel costs a spot, in grains, so the probe does not hop for nothing.
const HOP := 0.15
## The pull it wants the probe to feel toward its spot.
const KP := 60.0
const KD := 14.0
## Their response, as a critically damped spring of this rate (sqrt KP).
const OMEGA := 7.75
const CELL := 2.0


static func act(g: GameSkim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if g.is_done() or g.over:
		return out
	var s := best(g)
	if not g.started:
		out.append({k = "down", p = _cell(s[0])})
		return out
	out.append({k = "move", p = _cell(_aim(g, s[0], s[1]))})
	return out


## [the spot now, the velocity it moves with (the head's)].
static func best(g: GameSkim) -> Array[Vector2]:
	var tc := g.ct
	var grid := _ice(g)
	var rocks := _grit(g)
	var h0 := Vector2(g.hx(tc), g.hy(tc))
	var hl := Vector2(g.hx(tc + LEAD), g.hy(tc + LEAD))
	var d0 := _dir(g, h0)
	var dl := _dir(g, hl)
	var frames: Array = []
	var tau := tc
	while tau <= tc + LOOK + 0.001:
		var h := Vector2(g.hx(tau), g.hy(tau))
		frames.append([tau, h, _dir(g, h)])
		tau += LOOK_STEP
	var p := Vector2(g.prx, g.pry)
	var top := -INF
	var pick := Vector2(g.prx, g.pry)
	for r in RS:
		for lat in LATS:
			var back := g.KEEP + r
			var now := h0 + d0 * back + Vector2(-d0.y, d0.x) * lat
			if now.x < 3.0 or now.x > GameSkim.W - 4 or now.y < GameSkim.PY + 3 or now.y > GameSkim.H - 4:
				continue
			var at := hl + dl * back + Vector2(-dl.y, dl.x) * lat
			var sc := _density(grid, at, g.CATCH) - HOP * now.distance_to(p)
			var clear := _clearance(frames, rocks, p, Vector2(g.prvx, g.prvy), back, lat)
			if clear < SAFE:
				# near a lane: under every clear spot, ranked by how far the grit passes
				sc = -1000.0 + clear * 50.0
			if sc > top:
				top = sc
				pick = now
	var hv := (Vector2(g.hx(tc + GameSkim.DT), g.hy(tc + GameSkim.DT)) - h0) / GameSkim.DT if g.started else Vector2.ZERO
	return [pick, hv]


static func _dir(g: GameSkim, h: Vector2) -> Vector2:
	var d := g.dir_at(h.x, h.y)
	return Vector2(d[0], d[1])


## The grains where they will be LEAD on, on 2 px cells: young ice (by then) counts 2.
static func _ice(g: GameSkim) -> Dictionary:
	var grid := {}
	for i in g.qx.size():
		var c := Vector2i(int(floorf((g.qx[i] + g.qvx[i] * LEAD) / CELL)), int(floorf((g.qy[i] + g.qvy[i] * LEAD) / CELL)))
		grid[c] = float(grid.get(c, 0.0)) + (2.0 if g.qage[i] + LEAD < g.qlife[i] * g.DBL else 1.0)
	return grid


static func _density(grid: Dictionary, at: Vector2, reach: float) -> float:
	var n := 0.0
	var c := Vector2i(int(floorf(at.x / CELL)), int(floorf(at.y / CELL)))
	var k := ceili(reach / CELL)
	for j in range(-k, k + 1):
		for i in range(-k, k + 1):
			var q := c + Vector2i(i, j)
			if grid.has(q) and (Vector2(q) * CELL + Vector2(1, 1)).distance_to(at) <= reach + 1.0:
				n += float(grid[q])
	return n


## Every rock that will fly in the window: [start, velocity, when], those in flight and those due.
static func _grit(g: GameSkim) -> Array:
	var out: Array = []
	for o in g.rocks:
		out.append([Vector2(o[0], o[1]), Vector2(o[2], o[3]), g.ct])
	var at: PackedFloat64Array = g.P.at
	var j := g.gi
	while j < at.size() and at[j] < g.ct + LOOK + LOOK_STEP:
		var t0 := at[j]
		var h := Vector2(g.hx(t0), g.hy(t0))
		var hv := (Vector2(g.hx(t0 + GameSkim.DT), g.hy(t0 + GameSkim.DT)) - h) / GameSkim.DT
		var a := _dir(g, h).angle() + float(g.P.off[j])
		out.append([h, Vector2(cos(a), sin(a)) * g.VS * float(g.P.sp[j]) + hv * 0.4, t0])
		j += 1
	return out


## How near a rock passes the probe on its way to the spot (back, lat in the head's
## frame) in the window. The way there is the tether's pull as `_aim` asks for it (critically damped
## at OMEGA, from where the probe is and how it moves); each rock and the probe move in a line
## between two frames, so the nearest they come in one is a point's distance to a segment.
static func _clearance(frames: Array, rocks: Array, p: Vector2, v: Vector2, back: float, lat: float) -> float:
	var at: Array[Vector2] = []
	var t0: float = frames[0][0]
	for f: Array in frames:
		var d: Vector2 = f[2]
		var s: Vector2 = f[1] + d * back + Vector2(-d.y, d.x) * lat
		var u: float = float(f[0]) - t0
		var e := exp(-OMEGA * u)
		at.append(p + v * u * e + (s - p) * (1.0 - (1.0 + OMEGA * u) * e))
	var near := INF
	for k in frames.size() - 1:
		var ta: float = frames[k][0]
		var tb: float = frames[k + 1][0]
		for o: Array in rocks:
			var w: float = o[2]
			if w > tb:
				continue
			var a: Vector2 = o[0] + o[1] * (maxf(ta, w) - w) - at[k]
			var b: Vector2 = o[0] + o[1] * (tb - w) - at[k + 1]
			near = minf(near, Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b).length())
	return near


## The pointer that pulls the probe onto `goal` (moving with `gv`): the acceleration wanted, less the
## tether's drag, over its spring, kept on the glass.
static func _aim(g: GameSkim, goal: Vector2, gv: Vector2) -> Vector2:
	var p := Vector2(g.prx, g.pry)
	var v := Vector2(g.prvx, g.prvy)
	var acc := (goal - p) * KP + (gv - v) * KD
	var a := p + (acc + v * GameSkim.DAMP) / g.SPRING
	return Vector2(clampf(a.x, 1.0, GameSkim.W - 2.0), clampf(a.y, GameSkim.PY + 1.0, GameSkim.H - 2.0))


static func _cell(p: Vector2) -> Vector2:
	return p.floor() + Vector2(0.5, 0.5)
