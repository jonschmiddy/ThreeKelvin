extends Node

## The station's floor change, timed headless: every ordered pair of decks, the first visit of a
## docking against later ones, on the slide and the cross-fade. Not in the gate; run it with
## `--fixed-fps 60`. It prints a table and asserts only that each ride ends on the deck asked for.
## Options: runs=N mode=slide|fade every=1 dev=N seed=N only=a>b. Headless sees script time only.

const SETTLE_FRAMES := 12
const TAIL_FRAMES := 4

var h := Harness.new()
var _tree: SceneTree
var _rows: Dictionary = {}


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _ms(u0: int) -> float:
	return float(Time.get_ticks_usec() - u0) / 1000.0


func _station(dev: int, seed0: int) -> MapGen.MapNode:
	Rng.forced = seed0
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = dev
	here.security = 4
	here.danger = 5
	here.in_nebula = false
	here.berths.clear()
	here.manufacturer = &""
	return here


## A NEW DOCKING: every deck powers on afresh.
func _dock(here: MapGen.MapNode) -> StationScreen:
	Router.powered.clear()
	Router.park_at_station(here)
	Router.show_station()
	await Harness.frames(_tree, 30)
	return Router.current as StationScreen


## The decks' ids, high to low.
func _ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for row in StationScreen.DECKS:
		ids.append(row[0])
	return ids


## Stand on deck `a` with no ride and let it settle.
func _stand(st: StationScreen, a: StringName) -> void:
	Router.animate_in_harness = false
	st._show_tab(a)
	await Harness.frames(_tree, 2)
	Router.animate_in_harness = true
	await Harness.frames(_tree, SETTLE_FRAMES)


## One floor change from the click to the ride's end and a few frames after.
## Returns {frames: Array[float] (ms), click: ms, nodes, res, objs, peak_nodes, ended: bool}.
func _ride(st: StationScreen, b: StringName) -> Dictionary:
	var n0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var r0 := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var o0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var peak_n := 0.0
	var peak_r := 0.0
	var frames: Array[float] = []
	var u0 := Time.get_ticks_usec()
	(st._tabs[b] as Button).pressed.emit()
	var click := _ms(u0)
	var last := Time.get_ticks_usec()
	var tail := 0
	var guard := 0
	while guard < 600:
		guard += 1
		await _tree.process_frame
		frames.append(_ms(last))
		last = Time.get_ticks_usec()
		peak_n = maxf(peak_n, Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - n0)
		peak_r = maxf(peak_r, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) - r0)
		if not st.deck_changing():
			tail += 1
			if tail >= TAIL_FRAMES:
				break
	return {
		frames = frames, click = click, ended = st._tab == b and not st.deck_changing(),
		nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - n0,
		res = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) - r0,
		objs = Performance.get_monitor(Performance.OBJECT_COUNT) - o0,
		peak_nodes = peak_n, peak_res = peak_r,
	}


func _record(key: String, r: Dictionary) -> void:
	var fr: Array = r.frames
	var worst := r.click as float
	var worst_at := -1
	var total := r.click as float
	var o8 := 1 if (r.click as float) > 8.0 else 0
	var o16 := 1 if (r.click as float) > 16.0 else 0
	for i in fr.size():
		var f: float = fr[i]
		total += f
		if f > worst:
			worst = f
			worst_at = i
		if f > 8.0:
			o8 += 1
		if f > 16.0:
			o16 += 1
	var row: Dictionary = _rows.get(key, {})
	if not row.has(&"runs"):
		row[&"runs"] = []
	var one: Array = [r.click]
	one.append_array(fr)
	(row.runs as Array).append(one)
	for k in [&"worst", &"total", &"click", &"o8", &"o16", &"nodes", &"res", &"objs", &"peak_nodes", &"peak_res", &"at", &"n"]:
		if not row.has(k):
			row[k] = []
	(row.worst as Array).append(worst)
	(row.total as Array).append(total)
	(row.click as Array).append(r.click)
	(row.o8 as Array).append(float(o8))
	(row.o16 as Array).append(float(o16))
	(row.nodes as Array).append(r.nodes)
	(row.res as Array).append(r.res)
	(row.objs as Array).append(r.objs)
	(row.peak_nodes as Array).append(r.peak_nodes)
	(row.peak_res as Array).append(r.peak_res)
	(row.at as Array).append(float(worst_at))
	(row.n as Array).append(float(fr.size()))
	_rows[key] = row


