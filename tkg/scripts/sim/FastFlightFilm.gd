extends Node

## THE FAST TRANSFERS, FILMED (Jon, Nov 4-5: "almost 4 times slower than feels
## good", "Why is transferring between planets a straight line?"):
##   godot --path . --windowed --resolution 960x540 --fixed-fps 60
##       --write-movie <dir>/f.avi -- sheet=FastFlightFilm [seed=N] [sys=<name part>|<index>]
##       [from=<body>|edge] [to=<body>] [twin] [autopilot=direct|curved] [flight_pace=K]
##       [lookaids=0] [worldpace=K] [title=<words>] [hold=S] [lead=S] [out=<json>]
## The real map of one system (by default seed 4242's IOTA TALLOW, Jon's V to
## IV), the ship parked in orbit of `from` (or, `from=edge`, just arrived by
## jump, its arrival played), `to` selected so its line is drawn as a first
## click draws it, and `lead` s later clicked again (`fly_to_body`); held until
## the ship is settled in orbit there and `hold` s more. Timed on the map's own
## clock (`view.t`, which moves by each frame's delta: real time, never the
## wall clock the movie writer races), and printed with the flight's bend and
## turn (`FlightSolve.shape_of`) as `FILM {json}`. A caption in the corner says
## the path, the pace and, once settled, the seconds. `worlds`: no flight,
## `hold` s of the map with the ship parked, for the worlds' pace strip; the
## seconds a lap of the first worlds, the giant and the pair printed.

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")

var _tree: SceneTree
var _args: PackedStringArray
var _cap: Label


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _has(k: String) -> bool:
	return _args.has(k)


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _idle() -> void:
	for i in 900:
		await _tree.process_frame
		if not ZoomLadder.busy() and ZoomLadder.chain == &"":
			break


## The system asked for: `sys` a name part or an index; `twin` a binary.
func _find(want: String, twin: bool) -> MapGen.MapNode:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM and n.type != MapGen.NodeType.STATION:
			continue
		if want != "" and want.is_valid_int():
			if n.index == int(want):
				return n
			continue
		if want != "" and MapGen.star_name(n).to_upper().find(want.to_upper()) < 0:
			continue
		if twin and not (n.twin and MapGen.twin_ok(n)):
			continue
		if not twin and n.twin:
			continue
		return n
	return null


