class_name FlickPilot
extends RefCounted

## A scripted Flick player (`MiniSolver`), through the pointer as a player would: it grabs the chunk
## that will reach the ship soonest of those that need a hand (any rock, ice that would miss the bay),
## flings a rock off a side down a lane no other chunk will be in, and carries stray ice over the bay and lets it fall in.
## Why: docs/why/MiniGame.md#flick

## A rock is let go once it flies this fast, off the side it is thrown to.
const THROW := 140.0
## The bay's margin a falling chunk must keep inside, and how fast ice must fall to be let go.
const MARGIN := 4.0
const DROP := 25.0
## Ice that would land this close to the run's end, or after it, is carried in.
const LATE := 0.6
## Chunks are grabbed once below this row (clear of the nucleus), and ice let go once below LOW.
const CLEAR_Y := 48.0
const LOW := GameFlick.HULL - 40.0
## How clear of every other chunk a flung rock's lane must be.
const LANE_ROOM := 4.0

## The lane each held rock is being flung down, by game and chunk.
static var _lanes := {}


static func act(g: GameFlick) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if g.is_done() or g.over:
		return out
	var here := Vector2(g.ptr_x, g.ptr_y) + Vector2(0.5, 0.5)
	if not g.started:
		out.append({k = "down", p = Vector2(75.5, 80.5)})
		return out
	if not g.held.is_empty():
		var c: Dictionary = g.held
		var to := _throw(g, c) if c.rock else _carry(g, c)
		if to == Vector2.INF:
			out.append({k = "up", p = here})
		else:
			out.append({k = "move", p = to.floor() + Vector2(0.5, 0.5)})
		return out
	var job := next_job(g)
	if not job.is_empty():
		var at := Vector2(clampf(float(job.x), 0.0, GameFlick.W - 1.0), clampf(float(job.y), GameFlick.PY, GameFlick.H - 1.0))
		out.append({k = "down", p = at.floor() + Vector2(0.5, 0.5)})
	return out


## Where a falling chunk meets the hull row, and how soon (none: it is not falling).
static func landing(c: Dictionary) -> Vector2:
	if float(c.vy) <= 1.0:
		return Vector2(INF, 99.0)
	var eta := (GameFlick.HULL - float(c.r) - float(c.y)) / float(c.vy)
	return Vector2(float(c.x) + float(c.vx) * eta, eta)


## How soon a chunk off the ship's line leaves the glass.
static func _leaves(c: Dictionary) -> float:
	var k := 99.0
	var vx := float(c.vx)
	var vy := float(c.vy)
	if vx < -0.1:
		k = minf(k, (-10.0 - float(c.x)) / vx)
	elif vx > 0.1:
		k = minf(k, (GameFlick.W + 10.0 - float(c.x)) / vx)
	if vy < -0.1:
		k = minf(k, (GameFlick.PY - 12.0 - float(c.y)) / vy)
	return k


## Whether a chunk's line meets the ship (a thrown rock heading off the glass does not).
static func lands(l: Vector2) -> bool:
	return l.x != INF and l.x > -8.0 and l.x < GameFlick.W + 8.0


static func in_bay(g: GameFlick, x: float) -> bool:
	return x > g.BX0 + 1 + MARGIN and x < g.BX1 - 1 - MARGIN


## The chunk to grab: the soonest to land of those that need a hand (rocks a beat earlier).
static func next_job(g: GameFlick) -> Dictionary:
	var best := {}
	var bs := INF
	for c in g.chunks:
		var l := landing(c)
		var sc := l.y - (0.3 if c.rock else 0.0)
		if not lands(l):
			# a rock off the ship's line is no threat; ice knocked off it is caught before it leaves
			if c.rock:
				continue
			sc = _leaves(c)
		elif not c.rock and in_bay(g, l.x) and g.rt + l.y < g.T - LATE:
			# ice falling into the bay needs no hand, unless it would land after the run ends
			continue
		# left alone by the nucleus, where a throw would scatter the chunks just shed
		if float(c.y) < CLEAR_Y and lands(l):
			continue
		if sc < bs:
			bs = sc
			best = c
	return best


## A held rock: flung along the clearest lane off a side (`lane`, chosen at the grab); let go
## (INF) once it flies down that lane fast, or is nearly at the glass's edge.
static func _throw(g: GameFlick, c: Dictionary) -> Vector2:
	var key := "%d:%d" % [g.get_instance_id(), int(c.id)]
	if not _lanes.has(key):
		_lanes[key] = lane(g, c)
	var dir: Vector2 = _lanes[key]
	var at := Vector2(float(c.x), float(c.y))
	var to := _edge(at, dir)
	if Vector2(float(c.vx), float(c.vy)).dot(dir) >= THROW or at.distance_to(to) < 10.0:
		_lanes.erase(key)
		return Vector2.INF
	return to


## The lanes a rock may be flung down: up and level to the nearer side first, then the other side,
## then a little down. The first no chunk will be in (each at its own drift) wins; if none, the
## one the nearest chunk misses by most.
static func lane(g: GameFlick, c: Dictionary) -> Vector2:
	var side := -1.0 if float(c.x) < 75.0 else 1.0
	var best := Vector2(side, 0.0)
	var room := -INF
	for s: float in [side, -side]:
		for up: float in [-0.6, -0.25, 0.0, 0.25]:
			if up > 0.0 and float(c.y) > GameFlick.HULL - 40.0:
				continue
			var dir := Vector2(s, up).normalized()
			var near := _clearance(g, c, dir)
			if near >= LANE_ROOM:
				return dir
			if near > room:
				room = near
				best = dir
	return best


## How near the rock, flung down `dir` at about THROW px/s, comes to any other chunk on its way out.
static func _clearance(g: GameFlick, c: Dictionary, dir: Vector2) -> float:
	var at := Vector2(float(c.x), float(c.y))
	var span := at.distance_to(_edge(at, dir)) + 10.0
	var near := INF
	var tau := 0.0
	while tau * THROW <= span:
		var p := at + dir * THROW * tau
		for o in g.chunks:
			if int(o.id) == int(c.id):
				continue
			var q := Vector2(float(o.x) + float(o.vx) * tau, float(o.y) + float(o.vy) * tau)
			near = minf(near, p.distance_to(q) - float(o.r) - float(c.r))
		tau += 0.02
	return near


## Where a line from `at` along `dir` leaves the glass (the pointer stays on it).
static func _edge(at: Vector2, dir: Vector2) -> Vector2:
	var k := INF
	if dir.x < 0.0:
		k = minf(k, (0.0 - at.x) / dir.x)
	elif dir.x > 0.0:
		k = minf(k, (GameFlick.W - 1.0 - at.x) / dir.x)
	if dir.y < 0.0:
		k = minf(k, (GameFlick.PY - at.y) / dir.y)
	elif dir.y > 0.0:
		k = minf(k, (GameFlick.H - 1.0 - at.y) / dir.y)
	return at + dir * maxf(0.0, k)


## Held ice: over the bay first, then down into it; let go (INF) once it is falling into the bay.
static func _carry(g: GameFlick, c: Dictionary) -> Vector2:
	var l := landing(c)
	if float(c.vy) > DROP and float(c.y) > LOW and l.x != INF and in_bay(g, l.x):
		return Vector2.INF
	var mid := (g.BX0 + g.BX1) / 2.0
	if absf(float(c.x) - mid) > g.BW / 2.0 - 6.0:
		return Vector2(mid, minf(float(c.y), GameFlick.HULL - 16.0))
	return Vector2(mid, GameFlick.HULL + 12.0)
