extends Node

## THE STATION DECKS' SOUND (Jon's Nov 26 picks, `StationSound`): the plan read at docking; every deck and tier
## resolving to files on disk; each deck's bed and events on the real screen, none started in a ride; the PA through
## the deck's speaker, the tape cut where its line stops; the PA's table and its dealing; the yard's jokes silent;
## silence after undocking. Row in docs/tests.md.
## Why: docs/why/StationSound.md#the-test

## A start lands within one frame (the test runs at --fixed-fps 60).
const FRAME := 1.0 / 60.0 + 0.002
## What may start while the car rides: the rooms' steady loops (a deck's bed comes in at the hand-over).
const STEADY := [&"bed", &"layer:station", &"curve:tube", &"curve:fork"]
const DECKS := [&"stock", &"services", &"hold", &"work", &"bench"]

var _tree: SceneTree
var h := Harness.new()


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	StationSound.record = true
	# (the car rides, headless: the ride is half of what is checked)
	Router.animate_in_harness = true
	# (the PA's dealing seeded, so a run of the test deals the same lines)
	StationSound.pa_rng.seed = 4242
	_plans()
	_table()
	_dealing()
	for dev: int in [MapGen.Development.SETTLEMENT, MapGen.Development.UNCLAIMED]:
		await _station(dev)
	_finish()


# ------------------------------------------------------------------ the plan on disk
func _plans() -> void:
	var d := StationSound.data()
	if not _ok("station.json loads (%d rooms, %d files)" % [(d.get("rooms", {}) as Dictionary).size(),
			(d.get("files", {}) as Dictionary).size()], not d.is_empty()):
		return
	var missing: Array[String] = []
	var speakers: Dictionary = d.get("speakers", {})
	for dk: StringName in [&"prom", &"yard", &"exch", &"board", &"lab"]:
		for tr in StationSound.TIERS:
			var p := StationSound.plan_of(dk, tr)
			if p.is_empty():
				missing.append("%s:%s has no plan" % [dk, tr])
				continue
			if not dk in [&"board", &"lab"] and (p.get("beds", []) as Array).size() != 2:
				missing.append("%s:%s has %d bed takes" % [dk, tr, (p.get("beds", []) as Array).size()])
			for f in StationSound.files_of(p):
				if not ResourceLoader.exists(StationSound.DIR % f) or StationSound.file_info(f).is_empty():
					missing.append("%s:%s %s" % [dk, tr, f])
			var sp := String((p.get("pa", {}) as Dictionary).get("speaker", ""))
			if not speakers.has(sp):
				missing.append("%s:%s speaker %s" % [dk, tr, sp])
			if (sp.begins_with("tape")) != (tr == "unclaimed"):
				missing.append("%s:%s reads %s" % [dk, tr, sp])
			var ideas: Dictionary = (d.get("rooms", {}) as Dictionary).get("%s:%s" % [dk, tr], {}).get("pa_ideas", {})
			for k: String in ["A", "B", "C"]:
				var isp := String((ideas.get(k, {}) as Dictionary).get("speaker", ""))
				var hall := String((speakers.get(isp, {}) as Dictionary).get("hall", ""))
				if not speakers.has(isp) or isp.begins_with("tape") != (tr == "unclaimed") 						or (hall != "" and not (d.get("pa_halls", {}) as Dictionary).has(hall)):
					missing.append("%s:%s idea %s reads %s" % [dk, tr, k, isp])
			for cls: Variant in (p.get("map", {}) as Dictionary):
				if String(cls) in ["sneeze", "cat", "plane", "joke"]:
					missing.append("%s:%s plays a joke (%s)" % [dk, tr, cls])
	_ok("every deck at every tier resolves to its files on disk, its speaker and no joke %s" % [missing], missing.is_empty())
	var absent: Array[String] = []
	for tr in StationSound.TIERS:
		var n := 0
		for r in StationSound.pa_rows():
			if (r.get("tiers", []) as Array).has(tr):
				n += 1
				if not ResourceLoader.exists(String(r.get("file", ""))):
					absent.append(String(r.get("id", "")))
		if n == 0:
			absent.append("no line at " + tr)
	_ok("the PA table has lines at every tier, each on disk %s" % [absent], absent.is_empty())


