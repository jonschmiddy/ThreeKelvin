extends Node

## SCRATCH (the flight-length study, Nov 1; not for the repo). Kept in
## tk-scratch/twin-build/flightlen/, copied into a detached worktree to run.
##
##   -- sheet=FlightLen mode=explore grid=NAME:TW:CAP[:CAPW];... [seeds=4242,7]
##        [one=N] [giant=N] [twin=N] [click=0.5] out=<json>
##      FlightTest's game starts (out of a world's orbit, a star's close orbit,
##      a settled star orbit, the edge as arrived, alongside) to every place,
##      in FlightTest's own systems (its pools and `_spread`), for each setting
##      of the grid: the preview planned as the map's worker plans it
##      (PREVIEW_AHEAD), clicked `click` s later and flown through ShipFlight
##      at 30 a second to settled. NAME TODAY flies today's planner instead.
##
##   -- sheet=FlightLen mode=replay set.B=TW:CAP[:CAPW] set.C=TW:CAP[:CAPW] out=<json>
##      Eight flights in real systems (seed 4242), each flown as built (A), at
##      B and C, and by today's planner (TODAY), from the same start and the
##      same click, through the real map opened headless (SystemMapScreen):
##      its view's projection, its overlay's drawn line and drawn ship.
##
##   THE EDGE FIX (Nov 1, after the skeptic): one-edge starts where the game
##   puts a ship just arrived by jump (`_game_edge`), not at the map's own
##   headless edge point, which `show_system` worked out before the frame had a
##   size (`SystemView.show_system` returns before any await headless). Every
##   run also carries the flame's length (`fl`), the overlay's ring scale
##   (`ok`), and 1.4 s of the ride before the click (`pre`, `pre_ok`, `pre_fl`).

const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")
const FlightTestS := preload("res://scripts/sim/FlightTest.gd")
const SystemOverlayS := preload("res://scripts/ui/sysmap/SystemOverlay.gd")
const NONE := {"w": false, "a": false, "s": false, "d": false}
const DT := 1.0 / 60.0

var _ft
var _mode := "explore"
var _out := ""
var _seeds: Array = [4242, 7]
var _per := {"one": 3, "giant": 2, "twin": 3}
var _grid: Array = []
var _click_d := 0.5
var _sets := {}
var _seed_replay := 4242


func _ready() -> void:
	_ft = FlightTestS.new()
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("mode="):
			_mode = s.substr(5)
		elif s.begins_with("out="):
			_out = s.substr(4)
		elif s.begins_with("seeds="):
			_seeds = []
			for x in s.substr(6).split(","):
				_seeds.append(int(x))
		elif s.begins_with("one="):
			_per.one = int(s.substr(4))
		elif s.begins_with("giant="):
			_per.giant = int(s.substr(6))
		elif s.begins_with("twin="):
			_per.twin = int(s.substr(5))
		elif s.begins_with("click="):
			_click_d = float(s.substr(6))
		elif s.begins_with("rseed="):
			_seed_replay = int(s.substr(6))
		elif s.begins_with("grid="):
			for g in s.substr(5).split(";"):
				_grid.append(_parse_set(g))
		elif s.begins_with("set."):
			var kv := s.substr(4).split("=")
			var d := _parse_set(kv[0] + ":" + kv[1])
			_sets[d.name] = d
	_run.call_deferred()


static func _parse_set(g: String) -> Dictionary:
	var p := g.split(":")
	var d := {"name": p[0]}
	if p.size() >= 3:
		d.tw = float(p[1])
		d.cap = float(p[2])
	if p.size() >= 4 and p[3] != "":
		d.capw = float(p[3])
	if p.size() >= 5 and p[4] != "":
		d.lead = float(p[4])
	if p.size() >= 6 and p[5] != "":
		d.back = float(p[5])
	for kw in p.slice(6):
		if kw == "noscale":
			d.scale = false
		elif kw == "both":
			d.both = true
	return d


func _run() -> void:
	await get_tree().process_frame
	var t_all := Time.get_ticks_msec()
	if _mode == "explore":
		_explore()
	elif _mode == "replay":
		await _replay()
	elif _mode == "probe":
		_probe()
	elif _mode == "probe2":
		_probe2()
	elif _mode == "probe3":
		_probe3()
	print("flightlen: all of it took %.0f s" % ((Time.get_ticks_msec() - t_all) / 1000.0))
	get_tree().quit(0)


# ============================================================== the grid
## FlightTest's systems and its game starts, every place each.
func _gather() -> Array:
	var cases: Array = []
	for sd: int in _seeds:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		var pool := {"one": [], "giant": [], "twin": []}
		for raw in Run.map:
			var n: MapGen.MapNode = raw
			if n.type != MapGen.NodeType.SYSTEM and n.type != MapGen.NodeType.PULSAR and n.type != MapGen.NodeType.STATION:
				continue
			OptionTable.ensure(n)
			var was := n.twin
			n.twin = false
			var L := SystemLayout.of(n)
			var sweep := "giant" if L.bodies.any(func(b: SystemLayout.Body) -> bool: return b.gm > 0.0) else "one"
			(pool[sweep] as Array).append([n, L])
			if MapGen.twin_ok(n):
				n.twin = true
				var L2 := SystemLayout.of(n)
				if L2.twin:
					(pool.twin as Array).append([n, L2])
			n.twin = was
		for sw: String in ["one", "giant", "twin"]:
			var all_of: Array = pool[sw]
			for k: int in FlightTestS._spread(all_of.size(), int(_per[sw])):
				var n2: MapGen.MapNode = all_of[k][0]
				var L3: SystemLayout = all_of[k][1]
				var targets: Array = []
				for s0 in L3.stars():
					targets.append(s0)
				for b in L3.bodies:
					targets.append(b.index)
				var starts: Array = []
				for b in L3.bodies:
					if b.world != &"":
						starts.append(["orbit", b.index])
				for s1 in L3.stars():
					starts.append(["close", s1])
				starts.append(["star", 0])
				starts.append(["edge", 0])
				for b in L3.bodies:
					if b.kind == &"station" or b.kind == &"belt" or b.kind == &"derelict" or b.kind == &"contact":
						starts.append(["keep", b.index])
						break
				var t := 40.0 + float(n2.index % 17) * 13.0
				for st: Array in starts:
					for i: int in targets:
						if (st[0] == "orbit" or st[0] == "close" or st[0] == "keep") and int(st[1]) == i:
							continue
						cases.append({"sweep": sw, "seed": sd, "sys": n2.index, "L": L3, "key": st[0], "b": st[1], "i": i, "t": t})
	return cases


func _explore() -> void:
	var cases := _gather()
	print("flightlen: %d cases (seeds %s, systems a sweep %s)" % [cases.size(), _seeds, _per])
	var all := {}
	for g: Dictionary in _grid:
		var t_g := Time.get_ticks_msec()
		var today: bool = g.name == "TODAY"
		var line := "today's planner (_old_plan)" if today else FlightSolve.tune(g)
		var rows: Array = []
		for c: Dictionary in cases:
			rows.append(_eval(c, today))
		var summ := _summ(cases, rows)
		var packed: Array = []
		for r: Dictionary in rows:
			packed.append([1 if r.get("skip", false) else 0, 1 if r.get("put", false) else 0, 1 if r.get("found", false) and r.get("clean", false) else 0, snappedf(float(r.get("click", -1.0)), 0.01), int(r.get("legs", 1)),
				snappedf(float(r.get("T", -1.0)), 0.01), snappedf(float(r.get("work", -1.0)), 0.1), snappedf(float(r.get("ms", 0.0)), 0.1)])
		all[g.name] = {"setting": line, "g": g, "summ": summ, "rows": packed}
		print("flightlen: setting %s: %s (%.0f s)" % [g.name, line, (Time.get_ticks_msec() - t_g) / 1000.0])
		for sw: String in ["one", "giant", "twin"]:
			var S: Dictionary = summ[sw]
			print("  %s: %d game starts: found and clean %d, today's planner %d, put there %d, two legs %d (time %s); click to settled %s; out of a place %s; plan T %s; ride %s; work %s; planning ms %s; not the drawn flight %d" % [
				sw, S.n, S.ok, S.fb, S.put, S.legs2, S.chainT, S.click, S.click_place, S.T, S.lead, S.work, S.ms, S.notsame])
	FlightSolve.tune({})
	if _out != "":
		var meta: Array = []
		for c: Dictionary in cases:
			meta.append([c.sweep, c.seed, c.sys, c.key, c.b, c.i])
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"cases": meta, "settings": all}))
		f.close()


