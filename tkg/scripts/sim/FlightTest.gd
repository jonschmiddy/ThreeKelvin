extends Node

## Flies every auto-flight on the sector map and judges it (ruling 20, Oct 30).
## Sweeps, phases and PASS rules are in the doc; shards split them (`Harness.mine`).
## Why: docs/why/FlightTest.md#test-overview

## THE TWO PATHS (fast transfers, Nov 5): both unless `autopilot=direct|curved` names one, each at its
## own pace. Each sweep is judged per path; click-to-settled times against CLICK_MED, CLICK_P90, CLICK_EDGE.
## Why: docs/why/FlightTest.md#two-paths
const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
## Click to settled at the path's own pace, s, each path its own: median, 90th, and a jump's first.
## Jon's ruling (Nov 7, "5A"): each path's limits just over what it flies.
## Why: docs/why/FlightTest.md#click-limits
const CLICK_MED := {&"direct": 4.5, &"curved": 6.5}
const CLICK_P90 := {&"direct": 6.0, &"curved": 8.5}
const CLICK_EDGE := {&"direct": 5.8, &"curved": 8.5}
var _paths: Array[StringName] = [&"direct", &"curved"]
## this pass's sweep suffix ("" DIRECT, " curved" CURVED) and whether it is the
## pass that picks the worker plans, the clicks and the hand phase's systems
var _tag := ""
var _picks_on := true
## `flight=<path>`: another ShipFlight to measure (an older one, to compare).
var _flight_script: Script = ShipFlightS

const SEEDS := [4242, 7, 1999, 31337, 99, 123, 5150, 8080]
const NONE := {"w": false, "a": false, "s": false, "d": false}
## found and clean in at least this share of each sweep (DESIGN)
const FOUND_MIN := 0.99
## how far inside a keep-out a clean flight's samples may pass, as MapGravity
## has it at each sample's own time (`SolveTest.IN_PX`)
const IN_PX := 1.0
## a flown frame this far from the drawn point for its moment is another flight
const DRAWN_PX := 0.5
## A CORNER, as `_turn_max` reads one over 2 px: more than this, deg per px
const CORNER := 20.0
## A snap: a velocity change SNAP_RATIO times its neighbours' and over SNAP_DV px/s.
const SNAP_RATIO := 4.0
const SNAP_DV := 6.0
## 16 s was for time-scaled conics; map-time flights take up to 16, 30 or 40 s (ruling 21).
## Why: docs/why/FlightTest.md#flight-time-cap
const FLY_MAX := 45.0
## A two-leg flight flies both legs by the as-built search, the second up to T_CAP_BACK more.
const FLY_MAX_TWO := FLY_MAX + FlightSolve.T_CAP_BACK
## No dv of nought: a coast with no burn is not a departure (one grazing by 3.7 px read as clear).
## Why: docs/why/FlightTest.md#unleavable-starts
const CLEAR_S := 1.0
const CLEAR_HEAD := 16
const CLEAR_DV := [20.0, 40.0, 70.0, 100.0, 150.0, 220.0]
## Residual plan misses were measured (Oct 31, Nov 2): arrivals miss, departures do not.
## Why: docs/why/FlightTest.md#measured-residual
const PUT_LEFT := 6
## Close-pair residuals measured Nov 1 to 3: all from harness starts, every game start found.
## Why: docs/why/FlightTest.md#measured-residual
const PUT_LEFT_CLOSE := 6
## the harness's starts the residual may come from, "seed:system:start" a sweep
## (any other start put there fails, whatever the count). SCIENCE (Phase 12,
## Nov 4) put a reading in place of one option in about three systems in eight,
## and those systems alone lay out anew (checked system by system against the
## layouts before): two of them, seed 1999 system 258's near start (THE RACE
## COURSE on its belt) and seed 7 system 328's free start (THE TARGET RANGE on
## its dry world), each to one place, now leave a twin's residual, the best burn
## from each keeping clear for 30 s, so again the arrivals miss. At the study's
## 1 in 6 (Nov 4) about half of all systems hold one, and one more does: seed
## 1999 system 74's near start (THE FIRST LOOK on its dry world, a reading it
## does not hold at 1 in 8; its list is main's but for that slot), to one place,
## the best burn keeping clear for 30 s again
const PUT_LEFT_CASES := {
	"twin": ["1999:177:free", "7:209:free", "1999:258:near", "7:328:free", "1999:74:near"],
	"close": ["1999:257:free", "4242:24:near", "4242:297:free"],
}
## the click comes up to this long after the first plan (s)
const CLICK_S := 1.5
## the overlay's preview line, laid out to this many points (`SystemOverlay.PV_N`)
const PV_LINE := 1600
## a solved flight ends this close to where `ShipFlight.center` puts its place (px)
const END_PX := 0.05

var h := Harness.new()
var _n_seeds := 3
var _systems := 12
var _only := ""
var _worker_n := 120
var _out := ""
var _why := ""
var _one_seed := -1
## `retarget`: flights turned to another place at ten points along the way
var _retarget := false
## `starride`: out of star orbits of several sizes, at several points round
## them, to every world: the plan's shape, and how it holds as the ship rides
var _starride := false
## `dump=<json>` with `why=`: that flight's drawn path and its target's place
var _dump := ""
var _worst_px: Array = []
var _corner_only := false
## where the S-bends are: leaving, on the coast, arriving, in the insertion
var _s_where := {}

## per sweep: counts and lists
var _sw := {}
## each layout's MapGravity, built once, that a clean flight is measured against
var _gq := {}
## the common flights, apart (per sweep): tightest bend radius at zoom 1 and 2,
## corners, flight time, S-bends
var _cat := {}
## the cases to plan again on a worker: [sweep, L, start, b, i, t, plan]
var _wk: Array = []
## Click rows per sweep: [sweep, L, start, b, i, t, node index], and how many per frame rate.
var _ck := {"one": [], "giant": [], "twin": [], "close": []}
var _clicks := 16
## per sweep, the flights planned so far in every shard's systems: every 5th of
## the game's starts is kept for the clicks (as `S.plans` counts them unsplit)
var _picks := {}
## A shard that makes worker plans, clicks or the hand
## phase also picks others' systems (`_pick_only`).
var _pick_wk := false
var _pick_ck := false
var _pick_hand := false
## the hand phase's systems (`_hand_phase`): the first wide and close pairs the
## clicks' starts hold
const HAND_WIDE := 10
const HAND_CLOSE := 5
## `hand=0`: no flying by hand (`_hand_phase`)
var _hand := true
## `phase=hand`: only the hand phase (above); `phase=rest` is `hand=0`
var _hand_only := false
## `short`: the gate's run (above); `places=N`: the far places' systems a sweep;
## `clicks`: only the clicks (the starts gathered as a sweep would, unplanned)
var _short := false
var _places := 12
var _rows_only := false
var _errs := ErrCount.new()


## Every engine error while the map's own paths run (a task waited for twice, a
## task let go of and never waited): there must be none.
class ErrCount extends Logger:
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


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("seeds="):
			_n_seeds = int(s.substr(6))
		elif s.begins_with("systems="):
			_systems = int(s.substr(8))
		elif s.begins_with("only="):
			_only = s.substr(5)
		elif s.begins_with("worker="):
			_worker_n = int(s.substr(7))
		elif s.begins_with("clicks="):
			_clicks = int(s.substr(7))
		elif s == "clicks":
			_rows_only = true
			_n_seeds = 1
			_systems = 4
			_clicks = 6
		elif s == "hand=0" or s == "phase=rest":
			_hand = false
		elif s == "phase=hand":
			_hand_only = true
		elif s == "short":
			_short = true
			_n_seeds = 1
			_systems = 4
			_worker_n = 24
			_clicks = 6
			_places = 4
		elif s.begins_with("places="):
			_places = int(s.substr(7))
		elif s.begins_with("out="):
			_out = s.substr(4)
		elif s.begins_with("flight="):
			_flight_script = load(s.substr(7))
		elif s.begins_with("dump="):
			_dump = s.substr(5)
		elif s == "retarget":
			_retarget = true
		elif s == "starride":
			_starride = true
		elif s.begins_with("seed="):
			_one_seed = int(s.substr(5))
		elif s.begins_with("autopilot="):
			var ap := s.substr(10)
			if ap == "direct" or ap == "curved":
				_paths = [StringName(ap)]
		elif s.begins_with("why="):
			# `why=system:start:target`: that one flight, every try's failure said
			_why = s.substr(4)
	_run.call_deferred()


func _wants(sweep: String) -> bool:
	return _only == "" or _only == sweep


func _stat(sweep0: String) -> Dictionary:
	var sweep := sweep0 + _tag
	if not _sw.has(sweep):
		_sw[sweep] = {"click_edge": [], "click_dep": [], "bend": [], "turn": [], "old_n": 0, "pace": float(ShipFlightS.flight_opts().pace),"plans": 0, "solved": 0, "clean": 0, "replay": 0, "warm": 0, "fallback": 0, "none": 0,
			"flown": 0, "landed": 0, "ms": [], "T": [], "work": [], "lead": [], "clicks": 0, "drawn": 0,
			"drawn_px": [], "corners1": 0, "corners2": 0, "turn1": [], "turn2": [], "snaps": 0, "frame_dv": 0.0,
			"frame_ratio": 0.0, "star": INF, "keep": INF, "world": INF, "speed": 0.0, "not_found": [], "not_landed": [],
			"cornered": [], "snapped": [], "off_drawn": [], "nose": 0.0, "by_start": {}, "systems": 0, "redrawn": 0, "ring_corners": 0, "game_corners1": 0, "game_corners2": 0, "unflyable": 0, "end_off": 0.0, "belt_ends": 0,
			"chained": 0, "chain_T": [], "chain_ms": [], "chain_cut": [], "chain_list": [], "chain_far": 0.0, "far": 0.0, "put": [],
			"click_game": [], "click_place": [], "click_two": [], "in_clean": 0, "in_worst": INF}
	return _sw[sweep]


func _run() -> void:
	if _retarget:
		_run_retarget()
		return
	if _starride:
		_run_starride()
		return
	var t_all := Time.get_ticks_msec()
	var seeds: Array = SEEDS.slice(0, mini(_n_seeds, SEEDS.size()))
	if _one_seed >= 0:
		seeds = [_one_seed]
	ShipFlightS.n_solved = 0
	ShipFlightS.n_fallback = 0
	ShipFlightS.n_none = 0
	var cap := {"one": [0, 0, 0], "twin": [0, 0, 0]}
	# (every system in turn, for the shards: `Harness.mine`)
	var n_sys := 0
	var n_mine := 0
	_pick_wk = h.shard().y > 1 and not _rows_only and h.mine(1)
	_pick_ck = h.shard().y > 1 and _clicks > 0 and h.mine(2)
	_pick_hand = h.shard().y > 1 and _hand and not _rows_only and h.mine(3) and not _pick_ck
	if _hand_only:
		# (no system its own: every one only picked from, for the hand phase)
		_pick_wk = false
		_pick_ck = false
		_pick_hand = _hand and not _rows_only
	ShipFlightS.flight_opts()
	for pi in _paths.size():
		_set_path(pi)
		_sweeps(seeds, cap)
		n_sys += _n_sys
		n_mine += _n_mine
	print("flighttest: the sweeps took %.0f s" % ((Time.get_ticks_msec() - t_all) / 1000.0))
	if _why == "" and not _rows_only and not _hand_only and h.mine(0):
		for pi2 in _paths.size():
			_set_path(pi2)
			_places_phase(seeds)
	var t_ph := Time.get_ticks_msec()
	if not _rows_only and not _hand_only and h.mine(1):
		await _worker_phase()
		print("flighttest: the worker plans took %.0f s" % ((Time.get_ticks_msec() - t_ph) / 1000.0))
	OS.add_logger(_errs)
	t_ph = Time.get_ticks_msec()
	if _clicks > 0 and not _hand_only and h.mine(2):
		await _click_phase()
		print("flighttest: the clicks took %.0f s" % ((Time.get_ticks_msec() - t_ph) / 1000.0))
	t_ph = Time.get_ticks_msec()
	if _hand and not _rows_only and (_hand_only or h.mine(3)):
		_hand_phase()
		print("flighttest: flying by hand took %.0f s" % ((Time.get_ticks_msec() - t_ph) / 1000.0))
	OS.remove_logger(_errs)
	if not _rows_only and not _hand_only:
		_report(cap)
	print("flighttest: all of it took %.0f s%s" % [(Time.get_ticks_msec() - t_all) / 1000.0, " (short)" if _short else ""])
	if not _hand_only:
		h.shard_end("flighttest", n_mine, n_sys)
	h.verdict("flighttest")
	get_tree().quit(h.code())


## Path pi of `_paths` for what flies next: the ship's planner's path
## (`ShipFlight.path_k`), the sweeps' suffix, and whether this pass picks.
func _set_path(pi: int) -> void:
	var p: StringName = _paths[pi]
	ShipFlightS.path_k = p
	_tag = "" if p == &"direct" else " curved"
	_picks_on = pi == _paths.size() - 1
	ShipFlightS.n_fallback = 0
	print("flighttest: the %s path at pace %.1f" % [p, float(ShipFlightS.flight_opts().pace)])


var _n_sys := 0
var _n_mine := 0
## ONE PATH'S SWEEPS (`_run`): every seed's systems sorted and flown. The
## captures are counted on the picking pass only (they are by hand, the same
## either way).
func _sweeps(seeds: Array, cap: Dictionary) -> void:
	var n_sys := 0
	var n_mine := 0
	var t_all := Time.get_ticks_msec()
	for sd: int in seeds:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		# every system of the map sorted into its sweep, then `_systems` of each
		# taken evenly through it: [node, its layout, two suns]
		var pool := {"one": [], "giant": [], "twin": [], "close": []}
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type != MapGen.NodeType.SYSTEM and n.type != MapGen.NodeType.PULSAR and n.type != MapGen.NodeType.STATION:
				continue
			OptionTable.ensure(n)
			var was := n.twin
			# ONE STAR: every node as it would be with one (the systems this
			# measure has always flown)
			n.twin = false
			var L := SystemLayout.of(n)
			var sweep := "giant" if L.bodies.any(func(b: SystemLayout.Body) -> bool: return b.gm > 0.0) else "one"
			if _wants(sweep):
				(pool[sweep] as Array).append([n, L, false])
			# TWO SUNS where the layout may give them (`-- twin=all`'s way), each
			# kind laid out on purpose (the kind is rolled, `SystemLayout.is_close`)
			for kind: Array in [["twin", -1], ["close", 1]]:
				if MapGen.twin_ok(n) and _wants(String(kind[0])):
					n.twin = true
					SystemLayout.close_force = int(kind[1])
					var L2 := SystemLayout.of(n)
					SystemLayout.close_force = 0
					if L2.twin:
						(pool[kind[0]] as Array).append([n, L2, true])
			n.twin = was
		var counts := {}
		for sweep2: String in ["one", "giant", "twin", "close"]:
			var all_of: Array = pool[sweep2]
			# (`why=` names its systems by index: every one, the rest skipped)
			var picks := _spread(all_of.size(), _systems if _why == "" else all_of.size())
			counts[sweep2] = "%d of %d" % [picks.size(), all_of.size()]
			for k: int in picks:
				var n2: MapGen.MapNode = all_of[k][0]
				var L3: SystemLayout = all_of[k][1]
				if _why != "" and not _why_names(n2.index):
					continue
				n_sys += 1
				var mine := h.mine(n_sys - 1) and not _hand_only
				# A sweep is reported in every shard so its totals
				# come from all, as an unsplit run reports it.
				_stat(sweep2)
				if not mine and not _picking(sweep2):
					continue
				if mine:
					n_mine += 1
				var was2 := n2.twin
				n2.twin = bool(all_of[k][2])
				_system(sweep2, sd, n2, L3, mine)
				if not _rows_only and mine:
					var cc := _captures(L3, n2.index)
					var into: Array = cap.twin if L3.twin else cap.one
					if _picks_on:
						for q in 3:
							into[q] += cc[q]
				n2.twin = was2
		print("flighttest: seed %d: %s systems%s" % [sd, counts, _tag])
	print("flighttest: the%s sweeps took %.0f s" % [_tag, (Time.get_ticks_msec() - t_all) / 1000.0])
	_n_sys = n_sys
	_n_mine = n_mine


