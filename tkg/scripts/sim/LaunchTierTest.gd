extends Node

## LAUNCH A RUN's tiers, as a player meets them (Jon's T1, Nov 10): the ladder,
## the unlock rule on a scratch record, the box from NEW RUN, a pick reaching the
## run and the galaxy's form, the record and the fresh-profile skip, box-tested.
## `docs/tests.md` has the list.
## Why: docs/why/Ladder.md#the-box

var _tree: SceneTree
var h := Harness.new()
var _history_was := ""
var _dev_was := false


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	_history_was = RunHistory.path
	RunHistory.path = TestRun.scratch("launchtier_history", "json")
	_write_history([])
	_dev_was = DevMode.enabled
	DevMode.enabled = false
	Run.picked_ascension = -1
	LaunchBox.last_tier = 0

	_ladder()
	_ok("with no win, tier 0 can be picked and 1 cannot",
		Ladder.best_won() == -1 and Ladder.can_pick(0) and not Ladder.can_pick(1))
	await _box_case()
	await _forms()
	await _record()
	await _fresh()
	_finish()


func _ladder() -> void:
	_ok("eleven rungs, 0 to 10", Ladder.count() == Run.ASCENSION_MAX + 1)
	var ok := true
	for t in Ladder.count():
		if Ladder.rung_name(t) == "" or Ladder.rule(t) == "" or Ladder.form_name(t) == "":
			ok = false
	_ok("every rung has a name, a form and a rule", ok)
	_ok("three spiral, three disc, three ball, one dwarf, the spiral first",
		Ladder.form(0) == Ladder.Form.SPIRAL and Ladder.form(3) == Ladder.Form.SPIRAL
		and Ladder.form(4) == Ladder.Form.DISC and Ladder.form(6) == Ladder.Form.DISC
		and Ladder.form(7) == Ladder.Form.BALL and Ladder.form(9) == Ladder.Form.BALL
		and Ladder.form(10) == Ladder.Form.DWARF)
	_ok("the Hellbender's rung is tier %d, THE HELLBENDER (Jon, Nov 11)" % Run.HELLBENDER_ASCENSION,
		Ladder.rung_name(Run.HELLBENDER_ASCENSION) == "THE HELLBENDER")
	# T-A's line under the rule, per tier
	var want := {0: "", 1: "", 2: "TIER 1 STILL APPLIES.", 3: "TIERS 1 AND 2 STILL APPLY.",
		4: "TIERS 1 TO 3 STILL APPLY.", 8: "TIERS 1 TO 7 STILL APPLY.", 10: "TIERS 1 TO 9 STILL APPLY."}
	var bad: Array[String] = []
	for t: int in want:
		if Ladder.still_line(t) != String(want[t]):
			bad.append("%d: '%s'" % [t, Ladder.still_line(t)])
	_ok("the still-applies line per tier%s" % ("" if bad.is_empty() else ": " + ", ".join(bad)), bad.is_empty())
	_ok("the rules in force at tier 3 are 3, 2, 1 and at tier 0 none",
		Ladder.in_force(3) == [3, 2, 1] and Ladder.in_force(0).is_empty())
	for f in 4:
		_ok("some galaxy kind takes form %s" % Ladder.FORM_NAME[f], not Ladder.kinds_of([0, 4, 7, 10][f]).is_empty())


