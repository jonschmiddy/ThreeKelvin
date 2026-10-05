extends Node

## Every auto-flight on the sector map, planned and flown, measured:
##   godot --headless --path . -- sheet=FlightTest [seeds=N] [out=<json>]
## For each system of N runs' maps, from every start -- in orbit of each world,
## in the star's close orbit, round the star on its wide orbit, flying free, at
## the edge as arrived -- to every place (each world, the star, each station,
## belt, hulk and contact): the plan `ShipFlight.make_plan` makes (direct, round
## a waypoint, or unclean -- none clean), how close it comes to the star and to
## any world's disc, its top speed and burn, how long it takes and how long
## planning it took; then the flight FLOWN through `ShipFlight.step` at 60 a
## second until it is on the orbit, and the biggest change of velocity from one
## frame to the next on the way (a snap would show as one frame far over its
## neighbours). Prints the totals and the worst cases.

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
## `flight=<path>`: another ShipFlight to measure (an older one, to compare).
var _flight_script: Script = ShipFlightS

var _n_seeds := 3
var _out := ""
var _why := ""
var _ms: Array = []
var _kinks: Array = []
## THE DRAWN PATH'S SHARPEST TURN, degrees per pixel of it, at zoom 1 and 2: the
## plans (with their insertions) and, from the free starts, the forecast line
var _turns := {"plan z1": [], "plan z2": [], "forecast z1": [], "forecast z2": []}
var _corners := {"plan z1": [], "plan z2": [], "forecast z1": [], "forecast z2": []}
var _turn_at := {}
var _corner_only := false
var _worst_px: Array = []
## THE COMMON FLIGHTS, apart: for each, the drawn path's tightest bend as a
## radius in screen px (6 px window) and its corners (2 px), at zoom 1 and 2
var _cat := {}
## `seed=N`: that one seed instead of the list
var _one_seed := -1
## `retarget`: flights turned to another place at ten points along the way
var _retarget := false
## `starride`: out of star orbits of several sizes, at several points round
## them, to every world: the plan's shape, and how it holds as the ship rides
var _starride := false
## `dump=<json>` with `why=`: that flight's drawn path and its target's place
var _dump := ""
## where the S-bends are: leaving, on the coast, arriving, in the insertion
var _s_where := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seeds="):
			_n_seeds = int((a as String).substr(6))
		elif (a as String).begins_with("out="):
			_out = (a as String).substr(4)
		elif (a as String).begins_with("flight="):
			_flight_script = load((a as String).substr(7))
		elif (a as String).begins_with("dump="):
			_dump = (a as String).substr(5)
		elif a == "retarget":
			_retarget = true
		elif a == "starride":
			_starride = true
		elif (a as String).begins_with("seed="):
			_one_seed = int((a as String).substr(5))
		elif (a as String).begins_with("why="):
			# `why=system:start:target`: that one flight, every try's failure said
			_why = (a as String).substr(4)
	_run.call_deferred()