## Swept apart: twin Hellbender flights found nothing 17% of the time, core ones dove into the lens.
## Why: docs/why/FlightTest.md#far-places
func _places_phase(seeds: Array) -> void:
	var t_ph := Time.get_ticks_msec()
	var st := {}
	for k: String in ["far one", "far twin", "far close", "core", "start"]:
		st[k + _tag] = {"plans": 0, "solved": 0, "old": 0, "none": 0, "T": [], "miss": [], "close": INF, "inside": 0}
	var keep_core := INF
	for sd: int in seeds:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var one: Array = []
		var two: Array = []
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type == MapGen.NodeType.CORE or n.type == MapGen.NodeType.START:
				OptionTable.ensure(n)
				var Lc := SystemLayout.of(n)
				var key := "core" if n.type == MapGen.NodeType.CORE else "start"
				if key == "core":
					keep_core = MapGravity.keep_out_star(Lc, -1)
				var places: Array = []
				for s0 in Lc.stars():
					places.append(s0)
				for b in Lc.bodies:
					places.append(b.index)
				for i: int in places:
					_far_case(st[key + _tag], key, sd, n, Lc, i, keep_core if key == "core" else -1.0)
			elif n.type == MapGen.NodeType.SYSTEM:
				if MapGen.twin_ok(n):
					two.append(n)
				one.append(n)
		for pair: Array in [["far one", one, false, 0], ["far twin", two, true, -1], ["far close", two, true, 1]]:
			var pool: Array = pair[1]
			for k2: int in _spread(pool.size(), _places):
				var n2: MapGen.MapNode = pool[k2]
				OptionTable.ensure(n2)
				var was := n2.twin
				n2.twin = bool(pair[2])
				Run.hellbender_at = n2.index
				Run.hellbender_hp = 1
				SystemLayout.close_force = int(pair[3])
				var L2 := SystemLayout.of(n2)
				SystemLayout.close_force = 0
				var hp := L2.hellbender_place()
				if hp >= 0 and L2.twin == bool(pair[2]):
					_far_case(st[String(pair[0]) + _tag], String(pair[0]), sd, n2, L2, hp, -1.0)
				Run.hellbender_at = -1
				Run.hellbender_hp = 0
				n2.twin = was
	for k30: String in ["far one", "far twin", "far close", "core", "start"]:
		var k3 := k30 + _tag
		var S: Dictionary = st[k3]
		print("flighttest: %s: %d flights from the game's starts: solved %d, today's planner %d, none (put there) %d; flight time %s s%s" % [k3, S.plans, S.solved, S.old, S.none, _dist(S.T),
			"; closest to the black hole %.1f px, its keep-out %.1f" % [S.close, keep_core] if k30 == "core" else ""])
		for l in (S.miss as Array).slice(0, 12):
			print("    %s" % l)
		# (in a twin no fallback: found by the solver; with one sun today's planner may)
		h._ok("%s: every flight from the game's starts found, none put there (%d of %d)" % [k3, int(S.plans) - int(S.none), S.plans], int(S.plans) > 0 and int(S.none) == 0)
		if k30 == "core":
			h._ok("core%s: no flight inside the black hole's keep-out, %.1f px, its lens (%d; closest %.1f)" % [_tag, keep_core, S.inside, S.close], int(S.inside) == 0)
	print("flighttest: the far places and the core took %.0f s" % ((Time.get_ticks_msec() - t_ph) / 1000.0))


## Every game start in system n to place i, planned as the preview is (`S` the
## tally; `keep` > 0: no flight's samples closer than that to star A).
func _far_case(S: Dictionary, key: String, sd: int, n: MapGen.MapNode, L: SystemLayout, i: int, keep: float) -> void:
	var t := 40.0 + float(n.index % 17) * 13.0
	var starts: Array = []
	for b in L.bodies:
		if b.index != i and (b.world != &"" or b.kind == &"station" or b.kind == &"belt" or b.kind == &"derelict" or b.kind == &"contact"):
			starts.append(["orbit" if b.world != &"" else "keep", b.index])
	for s in L.stars():
		if s != i:
			starts.append(["close", s])
	starts.append(["edge", 0])
	starts.append(["star", 0])
	starts.append(["star", 1])
	for s0: Array in starts:
		var fl = _flight_script.new()
		fl.setup(L, Vector2(L.edge, -210.0), t)
		_start(fl, L, String(s0[0]), int(s0[1]), t, sd * 7 + int(s0[1]) * 13 + i)
		fl.step(1.0 / 60.0, t, NONE)
		if not fl.can_fly():
			continue
		S.plans = int(S.plans) + 1
		var pl = fl.make_plan(i, t, {}, ShipFlightS.PREVIEW_AHEAD)
		var what := "seed %d system %d (%s) %s %d -> %d" % [sd, n.index, key, s0[0], s0[1], i]
		if pl == null:
			S.none = int(S.none) + 1
			(S.miss as Array).append("PUT THERE: " + what)
			continue
		if pl.res != null:
			S.solved = int(S.solved) + 1
		else:
			S.old = int(S.old) + 1
		(S.T as Array).append(float(pl.dur))
		if keep > 0.0:
			var m := INF
			for q: Vector3 in pl.samp:
				m = minf(m, Vector2(q.x, q.z).length())
			for q2: Vector3 in pl.tail:
				m = minf(m, Vector2(q2.x, q2.z).length())
			S.close = minf(float(S.close), m)
			if m < keep - 0.5:
				S.inside = int(S.inside) + 1
				(S.miss as Array).append("INSIDE THE KEEP-OUT, %.1f px (%s): %s" % [m, "solved" if pl.res != null else "today's planner", what])


## Whether `why=` names a flight in system `index`.
func _why_names(index: int) -> bool:
	for wc in _why.split(","):
		var wq := (wc as String).split(":")
		if wq.size() == 3 and int(wq[0]) == index:
			return true
	return false


## `want` of `size` indices, spread evenly through it (all of them when it
## holds no more).
static func _spread(size: int, want: int) -> Array[int]:
	var out: Array[int] = []
	if size <= want:
		for k in size:
			out.append(k)
		return out
	for k in want:
		out.append(int(floorf((float(k) + 0.5) * float(size) / float(want))))
	return out


## EVERY FLIGHT IN ONE SYSTEM, from every start to every place (split, another
## shard's system: only the picks, `_pick_only`).
func _system(sweep: String, sd: int, n: MapGen.MapNode, L: SystemLayout, mine := true) -> void:
	var S := _stat(sweep)
	if mine:
		S.systems = int(S.systems) + 1
	var targets: Array = []
	for s in L.stars():
		targets.append(s)
	for b in L.bodies:
		targets.append(b.index)
	var starts: Array = []
	for b in L.bodies:
		if b.world != &"":
			starts.append(["orbit", b.index])
	for s in L.stars():
		starts.append(["close", s])
	starts.append(["star", 0])
	starts.append(["free", 0])
	starts.append(["edge", 0])
	# CLOSE BY ALREADY: within a little over two rings of the place, moving any
	# way (Jon: a lap round the star with the world right beside him)
	starts.append(["near", 0])
	for b in L.bodies:
		if b.kind == &"station" or b.kind == &"belt" or b.kind == &"derelict" or b.kind == &"contact":
			starts.append(["keep", b.index])
			break
	var t := 40.0 + float(n.index % 17) * 13.0
	for s0: Array in starts:
		var key := String(s0[0])
		for i: int in targets:
			if (key == "orbit" or key == "close" or key == "keep") and int(s0[1]) == i:
				continue
			if key == "near" and (i < 0 or L.bodies[i].world == &""):
				continue
			if _why != "":
				# `why=sys:start:target[,sys:start:target...]`
				var hit := false
				for wc in _why.split(","):
					var wq := (wc as String).split(":")
					if wq.size() == 3 and int(wq[0]) == n.index and wq[1] == key and int(wq[2]) == i:
						hit = true
				if not hit:
					continue
				print("  WHY %d:%s:%d (%s)" % [n.index, key, i, sweep])
			if mine:
				_case(sweep, sd, n, L, key, int(s0[1]) if key != "near" else i, i, t)
			else:
				_pick_only(sweep, n, L, key, int(s0[1]) if key != "near" else i, i, t)


## Whether this shard still picks from another shard's system of `sweep`.
func _picking(sweep: String) -> bool:
	if not _picks_on:
		return false
	return (_pick_wk and int(_wk.size()) < _worker_n * 3) or _picking_ck(sweep)


## Whether this shard still picks the clicks' starts of `sweep`.
func _picking_ck(sweep: String) -> bool:
	if _pick_ck:
		return true
	if not _pick_hand or (sweep != "twin" and sweep != "close"):
		return false
	var seen := {}
	for row: Array in _ck[sweep]:
		seen[int(row[6])] = true
	return seen.size() < (HAND_WIDE if sweep == "twin" else HAND_CLOSE)


## Another shard's flight is set up and planned only, so the flights match however the run is split.
func _pick_only(sweep: String, n: MapGen.MapNode, L: SystemLayout, key: String, b: int, i: int, t: float) -> void:
	var fl = _flight_script.new()
	fl.setup(L, Vector2(-L.edge * 0.95, 0.0), t)
	_start(fl, L, key, b, t, n.index)
	fl.step(1.0 / 60.0, t, NONE)
	if fl.orbit_body() == i or (key != "free" and key != "near" and not fl.can_fly()):
		return
	# (nor a harness's start the first frame took onto a ring or alongside, as
	# `_case` leaves those out)
	if (key == "free" or key == "near") and fl.mode != &"free":
		return
	_picks[sweep] = int(_picks.get(sweep, 0)) + 1
	var for_wk := _pick_wk and int(_wk.size()) < _worker_n * 3 and (_wk.size() % 3 == 0 or sweep == "twin" or sweep == "close")
	var for_ck := _picking_ck(sweep) and key != "free" and key != "near" and int(_picks[sweep]) % 5 == 2
	if not for_wk and not for_ck:
		return
	var pl = fl.make_plan(i, t, {}, ShipFlightS.PREVIEW_AHEAD)
	if pl == null or pl.res == null:
		return
	if for_wk:
		_wk.append([sweep, L, key, b, i, t, pl, n.index])
	if for_ck:
		(_ck[sweep] as Array).append([sweep, L, key, b, i, t, n.index])


## ONE FLIGHT: planned as the map's worker plans it, clicked a moment later,
## flown, measured.
func _case(sweep: String, sd: int, n: MapGen.MapNode, L: SystemLayout, key: String, b: int, i: int, t: float) -> void:
	var S := _stat(sweep)
	var fl = _flight_script.new()
	fl.setup(L, Vector2(-L.edge * 0.95, 0.0), t)
	_start(fl, L, key, b, t, n.index)
	# one frame, so the ship is where its orbit puts it
	fl.step(1.0 / 60.0, t, NONE)
	# (taken by the place's ring already: nothing to fly)
	if fl.orbit_body() == i:
		return
	# A start the first frame took elsewhere is not one a flight can leave: counted, not planned.
	if key != "free" and key != "near" and not fl.can_fly():
		S.unflyable = int(S.unflyable) + 1
		return
	# A harness start taken onto another ring is counted,
	# not planned: the map would refuse the click.
	# Why: docs/why/FlightTest.md#taken-starts
	if (key == "free" or key == "near") and fl.mode != &"free":
		S.unflyable = int(S.unflyable) + 1
		return
	# (`clicks`: the start kept for the clicks as below, nothing planned)
	if _rows_only:
		S.plans = int(S.plans) + 1
		if _picks_on and key != "free" and key != "near" and int(S.plans) % 5 == 2:
			(_ck[sweep] as Array).append([sweep, L, key, b, i, t, n.index])
		return
	var where := "seed %d system %d (%s, %s) from %s %d to %d" % [sd, n.index, MapGen.star_name(n), sweep, key, b, i]
	var bs: Dictionary = S.by_start
	if not bs.has(key):
		bs[key] = {"plans": 0, "found": 0, "clean": 0}
	bs[key].plans = int(bs[key].plans) + 1
	var t_us := Time.get_ticks_usec()
	var pl = fl.make_plan(i, t, {}, ShipFlightS.PREVIEW_AHEAD)
	var ms := float(Time.get_ticks_usec() - t_us) / 1000.0
	S.plans = int(S.plans) + 1
	if _picks_on:
		_picks[sweep] = int(_picks.get(sweep, 0)) + 1
	(S.ms as Array).append(ms)
	if pl == null:
		S.none = int(S.none) + 1
		(S.not_found as Array).append(where + " (none)")
		(S.put as Array).append([where, _clear_for(fl, i, t), key, "%d:%d:%s" % [sd, n.index, key]])
		return
	if pl.res == null:
		S.fallback = int(S.fallback) + 1
		S.old_n = int(S.old_n) + 1
		(S.not_found as Array).append(where + " (today's planner)")
	else:
		S.solved = int(S.solved) + 1
		bs[key].found = int(bs[key].found) + 1
		if pl.res.clean:
			S.clean = int(S.clean) + 1
			bs[key].clean = int(bs[key].clean) + 1
			# Judge clean as `MapGravity` has it at each sample's
			# time: the solver's word passed flights 9 px inside.
			# Why: docs/why/FlightTest.md#clean-measure
			var Gq: MapGravity = _gq.get(L.get_instance_id(), null)
			if Gq == null:
				Gq = MapGravity.from_layout(L)
				_gq[L.get_instance_id()] = Gq
			# (the departure's and the target's own keep-outs are the solver's to
			# keep to their rings, `FlightSolve._setup`: left out, every sun's in)
			var own := [int((pl.dep as Dictionary).get("place", -9)), i]
			var mq := INF
			for kq in pl.samp.size():
				mq = minf(mq, Gq.margin_but(pl.samp[kq].x, pl.samp[kq].z, pl.t0 + kq * pl.sdt, own))
			S.in_worst = minf(float(S.in_worst), mq)
			if mq < -IN_PX:
				S.in_clean = int(S.in_clean) + 1
				(S.not_found as Array).append(where + " (clean, but %.2f px inside a keep-out at its samples' times)" % -mq)
		else:
			(S.not_found as Array).append(where + " (unclean, %.2f px in)" % -pl.res.clear)
		(S.T as Array).append(pl.res.T)
		(S.work as Array).append(pl.res.work)
		if pl.res.clean:
			var shp := FlightSolve.shape_of(pl.samp)
			(S.bend as Array).append(shp[0])
			(S.turn as Array).append(shp[1])
		(S.lead as Array).append(pl.res.lead)
		S.keep = minf(float(S.keep), pl.res.clear)
		# HOW FAR OUT FROM STAR A, against the map's edge (the edge is measured
		# from it): every solved flight, and a flight in two legs apart
		var far := 0.0
		for q: Vector3 in pl.samp:
			far = maxf(far, Vector2(q.x, q.z).length() / L.edge)
		S.far = maxf(float(S.far), far)
		if pl.res.legs == 2:
			S.chained = int(S.chained) + 1
			(S.chain_T as Array).append(pl.res.T)
			(S.chain_ms as Array).append(ms)
			(S.chain_cut as Array).append(pl.res.t_cut - pl.res.t0)
			S.chain_far = maxf(float(S.chain_far), far)
			(S.chain_list as Array).append("%s: %.1f s (the second leg off the first's coast %.1f s on, aimed through %s), work %.0f px/s, planned in %.0f ms, out to %.2f of the edge" % [where, pl.res.T, pl.res.t_cut - pl.res.t0, pl.res.wp.round(), pl.res.work, ms, far])
		if _picks_on and int(_wk.size()) < _worker_n * 3 and (_wk.size() % 3 == 0 or sweep == "twin" or sweep == "close"):
			_wk.append([sweep, L, key, b, i, t, pl, n.index])
		# (the game's starts, every few, for the clicks through the map's path)
		if _picks_on and key != "free" and key != "near" and int(_picks[sweep]) % 5 == 2:
			(_ck[sweep] as Array).append([sweep, L, key, b, i, t, n.index])
	# Compared with the ship's own `center`; a belt's beacon
	# rides its host, which `center` once took for origin.
	# Why: docs/why/FlightTest.md#flight-end-place
	if pl.res != null:
		var ce: Vector3 = fl.center(i, float(pl.end.t))
		var arl: Vector2 = pl.end.arel
		var ep: Vector3 = pl.end.p
		var de := Vector2(ce.x + arl.x - ep.x, ce.z + arl.y - ep.z).length()
		S.end_off = maxf(float(S.end_off), de)
		if i >= 0 and L.bodies[i].kind == &"belt":
			S.belt_ends = int(S.belt_ends) + 1
	var m := _measure(fl, L, pl, i, t, b if key == "orbit" or key == "close" else -9)
	S.star = minf(float(S.star), float(m.star))
	S.world = minf(float(S.world), float(m.world))
	S.speed = maxf(float(S.speed), float(m.speed))
	# THE DRAWN PATH: the plan and its insertion, as the map lays it out
	var path3 := PackedVector3Array(pl.samp)
	path3.append_array(pl.tail)
	var from_r: int = b if key == "orbit" or key == "close" else -99
	for zz: float in [1.0, 2.0]:
		var skip := _ring_skip(fl, L, pl, path3, i, from_r, zz)
		_corner_only = false
		var tv := _turn_max(path3, zz, skip)
		_corner_only = true
		var cv := _turn_max(path3, zz, skip)
		var cr := _turn_max(path3, zz) if skip.count(1) > 0 else cv
		_corner_only = false
		(S["turn%d" % int(zz)] as Array).append(tv)
		if cr > CORNER and cv <= CORNER and pl.res != null:
			S.ring_corners = int(S.ring_corners) + 1
		if cv > CORNER and pl.res != null:
			S["corners%d" % int(zz)] = int(S["corners%d" % int(zz)]) + 1
			var game: bool = key != "free" and key != "near"
			if game:
				S["game_corners%d" % int(zz)] = int(S["game_corners%d" % int(zz)]) + 1
			# (the game's own starts first: a harness's free starts fill a list)
			if (S.cornered as Array).size() < 20 or game:
				(S.cornered as Array).insert(0 if game else (S.cornered as Array).size(), "%s%s: %.0f deg/px at zoom %d" % ["A GAME'S START, " if game else "", where, cv, int(zz)])
			if _why != "":
				_corner_why(pl, path3, zz)
	_category(sweep, key, fl, L, pl, path3, i, b)
	if _why != "":
		print("    kind %s, lead %.2f k %.2f, dur %.2f, choice %s" % [pl.kind, pl.lead, pl.lead_k, pl.dur, pl.choice])
		if _dump != "":
			var dj := {"samp": [], "tail": [], "burns": []}
			for kd in pl.samp.size():
				dj.samp.append([pl.samp[kd].x, pl.samp[kd].z])
				dj.burns.append(pl.burns[kd])
			for qt: Vector3 in pl.tail:
				dj.tail.append([qt.x, qt.z])
			var fd := FileAccess.open(_dump, FileAccess.WRITE)
			fd.store_string(JSON.stringify(dj))
			fd.close()
	# Replans as the overlay does, each from the last
	# choice, so the click flies the flight drawn then.
	# Why: docs/why/FlightTest.md#the-click
	var R := RandomNumberGenerator.new()
	R.seed = n.index * 7919 + i * 31 + key.hash()
	var tc := t
	var ring_dep: bool = pl.res != null and StringName(pl.dep.get("kind", &"")) == &"ring" and int(pl.dep.place) != -9
	if pl.res != null and StringName(pl.dep.get("kind", &"")) != &"free":
		tc = t + R.randf() * CLICK_S
	var every := 3.0 if ring_dep else 1.0
	var dt := 1.0 / 60.0
	var tt := t
	var pv = pl
	var t_pv := t
	while tt + dt <= tc:
		tt += dt
		fl.step(dt, tt, NONE)
		if pv != null and pv.res != null and (tt - t_pv > every or tt >= float(pv.t0) - ShipFlightS.PLAN_AHEAD or fl._takeable(pv, tt).is_empty()):
			var np = fl.make_plan(i, tt, pv.choice, ShipFlightS.PREVIEW_AHEAD)
			S.redrawn = int(S.redrawn) + 1
			if np != null:
				pv = np
				t_pv = tt
			elif fl._takeable(pv, tt).is_empty():
				# (none found from here now: the map draws none, and the click
				# plans its own)
				pv = null
	tc = tt
	var fm := _fly(fl, i, tc, pv if pv != null else pl, pv == null)
	S.flown = int(S.flown) + 1
	if fm.landed:
		S.landed = int(S.landed) + 1
		# Flight length (ruling 21's measure): click to settled, in seconds of map time.
		if key != "free" and key != "near":
			(S.click_game as Array).append(float(fm.land_s))
			if float(fm.dep_s) >= 0.0:
				(S.click_dep as Array).append(float(fm.dep_s))
		if key == "edge":
			(S.click_edge as Array).append(float(fm.land_s))
		if key == "orbit" or key == "close" or key == "keep":
			(S.click_place as Array).append(float(fm.land_s))
		if pl.res != null and pl.res.legs == 2:
			(S.click_two as Array).append(float(fm.land_s))
	else:
		(S.not_landed as Array).append(where + " (mode %s, %.1f s)" % [fm.mode_end, fm.secs])
	if pl.res != null and not fm.undrawn:
		S.clicks = int(S.clicks) + 1
		if fm.redrawn:
			S.click_redrawn = int(S.get("click_redrawn", 0)) + 1
		if fm.same:
			S.drawn = int(S.drawn) + 1
			# (judged at pace 4's scale, `_drawn_px`)
			(S.drawn_px as Array).append(float(fm.off) * DRAWN_PX / _drawn_px(fm))
			if float(fm.off) > _drawn_px(fm) and (S.off_drawn as Array).size() < 20:
				(S.off_drawn as Array).append("%s: %.2f px off the drawn line (click %.2f s on)" % [where, fm.off, tc - t])
		elif (S.off_drawn as Array).size() < 20:
			(S.off_drawn as Array).append("%s: planned again at the click (%.2f s on)" % [where, tc - t])
	S.frame_dv = maxf(float(S.frame_dv), float(fm.frame_dv))
	S.frame_ratio = maxf(float(S.frame_ratio), float(fm.frame_ratio))
	S.nose = maxf(float(S.nose), float(fm.nose))
	if fm.snap:
		S.snaps = int(S.snaps) + 1
		if (S.snapped as Array).size() < 20:
			(S.snapped as Array).append("%s: %.1f px/s in a frame, %.1fx its neighbours, at %.2f s (%s)" % [where, fm.frame_dv, fm.frame_ratio, fm.at, fm.mode])


