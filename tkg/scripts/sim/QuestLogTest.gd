extends Node

## THE QUESTS TAB AND ITS TABLE, headless:
##   godot --headless --path . -- sheet=QuestLogTest
##
## Jon's design A (Oct 22): a QUESTS tab on the HUD after STARCHART opens a
## table of the quests you hold (`QuestPanel`, read off `QuestLog`); a row
## picked shows the note, SHOW ON STARCHART and PLOT ROUTE, which open the chart
## on the quest's place with its tag, and for PLOT ROUTE its route from YOU. On
## three galaxies, through the real screens:
##
## - the QUESTS tab is the same rect with none, one and five quests held (Jon:
##   "no number after quests", so it never changes size), and the HUD's row
##   fits with it;
## - with none, the table says so in a plain line;
## - a row for every quest, with its mark, state, task, where (the system and
##   its layer from 1, or any of the poster's yards and the nearest), jumps,
##   pay and the poster; READY and heat quests stand on the nearest paying yard;
## - a picked row shows the note and its two buttons; PLOT ROUTE opens the
##   chart, the quest's place the destination, its one tag and its route a
##   chain of legal jumps from YOU; SHOW ON STARCHART does the same without the
##   route; a star picked off the chart drops both;
## - FIT MEANS NOTHING OVERLAPS: the table clear of the HUD, the goal line and
##   A.S.H., on LOCAL, the sector map, the chart and a station; the chart's tag
##   clear of them, of the chart's words and of every star a click could pick;
## - the escape menu, and any change of screen, shut the table.
##
## And EVENT QUESTS and COMPLETED (Jon, Oct 22), on the first galaxy:
## - taking the runner's "Hide it aboard" adds a row beside a signed job:
##   MARKED, its task, where (system, layer, jumps), ON ARRIVAL, THE RUNNER,
##   its note the runner's own line; the head says 1 SIGNED · 1 MARKED;
## - its SHOW ON STARCHART and PLOT ROUTE open the chart on its system, its
##   route from YOU for PLOT ROUTE;
## - taking PAID IN FULL takes the row out of the open ones (and the chart's
##   mark off) and lists it under COMPLETED with what it paid; delivering the
##   job moves its row there too, newest first, with its credits and standing;
##   COMPLETED rows are greyed, open their note and have no PLOT ROUTE;
## - a save from before the records (VERSION 34, no `event_quests` and no
##   `quests_done`) loads with its open event quest still listed, who gave it
##   and where, and its delivered job under COMPLETED with its pay;
## - the QUESTS tab never changes size through any of it.

var _fails := 0
var _tree: SceneTree