func _caption(text: String) -> void:
	if _cap == null:
		var layer := CanvasLayer.new()
		layer.layer = 120
		_tree.root.add_child(layer)
		var bg := ColorRect.new()
		bg.color = Color(0.0, 0.0, 0.0, 0.72)
		bg.position = Vector2(4, 4)
		bg.size = Vector2(420, 34)
		layer.add_child(bg)
		_cap = UITheme.body("", UITheme.ICE, UITheme.FS_SMALL)
		_cap.position = Vector2(10, 8)
		layer.add_child(_cap)
	_cap.text = text


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	if _arg("scan", "") != "":
		# (a harness's search: which seeds lay out a system with a world named so)
		var want := _arg("scan", "")
		for sd in range(1, int(_arg("seeds", "200")) + 1):
			Rng.forced = sd
			Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
			for raw2 in Run.map:
				var n2: MapGen.MapNode = raw2
				if n2.type != MapGen.NodeType.SYSTEM:
					continue
				var L2 := SystemLayout.of(n2)
				var kinds := PackedStringArray()
				var hit := false
				for b2 in L2.bodies:
					kinds.append("%s:%s" % [b2.name.get_slice(" ", b2.name.get_slice_count(" ") - 1), b2.kind])
					hit = hit or b2.name == want
				if hit:
					print("SCAN seed %d system %d %s twin %s %s" % [sd, n2.index, MapGen.star_name(n2), L2.twin, " ".join(kinds)])
		_tree.quit(0)
		return
	Rng.forced = int(_arg("seed", "4242"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	StarchartScreen._primed_for = Run.galaxy_seed
	for raw in Run.map:
		var n0: MapGen.MapNode = raw
		n0.ambush_rolled = true
		n0.ambush_pending = false
	Run.fuel = 99
	var twin := _has("twin")
	var n := _find(_arg("sys", "TALLOW" if not twin else ""), twin)
	if n == null:
		n = _find("", twin)
	if n == null:
		print("FILM {\"error\": \"no system\"}")
		_tree.quit(1)
		return
	OptionTable.ensure(n)
	var L := SystemLayout.of(n)
	Run.at = n.index
	n.visited = true
	SectorScreen._approached_at = n.index
	var opts: Dictionary = ShipFlightS.flight_opts()
	var from := _arg("from", "")
	var worlds: Array[int] = []
	for b in L.bodies:
		if b.world != &"" and b.kind != &"belt" and b.kind != &"giant":
			worlds.append(b.index)
	# (V to IV by default: the last world and the one inside it)
	var to := int(_arg("to", str(worlds[worlds.size() - 2] if worlds.size() >= 2 else 0)))
	var start := int(from) if from.is_valid_int() else (worlds[worlds.size() - 1] if worlds.size() >= 1 else 0)
	if from == "edge":
		Router._post_arrive = true
	else:
		SystemMapScreen._parked[n.index] = {"at": start, "mode": &"rail"}
	Router.show_system()
	await _idle()
	var m := Router.current as SystemMapScreen
	if m == null:
		print("FILM {\"error\": \"no map\"}")
		_tree.quit(1)
		return
	# (`title=` with _ for spaces: a film script's argument has none)
	var title := _arg("title", "%s  x%s" % [String(opts.path).to_upper(), _num(float(opts.pace))]).replace("_", " ")
	var world_k := SystemLayout.world_pace()
	if _has("worlds"):
		_caption("WORLDS x%s" % _num(world_k))
		var laps := []
		for b in L.bodies:
			laps.append({"name": b.name, "kind": String(b.kind), "orbit": b.orbit, "lap_s": b.period})
		var out := {"kind": "worlds", "system": MapGen.star_name(n), "twin": L.twin, "world_pace": world_k, "laps": laps,
			"pair_lap_s": TAU / absf(L.pair_n) if L.pair_n != 0.0 else 0.0,
			"parked_lap_s": TAU * float(m.flight.rail.get("rt", 0.0)) / float(m.flight.rail.get("speed", 1.0)) if m.flight.mode == &"rail" else 0.0}
		# (a comet, at today's speed in every column: Jon, Nov 5, "I think the
		# comet speed is perfect though")
		if _has("comet"):
			await _frames(30)
			var why: String = m.view._weather.force(&"comet")
			out["comet"] = "started" if why == "" else why
			_caption("WORLDS x%s   COMET x1" % _num(world_k))
		await _frames(int(float(_arg("hold", "12")) * 60.0))
		print("FILM " + JSON.stringify(out))
		_tree.quit(0)
		return
	_caption(title)
	# WAIT TO FLY: the arrival over, the ship in orbit (or settled at the edge)
	for i in 1200:
		if m.flight != null and m.flight.can_fly():
			break
		await _tree.process_frame
	await _frames(int(float(_arg("pre", "1.0")) * 60.0))
	# THE FIRST CLICK: the place selected, its line drawn; THE SECOND, `lead` on
	m.select_body(to)
	await _frames(int(float(_arg("lead", "1.2")) * 60.0))
	if _has("debug"):
		var pv = m.overlay._pv_plan
		print("DEBUG preview %s t0-t %.3f takeable %s %s" % [pv != null, (float(pv.t0) - float(m.view.t)) if pv != null else -1.0,
			(not m.flight._takeable(pv, float(m.view.t)).is_empty()) if pv != null else false, m.flight._takeable(pv, float(m.view.t)) if pv != null else {}])
		var dpl = m.flight.make_plan(to, float(m.view.t), {}, ShipFlightS.PLAN_AHEAD)
		if dpl != null and dpl.res != null:
			var tn := float(m.view.t)
			var w := float(dpl.dep.w)
			var dang := fposmod((1.0 if w >= 0.0 else -1.0) * (dpl.res.a_dep - float(m.flight.rail.ang)), TAU)
			var ke: float = m.flight._ride_ke(dpl)
			var lead := float(dpl.t0) - tn
			var shp := ShipFlightS._ride_shape(dang, absf(w), lead, ke)
			shp.T = lead
			print("DEBUG fresh lead %.3f dang %.3f (w lead %.3f) ke %.2f lead_k %.2f shape %s peak*vr %.1f most %.1f vmax %.1f" % [lead, dang, absf(w) * lead, ke, dpl.lead_k, shp,
				absf(w) * float(dpl.dep.rt) * ShipFlightS._ride_peak(shp), FlightSolve.THRUST * dpl.pace * dpl.pace * ShipFlightS.SPIN_PUSH_K, (maxf(float(shp.k), 1.0) + ke - 1.0) * absf(w) * float(dpl.dep.rt)])
		print("DEBUG plan %s res %s kind %s takeable %s dep %s mode %s ns %d nf %d nn %d" % [dpl != null, dpl != null and dpl.res != null,
			dpl.res.kind if dpl != null and dpl.res != null else "-", (not m.flight._takeable(dpl, float(m.view.t)).is_empty()) if dpl != null else false,
			m.flight._dep_of(float(m.view.t), ShipFlightS.PLAN_AHEAD), m.flight.mode, ShipFlightS.n_solved, ShipFlightS.n_fallback, ShipFlightS.n_none])
	var t0 := float(m.view.t)
	var f0 := Engine.get_frames_drawn()
	m.fly_to_body(to)
	var shape := PackedFloat64Array([0.0, 0.0])
	var solved := false
	var pace := 1.0
	var settled := -1.0
	var ride := -1.0
	var flew := -1.0
	var plan_dur := 0.0
	var dep_in := -1.0
	var res_lead := -1.0
	var res_kind := ""
	for i in 60 * 120:
		await _tree.process_frame
		if not is_instance_valid(m):
			break
		var fl = m.flight
		if fl == null:
			continue
		if fl.plan != null and fl.plan.res != null and not solved:
			solved = true
			shape = FlightSolve.shape_of(fl.plan.samp)
			pace = float(fl.plan.pace)
			dep_in = float(fl.plan.t0) - t0
			res_lead = float(fl.plan.res.lead)
			res_kind = String(fl.plan.res.kind)
		var dt := float(m.view.t) - t0
		if ride < 0.0 and fl.mode == &"fly":
			ride = dt
			plan_dur = float(fl.plan.dur) if fl.plan != null else 0.0
		if ride >= 0.0 and flew < 0.0 and fl.mode != &"fly":
			flew = dt - ride
		if settled < 0.0:
			_caption("%s   %.1f s" % [title, dt])
		if settled < 0.0 and fl.reached() == to and fl.can_fly():
			settled = dt
			_caption("%s   %.2f s   bend %.2f  turn %d deg" % [title, settled, shape[0], roundi(shape[1])])
			break
	await _frames(int(float(_arg("hold", "1.5")) * 60.0))
	var rec := {"kind": "flight", "system": MapGen.star_name(n), "twin": L.twin, "from": "edge" if from == "edge" else L.bodies[start].name,
		"to": L.bodies[to].name, "path": String(opts.path), "pace": float(opts.pace), "plan_pace": pace, "solved": solved,
		"aids": ShipFlightS.aids_on(), "world_pace": world_k, "secs": settled, "ride": ride, "flew": flew, "plan_dur": plan_dur, "dep_in": dep_in, "res_lead": res_lead, "res_kind": res_kind, "frames": Engine.get_frames_drawn() - f0,
		"bend": shape[0], "turn": shape[1], "title": title}
	print("FILM " + JSON.stringify(rec))
	var out := _arg("out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(rec))
		f.close()
	_tree.quit(0)


static func _num(x: float) -> String:
	return str(roundi(x)) if absf(x - roundf(x)) < 1e-6 else "%.1f" % x