## One case: the preview, the click `_click_d` on, flown to settled.
func _eval(c: Dictionary, today: bool) -> Dictionary:
	var L: SystemLayout = c.L
	var i: int = c.i
	var t: float = c.t
	var fl = ShipFlightS.new()
	fl.setup(L, Vector2(-L.edge * 0.95, 0.0), t)
	_ft._start(fl, L, String(c.key), int(c.b), t, int(c.sys))
	fl.step(DT, t, NONE)
	if fl.orbit_body() == i or not fl.can_fly():
		return {"skip": true}
	if today and L.twin:
		return {"skip": true}
	var r := {"put": false, "found": false, "clean": false, "fb": false, "legs": 1, "T": -1.0, "lead": -1.0, "work": -1.0, "ms": 0.0, "click": -1.0, "same": true}
	var pv = null
	if today:
		pv = fl._old_plan(i, t)
	else:
		var us := Time.get_ticks_usec()
		pv = fl.make_plan(i, t, {}, ShipFlightS.PREVIEW_AHEAD)
		r.ms = float(Time.get_ticks_usec() - us) / 1000.0
		if pv == null:
			r.put = true
			return r
		if pv.res != null:
			r.found = true
			r.clean = pv.res.clean
			r.legs = pv.res.legs
			r.T = pv.res.T
			r.lead = pv.res.lead
			r.work = pv.res.work
		else:
			r.fb = true
	var tt := t
	while tt + DT <= t + _click_d + 1e-9:
		tt += DT
		fl.step(DT, tt, NONE)
	var got = null
	if today:
		# (main's click: the preview's own choice, its arrival time kept)
		var po = FlightTestS.today_click(fl, i, tt, pv)
		pv = null
		if po == null:
			r.put = true
			return r
		po.to = i
		po.t_plan = tt
		r.found = true
		r.clean = true
		got = fl.fly(i, tt, func() -> void: pass, {}, po)
	else:
		got = fl.fly(i, tt, func() -> void: pass, pv.choice, pv)
	if got == null:
		return r
	if pv != null:
		r.same = (pv.res != null and got.res == pv.res) or got == pv
	var t0 := tt
	var dt2 := 1.0 / 30.0
	for k in int(110.0 / dt2):
		tt += dt2
		fl.step(dt2, tt, NONE)
		if fl.reached() == i and k > 0:
			r.click = tt - t0
			break
	return r


static func _d(xs: Array) -> String:
	if xs.is_empty():
		return "(none)"
	var s := xs.duplicate()
	s.sort()
	var n := s.size()
	return "median %.2f, 90th %.2f, worst %.2f (%d)" % [float(s[n / 2]), float(s[mini(n - 1, int(n * 0.9))]), float(s[n - 1]), n]


func _summ(cases: Array, rows: Array) -> Dictionary:
	var out := {}
	for sw: String in ["one", "giant", "twin"]:
		var n := 0
		var ok := 0
		var fb := 0
		var put := 0
		var legs2 := 0
		var notsame := 0
		var chT: Array = []
		var ms: Array = []
		var T: Array = []
		var lead: Array = []
		var work: Array = []
		var click: Array = []
		var click_p: Array = []
		for k in cases.size():
			var c: Dictionary = cases[k]
			var r: Dictionary = rows[k]
			if c.sweep != sw or r.get("skip", false):
				continue
			n += 1
			if r.put:
				put += 1
			if r.fb:
				fb += 1
			if r.found and r.clean:
				ok += 1
			if not r.get("same", true):
				notsame += 1
			if float(r.ms) > 0.0:
				ms.append(float(r.ms))
			if r.found and float(r.T) >= 0.0:
				T.append(float(r.T))
				lead.append(float(r.lead))
				work.append(float(r.work))
			if int(r.legs) == 2:
				legs2 += 1
			if float(r.click) >= 0.0:
				click.append(float(r.click))
				if c.key == "orbit" or c.key == "close" or c.key == "keep":
					click_p.append(float(r.click))
				if int(r.legs) == 2:
					chT.append(float(r.click))
		out[sw] = {"n": n, "ok": ok, "fb": fb, "put": put, "legs2": legs2, "notsame": notsame, "chainT": _d(chT), "ms": _d(ms), "T": _d(T),
			"lead": _d(lead), "work": _d(work), "click": _d(click), "click_place": _d(click_p)}
	return out


# ============================================================== the replays
const STAR_PAL := [
	Vector3(5.0, 6.0, 10.0), Vector3(11.0, 18.0, 32.0), Vector3(51.0, 68.0, 90.0), Vector3(201.0, 216.0, 234.0), Vector3(255.0, 255.0, 255.0),
	Vector3(30.0, 8.0, 4.0), Vector3(58.0, 14.0, 8.0), Vector3(94.0, 22.0, 8.0), Vector3(132.0, 40.0, 12.0), Vector3(168.0, 58.0, 16.0),
	Vector3(194.0, 74.0, 20.0), Vector3(224.0, 106.0, 32.0), Vector3(236.0, 122.0, 38.0), Vector3(248.0, 154.0, 58.0), Vector3(255.0, 176.0, 84.0),
	Vector3(255.0, 208.0, 112.0), Vector3(255.0, 220.0, 150.0), Vector3(255.0, 238.0, 192.0), Vector3(255.0, 246.0, 226.0), Vector3(42.0, 6.0, 8.0),
	Vector3(74.0, 12.0, 12.0), Vector3(110.0, 20.0, 16.0), Vector3(150.0, 32.0, 24.0), Vector3(188.0, 50.0, 32.0), Vector3(216.0, 74.0, 42.0),
	Vector3(238.0, 106.0, 58.0), Vector3(255.0, 138.0, 80.0), Vector3(106.0, 26.0, 52.0), Vector3(160.0, 40.0, 74.0), Vector3(216.0, 74.0, 106.0),
	Vector3(255.0, 122.0, 138.0), Vector3(10.0, 16.0, 48.0), Vector3(16.0, 32.0, 96.0), Vector3(26.0, 58.0, 138.0), Vector3(42.0, 90.0, 184.0),
	Vector3(74.0, 138.0, 216.0), Vector3(138.0, 208.0, 240.0), Vector3(200.0, 240.0, 255.0), Vector3(230.0, 246.0, 255.0), Vector3(52.0, 120.0, 160.0),
	Vector3(79.0, 166.0, 196.0), Vector3(42.0, 24.0, 16.0), Vector3(74.0, 42.0, 24.0), Vector3(106.0, 62.0, 34.0)]
const RAMP_SUN := [7, 10, 12, 14, 16, 18]
const RAMP_RED := [19, 21, 23, 25, 26, 14]
const RAMP_BLU := [33, 34, 35, 36, 37, 4]
## a world's look as its ramp in Worlds.RAMP (the planet shader's own pairing
## where the names match; the rest by eye from the shader's kinds)
const WORLD_RAMP := {&"lava": &"glow", &"verdant": &"land", &"ocean": &"sea", &"eyeball": &"ice", &"hotjup": &"storm",
	&"cracked": &"lineae", &"hurricane": &"sea", &"haze": &"haze", &"volcanic": &"ash", &"biolum": &"alien",
	&"megacity": &"city", &"shattered": &"rock", &"carbonA": &"graphite", &"carbonB": &"tar", &"carbonC": &"diamond",
	&"scorched": &"scorch", &"rogue": &"carbon", &"aurora": &"sea", &"lightning": &"storm2", &"comet": &"ice",
	&"europa": &"ice", &"swamp": &"swamp"}

var _fw := 0.0
var _fo := Vector2.ZERO


## The sun shader's face ramp (`sun.gdshader` `ramp`), at v in 0..1, as 0..255.
static func _sun_ramp(kind: int, v: float) -> Vector3:
	var x := clampf(v, 0.0, 0.999) * 5.0
	var i := int(floor(x))
	var rr: Array = RAMP_RED if kind == 1 else (RAMP_BLU if kind == 2 else RAMP_SUN)
	var a: Vector3 = STAR_PAL[rr[i]]
	var b: Vector3 = STAR_PAL[rr[i + 1]]
	return a.lerp(b, x - float(i))


static func _rgb(v: Vector3) -> Array:
	return [roundi(clampf(v.x, 0.0, 255.0)), roundi(clampf(v.y, 0.0, 255.0)), roundi(clampf(v.z, 0.0, 255.0))]


static func _hex_rgb(h: String) -> Array:
	var c := Color(h)
	return [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]


static func _r1(x: float) -> float:
	return snappedf(x, 0.1)


static func _r2(x: float) -> float:
	return snappedf(x, 0.01)


## A screen point (the view's own coordinates) in the frame's, to 0.1 px.
func _fp(q: Vector2) -> Array:
	return [_r1(q.x - _fo.x), _r1(q.y - _fo.y)]


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## The ordinary one-star SYSTEM (no giant, no twin) with the most worlds (at
## least `least`), the first such in the run's map.
func _pick_one(least: int) -> MapGen.MapNode:
	var best: MapGen.MapNode = null
	var best_w := least - 1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM or n.twin:
			continue
		OptionTable.ensure(n)
		var L := SystemLayout.of(n)
		if L.twin or L.star != SystemLayout.StarKind.ORDINARY:
			continue
		if L.bodies.any(func(b: SystemLayout.Body) -> bool: return b.gm > 0.0):
			continue
		var w := 0
		for b in L.bodies:
			if b.world != &"" and b.kind != &"belt":
				w += 1
		if w > best_w:
			best_w = w
			best = n
	return best