func _run() -> void:
	if _retarget:
		_run_retarget()
		return
	if _starride:
		_run_starride()
		return
	var tot := {"plans": 0, "direct": 0, "waypoint": 0, "near": 0, "hohmann": 0, "slow": 0, "unclean": 0, "none": 0, "flown": 0, "landed": 0}
	var worst := {"star": INF, "world": INF, "speed": 0.0, "acc": 0.0, "frame_dv": 0.0, "frame_ratio": 0.0, "plan_ms": 0.0, "dur": 0.0, "kink": 0.0}
	var worst_at := {}
	var by_start := {}
	var rows: Array = []
	var seeds := [4242, 7, 1999, 31337, 99, 123, 5150, 8080]
	if _one_seed >= 0:
		seeds = [_one_seed]
		_n_seeds = 1
	for si in mini(_n_seeds, seeds.size()):
		Rng.forced = seeds[si]
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type != MapGen.NodeType.SYSTEM and n.type != MapGen.NodeType.PULSAR and n.type != MapGen.NodeType.STATION:
				continue
			OptionTable.ensure(n)
			var L := SystemLayout.of(n)
			var targets: Array = [-1]
			for b in L.bodies:
				targets.append(b.index)
			var starts: Array = []
			for b in L.bodies:
				if b.world != &"":
					starts.append(["orbit", b.index])
			starts.append(["close", -1])
			starts.append(["star", 0])
			starts.append(["free", 0])
			starts.append(["edge", 0])
			# CLOSE BY ALREADY: within a little over two rings of the place, moving
			# any way (Jon: a lap round the star with the world right beside him)
			starts.append(["near", 0])
			var t := 40.0 + float(n.index % 17) * 13.0
			for s0: Array in starts:
				for i: int in targets:
					if String(s0[0]) == "orbit" and int(s0[1]) == i:
						continue
					if String(s0[0]) == "close" and i == -1:
						continue
					if String(s0[0]) == "near" and (i < 0 or L.bodies[i].world == &""):
						continue
					if _why != "":
						var wq := _why.split(":")
						if int(wq[0]) != n.index or wq[1] != String(s0[0]) or int(wq[2]) != i:
							continue
						ShipFlightS.why = true
					var fl = _flight_script.new()
					fl.setup(L, Vector2(-L.edge * 0.95, 0.0), t)
					_start(fl, L, String(s0[0]), i if String(s0[0]) == "near" else int(s0[1]), t, n.index)
					# one frame, so the ship is where its orbit puts it
					fl.step(1.0 / 60.0, t, {"w": false, "a": false, "s": false, "d": false})
					# (taken by the place's ring already: nothing to fly)
					if fl.orbit_body() == i:
						continue
					var t_plan := Time.get_ticks_usec()
					var pl = fl.make_plan(i, t)
					var ms := float(Time.get_ticks_usec() - t_plan) / 1000.0
					_ms.append(ms)
					tot.plans += 1
					var key := String(s0[0])
					if not by_start.has(key):
						by_start[key] = {"plans": 0, "direct": 0, "waypoint": 0, "near": 0, "hohmann": 0, "slow": 0, "unclean": 0}
					by_start[key].plans += 1
					if pl == null:
						tot.none += 1
						if tot.none <= 12:
							print("  none: %s %d -> %d in system %d, ship at %s r %.0f, target r %.0f" % [key, int(s0[1]), i, n.index, fl.where3().round(), Vector2(fl.where3().x, fl.where3().z).length(), Vector2(fl.center(i, t).x, fl.center(i, t).z).length()])
						continue
					tot[String(pl.kind)] += 1
					by_start[key][String(pl.kind)] += 1
					var m := _measure(fl, L, pl, i, t, int(s0[1]) if key == "orbit" or key == "close" else -9)
					if _why != "":
						print("    kind %s, choice %s" % [pl.kind, pl.choice])
						if _dump != "":
							var dj := {"samp": [], "tail": [], "c": [], "ct": [], "sdt": pl.sdt, "ring": 0.0 if i < 0 else fl.approach_r(i), "burns": []}
							for kd in pl.samp.size():
								var qd: Vector3 = pl.samp[kd]
								dj.samp.append([qd.x, qd.z])
								dj.burns.append(pl.burns[kd])
								var cd: Vector3 = fl.center(i, float(pl.t0) + kd * pl.sdt)
								dj.c.append([cd.x, cd.z])
							for qt: Vector3 in pl.tail:
								dj.tail.append([qt.x, qt.z])
							var fd := FileAccess.open(_dump, FileAccess.WRITE)
							fd.store_string(JSON.stringify(dj))
							fd.close()
						# where the drawn path turns hardest: in the samples (by time) or the tail
						var nS: int = pl.samp.size()
						for kz in range(3, nS - 3):
							var u3: Vector3 = pl.samp[kz] - pl.samp[kz - 3]
							var v3: Vector3 = pl.samp[kz + 3] - pl.samp[kz]
							var u2 := Vector2(u3.x, u3.z * 0.38)
							var v2 := Vector2(v3.x, v3.z * 0.38)
							if u2.length() > 0.01 and v2.length() > 0.01 and absf(u2.angle_to(v2)) > 0.6:
								print("    sharp at %.3f s of %.2f (escape %.2f): turn %.0f deg, step %.2f px, burning %s" % [kz * pl.sdt, pl.dur, pl.esc_t, rad_to_deg(absf(u2.angle_to(v2))), u2.length(), pl.burns[kz] == 1])
						var nT: int = pl.tail.size()
						for kt in range(1, nT - 1):
							var ut: Vector3 = pl.tail[kt] - pl.tail[kt - 1]
							var vt: Vector3 = pl.tail[kt + 1] - pl.tail[kt]
							var ut2 := Vector2(ut.x, ut.z * 0.38)
							var vt2 := Vector2(vt.x, vt.z * 0.38)
							if ut2.length() > 0.01 and vt2.length() > 0.01 and absf(ut2.angle_to(vt2)) > 0.6:
								print("    sharp in the insertion at %d of %d: turn %.0f deg" % [kt, nT, rad_to_deg(absf(ut2.angle_to(vt2)))])
						if pl.tail.size() > 0:
							var e0: Vector3 = pl.samp[nS - 1] - pl.samp[nS - 2]
							var e1: Vector3 = pl.tail[1] - pl.tail[0]
							print("    the join into the insertion: plan end to tail start %.2f px; directions %.0f deg apart" % [(pl.tail[0] - pl.samp[nS - 1]).length(), rad_to_deg(absf(Vector2(e0.x, e0.z).angle_to(Vector2(e1.x, e1.z))))])
						# where the pull jumps most from one sample to the next
						var kj := 0.0
						var kj_at := 0
						for kk2 in range(2, nS - 2):
							var ka0: Vector3 = (pl.samp[kk2] - 2.0 * pl.samp[kk2 - 1] + pl.samp[kk2 - 2]) / (pl.sdt * pl.sdt)
							var ka1: Vector3 = (pl.samp[kk2 + 1] - 2.0 * pl.samp[kk2] + pl.samp[kk2 - 1]) / (pl.sdt * pl.sdt)
							if (ka1 - ka0).length() > kj:
								kj = (ka1 - ka0).length()
								kj_at = kk2
						print("    biggest kink %.0f px/s² at %.3f s of %.2f (sample %d of %d)" % [kj, kj_at * pl.sdt, pl.dur, kj_at, nS])
						# where along it the pull jumps and how fast it goes there
						var nn: int = pl.samp.size()
						for kq in range(2, nn - 1, 6):
							var aq: Vector3 = (pl.samp[kq + 1] - 2.0 * pl.samp[kq] + pl.samp[kq - 1]) / (pl.sdt * pl.sdt)
							var vq: Vector3 = (pl.samp[kq + 1] - pl.samp[kq - 1]) / (2.0 * pl.sdt)
							if aq.length() > 4000.0 or vq.length() > 1500.0:
								print("    at %.2f s of %.2f (escape %.2f, lead %.2f): speed %.0f, pull %.0f, r %.0f, burning %s" % [kq * pl.sdt, pl.dur, pl.esc_t, pl.lead, vq.length(), aq.length(), Vector2(pl.samp[kq].x, pl.samp[kq].z).length(), pl.burns[kq] == 1])
					if float(m.speed) > 1200.0:
						tot.fast = int(tot.get("fast", 0)) + 1
					if float(m.acc) > 5000.0:
						tot.hard = int(tot.get("hard", 0)) + 1
					if String(pl.kind) == "unclean" and int(tot.get("shown_u", 0)) < 12:
						tot.shown_u = int(tot.get("shown_u", 0)) + 1
						var tb_: SystemLayout.Body = null if i < 0 else L.bodies[i]
						print("  unclean: %s %d -> %d in system %d: star %.0f world %.0f speed %.0f; target %s r %.0f (star_r %.0f, keep-clear %.0f)" % [key, int(s0[1]), i, n.index, m.star, m.world, m.speed, "star" if tb_ == null else String(tb_.kind), 0.0 if tb_ == null else tb_.orbit, L.star_r, fl.keep_clear()])
					m.plan_ms = ms
					m.dur = pl.dur
					var where := "seed %d system %d (%s) from %s %d to %d" % [seeds[si], n.index, MapGen.star_name(n), key, int(s0[1]), i]
					for wk in ["star", "world"]:
						if float(m[wk]) < float(worst[wk]):
							worst[wk] = m[wk]
							worst_at[wk] = where
					_kinks.append(float(m.kink))
					var path3 := PackedVector3Array(pl.samp)
					path3.append_array(pl.tail)
					var tgt_world: bool = i >= 0 and L.bodies[i].world != &""
					var cat := ""
					if key == "orbit" and i == -1:
						cat = "world orbit -> star"
					elif key == "star" and tgt_world:
						cat = "star orbit -> world"
					elif key == "orbit" and tgt_world:
						cat = "world -> world"
					elif key == "free" and tgt_world:
						cat = "free -> world"
					elif key == "star" and i == -1:
						cat = "star orbit -> close orbit"
					elif key == "free" and i == -1:
						cat = "free -> close orbit"
					elif key == "near" and tgt_world:
						cat = "near -> world"
					if cat != "":
						if not _cat.has(cat):
							_cat[cat] = {"r1": [], "r2": [], "c1": 0, "c2": 0, "n": 0, "dur": [], "off": [], "s": [], "sw": [], "arr": []}
						_cat[cat].n += 1
						var ga := _gait(fl, L, pl, path3, i, int(s0[1]) if key == "orbit" else -9)
						_cat[cat].off.append(ga[0])
						_cat[cat].s.append(ga[1])
						_cat[cat].sw.append(ga[2])
						_cat[cat].arr.append(ga[3])
						if int(ga[3]) > 0 and int(_cat[cat].get("shown", 0)) < 4:
							_cat[cat].shown = int(_cat[cat].get("shown", 0)) + 1
							print("  ARRIVAL HOOK: %s, %s %d -> %d in system %d (kind %s)" % [cat, key, int(s0[1]), i, n.index, pl.kind])
						_cat[cat].dur.append(pl.dur)
						for zc: float in [1.0, 2.0]:
							_corner_only = false
							var tb := _turn_max(path3, zc)
							_corner_only = true
							var cb := _turn_max(path3, zc)
							_corner_only = false
							_cat[cat]["r%d" % int(zc)].append(1.0 / maxf(deg_to_rad(tb), 1e-4))
							if cb > 20.0:
								_cat[cat]["c%d" % int(zc)] += 1
					for zz: float in [1.0, 2.0]:
						var tv := _turn_max(path3, zz)
						_turns["plan z%d" % int(zz)].append(tv)
						_corner_only = true
						var cv := _turn_max(path3, zz)
						_corners["plan z%d" % int(zz)].append(cv)
						_corner_only = false
						if cv > 20.0 and int(_turn_at.get("listed", 0)) < 40 and zz == 2.0:
							_turn_at["listed"] = int(_turn_at.get("listed", 0)) + 1
							print("  CORNER %.0f deg/px at zoom 2: %s (kind %s)" % [cv, where, pl.kind])
						if _why != "" and zz == 1.0:
							# the tightest 6 px bend: which part of the flight
							_corner_only = false
							var tb6 := _turn_max(path3, 1.0)
							var cpx6: Vector2 = _worst_px[2]
							var bd6 := INF
							var bk6 := 0
							for kk6 in path3.size():
								var q6 := Vector2(path3[kk6].x, path3[kk6].z * 0.38 - path3[kk6].y * 0.925)
								if q6.distance_to(cpx6) < bd6:
									bd6 = q6.distance_to(cpx6)
									bk6 = kk6
							var ns6: int = pl.samp.size()
							print("    tightest bend at zoom 1: radius %.1f px, in %s" % [1.0 / maxf(deg_to_rad(tb6), 1e-4), ("the insertion (tail %d of %d)" % [bk6 - ns6, pl.tail.size()]) if bk6 >= ns6 else ("the flight at %.2f s of %.2f (escape %.2f, burning %s)" % [bk6 * pl.sdt, pl.dur, pl.esc_t, pl.burns[bk6] == 1])])
						if cv > 20.0 and _why != "":
							# which sample it is nearest, and what the ship is doing there
							var cpx: Vector2 = _worst_px[2] / zz
							var bestd := INF
							var bk := 0
							for kk3 in path3.size():
								var q3 := Vector2(path3[kk3].x, path3[kk3].z * 0.38 - path3[kk3].y * 0.925)
								if q3.distance_to(cpx) < bestd:
									bestd = q3.distance_to(cpx)
									bk = kk3
							var ns3: int = pl.samp.size()
							var part := "the insertion (tail %d of %d)" % [bk - ns3, pl.tail.size()] if bk >= ns3 else "the flight at %.3f s of %.2f (escape %.2f, burning %s)" % [bk * pl.sdt, pl.dur, pl.esc_t, pl.burns[bk] == 1]
							var vq := Vector3.ZERO
							if bk > 0 and bk < ns3 - 1:
								vq = (pl.samp[bk + 1] - pl.samp[bk - 1]) / (2.0 * pl.sdt)
							print("    corner at zoom %d is in %s; speed there %.1f px/s" % [int(zz), part, vq.length()])
						if tv > float(_turn_at.get("plan z%d" % int(zz), [0.0])[0]):
							_turn_at["plan z%d" % int(zz)] = [tv, where]
					if (key == "free" or key == "star") and i == targets[0]:
						fl.predict(t, {"w": false, "a": false, "s": false, "d": false})
						var ln: Dictionary = fl.line
						if not ln.is_empty():
							var fp := PackedVector3Array()
							for q2: Vector2 in ln.pts:
								fp.append(Vector3(q2.x, 0.0, q2.y))
							for zz2: float in [1.0, 2.0]:
								var tv2 := _turn_max(fp, zz2)
								_turns["forecast z%d" % int(zz2)].append(tv2)
								_corner_only = true
								_corners["forecast z%d" % int(zz2)].append(_turn_max(fp, zz2))
								_corner_only = false
								if tv2 > float(_turn_at.get("forecast z%d" % int(zz2), [0.0])[0]):
									_turn_at["forecast z%d" % int(zz2)] = [tv2, where]
					for wk2 in ["speed", "acc", "plan_ms", "dur", "kink"]:
						if float(m[wk2]) > float(worst[wk2]):
							worst[wk2] = m[wk2]
							worst_at[wk2] = where
					# FLOWN: the plan, then the insertion, through the ship's own step
					var fm := _fly(fl, i, t)
					tot.flown += 1
					if fm.landed:
						tot.landed += 1
					else:
						worst_at["not landed %d" % tot.flown] = where
					if String(pl.kind) != "unclean":
						if float(fm.frame_dv) > float(worst.get("clean_dv", 0.0)):
							worst["clean_dv"] = fm.frame_dv
							worst_at["clean_dv"] = where + " at %.2f s (%s)" % [fm.at, fm.mode]
						worst["clean_ratio"] = maxf(float(worst.get("clean_ratio", 0.0)), float(fm.frame_ratio))
					for wk3 in ["frame_dv", "frame_ratio"]:
						if float(fm[wk3]) > float(worst[wk3]):
							worst[wk3] = fm[wk3]
							worst_at[wk3] = where + " at %.2f s (%s)" % [fm.at, fm.mode]
					rows.append([where, String(pl.kind), m, fm])
	print("flighttest: %d plans: %d direct, %d round a waypoint, %d half-ellipses to the close orbit, %d needing a coast over 5 s, %d unclean, %d none" % [tot.plans, tot.direct, tot.waypoint, tot.hohmann, tot.slow, tot.unclean, tot.none])
	for k in by_start:
		print("  from %-6s %d plans: %d direct, %d waypoint, %d unclean" % [k, by_start[k].plans, by_start[k].direct, by_start[k].waypoint, by_start[k].unclean])
	print("  closest to the star %.1f px (keep-clear %s); closest to a world's disc edge %.1f px" % [worst.star, "star_r + 32", worst.world])
	print("  top speed %.0f px/s, hardest burn %.0f px/s², longest flight %.2f s, slowest plan %.1f ms" % [worst.speed, worst.acc, worst.dur, worst.plan_ms])
	print("  over 1,200 px/s: %d; over 5,000 px/s²: %d" % [int(tot.get("fast", 0)), int(tot.get("hard", 0))])
	for tk in _turns:
		var arr: Array = _turns[tk]
		arr.sort()
		if not arr.is_empty():
			var over := arr.filter(func(x: float) -> bool: return x > 8.0).size()
			print("  sharpest turn of the drawn %s, degrees per px: median %.2f, 99th %.2f, worst %.1f; over 8 deg/px (a corner): %d of %d; worst at %s" % [tk, arr[arr.size() / 2], arr[int(arr.size() * 0.99)], arr[-1], over, arr.size(), _turn_at.get(tk, [0, ""])[1]])
	for ck in _corners:
		var arr2: Array = _corners[ck]
		arr2.sort()
		if not arr2.is_empty():
			var over2 := arr2.filter(func(x: float) -> bool: return x > 20.0).size()
			print("  corners in the drawn %s (turn over 2 px, deg per px; a corner over 20): median %.2f, 99th %.2f, worst %.1f; corners: %d of %d" % [ck, arr2[arr2.size() / 2], arr2[int(arr2.size() * 0.99)], arr2[-1], over2, arr2.size()])
	for ck2 in _cat:
		var c: Dictionary = _cat[ck2]
		var r1: Array = c.r1
		var r2: Array = c.r2
		var du: Array = c.dur
		r1.sort()
		r2.sort()
		du.sort()
		var off: Array = c.off
		var sb: Array = c.s
		off.sort()
		var sbt := 0
		var sbn := 0
		for x in sb:
			sbt += int(x)
			if int(x) > 0:
				sbn += 1
		var sw: Array = c.sw
		sw.sort()
		var loops := sw.filter(func(x: float) -> bool: return x > 300.0).size()
		var an := 0
		var at_ := 0
		for x2 in c.arr:
			at_ += int(x2)
			if int(x2) > 0:
				an += 1
		print("  %-20s arriving: S-bends (an overshoot and hook back) %d in %d flights" % [ck2, at_, an])
		print("  %-20s away from the rings: tightest bend median %.0f px, worst tenth %.0f, worst %.1f; S-bends (a bend one way then hard the other) %d in %d flights; turning in all median %.0f deg, worst tenth %.0f, over 300 deg (a lobe) %d" % [ck2, off[off.size() / 2], off[int(off.size() * 0.1)], off[0], sbt, sbn, sw[sw.size() / 2], sw[int(sw.size() * 0.9)], loops])
		print("  %-20s %4d flights: tightest bend (radius, screen px) at zoom 1 median %.0f, worst tenth %.0f, worst %.1f; at zoom 2 median %.0f, worst tenth %.0f, worst %.1f; corners %d / %d; flight median %.1f s, longest %.1f s" % [ck2, c.n,
			r1[r1.size() / 2], r1[int(r1.size() * 0.1)], r1[0], r2[r2.size() / 2], r2[int(r2.size() * 0.1)], r2[0], c.c1, c.c2, du[du.size() / 2], du[-1]])
	print("  S-bends by where: %s" % _s_where)
	_kinks.sort()
	if not _kinks.is_empty():
		print("  the pull's biggest jump from one sample to the next (a kink), px/s² per sample: median %.0f, 90th %.0f, 99th %.0f, worst %.0f" % [_kinks[_kinks.size() / 2], _kinks[int(_kinks.size() * 0.9)], _kinks[int(_kinks.size() * 0.99)], _kinks[-1]])
	_ms.sort()
	if not _ms.is_empty():
		print("  planning: median %.1f ms, 90th %.1f, 99th %.1f, worst %.1f" % [_ms[_ms.size() / 2], _ms[int(_ms.size() * 0.9)], _ms[int(_ms.size() * 0.99)], _ms[-1]])
	print("  flown %d, on the orbit at the end %d; biggest frame-to-frame change of velocity %.1f px/s, %.1fx its neighbours" % [tot.flown, tot.landed, worst.frame_dv, worst.frame_ratio])
	print("  over the clean flights: biggest frame-to-frame change of velocity %.1f px/s, %.1fx its neighbours" % [float(worst.get("clean_dv", 0.0)), float(worst.get("clean_ratio", 0.0))])
	for k2 in worst_at:
		print("    worst %s: %s" % [k2, worst_at[k2]])
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"tot": tot, "worst": worst, "worst_at": worst_at, "by_start": by_start}))
		f.close()
	get_tree().quit()