# ------------------------------------------------------------------ the PA's table and its dealing
## Jon's Nov 26 script as the game holds it: his picks only, each with its role, the follow-ups' leads, the tape's cuts.
func _table() -> void:
	var bad: Array[String] = []
	var ids: Dictionary[String, Dictionary] = {}
	for r in StationSound.pa_rows():
		ids[String(r["id"])] = r
	for id: String in ids:
		var r := ids[id]
		var play := String(r.get("play", ""))
		if not play in ["dock", "bag", "after", "leave"]:
			bad.append("%s plays %s" % [id, play])
		if String(r.get("line", "")) == "" or String(r.get("when", "")) == "" or float(r.get("secs", 0.0)) <= 0.0:
			bad.append("%s has no line, when or length" % id)
		if "berth" in String(r.get("line", "")).to_lower():
			bad.append("%s says berth" % id)
		if (play == "dock") != id.begins_with("dock_") or (play == "leave") != id.begins_with("leave_"):
			bad.append("%s is %s" % [id, play])
		var tape := String(r.get("speaker", "")) == "Old tape"
		if tape != (r.get("tiers", []) == ["unclaimed"]) or tape != r.has("cut") or tape == bool(r.get("chime", false)):
			bad.append("%s: the tape is unclaimed's alone, cut, no chime" % id)
		if tape and not (float(r["cut"]) > 0.5 * float(r["secs"]) and float(r["cut"]) < float(r["secs"])):
			bad.append("%s cuts at %s of %s s" % [id, r["cut"], r["secs"]])
		if (String(r.get("speaker", "")) == "Recording") != (r.get("tiers", []) == ["capital"]):
			bad.append("%s: the Recording is the capital's alone" % id)
		for lead: Variant in r.get("after", []):
			if not ids.keys().any(func(k: String) -> bool: return k.begins_with(String(lead)) and k != id):
				bad.append("%s follows %s, which is not in the table" % [id, lead])
	for id in ["ship_4", "welder_1"]:
		if ids.has(id):
			bad.append("%s is in (Jon cut it)" % id)
	for id in ["forklift_1", "welder_2", "shift_1", "scrubber_1", "free_5"]:
		if ids.get(id, {}).get("decks", []) != ["yard"]:
			bad.append("%s is not the yard's alone" % id)
	if ids.get("lift_2", {}).get("needs", "") != "lift_1" or not bool(ids.get("reactor_1", {}).get("bang", false)):
		bad.append("lift_2 needs lift_1, reactor_1 its bang")
	for k in ["chime", "bang"]:
		if not ResourceLoader.exists(String(StationSound.pa_extra(k).get("file", ""))):
			bad.append("no %s on disk" % k)
	_ok("the PA table is Jon's 69 picked lines, each with its role, the follow-ups' leads, the tape's cuts; the chime and the bang %s"
		% [bad], ids.size() == 69 and bad.is_empty())