## The first natural twin (MapGen's own roll) with at least two worlds round both.
func _pick_twin() -> MapGen.MapNode:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM or not n.twin:
			continue
		OptionTable.ensure(n)
		var L := SystemLayout.of(n)
		if not L.twin:
			continue
		var p := 0
		var on_a := 0
		var on_b := 0
		for b in L.bodies:
			if b.world == &"" or b.kind == &"belt":
				continue
			if b.host_id == -9:
				p += 1
			elif b.host_id == -1:
				on_a += 1
			elif b.host_id == SystemLayout.STAR_B:
				on_b += 1
		if p >= 2 and on_a >= 1 and on_b >= 1:
			return n
	return null


## Opens the map on system n as a jump in would (headless), and holds it still:
## nothing of it runs on its own; the study moves its clock.
func _open(n: MapGen.MapNode) -> SystemMapScreen:
	Run.at = n.index
	n.visited = true
	SectorScreen._approached_at = n.index
	SystemMapScreen._parked.clear()
	Router.show_system()
	var m: SystemMapScreen = null
	for _k in 600:
		await get_tree().process_frame
		m = Router.current as SystemMapScreen
		if m != null and m.view != null and m.view.layout != null and m.flight != null and m.view.node == n:
			break
	if m == null:
		return null
	await _frames(30)
	m.set_process(false)
	m.view.set_process(false)
	m.overlay.set_process(false)
	return m


func _replay() -> void:
	Router.animate_in_harness = false
	Rng.forced = _seed_replay
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		(raw as MapGen.MapNode).ambush_rolled = true
		(raw as MapGen.MapNode).ambush_pending = false
	Run.fuel = 99
	var settings := {"A": {}, "B": _sets.get("B", {}), "C": _sets.get("C", {}), "TODAY": {}}
	var setting_out := {}
	for sn: String in ["A", "B", "C"]:
		FlightSolve.tune(settings[sn])
		setting_out[sn] = {"TIME_W": FlightSolve.TIME_W, "T_CAP": FlightSolve.T_CAP, "T_CAP_WIDE": FlightSolve.T_CAP_WIDE,
			"LEAD_MAX": FlightSolve.LEAD_MAX, "conics": FlightSolve.CONIC_TS, "conics_wide": FlightSolve.CONIC_TS_WIDE,
			"WIDE_T": FlightSolve.WIDE_T, "FAR_T": FlightSolve.FAR_T, "CHAIN_T": FlightSolve.CHAIN_T,
			"fallback": ("where the search to T_CAP finds nothing, the sooner of two: the as-built search (TIME_W 0.5, T_CAP %.0f, its guess times) and the wider search at this TIME_W; where both find nothing, the as-built wider one; two-leg flights' legs always by the as-built search" % FlightSolve.T_CAP_BACK) if FlightSolve.T_CAP_BACK > FlightSolve.T_CAP else "none (as built)"}
	setting_out["TODAY"] = {"planner": "ShipFlight._old_plan, the pre-branch autopilot (time-scaled conics round star A), as main's map flew it: the preview made at the selection, the click flown from the preview's own choice (its arrival time kept). Never flown in a twin (ShipFlight._fallback; main had no twins), so the twin flights have none."}
	FlightSolve.tune({})
	var flights: Array = []
	var frame := {}
	var checks: Array = []
	var one := _pick_one(3)
	if one == null:
		# (what the map holds, to see why)
		var shown := 0
		for raw in Run.map:
			var nn: MapGen.MapNode = raw
			if nn.type != MapGen.NodeType.SYSTEM or shown > 24:
				continue
			shown += 1
			OptionTable.ensure(nn)
			var Ld := SystemLayout.of(nn)
			var wn := 0
			var gi := 0
			for bd in Ld.bodies:
				if bd.world != &"" and bd.kind != &"belt":
					wn += 1
				if bd.gm > 0.0:
					gi += 1
			print("  system %d: twin %s/%s, star %d, worlds %d, giants %d, bodies %d" % [nn.index, nn.twin, Ld.twin, int(Ld.star), wn, gi, Ld.bodies.size()])
	var two := _pick_twin()
	print("flightlen: one sun system %d (%s), twin system %d (%s)" % [one.index if one else -1, MapGen.star_name(one) if one else "", two.index if two else -1, MapGen.star_name(two) if two else ""])
	for sysn: MapGen.MapNode in [one, two]:
		if sysn == null:
			continue
		var m := await _open(sysn)
		if m == null:
			print("flightlen: the map did not open on system %d" % sysn.index)
			continue
		var view = m.view
		var L: SystemLayout = view.layout
		_fo = view.window.position
		frame = {"w": _r1(view.window.size.x), "h": _r1(view.window.size.y), "screen_w": 960, "screen_h": 540,
			"note": "every x, y is in the map frame's own game px (0,0 its top-left; the view's window), as SystemView.screen puts it at the zoom the map opened at"}
		print("flightlen: system %d open: zoom %.4f (L.fit_zoom %.4f), pan %s, window %s, frame %s" % [sysn.index, view.zoom, L.fit_zoom, view.pan, view.window, m._frame.size])
		for F: Dictionary in _specs(L, sysn, m):
			var rec := {"id": F.id, "kind": F.kind, "system": sysn.index, "system_name": MapGen.star_name(sysn), "seed": _seed_replay,
				"from": F.from_name, "to": F.to_name, "start": F.key, "start_place": F.b, "target": F.i, "zoom": _r2(view.zoom * 100.0) / 100.0,
				"fit_zoom": L.fit_zoom, "runs": {}}
			if F.has("edge_note"):
				rec.edge_point = F.edge_note
			var secs_max := 0.0
			# (the world tracks run to the latest click of any moment plus the
			# longest flight of any, and 3.5 s more)
			var sel_hi := 0.0
			var secs_hi := 0.0
			for sn2: String in ["A", "B", "C", "TODAY"]:
				# TEN SELECTION MOMENTS, 0.1 s apart (the review of Nov 1: the
				# solver's pick moves by seconds when the selection comes a frame or
				# two later); the run nearest this setting's median is the one kept
				var all_runs: Array = []
				for k in N_SEL:
					var run := _fly_rec(m, L, F, sn2, settings[sn2], float(k) * SEL_STEP)
					all_runs.append(run)
					if not run.has("secs"):
						break
					sel_hi = maxf(sel_hi, float(run.click_at))
					secs_hi = maxf(secs_hi, float(run.secs))
					print("    %s %s sel +%.1f s: %s" % [F.id, sn2, float(k) * SEL_STEP, run.check])
					print("      pre: %s" % run.pre_check)
				var pick := _nearest_median(all_runs)
				var shown: Dictionary = all_runs[pick]
				if shown.has("secs"):
					shown.spread = _spread(all_runs, pick)
					secs_max = maxf(secs_max, float(shown.click_at) + float(shown.secs))
				rec.runs[sn2] = shown
				checks.append("%s %s: %s" % [F.id, sn2, shown.get("check", shown.get("none", "none"))])
				print("  %s %s: %s; %s" % [F.id, sn2, shown.get("check", shown.get("none", "none")), shown.get("spread", {}).get("line", "")])
			FlightSolve.tune({})
			var track_to := sel_hi + secs_hi + 3.5
			print("  %s: world tracks to %.2f s (the shown runs reach %.2f s)" % [F.id, track_to, secs_max])
			rec.scene = _scene(m, L, F, maxf(secs_max, track_to))
			flights.append(rec)
	var o := {"settings": setting_out, "frame": frame, "flights": flights, "checks": checks,
		"note": "Each setting's run is the one nearest its median of ten selection moments 0.1 s apart (spread: every one's click-to-settled s, its selection offset, plan T and engine work). click_at is that run's click in s after the scene's clock zero (scene.click_t, the first moment's click): a world's place at sample time t is scene.worlds[].centre at centre_t = click_at + t. samples [t s from the click, x, y as the map draws the ship (whole px: SystemOverlay._draw_ship's two roundings, out on its ring at the ring's drawn size), heading deg (the nose on screen, 0 = right, + clockwise), burn 0/1, phase]; exact [x, y] the same point unrounded; raw [x, y] the ship's own point through SystemView.screen, unrounded; line [x, y, burn] the flight as SystemOverlay draws its plan (_plan_line, _drawn_ends, _scr), hidden the indices it hides behind a sun or a nearer world at the click. World and star centres are on the map's 2 px block grid (SystemView.block_round), as the map draws them."}
	o.note_added = NOTE_ADDED
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(JSON.stringify(o))
		f.close()
		print("flightlen: wrote %s" % _out)