## Where a corner is (`why=`): the drawn point nearest the worst turn, and which part of the flight.
func _corner_why(pl, path3: PackedVector3Array, zz: float) -> void:
	var cpx: Vector2 = _worst_px[2] / zz
	var bd := INF
	var bk := 0
	for k in path3.size():
		var q := _scr(path3[k])
		if q.distance_to(cpx) < bd:
			bd = q.distance_to(cpx)
			bk = k
	var ns: int = pl.samp.size()
	if bk >= ns:
		print("    corner at zoom %d: in the ring drawn after (tail %d of %d)" % [int(zz), bk - ns, pl.tail.size()])
		return
	var tau: float = bk * pl.sdt
	var d2: float = pl.res.d2 if pl.res != null else 0.0
	var part := "the departure burn" if tau < float(pl.esc_t) else ("the arrival burn" if tau > float(pl.dur) - d2 else "the coast")
	var v := Vector3.ZERO
	if bk > 0 and bk < ns - 1:
		v = (pl.samp[bk + 1] - pl.samp[bk - 1]) / (2.0 * pl.sdt)
	var vmin := INF
	for k2 in range(maxi(1, bk - 120), mini(ns - 1, bk + 120)):
		vmin = minf(vmin, ((pl.samp[k2 + 1] - pl.samp[k2 - 1]) / (2.0 * pl.sdt)).length())
	var v0: Vector3 = (pl.samp[1] - pl.samp[0]) / pl.sdt
	print("    corner at zoom %d: %.2f s of %.2f (%s; burn %.2f s, arrival burn %.2f s), speed %.1f px/s, least within 0.5 s %.1f, burning %s; leaves at %.1f px/s, departure dv %.1f, work %.1f" % [int(zz), tau, pl.dur, part, pl.esc_t, d2, v.length(), vmin, pl.burns[bk] == 1, v0.length(), pl.res.dv1 if pl.res != null else 0.0, pl.res.work if pl.res != null else 0.0])


## Put the ship where the start says.
func _start(fl, L: SystemLayout, kind: String, b: int, t: float, seed: int) -> void:
	var R := RandomNumberGenerator.new()
	R.seed = seed * 31 + kind.hash() + b * 977
	var c0 := L.bary if L.twin else Vector2.ZERO
	match kind:
		"orbit", "close":
			fl.place_at(b, t)
			fl.rail.ang = R.randf() * TAU
		"keep":
			fl.place_at(b, t)
		"star":
			# SETTLED ON A STAR ORBIT where letting go would settle it: round the
			# star, or in a twin round the nearer star or both
			var lo: float = fl.star_ring() + 40.0
			var r := lerpf(lo, L.edge * 0.8, R.randf())
			var a := R.randf() * TAU
			var p := _clear_of_stars(fl, L, _clear_of_worlds(fl, L, c0 + Vector2(cos(a), sin(a)) * r, t), t)
			fl.settle_at(t, p, 1.0 if R.randf() < 0.8 else -1.0)
		"free":
			var r2 := lerpf(fl.star_ring() + 40.0, L.edge * 0.9, R.randf())
			var a2 := R.randf() * TAU
			fl.mode = &"free"
			fl.f.p = _clear_of_stars(fl, L, _clear_of_worlds(fl, L, c0 + Vector2(cos(a2), sin(a2)) * r2, t), t)
			fl.f.v = Vector2(R.randf_range(-120, 120), R.randf_range(-120, 120))
			# coasting free, not on the star orbit it arrived on
			fl.f.orbit_r = -1.0
		"edge":
			pass
		"near":
			var c3: Vector3 = fl.center(b, t)
			var cv3: Vector3 = fl.center_vel(b, t)
			# outside its ring (the ring would take it), within about two of it
			var ra3: float = L.bodies[b].soi
			var a3 := R.randf() * TAU
			fl.mode = &"free"
			var d3 := lerpf(1.15, 2.2, R.randf())
			fl.f.p = Vector2(c3.x, c3.z) + Vector2(cos(a3), sin(a3)) * ra3 * d3
			# clear of every star's bumper, as the game keeps a ship (round the
			# world until it is)
			for _k3 in 12:
				if _star_gap(fl, L, fl.f.p, t) > 12.0:
					break
				a3 += TAU / 12.0
				fl.f.p = Vector2(c3.x, c3.z) + Vector2(cos(a3), sin(a3)) * ra3 * d3
			fl.f.orbit_r = -1.0
			fl.f.v = Vector2(cv3.x, cv3.z) + Vector2(R.randf_range(-120, 120), R.randf_range(-120, 120))


## How far p is outside the nearest star's keep-clear at map time t (a
## turning pair's suns where they are then).
func _star_gap(fl, L: SystemLayout, p: Vector2, t: float) -> float:
	var g := INF
	for s in L.stars():
		g = minf(g, (p - L.star_pos(s, t)).length() - float(fl.keep_clear(s)))
	return g


## A start the stars allow at map time t: out of every star's bumper where
## the star is then (pushed out from the nearest).
func _clear_of_stars(fl, L: SystemLayout, p: Vector2, t: float) -> Vector2:
	for s in L.stars():
		var c := L.star_pos(s, t)
		var bm: float = float(fl.bumper(s)) + 10.0
		if (p - c).length() < bm:
			p = c + (p - c).normalized() * bm if (p - c).length() > 0.01 else c + Vector2(bm, 0.0)
	return p


## The plan's own numbers: closest approaches, top speed and pull, and the biggest kink.
func _measure(fl, L: SystemLayout, pl, i: int, t: float, from_b: int) -> Dictionary:
	var m := {"star": INF, "world": INF, "speed": 0.0, "acc": 0.0, "kink": 0.0}
	var n: int = pl.samp.size()
	var pv := Vector3.INF
	for k in range(0, n, 2):
		var q: Vector3 = pl.samp[k]
		var tk: float = float(pl.t0) + k * pl.sdt
		if not (SystemLayout.is_star(i) and (n - k) * pl.sdt < 0.4):
			for s in L.stars():
				m.star = minf(m.star, (Vector2(q.x, q.z) - L.star_pos(s, tk)).length() - L.star_radius(s))
		for b in L.bodies:
			if b.world == &"":
				continue
			if b.index == from_b and k * pl.sdt < pl.esc_t + 0.3:
				continue
			if b.index == i and (n - k) * pl.sdt < 0.5:
				continue
			var c: Vector3 = fl.center(b.index, tk)
			m.world = minf(m.world, Vector2(q.x - c.x, q.z - c.z).length() - b.r)
		if k >= 2 and k + 2 < n:
			var a0: Vector3 = (pl.samp[k] - 2.0 * pl.samp[k - 1] + pl.samp[k - 2]) / (pl.sdt * pl.sdt)
			var a1: Vector3 = (pl.samp[k + 1] - 2.0 * pl.samp[k] + pl.samp[k - 1]) / (pl.sdt * pl.sdt)
			m.kink = maxf(m.kink, (a1 - a0).length())
		if k + 2 < n:
			var v: Vector3 = (pl.samp[k + 2] - q) / (2.0 * pl.sdt)
			m.speed = maxf(m.speed, v.length())
			if pv != Vector3.INF:
				m.acc = maxf(m.acc, (v - pv).length() / (2.0 * pl.sdt))
			pv = v
	return m


## Flown at 60 a second with the drawn plan given to `fly` as the map's click does (`fly_bg`).
## Why: docs/why/FlightTest.md#click-and-flight
func _fly(fl, i: int, t0: float, drawn, undrawn := false) -> Dictionary:
	var out := {"land_s": -1.0, "dep_s": -1.0, "landed": false, "frame_dv": 0.0, "frame_ratio": 0.0, "at": 0.0, "mode": "", "same": false, "redrawn": false,
		"off": 0.0, "snap": false, "nose": 0.0, "mode_end": "", "secs": 0.0, "undrawn": undrawn, "inserted": false, "jump": 0.0}
	var pl = fl.fly(i, t0, func() -> void: pass, drawn.choice, null if undrawn else drawn)
	if pl == null:
		return out
	out.same = not undrawn and drawn.res != null and pl.res == drawn.res
	# THE DRAWN FLIGHT LEAVING LATE, PLANNED AGAIN AT THE CLICK (`ShipFlight.
	# CLICK_LATE`): the line is drawn again then, and that is the flight held
	# to it
	out.redrawn = bool(fl.click_replanned)
	if out.redrawn and pl.res != null:
		drawn = pl
		out.same = true
	out.pace = float(pl.pace) if pl.res != null else 1.0
	if ShipFlightS.why:
		print("    flown: kind %s, dur %.2f, esc %.2f, lead %.2f, t0 %.2f vs %.2f, samples %d, the drawn one %s" % [pl.kind, pl.dur, pl.esc_t, pl.lead, pl.t0, t0, pl.samp.size(), out.same])
	var dt := 1.0 / 60.0
	var t := t0
	var ps: Array = []
	var modes: Array = []
	var noses: Array = []
	var te: float = float(drawn.t0) + float(drawn.dur)
	var off := 0.0
	var landed_at := -1
	for k in int(_fly_max(pl) / dt):
		t += dt
		fl.step(dt, t, NONE)
		# (an insertion flown onto the ring: a solved flight lands on it exactly)
		if fl.mode == &"rail" and (fl.rail as Dictionary).has("ins"):
			out.inserted = true
		var p: Vector3 = fl.where3()
		ps.append(Vector2(p.x, p.z))
		modes.append(String(fl.mode) + (" inserting" if fl.inserting() else ""))
		# (the wait before it leaves: the click to the frame it flies)
		if float(out.dep_s) < 0.0 and fl.mode == &"fly":
			out.dep_s = t - t0
		noses.append(float(fl.ang))
		if out.same:
			if t >= float(drawn.t0) and t <= te:
				var q: Vector3 = drawn.pos((t - float(drawn.t0)) / float(drawn.dur))
				off = maxf(off, Vector2(p.x - q.x, p.z - q.z).length())
			elif t > te and t < te + 0.4 and drawn.tail.size() > 1:
				off = maxf(off, _to_line(Vector2(p.x, p.z), drawn.tail))
		if fl.reached() == i and k > 2:
			out.landed = true
			landed_at = k
			out.land_s = t - t0
			# a few frames on the orbit too
			for _j in 6:
				t += dt
				fl.step(dt, t, NONE)
				p = fl.where3()
				ps.append(Vector2(p.x, p.z))
				modes.append(String(fl.mode))
				noses.append(float(fl.ang))
			break
	out.off = off
	out.secs = t - t0
	out.mode_end = String(fl.mode)
	# The most it moved in one frame: a ship put elsewhere
	# changes velocity alike twice, unseen by the snap ratio.
	for k6 in range(1, ps.size()):
		out.jump = maxf(float(out.jump), ((ps[k6] as Vector2) - (ps[k6 - 1] as Vector2)).length())
	var dvs: Array = [0.0, 0.0]
	for k2 in range(2, ps.size()):
		var v1: Vector2 = (ps[k2] - ps[k2 - 1]) / dt
		var v0: Vector2 = (ps[k2 - 1] - ps[k2 - 2]) / dt
		dvs.append((v1 - v0).length())
	for k5 in range(1, noses.size()):
		out.nose = maxf(float(out.nose), rad_to_deg(absf(wrapf(float(noses[k5]) - float(noses[k5 - 1]), -PI, PI))))
	if ShipFlightS.why:
		for k4 in range(2, dvs.size()):
			if float(dvs[k4]) > 4.0:
				print("    frame %d (%.2f s, %s): dv %.1f, at %s" % [k4, k4 * dt, modes[k4], dvs[k4], (ps[k4] as Vector2).round()])
	for k3 in range(3, dvs.size() - 1):
		var d: float = dvs[k3]
		var ratio := d / ((float(dvs[k3 - 1]) + float(dvs[k3 + 1])) / 2.0 + 0.5)
		if d > float(out.frame_dv):
			out.frame_dv = d
			out.at = k3 * dt
			out.mode = modes[k3]
		out.frame_ratio = maxf(float(out.frame_ratio), ratio)
		# (a flight on its own clock pulls pace^2 harder on the map: a snap's floor too)
		if d > SNAP_DV * pow(float(pl.pace), 2.0) and ratio > SNAP_RATIO:
			out.snap = true
	if landed_at < 0 and ShipFlightS.why:
		print("    not landed: mode %s, reached %d" % [fl.mode, fl.reached()])
	return out


## How long the best burn keeps clear (up to 30 s); INF from any start no measure excuses.
func _clear_for(fl, i: int, t: float) -> float:
	var dep: Dictionary = fl._dep_of(t, ShipFlightS.PREVIEW_AHEAD)
	if dep.is_empty() or StringName(dep.kind) != &"free":
		return INF
	var fs := FlightSolve.new()
	fs._solve(fl._grav(), dep, fl._tgt_of(i), t, {})
	var p: Vector2 = dep.p
	var v: Vector2 = dep.v
	var best := 0.0
	for hj in CLEAR_HEAD:
		var hd := TAU * float(hj) / float(CLEAR_HEAD)
		for dv: float in CLEAR_DV:
			fs._integrate(t, p.x, p.y, v.x, v.y, cos(hd) * dv, sin(hd) * dv, t + 30.0)
			best = maxf(best, fs._t_bad - t if fs._t_bad < INF else 30.0)
	return best