const SEEDS := [4242, 11, 777]


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	await _tree.process_frame
	for sd in SEEDS:
		print("  [seed] %d" % sd)
		await _galaxy(sd)
	print("  [event quests] %d" % SEEDS[0])
	await _event_quests(SEEDS[0])
	print("questlogtest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


func _galaxy(sd: int) -> void:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.SYSTEM and n.layer == 3:
			Run.at = n.index
			n.visited = true
			break
	Run.chart_from(Run.node_at())
	QuestLog.forget()
	QuestPanel.picked = -1
	Router.show_local()
	await _frames(4)
	var hud := Router.hud
	var tab: Button = hud._tab_quests
	var tab0 := hud.quests_tab_rect()
	_ok("the HUD has a QUESTS tab after STARCHART", tab != null and tab.text == "QUESTS"
		and tab.get_index() == hud._tab_chart.get_index() + 1)
	_hud_fits("none held")

	# NONE
	tab.pressed.emit()
	await _frames(2)
	if _ok("the tab opens the table", QuestPanel.is_open()):
		var p := QuestPanel._open
		var empty := p.find_child("Empty", true, false) as Label
		_ok("with no quest it says so: \"%s\"" % (empty.text if empty != null else ""),
			empty != null and empty.text == QuestLog.EMPTY and _rows(p).is_empty())
		_fit("LOCAL, none held")
	tab.pressed.emit()
	await _frames(2)
	_ok("and the tab shuts it", not QuestPanel.is_open())

	# ONE, then FIVE
	var want := [ContractData.Kind.FETCH, ContractData.Kind.HUNT, ContractData.Kind.HEAT,
		ContractData.Kind.FETCH, ContractData.Kind.HUNT]
	var held: Array = []
	for kind in want:
		var job := _offer(kind)
		if job == null:
			_ok("a %s offer within reach" % ContractData.Kind.keys()[kind], false)
			continue
		held.append(Run.take_contract(job))
		if held.size() == 1:
			hud.refresh()
			await _frames(2)
			_ok("one quest: the QUESTS tab has not moved or changed size, and reads QUESTS",
				hud.quests_tab_rect() == tab0 and tab.text == "QUESTS")
	if held.size() < 2:
		return
	Run.reach_contract_target((held[0] as ContractData).at)
	Run.heat = 3
	hud.refresh()
	await _frames(2)
	_ok("five quests: the QUESTS tab has not moved or changed size (%s / %s)" % [hud.quests_tab_rect(), tab0],
		hud.quests_tab_rect() == tab0 and tab.text == "QUESTS")
	_hud_fits("five held")

	# THE TABLE
	tab.pressed.emit()
	await _frames(2)
	var p2 := QuestPanel._open
	if not _ok("the table is open again", p2 != null):
		return
	var rows := _rows(p2)
	var list := QuestLog.entries()
	_ok("a row for every quest held (%d of %d)" % [rows.size(), held.size()], rows.size() == held.size())
	var right := true
	for i in mini(rows.size(), list.size()):
		var e: Dictionary = list[i]
		var job: ContractData = e.job
		var words := _words(rows[i])
		var need: Array = [String(e.what).to_upper(), String(e.state), String(e.jumps), String(e.pay),
			String(e.who).to_upper()]
		if bool(e.yard):
			need.append("ANY %s YARD" % String(e.who).to_upper())
			need.append("NEAREST %s" % String(e.place_name))
		else:
			need.append(String(e.place_name))
			need.append("LAYER %d" % ((Run.map[job.at] as MapGen.MapNode).layer + 1))
		var place_ok := true
		if job.state == ContractData.State.READY or job.kind == ContractData.Kind.HEAT:
			var place := int(e.place)
			place_ok = place >= 0 and ContractData.berth_of(Run.map[place], job.manufacturer)
			for raw in Run.map:
				var n: MapGen.MapNode = raw
				if place_ok and ContractData.berth_of(n, job.manufacturer) and QuestLog.jumps(n.index) >= 0 \
						and QuestLog.jumps(n.index) < QuestLog.jumps(place):
					place_ok = false
		else:
			place_ok = int(e.place) == job.at
		var missing: Array = []
		for w in need:
			if not words.has(w):
				missing.append(w)
		if int(rows[i].get_meta(&"quest")) != job.id or not missing.is_empty() or not place_ok:
			right = false
			print("    row %d (%s): missing %s, place ok %s" % [i + 1, ContractData.Kind.keys()[job.kind], missing, place_ok])
	_ok("each row is its quest: mark, state, task, where, jumps, pay and poster; READY and heat on the nearest paying yard", right)
	_ok("the table's head counts them (%s)" % p2._sub.text, p2._sub.text == "%d SIGNED · 1 READY TO HAND IN" % held.size())

	# A ROW PICKED
	var hunt: ContractData = held[1]
	_row_of(p2, hunt.id).pressed.emit()
	await _frames(2)
	var hrow := _row_of(p2, hunt.id)
	var show: Button = null
	var plot: Button = null
	if hrow != null:
		show = hrow.find_child("ShowOnStarchart", true, false) as Button
		plot = hrow.find_child("PlotRoute", true, false) as Button
	_ok("a picked row shows the note and SHOW ON STARCHART and PLOT ROUTE",
		hrow != null and _words(hrow).has("\"%s\"" % hunt.text) and show != null and plot != null
		and not show.disabled and not plot.disabled)
	_fit("LOCAL, five held, a row open")
	if plot == null:
		return

	# PLOT ROUTE
	plot.pressed.emit()
	await _frames(4)
	var ch := Router.current as StarchartScreen
	if _ok("PLOT ROUTE opens the chart and shuts the table", ch != null and not QuestPanel.is_open()):
		_ok("with the quest's target the destination", ch._selected == hunt.at and ch._chart.selected == hunt.at
			and ch._dest_name.text == MapGen.star_name(Run.map[hunt.at]))
		var r: Array[int] = ch._chart.quest_route
		var legal := r.size() >= 2 and r[0] == Run.at and r[r.size() - 1] == hunt.at
		for k in range(1, r.size()):
			legal = legal and Run.reachable_from(Run.map[r[k - 1]], Run.map[r[k]])
		_ok("and its route from YOU, a legal jump a hop (%d hops)" % maxi(0, r.size() - 1), legal)
		_ok("and its one tag, on its target", ch._chart.quest_tags.size() == 1
			and int(ch._chart.quest_tags[0].index) == hunt.at and String(ch._chart.quest_tags[0].text) == "2 TARGET")
		await _tags(ch, "PLOT ROUTE")
		# the table from the chart
		Router.hud._tab_quests.pressed.emit()
		await _frames(2)
		_fit("the chart")
		QuestPanel.close()
		# another star drops the quest
		var other := -1
		for raw in Run.in_range():
			var n2: MapGen.MapNode = raw
			if n2.index != hunt.at and n2.index != Run.at:
				other = n2.index
				break
		if other >= 0:
			ch._on_node_picked(other)
			await _frames(1)
			_ok("picking another star drops the quest's tag and route",
				ch._chart.quest_route.is_empty() and ch._chart.quest_tags.is_empty())

	# SHOW ON STARCHART, for the READY one: its yard, no route
	Router.show_local()
	await _frames(3)
	QuestPanel.open()
	await _frames(1)
	var ready: ContractData = held[0]
	_row_of(QuestPanel._open, ready.id).pressed.emit()
	await _frames(2)
	var srow := _row_of(QuestPanel._open, ready.id)
	(srow.find_child("ShowOnStarchart", true, false) as Button).pressed.emit()
	await _frames(4)
	var ch2 := Router.current as StarchartScreen
	var yard := QuestLog.nearest_yard(ready.manufacturer)
	if _ok("SHOW ON STARCHART opens the chart", ch2 != null):
		_ok("on the READY quest's nearest paying yard, tagged HAND IN, no route",
			ch2._selected == yard and ch2._chart.quest_route.is_empty() and ch2._chart.quest_tags.size() == 1
			and String(ch2._chart.quest_tags[0].text) == "1 HAND IN" and int(ch2._chart.quest_tags[0].index) == yard)
		await _tags(ch2, "SHOW ON STARCHART")

	# THE SECTOR MAP, and the escape menu
	Router.show_system()
	await _frames(4)
	QuestPanel.open()
	await _frames(2)
	_fit("the sector map")
	get_parent().toggle_menu(false)
	await _frames(2)
	_ok("the escape menu shuts the table", not QuestPanel.is_open())
	get_parent().toggle_menu(false)
	await _frames(2)
	QuestPanel.open()
	await _frames(1)
	Router.show_local()
	await _frames(3)
	_ok("and so does another screen", not QuestPanel.is_open())

	# A STATION
	var here := Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.manufacturer = &"korvan"
	here.berths.clear()
	here.berths.append(&"korvan")
	Router.park_at_station(here)
	Router.show_station()
	await _frames(20)
	if _ok("a station is up", Router.current is StationScreen):
		Router.hud._tab_quests.pressed.emit()
		await _frames(2)
		_ok("the tab opens the table at a station", QuestPanel.is_open())
		_fit("a station")
		QuestPanel.close()


## The system the open PAID IN FULL stands on, and its slot there; [-1, -1].
func _paid_in_full() -> Array:
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		for i in n.options.size():
			if n.options[i] == &"paid_in_full" and not n.taken.has(MapGen.OPTION_SITE + i):
				return [n.index, i]
	return [-1, -1]


func _event_quests(sd: int) -> void:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.SYSTEM and n.layer == 3:
			Run.at = n.index
			n.visited = true
			break
	Run.chart_from(Run.node_at())
	QuestLog.forget()
	QuestPanel.picked = -1
	Router.show_local()
	await _frames(4)
	var hud := Router.hud
	var tab0 := hud.quests_tab_rect()
	var job := _offer(ContractData.Kind.HUNT)
	if not _ok("a hunt to sign beside the event quest", job != null):
		return
	job = Run.take_contract(job)

	# THE RUNNER, on this system, and her "Hide it aboard" taken cleanly
	var here := Run.node_at()
	OptionTable.ensure(here)
	here.options.append(&"the_runner")
	var runner_slot := here.options.size() - 1
	SkillCheck.forced = SkillCheck.Band.CLEAN
	var took: Dictionary = await OptionResolve.take(here, runner_slot, 0)
	SkillCheck.forced = -1
	var pf := _paid_in_full()
	var at: int = pf[0]
	_ok("the runner's Hide it aboard marks PAID IN FULL %d layers deeper (at %d)" % [OptionTable.PLACE_DEPTH, at],
		bool(took.get("ok", false)) and at >= 0
		and (Run.map[at] as MapGen.MapNode).layer >= here.layer + OptionTable.PLACE_DEPTH)
	if at < 0:
		return
	_ok("and the run records the runner as who gave it",
		StringName(Run.event_quest_at(at).get("from", &"")) == &"the_runner")
	QuestLog.forget()
	hud.refresh()
	await _frames(2)
	_ok("an event quest held: the QUESTS tab has not moved or changed size",
		hud.quests_tab_rect() == tab0 and hud._tab_quests.text == "QUESTS")
	var eid := QuestLog.EVENT_ID + at
	var words: Dictionary = OptionTable.by_id(&"paid_in_full").quest
	var target: MapGen.MapNode = Run.map[at]
	var j := QuestLog.jumps(at)
	var jw := "HERE" if j == 0 else ("1 JUMP" if j == 1 else ("%d JUMPS" % j if j > 0 else "NO ROUTE"))

	hud._tab_quests.pressed.emit()
	await _frames(2)
	var p := QuestPanel._open
	if not _ok("the table opens", p != null):
		return
	var row := _row_of(p, eid)
	var need := [String(words.task).to_upper(), "MARKED", MapGen.star_name(target),
		"LAYER %d" % (target.layer + 1), jw, QuestLog.ON_ARRIVAL, "THE RUNNER"]
	var missing: Array = []
	if row != null:
		for w in need:
			if not _words(row).has(w):
				missing.append(w)
	_ok("taking the runner's choice adds a row: %s%s" % [", ".join(need),
		"" if missing.is_empty() else " (missing %s)" % [missing]], row != null and missing.is_empty())
	var rows := _rows(p)
	_ok("after the signed job, both open", rows.size() == 2 and int(rows[0].get_meta(&"quest")) == job.id
		and int(rows[1].get_meta(&"quest")) == eid)
	_ok("the head counts it apart (%s)" % p._sub.text, p._sub.text == "1 SIGNED · 1 MARKED")
	_ok("no COMPLETED heading with nothing finished", p.find_child("Completed", true, false) == null)
	_fit("LOCAL, a job and an event quest")
	row.pressed.emit()
	await _frames(2)
	row = _row_of(p, eid)
	var plot: Button = row.find_child("PlotRoute", true, false) as Button if row != null else null
	var show: Button = row.find_child("ShowOnStarchart", true, false) as Button if row != null else null
	var runner_body := String(OptionTable.by_id(&"the_runner").body)
	_ok("its note is the runner's own line, word for word, and both buttons are there",
		row != null and _words(row).has("\"%s\"" % String(words.note)) and runner_body.contains(String(words.note))
		and plot != null and show != null and not plot.disabled and not show.disabled)
	_fit("LOCAL, the event quest's row open")
	if plot == null:
		return

	# PLOT ROUTE and SHOW ON STARCHART
	plot.pressed.emit()
	await _frames(4)
	var ch := Router.current as StarchartScreen
	if _ok("its PLOT ROUTE opens the chart", ch != null and not QuestPanel.is_open()):
		_ok("on its system", ch._selected == at and ch._chart.selected == at)
		var r: Array[int] = ch._chart.quest_route
		var legal := r.size() >= 2 and r[0] == Run.at and r[r.size() - 1] == at
		for k in range(1, r.size()):
			legal = legal and Run.reachable_from(Run.map[r[k - 1]], Run.map[r[k]])
		_ok("with its route from YOU, a legal jump a hop (%d hops)" % maxi(0, r.size() - 1), legal)
		_ok("and its one tag (%s)" % [ch._chart.quest_tags], ch._chart.quest_tags.size() == 1
			and int(ch._chart.quest_tags[0].index) == at and String(ch._chart.quest_tags[0].text) == "2 %s" % String(words.tag))
		await _tags(ch, "the event quest's PLOT ROUTE")
	Router.show_local()
	await _frames(3)
	QuestPanel.show_on_chart(eid, false)
	await _frames(4)
	ch = Router.current as StarchartScreen
	_ok("its SHOW ON STARCHART opens the chart on its system, no route",
		ch != null and ch._selected == at and ch._chart.quest_route.is_empty() and ch._chart.quest_tags.size() == 1)

	# PAID IN FULL TAKEN: out of the open rows, under COMPLETED with what it paid
	Router.show_local()
	await _frames(3)
	Run.at = at
	target.visited = true
	Run.chart_from(target)
	QuestLog.forget()
	var c0 := Run.credits
	var res: Dictionary = await OptionResolve.take(target, int(pf[1]), 1)
	var paid := Run.credits - c0
	QuestLog.forget()
	var gone := true
	for e in QuestLog.entries():
		if int((e as Dictionary).id) == eid:
			gone = false
	_ok("taking PAID IN FULL takes its row out of the open ones, and the chart's mark",
		bool(res.get("ok", false)) and gone and not OptionTable.holds_quest(target))
	var done := QuestLog.done_entries()
	var de: Dictionary = done[0] if not done.is_empty() else {}
	var names: Array = OptionResolve.gained_names(res.get("got", []))
	_ok("and lists it as finished, with what it paid (%s, %s: %s)" % [de.get("pay", ""), de.get("pay2", ""), de.get("paid", "")],
		int(de.get("id", -1)) == eid and String(de.pay) == "%d CR" % paid and paid > 0
		and not names.is_empty() and String(de.pay2) == "+1 THING"
		and String(de.paid).contains(String(names[0]).to_lower()))

	# THE JOB DELIVERED: under COMPLETED too, newest first
	job.state = ContractData.State.READY
	var s0 := Run.standing_with(job.manufacturer)
	Run.deliver_contract(job)
	done = QuestLog.done_entries()
	_ok("delivering the job moves it to COMPLETED, newest first, with its pay (%s %s)" % [
		(done[0] as Dictionary).pay, (done[0] as Dictionary).pay2],
		done.size() == 2 and int((done[0] as Dictionary).id) == job.id and int((done[1] as Dictionary).id) == eid
		and String((done[0] as Dictionary).pay) == "%d CR" % job.pay
		and String((done[0] as Dictionary).pay2) == "+%d STANDING" % (Run.standing_with(job.manufacturer) - s0)
		and QuestLog.entries().is_empty())
	hud.refresh()
	await _frames(2)
	_ok("everything finished: the QUESTS tab has not moved or changed size",
		hud.quests_tab_rect() == tab0 and hud._tab_quests.text == "QUESTS")
	await _completed_table(eid, job, "")

	# THE RECORDS SAVE AND LOAD (VERSION 35)
	var recs := str(Run.event_quests)
	var order := str(Run.quests_done)
	SaveGame.save()
	_ok("a save with the records loads", SaveGame.load_into_run())
	_ok("and brings them back as they were (%s, %s)" % [Run.event_quests, Run.quests_done],
		str(Run.event_quests) == recs and str(Run.quests_done) == order)
	QuestLog.forget()
	var back := QuestLog.done_entries()
	_ok("and COMPLETED reads the same after it",
		back.size() == 2 and int((back[0] as Dictionary).id) == job.id and int((back[1] as Dictionary).id) == eid
		and String((back[1] as Dictionary).pay) == "%d CR" % paid)
	target = Run.map[at]

	# A SAVE FROM BEFORE THE RECORDS: a new event quest open, the job closed
	var at2 := OptionTable.place(target, &"paid_in_full", &"the_runner")
	if not _ok("a second PAID IN FULL placed for the old save (at %d)" % at2, at2 >= 0):
		return
	SaveGame.save()
	var fr := FileAccess.open(SaveGame.path, FileAccess.READ)
	var old: Dictionary = JSON.parse_string(fr.get_as_text()) if fr != null else {}
	if fr != null:
		fr.close()
	old["version"] = 34
	old.erase("event_quests")
	old.erase("quests_done")
	var fo := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	if fo != null:
		fo.store_string(JSON.stringify(old, "", true, true))
		fo.close()
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_ok("a version 34 save, with no event_quests and no quests_done, loads", SaveGame.load_into_run())
	_ok("with nothing recorded", Run.event_quests.is_empty() and Run.quests_done.is_empty())
	QuestLog.forget()
	Router.show_local()
	await _frames(4)
	_ok("an old save: the QUESTS tab has not moved or changed size",
		Router.hud.quests_tab_rect() == tab0 and Router.hud._tab_quests.text == "QUESTS")
	var open: Array = QuestLog.entries()
	var oe: Dictionary = open[0] if open.size() == 1 else {}
	var t2: MapGen.MapNode = Run.map[at2]
	_ok("its open event quest still shows, read off the map: %s, %s, %s, %s" % [
		oe.get("what", ""), oe.get("where", ""), oe.get("jumps", ""), oe.get("who", "")],
		int(oe.get("id", -1)) == QuestLog.EVENT_ID + at2 and String(oe.what) == String(words.task)
		and String(oe.where) == "%s · L%d" % [MapGen.star_name(t2), t2.layer + 1]
		and String(oe.who) == "The runner" and String(oe.state) == "MARKED")
	done = QuestLog.done_entries()
	var dj: Dictionary = {}
	var dev: Dictionary = {}
	for e in done:
		if bool((e as Dictionary).event):
			dev = e
		else:
			dj = e
	_ok("its delivered job lists under COMPLETED with its pay (%s)" % dj.get("pay", ""),
		int(dj.get("id", -1)) == job.id and String(dj.pay) == "%d CR" % job.pay)
	_ok("and its taken event quest under COMPLETED without a pay, as none was kept",
		int(dev.get("id", -1)) == eid and String(dev.pay) == "" and String(dev.who) == "The runner")
	await _completed_table(eid, job, "the old save: ")
	var p3 := QuestPanel.open()
	await _frames(2)
	_ok("the old save's table shows the open event quest's row", p3 != null and _row_of(p3, QuestLog.EVENT_ID + at2) != null)
	QuestPanel.close()


## The table with finished quests: COMPLETED below the open rows, its rows
## greyed, a picked one with its note and SHOW ON STARCHART and no PLOT ROUTE.
func _completed_table(eid: int, job: ContractData, when: String) -> void:
	QuestPanel.close()
	Router.show_local()
	await _frames(3)
	QuestPanel.picked = -1
	var p := QuestPanel.open()
	await _frames(2)
	if not _ok("%sthe table opens" % when, p != null):
		return
	var head := p.find_child("Completed", true, false) as Label
	var rows := _rows(p)
	var below := head != null
	var grey := true
	for r in rows:
		var c := r as Control
		var is_done := bool(c.get_meta(&"done", false))
		if is_done and head != null and c.get_index() < head.get_index():
			below = false
		if not is_done and head != null and c.get_index() > head.get_index():
			below = false
		var line := c.find_child("Line", true, false) as Control
		if line == null or (line.modulate == QuestPanel.DONE_TINT) != is_done:
			grey = false
	_ok("%sa COMPLETED heading, the finished rows under it and the open ones above" % when,
		head != null and head.text == "COMPLETED" and below and _row_of(p, eid) != null and _row_of(p, job.id) != null)
	_ok("%sthe finished rows greyed, the open ones not" % when, grey and QuestPanel.DONE_TINT != Color.WHITE)
	_fit("%sLOCAL, finished quests" % when)
	_row_of(p, eid).pressed.emit()
	await _frames(2)
	var er := _row_of(p, eid)
	_ok("%sa finished row opens its note and SHOW ON STARCHART, and has no PLOT ROUTE" % when,
		er != null and er.find_child("Note", true, false) != null
		and er.find_child("ShowOnStarchart", true, false) != null
		and er.find_child("PlotRoute", true, false) == null)
	_fit("%sLOCAL, a finished row open" % when)
	QuestPanel.close()
	QuestPanel.picked = -1


func _offer(kind: int) -> ContractData:
	for raw in Run.map:
		for c in Contracts.board(raw as MapGen.MapNode):
			var job: ContractData = c
			if job.kind != kind or Run.holds_contract(job):
				continue
			if job.at >= 0 and (job.at == Run.at or QuestLog.jumps(job.at) < 1 or QuestLog.jumps(job.at) > 4):
				continue
			return job
	return null


func _rows(p: QuestPanel) -> Array:
	var out: Array = []
	for c in p._rows.get_children():
		if c is Control and c.has_meta(&"quest"):
			out.append(c)
	return out


func _row_of(p: QuestPanel, id: int) -> QuestPanel.Row:
	for c in _rows(p):
		if int((c as Control).get_meta(&"quest")) == id:
			return c as QuestPanel.Row
	return null


func _words(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return out


## The HUD's row: every piece inside the bar, none over another.
func _hud_fits(when: String) -> void:
	var hud := Router.hud
	var bar := hud.get_global_rect()
	var pieces: Array = []
	for c in hud._row.get_children():
		var k := c as Control
		if k != null and k.is_visible_in_tree() and k.size.x > 0.0:
			pieces.append(k)
	var bad: Array[String] = []
	for i in pieces.size():
		var r: Rect2 = (pieces[i] as Control).get_global_rect()
		if not bar.encloses(r):
			bad.append("%s leaves the bar" % (pieces[i] as Control).name)
		for j in range(i + 1, pieces.size()):
			if r.intersects((pieces[j] as Control).get_global_rect()):
				bad.append("%s over %s" % [(pieces[i] as Control).name, (pieces[j] as Control).name])
	var need := hud._row.get_combined_minimum_size().x
	for b in bad:
		print("    %s" % b)
	_ok("%s: the HUD's row fits with QUESTS (needs %.0f of %.0f px), nothing over anything" % [when, need, bar.size.x],
		bad.is_empty() and need <= bar.size.x)


## The table against the HUD, the goal line and A.S.H., inside the screen.
func _fit(where: String) -> void:
	var p := QuestPanel._open
	if p == null:
		_ok("%s: the table is open" % where, false)
		return
	var r := p.get_global_rect()
	var bad: Array[String] = []
	if r.intersects(Router.hud.get_global_rect()):
		bad.append("over the HUD")
	for k in QuestPanel.keep_off():
		if r.intersects(k as Rect2):
			bad.append("over %s" % k)
	if not Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(r):
		bad.append("off the screen %s" % r)
	# and inside it, every row whole and none over another (a row's words were
	# once piled on each other in a Button that lays nothing out)
	var rows := _rows(p)
	var view := p._scroll.get_global_rect()
	for i in rows.size():
		var a: Rect2 = (rows[i] as Control).get_global_rect()
		if a.size.y < 14.0:
			bad.append("row %d is %.0f px tall" % [i + 1, a.size.y])
		if not view.grow(0.5).encloses(a):
			bad.append("row %d %s not wholly shown in %s" % [i + 1, a, view])
		for j in range(i + 1, rows.size()):
			if a.intersects((rows[j] as Control).get_global_rect()):
				bad.append("row %d over row %d" % [i + 1, j + 1])
		for l in (rows[i] as Control).find_children("*", "Label", true, false):
			var lr := (l as Control).get_global_rect()
			for l2 in (rows[i] as Control).find_children("*", "Label", true, false):
				if l2 != l and lr.intersects((l2 as Control).get_global_rect()) and not lr.encloses((l2 as Control).get_global_rect()) and not (l2 as Control).get_global_rect().encloses(lr):
					bad.append("row %d: \"%s\" over \"%s\"" % [i + 1, (l as Label).text, (l2 as Label).text])
					break
	for b in bad:
		print("    %s" % b)
	_ok("%s: the table %s clear of the HUD, the goal line and A.S.H., %d rows whole and apart" % [where, r, rows.size()], bad.is_empty())


## The chart's tag against everything it must keep off, global.
func _tags(ch: StarchartScreen, when: String) -> void:
	var mc := ch._chart
	var near: Dictionary = mc.nodes_near(Rect2(Vector2.ZERO, mc.size))
	var pts := PackedVector2Array()
	for e: Array in near.nodes:
		pts.append(e[1] as Vector2)
	mc._pickable = pts
	var rects: Array = mc.place_quest_tags()
	var g := mc.get_global_transform()
	var avoid: Array = ch._quest_avoid()
	var rad: float = near.rad
	var bad: Array[String] = []
	for i in rects.size():
		var r: Rect2 = rects[i]
		if r.size == Vector2.ZERO or not Rect2(Vector2.ZERO, mc.size).encloses(r):
			bad.append("tag %d not laid inside the chart" % (i + 1))
			continue
		for a in avoid:
			if (g * r).intersects(a as Rect2):
				bad.append("tag over %s" % a)
		for sp in pts:
			var q := Vector2(clampf(sp.x, r.position.x, r.end.x), clampf(sp.y, r.position.y, r.end.y))
			if q.distance_to(sp) < rad:
				bad.append("tag over a star a click could pick at %s" % sp)
				break
	for b in bad:
		print("    %s" % b)
	_ok("%s: the tag clear of the HUD, the goal line, A.S.H., the chart's words and %d pickable stars" % [when, pts.size()],
		bad.is_empty() and rects.size() == 1)