const NOTE_ADDED := "Added Nov 1 (the edge fix; every field above unchanged). fl: per run, parallel to samples, the flame's length in px as SystemOverlay._draw_ship works it out that frame: 0 when not burning, else int(4 + 8 bk) + (int(view.t * 30) % 3 - 1) with bk = clamp(burn_k, 0.25, 1.6), burn_k = ShipFlight._flame's clamp(k, 0, 1) * (1 + 0.6 clamp(1 - age / 0.25, 0, 1)) (k the burn's share of its peak, age the burn's age in s), so a burn's first 0.25 s flares up to 1.6x; it is the length of the two outer flames (k = 1..fl behind the stern rows either side of the middle), the middle one runs to min(fl, 3 + int(3 bk)). ok: per run, parallel to samples, [_ok, _ok_body]: the overlay's ring scale (its spring, to 0.0001) and the place it scales from, that frame; the drawn point is out on the ring (round(bw + (round(raw) - bw) * ok), bw that place's centre unrounded) only where ok > 1.001 and ok_body is a place (>= 0, or -1 star A, -4 star B), else round(raw). pre: 1.4 s of the ride before the click, the same format as samples, t from -1.4 to -0.03 every 1/30 s (sample t = 0 is samples[0]), the ship on its departure ring or star orbit as the map draws it; pre_ok and pre_fl the same as ok and fl for it. Where the harness had not yet put the ship there (its start is the click's selection less up to 0.9 s, so up to 0.9 s of pre before it), pre is a second ship put on the same ring or star orbit earlier and stepped by the same code to the same angle (pre_check says how many points and how far its overlap with the flown ship differs), and the overlay's spring there is at rest as at the selection. warp_at (one-edge only): the jump-in's moment in s from the click; the map draws the warp streak for 0.6 s after it and keeps no trail points in that time (SystemOverlay._draw_trail). scene.worlds[].centre_pre_t / centre_pre: each world's centre at -1.5, -1.0 and -0.5 s on the scene clock, on the block grid as centre is, for pre's points (centre_t = click_at + t is negative there). The world tracks (centre_t, centre) now run to at least the latest click_at of any of the ten moments plus the longest secs of any, plus 3.5 s. one-edge's edge_point: the arrival point as SystemMapScreen.show_system works it out with the frame laid out, beside the headless one the study used before."


const N_SEL := 10
const SEL_STEP := 0.1


static func _median(xs: Array) -> float:
	var s := xs.duplicate()
	s.sort()
	var n := s.size()
	if n == 0:
		return -1.0
	return float(s[n / 2]) if n % 2 == 1 else 0.5 * (float(s[n / 2 - 1]) + float(s[n / 2]))


## The run whose click-to-settled is nearest the median of all (the first such).
static func _nearest_median(runs: Array) -> int:
	var xs: Array = []
	for r: Dictionary in runs:
		if r.has("secs"):
			xs.append(float(r.secs))
	if xs.is_empty():
		return 0
	var med := _median(xs)
	var best := 0
	var bd := INF
	for k in runs.size():
		if not (runs[k] as Dictionary).has("secs"):
			continue
		var d := absf(float(runs[k].secs) - med)
		if d < bd - 1e-9:
			bd = d
			best = k
	return best


static func _spread(runs: Array, pick: int) -> Dictionary:
	var secs: Array = []
	var sel: Array = []
	var T: Array = []
	var work: Array = []
	var settled := 0
	for r: Dictionary in runs:
		if not r.has("secs"):
			continue
		secs.append(float(r.secs))
		sel.append(float(r.click_at))
		T.append(float(r.plan.T))
		work.append(float(r.plan.work))
		if r.settled:
			settled += 1
	var lo: float = secs.min()
	var hi: float = secs.max()
	var med := _median(secs)
	return {"secs": secs, "sel": sel, "T": T, "work": work, "median": _r2(med), "min": _r2(lo), "max": _r2(hi), "shown": pick, "settled": settled,
		"line": "%d moments: median %.2f s, %.2f to %.2f, shown +%.1f s (%.2f s)" % [secs.size(), med, lo, hi, float(sel[pick]), float(secs[pick])]}


## THE EIGHT FLIGHTS of this system (four of one sun, four of two): where the
## ship starts, where it goes, when.
func _specs(L: SystemLayout, n: MapGen.MapNode, m: SystemMapScreen) -> Array:
	var out: Array = []
	var t := 40.0 + float(n.index % 17) * 13.0
	if not L.twin:
		# the worlds out from the star
		var ws: Array = []
		for b in L.bodies:
			if b.world != &"" and b.kind != &"belt":
				ws.append(b)
		ws.sort_custom(func(a: SystemLayout.Body, b: SystemLayout.Body) -> bool: return a.orbit < b.orbit)
		var w1: SystemLayout.Body = ws[1]
		var w2: SystemLayout.Body = ws[2]
		# 1. a world to its neighbour out
		out.append(_spec("one-neighbour", "one", L, n, "orbit", w1.index, w2.index, t, 0.6))
		# 2. a world to the world farthest from it then (across the system)
		var far: SystemLayout.Body = ws[0]
		var best := -1.0
		var c0 := ws[0].pos(t) as Vector2
		for b2: SystemLayout.Body in ws:
			var d := (b2.pos(t) - c0).length()
			if d > best and b2.index != ws[0].index:
				best = d
				far = b2
		out.append(_spec("one-across", "one", L, n, "orbit", ws[0].index, far.index, t, 2.0))
		# 3. a settled star orbit between the second and third world, to the outermost
		var sp := _spec("one-starorbit", "one", L, n, "star", 0, (ws[ws.size() - 1] as SystemLayout.Body).index, t, 0.0)
		var rr := (w1.orbit + w2.orbit) * 0.5
		sp.p = Vector2(cos(deg_to_rad(200.0)), sin(deg_to_rad(200.0))) * rr
		sp.sense = 1.0
		sp.from_name = "a settled star orbit, %.0f px out" % rr
		out.append(sp)
		# 4. the edge as the jump in left it, a moment after the map opened, to the middle world
		var se := _spec("one-edge", "one", L, n, "edge", 0, (ws[ws.size() / 2] as SystemLayout.Body).index, 1.0, 0.0)
		se.t_setup = 0.0
		# WHERE THE GAME PUTS A SHIP JUST ARRIVED BY JUMP, the frame laid out
		# (`_game_edge`), not the map's own headless point (`m.flight.edge_at`)
		var ge := _game_edge(m)
		var fq = ShipFlightS.new()
		fq.setup(L, ge, 0.0)
		var fh = ShipFlightS.new()
		fh.setup(L, m.flight.edge_at, 0.0)
		se.edge_pt = ge
		se.edge_note = {"game": [_r2(ge.x), _r2(ge.y)], "game_r": _r1(float(fq.f.orbit_r)), "headless": [_r2(m.flight.edge_at.x), _r2(m.flight.edge_at.y)], "headless_r": _r1(float(fh.f.orbit_r)),
			"window": [_r1(m.view.window.position.x), _r1(m.view.window.position.y), _r1(m.view.window.size.x), _r1(m.view.window.size.y)],
			"zoom_min": m.zoom_min, "zoom_for_frame": SystemMapScreen.zoom_for(L, m.view.node, m._frame.size), "edge": L.edge,
			"rule": "SystemMapScreen.show_system: ex = minf(L.edge, (view.window.end.x - SystemView.CX - 26) / zoom_min), ShipFlight.setup(L, Vector2(ex, -210), t0), whose arrival_r puts the ship on a star orbit clear of every ring"}
		se.from_name = "just arrived by jump: a settled star orbit, %.0f px out" % float(fq.f.orbit_r)
		print("flightlen: one-edge arrival: the game's point %s (orbit r %.1f) against the headless %s (orbit r %.1f); window %s, zoom_min %.4f, zoom_for(frame %s) %.4f, edge %.1f" % [
			ge, float(fq.f.orbit_r), m.flight.edge_at, float(fh.f.orbit_r), m.view.window, m.zoom_min, m._frame.size, SystemMapScreen.zoom_for(L, m.view.node, m._frame.size), L.edge])
		out.append(se)
	else:
		var ptype: Array = []
		for b in L.bodies:
			if b.world != &"" and b.kind != &"belt" and b.host_id == -9:
				ptype.append(b)
		ptype.sort_custom(func(a: SystemLayout.Body, b: SystemLayout.Body) -> bool: return a.orbit < b.orbit)
		# (the worlds round one star: by their host, not their index, which a belt can take)
		var sa := -1
		var sb := -1
		for b3 in L.bodies:
			if b3.world == &"" or b3.kind == &"belt":
				continue
			if b3.host_id == -1 and sa < 0:
				sa = b3.index
			elif b3.host_id == SystemLayout.STAR_B and sb < 0:
				sb = b3.index
		# 5. the world round A to the world round B
		out.append(_spec("twin-AtoB-worlds", "twin", L, n, "orbit", sa, sb, t, 1.0))
		# 6. a world round both (the nearest) to star B
		out.append(_spec("twin-world-to-starB", "twin", L, n, "orbit", (ptype[0] as SystemLayout.Body).index, SystemLayout.STAR_B, t, 3.0))
		# 7. star A's close orbit to star B
		out.append(_spec("twin-starA-to-starB", "twin", L, n, "close", -1, SystemLayout.STAR_B, t, 0.3))
		# 8. the outer world round both to the world round A
		out.append(_spec("twin-circumbinary-to-S", "twin", L, n, "orbit", (ptype[ptype.size() - 1] as SystemLayout.Body).index, sa, t, 4.0))
	# (every other flight is set up from the map's own point as before: its start
	# replaces where setup put it, so nothing of theirs moves)
	for F: Dictionary in out:
		if not F.has("edge_pt"):
			F.edge_pt = m.flight.edge_at
	return out