## Put the ship where the start says.
func _start(fl, L: SystemLayout, kind: String, b: int, t: float, seed: int) -> void:
	var R := RandomNumberGenerator.new()
	R.seed = seed * 31 + kind.hash()
	match kind:
		"orbit":
			fl.place_at(b, t)
			fl.rail.ang = R.randf() * TAU
		"close":
			fl.place_at(-1, t)
			fl.rail.ang = R.randf() * TAU
		"star":
			var r := lerpf(fl.star_ring() + 40.0, L.edge * 0.8, R.randf())
			var a := R.randf() * TAU
			fl.mode = &"free"
			fl.f.p = _clear_of_worlds(fl, L, Vector2(cos(a), sin(a)) * r, t)
			r = fl.f.p.length()
			fl.f.orbit_r = r
			fl.f.v = fl.star_orbit_v(fl.f.p, r)
		"free":
			var r2 := lerpf(fl.star_ring() + 40.0, L.edge * 0.9, R.randf())
			var a2 := R.randf() * TAU
			fl.mode = &"free"
			fl.f.p = Vector2(cos(a2), sin(a2)) * r2
			fl.f.p = _clear_of_worlds(fl, L, fl.f.p, t)
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
			# clear of the star's bumper, as the game keeps a ship (round the
			# world until it is)
			for _k3 in 12:
				if fl.f.p.length() > fl.keep_clear() + 12.0:
					break
				a3 += TAU / 12.0
				fl.f.p = Vector2(c3.x, c3.z) + Vector2(cos(a3), sin(a3)) * ra3 * d3
			fl.f.orbit_r = -1.0
			fl.f.v = Vector2(cv3.x, cv3.z) + Vector2(R.randf_range(-120, 120), R.randf_range(-120, 120))


