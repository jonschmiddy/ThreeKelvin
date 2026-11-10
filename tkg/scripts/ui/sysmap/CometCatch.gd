extends Node

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")

## THE CATCH (Phase 13, Jon's C, "wait on its path"): three spots on the comet's path, a race
## to each, a wait there, and the pass in LOCAL where its reading is taken. The map screen's.
## Why: docs/why/CometCatch.md#the-catch

## the map screen (`SystemMapScreen`)
var screen
## Seconds the ship must be settled at a spot before the comet reaches it.
const MARGIN := 1.0
## The pass starts this long before the comet reaches the spot (s of map time).
const PASS_LEAD := 0.4
## A spot is still the ship's while it is this near it (plane px).
const HOLD_PX := 3.0
## The race is planned again this often (s, wall clock), off the main thread.
const REPLAN_S := 0.5

## Each spot's time to it by the last plan: seconds from that plan's moment to settled there,
## INF unknown. Read by the panel; written from the worker's results on the main thread.
var you: Array[float] = [INF, INF, INF]
var _res: Array = [null, null, null]
var _dep: Dictionary = {}
var _plan_t := -INF
var _plan_at := -INF
var _job := -1
var _box: _Solved = null
## The spot the ship is flying to or waiting at, -1 none; and the option it is for.
var going := -1
var waiting := -1
var opt := -1
## Where to put the ship back when the map reopens after the pass (node index, spot).
static var _hold_after := {}


class _Solved extends RefCounted:
	var res: Array = [null, null, null]


## The comet here, or null.
func comet() -> CometPath:
	return screen.view.layout.comet if screen.view.layout != null else null


func t_now() -> float:
	return float(screen.view.t)


## Spot k's keep target for the planner: a still point, from the origin, as `ShipFlight.center(-9)`.
static func target(L: SystemLayout, c: CometPath, k: int) -> Dictionary[String, Variant]:
	return {"kind": &"keep", "place": -9, "c": Vector2.ZERO, "off": c.spot_at(L, k)}


## Seconds until the comet reaches spot k (below 0: gone by).
func it_in(k: int) -> float:
	var c := comet()
	return c.spot_in(k, t_now()) if c != null else -INF


## Whether spot k can still be made: the comet not yet there, and the last plan in time.
func can_make(k: int) -> bool:
	var it := it_in(k)
	if it <= 0.0:
		return false
	return you[k] == INF or you[k] + MARGIN < it


## TOO LATE: the comet is past the spot, or the ship cannot get there first.
func too_late(k: int) -> bool:
	return it_in(k) <= 0.0 or (you[k] != INF and you[k] + MARGIN >= it_in(k))


# ---------------------------------------------------------------- every frame
func step() -> void:
	var c := comet()
	if c == null or screen.flight == null:
		return
	var n: MapGen.MapNode = screen.view.node
	_put_back(n, c)
	_take_plans()
	# (broken off for somewhere else: no longer going to the spot)
	if going >= 0 and screen.flight.mode != &"fly" and not (screen.flight.mode == &"keep" and int(screen.flight.keep.body) == -9):
		going = -1
	if going < 0 and waiting < 0 and not c.gone(t_now()) and _open_reading(n) >= 0:
		if Time.get_ticks_msec() / 1000.0 - _plan_at >= REPLAN_S:
			_plan_all(c)
	if waiting >= 0:
		_wait(n, c)


## The comet's open reading here, or -1: what the spots are offered for.
func _open_reading(n: MapGen.MapNode) -> int:
	var c := comet()
	if c == null:
		return -1
	for bc in c.beacons:
		if EncounterDrawer.option_state(n, bc.opt).kind == &"open":
			return bc.opt
	return -1


## Waiting at the spot: when the comet is there, down to LOCAL for its reading.
func _wait(n: MapGen.MapNode, c: CometPath) -> void:
	var f = screen.flight
	var spot: Vector2 = c.spot_at(screen.view.layout, waiting)
	if f.mode != &"keep" or int(f.keep.body) != -9 or (f.f.p as Vector2).distance_to(spot) > HOLD_PX:
		waiting = -1
		return
	if c.spot_in(waiting, t_now()) > PASS_LEAD:
		return
	CometPath.set_caught(n, waiting)
	_hold_after[n.index] = waiting
	var o := opt
	waiting = -1
	if o >= 0 and not screen._taking:
		screen._zoom_down(o)