## WHERE A JUMP IN PUTS THE SHIP, as `SystemMapScreen.show_system` works it out
## in the game: by then the frame is laid out (the sky's bake awaits frames,
## and `_frame.resized` has run `_place_map`), so `view.window` is the frame's
## and `zoom_min` is `_fit_zoom` on it (`zoom_for`). Headless, `SystemView.
## show_system` returns before any await, the frame has no size yet, the window
## ends at CX and the point comes out at x = -26 / zoom_min.
func _game_edge(m: SystemMapScreen) -> Vector2:
	var view = m.view
	var L: SystemLayout = view.layout
	var zm: float = SystemMapScreen.zoom_for(L, view.node, m._frame.size)
	var ex := minf(L.edge, (view.window.end.x - view.CX - 26.0) / zm)
	return Vector2(ex, -210.0)


func _place_name(L: SystemLayout, n: MapGen.MapNode, p: int) -> String:
	if SystemLayout.is_star(p):
		return L.star_title(n, p)
	var b := L.bodies[p]
	return "%s (%s)" % [b.name, Worlds.display_name(b.world) if b.world != &"" else String(b.kind)]


func _spec(id: String, kind: String, L: SystemLayout, n: MapGen.MapNode, key: String, b: int, i: int, t: float, ang: float) -> Dictionary:
	var fr := ""
	if key == "orbit":
		fr = "in orbit of " + _place_name(L, n, b)
	elif key == "close":
		fr = "in the close orbit of " + _place_name(L, n, b)
	return {"id": id, "kind": kind, "key": key, "b": b, "i": i, "t_sel": t, "t_setup": t, "ang": ang,
		"from_name": fr, "to_name": _place_name(L, n, i), "p": Vector2.ZERO, "sense": 1.0}


## The ship as the overlay draws it: through the view's own projection, and
## out on its ring as the ring is drawn (`SystemOverlay._draw_ship`'s rule, the
## spring `_ok` stepped by the overlay's own `_process`).
func _ship_px(view, ov, fl) -> Array:
	var p3: Vector3 = fl.where3()
	var raw: Vector2 = view.screen(p3.x, p3.z)
	var x := raw
	# (and as `_draw_ship` draws it: rounded, then out on the ring and rounded again)
	var xd := raw.round()
	if float(ov._ok) > 1.001 and SystemLayout.is_place(int(ov._ok_body)):
		var bw: Vector2 = ov._body_scr(int(ov._ok_body))
		x = bw + (x - bw) * float(ov._ok)
		xd = (bw + (xd - bw) * float(ov._ok)).round()
	return [x, raw, xd]


func _phase(fl, t: float) -> String:
	if not (fl._pend as Dictionary).is_empty():
		return "wait"
	match fl.mode:
		&"rail":
			if fl.rail.has("phase"):
				return "ride"
			if fl.rail.has("arrive") or fl.inserting():
				return "capture"
			return "orbit"
		&"keep":
			if fl.keep.has("hold"):
				return "ride"
			if fl.keep.has("arrive") or fl.inserting():
				return "capture"
			return "orbit"
		&"fly":
			var u := clampf((t - float(fl.fly_t0)) / maxf(float(fl.plan.dur), 1e-6), 0.0, 1.0)
			if u < float(fl.plan.u_dep):
				return "ride"
			return "burn" if fl.burn else "coast"
		&"free":
			return "ride"
	return String(fl.mode)