## The plan's own numbers: closest to the star, to any world's disc (not the one
## it leaves while leaving, nor the one it comes to as it comes), top speed and
## burn.
func _measure(fl, L: SystemLayout, pl, i: int, t: float, from_b: int) -> Dictionary:
	var m := {"star": INF, "world": INF, "speed": 0.0, "acc": 0.0, "kink": 0.0}
	var n: int = pl.samp.size()
	var pv := Vector3.INF
	for k in range(0, n, 2):
		var q: Vector3 = pl.samp[k]
		var tk: float = float(pl.t0) + k * pl.sdt
		if not (i < 0 and (n - k) * pl.sdt < 0.4):
			m.star = minf(m.star, Vector2(q.x, q.z).length() - L.star_r)
		for b in L.bodies:
			if b.world == &"":
				continue
			if b.index == from_b and k * pl.sdt < pl.esc_t + 0.3:
				continue
			if b.index == i and (n - k) * pl.sdt < 0.5:
				continue
			var c: Vector3 = fl.center(b.index, tk)
			m.world = minf(m.world, Vector2(q.x - c.x, q.z - c.z).length() - b.r)
		# A KINK: the pull changing from one sample to the next far more than it
		# does along the rest of the path (a join that matches motion but not pull)
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


## Flown at 60 a second through the ship's own step, the flight and then the
## insertion: on the orbit at the end, and the biggest frame-to-frame change of
## velocity (against the frames either side, a snap's tell).
func _fly(fl, i: int, t0: float) -> Dictionary:
	var out := {"landed": false, "frame_dv": 0.0, "frame_ratio": 0.0, "at": 0.0, "mode": ""}
	var pl = fl.fly(i, t0, func() -> void: pass)
	if pl == null:
		return out
	if ShipFlightS.why:
		print("    flown: kind %s, dur %.2f, esc %.2f, lead %.2f, t0 %.2f vs %.2f, samples %d" % [pl.kind, pl.dur, pl.esc_t, pl.lead, pl.t0, t0, pl.samp.size()])
	var dt := 1.0 / 60.0
	var t := t0
	var none := {"w": false, "a": false, "s": false, "d": false}
	var ps: Array = []
	var modes: Array = []
	var p := Vector3.ZERO
	for k in int(16.0 / dt):
		t += dt
		fl.step(dt, t, none)
		p = fl.where3()
		ps.append(Vector2(p.x, p.z))
		modes.append(String(fl.mode) + (" inserting" if fl.inserting() else ""))
		if fl.reached() == i and k > 2:
			out.landed = true
			# a few frames on the orbit too
			for _j in 6:
				t += dt
				fl.step(dt, t, none)
				p = fl.where3()
				ps.append(Vector2(p.x, p.z))
				modes.append(String(fl.mode))
			break
	var dvs: Array = [0.0, 0.0]
	for k2 in range(2, ps.size()):
		var v1: Vector2 = (ps[k2] - ps[k2 - 1]) / dt
		var v0: Vector2 = (ps[k2 - 1] - ps[k2 - 2]) / dt
		dvs.append((v1 - v0).length())
	if ShipFlightS.why:
		for k4 in range(2, dvs.size()):
			if float(dvs[k4]) > 40.0:
				print("    frame %d (%.2f s, %s): dv %.0f, at %s; around %s %s" % [k4, k4 * dt, modes[k4], dvs[k4], (ps[k4] as Vector2).round(), ps.slice(maxi(k4 - 3, 0), k4 + 2), modes.slice(maxi(k4 - 3, 0), k4 + 2)])
	for k3 in range(3, dvs.size() - 1):
		var d: float = dvs[k3]
		var ratio := d / ((float(dvs[k3 - 1]) + float(dvs[k3 + 1])) / 2.0 + 2.0)
		if d > float(out.frame_dv):
			out.frame_dv = d
			out.at = k3 * dt
			out.mode = modes[k3]
		out.frame_ratio = maxf(float(out.frame_ratio), ratio)
	return out


