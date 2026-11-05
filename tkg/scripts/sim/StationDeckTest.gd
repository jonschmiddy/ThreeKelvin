extends Node

## ALL FIVE DECKS AT EVERY STATION, headless:
##   godot --headless --path . -- sheet=StationDeckTest
## Jon, Nov 3: every station has the PROMENADE, SHIPYARD, EXCHANGE, HIRING BOARD
## and LABORATORY, at every development level. The LABORATORY used to hide below
## a city (RELIC ANALYSIS was dev 3) and the HIRING BOARD where no manufacturer
## berths (an empty `Contracts.board`).
##
## Through the real station screen, at each level from UNCLAIMED to CAPITAL,
## once with no berth and once with one: all five tabs are on and shown and the
## elevator lights five floors; the lab's screen holds its entry (RESEARCH,
## AUGMENT, RECIPES and DATA) inside the screen's window, nothing overlapping
## (the settlement's 206 x 110 is the smallest); pressed, the camera goes into
## the glass (`LabZoom`, science S9, Jon's 1C) and RECIPES lists RELIC ANALYSIS
## at that level's price and DEVELOP FILM and READ FOR DATA at no credits, and
## the RESEARCH board passes the mockup's box test (every box inside the glass,
## none overlapping, no word across an arm) with no step, some and all of them
## bought and the strip on every step; AUGMENT passes it on every part and
## every affix (one part augmented, one with a rolled affix, DATA short, a
## hold that runs onto a second page, STRIP on each affix), costs 5 DATA and
## 22/20/18/16/15 credits, its key survives thirty refreshes, a click on a row
## moves no part, AUGMENT and STRIP pressed through the viewport do what they
## say; BUY stays one object through thirty
## refreshes, never shows on a step behind the next, buys, and the board is the
## same at a second station of the run; with no berth the board
## posts its dock desk's work (`Contracts.dock_desk`), hangs the desk's notice,
## and a job signed there is handed in at that desk; with a berth there is no
## desk.
## A board with nothing to post says NO WORK POSTED. and keeps its tab. The
## chart names the dock desk under OPERATORS, and every such line fits the
## destination panel.

var _fails := 0
var _tree: SceneTree

