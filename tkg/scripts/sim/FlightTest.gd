extends Node

## EVERY AUTO-FLIGHT ON THE SECTOR MAP, planned, clicked and flown, measured and
## judged (ruling 20, Oct 30: the solved flight, `FlightSolve`, in every system):
##   godot --headless --path . -- sheet=FlightTest [seeds=N] [seed=N] [systems=N]
##     [only=one|giant|twin|close] [worker=N] [out=<json>] [why=sys:start:target]
## For systems of N runs' maps (SYSTEM, PULSAR and STATION nodes; `systems` of
## each sweep a run, 12 unless asked, spread evenly through the map: seed 4242's
## holds 610, and flying all of them ran past 43 minutes for the one run;
## `systems=999` flies them all): one-star systems without a giant (`one`), with
## one (`giant`, every giant pulling at its rolled 1/10 to 1/4 of the star), and
## the ordinary systems again with two suns (`twin`, the node asked for them as
## `-- twin=all` does, each a wide pair), and again as close pairs (`close`,
## Jon's "Binary kinds: close:B", Nov 1: every body round both suns 150 to 170
## px apart; `SystemLayout.close_force`) -- from every
## start (in orbit of each world; in each star's close orbit; settled on a star
## orbit, round a star or round both; flying free; at the edge as arrived;
## close by a world; alongside a station, belt, hulk or contact) to every place
## (each star, each world, each station, belt, hulk and contact):
## - the plan the map's worker makes for its preview (`ShipFlight.make_plan`,
##   PREVIEW_AHEAD on, as `plan_bg` makes it), timed on this thread: solved,
##   today's planner as the fallback, or none;
## - found and clean (every keep-out held), how close to a star's surface and a
##   world's disc, top speed, flight time and engine work, and its drawn path's
##   tightest bend and corners at zoom 1 and 2 (`_turn_max`, `_gait`);
## - THE CLICK, a moment later (before its departure, as the map keeps the drawn
##   flight ahead of the ship): flown through `ShipFlight.fly` with the drawn
##   plan, as `fly_bg` flies it -- whether it flew that very flight, and how far
##   each flown frame was from the drawn point for its moment;
## - FLOWN through `ShipFlight.step` at 60 a second until it is on the orbit:
##   landed, the biggest change of velocity from one frame to the next, and
##   how long from the click to settled (printed, not judged: ruling 21's
##   measure of flight length).
## Then the captures that change under the new rule against the old (first by
## index), a slow ship let go inside each place's ring, and `worker` plans made
## on WorkerThreadPool (`plan_bg`): the same flights bit for bit, how long each
## took there, its take-in on this thread, and this thread's frames meanwhile.
## Then THE CLICKS THROUGH THE MAP'S OWN PATH (`_click_phase`, `clicks=N`): some
## of the game's starts clicked through `fly_bg` at 60 and 30 frames a second
## in the map's order, the preview kept as the overlay keeps it, paced to the
## wall clock while anything is planned -- every click flown and landed with
## its callback once, W letting go of one still being planned, nothing planned
## on this thread in a frame, every flight flown on the line drawn for it, no
## engine error. And FLYING BY HAND IN A TWIN (`_hand_phase`, `hand=0` to skip):
## let go far out on the far side and between the stars, it settles inside the
## map and taken by no ring; W at a sun never takes it inside its keep-out.
## PASS, per sweep, on the flights the game can start (out of an orbit, a
## star's close orbit, a settled star orbit or the edge as arrived, or
## alongside: free and close-by starts, coasting at up to 170 px/s, only this
## measure makes, and they are printed apart): at least 99% found and clean
## (DESIGN); no corner in a solved flight's drawn path at zoom 1 or 2 (a ring
## drawn so small its own ends turn faster, a twin's world round one star at
## zoom 1, left out where it is ridden, and counted). From every start: every
## planned flight landed; no frame's velocity change a snap; every click flew
## the drawn flight to within DRAWN_PX; every solved flight ends where the
## ship's own `center` puts its place; every worker plan the same. A game start
## the first frame takes onto a ring is counted and not planned (the map would
## refuse the click there).
## THE FAR PLACES AND THE CORE (`_places_phase`): the Hellbender laid out
## (`Run.hellbender_at`), where a job's place goes too, past every orbit, in
## systems of one sun and of two, and the core's black hole and the start
## system, which no sweep holds: every game start to each, found (in a twin by
## the solver; with one sun today's planner the fallback), and no flight in the
## core inside the black hole's keep-out (`MapGravity.keep_out_star`, its lens).
## `short`: the gate's run (seeds=1 systems=4 worker=24 clicks=6, the far places
## in 4 systems a sweep), one star, giant and twin, the clicks and the hand
## phase, in about 95 s. The gate runs it as two: `short clicks=0` (no clicks)
## in the pool, and `clicks` alone (the same systems' starts gathered, nothing
## else planned, then only the clicks, which time the step against 20 ms and
## pace to the wall clock: one of the gate's SOLO_UNITS).
## Other modes: `retarget` (another place chosen on the way, PASS/FAIL) and
## `starride` (out of star orbits, held as the ship rides).

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
## `flight=<path>`: another ShipFlight to measure (an older one, to compare).
var _flight_script: Script = ShipFlightS