## The longest plan pl may take from its click to on its orbit (s).
static func _fly_max(pl) -> float:
	return FLY_MAX_TWO if pl != null and pl.res != null and pl.res.legs == 2 else FLY_MAX


## How far p is from the polyline (plane px).
static func _to_line(p: Vector2, line: PackedVector3Array) -> float:
	var best := INF
	for k in range(1, line.size()):
		var a := Vector2(line[k - 1].x, line[k - 1].z)
		var b := Vector2(line[k].x, line[k].z)
		var ab := b - a
		var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		best = minf(best, (a + ab * u - p).length())
	return best


## THE COMMON FLIGHTS, apart, per sweep: the drawn path's tightest bend as a
## radius in screen px and its corners at zoom 1 and 2, its S-bends, its time.
func _category(sweep: String, key: String, fl, L: SystemLayout, pl, path3: PackedVector3Array, i: int, b: int) -> void:
	var tgt_world: bool = i >= 0 and L.bodies[i].world != &""
	var cat := ""
	if key == "orbit" and SystemLayout.is_star(i):
		cat = "world orbit -> star"
	elif key == "star" and tgt_world:
		cat = "star orbit -> world"
	elif key == "orbit" and tgt_world:
		cat = "world -> world"
	elif key == "free" and tgt_world:
		cat = "free -> world"
	elif key == "star" and SystemLayout.is_star(i):
		cat = "star orbit -> close orbit"
	elif key == "close" and tgt_world:
		cat = "close orbit -> world"
	elif key == "close" and SystemLayout.is_star(i):
		cat = "star -> star"
	elif key == "near" and tgt_world:
		cat = "near -> world"
	elif key == "keep" and tgt_world:
		cat = "alongside -> world"
	if cat == "":
		return
	cat = "%s: %s" % [sweep, cat]
	if not _cat.has(cat):
		_cat[cat] = {"r1": [], "r2": [], "c1": 0, "c2": 0, "n": 0, "dur": [], "off": [], "s": [], "sw": [], "arr": []}
	var C: Dictionary = _cat[cat]
	C.n = int(C.n) + 1
	var ga := _gait(fl, L, pl, path3, i, b if key == "orbit" else -9)
	(C.off as Array).append(ga[0])
	(C.s as Array).append(ga[1])
	(C.sw as Array).append(ga[2])
	(C.arr as Array).append(ga[3])
	(C.dur as Array).append(float(pl.res.T) if pl.res != null else float(pl.dur))
	for zc: float in [1.0, 2.0]:
		var skip := _ring_skip(fl, L, pl, path3, i, b if key == "orbit" or key == "close" else -99, zc)
		_corner_only = false
		var tb := _turn_max(path3, zc, skip)
		_corner_only = true
		var cb := _turn_max(path3, zc, skip)
		_corner_only = false
		(C["r%d" % int(zc)] as Array).append(1.0 / maxf(deg_to_rad(tb), 1e-4))
		if cb > CORNER:
			C["c%d" % int(zc)] = int(C["c%d" % int(zc)]) + 1


## Compares where letting go captures a slow ship under the new rule against the old.
## Why: docs/why/FlightTest.md#capture-rules
func _captures(L: SystemLayout, seed: int) -> Array:
	var fl = _flight_script.new()
	fl.setup(L, Vector2(L.edge * 0.9, -210.0), 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + seed
	var held2 := 0
	var diff := 0
	var n := 0
	var places: Array = []
	for b in L.bodies:
		if b.world != &"" or fl.is_keep(b.index):
			places.append(b.index)
	for s in L.stars():
		places.append(s)
	# Conjunctions are worked out from the circles: at
	# a random moment two rings rarely hold one ship.
	var meets: Array = []
	for p0: int in places:
		if p0 < 0:
			continue
		var a0 := L.bodies[p0]
		for b1 in L.bodies:
			if b1.world == &"" or b1.index == p0 or b1.host0 != a0.host0:
				continue
			if absf(a0.orbit - b1.orbit) >= b1.soi * 0.9:
				continue
			var na := TAU / a0.period
			var nb := TAU / b1.period
			if absf(na - nb) < 1e-9:
				continue
			# the angles a0.phase + na t and b1.phase + nb t meet
			var tq := fposmod(b1.phase - a0.phase, TAU) / (na - nb) if na > nb else fposmod(a0.phase - b1.phase, TAU) / (nb - na)
			for dtq: float in [0.0, -6.0, 6.0]:
				meets.append([p0, tq + dtq])
	var tries: Array = []
	for p: int in places:
		for j in 6:
			tries.append([p, rng.randf_range(0.0, 600.0)])
	tries.append_array(meets)
	for tr: Array in tries:
		var p: int = tr[0]
		var t: float = tr[1]
		var c3: Vector3 = fl.center(p, t)
		var cv: Vector3 = fl.center_vel(p, t) if p >= 0 else Vector3.ZERO
		var a := rng.randf() * TAU
		var reach := 0.0
		var off := Vector2.ZERO
		if SystemLayout.is_star(p):
			reach = float(fl.star_ring(p))
			off = Vector2(cos(a), sin(a)) * reach * rng.randf_range(0.6, 0.95)
		elif L.bodies[p].world != &"":
			reach = L.bodies[p].soi
			off = Vector2(cos(a), sin(a)) * reach * rng.randf_range(0.2, 0.95)
		else:
			off = Vector2(cos(a), sin(a) / 0.38) * ShipFlightS.KEEP_R * rng.randf_range(0.2, 0.9)
		var st = ShipFlightS.FreeState.new()
		st.p = Vector2(c3.x, c3.z) + off
		st.v = Vector2(cv.x, cv.z) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 20.0)
		st.coast = 1.0
		# how many rings hold it
		var holds := 0
		for b2 in L.bodies:
			var c2: Vector3 = fl.center(b2.index, t)
			var rel := Vector2(st.p.x - c2.x, st.p.y - c2.z)
			if b2.world != &"" and rel.length() < b2.soi:
				holds += 1
			elif fl.is_keep(b2.index) and Vector2(rel.x, rel.y * 0.38).length() < ShipFlightS.KEEP_R:
				holds += 1
		for s2 in L.stars():
			if (st.p - L.star_pos(s2, t)).length() < float(fl.star_ring(s2)):
				holds += 1
		n += 1
		if holds < 2:
			continue
		held2 += 1
		var sa = st.copy()
		var sb = st.copy()
		var ra: Dictionary = fl.free_step(sa, NONE, t, 1.0 / 60.0, -9, true)
		ShipFlightS.capture_by_index = true
		var rb: Dictionary = fl.free_step(sb, NONE, t, 1.0 / 60.0, -9, true)
		ShipFlightS.capture_by_index = false
		if ra.get("kind", &"") != rb.get("kind", &"") or int(ra.get("body", -99)) != int(rb.get("body", -99)):
			diff += 1
	return [held2, diff, n]


## Plans on a worker as `plan_bg` makes them, compared sample for sample with the one made here.
func _worker_phase() -> void:
	var tree := get_tree()
	var main_ms: Array = []
	var bg_ms: Array = []
	var take_us: Array = []
	var frames: Array = []
	var step_us: Array = []
	var gap_run: Array = []
	var gap_idle: Array = []
	var same := 0
	var tried := 0
	var stale := 0
	var by_sw := {}
	var t_last := Time.get_ticks_usec()
	# the frames with no plan running, for the frame cost with one (the first
	# few after the sweep's long frame left out)
	for _k in 36:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		if _k >= 6:
			gap_idle.append(float(now - t_last) / 1000.0)
		t_last = now
	var picked := 0
	for row: Array in _wk:
		if picked >= _worker_n:
			break
		picked += 1
		var L: SystemLayout = row[1]
		var fl = _flight_script.new()
		fl.setup(L, Vector2(-L.edge * 0.95, 0.0), float(row[5]))
		_start(fl, L, String(row[2]), int(row[3]), float(row[5]), int(row[7]))
		fl.step(1.0 / 60.0, float(row[5]), NONE)
		var t: float = row[5]
		var t0 := Time.get_ticks_usec()
		var ref = fl.make_plan(int(row[4]), t, {}, ShipFlightS.PREVIEW_AHEAD)
		main_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if ref == null or not fl.plan_bg(int(row[4]), t, {}, &"preview"):
			continue
		tried += 1
		var got: Dictionary = {}
		var nf := 0
		t_last = Time.get_ticks_usec()
		while got.is_empty() and nf < 600:
			await tree.process_frame
			var now2 := Time.get_ticks_usec()
			gap_run.append(float(now2 - t_last) / 1000.0)
			t_last = now2
			nf += 1
			# (the ship held where it was planned from: the poll and the take-in
			# are what this thread pays)
			var s0 := Time.get_ticks_usec()
			fl._poll_jobs(t)
			var ready: bool = not fl.planning(&"preview") or WorkerThreadPool.is_task_completed(int(fl._jobs[&"preview"].task))
			var s1 := Time.get_ticks_usec()
			if ready:
				got = fl.take_bg(&"preview", t)
				take_us.append(float(Time.get_ticks_usec() - s1))
			else:
				step_us.append(float(s1 - s0))
		frames.append(nf)
		var pl = got.get("plan")
		if pl == null or pl.res == null:
			continue
		bg_ms.append(float(fl.last_ms))
		if not by_sw.has(row[0]):
			by_sw[row[0]] = []
		(by_sw[row[0]] as Array).append(float(fl.last_ms))
		if pl.samp == ref.samp and pl.burns == ref.burns and pl.t0 == ref.t0 and pl.end == ref.end:
			same += 1
		elif stale < 6:
			stale += 1
			print("  worker: not the same flight: %s %d -> %d (%s)" % [row[2], int(row[3]), int(row[4]), row[0]])
	print("flighttest: on a worker, %d plans: %d the same flight bit for bit as on this thread" % [tried, same])
	print("  planning on this thread: %s ms; on the worker (its own time): %s ms" % [_dist(main_ms), _dist(bg_ms)])
	for sw: String in by_sw:
		print("  on the worker, %s: %s ms" % [sw, _dist(by_sw[sw])])
	print("  frames from asking to having it: %s; this thread's poll a frame while it runs: %s us; its take-in: %s us" % [_dist(frames), _dist(step_us), _dist(take_us)])
	print("  this thread's frame, a plan running on the worker: %s ms; none running: %s ms" % [_dist(gap_run), _dist(gap_idle)])
	h._ok("every worker plan the same flight as this thread's (%d of %d)" % [same, tried], same == tried and tried > 0)


## Added after the Oct 31 flight review: no harness clicked through `fly_bg`, and none in a twin.
## Why: docs/why/FlightTest.md#click-phase
func _click_phase() -> void:
	var tree := get_tree()
	var tot := {}
	var lines: Array = []
	for fps: float in [60.0, 30.0]:
		var dt := 1.0 / fps
		for sweep: String in ["twin", "close", "one", "giant"]:
			var pool: Array = _ck[sweep]
			if pool.is_empty():
				continue
			var want := _clicks if sweep == "twin" else maxi(1, _clicks / 2)
			var picks := _spread(pool.size(), want)
			var key2 := "%s at %.0f fps" % [sweep, fps]
			var T := {"clicks": 0, "flown": 0, "landed": 0, "cb_ok": 0, "put": 0, "stale": 0, "sync": 0, "pend": [], "drawn": 0,
				"drawn_px": [], "w_n": 0, "w_ok": 0, "adopt": 0, "undrawn": 0, "take_us": []}
			for ci in picks.size():
				var row: Array = pool[picks[ci]]
				var L: SystemLayout = row[1]
				var key: String = row[2]
				var b: int = row[3]
				var i: int = row[4]
				var t: float = row[5]
				var fl = _flight_script.new()
				fl.setup(L, Vector2(-L.edge * 0.95, 0.0), t)
				_start(fl, L, key, b, t, int(row[6]))
				fl.step(dt, t, NONE)
				if not fl.can_fly() or fl.orbit_body() == i:
					continue
				var where := "%s system %d from %s %d to %d" % [key2, int(row[6]), key, b, i]
				# Most click on the drawn line; some while the
				# preview is being made, some let go with W.
				var adopt := ci % 5 == 4
				var w_cancel := not adopt and ci % 4 == 3
				var undrawn := w_cancel or (not adopt and ci % 3 == 1)
				var R := RandomNumberGenerator.new()
				R.seed = int(row[6]) * 31 + i * 7 + ci
				# THE PREVIEW, as the overlay keeps it, up to the click
				var pv = null
				var pv_at := -99.0
				var every := 3.0 if fl.mode == &"rail" else 1.0
				var click_at := t + 0.4 + R.randf() * 1.1
				var w0 := Time.get_ticks_usec()
				var fr := 0
				var asked := false
				while true:
					if adopt and asked:
						break
					if not adopt and t >= click_at and pv != null:
						break
					if t > click_at + 4.0:
						break
					await tree.process_frame
					_pace(w0, fr, dt)
					fr += 1
					t += dt
					fl.step(dt, t, NONE)
					var gone: bool = pv != null and (t >= float(pv.t0) - ShipFlightS.PLAN_AHEAD or fl._takeable(pv, t).is_empty())
					if not fl.planning(&"preview") and (pv == null and pv_at < -1.0 or gone or t - pv_at > every):
						if fl.plan_bg(i, t, pv.choice if pv != null else {}, &"preview", PV_LINE):
							asked = true
							pv_at = t
					var tu := Time.get_ticks_usec()
					var got: Dictionary = fl.take_bg(&"preview", t)
					if not got.is_empty():
						(T.take_us as Array).append(float(Time.get_ticks_usec() - tu))
						var pl = got.plan
						if pl != null and not fl._takeable(pl, t).is_empty():
							pv = pl
						elif pl != null:
							pv_at = -99.0
				# THE CLICK, before the frame's clock moves
				T.clicks = int(T.clicks) + 1
				if adopt:
					T.adopt = int(T.adopt) + 1
				if undrawn:
					T.undrawn = int(T.undrawn) + 1
					pv = null
					fl.drop_bg(&"preview")
				var calls := [0, -99]
				var st0: int = ShipFlightS.n_stale
				var ok: bool = fl.fly_bg(i, t, func() -> void:
					calls[0] += 1
					calls[1] = fl.reached(), pv.choice if pv != null else {}, pv)
				if not ok:
					lines.append("REFUSED: %s" % where)
					continue
				var took := -1
				var flew_drawn := false
				var flown_pl = null
				var fline := PackedVector3Array()
				var off := 0.0
				var jl := 0
				var w0b := Time.get_ticks_usec()
				var fb := 0
				var put := false
				var landed := false
				# (longer once the flight flown is one in two legs)
				var lim := int(FLY_MAX / dt)
				var k := -1
				while k + 1 < lim:
					k += 1
					var pend: bool = not (fl._pend as Dictionary).is_empty()
					if pend:
						await tree.process_frame
						_pace(w0b, fb, dt)
						fb += 1
					t += dt
					var keys: Dictionary = NONE
					if w_cancel and pend and k == 1:
						keys = {"w": true, "a": false, "s": false, "d": false}
					var s0 := Time.get_ticks_usec()
					fl.step(dt, t, keys)
					if Time.get_ticks_usec() - s0 > 20000:
						T.sync = int(T.sync) + 1
					if keys.w:
						T.w_n = int(T.w_n) + 1
						if (fl._pend as Dictionary).is_empty() and not fl.planning(&"fly") and fl.mode == &"free":
							T.w_ok = int(T.w_ok) + 1
						else:
							lines.append("W DID NOT LET GO: %s (mode %s)" % [where, fl.mode])
						break
					if took < 0 and (fl._pend as Dictionary).is_empty():
						took = k + 1
						(T.pend as Array).append(float(took))
						if fl.plan == null and calls[0] > 0:
							put = true
						elif fl.plan != null:
							flew_drawn = pv != null and ((fl.plan.res != null and fl.plan.res == pv.res) or fl.plan == pv)
							# The flight as the overlay draws it once flown
							# (`_plan_line`): the preview's or the click's.
							flown_pl = pv if flew_drawn else fl.plan
							fline = (flown_pl.line[0] if (flown_pl.line as Array).size() == 3 else fl.lay_out(flown_pl, PV_LINE)[0])
							lim = int(_fly_max(flown_pl) / dt)
					# Flown frame against the drawn line, from its
					# departure to the ring drawn after its arrival.
					if flown_pl != null and not fline.is_empty():
						var te: float = float(flown_pl.end.get("t", float(flown_pl.t0) + float(flown_pl.dur)))
						if t >= float(flown_pl.t0) and t <= te + 0.9 * ShipFlightS.TAIL_S:
							var p3: Vector3 = fl.where3()
							var r2 := _near_line(Vector2(p3.x, p3.z), fline, jl)
							jl = int(r2[1])
							off = maxf(off, float(r2[0]))
					if fl.reached() == i and calls[0] > 0:
						landed = true
						break
				var stales: int = ShipFlightS.n_stale - st0
				T.stale = int(T.stale) + stales
				if put:
					T.put = int(T.put) + 1
					lines.append("PUT THERE: %s" % where)
				if took >= 0 and not put:
					T.flown = int(T.flown) + 1
				if landed:
					T.landed = int(T.landed) + 1
				var cb_ok: bool = calls[0] == 1 and int(calls[1]) == i
				if landed and cb_ok:
					T.cb_ok = int(T.cb_ok) + 1
				elif not w_cancel and lines.size() < 40:
					lines.append("%s: callback %d times (at %d), landed %s, mode %s" % [where, calls[0], calls[1], landed, fl.mode])
				if flew_drawn:
					T.drawn = int(T.drawn) + 1
				if flown_pl != null:
					(T.drawn_px as Array).append(off)
					if off > DRAWN_PX and lines.size() < 40:
						lines.append("OFF THE DRAWN LINE %.2f px: %s" % [off, where])
			tot[key2] = T
	print("flighttest: clicks through the map's own path (fly_bg, the preview as the overlay keeps it), paced to the wall clock while planning")
	var all_ok := true
	for key3: String in tot:
		var T2: Dictionary = tot[key3]
		var n_fly: int = int(T2.clicks) - int(T2.w_n)
		print("  %s: %d clicks (%d while the preview was being made, %d with none drawn), %d flown, %d landed, %d with the callback once on the orbit, %d put there; %d stale take-ins planned again, %d frames over 20 ms in the step; W let go of %d of %d still being planned" % [key3, T2.clicks, T2.adopt, T2.undrawn, T2.flown, T2.landed, T2.cb_ok, T2.put, T2.stale, T2.sync, T2.w_ok, T2.w_n])
		print("    frames from the click to the flight: %s; the preview's take-in on this thread: %s us" % [_dist(T2.pend), _dist(T2.take_us)])
		print("    flew the preview drawn before the click: %d; every flight's frames against the line the overlay draws for it, px: %s" % [T2.drawn, _dist(T2.drawn_px)])
		var off_ok := true
		for x in T2.drawn_px:
			if float(x) > DRAWN_PX:
				off_ok = false
		var ok3: bool = int(T2.landed) == n_fly and int(T2.cb_ok) == n_fly and int(T2.w_ok) == int(T2.w_n) and int(T2.sync) == 0 and off_ok and n_fly > 0
		h._ok("%s: every click flew and landed with its callback once (%d of %d), W let go of every one being planned (%d of %d), no frame planned on this thread, every flight that was drawn flown on its line within %.1f px" % [key3, T2.cb_ok, n_fly, T2.w_ok, T2.w_n, DRAWN_PX], ok3)
		all_ok = all_ok and ok3
	for l in lines.slice(0, 30):
		print("    " + l)
	print("  engine errors while the map's paths ran: %d" % _errs.n)
	for e in _errs.first:
		print("    error: " + e)
	h._ok("no engine error while clicking through the map's paths (%d)" % _errs.n, _errs.n == 0)