## RELIC ANALYSIS's bill at each level: 40 credits by `Market.service_index`.
const PRICES := [45, 40, 35, 32, 30]
## AUGMENT's credits at each level (5 DATA beside them), and STRIP's (2 DATA).
const AUGMENT := [22, 20, 18, 16, 15]
const STRIP := [11, 10, 9, 8, 7]
## The chart's destination panel width (`NameFit.PANEL_W`).
const PANEL_W := 228.0


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
	_dock_desk_rule()
	_operators_fit()
	for dev in 5:
		for berth: bool in [false, true]:
			await _decks(dev, berth)
	for dev: int in [MapGen.Development.OUTPOST, MapGen.Development.SETTLEMENT, MapGen.Development.CITY]:
		await _bare(dev)
	await _second_station()
	await _chart()
	print("stationdecktest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


## WHO THE DOCK DESK IS, off the map alone: nobody at a station with a berth, at an
## ordinary system or at the start; the same desk for one station every time;
## and every station without a berth has one.
func _dock_desk_rule() -> void:
	Rng.forced = 9300
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var bare := 0
	var desked := 0
	var berthed_with_desk := 0
	var other_with_desk := 0
	var steady := true
	var seen := {}
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		var h := Contracts.dock_desk(n)
		if h != Contracts.dock_desk(n):
			steady = false
		if n.type != MapGen.NodeType.STATION:
			if h != &"":
				other_with_desk += 1
			continue
		if n.berths.is_empty() and n.manufacturer == &"":
			bare += 1
			if h != &"":
				desked += 1
				seen[h] = true
		elif h != &"":
			berthed_with_desk += 1
	print("    seed 9300: %d stations with no berth, %d of them with a dock desk (%s)" % [bare, desked, ", ".join(seen.keys())])
	_ok("every station with no berth has a dock desk (%d of %d)" % [desked, bare], desked == bare)
	_ok("no station with a berth has one (%d)" % berthed_with_desk, berthed_with_desk == 0)
	_ok("nor any place that is not a station, the start among them (%d)" % other_with_desk,
		other_with_desk == 0 and Contracts.dock_desk(Run.map[Run.at]) == &"")
	_ok("a station's dock desk is the same every time it is asked", steady)
	_ok("a null node has none", Contracts.dock_desk(null) == &"")
	# PINNED to the text order of the ids: `keys().sort()` on StringNames sorts
	# by address, and one process cannot see that, since its order holds for
	# the whole run. A literal desk fails as soon as the pick is not by text.
	var pins: Array = []
	for raw in Run.map:
		var np: MapGen.MapNode = raw
		if Contracts.dock_desk(np) != &"":
			pins.append("%d:%s" % [np.index, Contracts.dock_desk(np)])
	var pin := " ".join(pins)
	_ok("seed 9300's dock desks are the text-ordered picks (%s)" % pin,
		pin == "11:verity 37:calyx 62:calyx")
	# And every one of them, against the ids written out in text order here.
	var abc := PackedStringArray(["calyx", "cygnet", "korvan", "probate", "redline", "solari", "verity"])
	var by_text := true
	for raw in Run.map:
		var nt: MapGen.MapNode = raw
		var ht := Contracts.dock_desk(nt)
		if ht != &"" and String(ht) != abc[Rng.derive(&"dock_desk", nt.index).randi() % abc.size()]:
			by_text = false
	_ok("each desk is drawn from the ids in text order (%s)" % ", ".join(abc),
		by_text and NetSession.sorted_ids(DB.manufacturers) == abc)
	# One process keeps one address order, so the real table cannot show the
	# fault. A table of fresh StringNames made in reverse text order can: their
	# addresses fall in no text order, and a different one each process (3, 4,
	# 2, 5, 1, 6, 7 one run and 1, 5, 2, 4, 3, 7, 6 the next on Nov 3), and a
	# `keys().sort()` pick follows the addresses. Checked failing on that sort.
	var made: Array = []
	for i in range(7, 0, -1):
		made.append(StringName("tk_desk_probe_%d" % i))
	var probe := {}
	for sn in made:
		probe[sn] = true
	var keyed: Array = probe.keys()
	keyed.sort()
	var text_order := NetSession.sorted_ids(probe)
	var follows_text := true
	for i in 64:
		var want := StringName(text_order[Rng.derive(&"dock_desk", i).randi() % text_order.size()])
		if Contracts.dock_desk_from(i, probe) != want:
			follows_text = false
	print("    probe table: keys().sort() gives %s" % str(keyed))
	_ok("a table made out of text order still picks by text, at 64 indices", follows_text)
	# And the same desk on the same seed in a new run (derived, never stored).
	var first := {}
	for raw in Run.map:
		var n2: MapGen.MapNode = raw
		first[n2.index] = Contracts.dock_desk(n2)
	Rng.forced = 9300
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var same := true
	for raw in Run.map:
		var n3: MapGen.MapNode = raw
		if Contracts.dock_desk(n3) != first.get(n3.index, &"?"):
			same = false
	_ok("and the same desks on the same seed in a new run", same)


## "NONE, <MANUFACTURER> DESK" for every manufacturer fits the chart's destination
## panel beside its OPERATORS key, at the panel's own font.
func _operators_fit() -> void:
	var font := UITheme.pixel_font()
	var key_w := font.get_string_size("OPERATORS", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
	var worst := 0.0
	var worst_s := ""
	for mid: StringName in DB.manufacturers:
		var s := "NONE, %s DESK" % DB.short_name(DB.manufacturer_name(mid)).to_upper()
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL).x
		if w > worst:
			worst = w
			worst_s = s
	_ok("the widest desk line (%s, %d px) fits the panel beside OPERATORS (%d px of %d)"
		% [worst_s, int(worst), int(key_w + worst), int(PANEL_W)], key_w + worst + 8.0 <= PANEL_W)


## The station you are at, built as BoardSignTest builds it: `berth` gives it
## Korvan, otherwise nobody holds it.
func _station(dev: int, berth: bool, seed0: int) -> MapGen.MapNode:
	Rng.forced = seed0
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = dev
	here.security = 4
	here.danger = 5
	# (out of any cloud, whose blurb would speak first)
	here.in_nebula = false
	here.berths.clear()
	if berth:
		here.manufacturer = &"korvan"
		here.berths.append(&"korvan")
	else:
		here.manufacturer = &""
	return here


func _dock(here: MapGen.MapNode) -> StationScreen:
	# A NEW DOCKING: every deck powers on afresh, as undocking would leave it.
	Router.powered.clear()
	Router.park_at_station(here)
	Router.show_station()
	await _frames(30)
	return Router.current as StationScreen


## Open a deck by its button and wait (wall clock: the lamp and the scan run on
## it) for its main thing to be up.
func _open(st: StationScreen, id: StringName) -> bool:
	(st._tabs[id] as Button).pressed.emit()
	# (a few frames first: the deck's power-on shuts the lab's holder and then
	# scans it open, so it is whole for a moment before it starts)
	await _frames(3)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and not st.deck_subject(id).has_area():
		await _tree.process_frame
	await _frames(4)
	if not st.deck_subject(id).has_area():
		print("    %s not up after %d ms: tab %s, page shown %s, clip %s of window %s, %d rows" % [id,
			Time.get_ticks_msec() - t0, st._tab, (st._pages[id] as Control).is_visible_in_tree(),
			st._bench_clip.size, st._lab.win_rect().size, st._bench.get_child_count()])
	return st.deck_subject(id).has_area()


func _decks(dev: int, berth: bool) -> void:
	var tag := "%s, %s" % [String(MapGen.Development.keys()[dev]).to_lower(), "a Korvan berth" if berth else "no berth"]
	var here := _station(dev, berth, 9100 + dev)
	var st := await _dock(here)
	if not _ok("%s: the station is up" % tag, st != null):
		return
	var off: Array[String] = []
	for row in StationScreen.DECKS:
		var id: StringName = row[0]
		if not st._tabs_on.get(id, true) or not st._tabs.has(id) or not (st._tabs[id] as Button).visible:
			off.append(String(row[1]))
	_ok("%s: all five decks are on and shown (%s)" % [tag, "none off" if off.is_empty() else "off: " + ", ".join(off)], off.is_empty())
	_ok("%s: the elevator lights five floors (%d)" % [tag, st._spine.floors.size()], st._spine.floors.size() == 5)

	# THE LABORATORY: RELIC ANALYSIS at this level's price, inside the screen.
	var recipes := Fabricator.available(here)
	var relic: Dictionary = {}
	for r in recipes:
		if StringName(r.id) == &"analysis":
			relic = r
	if _ok("%s: the lab offers RELIC ANALYSIS" % tag, not relic.is_empty()):
		var price := Fabricator.price(here, relic)
		_ok("%s: at %d credits (%d wanted)" % [tag, price, PRICES[dev]], price == PRICES[dev])
	if _ok("%s: the lab's screen is up, scanned" % tag, await _open(st, &"bench")):
		await _lab(st, here, tag, dev, not berth)

	# THE HIRING BOARD: whose work it is.
	var desk := Contracts.dock_desk(here)
	var offers := Contracts.board(here)
	var who: Array[String] = []
	for c in offers:
		who.append(String((c as ContractData).manufacturer))
	if berth:
		_ok("%s: no dock desk" % tag, desk == &"")
		_ok("%s: the board posts Korvan's work (%s)" % [tag, ", ".join(who)],
			not offers.is_empty() and who.all(func(m: String) -> bool: return m == "korvan"))
	else:
		_ok("%s: a dock desk (%s)" % [tag, desk], desk != &"")
		_ok("%s: the board posts the dock desk's work (%s)" % [tag, ", ".join(who)],
			not offers.is_empty() and who.all(func(m: String) -> bool: return m == String(desk)))
		_ok("%s: the blurb names the desk" % tag,
			MapGen.place_blurb(here).contains("%s posts work from a desk" % DB.short_name(DB.manufacturer_name(desk))))
	if not _ok("%s: the board is open and lit" % tag, await _open(st, &"work")):
		return
	var posts: Array[StringName] = st._board.posts
	var lead: StringName = &"korvan" if berth else desk
	_ok("%s: %s's notice hangs first (%s)" % [tag, lead, str(posts)], not posts.is_empty() and posts[0] == lead)
	_ok("%s: an offer's SIGN is on the board" % tag, _find_button(st._work, "SIGN") != null)
	_ok("%s: no NO WORK POSTED. note on a board with work" % tag, _find_label(st._work, StationScreen.NO_WORK) == null)

	# A JOB SIGNED HERE IS HANDED IN HERE: done, it is deliverable at this desk,
	# the chart's search finds this desk, and the board puts up its DELIVER.
	var job := Run.take_contract(offers[0])
	if job.kind == ContractData.Kind.HEAT:
		# (a heat job is handed in with the heat on the hull, still TAKEN)
		Run.heat = job.amount + 1
	else:
		job.state = ContractData.State.READY
	Sig.resources_changed.emit()
	await _frames(6)
	var at_desk := Run.deliverable_at(here).has(job) or Run.heat_deliverable_at(here).has(job)
	_ok("%s: a %s job signed here can be handed in here" % [tag, String(ContractData.Kind.keys()[job.kind]).to_lower()], at_desk)
	_ok("%s: and the chart counts this desk as its berth" % tag, ContractData.berth_of(here, job.manufacturer))
	var hand_in := _find_button(st._work, "DELIVER") if job.kind != ContractData.Kind.HEAT \
		else _find_button(st._work, "OFFLOAD %d HEAT" % job.amount)
	_ok("%s: the board shows it a button to hand it in" % tag, hand_in != null)
	if hand_in != null:
		var cash := Run.credits
		hand_in.pressed.emit()
		await _frames(6)
		_ok("%s: and pressed, it pays (%d -> %d)" % [tag, cash, Run.credits], Run.credits > cash)


## A BOARD WITH NOTHING TO POST: a station with no berth whose two offers both
## want an ordinary system nearby, with none left. Its tab stays, and it says
## NO WORK POSTED. on a note in the board's own hand.
func _bare(dev: int) -> void:
	var tag := "%s, bare" % String(MapGen.Development.keys()[dev]).to_lower()
	var here: MapGen.MapNode = null
	for s in 60:
		here = _station(dev, false, 9500 + s)
		for raw in Run.map:
			var o: MapGen.MapNode = raw
			if o.type == MapGen.NodeType.SYSTEM:
				o.type = MapGen.NodeType.PULSAR
		if Contracts.board(here).is_empty():
			break
		here = null
	if not _ok("%s: a station whose board has nothing to post" % tag, here != null):
		return
	var st := await _dock(here)
	if not _ok("%s: the station is up" % tag, st != null):
		return
	_ok("%s: the Hiring Board's tab stays on" % tag,
		st._tabs_on.get(&"work", true) and (st._tabs[&"work"] as Button).visible and st._spine.floors.size() == 5)
	(st._tabs[&"work"] as Button).pressed.emit()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and not st.deck_subject(&"work").has_area():
		await _tree.process_frame
	await _frames(4)
	var kids := st._work.get_child_count()
	var note := _find_label(st._work, StationScreen.NO_WORK)
	_ok("%s: one note says %s (%d on the board)" % [tag, StationScreen.NO_WORK, kids], note != null and kids == 1)
	if note != null:
		var board := st._board.get_global_rect()
		_ok("%s: and it is on the board %s (%s)" % [tag, board, note.get_global_rect()],
			note.is_visible_in_tree() and board.encloses(note.get_global_rect()))


## THE CHART at a dock desk station: OPERATORS reads NONE, <MANUFACTURER> DESK.
func _chart() -> void:
	var here := _station(MapGen.Development.OUTPOST, false, 9100)
	var desk := Contracts.dock_desk(here)
	var st := await _dock(here)
	if st == null:
		_ok("chart: the station is up", false)
		return
	Router.show_starchart()
	await _frames(20)
	var ch := Router.current as StarchartScreen
	if not _ok("chart: the star chart is up", ch != null):
		return
	ch._on_node_picked(here.index)
	await _frames(6)
	var want := "NONE, %s DESK" % DB.short_name(DB.manufacturer_name(desk)).to_upper()
	var said := ""
	var row_ok := false
	for row in ch._rows.get_children():
		var labels := _labels(row as Control)
		if labels.size() >= 2 and labels[0].text == "OPERATORS":
			said = labels[labels.size() - 1].text
			var box := ch._rows.get_global_rect()
			row_ok = box.grow(0.5).encloses(labels[labels.size() - 1].get_global_rect())
	_ok("chart: OPERATORS reads %s (%s)" % [want, said], said == want)
	_ok("chart: and its line sits inside the panel", row_ok)
	# The dock desk's blurb is the longest a station gives (the salvage line and the
	# desk line, and a law line after them). Its extra line spends the spacer
	# below the rows; JUMP must stay on screen and clear of them.
	var blurb := ch._dest_blurb.text
	var rows_bottom := ch._rows.get_global_rect().end.y
	var jump := ch._jump.get_global_rect()
	var screen_h: float = ch.get_viewport_rect().size.y
	print("    chart blurb %d chars: rows end at %.0f, JUMP %.0f to %.0f of %.0f" 		% [blurb.length(), rows_bottom, jump.position.y, jump.end.y, screen_h])
	_ok("chart: the blurb says salvage is thin and names the desk",
		blurb.contains("Salvage is thin and random.") and blurb.contains("posts work from a desk"))
	_ok("chart: JUMP is on screen and below the rows",
		jump.end.y <= screen_h + 0.5 and jump.position.y >= rows_bottom - 0.5)


## THE LABORATORY'S SCREEN AND THE CAMERA INTO IT (science S9, Jon's 1C, Nov 4:
## "is the screen really big enough for a player to see all of it?"). The room's
## entry fits the glass at every level; the zoomed RECIPES and RESEARCH pass
## the box test; and, where `deep`, the board in its used states, BUY's rules
## and the board at a second station.
func _lab(st: StationScreen, here: MapGen.MapNode, tag: String, dev: int, deep: bool) -> void:
	# the entry, inside the screen's window, nothing on top of anything
	var win := st._bench_clip.get_global_rect()
	var boxes: Array = []
	for c in _leaves(st._bench):
		boxes.append([c, c.get_global_rect()])
	var out: Array[String] = []
	for bx: Array in boxes:
		if not win.grow(0.5).encloses(bx[1]):
			out.append("%s %s" % [_name_of(bx[0]), bx[1]])
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if (boxes[i][1] as Rect2).grow(-0.5).intersects((boxes[j][1] as Rect2).grow(-0.5)):
				out.append("%s on %s" % [_name_of(boxes[i][0]), _name_of(boxes[j][0])])
	_ok("%s: the entry's %d boxes sit inside the screen's window %s, none on another (%s)"
		% [tag, boxes.size(), win, "all in" if out.is_empty() else "; ".join(out)], out.is_empty() and boxes.size() >= 8)
	var keys := ["RESEARCH", "AUGMENT", "RECIPES"].all(func(w: String) -> bool: return _find_button(st._bench, w) != null)
	_ok("%s: the entry has RESEARCH, AUGMENT and RECIPES, and DATA %d" % [tag, Run.data],
		keys and _find_label(st._bench, "DATA %d" % Run.data) != null)

	# INTO THE GLASS, on RECIPES
	var zoom := st.lab_zoom()
	await _click(_find_button(st._bench, "RECIPES"))
	await _frames(3)
	if not _ok("%s: RECIPES moves the camera into the glass and lands (open %s, landed %s, tab %s)"
			% [tag, zoom.is_open(), zoom.landed(), zoom.tab], zoom.is_open() and zoom.landed() and zoom.tab == &"recipes"):
		return
	var rows := {}
	for row: Dictionary in zoom.recipe_rows:
		rows[StringName(row.r.id)] = row
	var relic: Dictionary = rows.get(&"analysis", {})
	_ok("%s: RECIPES says RELIC ANALYSIS at %d CREDITS (%s)" % [tag, PRICES[dev], relic.cost if not relic.is_empty() else "no row"],
		not relic.is_empty() and relic.name == "RELIC ANALYSIS" and bool(relic.on)
		and str(relic.cost).contains("%d CREDITS" % PRICES[dev]))
	for id: StringName in [&"develop", &"read"]:
		var r: Dictionary = rows.get(id, {})
		_ok("%s: %s costs 0 credits (%s)" % [tag, id, r.cost if not r.is_empty() else "no row"],
			not r.is_empty() and Fabricator.price(here, r.r) == 0 and not str(r.cost).contains("CREDITS")
			and bool(r.on) and str(r.cost) != "")
	# film and relics held, said on their rows
	for i in 2:
		Run.place_in_hold(MaterialData.of(MaterialTable.by_id(&"survey_film")))
	Sig.resources_changed.emit()
	await _frames(2)
	_ok("%s: DEVELOP FILM says the film held (%s)" % [tag, rows[&"develop"].held],
		str(rows[&"develop"].held) == "YOU HAVE %d SURVEY FILMS" % Run.material(&"survey_film") and not (rows[&"develop"].make as LabPlate).disabled)
	var bad0 := zoom.check()
	_ok("%s: RECIPES with film to develop passes the box test (%s)" % [tag, "clean" if bad0.is_empty() else "; ".join(bad0)], bad0.is_empty())
	var bad := zoom.check()
	_ok("%s: RECIPES passes the box test (%s)" % [tag, "clean" if bad.is_empty() else "; ".join(bad)], bad.is_empty())

	# RESEARCH: the board, with no step, some and all of them bought
	await _click(zoom.tab_buttons[&"research"])
	await _frames(2)
	_ok("%s: RESEARCH is on show" % tag, zoom.tab == &"research" and zoom.board.is_visible_in_tree())
	var was_data := Run.data
	var was_owned := Run.board_owned.duplicate()
	for case: Array in [[[0, 0, 0], 16], [[1, 0, 2], 16], [[1, 1, 2], 4], [[3, 3, 3], 5]]:
		var o: Array = case[0]
		for b in 3:
			Run.board_owned[b] = o[b]
		Run.data = case[1]
		Sig.resources_changed.emit()
		var fails: Array[String] = []
		for b2 in 3:
			for k in 3:
				zoom.board.pick = Vector2i(b2, k)
				zoom.board.refresh()
				await _frames(2)
				for f in zoom.check():
					fails.append("%d,%d %s" % [b2, k, f])
		_ok("%s: the board owned %s with %d DATA passes the box test on all nine steps (%s)" % [tag, str(o), int(case[1]),
			"clean" if fails.is_empty() else "; ".join(fails.slice(0, 4))], fails.is_empty())
	if deep:
		await _buy_rules(st, zoom, tag)
	for b3 in 3:
		Run.board_owned[b3] = was_owned[b3]
	Run.data = was_data
	Sig.resources_changed.emit()
	await _augment_page(st, zoom, here, tag, dev, deep)
	Run.data = was_data
	Sig.resources_changed.emit()

	# BACK OUT: LEAVE, and Esc
	await _click(zoom.leave_button)
	await _frames(2)
	_ok("%s: LEAVE takes the camera back out (open %s, shown %s, entry %.1f)" % [tag, zoom.is_open(), zoom.visible, st._bench.modulate.a],
		not zoom.is_open() and not zoom.visible and is_equal_approx(st._bench.modulate.a, 1.0))
	(_find_button(st._bench, "RESEARCH") as Button).pressed.emit()
	await _frames(2)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	st.get_viewport().push_input(esc)
	await _frames(2)
	_ok("%s: RESEARCH goes in, and Esc comes back out (open %s)" % [tag, zoom.is_open()], not zoom.is_open() and not zoom.visible)
	# (and at the capital with a berth: the yard's edge sets the rail's alpha
	# every frame there, and undid the chrome's going)
	var big := dev == MapGen.Development.CAPITAL or dev == MapGen.Development.SETTLEMENT
	if (deep and big) or (not deep and dev == MapGen.Development.CAPITAL):
		await _camera_move(st, zoom, tag)


## THE MOVE ITSELF, animated (`Router.animate_in_harness`; headless it jumps
## to its end): the station's chrome leaves before the camera moves and is
## gone while it moves, and back only once the camera is out; Esc on the way
## in turns it round and opens no pause menu; a click during the move lands
## it and is eaten (it reaches no page key, and on the way out it does not
## open the Lab again); Tab with the camera in takes it out at once, the
## chrome back. The HUD's alpha, the rail's and the entry's are read off the
## nodes the player sees.
func _camera_move(st: StationScreen, zoom: LabZoom, tag: String) -> void:
	var hud: Control = Router.hud
	var was_anim := Router.animate_in_harness
	Router.animate_in_harness = true
	var out_s := ZoomLadder.UI_OUT_S
	var mid := out_s + ZoomLadder.LAB_ZOOM_S * 0.4
	# IN, and held mid-move
	await _click(_find_button(st._bench, "RESEARCH"))
	await _until(func() -> bool: return zoom._at >= mid)
	var moving := zoom.is_open() and not zoom.landed() and zoom._at > out_s
	_ok("%s, animated: mid-move the HUD, the rail and the entry are gone (HUD %.2f, rail %.2f, entry %.2f, at %.2f of %.2f)" % [tag,
		hud.modulate.a, st._rail.modulate.a, st._bench.modulate.a, zoom._at, zoom._goal],
		moving and hud.modulate.a < 0.02 and st._rail.modulate.a < 0.02 and st._bench.modulate.a < 0.02)
	# AND ALL ELSE ON THE GLASS WITH THE ENTRY: the press's glow under the
	# pointer went out in one frame as the camera set off (the capital's glass
	# 52 to 39 grey), and the screen's snow flashed on the bare glass
	var fxl := st._lab.fx_layer()
	_ok("%s, animated: mid-move the press's glow and the screen's own effects are gone with it (press %.2f, screen %.2f, hushed %s), the room's edge let go (veil %s, walls %s)" % [tag,
		st._glass_press.modulate.a, fxl.modulate.a, st._lab._glass.hushed, zoom._veil.visible, zoom._walls.visible],
		st._glass_press.modulate.a < 0.02 and fxl.modulate.a < 0.02 and st._lab._glass.hushed
		and zoom._veil.visible and zoom._walls.visible)
	# Esc mid-move turns it round, and no pause menu opens
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	GameShell.input_target(_tree).push_input(esc)
	await _tree.process_frame
	var menu: Variant = _tree.current_scene.get("_menu") if _tree.current_scene != null else null
	_ok("%s, animated: Esc on the way in turns the camera round (goal %.2f) and opens no menu (%s)" % [tag, zoom._goal, menu],
		zoom._goal == 0.0 and menu == null)
	var chrome_while_moving := 1.0
	var t0 := Time.get_ticks_msec()
	while zoom.visible and Time.get_ticks_msec() - t0 < 8000:
		if zoom._at > out_s:
			chrome_while_moving = minf(chrome_while_moving, 1.0 - hud.modulate.a)
		await _tree.process_frame
	_ok("%s, animated: out again, the chrome back as it was (HUD %.2f, rail %.2f, entry %.2f), and gone all the way out (%.2f)" % [tag,
		hud.modulate.a, st._rail.modulate.a, st._bench.modulate.a, chrome_while_moving],
		not zoom.is_open() and is_equal_approx(hud.modulate.a, 1.0) and is_equal_approx(st._rail.modulate.a, 1.0)
		and is_equal_approx(st._bench.modulate.a, 1.0) and chrome_while_moving > 0.98)
	_ok("%s, animated: out again, the press's glow and the screen's effects back (press %.2f, screen %.2f, hushed %s, veil %s)" % [tag,
		st._glass_press.modulate.a, st._lab.fx_layer().modulate.a, st._lab._glass.hushed, zoom._veil.visible],
		is_equal_approx(st._glass_press.modulate.a, 1.0) and is_equal_approx(st._lab.fx_layer().modulate.a, 1.0)
		and not st._lab._glass.hushed and not zoom._veil.visible)
	# IN AGAIN: a click mid-move lands it, and goes no further (it is where
	# the AUGMENT tab will be)
	await _click(_find_button(st._bench, "RESEARCH"))
	await _until(func() -> bool: return zoom._at >= mid)
	var tab_at: Vector2 = (zoom.tab_buttons[&"augment"] as Control).get_global_rect().get_center()
	await _click_at(tab_at)
	await _frames(2)
	_ok("%s, animated: a click mid-move lands the camera (landed %s) and is eaten (the page %s, not AUGMENT)" % [tag, zoom.landed(), zoom.tab],
		zoom.landed() and zoom.tab == &"research")
	# LANDED, the chrome stays gone (frames on: where there is a berth the
	# yard's edge sets the rail's alpha every frame, and put it back whole)
	await _frames(4)
	_ok("%s, animated: landed, frames on, the HUD and the rail stay gone (HUD %.2f, rail %.2f)" % [tag, hud.modulate.a, st._rail.modulate.a],
		zoom.landed() and hud.modulate.a < 0.02 and st._rail.modulate.a < 0.02)
	# nothing drawn for nothing under the landed frame: the walls and the veil
	# behind it are hidden (they cost a pass of the room's light every frame)
	_ok("%s, animated: landed, the walls and the veil under the frame are hidden (walls %s, life %s, veil %s)" % [tag,
		zoom._walls.visible, zoom._wall_life.visible, zoom._veil.visible],
		zoom.landed() and not zoom._walls.visible and not zoom._wall_life.visible and not zoom._veil.visible)
	# OUT, with a click on the glass mid-move: it lands out, and the Lab stays shut
	await _click(zoom.leave_button)
	await _until(func() -> bool: return zoom._at <= out_s + ZoomLadder.LAB_ZOOM_S * 0.5)
	var glass_at := st._bench_clip.get_global_rect().get_center()
	await _click_at(glass_at)
	await _frames(3)
	_ok("%s, animated: a click on the glass on the way out lands it out and opens nothing (open %s, shown %s, HUD %.2f)" % [tag,
		zoom.is_open(), zoom.visible, hud.modulate.a], not zoom.is_open() and not zoom.visible and is_equal_approx(hud.modulate.a, 1.0))
	# TAB with the camera in: out at once, the chrome back, the key left for Main
	Router.animate_in_harness = false
	zoom.open(&"research")
	await _frames(1)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	var tab_bound := tab.is_action_pressed(&"next_screen")
	zoom._input(tab)
	_ok("%s: Tab (next screen, bound %s) with the camera in takes it out at once, the chrome back (open %s, shown %s, HUD %.2f, rail %.2f)" % [tag,
		tab_bound, zoom.is_open(), zoom.visible, hud.modulate.a, st._rail.modulate.a],
		tab_bound and not zoom.is_open() and not zoom.visible and is_equal_approx(hud.modulate.a, 1.0) and is_equal_approx(st._rail.modulate.a, 1.0))
	Router.animate_in_harness = was_anim


## AUGMENT AND STRIP (S9 part two): the page's box test on every part and
## affix, in the states a run reaches; its prices; its key kept through
## refreshes; a pick that moves nothing; and both presses made through the
## viewport, as a player makes them (`deep`: once a level).
func _augment_page(st: StationScreen, zoom: LabZoom, here: MapGen.MapNode, tag: String, dev: int, deep: bool) -> void:
	var aug := zoom.augment
	# THE USED STATE: a fitted part already augmented, a hold part with a
	# rolled affix, and two more in the hold
	var fitted: ModuleData = Run.installed[0]
	if not fitted.augmented:
		var l1: Array[AffixData] = fitted.affixes.duplicate()
		l1.append(Science._affix(&"Wide-Banded"))
		fitted.affixes = l1
		fitted.augmented = true
	var guard := 0
	while _held().size() < 3 and guard < 20:
		guard += 1
		Run.place_in_hold(LootGen.roll_module(3 + guard % 4, &"", true))
	var rolled: ModuleData = _held()[0] if not _held().is_empty() else null
	if rolled != null and rolled.affixes.is_empty():
		var l2: Array[AffixData] = []
		l2.append(Science._affix(&"Tuned Injectors"))
		rolled.affixes = l2
	Run.data = 16
	Run.credits = 500
	Sig.resources_changed.emit()
	await _click(zoom.tab_buttons[&"augment"])
	await _frames(2)
	if not _ok("%s: AUGMENT is on show" % tag, zoom.tab == &"augment" and aug.is_visible_in_tree()):
		return
	# THE PRICE: 5 DATA and this level's credits, on the key's bill
	var plain: ModuleData = null
	for m in Run.installed:
		if not m.augmented:
			plain = m
			break
	if plain != null:
		aug.pick_part(plain)
		await _frames(2)
	var b := aug.bill()
	_ok("%s: AUGMENT costs 5 DATA and %d credits (bill %s, the key's %s)" % [tag, AUGMENT[dev], b, aug.bill_words],
		int(b.data) == 5 and int(b.credits) == AUGMENT[dev] and Market.augment_price(here) == AUGMENT[dev]
		and aug.bill_words == "5 DATA + %d CREDITS" % AUGMENT[dev])
	# A PICK MOVES NOTHING: every part where it was after every row is clicked
	var places := _places()
	var fails: Array[String] = []
	var rows_seen := 0
	for pg in aug._pages.size():
		aug.page = pg
		aug._relayout()
		for i in aug._rows.size():
			var r: Dictionary = aug._rows[i]
			await _click_at(aug.get_global_transform() * Vector2(aug.RAIL_X + 120, int(r.cy) - 5))
			rows_seen += 1
			if aug.part != r.m:
				fails.append("row %d didn't pick %s" % [i, (r.m as ModuleData).name])
			for k in maxi(1, aug._affs.size()):
				if k < aug._affs.size():
					aug.pick_affix(k)
				await _frames(1)
				for f in zoom.check():
					fails.append("%s %s %d: %s" % [(r.m as ModuleData).name, aug.mode, k, f])
	_ok("%s: AUGMENT passes the box test on all %d parts and every affix, a click picking each (%s)" % [tag, rows_seen,
		"clean" if fails.is_empty() else "; ".join(fails.slice(0, 4))], fails.is_empty() and rows_seen >= 3)
	_ok("%s: and no click on a row moved a part" % tag, _places() == places)
	_ok("%s: the augmented part opens on STRIP, with its key" % tag, await _strip_view(aug, fitted, dev))
	# DATA SHORT: the key goes dead, the bill says which is short, and it fits
	Run.data = 3
	Sig.resources_changed.emit()
	if plain != null:
		aug.pick_part(plain)
	await _frames(2)
	var bad := zoom.check()
	_ok("%s: DATA short, AUGMENT can't be pressed and the page passes the box test (%s)" % [tag, "clean" if bad.is_empty() else "; ".join(bad)],
		plain == null or (aug.commit_button.visible and aug.commit_button.disabled and bad.is_empty()))
	Run.data = 16
	Sig.resources_changed.emit()
	if deep and plain != null:
		await _augment_press(st, zoom, plain, tag, dev)
	# A HOLD THAT RUNS ONTO A SECOND PAGE
	guard = 0
	while not Run.hold_full() and guard < 40:
		guard += 1
		Run.place_in_hold(LootGen.roll_module(1 + guard % 3, &"", true))
	Sig.resources_changed.emit()
	await _frames(2)
	var pages := aug._pages.size()
	var fails2: Array[String] = []
	for pg2 in pages:
		if pg2 > 0:
			await _click(aug.more_button)
			await _frames(1)
		for f2 in zoom.check():
			fails2.append("page %d: %s" % [aug.page + 1, f2])
	_ok("%s: %d parts run onto %d pages, MORE turns them, and each passes the box test (%s)" % [tag, Run.installed.size() + _held().size(),
		pages, "clean" if fails2.is_empty() else "; ".join(fails2.slice(0, 4))], fails2.is_empty() and (pages > 1) == aug.more_button.visible)


## The augmented part on STRIP: each of its affixes in hand passes the box
## test, the key reads STRIP, and the bill is 2 DATA and this level's credits.
func _strip_view(aug: LabAugment, m: ModuleData, dev: int) -> bool:
	aug.pick_part(m)
	await _frames(1)
	var ok := aug.mode == &"strip" and aug._affs.size() == m.affixes.size()
	for k in aug._affs.size():
		aug.pick_affix(k)
		await _frames(1)
		var bad := (aug.get_parent().get_parent() as LabZoom).check()
		if not bad.is_empty():
			print("    strip %d: %s" % [k, "; ".join(bad)])
			ok = false
		ok = ok and aug.commit_button.visible and aug.commit_button.label == "STRIP" \
			and aug.bill_words == "2 DATA + %d CREDITS" % STRIP[dev]
	return ok


## AUGMENT pressed through the viewport after thirty refreshes, then STRIP.
func _augment_press(st: StationScreen, zoom: LabZoom, m: ModuleData, tag: String, dev: int) -> void:
	var aug := zoom.augment
	# A ROLLED AFFIX ON IT FIRST, so STRIP has two to choose from and taking
	# the wrong one shows (with one, the first and the last are the same)
	if m.affixes.is_empty():
		var rl: Array[AffixData] = []
		rl.append(Science._affix(&"Cryo-Lined"))
		m.affixes = rl
		Sig.ship_changed.emit()
	var rolled_name := m.affixes[0].name
	aug.pick_part(m)
	aug.pick_affix(0)
	await _frames(2)
	var key := aug.commit_button
	for i in 30:
		Sig.resources_changed.emit()
		if i % 10 == 0:
			await _frames(1)
	await _frames(2)
	_ok("%s: AUGMENT is the same object after 30 refreshes, the part still in hand" % tag,
		is_instance_valid(key) and aug.commit_button == key and key.visible and not key.disabled and aug.part == m)
	var a: AffixData = aug._affs[0]
	var n_aff := m.affixes.size()
	var data0 := Run.data
	var cr0 := Run.credits
	var hp0 := Run.max_hp()
	# WHAT THE PAGE IS DOING INSIDE THE PRESS: the service sends ship_changed,
	# and the refresh it runs must find the page still on AUGMENT (read here,
	# after the station's own refresh, on the same emit)
	var inside: Array = []
	var probe := func() -> void: inside.append(aug.mode)
	Sig.ship_changed.connect(probe)
	await _click(key)
	Sig.ship_changed.disconnect(probe)
	await _frames(2)
	_ok("%s: AUGMENT puts %s on %s for 5 DATA and %d credits (DATA %d to %d, credits %d to %d, the header %s)" % [tag, a.name, m.name,
		AUGMENT[dev], data0, Run.data, cr0, Run.credits, zoom._note],
		m.augmented and m.affixes.size() == n_aff + 1 and m.affixes[-1].name == a.name
		and Run.data == data0 - 5 and Run.credits == cr0 - AUGMENT[dev] and zoom._note == "-5")
	_ok("%s: inside the press the page never turned over to STRIP (%s)" % [tag, inside],
		not inside.is_empty() and inside.all(func(md: StringName) -> bool: return md == &"augment"))
	_ok("%s: the page stays on AUGMENT and the strip says it is done, with no key (mode %s, %s)" % [tag, aug.mode, aug.done.get("line", "")],
		not aug.done.is_empty() and aug.done.kind == &"augment" and aug.mode == &"augment" and not key.visible
		and aug.leaves.any(func(l: Array) -> bool: return l[0] == String(aug.done.line).to_upper())
		and aug.leaves.any(func(l: Array) -> bool: return l[0] == "%s %s" % [a.name.to_upper(), LabAugment.short_part(m.name)])
		and aug._node_state(0) == &"owned")
	var bad := zoom.check()
	_ok("%s: the page just augmented passes the box test (%s)" % [tag, "clean" if bad.is_empty() else "; ".join(bad)], bad.is_empty())
	if a.hull > 0 and Run.installed.has(m):
		_ok("%s: and the ship's max hull went %d to %d" % [tag, hp0, Run.max_hp()], Run.max_hp() == hp0 + 7 * a.hull)
	# a second augment is refused: the row opens on STRIP
	await _click_at(aug.get_global_transform() * Vector2(aug.RAIL_X + 120, _row_y(aug, m)))
	await _frames(2)
	_ok("%s: picked again, it opens on STRIP, never a second augment" % tag, aug.mode == &"strip" and aug.commit_button.label == "STRIP")
	# the Lab's own affix picked, and it last on the part: the rolled one first
	var at_lab := -1
	for i in aug._affs.size():
		if aug._affs[i].name == a.name:
			at_lab = i
	aug.pick_affix(at_lab)
	await _frames(1)
	var data1 := Run.data
	var cr1 := Run.credits
	await _click(aug.commit_button)
	await _frames(2)
	var left: Array = m.affixes.map(func(x: AffixData) -> String: return x.name)
	_ok("%s: STRIP takes the picked %s off and leaves %s on (%s) for 2 DATA and %d credits, and the mark stays (DATA %d to %d, credits %d to %d)" % [tag, a.name,
		rolled_name, left, STRIP[dev], data1, Run.data, cr1, Run.credits],
		at_lab > 0 and m.augmented and m.affixes.size() == n_aff and not left.has(a.name) and left.has(rolled_name)
		and Run.data == data1 - 2 and Run.credits == cr1 - STRIP[dev])
	var bad2 := zoom.check()
	_ok("%s: the page just stripped passes the box test (%s)" % [tag, "clean" if bad2.is_empty() else "; ".join(bad2)], bad2.is_empty())


func _row_y(aug: LabAugment, m: ModuleData) -> int:
	for r: Dictionary in aug._rows:
		if r.m == m:
			return int(r.cy) - 5
	return -100


func _held() -> Array[ModuleData]:
	var out: Array[ModuleData] = []
	for h in Run.cargo:
		if h is ModuleData:
			out.append(h)
	return out


## Where every part is: its mount, or its cell in the hold.
func _places() -> Array:
	var out: Array = []
	for m in Run.installed:
		out.append("%s fitted %d" % [m.name, m.mount])
	for h in _held():
		out.append("%s at %s" % [h.name, h.hold_at])
	return out


## BUY: one object, only on the next step, and it buys.
func _buy_rules(st: StationScreen, zoom: LabZoom, tag: String) -> void:
	var board := zoom.board
	for b in 3:
		Run.board_owned[b] = 0
	Run.data = 40
	Sig.resources_changed.emit()
	await _frames(2)
	var none_behind := true
	var on_next := true
	for b2 in 3:
		board.pick = Vector2i(b2, 1)
		board.refresh()
		if board.buy_button.visible:
			none_behind = false
		board.pick = Vector2i(b2, 2)
		board.refresh()
		if board.buy_button.visible:
			none_behind = false
		board.pick = Vector2i(b2, 0)
		board.refresh()
		if not board.buy_button.visible:
			on_next = false
	_ok("%s: no BUY on a step while the one before it is not bought" % tag, none_behind)
	_ok("%s: BUY on each branch's next step" % tag, on_next)
	# CORE's first step picked as a player picks it, by its ring
	board.pick = Vector2i(0, 2)
	board.refresh()
	await _frames(1)
	await _click_at(board.get_global_transform() * Vector2(board._nodes[Vector2i(1, 0)]))
	_ok("%s: a click on CORE's first step puts it on the strip, with BUY" % tag,
		board.pick == Vector2i(1, 0) and board.buy_button.visible)
	var buy := board.buy_button
	var key: Button = st._entry_keys[&"research"]
	for i in 30:
		Sig.resources_changed.emit()
		if i % 10 == 0:
			await _frames(1)
	await _frames(2)
	_ok("%s: BUY and the entry's keys are the same objects after 30 refreshes" % tag,
		is_instance_valid(buy) and board.buy_button == buy and buy.visible and buy.get_parent() == board
		and is_instance_valid(key) and st._entry_keys[&"research"] == key)
	await _click(buy)
	await _frames(2)
	_ok("%s: BUY spends 6 DATA and runs CORE's first step (DATA %d, owned %s, the strip on %s)"
		% [tag, Run.data, str(Run.board_owned), board.bought],
		Run.data == 34 and Run.board_owned[1] == 1 and board.bought == Vector2i(1, 0) and zoom._note == "-6")
	_ok("%s: and the strip says it runs from the next fight" % tag, board.leaves.any(func(l: Array) -> bool: return l[0] == "RUNNING FROM YOUR NEXT FIGHT."))
	var bad := zoom.check()
	_ok("%s: the board just bought passes the box test (%s)" % [tag, "clean" if bad.is_empty() else "; ".join(bad)], bad.is_empty())
	# DATA SHORT: the next step keeps its key, dead, and the strip says what
	# you hold; a click on it buys nothing
	for b4 in 3:
		Run.board_owned[b4] = 0
	Run.data = 3
	Sig.resources_changed.emit()
	board.pick = Vector2i(0, 0)
	board.bought = Vector2i(-1, -1)
	board.refresh()
	await _frames(2)
	await _click(board.buy_button)
	await _frames(2)
	var bad2 := zoom.check()
	_ok("%s: DATA short, BUY is there and dead, the strip says YOU HAVE 3 DATA, a click buys nothing, and it fits (%s)" % [tag,
		"clean" if bad2.is_empty() else "; ".join(bad2)],
		board.buy_button.visible and board.buy_button.disabled and board.buy_button == buy
		and board.leaves.any(func(l: Array) -> bool: return l[0] == "YOU HAVE 3 DATA")
		and Run.data == 3 and Run.board_owned[0] == 0 and bad2.is_empty())


## THE SAME BOARD AT A SECOND STATION of the run: the same steps where they
## were and every word where it was, a station two levels up.
func _second_station() -> void:
	var here := _station(MapGen.Development.OUTPOST, false, 9100)
	var st := await _dock(here)
	if not _ok("second station: the first is up", st != null and await _open(st, &"bench")):
		return
	Run.board_owned[0] = 1
	Run.board_owned[2] = 2
	Run.data = 16
	st.lab_zoom().open(&"research")
	st.lab_zoom().board.pick = Vector2i(1, 0)
	st.lab_zoom().board.refresh()
	await _frames(3)
	var first := _board_print(st.lab_zoom().board)
	var other: MapGen.MapNode = null
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n != here and n.type != MapGen.NodeType.CORE and n.type != MapGen.NodeType.START:
			other = n
			break
	st.lab_zoom().close()
	other.type = MapGen.NodeType.STATION
	other.development = MapGen.Development.CITY
	var st2 := await _dock(other)
	if not _ok("second station: a city on the same run is up", st2 != null and st2 != st and await _open(st2, &"bench")):
		return
	st2.lab_zoom().open(&"research")
	st2.lab_zoom().board.pick = Vector2i(1, 0)
	st2.lab_zoom().board.refresh()
	await _frames(3)
	var there := _board_print(st2.lab_zoom().board)
	_ok("the board is the same at a second station: every step and word where it was (%d)" % there.size(),
		there == first and there.size() >= 20)
	st2.lab_zoom().close()


## Frames until `cond` holds, at most `ms` of the wall clock (the move runs
## on it).
func _until(cond: Callable, ms: int = 8000) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < ms:
		await _tree.process_frame


## A click through the viewport, as a player makes it (BoardSignTest's way):
## whatever is on top at that point takes it.
func _click(b: Control) -> void:
	b.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _click_at(b.get_global_rect().get_center())


func _click_at(at: Vector2) -> void:
	var target := GameShell.input_target(_tree)
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	target.push_input(mv)
	await _tree.process_frame
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		mb.position = at
		mb.global_position = at
		target.push_input(mb)
		await _tree.process_frame


## Where the board's steps and words are, as text.
func _board_print(board: LabBoard) -> Array:
	var out: Array = []
	for k: Vector2i in board._nodes:
		out.append("%s@%s" % [k, board._nodes[k]])
	for l: Dictionary in board._labels:
		out.append("%s@%d,%d" % [l.s, l.x, l.ycap])
	return out


## Every word and key under `n` that shows: what a box test of a page is about.
func _leaves(n: Node) -> Array[Control]:
	var out: Array[Control] = []
	if n is Button and (n as Button).is_visible_in_tree():
		out.append(n as Control)
		return out
	if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text != "":
		out.append(n as Control)
	for c in n.get_children():
		out.append_array(_leaves(c))
	return out


func _name_of(c: Control) -> String:
	if c is Button:
		return "[%s]" % (c as Button).text
	if c is Label:
		return (c as Label).text.left(24)
	return c.name


func _labels(n: Node) -> Array[Label]:
	var out: Array[Label] = []
	if n is Label and (n as Label).is_visible_in_tree():
		out.append(n as Label)
	for c in n.get_children():
		out.append_array(_labels(c))
	return out


func _find_label(n: Node, text: String) -> Label:
	if n is Label and (n as Label).text == text:
		return n as Label
	for c in n.get_children():
		var got := _find_label(c, text)
		if got != null:
			return got
	return null


func _find_label_containing(n: Node, text: String) -> Label:
	if n is Label and (n as Label).text.contains(text):
		return n as Label
	for c in n.get_children():
		var got := _find_label_containing(c, text)
		if got != null:
			return got
	return null


func _find_button(n: Node, text: String) -> Button:
	var b := n as Button
	if b != null and b.text == text and b.is_visible_in_tree():
		return b
	for c in n.get_children():
		var got := _find_button(c, text)
		if got != null:
			return got
	return null