const SEEDS := [4242, 7, 1999, 31337, 99, 123, 5150, 8080]
const NONE := {"w": false, "a": false, "s": false, "d": false}
## found and clean in at least this share of each sweep (DESIGN)
const FOUND_MIN := 0.99
## a flown frame this far from the drawn point for its moment is another flight
const DRAWN_PX := 0.5
## A CORNER, as `_turn_max` reads one over 2 px: more than this, deg per px
const CORNER := 20.0
## A SNAP: a frame's change of velocity this many times its neighbours' (and
## over SNAP_DV px/s). A solved flight's burns are at THRUST (0.67 px/s a frame)
## and a star's pull near its keep-out about twice that.
const SNAP_RATIO := 4.0
const SNAP_DV := 6.0
## the longest a flight may take, from the click to on its orbit: from its plan
## to its arrival T_CAP 16 s, ride and all (ruling 21; T_CAP_BACK 30 s where
## the as-built search behind it flies it, T_CAP_WIDE 40 s for the few only the
## wider search finds), the plan made up to PREVIEW_AHEAD 1 s on, the
## insertion or the stop alongside, and slack. It was 16 s when flights were
## time-scaled conics of 4 to 12 s; on map time they take up to 16, 30 or 40.
const FLY_MAX := 45.0
## a flight in two legs (`FlightSolve._chain`, in a twin only where one leg
## reaches nothing) flies both legs by the as-built search, its second of up
## to T_CAP_BACK more
const FLY_MAX_TWO := FLY_MAX + FlightSolve.T_CAP_BACK
## A START NO FLIGHT CAN LEAVE: flying free, no burn at THRUST (CLEAR_HEAD
## headings, each of CLEAR_DV) keeps its coast clear of every keep-out for this
## long (s). Close by a twin's world round one star, coasting at up to 170 px/s
## a few px outside a keep-out, a burn changes the motion by 4 px/s in a tenth
## of a second: the coast is into the keep-out first
const CLEAR_S := 1.0
const CLEAR_HEAD := 16
const CLEAR_DV := [0.0, 20.0, 40.0, 70.0, 100.0, 150.0, 220.0]
## AND THE MEASURED RESIDUAL past those, at the most (Oct 31, three seeds: 1 of
## 1,790 twin plans): seed 7 system 110, close by world 1 round star B coasting
## at 77 px/s, 11 px outside a keep-out, where one burn of 96 keeps clear but no
## flight in one leg or two (through any of 34 points round the pair and the
## place, or with that burn itself as the first leg) nor the near hop flies
## from. A harness's start: the map flies only out of an orbit
const PUT_LEFT := 1
## AND A CLOSE PAIR'S (Nov 1, three seeds: 5 of 1,789 plans, every one from a
## harness's start; every game start found): a free start 223 px from star A
## diving at the pair at 149 px/s, to star A and to world 3 (found 1 and 2 s
## on), and one to star B; two close by a world, coasting at 106 and 114 px/s,
## that the next half second takes onto the place itself or alongside (found 2 s
## on). With the suns 150 to 170 px apart a harness's free start lands nearer
## them than in a wide pair, aimed at them more often.
const PUT_LEFT_CLOSE := 5
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
## the common flights, apart (per sweep): tightest bend radius at zoom 1 and 2,
## corners, flight time, S-bends
var _cat := {}
## the cases to plan again on a worker: [sweep, L, start, b, i, t, plan]
var _wk: Array = []
## THE CLICKS THROUGH THE MAP'S OWN PATH (`_click_phase`): [sweep, L, start, b,
## i, t, node index] per sweep, and how many of each sweep to click at each frame
## rate (`clicks=N`: twins N, the others half)
var _ck := {"one": [], "giant": [], "twin": [], "close": []}
var _clicks := 16
## `hand=0`: no flying by hand (`_hand_phase`)
var _hand := true
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
		elif s == "hand=0":
			_hand = false
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
		elif s.begins_with("why="):
			# `why=system:start:target`: that one flight, every try's failure said
			_why = s.substr(4)
	_run.call_deferred()


func _wants(sweep: String) -> bool:
	return _only == "" or _only == sweep