## The box opened from NEW RUN, with a save so it is not skipped.
func _box_case() -> void:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Rng.forced = 0
	SaveGame.save()
	Router.show_launcher()
	await Harness.frames(_tree, 4)
	var nr := Harness.button_with_text(Router.current, "NEW RUN")
	if not _ok("the title has NEW RUN", nr != null):
		return
	nr.pressed.emit()
	await Harness.frames(_tree, 4)
	var box := Harness.first(Router.current, func(n: Node) -> bool: return n is LaunchBox) as LaunchBox
	if not _ok("NEW RUN with a save opens LAUNCH A RUN with the tier box", box != null):
		return
	_ok("eleven stops, a galaxy and the rule's words", box.stops.size() == 11 and box.galaxy != null
		and _says(box, Ladder.rung_name(0)) and _says(box, "TIER 0"))
	_fit(box, "tier 0, no win")
	box.stops[1].notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _click(box.stops[1])
	_ok("with no win, a click on stop 1 is refused: the pick stays at 0", box.tier == 0 and Run.picked_ascension == 0)
	# one win at tier 0 opens tier 1 and no more
	_write_history([{"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": "korvan", "ascension": 0}])
	await _click(box.stops[2])
	_ok("after a tier 0 win, a click on stop 2 (past best + 1) is refused", box.tier == 0 and Run.picked_ascension == 0)
	await _click(box.stops[1])
	_ok("a click on stop 1 moves the pick", box.tier == 1 and Run.picked_ascension == 1
		and _says(box, "TIER 1") and _says(box, Ladder.rung_name(1)))
	_ok("the galaxy is the tier's", box.galaxy.tier == 1 and box.galaxy.form == int(Ladder.Form.SPIRAL))
	_fit(box, "tier 1 picked")
	await _hover_case(box)
	var ny := Harness.button_with_text(Router.current, "NOT YET")
	var field := Harness.first(box, func(n: Node) -> bool: return n is LineEdit) as Control
	var go0 := Harness.button_with_text(Router.current, "LAUNCH")
	print("    rows: LAUNCH %s NOT YET %s field %s" % [go0.get_global_rect(), ny.get_global_rect(), field.get_global_rect() if field != null else "none"])
	_ok("LAUNCH, NOT YET and the seed field share one box height and one top row",
		field != null and ny != null and absf(go0.size.y - field.size.y) < 0.5 and absf(ny.size.y - field.size.y) < 0.5
		and absf(go0.global_position.y - field.global_position.y) < 0.5)
	var go := Harness.button_with_text(Router.current, "LAUNCH")
	if not _ok("the box has LAUNCH", go != null):
		return
	go.pressed.emit()
	await Harness.frames(_tree, 8)
	_ok("LAUNCH starts the run at tier 1", Router.current is ChassisSelect and Run.ascension == 1)
	_ok("in a spiral galaxy: %s" % GalaxyGen.type_name(Run.galaxy_kind), Ladder.form_of_kind(Run.galaxy_kind) == Ladder.Form.SPIRAL)
	# tier 0 is spirals only (Jon's G2, Nov 10), whatever the seed
	Run.forced_ascension = 0
	var spirals := true
	for sd: int in [4242, 7, 1999, 31337, 9300]:
		Rng.forced = sd
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		Rng.forced = 0
		if Run.ascension != 0 or Ladder.form_of_kind(Run.galaxy_kind) != Ladder.Form.SPIRAL:
			spirals = false
	Run.forced_ascension = -1
	_ok("a tier 0 run flies a spiral on every seed tried", spirals)
	_ok("the pick is remembered for the next box", LaunchBox.last_tier == 1)
	Run.hull = null


## A tier's galaxy takes the tier's form, by the test seam.
func _forms() -> void:
	for pair: Array in [[4, Ladder.Form.DISC], [8, Ladder.Form.BALL], [10, Ladder.Form.DWARF]]:
		Run.forced_ascension = int(pair[0])
		Rng.forced = 777
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		Rng.forced = 0
		_ok("a tier %d run flies a %s: %s" % [int(pair[0]), Ladder.FORM_NAME[int(pair[1])], GalaxyGen.type_name(Run.galaxy_kind)],
			Run.ascension == int(pair[0]) and Ladder.form_of_kind(Run.galaxy_kind) == pair[1])
	Run.forced_ascension = -1
	Run.hull = null