## The ride's frames with each frame's time the MEDIAN across the runs: a spike that lands on a
## different frame every run (a busy machine) goes, one that lands on the same frame every run
## (the game's own) stays. Index 0 is the click's own call. Returns [worst median ms, its index].
static func _robust(runs: Array) -> Vector2:
	var n := 0
	for one: Array in runs:
		n = maxi(n, one.size())
	var best := 0.0
	var at := 0
	for i in n:
		var col: Array = []
		for one: Array in runs:
			if i < one.size():
				col.append(one[i])
		var m := _med(col)
		if m > best:
			best = m
			at = i
	return Vector2(best, at)


static func _med(a: Array) -> float:
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2]) if not s.is_empty() else 0.0


static func _lo(a: Array) -> float:
	return float(a.min()) if not a.is_empty() else 0.0


static func _hi(a: Array) -> float:
	return float(a.max()) if not a.is_empty() else 0.0


func _run() -> void:
	await _tree.process_frame
	Router.animate_in_harness = true
	var runs := int(Harness.arg("runs", "5"))
	var dev := int(Harness.arg("dev", "3"))
	var seed0 := h.seed_run(777)
	var only := Harness.arg("only", "")
	var ids := _ids()
	var was_move := StationScreen.deck_move
	var order: Array[String] = []
	var modes: Array[StringName] = [&"slide", &"fade"]
	if Harness.arg("mode") != "":
		modes = [StringName(Harness.arg("mode"))]
	for mode in modes:
		StationScreen.deck_move = mode
		for run in runs:
			var here := _station(dev, seed0)
			var st := await _dock(here)
			if not h._ok("%s run %d: the station is up" % [mode, run], st != null):
				return _finish(was_move)
			# THE COLD TOUR: the first visit to each deck in this docking, from the one before.
			var tour: Array[StringName] = [&"services", &"work", &"stock", &"hold", &"bench"]
			await _stand(st, &"services")
			Router.powered[&"services"] = true
			for i in range(1, tour.size()):
				var key := "%s|cold %s>%s" % [mode, tour[i - 1], tour[i]]
				if not order.has(key):
					order.append(key)
				var r := await _ride(st, tour[i])
				h._ok("%s ends on the deck asked for" % key, r.ended)
				_record(key, r)
				await Harness.frames(_tree, SETTLE_FRAMES)
			# EVERY ORDERED PAIR: the first visit (the deck's power-on owed again) and a later one.
			for a in ids:
				for b in ids:
					if a == b or (only != "" and only != "%s>%s" % [a, b]):
						continue
					for kind in [&"first", &"later"]:
						await _stand(st, a)
						if kind == &"first":
							Router.powered.erase(b)
						else:
							Router.powered[b] = true
						var key2 := "%s|%s %s>%s" % [mode, kind, a, b]
						if not order.has(key2):
							order.append(key2)
						var r2 := await _ride(st, b)
						h._ok("%s ends on the deck asked for" % key2, r2.ended)
						_record(key2, r2)
			if Harness.arg("every") != "":
				_table(order, dev)
	_table(order, dev)
	# EACH DECK ALONE, at rest: what a frame costs while it is the only one shown.
	var st2 := await _dock(_station(dev, seed0))
	print("a deck at rest, mean and worst ms of 60 frames:")
	for a in ids:
		var v := await _rest(st2, a, 60)
		print("  %-9s mean %5.2f  worst %5.1f" % [a, v.x, v.y])
	_finish(was_move)


## A deck standing alone, no ride: its mean and worst frame over `n` frames.
func _rest(st: StationScreen, a: StringName, n: int) -> Vector2:
	await _stand(st, a)
	var sum := 0.0
	var worst := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await _tree.process_frame
		var f := _ms(last)
		last = Time.get_ticks_usec()
		sum += f
		worst = maxf(worst, f)
	return Vector2(sum / float(n), worst)


func _table(order: Array[String], dev: int) -> void:
	print("")
	print("deckridebench: dev %d, medians (min-max); ms per frame at --fixed-fps 60" % dev)
	print("%-30s %5s %17s %17s %5s %5s %6s %6s %6s %12s" % ["mode|kind pair", "fr", "worst ms", "total ms", ">8", ">16", "dnode", "dres", "at", "steady@frame"])
	for key3 in order:
		var row: Dictionary = _rows[key3]
		print("%-30s %5.0f %5.1f (%4.1f-%5.1f) %6.1f (%5.1f-%6.1f) %5.1f %5.1f %6.0f %6.0f %6.0f %6.1f@%-3d" % [key3,
			_med(row.n), _med(row.worst), _lo(row.worst), _hi(row.worst),
			_med(row.total), _lo(row.total), _hi(row.total), _med(row.o8), _med(row.o16),
			_med(row.nodes), _med(row.res), _med(row.at), _robust(row.runs).x, int(_robust(row.runs).y)])


func _finish(was_move: StringName) -> void:
	StationScreen.deck_move = was_move
	h.verdict("deckridebench")
	_tree.quit(h.code())
