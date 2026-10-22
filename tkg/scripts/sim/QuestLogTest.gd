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