## Back from LOCAL the map puts a ship it cannot place at the edge; it was on its spot.
func _put_back(n: MapGen.MapNode, c: CometPath) -> void:
	if not _hold_after.has(n.index):
		return
	var k := int(_hold_after[n.index])
	_hold_after.erase(n.index)
	var f = screen.flight
	var spot := c.spot_at(screen.view.layout, k)
	f.mode = &"keep"
	f.rail = {}
	f.keep = {"body": -9, "off": spot, "ev": Vector2.ZERO, "ev0": 0.0, "inf": spot}
	f.f.p = spot
	f.f.v = Vector2.ZERO


# ---------------------------------------------------------------- the race
## Every spot planned on a worker from where the ship is now (`FlightSolve`, pure data).
func _plan_all(c: CometPath) -> void:
	if _job >= 0:
		return
	var f = screen.flight
	_plan_at = Time.get_ticks_msec() / 1000.0
	if not f.can_fly():
		you = [INF, INF, INF]
		return
	var t := t_now() + float(f.PLAN_AHEAD)
	var dep: Dictionary = f._dep_of(t_now(), float(f.PLAN_AHEAD))
	if dep.is_empty():
		return
	var o: Dictionary = f.flight_opts()
	var grav: MapGravity = f._grav_at(float(o.pace))
	var L: SystemLayout = screen.view.layout
	var tgts: Array = []
	for k in 3:
		tgts.append(target(L, c, k) if c.spot_in(k, t) > 0.0 else {})
	var box := _Solved.new()
	_box = box
	_dep = dep
	_plan_t = t
	_job = WorkerThreadPool.add_task(func() -> void:
		for k in 3:
			if not (tgts[k] as Dictionary).is_empty():
				box.res[k] = FlightSolve.solve(grav, dep, tgts[k], t, {}, o))


## A plan still running when the map goes is waited out, so no task outlives the screen it reads.
func _exit_tree() -> void:
	if _job >= 0:
		WorkerThreadPool.wait_for_task_completion(_job)
		_job = -1


func _take_plans() -> void:
	if _job < 0 or not WorkerThreadPool.is_task_completed(_job):
		return
	WorkerThreadPool.wait_for_task_completion(_job)
	_job = -1
	for k in 3:
		var r: FlightSolve.Result = _box.res[k]
		_res[k] = r
		# (from now: the plan's moment is PLAN_AHEAD on, and it is settled at its end)
		you[k] = (float(r.end.t) - t_now()) if r != null and r.found else INF


## GO to spot k for reading `i`: the last plan if it can still be flown, else one planned now.
func go_spot(k: int, i: int) -> bool:
	var c := comet()
	var f = screen.flight
	if c == null or f == null or screen._taking or not f.can_fly() or not Router.may_cast_off():
		Audio.denied()
		return false
	var t := t_now()
	var pv = null
	var r: FlightSolve.Result = _res[k]
	if r != null and r.found and not _dep.is_empty():
		pv = f._plan_of(r, -9, _dep, _plan_t)
		if f._takeable(pv, t).is_empty():
			pv = null
	if pv == null:
		var dep: Dictionary = f._dep_of(t, 0.0)
		if dep.is_empty():
			Audio.denied()
			return false
		var o: Dictionary = f.flight_opts()
		var r2 := FlightSolve.solve(f._grav_at(float(o.pace)), dep, target(screen.view.layout, c, k), t, {}, o)
		if not r2.found:
			Audio.denied()
			return false
		pv = f._plan_of(r2, -9, dep, t)
	# (too late is refused here too: never a flight that arrives after the comet)
	if float(pv.end.t) + MARGIN >= c.spot_t(k):
		you[k] = float(pv.end.t) - t
		Audio.denied()
		return false
	if not Router.cast_off():
		return false
	going = k
	opt = i
	if f.fly(-9, t, func() -> void: _arrived(k), {}, pv) == null:
		going = -1
		Audio.denied()
		return false
	return true


func _arrived(k: int) -> void:
	going = -1
	waiting = k