## The map's frames paced to the wall clock: frame fr ends no sooner than (fr +
## 1) dt after w0 (a frame of the game's, at that rate).
func _pace(w0: int, fr: int, dt: float) -> void:
	var want := int(float(fr + 1) * dt * 1e6)
	var spent := Time.get_ticks_usec() - w0
	if spent < want:
		OS.delay_usec(want - spent)


## How far p is from a laid-out line, looking on from j0: [distance, nearest segment].
## It looks on past 64 points while the nearest is at the end: CURVED at x12 moves about 65 a frame.
## Why: docs/why/FlightTest.md#near-line
static func _near_line(p: Vector2, line: PackedVector3Array, j0: int) -> Array:
	var best := INF
	var bj := j0
	var lo := maxi(1, j0 - 8)
	var hi := mini(line.size(), j0 + 64)
	while true:
		for j in range(lo, hi):
			var a := Vector2(line[j - 1].x, line[j - 1].z)
			var b := Vector2(line[j].x, line[j].z)
			var ab := b - a
			var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
			var d := (a + ab * u - p).length()
			if d < best:
				best = d
				bj = j
		if bj < hi - 2 or hi >= line.size():
			break
		lo = hi
		hi = mini(line.size(), hi + 64)
	return [best, bj]


## As the Oct 31 review let go and held W: it settles inside the map and never enters a keep-out.
## Why: docs/why/FlightTest.md#hand-flying-in-a-twin
func _hand_phase() -> void:
	var seen := {}
	var dt := 1.0 / 60.0
	var n := {"far": 0, "far_ok": 0, "far_flights": 0, "far_fl_ok": 0, "mid": 0, "mid_ok": 0, "sun": 0, "sun_ok": 0}
	var rows: Array = []
	var worst_out := -INF
	var worst_settle := 0.0
	var worst_sun := INF
	# (ten wide pairs and five close pairs, as the clicks gathered them:
	# HAND_WIDE and HAND_CLOSE)
	var by_kind := {}
	for row: Array in (_ck.twin as Array) + (_ck.close as Array):
		var L: SystemLayout = row[1]
		var kind := "close" if L.close else "wide"
		var key := "%s %d" % [kind, int(row[6])]
		if seen.has(key) or int(by_kind.get(kind, 0)) >= (HAND_CLOSE if L.close else HAND_WIDE):
			continue
		seen[key] = true
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var t0: float = row[5]
		# The pair turns (ruling 23), so far side and
		# across are read off the suns where they are then.
		var line_ab := (L.star_pos(SystemLayout.STAR_B, t0) - L.star_pos(-1, t0)).normalized()
		var away := -line_ab
		var perp := Vector2(-away.y, away.x)
		# OUT ON THE FAR SIDE
		var fl = _flight_script.new()
		fl.setup(L, Vector2(-L.edge * 0.95, 0.0), t0)
		fl.mode = &"free"
		fl.f.p = away * L.edge * 0.99
		fl.f.v = perp * 8.0
		fl.f.orbit_r = -1.0
		fl.f.coast = 0.0
		var t := t0
		var settled_at := -1.0
		var pinned := 0
		# About one twin layout in five had the far circle
		# inside a world's ring, putting the ship on it (Nov 2).
		# Why: docs/why/FlightTest.md#hand-flying-in-a-twin
		var taken_far := ""
		for k in int(60.0 / dt):
			t += dt
			fl.step(dt, t, NONE)
			if settled_at < 0.0 and fl.star_orbiting():
				settled_at = float(k) * dt
			if settled_at >= 0.0 and (fl.f.p as Vector2).length() > L.edge - 0.5:
				pinned += 1
			if taken_far == "" and fl.mode != &"free":
				taken_far = "%s %d at %.1f s" % [fl.mode, fl.orbit_body(), float(k) * dt]
		n.far = int(n.far) + 1
		var out: float = (fl.f.cen as Vector2).length() + float(fl.f.orbit_r) - L.edge
		worst_out = maxf(worst_out, out)
		worst_settle = maxf(worst_settle, settled_at if settled_at >= 0.0 else 99.0)
		var far_ok: bool = settled_at >= 0.0 and settled_at < 30.0 and out <= -11.0 and pinned == 0 and taken_far == ""
		if far_ok:
			n.far_ok = int(n.far_ok) + 1
		else:
			rows.append("far side, system %d: settled at %.1f s, its circle %+.0f px past the edge, %d frames on the edge after%s" % [int(row[6]), settled_at, out, pinned, "" if taken_far == "" else ", taken by a ring (%s)" % taken_far])
		if fl.star_orbiting():
			var tg: Array[int] = [-1]
			for bb in L.bodies:
				if bb.world != &"":
					tg.append(bb.index)
					break
			for i2: int in tg:
				var pl = fl.make_plan(i2, t, {}, ShipFlightS.PREVIEW_AHEAD)
				if pl == null:
					continue
				n.far_flights = int(n.far_flights) + 1
				var past := -INF
				for q: Vector3 in pl.samp:
					past = maxf(past, Vector2(q.x, q.z).length() - L.edge)
				if past <= 0.5:
					n.far_fl_ok = int(n.far_fl_ok) + 1
				else:
					rows.append("far side, system %d: the flight to %d runs %.1f px past the edge" % [int(row[6]), i2, past])
		# BETWEEN THE STARS
		for r0: float in [3.0, 25.0]:
			var fm = _flight_script.new()
			fm.setup(L, Vector2(-L.edge * 0.95, 0.0), t0)
			fm.mode = &"free"
			fm.f.p = L.bary + Vector2(-line_ab.y, line_ab.x) * r0
			fm.f.v = Vector2.ZERO
			fm.f.orbit_r = -1.0
			fm.f.coast = 0.0
			var tm := t0
			var st_at := -1.0
			var taken := false
			for k2 in int(15.0 / dt):
				tm += dt
				fm.step(dt, tm, NONE)
				if fm.mode != &"free":
					taken = true
					break
				if fm.star_orbiting():
					st_at = float(k2) * dt
					break
			n.mid = int(n.mid) + 1
			if st_at >= 0.0 and st_at < 10.0 and not taken:
				n.mid_ok = int(n.mid_ok) + 1
			else:
				rows.append("between the stars, system %d, %.0f px off: settled at %.1f s, taken by a ring %s (mode %s, %d)" % [int(row[6]), r0, st_at, taken, fm.mode, fm.orbit_body()])
		# W HELD AT EACH SUN
		for s: int in L.stars():
			# (the sun where it is at t0, measured against where it is each frame
			# it is held: a turning sun moves under the ship)
			var sc := L.star_pos(s, t0)
			var dir := Vector2(-line_ab.y, line_ab.x)
			var fw = _flight_script.new()
			fw.setup(L, Vector2(-L.edge * 0.95, 0.0), t0)
			fw.mode = &"free"
			fw.f.p = sc + dir * 170.0
			fw.f.v = -dir * 150.0
			fw.f.orbit_r = -1.0
			fw.f.head = ShipFlightS._scr_ang(-dir)
			fw.ang = fw.f.head
			var tw := t0
			var rmin := INF
			for _k3 in int(4.0 / dt):
				tw += dt
				fw.step(dt, tw, {"w": true, "a": false, "s": false, "d": false})
				rmin = minf(rmin, ((fw.f.p as Vector2) - L.star_pos(s, tw)).length())
			n.sun = int(n.sun) + 1
			var kc: float = float(fw.keep_clear(s))
			worst_sun = minf(worst_sun, rmin - (kc - 6.0))
			if rmin >= kc - 0.5:
				n.sun_ok = int(n.sun_ok) + 1
			else:
				rows.append("W at star %d, system %d: came to %.1f px from its centre, its keep-out %.1f (drawn sun %.1f)" % [s, int(row[6]), rmin, kc, kc - 6.0])
	print("flighttest: flying by hand in a twin (%d systems, %d of them close pairs): let go on the far side, %d of %d settled inside the map and off its edge and taken by no ring (its circle at worst %+.0f px past the edge, settled at worst in %.1f s), %d of %d flights from there inside it; let go between the stars, %d of %d settled and taken by no ring; W at a sun, %d of %d held out of its keep-out (at worst %.1f px outside the drawn sun)" % [seen.size(), int(by_kind.get("close", 0)), n.far_ok, n.far, worst_out, worst_settle, n.far_fl_ok, n.far_flights, n.mid_ok, n.mid, n.sun_ok, n.sun, worst_sun])
	for r in rows.slice(0, 20):
		print("    " + r)
	h._ok("by hand in a twin: let go anywhere it settles inside the map, between the stars too, and W never takes it into a sun (%d/%d, %d/%d, %d/%d, %d/%d)" % [n.far_ok, n.far, n.far_fl_ok, n.far_flights, n.mid_ok, n.mid, n.sun_ok, n.sun],
		int(n.far) > 0 and (not _wants("close") or int(by_kind.get("close", 0)) > 0) and n.far_ok == n.far and n.far_fl_ok == n.far_flights and n.mid_ok == n.mid and n.sun_ok == n.sun)
	# (and the turning pair's own flights by hand and from its edge: `_orbit_phase`)
	_orbit_phase()