## The won run on the record, with its tier; it opens the next tier and no more.
func _record() -> void:
	Run.forced_ascension = 3
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Rng.forced = 0
	Run.forced_ascension = -1
	RunHistory.record(RunHistory.Outcome.WON, "Test win.")
	var runs := RunHistory.load_all()
	var last: Dictionary = runs[runs.size() - 1] if not runs.is_empty() else {}
	_ok("the won run is on the record with its tier (3)", int(last.get("ascension", -1)) == 3)
	_ok("the best tier won is 3, so 4 opens and 5 does not", Ladder.best_won() == 3 and Ladder.can_pick(4) and not Ladder.can_pick(5))
	_write_history([{"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": "korvan"}])
	_ok("a win from before tiers is a tier 0 win: tier 1 opens", Ladder.best_won() == 0 and Ladder.can_pick(1) and not Ladder.can_pick(2))
	Run.hull = null
	# the box at every tier, box-tested, with the wins that open them
	_write_history([{"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": "korvan", "ascension": 10}])
	var sizes: Array[Vector2] = []
	for t in Ladder.count():
		LaunchBox.last_tier = t
		var box := LaunchBox.new()
		add_child(box)
		box.setup(Widgets.button("LAUNCH", func() -> void: pass, false), Widgets.button("NOT YET", func() -> void: pass), HBoxContainer.new())
		await Harness.frames(_tree, 2)
		_ok("the box opens on the remembered tier %d" % t, box.tier == t and _says(box, "TIER %d" % t))
		_stack(box, t)
		_fit(box, "tier %d" % t)
		sizes.append(box.size)
		box.queue_free()
	_ok("the box is one size at every tier (%s)" % sizes[0], sizes.all(func(v: Vector2) -> bool: return v == sizes[0]))
	await Harness.frames(_tree, 1)
	_write_history([])
	LaunchBox.last_tier = 0


## A fresh profile skips the box and launches at tier 0.
func _fresh() -> void:
	SaveGame.clear()
	_write_history([])
	Run.picked_ascension = -1
	Router.show_launcher()
	await Harness.frames(_tree, 4)
	var nr := Harness.button_with_text(Router.current, "NEW RUN")
	if nr == null:
		_ok("the title has NEW RUN", false)
		return
	nr.pressed.emit()
	await Harness.frames(_tree, 6)
	_ok("a fresh profile's NEW RUN skips the box and launches at tier 0",
		Router.current is ChassisSelect and Run.ascension == 0)
	Run.hull = null


## T-A and T-C at tier t: the lit stops are 1 to t, the line under the rule says
## the lower tiers still apply, one lamp lit per rule in force, the lamps inside
## the galaxy and clear of each other.
func _stack(box: LaunchBox, t: int) -> void:
	var lit: Array[int] = []
	for s in box.stops:
		if s.lit():
			lit.append(s.tier)
	var want: Array[int] = []
	for k in range(1, t + 1):
		want.append(k)
	_ok("tier %d: stops %s lit" % [t, lit], lit == want)
	var line := box.still.text if box.still != null else ""
	_ok("tier %d: the line under the rule is '%s'" % [t, line], line == Ladder.still_line(t)
		and (box.still == null) == (t <= 1) and (t <= 1 or _says(box, line)))
	_ok("tier %d: %d lamps lit" % [t, box.galaxy.lamps_lit()], box.galaxy.lamps_lit() == t)
	var inside := true
	var apart := true
	for k in range(1, 11):
		var r := box.galaxy.lamp_rect(k).grow(1.0)
		inside = inside and Rect2(Vector2.ZERO, box.galaxy.size).encloses(r)
		for j in range(k + 1, 11):
			apart = apart and not r.intersects(box.galaxy.lamp_rect(j).grow(1.0))
	_ok("tier %d: the ten lamps inside the galaxy and clear of each other" % t, inside and apart)