func _stat(sweep: String) -> Dictionary:
	if not _sw.has(sweep):
		_sw[sweep] = {"plans": 0, "solved": 0, "clean": 0, "replay": 0, "warm": 0, "fallback": 0, "none": 0,
			"flown": 0, "landed": 0, "ms": [], "T": [], "work": [], "lead": [], "clicks": 0, "drawn": 0,
			"drawn_px": [], "corners1": 0, "corners2": 0, "turn1": [], "turn2": [], "snaps": 0, "frame_dv": 0.0,
			"frame_ratio": 0.0, "star": INF, "keep": INF, "world": INF, "speed": 0.0, "not_found": [], "not_landed": [],
			"cornered": [], "snapped": [], "off_drawn": [], "nose": 0.0, "by_start": {}, "systems": 0, "redrawn": 0, "ring_corners": 0, "game_corners1": 0, "game_corners2": 0, "unflyable": 0, "end_off": 0.0, "belt_ends": 0,
			"chained": 0, "chain_T": [], "chain_ms": [], "chain_cut": [], "chain_list": [], "chain_far": 0.0, "far": 0.0, "put": [],
			"click_game": [], "click_place": [], "click_two": []}
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
				var was2 := n2.twin
				n2.twin = bool(all_of[k][2])
				_system(sweep2, sd, n2, L3)
				if not _rows_only:
					var cc := _captures(L3, n2.index)
					var into: Array = cap.twin if L3.twin else cap.one
					for q in 3:
						into[q] += cc[q]
				n2.twin = was2
		print("flighttest: seed %d: %s systems" % [sd, counts])
	if _why == "" and not _rows_only:
		_places_phase(seeds)
	if not _rows_only:
		await _worker_phase()
	OS.add_logger(_errs)
	if _clicks > 0:
		await _click_phase()
	if _hand and not _rows_only:
		_hand_phase()
	OS.remove_logger(_errs)
	if not _rows_only:
		_report(cap)
	print("flighttest: all of it took %.0f s%s" % [(Time.get_ticks_msec() - t_all) / 1000.0, " (short)" if _short else ""])
	h.verdict("flighttest")
	get_tree().quit(h.code())


## THE FAR PLACES AND THE CORE, from the game's starts (out of each world's
## orbit, each star's close orbit, a settled star orbit, the edge as arrived,
## alongside): the Hellbender laid out in `_places` systems a sweep of one sun
## and of two (a job's place is laid out the same way, past every orbit:
## `SystemLayout.of`), flown to; and the core and the start system, every
## place. A twin's flight to the Hellbender found nothing 17% of the time from
## the edge before flights in two legs (the one-sun review, Oct 31), and the
## core's solved flights dove inside the black hole's lens, 33 of 252 inside its
## close orbit, where today's planner never went.
func _places_phase(seeds: Array) -> void:
	var t_ph := Time.get_ticks_msec()
	var st := {}
	for k: String in ["far one", "far twin", "far close", "core", "start"]:
		st[k] = {"plans": 0, "solved": 0, "old": 0, "none": 0, "T": [], "miss": [], "close": INF, "inside": 0}
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
					_far_case(st[key], key, sd, n, Lc, i, keep_core if key == "core" else -1.0)
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
					_far_case(st[pair[0]], String(pair[0]), sd, n2, L2, hp, -1.0)
				Run.hellbender_at = -1
				Run.hellbender_hp = 0
				n2.twin = was
	for k3: String in ["far one", "far twin", "far close", "core", "start"]:
		var S: Dictionary = st[k3]
		print("flighttest: %s: %d flights from the game's starts: solved %d, today's planner %d, none (put there) %d; flight time %s s%s" % [k3, S.plans, S.solved, S.old, S.none, _dist(S.T),
			"; closest to the black hole %.1f px, its keep-out %.1f" % [S.close, keep_core] if k3 == "core" else ""])
		for l in (S.miss as Array).slice(0, 12):
			print("    %s" % l)
		# (in a twin no fallback: found by the solver; with one sun today's planner may)
		h._ok("%s: every flight from the game's starts found, none put there (%d of %d)" % [k3, int(S.plans) - int(S.none), S.plans], int(S.plans) > 0 and int(S.none) == 0)
		if k3 == "core":
			h._ok("core: no flight inside the black hole's keep-out, %.1f px, its lens (%d; closest %.1f)" % [keep_core, S.inside, S.close], int(S.inside) == 0)
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