## ANOTHER PLACE CHOSEN ON THE WAY (Jon: "You have to be IN AN ORBIT ... AND
## THEN CLICK to go to another planet"): flights out of a world's orbit and out
## of the star orbit, flown frame by frame. Counted: frames where a flight could
## start while it should not (on the way, burning onto an orbit, riding round
## to leave); then, once settled, the plan to another place -- none, degenerate
## (not a number, off the map, through the star), how far out it swings and
## turns, how much it moves as the map replans it every half second for 3 s --
## and whether it lands.
func _run_retarget() -> void:
	Rng.forced = 4242 if _one_seed < 0 else _one_seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var none := {"w": false, "a": false, "s": false, "d": false}
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
			if fl.fly(first, t0, func() -> void: pass) == null:
				continue
			tot.tries += 1
			var where := "system %d, %s %d -> %d, then %d" % [n.index, cs[0], cs[1], first, j]
			# ON THE WAY: no flight may start until it is settled in its orbit
			var t := t0
			var settled := false
			for _f in int(30.0 / dt):
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
			var pa = fl.make_plan(j, t)
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
				var pn = fl.make_plan(j, t, choice)
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
			moves.append(worst)
			if worst > 6.0 and shown < 24:
				shown += 1
				print("  MOVED %.1f px in a half second: %s" % [worst, where])
			# and flown from there
			var ok := false
			fl.fly(j, t, func() -> void: pass, choice)
			for _k in int(20.0 / dt):
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
	get_tree().quit()