## The dealing, on the table alone: a whole pass of the bag before any line twice, no `when` twice running, kept
## across a docking; the dock lines' own bag; lift_2 after lift_1 only; the yard's lines on the yard; tiers; follow-ups.
func _dealing() -> void:
	var ss := StationSound.shared()
	StationSound._pa_bag.clear()
	StationSound._pa_dock_bag.clear()
	var all_heard: Dictionary = {}
	for r in StationSound.pa_rows():
		all_heard[String(r["id"])] = true
	var fit := func(tr: String, dk: StringName, heard: Dictionary) -> Array[String]:
		var o: Array[String] = []
		for r in StationSound.pa_rows():
			if StationSound.pa_fits(r, "bag", tr, dk, heard):
				o.append(String(r["id"]))
		return o
	# (a whole pass at a settlement's yard with a docking half way, then the next pass)
	var pool: Array[String] = fit.call("settlement", &"yard", all_heard)
	var got: Array[String] = []
	var bad: Array[String] = []
	var prev := ""
	for i in pool.size() * 2:
		if i == pool.size() / 2:
			ss.dock(null, true)
		var r := StationSound.pa_draw("bag", "settlement", &"yard", all_heard)
		var id := String(r.get("id", ""))
		if i < pool.size() and got.has(id):
			bad.append("%s twice" % id)
		got.append(id)
		if String(r.get("when", "")) == prev:
			bad.append("%s after the same when" % id)
		prev = String(r.get("when", ""))
	var first := got.slice(0, pool.size())
	first.sort()
	pool.sort()
	_ok("the bag deals all %d settlement yard lines before any twice, across a docking, no `when` twice running %s"
		% [pool.size(), bad], first == pool and bad.is_empty())
	var docks: Array[String] = []
	for i in 6:
		docks.append(String(StationSound.pa_draw("dock", "outpost", &"prom", {}).get("id", "")))
	var d3 := docks.slice(0, 3)
	d3.sort()
	_ok("the dock lines rotate in their own bag %s" % [docks], d3 == ["dock_1", "dock_4", "dock_5"]
		and docks.slice(3).all(func(id: String) -> bool: return id in d3) and docks[2] != docks[3])
	bad.clear()
	for heard: Dictionary in [{}, {"lift_1": true}]:
		var seen: Dictionary = {}
		for i in 3 * pool.size():
			seen[String(StationSound.pa_draw("bag", "settlement", &"prom", heard).get("id", ""))] = true
		if seen.has("lift_2") != heard.has("lift_1"):
			bad.append("lift_2 %s with %s" % [seen.has("lift_2"), heard])
		for id in ["forklift_1", "welder_2", "shift_1", "scrubber_1", "free_5"]:
			if seen.has(id):
				bad.append("%s on the promenade" % id)
		for id: String in seen:
			if StationSound.pa_row(id).get("play", "") != "bag":
				bad.append("%s dealt from the bag" % id)
	for tr in ["unclaimed", "capital"]:
		var here: Array[String] = fit.call(tr, &"prom", all_heard)
		if here.is_empty():
			bad.append("nothing at %s" % tr)
		for id: String in here:
			var who := String(StationSound.pa_row(id).get("speaker", ""))
			if (tr == "unclaimed") != (who == "Old tape") or (tr == "capital" and who in ["Daniel", "Bill"]):
				bad.append("%s at %s" % [id, tr])
	_ok("lift_2 only once lift_1 is heard; the yard's lines on the yard alone; unclaimed hears the tape alone, capital no Daniel or Bill %s"
		% [bad], bad.is_empty())
	ss.tier = "settlement"
	var n := 0
	var after_ok := true
	for i in 3000:
		ss._pa_after.clear()
		ss._pa_len = 4.0
		ss.pa_follow("ship_1")
		if not ss._pa_after.is_empty():
			n += 1
			var f: Dictionary = ss._pa_after[0]
			var dt := float(f["at"]) - ss.t - 4.0
			after_ok = after_ok and String((f["row"] as Dictionary)["id"]) == "free_2" and dt >= 5.0 and dt <= 10.0
	ss._pa_after.clear()
	_ok("a ship call gets free_2 about one time in three (%d of 3000), 5-10 s after it ends" % n,
		after_ok and n > 850 and n < 1150)
	StationSound._pa_bag.clear()
	StationSound._pa_dock_bag.clear()


# ------------------------------------------------------------------ one station, every deck
func _station(dev: int) -> void:
	var tr := StationSound.tier_of(dev)
	StationSound._data.clear()
	Rng.forced = 4242 + dev
	Run.start_new_run(&"korvan", 1)
	await Harness.frames(_tree, 2)
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = dev as MapGen.Development
	here.security = 4
	here.berths.clear()
	here.manufacturer = &""
	here.danger = 5
	Router.park_at_station(here)
	Router.show_station()
	await Harness.frames(_tree, 2)
	var scr := Router.current as StationScreen
	if not _ok("%s: the station is up" % tr, scr != null):
		return
	var ss := StationSound.shared()
	_ok("%s: the plan was read at docking, before any deck opened (%.2f ms)" % [tr, StationSound.open_ms.get(&"dock", -1.0)],
		not StationSound._data.is_empty() and ss.tier == tr)
	var n0 := ss.starts.size()
	var t0 := ss.t
	for id: StringName in DECKS:
		await _deck(scr, id, tr)
	_first_line(ss.starts.slice(n0), t0, tr)
	await _ride_pa(scr, tr)
	if tr == "settlement":
		await _reactor(scr)
		await _jokes(scr)
	await _leave(tr)