## EVERY FLIGHT IN ONE SYSTEM, from every start to every place.
func _system(sweep: String, sd: int, n: MapGen.MapNode, L: SystemLayout) -> void:
	var S := _stat(sweep)
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
			_case(sweep, sd, n, L, key, int(s0[1]) if key != "near" else i, i, t)


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
	# (a game's start the first frame took elsewhere -- a star orbit put inside a
	# world's ring, taken onto it -- is no longer a start a flight can leave from:
	# the map would refuse the click, `can_fly`; counted, not planned)
	if key != "free" and key != "near" and not fl.can_fly():
		S.unflyable = int(S.unflyable) + 1
		return
	# (`clicks`: the start kept for the clicks as below, nothing planned)
	if _rows_only:
		S.plans = int(S.plans) + 1
		if key != "free" and key != "near" and int(S.plans) % 5 == 2:
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
	(S.ms as Array).append(ms)
	if pl == null:
		S.none = int(S.none) + 1
		(S.not_found as Array).append(where + " (none)")
		(S.put as Array).append([where, _clear_for(fl, i, t)])
		return
	if pl.res == null:
		S.fallback = int(S.fallback) + 1
		(S.not_found as Array).append(where + " (today's planner)")
	else:
		S.solved = int(S.solved) + 1
		bs[key].found = int(bs[key].found) + 1
		if pl.res.clean:
			S.clean = int(S.clean) + 1
			bs[key].clean = int(bs[key].clean) + 1
		else:
			(S.not_found as Array).append(where + " (unclean, %.2f px in)" % -pl.res.clear)
		(S.T as Array).append(pl.res.T)
		(S.work as Array).append(pl.res.work)
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
		if int(_wk.size()) < _worker_n * 3 and (_wk.size() % 3 == 0 or sweep == "twin" or sweep == "close"):
			_wk.append([sweep, L, key, b, i, t, pl, n.index])
		# (the game's starts, every few, for the clicks through the map's path)
		if key != "free" and key != "near" and int(S.plans) % 5 == 2:
			(_ck[sweep] as Array).append([sweep, L, key, b, i, t, n.index])
	# WHERE IT ENDS, against where the ship's own `center` puts the place then
	# (the solver's place is MapGravity's copy of the layout's; a belt's beacon
	# rides round the belt's host, which `center` once took for the origin)
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
	# THE CLICK, up to CLICK_S on (the ship riding its ring, holding alongside,
	# or round its star orbit meanwhile), on the flight drawn then: planned
	# again as the overlay plans it (`SystemOverlay._draw_paths`: every 3 s on a
	# ring, every second otherwise, as its departure comes up, and once it can no
	# longer be flown -- a ride that had to phase falls behind if it is not
	# flown), each from the last one's choice. Here each comes in at once; on the
	# map a few frames later, and a click meanwhile flies the one being made.
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
		# HOW LONG IT TAKES (ruling 21's measure): from the click to settled on
		# the orbit or alongside, s of map time, from the game's starts, out of
		# a place (an orbit, a star's close orbit, alongside), and in two legs
		if key != "free" and key != "near":
			(S.click_game as Array).append(float(fm.land_s))
		if key == "orbit" or key == "close" or key == "keep":
			(S.click_place as Array).append(float(fm.land_s))
		if pl.res != null and pl.res.legs == 2:
			(S.click_two as Array).append(float(fm.land_s))
	else:
		(S.not_landed as Array).append(where + " (mode %s, %.1f s)" % [fm.mode_end, fm.secs])
	if pl.res != null and not fm.undrawn:
		S.clicks = int(S.clicks) + 1
		if fm.same:
			S.drawn = int(S.drawn) + 1
			(S.drawn_px as Array).append(float(fm.off))
			if float(fm.off) > DRAWN_PX and (S.off_drawn as Array).size() < 20:
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


## WHERE A CORNER IS (`why=`): the drawn point nearest the worst turn, which
## part of the flight it is in, how fast it goes there and the least speed
## round it, and whether it burns.
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
			var p := _clear_of_stars(fl, L, _clear_of_worlds(fl, L, c0 + Vector2(cos(a), sin(a)) * r, t))
			fl.settle_at(p, 1.0 if R.randf() < 0.8 else -1.0)
		"free":
			var r2 := lerpf(fl.star_ring() + 40.0, L.edge * 0.9, R.randf())
			var a2 := R.randf() * TAU
			fl.mode = &"free"
			fl.f.p = _clear_of_stars(fl, L, _clear_of_worlds(fl, L, c0 + Vector2(cos(a2), sin(a2)) * r2, t))
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
				if _star_gap(fl, L, fl.f.p) > 12.0:
					break
				a3 += TAU / 12.0
				fl.f.p = Vector2(c3.x, c3.z) + Vector2(cos(a3), sin(a3)) * ra3 * d3
			fl.f.orbit_r = -1.0
			fl.f.v = Vector2(cv3.x, cv3.z) + Vector2(R.randf_range(-120, 120), R.randf_range(-120, 120))


## How far p is outside the nearest star's keep-clear.
func _star_gap(fl, L: SystemLayout, p: Vector2) -> float:
	var g := INF
	for s in L.stars():
		g = minf(g, (p - L.star_pos(s)).length() - float(fl.keep_clear(s)))
	return g


## A start the stars allow: out of every star's bumper (pushed out from the
## nearest).
func _clear_of_stars(fl, L: SystemLayout, p: Vector2) -> Vector2:
	for s in L.stars():
		var c := L.star_pos(s)
		var bm: float = float(fl.bumper(s)) + 10.0
		if (p - c).length() < bm:
			p = c + (p - c).normalized() * bm if (p - c).length() > 0.01 else c + Vector2(bm, 0.0)
	return p