## OUT OF THE STAR ORBIT (Jon: "the projected orbit path is updating constantly
## and can create some WEIRD shapes"): star orbits at three sizes, the ship at
## six points round each, to every world. Each plan measured as drawn (turning in
## all, S-bends, lobes, tightest bend away from the rings) and then held: the
## ship rides on for 3 s and the map's replan (every half second, keeping its
## choice) is compared with the last -- how far its line moved.
func _run_starride() -> void:
	Rng.forced = 4242 if _one_seed < 0 else _one_seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var none := {"w": false, "a": false, "s": false, "d": false}
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
					fl.mode = &"free"
					fl.f.p = _clear_of_worlds(fl, L, Vector2(cos(a), sin(a)) * r, t0)
					fl.f.orbit_r = fl.f.p.length()
					fl.f.v = fl.star_orbit_v(fl.f.p, fl.f.orbit_r)
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
							print("    moved %.1f: was %s now %s; ship r %.1f" % [mv, choice, pn.choice, fl.f.p.length()])
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
## through the star's disc.
func _degenerate(fl, L: SystemLayout, pl) -> String:
	for q: Vector3 in pl.samp:
		if is_nan(q.x) or is_nan(q.z) or is_inf(q.x) or is_inf(q.z):
			return "not a number"
		if Vector2(q.x, q.z).length() > L.edge * 1.6:
			return "off the map"
		if Vector2(q.x, q.z).length() < L.star_r + 2.0:
			return "through the star"
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
## round the star until it is clear).
func _clear_of_worlds(fl, L: SystemLayout, p: Vector2, t: float) -> Vector2:
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
		p = p.rotated(0.17)
	return p