## ONE FLIGHT FLOWN AND RECORDED at setting `sn`: the ship started, ridden on to
## the selection (the preview planned then, as the map's worker does), on to
## the click `_click_d` later, clicked through `fly_bg` with the drawn preview,
## and flown at 60 frames a second to settled, a sample every 1/30 s.
func _fly_rec(m: SystemMapScreen, L: SystemLayout, F: Dictionary, sn: String, setting: Dictionary, off := 0.0) -> Dictionary:
	var view = m.view
	var ov = m.overlay
	var today := sn == "TODAY"
	FlightSolve.tune(setting)
	var i: int = F.i
	if today and L.twin:
		return {"none": "today's planner is never flown in a twin (ShipFlight._fallback: 'Never in a twin'; main had no twins)"}
	var fl = ShipFlightS.new()
	var ts0: float = F.t_setup
	fl.setup(L, F.edge_pt, ts0)
	var warp0 := float(fl.warp_t)
	ov.flight = fl
	match String(F.key):
		"orbit", "close":
			fl.place_at(int(F.b), ts0)
			fl.rail.ang = float(F.ang)
		"star":
			fl.settle_at(F.p, float(F.sense))
	var t := ts0
	view.t = t
	view._step_bodies()
	fl.step(DT, t, NONE)
	# (THE RIDE BEFORE THE CLICK, every frame, read only: for `pre`)
	var ride: Array = [_ride_pt(fl, t, [])]
	var t_sel := float(F.t_sel) + off
	while t + DT <= t_sel + 1e-9:
		t += DT
		view.t = t
		fl.step(DT, t, NONE)
		ride.append(_ride_pt(fl, t, []))
	var n_sel := ride.size() - 1
	# the overlay's spring at rest for the ring it is on
	ov._ok = 1.0
	ov._ok_v = 0.0
	ov._ok_body = -9
	ov._pulse = {}
	ov._left = {}
	ov._was = fl.reached()
	ov._star_r = fl.f.orbit_r if fl.star_orbiting() else -1.0
	for _k in 400:
		ov._process(DT)
	var ok_rest := [float(ov._ok), int(ov._ok_body)]
	# THE PREVIEW at the selection, as `plan_bg` makes it for the overlay
	# (today's: main's overlay made its preview with `_old_plan`, again from its
	# own choice every 3 s on a ring and every 0.5 s otherwise)
	var pv = null
	if not today:
		pv = fl.make_plan(i, t, {}, ShipFlightS.PREVIEW_AHEAD)
	else:
		pv = fl._old_plan(i, t)
	var t_pv := t
	# riding on to the click
	var t_click := t + _click_d
	while t + DT <= t_click + 1e-9:
		t += DT
		view.t = t
		fl.step(DT, t, NONE)
		ov._process(DT)
		ride.append(_ride_pt(fl, t, [float(ov._ok), int(ov._ok_body)]))
		if today and pv != null and t - t_pv > (3.0 if fl.mode == &"rail" and not fl.inserting() else 0.5):
			t_pv = t
			var np = fl._old_plan(i, t, pv.choice)
			if np != null:
				pv = np
	var tc := t
	var po = null
	var ok := false
	if today:
		# (main's click: the preview's own choice, which keeps its arrival time)
		po = FlightTestS.today_click(fl, i, tc, pv)
		pv = null
		if po == null:
			return {"none": "today's planner found nothing"}
		po.to = i
		po.t_plan = tc
		ok = fl.fly_bg(i, tc, func() -> void: pass, {}, po)
	else:
		ok = fl.fly_bg(i, tc, func() -> void: pass, pv.choice if pv != null else {}, pv)
	if not ok:
		return {"none": "fly_bg refused the click"}
	var waited := false
	if not (fl._pend as Dictionary).is_empty() and fl._jobs.has(&"fly"):
		# (not the drawn flight: planned for the click on a worker; taken in on the next frame)
		ShipFlightS._wait(int(fl._jobs[&"fly"].task))
		waited = true
	var drawn_pl = po if today else pv
	var samples: Array = []
	var raws: Array = []
	var t0 := tc
	var sp: Array = _ship_px(view, ov, fl)
	var start_px: Vector2 = sp[2]
	var exacts: Array = []
	samples.append([0.0, int(sp[2].x - _fo.x), int(sp[2].y - _fo.y), _r1(rad_to_deg(float(fl.ang))), 1 if fl.burn else 0, _phase(fl, t)])
	exacts.append(_fp(sp[0]))
	raws.append(_fp(sp[1]))
	# (the flame's length and the ring's scale as the overlay draws them, each sample)
	var flames: Array = [_flame_px(bool(fl.burn), float(fl.burn_k), float(view.t))]
	var oks: Array = [[snappedf(float(ov._ok), 0.0001), int(ov._ok_body)]]
	var settled := false
	var k := 0
	var flown_pl = null
	var plane_off := 0.0
	var scr_off := 0.0
	var jl := 1
	var js := 1
	var lpts := PackedVector3Array()
	var ldrawn := PackedVector2Array()
	var line_out: Array = []
	var hidden: Array = []
	var ph_t := {}
	var ph_last := ""
	var tail_s: float = ShipFlightS.TAIL_S
	var flying := false
	while k < int(130.0 / DT):
		k += 1
		t += DT
		view.t = t
		fl.step(DT, t, NONE)
		ov._process(DT)
		if flown_pl == null and fl.plan != null:
			flown_pl = fl.plan
			if drawn_pl == null or not ((flown_pl.res != null and drawn_pl.res != null and flown_pl.res == drawn_pl.res) or flown_pl == drawn_pl):
				drawn_pl = flown_pl
			# THE LINE AS THE OVERLAY DRAWS THIS PLAN, at the click
			var ln: Array = ov._plan_line(drawn_pl, false)
			lpts = ln[0]
			var lits: PackedByteArray = ln[1]
			var us: PackedFloat32Array = ln[2]
			var dr: PackedVector3Array = ov._drawn_ends(lpts, us, drawn_pl) if drawn_pl.res != null else lpts
			view.t = tc
			view._step_bodies()
			var occ: Array = ov._occluders()
			for j in dr.size():
				var q: Vector3 = dr[j]
				var s2: Vector2 = ov._scr(q.x, q.z)
				ldrawn.append(s2)
				line_out.append([_r1(s2.x - _fo.x), _r1(s2.y - _fo.y), int(lits[j])])
				if SystemOverlayS._hidden(s2, view.depth(Vector2(q.x, q.z)), occ):
					hidden.append(j)
			view.t = t
			view._step_bodies()
		var ph := _phase(fl, t)
		if ph != ph_last:
			ph_t[ph] = t - t0
			ph_last = ph
		# AGAINST THE DRAWN LINE, from the departure to a little round the ring
		# after (FlightTest's click measure: the plane, DRAWN_PX)
		if fl.mode == &"fly":
			flying = true
		if drawn_pl != null and not lpts.is_empty() and flying:
			var own: bool = drawn_pl.res != null or drawn_pl.ahead
			var t_from := float(drawn_pl.t0) if own else float(fl.fly_t0)
			var te := float(drawn_pl.end.get("t", t_from + float(drawn_pl.dur))) if own else t_from + float(drawn_pl.dur)
			if t >= t_from and t <= te + 0.9 * tail_s:
				var p3: Vector3 = fl.where3()
				var r2: Array = FlightTestS._near_line(Vector2(p3.x, p3.z), lpts, jl)
				jl = int(r2[1])
				plane_off = maxf(plane_off, float(r2[0]))
				var sx: Vector2 = _ship_px(view, ov, fl)[0]
				var r3 := _near_px(sx, ldrawn, js)
				js = int(r3[1])
				scr_off = maxf(scr_off, float(r3[0]))
		var done: bool = fl.reached() == i
		if k % 2 == 0 or done:
			var s3: Array = _ship_px(view, ov, fl)
			samples.append([_r2(t - t0), int(s3[2].x - _fo.x), int(s3[2].y - _fo.y), _r1(rad_to_deg(float(fl.ang))), 1 if fl.burn else 0, ph if not done else "orbit"])
			exacts.append(_fp(s3[0]))
			raws.append(_fp(s3[1]))
			flames.append(_flame_px(bool(fl.burn), float(fl.burn_k), float(view.t)))
			oks.append([snappedf(float(ov._ok), 0.0001), int(ov._ok_body)])
		if done:
			settled = true
			break
	var secs := t - t0
	# ON THE TARGET'S RING, settled
	var ring_off := INF
	var c3: Vector3 = fl.center(i, t)
	var pend: Vector3 = fl.where3()
	if fl.mode == &"rail":
		ring_off = absf(Vector2(pend.x - c3.x, pend.z - c3.z).length() - float(fl.rail.rt))
	elif fl.mode == &"keep":
		ring_off = (Vector2(pend.x - c3.x, pend.z - c3.z) - (fl.keep.off as Vector2)).length()
	var res = drawn_pl.res if drawn_pl != null else null
	var run := {"secs": _r2(secs), "settled": settled, "samples": samples, "exact": exacts, "raw": raws, "line": line_out, "hidden": hidden,
		"click_at": _r2(off), "sel_t": _r2(t_sel), "click_t": _r2(tc),
		"phase_at": ph_t, "start": [int(start_px.x - _fo.x), int(start_px.y - _fo.y)],
		"plan": {"solved": res != null, "legs": res.legs if res != null else 1, "T": _r2(res.T) if res != null else -1.0,
			"ride": _r2(res.lead) if res != null else _r2(float(drawn_pl.lead) if drawn_pl != null else 0.0),
			"work": _r1(res.work) if res != null else -1.0, "flew_drawn": not waited,
			"end_ring_r": _r2(fl.orbit_r(i)) if not fl.is_keep(i) else -1.0},
		"worst": {"plane_px": _r2(plane_off), "screen_px": _r2(scr_off), "ring_px": snappedf(ring_off, 0.001)}}
	run.check = "%.2f s click to settled (%s), %s, plan %s legs %d T %.2f ride %.2f work %.0f; off the drawn line %.3f plane px (FlightTest's DRAWN_PX %.1f), %.2f screen px; on the target's ring within %.4f px; starts at %s" % [
		secs, "settled" if settled else "NOT SETTLED", "the drawn flight" if not waited else "planned at the click", "solved" if res != null else "today's",
		int(run.plan.legs), float(run.plan.T), float(run.plan.ride), float(run.plan.work), plane_off, FlightTestS.DRAWN_PX, scr_off, ring_off, run.start]
	# ADDED (the edge fix): the flame and the ring's scale per sample, and the
	# ride before the click; worked out after all of the above, reading only
	run.fl = flames
	run.ok = oks
	var pr := _pre(view, ov, L, F, ride, n_sel, ok_rest, tc, ts0)
	run.pre = pr.pre
	run.pre_ok = pr.pre_ok
	run.pre_fl = pr.pre_fl
	run.pre_check = pr.check
	if String(F.key) == "edge":
		run.warp_at = _r2(warp0 - tc)
	view.t = t
	return run


## One frame of the ride before the click, as read off the ship: its clock, its
## point, nose, burn, flame level, phase, and the overlay's [ok, ok_body] where
## the overlay ran that frame ([] where it did not: at rest, as at the selection).
func _ride_pt(f, t: float, okp: Array) -> Array:
	return [t, f.where3(), float(f.ang), bool(f.burn), float(f.burn_k), _phase(f, t), okp]


## THE FLAME'S LENGTH as `SystemOverlay._draw_ship` works it out (px): the two
## outer flames run k = 1..ln behind the stern; 0 when not burning.
static func _flame_px(burn: bool, burn_k: float, tv: float) -> int:
	if not burn:
		return 0
	var bk := clampf(burn_k, 0.25, 1.6)
	var fl2 := int(tv * 30.0) % 3
	return int(4.0 + 8.0 * bk) + (fl2 - 1)


## A plane point as `_draw_ship` draws the ship there at clock tv with the
## overlay's ring scale okv round okb: rounded, then out on the ring and rounded
## again (`_ship_px`'s drawn point, for a point and a scale given).
func _px_at(view, ov, p3: Vector3, okv: float, okb: int, tv: float) -> Vector2:
	var keep_t := float(view.t)
	view.t = tv
	var xd: Vector2 = view.screen(p3.x, p3.z).round()
	if okv > 1.001 and SystemLayout.is_place(okb):
		var bw: Vector2 = ov._body_scr(okb)
		xd = (bw + (xd - bw) * okv).round()
	view.t = keep_t
	return xd


const PRE_FRAMES := 84
const PRE_N := 42
const PRE_LEAD := 60