## The plan's own numbers: closest to a star's surface, to any world's disc
## (not the one it leaves while leaving, nor the one it comes to as it comes),
## top speed and pull, the biggest kink.
func _measure(fl, L: SystemLayout, pl, i: int, t: float, from_b: int) -> Dictionary:
	var m := {"star": INF, "world": INF, "speed": 0.0, "acc": 0.0, "kink": 0.0}
	var n: int = pl.samp.size()
	var pv := Vector3.INF
	for k in range(0, n, 2):
		var q: Vector3 = pl.samp[k]
		var tk: float = float(pl.t0) + k * pl.sdt
		if not (SystemLayout.is_star(i) and (n - k) * pl.sdt < 0.4):
			for s in L.stars():
				m.star = minf(m.star, (Vector2(q.x, q.z) - L.star_pos(s)).length() - L.star_radius(s))
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


## THE CLICK AND THE FLIGHT, at 60 a second through the ship's own step: the
## drawn plan given to `fly` as the map's click gives it (`fly_bg`); whether
## the ship flew that very flight, each flown frame from its departure to its
## arrival against the drawn point for its moment and, after it, against the
## drawn insertion; on the orbit at the end; the biggest frame-to-frame change
## of velocity (against the frames either side, a snap's tell) and of the nose.
func _fly(fl, i: int, t0: float, drawn, undrawn := false) -> Dictionary:
	var out := {"land_s": -1.0, "landed": false, "frame_dv": 0.0, "frame_ratio": 0.0, "at": 0.0, "mode": "", "same": false,
		"off": 0.0, "snap": false, "nose": 0.0, "mode_end": "", "secs": 0.0, "undrawn": undrawn}
	var pl = fl.fly(i, t0, func() -> void: pass, drawn.choice, null if undrawn else drawn)
	if pl == null:
		return out
	out.same = not undrawn and drawn.res != null and pl.res == drawn.res
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
		var p: Vector3 = fl.where3()
		ps.append(Vector2(p.x, p.z))
		modes.append(String(fl.mode) + (" inserting" if fl.inserting() else ""))
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
		if d > SNAP_DV and ratio > SNAP_RATIO:
			out.snap = true
	if landed_at < 0 and ShipFlightS.why:
		print("    not landed: mode %s, reached %d" % [fl.mode, fl.reached()])
	return out


## HOW LONG THE BEST BURN FROM HERE KEEPS CLEAR (s, up to 30): flying free, a
## burn at THRUST of each of CLEAR_DV at CLEAR_HEAD headings and the coast after
## it, through the keep-outs this flight to place i holds (its own place's cut
## to its ring); INF from any other start (an orbit, alongside), which no
## measure excuses.
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


## THE CAPTURES THAT CHANGE under the new rule (the place the line goes into,
## else the nearest ring) against the old (the first world by index, then the
## star, then a station's), as letting go there takes the ship: a slow ship put
## inside each place's ring (a world's at 0.2 to 0.95 of it, a station's,
## belt's, hulk's or contact's within its reach as seen, a star's close ring) at
## six points round it, one step of `free_step` each way: [how many were held
## by two rings or more, how many of those the new rule took elsewhere, of how
## many]. Where one ring holds the ship the two rules are the same rule.
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
	# (and the moments one place is inside another world's ring -- a hulk inside
	# the giant's, a world's passing another's -- at their conjunction, worked
	# out from their circles: at a random moment two rings hardly ever hold the
	# same ship, and a slow pair's conjunction is hours of map time away)
	var meets: Array = []
	for p0: int in places:
		if p0 < 0:
			continue
		var a0 := L.bodies[p0]
		for b1 in L.bodies:
			if b1.world == &"" or b1.index == p0 or b1.host != a0.host:
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
			if (st.p - L.star_pos(s2)).length() < float(fl.star_ring(s2)):
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


## PLANS ON A WORKER, as the map makes them (`plan_bg`): for the cases kept,
## the same state planned again there, each frame on this thread the ship's step
## and the poll timed while it runs, the take-in timed when it is done, and the
## flight compared with the one made here, sample for sample.
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