## The sharpest turn of a path as drawn at `zoom` (on screen, the plane's tilt
## and height as the map projects them), in degrees per pixel: resampled to
## 1 px steps, the turn over 3 px either side of each point, over 6 px.
func _turn_max(p3: PackedVector3Array, zoom: float) -> float:
	var sp := PackedVector2Array()
	for q in p3:
		sp.append(Vector2(q.x, q.z * 0.38 - q.y * 0.925) * zoom)
	var px := PackedVector2Array()
	if sp.size() < 2:
		return 0.0
	px.append(sp[0])
	var carry := 0.0
	for j in range(1, sp.size()):
		var a := sp[j - 1]
		var b := sp[j]
		var seg := a.distance_to(b)
		var d := 1.0 - carry
		while d <= seg:
			px.append(a.lerp(b, d / seg))
			d += 1.0
		carry = seg - (d - 1.0)
	# over 6 px (any tight bend), or over 2 px (a CORNER: the turn all in one
	# pixel -- a smooth curve turns as much a pixel over 2 px as over 6)
	var worst := 0.0
	var w := 3 if not _corner_only else 1
	for k in range(w, px.size() - w):
		var u := px[k] - px[k - w]
		var v := px[k + w] - px[k]
		if u.length() < float(w) * 0.8 or v.length() < float(w) * 0.8:
			continue
		var tv := rad_to_deg(absf(u.angle_to(v))) / float(2 * w)
		if tv > worst:
			worst = tv
			_worst_px = [k, px.size(), px[k]]
	return worst


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
		if i == -1 and Vector2(q.x, q.z).length() < fl.star_ring() + 30.0:
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