## Ruling 23 (Jon, Nov 1): the suns circle at four times Kepler and carry their worlds along.
## Why: docs/why/FlightTest.md#turning-pair
const ORBIT_S := 60.0
const SETTLE_HOLD := 2.0
## a frame's move past this (px) is a jump, not a flight: 900 px/s, past any
## solved flight's top speed
const JUMP_PX := 15.0
func _orbit_phase() -> void:
	var dt := 1.0 / 60.0
	var B := SystemLayout.STAR_B
	var seen := {}
	var by_kind := {}
	var rows: Array = []
	var n := {"rail": 0, "rail_ok": 0, "settle": 0, "settle_ok": 0, "park": 0, "park_ok": 0,
		"pv": 0, "pv_take": 0, "pv_replay": 0, "pv_gave": 0, "pv_fly": 0, "edge_end": 0.0, "edge": 0, "edge_found": 0, "edge_landed": 0,
		"edge_drawn": 0, "edge_snaps": 0, "edge_jumps": 0, "on_b": 0, "on_b_ok": 0}
	var worst := {"jump": 0.0, "rail": 0.0, "rail_v": 0.0, "settle": 0.0, "cen": 0.0, "park": 0.0, "edge_off": 0.0, "on_b": 0.0, "moved": INF}
	for row: Array in (_ck.twin as Array) + (_ck.close as Array):
		var L: SystemLayout = row[1]
		var kind := "close" if L.close else "wide"
		var key := "%s %d" % [kind, int(row[6])]
		if seen.has(key) or int(by_kind.get(kind, 0)) >= (2 if L.close else 3):
			continue
		seen[key] = true
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var t0: float = row[5]
		var idx: int = row[6]
		var wb := -1
		for b in L.bodies:
			if b.host_id == B and b.world != &"":
				wb = b.index
				break
		# A CARRIED RAIL: star B's close orbit, and its world's
		var rails: Array[int] = [B]
		if wb >= 0:
			rails.append(wb)
		for place: int in rails:
			var fr = _flight_script.new()
			fr.setup(L, Vector2(L.edge, -210.0), t0)
			fr.place_at(place, t0)
			var rt: float = float(fr.rail.rt)
			var spd: float = float(fr.rail.speed)
			var c0 := _where_drawn(L, place, t0)
			var t := t0
			var w_r := 0.0
			var w_v := 0.0
			var left := false
			var last := Vector2.INF
			for k in int(ORBIT_S / dt):
				t = t0 + float(k + 1) * dt
				fr.step(dt, t, NONE)
				if fr.mode != &"rail" or fr.orbit_body() != place:
					left = true
					break
				var p := fr.f.p as Vector2
				w_r = maxf(w_r, absf((p - _where_drawn(L, place, t)).length() - rt))
				# Frame motion against the velocity it claims:
				# a rail lagging its sun by a frame shows.
				if last != Vector2.INF:
					w_v = maxf(w_v, ((p - last) / dt - (fr.f.v as Vector2)).length())
				last = p
			var moved := (_where_drawn(L, place, t) - c0).length()
			if L.pair_n != 0.0:
				worst.moved = minf(float(worst.moved), moved)
			worst.rail = maxf(float(worst.rail), w_r)
			worst.rail_v = maxf(float(worst.rail_v), w_v)
			n.rail = int(n.rail) + 1
			# (frame to frame against its velocity: a rail turns, so a chord is off
			# the tangent by v^2 dt / 2r, under 0.5 px/s on these rings)
			var v_slack := spd * spd * dt / (2.0 * rt) + 0.05
			if not left and w_r < 0.01 and w_v < v_slack and (L.pair_n == 0.0 or moved > 5.0):
				n.rail_ok = int(n.rail_ok) + 1
			else:
				rows.append("A CARRIED RAIL round %d, %s: %s, off its radius by %.4f px at worst, its motion off its velocity by %.2f px/s (at most %.2f), the place carried %.1f px" % [place, key, "LEFT IT" if left else "held", w_r, w_v, v_slack, moved])
		# In a wide pair B's world rings its whole zone, so
		# it is taken off the map for the settle and put-back.
		# Why: docs/why/FlightTest.md#carried-settle
		var r_set := _settle_r(L)
		var away := Vector2.RIGHT.rotated(L.pair_angle(t0) + PI * 0.5)
		if wb >= 0:
			away = (L.star_pos(B, t0) - L.bodies[wb].pos(t0)).normalized()
		var p_let := L.star_pos(B, t0) + away * r_set
		var hid: StringName = L.bodies[wb].world if wb >= 0 else &""
		if wb >= 0:
			L.bodies[wb].world = &""
		var settled: Array = []
		for how: String in ["let go", "settle_at"]:
			var fs = _flight_script.new()
			fs.setup(L, Vector2(L.edge, -210.0), t0)
			if how == "let go":
				fs.mode = &"free"
				fs.f.p = p_let
				fs.f.v = L.star_vel(B, t0)
				fs.f.orbit_r = -1.0
				fs.f.coast = 0.0
			else:
				fs.settle_at(t0, p_let, -1.0)
			var t := t0
			var at := -1.0
			for k in int(20.0 / dt):
				if fs.star_orbiting():
					at = t - t0
					break
				t = t0 + float(k + 1) * dt
				fs.step(dt, t, NONE)
			n.settle = int(n.settle) + 1
			if at < 0.0 or int(fs.f.cen_id) != B:
				rows.append("A CARRIED SETTLE (%s) in %s: %s, round %d, %.2f px from it (want %.2f, let go at %.2f), moving %.2f px/s against it, %s" % [how, key, "settled at %.1f s" % at if at >= 0.0 else "NOT SETTLED in 20 s", int(fs.f.cen_id),
					((fs.f.p as Vector2) - (fs.f.cen as Vector2)).length(), float(fs.f.r_want), r_set, ((fs.f.v as Vector2) - L.star_vel(B, t)).length(), fs.mode])
				continue
			var w_s := 0.0
			var w_c := 0.0
			var t1 := t
			var off_orbit := false
			# Let go counts from SETTLE_HOLD, with up to
			# SETTLED_DV motion left; put there from frame one.
			var from_k := int(SETTLE_HOLD / dt) if how == "let go" else 0
			for k2 in int(ORBIT_S / dt) + from_k:
				t = t1 + float(k2 + 1) * dt
				fs.step(dt, t, NONE)
				if not fs.star_orbiting() or int(fs.f.cen_id) != B:
					off_orbit = true
					break
				if k2 < from_k:
					continue
				var sb := L.star_pos(B, t)
				w_s = maxf(w_s, absf(((fs.f.p as Vector2) - sb).length() - float(fs.f.orbit_r)))
				w_c = maxf(w_c, ((fs.f.cen as Vector2) - sb).length())
			worst.settle = maxf(float(worst.settle), w_s)
			worst.cen = maxf(float(worst.cen), w_c)
			if not off_orbit and w_s < ShipFlightS.SETTLED_PX and w_c < 0.01:
				n.settle_ok = int(n.settle_ok) + 1
				settled.append([fs, t])
			else:
				rows.append("A CARRIED SETTLE (%s) in %s: %s, off its radius round star B by %.3f px at worst (SETTLED_PX %.1f), its centre %.4f px off the sun" % [how, key, "LEFT IT" if off_orbit else "held", w_s, ShipFlightS.SETTLED_PX, w_c])
		if not settled.is_empty():
			var fs1 = settled[0][0]
			var tp: float = settled[0][1]
			# PARKED AND PUT BACK across a reopened map
			var e := {"at": -9, "p": fs1.f.p, "v": fs1.f.v, "head": fs1.f.head, "mode": &"free",
				"cen": int(fs1.f.cen_id), "r": float(fs1.f.orbit_r), "sense": float(fs1.f.sense)}
			var rel_park: Vector2 = (fs1.f.p as Vector2) - L.star_pos(B, tp)
			for how2: String in ["at the kept clock", "through the save's rows", "the clock run on 5 s without it"]:
				var d := e
				var tb := tp
				if how2 == "through the save's rows":
					var was_p: Dictionary = SystemMapScreen._parked
					var was_c: Dictionary = Run.map_clock
					SystemMapScreen._parked = {idx: e}
					Run.map_clock = {idx: tp}
					var raw = JSON.parse_string(JSON.stringify(SaveGame._parked_to()))
					var raw_c = JSON.parse_string(JSON.stringify(SaveGame._clocks_to()))
					var back := SaveGame._parked_from(raw, Run.map.size())
					Run.map_clock = SaveGame._clocks_from(raw_c, Run.map.size())
					d = back.get(idx, {})
					tb = Run.map_t(idx)
					SystemMapScreen._parked = was_p
					Run.map_clock = was_c
				elif how2 == "the clock run on 5 s without it":
					tb = tp + 5.0
				var fp = _flight_script.new()
				fp.setup(L, Vector2(L.edge, -210.0), tb)
				fp.restore_free(tb, d.get("p", Vector2.ZERO), d.get("v", Vector2.ZERO), float(d.get("head", PI)),
					int(d.get("cen", -99)), float(d.get("r", -1.0)), float(d.get("sense", 0.0)))
				var rel_back: Vector2 = (fp.f.p as Vector2) - L.star_pos(B, tb)
				var off_r0 := absf(rel_back.length() - float(e.r))
				# At the kept clock the very spot; with the
				# clock run on, no further than its sun moved.
				var moved_b := (L.star_pos(B, tb) - L.star_pos(B, tp)).length()
				var off_at := (rel_back - rel_park).length() if how2 != "the clock run on 5 s without it" else maxf(0.0, ((fp.f.p as Vector2) - (e.p as Vector2)).length() - moved_b)
				var w_p := 0.0
				var gone := false
				var t := tb
				for k3 in int(30.0 / dt):
					t = tb + float(k3 + 1) * dt
					fp.step(dt, t, NONE)
					if not fp.star_orbiting() or int(fp.f.cen_id) != B:
						gone = true
						break
					w_p = maxf(w_p, absf(((fp.f.p as Vector2) - L.star_pos(B, t)).length() - float(e.r)))
				worst.park = maxf(float(worst.park), maxf(w_p, off_r0))
				n.park = int(n.park) + 1
				if not gone and absf(tb - (tp if how2 != "the clock run on 5 s without it" else tp + 5.0)) < 1e-6 and off_r0 < ShipFlightS.SETTLED_PX and off_at < 0.5 and w_p < ShipFlightS.SETTLED_PX:
					n.park_ok = int(n.park_ok) + 1
				else:
					rows.append("PUT BACK round star B (%s) in %s: at t %.2f (parked at %.2f), %.3f px off its radius, %.3f px from where it was round its sun, %s 30 s on (off its radius by %.3f at worst)" % [how2, key, tb, tp, off_r0, off_at, "LEFT IT" if gone else "held", w_p])
		if wb >= 0:
			L.bodies[wb].world = hid
		# A PREVIEW ROUND B, takeable and replayed on
		var tgts: Array[int] = [-1]
		var w_a := -1
		var w_both := -1
		for b2 in L.bodies:
			if b2.world == &"":
				continue
			if b2.host_id == -1 and w_a < 0:
				w_a = b2.index
			elif b2.host_id == -9 and w_both < 0:
				w_both = b2.index
		for wi: int in [w_a, wb, w_both]:
			if wi >= 0:
				tgts.append(wi)
		for i: int in tgts:
			var fv = _flight_script.new()
			fv.setup(L, Vector2(L.edge, -210.0), t0)
			fv.settle_at(t0, p_let, 1.0)
			_hold_off(fv, wb)
			fv.step(dt, t0 + dt, NONE)
			var tv0 := t0 + dt
			if fv.orbit_body() == i or not fv.can_fly() or int(fv.f.cen_id) != B:
				continue
			var pv = fv.make_plan(i, tv0, {}, ShipFlightS.PREVIEW_AHEAD)
			n.pv = int(n.pv) + 1
			if pv == null or pv.res == null:
				rows.append("A PREVIEW ROUND B in %s to %d: %s" % [key, i, "none planned" if pv == null else "today's planner's"])
				continue
			var take_ok := true
			var replay_ok := true
			var why := ""
			var t := tv0
			# A quarter second and a second on, or the last
			# frame the overlay keeps a preview before departure.
			var k_late := clampi(int(floorf((float(pv.t0) - ShipFlightS.PLAN_AHEAD - tv0) / dt)), 15, 60)
			for k4 in k_late:
				t = tv0 + float(k4 + 1) * dt
				fv.step(dt, t, NONE)
				if k4 + 1 == 15 or k4 + 1 == k_late:
					if fv._takeable(pv, t).is_empty():
						take_ok = false
						why += " not takeable %.2f s on;" % (t - tv0)
					var rp = fv.make_plan(i, t, pv.choice)
					if rp != null and rp.res != null and _gave_way(pv.res, rp.res):
						n.pv_gave = int(n.pv_gave) + 1
					elif rp == null or rp.res == null or rp.res.kind != &"replay" or rp.res.samp != pv.res.samp:
						replay_ok = false
						why += " rebuilt %.2f s on as %s;" % [t - tv0, "nothing" if rp == null or rp.res == null else String(rp.res.kind)]
			if take_ok:
				n.pv_take = int(n.pv_take) + 1
			if replay_ok:
				n.pv_replay = int(n.pv_replay) + 1
			# THE CLICK a quarter second on, on the drawn flight
			var fc = _flight_script.new()
			fc.setup(L, Vector2(L.edge, -210.0), t0)
			fc.settle_at(t0, p_let, 1.0)
			_hold_off(fc, wb)
			fc.step(dt, tv0, NONE)
			var tcl := tv0
			for k5 in 15:
				tcl = tv0 + float(k5 + 1) * dt
				fc.step(dt, tcl, NONE)
			var fm := _fly(fc, i, tcl, pv)
			var fly_ok: bool = fm.same and fm.landed and float(fm.off) <= _drawn_px(fm) and not fm.snap and float(fm.jump) <= _jump_px(fm)
			if fly_ok:
				n.pv_fly = int(n.pv_fly) + 1
			else:
				why += " clicked a quarter second on: %s, %s, %.2f px off the drawn line%s, the most in a frame %.1f px;" % ["the drawn flight" if fm.same else "PLANNED AGAIN", "landed" if fm.landed else "NOT LANDED", fm.off, ", A SNAP" if fm.snap else "", fm.jump]
			if why != "":
				rows.append("A PREVIEW ROUND B in %s to %d:%s" % [key, i, why])
		# THE EDGE AS ARRIVED, the pair at eight angles a lap apart
		var lap := TAU / L.pair_n if L.pair_n != 0.0 else 1200.0
		var places: Array[int] = []
		for s in L.stars():
			places.append(s)
		for b3 in L.bodies:
			places.append(b3.index)
		for ph in 8:
			var tk := t0 + lap * float(ph) / 8.0
			for i2: int in places:
				var fe = _flight_script.new()
				fe.setup(L, Vector2(L.edge, -210.0), tk)
				fe.step(dt, tk, NONE)
				if not fe.can_fly() or fe.orbit_body() == i2:
					continue
				n.edge = int(n.edge) + 1
				var where := "%s, the pair at %d/8 of a lap (t %.0f), the edge -> %d" % [key, ph, tk, i2]
				var pl = fe.make_plan(i2, tk, {}, ShipFlightS.PREVIEW_AHEAD)
				if pl == null or pl.res == null or not pl.res.clean:
					rows.append("THE EDGE: %s: %s" % [where, "none" if pl == null else ("today's planner's" if pl.res == null else "unclean, %.2f px in" % -pl.res.clear)])
					if pl == null:
						continue
				else:
					n.edge_found = int(n.edge_found) + 1
				var round_b: bool = i2 == B or (i2 >= 0 and L.bodies[i2].host_id == B)
				if pl.res != null:
					# (where it ends against where the ship's own `center` puts the
					# place then, as the sweep holds it to END_PX)
					var ce: Vector3 = fe.center(i2, float(pl.end.t))
					var arl: Vector2 = pl.end.arel
					var ep: Vector3 = pl.end.p
					var de := Vector2(ce.x + arl.x - ep.x, ce.z + arl.y - ep.z).length()
					n.edge_end = maxf(float(n.edge_end), de)
					if de > END_PX:
						rows.append("THE EDGE: %s: ends %.3f px off where its place is then" % [where, de])
				var fm2 := _fly(fe, i2, tk, pl)
				if fm2.landed:
					n.edge_landed = int(n.edge_landed) + 1
				else:
					rows.append("THE EDGE: %s: NOT LANDED (mode %s)" % [where, fm2.mode_end])
				if fm2.same and float(fm2.off) <= _drawn_px(fm2):
					n.edge_drawn = int(n.edge_drawn) + 1
				elif pl.res != null:
					rows.append("THE EDGE: %s: %s, %.2f px off the drawn line" % [where, "flew the drawn flight" if fm2.same else "PLANNED AGAIN", fm2.off])
				worst.edge_off = maxf(float(worst.edge_off), float(fm2.off))
				worst.jump = maxf(float(worst.jump), float(fm2.jump))
				if float(fm2.jump) > _jump_px(fm2):
					n.edge_jumps = int(n.edge_jumps) + 1
					rows.append("THE EDGE: %s: MOVED %.1f px IN A FRAME" % [where, fm2.jump])
				if fm2.snap:
					n.edge_snaps = int(n.edge_snaps) + 1
					rows.append("THE EDGE: %s: A SNAP, %.1f px/s in a frame (%s)" % [where, fm2.frame_dv, fm2.mode])
				if round_b and fm2.landed and pl.res != null:
					# ON ITS RING round where B (or its world) is, with no insertion
					# flown (`_land`: a solved flight lands on the ring exactly)
					n.on_b = int(n.on_b) + 1
					var c_b := _where_drawn(L, i2, tk + float(fm2.secs))
					var off_b := absf(((fe.f.p as Vector2) - c_b).length() - float(fe.orbit_r(i2)))
					worst.on_b = maxf(float(worst.on_b), off_b)
					if off_b <= ShipFlightS.ON_RING_PX and not bool(fm2.inserted):
						n.on_b_ok = int(n.on_b_ok) + 1
					else:
						rows.append("THE EDGE: %s: landed %.4f px off its ring round B%s" % [where, off_b, ", AN INSERTION FLOWN" if bool(fm2.inserted) else ""])
	print("flighttest: the turning pair (%d systems, %d of them close pairs; the pair at %.1fx Kepler): carried rails %d of %d held for %.0f s (off the radius at worst %.4f px, the motion off its velocity %.2f px/s; the place carried at least %.1f px); carried settles round star B %d of %d within %.1f px (at worst %.3f, the centre %.4f px off its sun); put back round B %d of %d (off its radius at worst %.3f px); previews round B: %d planned, %d takeable a quarter second and a second on, %d rebuilt as the same flight then (%d of those moments a flight the fallback found giving way to a fresh one arriving sooner), %d clicked, flown as drawn and landed; the edge as arrived at eight angles of the pair: %d of %d found and clean, ending at worst %.4f px off its place, %d landed, %d on the drawn line (worst %.2f px), %d snaps, %d jumps (the most in a frame %.1f px); %d of %d landings round B on the ring with no insertion (worst %.4f px)" % [
		seen.size(), int(by_kind.get("close", 0)), SystemLayout.pair_speed(), n.rail_ok, n.rail, ORBIT_S, worst.rail, worst.rail_v, worst.moved,
		n.settle_ok, n.settle, ShipFlightS.SETTLED_PX, worst.settle, worst.cen, n.park_ok, n.park, worst.park,
		n.pv, n.pv_take, n.pv_replay, n.pv_gave, n.pv_fly, n.edge_found, n.edge, n.edge_end, n.edge_landed, n.edge_drawn, worst.edge_off, n.edge_snaps, n.edge_jumps, worst.jump, n.on_b_ok, n.on_b, worst.on_b])
	for r in rows.slice(0, 40):
		print("    " + r)
	var any: bool = seen.size() > 0
	h._ok("the turning pair: a carried rail round star B and round its world holds its radius from where it is drawn for %.0f s (%d of %d)" % [ORBIT_S, n.rail_ok, n.rail], any and n.rail_ok == n.rail and int(n.rail) > 0)
	h._ok("the turning pair: let go or put round star B it settles round B and keeps its radius within %.1f px of the moving sun (%d of %d)" % [ShipFlightS.SETTLED_PX, n.settle_ok, n.settle], any and n.settle_ok == n.settle and int(n.settle) > 0)
	h._ok("the turning pair: parked round star B and put back across a reopened map, at the kept clock, through the save's rows and with the clock run on, it is on its orbit round B (%d of %d)" % [n.park_ok, n.park], any and n.park_ok == n.park and int(n.park) > 0)
	h._ok("the turning pair: a preview round star B still takeable a quarter second and a second on (%d of %d), rebuilt from its choice as the same flight (%d of %d), clicked and flown as drawn (%d of %d)" % [n.pv_take, n.pv, n.pv_replay, n.pv, n.pv_fly, n.pv],
		any and int(n.pv) > 0 and n.pv_take == n.pv and n.pv_replay == n.pv and n.pv_fly == n.pv)
	var share := float(n.edge_found) / float(maxi(int(n.edge), 1))
	h._ok("the turning pair: from the edge as arrived at eight angles of the pair, found and clean %d of %d (%.1f%%, at least %.0f%%), each ending where its place is then (worst %.4f px, at most %.2f), every one landed (%d), on the drawn line (%d), no snap (%d) and no jump (%d), every landing round B on its ring with no insertion (%d of %d)" % [n.edge_found, n.edge, share * 100.0, FOUND_MIN * 100.0, n.edge_end, END_PX, n.edge_landed, n.edge_drawn, n.edge_snaps, n.edge_jumps, n.on_b_ok, n.on_b],
		any and int(n.edge) > 0 and share >= FOUND_MIN and float(n.edge_end) <= END_PX and n.edge_landed == n.edge and n.edge_drawn == n.edge_found and int(n.edge_snaps) == 0 and int(n.edge_jumps) == 0 and n.on_b_ok == n.on_b)


## A fallback flight may give way to a fresh one-leg
## flight arriving sooner (ruling 21); two-leg not yet.
## Why: docs/why/FlightTest.md#giving-way
static func _gave_way(r: FlightSolve.Result, r2: FlightSolve.Result) -> bool:
	return r.legs == 1 and float(r.choice.get("cap", 0.0)) > FlightSolve.first_cap(r.path) + 1e-6 and r2.found and r2.clean and r2.legs == 1 and r2.kind == &"solved" and float(r2.end.t) < float(r.end.t) - 1e-6


## Where place i is drawn at time t: the layout's answer,
## not the flight's `center`, which the rail rides.
static func _where_drawn(L: SystemLayout, i: int, t: float) -> Vector2:
	if SystemLayout.is_star(i):
		return L.star_pos(i, t)
	return L.bodies[i].pos(t)


## A radius round star B in its steady zone and past
## STAR_ORBIT_GAP; just outside it in a close pair.
func _settle_r(L: SystemLayout) -> float:
	var B := SystemLayout.STAR_B
	var lo := L.star_ring_of(B) + ShipFlightS.STAR_ORBIT_GAP + 2.0
	var hi := SystemLayout.s_limit(L.star_share) * L.sep - 2.0
	if hi < lo:
		return lo
	return (lo + hi) * 0.5