## THE CLICK AS THE MAP MAKES IT (the flight review, Oct 31: no harness clicked
## through `fly_bg`, and none in a twin): for some of the game's starts in each
## sweep, at 60 and at 30 frames a second, in the map's own order -- the click
## before the frame's clock moves, then the clock, the ship's step, and the
## overlay's draw (its preview asked for on a worker, laid out there, taken in
## when done and kept while it can be flown, as `SystemOverlay._draw_paths`
## does) -- paced to the wall clock while anything is being planned, so a plan
## comes in as many frames late as it would. Some clicks come while the preview
## is still being made (the click takes its job over), some let go with W while
## their plan is still coming. Counted: flown, landed, the callback once on the
## orbit, put there, stale take-ins, a frame the step took over 20 ms (a plan
## made on this thread), frames from the click to the flight, and each flown
## frame against the line the overlay drew (the polyline `ShipFlight.lay_out`
## laid out, which is what is on screen).
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
				# (most click on the line drawn; some while the preview is still
				# being made, some with none drawn -- planned for the click -- and
				# some of those let go of with W while it is)
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
							# the flight as the overlay draws it once it is flown (its
							# own line, `_plan_line`): the preview's, or the one
							# planned for the click and laid out
							flown_pl = pv if flew_drawn else fl.plan
							fline = (flown_pl.line[0] if (flown_pl.line as Array).size() == 3 else fl.lay_out(flown_pl, PV_LINE)[0])
							lim = int(_fly_max(flown_pl) / dt)
					# THE FLOWN FRAME AGAINST THE LINE DRAWN for its stretch: from its
					# departure (a settled star orbit's ride round to it is not drawn)
					# to the ring drawn after its arrival
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


## How far p is from a laid-out line (plane px), looking on from point j0:
## [distance, the segment it is nearest].
static func _near_line(p: Vector2, line: PackedVector3Array, j0: int) -> Array:
	var best := INF
	var bj := j0
	for j in range(maxi(1, j0 - 8), mini(line.size(), j0 + 64)):
		var a := Vector2(line[j - 1].x, line[j - 1].z)
		var b := Vector2(line[j].x, line[j].z)
		var ab := b - a
		var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
		var d := (a + ab * u - p).length()
		if d < best:
			best = d
			bj = j
	return [best, bj]


## FLYING BY HAND IN A TWIN, as the flight review let go and held W (Oct 31),
## in each twin the clicks used: let go out on the far side from star B (0.99 of
## the edge, drifting 8 px/s along), it settles round both stars on a circle
## inside the map and stays off the edge, and a flight from there stays inside
## it; let go between the stars (3 and 25 px off their balance point, at rest),
## it settles, taken by no ring; W held at each star at 150 px/s, it never comes
## inside its keep-out (6 px outside its sun as drawn at the opening zoom).
func _hand_phase() -> void:
	var seen := {}
	var dt := 1.0 / 60.0
	var n := {"far": 0, "far_ok": 0, "far_flights": 0, "far_fl_ok": 0, "mid": 0, "mid_ok": 0, "sun": 0, "sun_ok": 0}
	var rows: Array = []
	var worst_out := -INF
	var worst_settle := 0.0
	var worst_sun := INF
	# (ten wide pairs and five close pairs, as the clicks gathered them)
	var by_kind := {}
	for row: Array in (_ck.twin as Array) + (_ck.close as Array):
		var L: SystemLayout = row[1]
		var kind := "close" if L.close else "wide"
		var key := "%s %d" % [kind, int(row[6])]
		if seen.has(key) or int(by_kind.get(kind, 0)) >= (5 if L.close else 10):
			continue
		seen[key] = true
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var t0: float = row[5]
		var away := -L.star2_at.normalized()
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
		for k in int(60.0 / dt):
			t += dt
			fl.step(dt, t, NONE)
			if settled_at < 0.0 and fl.star_orbiting():
				settled_at = float(k) * dt
			if settled_at >= 0.0 and (fl.f.p as Vector2).length() > L.edge - 0.5:
				pinned += 1
		n.far = int(n.far) + 1
		var out: float = (fl.f.cen as Vector2).length() + float(fl.f.orbit_r) - L.edge
		worst_out = maxf(worst_out, out)
		worst_settle = maxf(worst_settle, settled_at if settled_at >= 0.0 else 99.0)
		var far_ok: bool = settled_at >= 0.0 and settled_at < 30.0 and out <= -11.0 and pinned == 0
		if far_ok:
			n.far_ok = int(n.far_ok) + 1
		else:
			rows.append("far side, system %d: settled at %.1f s, its circle %+.0f px past the edge, %d frames on the edge after" % [int(row[6]), settled_at, out, pinned])
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
			fm.f.p = L.bary + Vector2(-L.star2_at.y, L.star2_at.x).normalized() * r0
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
			var sc := L.star_pos(s)
			var dir := Vector2(-L.star2_at.y, L.star2_at.x).normalized()
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
				rmin = minf(rmin, ((fw.f.p as Vector2) - sc).length())
			n.sun = int(n.sun) + 1
			var kc: float = float(fw.keep_clear(s))
			worst_sun = minf(worst_sun, rmin - (kc - 6.0))
			if rmin >= kc - 0.5:
				n.sun_ok = int(n.sun_ok) + 1
			else:
				rows.append("W at star %d, system %d: came to %.1f px from its centre, its keep-out %.1f (drawn sun %.1f)" % [s, int(row[6]), rmin, kc, kc - 6.0])
	print("flighttest: flying by hand in a twin (%d systems, %d of them close pairs): let go on the far side, %d of %d settled inside the map and off its edge (its circle at worst %+.0f px past the edge, settled at worst in %.1f s), %d of %d flights from there inside it; let go between the stars, %d of %d settled and taken by no ring; W at a sun, %d of %d held out of its keep-out (at worst %.1f px outside the drawn sun)" % [seen.size(), int(by_kind.get("close", 0)), n.far_ok, n.far, worst_out, worst_settle, n.far_fl_ok, n.far_flights, n.mid_ok, n.mid, n.sun_ok, n.sun, worst_sun])
	for r in rows.slice(0, 20):
		print("    " + r)
	h._ok("by hand in a twin: let go anywhere it settles inside the map, between the stars too, and W never takes it into a sun (%d/%d, %d/%d, %d/%d, %d/%d)" % [n.far_ok, n.far, n.far_fl_ok, n.far_flights, n.mid_ok, n.mid, n.sun_ok, n.sun],
		int(n.far) > 0 and (not _wants("close") or int(by_kind.get("close", 0)) > 0) and n.far_ok == n.far and n.far_fl_ok == n.far_flights and n.mid_ok == n.mid and n.sun_ok == n.sun)