## T-C's tag: pointing at the galaxy at tier 8 lists the eight rules in force by name, newest first.
func _hover_case(box: LaunchBox) -> void:
	_write_history([{"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": "korvan", "ascension": 9}])
	box.pick(8)
	await Harness.frames(_tree, 2)
	var gr := box.galaxy.get_global_rect()
	await _point(gr.get_center())
	await Harness.frames(_tree, int(TagLayer.DELAY * 60.0) + 12)
	var plate := TagLayer.instance.shown() if TagLayer.instance != null else null
	var body: TierGalaxy.RulesTag = plate.get_child(0) as TierGalaxy.RulesTag if plate != null and plate.get_child_count() > 0 else null
	if _ok("pointing at the galaxy brings up the tag of rules in force", body != null):
		_ok("it says %s and lists tiers %s" % [body.head, body.rows],
			body.head == "8 RULES IN FORCE" and body.rows == [8, 7, 6, 5, 4, 3, 2, 1])
		var tr := Rect2(plate.global_position, plate.size)
		_ok("the tag is on screen and off the galaxy (%s)" % tr,
			Rect2(0, 0, 960, 540).encloses(tr) and not tr.intersects(gr))
	_ok("its words name every rule: %s" % box.galaxy.tooltip_text.replace("
", " / "),
		Ladder.in_force(8).all(func(k: int) -> bool: return box.galaxy.tooltip_text.contains(Ladder.rung_name(k))))
	await _point(Vector2(4, 4))
	await Harness.frames(_tree, 3)
	box.pick(1)
	_write_history([{"outcome": int(RunHistory.Outcome.WON), "chassis_manufacturer": "korvan", "ascension": 0}])
	await Harness.frames(_tree, 2)


func _point(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	get_viewport().push_input(mm, true)
	await Harness.frames(_tree, 2)


# ------------------------------------------------------------------ helpers

func _write_history(runs: Array) -> void:
	var f := FileAccess.open(RunHistory.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": RunHistory.VERSION, "runs": runs}))
	f.close()


func _click(c: Control) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = c.size * 0.5
		ev.global_position = c.global_position + c.size * 0.5
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		c._gui_input(ev)
	await Harness.frames(_tree, 2)


func _labels(root: Node) -> Array[Label]:
	var out: Array[Label] = []
	if root is Label and (root as Label).is_visible_in_tree():
		out.append(root)
	for c in root.get_children():
		out.append_array(_labels(c))
	return out


func _says(root: Node, needle: String) -> bool:
	for l in _labels(root):
		if l.text.contains(needle):
			return true
	return false


## FIT: every word, stop and button of the box on screen and clear of each other.
func _fit(box: LaunchBox, when: String) -> void:
	var screen := Rect2(0, 0, 960, 540)
	var boxes: Array[Rect2] = []
	var names: Array[String] = []
	for l in _labels(box):
		boxes.append(l.get_global_rect())
		names.append(l.text)
	for s in box.stops:
		boxes.append(s.get_global_rect())
		names.append("stop %d" % s.tier)
	boxes.append(box.galaxy.get_global_rect())
	names.append("galaxy")
	for b in box.find_children("*", "Button", true, false):
		boxes.append((b as Control).get_global_rect())
		names.append((b as Button).text)
	var off: Array[String] = []
	var hits: Array[String] = []
	for i in boxes.size():
		if not screen.grow(0.5).encloses(boxes[i]):
			off.append("%s %s" % [names[i], boxes[i]])
		for j in range(i + 1, boxes.size()):
			var r := boxes[i].intersection(boxes[j])
			if r.size.x > 0.0 and r.size.y > 0.0:
				hits.append("%s x %s" % [names[i], names[j]])
	_ok("%s: everything on screen%s" % [when, "" if off.is_empty() else ": " + ", ".join(off)], off.is_empty())
	_ok("%s: nothing overlaps%s" % [when, "" if hits.is_empty() else ": " + ", ".join(hits)], hits.is_empty())


func _finish() -> void:
	DevMode.enabled = _dev_was
	Run.picked_ascension = -1
	Run.forced_ascension = -1
	SaveGame.clear()
	if _history_was != "":
		RunHistory.clear()
		RunHistory.path = _history_was
	h.verdict("launchtiertest")
	_tree.quit(h.code())