func _deck(scr: StationScreen, id: StringName, tr: String) -> void:
	var ss := StationSound.shared()
	var n0 := ss.starts.size()
	scr._show_tab(id)
	var rode := 0
	while scr.deck_changing():
		rode += 1
		await _tree.process_frame
	var t0 := ss.t
	var arc := 0
	var y := scr.deck_room(&"services") as YardScene
	while ss.t - t0 < 24.0:
		await _tree.process_frame
		if id == &"services" and y != null and y.life != null and bool(y.life.weld_now.get("on", false)):
			arc += 1
	var dk: StringName = StationSound.DECK_OF[id]
	var got := ss.starts.slice(n0)
	var counts: Dictionary[String, int] = {}
	var in_ride: Array[String] = []
	for s: Dictionary in got:
		counts[String(s["id"])] = counts.get(String(s["id"]), 0) + 1
		if bool(s["riding"]) and not StringName(s["id"]) in STEADY:
			in_ride.append(String(s["id"]))
	print("  %s %s: rode %d frames; %s; opened in %.2f ms" % [tr, dk, rode, counts, StationSound.open_ms.get(dk, -1.0)])
	_ok("%s %s: the deck on show is heard" % [tr, dk], ss.deck == dk and ss.plan.get("deck", "") == String(dk))
	if not dk in [&"board", &"lab"]:
		_ok("%s %s: its bed plays" % [tr, dk], counts.get("bed", 0) >= 1)
	_ok("%s %s: nothing but its steady loops starts in the ride %s" % [tr, dk, in_ride], in_ride.is_empty())
	match dk:
		&"prom":
			_ok("%s prom: the nearest walker's steps (%d in 24 s)" % [tr, counts.get("step", 0)], counts.get("step", 0) >= 6)
		&"yard":
			# (the welder's arc is worked out where the yard paints, which headless it may not: then nothing to hear)
			_ok("%s yard: the forklift, and the welder's arc each time it strikes (%d frames lit)" % [tr, arc],
				counts.get("curve:fork", 0) == 1 and (counts.get("weld", 0) >= 1) == (arc > 0))
		&"board":
			_ok("%s board: the tube and the station behind the wall" % tr,
				counts.get("curve:tube", 0) == 1 and counts.get("layer:station", 0) == 1)
			var own := counts.keys().filter(func(k: String) -> bool: return k.begins_with("lab_") or k.begins_with("board_"))
			_ok("%s board: its own sounds (the tubes' stutters) play through its room %s" % [tr, own], not own.is_empty())
		&"exch":
			_passes(got, tr)
		&"lab":
			var lab := scr.deck_room(&"bench") as LabScene
			_ok("%s lab: the station behind the shut door, and its own bed is Jon's far plant (%s)" % [tr,
				LabScene.bed_path(lab._level) if lab != null else "no lab"], counts.get("layer:station", 0) == 1
				and lab != null and LabScene.bed_path(lab._level).begins_with("res://assets/audio/station/lab_")
				and ResourceLoader.exists(LabScene.bed_path(lab._level)))


## Each ship pass starts its lead before the ship's middle crosses the screen's (within a frame).
func _passes(got: Array[Dictionary], tr: String) -> void:
	var ss := StationSound.shared()
	var bad: Array[String] = []
	var n := 0
	for s in got:
		if not String(s["id"]).begins_with("pass"):
			continue
		n += 1
		var want := ss.lead_of(StringName(s["id"]))
		if absf(float(s["late"]) - want) > FRAME:
			bad.append("%s %.3f s ahead, wanted %.3f" % [s["id"], s["late"], want])
	_ok("%s exch: %d ship passes, each its lead ahead of its crossing %s" % [tr, n, bad], bad.is_empty())


# ------------------------------------------------------------------ the PA and the ride
## The first line after a fresh docking: a dock line at a settlement, its chime first, a few seconds in; the tape at
## unclaimed, no chime.
func _first_line(got: Array[Dictionary], t0: float, tr: String) -> void:
	var lead := float(StationSound.pa_extra("chime").get("lead", 2.0))
	var line: Dictionary = {}
	var chime: Dictionary = {}
	for s in got:
		if s["id"] == &"pa_chime" and chime.is_empty():
			chime = s
		if s["id"] == &"pa":
			line = s
			break
	var at := float(line.get("t", INF)) - t0
	var id := String(line.get("file", ""))
	if tr == "unclaimed":
		_ok("unclaimed: the first line is the old tape, no chime (%s at %.1f s)" % [id, at],
			id.begins_with("tape_") and chime.is_empty())
		return
	_ok("%s: the first line after docking is a dock line, its chime %.1f s before, %.1f s in (%s)" % [tr, lead, at, id],
		id.begins_with("dock_") and not chime.is_empty() and absf(float(line["t"]) - float(chime["t"]) - lead) < FRAME
		and at >= StationSound.PA_DOCK.x + lead - FRAME and at <= StationSound.PA_DOCK.y + lead + 3.0)