func _report(cap: Dictionary) -> void:
	var tot_plans := 0
	for sweep: String in ["one", "giant", "twin", "close"]:
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
		print("  closest to a star's surface %.1f px; least margin to a keep-out %.2f px; closest to a world's disc %.1f px; top speed %.0f px/s" % [S.star, S.keep, S.world, S.speed])
		print("  sharpest turn of the drawn path, deg per px: zoom 1 %s; zoom 2 %s" % [_dist(S.turn1), _dist(S.turn2)])
		print("  corners (over %.0f deg/px in 2 px) in solved flights: zoom 1 %d, zoom 2 %d (from the game's starts %d, %d); and %d on a ring's own curve only (a ring drawn so small its ends turn that fast)" % [CORNER, S.corners1, S.corners2, S.game_corners1, S.game_corners2, S.ring_corners])
		print("  clicks: %d, %d flew the drawn flight; drawn against flown, px: %s; the drawn flight planned again before the click %d times" % [S.clicks, S.drawn, _dist(S.drawn_px), S.redrawn])
		print("  flown: biggest frame-to-frame change of velocity %.1f px/s, %.1fx its neighbours; snaps %d; the nose's biggest turn in a frame %.1f deg" % [S.frame_dv, S.frame_ratio, S.snaps, S.nose])
		if int(S.unflyable) > 0:
			print("  game starts the first frame took onto a ring (no flight can leave there, not planned): %d" % S.unflyable)
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
		# JUDGED ON THE FLIGHTS THE GAME CAN START: out of an orbit, a star's
		# close orbit, a settled star orbit (the edge as arrived is one) or
		# alongside (Jon: "You have to be IN AN ORBIT ... AND THEN CLICK");
		# flying free and close by a world, coasting at up to 170 px/s, only
		# this measure asks for, and they are printed on their own
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
		h._ok("%s: found and clean from an orbit, a star orbit or alongside %d of %d (%.2f%%, at least %.0f%%)" % [sweep, g_ok, g_n, share * 100.0, FOUND_MIN * 100.0], g_n > 0 and share >= FOUND_MIN)
		print("  farthest any solved flight goes from star A: %.2f of the edge" % S.far)
		if int(S.chained) > 0 or sweep == "twin" or sweep == "close":
			print("  flights in two legs (FlightSolve._chain, where one leg reaches nothing): %d; flight time %s s; planned (this thread) %s ms; the second leg off the first's coast, s on: %s; out to %.2f of the edge at the farthest" % [S.chained, _dist(S.chain_T), _dist(S.chain_ms), _dist(S.chain_cut), S.chain_far])
			for l6 in S.chain_list:
				print("    TWO LEGS: %s" % l6)
		if sweep == "twin" or sweep == "close":
			# IN A TWIN NO FLIGHT IS PUT THERE (the ship jumped to the place with no
			# flight: 63 of 1,790 before a flight in two legs, 18 of them from the
			# game's starts), from any start this measure makes -- but one no burn
			# at THRUST can leave without crossing a keep-out within CLEAR_S, each
			# listed with how long its best burn keeps clear
			var excused := 0
			for e7: Array in S.put:
				var ok7 := float(e7[1]) < CLEAR_S
				if ok7:
					excused += 1
				print("    PUT THERE: %s; the best burn from there keeps clear for %.2f s%s" % [e7[0], e7[1], " (no flight can leave)" if ok7 else " (THE RESIDUAL)"])
			var left: int = (S.put as Array).size() - excused
			var most := PUT_LEFT_CLOSE if sweep == "close" else PUT_LEFT
			h._ok("%s: no flight put there from any start (%d of %d plans) but where no burn at THRUST keeps clear of a keep-out for %.1f s (%d of them), and the measured residual, at most %d (%d)" % [sweep, (S.put as Array).size(), plans, CLEAR_S, excused, most, left], left <= most)
		h._ok("%s: every planned flight landed (%d of %d)" % [sweep, S.landed, S.flown], int(S.landed) == int(S.flown))
		# (from a harness's free start, coasting at anything from nought to 170
		# px/s, a burn across a ship all but at rest draws a hook where it starts:
		# printed above, not judged)
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