## THE 1.4 s BEFORE THE CLICK, every other frame as the samples are: the flown
## ship's own frames where the harness had it there (`ride`, from its start),
## and before that a second ship put on the same ring or star orbit PRE_LEAD
## frames earlier than needed and stepped by the same code to the same angle.
## The overlay's spring is at rest (as at the selection) up to the selection,
## then as it ran. The second ship is stepped on to the click too, and where
## both ran the two are compared (`check`).
func _pre(view, ov, L: SystemLayout, F: Dictionary, ride: Array, n_sel: int, ok_rest: Array, tc: float, ts0: float) -> Dictionary:
	var N := ride.size() - 1
	var M := maxi(0, PRE_FRAMES - N)
	var shadow := {}
	var how := "the flown ship's own ride"
	var dmax := 0.0
	var ddrawn := 0
	var nboth := 0
	var key := String(F.key)
	if M > 0:
		var Ms := M + PRE_LEAD
		var tq := ts0 - float(Ms) * DT
		var fs = ShipFlightS.new()
		fs.setup(L, F.edge_pt, tq)
		var made := true
		if key == "orbit" or key == "close":
			fs.place_at(int(F.b), tq)
			# (a rail turns dir * speed / rt a second; the flown ship's first step,
			# at its start, took it to F.ang + w DT)
			var w := float(fs.rail.dir) * float(fs.rail.speed) / float(fs.rail.rt)
			fs.rail.ang = float(F.ang) - w * DT * float(Ms)
			how = "a second ship on the same ring"
		elif key == "star":
			var f0 = ShipFlightS.new()
			f0.setup(L, F.edge_pt, ts0)
			f0.settle_at(F.p, float(F.sense))
			var cen: Vector2 = f0.f.cen
			var q0: Vector2 = f0.f.p - cen
			var v0: Vector2 = f0.f.v
			var w2 := (q0.x * v0.y - q0.y * v0.x) / maxf(q0.length_squared(), 1e-9)
			fs.settle_at(cen + q0.rotated(-w2 * DT * float(Ms)), float(F.sense))
			how = "a second ship on the same star orbit"
		else:
			made = false
			how = "the flown ship's own ride only (no second ship for a %s start)" % key
		if made:
			var tt := tq
			fs.step(DT, tt, NONE)
			shadow[-Ms] = _ride_pt(fs, tt, [])
			for j in range(1, Ms + N + 1):
				tt += DT
				fs.step(DT, tt, NONE)
				shadow[j - Ms] = _ride_pt(fs, tt, [])
			for k in N + 1:
				var a: Array = ride[k]
				var b: Array = shadow[k]
				nboth += 1
				var d := ((a[1] as Vector3) - (b[1] as Vector3)).length()
				dmax = maxf(dmax, d)
				var okp: Array = ok_rest if k <= n_sel else a[6]
				if _px_at(view, ov, a[1], float(okp[0]), int(okp[1]), float(a[0])) != _px_at(view, ov, b[1], float(okp[0]), int(okp[1]), float(a[0])):
					ddrawn += 1
	var pre: Array = []
	var pre_ok: Array = []
	var pre_fl: Array = []
	var n_sh := 0
	for jj in range(PRE_N, 0, -1):
		var fi := N - 2 * jj
		var e: Array = []
		if fi >= 0:
			e = ride[fi]
		elif shadow.has(fi):
			e = shadow[fi]
			n_sh += 1
		else:
			continue
		var okp2: Array = ok_rest if fi <= n_sel else e[6]
		var tv: float = e[0]
		var xd := _px_at(view, ov, e[1], float(okp2[0]), int(okp2[1]), tv)
		pre.append([_r2(tv - tc), int(xd.x - _fo.x), int(xd.y - _fo.y), _r1(rad_to_deg(float(e[2]))), 1 if e[3] else 0, e[5]])
		pre_ok.append([snappedf(float(okp2[0]), 0.0001), int(okp2[1])])
		pre_fl.append(_flame_px(bool(e[3]), float(e[4]), tv))
	var ck := "%d points, %d from %s" % [pre.size(), pre.size() - n_sh, "the flown ship"]
	if n_sh > 0:
		ck += ", the first %d from %s put there %.2f s before the flown one; where both ran (%d frames, its start to the click) they differ by at most %.6f plane px and %d drawn points differ" % [n_sh, how, float(M + PRE_LEAD) * DT, nboth, dmax, ddrawn]
	elif M > 0:
		ck += "; %s" % how
	return {"pre": pre, "pre_ok": pre_ok, "pre_fl": pre_fl, "check": ck}


static func _near_px(p: Vector2, line: PackedVector2Array, j0: int) -> Array:
	var best := INF
	var bj := j0
	for j in range(maxi(1, j0 - 8), mini(line.size(), j0 + 64)):
		var a := line[j - 1]
		var b := line[j]
		var ab := b - a
		var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
		var d := (a + ab * u - p).length()
		if d < best:
			best = d
			bj = j
	return [best, bj]


## THE SCENE at the zoom the map opened at: the frame, each star, each world
## (its centre every half second from the click over the longest run), its
## drawn size and look, its rings, the orbit lines as the view draws them, and
## the rings the ship rides.
const PRE_T := [-1.5, -1.0, -0.5]


func _scene(m: SystemMapScreen, L: SystemLayout, F: Dictionary, secs_max: float) -> Dictionary:
	var view = m.view
	var ov = m.overlay
	var tc: float = float(F.t_sel) + _click_d
	var z: float = view.zoom
	var tilt: float = view.TILT
	var fl = ShipFlightS.new()
	fl.setup(L, F.edge_pt, float(F.t_setup))
	ov.flight = fl
	view.t = tc
	view._step_bodies()
	var stars: Array = []
	for s: int in L.stars():
		var sv = view.star if s == -1 else view.star2
		var pal := 0
		var glow := Vector3(1.0, 0.62, 0.22)
		var warm := 1.0
		if sv != null and (sv.P as Dictionary).has("pal"):
			pal = int(sv.P.pal)
			glow = sv.P.glow_c
			warm = float(sv.P.get("warm", 1.0))
		stars.append({"p": s, "name": L.star_title(view.node, s), "centre": _fp(ov.star_scr(s)), "r": _r1(ov.star_disc(s)),
			"rgb": _rgb(_sun_ramp(pal, 0.7) * warm), "rgb_hot": _rgb(_sun_ramp(pal, 0.97) * warm), "rgb_limb": _rgb(_sun_ramp(pal, 0.15) * warm),
			"glow_rgb": _rgb(glow * 255.0), "close_orbit_px": _r1(ov._orbit_px(s, fl.orbit_r(s))), "kind": L.star_kind_of(s) if L.has_method(&"star_kind_of") else 0})
	var worlds: Array = []
	var times: Array = []
	var tt := 0.0
	while tt <= secs_max + 0.51:
		times.append(_r2(tt))
		tt += 0.5
	for b in L.bodies:
		var track: Array = []
		for ts: float in times:
			var q: Vector2 = b.pos(tc + ts)
			track.append(_fp(view.block_round(view.screen(q.x, q.y))))
		# (and before the scene's clock zero, for `pre`)
		var track_pre: Array = []
		for ts2: float in PRE_T:
			var q2: Vector2 = b.pos(tc + ts2)
			track_pre.append(_fp(view.block_round(view.screen(q2.x, q2.y))))
		var ramp: StringName = WORLD_RAMP.get(b.world, b.world)
		var rgb: Array = _hex_rgb(Worlds.RAMP[ramp][3]) if Worlds.RAMP.has(ramp) else [140, 130, 117]
		var W: Dictionary = Worlds.WORLD.get(b.world, {})
		var hc: Vector2 = b.host
		worlds.append({"i": b.index, "name": b.name, "kind": String(b.kind), "world": String(b.world), "look": Worlds.display_name(b.world) if b.world != &"" else String(b.kind).to_upper(),
			"host_id": b.host_id, "r": _r1(view.draw_r(b)), "rgb": rgb, "atm_rgb": _hex_rgb(W.atm) if W.has("atm") else null,
			"centre_t": times, "centre": track, "centre_pre_t": PRE_T, "centre_pre": track_pre,
			"orbit": {"c": _fp(view.screen(hc.x, hc.y)), "rx": _r1(b.orbit * z), "ry": _r1(b.orbit * z * tilt)},
			"capture_ring": {"rx": _r1(b.soi * z), "ry": _r1(b.soi * z * tilt)} if b.world != &"" else null,
			"ride_ring": {"rx": _r1(ov._orbit_px(b.index, fl.orbit_r(b.index))), "ry": _r1(ov._orbit_px(b.index, fl.orbit_r(b.index)) * tilt),
				"life_rx": _r1(fl.orbit_r(b.index) * z)} if b.world != &"" else null})
	# THE ORBIT LINES as the view draws them now (`_Lines.orbit_runs`), every 2 px
	var lines: Array = []
	if view._lines != null:
		for run: Array in view._lines.orbit_runs():
			var pts: PackedVector2Array = run[0]
			var cols: PackedColorArray = run[1]
			var poly: Array = []
			var last := Vector2.INF
			for j in pts.size():
				if j == 0 or j == pts.size() - 1 or pts[j].distance_to(last) >= 2.0:
					poly.append(_fp(pts[j]))
					last = pts[j]
			var cm: Color = cols[cols.size() / 2] if cols.size() > 0 else Color.WHITE
			lines.append({"pts": poly, "rgba": [roundi(cm.r * 255.0), roundi(cm.g * 255.0), roundi(cm.b * 255.0), snappedf(cm.a, 0.01)]})
	# THE RINGS THE SHIP RIDES: the one it leaves (or the star orbit it is
	# settled on) and the one it arrives on, at their drawn size
	var rides: Array = []
	var key := String(F.key)
	if key == "orbit" or key == "close":
		var bb := int(F.b)
		var r0: float = fl.orbit_r(bb)
		rides.append({"what": "leaves", "place": bb, "centre": "star" if SystemLayout.is_star(bb) else "world", "rx": _r1(ov._orbit_px(bb, r0)), "ry": _r1(ov._orbit_px(bb, r0) * tilt), "life_rx": _r1(r0 * z)})
	elif key == "star" or key == "edge":
		var f2 = ShipFlightS.new()
		f2.setup(L, F.edge_pt, float(F.t_setup))
		if key == "star":
			f2.settle_at(F.p, float(F.sense))
		var cc: Vector2 = f2.f.cen
		rides.append({"what": "leaves (a settled star orbit)", "place": -9, "c": _fp(view.screen(cc.x, cc.y)), "rx": _r1(float(f2.f.orbit_r) * z), "ry": _r1(float(f2.f.orbit_r) * z * tilt)})
	var ti: int = F.i
	if not fl.is_keep(ti):
		rides.append({"what": "arrives", "place": ti, "centre": "star" if SystemLayout.is_star(ti) else "world", "rx": _r1(ov._orbit_px(ti, fl.orbit_r(ti))), "ry": _r1(ov._orbit_px(ti, fl.orbit_r(ti)) * tilt), "life_rx": _r1(fl.orbit_r(ti) * z)})
	return {"frame": {"w": _r1(view.window.size.x), "h": _r1(view.window.size.y)}, "zoom": z, "tilt": tilt, "click_t": tc,
		"stars": stars, "worlds": worlds, "orbit_lines": lines, "rides": rides, "from": F.from_name, "to": F.to_name}


