extends Node

## THE STATION DECKS' SOUND (Jon's Nov 26 picks, `StationSound`): the plan read at docking; every deck and tier
## resolving to files on disk; each deck's bed and events on the real screen, none started in a ride; the PA through
## the deck's speaker, the unclaimed tape cut; the yard's jokes silent; silence after undocking. Row in docs/tests.md.
## Why: docs/why/StationSound.md#the-test

## A start lands within one frame (the test runs at --fixed-fps 60).
const FRAME := 1.0 / 60.0 + 0.002
## What may start while the car rides: the rooms' steady loops (a deck's bed comes in at the hand-over).
const STEADY := [&"bed", &"layer:station", &"curve:tube", &"curve:fork"]
const DECKS := [&"stock", &"services", &"hold", &"work"]

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
	_plans()
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
	for dk: StringName in [&"prom", &"yard", &"exch", &"board"]:
		for tr in StationSound.TIERS:
			var p := StationSound.plan_of(dk, tr)
			if p.is_empty():
				missing.append("%s:%s has no plan" % [dk, tr])
				continue
			if dk != &"board" and (p.get("beds", []) as Array).size() != 2:
				missing.append("%s:%s has %d bed takes" % [dk, tr, (p.get("beds", []) as Array).size()])
			for f in StationSound.files_of(p):
				if not ResourceLoader.exists(StationSound.DIR % f) or StationSound.file_info(f).is_empty():
					missing.append("%s:%s %s" % [dk, tr, f])
			var sp := String((p.get("pa", {}) as Dictionary).get("speaker", ""))
			if not speakers.has(sp):
				missing.append("%s:%s speaker %s" % [dk, tr, sp])
			if (sp.begins_with("tape")) != (tr == "unclaimed"):
				missing.append("%s:%s reads %s" % [dk, tr, sp])
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
	for id: StringName in DECKS:
		await _deck(scr, id, tr)
	await _ride_pa(scr, tr)
	if tr == "settlement":
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
	if dk != &"board":
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
## A line due while the car rides waits for the car to stop; it is read through the deck's speaker; the tape cuts.
func _ride_pa(scr: StationScreen, tr: String) -> void:
	var ss := StationSound.shared()
	var n0 := ss.starts.size()
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
	var clunk := 0
	for s in ss.starts.slice(n0):
		if s["id"] == &"pa":
			pa.append(s)
		elif s["id"] == &"pa_clunk":
			clunk += 1
	var want := String((ss.plan.get("pa", {}) as Dictionary).get("speaker", ""))
	_ok("%s: a line due mid-ride waits for the car (%s), then one is read through the %s speaker" % [tr, rode, want],
		rode and pa.size() == 1 and not bool(pa[0]["riding"]) and String(pa[0]["speaker"]) == want)
	if tr == "unclaimed":
		_ok("unclaimed: the old tape cuts out part way through the line, with its clunk", clunk == 1)


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
			if not StringName(s["id"]) in STEADY + [&"weld", &"flyer", &"pa"]:
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