## The ring of world wb lets this ship go for the measure (`no_cap_body`, held
## for good): a settle round its sun is flown, not that world's capture.
static func _hold_off(fl, wb: int) -> void:
	if wb >= 0:
		fl.f.no_cap_body = wb
		fl.f.no_cap_left = 1e9


func _report(cap: Dictionary) -> void:
	var tot_plans := 0
	var keys: Array = []
	for p in _paths:
		for b0: String in ["one", "giant", "twin", "close"]:
			keys.append([b0 + ("" if p == &"direct" else " curved"), b0, p])
	for kq: Array in keys:
		var sweep: String = kq[0]
		var base: String = kq[1]
		if not _sw.has(sweep):
			continue
		var S: Dictionary = _sw[sweep]
		var plans: int = S.plans
		tot_plans += plans
		var ok_n: int = S.clean
		print("flighttest: %s: %d systems, %d plans: %d solved (%d clean), %d by today's planner, %d none; %d flown, %d landed" % [sweep, S.systems, plans, S.solved, S.clean, S.fallback, S.none, S.flown, S.landed])
		var bsl := PackedStringArray()
		for k in S.by_start:
			bsl.append("%s %d/%d (clean %d)" % [k, S.by_start[k].found, S.by_start[k].plans, S.by_start[k].clean])
		print("  found by start: %s" % ", ".join(bsl))
		print("  planning (this thread) ms: %s" % _dist(S.ms))
		print("  flight time from the plan, s: %s; its ride first, s: %s" % [_dist(S.T), _dist(S.lead)])
		print("  engine work, px/s: %s" % _dist(S.work))
		print("  click to settled, s: from the game's starts %s; place to place %s; in two legs %s" % [_dist(S.click_game), _dist(S.click_place), _dist(S.click_two)])
		print("  FAST (%s at pace %.1f): click to settled, real s: the game's starts %s; from the edge as arrived (a jump's first) %s; bend %s; turn deg %s; to today's planner %d" % [kq[2], S.pace, _dist(S.click_game), _dist(S.click_edge), _dist(S.bend), _dist(S.turn), S.old_n])
		print("  the wait before it leaves (the click to the frame it flies, the game's starts), real s: %s" % _dist(S.click_dep))
		if float(S.pace) == float(ShipFlightS.FLIGHT_PACE[kq[2]]) and not (S.click_game as Array).is_empty():
			var cg: Array = (S.click_game as Array).duplicate()
			cg.sort()
			var med: float = cg[cg.size() / 2]
			var p90: float = cg[mini(cg.size() - 1, int(cg.size() * 0.9))]
			var lm: float = CLICK_MED[kq[2]]
			var lp: float = CLICK_P90[kq[2]]
			var le: float = CLICK_EDGE[kq[2]]
			h._ok("%s: click to settled at pace %.0f, median %.2f s (at most %.1f), 90th %.2f s (at most %.1f)" % [sweep, S.pace, med, lm, p90, lp], med <= lm and p90 <= lp)
			if not (S.click_edge as Array).is_empty():
				var ce: Array = (S.click_edge as Array).duplicate()
				ce.sort()
				h._ok("%s: a jump's first flight (from the edge as arrived), median %.2f s (at most %.1f)" % [sweep, float(ce[ce.size() / 2]), le], float(ce[ce.size() / 2]) <= le)
		print("  closest to a star's surface %.1f px; least margin to a keep-out %.2f px; closest to a world's disc %.1f px; top speed %.0f px/s" % [S.star, S.keep, S.world, S.speed])
		print("  sharpest turn of the drawn path, deg per px: zoom 1 %s; zoom 2 %s" % [_dist(S.turn1), _dist(S.turn2)])
		print("  corners (over %.0f deg/px in 2 px) in solved flights: zoom 1 %d, zoom 2 %d (from the game's starts %d, %d); and %d on a ring's own curve only (a ring drawn so small its ends turn that fast)" % [CORNER, S.corners1, S.corners2, S.game_corners1, S.game_corners2, S.ring_corners])
		print("  clicks: %d, %d flew the drawn flight; drawn against flown, px: %s; the drawn flight planned again before the click %d times; planned again AT the click (it left late, `ShipFlight.CLICK_LATE`) %d" % [S.clicks, S.drawn, _dist(S.drawn_px), S.redrawn, int(S.get("click_redrawn", 0))])
		print("  flown: biggest frame-to-frame change of velocity %.1f px/s, %.1fx its neighbours; snaps %d; the nose's biggest turn in a frame %.1f deg" % [S.frame_dv, S.frame_ratio, S.snaps, S.nose])
		if int(S.unflyable) > 0:
			print("  starts the first frame took onto a ring or alongside (no flight can leave there, not planned): %d" % S.unflyable)
		for l in (S.not_found as Array).slice(0, 40):
			print("    not found: %s" % l)
		for l2 in (S.not_landed as Array).slice(0, 12):
			print("    NOT LANDED: %s" % l2)
		for l3 in (S.cornered as Array).slice(0, 24):
			print("    CORNER: %s" % l3)
		for l4 in S.snapped:
			print("    SNAP: %s" % l4)
		for l5 in S.off_drawn:
			print("    NOT THE DRAWN FLIGHT: %s" % l5)
		# Judge flights the game can start, from an orbit
		# (Jon: be in an orbit, then click); free starts apart.
		# Why: docs/why/FlightTest.md#judged-flights
		var g_n := 0
		var g_ok := 0
		var f_n := 0
		var f_ok := 0
		for k in S.by_start:
			if k == "free" or k == "near":
				f_n += int(S.by_start[k].plans)
				f_ok += int(S.by_start[k].clean)
			else:
				g_n += int(S.by_start[k].plans)
				g_ok += int(S.by_start[k].clean)
		print("  found and clean: from the game's starts %d of %d; flying free or close by (a harness's) %d of %d" % [g_ok, g_n, f_ok, f_n])
		var share := float(g_ok) / float(maxi(g_n, 1))
		h.total("%s: found and clean" % sweep, "%s: found and clean from an orbit, a star orbit or alongside %d of %d (%.2f%%, at least %.0f%%)" % [sweep, g_ok, g_n, share * 100.0, FOUND_MIN * 100.0],
			"g_n > 0 and float(g_ok) / float(maxi(g_n, 1)) >= FOUND_MIN", {"g_ok": g_ok, "g_n": g_n, "FOUND_MIN": FOUND_MIN})
		# (a count of flights each judged on its own: none in any shard is none
		# in all, so each shard judges its own; the least margin is its shard's)
		h._ok("%s: every clean flight clear of MapGravity's keep-outs at each sample's own time, within %.0f px (%d inside; least margin %.2f px)" % [sweep, IN_PX, S.in_clean, S.in_worst], int(S.in_clean) == 0)
		print("  farthest any solved flight goes from star A: %.2f of the edge" % S.far)
		if int(S.chained) > 0 or base == "twin" or base == "close":
			print("  flights in two legs (FlightSolve._chain, where one leg reaches nothing): %d; flight time %s s; planned (this thread) %s ms; the second leg off the first's coast, s on: %s; out to %.2f of the edge at the farthest" % [S.chained, _dist(S.chain_T), _dist(S.chain_ms), _dist(S.chain_cut), S.chain_far])
			for l6 in S.chain_list:
				print("    TWO LEGS: %s" % l6)
		if base == "twin" or base == "close":
			# In a twin no flight may be put there: 63 of 1,790
			# before two-leg flights, 18 from game starts.
			# Why: docs/why/FlightTest.md#put-there
			var excused := 0
			var game := 0
			var unnamed := 0
			var named: Array = PUT_LEFT_CASES.get(base, [])
			for e7: Array in S.put:
				var harness7 := String(e7[2]) == "free" or String(e7[2]) == "near"
				var ok7 := harness7 and float(e7[1]) < CLEAR_S
				var why7 := " (no flight can leave)"
				if not harness7:
					game += 1
					why7 = " (A GAME'S START)"
				elif ok7:
					excused += 1
				else:
					why7 = " (THE RESIDUAL)"
					if not named.has(e7[3]):
						unnamed += 1
						why7 = " (THE RESIDUAL, NOT A NAMED START)"
				print("    PUT THERE: %s; the best burn from there keeps clear for %.2f s%s" % [e7[0], e7[1], why7])
			h._ok("%s: no flight put there from the game's starts (%d)" % [sweep, game], game == 0)
			var left: int = (S.put as Array).size() - excused - game
			var most := PUT_LEFT_CLOSE if base == "close" else PUT_LEFT
			# The residual against its limit is summed across
			# shards; each start is named or not on its own.
			h.total("%s: put there" % sweep, "%s: no flight put there from a harness's start (%d of %d plans) but where no burn at THRUST keeps clear of a keep-out for %.1f s (%d of them), and the measured residual from the named starts %s, at most %d (%d, %d from another start)" % [sweep, (S.put as Array).size() - game, plans, CLEAR_S, excused, ", ".join(PackedStringArray(named)), most, left, unnamed],
				"left <= MOST and unnamed == 0", {"left": left, "unnamed": unnamed, "MOST": most})
		h._ok("%s: every planned flight landed (%d of %d)" % [sweep, S.landed, S.flown], int(S.landed) == int(S.flown))
		# From a free start a burn across a near-still ship draws a hook: printed, not judged.
		h._ok("%s: no corner in the drawn path of a solved flight from an orbit, a star orbit or alongside (zoom 1 %d, zoom 2 %d)" % [sweep, S.game_corners1, S.game_corners2], int(S.game_corners1) == 0 and int(S.game_corners2) == 0)
		h._ok("%s: no snap in a flown frame (%d)" % [sweep, S.snaps], int(S.snaps) == 0)
		h._ok("%s: every solved flight ends where the ship's own centre puts its place, a belt's beacon round its host among them (%d), within %.2f px (worst %.4f)" % [sweep, S.belt_ends, END_PX, S.end_off], float(S.end_off) <= END_PX)
		var off_ok := true
		for x in S.drawn_px:
			if float(x) > DRAWN_PX:
				off_ok = false
		h._ok("%s: every click flew the drawn flight (%d of %d), within %.1f px" % [sweep, S.drawn, S.clicks, DRAWN_PX], int(S.drawn) == int(S.clicks) and off_ok)
	for ck: String in _cat:
		var c: Dictionary = _cat[ck]
		var r1: Array = c.r1
		var r2: Array = c.r2
		r1.sort()
		r2.sort()
		var sbt := 0
		for x in c.s:
			sbt += int(x)
		var at_ := 0
		for x2 in c.arr:
			at_ += int(x2)
		var sw: Array = c.sw
		sw.sort()
		var loops := sw.filter(func(x: float) -> bool: return x > 300.0).size()
		print("  %-32s %4d flights: tightest bend (radius, screen px) at zoom 1 median %.0f, worst %.1f; zoom 2 median %.0f, worst %.1f; corners %d / %d; S-bends %d, arriving %d; lobes %d; time %s s" % [ck, c.n,
			r1[r1.size() / 2], r1[0], r2[r2.size() / 2], r2[0], c.c1, c.c2, sbt, at_, loops, _dist(c.dur)])
	print("  S-bends by where: %s" % _s_where)
	print("  fallbacks: %d to today's planner, %d none (the ship put there) of %d plans" % [ShipFlightS.n_fallback, ShipFlightS.n_none, tot_plans])
	print("flighttest: captures, a slow ship let go inside a place's ring: one star %d of %d held by two rings or more, %d of them taken elsewhere by the new rule (the place the line goes into, else the nearest; it was the first world by index); two suns %d of %d, %d" % [cap.one[0], cap.one[2], cap.one[1], cap.twin[0], cap.twin[2], cap.twin[1]])
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"sweeps": _sw, "cap": cap}))
		f.close()


## THE DRAWN LINE'S AND A FRAME'S TOLERANCES FOR A FLIGHT ON ITS OWN CLOCK
## (`fm.pace`, the fast transfers, Nov 5): a frame's timing against the
## samples is pace times as far along a flight pace times as fast, so the
## drawn line's DRAWN_PX holds to pace 4 and grows with it past that, and a
## frame may move JUMP_PX x pace.
static func _drawn_px(fm: Dictionary) -> float:
	return DRAWN_PX * maxf(1.0, float(fm.get("pace", 1.0)) / 4.0)


static func _jump_px(fm: Dictionary) -> float:
	return JUMP_PX * maxf(1.0, float(fm.get("pace", 1.0)))


## Median, 90th, 99th and worst of a list of numbers, as one string.
static func _dist(xs: Array) -> String:
	if xs.is_empty():
		return "(none)"
	var s := xs.duplicate()
	s.sort()
	var n := s.size()
	return "median %.2f, 90th %.2f, 99th %.2f, worst %.2f (%d)" % [float(s[n / 2]), float(s[mini(n - 1, int(n * 0.9))]), float(s[mini(n - 1, int(n * 0.99))]), float(s[n - 1]), n]


## The drawn line held while the ship rides its orbit: the median of each flight's biggest move in
## half a second at most twice today's (8.11 px). Nov 5: DIRECT 11.7, CURVED 29.0. Left failing for Jon.
## Why: docs/why/FlightTest.md#drawn-line-held
const MOVE_MED := 16.0