## A line due while the car rides waits for the car to stop; it is read through the deck's speaker after its chime
## (the tape: none); the tape cuts where its line stops.
func _ride_pa(scr: StationScreen, tr: String) -> void:
	var ss := StationSound.shared()
	var n0 := ss.starts.size()
	# (nothing of the PA's left over from the decks: a follow-up, a line waiting on its chime, a line playing)
	ss.pa_quiet()
	ss._pa_next = ss.t + 0.1
	scr._show_tab(&"stock")
	await Harness.frames(_tree, 2)
	var rode := scr.deck_changing()
	while scr.deck_changing():
		await _tree.process_frame
	var t0 := ss.t
	while ss.t - t0 < 16.0:
		await _tree.process_frame
	var pa: Array[Dictionary] = []
	var clunk: Array[Dictionary] = []
	var chimes := 0
	for s in ss.starts.slice(n0):
		if s["id"] == &"pa" and s["play"] != "after":
			pa.append(s)
		elif s["id"] == &"pa_clunk":
			clunk.append(s)
		elif s["id"] == &"pa_chime":
			chimes += 1
	var want := String((ss.plan.get("pa", {}) as Dictionary).get("speaker", ""))
	_ok("%s: a line due mid-ride waits for the car (%s), then one is read through the %s speaker, %s" % [tr, rode, want,
		"no chime" if tr == "unclaimed" else "its chime first"], rode and pa.size() == 1 and not bool(pa[0]["riding"])
		and String(pa[0]["speaker"]) == want and (chimes == 0) == (tr == "unclaimed"))
	if tr == "unclaimed":
		var cut := float(pa[0].get("cut", -1.0)) if pa.size() == 1 else -1.0
		var at := float(clunk[0].get("at", -9.0)) if clunk.size() == 1 else -9.0
		_ok("unclaimed: the old tape (%s) cuts out where its line stops, %.2f s in, with its clunk (%.3f s)" % [
			pa[0].get("file", "") if pa.size() == 1 else "none", cut, at], clunk.size() == 1 and cut > 0.0
			and at >= cut and at < cut + FRAME)


## reactor_1 comes straight after its bang: the bang, its chime BANG_LEAD later, the line the chime's lead after that.
func _reactor(scr: StationScreen) -> void:
	scr._show_tab(&"stock")
	while scr.deck_changing():
		await _tree.process_frame
	var ss := StationSound.shared()
	ss.pa_quiet()
	ss._pa_next = INF
	var n0 := ss.starts.size()
	ss.announce(StationSound.pa_row("reactor_1"))
	var t0 := ss.t
	while ss.t - t0 < 6.0:
		await _tree.process_frame
	var at: Dictionary[String, float] = {}
	for s in ss.starts.slice(n0):
		if not at.has(String(s["id"])):
			at[String(s["id"])] = float(s["t"]) - t0
	var lead := float(StationSound.pa_extra("chime").get("lead", 2.0))
	_ok("reactor_1 comes straight after its bang (bang %.2f, chime %.2f, line %.2f s)" % [at.get("pa_bang", -1.0),
		at.get("pa_chime", -1.0), at.get("pa", -1.0)], at.has("pa_bang") and at.has("pa_chime") and at.has("pa")
		and absf(at["pa_chime"] - at["pa_bang"] - StationSound.BANG_LEAD) < FRAME
		and absf(at["pa"] - at["pa_chime"] - lead) < FRAME)
	ss._pa_next = ss.t + 60.0


# ------------------------------------------------------------------ the yard's jokes
func _jokes(scr: StationScreen) -> void:
	scr._show_tab(&"services")
	while scr.deck_changing():
		await _tree.process_frame
	await Harness.frames(_tree, 30)
	var y := scr.deck_room(&"services") as YardScene
	# (no other rare event while the jokes are heard: only the jokes fire)
	y._next_ev = 1e9
	var ss := StationSound.shared()
	var loud: Array[String] = []
	for k: String in StationSound.JOKES:
		var n0 := ss.starts.size()
		Audio.tape.clear()
		Audio.taping = true
		var fired := y.fire(k, y._t)
		var t0 := ss.t
		while ss.t - t0 < 5.0:
			await _tree.process_frame
		Audio.taping = false
		for s in ss.starts.slice(n0):
			if not StringName(s["id"]) in STEADY + [&"weld", &"flyer", &"pa", &"pa_chime", &"pa_bang"]:
				loud.append("%s: %s" % [k, s["id"]])
		for row: Variant in Audio.tape:
			var nm := String((row as Array)[0])
			for word in ["sneeze", "cat", "plane", "joke"]:
				if word in nm:
					loud.append("%s: %s" % [k, nm])
		print("  joke %s fired %s" % [k, fired])
	_ok("the yard's jokes (%s) make no sound %s" % [", ".join(StationSound.JOKES), loud], loud.is_empty())


func _leave(tr: String) -> void:
	Router.show_sector()
	await Harness.frames(_tree, 40)
	var ss := StationSound.shared()
	var busy := 0
	for v in ss._voices:
		if v.busy:
			busy += 1
	_ok("%s: undocked, the decks are silent (%d voices)" % [tr, busy], ss.deck == &"" and busy == 0)


func _finish() -> void:
	StationSound.record = false
	h.verdict("stationsoundtest")
	_tree.quit(h.code())