# ============================================================== a probe
## SolveTest's own cases (its `_real_cases`), those whose label holds one of
## `labels=` (split on |), solved at each setting of the grid with the trace on.
func _probe() -> void:
	var want: Array = []
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("labels="):
			want = Array((a as String).substr(7).split("|"))
	var st = load("res://scripts/sim/SolveTest.gd").new()
	st._real_cases()
	print("flightlen probe: %d cases" % st._cases.size())
	for c: Dictionary in st._cases:
		var hit := false
		for w in want:
			if String(c.label).find(w) >= 0:
				hit = true
		if not hit:
			continue
		print("  CASE %s (%s)" % [c.label, c.sweep])
		for g: Dictionary in _grid:
			print("   setting %s: %s" % [g.name, FlightSolve.tune(g)])
			FlightSolve.dbg = true
			var r := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t))
			FlightSolve.dbg = false
			print("   -> found %s, T %.2f, cost %.1f, integrations %d, legs %d" % [r.found, r.T, r.cost, r.integrations, r.legs])
	FlightSolve.tune({})


## (probe 2) SolveTest's own order: its warm-up (`_bench`, `_prototype`), its
## cases, every one solved in turn as its main loop does; the labelled ones
## printed, then each solved again at once, alone.
func _probe2() -> void:
	var want: Array = []
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("labels="):
			want = Array((a as String).substr(7).split("|"))
	FlightSolve.tune(_grid[0] if not _grid.is_empty() else {})
	var st = load("res://scripts/sim/SolveTest.gd").new()
	st._bench()
	st._prototype()
	st._real_cases()
	print("flightlen probe2: %d cases, %s" % [st._cases.size(), FlightSolve.setting()])
	var again: Array = []
	for i in st._cases.size():
		var c: Dictionary = st._cases[i]
		var r := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t))
		for w in want:
			if String(c.label).find(w) >= 0:
				print("  IN ORDER #%d %s: found %s, integrations %d, T %.2f" % [i, c.label, r.found, r.integrations, r.T])
				again.append(i)
	for i2: int in again:
		var c2: Dictionary = st._cases[i2]
		var r2 := FlightSolve.solve(c2.G, c2.dep, c2.tgt, float(c2.t))
		print("  AGAIN #%d %s: found %s, integrations %d, T %.2f" % [i2, c2.label, r2.found, r2.integrations, r2.T])


## (probe 3) SolveTest's whole case set (its order, its warm-up) solved at each
## setting of the grid in one process: per sweep the found-and-clean count, and
## the cases the first setting finds that each other misses.
func _probe3() -> void:
	var st = load("res://scripts/sim/SolveTest.gd").new()
	st._bench()
	st._real_cases()
	st._twin_cases()
	print("flightlen probe3: %d cases" % st._cases.size())
	var ok_by: Array = []
	# (per case and setting: plan T, engine work, planning ms; -1 where not found)
	var rows_by: Array = []
	var tw_by: Array = []
	var cap_by: Array = []
	for g: Dictionary in _grid:
		var line := FlightSolve.tune(g)
		tw_by.append(FlightSolve.TIME_W)
		cap_by.append(FlightSolve.T_CAP)
		var t0 := Time.get_ticks_msec()
		var oks := PackedByteArray()
		var rows := PackedFloat64Array()
		var per := {}
		for c: Dictionary in st._cases:
			var r := FlightSolve.solve(c.G, c.dep, c.tgt, float(c.t))
			var ok := r.found and r.clean
			oks.append(1 if ok else 0)
			rows.append_array(PackedFloat64Array([r.T if r.found else -1.0, r.work if r.found else -1.0, float(r.usec) / 1000.0]))
			if not per.has(c.sweep):
				per[c.sweep] = [0, 0]
			per[c.sweep][0] += 1
			if ok:
				per[c.sweep][1] += 1
		ok_by.append(oks)
		rows_by.append(rows)
		print("  setting %s (%s): %s (%.0f s)" % [g.name, line, per, (Time.get_ticks_msec() - t0) / 1000.0])
	for k in range(1, ok_by.size()):
		var lost := 0
		var gained := 0
		for i in st._cases.size():
			if ok_by[0][i] == 1 and ok_by[k][i] == 0:
				lost += 1
				print("    %s MISSES what %s finds: %s (%s)" % [_grid[k].name, _grid[0].name, st._cases[i].label, st._cases[i].sweep])
			elif ok_by[0][i] == 0 and ok_by[k][i] == 1:
				gained += 1
		print("  %s against %s: misses %d it finds, finds %d it misses" % [_grid[k].name, _grid[0].name, lost, gained])
		# CASE BY CASE where both find a clean flight: how often this one is
		# longer (by over 0.3 s), its extra engine work, and how often a flight
		# the first finds inside this one's cap costs less at this one's own
		# TIME_W than what this one picked (a search that missed it)
		for sw: String in ["one", "giant", "rtwin", "twin"]:
			var both := 0
			var longer := 0
			var shorter := 0
			var worst := 0.0
			var dw: Array = []
			var missed := 0
			for i2 in st._cases.size():
				if st._cases[i2].sweep != sw or ok_by[0][i2] == 0 or ok_by[k][i2] == 0:
					continue
				both += 1
				var Ta: float = rows_by[0][i2 * 3]
				var Wa: float = rows_by[0][i2 * 3 + 1]
				var Tk: float = rows_by[k][i2 * 3]
				var Wk: float = rows_by[k][i2 * 3 + 1]
				if Tk > Ta + 0.3:
					longer += 1
					worst = maxf(worst, Tk - Ta)
				elif Tk < Ta - 0.3:
					shorter += 1
				dw.append(Wk - Wa)
				if Ta <= float(cap_by[k]) + 1e-6 and Wa + float(tw_by[k]) * Ta < Wk + float(tw_by[k]) * Tk - 0.5:
					missed += 1
			print("    %s %s: both clean %d; longer than %s (over 0.3 s) %d (%.1f%%, worst +%.1f s), shorter %d; extra engine work median %+.1f, mean %+.1f px/s; a cheaper flight at its own TIME_W that %s finds inside its cap, missed: %d" % [
				_grid[k].name, sw, both, _grid[0].name, longer, 100.0 * longer / maxf(both, 1), worst, shorter, _median(dw), (dw.reduce(func(a, b): return a + b, 0.0) / maxf(dw.size(), 1)), _grid[0].name, missed])
	if _out != "":
		var labels: Array = []
		for c2: Dictionary in st._cases:
			labels.append([c2.label, c2.sweep])
		var res := {}
		for k2 in _grid.size():
			res[_grid[k2].name] = {"setting": _grid[k2], "tw": tw_by[k2], "cap": cap_by[k2], "ok": Array(ok_by[k2]), "rows": Array(rows_by[k2])}
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"cases": labels, "settings": res}))
		f.close()
	FlightSolve.tune({})