## Median, 90th, 99th and worst of a list of numbers, as one string.
static func _dist(xs: Array) -> String:
	if xs.is_empty():
		return "(none)"
	var s := xs.duplicate()
	s.sort()
	var n := s.size()
	return "median %.2f, 90th %.2f, 99th %.2f, worst %.2f (%d)" % [float(s[n / 2]), float(s[mini(n - 1, int(n * 0.9))]), float(s[mini(n - 1, int(n * 0.99))]), float(s[n - 1]), n]


## ANOTHER PLACE CHOSEN ON THE WAY (Jon: "You have to be IN AN ORBIT ... AND
## THEN CLICK to go to another planet"): flights out of a world's orbit and out
## of the star orbit, flown frame by frame. Counted: frames where a flight could
## start while it should not (on the way, burning onto an orbit, riding round
## to leave); then, once settled, the plan to another place -- none, degenerate
## (not a number, off the map, through a star), how far out it swings and
## turns, how much it moves as the map replans it every half second for 3 s --
## and whether it lands. Flights on map time take up to 16 s from their
## departure (ruling 21; 30 s where the as-built search behind it flies them,
## 40 for the wider search) and their ride up to 4.4 s first (ruling 20), so
## the waits for settling and landing are FLY_MAX, not the 30 s and 20 s of the
## time-scaled conics; what is counted is the same.
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
	if not moves.is_empty():
		print("  the drawn plan's biggest move in a half second while it rides its orbit, px: median %.2f, 90th %.2f, worst %.1f; over 6 px: %d" % [moves[moves.size() / 2], moves[int(moves.size() * 0.9)], moves[-1], moves.filter(func(x: float) -> bool: return x > 6.0).size()])
	var ok_all: bool = tot.early == 0 and tot.late == 0 and tot.none == 0 and tot.bad == 0 and tot.landed == tot.tries
	print("retarget: %s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)


## OUT OF THE STAR ORBIT (Jon: "the projected orbit path is updating constantly
## and can create some WEIRD shapes"): star orbits at three sizes, the ship at
## six points round each, to every world. Each plan measured as drawn (turning in
## all, S-bends, lobes, tightest bend away from the rings) and then held: the
## ship rides on for 3 s and the map's replan (every half second, keeping its
## choice) is compared with the last -- how far its line moved.
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
					fl.settle_at(_clear_of_worlds(fl, L, Vector2(cos(a), sin(a)) * r, t0))
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
## through a star's disc.
func _degenerate(fl, L: SystemLayout, pl) -> String:
	for q: Vector3 in pl.samp:
		if is_nan(q.x) or is_nan(q.z) or is_inf(q.x) or is_inf(q.z):
			return "not a number"
		if Vector2(q.x, q.z).length() > L.edge * 1.6:
			return "off the map"
		for s in L.stars():
			if (Vector2(q.x, q.z) - L.star_pos(s)).length() < L.star_radius(s) + 2.0:
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


## The sharpest turn of a path as drawn at `zoom` (on screen, the plane's tilt
## and height as the map projects them), in degrees per pixel: resampled to
## 1 px steps, the turn over 3 px either side of each point, over 6 px.
## `skip`, one per point: 1 where the turn is not measured (a ring's own curve,
## `_ring_skip`).
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


## THE STRETCHES OF A DRAWN PATH THAT ARE A RING'S OWN CURVE, as `_turn_max`
## skips them at `zoom`: on the ring it leaves (while it leaves) or the one it
## arrives on (as it arrives, and the ring drawn after), within 1.25 of that
## ring, where that ring is drawn so small its own ends turn faster than CORNER
## -- a ring of radius R is drawn as an ellipse whose ends curve at TILT^2 R
## zoom px, 2.5 px for a twin's world round one star (R 17.6) at zoom 1, 22 deg
## a px. The ring is the world's, drawn as such; the flight on and off it is
## still measured, and corners there are counted apart (`ring corners`).
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


## HOW GRACEFUL A FLIGHT LOOKS, at zoom 1, on screen: [the tightest bend's
## radius in px away from the rings it leaves and joins (within 1.4 rings of the
## world, or inside the star's close ring, is the ring's own curve), the count of
## S-bends -- a bend tighter than 40 px one way within 30 px of one the other
## way: a hook or a dog-leg].
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
		if SystemLayout.is_star(i) and (Vector2(q.x, q.z) - L.star_pos(i)).length() < float(fl.star_ring(i)) + 30.0:
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
