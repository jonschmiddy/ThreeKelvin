extends Node

## Runs the real outcomes through LOCAL's band in every look and layout.
## C's flights are checked animated: the HUD holds its old number until the flight lands.
## Why: docs/why/OutcomeTest.md#outcome-test

var _tree: SceneTree
var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


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
	for layout: StringName in [&"row", &"column", &"card"]:
		LocalEventDrawer.layout = layout
		for c in cases:
			await _looks(n, String(c), cases[c], layout)
	if cases.has("data"):
		for layout: StringName in [&"row", &"column", &"card"]:
			LocalEventDrawer.layout = layout
			await _sheet_row(n, cases["data"], layout)
			await _five_row(n, cases["data"], layout)
	LocalEventDrawer.layout = &"column"
	if cases.has("big"):
		await _flight(n, cases["big"], false)
		await _flight(n, cases["big"], true)
	if cases.has("data"):
		await _flight(n, cases["data"], false)
		await _flight(n, cases["data"], true)
	OutcomeRow.look = &"today"
	LocalEventDrawer.quiet = false
	print("")
	print("outcometest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(1 if _fails > 0 else 0)


## Case f on the real LOCAL, its band up and its choice taken; the drawer.
func _take(n: MapGen.MapNode, f: Dictionary) -> Array:
	OutcomeCheck.reset(n, StringName(f.id), int(f.seed))
	n.visited = true
	SectorScreen._approached_at = n.index
	SystemMapScreen._parked.erase(n.index)
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
	var cont_today := Rect2()
	var bad: Array = []
	for lk: StringName in OutcomeRow.LOOKS:
		OutcomeRow.look = lk
		d.out.erase("flown")
		d._result()
		for i in 4:
			await _tree.process_frame
		for line in OutcomeCheck.check(d, lk, want):
			bad.append(line)
		var cont := d.panel.find_child("Continue", true, false) as Control
		if cont != null and layout != &"card":
			var cr := cont.get_global_rect()
			if lk == &"today":
				cont_today = cr
			elif lk == &"D":
				# D's at the band's top right (Jon, Oct 19), same size and edge as today's.
				if not cr.size.is_equal_approx(cont_today.size) or absf(cr.end.x - cont_today.end.x) > 0.5:
					bad.append("D: CONTINUE %s, not today's %s moved up" % [cr, cont_today])
				if cr.position.y > d.panel.get_global_rect().position.y + 12.0:
					bad.append("D: CONTINUE at %s, not at the band's top %s" % [cr, d.panel.get_global_rect()])
			elif not cr.is_equal_approx(cont_today):
				bad.append("%s: CONTINUE at %s, today's at %s" % [lk, cr, cont_today])
		# the card is seated by its height (`_seat_card`), so it is its WIDTH
		# that has to hold: an outcome must not widen it
		if layout == &"card" and absf(d.panel.size.x - LocalEventDrawer.CARD_W) > 0.5:
			bad.append("%s: the card is %d wide, not %d" % [lk, int(d.panel.size.x), int(LocalEventDrawer.CARD_W)])
		if not OutcomeRow.held.is_empty():
			bad.append("%s: HUD numbers left held %s" % [lk, OutcomeRow.held])
	_ok("%s (%s): every look says what moved, fits, and keeps CONTINUE where it was (D's at the top right)%s" % [c, layout,
		"" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty())
	OutcomeRow.look = &"today"
	d._drop()
	await _tree.process_frame


## THE LAB SHEET'S ROW (Jon's 2A, Nov 4: DATA a fifth stat in the result):
## the reading's result on the real LOCAL, its bill made the sheet's own
## (fuel 40 to 38, DATA 16 to 21) and drawn in D. The table reads
## "FUEL -2 · DATA +5", the box test and D's placing pass, and the line the
## map's card keeps for it says the same. No reading pays exactly this (fuel
## 2 is tier 3, which pays 8), so the real case's own row is `_looks`'s.
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
	OutcomeRow.look = &"D"
	d.out.erase("flown")
	d._result()
	for i in 4:
		await _tree.process_frame
	var texts: Array = OutcomeCheck.entries(d).map(func(x: Dictionary) -> String: return String(x.text))
	var said := " · ".join(texts)
	_ok("the sheet's row (%s): D reads \"%s\"" % [layout, said], said == "FUEL -2 · DATA +5")
	var bad := OutcomeCheck.check(d, &"D", want)
	_ok("the sheet's row (%s): fits and sits where D's table goes%s" % [layout,
		"" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty())
	var line := EncounterDrawer.moved_line(d.out.bill)
	_ok("the sheet's row (%s): the map's card keeps \"%s\"" % [layout, line], line == "FUEL -2 · DATA +5")
	OutcomeRow.look = &"today"
	d._drop()
	await _tree.process_frame


## ALL FIVE AT THEIR WIDEST (DATA made five stats possible in one result): a
## bill moving hull, fuel, credits, DATA and heat at once, each at the width
## a real result reaches (HULL -28, FUEL -2, CREDITS +72, DATA +28, HEAT +3),
## drawn on a real result in every look. Every look says all five and passes
## the box test, and D's table reads them in ORDER.
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
	for lk: StringName in OutcomeRow.LOOKS:
		OutcomeRow.look = lk
		d.out.erase("flown")
		d._result()
		for i in 4:
			await _tree.process_frame
		for b in OutcomeCheck.check(d, lk, want):
			bad.append(b)
		if lk == &"D":
			var said := " · ".join(OutcomeCheck.entries(d).map(func(x: Dictionary) -> String: return String(x.text)))
			if said != "HULL -28 · FUEL -2 · CREDITS +72 · DATA +28 · HEAT +3":
				bad.append("D reads \"%s\"" % said)
		if not OutcomeRow.held.is_empty():
			bad.append("%s: HUD numbers left held %s" % [lk, OutcomeRow.held])
	_ok("all five (%s): every look says hull, fuel, credits, DATA and heat and fits%s" % [layout,
		"" if bad.is_empty() else ": " + "; ".join(bad.slice(0, 4))], bad.is_empty())
	OutcomeRow.look = &"today"
	d._drop()
	await _tree.process_frame


## C, animated, on the big case and on the reading: the hold, the flight, the
## landing, the flicker.
func _flight(n: MapGen.MapNode, f: Dictionary, reduced: bool) -> void:
	var tag := "reduced motion" if reduced else "animated"
	Router.animate_in_harness = true
	var was_rm := DisplaySettings.reduced_motion
	DisplaySettings.reduced_motion = reduced
	OutcomeRow.look = &"C"
	var got := await _take(n, f)
	var d: LocalEventDrawer = got[0]
	if not _ok("C %s: the result is up" % tag, d != null and d.page == &"result"):
		DisplaySettings.reduced_motion = was_rm
		Router.animate_in_harness = false
		return
	# the band settled at the result's height before anything is measured
	# (reduced motion lands and flickers at once: watch the colours from here)
	var hud: HudBar = Router.hud
	var flickered := false
	for i in 15:
		await _tree.process_frame
		for w in _watch(hud, d):
			if (w as Control).modulate != Color.WHITE:
				flickered = true
	var keys: Array = []
	for e: Dictionary in OutcomeRow.changes(d.out):
		if e.kind == &"stat":
			keys.append(String(e.key))
	# what the HUD showed before the text was in, and where everything stood
	var shown_before := _hud_numbers(hud)
	var watch := _watch(hud, d)
	var at0: Array = watch.map(func(w: Control) -> Rect2: return w.get_global_rect())
	var held_at_start := OutcomeRow.held.duplicate()
	var want: Dictionary = got[1]
	var held_right := true
	for k in keys:
		held_right = held_right and int(held_at_start.get(k, -999)) == int((want.stats[k] as Array)[1])
	if not reduced:
		_ok("C %s: the HUD holds the old numbers while the text comes in (%s)" % [tag, held_at_start], held_right and held_at_start.size() == keys.size())
	# the text in: the flights go
	if d.text != null:
		d.text.skip()
	var flew := 0
	var flew_keys := {}
	var moved := ""
	var last_at := {}
	var biggest := 0.0
	for i in 150:
		await _tree.process_frame
		for c in d.get_children():
			if c is OutcomeRow.Flight:
				for a: Dictionary in (c as OutcomeRow.Flight).in_air():
					flew += 1
					var k2 := String(a.e.key)
					flew_keys[k2] = true
					if last_at.has(k2):
						biggest = maxf(biggest, (a.at as Vector2).distance_to(last_at[k2]))
					last_at[k2] = a.at
		for wi in watch.size():
			var w: Control = watch[wi]
			if not is_instance_valid(w):
				continue
			# A shorter number is the HUD's own layout, so a readout keeps its right edge and row.
			var r0: Rect2 = at0[wi]
			var r1 := w.get_global_rect()
			var still := r1.is_equal_approx(r0) if w is BaseButton \
				else (is_equal_approx(r1.end.x, r0.end.x) and is_equal_approx(r1.position.y, r0.position.y))
			if not still:
				moved = "%s moved %s -> %s" % [w.name, r0, r1]
			if w.modulate != Color.WHITE:
				flickered = true
	if reduced:
		_ok("C %s: nothing flies" % tag, flew == 0)
	else:
		_ok("C %s: the changes fly to the HUD (%d frames in the air, at most %.1f px a frame)" % [tag, flew, biggest], flew > 0)
		for k in keys:
			# in the air, and its last place in the air on its OWN readout
			# (a chip sent to another readout would still have flown)
			var home := Rect2()
			for nd in hud.stat_nodes(k):
				var g := (nd as Control).get_global_rect()
				home = g if home.size == Vector2.ZERO else home.merge(g)
			var end_at: Vector2 = last_at.get(k, Vector2(-999, -999))
			_ok("C %s: %s flies to its HUD readout (last seen at %s, the readout %s)" % [tag, OutcomeRow.WORDS[k], end_at, home],
				flew_keys.has(k) and home.grow(8).has_point(end_at))
	_ok("C %s: a readout flickers as its change lands" % tag, flickered)
	_ok("C %s: nothing on the HUD and no button moved%s" % [tag, "" if moved == "" else " (" + moved + ")"], moved == "")
	var back := true
	for w in watch:
		if is_instance_valid(w) and (w as Control).modulate != Color.WHITE:
			back = false
	_ok("C %s: every readout is back to its own colour" % tag, back)
	_ok("C %s: nothing left held (%s)" % [tag, OutcomeRow.held], OutcomeRow.held.is_empty())
	var shown_after := _hud_numbers(hud)
	var right := true
	for k in keys:
		right = right and int(shown_after[k]) == int((want.stats[k] as Array)[2])
	_ok("C %s: the HUD shows the new numbers (%s, was %s)" % [tag, shown_after, shown_before], right)
	if not reduced:
		# CONTINUE mid-flight lands everything at once
		OutcomeRow.look = &"C"
		d.out.erase("flown")
		d._result()
		await _wait(0.1)
		if d.text != null:
			d.text.skip()
		await _wait(0.15)
		d.continue_on()
		await _tree.process_frame
		_ok("C: CONTINUE mid-flight lets every number go", OutcomeRow.held.is_empty())
	OutcomeRow.look = &"today"
	DisplaySettings.reduced_motion = was_rm
	await _wait(0.6)
	Router.animate_in_harness = false


## Every HUD readout and tab a change can fly to, and the band's buttons.
func _watch(hud: HudBar, d: LocalEventDrawer) -> Array:
	var watch: Array = []
	for k in ["hp", "heat", "credits", "fuel", "data"]:
		watch.append_array(hud.stat_nodes(k))
	watch.append_array(hud.tab_nodes(&"chart"))
	for nm in ["Continue", "Reward"]:
		var b := d.panel.find_child(nm, true, false)
		if b != null:
			watch.append(b)
	return watch


## What the HUD prints for each stat now: {hp, heat, credits, fuel, data}.
func _hud_numbers(hud: HudBar) -> Dictionary:
	var outd := {}
	var hp_t := (hud.stat_nodes("hp")[2] as Label).text
	var heat_t := (hud.stat_nodes("heat")[2] as Label).text
	outd["hp"] = int(hp_t.get_slice("/", 0))
	outd["heat"] = int(heat_t.get_slice("/", 0).get_slice(" ", 0))
	outd["credits"] = int(((hud.stat_nodes("credits")[0] as Node).get_node("Value") as Label).text)
	# (fuel prints "44/45": the tank's size after the slash, not a digit of it)
	outd["fuel"] = int(((hud.stat_nodes("fuel")[0] as Node).get_node("Value") as Label).text.get_slice("/", 0))
	outd["data"] = int(((hud.stat_nodes("data")[0] as Node).get_node("Value") as Label).text)
	return outd


func _system() -> MapGen.MapNode:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.type == MapGen.NodeType.SYSTEM:
			OptionTable.ensure(m)
			Run.at = m.index
			return m
	return null
