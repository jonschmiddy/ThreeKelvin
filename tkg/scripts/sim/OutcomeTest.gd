extends Node

## Runs the real outcomes through LOCAL's band in D, the one look, in the column, the one layout.
## Why: docs/why/OutcomeTest.md#outcome-test

var _tree: SceneTree
var h := Harness.new()


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _wait(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	LocalEventDrawer.quiet = true
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n := _system()
	var cases: Dictionary = await OutcomeCheck.find_cases(n)
	for c in ["jon", "gain", "mix", "card", "nothing", "credits", "big", "data", "data_toll"]:
		_ok("a real outcome for the case '%s' (%s)" % [c, cases.get(c, {}).get("sig", "none")], cases.has(c))
	if cases.has("data_toll"):
		_ok("the toll reading moves three stats or more (%s)" % cases["data_toll"].sig,
			String(cases["data_toll"].sig).split(", ").size() >= 3)
	Router.animate_in_harness = false
	for layout: StringName in [&"column"]:
		for c in cases:
			await _looks(n, String(c), cases[c], layout)
	if cases.has("data"):
		for layout: StringName in [&"column"]:
			await _sheet_row(n, cases["data"], layout)
			await _five_row(n, cases["data"], layout)
	LocalEventDrawer.quiet = false
	print("")
	h.verdict("outcometest")
	_tree.quit(h.code())


## Case f on the real LOCAL, its band up and its choice taken; the drawer.
func _take(n: MapGen.MapNode, f: Dictionary) -> Array:
	OutcomeCheck.reset(n, StringName(f.id), int(f.seed))
	n.visited = true
	SectorScreen._approached_at = n.index
	ParkedShips.spots.erase(n.index)
	LocalEventDrawer.request(n.index, 0)
	Router.show_local()
	var d: LocalEventDrawer = null
	for i in 240:
		await _tree.process_frame
		var lo := Router.current as SectorScreen
		d = lo.get("_events") if lo != null else null
		if d != null and d.page == &"event" and not ZoomLadder.busy():
			break
	if d == null or d.page != &"event":
		return [null, {}]
	for i in 10:
		if d.text != null and not d.text.done:
			d.text.skip()
		await _tree.process_frame
	Rng.event.seed = int(f.seed)
	Rng.loot.seed = int(f.seed) * 7 + 1
	Rng.world.seed = int(f.seed) * 13 + 5
	var before := OutcomeCheck.snapshot(n)
	var r: Dictionary = await d.choose(int(f.j))
	await _tree.process_frame
	return [d, OutcomeCheck.expect(n, before, r.get("res", {}))]


func _looks(n: MapGen.MapNode, c: String, f: Dictionary, layout: StringName) -> void:
	var got := await _take(n, f)
	var d: LocalEventDrawer = got[0]
	if not _ok("%s (%s): the result is up" % [c, layout], d != null and d.page == &"result"):
		return
	var want: Dictionary = got[1]
	var bad: Array = []
	for lk: StringName in [&"D"]:
		d._result()
		for i in 4:
			await _tree.process_frame
		for line in OutcomeCheck.check(d, lk, want):
			bad.append(line)
		var cont := d.panel.find_child("Continue", true, false) as Control
		# D's at the band's top right (Jon, Oct 19)
		if cont != null and cont.get_global_rect().position.y > d.panel.get_global_rect().position.y + 12.0:
			bad.append("D: CONTINUE at %s, not at the band's top %s" % [cont.get_global_rect(), d.panel.get_global_rect()])
	_ok("%s (%s): D says what moved, fits, and has CONTINUE at the top right%s" % [c, layout,
		"" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty())
	d._drop()
	await _tree.process_frame


## THE LAB SHEET'S ROW (Jon's 2A, Nov 4: DATA a fifth stat in the result): a reading's result
## on the real LOCAL reads "FUEL -2 · DATA +5" and passes the box test.
## Why: docs/why/OutcomeTest.md#the-lab-sheets-row
func _sheet_row(n: MapGen.MapNode, f: Dictionary, layout: StringName) -> void:
	var got := await _take(n, f)
	var d: LocalEventDrawer = got[0]
	if not _ok("the sheet's row (%s): the result is up" % layout, d != null and d.page == &"result"):
		return
	var was := {credits = 180, fuel = 40, heat = 2, hp = 30, data = 16}
	var now := was.duplicate()
	now.fuel = 38
	now.data = 21
	d.out["bill"] = EncounterDrawer.bill_rows(was, now)
	d.out["got"] = []
	var stats := {}
	for k in OutcomeCheck.WORDS:
		stats[k] = [int(now[k]) - int(was[k]), int(was[k]), int(now[k])]
	var want := {stats = stats, gained = {}, lost = {}, kind = {}, frame = false, place = false}
	d._result()
	for i in 4:
		await _tree.process_frame
	var texts: Array = OutcomeCheck.entries(d).map(func(x: Dictionary) -> String: return String(x.text))
	var said := " · ".join(texts)
	_ok("the sheet's row (%s): D reads \"%s\"" % [layout, said], said == "FUEL -2 · DATA +5")
	var bad := OutcomeCheck.check(d, &"D", want)
	_ok("the sheet's row (%s): fits and sits where D's table goes%s" % [layout,
		"" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty())
	var line := EncounterText.moved_line(d.out.bill)
	_ok("the sheet's row (%s): the map's card keeps \"%s\"" % [layout, line], line == "FUEL -2 · DATA +5")
	d._drop()
	await _tree.process_frame


## ALL FIVE AT THEIR WIDEST (DATA made five stats possible in one result): a
## bill moving hull, fuel, credits, DATA and heat at once, each at the width
## a real result reaches (HULL -28, FUEL -2, CREDITS +72, DATA +28, HEAT +3),
## drawn on a real result. D says all five, passes the box test and reads them in ORDER.
func _five_row(n: MapGen.MapNode, f: Dictionary, layout: StringName) -> void:
	var got := await _take(n, f)
	var d: LocalEventDrawer = got[0]
	if not _ok("all five (%s): the result is up" % layout, d != null and d.page == &"result"):
		return
	var was := {credits = 180, fuel = 40, heat = 2, hp = 40, data = 16}
	var now := {credits = 252, fuel = 38, heat = 5, hp = 12, data = 44}
	d.out["bill"] = EncounterDrawer.bill_rows(was, now)
	d.out["got"] = []
	var stats := {}
	for k in OutcomeCheck.WORDS:
		stats[k] = [int(now[k]) - int(was[k]), int(was[k]), int(now[k])]
	var want := {stats = stats, gained = {}, lost = {}, kind = {}, frame = false, place = false}
	var bad: Array = []
	for lk: StringName in [&"D"]:
		d._result()
		for i in 4:
			await _tree.process_frame
		for b in OutcomeCheck.check(d, lk, want):
			bad.append(b)
		var said := " · ".join(OutcomeCheck.entries(d).map(func(x: Dictionary) -> String: return String(x.text)))
		if said != "HULL -28 · FUEL -2 · CREDITS +72 · DATA +28 · HEAT +3":
			bad.append("D reads \"%s\"" % said)
	_ok("all five (%s): D says hull, fuel, credits, DATA and heat and fits%s" % [layout,
		"" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty())
	d._drop()
	await _tree.process_frame


func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM:
			OptionTable.ensure(m)
			Run.at = m.index
			return m
	return null