## Counts frames where a flight could start but should not (Jon: be in an orbit, then click).
## Why: docs/why/FlightTest.md#retarget
func _run_retarget() -> void:
	Rng.forced = 4242 if _one_seed < 0 else _one_seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var none := NONE
	var dt := 1.0 / 60.0
	var tot := {"tries": 0, "none": 0, "bad": 0, "landed": 0, "early": 0, "frames": 0, "late": 0}
	var moves: Array = []
	var wides: Array = []
	var turns_r: Array = []
	var sbs := 0
	var lobes := 0
	var shown := 0
	var systems := 0
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM and n.type != MapGen.NodeType.PULSAR and n.type != MapGen.NodeType.STATION:
			continue
		if systems >= 40:
			break
		systems += 1
		OptionTable.ensure(n)
		var L := SystemLayout.of(n)
		var worlds: Array = []
		for b in L.bodies:
			if b.world != &"":
				worlds.append(b.index)
		if worlds.size() < 2:
			continue
		var t0 := 40.0 + float(n.index % 17) * 13.0
		# [start kind, start body, first place, the place chosen on the way]
		var cases: Array = [["orbit", worlds[0], -1, worlds[1]], ["orbit", worlds[0], worlds[1], -1], ["star", 0, worlds[0], worlds[1]],
			["orbit", worlds[0], -1, worlds[0]]]
		for cs: Array in cases:
			var fl = _flight_script.new()
			fl.setup(L, Vector2(-L.edge * 0.95, 0.0), t0)
			_start(fl, L, String(cs[0]), int(cs[1]), t0, n.index)
			fl.step(dt, t0, none)
			var first: int = cs[2]
			var j: int = cs[3]
			var pf = fl.fly(first, t0, func() -> void: pass)
			if pf == null:
				continue
			tot.tries += 1
			var where := "system %d, %s %d -> %d, then %d" % [n.index, cs[0], cs[1], first, j]
			# ON THE WAY: no flight may start until it is settled in its orbit
			var t := t0
			var settled := false
			for _f in int(_fly_max(pf) / dt):
				t += dt
				fl.step(dt, t, none)
				tot.frames += 1
				var on_it: bool = fl.reached() == first
				if fl.can_fly() and not on_it:
					tot.early += 1
					if shown < 12:
						shown += 1
						print("  EARLY: a flight could start in mode %s%s: %s" % [fl.mode, " inserting" if fl.inserting() else "", where])
				if on_it and fl.can_fly():
					settled = true
					break
			if not settled:
				tot.late += 1
				if shown < 12:
					shown += 1
					print("  NEVER SETTLED: %s" % where)
				continue
			if fl.reached() == j:
				tot.landed += 1
				continue
			# SETTLED: the plan to the place chosen on the way, as the map draws it
			# (its preview, made PREVIEW_AHEAD on)
			var pa = fl.make_plan(j, t, {}, ShipFlightS.PREVIEW_AHEAD)
			if pa == null:
				tot.none += 1
				if shown < 12:
					shown += 1
					print("  NONE: %s" % where)
				continue
			var bad := _degenerate(fl, L, pa)
			if bad != "":
				tot.bad += 1
				if shown < 12:
					shown += 1
					print("  DEGENERATE (%s): %s" % [bad, where])
			var r_s := Vector2(fl.where3().x, fl.where3().z).length()
			var ce: Vector3 = fl.center(j, float(pa.end.t))
			var r_t: float = Vector2(ce.x, ce.z).length() if j >= 0 else float(fl.star_ring())
			var rmax := 0.0
			for q9: Vector3 in pa.samp:
				rmax = maxf(rmax, Vector2(q9.x, q9.z).length())
			wides.append(rmax / maxf(maxf(r_s, r_t), 1.0))
			var p3r := PackedVector3Array(pa.samp)
			p3r.append_array(pa.tail)
			var gr: Array = _gait(fl, L, pa, p3r, j, first)
			turns_r.append(gr[2])
			if float(gr[2]) > 300.0:
				lobes += 1
			sbs += int(gr[1]) + int(gr[3])
			# held while it rides its orbit: replanned every half second for 3 s
			var last := _line_px(pa)
			var choice: Dictionary = pa.choice
			var worst := 0.0
			for _h in 6:
				for _s in 30:
					t += dt
					fl.step(dt, t, none)
				var pn = fl.make_plan(j, t, choice, ShipFlightS.PREVIEW_AHEAD)
				if pn == null:
					break
				var cur := _line_px(pn)
				var mv := 0.0
				for q1 in cur:
					var md := INF
					for q0 in last:
						md = minf(md, q1.distance_to(q0))
					mv = maxf(mv, md)
				worst = maxf(worst, mv)
				last = cur
				choice = pn.choice
				pa = pn
			moves.append(worst)
			if worst > 6.0 and shown < 24:
				shown += 1
				print("  MOVED %.1f px in a half second: %s" % [worst, where])
			# and flown from there, the drawn plan as a click flies it
			var ok := false
			var pj = fl.fly(j, t, func() -> void: pass, choice, pa)
			for _k in int(_fly_max(pj) / dt):
				t += dt
				fl.step(dt, t, none)
				if fl.reached() == j:
					ok = true
					break
			if ok:
				tot.landed += 1
			elif shown < 24:
				shown += 1
				print("  NOT LANDED: %s" % where)
	moves.sort()
	wides.sort()
	turns_r.sort()
	print("retarget: %d flights in %d systems, another place chosen on the way: %d frames where a flight could start before the ship was in its orbit (of %d), %d never settled; once settled, %d with no plan, %d degenerate, %d landed" % [tot.tries, systems, tot.early, tot.frames, tot.late, tot.none, tot.bad, tot.landed])
	if not wides.is_empty():
		print("  how far out it swings, against the farther of its two ends: median %.2fx, 90th %.2fx, worst %.2fx; over 1.3x: %d" % [wides[wides.size() / 2], wides[int(wides.size() * 0.9)], wides[-1], wides.filter(func(x: float) -> bool: return x > 1.3).size()])
		print("  turning in all, deg: median %.0f, 90th %.0f, worst %.0f; lobes (over 300) %d; S-bends %d" % [turns_r[turns_r.size() / 2], turns_r[int(turns_r.size() * 0.9)], turns_r[-1], lobes, sbs])
	var move_ok := true
	if not moves.is_empty():
		print("  the drawn plan's biggest move in a half second while it rides its orbit, px: median %.2f, 90th %.2f, worst %.1f; over 6 px: %d" % [moves[moves.size() / 2], moves[int(moves.size() * 0.9)], moves[-1], moves.filter(func(x: float) -> bool: return x > 6.0).size()])
		move_ok = float(moves[moves.size() / 2]) <= MOVE_MED
		print("  %s the drawn plan's median move, %.2f px, at most %.0f (twice today's)" % ["ok  " if move_ok else "FAIL", moves[moves.size() / 2], MOVE_MED])
	var ok_all: bool = tot.early == 0 and tot.late == 0 and tot.none == 0 and tot.bad == 0 and tot.landed == tot.tries and move_ok
	print("retarget: %s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)


## Checks star orbits because the projected path kept updating into weird shapes (Jon).
## Why: docs/why/FlightTest.md#star-ride
func _run_starride() -> void:
	Rng.forced = 4242 if _one_seed < 0 else _one_seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var none := NONE
	var dt := 1.0 / 60.0
	var n_pl := 0
	var kinds := {}
	var swings: Array = []
	var offs: Array = []
	var sb := 0
	var lobes := 0
	var moves: Array = []
	var shown := 0
	var systems := 0
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM and n.type != MapGen.NodeType.PULSAR and n.type != MapGen.NodeType.STATION:
			continue
		if systems >= 30:
			break
		systems += 1
		OptionTable.ensure(n)
		var L := SystemLayout.of(n)
		var t0 := 40.0 + float(n.index % 17) * 13.0
		for b in L.bodies:
			if b.world == &"":
				continue
			for rk: float in [0.35, 0.55, 0.8]:
				for ph in 6:
					var fl = _flight_script.new()
					fl.setup(L, Vector2(-L.edge * 0.95, 0.0), t0)
					var r := lerpf(fl.star_ring() + 40.0, L.edge, rk)
					var a := float(ph) / 6.0 * TAU + float(n.index) * 0.37
					fl.settle_at(t0, _clear_of_worlds(fl, L, Vector2(cos(a), sin(a)) * r, t0))
					fl.step(dt, t0, none)
					if fl.orbit_body() == b.index:
						continue
					var t := t0
					var pl = fl.make_plan(b.index, t)
					if pl == null:
						continue
					n_pl += 1
					kinds[String(pl.kind)] = int(kinds.get(String(pl.kind), 0)) + 1
					var path3 := PackedVector3Array(pl.samp)
					path3.append_array(pl.tail)
					var ga := _gait(fl, L, pl, path3, b.index, -9)
					offs.append(ga[0])
					sb += int(ga[1]) + int(ga[3])
					swings.append(ga[2])
					if float(ga[2]) > 300.0:
						lobes += 1
					var where := "system %d, star orbit r %.0f at %.1f rad -> %d (%s)" % [n.index, r, a, b.index, pl.kind]
					if (float(ga[2]) > 300.0 or int(ga[1]) + int(ga[3]) > 0) and shown < 12:
						shown += 1
						print("  SHAPE: %s, turning %.0f deg, S-bends %d" % [where, ga[2], int(ga[1]) + int(ga[3])])
					# riding on, replanned as the map does
					var last := _line_px(pl)
					var choice: Dictionary = pl.choice
					var worst := 0.0
					for _h in 6:
						for _s in 30:
							t += dt
							fl.step(dt, t, none)
						if not fl.star_orbiting():
							break
						var pn = fl.make_plan(b.index, t, choice)
						if pn == null:
							break
						var cur := _line_px(pn)
						var mv := 0.0
						for q1 in cur:
							var md := INF
							for q0 in last:
								md = minf(md, q1.distance_to(q0))
							mv = maxf(mv, md)
						worst = maxf(worst, mv)
						if mv > 6.0 and shown < 40:
							shown += 1
							print("    moved %.1f: now %s; ship r %.1f" % [mv, pn.kind, fl.f.p.length()])
						last = cur
						choice = pn.choice
					moves.append(worst)
					if worst > 6.0 and shown < 24:
						shown += 1
						print("  MOVED %.1f px in a half second of riding: %s" % [worst, where])
	swings.sort()
	offs.sort()
	moves.sort()
	print("starride: %d plans in %d systems (%s)" % [n_pl, systems, kinds])
	if not swings.is_empty():
		print("  turning in all, deg: median %.0f, 90th %.0f, worst %.0f; lobes (over 300) %d; S-bends %d" % [swings[swings.size() / 2], swings[int(swings.size() * 0.9)], swings[-1], lobes, sb])
		print("  tightest bend away from the rings, px: median %.0f, worst tenth %.0f" % [offs[offs.size() / 2], offs[int(offs.size() * 0.1)]])
		print("  the drawn plan's biggest move in a half second while riding, px: median %.2f, 90th %.2f, worst %.1f; over 6 px: %d" % [moves[moves.size() / 2], moves[int(moves.size() * 0.9)], moves[-1], moves.filter(func(x: float) -> bool: return x > 6.0).size()])
	get_tree().quit()


## What is wrong with a plan's points, if anything: not a number, off the map,
## through a star's disc (where the star is at that sample's moment).
func _degenerate(fl, L: SystemLayout, pl) -> String:
	for kq in pl.samp.size():
		var q: Vector3 = pl.samp[kq]
		var tq: float = float(pl.t0) + kq * pl.sdt
		if is_nan(q.x) or is_nan(q.z) or is_inf(q.x) or is_inf(q.z):
			return "not a number"
		if Vector2(q.x, q.z).length() > L.edge * 1.6:
			return "off the map"
		for s in L.stars():
			if (Vector2(q.x, q.z) - L.star_pos(s, tq)).length() < L.star_radius(s) + 2.0:
				return "through a star"
	for q2: Vector3 in pl.tail:
		if is_nan(q2.x) or is_nan(q2.z):
			return "not a number (insertion)"
	return ""


static func _scr(q: Vector3) -> Vector2:
	return Vector2(q.x, q.z * 0.38 - q.y * 0.925)


## A plan as drawn at zoom 1, every 2 px or so.
func _line_px(pl) -> PackedVector2Array:
	var out := PackedVector2Array()
	var last := Vector2.INF
	var all := PackedVector3Array(pl.samp)
	all.append_array(pl.tail)
	for q: Vector3 in all:
		var sp := _scr(q)
		if last == Vector2.INF or sp.distance_to(last) >= 2.0:
			out.append(sp)
			last = sp
	return out


## A start the game's own bumpers allow: not inside any world's disc (turned
## round the centre until it is clear).
func _clear_of_worlds(fl, L: SystemLayout, p: Vector2, t: float) -> Vector2:
	var c0 := L.bary if L.twin else Vector2.ZERO
	for _k in 36:
		var clear := true
		for b in L.bodies:
			if b.world == &"":
				continue
			var c: Vector3 = fl.center(b.index, t)
			if Vector2(p.x - c.x, p.y - c.z).length() < maxf(b.r, 10.0) + 12.0:
				clear = false
		if clear:
			return p
		p = c0 + (p - c0).rotated(0.17)
	return p


## Sharpest turn as drawn at `zoom`, in degrees per pixel; `skip` marks a ring's own curve.
func _turn_max(p3: PackedVector3Array, zoom: float, skip := PackedByteArray()) -> float:
	var sp := PackedVector2Array()
	for q in p3:
		sp.append(Vector2(q.x, q.z * 0.38 - q.y * 0.925) * zoom)
	var px := PackedVector2Array()
	var pk := PackedByteArray()
	if sp.size() < 2:
		return 0.0
	px.append(sp[0])
	pk.append(skip[0] if not skip.is_empty() else 0)
	var carry := 0.0
	for j in range(1, sp.size()):
		var a := sp[j - 1]
		var b := sp[j]
		var seg := a.distance_to(b)
		var d := 1.0 - carry
		while d <= seg:
			px.append(a.lerp(b, d / seg))
			pk.append(skip[j] if not skip.is_empty() else 0)
			d += 1.0
		carry = seg - (d - 1.0)
	# over 6 px (any tight bend), or over 2 px (a CORNER: the turn all in one
	# pixel -- a smooth curve turns as much a pixel over 2 px as over 6)
	var worst := 0.0
	var w := 3 if not _corner_only else 1
	for k in range(w, px.size() - w):
		if pk[k] == 1:
			continue
		var u := px[k] - px[k - w]
		var v := px[k + w] - px[k]
		if u.length() < float(w) * 0.8 or v.length() < float(w) * 0.8:
			continue
		var tv := rad_to_deg(absf(u.angle_to(v))) / float(2 * w)
		if tv > worst:
			worst = tv
			_worst_px = [k, px.size(), px[k]]
	return worst


## A small ring's own ends turn faster than CORNER (2.5 px at zoom 1), so ring curves are skipped.
## Why: docs/why/FlightTest.md#ring-skips
func _ring_skip(fl, L: SystemLayout, pl, path3: PackedVector3Array, i: int, from_b: int, zoom: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(path3.size())
	var ns: int = pl.samp.size()
	var tiny := func(b: int, R: float) -> bool:
		return b >= -9 and R > 0.0 and 0.38 * 0.38 * R * zoom < 57.2958 / CORNER
	var r_from: float = float(fl.orbit_r(from_b)) if SystemLayout.is_place(from_b) else 0.0
	var r_to: float = float(fl.orbit_r(i)) if SystemLayout.is_place(i) and not fl.is_keep(i) else 0.0
	var skip_from: bool = SystemLayout.is_place(from_b) and tiny.call(from_b, r_from)
	var skip_to: bool = r_to > 0.0 and tiny.call(i, r_to)
	if not skip_from and not skip_to:
		return out
	for k in path3.size():
		var tk: float = float(pl.t0) + minf(k, ns - 1) * pl.sdt
		var q := path3[k]
		if skip_from and k * pl.sdt < float(pl.esc_t) + 1.0:
			var c: Vector3 = fl.center(from_b, tk)
			if Vector2(q.x - c.x, q.z - c.z).length() < r_from * 1.25:
				out[k] = 1
		if skip_to and (k >= ns or (ns - k) * pl.sdt < 1.5):
			var c2: Vector3 = fl.center(i, tk if k < ns else float(pl.end.t) + float(k - ns) / 120.0 * ShipFlightS.TAIL_S)
			if Vector2(q.x - c2.x, q.z - c2.z).length() < r_to * 1.25:
				out[k] = 1
	return out


## Grace at zoom 1: the tightest bend radius away from the rings, and the count of S-bends.
func _gait(fl, L: SystemLayout, pl, path3: PackedVector3Array, i: int, from_b: int) -> Array:
	var sp := PackedVector2Array()
	var keep := PackedByteArray()
	var ns: int = pl.samp.size()
	for k in path3.size():
		var q := path3[k]
		sp.append(Vector2(q.x, q.z * 0.38 - q.y * 0.925))
		var tk: float = float(pl.t0) + minf(k, ns - 1) * pl.sdt
		var near := false
		var near_to := false
		for b in [i, from_b]:
			if b >= 0 and L.bodies[b].world != &"":
				var c: Vector3 = fl.center(b, tk)
				if Vector2(q.x - c.x, q.z - c.z).length() < float(fl.approach_r(b)) * 1.4:
					near = true
					if b == i:
						near_to = true
		# (the target star where it is at the sample's moment)
		if SystemLayout.is_star(i) and (Vector2(q.x, q.z) - L.star_pos(i, tk)).length() < float(fl.star_ring(i)) + 30.0:
			near = true
			near_to = true
		# 2: coming in to the place (its arrival, apart); 0: leaving the one it left
		keep.append(2 if near_to else (0 if near else 1))
	# THE ARRIVAL is from the last time it comes near the place on: passing it
	# earlier (leaving near it) is the flight, measured as the flight
	var last_in := keep.size()
	for k in range(keep.size() - 1, -1, -1):
		if keep[k] != 2:
			break
		last_in = k
	for k in last_in:
		if keep[k] == 2:
			keep[k] = 1
	# resample to 1 px, carrying the keep flag
	var px := PackedVector2Array()
	var pk := PackedByteArray()
	var src := PackedInt32Array()
	px.append(sp[0])
	pk.append(keep[0])
	src.append(0)
	var carry := 0.0
	for j in range(1, sp.size()):
		var a := sp[j - 1]
		var b2 := sp[j]
		var seg := a.distance_to(b2)
		var d := 1.0 - carry
		while d <= seg:
			px.append(a.lerp(b2, d / seg))
			pk.append(keep[j])
			src.append(j)
			d += 1.0
		carry = seg - (d - 1.0)
	var tight := INF
	var swing := 0.0
	var turns := PackedFloat32Array()
	turns.resize(px.size())
	for k in range(3, px.size() - 3):
		var u := px[k] - px[k - 3]
		var v := px[k + 3] - px[k]
		if u.length() < 2.4 or v.length() < 2.4:
			continue
		var tv := u.angle_to(v) / 6.0
		turns[k] = tv
		if pk[k] == 1 and absf(tv) > 1e-4:
			tight = minf(tight, 1.0 / absf(tv))
		if pk[k] == 1:
			swing += absf(tv)
	var sbends := 0
	var last_sign := 0
	var last_at := -999
	var k2 := 3
	while k2 < px.size() - 3:
		var tv2: float = turns[k2]
		if pk[k2] == 1 and absf(tv2) > 1.0 / 40.0:
			var sg := 1 if tv2 > 0.0 else -1
			if last_sign != 0 and sg != last_sign and k2 - last_at < 30:
				sbends += 1
				var sjw: int = src[k2]
				var wh := "insertion"
				if sjw < ns:
					var tw: float = sjw * pl.sdt
					wh = "leaving" if tw < float(pl.esc_t) + 1.0 else ("arriving" if tw > float(pl.dur) - 1.4 else "coast")
				_s_where[wh] = int(_s_where.get(wh, 0)) + 1
				if _why != "":
					var sj: int = src[k2]
					print("    S-bend at %s; bend radius %.0f px" % [("the insertion (tail %d of %d)" % [sj - ns, path3.size() - ns]) if sj >= ns else ("the flight at %.2f s of %.2f (escape %.2f, burning %s)" % [sj * pl.sdt, pl.dur, pl.esc_t, pl.burns[sj] == 1]), 1.0 / absf(tv2)])
				last_sign = 0
				k2 += 30
				continue
			last_sign = sg
			last_at = k2
		k2 += 1
	# ARRIVING: the same test where it comes in to the place -- an overshoot and
	# hook back reads as a bend one way then hard the other
	var arr_s := 0
	var ls2 := 0
	var la2 := -999
	var k3 := 3
	while k3 < px.size() - 3:
		var tv3: float = turns[k3]
		if pk[k3] == 2 and absf(tv3) > 1.0 / 40.0:
			var sg3 := 1 if tv3 > 0.0 else -1
			if ls2 != 0 and sg3 != ls2 and k3 - la2 < 30:
				arr_s += 1
				if _why != "":
					var sj3: int = src[k3]
					print("    ARRIVAL S-bend at %s; bend radius %.0f px" % [("the insertion (tail %d of %d)" % [sj3 - ns, path3.size() - ns]) if sj3 >= ns else ("the flight at %.2f s of %.2f" % [sj3 * pl.sdt, pl.dur]), 1.0 / absf(tv3)])
				ls2 = 0
				k3 += 30
				continue
			ls2 = sg3
			la2 = k3
		k3 += 1
	return [tight if tight < INF else 999.0, sbends, rad_to_deg(swing), arr_s]
